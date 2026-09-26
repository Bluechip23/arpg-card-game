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
	_check(Card.max_deck_copies("fireball") == 2, "fireball (legendary) caps at 2")
	_check(Card.max_deck_copies("charge") == 4, "charge (rare) caps at 4")
	_check(Card.max_deck_copies("mirror_mirror") == 1, "mirror mirror (mythic) caps at 1")

	# A deck manager wired to a real inventory so socketed copies count too.
	var data := CharacterData.create_brad()
	var stats = load("res://scripts/character/player_stats.gd").new()
	get_root().add_child(stats)
	stats.initialize(data)
	var inv = load("res://scripts/progression/inventory.gd").new()
	get_root().add_child(inv)
	inv.initialize(data.character_name)
	inv.connect_player_stats(stats)
	var dm = load("res://scripts/cards/deck_manager.gd").new()
	get_root().add_child(dm)
	dm.connect_player_stats(stats)
	dm.connect_inventory(inv)

	_check(dm.can_add_copy("fireball"), "empty deck accepts a legendary")
	dm.discard_pile.append(Card.create_by_id("fireball"))
	_check(dm.can_add_copy("fireball"), "a second legendary copy is allowed")
	dm.discard_pile.append(Card.create_by_id("fireball"))
	_check(not dm.can_add_copy("fireball"), "a third legendary copy is refused")
	_check(not dm.add_card_to_deck_from_id("fireball"), "add_card_to_deck_from_id honors the cap")
	for _i in range(20):
		dm.discard_pile.append(Card.create_by_id("slash"))
	_check(dm.can_add_copy("slash"), "21st slash is still welcome")
	_check(dm.count_copies_in_deck("slash") == 20, "copies counted across the deck")

	# Socketed copies count: three Charges in the deck plus one in a helm's
	# socket is the rare cap of four.
	for _i in range(3):
		dm.discard_pile.append(Card.create_by_id("charge"))
	_check(dm.can_add_copy("charge"), "three rares leave room for a fourth")
	var helm := ItemData.create_thick_steel_helm()
	helm.slotted_cards.append(Card.create_by_id("charge"))
	inv.stored_items.append(helm)
	_check(dm.count_copies_in_deck("charge") == 4, "a copy socketed in a carried item counts (got %d)" % dm.count_copies_in_deck("charge"))
	_check(not dm.can_add_copy("charge"), "the socketed copy fills the rare cap")

	# Mythic cards as a group follow the mythic-item allowance (level / 15).
	stats.current_level = 1
	_check(inv.get_mythic_capacity() == 0 and not dm.can_add_copy("mirror_mirror"), "level 1 allows no mythic cards in the deck")
	stats.current_level = 30
	_check(inv.get_mythic_capacity() == 2 and dm.can_add_copy("mirror_mirror"), "level 30 allows two mythic cards")
	dm.discard_pile.append(Card.create_by_id("mirror_mirror"))
	_check(not dm.can_add_copy("mirror_mirror"), "the same mythic never has a second copy")
	_check(dm.can_add_copy("god_of_thunder"), "a different mythic fits under the allowance")
	helm.slotted_cards.append(Card.create_by_id("god_of_thunder"))
	_check(dm.count_mythic_cards() == 2 and not dm.can_add_copy("if_pigs_could_fly"), "a mythic socketed in gear uses up the allowance")

	dm.queue_free()
	inv.queue_free()
	stats.queue_free()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
