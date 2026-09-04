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
