extends SceneTree

## Verifies the multi-card Hex rework and the player-side Weakened debuff:
## Hex — each application is its own instance claiming its own card; two hexes
## land on two different cards; surcharge reads per card; playing a hexed card
## clears only the hexes riding it; indices shift when an earlier card leaves
## the hand; more hexes than cards stack onto shared cards.
## Weakened — -30% damage dealt while stacks remain (stacking with Cursed,
## capped), one stack burned per attack, expiring at zero.
## Run: godot --headless --path . --script tests/test_multi_hex_weaken.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _hexed_indices(dm: DebuffManager) -> Array:
	var out: Array = []
	for h in dm.get_hexed_debuffs():
		out.append(h.affected_card_index)
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
	var idx: Array = _hexed_indices(dm)
	_check(idx[0] != idx[1], "the two hexes claim DIFFERENT cards (%s)" % str(idx))
	_check(dm.is_card_hexed(idx[0]) and dm.is_card_hexed(idx[1]), "both cards read as hexed")
	_check(dm.get_hexed_mana_increase(idx[0]) == 30, "per-card surcharge is 30")
	var unhexed := -1
	for i in range(3):
		if not dm.is_card_hexed(i):
			unhexed = i
	_check(unhexed >= 0 and dm.get_hexed_mana_increase(unhexed) == 0, "the unhexed card pays nothing")

	# --- Playing a hexed card clears only ITS hexes ---
	dm.remove_hexes_on_card(idx[1])
	_check(dm.get_hexed_debuffs().size() == 1, "playing one hexed card clears one hex")
	_check(dm.get_hexed_debuffs()[0].affected_card_index == idx[0], "the other hex survives")

	# --- Indices shift when an earlier card leaves the hand ---
	var before: int = dm.get_hexed_debuffs()[0].affected_card_index
	if before > 0:
		dm.shift_hexed_indices(0)  # a card before it left the hand
		_check(dm.get_hexed_debuffs()[0].affected_card_index == before - 1,
			"hex follows its card down one slot")
	else:
		dm.shift_hexed_indices(2)  # a card after it left — no move
		_check(dm.get_hexed_debuffs()[0].affected_card_index == before,
			"hex unmoved when a later card leaves")
	dm.remove_hexes_on_card(dm.get_hexed_debuffs()[0].affected_card_index)

	# --- More hexes than cards: they stack onto shared cards ---
	deck.hand.clear()
	deck.hand.append(Card.create_slash())
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.HEXED, 30, 25))
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.HEXED, 30, 25))
	deck.assign_hexed_locked_cards(dm)
	_check(dm.get_hexed_mana_increase(0) == 60, "two hexes on a 1-card hand stack to +60")
	dm.remove_hexes_on_card(0)
	_check(dm.get_hexed_debuffs().is_empty(), "playing the card clears every hex on it")

	# --- Weakened: -30% damage, one stack per attack ---
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.WEAKENED, 2, -1))
	_check(is_equal_approx(dm.get_damage_reduction_percent(), 0.3), "Weakened reduces damage 30%")
	dm.on_attack()
	_check(dm.has_debuff(Debuff.DebuffType.WEAKENED)
		and dm.get_debuff(Debuff.DebuffType.WEAKENED).value == 1, "first attack burns 1 stack")
	_check(is_equal_approx(dm.get_damage_reduction_percent(), 0.3), "still weakened with 1 stack left")
	dm.on_attack()
	_check(not dm.has_debuff(Debuff.DebuffType.WEAKENED), "Weakened gone after its 2 attacks")
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
