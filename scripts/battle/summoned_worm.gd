extends Summon

## An Alaskan Bull Worm summoned by Worm's Armageddon (10% proc).
##
## Stat block (per the card): 12 HP, 6 damage, burrowed until it attacks,
## untargetable while burrowed, 1 movement per tempo.
##
## This node owns only visuals/health/movement animation;
## main.gd drives the per-tempo decisions (_update_summoned_worms).

const MAX_HEALTH := 12
const CONTACT_DAMAGE := 6

var burrowed: bool = true  # Untargetable until it surfaces to attack

var _mound: MeshInstance3D = null
var _body: Node3D = null

func setup(gm: GridManager, spawn_pos: Vector3) -> void:
	_place(gm, spawn_pos)
	display_name = "Worm"
	glide_speed = 3.0
	max_health = MAX_HEALTH
	health = MAX_HEALTH
	_finish_setup()

func _build_visuals() -> void:
	# Burrowed state: a low mound of churned earth.
	_mound = MeshInstance3D.new()
	var mound_mesh := SphereMesh.new()
	mound_mesh.radius = 0.32
	mound_mesh.height = 0.24
	_mound.mesh = mound_mesh
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color(0.42, 0.30, 0.18)
	dirt.roughness = 1.0
	_mound.material_override = dirt
	_mound.position = Vector3(0, 0.08, 0)
	add_child(_mound)

	# Surfaced state: a pale segmented worm body (hidden until surface()).
	_body = Node3D.new()
	_body.visible = false
	add_child(_body)
	var pale := StandardMaterial3D.new()
	pale.albedo_color = Color(0.85, 0.78, 0.86)
	for i in range(4):
		var seg := MeshInstance3D.new()
		var seg_mesh := SphereMesh.new()
		var r := 0.26 - i * 0.03
		seg_mesh.radius = r
		seg_mesh.height = r * 2.0
		seg.mesh = seg_mesh
		seg.material_override = pale
		seg.position = Vector3(0, 0.25 + i * 0.34, 0)
		_body.add_child(seg)
	# Simple mouth ring on the top segment.
	var mouth := MeshInstance3D.new()
	var mouth_mesh := TorusMesh.new()
	mouth_mesh.inner_radius = 0.07
	mouth_mesh.outer_radius = 0.15
	mouth.mesh = mouth_mesh
	var maw := StandardMaterial3D.new()
	maw.albedo_color = Color(0.55, 0.15, 0.2)
	mouth.material_override = maw
	mouth.position = Vector3(0, 0.25 + 3 * 0.34 + 0.17, 0)
	_body.add_child(mouth)

	_build_health_label(1.7, Color(0.9, 0.85, 0.95), 28)

func surface() -> void:
	## The worm erupts from the ground to attack — from now on it is targetable.
	if not burrowed:
		return
	burrowed = false
	if _mound:
		_mound.visible = false
	if _body:
		_body.visible = true
	_update_health_label()

func _health_label_text() -> String:
	if burrowed:
		return "Worm (burrowed)"
	return "Worm %d/%d" % [max(health, 0), MAX_HEALTH]

func _can_be_hit() -> bool:
	return not burrowed  # Untargetable while burrowed
