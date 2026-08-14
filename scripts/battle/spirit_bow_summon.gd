extends Node3D

## Spirit bows of the Bow of Budding Blasts. One script, two lives:
##
## - The maintained Spirit Bow (is_bud = false): summoned by the Spirit Bow
##   card, lives while its 65 mana stays reserved. Stalks the nearest enemy
##   1 square per tempo and looses a 10-damage shot every 4 tempo.
## - A budded bow (is_bud = true): sprouts where the wielder stands when a
##   slotted card crits. Rooted in place, 6-damage shot every 5 tempo, dies
##   after 2 shots — or instantly to ANY source of damage.
##
## Both count as "bow instances" for the item's +2 damage / +5% crit stacking
## (main keeps PlayerStats.bow_instance_count current). This node owns
## visuals/health/movement; main.gd drives per-tempo decisions
## (_update_spirit_bows) via the cadence accumulators.

signal died(bow)

const SPIRIT_ATTACK := 10       # maintained spirit bow damage
const SPIRIT_ATTACK_INTERVAL := 4
const SPIRIT_MOVE_INTERVAL := 1 # 1 square per tempo
const SPIRIT_MOVE_STEPS := 1
const BUD_ATTACK := 6           # budded bow damage
const BUD_ATTACK_INTERVAL := 5
const ATTACK_RANGE := 6         # shot range in squares, both forms

var is_bud: bool = false
var attacks_left: int = -1      # buds: shots remaining before withering (-1 = unlimited)
var max_health: int = 20
var health: int = 20
var grid_manager: GridManager = null
var is_dead: bool = false
var move_accum: int = 0
var attack_accum: int = 0

var _target_position: Vector3 = Vector3.ZERO
var _is_moving: bool = false
var _health_label: Label3D = null

func setup(gm: GridManager, spawn_pos: Vector3, bud: bool) -> void:
	grid_manager = gm
	is_bud = bud
	position = Vector3(spawn_pos.x, 0.0, spawn_pos.z)
	_target_position = position
	if is_bud:
		# A bud is a fragile sprout: any damage kills it, two shots spend it.
		max_health = 1
		health = 1
		attacks_left = 2
	_build_visuals()
	_update_health_label()

func attack_interval() -> int:
	return BUD_ATTACK_INTERVAL if is_bud else SPIRIT_ATTACK_INTERVAL

func base_attack() -> int:
	return BUD_ATTACK if is_bud else SPIRIT_ATTACK

func _build_visuals() -> void:
	var slime := StandardMaterial3D.new()
	slime.albedo_color = Color(0.3, 0.65, 0.6, 0.85)  # sea-cucumber teal
	slime.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	slime.emission_enabled = true
	slime.emission = Color(0.15, 0.4, 0.38)
	var scale_mult := 0.6 if is_bud else 1.0
	# The limb: a torus segment reads as a drawn bow at billboard distance.
	var limb := MeshInstance3D.new()
	var limb_mesh := TorusMesh.new()
	limb_mesh.inner_radius = 0.22 * scale_mult
	limb_mesh.outer_radius = 0.3 * scale_mult
	limb.mesh = limb_mesh
	limb.material_override = slime
	limb.rotation_degrees = Vector3(0, 0, 90)
	limb.position = Vector3(0, 0.55 * scale_mult, 0)
	add_child(limb)
	# The string.
	var string := MeshInstance3D.new()
	var string_mesh := CylinderMesh.new()
	string_mesh.top_radius = 0.015
	string_mesh.bottom_radius = 0.015
	string_mesh.height = 0.55 * scale_mult
	string.mesh = string_mesh
	string.material_override = slime
	string.position = Vector3(0.12 * scale_mult, 0.55 * scale_mult, 0)
	add_child(string)
	_health_label = Label3D.new()
	_health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_label.font_size = 24
	_health_label.pixel_size = 0.005
	_health_label.position = Vector3(0, 1.0 * scale_mult + 0.2, 0)
	_health_label.modulate = Color(0.6, 0.9, 0.85)
	WorldText.crisp(_health_label)
	add_child(_health_label)

func _update_health_label() -> void:
	if not _health_label:
		return
	if is_bud:
		_health_label.text = "Bud %d shot%s" % [max(attacks_left, 0), "" if attacks_left == 1 else "s"]
	else:
		_health_label.text = "Spirit Bow %d/%d" % [max(health, 0), max_health]

func spend_attack() -> void:
	## Buds wither after their shots are spent; the spirit bow shoots forever.
	if attacks_left > 0:
		attacks_left -= 1
		_update_health_label()
		if attacks_left <= 0:
			die()

func _process(delta: float) -> void:
	if not _is_moving:
		return
	position.x = move_toward(position.x, _target_position.x, 4.0 * delta)
	position.z = move_toward(position.z, _target_position.z, 4.0 * delta)
	if abs(position.x - _target_position.x) < 0.01 and abs(position.z - _target_position.z) < 0.01:
		position.x = _target_position.x
		position.z = _target_position.z
		_is_moving = false

func get_cell() -> Vector2i:
	if grid_manager:
		return grid_manager.world_to_grid(position)
	return Vector2i.ZERO

func move_to_cell(cell: Vector2i) -> void:
	if not grid_manager or is_dead or is_bud:
		return  # buds are rooted where they sprouted
	var world = grid_manager.grid_to_world(cell)
	_target_position = Vector3(world.x, 0.0, world.z)
	_is_moving = true

func get_health_percent() -> float:
	return float(health) / float(max_health) if max_health > 0 else 0.0

func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	health = min(max_health, health + amount)
	_update_health_label()

func take_damage(amount: int) -> void:
	if is_dead:
		return
	# Any source of damage kills a bud instantly.
	health -= max_health if is_bud else amount
	_update_health_label()
	if health <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit(self)
	queue_free()
