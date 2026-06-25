class_name EnemyLab
extends Control

## Enemy Lab — a development workbench for browsing every enemy and previewing
## its idle, movement and attack animations, the sibling of the Animation Lab.
##
## Shows the procedural 3D EnemyFigure for the selected enemy in a viewport "box"
## with a scrollable list of every enemy on the side. Selecting an enemy rebuilds
## the figure for that species; the action buttons below the viewport drive the
## same EnemyFigure animations (idle / move / attack / hit) that battle uses, plus
## a button per the enemy's real action list so you can step through its moveset.
##
## Enemy data (names, stats, action lists, behaviour notes) comes from the single
## source of truth Enemy.get_all_enemy_data(); the figure for each species mirrors
## Enemy._setup_sprite(). Generic tiers (Minion/Elite/Boss) have no bespoke model,
## so they are shown as their coloured battle box with the same animations.

const TitleMenuScene := "res://scenes/menus/title_menu.tscn"

# Mirrors Enemy._setup_sprite(): EnemyType -> EnemyFigure kind. Types absent here
# are generic tiers shown as a coloured box.
const KIND_BY_TYPE := {
	Enemy.EnemyType.WERERAT: "rat",
	Enemy.EnemyType.ARCHER_RAT: "archer_rat",
	Enemy.EnemyType.ARMORED_TROLL: "armored_troll",
	Enemy.EnemyType.SKELETON: "skeleton",
	Enemy.EnemyType.HYDRA: "hydra",
	Enemy.EnemyType.FIRE_GOBLIN_SOLDIER: "fire_goblin_soldier",
	Enemy.EnemyType.FIRE_GOBLIN_MAGE: "fire_goblin_mage",
	Enemy.EnemyType.FIRE_GOBLIN_SHAMAN: "fire_goblin_shaman",
	Enemy.EnemyType.GIANT_BEAVER: "giant_beaver",
	Enemy.EnemyType.MINI_BEAR: "mini_bear",
	Enemy.EnemyType.LARGE_BEAR: "large_bear",
	Enemy.EnemyType.WOLF: "wolf",
	Enemy.EnemyType.COYOTE: "coyote",
	Enemy.EnemyType.BUGBEAR: "bugbear",
	Enemy.EnemyType.INFECTED_HUNTER: "infected_hunter",
	Enemy.EnemyType.GIANT_HAWK: "giant_hawk",
	Enemy.EnemyType.TREANT: "treant",
	Enemy.EnemyType.ICE_MAGE: "ice_mage",
	Enemy.EnemyType.FIRE_MAGE: "fire_mage",
	Enemy.EnemyType.SPARK_MAGE: "spark_mage",
	Enemy.EnemyType.AIR_MAGE: "air_mage",
	Enemy.EnemyType.EARTH_MAGE: "earth_mage",
	Enemy.EnemyType.ZOMBIE: "zombie",
	Enemy.EnemyType.WEREWOLF: "werewolf",
	Enemy.EnemyType.WERERABBIT: "wererabbit",
	Enemy.EnemyType.VAMPIRE: "vampire",
	Enemy.EnemyType.NECROMANCER: "necromancer",
	Enemy.EnemyType.BONE_DRAGON: "bone_dragon",
	Enemy.EnemyType.SPIRIT_COLLECTOR: "spirit_collector",
	Enemy.EnemyType.GRAVE_TITAN: "grave_titan",
	Enemy.EnemyType.CRYPT_CRAWLER: "crypt_crawler",
	Enemy.EnemyType.SCREECHER: "screecher",
	Enemy.EnemyType.CONSUMED: "consumed",
	Enemy.EnemyType.SLUDGE: "sludge",
	Enemy.EnemyType.PIPE_CRAWLER: "pipe_crawler",
	Enemy.EnemyType.SEWER_CROC: "sewer_croc",
	Enemy.EnemyType.RAT_KING: "rat_king",
	Enemy.EnemyType.SWARM: "swarm",
}

# Coloured box fallback for the generic tiers (mirrors Enemy.initialize colours).
const COLOR_BY_TYPE := {
	Enemy.EnemyType.MINION: Color(0.8, 0.2, 0.2),
	Enemy.EnemyType.ELITE: Color(0.6, 0.1, 0.1),
	Enemy.EnemyType.BOSS: Color(0.4, 0.0, 0.2),
}

# Which list section each enemy belongs to, in display order.
const SECTIONS := [
	{"title": "GENERIC", "types": [Enemy.EnemyType.MINION, Enemy.EnemyType.ELITE, Enemy.EnemyType.BOSS]},
	{"title": "ACT I — HELL", "types": [
		Enemy.EnemyType.WERERAT, Enemy.EnemyType.SKELETON, Enemy.EnemyType.ARMORED_TROLL,
		Enemy.EnemyType.ARCHER_RAT, Enemy.EnemyType.HYDRA,
		Enemy.EnemyType.FIRE_GOBLIN_SOLDIER, Enemy.EnemyType.FIRE_GOBLIN_MAGE, Enemy.EnemyType.FIRE_GOBLIN_SHAMAN,
	]},
	{"title": "ACT II — FOREST", "types": [
		Enemy.EnemyType.GIANT_BEAVER, Enemy.EnemyType.MINI_BEAR, Enemy.EnemyType.LARGE_BEAR,
		Enemy.EnemyType.WOLF, Enemy.EnemyType.COYOTE, Enemy.EnemyType.BUGBEAR,
		Enemy.EnemyType.INFECTED_HUNTER, Enemy.EnemyType.GIANT_HAWK, Enemy.EnemyType.TREANT,
		Enemy.EnemyType.ICE_MAGE, Enemy.EnemyType.FIRE_MAGE, Enemy.EnemyType.SPARK_MAGE,
		Enemy.EnemyType.AIR_MAGE, Enemy.EnemyType.EARTH_MAGE,
	]},
	{"title": "GRAVEYARD", "types": [
		Enemy.EnemyType.ZOMBIE, Enemy.EnemyType.WEREWOLF, Enemy.EnemyType.WERERABBIT,
		Enemy.EnemyType.VAMPIRE, Enemy.EnemyType.NECROMANCER, Enemy.EnemyType.BONE_DRAGON,
		Enemy.EnemyType.SPIRIT_COLLECTOR, Enemy.EnemyType.GRAVE_TITAN, Enemy.EnemyType.CRYPT_CRAWLER,
		Enemy.EnemyType.SCREECHER, Enemy.EnemyType.CONSUMED,
	]},
	{"title": "SEWER", "types": [
		Enemy.EnemyType.SLUDGE, Enemy.EnemyType.PIPE_CRAWLER, Enemy.EnemyType.SEWER_CROC,
		Enemy.EnemyType.RAT_KING, Enemy.EnemyType.SWARM,
	]},
]

# Display action names (from get_all_enemy_data) that are movement rather than attacks.
const MOVE_ACTIONS := ["move", "scurry", "scurry away", "get into range", "flee", "hop", "drift"]

var _viewport: SubViewport = null
var _figure_root: Node3D = null       # holds the current figure/box; tweened for "move"
var _figure: EnemyFigure = null       # set for species with a bespoke model
var _box: MeshInstance3D = null       # set for generic tiers (coloured cube)
var _box_base_y: float = 0.35

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
var _box_busy: bool = false
var _time: float = 0.0


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

	# All figures/boxes live under this node so "move" can translate them without
	# fighting EnemyFigure's own internal idle bob (which moves a child node).
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
	_box = null
	_box_busy = false
	for child in _figure_root.get_children():
		child.queue_free()
	_figure_root.position = Vector3.ZERO
	_figure_root.rotation_degrees = Vector3.ZERO

	var kind: String = KIND_BY_TYPE.get(type, "")
	if kind != "":
		_figure = EnemyFigure.new()
		_figure_root.add_child(_figure)
		_figure.setup(kind)
	else:
		# Generic tier: coloured battle box.
		_box = MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.7, 0.7, 0.7)
		_box.mesh = b
		var mat := StandardMaterial3D.new()
		mat.albedo_color = COLOR_BY_TYPE.get(type, Color(0.7, 0.2, 0.2))
		_box.material_override = mat
		_box.position = Vector3(0, _box_base_y, 0)
		_figure_root.add_child(_box)


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
	elif _box:
		_box_lunge()


func _play_hit() -> void:
	if _figure:
		_figure.play_hit()
		_figure.flash(Color(1.0, 0.3, 0.3))
	elif _box:
		_box_recoil()


func _play_heal() -> void:
	if _figure:
		_figure.set_walking(false)
		_figure.flash(Color(0.5, 1.0, 0.5))
	elif _box:
		_box_flash(Color(0.5, 1.0, 0.5))


# ---- Generic box animations (mirror EnemyFigure's tween feel) ----

func _box_lunge() -> void:
	if _box == null or _box_busy:
		return
	_box_busy = true
	var dir := _facing_offset().normalized()
	var base := Vector3(0, _box_base_y, 0)
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(_box, "position", base + dir * 0.25, 0.09)
	tw.tween_property(_box, "position", base, 0.2)
	tw.tween_callback(func(): _box_busy = false)
	_box_flash(Color(1.0, 0.7, 0.3))


func _box_recoil() -> void:
	if _box == null or _box_busy:
		return
	_box_busy = true
	var dir := _facing_offset().normalized()
	var base := Vector3(0, _box_base_y, 0)
	var tw := create_tween().set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_box, "position", base - dir * 0.18, 0.07)
	tw.tween_property(_box, "position", base, 0.22)
	tw.tween_callback(func(): _box_busy = false)
	_box_flash(Color(1.0, 0.3, 0.3))


func _box_flash(color: Color) -> void:
	if _box == null:
		return
	var sm := _box.material_override as StandardMaterial3D
	if sm == null:
		return
	sm.emission_enabled = true
	sm.emission = color
	sm.emission_energy_multiplier = 1.1
	var tw := create_tween()
	tw.tween_property(sm, "emission_energy_multiplier", 0.0, 0.32)


# =============================================================
# FACING
# =============================================================

func _on_set_direction(dir: int) -> void:
	_current_dir = dir
	_apply_facing()


func _apply_facing() -> void:
	if _figure:
		_figure.set_facing(_current_dir)
	elif _box:
		match _current_dir:
			CharacterAnimator.Direction.SOUTH: _figure_root.rotation_degrees.y = 0.0
			CharacterAnimator.Direction.NORTH: _figure_root.rotation_degrees.y = 180.0
			CharacterAnimator.Direction.EAST: _figure_root.rotation_degrees.y = 90.0
			CharacterAnimator.Direction.WEST: _figure_root.rotation_degrees.y = -90.0


## World-space forward offset for the current facing. Figures are built facing +Z
## (south, toward the camera); the box rotates via _figure_root, so for it we move
## along +Z in its local frame, which _figure_root's rotation already accounts for.
func _facing_offset() -> Vector3:
	if _box:
		return Vector3(0, 0, 0.7)  # local +Z, _figure_root rotation handles facing
	match _current_dir:
		CharacterAnimator.Direction.NORTH: return Vector3(0, 0, -0.7)
		CharacterAnimator.Direction.EAST: return Vector3(0.7, 0, 0)
		CharacterAnimator.Direction.WEST: return Vector3(-0.7, 0, 0)
		_: return Vector3(0, 0, 0.7)  # SOUTH


# =============================================================
# IDLE BOB (generic box only — EnemyFigure bobs itself)
# =============================================================

func _process(delta: float) -> void:
	if _box == null or _box_busy:
		return
	_time += delta
	_box.position.y = _box_base_y + sin(_time * 2.0) * 0.02


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
