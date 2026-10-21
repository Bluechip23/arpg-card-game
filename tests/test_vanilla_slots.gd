extends SceneTree

## Vanilla (plain) card slots: an item's card_slots are its bonus slots and
## vanilla_slots its plain ones. Bonus slots fill first; a card in a plain slot
## joins the deck like any slotted card (engravings included) but gets the
## neutral on-self bonus; a card's slot is stamped for its whole stay. Also
## checks the Tome label is folded into Wand and the designer's slot table
## landed in the item data.
## Run: godot --headless --path . --script tests/test_vanilla_slots.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _sword_card(id: String, engrave: bool = false) -> Card:
	var c := Card.new()
	c.card_id = "test_%s" % id
	c.card_name = id
	c.card_type = Card.CardType.ATTACK
	c.base_damage = 5
	c.slot_labels = [Card.CardKeyword.SWORD]
	c.requires_engraving = engrave
	return c

func _initialize() -> void:
	var sword := ItemData.new()
	sword.item_name = "Test Sword"
	sword.item_type = ItemData.ItemType.WEAPON
	sword.weapon_subtype = ItemData.WeaponSubtype.SWORD
	sword.card_slots = 1
	sword.vanilla_slots = 2
	sword.on_self_damage = 3
	_check(sword.total_card_slots() == 3 and sword.has_card_slots() and sword.get_free_card_slots() == 3, "1 bonus + 2 plain = 3 slots")
	_check(ItemData.slot_words(sword) == "3 slots (1 bonus, 2 plain)", "slot phrase names the plain ones: %s" % ItemData.slot_words(sword))

	var a := _sword_card("a")
	var b := _sword_card("b")
	var c := _sword_card("c", true)
	var d := _sword_card("d")
	_check(sword.slot_card(a) and sword.slot_card(b) and sword.slot_card(c), "three cards slot (the third an engraving)")
	_check(not sword.can_slot_card(d), "a fourth is refused")
	_check(not sword.is_vanilla_slot(a) and sword.is_vanilla_slot(b) and sword.is_vanilla_slot(c), "bonus slot fills first, then the plain ones")
	_check(int(a.get_on_self_bonus().get("damage", 0)) == 3, "the bonus-slot card gets the rider (+3)")
	var osb_b: Dictionary = b.get_on_self_bonus()
	_check(int(osb_b.get("damage", -1)) == 0 and float(osb_b.get("damage_multiplier", 0.0)) == 1.0 and osb_b.has("apply_slow"),
		"a plain-slot card gets the neutral bonus with every key present")
	_check(c.get_on_self_bonus().get("damage", -1) == 0, "an engraving in a plain slot gets no rider either")

	# A neighbour leaving never moves a card: b stays plain, and the freed
	# bonus slot goes to the next card in.
	sword.unslot_card(0)
	_check(sword.is_vanilla_slot(b) and int(b.get_on_self_bonus().get("damage", -1)) == 0, "unslotting the bonus card leaves b in its plain slot")
	_check(sword.slot_card(d) and not sword.is_vanilla_slot(d) and int(d.get_on_self_bonus().get("damage", 0)) == 3, "the next card takes the freed bonus slot")

	# Slot at a chosen square (the manage-cards window's drag target).
	var pick := ItemData.new()
	pick.item_type = ItemData.ItemType.WEAPON
	pick.weapon_subtype = ItemData.WeaponSubtype.SWORD
	pick.card_slots = 1
	pick.vanilla_slots = 2
	pick.on_self_damage = 3
	var p1 := _sword_card("p1")
	var p2 := _sword_card("p2")
	_check(pick.can_slot_card_at(p1, 2) and pick.slot_card_at(p1, 2) and pick.is_vanilla_slot(p1), "a card dropped on square 2 takes the vanilla slot, leaving the bonus slot open")
	_check(not pick.can_slot_card_at(p2, 2) and not pick.can_slot_card_at(p2, 3) and pick.can_slot_card_at(p2, 0), "an occupied or missing square refuses; the open bonus square accepts")
	_check(pick.can_move_slotted_card_to(p1, 0) and not pick.can_move_slotted_card_to(p1, 2) and not pick.can_move_slotted_card_to(p2, 0), "a slotted card may move to a free square, not onto its own or as a stranger")
	pick.unslot_card(0)
	_check(pick.slot_card_at(p1, 0) and int(p1.get_on_self_bonus().get("damage", 0)) == 3, "moved onto the bonus square it gets the rider")
	var feral := ItemData.new()
	feral.item_type = ItemData.ItemType.WEAPON
	feral.weapon_subtype = ItemData.WeaponSubtype.OTHER
	feral.feral_weapon = true
	feral.card_slots = 2
	feral.vanilla_slots = 1
	feral.slot_colors = ["red", "blue"]
	var fire := _sword_card("fire")
	fire.element = "red"
	_check(not feral.can_slot_card_at(fire, 1) and feral.can_slot_card_at(fire, 0) and feral.can_slot_card_at(fire, 2), "a red card fits the red square and the vanilla square, not the blue one")
	# The window's squares: trim and label per slot kind.
	var CellScript = load("res://scripts/character/card_slot_cell.gd")
	_check(CellScript.kind_label(feral, 0) == "Red" and CellScript.kind_label(feral, 2) == "Vanilla" and CellScript.kind_label(pick, 0) == "On-self",
		"squares read Red / Vanilla / On-self")
	_check(CellScript.trim_for(feral, 1) == CellScript.TRIM["blue"] and CellScript.trim_for(pick, 1) == CellScript.TRIM["vanilla"] and CellScript.trim_for(pick, 0) == CellScript.TRIM["on_self"],
		"trim colours follow the slot kind")
	var cell = CellScript.new()
	root.add_child(cell)
	cell.setup_slot(null, pick, 2, null)
	var drop := {"kind": "card", "source": "pool", "card": p2, "item": pick, "slot_index": -1}
	_check(cell._can_drop_data(Vector2.ZERO, drop), "an empty vanilla square accepts a pool card")
	cell.setup_slot(null, pick, 0, p1)
	_check(not cell._can_drop_data(Vector2.ZERO, drop), "an occupied square refuses a drop")
	cell.queue_free()

	# Laurentius's ally-targeting rider is a bonus-slot thing.
	var spear := ItemData.new()
	spear.item_type = ItemData.ItemType.WEAPON
	spear.weapon_subtype = ItemData.WeaponSubtype.POLEARM
	spear.card_slots = 0
	spear.vanilla_slots = 1
	spear.on_self_self_targets_allies = true
	var s := Card.new()
	s.card_id = "test_self"
	s.card_type = Card.CardType.UTILITY
	s.target_types = ["self"]
	s.slot_labels = [Card.CardKeyword.SPEAR]
	spear.slot_card(s)
	_check(not s.target_types.has("ally"), "a plain slot does not grant Laurentius's ally targeting")

	# Tome folded into Wand.
	var book = ItemData.create("frost_book")
	var wand_card := Card.new()
	wand_card.card_id = "test_wand"
	wand_card.card_type = Card.CardType.ATTACK
	wand_card.slot_labels = [Card.CardKeyword.WAND]
	_check(book != null and book.total_card_slots() > 0 and book.can_slot_card(wand_card), "a tome takes a Wand card")
	var ae = Card.create_by_id("absorb_essence")
	_check(ae != null and not ae.slot_labels.has(Card.CardKeyword.TOME) and ae.slot_labels.has(Card.CardKeyword.WAND), "Absorb Essence carries Wand, not Tome")
	_check(Card.keyword_name(Card.CardKeyword.TOME) == "Wand", "the Tome label reads Wand")

	# The designer's table landed.
	var axe = ItemData.create("axes_axe")
	var theseus = ItemData.create("sword_of_theseus")
	var belt = ItemData.create("leather_belt")
	_check(axe != null and axe.card_slots == 0 and axe.vanilla_slots == 4 and axe.total_card_slots() == 4, "Axe's Axe: 4 plain slots")
	_check(theseus != null and theseus.card_slots == 5 and theseus.vanilla_slots == 2, "Sword of Theseus: 5 bonus + 2 plain")
	_check(belt != null and belt.vanilla_slots == 0 and belt.total_card_slots() == 1, "Leather belt: no plain slots")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
