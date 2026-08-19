class_name Buff
extends RefCounted

## Represents a positive buff/status effect on a character

enum BuffType {
	THORNS,
	FOCUSED,
	REGEN,
	BLESSED,
	FORTIFY,
	ENLIGHTENED,
	STRENGTHEN,
	BOLSTER,
	HASTE,
	CLEANSE,
	SMITH,
	STEADY,
	BRACE,
	RESILIENT,
	LIFE_STEAL,
	MORPHINE,
	WEAR_DOWN,
	INVISIBLE,
	ARMOR_BREAK,
	SHIELD_READY,
	REPELLED_BLOCK,
	SHIELD_OF_GROWTH,
	PHOENIX_GRACE,
	DEMONIC_RAGE,
	POISONED_BLOOD,
	ELIXIR,
	GENERIC,
	KEEN,
	MIGHT
}

var buff_type: BuffType
var buff_name: String
var description: String
var value: int = 0            # The 'x' value (damage, bonus, etc.)
var duration: int = 0         # Tempo remaining (-1 for until depleted)
var charges: int = -1         # For charge-based buffs (attacks, armor gains, etc.)
var source_name: String = ""  # What applied this buff
var stacks: int = 1           # Some buffs can stack
var damage_type: int = -1     # Typed damage reduction (Resilient); -1 = all types
var custom_color: Color = Color.WHITE  # GENERIC display buffs: badge tint
var custom_icon_key: String = ""       # GENERIC display buffs: StatusIcons glyph key
var decay_by_damage: bool = false      # THORNS variant (Vined Encasing): lose X thorns per X damage received instead of 1 per hit

func _init(type: BuffType, val: int = 0, dur: int = 15, chrg: int = -1) -> void:
	buff_type = type
	value = val
	duration = dur
	charges = chrg
	_set_name_and_description()

func _set_name_and_description() -> void:
	match buff_type:
		BuffType.THORNS:
			buff_name = "Thorns"
			description = "Deal %d damage back to attackers" % value
		BuffType.FOCUSED:
			buff_name = "Focused"
			description = "Gain 10 extra mana per cycle"
		BuffType.REGEN:
			buff_name = "Regen"
			description = "Heal %d HP per cycle" % value
		BuffType.BLESSED:
			buff_name = "Blessed"
			description = "Draw %d additional card(s) per cycle for %d more cycle(s)" % [value, charges]
		BuffType.FORTIFY:
			buff_name = "Fortify"
			description = "Armor does not decay"
		BuffType.ENLIGHTENED:
			buff_name = "Enlightened"
			description = "10%% crit chance for the next %d attacks (stacks extend, never add)" % charges
		BuffType.STRENGTHEN:
			buff_name = "Strengthen"
			description = "+%d damage on next %d attacks" % [value, charges]
		BuffType.BOLSTER:
			buff_name = "Bolster"
			description = "+%d armor next %d times you gain armor" % [value, charges]
		BuffType.HASTE:
			buff_name = "Haste"
			description = "+%d tempo-free movement on your next %d move(s)" % [value, charges]
		BuffType.CLEANSE:
			buff_name = "Cleanse"
			description = "Remove %d negative effect(s)" % value
		BuffType.SMITH:
			buff_name = "Smith"
			description = "Gain %d armor per cycle, decaying by 1 each cycle" % value
		BuffType.STEADY:
			buff_name = "Steady"
			description = "Next action does not add tempo"
		BuffType.BRACE:
			buff_name = "Brace"
			description = "Reduce incoming attack damage by %d%% for %d attacks" % [value, charges]
		BuffType.RESILIENT:
			buff_name = "Resilient"
			description = "Reduce all incoming damage by %d%% for %d tempo" % [value, duration]
		BuffType.LIFE_STEAL:
			buff_name = "Life Steal"
			# value 0 = legacy full-damage heal; value > 0 = percentage of damage
			if value > 0:
				description = "Next attack heals you for %d%% of damage dealt" % value
			else:
				description = "Next attack heals you for damage dealt"
		BuffType.MORPHINE:
			buff_name = "Morphine"
			description = "Temp HP active. Lose %d HP and take 2 damage when expired" % value
		BuffType.WEAR_DOWN:
			buff_name = "Wear Down"
			description = "Each attack reduces target's attack by 1 (stacks) for %d tempo" % duration
		BuffType.INVISIBLE:
			buff_name = "Invisible"
			description = "Cannot be targeted by enemies for %d tempo" % duration
		BuffType.ARMOR_BREAK:
			buff_name = "Armor Break"
			description = "Next attack deals double damage to armor only (no health damage)"
		BuffType.SHIELD_READY:
			buff_name = "Shield Ready"
			description = "Gain %d more armor in %d tempo" % [value, duration]
		BuffType.REPELLED_BLOCK:
			buff_name = "Repelled Block"
			description = "If next melee attack is fully blocked by armor, negate damage and push enemy back 4 spaces"
		BuffType.SHIELD_OF_GROWTH:
			buff_name = "Shield of Growth"
			description = "All damage taken increases armor by that amount for %d tempo" % duration
		BuffType.PHOENIX_GRACE:
			buff_name = "Phoenix Grace"
			description = "When HP drops below 50%%: heal to 80%% and apply 5 burn to the nearest enemy (%d charge(s))" % charges
		BuffType.DEMONIC_RAGE:
			buff_name = "Demonic Rage"
			description = "Next %d mana costs use health instead" % charges
		BuffType.POISONED_BLOOD:
			buff_name = "Poisoned Blood"
			description = "Your next %d heal cards deal damage to enemies instead of healing" % charges
		BuffType.ELIXIR:
			buff_name = "Elixir"
			description = "Your next %d poison ticks heal you instead of dealing damage" % stacks
		BuffType.KEEN:
			buff_name = "Keen"
			description = "+%d%% crit chance for %d tempo" % [value, duration]
		BuffType.MIGHT:
			buff_name = "Might"
			description = "+%d STR for %d tempo" % [value, duration]
		BuffType.GENERIC:
			pass  # name/description are set directly by create_generic()

func get_icon_key() -> String:
	## Key used to look up the StatusIcons glyph. GENERIC buffs carry an explicit
	## key; all others fall back to their display name.
	if buff_type == BuffType.GENERIC and custom_icon_key != "":
		return custom_icon_key
	return buff_name

func advance_time(amount: int) -> bool:
	# Duration counts RAW tempo, decremented on every tempo advance. Negative
	# duration = "until depleted": never expires by the clock. Returns true
	# when expired.
	if duration < 0:
		return false
	duration -= amount
	return duration <= 0

func use_charge() -> bool:
	# Called when charge-based buff is used. Returns true if depleted.
	if charges > 0:
		charges -= 1
		print("[BUFF] %s charges remaining: %d" % [buff_name, charges])
		return charges <= 0
	return false

func is_charge_based() -> bool:
	match buff_type:
		BuffType.ENLIGHTENED, BuffType.STRENGTHEN, BuffType.BOLSTER, BuffType.BRACE, BuffType.STEADY, \
		BuffType.LIFE_STEAL, BuffType.ARMOR_BREAK, BuffType.REPELLED_BLOCK, BuffType.PHOENIX_GRACE, \
		BuffType.DEMONIC_RAGE, BuffType.BLESSED, BuffType.HASTE, BuffType.POISONED_BLOOD:
			return true
	return false

func is_expired() -> bool:
	if is_charge_based():
		return charges <= 0
	if duration < 0:
		return false  # "until depleted" — expiry comes from elsewhere, not the clock
	return duration <= 0

func get_icon_color() -> Color:
	match buff_type:
		BuffType.THORNS: return Color(0.8, 0.4, 0.8)
		BuffType.FOCUSED: return Color(0.4, 0.6, 1.0)
		BuffType.REGEN: return Color(0.4, 1.0, 0.4)
		BuffType.BLESSED: return Color(1.0, 0.9, 0.5)
		BuffType.FORTIFY: return Color(0.6, 0.6, 0.8)
		BuffType.ENLIGHTENED: return Color(1.0, 1.0, 0.6)
		BuffType.STRENGTHEN: return Color(1.0, 0.5, 0.3)
		BuffType.BOLSTER: return Color(0.5, 0.7, 1.0)
		BuffType.HASTE: return Color(0.5, 1.0, 1.0)
		BuffType.CLEANSE: return Color(1.0, 1.0, 1.0)
		BuffType.SMITH: return Color(0.7, 0.7, 0.7)
		BuffType.STEADY: return Color(0.6, 0.8, 0.6)
		BuffType.BRACE: return Color(0.5, 0.5, 0.8)
		BuffType.RESILIENT: return Color(0.7, 0.6, 0.9)
		BuffType.LIFE_STEAL: return Color(0.9, 0.2, 0.4)
		BuffType.MORPHINE: return Color(1.0, 0.6, 0.8)
		BuffType.WEAR_DOWN: return Color(0.9, 0.6, 0.3)
		BuffType.INVISIBLE: return Color(0.5, 0.5, 0.7)
		BuffType.ARMOR_BREAK: return Color(0.8, 0.6, 0.2)
		BuffType.SHIELD_READY: return Color(0.4, 0.6, 0.9)
		BuffType.REPELLED_BLOCK: return Color(0.3, 0.5, 1.0)
		BuffType.SHIELD_OF_GROWTH: return Color(0.3, 0.8, 0.5)
		BuffType.PHOENIX_GRACE: return Color(1.0, 0.5, 0.2)
		BuffType.DEMONIC_RAGE: return Color(0.8, 0.1, 0.2)
		BuffType.POISONED_BLOOD: return Color(0.5, 0.1, 0.4)
		BuffType.ELIXIR: return Color(0.3, 0.9, 0.5)
		BuffType.KEEN: return Color(1.0, 0.9, 0.3)
		BuffType.MIGHT: return Color(1.0, 0.4, 0.2)
		BuffType.GENERIC: return custom_color
	return Color.WHITE

func get_short_display() -> String:
	if is_charge_based():
		if value > 0:
			return "%s(%d×%d)" % [buff_name, value, charges]
		return "%s(%d)" % [buff_name, charges]  # value-less charges: "Life Steal(1)", not "(0×1)"
	elif value > 0:
		return "%s(%d)" % [buff_name, value]
	return buff_name

func get_duration_display() -> String:
	if is_charge_based():
		return "%d charges" % charges
	elif duration < 0:
		return "∞"
	return "%d tempo" % duration

# ============================================
# FACTORY METHODS
# ============================================

static func create(type: BuffType, val: int = 0, dur: int = 15, chrg: int = -1) -> Buff:
	return Buff.new(type, val, dur, chrg)

static func create_thorns(damage: int = 3, duration: int = 15, source: String = "") -> Buff:
	var buff = Buff.new(BuffType.THORNS, damage, duration)
	buff.source_name = source
	return buff

static func create_focused(duration: int = 15, source: String = "") -> Buff:
	var buff = Buff.new(BuffType.FOCUSED, 1, duration)
	buff.source_name = source
	return buff

static func create_regen(heal_per_cycle: int = 2, duration: int = 15, source: String = "") -> Buff:

	var buff = Buff.new(BuffType.REGEN, heal_per_cycle, duration)
	buff.source_name = source
	return buff

static func create_blessed(extra_draws: int = 1, cycles: int = 3, source: String = "") -> Buff:
	# Charge-based: draws extra cards each cycle and burns one charge per cycle.
	var buff = Buff.new(BuffType.BLESSED, extra_draws, -1, cycles)
	buff.source_name = source
	return buff

static func create_fortify(duration: int = 15, source: String = "") -> Buff:
	var buff = Buff.new(BuffType.FORTIFY, 0, duration)
	buff.source_name = source
	return buff

static func create_enlightened(crit_chance: int = 25, attacks: int = 3, source: String = "") -> Buff:
	var buff = Buff.new(BuffType.ENLIGHTENED, crit_chance, -1, attacks)
	buff.source_name = source
	return buff

static func create_strengthen(extra_damage: int = 3, attacks: int = 3, source: String = "") -> Buff:
	var buff = Buff.new(BuffType.STRENGTHEN, extra_damage, -1, attacks)
	buff.source_name = source
	return buff

static func create_bolster(extra_armor: int = 2, times: int = 3, source: String = "") -> Buff:
	var buff = Buff.new(BuffType.BOLSTER, extra_armor, -1, times)
	buff.source_name = source
	return buff

static func create_haste(extra_movement: int = 1, movements: int = 3, source: String = "") -> Buff:
	# Charge-based: each non-flash move gets tempo-free bonus tiles and burns a charge.
	var buff = Buff.new(BuffType.HASTE, extra_movement, -1, movements)
	buff.source_name = source
	return buff

static func create_cleanse(debuffs_to_remove: int = 1, source: String = "") -> Buff:
	# Cleanse is instant, so duration 0
	var buff = Buff.new(BuffType.CLEANSE, debuffs_to_remove, 0)
	buff.source_name = source
	return buff

static func create_smith(armor_per_cycle: int = 2, duration: int = 15, source: String = "") -> Buff:
	var buff = Buff.new(BuffType.SMITH, armor_per_cycle, duration)
	buff.source_name = source
	return buff

static func create_steady(source: String = "") -> Buff:
	var buff = Buff.new(BuffType.STEADY, 0, -1, 1)  # 1 charge
	buff.source_name = source
	return buff

static func create_brace(percent_reduction: int = 30, attacks: int = 1, source: String = "") -> Buff:
	var buff = Buff.new(BuffType.BRACE, percent_reduction, -1, attacks)
	buff.source_name = source
	return buff

static func create_resilient(percent_reduction: int = 15, tempo: int = 15, source: String = "", damage_type: int = -1) -> Buff:
	var buff = Buff.new(BuffType.RESILIENT, percent_reduction, tempo)
	buff.source_name = source
	buff.damage_type = damage_type  # -1 = reduces all damage; else only that type
	return buff

## Ragnarok (Hide of Garmr): timed flat crit chance. Stacks value.
static func create_keen(crit_percent: int, tempo: int = 10, source: String = "") -> Buff:
	var buff = Buff.new(BuffType.KEEN, crit_percent, tempo)
	buff.source_name = source
	return buff

## Ragnarok (Hide of Garmr): timed STR. Read as temp_strength_bonus on the
## owner's stats (recomputed by BuffManager whenever buffs change); it boosts
## damage but not carry capacity, so gear never pops off mid-fury.
static func create_might(str_bonus: int, tempo: int = 10, source: String = "") -> Buff:
	var buff = Buff.new(BuffType.MIGHT, str_bonus, tempo)
	buff.source_name = source
	return buff

static func create_life_steal(source: String = "") -> Buff:
	var buff = Buff.new(BuffType.LIFE_STEAL, 0, -1, 1)  # 1 charge - next attack
	buff.source_name = source
	return buff

## Percentage-based life steal (Resourceful Replenish): next attack heals for
## `pct`% of the damage dealt instead of the full amount.
static func create_life_steal_percent(pct: int, source: String = "") -> Buff:
	var buff = Buff.new(BuffType.LIFE_STEAL, pct, -1, 1)  # value carries the percent
	buff.source_name = source
	return buff

static func create_morphine(armor_amount: int = 4, duration: int = 15, source: String = "") -> Buff:
	var buff = Buff.new(BuffType.MORPHINE, armor_amount, duration)
	buff.source_name = source
	return buff

static func create_wear_down(duration: int = 15, source: String = "") -> Buff:
	var buff = Buff.new(BuffType.WEAR_DOWN, 0, duration)
	buff.source_name = source
	return buff

static func create_armor_break(source: String = "") -> Buff:
	var buff = Buff.new(BuffType.ARMOR_BREAK, 0, -1, 1)
	buff.source_name = source
	return buff

static func create_invisible(tempo: int = 10, source: String = "") -> Buff:
	var buff = Buff.new(BuffType.INVISIBLE, 0, tempo)
	buff.source_name = source
	return buff

static func create_shield_ready(armor: int = 5, delay: int = 5, source: String = "") -> Buff:
	var buff = Buff.new(BuffType.SHIELD_READY, armor, delay)
	buff.source_name = source
	return buff

static func create_repelled_block(source: String = "") -> Buff:
	var buff = Buff.new(BuffType.REPELLED_BLOCK, 0, -1, 1)  # 1 charge
	buff.source_name = source
	return buff

static func create_shield_of_growth(duration: int = 10, source: String = "") -> Buff:
	var buff = Buff.new(BuffType.SHIELD_OF_GROWTH, 0, duration)
	buff.source_name = source
	return buff

static func create_phoenix_grace(charges: int = 1, source: String = "") -> Buff:
	# Stack-oriented: each HP-below-50% rescue burns one charge.
	var buff = Buff.new(BuffType.PHOENIX_GRACE, 0, -1, charges)
	buff.source_name = source
	return buff

static func create_demonic_rage(uses: int = 5, source: String = "") -> Buff:
	var buff = Buff.new(BuffType.DEMONIC_RAGE, 0, -1, uses)  # charge-based: N mana uses
	buff.source_name = source
	return buff

static func create_poisoned_blood(heals: int = 3, source: String = "") -> Buff:
	# Stack-oriented: each heal card converted to damage burns one charge.
	var buff = Buff.new(BuffType.POISONED_BLOOD, 0, -1, heals)
	buff.source_name = source
	return buff

static func create_elixir(ticks: int = 5, source: String = "") -> Buff:
	# Display wrapper; lifecycle is driven by PlayerStats.elixir_stacks (one
	# stack burned per poison tick healed) and synced by BuffManager.
	var buff = Buff.new(BuffType.ELIXIR, 0, -1)
	buff.stacks = ticks
	buff.source_name = source
	return buff

static func create_generic(key: String, display_name: String, desc: String, color: Color, tempo: int = -1, count: int = 1) -> Buff:
	## A display-only badge for effects tracked as raw flags elsewhere. `key` is
	## the StatusIcons glyph key; `count` shows as xN. Lifecycle is driven by the
	## owning system (BuffManager._sync_flag_buffs), not the generic tick.
	var buff = Buff.new(BuffType.GENERIC, 0, tempo)
	buff.custom_icon_key = key
	buff.custom_color = color
	buff.buff_name = display_name
	buff.description = desc
	buff.source_name = display_name
	buff.stacks = count
	return buff
