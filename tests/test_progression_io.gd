extends SceneTree

## Headless validation of ProgressionIO disk round-tripping.
## Run: godot --headless --path . --script tests/test_progression_io.gd

var failures: int = 0

func _fail(msg: String) -> void:
	failures += 1
	print("FAIL: %s" % msg)

func _initialize() -> void:
	var sg := SphereGrid.new()
	# id 0 (START) is unlocked by default; unlock two more.
	sg.get_node_by_id(1).unlocked = true
	sg.get_node_by_id(2).unlocked = true

	var live := {
		"stats": {"current_level": 7, "max_health": 42},
		"deck_state": {"hand": ["slash", "block"], "draw_pile": ["dodge"]},
		"sphere_inventory": {"spheres": {"red": 3}, "retrospective_tokens": 1},
		"sphere_grid": sg,
	}

	# --- to_disk ---
	var disk := ProgressionIO.to_disk(live)
	if disk.get("stats", {}).get("current_level", -1) != 7:
		_fail("stats not carried to disk")
	if not disk.has("sphere_unlocked_ids"):
		_fail("sphere unlocked ids not captured")
	var ids: Array = disk.get("sphere_unlocked_ids", [])
	if not (ids.has(0) and ids.has(1) and ids.has(2)):
		_fail("unlocked node ids incomplete: %s" % str(ids))
	if ids.has(3):
		_fail("locked node 3 was captured as unlocked")

	# stats_override should win over live stats.
	var disk2 := ProgressionIO.to_disk(live, {"current_level": 9})
	if disk2.get("stats", {}).get("current_level", -1) != 9:
		_fail("stats_override not applied")

	# --- to_live ---
	var live2 := ProgressionIO.to_live(disk)
	var sg2 = live2.get("sphere_grid")
	if sg2 == null or not (sg2 is SphereGrid):
		_fail("sphere grid not reconstructed")
	else:
		if not (sg2.get_node_by_id(0).unlocked and sg2.get_node_by_id(1).unlocked and sg2.get_node_by_id(2).unlocked):
			_fail("reconstructed grid missing unlocked nodes")
		if sg2.get_node_by_id(3).unlocked:
			_fail("reconstructed grid unlocked a node that should be locked")
	if live2.get("stats", {}).get("max_health", -1) != 42:
		_fail("stats not carried back to live")
	if live2.get("deck_state", {}).get("hand", []) != ["slash", "block"]:
		_fail("deck state not carried back to live")

	# Empty snapshot behaves like "no progression".
	if not ProgressionIO.to_live({}).is_empty():
		_fail("empty disk did not produce empty live progression")

	if failures == 0:
		print("ALL PROGRESSION IO TESTS PASSED")
	else:
		print("TOTAL FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
