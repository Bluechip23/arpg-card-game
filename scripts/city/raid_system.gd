class_name RaidSystem
extends RefCounted

## Raids: invade rival cities for loot; rivals (or other players) invade yours.
##
## PvP here is ASYNCHRONOUS, Clash-of-Clans style: you never fight a live
## player — you attack a snapshot of a city and its defenses. First pass the
## snapshots are generated rivals; the same path accepts a real player's city
## dict (CityState.to_dict() shipped via save file or, later, a server).

## Fraction of each UNPROTECTED resource stolen on a clean win.
const LOOT_FRACTION := 0.25

## Attack/defense ratio needed to win outright; between the two is a partial win.
const WIN_RATIO := 1.15
const LOSS_RATIO := 0.85

# ============================================
# RIVAL GENERATION (async "matchmaking")
# ============================================

static func generate_rival(target_power: int, rng: RandomNumberGenerator = null) -> CityState:
	## A believable rival city near the requested power. Deterministic when
	## given a seeded rng (used by tests; later lets a daily rival list be stable).
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var rival := CityState.new()
	# Spend "levels" across buildings until the rival's power approaches target.
	var ids: Array = rival.buildings.keys()
	var guard := 200
	while rival.get_power() < target_power and guard > 0:
		guard -= 1
		var id: String = ids[rng.randi_range(0, ids.size() - 1)]
		var lvl: int = rival.buildings[id]
		if lvl >= int(CityState.BUILDING_DEFS[id]["max_level"]):
			continue
		# Respect the town-hall gate rivals play by the same rules.
		if id != "town_hall" and lvl >= rival.buildings["town_hall"]:
			continue
		rival.buildings[id] = lvl + 1
	# Stock the rival with loot proportional to its economy.
	var stock := rival.get_power() * rng.randi_range(3, 6)
	rival.add_resources({
		"gold": stock, "lumber": stock / 2, "stone": stock / 2, "essence": stock / 8,
	})
	return rival

# ============================================
# RAID RESOLUTION
# ============================================

static func resolve_raid(attacker_power: int, defender: CityState, now: int = 0, attacker_name: String = "Raider") -> Dictionary:
	## One raid against a defending city (yours or a rival's).
	## Returns {won, partial, ratio, loot: {res: amt}} and applies the outcome
	## to the defender: loot removed, defense logged.
	var defense: int = maxi(1, defender.get_defense_power())
	var ratio: float = float(attacker_power) / float(defense)

	var won := ratio >= WIN_RATIO
	var partial := not won and ratio > LOSS_RATIO
	var loot := {}

	if won or partial:
		var frac := LOOT_FRACTION if won else LOOT_FRACTION * 0.4
		var protected := defender.get_protected_fraction()
		for res in CityState.RESOURCES:
			var lootable: int = int(defender.resources.get(res, 0) * (1.0 - protected))
			var amt: int = int(lootable * frac)
			if amt > 0:
				loot[res] = amt
				defender.resources[res] -= amt

	defender.record_defense({
		"time": now,
		"attacker": attacker_name,
		"won": won or partial,
		"loot": loot.duplicate(),
	})

	return {"won": won, "partial": partial, "ratio": ratio, "loot": loot}

static func raid_rival(city: CityState, hero_power: int, rival: CityState, now: int = 0) -> Dictionary:
	## The player's raid: hero power + the city's military buildings attack a
	## rival; winnings are banked into the player's city (storage cap applies).
	var attack: int = hero_power + city.get_attack_power()
	var result := resolve_raid(attack, rival, now, "You")
	if not result["loot"].is_empty():
		result["banked"] = city.add_resources(result["loot"])
	return result

static func simulate_incoming_raid(city: CityState, now: int, rng: RandomNumberGenerator = null) -> Dictionary:
	## An offline/AI invasion against the player's city, sized to its power.
	## Later, real player attacks replace this with their recorded hero power.
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var attacker: int = maxi(10, int(city.get_power() * rng.randf_range(0.7, 1.3)))
	return resolve_raid(attacker, city, now, "Rival Warlord")
