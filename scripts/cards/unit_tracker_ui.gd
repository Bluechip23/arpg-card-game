class_name UnitTrackerUI
extends Control

## Left-side unit tracker — minimal portrait squares for each enemy type.
## Single enemy types show info directly beneath the square.
## Multiple enemy types show a clickable square with "xN" that expands
## horizontally into individual sub-portraits.

signal enemy_hovered(enemy: Enemy)    # Emitted when hovering a portrait
signal enemy_unhovered()              # Emitted when leaving a portrait
signal enemy_clicked(enemy: Enemy)    # Emitted when clicking a portrait (opens the inspect panel)

var enemy_spawner = null
var _content: VBoxContainer
var _toggle_btn: Button
var _group_entries: Dictionary = {}
# Tracker-side tempo bars: [{enemy, fg: ColorRect, width: float}] — refreshed
# each tick by update_tempo_bars() to mirror the overhead action bars.
var _tempo_bars: Array = []
# Maps Enemy instance_id -> portrait panel for reverse-lookup from battlefield hover
var _enemy_to_panel: Dictionary = {}
var _highlighted_enemy: Enemy = null  # Currently highlighted enemy (from either direction)
var collapsed: bool = false  # Start expanded

const SQUARE_SIZE: float = 48.0
const SUB_SQUARE_SIZE: float = 38.0
const MAX_STATUS_ICONS: int = 5

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Toggle button at top
	_toggle_btn = Button.new()
	_toggle_btn.text = "_ Enemies"
	_toggle_btn.custom_minimum_size = Vector2(90, 22)
	_toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.12, 0.12, 0.18, 0.9)
	btn_style.border_color = Color(0.3, 0.3, 0.45, 0.6)
	btn_style.border_width_bottom = 1
	btn_style.border_width_top = 1
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.corner_radius_top_left = 3
	btn_style.corner_radius_top_right = 3
	btn_style.corner_radius_bottom_left = 3
	btn_style.corner_radius_bottom_right = 3
	_toggle_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.18, 0.18, 0.25, 0.95)
	_toggle_btn.add_theme_stylebox_override("hover", btn_hover)
	_toggle_btn.add_theme_font_size_override("font_size", 11)
	_toggle_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_toggle_btn.pressed.connect(_on_toggle)
	add_child(_toggle_btn)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 6)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.visible = not collapsed
	# Sit BELOW the toggle button — never on top of it, so collapsing is
	# always one clean click.
	_content.position = Vector2(0, 28)
	add_child(_content)

func initialize(spawner) -> void:
	enemy_spawner = spawner

func refresh() -> void:
	if not enemy_spawner:
		return

	# Save expanded states before clearing
	var prev_expanded: Dictionary = {}
	for type_name in _group_entries:
		prev_expanded[type_name] = _group_entries[type_name].get("expanded", false)

	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_group_entries.clear()
	_enemy_to_panel.clear()
	_tempo_bars.clear()

	var living = enemy_spawner.get_living_enemies()
	if living.is_empty():
		visible = false
		return
	visible = true
	_content.visible = not collapsed
	_update_toggle_text(living.size())

	# Group enemies by type
	var groups: Dictionary = {}
	for enemy in living:
		var type_name = _get_type_name(enemy)
		if not groups.has(type_name):
			groups[type_name] = []
		groups[type_name].append(enemy)

	for type_name in groups:
		var enemies_arr = groups[type_name]
		var group_data = {"enemies": enemies_arr, "expanded": prev_expanded.get(type_name, false)}

		if enemies_arr.size() == 1:
			# Single enemy — show square with info underneath
			var entry = _create_single_entry(enemies_arr[0])
			_content.add_child(entry)
			group_data["container"] = entry
		else:
			# Multiple — clickable group square + expandable sub-portraits
			var group_box = VBoxContainer.new()
			group_box.add_theme_constant_override("separation", 2)
			group_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_content.add_child(group_box)

			# Top row: group square + expand area
			var top_row = HBoxContainer.new()
			top_row.add_theme_constant_override("separation", 4)
			top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			group_box.add_child(top_row)

			var header_square = _create_group_square(type_name, enemies_arr.size())
			header_square.gui_input.connect(_on_group_click.bind(type_name))
			top_row.add_child(header_square)

			# Count badge to the right of the square
			var badge = Label.new()
			badge.text = "x%d" % enemies_arr.size()
			badge.add_theme_font_size_override("font_size", 11)
			badge.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
			badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			top_row.add_child(badge)

			# Expanded sub-portraits container (horizontal)
			var sub_container = HBoxContainer.new()
			sub_container.add_theme_constant_override("separation", 4)
			sub_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sub_container.visible = group_data["expanded"]
			top_row.add_child(sub_container)

			for enemy in enemies_arr:
				var sub = _create_sub_portrait(enemy)
				sub_container.add_child(sub)

			group_data["container"] = group_box
			group_data["sub_container"] = sub_container

		_group_entries[type_name] = group_data

func _on_group_click(event: InputEvent, type_name: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _group_entries.has(type_name):
			var data = _group_entries[type_name]
			data["expanded"] = not data["expanded"]
			if data.has("sub_container"):
				data["sub_container"].visible = data["expanded"]

func _on_toggle() -> void:
	collapsed = not collapsed
	_content.visible = not collapsed
	var count = 0
	if enemy_spawner:
		count = enemy_spawner.get_living_enemies().size()
	_update_toggle_text(count)

func _update_toggle_text(count: int = 0) -> void:
	if collapsed:
		_toggle_btn.text = "+ Enemies (%d)" % count
	else:
		_toggle_btn.text = "_ Enemies (%d)" % count

# ============================================
# SINGLE ENEMY ENTRY (square + info below)
# ============================================

func _create_single_entry(enemy: Enemy) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Portrait square
	var square = _create_portrait_square(enemy, SQUARE_SIZE)
	vbox.add_child(square)
	_enemy_to_panel[enemy.get_instance_id()] = square

	# Next-action tempo bar (yellow), mirroring the overhead bar
	vbox.add_child(_create_tempo_bar_row(enemy, SQUARE_SIZE))

	# Info underneath
	var info = _create_info_column(enemy, 11)
	vbox.add_child(info)

	return vbox

func _create_tempo_bar_row(enemy: Enemy, width: float) -> Control:
	## A thin dark strip with a yellow fill that tracks the enemy's progress
	## toward its next action (same value as the bar above its head).
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(width, 5)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.08, 0.9)
	bg.size = Vector2(width, 5)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bg)

	var fg := ColorRect.new()
	fg.color = Color(1.0, 0.85, 0.0, 0.95)
	fg.size = Vector2(0, 5)
	fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(fg)

	_tempo_bars.append({"enemy": enemy, "fg": fg, "width": width})
	return holder

func update_tempo_bars() -> void:
	## Called every tempo tick from main — cheap: resizes the yellow fills.
	for entry in _tempo_bars:
		var enemy = entry["enemy"]
		var fg: ColorRect = entry["fg"]
		if not is_instance_valid(enemy) or not is_instance_valid(fg) or not enemy.is_alive():
			continue
		var progress: float = enemy.get_action_progress()
		fg.size.x = 0.0 if progress < 0.0 else entry["width"] * progress

# ============================================
# GROUP SQUARE (for multiple of same type)
# ============================================

func _create_group_square(type_name: String, count: int) -> PanelContainer:
	## Clickable square with type abbreviation.
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(SQUARE_SIZE, SQUARE_SIZE)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var color = _get_type_color_by_name(type_name)
	var style = StyleBoxFlat.new()
	style.bg_color = color.darkened(0.55)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

	# Type abbreviation centered
	var type_lbl = Label.new()
	type_lbl.text = type_name.left(3).to_upper()
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	type_lbl.add_theme_font_size_override("font_size", 14)
	type_lbl.add_theme_color_override("font_color", color)
	type_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(type_lbl)

	return panel

# ============================================
# SUB-PORTRAIT (individual enemy in expanded group)
# ============================================

func _create_sub_portrait(enemy: Enemy) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var square = _create_portrait_square(enemy, SUB_SQUARE_SIZE)
	vbox.add_child(square)
	_enemy_to_panel[enemy.get_instance_id()] = square

	# Next-action tempo bar, same as single entries
	vbox.add_child(_create_tempo_bar_row(enemy, SUB_SQUARE_SIZE))

	var info = _create_info_column(enemy, 10)
	vbox.add_child(info)

	return vbox

# ============================================
# PORTRAIT SQUARE (per-enemy, with hover)
# ============================================

func _create_portrait_square(enemy: Enemy, sz: float) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(sz, sz)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var color = _get_type_color(enemy)
	var style = StyleBoxFlat.new()
	style.bg_color = color.darkened(0.55)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

	# Store reference for highlight lookups
	panel.set_meta("enemy_ref", enemy)
	panel.set_meta("base_border_color", color)

	var type_lbl = Label.new()
	type_lbl.text = _get_type_name(enemy).left(3).to_upper()
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	type_lbl.add_theme_font_size_override("font_size", int(sz * 0.3))
	type_lbl.add_theme_color_override("font_color", color)
	type_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(type_lbl)

	# Hover signals
	panel.mouse_entered.connect(_on_portrait_hover.bind(enemy))
	panel.mouse_exited.connect(_on_portrait_unhover)
	# Click opens the enemy inspect panel
	panel.gui_input.connect(_on_portrait_gui_input.bind(enemy))

	return panel

func _on_portrait_gui_input(event: InputEvent, enemy: Enemy) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		enemy_clicked.emit(enemy)

func _on_portrait_hover(enemy: Enemy) -> void:
	enemy_hovered.emit(enemy)

func _on_portrait_unhover() -> void:
	enemy_unhovered.emit()

# ============================================
# INFO COLUMN (HP, armor, tempo, status icons below a square)
# ============================================

func _create_info_column(enemy: Enemy, font_sz: int) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# HP
	var hp = Label.new()
	hp.text = "%d/%d" % [enemy.current_health, enemy.max_health]
	hp.add_theme_font_size_override("font_size", font_sz)
	hp.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hp)

	# Armor (only show if relevant)
	if enemy.current_armor > 0 or enemy.max_armor > 0:
		var arm = Label.new()
		arm.text = "ARM %d" % enemy.current_armor
		arm.add_theme_font_size_override("font_size", font_sz)
		arm.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
		arm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(arm)

	# Tempo / action
	var tempo = Label.new()
	var action_name = enemy.chosen_action.get("name", "idle").capitalize()
	var tempo_cost = enemy.chosen_action.get("tempo_cost", 0)
	if tempo_cost > 0:
		tempo.text = "%s %d/%d" % [action_name, enemy.action_tempo_counter, tempo_cost]
	else:
		tempo.text = "Idle"
	tempo.add_theme_font_size_override("font_size", font_sz - 1)
	tempo.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	tempo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(tempo)

	# Status icons
	var effects = enemy.get_active_effects()
	if effects.size() > 0:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(row)

		var show_count = min(effects.size(), MAX_STATUS_ICONS)
		for i in range(show_count):
			var eff = effects[i]
			var icon = _create_status_icon(eff["color"], eff["stacks"], eff["name"])
			row.add_child(icon)
		if effects.size() > MAX_STATUS_ICONS:
			var plus = Label.new()
			plus.text = "+"
			plus.add_theme_font_size_override("font_size", 10)
			plus.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(plus)

	return vbox

# ============================================
# HIGHLIGHT (called by main.gd for bidirectional hover)
# ============================================

func highlight_enemy(enemy: Enemy) -> void:
	## Highlight the portrait panel for this enemy.
	_clear_all_highlights()
	_highlighted_enemy = enemy
	if not enemy:
		return
	var eid = enemy.get_instance_id()
	if _enemy_to_panel.has(eid):
		var panel = _enemy_to_panel[eid] as PanelContainer
		if is_instance_valid(panel):
			var style = panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
			style.border_color = Color(1.0, 1.0, 1.0, 0.95)
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_width_top = 3
			style.border_width_bottom = 3
			panel.add_theme_stylebox_override("panel", style)

func clear_highlight() -> void:
	_clear_all_highlights()
	_highlighted_enemy = null

func _clear_all_highlights() -> void:
	for eid in _enemy_to_panel:
		var panel = _enemy_to_panel[eid] as PanelContainer
		if is_instance_valid(panel) and panel.has_meta("base_border_color"):
			var color = panel.get_meta("base_border_color") as Color
			var style = panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
			style.border_color = color
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			panel.add_theme_stylebox_override("panel", style)

# ============================================
# STATUS ICON
# ============================================

func _create_status_icon(color: Color, stacks: int, effect_name: String = "") -> PanelContainer:
	var sz = 14
	var circle = PanelContainer.new()
	circle.custom_minimum_size = Vector2(sz, sz)
	circle.mouse_filter = Control.MOUSE_FILTER_STOP
	if effect_name != "":
		var tip = effect_name
		if stacks > 0:
			tip += " (%d)" % stacks
		circle.tooltip_text = tip
	var circle_style = StyleBoxFlat.new()
	circle_style.bg_color = color
	circle_style.corner_radius_top_left = int(sz / 2)
	circle_style.corner_radius_top_right = int(sz / 2)
	circle_style.corner_radius_bottom_left = int(sz / 2)
	circle_style.corner_radius_bottom_right = int(sz / 2)
	circle.add_theme_stylebox_override("panel", circle_style)

	# Badge glyph over the colour disc when one exists for this effect.
	var glyph_tex := StatusIcons.get_icon(effect_name)
	if glyph_tex:
		circle_style.bg_color = color.darkened(0.55)
		var glyph = TextureRect.new()
		glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art stays crisp under the linear canvas default
		glyph.texture = glyph_tex
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		circle.add_child(glyph)

	if stacks > 0:
		var count = Label.new()
		count.text = str(stacks)
		count.add_theme_font_size_override("font_size", 9)
		count.add_theme_color_override("font_color", Color.WHITE)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		circle.add_child(count)

	return circle

# ============================================
# HELPERS
# ============================================

func _get_type_name(enemy: Enemy) -> String:
	match enemy.enemy_type:
		Enemy.EnemyType.WERERAT: return "Wererat"
		Enemy.EnemyType.SKELETON: return "Skeleton"
		Enemy.EnemyType.ARMORED_TROLL: return "Armored Troll"
		Enemy.EnemyType.MINION: return "Minion"
		Enemy.EnemyType.ELITE: return "Elite"
		Enemy.EnemyType.BOSS: return "Boss"
		Enemy.EnemyType.HYDRA: return "Hydra"
		Enemy.EnemyType.FIRE_GOBLIN_SOLDIER: return "Fire Goblin Soldier"
		Enemy.EnemyType.FIRE_GOBLIN_MAGE: return "Fire Goblin Mage"
		Enemy.EnemyType.FIRE_GOBLIN_SHAMAN: return "Fire Goblin Shaman"
	return "Unknown"

func _get_type_color(enemy: Enemy) -> Color:
	return _get_type_color_by_name(_get_type_name(enemy))

func _get_type_color_by_name(type_name: String) -> Color:
	match type_name:
		"Wererat": return Color(0.7, 0.5, 0.3)
		"Skeleton": return Color(0.85, 0.85, 0.8)
		"Armored Troll": return Color(0.4, 0.9, 0.3)
		"Minion": return Color(0.7, 0.7, 0.7)
		"Elite": return Color(1.0, 0.85, 0.0)
		"Boss": return Color(0.8, 0.0, 0.8)
	return Color.WHITE
