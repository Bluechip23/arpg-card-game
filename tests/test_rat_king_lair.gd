extends SceneTree

## The Rat King's Lair — the first boss room.
##  - Layout: a round den entered from the west, the king at the bottom with
##    three rats before him and two archers behind, three cliffs across the
##    room with a nest at the foot of each, no exit until the king dies.
##  - Fight: treading on a nest releases an archer that climbs its cliff; at
##    50% / 30% / 30% the king bolts for an untouched nest and feeds on it
##    (left 20%, middle 30%, right 50% of his health, each nest once);
##    nests are 15-HP structures that drop nothing and never end the wave.
##  - Rules: entered from the sewer's cistern door; the hand and every buff
##    and debuff carry in; leaving returns to the sewer at the lair door.
## Run: godot --headless --path . --script tests/test_rat_king_lair.gd

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
	_test_sewer_door()
	await _test_lair_fight()
	await _test_sewer_round_trip()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _build(interior: String, cleared: bool = false) -> DungeonManager:
	var holder = Node3D.new()
	get_root().add_child(holder)
	var gm = GridManager.new()
	holder.add_child(gm)
	var parent = Node3D.new()
	holder.add_child(parent)
	var dm = DungeonManager.new()
	holder.add_child(dm)
	dm._opened_chests_ref = {}
	dm.cleared_bosses = ["ratking"] if cleared else []
	dm.initialize(gm, parent, 1, interior)
	return dm

func _test_layout() -> void:
	print("-- Lair layout --")
	var dm := _build("ratking_lair")
	_check(dm.interior_kind == "ratking", "the lair is its own interior kind")
	_check(dm.get_location_name() == "Rat King's Lair", "it is named")
	_check(dm.is_floor(dm.player_start) and dm.get_elevation(dm.player_start) == 0, "the player starts on flat floor")
	_check(dm.player_start.x < dm.RK_CENTER.x - dm.RK_RADIUS + 3, "the entrance is on the west edge")
	_check(dm.get_site_by_id("exit") < 0, "no exit: the room is sealed")
	_check(dm.spawn_zones.is_empty() and dm.chest_nodes.is_empty(), "no zones and no chests — main stands the fight up")
	_check(dm.rat_cliffs.size() == 3, "three cliffs")
	var pack_cliffs := true
	for rect in dm.rat_cliffs:
		for x in range(rect.position.x, rect.end.x):
			for z in range(rect.position.y, rect.end.y):
				var c := Vector2i(x, z)
				if z == rect.end.y - 1:
					# The cliff face row: a wall tile the pack's cliff strip is drawn on.
					if dm.is_floor(c):
						pack_cliffs = false
				elif not dm.is_floor(c) or dm.get_elevation(c) != 1:
					pack_cliffs = false
	_check(pack_cliffs, "each cliff is a pack cliff: a wall face row under two raised, walkable rows")
	var middle: Rect2i = dm.rat_cliffs[1]
	_check(middle.get_center().x == dm.RK_CENTER.x and middle.get_center().y < dm.RK_CENTER.y, "the middle cliff stands straight across from the king (north)")
	_check(dm.rat_cliffs[0].get_center().x < dm.RK_CENTER.x and dm.rat_cliffs[2].get_center().x > dm.RK_CENTER.x, "the other two flank it 45 degrees to each side")
	_check(dm.rat_nests.size() == 3, "three nests")
	var pcts: Array = []
	var ordered := true
	var at_base := true
	for i in range(dm.rat_nests.size()):
		var n: Dictionary = dm.rat_nests[i]
		pcts.append(n["heal_pct"])
		var cell: Vector2i = n["cell"]
		if not dm.is_floor(cell) or dm.get_elevation(cell) != 0:
			at_base = false
		var rect: Rect2i = dm.rat_cliffs[i]
		# At the foot of the cliff face: directly south of the face row.
		if not rect.has_point(cell + Vector2i(0, -1)) or cell.y != rect.end.y:
			at_base = false
		if not rect.has_point(n["perch"]):
			at_base = false
		if i > 0 and cell.x <= (dm.rat_nests[i - 1]["cell"] as Vector2i).x:
			ordered = false
	_check(pcts == [0.2, 0.3, 0.5], "the nests heal 20%% / 30%% / 50%% left to right (%s)" % [pcts])
	_check(ordered, "the nests run left to right")
	_check(at_base, "each nest sits on flat floor at the foot of its cliff face, its perch on top")
	var pl: Dictionary = dm.rat_king_placements
	var king: Vector2i = pl["king"]
	_check(dm.is_floor(king) and king.y > dm.RK_CENTER.y and king.x == dm.RK_CENTER.x, "the king stands at the bottom middle")
	var rats_front: bool = pl["rats"].size() == 3
	for c in pl["rats"]:
		if not dm.is_floor(c) or c.y >= king.y:
			rats_front = false
	_check(rats_front, "three rats stand in front of him")
	var archers_behind: bool = pl["archers"].size() == 2
	for c in pl["archers"]:
		if not dm.is_floor(c) or c.y <= king.y:
			archers_behind = false
	_check(archers_behind, "two archers stand behind him")
	# Every floor tile reachable from the door (the cliffs are walkable).
	var seen := {dm.player_start: true}
	var frontier := [dm.player_start]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + d
			if dm.is_floor(nxt) and not seen.has(nxt):
				seen[nxt] = true
				frontier.append(nxt)
	_check(seen.size() == dm.get_floor_tiles().size(), "the whole den, cliff tops included, is reachable from the door")
	var cleared := _build("ratking_lair", true)
	_check(cleared.get_site_by_id("exit") >= 0, "a lair whose king is already dead opens with its exit in place")

func _test_sewer_door() -> void:
	print("-- The sewer's lair door --")
	var dm := _build("sewer_0")
	var idx := dm.get_site_by_id("ratking_lair")
	_check(idx >= 0, "the sewer has the lair door")
	if idx >= 0:
		var site = dm.site_nodes[idx]
		_check(site["kind"] == "ratking" and dm.is_floor(site["grid_pos"]), "the door stands on floor as a ratking site")
		var in_arena := false
		for room in dm.rooms:
			if room["kind"] == "arena" and (room["rect"] as Rect2i).has_point(site["grid_pos"]):
				in_arena = true
		_check(in_arena, "the door is in the central cistern")
	var king_in_sewer := false
	var guard := false
	for zn in dm.spawn_zones:
		for t in zn["enemy_types"]:
			if t == Enemy.EnemyType.RAT_KING:
				king_in_sewer = true
			if t == Enemy.EnemyType.WERERAT:
				guard = true
	_check(not king_in_sewer, "the king no longer spawns in the sewer itself")
	_check(guard, "rats still guard the cistern")

func _settle(frames: int = 8) -> void:
	for _i in range(frames):
		await process_frame

func _dismiss(main) -> void:
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame

func _find_main() -> Node:
	for child in get_root().get_children():
		if child.get_script() and "current_interior_id" in child and not child.is_queued_for_deletion():
			return child
	return null

func _count(main, type: int) -> int:
	var n := 0
	for e in main.enemy_spawner.get_living_enemies():
		if e.enemy_type == type:
			n += 1
	return n

func _first(main, type: int) -> Enemy:
	for e in main.enemy_spawner.get_living_enemies():
		if e.enemy_type == type:
			return e
	return null

func _test_lair_fight() -> void:
	print("-- Booting main.tscn as the lair --")
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "ratking_lair")
	get_root().add_child(main)
	await _settle()
	await _dismiss(main)
	_check(main.boss_room_mode, "the scene knows it is a boss room")
	_check(_count(main, Enemy.EnemyType.RAT_KING) == 1, "one Rat King")
	_check(_count(main, Enemy.EnemyType.WERERAT) == 3, "three rats")
	_check(_count(main, Enemy.EnemyType.ARCHER_RAT) == 2, "two archers")
	_check(_count(main, Enemy.EnemyType.RAT_NEST) == 3, "three nests")
	_check(main.dungeon_manager.get_site_by_id("exit") < 0, "no way out while the king lives")
	var king: Enemy = _first(main, Enemy.EnemyType.RAT_KING)
	var nests: Array = main._rat_nests
	if king == null or nests.size() != 3:
		_check(false, "lair units missing; skipping the fight")
		main.queue_free()
		await _settle()
		return
	var nest_mid: Enemy = nests[1]
	_check(nest_mid.is_structure and nest_mid.max_health == 15 and nest_mid.xp_reward == 0, "a nest is a 15-HP structure worth no XP")
	_check(nest_mid.nest_heal_pct == 0.3 and nest_mid.nest_label == "middle", "the middle nest heals 30%")
	_check(main.enemy_spawner._generate_loot(nest_mid).is_empty(), "a nest drops nothing")

	# Treading on a nest releases its archer, who climbs to the cliff top.
	var gm = main.grid_manager
	var nest_cell: Vector2i = gm.world_to_grid(nest_mid.position)
	main.player.position = main._ground_pos(nest_cell)
	main.player.target_position = main.player.position
	main._on_player_tile_reached()
	_check(_count(main, Enemy.EnemyType.ARCHER_RAT) == 3, "stepping on a nest releases an archer")
	main._on_player_tile_reached()
	_check(_count(main, Enemy.EnemyType.ARCHER_RAT) == 3, "a nest releases its archer only once")
	var perched: Enemy = null
	for e in main.enemy_spawner.get_living_enemies():
		if e.enemy_type == Enemy.EnemyType.ARCHER_RAT and e.perch_cell.x >= 0:
			perched = e
	_check(perched != null and perched.perch_cell == nest_mid.nest_perch, "the released archer is bound to the nest's cliff top")
	if perched:
		for _i in range(5):
			main.tempo_manager.add_tempo(2)
			await _settle(2)
			# Headless frames outrun the glide: stand it where its route ends.
			perched.position = main._ground_pos(perched.intended_cell())
			perched.target_position = perched.position
			perched.is_moving = false
			perched._move_path.clear()
		_check(perched.intended_cell() == perched.perch_cell, "it walks up to the top of the high ground (%s -> %s)" % [perched.intended_cell(), perched.perch_cell])
		_check(main.dungeon_manager.get_elevation(perched.perch_cell) == 1, "the perch is high ground")

	# 50%: the king bolts for a nest.
	var before_target = king._nest_target
	king.current_health = int(king.max_health * 0.49)
	king.take_damage(1, true)
	_check(before_target == null and king._nest_flights_done == 1 and king._nest_target != null, "at 50% health the king runs for a nest")
	var target: Enemy = king._nest_target
	_check(target in nests and not target.nest_used, "an untouched nest")
	# Stand him beside it and let the clock run: he feeds and the nest is spent.
	var tcell: Vector2i = gm.world_to_grid(target.position)
	var beside: Vector2i = tcell + Vector2i(0, 1)
	king.is_moving = false
	king._move_path.clear()
	king.position = main._ground_pos(beside)
	king.target_position = king.position
	main.player.position = main._ground_pos(main.dungeon_manager.player_start)
	main.player.target_position = main.player.position
	var hp_before: int = king.current_health
	for _i in range(3):
		main.tempo_manager.add_tempo(2)
		await _settle(1)
	var expected_heal: int = roundi(king.max_health * target.nest_heal_pct)
	_check(target.nest_used, "the %s nest is drained" % target.nest_label)
	_check(king.current_health == mini(king.max_health, hp_before + expected_heal), "he healed %d%% of his health (%d -> %d)" % [int(target.nest_heal_pct * 100), hp_before, king.current_health])
	_check(king._nest_target == null, "and goes back to the fight")

	# 30%: a different nest; a drained one is never revisited.
	king.current_health = int(king.max_health * 0.29)
	king.take_damage(1, true)
	_check(king._nest_flights_done == 2 and king._nest_target != null and king._nest_target != target, "at 30% he runs for a nest he has not used")
	# Tear that nest down: he gives it up for another untouched one.
	var second: Enemy = king._nest_target
	second.take_damage(100, true)
	_check(second.is_dead, "a nest can be destroyed")
	king._choose_action(main.player)
	_check(king._nest_target != null and king._nest_target != second and king._nest_target != target, "a destroyed nest is abandoned for the last untouched one")
	# Spend it, then the third flight finds nothing left.
	king._nest_target.drain_nest()
	king._choose_action(main.player)
	_check(king._nest_target == null, "with every nest spent he fights on")
	king.current_health = int(king.max_health * 0.29)
	king.take_damage(1, true)
	_check(king._nest_flights_done == 3 and king._nest_target == null, "the third threshold is spent with no nest to run to")
	king.current_health = int(king.max_health * 0.1)
	king.take_damage(1, true)
	_check(king._nest_flights_done == 3, "three flights, never a fourth")

	# The king dies: the way out opens, and the kill is remembered.
	king.take_damage(10000, true)
	await _settle(2)
	_check(main.dungeon_manager.get_site_by_id("exit") >= 0, "the exit appears when the king dies")
	_check(main.current_character.has_defeated_boss("ratking"), "the character remembers the lair as cleared")
	main.queue_free()
	await _settle()

func _test_sewer_round_trip() -> void:
	print("-- Sewer -> lair -> sewer, carrying the hand and statuses --")
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "sewer_0")
	get_root().add_child(main)
	await _settle()
	await _dismiss(main)
	var idx: int = main.dungeon_manager.get_site_by_id("ratking_lair")
	_check(idx >= 0, "the live sewer has the lair door")
	if idx < 0:
		main.queue_free()
		return
	var door: Vector2i = main.dungeon_manager.site_nodes[idx]["grid_pos"]
	main.player.get_buff_manager().apply_buff(Buff.create_thorns(3, 15, "test"))
	main.player.get_debuff_manager().apply_debuff(Debuff.create(Debuff.DebuffType.BLEED, 2, 10))
	var hand_ids: Array = []
	for c in main.deck_manager.hand:
		hand_ids.append(c.card_id)
	main._enter_interior("ratking_lair", "Rat King's Lair")
	await _settle()
	var inside = _find_main()
	_check(inside != null and inside.current_interior_id == "ratking_lair", "Shift at the door enters the lair")
	if inside == null:
		return
	await _dismiss(inside)
	_check(inside.parent_interior_id == "sewer_0", "the lair remembers the sewer behind it")
	var in_hand: Array = []
	for c in inside.deck_manager.hand:
		in_hand.append(c.card_id)
	_check(in_hand == hand_ids, "the hand is exactly what it was (%d cards)" % in_hand.size())
	_check(inside.player.get_buff_manager().has_buff(Buff.BuffType.THORNS), "the Thorns buff came along")
	var bleed = inside.player.get_debuff_manager().get_debuff(Debuff.DebuffType.BLEED)
	_check(bleed != null and bleed.value == 2, "the Bleed debuff came along, stacks intact")
	_check(inside.carried_statuses.is_empty(), "the hand-over is consumed")
	_check(inside.dungeon_manager.get_site_by_id("exit") < 0, "the door is sealed")
	var king: Enemy = _first(inside, Enemy.EnemyType.RAT_KING)
	if king:
		king.take_damage(10000, true)
		await _settle(2)
	_check(inside.dungeon_manager.get_site_by_id("exit") >= 0, "the king's death opens the exit")
	inside._exit_interior()
	await _settle()
	var back = _find_main()
	_check(back != null and back.current_interior_id == "sewer_0", "leaving returns to the sewer")
	if back:
		await _dismiss(back)
		var cell: Vector2i = back.grid_manager.world_to_grid(back.player.position)
		_check(cell == door, "at the lair door (%s vs %s)" % [cell, door])
		_check(back.dungeon_manager.cleared_bosses.has("ratking"), "the sewer knows the king is dead")
		_check(_count(back, Enemy.EnemyType.RAT_KING) == 0, "no second Rat King")
		back.queue_free()
	await _settle()
