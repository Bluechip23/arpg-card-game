extends SceneTree

## Loads every .gd under res://scripts so any parse error fails CI instead of
## surfacing at runtime (a broken UI script can slip past suites that never
## load it — this catches the whole tree).
## Run: godot --headless --path . --script tests/test_parse_all.gd

func _initialize() -> void:
	print("=== Parse sweep: res://scripts ===")
	var bad := 0
	var total := 0
	var stack: Array[String] = ["res://scripts"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var d := DirAccess.open(dir_path)
		if d == null:
			continue
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			var p := dir_path + "/" + f
			if d.current_is_dir() and not f.begins_with("."):
				stack.append(p)
			elif f.ends_with(".gd"):
				total += 1
				if load(p) == null:
					bad += 1
					printerr("  FAIL: parse error in " + p)
			f = d.get_next()
		d.list_dir_end()
	print("  checked %d scripts" % total)
	print("=== %d failure(s) ===" % bad)
	quit(1 if bad > 0 else 0)
