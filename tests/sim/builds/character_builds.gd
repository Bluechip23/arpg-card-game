class_name CharacterBuilds
extends RefCounted

## The character-generic build composer. Each character has a component
## file, tests/sim/builds/<name>_builds.gd, holding named ITEM_SETS, DECKS,
## ALLOCS, SPHERES, PASSIVES, SLOTTED and DESIGNED builds (see
## ryan_builds.gd for the shape). compose() turns a choice of parts into a
## scenario Dictionary at any level:
##
##   CharacterBuilds.compose("ryan", {"build": "bruiser", "level": 50,
##       "deck": "potions", "alloc": "str_det", "enemy": "WYVERN"})
##
## Level scaling: allocations and passive ranks are WEIGHTS, spread over
## the points the level banks (3 stat points and 1 passive point a level,
## ranks capped at PASSIVE_MAX_LEVEL); the mythic cap is the game's (one
## equipped mythic per 15 levels) and an item entry may carry a legendary
## fallback for when its mythic does not fit: ["sabre_tooth", 0,
## "nine_ruins_of_sanguine"].

const CHARACTERS := ["ryan", "brad", "jeremy", "stephen", "cory"]
const DEFAULT_LEVEL := 18
const STAT_POINTS_PER_LEVEL := 3
const PASSIVE_POINTS_PER_LEVEL := 1
const LEVELS_PER_MYTHIC := 15

static func library(character: String) -> Script:
	var path := "res://tests/sim/builds/%s_builds.gd" % character.to_lower()
	var script = load(path)
	if script == null:
		push_error("[SIM] no build library for '%s' (%s)" % [character, path])
	return script

static func components(character: String) -> Dictionary:
	var lib := library(character)
	if lib == null:
		return {}
	return {"items": lib.ITEM_SETS.keys(), "deck": lib.DECKS.keys(), "alloc": lib.ALLOCS.keys(),
		"sphere": lib.SPHERES.keys(), "passives": lib.PASSIVES.keys(), "designed": lib.DESIGNED.keys(),
		"designed_parts": lib.DESIGNED, "default_enemy": lib.DEFAULT_ENEMY,
		"tree_passives": tree_passives(character),
		"recipes": recipes(character).keys(), "card_pool": SimDeckBuilder.legal_ids()}

## The library's DECK_RECIPES (shape-described decks), {} when it has none.
static func recipes(character: String) -> Dictionary:
	var lib := library(character)
	if lib == null:
		return {}
	var consts: Dictionary = lib.get_script_constant_map()
	return consts.get("DECK_RECIPES", {})

## Every upgradeable passive the character's skill tree offers, read from
## the tree itself so a passive the designer adds is swept automatically.
## (Passives that come with an item have no rank and are not here.)
static func tree_passives(character: String) -> Array:
	var tree = SkillTreeData.create_tree_for(character.capitalize(), 50)
	var out: Array = []
	for row in tree.rows:
		for opt in row.options:
			if opt.option_type == SkillTreeData.OptionType.PASSIVE and opt.passive_id != "" and not out.has(opt.passive_id):
				out.append(opt.passive_id)
	return out

static func all_components() -> Dictionary:
	var out := {}
	for c in CHARACTERS:
		var comp := components(c)
		if not comp.is_empty():
			out[c] = comp
	return out

## Spread `points` over weighted stats, largest remainders first, so the
## total is exact at every level.
static func spread(weights: Dictionary, points: int, cap: int = 1 << 30) -> Dictionary:
	var total := 0.0
	for k in weights:
		total += maxf(0.0, float(weights[k]))
	if total <= 0.0 or points <= 0:
		return {}
	var out := {}
	var remainders: Array = []
	var given := 0
	for k in weights:
		var exact := float(points) * maxf(0.0, float(weights[k])) / total
		var base := mini(cap, int(floor(exact)))
		out[k] = base
		given += base
		remainders.append([exact - floor(exact), k])
	remainders.sort_custom(func(a, b): return a[0] > b[0])
	var left := points - given
	var guard := 0
	while left > 0 and guard < 1000:
		guard += 1
		var placed := false
		for r in remainders:
			if left <= 0:
				break
			if out[r[1]] < cap:
				out[r[1]] += 1
				left -= 1
				placed = true
		if not placed:
			break   # every stat at its cap
	var clean := {}
	for k in out:
		if out[k] > 0:
			clean[k] = out[k]
	return clean

## Items for a level: mythics in listed order up to the cap, legendary
## fallbacks for the rest. Returns {"items": [[id, slot]...], "dropped": [...]}.
static func fit_items(entries: Array, level: int, catalog_mythics: Dictionary) -> Dictionary:
	var cap: int = int(level / LEVELS_PER_MYTHIC)
	var used := 0
	var items: Array = []
	var dropped: Array = []
	for e in entries:
		var id: String = str(e[0])
		var slot: int = int(e[1]) if e.size() > 1 else 0
		var fallback: String = str(e[2]) if e.size() > 2 else ""
		if catalog_mythics.get(id, false):
			if used < cap:
				used += 1
				items.append([id, slot])
			elif fallback != "":
				items.append([fallback, slot])
			else:
				dropped.append(id)
		else:
			items.append([id, slot])
	return {"items": items, "dropped": dropped}

static func is_mythic(id: String) -> bool:
	var script: Script = ItemData
	if not SimScenario.script_has(script, "create_%s" % id):
		return false
	var it = script.call("create_%s" % id)
	return it is ItemData and it.rarity == ItemData.Rarity.MYTHIC

static func compose(character: String, parts: Dictionary) -> Dictionary:
	var lib := library(character)
	if lib == null:
		return {}
	var designed: Dictionary = lib.DESIGNED
	var build_name := str(parts.get("build", designed.keys()[0]))
	var base: Dictionary = designed.get(build_name, designed[designed.keys()[0]]).duplicate()
	for k in ["items", "deck", "alloc", "sphere", "passives"]:
		if parts.has(k):
			base[k] = str(parts[k])
	var level: int = int(parts.get("level", DEFAULT_LEVEL))
	var items_name: String = base["items"]
	var slot_name: String = str(parts.get("slotted", items_name))
	var enemy := str(parts.get("enemy", lib.DEFAULT_ENEMY))
	var mythics := {}
	for e in lib.ITEM_SETS[items_name]:
		mythics[str(e[0])] = is_mythic(str(e[0]))
	var fitted := fit_items(lib.ITEM_SETS[items_name], level, mythics)
	var max_rank: int = PlayerStats.PASSIVE_MAX_LEVEL
	var alloc := spread(lib.ALLOCS[base["alloc"]], (level - 1) * STAT_POINTS_PER_LEVEL)
	var passive_points: int = (level - 1) * PASSIVE_POINTS_PER_LEVEL
	var ranks: Dictionary
	if parts.has("focus") and str(parts["focus"]) != "":
		# One passive maxed first, the rest of the points spread over the
		# build's own set (or evenly over the other tree passives when the
		# set is empty) — how a player who commits to a passive builds.
		var focus := str(parts["focus"])
		base["focus"] = focus
		ranks = {focus: mini(passive_points, max_rank)}
		var rest := {}
		for k in lib.PASSIVES[base["passives"]]:
			if str(k) != focus:
				rest[k] = lib.PASSIVES[base["passives"]][k]
		if rest.is_empty():
			for k in tree_passives(character):
				if str(k) != focus:
					rest[k] = 1
		ranks.merge(spread(rest, passive_points - ranks[focus], max_rank))
	else:
		ranks = spread(lib.PASSIVES[base["passives"]], passive_points, max_rank)
	# Slotted cards only for items that made the cut.
	var slotted := {}
	var worn := {}
	for it in fitted["items"]:
		worn[it[0]] = true
	for item_id in lib.SLOTTED.get(slot_name, {}):
		if worn.has(item_id):
			slotted[item_id] = (lib.SLOTTED[slot_name][item_id] as Array).duplicate()
	# The deck: the build's list, a recipe generated from the pool, and/or
	# one pool card swapped in for the list's last card and spotlighted into
	# the opening hand (the single-card sweep).
	var deck: Array = (lib.DECKS[base["deck"]] as Array).duplicate()
	var opening: Array = []
	if parts.has("recipe") and str(parts["recipe"]) != "":
		var rname := str(parts["recipe"])
		var rec: Dictionary = recipes(character).get(rname, {})
		if rec.is_empty():
			push_error("[SIM] %s has no deck recipe '%s'" % [character, rname])
		else:
			# Engraved mythic cards use up the deck's mythic room (level / 15).
			var engraved_mythics := 0
			var cpool := SimDeckBuilder.pool()
			for item_id in slotted:
				for cid in slotted[item_id]:
					if cpool.has(cid) and cpool[cid]["rarity"] == "Mythic":
						engraved_mythics += 1
			deck = SimDeckBuilder.generate(rec, character, build_name, level, maxi(0, int(level / LEVELS_PER_MYTHIC) - engraved_mythics))
			base["recipe"] = rname
	if parts.has("swap") and str(parts["swap"]) != "":
		var card := str(parts["swap"])
		if not deck.is_empty():
			deck[deck.size() - 1] = card
		else:
			deck.append(card)
		opening = [card]
		base["swap"] = card
	var name := "%s_%s" % [character.to_lower(), build_name]
	return {
		"name": name,
		"max_bars": 40,
		"player": {
			"character": character.to_lower(),
			"level": level,
			"allocation": alloc,
			"passives": ranks,
			"sphere_targets": (lib.SPHERES[base["sphere"]] as Array).duplicate(),
			"items": fitted["items"],
			"slotted": slotted,
			"deck": deck,
			"opening_hand": opening,
			"cell": [6, 7],
		},
		"enemies": [{"type": enemy, "cell": [9, 7], "overrides": parts.get("enemy_overrides", {})}],
		"auto_range": true,
		"policy": "lookahead",
		"parts": base,
		"notes": ("dropped (mythic cap %d at level %d): %s" % [int(level / LEVELS_PER_MYTHIC), level, ", ".join(fitted["dropped"])]) if not fitted["dropped"].is_empty() else "",
	}
