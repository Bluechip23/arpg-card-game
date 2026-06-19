class_name AnimationLab
extends Control

## Animation Lab — a development workbench for authoring card/passive animations.
##
## Shows a generic 3D character in a viewport "box" with a scrollable list of
## every card and passive on the side. Selecting an entry makes the character
## perform that entry's animation, so animations can be iterated on here instead
## of having to reproduce situations in a real battle.
##
## The character is intentionally generic — animations are skeletal/procedural and
## do not depend on which character is shown. Cards play the action returned by
## Card.get_animation_action(); as unique per-card animations are authored there
## (and in CharacterFigure.play_action), this lab picks them up automatically.

const TitleMenuScene := "res://scenes/menus/title_menu.tscn"

var _figure: CharacterFigure = null
var _list_vbox: VBoxContainer = null
var _status_label: Label = null
var _filter_edit: LineEdit = null
var _left_column: VBoxContainer = null

# Each entry button: { "button": Button, "search": String }
var _entry_buttons: Array[Dictionary] = []

var _current_dir: int = CharacterAnimator.Direction.SOUTH
var _current_action: String = ""


func _ready() -> void:
	_build_ui()
	_build_viewport()
	_populate_list()


# =============================================================
# UI
# =============================================================

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.06, 0.09)
	add_child(bg)

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
	top_bar.add_child(back_btn)

	var title := Label.new()
	title.text = "Animation Lab"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	top_bar.add_child(title)

	_status_label = Label.new()
	_status_label.text = "Select a card or passive to preview its animation."
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
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
	body.add_child(left)
	_left_column = left

	# Right column (filter + scrolling list)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(340, 0)
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)

	_filter_edit = LineEdit.new()
	_filter_edit.placeholder_text = "Filter cards / passives..."
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

	# World environment so the shaded figure is clearly lit.
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.13, 0.18)
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
	ground_mat.albedo_color = Color(0.18, 0.19, 0.24)
	ground.material_override = ground_mat
	vp.add_child(ground)

	var camera := Camera3D.new()
	camera.current = true
	camera.position = Vector3(0, 1.7, 3.7)
	vp.add_child(camera)
	camera.look_at(Vector3(0, 0.85, 0), Vector3.UP)

	_figure = CharacterFigure.new()
	vp.add_child(_figure)
	_figure.setup("Ryan")
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


func _add_dir_button(parent: Node, label: String, dir: int) -> void:
	var btn := Button.new()
	btn.text = label
	btn.pressed.connect(_on_set_direction.bind(dir))
	parent.add_child(btn)


# =============================================================
# LIST POPULATION
# =============================================================

func _populate_list() -> void:
	_add_section_header("CARDS")
	for entry in _collect_cards():
		_add_entry(entry["label"], entry["action"], entry["search"])

	_add_section_header("PASSIVES")
	for entry in _collect_passives():
		_add_entry(entry["label"], entry["action"], entry["search"])


func _add_section_header(text: String) -> void:
	var header := Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	_list_vbox.add_child(spacer)
	_list_vbox.add_child(header)


func _add_entry(label: String, action: String, search: String) -> void:
	var btn := Button.new()
	btn.text = label
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_entry_selected.bind(label, action))
	_list_vbox.add_child(btn)
	_entry_buttons.append({"button": btn, "search": search.to_lower()})


## Returns every card via reflection over Card's create_*() factory methods,
## sorted by display name. Mirrors deck_manager's factory discovery.
func _collect_cards() -> Array:
	var out: Array = []
	var card_script: Script = Card
	for method in card_script.get_script_method_list():
		var mname: String = method["name"]
		if mname.begins_with("create_") and method["args"].size() == 0:
			var card = card_script.call(mname)
			if card is Card:
				var type_name: String = Card.CardType.keys()[card.card_type].capitalize()
				out.append({
					"label": "%s  (%s)" % [card.card_name, type_name],
					"action": card.get_animation_action(),
					"search": "%s %s" % [card.card_name, card.card_id],
				})
	out.sort_custom(func(a, b): return a["label"] < b["label"])
	return out


## Collects passives from the skill trees and the sphere grid. Passives have no
## bespoke animations yet — selecting one resets the figure to idle — but listing
## them here is the hook for authoring those animations later.
func _collect_passives() -> Array:
	var out: Array = []
	var seen := {}

	var trees := [
		SkillTreeData.create_brad_tree(),
		SkillTreeData.create_stephen_tree(),
		SkillTreeData.create_ryan_tree(),
		SkillTreeData.create_cory_tree(),
		SkillTreeData.create_jeremy_tree(),
	]
	for tree in trees:
		for row in tree.rows:
			for opt in row.options:
				if opt.option_type == SkillTreeData.OptionType.PASSIVE \
						or opt.option_type == SkillTreeData.OptionType.PASSIVE_MUTATION:
					var key: String = opt.name if opt.name != "" else opt.passive_id
					if key == "" or seen.has(key):
						continue
					seen[key] = true
					out.append({
						"label": key,
						"action": "passive:%s" % opt.passive_id,
						"search": "%s %s %s" % [key, opt.passive_id, opt.description],
					})

	var grid := SphereGrid.new()
	for node in grid.get_all_nodes():
		if node.node_type == SphereGrid.NodeType.PASSIVE:
			var desc: String = node.description
			if desc == "" or seen.has(desc):
				continue
			seen[desc] = true
			out.append({
				"label": desc,
				"action": "passive_grid:%d" % node.id,
				"search": desc,
			})

	out.sort_custom(func(a, b): return a["label"] < b["label"])
	return out


# =============================================================
# CALLBACKS
# =============================================================

func _on_entry_selected(label: String, action: String) -> void:
	_current_action = action
	_play_current()
	_status_label.text = "%s  →  action: \"%s\"" % [label, action]


func _on_replay() -> void:
	if _current_action != "":
		_play_current()


func _on_set_direction(dir: int) -> void:
	_current_dir = dir
	if _figure:
		_figure.set_facing(dir)
	if _current_action != "":
		_play_current()


func _play_current() -> void:
	if _figure:
		_figure.play_action(_current_action, _current_dir)


func _on_filter_changed(text: String) -> void:
	var needle := text.strip_edges().to_lower()
	for entry in _entry_buttons:
		var btn: Button = entry["button"]
		btn.visible = needle == "" or entry["search"].contains(needle)


func _on_back() -> void:
	var title = load(TitleMenuScene).instantiate()
	get_tree().root.add_child(title)
	queue_free()
