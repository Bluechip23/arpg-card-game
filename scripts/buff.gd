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
	INVISIBLE
}

var buff_type: BuffType
var buff_name: String
var description: String
var value: int = 0            # The 'x' value (damage, bonus, etc.)
var duration: int = 0         # Tempo remaining (-1 for until depleted)
var charges: int = -1         # For charge-based buffs (attacks, armor gains, etc.)
var source_name: String = ""  # What applied this buff
var stacks: int = 1           # Some buffs can stack

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
			description = "Gain 1 extra mana per cycle"
		BuffType.REGEN:
			buff_name = "Regen"
			description = "Heal %d HP per cycle" % value
		BuffType.BLESSED:
			buff_name = "Blessed"
			description = "Draw %d additional card(s) per cycle" % value
		BuffType.FORTIFY:
			buff_name = "Fortify"
			description = "Armor does not decay"
		BuffType.ENLIGHTENED:
			buff_name = "Enlightened"
			description = "+%d%% crit chance for next %d attacks" % [value, charges]
		BuffType.STRENGTHEN:
			buff_name = "Strengthen"
			description = "+%d damage on next %d attacks" % [value, charges]
		BuffType.BOLSTER:
			buff_name = "Bolster"
			description = "+%d armor next %d times you gain armor" % [value, charges]
		BuffType.HASTE:
			buff_name = "Haste"
			description = "+%d movement per tempo spent" % value
		BuffType.CLEANSE:
			buff_name = "Cleanse"
			description = "Remove %d negative effect(s)" % value
		BuffType.SMITH:
			buff_name = "Smith"
			description = "Gain %d armor per cycle" % value
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
			description = "Next attack heals you for damage dealt"
		BuffType.MORPHINE:
			buff_name = "Morphine"
			description = "Temp HP active. Lose %d armor and take 2 damage when expired" % value
		BuffType.WEAR_DOWN:
			buff_name = "Wear Down"
			description = "Each attack reduces target's attack by 1 (stacks) for %d tempo" % duration
		BuffType.INVISIBLE:
			buff_name = "Invisible"
			description = "Cannot be targeted by enemies for %d tempo" % duration

func tick() -> bool:
	# Called each cycle (5 tempo). Returns true if buff expired by duration.
	if duration > 0:
		duration -= 5
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
		BuffType.ENLIGHTENED, BuffType.STRENGTHEN, BuffType.BOLSTER, BuffType.BRACE, BuffType.STEADY, BuffType.LIFE_STEAL:
			return true
	return false

func is_expired() -> bool:
	if is_charge_based():
		return charges <= 0
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
	return Color.WHITE

func get_short_display() -> String:
	if is_charge_based():
		return "%s(%d×%d)" % [buff_name, value, charges]
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

static func create_blessed(extra_draws: int = 1, duration: int = 15, source: String = "") -> Buff:
	var buff = Buff.new(BuffType.BLESSED, extra_draws, duration)
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

static func create_haste(extra_movement: int = 1, duration: int = 15, source: String = "") -> Buff:
	var buff = Buff.new(BuffType.HASTE, extra_movement, duration)
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

static func create_resilient(percent_reduction: int = 15, tempo: int = 15, source: String = "") -> Buff:
	var buff = Buff.new(BuffType.RESILIENT, percent_reduction, tempo)
	buff.source_name = source
	return buff

static func create_life_steal(source: String = "") -> Buff:
	var buff = Buff.new(BuffType.LIFE_STEAL, 0, -1, 1)  # 1 charge - next attack
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

static func create_invisible(tempo: int = 10, source: String = "") -> Buff:
	var buff = Buff.new(BuffType.INVISIBLE, 0, tempo)
	buff.source_name = source
	return buff
