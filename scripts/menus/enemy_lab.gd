class_name EnemyLab
extends Control

## Enemy Lab — a development workbench for browsing every enemy and previewing
## its idle, movement and attack animations, the sibling of the Animation Lab.
##
## Shows the SpriteEnemyFigure for the selected enemy in a viewport "box" with a
## scrollable list of every enemy on the side. Selecting an enemy rebuilds the
## figure for that species; the action buttons below the viewport drive the same
## figure animations (idle / move / attack / hit) that battle uses, plus a button
## per the enemy's real action list so you can step through its moveset.
##
## Enemy data (names, stats, action lists, behaviour notes) comes from the single
## source of truth Enemy.get_all_enemy_data(); the figure kind comes from
## EnemyDefs, exactly as Enemy._setup_sprite() reads it.

const TitleMenuScene := "res://scenes/menus/title_menu.tscn"

# Enemies are catalogued by HABITAT, not by Act (see docs/STORY.md §5.3):
# an Act simply draws from one or more habitats.
const SECTIONS := [
	{"title": "GENERIC", "types": [Enemy.EnemyType.MINION, Enemy.EnemyType.ELITE, Enemy.EnemyType.BOSS]},
	{"title": "FOREST", "types": [
		Enemy.EnemyType.HYDRA, Enemy.EnemyType.GIANT_BEAVER, Enemy.EnemyType.MINI_BEAR,
		Enemy.EnemyType.LARGE_BEAR, Enemy.EnemyType.WOLF, Enemy.EnemyType.COYOTE,
		Enemy.EnemyType.BUGBEAR, Enemy.EnemyType.INFECTED_HUNTER, Enemy.EnemyType.GIANT_HAWK,
		Enemy.EnemyType.TREANT, Enemy.EnemyType.ICE_MAGE, Enemy.EnemyType.FIRE_MAGE,
		Enemy.EnemyType.SPARK_MAGE, Enemy.EnemyType.AIR_MAGE, Enemy.EnemyType.EARTH_MAGE,
	]},
	{"title": "GRAVEYARD", "types": [
		Enemy.EnemyType.SKELETON, Enemy.EnemyType.ZOMBIE, Enemy.EnemyType.WEREWOLF,
		Enemy.EnemyType.WERERABBIT, Enemy.EnemyType.SCREECHER, Enemy.EnemyType.VAMPIRE,
		Enemy.EnemyType.NECROMANCER, Enemy.EnemyType.BONE_DRAGON, Enemy.EnemyType.SPIRIT_COLLECTOR,
		Enemy.EnemyType.GRAVE_TITAN, Enemy.EnemyType.CRYPT_CRAWLER, Enemy.EnemyType.CONSUMED,
	]},
	{"title": "CAVE", "types": [
		Enemy.EnemyType.ARMORED_TROLL, Enemy.EnemyType.FIRE_GOBLIN_SOLDIER,
		Enemy.EnemyType.FIRE_GOBLIN_MAGE, Enemy.EnemyType.FIRE_GOBLIN_SHAMAN,
	]},
	{"title": "SEWER", "types": [
		Enemy.EnemyType.WERERAT, Enemy.EnemyType.ARCHER_RAT, Enemy.EnemyType.SLUDGE,
		Enemy.EnemyType.PIPE_CRAWLER, Enemy.EnemyType.SEWER_CROC, Enemy.EnemyType.RAT_KING,
		Enemy.EnemyType.SWARM,
	]},
	{"title": "MOUNTAINS", "types": [
		Enemy.EnemyType.WEREGOAT, Enemy.EnemyType.WYVERN, Enemy.EnemyType.ROC,
		Enemy.EnemyType.ICE_TROLL, Enemy.EnemyType.SNOW_WRAITH, Enemy.EnemyType.GRANITE_COLOSSUS,
		Enemy.EnemyType.WHITE_MANTICORE, Enemy.EnemyType.SABERTOOTH,
	]},
	{"title": "UNDERWORLD", "types": [
		Enemy.EnemyType.CERBERUS, Enemy.EnemyType.SUCCUBUS, Enemy.EnemyType.DEMON,
		Enemy.EnemyType.IFRIT, Enemy.EnemyType.MIND_EATER, Enemy.EnemyType.SPECTER,
		Enemy.EnemyType.MAGMA_SPIDER, Enemy.EnemyType.PIT_FIEND, Enemy.EnemyType.ASH_HARPY,
		Enemy.EnemyType.INFLAMED_MINOTAUR,
	]},
	{"title": "HEAVENS", "types": [
		Enemy.EnemyType.CHERUB, Enemy.EnemyType.DJINN, Enemy.EnemyType.CORRUPTED_ARCHANGEL,
	]},
]

# Display action names (from get_all_enemy_data) that are movement rather than attacks.
const MOVE_ACTIONS := ["move", "scurry", "scurry away", "get into range", "flee", "hop", "drift"]

var _viewport: SubViewport = null
var _figure_root: Node3D = null       # holds the current figure/box; tweened for "move"
var _figure: SpriteEnemyFigure = null

var _list_vbox: VBoxContainer = null
var _status_label: Label = null
var _info_label: RichTextLabel = null
var _filter_edit: LineEdit = null
var _left_column: VBoxContainer = null
var _action_row: HBoxContainer = null

# Each entry button: { "button": Button, "search": String }
var _entry_buttons: Array[Dictionary] = []

var _data_by_type: Dictionary = {}    # EnemyType -> get_all_enemy_data() entry
var _current_type: int = -1
var _current_dir: int = CharacterAnimator.Direction.SOUTH
var _move_tween: Tween = null


func _ready() -> void:
	_index_enemy_data()
	_build_ui()
	_build_viewport()
	_populate_list()
	# Open on the first enemy that has a bespoke model so the viewport isn't a bare box.
	_select_type(Enemy.EnemyType.WERERAT)


func _index_enemy_data() -> void:
	# get_all_enemy_data() returns entries in EnemyType.values() order.
	var data := Enemy.get_all_enemy_data()
	var types := Enemy.EnemyType.values()
	for i in range(types.size()):
		if i < data.size():
			_data_by_type[types[i]] = data[i]


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
	title.text = "Enemy Lab"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	top_bar.add_child(title)

	_status_label = Label.new()
	_status_label.text = "Select an enemy to preview its animations."
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	top_bar.add_child(_status_label)

	# --- Body: viewport box on the left, list on the right ---
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root_vbox.add_child(body)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	_left_column = left

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(340, 0)
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)

	_filter_edit = LineEdit.new()
	_filter_edit.placeholder_text = "Filter enemies..."
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
	# A framed box that renders the 3D enemy.
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
	_viewport = vp

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

	# The figure lives under this node so "move" can translate it without
	# fighting the figure's own internal motion (which moves its rig).
	_figure_root = Node3D.new()
	vp.add_child(_figure_root)

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

	# --- Core animation controls (always available) ---
	var core_row := HBoxContainer.new()
	core_row.alignment = BoxContainer.ALIGNMENT_CENTER
	core_row.add_theme_constant_override("separation", 6)
	_left_column.add_child(core_row)

	var core_label := Label.new()
	core_label.text = "Animation:"
	core_row.add_child(core_label)

	_add_core_button(core_row, "Idle", "idle")
	_add_core_button(core_row, "Move", "move")
	_add_core_button(core_row, "Attack", "attack")
	_add_core_button(core_row, "Hit", "hit")

	# --- Per-enemy moveset (rebuilt per selection) ---
	_action_row = HBoxContainer.new()
	_action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_action_row.add_theme_constant_override("separation", 6)
	_left_column.add_child(_action_row)

	# --- Enemy info / behaviour panel ---
	var info_panel := PanelContainer.new()
	info_panel.custom_minimum_size = Vector2(0, 120)
	_left_column.add_child(info_panel)

	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.fit_content = true
	_info_label.scroll_active = false
	_info_label.add_theme_constant_override("margin_left", 10)
	_info_label.add_theme_constant_override("margin_top", 8)
	_info_label.add_theme_constant_override("margin_right", 10)
	_info_label.add_theme_constant_override("margin_bottom", 8)
	info_panel.add_child(_info_label)


func _add_dir_button(parent: Node, label: String, dir: int) -> void:
	var btn := Button.new()
	btn.text = label
	btn.pressed.connect(_on_set_direction.bind(dir))
	parent.add_child(btn)


func _add_core_button(parent: Node, label: String, category: String) -> void:
	var btn := Button.new()
	btn.text = label
	btn.pressed.connect(_on_play_category.bind(category, label))
	parent.add_child(btn)


# =============================================================
# LIST POPULATION
# =============================================================

func _populate_list() -> void:
	for section in SECTIONS:
		_add_section_header(section["title"])
		for type in section["types"]:
			var d: Dictionary = _data_by_type.get(type, {})
			var nm: String = d.get("name", "Enemy")
			var tier: String = d.get("type", "")
			_add_entry(type, "%s  (%s)" % [nm, tier], "%s %s" % [nm, tier])


func _add_section_header(text: String) -> void:
	var header := Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	_list_vbox.add_child(spacer)
	_list_vbox.add_child(header)


func _add_entry(type: int, label: String, search: String) -> void:
	var btn := Button.new()
	btn.text = label
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_select_type.bind(type))
	_list_vbox.add_child(btn)
	_entry_buttons.append({"button": btn, "search": search.to_lower()})


# =============================================================
# SELECTION / FIGURE BUILDING
# =============================================================

func _select_type(type: int) -> void:
	_current_type = type
	_build_figure(type)
	_build_moveset_buttons(type)
	_update_info(type)
	_apply_facing()
	var d: Dictionary = _data_by_type.get(type, {})
	_status_label.text = "%s  —  idle" % d.get("name", "Enemy")


func _build_figure(type: int) -> void:
	# Tear down whatever figure/box is currently shown.
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null
	_figure = null
	for child in _figure_root.get_children():
		child.queue_free()
	_figure_root.position = Vector3.ZERO
	_figure_root.rotation_degrees = Vector3.ZERO

	var kind: String = str(EnemyDefs.DEFS.get(Enemy.EnemyType.keys()[type], {}).get("figure_kind", ""))
	if SpriteEnemyFigure.supports(kind):
		_figure = SpriteEnemyFigure.new()
		_figure_root.add_child(_figure)
		_figure.setup(kind)


func _build_moveset_buttons(type: int) -> void:
	for child in _action_row.get_children():
		child.queue_free()

	var d: Dictionary = _data_by_type.get(type, {})
	var actions: Array = d.get("actions", [])
	if actions.is_empty():
		return

	var label := Label.new()
	label.text = "Moveset:"
	_action_row.add_child(label)

	for action in actions:
		var aname: String = action.get("name", "")
		var tempo: int = action.get("tempo", 0)
		var btn := Button.new()
		btn.text = "%s (%d)" % [aname, tempo]
		var category := _classify_action(aname)
		btn.pressed.connect(_on_play_category.bind(category, aname))
		_action_row.add_child(btn)


func _classify_action(action_name: String) -> String:
	var n := action_name.to_lower()
	if n in MOVE_ACTIONS:
		return "move"
	if n.contains("heal"):
		return "heal"
	return "attack"


func _update_info(type: int) -> void:
	var d: Dictionary = _data_by_type.get(type, {})
	if d.is_empty():
		_info_label.text = ""
		return
	var special: String = d.get("special", "")
	special = special.replace("\n", "\n")
	_info_label.text = "[b]%s[/b]  [color=#9aa]%s[/color]\n[color=#cfd]HP %d   Armor %d   DMG %d   XP %d[/color]\n\n%s" % [
		d.get("name", "Enemy"), d.get("type", ""),
		int(d.get("health", 0)), int(d.get("armor", 0)), int(d.get("damage", 0)), int(d.get("xp", 0)),
		special,
	]


# =============================================================
# ANIMATION PLAYBACK
# =============================================================

func _on_play_category(category: String, label: String) -> void:
	match category:
		"move":
			_play_move()
		"attack":
			# Route to the enemy's specific attack animation. The figure disambiguates
			# multi-attack species (kick vs smash, hook vs cleave, slam vs root...) by
			# this key, derived from the action's display name.
			_play_attack(label.strip_edges().to_lower().replace(" ", "_"))
		"heal":
			_play_heal()
		"hit":
			_play_hit()
		_:
			_play_idle()
	var d: Dictionary = _data_by_type.get(_current_type, {})
	_status_label.text = "%s  —  %s" % [d.get("name", "Enemy"), label]


func _play_idle() -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	if _figure:
		_figure.set_walking(false)
	_figure_root.position = Vector3.ZERO


func _play_move() -> void:
	# Walk in place (leg cycle / bob) while gliding forward and back so the
	# locomotion reads clearly in the small viewport.
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	var forward := _facing_offset() * 0.7
	if _figure:
		_figure.set_walking(true)
	_move_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_move_tween.tween_property(_figure_root, "position", forward, 0.6)
	_move_tween.tween_property(_figure_root, "position", Vector3.ZERO, 0.6)
	_move_tween.tween_callback(func():
		if _figure:
			_figure.set_walking(false))


func _play_attack(key: String = "attack") -> void:
	if _figure:
		_figure.play_action(key)
		_figure.flash(Color(1.0, 0.7, 0.3))  # the colour "blink" on every attack


func _play_hit() -> void:
	if _figure:
		_figure.play_hit()
		_figure.flash(Color(1.0, 0.3, 0.3))


func _play_heal() -> void:
	if _figure:
		_figure.set_walking(false)
		_figure.flash(Color(0.5, 1.0, 0.5))


# =============================================================
# FACING
# =============================================================

func _on_set_direction(dir: int) -> void:
	_current_dir = dir
	_apply_facing()


func _apply_facing() -> void:
	if _figure:
		_figure.set_facing(_current_dir)


## World-space forward offset for the current facing (+Z is south, toward the camera).
func _facing_offset() -> Vector3:
	match _current_dir:
		CharacterAnimator.Direction.NORTH: return Vector3(0, 0, -0.7)
		CharacterAnimator.Direction.EAST: return Vector3(0.7, 0, 0)
		CharacterAnimator.Direction.WEST: return Vector3(-0.7, 0, 0)
		_: return Vector3(0, 0, 0.7)  # SOUTH


# =============================================================
# MISC
# =============================================================

func _on_filter_changed(text: String) -> void:
	var needle := text.strip_edges().to_lower()
	for entry in _entry_buttons:
		var btn: Button = entry["button"]
		btn.visible = needle == "" or entry["search"].contains(needle)


func _on_back() -> void:
	var title = load(TitleMenuScene).instantiate()
	get_tree().root.add_child(title)
	queue_free()
