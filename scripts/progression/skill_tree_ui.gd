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
var _stat_alloc_backdrop: Control = null   # the training-ground painting behind it
var _stat_points_remaining: int = 0
var _stat_allocations: Dictionary = {}
var _stat_alloc_btn: Button = null  # "Stat Points: N" in the tab bar

# Painted passive board (heroes with one in PASSIVE_BOARDS)
var _board_view: Control = null   # the board's rect under the tab bar (clips the painting)

# Style constants
# Emerald Sanctum, the menus' look: emerald glass, gold frame, mint text.
const COLOR_BG := EmeraldTheme.PANEL_BG_SOLID
const COLOR_BORDER := EmeraldTheme.GOLD_DIM
const COLOR_TITLE := EmeraldTheme.GOLD
const COLOR_TEXT := EmeraldTheme.TEXT
const COLOR_DIM := EmeraldTheme.TEXT_DIM
const COLOR_CHOSEN_TEXT := Color(0.4, 1.0, 0.5)
const COLOR_AUTO_TEXT := Color(1.0, 0.85, 0.4)
const COLOR_TAB_ACTIVE := Color(0.05, 0.22, 0.17)
const COLOR_TAB_INACTIVE := Color(0.02, 0.09, 0.07)
const COLOR_TAB_HOVER := Color(0.04, 0.16, 0.12)


func _ready() -> void:
	layer = 115
	visible = false
	_apply_styles()
	_build_tab_bar()
	# Courgette and the emerald buttons/scrollbars for everything on the layer.
	for c in get_children():
		if c is Control:
			c.theme = EmeraldTheme.get_theme()

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
	style.border_color = COLOR_BORDER if active else Color(COLOR_BORDER, 0.5)
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
		if is_instance_valid(_board_view):
			_board_view.visible = false
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
	EmeraldTheme.style_button(close_button, 14)

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
const COLOR_NODE_LOCKED := Color(0.05, 0.08, 0.075)
const COLOR_NODE_EMPTY := Color(0.05, 0.14, 0.11)
const COLOR_COUNT := Color(0.45, 0.85, 1.0)     # the "x / 15" readout
const COLOR_COUNT_DIM := Color(0.35, 0.35, 0.45)
const COLOR_MAXED := Color(1.0, 0.85, 0.3)      # gold ring on a maxed passive

func _rebuild_table() -> void:
	## LANE VIEW: one horizontal chain of circular nodes per archetype.
	## Each passive is LEVELED with banked passive points ("x / 15" under its
	## circle). The lanes' stages line up in columns; a whole column unlocks
	## together once STAGE_GATE_POINTS are invested anywhere in the previous
	## column, so the gate is shown once per column (header) rather than on
	## every node.
	_refresh_stat_alloc_button()
	if not skill_tree:
		return
	if not is_instance_valid(table_container):
		return

	_update_title()

	# Clear existing content
	for child in table_container.get_children():
		child.queue_free()

	# A hero with a painted board gets the board instead of the lane table.
	var board := board_for(skill_tree)
	if not board.is_empty():
		scroll_container.visible = false
		_rebuild_board(board)
		return
	if is_instance_valid(_board_view):
		_board_view.visible = false
	scroll_container.visible = _current_tab == Tab.SKILL_TREE

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
	hint.text = "Click a circle to invest a point (max %d per passive). Hover a circle to see what it does now and what the next point adds. Each stage's whole column opens once %d points sit in the previous stage — from any archetypes." % [
		SkillTreeData.PASSIVE_MAX_LEVEL, SkillTreeData.STAGE_GATE_POINTS]
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", COLOR_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	table_container.add_child(hint)

	table_container.add_child(HSeparator.new())

	var lanes: Array = skill_tree.get_archetype_lanes()
	var stage_count := 0
	for lane in lanes:
		stage_count = maxi(stage_count, lane["passives"].size())
	if stage_count > 0:
		table_container.add_child(_build_stage_header(lanes, stage_count))
	for lane in lanes:
		table_container.add_child(_build_lane_row(lane, lanes))

# ============================================
# PAINTED PASSIVE BOARD (heroes with a board)
# ============================================
# The designer's per-hero passive paintings (2026-11-09): the painting fills
# the Passives tab, one archetype scene per corner, and each archetype's
# passives sit as an upside-down triangle beside its scene, on the side
# toward the painting's empty centre — the first passive top-left, the
# second top-right, the final unlock at the bottom point. The centre holds
# the points and the stage gates. A hero without a board keeps the lane
# table. Every position below is in the painting's own pixels.
#
# Per hero (SkillTreeData.character_name):
#   texture     the painting
#   size        its pixel size
#   info        the empty-centre rect for the points / stage gates / hint
#   spread      half the gap between a triangle's top two passives (x) and
#               half its height (y): top-left = anchor - spread,
#               top-right = anchor + (spread.x, -spread.y),
#               bottom = anchor + (0, spread.y)
#   node        passive circle diameter
#   archetypes  archetype name -> {anchor: triangle centre, label: "above" | "below"}
## Brad's board: the two left triangles (Berserker over The Ancient) share
## one column, and the two right ones (Warden over The Fallen) another, so
## each side lines up (designer, 2026-11-09).
const BOARD_LEFT_X := 790.0
const BOARD_RIGHT_X := 1065.0
## Cory's board: the same rule, his centre a little narrower.
const CORY_LEFT_X := 752.0
const CORY_RIGHT_X := 1022.0
const PASSIVE_BOARDS := {
	"Brad": {
		"texture": "res://assets/textures/ui/brad_passive_board.webp",
		"size": Vector2(1774, 887),
		"info": Rect2(735, 98, 295, 138),
		"spread": Vector2(80, 55),
		"node": 72.0,
		"archetypes": {
			# Top left: the berserker's axe and his victims; the triangle sits
			# below the victims' heads, at the centre's top-left.
			"Berserker": {"anchor": Vector2(BOARD_LEFT_X, 362), "label": "above"},
			# Top right: the gold knight's shield bash; below his victim.
			"Warden": {"anchor": Vector2(BOARD_RIGHT_X, 362), "label": "above"},
			# Bottom left: the vine-bound foe; right of him.
			"The Ancient": {"anchor": Vector2(BOARD_LEFT_X, 612), "label": "below"},
			# Bottom right: the dark knight's black smoke; left of his foes.
			"The Fallen": {"anchor": Vector2(BOARD_RIGHT_X, 612), "label": "below"},
		},
	},
	# Cory (designer's board, 2026-11-09): top left the purple withering strike
	# (Atrophist), top right the monk's blue palm (Monk), bottom left the
	# knife in the dark (Lurker), bottom right the antlered druid (Druid).
	"Cory": {
		"texture": "res://assets/textures/ui/cory_passive_board.webp",
		"size": Vector2(1774, 887),
		"info": Rect2(735, 98, 295, 138),
		"spread": Vector2(68, 55),
		"node": 64.0,
		"archetypes": {
			"Atrophist": {"anchor": Vector2(CORY_LEFT_X, 380), "label": "above"},
			"Monk": {"anchor": Vector2(CORY_RIGHT_X, 380), "label": "above"},
			"Lurker": {"anchor": Vector2(CORY_LEFT_X, 625), "label": "below"},
			"Druid": {"anchor": Vector2(CORY_RIGHT_X, 625), "label": "below"},
		},
	},
}
## How far "cover" may enlarge the painting past "contain" (the gilt frame
## crops a little; the corner scenes and the centre always show).
const BOARD_MAX_COVER := 1.06
## The board's rect on the screen: the panel under the tab bar.
const BOARD_MARGIN_SIDE := 16.0
const BOARD_MARGIN_TOP := 76.0
const BOARD_MARGIN_BOTTOM := 16.0

## The board definition for this tree's hero, or {} (lane table) — also {}
## when the board doesn't place every archetype the tree has.
static func board_for(tree: SkillTreeData) -> Dictionary:
	if tree == null or not PASSIVE_BOARDS.has(tree.character_name):
		return {}
	var board: Dictionary = PASSIVE_BOARDS[tree.character_name]
	var lanes: Array = tree.get_archetype_lanes()
	if lanes.is_empty():
		return {}
	for lane in lanes:
		if not board["archetypes"].has(lane["name"]) or lane["passives"].size() > 3:
			return {}
	return board

## Where the 0-based `stage`'s passive sits in a triangle, in painting pixels:
## stage 0 top-left, stage 1 top-right, stage 2 the bottom point.
static func board_slot(board: Dictionary, archetype: String, stage: int) -> Vector2:
	var anchor: Vector2 = board["archetypes"][archetype]["anchor"]
	var sp: Vector2 = board["spread"]
	match stage:
		0: return anchor + Vector2(-sp.x, -sp.y)
		1: return anchor + Vector2(sp.x, -sp.y)
	return anchor + Vector2(0, sp.y)

## The board's screen rect and the painting's scale / offset inside it.
func _board_geometry(board: Dictionary) -> Dictionary:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var rect := Rect2(BOARD_MARGIN_SIDE, BOARD_MARGIN_TOP,
		maxf(1.0, screen.x - BOARD_MARGIN_SIDE * 2.0),
		maxf(1.0, screen.y - BOARD_MARGIN_TOP - BOARD_MARGIN_BOTTOM))
	var bsize: Vector2 = board["size"]
	var contain: float = minf(rect.size.x / bsize.x, rect.size.y / bsize.y)
	var cover: float = maxf(rect.size.x / bsize.x, rect.size.y / bsize.y)
	var k: float = minf(cover, contain * BOARD_MAX_COVER)
	var off: Vector2 = (rect.size - bsize * k) * 0.5   # inside the rect
	return {"rect": rect, "k": k, "off": off}

func _ensure_board_view() -> void:
	if is_instance_valid(_board_view):
		return
	_board_view = Control.new()
	_board_view.name = "PassiveBoardView"
	_board_view.clip_contents = true
	_board_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_view.theme = EmeraldTheme.get_theme()
	add_child(_board_view)
	# Drawn where the lane table would be: over the panel, under nothing else
	# (the title, tab bar and close button sit above the board's rect).
	move_child(_board_view, scroll_container.get_index())
	get_viewport().size_changed.connect(_on_board_viewport_resized)

func _on_board_viewport_resized() -> void:
	if visible and _current_tab == Tab.SKILL_TREE and is_instance_valid(_board_view) and _board_view.visible:
		_rebuild_table()

## A label set on the painting: outlined so it reads over any part of it.
func _board_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", maxi(3, font_size / 4))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## A font size that follows the painting's scale (0.7 ≈ a 1280x720 window).
static func _board_font(base: float, k: float, lowest: int) -> int:
	return maxi(lowest, roundi(base * k / 0.7))

func _rebuild_board(board: Dictionary) -> void:
	_ensure_board_view()
	_board_view.visible = _current_tab == Tab.SKILL_TREE
	for child in _board_view.get_children():
		_board_view.remove_child(child)
		child.queue_free()
	var geo := _board_geometry(board)
	var rect: Rect2 = geo["rect"]
	var k: float = geo["k"]
	var off: Vector2 = geo["off"]
	_board_view.position = rect.position
	_board_view.size = rect.size

	var art := TextureRect.new()
	art.name = "PassiveBoard"
	art.texture = load(board["texture"])
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.position = off
	art.size = Vector2(board["size"]) * k
	_board_view.add_child(art)

	var lanes: Array = skill_tree.get_archetype_lanes()
	_build_board_info(board, lanes, k, off)
	for lane in lanes:
		_build_board_triangle(board, lane, lanes, k, off)

## The empty centre: points to spend, the stage gates, how it works.
func _build_board_info(board: Dictionary, lanes: Array, k: float, off: Vector2) -> void:
	var info_rect: Rect2 = board["info"]
	var info := PanelContainer.new()
	info.name = "BoardInfo"
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.01, 0.05, 0.045, 0.62)
	st.border_color = Color(COLOR_BORDER, 0.55)
	st.set_border_width_all(1)
	st.set_corner_radius_all(8)
	st.content_margin_left = 8.0
	st.content_margin_right = 8.0
	st.content_margin_top = 4.0
	st.content_margin_bottom = 4.0
	info.add_theme_stylebox_override("panel", st)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.position = off + info_rect.position * k
	info.size = info_rect.size * k
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	info.add_child(vb)

	var pool: int = player_stats.unspent_passive_points if player_stats else 0
	var pts := _board_label("Passive Points: %d" % pool, _board_font(18, k, 12), COLOR_AUTO_TEXT if pool > 0 else COLOR_DIM)
	pts.name = "PointsLabel"
	vb.add_child(pts)

	var stage_count := 0
	for lane in lanes:
		stage_count = maxi(stage_count, lane["passives"].size())
	# One line per later stage, named by where its passives sit in the triangles.
	var where := ["top left", "top right", "bottom"]
	var gates: Array[String] = []
	for stage in range(1, stage_count):
		if SkillTreeData.is_stage_unlocked(lanes, stage, player_stats):
			gates.append("Stage %d (%s): open ✓" % [stage + 1, where[stage]])
		else:
			gates.append("Stage %d (%s): %d/%d in Stage %d" % [stage + 1, where[stage],
				SkillTreeData.stage_points(lanes, stage - 1, player_stats),
				SkillTreeData.stage_unlock_cost(stage), stage])
	var gate_lbl := _board_label("\n".join(gates), _board_font(11, k, 9), COLOR_COUNT)
	gate_lbl.name = "StageGates"
	vb.add_child(gate_lbl)

	var hint := _board_label("Click a circle: +1 point (max %d). Hover it for details." % [
		SkillTreeData.PASSIVE_MAX_LEVEL], _board_font(10, k, 8), COLOR_DIM)
	hint.name = "Hint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(hint)
	_board_view.add_child(info)

## One archetype's upside-down triangle: its passives (the same circles as
## the lane table, at the board's scale) with their names, faint connectors
## along the unlock chain, and the archetype's name on the outer edge.
func _build_board_triangle(board: Dictionary, lane: Dictionary, lanes: Array, k: float, off: Vector2) -> void:
	var arch: String = lane["name"]
	var lane_color: Color = lane["color"]
	var spec: Dictionary = board["archetypes"][arch]
	var sp: Vector2 = board["spread"]
	var node_d: float = float(board["node"]) * k
	var name_w: float = sp.x * 2.0 * 0.7 * k   # names wrap within the triangle's width
	var count_font := _board_font(12, k, 10)
	var name_font := _board_font(11, k, 9)

	var tri := Control.new()
	tri.name = "Triangle_" + arch.replace(" ", "")
	tri.set_meta("archetype", arch)
	tri.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_view.add_child(tri)

	var passives: Array = lane["passives"]
	var centres: Array[Vector2] = []
	for stage in range(passives.size()):
		centres.append(off + board_slot(board, arch, stage) * k)

	# Connectors 1 -> 2 -> 3: a stage opens off the one before it. Lit in the
	# archetype's colour once the later stage is open, faint grey before.
	for stage in range(1, centres.size()):
		var a: Vector2 = centres[stage - 1]
		var b: Vector2 = centres[stage]
		var dir := (b - a).normalized()
		var line := Line2D.new()
		line.name = "Connector_%d" % stage
		var open := SkillTreeData.is_stage_unlocked(lanes, stage, player_stats)
		line.default_color = Color(lane_color.r, lane_color.g, lane_color.b, 0.55) if open else Color(0.75, 0.75, 0.8, 0.25)
		line.width = maxf(2.0, 4.0 * k)
		line.add_point(a + dir * node_d * 0.55)
		line.add_point(b - dir * node_d * 0.55)
		tri.add_child(line)

	var bottom_edge := 0.0
	for stage in range(passives.size()):
		var opt: SkillTreeData.SkillOption = passives[stage]
		var box := _build_passive_node(lane, stage, lanes, node_d, count_font)
		box.name = "Passive_%d" % stage
		box.add_theme_constant_override("separation", 0)
		var stage_open := SkillTreeData.is_stage_unlocked(lanes, stage, player_stats)
		var nm := _board_label(opt.name, name_font, lane_color.lightened(0.3) if stage_open else COLOR_DIM)
		nm.name = "NameLabel"
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.custom_minimum_size = Vector2(name_w, 0)
		box.add_child(nm)
		box.move_child(nm, 1)   # under the circle, above the "x / 15"
		var rank: Label = box.get_node("RankLabel")
		rank.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		rank.add_theme_constant_override("outline_size", 3)
		var w: float = maxf(name_w, node_d)
		tri.add_child(box)
		box.position = centres[stage] - Vector2(w * 0.5, node_d * 0.5)
		box.size = Vector2(w, 0)
		bottom_edge = maxf(bottom_edge, box.position.y + box.get_combined_minimum_size().y)

	# The archetype's name and invested points, on the triangle's outer edge
	# (toward its scene): above the top pair, or under the bottom point.
	var title := _board_label("%s  ·  %d pts" % [arch, _lane_points(lane)], _board_font(16, k, 12), lane_color.lightened(0.15))
	title.name = "ArchetypeLabel"
	var tsize: Vector2 = title.get_combined_minimum_size()
	var anchor: Vector2 = off + Vector2(spec["anchor"]) * k
	var tw: float = maxf(tsize.x, sp.x * 2.0 * k + node_d)
	var ty: float
	if spec.get("label", "above") == "below":
		ty = bottom_edge + 1.0
	else:
		ty = (centres[0].y if not centres.is_empty() else anchor.y) - node_d * 0.5 - tsize.y - 2.0
	title.position = Vector2(anchor.x - tw * 0.5, ty)
	title.size = Vector2(tw, tsize.y)
	tri.add_child(title)

## Total points invested in a lane (shown on its name plate).
func _lane_points(lane: Dictionary) -> int:
	var total := 0
	if player_stats:
		for opt in lane["passives"]:
			total += player_stats.get_passive_level(opt.passive_id)
	return total

func _build_stage_header(lanes: Array, stage_count: int) -> Control:
	## One label per stage column, centred over that column's circles: the
	## stage number and, past the first, its gate — "needs 5 in Stage 1
	## (3/5)" — which counts every archetype's points in that earlier stage.
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	# Column pitch is one node plus one connector; the first circle's centre
	# sits NODE_SIZE/2 past the name plate.
	var pitch := NODE_SIZE + CONNECTOR_W
	var lead = Control.new()
	lead.custom_minimum_size = Vector2(LANE_NAME_W + NODE_SIZE / 2.0 - pitch / 2.0, 0)
	row.add_child(lead)
	for stage in range(stage_count):
		var cell = VBoxContainer.new()
		cell.custom_minimum_size = Vector2(pitch, 0)
		cell.alignment = BoxContainer.ALIGNMENT_END
		var unlocked := SkillTreeData.is_stage_unlocked(lanes, stage, player_stats)
		var title = Label.new()
		title.text = "Stage %d" % (stage + 1)
		title.add_theme_font_size_override("font_size", 13)
		title.add_theme_color_override("font_color", COLOR_TITLE if unlocked else COLOR_DIM)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(title)
		var gate = Label.new()
		if stage == 0:
			gate.text = "open"
		else:
			var have := SkillTreeData.stage_points(lanes, stage - 1, player_stats)
			var need := SkillTreeData.stage_unlock_cost(stage)
			gate.text = ("%d in Stage %d ✓" % [need, stage]) if unlocked else ("needs %d in Stage %d (%d/%d)" % [need, stage, have, need])
		gate.add_theme_font_size_override("font_size", 10)
		gate.add_theme_color_override("font_color", COLOR_COUNT if unlocked else COLOR_COUNT_DIM)
		gate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gate.custom_minimum_size = Vector2(pitch, 0)
		cell.add_child(gate)
		row.add_child(cell)
	return row

func _build_lane_row(lane: Dictionary, lanes: Array) -> Control:
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
		var stage_unlocked := SkillTreeData.is_stage_unlocked(lanes, stage, player_stats)
		if stage > 0:
			row.add_child(_build_connector(stage_unlocked, lane_color))
		row.add_child(_build_passive_node(lane, stage, lanes))
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

## The passive's rules text without the "Name (Archetype): " prefix the tree
## data prepends — the tooltip carries the name on its own line.
func _passive_body(opt: SkillTreeData.SkillOption) -> String:
	var body: String = opt.description
	var prefix := "%s (%s): " % [opt.name, opt.archetype]
	if body.begins_with(prefix):
		body = body.substr(prefix.length())
	return body

## Tooltip: what the passive does at its CURRENT rank, then what the next
## point changes — rendered from the scaling tables, so "10%→25%" becomes
## "12%" now and "13%" next instead of a range the player has to guess at.
func _passive_tooltip(opt: SkillTreeData.SkillOption, lane: Dictionary, stage: int, lanes: Array) -> String:
	var level: int = player_stats.get_passive_level(opt.passive_id) if player_stats else 0
	var max_lvl: int = SkillTreeData.PASSIVE_MAX_LEVEL
	var body := _passive_body(opt)
	var lines: Array[String] = []
	if not SkillTreeData.is_stage_unlocked(lanes, stage, player_stats):
		var have := SkillTreeData.stage_points(lanes, stage - 1, player_stats)
		var need := SkillTreeData.stage_unlock_cost(stage)
		lines.append("%s — %s (LOCKED)" % [opt.name, lane["name"]])
		lines.append("Opens with Stage %d once %d points sit in Stage %d, any archetype (%d/%d)." % [
			stage + 1, need, stage, have, need])
		lines.append("")
		lines.append("First point: %s" % PassiveScaling.describe_at_rank(opt.passive_id, body, 1))
		return "\n".join(lines)
	if level <= 0:
		lines.append("%s — %s (not learned)" % [opt.name, lane["name"]])
		lines.append("First point: %s" % PassiveScaling.describe_at_rank(opt.passive_id, body, 1))
		lines.append("")
		lines.append("Click to invest 1 passive point.")
		return "\n".join(lines)
	if level >= max_lvl:
		lines.append("%s — %s (Rank %d / %d, MAX)" % [opt.name, lane["name"], level, max_lvl])
		lines.append("Now: %s" % PassiveScaling.describe_at_rank(opt.passive_id, body, level))
		return "\n".join(lines)
	lines.append("%s — %s (Rank %d / %d)" % [opt.name, lane["name"], level, max_lvl])
	lines.append("Now: %s" % PassiveScaling.describe_at_rank(opt.passive_id, body, level))
	lines.append("Next point (Rank %d): %s" % [level + 1, PassiveScaling.describe_at_rank(opt.passive_id, body, level + 1)])
	lines.append("")
	lines.append("Click to invest 1 passive point.")
	return "\n".join(lines)

## One passive's circle and its "x / 15" readout. `node_size` and
## `count_font` let the painted board draw it at the board's scale; the lane
## table uses the defaults.
func _build_passive_node(lane: Dictionary, stage: int, lanes: Array, node_size: float = NODE_SIZE, count_font: int = 12) -> Control:
	var opt: SkillTreeData.SkillOption = lane["passives"][stage]
	var level: int = player_stats.get_passive_level(opt.passive_id) if player_stats else 0
	var maxed: bool = level >= SkillTreeData.PASSIVE_MAX_LEVEL
	var stage_unlocked := SkillTreeData.is_stage_unlocked(lanes, stage, player_stats)
	var lane_color: Color = lane["color"]

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN

	var btn = IconTooltipButton.new()  # its tooltip shows the passive's icon large
	btn.name = "PassiveButton"
	btn.custom_minimum_size = Vector2(node_size, node_size)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.focus_mode = Control.FOCUS_NONE

	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(int(node_size / 2.0))
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
	# A locked circle is a disabled button: keep it round (the theme's
	# disabled box is square).
	btn.add_theme_stylebox_override("disabled", style)

	# Pack icon inside the circle (initials only when no art resolves). A
	# locked stage shows the same icon dimmed and unclickable — no padlock.
	var art: Texture2D = SkillIconArt.passive(opt.passive_id, opt.archetype)
	btn.tooltip_icon = art
	btn.tooltip_accent = lane_color
	if art != null:
		btn.icon = art
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.add_theme_constant_override("icon_max_width", int(node_size * (NODE_SIZE - 14.0) / NODE_SIZE))
		btn.text = ""
		if not stage_unlocked:
			btn.self_modulate = Color(0.45, 0.45, 0.5, 0.75)
		elif level <= 0:
			btn.self_modulate = Color(0.72, 0.72, 0.78)
	else:
		var initials := ""
		for word in opt.name.split(" ", false):
			initials += word.substr(0, 1)
			if initials.length() >= 2:
				break
		btn.text = initials
		if not stage_unlocked:
			btn.self_modulate = Color(0.45, 0.45, 0.5, 0.75)
	btn.disabled = not stage_unlocked
	btn.mouse_default_cursor_shape = Control.CURSOR_ARROW if not stage_unlocked else Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", lane_color if stage_unlocked else COLOR_DIM)
	btn.tooltip_text = _passive_tooltip(opt, lane, stage, lanes)

	btn.pressed.connect(_on_passive_node_pressed.bind(opt.passive_id, stage))
	box.add_child(btn)

	var count = Label.new()
	count.name = "RankLabel"
	# The gate lives in the stage header; a locked circle just says so.
	count.text = ("%d / %d" % [level, SkillTreeData.PASSIVE_MAX_LEVEL]) if stage_unlocked else "locked"
	count.add_theme_font_size_override("font_size", count_font)
	count.add_theme_color_override("font_color", (COLOR_MAXED if maxed else COLOR_COUNT) if stage_unlocked else COLOR_COUNT_DIM)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.custom_minimum_size = Vector2(node_size, 0)
	box.add_child(count)
	box.set_meta("passive_id", opt.passive_id)
	box.set_meta("stage", stage)
	return box

func _on_passive_node_pressed(passive_id: String, stage: int) -> void:
	if player_stats == null or skill_tree == null:
		return
	# Stage gate re-checked at click time (the pool/levels may have changed).
	if not SkillTreeData.is_stage_unlocked(skill_tree.get_archetype_lanes(), stage, player_stats):
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
	_stat_alloc_panel.theme = EmeraldTheme.get_theme()
	_stat_alloc_panel.z_index = 10
	var style = StyleBoxFlat.new()
	style.bg_color = EmeraldTheme.PANEL_BG_SOLID
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

	_stat_alloc_panel.custom_minimum_size = Vector2(300, 350)

	# The designer's training-ground painting (2026-11-09) fills the screen
	# behind the level-up allocation; the box sits in its empty middle.
	_stat_alloc_backdrop = Control.new()
	_stat_alloc_backdrop.name = "StatAllocBackdrop"
	_stat_alloc_backdrop.top_level = true
	_stat_alloc_backdrop.z_index = 10
	_stat_alloc_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP   # the panel behind waits
	add_child(_stat_alloc_backdrop)
	var board := TextureRect.new()
	board.name = "AllocBoard"
	board.texture = load(STAT_ALLOC_BOARD)
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stat_alloc_backdrop.add_child(board)
	_stat_alloc_backdrop.add_child(_stat_alloc_panel)
	_fit_stat_alloc()
	_fit_stat_alloc.call_deferred()
	if not get_viewport().size_changed.is_connected(_fit_stat_alloc):
		get_viewport().size_changed.connect(_fit_stat_alloc)

const STAT_ALLOC_BOARD := "res://assets/textures/ui/stat_allocation_board.webp"
## The painting's size and its empty middle, in its own pixels: the box goes
## between the archers and the sword ring.
const STAT_ALLOC_BOARD_SIZE := Vector2(1774, 887)
const STAT_ALLOC_BOARD_SPACE := Rect2(500, 175, 730, 570)
const STAT_ALLOC_SCALE := 1.4   # the box drawn larger on the painting, as far as the space allows

## Cover the screen with the painting and set the allocation box in its
## empty middle (centred; scaled to the space).
func _fit_stat_alloc() -> void:
	if not is_instance_valid(_stat_alloc_backdrop) or not is_instance_valid(_stat_alloc_panel):
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	_stat_alloc_backdrop.position = Vector2.ZERO
	_stat_alloc_backdrop.size = screen
	var k: float = maxf(screen.x / STAT_ALLOC_BOARD_SIZE.x, screen.y / STAT_ALLOC_BOARD_SIZE.y)
	var off: Vector2 = (screen - STAT_ALLOC_BOARD_SIZE * k) * 0.5
	var space := Rect2(off + STAT_ALLOC_BOARD_SPACE.position * k, STAT_ALLOC_BOARD_SPACE.size * k)
	var need: Vector2 = _stat_alloc_panel.get_combined_minimum_size()
	_stat_alloc_panel.size = need
	var f: float = minf(STAT_ALLOC_SCALE, minf(space.size.x / need.x, space.size.y / need.y))
	_stat_alloc_panel.scale = Vector2(f, f)
	_stat_alloc_panel.position = space.position + (space.size - need * f) * 0.5

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
	if is_instance_valid(_stat_alloc_backdrop):
		_stat_alloc_backdrop.queue_free()
	_stat_alloc_backdrop = null

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
