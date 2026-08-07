extends SceneTree

## Verifies the fourth audit fix batch: D1 maintain-card convention (plain
## "Maintain:" tag, reserve == mana cost) and D9's equipped_quivers removal.
## Run: godot --headless --path . --script tests/test_audit_batch4.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Audit batch 4 test ===")

	# --- D1: every maintain card uses the plain tag and reserves its mana cost ---
	var maintain_cards := [
		Card.create_halo(),
		Card.create_armored_discipline(),
		Card.create_cultish_wounds(),
		Card.create_fountain_of_life(),
	]
	var num_maintain := RegEx.create_from_string("Maintain \\d")
	for card in maintain_cards:
		_check(card.maintain_cost == card.mana_cost,
			"%s reserve (%d) equals its mana cost (%d)" % [card.card_name, card.maintain_cost, card.mana_cost])
		_check(card.description.begins_with("Maintain:"),
			"%s description starts with the plain 'Maintain:' tag" % card.card_name)
		_check(num_maintain.search(card.description) == null,
			"%s description carries no numeric maintain cost" % card.card_name)

	# --- D1: Halo's face now scales the right number (the heal, not the cost) ---
	var halo = Card.create_halo()
	var shown = halo.get_display_description({"heal": 8, "heal_base": 3})
	_check("]8[/color] HP" in shown,
		"Halo's scaled heal lands on the HP number (got: %s)" % shown)

	# --- D9: the vestigial quiver slot is fully gone ---
	var inv = load("res://scripts/progression/inventory.gd").new()
	_check(not ("equipped_quivers" in inv), "equipped_quivers property no longer exists")
	_check(not ("quiver_slots" in inv), "quiver_slots property no longer exists")
	inv.initialize("Stephen")
	_check(not inv.get_slot_info().has("quiver"), "slot map has no quiver entry")
	inv.free()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
