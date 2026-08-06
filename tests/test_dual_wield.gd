extends SceneTree

## Dual-wield weight penalty: holding two or more non-shield weapons taxes
## EVERY wielded weapon's carried weight by 15% (DUAL_WIELD_WEIGHT_MULT), so a
## heavy main hand can't hide behind a feather off-hand. Shields don't count.
## Run: godot --headless --path . --script tests/test_dual_wield.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Dual-wield weight penalty test ===")

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
	var sword := ItemData.create_iron_sword()      # weight 80
	var shield := ItemData.create_wooden_shield()  # weight 4
	_check(inv.equip_item(sword, 0), "sword equips in main hand")
	_check(inv.equip_item(shield, 1), "shield equips in off hand")
	_check(not inv.is_dual_wielding(), "sword + shield does not count as dual wielding")
	_check(inv.get_total_weight() == 84, "sword + shield carries at raw weight (84)")

	# --- Sword + dagger: BOTH weapons pay the 15% ---
	inv.unequip_item(ItemData.ItemType.WEAPON, 1)
	var dagger := ItemData.create_shadow_dagger()  # weight 10
	_check(inv.equip_item(dagger, 1), "dagger equips in off hand")
	_check(inv.is_dual_wielding(), "sword + dagger counts as dual wielding")
	# floor(80 * 1.15) + floor(10 * 1.15) = 92 + 11
	_check(inv.get_total_weight() == 103,
		"both weapons taxed: 92 + 11 = %d" % inv.get_total_weight())

	# --- Dropping to one weapon removes the penalty ---
	inv.unequip_item(ItemData.ItemType.WEAPON, 1)
	_check(not inv.is_dual_wielding(), "one weapon is not dual wielding")
	_check(inv.get_total_weight() == 80, "solo sword back to raw weight (80)")

	# --- Two small blades: the tax is pocket change ---
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	inv.equip_item(ItemData.create_shadow_dagger(), 0)
	inv.equip_item(ItemData.create_shadow_dagger(), 1)
	_check(inv.get_total_weight() == 22, "twin daggers: 11 + 11 (only +2 over raw)")

	# --- Two real weapons: a felt commitment ---
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	inv.unequip_item(ItemData.ItemType.WEAPON, 1)
	inv.equip_item(ItemData.create_serpent_fang(), 0)  # weight 40
	inv.equip_item(ItemData.create_serpent_fang(), 1)
	_check(inv.get_total_weight() == 92, "paired fangs: 46 + 46 = 92 (+12 over raw)")

	# --- Dual-wielding SHIELDS is a stance too, and pays the same pair tax ---
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	inv.unequip_item(ItemData.ItemType.WEAPON, 1)
	inv.equip_item(ItemData.create_spiked_shield(), 0)  # weight 40
	inv.equip_item(ItemData.create_spiked_shield(), 1)
	_check(inv.is_dual_wielding(), "twin shields count as dual wielding")
	_check(inv.get_total_weight() == 92, "paired shields taxed: 46 + 46 = 92")

	# --- Mixed classes stay untaxed: shield + fang ---
	inv.unequip_item(ItemData.ItemType.WEAPON, 1)
	inv.equip_item(ItemData.create_serpent_fang(), 1)
	_check(not inv.is_dual_wielding(), "shield + weapon mixes classes — not dual wielding")
	_check(inv.get_total_weight() == 80, "shield + fang carries at raw weight (80)")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
