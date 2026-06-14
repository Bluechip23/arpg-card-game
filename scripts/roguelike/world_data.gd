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
