extends SceneTree

## Verifies the two Dexterity attack-proc keystones:
##   Flurry Form   (dex_twin_strike) — proc strikes twice; all attacks -2 damage
##   Killing Rhythm(dex_flat_damage) — no tempo/mana proc; each trigger arms a
##                                     DEX-scaled bonus-damage burst on the next attack
## Covers grid placement, the damage-pipeline effects, register_attack() branching,
## and the save/restore round trip.
## Run: godot --headless --path . --script tests/test_dex_keystones.gd

var failures := 0
var _proc_fired := false

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Dexterity keystones test ===")
	_test_grid_placement()
	_test_twin_strike_penalty()
	_test_killing_rhythm()
	_test_normal_proc_unaffected()
	_test_persistence()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_grid_placement() -> void:
	print("-- Grid placement --")
	var grid = SphereGrid.new()
	var flurry = grid.get_node_by_id(106)
	var rhythm = grid.get_node_by_id(127)
	_check(flurry.node_type == SphereGrid.NodeType.KEYSTONE and flurry.keystone_id == "dex_twin_strike",
		"node 106 is the Flurry Form keystone")
	_check(rhythm.node_type == SphereGrid.NodeType.KEYSTONE and rhythm.keystone_id == "dex_flat_damage",
		"node 127 is the Killing Rhythm keystone")
	_check(flurry.requirements.get("stat", "") == "dexterity" and flurry.requirements.get("value", 0) == 18,
		"Flurry Form is gated behind DEX 18")
	_check(rhythm.requirements.get("stat", "") == "dexterity" and rhythm.requirements.get("value", 0) == 18,
		"Killing Rhythm is gated behind DEX 18")

func _test_twin_strike_penalty() -> void:
	print("-- Flurry Form: per-hit damage penalty --")
	var stats = _fresh_stats()
	var before_phys = stats.get_effective_physical_damage(10)
	stats.keystone_dex_twin_strike = true
	_check(stats.get_effective_physical_damage(10) == before_phys - PlayerStats.DEX_TWIN_STRIKE_DAMAGE_PENALTY,
		"physical damage drops by the penalty (%d -> %d)" % [before_phys, stats.get_effective_physical_damage(10)])

func _test_killing_rhythm() -> void:
	print("-- Killing Rhythm: proc becomes armed bonus damage --")
	var stats = _fresh_stats()
	stats.base_dexterity = 20  # effective DEX 20 at full health -> bonus = floor(20 * 0.5) = 10
	stats.keystone_dex_flat_damage = true
	_proc_fired = false
	stats.dexterity_proc.connect(func(): _proc_fired = true)

	stats.current_attack_counter = 1  # next attack completes the counter
	var result = stats.register_attack()
	_check(not _proc_fired, "no dexterity_proc signal fires (tempo/mana proc suppressed)")
	_check(result.get("proc", true) == false, "register_attack reports no tempo proc")
	_check(stats.get_dex_proc_flat_bonus() == 10, "DEX 20 -> +10 flat bonus (got %d)" % stats.get_dex_proc_flat_bonus())
	_check(stats.pending_dex_bonus_damage == 10, "the bonus is armed for the next attack (%d)" % stats.pending_dex_bonus_damage)
	_check(stats.consume_pending_dex_bonus_damage() == 10 and stats.pending_dex_bonus_damage == 0,
		"consuming the bonus returns 10 and clears it")

func _test_normal_proc_unaffected() -> void:
	print("-- Baseline proc still fires without the keystones --")
	var stats = _fresh_stats()
	_proc_fired = false
	stats.dexterity_proc.connect(func(): _proc_fired = true)
	stats.current_attack_counter = 1
	var result = stats.register_attack()
	_check(_proc_fired, "dexterity_proc fires normally")
	_check(result.get("half_tempo", false) == true and result.get("mana_discount", 0) == 2,
		"the proc still grants half tempo + 2 mana")
	_check(result.get("twin_strike", true) == false, "twin_strike flag is false when Flurry Form is off")

func _test_persistence() -> void:
	print("-- Save / restore --")
	var stats = _fresh_stats()
	stats.keystone_dex_twin_strike = true
	stats.keystone_dex_flat_damage = true
	var snap = stats.save_progression()
	var restored = _fresh_stats()
	restored.restore_progression(snap)
	_check(restored.keystone_dex_twin_strike, "Flurry Form flag survives save/restore")
	_check(restored.keystone_dex_flat_damage, "Killing Rhythm flag survives save/restore")

func _fresh_stats() -> PlayerStats:
	var stats = PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(CharacterData.create_ryan())
	return stats
