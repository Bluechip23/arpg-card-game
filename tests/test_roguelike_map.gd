extends SceneTree

## Headless validation of roguelike map generation and run navigation.
## Run: godot --headless --path . --script tests/test_roguelike_map.gd

var failures: int = 0

func _initialize() -> void:
	_test_determinism()
	_test_structure()
	_test_connectivity()
	_test_run_navigation()

	if failures == 0:
		print("ALL ROGUELIKE MAP TESTS PASSED")
	else:
		print("TOTAL FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)

func _fail(msg: String) -> void:
	failures += 1
	print("FAIL: %s" % msg)

func _signature(m: RoguelikeMap) -> String:
	var parts: Array = []
	for r in range(m.rows.size()):
		for node in m.rows[r]:
			var nexts: Array = node.next_ids.duplicate()
			nexts.sort()
			parts.append("%d:%d:%d:%s" % [node.row, node.col, node.type, str(nexts)])
	return "|".join(parts)

func _test_determinism() -> void:
	var a := RoguelikeMap.new()
	a.generate(12345)
	var b := RoguelikeMap.new()
	b.generate(12345)
	if _signature(a) != _signature(b):
		_fail("generation is not deterministic for the same seed")
	var c := RoguelikeMap.new()
	c.generate(99999)
	if _signature(a) == _signature(c):
		_fail("different seeds produced identical maps (suspicious)")

func _test_structure() -> void:
	var m := RoguelikeMap.new()
	m.generate(7)

	# First row must be all monsters.
	for node in m.rows[0]:
		if node.type != RoguelikeMapNode.Type.MONSTER:
			_fail("first row node is not a monster")

	# Row just below boss must be all campfires.
	var pre_boss: Array = m.rows[RoguelikeMap.ROWS - 1]
	for node in pre_boss:
		if node.type != RoguelikeMapNode.Type.CAMPFIRE:
			_fail("pre-boss row node is not a campfire")

	# Final row is a single boss.
	var last: Array = m.rows[m.rows.size() - 1]
	if last.size() != 1 or last[0].type != RoguelikeMapNode.Type.BOSS:
		_fail("final row is not a single boss node")
	if m.boss_node == null or m.boss_node.type != RoguelikeMapNode.Type.BOSS:
		_fail("boss_node not set correctly")

	# Every non-boss node must have at least one outgoing edge.
	for id in m.nodes_by_id.keys():
		var node: RoguelikeMapNode = m.nodes_by_id[id]
		if node.type != RoguelikeMapNode.Type.BOSS and node.next_ids.is_empty():
			_fail("node %d has no outgoing edge" % id)

func _test_connectivity() -> void:
	var m := RoguelikeMap.new()
	m.generate(424242)

	# BFS from all first-row nodes; every node must be reachable, including boss.
	var reached: Dictionary = {}
	var frontier: Array = m.first_row_ids()
	for id in frontier:
		reached[id] = true
	while not frontier.is_empty():
		var cur: int = frontier.pop_back()
		var node: RoguelikeMapNode = m.get_node(cur)
		for nid in node.next_ids:
			if not reached.has(nid):
				reached[nid] = true
				frontier.append(nid)

	if reached.size() != m.nodes_by_id.size():
		_fail("not all nodes reachable from row 0 (%d of %d)" % [reached.size(), m.nodes_by_id.size()])
	if not reached.has(m.boss_node.id):
		_fail("boss is not reachable from row 0")

	# Every node above row 0 must have an incoming edge.
	var has_incoming: Dictionary = {}
	for id in m.nodes_by_id.keys():
		var node: RoguelikeMapNode = m.nodes_by_id[id]
		for nid in node.next_ids:
			has_incoming[nid] = true
	for id in m.nodes_by_id.keys():
		var node: RoguelikeMapNode = m.nodes_by_id[id]
		if node.row > 0 and not has_incoming.has(id):
			_fail("node %d (row %d) has no incoming edge" % [id, node.row])

func _test_run_navigation() -> void:
	var run := RoguelikeRun.new()
	run.start(CharacterData.create_ryan(), WorldData.make_new("Test World"), 555)

	var start_options := run.available_node_ids()
	var expected := run.map.first_row_ids()
	if start_options != expected:
		_fail("run does not start with first-row options")
	if run.hp <= 0 or run.hp != run.max_hp:
		_fail("run did not initialize HP to full")

	# Walk a full path to the boss, always taking the first available node.
	var steps := 0
	while not run.finished and steps < 100:
		var options := run.available_node_ids()
		if options.is_empty():
			_fail("ran out of options before reaching the boss")
			break
		run.resolve_node(options[0])
		steps += 1

	if not run.finished or not run.victorious:
		_fail("could not walk a path to the boss")
	if run.floor_reached != run.map.total_rows():
		_fail("floor_reached (%d) did not match total rows (%d) after clearing" % [run.floor_reached, run.map.total_rows()])
