extends SceneTree

## The town-building end-game was removed (designer, 2026-11-07). A save made
## before that still loads: its SaveData `city` field, the progression's
## city / satchel / trial keys and an accepted Trial Warning quest are
## dropped without an error, and the Town Hall stands as scenery that nothing
## offers to interact with.
## Run: godot --headless --path . --script tests/test_retired_city_saves.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	print("=== Retired city saves ===")
	# A save written the way the old game wrote it: SaveData with a `city`
	# export, and the city keys inside the progression snapshot.
	var path := "user://test_retired_city_save.tres"
	var sd := SaveData.new()
	sd.character_name = "Old Timer"
	sd.character_data = CharacterData.create_brad()
	sd.progression = {
		"city": {"resources": {"gold": 120, "lumber": 40}, "buildings": {"town_hall": 2}},
		"city_satchel": {"lumber": 7, "stone": 3},
		"city_calamity": {"kills_left": 4},
		"quest_state": {"accepted_ids": ["trial_warning", "olorin_kill_wererats"],
			"completed_ids": [], "progress": {"trial_warning": [0]}, "flags": {"garrison_veteran": true}},
	}
	_check(ResourceSaver.save(sd, path) == OK, "the test save is written")
	var txt := FileAccess.get_file_as_string(path)
	txt = txt.replace("[resource]\n", "[resource]\ncity = {\n\"resources\": {\n\"gold\": 120\n}\n}\n")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(txt)
	f.close()
	_check(txt.contains("city = {"), "…carrying the old SaveData `city` field")

	var loaded = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(loaded is SaveData, "the old save still loads as SaveData")
	if loaded is SaveData:
		_check(not ("city" in loaded), "the city field is gone from SaveData")
		var live := ProgressionIO.to_live(loaded.progression)
		for k in ProgressionIO.RETIRED_CITY_KEYS:
			_check(not live.has(k) and not loaded.progression.has(k), "the old '%s' key is dropped on load" % k)
		var qm := QuestManager.new()
		qm._ready()   # registers the quest catalogue
		qm.load_state(loaded.progression.get("quest_state", {}))
		_check(qm.get_quest("trial_warning") == null, "an accepted Trial Warning in the save is skipped")
		_check(qm.get_quest("olorin_kill_wererats") != null, "the save's other quests still load")
		qm.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	# The town comes up, and its Town Hall is scenery only.
	var town = load("res://scenes/menus/town.tscn").instantiate()
	town.starting_character = CharacterData.create_brad()
	get_root().add_child(town)
	for _i in range(6):
		await process_frame
	var hall: Node = town.get_node_or_null("TownHall")
	_check(hall != null, "the Town Hall still stands in town")
	_check(hall != null and hall.get_parent() == town, "…outside the interactable Vendors group")
	_check(not town.vendor_info.has("TownHall"), "…with nothing to open")
	_check(hall != null and hall.find_children("*", "Label3D", true, false).is_empty(), "…and no floating name")
	town.queue_free()
	await process_frame
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
