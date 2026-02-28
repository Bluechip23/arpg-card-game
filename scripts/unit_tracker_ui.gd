class_name UnitTrackerUI
extends PanelContainer

## Left-side panel that tracks all enemy units on the battlefield.
## Groups enemies by type: single enemies show full info;
## multiples show a clickable portrait that expands to sub-portraits.

signal enemy_clicked(enemy: Enemy)

var enemy_spawner = null  # Set by main.gd
var _content: VBoxContainer
var _group_entries: Dictionary = {}  # type_name -> { "container": Control, "expanded": bool, "enemies": Array }
var _scroll: ScrollContainer

const PORTRAIT_HEIGHT: float = 80.0
const SUB_PORTRAIT_HEIGHT: float = 64.0
const MAX_STATUS_ICONS: int = 5

func _ready() -> void:
	# Panel styling
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.4)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	add_theme_stylebox_override("panel", style)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 4)
	_scroll.add_child(_content)

func initialize(spawner) -> void:
	enemy_spawner = spawner

func refresh() -> void:
	if not enemy_spawner:
		return

	# Clear existing entries
	for child in _content.get_children():
		child.queue_free()
	_group_entries.clear()

	var living = enemy_spawner.get_living_enemies()
	if living.is_empty():
		visible = false
		return
	visible = true

	# Group enemies by type name
	var groups: Dictionary = {}  # type_name -> Array[Enemy]
	for enemy in living:
		var type_name = _get_type_name(enemy)
		if not groups.has(type_name):
			groups[type_name] = []
		groups[type_name].append(enemy)

	# Create UI for each group
	for type_name in groups:
		var enemies_in_group = groups[type_name]
		var group_data = {"enemies": enemies_in_group, "expanded": false}

		if enemies_in_group.size() == 1:
			# Single enemy: show full portrait directly
			var portrait = _create_portrait(enemies_in_group[0], false)
			_content.add_child(portrait)
			group_data["container"] = portrait
		else:
			# Multiple: clickable group header + expandable sub-portraits
			var group_box = VBoxContainer.new()
			group_box.add_theme_constant_override("separation", 2)
			_content.add_child(group_box)

			var header = _create_group_header(type_name, enemies_in_group.size())
			header.gui_input.connect(_on_group_header_input.bind(type_name))
			group_box.add_child(header)

			# Sub-portrait container (hidden by default)
			var sub_container = HBoxContainer.new()
			sub_container.add_theme_constant_override("separation", 4)
			sub_container.visible = false
			group_box.add_child(sub_container)

			for enemy in enemies_in_group:
				var sub_portrait = _create_portrait(enemy, true)
				sub_container.add_child(sub_portrait)

			group_data["container"] = group_box
			group_data["sub_container"] = sub_container
			# Carry over previous expanded state
			if _group_entries.has(type_name) and _group_entries[type_name].get("expanded", false):
				group_data["expanded"] = true
				sub_container.visible = true

		_group_entries[type_name] = group_data

func _on_group_header_input(event: InputEvent, type_name: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _group_entries.has(type_name):
			var data = _group_entries[type_name]
			data["expanded"] = not data["expanded"]
			if data.has("sub_container"):
				data["sub_container"].visible = data["expanded"]

func _create_group_header(type_name: String, count: int) -> PanelContainer:
	## Creates a clickable header showing the enemy type and count.
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 40)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.22, 0.95)
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.4, 0.5)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	panel.add_child(hbox)

	# Type name square (placeholder portrait)
	var type_box = _create_type_square(type_name, Vector2(32, 32))
	hbox.add_child(type_box)

	var info = VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	hbox.add_child(info)

	var name_label = Label.new()
	name_label.text = "%s (x%d)" % [type_name, count]
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	info.add_child(name_label)

	var hint = Label.new()
	hint.text = "Click to expand"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	info.add_child(hint)

	return panel

func _create_portrait(enemy: Enemy, is_sub: bool) -> PanelContainer:
	## Creates a full portrait for a single enemy showing name, HP, armor, tempo, effects.
	var height = SUB_PORTRAIT_HEIGHT if is_sub else PORTRAIT_HEIGHT
	var width = 140 if is_sub else 180
	var font_sz = 11 if is_sub else 12

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, height)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.4)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	# Row 1: Type square + name
	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 4)
	vbox.add_child(top_row)

	var sq_size = 22 if is_sub else 28
	var type_square = _create_type_square(_get_type_name(enemy), Vector2(sq_size, sq_size))
	top_row.add_child(type_square)

	var name_lbl = Label.new()
	name_lbl.text = enemy.enemy_name
	name_lbl.add_theme_font_size_override("font_size", font_sz)
	name_lbl.add_theme_color_override("font_color", _get_type_color(enemy))
	top_row.add_child(name_lbl)

	# Row 2: HP and Armor bars
	var stats_row = HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 6)
	vbox.add_child(stats_row)

	var hp_label = Label.new()
	hp_label.text = "HP: %d/%d" % [enemy.current_health, enemy.max_health]
	hp_label.add_theme_font_size_override("font_size", font_sz)
	hp_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	stats_row.add_child(hp_label)

	if enemy.current_armor > 0 or enemy.max_armor > 0:
		var armor_label = Label.new()
		armor_label.text = "ARM: %d" % enemy.current_armor
		armor_label.add_theme_font_size_override("font_size", font_sz)
		armor_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
		stats_row.add_child(armor_label)

	# Row 3: Tempo bar
	var tempo_row = HBoxContainer.new()
	tempo_row.add_theme_constant_override("separation", 4)
	vbox.add_child(tempo_row)

	var tempo_label = Label.new()
	var action_name = enemy.chosen_action.get("name", "idle").capitalize()
	var tempo_cost = enemy.chosen_action.get("tempo_cost", 0)
	if tempo_cost > 0:
		tempo_label.text = "%s: %d/%d" % [action_name, enemy.action_tempo_counter, tempo_cost]
	else:
		tempo_label.text = "Idle"
	tempo_label.add_theme_font_size_override("font_size", font_sz - 1)
	tempo_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	tempo_row.add_child(tempo_label)

	# Row 4: Status effects (buffs on left, debuffs on right — for enemies, all are debuffs)
	var effects = enemy.get_active_effects()
	if effects.size() > 0:
		var effects_row = HBoxContainer.new()
		effects_row.add_theme_constant_override("separation", 2)
		vbox.add_child(effects_row)

		var show_count = min(effects.size(), MAX_STATUS_ICONS)
		for i in range(show_count):
			var eff = effects[i]
			var icon = _create_status_icon(eff["color"], eff["stacks"], is_sub)
			effects_row.add_child(icon)

		if effects.size() > MAX_STATUS_ICONS:
			var plus = Label.new()
			plus.text = "+"
			plus.add_theme_font_size_override("font_size", 10)
			plus.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			effects_row.add_child(plus)

	return panel

func _create_type_square(type_name: String, sz: Vector2) -> PanelContainer:
	## Creates a colored square with the enemy type name inside.
	var square = PanelContainer.new()
	square.custom_minimum_size = sz

	var color = _get_type_color_by_name(type_name)
	var style = StyleBoxFlat.new()
	style.bg_color = color.darkened(0.5)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = color
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	square.add_theme_stylebox_override("panel", style)

	var lbl = Label.new()
	lbl.text = type_name.left(3).to_upper()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", int(sz.y * 0.4))
	lbl.add_theme_color_override("font_color", color)
	square.add_child(lbl)

	return square

func _create_status_icon(color: Color, stacks: int, is_small: bool) -> Control:
	## Creates a small colored circle with a stack count at bottom-right.
	var sz = 14 if is_small else 18
	var container = Control.new()
	container.custom_minimum_size = Vector2(sz + 6, sz + 4)

	# Circle (colored rect with rounded corners as approximation)
	var circle = PanelContainer.new()
	circle.custom_minimum_size = Vector2(sz, sz)
	circle.position = Vector2(0, 0)
	var circle_style = StyleBoxFlat.new()
	circle_style.bg_color = color
	circle_style.corner_radius_top_left = int(sz / 2)
	circle_style.corner_radius_top_right = int(sz / 2)
	circle_style.corner_radius_bottom_left = int(sz / 2)
	circle_style.corner_radius_bottom_right = int(sz / 2)
	circle.add_theme_stylebox_override("panel", circle_style)
	container.add_child(circle)

	# Stack count number (bottom-right, half on/half off the circle)
	if stacks > 0:
		var count = Label.new()
		count.text = str(stacks)
		count.add_theme_font_size_override("font_size", 9 if is_small else 10)
		count.add_theme_color_override("font_color", Color.WHITE)
		count.position = Vector2(sz * 0.55, sz * 0.4)
		container.add_child(count)

	return container

func _get_type_name(enemy: Enemy) -> String:
	match enemy.enemy_type:
		Enemy.EnemyType.WERERAT: return "Wererat"
		Enemy.EnemyType.SKELETON: return "Skeleton"
		Enemy.EnemyType.ARMORED_TROLL: return "Armored Troll"
		Enemy.EnemyType.MINION: return "Minion"
		Enemy.EnemyType.ELITE: return "Elite"
		Enemy.EnemyType.BOSS: return "Boss"
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
