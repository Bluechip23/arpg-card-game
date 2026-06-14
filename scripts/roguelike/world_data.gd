class_name WorldData
extends Resource

## A "world" is the persistent meta-container for the roguelike end-game.
##
## Each story-mode playthrough builds ONE world. Everything unlocked in that
## world (relics, vendors, events, node upgrades, etc.) is SHARED by every
## character that belongs to the world. The only things that are NOT shared and
## instead live on the character are:
##   - which cards the character has access to in a run
##   - which monsters the character has defeated in story mode (the bestiary,
##     used later to gate monster-intent reveals)
##
## For the first roguelike slice this is mostly a scaffold held in memory; disk
## persistence and the story-mode hooks that populate these pools come later.

@export var world_id: String = ""
@export var world_name: String = "New World"
@export var created_timestamp: String = ""

# ---- Shared unlock pools (grow as the player progresses story mode) ----
@export var unlocked_relic_ids: Array[String] = []
@export var unlocked_vendor_ids: Array[String] = []
@export var unlocked_event_ids: Array[String] = []
# Node types available in the run beyond the always-present base five.
@export var unlocked_node_type_ids: Array[String] = []
# Per-node-type upgrades, e.g. {"campfire": ["forge", "double_rest"]}.
@export var node_upgrades: Dictionary = {}

# ---- Run history (shared, informational) ----
@export var runs_started: int = 0
@export var runs_completed: int = 0
@export var deepest_floor_reached: int = 0

static func make_new(name: String) -> WorldData:
	var w := WorldData.new()
	w.world_name = name
	w.world_id = "%d_%d" % [Time.get_unix_time_from_system(), randi() % 100000]
	w.created_timestamp = Time.get_datetime_string_from_system()
	return w

func has_node_upgrade(node_type: String, upgrade_id: String) -> bool:
	var ups = node_upgrades.get(node_type, [])
	return ups.has(upgrade_id)

# ----------------------------------------------------------------------------
# Persistence (the shared world meta is stored on each character's save)
# ----------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"world_id": world_id,
		"world_name": world_name,
		"created": created_timestamp,
		"relics": unlocked_relic_ids.duplicate(),
		"vendors": unlocked_vendor_ids.duplicate(),
		"events": unlocked_event_ids.duplicate(),
		"node_types": unlocked_node_type_ids.duplicate(),
		"node_upgrades": node_upgrades.duplicate(true),
		"runs_started": runs_started,
		"runs_completed": runs_completed,
		"deepest_floor_reached": deepest_floor_reached,
	}

static func from_dict(data: Dictionary) -> WorldData:
	var w := WorldData.new()
	if data == null or data.is_empty():
		return w
	w.world_id = str(data.get("world_id", ""))
	w.world_name = str(data.get("world_name", "New World"))
	w.created_timestamp = str(data.get("created", ""))
	# Typed string arrays must be rebuilt element-by-element from the loaded
	# (untyped) arrays.
	for s in data.get("relics", []):
		w.unlocked_relic_ids.append(str(s))
	for s in data.get("vendors", []):
		w.unlocked_vendor_ids.append(str(s))
	for s in data.get("events", []):
		w.unlocked_event_ids.append(str(s))
	for s in data.get("node_types", []):
		w.unlocked_node_type_ids.append(str(s))
	var ups: Dictionary = data.get("node_upgrades", {})
	for key in ups.keys():
		var ids: Array = []
		for v in ups[key]:
			ids.append(str(v))
		w.node_upgrades[str(key)] = ids
	w.runs_started = int(data.get("runs_started", 0))
	w.runs_completed = int(data.get("runs_completed", 0))
	w.deepest_floor_reached = int(data.get("deepest_floor_reached", 0))
	return w
