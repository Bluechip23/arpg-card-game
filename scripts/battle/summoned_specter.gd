extends Node3D

## Specter summoned by Jeremy's Seance: a spell cast at an empty tile raises
## one there for 25 tempo. It cannot act — it stands, soaks attention, and
## when an enemy destroys it, its HP comes back out as damage on the killer.
## Enemies treat it as an ordinary summon (main lists it in
## EnemySpawner.summons), so it is targeted by proximity like a wolf.
##
## This node owns visuals/health/lifetime; main.gd ticks it per tempo
## (_update_specters) and pays out the death damage.

signal died(specter, killed: bool)

const LIFETIME_TEMPO := 25

var max_health: int = 5
var health: int = 5
var death_damage: int = 5
var tempo_remaining: int = LIFETIME_TEMPO
var grid_manager: GridManager = null
var is_dead: bool = false
var last_attacker = null   # set by Enemy before it hits a summon

# Shepherd's Mark on a summon (Whispers of the Flock): survive one lethal
# blow at 1 HP with the mark's armor; the caster pays 8 HP.
var armor: int = 0
var shepherd_mark_caster = null
var shepherd_mark_armor: int = 0
var shepherd_mark_tempo: int = 0

var _health_label: Label3D = null

func setup(gm: GridManager, spawn_pos: Vector3, hp: int) -> void:
	grid_manager = gm
	max_health = maxi(1, hp)
	health = max_health
	death_damage = max_health
	position = Vector3(spawn_pos.x, 0.0, spawn_pos.z)
	_build_visuals()
	_update_health_label()

func _build_visuals() -> void:
	var shade := StandardMaterial3D.new()
	shade.albedo_color = Color(0.7, 0.5, 1.0, 0.55)
	shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shade.emission_enabled = true
	shade.emission = Color(0.5, 0.3, 0.9)
	shade.emission_energy_multiplier = 0.6
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.2
	mesh.height = 0.9
	body.mesh = mesh
	body.material_override = shade
	body.position = Vector3(0, 0.55, 0)
	add_child(body)
	_health_label = Label3D.new()
	_health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_label.font_size = 24
	_health_label.pixel_size = 0.005
	_health_label.position = Vector3(0, 1.3, 0)
	_health_label.modulate = Color(0.85, 0.7, 1.0)
	WorldText.crisp(_health_label)
	add_child(_health_label)

func _update_health_label() -> void:
	if _health_label:
		var armor_txt := " +%d" % armor if armor > 0 else ""
		_health_label.text = "Specter %d/%d%s" % [max(health, 0), max_health, armor_txt]

func get_cell() -> Vector2i:
	if grid_manager:
		return grid_manager.world_to_grid(position)
	return Vector2i.ZERO

func get_health_percent() -> float:
	return float(health) / float(max_health) if max_health > 0 else 0.0

## Lifetime and the mark run on raw tempo (main calls this every tick).
func tick(amount: int) -> void:
	if is_dead:
		return
	tick_shepherd_mark(amount)
	tempo_remaining -= amount
	if tempo_remaining <= 0:
		die(false)

func tick_shepherd_mark(amount: int) -> void:
	if shepherd_mark_tempo > 0:
		shepherd_mark_tempo = maxi(0, shepherd_mark_tempo - amount)
		if shepherd_mark_tempo <= 0:
			shepherd_mark_caster = null
			shepherd_mark_armor = 0

func heal(amount: int) -> void:
	if PlayerStats.heal_to_damage and amount > 0:
		take_damage(amount)  # Poisoned Blood: the heal lands as damage
		return
	if is_dead or amount <= 0:
		return
	health = min(max_health, health + amount)
	_update_health_label()

func take_damage(amount: int) -> void:
	if is_dead:
		return
	# Cover: a defender within 2 squares soaks the hit by their hand size.
	amount = PlayerStats.apply_cover(self, amount)
	if amount <= 0:
		return
	if armor > 0:
		var soaked: int = mini(armor, amount)
		armor -= soaked
		amount -= soaked
	health -= amount
	if health <= 0 and shepherd_mark_caster != null:
		# Shepherd's Mark: survive at 1 HP with the mark's armor; the caster pays.
		health = 1
		armor += shepherd_mark_armor
		var caster = shepherd_mark_caster
		shepherd_mark_caster = null
		shepherd_mark_armor = 0
		shepherd_mark_tempo = 0
		if caster and caster.has_method("take_direct_damage"):
			caster.take_direct_damage(8)
		print("[SPECTER] Shepherd's Mark: survived at 1 HP")
	_update_health_label()
	if health <= 0:
		die(true)

func die(killed: bool) -> void:
	if is_dead:
		return
	is_dead = true
	died.emit(self, killed)
	queue_free()
