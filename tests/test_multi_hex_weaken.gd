extends SceneTree

## Verifies the multi-card Hex rework and the player-side Weakened debuff:
## Hex — each application is its own instance claiming its own card; two hexes
## land on two different cards; surcharge reads per card; playing a hexed card
## clears only the hexes riding it; a hex follows its card when an earlier
## card leaves the hand; more hexes than cards stack onto shared cards.
## Weakened — -30% damage dealt while stacks remain (stacking with Cursed,
## capped); a stack is 5 tempo on the debuff's own clock — attacks never burn
## one — expiring when the last stack falls.
## Run: godot --headless --path . --script tests/test_multi_hex_weaken.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _hexed_indices(dm: DebuffManager, deck: DeckManager) -> Array:
	var out: Array = []
	for h in dm.get_hexed_debuffs():
		out.append(deck.hand.find(h.affected_card))
	out.sort()
	return out

func _initialize() -> void:
	print("=== Multi-hex + Weakened test ===")

	var stats = load("res://scripts/character/player_stats.gd").new()
	stats.initialize(CharacterData.create_ryan())
	var dm = DebuffManager.new()
	dm.initialize(stats)

	var deck = DeckManager.new()
	deck.connect_player_stats(stats)

	# --- Two hexes are two instances, each claiming its own card ---
	for i in range(3):
		deck.hand.append(Card.create_slash())
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.HEXED, 30, 25))
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.HEXED, 30, 25))
	_check(dm.get_hexed_debuffs().size() == 2, "two hex applications = two instances")
	deck.assign_hexed_locked_cards(dm)
	var idx: Array = _hexed_indices(dm, deck)
	_check(idx[0] != idx[1], "the two hexes claim DIFFERENT cards (%s)" % str(idx))
	_check(dm.is_card_hexed(idx[0]) and dm.is_card_hexed(idx[1]), "both cards read as hexed")
	_check(dm.get_hexed_mana_increase(idx[0]) == 30, "per-card surcharge is 30")
	var unhexed := -1
	for i in range(3):
		if not dm.is_card_hexed(i):
			unhexed = i
	_check(unhexed >= 0 and dm.get_hexed_mana_increase(unhexed) == 0, "the unhexed card pays nothing")

	# --- Playing a hexed card clears only ITS hexes ---
	var kept: Card = deck.hand[idx[0]]
	dm.remove_hexes_on_card(deck.hand[idx[1]])
	_check(dm.get_hexed_debuffs().size() == 1, "playing one hexed card clears one hex")
	_check(dm.get_hexed_debuffs()[0].affected_card == kept, "the other hex survives")

	# --- A hex follows its card when an earlier card leaves the hand ---
	var before: int = deck.hand.find(kept)
	var leaver: int = 0 if before > 0 else 2
	deck.discard_card_from_hand(deck.hand[leaver])
	_check(dm.card_is_hexed(kept) and dm.is_card_hexed(deck.hand.find(kept)),
		"hex stays on its card wherever it slides (%d -> %d)" % [before, deck.hand.find(kept)])
	dm.remove_hexes_on_card(kept)

	# --- More hexes than cards: they stack onto shared cards ---
	deck.hand.clear()
	deck.hand.append(Card.create_slash())
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.HEXED, 30, 25))
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.HEXED, 30, 25))
	deck.assign_hexed_locked_cards(dm)
	_check(dm.get_hexed_mana_increase(0) == 60, "two hexes on a 1-card hand stack to +60")
	dm.remove_hexes_on_card(0)
	_check(dm.get_hexed_debuffs().is_empty(), "playing the card clears every hex on it")

	# --- Weakened: -30% damage, a stack is 5 tempo (attacks burn nothing) ---
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.WEAKENED, 2))
	_check(is_equal_approx(dm.get_damage_reduction_percent(), 0.3), "Weakened reduces damage 30%")
	dm.on_attack()
	_check(dm.has_debuff(Debuff.DebuffType.WEAKENED)
		and dm.get_debuff(Debuff.DebuffType.WEAKENED).value == 2, "an attack burns no stack")
	dm.advance_time(5)
	_check(dm.has_debuff(Debuff.DebuffType.WEAKENED)
		and dm.get_debuff(Debuff.DebuffType.WEAKENED).value == 1, "5 tempo sheds 1 stack")
	_check(is_equal_approx(dm.get_damage_reduction_percent(), 0.3), "still weakened with 1 stack left")
	dm.advance_time(5)
	_check(not dm.has_debuff(Debuff.DebuffType.WEAKENED), "Weakened gone after 10 tempo")
	_check(is_equal_approx(dm.get_damage_reduction_percent(), 0.0), "no reduction once worn off")

	# --- Weakened + Cursed stack ---
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.WEAKENED, 1, -1))
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.CURSED, 0, 15))
	_check(is_equal_approx(dm.get_damage_reduction_percent(), 0.5), "Weakened (30%) + Cursed (20%) = 50%")

	deck.free()
	dm.free()
	stats.free()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
