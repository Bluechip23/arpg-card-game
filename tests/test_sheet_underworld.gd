extends SceneTree

## Enemy sheet second pass, Underworld & Heavens slice (docs/ENEMY_SHEET.tsv):
##  - Hidden enemies refuse the player's direct hits, cannot be picked or
##    auto-aimed, and still take clock damage and area sweeps.
##  - Specter: Invisible hides it for 3 tempo.
##  - Cherub: the first Love's Arrow flies the moment the player is within 4;
##    every arrow hides it for 5 tempo.
##  - Screecher: unseen from the start, seen for 3 tempo after Screech, drifting
##    2 spaces / 5 tempo while seen instead of 4 / 2.
##  - Demon: at most 2 mimics, each dying to any damage and worth nothing.
##  - Ash Harpy: steals one card without discarding it, returns it on death
##    (past the hand cap) or when swept away.
##  - Magma Spider: Fire Web slows and deals 1 fire every 3 tempo inside.
##  - Mind Eater: Mind Slow hexes every card in hand by 20 until played.
##  - Succubus: chooser and range in a tick loop.
## Run: godot --headless --path . --script tests/test_sheet_underworld.gd

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
	await _test_fight()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _settle(frames: int = 8) -> void:
	for _i in range(frames):
		await process_frame

func _dismiss(main) -> void:
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame

func _first(main, type: int) -> Enemy:
	for e in main.enemy_spawner.get_living_enemies():
		if e.enemy_type == type:
			return e
	return null

func _spawn(main, type: int, cell: Vector2i) -> Enemy:
	return main.enemy_spawner.spawn_enemy(type, main._ground_pos(cell))

func _place(main, cell: Vector2i) -> void:
	main.player.position = main._ground_pos(cell)
	main.player.target_position = main.player.position

func _effect_names(e: Enemy) -> Array:
	var out: Array = []
	for eff in e.get_active_effects():
		out.append(str(eff["name"]))
	return out

func _test_fight() -> void:
	print("-- Booting main.tscn as Hell's Gate (an open hall with no waves) --")
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "hellgate")
	get_root().add_child(main)
	await _settle()
	await _dismiss(main)
	var gm = main.grid_manager
	var dm = main.dungeon_manager
	var stats = main.player.get_stats()
	var pdm = main.player.get_debuff_manager()
	var deck = main.deck_manager
	stats.max_health = 5000
	stats.current_health = 5000
	stats.current_armor = 0

	# A keeper that never moves and never reaches: the room is never "cleared"
	# while the boss and the door are sent away so they cannot interfere.
	var start: Vector2i = dm.player_start
	_place(main, start)
	var keeper: Enemy = _spawn(main, Enemy.EnemyType.MIND_EATER, start + Vector2i(18, 4))
	_check(keeper != null and dm.is_floor(start + Vector2i(18, 4)), "keeper in place")
	var dog: Enemy = _first(main, Enemy.EnemyType.CERBERUS)
	var door: Enemy = _first(main, Enemy.EnemyType.HELL_DOOR)
	if dog:
		main.enemy_spawner.despawn_enemy(dog)
	if door:
		main.enemy_spawner.despawn_enemy(door)
	await _settle(1)

	# ===================== Hidden system + Specter =====================
	print("-- Specter: Invisible --")
	var sp: Enemy = _spawn(main, Enemy.EnemyType.SPECTER, start + Vector2i(3, 0))
	_check(not sp.is_hidden(), "a Specter starts in plain sight")
	_check(sp._try_specter_vanish(), "Invisible fires")
	_check(sp.is_hidden() and sp.hidden_tempo == 3, "hidden for 3 tempo (sheet)")
	_check(not sp._try_specter_vanish(), "already unseen: the Async clock is spent")
	PlayerStats.hit_source_direct = true
	var hp0: int = sp.current_health
	sp.take_damage(3, true)
	_check(sp.current_health == hp0, "a direct player hit finds nothing")
	sp.take_damage(3, false)
	_check(sp.current_health == hp0 - 3, "clock damage (from_player false) lands")
	sp.poison_stacks = 2
	sp._tick_status_durations()
	_check(sp.current_health == hp0 - 5, "a poison tick lands while hidden")
	_check(main.enemy_spawner.get_enemy_at_position(sp.position) == null, "cannot be picked at its square")
	_check(main._get_nearest_enemy() != sp, "the auto-aim skips it")
	_check(main._nearest_enemy_to(main.player.position, main.enemy_spawner.get_living_enemies()) != sp, "summon targeting skips it")
	_check(not main._is_target_in_card_range(Card.create_slash(), sp), "no card has it in range")
	_check("Invisible" in _effect_names(sp), "an Invisible badge shows")
	_check(str(sp.get_effect_tooltip("Invisible")["desc"]).length() > 0, "the badge has a tooltip")
	if sp._enemy_figure and "_sprite" in sp._enemy_figure and sp._enemy_figure._sprite:
		_check(sp._enemy_figure._sprite.modulate.a < 0.5, "the figure is translucent while hidden")
	# Area sweeps still catch it: the radius query marks it, the hit lands.
	var swept: Array = main.enemy_spawner.get_enemies_in_radius(sp.position, 1.0)
	_check(sp in swept, "an area sweep still finds it")
	sp.take_damage(2, true)
	_check(sp.current_health == hp0 - 7, "area damage lands on a hidden enemy")
	await _settle(1)  # the sweep's pass is for that frame only
	sp.take_damage(2, true)
	_check(sp.current_health == hp0 - 7, "next frame a direct hit is refused again")
	sp._tick_timed_statuses(2)
	_check(sp.is_hidden() and sp.hidden_tempo == 1, "two tempo later: still unseen")
	sp._tick_timed_statuses(1)
	_check(not sp.is_hidden(), "the third tempo reveals it")
	_check(main.enemy_spawner.get_enemy_at_position(sp.position) == sp, "visible: picked at its square again")
	sp.take_damage(2, true)
	_check(sp.current_health == hp0 - 9, "visible: direct hits land")
	if sp._enemy_figure and "_sprite" in sp._enemy_figure and sp._enemy_figure._sprite:
		_check(is_equal_approx(sp._enemy_figure._sprite.modulate.a, 1.0), "the figure is solid again")
	PlayerStats.hit_source_direct = false

	# ===================== Cherub =====================
	print("-- Cherub: Love's Arrow --")
	var ch: Enemy = _spawn(main, Enemy.EnemyType.CHERUB, start + Vector2i(7, 0))
	ch.on_tempo_advanced(1, main.player)
	_check(ch._cherub_first_arrow and not ch.is_hidden(), "7 squares away: no arrow yet")
	_place(main, start + Vector2i(3, 0))  # 4 squares from the Cherub
	var php0: int = int(stats.current_health)
	ch.on_tempo_advanced(1, main.player)
	_check(not ch._cherub_first_arrow, "the first arrow flies the moment the player is within 4")
	_check(int(stats.current_health) == php0 - ch.attack_damage, "it hits for %d (sheet 2)" % ch.attack_damage)
	_check(ch.is_hidden() and ch.hidden_tempo == 5, "the Cherub cannot be attacked directly for 5 tempo")
	_check(ch.action_tempo_counter == 0, "the 10-tempo clock starts fresh behind it")
	_check(ch._get_action("loves_arrow")["tempo_cost"] == 10, "Love's Arrow is a 10-tempo attack after that")
	ch._tick_timed_statuses(4)
	_check(ch.is_hidden(), "4 tempo later: still unseen")
	ch._tick_timed_statuses(1)
	_check(not ch.is_hidden(), "5 tempo later: visible")
	_check(ch._try_loves_arrow(main.player) and ch.is_hidden() and ch.hidden_tempo == 5, "every arrow hides it again for 5")
	_place(main, start)

	# ===================== Screecher =====================
	print("-- Screecher: unseen until it strikes --")
	var sc: Enemy = _spawn(main, Enemy.EnemyType.SCREECHER, start + Vector2i(1, 0))
	_check(sc.is_hidden() and sc.hidden_tempo == -1, "a Screecher starts unseen, until revealed")
	_check(main.enemy_spawner.get_enemy_at_position(sc.position) == null, "it cannot be picked")
	_check(int(sc.move_distance) == 4 and sc._effective_cost(sc._get_action("move")) == 2, "Drift unseen: 4 spaces / 2 tempo")
	sc._tick_timed_statuses(10)
	_check(sc.is_hidden(), "time alone never reveals it")
	var shp0: int = int(stats.current_health)
	_check(sc._try_screech(main.player), "Screech lands on the adjacent player")
	_check(int(stats.current_health) == shp0 - sc.attack_damage, "for %d (sheet 5)" % sc.attack_damage)
	_check(not sc.is_hidden() and sc._screecher_visible_tempo == 3, "the strike shows it for 3 tempo")
	_check(int(sc.move_distance) == 2 and sc._effective_cost(sc._get_action("move")) == 5, "Drift seen: 2 spaces / 5 tempo")
	_check(main.enemy_spawner.get_enemy_at_position(sc.position) == sc, "seen: it can be picked")
	sc._tick_timed_statuses(2)
	_check(not sc.is_hidden(), "2 tempo later: still seen")
	sc._tick_timed_statuses(1)
	_check(sc.is_hidden() and sc.hidden_tempo == -1, "3 tempo later: gone again until the next strike")
	_check(int(sc.move_distance) == 4 and sc._effective_cost(sc._get_action("move")) == 2, "and the fast drift is back")

	# ===================== Demon: Mimic =====================
	print("-- Demon: Mimic --")
	var d: Enemy = _spawn(main, Enemy.EnemyType.DEMON, start + Vector2i(4, 3))
	_check(d._try_mimic(main.player), "Mimic conjures a copy")
	d.poison_stacks = 3
	d.take_damage(7, false)
	_check(d._try_mimic(main.player), "and a second")
	_check(not d._try_mimic(main.player), "a third is refused: at most 2 mimics per demon (sheet)")
	_check(d._mimics.size() == 2, "two living mimics tracked")
	var m0: Enemy = d._mimics[0]
	var m1: Enemy = d._mimics[1]
	_check(m0.is_mimic and m0.mimic_of == d and m1.is_mimic and m1.mimic_of == d, "both know their original")
	_check(m0.enemy_name == d.enemy_name and m0.enemy_type == Enemy.EnemyType.DEMON, "a mimic is a Demon by name and kind")
	_check(m0.current_health == d.current_health and m0.max_health == d.max_health, "the health shown is the original's")
	_check(m1.poison_stacks == 3 and m0.poison_stacks == 0, "debuffs carry over as they stand when the copy is made")
	_check(m0.attack_damage == d.attack_damage, "it hits as hard as the original")
	_check(m0.xp_reward == 0 and main.enemy_spawner._generate_loot(m0).is_empty(), "no XP and no loot from a mimic")
	_check(not m1._try_mimic(main.player), "a mimic never mimics")
	d.poison_stacks = 0
	m1.poison_stacks = 0
	d.take_damage(5, false)
	_check(m0.current_health == d.current_health, "the mirror follows the original's wounds")
	m0.take_damage(1, false)
	_check(m0.is_dead, "1 damage kills a mimic")
	_check(d.is_alive(), "the original is untouched")
	_check(d._try_mimic(main.player) and d._mimics.size() == 2, "with one fallen a new mimic may be conjured")
	var alive_before := d._mimics.duplicate()
	d.die()
	_check(alive_before.all(func(m): return m.is_dead), "the copies fall with the original")
	await _settle(1)

	# ===================== Ash Harpy: Card Steal =====================
	print("-- Ash Harpy: Card Steal --")
	pdm.clear_all_debuffs()
	while deck.hand.size() < 3:
		deck.hand.append(Card.create_slash())
	var far_harpy: Enemy = _spawn(main, Enemy.EnemyType.ASH_HARPY, start + Vector2i(3, 1))
	_check(far_harpy._try_card_steal(main.player), "spotted from 3 squares: it flies in")
	_check(far_harpy._stolen_card == null and not far_harpy._harpy_steal_used, "nothing stolen yet from out of melee")
	main.enemy_spawner.despawn_enemy(far_harpy)
	var h: Enemy = _spawn(main, Enemy.EnemyType.ASH_HARPY, start + Vector2i(0, 1))
	var hand0: int = deck.hand.size()
	var discards0: int = deck.discard_pile.size()
	var dc0: int = deck.discards_this_cycle
	var in_hand_before: Array = deck.hand.duplicate()
	_check(h._try_card_steal(main.player), "adjacent: Card Steal fires")
	_check(deck.hand.size() == hand0 - 1 and h._stolen_card != null and h._stolen_card in in_hand_before, "one card leaves the hand into the harpy's claws")
	_check(deck.discard_pile.size() == discards0 and deck.discards_this_cycle == dc0, "it is not a discard")
	_check(h._harpy_steal_used and not h._try_card_steal(main.player), "once per harpy")
	var stolen: Card = h._stolen_card
	while deck.hand.size() < deck.get_hand_cap():
		deck.hand.append(Card.create_slash())
	var cap: int = deck.get_hand_cap()
	h.die()
	_check(stolen in deck.hand and deck.hand.size() == cap + 1, "on death the card returns, past the hand cap (%d/%d)" % [deck.hand.size(), cap])
	_check(h._stolen_card == null, "nothing left in its claws")
	# Swept away without dying (a despawn): the card still comes home.
	var h2: Enemy = _spawn(main, Enemy.EnemyType.ASH_HARPY, start + Vector2i(0, -1))
	var hand1: int = deck.hand.size()
	_check(h2._try_card_steal(main.player) and deck.hand.size() == hand1 - 1, "a second harpy steals")
	main.enemy_spawner.despawn_enemy(h2)
	await _settle(2)
	_check(deck.hand.size() == hand1, "despawned: the card is back")
	await _settle(1)

	# ===================== Mind Eater: Mind Slow =====================
	print("-- Mind Eater: Mind Slow --")
	pdm.clear_all_debuffs()
	var me: Enemy = _spawn(main, Enemy.EnemyType.MIND_EATER, start + Vector2i(5, 0))
	var n: int = deck.hand.size()
	_check(n >= 3, "a hand of %d to tax" % n)
	_check(me._try_mind_slow(main.player), "Mind Slow fires at range 5")
	_check(pdm.get_hexed_debuffs().size() == n, "one Hexed per card in hand (%d)" % n)
	var all_taxed := true
	for i in range(n):
		if pdm.get_hexed_mana_increase(i) != 20:
			all_taxed = false
	_check(all_taxed, "every card costs +20 mana")
	var no_clock := true
	for hx in pdm.get_hexed_debuffs():
		if hx.duration != -1:
			no_clock = false
	_check(no_clock, "the hexes have no clock: until played")
	pdm.advance_time(50)
	_check(pdm.get_hexed_debuffs().size() == n, "50 tempo later they still hold")
	pdm.remove_hexes_on_card(0)
	_check(pdm.get_hexed_debuffs().size() == n - 1, "playing a card lifts only its hex")
	_place(main, start + Vector2i(-1, 0))
	pdm.clear_all_debuffs()
	main.enemy_spawner.despawn_enemy(me)
	_place(main, start)

	# ===================== Succubus =====================
	print("-- Succubus --")
	var su: Enemy = _spawn(main, Enemy.EnemyType.SUCCUBUS, start + Vector2i(6, 0))
	_place(main, start + Vector2i(3, 0))  # 3 squares from the Succubus
	su._choose_action(main.player)
	_check(str(su.chosen_action.get("name", "")) in ["mana_drain", "damaging_snap"], "within 4: Mana Drain or Damaging Snap (%s)" % str(su.chosen_action.get("name", "")))
	_place(main, start)
	_check(su._get_cell_distance(main.player) > 4, "stood 6 away")
	su._reset_action_clocks()
	su._choose_action(main.player)
	# A 4-range caster closes in when out of reach.
	_check(str(su.chosen_action.get("name", "")) == "move", "out of range: it moves")
	_place(main, start + Vector2i(3, 0))
	su._reset_action_clocks()
	var mana0: float = stats.current_mana
	var hps0: int = int(stats.current_health)
	for _t in range(12):
		su.on_tempo_advanced(1, main.player)
	_check(stats.current_mana < mana0 or int(stats.current_health) < hps0, "in a tick loop it drains mana or snaps within 12 tempo")
	main.enemy_spawner.despawn_enemy(su)
	_place(main, start)

	# ===================== Magma Spider: Fire Web =====================
	print("-- Magma Spider: Fire Web --")
	for e in [sp, ch, sc]:
		if is_instance_valid(e):
			main.enemy_spawner.despawn_enemy(e)
	await _settle(1)
	pdm.clear_all_debuffs()
	var wc: Vector2i = start + Vector2i(6, 2)
	var s: Enemy = _spawn(main, Enemy.EnemyType.MAGMA_SPIDER, wc)
	_place(main, wc + Vector2i(1, 0))
	_check(s._try_fire_web(main.player), "Fire Web is laid")
	_check(main._fire_webs.size() == 1 and main._fire_webs[0]["cells"].size() == 9, "one web of the 3x3 around the spider")
	_check(main._fire_webs[0]["nodes"].size() == 9, "each tile wears the fire walls' flame")
	_check(s._try_fire_web(main.player) and main._fire_webs.size() == 1, "a recast lays it afresh: still one web")
	stats.current_armor = 0
	var whp0: int = int(stats.current_health)
	main.tempo_manager.add_tempo(1)
	await _settle(1)
	var slowed = pdm.get_debuff(Debuff.DebuffType.SLOWED)
	_check(slowed != null and slowed.clock_timed, "standing in it: Slowed on the clock")
	_check(int(stats.current_health) == whp0, "no damage yet after 1 tempo")
	main.tempo_manager.add_tempo(1)
	await _settle(1)
	main.tempo_manager.add_tempo(1)
	await _settle(1)
	_check(int(stats.current_health) == whp0 - 1, "1 damage after 3 tempo inside")
	_check(pdm.has_debuff(Debuff.DebuffType.SLOWED), "still Slowed")
	for _t in range(3):
		main.tempo_manager.add_tempo(1)
		await _settle(1)
	_check(int(stats.current_health) == whp0 - 2, "2 damage after 6")
	_place(main, wc + Vector2i(4, 0))
	for _t in range(3):
		main.tempo_manager.add_tempo(1)
		await _settle(1)
	_check(int(stats.current_health) == whp0 - 2, "outside the web: no more ticks")
	_check(not pdm.has_debuff(Debuff.DebuffType.SLOWED), "and the Slowed has run out")
	s.die()
	main.tempo_manager.add_tempo(1)
	await _settle(1)
	_check(main._fire_webs.is_empty(), "the web burns out with the spider")

	main.queue_free()
	await _settle(2)
