extends SceneTree

## Slot labels: any card may sit in the deck; only a LABELED card may be
## enchanted into an item, and only into a slot one of its labels names. A
## card can carry several labels. Unlabeled cards are deck-only. Engrave
## cards keep their rule (slot only) and therefore must be labeled.
## Run: godot --headless --path . --script tests/test_slot_labels.gd

const F := preload("res://tests/item_fixtures.gd")

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Slot labels test ===")
	var belt := F.belt()
	belt.card_slots = 1
	var helm := F.helm()
	var ring := F.ring()
	ring.card_slots = 1
	var sword := F.sword()
	sword.card_slots = 1
	var shield := F.shield()
	shield.card_slots = 1

	# Unlabeled: deck only.
	var slash := Card.create_slash()
	_check(not slash.is_slottable(), "Slash carries no slot label")
	_check(not belt.can_slot_card(slash) and not sword.can_slot_card(slash) and not helm.can_slot_card(slash),
		"an unlabeled card cannot be slotted anywhere — not even a sword")

	# Single label: its slot, nothing else.
	var pocket := Card.create_block()
	pocket.card_keyword = Card.CardKeyword.POCKET
	_check(pocket.slot_labels == [Card.CardKeyword.POCKET], "the single-label setter fills the label list")
	_check(belt.can_slot_card(pocket), "a Pocket card slots into a belt")
	_check(not helm.can_slot_card(pocket) and not ring.can_slot_card(pocket), "…but not a helm or ring")
	_check(not sword.can_slot_card(pocket), "a sword refuses a Pocket card")
	var sword_card := Card.create_slash()
	sword_card.card_keyword = Card.CardKeyword.SWORD
	_check(sword.can_slot_card(sword_card), "a Sword card slots into a sword")
	var chest := F._base("Test Plate", ItemData.ItemType.CHEST)
	chest.card_slots = 1
	_check(not chest.can_slot_card(sword_card), "chest armor refuses a Sword card")
	var bulwark := Card.create_block()
	bulwark.card_keyword = Card.CardKeyword.BULWARK
	_check(chest.can_slot_card(bulwark), "a Bulwark card slots into chest armor")
	var staff := F.staff()
	staff.card_slots = 1
	_check(not staff.can_slot_card(pocket), "a staff refuses a Pocket card")
	var staff_card := Card.create_heal()
	staff_card.card_keyword = Card.CardKeyword.STAFF
	_check(staff.can_slot_card(staff_card), "a Staff card slots into a staff")

	# Several labels: any of them opens its slot.
	var multi := Card.create_charge()  # deck-only on the sheet: a clean slate
	multi.add_slot_labels([Card.CardKeyword.CROWN, Card.CardKeyword.GEM, Card.CardKeyword.POCKET])
	_check(multi.slot_label_names() == "Crown / Gem / Pocket", "labels display joined (%s)" % multi.slot_label_names())
	_check(helm.can_slot_card(multi) and ring.can_slot_card(multi) and belt.can_slot_card(multi),
		"a Crown / Gem / Pocket card fits helms, rings and belts")
	_check(not shield.can_slot_card(multi), "…but not a shield (Buckler)")
	_check(multi.card_keyword == Card.CardKeyword.CROWN, "the legacy single-label view reads the first label")
	multi.add_slot_labels([Card.CardKeyword.GEM, Card.CardKeyword.NONE])
	_check(multi.slot_labels.size() == 3, "adding a duplicate or NONE changes nothing")

	# Explicit allow-lists on an item: any shared label will do.
	var quiver := F.quiver()  # allows ARROW only
	var arrow_pocket := Card.create_block()
	arrow_pocket.add_slot_labels([Card.CardKeyword.POCKET, Card.CardKeyword.ARROW])
	_check(quiver.can_slot_card(arrow_pocket), "an Arrow / Pocket card fits a quiver's Arrow allow-list")
	_check(not quiver.can_slot_card(pocket), "a Pocket-only card does not")

	# Shields want Buckler now.
	var buckler := Card.create_block()
	buckler.card_keyword = Card.CardKeyword.BUCKLER
	_check(shield.can_slot_card(buckler), "a Buckler card slots into a shield")

	# Engrave cards are slot-only, so every one of them must be labeled.
	var unlabeled_engraves: Array = []
	for m in (Card as Script).get_script_method_list():
		if m["name"].begins_with("create_") and m["args"].size() == 0:
			var c = (Card as Script).call(m["name"])
			if c is Card and c.requires_engraving and not c.is_slottable():
				unlabeled_engraves.append(c.card_id)
	_check(unlabeled_engraves.is_empty(), "every Engrave card carries a slot label (%s)" % [unlabeled_engraves])

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
