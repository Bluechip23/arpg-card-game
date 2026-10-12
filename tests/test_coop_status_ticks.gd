extends SceneTree

## Co-op status ticks (audit item 39): every living partner's per-cycle
## statuses run each cycle against their own managers — not only the
## controlled character's — and the controlled one still ticks exactly once.
## Slowed prices the stepping character's tiles, Marvolo's misunderstanding
## lands on its carrier, and fire walls / the Spiked Web hit whoever stepped in.
## A real second player is spawned headlessly through the sandbox ally path
## (the same co-op pipeline as a two-player start), inside the dojo, whose
## dummies never act.
## Run: godot --headless --path . --script tests/test_coop_status_ticks.gd

var failures := 0
var main

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Co-op status ticks test ===")
	_run()

func _run() -> void:
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	main = packed.instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(6):
		await process_frame

	main._on_sandbox_add_ally("Jeremy")
	await process_frame
	var p1: Player = main._p1_player
	var p2: Player = main._p2_player
	_check(main.is_multiplayer and p2 != null and is_instance_valid(p2), "a second player joins headlessly")
	_check(main._active_index == 0 and main.player == p1, "player 1 starts in control")
	# No timed draws during the test: only Blessed may add cards.
	main.draw_timer.tempo_until_draw = 100000.0

	_test_cycle_effects(p1, p2)
	_test_marvolo(p1, p2)
	_test_slowed_pricing(p1, p2)
	_test_fire_wall(p1, p2)
	_test_spiked_web(p1, p2)

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

## Advance the clock to exactly one cycle boundary.
func _one_cycle() -> void:
	var tm = main.tempo_manager
	tm.add_tempo(tm.tempo_threshold - tm.current_tempo)

func _reset(p: Player) -> void:
	var s: PlayerStats = p.get_stats()
	s.max_health = 500
	s.current_health = 300
	s.current_armor = 0
	s.current_temp_health = 0
	s.temp_health_tempo_remaining = 0
	s.healing_boost_percent = 0.0
	s.healing_boost_tempo = 0
	p.get_buff_manager().buffs.clear()
	p.get_debuff_manager().debuffs.clear()

func _test_cycle_effects(p1: Player, p2: Player) -> void:
	print("-- per-cycle buffs, debuffs and stat timers run for both players --")
	_reset(p1)
	_reset(p2)
	var s1: PlayerStats = p1.get_stats()
	var s2: PlayerStats = p2.get_stats()
	var bm1 = p1.get_buff_manager()
	var bm2 = p2.get_buff_manager()
	_one_cycle()  # settle onto a cycle boundary first

	bm1.apply_buff(Buff.create_regen(3, 100, "Test"))
	bm2.apply_buff(Buff.create_regen(3, 100, "Test"))
	s1.add_temp_health(10, 15)
	s2.add_temp_health(10, 10)
	s1.healing_boost_percent = 0.3
	s1.healing_boost_tempo = 15
	s2.healing_boost_percent = 0.3
	s2.healing_boost_tempo = 10
	var hp1: int = s1.current_health
	var hp2: int = s2.current_health

	_one_cycle()
	var regen2 = bm2.get_buff(Buff.BuffType.REGEN)
	_check(s2.current_health > hp2, "the inactive partner's Regen heals (%d -> %d)" % [hp2, s2.current_health])
	_check(regen2 != null and regen2.value == 2, "the inactive partner's Regen decays 3 -> 2")
	var regen1 = bm1.get_buff(Buff.BuffType.REGEN)
	_check(regen1 != null and regen1.value == 2, "the active player's Regen decays once, not twice (3 -> 2)")
	_check(s1.current_health - hp1 == s2.current_health - hp2,
		"the active player heals one Regen tick, same as the partner (%d vs %d)" % [s1.current_health - hp1, s2.current_health - hp2])
	_check(s2.temp_health_tempo_remaining == 5, "the partner's temp HP timer counts down a cycle (10 -> %d)" % s2.temp_health_tempo_remaining)
	_check(s1.temp_health_tempo_remaining == 10, "the active player's temp HP timer counts down once (15 -> %d)" % s1.temp_health_tempo_remaining)
	_check(s2.healing_boost_tempo == 5, "the partner's Raged Circulation counts down (10 -> %d)" % s2.healing_boost_tempo)
	_check(s1.healing_boost_tempo == 10, "the active player's Raged Circulation counts down once (15 -> %d)" % s1.healing_boost_tempo)

	_one_cycle()
	_check(s2.current_temp_health == 0, "the partner's temp HP expires on time")
	_check(s2.healing_boost_percent == 0.0, "the partner's Raged Circulation expires on time")
	_check(s1.current_temp_health == 10, "the active player's temp HP is still up (one cycle left)")

	# Poison on the partner ticks for the stack count and loses a stack.
	_reset(p1)
	_reset(p2)
	p2.get_debuff_manager().apply_debuff(Debuff.create(Debuff.DebuffType.POISON, 4, 1000))
	var hp_before: int = s2.current_health
	var p1_before: int = s1.current_health
	_one_cycle()
	var poison = p2.get_debuff_manager().get_debuff(Debuff.DebuffType.POISON)
	_check(hp_before - s2.current_health == 4, "the partner's Poison ticks for 4 (%d -> %d)" % [hp_before, s2.current_health])
	_check(poison != null and poison.value == 3, "the partner's Poison loses a stack")
	_check(s1.current_health == p1_before, "the partner's Poison never touches the active player")

	# Blessed: the extra draw lands in the partner's own hand.
	_reset(p1)
	_reset(p2)
	var d1: DeckManager = main._p1_deck_manager
	var d2: DeckManager = main._p2_deck_manager
	while d2.hand.size() > 2:
		d2.discard_pile.append(d2.hand.pop_back())
	var h1: int = d1.hand.size()
	var h2: int = d2.hand.size()
	bm2.apply_buff(Buff.create_blessed(1, 3, "Test"))
	_one_cycle()
	_check(d2.hand.size() == h2 + 1, "the partner's Blessed draws into their own hand (%d -> %d)" % [h2, d2.hand.size()])
	_check(d1.hand.size() == h1, "the active player's hand gets no partner draw (%d -> %d)" % [h1, d1.hand.size()])

func _test_marvolo(p1: Player, p2: Player) -> void:
	print("-- Marvolo's Misunderstanding lands on its carrier --")
	_reset(p1)
	_reset(p2)
	p2.get_debuff_manager().apply_debuff(Debuff.create_generic("Marvolo's Misunderstanding",
		"test", 25, 2, "Marvolo Gaunt"))
	var hp1: int = p1.get_stats().current_health
	var hp2: int = p2.get_stats().current_health
	main.tempo_manager.add_tempo(2)
	_check(hp2 - p2.get_stats().current_health == 25, "the partner takes the 25 when their debuff expires")
	_check(p1.get_stats().current_health == hp1, "the active player is untouched by the partner's Marvolo")

func _test_slowed_pricing(p1: Player, p2: Player) -> void:
	print("-- Slowed prices the moving player's tiles --")
	_reset(p1)
	_reset(p2)
	var tm = main.tempo_manager
	p1.get_stats().flash_movement_enabled = false
	p2.get_stats().flash_movement_enabled = false
	p2.get_debuff_manager().apply_debuff(Debuff.create_slowed(2, "Test"))
	main._switch_active_player()
	_check(main.player == p2, "TAB hands control to the partner")
	_check(tm.debuff_manager == p2.get_debuff_manager(), "the switch re-points Slowed pricing at the partner")
	var before: int = tm.get_global_tempo()
	tm.add_movement_tempo()
	_check(tm.get_global_tempo() - before == Debuff.SLOWED_TEMPO_PER_TILE, "a slowed partner's tile costs %d tempo" % Debuff.SLOWED_TEMPO_PER_TILE)
	main._switch_active_player()
	_check(tm.debuff_manager == p1.get_debuff_manager(), "switching back points pricing at player 1 again")
	before = tm.get_global_tempo()
	tm.add_movement_tempo()
	_check(tm.get_global_tempo() - before == 1, "the unslowed player 1 pays 1 tempo a tile")
	before = tm.get_global_tempo()
	tm.add_movement_tempo(p2.get_debuff_manager())
	_check(tm.get_global_tempo() - before == Debuff.SLOWED_TEMPO_PER_TILE, "the stepper's own Slowed prices the tile when passed in")
	p2.get_debuff_manager().debuffs.clear()

func _test_fire_wall(p1: Player, p2: Player) -> void:
	print("-- a fire wall burns whoever stepped in --")
	_reset(p1)
	_reset(p2)
	var gm = main.grid_manager
	var cell: Vector2i = gm.world_to_grid(p2.position)
	_check(cell != gm.world_to_grid(p1.position), "the partners stand on different tiles")
	main.register_fire_wall([cell], 7, 2)
	# Start on a fresh cycle so the step's own tempo cannot tick the new Burn.
	_one_cycle()
	var hp1: int = p1.get_stats().current_health
	var hp2: int = p2.get_stats().current_health
	# Player 1 is in control; the partner's own step fires the tile handler.
	main._on_player_tile_reached(p2)
	_check(hp2 - p2.get_stats().current_health == 7, "the partner who stepped in takes the wall's 7 (%d -> %d)" % [hp2, p2.get_stats().current_health])
	_check(p2.get_debuff_manager().has_debuff(Debuff.DebuffType.BURN), "the partner is set burning")
	_check(p1.get_stats().current_health == hp1, "the controlled player 1 is not burned")
	_check(not p1.get_debuff_manager().has_debuff(Debuff.DebuffType.BURN), "player 1 carries no Burn")
	for w in main._fire_walls:
		for v in w["visuals"]:
			if is_instance_valid(v):
				v.queue_free()
	main._fire_walls.clear()

func _test_spiked_web(p1: Player, p2: Player) -> void:
	print("-- the Spiked Web snares whoever sprang it --")
	_reset(p1)
	_reset(p2)
	var cell: Vector2i = main.grid_manager.world_to_grid(p2.position)
	var hp1: int = p1.get_stats().current_health
	var hp2: int = p2.get_stats().current_health
	main._spring_trap({"kind": "web", "tiles": [cell]}, p2, true)
	_check(p2.get_stats().current_health < hp2, "the partner takes the web's damage")
	_check(p2.get_debuff_manager().has_debuff(Debuff.DebuffType.SLOWED), "the partner is Slowed by the web")
	_check(p1.get_stats().current_health == hp1 and not p1.get_debuff_manager().has_debuff(Debuff.DebuffType.SLOWED),
		"player 1 is neither hit nor slowed")
