class_name CharacterQuestionnaire
extends Control

## Character questionnaire UI - presents 11 personality questions one at a time,
## then shows the recommended character with an option to proceed or retake.

signal character_recommended(character: CharacterData)
signal back_pressed

var _questions: Array[Dictionary] = []
var _current_index: int = 0
var _answers: Array[int] = []

# UI references (built dynamically)
var _background: ColorRect
var _main_vbox: VBoxContainer
var _progress_label: Label
var _question_label: Label
var _answers_vbox: VBoxContainer
var _answer_buttons: Array[Button] = []
var _back_button: Button

# Result screen references
var _result_panel: VBoxContainer = null
var _result_name_label: Label = null
var _result_desc_label: Label = null
var _score_container: VBoxContainer = null

func _ready() -> void:
	_questions = QuestionnaireData.get_questions()
	_answers.resize(_questions.size())
	_answers.fill(-1)
	_build_ui()
	_show_question(_current_index)

func _build_ui() -> void:
	# Full-screen dark background
	_background = ColorRect.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.color = Color(0.05, 0.05, 0.08, 1)
	add_child(_background)

	# Back button (top-left)
	_back_button = Button.new()
	_back_button.text = "< Back"
	_back_button.position = Vector2(20, 10)
	_back_button.size = Vector2(80, 30)
	_back_button.add_theme_font_size_override("font_size", 16)
	_style_button_flat(_back_button, Color(0.2, 0.2, 0.25), Color(0.3, 0.3, 0.35), Color(0.4, 0.4, 0.5), Color(0.5, 0.5, 0.6))
	_back_button.pressed.connect(_on_back)
	add_child(_back_button)

	# Main content container (centered vertically)
	_main_vbox = VBoxContainer.new()
	_main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_vbox.offset_left = 80.0
	_main_vbox.offset_top = 60.0
	_main_vbox.offset_right = -80.0
	_main_vbox.offset_bottom = -40.0
	_main_vbox.add_theme_constant_override("separation", 24)
	add_child(_main_vbox)

	# Progress label (e.g. "Question 3 of 11")
	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_font_size_override("font_size", 14)
	_progress_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.65))
	_main_vbox.add_child(_progress_label)

	# Question text
	_question_label = Label.new()
	_question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_question_label.add_theme_font_size_override("font_size", 26)
	_question_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	_question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_main_vbox.add_child(_question_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	_main_vbox.add_child(spacer)

	# Answer buttons container (centered)
	var answer_center = CenterContainer.new()
	answer_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_vbox.add_child(answer_center)

	_answers_vbox = VBoxContainer.new()
	_answers_vbox.add_theme_constant_override("separation", 12)
	answer_center.add_child(_answers_vbox)

	# Create 4 answer buttons (reused for each question)
	for i in range(4):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(600, 50)
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
		_style_answer_button(btn)
		btn.pressed.connect(_on_answer_selected.bind(i))
		_answers_vbox.add_child(btn)
		_answer_buttons.append(btn)

func _show_question(index: int) -> void:
	if index < 0 or index >= _questions.size():
		return

	# Hide result panel if showing
	if _result_panel:
		_result_panel.visible = false
	_answers_vbox.get_parent().visible = true
	_question_label.visible = true
	_progress_label.visible = true

	var q = _questions[index]
	_progress_label.text = "Question %d of %d" % [index + 1, _questions.size()]
	_question_label.text = q["question"]

	var answers: Array = q["answers"]
	for i in range(4):
		if i < answers.size():
			_answer_buttons[i].text = answers[i]["text"]
			_answer_buttons[i].visible = true
		else:
			_answer_buttons[i].visible = false

func _on_answer_selected(answer_index: int) -> void:
	_answers[_current_index] = answer_index
	_current_index += 1

	if _current_index >= _questions.size():
		_show_result()
	else:
		_show_question(_current_index)

func _show_result() -> void:
	var result = QuestionnaireData.compute_result(_answers)
	var recommended: String = result["recommended"]
	var scores: Dictionary = result["scores"]

	# Hide question UI
	_question_label.visible = false
	_progress_label.visible = false
	_answers_vbox.get_parent().visible = false

	# Build or reuse result panel
	if not _result_panel:
		_result_panel = VBoxContainer.new()
		_result_panel.add_theme_constant_override("separation", 16)
		_main_vbox.add_child(_result_panel)

		var title = Label.new()
		title.text = "Your Character Recommendation"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 28)
		title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		_result_panel.add_child(title)

		# Character name
		_result_name_label = Label.new()
		_result_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_result_name_label.add_theme_font_size_override("font_size", 36)
		_result_name_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
		_result_panel.add_child(_result_name_label)

		# Description
		_result_desc_label = Label.new()
		_result_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_result_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_result_desc_label.add_theme_font_size_override("font_size", 16)
		_result_desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		_result_panel.add_child(_result_desc_label)

		# Spacer
		var sp = Control.new()
		sp.custom_minimum_size = Vector2(0, 8)
		_result_panel.add_child(sp)

		# Score breakdown title
		var score_title = Label.new()
		score_title.text = "Affinity Scores"
		score_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_title.add_theme_font_size_override("font_size", 18)
		score_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.72))
		_result_panel.add_child(score_title)

		# Score bars container
		var score_center = CenterContainer.new()
		_result_panel.add_child(score_center)
		_score_container = VBoxContainer.new()
		_score_container.add_theme_constant_override("separation", 6)
		score_center.add_child(_score_container)

		# Spacer
		var sp2 = Control.new()
		sp2.custom_minimum_size = Vector2(0, 12)
		_result_panel.add_child(sp2)

		# Buttons row
		var btn_center = CenterContainer.new()
		_result_panel.add_child(btn_center)
		var btn_hbox = HBoxContainer.new()
		btn_hbox.add_theme_constant_override("separation", 30)
		btn_center.add_child(btn_hbox)

		var proceed_btn = Button.new()
		proceed_btn.text = "Play as %s" % recommended
		proceed_btn.custom_minimum_size = Vector2(200, 50)
		proceed_btn.add_theme_font_size_override("font_size", 18)
		_style_button_flat(proceed_btn, Color(0.15, 0.3, 0.15), Color(0.2, 0.4, 0.2), Color(0.3, 0.6, 0.3), Color(0.4, 0.8, 0.4))
		proceed_btn.pressed.connect(_on_proceed.bind(recommended))
		btn_hbox.add_child(proceed_btn)

		var choose_btn = Button.new()
		choose_btn.text = "Choose Myself"
		choose_btn.custom_minimum_size = Vector2(200, 50)
		choose_btn.add_theme_font_size_override("font_size", 18)
		_style_button_flat(choose_btn, Color(0.15, 0.15, 0.3), Color(0.2, 0.2, 0.4), Color(0.3, 0.3, 0.6), Color(0.4, 0.4, 0.8))
		choose_btn.pressed.connect(_on_choose_myself)
		btn_hbox.add_child(choose_btn)

		var retake_btn = Button.new()
		retake_btn.text = "Retake Quiz"
		retake_btn.custom_minimum_size = Vector2(200, 50)
		retake_btn.add_theme_font_size_override("font_size", 18)
		_style_button_flat(retake_btn, Color(0.25, 0.2, 0.1), Color(0.35, 0.28, 0.15), Color(0.5, 0.4, 0.2), Color(0.7, 0.55, 0.3))
		retake_btn.pressed.connect(_on_retake)
		btn_hbox.add_child(retake_btn)

	_result_panel.visible = true
	_result_name_label.text = recommended
	_result_desc_label.text = QuestionnaireData.get_character_description(recommended)

	# Update the proceed button text
	var btn_hbox = _result_panel.get_child(_result_panel.get_child_count() - 1).get_child(0)
	var proceed_btn = btn_hbox.get_child(0) as Button
	proceed_btn.text = "Play as %s" % recommended
	# Reconnect signal to pass correct name
	if proceed_btn.pressed.is_connected(_on_proceed):
		proceed_btn.pressed.disconnect(_on_proceed)
	proceed_btn.pressed.connect(_on_proceed.bind(recommended))

	# Update score bars
	for child in _score_container.get_children():
		child.queue_free()

	# Sort scores descending
	var sorted_names: Array = scores.keys()
	sorted_names.sort_custom(func(a, b): return scores[a] > scores[b])

	var max_score: int = 1
	for s in scores.values():
		if s > max_score:
			max_score = s

	for char_name in sorted_names:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		_score_container.add_child(hbox)

		var name_label = Label.new()
		name_label.text = char_name
		name_label.custom_minimum_size = Vector2(80, 0)
		name_label.add_theme_font_size_override("font_size", 15)
		if char_name == recommended:
			name_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
		else:
			name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		hbox.add_child(name_label)

		# Score bar background
		var bar_bg = ColorRect.new()
		bar_bg.custom_minimum_size = Vector2(300, 18)
		bar_bg.color = Color(0.15, 0.15, 0.2)
		hbox.add_child(bar_bg)

		# Score bar fill
		var bar_fill = ColorRect.new()
		var fill_width = int(290.0 * scores[char_name] / max_score) + 10
		bar_fill.custom_minimum_size = Vector2(fill_width, 14)
		bar_fill.position = Vector2(2, 2)
		if char_name == recommended:
			bar_fill.color = Color(0.3, 0.75, 0.4)
		else:
			bar_fill.color = Color(0.3, 0.3, 0.5)
		bar_bg.add_child(bar_fill)

		var score_label = Label.new()
		score_label.text = str(scores[char_name])
		score_label.add_theme_font_size_override("font_size", 14)
		score_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		hbox.add_child(score_label)

func _on_proceed(char_name: String) -> void:
	var character = QuestionnaireData.get_character_by_name(char_name)
	character_recommended.emit(character)
	# Navigate to character select with this character pre-selected, show mode select
	var select_scene = load("res://scenes/character_select.tscn").instantiate()
	select_scene.game_mode = "single_player"
	select_scene._selected_character = character
	get_tree().root.add_child(select_scene)
	queue_free()
	# Show the town/fight mode select immediately
	select_scene._show_mode_select()

func _on_choose_myself() -> void:
	# Go to normal character select screen
	var select_scene = load("res://scenes/character_select.tscn").instantiate()
	select_scene.game_mode = "single_player"
	get_tree().root.add_child(select_scene)
	queue_free()

func _on_retake() -> void:
	_current_index = 0
	_answers.fill(-1)
	if _result_panel:
		_result_panel.visible = false
	_show_question(0)

func _on_back() -> void:
	if _current_index > 0 and (_result_panel == null or not _result_panel.visible):
		# Go back one question
		_current_index -= 1
		_answers[_current_index] = -1
		_show_question(_current_index)
	elif _result_panel and _result_panel.visible:
		# From result screen, go back to last question
		_result_panel.visible = false
		_current_index = _questions.size() - 1
		_answers[_current_index] = -1
		_show_question(_current_index)
	else:
		# Go back to title menu
		back_pressed.emit()
		var title_scene = load("res://scenes/title_menu.tscn").instantiate()
		get_tree().root.add_child(title_scene)
		queue_free()

# ---- Styling helpers ----

func _style_answer_button(btn: Button) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.12, 0.18, 0.8)
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.3, 0.3, 0.45)
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	normal.content_margin_left = 16.0
	normal.content_margin_right = 16.0
	btn.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.18, 0.18, 0.26, 0.9)
	hover.border_width_left = 2
	hover.border_width_right = 2
	hover.border_width_top = 2
	hover.border_width_bottom = 2
	hover.border_color = Color(0.5, 0.4, 0.2)
	hover.corner_radius_top_left = 6
	hover.corner_radius_top_right = 6
	hover.corner_radius_bottom_left = 6
	hover.corner_radius_bottom_right = 6
	hover.content_margin_left = 16.0
	hover.content_margin_right = 16.0
	btn.add_theme_stylebox_override("hover", hover)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = Color(0.22, 0.18, 0.1, 0.95)
	pressed.border_width_left = 2
	pressed.border_width_right = 2
	pressed.border_width_top = 2
	pressed.border_width_bottom = 2
	pressed.border_color = Color(0.7, 0.55, 0.2)
	pressed.corner_radius_top_left = 6
	pressed.corner_radius_top_right = 6
	pressed.corner_radius_bottom_left = 6
	pressed.corner_radius_bottom_right = 6
	pressed.content_margin_left = 16.0
	pressed.content_margin_right = 16.0
	btn.add_theme_stylebox_override("pressed", pressed)

func _style_button_flat(btn: Button, normal_bg: Color, hover_bg: Color, normal_border: Color, hover_border: Color) -> void:
	var ns = StyleBoxFlat.new()
	ns.bg_color = normal_bg
	ns.border_width_left = 2
	ns.border_width_right = 2
	ns.border_width_top = 2
	ns.border_width_bottom = 2
	ns.border_color = normal_border
	ns.corner_radius_top_left = 6
	ns.corner_radius_top_right = 6
	ns.corner_radius_bottom_left = 6
	ns.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", ns)
	var hs = StyleBoxFlat.new()
	hs.bg_color = hover_bg
	hs.border_width_left = 2
	hs.border_width_right = 2
	hs.border_width_top = 2
	hs.border_width_bottom = 2
	hs.border_color = hover_border
	hs.corner_radius_top_left = 6
	hs.corner_radius_top_right = 6
	hs.corner_radius_bottom_left = 6
	hs.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("hover", hs)
