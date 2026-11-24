extends SceneTree

## Damage-over-time ticks reach the battle log, on enemies (Burn, Poison,
## Bleed, Shock, Choke) and on the player (Burn, Poison, Drain, Bleed), so a
## number that floats up with nobody swinging is explained.
## Run: godot --headless --path . --script tests/test_dot_log.gd

var failures := 0
var lines: Array[String] = []

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _logged(prefix: String) -> String:
	for l in lines:
		if l.begins_with(prefix):
			return l
	return ""

func _initialize() -> void:
	_run()

func _run() -> void:
	print("=== DOT log test ===")
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(8):
		await process_frame
	while main.olorin and main.olorin.is_busy():
		main.olorin._close()
		await process_frame
	main.battle_logged.connect(func(m: String) -> void: lines.append(m))

	var e: Enemy = null
	for en in main.enemy_spawner.get_living_enemies():
		e = en
		break
	_check(e != null, "an enemy to burn")
	if e:
		e.max_health = 500
		e.current_health = 500
		e.current_armor = 0
		e.apply_debuff("burn", 2)
		e.apply_debuff("poison", 3)
		e.apply_debuff("shock", 1)
		e._tick_burn_poison()       # Burn and Poison: their own 2-tempo tick
		e._tick_status_durations()  # Shock: the 5-tempo cycle
		var b := _logged("Burn: %s takes 7" % e.enemy_name)   # 2 Burn + 3, and 2 more
		_check(b != "" and b.contains("last tick"), "enemy Burn tick logged with what comes next (%s)" % b)
		var p := _logged("Poison: %s takes 3" % e.enemy_name)
		_check(p != "" and p.contains("2 next tick"), "enemy Poison tick logged (%s)" % p)
		_check(_logged("Shock: %s takes 1" % e.enemy_name) != "", "enemy Shock tick logged")
		lines.clear()
		e.current_armor = 5
		e.apply_debuff("burn", 7)
		e._tick_burn_poison()
		var b2 := _logged("Burn: %s takes 12" % e.enemy_name)
		_check(b2.contains("5 to armor") and b2.contains("2 Burn left"), "armor soaking a tick is said (%s)" % b2)
		e.burn_stacks = 0
		e.poison_stacks = 0

	lines.clear()
	var dm = main.player.get_debuff_manager()
	var stats = main.player.get_stats()
	stats.current_health = stats.max_health
	stats.current_armor = 0
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.BURN, 2))
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.POISON, 2))
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.DRAIN, 1))
	dm.process_dot_tick()
	dm.process_turn_start()
	_check(_logged("Burn: you take 7") != "", "player Burn tick logged (%s)" % _logged("Burn"))
	_check(_logged("Poison: you take 2") != "", "player Poison tick logged (%s)" % _logged("Poison"))
	_check(_logged("Drain: you lose 10 mana").contains("last tick"), "player Drain tick logged (%s)" % _logged("Drain"))
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.BLEED, 3))
	dm.on_movement(1)
	_check(_logged("Bleed: you take 1") != "" and _logged("Bleed").contains("2 stack(s) left"), "player Bleed step logged (%s)" % _logged("Bleed"))

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
