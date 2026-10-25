extends SceneTree

## The hand rules as the designer set them (2026-10-25):
##  - Free hand: one ONE-HANDED item and an empty hand. A lone staff (or bow)
##    is two-handed by nature and never qualifies.
##  - A quiver is only worn beside a bow; it comes off when the bow does.
##  - Dual wielding adds no weight.
##  - The off-hand modifier (0.9; Stephen's White Sleeve 1.1) covers ANY item
##    in the off hand — weapon, shield or quiver — and everything it gives:
##    its stats, its flat bonuses, its riders. Holding it two-handed lifts it.
##  - Two-handing a shield, then releasing it or unequipping it while held
##    two-handed, leaves the stats exactly where they started (no leak).
##  - A shield held two-handed adds its block (weight / 25) to every
##    armor-granting card, not just the Block button.
## Run: godot --headless --path . --script tests/test_hand_rules_1025.gd

const Fixtures = preload("res://tests/item_fixtures.gd")

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _rig(who: String) -> Array:
	var data: CharacterData = CharacterData.create_stephen() if who == "Stephen" else CharacterData.create_ryan()
	var stats := PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(data)
	var inv := Inventory.new()
	get_root().add_child(inv)
	inv.initialize(data.character_name)
	inv.connect_player_stats(stats)
	stats.base_strength = 40  # capacity never gets in the way
	return [inv, stats]

func _stat_shield(weight := 50) -> ItemData:
	var sh := Fixtures.shield(weight)
	sh.item_name = "Stat Shield"
	sh.strength_bonus = 5
	sh.agility_bonus = 3
	sh.crit_chance_percent = 10.0
	return sh

func _snapshot(stats: PlayerStats) -> Array:
	return [stats.base_strength, stats.base_agility, snappedf(stats.equipment_crit_bonus, 0.001)]

func _initialize() -> void:
	_test_free_hand()
	_test_quiver()
	_test_dual_wield_weight()
	_test_off_hand_items()
	_test_two_hand_shield_round_trip("Ryan")
	_test_two_hand_shield_round_trip("Stephen")
	_test_two_hand_shield_block_cards()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_free_hand() -> void:
	print("-- Free hand --")
	var r := _rig("Ryan")
	var inv: Inventory = r[0]
	inv.equip_item(Fixtures.sword(), 0)
	_check(inv.is_free_handing(), "a lone sword is the free-hand stance")
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	inv.equip_item(Fixtures.staff(), 0)
	_check(not inv.is_free_handing(), "a lone staff is two-handed by nature: no free hand")
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	inv.equip_item(Fixtures.bow(), 0)
	_check(not inv.is_free_handing(), "a lone bow: no free hand")

func _test_quiver() -> void:
	print("-- Quivers only beside a bow --")
	var r := _rig("Ryan")
	var inv: Inventory = r[0]
	_check(not inv.equip_item(Fixtures.quiver(), 1), "a quiver alone is refused: %s" % inv.last_refusal)
	inv.equip_item(Fixtures.sword(), 0)
	_check(not inv.equip_item(Fixtures.quiver(), 1), "a quiver beside a sword is refused")
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	var bow := Fixtures.bow()
	var q := Fixtures.quiver()
	_check(inv.equip_item(bow, 0) and inv.equip_item(q, 1), "bow, then quiver: worn")
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	_check(inv.equipped_weapons[1] == null and inv.stored_items.has(q), "the bow comes off: the quiver goes back to the bag")
	# A build switch that lands on a quiver without its bow sheds the quiver.
	inv.stored_items.erase(q)
	inv.equip_item(bow, 0)
	inv.equip_item(q, 1)
	inv.switch_build(1)                 # build 2 starts as a copy of this loadout
	inv.switch_build(0)                 # back on build 1 (saving build 2 as is)
	inv.builds[1]["weapons"] = [null, q]  # a stale build 2: quiver, no bow
	var r2 := inv.switch_build(1)
	_check(r2["success"] and inv.equipped_weapons[1] == null, "a build of a quiver without its bow lands with the quiver in the bag")

func _test_dual_wield_weight() -> void:
	print("-- Dual wielding adds no weight --")
	var r := _rig("Ryan")
	var inv: Inventory = r[0]
	inv.equip_item(Fixtures.sword(80), 0)
	inv.equip_item(Fixtures.dagger(10), 1)
	_check(inv.is_dual_wielding() and inv.get_total_weight() == 90, "sword 80 + dagger 10 weigh 90 (%d)" % inv.get_total_weight())

func _test_off_hand_items() -> void:
	print("-- The off-hand modifier covers shields and quivers --")
	var r := _rig("Ryan")
	var inv: Inventory = r[0]
	var stats: PlayerStats = r[1]
	var str0 := stats.base_strength
	inv.equip_item(Fixtures.sword(), 0)
	var sh := _stat_shield()
	inv.equip_item(sh, 1)
	_check(stats.base_strength - str0 == 4, "an off-hand shield's +5 STR gives 4 (floor of 4.5): %d" % (stats.base_strength - str0))
	_check(is_equal_approx(stats.equipment_crit_bonus, 9.0), "its +10% crit gives 9% (%s)" % stats.equipment_crit_bonus)
	_check(sh.is_in_off_hand and is_equal_approx(sh.rider_scale(), 0.9), "its riders work at 90%")
	inv.unequip_item(ItemData.ItemType.WEAPON, 1)
	_check(stats.base_strength == str0 and is_equal_approx(stats.equipment_crit_bonus, 0.0), "unequipped: back to exactly where it was")
	_check(not sh.is_in_off_hand and is_equal_approx(sh.rider_scale(), 1.0), "off the hands: riders back to full")
	# A quiver in the off hand beside its bow.
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	var q := Fixtures.quiver()
	q.ranged_damage_bonus = 10
	inv.equip_item(Fixtures.bow(), 0)
	inv.equip_item(q, 1)
	_check(stats.ranged_damage_bonus == 9, "an off-hand quiver's +10 ranged damage gives 9 (%d)" % stats.ranged_damage_bonus)
	# Stephen: 110%.
	var rs := _rig("Stephen")
	var sinv: Inventory = rs[0]
	var sstats: PlayerStats = rs[1]
	var sstr0 := sstats.base_strength
	sinv.equip_item(Fixtures.sword(), 0)
	sinv.equip_item(_stat_shield(), 1)
	_check(sstats.base_strength - sstr0 == 5, "Stephen: the shield's +5 STR gives 5 (floor of 5.5)")
	_check(is_equal_approx(sstats.equipment_crit_bonus, 11.0), "Stephen: its +10% crit gives 11% (%s)" % sstats.equipment_crit_bonus)

func _test_two_hand_shield_round_trip(who: String) -> void:
	print("-- %s: two-handing an off-hand shield and back --" % who)
	var r := _rig(who)
	var inv: Inventory = r[0]
	var stats: PlayerStats = r[1]
	var before := _snapshot(stats)
	var sh := _stat_shield()
	inv.equip_item(sh, 1)  # the off hand, main hand empty
	var off := _snapshot(stats)
	_check(inv.set_two_handed(1, true), "the shield is held two-handed")
	var held := _snapshot(stats)
	_check(held[0] - before[0] == 5 and held[1] - before[1] == 3, "two-handed: its stats at full strength (%s)" % str(held))
	_check(inv.set_two_handed(1, false), "released to one hand")
	_check(_snapshot(stats) == off, "released: back to the off-hand amounts (%s vs %s)" % [str(_snapshot(stats)), str(off)])
	inv.set_two_handed(1, true)
	inv.unequip_item(ItemData.ItemType.WEAPON, 1)
	_check(_snapshot(stats) == before, "unequipped while two-handed: nothing leaks (%s vs %s)" % [str(_snapshot(stats)), str(before)])

func _test_two_hand_shield_block_cards() -> void:
	print("-- A two-handed shield's block reaches armor-granting cards --")
	var r := _rig("Ryan")
	var inv: Inventory = r[0]
	var stats: PlayerStats = r[1]
	var sh := Fixtures.shield(75)  # 75 / 25 = +3
	inv.equip_item(sh, 0)
	_check(stats.get_defense_card_block() == 0, "one-handed: no extra card block")
	inv.set_two_handed(0, true)
	_check(stats.two_hand_block_bonus == 3 and stats.get_defense_card_block() == 3, "two-handed: +3 on armor-granting cards")
	_check(inv.get_two_hand_block_bonus(sh) == 3, "and +3 on the Block button")
	var armor0 := stats.current_armor
	stats.defense_card_bonus_pending = true  # a card resolving (Card.execute arms this)
	stats.add_armor(5)
	_check(stats.current_armor - armor0 == 8, "a 5-armor card grants 8 (%d)" % (stats.current_armor - armor0))
	inv.set_two_handed(0, false)
	_check(stats.get_defense_card_block() == 0, "released: the card bonus goes")
