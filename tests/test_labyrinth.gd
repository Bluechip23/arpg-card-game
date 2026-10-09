extends SceneTree

## The Labyrinth — the Inflamed Minotaur's boss room.
##  - Layout: a square maze of two-wide passages (cave-pack rock) around an
##    open court with lava in its corners, off the deepest cave of the second
##    world; entered from the west; sealed until the Minotaur is dead.
##  - The Minotaur (boss sheet, level 9): 350 HP / 100 armor / 35 + 2 Burn;
##    resists 15 / 50 / 25; Labyrinth Leap once he has taken over 20 damage
##    since his last leap, a running total (14 spaces, one fewer per Slow), Bull Rush a cycle later (Vulnerable, fire along the
##    lane), fire in his wake that heals him 10 when it burns a player.
##  - Lost in the Labyrinth: every 25 tempo the hand is scrambled, must be
##    played left to right, and nothing can be drawn, for 15 tempo. The curse
##    lifts when the Minotaur dies, and his death opens the way out.
## Run: godot --headless --path . --script tests/test_labyrinth.gd

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
	_test_layout()
	await _test_fight()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _build(interior: String, level: int = 2, cleared: Array = []) -> DungeonManager:
	var holder = Node3D.new()
	get_root().add_child(holder)
	var gm = GridManager.new()
	holder.add_child(gm)
	var parent = Node3D.new()
	holder.add_child(parent)
	var dm = DungeonManager.new()
	holder.add_child(dm)
	dm._opened_chests_ref = {}
	dm.cleared_bosses = cleared
	dm.initialize(gm, parent, level, interior)
	return dm

func _reachable(dm: DungeonManager, from: Vector2i, to: Vector2i) -> bool:
	## Breadth-first over walkable floor (walls and lava block).
	var seen := {from: true}
	var queue: Array = [from]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == to:
			return true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if seen.has(n) or not dm.is_floor(n) or dm.is_water(n):
				continue
			seen[n] = true
			queue.append(n)
	return false

func _test_layout() -> void:
	print("-- The Labyrinth layout --")
	var dm := _build("labyrinth")
	_check(dm.interior_kind == "labyrinth" and dm.get_location_name() == "The Labyrinth", "the Labyrinth is its own interior kind")
	_check(dm.GRID_W == dm.LB_SIZE and dm.GRID_H == dm.LB_SIZE, "a %dx%d square" % [dm.GRID_W, dm.GRID_H])
	_check(dm.is_floor(dm.player_start) and dm.player_start.x == 1, "entered from the west")
	_check(dm.get_site_by_id("exit") < 0, "sealed: no way out while the Minotaur lives")
	var court_open := true
	var lava := 0
	for x in range(dm.LB_COURT.position.x, dm.LB_COURT.end.x):
		for z in range(dm.LB_COURT.position.y, dm.LB_COURT.end.y):
			if not dm.is_floor(Vector2i(x, z)):
				court_open = false
			if dm.is_water(Vector2i(x, z)):
				lava += 1
	_check(court_open, "the court at the heart is open")
	_check(lava == 16 and dm.water_texture_path().ends_with("water_lava.png"), "four lava pools in its corners (%d tiles)" % lava)
	_check(dm.is_floor(dm.labyrinth_minotaur_cell) and not dm.is_water(dm.labyrinth_minotaur_cell) and dm.LB_COURT.has_point(dm.labyrinth_minotaur_cell),
		"the Minotaur's post is dry ground in the court")
	var inner_walls := 0
	for x in range(1, dm.GRID_W - 1):
		for z in range(1, dm.GRID_H - 1):
			if not dm.is_floor(Vector2i(x, z)):
				inner_walls += 1
	_check(inner_walls > 150, "a maze: %d wall tiles inside the border" % inner_walls)
	_check(_reachable(dm, dm.player_start, dm.labyrinth_minotaur_cell), "the passages lead from the gate to the court")
	_check(dm.floor_texture_path().ends_with("floor_cave.png") and dm.wall_texture_path().ends_with("wall_cave.png"), "dressed in the cave pack's rock")
	# Deterministic: the same seed lays the same maze.
	var again := _build("labyrinth")
	var same := true
	for x in range(dm.GRID_W):
		for z in range(dm.GRID_H):
			if dm.is_floor(Vector2i(x, z)) != again.is_floor(Vector2i(x, z)):
				same = false
	_check(same, "the maze is the same every visit")
	var opened := _build("labyrinth", 2, ["labyrinth"])
	_check(opened.get_site_by_id("exit") >= 0, "a cleared Labyrinth opens from the start")
	# The door: the deepest cave of the second world — and only there.
	var cave := _build("cave_0", 2)
	var idx := cave.get_site_by_id("labyrinth")
	_check(idx >= 0, "the second world's cave has the door to the Labyrinth")
	if idx >= 0:
		var in_deep := false
		for room in cave.rooms:
			if room["kind"] == "deep" and (room["rect"] as Rect2i).has_point(cave.site_nodes[idx]["grid_pos"]):
				in_deep = true
		_check(in_deep, "in its deepest chamber")
	_check(cave.get_site_by_id("hellgate") < 0, "and no second Hell's Gate there")
	_check(_build("cave_0", 1).get_site_by_id("labyrinth") < 0 and _build("cave_0", 3).get_site_by_id("labyrinth") < 0,
		"the first and third worlds' caves do not")

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

func _tempo(main, n: int) -> void:
	for _t in range(n):
		main.tempo_manager.add_tempo(1)
	await _settle(1)

func _test_fight() -> void:
	print("-- Booting main.tscn as the Labyrinth --")
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_world_level", 2)
	main.set("current_interior_id", "labyrinth")
	get_root().add_child(main)
	await _settle()
	await _dismiss(main)
	_check(main.boss_room_mode, "the scene knows it is a boss room")
	var bull: Enemy = _first(main, Enemy.EnemyType.INFLAMED_MINOTAUR)
	_check(bull != null, "the Minotaur is up")
	if bull == null:
		main.queue_free()
		return
	var gm = main.grid_manager
	var dm = main.dungeon_manager
	_check(gm.world_to_grid(bull.position) == dm.labyrinth_minotaur_cell, "waiting in the court")
	var pps: Dictionary = Enemy.passive_power_scale(9)
	_check(bull.max_health == roundi(350 * pps["hp"]) and bull.max_armor == roundi(100 * pps["hp"]) and bull.attack_damage == roundi(35 * pps["dmg"]),
		"the boss sheet's numbers (%d HP, %d armor, %d attack)" % [bull.max_health, bull.max_armor, bull.attack_damage])
	_check(bull.attack_burn == 2 and bull.move_distance == 6.0, "+2 Burn on hit, 6 spaces a move")
	_check(bull.damage_resistances.get(DamageTypes.Type.PHYSICAL, 0) == 15 and bull.damage_resistances.get(DamageTypes.Type.FIRE, 0) == 50 and bull.damage_resistances.get(DamageTypes.Type.LIGHTNING, 0) == 25,
		"resists 15 / 50 / 25")
	_check(main.enemy_spawner.get_loot_tier(Enemy.EnemyType.INFLAMED_MINOTAUR) == DropRates.TIER_BOSS, "rolls boss loot")

	var stats = main.player.get_stats()
	stats.max_health = 5000
	stats.current_health = 5000
	var pdm = main.player.get_debuff_manager()
	var deck = main.deck_manager

	# --- Labyrinth Leap: a hit over 20 springs him away; Slow shortens it ---
	var bcell: Vector2i = gm.world_to_grid(bull.position)
	main.player.position = main._ground_pos(bcell + Vector2i(-1, 0))
	main.player.target_position = main.player.position
	bull.take_damage(12, true, DamageTypes.Type.PHYSICAL, true)
	bull.take_damage(8, true, DamageTypes.Type.PHYSICAL, true)
	_check(not bull._minotaur_rush_pending and gm.world_to_grid(bull.position) == bcell and bull._minotaur_damage_taken == 20,
		"12 then 8: twenty damage taken, he holds his ground")
	bull.take_damage(1, true, DamageTypes.Type.PHYSICAL, true)
	var leap_cell: Vector2i = gm.world_to_grid(bull.position)
	_check(bull._minotaur_rush_pending and bull._minotaur_leap_spaces == 14 and leap_cell != bcell,
		"one more point: over 20 in total — Labyrinth Leap, 14 spaces, Bull Rush armed")
	_check(bull._minotaur_damage_taken == 0, "the count starts over after a leap")
	bull.take_damage(30, true, DamageTypes.Type.PHYSICAL, true)
	_check(bull._minotaur_rush_pending and gm.world_to_grid(bull.position) == leap_cell and bull._minotaur_damage_taken == 30,
		"with a Bull Rush owed he does not leap again, but the damage keeps counting")
	_check(dm.is_floor(leap_cell) and not dm.is_water(leap_cell), "he lands on open floor")
	var rush_delay: int = int(bull.chosen_action.get("tempo_cost", 0))
	_check(bull.chosen_action.get("name", "") == "bull_rush" and rush_delay >= 5 and rush_delay <= 15 and bull.action_tempo_counter == 0,
		"the rush comes a random 5 to 15 tempo after landing (%d)" % rush_delay)

	# --- Bull Rush: Vulnerable, damage by the ground covered, fire along the lane ---
	# A known run-up: the bull at the court's east side, the player at its west.
	var court_c: Vector2i = dm.labyrinth_minotaur_cell
	bull.position = main._ground_pos(court_c + Vector2i(4, 0))
	bull.target_position = bull.position
	main.player.position = main._ground_pos(court_c + Vector2i(-3, 0))
	main.player.target_position = main.player.position
	main._sync_occupied_tiles()
	var hp0: int = stats.current_health
	var armor0: int = stats.current_armor
	pdm.clear_all_debuffs()
	var walls0: int = main._fire_walls.size()
	bull._try_bull_rush(main.player)
	var dealt: int = (hp0 - stats.current_health) + (armor0 - stats.current_armor)
	_check(not bull._minotaur_rush_pending and dealt == roundi((14 + 6) * pps["dmg"]),
		"Bull Rush: 14 leapt + 6 charged = %d damage (dealt %d)" % [roundi((14 + 6) * pps["dmg"]), dealt])
	_check(gm.world_to_grid(bull.position) == court_c + Vector2i(-2, 0), "he ends beside his target")
	_check(pdm.has_debuff(Debuff.DebuffType.VULNERABLE), "the target is left Vulnerable")
	_check(main._fire_walls.size() > walls0, "fire burns in the lane behind the charge")
	var rush_cell: Vector2i = gm.world_to_grid(bull.position)
	_check(bull._wake_prev_cell == rush_cell, "his trail picks up again from where the charge ends")

	# Slow is his weakness: every stack takes a space off the leap. (The 30
	# counted during the rush is still on the books: one more point leaps.)
	bull.slow_stacks = 14
	var pre: Vector2i = gm.world_to_grid(bull.position)
	bull.take_damage(1, true, DamageTypes.Type.PHYSICAL, true)
	_check(bull._minotaur_rush_pending and bull._minotaur_leap_spaces == 0 and gm.world_to_grid(bull.position) == pre,
		"14 Slow: the leap covers no ground at all")
	bull.slow_stacks = 0
	bull._minotaur_rush_pending = false
	bull.chosen_action = {}

	# --- His wake heals him ---
	bull.current_health = 100
	main.register_fire_wall([Vector2i(5, 5)], 10, 2, 99, 15, bull, 10)
	main._check_fire_walls(Vector2i(5, 5))
	_check(bull.current_health == 110, "fire from his wake that burns a player heals him 10")

	# --- Lost in the Labyrinth: every 25 tempo, for 15 ---
	# Keep him parked so his own moves don't muddy the clock.
	bull.rooted_tempo = 999
	main.player.position = main._ground_pos(dm.player_start)
	main.player.target_position = main.player.position
	pdm.clear_all_debuffs()
	main._labyrinth_tempo = 0
	# A hand with something in it to scramble.
	while deck.hand.size() < 4 and deck.draw_card() != null:
		pass
	await _settle(1)
	await _tempo(main, 24)
	_check(not pdm.is_lost(), "24 tempo in: not yet")
	await _tempo(main, 1)
	_check(pdm.is_lost(), "25 tempo in: Lost in the Labyrinth")
	var lost: Debuff = pdm.get_debuff(Debuff.DebuffType.LOST)
	_check(lost != null and lost.duration == 15 and lost.debuff_name == "Lost in the Labyrinth", "for 15 tempo, by name")
	_check(Card.labyrinth_lost, "the hand knows it")
	# The hand is laid out one card per slot, in order, and only the first
	# card in line may be played.
	_check(main._hand_groups.size() == deck.hand.size(), "no stacks: one slot per card in hand order (%d)" % deck.hand.size())
	var ordered := true
	for i in range(main._hand_groups.size()):
		if main._hand_groups[i]["rep"] != deck.hand[i]:
			ordered = false
	_check(ordered, "left to right is the hand's order")
	var first: Card = null
	var first_idx := -1
	for i in range(deck.hand.size()):
		if deck.hand[i].card_type != Card.CardType.REACTION and not deck.hand[i].is_jailed():
			first = deck.hand[i]
			first_idx = i
			break
	_check(first != null and first.world_block_reason() == "", "the first card in line may be played")
	var others_blocked: bool = deck.hand.size() > 1
	for i in range(deck.hand.size()):
		if i == first_idx or deck.hand[i].card_type == Card.CardType.REACTION:
			continue
		if deck.hand[i].world_block_reason() == "":
			others_blocked = false
	_check(others_blocked, "every card behind it is refused until its turn")
	# No draws of any kind.
	var hand_n: int = deck.hand.size()
	_check(deck.draw_card() == null and deck.hand.size() == hand_n, "a card's draw effect draws nothing")
	deck.attempt_draw()
	_check(deck.hand.size() == hand_n, "the tempo draw draws nothing")
	_check(not pdm.can_draw_cards(), "the draw gate reads shut")
	# Playing the first card frees the next one.
	if first != null and deck.hand.size() > 1:
		deck.hand.erase(first)
		deck.discard_pile.append(first)
		deck.hand_updated.emit()
		await _settle(1)
		var next_free := false
		for c in deck.hand:
			if c.card_type != Card.CardType.REACTION and not c.is_jailed() and c.world_block_reason() == "":
				next_free = true
				break
		_check(next_free, "once it is played, the next card in line is free")
	# It lifts after 15 tempo, and the stacks and draws come back.
	await _tempo(main, 14)
	_check(pdm.is_lost(), "14 tempo later it still holds")
	await _tempo(main, 1)
	_check(not pdm.is_lost() and not Card.labyrinth_lost and Card.labyrinth_next_card == null, "15 tempo later it lifts")
	var free_all := true
	for c in deck.hand:
		if c.card_type != Card.CardType.REACTION and not c.is_jailed() and c.world_block_reason() != "":
			free_all = false
	_check(free_all, "every card may be played again")
	while deck.hand.size() >= deck.get_hand_cap():
		deck.discard_pile.append(deck.hand.pop_back())
	hand_n = deck.hand.size()
	_check(deck.draw_card() != null and deck.hand.size() == hand_n + 1, "and draws work again")
	# The maze takes hold again 10 tempo after that (25 from the last).
	await _tempo(main, 10)
	_check(pdm.is_lost(), "every 25 tempo: it returns")

	# --- The Minotaur dies: the hold breaks and the way out opens ---
	bull.take_damage(100000, true, DamageTypes.Type.PHYSICAL, true)
	await _settle(2)
	_check(not bull.is_alive(), "the Minotaur falls")
	_check(not pdm.is_lost() and not Card.labyrinth_lost, "his death breaks the Labyrinth's hold")
	_check(dm.get_site_by_id("exit") >= 0, "the way out opens")
	_check(main.current_character.has_defeated_boss("labyrinth"), "the Labyrinth is remembered as cleared")
	var before_tick: int = main._labyrinth_tempo
	await _tempo(main, 25)
	_check(not pdm.is_lost() and main._labyrinth_tempo == before_tick, "with him dead the clock is still")
	main.queue_free()
	await _settle()
