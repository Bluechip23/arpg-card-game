extends SceneTree

## Auto attack: the ~ key arms it like the button does, and the button shows
## the damage number beside the sword from the moment the battle loads.
## Run: godot --headless --path . --script tests/test_auto_attack_hotkey.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Auto attack hotkey test ===")
	_run()

func _run() -> void:
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.starting_character = CharacterData.create_ryan()
	get_root().add_child(main)
	for _i in range(8):
		await process_frame

	# Damage number sits beside the sword icon as soon as the battle is up.
	var expected: int = main._get_basic_attack_display_damage()
	_check(main._attack_damage_label != null and main._attack_damage_label.text == str(expected),
		"attack button shows the damage number on load (%s)" % main._attack_damage_label.text)
	_check(expected >= PlayerStats.BASIC_ATTACK_BASE_DAMAGE, "displayed damage covers the base swing")
	_check(main._attack_button.tooltip_text.contains("[~]"), "tooltip names the ~ hotkey")

	# The ~ key arms the attack; pressing it again disarms.
	var key := InputEventKey.new()
	key.keycode = KEY_QUOTELEFT
	key.pressed = true
	main._input(key)
	_check(main._basic_attack_pending, "~ arms the auto attack")
	main._input(key)
	_check(not main._basic_attack_pending, "~ again disarms it")

	# Shifted variant (~ itself) works too.
	var tilde := InputEventKey.new()
	tilde.keycode = KEY_ASCIITILDE
	tilde.pressed = true
	main._input(tilde)
	_check(main._basic_attack_pending, "shifted ~ also arms the auto attack")
	main._set_basic_attack_pending(false)

	# The readout tracks a stat change on the next tempo step.
	var stats = main.player.get_stats()
	var before: int = int(main._attack_damage_label.text)
	stats.base_strength += 20
	main._update_attack_button_text()
	var after: int = int(main._attack_damage_label.text)
	_check(after > before, "damage number climbs with strength (%d -> %d)" % [before, after])

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
