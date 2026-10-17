#!/usr/bin/env python3
"""Export the sphere grid as an editable draw.io diagram (and an SVG preview).

Reads the grid the game builds (tests/sim/dump_sphere_grid.gd writes
sim_out/sphere_grid.json: every node with its on-screen position, type,
description, stat gate, keystone and connections, plus the constellations)
and writes:

  docs/sphere_grid.drawio   open at app.diagrams.net (File > Open), in the
                            draw.io desktop app, or insert into a Google Doc
                            with the diagrams.net add-on. Uncompressed XML.
  docs/sphere_grid.svg      a plain picture of the same layout.

The diagram has three layers (View > Layers): the grid itself, the
constellations (coloured lines along each constellation's connections, with
its bonus as a label) and a legend. Hovering a node shows its description;
a stat gate ("DEX 15") sits under the label. Positions are the game's own
(scripts/progression/sphere_grid.gd), so the picture matches the in-game
grid. Editing the file changes nothing in the game; it is a drawing board.

  python3 tools/sphere_grid_export.py [--input sim_out/sphere_grid.json]
"""
import argparse, html, json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Fill / stroke per node type.
STYLE = {
    "START":         ("#FFE9B3", "#B8860B"),
    "STAT_BONUS":    ("#D6E8F7", "#4A7FB5"),
    "COMBAT_BONUS":  ("#F8DCD2", "#C0623F"),
    "HEALTH":        ("#DFF0D8", "#4F8F3B"),
    "MANA":          ("#E3DCF5", "#6F4FB5"),
    "KEYSTONE":      ("#FFF2B3", "#9A7B00"),
    "FREE_STAT":     ("#F2F2F2", "#555555"),
    "CULLING_STONE": ("#E0E0E0", "#333333"),
    "NULL_NODE":     ("#EEEEEE", "#AAAAAA"),
}
LEGEND_TEXT = {
    "START": "Origin",
    "STAT_BONUS": "Stat bonus (+1 to a stat)",
    "COMBAT_BONUS": "Combat bonus",
    "HEALTH": "Max health",
    "MANA": "Max mana",
    "KEYSTONE": "Keystone (stat-gated, build-defining)",
    "FREE_STAT": "Free stat point",
    "CULLING_STONE": "Culling stone",
    "NULL_NODE": "Empty node (a path, no bonus)",
}
STAT_SHORT = {"strength": "STR", "dexterity": "DEX", "intelligence": "INT",
              "wisdom": "WIS", "agility": "AGI", "determination": "DET"}


def load(path):
    d = json.load(open(path))
    nodes = d.get("nodes") or d.get("sphere_nodes")
    cons = d.get("constellations", [])
    return nodes, cons


def gate(n):
    r = n.get("requirements") or {}
    if "stat" in r:
        return "%s %s" % (STAT_SHORT.get(r["stat"], r["stat"]), r["value"])
    return ""


def size(n):
    t = n["type"]
    if t == "KEYSTONE":
        return 120, 64
    if t == "NULL_NODE":
        return 34, 34
    if t == "START":
        return 80, 50
    return 78, 44


def esc(s):
    return html.escape(str(s), quote=True)


def write_drawio(nodes, cons, path):
    minx = min(n["x"] for n in nodes) - 80
    miny = min(n["y"] for n in nodes) - 80
    pos = {n["id"]: (n["x"] - minx, n["y"] - miny) for n in nodes}
    out = []
    out.append('<mxfile host="app.diagrams.net" type="device">')
    out.append('<diagram id="sphere-grid" name="Sphere Grid">')
    out.append('<mxGraphModel dx="1400" dy="900" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" '
               'arrows="1" fold="1" page="0" pageScale="1" pageWidth="1600" pageHeight="1400" math="0" shadow="0">')
    out.append('<root>')
    out.append('<mxCell id="0"/>')
    out.append('<mxCell id="L_grid" value="Grid" style="locked=0" parent="0"/>')
    out.append('<mxCell id="L_cons" value="Constellations" style="locked=0" parent="0"/>')
    out.append('<mxCell id="L_legend" value="Legend" style="locked=0" parent="0"/>')
    # Edges first (drawn under nodes): one per undirected pair.
    seen = set()
    for n in nodes:
        for m in n["connections"]:
            a, b = sorted((n["id"], int(m)))
            if (a, b) in seen:
                continue
            seen.add((a, b))
            out.append('<mxCell id="e_%d_%d" style="endArrow=none;html=1;strokeColor=#9E9E9E;strokeWidth=1.5;" '
                       'edge="1" parent="L_grid" source="n%d" target="n%d"><mxGeometry relative="1" as="geometry"/></mxCell>'
                       % (a, b, a, b))
    # Nodes.
    for n in nodes:
        fill, stroke = STYLE.get(n["type"], ("#FFFFFF", "#000000"))
        w, h = size(n)
        x, y = pos[n["id"]]
        # The label is HTML inside an XML attribute: escape the text for HTML,
        # then the whole thing once more for the attribute.
        label = html.escape(n["label"]) if n["type"] != "NULL_NODE" else ""
        g = gate(n)
        if g:
            label = "%s<br><font style=\"font-size:9px\">%s</font>" % (label, html.escape(g))
        label = esc(label)
        if n["type"] == "KEYSTONE":
            shape = "shape=hexagon;perimeter=hexagonPerimeter2;"
        elif n["type"] == "START":
            shape = "ellipse;shape=doubleEllipse;"
        else:
            shape = "ellipse;"
        style = ("%shtml=1;whiteSpace=wrap;fillColor=%s;strokeColor=%s;strokeWidth=2;fontSize=10;fontStyle=%d;"
                 % (shape, fill, stroke, 1 if n["type"] == "KEYSTONE" else 0))
        tip = n["description"]
        if g:
            tip += " | Needs %s" % g
        if n.get("keystone"):
            tip += " | keystone id: %s" % n["keystone"]
        tip += " | node %d, ring %d, %s" % (n["id"], n["ring"], n["type"].lower().replace("_", " "))
        out.append('<UserObject label="%s" tooltip="%s" nodeId="%d" nodeType="%s" ring="%d" id="n%d">'
                   '<mxCell style="%s" vertex="1" parent="L_grid">'
                   '<mxGeometry x="%.0f" y="%.0f" width="%d" height="%d" as="geometry"/></mxCell></UserObject>'
                   % (label, esc(tip), n["id"], n["type"], n["ring"], n["id"], style, x - w / 2, y - h / 2, w, h))
    # Constellations: thick translucent lines along their connections, a label at the farthest node.
    byid = {n["id"]: n for n in nodes}
    palette = ["#E65C3F", "#B71C1C", "#7E57C2", "#9575CD", "#1E88E5", "#26A69A",
               "#D4A017", "#C62828", "#5E35B1", "#607D8B", "#43A047", "#00897B"]
    for ci, c in enumerate(cons):
        colour = palette[ci % len(palette)]
        members = set(int(i) for i in c["nodes"])
        for a in sorted(members):
            for b in byid[a]["connections"]:
                b = int(b)
                if b in members and a < b:
                    out.append('<mxCell id="c_%s_%d_%d" style="endArrow=none;html=1;strokeColor=%s;strokeWidth=7;opacity=45;" '
                               'edge="1" parent="L_cons" source="n%d" target="n%d"><mxGeometry relative="1" as="geometry"/></mxCell>'
                               % (c["id"], a, b, colour, a, b))
        far = max(members, key=lambda i: (byid[i]["x"] - 640) ** 2 + (byid[i]["y"] - 360) ** 2)
        fx, fy = pos[far]
        ddx = fx - (640 - minx)
        ddy = fy - (360 - miny)
        d = max(1.0, (ddx ** 2 + ddy ** 2) ** 0.5)
        lx, ly = fx + ddx / d * 70, fy + ddy / d * 70
        text = esc("<b>%s</b><br><font style=\"font-size:9px\">%s</font><br><font style=\"font-size:8px\">nodes %s</font>" % (
            html.escape(c["name"]), html.escape(c.get("bonus_description", "")), ", ".join(str(i) for i in c["nodes"])))
        out.append('<mxCell id="cl_%s" value="%s" style="text;html=1;align=center;verticalAlign=middle;whiteSpace=wrap;'
                   'fontSize=10;fontColor=%s;strokeColor=%s;strokeWidth=1;fillColor=#FFFFFF;opacity=85;rounded=1;" '
                   'vertex="1" parent="L_cons"><mxGeometry x="%.0f" y="%.0f" width="170" height="64" as="geometry"/></mxCell>'
                   % (c["id"], text, colour, colour, lx - 85, ly - 32))
    # Legend.
    lx, ly = 20, 20
    out.append('<mxCell id="legend_title" value="&lt;b&gt;Sphere grid&lt;/b&gt;&lt;br&gt;&lt;font style=&quot;font-size:9px&quot;&gt;'
               'generated from scripts/progression/sphere_grid.gd; %d nodes, %d constellations. Hover a node for its text. '
               'Layers: Grid, Constellations, Legend.&lt;/font&gt;" '
               'style="text;html=1;align=left;verticalAlign=top;whiteSpace=wrap;fontSize=12;" vertex="1" parent="L_legend">'
               '<mxGeometry x="%d" y="%d" width="300" height="60" as="geometry"/></mxCell>' % (len(nodes), len(cons), lx, ly))
    for i, (t, (fill, stroke)) in enumerate(STYLE.items()):
        yy = ly + 70 + i * 28
        shape = "shape=hexagon;perimeter=hexagonPerimeter2;" if t == "KEYSTONE" else ("ellipse;shape=doubleEllipse;" if t == "START" else "ellipse;")
        out.append('<mxCell id="lg_%s" value="" style="%shtml=1;fillColor=%s;strokeColor=%s;strokeWidth=2;" vertex="1" parent="L_legend">'
                   '<mxGeometry x="%d" y="%d" width="36" height="22" as="geometry"/></mxCell>' % (t, shape, fill, stroke, lx, yy))
        out.append('<mxCell id="lgt_%s" value="%s" style="text;html=1;align=left;verticalAlign=middle;fontSize=10;" vertex="1" parent="L_legend">'
                   '<mxGeometry x="%d" y="%d" width="240" height="22" as="geometry"/></mxCell>' % (t, esc(LEGEND_TEXT[t]), lx + 44, yy))
    out.append('</root></mxGraphModel></diagram></mxfile>')
    with open(path, "w") as f:
        f.write("\n".join(out))


def write_svg(nodes, cons, path):
    minx = min(n["x"] for n in nodes) - 80
    miny = min(n["y"] for n in nodes) - 80
    maxx = max(n["x"] for n in nodes) + 80
    maxy = max(n["y"] for n in nodes) + 80
    pos = {n["id"]: (n["x"] - minx, n["y"] - miny) for n in nodes}
    W, H = maxx - minx, maxy - miny
    o = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" font-family="Helvetica, Arial, sans-serif">' % (W, H, W, H),
         '<rect width="100%%" height="100%%" fill="#FFFFFF"/>']
    seen = set()
    for n in nodes:
        for m in n["connections"]:
            a, b = sorted((n["id"], int(m)))
            if (a, b) in seen:
                continue
            seen.add((a, b))
            (x1, y1), (x2, y2) = pos[a], pos[b]
            o.append('<line x1="%.0f" y1="%.0f" x2="%.0f" y2="%.0f" stroke="#9E9E9E" stroke-width="1.5"/>' % (x1, y1, x2, y2))
    byid = {n["id"]: n for n in nodes}
    palette = ["#E65C3F", "#B71C1C", "#7E57C2", "#9575CD", "#1E88E5", "#26A69A",
               "#D4A017", "#C62828", "#5E35B1", "#607D8B", "#43A047", "#00897B"]
    for ci, c in enumerate(cons):
        members = set(int(i) for i in c["nodes"])
        for a in sorted(members):
            for b in byid[a]["connections"]:
                if int(b) in members and a < int(b):
                    (x1, y1), (x2, y2) = pos[a], pos[int(b)]
                    o.append('<line x1="%.0f" y1="%.0f" x2="%.0f" y2="%.0f" stroke="%s" stroke-width="7" stroke-opacity="0.45"/>'
                             % (x1, y1, x2, y2, palette[ci % len(palette)]))
    for n in nodes:
        fill, stroke = STYLE.get(n["type"], ("#FFFFFF", "#000000"))
        w, h = size(n)
        x, y = pos[n["id"]]
        o.append('<g><title>%s</title>' % esc(n["description"]))
        if n["type"] == "KEYSTONE":
            pts = "%.0f,%.0f %.0f,%.0f %.0f,%.0f %.0f,%.0f %.0f,%.0f %.0f,%.0f" % (
                x - w / 2, y, x - w / 2 + 14, y - h / 2, x + w / 2 - 14, y - h / 2, x + w / 2, y, x + w / 2 - 14, y + h / 2, x - w / 2 + 14, y + h / 2)
            o.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="2"/>' % (pts, fill, stroke))
        else:
            o.append('<ellipse cx="%.0f" cy="%.0f" rx="%d" ry="%d" fill="%s" stroke="%s" stroke-width="2"/>' % (x, y, w / 2, h / 2, fill, stroke))
        if n["type"] != "NULL_NODE":
            g = gate(n)
            o.append('<text x="%.0f" y="%.0f" font-size="9" text-anchor="middle"%s>%s</text>' % (
                x, y + (1 if g else 3), ' font-weight="bold"' if n["type"] == "KEYSTONE" else "", esc(n["label"])))
            if g:
                o.append('<text x="%.0f" y="%.0f" font-size="8" text-anchor="middle" fill="#555">%s</text>' % (x, y + 11, esc(g)))
        o.append('</g>')
    o.append('</svg>')
    with open(path, "w") as f:
        f.write("\n".join(o))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", default=os.path.join(ROOT, "sim_out", "sphere_grid.json"))
    ap.add_argument("--out-dir", default=os.path.join(ROOT, "docs"))
    args = ap.parse_args()
    nodes, cons = load(args.input)
    nodes.sort(key=lambda n: n["id"])
    dr = os.path.join(args.out_dir, "sphere_grid.drawio")
    sv = os.path.join(args.out_dir, "sphere_grid.svg")
    write_drawio(nodes, cons, dr)
    write_svg(nodes, cons, sv)
    print("wrote %s and %s (%d nodes, %d constellations)" % (dr, sv, len(nodes), len(cons)))


if __name__ == "__main__":
    main()
