class_name SphereInventory
extends Node

## Tracks the player's collection of sphere orbs used to unlock nodes on the sphere grid.
## There is a single, universal sphere type — every node costs the same sphere.

signal spheres_changed

enum SphereType {
	SPHERE,     # Universal sphere — unlocks any grid node type
}

# Inventory: count of each sphere type the player currently holds
var spheres: Dictionary = {
	SphereType.SPHERE: 0,
}

# Retrospective tokens (from sphere grid, lets player reclaim a skipped skill tree option)
var retrospective_tokens: int = 0

# ============================================
# SPHERE MANAGEMENT
# ============================================

func add_sphere(type: SphereType, amount: int = 1) -> void:
	spheres[type] = spheres.get(type, 0) + amount
	print("[SPHERES] Gained %d sphere(s). Total: %d" % [amount, spheres[type]])
	spheres_changed.emit()

func remove_sphere(type: SphereType, amount: int = 1) -> bool:
	if spheres.get(type, 0) < amount:
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

func has_sphere_for_node(_node_type: SphereGrid.NodeType) -> bool:
	## Every unlockable node costs the same universal sphere.
	return spheres.get(SphereType.SPHERE, 0) > 0

func spend_sphere_for_node(_node_type: SphereGrid.NodeType) -> bool:
	## Spends one universal sphere, regardless of node type.
	return remove_sphere(SphereType.SPHERE)

func load_spheres(data: Dictionary) -> void:
	## Restores saved sphere counts into the unified pool. Any legacy multi-type
	## save (Stat/Passive/Any/Swap) is merged into the single sphere count so no
	## spheres are lost when migrating an older save.
	var total := 0
	for v in data.values():
		if v is int or v is float:
			total += int(v)
	spheres = { SphereType.SPHERE: total }
	spheres_changed.emit()

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
	## Every node costs one universal sphere. Returns -1 for START, which is
	## already unlocked and cannot be bought with a sphere.
	if node_type == SphereGrid.NodeType.START:
		return -1
	return SphereType.SPHERE

static func get_sphere_name(_type: SphereType) -> String:
	return "Sphere"

static func get_sphere_color(_type: SphereType) -> Color:
	return Color(0.6, 0.75, 1.0)

# ============================================
# LEVEL-UP REWARDS TABLE
# ============================================

static func get_level_rewards(_level: int) -> Array:
	## Returns array of [SphereType, count] pairs for the given level.
	## Every level (including the level-1 starting grant) awards 2 universal
	## spheres, matching the old economy of 2 spheres per level.
	return [[SphereType.SPHERE, 2]]
