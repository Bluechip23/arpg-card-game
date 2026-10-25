extends SceneTree

## Dual wielding (two weapons, or two shields) adds NO weight: every hand
## item weighs what it weighs (the 15% surcharge was removed, designer
## 2026-10-25). Weapon + shield is not dual wielding.
## Run: godot --headless --path . --script tests/test_dual_wield.gd

const Fixtures = preload("res://tests/item_fixtures.gd")

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Dual-wield weight test ===")

	var data := CharacterData.create_ryan()
	var stats := PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(data)

	var inv := Inventory.new()
	get_root().add_child(inv)
	inv.initialize(data.character_name)
	inv.connect_player_stats(stats)

	# Plenty of capacity so the equip gate never interferes with the math.
	stats.base_strength = 30

	# --- Sword + shield is NOT dual wielding ---
	var sword := Fixtures.sword()      # weight 80
	var shield := Fixtures.shield()    # weight 4
	_check(inv.equip_item(sword, 0), "sword equips in main hand")
	_check(inv.equip_item(shield, 1), "shield equips in off hand")
	_check(not inv.is_dual_wielding(), "sword + shield does not count as dual wielding")
	_check(inv.get_total_weight() == 84, "sword + shield carries at raw weight (84)")

	# --- Sword + dagger: dual wielding, raw weight ---
	inv.unequip_item(ItemData.ItemType.WEAPON, 1)
	var dagger := Fixtures.dagger()  # weight 10
	_check(inv.equip_item(dagger, 1), "dagger equips in off hand")
	_check(inv.is_dual_wielding(), "sword + dagger counts as dual wielding")
	_check(inv.get_total_weight() == 90,
		"no dual-wield weight: 80 + 10 = %d" % inv.get_total_weight())

	# --- Dropping to one weapon removes the penalty ---
	inv.unequip_item(ItemData.ItemType.WEAPON, 1)
	_check(not inv.is_dual_wielding(), "one weapon is not dual wielding")
	_check(inv.get_total_weight() == 80, "solo sword back to raw weight (80)")

	# --- Two small blades weigh just their weight ---
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	inv.equip_item(Fixtures.dagger(), 0)
	inv.equip_item(Fixtures.dagger(), 1)
	_check(inv.get_total_weight() == 20, "twin daggers: 10 + 10 (%d)" % inv.get_total_weight())

	# --- Two real weapons: still just their weight ---
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	inv.unequip_item(ItemData.ItemType.WEAPON, 1)
	inv.equip_item(Fixtures.polearm(), 0)  # weight 40
	inv.equip_item(Fixtures.polearm(), 1)
	_check(inv.get_total_weight() == 80, "paired fangs: 40 + 40 (%d)" % inv.get_total_weight())

	# --- Dual-wielding SHIELDS is a stance too, also weightless beyond the items ---
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	inv.unequip_item(ItemData.ItemType.WEAPON, 1)
	inv.equip_item(Fixtures.shield(40), 0)  # weight 40
	inv.equip_item(Fixtures.shield(40), 1)
	_check(inv.is_dual_wielding(), "twin shields count as dual wielding")
	_check(inv.get_total_weight() == 80, "paired shields: 40 + 40 (%d)" % inv.get_total_weight())

	# --- Mixed classes: shield + fang ---
	inv.unequip_item(ItemData.ItemType.WEAPON, 1)
	inv.equip_item(Fixtures.polearm(), 1)
	_check(not inv.is_dual_wielding(), "shield + weapon mixes classes — not dual wielding")
	_check(inv.get_total_weight() == 80, "shield + fang carries at raw weight (80)")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
