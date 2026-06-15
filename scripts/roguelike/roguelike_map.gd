class_name RoguelikeMap
extends RefCounted

## Generates and holds the node graph for a single roguelike run.
##
## Layout is a stack of rows (floors). Row 0 is the first floor; the final row
## is a single boss node. Each node connects upward to one or more nodes on the
## next row, and generation guarantees the graph is fully connected (every node
## is reachable from row 0 and every node leads toward the boss).
##
## Generation is deterministic for a given seed so a world/run map is stable.

const ROWS: int = 8            ## number of encounter rows before the boss row
const MIN_ROW_WIDTH: int = 2
const MAX_ROW_WIDTH: int = 4

## Spawn weights for the base node types (sum = 100). The first row is always
## monsters and the row just below the boss is always a campfire, so these
## weights apply to the middle rows.
var TYPE_WEIGHTS: Array = [
	[RoguelikeMapNode.Type.MONSTER, 50],
	[RoguelikeMapNode.Type.RANDOM, 10],
	[RoguelikeMapNode.Type.ELITE, 10],
	[RoguelikeMapNode.Type.SHOP, 15],
	[RoguelikeMapNode.Type.CAMPFIRE, 15],
]

var seed_value: int = 0
var rows: Array = []                ## Array[Array[RoguelikeMapNode]]; last entry is [boss]
var nodes_by_id: Dictionary = {}    ## id -> RoguelikeMapNode
var boss_node: RoguelikeMapNode = null

func generate(seed_val: int) -> void:
	seed_value = seed_val
	rows.clear()
	nodes_by_id.clear()
	boss_node = null

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var next_id: int = 0

	# Encounter rows
	for r in range(ROWS):
		var width: int = rng.randi_range(MIN_ROW_WIDTH, MAX_ROW_WIDTH)
		var row_nodes: Array = []
		for c in range(width):
			var node := RoguelikeMapNode.new()
			node.id = next_id
			next_id += 1
			node.row = r
			node.col = c
			node.type = _pick_type(rng, r)
			nodes_by_id[node.id] = node
			row_nodes.append(node)
		rows.append(row_nodes)

	# Boss row
	boss_node = RoguelikeMapNode.new()
	boss_node.id = next_id
	boss_node.row = ROWS
	boss_node.col = 0
	boss_node.type = RoguelikeMapNode.Type.BOSS
	nodes_by_id[boss_node.id] = boss_node
	rows.append([boss_node])

	# Connect each row to the next, guaranteeing connectivity
	for r in range(ROWS):
		_connect_rows(rng, rows[r], rows[r + 1])

func get_node(id: int) -> RoguelikeMapNode:
	return nodes_by_id.get(id, null)

func first_row_ids() -> Array[int]:
	var ids: Array[int] = []
	if rows.size() > 0:
		for node in rows[0]:
			ids.append(node.id)
	return ids

func total_rows() -> int:
	return rows.size()

func _pick_type(rng: RandomNumberGenerator, row: int) -> int:
	# First floor: always combat so a run opens with a fight.
	if row == 0:
		return RoguelikeMapNode.Type.MONSTER
	# Floor right before the boss: always a campfire to rest/prepare.
	if row == ROWS - 1:
		return RoguelikeMapNode.Type.CAMPFIRE

	var total: int = 0
	for entry in TYPE_WEIGHTS:
		total += entry[1]
	var roll: int = rng.randi_range(0, total - 1)
	var acc: int = 0
	for entry in TYPE_WEIGHTS:
		acc += entry[1]
		if roll < acc:
			return entry[0]
	return RoguelikeMapNode.Type.MONSTER

func _connect_rows(rng: RandomNumberGenerator, from_row: Array, to_row: Array) -> void:
	var n_from: int = from_row.size()
	var n_to: int = to_row.size()

	# Primary edge: each source node connects to its proportional target so
	# edges fan out without crossing much.
	for i in range(n_from):
		var t: int
		if n_from > 1:
			t = int(round(float(i) / float(n_from - 1) * float(n_to - 1)))
		else:
			t = rng.randi_range(0, n_to - 1)
		t = clampi(t, 0, n_to - 1)
		_add_edge(from_row[i], to_row[t])
		# Optional branch to an adjacent target for more route variety.
		if n_to > 1 and rng.randf() < 0.35:
			var dir: int = 1 if rng.randf() < 0.5 else -1
			var t2: int = clampi(t + dir, 0, n_to - 1)
			if t2 != t:
				_add_edge(from_row[i], to_row[t2])

	# Guarantee every target has at least one incoming edge.
	for j in range(n_to):
		if not _has_incoming(from_row, to_row[j]):
			var fi: int
			if n_to > 1:
				fi = int(round(float(j) / float(n_to - 1) * float(n_from - 1)))
			else:
				fi = 0
			fi = clampi(fi, 0, n_from - 1)
			_add_edge(from_row[fi], to_row[j])

func _add_edge(from_node: RoguelikeMapNode, to_node: RoguelikeMapNode) -> void:
	if not from_node.next_ids.has(to_node.id):
		from_node.next_ids.append(to_node.id)

func _has_incoming(from_row: Array, to_node: RoguelikeMapNode) -> bool:
	for fn in from_row:
		if fn.next_ids.has(to_node.id):
			return true
	return false

# ----------------------------------------------------------------------------
# Persistence
# ----------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var node_dicts: Array = []
	for r in range(rows.size()):
		for node in rows[r]:
			node_dicts.append({
				"id": node.id,
				"type": node.type,
				"row": node.row,
				"col": node.col,
				"next_ids": node.next_ids.duplicate(),
				"visited": node.visited,
			})
	return {
		"seed": seed_value,
		"nodes": node_dicts,
		"boss_id": boss_node.id if boss_node else -1,
	}

static func from_dict(data: Dictionary) -> RoguelikeMap:
	var m := RoguelikeMap.new()
	m.seed_value = int(data.get("seed", 0))
	var node_dicts: Array = data.get("nodes", [])
	var boss_id: int = int(data.get("boss_id", -1))
	var max_row: int = 0
	for nd in node_dicts:
		max_row = maxi(max_row, int(nd.get("row", 0)))
	# Prepare empty rows.
	m.rows = []
	for _r in range(max_row + 1):
		m.rows.append([])
	for nd in node_dicts:
		var node := RoguelikeMapNode.new()
		node.id = int(nd.get("id", -1))
		node.type = int(nd.get("type", RoguelikeMapNode.Type.MONSTER))
		node.row = int(nd.get("row", 0))
		node.col = int(nd.get("col", 0))
		node.visited = bool(nd.get("visited", false))
		var nexts: Array[int] = []
		for v in nd.get("next_ids", []):
			nexts.append(int(v))
		node.next_ids = nexts
		m.nodes_by_id[node.id] = node
		m.rows[node.row].append(node)
		if node.id == boss_id:
			m.boss_node = node
	# Keep each row ordered by column for stable layout.
	for r in range(m.rows.size()):
		m.rows[r].sort_custom(func(a, b): return a.col < b.col)
	return m
