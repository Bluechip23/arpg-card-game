extends MarkableSummon

## Specter summoned by Jeremy's Seance: a spell cast at an empty tile raises
## one there for 25 tempo. It cannot act — it stands, soaks attention, and
## when an enemy destroys it, its HP comes back out as damage on the killer.
## Enemies treat it as an ordinary summon (main lists it in
## EnemySpawner.summons), so it is targeted by proximity like a wolf.
##
## This node owns visuals/health/lifetime; main.gd ticks it per tempo
## (_update_specters) and pays out the death damage.

signal specter_died(specter, killed: bool)

const LIFETIME_TEMPO := 25

var death_damage: int = 5
var tempo_remaining: int = LIFETIME_TEMPO

func setup(gm: GridManager, spawn_pos: Vector3, hp: int) -> void:
	_place(gm, spawn_pos)
	display_name = "Specter"
	max_health = maxi(1, hp)
	health = max_health
	death_damage = max_health
	_finish_setup()

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
	_build_health_label(1.3, Color(0.85, 0.7, 1.0))

func _health_label_text() -> String:
	var armor_txt := " +%d" % armor if armor > 0 else ""
	return "Specter %d/%d%s" % [max(health, 0), max_health, armor_txt]

## Lifetime and the mark run on raw tempo (main calls this every tick).
func tick(amount: int) -> void:
	if is_dead:
		return
	tick_shepherd_mark(amount)
	tempo_remaining -= amount
	if tempo_remaining <= 0:
		die(false)

## killed: destroyed by an enemy (its killer takes death_damage) rather than
## faded out at the end of its lifetime.
func die(killed: bool = true) -> void:
	if is_dead:
		return
	is_dead = true
	died.emit(self)
	specter_died.emit(self, killed)
	queue_free()
