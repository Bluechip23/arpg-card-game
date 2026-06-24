class_name DamageTypes
## Central damage-type registry for the combat system.
##
## Every point of damage carries a Type. Defenders can resist damage per-type
## (see PlayerStats.damage_resistances and the Resilient buff's damage_type).
## Nothing is required to specify a type yet — all damage defaults to PHYSICAL,
## so behaviour is unchanged until cards/attacks/enemies start tagging a type.

enum Type { PHYSICAL, FIRE, LIGHTNING, POISON, ICE, WIND }

## -1 is the "untyped / all types" sentinel used by resistances and buffs that
## should apply to every damage type (e.g. a generic Resilient).
const ALL: int = -1

static func type_name(t: int) -> String:
	match t:
		Type.PHYSICAL: return "Physical"
		Type.FIRE: return "Fire"
		Type.LIGHTNING: return "Lightning"
		Type.POISON: return "Poison"
		Type.ICE: return "Ice"
		Type.WIND: return "Wind"
	return "Physical"
