extends SceneTree

## Hover windows show the thing's icon large (designer, 2026-10-28): buffs,
## debuffs (StatusHoverPopup) and passives (the tray boxes and the skill
## tree's nodes, IconTooltip). Also: town NPCs stand TOWN_NPC_SCALE larger,
## and the camera zooms one step closer than before.
## Run: godot --headless --path . --script tests/test_hover_icons.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _icon_px(c: Node) -> float:
	var big := c.find_child("BigIcon", true, false) as Control
	if big == null:
		return 0.0
	var pic := big.find_child("Icon", true, false) as TextureRect
	return pic.custom_minimum_size.x if pic and pic.texture else 0.0

func _run() -> void:
	print("=== Big icons in hover windows ===")
	var holder := Control.new()
	get_root().add_child(holder)
	var badge := Control.new()
	badge.size = Vector2(20, 20)
	holder.add_child(badge)
	await process_frame
	var poison := StatusIcons.get_icon("Poison")
	StatusHoverPopup.show_for(badge, "Poison", Color.GREEN, "Hurts.", Callable(), "", poison)
	await process_frame
	var pop = StatusHoverPopup._inst
	_check(_icon_px(pop) >= 64, "a debuff's hover window shows its icon at %d px" % _icon_px(pop))
	StatusHoverPopup.show_for(badge, "Gold", Color.YELLOW, "Coins.", Callable())
	await process_frame
	_check(_icon_px(pop) == 0.0 and not pop._icon_slot.visible, "a window with no icon (loot) stays text-only")

	var box := PassiveBoxUI.new()
	holder.add_child(box)
	box._icon = SkillIconArt.passive("enraged_will")
	var tip = box._make_custom_tooltip("Enraged Will")
	_check(tip != null and _icon_px(tip) >= 64, "a passive's tooltip shows its icon large")
	var btn := IconTooltipButton.new()
	btn.tooltip_icon = box._icon
	var tip2 = btn._make_custom_tooltip("Enraged Will")
	_check(tip2 != null and _icon_px(tip2) >= 64, "and so does a skill tree node's")

	# The cooldown is said once: the passive's own text already gives it.
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("sandbox_mode", true)
	get_root().add_child(main)
	for _i in range(6):
		await process_frame
	var st: PlayerStats = main.player.get_stats()
	st.add_skill_tree_passive("enraged_will")
	st.passive_levels["enraged_will"] = 5
	var pb := PassiveBoxUI.new()
	holder.add_child(pb)
	var ew_desc := ""
	for row in SkillTreeData.create_brad_tree().rows:
		for o in row.options:
			if o.passive_id == "enraged_will":
				ew_desc = o.description
	_check(ew_desc.contains("Cooldown"), "Enraged Will's own text gives its cooldown")
	pb.setup("enraged_will", "Enraged Will", ew_desc, st, main.tempo_manager)
	var n := pb.tooltip_text.to_lower().count("cooldown")
	_check(n == 1, "Enraged Will's tooltip gives its cooldown once (%d)" % n)
	main.queue_free()
	await process_frame
	_check(CameraView.ZOOM_MAX == 5.0, "the camera zooms in one step further (to %dx)" % int(CameraView.ZOOM_MAX))

	var town = load("res://scenes/menus/town.tscn").instantiate()
	town.starting_character = CharacterData.create_brad()
	get_root().add_child(town)
	for _i in range(4):
		await process_frame
	for path in ["Vendors/Sellsword/Figure", "Vendors/Olorin/Figure", "Vendors/Blacksmith/Stall/Smith"]:
		var f = town.get_node_or_null(path)
		_check(f != null and is_equal_approx(f.scale.x, town.TOWN_NPC_SCALE) and town.TOWN_NPC_SCALE > 1.0,
			"%s stands %.2fx" % [path, f.scale.x if f else 0.0])
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
