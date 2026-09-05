extends SceneTree

## Verifies the passive-lane allocation model: archetype lanes extracted from
## the skill trees, stage unlock costs (5/15/25...), point allocation with the
## 15-level cap, level-1 activation, persistence, and old-save back-compat.
## Run: godot --headless --path . --script tests/test_passive_lanes.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Passive lane allocation test ===")

	# --- Lane extraction: every character tree yields archetype lanes ---
	var trees := {
		"Brad": SkillTreeData.create_brad_tree(),
		"Stephen": SkillTreeData.create_stephen_tree(),
		"Ryan": SkillTreeData.create_ryan_tree(),
		"Cory": SkillTreeData.create_cory_tree(),
		"Jeremy": SkillTreeData.create_jeremy_tree(),
	}
	for cname in trees:
		var lanes: Array = trees[cname].get_archetype_lanes()
		_check(lanes.size() >= 3, "%s has %d archetype lanes" % [cname, lanes.size()])
		for lane in lanes:
			_check(lane["passives"].size() >= 1, "%s lane '%s' has %d passive(s)" % [cname, lane["name"], lane["passives"].size()])
			for opt in lane["passives"]:
				if opt.archetype != lane["name"]:
					_check(false, "%s lane '%s' holds a foreign passive" % [cname, lane["name"]])

	# --- Stage gates: the first stage is free; every later stage opens once
	# 5 points sit in the WHOLE previous stage (any archetype) ---
	_check(SkillTreeData.stage_unlock_cost(0) == 0, "stage 1 is free")
	for st in range(1, 5):
		_check(SkillTreeData.stage_unlock_cost(st) == SkillTreeData.STAGE_GATE_POINTS,
			"stage %d needs %d points across the previous stage" % [st + 1, SkillTreeData.STAGE_GATE_POINTS])
	var brad_lanes: Array = trees["Brad"].get_archetype_lanes()
	var gate_stats = load("res://scripts/character/player_stats.gd").new()
	gate_stats.initialize(CharacterData.create_brad())
	_check(SkillTreeData.stage_points(brad_lanes, 0, gate_stats) == 0, "fresh tree: stage 1 holds 0 points")
	_check(not SkillTreeData.is_stage_unlocked(brad_lanes, 1, gate_stats), "stage 2 locked with 0 points in stage 1")
	gate_stats.unspent_passive_points = 10
	# Spread 5 points over DIFFERENT archetypes' first-stage passives: the gate
	# counts the whole stage, not one lane.
	var spread := 0
	for lane in brad_lanes:
		if spread >= SkillTreeData.STAGE_GATE_POINTS:
			break
		gate_stats.allocate_passive_point(lane["passives"][0].passive_id)
		spread += 1
	while spread < SkillTreeData.STAGE_GATE_POINTS:
		gate_stats.allocate_passive_point(brad_lanes[0]["passives"][0].passive_id)
		spread += 1
	_check(SkillTreeData.stage_points(brad_lanes, 0, gate_stats) == SkillTreeData.STAGE_GATE_POINTS,
		"5 points spread across archetypes all count toward stage 1")
	_check(SkillTreeData.is_stage_unlocked(brad_lanes, 1, gate_stats), "stage 2 unlocks off the whole previous stage")
	_check(not SkillTreeData.is_stage_unlocked(brad_lanes, 2, gate_stats), "stage 3 still locked (0 points in stage 2)")
	gate_stats.free()

	# --- Rank-specific description text (what the tree tooltip shows) ---
	var ew_desc := "When you drop below 10%→25% HP (scales with rank), swing. Cooldown: 25→10 tempo"
	_check(PassiveScaling.describe_at_rank("enraged_will", ew_desc, 1) == "When you drop below 10% HP, swing. Cooldown: 25 tempo",
		"rank 1 text reads the table's first entries")
	_check(PassiveScaling.describe_at_rank("enraged_will", ew_desc, 3) == "When you drop below 12% HP, swing. Cooldown: 23 tempo",
		"rank 3 text: fraction table shown as a percent, cooldown counts down")
	_check(PassiveScaling.describe_at_rank("enraged_will", ew_desc, 15) == "When you drop below 25% HP, swing. Cooldown: 10 tempo",
		"rank 15 text reads the table's last entries")
	_check(PassiveScaling.describe_at_rank("the_way_of_the_plate", "Every 9th→2nd Defense card", 5) == "Every 7th Defense card",
		"ordinal ranges re-suffix the rank value")
	_check(PassiveScaling.describe_at_rank("self_reliance", "cost -10m→-80m", 15) == "cost -80m",
		"negative mana ranges match the positive table")
	_check(PassiveScaling.describe_at_rank("nothing_here", "gain 0→14 armor", 8) == "gain 7 armor",
		"unknown passive interpolates the range linearly")
	_check(PassiveScaling.describe_at_rank("x", "Attack→Heal: convert", 3) == "Attack→Heal: convert",
		"non-numeric arrows are untouched")

	# --- Allocation rules ---
	var stats = load("res://scripts/character/player_stats.gd").new()
	stats.initialize(CharacterData.create_ryan())
	_check(not stats.allocate_passive_point("keep_them_guessing"), "no points -> allocation refused")
	stats.unspent_passive_points = 20
	_check(stats.allocate_passive_point("keep_them_guessing"), "allocation spends a point")
	_check(stats.get_passive_level("keep_them_guessing") == 1, "passive is level 1")
	_check(stats.has_skill_tree_passive("keep_them_guessing"), "level 1 activates the passive effect")
	_check(stats.unspent_passive_points == 19, "pool decremented")
	for _i in range(19):
		stats.allocate_passive_point("keep_them_guessing")
	_check(stats.get_passive_level("keep_them_guessing") == PlayerStats.PASSIVE_MAX_LEVEL,
		"level capped at %d" % PlayerStats.PASSIVE_MAX_LEVEL)
	_check(stats.unspent_passive_points == 20 - PlayerStats.PASSIVE_MAX_LEVEL,
		"points past the cap are not consumed")

	# --- Level-up banks passive points ---
	var before: int = stats.unspent_passive_points
	stats._level_up()
	_check(stats.unspent_passive_points == before + PlayerStats.PASSIVE_POINTS_PER_LEVEL,
		"level-up banks +%d passive points" % PlayerStats.PASSIVE_POINTS_PER_LEVEL)

	# --- Persistence round trip ---
	var saved = stats.save_progression()
	var fresh = load("res://scripts/character/player_stats.gd").new()
	fresh.initialize(CharacterData.create_ryan())
	fresh.restore_progression(saved)
	_check(fresh.get_passive_level("keep_them_guessing") == PlayerStats.PASSIVE_MAX_LEVEL,
		"passive levels survive save/restore")
	_check(fresh.unspent_passive_points == stats.unspent_passive_points,
		"banked passive points survive save/restore")

	# --- Back-compat: old saves list passives with no levels -> level 1 ---
	var old_save = {"skill_tree_passives": ["eagle_eye"]}
	var legacy = load("res://scripts/character/player_stats.gd").new()
	legacy.initialize(CharacterData.create_ryan())
	legacy.restore_progression(old_save)
	_check(legacy.get_passive_level("eagle_eye") == 1, "legacy passive restored at level 1")
	_check(legacy.has_skill_tree_passive("eagle_eye"), "legacy passive still active")

	stats.free()
	fresh.free()
	legacy.free()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
