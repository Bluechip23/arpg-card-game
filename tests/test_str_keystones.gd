extends SceneTree

## Verifies the two Strength keystones:
##   Weighted Strikes (str_weight_basic) — one-handed weapon heft feeds basic attacks
##   Balanced Load    (str_light_slot)   — a chosen slot's items weigh 10% less (stacks)
## Covers grid placement, the weight-to-damage helper, the weight reduction and its
## stacking with Brad's chest reduction, and the save/restore round trip.
## Run: godot --headless --path . --script tests/test_str_keystones.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Strength keystones test ===")
	_test_grid_placement()
	_test_weighted_strikes()
	_test_balanced_load()
	_test_persistence()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _mk_inv(char_name: String):
	var stats = PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(CharacterData.create_ryan() if char_name == "Ryan" else CharacterData.create_brad())
	var inv = Inventory.new()
	get_root().add_child(inv)
	inv.initialize(char_name)
	inv.connect_player_stats(stats)
	return [stats, inv]

func _heavy_sword(weight: int) -> ItemData:
	var s = ItemData.new()
	s.item_name = "Test Heavy Sword"
	s.item_type = ItemData.ItemType.WEAPON
	s.weapon_subtype = ItemData.WeaponSubtype.SWORD
	s.weight = weight
	return s

func _test_grid_placement() -> void:
	print("-- Grid placement --")
	var grid = SphereGrid.new()
	var ws = grid.get_node_by_id(103)
	var bl = grid.get_node_by_id(104)
	_check(ws.node_type == SphereGrid.NodeType.KEYSTONE and ws.keystone_id == "str_weight_basic",
		"node 103 is the Weighted Strikes keystone")
	_check(bl.node_type == SphereGrid.NodeType.KEYSTONE and bl.keystone_id == "str_light_slot",
		"node 104 is the Balanced Load keystone")
	_check(ws.requirements.get("value", 0) == 15 and bl.requirements.get("stat", "") == "strength",
		"both gated behind STR 15")

func _test_weighted_strikes() -> void:
	print("-- Weighted Strikes: one-handed weight-to-damage --")
	var pair = _mk_inv("Ryan")
	var inv: Inventory = pair[1]
	inv.equip_item(_heavy_sword(80), 0)  # 80 weight -> 80/20 = 4 damage
	_check(inv.get_single_hand_weight_damage_bonus() == 4,
		"an 80-weight one-hander grants +4 (got %d)" % inv.get_single_hand_weight_damage_bonus())
	# Gripped two-handed, its heft is counted via two_hand_damage_bonus, not here.
	inv.set_two_handed(0, true)
	_check(inv.get_single_hand_weight_damage_bonus() == 0,
		"a two-handed weapon is excluded (counted via the grip instead)")

func _test_balanced_load() -> void:
	print("-- Balanced Load: chosen-slot weight cut + stacking --")
	# Brad has a 20% chest reduction; Balanced Load on CHEST should stack.
	var pair = _mk_inv("Brad")
	var stats: PlayerStats = pair[0]
	var inv: Inventory = pair[1]
	var chest = ItemData.new()
	chest.item_name = "Test Plate"
	chest.item_type = ItemData.ItemType.CHEST
	chest.weight = 100
	inv.equip_item(chest, 0)
	# Brad chest reduction only: floor(100 * 0.8) = 80
	_check(inv.get_total_weight() == 80, "chest reduction alone: 100 -> 80 (got %d)" % inv.get_total_weight())
	stats.keystone_str_light_slot = true
	stats.set_str_light_slot(ItemData.ItemType.CHEST)
	# Stacks: floor(floor(100*0.8) * 0.9) = floor(80 * 0.9) = 72
	_check(inv.get_total_weight() == 72,
		"Balanced Load stacks with chest reduction: 80 -> 72 (got %d)" % inv.get_total_weight())
	# Pointing it at a different slot leaves the chest alone.
	stats.set_str_light_slot(ItemData.ItemType.BOOTS)
	_check(inv.get_total_weight() == 80, "no reduction when the slot doesn't match (got %d)" % inv.get_total_weight())

func _test_persistence() -> void:
	print("-- Save / restore --")
	var pair = _mk_inv("Ryan")
	var stats: PlayerStats = pair[0]
	stats.keystone_str_weight_basic = true
	stats.keystone_str_light_slot = true
	stats.str_light_slot_type = ItemData.ItemType.BELT
	var snap = stats.save_progression()
	var restored = PlayerStats.new()
	get_root().add_child(restored)
	restored.initialize(CharacterData.create_ryan())
	restored.restore_progression(snap)
	_check(restored.keystone_str_weight_basic, "Weighted Strikes flag survives save/restore")
	_check(restored.keystone_str_light_slot and restored.str_light_slot_type == ItemData.ItemType.BELT,
		"Balanced Load flag + chosen slot survive save/restore")
