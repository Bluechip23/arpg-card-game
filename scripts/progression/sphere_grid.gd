class_name SphereGrid
extends Resource

## Data model for the sphere grid leveling system.
## Contains 139 nodes arranged in concentric rings (plus the outer
## amplification arc) with connections for pathing.

enum NodeType {
	STAT_BONUS,    # Flat stat increase (STR, DEX, INT, WIS, AGI, DET)
	PASSIVE,       # Triggered passive (everytime you do X, Y happens)
	HEALTH,        # Max health increase
	MANA,          # Max mana increase
	START,         # Starting node (already unlocked)
	CULLING_STONE, # Grants a culling stone to remove a card from deck
	RETROSPECTIVE, # Grants ability to pick from a previously skipped skill tree option
	COMBAT_BONUS,  # Neutral combat stat boost (Block, Thorns, Damage, Heal Power, Crit, Armor, etc.)
	FEATHER,       # Grants a feather to remove a card from deck (alternative to culling stone)
	NULL_NODE,     # Pure connective tissue: no effect, smaller, a sunk cost on the path
	KEYSTONE,      # Build-defining synergy node (keystone_id selects the mechanic)
	FREE_STAT      # Banks unspent stat points the player allocates freely (like a level-up)
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

	# Stat gate: {"stat": "wisdom", "value": 24} — the node cannot be unlocked
	# until the character's BASE stat reaches the value.
	var requirements: Dictionary = {}
	# For KEYSTONE nodes: which build-defining mechanic this node enables.
	var keystone_id: String = ""

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
signal constellation_replaced(old_constellation_id: String, new_constellation_id: String)

var constellations: Array[Constellation] = []
var _constellation_map: Dictionary = {}  # id -> Constellation

var nodes: Array = []  # Array of GridNode
var _node_map: Dictionary = {}  # id -> GridNode lookup

func _init() -> void:
	_build_grid()
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

# A character can attach only this many keystones — the build-defining choice.
const MAX_KEYSTONES: int = 3

func unlocked_keystone_count() -> int:
	var count = 0
	for node in nodes:
		if node.node_type == NodeType.KEYSTONE and node.unlocked:
			count += 1
	return count

func keystone_slots_free() -> bool:
	return unlocked_keystone_count() < MAX_KEYSTONES

func unlock_node(id: int) -> bool:
	if not is_unlockable(id):
		return false
	var node = get_node_by_id(id)
	if node.node_type == NodeType.KEYSTONE and not keystone_slots_free():
		return false
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

	# === Ring 1: 6 nodes at radius 90 (pushed out from 70) ===
	var ring1_types = [
		[NodeType.STAT_BONUS, "STR +1", "Strength +1"],
		[NodeType.STAT_BONUS, "DEX +1", "Dexterity +1"],
		[NodeType.STAT_BONUS, "INT +1", "Intelligence +1"],
		[NodeType.STAT_BONUS, "WIS +1", "Wisdom +1"],
		[NodeType.STAT_BONUS, "AGI +1", "Agility +1"],
		[NodeType.STAT_BONUS, "DET +1", "Determination +1"],
	]
	_create_ring(1, 6, 90.0, center, ring1_types, 1)

	# Connect ring 1 to center
	for i in range(6):
		_connect_nodes(0, 1 + i)
	# Connect ring 1 nodes to each other (hexagon)
	for i in range(6):
		_connect_nodes(1 + i, 1 + ((i + 1) % 6))

	# === Ring 2: 12 nodes at radius 170 (pushed out from 140) ===
	# Each Ring 1 stat branches into two Ring 2 nodes: the SAME stat again, then a
	# vitality node that reinforces that stat's playstyle — HP for the martial
	# stats (STR, DEX, DET) and Mana for the caster stats (WIS, INT, AGI).
	# Node order matches the Ring 1 -> Ring 2 connection mapping below
	# (ring1 node 1+i connects to ring2 nodes 7+i*2 and 7+i*2+1):
	#   STR -> 7,8 | DEX -> 9,10 | INT -> 11,12 | WIS -> 13,14 | AGI -> 15,16 | DET -> 17,18
	var ring2_types = [
		[NodeType.STAT_BONUS, "STR +1", "Strength +1"],   # STR branch
		[NodeType.HEALTH, "HP +10", "Max Health +10"],    # STR branch -> HP
		[NodeType.STAT_BONUS, "DEX +1", "Dexterity +1"],  # DEX branch
		[NodeType.HEALTH, "HP +10", "Max Health +10"],    # DEX branch -> HP
		[NodeType.STAT_BONUS, "INT +1", "Intelligence +1"], # INT branch
		[NodeType.MANA, "Mana +5", "Max Mana +5"],        # INT branch -> Mana
		[NodeType.STAT_BONUS, "WIS +1", "Wisdom +1"],     # WIS branch
		[NodeType.MANA, "Mana +5", "Max Mana +5"],        # WIS branch -> Mana
		[NodeType.STAT_BONUS, "AGI +1", "Agility +1"],    # AGI branch
		[NodeType.MANA, "Mana +5", "Max Mana +5"],        # AGI branch -> Mana
		[NodeType.STAT_BONUS, "DET +1", "Determination +1"], # DET branch
		[NodeType.HEALTH, "HP +10", "Max Health +10"],    # DET branch -> HP
	]
	_create_ring(7, 12, 170.0, center, ring2_types, 2)

	# Connect ring 2 to ring 1 (each ring1 node connects to 2 ring2 nodes)
	for i in range(6):
		_connect_nodes(1 + i, 7 + i * 2)
		_connect_nodes(1 + i, 7 + i * 2 + 1)
	# Connect ring 2 adjacent nodes
	for i in range(12):
		_connect_nodes(7 + i, 7 + ((i + 1) % 12))

	# === Ring 3: 12 nodes at radius 260 — each stat arm continues outward ===
	# Every Ring 2 arm (stat node + HP/Mana node) fans into two Ring 3 nodes that
	# sit directly outside their Ring 2 parents (same 12 angular slots as Ring 2):
	#   * outside each STAT node -> a FREE_STAT "+3 Stats" node (points banked to
	#     the player's pool, allocated freely on the stat screen)
	#   * outside each HP/Mana node -> a bigger vitality node (HP +12 / Mana +7)
	# The stat node also links across to its arm's vitality node, and the vitality
	# type always matches the stat (HP for STR/DEX/DET, Mana for INT/WIS/AGI), so a
	# DET arm reads DET -> {+3 Stats, HP} exactly as requested.
	# Order mirrors Ring 2 (ids 7..18): STR-stat, STR-hp, DEX-stat, DEX-hp,
	# INT-stat, INT-mana, WIS-stat, WIS-mana, AGI-stat, AGI-mana, DET-stat, DET-hp.
	var ring3_types = [
		[NodeType.FREE_STAT, "+3 Stats", "Bank 3 stat points to spend however you like"], # outside 7  (STR)
		[NodeType.HEALTH, "HP +12", "Max Health +12"],                                     # outside 8  (STR HP)
		[NodeType.FREE_STAT, "+3 Stats", "Bank 3 stat points to spend however you like"], # outside 9  (DEX)
		[NodeType.HEALTH, "HP +12", "Max Health +12"],                                     # outside 10 (DEX HP)
		[NodeType.FREE_STAT, "+3 Stats", "Bank 3 stat points to spend however you like"], # outside 11 (INT)
		[NodeType.MANA, "Mana +7", "Max Mana +7"],                                         # outside 12 (INT Mana)
		[NodeType.FREE_STAT, "+3 Stats", "Bank 3 stat points to spend however you like"], # outside 13 (WIS)
		[NodeType.MANA, "Mana +7", "Max Mana +7"],                                         # outside 14 (WIS Mana)
		[NodeType.FREE_STAT, "+3 Stats", "Bank 3 stat points to spend however you like"], # outside 15 (AGI)
		[NodeType.MANA, "Mana +7", "Max Mana +7"],                                         # outside 16 (AGI Mana)
		[NodeType.FREE_STAT, "+3 Stats", "Bank 3 stat points to spend however you like"], # outside 17 (DET)
		[NodeType.HEALTH, "HP +12", "Max Health +12"],                                     # outside 18 (DET HP)
	]
	_create_ring(19, 12, 260.0, center, ring3_types, 3)

	# === Ids 31–36: placeholder NULL nodes between Rings 3 and 4 ===
	# The old 18-node Ring 3 owned these ids and several constellations still
	# require them (Windwalker, Storm Runner, Unyielding, Shadow Strike, Iron
	# Bastion). Until the grid + constellation balancing pass lands, they live
	# as bare connective nodes at radius 305 so those constellations are
	# completable again. Each links its nearest Ring 3 arm and Ring 4 node.
	for k in range(6):
		var angle = (TAU / 6.0) * k - PI / 2
		var pos = center + Vector2(cos(angle), sin(angle)) * 305.0
		var null_node = GridNode.new(31 + k, NodeType.NULL_NODE, "·",
			"A bare link in the web. It offers nothing but the path onward.", pos, 3)
		_add_node(null_node)
		_connect_nodes(31 + k, 19 + k * 2)   # nearest Ring 3 arm node
		_connect_nodes(31 + k, 37 + k * 4)   # nearest Ring 4 node

	# Wire each arm's diamond. Ring 2 stat nodes sit at even offsets (ids 7,9,..17),
	# their HP/Mana partner at the following odd offset. The matching Ring 3 nodes
	# share the same offset (ids 19..30):
	#   stat -> its FREE_STAT node   (radially outward)
	#   stat -> its vitality node    (the "similar" option — HP or Mana)
	#   vitality(ring2) -> vitality(ring3)
	for j in range(0, 12, 2):
		var stat_r2 := 7 + j
		var vital_r2 := 7 + j + 1
		var free_r3 := 19 + j
		var vital_r3 := 19 + j + 1
		_connect_nodes(stat_r2, free_r3)
		_connect_nodes(stat_r2, vital_r3)
		_connect_nodes(vital_r2, vital_r3)

	# === Ring 4: 24 nodes at radius 280 ===
	var ring4_types = [
		[NodeType.PASSIVE, "Passive", "On crit: deal 50% bonus"],
		[NodeType.HEALTH, "HP +10", "Max Health +10"],
		[NodeType.STAT_BONUS, "STR +3", "Strength +3"],
		[NodeType.COMBAT_BONUS, "Block +1", "Block cards grant +1 additional block"],
		[NodeType.PASSIVE, "Passive", "On kill: draw 1 card"],
		[NodeType.COMBAT_BONUS, "Life Steal +1%", "Heal for 1% of damage dealt"],
		[NodeType.STAT_BONUS, "DEX +3", "Dexterity +3"],
		[NodeType.COMBAT_BONUS, "Thorns +1", "Deal 1 damage to attackers when hit"],
		[NodeType.RETROSPECTIVE, "Retrospect", "Reclaim a skipped skill tree reward"],
		[NodeType.COMBAT_BONUS, "Regen +1", "Regenerate 1 HP per tempo cycle"],
		[NodeType.STAT_BONUS, "INT +3", "Intelligence +3"],
		[NodeType.COMBAT_BONUS, "Damage +1", "All attacks deal +1 bonus damage"],
		[NodeType.PASSIVE, "Passive", "On tempo cycle: all enemies -1 armor"],
		[NodeType.COMBAT_BONUS, "Resist +1%", "Reduce all incoming damage by 1%"],
		[NodeType.STAT_BONUS, "WIS +3", "Wisdom +3"],
		[NodeType.COMBAT_BONUS, "Heal +1", "Heal cards restore +1 additional HP"],
		[NodeType.CULLING_STONE, "Cull Stone", "Grants 1 Culling Stone"],
		[NodeType.COMBAT_BONUS, "Arm/Cyc +1", "Gain 1 armor each tempo cycle"],
		[NodeType.STAT_BONUS, "AGI +3", "Agility +3"],
		[NodeType.COMBAT_BONUS, "Crit +1%", "Critical hit chance +1%"],
		[NodeType.PASSIVE, "Passive", "On move: 10% gain haste"],
		[NodeType.NULL_NODE, "·", "A bare link in the web. It offers nothing but the path onward."],
		[NodeType.STAT_BONUS, "DET +3", "Determination +3"],
		[NodeType.NULL_NODE, "·", "A bare link in the web. It offers nothing but the path onward."],
	]
	_create_ring(37, 24, 350.0, center, ring4_types, 4)

	# Connect ring 4 to ring 3. Ring 3 now has 12 nodes (radial arms), Ring 4 has
	# 24, so each Ring 3 node feeds the two Ring 4 nodes nearest it by angle. This
	# keeps every Ring 4 node (and the keystones beyond) reachable from an arm.
	for i in range(24):
		_connect_nodes(37 + i, 19 + (int(i / 2) % 12))
	# Connect ring 4 adjacent
	for i in range(24):
		_connect_nodes(37 + i, 37 + ((i + 1) % 24))

	# === Ring 5 (outer): 39 nodes at radius 340 ===
	# IDs 61..99 (39 nodes)
	var ring5_types: Array = []
	var r5_labels = [
		[NodeType.COMBAT_BONUS, "Block +1", "Block cards grant +1 additional block"],
		[NodeType.PASSIVE, "Passive", "On attack: 5% stun enemy"],
		[NodeType.STAT_BONUS, "STR +3", "Strength +3"],
		[NodeType.HEALTH, "HP +20", "Max Health +20"],
		[NodeType.PASSIVE, "Passive", "On kill: gain 3 armor"],
		[NodeType.STAT_BONUS, "DEX +3", "Dexterity +3"],
		[NodeType.FEATHER, "Feather", "Grants 1 Feather to remove a card from your deck"],
		[NodeType.COMBAT_BONUS, "Thorns +1", "Deal 1 damage to attackers when hit"],
		[NodeType.CULLING_STONE, "Cull Stone", "Grants 1 Culling Stone"],
		[NodeType.STAT_BONUS, "INT +3", "Intelligence +3"],
		[NodeType.HEALTH, "HP +20", "Max Health +20"],
		[NodeType.COMBAT_BONUS, "Vuln Amp +25%", "Vulnerable you apply amplifies damage by an extra 25% (30% base)"],
		[NodeType.COMBAT_BONUS, "Damage +1", "All attacks deal +1 bonus damage"],
		[NodeType.STAT_BONUS, "WIS +3", "Wisdom +3"],
		[NodeType.COMBAT_BONUS, "Life Steal +1%", "Heal for 1% of damage dealt"],
		[NodeType.COMBAT_BONUS, "Weaken Amp +25%", "Weaken you apply saps an extra 25% of enemy damage (30% base)"],
		[NodeType.COMBAT_BONUS, "Heal +1", "Heal cards restore +1 additional HP"],
		# Flash Reserves (AGI flash → draw) retired: card-drawing is Wisdom's
		# domain now (brain points). Node kept as a connector; refill with a
		# body-flavored AGI keystone later.
		[NodeType.NULL_NODE, "·", "A bare link in the web. It offers nothing but the path onward."],
		[NodeType.RETROSPECTIVE, "Retrospect", "Reclaim a skipped skill tree reward"],
		[NodeType.PASSIVE, "Passive", "On cycle: 20% gain empower"],
		[NodeType.STAT_BONUS, "DET +3", "Determination +3"],
		[NodeType.COMBAT_BONUS, "Crit +1%", "Critical hit chance +1%", {"req": {"stat": "dexterity", "value": 20}}],
		[NodeType.PASSIVE, "Passive", "On heal: overheal becomes armor"],
		[NodeType.COMBAT_BONUS, "Range +1", "Ranged attacks gain +1 range"],
		[NodeType.KEYSTONE, "Bulwark Soul", "Keystone: gain +2 max health per point of Determination — past and future.", {"req": {"stat": "determination", "value": 12}, "keystone": "det_vitality"}],
		[NodeType.COMBAT_BONUS, "Armor +1", "Start each combat with +1 armor"],
		[NodeType.PASSIVE, "Passive", "On crit: heal 3 HP"],
		[NodeType.HEALTH, "HP +25", "Max Health +25"],
		[NodeType.KEYSTONE, "Deadeye Form", "Keystone: ranged attacks scale with Dexterity instead of Strength.", {"req": {"stat": "dexterity", "value": 15}, "keystone": "dex_ranged"}],
		[NodeType.COMBAT_BONUS, "Block +1", "Block cards grant +1 additional block"],
		[NodeType.CULLING_STONE, "Cull Stone", "Grants 1 Culling Stone"],
		[NodeType.COMBAT_BONUS, "Resist +1%", "Reduce all incoming damage by 1%"],
		[NodeType.STAT_BONUS, "INT +3", "Intelligence +3"],
		[NodeType.COMBAT_BONUS, "Arm/Cyc +1", "Gain 1 armor each tempo cycle"],
		[NodeType.PASSIVE, "Passive", "On move: next card costs 1 less"],
		[NodeType.HEALTH, "HP +30", "Max Health +30"],
		[NodeType.STAT_BONUS, "WIS +3", "Wisdom +3"],
		[NodeType.COMBAT_BONUS, "Regen +1", "Regenerate 1 HP per tempo cycle"],
		[NodeType.PASSIVE, "Passive", "On tempo cycle: draw 1 card"],
	]
	for entry in r5_labels:
		ring5_types.append(entry)

	_create_ring(61, 39, 440.0, center, ring5_types, 5)

	# Connect ring 5 to ring 4
	for i in range(24):
		var r5_base = int(i * 1.625)
		_connect_nodes(37 + i, 61 + (r5_base % 39))
		_connect_nodes(37 + i, 61 + ((r5_base + 1) % 39))
	# Connect ring 5 adjacent
	for i in range(39):
		_connect_nodes(61 + i, 61 + ((i + 1) % 39))

	# === Ring 6 (outermost): 30 nodes at radius 540 ===
	# IDs 100..129 — high-tier nodes with advanced bonuses
	var ring6_types: Array = [
		[NodeType.COMBAT_BONUS, "Crit +1%", "Critical hit chance +1%"],
		[NodeType.COMBAT_BONUS, "Vuln Amp +25%", "Vulnerable you apply amplifies damage by an extra 25% (stacks with other Vuln Amp nodes)"],
		[NodeType.STAT_BONUS, "STR +5", "Strength +5"],
		[NodeType.KEYSTONE, "Weighted Strikes", "Keystone: your basic attack gains a heavy weapon's weight-to-damage bonus even wielded one-handed (+1 damage per 10 weapon weight).", {"req": {"stat": "strength", "value": 15}, "keystone": "str_weight_basic"}],
		[NodeType.KEYSTONE, "Balanced Load", "Keystone: pick an equipment slot — its items weigh 10% less, stacking with any other weight reduction on that slot.", {"req": {"stat": "strength", "value": 15}, "keystone": "str_light_slot"}],
		[NodeType.STAT_BONUS, "DEX +5", "Dexterity +5"],
		[NodeType.KEYSTONE, "Flurry Form", "Keystone: your Dexterity attack proc now strikes TWICE, but every attack deals 2 less damage — a faster, lighter flurry.", {"req": {"stat": "dexterity", "value": 18}, "keystone": "dex_twin_strike"}],
		[NodeType.KEYSTONE, "Arcane Ward", "Keystone: every time your mana regenerates, gain armor equal to half your Intelligence.", {"req": {"stat": "intelligence", "value": 15}, "keystone": "int_regen_armor"}],
		[NodeType.PASSIVE, "Passive", "On kill: draw 2 cards and gain 2 mana"],
		[NodeType.STAT_BONUS, "INT +5", "Intelligence +5"],
		[NodeType.KEYSTONE, "Arcane Echo", "Keystone: each spell you cast has an INT/3% chance to deal INT/2 bonus damage to a random enemy.", {"req": {"stat": "intelligence", "value": 15}, "keystone": "int_spell_proc"}],
		[NodeType.PASSIVE, "Passive", "On spell cast: 10% refund full mana cost"],
		[NodeType.KEYSTONE, "Quick Study", "Keystone: whenever your hand empties, immediately draw 1 card — without disturbing the countdown to your next timed draw.", {"req": {"stat": "wisdom", "value": 15}, "keystone": "wis_empty_draw"}],
		[NodeType.STAT_BONUS, "WIS +5", "Wisdom +5"],
		[NodeType.KEYSTONE, "Tactician's Eye", "Keystone: gain +2% critical hit chance for every card currently in your hand.", {"req": {"stat": "wisdom", "value": 15}, "keystone": "wis_hand_crit"}],
		[NodeType.PASSIVE, "Passive", "On block: heal 3 HP"],
		[NodeType.COMBAT_BONUS, "Heal +1", "Heal cards restore +1 additional HP"],
		[NodeType.STAT_BONUS, "AGI +5", "Agility +5"],
		[NodeType.KEYSTONE, "Flash Cut", "Keystone: the Sidestep action becomes an attack — spend 3 Flash points to strike the nearest enemy for 1 damage instead of gaining block.", {"req": {"stat": "agility", "value": 15}, "keystone": "flash_strike"}],
		[NodeType.PASSIVE, "Passive", "On move: gain 2 armor and 1 mana"],
		[NodeType.STAT_BONUS, "DET +5", "Determination +5"],
		[NodeType.COMBAT_BONUS, "Block +1", "Block cards grant +1 additional block"],
		[NodeType.PASSIVE, "Passive", "On tempo cycle: all enemies take 2 damage"],
		[NodeType.HEALTH, "HP +35", "Max Health +35"],
		[NodeType.COMBAT_BONUS, "Thorns +1", "Deal 1 damage to attackers when hit"],
		[NodeType.FEATHER, "Feather", "Grants 1 Feather to remove a card from your deck"],
		[NodeType.MANA, "Mana +15", "Max Mana +15"],
		[NodeType.KEYSTONE, "Killing Rhythm", "Keystone: give up the Dexterity tempo/mana proc — instead, each time it would trigger, your next attack deals bonus damage equal to half your Dexterity.", {"req": {"stat": "dexterity", "value": 18}, "keystone": "dex_flat_damage"}],
		[NodeType.KEYSTONE, "Unbroken Will", "Keystone: Determination can no longer gut your stats — its penalty floor rises from 10% to 50%, so low health never drops a stat below half its base.", {"req": {"stat": "determination", "value": 15}, "keystone": "det_floor"}],
		[NodeType.KEYSTONE, "Wild Abandon", "Keystone: Determination's effect per point is amplified 50% — bigger stat swings, up AND down, as your health rises and falls.", {"req": {"stat": "determination", "value": 15}, "keystone": "det_amplify"}],
		# --- Conversion keystones (ids 130-133). Ungated for now; final placement
		# and any stat gates come with the null-node / layout pass. ---
		[NodeType.KEYSTONE, "Sanguine Barrier", "Keystone: life steal no longer heals — stolen life becomes temporary HP instead.", {"keystone": "lifesteal_temp_hp"}],
		[NodeType.KEYSTONE, "Living Bulwark", "Keystone: armor you would gain becomes temporary HP instead.", {"keystone": "armor_temp_hp"}],
		[NodeType.KEYSTONE, "Arcane Blood", "Keystone: damage is split evenly between health and mana. If mana runs dry, health takes the rest — and death still comes only at 0 HP.", {"keystone": "mana_blood"}],
		[NodeType.KEYSTONE, "Willspring", "Keystone: Determination now answers to your mana instead of your health — your stats swing as mana drains, not HP.", {"keystone": "det_mana"}],
	]

	_create_ring(100, 34, 540.0, center, ring6_types, 6)

	# Connect ring 6 to ring 5
	for i in range(39):
		var r6_base = int(i * 0.871)  # 34/39 ≈ 0.871
		_connect_nodes(61 + i, 100 + (r6_base % 34))
		_connect_nodes(61 + i, 100 + ((r6_base + 1) % 34))
	# Connect ring 6 adjacent
	for i in range(34):
		_connect_nodes(100 + i, 100 + ((i + 1) % 34))

	# === Amplification arc: 5 buff-amp nodes at radius 620 (ids 134-138) ===
	# Playstyle amplification for the buffs YOU gain — the self-buff twin of
	# the Vuln/Weaken debuff-amp nodes. Each hangs off its two nearest Ring 6
	# nodes by angle.
	var amp_types := [
		[NodeType.COMBAT_BONUS, "Haste Amp +1", "Haste you gain lasts 1 extra movement"],
		[NodeType.COMBAT_BONUS, "Enlight Amp +10%", "Enlightened you gain grants +10% more crit chance (20% total)"],
		[NodeType.COMBAT_BONUS, "Brace Amp +10%", "Brace you gain blocks 10 more percentage points of damage"],
		[NodeType.COMBAT_BONUS, "Blessed Draw +1", "Blessed you gain draws 1 extra card per cycle"],
		[NodeType.COMBAT_BONUS, "Blessed Amp +1", "Blessed you gain lasts 1 extra cycle"],
	]
	for k in range(amp_types.size()):
		var amp_angle = (TAU / amp_types.size()) * k - PI / 2
		var amp_pos = center + Vector2(cos(amp_angle), sin(amp_angle)) * 620.0
		var a = amp_types[k]
		var amp_node = GridNode.new(134 + k, a[0], a[1], a[2], amp_pos, 7)
		_add_node(amp_node)
		var nearest := int(round(float(k) * 34.0 / float(amp_types.size()))) % 34
		_connect_nodes(134 + k, 100 + nearest)
		_connect_nodes(134 + k, 100 + ((nearest + 1) % 34))

## SHELVED CONTENT — the original Ring 3 (combat bonuses, on-hit/on-heal/on-block
## passives, a Culling Stone, a Retrospective) that the FREE_STAT / vitality arm
## layer replaced. Kept here (not wired into the grid) so it can be resurfaced
## later — e.g. folded into an outer ring or a future sector.
func _shelved_ring3_nodes() -> Array:
	return [
		{ "type": NodeType.COMBAT_BONUS, "label": "Block +1", "desc": "Block cards grant +1 additional block" },
		{ "type": NodeType.STAT_BONUS, "label": "STR +1", "desc": "Strength +1" },
		{ "type": NodeType.PASSIVE, "label": "Passive", "desc": "On attack: 10% apply bleed" },
		{ "type": NodeType.COMBAT_BONUS, "label": "Thorns +1", "desc": "Deal 1 damage to attackers when hit" },
		{ "type": NodeType.STAT_BONUS, "label": "DEX +1", "desc": "Dexterity +1" },
		{ "type": NodeType.CULLING_STONE, "label": "Cull Stone", "desc": "Grants 1 Culling Stone" },
		{ "type": NodeType.COMBAT_BONUS, "label": "Damage +1", "desc": "All attacks deal +1 bonus damage" },
		{ "type": NodeType.STAT_BONUS, "label": "INT +1", "desc": "Intelligence +1" },
		{ "type": NodeType.RETROSPECTIVE, "label": "Retrospect", "desc": "Reclaim a skipped skill tree reward" },
		{ "type": NodeType.COMBAT_BONUS, "label": "Heal +1", "desc": "Heal cards restore +1 additional HP" },
		{ "type": NodeType.STAT_BONUS, "label": "WIS +1", "desc": "Wisdom +1" },
		{ "type": NodeType.PASSIVE, "label": "Passive", "desc": "On heal: 15% cleanse debuff" },
		{ "type": NodeType.COMBAT_BONUS, "label": "Crit +1%", "desc": "Critical hit chance +1%" },
		{ "type": NodeType.STAT_BONUS, "label": "AGI +1", "desc": "Agility +1" },
		{ "type": NodeType.COMBAT_BONUS, "label": "Regen +1", "desc": "Regenerate 1 HP per tempo cycle" },
		{ "type": NodeType.COMBAT_BONUS, "label": "Crit +1%", "desc": "Critical hit chance +1%" },
		{ "type": NodeType.STAT_BONUS, "label": "DET +1", "desc": "Determination +1" },
		{ "type": NodeType.PASSIVE, "label": "Passive", "desc": "On block: reflect 2 damage" },
	]

func _create_ring(start_id: int, count: int, radius: float, center: Vector2, type_data: Array, ring: int) -> void:
	for i in range(count):
		var angle = (TAU / count) * i - PI / 2  # Start from top
		var pos = center + Vector2(cos(angle), sin(angle)) * radius
		var data = type_data[i % type_data.size()]
		var node = GridNode.new(start_id + i, data[0], data[1], data[2], pos, ring)
		# Optional 4th entry: {"req": {...}, "keystone": "..."} extras.
		if data.size() > 3 and data[3] is Dictionary:
			node.requirements = data[3].get("req", {})
			node.keystone_id = data[3].get("keystone", "")
		_add_node(node)

## True when the character's base stats satisfy a node's stat gate.
static func requirements_met(node: GridNode, stats) -> bool:
	if node.requirements.is_empty() or stats == null:
		return true
	var stat_name: String = node.requirements.get("stat", "")
	if stat_name != "":
		var current: int = stats.determination if stat_name == "determination" \
			else int(stats.get("base_" + stat_name))
		if current < int(node.requirements.get("value", 0)):
			return false
	return true

## Human-readable requirement line for tooltips ("" when ungated).
static func requirement_text(node: GridNode) -> String:
	var stat_name: String = node.requirements.get("stat", "")
	if stat_name == "":
		return ""
	return "Requires %s %d" % [stat_name.substr(0, 3).to_upper(), int(node.requirements.get("value", 0))]

func _build_constellations() -> void:
	constellations.clear()
	_constellation_map.clear()

	# --- PAIR 1: STR Sector — Iron Will vs Blood Hunter ---
	# Shared nodes: 1 (STR+1), 8 (STR-branch HP)
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
	# Shared nodes: 3 (INT+1), 11 (INT+1)
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
	# Shared nodes: 5 (AGI+1), 16 (Mana+3), 32 (placeholder null node for now)
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

	# ============================================
	# RING 3-4 CONSTELLATIONS (conflict with inner constellations)
	# ============================================

	# --- Crimson Edge vs Iron Will (shares node 20) and Blood Hunter (shares node 21) ---
	# Offensive sustain build using Ring 3-4 STR sector
	_add_constellation(Constellation.new(
		"crimson_edge", "Crimson Edge",
		[20, 21, 38, 39, 40] as Array[int],
		"Crimson Edge",
		"Attacks heal for 8% of damage dealt",
		Color(0.85, 0.2, 0.25)  # blood red
	))

	# --- Shadow Strike vs Windwalker (shares nodes 31, 32) and Storm Runner (shares 32) ---
	# Crit mastery build using Ring 3-4 AGI/crit sector
	_add_constellation(Constellation.new(
		"shadow_strike", "Shadow Strike",
		[31, 32, 54, 55, 56] as Array[int],
		"Shadow Strike",
		"Critical hits deal 2x damage instead of 1.5x",
		Color(0.35, 0.15, 0.55)  # dark violet
	))

	# --- Iron Bastion vs Iron Will (shares 19) and Unyielding (shares 36) ---
	# Defensive tank build using Ring 3-4 edges
	_add_constellation(Constellation.new(
		"iron_bastion", "Iron Bastion",
		[19, 36, 37, 59, 60] as Array[int],
		"Iron Bastion",
		"+5 armor at start of combat. When hit: 15% chance to reduce damage by 50%",
		Color(0.45, 0.55, 0.7)  # steel blue
	))

	# --- Nature's Grace vs Sage's Insight (shares 28, 29) ---
	# Healing/regen build using Ring 3-4 WIS sector
	_add_constellation(Constellation.new(
		"natures_grace", "Nature's Grace",
		[28, 29, 30, 51, 52] as Array[int],
		"Nature's Grace",
		"Regenerate 2 HP each tempo cycle. Heal cards restore +5 additional HP",
		Color(0.25, 0.75, 0.3)  # forest green
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
