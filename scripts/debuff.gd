class_name Debuff
extends RefCounted

## Represents a debuff/status effect on a character

enum DebuffType {
	BLEED,
	STUN,
	DISARM,
	SILENCE,
	BURN,
	POISON,
	INEBRIATE,
	CURSED,
	FROZEN,
	CUFFED,
	SHOCKED,
	SLOWED,
	STAGGERED,
	DRAIN,
	WEIGHTED,
	HEXED,
	LOCKED,
	ROOTED,
	CLUMSY,
	TETHERED,
	MAGNETIZED,
	VULNERABLE,
	LINKED,
	BRITTLE,
	EXPOSED
}

var debuff_type: DebuffType
var debuff_name: String
var description: String
var value: int = 0           # The 'x' value (damage, reduction, etc.)
var duration: int = 0        # Turns remaining (-1 for until cleansed)
var source_name: String = "" # What applied this debuff

# For tracking
var stacks: int = 1          # Some debuffs can stack

func _init(type: DebuffType, val: int = 0, dur: int = 3) -> void:
	debuff_type = type
	value = val
	duration = dur
	_set_name_and_description()

func _set_name_and_description() -> void:
	match debuff_type:
		DebuffType.BLEED:
			debuff_name = "Bleed"
			description = "On movement: take %d damage" % value
		DebuffType.STUN:
			debuff_name = "Stun"
			description = "Cannot take any actions"
		DebuffType.DISARM:
			debuff_name = "Disarm"
			description = "Cannot play attack cards"
		DebuffType.SILENCE:
			debuff_name = "Silence"
			description = "Cannot play spell cards"
		DebuffType.BURN:
			debuff_name = "Burn"
			description = "Take %d damage per turn and on attack" % value
		DebuffType.POISON:
			debuff_name = "Poison"
			description = "Take %d damage per turn, -%d damage dealt" % [value, value]
		DebuffType.INEBRIATE:
			debuff_name = "Inebriate"
			description = "Movement direction is randomized"
		DebuffType.CURSED:
			debuff_name = "Cursed"
			description = "Deal %d less damage, deal %d%% damage to self" % [value, value * 10]
		DebuffType.FROZEN:
			debuff_name = "Frozen"
			description = "Cannot play cards"
		DebuffType.CUFFED:
			debuff_name = "Cuffed"
			description = "Cannot draw cards"
		DebuffType.SHOCKED:
			debuff_name = "Shocked"
			description = "Deal %d damage to nearby allies per turn" % value
		DebuffType.SLOWED:
			debuff_name = "Slowed"
			description = "Lose %d movement per turn" % value
		DebuffType.STAGGERED:
			debuff_name = "Staggered"
			description = "Attack cards cost %d more mana" % value
		DebuffType.DRAIN:
			debuff_name = "Drain"
			description = "Lose %d mana per turn" % value
		DebuffType.WEIGHTED:
			debuff_name = "Weighted"
			description = "Cards cost %d more tempo" % value
		DebuffType.HEXED:
			debuff_name = "Hexed"
			description = "One random card costs +%d mana" % value
		DebuffType.LOCKED:
			debuff_name = "Locked"
			description = "One random card cannot be played"
		DebuffType.ROOTED:
			debuff_name = "Rooted"
			description = "Cannot move"
		DebuffType.TETHERED:
			debuff_name = "Tethered"
			description = "Cannot move more than %d tiles from start" % value
		DebuffType.MAGNETIZED:
			debuff_name = "Magnetized"
			description = "Pulled %d tiles toward nearest enemy each turn" % value
		DebuffType.LINKED:
			debuff_name = "Linked"
			description = "Share %d%% damage taken with nearest ally" % value
		DebuffType.CLUMSY:
			debuff_name = "Clumsy"
			description = "%d%% chance to discard random card when playing" % value
		DebuffType.VULNERABLE:
			debuff_name = "Vulnerable"
			description = "Take %d%% more damage" % value
		DebuffType.EXPOSED:
			debuff_name = "Exposed"
			description = "Armor effectiveness reduced by %d%%" % value
		DebuffType.BRITTLE:
			debuff_name = "Brittle"
			description = "Armor decays %d additional per turn" % value

func tick() -> bool:
	# Called each turn. Returns true if debuff expired.
	if duration > 0:
		duration -= 1
	return duration == 0

func get_icon_color() -> Color:
	match debuff_type:
		DebuffType.BLEED: return Color(0.8, 0.1, 0.1)
		DebuffType.STUN: return Color(1.0, 1.0, 0.0)
		DebuffType.DISARM: return Color(0.6, 0.3, 0.1)
		DebuffType.SILENCE: return Color(0.5, 0.0, 0.8)
		DebuffType.BURN: return Color(1.0, 0.5, 0.0)
		DebuffType.POISON: return Color(0.2, 0.8, 0.2)
		DebuffType.INEBRIATE: return Color(0.8, 0.4, 0.8)
		DebuffType.CURSED: return Color(0.3, 0.0, 0.3)
		DebuffType.FROZEN: return Color(0.5, 0.8, 1.0)
		DebuffType.CUFFED: return Color(0.5, 0.5, 0.5)
		DebuffType.SHOCKED: return Color(1.0, 1.0, 0.3)
		DebuffType.SLOWED: return Color(0.3, 0.3, 0.6)
		DebuffType.STAGGERED: return Color(0.6, 0.4, 0.2)
		DebuffType.DRAIN: return Color(0.4, 0.0, 0.6)
		DebuffType.WEIGHTED: return Color(0.4, 0.4, 0.4)
		# New debuffs
		DebuffType.HEXED: return Color(0.6, 0.0, 0.6)
		DebuffType.LOCKED: return Color(0.3, 0.3, 0.3)
		DebuffType.ROOTED: return Color(0.4, 0.25, 0.1)
		DebuffType.TETHERED: return Color(0.7, 0.7, 0.2)
		DebuffType.MAGNETIZED: return Color(0.2, 0.2, 0.8)
		DebuffType.LINKED: return Color(0.8, 0.4, 0.4)
		DebuffType.CLUMSY: return Color(0.9, 0.6, 0.2)
		DebuffType.VULNERABLE: return Color(1.0, 0.3, 0.3)
		DebuffType.EXPOSED: return Color(0.9, 0.7, 0.5)
		DebuffType.BRITTLE: return Color(0.7, 0.7, 0.6)
	return Color.WHITE

func get_short_display() -> String:
	if value > 0:
		return "%s(%d)" % [debuff_name, value]
	return debuff_name

static func create(type: DebuffType, val: int = 0, dur: int = 3) -> Debuff:
	return Debuff.new(type, val, dur)
