class_name SkillTreeUI
extends CanvasLayer

## Combined Level Progress panel with two tabs: Skill Tree (default) and Sphere Grid.
## Toggle with L key. Both views share the same full-screen overlay.

signal closed
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


# Stat allocation state (spends the banked level-up pool on PlayerStats)
var _stat_alloc_panel: PanelContainer = null
var _stat_points_remaining: int = 0
var _stat_allocations: Dictionary = {}
var _stat_alloc_btn: Button = null  # "Stat Points: N" in the tab bar

# Style constants
const COLOR_BG := Color(0.05, 0.05, 0.08, 0.95)
const COLOR_BORDER := Color(0.3, 0.3, 0.5)
const COLOR_TITLE := Color(0.9, 0.85, 0.5)
const COLOR_TEXT := Color(0.85, 0.85, 0.9)
const COLOR_DIM := Color(0.45, 0.45, 0.55)
const COLOR_CHOSEN_TEXT := Color(0.4, 1.0, 0.5)
const COLOR_AUTO_TEXT := Color(1.0, 0.85, 0.4)
const COLOR_TAB_ACTIVE := Color(0.15, 0.15, 0.25)
const COLOR_TAB_INACTIVE := Color(0.08, 0.08, 0.12)
const COLOR_TAB_HOVER := Color(0.2, 0.2, 0.3)


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

	_tab_btn_skill_tree = _make_tab_button("Passives", true)
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
				title_label.text = "%s - PASSIVES" % character_name.to_upper()
			else:
				title_label.text = "PASSIVES"
		Tab.SPHERE_GRID:
			title_label.text = "SPHERE GRID"

# ============================================
# TABLE BUILDING
# ============================================

# ---- Lane view geometry ----
const NODE_SIZE: float = 56.0        # circle diameter
const CONNECTOR_W: float = 46.0      # line segment between stages
const LANE_NAME_W: float = 150.0
const COLOR_NODE_LOCKED := Color(0.10, 0.10, 0.13)
const COLOR_NODE_EMPTY := Color(0.13, 0.14, 0.20)
const COLOR_COUNT := Color(0.45, 0.85, 1.0)     # the "x / 15" readout
const COLOR_COUNT_DIM := Color(0.35, 0.35, 0.45)
const COLOR_MAXED := Color(1.0, 0.85, 0.3)      # gold ring on a maxed passive

func _rebuild_table() -> void:
	## LANE VIEW: one horizontal chain of circular nodes per archetype.
	## Each passive is LEVELED with banked passive points ("x / 15" under its
	## circle); a lane's later stages unlock at 5 / 15 / 25... points invested
	## in that lane. Effects are unchanged for now — level 1 turns a passive
	## on, deeper levels are the hook for the upcoming scaling pass.
	_refresh_stat_alloc_button()
	if not skill_tree:
		return
	if not is_instance_valid(table_container):
		return

	_update_title()

	# Clear existing content
	for child in table_container.get_children():
		child.queue_free()

	table_container.add_theme_constant_override("separation", 18)

	# Points header
	var pool: int = player_stats.unspent_passive_points if player_stats else 0
	var pts_label = Label.new()
	pts_label.text = "Passive Points: %d" % pool
	pts_label.add_theme_font_size_override("font_size", 18)
	pts_label.add_theme_color_override("font_color", COLOR_AUTO_TEXT if pool > 0 else COLOR_DIM)
	pts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	table_container.add_child(pts_label)

	var hint = Label.new()
	hint.text = "Click a circle to invest a point (max %d per passive). Later stages unlock at %d / %d / %d points in that archetype." % [
		SkillTreeData.PASSIVE_MAX_LEVEL, SkillTreeData.stage_unlock_cost(1),
		SkillTreeData.stage_unlock_cost(2), SkillTreeData.stage_unlock_cost(3)]
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", COLOR_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	table_container.add_child(hint)

	table_container.add_child(HSeparator.new())

	for lane in skill_tree.get_archetype_lanes():
		table_container.add_child(_build_lane_row(lane))

## Total points invested in a lane (drives its stage gates).
func _lane_points(lane: Dictionary) -> int:
	var total := 0
	if player_stats:
		for opt in lane["passives"]:
			total += player_stats.get_passive_level(opt.passive_id)
	return total

func _build_lane_row(lane: Dictionary) -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN

	var lane_pts := _lane_points(lane)
	var lane_color: Color = lane["color"]

	# Lane name plate (the archetype), with its invested total.
	var name_box = VBoxContainer.new()
	name_box.custom_minimum_size = Vector2(LANE_NAME_W, NODE_SIZE)
	name_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_lbl = Label.new()
	name_lbl.text = lane["name"]
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", lane_color)
	name_box.add_child(name_lbl)
	var pts_lbl = Label.new()
	pts_lbl.text = "%d pts invested" % lane_pts
	pts_lbl.add_theme_font_size_override("font_size", 11)
	pts_lbl.add_theme_color_override("font_color", COLOR_DIM)
	name_box.add_child(pts_lbl)
	row.add_child(name_box)

	var passives: Array = lane["passives"]
	for stage in range(passives.size()):
		var stage_unlocked: bool = lane_pts >= SkillTreeData.stage_unlock_cost(stage)
		if stage > 0:
			row.add_child(_build_connector(stage_unlocked, lane_color))
		row.add_child(_build_passive_node(lane, stage, lane_pts))
	return row

func _build_connector(active: bool, lane_color: Color) -> Control:
	var holder = Control.new()
	holder.custom_minimum_size = Vector2(CONNECTOR_W, NODE_SIZE + 20)
	var line = ColorRect.new()
	line.color = Color(lane_color.r, lane_color.g, lane_color.b, 0.85) if active else Color(0.25, 0.25, 0.3)
	line.position = Vector2(0, NODE_SIZE / 2.0 - 2.0)
	line.size = Vector2(CONNECTOR_W, 4)
	holder.add_child(line)
	return holder

func _build_passive_node(lane: Dictionary, stage: int, lane_pts: int) -> Control:
	var opt: SkillTreeData.SkillOption = lane["passives"][stage]
	var level: int = player_stats.get_passive_level(opt.passive_id) if player_stats else 0
	var maxed: bool = level >= SkillTreeData.PASSIVE_MAX_LEVEL
	var unlock_cost: int = SkillTreeData.stage_unlock_cost(stage)
	var stage_unlocked: bool = lane_pts >= unlock_cost
	var lane_color: Color = lane["color"]

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	btn.focus_mode = Control.FOCUS_NONE

	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(int(NODE_SIZE / 2.0))
	style.set_border_width_all(3)
	if not stage_unlocked:
		style.bg_color = COLOR_NODE_LOCKED
		style.border_color = Color(0.22, 0.22, 0.28)
	elif maxed:
		style.bg_color = Color(lane_color.r * 0.35, lane_color.g * 0.35, lane_color.b * 0.35)
		style.border_color = COLOR_MAXED
	elif level > 0:
		style.bg_color = Color(lane_color.r * 0.25, lane_color.g * 0.25, lane_color.b * 0.25)
		style.border_color = lane_color
	else:
		style.bg_color = COLOR_NODE_EMPTY
		style.border_color = Color(lane_color.r, lane_color.g, lane_color.b, 0.45)
	btn.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate() as StyleBoxFlat
	hover.bg_color = style.bg_color.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)

	# Short glyph inside the circle: the passive's initials.
	var initials := ""
	for word in opt.name.split(" ", false):
		initials += word.substr(0, 1)
		if initials.length() >= 2:
			break
	btn.text = initials if stage_unlocked else "🔒"
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", lane_color if stage_unlocked else COLOR_DIM)

	if stage_unlocked:
		btn.tooltip_text = "%s (Level %d / %d)\n%s%s" % [
			opt.name, level, SkillTreeData.PASSIVE_MAX_LEVEL, opt.description,
			"" if maxed else "\n\nClick to invest 1 passive point."]
	else:
		btn.tooltip_text = "%s — LOCKED\nRequires %d points invested in %s (you have %d).\n\n%s" % [
			opt.name, unlock_cost, lane["name"], lane_pts, opt.description]

	btn.pressed.connect(_on_passive_node_pressed.bind(opt.passive_id, lane, stage))
	box.add_child(btn)

	var count = Label.new()
	count.text = ("%d / %d" % [level, SkillTreeData.PASSIVE_MAX_LEVEL]) if stage_unlocked else ("needs %d" % unlock_cost)
	count.add_theme_font_size_override("font_size", 12)
	count.add_theme_color_override("font_color", (COLOR_MAXED if maxed else COLOR_COUNT) if stage_unlocked else COLOR_COUNT_DIM)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.custom_minimum_size = Vector2(NODE_SIZE, 0)
	box.add_child(count)
	return box

func _on_passive_node_pressed(passive_id: String, lane: Dictionary, stage: int) -> void:
	if player_stats == null:
		return
	# Stage gate re-checked at click time (the pool/levels may have changed).
	if _lane_points(lane) < SkillTreeData.stage_unlock_cost(stage):
		return
	if player_stats.allocate_passive_point(passive_id):
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

func _scroll_to_current_level() -> void:
	# Lane view: everything fits on screen — always show from the top.
	if not is_instance_valid(scroll_container):
		return
	scroll_container.call_deferred("set_v_scroll", 0)

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
