class_name SaveData
extends Resource

## Holds all persistent data for a saved character

@export var character_name: String = ""
@export var character_level: int = 1
@export var current_location: String = "Town"
@export var time_played_seconds: float = 0.0
@export var sprite_path: String = ""
# World/story progress this character has reached. Used for display and (later)
# to gate the roguelike to characters that have started the story.
@export var world_level: int = 1

# Full character data for loading back into the game
@export var character_data: CharacterData = null

# Snapshot of equipped items (item names for display)
@export var equipped_item_names: Array[String] = []

# Snapshot of deck card IDs (for display)
@export var deck_card_ids: Array[String] = []

# Disk-safe progression snapshot (see ProgressionIO). Holds level/stats, deck,
# sphere inventory + unlocked nodes, quest state, waypoints and opened chests.
@export var progression: Dictionary = {}

# Save metadata
@export var save_slot: int = 0
@export var save_timestamp: String = ""

func get_time_played_string() -> String:
	var total_seconds = int(time_played_seconds)
	var hours = total_seconds / 3600
	var minutes = (total_seconds % 3600) / 60
	var seconds = total_seconds % 60
	if hours > 0:
		return "%dh %dm %ds" % [hours, minutes, seconds]
	elif minutes > 0:
		return "%dm %ds" % [minutes, seconds]
	else:
		return "%ds" % seconds
