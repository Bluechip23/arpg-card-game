extends SceneTree

## Co-op progression screen (designer, 2026-11-20): Player 2 has their own
## passive tree, Stats and sphere grid. The screen's P1/P2 tabs (or TAB) swap
## which hero it shows; it opens on the hero you control; closed, it is back
## on Player 1. Sphere unlocks, spheres and stat points land on the hero shown.
## A real second player joins through the sandbox ally path, in the dojo.
## Run: godot --headless --path . --script tests/test_coop_progression.gd

var failures := 0
var main

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Co-op progression screen ===")
	_run()

func _run() -> void:
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	main = packed.instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(6):
		await process_frame

	var stu: SkillTreeUI = main.skill_tree_ui
	var sgu: SphereGridUI = main.sphere_grid_ui
	var p1_tree = stu.skill_tree
	var p1_grid: SphereGrid = sgu.sphere_grid
	var p1_inv: SphereInventory = main.sphere_inventory

	# Solo: no hero tabs.
	main._open_progression_screen()
	await process_frame
	_check(stu.visible, "L opens the progression screen")
	_check(not stu._hero_btns[0].visible and not stu._hero_btns[1].visible, "solo: no P1/P2 tabs")
	_check(stu._stat_alloc_btn.text == "Stats" and not stu._stat_alloc_btn.disabled, "the Stats tab reads 'Stats' and is open")
	main._open_progression_screen()
	await process_frame

	main._on_sandbox_add_ally("Jeremy")
	await process_frame
	var p1: Player = main._p1_player
	var p2: Player = main._p2_player
	_check(p2 != null and is_instance_valid(p2), "a second player joins")

	# Opens on P1 (in control), with both hero tabs.
	main._open_progression_screen()
	await process_frame
	_check(stu._hero_btns[0].visible and stu._hero_btns[1].visible, "co-op: the P1 and P2 tabs show")
	_check(stu._hero_btns[1].text.contains("Jeremy"), "the P2 tab names the ally")
	_check(stu.player_stats == p1.get_stats(), "opens on Player 1 while they're in control")

	# Switch to P2 with the tab.
	stu.hero_switch_requested.emit(1)
	await process_frame
	_check(main._progression_index == 1, "the P2 tab binds the screen to Player 2")
	_check(stu.player_stats == p2.get_stats() and sgu.player_stats == p2.get_stats(), "Stats and the grid's gates read Player 2")
	_check(stu.skill_tree != p1_tree and stu.skill_tree != null, "Player 2 has their own passive tree")
	_check(stu.skill_tree.character_name.contains("Jeremy") if "character_name" in stu.skill_tree else true,
		"it is Jeremy's tree")
	_check(sgu.sphere_grid != p1_grid, "Player 2 has their own sphere grid")
	_check(sgu.sphere_inventory != p1_inv and sgu.sphere_inventory.get_count(SphereInventory.SphereType.SPHERE) > 0,
		"Player 2 has their own spheres (their level rewards)")

	# Unlock a node on P2's grid: P2's spheres pay, P1's grid is untouched.
	var target_id := -1
	for n in sgu.sphere_grid.get_all_nodes():
		if not n.unlocked and sgu.sphere_grid.is_unlockable(n.id) \
				and SphereGrid.requirements_met(n, p2.get_stats()):
			target_id = n.id
			break
	_check(target_id >= 0, "Player 2's grid has an unlockable node")
	if target_id >= 0:
		var before_p2: int = sgu.sphere_inventory.get_count(SphereInventory.SphereType.SPHERE)
		var before_p1: int = p1_inv.get_count(SphereInventory.SphereType.SPHERE)
		sgu._open_detail_popup(target_id)
		sgu._on_unlock_pressed()
		_check(sgu.sphere_grid.get_node_by_id(target_id).unlocked, "the node unlocks on Player 2's grid")
		_check(not p1_grid.get_node_by_id(target_id).unlocked, "Player 1's grid is untouched")
		_check(sgu.sphere_inventory.get_count(SphereInventory.SphereType.SPHERE) == before_p2 - 1, "Player 2's sphere pays")
		_check(p1_inv.get_count(SphereInventory.SphereType.SPHERE) == before_p1, "Player 1's spheres are untouched")

	# Stat points spent on the P2 tab land on P2.
	var s1: PlayerStats = p1.get_stats()
	var s2: PlayerStats = p2.get_stats()
	s2.unspent_stat_points = 2
	var str1: int = s1.strength
	var str2: int = s2.strength
	stu.stats_allocated.emit({"strength": 2})
	_check(s2.strength == str2 + 2 and s2.unspent_stat_points == 0, "Stats on the P2 tab spend Player 2's points")
	_check(s1.strength == str1, "Player 1's stats are untouched")

	# TAB swaps back.
	var ev := InputEventKey.new()
	ev.keycode = KEY_TAB
	ev.pressed = true
	stu._input(ev)
	await process_frame
	_check(main._progression_index == 0 and stu.player_stats == s1, "TAB swaps the screen back to Player 1")
	_check(stu.skill_tree == p1_tree and sgu.sphere_grid == p1_grid and sgu.sphere_inventory == p1_inv,
		"Player 1's tree, grid and spheres come back")

	# Closing returns to P1 even from P2's page.
	stu.hero_switch_requested.emit(1)
	await process_frame
	stu.hide_panel()
	await process_frame
	_check(main._progression_index == 0 and stu.skill_tree == p1_tree and sgu.sphere_grid == p1_grid,
		"closing the screen leaves it on Player 1")

	# Controlling P2 opens on P2; their unlock persisted.
	main._switch_active_player()
	await process_frame
	main._open_progression_screen()
	await process_frame
	_check(main._progression_index == 1, "opens on Player 2 while they're in control")
	if target_id >= 0:
		_check(sgu.sphere_grid.get_node_by_id(target_id).unlocked, "Player 2's unlock is still there")
	stu.hide_panel()

	# Ally level-up pays Player 2's spheres.
	var p2inv: SphereInventory = main._progression_sets[1]["inventory"]
	var c: int = p2inv.get_count(SphereInventory.SphereType.SPHERE)
	main._on_ally_leveled_up(s2.current_level + 1)
	_check(p2inv.get_count(SphereInventory.SphereType.SPHERE) > c, "Player 2's level-up grants their spheres")

	# The save snapshot is Player 1's.
	var prog: Dictionary = main._save_player_progression(false)
	_check(prog["skill_tree"] == p1_tree and prog["sphere_grid"] == p1_grid, "the save carries Player 1's tree and grid")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
