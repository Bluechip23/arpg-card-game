class_name RoguelikeRun
extends RefCounted

## Holds the live state of a single roguelike run: the map, where the player
## currently is, run resources (HP, gold), and a FROZEN snapshot of the world's
## meta-progression taken at the moment the run began.
##
## A character may only have one run in progress at a time (it is persisted on
## their save and resumed on re-entry). The run reads what's available from its
## meta_snapshot, never from the live world — anything the player unlocks during
## the run accrues to the world (persistent) but does not help this run. They
## must start a NEW run to play with the newly unlocked meta-progression.

var character: CharacterData = null
var world: WorldData = null
var map: RoguelikeMap = null
var seed_value: int = 0

## id of the last node the player resolved. -1 means the run has just started
## and the player has not entered any node yet.
var current_node_id: int = -1

var max_hp: int = 50
var hp: int = 50
var gold: int = 0
var floor_reached: int = 0
var finished: bool = false
var victorious: bool = false

## Things picked up during the run (acquired card ids added to the deck for
## later battles, potions held, relics carried this run).
var deck_cards: Array[String] = []
var potions: Array[String] = []
var relics: Array[String] = []

## Frozen copy of the world's meta-progression unlock pools at run start.
var meta_snapshot: Dictionary = {}

func start(char_data: CharacterData, world_data: WorldData, seed_val: int = -1) -> void:
	character = char_data
	world = world_data
	if seed_val < 0:
		seed_val = int(Time.get_unix_time_from_system()) ^ (randi() & 0xFFFFFF)
	seed_value = seed_val

	map = RoguelikeMap.new()
	map.generate(seed_value)

	current_node_id = -1
	floor_reached = 0
	finished = false
	victorious = false

	# Derive a roguelike HP pool from the character's base health. Base health
	# is intentionally small in this game, so scale it into a run-sized pool.
	max_hp = maxi(30, char_data.base_health * 4 + 20) if char_data else 50
	hp = max_hp
	gold = 0

	# Freeze the world's meta-progression for the whole run.
	meta_snapshot = _snapshot_world_meta(world)

	if world:
		world.runs_started += 1

func _snapshot_world_meta(world_data: WorldData) -> Dictionary:
	if not world_data:
		return {}
	return {
		"relics": world_data.unlocked_relic_ids.duplicate(),
		"vendors": world_data.unlocked_vendor_ids.duplicate(),
		"events": world_data.unlocked_event_ids.duplicate(),
		"node_types": world_data.unlocked_node_type_ids.duplicate(),
		"node_upgrades": world_data.node_upgrades.duplicate(true),
	}

func is_active() -> bool:
	return not finished

## Record a meta-progression unlock earned DURING the run. It is written to the
## live world (so a future run can use it) but deliberately NOT added to this
## run's frozen meta_snapshot.
func record_meta_unlock(category: String, id: String) -> void:
	if not world:
		return
	match category:
		"relic":
			if not world.unlocked_relic_ids.has(id):
				world.unlocked_relic_ids.append(id)
		"vendor":
			if not world.unlocked_vendor_ids.has(id):
				world.unlocked_vendor_ids.append(id)
		"event":
			if not world.unlocked_event_ids.has(id):
				world.unlocked_event_ids.append(id)
		"node_type":
			if not world.unlocked_node_type_ids.has(id):
				world.unlocked_node_type_ids.append(id)

## Node upgrades active for THIS run (read from the frozen snapshot, so mid-run
## unlocks do not appear here).
func active_node_upgrades(node_type_id: String) -> Array:
	var ups: Dictionary = meta_snapshot.get("node_upgrades", {})
	return ups.get(node_type_id, [])

func has_node_upgrade(node_type_id: String, upgrade_id: String) -> bool:
	return active_node_upgrades(node_type_id).has(upgrade_id)

## Unlock a node upgrade DURING a run. It is written to the live world (and so
## persisted for future runs) but deliberately not added to this run's frozen
## snapshot — the current run cannot benefit from it.
func unlock_node_upgrade(node_type_id: String, upgrade_id: String) -> void:
	if not world:
		return
	var arr: Array = world.node_upgrades.get(node_type_id, [])
	if not arr.has(upgrade_id):
		arr.append(upgrade_id)
		world.node_upgrades[node_type_id] = arr

## Node ids the player may move to right now.
func available_node_ids() -> Array[int]:
	if not map:
		return []
	if current_node_id == -1:
		return map.first_row_ids()
	var node := map.get_node(current_node_id)
	if node:
		return node.next_ids
	return []

func can_visit(id: int) -> bool:
	return available_node_ids().has(id)

## Commit a node as resolved and advance the player onto it.
func resolve_node(id: int) -> void:
	if not map:
		return
	var node := map.get_node(id)
	if not node:
		return
	node.visited = true
	current_node_id = id
	floor_reached = maxi(floor_reached, node.row + 1)
	if world:
		world.deepest_floor_reached = maxi(world.deepest_floor_reached, floor_reached)
	if node.type == RoguelikeMapNode.Type.BOSS:
		finished = true
		victorious = true
		if world:
			world.runs_completed += 1

func current_node() -> RoguelikeMapNode:
	if map and current_node_id != -1:
		return map.get_node(current_node_id)
	return null

func heal(amount: int) -> void:
	hp = clampi(hp + amount, 0, max_hp)

func damage(amount: int) -> void:
	hp = clampi(hp - amount, 0, max_hp)
	if hp <= 0:
		finished = true
		victorious = false

func add_gold(amount: int) -> void:
	gold = maxi(0, gold + amount)

# ----------------------------------------------------------------------------
# Persistence (so a character's single in-progress run survives and resumes)
# ----------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"seed": seed_value,
		"map": map.to_dict() if map else {},
		"current_node_id": current_node_id,
		"max_hp": max_hp,
		"hp": hp,
		"gold": gold,
		"floor_reached": floor_reached,
		"finished": finished,
		"victorious": victorious,
		"deck_cards": deck_cards.duplicate(),
		"potions": potions.duplicate(),
		"relics": relics.duplicate(),
		"meta_snapshot": meta_snapshot,
	}

## Rebuild a run from a saved dict. character/world are supplied by the caller
## (they live elsewhere); the map and run state come from the dict.
static func from_dict(data: Dictionary, char_data: CharacterData, world_data: WorldData) -> RoguelikeRun:
	var run := RoguelikeRun.new()
	run.character = char_data
	run.world = world_data
	run.seed_value = int(data.get("seed", 0))
	run.map = RoguelikeMap.from_dict(data.get("map", {}))
	run.current_node_id = int(data.get("current_node_id", -1))
	run.max_hp = int(data.get("max_hp", 50))
	run.hp = int(data.get("hp", run.max_hp))
	run.gold = int(data.get("gold", 0))
	run.floor_reached = int(data.get("floor_reached", 0))
	run.finished = bool(data.get("finished", false))
	run.victorious = bool(data.get("victorious", false))
	for c in data.get("deck_cards", []):
		run.deck_cards.append(str(c))
	for p in data.get("potions", []):
		run.potions.append(str(p))
	for r in data.get("relics", []):
		run.relics.append(str(r))
	run.meta_snapshot = data.get("meta_snapshot", {})
	return run
