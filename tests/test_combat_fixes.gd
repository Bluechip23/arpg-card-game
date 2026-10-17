extends SceneTree

## Three combat fixes through the real Main scene: an ally encased by
## Cryonics is no target (enemies wait out the ice; no blow lands on it);
## damage the armor takes floats above the enemy's head too, grey, and a
## split hit reads "armor/health"; and the tempo speed the player picks
## comes up again in every fresh TempoManager (a new area, town, a portal).
## Run: godot --headless --path . --script tests/test_combat_fixes.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: " + msg)
	else:
		print("  FAIL: " + msg)
		failures += 1

func _initialize() -> void:
	_run.call_deferred()

func _labels(parent: Node) -> Array:
	return parent.get_children().filter(func(c): return c is Label3D and c.get_parent() == parent and not c.name.begins_with("@") == false and c.billboard == BaseMaterial3D.BILLBOARD_ENABLED)

func _run() -> void:
	print("=== Combat fixes test ===")
	var runner := SimRunner.new(self)
	var sc := SimScenario.with_defaults(CharacterBuilds.compose("ryan", {"build": "bruiser", "enemy": "LARGE_BEAR"}))
	await runner.boot_only(sc, 1)
	var main = runner.main
	var stats = main.player.get_stats()
	var bear = main.enemy_spawner.get_living_enemies()[0]

	# --- Cryonics: iced = untargetable, even alone.
	_check(main.enemy_spawner._target_for(bear) == main.player, "alone, the player is the bear's target")
	main.player.untargetable = true
	_check(main.enemy_spawner._target_for(bear) == null, "iced, the bear has no target at all")
	var hp0: int = stats.current_health
	var armor0: int = stats.get_total_armor()
	bear._deal_damage_to_player(main.player, 30, "Maul")
	_check(stats.current_health == hp0 and stats.get_total_armor() == armor0, "a blow at the iced player lands nothing (%d hp, %d armor)" % [stats.current_health, stats.get_total_armor()])
	bear.on_tempo_advanced(6, main.enemy_spawner._target_for(bear))
	_check(stats.current_health == hp0, "six tempo of bear with no target: still untouched")
	main.player.untargetable = false
	bear._deal_damage_to_player(main.player, 30, "Maul")
	_check(stats.current_health + stats.get_total_armor() < hp0 + armor0, "thawed, the same blow lands")

	# --- Damage numbers: armor-only, split, and health-only.
	var world: Node = bear.get_parent()
	var before: int = world.get_children().filter(func(c): return c is Label3D).size()
	bear.current_armor = 50
	bear.max_armor = 50
	bear.take_damage(12, true)
	await process_frame
	var added: Array = world.get_children().filter(func(c): return c is Label3D).slice(before)
	_check(added.size() == 1 and added[0].text == "12" and added[0].modulate.is_equal_approx(bear.ARMOR_NUMBER_COLOR),
		"12 into armor floats a grey 12 (%s)" % str(added.map(func(l): return l.text)))
	before = world.get_children().filter(func(c): return c is Label3D).size()
	bear.current_armor = 5
	bear.take_damage(12, true)
	await process_frame
	added = world.get_children().filter(func(c): return c is Label3D).slice(before)
	var texts: Array = added.map(func(l): return l.text)
	# (the 5 armor is stripped by the hit: the health half carries the "!")
	_check(added.size() == 2 and texts.has("5/") and texts.has("7!"), "12 into 5 armor floats '5/' and '7!' (%s)" % str(texts))
	if added.size() == 2:
		var left = added[texts.find("5/")]
		var right = added[texts.find("7!")]
		_check(left.modulate.is_equal_approx(bear.ARMOR_NUMBER_COLOR) and not right.modulate.is_equal_approx(bear.ARMOR_NUMBER_COLOR),
			"the armor half is grey, the health half is not")
		_check(left.offset.x < 0.0 and right.offset.x > 0.0 and left.font_size == right.font_size and left.font_size < 28,
			"they sit side by side, a little smaller (%d px)" % left.font_size)
	before = world.get_children().filter(func(c): return c is Label3D).size()
	bear.take_damage(12, true)
	await process_frame
	added = world.get_children().filter(func(c): return c is Label3D).slice(before)
	_check(added.size() == 1 and added[0].text == "12" and not added[0].modulate.is_equal_approx(bear.ARMOR_NUMBER_COLOR),
		"12 into bare health floats a red 12 as before")

	# --- Tempo speed: remembered across TempoManagers (scene changes).
	var was: float = TempoManager.preferred_tick_speed
	main._on_tick_speed_changed(0.375)
	_check(main.tempo_manager.tick_speed == 0.375, "the player picks fast forward")
	var fresh := TempoManager.new()
	fresh.initialize(stats)
	_check(fresh.tick_speed == 0.375, "a fresh TempoManager (the next area) comes up at that speed (%.3f)" % fresh.tick_speed)
	var cfg := ConfigFile.new()
	_check(cfg.load(TempoManager.SETTINGS_PATH) == OK and float(cfg.get_value("tempo", "tick_speed", -1.0)) == 0.375,
		"and it is written to the settings file")
	fresh.free()
	# Leave the setting as it was for the next test run.
	if was > 0.0:
		TempoManager.remember_tick_speed(was)
	else:
		TempoManager.preferred_tick_speed = -1.0
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TempoManager.SETTINGS_PATH))

	runner.teardown()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
