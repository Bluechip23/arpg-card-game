extends SceneTree

## The Boneyard — the Bone Dragon's boss room.
##  - Layout: a walled square off the Old Graveyard's deepest crypt, entered
##    through the gate on the west; twelve gravestones in rows; the dragon
##    on the far side; a crypt door the grave diggers come out of; sealed
##    until the dragon dies.
##  - Fight: the dragon regenerates 1 health a cycle per standing stone,
##    and it never fades. A broken stone (10 HP) brings a grave digger
##    (20 HP) out of the crypt — one at a time, three in all — who walks
##    to it and, 8 tempo later, has it back at full and is gone.
## Run: godot --headless --path . --script tests/test_boneyard.gd

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

func _build(interior: String, cleared: Array = []) -> DungeonManager:
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
	dm.initialize(gm, parent, 1, interior)
	return dm

func _test_layout() -> void:
	print("-- Boneyard layout --")
	var dm := _build("boneyard")
	_check(dm.interior_kind == "boneyard" and dm.get_location_name() == "The Boneyard", "the Boneyard is its own interior kind")
	_check(dm.is_floor(dm.player_start) and dm.player_start.x < dm.BY_FLOOR.position.x + 2, "the player enters through the west gate")
	_check(dm.get_site_by_id("exit") < 0, "sealed: no exit while the dragon lives")
	_check(dm.gravestone_cells.size() == 12, "twelve gravestones")
	var on_floor := true
	var elev0 := true
	for c in dm.gravestone_cells:
		if not dm.is_floor(c):
			on_floor = false
		if dm.get_elevation(c) != 0:
			elev0 = false
	_check(on_floor and elev0, "every stone stands on flat floor")
	_check(dm.is_floor(dm.boneyard_dragon_cell) and dm.boneyard_dragon_cell.x > dm.BY_FLOOR.get_center().x, "the dragon waits across the yard")
	_check(dm.is_floor(dm.boneyard_crypt_cell), "the crypt door opens onto floor")
	_check(dm.floor_texture_path().ends_with("floor_undead.png") and dm.wall_texture_path().ends_with("wall_undead.png"), "dressed in the undead land pack")
	var opened := _build("boneyard", ["boneyard"])
	_check(opened.get_site_by_id("exit") >= 0, "a cleared Boneyard opens with its exit in place")
	var gy := _build("graveyard_0")
	var idx := gy.get_site_by_id("boneyard")
	_check(idx >= 0 and gy.site_nodes[idx]["kind"] == "boneyard", "the Old Graveyard has the door to the Boneyard")
	if idx >= 0:
		var in_deep := false
		for room in gy.rooms:
			if room["kind"] == "deep" and (room["rect"] as Rect2i).has_point(gy.site_nodes[idx]["grid_pos"]):
				in_deep = true
		_check(in_deep, "in its deepest crypt")

func _settle(frames: int = 8) -> void:
	for _i in range(frames):
		await process_frame

func _dismiss(main) -> void:
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame

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

func _test_fight() -> void:
	print("-- Booting main.tscn as the Boneyard --")
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "boneyard")
	get_root().add_child(main)
	await _settle()
	await _dismiss(main)
	_check(main.boss_room_mode, "the scene knows it is a boss room")
	_check(_count(main, Enemy.EnemyType.BONE_DRAGON) == 1, "one Bone Dragon")
	_check(_count(main, Enemy.EnemyType.GRAVESTONE) == 12, "twelve standing gravestones")
	_check(_count(main, Enemy.EnemyType.GRAVE_DIGGER) == 0, "no digger out yet")
	var dragon: Enemy = _first(main, Enemy.EnemyType.BONE_DRAGON)
	if dragon == null:
		_check(false, "no dragon; skipping the fight")
		main.queue_free()
		return
	var stone: Enemy = _first(main, Enemy.EnemyType.GRAVESTONE)
	_check(stone.is_structure and stone.max_health == 10 and stone.xp_reward == 0, "a gravestone is a 10-HP structure worth no XP")
	_check(main.enemy_spawner._generate_loot(stone).is_empty(), "a gravestone drops nothing")
	var gb: Dictionary = {}
	for eff in dragon.get_active_effects():
		if eff["name"] == "Gravebound":
			gb = eff
	_check(gb.get("stacks", 0) == 12, "the dragon shows Gravebound x12")

	# Regen: 1 per standing stone each cycle, and it does not decay.
	dragon.current_health = dragon.max_health / 2
	var hp0: int = dragon.current_health
	main.tempo_manager.add_tempo(5)
	await _settle(1)
	_check(dragon.current_health == hp0 + 12, "a cycle heals 12 with twelve stones (%d -> %d)" % [hp0, dragon.current_health])
	main.tempo_manager.add_tempo(5)
	await _settle(1)
	_check(dragon.current_health == hp0 + 24, "and 12 again the next cycle — nothing decays")

	# Break a stone: the regen drops and a digger comes out.
	var gm = main.grid_manager
	var cell: Vector2i = gm.world_to_grid(stone.position)
	stone.take_damage(100, true)
	await _settle(2)
	_check(main._standing_gravestones() == 11, "a broken stone lowers the count to 11")
	var digger: Enemy = _first(main, Enemy.EnemyType.GRAVE_DIGGER)
	_check(digger != null and main._grave_diggers_left == 2, "a grave digger comes out of the crypt (2 left)")
	if digger:
		_check(digger.repair_cell == cell and digger.max_health == 20, "bound to the broken stone, 20 HP")
		_check(gm.world_to_grid(digger.position) == main.dungeon_manager.boneyard_crypt_cell, "he starts at the crypt door")
		# He walks toward the stone.
		var d0: float = (gm.world_to_grid(digger.position) - cell).length()
		main.tempo_manager.add_tempo(2)
		await _settle(2)
		var d1: float = (digger.intended_cell() - cell).length()
		_check(d1 < d0, "he walks toward it (%.1f -> %.1f)" % [d0, d1])
		# Stand him beside it: his next action is the repair — 8 tempo of
		# work, then the stone stands and he is gone.
		digger.is_moving = false
		digger._move_path.clear()
		digger.position = main._ground_pos(cell + Vector2i(1, 0))
		digger.target_position = digger.position
		digger.chosen_action = {}
		digger.action_tempo_counter = 0
		for _t in range(7):
			main.tempo_manager.add_tempo(1)
		await _settle(1)
		_check(main._standing_gravestones() == 11 and is_instance_valid(digger) and digger.is_alive(), "7 tempo in, still working")
		main.tempo_manager.add_tempo(1)
		await _settle(3)
		_check(main._standing_gravestones() == 12, "8 tempo: the stone stands again at full")
		var rebuilt: Enemy = null
		for e in main.enemy_spawner.get_living_enemies():
			if e.enemy_type == Enemy.EnemyType.GRAVESTONE and gm.world_to_grid(e.position) == cell:
				rebuilt = e
		_check(rebuilt != null and rebuilt.current_health == rebuilt.max_health, "the rebuilt stone is at full health")
		_check(_count(main, Enemy.EnemyType.GRAVE_DIGGER) == 0, "and the digger is gone")

	# Break it again: the second digger; kill him and the third comes; kill
	# him and the stone stays broken for good.
	var stone2: Enemy = null
	for e in main.enemy_spawner.get_living_enemies():
		if e.enemy_type == Enemy.EnemyType.GRAVESTONE and gm.world_to_grid(e.position) == cell:
			stone2 = e
	if stone2:
		stone2.take_damage(100, true)
		await _settle(2)
	var d2: Enemy = _first(main, Enemy.EnemyType.GRAVE_DIGGER)
	_check(d2 != null and main._grave_diggers_left == 1, "a second digger comes out (1 left)")
	if d2:
		d2.take_damage(100, true)
		await _settle(2)
	var d3: Enemy = _first(main, Enemy.EnemyType.GRAVE_DIGGER)
	_check(d3 != null and d3 != d2 and main._grave_diggers_left == 0, "killed, the third and last comes out (0 left)")
	if d3:
		d3.take_damage(100, true)
		await _settle(2)
	_check(_count(main, Enemy.EnemyType.GRAVE_DIGGER) == 0 and main._standing_gravestones() == 11, "with no diggers left the stone stays broken")
	dragon.current_health = dragon.max_health / 2
	var hp1: int = dragon.current_health
	main.tempo_manager.add_tempo(5)
	await _settle(1)
	_check(dragon.current_health == hp1 + 11, "the dragon now heals 11 a cycle")

	# The dragon dies: the way out opens and the room is remembered as cleared.
	dragon.take_damage(100000, true, DamageTypes.Type.PHYSICAL, true)
	await _settle(2)
	_check(main.dungeon_manager.get_site_by_id("exit") >= 0, "the exit appears when the dragon dies")
	_check(main.current_character.has_defeated_boss("boneyard"), "the character remembers the Boneyard as cleared")
	_check(not main.current_character.has_defeated_boss("ratking"), "and only the Boneyard")
	main.queue_free()
	await _settle()
