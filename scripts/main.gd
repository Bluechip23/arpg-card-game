extends Node3D

## Main game scene - turn-based card ARPG

@onready var deck_manager: DeckManager = $DeckManager
@onready var buff_bar: BuffBarUI = $UI/BuffBar
@onready var turn_manager: TurnManager = $TurnManager
@onready var grid_manager: GridManager = $GridManager
@onready var move_dialog: MoveConfirmDialog = $MoveConfirmDialog
@onready var character_panel: CharacterPanel = $CharacterPanel
@onready var enemy_spawner: EnemySpawner = $EnemySpawner
@onready var test_ui: TestUI = $TestUi
@onready var gauntlet_skills_container: HBoxContainer = $UI/GauntletSkillsContainer
@onready var item_tooltip: ItemTooltip = $UI/ItemTooltip
@onready var aoe_indicator: AOEIndicator = $AOEIndicator
@onready var debuff_bar: DebuffBarUI = $UI/DebuffBar
@onready var hand_container: Control = $UI/HandArea/HandContainer
@onready var draw_label: Label = $UI/DeckInfo/DrawPileLabel
@onready var discard_label: Label = $UI/DeckInfo/DiscardPileLabel
@onready var jail_label: Label = $UI/DeckInfo/JailPileLabel
@onready var selected_label: Label = $UI/SelectedLabel
@onready var peaked_label: Label = $UI/PeakedLabel
@onready var tempo_label: Label = $UI/TempoContainer/TempoLabel
@onready var tempo_bar: ProgressBar = $UI/TempoContainer/TempoBar
@onready var overflow_buttons: HBoxContainer = $UI/OverflowButtons
@onready var player_health_label: Label = $UI/PlayerHealthLabel
@onready var player_mana_label: Label = $UI/PlayerManaLabel
@onready var player_armor_label: Label = $UI/PlayerArmorLabel
@onready var player_xp_label: Label = $UI/PlayerXPLabel
@onready var turn_label: Label = $UI/TurnLabel
@onready var player: Player = $Player
@onready var tempo_manager: TempoManager = $TempoManager
@onready var overflow_manager: OverflowManager = $OverflowManager
@onready var manifest_ui: ManifestUI = $UI/ManifestUI
@onready var overflow_ui: OverflowUI = $UI/OverflowUI
@onready var help_panel: HelpPanel = $HelpPanel
@onready var help_buttons: HelpButtons = $UI/HelpButtons
@onready var quiver_ui: QuiverUI = $UI/QuiverUI
@onready var sphere_grid_ui: SphereGridUI = $SphereGridUI
@onready var sphere_inventory: SphereInventory = $SphereInventory
@onready var range_indicator: RangeIndicator = $RangeIndicator

var unit_tracker: UnitTrackerUI = null

var battle_log_label: RichTextLabel = null
var battle_log_panel: PanelContainer = null
var _battle_log_toggle_btn: Button = null
var _battle_log_minimized: bool = false
const BATTLE_LOG_MAX_LINES: int = 50

const GauntletSkillUIScene = preload("res://scenes/gauntlet_skill_ui.tscn")
const CardUIScene = preload("res://scenes/card_ui.tscn")

const CARD_KEYS = [
	KEY_A, KEY_S, KEY_D, KEY_F, KEY_G,
	KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T,
	KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B
]

var selected_card_index: int = -1
var current_character: CharacterData = null
var starting_character: CharacterData = null
var player2_character: CharacterData = null
var is_multiplayer: bool = false

# Player 2 state
var _p2_deck_manager: DeckManager = null
var _p2_hand_panel: PanelContainer = null
var _p2_hand_container: VBoxContainer = null
var _p2_hand_visible: bool = false
var _p2_hand_card_preview: PanelContainer = null
var _p2_deck_panel: PanelContainer = null
var _p2_deck_container: VBoxContainer = null
var _p2_deck_visible: bool = false
var _p2_deck_card_preview: PanelContainer = null

var deck_list_panel: PanelContainer = null
var deck_list_container: VBoxContainer = null
var deck_list_visible: bool = false
var deck_list_card_preview: PanelContainer = null
var hand_card_preview: PanelContainer = null
var _hand_hover_id: int = 0
var pending_sky_falls: Array = []  # [{position: Vector3, damage: int, tempo_remaining: int}]
var barricade_obstacles: Array = []  # [{node: MeshInstance3D, health: int}]
var active_pillars: Array = []  # [{node: Node3D, position: Vector3, tempo_remaining: int}]
var _card_ui_instances: Array = []
var _current_hand_hover_index: int = -1
# Pending quiver card play state
var _block_button: Button = null
var _pending_quiver_card: Card = null
var _pending_quiver_index: int = -1
var _pending_quiver_target_type: String = ""

# Camera orbit state
var _camera_focus: Vector3 = Vector3(10, 0, 6)  # Center of the 20x12 grid
var _camera_yaw: float = 0.0       # Horizontal rotation (radians)
var _camera_pitch: float = -0.785  # Vertical angle (radians), -45° default
var _camera_distance: float = 17.0 # Distance from focus point
var _camera_orbiting: bool = false  # True while left-dragging to orbit
var _camera_drag_start: Vector2 = Vector2.ZERO
const CAMERA_PITCH_MIN: float = -1.4   # ~-80° (nearly top-down)
const CAMERA_PITCH_MAX: float = -0.15  # ~-9° (nearly level)
const CAMERA_ZOOM_MIN: float = 6.0
const CAMERA_ZOOM_MAX: float = 35.0
const CAMERA_ZOOM_STEP: float = 2.0
const CAMERA_ORBIT_SENSITIVITY: float = 0.005

func _ready() -> void:
	deck_manager.hand_updated.connect(_on_hand_updated)
	deck_manager.deck_shuffled.connect(_on_deck_shuffled)
	deck_manager.card_peaked.connect(_on_card_peaked)
	deck_manager.card_discarded.connect(_on_card_discarded)
	test_ui.apply_overflow_requested.connect(_on_apply_overflow)
	deck_manager.overflow_triggered.connect(_on_overflow_triggered)
	tempo_manager.tempo_threshold_reached.connect(_on_tempo_threshold_reached)
	tempo_manager.tempo_changed.connect(_on_tempo_changed)
	tempo_manager.tempo_advanced.connect(_on_tempo_advanced)
	turn_manager.turn_ended.connect(_on_turn_ended)
	manifest_ui.manifest_card_clicked.connect(_on_manifest_card_clicked)
	quiver_ui.quiver_card_targeting_selected.connect(_on_quiver_card_targeting_selected)
	overflow_manager.overcharge_triggered.connect(_on_overcharge_triggered)
	player.move_completed.connect(_on_player_move_completed)
	player.tile_reached.connect(_on_player_tile_reached)
	player.set_grid_manager(grid_manager)
	player.enemy_spawner = enemy_spawner

	move_dialog.confirmed.connect(_on_move_confirmed)
	move_dialog.cancelled.connect(_on_move_cancelled)
	
	# Enemy spawner
	enemy_spawner.initialize(grid_manager, player)
	enemy_spawner.enemy_killed.connect(_on_enemy_killed)
	enemy_spawner.all_enemies_defeated.connect(_on_all_enemies_defeated)
	
	# Test UI
	test_ui.spawn_wave_requested.connect(_on_spawn_wave)
	test_ui.spawn_elite_requested.connect(_on_spawn_elite)
	test_ui.give_item_requested.connect(_on_give_item)
	test_ui.give_card_requested.connect(_on_give_card)
	test_ui.apply_buff_requested.connect(_on_apply_buff)
	
	help_buttons.keywords_pressed.connect(_on_keywords_pressed)
	help_buttons.walkthrough_pressed.connect(_on_walkthrough_pressed)
	help_panel.closed.connect(_on_help_closed)
	
	# Sphere inventory + grid connection
	sphere_grid_ui.connect_sphere_inventory(sphere_inventory)

	_setup_overflow_buttons()
	_setup_action_buttons()
	_setup_battle_log()

	if starting_character:
		select_character(starting_character)
	else:
		select_character(CharacterData.create_ryan())
	
	# Style the hand area with solid background so battlefield doesn't bleed through
	_setup_hand_area_background()
	_setup_deck_list_button()
	_setup_deck_list_panel()
	_setup_hand_card_preview()

	# Multiplayer: initialize P2 deck and UI buttons
	if is_multiplayer and player2_character:
		_initialize_player2()

	# Unit tracker (left side panel)
	_setup_unit_tracker()

	# Spawn initial test wave
	enemy_spawner.spawn_test_arena()
	_update_enemy_count()
	_refresh_unit_tracker()

## Raycast from camera through mouse position to the ground plane (Y=0).
## Returns the 3D world position on the ground.
func get_mouse_world_position() -> Vector3:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return Vector3.ZERO
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var dir = camera.project_ray_normal(mouse_pos)
	if abs(dir.y) < 0.001:
		return Vector3.ZERO
	var t = -from.y / dir.y
	if t < 0:
		return Vector3.ZERO
	return from + dir * t

func _on_keywords_pressed() -> void:
	help_panel.show_panel(0)  # Keywords tab

func _on_walkthrough_pressed() -> void:
	help_panel.show_panel(1)  # Walkthrough tab

func _on_help_closed() -> void:
	pass  # Resume game if needed

func _update_camera() -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	# Compute camera position on a sphere around the focus point
	var offset = Vector3(
		sin(_camera_yaw) * cos(_camera_pitch) * _camera_distance,
		-sin(_camera_pitch) * _camera_distance,
		cos(_camera_yaw) * cos(_camera_pitch) * _camera_distance
	)
	camera.position = _camera_focus + offset
	camera.look_at(_camera_focus, Vector3.UP)

func _process(_delta: float) -> void:
	_update_hand_hover()
	_update_battlefield_enemy_hover()
	# Feed mouse world position to AOE indicator for cone/line direction
	if aoe_indicator and aoe_indicator.visible:
		var mouse_world = get_mouse_world_position()
		aoe_indicator.set_mouse_world_position(mouse_world)
		# Point-targeting AOE: move the indicator to follow the cursor
		if selected_card_index >= 0 and selected_card_index < deck_manager.hand.size():
			var card = deck_manager.hand[selected_card_index]
			if card.is_aoe and "point" in card.target_types and mouse_world != Vector3.ZERO:
				aoe_indicator.position = grid_manager.snap_to_grid(mouse_world)

func _update_hand_hover() -> void:
	if _card_ui_instances.is_empty():
		if _current_hand_hover_index != -1:
			_set_hand_hover(-1)
		return

	var mouse_pos = hand_container.get_local_mouse_position()

	# Expanded detection area - generous vertical padding for easier targeting
	var in_bounds = (
		mouse_pos.y >= -30.0 and
		mouse_pos.y <= hand_container.size.y + 10.0 and
		mouse_pos.x >= -20.0 and
		mouse_pos.x <= hand_container.size.x + 20.0
	)

	if not in_bounds:
		if _current_hand_hover_index != -1:
			_set_hand_hover(-1)
		return

	# Find closest card by center X position
	var best_index = -1
	var best_dist = INF
	var card_half_width = 60.0  # 120 / 2

	for i in range(_card_ui_instances.size()):
		var card_ui = _card_ui_instances[i]
		if not is_instance_valid(card_ui):
			continue
		var center_x = card_ui.position.x + card_half_width
		var dist = abs(mouse_pos.x - center_x)
		if dist < best_dist:
			best_dist = dist
			best_index = i

	# Don't hover if mouse is too far from any card
	if best_dist > card_half_width + 30.0:
		if _current_hand_hover_index != -1:
			_set_hand_hover(-1)
		return

	if best_index != _current_hand_hover_index:
		_set_hand_hover(best_index)

func _set_hand_hover(new_index: int) -> void:
	# Unhover previous card
	if _current_hand_hover_index >= 0 and _current_hand_hover_index < _card_ui_instances.size():
		var old_ui = _card_ui_instances[_current_hand_hover_index]
		if is_instance_valid(old_ui):
			old_ui.set_hovered_external(false)

	# Always trigger unhover callback when changing cards
	if _current_hand_hover_index != -1:
		_on_hand_card_unhovered()

	_current_hand_hover_index = new_index

	# Hover new card
	if new_index >= 0 and new_index < _card_ui_instances.size():
		var new_ui = _card_ui_instances[new_index]
		if is_instance_valid(new_ui) and new_index < deck_manager.hand.size():
			new_ui.set_hovered_external(true)
			_on_hand_card_hovered(deck_manager.hand[new_index], new_ui)

var _prev_battlefield_hover: Enemy = null

func _update_battlefield_enemy_hover() -> void:
	## Check if mouse is hovering over a battlefield enemy and highlight its panel entry.
	var mouse_pos = get_mouse_world_position()
	var closest: Enemy = null
	var closest_dist: float = 1.2  # Must be within ~1 tile

	for enemy in enemy_spawner.get_living_enemies():
		var diff = mouse_pos - enemy.position
		var dist = Vector3(diff.x, 0, diff.z).length()
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy

	if closest != _prev_battlefield_hover:
		# Unhighlight previous
		if _prev_battlefield_hover and is_instance_valid(_prev_battlefield_hover):
			_set_enemy_highlight(_prev_battlefield_hover, false)
		if unit_tracker:
			unit_tracker.clear_highlight()

		# Highlight new
		if closest:
			_set_enemy_highlight(closest, true)
			if unit_tracker:
				unit_tracker.highlight_enemy(closest)

		_prev_battlefield_hover = closest

func _setup_overflow_buttons() -> void:
	var modes = ["Jailed", "Enhance", "Peak", "Transferred", "Overcharge", "Manifest"]
	
	for i in range(modes.size()):
		var button = Button.new()
		button.text = modes[i]
		button.toggle_mode = true
		button.button_pressed = (i == 0)
		button.pressed.connect(_on_overflow_button_pressed.bind(i))
		overflow_buttons.add_child(button)
func _setup_hand_area_background() -> void:
	var hand_area = $UI/HandArea as PanelContainer
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.13, 0.16, 1.0)
	style.border_width_top = 2
	style.border_color = Color(0.3, 0.3, 0.4, 1.0)
	hand_area.add_theme_stylebox_override("panel", style)
	# Do NOT clip - cards need to pop up above the hand area on hover
	hand_area.clip_contents = false

func _setup_action_buttons() -> void:
	var ui = $UI as CanvasLayer

	var btn_container = Control.new()
	btn_container.name = "ActionButtonContainer"
	ui.add_child(btn_container)
	btn_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	btn_container.offset_left = 8.0
	btn_container.offset_top = -124.0
	btn_container.offset_right = 140.0
	btn_container.offset_bottom = -8.0

	var vbox = VBoxContainer.new()
	vbox.name = "ActionButtons"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_theme_constant_override("separation", 4)
	btn_container.add_child(vbox)

	# Attack button (top)
	var attack_btn = Button.new()
	attack_btn.name = "AttackButton"
	attack_btn.text = "Attack (5T)"
	attack_btn.custom_minimum_size = Vector2(130, 36)
	attack_btn.tooltip_text = "Basic melee attack: STR modifier damage. Costs 5 tempo."
	attack_btn.pressed.connect(_on_attack_pressed)
	vbox.add_child(attack_btn)

	# Block button (middle, only visible if shield equipped)
	_block_button = Button.new()
	_block_button.name = "BlockButton"
	_block_button.text = "Block (5T)"
	_block_button.custom_minimum_size = Vector2(130, 36)
	_block_button.tooltip_text = "Raise shield to block. Costs 5 tempo."
	_block_button.pressed.connect(_on_block_pressed)
	_block_button.visible = false
	vbox.add_child(_block_button)

	# Wait button (bottom)
	var wait_btn = Button.new()
	wait_btn.name = "WaitButton"
	wait_btn.text = "Wait (+1 Tempo)"
	wait_btn.custom_minimum_size = Vector2(130, 36)
	wait_btn.tooltip_text = "Advance the tempo clock by 1 without playing a card"
	wait_btn.pressed.connect(_on_wait_pressed)
	vbox.add_child(wait_btn)

func _setup_battle_log() -> void:
	var ui = $UI as CanvasLayer

	# Outer container to hold toggle button + log panel vertically
	var outer = VBoxContainer.new()
	outer.name = "BattleLogOuter"
	ui.add_child(outer)
	outer.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	outer.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	outer.offset_left = -200.0
	outer.offset_top = -120.0
	outer.offset_right = -8.0
	outer.offset_bottom = 120.0
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Minimize / expand toggle button
	_battle_log_toggle_btn = Button.new()
	_battle_log_toggle_btn.name = "BattleLogToggle"
	_battle_log_toggle_btn.text = "_ Log"
	_battle_log_toggle_btn.custom_minimum_size = Vector2(60, 22)
	_battle_log_toggle_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_battle_log_toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.12, 0.12, 0.18, 0.9)
	btn_style.border_color = Color(0.3, 0.3, 0.45, 0.6)
	btn_style.border_width_bottom = 1
	btn_style.border_width_top = 1
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.corner_radius_top_left = 3
	btn_style.corner_radius_top_right = 3
	btn_style.corner_radius_bottom_left = 0
	btn_style.corner_radius_bottom_right = 0
	_battle_log_toggle_btn.add_theme_stylebox_override("normal", btn_style)
	_battle_log_toggle_btn.add_theme_font_size_override("font_size", 11)
	_battle_log_toggle_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_battle_log_toggle_btn.pressed.connect(_on_battle_log_toggle)
	outer.add_child(_battle_log_toggle_btn)

	battle_log_panel = PanelContainer.new()
	battle_log_panel.name = "BattleLogPanel"
	battle_log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(battle_log_panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.85)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.45, 0.6)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	battle_log_panel.add_theme_stylebox_override("panel", style)

	battle_log_label = RichTextLabel.new()
	battle_log_label.name = "BattleLogLabel"
	battle_log_label.bbcode_enabled = true
	battle_log_label.scroll_following = true
	battle_log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_log_label.add_theme_font_size_override("normal_font_size", 13)
	battle_log_label.add_theme_color_override("default_color", Color(0.8, 0.8, 0.85))
	battle_log_panel.add_child(battle_log_label)

func _on_battle_log_toggle() -> void:
	_battle_log_minimized = not _battle_log_minimized
	battle_log_panel.visible = not _battle_log_minimized
	if _battle_log_minimized:
		_battle_log_toggle_btn.text = "+ Log"
	else:
		_battle_log_toggle_btn.text = "_ Log"

func add_battle_log(msg: String, color: Color = Color(0.8, 0.8, 0.85)) -> void:
	if not battle_log_label:
		return
	var hex = color.to_html(false)
	battle_log_label.append_text("[color=#%s]%s[/color]\n" % [hex, msg])
	# Trim old lines
	if battle_log_label.get_parsed_text().count("\n") > BATTLE_LOG_MAX_LINES:
		var text = battle_log_label.get_parsed_text()
		var lines = text.split("\n")
		if lines.size() > BATTLE_LOG_MAX_LINES:
			battle_log_label.clear()
			for i in range(lines.size() - BATTLE_LOG_MAX_LINES, lines.size()):
				battle_log_label.append_text(lines[i] + "\n")

func _on_attack_pressed() -> void:
	var stats = player.get_stats()
	if not stats:
		return

	var debuff_mgr = player.get_debuff_manager()
	if debuff_mgr:
		if not debuff_mgr.can_play_cards():
			add_battle_log("Cannot attack — Stunned or Frozen!", Color(1.0, 0.4, 0.4))
			print("[MAIN] Basic Attack - Cannot attack while Stunned or Frozen!")
			return
		if not debuff_mgr.can_play_attack_cards():
			add_battle_log("Cannot attack — Disarmed!", Color(1.0, 0.4, 0.4))
			print("[MAIN] Basic Attack - Cannot attack while Disarmed!")
			return

	# Find closest enemy in melee range (~1.5 tiles)
	var nearby = enemy_spawner.get_enemies_in_radius(player.position, 1.5)
	if nearby.is_empty():
		add_battle_log("No enemy in melee range!", Color(1.0, 0.6, 0.3))
		print("[MAIN] Basic Attack - No enemy in melee range!")
		return

	var target = nearby[0]
	var closest_dist = INF
	for enemy in nearby:
		var diff = player.position - enemy.position
		var dist = Vector3(diff.x, 0, diff.z).length()
		if dist < closest_dist:
			closest_dist = dist
			target = enemy

	# Damage: 0 base + strength modifier
	var damage = stats.get_effective_physical_damage(0)

	var buff_mgr = player.get_buff_manager()
	if buff_mgr:
		damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			damage = floori(damage * 2.0)
			buff_mgr.consume_enlightened()

	# Debuff damage reduction
	if debuff_mgr:
		var reduction = debuff_mgr.get_damage_reduction_percent()
		if reduction > 0.0:
			damage = max(1, floori(damage * (1.0 - reduction)))

	target.take_damage(damage, true)

	# Register attack for DEX proc counter
	stats.register_attack()

	if debuff_mgr:
		debuff_mgr.on_attack()

	# Tempo cost
	var tempo_cost = 5
	if debuff_mgr:
		tempo_cost += debuff_mgr.get_tempo_increase()

	if buff_mgr and buff_mgr.consume_steady():
		print("[MAIN] Steady! No tempo added for basic attack.")
	else:
		tempo_manager.add_tempo(tempo_cost)

	add_battle_log("Basic Attack: %d damage to %s" % [damage, target.enemy_name], Color(0.4, 1.0, 0.5))
	print("[MAIN] Basic Attack: dealt %d damage to %s (%d tempo)" % [damage, target.enemy_name, tempo_cost])

func _on_block_pressed() -> void:
	var stats = player.get_stats()
	if not stats:
		return

	var debuff_mgr = player.get_debuff_manager()
	if debuff_mgr and not debuff_mgr.can_play_cards():
		print("[MAIN] Basic Block - Cannot block while Stunned or Frozen!")
		return

	var inventory = player.get_inventory()
	if not inventory:
		return

	var shield = inventory.get_equipped_shield()
	if not shield:
		print("[MAIN] Basic Block - No shield equipped!")
		return

	var block_amount = shield.armor_bonus
	if block_amount <= 0:
		block_amount = 3  # Fallback for shields without armor_bonus

	stats.add_armor(block_amount)

	var tempo_cost = 5
	if debuff_mgr:
		tempo_cost += debuff_mgr.get_tempo_increase()

	tempo_manager.add_tempo(tempo_cost)

	print("[MAIN] Basic Block: gained %d armor from %s (%d tempo)" % [block_amount, shield.item_name, tempo_cost])

func _on_wait_pressed() -> void:
	print("[MAIN] Wait - advancing tempo by 1")
	tempo_manager.add_tempo(1)

func _update_block_button_visibility() -> void:
	if not _block_button:
		return
	var inventory = player.get_inventory()
	if inventory and inventory.has_shield_equipped():
		var shield = inventory.get_equipped_shield()
		var block_val = shield.armor_bonus if shield.armor_bonus > 0 else 3
		_block_button.text = "Block (5T)"
		_block_button.tooltip_text = "Raise %s: +%d Armor. Costs 5 tempo." % [shield.item_name, block_val]
		_block_button.visible = true
	else:
		_block_button.visible = false

func _setup_deck_list_button() -> void:
	var hand_area = $UI/HandArea as PanelContainer
	var deck_btn = Button.new()
	deck_btn.name = "DeckListButton"
	deck_btn.text = "Deck"
	deck_btn.custom_minimum_size = Vector2(50, 30)
	deck_btn.pressed.connect(_on_deck_list_button_pressed)
	# Place button to the right of the hand area
	var ui = $UI as CanvasLayer
	var btn_container = Control.new()
	btn_container.name = "DeckButtonContainer"
	ui.add_child(btn_container)
	btn_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_container.offset_left = -95.0
	btn_container.offset_top = -40.0
	btn_container.offset_right = -5.0
	btn_container.offset_bottom = -5.0
	btn_container.add_child(deck_btn)
	deck_btn.set_anchors_preset(Control.PRESET_FULL_RECT)

func _setup_deck_list_panel() -> void:
	var ui = $UI as CanvasLayer
	# Main panel
	deck_list_panel = PanelContainer.new()
	deck_list_panel.name = "DeckListPanel"
	ui.add_child(deck_list_panel)
	deck_list_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	deck_list_panel.offset_left = -280.0
	deck_list_panel.offset_top = -250.0
	deck_list_panel.offset_right = -10.0
	deck_list_panel.offset_bottom = 250.0
	deck_list_panel.custom_minimum_size = Vector2(270, 400)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.4, 0.4, 0.5)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.content_margin_left = 10.0
	panel_style.content_margin_right = 10.0
	panel_style.content_margin_top = 10.0
	panel_style.content_margin_bottom = 10.0
	deck_list_panel.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.layout_mode = 1
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	deck_list_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "Deck Contents"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	vbox.add_child(title)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 350)
	vbox.add_child(scroll)

	deck_list_container = VBoxContainer.new()
	deck_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(deck_list_container)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_on_deck_list_button_pressed)
	vbox.add_child(close_btn)

	deck_list_panel.visible = false

	# Card preview popup (shown on hover over deck list entries)
	deck_list_card_preview = PanelContainer.new()
	deck_list_card_preview.name = "DeckListCardPreview"
	ui.add_child(deck_list_card_preview)
	deck_list_card_preview.custom_minimum_size = Vector2(180, 0)
	var preview_style = StyleBoxFlat.new()
	preview_style.bg_color = Color(0.15, 0.15, 0.2, 0.98)
	preview_style.border_width_left = 2
	preview_style.border_width_right = 2
	preview_style.border_width_top = 2
	preview_style.border_width_bottom = 2
	preview_style.border_color = Color(0.5, 0.5, 0.6)
	preview_style.corner_radius_top_left = 4
	preview_style.corner_radius_top_right = 4
	preview_style.corner_radius_bottom_left = 4
	preview_style.corner_radius_bottom_right = 4
	preview_style.content_margin_left = 8.0
	preview_style.content_margin_right = 8.0
	preview_style.content_margin_top = 8.0
	preview_style.content_margin_bottom = 8.0
	deck_list_card_preview.add_theme_stylebox_override("panel", preview_style)
	deck_list_card_preview.visible = false
	deck_list_card_preview.z_index = 200
	deck_list_card_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_deck_list_button_pressed() -> void:
	deck_list_visible = !deck_list_visible
	deck_list_panel.visible = deck_list_visible
	if deck_list_visible:
		_populate_deck_list()
	else:
		deck_list_card_preview.visible = false

func _populate_deck_list() -> void:
	# Clear existing entries
	for child in deck_list_container.get_children():
		child.queue_free()

	# Count cards across all piles
	var card_counts: Dictionary = {}
	var card_refs: Dictionary = {}  # Store a reference card for each name
	var all_cards: Array = []
	all_cards.append_array(deck_manager.draw_pile)
	all_cards.append_array(deck_manager.hand)
	all_cards.append_array(deck_manager.discard_pile)
	if deck_manager.has_method("get_jail_pile"):
		all_cards.append_array(deck_manager.jail_pile)
	else:
		all_cards.append_array(deck_manager.jail_pile)

	for card in all_cards:
		if card.card_name in card_counts:
			card_counts[card.card_name] += 1
		else:
			card_counts[card.card_name] = 1
			card_refs[card.card_name] = card

	# Sort by name
	var names = card_counts.keys()
	names.sort()

	for card_name in names:
		var count = card_counts[card_name]
		var card_ref = card_refs[card_name]
		var entry = Button.new()
		entry.text = "%s (%d)" % [card_name, count]
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.flat = true
		entry.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		entry.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.4))
		entry.add_theme_font_size_override("font_size", 14)
		entry.mouse_entered.connect(_on_deck_list_entry_hovered.bind(card_ref, entry))
		entry.mouse_exited.connect(_on_deck_list_entry_unhovered)
		deck_list_container.add_child(entry)

func _on_deck_list_entry_hovered(card: Card, entry: Button) -> void:
	# Clear previous preview content
	for child in deck_list_card_preview.get_children():
		child.queue_free()

	var vbox = VBoxContainer.new()
	deck_list_card_preview.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = card.card_name
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	vbox.add_child(name_lbl)

	var type_lbl = Label.new()
	type_lbl.text = card.card_type_name
	type_lbl.add_theme_font_size_override("font_size", 12)
	match card.card_type:
		Card.CardType.ATTACK:
			type_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		Card.CardType.DEFENSE:
			type_lbl.add_theme_color_override("font_color", Color(0.3, 0.5, 1))
		Card.CardType.UTILITY:
			type_lbl.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
	vbox.add_child(type_lbl)

	var cost_lbl = Label.new()
	cost_lbl.text = "Cost: %dM / %dT" % [card.mana_cost, card.tempo_cost]
	cost_lbl.add_theme_font_size_override("font_size", 12)
	cost_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	vbox.add_child(cost_lbl)

	if card.is_ranged:
		var range_lbl = Label.new()
		range_lbl.text = card.get_range_display()
		range_lbl.add_theme_font_size_override("font_size", 12)
		range_lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 0.9))
		vbox.add_child(range_lbl)
	else:
		var melee_lbl = Label.new()
		melee_lbl.text = "Melee"
		melee_lbl.add_theme_font_size_override("font_size", 12)
		melee_lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
		vbox.add_child(melee_lbl)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var desc_lbl = RichTextLabel.new()
	desc_lbl.bbcode_enabled = true
	desc_lbl.text = card.description
	desc_lbl.fit_content = true
	desc_lbl.scroll_active = false
	desc_lbl.custom_minimum_size = Vector2(160, 0)
	desc_lbl.add_theme_font_size_override("normal_font_size", 13)
	vbox.add_child(desc_lbl)

	if card.sticky > 0:
		var sticky_lbl = Label.new()
		sticky_lbl.text = "Sticky %d" % card.sticky
		sticky_lbl.add_theme_font_size_override("font_size", 12)
		sticky_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
		vbox.add_child(sticky_lbl)

	# Position preview to the left of the deck list panel, above the hand area
	var entry_rect = entry.get_global_rect()
	var preview_x = deck_list_panel.position.x - deck_list_card_preview.size.x - 10
	var preview_y = entry_rect.position.y

	# Clamp so the preview doesn't extend below the hand area
	var hand_area = $UI/HandArea as PanelContainer
	var max_y = hand_area.global_position.y - deck_list_card_preview.size.y - 8.0
	preview_y = min(preview_y, max_y)

	# Also clamp to top of screen
	preview_y = max(preview_y, 4.0)

	deck_list_card_preview.global_position = Vector2(preview_x, preview_y)
	deck_list_card_preview.visible = true

func _on_deck_list_entry_unhovered() -> void:
	deck_list_card_preview.visible = false

func _setup_hand_card_preview() -> void:
	var ui = $UI
	hand_card_preview = PanelContainer.new()
	hand_card_preview.name = "HandCardPreview"
	ui.add_child(hand_card_preview)
	hand_card_preview.custom_minimum_size = Vector2(200, 0)
	var preview_style = StyleBoxFlat.new()
	preview_style.bg_color = Color(0.15, 0.15, 0.2, 0.98)
	preview_style.border_width_left = 2
	preview_style.border_width_right = 2
	preview_style.border_width_top = 2
	preview_style.border_width_bottom = 2
	preview_style.border_color = Color(0.5, 0.5, 0.6)
	preview_style.corner_radius_top_left = 4
	preview_style.corner_radius_top_right = 4
	preview_style.corner_radius_bottom_left = 4
	preview_style.corner_radius_bottom_right = 4
	preview_style.content_margin_left = 10.0
	preview_style.content_margin_right = 10.0
	preview_style.content_margin_top = 10.0
	preview_style.content_margin_bottom = 10.0
	hand_card_preview.add_theme_stylebox_override("panel", preview_style)
	hand_card_preview.visible = false
	hand_card_preview.z_index = 200
	hand_card_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_hand_card_hovered(card: Card, card_ui: CardUI) -> void:
	_hand_hover_id += 1
	var my_hover_id = _hand_hover_id

	# Clear previous preview content
	for child in hand_card_preview.get_children():
		child.queue_free()

	var vbox = VBoxContainer.new()
	hand_card_preview.add_child(vbox)

	# Card name (gold)
	var name_lbl = Label.new()
	name_lbl.text = card.card_name
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	vbox.add_child(name_lbl)

	# Card type (color-coded)
	var type_lbl = Label.new()
	type_lbl.text = card.card_type_name
	type_lbl.add_theme_font_size_override("font_size", 12)
	match card.card_type:
		Card.CardType.ATTACK:
			type_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		Card.CardType.DEFENSE:
			type_lbl.add_theme_color_override("font_color", Color(0.3, 0.5, 1))
		Card.CardType.UTILITY:
			type_lbl.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
	vbox.add_child(type_lbl)

	# Cost
	var cost_lbl = Label.new()
	cost_lbl.text = "Cost: %dM / %dT" % [card.mana_cost, card.tempo_cost]
	cost_lbl.add_theme_font_size_override("font_size", 12)
	cost_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	vbox.add_child(cost_lbl)

	# Range/Melee
	if card.is_ranged:
		var range_lbl = Label.new()
		range_lbl.text = card.get_range_display()
		range_lbl.add_theme_font_size_override("font_size", 12)
		range_lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 0.9))
		vbox.add_child(range_lbl)
	else:
		var melee_lbl = Label.new()
		melee_lbl.text = "Melee"
		melee_lbl.add_theme_font_size_override("font_size", 12)
		melee_lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
		vbox.add_child(melee_lbl)

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Description
	var desc_lbl = RichTextLabel.new()
	desc_lbl.bbcode_enabled = true
	if card.rng_outcomes_data.size() > 0 and card.has_been_rolled():
		desc_lbl.text = card.get_colored_description()
	else:
		desc_lbl.text = card.description
	desc_lbl.fit_content = true
	desc_lbl.scroll_active = false
	desc_lbl.custom_minimum_size = Vector2(180, 0)
	desc_lbl.add_theme_font_size_override("normal_font_size", 13)
	vbox.add_child(desc_lbl)

	# Sticky indicator
	if card.sticky > 0:
		var sticky_lbl = Label.new()
		sticky_lbl.text = "Sticky %d" % card.sticky
		sticky_lbl.add_theme_font_size_override("font_size", 12)
		sticky_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
		vbox.add_child(sticky_lbl)

	# Position popup above the hand area, centered on the hovered card
	var hand_area = $UI/HandArea as PanelContainer
	var card_global_rect = card_ui.get_global_rect()
	var card_center_x = card_global_rect.position.x + card_global_rect.size.x / 2.0

	# Wait a frame for the preview to calculate its size, then position
	await get_tree().process_frame

	# If hover changed while we waited, abort (fixes flickering when scrolling across cards)
	if my_hover_id != _hand_hover_id:
		return

	var preview_width = hand_card_preview.size.x
	var popup_x = card_center_x - preview_width / 2.0

	# Clamp to screen bounds
	var screen_width = get_viewport().get_visible_rect().size.x
	popup_x = clamp(popup_x, 4.0, screen_width - preview_width - 4.0)

	# Place above the hand area
	var popup_y = hand_area.global_position.y - hand_card_preview.size.y - 8.0
	hand_card_preview.global_position = Vector2(popup_x, popup_y)
	hand_card_preview.visible = true

func _on_hand_card_unhovered() -> void:
	_hand_hover_id += 1
	hand_card_preview.visible = false

func _setup_gauntlet_skills_ui() -> void:
	# Clear existing
	for child in gauntlet_skills_container.get_children():
		child.queue_free()
	
	var inventory = player.get_inventory()
	if not inventory:
		return
	
	var skills = inventory.get_available_gauntlet_skills()
	for gauntlet in skills:
		if gauntlet.gauntlet_skill_type == ItemData.GauntletSkillType.ACTIVE:
			var skill_ui = GauntletSkillUIScene.instantiate() as GauntletSkillUI
			gauntlet_skills_container.add_child(skill_ui)
			skill_ui.setup(gauntlet)
			skill_ui.skill_activated.connect(_on_gauntlet_skill_activated)

func _update_gauntlet_skills_ui() -> void:
	for child in gauntlet_skills_container.get_children():
		if child is GauntletSkillUI:
			child.update_display()

func _on_gauntlet_skill_activated(gauntlet: ItemData) -> void:
	var inventory = player.get_inventory()
	
	# For targeted skills, we need to select a target
	# For now, use closest enemy or require click
	var enemies = enemy_spawner.get_living_enemies()
	var target = enemies[0] if enemies.size() > 0 else null
	
	if inventory.use_gauntlet_skill(gauntlet, target):
		tempo_manager.add_tempo(1)  # Skills cost 1 tempo
		_update_gauntlet_skills_ui()

func _on_gauntlet_skill_ready(_gauntlet: ItemData) -> void:
	_update_gauntlet_skills_ui()

func _on_equipment_changed() -> void:
	_setup_gauntlet_skills_ui()
	_update_block_button_visibility()

func _setup_unit_tracker() -> void:
	var ui = $UI as CanvasLayer
	unit_tracker = UnitTrackerUI.new()
	unit_tracker.name = "UnitTracker"
	ui.add_child(unit_tracker)
	unit_tracker.initialize(enemy_spawner)

	# Anchor to left side, vertically centered
	unit_tracker.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	unit_tracker.offset_left = 8.0
	unit_tracker.offset_top = -200.0
	unit_tracker.offset_right = 250.0
	unit_tracker.offset_bottom = 200.0

	# Connect hover signals for bidirectional highlighting
	unit_tracker.enemy_hovered.connect(_on_tracker_enemy_hovered)
	unit_tracker.enemy_unhovered.connect(_on_tracker_enemy_unhovered)

var _battlefield_hovered_enemy: Enemy = null

func _on_tracker_enemy_hovered(enemy: Enemy) -> void:
	## Panel portrait hovered → highlight enemy on battlefield
	if is_instance_valid(enemy):
		# Clear previous battlefield hover so it doesn't conflict
		if _prev_battlefield_hover and _prev_battlefield_hover != enemy and is_instance_valid(_prev_battlefield_hover):
			_set_enemy_highlight(_prev_battlefield_hover, false)
		_set_enemy_highlight(enemy, true)

func _on_tracker_enemy_unhovered() -> void:
	## Panel portrait unhovered → clear battlefield highlight
	if _battlefield_hovered_enemy and is_instance_valid(_battlefield_hovered_enemy):
		_set_enemy_highlight(_battlefield_hovered_enemy, false)
		_battlefield_hovered_enemy = null
	# Clear all highlights
	for enemy in enemy_spawner.get_living_enemies():
		_set_enemy_highlight(enemy, false)

func _set_enemy_highlight(enemy: Enemy, highlighted: bool) -> void:
	## Toggle a bright highlight outline on a battlefield enemy.
	if not enemy or not is_instance_valid(enemy):
		return
	if not enemy.outline:
		return
	var mat = enemy.outline.get_surface_override_material(0) as StandardMaterial3D
	if not mat:
		return
	if highlighted:
		enemy.outline.visible = true
		mat.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
		_battlefield_hovered_enemy = enemy
	else:
		# Restore original outline state
		enemy.update_outline()

func _refresh_unit_tracker() -> void:
	if unit_tracker:
		unit_tracker.refresh()

func select_character(character: CharacterData) -> void:
	current_character = character
	
	player.initialize_character(character)
	deck_manager.connect_player_stats(player.get_stats())

	debuff_bar.connect_manager(player.get_debuff_manager())
	deck_manager.connect_inventory(player.get_inventory())
	player.connect_deck_to_inventory(deck_manager)
	tempo_manager.initialize(player.get_stats())
	update_tempo_display()
	turn_manager.initialize(player.get_stats(), deck_manager)
	overflow_manager.initialize(player.get_stats())
	deck_manager.connect_overflow_manager(overflow_manager)
	buff_bar.connect_manager(player.get_buff_manager())
	manifest_ui.connect_overflow_manager(overflow_manager)
	overflow_ui.connect_overflow_manager(overflow_manager)
	quiver_ui.connect_overflow_manager(overflow_manager)
	player.get_stats().health_changed.connect(_on_player_health_changed)
	player.get_stats().mana_changed.connect(_on_player_mana_changed)
	player.get_stats().armor_changed.connect(_on_player_armor_changed)
	player.get_stats().dexterity_proc.connect(_on_dexterity_proc)
	player.get_stats().damage_taken.connect(_on_player_damage_taken)
	deck_manager.on_draw_triggered.connect(_on_card_on_draw_triggered)
	
	character_panel.connect_stats(player.get_stats(), player.get_inventory())


	deck_manager.initialize_deck(character)
	player.get_inventory().apply_starting_item_card_effects()
	_setup_gauntlet_skills_ui()
	# Connect gauntlet cooldown signal so UI updates when skills come off cooldown
	var inventory = player.get_inventory()
	if inventory and not inventory.gauntlet_skill_ready.is_connected(_on_gauntlet_skill_ready):
		inventory.gauntlet_skill_ready.connect(_on_gauntlet_skill_ready)
	# Rebuild gauntlet skill UI whenever equipment changes (e.g. equipping from side panel)
	if inventory and not inventory.equipment_changed.is_connected(_on_equipment_changed):
		inventory.equipment_changed.connect(_on_equipment_changed)
	_on_hand_updated()
	update_deck_info()
	update_selected_display()
	update_peaked_display()
	update_turn_display()
	_on_player_health_changed(player.get_stats().current_health, player.get_stats().max_health)
	_on_player_mana_changed(player.get_stats().current_mana, player.get_stats().max_mana)
	_on_player_armor_changed(player.get_stats().current_armor)
	_update_block_button_visibility()

	# XP / Leveling
	player.get_stats().leveled_up.connect(_on_player_leveled_up)
	player.get_stats().xp_changed.connect(_on_player_xp_changed)
	_update_xp_display()

	# Give starting spheres (level 1 rewards)
	var starting_rewards = SphereInventory.get_level_rewards(1)
	for reward in starting_rewards:
		sphere_inventory.add_sphere(reward[0], reward[1])
	print("[MAIN] Granted starting spheres for level 1")

	print("[MAIN] Selected character: %s" % character.character_name)

# ============================================
# PLAYER 2 MULTIPLAYER SUPPORT
# ============================================

func _initialize_player2() -> void:
	# Create a separate DeckManager for P2
	_p2_deck_manager = DeckManager.new()
	_p2_deck_manager.name = "P2DeckManager"
	add_child(_p2_deck_manager)
	_p2_deck_manager.initialize_deck(player2_character)
	print("[MAIN] Player 2 initialized: %s (hand: %d cards)" % [player2_character.character_name, _p2_deck_manager.hand.size()])

	_setup_p2_buttons()
	_setup_p2_hand_panel()
	_setup_p2_deck_panel()

func _setup_p2_buttons() -> void:
	var ui = $UI as CanvasLayer
	var btn_container = Control.new()
	btn_container.name = "P2ButtonContainer"
	ui.add_child(btn_container)
	btn_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_container.offset_left = -95.0
	btn_container.offset_top = -110.0
	btn_container.offset_right = -5.0
	btn_container.offset_bottom = -45.0

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	btn_container.add_child(vbox)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)

	var hand_btn = Button.new()
	hand_btn.name = "P2HandButton"
	hand_btn.text = "P2 Hand"
	hand_btn.custom_minimum_size = Vector2(80, 28)
	hand_btn.pressed.connect(_on_p2_hand_button_pressed)
	vbox.add_child(hand_btn)

	var deck_btn = Button.new()
	deck_btn.name = "P2DeckButton"
	deck_btn.text = "P2 Deck"
	deck_btn.custom_minimum_size = Vector2(80, 28)
	deck_btn.pressed.connect(_on_p2_deck_button_pressed)
	vbox.add_child(deck_btn)

func _setup_p2_hand_panel() -> void:
	var ui = $UI as CanvasLayer

	_p2_hand_panel = PanelContainer.new()
	_p2_hand_panel.name = "P2HandPanel"
	ui.add_child(_p2_hand_panel)
	_p2_hand_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_p2_hand_panel.offset_left = -280.0
	_p2_hand_panel.offset_top = -250.0
	_p2_hand_panel.offset_right = -10.0
	_p2_hand_panel.offset_bottom = 250.0
	_p2_hand_panel.custom_minimum_size = Vector2(270, 400)
	_p2_hand_panel.add_theme_stylebox_override("panel", _make_p2_panel_style())

	var margin = MarginContainer.new()
	margin.layout_mode = 1
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_p2_hand_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "Player 2 Hand"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
	vbox.add_child(title)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 350)
	vbox.add_child(scroll)

	_p2_hand_container = VBoxContainer.new()
	_p2_hand_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_p2_hand_container)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_on_p2_hand_button_pressed)
	vbox.add_child(close_btn)

	_p2_hand_panel.visible = false

	# Card preview for P2 hand hover
	_p2_hand_card_preview = _make_p2_card_preview("P2HandCardPreview")
	ui.add_child(_p2_hand_card_preview)

func _setup_p2_deck_panel() -> void:
	var ui = $UI as CanvasLayer

	_p2_deck_panel = PanelContainer.new()
	_p2_deck_panel.name = "P2DeckPanel"
	ui.add_child(_p2_deck_panel)
	_p2_deck_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_p2_deck_panel.offset_left = -280.0
	_p2_deck_panel.offset_top = -250.0
	_p2_deck_panel.offset_right = -10.0
	_p2_deck_panel.offset_bottom = 250.0
	_p2_deck_panel.custom_minimum_size = Vector2(270, 400)
	_p2_deck_panel.add_theme_stylebox_override("panel", _make_p2_panel_style())

	var margin = MarginContainer.new()
	margin.layout_mode = 1
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_p2_deck_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "Player 2 Deck"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
	vbox.add_child(title)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 350)
	vbox.add_child(scroll)

	_p2_deck_container = VBoxContainer.new()
	_p2_deck_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_p2_deck_container)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_on_p2_deck_button_pressed)
	vbox.add_child(close_btn)

	_p2_deck_panel.visible = false

	# Card preview for P2 deck hover
	_p2_deck_card_preview = _make_p2_card_preview("P2DeckCardPreview")
	ui.add_child(_p2_deck_card_preview)

func _make_p2_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.08, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.35, 0.3)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style

func _make_p2_card_preview(preview_name: String) -> PanelContainer:
	var preview = PanelContainer.new()
	preview.name = preview_name
	preview.custom_minimum_size = Vector2(180, 0)
	var preview_style = StyleBoxFlat.new()
	preview_style.bg_color = Color(0.15, 0.12, 0.12, 0.98)
	preview_style.border_width_left = 2
	preview_style.border_width_right = 2
	preview_style.border_width_top = 2
	preview_style.border_width_bottom = 2
	preview_style.border_color = Color(0.5, 0.4, 0.35)
	preview_style.corner_radius_top_left = 4
	preview_style.corner_radius_top_right = 4
	preview_style.corner_radius_bottom_left = 4
	preview_style.corner_radius_bottom_right = 4
	preview_style.content_margin_left = 8.0
	preview_style.content_margin_right = 8.0
	preview_style.content_margin_top = 8.0
	preview_style.content_margin_bottom = 8.0
	preview.add_theme_stylebox_override("panel", preview_style)
	preview.visible = false
	preview.z_index = 200
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return preview

func _on_p2_hand_button_pressed() -> void:
	_p2_hand_visible = !_p2_hand_visible
	_p2_hand_panel.visible = _p2_hand_visible
	if _p2_hand_visible:
		# Hide other panels
		if _p2_deck_visible:
			_p2_deck_visible = false
			_p2_deck_panel.visible = false
			_p2_deck_card_preview.visible = false
		if deck_list_visible:
			deck_list_visible = false
			deck_list_panel.visible = false
			deck_list_card_preview.visible = false
		_populate_p2_hand()
	else:
		_p2_hand_card_preview.visible = false

func _on_p2_deck_button_pressed() -> void:
	_p2_deck_visible = !_p2_deck_visible
	_p2_deck_panel.visible = _p2_deck_visible
	if _p2_deck_visible:
		# Hide other panels
		if _p2_hand_visible:
			_p2_hand_visible = false
			_p2_hand_panel.visible = false
			_p2_hand_card_preview.visible = false
		if deck_list_visible:
			deck_list_visible = false
			deck_list_panel.visible = false
			deck_list_card_preview.visible = false
		_populate_p2_deck()
	else:
		_p2_deck_card_preview.visible = false

func _populate_p2_hand() -> void:
	for child in _p2_hand_container.get_children():
		child.queue_free()

	if not _p2_deck_manager:
		return

	for i in range(_p2_deck_manager.hand.size()):
		var card = _p2_deck_manager.hand[i]
		var entry = Button.new()
		entry.text = "%s (%dM / %dT)" % [card.card_name, card.mana_cost, card.tempo_cost]
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.flat = true
		entry.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		entry.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.4))
		entry.add_theme_font_size_override("font_size", 14)
		entry.mouse_entered.connect(_on_p2_hand_entry_hovered.bind(card, entry))
		entry.mouse_exited.connect(_on_p2_hand_entry_unhovered)
		_p2_hand_container.add_child(entry)

func _populate_p2_deck() -> void:
	for child in _p2_deck_container.get_children():
		child.queue_free()

	if not _p2_deck_manager:
		return

	# Count cards across all piles
	var card_counts: Dictionary = {}
	var card_refs: Dictionary = {}
	var all_cards: Array = []
	all_cards.append_array(_p2_deck_manager.draw_pile)
	all_cards.append_array(_p2_deck_manager.hand)
	all_cards.append_array(_p2_deck_manager.discard_pile)
	all_cards.append_array(_p2_deck_manager.jail_pile)

	for card in all_cards:
		if card.card_name in card_counts:
			card_counts[card.card_name] += 1
		else:
			card_counts[card.card_name] = 1
			card_refs[card.card_name] = card

	var names = card_counts.keys()
	names.sort()

	for card_name in names:
		var count = card_counts[card_name]
		var card_ref = card_refs[card_name]
		var entry = Button.new()
		entry.text = "%s (%d)" % [card_name, count]
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.flat = true
		entry.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		entry.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.4))
		entry.add_theme_font_size_override("font_size", 14)
		entry.mouse_entered.connect(_on_p2_deck_entry_hovered.bind(card_ref, entry))
		entry.mouse_exited.connect(_on_p2_deck_entry_unhovered)
		_p2_deck_container.add_child(entry)

func _build_p2_card_preview_content(card: Card, preview: PanelContainer) -> void:
	for child in preview.get_children():
		child.queue_free()

	var vbox = VBoxContainer.new()
	preview.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = card.card_name
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	vbox.add_child(name_lbl)

	var type_lbl = Label.new()
	type_lbl.text = card.card_type_name
	type_lbl.add_theme_font_size_override("font_size", 12)
	match card.card_type:
		Card.CardType.ATTACK:
			type_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		Card.CardType.DEFENSE:
			type_lbl.add_theme_color_override("font_color", Color(0.3, 0.5, 1))
		Card.CardType.UTILITY:
			type_lbl.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
	vbox.add_child(type_lbl)

	var cost_lbl = Label.new()
	cost_lbl.text = "Cost: %dM / %dT" % [card.mana_cost, card.tempo_cost]
	cost_lbl.add_theme_font_size_override("font_size", 12)
	cost_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	vbox.add_child(cost_lbl)

	if card.is_ranged:
		var range_lbl = Label.new()
		range_lbl.text = card.get_range_display()
		range_lbl.add_theme_font_size_override("font_size", 12)
		range_lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 0.9))
		vbox.add_child(range_lbl)
	else:
		var melee_lbl = Label.new()
		melee_lbl.text = "Melee"
		melee_lbl.add_theme_font_size_override("font_size", 12)
		melee_lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
		vbox.add_child(melee_lbl)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var desc_lbl = RichTextLabel.new()
	desc_lbl.bbcode_enabled = true
	desc_lbl.text = card.description
	desc_lbl.fit_content = true
	desc_lbl.scroll_active = false
	desc_lbl.custom_minimum_size = Vector2(160, 0)
	desc_lbl.add_theme_font_size_override("normal_font_size", 13)
	vbox.add_child(desc_lbl)

func _position_p2_preview(preview: PanelContainer, panel: PanelContainer, entry: Button) -> void:
	var entry_rect = entry.get_global_rect()
	var preview_x = panel.position.x - preview.size.x - 10
	var preview_y = entry_rect.position.y
	var hand_area = $UI/HandArea as PanelContainer
	var max_y = hand_area.global_position.y - preview.size.y - 8.0
	preview_y = min(preview_y, max_y)
	preview_y = max(preview_y, 4.0)
	preview.global_position = Vector2(preview_x, preview_y)
	preview.visible = true

func _on_p2_hand_entry_hovered(card: Card, entry: Button) -> void:
	_build_p2_card_preview_content(card, _p2_hand_card_preview)
	_position_p2_preview(_p2_hand_card_preview, _p2_hand_panel, entry)

func _on_p2_hand_entry_unhovered() -> void:
	_p2_hand_card_preview.visible = false

func _on_p2_deck_entry_hovered(card: Card, entry: Button) -> void:
	_build_p2_card_preview_content(card, _p2_deck_card_preview)
	_position_p2_preview(_p2_deck_card_preview, _p2_deck_panel, entry)

func _on_p2_deck_entry_unhovered() -> void:
	_p2_deck_card_preview.visible = false

func trigger_turn() -> void:
	# Simulate one full tempo cycle (5 global tempo) for testing
	tempo_manager.add_tempo(5)

func trigger_multiple_turns(count: int) -> void:
	# Each "turn" = 5 global tempo (one cycle)
	tempo_manager.add_tempo(5 * count)

func _on_player_tile_reached() -> void:
	# Tempo accumulates per tile in real time
	tempo_manager.add_movement_tempo()

func _on_player_move_completed() -> void:
	pass

func _on_move_confirmed(target_pos: Vector3, spaces: int) -> void:
	var debuff_mgr = player.get_debuff_manager()
	
	# Check Tethered range
	if debuff_mgr and debuff_mgr.is_tethered():
		if not debuff_mgr.is_within_tether_range(target_pos, grid_manager.grid_size):
			print("[MAIN] Cannot move - Tethered! Out of range.")
			return
	
	player.move_to_grid(target_pos, spaces)

func _on_move_cancelled() -> void:
	print("[INPUT] Movement cancelled")

## Fires on every global tempo addition - routes to per-system handlers.
func _on_tempo_advanced(global_total: int, amount: int) -> void:
	# Each enemy manages its own action counter independently
	enemy_spawner.on_tempo_advanced(amount)

	# Mana regen on the player's own tempo interval
	var stats = player.get_stats()
	if stats:
		stats.process_tempo(amount)

	# Card draw is tracked by turn_manager against its own tempo interval
	turn_manager.process_tempo(amount)

	# Process pillar durations
	_process_pillars(amount)

	# Check if invisibility expired and restore player opacity
	var buff_mgr = player.get_buff_manager()
	if buff_mgr and not buff_mgr.is_invisible():
		var mesh_node = player.mesh
		if mesh_node:
			var mat = mesh_node.get_surface_override_material(0) as StandardMaterial3D
			if mat and mat.albedo_color.a < 1.0:
				_set_player_invisible(false)

	update_turn_display()
	_refresh_unit_tracker()

func _on_enemy_killed(enemy: Enemy) -> void:
	print("[MAIN] Enemy killed: %s (XP: %d)" % [enemy.enemy_name, enemy.xp_reward])
	player.get_stats().gain_xp(enemy.xp_reward)
	_update_enemy_count()
	_refresh_unit_tracker()

func _on_all_enemies_defeated() -> void:
	print("[MAIN] Wave complete! Press 'Spawn Wave' for more enemies.")
	_refresh_unit_tracker()

func _on_player_leveled_up(new_level: int) -> void:
	print("[MAIN] *** LEVEL UP to %d! ***" % new_level)
	# Grant sphere rewards for this level
	var rewards = SphereInventory.get_level_rewards(new_level)
	for reward in rewards:
		sphere_inventory.add_sphere(reward[0], reward[1])
	print("[MAIN] Granted level %d sphere rewards" % new_level)

	# Force-refresh health and mana UI to guarantee display shows full restore
	var stats = player.get_stats()
	if stats:
		_on_player_health_changed(stats.current_health, stats.max_health)
		_on_player_mana_changed(stats.current_mana, stats.max_mana)
		_update_xp_display()

func _on_player_xp_changed(current_xp: int, xp_to_next: int) -> void:
	_update_xp_display()

func _update_enemy_count() -> void:
	test_ui.update_enemy_count(enemy_spawner.get_enemy_count())

func _on_turn_ended(turn_number: int) -> void:
	update_deck_info()

func _on_player_health_changed(current: int, max_hp: int) -> void:
	if player_health_label:
		player_health_label.text = "HP: %d / %d" % [current, max_hp]

func _on_player_mana_changed(current: float, max_mana: int) -> void:
	if player_mana_label:
		player_mana_label.text = "Mana: %d / %d" % [int(current), max_mana]

func _on_player_armor_changed(current: int) -> void:
	if player_armor_label:
		player_armor_label.text = "Armor: %d" % current

func _update_xp_display() -> void:
	if player_xp_label:
		var stats = player.get_stats()
		player_xp_label.text = "Lv %d | XP: %d/%d" % [stats.current_level, stats.current_xp, stats.get_xp_to_next_level()]

func _on_dexterity_proc() -> void:
	print("[MAIN] Dexterity proc! Next attack is free + 2 mana discount!")
	deck_manager.apply_dex_proc_bonus()

func update_turn_display() -> void:
	if turn_label:
		turn_label.text = "Global Tempo: %d | Draw in: %.0f | Atk Sp proc: %d" % [
			tempo_manager.get_global_tempo(),
			turn_manager.get_tempo_until_draw(),
			player.get_stats().get_attacks_until_proc()
		]

func _on_overflow_button_pressed(mode_index: int) -> void:
	for i in range(overflow_buttons.get_child_count()):
		var button = overflow_buttons.get_child(i) as Button
		button.button_pressed = (i == mode_index)
	
	deck_manager.set_overflow_mode(mode_index as DeckManager.OverflowMode)
	update_peaked_display()

func _on_hand_updated() -> void:
	if hand_card_preview:
		hand_card_preview.visible = false
	_card_ui_instances.clear()
	_current_hand_hover_index = -1
	for child in hand_container.get_children():
		child.queue_free()

	var debuff_mgr = player.get_debuff_manager()

	# Assign Hexed/Locked cards if needed
	deck_manager.assign_hexed_locked_cards(debuff_mgr)

	# Roll RNG for cards that haven't been rolled yet
	var enemies = enemy_spawner.get_living_enemies()
	var chance_boost = player.get_stats().chance_boost
	for card in deck_manager.hand:
		if card.has_chance_effect() and not card.has_been_rolled():
			card.roll_rng(enemies, chance_boost)
			card.rng_roll_tempo = tempo_manager.global_tempo

	var hand_size = deck_manager.hand.size()
	if hand_size == 0:
		if selected_card_index >= 0:
			selected_card_index = -1
		update_deck_info()
		update_selected_display()
		update_card_highlights()
		return

	var card_width: float = 120.0
	var card_height: float = 160.0
	var container_width: float = hand_container.size.x
	if container_width <= 0:
		container_width = 1080.0  # fallback

	# Calculate spacing: fit all cards proportionally within the container
	# If cards would fit without overlap, space them evenly
	# If not, overlap them so they all fit
	var total_cards_width = card_width * hand_size
	var spacing: float
	if total_cards_width <= container_width:
		# Cards fit - distribute evenly across the space
		if hand_size == 1:
			spacing = 0.0
		else:
			spacing = (container_width - card_width) / (hand_size - 1)
		# Cap spacing so cards don't spread too far apart
		spacing = min(spacing, card_width + 8.0)
	else:
		# Cards overlap - shrink spacing to fit
		spacing = (container_width - card_width) / max(hand_size - 1, 1)

	# Center the hand within the container
	var total_hand_width = card_width + spacing * max(hand_size - 1, 0)
	var start_x = (container_width - total_hand_width) / 2.0
	var card_y = (hand_container.size.y - card_height) / 2.0
	if card_y < 0:
		card_y = 0.0

	for i in range(hand_size):
		var card_ui = CardUIScene.instantiate()
		hand_container.add_child(card_ui)
		card_ui.setup(deck_manager.hand[i], i, debuff_mgr)
		card_ui.position = Vector2(start_x + i * spacing, card_y)
		card_ui.z_index = i
		card_ui.store_base_position()
		# Disable per-card mouse detection; position-based hover in _process handles it
		card_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_card_ui_instances.append(card_ui)

	if selected_card_index >= deck_manager.hand.size():
		selected_card_index = -1

	update_deck_info()
	update_selected_display()
	update_card_highlights()

func _on_card_discarded(card: Card) -> void:
	# Volatile Mixture: deal damage to a random nearby enemy when discarded
	if card.card_id == "volatile_mixture":
		var stats = player.get_stats()
		var total_damage = card.damage
		if stats:
			total_damage = stats.get_effective_spell_damage(card.damage)
		var nearby = enemy_spawner.get_enemies_in_radius(player.position, 5.0)
		if nearby.size() > 0:
			var target_enemy = nearby[randi() % nearby.size()]
			target_enemy.take_damage(total_damage, true)
			print("[MAIN] Volatile Mixture discarded! Dealt %d damage to %s" % [total_damage, target_enemy.enemy_name])
		else:
			print("[MAIN] Volatile Mixture discarded! No enemies nearby to damage")

func _on_deck_shuffled() -> void:
	update_deck_info()

func _on_card_peaked(card: Card) -> void:
	update_peaked_display()

func _on_overflow_triggered(mode: String, card: Card) -> void:
	update_deck_info()
	update_peaked_display()

func _on_apply_debuff(debuff_name: String) -> void:
	var debuff_mgr = player.get_debuff_manager()
	var debuff: Debuff = null
	
	match debuff_name:
		# Original debuffs
		"Bleed (3)": debuff = Debuff.create(Debuff.DebuffType.BLEED, 3, 3)
		"Stun": debuff = Debuff.create(Debuff.DebuffType.STUN, 0, 1)
		"Disarm": debuff = Debuff.create(Debuff.DebuffType.DISARM, 0, 3)
		"Silence": debuff = Debuff.create(Debuff.DebuffType.SILENCE, 0, 3)
		"Burn (2)": debuff = Debuff.create(Debuff.DebuffType.BURN, 2, 3)
		"Poison (2)": debuff = Debuff.create(Debuff.DebuffType.POISON, 2, 3)
		"Inebriate": debuff = Debuff.create(Debuff.DebuffType.INEBRIATE, 0, 3)
		"Cursed (2)": debuff = Debuff.create(Debuff.DebuffType.CURSED, 2, 3)
		"Frozen": debuff = Debuff.create(Debuff.DebuffType.FROZEN, 0, 2)
		"Cuffed": debuff = Debuff.create(Debuff.DebuffType.CUFFED, 0, 3)
		"Shocked (3)": debuff = Debuff.create(Debuff.DebuffType.SHOCKED, 3, 3)
		"Slowed (2)": debuff = Debuff.create(Debuff.DebuffType.SLOWED, 2, 3)
		"Staggered (1)": debuff = Debuff.create(Debuff.DebuffType.STAGGERED, 1, 3)
		"Drain (2)": debuff = Debuff.create(Debuff.DebuffType.DRAIN, 2, 3)
		"Weighted (1)": debuff = Debuff.create(Debuff.DebuffType.WEIGHTED, 1, 3)
		"Hexed (2)": debuff = Debuff.create(Debuff.DebuffType.HEXED, 2, 3)
		"Locked": debuff = Debuff.create(Debuff.DebuffType.LOCKED, 0, 2)
		"Rooted": debuff = Debuff.create(Debuff.DebuffType.ROOTED, 0, 2)
		"Tethered (3)": 
			debuff = Debuff.create(Debuff.DebuffType.TETHERED, 3, 4)
			debuff_mgr.set_tether_origin(player.position)
		"Magnetized (1)": debuff = Debuff.create(Debuff.DebuffType.MAGNETIZED, 1, 3)
		"Linked (25)": debuff = Debuff.create(Debuff.DebuffType.LINKED, 25, 3)
		"Clumsy (30)": debuff = Debuff.create(Debuff.DebuffType.CLUMSY, 30, 3)
		"Vulnerable (25)": debuff = Debuff.create(Debuff.DebuffType.VULNERABLE, 25, 3)
		"Exposed (50)": debuff = Debuff.create(Debuff.DebuffType.EXPOSED, 50, 3)
		"Brittle (2)": debuff = Debuff.create(Debuff.DebuffType.BRITTLE, 2, 3)
	if debuff and debuff_mgr:
		debuff_mgr.apply_debuff(debuff)
		_on_hand_updated()  # Refresh cards for Hexed/Locked
		print("[MAIN] Applied debuff: %s" % debuff_name)		

func _on_apply_buff(buff_name: String) -> void:
	var buff_mgr = player.get_buff_manager()
	var buff: Buff = null
	
	match buff_name:
		"Thorns (3 dmg)":
			buff = Buff.create_thorns(3, 15, "Test")
		"Focused":
			buff = Buff.create_focused(15, "Test")
		"Regen (2)":
			buff = Buff.create_regen(2, 15, "Test")
		"Blessed (1)":
			buff = Buff.create_blessed(1, 15, "Test")
		"Fortify":
			buff = Buff.create_fortify(15, "Test")
		"Enlightened (25%, 3)":
			buff = Buff.create_enlightened(25, 3, "Test")
		"Strengthen (+3, 3)":
			buff = Buff.create_strengthen(3, 3, "Test")
		"Bolster (+2, 3)":
			buff = Buff.create_bolster(2, 3, "Test")
		"Haste (+1)":
			buff = Buff.create_haste(1, 15, "Test")
		"Cleanse (1)":
			buff = Buff.create_cleanse(1, "Test")
		"Smith (2)":
			buff = Buff.create_smith(2, 15, "Test")
		"Steady":
			buff = Buff.create_steady("Test")
		"Brace (30%, 1)":
			buff = Buff.create_brace(30, 1, "Test")
		"Resilient (15%, 3)":
			buff = Buff.create_resilient(15, 15, "Test")
	
	if buff and buff_mgr:
		buff_mgr.apply_buff(buff)
		print("[MAIN] Applied buff: %s" % buff_name)
	

## Fires every 5 global tempo (one tempo cycle).
## Handles buff/debuff effects, armor decay, deck upkeep, sky falls, etc.
## Enemy actions and mana regen are handled in _on_tempo_advanced instead.
func _on_tempo_threshold_reached(times: int) -> void:
	print("[MAIN] === TEMPO CYCLE × %d ===" % times)

	var was_moving = player.is_moving
	if was_moving:
		player.pause_movement()

	for i in range(times):
		var debuff_mgr = player.get_debuff_manager()
		var buff_mgr = player.get_buff_manager()

		# Buff cycle-start effects (REGEN heal, FOCUSED mana, BLESSED draws, SMITH armor)
		if buff_mgr:
			var buff_result = buff_mgr.process_turn_start()
			if buff_result["extra_draws"] > 0:
				for d in range(buff_result["extra_draws"]):
					deck_manager.attempt_draw()

		# Debuff cycle-start effects (BURN damage, POISON, DRAIN, SHOCKED)
		if debuff_mgr:
			debuff_mgr.process_turn_start()

		deck_manager.process_turn()

		# Armor decay and healing boost tick (mana regen is handled by process_tempo)
		var stats = player.get_stats()
		stats.process_turn(debuff_mgr, buff_mgr)

		# Advance cycle counter and process inventory
		turn_manager.take_turn()

		# Buff/debuff cycle-end effects (MAGNETIZE pull, BRITTLE decay, duration ticks)
		if debuff_mgr:
			debuff_mgr.process_turn_end()
		if buff_mgr:
			buff_mgr.process_turn_end()

		_process_pending_sky_falls()

	_check_volatile_mixture_in_hand()
	_update_gauntlet_skills_ui()
	update_turn_display()
	_update_enemy_count()
	_reroll_card_rng()
	_on_hand_updated()
	_refresh_unit_tracker()

	if was_moving:
		player.resume_movement()
func _check_volatile_mixture_in_hand() -> void:
	var stats = player.get_stats()
	for i in range(deck_manager.hand.size() - 1, -1, -1):
		var card = deck_manager.hand[i]
		if card.card_id == "volatile_mixture":
			var self_damage = card.damage
			if stats:
				self_damage = stats.get_effective_spell_damage(card.damage)
				stats.take_damage(self_damage)
			deck_manager.hand.remove_at(i)
			deck_manager.discard_pile.append(card)
			print("[MAIN] Volatile Mixture still in hand! Took %d self-damage" % self_damage)

func _process_pending_sky_falls() -> void:
	for i in range(pending_sky_falls.size() - 1, -1, -1):
		var sf = pending_sky_falls[i]
		sf.tempo_remaining -= 5
		if sf.tempo_remaining <= 0:
			# Arrow lands! Deal AOE damage at stored position
			var enemies_hit = enemy_spawner.get_enemies_in_radius(sf.position, 1.5)
			for enemy in enemies_hit:
				enemy.take_damage(sf.damage, true)
			pending_sky_falls.remove_at(i)
			print("[MAIN] Sky Fall landed at %s! Hit %d enemies for %d damage" % [sf.position, enemies_hit.size(), sf.damage])
		else:
			print("[MAIN] Sky Fall: %d tempo until landing at %s" % [sf.tempo_remaining, sf.position])

func _apply_magnetize_pull(tiles: int) -> void:
	var enemies = enemy_spawner.get_living_enemies()
	if enemies.size() == 0:
		return
	
	# Find nearest enemy
	var nearest_enemy = enemies[0]
	var diff = player.position - nearest_enemy.position
	var nearest_dist = Vector3(diff.x, 0, diff.z).length()

	for enemy in enemies:
		var e_diff = player.position - enemy.position
		var dist = Vector3(e_diff.x, 0, e_diff.z).length()
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_enemy = enemy

	# Calculate pull direction
	var pull_diff = nearest_enemy.position - player.position
	var direction = Vector3(pull_diff.x, 0, pull_diff.z).normalized()
	var pull_distance = tiles * grid_manager.grid_size
	var new_pos = player.position + direction * pull_distance
	new_pos = grid_manager.snap_to_grid(new_pos)
	
	# Move player
	player.position = new_pos
	player.target_position = new_pos
	print("[MAIN] Magnetized pulled player %d tiles toward %s" % [tiles, nearest_enemy.enemy_name])
func _reroll_card_rng() -> void:
	var enemies = enemy_spawner.get_living_enemies()
	var chance_boost = player.get_stats().chance_boost

	for card in deck_manager.hand:
		if card.has_chance_effect():
			if card.should_reroll_rng(tempo_manager.global_tempo):
				card.roll_rng(enemies, chance_boost)
				card.rng_roll_tempo = tempo_manager.global_tempo

	# Update chance displays on existing card UIs
	for child in hand_container.get_children():
		if child is CardUI:
			child.update_chance_display()
	
func _on_tempo_changed(current: int, threshold: int) -> void:
	update_turn_display()
	update_tempo_display()

func update_tempo_display() -> void:
	if tempo_label:
		tempo_label.text = "Tempo: %d/%d" % [tempo_manager.get_tempo(), tempo_manager.get_threshold()]
	if tempo_bar:
		tempo_bar.max_value = tempo_manager.get_threshold()
		tempo_bar.value = tempo_manager.get_tempo()
func update_deck_info() -> void:
	if draw_label:
		draw_label.text = "Draw: %d" % deck_manager.get_draw_pile_size()
	if discard_label:
		discard_label.text = "Discard: %d" % deck_manager.get_discard_pile_size()
	if jail_label:
		jail_label.text = "Jail: %d" % deck_manager.get_jail_pile_size()

func update_selected_display() -> void:
	if selected_label:
		if selected_card_index >= 0 and selected_card_index < deck_manager.hand.size():
			var card = deck_manager.hand[selected_card_index]
			selected_label.text = "Selected: %s [%d mana] (Click to play)" % [card.card_name, card.mana_cost]
		else:
			selected_label.text = "Press A/S/D/F/G to select a card"

func update_peaked_display() -> void:
	if peaked_label:
		var peaked = deck_manager.get_peaked_card()
		if peaked and deck_manager.current_overflow_mode == DeckManager.OverflowMode.PEAK:
			peaked_label.text = "NEXT CARD: %s" % peaked.card_name
			peaked_label.visible = true
		else:
			peaked_label.visible = false

func update_card_highlights() -> void:
	var cards = hand_container.get_children()
	for i in range(cards.size()):
		var card_ui = cards[i] as CardUI
		if card_ui:
			card_ui.set_selected(i == selected_card_index)

func select_card(index: int) -> void:
	if index < 0 or index >= deck_manager.hand.size():
		selected_card_index = -1
		if aoe_indicator:
			aoe_indicator.hide_indicator()
		if range_indicator:
			range_indicator.hide_range()
		update_selected_display()
		return

	selected_card_index = index
	update_selected_display()

	# Show AOE indicator if applicable
	var card = deck_manager.hand[selected_card_index]
	if card.is_aoe and aoe_indicator:
		aoe_indicator.update_indicator(card.aoe_shape, card.aoe_range)
		# Point-targeting AOE cards: position indicator at cursor instead of player
		if "point" in card.target_types:
			var mouse_pos = get_mouse_world_position()
			aoe_indicator.position = grid_manager.snap_to_grid(mouse_pos) if mouse_pos != Vector3.ZERO else player.position
		else:
			aoe_indicator.position = player.position
		aoe_indicator.show_indicator()

		# Update enemy RNG indicators
		var enemies = enemy_spawner.get_living_enemies()
		aoe_indicator.update_enemy_rng_indicators(enemies, card)
	elif aoe_indicator:
		aoe_indicator.hide_indicator()

	# Show range indicator for ranged / spell cards (not melee)
	if card.is_ranged and range_indicator:
		var effective_range = float(card.get_effective_range())
		# Include Tighten String bonus if active
		var buff_mgr = player.get_buff_manager() if player else null
		if buff_mgr and buff_mgr.tighten_string_charges > 0 and card.card_type == Card.CardType.ATTACK:
			effective_range += 6
		# Include High Ground bonus if on pillar
		if card.card_type == Card.CardType.ATTACK and is_on_pillar(player.position):
			effective_range += 2
		range_indicator.position = player.position
		range_indicator.show_range(effective_range)
		add_battle_log("%s selected — Range: %d tiles" % [card.card_name, int(effective_range)], Color(0.6, 0.85, 1.0))
	elif card.is_aoe and not card.is_ranged and range_indicator:
		# AOE spells centered on player — show the AOE range
		range_indicator.position = player.position
		range_indicator.show_range(card.aoe_range)
		add_battle_log("%s selected — Radius: %d tiles" % [card.card_name, int(card.aoe_range)], Color(0.7, 0.6, 1.0))
	elif range_indicator:
		range_indicator.hide_range()

func play_selected_card(target) -> void:
	if selected_card_index < 0:
		add_battle_log("No card selected!", Color(1.0, 0.6, 0.3))
		print("[INPUT] No card selected!")
		return

	# Hide range indicator when playing a card
	if range_indicator:
		range_indicator.hide_range()

	var card = deck_manager.hand[selected_card_index]
	var tempo_cost = card.tempo_cost
	var is_ranged_attack = card.is_ranged and card.card_type == Card.CardType.ATTACK

	var debuff_mgr = player.get_debuff_manager()
	var buff_mgr = player.get_buff_manager()

	if debuff_mgr:
		tempo_cost += debuff_mgr.get_tempo_increase()

	# Tighten String: +3 tempo, +6 damage, +6 range, +20% crit on ranged attacks
	var tighten_applied = false
	if buff_mgr and buff_mgr.tighten_string_charges > 0 and is_ranged_attack:
		tempo_cost += 3
		card.bonus_damage += 6
		card.range_modifier += 6
		buff_mgr.apply_buff(Buff.create_enlightened(20, 1, "Tighten String"))
		tighten_applied = true

	# High Ground: +4 damage, +2 range when shooting from elevated position
	var high_ground_applied = false
	if is_ranged_attack and is_on_pillar(player.position):
		card.bonus_damage += 4
		card.range_modifier += 2
		high_ground_applied = true
		add_battle_log("High Ground! +4 damage, +2 range", Color(1.0, 0.9, 0.4))
		print("[MAIN] High Ground bonus applied: +4 damage, +2 range")

	var result = deck_manager.play_card(selected_card_index, target, player)

	if result["played"]:
		selected_card_index = -1

		# Log the card play
		var target_name = ""
		if target is Enemy:
			target_name = " on %s" % target.enemy_name
		if card.last_damage_dealt > 0:
			add_battle_log("Played %s%s — %d damage" % [card.card_name, target_name, card.last_damage_dealt], Color(0.4, 1.0, 0.5))
		else:
			add_battle_log("Played %s%s" % [card.card_name, target_name], Color(0.4, 1.0, 0.5))

		# Apply world effects (knockback, movement, AOE) that need game-level access
		_apply_card_world_effects(card, target)

		# Tighten String: decrement charges and undo temporary card mods
		if tighten_applied:
			buff_mgr.tighten_string_charges -= 1
			card.bonus_damage -= 6
			card.range_modifier -= 6
			if buff_mgr.tighten_string_charges <= 0:
				print("[MAIN] Tighten String expired!")

		# High Ground: undo temporary card mods
		if high_ground_applied:
			card.bonus_damage -= 4
			card.range_modifier -= 2

		# Enchanted Quiver: create a free arrow card after ranged attacks
		if buff_mgr and buff_mgr.enchanted_quiver_charges > 0 and is_ranged_attack:
			var arrow = Card.create_quick_arrow()
			deck_manager.hand.append(arrow)
			buff_mgr.enchanted_quiver_charges -= 1
			deck_manager.hand_updated.emit()
			print("[MAIN] Enchanted Quiver: Quick Arrow added to hand! (%d charges left)" % buff_mgr.enchanted_quiver_charges)

		# Shuriken Pouch: add manifest overflow effect (3 charges of shuriken)
		if card.card_id == "shuriken_pouch":
			var shuriken_effect = OverflowEffect.create_manifest_shuriken(3, "Shuriken Pouch")
			overflow_manager.add_overflow_effect(shuriken_effect)

		# Bottomless Quiver: add quiver overflow effect (5 charges)
		if card.card_id == "bottomless_quiver":
			var quiver_effect = OverflowEffect.create_quiver(5, "Bottomless Quiver")
			overflow_manager.add_overflow_effect(quiver_effect)
			if quiver_ui:
				quiver_ui.refresh()

		if not result["free_turn"]:
			if buff_mgr and buff_mgr.consume_steady():
				print("[MAIN] Steady! No tempo added.")
			else:
				tempo_manager.add_card_tempo(tempo_cost)
		else:
			print("[MAIN] Free attack! No tempo added.")

		_on_hand_updated()
		update_deck_info()
		_refresh_unit_tracker()
	else:
		# Card didn't play - undo temporary modifications
		if tighten_applied:
			card.bonus_damage -= 6
			card.range_modifier -= 6
		if high_ground_applied:
			card.bonus_damage -= 4
			card.range_modifier -= 2

func _get_distance_to_target(target) -> int:
	if not target or not target is Node3D:
		return 0
	var diff = player.position - target.position
	var flat_dist = Vector3(diff.x, 0, diff.z).length()
	return roundi(flat_dist / grid_manager.grid_size)

func _is_target_in_card_range(card: Card, target) -> bool:
	if not target or not target is Node3D:
		return true
	var diff = player.position - target.position
	var flat_dist = Vector3(diff.x, 0, diff.z).length()
	var distance_tiles = flat_dist / grid_manager.grid_size
	if card.is_ranged:
		var max_range = 5 + card.range_modifier
		# Tighten String: +6 range on ranged attacks
		var buff_mgr = player.get_buff_manager() if player else null
		if buff_mgr and buff_mgr.tighten_string_charges > 0 and card.card_type == Card.CardType.ATTACK:
			max_range += 6
		# High Ground: +2 range
		if card.card_type == Card.CardType.ATTACK and is_on_pillar(player.position):
			max_range += 2
		return distance_tiles <= max_range + 0.5  # Small tolerance
	else:
		# Melee: must be adjacent (within ~1.5 tiles)
		return distance_tiles <= 1.5

func _apply_card_world_effects(card: Card, target) -> void:
	var mouse_pos = get_mouse_world_position()

	match card.card_id:
		"roar":
			# Knock all nearby enemies back 1 space
			var nearby = enemy_spawner.get_enemies_in_radius(player.position, card.aoe_range)
			for enemy in nearby:
				enemy.knockback(player.position, 1)
			print("[MAIN] Roar knocked back %d enemies" % nearby.size())

		"taunt":
			# Force nearby enemies to target this player for 2 turns
			var nearby = enemy_spawner.get_enemies_in_radius(player.position, card.aoe_range)
			for enemy in nearby:
				enemy.apply_taunt(player, 2)
			print("[MAIN] Taunted %d enemies for 2 turns" % nearby.size())

		"charge":
			# Move player forward 5 spaces, damaging enemies and interacting with obstacles
			var charge_dest = target.position if target else grid_manager.snap_to_grid(mouse_pos)
			var start_pos = player.position
			var charge_diff = charge_dest - start_pos
			var charge_dir = Vector3(charge_diff.x, 0, charge_diff.z).normalized()
			var charge_distance = 5
			var final_pos = start_pos
			var charge_stopped = false
			var enemies_hit_count = 0

			for step in range(1, charge_distance + 1):
				if charge_stopped:
					break
				var next_pos = grid_manager.snap_to_grid(start_pos + charge_dir * (step * grid_manager.grid_size))

				# Check for obstacles (barricades) at this position
				var hit_obstacle = false
				for i in range(barricade_obstacles.size() - 1, -1, -1):
					var obs = barricade_obstacles[i]
					var obs_grid = grid_manager.world_to_grid(obs["position"])
					var next_grid = grid_manager.world_to_grid(next_pos)
					if obs_grid == next_grid:
						obs["health"] -= card.last_damage_dealt
						if obs["health"] <= 0:
							obs["node"].queue_free()
							barricade_obstacles.remove_at(i)
							_sync_blocked_tiles()
							print("[MAIN] Charge smashed through obstacle!")
						else:
							obs["label"].text = "HP: %d" % obs["health"]
							print("[MAIN] Charge stopped by obstacle! Obstacle HP: %d" % obs["health"])
							charge_stopped = true
							hit_obstacle = true
						break
				if hit_obstacle and charge_stopped:
					break

				# Check for enemies at this position and push them back
				var enemies_at_pos = enemy_spawner.get_enemies_in_radius(next_pos, 0.6)
				for enemy in enemies_at_pos:
					enemy.take_damage(card.last_damage_dealt, true)
					enemy.knockback(start_pos, 2)
					enemies_hit_count += 1

				final_pos = next_pos

			# Move player to final position
			final_pos = grid_manager.snap_to_grid(final_pos)
			player.position = final_pos
			player.target_position = final_pos
			print("[MAIN] Charge: moved to %s, hit %d enemies for %d damage" % [final_pos, enemies_hit_count, card.last_damage_dealt])

		"heroic_leap":
			# Jump to click position based on STR, deal AOE damage on landing
			# Leaps up to the character's full strength in tiles, passing through all units
			var stats = player.get_stats()
			var leap_distance = 3
			if stats:
				leap_distance = max(2, stats.strength)
			var diff = mouse_pos - player.position
			var direction = Vector3(diff.x, 0, diff.z).normalized()
			# Clamp leap to the actual distance to mouse if closer than max leap
			var mouse_dist = Vector3(diff.x, 0, diff.z).length()
			var actual_leap = mini(leap_distance, ceili(mouse_dist / grid_manager.grid_size))
			if actual_leap < 1:
				actual_leap = 1
			var leap_target = player.position + direction * (actual_leap * grid_manager.grid_size)
			leap_target = grid_manager.snap_to_grid(leap_target)
			# Teleport player to landing spot (passes through all units freely)
			player.position = leap_target
			player.target_position = leap_target
			# Deal AOE damage to enemies at landing
			var landing_enemies = enemy_spawner.get_enemies_in_radius(leap_target, 1.5)
			for enemy in landing_enemies:
				enemy.take_damage(card.last_damage_dealt, true)
			print("[MAIN] Heroic Leap: jumped %d tiles to %s, hit %d enemies for %d damage" % [actual_leap, leap_target, landing_enemies.size(), card.last_damage_dealt])

		"surrounding_ice":
			# AOE circle around player - roll independently for each enemy
			var nearby = enemy_spawner.get_enemies_in_radius(player.position, card.aoe_range)
			var hits = 0
			var misses = 0
			for enemy in nearby:
				if randf() <= 0.7:  # 70% hit chance (30% miss)
					enemy.take_damage(card.last_damage_dealt, true)
					hits += 1
				else:
					misses += 1
			print("[MAIN] Surrounding Ice: %d hits, %d misses out of %d enemies" % [hits, misses, nearby.size()])

		"snowballs_chance":
			# Searing fire line 3 spaces forward - always hits
			var sbc_diff = mouse_pos - player.position
			var direction = Vector3(sbc_diff.x, 0, sbc_diff.z).normalized()
			var fire_end = player.position + direction * card.aoe_range
			var fire_enemies = enemy_spawner.get_enemies_in_line(player.position, fire_end, 0.8)
			for enemy in fire_enemies:
				enemy.take_damage(card.last_damage_dealt, true)
			print("[MAIN] Snowball's Chance: fire line hit %d enemies for %d damage" % [fire_enemies.size(), card.last_damage_dealt])
			# 50% to also spread snowball cone
			if randf() < 0.5:
				var cone_enemies = enemy_spawner.get_enemies_in_cone(player.position, direction, card.aoe_range, 45.0)
				var extra_hits = 0
				for enemy in cone_enemies:
					if not enemy in fire_enemies:
						enemy.take_damage(card.last_damage_dealt, true)
						extra_hits += 1
				print("[MAIN] Snowball's Chance: snowball cone hit %d additional enemies!" % extra_hits)

		"sky_fall":
			# Store position for delayed 2-turn landing
			var landing_pos = grid_manager.snap_to_grid(mouse_pos)
			pending_sky_falls.append({
				"position": landing_pos,
				"damage": card.last_damage_dealt,
				"tempo_remaining": 10
			})
			print("[MAIN] Sky Fall: arrow launched! Will land at %s in 10 tempo for %d damage" % [landing_pos, card.last_damage_dealt])

		"round_em_up":
			# Pull enemies within 2 squares of clicked point 1 square toward that point
			var center = grid_manager.snap_to_grid(mouse_pos)
			var reu_radius = 2.0 * grid_manager.grid_size
			var nearby = enemy_spawner.get_enemies_in_radius(center, reu_radius)
			for enemy in nearby:
				var reu_diff = center - enemy.position
				var dir_to_center = Vector3(reu_diff.x, 0, reu_diff.z).normalized()
				var new_pos = enemy.position + dir_to_center * grid_manager.grid_size
				new_pos = grid_manager.snap_to_grid(new_pos)
				enemy.position = new_pos
				enemy.target_position = new_pos
			print("[MAIN] Round 'Em Up: pulled %d enemies toward %s" % [nearby.size(), center])
		"blink":
			var blink_pos = grid_manager.snap_to_grid(mouse_pos)
			player.blink_to(blink_pos)
		"push":
			# Push enemy 3 spaces away from the player
			if target and target.has_method("knockback"):
				target.knockback(player.position, 3)
			print("[MAIN] Push: enemy pushed 3 spaces away")

		"swap":
			# Swap positions between player and target
			if target and target is Node3D:
				var player_pos = player.position
				var target_pos = target.position
				player.position = target_pos
				player.target_position = target_pos
				target.position = player_pos
				target.target_position = player_pos
				print("[MAIN] Swap: swapped positions with %s" % target.name)

		"defensive_awareness":
			# Gain 3 armor per enemy within 2 spaces of the player
			var da_radius = 2.0
			var da_nearby = enemy_spawner.get_enemies_in_radius(player.position, da_radius)
			var enemy_count = da_nearby.size()
			var armor_gain = 3 * enemy_count
			if armor_gain > 0:
				var stats = player.get_stats()
				if stats:
					stats.add_armor(armor_gain)
			print("[MAIN] Defensive Awareness: %d enemies within 2 spaces, gained %d armor" % [enemy_count, armor_gain])

		"sweeping_disarm":
			# Deal damage and disarm all enemies within melee range (1 space)
			var sd_radius = 1.5
			var sd_nearby = enemy_spawner.get_enemies_in_radius(player.position, sd_radius)
			for enemy in sd_nearby:
				enemy.take_damage(card.last_damage_dealt, true)
				enemy.apply_debuff("disarmed", 1)
			print("[MAIN] Sweeping Disarm: hit %d nearby enemies for %d damage, disarmed" % [sd_nearby.size(), card.last_damage_dealt])

		"shadows":
			_set_player_invisible(true)

		"barricade":
			_spawn_barricade()

		"rise":
			var rise_pos = grid_manager.snap_to_grid(get_mouse_world_position())
			_spawn_pillar(rise_pos)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Character panel toggle
		if event.keycode == KEY_I:
			character_panel.toggle_panel()
			return

		# Sphere grid toggle
		if event.keycode == KEY_L:
			sphere_grid_ui.toggle_panel()
			return

		# Camera zoom: < (comma) = zoom in, > (period) = zoom out
		if event.keycode == KEY_COMMA:
			_camera_distance = max(CAMERA_ZOOM_MIN, _camera_distance - CAMERA_ZOOM_STEP)
			_update_camera()
			return
		if event.keycode == KEY_PERIOD:
			_camera_distance = min(CAMERA_ZOOM_MAX, _camera_distance + CAMERA_ZOOM_STEP)
			_update_camera()
			return

		# Card selection
		for i in range(CARD_KEYS.size()):
			if event.keycode == CARD_KEYS[i]:
				select_card(i)
				return
		
		if event.keycode == KEY_ESCAPE:
			selected_card_index = -1
			_pending_quiver_card = null
			_pending_quiver_index = -1
			_pending_quiver_target_type = ""
			if range_indicator:
				range_indicator.hide_range()
			update_selected_display()
			update_card_highlights()
			move_dialog.hide_dialog()
			character_panel.hide_panel()
			sphere_grid_ui.hide_panel()
	
	# Left click - play card or use gauntlet skill
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Quiver card pending targeting
		if _pending_quiver_card != null:
			var mouse_pos = get_mouse_world_position()
			if _pending_quiver_target_type == "enemy":
				var enemy = enemy_spawner.get_enemy_at_position(mouse_pos)
				if enemy:
					play_quiver_card(_pending_quiver_card, _pending_quiver_index, enemy)
				else:
					print("[MAIN] Quiver: click on an enemy to fire %s" % _pending_quiver_card.card_name)
			elif _pending_quiver_target_type == "point":
				play_quiver_card(_pending_quiver_card, _pending_quiver_index, player)
			return

		if selected_card_index >= 0:
			var card = deck_manager.hand[selected_card_index]
			var mouse_pos = get_mouse_world_position()

			var tt = card.target_types.duplicate()

			# Poison Blood: heal cards can also target enemies
			var buff_mgr = player.get_buff_manager() if player else null
			if buff_mgr and buff_mgr.poisoned_blood_active and card.heal_amount > 0:
				if "enemy" not in tt:
					tt.append("enemy")

			var _card_played = false

			# Try enemy targeting first if card supports it
			if "enemy" in tt:
				var enemy = enemy_spawner.get_enemy_at_position(mouse_pos)
				if enemy:
					_card_played = true
					if _is_target_in_card_range(card, enemy):
						play_selected_card(enemy)
					else:
						var range_type = "ranged" if card.is_ranged else "melee"
						var dist = _get_distance_to_target(enemy)
						if card.is_ranged:
							var max_r = card.get_effective_range()
							add_battle_log("Out of range! %s is %d tiles away (max range: %d)" % [enemy.enemy_name, dist, max_r], Color(1.0, 0.4, 0.4))
						else:
							add_battle_log("Out of melee range! %s is %d tiles away (need adjacent)" % [enemy.enemy_name, dist], Color(1.0, 0.4, 0.4))
						print("[INPUT] Enemy is out of %s range!" % range_type)

			# Fall through to other target types if no enemy was clicked
			if not _card_played:
				if "self" in tt:
					play_selected_card(player)
				elif "ally" in tt:
					# TODO: ally selection - for now target self
					play_selected_card(player)
				elif "all_nearby" in tt:
					play_selected_card(player)
				elif "point" in tt:
					play_selected_card(player)
				elif "enemy" in tt:
					# Enemy-only card but no enemy was clicked
					add_battle_log("No enemy at that position!", Color(1.0, 0.6, 0.3))
					print("[INPUT] No enemy at that position!")
				else:
					play_selected_card(null)
	
	# Right click - movement
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if not player.is_moving:
			var mouse_pos = get_mouse_world_position()
			var spaces = grid_manager.get_distance_in_cells(player.position, mouse_pos)

			if spaces == 0:
				print("[INPUT] Already at that location")
			elif spaces == 1:
				player.move_to_grid(mouse_pos, 1)
			else:
				move_dialog.show_dialog(mouse_pos, spaces)

	# Camera orbit - left click drag when no card is selected
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Only start orbiting if no card action is pending
			if selected_card_index < 0 and _pending_quiver_card == null:
				_camera_orbiting = true
				_camera_drag_start = event.position
		else:
			_camera_orbiting = false

	if event is InputEventMouseMotion and _camera_orbiting:
		var delta = event.relative
		_camera_yaw -= delta.x * CAMERA_ORBIT_SENSITIVITY
		_camera_pitch = clamp(_camera_pitch - delta.y * CAMERA_ORBIT_SENSITIVITY, CAMERA_PITCH_MIN, CAMERA_PITCH_MAX)
		_update_camera()

# ============================================
# TEST UI HANDLERS
# ============================================

func _on_spawn_wave() -> void:
	enemy_spawner.spawn_test_arena()
	_sync_blocked_tiles()
	_sync_pillar_tiles()
	_update_enemy_count()
	_refresh_unit_tracker()
	print("[MAIN] Spawned new wave!")

func _on_spawn_elite() -> void:
	var pos = Vector3(randf_range(9, 16), 0, randf_range(2, 8))
	enemy_spawner.spawn_enemy(Enemy.EnemyType.ELITE, pos)
	_sync_blocked_tiles()
	_sync_pillar_tiles()
	_update_enemy_count()
	_refresh_unit_tracker()
	print("[MAIN] Spawned elite enemy!")

func _on_give_item(item_name: String) -> void:
	var item: ItemData = null
	
	match item_name:
		"Iron Helm": item = ItemData.create_iron_helm()
		"Leather Chest": item = ItemData.create_leather_chest()
		"Iron Sword": item = ItemData.create_iron_sword()
		"Wooden Shield": item = ItemData.create_wooden_shield()
		"Gold Ring": item = ItemData.create_gold_ring()
		"Flame Dagger": item = ItemData.create_flame_dagger()
		"Frost Orb": item = ItemData.create_frost_orb()
		"Ring of Vengeance": item = ItemData.create_ring_of_vengeance()
		"Ring of Fortitude": item = ItemData.create_ring_of_fortitude()
		"Berserker Gauntlets": item = ItemData.create_berserker_gauntlets()
		"Guardian Gauntlets": item = ItemData.create_guardian_gauntlets()
	
	if item:
		var inv = player.get_inventory()
		# Find first empty equipment slot
		var slot_array = inv._get_slot_array(item.item_type)
		var max_slots = inv._get_max_slots(item.item_type)

		for i in range(max_slots):
			if slot_array[i] == null:
				inv.equip_item(item, i)
				print("[MAIN] Gave item: %s (equipped)" % item_name)
				return

		# No equipment slot available - store in inventory
		if inv.store_item(item):
			print("[MAIN] Gave item: %s (stored in inventory)" % item_name)
		else:
			print("[MAIN] Cannot give %s - equipment and storage full!" % item_name)

func _on_give_card(card_name: String) -> void:
	var card: Card = null
	
	match card_name:
		"Slash": card = Card.create_slash()
		"Block": card = Card.create_block()
		"Blink": card = Card.create_blink()
		"Heal": card = Card.create_heal()
		"Draw": card = Card.create_draw()
		"Discard": card = Card.create_discard()
		"Empower": card = Card.create_empower()
		"Healing Potion": card = Card.create_healing_potion()
		"Dagger Throw": card = Card.create_dagger_throw()
		"Gain Mana": card = Card.create_gain_mana()
	
	if card:
		deck_manager.hand.append(card)
		deck_manager.hand_updated.emit()
		print("[MAIN] Gave card: %s" % card_name)
func _on_manifest_card_clicked(index: int) -> void:
	var result = overflow_manager.activate_manifest(index)
	
	if result.is_empty():
		return
	
	# Execute manifest effect
	match result["manifest_id"]:
		"summon_skeleton":
			_spawn_summoned_creature("skeleton", result["manifest_value"])
		"summon_spirit":
			_spawn_summoned_creature("spirit", result["manifest_value"])
		"summon_golem":
			_spawn_summoned_creature("golem", result["manifest_value"])
		"use_mushroom":
			player.get_stats().heal(result["manifest_value"])
			print("[MAIN] Used Mushroom: Healed %d" % result["manifest_value"])
		"deal_damage":
			var enemies = enemy_spawner.get_living_enemies()
			if enemies.size() > 0:
				enemies[0].take_damage(result["manifest_value"], true)
		"shuriken":
			# Deal 3 damage to a random enemy; counts as a ranged attack
			var enemies = enemy_spawner.get_living_enemies()
			if enemies.size() > 0:
				var rand_enemy = enemies[randi() % enemies.size()]
				rand_enemy.take_damage(result["manifest_value"], true)
				# Count as an attack towards the attack counter
				var stats = player.get_stats()
				if stats:
					stats.register_attack()
				print("[MAIN] Shuriken! Dealt %d damage to %s" % [result["manifest_value"], rand_enemy.enemy_name])
			else:
				print("[MAIN] Shuriken thrown but no enemies present")
		_:
			print("[MAIN] Unknown manifest effect: %s" % result["manifest_id"])
	
	# Add tempo cost
	if result["tempo_cost"] > 0:
		tempo_manager.add_tempo(result["tempo_cost"])
	
	manifest_ui.refresh()

func _on_quiver_card_targeting_selected(card: Card, index: int, target_type: String) -> void:
	# "self" targeting plays immediately; enemy/point wait for a click
	if target_type == "self":
		play_quiver_card(card, index, player)
	else:
		_pending_quiver_card = card
		_pending_quiver_index = index
		_pending_quiver_target_type = target_type
		print("[MAIN] Quiver: waiting for %s target click for %s" % [target_type, card.card_name])

func play_quiver_card(card: Card, index: int, target) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	var buff_mgr = player.get_buff_manager()
	var debuff_mgr = player.get_debuff_manager()

	# Debuff checks - quiver cards are always attacks
	if debuff_mgr:
		if not debuff_mgr.can_play_cards():
			print("[MAIN] Quiver: cannot play cards - Stunned or Frozen!")
			return
		if not debuff_mgr.can_play_attack_cards():
			print("[MAIN] Quiver: cannot play attack cards - Disarmed!")
			return

	# Check and deduct mana (with Staggered debuff modifier)
	var mana_cost = card.mana_cost
	if debuff_mgr:
		mana_cost += debuff_mgr.get_attack_mana_increase()
	mana_cost = max(0, mana_cost)

	if not stats.has_mana(mana_cost):
		print("[MAIN] Quiver: not enough mana to play %s (need %d)" % [card.card_name, mana_cost])
		return
	if mana_cost > 0:
		stats.spend_mana(mana_cost)

	# Execute the card
	var damage_reduction = debuff_mgr.get_damage_reduction_percent() if debuff_mgr else 0.0
	var self_damage = debuff_mgr.get_self_damage_percent() if debuff_mgr else 0.0
	card.execute(target, stats, deck_manager, damage_reduction, self_damage, buff_mgr)

	# Register attack for attack speed counter (DEX proc)
	if card.card_type == Card.CardType.ATTACK:
		stats.register_attack()

	# Notify debuffs of attack
	if debuff_mgr and card.card_type == Card.CardType.ATTACK:
		debuff_mgr.on_attack()

	# Apply tempo
	var tempo_cost = card.tempo_cost
	if debuff_mgr:
		tempo_cost += debuff_mgr.get_tempo_increase()
	tempo_manager.add_card_tempo(tempo_cost)

	# Apply card world effects
	_apply_card_world_effects(card, target)

	# Notify inventory
	if deck_manager.inventory:
		deck_manager.inventory.on_card_played(card)

	# Remove the card from the quiver and discard it
	overflow_manager.remove_quiver_card(index)
	deck_manager.discard_pile.append(card)

	_pending_quiver_card = null
	_pending_quiver_index = -1
	_pending_quiver_target_type = ""

	quiver_ui.refresh()
	update_deck_info()
	_refresh_unit_tracker()
	print("[MAIN] Quiver: played %s from quiver (cost %d mana, %d tempo)" % [card.card_name, mana_cost, tempo_cost])

func _on_overcharge_triggered(effect_id: String, value: int) -> void:
	match effect_id:
		"damage_all":
			var enemies = enemy_spawner.get_living_enemies()
			for enemy in enemies:
				enemy.take_damage(value, true)
			print("[MAIN] Overcharge: Dealt %d damage to %d enemies" % [value, enemies.size()])

func _spawn_summoned_creature(creature_type: String, count: int) -> void:
	for i in range(count):
		var offset = Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
		var spawn_pos = player.position + offset

		if grid_manager:
			spawn_pos = grid_manager.snap_to_grid(spawn_pos)

		match creature_type:
			"skeleton":
				_create_ally_marker("Skeleton", spawn_pos, Color(0.9, 0.9, 0.8))
			"spirit":
				_create_ally_marker("Spirit", spawn_pos, Color(0.6, 0.8, 1.0))
			"golem":
				_create_ally_marker("Golem", spawn_pos, Color(0.6, 0.5, 0.4))

		print("[MAIN] Summoned %s at %s" % [creature_type, spawn_pos])

func _create_ally_marker(ally_name: String, pos: Vector3, color: Color) -> void:
	var marker = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.5, 0.5, 0.5)
	marker.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.8
	marker.material_override = mat
	marker.position = Vector3(pos.x, 0.25, pos.z)
	add_child(marker)

	var label = Label3D.new()
	label.text = ally_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 0.5, 0)
	marker.add_child(label)

# ============================================
# INVISIBILITY
# ============================================

func _set_player_invisible(invisible: bool) -> void:
	var mesh_node = player.mesh
	if not mesh_node:
		return
	var mat = mesh_node.get_surface_override_material(0) as StandardMaterial3D
	if not mat:
		return
	if invisible:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.25
		print("[MAIN] Player is now invisible (transparent)")
	else:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		mat.albedo_color.a = 1.0
		print("[MAIN] Player is no longer invisible")

# ============================================
# BARRICADE OBSTACLES
# ============================================

func _spawn_barricade() -> void:
	## Spawns 3 brown obstacle boxes in the 3 tiles directly in front of the player
	## (based on the direction from player to mouse cursor), completing a wall.
	var mouse_pos = get_mouse_world_position()
	var diff = mouse_pos - player.position
	var forward = Vector3(diff.x, 0, diff.z).normalized()

	# Get the perpendicular direction for the wall spread
	var right = Vector3(-forward.z, 0, forward.x)

	# Place the center block 1 tile forward, then one on each side
	var center = player.position + forward * grid_manager.grid_size
	var positions = [
		grid_manager.snap_to_grid(center - right * grid_manager.grid_size),
		grid_manager.snap_to_grid(center),
		grid_manager.snap_to_grid(center + right * grid_manager.grid_size),
	]

	for pos in positions:
		var obstacle = _create_obstacle_box(pos, 3)
		barricade_obstacles.append(obstacle)

	_sync_blocked_tiles()
	print("[MAIN] Barricade: spawned 3 obstacles in front of player")

func _create_obstacle_box(pos: Vector3, health: int) -> Dictionary:
	var marker = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.9, 0.9, 0.9)
	marker.mesh = box_mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.35, 0.15)  # Brown
	marker.material_override = mat
	marker.position = Vector3(pos.x, 0.45, pos.z)
	add_child(marker)

	var label = Label3D.new()
	label.text = "HP: %d" % health
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	label.position = Vector3(0, 0.7, 0)
	marker.add_child(label)

	return {"node": marker, "health": health, "position": pos, "label": label}

func damage_barricade_at(world_pos: Vector3, damage: int) -> bool:
	## Called when an enemy attacks a barricade obstacle. Returns true if blocked.
	for i in range(barricade_obstacles.size() - 1, -1, -1):
		var obs = barricade_obstacles[i]
		var obs_grid = grid_manager.world_to_grid(obs["position"])
		var target_grid = grid_manager.world_to_grid(world_pos)
		if obs_grid == target_grid:
			obs["health"] -= damage
			if obs["health"] <= 0:
				obs["node"].queue_free()
				barricade_obstacles.remove_at(i)
				_sync_blocked_tiles()
				print("[MAIN] Barricade block destroyed!")
			else:
				obs["label"].text = "HP: %d" % obs["health"]
				print("[MAIN] Barricade block hit! HP: %d" % obs["health"])
			return true
	return false

func is_barricade_at(world_pos: Vector3) -> bool:
	for obs in barricade_obstacles:
		var obs_grid = grid_manager.world_to_grid(obs["position"])
		var target_grid = grid_manager.world_to_grid(world_pos)
		if obs_grid == target_grid:
			return true
	return false

func _sync_blocked_tiles() -> void:
	## Syncs the barricade positions to the player and all enemies for pathfinding.
	var tiles: Array[Vector2i] = []
	for obs in barricade_obstacles:
		tiles.append(grid_manager.world_to_grid(obs["position"]))
	player.blocked_tiles = tiles
	for enemy in enemy_spawner.get_living_enemies():
		enemy.blocked_tiles = tiles

# ============================================
# RISE PILLAR
# ============================================

func _spawn_pillar(pos: Vector3) -> void:
	## Creates a brown cylinder pillar at the target position.
	## If a character is on that tile, they get elevated on top.
	## Pillar disappears after 5 tempo.
	var pillar_root = Node3D.new()
	pillar_root.position = Vector3(pos.x, 0, pos.z)
	add_child(pillar_root)

	var pillar_mesh = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.4
	cylinder.bottom_radius = 0.4
	cylinder.height = 2.0
	pillar_mesh.mesh = cylinder
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.35, 0.15)  # Brown
	pillar_mesh.material_override = mat
	pillar_mesh.position = Vector3(0, 1.0, 0)  # Center of cylinder at Y=1
	pillar_root.add_child(pillar_mesh)

	var label = Label3D.new()
	label.text = "Pillar"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	label.position = Vector3(0, 2.3, 0)
	pillar_root.add_child(label)

	var pillar_data = {"node": pillar_root, "position": pos, "tempo_remaining": 5}
	active_pillars.append(pillar_data)

	# Check if player is on this tile and elevate them
	var pillar_grid = grid_manager.world_to_grid(pos)
	var player_grid = grid_manager.world_to_grid(player.position)
	if pillar_grid == player_grid:
		player.position.y = 2.0
		player.target_position.y = 2.0
		print("[MAIN] Rise: player elevated on pillar!")

	# Check if any enemy is on this tile and elevate them
	var enemies = enemy_spawner.get_living_enemies()
	for enemy in enemies:
		var enemy_grid = grid_manager.world_to_grid(enemy.position)
		if enemy_grid == pillar_grid:
			enemy.position.y = 2.0
			enemy.target_position = enemy.position
			print("[MAIN] Rise: %s elevated on pillar!" % enemy.enemy_name)

	_sync_pillar_tiles()
	print("[MAIN] Rise: pillar created at %s (5 tempo duration)" % pos)

func _process_pillars(tempo_amount: int) -> void:
	var any_removed = false
	for i in range(active_pillars.size() - 1, -1, -1):
		var pillar = active_pillars[i]
		pillar["tempo_remaining"] -= tempo_amount
		if pillar["tempo_remaining"] <= 0:
			_remove_pillar(pillar)
			active_pillars.remove_at(i)
			any_removed = true
	if any_removed:
		_sync_pillar_tiles()

func _remove_pillar(pillar: Dictionary) -> void:
	var pos = pillar["position"]
	var pillar_grid = grid_manager.world_to_grid(pos)

	# Lower any characters that were on the pillar
	var player_grid = grid_manager.world_to_grid(player.position)
	if pillar_grid == player_grid and player.position.y > 0.1:
		player.position.y = 0.0
		player.target_position.y = 0.0
		print("[MAIN] Pillar expired: player lowered")

	var enemies = enemy_spawner.get_living_enemies()
	for enemy in enemies:
		var enemy_grid = grid_manager.world_to_grid(enemy.position)
		if enemy_grid == pillar_grid and enemy.position.y > 0.1:
			enemy.position.y = 0.0
			enemy.target_position = enemy.position
			print("[MAIN] Pillar expired: %s lowered" % enemy.enemy_name)

	pillar["node"].queue_free()
	print("[MAIN] Pillar at %s expired and removed" % pos)

func _sync_pillar_tiles() -> void:
	## Syncs active pillar positions to all enemies so they stay trapped on pillars.
	var tiles: Array[Vector2i] = []
	for pillar in active_pillars:
		tiles.append(grid_manager.world_to_grid(pillar["position"]))
	for enemy in enemy_spawner.get_living_enemies():
		enemy.pillar_tiles = tiles

func is_on_pillar(world_pos: Vector3) -> bool:
	var check_grid = grid_manager.world_to_grid(world_pos)
	for pillar in active_pillars:
		var pillar_grid = grid_manager.world_to_grid(pillar["position"])
		if pillar_grid == check_grid:
			return true
	return false

func _on_apply_overflow(overflow_name: String) -> void:
	var effect: OverflowEffect = null
	
	match overflow_name:
		"Jailed (3)":
			effect = OverflowEffect.create_jailed(3, "Test")
		"Manifest: Skeleton (3)":
			effect = OverflowEffect.create_manifest_skeleton(3, "Test")
		"Manifest: Mushroom (∞)":
			effect = OverflowEffect.create_manifest_mushroom(-1, "Test")
		"Manifest: Spirit (3)":
			effect = OverflowEffect.create_manifest_spirit(3, "Test")
		"Enhance +3 (3)":
			effect = OverflowEffect.create_enhance(3, 3, "Test")
		"Transferred (3)":
			effect = OverflowEffect.create_transferred(3, "Test")
		"Peak (∞)":
			effect = OverflowEffect.create_peak(-1, "Test")
		"Overcharge: +2 Health (∞)":
			effect = OverflowEffect.create_overcharge_health(2, -1, "Test")
		"Overcharge: +2 Mana (∞)":
			effect = OverflowEffect.create_overcharge_mana(2, -1, "Test")
		"Overcharge: +2 Armor (3)":
			effect = OverflowEffect.create_overcharge_armor(2, 3, "Test")
		"Overcharge: 3 Dmg All (3)":
			effect = OverflowEffect.create_overcharge_damage(3, 3, "Test")
	
	if effect:
		overflow_manager.add_overflow_effect(effect)
		print("[MAIN] Applied overflow: %s" % overflow_name)

# === Reaction & On Draw handlers ===

func _on_player_damage_taken(_amount: int) -> void:
	var triggered = deck_manager.trigger_reactions("on_damage_taken")
	for card in triggered:
		card.execute(null, player.get_stats(), deck_manager, 0.0, 0.0, player.get_buff_manager())
	if triggered.size() > 0:
		_refresh_unit_tracker()

func _on_card_on_draw_triggered(card: Card) -> void:
	match card.on_draw_effect:
		"deal_4_random_enemy":
			var enemies = enemy_spawner.get_living_enemies()
			if enemies.size() > 0:
				var random_enemy = enemies[randi() % enemies.size()]
				random_enemy.take_damage(4, true)
				print("[MAIN] %s On Draw: dealt 4 damage to %s" % [card.card_name, random_enemy.enemy_name])
			else:
				print("[MAIN] %s On Draw: no enemies to damage" % card.card_name)
