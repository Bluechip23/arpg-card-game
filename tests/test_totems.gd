extends SceneTree

## The mages' totems (designer, 2026-11-06: "the 5 wizard types (fire, air,
## earth, ice, and shock) all will create their own totems"):
##  - each mage has Raise Totem and raises its own element's totem beside it,
##    one standing at a time, another TOTEM_REBUILD_TEMPO after it is broken;
##  - a totem is a structure in the designer's art, and crumbles when its
##    mage falls. What each does (designer, the same day):
##    Air: its foes' movement drops by 4 - N, N squares from the vortex
##      (each tile costs 4 - N extra tempo);
##    Earth: heals the mage's allies; the totem has thorns;
##    Fire: 3 Burn to every foe within 3 every 5 tempo;
##    Ice: explodes on death for 1 + 1 a tempo it stood, up to 10 (a 10
##      tempo timer: it goes off by itself);
##    Shock: every 5 tempo hits the nearest foe and Shocks all within 4.
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

	# Fire: a mage raises its totem beside it; 3 Burn within 3 every 5 tempo.
	var fm: Enemy = sp.spawn_enemy(Enemy.EnemyType.FIRE_MAGE, main.grid_manager.grid_to_world(start + Vector2i(5, 0)))
	_check(fm._can_raise_totem(5), "a fire mage with its prey close raises its totem first")
	fm._try_raise_totem()
	var ft: Enemy = fm._totem
	_check(ft != null and ft.enemy_type == Enemy.EnemyType.FIRE_TOTEM and ft.totem_owner == fm and ft.is_structure,
		"the Fire Totem stands, and is its")
	_check(not fm._can_raise_totem(5), "one standing at a time")
	if ft:
		_place(main, ft, start + Vector2i(3, 0))
		ft.on_tempo_advanced(5, p)
		var burn = p.get_debuff_manager().get_debuff(Debuff.DebuffType.BURN)
		_check(burn != null and burn.value == 3, "the Fire Totem puts 3 Burn on the hero 3 squares off (%s)" % (burn.value if burn else 0))
		p.get_debuff_manager().clear_all_debuffs()
		_place(main, ft, start + Vector2i(4, 0))
		ft.on_tempo_advanced(5, p)
		_check(not p.get_debuff_manager().has_debuff(Debuff.DebuffType.BURN), "but not 4 squares off")
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
	fm.take_damage(99999, true, DamageTypes.Type.PHYSICAL, true)
	await _settle(4)
	p.get_debuff_manager().clear_all_debuffs()

	# Shock: 1 Shock to every foe within 4, and a hit on the nearest.
	var lm: Enemy = sp.spawn_enemy(Enemy.EnemyType.SPARK_MAGE, main.grid_manager.grid_to_world(start + Vector2i(8, -3)))
	lm._try_raise_totem()
	if lm._totem:
		_place(main, lm._totem, start + Vector2i(4, 0))
		var hp: int = p.get_stats().current_health
		lm._totem.on_tempo_advanced(5, p)
		var sh = p.get_debuff_manager().get_debuff(Debuff.DebuffType.SHOCKED)
		_check(p.get_stats().current_health < hp and sh != null,
			"the Shock Totem hits the hero 4 squares off (%d -> %d) and Shocks him" % [hp, p.get_stats().current_health])
		lm._totem.take_damage(99999, true, DamageTypes.Type.PHYSICAL, true)
	lm.take_damage(99999, true, DamageTypes.Type.PHYSICAL, true)
	await _settle(4)
	p.get_debuff_manager().clear_all_debuffs()
	p.get_stats().current_health = p.get_stats().max_health

	# Earth: heals the mage's allies; thorns on the totem itself.
	var em: Enemy = sp.spawn_enemy(Enemy.EnemyType.EARTH_MAGE, main.grid_manager.grid_to_world(start + Vector2i(9, 4)))
	em._try_raise_totem()
	if em._totem:
		var et: Enemy = em._totem
		em.current_health = em.max_health - 10
		var h0: int = em.current_health
		et.on_tempo_advanced(5, p)
		_check(em.current_health == h0 + Enemy.TOTEM_EARTH_HEAL, "the Earth Totem heals its mage (%d -> %d)" % [h0, em.current_health])
		var t0: int = et.current_health
		et.current_health = et.max_health - 5
		et.on_tempo_advanced(5, p)
		_check(et.current_health == et.max_health - 5, "but not itself")
		var php: int = p.get_stats().current_health
		var was: bool = PlayerStats.hit_source_direct
		PlayerStats.hit_source_direct = true   # the hero's own blow (card, skill, auto attack)
		et.take_damage(3, true, DamageTypes.Type.PHYSICAL, true)
		PlayerStats.hit_source_direct = was
		_check(p.get_stats().current_health == php - Enemy.TOTEM_EARTH_THORNS,
			"its thorns bite back for %d (%d -> %d)" % [Enemy.TOTEM_EARTH_THORNS, php, p.get_stats().current_health])
		et.take_damage(99999, true, DamageTypes.Type.PHYSICAL, true)
	em.take_damage(99999, true, DamageTypes.Type.PHYSICAL, true)
	await _settle(4)
	p.get_stats().current_health = p.get_stats().max_health

	# Ice: explodes on death for 1 + the tempo it stood (to 10); goes off at 10.
	var im: Enemy = sp.spawn_enemy(Enemy.EnemyType.ICE_MAGE, main.grid_manager.grid_to_world(start + Vector2i(6, 3)))
	im._try_raise_totem()
	if im._totem:
		var it: Enemy = im._totem
		_place(main, it, start + Vector2i(2, 0))
		it.on_tempo_advanced(4, p)
		var hp: int = p.get_stats().current_health
		it.take_damage(99999, true, DamageTypes.Type.PHYSICAL, true)
		await _settle(4)
		var lost: int = hp - p.get_stats().current_health
		var want5: int = maxi(1, roundi(5 * it._pps_dmg))   # the level scaling every enemy's set numbers get
		_check(lost == want5, "broken after 4 tempo, the Ice Totem bursts for 1 + 4 = 5, scaled %d (%d)" % [want5, lost])
	p.get_stats().current_health = p.get_stats().max_health
	im._totem_cooldown = 0
	im._try_raise_totem()
	if im._totem:
		var it2: Enemy = im._totem
		_place(main, it2, start + Vector2i(1, 0))
		var hp2: int = p.get_stats().current_health
		it2.on_tempo_advanced(9, p)
		_check(it2.is_alive(), "it stands 9 tempo")
		it2.on_tempo_advanced(1, p)
		await _settle(4)
		var lost2: int = hp2 - p.get_stats().current_health
		var want10: int = mini(p.get_stats().max_health, maxi(1, roundi(10 * it2._pps_dmg)))
		_check(not it2.is_alive() and lost2 == want10, "at 10 it goes off by itself, for 10, scaled %d (%d)" % [want10, lost2])
	p.get_stats().current_health = p.get_stats().max_health
	# The mage falls: its totem crumbles (and an ice one still bursts).
	im._totem_cooldown = 0
	im._try_raise_totem()
	var it3: Enemy = im._totem
	im.take_damage(99999, true, DamageTypes.Type.PHYSICAL, true)
	await _settle(4)
	_check(it3 != null and not it3.is_alive(), "the Ice Mage falls, and its totem crumbles with it")
	p.get_stats().current_health = p.get_stats().max_health

	# Air: each tile moved within the vortex costs 4 - N extra tempo.
	var am: Enemy = sp.spawn_enemy(Enemy.EnemyType.AIR_MAGE, main.grid_manager.grid_to_world(start + Vector2i(10, -4)))
	am._try_raise_totem()
	if am._totem:
		_place(main, am._totem, start)
		await _settle(2)
		var drags: Array = []
		for n in range(1, 6):
			drags.append(main.vortex_drag(start + Vector2i(n, 0)))
		_check(drags == [3, 2, 1, 0, 0], "the vortex drags 3, 2, 1 at one, two, three squares, then nothing (%s)" % [drags])
		var route: Array = [start + Vector2i(2, 0), start + Vector2i(3, 0), start + Vector2i(4, 0)]
		_place(main, p, start + Vector2i(1, 0))
		await _settle(2)
		var with_vortex: int = main.preview_move_tempo(route)
		am._totem.take_damage(99999, true, DamageTypes.Type.PHYSICAL, true)
		await _settle(4)
		var without: int = main.preview_move_tempo(route)
		_check(with_vortex - without == 3 + 2 + 1, "walking out of it costs 3 + 2 + 1 extra tempo (%d vs %d)" % [with_vortex, without])
	main.queue_free()
	await _settle(2)
