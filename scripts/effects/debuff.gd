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
	COLD,
	BLIND,
	# Appended at the tail — enum order is save-compat-sensitive.
	GENERIC  # bespoke named debuff (Marvolo's Misunderstanding); keeps its custom name/description
}

var debuff_type: DebuffType
var debuff_name: String
var description: String
var value: int = 0           # The 'x' value (damage, reduction, etc.)
var duration: int = 0        # Tempo remaining (-1 for until cleansed)
var source_name: String = "" # What applied this debuff

# For tracking
var stacks: int = 1          # Some debuffs can stack
var affected_card_index: int = -1  # For Hexed/Locked - which card in hand is affected

func _init(type: DebuffType, val: int = 0, dur: int = 15) -> void:
	debuff_type = type
	value = val
	duration = dur
	_set_name_and_description()

## A bespoke named debuff whose name/description survive every refresh —
## mirrors Buff.create_generic (see the GENERIC pass below).
static func create_generic(nm: String, desc: String, val: int, dur: int, source: String = "") -> Debuff:
	var d := Debuff.new(DebuffType.GENERIC, val, dur)
	d.debuff_name = nm
	d.description = desc
	d.source_name = source
	return d

func _set_name_and_description() -> void:
	if debuff_type == DebuffType.GENERIC:
		return  # custom name/description are set by create_generic and never stomped
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
			description = "Burn damage doubles each cycle (1, 2, 4, 8...)"
		DebuffType.POISON:
			debuff_name = "Poison"
			description = "Take %d damage per cycle, lose 1 poison each cycle" % value
		DebuffType.INEBRIATE:
			debuff_name = "Inebriate"
			description = "Movement direction is randomized"
		DebuffType.CURSED:
			debuff_name = "Cursed"
			description = "Deal 20% less damage and deal 20% damage to self"
		DebuffType.FROZEN:
			debuff_name = "Frozen"
			description = "Cannot play cards"
		DebuffType.CUFFED:
			debuff_name = "Cuffed"
			description = "Cannot draw cards"
		DebuffType.SHOCKED:
			debuff_name = "Shocked"
			description = "Deal %d damage to nearby allies per cycle, lose 1 per cycle" % value
		DebuffType.SLOWED:
			debuff_name = "Slowed"
			description = "Lose %d movement per cycle" % value
		DebuffType.STAGGERED:
			debuff_name = "Staggered"
			description = "Attack cards cost %d more mana" % value
		DebuffType.DRAIN:
			debuff_name = "Drain"
			description = "Lose 10 mana per cycle, lose 1 drain per cycle"
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
			description = "Pulled %d tiles toward nearest enemy each cycle" % value
		DebuffType.LINKED:
			debuff_name = "Linked"
			description = "Share %d%% damage taken with nearest ally" % value
		DebuffType.CLUMSY:
			debuff_name = "Clumsy"
			description = "%d%% chance to discard random card when playing" % value
		DebuffType.VULNERABLE:
			debuff_name = "Vulnerable"
			description = "Take 30%% more damage on next %d attack(s)" % value
		DebuffType.BRITTLE:
			debuff_name = "Brittle"
			description = "Armor decays extra 2 per cycle, %d stack(s)" % value
		DebuffType.COLD:
			debuff_name = "Cold"
			description = "At 5 stacks, become Frozen for 1 turn. Current: %d stack(s)" % value
		DebuffType.BLIND:
			debuff_name = "Blind"
			description = "%d%% chance for your attacks to miss" % (value if value > 0 else 50)

func tick() -> bool:
	# Called each cycle (5 tempo). Returns true if debuff expired.
	# Negative duration = "until cleansed / stack-driven": never expires here.
	if duration < 0:
		return false
	if duration > 0:
		duration -= 5
	return duration <= 0

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
		DebuffType.BRITTLE: return Color(0.7, 0.7, 0.6)
		DebuffType.COLD: return Color(0.4, 0.7, 1.0)
		DebuffType.BLIND: return Color(0.85, 0.85, 0.4)
	return Color.WHITE

func get_short_display() -> String:
	if value > 0:
		return "%s(%d)" % [debuff_name, value]
	return debuff_name

static func create(type: DebuffType, val: int = 0, dur: int = 15) -> Debuff:
	return Debuff.new(type, val, dur)

static func create_slowed(movement_loss: int = 2, duration: int = 10, source: String = "") -> Debuff:
	var debuff = Debuff.new(DebuffType.SLOWED, movement_loss, duration)
	debuff.source_name = source
	return debuff
