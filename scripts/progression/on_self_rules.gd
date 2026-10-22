class_name OnSelfRules
extends RefCounted

## The one statement of what each on-self rider needs from the slotted card,
## read straight off the code that applies it (card.gd / main.gd /
## deck_manager.gd). The hover preview, the item-text check and the slot
## audit all read this table, so a rider's requirement is written once.
##
##   key   — the get_on_self_bonus() key
##   wants — the card kind it fires on (see KIND_TEXT / qualifies)
##   say   — what it does, "%s" = the value

const KIND_TEXT := {
	"any": "any card",
	"damaging": "a card that deals damage",
	"offensive": "an offensive card",
	"offensive hit": "an offensive card that hits",
	"ranged offensive": "a ranged offensive card",
	"melee offensive": "a melee offensive card",
	"attack": "an Attack card",
	"defense": "a Defense card",
	"utility": "a Utility card",
	"utility or defense": "a Utility or Defense card that isn't offensive",
	"instant": "an Instant card",
	"enemy target": "a card aimed at an enemy",
	"friendly target": "a card aimed at you or an ally",
	"self target": "a card that targets you",
}

const RULES := {
	"damage": {"wants": "damaging", "say": "+%s damage"},
	"block": {"wants": "any", "say": "+%s block (armor on a card that blocks nothing)"},
	"heal": {"wants": "any", "say": "+%s healing (heals you on a card that doesn't heal)"},
	"self_heal": {"wants": "any", "say": "heal yourself %s"},
	"mana_reduction": {"wants": "any", "say": "%s mana cost"},
	"mana_reduction_percent": {"wants": "any", "say": "-%s%% mana cost"},
	"apply_burn": {"wants": "offensive hit", "say": "apply %s Burn"},
	"apply_cold": {"wants": "offensive hit", "say": "apply %s Cold"},
	"apply_bleed": {"wants": "offensive hit", "say": "apply %s Bleed"},
	"apply_vulnerable": {"wants": "offensive hit", "say": "apply %s Vulnerable"},
	"apply_slow": {"wants": "offensive hit", "say": "apply %s Slow"},
	"apply_shock": {"wants": "offensive hit", "say": "apply %s Shock"},
	"apply_weaken": {"wants": "offensive hit", "say": "apply %s Weaken"},
	"thorns": {"wants": "any", "say": "gain %s Thorns"},
	"range_offensive": {"wants": "offensive", "say": "+%s range"},
	"crit_ranged_percent": {"wants": "ranged offensive", "say": "+%s%% crit"},
	"utility_heal": {"wants": "utility", "say": "heal yourself %s"},
	"utility_spell_damage": {"wants": "utility", "say": "%s spell damage to a random nearby enemy"},
	"brain_regen": {"wants": "any", "say": "regain %s brain points"},
	"armor_any": {"wants": "any", "say": "gain %s armor"},
	"reaction_armor": {"wants": "instant", "say": "gain %s armor"},
	"flash_regen": {"wants": "any", "say": "restore %s flash points"},
	"int_damage_percent": {"wants": "damaging", "say": "+%s%% of INT as damage"},
	"armor_per_missing_health10": {"wants": "any", "say": "gain %s armor per step of missing health"},
	"instant_damage_nearest": {"wants": "instant", "say": "%s damage to the nearest enemy within 3"},
	"attack_tempo_reduction": {"wants": "attack", "say": "-%s tempo"},
	"invisible_tempo": {"wants": "any", "say": "become invisible for %s tempo"},
	"melee_damage": {"wants": "melee offensive", "say": "+%s damage"},
	"crit_damage_percent": {"wants": "any", "say": "+%s%% crit damage"},
	"flash_counter_drain": {"wants": "any", "say": "-%s from the flash-crit counter"},
	"defense_armor": {"wants": "defense", "say": "gain %s armor"},
	"utility_weaken": {"wants": "utility", "say": "Weaken %s a random enemy within 5"},
	"physical_resilient": {"wants": "any", "say": "%s%% physical resistance for 10 tempo"},
	"strengthen_value": {"wants": "any", "say": "Strengthen +%s"},
	"cleanse_stacks": {"wants": "friendly target", "say": "cleanse %s stacks of a debuff on the target"},
	"damage_while_invisible": {"wants": "damaging", "say": "+%s damage while invisible"},
	"taunt_cycles": {"wants": "offensive", "say": "taunt the target for %s cycles"},
	"support_heal": {"wants": "utility or defense", "say": "heal the target %s"},
	"damage_multiplier": {"wants": "damaging", "say": "x%s damage"},
	"mana_multiplier": {"wants": "any", "say": "x%s mana cost"},
	"offensive_damage": {"wants": "offensive", "say": "+%s damage"},
	"target_aoe_damage": {"wants": "enemy target", "say": "%s damage around the target"},
	"utility_tempo_refund": {"wants": "utility", "say": "-%s tempo"},
	"draw_card": {"wants": "any", "say": "draw %s card(s)"},
	"summon_wolf": {"wants": "any", "say": "summon %s wolf"},
	"root_offensive": {"wants": "offensive hit", "say": "root the target %s cycle(s)"},
	"disarm_offensive": {"wants": "offensive hit", "say": "Disarm the target (%s)"},
	"crit_percent": {"wants": "any", "say": "+%s%% crit chance"},
	"weakened_damage_percent": {"wants": "offensive", "say": "+%s%% damage to Weakened enemies"},
	"max_hp_damage_percent": {"wants": "offensive", "say": "+damage equal to %s%% of your max health"},
	"self_targets_allies": {"wants": "self target", "say": "may also target an ally"},
	"overdrive_multiplier": {"wants": "damaging", "say": "x%s damage, half the bonus hurts you"},
	"slow_damage_per_stack": {"wants": "offensive", "say": "+%s damage per Slow on the target"},
	"pair_tempo_reduction": {"wants": "any", "say": "-%s tempo while paired"},
	"ranged_damage": {"wants": "ranged offensive", "say": "+%s damage"},
	"ranged_tempo_reduction": {"wants": "ranged offensive", "say": "-%s tempo"},
	"resist_all_percent": {"wants": "any", "say": "+%s%% resistance to all damage"},
	"offensive_shift": {"wants": "offensive", "say": "your next %s tiles of movement are free"},
	"offensive_heal_percent": {"wants": "offensive", "say": "heal %s%% of your max health"},
	"adaptive_damage_type": {"wants": "damaging", "say": "deals the type the target resists least"},
	"armor_shred": {"wants": "offensive", "say": "shred %s extra armor"},
	"tempo_penalty": {"wants": "any", "say": "%s tempo"},
	"double_shot": {"wants": "offensive", "say": "hits its target a second time"},
	"jail_tempo": {"wants": "any", "say": "jailed %s tempo after play"},
	"bounce_percent": {"wants": "offensive", "say": "%s%% chance to bounce to another enemy"},
	"mana_to_life": {"wants": "any", "say": "half its mana is paid in life"},
	"kill_summon_skeleton": {"wants": "offensive", "say": "a kill raises a skeleton"},
	"conjure_on_play_id": {"wants": "any", "say": "adds %s to your hand"},
	"crit_bud_bow": {"wants": "offensive", "say": "a crit buds a bow turret"},
	"fortify": {"wants": "any", "say": "Fortify (armor stops decaying)"},
	"knockback": {"wants": "any", "say": "shove the target back %s (or every adjacent enemy, on a card with no enemy target)"},
	"discard": {"wants": "any", "say": "discard %s card(s)"},
	"lifesteal_percent": {"wants": "attack", "say": "%s%% lifesteal"},
	"chance_boost": {"wants": "any", "say": "+%s%% to its rolls"},
	"block_max_mana_percent": {"wants": "any", "say": "block worth %s%% of your max mana"},
}

## Rider keys that only parameterise another rider.
const PARAMS := ["range_requires_ranged", "strengthen_attacks", "missing_health_step", "resist_all_tempo"]

## Keys whose neutral value is not 0 / false / "".
const NEUTRAL_ONE := ["damage_multiplier", "mana_multiplier", "overdrive_multiplier"]

static func is_active(key: String, value) -> bool:
	if value == null:
		return false
	if key in NEUTRAL_ONE:
		return float(value) != 1.0
	if value is bool:
		return value
	if value is String:
		return value != ""
	if value is int or value is float:
		return float(value) != 0.0
	return false

## Whether `card` is the kind a rider wants. `kind` is a RULES "wants".
static func qualifies(card, kind: String) -> bool:
	if card == null:
		return false
	match kind:
		"any":
			return true
		"damaging":
			return card.base_damage > 0 or card.is_offensive()
		"offensive", "offensive hit":
			return card.is_offensive()
		"ranged offensive":
			return card.is_offensive() and card.is_ranged
		"melee offensive":
			return card.is_offensive() and not card.is_ranged
		"attack":
			return card.card_type == Card.CardType.ATTACK
		"defense":
			return card.card_type == Card.CardType.DEFENSE
		"utility":
			return card.card_type == Card.CardType.UTILITY
		"utility or defense":
			return (card.card_type == Card.CardType.UTILITY or card.card_type == Card.CardType.DEFENSE) and not card.is_offensive()
		"instant":
			return card.card_type == Card.CardType.REACTION
		"enemy target":
			return card.target_types.has("enemy") or card.target_types.has("point")
		"friendly target":
			return card.target_types.has("self") or card.target_types.has("ally")
		"self target":
			return card.target_types.has("self")
	return true

## Every active rider of an on-self bonus, as {key, wants, text, applies}:
## `applies` is whether `card` (null = unknown) is the kind it fires on.
static func describe(osb: Dictionary, card = null) -> Array:
	var out: Array = []
	for key in RULES:
		if not osb.has(key) or not is_active(key, osb[key]):
			continue
		var rule: Dictionary = RULES[key]
		var v = osb[key]
		var shown: String
		if v is float:
			shown = ("%.1f" % v).trim_suffix(".0")
		elif v is bool:
			shown = ""
		else:
			shown = str(v)
		var say: String = rule["say"]
		var text: String = say % shown if say.contains("%s") else say
		if key == "mana_reduction" and int(v) > 0:
			text = "-%s mana cost" % shown
		elif key == "mana_reduction" and int(v) < 0:
			text = "+%d mana cost" % -int(v)
		out.append({"key": key, "wants": rule["wants"], "text": text,
			"applies": card == null or qualifies(card, rule["wants"])})
	return out
