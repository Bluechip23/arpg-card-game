extends SceneTree

## Heavy Greedy Cheese, the thin-deck tax: reshuffling a discard pile of
## fewer than 3 cards leaves a Cheese in the discard; each Cheese in the hand
## makes every OTHER card there (other Cheese included) cost +100 mana and
## +2 tempo; playing it (100 mana, 5 tempo) erases it.
## Run: godot --headless --path . --script tests/test_greedy_cheese.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _count(pile: Array, id: String) -> int:
	var n := 0
	for c in pile:
		if c.card_id == id:
			n += 1
	return n

func _initialize() -> void:
	var stats := PlayerStats.new()
	stats.initialize(CharacterData.create_ryan())
	var dm := DeckManager.new()
	dm.connect_player_stats(stats)
	var cid := DeckManager.GREEDY_CHEESE_ID

	var cheese := Card.create_by_id(cid)
	_check(cheese != null and cheese.mana_cost == 100 and cheese.tempo_cost == 5 and cheese.erase_on_play,
		"the card: 100 mana, 5 tempo, erased when played")
	_check(Card.DROP_EXCLUDED_CARD_IDS.has(cid) and Card.GENERATED_CARD_IDS.has(cid) and not cheese.is_slottable(),
		"never drops, never sold, never slotted")

	# A thin discard (2 cards) reshuffles: one Cheese lands in the discard.
	dm.hand.clear(); dm.draw_pile.clear(); dm.discard_pile.clear()
	dm.discard_pile.append(Card.create_by_id("slash"))
	dm.discard_pile.append(Card.create_by_id("block"))
	var drawn = dm.draw_card()
	_check(drawn != null and _count(dm.discard_pile, cid) == 1 and dm.discard_pile.size() == 1,
		"a 2-card discard reshuffles and leaves one Cheese in the discard")
	_check(_count(dm.draw_pile, cid) == 0 and _count(dm.hand, cid) == 0, "the Cheese is not reshuffled in the same breath")

	# A 3-card discard does not.
	dm.hand.clear(); dm.draw_pile.clear(); dm.discard_pile.clear()
	for id in ["slash", "block", "heal"]:
		dm.discard_pile.append(Card.create_by_id(id))
	dm.draw_card()
	_check(_count(dm.discard_pile, cid) == 0, "a 3-card discard reshuffles clean")

	# An empty discard is not a reshuffle at all.
	dm.hand.clear(); dm.draw_pile.clear(); dm.discard_pile.clear()
	_check(dm.draw_card() == null and _count(dm.discard_pile, cid) == 0, "nothing to reshuffle, no Cheese")

	# The hand tax.
	dm.hand.clear(); dm.draw_pile.clear(); dm.discard_pile.clear()
	var slash := Card.create_by_id("slash")
	var c1 := Card.create_by_id(cid)
	var c2 := Card.create_by_id(cid)
	dm.hand.append(slash)
	var base_mana: int = int(dm.compute_play_cost(slash, 0)["mana"])
	_check(dm.greedy_tax(slash) == {"mana": 0, "tempo": 0}, "no Cheese, no tax")
	dm.hand.append(c1)
	_check(dm.greedy_tax(slash) == {"mana": 100, "tempo": 2}, "one Cheese: +100 mana, +2 tempo on the other card")
	_check(int(dm.compute_play_cost(slash, 0)["mana"]) == base_mana + 100, "the play cost carries the +100 (%d)" % int(dm.compute_play_cost(slash, 0)["mana"]))
	_check(dm.greedy_tax(c1) == {"mana": 0, "tempo": 0}, "a lone Cheese does not tax itself")
	dm.hand.append(c2)
	_check(dm.greedy_tax(slash) == {"mana": 200, "tempo": 4}, "two Cheese: +200 / +4 on the other card")
	_check(dm.greedy_tax(c1) == {"mana": 100, "tempo": 2} and dm.greedy_tax(c2) == {"mana": 100, "tempo": 2}, "each Cheese taxes the other")
	_check(int(dm.compute_play_cost(c1, 1)["mana"]) == 200, "a Cheese beside another costs 200 to clear")
	var outside := Card.create_by_id("block")
	dm.draw_pile.append(outside)
	_check(dm.greedy_tax(outside) == {"mana": 0, "tempo": 0}, "cards outside the hand are untouched")

	# Playing a Cheese erases it.
	stats.current_mana = 1000
	dm.hand.clear(); dm.draw_pile.clear(); dm.discard_pile.clear()
	dm.hand.append(Card.create_by_id(cid))
	var res: Dictionary = dm.play_card(0, null)
	_check(bool(res.get("played", false)) and _count(dm.hand, cid) + _count(dm.discard_pile, cid) + _count(dm.draw_pile, cid) == 0,
		"played, it is erased from the deck")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
