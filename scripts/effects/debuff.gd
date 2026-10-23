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
	WEAKENED,  # deal WEAKENED_REDUCTION% less damage; stacks fall on the 5-tempo clock (mirrors enemy-side Weaken)
	LOST  # Lost in the Labyrinth (the Minotaur's room): hand scrambled, play it left to right, no draws
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

## The sheet's "a stack is 5 tempo" rule: every stack-clocked debuff sheds one
## stack each STACK_TEMPO of its OWN clock (see advance_time), never by use.
const STACK_TEMPO := 5
## Cold's default timer on the player (the sheet: 5 tempo).
const COLD_TEMPO := 5
## What create()/new() hand a debuff that names no duration.
const DEFAULT_DURATION := 15

var debuff_type: DebuffType
var debuff_name: String
var description: String
var value: int = 0           # The 'x' value (damage, reduction, etc.) — the stack count for stack-clocked types
var duration: int = 0        # Tempo remaining (-1 = no timer: stack-driven, until played, or until cleansed)
var source_name: String = "" # What applied this debuff

# For tracking
var stacks: int = 1          # Some debuffs can stack
## A normally stack-driven debuff (Slowed, Staggered, Clumsy) that instead
## lasts a set number of tempo (Approach, Tower Shield, the White Manticore's
## Stinger): the clock expires it and nothing burns its stacks.
var clock_timed: bool = false
## Own clock for the stack-clocked types: raw tempo this instance has lived
## since its last stack fell. A stack applied at tempo 3 is gone at tempo 8,
## not at the next global cycle boundary.
var stack_clock: int = 0
## Hexed / Locked: the card this instance claims (null until the hand has one
## to give — a new claim only ever takes a card in hand). A claim rides the
## Card itself, not a hand slot, so it follows its card through every
## reshuffle of the hand and, by the designer's negative-card rule, into the
## discard and draw piles and jail: its clock keeps running in the piles and
## freezes in jail (DebuffManager.advance_time). It ends when the card is
## played ("until played"), when the clock runs out wherever the card is, or
## when the card leaves the game (erased, stolen, enchanted away).
var affected_card: Card = null

func _init(type: DebuffType, val: int = 0, dur: int = DEFAULT_DURATION) -> void:
	debuff_type = type
	value = val
	# sheet: Cold's default timer is 5 tempo. A caller that names no duration
	# (or the old 15) gets the sheet's number; an explicit other timer stands.
	if type == DebuffType.COLD and dur == DEFAULT_DURATION:
		dur = COLD_TEMPO
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

## The types whose stacks fall on their own 5-tempo clock (the sheet's
## "a stack is 5 tempo" model). Weighted is NOT one: it still burns per card.
static func is_stack_clocked(type: DebuffType) -> bool:
	return type in [DebuffType.VULNERABLE, DebuffType.BLIND, DebuffType.SLOWED,
		DebuffType.WEAKENED, DebuffType.STAGGERED, DebuffType.CLUMSY, DebuffType.BRITTLE]

## The hard locks whose timers ADD on re-application (Disarm 5 onto 3 left = 8).
static func is_additive_timer(type: DebuffType) -> bool:
	return type in [DebuffType.DISARM, DebuffType.ROOTED, DebuffType.SILENCE]

## This instance sheds stacks on its own clock: a stack-clocked type that is
## not riding a card's fixed timer (Approach's Slowed, Tower Shield's Staggered).
func uses_stack_clock() -> bool:
	return is_stack_clocked(debuff_type) and not clock_timed

func _stacks_left_text() -> String:
	return "%d stack(s), %d tempo each" % [value, STACK_TEMPO]

func _set_name_and_description() -> void:
	if debuff_type == DebuffType.GENERIC:
		return  # custom name/description are set by create_generic and never stomped
	match debuff_type:
		DebuffType.BLEED:
			debuff_name = "Bleed"
			description = "Take 1 damage per tile moved; each damage removes a stack (%d left)" % value
		DebuffType.STUN:
			debuff_name = "Stun"
			description = "Cannot take any action: no cards, attacks, blocks, moves, skills, Flash/Brain spends or gear swaps. Only Wait passes time"
		DebuffType.DISARM:
			debuff_name = "Disarm"
			description = "Cannot play attack cards or auto attack (%d tempo left)" % duration
		DebuffType.SILENCE:
			debuff_name = "Silence"
			description = "Cannot play spell cards (%d tempo left)" % duration
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
			description = "Cannot play cards, auto attack or Block"
		DebuffType.CUFFED:
			debuff_name = "Cuffed"
			description = "Cannot draw cards"
		DebuffType.SHOCKED:
			debuff_name = "Shocked"
			description = "Arc %d damage to nearby allies per cycle (a shocked enemy takes it itself), lose 1 per cycle" % value
		DebuffType.SLOWED:
			debuff_name = "Slowed"
			if clock_timed:
				description = "Movement costs %d tempo per tile (%d tempo left)" % [SLOWED_TEMPO_PER_TILE, duration]
			else:
				description = "Movement costs %d tempo per tile (%s)" % [SLOWED_TEMPO_PER_TILE, _stacks_left_text()]
		DebuffType.STAGGERED:
			debuff_name = "Staggered"
			if clock_timed:
				description = "Attack cards cost %d more mana (%d tempo left)" % [STAGGERED_MANA, duration]
			else:
				description = "Attack cards cost %d more mana (%s)" % [STAGGERED_MANA, _stacks_left_text()]
		DebuffType.DRAIN:
			debuff_name = "Drain"
			description = "Lose 10 mana per cycle, lose 1 drain per cycle"
		DebuffType.WEIGHTED:
			debuff_name = "Weighted"
			description = "Card plays cost %d more tempo (not the auto attack or Block); each card played burns a stack (%d left)" % [WEIGHTED_TEMPO, value]
		DebuffType.HEXED:
			debuff_name = "Hexed"
			description = "One card costs +%d mana until it is played%s. The hex stays on its card in the discard and draw piles, where its clock keeps running; the clock freezes while the card is jailed" \
					% [value, "" if duration < 0 else " (%d tempo left)" % duration]
		DebuffType.LOCKED:
			debuff_name = "Locked"
			description = "One random card cannot be played%s (each Locked holds its own card). The lock stays on its card in the discard and draw piles, where its clock keeps running; the clock freezes while the card is jailed" \
					% ("" if duration < 0 else " (%d tempo left)" % duration)
		DebuffType.ROOTED:
			debuff_name = "Rooted"
			description = "Cannot move (%d tempo left)" % duration
		DebuffType.CLUMSY:
			debuff_name = "Clumsy"
			if clock_timed:
				description = "%d%% chance to discard a random card when playing (%d tempo left)" % [CLUMSY_CHANCE, duration]
			else:
				description = "%d%% chance to discard a random card when playing (%s)" % [CLUMSY_CHANCE, _stacks_left_text()]
		DebuffType.VULNERABLE:
			debuff_name = "Vulnerable"
			description = "Take 30%% more damage (%s)" % _stacks_left_text()
		DebuffType.BRITTLE:
			debuff_name = "Brittle"
			description = "Armor decays an extra 2 per cycle (%s)" % _stacks_left_text()
		DebuffType.COLD:
			debuff_name = "Cold"
			description = "At 5 stacks, become Frozen for 1 cycle. Current: %d stack(s) (%d tempo left)" % [value, duration]
		DebuffType.BLIND:
			debuff_name = "Blind"
			description = "%d%% chance for your attacks to miss: attack cards, the auto attack and Flash Cut (%s)" % [BLIND_MISS, _stacks_left_text()]
		DebuffType.WEAKENED:
			debuff_name = "Weakened"
			description = "Deal %d%% less damage (%s)" % [WEAKENED_REDUCTION, _stacks_left_text()]
		DebuffType.LOST:
			debuff_name = "Lost in the Labyrinth"
			description = "Your hand is scrambled: play it left to right. You cannot draw (%d tempo left)" % duration

func advance_time(amount: int) -> bool:
	# Stack-clocked types (the sheet's "a stack is 5 tempo"): the instance's
	# own clock runs on raw tempo and sheds one stack per STACK_TEMPO. Expired
	# once the last stack falls. Returns true when expired.
	if uses_stack_clock():
		stack_clock += amount
		while stack_clock >= STACK_TEMPO and value > 0:
			stack_clock -= STACK_TEMPO
			value -= 1
		_set_name_and_description()
		return value <= 0
	# Duration counts RAW tempo, decremented on every tempo advance — so a
	# 3-tempo stun works. Negative duration = "until cleansed / stack-driven":
	# never expires here.
	if duration < 0:
		return false
	duration -= amount
	# Every timed description that shows tempo left stays honest.
	_set_name_and_description()
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
		DebuffType.LOST: return Color(0.85, 0.55, 0.25)
	return Color.WHITE

func get_short_display() -> String:
	if value > 0:
		return "%s(%d)" % [debuff_name, value]
	return debuff_name

static func create(type: DebuffType, val: int = 0, dur: int = DEFAULT_DURATION) -> Debuff:
	return Debuff.new(type, val, dur)

## Slowed, Staggered or Clumsy on the clock instead of by stacks.
static func create_timed(type: DebuffType, tempo: int, source: String = "") -> Debuff:
	var debuff = Debuff.new(type, 1, tempo)
	debuff.clock_timed = true
	debuff.source_name = source
	debuff._set_name_and_description()
	return debuff

static func create_slowed(stacks_count: int = 2, source: String = "") -> Debuff:
	# Stack form: each tile moved costs SLOWED_TEMPO_PER_TILE tempo; the stacks
	# fall on the debuff's own 5-tempo clock, never by moving.
	var debuff = Debuff.new(DebuffType.SLOWED, stacks_count, -1)
	debuff.source_name = source
	return debuff
