extends SceneTree

## Verifies the Engrave keyword: an engraved card refuses to play while it is
## not slotted into an item, and plays normally once it is; the two first-pass
## etchings carry the Swift/Crown keywords so boot and helm slots accept them.
## Run: godot --headless --path . --script tests/test_engrave.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Engrave keyword test ===")

	var stats = load("res://scripts/character/player_stats.gd").new()
	stats.initialize(CharacterData.create_ryan())
	var deck = DeckManager.new()
	deck.connect_player_stats(stats)

	# --- Unslotted: the card cannot be played ---
	var etch = Card.create_fleet_etching()
	_check(etch.requires_engraving, "Fleet Etching carries Engrave")
	_check(etch.card_keyword == Card.CardKeyword.SWIFT, "Fleet Etching is a Swift card")
	_check(Card.create_regal_etching().card_keyword == Card.CardKeyword.CROWN,
		"Regal Etching is a Crown card")
	deck.hand.append(etch)
	var result = deck.play_card(0, null)
	_check(not result["played"], "unslotted engraved card refuses to play")
	_check(deck.hand.size() == 1, "refused card stays in hand")

	# --- Boot and helm slots accept the keyworded etchings ---
	var boots = ItemData.new()
	boots.item_name = "Test Boots"
	boots.item_type = ItemData.ItemType.BOOTS
	boots.card_slots = 1
	_check(boots.can_slot_card(etch), "boot slot accepts the Swift etching")
	var helm = ItemData.new()
	helm.item_name = "Test Helm"
	helm.item_type = ItemData.ItemType.HELM
	helm.card_slots = 1
	_check(not helm.can_slot_card(etch), "helm slot refuses the Swift etching")
	_check(helm.can_slot_card(Card.create_regal_etching()), "helm slot accepts the Crown etching")

	# --- Slotted: the same card now plays ---
	boots.slot_card(etch)
	_check(etch.slotted_in_item == boots, "etching is slotted into the boots")
	var played = deck.play_card(0, null)
	_check(played["played"], "engraved card plays once slotted")

	# --- Deck exclusion: unslotted engraved cards are swept into storage ---
	var inv = Inventory.new()
	inv.player_stats = stats
	inv.deck_manager = deck
	deck.connect_inventory(inv)
	var stray = Card.create_regal_etching()
	deck.draw_pile.append(stray)
	deck.expel_unslotted_engraved()
	_check(not deck.draw_pile.has(stray), "sweep pulls the unslotted etching from the draw pile")
	_check(inv.stored_cards.has(stray), "the swept etching lands in the card inventory")

	# --- Storage -> deck is refused while unslotted ---
	var idx = inv.stored_cards.find(stray)
	_check(not inv.add_card_to_deck(idx, deck), "Add to Deck refuses an unslotted engraved card")
	_check(inv.stored_cards.has(stray), "the refused card stays in storage")

	# --- Enchanting from storage puts it in the item AND the deck ---
	helm.card_slots = 1
	_check(inv.enchant_card(stray, helm), "etching enchants into the helm from storage")
	_check(not inv.stored_cards.has(stray), "enchanted etching left storage")
	_check(deck.draw_pile.has(stray), "enchanted etching joined the draw pile")

	# --- Extracting sends it back out of the deck into storage ---
	inv.extract_card(helm, 0)
	_check(not deck.draw_pile.has(stray), "extracted etching left the deck")
	_check(inv.stored_cards.has(stray), "extracted etching returned to the card inventory")

	# --- Deck cap: 20 direct cards; item-owned cards ride past it free ---
	_check(deck.get_max_deck_size() == 20, "max deck size is 20")
	deck.draw_pile.clear()
	deck.hand.clear()
	deck.discard_pile.clear()
	for i in range(20):
		deck.draw_pile.append(Card.create_slash())
	_check(deck.get_deck_size() == 20 and deck.is_deck_full(), "20 direct cards fill the deck")
	inv.stored_cards.append(Card.create_block())
	var block_idx = inv.stored_cards.size() - 1
	_check(not inv.add_card_to_deck(block_idx, deck), "a 21st direct card is refused while full")
	# The slotted etching joins the deck WITHOUT counting toward the cap.
	_check(inv.enchant_card(stray, helm), "etching re-enchants into the helm at a full deck")
	_check(deck.draw_pile.has(stray), "the item card still joins the full deck")
	_check(deck.get_deck_size() == 20, "the slotted card does not count toward deck size")
	_check(deck.get_item_card_count() == 1, "one item card rides along past the cap")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
