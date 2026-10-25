extends SceneTree

## The damage number over an enemy's head (the card hover preview) counts the
## enemy-side modifiers the real hit will meet — Vulnerable, Marked,
## resistances, Brace, armor, Armor Break — and matches what take_damage then
## actually does. Previewing changes nothing on the enemy.
## Run: godot --headless --path . --script tests/test_damage_preview_modifiers.gd

var failures: int = 0
var main = null

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _settle(frames: int = 6) -> void:
	for _i in range(frames):
		await process_frame

func _run() -> void:
	main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	await _settle()
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	var living: Array = main.enemy_spawner.get_living_enemies() if main.enemy_spawner else []
	if main.player == null or living.is_empty():
		_check(false, "the dojo is up with a target")
		_finish()
		return
	var foe: Enemy = living[0]
	foe.max_health = 1000
	foe.current_health = 1000
	foe.current_armor = 0
	foe.damage_resistances = {}
	var slash = main.deck_manager._create_card_from_id("slash")

	var base: int = main.calculate_damage_preview(slash, foe)
	_check(base > 0, "a plain slash previews %d" % base)

	foe.vulnerable_stacks = 1
	var vuln: int = main.calculate_damage_preview(slash, foe)
	_check(vuln == floori(base * 1.3), "Vulnerable: the preview grows 30%% (%d -> %d)" % [base, vuln])
	foe.vulnerable_stacks = 0

	foe.is_marked = true
	var marked: int = main.calculate_damage_preview(slash, foe)
	_check(marked > base, "Marked: the preview grows (%d -> %d)" % [base, marked])
	foe.is_marked = false

	foe.damage_resistances = {DamageTypes.Type.PHYSICAL: 50.0}
	var resisted: int = main.calculate_damage_preview(slash, foe)
	_check(resisted == floori(base * 0.5), "50%% physical resistance halves the preview (%d -> %d)" % [base, resisted])
	foe.damage_resistances = {}

	foe._brace_charges = 2
	var braced: int = main.calculate_damage_preview(slash, foe)
	_check(braced == floori(base * 0.7), "Brace takes 30%% off (%d -> %d)" % [base, braced])
	_check(foe._brace_charges == 2, "previewing spends no Brace charge")
	foe._brace_charges = 0

	foe.current_armor = 4
	foe.vulnerable_stacks = 2
	var split: Dictionary = main.calculate_damage_preview_split(slash, foe)
	_check(split["armor"] == 4 and split["health"] == floori(base * 1.3) - 4,
		"Vulnerable counts before armor: %s" % str(split))

	# The preview matches what the hit then really does, state by state.
	var cases := [
		{"label": "plain", "set": func(): pass},
		{"label": "vulnerable", "set": func(): foe.vulnerable_stacks = 1},
		{"label": "marked", "set": func(): foe.is_marked = true},
		{"label": "resists 25%", "set": func(): foe.damage_resistances = {DamageTypes.Type.PHYSICAL: 25.0}},
		{"label": "braced", "set": func(): foe._brace_charges = 1},
		{"label": "armor 6", "set": func(): foe.current_armor = 6},
		{"label": "vulnerable + marked + armor 3", "set": func():
			foe.vulnerable_stacks = 1
			foe.is_marked = true
			foe.current_armor = 3},
	]
	for c in cases:
		foe.current_health = 1000
		foe.current_armor = 0
		foe.vulnerable_stacks = 0
		foe.is_marked = false
		foe.damage_resistances = {}
		foe._brace_charges = 0
		c["set"].call()
		var hit := 20
		var predicted: Dictionary = foe.preview_player_hit(hit)
		var hp0 := foe.current_health
		var ar0 := foe.current_armor
		PlayerStats.hit_source_direct = true
		foe.take_damage(hit, true)
		var dealt := {"armor": ar0 - foe.current_armor, "health": hp0 - foe.current_health}
		_check(predicted == dealt, "%s: preview %s == real hit %s" % [c["label"], str(predicted), str(dealt)])
	_finish()

func _finish() -> void:
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
