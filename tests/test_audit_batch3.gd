extends SceneTree

## Verifies the third audit fix batch: B9 override-table trim, C5 AoE shading
## ranges, D2 keyword-aware number substitution, D4 Quick Shot, D6/D7 nulled
## sphere nodes, D9 Cover's dead reaction tempo cost.
## Run: godot --headless --path . --script tests/test_audit_batch3.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Audit batch 3 test ===")

	# --- B9: phantom-block cards dropped from the display override table ---
	var main_consts: Dictionary = load("res://scripts/core/main.gd").get_script_constant_map()
	var overrides: Dictionary = main_consts.get("BLOCK_AMOUNT_OVERRIDES", {})
	for gone in ["turtle_up", "meditate", "mana_surge"]:
		_check(not overrides.has(gone), "%s no longer in BLOCK_AMOUNT_OVERRIDES" % gone)
	for kept in ["hold_the_line", "vengeful_shield"]:
		_check(overrides.has(kept), "%s still overridden (really grants armor)" % kept)

	# --- C5: AoE shading matches the real effect ---
	_check(Card.create_internal_combustion().aoe_range == 3.0, "Internal Combustion shades 3.0")
	_check(Card.create_round_em_up().aoe_range == 2.0, "Round 'Em Up shades 2.0")
	_check(Card.create_worms_armageddon().aoe_range == 100.0, "Worms Armageddon shades the whole field")
	_check(Card.create_spirit_arrow().aoe_range == 100.0, "Spirit Arrow shades the full pierce line")
	_check(not Card.create_god_of_thunder().is_aoe, "God of Thunder no longer AoE-flagged")

	# --- D2: substitution keys numbers to their own stat keyword ---
	var fa = Card.create_fortify_alliance()
	var shown = fa.get_display_description({
		"heal": 7, "heal_base": 5, "block": 9, "block_base": 5,
	})
	_check("]7[/color] and give" in shown, "heal number lands on the heal slot (got: %s)" % shown)
	_check("]9[/color] armor" in shown, "block number lands on the armor slot")

	# --- D4: Quick Shot = 2 base + half modifiers ---
	var qs = Card.create_quick_shot()
	_check(qs.base_damage == 2, "Quick Shot base damage is 2 (got %d)" % qs.base_damage)
	_check("half modifiers" in qs.description, "Quick Shot description explains the formula")

	# --- D3: empowered defense grants LESS block (regression alongside audit_fixes) ---
	var stats = load("res://scripts/character/player_stats.gd").new()
	stats.initialize(CharacterData.create_ryan())
	stats.apply_empower(1)
	var blk = Card.create_block()
	blk.execute(null, stats, null)
	_check(stats.current_armor == blk.block - stats.empower_block_reduction,
		"empowered block is %d less armor" % stats.empower_block_reduction)
	stats.free()

	# --- D6/D7: nodes 72, 76, 101 are null connectors ---
	var grid = SphereGrid.new()
	for nid in [72, 76, 101]:
		var node = grid.get_node_by_id(nid)
		_check(node != null and node.node_type == SphereGrid.NodeType.NULL_NODE,
			"sphere node %d is a NULL_NODE" % nid)

	# --- D9: Cover's dead reaction tempo cost removed ---
	_check(Card.create_cover().tempo_cost == 0, "Cover (reaction) charges no tempo")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
