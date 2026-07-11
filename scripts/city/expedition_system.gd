class_name ExpeditionSystem
extends RefCounted

## Expeditions: heroes venture into a habitat, kill monsters, and haul
## resources back to the city. This is the "go out into the world" half of the
## city loop — the other half is RaidSystem.
##
## Two ways to resolve an expedition:
##  1. REAL BATTLE (the intended path): the battle scene reports its kills via
##     rewards_for_kills() and the city banks the result. Nothing about combat
##     changes — this just converts kills into city resources.
##  2. QUICK RESOLVE (simulation): resolve_quick() lets the loop run before the
##     battle wiring exists, and later doubles as "send idle heroes out" auto-play.

## Habitats mirror the STORY.md bestiary realms. Higher tier = richer yields.
## weights: which resources this habitat skews toward.
const ZONES := {
	"Forest":     {"tier": 1, "weights": {"lumber": 3, "gold": 1}},
	"Sewer":      {"tier": 1, "weights": {"gold": 2, "essence": 1}},
	"Graveyard":  {"tier": 2, "weights": {"essence": 2, "stone": 1, "gold": 1}},
	"Cave":       {"tier": 2, "weights": {"stone": 3, "gold": 1}},
	"Mountains":  {"tier": 3, "weights": {"stone": 2, "gold": 2}},
	"Underworld": {"tier": 4, "weights": {"essence": 3, "gold": 2}},
	"Heavens":    {"tier": 5, "weights": {"essence": 4, "gold": 3}},
}

## Base resource value of one monster kill, scaled by the zone tier.
const BASE_LOOT_PER_KILL := 12

static func zone_names() -> Array:
	return ZONES.keys()

static func rewards_for_kills(zone: String, kills: int, city: CityState = null, elite_kills: int = 0) -> Dictionary:
	## Convert battle results in a habitat into city resources.
	## Elites count triple. The city's Hero Hall boosts the whole haul.
	if not ZONES.has(zone) or kills <= 0:
		return {}
	var z: Dictionary = ZONES[zone]
	var tier: int = z["tier"]
	var weights: Dictionary = z["weights"]
	var weight_total := 0
	for res in weights:
		weight_total += int(weights[res])
	if weight_total <= 0:
		return {}

	var value: float = BASE_LOOT_PER_KILL * tier * (kills + elite_kills * 2)
	if city:
		value *= city.get_expedition_bonus()

	var out := {}
	for res in weights:
		var share: float = float(weights[res]) / float(weight_total)
		var amt := int(round(value * share))
		if amt > 0:
			out[res] = amt
	return out

static func resolve_quick(zone: String, hero_power: int, city: CityState, rng: RandomNumberGenerator = null) -> Dictionary:
	## Simulated expedition for loop testing / future idle-hero dispatch.
	## Hero power vs zone tier decides how many monsters the party clears.
	## Returns {zone, kills, rewards, banked} and banks the loot into the city.
	if not ZONES.has(zone):
		return {}
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var tier: int = ZONES[zone]["tier"]
	# A party at parity with the zone clears ~6 monsters; over/under-powered
	# parties scale up/down, with a little variance so hauls aren't static.
	var parity: float = float(hero_power) / float(tier * 20)
	var kills: int = clampi(int(round(6.0 * parity * rng.randf_range(0.75, 1.25))), 0, 30)
	var rewards := rewards_for_kills(zone, kills, city)
	var banked := city.add_resources(rewards) if city else {}
	return {"zone": zone, "kills": kills, "rewards": rewards, "banked": banked}

static func hero_power(stats) -> int:
	## A PlayerStats-shaped object → one expedition/raid power number.
	## Sum of core stats + a slice of max health; simple on purpose.
	if stats == null:
		return 10
	var total: int = 0
	total += int(stats.strength) + int(stats.dexterity) + int(stats.intelligence)
	total += int(stats.wisdom) + int(stats.determination) + int(stats.agility)
	total += int(stats.max_health / 10.0)
	return max(1, total)
