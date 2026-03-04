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

	# Card nodes: which card this grants
	var card_id: String = ""        # e.g. "slash", "heal" — empty for non-card nodes

	# Upgrade paths (2 per node for card/passive nodes)
	# Each entry: { "label": String, "description": String }
	var upgrade_paths: Array = []

	# Transmute paths (2 per card/passive node)
	# Each entry: { "label": String, "description": String }
	var transmute_paths: Array = []

	# Upgrade level (0 = base, incremented by upgrade runes)
	var upgrade_level: int = 0

	func _init(p_id: int, p_type: NodeType, p_label: String, p_desc: String, p_pos: Vector2, p_ring: int = 0) -> void:
		id = p_id
		node_type = p_type
		label = p_label
		description = p_desc
		position = p_pos
		connections = []
		ring = p_ring

# ============================================
# CONSTELLATION SYSTEM
# ============================================

class Constellation:
	var id: String                    # Unique identifier
	var name: String                  # Display name
	var node_ids: Array[int]          # Required node IDs
	var bonus_name: String            # Short passive name
	var bonus_description: String     # Full description of the bonus
	var color: Color                  # Constellation color for lines/shading
	var completed: bool = false

	func _init(p_id: String, p_name: String, p_nodes: Array[int], p_bonus_name: String, p_bonus_desc: String, p_color: Color) -> void:
		id = p_id
		name = p_name
		node_ids = p_nodes
		bonus_name = p_bonus_name
		bonus_description = p_bonus_desc
		color = p_color

signal constellation_completed(constellation_id: String)

var constellations: Array[Constellation] = []
var _constellation_map: Dictionary = {}  # id -> Constellation

var nodes: Array = []  # Array of GridNode
var _node_map: Dictionary = {}  # id -> GridNode lookup

func _init() -> void:
	_build_grid()
	_assign_node_details()
	_build_constellations()

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

func _assign_node_details() -> void:
	## Assigns card IDs, upgrade paths, and transmute paths to card/passive nodes.
	## Called after the grid is fully built.

	# --- Card node assignments ---
	# Ring 3 card nodes: IDs 19, 22, 25, 28, 31, 34
	_assign_card(19, "life_steal", "Life Steal",
		[{"label": "Life Steal+", "description": "Steal 8 HP instead of 5"},
		 {"label": "Life Steal++", "description": "Steal 12 HP and gain 3 armor"}],
		[{"label": "Soul Drain", "description": "Drain 4 HP from all nearby enemies"},
		 {"label": "Blood Pact", "description": "Sacrifice 5 HP to deal 20 damage"}])

	_assign_card(22, "wear_down", "Wear Down",
		[{"label": "Wear Down+", "description": "Reduce enemy attack by 3 instead of 2"},
		 {"label": "Wear Down++", "description": "Reduce enemy attack by 4 for double duration"}],
		[{"label": "Cripple", "description": "Reduce enemy attack by 2 and slow by 50%"},
		 {"label": "Shatter Arms", "description": "Reduce enemy attack by 5 for 1 cycle"}])

	_assign_card(25, "surrounding_ice", "Surrounding Ice",
		[{"label": "Surrounding Ice+", "description": "Increased damage and range"},
		 {"label": "Surrounding Ice++", "description": "Also slows all hit enemies"}],
		[{"label": "Frost Nova", "description": "Freeze nearby enemies for 1 cycle"},
		 {"label": "Blizzard", "description": "AOE ice damage over 3 cycles"}])

	_assign_card(28, "empower", "Empower",
		[{"label": "Empower+", "description": "Empower 3 cards instead of 2"},
		 {"label": "Empower++", "description": "Empower 4 cards with +4 bonus"}],
		[{"label": "War Cry", "description": "Empower 2 cards and gain 5 armor"},
		 {"label": "Channel Power", "description": "Empower 1 card with +8 bonus damage"}])

	_assign_card(31, "preparation", "Preparation",
		[{"label": "Preparation+", "description": "Draw 3 cards instead of 2"},
		 {"label": "Preparation++", "description": "Draw 3 cards and reduce their cost by 1"}],
		[{"label": "Scheme", "description": "Draw 2 cards and peek at 2 more"},
		 {"label": "Mastermind", "description": "Draw 2 cards and gain 3 mana"}])

	_assign_card(34, "armor_break", "Armor Break",
		[{"label": "Armor Break+", "description": "Remove 8 armor instead of 5"},
		 {"label": "Armor Break++", "description": "Remove all armor and deal 5 damage"}],
		[{"label": "Sunder", "description": "Remove 5 armor and apply Exposed"},
		 {"label": "Demolish", "description": "Remove 10 armor from target"}])

	# Ring 4 card nodes: IDs 40, 44, 48, 52, 56, 60
	_assign_card(40, "charge", "Charge",
		[{"label": "Charge+", "description": "Charge deals 15 damage instead of 10"},
		 {"label": "Charge++", "description": "Charge deals 20 damage and stuns"}],
		[{"label": "Bull Rush", "description": "Charge through enemies, damaging all in path"},
		 {"label": "Blitz", "description": "Charge to enemy and gain 2 free tempo"}])

	_assign_card(44, "trick_shot", "Trick Shot",
		[{"label": "Trick Shot+", "description": "Bounces to 3 targets instead of 2"},
		 {"label": "Trick Shot++", "description": "Bounces to 4 targets with no damage falloff"}],
		[{"label": "Ricochet", "description": "Bounce 3 times, each hit gains +2 damage"},
		 {"label": "Piercing Shot", "description": "Hit all enemies in a line"}])

	_assign_card(48, "volatile_mixture", "Volatile Mixture",
		[{"label": "Volatile Mixture+", "description": "Increased damage and larger radius"},
		 {"label": "Volatile Mixture++", "description": "Also applies burn to hit enemies"}],
		[{"label": "Acid Flask", "description": "AOE that removes enemy armor over time"},
		 {"label": "Poison Cloud", "description": "AOE that deals damage over 3 cycles"}])

	_assign_card(52, "meditate", "Meditate",
		[{"label": "Meditate+", "description": "Restore 6 mana instead of 4"},
		 {"label": "Meditate++", "description": "Restore 8 mana and draw a card"}],
		[{"label": "Inner Peace", "description": "Restore 4 mana and cleanse 1 debuff"},
		 {"label": "Enlightenment", "description": "Restore 3 mana and reduce next card cost to 0"}])

	_assign_card(56, "heroic_leap", "Heroic Leap",
		[{"label": "Heroic Leap+", "description": "Leap further and deal 8 damage on land"},
		 {"label": "Heroic Leap++", "description": "Leap deals 12 AOE damage on land"}],
		[{"label": "Death From Above", "description": "Leap and deal damage based on distance"},
		 {"label": "Shockwave Land", "description": "Leap and stun all enemies at destination"}])

	_assign_card(60, "reposition", "Reposition",
		[{"label": "Reposition+", "description": "Move further and gain 3 armor"},
		 {"label": "Reposition++", "description": "Move further, gain 5 armor, draw a card"}],
		[{"label": "Tactical Retreat", "description": "Move away and gain 8 armor"},
		 {"label": "Flanking Strike", "description": "Move and deal 8 damage to adjacent enemy"}])

	# Ring 5 card nodes: IDs 61, 68, 73, 77, 82, 86, 90, 94, 98
	_assign_card(61, "last_breath", "Last Breath",
		[{"label": "Last Breath+", "description": "Increased damage multiplier at low HP"},
		 {"label": "Last Breath++", "description": "Massive damage at low HP, heal on kill"}],
		[{"label": "Death Wish", "description": "Deal damage equal to missing HP"},
		 {"label": "Undying Fury", "description": "At low HP: deal 30 damage and heal 10"}])

	_assign_card(68, "sky_fall", "Sky Fall",
		[{"label": "Sky Fall+", "description": "Larger impact radius"},
		 {"label": "Sky Fall++", "description": "Larger radius and leaves burning ground"}],
		[{"label": "Meteor", "description": "Massive single-target sky damage"},
		 {"label": "Rain of Fire", "description": "Multiple smaller impacts over area"}])

	_assign_card(73, "round_em_up", "Round Em Up",
		[{"label": "Round Em Up+", "description": "Pull enemies closer with more force"},
		 {"label": "Round Em Up++", "description": "Pull and stun all gathered enemies"}],
		[{"label": "Vortex", "description": "Pull enemies to a target point"},
		 {"label": "Graviton Surge", "description": "Pull and deal damage based on enemies caught"}])

	_assign_card(77, "shadows", "Shadows",
		[{"label": "Shadows+", "description": "Longer stealth duration"},
		 {"label": "Shadows++", "description": "Longer stealth and next attack from stealth crits"}],
		[{"label": "Vanish", "description": "Enter stealth and cleanse all debuffs"},
		 {"label": "Shadow Strike", "description": "Enter stealth, next attack deals double"}])

	_assign_card(82, "consecutive_snap", "Consecutive Snap",
		[{"label": "Consecutive Snap+", "description": "Each snap deals +2 more damage"},
		 {"label": "Consecutive Snap++", "description": "Each snap deals +3 more and costs 1 less"}],
		[{"label": "Rapid Fire", "description": "Fire 4 quick shots at random enemies"},
		 {"label": "Barrage", "description": "Each snap also hits adjacent enemies"}])

	_assign_card(86, "sweeping_disarm", "Sweeping Disarm",
		[{"label": "Sweeping Disarm+", "description": "Disarm lasts longer"},
		 {"label": "Sweeping Disarm++", "description": "Disarm all nearby enemies"}],
		[{"label": "Mass Disarm", "description": "Disarm all enemies for 1 cycle"},
		 {"label": "Weapon Break", "description": "Disarm target and reduce their damage permanently by 1"}])

	_assign_card(90, "elixir", "Elixir",
		[{"label": "Elixir+", "description": "Heal 15 HP instead of 10"},
		 {"label": "Elixir++", "description": "Heal 20 HP and gain 5 armor"}],
		[{"label": "Rejuvenation", "description": "Heal 8 HP over 3 cycles"},
		 {"label": "Phoenix Tears", "description": "Heal 10 HP, if this would kill you, heal to 1 instead"}])

	_assign_card(94, "mark", "Mark",
		[{"label": "Mark+", "description": "Marked enemy takes +4 bonus damage"},
		 {"label": "Mark++", "description": "Marked enemy takes +6 bonus damage from all sources"}],
		[{"label": "Death Mark", "description": "Mark: after 3 hits, deal 15 bonus damage"},
		 {"label": "Hunter's Mark", "description": "Mark: all ranged attacks gain +3 damage vs target"}])

	_assign_card(98, "defensive_awareness", "Defensive Awareness",
		[{"label": "Defensive Awareness+", "description": "Gain 8 armor instead of 5"},
		 {"label": "Defensive Awareness++", "description": "Gain 10 armor and reduce next damage taken by 50%"}],
		[{"label": "Iron Skin", "description": "Gain armor equal to 50% of max HP"},
		 {"label": "Fortress", "description": "Gain 5 armor and block all damage for 1 hit"}])

	# --- Passive node upgrade/transmute paths ---
	# Ring 2 passives
	_assign_passive(8, [
		{"label": "On kill: heal 2 HP", "description": "Upgraded healing on kill"},
		{"label": "On kill: heal 3 HP", "description": "Major healing on kill"}],
		[{"label": "On kill: gain 2 mana", "description": "Mana on kill instead of healing"},
		 {"label": "On kill: heal 1 HP and gain 1 armor", "description": "Hybrid defense on kill"}])

	_assign_passive(11, [
		{"label": "On card play: 8% draw extra", "description": "Increased draw chance"},
		{"label": "On card play: 12% draw extra", "description": "Major draw chance"}],
		[{"label": "On card play: 5% reduce next cost by 1", "description": "Chance for cost reduction"},
		 {"label": "On card play: 5% draw extra and gain 1 mana", "description": "Draw with mana bonus"}])

	_assign_passive(14, [
		{"label": "On move: gain 2 armor", "description": "More armor per move"},
		{"label": "On move: gain 3 armor", "description": "Major armor per move"}],
		[{"label": "On move: gain 2 life regen and 7 thorns", "description": "Regen and thorns on move"},
		 {"label": "On move: next card costs 1 less", "description": "Cost reduction on move"}])

	_assign_passive(17, [
		{"label": "On cycle: regen 2 mana", "description": "Improved mana regen"},
		{"label": "On cycle: regen 3 mana", "description": "Major mana regen"}],
		[{"label": "On cycle: regen 1 mana and heal 1 HP", "description": "Hybrid regen each cycle"},
		 {"label": "On cycle: regen 1 mana and draw a card", "description": "Mana regen with card draw"}])

	# Ring 3 passives
	_assign_passive(21, [
		{"label": "On attack: 15% apply bleed", "description": "Increased bleed chance"},
		{"label": "On attack: 20% apply bleed", "description": "Major bleed chance"}],
		[{"label": "On attack: 10% apply poison", "description": "Poison instead of bleed"},
		 {"label": "On attack: 10% apply bleed and slow", "description": "Bleed with slow"}])

	_assign_passive(24, [
		{"label": "On dodge: gain 3 tempo", "description": "More tempo on dodge"},
		{"label": "On dodge: gain 4 tempo", "description": "Major tempo on dodge"}],
		[{"label": "On dodge: counterattack for 5 damage", "description": "Counter on dodge"},
		 {"label": "On dodge: gain 3 tempo and 2 armor", "description": "Tempo and armor on dodge"}])

	_assign_passive(30, [
		{"label": "On heal: 20% cleanse debuff", "description": "Increased cleanse chance"},
		{"label": "On heal: 30% cleanse debuff", "description": "Major cleanse chance"}],
		[{"label": "On heal: 15% cleanse debuff and gain 2 armor", "description": "Cleanse with armor"},
		 {"label": "On heal: always cleanse weakest debuff", "description": "Guaranteed cleanse on heal"}])

	_assign_passive(36, [
		{"label": "On block: reflect 3 damage", "description": "Increased reflect"},
		{"label": "On block: reflect 5 damage", "description": "Major reflect"}],
		[{"label": "On block: reflect 2 and gain 1 armor", "description": "Reflect with armor gain"},
		 {"label": "On block: 30% stun attacker", "description": "Chance to stun on block"}])

	# Ring 4 passives
	_assign_passive(37, [
		{"label": "On crit: deal 75% bonus", "description": "Increased crit bonus"},
		{"label": "On crit: deal 100% bonus", "description": "Double damage on crit"}],
		[{"label": "On crit: deal 50% bonus and heal 2", "description": "Crit with lifesteal"},
		 {"label": "On crit: deal 50% bonus and gain 2 tempo", "description": "Crit with tempo"}])

	_assign_passive(41, [
		{"label": "On kill: draw 2 cards", "description": "Draw more on kill"},
		{"label": "On kill: draw 2 cards and gain 1 mana", "description": "Major on-kill draw"}],
		[{"label": "On kill: draw 1 card and reduce its cost by 1", "description": "Discounted draw on kill"},
		 {"label": "On kill: draw 1 card and gain 3 armor", "description": "Draw with armor on kill"}])

	_assign_passive(45, [
		{"label": "On spell cast: 15% refund mana", "description": "Increased refund chance"},
		{"label": "On spell cast: 20% refund mana", "description": "Major refund chance"}],
		[{"label": "On spell cast: 10% refund mana and deal 3 bonus damage", "description": "Refund with bonus damage"},
		 {"label": "On spell cast: 10% cast twice", "description": "Chance to double cast"}])

	_assign_passive(49, [
		{"label": "On tempo cycle: all enemies -2 armor", "description": "Increased armor shred"},
		{"label": "On tempo cycle: all enemies -3 armor", "description": "Major armor shred"}],
		[{"label": "On tempo cycle: all enemies -1 armor and take 1 damage", "description": "Shred with damage"},
		 {"label": "On tempo cycle: nearest enemy -5 armor", "description": "Focused armor shred"}])

	_assign_passive(53, [
		{"label": "On discard: 30% return to hand", "description": "Increased return chance"},
		{"label": "On discard: 40% return to hand", "description": "Major return chance"}],
		[{"label": "On discard: 20% return and gain 1 mana", "description": "Return with mana"},
		 {"label": "On discard: deal 3 damage to random enemy", "description": "Damage on discard"}])

	_assign_passive(57, [
		{"label": "On move: 15% gain haste", "description": "Increased haste chance"},
		{"label": "On move: 20% gain haste", "description": "Major haste chance"}],
		[{"label": "On move: 10% gain haste and 3 armor", "description": "Haste with armor"},
		 {"label": "On move: 10% gain haste and draw a card", "description": "Haste with draw"}])

	# Ring 5 passives: IDs 62, 65, 69, 72, 76, 80, 83, 87, 91, 95, 99
	_assign_passive(62, [
		{"label": "On attack: 8% stun enemy", "description": "Increased stun chance"},
		{"label": "On attack: 12% stun enemy", "description": "Major stun chance"}],
		[{"label": "On attack: 5% stun and deal 3 bonus damage", "description": "Stun with bonus damage"},
		 {"label": "On attack: 5% freeze enemy for 1 cycle", "description": "Chance to freeze instead of stun"}])

	_assign_passive(65, [
		{"label": "On kill: gain 5 armor", "description": "More armor on kill"},
		{"label": "On kill: gain 7 armor", "description": "Major armor on kill"}],
		[{"label": "On kill: gain 3 armor and heal 2", "description": "Hybrid on kill defense"},
		 {"label": "On kill: gain 3 armor and 2 tempo", "description": "Armor and tempo on kill"}])

	_assign_passive(69, [
		{"label": "On block: 20% counterattack", "description": "Increased counter chance"},
		{"label": "On block: 25% counterattack", "description": "Major counter chance"}],
		[{"label": "On block: 15% counterattack for double damage", "description": "Powerful counter"},
		 {"label": "On block: 15% counterattack and gain 2 armor", "description": "Counter with armor"}])

	_assign_passive(72, [
		{"label": "On spell cast: 8% double cast", "description": "Increased double cast chance"},
		{"label": "On spell cast: 12% double cast", "description": "Major double cast chance"}],
		[{"label": "On spell cast: 5% double cast and refund mana", "description": "Double cast with refund"},
		 {"label": "On spell cast: 5% triple cast", "description": "Chance to triple cast"}])

	_assign_passive(76, [
		{"label": "On draw: 15% draw costs 0 mana", "description": "Increased free draw chance"},
		{"label": "On draw: 20% draw costs 0 mana", "description": "Major free draw chance"}],
		[{"label": "On draw: 10% draw costs 0 and draw an extra card", "description": "Free draw with bonus"},
		 {"label": "On draw: 10% draw costs 0 and gain 2 armor", "description": "Free draw with armor"}])

	_assign_passive(80, [
		{"label": "On cycle: 30% gain empower", "description": "Increased empower chance"},
		{"label": "On cycle: 40% gain empower", "description": "Major empower chance"}],
		[{"label": "On cycle: 20% gain empower and draw a card", "description": "Empower with draw"},
		 {"label": "On cycle: 20% gain double empower", "description": "Chance for double empower"}])

	_assign_passive(83, [
		{"label": "On heal: overheal becomes 150% armor", "description": "Better overheal conversion"},
		{"label": "On heal: overheal becomes 200% armor", "description": "Major overheal conversion"}],
		[{"label": "On heal: overheal becomes armor and gain 1 mana", "description": "Overheal with mana"},
		 {"label": "On heal: overheal becomes armor, excess armor deals damage", "description": "Offensive overheal"}])

	_assign_passive(87, [
		{"label": "On crit: heal 5 HP", "description": "Increased crit healing"},
		{"label": "On crit: heal 7 HP", "description": "Major crit healing"}],
		[{"label": "On crit: heal 3 HP and gain 2 mana", "description": "Crit healing with mana"},
		 {"label": "On crit: heal 3 HP and gain 3 armor", "description": "Crit healing with armor"}])

	_assign_passive(91, [
		{"label": "On discard: deal 5 to random enemy", "description": "Increased discard damage"},
		{"label": "On discard: deal 7 to random enemy", "description": "Major discard damage"}],
		[{"label": "On discard: deal 3 to all enemies", "description": "AOE discard damage"},
		 {"label": "On discard: deal 3 to random enemy and gain 1 mana", "description": "Discard damage with mana"}])

	_assign_passive(95, [
		{"label": "On move: next card costs 2 less", "description": "Bigger cost reduction on move"},
		{"label": "On move: next card costs 3 less", "description": "Major cost reduction on move"}],
		[{"label": "On move: next card costs 1 less and deals +3 damage", "description": "Move to empower"},
		 {"label": "On move: next card is free", "description": "Free next card on move"}])

	_assign_passive(99, [
		{"label": "On tempo cycle: draw 2 cards", "description": "Draw more per cycle"},
		{"label": "On tempo cycle: draw 2 cards and gain 1 mana", "description": "Major cycle draw"}],
		[{"label": "On tempo cycle: draw 1 card and gain 2 mana", "description": "Balanced cycle reward"},
		 {"label": "On tempo cycle: draw 1 card and gain 3 armor", "description": "Defensive cycle"}])

# ============================================
# CONSTELLATION DEFINITIONS
# ============================================

func _build_constellations() -> void:
	constellations.clear()
	_constellation_map.clear()

	# --- PAIR 1: STR Sector — Iron Will vs Blood Hunter ---
	# Shared nodes: 1 (STR+1), 8 (On kill: heal)
	# Iron Will goes toward HP/Life Steal; Blood Hunter toward Bleed/Wear Down
	_add_constellation(Constellation.new(
		"iron_will", "Iron Will",
		[1, 7, 8, 19, 20] as Array[int],
		"Iron Will",
		"On kill: gain 3 armor and heal 2 HP",
		Color(0.9, 0.45, 0.25)  # warm red-orange
	))
	_add_constellation(Constellation.new(
		"blood_hunter", "Blood Hunter",
		[1, 8, 9, 21, 22] as Array[int],
		"Blood Hunter",
		"Attacks have +15% chance to apply bleed. Bleed deals +2 per tick",
		Color(0.75, 0.15, 0.15)  # dark crimson
	))

	# --- PAIR 2: INT Sector — Arcane Current vs Mind Weaver ---
	# Shared nodes: 3 (INT+1), 11 (On card play: draw)
	# Arcane Current goes toward raw spell power; Mind Weaver toward card economy
	_add_constellation(Constellation.new(
		"arcane_current", "Arcane Current",
		[3, 11, 12, 25, 26] as Array[int],
		"Arcane Current",
		"Spell cards deal +5 bonus damage",
		Color(0.5, 0.2, 0.85)  # deep purple
	))
	_add_constellation(Constellation.new(
		"mind_weaver", "Mind Weaver",
		[3, 10, 11, 23, 24] as Array[int],
		"Mind Weaver",
		"On spell cast: 20% chance to draw a card. +3 max mana",
		Color(0.7, 0.5, 0.95)  # lavender
	))

	# --- PAIR 3: AGI Sector — Windwalker vs Storm Runner ---
	# Shared nodes: 5 (AGI+1), 16 (Mana+3), 32 (AGI+3)
	# Windwalker goes toward card draw/prep; Storm Runner toward mana sustain
	# Storm Runner also shares node 17 with Unyielding — creating a 3-way conflict
	_add_constellation(Constellation.new(
		"windwalker", "Windwalker",
		[5, 15, 16, 31, 32] as Array[int],
		"Windwalker",
		"+1 movement per cycle. First card played after moving costs 1 less",
		Color(0.3, 0.85, 0.4)  # light green
	))
	_add_constellation(Constellation.new(
		"storm_runner", "Storm Runner",
		[5, 16, 17, 32, 33] as Array[int],
		"Storm Runner",
		"+1 movement per cycle. Gain 2 mana on each move",
		Color(0.2, 0.55, 0.95)  # electric blue
	))

	# --- STANDALONE: WIS Sector — Sage's Insight ---
	_add_constellation(Constellation.new(
		"sages_insight", "Sage's Insight",
		[4, 13, 14, 28, 29] as Array[int],
		"Sage's Insight",
		"Draw 1 extra card per tempo cycle",
		Color(0.2, 0.75, 0.65)  # teal
	))

	# --- STANDALONE: DET Sector — Unyielding ---
	# Shares node 17 with Storm Runner
	_add_constellation(Constellation.new(
		"unyielding", "Unyielding",
		[6, 17, 18, 35, 36] as Array[int],
		"Unyielding",
		"Below 50% HP: gain 3 armor each cycle. Determination scaling +20%",
		Color(0.85, 0.7, 0.2)  # dark gold
	))

func _add_constellation(c: Constellation) -> void:
	constellations.append(c)
	_constellation_map[c.id] = c

func get_constellation(id: String) -> Constellation:
	return _constellation_map.get(id, null)

func get_all_constellations() -> Array[Constellation]:
	return constellations

func is_constellation_complete(id: String) -> bool:
	var c = get_constellation(id)
	if not c:
		return false
	for node_id in c.node_ids:
		var node = get_node_by_id(node_id)
		if not node or not node.unlocked:
			return false
	return true

func check_constellation_completion() -> Array[String]:
	## Checks all constellations and returns IDs of any newly completed ones.
	var newly_completed: Array[String] = []
	for c in constellations:
		if c.completed:
			continue
		if is_constellation_complete(c.id):
			c.completed = true
			newly_completed.append(c.id)
			constellation_completed.emit(c.id)
			print("[SPHERE GRID] Constellation completed: %s — %s" % [c.name, c.bonus_description])
	return newly_completed

func get_constellations_for_node(node_id: int) -> Array[Constellation]:
	## Returns all constellations that include this node.
	var result: Array[Constellation] = []
	for c in constellations:
		if node_id in c.node_ids:
			result.append(c)
	return result

func get_constellation_progress(id: String) -> Dictionary:
	## Returns { "unlocked": int, "total": int, "node_ids": Array, "unlocked_ids": Array }
	var c = get_constellation(id)
	if not c:
		return { "unlocked": 0, "total": 0, "node_ids": [], "unlocked_ids": [] }
	var unlocked_ids: Array[int] = []
	for node_id in c.node_ids:
		var node = get_node_by_id(node_id)
		if node and node.unlocked:
			unlocked_ids.append(node_id)
	return { "unlocked": unlocked_ids.size(), "total": c.node_ids.size(), "node_ids": c.node_ids, "unlocked_ids": unlocked_ids }

func get_constellation_edges(id: String) -> Array:
	## Returns all grid edges [node_a_id, node_b_id] between nodes in this constellation.
	var c = get_constellation(id)
	if not c:
		return []
	var edges: Array = []
	var node_set = {}
	for nid in c.node_ids:
		node_set[nid] = true
	for nid in c.node_ids:
		var node = get_node_by_id(nid)
		if not node:
			continue
		for conn_id in node.connections:
			if conn_id in node_set and conn_id > nid:
				edges.append([nid, conn_id])
	return edges

func _assign_card(node_id: int, p_card_id: String, card_label: String, upgrades: Array, transmutes: Array) -> void:
	var node = get_node_by_id(node_id)
	if not node:
		return
	node.card_id = p_card_id
	node.label = card_label
	node.upgrade_paths = upgrades
	node.transmute_paths = transmutes

func _assign_passive(node_id: int, upgrades: Array, transmutes: Array) -> void:
	var node = get_node_by_id(node_id)
	if not node or node.node_type != NodeType.PASSIVE:
		return
	node.upgrade_paths = upgrades
	node.transmute_paths = transmutes
