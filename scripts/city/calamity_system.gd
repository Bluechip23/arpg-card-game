class_name CalamitySystem
extends RefCounted

## Calamities: threats against the player's city — monster invasions and
## natural disasters (docs/STORY.md §6.2). The player is never ambushed
## blind: Olorin's flute sounds a warning when one strikes.
##
## Flow (all state lives in progression["city_calamity"]):
##  1. schedule() arms a calamity once the city exists: a hidden countdown
##     measured in kills while adventuring (the world reacting to the city's
##     growing light).
##  2. on_kill() ticks the countdown; when it reaches zero the calamity
##     STRIKES — the flute cries out and the player should head home.
##  3. resolve() runs when the player next reaches town. Return promptly
##     (few kills after the strike) and the hero stands with the garrison;
##     dawdle and the city defends alone.

const TYPES := {
	"goblin_raid": {
		"name": "Goblin Raid",
		"kind": "invasion",
		"warning": "Goblins mass to sack the city!",
	},
	"wolf_pack": {
		"name": "Wolf Pack",
		"kind": "invasion",
		"warning": "A howling pack circles the city walls!",
	},
	"great_storm": {
		"name": "Great Storm",
		"kind": "disaster",
		"warning": "A monstrous storm bears down on the city!",
	},
}

## Kills between scheduling and the strike.
const KILLS_TO_STRIKE_MIN := 18
const KILLS_TO_STRIKE_MAX := 30
## Reach town within this many kills of the strike and the hero joins the defense.
const PROMPT_RESPONSE_KILLS := 8
## Disaster (storm) base damage: fraction of each stored resource destroyed.
const DISASTER_DAMAGE := 0.20
## Each Walls level shaves this off the disaster damage fraction.
const DISASTER_WALLS_RELIEF := 0.015

static func pending(progression: Dictionary) -> Dictionary:
	return progression.get("city_calamity", {})

static func has_struck(progression: Dictionary) -> bool:
	return pending(progression).get("struck", false)

static func schedule(progression: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	## Arm the next calamity. No-op (returns the existing one) if a calamity
	## is already brewing, or the city hasn't started.
	if not CityBridge.city_started(progression):
		return {}
	if not pending(progression).is_empty():
		return pending(progression)
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var type_id: String = TYPES.keys()[rng.randi_range(0, TYPES.size() - 1)]
	var calamity := {
		"type": type_id,
		"kills_left": rng.randi_range(KILLS_TO_STRIKE_MIN, KILLS_TO_STRIKE_MAX),
		"struck": false,
		"kills_since_strike": 0,
	}
	progression["city_calamity"] = calamity
	return calamity

static func on_kill(progression: Dictionary) -> bool:
	## Tick the countdown. Returns true exactly once — on the kill where the
	## calamity strikes (time to sound the flute).
	var calamity := pending(progression)
	if calamity.is_empty():
		return false
	if calamity["struck"]:
		calamity["kills_since_strike"] = int(calamity["kills_since_strike"]) + 1
		progression["city_calamity"] = calamity
		return false
	calamity["kills_left"] = int(calamity["kills_left"]) - 1
	if calamity["kills_left"] <= 0:
		calamity["struck"] = true
	progression["city_calamity"] = calamity
	return calamity["struck"]

static func warning_text(progression: Dictionary) -> String:
	var calamity := pending(progression)
	if calamity.is_empty():
		return ""
	return TYPES[calamity["type"]]["warning"]

static func resolve(progression: Dictionary, hero_power: int, now: int, rng: RandomNumberGenerator = null) -> Dictionary:
	## Resolve a STRUCK calamity against the city (called on reaching town).
	## Returns {} when nothing has struck. Otherwise clears the calamity and
	## returns {name, kind, hero_joined, held, lost: {res: amt}} after logging
	## the outcome to the city's defense log.
	var calamity := pending(progression)
	if calamity.is_empty() or not calamity["struck"]:
		return {}
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var city := CityBridge.get_city(progression)
	var info: Dictionary = TYPES[calamity["type"]]
	var hero_joined: bool = int(calamity["kills_since_strike"]) <= PROMPT_RESPONSE_KILLS
	var held := false
	var lost := {}

	if info["kind"] == "invasion":
		# Attack sized to the city; the garrison holds the walls, and a
		# promptly-returning hero stands with them.
		var attack: int = maxi(10, int(city.get_power() * rng.randf_range(0.7, 1.3)))
		var defense: int = maxi(1, city.get_defense_power() + (hero_power if hero_joined else 0))
		var ratio: float = float(attack) / float(defense)
		held = ratio < RaidSystem.WIN_RATIO
		if not held:
			var protected := city.get_protected_fraction()
			for res in CityState.RESOURCES:
				var lootable: int = int(city.resources.get(res, 0) * (1.0 - protected))
				var amt: int = int(lootable * RaidSystem.LOOT_FRACTION)
				if amt > 0:
					lost[res] = amt
					city.resources[res] -= amt
	else:
		# Disaster: raw destruction. Walls blunt it; a returning hero shores
		# up and halves the damage; the vault's shelter holds either way.
		var frac: float = DISASTER_DAMAGE - city.get_building_level("walls") * DISASTER_WALLS_RELIEF
		frac = maxf(frac, 0.04)
		if hero_joined:
			frac *= 0.5
		var protected := city.get_protected_fraction()
		for res in CityState.RESOURCES:
			var exposed: int = int(city.resources.get(res, 0) * (1.0 - protected))
			var amt: int = int(exposed * frac)
			if amt > 0:
				lost[res] = amt
				city.resources[res] -= amt
		held = lost.is_empty()

	city.record_defense({
		"time": now,
		"attacker": info["name"],
		"won": not held,
		"loot": lost.duplicate(),
	})
	CityBridge.store_city(progression, city)
	progression.erase("city_calamity")
	return {
		"name": info["name"],
		"kind": info["kind"],
		"hero_joined": hero_joined,
		"held": held,
		"lost": lost,
	}
