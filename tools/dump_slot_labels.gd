extends SceneTree

## Dumps every card the game builds with its slot labels, as JSON, for
## tools/build_slot_sharing.py. Run by that script; by hand:
##   godot --headless --path . --script tools/dump_slot_labels.gd -- <out.json>

func _initialize() -> void:
	var out_path: String = OS.get_cmdline_user_args()[0]
	var seen := {}
	var rows: Array = []
	for c in Card.get_all_cards(false):
		if seen.has(c.card_id):
			continue
		seen[c.card_id] = true
		var labels: Array = []
		for kw in c.slot_labels:
			var n := Card.keyword_name(kw)
			if n != "" and not n in labels:
				labels.append(n)
		rows.append({"name": c.card_name, "id": c.card_id, "labels": labels,
			"engrave": c.requires_engraving})
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(rows))
	f.close()
	quit()
