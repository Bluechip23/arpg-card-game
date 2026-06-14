class_name RoguelikeMapUI
extends Control

## The roguelike run map screen. Generates a run, draws the node graph
## (Slay-the-Spire style, first floor at the bottom, boss at the top), lets the
## player navigate reachable nodes, and resolves each node:
##   - Monster / Elite / Boss launch the existing card-battle scene.
##   - Shop / Campfire / Unknown open a lightweight encounter panel.

const MainScenePath := "res://scenes/core/main.tscn"
const TitleScenePath := "res://scenes/menus/title_menu.tscn"

const TOP_MARGIN := 96.0
const BOTTOM_MARGIN := 48.0
const SIDE_MARGIN := 280.0
const NODE_SIZE := 46.0

## Set by the character-select screen before this scene is added to the tree.
var character: CharacterData = null
## Optionally injected (e.g. from a saved world); defaults to a fresh world.
var world: WorldData = null
## The saved character behind this run (null for preset/test characters). Used
## to carry story progression into battles and to persist/resume the single
## active run so a character can only have one going at a time.
var save: SaveData = null

var save_progression: Dictionary = {}
var save_world_level: int = 1

var run: RoguelikeRun = null
var _node_buttons: Dictionary = {}   ## node id -> Button
var _header: Label = null
var _modal: Control = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	if save:
		save_progression = save.progression
		save_world_level = save.world_level
		# Restore this character's shared world meta (unlocked relics, node
		# upgrades, etc.) so a new run snapshots the latest unlocks.
		if not save.world_meta.is_empty():
			world = WorldData.from_dict(save.world_meta)
	if not world:
		world = WorldData.make_new("Prime World")
	if not character:
		character = CharacterData.create_ryan()

	if save and not save.active_run.is_empty():
		# Resume the character's single in-progress run.
		run = RoguelikeRun.from_dict(save.active_run, character, world)
		print("[ROGUELIKE] Resumed in-progress run for %s" % character.character_name)
	else:
		# Start a fresh run and record it as this character's active run.
		run = RoguelikeRun.new()
		run.start(character, world)
		# If this character has saved story progression, size the run HP pool
		# from their real max health rather than the vanilla base-health formula.
		if not save_progression.is_empty():
			var saved_stats: Dictionary = save_progression.get("stats", {})
			if saved_stats.has("max_health"):
				run.max_hp = int(saved_stats["max_health"])
				run.hp = run.max_hp
		_persist_run()

	_setup_header()
	_build_nodes()
	_layout()
	_refresh()

	get_viewport().size_changed.connect(_on_viewport_resized)

func _persist_run() -> void:
	## Save (or clear) the character's single active run plus the shared world
	## meta. No-op for presets, which have no save to write to.
	if not save:
		return
	save.active_run = {} if run.finished else run.to_dict()
	save.world_meta = world.to_dict()
	SaveManager.save_game(save.save_slot, save)

func _on_viewport_resized() -> void:
	_layout()
	queue_redraw()

# ----------------------------------------------------------------------------
# Build
# ----------------------------------------------------------------------------

func _setup_header() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 72.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.13, 0.95)
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.5)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	bar.add_theme_stylebox_override("panel", style)
	add_child(bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	bar.add_child(hbox)

	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 18)
	_header.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_header)

	var quit_btn := Button.new()
	quit_btn.text = "Abandon Run"
	quit_btn.add_theme_font_size_override("font_size", 14)
	quit_btn.pressed.connect(_on_quit_pressed)
	hbox.add_child(quit_btn)

func _build_nodes() -> void:
	for id in run.map.nodes_by_id.keys():
		var node: RoguelikeMapNode = run.map.nodes_by_id[id]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
		btn.size = Vector2(NODE_SIZE, NODE_SIZE)
		btn.text = RoguelikeMapNode.type_glyph(node.type)
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		btn.add_theme_color_override("font_disabled_color", Color(0.95, 0.95, 0.95))
		btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		btn.tooltip_text = RoguelikeMapNode.type_display_name(node.type)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_node_pressed.bind(node.id))
		add_child(btn)
		_node_buttons[node.id] = btn

func _node_style(color: Color, border: Color, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.border_width_left = border_w
	s.border_width_right = border_w
	s.border_width_top = border_w
	s.border_width_bottom = border_w
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.corner_radius_bottom_left = 8
	s.corner_radius_bottom_right = 8
	return s

# ----------------------------------------------------------------------------
# Layout & drawing
# ----------------------------------------------------------------------------

func _layout() -> void:
	if not run or not run.map:
		return
	var view := get_viewport_rect().size
	var total_rows: int = run.map.total_rows()
	var usable_h: float = view.y - TOP_MARGIN - BOTTOM_MARGIN
	var usable_w: float = view.x - SIDE_MARGIN * 2.0

	for r in range(total_rows):
		var row_nodes: Array = run.map.rows[r]
		var n: int = row_nodes.size()
		var y: float = view.y - BOTTOM_MARGIN
		if total_rows > 1:
			y = view.y - BOTTOM_MARGIN - float(r) / float(total_rows - 1) * usable_h
		for c in range(n):
			var x: float = view.x * 0.5
			if n > 1:
				x = SIDE_MARGIN + float(c) / float(n - 1) * usable_w
			var node: RoguelikeMapNode = row_nodes[c]
			node.ui_pos = Vector2(x, y)
			var btn: Button = _node_buttons.get(node.id, null)
			if btn:
				btn.position = node.ui_pos - Vector2(NODE_SIZE, NODE_SIZE) * 0.5

func _draw() -> void:
	# Background is painted here (not as a child node) so it sits BEHIND the
	# connection lines we draw next. A child ColorRect would cover them.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.04, 0.07))
	if not run or not run.map:
		return
	# Edges that lead from the player's currently reachable positions are lit so
	# the available choices for this floor read clearly.
	var available := run.available_node_ids()
	for id in run.map.nodes_by_id.keys():
		var node: RoguelikeMapNode = run.map.nodes_by_id[id]
		var from_current: bool = (node.id == run.current_node_id) or (run.current_node_id == -1 and node.row == 0)
		for nid in node.next_ids:
			var target: RoguelikeMapNode = run.map.get_node(nid)
			if not target:
				continue
			var lit: bool = from_current and available.has(nid)
			var col: Color = Color(1.0, 0.92, 0.5, 0.95) if lit else Color(0.32, 0.32, 0.42, 0.85)
			var width: float = 4.0 if lit else 2.5
			draw_line(node.ui_pos, target.ui_pos, col, width)

func _refresh() -> void:
	if not run:
		return
	_header.text = "%s   |   %s   |   Floor %d/%d   |   HP %d/%d   |   Gold %d" % [
		world.world_name, character.character_name,
		run.floor_reached, run.map.total_rows(),
		run.hp, run.max_hp, run.gold,
	]

	var available := run.available_node_ids()
	for id in _node_buttons.keys():
		var node: RoguelikeMapNode = run.map.get_node(id)
		var btn: Button = _node_buttons[id]
		var base := RoguelikeMapNode.type_color(node.type)
		if node.id == run.current_node_id:
			_style_node(btn, base, Color(1, 1, 1), 3, true)
		elif node.visited:
			_style_node(btn, base.darkened(0.55), Color(0.4, 0.4, 0.45), 1, true)
		elif available.has(id):
			btn.disabled = false
			btn.add_theme_stylebox_override("normal", _node_style(base, Color(1.0, 0.95, 0.5), 3))
			btn.add_theme_stylebox_override("hover", _node_style(base.lightened(0.2), Color(1.0, 1.0, 0.7), 3))
			btn.add_theme_stylebox_override("pressed", _node_style(base.darkened(0.1), Color(1.0, 1.0, 0.7), 3))
		else:
			_style_node(btn, base.darkened(0.4), Color(0.3, 0.3, 0.38), 1, true)
	queue_redraw()

## Applies one stylebox to every visual state of a node button. Disabled
## buttons render their "disabled" stylebox, so it must be overridden too.
func _style_node(btn: Button, color: Color, border: Color, border_w: int, disabled: bool) -> void:
	btn.disabled = disabled
	for state in ["normal", "hover", "pressed", "disabled"]:
		btn.add_theme_stylebox_override(state, _node_style(color, border, border_w))

# ----------------------------------------------------------------------------
# Node interaction
# ----------------------------------------------------------------------------

func _on_node_pressed(id: int) -> void:
	if _modal or not run.can_visit(id):
		return
	var node := run.map.get_node(id)
	if not node:
		return
	if node.is_combat():
		_launch_battle(node)
	else:
		_open_encounter_panel(node)

func _commit_node(id: int) -> void:
	run.resolve_node(id)
	_persist_run()
	_refresh()
	if run.finished:
		_show_end_overlay()

# ----------------------------------------------------------------------------
# Battle hand-off (reuses the existing card-battle scene)
# ----------------------------------------------------------------------------

func _launch_battle(node: RoguelikeMapNode) -> void:
	var main_scene = load(MainScenePath).instantiate()
	main_scene.starting_character = run.character
	# Restore the character's saved build (deck, stats, sphere grid) for the fight.
	if not save_progression.is_empty():
		main_scene.player_progression = ProgressionIO.to_live(save_progression)
		main_scene.current_world_level = save_world_level
	main_scene.roguelike_context = {
		"node_type": RoguelikeMapNode.type_id(node.type),
		"node_id": node.id,
	}
	main_scene.roguelike_battle_finished.connect(_on_battle_finished.bind(node.id, main_scene))
	# Keep this map alive but inert while the battle runs.
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(main_scene)

func _on_battle_finished(victory: bool, remaining_hp: int, node_id: int, main_scene: Node) -> void:
	if is_instance_valid(main_scene):
		main_scene.queue_free()
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	if victory:
		# Carry the player's surviving HP back to the run.
		run.hp = clampi(remaining_hp, 1, run.max_hp)
		var node := run.map.get_node(node_id)
		var reward := 25 if node and node.type == RoguelikeMapNode.Type.ELITE else 12
		if node and node.type == RoguelikeMapNode.Type.BOSS:
			reward = 50
		run.add_gold(reward)
		_commit_node(node_id)
	else:
		# Death in combat ends the run — no continue.
		run.hp = 0
		run.finished = true
		run.victorious = false
		_persist_run()
		_refresh()
		_show_end_overlay()

# ----------------------------------------------------------------------------
# Non-combat encounter panels (lightweight for the first slice)
# ----------------------------------------------------------------------------

func _open_encounter_panel(node: RoguelikeMapNode) -> void:
	var title := ""
	var body := ""
	var action_label := ""
	match node.type:
		RoguelikeMapNode.Type.CAMPFIRE:
			title = "Rest Site"
			body = "A quiet campfire. Resting restores %d HP." % _campfire_heal_amount()
			body += _active_upgrades_text("campfire")
			action_label = "Rest (+%d HP)" % _campfire_heal_amount()
		RoguelikeMapNode.Type.SHOP:
			title = "Shop"
			var discount := "  Founder's Discount is in effect." if run.has_node_upgrade("shop", "founders_discount") else ""
			body = "A wandering merchant eyes your coin purse (%d gold).%s\n\n(Wares unlock as you build this world.)" % [run.gold, discount]
			body += _active_upgrades_text("shop")
			action_label = "Leave Shop"
		RoguelikeMapNode.Type.RANDOM:
			title = "Unknown"
			body = "You stumble onto something unexpected..."
			# Unknown sites can discover a node upgrade for FUTURE runs.
			var discovered := _roll_node_upgrade_discovery()
			if discovered:
				body += "\n\nYou uncover lost knowledge: \"%s\" (%s).\nIt takes effect on your NEXT run, not this one." % [discovered.name, discovered.description]
			action_label = "Continue"
		_:
			title = RoguelikeMapNode.type_display_name(node.type)
			body = "..."
			action_label = "Continue"

	var node_id := node.id
	var on_continue := func() -> void:
		_apply_encounter_effect(node)
		_close_modal()
		_commit_node(node_id)
	_modal = _make_modal(title, body, action_label, on_continue)

func _campfire_heal_amount() -> int:
	var pct := 0.5 if run.has_node_upgrade("campfire", "deep_rest") else 0.3
	return int(round(run.max_hp * pct))

func _active_upgrades_text(node_type_id: String) -> String:
	var ids: Array = run.active_node_upgrades(node_type_id)
	if ids.is_empty():
		return ""
	var names: Array = []
	for id in ids:
		var up = NodeUpgrades.get_upgrade(id)
		names.append(up.name if up else id)
	return "\n\nActive upgrades: %s" % ", ".join(names)

func _roll_node_upgrade_discovery():
	## ~50% chance to unlock a still-locked node upgrade into the world (future
	## runs only). Returns the discovered NodeUpgrades.Upgrade, or null.
	var locked: Array = NodeUpgrades.locked_in(world)
	if locked.is_empty() or randf() > 0.5:
		return null
	var up = locked[randi() % locked.size()]
	run.unlock_node_upgrade(up.node_type_id, up.id)
	return up

func _apply_encounter_effect(node: RoguelikeMapNode) -> void:
	match node.type:
		RoguelikeMapNode.Type.CAMPFIRE:
			run.heal(_campfire_heal_amount())
			if run.has_node_upgrade("campfire", "war_supplies"):
				run.max_hp += 8
				run.heal(8)
		RoguelikeMapNode.Type.RANDOM:
			var bonus := 2 if run.has_node_upgrade("random", "lucky_find") else 1
			run.add_gold(randi_range(5, 20) * bonus)

# ----------------------------------------------------------------------------
# End-of-run overlay
# ----------------------------------------------------------------------------

func _show_end_overlay() -> void:
	var title := "Run Complete!" if run.victorious else "Defeated"
	var body := ""
	if run.victorious:
		body = "You toppled the boss and conquered the run.\n\nFloors cleared: %d\nGold: %d" % [run.floor_reached, run.gold]
	else:
		body = "Your run ends here.\n\nFloors cleared: %d\nGold: %d" % [run.floor_reached, run.gold]
	var on_return := func() -> void:
		_return_to_menu()
	_modal = _make_modal(title, body, "Return to Menu", on_return)

func _on_quit_pressed() -> void:
	if _modal:
		return
	var on_keep := func() -> void:
		_close_modal()
	# Exit but keep the run — it's already saved and will resume next time. A
	# character can only have one run going, so this is how you step away.
	var on_exit := func() -> void:
		_return_to_menu()
	# Abandon ends the run for good; the slot is freed so a fresh run (with any
	# newly unlocked meta-progression) can be started later.
	var on_abandon := func() -> void:
		run.finished = true
		run.victorious = false
		_persist_run()
		_return_to_menu()
	var body := "Exit keeps this run so you can resume it later — you can only have one run at a time.\n\nAbandon ends it for good."
	_modal = _make_modal("Leave Run?", body, "Keep Playing", on_keep, "Abandon Run", on_abandon, "Exit (resume later)", on_exit)

func _return_to_menu() -> void:
	var title_scene = load(TitleScenePath).instantiate()
	get_tree().root.add_child(title_scene)
	queue_free()

# ----------------------------------------------------------------------------
# Modal helper
# ----------------------------------------------------------------------------

func _make_modal(title: String, body: String, primary_label: String, primary_cb: Callable,
		secondary_label: String = "", secondary_cb: Callable = Callable(),
		tertiary_label: String = "", tertiary_cb: Callable = Callable()) -> Control:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(440, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.11, 0.17, 1.0)
	style.border_color = Color(0.45, 0.45, 0.65)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var body_lbl := Label.new()
	body_lbl.text = body
	body_lbl.add_theme_font_size_override("font_size", 15)
	body_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.custom_minimum_size = Vector2(380, 0)
	vbox.add_child(body_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	if secondary_label != "":
		var sbtn := Button.new()
		sbtn.text = secondary_label
		sbtn.custom_minimum_size = Vector2(140, 40)
		sbtn.pressed.connect(secondary_cb)
		btn_row.add_child(sbtn)

	if tertiary_label != "":
		var tbtn := Button.new()
		tbtn.text = tertiary_label
		tbtn.custom_minimum_size = Vector2(140, 40)
		tbtn.pressed.connect(tertiary_cb)
		btn_row.add_child(tbtn)

	var pbtn := Button.new()
	pbtn.text = primary_label
	pbtn.custom_minimum_size = Vector2(140, 40)
	pbtn.pressed.connect(primary_cb)
	btn_row.add_child(pbtn)

	return overlay

func _close_modal() -> void:
	if _modal and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null
