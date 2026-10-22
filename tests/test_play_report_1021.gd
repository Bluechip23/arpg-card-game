extends SceneTree

## The 2026-10-21 play-report fixes, checked in a booted dojo:
##  - a fallen (0 HP) character cannot move;
##  - menu windows (pile viewer, maintained list) sit on a layer above the HUD,
##    and the maintained list opens beside its icon;
##  - maintained powers are listed in the character window's active effects;
##  - Raise Shield shares the auto-attack row and shows its armor;
##  - Sticky counts down on the card face; long card text shrinks to fit;
##  - the Archer Rat shoots out to 6.
## Run: godot --headless --path . --script tests/test_play_report_1021.gd

var failures := 0
var main = null

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _settle(frames: int = 6) -> void:
	for _i in range(frames):
		await process_frame

func _layer_of(node: Node) -> int:
	var n := node
	while n != null:
		if n is CanvasLayer:
			return (n as CanvasLayer).layer
		n = n.get_parent()
	return 0

func _initialize() -> void:
	_run()

func _run() -> void:
	main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	await _settle()
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	_check(main.player != null, "the dojo is up")
	if main.player == null:
		print("=== %d failure(s) ===" % failures)
		quit(1)
		return
	var stats = main.player.get_stats()
	var dm = main.deck_manager

	# --- Windows above the HUD ---
	var hud_layer: int = (main.get_node("UI") as CanvasLayer).layer
	_check(_layer_of(main._pile_popup.panel) > hud_layer, "the pile viewer (discard) sits above the HUD layer (%d > %d)" % [_layer_of(main._pile_popup.panel), hud_layer])
	_check(_layer_of(main._maintained_list.panel) > hud_layer, "the maintained list sits above the HUD layer")
	_check(main.passive_display_container != null and _layer_of(main.passive_display_container) < _layer_of(main._pile_popup.panel), "the passive tray is below the windows")

	# --- Maintained power: icon, window beside it, character window ---
	var power := Card.create_by_id("fountain_of_life")
	if power == null:
		power = Card.create_by_id("block")
	power.maintain_cost = maxi(power.maintain_cost, 10)
	dm.maintained_cards.append(power)
	dm.maintained_changed.emit()
	main._maintained_list.refresh()
	await _settle(3)
	main.maintained_icon.visible = true
	await _settle(2)
	main._maintained_list.toggle()
	await _settle(2)
	var icon_r: Rect2 = main.maintained_icon.get_global_rect()
	var pan_r: Rect2 = main._maintained_list.panel.get_global_rect()
	_check(main._maintained_list.is_showing() and absf(pan_r.position.y - (icon_r.end.y + 6.0)) < 40.0 and absf(pan_r.position.x - icon_r.position.x) < 300.0,
		"the maintained window opens beside its icon (icon %s, window %s)" % [str(icon_r.position), str(pan_r.position)])
	main._maintained_list.toggle()
	var cp = main.character_panel
	cp.show_panel()
	await _settle(2)
	cp.update_display()
	await _settle(2)
	var found := false
	for row in cp._effects_box.get_children():
		for ch in row.get_children():
			if ch is Label and ch.text.contains("(maintained)"):
				found = true
	_check(found, "the maintained power is listed in the character window's active effects")
	cp.toggle_panel()

	# --- Raise Shield on the attack row with its armor ---
	_check(main._block_button.get_parent() == main._attack_button.get_parent(), "Raise Shield shares the auto-attack row")
	var inv = main.player.get_inventory()
	var shield = ItemData.create("wooden_shield")
	inv.stored_items.append(shield)
	inv.equip_item(shield, 1)
	main._update_block_button_visibility()
	var want: int = (shield.armor_bonus if shield.armor_bonus > 0 else 3) + inv.get_two_hand_block_bonus(shield)
	_check(main._block_button.visible and main._block_button.text == "+%d  4T" % want, "the shield button reads its armor beside its tempo (%s)" % main._block_button.text)

	# --- Sticky counts down; long text shrinks ---
	var gulp := Card.create_by_id("gulped_potion")
	_check(gulp.description == "Heal 1. Sticky 3.", "Gulped Potion reads 'Heal 1. Sticky 3.'")
	gulp.consecutive_uses = 1
	_check(gulp.get_display_description({}) == "Heal 1. Sticky 2.", "after one use the face reads Sticky 2 (%s)" % gulp.get_display_description({}))
	var ui_scene: PackedScene = load("res://scenes/cards/card_ui.tscn")
	var short_ui = ui_scene.instantiate()
	var long_ui = ui_scene.instantiate()
	get_root().add_child(short_ui)
	get_root().add_child(long_ui)
	await _settle(1)
	var short_c := Card.create_by_id("slash")
	var long_c := Card.create_by_id("slash")
	long_c.card_name = "A Very Long Card Name That Overflows"
	long_c.description = "Deal 10 damage. Then deal 10 more damage to every enemy within three tiles, apply two Vulnerable and two Weaken to each, draw two cards, and gain eight armor for every enemy struck by this effect."
	short_ui.setup(short_c, 0)
	long_ui.setup(long_c, 1)
	await _settle(1)
	var fs_short: int = short_ui.desc_label.get_theme_font_size("normal_font_size")
	var fs_long: int = long_ui.desc_label.get_theme_font_size("normal_font_size")
	_check(fs_long < fs_short, "a long description is set smaller (%d < %d)" % [fs_long, fs_short])
	_check(long_ui.name_label.get_theme_font_size("font_size") < short_ui.name_label.get_theme_font_size("font_size"), "a long name is set smaller")
	short_ui.queue_free()
	long_ui.queue_free()

	# --- Archer Rat range 6 ---
	_check(int(EnemyDefs.DEFS["ARCHER_RAT"]["range"]) == 6, "the Archer Rat's range is 6")

	# --- Test mode: a granted passive carries its chosen rank ---
	var opt := SkillTreeData.SkillOption.new()
	opt.option_type = SkillTreeData.OptionType.PASSIVE
	opt.name = "Stone Skin"
	opt.passive_id = "stone_skin"
	main._on_sandbox_grant_passive(opt, 12)
	await _settle(2)
	_check(stats.skill_tree_passives.has("stone_skin") and stats.get_passive_level("stone_skin") == 12, "a test-mode passive is granted at rank 12 (%d)" % stats.get_passive_level("stone_skin"))

	# --- Fallen: no movement ---
	var start: Vector3 = main.player.position
	stats.current_health = 0
	var cell: Vector2i = main.grid_manager.world_to_grid(main.player.position) + Vector2i(0, 1)
	var moved: bool = main.player.move_to_grid(main.grid_manager.grid_to_world(cell), 1)
	_check(not moved and main.player.preview_path_cells(main.grid_manager.grid_to_world(cell), 3).is_empty(), "a fallen character cannot move or preview a route")
	stats.current_health = stats.max_health

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
