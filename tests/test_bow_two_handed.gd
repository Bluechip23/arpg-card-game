extends SceneTree

const Fixtures = preload("res://tests/item_fixtures.gd")

## Verifies the bow rule: bows are two-handed weapons. While a bow is in the
## hands, the only other hand item allowed is a quiver — no swords, shields,
## or second bows, in either equip order. The War Rack refuses to bring a bow
## down alongside other gear.
## Run: godot --headless --path . --script tests/test_bow_two_handed.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _fresh_inventory(character: String) -> Array:
	var data = CharacterData.create_brad() if character == "Brad" else CharacterData.create_stephen()
	var stats = PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(data)
	stats.base_strength = 20
	var inv = Inventory.new()
	get_root().add_child(inv)
	inv.initialize(data.character_name)
	inv.connect_player_stats(stats)
	return [inv, stats]

func _initialize() -> void:
	print("=== Bow two-handed rule test ===")
	var rig = _fresh_inventory("Stephen")
	var inv: Inventory = rig[0]

	var bow = Fixtures.bow()
	var sword = Fixtures.sword()
	var shield = Fixtures.shield()

	# --- Bow first: nothing but a quiver joins it ---
	_check(inv.equip_item(bow, 0), "bow equips into empty hands")
	_check(not inv.equip_item(sword, 1), "sword refused alongside the bow")
	_check(not inv.equip_item(shield, 1), "shield refused alongside the bow")
	var quiver = ItemData.new()
	quiver.item_name = "Test Quiver"
	quiver.item_type = ItemData.ItemType.QUIVER
	quiver.item_type_name = "Quiver"
	quiver.weight = 2
	_check(inv.equip_item(quiver, 1), "quiver still equips alongside the bow")

	# --- Quiver first, then bow: also legal ---
	_check(inv.unequip_item(ItemData.ItemType.WEAPON, 0) == bow, "bow unequips (quiver stays)")
	_check(inv.equip_item(bow, 0), "bow re-equips alongside the already-worn quiver")
	_check(inv.unequip_item(ItemData.ItemType.QUIVER, 1) == quiver, "quiver unequips")

	# --- Other weapon first: bow refused ---
	_check(inv.unequip_item(ItemData.ItemType.WEAPON, 0) == bow, "bow unequips")
	_check(inv.equip_item(sword, 0), "sword equips")
	_check(not inv.equip_item(bow, 1), "bow refused while a sword is held")
	_check(inv.unequip_item(ItemData.ItemType.WEAPON, 0) == sword, "sword unequips")
	_check(inv.equip_item(bow, 0), "bow equips again once hands are clear")

	# --- Moving the bow between its own hand slots stays legal ---
	_check(inv.hand_conflict_reason(bow, 1) == "", "moving the bow to the other hand is not a conflict")

	# --- War Rack: a bow can't come down alongside other gear ---
	var rig2 = _fresh_inventory("Brad")
	var binv: Inventory = rig2[0]
	var bow2 = Fixtures.bow(50)
	var sword2 = Fixtures.sword()
	binv.rack_store_item(bow2)
	binv.rack_store_item(sword2)
	var check: Dictionary = binv.can_rack_exchange(false)
	_check(not check["ok"], "rack refuses to bring a bow down with a sword")
	_check(binv.rack_take_item(1) == sword2, "sword comes off the rack")
	_check(binv.can_rack_exchange(false)["ok"], "bow-only rack exchange is legal")
	var r: Dictionary = binv.rack_exchange(false)
	_check(r["success"] and binv.get_equipped_item(ItemData.ItemType.WEAPON, 0) == bow2,
		"bow comes down alone")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
