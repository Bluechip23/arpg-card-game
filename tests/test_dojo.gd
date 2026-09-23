extends SceneTree

## The Dojo: the town's training hall. Dummies never act, wander or die; the
## hall is one lit room with no loot or spawns; and the snapshot the dojo
## hands back to town carries no live card objects.
## Run: godot --headless --path . --script tests/test_dojo.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Dojo test ===")
	_run()

func _run() -> void:
	var holder := Node3D.new()
	get_root().add_child(holder)
	var gm := GridManager.new()
	holder.add_child(gm)
	await process_frame

	_test_dummy(holder, gm)
	_test_layout(holder, gm)
	_test_snapshot()
	_test_figures()
	await _test_scene_boot()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_scene_boot() -> void:
	print("-- Booting main.tscn as the dojo --")
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	var main = packed.instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(6):
		await process_frame
	_check(main.dojo_mode, "the scene enters dojo mode from the interior id")
	var dummies := 0
	for e in main.enemy_spawner.get_living_enemies():
		if e.enemy_type == Enemy.EnemyType.DUMMY:
			dummies += 1
	_check(dummies == 2, "two enemy dummies stand on the enemy side (%d)" % dummies)
	_check(main._dojo_allies.size() == 2, "two ally dummies stand on the ally side")
	var ally = main._dojo_allies[0]
	_check(ally is Player and ally.get_stats().max_health == 500, "ally dummies are Players with a fat health pool")
	_check(main._player_at_position(ally.position) == ally, "ally-target cards can find a dog")
	_check(main._action_vbox.get_node("WaitPauseRow").get_node_or_null("DojoResetButton") != null, "the Reset button sits beside Wait")
	_check(not main._dojo_entry_deck_state.has("live") and main._dojo_entry_deck_state.has("hand"), "the entry hand is snapshotted as data")
	_check(not main._dojo_entry_progression.is_empty() or main.player_progression.is_empty(), "the entry progression is kept")

	# Dragging the bars sets the values; health never reaches 0.
	var stats = main.player.get_stats()
	main._hp_bar.size = Vector2(200, 22)
	main._dojo_apply_bar_drag(main._hp_bar, "hp", Vector2(100, 5))
	_check(stats.current_health == roundi(stats.max_health * 0.5), "dragging the HP bar to the middle halves health (%d/%d)" % [stats.current_health, stats.max_health])
	main._dojo_apply_bar_drag(main._hp_bar, "hp", Vector2(-50, 5))
	_check(stats.current_health == 1, "dragging past the left edge floors health at 1")
	main._mana_bar.size = Vector2(200, 22)
	main._dojo_apply_bar_drag(main._mana_bar, "mana", Vector2(50, 5))
	_check(is_equal_approx(stats.current_mana, stats.max_mana * 0.25), "dragging the mana bar sets mana")

	# Hurt a chicken, buff up, then Reset puts everything back.
	var chicken: Enemy = null
	for e in main.enemy_spawner.get_living_enemies():
		if e.enemy_type == Enemy.EnemyType.DUMMY:
			chicken = e
	chicken.take_damage(40, true)
	stats.add_armor(9)
	main.tempo_manager.add_tempo(7)
	var hand_before: int = main.deck_manager.hand.size()
	main.deck_manager.hand.clear()
	main._dojo_reset()
	await process_frame
	_check(stats.current_health == stats.max_health and stats.current_armor == 0, "Reset: full health, no armor")
	_check(is_equal_approx(stats.current_mana, float(stats.max_mana)), "Reset: full mana")
	_check(main.tempo_manager.get_global_tempo() == 0, "Reset: tempo back to 0")
	_check(main.deck_manager.hand.size() == hand_before, "Reset: the entry hand is back (%d cards)" % main.deck_manager.hand.size())
	var fresh := 0
	for e in main.enemy_spawner.get_living_enemies():
		if e.enemy_type == Enemy.EnemyType.DUMMY and e.current_health == e.max_health:
			fresh += 1
	_check(fresh == 2, "Reset: two fresh chickens")
	_check(main._dojo_blocks_progression(), "the skill tree is locked in the dojo")
	main.queue_free()
	await process_frame

func _test_dummy(holder: Node3D, gm: GridManager) -> void:
	print("-- Training dummy --")
	var e: Enemy = load("res://scenes/battle/enemy.tscn").instantiate()
	holder.add_child(e)
	e.initialize(Enemy.EnemyType.DUMMY, gm)
	e.position = gm.grid_to_world(Vector2i(5, 5))
	_check(e.is_training_dummy, "DUMMY initializes as a training dummy")
	_check(e.enemy_name == "Training Dummy", "named for the compendium and the log")
	_check(e.actions.is_empty(), "a dummy has no actions")
	_check(e.xp_reward == 0, "a dummy is worth no XP")
	_check(e.figure_kind == "chicken", "enemy dummies wear the chicken sprite")
	var died := [false]
	e.died.connect(func(_who): died[0] = true)
	var full: int = e.max_health
	e.take_damage(7, true)
	_check(e.current_health == full - 7, "damage lands and shows (%d/%d)" % [e.current_health, full])
	e.take_damage(full * 3, true)
	_check(e.current_health == full and not e.is_dead and not died[0],
		"a lethal blow refills the dummy instead of killing it")
	# Tempo passes: the dummy never picks an action.
	var tgt := Node3D.new()
	holder.add_child(tgt)
	tgt.position = gm.grid_to_world(Vector2i(6, 5))
	for _i in range(25):
		e.on_tempo_advanced(1, tgt)
	_check(e.chosen_action.is_empty() and not e.is_dead, "25 tempo later it has done nothing")
	var start := e.position
	e._idle_ambient(10.0)
	_check(e.position == start and not e.is_moving, "no idle wandering")
	e.queue_free()
	tgt.queue_free()

func _test_layout(holder: Node3D, gm: GridManager) -> void:
	print("-- Dojo layout --")
	var parent := Node3D.new()
	holder.add_child(parent)
	var dm := DungeonManager.new()
	holder.add_child(dm)
	dm._opened_chests_ref = {}
	dm.initialize(gm, parent, 1, "dojo")
	_check(dm.interior_kind == "dojo", "interior id 'dojo' selects the dojo kind")
	_check(dm.GRID_W == dm.DOJO_W and dm.GRID_H == dm.DOJO_H, "the hall is the dojo's fixed size")
	_check(dm.get_location_name() == "Dojo", "location reads 'Dojo'")
	_check(dm.chest_nodes.is_empty(), "no chests")
	_check(dm.fountain_nodes.is_empty(), "no fountains")
	_check(dm.spawn_zones.is_empty(), "no spawn zones")
	_check(dm.site_nodes.size() == 1 and dm.site_nodes[0]["kind"] == "exit", "one site: the door out")
	var all_floor := true
	for cells in dm.DOJO_DUMMY_CELLS.values():
		for c in cells:
			if dm.grid[c.x][c.y] != dm.Tile.FLOOR or dm.elevation[c.x][c.y] != 0:
				all_floor = false
	_check(all_floor, "every dummy cell is flat floor")
	var start: Vector2i = dm.player_start
	_check(dm.grid[start.x][start.y] == dm.Tile.FLOOR, "the player starts on floor")
	var flat := true
	for x in range(dm.GRID_W):
		for z in range(dm.GRID_H):
			if dm.elevation[x][z] != 0:
				flat = false
	_check(flat, "the hall is flat")
	dm.clear()
	dm.queue_free()
	parent.queue_free()

func _test_snapshot() -> void:
	print("-- Entry snapshot --")
	var main_script = load("res://scripts/core/main.gd")
	var live_card := Card.create_slash()
	var progression := {
		"stats": {"current_health": 12, "gold": 3},
		"deck_state": {
			"hand": [{"id": "slash"}], "draw_pile": [], "discard_pile": [], "jail_pile": [], "maintained": [],
			"live": {"hand": [live_card]},
		},
		"inventory": {"stored_items": [], "culling_stones": 2},
	}
	var snap: Dictionary = main_script.dojo_snapshot(progression)
	_check(not snap["deck_state"].has("live"), "the snapshot drops the deck's live card objects")
	_check(progression["deck_state"].has("live"), "…without touching the original")
	_check(snap["deck_state"]["hand"][0]["id"] == "slash", "card data lists survive")
	snap["inventory"]["stored_items"].append("x")
	snap["stats"]["gold"] = 99
	_check(progression["inventory"]["stored_items"].is_empty() and progression["stats"]["gold"] == 3,
		"the snapshot is a deep copy: later edits do not leak back")

func _test_figures() -> void:
	print("-- Figures --")
	_check(SpriteFigure.supports("Dog"), "ally dummies have a dog figure")
	_check(SpriteEnemyFigure.supports("chicken"), "enemy dummies have a chicken figure")
	var tex = load("res://assets/sprites/generated/monsters/chicken.png")
	_check(tex != null and tex.get_width() == 64 and tex.get_height() == 64, "the chicken sprite is a 64x64 battler cell")
