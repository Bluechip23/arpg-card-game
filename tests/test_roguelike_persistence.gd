extends SceneTree

## Headless validation of roguelike run persistence, death-ends-run, and the
## frozen meta-progression snapshot.
## Run: godot --headless --path . --script tests/test_roguelike_persistence.gd

var failures: int = 0

func _fail(msg: String) -> void:
	failures += 1
	print("FAIL: %s" % msg)

func _count_visited(m: RoguelikeMap) -> int:
	var n := 0
	for id in m.nodes_by_id.keys():
		if m.nodes_by_id[id].visited:
			n += 1
	return n

func _initialize() -> void:
	var world := WorldData.make_new("Test World")
	world.unlocked_relic_ids.append("r1")

	# --- Meta snapshot is frozen at start ---
	var run := RoguelikeRun.new()
	run.start(CharacterData.create_ryan(), world, 321)
	var snap_relics: Array = run.meta_snapshot.get("relics", [])
	if not snap_relics.has("r1") or snap_relics.size() != 1:
		_fail("meta snapshot did not capture world relics")
	run.record_meta_unlock("relic", "r2")
	if not world.unlocked_relic_ids.has("r2"):
		_fail("new unlock not written to the live world")
	if run.meta_snapshot.get("relics", []).has("r2"):
		_fail("mid-run unlock leaked into the frozen snapshot")

	# --- Walk two floors, then serialize round-trip ---
	run.resolve_node(run.available_node_ids()[0])
	run.resolve_node(run.available_node_ids()[0])
	var disk := run.to_dict()
	var run2 := RoguelikeRun.from_dict(disk, run.character, world)
	if run2.current_node_id != run.current_node_id:
		_fail("current node id not preserved")
	if run2.hp != run.hp or run2.max_hp != run.max_hp or run2.gold != run.gold:
		_fail("run resources not preserved")
	if run2.map.nodes_by_id.size() != run.map.nodes_by_id.size():
		_fail("node count not preserved")
	if _count_visited(run2.map) != _count_visited(run.map):
		_fail("visited flags not preserved")
	if run2.available_node_ids() != run.available_node_ids():
		_fail("available options differ after restore")
	if run2.map.boss_node == null:
		_fail("boss node not restored")

	# --- Death ends the run as a loss ---
	var dead := RoguelikeRun.new()
	dead.start(CharacterData.create_ryan(), world, 7)
	dead.damage(dead.hp)
	if not dead.finished or dead.victorious:
		_fail("hp reaching 0 did not end the run as a loss")
	if dead.is_active():
		_fail("dead run still reports active")

	# --- Reaching the boss ends the run as a victory ---
	var won := RoguelikeRun.new()
	won.start(CharacterData.create_ryan(), world, 9)
	var steps := 0
	while not won.finished and steps < 100:
		var opts := won.available_node_ids()
		if opts.is_empty():
			break
		won.resolve_node(opts[0])
		steps += 1
	if not won.finished or not won.victorious:
		_fail("walking to the boss did not finish as a victory")

	if failures == 0:
		print("ALL ROGUELIKE PERSISTENCE TESTS PASSED")
	else:
		print("TOTAL FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
