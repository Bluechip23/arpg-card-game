class_name CharacterCard
extends PanelContainer

## Displays a single character's info for selection

signal selected(character: CharacterData)

var character_data: CharacterData

# UI nodes built programmatically
var _name_label: Label
var _stat_labels: Dictionary = {}
var _sprite_texture: TextureRect
var _sprite_label: Label
var _passive_label: Label
var _slot_label: Label
var _inventory_name_label: Label
var _inventory_desc_label: Label
var _archetypes_header_label: Label
var _archetype_labels: Array[Label] = []
var _ability_containers: Array[VBoxContainer] = []
var _select_button: Button

func _ready() -> void:
	_apply_panel_style()
	_build_ui()

func _apply_panel_style() -> void:
	custom_minimum_size = Vector2(280, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.13, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.35, 0.35, 0.5)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", style)

func _build_ui() -> void:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# ── Name Header ──────────────────────────────
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_name_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_name_label)

	vbox.add_child(_make_separator())

	# ── Stats + Sprite Row ───────────────────────
	var content_row = HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 12)
	vbox.add_child(content_row)

	# Left: Stats VBox
	var stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 3)
	stats_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_row.add_child(stats_vbox)

	var core_header = _make_section_header("ATTRIBUTES")
	stats_vbox.add_child(core_header)

	var core_stats = [
		["STR", Color(1.0, 0.5, 0.4)],
		["DEX", Color(0.5, 1.0, 0.5)],
		["INT", Color(0.5, 0.7, 1.0)],
		["WIS", Color(0.8, 0.6, 1.0)],
		["DET", Color(1.0, 0.8, 0.3)],
		["AGI", Color(0.4, 1.0, 0.9)],
	]
	for entry in core_stats:
		var lbl = _make_stat_label(entry[1])
		stats_vbox.add_child(lbl)
		_stat_labels[entry[0]] = lbl

	var mini_sep = HSeparator.new()
	mini_sep.add_theme_color_override("color", Color(0.25, 0.25, 0.35))
	stats_vbox.add_child(mini_sep)

	var derived_header = _make_section_header("RESOURCES")
	stats_vbox.add_child(derived_header)

	var derived_stats = [
		["HP",   Color(1.0, 0.45, 0.45)],
		["Mana", Color(0.4, 0.7, 1.0)],
		["Hand", Color(0.9, 0.9, 0.9)],
		["Draw", Color(0.9, 0.9, 0.9)],
	]
	for entry in derived_stats:
		var lbl = _make_stat_label(entry[1])
		stats_vbox.add_child(lbl)
		_stat_labels[entry[0]] = lbl

	# Right: Sprite placeholder panel
	var sprite_panel = PanelContainer.new()
	sprite_panel.custom_minimum_size = Vector2(95, 120)
	sprite_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var sp_style = StyleBoxFlat.new()
	sp_style.bg_color = Color(0.06, 0.06, 0.1, 1.0)
	sp_style.border_width_left = 1
	sp_style.border_width_right = 1
	sp_style.border_width_top = 1
	sp_style.border_width_bottom = 1
	sp_style.border_color = Color(0.3, 0.3, 0.45)
	sp_style.corner_radius_top_left = 4
	sp_style.corner_radius_top_right = 4
	sp_style.corner_radius_bottom_left = 4
	sp_style.corner_radius_bottom_right = 4
	sprite_panel.add_theme_stylebox_override("panel", sp_style)
	content_row.add_child(sprite_panel)

	_sprite_texture = TextureRect.new()
	_sprite_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite_texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sprite_texture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sprite_texture.visible = false
	sprite_panel.add_child(_sprite_texture)

	_sprite_label = Label.new()
	_sprite_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sprite_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sprite_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sprite_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sprite_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.5))
	_sprite_label.add_theme_font_size_override("font_size", 36)
	sprite_panel.add_child(_sprite_label)

	vbox.add_child(_make_separator())

	# ── Unique Passive ───────────────────────────
	vbox.add_child(_make_section_header("UNIQUE PASSIVE"))

	_passive_label = Label.new()
	_passive_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_passive_label.add_theme_font_size_override("font_size", 12)
	_passive_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	vbox.add_child(_passive_label)

	_slot_label = Label.new()
	_slot_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_slot_label.add_theme_font_size_override("font_size", 11)
	_slot_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.75))
	vbox.add_child(_slot_label)

	vbox.add_child(_make_separator())

	# ── Starting Inventory ───────────────────────
	vbox.add_child(_make_section_header("STARTING ITEM"))

	_inventory_name_label = Label.new()
	_inventory_name_label.add_theme_font_size_override("font_size", 13)
	_inventory_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	vbox.add_child(_inventory_name_label)

	_inventory_desc_label = Label.new()
	_inventory_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_inventory_desc_label.add_theme_font_size_override("font_size", 11)
	_inventory_desc_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(_inventory_desc_label)

	vbox.add_child(_make_separator())

	# ── Archetypes ──────────────────────────────
	_archetypes_header_label = Label.new()
	_archetypes_header_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_archetypes_header_label.add_theme_font_size_override("font_size", 10)
	_archetypes_header_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.7))
	_archetypes_header_label.text = "ARCHETYPES"
	vbox.add_child(_archetypes_header_label)

	var playstyle_label = Label.new()
	playstyle_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	playstyle_label.add_theme_font_size_override("font_size", 11)
	playstyle_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	playstyle_label.text = "Play this character for a playstyle fitting the following archetypes:"
	playstyle_label.name = "PlaystyleLabel"
	vbox.add_child(playstyle_label)

	for i in range(4):
		var arch_label = Label.new()
		arch_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		arch_label.add_theme_font_size_override("font_size", 11)
		arch_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.5))
		vbox.add_child(arch_label)
		_archetype_labels.append(arch_label)

		var ability_box = VBoxContainer.new()
		ability_box.add_theme_constant_override("separation", 1)
		vbox.add_child(ability_box)
		_ability_containers.append(ability_box)

	# ── Spacer ───────────────────────────────────
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# ── Select Button ────────────────────────────
	_select_button = Button.new()
	_select_button.text = "SELECT CHARACTER"
	_select_button.add_theme_font_size_override("font_size", 13)
	_select_button.pressed.connect(_on_select_pressed)

	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.15, 0.3, 0.55)
	btn_normal.corner_radius_top_left = 4
	btn_normal.corner_radius_top_right = 4
	btn_normal.corner_radius_bottom_left = 4
	btn_normal.corner_radius_bottom_right = 4
	_select_button.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.25, 0.45, 0.75)
	btn_hover.corner_radius_top_left = 4
	btn_hover.corner_radius_top_right = 4
	btn_hover.corner_radius_bottom_left = 4
	btn_hover.corner_radius_bottom_right = 4
	_select_button.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed_style = StyleBoxFlat.new()
	btn_pressed_style.bg_color = Color(0.1, 0.2, 0.4)
	btn_pressed_style.corner_radius_top_left = 4
	btn_pressed_style.corner_radius_top_right = 4
	btn_pressed_style.corner_radius_bottom_left = 4
	btn_pressed_style.corner_radius_bottom_right = 4
	_select_button.add_theme_stylebox_override("pressed", btn_pressed_style)

	vbox.add_child(_select_button)

func setup(character: CharacterData) -> void:
	character_data = character

	if _name_label:
		_name_label.text = character.character_name

	if _sprite_label:
		_sprite_label.text = character.character_name.left(1)

	if _sprite_texture and character.sprite_path != "" and ResourceLoader.exists(character.sprite_path):
		_sprite_texture.texture = load(character.sprite_path)
		_sprite_texture.visible = true
		_sprite_label.visible = false

	# Core stats
	var core_values = {
		"STR": character.strength,
		"DEX": character.dexterity,
		"INT": character.intelligence,
		"WIS": character.wisdom,
		"DET": character.determination,
		"AGI": character.agility,
	}
	for key in core_values:
		if _stat_labels.has(key):
			_stat_labels[key].text = "%s  %d" % [key, core_values[key]]

	# Derived stats
	if _stat_labels.has("HP"):
		_stat_labels["HP"].text   = "HP   %d" % character.base_health
	if _stat_labels.has("Mana"):
		_stat_labels["Mana"].text = "Mana %d" % character.base_mana
	if _stat_labels.has("Hand"):
		_stat_labels["Hand"].text = "Hand %d" % character.get_max_hand_size()
	if _stat_labels.has("Draw"):
		_stat_labels["Draw"].text = "Draw %d turns" % character.base_draw_timer

	# Passive & slot specialty
	if _passive_label:
		_passive_label.text = character.passive_description
	if _slot_label:
		_slot_label.text = "Slots: %s" % character.slot_specialty

	# Starting inventory
	if _inventory_name_label:
		_inventory_name_label.text = character.starting_item_name
	if _inventory_desc_label:
		_inventory_desc_label.text = character.starting_item_description

	# Archetypes
	for i in range(_archetype_labels.size()):
		if i < character.archetypes.size():
			var arch = character.archetypes[i]
			_archetype_labels[i].text = "%s - %s" % [arch["name"], arch["description"]]
			_archetype_labels[i].visible = true

			# Clear previous ability labels
			for child in _ability_containers[i].get_children():
				child.queue_free()
			_ability_containers[i].visible = true

			# Add ability labels if present
			if arch.has("abilities"):
				for ability in arch["abilities"]:
					var ability_label = Label.new()
					ability_label.autowrap_mode = TextServer.AUTOWRAP_WORD
					ability_label.add_theme_font_size_override("font_size", 9)
					ability_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
					ability_label.text = "  • %s: %s" % [ability["name"], ability["description"]]
					_ability_containers[i].add_child(ability_label)
		else:
			_archetype_labels[i].visible = false
			_ability_containers[i].visible = false

func _on_select_pressed() -> void:
	selected.emit(character_data)

# ── Helpers ───────────────────────────────────────────

func _make_separator() -> HSeparator:
	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color(0.3, 0.3, 0.45))
	return sep

func _make_section_header(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.7))
	return lbl

func _make_stat_label(color: Color) -> Label:
	var lbl = Label.new()
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	return lbl
