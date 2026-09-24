extends SceneTree

## Unerring armor: the capped, regenerating shell that periodic-armor items and
## the sphere grid's Arm/Cyc nodes feed. It never stacks past its cap, hits
## and decay eat it before regular armor, and the cap grows through sphere
## nodes and item stats.
## Run: godot --headless --path . --script tests/test_unerring_armor.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _fresh_stats() -> PlayerStats:
	var stats = PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(CharacterData.create_brad())
	return stats

func _initialize() -> void:
	print("=== Unerring armor test ===")
	_test_cap()
	_test_absorb_order()
	_test_decay_order()
	_test_periodic_items()
	_test_cap_sources()
	_test_save_round_trip()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_cap() -> void:
	print("-- The cap --")
	var stats := _fresh_stats()
	_check(stats.get_unerring_cap() == PlayerStats.BASE_UNERRING_CAP and PlayerStats.BASE_UNERRING_CAP == 6,
		"a fresh character's unerring cap is 6")
	_check(stats.add_unerring_armor(4) == 4 and stats.unerring_armor == 4, "gains fill the pool")
	_check(stats.add_unerring_armor(4) == 2 and stats.unerring_armor == 6, "the pool clamps at the cap (only 2 of 4 land)")
	_check(stats.add_unerring_armor(4) == 0, "at the cap nothing more lands, however long you wait")
	stats.current_armor = 3
	_check(stats.get_total_armor() == 9, "total armor is regular plus unerring")
	stats.queue_free()

func _test_absorb_order() -> void:
	print("-- Damage eats unerring first --")
	var stats := _fresh_stats()
	stats.current_health = stats.max_health
	stats.current_armor = 5
	stats.add_unerring_armor(6)
	var hp := stats.current_health
	stats.take_damage(4)
	_check(stats.unerring_armor == 2 and stats.current_armor == 5 and stats.current_health == hp,
		"a 4 hit: unerring 6 → 2, regular armor and health untouched")
	stats.take_damage(4)
	_check(stats.unerring_armor == 0 and stats.current_armor == 3 and stats.current_health == hp,
		"a second 4: the last 2 unerring, then 2 regular")
	stats.take_damage(5)
	_check(stats.current_armor == 0 and stats.current_health == hp - 2, "the shell breaks: 3 regular absorbed, 2 through to health")
	stats.queue_free()

func _test_decay_order() -> void:
	print("-- Decay eats unerring first --")
	var stats := _fresh_stats()
	stats.current_armor = 4
	stats.add_unerring_armor(3)
	stats.process_turn()
	_check(stats.unerring_armor == 1 and stats.current_armor == 4, "2 decay: unerring 3 → 1, regular untouched")
	stats.process_turn()
	_check(stats.unerring_armor == 0 and stats.current_armor == 3, "next cycle: the last unerring point, then 1 regular")
	stats.queue_free()

func _test_periodic_items() -> void:
	print("-- Periodic-armor items --")
	var stats := _fresh_stats()
	var inv := Inventory.new()
	get_root().add_child(inv)
	inv.initialize("Brad")
	inv.connect_player_stats(stats)
	var hat := ItemData.create_kettle_hat()  # 2 armor every 15 tempo
	_check(inv.equip_item(hat, 0), "Kettle Hat equips")
	for _i in range(300):
		inv.process_turn()  # 1500 tempo of waiting
	_check(stats.unerring_armor == 6 and stats.current_armor == 0,
		"1500 tempo of waiting leaves exactly the cap (%d unerring, %d regular)" % [stats.unerring_armor, stats.current_armor])
	stats.take_damage(5)
	_check(stats.unerring_armor == 1, "a hit spends it")
	for _i in range(3):
		inv.process_turn()
	_check(stats.unerring_armor == 3, "…and the hat regrows it on its clock (2 per 15 tempo)")
	# The sphere grid's Arm/Cyc armor is the same kind of shell.
	stats.apply_sphere_grid_combat_bonus("Arm/Cyc +1", "")
	_check(stats.sphere_bonus_armor_per_cycle == 1, "Arm/Cyc still parses")
	inv.queue_free()
	stats.queue_free()

func _test_cap_sources() -> void:
	print("-- Raising the cap --")
	var stats := _fresh_stats()
	stats.apply_sphere_grid_combat_bonus("Unerring +1", "")
	_check(stats.get_unerring_cap() == 7, "an Unerring +1 sphere node raises the cap to 7")
	var inv := Inventory.new()
	get_root().add_child(inv)
	inv.initialize("Brad")
	inv.connect_player_stats(stats)
	var belt := ItemData.new()
	belt.item_name = "Test Girdle"
	belt.item_type = ItemData.ItemType.BELT
	belt.item_type_name = "Belt"
	belt.unerring_cap_bonus = 2
	_check(inv.equip_item(belt, 0), "a belt with +2 unerring cap equips")
	_check(stats.get_unerring_cap() == 9, "…and the cap reads 9")
	stats.add_unerring_armor(9)
	inv.unequip_item(ItemData.ItemType.BELT, 0)
	_check(stats.get_unerring_cap() == 7 and stats.unerring_armor == 7, "unequipping shrinks the cap and sheds what no longer fits")
	# The grid holds Unerring nodes.
	var grid = SphereGrid.new()
	var found := 0
	for n in grid.nodes:
		if n.label.begins_with("Unerring"):
			found += 1
	_check(found >= 2, "the sphere grid carries Unerring cap nodes (%d)" % found)
	inv.queue_free()
	stats.queue_free()

func _test_save_round_trip() -> void:
	print("-- Save round trip --")
	var stats := _fresh_stats()
	stats.apply_sphere_grid_combat_bonus("Unerring +1", "")
	stats.add_unerring_armor(5)
	var saved: Dictionary = stats.save_progression()
	var again := _fresh_stats()
	again.restore_progression(saved)
	_check(again.unerring_armor == 5 and again.get_unerring_cap() == 7, "unerring armor and its sphere cap survive a save")
	stats.queue_free()
	again.queue_free()
