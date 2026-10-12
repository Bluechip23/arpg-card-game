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
		"recipes": recipes(character).keys(), "card_pool": SimDeckBuilder.legal_ids(),
		"tactics": tactics(character).keys(), "item_pool": item_pool()}

## The tactics a character can take: DEFAULT_TACTICS merged with the
## library's TACTICS, with passive weights resolved from the character's
## tree when the entry gives words instead of ids.
static func tactics(character: String) -> Dictionary:
	var lib := library(character)
	var own: Dictionary = lib.get_script_constant_map().get("TACTICS", {}) if lib else {}
	var out := _merged(DEFAULT_TACTICS, own)
	var text := {}
	for name in out:
		var t: Dictionary = out[name]
		if t.has("passives") or not t.has("passive_words"):
			continue
		if text.is_empty():
			text = tree_passive_text(character)
		var ps := {}
		for pid in text:
			for w in t["passive_words"]:
				if text[pid].find(str(w)) >= 0:
					ps[pid] = 3
		t["passives"] = ps
	return out

## Every item a stored build can be tested with: each zero-argument ItemData
## factory of the given rarities that goes in an equipment slot (scrolls do
## not). A new item enters the item sweep the moment its factory exists.
static func item_pool(rarities: Array = ["MYTHIC", "LEGENDARY"]) -> Array:
	var out: Array = []
	var script: Script = ItemData
	for m in script.get_script_method_list():
		var mn: String = m["name"]
		if not mn.begins_with("create_") or m["args"].size() != 0:
			continue
		var it = script.call(mn)
		if not (it is ItemData) or it.item_type == ItemData.ItemType.SCROLL:
			continue
		if ItemData.Rarity.keys()[it.rarity] in rarities:
			out.append(mn.substr(7))
	out.sort()
	return out

## Where a swapped-in item goes: its natural slot (main hand for weapons,
## off hand for shields and quivers, slot 0 for everything else).
static func _swap_slot(it: ItemData) -> int:
	if it.item_type == ItemData.ItemType.QUIVER:
		return 1
	if it.item_type == ItemData.ItemType.WEAPON and it.weapon_subtype == ItemData.WeaponSubtype.SHIELD:
		return 1
	return 0

## Replace the same-type, same-slot entry of `entries` with item `id`; a
## two-hand-only weapon also clears the off hand (a bow keeps its quiver).
## Returns the id it replaced ("" when it was added to an empty slot).
static func _place_item(entries: Array, id: String) -> String:
	var it: ItemData = (ItemData as Script).call("create_%s" % id)
	# Already part of the set (in any slot, or as a mythic's fallback): the
	# build keeps it where it is; compose then makes sure it is worn.
	for i in range(entries.size()):
		var e: Array = entries[i]
		if str(e[0]) == id:
			return ""
		if e.size() > 2 and str(e[2]) == id:
			entries[i] = [id, int(e[1])]
			return str(e[0])
	var slot := _swap_slot(it)
	var weapon_like := it.item_type in [ItemData.ItemType.WEAPON, ItemData.ItemType.QUIVER]
	var replaced := ""
	for i in range(entries.size()):
		var e: Array = entries[i]
		var et := _item_type(str(e[0]))
		var e_weapon_like := et in [ItemData.ItemType.WEAPON, ItemData.ItemType.QUIVER]
		var same_kind := (et == it.item_type) or (weapon_like and e_weapon_like)
		if same_kind and (int(e[1]) if e.size() > 1 else 0) == slot:
			# The entry's fallback (the piece worn when its mythic does not fit)
			# is reported too, so its engravings can follow the swap.
			replaced = str(e[0]) + ("|" + str(e[2]) if e.size() > 2 else "")
			entries[i] = [id, slot]
			break
	if replaced == "" and not entries.has([id, slot]):
		entries.append([id, slot])
	if Inventory.is_two_hand_only(it):
		var keep_quiver := it.weapon_subtype == ItemData.WeaponSubtype.BOW
		for i in range(entries.size() - 1, -1, -1):
			var e: Array = entries[i]
			if str(e[0]) == id or (int(e[1]) if e.size() > 1 else 0) != 1:
				continue
			var et := _item_type(str(e[0]))
			if et == ItemData.ItemType.WEAPON or (et == ItemData.ItemType.QUIVER and not keep_quiver):
				entries.remove_at(i)
	return replaced

## The engraved cards of `from_id` that also fit item `to_id` (labels and
## slot count, by the item's own can_slot_card on a scratch instance).
static func _carry_engravings(cards: Array, to_id: String) -> Array:
	var it: ItemData = (ItemData as Script).call("create_%s" % to_id)
	var kept: Array = []
	var dm := DeckManager.new()
	for cid in cards:
		var c = dm._create_card_from_id(str(cid))
		if c != null and it.can_slot_card(c):
			it.slot_card(c)
			kept.append(cid)
	dm.free()
	return kept

static func _item_type(id: String) -> int:
	var script: Script = ItemData
	if not SimScenario.script_has(script, "create_%s" % id):
		return -1
	var it = script.call("create_%s" % id)
	return int(it.item_type) if it is ItemData else -1

## Deck recipes every character gets (cards are universal): shape-described
## decks the generator fills from the whole pool (see SimDeckBuilder). A
## library's DECK_RECIPES adds to or overrides these by name.
const DEFAULT_RECIPES := {
	"dagger_rush": {"shape": {"ATTACK": 7, "DEFENSE": 3, "UTILITY": 2}, "school": "PHYSICAL", "reach": "melee",
		"theme": ["dagger", "slice", "strike", "bleed"]},
	"poisoner": {"shape": {"ATTACK": 3, "UTILITY": 6, "DEFENSE": 3}, "theme": ["poison", "potion", "toxin"]},
	"discard_mill": {"shape": {"ATTACK": 3, "UTILITY": 7, "DEFENSE": 2}, "theme": ["discard"]},
	"ghost": {"shape": {"ATTACK": 5, "UTILITY": 5, "DEFENSE": 2}, "theme": ["invisib", "blink", "shadow", "swap", "displace", "teleport"]},
	"archer": {"shape": {"ATTACK": 8, "UTILITY": 2, "DEFENSE": 2}, "reach": "ranged", "theme": ["arrow", "shot", "bow"]},
	"instants": {"shape": {"REACTION": 4, "ATTACK": 5, "DEFENSE": 3}},
	"caster": {"shape": {"ATTACK": 6, "UTILITY": 4, "DEFENSE": 2}, "school": "SPELL"},
	"top_twelve": {"shape": {"OFFENSIVE": 6, "DEFENSE": 3, "UTILITY": 3}},
}

## Tactics every character gets: cards into the deck's tail and an item
## into its slot. Passive ranks come from the character's own tree — the
## passives whose text names the tactic's words — unless the library's
## TACTICS entry lists them; a library entry overrides these field by field.
const DEFAULT_TACTICS := {
	"invisibility": {"deck": ["shadows", "shadows", "blink"], "items": [["shadow_obi", 0]],
		"passive_words": ["invisib", "displac"], "slotted": {"shadow_obi": ["shuriken", "poke"]}},
	"poison": {"deck": ["poison_bomb", "poison_bomb", "hemotoxins"], "items": [["alchemeist_belt", 0]],
		"passive_words": ["poison"], "slotted": {"alchemeist_belt": ["poison_bomb", "poisoned_blood"]}},
	"discard": {"deck": ["discard", "volatile_mixture", "volatile_mixture"], "passive_words": ["discard"]},
	"mobility": {"deck": ["blink", "reposition", "bob_and_weave"], "items": [["houdinis_slippers", 0]],
		"passive_words": ["spaces moved", "movement", "instant is played"], "slotted": {"houdinis_slippers": ["blink"]}},
	"burst": {"deck": ["exhausted_assault", "multishot", "consecutive_snap"], "passive_words": ["first strike", "first attack"]},
}

static func _merged(defaults: Dictionary, overrides: Dictionary) -> Dictionary:
	var out := {}
	for k in defaults:
		out[k] = (defaults[k] as Dictionary).duplicate(true)
	for k in overrides:
		if out.has(k):
			for f in overrides[k]:
				out[k][f] = overrides[k][f]
		else:
			out[k] = (overrides[k] as Dictionary).duplicate(true)
	return out

static func recipes(character: String) -> Dictionary:
	var lib := library(character)
	var own: Dictionary = lib.get_script_constant_map().get("DECK_RECIPES", {}) if lib else {}
	return _merged(DEFAULT_RECIPES, own)

## {passive id: its tree description} for the character.
static func tree_passive_text(character: String) -> Dictionary:
	var tree = SkillTreeData.create_tree_for(character.capitalize(), 50)
	var out := {}
	for row in tree.rows:
		for opt in row.options:
			if opt.option_type == SkillTreeData.OptionType.PASSIVE and opt.passive_id != "":
				out[opt.passive_id] = str(opt.description).to_lower()
	return out

## How many slots of an item type the character has (the game's own
## Inventory.initialize decides: Ryan 2 belts, Jeremy 3 rings, Cory 2 gauntlets).
static func slot_count(character: String, item_type: int) -> int:
	var inv := Inventory.new()
	inv.initialize(character.capitalize())
	var n: int = inv._get_max_slots(item_type)
	inv.free()
	return n

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
## `allowed` (optional): the only mythics that may be worn; any other mythic
## takes its fallback even with room under the cap. The item sweep uses it
## so one swapped item never lets a second set mythic come off its fallback.
static func fit_items(entries: Array, level: int, catalog_mythics: Dictionary, allowed: Dictionary = {}) -> Dictionary:
	var cap: int = int(level / LEVELS_PER_MYTHIC)
	var used := 0
	var items: Array = []
	var dropped: Array = []
	for e in entries:
		var id: String = str(e[0])
		var slot: int = int(e[1]) if e.size() > 1 else 0
		var fallback: String = str(e[2]) if e.size() > 2 else ""
		if catalog_mythics.get(id, false):
			if used < cap and (allowed.is_empty() or allowed.has(id)):
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
	# A tactic overlays the build: its items replace the same-type, same-slot
	# entries (unless already worn), its passive weights join the set, its
	# cards replace the deck's tail, its engravings join the slotted map.
	var entries: Array = (lib.ITEM_SETS[items_name] as Array).duplicate(true)
	var passive_weights: Dictionary = (lib.PASSIVES[base["passives"]] as Dictionary).duplicate()
	var tactic: Dictionary = {}
	if parts.has("tactic") and str(parts["tactic"]) != "":
		tactic = tactics(character).get(str(parts["tactic"]), {})
		if tactic.is_empty():
			push_error("[SIM] %s has no tactic '%s'" % [character, str(parts["tactic"])])
		else:
			base["tactic"] = str(parts["tactic"])
			for ti in tactic.get("items", []):
				var tid := str(ti[0])
				var tslot: int = int(ti[1]) if ti.size() > 1 else 0
				if tslot >= slot_count(character, _item_type(tid)):
					tslot = 0
				var worn := false
				for e in entries:
					if str(e[0]) == tid or (e.size() > 2 and str(e[2]) == tid):
						worn = true
				if worn:
					continue
				var ttype := _item_type(tid)
				var replaced := false
				for i in range(entries.size()):
					var e: Array = entries[i]
					if _item_type(str(e[0])) == ttype and (int(e[1]) if e.size() > 1 else 0) == tslot:
						entries[i] = [tid, tslot]
						replaced = true
						break
				if not replaced:
					entries.append([tid, tslot])
			for pid in tactic.get("passives", {}):
				passive_weights[pid] = float(passive_weights.get(pid, 0)) + float(tactic["passives"][pid])
	# One item swapped in (the item sweep): it takes its natural slot and is
	# always worn — a mythic takes a mythic slot ahead of the set's own.
	var swapped_item := ""
	var replaced_item := ""
	var allowed_mythics := {}
	if parts.has("item") and str(parts["item"]) != "":
		# The mythics the unswapped build wears: the swap may displace one of
		# them, never add another.
		var base_mythics := {}
		for e in entries:
			base_mythics[str(e[0])] = is_mythic(str(e[0]))
		for it in fit_items(entries, level, base_mythics)["items"]:
			if base_mythics.get(str(it[0]), false):
				allowed_mythics[str(it[0])] = true
		swapped_item = str(parts["item"])
		if not SimScenario.script_has(ItemData, "create_%s" % swapped_item):
			push_error("[SIM] no item '%s'" % swapped_item)
			swapped_item = ""
		else:
			replaced_item = _place_item(entries, swapped_item)
			base["item"] = swapped_item
	var mythics := {}
	for e in entries:
		mythics[str(e[0])] = is_mythic(str(e[0]))
	if swapped_item != "" and mythics.get(swapped_item, false):
		# Move it to the front so fit_items spends the first mythic slot on it.
		for i in range(entries.size()):
			if str(entries[i][0]) == swapped_item:
				var e = entries[i]
				entries.remove_at(i)
				entries.push_front(e)
				break
		allowed_mythics[swapped_item] = true
	if swapped_item == "":
		allowed_mythics = {}
	elif allowed_mythics.is_empty():
		allowed_mythics["__none__"] = true   # the build wore no mythic: keep it that way
	var fitted := fit_items(entries, level, mythics, allowed_mythics)
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
		for k in passive_weights:
			if str(k) != focus:
				rest[k] = passive_weights[k]
		if rest.is_empty():
			for k in tree_passives(character):
				if str(k) != focus:
					rest[k] = 1
		ranks.merge(spread(rest, passive_points - ranks[focus], max_rank))
	else:
		ranks = spread(passive_weights, passive_points, max_rank)
	# Slotted cards only for items that made the cut.
	var slotted := {}
	var worn := {}
	for it in fitted["items"]:
		worn[it[0]] = true
	for item_id in lib.SLOTTED.get(slot_name, {}):
		if worn.has(item_id):
			slotted[item_id] = (lib.SLOTTED[slot_name][item_id] as Array).duplicate()
	for item_id in tactic.get("slotted", {}):
		if worn.has(item_id) and not slotted.has(item_id):
			slotted[item_id] = (tactic["slotted"][item_id] as Array).duplicate()
	if swapped_item != "" and worn.has(swapped_item) and not slotted.has(swapped_item):
		var from_cards: Array = []
		for rid in replaced_item.split("|", false):
			for cid in lib.SLOTTED.get(slot_name, {}).get(rid, []):
				if not cid in from_cards:
					from_cards.append(cid)
		var kept := _carry_engravings(from_cards, swapped_item)
		if not kept.is_empty():
			slotted[swapped_item] = kept
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
	if not tactic.is_empty():
		# Copy caps count the deck and the engravings; a tactic card that
		# would exceed its cap leaves the original tail card in place.
		var tcards: Array = tactic.get("deck", [])
		for i in range(tcards.size()):
			var cid := str(tcards[i])
			var have := deck.count(cid)
			for item_id in slotted:
				have += (slotted[item_id] as Array).count(cid)
			var cap: int = Card.max_deck_copies(cid)
			var at: int = deck.size() - tcards.size() + i
			if cap >= 0 and have >= cap:
				continue
			if at >= 0 and at < deck.size():
				deck[at] = cid
			else:
				deck.append(cid)
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
			"sphere_fill": true,
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
