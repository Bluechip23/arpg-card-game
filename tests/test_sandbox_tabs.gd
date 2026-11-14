extends SceneTree

## Smoke test for the sandbox Add Card / Add Passive tabs sharing one player
## dropdown. Run: godot --headless --path . --script tests/test_sandbox_tabs.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Sandbox tabs test ===")
	var sb = load("res://scripts/ui/sandbox_ui.gd").new()
	get_root().add_child(sb)
	await process_frame  # let _ready build the UI

	# One shared player dropdown drives both tabs.
	_check(sb._char_dd != null, "single shared player dropdown exists")
	_check(sb._tab_card_btn != null and sb._tab_passive_btn != null, "Add Card and Add Passive tabs exist")

	# Enemy + ally dropdowns are separate and untouched.
	_check(sb._enemy_realm_dd != null, "enemy realm dropdown still present")
	_check(sb._ally_dd != null, "ally dropdown still present")

	# Card tab active: card list shown, passive list hidden, card buttons built.
	sb._set_tab(0)
	_check(sb._card_scroll.visible and not sb._passive_scroll.visible, "Add Card tab shows the card list")
	_check(sb._card_list.get_child_count() > 0, "card tab populated with cards")

	# Switch to Passive tab with a character selected: passives listed.
	sb._char_dd.select(0)  # Brad
	sb._set_tab(1)
	_check(not sb._card_scroll.visible and sb._passive_scroll.visible, "Add Passive tab shows the passive list")
	_check(sb._passive_list.get_child_count() > 0, "passive tab populated for Brad")

	# Same dropdown drives the card list too — flip back and it repopulates.
	sb._set_tab(0)
	_check(sb._card_list.get_child_count() > 0, "shared dropdown still drives the card list")

	# The Card tab's dropdown lists card types; the Passive tab's, characters.
	sb._set_tab(0)
	_check(sb._char_dd.item_count == sb.CARD_TYPE_ORDER.size() and sb._char_dd.get_item_text(0) == "Spell",
		"the Card tab's dropdown lists card types, Spell first")
	sb._set_tab(1)
	_check(sb._char_dd.item_count == sb.CHARACTER_ORDER.size() and sb._char_dd.get_item_text(0) == "Brad",
		"the Passive tab's dropdown lists the characters")
	sb._set_tab(0)

	# Every pool card sits in exactly one type, by the designer's precedence.
	var placed := {}
	for t in sb.CARD_TYPE_ORDER:
		for cid in sb._cards_of_type(t):
			placed[cid] = placed.get(cid, 0) + 1
	var pool := {}
	for owner in sb.CARD_GROUPS:
		for cid in sb.CARD_GROUPS[owner]:
			pool[cid] = true
	_check(placed.size() == pool.size() and placed.values().all(func(n): return n == 1),
		"every pool card is listed under exactly one type (%d of %d)" % [placed.size(), pool.size()])
	var cat := func(cid): return sb.card_category(Card.create_by_id(cid))
	_check(cat.call("fireball") == "Spell", "Fireball (an offensive spell) is a Spell")
	_check(cat.call("slash") == "Attack", "Slash is an Attack")
	_check(cat.call("block") == "Defensive", "Block is Defensive")
	_check(cat.call("healthy_bliss") == "Instant", "Healthy Bliss (an instant utility spell) is an Instant")
	_check(cat.call("halo") == "Maintain", "Halo is a Maintain")
	var spells_ok := true
	for cid in sb._cards_of_type("Spell") + sb._cards_of_type("Attack") + sb._cards_of_type("Offensive"):
		var c := Card.create_by_id(cid)
		if c.card_type in [Card.CardType.REACTION, Card.CardType.POWER, Card.CardType.DEFENSE, Card.CardType.UTILITY] \
				or c.maintain_cost > 0 or c.has_keyword("utility") or c.has_keyword("defense"):
			spells_ok = false
	_check(spells_ok, "no Instant, Maintain, Defensive or Utility card is listed as Spell, Attack or Offensive")
	for cid in sb._cards_of_type("Offensive"):
		var c := Card.create_by_id(cid)
		_check(c.school != Card.CardSchool.SPELL and not c.is_attack(), "%s (Offensive) is neither a spell nor an attack" % cid)

	# Every card id in every group must resolve to a real card, and no card may
	# appear in two groups (ownership per the cards-and-passives spreadsheet).
	var dm = DeckManager.new()
	var seen := {}
	var bad_ids: Array = []
	var dupes: Array = []
	for group in sb.CARD_GROUPS:
		for cid in sb.CARD_GROUPS[group]:
			if seen.has(cid):
				dupes.append(cid)
			seen[cid] = true
			if dm._create_card_from_id(cid) == null:
				bad_ids.append(cid)
	_check(bad_ids.is_empty(), "all sandbox card ids create real cards (bad: %s)" % [bad_ids])
	_check(dupes.is_empty(), "no card is listed under two owners (dupes: %s)" % [dupes])

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
