extends SceneTree

## Unit test for the persistent hand-slot / stacking layer (HandSlots) and
## Card.get_stack_signature().
## Run: godot --headless --path . --script tests/test_hand_slots.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _slots(hs: HandSlots, hand: Array) -> Array:
	hs.reconcile(hand)
	return hs.build_groups(hand)

func _initialize() -> void:
	print("=== HandSlots test ===")

	# --- Identical cards share a signature; different cards do not ---
	var s1 := Card.create_slash()
	var s2 := Card.create_slash()
	var b1 := Card.create_block()
	_check(s1.get_stack_signature() == s2.get_stack_signature(), "two Slashes share a stack signature")
	_check(s1.get_stack_signature() != b1.get_stack_signature(), "Slash and Block differ")

	# --- Stacking: 3 Slashes + 1 Block -> two groups (A x3, S x1) ---
	var hs := HandSlots.new()
	var hand: Array = [s1, s2, Card.create_slash(), b1]
	var groups := _slots(hs, hand)
	_check(groups.size() == 2, "3 Slashes + Block collapse to 2 buttons")
	_check(groups[0]["slot"] == 0 and groups[0]["cards"].size() == 3, "Slash stack on slot 1 (x3)")
	_check(groups[1]["slot"] == 1 and groups[1]["cards"].size() == 1, "Block on slot 2 (x1)")
	_check(HandSlots.letter(0) == "1" and HandSlots.letter(1) == "2", "slot keys 1, 2 (number row)")

	# --- Stable slots across a play: remove one Slash, Block keeps slot S ---
	hand.erase(s1)  # played a Slash
	groups = _slots(hs, hand)
	var block_group = null
	var slash_group = null
	for g in groups:
		if g["cards"][0].card_id == "block":
			block_group = g
		else:
			slash_group = g
	_check(block_group != null and block_group["slot"] == 1, "Block stays on slot 2 after a Slash is played (no re-letter)")
	_check(slash_group != null and slash_group["cards"].size() == 2, "Slash stack now x2")

	# --- Remove ALL Slashes: slot A frees; a NEW distinct card fills A, Block keeps S ---
	hand = [b1]  # only Block remains
	groups = _slots(hs, hand)
	_check(groups.size() == 1 and groups[0]["slot"] == 1, "with only Block left, it still holds slot 2")
	var draw := Card.create_dagger_throw()
	hand = [b1, draw]
	groups = _slots(hs, hand)
	var new_group = null
	for g in groups:
		if g["cards"][0].card_id == draw.card_id:
			new_group = g
	_check(new_group != null and new_group["slot"] == 0, "a newly drawn card fills the lowest free slot (1)")

	# --- New distinct cards fill in draw order from A ---
	var hs2 := HandSlots.new()
	var c_a := Card.create_slash()
	var c_s := Card.create_block()
	var c_d := Card.create_dagger_throw()
	groups = _slots(hs2, [c_a, c_s, c_d])
	_check(groups.size() == 3, "three distinct cards -> three buttons")
	_check(groups[0]["cards"][0] == c_a and groups[1]["cards"][0] == c_s and groups[2]["cards"][0] == c_d,
		"distinct cards fill 1,2,3 in draw order")

	# --- Representative skips a jailed copy so the button stays playable ---
	var hs3 := HandSlots.new()
	var j1 := Card.create_slash()
	var j2 := Card.create_slash()
	j1.jail_time_remaining = 30  # jailed -> different signature, own slot
	var hand3: Array = [j1, j2]
	_check(j1.get_stack_signature() != j2.get_stack_signature(), "a jailed copy splits from the playable one")
	groups = _slots(hs3, hand3)
	# The playable Slash group's rep must be the non-jailed card.
	for g in groups:
		var rep: Card = g["rep"]
		if not rep.is_jailed():
			_check(rep == j2, "playable stack's representative is the non-jailed copy")

	# --- Representative skips the Locked card index within a stack ---
	var hs4 := HandSlots.new()
	var k1 := Card.create_slash()
	var k2 := Card.create_slash()
	var hand4: Array = [k1, k2]  # identical, one slot
	groups = hs4.build_groups(hand4, 0)  # lock hand index 0 (k1)
	hs4.reconcile(hand4)
	groups = hs4.build_groups(hand4, 0)
	_check(groups.size() == 1 and groups[0]["rep"] == k2, "locked copy is skipped for the representative")

	# --- Instant (reaction) cards: all pile into ONE un-lettered stack ---
	var hs5 := HandSlots.new()
	var i1 := Card.create_spider_senses()
	var i2 := Card.create_spider_senses()
	var i3 := Card.create_gift_from_the_phoenix()  # different instant, same stack
	var n1 := Card.create_slash()
	_check(i1.get_stack_signature() == i3.get_stack_signature(),
		"different pure instants share the one instant-stack signature")
	var hand5: Array = [i1, n1, i2, i3]
	groups = _slots(hs5, hand5)
	_check(groups.size() == 2, "3 instants + Slash collapse to 2 stacks")
	var inst_group = null
	var norm_group = null
	for g in groups:
		if g["slot"] == HandSlots.INSTANT_SLOT:
			inst_group = g
		else:
			norm_group = g
	_check(inst_group != null and inst_group["cards"].size() == 3, "instant stack holds all 3 instants (x3)")
	_check(norm_group != null and norm_group["slot"] == 0, "Slash still gets the first lettered slot (A)")
	_check(groups[groups.size() - 1] == inst_group, "instant stack renders last (right end of the fan)")

	# Instants never consume a letter: draw another normal card, it takes S.
	var n2 := Card.create_block()
	hand5.append(n2)
	groups = _slots(hs5, hand5)
	for g in groups:
		if g["cards"][0] == n2:
			_check(g["slot"] == 1, "instants don't consume letters — next normal card gets S")

	# A card with an instant effect that is ALSO normally playable (not
	# CardType.REACTION, e.g. a maintained Power with a reaction trigger)
	# stacks like a normal card.
	var dual := Card.create_slash()
	dual.reaction_trigger = "on_damage_taken"
	_check(not HandSlots.is_instant_sig(dual.get_stack_signature()),
		"playable card with an instant effect is treated as a normal card")

	# --- Slotted copies: a card enchanted into an item plays with that item's
	# On-Self bonus, so it never stacks with the deck copies of the same card,
	# and copies in two different items never stack with each other. (Cryonics
	# carries the Sword label, so it fits a Wooden Sword's slot.)
	var hs6 := HandSlots.new()
	var p1 := Card.create_cryonics()
	var p2 := Card.create_cryonics()
	var e1 := Card.create_cryonics()
	var e2 := Card.create_cryonics()
	var sword_a := ItemData.create_wooden_sword()
	var sword_b := ItemData.create_wooden_sword()
	_check(sword_a.slot_card(e1) and sword_b.slot_card(e2), "Cryonics slots into two Wooden Swords")
	_check(p1.get_stack_signature() == p2.get_stack_signature(), "two deck Cryonics still share a signature")
	_check(e1.get_stack_signature() != p1.get_stack_signature(), "a slotted copy splits from the deck copies")
	_check(e1.get_stack_signature() != e2.get_stack_signature(), "copies slotted in two different items split from each other")
	var hand6: Array = [p1, e1, p2, e2]  # draw order: deck, sword A, deck, sword B
	groups = _slots(hs6, hand6)
	_check(groups.size() == 3, "2 deck + 1 in sword A + 1 in sword B -> three stacks")
	var plain_group = null
	var a_group = null
	var b_group = null
	for g in groups:
		var r: Card = g["rep"]
		if r.slotted_in_item == sword_a:
			a_group = g
		elif r.slotted_in_item == sword_b:
			b_group = g
		else:
			plain_group = g
	_check(plain_group != null and plain_group["slot"] == 0 and plain_group["cards"].size() == 2,
		"deck copies keep slot 1 as an x2 stack")
	_check(plain_group != null and not plain_group["cards"].has(e1) and not plain_group["cards"].has(e2),
		"neither slotted copy is in the deck stack")
	_check(a_group != null and a_group["slot"] == 1 and a_group["cards"] == [e1], "sword A's copy is its own stack on slot 2")
	_check(b_group != null and b_group["slot"] == 2 and b_group["cards"] == [e2], "sword B's copy is its own stack on slot 3")

	# Two copies in the SAME item share its bonus, so they do stack together.
	sword_a.card_slots = 2
	var e3 := Card.create_cryonics()
	_check(sword_a.slot_card(e3), "a second Cryonics slots into sword A's second slot")
	_check(e3.get_stack_signature() == e1.get_stack_signature(), "two copies in the same item share a signature")
	hand6.append(e3)
	groups = _slots(hs6, hand6)
	_check(groups.size() == 3, "same-item copies merge: still three stacks")
	for g in groups:
		if g["rep"].slotted_in_item == sword_a:
			_check(g["cards"].size() == 2 and g["slot"] == 1, "sword A's stack is x2 and kept its slot")

	# Extracting the card from its item makes it a plain copy again.
	sword_b.unslot_card(0)
	_check(e2.get_stack_signature() == p1.get_stack_signature(), "an extracted copy rejoins the deck stack")
	groups = _slots(hs6, hand6)
	_check(groups.size() == 2, "after extraction: deck stack (x3) + sword A stack (x2)")
	for g in groups:
		if g["rep"].slotted_in_item == null:
			_check(g["cards"].size() == 3 and g["slot"] == 0, "deck stack absorbs the extracted copy on slot 1")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
