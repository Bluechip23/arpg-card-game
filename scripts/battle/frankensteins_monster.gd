extends HealableSummon

## Frankensteins Monster — summoned by the "ITS ALIVE!!!!!" card granted by
## Frankensteins Screws (helm). A corpse is stitched back together into a
## lumbering ally that hunts the nearest enemy.
##
## Stat block (per the item), all scaling off the summoner's INT at spawn:
##   HP        = 50 + INT * 0.8
##   attack    = 10 + INT * 0.25   (every 5 tempo, when adjacent)
##   movement  = 4 spaces every 8 tempo
##   resist    = 5 + INT / 10  (%) against ALL incoming damage
##
## This node owns visuals/health/movement animation; main.gd drives the
## per-tempo decisions (_update_frankensteins) using the cadence counters.

var attack_damage: int = 10
var resist_percent: float = 5.0

const MOVE_INTERVAL := 8      # tempo between moves
const MOVE_STEPS := 4         # tiles per move
const ATTACK_INTERVAL := 5    # tempo between attacks

var _body: Node3D = null

func setup(gm: GridManager, spawn_pos: Vector3, summoner_int: int) -> void:
	_place(gm, spawn_pos)
	display_name = "Frankensteins Monster"
	glide_speed = 3.0
	max_health = 50 + int(summoner_int * 0.8)
	health = max_health
	attack_damage = 10 + int(summoner_int * 0.25)
	resist_percent = 5.0 + summoner_int / 10.0
	_finish_setup()

func _build_visuals() -> void:
	_body = Node3D.new()
	add_child(_body)
	var flesh := StandardMaterial3D.new()
	flesh.albedo_color = Color(0.45, 0.6, 0.4)  # stitched green
	flesh.roughness = 1.0
	# Torso
	var torso := MeshInstance3D.new()
	var torso_mesh := BoxMesh.new()
	torso_mesh.size = Vector3(0.55, 0.8, 0.4)
	torso.mesh = torso_mesh
	torso.material_override = flesh
	torso.position = Vector3(0, 0.7, 0)
	_body.add_child(torso)
	# Head
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.4, 0.4, 0.4)
	head.mesh = head_mesh
	head.material_override = flesh
	head.position = Vector3(0, 1.32, 0)
	_body.add_child(head)
	# Neck bolts
	var bolt_mat := StandardMaterial3D.new()
	bolt_mat.albedo_color = Color(0.7, 0.7, 0.5)
	bolt_mat.metallic = 0.8
	for sx in [-1.0, 1.0]:
		var bolt := MeshInstance3D.new()
		var bolt_mesh := CylinderMesh.new()
		bolt_mesh.top_radius = 0.06
		bolt_mesh.bottom_radius = 0.06
		bolt_mesh.height = 0.18
		bolt.mesh = bolt_mesh
		bolt.material_override = bolt_mat
		bolt.rotation_degrees = Vector3(0, 0, 90)
		bolt.position = Vector3(0.22 * sx, 1.1, 0)
		_body.add_child(bolt)

	_build_health_label(1.9, Color(0.6, 0.9, 0.6), 28)

func _absorb(amount: int) -> int:
	# Resist everything: reduce the incoming amount by resist_percent.
	return maxi(1, floori(amount * (1.0 - minf(resist_percent, 90.0) / 100.0)))
