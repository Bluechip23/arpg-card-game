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
	INEBRIATE,  # retired (nothing applies it); slot kept for enum-order compat
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
	TETHERED,  # retired (nothing applies it); slot kept for enum-order compat
	MAGNETIZED,  # retired (nothing applies it); slot kept for enum-order compat
	VULNERABLE,
	LINKED,  # retired (nothing applies it); slot kept for enum-order compat
	BRITTLE,
	COLD,
	BLIND,
	# Appended at the tail — enum order is save-compat-sensitive.
	GENERIC,  # bespoke named debuff (Marvolo's Misunderstanding); keeps its custom name/description
	WEAKENED  # deal WEAKENED_REDUCTION% less damage; 1 stack burns per attack (mirrors enemy-side Weaken)
}

# Fixed magnitudes for the stack-driven debuffs: the stack COUNT is the only
# per-application knob; how hard each stack hits is a constant. First-pass
# numbers — balance later.
const SLOWED_TEMPO_PER_TILE := 3   # slowed movement costs this much tempo per tile (normally 1)
const STAGGERED_MANA := 15         # extra mana per attack card while staggered
const WEIGHTED_TEMPO := 2          # extra tempo per card while weighted
const CLUMSY_CHANCE := 30          # % chance to discard on card play
const BLIND_MISS := 80             # % chance for attacks to miss
const WEAKENED_REDUCTION := 30     # % less damage dealt while Weakened (matches the enemy-side Weaken)

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
			description = "Take 1 damage per tile moved; each damage removes a stack (%d left)" % value
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
			description = "Burn damage doubles each cycle (1, 2, 4, 8...); attacking also triggers the current burn damage"
		DebuffType.POISON:
			debuff_name = "Poison"
			description = "Take %d damage per cycle, lose 1 poison each cycle" % value
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
			description = "Arc %d damage to nearby allies per cycle (a shocked enemy takes it itself), lose 1 per cycle" % value
		DebuffType.SLOWED:
			debuff_name = "Slowed"
			description = "Movement costs %d tempo per tile; each tile burns a stack (%d left)" % [SLOWED_TEMPO_PER_TILE, value]
		DebuffType.STAGGERED:
			debuff_name = "Staggered"
			description = "Attack cards cost %d more mana; each attack card burns a stack (%d left)" % [STAGGERED_MANA, value]
		DebuffType.DRAIN:
			debuff_name = "Drain"
			description = "Lose 10 mana per cycle, lose 1 drain per cycle"
		DebuffType.WEIGHTED:
			debuff_name = "Weighted"
			description = "Cards cost %d more tempo; each card played burns a stack (%d left)" % [WEIGHTED_TEMPO, value]
		DebuffType.HEXED:
			debuff_name = "Hexed"
			description = "One card in your hand costs +%d mana until it is played" % value
		DebuffType.LOCKED:
			debuff_name = "Locked"
			description = "One random card cannot be played"
		DebuffType.ROOTED:
			debuff_name = "Rooted"
			description = "Cannot move"
		DebuffType.CLUMSY:
			debuff_name = "Clumsy"
			description = "%d%% chance to discard a random card when playing; each card burns a stack (%d left)" % [CLUMSY_CHANCE, value]
		DebuffType.VULNERABLE:
			debuff_name = "Vulnerable"
			description = "Take 30%% more damage on next %d attack(s)" % value
		DebuffType.BRITTLE:
			debuff_name = "Brittle"
			description = "Armor decays extra 2 per cycle, %d stack(s)" % value
		DebuffType.COLD:
			debuff_name = "Cold"
			description = "At 5 stacks, become Frozen for 1 cycle. Current: %d stack(s)" % value
		DebuffType.BLIND:
			debuff_name = "Blind"
			description = "%d%% chance for your attacks to miss" % (value if value > 0 else BLIND_MISS)
		DebuffType.WEAKENED:
			debuff_name = "Weakened"
			description = "Deal %d%% less damage; each attack burns a stack (%d left)" % [WEAKENED_REDUCTION, value]

func advance_time(amount: int) -> bool:
	# Duration counts RAW tempo, decremented on every tempo advance — so a
	# 3-tempo stun works. Negative duration = "until cleansed / stack-driven":
	# never expires here. Returns true when expired.
	if duration < 0:
		return false
	duration -= amount
	return duration <= 0

func get_icon_color() -> Color:
	match debuff_type:
		DebuffType.BLEED: return Color(0.8, 0.1, 0.1)
		DebuffType.STUN: return Color(1.0, 1.0, 0.0)
		DebuffType.DISARM: return Color(0.6, 0.3, 0.1)
		DebuffType.SILENCE: return Color(0.5, 0.0, 0.8)
		DebuffType.BURN: return Color(1.0, 0.5, 0.0)
		DebuffType.POISON: return Color(0.2, 0.8, 0.2)
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
		DebuffType.CLUMSY: return Color(0.9, 0.6, 0.2)
		DebuffType.VULNERABLE: return Color(1.0, 0.3, 0.3)
		DebuffType.BRITTLE: return Color(0.7, 0.7, 0.6)
		DebuffType.COLD: return Color(0.4, 0.7, 1.0)
		DebuffType.BLIND: return Color(0.85, 0.85, 0.4)
		DebuffType.WEAKENED: return Color(0.5, 0.5, 0.8)
	return Color.WHITE

func get_short_display() -> String:
	if value > 0:
		return "%s(%d)" % [debuff_name, value]
	return debuff_name

static func create(type: DebuffType, val: int = 0, dur: int = 15) -> Debuff:
	return Debuff.new(type, val, dur)

static func create_slowed(stacks_count: int = 2, source: String = "") -> Debuff:
	# Stack-driven: each tile moved costs SLOWED_TEMPO_PER_TILE tempo and burns
	# one stack. Never expires by the clock.
	var debuff = Debuff.new(DebuffType.SLOWED, stacks_count, -1)
	debuff.source_name = source
	return debuff
