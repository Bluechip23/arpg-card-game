class_name SphereGrid
extends Resource

## Data model for the sphere grid leveling system.
## Contains 100 nodes arranged in concentric rings with connections for pathing.

enum NodeType {
	STAT_BONUS,    # Flat stat increase (STR, DEX, INT, WIS, AGI, DET)
	PASSIVE,       # Triggered passive (everytime you do X, Y happens)
	CARD,          # Grants a new card
	HEALTH,        # Max health increase
	MANA,          # Max mana increase
	START          # Starting node (already unlocked)
}

class GridNode:
	var id: int
	var node_type: NodeType
	var label: String               # Short display name
	var description: String         # Tooltip description
	var position: Vector2           # Position on the grid UI
	var connections: Array[int]     # IDs of connected nodes
	var unlocked: bool = false
	var ring: int = 0               # Which ring this node belongs to (0=center)

	func _init(p_id: int, p_type: NodeType, p_label: String, p_desc: String, p_pos: Vector2, p_ring: int = 0) -> void:
		id = p_id
		node_type = p_type
		label = p_label
		description = p_desc
		position = p_pos
		connections = []
		ring = p_ring

var nodes: Array = []  # Array of GridNode
var _node_map: Dictionary = {}  # id -> GridNode lookup

func _init() -> void:
	_build_grid()

func get_node_by_id(id: int) -> GridNode:
	return _node_map.get(id, null)

func get_all_nodes() -> Array:
	return nodes

func get_connections_for(id: int) -> Array[int]:
	var node = get_node_by_id(id)
	if node:
		return node.connections
	return []

func is_unlockable(id: int) -> bool:
	var node = get_node_by_id(id)
	if not node or node.unlocked:
		return false
	for conn_id in node.connections:
		var neighbor = get_node_by_id(conn_id)
		if neighbor and neighbor.unlocked:
			return true
	return false

func unlock_node(id: int) -> bool:
	if not is_unlockable(id):
		return false
	var node = get_node_by_id(id)
	node.unlocked = true
	return true

func _add_node(node: GridNode) -> void:
	nodes.append(node)
	_node_map[node.id] = node

func _connect_nodes(id_a: int, id_b: int) -> void:
	var a = get_node_by_id(id_a)
	var b = get_node_by_id(id_b)
	if a and b:
		if id_b not in a.connections:
			a.connections.append(id_b)
		if id_a not in b.connections:
			b.connections.append(id_a)

func _build_grid() -> void:
	nodes.clear()
	_node_map.clear()

	var center = Vector2(640, 360)  # Center of 1280x720

	# === Ring 0: Center (1 node) — the START node ===
	var n0 = GridNode.new(0, NodeType.START, "Origin", "Starting point", center, 0)
	n0.unlocked = true
	_add_node(n0)

	# === Ring 1: 6 nodes at radius 70 ===
	var ring1_types = [
		[NodeType.STAT_BONUS, "STR +1", "Strength +1"],
		[NodeType.STAT_BONUS, "DEX +1", "Dexterity +1"],
		[NodeType.STAT_BONUS, "INT +1", "Intelligence +1"],
		[NodeType.STAT_BONUS, "WIS +1", "Wisdom +1"],
		[NodeType.STAT_BONUS, "AGI +1", "Agility +1"],
		[NodeType.STAT_BONUS, "DET +1", "Determination +1"],
	]
	_create_ring(1, 6, 70.0, center, ring1_types, 1)

	# Connect ring 1 to center
	for i in range(6):
		_connect_nodes(0, 1 + i)
	# Connect ring 1 nodes to each other (hexagon)
	for i in range(6):
		_connect_nodes(1 + i, 1 + ((i + 1) % 6))

	# === Ring 2: 12 nodes at radius 140 ===
	var ring2_types = [
		[NodeType.HEALTH, "HP +5", "Max Health +5"],
		[NodeType.PASSIVE, "Passive", "On kill: heal 1 HP"],
		[NodeType.STAT_BONUS, "STR +2", "Strength +2"],
		[NodeType.MANA, "Mana +3", "Max Mana +3"],
		[NodeType.PASSIVE, "Passive", "On card play: 5% draw extra"],
		[NodeType.STAT_BONUS, "DEX +2", "Dexterity +2"],
		[NodeType.HEALTH, "HP +5", "Max Health +5"],
		[NodeType.PASSIVE, "Passive", "On move: gain 1 armor"],
		[NodeType.STAT_BONUS, "INT +2", "Intelligence +2"],
		[NodeType.MANA, "Mana +3", "Max Mana +3"],
		[NodeType.PASSIVE, "Passive", "On cycle: regen 1 mana"],
		[NodeType.STAT_BONUS, "WIS +2", "Wisdom +2"],
	]
	_create_ring(7, 12, 140.0, center, ring2_types, 2)

	# Connect ring 2 to ring 1 (each ring1 node connects to 2 ring2 nodes)
	for i in range(6):
		_connect_nodes(1 + i, 7 + i * 2)
		_connect_nodes(1 + i, 7 + i * 2 + 1)
	# Connect ring 2 adjacent nodes
	for i in range(12):
		_connect_nodes(7 + i, 7 + ((i + 1) % 12))

	# === Ring 3: 18 nodes at radius 210 ===
	var ring3_types = [
		[NodeType.CARD, "Card", "Unlocks a new card"],
		[NodeType.STAT_BONUS, "STR +3", "Strength +3"],
		[NodeType.PASSIVE, "Passive", "On attack: 10% apply bleed"],
		[NodeType.CARD, "Card", "Unlocks a new card"],
		[NodeType.STAT_BONUS, "DEX +3", "Dexterity +3"],
		[NodeType.PASSIVE, "Passive", "On dodge: gain 2 tempo"],
		[NodeType.CARD, "Card", "Unlocks a new card"],
		[NodeType.STAT_BONUS, "INT +3", "Intelligence +3"],
		[NodeType.HEALTH, "HP +10", "Max Health +10"],
		[NodeType.CARD, "Card", "Unlocks a new card"],
		[NodeType.STAT_BONUS, "WIS +3", "Wisdom +3"],
		[NodeType.PASSIVE, "Passive", "On heal: 15% cleanse debuff"],
		[NodeType.CARD, "Card", "Unlocks a new card"],
		[NodeType.STAT_BONUS, "AGI +3", "Agility +3"],
		[NodeType.MANA, "Mana +5", "Max Mana +5"],
		[NodeType.CARD, "Card", "Unlocks a new card"],
		[NodeType.STAT_BONUS, "DET +3", "Determination +3"],
		[NodeType.PASSIVE, "Passive", "On block: reflect 2 damage"],
	]
	_create_ring(19, 18, 210.0, center, ring3_types, 3)

	# Connect ring 3 to ring 2
	for i in range(12):
		_connect_nodes(7 + i, 19 + int(i * 1.5))
		_connect_nodes(7 + i, 19 + int(i * 1.5) + 1)
	# Remove duplicate connections that _connect_nodes handles gracefully
	# Connect ring 3 adjacent
	for i in range(18):
		_connect_nodes(19 + i, 19 + ((i + 1) % 18))

	# === Ring 4: 24 nodes at radius 280 ===
	var ring4_types = [
		[NodeType.PASSIVE, "Passive", "On crit: deal 50% bonus"],
		[NodeType.HEALTH, "HP +10", "Max Health +10"],
		[NodeType.STAT_BONUS, "STR +4", "Strength +4"],
		[NodeType.CARD, "Card", "Unlocks a new card"],
		[NodeType.PASSIVE, "Passive", "On kill: draw 1 card"],
		[NodeType.MANA, "Mana +5", "Max Mana +5"],
		[NodeType.STAT_BONUS, "DEX +4", "Dexterity +4"],
		[NodeType.CARD, "Card", "Unlocks a new card"],
		[NodeType.PASSIVE, "Passive", "On spell cast: 10% refund mana"],
		[NodeType.HEALTH, "HP +15", "Max Health +15"],
		[NodeType.STAT_BONUS, "INT +4", "Intelligence +4"],
		[NodeType.CARD, "Card", "Unlocks a new card"],
		[NodeType.PASSIVE, "Passive", "On tempo cycle: all enemies -1 armor"],
		[NodeType.MANA, "Mana +8", "Max Mana +8"],
		[NodeType.STAT_BONUS, "WIS +4", "Wisdom +4"],
		[NodeType.CARD, "Card", "Unlocks a new card"],
		[NodeType.PASSIVE, "Passive", "On discard: 20% return to hand"],
		[NodeType.HEALTH, "HP +15", "Max Health +15"],
		[NodeType.STAT_BONUS, "AGI +4", "Agility +4"],
		[NodeType.CARD, "Card", "Unlocks a new card"],
		[NodeType.PASSIVE, "Passive", "On move: 10% gain haste"],
		[NodeType.MANA, "Mana +8", "Max Mana +8"],
		[NodeType.STAT_BONUS, "DET +4", "Determination +4"],
		[NodeType.CARD, "Card", "Unlocks a new card"],
	]
	_create_ring(37, 24, 280.0, center, ring4_types, 4)

	# Connect ring 4 to ring 3
	for i in range(18):
		var r4_base = int(i * 1.333)
		_connect_nodes(19 + i, 37 + (r4_base % 24))
		_connect_nodes(19 + i, 37 + ((r4_base + 1) % 24))
	# Connect ring 4 adjacent
	for i in range(24):
		_connect_nodes(37 + i, 37 + ((i + 1) % 24))

	# === Ring 5 (outer): 39 nodes at radius 340 ===
	# IDs 61..99 (39 nodes to reach 100 total)
	var ring5_types: Array = []
	var r5_labels = [
		[NodeType.CARD, "Card", "Unlocks a new card"],
		[NodeType.PASSIVE, "Passive", "On attack: 5% stun enemy"],
		[NodeType.STAT_BONUS, "STR +5", "Strength +5"],
		[NodeType.HEALTH, "HP +20", "Max Health +20"],
		[NodeType.PASSIVE, "Passive", "On kill: gain 3 armor"],
		[NodeType.STAT_BONUS, "DEX +5", "Dexterity +5"],
		[NodeType.MANA, "Mana +10", "Max Mana +10"],
		[NodeType.CARD, "Card", "Unlocks a new card"],
		[NodeType.PASSIVE, "Passive", "On block: 15% counterattack"],
		[NodeType.STAT_BONUS, "INT +5", "Intelligence +5"],
		[NodeType.HEALTH, "HP +20", "Max Health +20"],
		[NodeType.PASSIVE, "Passive", "On spell cast: 5% double cast"],
		[NodeType.CARD, "Card", "Unlocks a new card"],
		[NodeType.STAT_BONUS, "WIS +5", "Wisdom +5"],
		[NodeType.MANA, "Mana +10", "Max Mana +10"],
		[NodeType.PASSIVE, "Passive", "On draw: 10% draw costs 0 mana"],
		[NodeType.CARD, "Card", "Unlocks a new card"],
		[NodeType.STAT_BONUS, "AGI +5", "Agility +5"],
		[NodeType.HEALTH, "HP +25", "Max Health +25"],
		[NodeType.PASSIVE, "Passive", "On cycle: 20% gain empower"],
		[NodeType.STAT_BONUS, "DET +5", "Determination +5"],
		[NodeType.CARD, "Card", "Unlocks a new card"],
		[NodeType.PASSIVE, "Passive", "On heal: overheal becomes armor"],
		[NodeType.MANA, "Mana +12", "Max Mana +12"],
		[NodeType.STAT_BONUS, "STR +6", "Strength +6"],
		[NodeType.CARD, "Card", "Unlocks a new card"],
		[NodeType.PASSIVE, "Passive", "On crit: heal 3 HP"],
		[NodeType.HEALTH, "HP +25", "Max Health +25"],
		[NodeType.STAT_BONUS, "DEX +6", "Dexterity +6"],
		[NodeType.CARD, "Card", "Unlocks a new card"],
		[NodeType.PASSIVE, "Passive", "On discard: deal 3 to random enemy"],
		[NodeType.MANA, "Mana +12", "Max Mana +12"],
		[NodeType.STAT_BONUS, "INT +6", "Intelligence +6"],
		[NodeType.CARD, "Card", "Unlocks a new card"],
		[NodeType.PASSIVE, "Passive", "On move: next card costs 1 less"],
		[NodeType.HEALTH, "HP +30", "Max Health +30"],
		[NodeType.STAT_BONUS, "WIS +6", "Wisdom +6"],
		[NodeType.CARD, "Card", "Unlocks a new card"],
		[NodeType.PASSIVE, "Passive", "On tempo cycle: draw 1 card"],
	]
	for entry in r5_labels:
		ring5_types.append(entry)

	_create_ring(61, 39, 340.0, center, ring5_types, 5)

	# Connect ring 5 to ring 4
	for i in range(24):
		var r5_base = int(i * 1.625)
		_connect_nodes(37 + i, 61 + (r5_base % 39))
		_connect_nodes(37 + i, 61 + ((r5_base + 1) % 39))
	# Connect ring 5 adjacent
	for i in range(39):
		_connect_nodes(61 + i, 61 + ((i + 1) % 39))

func _create_ring(start_id: int, count: int, radius: float, center: Vector2, type_data: Array, ring: int) -> void:
	for i in range(count):
		var angle = (TAU / count) * i - PI / 2  # Start from top
		var pos = center + Vector2(cos(angle), sin(angle)) * radius
		var data = type_data[i % type_data.size()]
		var node = GridNode.new(start_id + i, data[0], data[1], data[2], pos, ring)
		_add_node(node)
