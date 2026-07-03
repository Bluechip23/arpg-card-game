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
@onready var draw_label = $UI/DeckInfo/DrawPileLabel
@onready var discard_label = $UI/DeckInfo/DiscardPileLabel
@onready var jail_label = $UI/DeckInfo/JailPileLabel
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
var enemy_inspect_ui: EnemyInspectUI = null
var quest_manager: QuestManager = null
var progression_triggers: ProgressionTriggers = null
var chest_loot_ui: ChestLootUI = null
var olorin: OlorinTutorial = null
var waypoint_mgr: WaypointManager = null
# Rats summoned by the Infestation card (roguelike only).
var _summoned_rats: Array = []
var minimap_tab_ui: MinimapTabUI = null
var player2_ui: Player2UI = null
var current_world_level: int = 1

# Interior the player is currently inside ("" = overworld). e.g. "cave_0"
var current_interior_id: String = ""
# When returning from an interior, respawn at that site's entrance
var return_from_interior_id: String = ""

# Global waypoint discovery tracking (persists across world transitions)
# Each entry: { "world": int, "target": String, "display_name": String }
var discovered_waypoints: Array = []

# Chest open state tracking (persists across world transitions)
# Key: "world_<level>_chest_<index>", Value: true
var opened_chests: Dictionary = {}

# Quest state that persists across world transitions
# { "kill_counts": { "Wererat": 3, ... }, "accepted_ids": ["olorin_kill_wererats"], "completed_ids": [] }
var quest_state: Dictionary = {}

# Player progression that persists across world transitions
# Contains: player_stats snapshot, skill_tree object, sphere_grid object, sphere inventory data
var player_progression: Dictionary = {}

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
var _tab_menu_current_tab: int = 0  # 0=map, 1=quest log, 2=card inventory
var _tab_quest_container: VBoxContainer = null
var _tab_map_container: VBoxContainer = null
var _tab_map_texture_rect: TextureRect = null
var _tab_card_inv_container: VBoxContainer = null

# Card animation tracking
var _prev_hand_card_ids: Array[String] = []  # Card IDs from last hand update
var _card_play_animating: bool = false        # Block input during card play animation

# Enemy loot drops lying on the ground, waiting to be picked up.
# Each entry: {"node": Node3D, "cell": Vector2i, "loot": Dictionary}
var _loot_drops: Array = []

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

const GauntletSkillUIScene = preload("res://scenes/cards/gauntlet_skill_ui.tscn")
const CardUIScene = preload("res://scenes/cards/card_ui.tscn")

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

# Roguelike battle hand-off. When non-empty, this main scene was launched by the
# roguelike map to resolve a single encounter. On victory OR death it emits
# roguelike_battle_finished and the map removes/frees this scene. Empty for all
# normal story / fight / multiplayer flows, which keep their existing behavior.
signal roguelike_battle_finished(victory: bool, remaining_hp: int)
var roguelike_context: Dictionary = {}
var _roguelike_active: bool = false
var _roguelike_relics: Array = []  # Relics carried by the run (drive in-battle relic effects)

# Active fire walls (Fire Goblin Shaman). Each: {tiles, damage, burn, moves_left, visuals}.
var _fire_walls: Array = []

# Forest hazards & climbing (see DungeonManager forest features).
const TREE_CANOPY_Y := 2.0          # height the player rests at while up a tree
const BEAR_TRAP_DAMAGE := 7         # to anything that steps on a sprung trap…
const BEAR_TRAP_BEAR_DAMAGE := 10   # …but bears take extra
const DART_TRAP_DAMAGE := 5         # hunters' tripwire dart volley
var _climbed_tree_tile: Vector2i = Vector2i(-1, -1)  # tree the player is currently up, or (-1,-1)

# Player 2 state
var _p2_player: Player = null  # The co-op partner's on-grid character (own stats/figure)
# Co-op control: which character TAB is driving. `player`/`deck_manager` always
# point at the active one; _p1_* hold the original Player 1 references.
var _active_index: int = 0
var _p1_player: Player = null
var _p1_deck_manager: DeckManager = null
var _p2_deck_manager: DeckManager = null
# Co-op "lock in movement": queued moves per player index, executed together by
# the on-screen "Move Players" button so simultaneous movement shares tempo.
var _locked_moves: Dictionary = {}        # index -> {"pos": Vector3, "spaces": int}
var _locked_move_markers: Dictionary = {} # index -> Node3D ghost marker
var _move_players_button: Button = null
var _batch_moving: bool = false           # True while a locked-in batch is moving
var _batch_pending: int = 0               # How many batched movers are still in motion
# Co-op "lock in card": like locked movement, playing a card in co-op offers
# Play Now / Lock In / Cancel. Locked cards wait (no tempo, still in hand) until
# the on-screen "Play Cards" button fires them all together.
var _locked_cards: Array = []             # [{"card": Card, "target", "owner": int}]
var _play_cards_button: Button = null
var _card_confirm_panel: PanelContainer = null
var _card_confirm_label: Label = null
var _pending_card_target = null           # target captured while the dialog is up
var _pending_card: Card = null
var _card_play_confirmed: bool = false    # bypass flag: dialog already answered
# Co-op defeat: a player at 0 HP is "downed" but the fight continues; only when
# BOTH are downed is it a defeat. A downed player can be revived by healing.
var _downed: Dictionary = {0: false, 1: false}
var _co_op_defeated: bool = false
var _downed_markers: Dictionary = {}      # index -> Label3D "DOWNED" tag
# These four are created by Player2UI but stored on Main so its hover/preview
# handlers can reach them. The hand/deck open-state and list containers live in
# Player2UI itself (do not re-add them here).
var _p2_hand_panel: PanelContainer = null
var _p2_hand_card_preview: PanelContainer = null
var _p2_deck_panel: PanelContainer = null
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

# Shared pile contents popup (used by Draw, Discard, Jail buttons)
var pile_popup_panel: PanelContainer = null
var pile_popup_container: VBoxContainer = null
var pile_popup_title_label: Label = null
var pile_popup_card_preview: PanelContainer = null
var pile_popup_visible: bool = false
var pile_popup_current_pile: String = ""  # "draw", "discard", or "jail"
var hand_card_preview: PanelContainer = null
var _hand_hover_id: int = 0
var pending_sky_falls: Array = []  # [{position: Vector3, damage: int, tempo_remaining: int}]
var pending_absorb_essences: Array = []  # [{total_damage: int, tempo_remaining: int}]
# Generic delayed-effect scheduler (per-tempo). Cards that fire after a delay
# (spark, patience, succumb, adrenaline_shot, …) push a captured Callable here.
var _delayed_effects: Array = []  # [{remaining: int, callback: Callable, label: String}]
var _misery_active: bool = false  # Misery Loves Company: next AOE spreads debuffs
var _friendship_linked: bool = false  # Friendship: P1/P2 share healing and split damage
var glut_tempo_remaining: int = 0  # When > 0, player cannot play cards

# Ticked tempo system state
var _pending_resolve_queue: Array[Dictionary] = []  # [{card, target, data}] — sequential card queue

# Tick tempo bar UI (20 vertical bars showing tick progress)
var _tick_bar_rects: Array[ColorRect] = []    # The 20 vertical bar ColorRects
var _tick_bar_label: Label = null             # Label showing "Tick X/Y" text
var _tick_bar_card_name_label: Label = null   # Label showing current card name
var _tick_bar_total_ticks: int = 0            # Total ticks for current card
var _tick_bar_resolve_tick: int = 0           # Which tick resolves the card
var _tick_bar_current_tick: int = 0           # How many ticks have elapsed

# Pause system
var _is_paused: bool = false
var _pause_button: Button = null

var barricade_obstacles: Array = []  # [{node: MeshInstance3D, health: int}]
var active_pillars: Array = []  # [{node: Node3D, position: Vector3, tempo_remaining: int}]
var _card_ui_instances: Array = []
var _current_hand_hover_index: int = -1
# Pending quiver card play state
var _block_button: Button = null
var _attack_button: Button = null

# Stat bar UI references
var _hp_bar: ProgressBar = null
var _mana_bar: ProgressBar = null
var _armor_bar: ProgressBar = null
var _xp_bar: ProgressBar = null
var _hp_bar_label: Label = null
var _mana_bar_label: Label = null
var _armor_bar_label: Label = null
var _xp_bar_label: Label = null
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
	# Initialize extracted managers
	progression_triggers = ProgressionTriggers.new()
	progression_triggers.init(self)
	add_child(progression_triggers)

	chest_loot_ui = ChestLootUI.new()
	chest_loot_ui.init(self)
	add_child(chest_loot_ui)

	olorin = OlorinTutorial.new()
	olorin.init(self)
	add_child(olorin)

	waypoint_mgr = WaypointManager.new()
	waypoint_mgr.init(self)
	add_child(waypoint_mgr)

	minimap_tab_ui = MinimapTabUI.new()
	minimap_tab_ui.init(self)
	add_child(minimap_tab_ui)

	player2_ui = Player2UI.new()
	player2_ui.init(self)
	add_child(player2_ui)

	deck_manager.hand_updated.connect(_on_hand_updated)
	deck_manager.deck_shuffled.connect(_on_deck_shuffled)
	deck_manager.card_peaked.connect(_on_card_peaked)
	deck_manager.card_discarded.connect(_on_card_discarded)
	# Visual-only: cards leaving the hand get their exit animations (tube-suck
	# into the discard pile / instant spin) before the hand UI rebuilds.
	deck_manager.card_discarded.connect(_animate_card_discard)
	deck_manager.reaction_triggered.connect(_animate_card_instant)
	deck_manager.card_drawn.connect(_on_card_drawn_sphere_passive)
	test_ui.apply_overflow_requested.connect(_on_apply_overflow)
	deck_manager.overflow_triggered.connect(_on_overflow_triggered)
	tempo_manager.tempo_threshold_reached.connect(_on_tempo_threshold_reached)
	tempo_manager.tempo_changed.connect(_on_tempo_changed)
	tempo_manager.tempo_advanced.connect(_on_tempo_advanced)
	tempo_manager.card_resolved.connect(_on_card_tick_resolved)
	tempo_manager.ticking_finished.connect(_on_ticking_finished)
	turn_manager.turn_ended.connect(_on_turn_ended)
	manifest_ui.manifest_card_clicked.connect(_on_manifest_card_clicked)
	quiver_ui.quiver_card_targeting_selected.connect(_on_quiver_card_targeting_selected)
	overflow_manager.overcharge_triggered.connect(_on_overcharge_triggered)
	player.move_completed.connect(_on_player_move_completed)
	player.tile_reached.connect(_on_player_tile_reached)
	player.set_grid_manager(grid_manager)
	player.enemy_spawner = enemy_spawner
	player.ground_y_provider = Callable(self, "_desired_ground_y")

	move_dialog.confirmed.connect(_on_move_confirmed)
	move_dialog.cancelled.connect(_on_move_cancelled)
	move_dialog.lock_in_requested.connect(_on_move_lock_in)
	
	# Enemy spawner
	enemy_spawner.initialize(grid_manager, player)
	enemy_spawner.enemy_killed.connect(_on_enemy_killed)
	enemy_spawner.all_enemies_defeated.connect(_on_all_enemies_defeated)
	enemy_spawner.loot_dropped.connect(_on_loot_dropped)
	enemy_spawner.enemy_spawned.connect(_on_enemy_spawned_connect_debuffs)
	
	# Test UI
	test_ui.spawn_wave_requested.connect(_on_spawn_wave)
	test_ui.spawn_elite_requested.connect(_on_spawn_elite)
	test_ui.spawn_fire_goblins_requested.connect(_on_spawn_fire_goblins)
	test_ui.give_item_requested.connect(_on_give_item)
	test_ui.give_card_requested.connect(_on_give_card)
	test_ui.apply_buff_requested.connect(_on_apply_buff)
	
	help_panel.closed.connect(_on_help_closed)
	help_panel.tick_speed_changed.connect(_on_tick_speed_changed)

	# Sphere inventory + grid connection
	sphere_grid_ui.connect_sphere_inventory(sphere_inventory)
	sphere_grid_ui.node_unlocked.connect(progression_triggers._on_sphere_grid_node_unlocked)
	sphere_grid_ui.sphere_grid.constellation_completed.connect(progression_triggers._on_constellation_completed)
	sphere_grid_ui.sphere_grid.constellation_replaced.connect(progression_triggers._on_constellation_replaced)

	# Skill tree connection — also link sphere grid into the tabbed panel
	skill_tree_ui.connect_sphere_grid(sphere_grid_ui)
	skill_tree_ui.sphere_inventory = sphere_inventory
	skill_tree_ui.option_chosen.connect(progression_triggers._on_skill_tree_option_chosen)
	skill_tree_ui.auto_grant_claimed.connect(progression_triggers._on_skill_tree_auto_grant_claimed)
	skill_tree_ui.retrospective_chosen.connect(progression_triggers._on_skill_tree_retrospective_chosen)

	_setup_action_buttons()
	_setup_tick_bar()
	_setup_stat_bars()
	_setup_deck_info_vertical()
	_setup_battle_log()

	if starting_character:
		select_character(starting_character)
	else:
		select_character(CharacterData.create_ryan())

	# Restore player progression from a world transition (level, stats, passives, sphere grid, etc.)
	if not player_progression.is_empty():
		_restore_player_progression(player_progression)

	# Style the hand area with solid background so battlefield doesn't bleed through
	_setup_hand_area_background()
	_setup_deck_list_button()
	_setup_deck_list_panel()
	_setup_maintained_list_button()
	_setup_maintained_list_panel()
	_setup_pile_popup_panel()
	_setup_hand_card_preview()
	_setup_donation_panel()

	# Multiplayer: initialize P2 deck and UI buttons
	if is_multiplayer and player2_character:
		_p1_player = player
		_p1_deck_manager = deck_manager
		player2_ui._initialize_player2()
		# Route Player 2's per-tile movement through the same handlers (they act on
		# the active player, which is P2 whenever you're controlling it).
		if _p2_player:
			_p2_player.tile_reached.connect(_on_player_tile_reached)
			_p2_player.move_completed.connect(_on_player_move_completed)
			# Enemies target the nearest living player; defeat needs both downed.
			enemy_spawner.players = [_p1_player, _p2_player]
		# P2's deck gets the same card exit animations (visual-only handlers —
		# they no-op unless that deck's hand is the one on screen).
		if _p2_deck_manager:
			_p2_deck_manager.card_discarded.connect(_animate_card_discard)
			_p2_deck_manager.reaction_triggered.connect(_animate_card_instant)
			_p2_deck_manager.card_erased.connect(_animate_card_erase)
		if _p2_player and _p2_player.get_inventory():
			_p2_player.get_inventory().ring_triggered.connect(_on_ring_triggered_visual.bind(_p2_player))
			_setup_co_op_defeat()

	# Unit tracker (left side panel)
	_setup_unit_tracker()

	# Initialize dungeon
	_setup_dungeon()
	_update_enemy_count()
	_refresh_unit_tracker()

	# Co-op: now that the dungeon has placed Player 1, seat Player 2 beside them.
	if is_multiplayer and _p2_player:
		player2_ui.reposition_beside_p1()

	# Roguelike encounter: spawn the fight for this map node and arm the
	# return-to-map hook. Only runs when launched from the roguelike map.
	if not roguelike_context.is_empty():
		_start_roguelike_battle()

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

func _on_tick_speed_changed(speed: float) -> void:
	tempo_manager.tick_speed = speed
	print("[MAIN] Tick speed changed to %.2fs" % speed)

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

var _minimap_refresh_accum: float = 0.0

func _process(delta: float) -> void:
	_update_hand_hover()
	_update_battlefield_enemy_hover()
	_update_damage_preview()
	# Update chest interact prompts, waypoints, sites, and enemy fog visibility
	if dungeon_manager and grid_manager:
		var pg = grid_manager.world_to_grid(player.position)
		dungeon_manager.update_chest_prompts(pg)
		dungeon_manager.update_waypoint_prompts(pg)
		dungeon_manager.update_site_prompts(pg)
		dungeon_manager.update_tree_prompts(pg)
		dungeon_manager.update_enemy_fog_visibility(
			enemy_spawner.get_living_enemies(), grid_manager
		)
		# Throttle minimap redraws — repainting per-frame is wasteful on large worlds
		_minimap_refresh_accum += delta
		if _minimap_refresh_accum >= 0.2:
			_minimap_refresh_accum = 0.0
			minimap_tab_ui._update_minimap()
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
var _damage_preview_enemy: Enemy = null
var _sidebar_hover_active: bool = false  # True while sidebar portrait is driving hover

func _update_damage_preview() -> void:
	## Show/hide damage preview number above hovered enemy when a card is selected.
	var hovered = _prev_battlefield_hover
	var should_show = (
		selected_card_index >= 0
		and selected_card_index < deck_manager.hand.size()
		and hovered != null
		and is_instance_valid(hovered)
		and hovered.is_alive()
	)

	if should_show:
		var card = deck_manager.hand[selected_card_index]
		if card.card_type == Card.CardType.ATTACK and card.base_damage > 0 and "enemy" in card.target_types:
			var preview_dmg = calculate_damage_preview(card, hovered)
			if preview_dmg > 0:
				# Hide previous enemy's preview if switching targets
				if _damage_preview_enemy and _damage_preview_enemy != hovered and is_instance_valid(_damage_preview_enemy):
					_damage_preview_enemy.hide_damage_preview()
				hovered.show_damage_preview(preview_dmg)
				_damage_preview_enemy = hovered
				return

	# Hide preview if conditions not met
	if _damage_preview_enemy and is_instance_valid(_damage_preview_enemy):
		_damage_preview_enemy.hide_damage_preview()
		_damage_preview_enemy = null

func _update_battlefield_enemy_hover() -> void:
	## Check if mouse is hovering over a battlefield enemy and highlight its panel entry.
	# Skip raycast when the sidebar portrait is driving the hover
	if _sidebar_hover_active:
		return

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
	_attack_button = Button.new()
	_attack_button.name = "AttackButton"
	_attack_button.text = "Attack (5T) (0)"
	_attack_button.custom_minimum_size = Vector2(130, 36)
	_attack_button.tooltip_text = "Basic melee attack: STR modifier damage. Costs 5 tempo."
	_attack_button.pressed.connect(_on_attack_pressed)
	vbox.add_child(_attack_button)

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

	# Pause button (below wait)
	_pause_button = Button.new()
	_pause_button.name = "PauseButton"
	_pause_button.text = "Pause"
	_pause_button.custom_minimum_size = Vector2(130, 36)
	_pause_button.tooltip_text = "Pause gameplay. Useful during tick resolution or multiplayer coordination."
	_pause_button.pressed.connect(_on_pause_pressed)
	var pause_normal = StyleBoxFlat.new()
	pause_normal.bg_color = Color(0.35, 0.25, 0.1)
	pause_normal.corner_radius_top_left = 4
	pause_normal.corner_radius_top_right = 4
	pause_normal.corner_radius_bottom_left = 4
	pause_normal.corner_radius_bottom_right = 4
	_pause_button.add_theme_stylebox_override("normal", pause_normal)
	var pause_hover = StyleBoxFlat.new()
	pause_hover.bg_color = Color(0.45, 0.35, 0.15)
	pause_hover.corner_radius_top_left = 4
	pause_hover.corner_radius_top_right = 4
	pause_hover.corner_radius_bottom_left = 4
	pause_hover.corner_radius_bottom_right = 4
	_pause_button.add_theme_stylebox_override("hover", pause_hover)
	_pause_button.process_mode = Node.PROCESS_MODE_ALWAYS  # Works while tree is paused
	vbox.add_child(_pause_button)

func _setup_tick_bar() -> void:
	## Build the 20-tick global tempo bar centered at the top of the screen.
	var ui = $UI as CanvasLayer

	var tick_container = VBoxContainer.new()
	tick_container.name = "TickBarContainer"
	ui.add_child(tick_container)
	tick_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tick_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	# Center horizontally: bar is 20 bars * (8px + 2px gap) = ~210px wide
	tick_container.offset_left = -130.0
	tick_container.offset_top = 35.0
	tick_container.offset_right = 130.0
	tick_container.offset_bottom = 90.0
	tick_container.add_theme_constant_override("separation", 2)

	# Card name label
	_tick_bar_card_name_label = Label.new()
	_tick_bar_card_name_label.name = "TickBarCardName"
	_tick_bar_card_name_label.text = ""
	_tick_bar_card_name_label.add_theme_font_size_override("font_size", 11)
	_tick_bar_card_name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_tick_bar_card_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tick_container.add_child(_tick_bar_card_name_label)

	# Bar row
	var bar_hbox = HBoxContainer.new()
	bar_hbox.name = "TickBars"
	bar_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_hbox.add_theme_constant_override("separation", 2)
	tick_container.add_child(bar_hbox)

	_tick_bar_rects.clear()
	for i in range(20):
		var bar = ColorRect.new()
		bar.custom_minimum_size = Vector2(8, 22)
		bar.color = Color(0.15, 0.15, 0.2)  # Dim/inactive
		bar_hbox.add_child(bar)
		_tick_bar_rects.append(bar)

	# Status label
	_tick_bar_label = Label.new()
	_tick_bar_label.name = "TickBarLabel"
	_tick_bar_label.text = "Ready"
	_tick_bar_label.add_theme_font_size_override("font_size", 11)
	_tick_bar_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.65))
	_tick_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tick_container.add_child(_tick_bar_label)

func _update_tick_bar(ticks_elapsed: int, total_ticks: int, resolve_tick: int, card_name: String = "") -> void:
	## Update the 20-tick global tempo bar. This is a rolling counter that fills
	## on ALL tempo sources (cards, movement, attack, wait, block) and resets at 20.
	_tick_bar_current_tick = ticks_elapsed
	_tick_bar_total_ticks = total_ticks
	_tick_bar_resolve_tick = resolve_tick

	if _tick_bar_card_name_label:
		_tick_bar_card_name_label.text = card_name

	var filled = tempo_manager.get_global_tempo() % 20
	var dim_color = Color(0.15, 0.15, 0.2)        # Empty / unfilled
	var filled_color = Color(0.4, 0.4, 0.55)      # Filled tick
	var resolve_color = Color(1.0, 0.85, 0.3)     # Resolve tick marker (upcoming)
	var active_card_color = Color(0.3, 0.8, 0.4)  # Ticks the active card will consume

	# Calculate resolve marker position (where in the 20-bar the card resolves)
	var resolve_bar_index: int = -1
	var card_end_bar_index: int = -1
	if total_ticks > 0 and ticks_elapsed < total_ticks:
		var ticks_until_resolve = resolve_tick - ticks_elapsed
		if ticks_until_resolve > 0:
			resolve_bar_index = (filled + ticks_until_resolve - 1) % 20
		var ticks_remaining = total_ticks - ticks_elapsed
		card_end_bar_index = (filled + ticks_remaining - 1) % 20

	for i in range(20):
		if i < filled:
			_tick_bar_rects[i].color = filled_color
		else:
			_tick_bar_rects[i].color = dim_color

	# Overlay card tempo markers if a card is active
	if total_ticks > 0 and ticks_elapsed < total_ticks:
		var ticks_remaining = total_ticks - ticks_elapsed
		var ticks_until_resolve = max(0, resolve_tick - ticks_elapsed)
		for t in range(ticks_remaining):
			var bar_idx = (filled + t) % 20
			if ticks_until_resolve > 0 and t == ticks_until_resolve - 1:
				_tick_bar_rects[bar_idx].color = resolve_color
			else:
				_tick_bar_rects[bar_idx].color = active_card_color

	if _tick_bar_label:
		var gt = tempo_manager.get_global_tempo()
		if total_ticks > 0 and ticks_elapsed < total_ticks:
			_tick_bar_label.text = "(%d) Tick %d/%d (resolves tick %d)" % [gt, ticks_elapsed, total_ticks, resolve_tick]
		elif total_ticks > 0 and ticks_elapsed >= total_ticks:
			_tick_bar_label.text = "(%d) Complete" % gt
		else:
			_tick_bar_label.text = "(%d) %d / 20" % [gt, filled]

func _reset_tick_bar() -> void:
	## Reset the tick bar to idle state but still show global tempo progress.
	_tick_bar_current_tick = 0
	_tick_bar_total_ticks = 0
	_tick_bar_resolve_tick = 0
	if _tick_bar_card_name_label:
		_tick_bar_card_name_label.text = ""
	# Show the global counter even when no card is active
	_update_tick_bar(0, 0, 0, "")

func _setup_stat_bars() -> void:
	## Create stacked HP / Mana / Armor / XP progress bars on the left side of the screen.
	var ui = $UI as CanvasLayer

	# Hide old label nodes
	if player_health_label:
		player_health_label.visible = false
	if player_mana_label:
		player_mana_label.visible = false
	if player_armor_label:
		player_armor_label.visible = false
	if player_xp_label:
		player_xp_label.visible = false

	var stat_container = VBoxContainer.new()
	stat_container.name = "StatBarsContainer"
	ui.add_child(stat_container)
	stat_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stat_container.offset_left = 220.0
	stat_container.offset_top = 8.0
	stat_container.offset_right = 430.0
	stat_container.offset_bottom = 130.0
	stat_container.add_theme_constant_override("separation", 4)

	# --- HP Bar (red) ---
	var hp_pair = _create_stat_bar_with_label(stat_container, "HPBar", Color(0.7, 0.15, 0.15), Color(0.3, 0.08, 0.08))
	_hp_bar = hp_pair[0]
	_hp_bar_label = hp_pair[1]

	# --- Mana Bar (blue) ---
	var mana_pair = _create_stat_bar_with_label(stat_container, "ManaBar", Color(0.15, 0.3, 0.8), Color(0.08, 0.12, 0.3))
	_mana_bar = mana_pair[0]
	_mana_bar_label = mana_pair[1]

	# --- Armor Bar (silver/grey) ---
	var armor_pair = _create_stat_bar_with_label(stat_container, "ArmorBar", Color(0.55, 0.55, 0.6), Color(0.2, 0.2, 0.25))
	_armor_bar = armor_pair[0]
	_armor_bar_label = armor_pair[1]

	# --- XP Bar (gold) ---
	var xp_pair = _create_stat_bar_with_label(stat_container, "XPBar", Color(0.8, 0.65, 0.1), Color(0.3, 0.25, 0.05))
	_xp_bar = xp_pair[0]
	_xp_bar_label = xp_pair[1]

func _create_stat_bar_with_label(parent: VBoxContainer, bar_name: String, fill_color: Color, bg_color: Color) -> Array:
	## Creates a progress bar with an overlaid centered label. Returns [bar, label].
	var wrapper = Control.new()
	wrapper.name = bar_name + "Wrapper"
	wrapper.custom_minimum_size = Vector2(200, 22)
	parent.add_child(wrapper)

	var bar = ProgressBar.new()
	bar.name = bar_name
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.max_value = 100
	bar.value = 0
	bar.show_percentage = false
	# Style the fill
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.corner_radius_top_left = 3
	fill_style.corner_radius_top_right = 3
	fill_style.corner_radius_bottom_left = 3
	fill_style.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", fill_style)
	# Style the background
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = bg_color
	bg_style.corner_radius_top_left = 3
	bg_style.corner_radius_top_right = 3
	bg_style.corner_radius_bottom_left = 3
	bg_style.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bg_style)
	wrapper.add_child(bar)

	var lbl = Label.new()
	lbl.name = bar_name + "Label"
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(lbl)

	return [bar, lbl]

func _setup_deck_info_vertical() -> void:
	## Convert DeckInfo from HBoxContainer to VBoxContainer, placed above Maintained button.
	var deck_info = $UI/DeckInfo as HBoxContainer
	if not deck_info:
		return
	# Hide the old horizontal layout spacers
	for child in deck_info.get_children():
		if child.name.begins_with("Spacer"):
			child.visible = false
	# Reparent DeckInfo: reposition it as a vertical stack above the Maintained button (bottom-right)
	deck_info.offset_left = -210.0
	deck_info.offset_top = -130.0
	deck_info.offset_right = -100.0
	deck_info.offset_bottom = -45.0
	deck_info.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# We can't change HBoxContainer to VBoxContainer in scene, so we'll just stack via code
	# Hide the HBox and create a new VBox
	deck_info.visible = false

	var ui = $UI as CanvasLayer
	var vbox = VBoxContainer.new()
	vbox.name = "DeckInfoVertical"
	ui.add_child(vbox)
	vbox.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	vbox.offset_left = -210.0
	vbox.offset_top = -160.0
	vbox.offset_right = -100.0
	vbox.offset_bottom = -45.0
	vbox.add_theme_constant_override("separation", 4)

	# Create buttons that open a popup showing the cards in each pile
	var new_draw = _create_pile_button("DrawButton", "Draw: 0 (0)")
	new_draw.pressed.connect(_on_draw_pile_button_pressed)
	vbox.add_child(new_draw)

	var new_discard = _create_pile_button("DiscardButton", "Discard: 0")
	new_discard.pressed.connect(_on_discard_pile_button_pressed)
	vbox.add_child(new_discard)

	var new_jail = _create_pile_button("JailButton", "Jail: 0")
	new_jail.pressed.connect(_on_jail_pile_button_pressed)
	vbox.add_child(new_jail)

	# Reassign references
	draw_label = new_draw
	discard_label = new_discard
	jail_label = new_jail

func _create_pile_button(btn_name: String, initial_text: String) -> Button:
	## Creates a button styled to match the Maintained button (default Button look).
	var btn = Button.new()
	btn.name = btn_name
	btn.text = initial_text
	btn.custom_minimum_size = Vector2(110, 30)
	btn.focus_mode = Control.FOCUS_NONE
	return btn

func _on_pause_pressed() -> void:
	_is_paused = not _is_paused
	if _is_paused:
		get_tree().paused = true
		_pause_button.text = "Resume"
		add_battle_log("PAUSED", Color(1.0, 0.85, 0.3))
		print("[MAIN] Game paused")
	else:
		get_tree().paused = false
		_pause_button.text = "Pause"
		print("[MAIN] Game resumed")

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

	# Swing the arm down — basic attack uses the same slash as the slash card.
	if player.has_method("play_animation"):
		player.play_animation("attack_slash", _facing_dir_toward(target))

	# Damage: 0 base + strength modifier
	var damage = stats.get_effective_physical_damage(0)

	var buff_mgr = player.get_buff_manager()
	if buff_mgr:
		damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			damage = floori(damage * 1.5)
			buff_mgr.consume_enlightened()

	# Debuff damage reduction
	if debuff_mgr:
		var reduction = debuff_mgr.get_damage_reduction_percent()
		if reduction > 0.0:
			damage = max(1, floori(damage * (1.0 - reduction)))

	# Tempo cost
	var tempo_cost = 5
	if debuff_mgr:
		tempo_cost += debuff_mgr.get_tempo_increase()

	# Dex proc: halve basic attack tempo
	var basic_attack_proc = deck_manager.next_attack_half_tempo
	if basic_attack_proc:
		tempo_cost = tempo_cost / 2
		deck_manager.next_attack_half_tempo = false
		deck_manager.next_attack_mana_discount = 0
		# Pocket Knife: -2 additional tempo
		var ba_inv = player.get_inventory()
		if ba_inv and ba_inv.has_pocket_knife_equipped():
			tempo_cost = maxi(0, tempo_cost - 2)
			print("[MAIN] Pocket Knife! Basic attack tempo reduced to %d" % tempo_cost)
		print("[MAIN] Dex proc on basic attack! Tempo halved to %d" % tempo_cost)
		_on_hand_updated()
		_update_attack_button_text()

	if buff_mgr and buff_mgr.consume_steady():
		# Steady: resolve immediately with no tempo
		target.take_damage(damage, true)
		if buff_mgr.last_crit_hit:
			buff_mgr.last_crit_hit = false
			progression_triggers._trigger_skill_tree_on_crit(target)
		# Proc-bonus attacks don't count towards the next cycle
		if not basic_attack_proc:
			stats.register_attack()
		if debuff_mgr:
			debuff_mgr.on_attack()
		add_battle_log("Basic Attack: %d damage to %s (Steady!)" % [damage, target.enemy_name], Color(0.4, 1.0, 0.5))
		print("[MAIN] Basic Attack (Steady): dealt %d damage to %s — no tempo" % [damage, target.enemy_name])
	elif tempo_cost <= 0:
		# Dex proc reduced tempo to 0: resolve immediately
		target.take_damage(damage, true)
		if buff_mgr and buff_mgr.last_crit_hit:
			buff_mgr.last_crit_hit = false
			progression_triggers._trigger_skill_tree_on_crit(target)
		# Proc-bonus attack: don't count towards next cycle
		if debuff_mgr:
			debuff_mgr.on_attack()
		add_battle_log("Basic Attack: %d damage to %s (Proc!)" % [damage, target.enemy_name], Color(1.0, 0.3, 0.3))
		print("[MAIN] Basic Attack (Dex Proc): dealt %d damage to %s — no tempo" % [damage, target.enemy_name])
	else:
		# Queue basic attack through the ticked tempo system.
		# Damage resolves on tick 1; remaining ticks are cooldown.
		var basic_card = Card.create_basic_attack(damage)
		var resolve_tick = 1

		# Store in the pending resolve queue (same as regular cards)
		var resolve_entry := {
			"card": basic_card,
			"target": target,
			"data": {
				"is_basic_attack": true,
				"basic_attack_damage": damage,
				"basic_attack_crit": buff_mgr.last_crit_hit if buff_mgr else false,
				"basic_attack_proc": basic_attack_proc,
			},
		}
		_pending_resolve_queue.append(resolve_entry)

		# Start ticked tempo
		_update_tick_bar(0, tempo_cost, resolve_tick, "Basic Attack")
		tempo_manager.add_card_tempo(tempo_cost, basic_card, resolve_tick)

		add_battle_log("Winding up Basic Attack on %s (resolves tick %d/%d)" % [target.enemy_name, resolve_tick, tempo_cost], Color(1.0, 0.85, 0.4))
		print("[MAIN] Basic Attack queued: %d damage to %s (%d tempo, resolve tick %d)" % [damage, target.enemy_name, tempo_cost, resolve_tick])

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

	# Pound the chest + raise the shield icon.
	if player.has_method("play_animation"):
		player.play_animation("block", CharacterAnimator.Direction.SOUTH)

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

# ============================================
# PILE CONTENTS POPUP (Draw / Discard / Jail buttons)
# ============================================

func _setup_pile_popup_panel() -> void:
	## Creates the shared popup panel used by the Draw, Discard, and Jail buttons.
	var ui = $UI as CanvasLayer
	pile_popup_panel = PanelContainer.new()
	pile_popup_panel.name = "PilePopupPanel"
	ui.add_child(pile_popup_panel)
	pile_popup_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	pile_popup_panel.offset_left = -290.0
	pile_popup_panel.offset_top = -220.0
	pile_popup_panel.offset_right = -10.0
	pile_popup_panel.offset_bottom = 220.0
	pile_popup_panel.custom_minimum_size = Vector2(280, 320)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.4, 0.55, 0.8)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.content_margin_left = 10.0
	panel_style.content_margin_right = 10.0
	panel_style.content_margin_top = 10.0
	panel_style.content_margin_bottom = 10.0
	pile_popup_panel.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.layout_mode = 1
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	pile_popup_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	margin.add_child(vbox)

	pile_popup_title_label = Label.new()
	pile_popup_title_label.text = ""
	pile_popup_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pile_popup_title_label.add_theme_font_size_override("font_size", 18)
	pile_popup_title_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	vbox.add_child(pile_popup_title_label)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 270)
	vbox.add_child(scroll)

	pile_popup_container = VBoxContainer.new()
	pile_popup_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pile_popup_container)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_close_pile_popup)
	vbox.add_child(close_btn)

	pile_popup_panel.visible = false

	# Hover preview panel for pile entries
	pile_popup_card_preview = PanelContainer.new()
	pile_popup_card_preview.name = "PilePopupCardPreview"
	ui.add_child(pile_popup_card_preview)
	pile_popup_card_preview.custom_minimum_size = Vector2(180, 0)
	var preview_style = StyleBoxFlat.new()
	preview_style.bg_color = Color(0.15, 0.15, 0.2, 0.98)
	preview_style.border_width_left = 2
	preview_style.border_width_right = 2
	preview_style.border_width_top = 2
	preview_style.border_width_bottom = 2
	preview_style.border_color = Color(0.4, 0.55, 0.8)
	preview_style.corner_radius_top_left = 4
	preview_style.corner_radius_top_right = 4
	preview_style.corner_radius_bottom_left = 4
	preview_style.corner_radius_bottom_right = 4
	preview_style.content_margin_left = 8.0
	preview_style.content_margin_right = 8.0
	preview_style.content_margin_top = 8.0
	preview_style.content_margin_bottom = 8.0
	pile_popup_card_preview.add_theme_stylebox_override("panel", preview_style)
	pile_popup_card_preview.visible = false
	pile_popup_card_preview.z_index = 200
	pile_popup_card_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_draw_pile_button_pressed() -> void:
	_toggle_pile_popup("draw")

func _on_discard_pile_button_pressed() -> void:
	_toggle_pile_popup("discard")

func _on_jail_pile_button_pressed() -> void:
	_toggle_pile_popup("jail")

func _toggle_pile_popup(pile: String) -> void:
	## Opens the popup for the given pile, or closes it if already showing the same pile.
	if pile_popup_visible and pile_popup_current_pile == pile:
		_close_pile_popup()
		return
	pile_popup_current_pile = pile
	pile_popup_visible = true
	pile_popup_panel.visible = true
	_populate_pile_popup()

func _close_pile_popup() -> void:
	pile_popup_visible = false
	pile_popup_current_pile = ""
	if pile_popup_panel:
		pile_popup_panel.visible = false
	if pile_popup_card_preview:
		pile_popup_card_preview.visible = false

func _populate_pile_popup() -> void:
	if not pile_popup_container or not pile_popup_title_label:
		return

	for child in pile_popup_container.get_children():
		child.queue_free()

	var cards: Array = []
	var title_text = ""
	var title_color = Color(0.55, 0.85, 1.0)
	match pile_popup_current_pile:
		"draw":
			cards = deck_manager.draw_pile.duplicate()
			title_text = "Draw Pile (%d)" % cards.size()
			title_color = Color(0.55, 0.85, 1.0)
		"discard":
			cards = deck_manager.discard_pile.duplicate()
			title_text = "Discard Pile (%d)" % cards.size()
			title_color = Color(1.0, 0.7, 0.4)
		"jail":
			cards = deck_manager.jail_pile.duplicate()
			title_text = "Jail Pile (%d)" % cards.size()
			title_color = Color(0.85, 0.45, 0.85)

	pile_popup_title_label.text = title_text
	pile_popup_title_label.add_theme_color_override("font_color", title_color)

	if cards.size() == 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "Empty."
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pile_popup_container.add_child(empty_lbl)
		return

	# Aggregate by card name to avoid huge lists
	var card_counts: Dictionary = {}
	var card_refs: Dictionary = {}
	for card in cards:
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
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		entry.add_theme_color_override("font_hover_color", title_color)
		entry.add_theme_font_size_override("font_size", 14)
		entry.mouse_entered.connect(_on_pile_popup_entry_hovered.bind(card_ref, entry))
		entry.mouse_exited.connect(_on_pile_popup_entry_unhovered)
		pile_popup_container.add_child(entry)

func _on_pile_popup_entry_hovered(card: Card, entry: Button) -> void:
	for child in pile_popup_card_preview.get_children():
		child.queue_free()

	var vbox = VBoxContainer.new()
	pile_popup_card_preview.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = card.card_name
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
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

	# Position preview to the left of the popup panel, near the hovered entry
	var entry_rect = entry.get_global_rect()
	var preview_x = pile_popup_panel.position.x - pile_popup_card_preview.size.x - 10
	var preview_y = entry_rect.position.y
	preview_y = max(preview_y, 4.0)
	pile_popup_card_preview.global_position = Vector2(preview_x, preview_y)
	pile_popup_card_preview.visible = true

func _on_pile_popup_entry_unhovered() -> void:
	if pile_popup_card_preview:
		pile_popup_card_preview.visible = false

func _refresh_pile_popup_if_open() -> void:
	## Refreshes the pile popup if it's currently visible (to keep counts in sync).
	if pile_popup_visible:
		_populate_pile_popup()

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

	# Cost (with dex proc preview for attack cards)
	var cost_lbl = Label.new()
	var preview_mana = card.mana_cost
	var preview_tempo = card.tempo_cost
	var preview_proc = deck_manager.next_attack_half_tempo and card.card_type == Card.CardType.ATTACK
	if preview_proc:
		preview_mana = max(0, preview_mana - deck_manager.next_attack_mana_discount)
		preview_tempo = preview_tempo / 2
		# Pocket Knife: additional -2 tempo
		var tip_inv = player.get_inventory()
		if tip_inv and tip_inv.has_pocket_knife_equipped():
			preview_tempo = maxi(0, preview_tempo - 2)
	if preview_proc:
		if card.maintain_cost > 0:
			cost_lbl.text = "Cost: %dM / %dT | Maintain: %dM" % [preview_mana, preview_tempo, card.maintain_cost]
		else:
			cost_lbl.text = "Cost: %dM / %dT" % [preview_mana, preview_tempo]
	elif card.maintain_cost > 0:
		cost_lbl.text = "Cost: %dM / %dT | Maintain: %dM" % [preview_mana, preview_tempo, card.maintain_cost]
	else:
		cost_lbl.text = "Cost: %dM / %dT" % [preview_mana, preview_tempo]
	cost_lbl.add_theme_font_size_override("font_size", 12)
	if preview_proc:
		cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
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

	# On Self section for slotted cards
	if card.is_slotted():
		var on_self = card.get_on_self_bonus()
		var on_self_parts: Array[String] = []
		if on_self.get("damage", 0) > 0:
			on_self_parts.append("+%d Damage" % on_self["damage"])
		if on_self.get("block", 0) > 0:
			on_self_parts.append("+%d Block" % on_self["block"])
		if on_self.get("heal", 0) > 0:
			on_self_parts.append("+%d Heal" % on_self["heal"])
		if on_self.get("mana_reduction", 0) > 0:
			on_self_parts.append("-%d Mana Cost" % on_self["mana_reduction"])
		if on_self.get("apply_burn", false):
			on_self_parts.append("Apply Burn")
		if on_self.get("apply_cold", false):
			on_self_parts.append("Apply Cold")
		if on_self.get("thorns", 0) > 0:
			on_self_parts.append("+%d Thorns" % on_self["thorns"])
		if on_self.get("upgrade", false):
			on_self_parts.append("Upgraded")
		var on_self_sep = HSeparator.new()
		vbox.add_child(on_self_sep)
		var on_self_header = Label.new()
		on_self_header.text = "\u2234 On Self"
		on_self_header.add_theme_font_size_override("font_size", 13)
		on_self_header.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
		vbox.add_child(on_self_header)
		if on_self_parts.size() > 0:
			var on_self_lbl = Label.new()
			on_self_lbl.text = ", ".join(on_self_parts)
			on_self_lbl.add_theme_font_size_override("font_size", 12)
			on_self_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
			on_self_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			on_self_lbl.custom_minimum_size.x = 180
			vbox.add_child(on_self_lbl)
		else:
			var none_lbl = Label.new()
			none_lbl.text = "No bonuses"
			none_lbl.add_theme_font_size_override("font_size", 12)
			none_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
			vbox.add_child(none_lbl)
		var item_lbl = Label.new()
		item_lbl.text = "Slotted in: %s" % card.slotted_in_item.item_name
		item_lbl.add_theme_font_size_override("font_size", 11)
		item_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		vbox.add_child(item_lbl)

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
		# A little gauntlet pops over the user's head (like the heal heart).
		player.show_gauntlet_skill()
		_update_gauntlet_skills_ui()

func _on_gauntlet_skill_ready(_gauntlet: ItemData) -> void:
	_update_gauntlet_skills_ui()

func _on_ring_triggered_visual(_ring: ItemData, _effect: String, owner_player: Player) -> void:
	## Visual-only: a small ring pops over the head of whichever character's
	## ring just triggered.
	if owner_player and is_instance_valid(owner_player):
		owner_player.show_ring_trigger()

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
	unit_tracker.offset_top = -150.0
	unit_tracker.offset_right = 250.0
	unit_tracker.offset_bottom = 250.0

	# Inspect panel: opens beside the tracker when an enemy square is clicked.
	enemy_inspect_ui = EnemyInspectUI.new()
	enemy_inspect_ui.name = "EnemyInspect"
	ui.add_child(enemy_inspect_ui)
	enemy_inspect_ui.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	enemy_inspect_ui.offset_left = 258.0
	enemy_inspect_ui.offset_top = -200.0
	unit_tracker.enemy_clicked.connect(_on_tracker_enemy_clicked)

	# Connect hover signals for bidirectional highlighting
	unit_tracker.enemy_hovered.connect(_on_tracker_enemy_hovered)
	unit_tracker.enemy_unhovered.connect(_on_tracker_enemy_unhovered)

func _on_tracker_enemy_clicked(enemy: Enemy) -> void:
	if enemy_inspect_ui:
		enemy_inspect_ui.show_enemy(enemy)

var _battlefield_hovered_enemy: Enemy = null

func _on_tracker_enemy_hovered(enemy: Enemy) -> void:
	## Panel portrait hovered → highlight enemy on battlefield + show damage preview
	if is_instance_valid(enemy):
		_sidebar_hover_active = true
		# Clear previous battlefield hover so it doesn't conflict
		if _prev_battlefield_hover and _prev_battlefield_hover != enemy and is_instance_valid(_prev_battlefield_hover):
			_set_enemy_highlight(_prev_battlefield_hover, false)
		_set_enemy_highlight(enemy, true)
		# Set as hovered so damage preview picks it up
		_prev_battlefield_hover = enemy

func _on_tracker_enemy_unhovered() -> void:
	## Panel portrait unhovered → clear battlefield highlight + damage preview
	_sidebar_hover_active = false
	if _battlefield_hovered_enemy and is_instance_valid(_battlefield_hovered_enemy):
		_set_enemy_highlight(_battlefield_hovered_enemy, false)
		_battlefield_hovered_enemy = null
	# Clear all highlights
	for enemy in enemy_spawner.get_living_enemies():
		_set_enemy_highlight(enemy, false)
	# Clear sidebar-triggered hover so damage preview hides
	_prev_battlefield_hover = null

func _set_enemy_highlight(enemy: Enemy, highlighted: bool) -> void:
	## Toggle the hover highlight on a battlefield enemy. Enemies with a sprite/
	## figure glow the model itself; box-mesh enemies use the outline box.
	if not enemy or not is_instance_valid(enemy):
		return
	enemy.set_hover_highlight(highlighted)
	if highlighted:
		_battlefield_hovered_enemy = enemy

func _refresh_unit_tracker() -> void:
	if unit_tracker:
		unit_tracker.refresh()

func select_character(character: CharacterData) -> void:
	current_character = character
	
	player.initialize_character(character)
	deck_manager.connect_player_stats(player.get_stats())

	debuff_bar.connect_manager(player.get_debuff_manager())
	deck_manager.connect_debuff_manager(player.get_debuff_manager())
	player.get_debuff_manager().point_to_prove_triggered.connect(progression_triggers._on_point_to_prove_triggered)
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
	player.get_stats().armor_gained.connect(_on_player_armor_gained)
	player.get_stats().dexterity_proc.connect(_on_dexterity_proc)
	player.get_stats().damage_taken.connect(_on_player_damage_taken)
	player.get_stats().maintained_cards_broken.connect(_on_maintained_cards_broken)
	player.get_stats().health_damage_taken.connect(_on_player_health_damage_taken)
	player.get_stats().healed.connect(_on_player_healed)
	player.get_stats().mana_gained.connect(_on_player_mana_gained)
	player.get_stats().shepherds_mark_triggered.connect(_on_shepherds_mark_triggered)
	deck_manager.on_draw_triggered.connect(_on_card_on_draw_triggered)
	deck_manager.card_erased.connect(_on_card_erased)
	# Ring procs pop a ring icon over the owner's head (like the heal heart).
	if player.get_inventory():
		player.get_inventory().ring_triggered.connect(_on_ring_triggered_visual.bind(player))

	character_panel.connect_stats(player.get_stats(), player.get_inventory(), deck_manager)


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
	progression_triggers._apply_all_unlocked_sphere_nodes()

	# Check and apply any already-completed constellations
	sphere_grid_ui.sphere_grid.check_constellation_completion()
	progression_triggers._apply_all_constellation_bonuses()


	# Initialize character skill tree (use character-specific tree if available)
	var skill_tree: SkillTreeData
	if character.character_name == "Brad":
		skill_tree = SkillTreeData.create_brad_tree()
	elif character.character_name == "Stephen":
		skill_tree = SkillTreeData.create_stephen_tree()
	elif character.character_name == "Ryan":
		skill_tree = SkillTreeData.create_ryan_tree()
	elif character.character_name == "Cory":
		skill_tree = SkillTreeData.create_cory_tree()
	elif character.character_name == "Jeremy":
		skill_tree = SkillTreeData.create_jeremy_tree()
	else:
		skill_tree = SkillTreeData.create_placeholder_tree(character.character_name, 20, character.archetypes)

	skill_tree_ui.set_skill_tree(skill_tree)
	skill_tree_ui.set_player_level(player.get_stats().current_level)

	print("[MAIN] Selected character: %s" % character.character_name)

# ============================================
# PLAYER 2 MULTIPLAYER SUPPORT
# ============================================


# Player 2 co-op UI moved to
# scripts/ui/player2_ui.gd


func trigger_turn() -> void:
	# Simulate one full tempo cycle (5 global tempo) for testing
	tempo_manager.add_tempo(5)

func trigger_multiple_turns(count: int) -> void:
	# Each "turn" = 5 global tempo (one cycle)
	tempo_manager.add_tempo(5 * count)

var _player_last_grid_cell: Vector2i = Vector2i(-1, -1)

func _on_player_tile_reached() -> void:
	# Scoop up any loot pile on the tile just reached (checked for BOTH players,
	# and before the batch-move early-out so batch movers loot too). Looting is
	# tempo-free — only the movement itself costs tempo.
	_check_loot_pickup()
	# During a locked-in batch move, the shared movement tempo is charged once up
	# front (see _on_move_players_pressed), so skip the normal per-tile accounting.
	if _batch_moving:
		return
	# Check if the player stepped onto an enemy-occupied tile (pass-through costs 2 tempo)
	var player_cell = grid_manager.world_to_grid(player.position)
	var passed_through_enemy = false
	for enemy in enemy_spawner.get_living_enemies():
		if grid_manager.world_to_grid(enemy.position) == player_cell:
			passed_through_enemy = true
			break
	if passed_through_enemy:
		tempo_manager.add_pass_through_tempo()

	# Climbing penalty: going to higher elevation costs +1 extra tempo per tile
	if dungeon_manager and _player_last_grid_cell.x >= 0:
		var prev_elev = dungeon_manager.get_elevation(_player_last_grid_cell)
		var curr_elev = dungeon_manager.get_elevation(player_cell)
		if curr_elev > prev_elev:
			var climb_cost = curr_elev - prev_elev
			tempo_manager.add_tempo(climb_cost)
			add_battle_log("Climbing! +%d tempo" % climb_cost, Color(0.8, 0.7, 0.4))
			print("[MAIN] Climbing penalty: +%d tempo (elev %d -> %d)" % [climb_cost, prev_elev, curr_elev])
	_player_last_grid_cell = player_cell

	# Fire walls (Fire Goblin Shaman): burn the player if they stepped into one.
	_check_fire_walls(player_cell)

	# Stepping off a climbed tree drops the player back to the ground.
	if _climbed_tree_tile.x >= 0 and player_cell != _climbed_tree_tile:
		_clear_climbed_tree()

	# Forest hazards: bear traps / hunters' darts spring on whoever steps on them.
	_trigger_terrain_traps_for(player_cell, player, true)

	# Player Y follows terrain smoothly via ground_y_provider (see player.gd)

	# Normal per-tile tempo
	tempo_manager.add_movement_tempo()
	# Check if player entered a new dungeon zone
	_check_dungeon_zones()
	# Reveal fog of war around the player
	_update_fog_of_war()
	# Check if player stepped onto a waypoint to discover it
	waypoint_mgr._check_waypoint_discovery(player_cell)
	# Update camera focus to follow player
	if dungeon_manager:
		_camera_focus = player.position + Vector3(2, 0, 0)
		_update_camera()

func _on_player_move_completed() -> void:
	# Catch any pickup missed by per-tile checks (e.g. teleports/blinks).
	_check_loot_pickup()
	# Final zone check at destination
	_check_dungeon_zones()
	_update_fog_of_war()
	# Sphere grid passive triggers for movement
	progression_triggers._trigger_sphere_passives("on_move", {})

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

# ---- Co-op locked-in (batched) movement ----

func _on_move_lock_in(target_pos: Vector3, spaces: int) -> void:
	## Queue the active character's move without spending tempo or moving yet, so
	## the player can TAB to the partner and queue theirs too. The "Move Players"
	## button then runs every locked move together on shared tempo.
	var debuff_mgr = player.get_debuff_manager()
	if debuff_mgr and debuff_mgr.is_tethered():
		if not debuff_mgr.is_within_tether_range(target_pos, grid_manager.grid_size):
			print("[MAIN] Cannot lock in move - Tethered! Out of range.")
			return

	_locked_moves[_active_index] = {"pos": target_pos, "spaces": spaces}
	_show_locked_marker(_active_index, target_pos)
	_ensure_move_players_button()
	_move_players_button.visible = true
	var who := player2_character.character_name if _active_index == 1 else starting_character.character_name
	add_battle_log("%s movement locked in (%d). TAB to the partner or press Move Players." % [who, spaces], Color(1.0, 0.85, 0.4))
	print("[MAIN] Locked in move for player %d: %d spaces" % [_active_index + 1, spaces])

func _ensure_move_players_button() -> void:
	if _move_players_button and is_instance_valid(_move_players_button):
		return
	var ui = $UI as CanvasLayer
	_move_players_button = Button.new()
	_move_players_button.name = "MovePlayersButton"
	_move_players_button.text = "▶ Move Players"
	_move_players_button.add_theme_font_size_override("font_size", 16)
	_move_players_button.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	ui.add_child(_move_players_button)
	_move_players_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_move_players_button.offset_left = -80.0
	_move_players_button.offset_top = 70.0
	_move_players_button.offset_right = 80.0
	_move_players_button.offset_bottom = 104.0
	_move_players_button.pressed.connect(_on_move_players_pressed)
	_move_players_button.visible = false

func _on_move_players_pressed() -> void:
	## Execute every locked-in move at once. Because the moves happen
	## simultaneously, the shared movement tempo is the LONGEST move's cost,
	## charged a single time rather than summed per character.
	if _locked_moves.is_empty():
		return

	var shared_steps := 0
	for idx in _locked_moves:
		shared_steps = max(shared_steps, int(_locked_moves[idx]["spaces"]))

	_batch_moving = true
	_batch_pending = _locked_moves.size()

	# Charge the shared movement tempo once for the synchronized steps.
	for i in range(shared_steps):
		tempo_manager.add_movement_tempo()

	for idx in _locked_moves.keys():
		var mv = _locked_moves[idx]
		var p: Player = _p1_player if idx == 0 else _p2_player
		if p and is_instance_valid(p):
			if not p.move_completed.is_connected(_on_batch_mover_done):
				p.move_completed.connect(_on_batch_mover_done, CONNECT_ONE_SHOT)
			p.move_to_grid(mv["pos"], int(mv["spaces"]))

	_clear_locked_markers()
	_locked_moves.clear()
	if _move_players_button:
		_move_players_button.visible = false
	add_battle_log("Players move together! (%d tempo)" % shared_steps, Color(0.5, 1.0, 0.6))
	print("[MAIN] Batch move: %d movers, shared %d steps" % [_batch_pending, shared_steps])

func _on_batch_mover_done() -> void:
	_batch_pending -= 1
	if _batch_pending <= 0:
		_batch_moving = false
		_batch_pending = 0
		print("[MAIN] Batch move complete.")

# ---- Co-op locked-in (batched) card play ----

func _ensure_card_confirm_dialog() -> void:
	if _card_confirm_panel and is_instance_valid(_card_confirm_panel):
		return
	var ui = $UI as CanvasLayer
	_card_confirm_panel = PanelContainer.new()
	_card_confirm_panel.name = "CardConfirmPanel"
	ui.add_child(_card_confirm_panel)
	var vbox := VBoxContainer.new()
	_card_confirm_panel.add_child(vbox)
	_card_confirm_label = Label.new()
	_card_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_card_confirm_label)
	var buttons := HBoxContainer.new()
	vbox.add_child(buttons)
	var play_btn := Button.new()
	play_btn.text = "Play Now"
	play_btn.pressed.connect(_on_card_play_now)
	buttons.add_child(play_btn)
	var lock_btn := Button.new()
	lock_btn.text = "Lock In Card"
	lock_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	lock_btn.pressed.connect(_on_card_lock_in)
	buttons.add_child(lock_btn)
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_on_card_confirm_cancel)
	buttons.add_child(cancel_btn)
	_card_confirm_panel.visible = false

func _show_card_confirm_dialog(card: Card, target) -> void:
	_ensure_card_confirm_dialog()
	_pending_card = card
	_pending_card_target = target
	var tname := ""
	if target is Enemy and is_instance_valid(target):
		tname = " on %s" % target.enemy_name
	elif target is Player and target != player:
		tname = " on your partner"
	_card_confirm_label.text = "Play %s%s?" % [card.card_name, tname]
	_card_confirm_panel.visible = true
	# Position near the mouse, kept on screen (same feel as the move dialog)
	var mouse_pos = get_viewport().get_mouse_position()
	_card_confirm_panel.position = mouse_pos + Vector2(20, -50)
	var screen_size = get_viewport().get_visible_rect().size
	_card_confirm_panel.reset_size()
	if _card_confirm_panel.position.x + _card_confirm_panel.size.x > screen_size.x:
		_card_confirm_panel.position.x = screen_size.x - _card_confirm_panel.size.x - 10
	if _card_confirm_panel.position.y < 0:
		_card_confirm_panel.position.y = 10

func _hide_card_confirm_dialog() -> void:
	if _card_confirm_panel:
		_card_confirm_panel.visible = false
	_pending_card = null
	_pending_card_target = null

func _on_card_play_now() -> void:
	var card := _pending_card
	var target = _pending_card_target
	_hide_card_confirm_dialog()
	if card == null:
		return
	# Re-find the card in the active hand in case the selection shifted while
	# the dialog was up.
	var idx := deck_manager.hand.find(card)
	if idx < 0:
		add_battle_log("%s is no longer in hand." % card.card_name, Color(1.0, 0.6, 0.3))
		return
	selected_card_index = idx
	_card_play_confirmed = true
	play_selected_card(target)
	_card_play_confirmed = false

func _on_card_lock_in() -> void:
	## Queue the card without paying tempo or leaving the hand, so the player
	## can TAB to the partner and line up theirs too. "Play Cards" fires all of
	## them together.
	var card := _pending_card
	var target = _pending_card_target
	_hide_card_confirm_dialog()
	if card == null:
		return
	for e in _locked_cards:
		if e["card"] == card:
			add_battle_log("%s is already locked in." % card.card_name, Color(1.0, 0.6, 0.3))
			return
	_locked_cards.append({"card": card, "target": target, "owner": _active_index})
	selected_card_index = -1
	if range_indicator:
		range_indicator.hide_range()
	update_selected_display()
	update_card_highlights()
	_ensure_play_cards_button()
	_play_cards_button.text = "▶ Play Cards (%d)" % _locked_cards.size()
	_play_cards_button.visible = true
	var who := player2_character.character_name if _active_index == 1 else starting_character.character_name
	add_battle_log("%s locked in %s. TAB to the partner or press Play Cards." % [who, card.card_name], Color(1.0, 0.85, 0.4))
	print("[MAIN] Locked in card for player %d: %s" % [_active_index + 1, card.card_name])

func _on_card_confirm_cancel() -> void:
	# Keep the card selected so the player can re-target or dismiss with ESC.
	_hide_card_confirm_dialog()

func _ensure_play_cards_button() -> void:
	if _play_cards_button and is_instance_valid(_play_cards_button):
		return
	var ui = $UI as CanvasLayer
	_play_cards_button = Button.new()
	_play_cards_button.name = "PlayCardsButton"
	_play_cards_button.text = "▶ Play Cards"
	_play_cards_button.add_theme_font_size_override("font_size", 16)
	_play_cards_button.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	ui.add_child(_play_cards_button)
	_play_cards_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_play_cards_button.offset_left = -80.0
	_play_cards_button.offset_top = 110.0
	_play_cards_button.offset_right = 80.0
	_play_cards_button.offset_bottom = 144.0
	_play_cards_button.pressed.connect(_on_play_cards_pressed)
	_play_cards_button.visible = false

func _on_play_cards_pressed() -> void:
	## Fire every locked-in card. Each is played as its owner (the same
	## owner-binding trick _on_card_tick_resolved uses), so tempo, buffs and
	## hands all charge to the right character; the ticks then run together.
	if _locked_cards.is_empty():
		return
	var batch := _locked_cards.duplicate()
	_locked_cards.clear()
	if _play_cards_button:
		_play_cards_button.visible = false

	var prev_p := player
	var prev_d := deck_manager
	var prev_idx := _active_index
	for e in batch:
		var card: Card = e["card"]
		var target = e["target"]
		var owner: int = e["owner"]
		if target is Enemy and (not is_instance_valid(target) or target.is_dead):
			add_battle_log("%s: target is gone — card stays in hand." % card.card_name, Color(1.0, 0.6, 0.3))
			continue
		_active_index = owner
		player = _p1_player if owner == 0 else _p2_player
		deck_manager = _p1_deck_manager if owner == 0 else _p2_deck_manager
		var idx := deck_manager.hand.find(card)
		if idx < 0:
			add_battle_log("%s is no longer in hand — skipped." % card.card_name, Color(1.0, 0.6, 0.3))
			continue
		selected_card_index = idx
		_card_play_confirmed = true
		play_selected_card(target)
		_card_play_confirmed = false
	_active_index = prev_idx
	player = prev_p
	deck_manager = prev_d
	selected_card_index = -1
	_on_hand_updated()
	update_deck_info()
	add_battle_log("Locked cards played together!", Color(0.5, 1.0, 0.6))
	print("[MAIN] Batch card play: %d cards" % batch.size())

## Returns the player character whose tile is at/near the world position, or null.
## Used for co-op ally targeting (click the partner to heal/buff them).
func _player_at_position(world_pos: Vector3) -> Player:
	var best: Player = null
	var best_d := 1.2  # within ~1 tile of the click
	for p in _all_players():
		if not is_instance_valid(p):
			continue
		var d := Vector2(p.position.x - world_pos.x, p.position.z - world_pos.z).length()
		if d < best_d:
			best_d = d
			best = p
	return best

func _all_players() -> Array:
	if is_multiplayer and _p2_player:
		return [_p1_player, _p2_player]
	return [player]

# ---- Co-op downed / revive / defeat ----

func _setup_co_op_defeat() -> void:
	var s1 = _p1_player.get_stats()
	var s2 = _p2_player.get_stats()
	if s1:
		s1.died.connect(_on_co_op_player_died.bind(0))
		s1.health_changed.connect(func(c, _m): _on_co_op_health(0, c))
	if s2:
		s2.died.connect(_on_co_op_player_died.bind(1))
		s2.health_changed.connect(func(c, _m): _on_co_op_health(1, c))

func _on_co_op_player_died(idx: int) -> void:
	if not is_multiplayer or _downed.get(idx, false):
		return
	_downed[idx] = true
	var who := player2_character.character_name if idx == 1 else starting_character.character_name
	add_battle_log("%s has fallen! Heal them to revive." % who, Color(1.0, 0.3, 0.3))
	print("[MAIN] Co-op: player %d (%s) is DOWNED" % [idx + 1, who])
	_show_downed_marker(idx, true)

	# If the fallen character was the one being controlled, hand control to the
	# surviving partner automatically.
	if _active_index == idx and not _downed.get(1 - idx, false):
		_switch_active_player()

	if _downed.get(0, false) and _downed.get(1, false):
		_on_co_op_defeat()

func _on_co_op_health(idx: int, current: int) -> void:
	# Revive a downed partner the moment they're healed above 0.
	if not is_multiplayer or _co_op_defeated:
		return
	if current > 0 and _downed.get(idx, false):
		_downed[idx] = false
		var who := player2_character.character_name if idx == 1 else starting_character.character_name
		add_battle_log("%s is back on their feet!" % who, Color(0.5, 1.0, 0.6))
		print("[MAIN] Co-op: player %d (%s) REVIVED at %d HP" % [idx + 1, who, current])
		_show_downed_marker(idx, false)

func _show_downed_marker(idx: int, downed: bool) -> void:
	var p: Player = _p1_player if idx == 0 else _p2_player
	if not p or not is_instance_valid(p):
		return
	if not downed:
		if _downed_markers.has(idx):
			var old = _downed_markers[idx]
			if is_instance_valid(old):
				old.queue_free()
			_downed_markers.erase(idx)
		return
	var tag := Label3D.new()
	tag.text = "DOWNED"
	tag.font_size = 32
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(1.0, 0.25, 0.25)
	tag.outline_size = 10
	tag.position = Vector3(0, 2.6, 0)
	p.add_child(tag)
	_downed_markers[idx] = tag

func _on_co_op_defeat() -> void:
	if _co_op_defeated:
		return
	_co_op_defeated = true
	add_battle_log("Both heroes have fallen. Defeat.", Color(1.0, 0.2, 0.2))
	print("[MAIN] CO-OP DEFEAT — both players down.")
	_show_defeat_overlay()

func _show_release_tension_picker(card: Card, enemy) -> void:
	## Let the player choose which damage-over-time debuff to drain from the enemy.
	## Auto-resolves when there are 0 or 1 choices.
	var fields := {"poison": "poison_stacks", "burn": "burn_stacks", "shock": "shock_stacks", "cold": "cold_stacks"}
	var present: Array = []
	for name in ["poison", "burn", "shock", "cold"]:
		var v = enemy.get(fields[name])
		if v != null and int(v) > 0:
			present.append({"name": name, "stacks": int(v)})

	if present.size() <= 1:
		card.rt_chosen_debuff = present[0]["name"] if present.size() == 1 else ""
		play_selected_card(enemy)
		return

	var ui = $UI as CanvasLayer
	var overlay := ColorRect.new()
	overlay.name = "ReleaseTensionPicker"
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.12, 0.13, 0.18, 1.0)
	pstyle.set_border_width_all(2)
	pstyle.border_color = Color(0.4, 0.6, 0.5)
	pstyle.set_corner_radius_all(8)
	pstyle.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", pstyle)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.custom_minimum_size = Vector2(280, 0)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Release Tension — drain which debuff?"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.7, 1.0, 0.8))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	for entry in present:
		var b := Button.new()
		b.text = "%s  (%d)" % [str(entry["name"]).capitalize(), entry["stacks"]]
		b.custom_minimum_size = Vector2(260, 36)
		b.pressed.connect(func():
			card.rt_chosen_debuff = entry["name"]
			overlay.queue_free()
			play_selected_card(enemy))
		vbox.add_child(b)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(260, 32)
	cancel.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(cancel)

func show_hand_card_picker(prompt: String, on_pick: Callable, exclude: Card = null) -> void:
	## Reusable hand-card picker: presents the cards in hand (minus `exclude`) and
	## calls on_pick(chosen_card) with the selection. Auto-resolves when there are
	## 0 or 1 candidates, so callers don't have to special-case those.
	var candidates: Array = []
	for c in deck_manager.hand:
		if c != exclude:
			candidates.append(c)
	if candidates.is_empty():
		on_pick.call(null)
		return
	if candidates.size() == 1:
		on_pick.call(candidates[0])
		return

	var ui = $UI as CanvasLayer
	var overlay := ColorRect.new()
	overlay.name = "HandCardPicker"
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.12, 0.13, 0.18, 1.0)
	pstyle.set_border_width_all(2)
	pstyle.border_color = Color(0.4, 0.6, 0.5)
	pstyle.set_corner_radius_all(8)
	pstyle.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", pstyle)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.custom_minimum_size = Vector2(280, 0)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = prompt
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.7, 1.0, 0.8))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	for c in candidates:
		var b := Button.new()
		b.text = c.card_name
		b.custom_minimum_size = Vector2(260, 36)
		b.pressed.connect(func():
			overlay.queue_free()
			on_pick.call(c))
		vbox.add_child(b)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(260, 32)
	cancel.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(cancel)

func _show_defeat_overlay() -> void:
	var ui = $UI as CanvasLayer
	var overlay := ColorRect.new()
	overlay.name = "DefeatOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.8)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(overlay)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 18)
	overlay.add_child(box)

	var title := Label.new()
	title.text = "DEFEAT"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Both heroes have fallen."
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var town_btn := Button.new()
	town_btn.text = "Return to Town"
	town_btn.custom_minimum_size = Vector2(220, 44)
	town_btn.pressed.connect(_travel_to_town)
	box.add_child(town_btn)

func _show_locked_marker(idx: int, world_pos: Vector3) -> void:
	## A translucent ghost at the locked destination so the queued move is visible.
	_remove_locked_marker(idx)
	var marker := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.35
	mesh.bottom_radius = 0.35
	mesh.height = 0.08
	marker.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.9, 0.4, 0.45) if idx == 0 else Color(1.0, 0.6, 0.3, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = mat
	marker.position = Vector3(world_pos.x, 0.1, world_pos.z)
	add_child(marker)
	_locked_move_markers[idx] = marker

func _remove_locked_marker(idx: int) -> void:
	if _locked_move_markers.has(idx):
		var m = _locked_move_markers[idx]
		if is_instance_valid(m):
			m.queue_free()
		_locked_move_markers.erase(idx)

func _clear_locked_markers() -> void:
	for idx in _locked_move_markers.keys():
		var m = _locked_move_markers[idx]
		if is_instance_valid(m):
			m.queue_free()
	_locked_move_markers.clear()

## Fires on every global tempo addition - routes to per-system handlers.
func _on_tempo_advanced(global_total: int, amount: int) -> void:
	# Sync enemy positions so they don't stack on each other
	_sync_occupied_tiles()
	# Each enemy manages its own action counter independently
	enemy_spawner.on_tempo_advanced(amount)

	# Summoned rats (Infestation) move/lunge after the enemies have acted.
	_update_summoned_rats()

	# Fire any scheduled delayed card effects whose timer has elapsed.
	_process_delayed_effects(amount)

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
				progression_triggers._trigger_skill_tree_on_displacement()

	# Always update the 20-tick global counter (fills on ALL tempo sources)
	if tempo_manager.is_ticking():
		var progress = tempo_manager.get_active_card_progress()
		if not progress.is_empty():
			var card_name = ""
			# Get card name from the pending resolve queue
			for qe in _pending_resolve_queue:
				if qe["card"] and qe["card"].card_name:
					card_name = qe["card"].card_name
					break
			_update_tick_bar(progress["ticks_elapsed"], progress["total_ticks"], progress["resolve_tick"], card_name)
		else:
			_update_tick_bar(0, 0, 0, "")
	else:
		_update_tick_bar(0, 0, 0, "")

	update_turn_display()
	_refresh_unit_tracker()

func _on_enemy_spawned_connect_debuffs(enemy: Enemy) -> void:
	## Connect debuff signals for skill tree passives (Pop Rocks, etc.).
	enemy.debuff_applied.connect(_on_enemy_debuff_applied)
	enemy.debuff_expired.connect(_on_enemy_debuff_expired)
	enemy.exposed.connect(_on_enemy_exposed)
	enemy.attacked_player.connect(_on_enemy_attacked_player)
	enemy.damaged.connect(_on_enemy_damaged.bind(enemy))
	enemy.movement_completed.connect(_on_enemy_movement_completed)
	# Give enemy a reference to dungeon_manager for elevation lookups
	if dungeon_manager:
		enemy.dungeon_manager = dungeon_manager
	# Smooth terrain-following Y (elevation, pillars)
	enemy.ground_y_provider = Callable(self, "_desired_ground_y")
	# Snap initial Y position to terrain elevation
	if dungeon_manager and grid_manager:
		var enemy_cell = grid_manager.world_to_grid(enemy.position)
		var elev_y = dungeon_manager.get_elevation_world_y(enemy_cell)
		enemy.position.y = elev_y
		enemy.target_position.y = elev_y

	# Olorin offers a one-time word of counsel on the player's first story battle.
	if olorin and not _roguelike_active:
		olorin.show_combat_intro()

var _disarm_mastery_applying: bool = false  # Guard against recursive disarm
var _wither_applying: bool = false  # Guard against recursive wither
var _laced_arrow_applying: bool = false  # Guard against recursive laced arrow
var _enemy_melee_state: Dictionary = {}  # Territorial Death: tracks enemy melee range state

func _on_enemy_debuff_applied(enemy: Enemy, debuff_name: String, value: int) -> void:
	progression_triggers._trigger_skill_tree_on_debuff_applied(enemy, debuff_name, value)
	# Stephen: Disarm Mastery — extra disarm stack (guarded against recursion)
	if debuff_name == "disarmed" and not _disarm_mastery_applying:
		_disarm_mastery_applying = true
		progression_triggers._trigger_skill_tree_stephen_on_disarm_applied(enemy, value)
		_disarm_mastery_applying = false
	# Stephen: Laced Arrow — when applying burn, cold, or shock, apply +1 additional (guarded against recursion)
	if not _laced_arrow_applying and debuff_name in ["burn", "cold", "shock"]:
		var stats = player.get_stats()
		if stats and stats.has_skill_tree_passive("laced_arrow"):
			_laced_arrow_applying = true
			if enemy.has_method("apply_debuff"):
				enemy.apply_debuff(debuff_name, 1)
				add_battle_log("Laced Arrow: +1 %s" % debuff_name, Color(0.4, 0.9, 0.4))
			_laced_arrow_applying = false
	# Cory: Wither — +1 charge to all debuffs applied (guarded against recursion)
	if not _wither_applying:
		var stats = player.get_stats()
		if stats and stats.has_skill_tree_passive("wither"):
			_wither_applying = true
			if enemy.has_method("apply_debuff"):
				enemy.apply_debuff(debuff_name, 1)
			_wither_applying = false
	# Cory: Prey on the Weak — bonus damage on debuff to low HP enemy
	progression_triggers._trigger_skill_tree_cory_on_debuff_applied(enemy, debuff_name, value)

func _on_enemy_debuff_expired(enemy: Enemy, debuff_name: String) -> void:
	progression_triggers._trigger_skill_tree_on_debuff_expired(enemy)

func _on_enemy_exposed(enemy: Enemy) -> void:
	progression_triggers._trigger_skill_tree_stephen_on_expose(enemy)

func _on_enemy_movement_completed(enemy: Enemy) -> void:
	# Enemy Y follows terrain smoothly via ground_y_provider (see enemy.gd)

	# Forest hazards: an enemy can blunder into a bear trap or tripwire too.
	if dungeon_manager and is_instance_valid(enemy) and not enemy.is_dead:
		_trigger_terrain_traps_for(grid_manager.world_to_grid(enemy.position), enemy, false)

	# Cory: Territorial Death — check if enemy entered or left melee range
	var dist = player.position.distance_to(enemy.position)
	var in_melee = dist <= 1.8  # Slightly larger than 1.5 to catch edge cases
	var enemy_id = enemy.get_instance_id()
	var was_in_melee = _enemy_melee_state.get(enemy_id, false)
	_enemy_melee_state[enemy_id] = in_melee
	if in_melee and not was_in_melee:
		# Enemy entered melee range
		progression_triggers._trigger_skill_tree_cory_on_enemy_enter_melee(enemy)
		progression_triggers._trigger_skill_tree_brad_itt_on_enter(enemy)
	elif was_in_melee and not in_melee:
		# Enemy left melee range — also triggers Territorial Death
		progression_triggers._trigger_skill_tree_cory_on_enemy_leave_melee(enemy)

func _on_enemy_damaged(damage: int, enemy: Enemy) -> void:
	progression_triggers._trigger_skill_tree_cory_on_enemy_damaged(enemy, damage)

func _on_enemy_attacked_player(enemy: Enemy) -> void:
	progression_triggers._trigger_skill_tree_brad_on_attacked(enemy)
	progression_triggers._trigger_skill_tree_stephen_on_attacked(enemy)
	progression_triggers._trigger_skill_tree_jeremy_on_enemy_attacked(enemy)

func _roll_hydra_drops() -> void:
	## A Hydra can drop the Hydra Heart relic and/or the Growth Within Resilience
	## card into the character's persistent collection (saved in Town).
	if not current_character:
		return
	if randf() < 0.33:
		if not current_character.unlocked_relic_ids.has("hydra_heart"):
			current_character.unlocked_relic_ids.append("hydra_heart")
			add_battle_log("The Hydra's heart still beats — Hydra Heart relic unlocked for the roguelike!", Color(0.9, 0.3, 0.4))
			print("[MAIN] Hydra dropped: Hydra Heart relic")
	if randf() < 0.33:
		if not current_character.purchased_card_ids.has("growth_within_resilience"):
			current_character.purchased_card_ids.append("growth_within_resilience")
			add_battle_log("You learn Growth Within Resilience!", Color(0.4, 0.8, 0.4))
			print("[MAIN] Hydra dropped: Growth Within Resilience card")

func _on_enemy_killed(enemy: Enemy) -> void:
	print("[MAIN] Enemy killed: %s (XP: %d)" % [enemy.enemy_name, enemy.xp_reward])
	player.get_stats().gain_xp(enemy.xp_reward)
	# Bestiary: record story-mode kills per character so a future roguelike can
	# gate monster-intent reveals on "defeated in story". Roguelike encounters
	# don't count toward unlocking their own intents.
	if not _roguelike_active and current_character and not current_character.defeated_monster_ids.has(enemy.enemy_name):
		current_character.defeated_monster_ids.append(enemy.enemy_name)
	# Hydra drops (story only): feed discoveries into the character's roguelike pool.
	if not _roguelike_active and enemy.enemy_type == Enemy.EnemyType.HYDRA:
		_roll_hydra_drops()
	_update_enemy_count()
	_refresh_unit_tracker()
	# Sphere grid passive triggers for kills
	progression_triggers._trigger_sphere_passives("on_kill", {"target": enemy})
	# Cory: Eat — heal on kill
	progression_triggers._trigger_skill_tree_cory_on_kill(enemy)
	# Quest tracking
	if quest_manager:
		quest_manager.on_enemy_killed(enemy.enemy_name)

	# Return any queued cards targeting this dead enemy back to the player's hand
	_return_queued_cards_for_dead_target(enemy)

func _on_all_enemies_defeated() -> void:
	_clear_summoned_rats()
	if _roguelike_active:
		_roguelike_active = false
		var hp := player.get_stats().current_health if player and player.get_stats() else 0
		print("[MAIN] Roguelike encounter cleared — returning to map (HP %d)." % hp)
		roguelike_battle_finished.emit(true, hp)
		return
	print("[MAIN] Wave complete! Press 'Spawn Wave' for more enemies.")
	_refresh_unit_tracker()

func _on_roguelike_player_died() -> void:
	## Player died during a roguelike encounter — the run is over.
	if not _roguelike_active:
		return
	_roguelike_active = false
	_clear_summoned_rats()
	print("[MAIN] Player died in roguelike encounter — run over.")
	roguelike_battle_finished.emit(false, 0)

func _start_roguelike_battle() -> void:
	## Spawn the encounter for the roguelike map node that launched this scene,
	## then arm the win condition that returns control to the map.
	_clear_loot_drops()  # No stale piles from a previous room
	_roguelike_relics = roguelike_context.get("relics", [])
	var node_type: String = roguelike_context.get("node_type", "monster")
	match node_type:
		"elite":
			enemy_spawner.spawn_enemy(Enemy.EnemyType.ELITE, _roguelike_spawn_pos(Vector2i(13, 5)))
			enemy_spawner.spawn_enemy(Enemy.EnemyType.WERERAT, _roguelike_spawn_pos(Vector2i(15, 7)))
		"boss":
			enemy_spawner.spawn_enemy(Enemy.EnemyType.ELITE, _roguelike_spawn_pos(Vector2i(13, 5)))
			enemy_spawner.spawn_enemy(Enemy.EnemyType.ARMORED_TROLL, _roguelike_spawn_pos(Vector2i(15, 6)))
			enemy_spawner.spawn_enemy(Enemy.EnemyType.SKELETON, _roguelike_spawn_pos(Vector2i(11, 7)))
		_:
			enemy_spawner.spawn_test_arena()
	_sync_blocked_tiles()
	_sync_occupied_tiles()
	_sync_pillar_tiles()
	_update_enemy_count()
	_refresh_unit_tracker()
	# End the run if the player dies this encounter.
	var stats = player.get_stats()
	if stats and not stats.died.is_connected(_on_roguelike_player_died):
		stats.died.connect(_on_roguelike_player_died)
	_roguelike_active = true
	print("[MAIN] Roguelike encounter started (%s)." % node_type)

func _roguelike_spawn_pos(cell: Vector2i) -> Vector3:
	var world_pos := grid_manager.grid_to_world(cell)
	if dungeon_manager:
		world_pos.y = dungeon_manager.get_elevation_world_y(cell)
	return world_pos

# ============================================
# FIRE WALLS (Fire Goblin Shaman)
# ============================================

func register_fire_wall(tiles: Array, damage: int, burn: int, moves: int = 6) -> void:
	## Called by a Fire Goblin Shaman. Lays a hazard on the given grid cells that
	## burns the player when they walk into it; expires after a few player moves.
	var visuals: Array = []
	for cell in tiles:
		var v = _spawn_fire_wall_visual(cell)
		if v:
			visuals.append(v)
	_fire_walls.append({"tiles": tiles, "damage": damage, "burn": burn, "moves_left": moves, "visuals": visuals})
	add_battle_log("A wall of fire erupts!", Color(1.0, 0.5, 0.2))

func _spawn_fire_wall_visual(cell: Vector2i) -> MeshInstance3D:
	if not grid_manager:
		return null
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.7, 0.9)
	box.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.4, 0.1, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.1)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box.material_override = mat
	var pos := grid_manager.grid_to_world(cell)
	if dungeon_manager:
		pos.y = dungeon_manager.get_elevation_world_y(cell)
	box.position = pos + Vector3(0, 0.35, 0)
	add_child(box)
	return box

func _check_fire_walls(player_cell: Vector2i) -> void:
	if _fire_walls.is_empty():
		return
	var survivors: Array = []
	for wall in _fire_walls:
		if wall["tiles"].has(player_cell):
			_burn_player_from_fire(wall["damage"], wall["burn"])
		wall["moves_left"] -= 1
		if wall["moves_left"] > 0:
			survivors.append(wall)
		else:
			for v in wall["visuals"]:
				if is_instance_valid(v):
					v.queue_free()
	_fire_walls = survivors

func _burn_player_from_fire(damage: int, burn: int) -> void:
	var stats = player.get_stats()
	if not stats:
		return
	var dm = player.get_debuff_manager() if player.has_method("get_debuff_manager") else null
	var bm = player.get_buff_manager() if player.has_method("get_buff_manager") else null
	stats.take_damage(damage, dm, bm)
	if dm:
		for _i in range(burn):
			dm.apply_debuff(Debuff.new(Debuff.DebuffType.BURN, 1))
	add_battle_log("Fire wall burns you for %d (+%d burn)!" % [damage, burn], Color(1.0, 0.4, 0.1))

# ============================================
# FOREST HAZARDS — bear traps & hunters' tripwire darts
# ============================================

func _trigger_terrain_traps_for(cell: Vector2i, unit, is_player: bool) -> void:
	## Springs any armed forest trap on `cell`. Bear traps and dart tripwires are
	## single-use: once sprung they no longer trigger.
	if not dungeon_manager:
		return
	for trap in dungeon_manager.trap_defs:
		if trap.get("sprung", false):
			continue
		if not trap["tiles"].has(cell):
			continue
		trap["sprung"] = true
		_spring_trap(trap, unit, is_player)

func _spring_trap(trap: Dictionary, unit, is_player: bool) -> void:
	var kind: String = trap["kind"]
	var dmg: int
	var label: String
	if kind == "bear":
		dmg = BEAR_TRAP_DAMAGE
		if not is_player and _is_bear(unit):
			dmg = BEAR_TRAP_BEAR_DAMAGE
		label = "bear trap"
	else:
		dmg = DART_TRAP_DAMAGE
		label = "hunters' darts"

	if is_player:
		var stats = player.get_stats()
		if stats:
			var dmgr = player.get_debuff_manager() if player.has_method("get_debuff_manager") else null
			var bmgr = player.get_buff_manager() if player.has_method("get_buff_manager") else null
			stats.take_damage(dmg, dmgr, bmgr)
		add_battle_log("A %s snaps shut — %d damage!" % [label, dmg], Color(0.9, 0.5, 0.2))
	elif is_instance_valid(unit):
		unit.take_damage(dmg, false)
		add_battle_log("%s hits a %s for %d!" % [unit.enemy_name, label, dmg], Color(0.8, 0.7, 0.4))

	_animate_trap_sprung(trap)

func _is_bear(enemy) -> bool:
	if not is_instance_valid(enemy):
		return false
	if enemy.enemy_type == Enemy.EnemyType.MINI_BEAR or enemy.enemy_type == Enemy.EnemyType.LARGE_BEAR:
		return true
	return "Bear" in enemy.enemy_name

func _animate_trap_sprung(trap: Dictionary) -> void:
	## Visual feedback: bear traps darken (snapped shut); dart traps flash red.
	var node = trap.get("node")
	if not node or not is_instance_valid(node):
		return
	var tint = Color(0.35, 0.1, 0.1) if trap["kind"] == "dart" else Color(0.08, 0.08, 0.09)
	for child in node.get_children():
		if child is MeshInstance3D and child.material_override is StandardMaterial3D:
			(child.material_override as StandardMaterial3D).albedo_color = tint

# ============================================
# CLIMBABLE TREES — climb a low branch for high ground (forest)
# ============================================

func _try_climb_tree() -> bool:
	## Shift near a climbable tree: climb up (high ground) or, if already up, down.
	if not dungeon_manager:
		return false
	if _climbed_tree_tile.x >= 0:
		_climb_down()
		return true
	var pg = grid_manager.world_to_grid(player.position)
	var idx = dungeon_manager.get_nearby_climbable_tree(pg)
	if idx < 0:
		return false
	var tree = dungeon_manager.tree_nodes[idx]
	var tile: Vector2i = tree["grid_pos"]
	var wpos = grid_manager.grid_to_world(tile)
	wpos.y = TREE_CANOPY_Y
	player.position = wpos
	player.target_position = wpos
	_climbed_tree_tile = tile
	tree["climbed"] = true
	add_battle_log("You climb the tree — high ground!", Color(0.6, 0.9, 0.4))

	# One-time tutorial the first time the player ever climbs.
	if olorin:
		olorin.show_tutorial(
			"first_climbable_tree",
			"Climbing Trees",
			[
				"Some trees have a sturdy low branch you can climb. Press [Shift] beside one to scramble up.",
				"From the branches you hold the high ground: ranged attacks gain damage and reach, and most enemies can't strike you up there. Press [Shift] again — or simply move — to come back down.",
			]
		)
	return true

func _climb_down() -> void:
	## Drop the player from a tree to the nearest open adjacent floor tile.
	var base = _climbed_tree_tile
	_clear_climbed_tree()
	if base.x < 0:
		return
	var occupied: Array[Vector2i] = []
	for e in enemy_spawner.get_living_enemies():
		occupied.append(grid_manager.world_to_grid(e.position))
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var t = base + dir
		if dungeon_manager.is_floor(t) and not dungeon_manager.pit_tiles.has(t) and t not in occupied:
			var wpos = grid_manager.grid_to_world(t)
			wpos.y = dungeon_manager.get_elevation_world_y(t)
			player.position = wpos
			player.target_position = wpos
			break
	add_battle_log("You climb down.", Color(0.7, 0.8, 0.6))

func _clear_climbed_tree() -> void:
	if _climbed_tree_tile.x < 0:
		return
	if dungeon_manager:
		for tree in dungeon_manager.tree_nodes:
			if tree["grid_pos"] == _climbed_tree_tile:
				tree["climbed"] = false
	_climbed_tree_tile = Vector2i(-1, -1)

func _is_climbed_tree(world_pos: Vector3) -> bool:
	if _climbed_tree_tile.x < 0:
		return false
	return grid_manager.world_to_grid(world_pos) == _climbed_tree_tile

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


# Progression triggers (sphere grid, skill tree, sphere passives) moved to
# scripts/progression/progression_triggers.gd

func _update_enemy_count() -> void:
	test_ui.update_enemy_count(enemy_spawner.get_enemy_count())

func _on_turn_ended(turn_number: int) -> void:
	update_deck_info()

func _on_player_health_changed(current: int, max_hp: int) -> void:
	if player_health_label:
		player_health_label.visible = false
	if _hp_bar:
		_hp_bar.max_value = max_hp
		_hp_bar.value = current
	if _hp_bar_label:
		var pct = int(float(current) / float(max_hp) * 100.0) if max_hp > 0 else 0
		_hp_bar_label.text = "%d/%d (%d%%)" % [current, max_hp, pct]

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
		player_mana_label.visible = false
	if _mana_bar:
		_mana_bar.max_value = max_mana
		_mana_bar.value = int(current)
	if _mana_bar_label:
		_mana_bar_label.text = "%d/%d" % [int(current), max_mana]

func _on_player_armor_gained(_amount: int) -> void:
	## Armour gained from any source — pop the overhead armour icon.
	if player and player.has_method("show_armor_gained"):
		player.show_armor_gained()

func _on_player_armor_changed(current: int) -> void:
	if player_armor_label:
		player_armor_label.visible = false
	if _armor_bar:
		# Armor has no fixed max — use current as value, scale bar dynamically
		_armor_bar.max_value = max(current, 1)
		_armor_bar.value = current
	if _armor_bar_label:
		_armor_bar_label.text = "%d" % current

func _update_xp_display() -> void:
	if player_xp_label:
		player_xp_label.visible = false
	var stats = player.get_stats()
	if stats and _xp_bar:
		var xp_to_next = stats.get_xp_to_next_level()
		_xp_bar.max_value = xp_to_next
		_xp_bar.value = stats.current_xp
	if stats and _xp_bar_label:
		_xp_bar_label.text = "(%d) %d/%d" % [stats.current_level, stats.current_xp, stats.get_xp_to_next_level()]

func _on_dexterity_proc() -> void:
	print("[MAIN] Dexterity proc! Next attack: half tempo + 2 mana discount!")
	deck_manager.apply_dex_proc_bonus()
	# Stephen: Dominate — on dex proc, gain free attack card
	progression_triggers._trigger_skill_tree_stephen_on_dex_proc()
	# Refresh hand so attack cards show discounted mana/tempo
	_on_hand_updated()
	# Refresh attack button to show PROC state
	_update_attack_button_text()

func _on_maintained_cards_broken() -> void:
	## Called when player's mana hits 0 - all maintained Power cards are discarded
	deck_manager.break_all_maintained_cards()
	print("[MAIN] All maintained cards broken due to mana depletion!")

func _on_player_health_damage_taken(hp_amount: int) -> void:
	## Process maintained card effects that trigger on HP damage
	if hp_amount <= 0:
		# Damage was fully absorbed by armor → trigger on_block passives
		progression_triggers._trigger_sphere_passives("on_block", {})
		return
	player.spawn_damage_number(hp_amount)
	# Play hit animation when taking damage
	if player.has_method("play_animation"):
		if hp_amount >= 10:
			player.play_animation("hit_heavy")
		else:
			player.play_animation("hit")
	var stats = player.get_stats()

	# Exposed (damage broke through armor): fire on_exposed reactions.
	var exposed_reactions = deck_manager.trigger_reactions("on_exposed")
	for rcard in exposed_reactions:
		rcard.execute(null, stats, deck_manager, 0.0, 0.0, player.get_buff_manager())
		if rcard.card_id == "vengeful_shield":
			_stun_nearest_enemy(2.0)
	if exposed_reactions.size() > 0:
		_refresh_unit_tracker()
	for card in deck_manager.get_maintained_cards():
		if card.card_id == "armored_discipline":
			stats.add_armor(hp_amount)
			print("[MAIN] Armored Discipline: gained %d armor from %d HP damage!" % [hp_amount, hp_amount])

	# Skill tree passive triggers on damage taken
	progression_triggers._trigger_skill_tree_brad_on_damage_taken(hp_amount)
	progression_triggers._trigger_skill_tree_cory_on_damage_taken(hp_amount)

func _on_player_healed(amount: int) -> void:
	player.spawn_heal_number(amount)
	# Heal from any source pops the overhead heart icon.
	if amount > 0 and player.has_method("show_heal_icon"):
		player.show_heal_icon()
	# Sphere grid passive triggers for healing
	var stats = player.get_stats()
	var overheal = 0
	if stats and stats.current_health >= stats.max_health:
		overheal = amount  # approximate overheal
	progression_triggers._trigger_sphere_passives("on_heal", {"overheal": overheal})

	# Skill tree passive triggers on heal
	progression_triggers._trigger_skill_tree_brad_on_heal()
	progression_triggers._trigger_skill_tree_cory_on_heal()
	# Whispers of the Flock: healing (self/ally) adds a Shepherd's Mark to hand.
	progression_triggers._trigger_skill_tree_jeremy_on_heal_ally()

func _on_player_mana_gained(amount: int, is_regen: bool) -> void:
	# Cory: Energy Barrier — track non-regen mana gains
	progression_triggers._trigger_skill_tree_cory_on_mana_gain(amount, is_regen)

func update_turn_display() -> void:
	# Turn label no longer needed — global tempo is shown on tick bar, atk sp proc on attack button
	if turn_label:
		turn_label.visible = false
	# Update attack button with proc count
	_update_attack_button_text()
	# Update draw label with tempo until draw
	_update_draw_label()

func _on_hand_updated() -> void:
	if hand_card_preview:
		hand_card_preview.visible = false
	_current_hand_hover_index = -1

	# Cory: Regrowth — draw 4 when hand is empty
	if deck_manager.hand.is_empty():
		progression_triggers._trigger_skill_tree_cory_on_hand_empty()

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

	# Roll RNG for cards that haven't been rolled yet. The one-shot next_odds_boost
	# (Loaded Die / House Money) is added on top of the permanent chance_boost and
	# consumed once a card is actually rolled.
	var enemies = enemy_spawner.get_living_enemies()
	var _rng_stats = player.get_stats()
	var chance_boost = _rng_stats.chance_boost + _rng_stats.next_odds_boost
	for card in deck_manager.hand:
		if card.has_chance_effect() and not card.has_been_rolled():
			card.roll_rng(enemies, chance_boost)
			card.rng_roll_tempo = tempo_manager.global_tempo
			_rng_stats.next_odds_boost = 0.0  # consumed on the next rolled card

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

	var dex_proc_active = deck_manager.next_attack_half_tempo or deck_manager.next_attack_mana_discount > 0
	var pocket_knife = false
	if dex_proc_active:
		var hand_inv = player.get_inventory()
		pocket_knife = hand_inv and hand_inv.has_pocket_knife_equipped()

	for i in range(hand_size):
		var card_ui = CardUIScene.instantiate()
		hand_container.add_child(card_ui)
		card_ui.setup(deck_manager.hand[i], i, debuff_mgr, dex_proc_active, pocket_knife)

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

# ---- Card exit animations (visual-only; safe to fire for either deck) ----

func _hand_ui_for_card(card: Card) -> CardUI:
	## The on-screen CardUI currently showing `card`, or null (e.g. the card
	## belongs to the deck that isn't displayed right now).
	for child in hand_container.get_children():
		if child is CardUI and not child._is_animating_out and child.get_card() == card:
			return child
	return null

func _animate_card_discard(card: Card) -> void:
	## Any card headed for the discard pile pops up, pauses, then gets sucked
	## in bottom-first (like squeezing into a too-small tube).
	var ui := _hand_ui_for_card(card)
	if ui:
		ui.animate_played_to_discard(_get_discard_pile_pos())

func _animate_card_instant(card: Card) -> void:
	## Instant (reaction) cards pop up, spin twice, then discard.
	var ui := _hand_ui_for_card(card)
	if ui:
		ui.animate_instant(_get_discard_pile_pos())

func _animate_card_erase(card: Card) -> void:
	## Erase expiring in hand: the card disintegrates into drifting particles.
	var ui := _hand_ui_for_card(card)
	if ui:
		ui.animate_disintegrate()

func _on_card_discarded(card: Card) -> void:
	# Sphere grid passive triggers for discard
	progression_triggers._trigger_sphere_passives("on_discard", {"card": card})
	# Skill tree passive triggers for discard
	progression_triggers._trigger_skill_tree_on_discard(card)
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
	progression_triggers._trigger_sphere_passives("on_draw", {"card": card})
	progression_triggers._trigger_skill_tree_on_draw(card)

func _on_deck_shuffled() -> void:
	update_deck_info()
	_animate_shuffle()
	# Cory: Circle of Life
	progression_triggers._trigger_skill_tree_cory_on_shuffle()

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

		# Sphere-grid regen (e.g. Nature's Grace): heal each cycle, routed through
		# heal() so Raged Circulation's healing boost applies to it too.
		var regen_stats = player.get_stats()
		if regen_stats and regen_stats.sphere_bonus_regen > 0:
			regen_stats.heal(regen_stats.sphere_bonus_regen)

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
		_process_in_hand_cards()

	# Sphere grid passive triggers for tempo cycle
	progression_triggers._trigger_sphere_passives("on_cycle", {})
	progression_triggers._trigger_sphere_passives("on_tempo_cycle", {})

	# Skill tree passive triggers for tempo cycle
	progression_triggers._trigger_skill_tree_on_cycle()
	progression_triggers._trigger_skill_tree_brad_on_cycle()
	progression_triggers._trigger_skill_tree_cory_on_cycle()
	progression_triggers._trigger_skill_tree_jeremy_on_cycle()
	if tempo_manager.last_tempo_source == "movement":
		progression_triggers._trigger_skill_tree_on_movement_cycle()

	# Reset per-cycle movement tracking (after passives have read it)
	tempo_manager.spaces_moved_this_cycle = 0

	_check_volatile_mixture_in_hand()
	_apply_in_hand_debuffs()
	_process_enchantment_cycles()
	_process_healthy_bliss_cards()
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
		# Halo: heal all allies (self-only in solo, both players in co-op).
		for ally in _all_players():
			if is_instance_valid(ally) and ally.get_stats():
				ally.get_stats().heal(maintained_result["total_heal"])
		print("[MAIN] Maintained cards healed for %d HP" % maintained_result["total_heal"])
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

func _process_healthy_bliss_cards() -> void:
	var hand_changed = false
	for i in range(deck_manager.hand.size() - 1, -1, -1):
		var card = deck_manager.hand[i]
		if card.card_id != "healthy_bliss":
			continue
		card.cycles_in_hand += 1
		if card.cycles_in_hand >= 4:  # 4 cycles = 20 tempo
			# Heal all allies for 10
			var stats = player.get_stats()
			if stats:
				var heal_amt = stats.get_effective_heal_amount(card.heal_amount)
				stats.heal(heal_amt)
				add_battle_log("Healthy Bliss heals all allies for %d!" % heal_amt, Color(0.4, 1.0, 0.5))
			for ally in get_tree().get_nodes_in_group("allies"):
				if ally.has_method("heal"):
					ally.heal(card.heal_amount)
			# Discard the card
			deck_manager.hand.remove_at(i)
			deck_manager.discard_pile.append(card)
			card.cycles_in_hand = 0
			hand_changed = true
			print("[MAIN] Healthy Bliss triggered after 20 tempo in hand")
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

## Run `callback` after `tempo_delay` global tempo elapses. The caller captures
## any needed references (player, deck) so the effect resolves on the right
## target even if control has switched in the meantime.
func schedule_delayed_effect(tempo_delay: int, callback: Callable, label: String = "") -> void:
	_delayed_effects.append({"remaining": tempo_delay, "callback": callback, "label": label})

func _process_delayed_effects(amount: int) -> void:
	for i in range(_delayed_effects.size() - 1, -1, -1):
		var d = _delayed_effects[i]
		d.remaining -= amount
		if d.remaining <= 0:
			_delayed_effects.remove_at(i)
			if d.callback.is_valid():
				d.callback.call()

## Map a player character to its own DeckManager (co-op aware).
func _deck_for_player(p) -> DeckManager:
	if is_multiplayer:
		if p == _p2_player:
			return _p2_deck_manager
		if p == _p1_player:
			return _p1_deck_manager
	return deck_manager

## Add `delta` tempo (clamped at 0) to `count` random cards in a deck's hand.
func _adjust_random_hand_tempo(deck, count: int, delta: int) -> void:
	if not deck or deck.hand.is_empty():
		return
	var cards: Array = deck.hand.duplicate()
	cards.shuffle()
	for i in range(min(count, cards.size())):
		cards[i].tempo_cost = max(0, cards[i].tempo_cost + delta)
	deck.hand_updated.emit()

# --- Delayed card-effect handlers (scheduled via schedule_delayed_effect) ---

func _spark_delayed(deck) -> void:
	_adjust_random_hand_tempo(deck, 2, 2)
	add_battle_log("Spark: +2 tempo to 2 random cards", Color(0.7, 0.85, 1.0))

func _patience_delayed(deck) -> void:
	if deck:
		for i in range(3):
			deck.draw_card()
	add_battle_log("Patience: drew 3 cards", Color(0.5, 0.9, 0.5))

func _adrenaline_delayed(deck) -> void:
	_adjust_random_hand_tempo(deck, 1, 3)
	_adjust_random_hand_tempo(deck, 1, 2)
	add_battle_log("Adrenaline Shot wears off: +tempo to the target's cards", Color(1.0, 0.7, 0.5))

func _vines_tick(en, dmg: int) -> void:
	if is_instance_valid(en) and not en.is_dead and en.has_method("take_damage"):
		en.take_damage(dmg, true)

func _try_this_revert(tt_stats) -> void:
	if is_instance_valid(tt_stats):
		tt_stats.max_mana = max(1, tt_stats.max_mana - 3)
		tt_stats.hand_size = max(1, tt_stats.hand_size - 2)

func _stun_nearest_enemy(within: float) -> void:
	## Stun the closest living enemy within `within` tiles of the player.
	if not enemy_spawner:
		return
	var nearest = null
	var best := INF
	for en in enemy_spawner.get_living_enemies():
		var d = player.position.distance_to(en.position)
		if d <= within and d < best:
			best = d
			nearest = en
	if nearest and nearest.has_method("apply_stun"):
		nearest.apply_stun()
		add_battle_log("Vengeful Shield: stunned %s!" % nearest.enemy_name, Color(1.0, 1.0, 0.3))

func _harness_lightning_tick() -> void:
	## Harness Lightning orb: zap a random living enemy within 3 tiles for 4.
	if not enemy_spawner:
		return
	var in_range: Array = []
	for en in enemy_spawner.get_living_enemies():
		if player.position.distance_to(en.position) <= 3.0:
			in_range.append(en)
	if in_range.size() > 0:
		in_range[randi() % in_range.size()].take_damage(4, true)

func _cryonics_heal(p) -> void:
	if is_instance_valid(p) and p.get_stats():
		p.get_stats().heal(3)

func _cryonics_end(p) -> void:
	if is_instance_valid(p):
		p.untargetable = false
		add_battle_log("The ice melts — ally can act again.", Color(0.6, 0.85, 1.0))

## Friendship: link both players' stats so heals are shared and incoming damage
## is split 50/50 (handled inside PlayerStats.heal/take_damage on pre-modifier
## amounts, so each side applies its own amplification/penalty).
func _link_friendship() -> void:
	if _friendship_linked:
		return
	_friendship_linked = true
	var s1 = _p1_player.get_stats()
	var s2 = _p2_player.get_stats()
	if s1 and s2:
		s1.friendship_partner = s2
		s1.friendship_partner_debuff = _p2_player.get_debuff_manager()
		s1.friendship_partner_buff = _p2_player.get_buff_manager()
		s2.friendship_partner = s1
		s2.friendship_partner_debuff = _p1_player.get_debuff_manager()
		s2.friendship_partner_buff = _p1_player.get_buff_manager()

## Misery Loves Company: if armed, spread every damage-over-time debuff on the
## player and any hit enemy across all the hit enemies (topping each up to the
## highest stack seen). Consumes the arm.
func _apply_misery_spread(hit_enemies: Array) -> void:
	if not _misery_active or hit_enemies.is_empty():
		return
	_misery_active = false
	var fields = {"burn": "burn_stacks", "poison": "poison_stacks", "shock": "shock_stacks", "cold": "cold_stacks"}
	var maxv = {"burn": 0, "poison": 0, "shock": 0, "cold": 0}
	for en in hit_enemies:
		for t in fields:
			var v = en.get(fields[t])
			if v != null and int(v) > maxv[t]:
				maxv[t] = int(v)
	var pdm = player.get_debuff_manager()
	if pdm:
		var pmap = {"burn": Debuff.DebuffType.BURN, "poison": Debuff.DebuffType.POISON, "shock": Debuff.DebuffType.SHOCKED, "cold": Debuff.DebuffType.COLD}
		for t in pmap:
			if pdm.has_debuff(pmap[t]):
				var d = pdm.get_debuff(pmap[t])
				if d and d.value > maxv[t]:
					maxv[t] = d.value
	for en in hit_enemies:
		for t in fields:
			var cur = en.get(fields[t])
			cur = int(cur) if cur != null else 0
			var add = maxv[t] - cur
			if add > 0:
				en.apply_debuff(t, add)
	add_battle_log("Misery spread debuffs across %d enemies!" % hit_enemies.size(), Color(0.85, 0.5, 0.95))
	print("[MAIN] Misery Loves Company spread: %s" % str(maxv))

func _succumb_phase1(caster) -> void:
	if is_instance_valid(caster) and caster.get_stats():
		caster.get_stats().take_damage(10)
		add_battle_log("Succumb: took 10 damage", Color(1.0, 0.45, 0.45))

func _succumb_phase2(caster) -> void:
	if not is_instance_valid(caster):
		return
	if caster.get_stats():
		caster.get_stats().take_damage(10)
	var bm = caster.get_buff_manager()
	if bm and bm.debuff_manager:
		bm.debuff_manager.apply_debuff(Debuff.create(Debuff.DebuffType.CUFFED, 1, 10))
		bm.debuff_manager.apply_debuff(Debuff.create(Debuff.DebuffType.DRAIN, 1, 10))
		bm.debuff_manager.apply_debuff(Debuff.create(Debuff.DebuffType.DISARM, 1, 10))
	add_battle_log("Succumb: took 10 more damage; cuffed, drained, disarmed", Color(1.0, 0.3, 0.3))

func _process_in_hand_cards() -> void:
	## Per-cycle: advance in-hand timers (Healthy Bliss). When one elapses, heal
	## all allies and discard the card.
	var decks := [deck_manager]
	if is_multiplayer and _p1_deck_manager and _p2_deck_manager:
		decks = [_p1_deck_manager, _p2_deck_manager]
	for dmgr in decks:
		if not dmgr:
			continue
		for i in range(dmgr.hand.size() - 1, -1, -1):
			var c = dmgr.hand[i]
			if c.in_hand_heal_tempo > 0:
				c.in_hand_heal_tempo -= 5
				if c.in_hand_heal_tempo <= 0:
					for p in _all_players():
						if is_instance_valid(p) and p.get_stats():
							p.get_stats().heal(c.heal_amount)
					add_battle_log("Healthy Bliss heals all allies for %d!" % c.heal_amount, Color(0.5, 1.0, 0.6))
					print("[MAIN] Healthy Bliss triggered: healed all allies %d" % c.heal_amount)
					dmgr.discard_card_from_hand(c)

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
	var any_outcome_changed = false

	for card in deck_manager.hand:
		if card.has_chance_effect():
			if card.should_reroll_rng(tempo_manager.global_tempo):
				var old_index = card.rng_selected_index
				card.roll_rng(enemies, chance_boost)
				card.rng_roll_tempo = tempo_manager.global_tempo
				if card.rng_selected_index != old_index:
					any_outcome_changed = true

	# A Mage's Favor: reroll outcome changed → add Magic Barrier to hand
	if any_outcome_changed:
		progression_triggers._trigger_skill_tree_jeremy_on_rng_reroll()

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
	_update_draw_label()
	if discard_label:
		discard_label.text = "Discard: %d" % deck_manager.get_discard_pile_size()
	if jail_label:
		jail_label.text = "Jail: %d" % deck_manager.get_jail_pile_size()
	_update_maintained_button()
	_refresh_pile_popup_if_open()

func _update_draw_label() -> void:
	if draw_label:
		var tempo_until = turn_manager.get_tempo_until_draw()
		draw_label.text = "Draw: %d (%d)" % [deck_manager.get_draw_pile_size(), int(tempo_until)]

func _update_attack_button_text() -> void:
	if _attack_button:
		var proc_count = player.get_stats().get_attacks_until_proc()
		var proc_active = deck_manager.next_attack_half_tempo

		if proc_active:
			var proc_tempo = 5 / 2  # Halved
			var btn_inv = player.get_inventory()
			if btn_inv and btn_inv.has_pocket_knife_equipped():
				proc_tempo = maxi(0, proc_tempo - 2)
			_attack_button.text = "Attack (%dT) (PROC)" % proc_tempo
		else:
			_attack_button.text = "Attack (5T) (%d)" % proc_count

		# Glow red when the dex proc is active (next attack benefits from it)
		if proc_active:
			var glow_style = StyleBoxFlat.new()
			glow_style.bg_color = Color(0.6, 0.08, 0.08)
			glow_style.border_color = Color(1.0, 0.2, 0.2)
			glow_style.border_width_top = 2
			glow_style.border_width_bottom = 2
			glow_style.border_width_left = 2
			glow_style.border_width_right = 2
			glow_style.corner_radius_top_left = 4
			glow_style.corner_radius_top_right = 4
			glow_style.corner_radius_bottom_left = 4
			glow_style.corner_radius_bottom_right = 4
			_attack_button.add_theme_stylebox_override("normal", glow_style)
			var glow_hover = StyleBoxFlat.new()
			glow_hover.bg_color = Color(0.75, 0.12, 0.12)
			glow_hover.border_color = Color(1.0, 0.3, 0.3)
			glow_hover.border_width_top = 2
			glow_hover.border_width_bottom = 2
			glow_hover.border_width_left = 2
			glow_hover.border_width_right = 2
			glow_hover.corner_radius_top_left = 4
			glow_hover.corner_radius_top_right = 4
			glow_hover.corner_radius_bottom_left = 4
			glow_hover.corner_radius_bottom_right = 4
			_attack_button.add_theme_stylebox_override("hover", glow_hover)
			_attack_button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
		else:
			# Clear custom styles — revert to default theme
			_attack_button.remove_theme_stylebox_override("normal")
			_attack_button.remove_theme_stylebox_override("hover")
			_attack_button.remove_theme_color_override("font_color")

func update_selected_display() -> void:
	# Selection is now shown via golden border on the card — hide the text label
	if selected_label:
		selected_label.visible = false

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
		update_card_highlights()
		return

	selected_card_index = index
	update_selected_display()
	update_card_highlights()

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
		# Include High Ground bonus if on pillar or elevated terrain
		if card.card_type == Card.CardType.ATTACK and _is_on_high_ground(player.position):
			effective_range += 2
		# Eagle Eye: +2 range on ranged attacks
		var st_stats = player.get_stats()
		if st_stats and st_stats.has_skill_tree_passive("eagle_eye"):
			effective_range += 2
		# Scouted: +6 range on next attack after 3 consecutive hits
		if st_stats and st_stats.st_scouted_bonus_active:
			effective_range += 6
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

func calculate_damage_preview(card: Card, target_enemy: Enemy) -> int:
	## Calculate the estimated damage a card would deal to a target enemy.
	## This mirrors the damage pipeline without side effects (no consuming buffs).
	## Returns 0 for non-damaging cards.
	if card.base_damage <= 0 or card.card_type != Card.CardType.ATTACK:
		return 0
	if not target_enemy or not is_instance_valid(target_enemy) or target_enemy.is_dead:
		return 0

	var player_stats = player.get_stats()
	var buff_mgr = player.get_buff_manager()
	var debuff_mgr = player.get_debuff_manager()
	if not player_stats:
		return 0

	var total_damage = card.base_damage + card.bonus_damage
	var is_ranged_attack = card.is_ranged and card.card_type == Card.CardType.ATTACK

	# On-self bonus damage from slotted item
	var on_self = card.get_on_self_bonus()
	total_damage += on_self["damage"]

	# Ranged damage bonus from equipment (quivers)
	if card.is_ranged and player_stats.ranged_damage_bonus > 0:
		total_damage += player_stats.ranged_damage_bonus

	# Tighten String: +6 damage on ranged attacks
	if buff_mgr and buff_mgr.tighten_string_charges > 0 and is_ranged_attack:
		total_damage += 6

	# High Ground: +4 damage on ranged attacks from elevated position
	if is_ranged_attack and _has_high_ground(player.position, target_enemy):
		total_damage += 4

	# Harnessed Power: +30% damage with 2 or fewer cards in hand
	var hp_mult = progression_triggers._get_jeremy_harnessed_power_multiplier()
	if hp_mult > 1.0:
		total_damage += floori(card.base_damage * (hp_mult - 1.0))

	# Strength scaling (physical damage)
	total_damage = player_stats.get_effective_physical_damage(total_damage)

	# Empower buff
	if player_stats.is_empowered():
		total_damage += player_stats.empower_damage_bonus

	# Strengthen buff (peek, don't consume)
	if buff_mgr:
		total_damage += buff_mgr.get_strengthen_bonus()

	# Cursed debuff: damage reduction
	if debuff_mgr:
		var damage_reduction_pct = debuff_mgr.get_damage_reduction_percent()
		if damage_reduction_pct > 0.0:
			total_damage = max(1, floori(total_damage * (1.0 - damage_reduction_pct)))

	# Enemy-side: Premeditated bonus damage
	total_damage += target_enemy.bonus_damage_next_hit

	# Enemy-side: Armor absorption
	if target_enemy.current_armor > 0:
		# Armor Break: double damage to armor only, no health damage spillover
		if buff_mgr and buff_mgr.has_armor_break():
			var doubled = total_damage * 2
			var armor_absorbed = min(target_enemy.current_armor, doubled)
			# Show the armor damage that will be dealt
			total_damage = armor_absorbed
		else:
			var armor_absorbed = min(target_enemy.current_armor, total_damage)
			total_damage -= armor_absorbed

	return max(0, total_damage)

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

	# Roguelike-only cards (e.g. Infestation) can be collected in the story but
	# only played during a roguelike run.
	var selected = deck_manager.hand[selected_card_index]
	if selected.roguelike_only and not _roguelike_active:
		add_battle_log("%s can only be played in the Roguelike." % selected.card_name, Color(0.7, 0.85, 1.0))
		print("[INPUT] %s is roguelike-only and cannot be played in the story." % selected.card_name)
		return

	# Co-op: playing a card offers the same choice as multi-space movement —
	# play immediately, or lock it in and fire together with the partner's, so
	# one person can set up both characters before anything spends tempo.
	if is_multiplayer and _p2_player and not _card_play_confirmed:
		_show_card_confirm_dialog(deck_manager.hand[selected_card_index], target)
		return

	# Player can always queue cards — they append to the tick queue

	# Hide range indicator when playing a card
	if range_indicator:
		range_indicator.hide_range()

	var card = deck_manager.hand[selected_card_index]
	var tempo_cost = card.tempo_cost
	# Specific Strike: +1 tempo per OTHER card in hand (mana handled in play_card).
	if card.card_id == "specific_strike":
		tempo_cost += max(0, deck_manager.hand.size() - 1)
	var resolve_tick = mini(card.resolve_tick, tempo_cost)  # Clamp resolve_tick to tempo_cost
	var is_ranged_attack = card.is_ranged and card.card_type == Card.CardType.ATTACK

	# Arcane Overflow: -1 tempo on spells when primed (had 0 mana after previous spell)
	var ao_stats = player.get_stats()
	if ao_stats and ao_stats.has_skill_tree_passive("arcane_overflow") and ao_stats.st_arcane_overflow_discount:
		if card.card_type == Card.CardType.UTILITY and card.mana_cost > 0:
			tempo_cost = maxi(0, tempo_cost - 1)
			resolve_tick = mini(resolve_tick, tempo_cost)

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

	# High Ground: +4 damage, +2 range when shooting from elevated position (pillar or terrain elevation)
	var high_ground_applied = false
	if is_ranged_attack and _has_high_ground(player.position, target):
		card.bonus_damage += 4
		card.range_modifier += 2
		high_ground_applied = true
		add_battle_log("High Ground! +4 damage, +2 range", Color(1.0, 0.9, 0.4))
		print("[MAIN] High Ground bonus applied: +4 damage, +2 range")

	# Harnessed Power: +30% effectiveness with 2 or fewer cards in hand
	var harnessed_power_applied = false
	var harnessed_bonus_damage = 0
	var harnessed_bonus_heal = 0
	var harnessed_bonus_block = 0
	var hp_mult = progression_triggers._get_jeremy_harnessed_power_multiplier()
	if hp_mult > 1.0:
		harnessed_power_applied = true
		harnessed_bonus_damage = floori(card.base_damage * (hp_mult - 1.0))
		harnessed_bonus_heal = floori(card.heal_amount * (hp_mult - 1.0))
		harnessed_bonus_block = floori(card.base_block * (hp_mult - 1.0))
		card.bonus_damage += harnessed_bonus_damage
		card.heal_amount += harnessed_bonus_heal
		card.block += harnessed_bonus_block

	# Capture the card UI before playing for animation
	var played_card_ui: CardUI = null
	if selected_card_index >= 0 and selected_card_index < _card_ui_instances.size():
		played_card_ui = _card_ui_instances[selected_card_index]

	# Play card with deferred execution - validates, pays mana, removes from hand, but does NOT execute
	var result = deck_manager.play_card(selected_card_index, target, player, true)

	if result["played"]:
		# Played-card visuals: cards headed to the discard pile were already
		# animated by _animate_card_discard (pop, pause, tube-suck — fired
		# during play_card). Handle the placements that skip the discard pile.
		if played_card_ui and is_instance_valid(played_card_ui) and not played_card_ui._is_animating_out:
			if card in deck_manager.maintained_cards:
				# Maintained powers fly up toward the battlefield instead.
				played_card_ui.animate_play(_get_card_play_target_pos(target))
			# Sticky cards that stay in hand keep their UI; the use counter
			# pops over the rebuilt card below.

		# Trigger character sprite animation based on card type
		_play_card_animation(card, target)

		selected_card_index = -1

		# Log the card play (effect hasn't resolved yet for delayed cards)
		var target_name = ""
		if target is Enemy:
			target_name = " on %s" % target.enemy_name
		if resolve_tick <= 1:
			add_battle_log("Played %s%s" % [card.card_name, target_name], Color(0.4, 1.0, 0.5))
		else:
			add_battle_log("Winding up %s%s (resolves tick %d/%d)" % [card.card_name, target_name, resolve_tick, tempo_cost], Color(1.0, 0.85, 0.4))

		# Store pending resolve data in the queue for when the tick fires
		var resolve_entry := {
			"card": card,
			"target": target,
			"owner_index": _active_index,  # Co-op: which player played it
			"data": {
				"tighten_applied": tighten_applied,
				"high_ground_applied": high_ground_applied,
				"harnessed_power_applied": harnessed_power_applied,
				"harnessed_bonus_damage": harnessed_bonus_damage,
				"harnessed_bonus_heal": harnessed_bonus_heal,
				"harnessed_bonus_block": harnessed_bonus_block,
				"is_ranged_attack": is_ranged_attack,
				"half_tempo": result["half_tempo"],
			},
		}
		_pending_resolve_queue.append(resolve_entry)

		# Dex proc: halve tempo cost and resolve tick (both rounded down)
		if result["half_tempo"]:
			tempo_cost = tempo_cost / 2
			resolve_tick = resolve_tick / 2
			resolve_tick = maxi(resolve_tick, mini(1, tempo_cost))  # At least tick 1 if there's any tempo
			# Pocket Knife: resolve on first tick and -2 additional tempo
			var inv = player.get_inventory()
			if inv and inv.has_pocket_knife_equipped():
				tempo_cost = maxi(0, tempo_cost - 2)
				if tempo_cost > 0:
					resolve_tick = 1
				print("[MAIN] Pocket Knife! Tempo reduced to %d, resolve tick %d" % [tempo_cost, resolve_tick])
			print("[MAIN] Dex proc! Tempo %d, resolve tick %d" % [tempo_cost, resolve_tick])

		# Start ticked tempo — card ticks are appended sequentially
		if tempo_cost <= 0:
			print("[MAIN] No tempo cost — resolving immediately.")
			_resolve_queued_card(card)
		elif buff_mgr and buff_mgr.consume_steady():
			print("[MAIN] Steady! No tempo added.")
			# Resolve immediately since no ticks
			_resolve_queued_card(card)
		else:
			# Initialize the tick bar UI
			_update_tick_bar(0, tempo_cost, resolve_tick, card.card_name)
			tempo_manager.add_card_tempo(tempo_cost, card, resolve_tick, _active_index)

		_on_hand_updated()
		update_deck_info()
		_refresh_unit_tracker()

		# Sticky: the card snapped back into the hand — pop its use counter
		# over the card until the play limit sends it to the discard pile.
		if card.sticky > 0 and card in deck_manager.hand:
			var s_idx: int = deck_manager.hand.find(card)
			if s_idx >= 0 and s_idx < _card_ui_instances.size():
				var s_ui = _card_ui_instances[s_idx]
				if s_ui and is_instance_valid(s_ui):
					s_ui.show_sticky_counter(card.consecutive_uses, card.sticky)
	else:
		# Card didn't play - undo temporary modifications
		if tighten_applied:
			card.bonus_damage -= 6
			card.range_modifier -= 6
		if high_ground_applied:
			card.bonus_damage -= 4
			card.range_modifier -= 2

# ---- Ticked Tempo: Card Resolution Handlers ----

func _on_card_tick_resolved(card: Card) -> void:
	## Called by TempoManager when a card's resolve_tick is reached. In co-op the
	## resolving card may belong to the player NOT currently being controlled, so
	## we bind player/deck_manager to the card's owner for the duration of the
	## resolution, then restore the active context.
	var owner_idx := _owner_index_for_card(card)
	if is_multiplayer and owner_idx >= 0 and owner_idx != _active_index:
		var prev_p := player
		var prev_d := deck_manager
		player = _p1_player if owner_idx == 0 else _p2_player
		deck_manager = _p1_deck_manager if owner_idx == 0 else _p2_deck_manager
		_resolve_queued_card(card)
		player = prev_p
		deck_manager = prev_d
		# Restore the active player's hand/deck readout (resolution refreshed the
		# owner's hand into the shared display).
		_on_hand_updated()
		update_deck_info()
	else:
		_resolve_queued_card(card)

func _owner_index_for_card(card: Card) -> int:
	## Which player (0 = P1, 1 = P2) queued this still-pending card. -1 if unknown.
	for e in _pending_resolve_queue:
		if e["card"] == card:
			return e.get("owner_index", 0)
	return -1

func _switch_active_player() -> void:
	## Co-op: TAB toggles which character you control. Both players' health/mana
	## bars stay visible; the main hand area, deck info and card-play routing
	## follow the active character. Cards already in flight keep resolving on
	## their own owner (see _on_card_tick_resolved).
	# Don't hand control to a downed or iced (Cryonics) partner.
	var target_index := 1 - _active_index
	var target_node: Player = _p2_player if target_index == 1 else _p1_player
	if _downed.get(target_index, false) or (target_node and target_node.untargetable):
		add_battle_log("%s can't be controlled right now." % (player2_character.character_name if target_index == 1 else starting_character.character_name), Color(1.0, 0.5, 0.5))
		return

	selected_card_index = -1
	if range_indicator:
		range_indicator.hide_range()

	# Move the main hand display off the old active deck.
	if deck_manager.hand_updated.is_connected(_on_hand_updated):
		deck_manager.hand_updated.disconnect(_on_hand_updated)

	_active_index = 1 - _active_index
	if _active_index == 0:
		player = _p1_player
		deck_manager = _p1_deck_manager
	else:
		player = _p2_player
		deck_manager = _p2_deck_manager

	# Drive the main hand display from the new active deck.
	if not deck_manager.hand_updated.is_connected(_on_hand_updated):
		deck_manager.hand_updated.connect(_on_hand_updated)

	_on_hand_updated()
	update_deck_info()
	update_selected_display()
	if player2_ui:
		player2_ui.update_control_indicator()
	var who := player2_character.character_name if _active_index == 1 else starting_character.character_name
	add_battle_log("Now controlling %s" % who, Color(1.0, 0.85, 0.4))
	print("[MAIN] Co-op: now controlling player %d (%s)" % [_active_index + 1, who])

func _on_ticking_finished() -> void:
	## Called when all pending ticks are done. Reset the tick bar.
	_reset_tick_bar()
	print("[MAIN] All ticks complete. Player is free.")

func _return_queued_cards_for_dead_target(dead_enemy: Enemy) -> void:
	## When an enemy dies, return all unresolved cards targeting it back to the player's hand.
	var cards_returned := 0
	for i in range(_pending_resolve_queue.size() - 1, -1, -1):
		var entry = _pending_resolve_queue[i]
		if entry["target"] == dead_enemy:
			var card: Card = entry["card"]
			var data: Dictionary = entry["data"]
			_pending_resolve_queue.remove_at(i)
			if _return_dead_target_card(card, data, "%s defeated" % dead_enemy.enemy_name):
				cards_returned += 1

	if cards_returned > 0:
		_on_hand_updated()
		update_deck_info()

func _return_dead_target_card(card: Card, data: Dictionary, context: String) -> bool:
	## Shared handling for a queued card whose target is gone. Basic attacks are
	## temporary so they're simply cancelled; real cards return to hand with their
	## temp mods undone and remaining ticks refunded. Returns true when the card
	## was put back in hand (false for a cancelled basic attack), so callers know
	## whether the hand/deck readout needs refreshing.
	if data.get("is_basic_attack", false):
		var cancelled_basic = tempo_manager.cancel_card_ticks(card)
		add_battle_log("Basic attack cancelled — %s! (%d tempo refunded)" % [context, cancelled_basic], Color(1.0, 0.85, 0.4))
		print("[MAIN] Basic attack cancelled — %s. Refunded %d ticks." % [context, cancelled_basic])
		return false

	# Move from discard pile (where play_card put it) back to hand
	var discard_idx = deck_manager.discard_pile.find(card)
	if discard_idx >= 0:
		deck_manager.discard_pile.remove_at(discard_idx)
	deck_manager.add_card_to_hand(card)

	_undo_card_temp_mods(card, data)
	var cancelled = tempo_manager.cancel_card_ticks(card)

	add_battle_log("%s returned to hand — %s! (%d tempo refunded)" % [card.card_name, context, cancelled], Color(1.0, 0.85, 0.4))
	print("[MAIN] Card '%s' returned to hand — %s. Refunded %d ticks." % [card.card_name, context, cancelled])
	return true

func _undo_card_temp_mods(card: Card, data: Dictionary) -> void:
	## Undo temporary card modifications applied before queuing (tighten, high ground, harnessed).
	if data.get("tighten_applied", false):
		var buff_mgr = player.get_buff_manager()
		if buff_mgr:
			buff_mgr.tighten_string_charges -= 1
		card.bonus_damage -= 6
		card.range_modifier -= 6
	if data.get("high_ground_applied", false):
		card.bonus_damage -= 4
		card.range_modifier -= 2
	if data.get("harnessed_power_applied", false):
		card.bonus_damage -= data["harnessed_bonus_damage"]
		card.heal_amount -= data["harnessed_bonus_heal"]
		card.block -= data["harnessed_bonus_block"]

func _resolve_queued_card(resolved_card: Card) -> void:
	## Find the matching card in the pending queue and execute its effect.
	var queue_index := -1
	for i in range(_pending_resolve_queue.size()):
		if _pending_resolve_queue[i]["card"] == resolved_card:
			queue_index = i
			break
	if queue_index < 0:
		return

	var entry = _pending_resolve_queue[queue_index]
	_pending_resolve_queue.remove_at(queue_index)

	var card: Card = entry["card"]
	var target = entry["target"]
	var data: Dictionary = entry["data"]

	# --- Target died before this card resolved: return card to hand ---
	var target_is_dead := false
	if target != null and not is_instance_valid(target):
		target_is_dead = true
	elif target is Enemy and target.is_dead:
		target_is_dead = true

	if target_is_dead and card.card_type == Card.CardType.ATTACK:
		# Basic attacks are cancelled; real attack cards return to hand. Only a
		# returned card needs the hand/deck readout refreshed.
		if _return_dead_target_card(card, data, "target defeated"):
			_on_hand_updated()
			update_deck_info()
		return

	# --- Basic attack resolution: deal damage directly ---
	if data.get("is_basic_attack", false):
		var damage = data["basic_attack_damage"]
		target.take_damage(damage, true)

		var ba_buff_mgr = player.get_buff_manager()
		var ba_debuff_mgr = player.get_debuff_manager()
		var ba_stats = player.get_stats()

		# Skill tree crit check for basic attack
		if ba_buff_mgr and data.get("basic_attack_crit", false):
			ba_buff_mgr.last_crit_hit = false
			progression_triggers._trigger_skill_tree_on_crit(target)

		# Register attack for DEX proc counter
		# Proc-bonus attacks don't count towards the next cycle
		if ba_stats and not data.get("basic_attack_proc", false):
			ba_stats.register_attack()

		if ba_debuff_mgr:
			ba_debuff_mgr.on_attack()

		var target_name = ""
		if target is Enemy and is_instance_valid(target):
			target_name = target.enemy_name
		add_battle_log("Basic Attack: %d damage to %s" % [damage, target_name], Color(0.4, 1.0, 0.5))
		print("[MAIN] Basic Attack resolved: dealt %d damage to %s" % [damage, target_name])
		return

	# Execute the card's effect (damage, block, heal, etc.)
	deck_manager.execute_deferred_card(card, target, player)

	var debuff_mgr = player.get_debuff_manager()
	var buff_mgr = player.get_buff_manager()

	# Log damage after execution
	var target_name = ""
	if target is Enemy and is_instance_valid(target):
		target_name = " on %s" % target.enemy_name
	if card.last_damage_dealt > 0:
		add_battle_log("%s resolved — %d damage%s" % [card.card_name, card.last_damage_dealt, target_name], Color(0.4, 1.0, 0.5))

	# Sphere grid passive triggers for card play
	progression_triggers._trigger_sphere_passives("on_card_play", {"card": card, "target": target})
	if card.card_type == Card.CardType.ATTACK:
		progression_triggers._trigger_sphere_passives("on_attack", {"card": card, "target": target})
	if card.card_type == Card.CardType.UTILITY and card.mana_cost > 0:
		progression_triggers._trigger_sphere_passives("on_spell_cast", {"card": card, "target": target})

	# Skill tree passive triggers for card play
	progression_triggers._trigger_skill_tree_on_card_play(card, target)
	progression_triggers._trigger_skill_tree_stephen_on_card_play(card)
	progression_triggers._trigger_skill_tree_cory_on_card_play(card)
	progression_triggers._trigger_skill_tree_jeremy_on_card_play(card, target)
	if card.card_type == Card.CardType.ATTACK:
		progression_triggers._trigger_skill_tree_on_attack(card, target)
		var brad_bonus = progression_triggers._trigger_skill_tree_brad_on_attack(card, target)
		var stephen_bonus = progression_triggers._trigger_skill_tree_stephen_on_attack(card, target)
		if (brad_bonus + stephen_bonus) > 0 and target and target.has_method("take_damage"):
			target.take_damage(brad_bonus + stephen_bonus, true)
		if card.is_ranged:
			progression_triggers._trigger_skill_tree_stephen_on_ranged_attack(card, target)
	if card.card_type == Card.CardType.DEFENSE:
		progression_triggers._trigger_skill_tree_brad_on_defense_card_play(card)
	else:
		var pa_stats = player.get_stats()
		if pa_stats:
			pa_stats.st_consecutive_defense = 0

	# Crit-based skill tree passives (Eye Scrape)
	if buff_mgr and buff_mgr.last_crit_hit:
		buff_mgr.last_crit_hit = false
		progression_triggers._trigger_skill_tree_on_crit(target)

	# Apply world effects (knockback, movement, AOE)
	_apply_card_world_effects(card, target)

	# Undo temporary card modifications (tighten, high ground, harnessed power)
	_undo_card_temp_mods(card, data)

	# Enchanted Quiver: create a free arrow card after ranged attacks
	if buff_mgr and buff_mgr.enchanted_quiver_charges > 0 and data.get("is_ranged_attack", false):
		var arrow = Card.create_quick_arrow()
		deck_manager.hand.append(arrow)
		buff_mgr.enchanted_quiver_charges -= 1
		deck_manager.hand_updated.emit()
		print("[MAIN] Enchanted Quiver: Quick Arrow added to hand! (%d charges left)" % buff_mgr.enchanted_quiver_charges)

	# Card-specific post-play effects
	if card.card_id == "shuriken_pouch":
		var shuriken_effect = OverflowEffect.create_manifest_shuriken(3, "Shuriken Pouch")
		overflow_manager.add_overflow_effect(shuriken_effect)

	if card.card_id == "bottomless_quiver":
		var quiver_effect = OverflowEffect.create_quiver(5, "Bottomless Quiver")
		overflow_manager.add_overflow_effect(quiver_effect)
		if quiver_ui:
			quiver_ui.refresh()

	if card.card_id == "reckless_strike":
		for i in range(2):
			var wound = Card.create_minor_wounds()
			deck_manager.discard_pile.append(wound)
		add_battle_log("Reckless Strike: 2 Minor Wounds added to deck!", Color(1.0, 0.5, 0.3))
		print("[MAIN] Reckless Strike: added 2 Minor Wounds to discard pile")

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

	# Track last INSTANT card for Lethal Recall (instant cards mark "Instant" in
	# their description).
	if card.card_id != "lethal_recall" and "Instant" in card.description:
		_last_played_card = card
		_last_played_target = target

	# Lethal Recall: replay last card's effect 2 times
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

	# Glut: apply card lockout
	if card.glut_tempo > 0:
		glut_tempo_remaining = card.glut_tempo
		add_battle_log("Glutted for %d tempo! Cannot play cards." % card.glut_tempo, Color(1.0, 0.4, 0.4))
		print("[MAIN] Glut activated: %d tempo lockout" % card.glut_tempo)
		progression_triggers._trigger_skill_tree_stephen_on_glut(card.glut_tempo)

	# Queue entry already removed above — no further cleanup needed

	_on_hand_updated()
	update_deck_info()
	_refresh_unit_tracker()
	print("[MAIN] Card '%s' fully resolved" % card.card_name)

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
		if card.card_type == Card.CardType.ATTACK and _is_on_high_ground(player.position):
			max_range += 2
		# Eagle Eye: +2 range on ranged attacks
		var st_stats = player.get_stats()
		if st_stats and st_stats.has_skill_tree_passive("eagle_eye"):
			max_range += 2
		# Scouted: +6 range on next attack after 3 consecutive hits
		if st_stats and st_stats.st_scouted_bonus_active:
			max_range += 6
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

func _facing_dir_toward(target) -> CharacterAnimator.Direction:
	## Returns the CharacterAnimator.Direction the player should face to act on target.
	var dir = CharacterAnimator.Direction.SOUTH
	if target and target is Node3D and is_instance_valid(target):
		var to_target = target.position - player.position
		if abs(to_target.x) > abs(to_target.z):
			dir = CharacterAnimator.Direction.EAST if to_target.x > 0 else CharacterAnimator.Direction.WEST
		else:
			dir = CharacterAnimator.Direction.SOUTH if to_target.z > 0 else CharacterAnimator.Direction.NORTH
	return dir

func _play_card_animation(card: Card, target) -> void:
	if not player or not player.has_method("play_animation"):
		return
	# Determine animation direction based on target position
	var dir = _facing_dir_toward(target)
	# Card defines its own animation action (shared with the Animation Lab)
	player.play_animation(card.get_animation_action(), dir)
	# Worms Armageddon: only burst the Alaskan Bull Worm when its 10% summon hits.
	if card.card_id == "worms_armageddon" and card.rng_binary_succeeded() and player.has_method("show_worm_summon"):
		player.show_worm_summon()

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
		"infestation":
			_spawn_infestation_rats(5)

		"spark":
			# Damage is dealt in execute(); here: shift hand tempo now + later.
			_adjust_random_hand_tempo(deck_manager, 2, -2)
			schedule_delayed_effect(15, _spark_delayed.bind(deck_manager), "spark")
			print("[MAIN] Spark: -2 tempo to 2 cards now, +2 to 2 cards in 15 tempo")

		"patience":
			schedule_delayed_effect(15, _patience_delayed.bind(deck_manager), "patience")
			print("[MAIN] Patience: will draw 3 cards in 15 tempo")

		"succumb":
			var caster = player  # owner-bound during resolution
			var bm = caster.get_buff_manager()
			if bm:
				bm.apply_buff(Buff.create_fortify(20, "Succumb"))
				bm.apply_buff(Buff.create_blessed(2, 20, "Succumb"))
				bm.apply_buff(Buff.create_strengthen(5, 5, "Succumb"))
				bm.apply_buff(Buff.create_resilient(20, 20, "Succumb"))
			schedule_delayed_effect(10, _succumb_phase1.bind(caster), "succumb1")
			schedule_delayed_effect(20, _succumb_phase2.bind(caster), "succumb2")
			print("[MAIN] Succumb: buffs now; 10 dmg in 10t; 10 dmg + debuffs in 20t")

		"adrenaline_shot":
			# Target is the ally whose hand is manipulated.
			var tgt_deck = _deck_for_player(target) if target is Player else deck_manager
			_adjust_random_hand_tempo(tgt_deck, 2, -3)
			schedule_delayed_effect(5, _adrenaline_delayed.bind(tgt_deck), "adrenaline")
			print("[MAIN] Adrenaline Shot: -3 tempo to 2 cards now, +tempo in 5 tempo")

		"fireball":
			# AOE circle (4 squares) centred on the target; damage + 3 burn each.
			var center = target.position if target else grid_manager.snap_to_grid(mouse_pos)
			var fb_dmg = card.last_damage_dealt
			var fb_hit = enemy_spawner.get_enemies_in_radius(center, card.aoe_range if card.aoe_range > 0 else 2.0)
			for en in fb_hit:
				en.take_damage(fb_dmg, true)
				en.apply_debuff("burn", 3)
			_apply_misery_spread(fb_hit)
			add_battle_log("Fireball! %d damage + 3 burn to %d enemies" % [fb_dmg, fb_hit.size()], Color(1.0, 0.5, 0.2))
			print("[MAIN] Fireball hit %d enemies for %d (+3 burn)" % [fb_hit.size(), fb_dmg])

		"spirit_arrow":
			# Pierce every enemy along the line from the player through the target.
			var sa_dmg = card.last_damage_dealt
			var aim = target.position if target else grid_manager.snap_to_grid(mouse_pos)
			var sa_dir = Vector3(aim.x - player.position.x, 0, aim.z - player.position.z)
			var sa_far = aim
			if sa_dir.length() > 0.01:
				sa_far = player.position + sa_dir.normalized() * 100.0
			var sa_hit = enemy_spawner.get_enemies_in_line(player.position, sa_far, 0.8)
			for en in sa_hit:
				en.take_damage(sa_dmg, true)
			_apply_misery_spread(sa_hit)
			add_battle_log("Spirit Arrow pierced %d enemies for %d" % [sa_hit.size(), sa_dmg], Color(0.7, 0.9, 1.0))
			print("[MAIN] Spirit Arrow pierced %d enemies for %d" % [sa_hit.size(), sa_dmg])

		"internal_combustion":
			# Shed half your armor; deal that much to everything around you.
			var ic_stats = player.get_stats()
			var ic_amount = 0
			if ic_stats:
				ic_amount = ic_stats.current_armor / 2
				ic_stats.current_armor -= ic_amount
				ic_stats.armor_changed.emit(ic_stats.current_armor)
			var ic_hit = enemy_spawner.get_enemies_in_radius(player.position, 3.0)
			for en in ic_hit:
				en.take_damage(ic_amount, true)
			_apply_misery_spread(ic_hit)
			add_battle_log("Internal Combustion! %d damage to %d enemies" % [ic_amount, ic_hit.size()], Color(1.0, 0.6, 0.2))
			print("[MAIN] Internal Combustion: shed %d armor, hit %d enemies" % [ic_amount, ic_hit.size()])

		"god_of_thunder":
			# Drain all shock from every enemy, then bolt the target for the total.
			var total_shock = 0
			for en in enemy_spawner.get_living_enemies():
				total_shock += en.shock_stacks
				en.shock_stacks = 0
			if target and target.has_method("take_damage") and total_shock > 0:
				target.take_damage(total_shock, true)
			add_battle_log("God of Thunder! Absorbed %d shock, struck for %d" % [total_shock, total_shock], Color(0.8, 0.8, 1.0))
			print("[MAIN] God of Thunder: absorbed %d shock" % total_shock)

		"vines":
			# Hold the target for 3 cycles, dealing base damage at the end of each.
			if target and target.has_method("apply_debuff"):
				target.apply_debuff("stun", 3)
				for cyc in range(1, 4):
					schedule_delayed_effect(cyc * 5, _vines_tick.bind(target, card.base_damage), "vines")
				add_battle_log("Vines! Held the enemy for 3 turns (%d dmg/turn)" % card.base_damage, Color(0.4, 0.8, 0.3))
				print("[MAIN] Vines: held target, %d damage x3 cycles" % card.base_damage)

		"release_tension":
			# Remove one stack of the player-chosen debuff (falls back to the first
			# present DoT) and heal 3 per stack removed.
			var rt_removed = 0
			var rt_field := {"poison": "poison_stacks", "burn": "burn_stacks", "shock": "shock_stacks", "cold": "cold_stacks"}
			if target:
				var order := []
				if card.rt_chosen_debuff != "" and rt_field.has(card.rt_chosen_debuff):
					order = [card.rt_chosen_debuff]
				else:
					order = ["poison", "burn", "shock", "cold"]
				for name in order:
					var prop = rt_field[name]
					var v = target.get(prop)
					if v != null and int(v) > 0:
						target.set(prop, int(v) - 1)
						rt_removed = 1
						break
			var rt_stats = player.get_stats()
			if rt_stats and rt_removed > 0:
				rt_stats.heal(rt_removed * 3)
			add_battle_log("Release Tension! Removed %d debuff, healed %d" % [rt_removed, rt_removed * 3], Color(0.6, 0.9, 0.7))
			print("[MAIN] Release Tension: removed %d %s stack, healed %d" % [rt_removed, card.rt_chosen_debuff, rt_removed * 3])

		"roll":
			# Roll up to min(tempo_cost, 5) tiles toward the aim point, stopping on
			# the first character hit. An enemy takes 10 damage and is disarmed.
			var roll_aim = target.position if target else grid_manager.snap_to_grid(mouse_pos)
			var roll_start = player.position
			var roll_diff = Vector3(roll_aim.x - roll_start.x, 0, roll_aim.z - roll_start.z)
			var roll_dir = roll_diff.normalized() if roll_diff.length() > 0.01 else Vector3.ZERO
			var roll_max = min(card.tempo_cost, 5)
			var roll_final = roll_start
			for step in range(1, roll_max + 1):
				if roll_dir == Vector3.ZERO:
					break
				var np = grid_manager.snap_to_grid(roll_start + roll_dir * (step * grid_manager.grid_size))
				var hit_enemy = enemy_spawner.get_enemy_at_position(np)
				if hit_enemy:
					hit_enemy.take_damage(10, true)
					hit_enemy.apply_debuff("disarmed", 1)
					add_battle_log("Roll into %s! 10 damage + disarm" % hit_enemy.enemy_name, Color(0.9, 0.8, 0.4))
					break
				if is_multiplayer and _p2_player and grid_manager.world_to_grid(_p2_player.position) == grid_manager.world_to_grid(np):
					break  # bumped the partner — stop
				roll_final = np
			player.position = roll_final
			player.target_position = roll_final
			print("[MAIN] Roll: moved to %s (max %d tiles)" % [roll_final, roll_max])

		"misery_loves_company":
			_misery_active = true
			add_battle_log("Misery Loves Company! Your next AOE spreads debuffs.", Color(0.8, 0.5, 0.9))
			print("[MAIN] Misery Loves Company armed.")

		"worms_armageddon":
			# Rain meteors: base_damage to every enemy on the field; 10% Bull Worm VFX.
			var wa_dmg = card.base_damage
			var wa_hit = enemy_spawner.get_living_enemies()
			for en in wa_hit:
				en.take_damage(wa_dmg, true)
			add_battle_log("Worms Armageddon! %d damage to %d enemies" % [wa_dmg, wa_hit.size()], Color(0.6, 0.4, 0.2))
			print("[MAIN] Worms Armageddon hit %d enemies for %d" % [wa_hit.size(), wa_dmg])

		"harness_lightning":
			# Orb: 4 damage every 5 tempo for 30 tempo to a random enemy within 3.
			for tick in range(1, 7):
				schedule_delayed_effect(tick * 5, _harness_lightning_tick, "harness_lightning")
			add_battle_log("Harness Lightning! An orb crackles for 30 tempo.", Color(0.7, 0.8, 1.0))
			print("[MAIN] Harness Lightning orb created.")

		"try_this":
			# Ally +3 mana pool / +2 hand size for 10 tempo (10% backfires, permanent).
			var tt_stats = target.get_stats() if target is Player else player.get_stats()
			if tt_stats:
				if randf() < 0.1:
					tt_stats.max_mana = max(1, tt_stats.max_mana - 3)
					tt_stats.hand_size = max(1, tt_stats.hand_size - 2)
					add_battle_log("Try This backfired! -3 mana pool, -2 hand size", Color(1.0, 0.5, 0.4))
				else:
					tt_stats.max_mana += 3
					tt_stats.hand_size += 2
					schedule_delayed_effect(10, _try_this_revert.bind(tt_stats), "try_this")
					add_battle_log("Try This! +3 mana pool, +2 hand size for 10 tempo", Color(0.6, 1.0, 0.6))

		"item_mastery":
			# Place a copy of every card slotted in your items into your hand.
			var inv = player.get_inventory()
			var added = 0
			if inv and inv.has_method("get_all_slotted_cards"):
				for sc in inv.get_all_slotted_cards():
					var copy = deck_manager._create_card_from_id(sc.card_id)
					if copy:
						deck_manager.add_card_to_hand(copy)
						added += 1
			add_battle_log("Item Mastery! Pulled %d item card(s) into hand." % added, Color(0.8, 0.7, 0.4))
			print("[MAIN] Item Mastery added %d cards to hand." % added)

		"cryonics":
			# Encase an ally in ice: untargetable + cannot act for 15 tempo, healing
			# 3 every 5 tempo.
			var ice_target = target if target is Player else player
			var ice_idx = 1 if ice_target == _p2_player else 0
			ice_target.untargetable = true
			for cyc in range(1, 4):
				schedule_delayed_effect(cyc * 5, _cryonics_heal.bind(ice_target), "cryonics")
			schedule_delayed_effect(15, _cryonics_end.bind(ice_target), "cryonics_end")
			if is_multiplayer and _active_index == ice_idx and not _downed.get(1 - ice_idx, false):
				_switch_active_player()
			add_battle_log("Cryonics! Ally encased in ice (untargetable, +3 HP/5t) for 15 tempo.", Color(0.6, 0.85, 1.0))
			print("[MAIN] Cryonics: iced player %d for 15 tempo" % ice_idx)

		"friendship":
			if is_multiplayer and _p1_player and _p2_player:
				_link_friendship()
				add_battle_log("Friendship! Heals are shared and damage is split.", Color(1.0, 0.8, 0.5))
			else:
				add_battle_log("Friendship needs a partner.", Color(1.0, 0.6, 0.4))
			print("[MAIN] Friendship link: %s" % _friendship_linked)

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
				progression_triggers._trigger_skill_tree_on_displacement()
		"push":
			# Push enemy away by the card's range_modifier (min 1).
			var push_dist = max(1, int(card.range_modifier))
			if target and target.has_method("knockback"):
				target.knockback(player.position, push_dist)
			print("[MAIN] Push: enemy pushed %d spaces away" % push_dist)

		"hold_the_line":
			# All allies gain 5 armor, +2 determination, +2 strength.
			for ally in _all_players():
				var a_st = ally.get_stats() if is_instance_valid(ally) else null
				if a_st:
					a_st.add_armor(5)
					a_st.determination += 2
					a_st.base_strength += 2
					a_st.recalculate_derived_stats()
			add_battle_log("Hold the Line! All allies +5 armor, +2 DET, +2 STR", Color(0.3, 0.7, 1.0))

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
				progression_triggers._trigger_skill_tree_on_displacement()

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
	# Both heroes are down — the defeat overlay takes over.
	if _co_op_defeated:
		return

	# Block game input while donation panel is open
	if _donation_active:
		return

	# Block game input while waypoint menu is open
	if _waypoint_menu_visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			waypoint_mgr._close_waypoint_menu()
		return

	# Block game input while chest modal is open
	if _chest_modal_open:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			chest_loot_ui._close_chest_modal()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# Chest / waypoint / cave / building interaction (Shift key)
		if event.keycode == KEY_SHIFT:
			if _try_climb_tree():
				return
			if _try_interact_site():
				return
			if waypoint_mgr._try_interact_waypoint():
				return
			chest_loot_ui._try_interact_chest()
			return

		# TAB: in co-op, switch which character you control; otherwise quest/map menu.
		if event.keycode == KEY_TAB:
			if is_multiplayer and _p2_player:
				_switch_active_player()
			else:
				minimap_tab_ui._toggle_tab_menu()
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
			if player and player.is_moving:
				player.cancel_movement()
				add_battle_log("Movement stopped.", Color(1.0, 0.85, 0.4))
			selected_card_index = -1
			_pending_quiver_card = null
			_pending_quiver_index = -1
			_pending_quiver_target_type = ""
			if range_indicator:
				range_indicator.hide_range()
			update_selected_display()
			update_card_highlights()
			move_dialog.hide_dialog()
			_hide_card_confirm_dialog()
			if enemy_inspect_ui:
				enemy_inspect_ui.hide_panel()
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
						if card.card_id == "release_tension":
							_show_release_tension_picker(card, enemy)
						else:
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
				if "self" in tt or "ally" in tt:
					# Co-op: clicking the partner targets them (heal/buff an ally);
					# clicking yourself or empty ground defaults to self.
					var tgt_player := _player_at_position(mouse_pos)
					var tgt = tgt_player if tgt_player else player
					if card.card_id == "reposition":
						# Let the player choose which card to discard, then play.
						show_hand_card_picker("Reposition — discard which card?",
							func(chosen):
								card.picked_card = chosen
								play_selected_card(tgt),
							card)
					else:
						play_selected_card(tgt)
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
	
	# Right click - movement (or, mid-move, stop the current movement)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if player.is_moving:
			# Cancel the remainder of the path: the player halts on the next tile
			# (no position revert) and stops spending movement tempo.
			player.cancel_movement()
			add_battle_log("Movement stopped.", Color(1.0, 0.85, 0.4))
		else:
			var mouse_pos = get_mouse_world_position()
			var spaces = grid_manager.get_distance_in_cells(player.position, mouse_pos)

			if spaces == 0:
				print("[INPUT] Already at that location")
			elif is_multiplayer and _p2_player:
				# Co-op: always offer the dialog (even a single step) so the move can
				# be locked in and executed together with the partner's.
				move_dialog.show_dialog(mouse_pos, spaces, true)
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
	dungeon_manager._opened_chests_ref = opened_chests
	add_child(dungeon_manager)
	dungeon_manager.initialize(grid_manager, self, current_world_level, current_interior_id)

	# Move player to dungeon start (or back to the entrance of the interior we just left)
	var start_pos = dungeon_manager.get_player_start_world()
	if return_from_interior_id != "" and current_interior_id == "":
		var site_idx = dungeon_manager.get_site_by_id(return_from_interior_id)
		if site_idx >= 0:
			var entrance: Vector2i = dungeon_manager.site_nodes[site_idx]["grid_pos"]
			start_pos = grid_manager.grid_to_world(entrance)
			start_pos.y = dungeon_manager.get_elevation_world_y(entrance)
			dungeon_manager.reveal_around(entrance)
		return_from_interior_id = ""
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
	waypoint_mgr._restore_discovered_waypoints()

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
	minimap_tab_ui._setup_minimap()

	# Setup tab menu
	minimap_tab_ui._setup_tab_menu()

	# Build ground plane to match world size
	_build_ground_plane()

	# Tune lighting and atmosphere for this world / interior
	_apply_world_ambience()

	print("[MAIN] Dungeon initialized (%s), player at %s" % [get_location_label(), start_pos])

func _sync_dungeon_blocked_tiles() -> void:
	## Combines dungeon walls + barricades + pits for pathfinding. Forest tree
	## trunks additionally block enemies (the player may climb them).
	var tiles: Array[Vector2i] = []
	if dungeon_manager:
		tiles.append_array(dungeon_manager.get_wall_tiles())
		for p in dungeon_manager.pit_tiles.keys():
			tiles.append(p)
	for obs in barricade_obstacles:
		tiles.append(grid_manager.world_to_grid(obs["position"]))
	player.blocked_tiles = tiles
	var enemy_tiles := tiles.duplicate()
	if dungeon_manager:
		for tree in dungeon_manager.tree_nodes:
			enemy_tiles.append(tree["grid_pos"])
	for enemy in enemy_spawner.get_living_enemies():
		enemy.blocked_tiles = enemy_tiles

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

	# Track cells used by already-spawned enemies to avoid stacking
	var used_cells: Array[Vector2i] = []
	for enemy in enemy_spawner.get_living_enemies():
		used_cells.append(grid_manager.world_to_grid(enemy.position))
	# Also include player cell
	used_cells.append(grid_manager.world_to_grid(player.position))

	for i in range(count):
		var cell = spawn_points[i] as Vector2i
		# Validate spawn point is on a floor tile and not already occupied
		cell = _find_valid_spawn_cell(cell, used_cells)
		used_cells.append(cell)
		var world_pos = grid_manager.grid_to_world(cell)
		if dungeon_manager:
			world_pos.y = dungeon_manager.get_elevation_world_y(cell)
		enemy_spawner.spawn_enemy(enemy_types[i], world_pos)

	_sync_dungeon_blocked_tiles()
	_sync_occupied_tiles()
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

func _find_valid_spawn_cell(desired: Vector2i, used_cells: Array[Vector2i]) -> Vector2i:
	## Returns desired cell if it's a walkable floor and not occupied.
	## Otherwise searches nearby cells in expanding rings for a valid alternative.
	if dungeon_manager and dungeon_manager.is_floor(desired) and desired not in used_cells:
		return desired
	# BFS outward to find nearest valid floor tile
	for radius in range(1, 8):
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dz) != radius:
					continue  # Only check the ring perimeter
				var candidate = desired + Vector2i(dx, dz)
				if dungeon_manager and dungeon_manager.is_floor(candidate) and candidate not in used_cells:
					print("[MAIN] Spawn nudged from %s to %s (original was wall/occupied)" % [desired, candidate])
					return candidate
	# Fallback: return desired anyway (shouldn't happen with well-designed maps)
	print("[MAIN] WARNING: Could not find valid spawn near %s!" % desired)
	return desired

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
# ENTERABLE SITES (CAVES & BUILDINGS)
# ============================================

func _try_interact_site() -> bool:
	## Handles Shift near a cave/building entrance (or an interior exit).
	if not dungeon_manager:
		return false
	var player_grid = grid_manager.world_to_grid(player.position)
	var site_idx = dungeon_manager.get_nearby_site(player_grid)
	if site_idx < 0:
		return false
	var site = dungeon_manager.site_nodes[site_idx]
	if site["kind"] == "exit":
		_exit_interior()
	else:
		_enter_interior(site["id"], site["display_name"])
	return true

func _enter_interior(interior_id: String, display_name: String = "") -> void:
	print("[MAIN] Entering %s (%s) in World %d" % [display_name, interior_id, current_world_level])
	var saved_quest_state = quest_manager.save_state() if quest_manager else {}
	var saved_progression = _save_player_progression()
	var main_scene = load("res://scenes/core/main.tscn").instantiate()
	main_scene.starting_character = starting_character
	main_scene.player2_character = player2_character
	main_scene.is_multiplayer = is_multiplayer
	main_scene.current_world_level = current_world_level
	main_scene.current_interior_id = interior_id
	main_scene.discovered_waypoints = discovered_waypoints
	main_scene.quest_state = saved_quest_state
	main_scene.player_progression = saved_progression
	main_scene.opened_chests = opened_chests
	get_tree().root.add_child(main_scene)
	queue_free()

func _exit_interior() -> void:
	print("[MAIN] Leaving %s, returning to World %d" % [current_interior_id, current_world_level])
	var saved_quest_state = quest_manager.save_state() if quest_manager else {}
	var saved_progression = _save_player_progression()
	var main_scene = load("res://scenes/core/main.tscn").instantiate()
	main_scene.starting_character = starting_character
	main_scene.player2_character = player2_character
	main_scene.is_multiplayer = is_multiplayer
	main_scene.current_world_level = current_world_level
	main_scene.return_from_interior_id = current_interior_id
	main_scene.discovered_waypoints = discovered_waypoints
	main_scene.quest_state = saved_quest_state
	main_scene.player_progression = saved_progression
	main_scene.opened_chests = opened_chests
	get_tree().root.add_child(main_scene)
	queue_free()

func get_location_label() -> String:
	## Human-readable current location, e.g. "World 2" or "World 2 — Cave 1".
	if not dungeon_manager:
		return "World %d" % current_world_level
	if current_interior_id == "":
		return "World %d" % current_world_level
	return "World %d — %s" % [current_world_level, dungeon_manager.get_location_name()]

func _desired_ground_y(world_pos: Vector3) -> float:
	## The Y a unit standing at world_pos should rest at (pillar, tree, or terrain).
	## Player and enemies glide toward this each frame for smooth climbs.
	if is_on_pillar(world_pos):
		return 2.0
	if _is_climbed_tree(world_pos):
		return TREE_CANOPY_Y
	if dungeon_manager and grid_manager:
		return dungeon_manager.get_elevation_world_y(grid_manager.world_to_grid(world_pos))
	return 0.0

func _apply_world_ambience() -> void:
	## Adjusts environment lighting, fog, and sun per world palette so each
	## world (and cave/building interior) has its own atmosphere.
	if not dungeon_manager:
		return
	var pal: Dictionary = dungeon_manager.get_palette()
	var in_cave = current_interior_id.begins_with("cave")
	var in_building = current_interior_id.begins_with("building")
	var in_sewer = current_interior_id.begins_with("sewer")
	var in_forest = current_interior_id.begins_with("forest")

	var world_env = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env and world_env.environment:
		var env = world_env.environment
		env.ambient_light_color = pal.get("ambient", Color(0.3, 0.3, 0.35))
		if in_cave:
			env.ambient_light_energy = 0.14  # darker even than the sewers
		elif in_sewer:
			env.ambient_light_energy = 0.20  # near-lightless; torches do the work
		elif in_forest:
			env.ambient_light_energy = 0.70  # bright, sun-dappled woodland
		else:
			env.ambient_light_energy = 0.55
		env.fog_enabled = true
		env.fog_light_color = pal.get("ambient", Color(0.2, 0.2, 0.25)).darkened(0.55)
		if in_cave:
			env.fog_density = 0.045  # heavy underground gloom
		elif in_sewer:
			env.fog_density = 0.035  # thick, dank haze that swallows the far walls
		elif in_building:
			env.fog_density = 0.012
		elif in_forest:
			env.fog_density = 0.004  # clear, open air
		else:
			env.fog_density = 0.006
		env.ssao_enabled = true
		env.ssao_intensity = 1.6

	var sun = get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun:
		sun.light_color = pal.get("sun", Color(1, 0.95, 0.9))
		var energy: float = pal.get("sun_energy", 1.2)
		if in_cave:
			energy = 0.16
		elif in_sewer:
			energy = 0.22
		elif in_building:
			energy = 0.8
		elif in_forest:
			energy = pal.get("sun_energy", 1.35)  # full dappled daylight
		sun.light_energy = energy

	# Underground (sewers and caves), each player carries their own pool of light.
	_ensure_player_torch(in_sewer or in_cave)

func _ensure_player_torch(enable: bool) -> void:
	## Gives each player a warm point light (the "lit circle" around the
	## character) while underground in the sewers; removes it elsewhere.
	for p in _all_players():
		if p == null or not is_instance_valid(p):
			continue
		var existing = p.get_node_or_null("PlayerTorch")
		if enable:
			if existing == null:
				var torch = OmniLight3D.new()
				torch.name = "PlayerTorch"
				torch.light_color = Color(1.0, 0.86, 0.62)
				torch.light_energy = 2.8
				torch.omni_range = 9.0
				torch.omni_attenuation = 1.1
				torch.shadow_enabled = false
				torch.position = Vector3(0, 1.2, 0)
				p.add_child(torch)
		elif existing:
			existing.queue_free()


# ============================================
# CHEST LOOT MODAL
# ============================================


# Chest interaction and loot modal moved to
# scripts/ui/chest_loot_ui.gd

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

func _on_spawn_fire_goblins() -> void:
	enemy_spawner.spawn_fire_goblin_pack()
	_sync_blocked_tiles()
	_sync_occupied_tiles()
	_sync_pillar_tiles()
	_update_enemy_count()
	_refresh_unit_tracker()
	print("[MAIN] Spawned fire goblin pack!")

func _on_spawn_elite() -> void:
	var used_cells: Array[Vector2i] = []
	for enemy in enemy_spawner.get_living_enemies():
		used_cells.append(grid_manager.world_to_grid(enemy.position))
	used_cells.append(grid_manager.world_to_grid(player.position))
	var desired = Vector2i(randi_range(9, 16), randi_range(2, 8))
	var cell = _find_valid_spawn_cell(desired, used_cells)
	var world_pos = grid_manager.grid_to_world(cell)
	if dungeon_manager:
		world_pos.y = dungeon_manager.get_elevation_world_y(cell)
	enemy_spawner.spawn_enemy(Enemy.EnemyType.ELITE, world_pos)
	_sync_blocked_tiles()
	_sync_occupied_tiles()
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
# INFESTATION RATS (roguelike summon)
# ============================================

func _spawn_infestation_rats(count: int) -> void:
	if not grid_manager:
		return
	var player_cell = grid_manager.world_to_grid(player.position)
	var blocked = player.blocked_tiles
	var enemy_cells = _living_enemy_cells()
	# Candidate tiles spiral outward from the player.
	var offsets = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
		Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2),
	]
	var used: Array = []
	var spawned = 0
	for off in offsets:
		if spawned >= count:
			break
		var cell = player_cell + off
		if cell == player_cell or cell in blocked or cell in enemy_cells or cell in used:
			continue
		used.append(cell)
		_create_infestation_rat(cell)
		spawned += 1
	# Fallback: if the player is boxed in, the remaining rats pile onto the
	# player's tile and spread out as they move.
	while spawned < count:
		_create_infestation_rat(player_cell)
		spawned += 1
	add_battle_log("Infestation! %d rats scurry out." % spawned, Color(0.7, 0.7, 0.6))

func _create_infestation_rat(cell: Vector2i) -> void:
	var rat = SummonedRat.new()
	add_child(rat)
	rat.setup(grid_manager, grid_manager.grid_to_world(cell))
	rat.died.connect(_on_summoned_rat_died)
	_summoned_rats.append(rat)

func _on_summoned_rat_died(rat) -> void:
	_summoned_rats.erase(rat)

func _clear_summoned_rats() -> void:
	for rat in _summoned_rats:
		if is_instance_valid(rat):
			rat.queue_free()
	_summoned_rats.clear()

func _living_enemy_cells() -> Array:
	var cells: Array = []
	if not grid_manager or not enemy_spawner:
		return cells
	for e in enemy_spawner.get_living_enemies():
		cells.append(grid_manager.world_to_grid(e.position))
	return cells

func _nearest_enemy_to(pos: Vector3, enemies: Array) -> Enemy:
	var nearest: Enemy = null
	var nearest_dist := INF
	for e in enemies:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var d = pos.distance_to(e.position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	return nearest

func _rat_step_toward(cell: Vector2i, target: Vector2i, blocked: Array, enemy_cells: Array, rat_cells: Array) -> Vector2i:
	var player_cell = grid_manager.world_to_grid(player.position)
	var best = cell
	var best_dist = _manhattan(cell, target)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var cand = cell + d
		if cand == target or cand == player_cell:
			continue
		if cand in blocked or cand in enemy_cells or cand in rat_cells:
			continue
		var dist = _manhattan(cand, target)
		if dist < best_dist:
			best_dist = dist
			best = cand
	return best

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _update_summoned_rats() -> void:
	if _summoned_rats.is_empty():
		return
	# Drop any freed/dead rats.
	_summoned_rats = _summoned_rats.filter(func(r): return is_instance_valid(r) and not r.is_dead)
	if not grid_manager or not enemy_spawner:
		return

	var enemies = enemy_spawner.get_living_enemies()
	var blocked = player.blocked_tiles

	# Phase 1: enemies adjacent to a rat swat it (rats only have 3 HP, so a
	# strong foe can kill one before it ever connects). Iterate a snapshot since
	# take_damage can free a rat mid-loop.
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var ecell = grid_manager.world_to_grid(enemy.position)
		for rat in _summoned_rats.duplicate():
			if not is_instance_valid(rat) or rat.is_dead:
				continue
			if _manhattan(rat.get_cell(), ecell) == 1:
				rat.take_damage(enemy.attack_damage)
				break  # one swat per enemy per tempo

	# Phase 2: surviving rats lunge if in contact, otherwise scurry one square
	# toward the nearest enemy.
	var rat_cells: Array = []
	for rat in _summoned_rats:
		if is_instance_valid(rat) and not rat.is_dead:
			rat_cells.append(rat.get_cell())

	for rat in _summoned_rats.duplicate():
		if not is_instance_valid(rat) or rat.is_dead:
			continue
		var target_enemy = _nearest_enemy_to(rat.position, enemies)
		if target_enemy == null:
			continue
		var rcell = rat.get_cell()
		var tcell = grid_manager.world_to_grid(target_enemy.position)
		if _manhattan(rcell, tcell) <= 1:
			# Contact! The rat lunges, dealing its damage and dying.
			target_enemy.take_damage(SummonedRat.CONTACT_DAMAGE, true)
			add_battle_log("A rat lunges for %d damage!" % SummonedRat.CONTACT_DAMAGE, Color(0.7, 0.7, 0.6))
			rat_cells.erase(rcell)
			rat.die()
			continue
		var next_cell = _rat_step_toward(rcell, tcell, blocked, _living_enemy_cells(), rat_cells)
		if next_cell != rcell:
			rat_cells.erase(rcell)
			rat_cells.append(next_cell)
			rat.move_to_cell(next_cell)

	# Clear out any rats that died this tick.
	_summoned_rats = _summoned_rats.filter(func(r): return is_instance_valid(r) and not r.is_dead)

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

func _sync_occupied_tiles() -> void:
	## Tells each enemy where every OTHER enemy currently stands so they don't stack.
	var living = enemy_spawner.get_living_enemies()
	var all_cells: Array[Vector2i] = []
	for enemy in living:
		all_cells.append(grid_manager.world_to_grid(enemy.position))
	for i in range(living.size()):
		var other_cells: Array[Vector2i] = []
		for j in range(all_cells.size()):
			if j != i:
				other_cells.append(all_cells[j])
		living[i].occupied_tiles = other_cells

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

func _is_on_high_ground(world_pos: Vector3) -> bool:
	## Returns true if the position is elevated (pillar, climbed tree, or terrain).
	if is_on_pillar(world_pos):
		return true
	if _is_climbed_tree(world_pos):
		return true
	if dungeon_manager:
		var grid_pos = grid_manager.world_to_grid(world_pos)
		return dungeon_manager.get_elevation(grid_pos) > 0
	return false

func _has_high_ground(attacker_pos: Vector3, target) -> bool:
	## Returns true if attacker is at higher elevation than target.
	# Flying enemies (e.g. Giant Hawk) are never below the player's high ground.
	if target and is_instance_valid(target) and "immune_to_high_ground" in target and target.immune_to_high_ground:
		return false
	if is_on_pillar(attacker_pos):
		return true
	if _is_climbed_tree(attacker_pos):
		return true
	if dungeon_manager and target and is_instance_valid(target):
		var attacker_grid = grid_manager.world_to_grid(attacker_pos)
		var target_grid = grid_manager.world_to_grid(target.position)
		return dungeon_manager.get_elevation(attacker_grid) > dungeon_manager.get_elevation(target_grid)
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
	# Cover: an ally taking damage (self in solo) fires its mitigation reaction.
	var cover_reactions = deck_manager.trigger_reactions("on_ally_damage_taken")
	for card in cover_reactions:
		card.execute(null, player.get_stats(), deck_manager, 0.0, 0.0, player.get_buff_manager())
	if triggered.size() > 0 or cover_reactions.size() > 0:
		_refresh_unit_tracker()

	var stats = player.get_stats()
	var non_fatal: bool = stats != null and stats.current_health > 0
	if not non_fatal:
		return

	# Growth Within Resilience (maintained Power): non-fatal damage adds a
	# single-use Hydra Bite to your hand.
	for mcard in deck_manager.get_maintained_cards():
		if mcard.card_id == "growth_within_resilience":
			deck_manager.add_card_to_hand(Card.create_hydra_bite())
			add_battle_log("Growth Within Resilience: a Hydra Bite surges into your hand!", Color(0.5, 0.85, 0.4))
			break

	# Hydra Heart relic (roguelike runs only): gain 1 strength when you take
	# damage. (The "own turn" condition is approximated as any damage taken
	# during the run until per-source turn tracking exists.)
	if _roguelike_relics.has("hydra_heart"):
		stats.base_strength += 1
		add_battle_log("Hydra Heart: +1 strength!", Color(0.9, 0.4, 0.5))
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
	# Disintegrate the card's UI in place BEFORE the hand rebuild frees it.
	_animate_card_erase(card)
	add_battle_log("%s erased from deck!" % card.card_name, Color(0.7, 0.7, 0.7))
	update_deck_info()
	_on_hand_updated()

func _on_shepherds_mark_triggered() -> void:
	add_battle_log("Shepherd's Mark: Lethal damage prevented! 1 HP + 10 armor!", Color(0.3, 0.7, 1.0))
	# Jeremy takes 8 damage as the cost of the mark triggering
	var stats = player.get_stats()
	if stats:
		stats.take_direct_damage(8)
		add_battle_log("Whispers of the Flock: Jeremy takes 8 damage!", Color(0.9, 0.3, 0.3))

# ============================================
# LOOT DROP SYSTEM
# ============================================

func _on_loot_dropped(loot: Dictionary, pos: Vector3) -> void:
	## Enemies drop their loot ON THE GROUND: a glinting pile appears on the
	## tile where they died, and whoever walks onto it scoops it up. Looting is
	## TEMPO-FREE — nothing in the pickup path adds tempo; only the walk to
	## reach the pile costs the usual movement tempo.
	_spawn_loot_drop(loot, pos)

func _spawn_loot_drop(loot: Dictionary, pos: Vector3) -> void:
	var has_any: bool = int(loot.get("gold", 0)) > 0 \
		or loot.get("item") != null or loot.get("card") != null \
		or int(loot.get("culling_stones", 0)) > 0
	if not has_any:
		return
	var cell: Vector2i = grid_manager.world_to_grid(pos)
	var world: Vector3 = grid_manager.grid_to_world(cell)
	world.y = pos.y
	var drop := Node3D.new()
	drop.name = "LootDrop"
	drop.position = world
	add_child(drop)
	_build_loot_visual(drop, loot)
	_loot_drops.append({"node": drop, "cell": cell, "loot": loot})
	# If someone is already standing on that tile (a pass-through kill or a
	# melee finish on their own cell), scoop it up immediately.
	_check_loot_pickup()

func _build_loot_visual(drop: Node3D, loot: Dictionary) -> void:
	## A dropped sack with the contents peeking out, under a pulsing glint so
	## it reads as lootable from the battle camera.
	var sack := _loot_mesh(drop, _mesh_sphere(0.13), Vector3(0, 0.09, 0), Color(0.45, 0.33, 0.2))
	sack.scale = Vector3(1.0, 0.75, 1.0)
	_loot_mesh(drop, _mesh_box(Vector3(0.05, 0.04, 0.05)), Vector3(0.02, 0.19, 0), Color(0.35, 0.25, 0.15))  # tied neck
	if int(loot.get("gold", 0)) > 0:
		for i in range(3):
			var coin := _loot_mesh(drop, _mesh_cyl(0.035, 0.012), Vector3(-0.12 + i * 0.05, 0.015, 0.12 + (i % 2) * 0.04), Color(0.92, 0.78, 0.28), true)
			coin.rotation_degrees = Vector3(8 * i, 30 * i, 0)
	var item: ItemData = loot.get("item")
	if item:
		_loot_mesh(drop, _mesh_box(Vector3(0.1, 0.08, 0.06)), Vector3(0.13, 0.05, -0.04), Color(0.62, 0.66, 0.72))  # gear glinting out of the sack
	var card: Card = loot.get("card")
	if card:
		var c := _loot_mesh(drop, _mesh_box(Vector3(0.11, 0.15, 0.012)), Vector3(-0.13, 0.1, -0.05), Color(0.92, 0.9, 0.84), true)
		c.rotation_degrees = Vector3(-14, 24, 0)
	if int(loot.get("culling_stones", 0)) > 0:
		_loot_mesh(drop, _mesh_sphere(0.05), Vector3(0.0, 0.05, -0.13), Color(0.55, 0.3, 0.75), true)
	# Pulsing glint above the pile + a gentle bob, looping until picked up.
	var glint := _loot_mesh(drop, _mesh_sphere(0.035), Vector3(0, 0.32, 0), Color(1.0, 0.95, 0.6), true)
	var tw := drop.create_tween().set_loops()
	tw.tween_property(glint, "scale", Vector3.ONE * 1.6, 0.5).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(drop, "position:y", drop.position.y + 0.04, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(glint, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(drop, "position:y", drop.position.y, 0.5).set_trans(Tween.TRANS_SINE)
	drop.set_meta("bob_tween", tw)

func _loot_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, emissive := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.8
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _mesh_sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s

func _mesh_box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _mesh_cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	return c

func _check_loot_pickup() -> void:
	## Any player standing on a loot pile's tile scoops it up. Tempo-free by
	## design: there is deliberately no add_tempo anywhere in this path.
	if _loot_drops.is_empty():
		return
	for p in _all_players():
		if not is_instance_valid(p):
			continue
		var pcell: Vector2i = grid_manager.world_to_grid(p.position)
		var i := 0
		while i < _loot_drops.size():
			var entry: Dictionary = _loot_drops[i]
			if entry["cell"] == pcell:
				_loot_drops.remove_at(i)
				_collect_loot(entry["loot"], p)
				_pop_loot_drop(entry["node"])
			else:
				i += 1

func _pop_loot_drop(node: Node3D) -> void:
	## Little pickup flourish: the pile hops up, shrinks and vanishes.
	if not is_instance_valid(node):
		return
	# Stop the idle bob so it doesn't fight the pickup pop.
	var bob = node.get_meta("bob_tween") if node.has_meta("bob_tween") else null
	if bob is Tween and bob.is_valid():
		bob.kill()
	var tw := create_tween().set_trans(Tween.TRANS_QUAD)
	tw.tween_property(node, "position:y", node.position.y + 0.5, 0.18).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(node, "scale", Vector3.ZERO, 0.18).set_ease(Tween.EASE_IN)
	tw.tween_callback(node.queue_free)

func _clear_loot_drops() -> void:
	for entry in _loot_drops:
		if is_instance_valid(entry["node"]):
			entry["node"].queue_free()
	_loot_drops.clear()

func _collect_loot(loot: Dictionary, looter: Player) -> void:
	## Apply a loot bundle to the player who picked it up.
	var messages: Array[String] = []

	# Gold
	var gold = loot.get("gold", 0)
	if gold > 0:
		looter.get_stats().gain_gold(gold)
		messages.append("+%d Gold" % gold)

	# Culling stones
	var culling_stones = loot.get("culling_stones", 0)
	if culling_stones > 0:
		var inventory = looter.get_inventory()
		if inventory:
			inventory.culling_stones += culling_stones
			messages.append("+%d Culling Stone" % culling_stones)

	# Item drop
	var item: ItemData = loot.get("item")
	if item:
		var inventory = looter.get_inventory()
		if inventory:
			if inventory.store_item(item):
				messages.append("Item: %s" % item.item_name)
			else:
				messages.append("Item dropped (inventory full): %s" % item.item_name)

	# Card drop - goes to INVENTORY, not deck
	var card: Card = loot.get("card")
	if card:
		var inventory = looter.get_inventory()
		if inventory:
			if inventory.store_card(card):
				messages.append("Card: %s (inventory)" % card.card_name)
			else:
				messages.append("Card dropped (inventory full): %s" % card.card_name)
		# Infestation is a roguelike-only reward. Unlock it for this character's
		# runs and let Olorin appear to explain how roguelike rewards work.
		if card.card_id == "infestation":
			if current_character and not current_character.purchased_card_ids.has("infestation"):
				current_character.purchased_card_ids.append("infestation")
			if olorin:
				olorin.show_infestation_intro()

	if messages.size() > 0:
		var loot_text = "Looted: " + ", ".join(messages)
		add_battle_log(loot_text, Color(1.0, 0.85, 0.2))
		print("[MAIN] %s" % loot_text)

# ============================================
# WAYPOINT TRAVEL
# ============================================


# Waypoint discovery, menu, and teleportation moved to
# scripts/core/waypoint_manager.gd

func _restore_player_progression(progression: Dictionary) -> void:
	## Restore persistent player state after a world transition.
	var stats = player.get_stats()

	# Restore stats (level, XP, base stats, sphere bonuses, skill tree passives)
	if stats and progression.has("stats"):
		stats.restore_progression(progression["stats"])

	# Restore skill tree with all previous choices intact
	if progression.has("skill_tree") and progression["skill_tree"] != null:
		skill_tree_ui.set_skill_tree(progression["skill_tree"])
		skill_tree_ui.set_player_level(stats.current_level if stats else 1)

	# Restore sphere grid with all unlocked nodes intact
	if progression.has("sphere_grid") and progression["sphere_grid"] != null:
		sphere_grid_ui.sphere_grid = progression["sphere_grid"]

	# Restore sphere inventory counts
	if progression.has("sphere_inventory"):
		var inv_data = progression["sphere_inventory"]
		sphere_inventory.spheres = inv_data.get("spheres", sphere_inventory.spheres)
		sphere_inventory.retrospective_tokens = inv_data.get("retrospective_tokens", 0)

	# Restore deck state (preserves hand, draw, discard piles exactly)
	if progression.has("deck_state") and not progression["deck_state"].is_empty():
		deck_manager.restore_deck_state(progression["deck_state"])
		_on_hand_updated()
		update_deck_info()

	# Restore equipped and stored items
	if progression.has("inventory"):
		var inv = player.get_inventory()
		var inv_data = progression["inventory"]
		if inv:
			inv.equipped_helms = inv_data.get("equipped_helms", inv.equipped_helms)
			inv.equipped_chests = inv_data.get("equipped_chests", inv.equipped_chests)
			inv.equipped_rings = inv_data.get("equipped_rings", inv.equipped_rings)
			inv.equipped_belts = inv_data.get("equipped_belts", inv.equipped_belts)
			inv.equipped_boots = inv_data.get("equipped_boots", inv.equipped_boots)
			inv.equipped_gauntlets = inv_data.get("equipped_gauntlets", inv.equipped_gauntlets)
			inv.equipped_weapons = inv_data.get("equipped_weapons", inv.equipped_weapons)
			inv.equipped_quivers = inv_data.get("equipped_quivers", inv.equipped_quivers)
			inv.stored_items = inv_data.get("stored_items", inv.stored_items)
			inv.stored_cards = inv_data.get("stored_cards", inv.stored_cards)
			inv.stash_items = inv_data.get("stash_items", inv.stash_items)
			inv.culling_stones = inv_data.get("culling_stones", inv.culling_stones)
			inv.equipment_changed.emit()

	# Update UI displays
	_on_player_health_changed(stats.current_health, stats.max_health)
	_on_player_mana_changed(stats.current_mana, stats.max_mana)
	_update_xp_display()
	print("[MAIN] Player progression restored: Level %d, World %d" % [stats.current_level, current_world_level])

func _save_player_progression() -> Dictionary:
	## Capture all persistent player state before a world transition.
	var stats = player.get_stats()
	var progression := {}
	if stats:
		progression["stats"] = stats.save_progression()
	# Skill tree with all chosen options (RefCounted — survives scene change)
	progression["skill_tree"] = skill_tree_ui.skill_tree
	# Sphere grid with all unlocked nodes (Resource — survives scene change)
	progression["sphere_grid"] = sphere_grid_ui.sphere_grid
	# Sphere inventory counts (Node gets destroyed, so snapshot the data)
	var sphere_inv: SphereInventory = sphere_inventory
	progression["sphere_inventory"] = {
		"spheres": sphere_inv.spheres.duplicate(),
		"retrospective_tokens": sphere_inv.retrospective_tokens,
	}
	# Deck state (each pile saved separately to preserve hand exactly)
	progression["deck_state"] = deck_manager.save_deck_state()
	# Equipped items and stored items (Resource objects survive scene change)
	var inv = player.get_inventory()
	if inv:
		progression["inventory"] = {
			"equipped_helms": inv.equipped_helms.duplicate(),
			"equipped_chests": inv.equipped_chests.duplicate(),
			"equipped_rings": inv.equipped_rings.duplicate(),
			"equipped_belts": inv.equipped_belts.duplicate(),
			"equipped_boots": inv.equipped_boots.duplicate(),
			"equipped_gauntlets": inv.equipped_gauntlets.duplicate(),
			"equipped_weapons": inv.equipped_weapons.duplicate(),
			"equipped_quivers": inv.equipped_quivers.duplicate(),
			"stored_items": inv.stored_items.duplicate(),
			"stored_cards": inv.stored_cards.duplicate(),
			"stash_items": inv.stash_items.duplicate(),
			"culling_stones": inv.culling_stones,
		}
	var deck_state = progression["deck_state"]
	var total_cards = deck_state.get("hand", []).size() + deck_state.get("draw_pile", []).size() + deck_state.get("discard_pile", []).size() + deck_state.get("jail_pile", []).size()
	print("[MAIN] Saved player progression: Level %d, %d passives, %d cards" % [
		stats.current_level if stats else 0,
		stats.skill_tree_passives.size() if stats else 0,
		total_cards,
	])
	return progression

func _travel_to_town() -> void:
	print("[MAIN] Traveling to town!")
	var saved_quest_state = quest_manager.save_state() if quest_manager else {}
	var saved_progression = _save_player_progression()
	var town_scene = load("res://scenes/menus/town.tscn").instantiate()
	town_scene.starting_character = starting_character
	if "player2_character" in town_scene:
		town_scene.player2_character = player2_character
	if "return_world_level" in town_scene:
		town_scene.return_world_level = current_world_level
	if "discovered_waypoints" in town_scene:
		town_scene.discovered_waypoints = discovered_waypoints
	if "quest_state" in town_scene:
		town_scene.quest_state = saved_quest_state
	if "player_progression" in town_scene:
		town_scene.player_progression = saved_progression
	if "opened_chests" in town_scene:
		town_scene.opened_chests = opened_chests
	get_tree().root.add_child(town_scene)
	queue_free()

func _travel_to_world(level: int) -> void:
	print("[MAIN] Traveling to World %d!" % level)
	var saved_quest_state = quest_manager.save_state() if quest_manager else {}
	var saved_progression = _save_player_progression()
	var main_scene = load("res://scenes/core/main.tscn").instantiate()
	main_scene.starting_character = starting_character
	main_scene.player2_character = player2_character
	main_scene.is_multiplayer = is_multiplayer
	main_scene.current_world_level = level
	main_scene.discovered_waypoints = discovered_waypoints
	main_scene.quest_state = saved_quest_state
	main_scene.player_progression = saved_progression
	main_scene.opened_chests = opened_chests
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
	plane_mesh.size = Vector2(dungeon_manager.GRID_W + 40, dungeon_manager.GRID_H + 40)
	ground.mesh = plane_mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = dungeon_manager.get_palette().get("ground", Color(0.15, 0.12, 0.1))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 1.0
	ground.material_override = mat
	ground.position = Vector3(dungeon_manager.GRID_W / 2.0, -0.12, dungeon_manager.GRID_H / 2.0)
	add_child(ground)

# ============================================
# MINIMAP
# ============================================


# Minimap, tab menu, quest log, and expanded map moved to
# scripts/ui/minimap_tab_ui.gd
