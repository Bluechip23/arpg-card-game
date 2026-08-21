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

	# --- Stage unlock costs: 0 / 5 / 15 / 25 / 35 ---
	_check(SkillTreeData.stage_unlock_cost(0) == 0, "stage 1 is free")
	_check(SkillTreeData.stage_unlock_cost(1) == 5, "stage 2 needs 5 lane points")
	_check(SkillTreeData.stage_unlock_cost(2) == 15, "stage 3 needs 15 lane points")
	_check(SkillTreeData.stage_unlock_cost(3) == 25, "stage 4 needs 25 lane points")
	_check(SkillTreeData.stage_unlock_cost(4) == 35, "stage 5 needs 35 lane points")

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
