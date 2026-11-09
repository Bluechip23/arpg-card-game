extends SceneTree

## Brad's painted passive board (designer, 2026-11-09): the Passives tab shows
## his painting, and each archetype's three passives sit as an upside-down
## triangle beside its corner scene — Berserker top left, Warden top right,
## The Ancient bottom left, The Fallen bottom right; first passive top-left,
## second top-right, the final unlock at the bottom point. Investing still
## works through the board's circles (stage gates included), and a hero
## without a board keeps the lane table.
## Run: godot --headless --path . --script tests/test_passive_board.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

## The circle (button) of `arch`'s passive at `stage` on the board, or null.
func _circle(ui: SkillTreeUI, arch: String, stage: int) -> Button:
	var tri: Node = ui._board_view.get_node_or_null("Triangle_" + arch.replace(" ", ""))
	if tri == null:
		return null
	return tri.get_node_or_null("Passive_%d/PassiveButton" % stage) as Button

func _run() -> void:
	print("=== Passive board ===")
	await process_frame
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(8):
		await process_frame
	var g := 0
	while main.olorin and main.olorin.is_busy() and g < 10:
		main.olorin._close()
		g += 1
		await process_frame
	var st = main.player.get_stats()
	var ui: SkillTreeUI = main.skill_tree_ui
	ui.player_stats = st
	st.unspent_passive_points = 0
	ui.set_skill_tree(SkillTreeData.create_brad_tree())
	ui.show_panel()
	await process_frame
	await process_frame

	# --- The board replaces the lane table for Brad ---
	_check(not SkillTreeUI.board_for(ui.skill_tree).is_empty(), "Brad has a passive board")
	_check(is_instance_valid(ui._board_view) and ui._board_view.visible, "the Passives tab shows the board")
	_check(not ui.scroll_container.visible, "the lane table is hidden behind it")
	var art: TextureRect = ui._board_view.get_node_or_null("PassiveBoard")
	_check(art != null and art.texture != null and art.texture.resource_path.ends_with("brad_passive_board.webp"),
		"the board is Brad's painting")
	var view_rect: Rect2 = ui._board_view.get_global_rect()
	var art_rect: Rect2 = art.get_global_rect() if art else Rect2()
	_check(art_rect.size.x >= view_rect.size.x - 1.0 or art_rect.size.y >= view_rect.size.y - 1.0,
		"the painting fills the panel along one side at least")
	_check(absf(art_rect.size.x / art_rect.size.y - 1774.0 / 887.0) < 0.01, "the painting keeps its aspect")
	_check(ui._board_view.get_node_or_null("BoardInfo") != null, "the centre holds the points / stage info")

	# --- Four triangles, each with its three passives in order ---
	var expect := {
		"Berserker": {"left": true, "top": true, "ids": ["enraged_will", "directed_strength", "life_steal"]},
		"Warden": {"left": false, "top": true, "ids": ["in_the_trenches", "the_way_of_the_plate", "pristine_armor"]},
		"The Ancient": {"left": true, "top": false, "ids": ["stone_skin", "ancestral_aid", "vines_codependence"]},
		"The Fallen": {"left": false, "top": false, "ids": ["point_to_prove", "redemption", "solemn_independence"]},
	}
	var mid: Vector2 = art_rect.get_center()
	var all_rects: Array[Rect2] = []
	for arch in expect:
		var want: Dictionary = expect[arch]
		var tri: Node = ui._board_view.get_node_or_null("Triangle_" + arch.replace(" ", ""))
		_check(tri != null, "%s has a triangle" % arch)
		if tri == null:
			continue
		var c: Array[Vector2] = []
		for stage in range(3):
			var box: Node = tri.get_node_or_null("Passive_%d" % stage)
			var btn := _circle(ui, arch, stage)
			_check(box != null and btn != null, "%s passive %d is on the board" % [arch, stage + 1])
			if box == null or btn == null:
				c.append(Vector2.ZERO)
				continue
			_check(str(box.get_meta("passive_id", "")) == want["ids"][stage],
				"%s passive %d is %s" % [arch, stage + 1, want["ids"][stage]])
			_check(btn.tooltip_text != "", "%s passive %d keeps its hover text" % [arch, stage + 1])
			var r := btn.get_global_rect()
			c.append(r.get_center())
			all_rects.append(r)
			_check(view_rect.encloses(r), "%s passive %d is inside the board" % [arch, stage + 1])
		# Upside-down triangle: 1 top-left, 2 top-right, 3 the bottom point.
		_check(c[0].x < c[1].x and absf(c[0].y - c[1].y) < 1.0, "%s: passive 1 top-left, passive 2 top-right" % arch)
		_check(c[2].y > c[0].y + 20.0 and c[2].x > c[0].x and c[2].x < c[1].x,
			"%s: the final passive is the bottom point between them" % arch)
		# The triangle's quadrant of the painting.
		var side_ok := true
		var height_ok := true
		for p in c:
			side_ok = side_ok and ((p.x < mid.x) == want["left"])
			height_ok = height_ok and ((p.y < mid.y) == want["top"])
		_check(side_ok and height_ok, "%s sits in the %s %s quarter" % [arch,
			"top" if want["top"] else "bottom", "left" if want["left"] else "right"])
		var lbl: Label = tri.get_node_or_null("ArchetypeLabel")
		_check(lbl != null and lbl.text.begins_with(arch), "%s is labelled by its triangle" % arch)
	var overlap := false
	for i in range(all_rects.size()):
		for j in range(i + 1, all_rects.size()):
			if all_rects[i].intersects(all_rects[j]):
				overlap = true
	_check(all_rects.size() == 12 and not overlap, "12 circles, none overlapping")

	# --- States: stage 1 open, later stages locked with nothing invested ---
	_check(not _circle(ui, "Berserker", 0).disabled, "first passives are open")
	_check(_circle(ui, "Berserker", 1).disabled and _circle(ui, "Warden", 2).disabled, "later passives start locked")

	# --- Investing through the board's circles ---
	st.unspent_passive_points = 7
	_circle(ui, "Warden", 2).pressed.emit()   # locked: refused
	_check(st.get_passive_level("pristine_armor") == 0 and st.unspent_passive_points == 7, "a locked circle takes no point")
	_circle(ui, "Berserker", 0).pressed.emit()
	await process_frame
	_check(st.get_passive_level("enraged_will") == 1 and st.unspent_passive_points == 6, "clicking a circle invests a point")
	var rank: Label = _circle(ui, "Berserker", 0).get_parent().get_node("RankLabel")
	_check(rank.text == "1 / %d" % SkillTreeData.PASSIVE_MAX_LEVEL, "the board redraws with the new rank")
	# Four more across other paths' first passives open stage 2 everywhere.
	for arch in ["Warden", "The Ancient", "The Fallen", "Warden"]:
		_circle(ui, arch, 0).pressed.emit()
		await process_frame
	_check(not _circle(ui, "The Fallen", 1).disabled, "5 points in stage 1 open every path's second passive")
	_check(_circle(ui, "The Fallen", 2).disabled, "the final passives stay locked")
	_circle(ui, "The Fallen", 1).pressed.emit()
	await process_frame
	_check(st.get_passive_level("redemption") == 1, "a newly opened second passive takes a point")
	var pts: Label = ui._board_view.find_child("PointsLabel", true, false)
	_check(pts != null and pts.text == "Passive Points: %d" % st.unspent_passive_points, "the centre shows the points left")

	# --- Tabs still switch ---
	ui._switch_to_tab(SkillTreeUI.Tab.SPHERE_GRID)
	await process_frame
	_check(not ui._board_view.visible, "the board hides on the Sphere Grid tab")
	ui._switch_to_tab(SkillTreeUI.Tab.SKILL_TREE)
	await process_frame
	_check(ui._board_view.visible and not ui.scroll_container.visible, "and comes back on Passives")

	# --- A hero without a board keeps the lane table ---
	ui.set_skill_tree(SkillTreeData.create_cory_tree())
	await process_frame
	_check(SkillTreeUI.board_for(ui.skill_tree).is_empty(), "Cory has no board (yet)")
	_check(not ui._board_view.visible, "Cory's tab hides the board")
	_check(ui.scroll_container.visible and ui.table_container.get_child_count() > 0, "Cory gets the lane table")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
