extends SceneTree

## Verifies the three conversion keystones on the sphere grid:
##   Sanguine Barrier (lifesteal_temp_hp) — life steal grants temp HP, not healing
##   Living Bulwark   (armor_temp_hp)     — armor gains become temp HP
##   Arcane Blood     (mana_blood)        — damage splits between health and mana
## Covers grid placement and the conversion mechanics on PlayerStats.
## Run: godot --headless --path . --script tests/test_conversion_keystones.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _fresh_stats() -> PlayerStats:
	var data = CharacterData.create_ryan()
	var stats = PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(data)
	return stats

func _initialize() -> void:
	print("=== Conversion keystones test ===")
	_test_grid_placement()
	_test_sanguine_barrier()
	_test_living_bulwark()
	_test_arcane_blood()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_grid_placement() -> void:
	print("-- Grid placement --")
	var grid = SphereGrid.new()
	var sang = grid.get_node_by_id(130)
	var bulw = grid.get_node_by_id(131)
	var blood = grid.get_node_by_id(132)
	_check(sang != null and sang.node_type == SphereGrid.NodeType.KEYSTONE and sang.keystone_id == "lifesteal_temp_hp",
		"node 130 is the Sanguine Barrier keystone")
	_check(bulw != null and bulw.node_type == SphereGrid.NodeType.KEYSTONE and bulw.keystone_id == "armor_temp_hp",
		"node 131 is the Living Bulwark keystone")
	_check(blood != null and blood.node_type == SphereGrid.NodeType.KEYSTONE and blood.keystone_id == "mana_blood",
		"node 132 is the Arcane Blood keystone")
	_check(sang.requirements.is_empty() and bulw.requirements.is_empty() and blood.requirements.is_empty(),
		"all three are ungated for now")
	_check(sang.connections.size() > 0 and bulw.connections.size() > 0 and blood.connections.size() > 0,
		"all three are wired into the grid")

func _test_sanguine_barrier() -> void:
	print("-- Sanguine Barrier (life steal -> temp HP) --")
	var stats = _fresh_stats()
	stats.current_health = stats.max_health - 10

	# Without the keystone: life steal heals (through the normal heal pipeline,
	# so the INT heal bonus at the pre-heal DET state rides along).
	var expected_heal = 4 + stats.get_intelligence_spell_bonus()
	stats.apply_life_steal(4)
	_check(stats.current_health == stats.max_health - 10 + expected_heal and stats.current_temp_health == 0,
		"without keystone, life steal heals normally (+%d)" % expected_heal)

	# With the keystone: no healing, temp HP instead.
	stats.keystone_lifesteal_temp_hp = true
	var hp_before = stats.current_health
	stats.apply_life_steal(5)
	_check(stats.current_health == hp_before and stats.current_temp_health == 5,
		"with keystone, 5 life steal became 5 temp HP (no heal)")

	# Works past full health, where a heal would be wasted.
	stats.current_health = stats.max_health
	stats.apply_life_steal(3)
	_check(stats.current_temp_health == 8,
		"temp HP stacks even at full health (got %d)" % stats.current_temp_health)

func _test_living_bulwark() -> void:
	print("-- Living Bulwark (armor -> temp HP) --")
	var stats = _fresh_stats()

	# Without the keystone: armor accrues normally.
	stats.add_armor(4)
	_check(stats.current_armor >= 4 and stats.current_temp_health == 0,
		"without keystone, armor accrues normally")

	# With the keystone: gains divert to temp HP, existing armor untouched.
	stats.keystone_armor_temp_hp = true
	var armor_before = stats.current_armor
	stats.add_armor(6)
	_check(stats.current_armor == armor_before and stats.current_temp_health >= 6,
		"with keystone, +6 armor became temp HP (armor unchanged at %d)" % stats.current_armor)

	var temp_before = stats.current_temp_health
	stats.add_armor_with_bolster(3)
	_check(stats.current_armor == armor_before and stats.current_temp_health >= temp_before + 3,
		"bolstered armor gain also converts to temp HP")

func _test_arcane_blood() -> void:
	print("-- Arcane Blood (damage splits health/mana) --")
	var stats = _fresh_stats()
	stats.keystone_mana_blood = true
	stats.current_armor = 0
	stats.current_temp_health = 0
	stats.current_health = 30
	stats.current_mana = 10.0

	# 10 damage -> 5 mana, 5 health.
	stats.take_damage(10)
	_check(stats.current_health == 25 and int(stats.current_mana) == 5,
		"10 damage split evenly: HP 30->%d, mana 10->%d" % [stats.current_health, int(stats.current_mana)])

	# Odd damage -> health takes the extra point (7 -> 4 HP / 3 mana).
	stats.take_damage(7)
	_check(stats.current_health == 21 and int(stats.current_mana) == 2,
		"odd split gives health the extra point: HP %d, mana %d" % [stats.current_health, int(stats.current_mana)])

	# Mana can't cover its share -> health takes the leftover (10 -> mana soaks 2, HP takes 8).
	stats.take_damage(10)
	_check(stats.current_health == 13 and int(stats.current_mana) == 0,
		"depleted mana spills to health: HP %d, mana %d" % [stats.current_health, int(stats.current_mana)])

	# Mana empty -> health takes everything.
	stats.take_damage(6)
	_check(stats.current_health == 7,
		"with 0 mana, health takes the full hit (HP %d)" % stats.current_health)

	# Death comes from HP alone, even with mana left.
	stats.current_health = 4
	stats.current_mana = 100.0
	var died_flag = [false]
	stats.died.connect(func(): died_flag[0] = true)
	stats.take_damage(8)
	_check(stats.current_health == 0 and died_flag[0],
		"character dies at 0 HP even with %d mana left" % int(stats.current_mana))
