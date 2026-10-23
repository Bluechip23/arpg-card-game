extends SceneTree

## The Choose Your Character screen, after the designer's board (2026-10-23):
## one row per hero — the portrait, the name in the hero's colour, what the
## hero is rewarded for, then the four passive trees by name with their three
## passives each as icon squares (twelve), every square explaining its passive
## on hover. Clicking a row (or one of its squares) chooses the hero.
## Run: godot --headless --path . --script tests/test_character_select_screen.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _click(target: Control) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	target._gui_input(ev)

func _run() -> void:
	print("=== Choose Your Character screen ===")
	var screen = load("res://scenes/character/character_select.tscn").instantiate()
	get_root().add_child(screen)
	await process_frame
	var rows: Array = screen.character_container.get_children().filter(func(c): return c is CharacterRow)
	_check(rows.size() == 6, "five heroes and the Customize option (%d rows)" % rows.size())
	var heroes := CharacterData.get_all_characters()
	var all_icons := {}
	for i in range(heroes.size()):
		var hero: CharacterData = heroes[i]
		var row: CharacterRow = rows[i]
		var hn := hero.character_name
		_check(row.character_data.get_base_character() == hn, "row %d is %s" % [i, hn])
		var portrait := row.find_child("Portrait", true, false)
		var pics: Array = portrait.find_children("*", "TextureRect", true, false) if portrait else []
		_check(pics.size() == 1 and pics[0].texture != null
			and pics[0].texture.resource_path == CharacterData.PORTRAIT_DIR + hn.to_lower() + ".png",
			"%s shows the board's portrait" % hn)
		var name_lbl: Label = row.find_child("Name", true, false)
		_check(name_lbl != null and name_lbl.text == hn.to_upper()
			and name_lbl.get_theme_color("font_color") == hero.get_accent_color(), "%s's name is in the hero's colour" % hn)
		var blurb: Label = row.find_child("RewardedFor", true, false)
		_check(blurb != null and blurb.text.begins_with("Rewarded for") and blurb.text == hero.get_rewarded_for(),
			"%s says what the hero is rewarded for" % hn)
		# (UiTheme wraps every tooltip, so line breaks read as spaces.)
		var id_tip := str(portrait.tooltip_text).replace("\n", " ")
		_check(id_tip.contains("Unique passive: %s" % hero.passive_description) and id_tip.contains("Slots: "),
			"%s's portrait tooltip carries the unique passive and slots" % hn)
		# Four trees, named after the hero's archetype lanes, three squares each.
		var lanes: Array = SkillTreeData.create_tree_for(hn).get_archetype_lanes()
		var heads: Array = row.find_children("TreeName", "Label", true, false)
		var head_texts: Array = heads.map(func(l): return l.text)
		var lane_names: Array = lanes.map(func(l): return str(l["name"]).to_upper())
		_check(heads.size() == 4 and head_texts == lane_names, "%s's four trees are %s" % [hn, head_texts])
		var squares: Array = row.find_children("*", "PassiveSquare", true, false)
		_check(squares.size() == 12, "%s shows 12 passive squares (%d)" % [hn, squares.size()])
		for sq in squares:
			var icon: TextureRect = sq.get_node_or_null("Icon")
			_check(icon != null and icon.texture != null, "%s: %s has its picture" % [hn, sq.option.name])
			if icon and icon.texture:
				_check(not all_icons.has(icon.texture.resource_path),
					"%s: %s's picture is its own (%s)" % [hn, sq.option.name, icon.texture.resource_path.get_file()])
				all_icons[icon.texture.resource_path] = true
			var tip: Control = sq._make_custom_tooltip(sq.tooltip_text)
			var tip_text := ""
			if tip:
				for l in tip.find_children("*", "Label", true, false):
					tip_text += l.text + "\n"
				tip.free()
			_check(sq.tooltip_text != "" and sq.option.name in tip_text and "First point:" in tip_text
				and sq.archetype in tip_text, "%s: hovering %s explains it" % [hn, sq.option.name])
	# The Customize row has no trees: they come from the answers.
	var quiz: CharacterRow = rows[5]
	_check(quiz.character_data.character_name == "Customize"
		and quiz.find_children("*", "PassiveSquare", true, false).is_empty(), "the Customize row has no passive squares")

	# Clicking a hero's row chooses the hero; clicking a square does too.
	_click(rows[0])
	_check(screen.confirm_overlay.visible and screen._selected_character.get_base_character() == "Ryan",
		"clicking Ryan's row opens the confirm dialog for Ryan")
	screen._on_cancel_pressed()
	var brad_sq: PassiveSquare = rows[4].find_children("*", "PassiveSquare", true, false)[5]
	_check(brad_sq.mouse_filter == Control.MOUSE_FILTER_PASS, "a square passes its click on to the row")
	_click(rows[4])
	_check(screen.confirm_overlay.visible and screen._selected_character.get_base_character() == "Brad",
		"clicking Brad's row chooses Brad")
	screen.queue_free()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
