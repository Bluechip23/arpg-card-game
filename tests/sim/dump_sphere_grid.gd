extends SceneTree

## Dumps the sphere grid the game builds (every node with its on-screen
## position, type, text, stat gate, keystone and connections, plus the
## constellations) to sim_out/sphere_grid.json, for
## tools/sphere_grid_export.py (an editable draw.io diagram).
## Run: godot --headless --path . --script tests/sim/dump_sphere_grid.gd
func _initialize():
	var grid := SphereGrid.new()
	var nodes: Array = []
	for n in grid.get_all_nodes():
		nodes.append({"id": n.id, "type": SphereGrid.NodeType.keys()[n.node_type], "label": n.label,
			"description": n.description, "ring": n.ring, "requirements": n.requirements,
			"keystone": n.keystone_id, "connections": n.connections, "x": n.position.x, "y": n.position.y})
	var cons: Array = []
	for c in grid.constellations:
		cons.append({"id": c.id, "name": c.name, "nodes": c.node_ids, "bonus": c.bonus_name, "bonus_description": c.bonus_description})
	var f = FileAccess.open("res://sim_out/sphere_grid.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"nodes": nodes, "constellations": cons}, "  "))
	f.close()
	print("DUMPED ", nodes.size(), " nodes ", cons.size(), " constellations")
	quit()
