class_name AnimationLab
extends "res://scripts/shared/lab_menu_base.gd"

## Animation Lab — a development workbench for authoring card animations.
##
## Shows a character in a viewport "box" with a scrollable list on the side:
## the hero's own drawn actions, every card grouped by type (the sandbox's
## Spell / Offensive / Attack / Defensive / Utility / Instant / Maintain), and
## the systemic effects. Selecting an entry makes the character perform it,
## so animations can be iterated on here instead of having to reproduce
## situations in a real battle.
##
## Characters render through SpriteFigure — the same billboard figure battle
## uses — so the lab previews what ships. Cards play exactly what battle
## plays (main._play_card_animation): Card.get_animation_action(), and a
## Spell card the hero's drawn cast. (Passives have no animations and are not
## listed, designer 2026-11-15.)

const TitleMenuScene := "res://scenes/menus/title_menu.tscn"

var _figure: SpriteFigure = null
var _status_label: Label = null
var _filter_edit: LineEdit = null
var _left_column: VBoxContainer = null
var _viewport: SubViewport = null
var _camera: Camera3D = null
var _reveal: MythicReveal = null  # active Mythic Reveal preview, if any

# Each entry button: { "button": Button, "search": String }

var _current_dir: int = CharacterAnimator.Direction.SOUTH
var _current_action: String = ""
var _current_armor: bool = false
var _current_heal: bool = false
var _current_spell: bool = false


func _ready() -> void:
	_build_ui()
	_build_viewport()
	_populate_list()


# =============================================================
# UI
# =============================================================

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Emerald Sanctum: the forest shows around the edges, dimmed hard so the
	# lab's panels stay the focus.
	EmeraldTheme.apply(self, true, 0.55)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	# --- Top bar: back button, title, status ---
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 16)
	root_vbox.add_child(top_bar)

	var back_btn := Button.new()
	back_btn.text = "< Back"
	back_btn.pressed.connect(_on_back)
	back_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	EmeraldTheme.style_button(back_btn, 16)
	top_bar.add_child(back_btn)

	var title := Label.new()
	title.text = "Animation Lab"
	EmeraldTheme.style_title(title, 32)
	top_bar.add_child(title)

	_status_label = Label.new()
	_status_label.text = "Select an action or a card to preview its animation."
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
	top_bar.add_child(_status_label)

	# --- Body: viewport box on the left, list on the right ---
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root_vbox.add_child(body)

	# Left column (viewport + direction controls)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	body.add_child(_glass_panel(left, true))
	_left_column = left

	# Right column (filter + scrolling list)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(340, 0)
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	body.add_child(_glass_panel(right, false))

	_filter_edit = LineEdit.new()
	_filter_edit.placeholder_text = "Filter actions / cards..."
	_filter_edit.clear_button_enabled = true
	_filter_edit.text_changed.connect(_on_filter_changed)
	right.add_child(_filter_edit)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 2)
	scroll.add_child(_list_vbox)


func _build_viewport() -> void:
	# A framed box that renders the 3D character.
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel",
		EmeraldTheme.panel_box(Color(0.01, 0.05, 0.04, 1.0), EmeraldTheme.GOLD_DIM, 1, 4, 2))
	_left_column.add_child(frame)

	var vp_container := SubViewportContainer.new()
	vp_container.stretch = true
	vp_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vp_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(vp_container)

	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_4X
	vp_container.add_child(vp)
	_viewport = vp
	# Clicks in the preview drive click-to-advance sequences (Mythic Reveal).
	vp_container.gui_input.connect(_on_viewport_input)

	# World environment so the shaded figure is clearly lit.
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.11, 0.10)  # emerald dusk
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.65)
	env.ambient_light_energy = 0.7
	world_env.environment = env
	vp.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -35, 0)
	light.light_energy = 1.1
	vp.add_child(light)

	# Simple ground so the figure isn't floating in a void.
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6, 6)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.11, 0.19, 0.16)
	ground.material_override = ground_mat
	vp.add_child(ground)

	var camera := Camera3D.new()
	camera.current = true
	camera.position = Vector3(0, 1.35, 3.0)
	vp.add_child(camera)
	camera.look_at(Vector3(0, 0.7, 0), Vector3.UP)
	_camera = camera

	_figure = SpriteFigure.new()
	vp.add_child(_figure)
	_figure.setup("Brad")
	_figure.set_facing(_current_dir)

	# --- Direction + replay controls ---
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 6)
	_left_column.add_child(controls)

	var facing_label := Label.new()
	facing_label.text = "Facing:"
	controls.add_child(facing_label)

	_add_dir_button(controls, "South", CharacterAnimator.Direction.SOUTH)
	_add_dir_button(controls, "North", CharacterAnimator.Direction.NORTH)
	_add_dir_button(controls, "East", CharacterAnimator.Direction.EAST)
	_add_dir_button(controls, "West", CharacterAnimator.Direction.WEST)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(20, 0)
	controls.add_child(spacer)

	var replay := Button.new()
	replay.text = "Replay"
	replay.pressed.connect(_on_replay)
	controls.add_child(replay)

	# --- Character selector: each hero's own drawn board and actions ---
	var char_row := HBoxContainer.new()
	char_row.alignment = BoxContainer.ALIGNMENT_CENTER
	char_row.add_theme_constant_override("separation", 6)
	_left_column.add_child(char_row)

	var char_label := Label.new()
	char_label.text = "Character:"
	char_row.add_child(char_label)

	for cname in ["Brad", "Ryan", "Stephen", "Cory", "Jeremy"]:
		var cbtn := Button.new()
		cbtn.text = cname
		cbtn.pressed.connect(_on_set_character.bind(cname))
		char_row.add_child(cbtn)


# =============================================================
# LIST POPULATION
# =============================================================

func _populate_list() -> void:
	# The hero's own drawn actions — what the Attack and Block buttons and the
	# auto attack play in battle, and the cast every Spell card plays.
	_add_section_header("HERO ACTIONS")
	_add_entry("Basic Attack", "basic_attack", "basic attack auto swing")
	_add_entry("Block", "basic_block", "basic block shield guard", true)
	_add_entry("Spell Cast", "spell_cast", "spell cast", false, false, true)

	# Cards by type, in the sandbox's groups and precedence (SandboxUI).
	var groups := _collect_cards()
	for type_name in SandboxUI.CARD_TYPE_ORDER:
		var entries: Array = groups.get(type_name, [])
		if entries.is_empty():
			continue
		_add_section_header("%s CARDS" % type_name.to_upper())
		for entry in entries:
			_add_entry(entry["label"], entry["action"], entry["search"], entry["armor"], entry["heal"], entry["spell"])

	_add_section_header("SYSTEMIC")
	# Feedback driven by game events rather than cards (previewable here).
	_add_entry("Level Up", "level_up", "level up levelup mist swirl")
	_add_entry("Mythic Reveal", "mythic_reveal", "mythic reveal loot glow present gift ribbon icon")


func _add_entry(label: String, action: String, search: String, grants_armor: bool = false, grants_heal: bool = false, spell: bool = false) -> void:
	var btn := Button.new()
	btn.text = label
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.clip_text = true
	_style_list_button(btn)
	btn.pressed.connect(_on_entry_selected.bind(label, action, grants_armor, grants_heal, spell))
	_list_vbox.add_child(btn)
	_entry_buttons.append({"button": btn, "search": search.to_lower()})


## Every catalogue card (the rank-scaled generated ones excepted), as
## type -> entries sorted by name; the type is SandboxUI.card_category.
func _collect_cards() -> Dictionary:
	var out: Dictionary = {}
	for card in Card.get_all_cards(false):
		if card == null:
			continue
		var type_name: String = SandboxUI.card_category(card)
		var spell: bool = card.school == Card.CardSchool.SPELL
		if not out.has(type_name):
			out[type_name] = []
		out[type_name].append({
			"label": card.card_name,
			"action": card.get_animation_action(),
			"search": "%s %s %s%s" % [card.card_name, card.card_id, type_name, " spell" if spell else ""],
			# So the lab previews the systemic armour/heal icons, which in
			# battle are driven by real stat changes rather than the animation.
			"armor": card.base_block > 0 or card.block > 0,
			"heal": card.heal_amount > 0,
			# A Spell card plays the hero's drawn cast, as in battle.
			"spell": spell,
		})
	for type_name in out:
		out[type_name].sort_custom(func(a, b): return a["label"] < b["label"])
	return out


# =============================================================
# CALLBACKS
# =============================================================

func _on_entry_selected(label: String, action: String, grants_armor: bool = false, grants_heal: bool = false, spell: bool = false) -> void:
	_current_action = action
	_current_armor = grants_armor
	_current_heal = grants_heal
	_current_spell = spell
	_play_current()
	if action != "mythic_reveal":  # the reveal preview writes its own status line
		_status_label.text = "%s  →  action: \"%s\"%s" % [label, action, "  (spell: the hero's cast)" if spell else ""]


func _on_replay() -> void:
	if _current_action != "":
		_play_current()


func _on_set_direction(dir: int) -> void:
	_current_dir = dir
	if _figure:
		_figure.set_facing(dir)
	if _current_action != "":
		_play_current()


func _on_set_character(character_name: String) -> void:
	if _figure:
		_figure.setup(character_name)
		_figure.set_facing(_current_dir)
	if _current_action != "":
		_play_current()


func _play_current() -> void:
	if not _figure:
		return
	_clear_reveal()
	if _current_action == "mythic_reveal":
		_play_mythic_reveal()
		return
	_figure.play_action(_current_action, _current_dir, _current_spell)
	# Preview the systemic overhead icons (battle drives these from real stat changes).
	if _current_armor:
		_figure.pop_armor_icon()
	if _current_heal:
		_figure.pop_heart()


# =============================================================
# MYTHIC REVEAL PREVIEW
# =============================================================

func _clear_reveal() -> void:
	if _reveal and is_instance_valid(_reveal):
		_reveal.queue_free()
	_reveal = null


## Runs the real MythicReveal node (scripts/battle/mythic_reveal.gd) in the
## preview viewport with a random mythic's icon. The radius is shrunk and the
## direction pinned eastward so the present stays inside the camera frame;
## in battle it uses the full radius and a random direction.
func _play_mythic_reveal() -> void:
	var pool: Array = ItemData.get_items_of_rarity(ItemData.Rarity.MYTHIC)
	var item: ItemData = pool[randi() % pool.size()] if not pool.is_empty() else null
	_reveal = MythicReveal.start(item, Vector3.ZERO)
	_reveal.glow_radius = 1.6
	_reveal.fixed_angle = 0.0  # +X: lands to the figure's right, in frame
	_reveal.claimed.connect(func(claimed_item):
		_status_label.text = "Mythic claimed: %s — Replay to run it again." % (claimed_item.item_name if claimed_item else "?"))
	_viewport.add_child(_reveal)
	var iname: String = item.item_name if item else "?"
	_status_label.text = "Mythic Reveal (%s) — click the present, then the icon." % iname


func _on_viewport_input(event: InputEvent) -> void:
	## Forward preview clicks to click-to-advance sequences: project the mouse
	## through the lab camera onto the ground plane and hand it to the reveal.
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _reveal == null or not is_instance_valid(_reveal) or _camera == null:
		return
	var origin: Vector3 = _camera.project_ray_origin(event.position)
	var dir: Vector3 = _camera.project_ray_normal(event.position)
	if absf(dir.y) < 0.0001:
		return
	var t: float = -origin.y / dir.y  # intersect the y=0 ground plane
	if t <= 0.0:
		return
	_reveal.try_click(origin + dir * t)


func _on_back() -> void:
	var title = load(TitleMenuScene).instantiate()
	get_tree().root.add_child(title)
	queue_free()


# =============================================================
# EMERALD THEME HELPERS
# =============================================================

## Seat a column on a dark emerald glass panel so it reads over the forest.
## List rows: bare text until hovered, then the theme's glass and gold.
