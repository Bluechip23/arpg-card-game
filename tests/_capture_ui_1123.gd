extends SceneTree
## Screens for the 2026-11-23 UI pass: the inventory's card window (the real
## card face), the Stats tab under its tabs, and a stat's info window.
## Run: xvfb-run godot --path . --script tests/_capture_ui_1123.gd -- <outdir>
var _out := "/tmp"
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: _out = a[0]
	_run.call_deferred()
func _shot(name: String) -> void:
	for _i in range(6): await process_frame
	get_root().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
func _run() -> void:
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(10): await process_frame
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	var inv = main.player.get_inventory()
	var card: Card = main.deck_manager.draw_pile[0].duplicate_card() if main.deck_manager.draw_pile[0].has_method("duplicate_card") else main.deck_manager.draw_pile[0]
	inv.stored_cards.append(card)
	var panel = main.character_panel
	panel.show_panel()
	panel._on_card_cell_clicked(card, inv.stored_cards.find(card))
	await _shot("card_window")
	panel.hide_panel()
	var st = main.player.get_stats()
	st.unspent_stat_points = 3
	main._open_progression_screen()
	var ui = main.skill_tree_ui
	ui._on_tab_stats()
	await _shot("stats_tab")
	ui._toggle_stat_info("DEX")
	await _shot("stat_info")
	ui._on_tab_skill_tree()
	await _shot("back_to_passives")
	quit()
