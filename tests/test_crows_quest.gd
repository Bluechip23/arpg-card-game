extends SceneTree

## What the Crows Saw: World 1 hides an Old Graveyard off the minimap; while
## the quest is active a trail of feathers leads from the start toward it,
## each tip pointing at the next; walking up to the gate discovers the site,
## completes the quest, and the graveyard interior fields the dead.
## Run: godot --headless --path . --script tests/test_crows_quest.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _settle(frames: int = 8) -> void:
	for _i in range(frames):
		await process_frame

func _find_main() -> Node:
	for child in get_root().get_children():
		if child.get_script() and "current_interior_id" in child and not child.is_queued_for_deletion():
			return child
	return null

func _initialize() -> void:
	print("=== What the Crows Saw test ===")
	await _run()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _run() -> void:
	var qm := QuestManager.new()
	qm._ready()
	qm.accept_quest("olorin_kill_wererats")
	for _i in range(5):
		qm.on_enemy_killed("Wererat")
	qm.turn_in_quest("olorin_kill_wererats")
	_check(qm.accept_quest("what_the_crows_saw"), "the quest is offered after the first errand")

	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("quest_state", qm.save_state())
	get_root().add_child(main)
	await _settle()
	var dm = main.dungeon_manager

	var gy_idx := -1
	for i in range(dm.site_nodes.size()):
		if dm.site_nodes[i]["id"] == "graveyard_0":
			gy_idx = i
	_check(gy_idx >= 0, "world 1 has a graveyard site")
	if gy_idx < 0:
		return
	var site = dm.site_nodes[gy_idx]
	_check(site.get("hidden", false), "…hidden from the map to begin with")
	var entrance: Vector2i = site["grid_pos"]
	var start_d := absi(entrance.x - dm.player_start.x) + absi(entrance.y - dm.player_start.y)
	_check(start_d > 20, "…far from the start (%d tiles)" % start_d)

	# Feathers: a chain from the start, each pointing at the next.
	_check(dm.feather_nodes.size() >= 3, "a feather trail is laid (%d feathers)" % dm.feather_nodes.size())
	if dm.feather_nodes.size() >= 2:
		var first: Vector2i = dm.feather_nodes[0]["grid_pos"]
		var d0 := absi(first.x - dm.player_start.x) + absi(first.y - dm.player_start.y)
		_check(d0 <= dm.FEATHER_SPACING + 2, "the first feather lies near the start")
		var last: Vector2i = dm.feather_nodes[dm.feather_nodes.size() - 1]["grid_pos"]
		var dl := absi(last.x - entrance.x) + absi(last.y - entrance.y)
		_check(dl <= dm.FEATHER_SPACING + 2, "the last feather lies near the gate")
		# The tip direction: (-sin θ, -cos θ) must point from feather 0 toward feather 1.
		var n0: Sprite3D = dm.feather_nodes[0]["node"]
		var theta := deg_to_rad(n0.rotation_degrees.y)
		var tip := Vector2(-sin(theta), -cos(theta))
		var toward := Vector2(dm.feather_nodes[1]["grid_pos"] - first).normalized()
		_check(tip.dot(toward) > 0.9, "a feather's tip points at the next feather (dot %.2f)" % tip.dot(toward))
		var far_node: Sprite3D = dm.feather_nodes[dm.feather_nodes.size() - 1]["node"]
		_check(not far_node.visible, "feathers far from the start hide under the fog until revealed")

	# Discovery on foot.
	main.player.position = main.grid_manager.grid_to_world(entrance + Vector2i(0, 1))
	main.player.target_position = main.player.position
	main._check_hidden_site_discovery(entrance + Vector2i(0, 1))
	_check(not site.get("hidden", true), "walking up to the gate reveals the site")
	_check(main.quest_manager.get_quest("what_the_crows_saw").is_complete, "…and completes What the Crows Saw")
	_check(main.opened_chests.get("world_1_site_graveyard_0_found", false), "…remembered in world state")
	_check(dm.feather_nodes.is_empty(), "the feathers are gone once the gate is found")

	# Into the graveyard.
	main._enter_interior("graveyard_0", "Old Graveyard")
	await _settle()
	var inside = _find_main()
	_check(inside != null and inside.dungeon_manager.interior_kind == "graveyard", "the graveyard is its own interior kind")
	if inside:
		_check(inside.dungeon_manager.get_location_name() == "Old Graveyard", "…named Old Graveyard")
		var types := {}
		for z in inside.dungeon_manager.spawn_zones:
			for t in z["enemy_types"]:
				types[t] = true
		_check(types.has(Enemy.EnemyType.ZOMBIE) or types.has(Enemy.EnemyType.SKELETON), "the dead walk there (%d zones)" % inside.dungeon_manager.spawn_zones.size())
		_check(types.has(Enemy.EnemyType.NECROMANCER), "…and a Necromancer holds the deepest crypt")
		_check(not types.has(Enemy.EnemyType.WERERAT), "…with no sewer rats")
