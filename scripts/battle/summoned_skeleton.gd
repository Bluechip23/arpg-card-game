extends HealableSummon

## Summoned melee ally: the Sack of Bone Arrows skeleton, the manifest summons
## (skeleton / spirit / golem), and the summon cards (designer, 2026-10-27):
## Summon Skeleton / Skeleton Army ("card_skeleton"), Summon Shadow Hound
## ("shadow_hound") and Summon Battle Turtle / Turtle Power ("battle_turtle").
## They all share one brain, main._update_skeletons.
##
## Base stat block (skeleton, per the item): hits for 5, moves 4 spaces every
## tempo, attacks every 5 tempo. Spirits are fast and fragile; golems slow and
## tanky (see setup). The item and manifest summons cap at 3 standing at once;
## card summons don't count toward that cap (Skeleton Army raises 4).
##
## This node owns visuals/health/movement; main.gd drives per-tempo decisions
## (_update_skeletons) via the cadence accumulators.

# Per-kind cadence knobs — skeleton defaults; setup() retunes for the kind.
var base_attack := 5      # damage per hit (0: never attacks — the Battle Turtle)
var move_interval := 1    # tempo between moves
var move_steps := 4       # tiles per move
var attack_interval := 5  # tempo between attacks
var kind := "skeleton"
var from_card := false    # raised by a summon card: outside the 3-summon cap

# Battle Turtle: armor taken before health, capped by its unerring armor
# (summoner INT / 2). It starts full and regains a fifth of the cap every
# ARMOR_REGAIN_INTERVAL tempo, never past the cap (main drives it).
const ARMOR_REGAIN_INTERVAL := 5
var unerring_cap := 0      # the most armor it can hold
var unerring_armor := 0    # what it holds now
var armor_accum := 0

## `summoner_int` sets what scales with the caster: the turtle's armor cap
## (INT / 2) and the hound's bite cadence (8 - INT / 10 tempo, at least 1).
func setup(gm: GridManager, spawn_pos: Vector3, hp: int, summon_kind := "skeleton", summoner_int := 0) -> void:
	_place(gm, spawn_pos)
	glide_speed = 4.5
	kind = summon_kind
	match kind:
		"spirit":
			# Fast and fragile: weaker hits, quicker cadence, longer strides.
			display_name = "Spirit"
			base_attack = 3
			attack_interval = 3
			move_steps = 5
		"golem":
			# Slow and tanky: heavy hits on a long wind-up, short strides.
			display_name = "Golem"
			base_attack = 8
			attack_interval = 8
			move_steps = 2
		"card_skeleton":
			# Summon Skeleton: 1 space every tempo, 6 damage every 5 tempo.
			display_name = "Skeleton"
			base_attack = 6
			attack_interval = 5
			move_steps = 1
			from_card = true
		"shadow_hound":
			# Summon Shadow Hound: 2 spaces every tempo, 4 damage every
			# (8 - INT/10) tempo.
			display_name = "Shadow Hound"
			base_attack = 4
			attack_interval = maxi(1, 8 - int(summoner_int / 10))
			move_steps = 2
			from_card = true
		"battle_turtle":
			# Summon Battle Turtle: 1 space every tempo, no attack; unerring
			# armor INT / 2, regained over time (main._regain_turtle_armor).
			display_name = "Battle Turtle"
			base_attack = 0
			move_steps = 1
			unerring_cap = int(summoner_int / 2)
			unerring_armor = unerring_cap
			from_card = true
		_:
			display_name = "Skeleton"
	max_health = maxi(1, hp)
	health = max_health
	_finish_setup()

func _build_visuals() -> void:
	match kind:
		"spirit":
			_build_figure("specter")         # the Craftpix ghost
		"golem":
			_build_figure("summon_golem")    # the Craftpix rock golem, ally-sized
		"shadow_hound":
			_build_figure("shadow_hound")    # stand-in until its board: the wolf, shadowed
		"battle_turtle":
			_build_figure("battle_turtle")   # the designer's board (2026-10-28)
		_:
			_build_figure("summon_skeleton") # the designer's summon skeleton board (2026-10-27)
	_build_health_label(1.7, Color(0.85, 0.9, 0.8))

## Battle Turtle: the armor soaks the hit first.
func _absorb(amount: int) -> int:
	if unerring_armor <= 0:
		return amount
	var soaked := mini(unerring_armor, amount)
	unerring_armor -= soaked
	return amount - soaked

func _health_label_text() -> String:
	var t := super._health_label_text()
	if kind == "battle_turtle":
		t += "  [%d/%d]" % [unerring_armor, unerring_cap]
	return t

## The armor a Battle Turtle regains each interval: a fifth of its cap
## (at least 1 while it has a cap).
func armor_regain() -> int:
	return maxi(1, int(unerring_cap / 5)) if unerring_cap > 0 else 0

## Battle Turtle: add armor up to the cap (its regain, or an ally turtle's
## passive). Returns what it actually gained.
func gain_armor(amount: int) -> int:
	if amount <= 0 or is_dead:
		return 0
	var gained := mini(amount, unerring_cap - unerring_armor)
	if gained <= 0:
		return 0
	unerring_armor += gained
	_update_health_label()
	return gained
