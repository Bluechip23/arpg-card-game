extends SceneTree

## The mages' totems (designer, 2026-11-06: "the 5 wizard types (fire, air,
## earth, ice, and shock) all will create their own totems"):
##  - each mage has Raise Totem and raises its own element's totem beside it,
##    one standing at a time, another TOTEM_REBUILD_TEMPO after it is broken;
##  - a totem is a structure in the designer's art that pulses its element
##    every cycle (first pass): fire Burns, ice Slows, lightning strikes the
##    nearest foe, earth armors its allies, air blows foes back;
##  - it crumbles when its mage falls.
## Run: godot --headless --path . --script tests/test_totems.gd

var failures: int = 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	_test_tables()
	await _test_in_game()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

const PAIRS := {
	"AIR_MAGE": ["AIR_TOTEM", "air_totem"],
	"EARTH_MAGE": ["EARTH_TOTEM", "earth_totem"],
	"SPARK_MAGE": ["LIGHTNING_TOTEM", "lightning_totem"],
	"FIRE_MAGE": ["FIRE_TOTEM", "fire_totem"],
	"ICE_MAGE": ["ICE_TOTEM", "ice_totem"],
}

func _test_tables() -> void:
	print("-- the five mages and their totems --")
	for mage in PAIRS:
		var mt: int = Enemy.EnemyType[mage]
		var tt: int = Enemy.EnemyType[PAIRS[mage][0]]
		var e := Enemy.new()
		e.initialize(mt)
		var names: Array = []
		for a in e.actions:
			names.append(a["name"])
		_check("raise_totem" in names, "%s can Raise Totem" % mage)
		_check(Enemy.MAGE_TOTEMS[mt] == tt, "%s raises the %s" % [mage, PAIRS[mage][0]])
		e.free()
		var d: Dictionary = EnemyDefs.DEFS[PAIRS[mage][0]]
		_check(d["is_structure"] and d["xp"] == 0 and d["figure_kind"] == PAIRS[mage][1], "%s is a structure in its own figure" % d["name"])
		_check(ResourceLoader.exists("res://assets/sprites/generated/sheets/%s/Idle.png" % PAIRS[mage][1]), "%s has the designer's art" % d["name"])

func _settle(frames: int = 8) -> void:
	for _i in range(frames):
		await process_frame

func _place(main, e: Node3D, cell: Vector2i) -> void:
	var w: Vector3 = main.grid_manager.grid_to_world(cell)
	e.position = w
	if "target_position" in e:
		e.target_position = w

func _test_in_game() -> void:
	print("-- in Thanatos's Hall's open floor --")
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_world_level", 2)
	main.set("current_interior_id", "thanatoshall")
	get_root().add_child(main)
	await _settle(20)
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	var p = main.player
	var dm = main.dungeon_manager
	var start: Vector2i = dm.player_start + Vector2i(2, 0)
	_place(main, p, start)
	await _settle(2)
	var sp = main.enemy_spawner

	# Fire: a mage raises its totem beside it; it Burns whoever is within 3.
	var fm: Enemy = sp.spawn_enemy(Enemy.EnemyType.FIRE_MAGE, main.grid_manager.grid_to_world(start + Vector2i(5, 0)))
	_check(fm._can_raise_totem(5), "a fire mage with its prey close raises its totem first")
	fm._try_raise_totem()
	var ft: Enemy = fm._totem
	_check(ft != null and ft.enemy_type == Enemy.EnemyType.FIRE_TOTEM and ft.totem_owner == fm and ft.is_structure,
		"the Fire Totem stands, and is its")
	_check(not fm._can_raise_totem(5), "one standing at a time")
	if ft:
		_place(main, ft, start + Vector2i(2, 0))
		ft.on_tempo_advanced(5, p)
		_check(p.get_debuff_manager().has_debuff(Debuff.DebuffType.BURN), "the Fire Totem Burns the hero within 3 squares")
		ft.take_damage(99999, true, DamageTypes.Type.PHYSICAL, true)
		await _settle(4)
		_check(not fm.has_totem() and fm._totem_cooldown == Enemy.TOTEM_REBUILD_TEMPO and not fm._can_raise_totem(5),
			"broken, it leaves its mage %d tempo to raise another" % Enemy.TOTEM_REBUILD_TEMPO)
		fm.on_tempo_advanced(Enemy.TOTEM_REBUILD_TEMPO, p)
		await _settle(4)
		_check(fm._totem_cooldown == 0 and (fm.has_totem() or fm._can_raise_totem(5)),
			"and then it may (raised again: %s)" % fm.has_totem())
		if fm.has_totem():
			fm._totem.take_damage(99999, true, DamageTypes.Type.PHYSICAL, true)
	p.get_debuff_manager().clear_all_debuffs()

	# Ice: Slows.
	var im: Enemy = sp.spawn_enemy(Enemy.EnemyType.ICE_MAGE, main.grid_manager.grid_to_world(start + Vector2i(6, 3)))
	im._try_raise_totem()
	if im._totem:
		_place(main, im._totem, start + Vector2i(0, 3))
		im._totem.on_tempo_advanced(5, p)
		_check(p.get_debuff_manager().is_slowed(), "the Ice Totem Slows the hero within 3 squares")
	# The mage falls: its totem crumbles.
	var it: Enemy = im._totem
	im.take_damage(99999, true, DamageTypes.Type.PHYSICAL, true)
	await _settle(4)
	_check(it != null and not it.is_alive(), "the Ice Mage falls, and its totem crumbles with it")
	p.get_debuff_manager().clear_all_debuffs()

	# Lightning: strikes the nearest foe within 5.
	var lm: Enemy = sp.spawn_enemy(Enemy.EnemyType.SPARK_MAGE, main.grid_manager.grid_to_world(start + Vector2i(8, -3)))
	lm._try_raise_totem()
	if lm._totem:
		_place(main, lm._totem, start + Vector2i(4, 0))
		var hp: int = p.get_stats().current_health
		lm._totem.on_tempo_advanced(5, p)
		_check(p.get_stats().current_health < hp and p.get_debuff_manager().has_debuff(Debuff.DebuffType.SHOCKED),
			"the Lightning Totem strikes the hero 4 squares off (%d -> %d) and Shocks him" % [hp, p.get_stats().current_health])
		lm._totem.take_damage(99999, true, DamageTypes.Type.PHYSICAL, true)
	p.get_debuff_manager().clear_all_debuffs()

	# Earth: armors its allies within 3, up to 15 over their own.
	var em: Enemy = sp.spawn_enemy(Enemy.EnemyType.EARTH_MAGE, main.grid_manager.grid_to_world(start + Vector2i(9, 4)))
	em._try_raise_totem()
	if em._totem:
		var a0: int = em.current_armor
		em._totem.on_tempo_advanced(5, em._last_seen_target if em._last_seen_target else p)
		_check(em.current_armor == a0 + Enemy.TOTEM_ARMOR, "the Earth Totem armors its mage (%d -> %d)" % [a0, em.current_armor])
		for _i in range(10):
			em._totem.on_tempo_advanced(5, p)
		_check(em.current_armor == em.max_armor + Enemy.TOTEM_ARMOR_CAP, "up to %d over its own (%d)" % [Enemy.TOTEM_ARMOR_CAP, em.current_armor])
		em._totem.take_damage(99999, true, DamageTypes.Type.PHYSICAL, true)

	# Air: blows the hero 2 squares straight back.
	var am: Enemy = sp.spawn_enemy(Enemy.EnemyType.AIR_MAGE, main.grid_manager.grid_to_world(start + Vector2i(10, -4)))
	am._try_raise_totem()
	if am._totem:
		_place(main, am._totem, start + Vector2i(1, 0))
		await _settle(2)
		am._totem.on_tempo_advanced(5, p)
		var dest: Vector2i = main.grid_manager.world_to_grid(p.target_position)
		_check(dest == start - Vector2i(2, 0), "the Air Totem blows the hero 2 squares back (%s -> %s)" % [start, dest])
	main.queue_free()
	await _settle(2)
