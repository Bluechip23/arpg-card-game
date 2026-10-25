extends SceneTree

## The questionnaire's "Play as …" button: the quiz-built character opens on
## Choose Your Character's Play-as confirmation (no error, no missing mode
## select), skips the 8-point stat allocation the presets get (its answers
## already shaped its stats), and Proceed takes it into town.
## Run: godot --headless --path . --script tests/test_questionnaire_play_as.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _find(type_name: String) -> Node:
	for child in get_root().get_children():
		if child.get_script() and child.get_script().get_global_name() == type_name:
			if not child.is_queued_for_deletion():
				return child
	return null

func _find_town() -> Node:
	for child in get_root().get_children():
		if child.scene_file_path == "res://scenes/menus/town.tscn":
			return child
	return null

func _run() -> void:
	print("=== Questionnaire: Play as … ===")
	var quiz = load("res://scenes/character/character_questionnaire.tscn").instantiate()
	get_root().add_child(quiz)
	await process_frame
	# Answer every question with its first choice, then reach the result.
	for i in range(quiz._answers.size()):
		quiz._answers[i] = 0
	quiz._current_index = quiz._answers.size() - 1
	quiz._show_result()
	var title: String = quiz._last_result["title"]
	_check(title != "", "the quiz produced a character (%s)" % title)

	quiz._on_proceed()
	await process_frame
	var select = _find("CharacterSelect")
	if select == null:
		# The select screen may not carry a class_name; fall back to its scene.
		for child in get_root().get_children():
			if child.scene_file_path == "res://scenes/character/character_select.tscn":
				select = child
	_check(select != null, "Play as opens Choose Your Character")
	_check(not is_instance_valid(quiz) or quiz.is_queued_for_deletion(), "the questionnaire closes")
	if select == null:
		_finish()
		return
	_check(select._selected_character != null and select._selected_character.character_name == title,
		"the quiz character is the one selected")
	_check(select.confirm_overlay.visible, "its Play-as confirmation is open")
	_check(select.confirm_title.text == "Play as %s" % title, "the confirmation names it")

	# Proceed with no stat allocation in between (the answers already set
	# its stats): the select screen hands over to town at once.
	select._on_proceed_pressed()
	_check(select._alloc_overlay == null, "no stat allocation for the quiz character")
	await process_frame
	var town = _find_town()
	_check(town != null, "Proceed takes the quiz character into town")
	if town:
		_check(town.starting_character != null and town.starting_character.character_name == title,
			"town starts with the quiz character")
		town.queue_free()

	# A preset still allocates after a quiz character was cancelled.
	var screen = load("res://scenes/character/character_select.tscn").instantiate()
	get_root().add_child(screen)
	await process_frame
	screen.select_quiz_character(CharacterData.create_brad())
	screen._on_cancel_pressed()
	screen._on_character_selected(CharacterData.create_ryan())
	_check(screen._needs_allocation(screen._selected_character), "a preset picked after cancelling still allocates")
	screen.queue_free()
	_finish()

func _finish() -> void:
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
