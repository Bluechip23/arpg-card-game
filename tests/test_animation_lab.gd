extends SceneTree

## The Animation Lab's list (designer, 2026-11-15): the hero's drawn actions,
## every card grouped by type as in the sandbox, the systemic effects — no
## passives — and a Spell card plays the hero's drawn cast, as in battle.
## Run: godot --headless --path . --script tests/test_animation_lab.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	print("=== Animation Lab ===")
	var lab = load("res://scenes/menus/animation_lab.tscn").instantiate()
	get_root().add_child(lab)
	for _i in range(4):
		await process_frame
	var headers: Array[String] = []
	var buttons: Array[String] = []
	for c in lab._list_vbox.get_children():
		if c is Label:
			headers.append(c.text)
		elif c is Button:
			buttons.append(c.text)
	_check(not headers.has("PASSIVES") and not buttons.any(func(t): return t.begins_with("+") or t.contains("passive")),
		"no passives listed (%d headers: %s)" % [headers.size(), headers])
	_check(headers[0] == "HERO ACTIONS" and buttons.slice(0, 3) == ["Basic Attack", "Block", "Spell Cast"],
		"the hero's drawn actions come first")
	_check(headers.has("SPELL CARDS") and headers.has("ATTACK CARDS") and headers.has("MAINTAIN CARDS") and headers.has("SYSTEMIC"),
		"cards are grouped by type")
	var cards: int = 0
	for t in SandboxUI.CARD_TYPE_ORDER:
		cards += lab._collect_cards().get(t, []).size()
	_check(cards == Card.get_all_cards(false).size(), "every catalogue card is listed once (%d)" % cards)
	var spells: Array = lab._collect_cards().get("Spell", [])
	_check(spells.any(func(e): return e["label"] == "Fireball" and e["spell"]), "Fireball is listed under Spell, as a spell")

	# Selecting a spell card plays the hero's drawn cast.
	lab._on_set_character("Jeremy")
	var fb: Dictionary = spells.filter(func(e): return e["label"] == "Fireball")[0]
	lab._on_entry_selected(fb["label"], fb["action"], false, false, true)
	await process_frame
	_check(lab._figure._action_sprite.visible, "a spell card plays the drawn cast")
	_check(lab._status_label.text.contains("spell"), "the status line says it is a spell")
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
