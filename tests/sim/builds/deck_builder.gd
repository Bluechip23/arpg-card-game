class_name SimDeckBuilder
extends RefCounted

## The card pool and the recipe deck generator for the stored builds.
##
## Pool: every card a base deck may hold — a Card factory exists, the card
## is playable (not UNPLAYABLE), is not engraving-only and is not an
## item-generated / conjured card (shop_excluded). Cards are universal: no
## character filter, as the designer ruled.
##
## Recipe: a deck described by its shape instead of a list, so a new card
## enters the sweeps the moment it exists:
##   {"shape": {"ATTACK": 7, "DEFENSE": 3, "UTILITY": 2},   # cards per type, sums to 12
##    "school": "PHYSICAL" | "SPELL" | "",                  # optional
##    "reach": "melee" | "ranged" | "",                      # optional (attacks only)
##    "theme": ["poison", "potion"],                         # words matched in id / name / keywords / description
##    "prefer": ["slice"], "exclude": ["draw"],              # optional
##    "max_copies": 2}                                       # per card (the game's rarity cap still applies)
## Candidates for a type are ranked: theme matches first, then the card's
## measured uplift on this build from the single-card sweep when
## sim_out/charts/<char>[_L<level>]_card_swap.csv exists, else a flat
## efficiency heuristic, then id — so the deck is deterministic and, once a
## sweep has run, data-driven.

const DECK_SIZE := 12
static var _pool: Dictionary = {}

## id -> {type, school, rarity, ranged, keywords, mana, tempo, damage, block, heal, name, text}
static func pool() -> Dictionary:
	if not _pool.is_empty():
		return _pool
	var script: Script = Card
	for m in script.get_script_method_list():
		var mn: String = m["name"]
		if not mn.begins_with("create_") or m["args"].size() - m["default_args"].size() != 0:
			continue
		var c = script.call(mn)
		if not (c is Card):
			continue
		if c.card_type == Card.CardType.UNPLAYABLE or c.requires_engraving or c.shop_excluded:
			continue
		if c.card_id.ends_with("_copy"):   # token copies a card conjures, never dealt
			continue
		_pool[c.card_id] = {
			"type": Card.CardType.keys()[c.card_type],
			"offensive": c.is_offensive(),
			"school": Card.CardSchool.keys()[c.school],
			"rarity": c.get_rarity_name(),
			"ranged": c.is_ranged,
			"keywords": c.keywords.duplicate(),
			"mana": c.mana_cost, "tempo": c.tempo_cost,
			"damage": c.base_damage, "block": c.base_block if c.base_block > 0 else c.block, "heal": c.heal_amount,
			"name": c.card_name, "text": c.description,
		}
	return _pool

static func legal_ids() -> Array:
	var ids: Array = pool().keys()
	ids.sort()
	return ids

## Uplift per card for one build from the single-card sweep CSV, {} when none ran.
static func measured_uplift(character: String, build: String, level: int) -> Dictionary:
	var tag := character.to_lower() if level == CharacterBuilds.DEFAULT_LEVEL else "%s_L%d" % [character.to_lower(), level]
	var path := "res://sim_out/charts/%s_card_swap.csv" % tag
	if not FileAccess.file_exists(path):
		return {}
	var out := {}
	var lines := FileAccess.get_file_as_string(path).split("\n", false)
	if lines.size() < 2:
		return out
	var header := lines[0].split(",")
	var ib := header.find("build"); var ic := header.find("card")
	var iv := header.find("d_dpt_median") if header.find("d_dpt_median") >= 0 else header.find("d_dpt")
	if ib < 0 or ic < 0 or iv < 0:
		return out
	for i in range(1, lines.size()):
		var f := lines[i].split(",")
		if f.size() > maxi(ib, maxi(ic, iv)) and f[ib] == build:
			out[f[ic]] = float(f[iv])
	return out

static func _matches(card: Dictionary, recipe: Dictionary, type_name: String) -> bool:
	if type_name == "OFFENSIVE":
		if not card["offensive"]:
			return false
	elif card["type"] != type_name:
		return false
	var school := str(recipe.get("school", ""))
	if school != "" and card["school"] != school:
		return false
	var reach := str(recipe.get("reach", ""))
	if reach != "" and card["offensive"]:
		if (reach == "ranged") != bool(card["ranged"]):
			return false
	return true

static func _theme_hits(card: Dictionary, words: Array, id: String) -> int:
	var hay := ("%s %s %s %s" % [id, card["name"], " ".join(card["keywords"]), card["text"]]).to_lower()
	var n := 0
	for w in words:
		if hay.find(str(w).to_lower()) >= 0:
			n += 1
	return n

static func _heuristic(card: Dictionary) -> float:
	return float(card["damage"] + card["block"] + card["heal"]) / float(maxi(1, int(card["tempo"]))) - float(card["mana"]) * 0.02

## Build the 12-card list for a recipe on a build. Deterministic.
## mythic_slots: how many MYTHIC cards the deck may still hold (the game
## allows level / 15, and engraved mythics count against it).
static func generate(recipe: Dictionary, character: String, build: String, level: int, mythic_slots: int = 0) -> Array:
	var cards := pool()
	var mythics_left := mythic_slots
	var uplift := measured_uplift(character, build, level)
	var exclude: Array = recipe.get("exclude", [])
	var prefer: Array = recipe.get("prefer", [])
	var theme: Array = recipe.get("theme", [])
	var max_copies: int = int(recipe.get("max_copies", 2))
	var shape: Dictionary = recipe.get("shape", {"ATTACK": 6, "DEFENSE": 3, "UTILITY": 3})
	var deck: Array = []
	var copies := {}
	var order: Array = shape.keys()
	for type_name in order:
		var want: int = int(shape[type_name])
		var cands: Array = []
		for id in cards:
			if id in exclude or not _matches(cards[id], recipe, str(type_name)):
				continue
			var pi: int = prefer.find(id)
			var hits := _theme_hits(cards[id], theme, id)
			var score: float = uplift[id] if uplift.has(id) else _heuristic(cards[id])
			cands.append([1 if (hits > 0 or pi >= 0) else 0, (prefer.size() - pi) if pi >= 0 else 0, hits, score, id])
		cands.sort_custom(func(a, b):
			for i in range(4):
				if a[i] != b[i]:
					return a[i] > b[i]
			return a[4] < b[4])
		var got := 0
		var pass_i := 0
		while got < want and pass_i < max_copies and not cands.is_empty():
			for c in cands:
				if got >= want:
					break
				var id: String = c[4]
				var cap: int = Card.max_deck_copies(id)
				var have: int = int(copies.get(id, 0))
				if have > pass_i or (cap >= 0 and have >= cap) or have >= max_copies:
					continue
				if cards[id]["rarity"] == "Mythic":
					if mythics_left <= 0:
						continue
					mythics_left -= 1
				deck.append(id)
				copies[id] = have + 1
				got += 1
			pass_i += 1
	# Any shortfall (a type with too few legal cards) is filled from the whole pool by score.
	if deck.size() < DECK_SIZE:
		var rest: Array = []
		for id in cards:
			if id in exclude:
				continue
			rest.append([uplift[id] if uplift.has(id) else _heuristic(cards[id]), id])
		rest.sort_custom(func(a, b): return a[0] > b[0] if a[0] != b[0] else a[1] < b[1])
		for r in rest:
			if deck.size() >= DECK_SIZE:
				break
			var cap: int = Card.max_deck_copies(r[1])
			var have: int = int(copies.get(r[1], 0))
			if (cap >= 0 and have >= cap) or have >= max_copies:
				continue
			if cards[r[1]]["rarity"] == "Mythic":
				if mythics_left <= 0:
					continue
				mythics_left -= 1
			deck.append(r[1])
			copies[r[1]] = have + 1
	return deck.slice(0, DECK_SIZE)
