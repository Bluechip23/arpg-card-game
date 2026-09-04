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

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
