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

	# "Core / Shared" has no passive tree — Passive tab shows a friendly note.
	sb._char_dd.select(sb.CARD_GROUP_ORDER.size() - 1)  # "Core / Shared"
	sb._set_tab(1)
	_check(sb._passive_list.get_child_count() >= 1, "Core / Shared shows a no-passives note, not a crash")

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
