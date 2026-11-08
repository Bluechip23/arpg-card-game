class_name SaveManager
extends RefCounted

## Handles saving and loading character data to disk

const SAVE_DIR = "user://saves/"
const MAX_SAVE_SLOTS = 6          # manual slots 0..5
const AUTOSAVE_SLOT = 6           # written every time the character arrives in town

## The manual slot the character in play was loaded from or last saved to
## (-1: none yet — a new character, or one loaded from the autosave). The
## in-game menu's "save before you quit" writes here without asking.
static var current_slot: int = -1

static func has_current_slot() -> bool:
	return current_slot >= 0 and current_slot < MAX_SAVE_SLOTS

static func ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

static func get_save_path(slot: int) -> String:
	return SAVE_DIR + "save_slot_%d.tres" % slot

## Checked on disk: ResourceLoader.exists also answers from its cache, so a
## deleted save would still look present.
static func save_exists(slot: int) -> bool:
	return FileAccess.file_exists(get_save_path(slot))

static func save_game(slot: int, save_data: SaveData) -> bool:
	ensure_save_dir()
	save_data.save_slot = slot
	save_data.save_timestamp = Time.get_datetime_string_from_system()
	var err = ResourceSaver.save(save_data, get_save_path(slot))
	if err != OK:
		push_error("[SAVE] Failed to save slot %d: %s" % [slot, error_string(err)])
		return false
	print("[SAVE] Saved slot %d: %s" % [slot, save_data.character_name])
	if slot < MAX_SAVE_SLOTS:
		current_slot = slot
	return true

static func load_game(slot: int) -> SaveData:
	var path = get_save_path(slot)
	if not FileAccess.file_exists(path):
		return null
	var data = ResourceLoader.load(path)
	if data is SaveData:
		return data
	push_error("[SAVE] Invalid save data in slot %d" % slot)
	return null

## Delete a save from disk (designer, 2026-11-08: the load screen asks for a
## 4-second hold and then an "are you sure" before calling this). A slot the
## character in play came from is forgotten too, so "save before you quit"
## never writes back into a deleted slot.
static func delete_save(slot: int) -> bool:
	var path := get_save_path(slot)
	if not FileAccess.file_exists(path):
		return false
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("[SAVE] Failed to delete slot %d: %s" % [slot, error_string(err)])
		return false
	if current_slot == slot:
		current_slot = -1
	print("[SAVE] Deleted slot %d" % slot)
	return true

static func is_autosave(slot: int) -> bool:
	return slot == AUTOSAVE_SLOT

static func get_all_saves() -> Array[SaveData]:
	## Manual slots first, the autosave last (index AUTOSAVE_SLOT).
	var saves: Array[SaveData] = []
	for i in range(MAX_SAVE_SLOTS + 1):
		var save = load_game(i)
		if save:
			saves.append(save)
		else:
			saves.append(null)
	return saves
