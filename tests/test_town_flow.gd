extends SceneTree

## Town flow + grid occupancy batch:
##  - character select / load go straight to town (no Town-vs-Fight prompt)
##  - the town has no Back-to-title button
##  - quest markers: gold ! on offer, gray ? in progress, gold ? ready to turn in
##  - the world stays shut until Olorin's first errand is taken
##  - turned-in quests do not come back as fresh offers after a reload
##  - a move never ends on an enemy's tile (current or destination)
##  - tree trunks (obstacle tiles) block the player, not just enemies
## Run: godot --headless --path . --script tests/test_town_flow.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Town flow test ===")

	for path in [
		"res://scripts/menus/town.gd",
		"res://scripts/character/character_select.gd",
		"res://scripts/menus/load_character.gd",
		"res://scripts/core/quest_manager.gd",
		"res://scripts/character/player.gd",
		"res://scripts/battle/enemy.gd",
		"res://scripts/core/dungeon_manager.gd",
	]:
		var script = load(path)
		_check(script != null and script.can_instantiate(), "%s parses" % path.get_file())

	_test_menu_flow()
	_test_quest_markers()
	await _test_player_path_trimming()
	await _test_live_town()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

# ---------------------------------------------------------------------------

func _test_menu_flow() -> void:
	var select_src: String = FileAccess.get_file_as_string("res://scripts/character/character_select.gd")
	_check(not select_src.contains("_show_mode_select") and not select_src.contains("_on_mode_fight"),
		"character select no longer offers Town vs Fight")
	_check(select_src.contains("_go_to_town"), "character select heads straight to town")
	var load_src: String = FileAccess.get_file_as_string("res://scripts/menus/load_character.gd")
	_check(not load_src.contains("_show_mode_select") and not load_src.contains("_on_mode_fight"),
		"load character no longer offers Town vs Fight")
	var town_scene: PackedScene = load("res://scenes/menus/town.tscn")
	var state := town_scene.get_state()
	var has_back := false
	for i in range(state.get_node_count()):
		if String(state.get_node_name(i)) == "BackButton":
			has_back = true
	_check(not has_back, "town scene has no Back button")
	var town_src: String = FileAccess.get_file_as_string("res://scripts/menus/town.gd")
	_check(not town_src.contains("title_menu.tscn"), "town never loads the title menu")

func _test_quest_markers() -> void:
	var qm = QuestManager.new()
	qm._ready()
	_check(qm.marker_state_for("Olorin") == "available", "fresh game: Olorin shows a gold ! (quest on offer)")
	_check(not qm.is_quest_started("olorin_kill_wererats"), "fresh game: world is shut until the rat quest is taken")
	_check(qm.marker_state_for("Sellsword") == "", "NPCs without quests show no marker")

	_check(qm.accept_quest("olorin_kill_wererats"), "rat quest accepted")
	_check(qm.marker_state_for("Olorin") == "active", "accepted: Olorin shows a gray ? (in progress)")
	_check(qm.is_quest_started("olorin_kill_wererats"), "accepted: the portal opens")

	for _i in range(5):
		qm.on_enemy_killed("Wererat")
	_check(qm.marker_state_for("Olorin") == "complete", "objectives done: Olorin shows a gold ? (turn in)")

	# Round-trip through the world and back keeps the state.
	var saved = qm.save_state()
	var qm2 = QuestManager.new()
	qm2._ready()
	qm2.load_state(saved)
	_check(qm2.marker_state_for("Olorin") == "complete", "state survives the trip back to town")

	var rewards = qm2.turn_in_quest("olorin_kill_wererats")
	_check(rewards.get("gold", 0) == 50, "turn-in pays out")
	_check(qm2.marker_state_for("Olorin") == "available", "turned in: Olorin's next errands are on offer")
	_check("olorin_kill_wererats" not in qm2.available_quests, "…but the rat quest itself is done for good")

	# A turned-in quest must not resurface as a fresh offer on the next load.
	var saved2 = qm2.save_state()
	var qm3 = QuestManager.new()
	qm3._ready()
	qm3.load_state(saved2)
	_check("olorin_kill_wererats" not in qm3.available_quests and qm3.is_quest_turned_in("olorin_kill_wererats"), "reload after turn-in: no phantom re-offer of the rat quest")
	_check(qm3.is_quest_started("olorin_kill_wererats"), "reload after turn-in: portal still open")

	# The town's marker painter.
	var TownScript = load("res://scripts/menus/town.gd")
	var marker := Label3D.new()
	TownScript._apply_quest_marker(marker, "available")
	_check(marker.text == "!" and marker.visible and marker.modulate == TownScript.MARKER_GOLD, "marker: gold !")
	TownScript._apply_quest_marker(marker, "active")
	_check(marker.text == "?" and marker.visible and marker.modulate == TownScript.MARKER_GRAY, "marker: gray ?")
	TownScript._apply_quest_marker(marker, "complete")
	_check(marker.text == "?" and marker.visible and marker.modulate == TownScript.MARKER_GOLD, "marker: gold ?")
	TownScript._apply_quest_marker(marker, "")
	_check(not marker.visible, "marker: hidden when nothing to show")
	marker.free()

func _test_live_town() -> void:
	## The real town scene: gate shut on arrival, Olorin flagged, the portal
	## centred on a tile the player rides up onto; accept the quest and the
	## gate opens with the marker turning into a gray ?.
	var town = load("res://scenes/menus/town.tscn").instantiate()
	town.starting_character = CharacterData.create_ryan()
	get_root().add_child(town)
	await process_frame
	await process_frame

	_check(town.get_node_or_null("UI/BackButton") == null, "live town: no Back button")
	_check(town.fight_button.disabled, "live town: TO BATTLE is disabled until Olorin is spoken to")
	_check(not town._can_leave_town(), "live town: portal shut on a fresh character")
	var olorin = town.get_node_or_null("Vendors/Olorin")
	var marker: Label3D = olorin.get_node("QuestIndicator") if olorin else null
	_check(marker != null and marker.text == "!" and marker.visible, "live town: Olorin wears a gold !")

	var gm: GridManager = town.grid_manager
	var portal: Node3D = town._town_waypoint_node
	var portal_cell := gm.world_to_grid(portal.position)
	_check(portal.position.is_equal_approx(gm.grid_to_world(portal_cell)), "live town: portal sits on a tile centre")
	_check(absf(town._town_ground_y(portal.position) - DungeonManager.WAYPOINT_MOUND_HEIGHT) < 0.001,
		"live town: standing on the portal tile puts the player on top of the mound")
	_check(town._town_ground_y(portal.position + Vector3(2, 0, 0)) == 0.0, "live town: flat plaza beside it")
	_check(town.player.ground_y_provider.is_valid(), "live town: player follows the town ground height")
	_check(town.player.position.is_equal_approx(gm.snap_to_grid(town.player.position)), "live town: player starts on a tile centre")

	town.quest_manager.accept_quest(town.FIRST_QUEST_ID)
	town._refresh_quest_indicators()
	town._refresh_leave_gate()
	_check(marker.text == "?" and marker.modulate == town.MARKER_GRAY, "live town: accepted quest turns the ! into a gray ?")
	_check(not town.fight_button.disabled and town._can_leave_town(), "live town: gate opens once the quest is taken")

	town.queue_free()
	await process_frame

## A stand-in spawner: just enough surface for Player._taken_cells().
class FakeSpawner extends Node:
	var enemies: Array = []
	var players: Array = []
	var summons: Array = []
	func get_living_enemies() -> Array:
		return enemies
	func _living_summons() -> Array:
		return summons

## A stand-in enemy: a tile, plus the tile its move will end on.
class FakeEnemy extends Node3D:
	var dest: Vector2i
	func intended_cell() -> Vector2i:
		return dest

func _test_player_path_trimming() -> void:
	var holder := Node3D.new()
	get_root().add_child(holder)
	var gm := GridManager.new()
	holder.add_child(gm)
	var player: Player = load("res://scenes/character/player.tscn").instantiate()
	holder.add_child(player)
	await process_frame  # let _ready wire up the stats / debuff managers
	player.set_grid_manager(gm)
	player.position = gm.grid_to_world(Vector2i(2, 2))
	player.target_position = player.position
	var spawner := FakeSpawner.new()
	holder.add_child(spawner)
	player.enemy_spawner = spawner

	var rat := FakeEnemy.new()
	holder.add_child(rat)
	rat.position = gm.grid_to_world(Vector2i(5, 2))
	rat.dest = Vector2i(5, 2)
	spawner.enemies = [rat]

	# Aiming past the rat with only enough movement to reach its tile.
	_check(player.move_to_grid(gm.grid_to_world(Vector2i(8, 2)), 3), "move toward the rat starts")
	_check(player.intended_cell() == Vector2i(4, 2),
		"3-tile move that would end ON the rat stops one short (ends at %s)" % player.intended_cell())
	player.is_moving = false
	player.move_path.clear()

	# A single step straight into the rat is refused outright.
	player.position = gm.grid_to_world(Vector2i(4, 2))
	player.target_position = player.position
	_check(not player.move_to_grid(gm.grid_to_world(Vector2i(5, 2)), 1), "stepping onto an enemy tile is refused")

	# The rat's DESTINATION is reserved too, not just where it stands.
	rat.dest = Vector2i(4, 4)
	player.position = gm.grid_to_world(Vector2i(4, 2))
	player.target_position = player.position
	_check(player.move_to_grid(gm.grid_to_world(Vector2i(4, 4)), 2), "move toward the rat's destination starts")
	_check(player.intended_cell() == Vector2i(4, 3),
		"move ends short of where the rat is heading (ends at %s)" % player.intended_cell())
	player.is_moving = false
	player.move_path.clear()

	# Crossing an enemy tile mid-route is still allowed (only the END is guarded).
	rat.dest = Vector2i(5, 2)
	player.position = gm.grid_to_world(Vector2i(4, 2))
	player.target_position = player.position
	_check(player.move_to_grid(gm.grid_to_world(Vector2i(7, 2)), 3), "route through the rat to a free tile starts")
	_check(player.intended_cell() == Vector2i(7, 2), "route through the rat ends on the free tile beyond")
	player.is_moving = false
	player.move_path.clear()

	# Tree trunks in blocked_tiles: the player paths AROUND them.
	player.enemy_spawner = null
	player.position = gm.grid_to_world(Vector2i(2, 5))
	player.target_position = player.position
	player.blocked_tiles = [Vector2i(3, 5)]
	var path = player.calculate_path_to(gm.grid_to_world(Vector2i(4, 5)))
	var crosses_tree := false
	for wp in path:
		if gm.world_to_grid(wp) == Vector2i(3, 5):
			crosses_tree = true
	_check(path.size() == 4 and not crosses_tree, "player walks around a blocked tree tile (path %d tiles)" % path.size())

	holder.queue_free()
