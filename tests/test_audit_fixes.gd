extends SceneTree

## Verifies the audit section A/B fixes: the sphere passive parser magnitude
## bugs, Empower's defense behavior, sphere resistance, and Iron Bastion.
## Run: godot --headless --path . --script tests/test_audit_fixes.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Audit fix test ===")

	# --- Sphere passive parser: magnitude % must not be eaten as proc chance ---
	var pt = load("res://scripts/progression/progression_triggers.gd").new()
	var p1 = pt._parse_passive_description("On crit: deal 50% bonus", 0)
	_check(p1.get("effect", "") == "bonus_damage" and p1.get("value", 0) == 50,
		"crit bonus node parses as bonus_damage 50 (got " + str(p1.get("effect")) + " " + str(p1.get("value")) + ")")
	_check(p1.get("chance", 0.0) >= 1.0, "the 50 percent is a magnitude, not a proc chance")

	var p2 = pt._parse_passive_description("On heal: overheal becomes armor", 0)
	_check(p2.get("effect", "") == "overheal_armor",
		"'overheal becomes armor' beats the generic heal branch (got %s)" % p2.get("effect"))

	var p3 = pt._parse_passive_description("On heal: overheal becomes 200% armor", 0)
	_check(p3.get("effect", "") == "overheal_armor" and p3.get("value", 0) == 200,
		"upgraded overheal node keeps its 200 (got " + str(p3.get("effect")) + " " + str(p3.get("value")) + ")")

	var p4 = pt._parse_passive_description("On attack: 5% freeze enemy for 1 cycle", 0)
	_check(p4.get("effect", "") == "freeze_enemy" and absf(p4.get("chance", 0.0) - 0.05) < 0.001,
		"freeze transmute parses as freeze_enemy at 5 percent (got " + str(p4.get("effect")) + ")")

	# --- Empower on defense: mana refund, full armor ---
	var stats = load("res://scripts/character/player_stats.gd").new()
	stats.initialize(CharacterData.create_ryan())
	stats.current_mana = 0.0
	stats.apply_empower(2)
	var block_card = Card.create_block()
	block_card.execute(null, stats, null)
	_check(stats.current_armor == block_card.block, "empowered block grants FULL armor (%d)" % stats.current_armor)
	_check(int(stats.current_mana) == stats.empower_block_reduction,
		"empowered defense refunds %d mana" % stats.empower_block_reduction)

	# --- Sphere resistance actually reduces damage ---
	stats.current_armor = 0
	stats.current_health = stats.max_health
	stats.sphere_bonus_resistance = 50.0
	stats.take_damage(10)
	_check(stats.max_health - stats.current_health == 5, "Resist 50 percent halves a 10 hit")

	# --- Iron Bastion proc (forced to 100% chance) ---
	stats.sphere_bonus_resistance = 0.0
	stats.current_health = stats.max_health
	stats.damage_proc_reduction_chance = 1.0
	stats.take_damage(10)
	_check(stats.max_health - stats.current_health == 5, "Iron Bastion halves the hit when it procs")

	stats.free()
	pt.free()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
