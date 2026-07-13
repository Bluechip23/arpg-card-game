extends SceneTree

## Unit test for the renamable-character identity layer: character_name is the
## display name the player can change, base_character is the preset identity
## that kits / figures / skill trees key off.
## Run: godot --headless --path . --script tests/test_character_rename.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Character rename test ===")

	# Every preset factory stamps its base identity.
	for c in CharacterData.get_all_characters():
		_check(c.base_character == c.character_name and c.base_character != "",
			"%s preset carries base_character" % c.character_name)

	# Renaming changes the display name but not the identity.
	var brad := CharacterData.create_brad()
	brad.character_name = "Sir Bradley"
	_check(brad.character_name == "Sir Bradley", "display name is renamable")
	_check(brad.get_base_character() == "Brad", "identity survives the rename")

	# Old saves (no base_character) fall back to the display name.
	var old_save := CharacterData.new()
	old_save.character_name = "Stephen"
	_check(old_save.get_base_character() == "Stephen",
		"old saves without base_character fall back to character_name")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
