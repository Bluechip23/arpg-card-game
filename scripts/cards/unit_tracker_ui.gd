class_name UnitTrackerUI
extends Control

## Left-side unit tracker — minimal portrait squares for each enemy type.
## Single enemy types show info directly beneath the square.
## Multiple enemy types show a clickable square with "xN" that expands
## horizontally into individual sub-portraits.
##
## Beside the Enemies tab sits the Allies & Summons tab (designer,
## 2026-10-28): every ally on the field — the other hero, ally dummies and
## every summon — with its picture, health, armor and buffs / debuffs. The two
## tabs share the column, so opening one closes the other.

signal enemy_hovered(enemy: Enemy)    # Emitted when hovering a portrait
signal enemy_unhovered()              # Emitted when leaving a portrait
signal enemy_clicked(enemy: Enemy)    # Emitted when clicking a portrait (opens the inspect panel)
signal ally_clicked(unit)             # Emitted when clicking an ally / summon row (opens the same box)

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

# ---- Allies & Summons tab ----
## Main hands in who counts: Callable() -> Array of ally nodes (players,
## dummies, summons). Unset: the tab never shows.
var ally_source: Callable = Callable()
var allies_open: bool = false
var _ally_btn: Button = null
var _ally_content: VBoxContainer = null
var _ally_signature := ""
var _ally_poll := 0.0
const ALLY_POLL := 0.25  # seconds between checks for a change worth redrawing
const ALLY_SQUARE := 40.0

const SQUARE_SIZE: float = 48.0
const SUB_SQUARE_SIZE: float = 38.0
const MAX_STATUS_ICONS: int = 5

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The Allies list keeps itself current while the battle waits paused
	# between actions (that is when the player reads it).
	process_mode = Node.PROCESS_MODE_ALWAYS

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
	_style_tab(_toggle_btn)

	_ally_btn = Button.new()
	_ally_btn.name = "AlliesTab"
	_ally_btn.custom_minimum_size = Vector2(90, 22)
	_ally_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_ally_btn.pressed.connect(_on_ally_toggle)
	_ally_btn.visible = false
	add_child(_ally_btn)
	_style_tab(_ally_btn)

	_ally_content = VBoxContainer.new()
	_ally_content.name = "AlliesList"
	_ally_content.add_theme_constant_override("separation", 5)
	_ally_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ally_content.position = Vector2(0, 28)
	_ally_content.visible = false
	add_child(_ally_content)

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
	_toggle_btn.visible = not living.is_empty()
	_layout_tabs()
	if living.is_empty():
		_content.visible = false
		visible = _ally_btn.visible
		return
	visible = true
	_content.visible = not collapsed and not allies_open
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

			var header_square = _create_group_square(type_name, enemies_arr.size(), enemies_arr[0])
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
	if allies_open:
		# From the Allies tab: switch over to the enemies.
		_set_allies_open(false)
		collapsed = false
	else:
		collapsed = not collapsed
	_content.visible = not collapsed
	var count = 0
	if enemy_spawner:
		count = enemy_spawner.get_living_enemies().size()
	_update_toggle_text(count)

func _update_toggle_text(count: int = 0) -> void:
	if collapsed or allies_open:
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

	# Portrait square with the vertical action-tempo bar on its left
	var square = _create_portrait_square(enemy, SQUARE_SIZE)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_create_tempo_bar_column(enemy, SQUARE_SIZE))
	row.add_child(square)
	vbox.add_child(row)
	_enemy_to_panel[enemy.get_instance_id()] = square

	# Info underneath
	var info = _create_info_column(enemy, 11)
	vbox.add_child(info)

	return vbox

func _create_tempo_bar_column(enemy: Enemy, sz: float) -> Control:
	## A vertical strip beside the portrait square: dark background with a
	## yellow fill that rises as the enemy's next action approaches (same
	## value as the bar above its head).
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(7, sz)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.08, 0.9)
	bg.size = Vector2(7, sz)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bg)

	var fg := ColorRect.new()
	fg.color = Color(1.0, 0.85, 0.0, 0.95)
	fg.size = Vector2(7, 0)
	fg.position = Vector2(0, sz)
	fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(fg)

	_tempo_bars.append({"enemy": enemy, "fg": fg, "height": sz})
	return holder

func update_tempo_bars() -> void:
	## Called every tempo tick from main — cheap: resizes the yellow fills.
	for entry in _tempo_bars:
		var enemy = entry["enemy"]
		var fg: ColorRect = entry["fg"]
		if not is_instance_valid(enemy) or not is_instance_valid(fg) or not enemy.is_alive():
			continue
		var progress: float = clampf(enemy.get_action_progress(), 0.0, 1.0)
		var h: float = entry["height"] * progress
		fg.size.y = h
		fg.position.y = entry["height"] - h
		# Same colour language as the overhead bar: Sync yellow, Async blue,
		# channel orange.
		var shown: Dictionary = enemy.get_display_action()
		var kind: String = str(shown.get("kind", "sync"))
		fg.color = Color(Enemy.action_kind_color(kind), 0.95)

# ============================================
# GROUP SQUARE (for multiple of same type)
# ============================================

## The enemy's own picture, scaled to fill a square (nearest, so it stays
## crisp). Null when the enemy has no sprite (generic brute tiers).
func _portrait_rect(enemy: Enemy, sz: float) -> TextureRect:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("get_portrait_texture"):
		return null
	var tex: Texture2D = enemy.get_portrait_texture()
	if tex == null:
		return null
	var rect := TextureRect.new()
	rect.texture = tex
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.custom_minimum_size = Vector2(sz - 6, sz - 6)
	rect.modulate = enemy.get_portrait_tint()
	rect.flip_h = enemy.is_portrait_flipped()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _create_group_square(type_name: String, count: int, sample: Enemy = null) -> PanelContainer:
	## Clickable square showing the type's picture (abbreviation when none).
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

	var pic := _portrait_rect(sample, SQUARE_SIZE)
	if pic != null:
		panel.add_child(pic)
	else:
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
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_create_tempo_bar_column(enemy, SUB_SQUARE_SIZE))
	row.add_child(square)
	vbox.add_child(row)
	_enemy_to_panel[enemy.get_instance_id()] = square

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

	var pic := _portrait_rect(enemy, sz)
	if pic != null:
		panel.add_child(pic)
	else:
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
	var shown: Dictionary = enemy.get_display_action()
	var tempo_color := Color(0.7, 0.7, 0.9)
	if shown.is_empty():
		tempo.text = "Idle"
	elif str(shown["kind"]) == "channel":
		tempo.text = "Channeling %s %d/%d" % [shown["label"], shown["counter"], shown["cost"]]
		tempo_color = Enemy.ACTION_COLOR_CHANNEL
	else:
		tempo.text = "%s %d/%d" % [shown["label"], shown["counter"], shown["cost"]]
		if str(shown["kind"]) == "async":
			tempo_color = Enemy.ACTION_COLOR_ASYNC
	tempo.add_theme_font_size_override("font_size", font_sz - 1)
	tempo.add_theme_color_override("font_color", tempo_color)
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
			var icon = _create_status_icon(eff["color"], eff["stacks"], eff["name"], enemy)
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

func _create_status_icon(color: Color, stacks: int, effect_name: String = "", enemy = null) -> PanelContainer:
	var sz = 14
	var circle = PanelContainer.new()
	circle.custom_minimum_size = Vector2(sz, sz)
	circle.mouse_filter = Control.MOUSE_FILTER_STOP
	if effect_name != "" and enemy != null:
		# The same hover window as the player's own badges: what the effect
		# does and what is left of it (read live off the enemy).
		circle.mouse_entered.connect(func():
			if not is_instance_valid(enemy):
				return
			var info: Dictionary = enemy.get_effect_tooltip(effect_name)
			StatusHoverPopup.show_for(circle, effect_name, info.get("color", color), info.get("desc", ""),
				func() -> String:
					return str(enemy.get_effect_tooltip(effect_name).get("remaining", "")) if is_instance_valid(enemy) else "",
				"", StatusIcons.get_icon(effect_name)))
		circle.mouse_exited.connect(func(): StatusHoverPopup.hide_for(circle))
		circle.tree_exiting.connect(func(): StatusHoverPopup.hide_for(circle))
	elif effect_name != "":
		circle.tooltip_text = effect_name + (" (%d)" % stacks if stacks > 0 else "")
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

# ============================================
# ALLIES & SUMMONS TAB
# ============================================

## The tabs' look: emerald glass with a gold edge (the menus' Emerald Sanctum).
func _style_tab(btn: Button) -> void:
	var normal := EmeraldTheme.button_box(EmeraldTheme.PALETTE["btn_bg"], EmeraldTheme.GOLD_DIM, 1, 3)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 1
	normal.content_margin_bottom = 2
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = EmeraldTheme.PALETTE["btn_hover_bg"]
	hover.border_color = EmeraldTheme.GOLD
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_override("font", EmeraldTheme.font())
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", EmeraldTheme.TEXT)
	btn.add_theme_color_override("font_hover_color", EmeraldTheme.GOLD)

## The Allies tab sits right of the Enemies tab (at the left edge when there
## are no enemies).
func _layout_tabs() -> void:
	if _ally_btn == null:
		return
	var x := 0.0
	if _toggle_btn.visible:
		x = _toggle_btn.get_combined_minimum_size().x + 6.0
	_ally_btn.position = Vector2(x, 0)

func _allies() -> Array:
	if not ally_source.is_valid():
		return []
	var out: Array = []
	for u in ally_source.call():
		if u != null and is_instance_valid(u) and not u.get("is_dead") == true:
			out.append(u)
	return out

func _on_ally_toggle() -> void:
	_set_allies_open(not allies_open)

func _set_allies_open(open: bool) -> void:
	allies_open = open
	_ally_content.visible = open
	_content.visible = not open and not collapsed
	_redraw_allies()
	var count := 0
	if enemy_spawner:
		count = enemy_spawner.get_living_enemies().size()
	_update_toggle_text(count)

func _process(delta: float) -> void:
	if not ally_source.is_valid():
		return
	_ally_poll -= delta
	if _ally_poll > 0.0:
		return
	_ally_poll = ALLY_POLL
	var allies := _allies()
	var shown := not allies.is_empty()
	if shown != _ally_btn.visible:
		_ally_btn.visible = shown
		if not shown and allies_open:
			_set_allies_open(false)
		_layout_tabs()
		visible = _toggle_btn.visible or shown
	_ally_btn.text = ("_ " if allies_open else "+ ") + "Allies & Summons (%d)" % allies.size()
	if allies_open:
		var sig := _ally_sig(allies)
		if sig != _ally_signature:
			_redraw_allies(allies)

## A summary of everything the list shows: redraw only when it changes.
func _ally_sig(allies: Array) -> String:
	var parts := PackedStringArray()
	for u in allies:
		var d := ally_info(u)
		parts.append("%d:%d/%d:%s:%s" % [u.get_instance_id(), d["hp"], d["max_hp"], str(d["armor"]), str(d["effects"].map(func(e): return "%s%d" % [e["name"], e["stacks"]]))])
	return "|".join(parts)

## What the tab shows for one ally: name, health, armor ([now, cap]) and
## effects ([{name, color, stacks, desc}]). Heroes read their stats and their
## buff / debuff managers; summons answer for themselves (Summon).
static func ally_info(u) -> Dictionary:
	var d := {"name": "Ally", "hp": 0, "max_hp": 0, "armor": [0, 0], "effects": [], "portrait": null, "flip": false}
	if u.has_method("get_stats") and u.get_stats() != null:
		var st = u.get_stats()
		var cd = st.character_data if "character_data" in st else null
		d["name"] = cd.character_name if cd else str(u.name)
		d["hp"] = int(st.current_health)
		d["max_hp"] = int(st.max_health)
		d["armor"] = [int(st.current_armor), 0]
		d["portrait"] = cd.get_portrait() if cd and cd.has_method("get_portrait") else null
		var effects: Array = []
		var bm = u.get("buff_manager")
		if bm:
			for b in bm.buffs:
				effects.append({"name": b.buff_name, "color": b.get_icon_color(), "stacks": b.stacks if b.stacks > 1 else maxi(0, b.duration),
					"desc": b.description})
		var dm = u.get("debuff_manager")
		if dm:
			for x in dm.debuffs:
				effects.append({"name": x.debuff_name, "color": x.get_icon_color(), "stacks": x.stacks if x.stacks > 1 else maxi(0, x.duration),
					"desc": x.description})
		d["effects"] = effects
		return d
	d["name"] = str(u.get("display_name")) if u.get("display_name") != null else str(u.name)
	d["hp"] = int(u.get("health")) if u.get("health") != null else 0
	d["max_hp"] = int(u.get("max_health")) if u.get("max_health") != null else 0
	if u.has_method("get_armor_display"):
		d["armor"] = u.get_armor_display()
	if u.has_method("get_status_effects"):
		d["effects"] = u.get_status_effects()
	if u.has_method("get_portrait_texture"):
		d["portrait"] = u.get_portrait_texture()
		d["flip"] = u.has_method("is_portrait_flipped") and u.is_portrait_flipped()
	return d

func _redraw_allies(allies: Array = []) -> void:
	if allies.is_empty():
		allies = _allies()
	_ally_signature = _ally_sig(allies)
	for c in _ally_content.get_children():
		_ally_content.remove_child(c)
		c.queue_free()
	for u in allies:
		_ally_content.add_child(_create_ally_row(u))

func _create_ally_row(u) -> HBoxContainer:
	var d := ally_info(u)
	var row := HBoxContainer.new()
	row.name = "Ally_%d" % u.get_instance_id()
	row.add_theme_constant_override("separation", 6)
	# Clicking the row opens the ally's box, as an enemy's square does.
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT \
				and is_instance_valid(u):
			ally_clicked.emit(u))

	var sq := PanelContainer.new()
	sq.custom_minimum_size = Vector2(ALLY_SQUARE, ALLY_SQUARE)
	sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sq.add_theme_stylebox_override("panel", EmeraldTheme.panel_box(EmeraldTheme.CARD_BG, EmeraldTheme.GOLD_DIM, 2, 4))
	var tex: Texture2D = d["portrait"]
	if tex:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.custom_minimum_size = Vector2(ALLY_SQUARE - 6, ALLY_SQUARE - 6)
		pic.flip_h = bool(d["flip"])
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sq.add_child(pic)
	else:
		var ab := Label.new()
		ab.text = str(d["name"]).left(3).to_upper()
		ab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ab.add_theme_color_override("font_color", EmeraldTheme.GOLD)
		ab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sq.add_child(ab)
	row.add_child(sq)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var nm := Label.new()
	nm.name = "Name"
	nm.text = str(d["name"])
	nm.add_theme_font_override("font", EmeraldTheme.font())
	nm.add_theme_font_size_override("font_size", 12)
	nm.add_theme_color_override("font_color", EmeraldTheme.GOLD)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(nm)
	var stats_line := Label.new()
	stats_line.name = "Stats"
	var arm: Array = d["armor"]
	var t := "%d/%d HP" % [d["hp"], d["max_hp"]]
	if int(arm[1]) > 0:
		t += "   ARM %d/%d" % [arm[0], arm[1]]
	elif int(arm[0]) > 0:
		t += "   ARM %d" % arm[0]
	stats_line.text = t
	stats_line.add_theme_font_size_override("font_size", 11)
	stats_line.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	stats_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(stats_line)
	var effects: Array = d["effects"]
	if not effects.is_empty():
		var icons := HBoxContainer.new()
		icons.name = "Effects"
		icons.add_theme_constant_override("separation", 2)
		icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(icons)
		for i in range(mini(effects.size(), MAX_STATUS_ICONS)):
			icons.add_child(_create_ally_status_icon(effects[i]))
		if effects.size() > MAX_STATUS_ICONS:
			var plus := Label.new()
			plus.text = "+%d" % (effects.size() - MAX_STATUS_ICONS)
			plus.add_theme_font_size_override("font_size", 10)
			plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icons.add_child(plus)
	return row

## A badge like the enemies' (the colour disc, its glyph, the count), with
## the same hover window telling what it does.
func _create_ally_status_icon(eff: Dictionary) -> PanelContainer:
	var icon := _create_status_icon(eff.get("color", Color.WHITE), int(eff.get("stacks", 0)))
	icon.name = "Effect_" + str(eff.get("name", "")).replace(" ", "_")
	icon.mouse_filter = Control.MOUSE_FILTER_STOP
	var glyph_tex := StatusIcons.get_icon(str(eff.get("name", "")))
	if glyph_tex:
		var st := icon.get_theme_stylebox("panel") as StyleBoxFlat
		st.bg_color = Color(eff.get("color", Color.WHITE)).darkened(0.55)
		var glyph := TextureRect.new()
		glyph.texture = glyph_tex
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.add_child(glyph)
		icon.move_child(glyph, 0)
	icon.mouse_entered.connect(func():
		StatusHoverPopup.show_for(icon, str(eff.get("name", "")), eff.get("color", Color.WHITE), str(eff.get("desc", "")),
			func() -> String: return "", "", StatusIcons.get_icon(str(eff.get("name", "")))))
	icon.mouse_exited.connect(func(): StatusHoverPopup.hide_for(icon))
	icon.tree_exiting.connect(func(): StatusHoverPopup.hide_for(icon))
	return icon
