class_name SkillTreeUI
extends CanvasLayer

## Combined Level Progress panel with two tabs: Skill Tree (default) and Sphere Grid.
## Toggle with L key. Both views share the same full-screen overlay.

signal closed
signal option_chosen(level: int, option_index: int)
signal retrospective_chosen(level: int, option_index: int)
signal stats_allocated(allocations: Dictionary)  # stat name -> points spent from the banked pool

@onready var panel: PanelContainer = $Panel
@onready var close_button: Button = $CloseButton
@onready var title_label: Label = $TitleLabel
@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var table_container: VBoxContainer = $ScrollContainer/TableContainer

var skill_tree: SkillTreeData = null
var player_level: int = 1
var character_name: String = ""
var player_stats = null  # PlayerStats — source of the banked stat-point pool (set by main.gd)

# Tab state
enum Tab { SKILL_TREE, SPHERE_GRID }
var _current_tab: Tab = Tab.SKILL_TREE
var _sphere_grid_ui: SphereGridUI = null  # Reference set by main.gd
var sphere_inventory: SphereInventory = null  # Reference for retrospective tokens
var _tab_btn_skill_tree: Button = null
var _tab_btn_sphere_grid: Button = null
var _tab_bar: HBoxContainer = null

# UI state
var _hovered_row: int = -1
var _hovered_col: int = -1
var _row_panels: Dictionary = {}

# Stat allocation state (spends the banked level-up pool on PlayerStats)
var _stat_alloc_panel: PanelContainer = null
var _stat_points_remaining: int = 0
var _stat_allocations: Dictionary = {}
var _stat_alloc_btn: Button = null  # "Stat Points: N" in the tab bar

# Style constants
const COLOR_BG := Color(0.05, 0.05, 0.08, 0.95)
const COLOR_ROW_BG := Color(0.08, 0.08, 0.12, 0.9)
const COLOR_ROW_BG_ALT := Color(0.06, 0.07, 0.10, 0.9)
const COLOR_OPTION_AVAILABLE := Color(0.12, 0.14, 0.22, 1.0)
const COLOR_OPTION_CHOSEN := Color(0.1, 0.25, 0.15, 1.0)
const COLOR_OPTION_BLACKED_OUT := Color(0.04, 0.04, 0.06, 0.85)
const COLOR_OPTION_LOCKED := Color(0.07, 0.07, 0.10, 0.7)
const COLOR_OPTION_HOVER := Color(0.18, 0.20, 0.32, 1.0)
const COLOR_AUTO_GRANT_BG := Color(0.18, 0.15, 0.08, 1.0)
const COLOR_AUTO_GRANT_CLAIMED := Color(0.12, 0.20, 0.10, 1.0)
const COLOR_BORDER := Color(0.3, 0.3, 0.5)
const COLOR_BORDER_CHOSEN := Color(0.2, 0.8, 0.3)
const COLOR_BORDER_AVAILABLE := Color(0.7, 0.7, 0.3)
const COLOR_BORDER_BLACKED := Color(0.15, 0.15, 0.2)
const COLOR_BORDER_LOCKED := Color(0.2, 0.2, 0.25)
const COLOR_TITLE := Color(0.9, 0.85, 0.5)
const COLOR_TEXT := Color(0.85, 0.85, 0.9)
const COLOR_DIM := Color(0.45, 0.45, 0.55)
const COLOR_CHOSEN_TEXT := Color(0.4, 1.0, 0.5)
const COLOR_BLACKED_TEXT := Color(0.25, 0.25, 0.3)
const COLOR_TYPE_CARD := Color(0.3, 0.7, 1.0)
const COLOR_TYPE_PASSIVE := Color(0.4, 0.9, 0.4)
const COLOR_TYPE_STAT := Color(0.7, 0.7, 1.0)
const COLOR_AUTO_TEXT := Color(1.0, 0.85, 0.4)
const COLOR_LEVEL_LABEL := Color(0.6, 0.6, 0.75)
const COLOR_TAB_ACTIVE := Color(0.15, 0.15, 0.25)
const COLOR_TAB_INACTIVE := Color(0.08, 0.08, 0.12)
const COLOR_TAB_HOVER := Color(0.2, 0.2, 0.3)
const COLOR_RETRO_BG := Color(0.08, 0.18, 0.18, 1.0)
const COLOR_RETRO_BORDER := Color(0.2, 0.7, 0.65)
const COLOR_RETRO_TEXT := Color(0.3, 0.9, 0.85)

const ROW_HEIGHT: float = 90.0
const OPTION_WIDTH: float = 200.0
const AUTO_GRANT_WIDTH: float = 180.0
const COLUMN_GAP: float = 8.0
const ROW_GAP: float = 4.0
const HEADER_HEIGHT: float = 36.0

func _ready() -> void:
	layer = 115
	visible = false
	_apply_styles()
	_build_tab_bar()

	close_button.pressed.connect(_on_close_pressed)

## Connect the sphere grid UI so we can manage its visibility from our tabs.
func connect_sphere_grid(grid_ui: SphereGridUI) -> void:
	_sphere_grid_ui = grid_ui
	# Disconnect the sphere grid's own close button from hiding itself independently
	# We'll manage its visibility through our tab system
	# Hide it by default since we start on skill tree tab
	_sphere_grid_ui.visible = false

func set_skill_tree(tree: SkillTreeData) -> void:
	skill_tree = tree
	character_name = tree.character_name
	if _current_tab == Tab.SKILL_TREE:
		_rebuild_table()

func set_player_level(level: int) -> void:
	player_level = level
	if _current_tab == Tab.SKILL_TREE:
		_rebuild_table()

func show_panel() -> void:
	visible = true
	_switch_to_tab(_current_tab)

func hide_panel() -> void:
	_close_stat_alloc_panel()
	visible = false
	# Also hide sphere grid when we close
	if _sphere_grid_ui:
		_sphere_grid_ui.hide_panel()

func toggle_panel() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()

func _on_close_pressed() -> void:
	hide_panel()
	closed.emit()

# ============================================
# TAB SYSTEM
# ============================================

func _build_tab_bar() -> void:
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 4)
	# Position below title, above content
	_tab_bar.anchors_preset = Control.PRESET_TOP_WIDE
	_tab_bar.offset_left = 16.0
	_tab_bar.offset_top = 40.0
	_tab_bar.offset_right = -120.0  # Leave room for close button
	_tab_bar.offset_bottom = 72.0

	_tab_btn_skill_tree = _make_tab_button("Skill Tree", true)
	_tab_btn_skill_tree.pressed.connect(_on_tab_skill_tree)
	_tab_bar.add_child(_tab_btn_skill_tree)

	_tab_btn_sphere_grid = _make_tab_button("Sphere Grid", false)
	_tab_btn_sphere_grid.pressed.connect(_on_tab_sphere_grid)
	_tab_bar.add_child(_tab_btn_sphere_grid)

	# Banked level-up stat points (+3 per level) are spent from here.
	_stat_alloc_btn = Button.new()
	_stat_alloc_btn.text = "Stat Points: 0"
	_stat_alloc_btn.add_theme_font_size_override("font_size", 14)
	_stat_alloc_btn.add_theme_color_override("font_color", COLOR_AUTO_TEXT)
	_stat_alloc_btn.pressed.connect(_open_stat_allocation)
	_tab_bar.add_child(_stat_alloc_btn)

	add_child(_tab_bar)

func _make_tab_button(text: String, active: bool) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 28)
	btn.add_theme_font_size_override("font_size", 14)
	_apply_tab_style(btn, active)
	return btn

func _apply_tab_style(btn: Button, active: bool) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_TAB_ACTIVE if active else COLOR_TAB_INACTIVE
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 0 if active else 2
	style.border_color = COLOR_BORDER if active else Color(0.2, 0.2, 0.3)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate() as StyleBoxFlat
	hover_style.bg_color = COLOR_TAB_ACTIVE if active else COLOR_TAB_HOVER
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = COLOR_TAB_ACTIVE
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_color_override("font_color", COLOR_TITLE if active else COLOR_DIM)
	btn.add_theme_color_override("font_hover_color", COLOR_TITLE)

func _on_tab_skill_tree() -> void:
	_switch_to_tab(Tab.SKILL_TREE)

func _on_tab_sphere_grid() -> void:
	_switch_to_tab(Tab.SPHERE_GRID)

func _switch_to_tab(tab: Tab) -> void:
	_current_tab = tab

	# Update tab button styles
	_apply_tab_style(_tab_btn_skill_tree, tab == Tab.SKILL_TREE)
	_apply_tab_style(_tab_btn_sphere_grid, tab == Tab.SPHERE_GRID)

	if tab == Tab.SKILL_TREE:
		# Show skill tree content, hide sphere grid
		panel.visible = true
		scroll_container.visible = true
		_rebuild_table()
		_scroll_to_current_level()
		_update_title()
		if _sphere_grid_ui:
			_sphere_grid_ui.hide_panel()
	elif tab == Tab.SPHERE_GRID:
		# Hide skill tree content, show sphere grid
		panel.visible = false
		scroll_container.visible = false
		_close_stat_alloc_panel()
		_update_title()
		if _sphere_grid_ui:
			_sphere_grid_ui.show_panel()

# ============================================
# STYLING
# ============================================

func _apply_styles() -> void:
	# Panel background
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = COLOR_BORDER
	panel.add_theme_stylebox_override("panel", style)

	# Title
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", COLOR_TITLE)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_update_title()

	# Close button
	close_button.text = "Close [L]"
	close_button.add_theme_font_size_override("font_size", 14)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.15, 0.2)
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	btn_style.border_color = Color(0.35, 0.35, 0.5)
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4
	close_button.add_theme_stylebox_override("normal", btn_style)
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.25, 0.25, 0.35)
	close_button.add_theme_stylebox_override("hover", btn_hover)

	# ScrollContainer styling - shift down to make room for tab bar
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.offset_top = 76.0  # Below tab bar

func _update_title() -> void:
	match _current_tab:
		Tab.SKILL_TREE:
			if character_name != "":
				title_label.text = "%s - SKILL TREE" % character_name.to_upper()
			else:
				title_label.text = "SKILL TREE"
		Tab.SPHERE_GRID:
			title_label.text = "SPHERE GRID"

# ============================================
# TABLE BUILDING
# ============================================

func _rebuild_table() -> void:
	_refresh_stat_alloc_button()
	if not skill_tree:
		return
	if not is_instance_valid(table_container):
		return

	_update_title()

	# Clear existing rows
	for child in table_container.get_children():
		child.queue_free()
	_row_panels.clear()

	# Show retrospective info
	var pending_retro = skill_tree.get_pending_retro_level(player_level)
	var has_token = sphere_inventory and sphere_inventory.has_retrospective_token()
	if pending_retro > 0 or has_token:
		var retro_label = Label.new()
		if pending_retro > 0:
			retro_label.text = "Retrospective Level! You may choose a previously skipped option instead of a new one."
		elif has_token:
			var token_count = sphere_inventory.retrospective_tokens
			retro_label.text = "Retrospective Token%s: %d — reclaim a skipped option as a bonus pick!" % ["s" if token_count > 1 else "", token_count]
		retro_label.add_theme_font_size_override("font_size", 12)
		retro_label.add_theme_color_override("font_color", COLOR_RETRO_TEXT)
		retro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		table_container.add_child(retro_label)

	# Add column header
	_build_header_row()

	# Add separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	table_container.add_child(sep)

	# Build rows for ALL levels so the player can see future choices
	for row in skill_tree.rows:
		var is_locked = row.level > player_level
		_build_skill_row(row, is_locked)

func _build_header_row() -> void:
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size.y = HEADER_HEIGHT
	hbox.add_theme_constant_override("separation", int(COLUMN_GAP))

	# Level column
	var level_header = _make_header_label("LVL", 50.0)
	hbox.add_child(level_header)

	# 4 option columns
	for i in range(4):
		var header = _make_header_label("Option %d" % (i + 1), OPTION_WIDTH)
		hbox.add_child(header)

	# Divider
	var divider = VSeparator.new()
	divider.add_theme_constant_override("separation", 4)
	hbox.add_child(divider)

	# Auto-grant column
	var auto_header = _make_header_label("Auto Reward", AUTO_GRANT_WIDTH)
	auto_header.add_theme_color_override("font_color", COLOR_AUTO_TEXT)
	hbox.add_child(auto_header)

	table_container.add_child(hbox)

func _make_header_label(text: String, min_width: float) -> Label:
	var label = Label.new()
	label.text = text
	label.custom_minimum_size.x = min_width
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", COLOR_LEVEL_LABEL)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _build_skill_row(row: SkillTreeData.SkillRow, is_locked: bool) -> void:
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size.y = ROW_HEIGHT
	hbox.add_theme_constant_override("separation", int(COLUMN_GAP))

	var row_data: Dictionary = {"hbox": hbox, "option_panels": [], "auto_panel": null}

	# Level label column
	var level_panel = PanelContainer.new()
	level_panel.custom_minimum_size = Vector2(50, ROW_HEIGHT)
	var level_style = StyleBoxFlat.new()
	level_style.bg_color = COLOR_ROW_BG if row.level % 2 == 0 else COLOR_ROW_BG_ALT
	level_style.corner_radius_top_left = 4
	level_style.corner_radius_bottom_left = 4
	level_panel.add_theme_stylebox_override("panel", level_style)

	var level_vbox = VBoxContainer.new()
	level_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var level_label = Label.new()
	level_label.text = str(row.level)
	level_label.add_theme_font_size_override("font_size", 18)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if is_locked:
		level_label.add_theme_color_override("font_color", COLOR_DIM)
	elif row.level <= player_level:
		level_label.add_theme_color_override("font_color", COLOR_TEXT)
	level_vbox.add_child(level_label)
	if SkillTreeData.is_retrospective_level(row.level):
		var retro_indicator = Label.new()
		retro_indicator.text = "R"
		retro_indicator.add_theme_font_size_override("font_size", 10)
		retro_indicator.add_theme_color_override("font_color", COLOR_RETRO_TEXT)
		retro_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_vbox.add_child(retro_indicator)
	level_panel.add_child(level_vbox)
	hbox.add_child(level_panel)

	# If this row used a retro choice (chose from a previous level), show a spanning message
	if row.chosen_index == -2 and row.level in skill_tree.retro_level_choices:
		var retro_info = skill_tree.retro_level_choices[row.level]
		var source_row = skill_tree.get_row_for_level(retro_info["source_level"])
		var source_name = "unknown"
		if source_row and retro_info["option_index"] < source_row.options.size():
			source_name = source_row.options[retro_info["option_index"]].name
		var retro_panel = PanelContainer.new()
		retro_panel.custom_minimum_size = Vector2(OPTION_WIDTH * 4 + COLUMN_GAP * 3, ROW_HEIGHT)
		retro_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var retro_style = StyleBoxFlat.new()
		retro_style.bg_color = COLOR_RETRO_BG
		retro_style.border_color = COLOR_RETRO_BORDER
		retro_style.corner_radius_top_left = 6
		retro_style.corner_radius_top_right = 6
		retro_style.corner_radius_bottom_left = 6
		retro_style.corner_radius_bottom_right = 6
		retro_style.border_width_left = 2
		retro_style.border_width_right = 2
		retro_style.border_width_top = 2
		retro_style.border_width_bottom = 2
		retro_style.content_margin_left = 12.0
		retro_style.content_margin_top = 8.0
		retro_panel.add_theme_stylebox_override("panel", retro_style)
		var retro_vbox = VBoxContainer.new()
		retro_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		var retro_title = Label.new()
		retro_title.text = "RETROSPECTIVE — Chose from Level %d" % retro_info["source_level"]
		retro_title.add_theme_font_size_override("font_size", 13)
		retro_title.add_theme_color_override("font_color", COLOR_RETRO_TEXT)
		retro_vbox.add_child(retro_title)
		var retro_desc = Label.new()
		retro_desc.text = "Reclaimed: %s" % source_name
		retro_desc.add_theme_font_size_override("font_size", 11)
		retro_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		retro_vbox.add_child(retro_desc)
		retro_panel.add_child(retro_vbox)
		hbox.add_child(retro_panel)
	else:
		# Normal 4 chooseable option columns
		for i in range(4):
			if i < row.options.size():
				var option = row.options[i]
				var option_panel = _build_option_panel(row, i, option, is_locked)
				row_data["option_panels"].append(option_panel)
				hbox.add_child(option_panel)
			else:
				var empty = _build_empty_panel()
				hbox.add_child(empty)

	# Vertical divider
	var divider = VSeparator.new()
	divider.add_theme_constant_override("separation", 4)
	hbox.add_child(divider)

	# Auto-grant column (5th)
	var auto_panel = _build_auto_grant_panel(row, is_locked)
	row_data["auto_panel"] = auto_panel
	hbox.add_child(auto_panel)

	_row_panels[row.level] = row_data
	table_container.add_child(hbox)

func _build_option_panel(row: SkillTreeData.SkillRow, index: int, option: SkillTreeData.SkillOption, is_locked: bool) -> PanelContainer:
	var panel_node = PanelContainer.new()
	panel_node.custom_minimum_size = Vector2(OPTION_WIDTH, ROW_HEIGHT)
	panel_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var is_chosen = row.is_chosen() and row.chosen_index == index
	var is_retro_picked = skill_tree.is_retrospective_picked(row.level, index)
	var is_blacked_out = row.is_chosen() and row.chosen_index != index and not is_retro_picked
	var is_available = not row.is_chosen() and not is_locked and row.level <= player_level
	# Retro availability: either a sphere grid token (bonus pick anytime) or
	# the player is on a retro level and hasn't made their choice yet (free pick instead of current options)
	var has_sphere_retro_token = sphere_inventory and sphere_inventory.has_retrospective_token()
	var on_pending_retro_level = skill_tree.get_pending_retro_level(player_level) > 0
	var has_retro_token = has_sphere_retro_token or on_pending_retro_level
	var is_retro_available = is_blacked_out and has_retro_token and skill_tree.can_retrospective_pick(row.level, index)

	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0

	if is_chosen or is_retro_picked:
		style.bg_color = COLOR_OPTION_CHOSEN
		style.border_color = COLOR_BORDER_CHOSEN
	elif is_retro_available:
		style.bg_color = COLOR_RETRO_BG
		style.border_color = COLOR_RETRO_BORDER
	elif is_blacked_out:
		style.bg_color = COLOR_OPTION_BLACKED_OUT
		style.border_color = COLOR_BORDER_BLACKED
	elif is_available:
		style.bg_color = COLOR_OPTION_AVAILABLE
		style.border_color = COLOR_BORDER_AVAILABLE
	elif is_locked:
		style.bg_color = COLOR_OPTION_LOCKED
		style.border_color = COLOR_BORDER_LOCKED
	else:
		style.bg_color = COLOR_OPTION_LOCKED
		style.border_color = COLOR_BORDER_LOCKED

	panel_node.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 6)

	var type_label = Label.new()
	type_label.text = "[%s]" % option.get_type_label()
	type_label.add_theme_font_size_override("font_size", 11)
	var type_color = _get_type_color(option.option_type)
	if is_blacked_out and not is_retro_available:
		type_color = COLOR_BLACKED_TEXT
	elif is_locked:
		type_color = COLOR_DIM
	type_label.add_theme_color_override("font_color", type_color)
	top_hbox.add_child(type_label)

	var name_label = Label.new()
	name_label.text = option.name
	name_label.add_theme_font_size_override("font_size", 13)
	if is_chosen or is_retro_picked:
		name_label.add_theme_color_override("font_color", COLOR_CHOSEN_TEXT)
	elif is_retro_available:
		name_label.add_theme_color_override("font_color", COLOR_RETRO_TEXT)
	elif is_blacked_out:
		name_label.add_theme_color_override("font_color", COLOR_BLACKED_TEXT)
	elif is_locked:
		name_label.add_theme_color_override("font_color", COLOR_DIM)
	else:
		name_label.add_theme_color_override("font_color", COLOR_TEXT)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top_hbox.add_child(name_label)

	vbox.add_child(top_hbox)

	var desc_label = Label.new()
	desc_label.text = option.description
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_blacked_out and not is_retro_available:
		desc_label.add_theme_color_override("font_color", COLOR_BLACKED_TEXT)
	elif is_locked:
		desc_label.add_theme_color_override("font_color", COLOR_DIM)
	else:
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(desc_label)

	var status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 10)
	if is_chosen:
		status_label.text = "CHOSEN"
		status_label.add_theme_color_override("font_color", COLOR_CHOSEN_TEXT)
	elif is_retro_picked:
		status_label.text = "RECLAIMED"
		status_label.add_theme_color_override("font_color", COLOR_CHOSEN_TEXT)
	elif is_retro_available:
		status_label.text = "Click to reclaim (Retrospective)"
		status_label.add_theme_color_override("font_color", COLOR_RETRO_TEXT)
	elif is_blacked_out:
		status_label.text = "LOCKED"
		status_label.add_theme_color_override("font_color", COLOR_BLACKED_TEXT)
	elif is_available:
		status_label.text = "Click to choose"
		status_label.add_theme_color_override("font_color", COLOR_BORDER_AVAILABLE)
	elif is_locked:
		status_label.text = "Level %d required" % row.level
		status_label.add_theme_color_override("font_color", COLOR_DIM)
	vbox.add_child(status_label)

	panel_node.add_child(vbox)

	if is_available:
		panel_node.mouse_filter = Control.MOUSE_FILTER_STOP
		panel_node.gui_input.connect(_on_option_input.bind(row.level, index))
		panel_node.mouse_entered.connect(_on_option_hover.bind(panel_node, true))
		panel_node.mouse_exited.connect(_on_option_hover.bind(panel_node, false))
	elif is_retro_available:
		panel_node.mouse_filter = Control.MOUSE_FILTER_STOP
		panel_node.gui_input.connect(_on_retro_option_input.bind(row.level, index))
		panel_node.mouse_entered.connect(_on_retro_option_hover.bind(panel_node, true))
		panel_node.mouse_exited.connect(_on_retro_option_hover.bind(panel_node, false))
	else:
		panel_node.mouse_filter = Control.MOUSE_FILTER_PASS

	return panel_node

func _build_auto_grant_panel(row: SkillTreeData.SkillRow, is_locked: bool) -> PanelContainer:
	var panel_node = PanelContainer.new()
	panel_node.custom_minimum_size = Vector2(AUTO_GRANT_WIDTH, ROW_HEIGHT)

	var auto = row.auto_grant
	if not auto:
		return panel_node

	var is_claimed = row.level <= player_level

	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0

	if is_claimed:
		style.bg_color = COLOR_AUTO_GRANT_CLAIMED
		style.border_color = Color(0.3, 0.6, 0.3)
	elif is_locked:
		style.bg_color = COLOR_OPTION_LOCKED
		style.border_color = COLOR_BORDER_LOCKED
	else:
		style.bg_color = COLOR_AUTO_GRANT_BG
		style.border_color = Color(0.5, 0.4, 0.2)

	panel_node.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	var auto_tag = Label.new()
	auto_tag.text = "AUTO"
	auto_tag.add_theme_font_size_override("font_size", 10)
	auto_tag.add_theme_color_override("font_color", COLOR_AUTO_TEXT if not is_locked else COLOR_DIM)
	vbox.add_child(auto_tag)

	var name_label = Label.new()
	name_label.text = auto.name
	name_label.add_theme_font_size_override("font_size", 13)
	if is_locked:
		name_label.add_theme_color_override("font_color", COLOR_DIM)
	elif is_claimed:
		name_label.add_theme_color_override("font_color", COLOR_CHOSEN_TEXT)
	else:
		name_label.add_theme_color_override("font_color", COLOR_AUTO_TEXT)
	vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = auto.description
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_locked:
		desc_label.add_theme_color_override("font_color", COLOR_DIM)
	else:
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(desc_label)

	var status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 10)
	if is_claimed:
		status_label.text = "GRANTED"
		status_label.add_theme_color_override("font_color", COLOR_CHOSEN_TEXT)
	elif is_locked:
		status_label.text = "Level %d" % row.level
		status_label.add_theme_color_override("font_color", COLOR_DIM)
	vbox.add_child(status_label)

	panel_node.add_child(vbox)
	return panel_node

func _build_empty_panel() -> PanelContainer:
	var panel_node = PanelContainer.new()
	panel_node.custom_minimum_size = Vector2(OPTION_WIDTH, ROW_HEIGHT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.06, 0.5)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel_node.add_theme_stylebox_override("panel", style)
	return panel_node

# ============================================
# OPTION INTERACTION
# ============================================

func _on_option_input(event: InputEvent, level: int, option_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_choose_option(level, option_index)

func _on_option_hover(panel_node: PanelContainer, entered: bool) -> void:
	if not is_instance_valid(panel_node):
		return
	var style = panel_node.get_theme_stylebox("panel") as StyleBoxFlat
	if not style:
		return
	var new_style = style.duplicate() as StyleBoxFlat
	if entered:
		new_style.bg_color = COLOR_OPTION_HOVER
		new_style.border_color = Color(0.9, 0.85, 0.4)
	else:
		new_style.bg_color = COLOR_OPTION_AVAILABLE
		new_style.border_color = COLOR_BORDER_AVAILABLE
	panel_node.add_theme_stylebox_override("panel", new_style)

func _choose_option(level: int, option_index: int) -> void:
	if not skill_tree:
		return
	var row = skill_tree.get_row_for_level(level)
	if not row or row.is_chosen():
		return
	if option_index < 0 or option_index >= row.options.size():
		return
	_open_confirm_dialog(level, option_index, row.options[option_index])

func _confirm_option(level: int, option_index: int) -> void:
	_close_confirm_dialog()
	if skill_tree.choose_option(level, option_index):
		var row = skill_tree.get_row_for_level(level)
		print("[SKILL TREE] Chose option %d for level %d: %s" % [option_index + 1, level, row.options[option_index].name])
		option_chosen.emit(level, option_index)
		_rebuild_table()

func _on_retro_option_input(event: InputEvent, level: int, option_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_choose_retrospective(level, option_index)

func _on_retro_option_hover(panel_node: PanelContainer, entered: bool) -> void:
	if not is_instance_valid(panel_node):
		return
	var new_style = (panel_node.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	if entered:
		new_style.bg_color = Color(0.12, 0.25, 0.25, 1.0)
		new_style.border_color = Color(0.3, 0.9, 0.85)
	else:
		new_style.bg_color = COLOR_RETRO_BG
		new_style.border_color = COLOR_RETRO_BORDER
	panel_node.add_theme_stylebox_override("panel", new_style)

func _choose_retrospective(level: int, option_index: int) -> void:
	if not skill_tree:
		return
	if not skill_tree.can_retrospective_pick(level, option_index):
		return
	var row = skill_tree.get_row_for_level(level)
	if not row or option_index >= row.options.size():
		return
	_open_confirm_dialog(level, option_index, row.options[option_index], true)

func _confirm_retrospective(level: int, option_index: int) -> void:
	_close_confirm_dialog()
	if not skill_tree:
		return
	# Check if this is a retro level free pick (counts as the level-up choice)
	# or a sphere grid token bonus pick (extra on top of normal choice)
	var pending_retro = skill_tree.get_pending_retro_level(player_level)
	if pending_retro > 0:
		# Free retro pick — choosing a previous option instead of current level's options
		skill_tree.retro_level_choose_previous(pending_retro, level, option_index)
		var row = skill_tree.get_row_for_level(level)
		if row and option_index < row.options.size():
			print("[SKILL TREE] Retro level %d: chose option %d from level %d (%s) instead" % [pending_retro, option_index + 1, level, row.options[option_index].name])
	elif sphere_inventory and sphere_inventory.has_retrospective_token():
		# Sphere grid token — bonus pick on top of normal choice
		sphere_inventory.spend_retrospective_token()
		skill_tree.retrospective_pick(level, option_index)
		var row = skill_tree.get_row_for_level(level)
		if row and option_index < row.options.size():
			print("[SKILL TREE] Retro token: bonus pick option %d from level %d (%s)" % [option_index + 1, level, row.options[option_index].name])
	else:
		return

	retrospective_chosen.emit(level, option_index)
	_rebuild_table()

# ============================================
# STAT ALLOCATION POPUP (banked level-up points)
# ============================================

func _refresh_stat_alloc_button() -> void:
	if not _stat_alloc_btn:
		return
	var pool: int = player_stats.unspent_stat_points if player_stats else 0
	_stat_alloc_btn.text = "Stat Points: %d" % pool
	_stat_alloc_btn.disabled = pool <= 0

func _open_stat_allocation() -> void:
	_close_stat_alloc_panel()
	var pool: int = player_stats.unspent_stat_points if player_stats else 0
	if pool <= 0:
		return

	_stat_points_remaining = pool
	_stat_allocations = {
		"strength": 0, "dexterity": 0, "intelligence": 0,
		"wisdom": 0, "agility": 0, "determination": 0
	}

	_stat_alloc_panel = PanelContainer.new()
	_stat_alloc_panel.z_index = 10
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, 0.98)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.4, 0.2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	_stat_alloc_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var popup_title = Label.new()
	popup_title.text = "Allocate %d Stat Points" % _stat_points_remaining
	popup_title.add_theme_font_size_override("font_size", 16)
	popup_title.add_theme_color_override("font_color", COLOR_AUTO_TEXT)
	popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(popup_title)

	var remaining_label = Label.new()
	remaining_label.name = "RemainingLabel"
	remaining_label.text = "Remaining: %d" % _stat_points_remaining
	remaining_label.add_theme_font_size_override("font_size", 13)
	remaining_label.add_theme_color_override("font_color", COLOR_TEXT)
	remaining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(remaining_label)

	for stat_name in ["strength", "dexterity", "intelligence", "wisdom", "agility", "determination"]:
		var stat_row = _build_stat_alloc_row(stat_name)
		vbox.add_child(stat_row)

	var confirm_btn = Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.add_theme_font_size_override("font_size", 14)
	confirm_btn.pressed.connect(_on_stat_alloc_confirm)
	vbox.add_child(confirm_btn)

	_stat_alloc_panel.add_child(vbox)

	_stat_alloc_panel.anchors_preset = Control.PRESET_CENTER
	_stat_alloc_panel.custom_minimum_size = Vector2(300, 350)

	add_child(_stat_alloc_panel)

func _stat_base_value(stat_name: String) -> int:
	## The character's CURRENT value for a stat (before this popup's pending
	## allocation). Determination has no base_ prefix in PlayerStats.
	if not player_stats:
		return 0
	if stat_name == "determination":
		return player_stats.determination
	return player_stats.get("base_" + stat_name)

func _build_stat_alloc_row(stat_name: String) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var label = Label.new()
	label.text = stat_name.capitalize()
	label.custom_minimum_size.x = 110
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	hbox.add_child(label)

	var minus_btn = Button.new()
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = Vector2(30, 28)
	minus_btn.pressed.connect(_on_stat_alloc_change.bind(stat_name, -1))
	hbox.add_child(minus_btn)

	var value_label = Label.new()
	value_label.name = "Value_" + stat_name
	value_label.text = "%d" % _stat_base_value(stat_name)
	value_label.custom_minimum_size.x = 64
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", COLOR_TEXT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(value_label)

	var plus_btn = Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(30, 28)
	plus_btn.pressed.connect(_on_stat_alloc_change.bind(stat_name, 1))
	hbox.add_child(plus_btn)

	return hbox

func _on_stat_alloc_change(stat_name: String, delta: int) -> void:
	var current = _stat_allocations.get(stat_name, 0)
	var new_val = current + delta

	if new_val < 0:
		return
	if delta > 0 and _stat_points_remaining <= 0:
		return

	_stat_allocations[stat_name] = new_val
	_stat_points_remaining -= delta

	_refresh_stat_alloc_display()

func _refresh_stat_alloc_display() -> void:
	if not is_instance_valid(_stat_alloc_panel):
		return

	var remaining = _stat_alloc_panel.get_node_or_null("VBoxContainer/RemainingLabel")
	if not remaining:
		for child in _stat_alloc_panel.get_children():
			if child is VBoxContainer:
				for sub in child.get_children():
					if sub.name == "RemainingLabel":
						remaining = sub
						break
	if remaining:
		remaining.text = "Remaining: %d" % _stat_points_remaining

	for stat_name in _stat_allocations:
		var value_node_name = "Value_" + stat_name
		for child in _stat_alloc_panel.get_children():
			if child is VBoxContainer:
				for sub in child.get_children():
					if sub is HBoxContainer:
						var val_label = sub.get_node_or_null(value_node_name)
						if val_label:
							# Show the resulting stat value, with the pending
							# points called out (e.g. "5 (+2)").
							var base := _stat_base_value(stat_name)
							var alloc: int = _stat_allocations[stat_name]
							if alloc > 0:
								val_label.text = "%d (+%d)" % [base + alloc, alloc]
								val_label.add_theme_color_override("font_color", COLOR_CHOSEN_TEXT)
							else:
								val_label.text = "%d" % base
								val_label.add_theme_color_override("font_color", COLOR_TEXT)

func _on_stat_alloc_confirm() -> void:
	## Partial spends are fine — whatever isn't allocated stays banked.
	var spent := 0
	for stat_name in _stat_allocations:
		spent += _stat_allocations[stat_name]
	_close_stat_alloc_panel()
	if spent <= 0:
		return
	print("[SKILL TREE] Stat allocation confirmed: %s" % str(_stat_allocations))
	stats_allocated.emit(_stat_allocations.duplicate())
	_refresh_stat_alloc_button()

func _close_stat_alloc_panel() -> void:
	if is_instance_valid(_stat_alloc_panel):
		_stat_alloc_panel.queue_free()
	_stat_alloc_panel = null

# ============================================
# OPTION CONFIRM DIALOG
# ============================================

var _confirm_panel: PanelContainer = null
var _confirm_backdrop: ColorRect = null

func _open_confirm_dialog(level: int, option_index: int, option: SkillTreeData.SkillOption, is_retro: bool = false) -> void:
	_close_confirm_dialog()

	_confirm_panel = PanelContainer.new()
	_confirm_panel.z_index = 15
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.12, 0.98)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.9, 0.85, 0.4)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	_confirm_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var title = Label.new()
	title.text = "Confirm Selection"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var type_label = Label.new()
	type_label.text = "[%s]" % option.get_type_label()
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.add_theme_color_override("font_color", _get_type_color(option.option_type))
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_label)

	var name_label = Label.new()
	name_label.text = option.name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = option.description
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size.x = 300
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc_label)

	var spacer = Control.new()
	spacer.custom_minimum_size.y = 4
	vbox.add_child(spacer)

	var button_hbox = HBoxContainer.new()
	button_hbox.add_theme_constant_override("separation", 12)
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(100, 32)
	cancel_btn.pressed.connect(_close_confirm_dialog)
	button_hbox.add_child(cancel_btn)

	var confirm_btn = Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(100, 32)
	if is_retro:
		confirm_btn.pressed.connect(_confirm_retrospective.bind(level, option_index))
	else:
		confirm_btn.pressed.connect(_confirm_option.bind(level, option_index))
	button_hbox.add_child(confirm_btn)

	vbox.add_child(button_hbox)
	_confirm_panel.add_child(vbox)

	# Add a full-screen backdrop to block clicks on elements behind the modal
	_confirm_backdrop = ColorRect.new()
	_confirm_backdrop.name = "ConfirmBackdrop"
	_confirm_backdrop.color = Color(0, 0, 0, 0.5)
	_confirm_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_backdrop.z_index = 14
	add_child(_confirm_backdrop)

	_confirm_panel.z_index = 15
	_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_confirm_panel)
	_confirm_panel.set_anchors_preset(Control.PRESET_CENTER)
	await get_tree().process_frame
	var vp_size = get_viewport().get_visible_rect().size
	_confirm_panel.position = vp_size / 2 - _confirm_panel.size / 2

func _close_confirm_dialog() -> void:
	if is_instance_valid(_confirm_backdrop):
		_confirm_backdrop.queue_free()
	_confirm_backdrop = null
	if is_instance_valid(_confirm_panel):
		_confirm_panel.queue_free()
	_confirm_panel = null

# ============================================
# HELPERS
# ============================================

func _get_type_color(option_type: SkillTreeData.OptionType) -> Color:
	match option_type:
		SkillTreeData.OptionType.CARD: return COLOR_TYPE_CARD
		SkillTreeData.OptionType.PASSIVE: return COLOR_TYPE_PASSIVE
		SkillTreeData.OptionType.STAT_BONUS: return COLOR_TYPE_STAT
	return COLOR_TEXT

func _scroll_to_current_level() -> void:
	if not is_instance_valid(scroll_container):
		return
	var target_row = player_level - 1
	var scroll_y = max(0, (target_row - 3) * (ROW_HEIGHT + ROW_GAP))
	scroll_container.call_deferred("set_v_scroll", int(scroll_y))

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_L:
			hide_panel()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if is_instance_valid(_stat_alloc_panel):
				_close_stat_alloc_panel()
			else:
				hide_panel()
			get_viewport().set_input_as_handled()
