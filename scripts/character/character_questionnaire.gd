class_name CharacterQuestionnaire
extends Control

## Character questionnaire UI - presents 11 personality questions one at a time,
## then shows a custom-built character with stats, cards, item, and title.


var _questions: Array[Dictionary] = []
var _current_index: int = 0
var _answers: Array[int] = []
var _last_result: Dictionary = {}

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
var _result_title_label: Label = null
var _result_flavor_label: Label = null

func _ready() -> void:
	_questions = QuestionnaireData.get_questions()
	_answers.resize(_questions.size())
	_answers.fill(-1)
	_build_ui()
	_show_question(_current_index)

func _build_ui() -> void:
	# Full-screen dark background, hidden under the Emerald forest backdrop
	# (kept for anything that looks for it).
	_background = ColorRect.new()
	_background.name = "Background"
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.color = Color(0.05, 0.05, 0.08, 1)
	add_child(_background)
	EmeraldTheme.apply(self, true, 0.5)

	# Back button (top-left)
	_back_button = Button.new()
	_back_button.text = "< Back"
	_back_button.position = Vector2(20, 10)
	_back_button.size = Vector2(80, 30)
	EmeraldTheme.style_button(_back_button, 16)
	_back_button.pressed.connect(_on_back)
	add_child(_back_button)

	# Main content container
	_main_vbox = VBoxContainer.new()
	_main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_vbox.offset_left = 80.0
	_main_vbox.offset_top = 50.0
	_main_vbox.offset_right = -80.0
	_main_vbox.offset_bottom = -20.0
	_main_vbox.add_theme_constant_override("separation", 24)
	add_child(_main_vbox)

	# Progress label
	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_font_size_override("font_size", 17)
	_progress_label.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
	_main_vbox.add_child(_progress_label)

	# Question text
	_question_label = Label.new()
	_question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EmeraldTheme.style_title(_question_label, 32)
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

	# Create 4 answer buttons
	for i in range(4):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(600, 50)
		EmeraldTheme.style_button(btn, 20)
		EmeraldTheme.add_ring_markers(btn)
		btn.pressed.connect(_on_answer_selected.bind(i))
		_answers_vbox.add_child(btn)
		_answer_buttons.append(btn)

func _show_question(index: int) -> void:
	if index < 0 or index >= _questions.size():
		return

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
	_last_result = QuestionnaireData.compute_result(_answers)

	# Hide question UI
	_question_label.visible = false
	_progress_label.visible = false
	_answers_vbox.get_parent().visible = false

	# Remove old result panel if retaking
	if _result_panel:
		_result_panel.queue_free()
		_result_panel = null

	_result_panel = VBoxContainer.new()
	_result_panel.add_theme_constant_override("separation", 6)
	_main_vbox.add_child(_result_panel)

	# ---- Title Section ----
	var header = Label.new()
	header.text = "Your Character"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EmeraldTheme.style_heading(header, 20)
	_result_panel.add_child(header)

	_result_title_label = Label.new()
	_result_title_label.text = _last_result["title"]
	_result_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EmeraldTheme.style_title(_result_title_label, 38)
	_result_panel.add_child(_result_title_label)

	# Flavor text
	_result_flavor_label = Label.new()
	_result_flavor_label.text = _last_result["flavor_text"]
	_result_flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_flavor_label.add_theme_font_size_override("font_size", 15)
	_result_flavor_label.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
	_result_panel.add_child(_result_flavor_label)

	# ---- Two-column layout: Stats + Archetype on left, Details on right ----
	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_panel.add_child(columns)

	# Left column: Stats
	var left_col = VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 4)
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left_col)

	var stats_title = Label.new()
	stats_title.text = "Stats"
	EmeraldTheme.style_heading(stats_title, 19)
	left_col.add_child(stats_title)

	var stat_bonuses: Dictionary = _last_result["stat_bonuses"]
	var stat_display_names: Dictionary = {
		"strength": "STR", "dexterity": "DEX", "intelligence": "INT",
		"wisdom": "WIS", "agility": "AGI", "determination": "DET",
	}
	var stat_colors: Dictionary = {
		"strength": Color(1.0, 0.4, 0.4),
		"dexterity": Color(0.4, 1.0, 0.4),
		"intelligence": Color(0.4, 0.6, 1.0),
		"wisdom": Color(0.9, 0.8, 0.3),
		"agility": Color(0.3, 0.9, 0.8),
		"determination": Color(0.9, 0.5, 0.2),
	}

	for stat_key in ["strength", "dexterity", "intelligence", "wisdom", "agility", "determination"]:
		var total = 5 + stat_bonuses[stat_key]
		var bonus = stat_bonuses[stat_key]

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		left_col.add_child(hbox)

		var stat_label = Label.new()
		stat_label.text = stat_display_names[stat_key]
		stat_label.custom_minimum_size = Vector2(40, 0)
		stat_label.add_theme_font_size_override("font_size", 14)
		stat_label.add_theme_color_override("font_color", stat_colors[stat_key])
		hbox.add_child(stat_label)

		# Stat bar
		var bar_bg = ColorRect.new()
		bar_bg.custom_minimum_size = Vector2(180, 16)
		bar_bg.color = Color(0.02, 0.08, 0.06, 0.9)
		hbox.add_child(bar_bg)

		var bar_fill = ColorRect.new()
		# Max possible per stat is ~11 (5 base + up to 6 bonus from 11 questions)
		var fill_pct = clampf(float(total) / 11.0, 0.05, 1.0)
		bar_fill.custom_minimum_size = Vector2(int(174.0 * fill_pct) + 4, 12)
		bar_fill.position = Vector2(2, 2)
		bar_fill.color = stat_colors[stat_key].lerp(Color(0.05, 0.15, 0.12), 0.4)
		bar_bg.add_child(bar_fill)

		var value_label = Label.new()
		if bonus > 0:
			value_label.text = "%d (5+%d)" % [total, bonus]
		else:
			value_label.text = str(total)
		value_label.add_theme_font_size_override("font_size", 13)
		value_label.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
		hbox.add_child(value_label)

	# Archetype scores
	var arch_title = Label.new()
	arch_title.text = "Archetype Affinity"
	EmeraldTheme.style_heading(arch_title, 19)
	left_col.add_child(arch_title)

	var arch_scores: Dictionary = _last_result["archetype_scores"]
	var primary_arch: int = _last_result["primary_archetype"]
	var max_arch: int = 1
	for v in arch_scores.values():
		if v > max_arch:
			max_arch = v

	var arch_order: Array = arch_scores.keys()
	arch_order.sort_custom(func(a, b): return arch_scores[a] > arch_scores[b])

	for arch in arch_order:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		left_col.add_child(hbox)

		var name_label = Label.new()
		name_label.text = QuestionnaireData.get_archetype_name(arch)
		name_label.custom_minimum_size = Vector2(65, 0)
		name_label.add_theme_font_size_override("font_size", 13)
		if arch == primary_arch:
			name_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
		else:
			name_label.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
		hbox.add_child(name_label)

		var bar_bg = ColorRect.new()
		bar_bg.custom_minimum_size = Vector2(150, 14)
		bar_bg.color = Color(0.02, 0.08, 0.06, 0.9)
		hbox.add_child(bar_bg)

		var bar_fill = ColorRect.new()
		var fill_w = int(144.0 * arch_scores[arch] / max_arch) + 4
		bar_fill.custom_minimum_size = Vector2(fill_w, 10)
		bar_fill.position = Vector2(2, 2)
		if arch == primary_arch:
			bar_fill.color = Color(0.3, 0.7, 0.4)
		else:
			bar_fill.color = Color(0.20, 0.32, 0.28)
		bar_bg.add_child(bar_fill)

		var score_label = Label.new()
		score_label.text = str(arch_scores[arch])
		score_label.add_theme_font_size_override("font_size", 13)
		score_label.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
		hbox.add_child(score_label)

	# Right column: Starting gear and cards
	var right_col = VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 4)
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right_col)

	# Character Passive
	var passive_title = Label.new()
	passive_title.text = "Character Passive"
	EmeraldTheme.style_heading(passive_title, 19)
	right_col.add_child(passive_title)

	var passive_desc = Label.new()
	passive_desc.text = _last_result["passive_description"]
	passive_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	passive_desc.add_theme_font_size_override("font_size", 14)
	passive_desc.add_theme_color_override("font_color", Color(0.8, 0.75, 0.5))
	right_col.add_child(passive_desc)

	# Passive Paths (4 skill tree archetypes)
	var paths_title = Label.new()
	paths_title.text = "Passive Paths"
	EmeraldTheme.style_heading(paths_title, 19)
	right_col.add_child(paths_title)

	var paths: Array = _last_result["passive_paths"]
	for i in range(paths.size()):
		var path_entry = paths[i]
		var path_hbox = HBoxContainer.new()
		path_hbox.add_theme_constant_override("separation", 6)
		right_col.add_child(path_hbox)

		var path_name = Label.new()
		path_name.text = path_entry["name"]
		path_name.custom_minimum_size = Vector2(130, 0)
		path_name.add_theme_font_size_override("font_size", 14)
		if i < 2:
			path_name.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
		else:
			path_name.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
		path_hbox.add_child(path_name)

		var path_desc = Label.new()
		path_desc.text = path_entry["description"]
		path_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		path_desc.add_theme_font_size_override("font_size", 13)
		path_desc.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
		path_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		path_hbox.add_child(path_desc)

	# Starting Cards
	var cards_title = Label.new()
	cards_title.text = "Starting Cards"
	EmeraldTheme.style_heading(cards_title, 19)
	right_col.add_child(cards_title)

	var cards_text := "Base deck (Attack, Exposing Strike, Block, Braced Draw, Heal) — identical for every character"

	var cards_label = Label.new()
	cards_label.text = cards_text
	cards_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cards_label.add_theme_font_size_override("font_size", 13)
	cards_label.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
	right_col.add_child(cards_label)

	# Slot specialty
	var slot_title = Label.new()
	slot_title.text = "Equipment Slots"
	EmeraldTheme.style_heading(slot_title, 19)
	right_col.add_child(slot_title)

	var slot_label = Label.new()
	slot_label.text = _last_result["slot_specialty"]
	slot_label.add_theme_font_size_override("font_size", 14)
	slot_label.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
	right_col.add_child(slot_label)

	# ---- Action Buttons ----
	var btn_center = CenterContainer.new()
	_result_panel.add_child(btn_center)
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 30)
	btn_center.add_child(btn_hbox)

	var proceed_btn = Button.new()
	proceed_btn.text = "Play as %s" % _last_result["title"]
	proceed_btn.custom_minimum_size = Vector2(220, 50)
	EmeraldTheme.style_button(proceed_btn, 20)
	EmeraldTheme.add_ring_markers(proceed_btn)
	proceed_btn.pressed.connect(_on_proceed)
	btn_hbox.add_child(proceed_btn)

	var choose_btn = Button.new()
	choose_btn.text = "Choose Preset"
	choose_btn.custom_minimum_size = Vector2(200, 50)
	EmeraldTheme.style_button(choose_btn, 20)
	choose_btn.pressed.connect(_on_choose_myself)
	btn_hbox.add_child(choose_btn)

	var retake_btn = Button.new()
	retake_btn.text = "Retake Quiz"
	retake_btn.custom_minimum_size = Vector2(200, 50)
	EmeraldTheme.style_button(retake_btn, 20)
	retake_btn.pressed.connect(_on_retake)
	btn_hbox.add_child(retake_btn)

func _on_proceed() -> void:
	var character = QuestionnaireData.build_character(_last_result)
	# Navigate to character select with this character pre-selected, show mode select
	var select_scene = load("res://scenes/character/character_select.tscn").instantiate()
	select_scene.game_mode = "single_player"
	select_scene._selected_character = character
	get_tree().root.add_child(select_scene)
	queue_free()
	# Show the town/fight mode select immediately
	select_scene._show_mode_select()

func _on_choose_myself() -> void:
	var select_scene = load("res://scenes/character/character_select.tscn").instantiate()
	select_scene.game_mode = "single_player"
	get_tree().root.add_child(select_scene)
	queue_free()

func _on_retake() -> void:
	_current_index = 0
	_answers.fill(-1)
	if _result_panel:
		_result_panel.queue_free()
		_result_panel = null
	_answers_vbox.get_parent().visible = true
	_question_label.visible = true
	_progress_label.visible = true
	_show_question(0)

func _on_back() -> void:
	if _current_index > 0 and (_result_panel == null or not _result_panel.visible):
		_current_index -= 1
		_answers[_current_index] = -1
		_show_question(_current_index)
	elif _result_panel and _result_panel.visible:
		_result_panel.queue_free()
		_result_panel = null
		_current_index = _questions.size() - 1
		_answers[_current_index] = -1
		_answers_vbox.get_parent().visible = true
		_question_label.visible = true
		_progress_label.visible = true
		_show_question(_current_index)
	else:
		# Go back to character select (quiz is accessed from there)
		var select_scene = load("res://scenes/character/character_select.tscn").instantiate()
		select_scene.game_mode = "single_player"
		get_tree().root.add_child(select_scene)
		queue_free()
