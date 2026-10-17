extends HealableSummon

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

const SPIRIT_ATTACK := 10       # maintained spirit bow damage
const SPIRIT_ATTACK_INTERVAL := 4
const SPIRIT_MOVE_INTERVAL := 1 # 1 square per tempo
const BUD_ATTACK := 6           # budded bow damage
const BUD_ATTACK_INTERVAL := 5
const ATTACK_RANGE := 6         # shot range in squares, both forms

var is_bud: bool = false
var attacks_left: int = -1      # buds: shots remaining before withering (-1 = unlimited)

func setup(gm: GridManager, spawn_pos: Vector3, bud: bool) -> void:
	_place(gm, spawn_pos)
	is_bud = bud
	max_health = 20
	health = 20
	if is_bud:
		# A bud is a fragile sprout: any damage kills it, two shots spend it.
		max_health = 1
		health = 1
		attacks_left = 2
	_finish_setup()

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
	_build_health_label(1.0 * scale_mult + 0.2, Color(0.6, 0.9, 0.85))

func _health_label_text() -> String:
	if is_bud:
		return "Bud %d shot%s" % [max(attacks_left, 0), "" if attacks_left == 1 else "s"]
	return "Spirit Bow %d/%d" % [max(health, 0), max_health]

func spend_attack() -> void:
	## Buds wither after their shots are spent; the spirit bow shoots forever.
	if attacks_left > 0:
		attacks_left -= 1
		_update_health_label()
		if attacks_left <= 0:
			die()

func move_to_cell(cell: Vector2i) -> void:
	if is_bud:
		return  # buds are rooted where they sprouted
	super(cell)

func take_damage(amount: int) -> void:
	if is_dead:
		return
	# Cover: a defender within 2 squares soaks the hit by their hand size.
	# (A hit Cover fully soaks never lands — not even on a bud.)
	var incoming := amount
	amount = PlayerStats.apply_cover(self, amount)
	if amount <= 0 and incoming > 0:
		return
	# Any source of damage kills a bud instantly.
	health -= max_health if is_bud else amount
	_update_health_label()
	if health <= 0:
		die()
