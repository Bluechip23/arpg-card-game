class_name MythicReveal
extends Node3D

## The mythic loot ceremony. Looting a mythic doesn't just add it to the bag:
##  1. A big yellow glow bursts out of the player and expands as it travels.
##  2. Where the glow ends, a green present with a purple ribbon appears.
##  3. Clicking the present opens it: the mythic's icon rises out with flashy
##     coloration swirling around it.
##  4. Clicking the icon claims it — main stores it in the player's inventory.
signal claimed(item: ItemData)

const GLOW_RADIUS := 3.0        # tiles the glow expands before it ends
const GLOW_DURATION := 1.4      # seconds for the expansion
const PRESENT_CLICK_RADIUS := 1.2

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

func _ready() -> void:
	# The present lands where the glow ends: a random direction, GLOW_RADIUS out.
	var angle := randf() * TAU
	_present_offset = Vector3(cos(angle), 0, sin(angle)) * GLOW_RADIUS
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
	tw.tween_property(disc, "scale", Vector3(GLOW_RADIUS, 1, GLOW_RADIUS), GLOW_DURATION) \
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

	var green := Color(0.2, 0.7, 0.25)
	var purple := Color(0.55, 0.2, 0.8)
	_reveal_mesh(_present_root, _box(Vector3(0.42, 0.32, 0.42)), Vector3(0, 0.16, 0), green)
	# Ribbon: two straps crossing the box, and a bow on top.
	_reveal_mesh(_present_root, _box(Vector3(0.44, 0.34, 0.1)), Vector3(0, 0.16, 0), purple, true)
	_reveal_mesh(_present_root, _box(Vector3(0.1, 0.34, 0.44)), Vector3(0, 0.16, 0), purple, true)
	_reveal_mesh(_present_root, _sphere(0.07), Vector3(0, 0.36, 0), purple, true)
	# Lid seam so it reads as a present, not a crate.
	_reveal_mesh(_present_root, _box(Vector3(0.46, 0.05, 0.46)), Vector3(0, 0.28, 0), green.darkened(0.2))

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
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.pixel_size = 0.028  # 32px icon -> ~0.9 world units
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

func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s
