class_name MythicReveal
extends Node3D

## The mythic loot ceremony. Looting a mythic doesn't just add it to the bag:
##  1. A big yellow glow bursts out of the player and expands as it travels.
##  2. Where the glow ends, the designer's present (green, purple bow) appears —
##     in battle, on an open tile right beside the player (`land_at`).
##  3. Clicking the present opens it: the mythic's icon rises out with flashy
##     coloration swirling around it.
##  4. Clicking the icon claims it — main stores it in the player's inventory.
signal claimed(item: ItemData)

const GLOW_DURATION := 1.4      # seconds for the expansion
const PRESENT_CLICK_RADIUS := 1.2
const PRESENT_TEXTURE := "res://assets/textures/props/mythic_present.png"
const PRESENT_HEIGHT := 0.75      # world units, about three quarters of a tile
const ICON_SIZE := 0.9            # the mythic's art, whatever its pixel size

# Tunable per spawn (the Animation Lab shrinks and pins these to keep the
# present inside its preview camera's frame).
var glow_radius: float = 3.0    # tiles the glow expands before it ends
var fixed_angle: float = NAN    # radians; NAN = random direction

# Where the present lands, relative to the origin; set with land_at().
var _has_landing := false
var _landing := Vector3.ZERO

var item: ItemData = null
var state: String = "glow"      # "glow" -> "present" -> "icon" -> (freed)

var _present_root: Node3D = null
var _icon_root: Node3D = null
var _present_offset: Vector3 = Vector3.ZERO
var _sparkles: Array = []       # MeshInstance3D ring around the revealed icon
var _spin_t: float = 0.0

static func start(p_item: ItemData, origin: Vector3) -> MythicReveal:
	var r := MythicReveal.new()
	r.item = p_item
	r.position = origin
	return r

## Land the present at this offset from the origin (battle: the tile next to
## the player). The glow keeps its full glow_radius. Call before adding.
func land_at(offset: Vector3) -> void:
	_has_landing = true
	_landing = Vector3(offset.x, 0, offset.z)

func _ready() -> void:
	# The present lands where the glow ends: the chosen spot, or else
	# glow_radius out in fixed_angle's (or a random) direction.
	if _has_landing:
		_present_offset = _landing  # the glow still bursts its full radius
	else:
		var angle := fixed_angle if not is_nan(fixed_angle) else randf() * TAU
		_present_offset = Vector3(cos(angle), 0, sin(angle)) * glow_radius
	_run_glow()

## World position the player must click during "present"/"icon".
func click_position() -> Vector3:
	return global_position + _present_offset

## Advance the sequence if the click lands on the present/icon. Returns true
## when the click was consumed.
func try_click(world_pos: Vector3) -> bool:
	if state != "present" and state != "icon":
		return false
	var diff := world_pos - click_position()
	if Vector3(diff.x, 0, diff.z).length() > PRESENT_CLICK_RADIUS:
		return false
	if state == "present":
		_open_present()
	else:
		state = "claimed"
		claimed.emit(item)
		_pop_and_free()
	return true

# ---- Phase 1: the expanding glow -------------------------------------------

func _run_glow() -> void:
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.02
	disc.mesh = cyl
	disc.position = Vector3(0, 0.03, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.25, 0.75)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.2)
	mat.emission_energy_multiplier = 2.0
	mat.no_depth_test = true
	disc.material_override = mat
	disc.scale = Vector3(0.2, 1, 0.2)
	add_child(disc)
	var tw := create_tween()
	tw.tween_property(disc, "scale", Vector3(glow_radius, 1, glow_radius), GLOW_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, GLOW_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(disc.queue_free)
	tw.tween_callback(_spawn_present)

# ---- Phase 2: the present ----------------------------------------------------

func _spawn_present() -> void:
	state = "present"
	_present_root = Node3D.new()
	_present_root.position = _present_offset
	add_child(_present_root)

	# The designer's present (tools/cut_mythic_present.py, 2026-10-31): a
	# green box with a gold-edged purple bow, standing on the tile.
	var tex: Texture2D = load(PRESENT_TEXTURE)
	var box := Sprite3D.new()
	box.name = "Present"
	box.texture = tex
	box.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	box.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	box.pixel_size = PRESENT_HEIGHT / float(tex.get_height())
	box.offset = Vector2(0, tex.get_height() * 0.5)   # stands on the tile
	box.no_depth_test = true
	_present_root.add_child(box)

	# Arrive with a pop, then bob gently until clicked.
	_present_root.scale = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(_present_root, "scale", Vector3.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var bob := create_tween().set_loops()
	bob.tween_property(_present_root, "position:y", 0.08, 0.7).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_present_root, "position:y", 0.0, 0.7).set_trans(Tween.TRANS_SINE)
	_present_root.set_meta("bob", bob)

# ---- Phase 3: the icon -------------------------------------------------------

func _open_present() -> void:
	state = "icon"
	var bob = _present_root.get_meta("bob") if _present_root.has_meta("bob") else null
	if bob is Tween and bob.is_valid():
		bob.kill()
	var out := create_tween()
	out.tween_property(_present_root, "scale", Vector3.ZERO, 0.2).set_ease(Tween.EASE_IN)
	out.tween_callback(_present_root.queue_free)
	out.tween_callback(_spawn_icon)

func _spawn_icon() -> void:
	_icon_root = Node3D.new()
	_icon_root.position = _present_offset + Vector3(0, 0.7, 0)
	add_child(_icon_root)

	var tex: Texture2D = item.get_appearance_texture() if item else null
	if tex:
		var sprite := Sprite3D.new()
		sprite.texture = tex
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		# ICON_SIZE across whatever the art's size (the mythics are 128px
		# paintings now; 0.028 a pixel was for the old 32px icons and blew the
		# painted ones up four times over).
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.pixel_size = ICON_SIZE / float(maxi(tex.get_width(), tex.get_height()))
		sprite.no_depth_test = true
		_icon_root.add_child(sprite)
	else:
		# No icon authored yet: a golden gem stands in.
		_reveal_mesh(_icon_root, _sphere(0.22), Vector3.ZERO, Color(1.0, 0.8, 0.2), true)

	# Mildly flashy coloration: a ring of hue-cycling sparks orbiting the icon.
	_sparkles.clear()
	for i in range(6):
		var s := _reveal_mesh(_icon_root, _sphere(0.045), Vector3.ZERO, Color(1, 1, 1), true)
		_sparkles.append(s)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.4)
	light.omni_range = 3.0
	light.light_energy = 1.4
	_icon_root.add_child(light)

	_icon_root.scale = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(_icon_root, "scale", Vector3.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if state != "icon" or _icon_root == null:
		return
	_spin_t += delta
	for i in range(_sparkles.size()):
		var s: MeshInstance3D = _sparkles[i]
		if not is_instance_valid(s):
			continue
		var a: float = _spin_t * 1.8 + TAU * i / _sparkles.size()
		s.position = Vector3(cos(a) * 0.55, sin(_spin_t * 2.4 + i) * 0.18, sin(a) * 0.55)
		var mat := s.material_override as StandardMaterial3D
		var hue: float = fmod(_spin_t * 0.35 + float(i) / _sparkles.size(), 1.0)
		var c := Color.from_hsv(hue, 0.75, 1.0)
		mat.albedo_color = c
		mat.emission = c

func _pop_and_free() -> void:
	if _icon_root and is_instance_valid(_icon_root):
		var tw := create_tween()
		tw.tween_property(_icon_root, "position:y", _icon_root.position.y + 0.6, 0.22).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_icon_root, "scale", Vector3.ZERO, 0.22).set_ease(Tween.EASE_IN)
		tw.tween_callback(queue_free)
	else:
		queue_free()

# ---- Mesh helpers --------------------------------------------------------------

func _reveal_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, emissive := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.5
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.0
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s
