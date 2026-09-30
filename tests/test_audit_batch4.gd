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

	# --- D1: every maintain card names its reserve on its face ("Maintain 3M:")
	# and reserves exactly that much (x10 mana scale) ---
	var maintain_cards := [
		Card.create_halo(),
		Card.create_armored_discipline(),
		Card.create_cultish_wounds(),
		Card.create_fountain_of_life(),
	]
	var num_maintain := RegEx.create_from_string("^Maintain (\\d+)M:")
	for card in maintain_cards:
		var m := num_maintain.search(card.description)
		_check(m != null, "%s description starts with 'Maintain XM:'" % card.card_name)
		if m:
			_check(card.maintain_cost == int(m.get_string(1)) * 10,
				"%s reserve (%d) matches its face (%sM)" % [card.card_name, card.maintain_cost, m.get_string(1)])

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
