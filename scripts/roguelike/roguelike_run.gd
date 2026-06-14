class_name RoguelikeRun
extends RefCounted

## Holds the live state of a single roguelike run: the map, where the player
## currently is, and run resources (HP, gold). Kept in memory for the first
## slice — nothing here is written to disk yet.

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

	if world:
		world.runs_started += 1

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
