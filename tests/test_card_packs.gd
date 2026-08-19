extends SceneTree

## Verifies card packs (tiered contents, counts, weights tables) and the
## rarity-based deck copy limits.
## Run: godot --headless --path . --script tests/test_card_packs.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Card pack + deck copy limit test ===")

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# --- Pack contents: count and rarity range per tier ---
	for tier in [ItemData.Rarity.COMMON, ItemData.Rarity.RARE,
			ItemData.Rarity.LEGENDARY, ItemData.Rarity.MYTHIC]:
		var pack := CardPack.create(tier)
		var cards: Array = pack.open(rng)
		var want: int = int(DropRates.PACK_CARD_COUNT[tier])
		_check(cards.size() == want,
			"%s holds %d cards (got %d)" % [pack.get_display_name(), want, cards.size()])
		var allowed: Array = DropRates.PACK_CARD_WEIGHTS[tier].keys()
		var all_allowed := true
		for c in cards:
			if not allowed.has(c.get_rarity()):
				all_allowed = false
		_check(all_allowed, "%s cards stay in the tier's rarity range" % pack.get_display_name())

	# --- Mythic pack never drops basics/commons ---
	var mythic_pack := CardPack.create(ItemData.Rarity.MYTHIC)
	var no_floor := true
	for _i in range(10):
		for c in mythic_pack.open(rng):
			if c.get_rarity() == Card.Rarity.BASIC or c.get_rarity() == Card.Rarity.COMMON:
				no_floor = false
	_check(no_floor, "mythic packs only hold rare+ cards")

	# --- Deck copy limits ---
	_check(Card.max_deck_copies("slash") == -1, "slash (basic) is unlimited")
	_check(Card.max_deck_copies("fireball") == 1, "fireball (legendary) caps at 1")
	_check(Card.max_deck_copies("charge") == 3, "charge (rare) caps at 3")

	var dm = load("res://scripts/cards/deck_manager.gd").new()
	_check(dm.can_add_copy("fireball"), "empty deck accepts a legendary")
	dm.discard_pile.append(Card.create_by_id("fireball"))
	_check(not dm.can_add_copy("fireball"), "second legendary copy is refused")
	_check(not dm.add_card_to_deck_from_id("fireball"), "add_card_to_deck_from_id honors the cap")
	for _i in range(20):
		dm.discard_pile.append(Card.create_by_id("slash"))
	_check(dm.can_add_copy("slash"), "21st slash is still welcome")
	_check(dm.count_copies_in_deck("slash") == 20, "copies counted across the deck")
	dm.free()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
