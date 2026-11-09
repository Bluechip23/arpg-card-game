extends SceneTree

## Painted passive boards (designer, 2026-11-09): the Passives tab shows the
## hero's painting, and each archetype's three passives sit as an upside-down
## triangle beside its corner scene — Brad: Berserker top left, Warden top
## right, The Ancient bottom left, The Fallen bottom right; Cory: Atrophist,
## Monk, Lurker, Druid; Jeremy: Abjurer, Evocation, Poltergeist, Shepherd;
## Ryan: Light Foot, Apothecary, Shadow Blade, Relentless Blade (his narrow
## gap puts the bottom pair's names beside them, toward their scenes). First passive top-left, second top-right, the final
## unlock at the bottom point; each side's two triangles share their columns.
## Investing still works through the board's circles (stage gates included),
## and a hero without a board keeps the lane table.
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

## The board for `hero`: its painting, the four triangles in their quarters
## with the passives in order, no circles overlapping, and each column pair
## (top triangle over bottom triangle) lined up.
func _check_board(ui: SkillTreeUI, hero: String, painting: String, expect: Dictionary, columns: Array) -> void:
	_check(not SkillTreeUI.board_for(ui.skill_tree).is_empty(), "%s has a passive board" % hero)
	_check(is_instance_valid(ui._board_view) and ui._board_view.visible, "%s: the Passives tab shows the board" % hero)
	_check(not ui.scroll_container.visible, "%s: the lane table is hidden behind it" % hero)
	var art: TextureRect = ui._board_view.get_node_or_null("PassiveBoard")
	_check(art != null and art.texture != null and art.texture.resource_path.ends_with(painting),
		"%s: the board is %s" % [hero, painting])
	var view_rect: Rect2 = ui._board_view.get_global_rect()
	var art_rect: Rect2 = art.get_global_rect() if art else Rect2()
	_check(art_rect.size.x >= view_rect.size.x - 1.0 or art_rect.size.y >= view_rect.size.y - 1.0,
		"%s: the painting fills the panel along one side at least" % hero)
	_check(absf(art_rect.size.x / art_rect.size.y - 1774.0 / 887.0) < 0.01, "%s: the painting keeps its aspect" % hero)
	_check(ui._board_view.get_node_or_null("BoardInfo") != null, "%s: the centre holds the points / stage info" % hero)

	# Left / right is judged against the middle of the four triangles (a
	# board's gap need not be centred on the painting); top / bottom against
	# the painting's middle.
	var mid: Vector2 = art_rect.get_center()
	var xs: Array[float] = []
	for arch in expect:
		for stage in range(3):
			var b := _circle(ui, arch, stage)
			if b:
				xs.append(b.get_global_rect().get_center().x)
	if not xs.is_empty():
		mid.x = (xs.min() + xs.max()) * 0.5
	var all_rects: Array[Rect2] = []
	var corners := {}
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
		corners[arch] = c
		# Upside-down triangle: 1 top-left, 2 top-right, 3 the bottom point.
		_check(c[0].x < c[1].x and absf(c[0].y - c[1].y) < 1.0, "%s: passive 1 top-left, passive 2 top-right" % arch)
		_check(c[2].y > c[0].y + 20.0 and c[2].x > c[0].x and c[2].x < c[1].x,
			"%s: the final passive is the bottom point between them" % arch)
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
	_check(all_rects.size() == 12 and not overlap, "%s: 12 circles, none overlapping" % hero)
	for pair in columns:
		if corners.has(pair[0]) and corners.has(pair[1]):
			var a: Array = corners[pair[0]]
			var b: Array = corners[pair[1]]
			_check(absf(a[0].x - b[0].x) < 1.0 and absf(a[1].x - b[1].x) < 1.0,
				"%s lines up over %s" % [pair[0], pair[1]])

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

	var brad := {
		"Berserker": {"left": true, "top": true, "ids": ["enraged_will", "directed_strength", "life_steal"]},
		"Warden": {"left": false, "top": true, "ids": ["in_the_trenches", "the_way_of_the_plate", "pristine_armor"]},
		"The Ancient": {"left": true, "top": false, "ids": ["stone_skin", "ancestral_aid", "vines_codependence"]},
		"The Fallen": {"left": false, "top": false, "ids": ["point_to_prove", "redemption", "solemn_independence"]},
	}
	_check_board(ui, "Brad", "brad_passive_board.webp", brad, [["Berserker", "The Ancient"], ["Warden", "The Fallen"]])

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

	# --- Cory's board ---
	ui.set_skill_tree(SkillTreeData.create_cory_tree())
	await process_frame
	await process_frame
	var cory := {
		"Atrophist": {"left": true, "top": true, "ids": ["wither", "territorial_death", "death_as_lifeblood"]},
		"Monk": {"left": false, "top": true, "ids": ["energy_barrier", "expel_negativity", "self_reliance"]},
		"Lurker": {"left": true, "top": false, "ids": ["prey_on_the_weak", "eat", "serial_killer"]},
		"Druid": {"left": false, "top": false, "ids": ["budding", "circle_of_life", "regrowth"]},
	}
	_check_board(ui, "Cory", "cory_passive_board.webp", cory, [["Atrophist", "Lurker"], ["Monk", "Druid"]])

	# --- Jeremy's board ---
	ui.set_skill_tree(SkillTreeData.create_jeremy_tree())
	await process_frame
	await process_frame
	var jeremy := {
		"Abjurer": {"left": true, "top": true, "ids": ["a_mage's_favor", "kinetic_armor", "fresh_start"]},
		"Evocation": {"left": false, "top": true, "ids": ["arcane_overflow", "harnessed_power", "mana_surge"]},
		"Poltergeist": {"left": true, "top": false, "ids": ["tricks_of_death", "seance", "haunted_rebuke"]},
		"Shepherd": {"left": false, "top": false, "ids": ["i_heal_you", "whispers_of_the_flock", "blood_libation"]},
	}
	_check_board(ui, "Jeremy", "jeremy_passive_board.webp", jeremy, [["Abjurer", "Poltergeist"], ["Evocation", "Shepherd"]])

	# --- Ryan's board ---
	ui.set_skill_tree(SkillTreeData.create_ryan_tree())
	await process_frame
	await process_frame
	var ryan := {
		"Light Foot": {"left": true, "top": true, "ids": ["quick_step", "ladder_work", "let's_dance"]},
		"Apothecary": {"left": false, "top": true, "ids": ["stimulant", "pop_rocks", "mad_scientist"]},
		"Shadow Blade": {"left": true, "top": false, "ids": ["now_you_see_me", "surprise_opener", "eye_scrape"]},
		"Relentless Blade": {"left": false, "top": false, "ids": ["keep_them_guessing", "from_the_hip", "nimble_assault"]},
	}
	_check_board(ui, "Ryan", "ryan_passive_board.webp", ryan, [["Light Foot", "Shadow Blade"], ["Apothecary", "Relentless Blade"]])
	var sb_lbl: Label = ui._board_view.get_node("Triangle_ShadowBlade/ArchetypeLabel")
	var rb_lbl: Label = ui._board_view.get_node("Triangle_RelentlessBlade/ArchetypeLabel")
	_check(sb_lbl.get_global_rect().end.x <= _circle(ui, "Shadow Blade", 0).get_global_rect().position.x,
		"Shadow Blade's name sits left of its triangle")
	_check(rb_lbl.get_global_rect().position.x >= _circle(ui, "Relentless Blade", 1).get_global_rect().end.x,
		"Relentless Blade's name sits right of its triangle")

	# --- A hero without a board keeps the lane table ---
	ui.set_skill_tree(SkillTreeData.create_stephen_tree())
	await process_frame
	_check(SkillTreeUI.board_for(ui.skill_tree).is_empty(), "Stephen has no board (yet)")
	_check(not ui._board_view.visible, "Stephen's tab hides the board")
	_check(ui.scroll_container.visible and ui.table_container.get_child_count() > 0, "Stephen gets the lane table")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
