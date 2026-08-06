extends SceneTree

const Fixtures = preload("res://tests/item_fixtures.gd")

## Smoke test for weight-based two-handed wielding, the carry-capacity equip
## gate, equipment-swap tempo costs, and the three equipment builds (I/II/III).
## Run: godot --headless --path . --script tests/test_two_handed_builds.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Two-handed wielding + builds smoke test ===")

	# --- Set up stats + inventory the way Player does (2 hand slots) ---
	var data := CharacterData.create_brad()
	var stats := PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(data)

	var inv := Inventory.new()
	get_root().add_child(inv)
	inv.initialize(data.character_name)
	inv.connect_player_stats(stats)

	# The hard carry gate refuses equips past capacity, so give the test rig
	# enough Strength to lift the greatsword AND the tower shield together
	# (130 + 60 weight -> capacity 200).
	stats.base_strength = 15

	var base_cap := stats.get_carry_capacity()
	_check(base_cap == stats.base_carry_capacity + stats.strength * 10,
		"capacity = base + STR*10 (%d)" % base_cap)

	# --- Two-handed grip: weight halves, capacity drops to 80% ---
	var sword := Fixtures.greatsword()  # weight 130
	_check(inv.equip_item(sword, 0), "greatsword equips one-handed in slot 0")
	_check(inv.get_total_weight() == 130, "one-handed carried weight is 130")

	_check(inv.set_two_handed(0, true), "greatsword can be gripped two-handed")
	_check(inv.two_handed_slot == 0, "grip tracked on slot 0")
	_check(inv.two_handed_lock_slot == 1, "grip claims empty slot 1 as the second hand")
	_check(inv.get_total_weight() == 65, "two-handed carried weight halves to 65")
	_check(stats.get_carry_capacity() == floori(base_cap * PlayerStats.TWO_HAND_CAPACITY_MULT),
		"capacity drops to 80%% while gripped (%d)" % stats.get_carry_capacity())
	_check(stats.two_hand_damage_bonus == floori(130 / Inventory.TWO_HAND_WEIGHT_DAMAGE_DIVISOR),
		"+%d damage from the sword's ORIGINAL weight" % stats.two_hand_damage_bonus)
	_check(stats.get_effective_physical_damage(0) ==
		stats.get_strength_damage_bonus() + stats.two_hand_damage_bonus,
		"two-hand bonus flows into physical damage")

	# The locked hand refuses items; there is no third hand slot.
	var shield := Fixtures.shield()
	_check(not inv.equip_item(shield, 1), "locked hand slot refuses the shield")
	_check(not inv.equip_item(shield, 2), "no third hand slot exists")

	# --- Release the grip: weight and capacity restore ---
	_check(inv.set_two_handed(0, false), "grip releases back to one hand")
	_check(inv.get_total_weight() == 130, "weights restore (130)")
	_check(stats.get_carry_capacity() == base_cap, "capacity restores in full")
	_check(stats.two_hand_damage_bonus == 0, "damage bonus cleared")

	# --- A braced shield gains Basic Block armor from its weight ---
	# With only 2 hand slots, bracing needs the other hand free: stow the
	# greatsword first, brace the tower shield, then take the sword back.
	_check(inv.unequip_to_storage(ItemData.ItemType.WEAPON, 0), "greatsword stows to make room for the brace")
	var tower := ItemData.new()
	tower.item_name = "Test Tower Shield"
	tower.item_type = ItemData.ItemType.WEAPON
	tower.weapon_subtype = ItemData.WeaponSubtype.SHIELD
	tower.weight = 60
	tower.armor_bonus = 6
	_check(inv.equip_item(tower, 1), "tower shield equips in slot 1")
	_check(inv.set_two_handed(1, true), "tower shield braces two-handed")
	_check(stats.two_hand_damage_bonus == 0, "braced shield grants no damage bonus")
	_check(inv.get_two_hand_block_bonus(tower) == 3, "braced shield: +3 Basic Block armor (60/20)")
	inv.set_two_handed(1, false)
	inv.unequip_item(ItemData.ItemType.WEAPON, 1)
	_check(inv.equip_item(sword, 0), "greatsword re-equips after the brace test")

	# --- Hard carry gate: equips past capacity are refused ---
	var anvil := ItemData.new()
	anvil.item_name = "Test Anvil"
	anvil.item_type = ItemData.ItemType.WEAPON
	anvil.weight = 9999
	_check(not inv.equip_item(anvil, 1), "over-capacity equip is refused")
	_check(not stats.is_overburdened(), "character is not overburdened after refusal")

	# --- The off-hand accepts the shield now that the grip is released ---
	_check(inv.equip_item(shield, 1), "off-hand slot accepts the shield")
	_check(inv.get_two_hand_block_bonus(shield) == 0, "no block bonus: shield isn't the gripped item")
	_check(inv.get_total_weight() == 134, "carried weight is sword + shield (130 + 4)")

	# --- Swap tempo costs ---
	_check(inv.get_swap_tempo_cost(ItemData.ItemType.HELM) == 2, "helm swap costs 2")
	_check(inv.get_swap_tempo_cost(ItemData.ItemType.RING) == 2, "ring swap costs 2")
	_check(inv.get_swap_tempo_cost(ItemData.ItemType.WEAPON) == 2, "hand swap costs 2")
	_check(inv.get_swap_tempo_cost(ItemData.ItemType.GAUNTLETS) == 3, "gauntlet swap costs 3")
	_check(inv.get_swap_tempo_cost(ItemData.ItemType.BELT) == 3, "belt swap costs 3")
	_check(inv.get_swap_tempo_cost(ItemData.ItemType.BOOTS) == 3, "boots swap costs 3")
	_check(inv.get_swap_tempo_cost(ItemData.ItemType.CHEST) == 8, "chest swap costs 8")
	_check(inv.get_swap_tempo_cost(ItemData.ItemType.HELM, true) == 1, "helm unequip-only costs 1")
	_check(inv.get_swap_tempo_cost(ItemData.ItemType.BOOTS, true) == 1, "boots unequip-only costs 1")
	_check(inv.get_swap_tempo_cost(ItemData.ItemType.CHEST, true) == 4, "chest unequip-only costs 4")

	# --- Builds: first switch copies current gear; edits round-trip ---
	# Current state: greatsword slot 0 (one-handed), shield slot 1.
	var r1: Dictionary = inv.switch_build(1)
	_check(r1["success"] and r1["tempo_cost"] == 0, "first switch to build II is a free copy")
	_check(inv.active_build == 1, "build II is active")

	# In build II: drop the shield to storage and grip the sword two-handed.
	_check(inv.unequip_to_storage(ItemData.ItemType.WEAPON, 1), "build II: shield unequips to storage")
	_check(inv.set_two_handed(0, true), "build II: greatsword gripped two-handed")

	var r0: Dictionary = inv.switch_build(0)
	_check(r0["success"], "switch back to build I succeeds")
	_check(inv.get_equipped_item(ItemData.ItemType.WEAPON, 1) == shield, "build I re-equips the shield")
	_check(inv.two_handed_slot == -1, "build I holds the sword one-handed")
	_check(r0["tempo_cost"] == 2, "re-equipping the shield cost 2 tempo (hand slot)")

	var r2: Dictionary = inv.switch_build(1)
	_check(r2["success"], "switch to build II succeeds again")
	_check(inv.get_equipped_item(ItemData.ItemType.WEAPON, 1) == null, "build II sheds the shield")
	_check(inv.two_handed_slot == 0, "build II restores the two-handed grip")
	_check(inv.get_total_weight() == 65, "build II carried weight is the halved sword")

	print("=== Done: %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
