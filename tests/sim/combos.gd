extends RefCounted

## The combo registry (Milestone 5). Each entry is a macro-action the
## combo_planner can evaluate as a unit — a setup card and the payoff it
## enables, in order — including when it spans two bars (setup this bar,
## payoff next).
##
##   {"id": String,                 a name for the summary
##    "cards": [card ids in order], setup first, payoff last
##    "preconditions": {            all optional
##        "target": "enemy",        the payoff wants a living enemy in range
##        "min_mana": int,          mana the whole sequence needs
##        "enemy_armor_min": int},  only worth it against plate
##    "payoff": float}              expected gain over a bar beyond the parts
##                                  (the 3b synergy, damage per tempo × 5)
##
## ENTRIES comes from the 3b sweep through tools/sim_analysis/promote_combos.py
## (combos_promoted.gd). The registry biases the planner toward combos we
## already know exist — a floor, not a ceiling. 3b keeps running with the
## unaided planner (registry empty) as the discovery channel; a synergy is
## promoted only once it has shown up there. `extra` is for tests and
## one-off experiments (SimCombos.register) and is never promoted by itself.

const PROMOTED := preload("res://tests/sim/combos_promoted.gd").ENTRIES

static var extra: Array = []

static func registry() -> Array:
	return PROMOTED + extra

static func register(entry: Dictionary) -> void:
	extra.append(entry)

static func clear_extra() -> void:
	extra.clear()

## Whether the entry's preconditions hold on this state.
static func preconditions_ok(entry: Dictionary, state: SimState) -> bool:
	var pre: Dictionary = entry.get("preconditions", {})
	if str(pre.get("target", "")) == "enemy" and state.nearest_enemy_index() < 0:
		return false
	if int(pre.get("min_mana", 0)) > state.player_mana:
		return false
	if pre.has("enemy_armor_min"):
		var ok := false
		for e in state.enemies:
			if int(e["armor"]) >= int(pre["enemy_armor_min"]):
				ok = true
		if not ok:
			return false
	return true

## Hand indices holding each of the entry's cards (-1 when not held); a card
## id held twice counts once.
static func held_indices(entry: Dictionary, state: SimState, exclude: Dictionary = {}) -> Array:
	var out: Array = []
	var taken := {}
	for cid in entry["cards"]:
		var found := -1
		for h in state.hand:
			var i := int(h["index"])
			if str(h["id"]) == str(cid) and not taken.has(i) and not exclude.has(i):
				found = i
				break
		if found >= 0:
			taken[found] = true
		out.append(found)
	return out

## How many of the entry's cards (not held) wait in the draw pile — the
## player knows their deck list.
static func in_deck_count(entry: Dictionary, state: SimState, held: Array) -> int:
	var n := 0
	var pile: Array = state.main.deck_manager.draw_pile
	for k in range(entry["cards"].size()):
		if held[k] >= 0:
			continue
		for c in pile:
			if c.card_id == str(entry["cards"][k]):
				n += 1
				break
	return n
