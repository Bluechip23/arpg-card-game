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
	_check(groups[0]["slot"] == 0 and groups[0]["cards"].size() == 3, "Slash stack on slot A (x3)")
	_check(groups[1]["slot"] == 1 and groups[1]["cards"].size() == 1, "Block on slot S (x1)")
	_check(HandSlots.letter(0) == "A" and HandSlots.letter(1) == "S", "slot letters A, S")

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
	_check(block_group != null and block_group["slot"] == 1, "Block stays on slot S after a Slash is played (no re-letter)")
	_check(slash_group != null and slash_group["cards"].size() == 2, "Slash stack now x2")

	# --- Remove ALL Slashes: slot A frees; a NEW distinct card fills A, Block keeps S ---
	hand = [b1]  # only Block remains
	groups = _slots(hs, hand)
	_check(groups.size() == 1 and groups[0]["slot"] == 1, "with only Block left, it still holds slot S")
	var draw := Card.create_dagger_throw()
	hand = [b1, draw]
	groups = _slots(hs, hand)
	var new_group = null
	for g in groups:
		if g["cards"][0].card_id == draw.card_id:
			new_group = g
	_check(new_group != null and new_group["slot"] == 0, "a newly drawn card fills the lowest free slot (A)")

	# --- New distinct cards fill in draw order from A ---
	var hs2 := HandSlots.new()
	var c_a := Card.create_slash()
	var c_s := Card.create_block()
	var c_d := Card.create_dagger_throw()
	groups = _slots(hs2, [c_a, c_s, c_d])
	_check(groups.size() == 3, "three distinct cards -> three buttons")
	_check(groups[0]["cards"][0] == c_a and groups[1]["cards"][0] == c_s and groups[2]["cards"][0] == c_d,
		"distinct cards fill A,S,D in draw order")

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

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
