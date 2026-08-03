class_name CharacterCard
extends PanelContainer

## Displays a single character's info for selection

signal selected(character: CharacterData)
signal skill_tree_requested(character: CharacterData)

var character_data: CharacterData

# UI nodes built programmatically
var _name_label: Label
var _sprite_panel: PanelContainer
var _sprite_texture: TextureRect
var _sprite_label: Label
var _figure_viewport: SubViewport = null
var _passive_label: Label
var _slot_label: Label
var _archetypes_header_label: Label
var _archetype_labels: Array[Label] = []
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

	# ── Portrait Row ─────────────────────────────
	# (Stats/resources removed: every character now starts with identical
	# numbers, so the portrait is the card's hero visual.)
	var content_row = HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 12)
	content_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(content_row)

	var sprite_panel = PanelContainer.new()
	sprite_panel.custom_minimum_size = Vector2(140, 150)
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
	_sprite_panel = sprite_panel

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

	# ── Archetypes ──────────────────────────────
	_archetypes_header_label = Label.new()
	_archetypes_header_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_archetypes_header_label.add_theme_font_size_override("font_size", 10)
	_archetypes_header_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.7))
	_archetypes_header_label.text = "ARCHETYPES"
	vbox.add_child(_archetypes_header_label)

	for i in range(4):
		var arch_label = Label.new()
		arch_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		arch_label.add_theme_font_size_override("font_size", 11)
		arch_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.5))
		vbox.add_child(arch_label)
		_archetype_labels.append(arch_label)

	# ── Spacer ───────────────────────────────────
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# ── Skill Tree Button ────────────────────────
	var skill_tree_button = Button.new()
	skill_tree_button.text = "SKILL TREE"
	skill_tree_button.add_theme_font_size_override("font_size", 13)
	skill_tree_button.pressed.connect(_on_skill_tree_pressed)

	var st_normal = StyleBoxFlat.new()
	st_normal.bg_color = Color(0.25, 0.2, 0.4)
	st_normal.corner_radius_top_left = 4
	st_normal.corner_radius_top_right = 4
	st_normal.corner_radius_bottom_left = 4
	st_normal.corner_radius_bottom_right = 4
	skill_tree_button.add_theme_stylebox_override("normal", st_normal)

	var st_hover = StyleBoxFlat.new()
	st_hover.bg_color = Color(0.35, 0.3, 0.55)
	st_hover.corner_radius_top_left = 4
	st_hover.corner_radius_top_right = 4
	st_hover.corner_radius_bottom_left = 4
	st_hover.corner_radius_bottom_right = 4
	skill_tree_button.add_theme_stylebox_override("hover", st_hover)

	var st_pressed = StyleBoxFlat.new()
	st_pressed.bg_color = Color(0.18, 0.14, 0.3)
	st_pressed.corner_radius_top_left = 4
	st_pressed.corner_radius_top_right = 4
	st_pressed.corner_radius_bottom_left = 4
	st_pressed.corner_radius_bottom_right = 4
	skill_tree_button.add_theme_stylebox_override("pressed", st_pressed)

	vbox.add_child(skill_tree_button)

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

	# Render a 3D figure preview for real characters (the quiz "Customize" card
	# keeps its "?" placeholder). Preset identity drives the figure so renamed
	# saves keep their look.
	if character.character_name != "Customize":
		_build_figure_preview(character.get_base_character(), character.sprite_path)

	# (Per-character stat/resource readouts removed — identical across the
	# roster now; identity comes from passive, slots and archetypes.)

	# Passive & slot specialty
	if _passive_label:
		_passive_label.text = character.passive_description
	if _slot_label:
		_slot_label.text = "Slots: %s" % character.slot_specialty

	# Archetypes
	for i in range(_archetype_labels.size()):
		if i < character.archetypes.size():
			var arch = character.archetypes[i]
			_archetype_labels[i].text = "%s - %s" % [arch["name"], arch["description"]]
			_archetype_labels[i].visible = true
		else:
			_archetype_labels[i].visible = false

func _build_figure_preview(character_name: String, sprite_path: String = "") -> void:
	## Drops a small 3D scene (figure + camera + lights) into the sprite panel via a
	## SubViewport, giving each card a pre-rendered "SNES RPG" look instead of a flat
	## 2D sprite. The figure idles on its own (see CharacterFigure._process).
	if _figure_viewport or not _sprite_panel:
		return

	var sub_container := SubViewportContainer.new()
	sub_container.stretch = true
	sub_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sub_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite_panel.add_child(sub_container)

	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_container.add_child(viewport)
	_figure_viewport = viewport

	# Mana Seed sprite portrait when the character has one (matches the new
	# in-battle look); procedural 3D figure otherwise.
	var figure: Node3D
	if SpriteFigure.supports(character_name):
		figure = SpriteFigure.new()
	else:
		figure = CharacterFigure.new()
	figure.setup(character_name, sprite_path)
	viewport.add_child(figure)

	# Orthographic, slightly raised 3/4 angle — that pre-rendered Mario-RPG feel.
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.6
	viewport.add_child(cam)
	cam.position = Vector3(0.5, 1.05, 2.6)
	cam.look_at(Vector3(0, 0.58, 0), Vector3.UP)
	cam.current = true

	var key := DirectionalLight3D.new()
	key.light_energy = 1.15
	viewport.add_child(key)
	key.rotation_degrees = Vector3(-45, -30, 0)  # global upper-left light (style guide §3)

	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.45
	viewport.add_child(fill)
	fill.rotation_degrees = Vector3(-12, -42, 0)

	# The 3D figure stands in for the flat placeholders
	if _sprite_texture:
		_sprite_texture.visible = false
	if _sprite_label:
		_sprite_label.visible = false

func _on_select_pressed() -> void:
	selected.emit(character_data)

func _on_skill_tree_pressed() -> void:
	skill_tree_requested.emit(character_data)

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

