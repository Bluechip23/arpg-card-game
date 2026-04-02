class_name SphereInventory
extends Node

## Tracks the player's collection of sphere orbs used to unlock nodes on the sphere grid.
## Sphere types determine which grid node types they can unlock.

signal spheres_changed

enum SphereType {
	STAT,       # Can unlock STAT_BONUS, HEALTH, MANA, COMBAT_BONUS nodes
	PASSIVE,    # Can unlock PASSIVE nodes
	ANY,        # Can unlock any node type
	SWAP,       # Special: swap one unlocked node for another of the same type (rare)
}

# Inventory: count of each sphere type the player currently holds
var spheres: Dictionary = {
	SphereType.STAT: 0,
	SphereType.PASSIVE: 0,
	SphereType.ANY: 0,
	SphereType.SWAP: 0,
}

# Retrospective tokens (from sphere grid, lets player reclaim a skipped skill tree option)
var retrospective_tokens: int = 0

# ============================================
# SPHERE MANAGEMENT
# ============================================

func add_sphere(type: SphereType, amount: int = 1) -> void:
	spheres[type] += amount
	print("[SPHERES] Gained %d %s sphere(s). Total: %d" % [amount, get_sphere_name(type), spheres[type]])
	spheres_changed.emit()

func remove_sphere(type: SphereType, amount: int = 1) -> bool:
	if spheres[type] < amount:
		return false
	spheres[type] -= amount
	spheres_changed.emit()
	return true

func get_count(type: SphereType) -> int:
	return spheres.get(type, 0)

func get_total_spheres() -> int:
	var total = 0
	for count in spheres.values():
		total += count
	return total

func has_sphere_for_node(node_type: SphereGrid.NodeType) -> bool:
	## Returns true if the player has a sphere that can unlock this node type.
	if spheres[SphereType.ANY] > 0:
		return true
	var required = get_required_sphere_type(node_type)
	if required == -1:
		return false
	return spheres[required] > 0

func spend_sphere_for_node(node_type: SphereGrid.NodeType) -> bool:
	## Spends the appropriate sphere. Prefers typed spheres over ANY.
	var required = get_required_sphere_type(node_type)
	if required != -1 and spheres[required] > 0:
		return remove_sphere(required)
	if spheres[SphereType.ANY] > 0:
		return remove_sphere(SphereType.ANY)
	return false

# ============================================
# RETROSPECTIVE TOKENS
# ============================================

func add_retrospective_token(amount: int = 1) -> void:
	retrospective_tokens += amount
	print("[SPHERES] Gained %d retrospective token(s). Total: %d" % [amount, retrospective_tokens])
	spheres_changed.emit()

func spend_retrospective_token() -> bool:
	if retrospective_tokens <= 0:
		return false
	retrospective_tokens -= 1
	spheres_changed.emit()
	return true

func has_retrospective_token() -> bool:
	return retrospective_tokens > 0

# ============================================
# TYPE MAPPING
# ============================================

static func get_required_sphere_type(node_type: SphereGrid.NodeType) -> int:
	## Returns the SphereType required to unlock a given grid node type.
	## Returns -1 for START (cannot be unlocked with a sphere).
	match node_type:
		SphereGrid.NodeType.STAT_BONUS, SphereGrid.NodeType.HEALTH, SphereGrid.NodeType.MANA, SphereGrid.NodeType.CULLING_STONE, SphereGrid.NodeType.COMBAT_BONUS, SphereGrid.NodeType.FEATHER:
			return SphereType.STAT
		SphereGrid.NodeType.PASSIVE:
			return SphereType.PASSIVE
		SphereGrid.NodeType.RETROSPECTIVE:
			return SphereType.ANY
		SphereGrid.NodeType.START:
			return -1  # Already unlocked
	return -1

static func get_sphere_name(type: SphereType) -> String:
	match type:
		SphereType.STAT: return "Stat"
		SphereType.PASSIVE: return "Passive"
		SphereType.ANY: return "Any"
		SphereType.SWAP: return "Swap"
	return "Unknown"

static func get_sphere_color(type: SphereType) -> Color:
	match type:
		SphereType.STAT: return Color(0.4, 0.6, 1.0)
		SphereType.PASSIVE: return Color(0.9, 0.5, 0.2)
		SphereType.ANY: return Color(1.0, 1.0, 0.6)
		SphereType.SWAP: return Color(0.2, 0.9, 0.9)
	return Color.WHITE

# ============================================
# LEVEL-UP REWARDS TABLE
# ============================================

static func get_level_rewards(level: int) -> Array:
	## Returns array of [SphereType, count] pairs for the given level.
	## Level 1 (starting): 2 stat
	## Level 2: 1 stat, 1 passive
	## Level 3: 2 stat
	## Then repeating: even levels = 1 stat + 1 passive, odd levels = 2 stat
	match level:
		1: return [[SphereType.STAT, 2]]
		2: return [[SphereType.STAT, 1], [SphereType.PASSIVE, 1]]
		3: return [[SphereType.STAT, 2]]
		_:
			if level % 2 == 0:
				return [[SphereType.STAT, 1], [SphereType.PASSIVE, 1]]
			else:
				return [[SphereType.STAT, 2]]
