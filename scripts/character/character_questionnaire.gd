class_name CharacterQuestionnaire
extends Control

## Character questionnaire UI - presents 11 personality questions one at a time,
## then shows a custom-built character with stats, cards, item, and title.

signal character_recommended(character: CharacterData)
signal back_pressed

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

	# Main content container
	_main_vbox = VBoxContainer.new()
	_main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_vbox.offset_left = 80.0
	_main_vbox.offset_top = 60.0
	_main_vbox.offset_right = -80.0
	_main_vbox.offset_bottom = -40.0
	_main_vbox.add_theme_constant_override("separation", 24)
	add_child(_main_vbox)

	# Progress label
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

	# Create 4 answer buttons
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
	_result_panel.add_theme_constant_override("separation", 12)
	_main_vbox.add_child(_result_panel)

	# ---- Title Section ----
	var header = Label.new()
	header.text = "Your Character"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.72))
	_result_panel.add_child(header)

	_result_title_label = Label.new()
	_result_title_label.text = _last_result["title"]
	_result_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title_label.add_theme_font_size_override("font_size", 36)
	_result_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	_result_panel.add_child(_result_title_label)

	# Flavor text
	_result_flavor_label = Label.new()
	_result_flavor_label.text = _last_result["flavor_text"]
	_result_flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_flavor_label.add_theme_font_size_override("font_size", 14)
	_result_flavor_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_result_panel.add_child(_result_flavor_label)

	# ---- Two-column layout: Stats + Archetype on left, Details on right ----
	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_panel.add_child(columns)

	# Left column: Stats
	var left_col = VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 8)
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left_col)

	var stats_title = Label.new()
	stats_title.text = "Stats"
	stats_title.add_theme_font_size_override("font_size", 18)
	stats_title.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
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
		bar_bg.color = Color(0.12, 0.12, 0.18)
		hbox.add_child(bar_bg)

		var bar_fill = ColorRect.new()
		# Max possible per stat is ~11 (5 base + up to 6 bonus from 11 questions)
		var fill_pct = clampf(float(total) / 11.0, 0.05, 1.0)
		bar_fill.custom_minimum_size = Vector2(int(174.0 * fill_pct) + 4, 12)
		bar_fill.position = Vector2(2, 2)
		bar_fill.color = stat_colors[stat_key].lerp(Color(0.2, 0.2, 0.3), 0.4)
		bar_bg.add_child(bar_fill)

		var value_label = Label.new()
		if bonus > 0:
			value_label.text = "%d (5+%d)" % [total, bonus]
		else:
			value_label.text = str(total)
		value_label.add_theme_font_size_override("font_size", 13)
		value_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		hbox.add_child(value_label)

	# Archetype scores
	var arch_title = Label.new()
	arch_title.text = "Archetype Affinity"
	arch_title.add_theme_font_size_override("font_size", 18)
	arch_title.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
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
			name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		hbox.add_child(name_label)

		var bar_bg = ColorRect.new()
		bar_bg.custom_minimum_size = Vector2(150, 14)
		bar_bg.color = Color(0.12, 0.12, 0.18)
		hbox.add_child(bar_bg)

		var bar_fill = ColorRect.new()
		var fill_w = int(144.0 * arch_scores[arch] / max_arch) + 4
		bar_fill.custom_minimum_size = Vector2(fill_w, 10)
		bar_fill.position = Vector2(2, 2)
		if arch == primary_arch:
			bar_fill.color = Color(0.3, 0.7, 0.4)
		else:
			bar_fill.color = Color(0.3, 0.3, 0.45)
		bar_bg.add_child(bar_fill)

		var score_label = Label.new()
		score_label.text = str(arch_scores[arch])
		score_label.add_theme_font_size_override("font_size", 12)
		score_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		hbox.add_child(score_label)

	# Right column: Starting gear and cards
	var right_col = VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 8)
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right_col)

	# Character Passive
	var passive_title = Label.new()
	passive_title.text = "Character Passive"
	passive_title.add_theme_font_size_override("font_size", 18)
	passive_title.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
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
	paths_title.add_theme_font_size_override("font_size", 18)
	paths_title.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
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
		path_desc.add_theme_font_size_override("font_size", 11)
		path_desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		path_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		path_hbox.add_child(path_desc)

	# Starting Cards
	var cards_title = Label.new()
	cards_title.text = "Starting Cards"
	cards_title.add_theme_font_size_override("font_size", 18)
	cards_title.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	right_col.add_child(cards_title)

	var cards_text := "Base deck (Slash x4, Block x4, Draw, Energy, Heal) — identical for every character"

	var cards_label = Label.new()
	cards_label.text = cards_text
	cards_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cards_label.add_theme_font_size_override("font_size", 13)
	cards_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	right_col.add_child(cards_label)

	# Slot specialty
	var slot_title = Label.new()
	slot_title.text = "Equipment Slots"
	slot_title.add_theme_font_size_override("font_size", 18)
	slot_title.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	right_col.add_child(slot_title)

	var slot_label = Label.new()
	slot_label.text = _last_result["slot_specialty"]
	slot_label.add_theme_font_size_override("font_size", 14)
	slot_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
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
	proceed_btn.add_theme_font_size_override("font_size", 18)
	_style_button_flat(proceed_btn, Color(0.15, 0.3, 0.15), Color(0.2, 0.4, 0.2), Color(0.3, 0.6, 0.3), Color(0.4, 0.8, 0.4))
	proceed_btn.pressed.connect(_on_proceed)
	btn_hbox.add_child(proceed_btn)

	var choose_btn = Button.new()
	choose_btn.text = "Choose Preset"
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

func _on_proceed() -> void:
	var character = QuestionnaireData.build_character(_last_result)
	character_recommended.emit(character)
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
		back_pressed.emit()
		var select_scene = load("res://scenes/character/character_select.tscn").instantiate()
		select_scene.game_mode = "single_player"
		get_tree().root.add_child(select_scene)
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
