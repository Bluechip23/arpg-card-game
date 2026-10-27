extends SceneTree

## The generated figure sprites stay lossless in the editor (2026-10-27): with
## Godot's default "detect 3D" the editor re-imports a texture it sees on a 3D
## sprite as VRAM-compressed, which blurred every new board. Each import file
## under assets/sprites/generated pins lossless with no 3D detection, mipmaps
## on for the smooth twins and off for the pixel sheets; project.godot makes
## no-detection the default for new textures (tools/fix_sprite_imports.py).
## Run: godot --headless --path . --script tests/test_sprite_imports.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	var bad: Array = []
	var count := 0
	for path: String in _imports("res://assets/sprites/generated"):
		count += 1
		var t := FileAccess.get_file_as_string(path)
		var smooth: bool = "/smooth/" in path
		if not "detect_3d/compress_to=0" in t or not "compress/mode=0" in t \
				or not ("mipmaps/generate=%s" % ("true" if smooth else "false")) in t:
			bad.append(path.trim_prefix("res://assets/sprites/generated/"))
	_check(count > 100, "found the generated sprite imports (%d)" % count)
	_check(bad.is_empty(), "all lossless, no 3D detection, mipmaps as their look needs %s" % (str(bad.slice(0, 8)) if not bad.is_empty() else ""))
	var proj := FileAccess.get_file_as_string("res://project.godot")
	_check("[importer_defaults]" in proj and "\"detect_3d/compress_to\": 0" in proj, "new textures default to no 3D detection")
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _imports(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".png.import"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out.append_array(_imports(dir + "/" + sub))
	return out
