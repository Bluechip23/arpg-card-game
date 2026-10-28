class_name MarkableSummon
extends HealableSummon

## A summon Shepherd's Mark (Whispers of the Flock) can protect: survive one
## lethal blow at 1 HP with the mark's armor; the caster pays 8 HP. Only the
## wolves and specters carry these fields — Card._execute_shepherds_mark
## tests `"shepherd_mark_caster" in target` to decide who may be marked.

var last_attacker = null   # set by Enemy before it hits a summon

var armor: int = 0
var shepherd_mark_caster = null
var shepherd_mark_armor: int = 0
var shepherd_mark_tempo: int = 0

func tick_shepherd_mark(amount: int) -> void:
	if shepherd_mark_tempo > 0:
		shepherd_mark_tempo = maxi(0, shepherd_mark_tempo - amount)
		if shepherd_mark_tempo <= 0:
			shepherd_mark_caster = null
			shepherd_mark_armor = 0

func _absorb(amount: int) -> int:
	if armor > 0:
		var soaked: int = mini(armor, amount)
		armor -= soaked
		amount -= soaked
	return amount

func _survive_lethal() -> bool:
	if shepherd_mark_caster == null:
		return false
	# Shepherd's Mark: survive at 1 HP with the mark's armor; the caster pays.
	health = 1
	armor += shepherd_mark_armor
	var caster = shepherd_mark_caster
	shepherd_mark_caster = null
	shepherd_mark_armor = 0
	shepherd_mark_tempo = 0
	if caster and caster.has_method("take_direct_damage"):
		caster.take_direct_damage(8)
	print("[%s] Shepherd's Mark: survived at 1 HP" % display_name.to_upper())
	return true


func get_armor_display() -> Array:
	return [armor, 0]

func get_status_effects() -> Array:
	var out: Array = super.get_status_effects()
	if shepherd_mark_caster != null and shepherd_mark_tempo > 0:
		out.append({"name": "Shepherd's Mark", "color": Color(0.95, 0.85, 0.45), "stacks": shepherd_mark_tempo,
			"desc": "Survives one lethal blow at 1 HP with %d armor; the caster pays 8 HP. %d tempo left." % [shepherd_mark_armor, shepherd_mark_tempo]})
	return out
