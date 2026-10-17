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
	var etch = Card.create_by_id("fleet_etching")
	_check(etch.requires_engraving, "Fleet Etching carries Engrave")
	_check(etch.card_keyword == Card.CardKeyword.SWIFT, "Fleet Etching is a Swift card")
	_check(Card.create_by_id("regal_etching").card_keyword == Card.CardKeyword.CROWN,
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
	_check(helm.can_slot_card(Card.create_by_id("regal_etching")), "helm slot accepts the Crown etching")

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
	var stray = Card.create_by_id("regal_etching")
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

	# --- Deck cap: 12 direct cards; item-owned cards ride past it free ---
	_check(deck.get_max_deck_size() == 12, "max deck size is 12")
	deck.draw_pile.clear()
	deck.hand.clear()
	deck.discard_pile.clear()
	for i in range(12):
		deck.draw_pile.append(Card.create_by_id("slash"))
	_check(deck.get_deck_size() == 12 and deck.is_deck_full(), "12 direct cards fill the deck")
	inv.stored_cards.append(Card.create_by_id("block"))
	var block_idx = inv.stored_cards.size() - 1
	_check(not inv.add_card_to_deck(block_idx, deck), "a 13th direct card is refused while full")
	# The slotted etching joins the deck WITHOUT counting toward the cap.
	_check(inv.enchant_card(stray, helm), "etching re-enchants into the helm at a full deck")
	_check(deck.draw_pile.has(stray), "the item card still joins the full deck")
	_check(deck.get_deck_size() == 12, "the slotted card does not count toward deck size")
	_check(deck.get_item_card_count() == 1, "one item card rides along past the cap")

	# --- Total cap: 12 base + slotted cards may reach 25, never more ---
	_check(deck.get_max_total_deck_size() == 25, "the total deck cap is 25")
	# A weapon that takes any Crown card, with room for twenty: worn in hand.
	var rack = ItemData.new()
	rack.item_name = "Test Rack"
	rack.item_type = ItemData.ItemType.WEAPON
	rack.weapon_subtype = ItemData.WeaponSubtype.OTHER
	rack.card_slots = 20
	inv._init_slot_arrays()
	_check(inv.equip_item(rack, 0), "the rack is worn in hand")
	# 12 base + the helm's etching = 13; twelve more Crown etchings fill it.
	var added := 0
	for i in range(12):
		var e = Card.create_by_id("regal_etching")
		inv.stored_cards.append(e)
		if inv.enchant_card(e, rack):
			added += 1
	_check(added == 12 and deck.get_total_deck_size() == 25 and deck.is_total_deck_full(),
		"twelve etchings slot in from storage up to 25 in all (%d added, total %d)" % [added, deck.get_total_deck_size()])
	_check(deck.get_deck_size() == 12, "the base count is still 12")
	var extra = Card.create_by_id("regal_etching")
	inv.stored_cards.append(extra)
	_check(not inv.enchant_card(extra, rack) and inv.stored_cards.has(extra) and not deck.draw_pile.has(extra),
		"a 26th card is refused at the slot and stays in the card inventory")
	_check(inv.last_refusal.begins_with("Deck is full"), "the refusal names the cap (%s)" % inv.last_refusal)

	# A base card already in the deck can still be slotted at the cap: it
	# moves from the base count to the slotted count and the total stays 25.
	var labeled = null
	for c in Card.get_all_cards():
		if c.is_slottable() and not c.requires_engraving and rack.can_slot_card(c):
			labeled = Card.create_by_id(c.card_id)
			break
	if labeled != null:
		deck.draw_pile.remove_at(deck.draw_pile.size() - 1)  # one slash out, the labeled card in
		deck.draw_pile.append(labeled)
		_check(deck.get_total_deck_size() == 25, "swapping a base card keeps the total at 25")
		_check(inv.enchant_card(labeled, rack) and deck.get_total_deck_size() == 25 and deck.get_deck_size() == 11,
			"a deck card slotted at the cap just moves counts (base %d, total %d)" % [deck.get_deck_size(), deck.get_total_deck_size()])

	# A granted card still joins a full deck: it counts toward neither cap.
	var belt = ItemData.new()
	belt.item_name = "Test Belt"
	belt.item_type = ItemData.ItemType.BELT
	belt.granted_card_ids.append("dagger_throw")
	var total_before: int = deck.get_total_deck_size()
	var items_before: int = deck.get_item_card_count()
	_check(inv.equip_item(belt, 0), "a card-granting belt equips at a full deck")
	_check(deck.get_item_card_count() == items_before + 1 and deck.get_total_deck_size() == total_before,
		"its granted card is in play and counts toward neither cap (total %d)" % deck.get_total_deck_size())

	# Gear whose slotted cards would push the deck past the cap is refused.
	var crown = ItemData.new()
	crown.item_name = "Test Crown"
	crown.item_type = ItemData.ItemType.HELM
	crown.card_slots = 1
	_check(crown.slot_card(Card.create_by_id("regal_etching")), "a crown with an etching slotted while in the bag")
	_check(not inv.equip_item(crown, 0) and inv.equipped_helms[0] == null,
		"the crown is refused at a full deck (%s)" % inv.last_refusal)
	_check(inv.extract_card(rack, 0) != null and deck.get_total_deck_size() == 24, "unslotting one card frees a place (total %d)" % deck.get_total_deck_size())
	_check(inv.equip_item(crown, 0) and deck.get_total_deck_size() == 25, "now the crown goes on and its card is in play")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
