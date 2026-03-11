extends Node3D

## Main game scene - turn-based card ARPG

@onready var deck_manager: DeckManager = $DeckManager
@onready var buff_bar: BuffBarUI = $UI/BuffBar
@onready var turn_manager: TurnManager = $TurnManager
@onready var grid_manager: GridManager = $GridManager
@onready var move_dialog: MoveConfirmDialog = $MoveConfirmDialog
@onready var point_to_prove_dialog: PointToProveDialog = $PointToProveDialog
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
@onready var quiver_ui: QuiverUI = $UI/QuiverUI
@onready var sphere_grid_ui: SphereGridUI = $SphereGridUI
@onready var skill_tree_ui: SkillTreeUI = $SkillTreeUI
@onready var sphere_inventory: SphereInventory = $SphereInventory
@onready var range_indicator: RangeIndicator = $RangeIndicator

var dungeon_manager: DungeonManager = null
var unit_tracker: UnitTrackerUI = null
var quest_manager: QuestManager = null
var current_world_level: int = 1

# Global waypoint discovery tracking (persists across world transitions)
# Each entry: { "world": int, "target": String, "display_name": String }
var discovered_waypoints: Array = []

# Quest state that persists across world transitions
# { "kill_counts": { "Wererat": 3, ... }, "accepted_ids": ["olorin_kill_wererats"], "completed_ids": [] }
var quest_state: Dictionary = {}

# Waypoint teleport menu state
var _waypoint_menu_panel: PanelContainer = null
var _waypoint_menu_visible: bool = false

# Minimap UI
var _minimap_panel: PanelContainer = null
var _minimap_texture_rect: TextureRect = null
var _minimap_image: Image = null
const MINIMAP_SIZE: int = 100
const MINIMAP_PIXEL_SCALE: int = 4

# Tab menu (quest log / map)
var _tab_menu_panel: PanelContainer = null
var _tab_menu_visible: bool = false
var _tab_menu_current_tab: int = 0  # 0=map, 1=quest log
var _tab_quest_container: VBoxContainer = null
var _tab_map_container: VBoxContainer = null
var _tab_map_texture_rect: TextureRect = null

# Card animation tracking
var _prev_hand_card_ids: Array[String] = []  # Card IDs from last hand update
var _card_play_animating: bool = false        # Block input during card play animation

# Chest loot modal state
var _chest_modal: PanelContainer = null
var _chest_modal_open: bool = false
var _chest_modal_contents: Dictionary = {}
var _chest_interact_prompt: Label3D = null


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

var maintained_list_panel: PanelContainer = null
var maintained_list_container: VBoxContainer = null
var maintained_list_visible: bool = false
var maintained_list_card_preview: PanelContainer = null
var maintained_btn: Button = null
var hand_card_preview: PanelContainer = null
var _hand_hover_id: int = 0
var pending_sky_falls: Array = []  # [{position: Vector3, damage: int, tempo_remaining: int}]
var pending_absorb_essences: Array = []  # [{total_damage: int, tempo_remaining: int}]
var glut_tempo_remaining: int = 0  # When > 0, player cannot play cards
var barricade_obstacles: Array = []  # [{node: MeshInstance3D, health: int}]
var active_pillars: Array = []  # [{node: Node3D, position: Vector3, tempo_remaining: int}]
var _card_ui_instances: Array = []
var _current_hand_hover_index: int = -1
# Pending quiver card play state
var _block_button: Button = null
var _pending_quiver_card: Card = null
var _pending_quiver_index: int = -1
var _pending_quiver_target_type: String = ""

# Communal Donation UI state
var _donation_panel: PanelContainer = null
var _donation_slider: HSlider = null
var _donation_amount_label: Label = null
var _donation_ally_container: VBoxContainer = null
var _donation_active: bool = false
var _donation_ally_sliders: Array = []  # [{slider: HSlider, label: Label, name: String}]

# Lethal Recall: track the last instant card played and its target for replay
var _last_played_card: Card = null
var _last_played_target = null

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
	deck_manager.card_drawn.connect(_on_card_drawn_sphere_passive)
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
	enemy_spawner.loot_dropped.connect(_on_loot_dropped)
	enemy_spawner.enemy_spawned.connect(_on_enemy_spawned_connect_debuffs)
	
	# Test UI
	test_ui.spawn_wave_requested.connect(_on_spawn_wave)
	test_ui.spawn_elite_requested.connect(_on_spawn_elite)
	test_ui.give_item_requested.connect(_on_give_item)
	test_ui.give_card_requested.connect(_on_give_card)
	test_ui.apply_buff_requested.connect(_on_apply_buff)
	
	help_panel.closed.connect(_on_help_closed)
	
	# Sphere inventory + grid connection
	sphere_grid_ui.connect_sphere_inventory(sphere_inventory)
	sphere_grid_ui.node_unlocked.connect(_on_sphere_grid_node_unlocked)
	sphere_grid_ui.sphere_grid.constellation_completed.connect(_on_constellation_completed)

	# Skill tree connection — also link sphere grid into the tabbed panel
	skill_tree_ui.connect_sphere_grid(sphere_grid_ui)
	skill_tree_ui.sphere_inventory = sphere_inventory
	skill_tree_ui.option_chosen.connect(_on_skill_tree_option_chosen)
	skill_tree_ui.auto_grant_claimed.connect(_on_skill_tree_auto_grant_claimed)
	skill_tree_ui.retrospective_chosen.connect(_on_skill_tree_retrospective_chosen)

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
	_setup_maintained_list_button()
	_setup_maintained_list_panel()
	_setup_hand_card_preview()
	_setup_donation_panel()

	# Multiplayer: initialize P2 deck and UI buttons
	if is_multiplayer and player2_character:
		_initialize_player2()

	# Unit tracker (left side panel)
	_setup_unit_tracker()

	# Initialize dungeon
	_setup_dungeon()
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
	# Update chest interact prompts, waypoints, and enemy fog visibility
	if dungeon_manager and grid_manager:
		var pg = grid_manager.world_to_grid(player.position)
		dungeon_manager.update_chest_prompts(pg)
		dungeon_manager.update_waypoint_prompts(pg)
		dungeon_manager.update_enemy_fog_visibility(
			enemy_spawner.get_living_enemies(), grid_manager
		)
		_update_minimap()
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

func _setup_hand_area_background() -> void:
	var hand_area = $UI/HandArea as PanelContainer
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_top = 0
	style.border_color = Color(0, 0, 0, 0)
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

	# Skill tree crit check for basic attack
	if buff_mgr and buff_mgr.last_crit_hit:
		buff_mgr.last_crit_hit = false
		_trigger_skill_tree_on_crit(target)

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
		add_battle_log("Cannot block — Stunned or Frozen!", Color(1.0, 0.4, 0.4))
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
		Card.CardType.POWER:
			type_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
		Card.CardType.ENCHANTMENT:
			type_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.8))
	vbox.add_child(type_lbl)

	var cost_lbl = Label.new()
	if card.maintain_cost > 0:
		cost_lbl.text = "Cost: %dM / %dT | Maintain: %dM" % [card.mana_cost, card.tempo_cost, card.maintain_cost]
	else:
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

	_append_keyword_tooltips(vbox, card)

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

# ============================================
# MAINTAINED CARDS LIST (expandable button)
# ============================================

func _setup_maintained_list_button() -> void:
	var ui = $UI as CanvasLayer
	maintained_btn = Button.new()
	maintained_btn.name = "MaintainedListButton"
	maintained_btn.text = "Maintained: 0"
	maintained_btn.custom_minimum_size = Vector2(110, 30)
	maintained_btn.pressed.connect(_on_maintained_list_button_pressed)
	var btn_container = Control.new()
	btn_container.name = "MaintainedButtonContainer"
	ui.add_child(btn_container)
	btn_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_container.offset_left = -210.0
	btn_container.offset_top = -40.0
	btn_container.offset_right = -100.0
	btn_container.offset_bottom = -5.0
	btn_container.add_child(maintained_btn)
	maintained_btn.set_anchors_preset(Control.PRESET_FULL_RECT)

func _setup_maintained_list_panel() -> void:
	var ui = $UI as CanvasLayer
	maintained_list_panel = PanelContainer.new()
	maintained_list_panel.name = "MaintainedListPanel"
	ui.add_child(maintained_list_panel)
	maintained_list_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	maintained_list_panel.offset_left = -280.0
	maintained_list_panel.offset_top = -200.0
	maintained_list_panel.offset_right = -10.0
	maintained_list_panel.offset_bottom = 200.0
	maintained_list_panel.custom_minimum_size = Vector2(270, 300)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.6, 0.3, 0.8)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.content_margin_left = 10.0
	panel_style.content_margin_right = 10.0
	panel_style.content_margin_top = 10.0
	panel_style.content_margin_bottom = 10.0
	maintained_list_panel.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.layout_mode = 1
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	maintained_list_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "Maintained Cards"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
	vbox.add_child(title)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 250)
	vbox.add_child(scroll)

	maintained_list_container = VBoxContainer.new()
	maintained_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(maintained_list_container)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_on_maintained_list_button_pressed)
	vbox.add_child(close_btn)

	maintained_list_panel.visible = false

	# Card preview popup for maintained list
	maintained_list_card_preview = PanelContainer.new()
	maintained_list_card_preview.name = "MaintainedListCardPreview"
	ui.add_child(maintained_list_card_preview)
	maintained_list_card_preview.custom_minimum_size = Vector2(180, 0)
	var preview_style = StyleBoxFlat.new()
	preview_style.bg_color = Color(0.15, 0.15, 0.2, 0.98)
	preview_style.border_width_left = 2
	preview_style.border_width_right = 2
	preview_style.border_width_top = 2
	preview_style.border_width_bottom = 2
	preview_style.border_color = Color(0.6, 0.3, 0.8)
	preview_style.corner_radius_top_left = 4
	preview_style.corner_radius_top_right = 4
	preview_style.corner_radius_bottom_left = 4
	preview_style.corner_radius_bottom_right = 4
	preview_style.content_margin_left = 8.0
	preview_style.content_margin_right = 8.0
	preview_style.content_margin_top = 8.0
	preview_style.content_margin_bottom = 8.0
	maintained_list_card_preview.add_theme_stylebox_override("panel", preview_style)
	maintained_list_card_preview.visible = false
	maintained_list_card_preview.z_index = 200
	maintained_list_card_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _update_maintained_button() -> void:
	if maintained_btn:
		var count = deck_manager.get_maintained_card_count()
		maintained_btn.text = "Maintained: %d" % count
		maintained_btn.visible = count > 0
	if maintained_list_visible:
		_populate_maintained_list()

func _on_maintained_list_button_pressed() -> void:
	maintained_list_visible = !maintained_list_visible
	maintained_list_panel.visible = maintained_list_visible
	if maintained_list_visible:
		_populate_maintained_list()
	else:
		maintained_list_card_preview.visible = false

func _populate_maintained_list() -> void:
	for child in maintained_list_container.get_children():
		child.queue_free()

	var maintained_cards = deck_manager.get_maintained_cards()
	if maintained_cards.size() == 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "No maintained cards."
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		maintained_list_container.add_child(empty_lbl)
		return

	for i in range(maintained_cards.size()):
		var card = maintained_cards[i]
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var entry = Button.new()
		entry.text = "%s (%dM)" % [card.card_name, card.maintain_cost]
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.flat = true
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		entry.add_theme_color_override("font_hover_color", Color(0.8, 0.5, 1.0))
		entry.add_theme_font_size_override("font_size", 14)
		entry.mouse_entered.connect(_on_maintained_list_entry_hovered.bind(card, entry))
		entry.mouse_exited.connect(_on_maintained_list_entry_unhovered)
		hbox.add_child(entry)

		var dismiss_btn = Button.new()
		dismiss_btn.text = "X"
		dismiss_btn.custom_minimum_size = Vector2(28, 28)
		dismiss_btn.add_theme_font_size_override("font_size", 14)
		var dismiss_style = StyleBoxFlat.new()
		dismiss_style.bg_color = Color(0.6, 0.15, 0.15, 0.9)
		dismiss_style.corner_radius_top_left = 4
		dismiss_style.corner_radius_top_right = 4
		dismiss_style.corner_radius_bottom_left = 4
		dismiss_style.corner_radius_bottom_right = 4
		dismiss_btn.add_theme_stylebox_override("normal", dismiss_style)
		var dismiss_hover = StyleBoxFlat.new()
		dismiss_hover.bg_color = Color(0.8, 0.2, 0.2, 0.95)
		dismiss_hover.corner_radius_top_left = 4
		dismiss_hover.corner_radius_top_right = 4
		dismiss_hover.corner_radius_bottom_left = 4
		dismiss_hover.corner_radius_bottom_right = 4
		dismiss_btn.add_theme_stylebox_override("hover", dismiss_hover)
		dismiss_btn.pressed.connect(_on_maintained_card_dismiss.bind(i))
		hbox.add_child(dismiss_btn)

		maintained_list_container.add_child(hbox)

func _on_maintained_card_dismiss(index: int) -> void:
	deck_manager.dismiss_maintained_card(index)
	_populate_maintained_list()
	_update_maintained_button()
	update_deck_info()
	add_battle_log("Dismissed a maintained card.", Color(0.8, 0.5, 1.0))

func _on_maintained_list_entry_hovered(card: Card, entry: Button) -> void:
	for child in maintained_list_card_preview.get_children():
		child.queue_free()

	var vbox = VBoxContainer.new()
	maintained_list_card_preview.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = card.card_name
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
	vbox.add_child(name_lbl)

	var type_lbl = Label.new()
	type_lbl.text = card.card_type_name
	type_lbl.add_theme_font_size_override("font_size", 12)
	type_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
	vbox.add_child(type_lbl)

	var cost_lbl = Label.new()
	cost_lbl.text = "Maintain: %dM reserved" % card.maintain_cost
	cost_lbl.add_theme_font_size_override("font_size", 12)
	cost_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	vbox.add_child(cost_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = card.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(160, 0)
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(desc_lbl)

	_append_keyword_tooltips(vbox, card)

	var entry_rect = entry.get_global_rect()
	var preview_x = maintained_list_panel.position.x - maintained_list_card_preview.size.x - 10
	var preview_y = entry_rect.position.y
	var hand_area = $UI/HandArea as PanelContainer
	var max_y = hand_area.global_position.y - maintained_list_card_preview.size.y - 8.0
	preview_y = min(preview_y, max_y)
	preview_y = max(preview_y, 4.0)
	maintained_list_card_preview.global_position = Vector2(preview_x, preview_y)
	maintained_list_card_preview.visible = true

func _on_maintained_list_entry_unhovered() -> void:
	maintained_list_card_preview.visible = false

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
		Card.CardType.POWER:
			type_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
		Card.CardType.ENCHANTMENT:
			type_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.8))
	vbox.add_child(type_lbl)

	# Cost
	var cost_lbl = Label.new()
	if card.maintain_cost > 0:
		cost_lbl.text = "Cost: %dM / %dT | Maintain: %dM" % [card.mana_cost, card.tempo_cost, card.maintain_cost]
	else:
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

	_append_keyword_tooltips(vbox, card)

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
	deck_manager.connect_debuff_manager(player.get_debuff_manager())
	player.get_debuff_manager().point_to_prove_triggered.connect(_on_point_to_prove_triggered)
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
	player.get_stats().maintained_cards_broken.connect(_on_maintained_cards_broken)
	player.get_stats().health_damage_taken.connect(_on_player_health_damage_taken)
	player.get_stats().healed.connect(_on_player_healed)
	player.get_stats().mana_gained.connect(_on_player_mana_gained)
	deck_manager.on_draw_triggered.connect(_on_card_on_draw_triggered)
	deck_manager.card_erased.connect(_on_card_erased)

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

	# Apply any already-unlocked sphere grid nodes to the character
	_apply_all_unlocked_sphere_nodes()

	# Check and apply any already-completed constellations
	sphere_grid_ui.sphere_grid.check_constellation_completion()
	_apply_all_constellation_bonuses()


	# Initialize character skill tree (use character-specific tree if available)
	var skill_tree: SkillTreeData
	if character.character_name == "Brad":
		skill_tree = SkillTreeData.create_brad_tree()
	elif character.character_name == "Stephen":
		skill_tree = SkillTreeData.create_stephen_tree()
	elif character.character_name == "Ryan":
		skill_tree = SkillTreeData.create_ryan_tree()
	else:
		skill_tree = SkillTreeData.create_placeholder_tree(character.character_name)

	skill_tree_ui.set_skill_tree(skill_tree)
	skill_tree_ui.set_player_level(player.get_stats().current_level)

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
		Card.CardType.POWER:
			type_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
		Card.CardType.ENCHANTMENT:
			type_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.8))
	vbox.add_child(type_lbl)

	var cost_lbl = Label.new()
	if card.maintain_cost > 0:
		cost_lbl.text = "Cost: %dM / %dT | Maintain: %dM" % [card.mana_cost, card.tempo_cost, card.maintain_cost]
	else:
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

	_append_keyword_tooltips(vbox, card)

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
	# Check if the player stepped onto an enemy-occupied tile (pass-through costs 2 tempo)
	var player_cell = grid_manager.world_to_grid(player.position)
	var passed_through_enemy = false
	for enemy in enemy_spawner.get_living_enemies():
		if grid_manager.world_to_grid(enemy.position) == player_cell:
			passed_through_enemy = true
			break
	if passed_through_enemy:
		tempo_manager.add_pass_through_tempo()
	# Normal per-tile tempo
	tempo_manager.add_movement_tempo()
	# Check if player entered a new dungeon zone
	_check_dungeon_zones()
	# Reveal fog of war around the player
	_update_fog_of_war()
	# Check if player stepped onto a waypoint to discover it
	_check_waypoint_discovery(player_cell)
	# Update camera focus to follow player
	if dungeon_manager:
		_camera_focus = player.position + Vector3(2, 0, 0)
		_update_camera()

func _on_player_move_completed() -> void:
	# Final zone check at destination
	_check_dungeon_zones()
	_update_fog_of_war()
	# Sphere grid passive triggers for movement
	_trigger_sphere_passives("on_move", {})

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
				# Reappearing from invisibility counts as displacement
				_trigger_skill_tree_on_displacement()

	update_turn_display()
	_refresh_unit_tracker()

func _on_enemy_spawned_connect_debuffs(enemy: Enemy) -> void:
	## Connect debuff signals for skill tree passives (Toxic Fumes, Pop Rocks).
	enemy.debuff_applied.connect(_on_enemy_debuff_applied)
	enemy.debuff_expired.connect(_on_enemy_debuff_expired)
	enemy.exposed.connect(_on_enemy_exposed)
	enemy.attacked_player.connect(_on_enemy_attacked_player)
	enemy.damaged.connect(_on_enemy_damaged.bind(enemy))
	enemy.movement_completed.connect(_on_enemy_movement_completed)

var _disarm_mastery_applying: bool = false  # Guard against recursive disarm
var _wither_applying: bool = false  # Guard against recursive wither
var _enemy_melee_state: Dictionary = {}  # Territorial Death: tracks enemy melee range state

func _on_enemy_debuff_applied(enemy: Enemy, debuff_name: String, value: int) -> void:
	_trigger_skill_tree_on_debuff_applied(enemy, debuff_name, value)
	# Stephen: Disarm Mastery — extra disarm stack (guarded against recursion)
	if debuff_name == "disarmed" and not _disarm_mastery_applying:
		_disarm_mastery_applying = true
		_trigger_skill_tree_stephen_on_disarm_applied(enemy, value)
		_disarm_mastery_applying = false
	# Cory: Wither — +1 charge to all debuffs applied (guarded against recursion)
	if not _wither_applying:
		var stats = player.get_stats()
		if stats and stats.has_skill_tree_passive("wither"):
			_wither_applying = true
			if enemy.has_method("apply_debuff"):
				enemy.apply_debuff(debuff_name, 1)
			_wither_applying = false
	# Cory: Prey on the Weak — bonus damage on debuff to low HP enemy
	_trigger_skill_tree_cory_on_debuff_applied(enemy, debuff_name, value)

func _on_enemy_debuff_expired(enemy: Enemy, debuff_name: String) -> void:
	_trigger_skill_tree_on_debuff_expired(enemy)

func _on_enemy_exposed(enemy: Enemy) -> void:
	_trigger_skill_tree_stephen_on_expose(enemy)

func _on_enemy_movement_completed(enemy: Enemy) -> void:
	# Cory: Territorial Death — check if enemy entered or left melee range
	var dist = player.position.distance_to(enemy.position)
	var in_melee = dist <= 1.8  # Slightly larger than 1.5 to catch edge cases
	var enemy_id = enemy.get_instance_id()
	var was_in_melee = _enemy_melee_state.get(enemy_id, false)
	_enemy_melee_state[enemy_id] = in_melee
	if in_melee != was_in_melee:
		_trigger_skill_tree_cory_on_enemy_enter_melee(enemy)
		# Brad: In the Trenches — free attack when enemy enters adjacent square
		if in_melee:
			_trigger_skill_tree_brad_itt_on_enter(enemy)

func _on_enemy_damaged(damage: int, enemy: Enemy) -> void:
	_trigger_skill_tree_cory_on_enemy_damaged(enemy, damage)

func _on_enemy_attacked_player(enemy: Enemy) -> void:
	_trigger_skill_tree_brad_on_attacked(enemy)
	_trigger_skill_tree_stephen_on_attacked(enemy)

func _on_enemy_killed(enemy: Enemy) -> void:
	print("[MAIN] Enemy killed: %s (XP: %d)" % [enemy.enemy_name, enemy.xp_reward])
	player.get_stats().gain_xp(enemy.xp_reward)
	_update_enemy_count()
	_refresh_unit_tracker()
	# Sphere grid passive triggers for kills
	_trigger_sphere_passives("on_kill", {"target": enemy})
	# Cory: Eat — heal on kill
	_trigger_skill_tree_cory_on_kill(enemy)
	# Quest tracking
	if quest_manager:
		quest_manager.on_enemy_killed(enemy.enemy_name)

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

	# Update skill tree with new level
	skill_tree_ui.set_player_level(new_level)

	# Force-refresh health and mana UI to guarantee display shows full restore
	var stats = player.get_stats()
	if stats:
		_on_player_health_changed(stats.current_health, stats.max_health)
		_on_player_mana_changed(stats.current_mana, stats.max_mana)
		_update_xp_display()

func _on_player_xp_changed(current_xp: int, xp_to_next: int) -> void:
	_update_xp_display()

# ============================================
# SPHERE GRID → CHARACTER SYNC
# ============================================

func _on_sphere_grid_node_unlocked(node_id: int) -> void:
	## Called when the player unlocks a node on the sphere grid.
	## Applies the node's effect to the character immediately.
	var grid = sphere_grid_ui.sphere_grid
	var node = grid.get_node_by_id(node_id)
	if not node:
		return
	_apply_sphere_grid_node(node)

func _apply_sphere_grid_node(node) -> void:
	## Applies a single sphere grid node's effect to the character.
	var stats = player.get_stats()
	if not stats:
		return

	match node.node_type:
		SphereGrid.NodeType.STAT_BONUS:
			var parsed = _parse_stat_label(node.label)
			if parsed.size() > 0:
				stats.apply_sphere_grid_stat(parsed["stat"], parsed["value"])
				add_battle_log("Sphere Grid: %s" % node.label, Color(0.4, 0.6, 1.0))

		SphereGrid.NodeType.HEALTH:
			var amount = _parse_numeric_value(node.label)
			if amount > 0:
				stats.apply_sphere_grid_health(amount)
				add_battle_log("Sphere Grid: Max HP +%d" % amount, Color(0.9, 0.2, 0.2))

		SphereGrid.NodeType.MANA:
			var amount = _parse_numeric_value(node.label)
			if amount > 0:
				stats.apply_sphere_grid_mana(amount)
				add_battle_log("Sphere Grid: Max Mana +%d" % amount, Color(0.2, 0.5, 1.0))

		SphereGrid.NodeType.COMBAT_BONUS:
			stats.apply_sphere_grid_combat_bonus(node.label, node.description)
			add_battle_log("Sphere Grid: %s" % node.label, Color(0.9, 0.7, 0.2))

		SphereGrid.NodeType.PASSIVE:
			var passive = _parse_passive_description(node.description, node.id)
			if passive.size() > 0:
				stats.add_sphere_grid_passive(passive)
				add_battle_log("Sphere Grid: %s" % node.description, Color(0.9, 0.5, 0.2))

		SphereGrid.NodeType.CULLING_STONE:
			var inventory = player.get_inventory()
			if inventory:
				inventory.culling_stones += 1
				add_battle_log("Sphere Grid: Obtained Culling Stone!", Color(0.8, 0.5, 1.0))

	print("[MAIN] Sphere grid node %d applied: [%s] %s" % [node.id, SphereGrid.NodeType.keys()[node.node_type], node.label])

func _apply_all_unlocked_sphere_nodes() -> void:
	## Applies all already-unlocked sphere grid nodes to the character.
	## Called after character selection to sync grid state.
	var grid = sphere_grid_ui.sphere_grid
	if not grid:
		return
	for node in grid.get_all_nodes():
		if node.unlocked and node.node_type != SphereGrid.NodeType.START:
			_apply_sphere_grid_node(node)

func _parse_stat_label(label: String) -> Dictionary:
	## Parses labels like "STR +3" → { "stat": "strength", "value": 3 }
	var stat_map = {
		"STR": "strength",
		"DEX": "dexterity",
		"INT": "intelligence",
		"WIS": "wisdom",
		"AGI": "agility",
		"DET": "determination",
	}
	for abbr in stat_map:
		if label.begins_with(abbr):
			var value = _parse_numeric_value(label)
			if value > 0:
				return { "stat": stat_map[abbr], "value": value }
	return {}

func _parse_numeric_value(label: String) -> int:
	## Extracts the first integer from a label like "HP +10" or "Mana +5"
	var regex = RegEx.new()
	regex.compile("\\+(\\d+)")
	var result = regex.search(label)
	if result:
		return int(result.get_string(1))
	# Try without + sign
	regex.compile("(\\d+)")
	result = regex.search(label)
	if result:
		return int(result.get_string(1))
	return 0

func _parse_passive_description(desc: String, node_id: int) -> Dictionary:
	## Parses passive descriptions like "On kill: heal 1 HP" into structured data.
	## Returns { "node_id": int, "trigger": String, "effect": String, "value": float, "chance": float }
	var passive: Dictionary = { "node_id": node_id, "trigger": "", "effect": "", "value": 0, "chance": 1.0 }

	# Extract trigger (everything before the colon)
	var colon_idx = desc.find(":")
	if colon_idx < 0:
		return {}

	var trigger_part = desc.substr(0, colon_idx).strip_edges().to_lower()
	var effect_part = desc.substr(colon_idx + 1).strip_edges().to_lower()

	# Map trigger text to trigger ID
	var trigger_map = {
		"on kill": "on_kill",
		"on card play": "on_card_play",
		"on move": "on_move",
		"on cycle": "on_cycle",
		"on tempo cycle": "on_tempo_cycle",
		"on attack": "on_attack",
		"on dodge": "on_dodge",
		"on heal": "on_heal",
		"on block": "on_block",
		"on crit": "on_crit",
		"on spell cast": "on_spell_cast",
		"on discard": "on_discard",
		"on draw": "on_draw",
	}

	for text in trigger_map:
		if trigger_part == text:
			passive["trigger"] = trigger_map[text]
			break

	if passive["trigger"] == "":
		return {}

	# Check for percentage chance (e.g., "5% draw extra" or "10% apply bleed")
	var chance_regex = RegEx.new()
	chance_regex.compile("(\\d+)%\\s*(.*)")
	var chance_match = chance_regex.search(effect_part)
	if chance_match:
		passive["chance"] = float(chance_match.get_string(1)) / 100.0
		effect_part = chance_match.get_string(2)

	# Parse the effect and value
	var value_regex = RegEx.new()
	value_regex.compile("(\\d+)")
	var value_match = value_regex.search(effect_part)
	if value_match:
		passive["value"] = int(value_match.get_string(1))

	# Categorize the effect
	if "heal" in effect_part and "hp" in effect_part:
		passive["effect"] = "heal"
	elif "heal" in effect_part:
		passive["effect"] = "heal"
	elif "draw" in effect_part:
		passive["effect"] = "draw_card"
	elif "armor" in effect_part:
		passive["effect"] = "gain_armor"
	elif "mana" in effect_part and "regen" in effect_part:
		passive["effect"] = "regen_mana"
	elif "mana" in effect_part and "gain" in effect_part:
		passive["effect"] = "gain_mana"
	elif "mana" in effect_part:
		passive["effect"] = "gain_mana"
	elif "bleed" in effect_part:
		passive["effect"] = "apply_bleed"
	elif "tempo" in effect_part:
		passive["effect"] = "gain_tempo"
	elif "cleanse" in effect_part:
		passive["effect"] = "cleanse_debuff"
	elif "reflect" in effect_part:
		passive["effect"] = "reflect_damage"
	elif "bonus" in effect_part and "damage" in effect_part:
		passive["effect"] = "bonus_damage"
	elif "deal" in effect_part and "damage" in effect_part:
		passive["effect"] = "deal_damage"
	elif "stun" in effect_part:
		passive["effect"] = "stun_enemy"
	elif "counterattack" in effect_part:
		passive["effect"] = "counterattack"
	elif "haste" in effect_part:
		passive["effect"] = "gain_haste"
	elif "empower" in effect_part:
		passive["effect"] = "gain_empower"
	elif "double cast" in effect_part:
		passive["effect"] = "double_cast"
	elif "refund" in effect_part:
		passive["effect"] = "refund_mana"
	elif "return" in effect_part:
		passive["effect"] = "return_to_hand"
	elif "cost" in effect_part and "less" in effect_part:
		passive["effect"] = "reduce_cost"
	elif "freeze" in effect_part:
		passive["effect"] = "freeze_enemy"
	elif "overheal" in effect_part:
		passive["effect"] = "overheal_armor"
	elif "costs 0" in effect_part:
		passive["effect"] = "free_draw"
	else:
		passive["effect"] = effect_part  # Store raw text as fallback

	passive["description"] = desc
	return passive

# ============================================
# CONSTELLATION COMPLETION
# ============================================

var _active_constellations: Array[String] = []  # IDs of completed constellations

func _on_constellation_completed(constellation_id: String) -> void:
	## Called when the player completes a constellation on the sphere grid.
	var grid = sphere_grid_ui.sphere_grid
	var c = grid.get_constellation(constellation_id)
	if not c:
		return

	_active_constellations.append(constellation_id)
	_apply_constellation_bonus(constellation_id)
	add_battle_log("CONSTELLATION COMPLETE: %s" % c.name, c.color)
	add_battle_log("Bonus: %s" % c.bonus_description, Color(0.9, 0.85, 0.5))
	print("[MAIN] Constellation completed: %s — %s" % [c.name, c.bonus_description])

func _apply_constellation_bonus(constellation_id: String) -> void:
	## Applies the permanent bonus from a completed constellation.
	var stats = player.get_stats()
	if not stats:
		return

	match constellation_id:
		"iron_will":
			# On kill: gain 3 armor and heal 2 HP — register as a sphere passive
			stats.add_sphere_grid_passive({
				"node_id": -1, "trigger": "on_kill", "effect": "iron_will",
				"value": 0, "chance": 1.0,
				"description": "Iron Will: On kill: gain 3 armor and heal 2 HP"
			})
		"blood_hunter":
			# +15% bleed on attacks, bleed +2/tick — register as a sphere passive
			stats.add_sphere_grid_passive({
				"node_id": -1, "trigger": "on_attack", "effect": "blood_hunter",
				"value": 0, "chance": 0.15,
				"description": "Blood Hunter: 15% bleed on attacks, bleed +2/tick"
			})
		"arcane_current":
			# Spell cards deal +5 bonus damage — register as a sphere passive
			stats.add_sphere_grid_passive({
				"node_id": -1, "trigger": "on_spell_cast", "effect": "arcane_current",
				"value": 5, "chance": 1.0,
				"description": "Arcane Current: Spell cards deal +5 bonus damage"
			})
		"mind_weaver":
			# On spell cast: 20% draw a card. +3 max mana
			stats.apply_sphere_grid_mana(3)
			stats.add_sphere_grid_passive({
				"node_id": -1, "trigger": "on_spell_cast", "effect": "draw_card",
				"value": 1, "chance": 0.20,
				"description": "Mind Weaver: 20% chance to draw a card on spell cast"
			})
		"windwalker":
			# +1 movement, first card after moving costs 1 less
			stats.add_sphere_grid_passive({
				"node_id": -1, "trigger": "on_move", "effect": "reduce_cost",
				"value": 1, "chance": 1.0,
				"description": "Windwalker: First card after moving costs 1 less"
			})
			# +1 movement via agility
			stats.apply_sphere_grid_stat("agility", 5)  # +5 AGI = +1 move/cycle
		"storm_runner":
			# +1 movement, gain 2 mana on move
			stats.add_sphere_grid_passive({
				"node_id": -1, "trigger": "on_move", "effect": "gain_mana",
				"value": 2, "chance": 1.0,
				"description": "Storm Runner: Gain 2 mana on each move"
			})
			stats.apply_sphere_grid_stat("agility", 5)  # +5 AGI = +1 move/cycle
		"sages_insight":
			# Draw 1 extra card per tempo cycle
			stats.add_sphere_grid_passive({
				"node_id": -1, "trigger": "on_cycle", "effect": "draw_card",
				"value": 1, "chance": 1.0,
				"description": "Sage's Insight: Draw 1 extra card per tempo cycle"
			})
		"unyielding":
			# Below 50% HP: gain 3 armor each cycle, +20% determination
			stats.add_sphere_grid_passive({
				"node_id": -1, "trigger": "on_cycle", "effect": "unyielding",
				"value": 3, "chance": 1.0,
				"description": "Unyielding: Below 50% HP: gain 3 armor each cycle"
			})
			stats.apply_sphere_grid_stat("determination", 2)

# ============================================
# SKILL TREE → CHARACTER SYNC
# ============================================

func _on_skill_tree_option_chosen(level: int, option_index: int) -> void:
	## Called when the player chooses one of the 4 options in a skill tree row.
	var tree = skill_tree_ui.skill_tree
	if not tree:
		return
	var row = tree.get_row_for_level(level)
	if not row:
		return
	var option = row.get_chosen_option()
	if not option:
		return

	print("[MAIN] Skill tree choice at level %d: %s (%s)" % [level, option.name, option.get_type_label()])
	_apply_skill_tree_option(option)

func _on_skill_tree_auto_grant_claimed(level: int) -> void:
	## Called when a stat allocation or other auto-grant is confirmed.
	print("[MAIN] Skill tree auto-grant claimed for level %d" % level)
	# Future: apply stat allocations, card removals, upgrades, etc.

func _on_skill_tree_retrospective_chosen(level: int, option_index: int) -> void:
	## Called when the player uses a retrospective token to reclaim a skipped option.
	var tree = skill_tree_ui.skill_tree
	if not tree:
		return
	var row = tree.get_row_for_level(level)
	if not row or option_index < 0 or option_index >= row.options.size():
		return
	var option = row.options[option_index]
	print("[MAIN] Retrospective pick at level %d: %s (%s)" % [level, option.name, option.get_type_label()])
	_apply_skill_tree_option(option)

func _apply_skill_tree_option(option) -> void:
	## Applies a chosen skill tree option's effect to the player.
	var stats = player.get_stats()
	if not stats:
		return

	if option.option_type == SkillTreeData.OptionType.PASSIVE or option.option_type == SkillTreeData.OptionType.PASSIVE_MUTATION:
		var pid = option.passive_id
		if pid == "":
			pid = option.name.to_lower().replace(" ", "_")

		# Special handling for stat-granting passives (apply immediately + register)
		match pid:
			"ladder_work":
				# Ryan: +3 dexterity and +3 agility
				stats.base_dexterity += 3
				stats.base_agility += 3
				stats.stats_updated.emit()
				add_battle_log("Ladder Work: +3 DEX, +3 AGI", Color(0.3, 0.7, 1.0))
			"stone_skin":
				# Brad: +10% Fire, Physical, Lightning resistance
				stats.add_skill_tree_passive(pid)
				add_battle_log("Stone Skin: +10%% Fire/Physical/Lightning resistance", Color(0.4, 0.9, 0.4))
			"deadly":
				# Stephen: +3 flat damage (tracked via passive, applied on attack)
				stats.add_skill_tree_passive(pid)
				add_battle_log("Deadly: +3 damage on all attacks", Color(0.9, 0.3, 0.3))
			"eagle_eye":
				# Stephen: +2 range on ranged attacks (tracked via passive)
				stats.add_skill_tree_passive(pid)
				add_battle_log("Eagle Eye: +2 range on ranged attacks", Color(0.4, 0.9, 0.4))
			"sword_specialist":
				# Stephen: +25% block when only wielding swords (tracked via passive)
				stats.add_skill_tree_passive(pid)
				add_battle_log("Sword Specialist: +25%% block with swords only", Color(0.3, 0.7, 1.0))
			_:
				stats.add_skill_tree_passive(pid)
				add_battle_log("Passive unlocked: %s" % option.name, Color(0.9, 0.7, 0.2))

	elif option.option_type == SkillTreeData.OptionType.STAT_BONUS:
		if option.stat_type != "" and option.stat_amount > 0:
			match option.stat_type:
				"strength": stats.base_strength += option.stat_amount
				"dexterity": stats.base_dexterity += option.stat_amount
				"intelligence": stats.base_intelligence += option.stat_amount
				"wisdom": stats.base_wisdom += option.stat_amount
				"agility": stats.base_agility += option.stat_amount
				"determination": stats.determination += option.stat_amount
			stats.stats_updated.emit()
			add_battle_log("+%d %s" % [option.stat_amount, option.stat_type.capitalize()], Color(0.3, 0.8, 1.0))

	elif option.option_type == SkillTreeData.OptionType.CARD:
		if option.card_id != "":
			if deck_manager.add_card_to_deck_from_id(option.card_id):
				add_battle_log("Card added: %s" % option.name, Color(0.5, 1.0, 0.5))

# ============================================
# SKILL TREE PASSIVE TRIGGERS
# ============================================

func _trigger_skill_tree_on_discard(card: Card) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Keep Them Guessing: -1t from a random card in hand
	if stats.has_skill_tree_passive("keep_them_guessing"):
		if deck_manager and deck_manager.hand.size() > 0:
			var random_idx = randi() % deck_manager.hand.size()
			var target_card = deck_manager.hand[random_idx]
			if target_card.tempo_cost > 0:
				target_card.tempo_cost -= 1
				add_battle_log("Keep Them Guessing: %s -1t" % target_card.card_name, Color(0.9, 0.3, 0.3))

func _trigger_skill_tree_on_card_play(card: Card, target) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# From the Hip: clear the discount when any card is played
	if stats.has_skill_tree_passive("from_the_hip") and stats.st_from_hip_card != null:
		var discounted = stats.st_from_hip_card
		if is_instance_valid(discounted):
			discounted.mana_cost = stats.st_from_hip_original_cost
		stats.st_from_hip_card = null
		stats.st_from_hip_original_cost = 0

	# Nimble Assault: no Defense cards in hand → draw on attack
	if stats.has_skill_tree_passive("nimble_assault") and card.card_type == Card.CardType.ATTACK:
		var has_defense = false
		for c in deck_manager.hand:
			if c.card_type == Card.CardType.DEFENSE:
				has_defense = true
				break
		if not has_defense:
			deck_manager.attempt_draw()
			add_battle_log("Nimble Assault: drew a card!", Color(0.9, 0.3, 0.3))

	# Quick Step: instant played from hand → +5 armor
	if stats.has_skill_tree_passive("quick_step"):
		if card.card_type == Card.CardType.REACTION or card.tempo_cost == 0:
			stats.add_armor(5)
			add_battle_log("Quick Step: +5 armor", Color(0.3, 0.7, 1.0))

func _trigger_skill_tree_on_draw(card: Card) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# From the Hip: if an attack card, discount the most recently drawn card by -1m
	if stats.has_skill_tree_passive("from_the_hip") and card.card_type == Card.CardType.ATTACK:
		# Clear previous discount if any
		if stats.st_from_hip_card != null and is_instance_valid(stats.st_from_hip_card):
			stats.st_from_hip_card.mana_cost = stats.st_from_hip_original_cost
		# Apply new discount
		if card.mana_cost > 0:
			stats.st_from_hip_original_cost = card.mana_cost
			card.mana_cost -= 1
			stats.st_from_hip_card = card
			add_battle_log("From the Hip: %s -1m" % card.card_name, Color(0.9, 0.3, 0.3))

func _trigger_skill_tree_on_attack(card: Card, target) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Surprise Opener: bonus damage on first strike per enemy
	if stats.has_skill_tree_passive("surprise_opener") and target and target is Enemy:
		var enemy_id = target.get_instance_id()
		if enemy_id not in stats.st_enemy_first_strikes:
			stats.st_enemy_first_strikes[enemy_id] = true
			var bonus = 2
			if target.current_armor <= 0:
				bonus += 2
			# Check if this is the enemy's first source of damage (full HP = no prior damage)
			if target.current_health >= target.max_health:
				bonus += 2
			target.take_damage(bonus, true)
			add_battle_log("Surprise Opener: +%d bonus damage!" % bonus, Color(0.8, 0.4, 0.9))

func _trigger_skill_tree_on_crit(target) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Eye Scrape: every 3rd crit → invisibility
	if stats.has_skill_tree_passive("eye_scrape"):
		stats.st_crit_counter += 1
		if stats.st_crit_counter >= 3:
			stats.st_crit_counter = 0
			var buff_mgr = player.get_buff_manager()
			if buff_mgr:
				buff_mgr.apply_buff(Buff.create_invisible(10, "Eye Scrape"))
				_set_player_invisible(true)
				add_battle_log("Eye Scrape: Invisibility!", Color(0.8, 0.4, 0.9))

func _trigger_skill_tree_on_cycle() -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Pop Rocks: check all enemies for expired debuffs — handled per enemy in tempo processing
	# (See _process_enemy_debuff_expiry)

	# Let's Dance: movement cycle → +3 armor (handled in movement section)
	pass

func _trigger_skill_tree_on_heal_ally(ally_name: String) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Field Medic: when Ryan heals an ally, +2 STR for 10 tempo to the ally
	if stats.has_skill_tree_passive("field_medic"):
		add_battle_log("Field Medic: %s gains +2 STR (10t)" % ally_name, Color(0.4, 0.9, 0.4))
		# Ally buff would be applied through the ally's buff system when allies are implemented

	# Brad: Redemption — heal ally → +10% crit on next attack
	_trigger_skill_tree_brad_on_heal_ally(ally_name)

func _trigger_skill_tree_on_displacement() -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Now You See Me: displacement → invisibility
	if stats.has_skill_tree_passive("now_you_see_me"):
		var buff_mgr = player.get_buff_manager()
		if buff_mgr:
			buff_mgr.apply_buff(Buff.create_invisible(10, "Now You See Me"))
			_set_player_invisible(true)
			add_battle_log("Now You See Me: Invisibility!", Color(0.8, 0.4, 0.9))

var _toxic_fumes_spreading: bool = false  # Guard against infinite spread loops

func _trigger_skill_tree_on_debuff_applied(target, debuff_name: String, value: int) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Toxic Fumes: spread debuffs to nearby enemies (guard against recursive spread)
	if stats.has_skill_tree_passive("toxic_fumes") and target and not _toxic_fumes_spreading:
		_toxic_fumes_spreading = true
		var nearby = enemy_spawner.get_enemies_in_radius(target.position, 3.0)
		for enemy in nearby:
			if enemy != target and enemy.has_method("apply_debuff"):
				enemy.apply_debuff(debuff_name, value)
		if nearby.size() > 1:
			add_battle_log("Toxic Fumes: %s spread to %d enemies" % [debuff_name, nearby.size() - 1], Color(0.4, 0.9, 0.4))
		_toxic_fumes_spreading = false

func _trigger_skill_tree_on_debuff_expired(target) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Pop Rocks: deal 2 damage when debuffs expire on enemy
	if stats.has_skill_tree_passive("pop_rocks") and target and target.has_method("take_damage"):
		target.take_damage(2, true)
		add_battle_log("Pop Rocks: 2 damage!", Color(0.4, 0.9, 0.4))

func _trigger_skill_tree_on_movement_cycle() -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Let's Dance: movement triggers a cycle → +3 armor
	if stats.has_skill_tree_passive("let's_dance"):
		stats.add_armor(3)
		add_battle_log("Let's Dance: +3 armor", Color(0.3, 0.7, 1.0))

# ============================================
# BRAD SKILL TREE PASSIVE TRIGGERS
# ============================================

func _trigger_skill_tree_brad_on_damage_taken(damage: int) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Enraged Will: below 10% HP → Reach AOE swing (1 base + 1 Reach = 2 range) + gain 1 mana per kill
	if stats.has_skill_tree_passive("enraged_will"):
		if stats.get_health_percent() <= 0.10 and stats.current_health > 0:
			var enemies = enemy_spawner.get_enemies_in_radius(player.position, 2.0) if enemy_spawner else []
			if enemies.size() > 0:
				var dmg = stats.get_effective_physical_damage(0)
				var kills = 0
				for enemy in enemies:
					enemy.take_damage(dmg, true)
					if not enemy.is_alive():
						kills += 1
				if kills > 0:
					stats.gain_mana(kills)
				add_battle_log("Enraged Will: AOE swing for %d! (+%d mana)" % [dmg, kills], Color(0.9, 0.3, 0.3))

	# Dark Forces: when exposed (armor broken to 0), gain +3 damage to next strike
	if stats.has_skill_tree_passive("dark_forces"):
		if stats.current_armor <= 0 and damage > 0:
			stats.st_dark_forces_bonus = 3
			add_battle_log("Dark Forces: +3 damage on next strike!", Color(0.8, 0.4, 0.9))

func _trigger_skill_tree_brad_on_attacked(attacker) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# In the Trenches: when attacked from adjacent, knock attacker back (consumes 1 charge)
	if stats.has_skill_tree_passive("in_the_trenches"):
		_itt_try_refresh_charges(stats)
		if stats.st_itt_charges > 0:
			if attacker and attacker.has_method("knockback"):
				stats.st_itt_charges -= 1
				attacker.knockback(player.position)
				add_battle_log("In the Trenches: knocked back %s! (%d charge(s) left)" % [attacker.enemy_name, stats.st_itt_charges], Color(0.3, 0.7, 1.0))
				if stats.st_itt_charges <= 0:
					stats.st_itt_last_used_tempo = tempo_manager.get_global_tempo()

func _trigger_skill_tree_brad_itt_on_enter(enemy: Enemy) -> void:
	## In the Trenches: free attack when an enemy enters an adjacent square (consumes 1 charge)
	var stats = player.get_stats()
	if not stats:
		return
	if not stats.has_skill_tree_passive("in_the_trenches"):
		return
	_itt_try_refresh_charges(stats)
	if stats.st_itt_charges <= 0:
		return
	stats.st_itt_charges -= 1
	var dmg = stats.get_effective_physical_damage(0)
	enemy.take_damage(dmg, true)
	add_battle_log("In the Trenches: free attack on %s for %d! (%d charge(s) left)" % [enemy.enemy_name, dmg, stats.st_itt_charges], Color(0.3, 0.7, 1.0))
	if stats.st_itt_charges <= 0:
		stats.st_itt_last_used_tempo = tempo_manager.get_global_tempo()

func _itt_try_refresh_charges(stats: PlayerStats) -> void:
	## Refresh In the Trenches charges if 10 tempo has passed since last exhaustion.
	if stats.st_itt_charges <= 0:
		var elapsed = tempo_manager.get_global_tempo() - stats.st_itt_last_used_tempo
		if elapsed >= 10:
			stats.st_itt_charges = 2

func _trigger_skill_tree_brad_on_defense_card_play(card: Card) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# The Way of the Plate: every other Defense card costs -1m/-1t
	if stats.has_skill_tree_passive("the_way_of_the_plate"):
		stats.st_defense_cards_played += 1
		if stats.st_defense_cards_played >= 2:
			stats.st_defense_cards_played = 0
			# Refund 1 mana and 1 tempo
			stats.gain_mana(1)
			tempo_manager.add_tempo(-1)
			add_battle_log("Way of the Plate: -1m/-1t refund!", Color(0.3, 0.7, 1.0))

	# Pristine Armor: +2 armor on defense cards, +5 bonus for 3 in a row
	if stats.has_skill_tree_passive("pristine_armor"):
		stats.add_armor(2)
		stats.st_consecutive_defense += 1
		if stats.st_consecutive_defense >= 3:
			stats.st_consecutive_defense = 0
			stats.add_armor(5)
			add_battle_log("Pristine Armor: +2 armor, +5 bonus (3 in a row)!", Color(0.3, 0.7, 1.0))
		else:
			add_battle_log("Pristine Armor: +2 armor", Color(0.3, 0.7, 1.0))

func _trigger_skill_tree_brad_on_heal() -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Vines Codependence: whenever you heal, gain 3 thorns
	if stats.has_skill_tree_passive("vines_codependence"):
		var buff_mgr = player.get_buff_manager()
		if buff_mgr:
			buff_mgr.apply_buff(Buff.new(Buff.BuffType.THORNS, 3, 30))
			add_battle_log("Vines Codependence: +3 thorns", Color(0.4, 0.9, 0.4))

	# Redemption: gain crit buff when healing (self or ally)
	if stats.has_skill_tree_passive("redemption"):
		var buff_mgr = player.get_buff_manager()
		if buff_mgr:
			buff_mgr.apply_buff(Buff.create_focused(10, "Redemption"))
			add_battle_log("Redemption: crit on next attack!", Color(0.8, 0.4, 0.9))

func _trigger_skill_tree_brad_on_heal_ally(ally_name: String) -> void:
	var stats = player.get_stats()
	if not stats:
		return
	# Redemption for ally heals is now handled in _trigger_skill_tree_brad_on_heal
	# which fires on all heals (self and ally). This function remains for
	# ally-specific effects from other characters (e.g. Field Medic).
	pass

func _trigger_skill_tree_brad_on_cycle() -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Ancestral Aid: depends on hand composition — more attacks = -2m to attack, more defense = +3 HP regen
	if stats.has_skill_tree_passive("ancestral_aid"):
		var attack_count = 0
		var defense_count = 0
		for c in deck_manager.hand:
			if c.card_type == Card.CardType.ATTACK:
				attack_count += 1
			elif c.card_type == Card.CardType.DEFENSE:
				defense_count += 1
		if attack_count > defense_count:
			# Discount a random attack card by 2 mana
			var attacks: Array[Card] = []
			for c in deck_manager.hand:
				if c.card_type == Card.CardType.ATTACK and c.mana_cost >= 2:
					attacks.append(c)
			if attacks.size() > 0:
				var target_card = attacks[randi() % attacks.size()]
				target_card.mana_cost -= 2
				add_battle_log("Ancestral Aid: %s -2m (offense)" % target_card.card_name, Color(0.4, 0.9, 0.4))
		elif defense_count > attack_count:
			stats.heal(3)
			add_battle_log("Ancestral Aid: +3 HP regen (defense)", Color(0.4, 0.9, 0.4))
		else:
			# Tied — small heal
			stats.heal(1)
			add_battle_log("Ancestral Aid: +1 HP (balanced)", Color(0.4, 0.9, 0.4))

	# Directed Strength is checked at attack time, not per-cycle

func _trigger_skill_tree_brad_on_attack(card: Card, target) -> int:
	## Returns bonus damage from Brad passives.
	var stats = player.get_stats()
	if not stats:
		return 0
	var bonus = 0

	# Directed Strength: -5 STR above 50% HP, +5 STR below 50%
	if stats.has_skill_tree_passive("directed_strength"):
		if stats.get_health_percent() <= 0.5:
			bonus += 5
		else:
			bonus -= 5

	# Life Steal: all attacks life steal by 5%
	if stats.has_skill_tree_passive("life_steal"):
		var buff_mgr = player.get_buff_manager()
		if buff_mgr and not buff_mgr.has_life_steal():
			buff_mgr.apply_buff(Buff.create_life_steal("Life Steal (Passive)"))

	# Dark Forces: consume stored bonus damage
	if stats.has_skill_tree_passive("dark_forces") and stats.st_dark_forces_bonus > 0:
		bonus += stats.st_dark_forces_bonus
		stats.st_dark_forces_bonus = 0
		add_battle_log("Dark Forces: +%d damage!" % bonus, Color(0.8, 0.4, 0.9))

	return bonus

var _ptp_confirmed_callable: Callable
var _ptp_declined_callable: Callable

func _on_point_to_prove_triggered(debuff: Debuff) -> void:
	## Show dialog asking the player if they want to sacrifice HP to ignore the debuff.
	# Disconnect any previous one-shot connections
	if _ptp_confirmed_callable.is_valid() and point_to_prove_dialog.confirmed.is_connected(_ptp_confirmed_callable):
		point_to_prove_dialog.confirmed.disconnect(_ptp_confirmed_callable)
	if _ptp_declined_callable.is_valid() and point_to_prove_dialog.declined.is_connected(_ptp_declined_callable):
		point_to_prove_dialog.declined.disconnect(_ptp_declined_callable)

	var debuff_name = Debuff.DebuffType.keys()[debuff.debuff_type].capitalize()
	var cost = 5
	point_to_prove_dialog.show_dialog(debuff_name, debuff.debuff_type, cost)
	_ptp_confirmed_callable = _on_point_to_prove_confirmed.bind(debuff)
	_ptp_declined_callable = _on_point_to_prove_declined
	point_to_prove_dialog.confirmed.connect(_ptp_confirmed_callable, CONNECT_ONE_SHOT)
	point_to_prove_dialog.declined.connect(_ptp_declined_callable, CONNECT_ONE_SHOT)

func _on_point_to_prove_confirmed(debuff_type: int, debuff: Debuff) -> void:
	var stats = player.get_stats()
	if not stats:
		return
	# Sacrifice HP to remove the debuff
	stats.take_direct_damage(5)
	var debuff_mgr = player.get_debuff_manager()
	if debuff_mgr:
		debuff_mgr.remove_debuff(debuff.debuff_type)
	var debuff_name = Debuff.DebuffType.keys()[debuff_type].capitalize()
	add_battle_log("Point to Prove: Sacrificed 5 HP to ignore %s!" % debuff_name, Color(0.9, 0.7, 0.3))

func _on_point_to_prove_declined(debuff_type: int) -> void:
	var debuff_name = Debuff.DebuffType.keys()[debuff_type].capitalize()
	add_battle_log("Point to Prove: Accepted %s." % debuff_name, Color(0.6, 0.6, 0.6))

# ============================================
# STEPHEN SKILL TREE PASSIVE TRIGGERS
# ============================================

func _trigger_skill_tree_stephen_on_attack(card: Card, target) -> int:
	## Returns bonus damage from Stephen passives.
	var stats = player.get_stats()
	if not stats:
		return 0
	var bonus = 0

	# Deadly: +3 flat damage on all attacks
	if stats.has_skill_tree_passive("deadly"):
		bonus += 3

	# Scouted: if enemy hasn't moved in 10+ tempo, +3 damage
	if stats.has_skill_tree_passive("scouted") and target and target is Enemy:
		var enemy_id = target.get_instance_id()
		var last_move = stats.st_enemy_last_move_tempo.get(enemy_id, -999)
		var current_tempo = tempo_manager.get_global_tempo()
		if current_tempo - last_move >= 10:
			bonus += 3
			add_battle_log("Scouted: +3 damage (stationary target)", Color(0.4, 0.9, 0.4))

	# Skilled Momentum: 4 attacks in a row → 5th plays twice
	if stats.has_skill_tree_passive("skilled_momentum") and card.card_type == Card.CardType.ATTACK:
		stats.st_consecutive_attacks += 1
		if stats.st_consecutive_attacks >= 5:
			stats.st_consecutive_attacks = 0
			# Deal the card's damage again
			if target and target.has_method("take_damage"):
				var extra_dmg = card.last_damage_dealt if card.last_damage_dealt > 0 else stats.get_effective_physical_damage(card.base_damage)
				target.take_damage(extra_dmg, true)
				add_battle_log("Skilled Momentum: double strike for %d!" % extra_dmg, Color(0.9, 0.3, 0.3))

	# Swing for the Fences: cards with >4 tempo cost deal tempo cost as additional damage
	if stats.has_skill_tree_passive("swing_for_the_fences") and card.tempo_cost > 4:
		bonus += card.tempo_cost
		add_battle_log("Swing for the Fences: +%d damage!" % card.tempo_cost, Color(0.8, 0.4, 0.9))

	return bonus

func _trigger_skill_tree_stephen_on_ranged_attack(card: Card, target) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Laced Arrow: +1 burn, +1 shock, +1 cold on ranged attacks
	if stats.has_skill_tree_passive("laced_arrow") and target and target is Enemy:
		if target.has_method("apply_debuff"):
			target.apply_debuff("burn", 1)
			target.apply_debuff("shock", 1)
			target.apply_debuff("cold", 1)
			add_battle_log("Laced Arrow: +1 burn/shock/cold", Color(0.4, 0.9, 0.4))

func _trigger_skill_tree_stephen_on_expose(target) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Easy Target: when exposing an enemy, deal your damage again
	if stats.has_skill_tree_passive("easy_target") and target and target.has_method("take_damage"):
		var dmg = stats.get_effective_physical_damage(0)
		target.take_damage(dmg, true)
		add_battle_log("Easy Target: %d bonus damage on expose!" % dmg, Color(0.9, 0.3, 0.3))

func _trigger_skill_tree_stephen_on_attacked(attacker) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Phalanx: melee attack → deal damage = number of Defense cards in hand
	if stats.has_skill_tree_passive("phalanx") and attacker and attacker.has_method("take_damage"):
		var defense_count = 0
		for c in deck_manager.hand:
			if c.card_type == Card.CardType.DEFENSE:
				defense_count += 1
		if defense_count > 0:
			attacker.take_damage(defense_count, true)
			add_battle_log("Phalanx: %d damage back!" % defense_count, Color(0.3, 0.7, 1.0))

func _trigger_skill_tree_stephen_on_card_play(card: Card) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Skilled Momentum: reset counter if non-attack card is played
	if stats.has_skill_tree_passive("skilled_momentum") and card.card_type != Card.CardType.ATTACK:
		stats.st_consecutive_attacks = 0

func _trigger_skill_tree_stephen_on_disarm_applied(target, value: int) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Disarm Mastery: when applying disarm, apply 1 more
	if stats.has_skill_tree_passive("disarm_mastery") and target and target.has_method("apply_debuff"):
		target.apply_debuff("disarmed", 1)
		add_battle_log("Disarm Mastery: +1 disarm", Color(0.3, 0.7, 1.0))

func _trigger_skill_tree_stephen_on_glut(glut_amount: int) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Patience is a Virtue: on receiving Glut, deal that much damage to melee enemy and halve Glut
	if stats.has_skill_tree_passive("patience_is_a_virtue") and glut_amount > 0:
		var target = _get_nearest_enemy()
		if target and target.has_method("take_damage"):
			var dist = player.position.distance_to(target.position)
			if dist <= 2.0:  # Melee range
				target.take_damage(glut_amount, true)
				glut_tempo_remaining = max(0, glut_tempo_remaining / 2)
				add_battle_log("Patience is a Virtue: %d damage, Glut halved!" % glut_amount, Color(0.8, 0.4, 0.9))

func _trigger_skill_tree_stephen_on_dex_proc() -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Dominate: on attack speed proc, gain a 0m/0t basic attack card
	if stats.has_skill_tree_passive("dominate"):
		var free_attack = Card.create_slash()
		free_attack.mana_cost = 0
		free_attack.tempo_cost = 0
		free_attack.card_name = "Dominate Strike"
		free_attack.description = "Free basic attack from Dominate"
		deck_manager.hand.append(free_attack)
		deck_manager.hand_updated.emit()
		add_battle_log("Dominate: free 0m/0t attack card!", Color(0.8, 0.4, 0.9))

# ============================================
# CORY SKILL TREE PASSIVE TRIGGERS
# ============================================

func _trigger_skill_tree_cory_on_mana_gain(amount: int, is_regen: bool) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Energy Barrier: every 3rd non-regen mana gain → put Energy Barrier in hand
	if stats.has_skill_tree_passive("energy_barrier") and not is_regen and amount > 0:
		stats.st_mana_gain_counter += 1
		if stats.st_mana_gain_counter >= 3:
			stats.st_mana_gain_counter = 0
			var barrier = Card.create_energy_barrier()
			deck_manager.hand.append(barrier)
			deck_manager.hand_updated.emit()
			add_battle_log("Energy Barrier: defense card added to hand!", Color(0.9, 0.3, 0.3))

func _trigger_skill_tree_cory_on_card_play(card: Card) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Self Reliance: 3 cards in one tempo cycle → next card costs -1m
	if stats.has_skill_tree_passive("self_reliance"):
		stats.st_cards_this_cycle.append(card.card_type_name)
		if stats.st_cards_this_cycle.size() >= 3 and not stats.st_self_reliance_discount:
			stats.st_self_reliance_discount = true
			add_battle_log("Self Reliance: next card costs -1m!", Color(0.9, 0.3, 0.3))

	# Self Reliance: consume discount
	if stats.st_self_reliance_discount and card.mana_cost > 0:
		stats.gain_mana(1)  # Refund 1 mana as discount
		stats.st_self_reliance_discount = false
		add_battle_log("Self Reliance: -1m applied!", Color(0.9, 0.3, 0.3))

	# Budding: track card types (no back-to-back same type)
	if stats.has_skill_tree_passive("budding"):
		var ctype = ""
		match card.card_type:
			Card.CardType.ATTACK: ctype = "attack"
			Card.CardType.DEFENSE: ctype = "defense"
			Card.CardType.UTILITY: ctype = "utility"

		if ctype != "":
			if ctype == stats.st_budding_last_type:
				# Back-to-back same type — reset tracking
				stats.st_budding_types.clear()
				stats.st_budding_types.append(ctype)
			else:
				if ctype not in stats.st_budding_types:
					stats.st_budding_types.append(ctype)
			stats.st_budding_last_type = ctype

			# Check if all 3 types played
			if stats.st_budding_types.has("attack") and stats.st_budding_types.has("defense") and stats.st_budding_types.has("utility"):
				stats.heal(2)
				stats.add_armor(3)  # Temp HP represented as armor
				stats.st_budding_types.clear()
				stats.st_budding_last_type = ""
				add_battle_log("Budding: healed 2, +3 temp HP!", Color(0.8, 0.4, 0.9))

func _trigger_skill_tree_cory_on_damage_taken(damage: int) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Expel Negativity: transfer a debuff to enemy when dropping below 50% HP
	if stats.has_skill_tree_passive("expel_negativity") and not stats.st_expel_triggered:
		if stats.get_health_percent() <= 0.5:
			stats.st_expel_triggered = true
			var debuff_mgr = player.get_debuff_manager()
			if debuff_mgr and debuff_mgr.debuffs.size() > 0:
				var debuff = debuff_mgr.debuffs[randi() % debuff_mgr.debuffs.size()]
				var target = _get_nearest_enemy()
				if target and target.has_method("apply_debuff"):
					target.apply_debuff(debuff.debuff_name.to_lower(), debuff.value)
					debuff_mgr.remove_debuff(debuff.debuff_type)
					add_battle_log("Expel Negativity: transferred %s to %s!" % [debuff.debuff_name, target.enemy_name], Color(0.9, 0.3, 0.3))

func _trigger_skill_tree_cory_on_heal() -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Expel Negativity: reset trigger when healed above 50%
	if stats.has_skill_tree_passive("expel_negativity") and stats.st_expel_triggered:
		if stats.get_health_percent() > 0.5:
			stats.st_expel_triggered = false

func _trigger_skill_tree_cory_on_kill(enemy: Enemy) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Eat: killing enemies heals 10% max HP
	if stats.has_skill_tree_passive("eat"):
		var heal_amount = max(1, floori(stats.max_health * 0.10))
		stats.heal(heal_amount)
		add_battle_log("Eat: healed %d HP!" % heal_amount, Color(0.3, 0.7, 1.0))

func _trigger_skill_tree_cory_on_enemy_damaged(enemy: Enemy, damage: int) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Serial Killer: first time enemy drops below 10% HP → player invisible to them
	if stats.has_skill_tree_passive("serial_killer") and enemy.is_alive():
		var enemy_id = enemy.get_instance_id()
		if enemy_id not in stats.st_serial_killer_enemies:
			var hp_pct = float(enemy.current_health) / float(enemy.max_health)
			if hp_pct <= 0.10:
				stats.st_serial_killer_enemies[enemy_id] = true
				# Make this enemy lose sight of the player by resetting its target
				enemy.target = null
				add_battle_log("Serial Killer: invisible to %s!" % enemy.enemy_name, Color(0.3, 0.7, 1.0))

func _trigger_skill_tree_cory_on_debuff_applied(target, debuff_name: String, value: int) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Prey on the Weak: debuff on enemy below 50% HP → deal 3 damage
	if stats.has_skill_tree_passive("prey_on_the_weak") and target and target is Enemy:
		var hp_pct = float(target.current_health) / float(target.max_health)
		if hp_pct < 0.5 and target.has_method("take_damage"):
			target.take_damage(3, true)
			add_battle_log("Prey on the Weak: 3 damage to %s!" % target.enemy_name, Color(0.3, 0.7, 1.0))

func _trigger_skill_tree_cory_on_cycle() -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Self Reliance: reset cards-this-cycle counter
	stats.st_cards_this_cycle.clear()

	# Regrowth: tick cooldown
	if stats.st_regrowth_cooldown > 0:
		stats.st_regrowth_cooldown -= 5

	# Death as Lifeblood: heal for each nearby debuffed enemy
	if stats.has_skill_tree_passive("death_as_lifeblood"):
		var nearby = enemy_spawner.get_enemies_in_radius(player.position, 5.0) if enemy_spawner else []
		var debuffed_count = 0
		for enemy in nearby:
			if enemy.has_method("get_active_effects"):
				var effects = enemy.get_active_effects()
				if effects.size() > 0:
					debuffed_count += 1
		if debuffed_count > 0:
			stats.heal(debuffed_count)
			add_battle_log("Death as Lifeblood: healed %d HP" % debuffed_count, Color(0.4, 0.9, 0.4))

func _trigger_skill_tree_cory_on_hand_empty() -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Regrowth: draw 4 cards when hand is empty (cooldown 25 tempo)
	if stats.has_skill_tree_passive("regrowth") and stats.st_regrowth_cooldown <= 0:
		stats.st_regrowth_cooldown = 25
		for i in range(4):
			deck_manager.attempt_draw()
		add_battle_log("Regrowth: drew 4 cards!", Color(0.8, 0.4, 0.9))

func _trigger_skill_tree_cory_on_shuffle() -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Circle of Life: gain 15 armor and +3 damage for 3 attacks
	if stats.has_skill_tree_passive("circle_of_life"):
		stats.add_armor(15)
		var buff_mgr = player.get_buff_manager()
		if buff_mgr:
			buff_mgr.apply_buff(Buff.new(Buff.BuffType.STRENGTHEN, 3, -1, 3))
		add_battle_log("Circle of Life: +15 armor, +3 damage (3 attacks)!", Color(0.8, 0.4, 0.9))

func _trigger_skill_tree_cory_on_enemy_enter_melee(enemy: Enemy) -> void:
	var stats = player.get_stats()
	if not stats:
		return

	# Territorial Death: re-apply 1 random existing debuff
	if stats.has_skill_tree_passive("territorial_death") and enemy.has_method("get_active_effects"):
		var effects = enemy.get_active_effects()
		if effects.size() > 0:
			var random_effect = effects[randi() % effects.size()]
			var debuff_name = random_effect.get("name", "").to_lower()
			if debuff_name != "" and enemy.has_method("apply_debuff"):
				enemy.apply_debuff(debuff_name, random_effect.get("stacks", 1))
				add_battle_log("Territorial Death: re-applied %s to %s!" % [random_effect.get("name", "?"), enemy.enemy_name], Color(0.4, 0.9, 0.4))

func _apply_all_constellation_bonuses() -> void:
	## Re-applies all completed constellation bonuses (called after character select).
	var grid = sphere_grid_ui.sphere_grid
	if not grid:
		return
	for c in grid.get_all_constellations():
		if c.completed and c.id not in _active_constellations:
			_active_constellations.append(c.id)
			_apply_constellation_bonus(c.id)

func _trigger_sphere_passives(trigger: String, context: Dictionary = {}) -> void:
	## Fires all sphere grid passives matching the trigger.
	## context may contain: "target" (enemy), "card" (Card), "damage" (int), etc.
	var stats = player.get_stats()
	if not stats:
		return

	var passives = stats.get_sphere_grid_passives_for_trigger(trigger)
	for passive in passives:
		# Roll chance
		var chance = passive.get("chance", 1.0)
		if chance < 1.0 and randf() > chance:
			continue

		var value = passive.get("value", 0)
		var effect = passive.get("effect", "")

		match effect:
			"heal":
				if value > 0:
					stats.heal(value)
					add_battle_log("Passive: Healed %d HP" % value, Color(0.5, 1.0, 0.5))
			"draw_card":
				if value <= 0:
					value = 1
				for i in range(value):
					deck_manager.attempt_draw()
				add_battle_log("Passive: Drew %d card(s)" % value, Color(0.3, 0.8, 1.0))
			"gain_armor":
				if value > 0:
					stats.add_armor(value)
					add_battle_log("Passive: Gained %d armor" % value, Color(0.6, 0.6, 0.8))
			"regen_mana", "gain_mana":
				if value > 0:
					stats.gain_mana(value)
					add_battle_log("Passive: Gained %d mana" % value, Color(0.2, 0.5, 1.0))
			"apply_bleed":
				var target = context.get("target", null)
				if target and target.has_method("apply_bleed"):
					target.apply_bleed(value if value > 0 else 2)
					add_battle_log("Passive: Applied bleed", Color(0.9, 0.3, 0.3))
			"gain_tempo":
				if value > 0:
					tempo_manager.add_tempo(-value)  # Negative tempo = gain turns
					add_battle_log("Passive: Gained %d tempo" % value, Color(0.9, 0.85, 0.2))
			"cleanse_debuff":
				if player.has_method("get_debuff_manager"):
					var dbm = player.get_debuff_manager()
					if dbm and dbm.has_method("remove_random_debuff"):
						dbm.remove_random_debuff()
						add_battle_log("Passive: Cleansed a debuff", Color(0.5, 1.0, 0.8))
			"reflect_damage":
				var target = context.get("target", null)
				if target and value > 0 and target.has_method("take_damage"):
					target.take_damage(value)
					add_battle_log("Passive: Reflected %d damage" % value, Color(1.0, 0.5, 0.2))
			"deal_damage":
				# Deal damage to a random enemy or specified target
				var target = context.get("target", null)
				if not target:
					var enemies = enemy_spawner.get_alive_enemies() if enemy_spawner else []
					if enemies.size() > 0:
						target = enemies[randi() % enemies.size()]
				if target and value > 0 and target.has_method("take_damage"):
					target.take_damage(value)
					add_battle_log("Passive: Dealt %d damage" % value, Color(1.0, 0.4, 0.4))
			"stun_enemy":
				var target = context.get("target", null)
				if target and target.has_method("apply_stun"):
					target.apply_stun()
					add_battle_log("Passive: Stunned enemy", Color(1.0, 1.0, 0.3))
			"gain_haste":
				if player.has_method("get_buff_manager"):
					var bm = player.get_buff_manager()
					if bm and bm.has_method("apply_buff"):
						bm.apply_buff(Buff.create_haste(5))
						add_battle_log("Passive: Gained haste", Color(0.3, 1.0, 0.5))
			"gain_empower":
				stats.apply_empower(1)
				add_battle_log("Passive: Gained empower", Color(1.0, 0.8, 0.3))
			"refund_mana":
				var card = context.get("card", null)
				if card:
					stats.gain_mana(card.mana_cost)
					add_battle_log("Passive: Refunded %d mana" % card.mana_cost, Color(0.2, 0.5, 1.0))
			"return_to_hand":
				var card = context.get("card", null)
				if card:
					# Move from discard back to hand
					var idx = deck_manager.discard_pile.find(card)
					if idx >= 0:
						deck_manager.discard_pile.remove_at(idx)
						deck_manager.add_card_to_hand(card)
						add_battle_log("Passive: %s returned to hand" % card.card_name, Color(0.7, 0.7, 1.0))
			"reduce_cost":
				# Reduce next card cost by value
				if value > 0:
					deck_manager.prep_utility_discount = value
					deck_manager.prep_utility_charges = 1
					add_battle_log("Passive: Next card costs %d less" % value, Color(0.8, 0.8, 0.3))
			"bonus_damage":
				# Handled at damage calculation time via context
				pass
			"counterattack":
				var target = context.get("target", null)
				if target and target.has_method("take_damage"):
					var dmg = stats.get_effective_physical_damage(5)
					target.take_damage(dmg)
					add_battle_log("Passive: Counterattack for %d" % dmg, Color(1.0, 0.5, 0.2))
			"overheal_armor":
				# This is handled in the heal flow — check overheal and convert
				var overheal = context.get("overheal", 0)
				if overheal > 0:
					stats.add_armor(overheal)
					add_battle_log("Passive: Overheal → %d armor" % overheal, Color(0.6, 0.8, 1.0))
			"free_draw":
				# Next drawn card costs 0 — apply via prep system
				deck_manager.prep_utility_discount = 99
				deck_manager.prep_utility_charges = 1
				add_battle_log("Passive: Next card costs 0", Color(0.8, 0.8, 0.3))
			"iron_will":
				# Constellation: On kill: gain 3 armor and heal 2 HP
				stats.add_armor(3)
				stats.heal(2)
				add_battle_log("Iron Will: +3 armor, healed 2 HP", Color(0.9, 0.45, 0.25))
			"blood_hunter":
				# Constellation: 15% chance to apply bleed on attack
				var target = context.get("target", null)
				if target and target.has_method("apply_bleed"):
					target.apply_bleed(4)  # Base 2 + 2 bonus from constellation
					add_battle_log("Blood Hunter: Applied enhanced bleed!", Color(0.75, 0.15, 0.15))
			"arcane_current":
				# Constellation: +5 spell damage — applied as bonus damage on the card
				var card = context.get("card", null)
				if card:
					card.bonus_damage += 5
					add_battle_log("Arcane Current: +5 spell damage", Color(0.5, 0.2, 0.85))
			"unyielding":
				# Constellation: Below 50% HP: gain 3 armor each cycle
				if stats.current_health <= stats.max_health / 2:
					stats.add_armor(value)
					add_battle_log("Unyielding: +%d armor (low HP)" % value, Color(0.85, 0.7, 0.2))
			_:
				print("[MAIN] Unhandled sphere passive effect: %s" % effect)

func _update_enemy_count() -> void:
	test_ui.update_enemy_count(enemy_spawner.get_enemy_count())

func _on_turn_ended(turn_number: int) -> void:
	update_deck_info()

func _on_player_health_changed(current: int, max_hp: int) -> void:
	if player_health_label:
		player_health_label.text = "HP: %d / %d" % [current, max_hp]

	# Trigger instant reaction cards when HP drops below 50%
	var stats = player.get_stats()
	if stats and current > 0 and current < max_hp * 0.5:
		var triggered = deck_manager.trigger_reactions("on_hp_below_50")
		for card in triggered:
			if card.card_id == "gift_from_the_phoenix":
				var heal_target = int(max_hp * 0.8)
				var heal_amount = heal_target - current
				if heal_amount > 0:
					stats.heal(heal_amount)
				# Apply 5 burn to nearest enemy
				var nearest_enemy: Enemy = null
				var nearest_dist = INF
				for e in enemy_spawner.get_living_enemies():
					var d = (e.position - player.position).length()
					if d < nearest_dist:
						nearest_dist = d
						nearest_enemy = e
				if nearest_enemy:
					nearest_enemy.apply_debuff("burn", 5)
					print("[MAIN] Gift of the Phoenix: applied 5 burn to %s" % nearest_enemy.enemy_name)
				add_battle_log("Gift of the Phoenix! Healed to 80%% HP!", Color(1.0, 0.5, 0.2))
				print("[MAIN] Gift of the Phoenix triggered! Healed %d HP to %d/%d" % [heal_amount, heal_target, max_hp])

func _on_player_mana_changed(current: float, max_mana: int) -> void:
	if player_mana_label:
		var stats = player.get_stats()
		if stats and stats.maintained_mana > 0:
			player_mana_label.text = "Mana: %d / %d (%dM reserved)" % [int(current), max_mana, stats.maintained_mana]
		else:
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
	# Stephen: Dominate — on dex proc, gain free attack card
	_trigger_skill_tree_stephen_on_dex_proc()

func _on_maintained_cards_broken() -> void:
	## Called when player's mana hits 0 - all maintained Power cards are discarded
	deck_manager.break_all_maintained_cards()
	print("[MAIN] All maintained cards broken due to mana depletion!")

func _on_player_health_damage_taken(hp_amount: int) -> void:
	## Process maintained card effects that trigger on HP damage
	if hp_amount <= 0:
		# Damage was fully absorbed by armor → trigger on_block passives
		_trigger_sphere_passives("on_block", {})
		return
	player.spawn_damage_number(hp_amount)
	var stats = player.get_stats()
	for card in deck_manager.get_maintained_cards():
		if card.card_id == "armored_discipline":
			stats.add_armor(hp_amount)
			print("[MAIN] Armored Discipline: gained %d armor from %d HP damage!" % [hp_amount, hp_amount])

	# Skill tree passive triggers on damage taken
	_trigger_skill_tree_brad_on_damage_taken(hp_amount)
	_trigger_skill_tree_cory_on_damage_taken(hp_amount)

func _on_player_healed(amount: int) -> void:
	player.spawn_heal_number(amount)
	# Sphere grid passive triggers for healing
	var stats = player.get_stats()
	var overheal = 0
	if stats and stats.current_health >= stats.max_health:
		overheal = amount  # approximate overheal
	_trigger_sphere_passives("on_heal", {"overheal": overheal})

	# Skill tree passive triggers on heal
	_trigger_skill_tree_brad_on_heal()
	_trigger_skill_tree_cory_on_heal()

func _on_player_mana_gained(amount: int, is_regen: bool) -> void:
	# Cory: Energy Barrier — track non-regen mana gains
	_trigger_skill_tree_cory_on_mana_gain(amount, is_regen)

func update_turn_display() -> void:
	if turn_label:
		turn_label.text = "Global Tempo: %d | Draw in: %.0f | Atk Sp proc: %d" % [
			tempo_manager.get_global_tempo(),
			turn_manager.get_tempo_until_draw(),
			player.get_stats().get_attacks_until_proc()
		]

func _on_hand_updated() -> void:
	if hand_card_preview:
		hand_card_preview.visible = false
	_current_hand_hover_index = -1

	# Cory: Regrowth — draw 4 when hand is empty
	if deck_manager.hand.is_empty():
		_trigger_skill_tree_cory_on_hand_empty()

	# Snapshot current hand card IDs to detect which are new
	var new_card_ids: Array[String] = []
	for card in deck_manager.hand:
		new_card_ids.append(card.card_id + "_" + str(card.get_instance_id()))

	# Determine which cards are newly drawn
	var new_indices: Array[int] = []
	for i in range(new_card_ids.size()):
		if not new_card_ids[i] in _prev_hand_card_ids:
			new_indices.append(i)

	_prev_hand_card_ids = new_card_ids

	# Remove old card UI nodes that aren't animating out
	for child in hand_container.get_children():
		if child is CardUI and not child._is_animating_out:
			child.queue_free()
		elif not child is CardUI:
			child.queue_free()
	_card_ui_instances.clear()

	var debuff_mgr = player.get_debuff_manager()

	# Assign Hexed/Locked cards if needed
	deck_manager.assign_hexed_locked_cards(debuff_mgr)

	# Recalculate enchantment bonuses based on current hand contents
	_recalculate_enchantment_bonuses()

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

	# Calculate spacing
	var total_cards_width = card_width * hand_size
	var spacing: float
	if total_cards_width <= container_width:
		if hand_size == 1:
			spacing = 0.0
		else:
			spacing = (container_width - card_width) / (hand_size - 1)
		spacing = min(spacing, card_width + 8.0)
	else:
		spacing = (container_width - card_width) / max(hand_size - 1, 1)

	# Center the hand
	var total_hand_width = card_width + spacing * max(hand_size - 1, 0)
	var start_x = (container_width - total_hand_width) / 2.0
	var card_y = (hand_container.size.y - card_height) / 2.0
	if card_y < 0:
		card_y = 0.0

	# Fan rotation: slight arc for cards in hand
	var max_fan_angle: float = 3.0  # Max degrees for outermost card
	if hand_size <= 1:
		max_fan_angle = 0.0

	# Draw pile position for draw animation origin (bottom-left of screen)
	var draw_origin = Vector2(-80, card_y + 40)

	for i in range(hand_size):
		var card_ui = CardUIScene.instantiate()
		hand_container.add_child(card_ui)
		card_ui.setup(deck_manager.hand[i], i, debuff_mgr)

		var final_pos = Vector2(start_x + i * spacing, card_y)

		# Fan rotation: arc from left to right
		var fan_t = 0.0
		if hand_size > 1:
			fan_t = float(i) / float(hand_size - 1) * 2.0 - 1.0  # -1..1
		var fan_angle = fan_t * max_fan_angle
		card_ui.set_fan_rotation(fan_angle)

		card_ui.z_index = i
		card_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if i in new_indices:
			# New card: animate sliding in from draw pile area
			card_ui.position = final_pos  # Set base for store
			card_ui.store_base_position()
			var delay = new_indices.find(i) * 0.08
			card_ui.animate_draw_in(draw_origin, final_pos, delay)
		else:
			# Existing card: slide to new position
			card_ui.position = final_pos
			card_ui.store_base_position()

		_card_ui_instances.append(card_ui)

	if selected_card_index >= deck_manager.hand.size():
		selected_card_index = -1

	update_deck_info()
	update_selected_display()
	update_card_highlights()

func _on_card_discarded(card: Card) -> void:
	# Sphere grid passive triggers for discard
	_trigger_sphere_passives("on_discard", {"card": card})
	# Skill tree passive triggers for discard
	_trigger_skill_tree_on_discard(card)
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
	# Generic on-discard effects
	if card.has_on_discard:
		_handle_on_discard_effect(card)

func _handle_on_discard_effect(card: Card) -> void:
	match card.on_discard_effect:
		"discard_2_cards":
			if deck_manager and deck_manager.hand.size() > 0:
				var cards_to_discard = mini(2, deck_manager.hand.size())
				for i in range(cards_to_discard):
					var random_index = randi() % deck_manager.hand.size()
					var discarded = deck_manager.hand[random_index]
					deck_manager.hand.remove_at(random_index)
					deck_manager.discard_pile.append(discarded)
					deck_manager.discards_this_cycle += 1
					deck_manager.card_discarded.emit(discarded)
					print("[MAIN] %s On Discard: discarded %s" % [card.card_name, discarded.card_name])
				deck_manager.hand_updated.emit()
				add_battle_log("%s discarded! Lost %d cards!" % [card.card_name, cards_to_discard], Color(1.0, 0.5, 0.3))

func _on_card_drawn_sphere_passive(card: Card) -> void:
	_trigger_sphere_passives("on_draw", {"card": card})
	_trigger_skill_tree_on_draw(card)

func _on_deck_shuffled() -> void:
	update_deck_info()
	_animate_shuffle()
	# Cory: Circle of Life
	_trigger_skill_tree_cory_on_shuffle()

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

		# Maintained Power card effects (Halo healing, etc.)
		_process_maintained_card_effects()

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
		_process_pending_absorb_essences()
		_process_glut_countdown()

	# Sphere grid passive triggers for tempo cycle
	_trigger_sphere_passives("on_cycle", {})
	_trigger_sphere_passives("on_tempo_cycle", {})

	# Skill tree passive triggers for tempo cycle
	_trigger_skill_tree_on_cycle()
	_trigger_skill_tree_brad_on_cycle()
	_trigger_skill_tree_cory_on_cycle()
	if tempo_manager.last_tempo_source == "movement":
		_trigger_skill_tree_on_movement_cycle()

	_check_volatile_mixture_in_hand()
	_apply_in_hand_debuffs()
	_process_enchantment_cycles()
	_update_gauntlet_skills_ui()
	update_turn_display()
	_update_enemy_count()
	_reroll_card_rng()
	_on_hand_updated()
	_refresh_unit_tracker()

	if was_moving:
		player.resume_movement()
func _process_maintained_card_effects() -> void:
	## Process ongoing effects from maintained Power cards each tempo cycle.
	var maintained_result = deck_manager.process_maintained_cards()
	var stats = player.get_stats()
	if maintained_result["total_heal"] > 0 and stats:
		var heal_amount = maintained_result["total_heal"]
		if stats:
			heal_amount = stats.get_effective_heal_amount(heal_amount)
		stats.heal(heal_amount)
		print("[MAIN] Maintained cards healed for %d HP" % heal_amount)
	if maintained_result["self_damage"] > 0 and stats:
		stats.take_direct_damage(maintained_result["self_damage"])
		print("[MAIN] Cultish Wounds: dealt %d damage to self (ignoring armor)" % maintained_result["self_damage"])

	# Fountain of Life: deal damage to self and draw a card each cycle
	if maintained_result["fountain_self_damage"] > 0 and stats:
		stats.take_damage(maintained_result["fountain_self_damage"])
		add_battle_log("Fountain of Life: took %d damage!" % maintained_result["fountain_self_damage"], Color(1.0, 0.3, 0.3))
		print("[MAIN] Fountain of Life dealt %d self-damage" % maintained_result["fountain_self_damage"])
	if maintained_result["fountain_draws"] > 0:
		for i in range(maintained_result["fountain_draws"]):
			deck_manager.draw_card()
		add_battle_log("Fountain of Life: drew %d card(s)!" % maintained_result["fountain_draws"], Color(0.4, 0.8, 1.0))
		print("[MAIN] Fountain of Life drew %d card(s)" % maintained_result["fountain_draws"])

func _append_keyword_tooltips(parent: VBoxContainer, card: Card) -> void:
	## Scan a card for keyword matches and append tooltip labels to the parent container.
	var keywords = card.get_matching_keywords()
	if keywords.size() == 0:
		return

	var sep = HSeparator.new()
	parent.add_child(sep)

	var header = Label.new()
	header.text = "Keywords:"
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	parent.add_child(header)

	for kw in keywords:
		var kw_label = RichTextLabel.new()
		kw_label.bbcode_enabled = true
		kw_label.text = "[color=#cc88ff]%s[/color]: %s" % [kw["keyword"], kw["definition"]]
		kw_label.fit_content = true
		kw_label.scroll_active = false
		kw_label.custom_minimum_size = Vector2(220, 0)
		kw_label.add_theme_font_size_override("normal_font_size", 10)
		kw_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(kw_label)

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

func _recalculate_enchantment_bonuses() -> void:
	var stats = player.get_stats()
	if not stats:
		return
	var damage_bonus: int = 0
	var block_bonus: int = 0
	var mana_regen_bonus: float = 0.0
	var movement_bonus: int = 0
	for card in deck_manager.hand:
		if card.in_hand_buff == "":
			continue
		match card.in_hand_buff:
			"damage_3":
				damage_bonus += 3
			"block_3":
				block_bonus += 3
			"movement_1":
				movement_bonus += 1
			"mana_regen_1":
				mana_regen_bonus += 1.0
	var changed = (stats.enchantment_damage_bonus != damage_bonus
		or stats.enchantment_block_bonus != block_bonus
		or stats.enchantment_mana_regen_bonus != mana_regen_bonus
		or stats.enchantment_movement_bonus != movement_bonus)
	if changed:
		stats.enchantment_damage_bonus = damage_bonus
		stats.enchantment_block_bonus = block_bonus
		stats.enchantment_mana_regen_bonus = mana_regen_bonus
		stats.enchantment_movement_bonus = movement_bonus
		print("[MAIN] Enchantment bonuses updated — DMG: +%d, BLK: +%d, MOVE: +%d, MANA REGEN: +%.1f" % [damage_bonus, block_bonus, movement_bonus, mana_regen_bonus])

func _apply_in_hand_debuffs() -> void:
	var debuff_mgr = player.get_buff_manager().debuff_manager if player.get_buff_manager() else null
	if not debuff_mgr:
		return
	for card in deck_manager.hand:
		if card.in_hand_debuff != "":
			match card.in_hand_debuff:
				"slowed_2":
					debuff_mgr.apply_debuff(Debuff.create_slowed(2, 6, card.card_name))

func _process_enchantment_cycles() -> void:
	var hand_changed = false
	for i in range(deck_manager.hand.size() - 1, -1, -1):
		var card = deck_manager.hand[i]
		if card.card_type != Card.CardType.ENCHANTMENT:
			continue
		card.cycles_in_hand += 1
		if card.cycles_in_hand >= 2:
			deck_manager.hand.remove_at(i)
			deck_manager.discard_pile.append(card)
			card.cycles_in_hand = 0
			hand_changed = true
			add_battle_log("%s faded away" % card.card_name, Color(0.2, 0.9, 0.8))
			print("[MAIN] Enchantment '%s' auto-discarded after 2 cycles" % card.card_name)
	if hand_changed:
		deck_manager.hand_updated.emit()

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

func _process_pending_absorb_essences() -> void:
	for i in range(pending_absorb_essences.size() - 1, -1, -1):
		var ae = pending_absorb_essences[i]
		ae.tempo_remaining -= 5
		if ae.tempo_remaining <= 0:
			# Create Energy Ball card and add to hand
			var energy_ball = Card.create_energy_ball()
			energy_ball.damage = ae.total_damage
			energy_ball.base_damage = ae.total_damage
			deck_manager.hand.append(energy_ball)
			deck_manager.hand_updated.emit()
			pending_absorb_essences.remove_at(i)
			add_battle_log("Energy Ball obtained! (%d damage)" % ae.total_damage, Color(0.5, 0.8, 1.0))
			print("[MAIN] Absorb Essence: Energy Ball created with %d damage!" % ae.total_damage)
		else:
			print("[MAIN] Absorb Essence: %d tempo until Energy Ball" % ae.tempo_remaining)

func _process_glut_countdown() -> void:
	if glut_tempo_remaining > 0:
		glut_tempo_remaining -= 5
		if glut_tempo_remaining <= 0:
			glut_tempo_remaining = 0
			add_battle_log("Glut expired! You can play cards again.", Color(0.4, 1.0, 0.5))
			print("[MAIN] Glut expired!")
		else:
			print("[MAIN] Glut: %d tempo remaining" % glut_tempo_remaining)

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
	_update_maintained_button()

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
		# Eagle Eye: +2 range on ranged attacks
		var st_stats = player.get_stats()
		if st_stats and st_stats.has_skill_tree_passive("eagle_eye"):
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

	# Glut: cannot play cards while glutted
	if glut_tempo_remaining > 0:
		add_battle_log("Glutted! Cannot play cards for %d more tempo." % glut_tempo_remaining, Color(1.0, 0.3, 0.3))
		print("[INPUT] Cannot play cards - Glutted for %d more tempo!" % glut_tempo_remaining)
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

	# Capture the card UI before playing for animation
	var played_card_ui: CardUI = null
	if selected_card_index >= 0 and selected_card_index < _card_ui_instances.size():
		played_card_ui = _card_ui_instances[selected_card_index]

	var result = deck_manager.play_card(selected_card_index, target, player)

	if result["played"]:
		# Animate the played card flying to target
		if played_card_ui and is_instance_valid(played_card_ui):
			var fly_target = _get_card_play_target_pos(target)
			played_card_ui.animate_play(fly_target)

		selected_card_index = -1

		# Log the card play
		var target_name = ""
		if target is Enemy:
			target_name = " on %s" % target.enemy_name
		if card.last_damage_dealt > 0:
			add_battle_log("Played %s%s — %d damage" % [card.card_name, target_name, card.last_damage_dealt], Color(0.4, 1.0, 0.5))
		else:
			add_battle_log("Played %s%s" % [card.card_name, target_name], Color(0.4, 1.0, 0.5))

		# Sphere grid passive triggers for card play
		_trigger_sphere_passives("on_card_play", {"card": card, "target": target})
		if card.card_type == Card.CardType.ATTACK:
			_trigger_sphere_passives("on_attack", {"card": card, "target": target})
		if card.card_type == Card.CardType.UTILITY and card.mana_cost > 0:
			_trigger_sphere_passives("on_spell_cast", {"card": card, "target": target})

		# Skill tree passive triggers for card play
		_trigger_skill_tree_on_card_play(card, target)
		_trigger_skill_tree_stephen_on_card_play(card)
		_trigger_skill_tree_cory_on_card_play(card)
		if card.card_type == Card.CardType.ATTACK:
			_trigger_skill_tree_on_attack(card, target)
			# Brad/Stephen attack passives (bonus damage applied to target)
			var brad_bonus = _trigger_skill_tree_brad_on_attack(card, target)
			var stephen_bonus = _trigger_skill_tree_stephen_on_attack(card, target)
			if (brad_bonus + stephen_bonus) > 0 and target and target.has_method("take_damage"):
				target.take_damage(brad_bonus + stephen_bonus, true)
			# Ranged attack passives (Stephen)
			if card.is_ranged:
				_trigger_skill_tree_stephen_on_ranged_attack(card, target)
		if card.card_type == Card.CardType.DEFENSE:
			_trigger_skill_tree_brad_on_defense_card_play(card)
		else:
			# Reset Pristine Armor consecutive defense counter on non-defense card
			var pa_stats = player.get_stats()
			if pa_stats:
				pa_stats.st_consecutive_defense = 0

		# Check for crit-based skill tree passives (Eye Scrape)
		if buff_mgr and buff_mgr.last_crit_hit:
			buff_mgr.last_crit_hit = false
			_trigger_skill_tree_on_crit(target)

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

		# Reckless Strike: add 2 Minor Wounds to the deck
		if card.card_id == "reckless_strike":
			for i in range(2):
				var wound = Card.create_minor_wounds()
				deck_manager.discard_pile.append(wound)
			add_battle_log("Reckless Strike: 2 Minor Wounds added to deck!", Color(1.0, 0.5, 0.3))
			print("[MAIN] Reckless Strike: added 2 Minor Wounds to discard pile")

		# Collect Arrows: move up to 2 attack cards from discard pile to hand
		if card.card_id == "collect_arrows":
			var collected = 0
			for i in range(deck_manager.discard_pile.size() - 1, -1, -1):
				if collected >= 2:
					break
				var discard_card = deck_manager.discard_pile[i]
				if discard_card.card_type == Card.CardType.ATTACK:
					deck_manager.discard_pile.remove_at(i)
					deck_manager.hand.append(discard_card)
					collected += 1
					print("[MAIN] Collect Arrows: retrieved %s from discard" % discard_card.card_name)
			if collected > 0:
				deck_manager.hand_updated.emit()
				add_battle_log("Collect Arrows: retrieved %d attack card(s)!" % collected, Color(0.4, 0.8, 1.0))
			else:
				add_battle_log("Collect Arrows: no attack cards in discard pile!", Color(1.0, 0.6, 0.3))
			print("[MAIN] Collect Arrows: collected %d attack cards" % collected)
		# Track last played card for Lethal Recall (skip lethal_recall itself to avoid loops)
		if card.card_id != "lethal_recall":
			_last_played_card = card
			_last_played_target = target

		# Lethal Recall: replay last instant card's effect 2 times
		if card.card_id == "lethal_recall" and _last_played_card:
			var replay_card = _last_played_card
			var replay_target = _last_played_target
			var stats = player.get_stats()
			var damage_reduction = 0.0
			var self_damage = 0.0
			if debuff_mgr:
				damage_reduction = debuff_mgr.get_damage_reduction_percent()
				self_damage = debuff_mgr.get_self_damage_percent()
			for i in range(2):
				replay_card.execute(replay_target, stats, deck_manager, damage_reduction, self_damage, buff_mgr)
				_apply_card_world_effects(replay_card, replay_target)
				print("[MAIN] Lethal Recall: replayed %s (repeat %d/2)" % [replay_card.card_name, i + 1])
			add_battle_log("Lethal Recall: %s triggered 2 times!" % replay_card.card_name, Color(0.8, 0.4, 1.0))

		# Glut: apply card lockout if the card has glut_tempo
		if card.glut_tempo > 0:
			glut_tempo_remaining = card.glut_tempo
			add_battle_log("Glutted for %d tempo! Cannot play cards." % card.glut_tempo, Color(1.0, 0.4, 0.4))
			print("[MAIN] Glut activated: %d tempo lockout" % card.glut_tempo)
			# Stephen: Patience is a Virtue
			_trigger_skill_tree_stephen_on_glut(card.glut_tempo)

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
		# Eagle Eye: +2 range on ranged attacks
		var st_stats = player.get_stats()
		if st_stats and st_stats.has_skill_tree_passive("eagle_eye"):
			max_range += 2
		return distance_tiles <= max_range + 0.5  # Small tolerance
	else:
		# Melee: must be adjacent (within ~1.5 tiles), Reach adds 1 square
		var melee_range = 1.5
		if card.has_reach:
			melee_range += 1.0
		return distance_tiles <= melee_range

func _get_nearest_enemy() -> Enemy:
	## Returns the nearest living enemy to the player, or null if none.
	if not enemy_spawner:
		return null
	var enemies = enemy_spawner.get_living_enemies()
	if enemies.is_empty():
		return null
	var nearest: Enemy = null
	var nearest_dist: float = INF
	for enemy in enemies:
		var dist = player.position.distance_to(enemy.position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest

func _get_card_play_target_pos(target) -> Vector2:
	## Returns a screen position to animate the card toward (in hand_container local coords).
	var cam = get_viewport().get_camera_3d()
	if target is Enemy and is_instance_valid(target) and cam:
		var screen_pos = cam.unproject_position(target.position + Vector3(0, 0.5, 0))
		var container_global = hand_container.get_global_rect().position
		return screen_pos - container_global
	# Default: fly upward toward center of screen
	var vp_size = get_viewport().get_visible_rect().size
	var container_global = hand_container.get_global_rect().position
	return Vector2(vp_size.x * 0.5, vp_size.y * 0.3) - container_global

func _get_discard_pile_pos() -> Vector2:
	## Returns discard pile area position in hand_container local coords for discard animation.
	if discard_label:
		var label_global = discard_label.get_global_rect().position
		var container_global = hand_container.get_global_rect().position
		return label_global - container_global + Vector2(40, 0)
	return Vector2(-100, 0)

func _animate_shuffle() -> void:
	## Shakes the draw pile label to indicate a shuffle.
	if not draw_label:
		return
	var original_pos = draw_label.position
	var tween = create_tween()
	for i in range(4):
		var offset = Vector2(randf_range(-4, 4), randf_range(-2, 2))
		tween.tween_property(draw_label, "position", original_pos + offset, 0.05)
	tween.tween_property(draw_label, "position", original_pos, 0.05)
	# Flash color
	var color_tween = create_tween()
	color_tween.tween_property(draw_label, "modulate", Color(1.0, 0.9, 0.4), 0.1)
	color_tween.tween_property(draw_label, "modulate", Color(1, 1, 1), 0.2)

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
			var blink_cell = grid_manager.world_to_grid(blink_pos)
			# Prevent blinking into walls or obstacles
			if blink_cell in player.blocked_tiles:
				add_battle_log("Cannot blink into a wall or obstacle!", Color(1.0, 0.4, 0.4))
				print("[MAIN] Blink blocked: target tile is a wall/obstacle")
			else:
				player.blink_to(blink_pos)
				_trigger_skill_tree_on_displacement()
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
				_trigger_skill_tree_on_displacement()

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

		"absorb_essence":
			# Deal 1 damage to ALL things on the battlefield (enemies, obstacles, allies)
			var absorb_total_damage = 0
			var all_enemies = enemy_spawner.get_living_enemies()
			for enemy in all_enemies:
				enemy.take_damage(1, true)
				absorb_total_damage += 1
			# Damage obstacles (barricades)
			for i in range(barricade_obstacles.size() - 1, -1, -1):
				var obs = barricade_obstacles[i]
				obs["health"] -= 1
				absorb_total_damage += 1
				if obs["health"] <= 0:
					obs["node"].queue_free()
					barricade_obstacles.remove_at(i)
					_sync_blocked_tiles()
				else:
					obs["label"].text = "HP: %d" % obs["health"]
			# Self damage (1 to player)
			var abs_stats = player.get_stats()
			if abs_stats:
				abs_stats.take_direct_damage(1)
				absorb_total_damage += 1
			# Queue delayed Energy Ball creation
			pending_absorb_essences.append({
				"total_damage": absorb_total_damage,
				"tempo_remaining": 10
			})
			print("[MAIN] Absorb Essence: dealt 1 damage to %d things. Energy Ball in 10 tempo (damage: %d)" % [absorb_total_damage, absorb_total_damage])

		"communal_donation":
			_open_donation_panel()

func _input(event: InputEvent) -> void:
	# Block game input while donation panel is open
	if _donation_active:
		return

	# Block game input while waypoint menu is open
	if _waypoint_menu_visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_close_waypoint_menu()
		return

	# Block game input while chest modal is open
	if _chest_modal_open:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_close_chest_modal()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# Chest / waypoint interaction (Shift key)
		if event.keycode == KEY_SHIFT:
			if _try_interact_waypoint():
				return
			_try_interact_chest()
			return

		# Tab menu toggle (quest log / map)
		if event.keycode == KEY_TAB:
			_toggle_tab_menu()
			return

		# Character panel toggle
		if event.keycode == KEY_I:
			character_panel.toggle_panel()
			return

		# Level progress panel toggle (skill tree + sphere grid tabs)
		if event.keycode == KEY_L:
			skill_tree_ui.toggle_panel()
			return

		# Help panel toggle
		if event.keycode == KEY_H:
			if help_panel.visible:
				help_panel.visible = false
				help_panel.closed.emit()
			else:
				help_panel.show_panel(0)
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
			skill_tree_ui.hide_panel()
	
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

	# Mouse wheel zoom
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = max(CAMERA_ZOOM_MIN, _camera_distance - CAMERA_ZOOM_STEP)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = min(CAMERA_ZOOM_MAX, _camera_distance + CAMERA_ZOOM_STEP)
			_update_camera()

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
# DUNGEON SYSTEM
# ============================================

func _setup_dungeon() -> void:
	dungeon_manager = DungeonManager.new()
	dungeon_manager.name = "DungeonManager"
	add_child(dungeon_manager)
	dungeon_manager.initialize(grid_manager, self, current_world_level)

	# Move player to dungeon start
	var start_pos = dungeon_manager.get_player_start_world()
	player.position = start_pos
	player.target_position = start_pos

	# Sync wall tiles as blocked tiles for pathfinding
	_sync_dungeon_blocked_tiles()

	# Center camera on player start
	_camera_focus = start_pos + Vector3(3, 0, 0)
	_update_camera()

	# Ensure town waypoint is always in discovered list
	var has_town = false
	for d in discovered_waypoints:
		if d["target"] == "town":
			has_town = true
			break
	if not has_town:
		discovered_waypoints.append({
			"world": current_world_level,
			"target": "town",
			"display_name": "Town Portal"
		})

	# Restore previously discovered waypoints for this world
	_restore_discovered_waypoints()

	# Setup quest manager
	if not quest_manager:
		quest_manager = QuestManager.new()
		quest_manager.name = "QuestManager"
		add_child(quest_manager)
		# Restore quest state from previous scene (persists kills across worlds)
		if not quest_state.is_empty():
			quest_manager.load_state(quest_state)
		else:
			# First time: auto-accept available quests so they appear in quest log
			for quest_id in quest_manager.available_quests.keys():
				quest_manager.accept_quest(quest_id)

	# Setup minimap
	_setup_minimap()

	# Setup tab menu
	_setup_tab_menu()

	# Build ground plane to match world size
	_build_ground_plane()

	print("[MAIN] Dungeon initialized (World %d), player at %s" % [current_world_level, start_pos])

func _sync_dungeon_blocked_tiles() -> void:
	## Combines dungeon wall tiles with barricade tiles for pathfinding.
	var tiles: Array[Vector2i] = []
	if dungeon_manager:
		tiles.append_array(dungeon_manager.get_wall_tiles())
	for obs in barricade_obstacles:
		tiles.append(grid_manager.world_to_grid(obs["position"]))
	player.blocked_tiles = tiles
	for enemy in enemy_spawner.get_living_enemies():
		enemy.blocked_tiles = tiles

func _check_dungeon_zones() -> void:
	## Check if player has entered any new spawn zones.
	if not dungeon_manager:
		return
	var player_grid = grid_manager.world_to_grid(player.position)
	dungeon_manager.update_chest_prompts(player_grid)

	var triggered = dungeon_manager.check_player_position(player_grid)
	for zone_idx in triggered:
		_spawn_dungeon_zone(zone_idx)

func _spawn_dungeon_zone(zone_index: int) -> void:
	var zone = dungeon_manager.get_spawn_zone(zone_index)
	if zone.is_empty():
		return

	var spawn_points: Array = zone["spawn_points"]
	var enemy_types: Array = zone["enemy_types"]
	var count = mini(spawn_points.size(), enemy_types.size())

	for i in range(count):
		var world_pos = grid_manager.grid_to_world(spawn_points[i])
		enemy_spawner.spawn_enemy(enemy_types[i], world_pos)

	_sync_dungeon_blocked_tiles()
	_sync_pillar_tiles()
	_update_enemy_count()
	_refresh_unit_tracker()

	# Hide newly spawned enemies that are in fog
	if dungeon_manager:
		dungeon_manager.update_enemy_fog_visibility(
			enemy_spawner.get_living_enemies(), grid_manager
		)

	add_battle_log("Enemies appear!", Color(1.0, 0.4, 0.4))
	print("[MAIN] Dungeon zone %d triggered! Spawned %d enemies." % [zone_index, count])

func _update_fog_of_war() -> void:
	if not dungeon_manager:
		return
	var player_grid = grid_manager.world_to_grid(player.position)
	dungeon_manager.reveal_around(player_grid)
	# Update enemy visibility based on revealed tiles
	dungeon_manager.update_enemy_fog_visibility(
		enemy_spawner.get_living_enemies(), grid_manager
	)


# ============================================
# CHEST LOOT MODAL
# ============================================

func _try_interact_chest() -> void:
	if not dungeon_manager:
		return
	if _chest_modal_open:
		return

	var player_grid = grid_manager.world_to_grid(player.position)
	var chest_idx = dungeon_manager.get_nearby_chest(player_grid)
	if chest_idx < 0:
		return

	var contents = dungeon_manager.open_chest(chest_idx)
	if contents.is_empty():
		return

	# Grant gold immediately
	var gold_amount = contents.get("gold", 0)
	if gold_amount > 0:
		player.get_stats().gain_gold(gold_amount)

	_show_chest_modal(contents)

func _show_chest_modal(contents: Dictionary) -> void:
	_chest_modal_open = true
	_chest_modal_contents = contents

	var ui = $UI as CanvasLayer

	# Dimmed overlay
	var overlay = ColorRect.new()
	overlay.name = "ChestOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(_on_chest_overlay_input)
	ui.add_child(overlay)

	# Modal panel
	_chest_modal = PanelContainer.new()
	_chest_modal.name = "ChestModal"
	_chest_modal.custom_minimum_size = Vector2(420, 0)
	_chest_modal.set_anchors_preset(Control.PRESET_CENTER)
	_chest_modal.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_chest_modal.grow_vertical = Control.GROW_DIRECTION_BOTH

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.07, 0.1, 0.98)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.7, 0.55, 0.2)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	_chest_modal.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_chest_modal.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Treasure Chest!"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Gold
	var gold_amount = contents.get("gold", 0)
	if gold_amount > 0:
		var gold_lbl = Label.new()
		gold_lbl.text = "+ %d Gold" % gold_amount
		gold_lbl.add_theme_font_size_override("font_size", 18)
		gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(gold_lbl)

	# Item reward
	var item: ItemData = contents.get("item")
	if item:
		vbox.add_child(HSeparator.new())
		var item_container = _build_chest_item_display(item)
		vbox.add_child(item_container)

		var pick_up_btn = Button.new()
		pick_up_btn.text = "Pick Up Item"
		pick_up_btn.custom_minimum_size = Vector2(160, 36)
		pick_up_btn.add_theme_font_size_override("font_size", 15)
		_style_chest_button(pick_up_btn, Color(0.15, 0.4, 0.15), Color(0.3, 0.7, 0.3))
		pick_up_btn.pressed.connect(_on_chest_pick_up_item.bind(item))
		vbox.add_child(pick_up_btn)

	# Card reward
	var card: Card = contents.get("card")
	if card:
		vbox.add_child(HSeparator.new())
		var card_container = _build_chest_card_display(card)
		vbox.add_child(card_container)

		var btn_hbox = HBoxContainer.new()
		btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_hbox.add_theme_constant_override("separation", 12)

		var add_deck_btn = Button.new()
		add_deck_btn.text = "Add to Deck"
		add_deck_btn.custom_minimum_size = Vector2(140, 36)
		add_deck_btn.add_theme_font_size_override("font_size", 15)
		_style_chest_button(add_deck_btn, Color(0.15, 0.3, 0.45), Color(0.3, 0.5, 0.8))
		add_deck_btn.pressed.connect(_on_chest_add_card_to_deck.bind(card))
		btn_hbox.add_child(add_deck_btn)

		# Check if card can be slotted into any weapon
		var inv = player.get_inventory()
		var compatible_items = _get_compatible_items_for_card(card, inv)
		if compatible_items.size() > 0:
			var slot_btn = Button.new()
			slot_btn.text = "Slot into Weapon"
			slot_btn.custom_minimum_size = Vector2(150, 36)
			slot_btn.add_theme_font_size_override("font_size", 15)
			_style_chest_button(slot_btn, Color(0.4, 0.25, 0.1), Color(0.7, 0.5, 0.2))
			slot_btn.pressed.connect(_on_chest_slot_card.bind(card, compatible_items))
			btn_hbox.add_child(slot_btn)

		vbox.add_child(btn_hbox)

	vbox.add_child(HSeparator.new())

	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(120, 34)
	close_btn.add_theme_font_size_override("font_size", 14)
	_style_chest_button(close_btn, Color(0.3, 0.15, 0.15), Color(0.6, 0.3, 0.3))
	close_btn.pressed.connect(_close_chest_modal)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(close_btn)

	ui.add_child(_chest_modal)

func _build_chest_item_display(item: ItemData) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)

	var name_lbl = Label.new()
	name_lbl.text = item.item_name
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(name_lbl)

	var type_lbl = Label.new()
	type_lbl.text = "[%s]" % item.get_type_name()
	type_lbl.add_theme_font_size_override("font_size", 13)
	type_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(type_lbl)

	# Stats (build same as town modal)
	var stats_text = _build_chest_item_stats(item)
	if stats_text != "":
		var stats_lbl = Label.new()
		stats_lbl.text = stats_text
		stats_lbl.add_theme_font_size_override("font_size", 13)
		stats_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		container.add_child(stats_lbl)

	if item.description != "":
		var desc_lbl = Label.new()
		desc_lbl.text = item.description
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		container.add_child(desc_lbl)

	return container

func _build_chest_item_stats(item: ItemData) -> String:
	var lines: Array[String] = []
	if item.strength_bonus != 0:
		lines.append("+%d Strength" % item.strength_bonus if item.strength_bonus > 0 else "%d Strength" % item.strength_bonus)
	if item.dexterity_bonus != 0:
		lines.append("+%d Dexterity" % item.dexterity_bonus if item.dexterity_bonus > 0 else "%d Dexterity" % item.dexterity_bonus)
	if item.intelligence_bonus != 0:
		lines.append("+%d Intelligence" % item.intelligence_bonus if item.intelligence_bonus > 0 else "%d Intelligence" % item.intelligence_bonus)
	if item.weapon_damage > 0:
		lines.append("%d Weapon Damage" % item.weapon_damage)
	if item.armor_bonus > 0:
		lines.append("+%d Armor" % item.armor_bonus)
	if item.health_bonus > 0:
		lines.append("+%d Health" % item.health_bonus)
	if item.mana_bonus > 0:
		lines.append("+%d Mana" % item.mana_bonus)
	if item.weight > 0:
		lines.append("Weight: %d" % item.weight)
	return "\n".join(lines)

func _build_chest_card_display(card: Card) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)

	var name_lbl = Label.new()
	name_lbl.text = card.card_name
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(name_lbl)

	var type_lbl = Label.new()
	type_lbl.text = card.card_type_name
	type_lbl.add_theme_font_size_override("font_size", 13)
	match card.card_type:
		Card.CardType.ATTACK:
			type_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		Card.CardType.DEFENSE:
			type_lbl.add_theme_color_override("font_color", Color(0.3, 0.5, 1))
		Card.CardType.UTILITY:
			type_lbl.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
		Card.CardType.POWER:
			type_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
		Card.CardType.ENCHANTMENT:
			type_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.8))
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(type_lbl)

	var cost_lbl = Label.new()
	cost_lbl.text = "Cost: %dM / %dT" % [card.mana_cost, card.tempo_cost]
	cost_lbl.add_theme_font_size_override("font_size", 12)
	cost_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(cost_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = card.description
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(desc_lbl)

	return container

func _get_compatible_items_for_card(card: Card, inv: Inventory) -> Array[ItemData]:
	var result: Array[ItemData] = []
	var items = inv.get_all_items_with_card_slots()
	for item in items:
		if item.can_slot_card(card):
			result.append(item)
	return result

func _on_chest_pick_up_item(item: ItemData) -> void:
	var inv = player.get_inventory()
	if inv.store_item(item):
		add_battle_log("Picked up %s!" % item.item_name, Color(1.0, 0.85, 0.3))
	else:
		add_battle_log("Inventory full! Could not pick up %s." % item.item_name, Color(1.0, 0.4, 0.4))
	_close_chest_modal()

func _on_chest_add_card_to_deck(card: Card) -> void:
	deck_manager.discard_pile.append(card)
	add_battle_log("Added %s to deck!" % card.card_name, Color(0.3, 0.8, 1.0))
	_close_chest_modal()

func _on_chest_slot_card(card: Card, compatible_items: Array[ItemData]) -> void:
	# For simplicity, slot into first compatible item
	if compatible_items.size() > 0:
		var target_item = compatible_items[0]
		var inv = player.get_inventory()
		if inv.enchant_card(card, target_item):
			add_battle_log("Slotted %s into %s!" % [card.card_name, target_item.item_name], Color(0.8, 0.6, 1.0))
		else:
			# Fallback: add to deck
			deck_manager.discard_pile.append(card)
			add_battle_log("Could not slot card. Added %s to deck instead." % card.card_name, Color(1.0, 0.6, 0.3))
	_close_chest_modal()

func _on_chest_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_chest_modal()

func _close_chest_modal() -> void:
	_chest_modal_open = false
	_chest_modal_contents = {}
	var ui = $UI as CanvasLayer
	var overlay = ui.get_node_or_null("ChestOverlay")
	if overlay:
		overlay.queue_free()
	if _chest_modal and is_instance_valid(_chest_modal):
		_chest_modal.queue_free()
		_chest_modal = null

func _style_chest_button(btn: Button, bg_color: Color, border_color: Color) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.border_color = border_color
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = bg_color.lightened(0.15)
	hover.border_width_left = 2
	hover.border_width_right = 2
	hover.border_width_top = 2
	hover.border_width_bottom = 2
	hover.border_color = border_color.lightened(0.2)
	hover.corner_radius_top_left = 6
	hover.corner_radius_top_right = 6
	hover.corner_radius_bottom_left = 6
	hover.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("hover", hover)

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
		"Halo": card = Card.create_halo()
		"Armored Discipline": card = Card.create_armored_discipline()

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

	# Demonic Rage: quiver mana costs use health instead
	var quiver_demonic_rage = buff_mgr and buff_mgr.has_demonic_rage() and mana_cost > 0
	if quiver_demonic_rage:
		if stats.current_health <= mana_cost:
			print("[MAIN] Quiver: Demonic Rage - not enough health to pay %d!" % mana_cost)
			return
	elif not stats.has_mana(mana_cost):
		print("[MAIN] Quiver: not enough mana to play %s (need %d)" % [card.card_name, mana_cost])
		return
	if mana_cost > 0:
		if quiver_demonic_rage:
			stats.take_damage(mana_cost)
			buff_mgr.consume_demonic_rage()
			print("[MAIN] Quiver: Demonic Rage paid %d health instead of mana" % mana_cost)
		else:
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
# COMMUNAL DONATION UI
# ============================================

func _setup_donation_panel() -> void:
	var ui = $UI as CanvasLayer
	_donation_panel = PanelContainer.new()
	_donation_panel.name = "DonationPanel"
	ui.add_child(_donation_panel)
	_donation_panel.set_anchors_preset(Control.PRESET_CENTER)
	_donation_panel.offset_left = -180.0
	_donation_panel.offset_top = -160.0
	_donation_panel.offset_right = 180.0
	_donation_panel.offset_bottom = 160.0
	_donation_panel.custom_minimum_size = Vector2(360, 320)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.3, 0.3)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	_donation_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_donation_panel.add_child(vbox)

	var title = Label.new()
	title.text = "Communal Donation"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	vbox.add_child(title)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var desc = Label.new()
	desc.text = "Choose how much HP to sacrifice.\nHealing is split among your allies."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(desc)

	# HP donation slider
	var slider_hbox = HBoxContainer.new()
	slider_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(slider_hbox)

	var slider_label = Label.new()
	slider_label.text = "HP to donate:"
	slider_label.add_theme_font_size_override("font_size", 14)
	slider_hbox.add_child(slider_label)

	_donation_slider = HSlider.new()
	_donation_slider.min_value = 1
	_donation_slider.max_value = 10
	_donation_slider.step = 1
	_donation_slider.value = 1
	_donation_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_donation_slider.custom_minimum_size = Vector2(150, 0)
	_donation_slider.value_changed.connect(_on_donation_slider_changed)
	slider_hbox.add_child(_donation_slider)

	_donation_amount_label = Label.new()
	_donation_amount_label.text = "1"
	_donation_amount_label.add_theme_font_size_override("font_size", 16)
	_donation_amount_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_donation_amount_label.custom_minimum_size = Vector2(30, 0)
	slider_hbox.add_child(_donation_amount_label)

	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# Ally allocation section (populated when panel opens)
	_donation_ally_container = VBoxContainer.new()
	_donation_ally_container.add_theme_constant_override("separation", 6)
	vbox.add_child(_donation_ally_container)

	# Buttons
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 12)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	var confirm_btn = Button.new()
	confirm_btn.text = "Donate"
	confirm_btn.add_theme_font_size_override("font_size", 14)
	confirm_btn.custom_minimum_size = Vector2(100, 30)
	confirm_btn.pressed.connect(_on_donation_confirmed)
	btn_hbox.add_child(confirm_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.add_theme_font_size_override("font_size", 14)
	cancel_btn.custom_minimum_size = Vector2(100, 30)
	cancel_btn.pressed.connect(_on_donation_cancelled)
	btn_hbox.add_child(cancel_btn)

	_donation_panel.visible = false

func _get_ally_names() -> Array:
	## Returns names of all living allies that can receive healing.
	var allies: Array = []
	# Player 2 in multiplayer
	if is_multiplayer and player2_character:
		allies.append(player2_character.character_name)
	# Summoned creatures (ally markers)
	for child in get_children():
		if child is MeshInstance3D and child.has_node("Label3D"):
			var label_node = child.get_node("Label3D") as Label3D
			if label_node:
				allies.append(label_node.text)
	# If no allies exist, allow self-heal as fallback
	if allies.size() == 0:
		allies.append("Self")
	return allies

func _open_donation_panel() -> void:
	var stats = player.get_stats()
	if not stats:
		return
	_donation_active = true

	# Set slider max to current HP - 1 (can't kill yourself)
	var max_donate = max(1, stats.current_health - 1)
	_donation_slider.max_value = max_donate
	_donation_slider.value = min(5, max_donate)
	_donation_amount_label.text = str(int(_donation_slider.value))

	# Build ally allocation rows
	for child in _donation_ally_container.get_children():
		child.queue_free()
	_donation_ally_sliders.clear()

	var ally_names = _get_ally_names()
	for ally_name in ally_names:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_donation_ally_container.add_child(row)

		var name_lbl = Label.new()
		name_lbl.text = ally_name
		name_lbl.custom_minimum_size = Vector2(100, 0)
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		row.add_child(name_lbl)

		var slider = HSlider.new()
		slider.min_value = 0
		slider.max_value = int(_donation_slider.value)
		slider.step = 1
		slider.value = int(_donation_slider.value) / ally_names.size()
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size = Vector2(120, 0)
		row.add_child(slider)

		var val_lbl = Label.new()
		val_lbl.text = str(int(slider.value))
		val_lbl.custom_minimum_size = Vector2(25, 0)
		val_lbl.add_theme_font_size_override("font_size", 13)
		val_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		row.add_child(val_lbl)

		slider.value_changed.connect(func(v): val_lbl.text = str(int(v)))

		_donation_ally_sliders.append({"slider": slider, "label": val_lbl, "name": ally_name})

	_donation_panel.visible = true

func _on_donation_slider_changed(value: float) -> void:
	_donation_amount_label.text = str(int(value))
	# Update ally slider maximums to match total pool
	for entry in _donation_ally_sliders:
		entry["slider"].max_value = int(value)

func _on_donation_confirmed() -> void:
	_donation_panel.visible = false
	_donation_active = false

	var stats = player.get_stats()
	if not stats:
		return

	var self_damage = int(_donation_slider.value)
	if self_damage <= 0:
		return

	# Deal self-damage (ignores armor)
	stats.take_direct_damage(self_damage)
	add_battle_log("Communal Donation: sacrificed %d HP!" % self_damage, Color(1.0, 0.3, 0.3))
	print("[MAIN] Communal Donation: player took %d self-damage" % self_damage)

	# Distribute healing to allies
	var total_healed = 0
	for entry in _donation_ally_sliders:
		var heal_amount = int(entry["slider"].value)
		if heal_amount <= 0:
			continue
		var ally_name: String = entry["name"]
		if ally_name == "Self":
			stats.heal(heal_amount)
			add_battle_log("Communal Donation: healed self for %d" % heal_amount, Color(0.3, 1.0, 0.3))
		else:
			# Heal summoned allies / P2 (future: route to actual ally stats)
			add_battle_log("Communal Donation: healed %s for %d" % [ally_name, heal_amount], Color(0.3, 1.0, 0.3))
		total_healed += heal_amount
		print("[MAIN] Communal Donation: healed %s for %d" % [ally_name, heal_amount])

	var wasted = self_damage - total_healed
	if wasted > 0:
		add_battle_log("Communal Donation: %d HP unallocated (wasted)" % wasted, Color(0.7, 0.7, 0.3))

func _on_donation_cancelled() -> void:
	_donation_panel.visible = false
	_donation_active = false
	add_battle_log("Communal Donation cancelled.", Color(0.7, 0.7, 0.7))

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
	## Syncs the barricade positions + dungeon walls to the player and all enemies for pathfinding.
	var tiles: Array[Vector2i] = []
	if dungeon_manager:
		tiles.append_array(dungeon_manager.get_wall_tiles())
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
		"deal_2_self":
			var stats = player.get_stats()
			if stats:
				stats.take_damage(2)
				add_battle_log("Minor Wounds: took 2 damage!", Color(1.0, 0.3, 0.3))
				print("[MAIN] %s On Draw: dealt 2 damage to self" % card.card_name)
		"draw_3_cards":
			if deck_manager:
				for i in range(3):
					deck_manager.draw_card()
				add_battle_log("%s On Draw: drew 3 cards!" % card.card_name, Color(0.5, 0.9, 0.5))
				print("[MAIN] %s On Draw: drew 3 cards" % card.card_name)
		"gain_3_armor_cleanse_1":
			var stats = player.get_stats()
			var buff_mgr = player.get_buff_manager()
			if stats:
				stats.add_armor(3)
			if buff_mgr:
				buff_mgr.apply_buff(Buff.create_cleanse(1, card.card_name))
			add_battle_log("%s: +3 armor, cleanse 1!" % card.card_name, Color(0.5, 0.7, 1.0))
			print("[MAIN] %s On Draw: gained 3 armor, cleansed 1 debuff" % card.card_name)

func _on_card_erased(card: Card) -> void:
	add_battle_log("%s erased from deck!" % card.card_name, Color(0.7, 0.7, 0.7))
	update_deck_info()
	_on_hand_updated()

# ============================================
# LOOT DROP SYSTEM
# ============================================

func _on_loot_dropped(loot: Dictionary, pos: Vector3) -> void:
	var messages: Array[String] = []

	# Gold
	var gold = loot.get("gold", 0)
	if gold > 0:
		player.get_stats().gain_gold(gold)
		messages.append("+%d Gold" % gold)

	# Item drop
	var item: ItemData = loot.get("item")
	if item:
		var inventory = player.get_inventory()
		if inventory:
			if inventory.store_item(item):
				messages.append("Item: %s" % item.item_name)
			else:
				messages.append("Item dropped (inventory full): %s" % item.item_name)

	# Card drop
	var card: Card = loot.get("card")
	if card:
		if deck_manager:
			deck_manager.discard_pile.append(card)
			messages.append("Card: %s" % card.card_name)

	if messages.size() > 0:
		var loot_text = "Loot: " + ", ".join(messages)
		add_battle_log(loot_text, Color(1.0, 0.85, 0.2))
		print("[MAIN] %s" % loot_text)

# ============================================
# WAYPOINT TRAVEL
# ============================================

func _restore_discovered_waypoints() -> void:
	## Marks waypoints in the current dungeon as discovered if they were previously found.
	if not dungeon_manager:
		return
	for i in range(dungeon_manager.waypoint_nodes.size()):
		var wp = dungeon_manager.waypoint_nodes[i]
		for d in discovered_waypoints:
			if d["world"] == current_world_level and d["target"] == wp["target"]:
				dungeon_manager.discover_waypoint(i)
				break

func _check_waypoint_discovery(player_grid: Vector2i) -> void:
	## Discover any waypoint the player is standing on.
	if not dungeon_manager:
		return
	var wp_idx = dungeon_manager.get_waypoint_on_tile(player_grid)
	if wp_idx < 0:
		return
	if dungeon_manager.discover_waypoint(wp_idx):
		var wp = dungeon_manager.waypoint_nodes[wp_idx]
		# Register in global discovered list
		var entry = {
			"world": current_world_level,
			"target": wp["target"],
			"display_name": wp["display_name"]
		}
		# Check if already registered (e.g. from a previous visit)
		var already = false
		for d in discovered_waypoints:
			if d["world"] == entry["world"] and d["target"] == entry["target"]:
				already = true
				break
		if not already:
			discovered_waypoints.append(entry)
		add_battle_log("Waypoint discovered: %s" % wp["display_name"], Color(0.3, 0.9, 1.0))

func _try_interact_waypoint() -> bool:
	## Handles Shift near a waypoint. Green/yellow portals travel directly.
	## Blue town waypoints open the teleport menu.
	if not dungeon_manager:
		return false
	var player_grid = grid_manager.world_to_grid(player.position)
	var wp_idx = dungeon_manager.get_nearby_waypoint(player_grid)
	if wp_idx < 0:
		return false
	# Must be discovered to use
	if not dungeon_manager.waypoint_nodes[wp_idx]["discovered"]:
		add_battle_log("Walk onto the waypoint to discover it first.", Color(0.8, 0.8, 0.5))
		return true
	# Next/prev world portals travel directly (original behavior)
	var target = dungeon_manager.waypoint_nodes[wp_idx]["target"]
	match target:
		"next_world":
			_travel_to_world(current_world_level + 1)
			return true
		"prev_world":
			_travel_to_world(current_world_level - 1)
			return true
	# Town waypoint opens the teleport menu
	_open_waypoint_menu()
	return true

func _open_waypoint_menu() -> void:
	## Shows a centered panel listing all discovered waypoints for teleportation.
	if _waypoint_menu_visible:
		_close_waypoint_menu()
		return

	var ui = $UI as CanvasLayer

	_waypoint_menu_panel = PanelContainer.new()
	_waypoint_menu_panel.name = "WaypointMenu"
	ui.add_child(_waypoint_menu_panel)
	# Explicitly center on 1280x720 screen
	var wp_w = 350.0
	var wp_h = 300.0
	_waypoint_menu_panel.offset_left = (1280.0 - wp_w) / 2.0
	_waypoint_menu_panel.offset_top = (720.0 - wp_h) / 2.0
	_waypoint_menu_panel.offset_right = (1280.0 + wp_w) / 2.0
	_waypoint_menu_panel.offset_bottom = (720.0 + wp_h) / 2.0
	_waypoint_menu_panel.custom_minimum_size = Vector2(wp_w, wp_h)
	_waypoint_menu_panel.z_index = 100  # Sit on top of cards and other UI

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.12, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.6, 1.0, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_waypoint_menu_panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_waypoint_menu_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Teleport to Waypoint"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# List all discovered waypoints
	for wp in discovered_waypoints:
		var btn = Button.new()
		var label_text = wp["display_name"]
		if wp["world"] == current_world_level and wp["target"] != "town":
			label_text += " (Current World)"
		btn.text = label_text
		btn.custom_minimum_size = Vector2(280, 36)
		btn.add_theme_font_size_override("font_size", 15)

		# Color-code by type
		match wp["target"]:
			"town":
				btn.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
			"next_world", "prev_world":
				btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))

		# Capture values for the lambda
		var target = wp["target"]
		var world = wp["world"]
		btn.pressed.connect(func():
			_close_waypoint_menu()
			_teleport_to_waypoint(target, world)
		)
		vbox.add_child(btn)

	if discovered_waypoints.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No waypoints discovered yet."
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(empty_lbl)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "Cancel [Esc]"
	close_btn.custom_minimum_size = Vector2(120, 32)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.pressed.connect(_close_waypoint_menu)
	vbox.add_child(close_btn)

	_waypoint_menu_visible = true

func _close_waypoint_menu() -> void:
	if _waypoint_menu_panel and is_instance_valid(_waypoint_menu_panel):
		_waypoint_menu_panel.queue_free()
		_waypoint_menu_panel = null
	_waypoint_menu_visible = false

func _teleport_to_waypoint(target: String, world: int) -> void:
	match target:
		"town":
			_travel_to_town()
		_:
			if world == current_world_level:
				# Same world: teleport to the waypoint position within the dungeon
				for wp in dungeon_manager.waypoint_nodes:
					if wp["target"] == target:
						var wp_world_pos = grid_manager.grid_to_world(wp["grid_pos"])
						player.position = wp_world_pos
						player.target_position = wp_world_pos
						_camera_focus = wp_world_pos + Vector3(3, 0, 0)
						_update_camera()
						_update_fog_of_war()
						add_battle_log("Teleported to %s" % wp["display_name"], Color(0.3, 0.9, 1.0))
						return
			else:
				_travel_to_world(world)

func _travel_to_town() -> void:
	print("[MAIN] Traveling to town!")
	var saved_quest_state = quest_manager.save_state() if quest_manager else {}
	var town_scene = load("res://scenes/town.tscn").instantiate()
	town_scene.starting_character = starting_character
	if "discovered_waypoints" in town_scene:
		town_scene.discovered_waypoints = discovered_waypoints
	if "quest_state" in town_scene:
		town_scene.quest_state = saved_quest_state
	get_tree().root.add_child(town_scene)
	queue_free()

func _travel_to_world(level: int) -> void:
	print("[MAIN] Traveling to World %d!" % level)
	var saved_quest_state = quest_manager.save_state() if quest_manager else {}
	var main_scene = load("res://main.tscn").instantiate()
	main_scene.starting_character = starting_character
	main_scene.current_world_level = level
	main_scene.discovered_waypoints = discovered_waypoints
	main_scene.quest_state = saved_quest_state
	get_tree().root.add_child(main_scene)
	queue_free()

func _build_ground_plane() -> void:
	# Remove existing ground if any and build one matching world size
	var existing = get_node_or_null("GroundPlane")
	if existing:
		existing.queue_free()

	var ground = MeshInstance3D.new()
	ground.name = "GroundPlane"
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(dungeon_manager.GRID_W, dungeon_manager.GRID_H)
	ground.mesh = plane_mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.12, 0.1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	ground.material_override = mat
	ground.position = Vector3(dungeon_manager.GRID_W / 2.0, -0.01, dungeon_manager.GRID_H / 2.0)
	add_child(ground)

# ============================================
# MINIMAP
# ============================================

func _setup_minimap() -> void:
	if _minimap_panel and is_instance_valid(_minimap_panel):
		_minimap_panel.queue_free()

	var ui = $UI as CanvasLayer

	_minimap_panel = PanelContainer.new()
	_minimap_panel.name = "MinimapPanel"
	ui.add_child(_minimap_panel)

	# Position in upper-left corner
	_minimap_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_minimap_panel.offset_left = 8.0
	_minimap_panel.offset_top = 40.0
	_minimap_panel.offset_right = 8.0 + MINIMAP_SIZE + 8
	_minimap_panel.offset_bottom = 40.0 + MINIMAP_SIZE + 8

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.85)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.45, 0.8)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_minimap_panel.add_theme_stylebox_override("panel", style)

	_minimap_texture_rect = TextureRect.new()
	_minimap_texture_rect.custom_minimum_size = Vector2(MINIMAP_SIZE, MINIMAP_SIZE)
	_minimap_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_minimap_panel.add_child(_minimap_texture_rect)

	# Create initial minimap image
	_minimap_image = Image.create(dungeon_manager.GRID_W * MINIMAP_PIXEL_SCALE, dungeon_manager.GRID_H * MINIMAP_PIXEL_SCALE, false, Image.FORMAT_RGBA8)
	_minimap_image.fill(Color(0.02, 0.02, 0.05, 1.0))

func _update_minimap() -> void:
	if not _minimap_image or not dungeon_manager or not _minimap_texture_rect:
		return

	var gw = dungeon_manager.GRID_W
	var gh = dungeon_manager.GRID_H
	var s = MINIMAP_PIXEL_SCALE

	# Clear
	_minimap_image.fill(Color(0.02, 0.02, 0.05, 1.0))

	# Draw revealed floor tiles
	for x in range(gw):
		for z in range(gh):
			if dungeon_manager.is_revealed(Vector2i(x, z)):
				var col: Color
				if dungeon_manager.is_floor(Vector2i(x, z)):
					col = Color(0.25, 0.22, 0.2, 1.0)
				else:
					col = Color(0.12, 0.1, 0.15, 1.0)
				for px in range(s):
					for pz in range(s):
						var ix = x * s + px
						var iz = z * s + pz
						if ix < _minimap_image.get_width() and iz < _minimap_image.get_height():
							_minimap_image.set_pixel(ix, iz, col)

	# Draw waypoints
	for wp in dungeon_manager.waypoint_nodes:
		var wp_pos: Vector2i = wp["grid_pos"]
		var wp_col = Color(0.3, 0.7, 1.0)
		if wp["target"] == "next_world":
			wp_col = Color(0.3, 1.0, 0.4)
		elif wp["target"] == "prev_world":
			wp_col = Color(1.0, 0.8, 0.3)
		for px in range(s):
			for pz in range(s):
				var ix = wp_pos.x * s + px
				var iz = wp_pos.y * s + pz
				if ix < _minimap_image.get_width() and iz < _minimap_image.get_height():
					_minimap_image.set_pixel(ix, iz, wp_col)

	# Draw enemies
	for enemy in enemy_spawner.get_living_enemies():
		if not enemy.visible:
			continue
		var eg = grid_manager.world_to_grid(enemy.position)
		for px in range(s):
			for pz in range(s):
				var ix = eg.x * s + px
				var iz = eg.y * s + pz
				if ix >= 0 and ix < _minimap_image.get_width() and iz >= 0 and iz < _minimap_image.get_height():
					_minimap_image.set_pixel(ix, iz, Color(1.0, 0.2, 0.2))

	# Draw player (slightly larger)
	var pg = grid_manager.world_to_grid(player.position)
	for px in range(-1, s + 1):
		for pz in range(-1, s + 1):
			var ix = pg.x * s + px
			var iz = pg.y * s + pz
			if ix >= 0 and ix < _minimap_image.get_width() and iz >= 0 and iz < _minimap_image.get_height():
				_minimap_image.set_pixel(ix, iz, Color(0.2, 1.0, 0.4))

	var tex = ImageTexture.create_from_image(_minimap_image)
	_minimap_texture_rect.texture = tex

# ============================================
# TAB MENU (QUEST LOG / MAP)
# ============================================

func _setup_tab_menu() -> void:
	if _tab_menu_panel and is_instance_valid(_tab_menu_panel):
		_tab_menu_panel.queue_free()

	var ui = $UI as CanvasLayer

	_tab_menu_panel = PanelContainer.new()
	_tab_menu_panel.name = "TabMenuPanel"
	ui.add_child(_tab_menu_panel)
	# Explicitly center on 1280x720 screen
	var tab_w = 750.0
	var tab_h = 550.0
	_tab_menu_panel.offset_left = (1280.0 - tab_w) / 2.0
	_tab_menu_panel.offset_top = (720.0 - tab_h) / 2.0
	_tab_menu_panel.offset_right = (1280.0 + tab_w) / 2.0
	_tab_menu_panel.offset_bottom = (720.0 + tab_h) / 2.0
	_tab_menu_panel.custom_minimum_size = Vector2(tab_w, tab_h)
	_tab_menu_panel.visible = false
	_tab_menu_panel.z_index = 100  # Sit on top of cards and other UI

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.06, 0.1, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.4, 0.35, 0.55)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	_tab_menu_panel.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_tab_menu_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Tab buttons row
	var tab_hbox = HBoxContainer.new()
	tab_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(tab_hbox)

	var map_tab_btn = Button.new()
	map_tab_btn.text = "Dungeon Map"
	map_tab_btn.custom_minimum_size = Vector2(140, 32)
	map_tab_btn.add_theme_font_size_override("font_size", 16)
	map_tab_btn.pressed.connect(_on_tab_map_pressed)
	tab_hbox.add_child(map_tab_btn)

	var quest_tab_btn = Button.new()
	quest_tab_btn.text = "Quest Log"
	quest_tab_btn.custom_minimum_size = Vector2(120, 32)
	quest_tab_btn.add_theme_font_size_override("font_size", 16)
	quest_tab_btn.pressed.connect(_on_tab_quest_pressed)
	tab_hbox.add_child(quest_tab_btn)

	# World label
	var world_lbl = Label.new()
	world_lbl.text = "World %d" % current_world_level
	world_lbl.add_theme_font_size_override("font_size", 16)
	world_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	world_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tab_hbox.add_child(world_lbl)

	vbox.add_child(HSeparator.new())

	# Map content (shown by default — tab 0)
	_tab_map_container = VBoxContainer.new()
	_tab_map_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_map_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tab_map_container)

	# Large map texture rect for dungeon map
	_tab_map_texture_rect = TextureRect.new()
	_tab_map_texture_rect.custom_minimum_size = Vector2(400, 350)
	_tab_map_texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_map_texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_map_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tab_map_container.add_child(_tab_map_texture_rect)

	# Quest log content (hidden by default — tab 1)
	var quest_scroll = ScrollContainer.new()
	quest_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quest_scroll.custom_minimum_size = Vector2(0, 400)
	quest_scroll.visible = false
	vbox.add_child(quest_scroll)

	_tab_quest_container = VBoxContainer.new()
	_tab_quest_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_scroll.add_child(_tab_quest_container)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close [Tab]"
	close_btn.custom_minimum_size = Vector2(120, 32)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.pressed.connect(_toggle_tab_menu)
	vbox.add_child(close_btn)

	# Default to map tab
	_tab_menu_current_tab = 0

func _toggle_tab_menu() -> void:
	_tab_menu_visible = not _tab_menu_visible
	if _tab_menu_panel:
		_tab_menu_panel.visible = _tab_menu_visible
	if _tab_menu_visible:
		_refresh_tab_menu()

func _on_tab_map_pressed() -> void:
	_tab_menu_current_tab = 0
	_refresh_tab_menu()

func _on_tab_quest_pressed() -> void:
	_tab_menu_current_tab = 1
	_refresh_tab_menu()

func _refresh_tab_menu() -> void:
	if not _tab_quest_container or not _tab_map_container:
		return

	if _tab_menu_current_tab == 0:
		# Dungeon Map tab
		_tab_map_container.visible = true
		_tab_quest_container.get_parent().visible = false
		_refresh_expanded_map()
	else:
		# Quest Log tab
		_tab_map_container.visible = false
		_tab_quest_container.get_parent().visible = true
		_refresh_quest_log()

func _refresh_quest_log() -> void:
	for child in _tab_quest_container.get_children():
		child.queue_free()

	if not quest_manager:
		var no_quests = Label.new()
		no_quests.text = "No quests available."
		no_quests.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_tab_quest_container.add_child(no_quests)
		return

	# Active quests
	var active = quest_manager.get_active_quests()
	if active.size() > 0:
		var header = Label.new()
		header.text = "Active Quests"
		header.add_theme_font_size_override("font_size", 18)
		header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		_tab_quest_container.add_child(header)

		for quest in active:
			var quest_panel = _create_quest_entry(quest)
			_tab_quest_container.add_child(quest_panel)

	# Completed quests
	var completed = quest_manager.get_completed_quests()
	if completed.size() > 0:
		_tab_quest_container.add_child(HSeparator.new())
		var header2 = Label.new()
		header2.text = "Completed Quests"
		header2.add_theme_font_size_override("font_size", 18)
		header2.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		_tab_quest_container.add_child(header2)

		for quest in completed:
			var quest_panel = _create_quest_entry(quest)
			_tab_quest_container.add_child(quest_panel)

	if active.is_empty() and completed.is_empty():
		var no_quests = Label.new()
		no_quests.text = "No quests yet. Talk to NPCs in town!"
		no_quests.add_theme_font_size_override("font_size", 14)
		no_quests.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		_tab_quest_container.add_child(no_quests)

func _create_quest_entry(quest) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.8)
	style.border_width_left = 1
	style.border_color = Color(0.3, 0.3, 0.4)
	style.corner_radius_top_left = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = quest.name
	name_lbl.add_theme_font_size_override("font_size", 16)
	if quest.is_complete:
		name_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	else:
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	vbox.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = quest.description
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	var progress_lbl = Label.new()
	progress_lbl.text = quest.get_objective_text()
	progress_lbl.add_theme_font_size_override("font_size", 14)
	if quest.is_complete:
		progress_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	else:
		progress_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	vbox.add_child(progress_lbl)

	return panel

func _refresh_expanded_map() -> void:
	## Renders a large dungeon map into the tab menu map texture rect.
	if not dungeon_manager or not _tab_map_texture_rect:
		return

	var gw = dungeon_manager.GRID_W
	var gh = dungeon_manager.GRID_H
	var scale = 8  # Larger pixel scale for expanded view
	var img = Image.create(gw * scale, gh * scale, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.02, 0.02, 0.05, 1.0))

	# Draw tiles
	for x in range(gw):
		for z in range(gh):
			if dungeon_manager.is_revealed(Vector2i(x, z)):
				var col: Color
				if dungeon_manager.is_floor(Vector2i(x, z)):
					col = Color(0.25, 0.22, 0.2, 1.0)
				else:
					col = Color(0.12, 0.1, 0.15, 1.0)
				for px in range(scale):
					for pz in range(scale):
						img.set_pixel(x * scale + px, z * scale + pz, col)

	# Draw waypoints (larger in expanded view)
	for wp in dungeon_manager.waypoint_nodes:
		var wp_pos: Vector2i = wp["grid_pos"]
		var wp_col = Color(0.3, 0.7, 1.0)
		if wp["target"] == "next_world":
			wp_col = Color(0.3, 1.0, 0.4)
		elif wp["target"] == "prev_world":
			wp_col = Color(1.0, 0.8, 0.3)
		for px in range(scale):
			for pz in range(scale):
				var ix = wp_pos.x * scale + px
				var iz = wp_pos.y * scale + pz
				if ix < img.get_width() and iz < img.get_height():
					img.set_pixel(ix, iz, wp_col)

	# Draw chests
	for chest in dungeon_manager.chest_nodes:
		var cp: Vector2i = chest["grid_pos"]
		if not dungeon_manager.is_revealed(cp):
			continue
		var cc = Color(0.9, 0.7, 0.2) if not chest["opened"] else Color(0.4, 0.35, 0.2)
		for px in range(scale):
			for pz in range(scale):
				var ix = cp.x * scale + px
				var iz = cp.y * scale + pz
				if ix < img.get_width() and iz < img.get_height():
					img.set_pixel(ix, iz, cc)

	# Draw enemies
	for enemy in enemy_spawner.get_living_enemies():
		if not enemy.visible:
			continue
		var eg = grid_manager.world_to_grid(enemy.position)
		for px in range(scale):
			for pz in range(scale):
				var ix = eg.x * scale + px
				var iz = eg.y * scale + pz
				if ix >= 0 and ix < img.get_width() and iz >= 0 and iz < img.get_height():
					img.set_pixel(ix, iz, Color(1.0, 0.2, 0.2))

	# Draw player (slightly larger)
	var pg = grid_manager.world_to_grid(player.position)
	for px in range(-1, scale + 1):
		for pz in range(-1, scale + 1):
			var ix = pg.x * scale + px
			var iz = pg.y * scale + pz
			if ix >= 0 and ix < img.get_width() and iz >= 0 and iz < img.get_height():
				img.set_pixel(ix, iz, Color(0.2, 1.0, 0.4))

	var tex = ImageTexture.create_from_image(img)
	_tab_map_texture_rect.texture = tex
