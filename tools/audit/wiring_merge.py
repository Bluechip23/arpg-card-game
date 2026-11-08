#!/usr/bin/env python3
"""Phase 2: merge the per-slice wiring reports (docs/audit/wiring/<slice>.md)
into docs/audit/wiring.md — one table, totals per type and status, and every
slice's Flagged list.

Run: python3 tools/audit/wiring_merge.py
"""
import collections
import glob
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SLICES = os.path.join(ROOT, "docs/audit/wiring")
OUT = os.path.join(ROOT, "docs/audit/wiring.md")
STATUSES = ["CORRECT", "FIXED", "MISSING", "FLAGGED", "BLOCKED"]


def status_of(cell):
    up = cell.upper()
    for s in STATUSES:
        if s in up:
            return s
    return cell.strip()


def main():
    rows = []
    flagged = []
    for path in sorted(glob.glob(os.path.join(SLICES, "*.md"))):
        name = os.path.basename(path)[:-3]
        text = open(path).read()
        in_table = False
        for ln in text.split("\n"):
            if ln.startswith("| name") or ln.startswith("|name"):
                in_table = True
                continue
            if in_table and re.match(r"^\|\s*-", ln):
                continue
            if in_table and ln.startswith("|"):
                cells = [c.strip() for c in ln.strip().strip("|").split("|")]
                if len(cells) >= 6:
                    rows.append((name, cells[:6]))
                continue
            if in_table and not ln.startswith("|"):
                in_table = False
        m = re.search(r"^## Flagged.*?\n(.*?)(?=^## |\Z)", text, re.S | re.M)
        if m:
            flagged.append((name, m.group(1).strip()))
    counts = collections.defaultdict(collections.Counter)
    for _, c in rows:
        counts[c[1].strip().lower()][status_of(c[2])] += 1
    L = ["# Phase 2 — wiring audit\n",
         "Every card, item, enemy, summon and passive was read against its stated description, its code path traced (cost, targeting, triggers, stacking, duration, the tempo clock), marked, and **proven by a test**. Eleven slices were audited in parallel; each slice's full notes are in `docs/audit/wiring/<slice>.md`. Regenerate this page with `python3 tools/audit/wiring_merge.py`.\n",
         "**Read with [`pass2.md`](pass2.md).** The second pass re-read every CORRECT row on its edge paths: 106 of them disagree with their text and 20 are unclear. That page gives each one's cause and status; this table still shows pass 1's verdict for those rows.\n",
         "Status: **CORRECT** (code does what the text says) · **FIXED** (was wrong; code changed to match the text) · **MISSING** (described, not built; now built) · **FLAGGED** (the text is unclear or contradicts another system — a question for you below; where a slice also fixed the clear part, the row says so) · **BLOCKED** (too large to fix safely in the audit; plan in `validation.md`). Rows marked *(Phase 6 re-check)* were CORRECT until the independent re-check in `validation.md` found them wrong.\n",
         "## Totals\n",
         "| type | " + " | ".join(STATUSES) + " | total |", "|---|" + "---|" * (len(STATUSES) + 1)]
    grand = collections.Counter()
    for t in sorted(counts):
        c = counts[t]
        grand.update(c)
        L.append("| %s | %s | %d |" % (t, " | ".join(str(c[s]) for s in STATUSES), sum(c.values())))
    L.append("| **all** | %s | **%d** |" % (" | ".join("**%d**" % grand[s] for s in STATUSES), sum(grand.values())))
    L.append("")
    L.append("## FLAGGED — questions for the designer\n")
    for name, body in flagged:
        L.append("### %s\n" % name)
        L.append(body + "\n")
    L.append("## Every entity\n")
    L.append("| name | type | status | what was wrong | what changed | test name |")
    L.append("|---|---|---|---|---|---|")
    for _, c in rows:
        L.append("| " + " | ".join(c) + " |")
    with open(OUT, "w") as fh:
        fh.write("\n".join(L) + "\n")
    print("rows %d; %s" % (len(rows), dict(grand)))


if __name__ == "__main__":
    main()
