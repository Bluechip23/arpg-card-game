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
var _draw_pile_btn: Button = null       # left draw pile button (for its tooltip)
var _hand_info_btn: Button = null       # small ⓘ button beside the hand icon
var _hand_info_popup: PanelContainer = null  # hand size / overflow info popup
var _hand_info_vbox: VBoxContainer = null    # popup content (rebuilt on refresh)
var _discard_pile_btn: Button = null    # right discard pile button (for its tooltip)
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
var enemy_inspect_ui = null          # EnemyInspectUI (preloaded; untyped to avoid class-cache dependency)
var quest_manager: QuestManager = null
var progression_triggers: ProgressionTriggers = null
var chest_loot_ui: ChestLootUI = null
var olorin: OlorinTutorial = null
var waypoint_mgr: WaypointManager = null
# First-room tutorial: the first rat of the story drops the Bladed Doughnut,
# Olorin explains item levels, and once the player walks off with it he gets
# hungry and takes it back.
var _pending_doughnut_drop: bool = false
var _doughnut_farewell_armed: bool = false
# Act-mythic pity layer: a mythic rolled on this kill (DropRates), waiting to
# be injected into the enemy's loot pile.
var _pending_mythic_item: ItemData = null
var _doughnut_item: ItemData = null
var _doughnut_looter: Player = null
var _doughnut_pickup_cell: Vector2i = Vector2i(-999, -999)
var _summoned_worms: Array = []  # Worm's Armageddon: Alaskan Bull Worm allies
const SummonedWormScript = preload("res://scripts/battle/summoned_worm.gd")
var _frankensteins: Array = []   # ITS ALIVE!!!!!: Frankensteins Monster allies
var _corpses: Array = []         # {cell: Vector2i, position: Vector3} left by dead enemies, for resurrection
var _fire_spots: Array = []      # Elemental Trail Blazers: {cell, tempo, damage, node}
var _bullet_casings: Array = []  # Chewbaccas Bandolier: {cell, tempo, damage, node}
var _berry_bushels: Array = []   # Crops (Shepherds Crook): {cell, node} — last until an ally eats them
var _purge_cycle_accum: int = 0  # Horned Nasal Helm: cycles banked toward the next auto-purge
var _wolves: Array = []          # Gauntlets of Dungeon Mastering: summoned wolves
var _penguin = null              # Nine Ruins of Sanguine: the blood penguin (one at a time)
const PenguinScript = preload("res://scripts/battle/sanguine_penguin.gd")
const WolfScript = preload("res://scripts/battle/summoned_wolf.gd")
var _smoke_zones: Array = []     # smoke bomb: {position, tempo}
var _skeletons: Array = []       # Sack of Bone Arrows: raised skeletons (cap 3)
const SkeletonScript = preload("res://scripts/battle/summoned_skeleton.gd")
var _spirit_bows: Array = []     # Bow of Budding Blasts: maintained spirit bow + budded turrets
const SpiritBowScript = preload("res://scripts/battle/spirit_bow_summon.gd")
var _mark_zones: Array = []      # Territorial Mark: {cells: Array[Vector2i], tempo, nodes}
var _clones: Array = []          # Draupnir: duplicates of the bearer (live until killed — no battle-end cleanup)
const CloneScript = preload("res://scripts/battle/summoned_clone.gd")
var _wraiths: Array = []         # The Precious: the hostile hunters, on the field only during shadow form
var _draupnir_spawn_frame: int = -1  # frame of the last clone spawn (Jeremy's doubled fire lands the same frame)
var _harnessed_reentry: bool = false # guard: the Harnessed Sun's +2 burn must not amplify itself
var _three_count_cd: int = 0     # Mits of Chingiz: cycles until 3 count can fire again
var _offensive_streak: int = 0   # consecutive offensive cards played (3 count)
var _cuffs_cycle_accum: int = 0  # Cuffs of Current: cycles banked toward the next free draw
var _spiked_armor_accum: int = 0 # Spiked Mitts: armor gained banked toward the next thorns grant
const FrankensteinScript = preload("res://scripts/battle/frankensteins_monster.gd")
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
var _loot_tooltip: PanelContainer = null
var _loot_tooltip_label: Label = null

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
# Preloaded so main.gd doesn't depend on these newer class_names being present
# in Godot's global class cache (avoids "Could not find type" on first run).
const SandboxUIScript = preload("res://scripts/ui/sandbox_ui.gd")
const HudIconBarScript = preload("res://scripts/ui/hud_icon_bar.gd")
const EnemyInspectUIScript = preload("res://scripts/ui/enemy_inspect_ui.gd")
const HandSlotsScript = preload("res://scripts/cards/hand_slots.gd")

# Hand cards bind to the number row (1..9, 0) so WASD is free for movement.
const CARD_KEYS = [
	KEY_1, KEY_2, KEY_3, KEY_4, KEY_5,
	KEY_6, KEY_7, KEY_8, KEY_9, KEY_0,
]

var selected_card_index: int = -1
var targeting_arrow: TargetingArrow = null  # red player→mouse arrow for unit-targeted cards
var current_character: CharacterData = null
var starting_character: CharacterData = null
var player2_character: CharacterData = null
var is_multiplayer: bool = false
var sandbox_mode: bool = false      # Free-play arena launched from the Sandbox menu
var sandbox_ui = null                # SandboxUI (preloaded; untyped to avoid class-cache dependency)
# Ally interaction: right-clicking the co-op partner opens a small menu whose
# "Trade" entry opens the two-pane trade window (items + gold, both ways).
var trade_ui = null                  # TradeUI (created lazily on first trade)
var _ally_menu: PopupMenu = null     # right-click context menu on the partner
var _ally_menu_target: Player = null
var hud_icon_bar = null              # HudIconBar — top-right icon bar (character / EXP / quest / help)
var _quest_notify: bool = false      # A quest was added/updated/completed since last opened

# Active fire walls (Fire Goblin Shaman). Each: {tiles, damage, burn, moves_left, visuals}.
var _fire_walls: Array = []

# Forest hazards & climbing (see DungeonManager forest features).
const TREE_CANOPY_Y := 2.0          # height the player rests at while up a tree
const BEAR_TRAP_DAMAGE := 7         # to anything that steps on a sprung trap…
const BEAR_TRAP_BEAR_DAMAGE := 10   # …but bears take extra
const DART_TRAP_DAMAGE := 5         # hunters' tripwire dart volley
const WEB_TRAP_DAMAGE := 5          # cave spiked spiderwebs (also snares)
const WALL_DART_DAMAGE := 6         # building wall dart shooters
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
var maintained_icon: MaintainedIconUI = null
var jailed_icon: JailedIconUI = null
var _mana_reserve_tip: ManaReserveTooltip = null

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

# Action queue dropdown (▾ beside the tick bar label): lists queued actions;
# entries whose ticks haven't started carry a red ✕ to cancel them.
const ACTION_QUEUE_MAX_ROWS: int = 15
var _queue_toggle_btn: Button = null
var _queue_panel: PanelContainer = null
var _queue_list: VBoxContainer = null
var _queue_open: bool = false

# Pause system
var _is_paused: bool = false
var _pause_button: Button = null

var barricade_obstacles: Array = []  # [{node: MeshInstance3D, health: int}]
var active_pillars: Array = []  # [{node: Node3D, position: Vector3, tempo_remaining: int}]
var _card_ui_instances: Array = []  # one CardUI per hand group (parallel to _hand_groups)
var _current_hand_hover_index: int = -1

# Persistent hand-slot layer: identical cards stack under one lettered play
# button, and a slot keeps its letter until the last copy leaves hand — playing
# a card never re-letters the others (see HandSlots). _hand_groups is the
# rendered view, one entry per occupied slot:
#   {slot:int, cards:Array[Card], rep:Card, card_ui:CardUI}
var _hand_slots = HandSlotsScript.new()
var _hand_groups: Array = []
# Pending quiver card play state
var _block_button: Button = null
var _attack_button: Button = null
var _attack_damage_label: Label = null  # Red basic-attack damage beside the sword
var _attack_tempo_label: Label = null   # "5T (n)" tempo/proc readout
var _rack_button: Button = null         # Brad's War Rack swap (free on cooldown / paid)
# Basic (auto) attack baseline: flat damage before the STR modifier, so early
# swings never feel like pure chip damage. STR still scales on top of this.
var _flash_button: Button = null        # bolt + pool count display (60% of the row)
var _flash_move_button: Button = null   # boots: toggle spending flash on movement
var _flash_move_sparkle: SparkleBorder = null  # gold cycling border while the toggle is on
var _flash_block_button: Button = null  # duck: 3 flash → 2 block
var _flash_proc_button: Button = null   # daggers: 5 flash → 1 attack-speed tick
var _brain_button: Button = null        # brain + pool count display (60% of the row)
var _brain_peek_button: Button = null   # eye: escalating cost → reveal next draw-pile card
var _brain_draw_button: Button = null   # card+: escalating cost → draw a card
var _brain_draw_cost_label: Label = null  # small price badge on the draw button's corner
var _action_vbox: VBoxContainer = null  # bottom-left action column (draw/attack/block + wait|pause row)

# Stat bar UI references
var _hp_bar: ProgressBar = null
var _mana_bar: ProgressBar = null
var _armor_bar: ProgressBar = null
var _xp_bar: ProgressBar = null
var _hp_bar_label: Label = null
var _mana_bar_label: Label = null
var _armor_bar_label: Label = null
var _xp_bar_label: Label = null
var _level_badge_label: Label = null  # "Lvl: X" beside the XP bar
var _mana_regen_drop_label: Label = null  # number inside the mana-regen raindrop
var _armor_shield_label: Label = null     # armor value inside the shield beside the HP bar
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

# ============================================
# LOW-RES WORLD RENDER (Secret-of-Mana pixel look)
# The 3D battle renders at WORLD_RES inside a SubViewport and is
# nearest-upscaled to the window; UI CanvasLayers stay full resolution.
# ============================================

# Integer downscale factor for the world render: 1280x720 / 2 = 640x360.
const WORLD_SHRINK := 2
var _world_viewport: SubViewport = null
var _world_container: SubViewportContainer = null
var _world_camera: Camera3D = null


func _setup_world_viewport() -> void:
	var cam := $Camera3D as Camera3D
	var layer := CanvasLayer.new()
	layer.name = "WorldRenderLayer"
	layer.layer = -100
	add_child(layer)
	var svc := SubViewportContainer.new()
	svc.name = "WorldViewportContainer"
	# stretch + stretch_shrink is the canonical low-res setup: the container
	# sizes the SubViewport to container_size / shrink and scales the result
	# back up. (Setting sv.size manually is futile — stretch overrides it.)
	svc.stretch = true
	svc.stretch_shrink = WORLD_SHRINK
	svc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(svc)
	var sv := SubViewport.new()
	sv.name = "WorldViewport"
	sv.world_3d = get_viewport().find_world_3d()
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.physics_object_picking = false
	svc.add_child(sv)
	_world_viewport = sv
	_world_container = svc
	# The scene camera moves into the SubViewport; the root viewport is left
	# without an active 3D camera so the world only renders low-res.
	cam.get_parent().remove_child(cam)
	sv.add_child(cam)
	cam.current = true
	_world_camera = cam


## Style guide §3: one global light, upper-left 45°, no engine-cast shadows
## (all contact shadows are discrete blob quads).
func _unify_lighting() -> void:
	var light := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if light:
		light.rotation_degrees = Vector3(-45, -30, 0)
		light.shadow_enabled = false
	# The void beyond the arena reads as a dark olive ground haze instead of
	# pure black — SoM frames are never empty (VERIFY_PASS2 item 9).
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		we.environment.background_mode = Environment.BG_COLOR
		we.environment.background_color = Color8(26, 28, 20)


## The camera that renders the 3D world (lives inside the world SubViewport).
func get_world_camera() -> Camera3D:
	if _world_camera and is_instance_valid(_world_camera):
		return _world_camera
	return get_viewport().get_camera_3d()


## Ratio between the world viewport's pixels and root-viewport pixels.
func _world_scale_ratio() -> Vector2:
	if _world_viewport and _world_container and _world_container.size.x > 0.0 and _world_container.size.y > 0.0:
		return Vector2(_world_viewport.size) / _world_container.size
	return Vector2.ONE


## Mouse position mapped into the low-res world viewport's coordinates.
func _world_mouse_position() -> Vector2:
	return get_viewport().get_mouse_position() * _world_scale_ratio()


## Project a world position to FULL-RES screen coordinates (for UI overlays).
func world_to_screen(world_pos: Vector3) -> Vector2:
	var cam := get_world_camera()
	if cam == null:
		return Vector2.ZERO
	var ratio := _world_scale_ratio()
	var p := cam.unproject_position(world_pos)
	if ratio.x <= 0.0 or ratio.y <= 0.0:
		return p
	return p / ratio


func _ready() -> void:
	_setup_world_viewport()
	_unify_lighting()
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
	deck_manager.non_play_discard.connect(_on_non_play_discard)
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
	overflow_manager.overdraw_processed.connect(_on_overdraw_processed)
	overflow_manager.overflow_effects_changed.connect(func():
		if _hand_info_popup and _hand_info_popup.visible:
			_refresh_hand_info_popup())
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
	skill_tree_ui.stats_allocated.connect(progression_triggers._on_skill_tree_stats_allocated)
	# Clear the EXP notification dot once points are actually spent (stat
	# allocations signal; passive spends are caught when the panel closes).
	skill_tree_ui.stats_allocated.connect(func(_a): _refresh_hud_notifications())
	skill_tree_ui.closed.connect(_refresh_hud_notifications)

	_setup_action_buttons()
	_setup_tick_bar()
	_setup_stat_bars()
	_setup_deck_info_vertical()
	_setup_battle_log()
	_setup_targeting_arrow()

	if starting_character:
		select_character(starting_character)
	else:
		select_character(CharacterData.create_ryan())

	# Restore player progression from a world transition (level, stats, passives, sphere grid, etc.)
	if not player_progression.is_empty():
		_restore_player_progression(player_progression)

	# Style the hand area with solid background so battlefield doesn't bleed through
	_setup_hand_area_background()
	# (The Deck button now lives in the top-right HUD icon bar; only the popup
	# panel is created here.)
	_setup_deck_list_panel()
	_setup_maintained_icon()
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
			# Cover reactions: each partner can mitigate the other's damage.
			var p2s = _p2_player.get_stats()
			if p2s:
				p2s.damage_taken.connect(_on_ally_damage_taken.bind(_p2_player))
			var p1s = _p1_player.get_stats()
			if p1s:
				p1s.damage_taken.connect(_on_ally_damage_taken.bind(_p1_player))
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

	# HUD icon bar (character / EXP / quest journal / help)
	_setup_hud_icon_bar()

	# Initialize dungeon
	_setup_dungeon()
	_update_enemy_count()
	_refresh_unit_tracker()

	# Co-op: now that the dungeon has placed Player 1, seat Player 2 beside them.
	if is_multiplayer and _p2_player:
		player2_ui.reposition_beside_p1()

	# Sandbox: open the card/enemy control panel and raise some high ground.
	if sandbox_mode:
		_setup_sandbox()

	# HUD notification wiring: light the EXP dot on level-up, the Quest dot on
	# any quest activity. Initial state reflects any already-pending choices.
	if player and player.get_stats():
		if not player.get_stats().leveled_up.is_connected(_on_leveled_up_notify):
			player.get_stats().leveled_up.connect(_on_leveled_up_notify)
	if quest_manager:
		if not quest_manager.quest_accepted.is_connected(_on_quest_activity_id):
			quest_manager.quest_accepted.connect(_on_quest_activity_id)
			quest_manager.quest_updated.connect(_on_quest_activity_upd)
			quest_manager.quest_completed.connect(_on_quest_activity_id)
	_refresh_hud_notifications()
	# Stepped back through the town-side twin of a Return Scroll portal:
	# restore the player to where they set it and re-open the battle-side end.
	if portal_return_position != null:
		call_deferred("_apply_portal_return")

func _apply_portal_return() -> void:
	if portal_return_position == null or not player:
		return
	var back = portal_return_position
	portal_return_position = null
	var cell = grid_manager.world_to_grid(back)
	# Land beside the portal tile, not inside it.
	var land = cell + Vector2i(0, 1)
	if land in player.blocked_tiles:
		land = cell + Vector2i(1, 0)
	var world = grid_manager.grid_to_world(land)
	player.position = Vector3(world.x, player.position.y, world.z)
	if "target_position" in player:
		player.target_position = player.position
	spawn_town_portal(back)
	add_battle_log("You step back through your portal.", Color(0.8, 0.55, 1.0))

## Raycast from camera through mouse position to the ground plane (Y=0).
## Returns the 3D world position on the ground.
func get_mouse_world_position() -> Vector3:
	var camera = get_world_camera()
	if not camera:
		return Vector3.ZERO
	var mouse_pos = _world_mouse_position()
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
	var camera = get_world_camera()
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
	# Orthographic projection: SNES perspective has no foreshortening — this
	# is the single biggest "reads 16-bit vs reads 3D" lever. Size is frame-
	# matched to the old perspective view so zoom levels feel unchanged.
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0 * _camera_distance * tan(deg_to_rad(75.0) * 0.5) * 0.62

var _minimap_refresh_accum: float = 0.0

func _process(delta: float) -> void:
	_update_hand_hover()
	_update_battlefield_enemy_hover()
	_update_self_target_hover()
	_update_damage_preview()
	_update_loot_hover()
	_check_doughnut_farewell()
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

	# Hover hitbox matches the card's visible footprint: the cards rest with
	# their top at the band top and run down to (and below) the band bottom, so
	# the trigger is the band's own height — no tall padding above it.
	var in_bounds = (
		mouse_pos.y >= -4.0 and
		mouse_pos.y <= hand_container.size.y and
		mouse_pos.x >= -10.0 and
		mouse_pos.x <= hand_container.size.x + 10.0
	)

	if not in_bounds:
		if _current_hand_hover_index != -1:
			_set_hand_hover(-1)
		return

	# Find closest card by center X position
	var best_index = -1
	var best_dist = INF
	var card_half_width = 75.0  # 150 / 2

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
		if is_instance_valid(new_ui) and new_index < _hand_groups.size():
			new_ui.set_hovered_external(true)
			_on_hand_card_hovered(_hand_groups[new_index]["rep"], new_ui)

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

var _self_hover_active: bool = false

func _update_self_target_hover() -> void:
	## When a self-targetable card is selected, glow the player figure while the
	## cursor is over them — the same feedback enemies get as valid targets.
	var want := false
	if selected_card_index >= 0 and selected_card_index < deck_manager.hand.size() and player:
		var card = deck_manager.hand[selected_card_index]
		if "self" in card.target_types or "ally" in card.target_types:
			var mouse_pos = get_mouse_world_position()
			# Prefer an explicit hit on a player figure (co-op aware); fall back to
			# proximity to this player.
			var tgt = _player_at_position(mouse_pos) if has_method("_player_at_position") else null
			if tgt == null:
				var diff = mouse_pos - player.position
				if Vector3(diff.x, 0, diff.z).length() < 1.2:
					tgt = player
			want = tgt != null
	if want != _self_hover_active:
		_self_hover_active = want
		if player and player.has_method("set_hover_highlight"):
			player.set_hover_highlight(want)

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

	# The action column shrink-wraps to its widest button (the Attack button, at
	# its natural content width). Anchored bottom-left, it grows up and to the
	# right, so the Wait+Pause row below matches the Attack width automatically.
	var vbox = VBoxContainer.new()
	vbox.name = "ActionButtons"
	ui.add_child(vbox)
	vbox.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	vbox.grow_horizontal = Control.GROW_DIRECTION_END
	vbox.grow_vertical = Control.GROW_DIRECTION_BEGIN
	vbox.offset_left = 8.0
	vbox.offset_right = 8.0
	vbox.offset_top = -8.0
	vbox.offset_bottom = -8.0
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_vbox = vbox

	# Compact icon buttons: a glyph carries the meaning (sword = attack,
	# hand = wait, stop sign = pause) so only the numbers need text, keeping
	# the stack small and the battlefield clear. The Draw pile button is
	# inserted at the top of this column by _setup_deck_info_vertical.

	# Flash row (above Attack). Left 60%: bolt + pool count (display only).
	# Right 40%: three spend buttons — boots toggles flash movement, the
	# ducking figure buys block, the crossed daggers buy an attack-speed tick.
	# Spend buttons fade while the pool can't afford them.
	var flash_row = HBoxContainer.new()
	flash_row.name = "FlashRow"
	flash_row.add_theme_constant_override("separation", 2)
	vbox.add_child(flash_row)

	_flash_button = Button.new()
	_flash_button.name = "FlashCount"
	_flash_button.icon = UIGlyphs.get_glyph("flash_bolt")
	_flash_button.text = "0"
	_flash_button.custom_minimum_size = Vector2(0, 36)
	_flash_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flash_button.size_flags_stretch_ratio = 6.0
	_flash_button.focus_mode = Control.FOCUS_NONE
	flash_row.add_child(_flash_button)

	_flash_move_button = Button.new()
	_flash_move_button.name = "FlashMoveToggle"
	_flash_move_button.icon = UIGlyphs.get_glyph("boots")
	_flash_move_button.toggle_mode = true
	_flash_move_button.expand_icon = true
	_flash_move_button.custom_minimum_size = Vector2(26, 36)
	_flash_move_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flash_move_button.size_flags_stretch_ratio = 4.0 / 3.0
	_flash_move_button.toggled.connect(_on_flash_move_toggled)
	flash_row.add_child(_flash_move_button)
	# Sparkling gold border cycling the boots button while auto-spend is on.
	_flash_move_sparkle = SparkleBorder.new()
	_flash_move_button.add_child(_flash_move_sparkle)

	_flash_block_button = Button.new()
	_flash_block_button.name = "FlashBlockButton"
	_flash_block_button.icon = UIGlyphs.get_glyph("duck")
	_flash_block_button.expand_icon = true
	_flash_block_button.custom_minimum_size = Vector2(26, 36)
	_flash_block_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flash_block_button.size_flags_stretch_ratio = 4.0 / 3.0
	_flash_block_button.pressed.connect(_on_flash_block_pressed)
	flash_row.add_child(_flash_block_button)

	_flash_proc_button = Button.new()
	_flash_proc_button.name = "FlashProcButton"
	_flash_proc_button.icon = UIGlyphs.get_glyph("dual_daggers")
	_flash_proc_button.expand_icon = true
	_flash_proc_button.custom_minimum_size = Vector2(26, 36)
	_flash_proc_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flash_proc_button.size_flags_stretch_ratio = 4.0 / 3.0
	_flash_proc_button.pressed.connect(_on_flash_proc_pressed)
	flash_row.add_child(_flash_proc_button)

	# Brain row (below Flash, above Attack): Wisdom's pool. Same layout —
	# left 60%: brain + pool count (display only). Right 40%: two spend
	# buttons — the eye peeks the next draw-pile card, the card+ buys a draw.
	# Both prices escalate within each refresh window. Flash and Brain are
	# independent pools under the shared ACTION POINTS category.
	var brain_row = HBoxContainer.new()
	brain_row.name = "BrainRow"
	brain_row.add_theme_constant_override("separation", 2)
	vbox.add_child(brain_row)

	_brain_button = Button.new()
	_brain_button.name = "BrainCount"
	_brain_button.icon = UIGlyphs.get_glyph("brain")
	_brain_button.text = "0"
	_brain_button.custom_minimum_size = Vector2(0, 36)
	_brain_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_brain_button.size_flags_stretch_ratio = 6.0
	_brain_button.focus_mode = Control.FOCUS_NONE
	brain_row.add_child(_brain_button)

	# The two spend buttons mirror the flash row's THREE in total footprint
	# (2 × 39 min = 3 × 26, 2 × 2.0 ratio = 3 × 4/3), so both rows resolve to
	# identical count-button widths — the brain square matches the bolt square.
	_brain_peek_button = Button.new()
	_brain_peek_button.name = "BrainPeekButton"
	_brain_peek_button.icon = UIGlyphs.get_glyph("eye")
	_brain_peek_button.expand_icon = true
	_brain_peek_button.custom_minimum_size = Vector2(39, 36)
	_brain_peek_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_brain_peek_button.size_flags_stretch_ratio = 2.0
	_brain_peek_button.pressed.connect(_on_brain_peek_pressed)
	brain_row.add_child(_brain_peek_button)

	_brain_draw_button = Button.new()
	_brain_draw_button.name = "BrainDrawButton"
	_brain_draw_button.icon = UIGlyphs.get_glyph("card_plus")
	_brain_draw_button.expand_icon = true
	_brain_draw_button.custom_minimum_size = Vector2(39, 36)
	_brain_draw_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_brain_draw_button.size_flags_stretch_ratio = 2.0
	_brain_draw_button.pressed.connect(_on_brain_draw_pressed)
	brain_row.add_child(_brain_draw_button)
	# The next draw's price rides the button's top-right corner as a small
	# badge, leaving the card+ glyph full-size underneath.
	_brain_draw_cost_label = Label.new()
	_brain_draw_cost_label.add_theme_font_size_override("font_size", 9)
	_brain_draw_cost_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_brain_draw_cost_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_brain_draw_cost_label.add_theme_constant_override("outline_size", 4)
	_brain_draw_cost_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_brain_draw_cost_label.offset_left = -18.0
	_brain_draw_cost_label.offset_right = -2.0
	_brain_draw_cost_label.offset_top = 1.0
	_brain_draw_cost_label.offset_bottom = 12.0
	_brain_draw_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_brain_draw_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brain_draw_button.add_child(_brain_draw_cost_label)

	# Attack button (top): sword + damage + tempo cost + attacks until the
	# speed proc. Damage renders red beside the sword, so the button hosts an
	# HBox of labels instead of the single-colour built-in text.
	_attack_button = Button.new()
	_attack_button.name = "AttackButton"
	_attack_button.custom_minimum_size = Vector2(0, 36)
	_attack_button.size_flags_horizontal = Control.SIZE_FILL
	_attack_button.tooltip_text = "Basic melee attack: %d base + STR modifier damage. Costs 5 tempo." % PlayerStats.BASIC_ATTACK_BASE_DAMAGE
	_attack_button.pressed.connect(_on_attack_pressed)
	var atk_row := HBoxContainer.new()
	atk_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	atk_row.alignment = BoxContainer.ALIGNMENT_CENTER
	atk_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atk_row.add_theme_constant_override("separation", 5)
	var atk_icon := TextureRect.new()
	atk_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art stays crisp under the linear canvas default
	atk_icon.texture = UIGlyphs.get_glyph("sword")
	atk_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	atk_icon.custom_minimum_size = Vector2(22, 22)
	atk_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	atk_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atk_row.add_child(atk_icon)
	_attack_damage_label = Label.new()
	_attack_damage_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_attack_damage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atk_row.add_child(_attack_damage_label)
	_attack_tempo_label = Label.new()
	_attack_tempo_label.text = "5T (0)"
	_attack_tempo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atk_row.add_child(_attack_tempo_label)
	_attack_button.add_child(atk_row)
	# Reserve the row's natural width so the content-sized button fits it.
	_attack_button.custom_minimum_size.x = 118
	vbox.add_child(_attack_button)

	# Block button (middle, only visible if shield equipped)
	_block_button = Button.new()
	_block_button.name = "BlockButton"
	_block_button.icon = UIGlyphs.get_glyph("shield")
	_block_button.text = "5T"
	_block_button.custom_minimum_size = Vector2(0, 36)
	_block_button.size_flags_horizontal = Control.SIZE_FILL
	_block_button.tooltip_text = "Raise shield to block. Costs 5 tempo."
	_block_button.pressed.connect(_on_block_pressed)
	_block_button.visible = false
	vbox.add_child(_block_button)

	# War Rack button (Brad only): swap hands with the gear on his back.
	_rack_button = Button.new()
	_rack_button.name = "RackButton"
	_rack_button.text = "Rack"
	_rack_button.custom_minimum_size = Vector2(0, 36)
	_rack_button.size_flags_horizontal = Control.SIZE_FILL
	_rack_button.pressed.connect(_on_rack_button_pressed)
	_rack_button.visible = false
	vbox.add_child(_rack_button)

	# Bottom row: Wait beside a (shrunk) Pause, stretched to the column (= attack)
	# width so the two plus the gap match the Attack button.
	var bottom_row = HBoxContainer.new()
	bottom_row.name = "WaitPauseRow"
	bottom_row.custom_minimum_size = Vector2(0, 36)
	bottom_row.size_flags_horizontal = Control.SIZE_FILL
	bottom_row.add_theme_constant_override("separation", 4)
	vbox.add_child(bottom_row)

	# Wait: raised hand + the 1 tempo it advances (takes the remaining width).
	var wait_btn = Button.new()
	wait_btn.name = "WaitButton"
	wait_btn.icon = UIGlyphs.get_glyph("wait_hand")
	wait_btn.text = "1T"
	wait_btn.custom_minimum_size = Vector2(0, 36)
	wait_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wait_btn.tooltip_text = "Advance the tempo clock by 1 without playing a card"
	wait_btn.pressed.connect(_on_wait_pressed)
	bottom_row.add_child(wait_btn)

	# Pause: narrow red stop sign, no text; shows a green play triangle while paused.
	_pause_button = Button.new()
	_pause_button.name = "PauseButton"
	_pause_button.icon = UIGlyphs.get_glyph("stop_sign")
	_pause_button.custom_minimum_size = Vector2(38, 36)
	_pause_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_pause_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	bottom_row.add_child(_pause_button)

func _setup_targeting_arrow() -> void:
	## Screen-space red arrow from the player to the mouse while a card that
	## targets a specific enemy/ally is selected (see TargetingArrow).
	targeting_arrow = TargetingArrow.new()
	targeting_arrow.name = "TargetingArrow"
	targeting_arrow.main = self
	($UI as CanvasLayer).add_child(targeting_arrow)

func _setup_tick_bar() -> void:
	## Build the 20-tick global tempo bar centered at the top of the screen,
	## framed like a little bookshelf (dark walnut box, gold trim, and a shelf
	## plank the tick "books" stand on) so it stands out.
	var ui = $UI as CanvasLayer

	# Outer frame: a wooden box with a thin gold line running the whole border.
	var frame = PanelContainer.new()
	frame.name = "TickBarFrame"
	ui.add_child(frame)
	# Anchored top-centre and shrink-wrapped to its contents so the wooden box
	# hugs the tick bars instead of leaving wide empty margins.
	frame.set_anchors_preset(Control.PRESET_CENTER_TOP)
	frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	frame.grow_vertical = Control.GROW_DIRECTION_END
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.offset_left = 0.0
	frame.offset_top = 32.0
	frame.offset_right = 0.0
	frame.offset_bottom = 0.0
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.16, 0.11, 0.07)          # dark walnut
	frame_style.set_border_width_all(2)
	frame_style.border_color = Color(0.82, 0.66, 0.28)      # thin gold line
	frame_style.set_corner_radius_all(5)
	frame_style.content_margin_left = 6
	frame_style.content_margin_right = 6
	frame_style.content_margin_top = 4
	frame_style.content_margin_bottom = 4
	frame_style.shadow_color = Color(0, 0, 0, 0.45)
	frame_style.shadow_size = 4
	frame.add_theme_stylebox_override("panel", frame_style)

	var tick_container = VBoxContainer.new()
	tick_container.name = "TickBarContainer"
	tick_container.add_theme_constant_override("separation", 2)
	frame.add_child(tick_container)

	# Card name label
	_tick_bar_card_name_label = Label.new()
	_tick_bar_card_name_label.name = "TickBarCardName"
	_tick_bar_card_name_label.text = ""
	_tick_bar_card_name_label.add_theme_font_size_override("font_size", 11)
	_tick_bar_card_name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_tick_bar_card_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tick_container.add_child(_tick_bar_card_name_label)

	# Bar row — the "books" standing on the shelf.
	var bar_hbox = HBoxContainer.new()
	bar_hbox.name = "TickBars"
	bar_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_hbox.add_theme_constant_override("separation", 3)
	tick_container.add_child(bar_hbox)

	_tick_bar_rects.clear()
	for i in range(20):
		var bar = ColorRect.new()
		bar.custom_minimum_size = Vector2(13, 29)  # wider tick "books"
		bar.color = Color(0.15, 0.15, 0.2)  # Dim/inactive
		bar_hbox.add_child(bar)
		_tick_bar_rects.append(bar)

	# Shelf plank the tick books rest on: a wood strip capped with a gold edge.
	var shelf = Panel.new()
	shelf.name = "TickBarShelf"
	shelf.custom_minimum_size = Vector2(0, 5)
	shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shelf_style := StyleBoxFlat.new()
	shelf_style.bg_color = Color(0.28, 0.19, 0.11)          # lighter plank wood
	shelf_style.border_width_top = 1
	shelf_style.border_color = Color(0.82, 0.66, 0.28)      # gold shelf edge
	shelf_style.set_corner_radius_all(1)
	shelf.add_theme_stylebox_override("panel", shelf_style)
	tick_container.add_child(shelf)

	# Status label + queue dropdown arrow, side by side
	var label_row = HBoxContainer.new()
	label_row.alignment = BoxContainer.ALIGNMENT_CENTER
	label_row.add_theme_constant_override("separation", 4)
	tick_container.add_child(label_row)

	_tick_bar_label = Label.new()
	_tick_bar_label.name = "TickBarLabel"
	_tick_bar_label.text = "Ready"
	_tick_bar_label.add_theme_font_size_override("font_size", 11)
	_tick_bar_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
	_tick_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_row.add_child(_tick_bar_label)

	_queue_toggle_btn = Button.new()
	_queue_toggle_btn.name = "QueueToggle"
	_queue_toggle_btn.text = "▾"
	_queue_toggle_btn.tooltip_text = "Show the action queue — cancel queued actions before their tempo starts"
	_queue_toggle_btn.custom_minimum_size = Vector2(22, 16)
	_queue_toggle_btn.add_theme_font_size_override("font_size", 11)
	_queue_toggle_btn.flat = true
	_queue_toggle_btn.pressed.connect(_toggle_action_queue)
	label_row.add_child(_queue_toggle_btn)

	# The dropdown itself: hangs below the tick bar, hidden until opened.
	_queue_panel = PanelContainer.new()
	_queue_panel.name = "ActionQueuePanel"
	_queue_panel.visible = false
	var q_style := StyleBoxFlat.new()
	q_style.bg_color = Color(0.09, 0.07, 0.05, 0.95)
	q_style.border_color = Color(0.82, 0.66, 0.28)
	q_style.set_border_width_all(1)
	q_style.set_corner_radius_all(4)
	q_style.content_margin_left = 8
	q_style.content_margin_right = 8
	q_style.content_margin_top = 6
	q_style.content_margin_bottom = 6
	_queue_panel.add_theme_stylebox_override("panel", q_style)
	tick_container.add_child(_queue_panel)

	_queue_list = VBoxContainer.new()
	_queue_list.add_theme_constant_override("separation", 2)
	_queue_panel.add_child(_queue_list)

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

	_refresh_action_queue()

func _toggle_action_queue() -> void:
	_queue_open = not _queue_open
	if _queue_panel:
		_queue_panel.visible = _queue_open
	if _queue_toggle_btn:
		_queue_toggle_btn.text = "▴" if _queue_open else "▾"
	_refresh_action_queue()

func _refresh_action_queue() -> void:
	## Rebuild the dropdown rows from _pending_resolve_queue (latest
	## ACTION_QUEUE_MAX_ROWS). An action whose ticks have started is locked
	## ("ticking…"); anything still waiting carries a red ✕ to cancel it.
	if not _queue_open or _queue_list == null:
		return
	for child in _queue_list.get_children():
		child.queue_free()

	if _pending_resolve_queue.is_empty():
		var empty := Label.new()
		empty.text = "Nothing queued."
		empty.add_theme_font_size_override("font_size", 11)
		empty.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4))
		_queue_list.add_child(empty)
		return

	var start: int = maxi(0, _pending_resolve_queue.size() - ACTION_QUEUE_MAX_ROWS)
	for i in range(start, _pending_resolve_queue.size()):
		var entry: Dictionary = _pending_resolve_queue[i]
		var card: Card = entry["card"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var name_lbl := Label.new()
		var action_name: String = "Basic Attack" if entry["data"].get("is_basic_attack", false) else card.card_name
		if is_multiplayer and entry.get("owner_index", 0) == 1:
			action_name += "  (P2)"
		name_lbl.text = action_name
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.custom_minimum_size = Vector2(140, 0)
		row.add_child(name_lbl)

		if tempo_manager.is_card_started(card):
			var ticking := Label.new()
			ticking.text = "ticking…"
			ticking.add_theme_font_size_override("font_size", 11)
			ticking.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			row.add_child(ticking)
		else:
			var cancel_btn := Button.new()
			cancel_btn.text = "✕"
			cancel_btn.tooltip_text = "Cancel this action (it hasn't started ticking yet)"
			cancel_btn.custom_minimum_size = Vector2(22, 18)
			cancel_btn.add_theme_font_size_override("font_size", 12)
			cancel_btn.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
			cancel_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.55, 0.5))
			cancel_btn.pressed.connect(_cancel_queued_action.bind(card))
			row.add_child(cancel_btn)

		_queue_list.add_child(row)

func _cancel_queued_action(card: Card) -> void:
	## Red ✕: pull a queued action before its tempo starts. Once its ticks
	## begin the player is locked in and this refuses.
	if tempo_manager.is_card_started(card):
		add_battle_log("Too late — that action's tempo is already ticking!", Color(1.0, 0.5, 0.4))
		_refresh_action_queue()
		return
	for i in range(_pending_resolve_queue.size()):
		var entry: Dictionary = _pending_resolve_queue[i]
		if entry["card"] != card:
			continue
		_pending_resolve_queue.remove_at(i)
		# Co-op: return the card to its OWNER's hand, not the active player's.
		var owner_idx: int = entry.get("owner_index", 0)
		if is_multiplayer and owner_idx != _active_index:
			var prev_p := player
			var prev_d := deck_manager
			player = _p1_player if owner_idx == 0 else _p2_player
			deck_manager = _p1_deck_manager if owner_idx == 0 else _p2_deck_manager
			_return_dead_target_card(card, entry["data"], "cancelled")
			_refund_cancelled_action_cost(player, entry["data"])
			player = prev_p
			deck_manager = prev_d
		else:
			_return_dead_target_card(card, entry["data"], "cancelled")
			_refund_cancelled_action_cost(player, entry["data"])
		_on_hand_updated()
		update_deck_info()
		_refresh_action_queue()
		return

func _refund_cancelled_action_cost(p, data: Dictionary) -> void:
	## A voluntary cancel gives back exactly what the play cost — the mana
	## spent (or health, when Demonic Rage paid). Dead-target returns keep
	## their existing behavior; this runs only from the queue's red ✕.
	var mana_spent: int = data.get("mana_spent", 0)
	var health_spent: int = data.get("health_spent", 0)
	if mana_spent <= 0 and health_spent <= 0:
		return
	var stats = p.get_stats() if p else null
	if not stats:
		return
	stats.refund_action_cost(mana_spent, health_spent)
	var parts: Array[String] = []
	if mana_spent > 0:
		parts.append("%d mana" % mana_spent)
	if health_spent > 0:
		parts.append("%d health" % health_spent)
	add_battle_log("Refunded %s." % " and ".join(parts), Color(0.5, 0.8, 1.0))

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
	# Tucked in right beside the minimap (which ends at x = 116).
	stat_container.offset_left = 122.0
	stat_container.offset_top = 8.0
	stat_container.offset_right = 332.0
	stat_container.offset_bottom = 130.0
	stat_container.add_theme_constant_override("separation", 4)

	# --- HP Bar (red) — armour shown as a shield badge to its right ---
	var hp_pair = _create_stat_bar_with_label(stat_container, "HPBar", Color(0.7, 0.15, 0.15), Color(0.3, 0.08, 0.08))
	_hp_bar = hp_pair[0]
	_hp_bar_label = hp_pair[1]
	_setup_armor_shield()

	# --- Mana Bar (blue) ---
	var mana_pair = _create_stat_bar_with_label(stat_container, "ManaBar", Color(0.15, 0.3, 0.8), Color(0.08, 0.12, 0.3))
	_mana_bar = mana_pair[0]
	_mana_bar_label = mana_pair[1]
	# Hovering the mana bar lists how much mana each maintained card reserves.
	_mana_reserve_tip = ManaReserveTooltip.new()
	_mana_reserve_tip.name = "ManaReserveTooltip"
	_mana_bar.get_parent().add_child(_mana_reserve_tip)
	_setup_mana_regen_drop()

	# --- XP Bar (gold) — right under mana, a quarter of the normal height ---
	var xp_pair = _create_stat_bar_with_label(stat_container, "XPBar", Color(0.8, 0.65, 0.1), Color(0.3, 0.25, 0.05), 6)
	_xp_bar = xp_pair[0]
	# The bar is too thin for an overlaid number; the level/XP text lives in the
	# character panel instead.
	if xp_pair[1]:
		xp_pair[1].visible = false

	# Current level, just right of the XP bar (below the mana drop).
	_level_badge_label = Label.new()
	_level_badge_label.name = "LevelBadge"
	_level_badge_label.text = "Lvl: 1"
	_level_badge_label.tooltip_text = "Character level"
	_level_badge_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_level_badge_label.add_theme_font_size_override("font_size", 13)
	_level_badge_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.2))
	_level_badge_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_level_badge_label.add_theme_constant_override("outline_size", 4)
	_level_badge_label.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_level_badge_label.offset_left = 6.0
	_level_badge_label.offset_top = -9.0
	_level_badge_label.offset_bottom = 9.0
	_xp_bar.get_parent().add_child(_level_badge_label)

	# Buffs and debuffs sit directly under the (thin) XP bar rather than off to
	# the right of the health bar.
	_reposition_status_bars()
	_xp_bar_label = null
	# (Armour no longer has its own bar — the shield badge shows it.)
	_armor_bar = null
	_armor_bar_label = null

func _create_stat_bar_with_label(parent: VBoxContainer, bar_name: String, fill_color: Color, bg_color: Color, height: int = 22) -> Array:
	## Creates a progress bar with an overlaid centered label. Returns [bar, label].
	var wrapper = Control.new()
	wrapper.name = bar_name + "Wrapper"
	wrapper.custom_minimum_size = Vector2(200, height)
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

func _setup_mana_regen_drop() -> void:
	## A blue raindrop just right of the mana bar. The number in it is the tempo
	## remaining until the next mana-regen tick.
	if not _mana_bar:
		return
	var wrapper = _mana_bar.get_parent()
	var drop = Control.new()
	drop.name = "ManaRegenDrop"
	drop.mouse_filter = Control.MOUSE_FILTER_STOP
	drop.tooltip_text = "Tempo until your next mana regen"
	drop.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	drop.offset_left = 6.0
	drop.offset_right = 32.0
	drop.offset_top = -14.0
	drop.offset_bottom = 14.0
	wrapper.add_child(drop)

	var tex := TextureRect.new()
	tex.texture = UIGlyphs.get_glyph("raindrop")
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop.add_child(tex)

	_mana_regen_drop_label = Label.new()
	_mana_regen_drop_label.add_theme_font_size_override("font_size", 12)
	_mana_regen_drop_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_mana_regen_drop_label.add_theme_color_override("font_outline_color", Color(0.05, 0.15, 0.35))
	_mana_regen_drop_label.add_theme_constant_override("outline_size", 4)
	_mana_regen_drop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mana_regen_drop_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Centred over the round (lower) part of the drop.
	_mana_regen_drop_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mana_regen_drop_label.offset_top = 4.0
	_mana_regen_drop_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop.add_child(_mana_regen_drop_label)

func _update_mana_regen_indicator() -> void:
	if not _mana_regen_drop_label or not player:
		return
	var stats = player.get_stats()
	if stats:
		_mana_regen_drop_label.text = "%d" % stats.get_tempo_until_mana_regen()

func _setup_armor_shield() -> void:
	## A shield badge just right of the HP bar showing current armour (replaces
	## the old armour bar). Same footprint as the mana raindrop.
	if not _hp_bar:
		return
	var wrapper = _hp_bar.get_parent()
	var badge = Control.new()
	badge.name = "ArmorShield"
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	badge.tooltip_text = "Current armor"
	badge.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	badge.offset_left = 6.0
	badge.offset_right = 32.0
	badge.offset_top = -14.0
	badge.offset_bottom = 14.0
	wrapper.add_child(badge)

	var tex := TextureRect.new()
	tex.texture = UIGlyphs.get_glyph("shield")
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(tex)

	_armor_shield_label = Label.new()
	_armor_shield_label.add_theme_font_size_override("font_size", 12)
	_armor_shield_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_armor_shield_label.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.12))
	_armor_shield_label.add_theme_constant_override("outline_size", 5)
	_armor_shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_armor_shield_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_armor_shield_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_armor_shield_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(_armor_shield_label)

func _reposition_status_bars() -> void:
	## Stack the debuff and buff rows directly beneath the (thin) XP bar, close
	## to it, instead of floating out to the right of the health bar.
	# HP(22) + 4 + Mana(22) + 4 + XP(6) starting at y=8 -> bottom of XP at y=66.
	var left := 122.0
	var right := 122.0 + 360.0
	if debuff_bar:
		debuff_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
		debuff_bar.offset_left = left
		debuff_bar.offset_top = 69.0
		debuff_bar.offset_right = right
		debuff_bar.offset_bottom = 99.0
	if buff_bar:
		buff_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
		buff_bar.offset_left = left
		buff_bar.offset_top = 101.0
		buff_bar.offset_right = right
		buff_bar.offset_bottom = 131.0

func _setup_deck_info_vertical() -> void:
	## Draw and Discard piles become card-stack buttons on opposite edges:
	## Draw on the left (green up-arrow + turns-until-draw), Discard on the
	## right (yellow down-arrow + count). The Deck box lives in the top HUD bar.
	var deck_info = $UI/DeckInfo as HBoxContainer
	if deck_info:
		deck_info.visible = false  # retire the old horizontal readout

	var ui = $UI as CanvasLayer

	# Draw pile — sits at the TOP of the left-side action column (above Attack),
	# so it moves down to fill space along with the rest of the cluster.
	var draw_pair = _create_pile_button("DrawButton", true, Color(0.5, 0.95, 0.5))
	_draw_pile_btn = draw_pair[0]
	draw_label = draw_pair[1]
	_draw_pile_btn.pressed.connect(_on_draw_pile_button_pressed)
	_draw_pile_btn.custom_minimum_size = Vector2(50, 54)  # slightly bigger than the action buttons
	_draw_pile_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# The draw pile sits in a row with a small ⓘ button beside it. Clicking ⓘ
	# opens a small popup with max/current hand size and any active overflow
	# effects.
	var draw_row = HBoxContainer.new()
	draw_row.name = "DrawRow"
	draw_row.add_theme_constant_override("separation", 2)
	draw_row.add_child(_draw_pile_btn)
	_hand_info_btn = Button.new()
	_hand_info_btn.name = "HandInfoButton"
	_hand_info_btn.focus_mode = Control.FOCUS_NONE
	_hand_info_btn.icon = UIGlyphs.get_glyph("info")
	_hand_info_btn.flat = true
	_hand_info_btn.custom_minimum_size = Vector2(22, 22)
	_hand_info_btn.add_theme_constant_override("icon_max_width", 16)
	_hand_info_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hand_info_btn.tooltip_text = "Hand size and overflow info"
	_hand_info_btn.pressed.connect(_toggle_hand_info_popup)
	draw_row.add_child(_hand_info_btn)
	if _action_vbox:
		_action_vbox.add_child(draw_row)
		_action_vbox.move_child(draw_row, 0)  # top of the column

	# The popup itself lives on the UI layer, hidden until asked for.
	_hand_info_popup = PanelContainer.new()
	_hand_info_popup.name = "HandInfoPopup"
	_hand_info_popup.visible = false
	var hip_style = StyleBoxFlat.new()
	hip_style.bg_color = Color(0.1, 0.1, 0.15, 0.96)
	hip_style.border_color = Color(0.45, 0.7, 1.0)
	hip_style.set_border_width_all(1)
	hip_style.set_corner_radius_all(6)
	hip_style.content_margin_left = 10
	hip_style.content_margin_right = 10
	hip_style.content_margin_top = 8
	hip_style.content_margin_bottom = 8
	_hand_info_popup.add_theme_stylebox_override("panel", hip_style)
	_hand_info_vbox = VBoxContainer.new()
	_hand_info_vbox.add_theme_constant_override("separation", 3)
	_hand_info_popup.add_child(_hand_info_vbox)
	ui.add_child(_hand_info_popup)

	# Discard pile — right edge.
	var disc_wrap = Control.new()
	disc_wrap.name = "DiscardButtonContainer"
	ui.add_child(disc_wrap)
	disc_wrap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	disc_wrap.offset_left = -62.0
	disc_wrap.offset_top = -190.0
	disc_wrap.offset_right = -8.0
	disc_wrap.offset_bottom = -132.0
	var disc_pair = _create_pile_button("DiscardButton", false, Color(1.0, 0.85, 0.25))
	_discard_pile_btn = disc_pair[0]
	discard_label = disc_pair[1]
	_discard_pile_btn.pressed.connect(_on_discard_pile_button_pressed)
	_discard_pile_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	disc_wrap.add_child(_discard_pile_btn)

	jail_label = null

func _create_pile_button(btn_name: String, is_draw: bool, number_color: Color) -> Array:
	## A compact pile button: just the card-stack icon (up-arrow for Draw,
	## down-arrow for Discard) with a small coloured number tucked next to the
	## arrow so the button stays icon-sized. Draw's stack is flipped horizontally
	## so the cards' open side faces inward from the left edge.
	## Returns [button, number_label].
	var btn = Button.new()
	btn.name = btn_name
	btn.focus_mode = Control.FOCUS_NONE
	btn.icon = PileIcon.get_icon(is_draw, number_color, is_draw)
	btn.expand_icon = false
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_constant_override("icon_max_width", 42)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.92)
	style.set_border_width_all(1)
	style.border_color = number_color.darkened(0.3)
	style.set_corner_radius_all(6)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.16, 0.16, 0.2, 0.95)
	btn.add_theme_stylebox_override("hover", hover)

	# Small number overlaid right next to the arrow (top for Draw's up-arrow,
	# bottom for Discard's down-arrow), outlined so it reads over the cards.
	var num = Label.new()
	num.name = btn_name + "Number"
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	num.add_theme_font_size_override("font_size", 13)
	num.add_theme_color_override("font_color", number_color)
	num.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.06))
	num.add_theme_constant_override("outline_size", 5)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if is_draw:
		# Beside the up-arrow head, upper area.
		num.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		num.offset_left = -22.0
		num.offset_right = -2.0
		num.offset_top = 1.0
		num.offset_bottom = 19.0
	else:
		# Beside the down-arrow head, lower area.
		num.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		num.offset_left = -22.0
		num.offset_right = -2.0
		num.offset_top = -19.0
		num.offset_bottom = -1.0
	btn.add_child(num)

	return [btn, num]

func _on_pause_pressed() -> void:
	_is_paused = not _is_paused
	if _is_paused:
		get_tree().paused = true
		_pause_button.icon = UIGlyphs.get_glyph("play")
		_pause_button.tooltip_text = "Resume gameplay."
		add_battle_log("PAUSED", Color(1.0, 0.85, 0.3))
		print("[MAIN] Game paused")
	else:
		get_tree().paused = false
		_pause_button.icon = UIGlyphs.get_glyph("stop_sign")
		_pause_button.tooltip_text = "Pause gameplay. Useful during tick resolution or multiplayer coordination."
		print("[MAIN] Game resumed")

func _setup_battle_log() -> void:
	var ui = $UI as CanvasLayer

	# Outer container to hold toggle button + log panel vertically, tucked
	# directly under the HUD icon bar (which ends at y = 46).
	var outer = VBoxContainer.new()
	outer.name = "BattleLogOuter"
	ui.add_child(outer)
	outer.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	outer.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	outer.grow_vertical = Control.GROW_DIRECTION_END
	outer.offset_left = -200.0
	outer.offset_top = 52.0
	outer.offset_right = -8.0
	outer.offset_bottom = 292.0
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

	# NOTE: the swing animation plays when the attack RESOLVES (immediately for
	# Steady/zero-tempo below, otherwise on its resolve tick in
	# _resolve_queued_card) so the motion lines up with the hit.

	# Damage: flat baseline + strength modifier (get_effective_physical_damage
	# already applies Flurry Form's per-hit penalty). Killing Rhythm's armed
	# bonus, if any, is spent on this swing.
	var damage = stats.get_basic_attack_damage()
	damage += stats.consume_pending_dex_bonus_damage()
	# Weighted Strikes: a heavy one-handed weapon's heft adds to the basic swing.
	if stats.keystone_str_weight_basic:
		var ba_inv = player.get_inventory()
		if ba_inv:
			damage += ba_inv.get_single_hand_weight_damage_bonus()

	var buff_mgr = player.get_buff_manager()
	if buff_mgr:
		damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			damage = Card.crit_multiply(damage, stats, target)

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
		# Flurry Form: the proc-empowered basic attack lands twice. A basic swing
		# has no per-hit card effects, so a doubled hit is equivalent to two.
		if stats.keystone_dex_twin_strike:
			damage *= 2
			print("[MAIN] Flurry Form: basic attack strikes twice!")
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
		if player.has_method("play_animation"):
			player.play_animation("attack_slash", _facing_dir_toward(target))
		target.take_damage(damage, true)
		if buff_mgr.last_crit_hit:
			buff_mgr.last_crit_hit = false
			progression_triggers._trigger_skill_tree_on_crit(target)
		# Proc-bonus attacks don't count towards the next cycle
		if not basic_attack_proc:
			stats.register_attack()
			if stats.consume_free_hand_echo() and is_instance_valid(target):
				target.take_damage(damage, true)
				add_battle_log("Free hand echo! The strike lands twice.", Color(1.0, 0.9, 0.4))
		if debuff_mgr:
			debuff_mgr.on_attack()
		add_battle_log("Basic Attack: %d damage to %s (Steady!)" % [damage, target.enemy_name], Color(0.4, 1.0, 0.5))
		print("[MAIN] Basic Attack (Steady): dealt %d damage to %s — no tempo" % [damage, target.enemy_name])
		_ring_note_big_hit(damage)
	elif tempo_cost <= 0:
		# Dex proc reduced tempo to 0: resolve immediately
		if player.has_method("play_animation"):
			player.play_animation("attack_slash", _facing_dir_toward(target))
		target.take_damage(damage, true)
		if buff_mgr and buff_mgr.last_crit_hit:
			buff_mgr.last_crit_hit = false
			progression_triggers._trigger_skill_tree_on_crit(target)
		# Proc-bonus attack: don't count towards next cycle
		if debuff_mgr:
			debuff_mgr.on_attack()
		add_battle_log("Basic Attack: %d damage to %s (Proc!)" % [damage, target.enemy_name], Color(1.0, 0.3, 0.3))
		print("[MAIN] Basic Attack (Dex Proc): dealt %d damage to %s — no tempo" % [damage, target.enemy_name])
		_ring_note_big_hit(damage)
	else:
		# Queue basic attack through the ticked tempo system.
		# Damage resolves on tick 1; remaining ticks are cooldown.
		var basic_card = Card.create_basic_attack(damage)
		var resolve_tick = 1

		# Store in the pending resolve queue (same as regular cards)
		var resolve_entry := {
			"card": basic_card,
			"target": target,
			"owner_index": _active_index,
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
		tempo_manager.add_card_tempo(tempo_cost, basic_card, resolve_tick, _active_index)

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
	# Bracing the shield with both hands adds block from its original weight
	block_amount += inventory.get_two_hand_block_bonus(shield)

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

func _is_in_combat() -> bool:
	## Equipment swaps only cost tempo when something can punish them: any
	## living enemy close enough to aggro.
	if not enemy_spawner or not player:
		return false
	for enemy in enemy_spawner.get_living_enemies():
		if enemy.global_position.distance_to(player.global_position) <= enemy.aggro_range:
			return true
	return false

func _on_swap_tempo_spent(cost: int, action: String) -> void:
	## Changing gear mid-fight advances the clock like Basic Block / Wait does.
	## The character panel emits this for every swap; free out of combat.
	if cost <= 0 or not _is_in_combat():
		return
	tempo_manager.add_tempo(cost)
	add_battle_log("%s — %d tempo" % [action, cost], Color(0.85, 0.75, 0.5))

func _on_rack_button_pressed() -> void:
	## Brad's War Rack: free exchange when the cooldown is ready (and the
	## single-two-handed-item rule is met); otherwise a normal paid exchange.
	var inv = player.get_inventory() if player else null
	if not inv or not inv.has_back_rack:
		return
	var free_check: Dictionary = inv.can_rack_exchange(true)
	if free_check["ok"]:
		var result: Dictionary = inv.rack_exchange(true)
		if result["success"]:
			add_battle_log("War Rack: swapped FREE — cards to hand!", Color(1.0, 0.85, 0.4))
	else:
		var result: Dictionary = inv.rack_exchange(false)
		if result["success"]:
			_on_swap_tempo_spent(result["tempo_cost"], "War Rack exchange")
		else:
			add_battle_log("War Rack: %s" % result["reason"], Color(1.0, 0.5, 0.4))
	_update_rack_button()
	_update_block_button_visibility()
	_on_hand_updated()

func _update_rack_button() -> void:
	if not _rack_button:
		return
	var inv = player.get_inventory() if player else null
	if not inv or not inv.has_back_rack:
		_rack_button.visible = false
		return
	_rack_button.visible = true
	var rack_names: String = inv._rack_names(inv.rack_items)
	if inv.rack_cooldown_tempo <= 0:
		_rack_button.text = "Rack FREE"
		_rack_button.tooltip_text = "War Rack: swap your hands with the gear on your back for FREE.\nOn back: %s\nOne side must be a single two-handed item; incoming cards rush to your hand.\n%d tempo cooldown after use. Click while recharging for a normal paid swap." % [rack_names, Inventory.RACK_FREE_SWAP_COOLDOWN]
	else:
		_rack_button.text = "Rack %dT" % inv.rack_cooldown_tempo
		_rack_button.tooltip_text = "War Rack recharging: free swap in %d tempo.\nOn back: %s\nClick to exchange now at normal swap-tempo cost." % [inv.rack_cooldown_tempo, rack_names]

func _update_block_button_visibility() -> void:
	if not _block_button:
		return
	var inventory = player.get_inventory()
	if inventory and inventory.has_shield_equipped():
		var shield = inventory.get_equipped_shield()
		var block_val = shield.armor_bonus if shield.armor_bonus > 0 else 3
		block_val += inventory.get_two_hand_block_bonus(shield)
		_block_button.text = "5T"
		_block_button.tooltip_text = "Raise %s: +%d Armor. Costs 5 tempo." % [shield.item_name, block_val]
		_block_button.visible = true
	else:
		_block_button.visible = false

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

	var manage_btn = Button.new()
	manage_btn.text = "Manage Deck"
	manage_btn.pressed.connect(_open_manage_deck_panel)
	vbox.add_child(manage_btn)

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

# ============================================
# MANAGE DECK (cull / add cards mid-run)
# ============================================

var manage_deck_panel: PanelContainer = null
var _md_deck_list: VBoxContainer = null
var _md_stored_list: VBoxContainer = null
var _md_stones_label: Label = null
var _md_pending_cull: String = ""  # two-click confirm: name of the card armed for culling

func _open_manage_deck_panel() -> void:
	if manage_deck_panel == null:
		_build_manage_deck_panel()
	_md_pending_cull = ""
	manage_deck_panel.visible = true
	_refresh_manage_deck_panel()

func _build_manage_deck_panel() -> void:
	var ui = $UI as CanvasLayer
	manage_deck_panel = PanelContainer.new()
	manage_deck_panel.name = "ManageDeckPanel"
	ui.add_child(manage_deck_panel)
	manage_deck_panel.set_anchors_preset(Control.PRESET_CENTER)
	manage_deck_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	manage_deck_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	manage_deck_panel.custom_minimum_size = Vector2(580, 500)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.97)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.45, 0.25)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	manage_deck_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	manage_deck_panel.add_child(vbox)

	var title = Label.new()
	title.text = "Manage Deck"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	vbox.add_child(title)

	_md_stones_label = Label.new()
	_md_stones_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_md_stones_label.add_theme_font_size_override("font_size", 13)
	_md_stones_label.add_theme_color_override("font_color", Color(0.9, 0.65, 0.35))
	vbox.add_child(_md_stones_label)

	vbox.add_child(HSeparator.new())

	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(columns)

	# Left column: current deck, click to cull.
	var left_box = VBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left_box)
	var left_title = Label.new()
	left_title.text = "Deck — click to cull (1 stone)"
	left_title.add_theme_font_size_override("font_size", 13)
	left_title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.4))
	left_box.add_child(left_title)
	var left_scroll = ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.custom_minimum_size = Vector2(260, 360)
	left_box.add_child(left_scroll)
	_md_deck_list = VBoxContainer.new()
	_md_deck_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(_md_deck_list)

	# Right column: cards carried in the inventory, click to add.
	var right_box = VBoxContainer.new()
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right_box)
	var right_title = Label.new()
	right_title.text = "Cards on you — click to add (to discard)"
	right_title.add_theme_font_size_override("font_size", 13)
	right_title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	right_box.add_child(right_title)
	var right_scroll = ScrollContainer.new()
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.custom_minimum_size = Vector2(260, 360)
	right_box.add_child(right_scroll)
	_md_stored_list = VBoxContainer.new()
	_md_stored_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(_md_stored_list)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): manage_deck_panel.visible = false)
	vbox.add_child(close_btn)

	manage_deck_panel.visible = false

func _refresh_manage_deck_panel() -> void:
	if manage_deck_panel == null or not manage_deck_panel.visible:
		return
	var inv = player.get_inventory()
	_md_stones_label.text = "Culling Stones: %d" % (inv.get_culling_stone_count() if inv else 0)

	for child in _md_deck_list.get_children():
		child.queue_free()
	for child in _md_stored_list.get_children():
		child.queue_free()

	# Left: unique deck cards with counts (same scope as the deck list view).
	var card_counts: Dictionary = {}
	var all_cards: Array = []
	all_cards.append_array(deck_manager.draw_pile)
	all_cards.append_array(deck_manager.hand)
	all_cards.append_array(deck_manager.discard_pile)
	all_cards.append_array(deck_manager.jail_pile)
	for card in all_cards:
		card_counts[card.card_name] = card_counts.get(card.card_name, 0) + 1
	var names = card_counts.keys()
	names.sort()
	for card_name in names:
		var entry = Button.new()
		if _md_pending_cull == card_name:
			entry.text = "Cull %s? (click to confirm)" % card_name
			entry.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
		else:
			entry.text = "%s (%d)" % [card_name, card_counts[card_name]]
			entry.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.flat = true
		entry.add_theme_color_override("font_hover_color", Color(1.0, 0.6, 0.4))
		entry.add_theme_font_size_override("font_size", 14)
		entry.pressed.connect(_on_manage_cull_pressed.bind(card_name))
		_md_deck_list.add_child(entry)

	# Right: cards carried in storage (NOT the town stash).
	var stored_count = inv.get_stored_card_count() if inv else 0
	if stored_count == 0:
		var none = Label.new()
		none.text = "(no cards on you)"
		none.add_theme_font_size_override("font_size", 13)
		none.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_md_stored_list.add_child(none)
	for i in range(stored_count):
		var card = inv.get_stored_card(i)
		if card == null:
			continue
		var entry = Button.new()
		entry.text = card.card_name
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.flat = true
		entry.add_theme_color_override("font_color", Color(0.75, 0.95, 0.75))
		entry.add_theme_color_override("font_hover_color", Color(0.5, 1.0, 0.6))
		entry.add_theme_font_size_override("font_size", 14)
		entry.pressed.connect(_on_manage_add_pressed.bind(i))
		_md_stored_list.add_child(entry)

func _on_manage_cull_pressed(card_name: String) -> void:
	# First click arms the cull, second click on the same entry confirms.
	if _md_pending_cull != card_name:
		_md_pending_cull = card_name
		_refresh_manage_deck_panel()
		return
	_md_pending_cull = ""
	var inv = player.get_inventory()
	if not inv or inv.get_culling_stone_count() <= 0:
		add_battle_log("No Culling Stones left.", Color(1.0, 0.5, 0.4))
		_refresh_manage_deck_panel()
		return
	# Prefer culling an instance the player won't miss mid-fight.
	var target: Card = null
	for pile in [deck_manager.discard_pile, deck_manager.draw_pile, deck_manager.jail_pile, deck_manager.hand]:
		for c in pile:
			if c.card_name == card_name:
				target = c
				break
		if target:
			break
	if target == null or not inv.use_culling_stone():
		_refresh_manage_deck_panel()
		return
	deck_manager.remove_card_from_all_piles(target)
	# Keep the character's card lists in sync, matching the town cull flow.
	if starting_character:
		var pidx = starting_character.purchased_card_ids.find(target.card_id)
		if pidx >= 0:
			starting_character.purchased_card_ids.remove_at(pidx)
		else:
			starting_character.removed_card_ids.append(target.card_id)
	add_battle_log("Culled %s from the deck." % card_name, Color(1.0, 0.6, 0.3))
	update_deck_info()
	if deck_list_visible:
		_populate_deck_list()
	_refresh_manage_deck_panel()

func _on_manage_add_pressed(index: int) -> void:
	var inv = player.get_inventory()
	if not inv:
		return
	var card = inv.get_stored_card(index)
	if card == null:
		return
	if inv.add_card_to_deck(index, deck_manager):
		add_battle_log("Added %s to your discard pile." % card.card_name, Color(0.4, 1.0, 0.5))
		update_deck_info()
		if deck_list_visible:
			_populate_deck_list()
		_refresh_manage_deck_panel()
	elif not deck_manager.can_add_copy(card.card_id):
		add_battle_log("Deck limit: only %d cop%s of %s (%s) allowed." % [
			Card.max_deck_copies(card.card_id),
			"y" if Card.max_deck_copies(card.card_id) == 1 else "ies",
			card.card_name, card.get_rarity_name()], Color(1.0, 0.5, 0.3))

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

func _setup_maintained_icon() -> void:
	## Maintained cards show as one card icon (xN) in the top status row with
	## the other buffs; hover lists each card, click opens the manage panel.
	maintained_icon = MaintainedIconUI.new()
	maintained_icon.name = "MaintainedIcon"
	maintained_icon.visible = false
	maintained_icon.pressed.connect(_on_maintained_list_button_pressed)
	buff_bar.pin_front(maintained_icon)

	# Jailed cards show as one cage icon (xN) in the debuff row; hover lists
	# each jailed card, click opens the jail pile popup.
	jailed_icon = JailedIconUI.new()
	jailed_icon.name = "JailedIcon"
	jailed_icon.visible = false
	jailed_icon.pressed.connect(_on_jail_pile_button_pressed)
	debuff_bar.pin_front(jailed_icon)

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
	var cards = deck_manager.get_maintained_cards()
	if maintained_icon:
		maintained_icon.set_cards(cards)
	if _mana_reserve_tip:
		_mana_reserve_tip.set_cards(cards)
	if maintained_list_visible:
		if cards.size() == 0:
			# Last maintained card gone — close the manage panel too.
			_on_maintained_list_button_pressed()
		else:
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
	# Hug the compact content: no wider than the card below it unless the
	# text itself needs more (the container grows to fit).
	hand_card_preview.custom_minimum_size = Vector2(150, 0)
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
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	vbox.add_child(name_lbl)

	# One compact info line: type · cost · melee/range (dex-proc aware).
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

	var info_row = HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 8)
	vbox.add_child(info_row)

	var type_lbl = Label.new()
	type_lbl.text = card.card_type_name
	type_lbl.add_theme_font_size_override("font_size", 11)
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
	info_row.add_child(type_lbl)

	var cost_lbl = Label.new()
	if card.maintain_cost > 0:
		cost_lbl.text = "%dM %dT · Maint %dM" % [preview_mana, preview_tempo, card.maintain_cost]
	else:
		cost_lbl.text = "%dM %dT" % [preview_mana, preview_tempo]
	cost_lbl.add_theme_font_size_override("font_size", 11)
	if preview_proc:
		cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		cost_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	info_row.add_child(cost_lbl)

	var range_lbl = Label.new()
	range_lbl.add_theme_font_size_override("font_size", 11)
	if card.is_ranged:
		range_lbl.text = card.get_range_display()
		range_lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 0.9))
	else:
		range_lbl.text = "Melee"
		range_lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
	info_row.add_child(range_lbl)

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

	# Instant stack: every ready instant piles under this one card, so list
	# what's actually inside the stack.
	for g in _hand_groups:
		if g["rep"] != card or g["slot"] != HandSlotsScript.INSTANT_SLOT:
			continue
		var stack: Array = g["cards"]
		if stack.size() <= 1:
			break
		var inst_sep = HSeparator.new()
		vbox.add_child(inst_sep)
		var inst_header = Label.new()
		inst_header.text = "In this stack (trigger automatically):"
		inst_header.add_theme_font_size_override("font_size", 12)
		inst_header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
		vbox.add_child(inst_header)
		# Collapse duplicates: one line per distinct instant, with its count.
		var by_name := {}
		var name_order: Array = []
		for icard in stack:
			if not by_name.has(icard.card_name):
				by_name[icard.card_name] = {"card": icard, "count": 0}
				name_order.append(icard.card_name)
			by_name[icard.card_name]["count"] += 1
		for iname in name_order:
			var entry: Dictionary = by_name[iname]
			var line = RichTextLabel.new()
			line.bbcode_enabled = true
			line.fit_content = true
			line.scroll_active = false
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.custom_minimum_size = Vector2(180, 0)
			line.add_theme_font_size_override("normal_font_size", 12)
			line.add_theme_font_size_override("bold_italics_font_size", 12)
			var count_txt: String = (" x%d" % entry["count"]) if entry["count"] > 1 else ""
			line.text = "[b][i]%s[/i][/b]%s: %s" % [iname, count_txt, entry["card"].description]
			vbox.add_child(line)
		break

	# Position popup above the hand area, centered on the hovered card
	var hand_area = $UI/HandArea as PanelContainer
	var card_global_rect = card_ui.get_global_rect()
	var card_center_x = card_global_rect.position.x + card_global_rect.size.x / 2.0

	# Wait a frame for the preview to calculate its size, then position
	await get_tree().process_frame

	# If hover changed while we waited, abort (fixes flickering when scrolling across cards)
	if my_hover_id != _hand_hover_id:
		return

	# RichTextLabel fit_content heights settle a frame late, and the shared
	# panel never shrinks on its own — wait one more frame, then snap the
	# panel to the new content's minimum size before measuring.
	await get_tree().process_frame
	if my_hover_id != _hand_hover_id:
		return
	hand_card_preview.reset_size()

	var preview_width = hand_card_preview.size.x
	var popup_x = card_center_x - preview_width / 2.0

	# Clamp to screen bounds
	var screen_width = get_viewport().get_visible_rect().size.x
	popup_x = clamp(popup_x, 4.0, screen_width - preview_width - 4.0)

	# Place above the HOVERED card's lifted position (hovering raises the card
	# by HOVER_LIFT), not just above the hand area — so the popup never sits
	# on top of the card being read.
	var lifted_card_top = card_global_rect.position.y - CardUI.HOVER_LIFT
	var popup_y = minf(hand_area.global_position.y, lifted_card_top) - hand_card_preview.size.y - 10.0
	popup_y = maxf(popup_y, 4.0)
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

func _setup_hud_icon_bar() -> void:
	## Top-right icon bar replacing the old I/L/H text hints. Buttons open the
	## same windows the keyboard shortcuts do; the EXP and Quest icons carry a
	## yellow dot when there's something to attend to.
	var ui = $UI as CanvasLayer
	hud_icon_bar = HudIconBarScript.new()
	hud_icon_bar.name = "HudIconBar"
	ui.add_child(hud_icon_bar)
	hud_icon_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hud_icon_bar.offset_left = -360.0
	hud_icon_bar.offset_top = 8.0
	hud_icon_bar.offset_right = -8.0
	hud_icon_bar.offset_bottom = 46.0
	hud_icon_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud_icon_bar.alignment = BoxContainer.ALIGNMENT_END
	hud_icon_bar.character_pressed.connect(func(): character_panel.toggle_panel())
	hud_icon_bar.level_pressed.connect(func(): skill_tree_ui.toggle_panel(); _refresh_hud_notifications())
	hud_icon_bar.quest_pressed.connect(_on_hud_quest_pressed)
	hud_icon_bar.help_pressed.connect(_on_hud_help_pressed)
	hud_icon_bar.deck_pressed.connect(_on_deck_list_button_pressed)

func _on_hud_quest_pressed() -> void:
	minimap_tab_ui.open_quest_log()
	_quest_notify = false
	_refresh_hud_notifications()

func _on_hud_help_pressed() -> void:
	if help_panel.visible:
		help_panel.visible = false
		help_panel.closed.emit()
	else:
		help_panel.show_panel(0)

func _skill_tree_has_pending() -> bool:
	## True when the player has banked stat or passive points waiting to be
	## spent from the passives screen.
	if not skill_tree_ui or not player:
		return false
	var stats = player.get_stats()
	if not stats:
		return false
	return stats.unspent_stat_points > 0 or stats.unspent_passive_points > 0

func _refresh_hud_notifications() -> void:
	if not hud_icon_bar:
		return
	hud_icon_bar.set_level_notify(_skill_tree_has_pending())
	hud_icon_bar.set_quest_notify(_quest_notify)

func _on_quest_activity() -> void:
	## A quest was accepted/updated/completed — flag the journal icon.
	_quest_notify = true
	_refresh_hud_notifications()

# Signal-shape adapters (quest signals carry args; the level one carries a level).
func _on_quest_activity_id(_id: String) -> void:
	_on_quest_activity()

func _on_quest_activity_upd(_id: String, _cur: int, _req: int) -> void:
	_on_quest_activity()

func _on_leveled_up_notify(_new_level: int) -> void:
	if skill_tree_ui:
		skill_tree_ui.set_player_level(_new_level)
	_refresh_hud_notifications()

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
	enemy_inspect_ui = EnemyInspectUIScript.new()
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

func _refresh_hand_card_values() -> void:
	## Re-print the stat-adjusted numbers on the hand's card faces (see
	## get_card_vacuum_values) after a buff/stat shift.
	if not hand_container:
		return
	for child in hand_container.get_children():
		if child is CardUI:
			child.update_chance_display()

func select_character(character: CharacterData) -> void:
	current_character = character
	
	player.initialize_character(character)
	deck_manager.connect_player_stats(player.get_stats())
	# Card faces print stat-adjusted numbers for this character (see
	# get_card_vacuum_values); the provider is polled on every card refresh.
	CardUI.value_provider = get_card_vacuum_values

	debuff_bar.connect_manager(player.get_debuff_manager())
	deck_manager.connect_debuff_manager(player.get_debuff_manager())
	player.get_debuff_manager().point_to_prove_triggered.connect(progression_triggers._on_point_to_prove_triggered)
	deck_manager.connect_inventory(player.get_inventory())
	player.connect_deck_to_inventory(deck_manager)
	tempo_manager.initialize(player.get_stats())
	tempo_manager.debuff_manager = player.get_debuff_manager()
	update_tempo_display()
	turn_manager.initialize(player.get_stats(), deck_manager)
	overflow_manager.initialize(player.get_stats())
	deck_manager.connect_overflow_manager(overflow_manager)
	buff_bar.connect_manager(player.get_buff_manager())
	# Standing buffs (strengthen, empower, …) move the numbers printed on the
	# card faces — re-render hand descriptions whenever they shift.
	player.get_buff_manager().buffs_changed.connect(_refresh_hand_card_values)
	manifest_ui.connect_overflow_manager(overflow_manager)
	overflow_ui.connect_overflow_manager(overflow_manager)
	quiver_ui.connect_overflow_manager(overflow_manager)
	player.get_stats().health_changed.connect(_on_player_health_changed)
	player.get_stats().mana_changed.connect(_on_player_mana_changed)
	player.get_stats().armor_changed.connect(_on_player_armor_changed)
	player.get_stats().armor_gained.connect(_on_player_armor_gained)
	player.get_stats().dexterity_proc.connect(_on_dexterity_proc)
	player.get_stats().flash_points_changed.connect(_on_flash_points_changed)
	player.get_stats().brain_points_changed.connect(_on_brain_points_changed)
	player.get_stats().action_points_spent.connect(_on_action_points_spent)
	player.get_stats().movement_flash_threshold_reached.connect(_on_movement_flash_threshold)
	player.get_stats().consecutive_attacks_reached.connect(_on_consecutive_attacks_reached)
	player.get_stats().attack_fully_blocked.connect(_on_attack_fully_blocked)
	player.get_debuff_manager().debuff_removed.connect(_on_player_debuff_removed)
	player.get_stats().armor_broken.connect(_on_player_armor_broken)
	player.get_stats().armor_gained.connect(_on_armor_gained_spiked)
	player.get_stats().curse_of_the_living_shared.connect(_on_curse_of_the_living_shared)
	if player.get_inventory():
		player.get_inventory().gauntlet_world_skill.connect(_on_gauntlet_world_skill)
	_update_flash_button()
	_update_brain_button()
	# The skill tree screen spends the banked level-up stat points.
	skill_tree_ui.player_stats = player.get_stats()
	# The sphere grid checks stat-gated node requirements against the player.
	sphere_grid_ui.player_stats = player.get_stats()
	# Magnetized debuff: wire the pull (emitted each cycle-end) to the handler.
	player.get_debuff_manager().magnetize_pull.connect(func(tiles, _dir): _apply_magnetize_pull(tiles))
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
	# Ring pass 1: bespoke ring procs, counters, and their world-side payloads.
	if player.get_inventory():
		player.get_inventory().custom_ring_fired.connect(_on_custom_ring_fired)
	player.get_stats().marvolo_triggered.connect(_on_marvolo_triggered)
	player.get_stats().shadow_form_ended.connect(_on_shadow_form_ended)
	player.get_buff_manager().buff_applied.connect(_on_player_buff_applied_ring)
	player.get_debuff_manager().debuff_expired.connect(_on_player_debuff_expired)

	character_panel.connect_stats(player.get_stats(), player.get_inventory(), deck_manager, player.get_buff_manager(), player.get_debuff_manager())
	character_panel.swap_tempo_spent.connect(_on_swap_tempo_spent)
	# Every adventurer carries a Return Scroll (right-click it to portal home).
	if player.get_inventory():
		player.get_inventory().ensure_return_scroll()
	# War Rack (Brad): show the swap button and keep its cooldown display live.
	var rack_inv = player.get_inventory()
	if rack_inv:
		rack_inv.rack_changed.connect(_update_rack_button)
	_update_rack_button()
	# Ally paging: the panel's arrows page through everyone currently in play.
	character_panel.set_page_provider(_all_players)


	deck_manager.initialize_deck(character)
	player.get_inventory().apply_equipped_item_card_effects()
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


	# Initialize character skill tree (use character-specific tree if available).
	# Keyed off the preset identity so a renamed character keeps their tree.
	var skill_tree: SkillTreeData
	var tree_base := character.get_base_character()
	if tree_base == "Brad":
		skill_tree = SkillTreeData.create_brad_tree()
	elif tree_base == "Stephen":
		skill_tree = SkillTreeData.create_stephen_tree()
	elif tree_base == "Ryan":
		skill_tree = SkillTreeData.create_ryan_tree()
	elif tree_base == "Cory":
		skill_tree = SkillTreeData.create_cory_tree()
	elif tree_base == "Jeremy":
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
	var _vacated_cell := _player_last_grid_cell
	_player_last_grid_cell = player_cell

	# Elemental Trail Blazers: moving with flash points leaves fire on the vacated tile.
	if _vacated_cell.x >= 0 and _vacated_cell != player_cell:
		_maybe_drop_fire_trail(_vacated_cell)

	# Fire walls (Fire Goblin Shaman): burn the player if they stepped into one.
	_check_fire_walls(player_cell)

	# Stepping off a climbed tree drops the player back to the ground.
	if _climbed_tree_tile.x >= 0 and player_cell != _climbed_tree_tile:
		_clear_climbed_tree()

	# Forest hazards: bear traps / hunters' darts spring on whoever steps on them.
	_trigger_terrain_traps_for(player_cell, player, true)
	# Crops: stepping onto a berry bushel eats it (checks every ally).
	_check_berry_bushels()

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

func _movement_locked() -> bool:
	## While the active character's own action ticks run (card or basic
	## attack), they are glued in place — that is the point of tempo. Cancel
	## un-started queued actions from the tempo bar's queue dropdown to free
	## up sooner; the currently ticking action always finishes.
	return tempo_manager != null and tempo_manager.owner_is_busy(_active_index)

func _notify_movement_locked() -> void:
	add_battle_log("Committed! Your action is still ticking — cancel queued actions (▾ by the tempo bar) to bail out.", Color(1.0, 0.6, 0.3))

func _on_move_confirmed(target_pos: Vector3, spaces: int) -> void:
	if _movement_locked():
		_notify_movement_locked()
		return
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
	if _movement_locked():
		_notify_movement_locked()
		return
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

# ============================================
# SANDBOX MODE
# ============================================

func _setup_sandbox() -> void:
	## Free-play arena: no story enemies spawn, the player gets a fat pool of
	## health/mana to experiment with, a couple of raised platforms give High
	## Ground to play with, and the Sandbox control panel opens.
	# Testing ground: the story-mode mythic equip limit does not apply here.
	if player and player.get_inventory():
		player.get_inventory().enforce_mythic_limit = false
	var start_cell = grid_manager.world_to_grid(player.position)
	# Two raised platforms flanking the start so High Ground is always nearby.
	if dungeon_manager:
		dungeon_manager.build_high_ground(start_cell + Vector2i(5, -1), 1, 1)
		dungeon_manager.build_high_ground(start_cell + Vector2i(-4, 3), 2, 1)
		_sync_dungeon_blocked_tiles()

	_sandbox_refill()

	# Stats aren't inflated in sandbox — instead the character panel (I) gets
	# free-form -/+ stat editing.
	if character_panel:
		character_panel.set_sandbox_stat_edit(true)

	sandbox_ui = SandboxUIScript.new()
	sandbox_ui.name = "SandboxUI"
	add_child(sandbox_ui)
	sandbox_ui.add_card_requested.connect(_on_sandbox_add_card)
	sandbox_ui.add_item_requested.connect(_on_give_item)
	sandbox_ui.spawn_enemy_requested.connect(_on_sandbox_spawn_enemy)
	sandbox_ui.clear_enemies_requested.connect(_on_sandbox_clear_enemies)
	sandbox_ui.refill_requested.connect(_sandbox_refill)
	sandbox_ui.add_ally_requested.connect(_on_sandbox_add_ally)
	sandbox_ui.grant_passive_requested.connect(_on_sandbox_grant_passive)
	sandbox_ui.open()
	add_battle_log("Sandbox mode: use the panel (top-right) to add cards and spawn enemies.", Color(0.7, 0.85, 1.0))

func _sandbox_refill() -> void:
	## Top health/mana back up WITHOUT touching the character's real stats —
	## sandbox uses the same pools as the story; tweak them via the +/- stat
	## controls in the character panel instead.
	var s = player.get_stats()
	if s:
		s.current_health = s.max_health
		s.current_mana = s.max_mana
		s.health_changed.emit(s.current_health, s.max_health)
		s.mana_changed.emit(s.current_mana, s.max_mana)

func _on_sandbox_add_card(card_id: String) -> void:
	var card = deck_manager._create_card_from_id(card_id)
	if card == null:
		add_battle_log("Sandbox: couldn't create '%s'." % card_id, Color(1.0, 0.5, 0.4))
		return
	deck_manager.hand.append(card)
	deck_manager.hand_updated.emit()
	add_battle_log("Sandbox: added %s to hand." % card.card_name, Color(0.5, 1.0, 0.6))

func _on_sandbox_add_ally(char_name: String) -> void:
	## Spawn a second character as an ally so ally-targeting cards can be tested.
	## Reuses the whole co-op (Player 2) pipeline: own stats, deck, figure, and
	## TAB control switching.
	if _p2_player:
		add_battle_log("Sandbox: an ally is already on the field.", Color(1.0, 0.7, 0.4))
		return
	var chosen: CharacterData = null
	for c in CharacterData.get_all_characters():
		if c.character_name == char_name:
			chosen = c
			break
	if chosen == null:
		add_battle_log("Sandbox: unknown character '%s'." % char_name, Color(1.0, 0.5, 0.4))
		return

	player2_character = chosen
	is_multiplayer = true
	_p1_player = player
	_p1_deck_manager = deck_manager
	player2_ui._initialize_player2()

	# Same wiring the normal co-op path does in _ready().
	if _p2_player:
		_p2_player.tile_reached.connect(_on_player_tile_reached)
		_p2_player.move_completed.connect(_on_player_move_completed)
		enemy_spawner.players = [_p1_player, _p2_player]
		# Cover reactions: each partner can mitigate the other's damage.
		var sb_p2s = _p2_player.get_stats()
		if sb_p2s:
			sb_p2s.damage_taken.connect(_on_ally_damage_taken.bind(_p2_player))
		var sb_p1s = _p1_player.get_stats()
		if sb_p1s:
			sb_p1s.damage_taken.connect(_on_ally_damage_taken.bind(_p1_player))
	if _p2_deck_manager:
		_p2_deck_manager.card_discarded.connect(_animate_card_discard)
		_p2_deck_manager.reaction_triggered.connect(_animate_card_instant)
		_p2_deck_manager.card_erased.connect(_animate_card_erase)
	if _p2_player and _p2_player.get_inventory():
		_p2_player.get_inventory().ring_triggered.connect(_on_ring_triggered_visual.bind(_p2_player))
	_setup_co_op_defeat()

	# Ally spawns topped up, with their real stats untouched (like the player).
	var s2 = _p2_player.get_stats() if _p2_player else null
	if s2:
		s2.current_health = s2.max_health
		s2.current_mana = s2.max_mana
		s2.health_changed.emit(s2.current_health, s2.max_health)
		s2.mana_changed.emit(s2.current_mana, s2.max_mana)

	if sandbox_ui and sandbox_ui.has_method("mark_ally_added"):
		sandbox_ui.mark_ally_added()
	add_battle_log("Sandbox: %s joined as your ally! (TAB to switch control)" % char_name, Color(0.5, 1.0, 0.6))

func _on_sandbox_grant_passive(option) -> void:
	## Grant a skill-tree passive to the ACTIVE player so it can be tested.
	if option == null:
		return
	progression_triggers._apply_skill_tree_option(option)
	if character_panel:
		character_panel.update_display()
	add_battle_log("Sandbox: granted passive '%s'." % option.name, Color(0.9, 0.7, 0.2))

func _on_sandbox_spawn_enemy(enemy_type: int) -> void:
	## Spawn the chosen enemy on a free tile a few cells in front of the player.
	var base_cell = grid_manager.world_to_grid(player.position)
	var spot := _sandbox_free_cell(base_cell)
	var world = grid_manager.grid_to_world(spot)
	if dungeon_manager:
		world.y = dungeon_manager.get_elevation_world_y(spot)
	var enemy = enemy_spawner.spawn_enemy(enemy_type, world)
	_update_enemy_count()
	_refresh_unit_tracker()
	if enemy:
		add_battle_log("Sandbox: spawned %s." % enemy.enemy_name, Color(1.0, 0.7, 0.4))

func _sandbox_free_cell(base: Vector2i) -> Vector2i:
	## Find an unoccupied floor tile near the player, spiralling outward.
	var occupied: Dictionary = {}
	for e in enemy_spawner.get_living_enemies():
		occupied[grid_manager.world_to_grid(e.position)] = true
	occupied[grid_manager.world_to_grid(player.position)] = true
	for r in range(2, 8):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var c := base + Vector2i(dx, dz)
				if occupied.has(c):
					continue
				if c.x < 0 or c.x >= grid_manager.grid_width or c.y < 0 or c.y >= grid_manager.grid_height:
					continue
				if player.blocked_tiles.has(c):
					continue
				return c
	return base + Vector2i(3, 0)

func _on_sandbox_clear_enemies() -> void:
	enemy_spawner.clear_enemies()
	_update_enemy_count()
	_refresh_unit_tracker()
	add_battle_log("Sandbox: cleared all enemies.", Color(0.8, 0.8, 0.85))

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

# ---- Ally interaction (right-click menu + trade) ----

func _show_ally_menu(ally: Player, screen_pos: Vector2) -> void:
	## Small context menu shown when right-clicking the co-op partner.
	if _ally_menu == null:
		_ally_menu = PopupMenu.new()
		_ally_menu.add_item("Trade", 0)
		_ally_menu.id_pressed.connect(_on_ally_menu_pressed)
		get_node("UI").add_child(_ally_menu)
	_ally_menu_target = ally
	_ally_menu.position = Vector2i(screen_pos)
	_ally_menu.popup()

func _on_ally_menu_pressed(id: int) -> void:
	if id == 0 and _ally_menu_target and is_instance_valid(_ally_menu_target):
		_open_trade_ui(player, _ally_menu_target)

func _open_trade_ui(a: Player, b: Player) -> void:
	if trade_ui == null:
		trade_ui = preload("res://scripts/ui/trade_ui.gd").new()
		get_node("UI").add_child(trade_ui)
	trade_ui.open_trade(a, b)

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
	# Linked debuff: each partner is the other's "nearest ally" for damage sharing.
	if _p1_player.get_debuff_manager():
		_p1_player.get_debuff_manager().linked_ally = _p2_player
	if _p2_player.get_debuff_manager():
		_p2_player.get_debuff_manager().linked_ally = _p1_player
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
	WorldText.crisp(tag)
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

func show_hand_multi_picker(prompt: String, on_done: Callable) -> void:
	## Multi-select hand picker: toggle any number of cards, then press Done.
	## Calls on_done(Array[Card]) with the selection (possibly empty). Resolves
	## immediately with [] when the hand is empty.
	if deck_manager.hand.is_empty():
		on_done.call([])
		return
	var ui = $UI as CanvasLayer
	var overlay := ColorRect.new()
	overlay.name = "HandMultiPicker"
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
	pstyle.border_color = Color(0.6, 0.5, 0.3)
	pstyle.set_corner_radius_all(8)
	pstyle.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", pstyle)
	overlay.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.custom_minimum_size = Vector2(300, 0)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = prompt
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	vbox.add_child(title)
	var picked: Array = []
	var count_lbl := Label.new()
	count_lbl.text = "0 selected"
	count_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(count_lbl)
	var rows_scroll := ScrollContainer.new()
	rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows_scroll.custom_minimum_size = Vector2(300, minf(320.0, deck_manager.hand.size() * 40.0))
	vbox.add_child(rows_scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_scroll.add_child(rows)
	for c in deck_manager.hand:
		var b := Button.new()
		b.toggle_mode = true
		b.text = "%s  (%dm/%dt)" % [c.card_name, c.mana_cost, c.get_burden_tempo_cost()]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var cc = c
		b.toggled.connect(func(on: bool):
			if on:
				picked.append(cc)
			else:
				picked.erase(cc)
			count_lbl.text = "%d selected" % picked.size())
		rows.add_child(b)
	var done := Button.new()
	done.text = "Done"
	done.custom_minimum_size = Vector2(120, 34)
	done.pressed.connect(func():
		overlay.queue_free()
		on_done.call(picked))
	vbox.add_child(done)

func show_hand_card_picker(prompt: String, on_pick: Callable, exclude: Card = null, on_cancel: Callable = Callable()) -> void:
	## Reusable hand-card picker: presents the cards in hand (minus `exclude`) and
	## calls on_pick(chosen_card) with the selection. Auto-resolves when there are
	## 0 or 1 candidates, so callers don't have to special-case those. Pass
	## `on_cancel` when the flow must resume after a Cancel (Defensive Sacrifice
	## holds a paused tree — a silent Cancel would hard-lock it). The overlay
	## runs PROCESS_MODE_ALWAYS so it stays live under a paused tree.
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
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
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
	cancel.pressed.connect(func():
		overlay.queue_free()
		if on_cancel.is_valid():
			on_cancel.call())
	vbox.add_child(cancel)

var _ds_prompt_active: bool = false  # Defensive Sacrifice: one prompt at a time

func offer_defensive_sacrifice(attacker, player_node, dmg: int, dmgr, bmgr, dmg_type: int) -> bool:
	## Abjurers Cane: an enemy attack is about to land. If a Defensive
	## Sacrifice sits in hand (with something else to give up), pause the
	## battle and offer the choice. Returns true when main takes ownership of
	## the hit; false lets the enemy apply it normally. A second attack in the
	## same tick lands normally while a prompt is open.
	if _ds_prompt_active or dmg <= 0 or not deck_manager or player_node != player:
		return false
	var ds: Card = null
	for ds_c in deck_manager.hand:
		if ds_c and ds_c.card_id == "defensive_sacrifice":
			ds = ds_c
			break
	if ds == null or deck_manager.hand.size() < 2:
		return false
	_ds_prompt_active = true
	get_tree().paused = true
	_show_defensive_sacrifice_prompt(dmg,
		func():  # YES — pick the card to give up.
			show_hand_card_picker("Defensive Sacrifice — discard which card?",
				func(chosen):
					if chosen == null or not deck_manager.discard_card_from_hand(chosen):
						_ds_resume(attacker, player_node, dmg, dmgr, bmgr, dmg_type)
						return
					deck_manager.spend_reaction_from_hand(ds)
					var ds_stats = player.get_stats()
					if ds_stats:
						ds_stats.gain_mana(10)
					var ds_half: int = floori(dmg / 2.0)
					add_battle_log("Defensive Sacrifice! The blow is halved to %d — +10 mana." % ds_half, Color(0.6, 0.75, 0.95))
					_ds_resume(attacker, player_node, ds_half, dmgr, bmgr, dmg_type),
				ds,
				func():  # picker cancelled — that's declining: full hit, card kept.
					_ds_resume(attacker, player_node, dmg, dmgr, bmgr, dmg_type)),
		func():  # NO — the card stays in hand, the blow lands whole.
			_ds_resume(attacker, player_node, dmg, dmgr, bmgr, dmg_type))
	return true

func _ds_resume(attacker, player_node, dmg: int, dmgr, bmgr, dmg_type: int) -> void:
	## Unpause and land the (possibly halved) deferred hit, then run the
	## enemy's post-hit riders exactly as the direct path would have.
	get_tree().paused = false
	_ds_prompt_active = false
	if is_instance_valid(player_node) and player_node.has_method("get_stats") and player_node.get_stats():
		player_node.get_stats().take_damage(dmg, dmgr, bmgr, dmg_type)
	if is_instance_valid(attacker) and attacker.has_method("_finish_player_hit") \
			and is_instance_valid(player_node):
		attacker._finish_player_hit(player_node)

func _show_defensive_sacrifice_prompt(dmg: int, on_yes: Callable, on_no: Callable) -> void:
	## A yes/no overlay that stays live while the tree is paused.
	var ui = $UI as CanvasLayer
	var overlay := ColorRect.new()
	overlay.name = "DefensiveSacrificePrompt"
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	ui.add_child(overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.12, 0.13, 0.18, 1.0)
	pstyle.set_border_width_all(2)
	pstyle.border_color = Color(0.5, 0.6, 0.8)
	pstyle.set_corner_radius_all(8)
	pstyle.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", pstyle)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.custom_minimum_size = Vector2(320, 0)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Defensive Sacrifice: discard a card to halve %d incoming damage and gain 10 mana?" % dmg
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(320, 0)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var yes := Button.new()
	yes.text = "Sacrifice"
	yes.custom_minimum_size = Vector2(150, 36)
	yes.pressed.connect(func():
		overlay.queue_free()
		on_yes.call())
	row.add_child(yes)
	var no := Button.new()
	no.text = "Take the hit"
	no.custom_minimum_size = Vector2(150, 36)
	no.pressed.connect(func():
		overlay.queue_free()
		on_no.call())
	row.add_child(no)
	vbox.add_child(row)

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
	# Timed statuses (stun, frozen, blind...) tick on RAW tempo so durations
	# like "3 tempo" work; per-cycle effects still run on the 5-tempo turn.
	for tick_p in _all_players():
		if not is_instance_valid(tick_p):
			continue
		var tick_dm = tick_p.get_debuff_manager()
		if tick_dm:
			tick_dm.advance_time(amount)
		var tick_bm = tick_p.get_buff_manager()
		if tick_bm:
			tick_bm.advance_time(amount)
		var tick_stats = tick_p.get_stats()
		if tick_stats:
			tick_stats.advance_status_tempo(amount)

	# Sync enemy positions so they don't stack on each other
	_sync_occupied_tiles()
	# Summons are ordinary units to enemy target selection
	enemy_spawner.summons = _frankensteins + _summoned_worms + _wolves \
		+ _skeletons + _spirit_bows + _clones \
		+ ([_penguin] if (_penguin != null and is_instance_valid(_penguin)) else [])
	# Each enemy manages its own action counter independently
	enemy_spawner.on_tempo_advanced(amount)

	# Mirror each enemy's action progress onto its tracker-side yellow bar.
	if unit_tracker:
		unit_tracker.update_tempo_bars()

	# Summoned Bull Worms move/attack after the enemies act.
	_update_summoned_worms()
	# Frankensteins Monsters act on their own tempo cadence.
	_update_frankensteins(amount)
	# Elemental Trail Blazers: fire spots burn enemies then fade.
	_update_fire_spots(amount)
	# Chewbaccas Bandolier: casings explode on contact or when their timer runs out.
	_update_bullet_casings(amount)
	# Sanguine the penguin waddles after the wielder and pecks on his own clock.
	_update_penguin(amount)
	# Wolves hunt on their own cadence; smoke clouds shelter then disperse.
	_update_wolves(amount)
	_update_smoke_zones(amount)
	# Bone-arrow skeletons sprint at whatever their quiver's kill left behind.
	_update_skeletons(amount)
	# Spirit bows stalk and shoot; budded turrets just shoot.
	_update_spirit_bows(amount)
	# Elemental Weaver: refresh the pollination flag enemies read while ticking.
	_update_element_pollination()
	# Reaction Rod: keep Grounding's Shock discount current on the card face.
	_update_grounding_discount()
	# Crops: catch an ally who ended up standing on a bushel (P2 movement
	# routes through the shared tile handler reading the active player only).
	_check_berry_bushels()
	# Territorial Mark: refresh which enemies stand in the blue smoke.
	_update_mark_zones(amount)
	# Close is Favored: any enemy inside melee reach springs the trap.
	_check_melee_range_reactions()
	# Draupnir duplicates fight on their own cadence.
	_update_clones(amount)

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
	# Walls/pits/barricades/trees this enemy must not walk through. Without this
	# a freshly-spawned enemy has an empty list and clips through structures.
	if grid_manager:
		enemy.blocked_tiles = _enemy_blocked_tiles()
	# Smooth terrain-following Y (elevation, pillars)
	enemy.ground_y_provider = Callable(self, "_desired_ground_y")
	# Snap initial Y position to terrain elevation
	if dungeon_manager and grid_manager:
		var enemy_cell = grid_manager.world_to_grid(enemy.position)
		var elev_y = dungeon_manager.get_elevation_world_y(enemy_cell)
		enemy.position.y = elev_y
		enemy.target_position.y = elev_y

	# Olorin offers a one-time word of counsel on the player's first story battle.
	if olorin:
		olorin.show_combat_intro()

var _disarm_mastery_applying: bool = false  # Guard against recursive disarm
var _wither_applying: bool = false  # Guard against recursive wither
var _laced_arrow_applying: bool = false  # Guard against recursive laced arrow
var _polymorph_firing: bool = false  # Guard: Polymorph's own debuff must not re-trigger it
var _reapers_taking_firing: bool = false  # Guard: Reaper's Taking's damage must not re-trigger it
var _enemy_melee_state: Dictionary = {}  # Territorial Death: tracks enemy melee range state

func _on_enemy_debuff_applied(enemy: Enemy, debuff_name: String, value: int) -> void:
	progression_triggers._trigger_skill_tree_on_debuff_applied(enemy, debuff_name, value)
	# Ring pass: feed the poison/burn accumulators and the Circlet checklist,
	# then the Harnessed Sun amplifies burns (+2) — guarded so the bonus
	# never amplifies itself (it still counts toward the 25-burn total).
	if player and player.get_inventory():
		player.get_inventory().on_player_debuff_applied(debuff_name, value)
		if debuff_name == "burn" and not _harnessed_reentry:
			for hs_r in player.get_inventory().equipped_rings:
				if hs_r != null and hs_r.item_name == "Harnessed Sun":
					_harnessed_reentry = true
					enemy.apply_debuff("burn", 2)
					_harnessed_reentry = false
					break
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
	# Spell weapons pass: weapon passives that watch every debuff you land.
	var sw_inv = player.get_inventory() if player else null
	if sw_inv and "equipped_weapons" in sw_inv:
		for sw_w in sw_inv.equipped_weapons:
			if sw_w == null:
				continue
			# Elemental Weaver: applying Burn, Shock or Cold stings the target
			# for +X per charge applied.
			if sw_w.elemental_charge_damage > 0 and debuff_name in ["burn", "shock", "cold"] \
					and is_instance_valid(enemy) and not enemy.is_dead:
				var ew_dmg: int = sw_w.elemental_charge_damage * maxi(value, 1)
				enemy.take_damage(ew_dmg, true)
				add_battle_log("Elemental Weaver: +%d damage (%d charge(s) woven)" % [ew_dmg, maxi(value, 1)], Color(0.7, 0.5, 1.0))
			# Wand of the Phoenix Feather: each Burn occasion singes the wielder
			# for 1 — riders like Laced Arrow / Wither / Harnessed Sun amplify
			# the SAME occasion, so their guarded re-entries don't singe again.
			if sw_w.burn_backlash_self > 0 and debuff_name == "burn" \
					and not _harnessed_reentry and not _laced_arrow_applying and not _wither_applying:
				var pb_dm = player.get_debuff_manager()
				if pb_dm:
					var pb_burn = Debuff.create(Debuff.DebuffType.BURN, sw_w.burn_backlash_self, 15)
					pb_burn.source_name = sw_w.item_name
					pb_dm.apply_debuff(pb_burn)
					add_battle_log("The phoenix feather singes you: %d Burn" % sw_w.burn_backlash_self, Color(1.0, 0.5, 0.2))
	# Circe's Wand: landing a 5th distinct debuff springs Polymorph from hand.
	if not _polymorph_firing and deck_manager and is_instance_valid(enemy) and not enemy.is_dead \
			and enemy.polymorph_tempo <= 0 and Card.count_debuff_kinds(enemy) >= 5:
		var pm_card = deck_manager.trigger_one_reaction_jailed("on_enemy_fifth_debuff", 25)
		if pm_card:
			_polymorph_firing = true
			pm_card.execute(null, player.get_stats(), deck_manager, 0.0, 0.0, player.get_buff_manager())
			enemy.apply_debuff("polymorph", 5)
			_polymorph_firing = false
			add_battle_log("Polymorph! %s is a pig for 5 tempo!" % enemy.enemy_name, Color(1.0, 0.6, 0.8))

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
	# Reaper's Taking (Reaper Scythe): an enemy dropping below a quarter within
	# 5 squares pulls the reaper to them — edge-detected on the crossing hit.
	if _reapers_taking_firing or enemy == null or not is_instance_valid(enemy) \
			or enemy.is_dead or enemy.max_health <= 0 or not deck_manager or not grid_manager:
		return
	var rt_after: int = enemy.current_health
	var rt_before: int = rt_after + damage
	var rt_quarter: float = enemy.max_health * 0.25
	if rt_after <= 0 or float(rt_after) >= rt_quarter or float(rt_before) < rt_quarter:
		return
	if grid_manager.get_distance_in_cells(player.position, enemy.position) > 5:
		return
	var rt_cards = deck_manager.trigger_reactions("on_enemy_low_health_nearby")
	for rt_card in rt_cards:
		_reapers_taking_firing = true
		rt_card.execute(null, player.get_stats(), deck_manager, 0.0, 0.0, player.get_buff_manager())
		# Step through the veil to the victim's side: nearest free adjacent tile.
		var rt_cell: Vector2i = grid_manager.world_to_grid(enemy.position)
		for rt_off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var rt_c: Vector2i = rt_cell + rt_off
			if not (rt_c in player.blocked_tiles):
				if player.has_method("blink_to"):
					player.blink_to(grid_manager.grid_to_world(rt_c))
				break
		var rt_dmg: int = 35 if (rt_card.granted_by_item and rt_card.granted_by_item.item_level >= 3) else 20
		enemy.take_damage(rt_dmg, true)
		add_battle_log("Reaper's Taking! The scythe crosses the field — %d damage to %s!" % [rt_dmg, enemy.enemy_name], Color(0.4, 0.7, 1.0))
		_reapers_taking_firing = false

func _on_enemy_attacked_player(enemy: Enemy) -> void:
	progression_triggers._trigger_skill_tree_brad_on_attacked(enemy)
	progression_triggers._trigger_skill_tree_stephen_on_attacked(enemy)
	progression_triggers._trigger_skill_tree_jeremy_on_enemy_attacked(enemy)

func _on_enemy_killed(enemy: Enemy) -> void:
	print("[MAIN] Enemy killed: %s (XP: %d)" % [enemy.enemy_name, enemy.xp_reward])
	# Snapshot a corpse where the enemy fell so ITS ALIVE!!!!! can raise it. The
	# enemy is still valid here (it frees a moment later), so its position is good.
	if grid_manager and is_instance_valid(enemy):
		_corpses.append({"cell": grid_manager.world_to_grid(enemy.position), "position": enemy.position})
		_garmr_death_stack(enemy.position)
	# Everyone in the party earns the kill's XP, so the co-op partner's level
	# progresses alongside the active player's.
	for p in _all_players():
		if is_instance_valid(p) and p.get_stats():
			p.get_stats().gain_xp(enemy.xp_reward)
	# Bestiary: record kills per character (feeds the compendium and any future
	# monster-intent reveals gated on "defeated before").
	if current_character and not current_character.defeated_monster_ids.has(enemy.enemy_name):
		current_character.defeated_monster_ids.append(enemy.enemy_name)
	_update_enemy_count()
	_refresh_unit_tracker()
	# Sphere grid passive triggers for kills
	progression_triggers._trigger_sphere_passives("on_kill", {"target": enemy})
	# Cory: Eat — heal on kill
	progression_triggers._trigger_skill_tree_cory_on_kill(enemy)
	# Quest tracking
	if quest_manager:
		quest_manager.on_enemy_killed(enemy.enemy_name)

	# City loop: every kill adds habitat resources to the satchel headed home,
	# and ticks any brewing calamity's countdown (STORY.md §6).
	if not sandbox_mode and current_character:
		var zone := CityBridge.zone_for_area(
			dungeon_manager.interior_kind if dungeon_manager else "", current_world_level)
		var loot_tier: String = enemy_spawner.get_loot_tier(enemy.enemy_type)
		var elite := loot_tier == DropRates.TIER_ELITE or loot_tier == DropRates.TIER_BOSS
		var gained := CityBridge.add_kill_to_satchel(player_progression, zone, elite)
		if not gained.is_empty():
			add_battle_log("Satchel: %s" % CityBridge.format_resources(gained), Color(0.75, 0.7, 0.5))
		if CalamitySystem.on_kill(player_progression):
			_announce_calamity()

	# First-room tutorial: the very first rat felled in the story carries the
	# Bladed Doughnut (injected into its loot in _on_loot_dropped, which fires
	# right after this handler).
	if current_world_level == 1 and olorin \
			and not olorin.has_seen("item_levels_intro") \
			and enemy.enemy_type in [Enemy.EnemyType.WERERAT, Enemy.EnemyType.ARCHER_RAT]:
		_pending_doughnut_drop = true

	# Act-mythic pity ("mythic creep"): every story kill raises the chance of
	# the act's near-guaranteed mythic until it drops, then the act returns to
	# its per-tier baseline (act 1: capped at that one mythic forever). The
	# scripted doughnut kill is skipped so the tutorial drop stays scripted.
	if current_character and not _pending_doughnut_drop:
		var tier: String = enemy_spawner.get_loot_tier(enemy.enemy_type)
		if DropRates.roll_act_mythic_kill(current_character, current_world_level, tier):
			var pool = ItemData.get_items_of_rarity(ItemData.Rarity.MYTHIC)
			_pending_mythic_item = pool[randi() % pool.size()]
			if dungeon_manager and current_world_level == 1:
				dungeon_manager.block_act1_mythics = true

	# Return any queued cards targeting this dead enemy back to the player's hand
	_return_queued_cards_for_dead_target(enemy)

func _on_all_enemies_defeated() -> void:
	_clear_summoned_worms()
	_clear_frankensteins()
	_clear_fire_spots()
	_clear_bullet_casings()
	_clear_penguin()
	_clear_wolves()
	_smoke_zones.clear()
	# Bone-arrow skeletons and Draupnir duplicates deliberately survive the
	# wave — "lives until killed": one cumulative journey, no battle resets.
	_clear_spirit_bows()
	_clear_mark_zones()
	# Spell weapons: no element remap or pollination survives the wave, and
	# unpicked berries wilt with it.
	Card.active_element_remap = ""
	Card.element_pollination_active = false
	_clear_berry_bushels()
	# (The Wrist Rocket's banked crit is cumulative — one journey, no resets.)
	print("[MAIN] Wave complete! Press 'Spawn Wave' for more enemies.")
	_refresh_unit_tracker()

func _announce_calamity() -> void:
	## A calamity just struck the city — Olorin's flute sounds the alarm
	## (the signal item he gave the player when the city was founded).
	var warning := CalamitySystem.warning_text(player_progression)
	add_battle_log("A shrill flute-note pierces the air! %s" % warning, Color(1.0, 0.4, 0.35))
	print("[MAIN] Calamity struck: %s" % warning)
	if olorin:
		olorin.show_tutorial(
			"calamity_strike",
			"The Flute Cries Out",
			[
				"A single piercing note cuts through the din of battle — Olorin's flute, and it does not sing for nothing.",
				"\"%s\"" % warning,
				"Return to town swiftly and the garrison will not stand alone. Linger, and the city must weather it without you.",
			],
			true  # the flute sounds for every calamity, not just the first
		)

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
	match kind:
		"bear":
			dmg = BEAR_TRAP_DAMAGE
			if not is_player and _is_bear(unit):
				dmg = BEAR_TRAP_BEAR_DAMAGE
			label = "bear trap"
		"web":
			dmg = WEB_TRAP_DAMAGE
			label = "spiked web"
		"wall_dart":
			dmg = WALL_DART_DAMAGE
			label = "wall dart"
		_:
			dmg = DART_TRAP_DAMAGE
			label = "hunters' darts"

	if is_player:
		var stats = player.get_stats()
		if stats:
			var dmgr = player.get_debuff_manager() if player.has_method("get_debuff_manager") else null
			var bmgr = player.get_buff_manager() if player.has_method("get_buff_manager") else null
			stats.take_damage(dmg, dmgr, bmgr)
			# Spiked webs snare whoever blunders in.
			if kind == "web" and dmgr:
				dmgr.apply_debuff(Debuff.create_slowed(2, "Spiked Web"))
		add_battle_log("A %s snaps shut — %d damage!" % [label, dmg], Color(0.9, 0.5, 0.2))
	elif is_instance_valid(unit):
		# Hermes Boots: trap damage against enemies is amplified — the whole
		# point of dancing them into the hazards.
		var tstats = player.get_stats() if player else null
		if tstats and tstats.equipment_trap_damage_percent > 0.0:
			dmg = floori(dmg * (1.0 + tstats.equipment_trap_damage_percent / 100.0))
		unit.take_damage(dmg, false)
		if kind == "web" and unit.has_method("apply_debuff"):
			unit.apply_debuff("root", 25)
		add_battle_log("%s hits a %s for %d!" % [unit.enemy_name, label, dmg], Color(0.8, 0.7, 0.4))

	_animate_trap_sprung(trap)

func _is_bear(enemy) -> bool:
	if not is_instance_valid(enemy):
		return false
	if enemy.enemy_type == Enemy.EnemyType.MINI_BEAR or enemy.enemy_type == Enemy.EnemyType.LARGE_BEAR:
		return true
	return "Bear" in enemy.enemy_name

func _animate_trap_sprung(trap: Dictionary) -> void:
	## Visual feedback: bear traps darken (snapped shut), dart traps and wall
	## shooters flash red, webs collapse to a torn grey.
	var node = trap.get("node")
	if not node or not is_instance_valid(node):
		return
	var tint: Color
	match trap["kind"]:
		"dart", "wall_dart":
			tint = Color(0.35, 0.1, 0.1)
		"web":
			tint = Color(0.30, 0.30, 0.32)
		_:
			tint = Color(0.08, 0.08, 0.09)
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
	# Swirling mist flourish on the character
	player.show_level_up()
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

func _on_ally_leveled_up(new_level: int) -> void:
	## The co-op partner leveled up: flourish + log. (Sphere/skill-tree rewards
	## stay tied to Player 1's progression UIs.)
	if _p2_player and is_instance_valid(_p2_player):
		_p2_player.show_level_up()
	var ally_name: String = player2_character.character_name if player2_character else "Your ally"
	add_battle_log("%s reached level %d!" % [ally_name, new_level], Color(1.0, 0.85, 0.4))
	print("[MAIN] Ally leveled up to %d" % new_level)

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
		# Phoenix Grace (stack-oriented buff): each rescue burns one charge.
		var pg_bm = player.get_buff_manager()
		var pg = pg_bm.get_buff(Buff.BuffType.PHOENIX_GRACE) if pg_bm else null
		if pg:
			var pg_heal = int(max_hp * 0.8) - current
			if pg_heal > 0:
				stats.heal(pg_heal)
			var pg_nearest: Enemy = null
			var pg_dist = INF
			for pe in enemy_spawner.get_living_enemies():
				var pd = (pe.position - player.position).length()
				if pd < pg_dist:
					pg_dist = pd
					pg_nearest = pe
			if pg_nearest:
				pg_nearest.apply_debuff("burn", 5)
			if pg.use_charge():
				pg_bm.remove_buff(Buff.BuffType.PHOENIX_GRACE)
			add_battle_log("Phoenix Grace! Healed to 80%% HP!", Color(1.0, 0.5, 0.2))
			return
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
	_update_mana_regen_indicator()

func _on_player_armor_gained(_amount: int) -> void:
	## Armour gained from any source — pop the overhead armour icon.
	if player and player.has_method("show_armor_gained"):
		player.show_armor_gained()

func _on_player_armor_changed(current: int) -> void:
	if player_armor_label:
		player_armor_label.visible = false
	if _armor_shield_label:
		_armor_shield_label.text = "%d" % current

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
	if stats and _level_badge_label:
		_level_badge_label.text = "Lvl: %d" % stats.current_level

func _on_flash_points_changed(_current: int, _max_points: int) -> void:
	_update_flash_button()

func _on_flash_move_toggled(pressed: bool) -> void:
	var stats = player.get_stats() if player else null
	if stats:
		stats.flash_movement_enabled = pressed
	if pressed:
		add_battle_log("Flash movement ON — moving spends flash points instead of tempo.", Color(1.0, 0.9, 0.4))
	else:
		add_battle_log("Flash movement off — moving costs tempo.", Color(1.0, 0.9, 0.4))
	_update_flash_button()

func _on_flash_block_pressed() -> void:
	var stats = player.get_stats() if player else null
	if not stats:
		return
	# Flash Cut keystone: the Sidestep spend becomes an attack instead of armor.
	if stats.keystone_flash_strike:
		_flash_strike(stats)
		return
	var parry_cost := stats.get_flash_block_cost()
	if stats.spend_flash_for_block():
		add_battle_log("Sidestep! -%d flash, +%d block." % [
			parry_cost, PlayerStats.FLASH_BLOCK_ARMOR], Color(1.0, 0.9, 0.4))
	else:
		add_battle_log("Not enough flash points (%d needed)." % parry_cost, Color(1.0, 0.5, 0.5))

func _flash_strike(stats) -> void:
	## Flash Cut: spend Sidestep flash to strike the nearest enemy in reach.
	var nearby = enemy_spawner.get_enemies_in_radius(player.position, 2.5)
	if nearby.is_empty():
		add_battle_log("Flash Cut: no enemy in reach!", Color(1.0, 0.6, 0.3))
		return
	var target = nearby[0]
	var closest_dist = INF
	for enemy in nearby:
		var diff = player.position - enemy.position
		var dist = Vector3(diff.x, 0, diff.z).length()
		if dist < closest_dist:
			closest_dist = dist
			target = enemy
	if not stats.spend_flash_for_strike():
		add_battle_log("Not enough flash points (%d needed)." % stats.get_flash_block_cost(), Color(1.0, 0.5, 0.5))
		return
	if player.has_method("play_animation"):
		player.play_animation("attack_slash", _facing_dir_toward(target))
	target.take_damage(PlayerStats.FLASH_STRIKE_DAMAGE, true)
	add_battle_log("Flash Cut! -%d flash, %d damage to %s." % [
		stats.get_flash_block_cost(), PlayerStats.FLASH_STRIKE_DAMAGE, target.enemy_name], Color(1.0, 0.9, 0.4))

func _try_arcane_echo(stats) -> void:
	## Arcane Echo keystone: a spell cast has an INT/3% chance to deal INT/2
	## bonus damage to a random living enemy.
	if not stats or not stats.keystone_int_spell_proc:
		return
	if randf() * 100.0 >= stats.get_int_spell_proc_chance():
		return
	var dmg = stats.get_int_spell_proc_damage()
	if dmg <= 0:
		return
	var enemies = enemy_spawner.get_living_enemies()
	if enemies.is_empty():
		return
	var target = enemies[randi() % enemies.size()]
	if not (target and target.has_method("take_damage")):
		return
	target.take_damage(dmg, true)
	add_battle_log("Arcane Echo! %d bonus damage to %s." % [dmg, target.enemy_name], Color(0.6, 0.4, 1.0))

func _on_brain_draw_pressed() -> void:
	var stats = player.get_stats() if player else null
	if not stats:
		return
	var cost = stats.get_next_brain_draw_cost()
	if stats.current_brain_points < cost:
		add_battle_log("Not enough brain points (%d needed)." % cost, Color(1.0, 0.5, 0.5))
		return
	var debuff_mgr = player.get_debuff_manager()
	if debuff_mgr and debuff_mgr.has_method("can_draw_cards") and not debuff_mgr.can_draw_cards():
		add_battle_log("Cuffed — cannot draw cards.", Color(1.0, 0.5, 0.5))
		return
	if deck_manager.hand.size() >= deck_manager.get_hand_cap():
		add_battle_log("Hand is full.", Color(1.0, 0.5, 0.5))
		return
	if deck_manager.get_draw_pile_size() == 0 and deck_manager.get_discard_pile_size() == 0:
		add_battle_log("No cards left to draw.", Color(1.0, 0.5, 0.5))
		return
	if stats.spend_brain_for_draw():
		deck_manager.draw_card()
		add_battle_log("Insight! -%d brain, drew a card (next: %d)." % [
			cost, stats.get_next_brain_draw_cost()], Color(0.85, 0.6, 0.9))
		# Umbral Eclipse: brain-point draws restore flash.
		if player and player.get_inventory():
			for ue_w in player.get_inventory().equipped_weapons:
				if ue_w and ue_w.insight_flash_restore > 0:
					stats.gain_flash_points(ue_w.insight_flash_restore)
					add_battle_log("%s: +%d flash" % [ue_w.item_name, ue_w.insight_flash_restore], Color(0.6, 0.6, 0.9))
					break
		update_peaked_display()
		_update_brain_button()

func _on_brain_peek_pressed() -> void:
	var stats = player.get_stats() if player else null
	if not stats:
		return
	var cost = stats.get_next_brain_peek_cost()
	if stats.current_brain_points < cost:
		add_battle_log("Not enough brain points (%d needed)." % cost, Color(1.0, 0.5, 0.5))
		return
	if deck_manager.brain_peek_depth >= deck_manager.get_draw_pile_size():
		add_battle_log("The draw pile is already fully revealed.", Color(1.0, 0.5, 0.5))
		return
	if stats.spend_brain_for_peek():
		deck_manager.brain_peek_depth += 1
		var seen = deck_manager.get_brain_peeked_cards()
		if seen.size() > 0:
			add_battle_log("Peek! -%d brain — card %d down is %s (next peek: %d)." % [
				cost, seen.size(), seen[seen.size() - 1].card_name,
				stats.get_next_brain_peek_cost()], Color(0.85, 0.6, 0.9))
		update_peaked_display()
		_update_brain_button()

func _on_brain_points_changed(_current: int, _max_points: int) -> void:
	_update_brain_button()

func _update_brain_button() -> void:
	if not _brain_button:
		return
	var stats = player.get_stats() if player else null
	if not stats:
		return
	var pool: int = stats.current_brain_points
	_brain_button.text = "%d" % pool
	_brain_button.tooltip_text = "Brain points: %d / %d (1 per WIS, refresh every %d cycles).\nRefills in %d tempo." % [
		pool, stats.get_max_brain_points(), PlayerStats.BRAIN_REFRESH_CYCLES,
		tempo_manager.get_tempo_until_brain_refresh() if tempo_manager else 0]
	# Spend buttons fade while unaffordable (still clickable — the click explains).
	if _brain_peek_button:
		var pk = stats.get_next_brain_peek_cost()
		_brain_peek_button.modulate.a = 1.0 if pool >= pk else 0.45
		_brain_peek_button.tooltip_text = "Peek: spend %d brain to reveal the next unseen card of your draw pile.\nEach peek this window costs %d more." % [
			pk, PlayerStats.BRAIN_PEEK_COST_STEP]
	if _brain_draw_button:
		var dc = stats.get_next_brain_draw_cost()
		# The corner badge wears the NEXT draw's price so the player always
		# knows where they are on the ladder; the glyph keeps the full button.
		if _brain_draw_cost_label:
			_brain_draw_cost_label.text = "%d" % dc
		_brain_draw_button.modulate.a = 1.0 if pool >= dc else 0.45
		_brain_draw_button.tooltip_text = "Insight: spend %d brain to draw a card.\nEach draw this window costs more (5, 10, 15, 20, 25...)." % dc

func _on_flash_proc_pressed() -> void:
	var stats = player.get_stats() if player else null
	if not stats:
		return
	if stats.spend_flash_for_proc_tick():
		add_battle_log("Quick hands! -%d flash, %d attacks to proc." % [
			PlayerStats.FLASH_COST_PROC_TICK, stats.get_attacks_until_proc()], Color(1.0, 0.9, 0.4))
		_update_attack_button_text()
	else:
		add_battle_log("Not enough flash points (%d needed)." % PlayerStats.FLASH_COST_PROC_TICK, Color(1.0, 0.5, 0.5))

func _update_flash_button() -> void:
	if not _flash_button:
		return
	var stats = player.get_stats() if player else null
	if not stats:
		return
	var pool: int = stats.current_flash_points
	_flash_button.text = "%d" % pool
	_flash_button.tooltip_text = "Flash points: %d / %d (refresh every %d cycles).\nRefills in %d tempo." % [
		pool, stats.get_max_flash_points(), PlayerStats.FLASH_REFRESH_CYCLES,
		tempo_manager.get_tempo_until_flash_refresh() if tempo_manager else 0]
	# Spend buttons fade while unaffordable (still clickable — the click explains).
	if _flash_move_button:
		_flash_move_button.set_pressed_no_signal(stats.flash_movement_enabled)
		_flash_move_button.modulate.a = 1.0 if pool >= PlayerStats.FLASH_COST_MOVE else 0.45
		if _flash_move_sparkle:
			_flash_move_sparkle.active = stats.flash_movement_enabled
		_flash_move_button.tooltip_text = "Flash movement: %s.\nWhile on, each tile moved spends %d flash point instead of tempo." % [
			"ON" if stats.flash_movement_enabled else "off", PlayerStats.FLASH_COST_MOVE]
	if _flash_block_button:
		_flash_block_button.modulate.a = 1.0 if pool >= PlayerStats.FLASH_COST_BLOCK else 0.45
		if stats.keystone_flash_strike:
			_flash_block_button.tooltip_text = "Flash Cut: spend %d flash to strike the nearest enemy for %d damage." % [
				PlayerStats.FLASH_COST_BLOCK, PlayerStats.FLASH_STRIKE_DAMAGE]
		else:
			_flash_block_button.tooltip_text = "Sidestep: spend %d flash for %d block." % [
				PlayerStats.FLASH_COST_BLOCK, PlayerStats.FLASH_BLOCK_ARMOR]
	if _flash_proc_button:
		_flash_proc_button.modulate.a = 1.0 if pool >= PlayerStats.FLASH_COST_PROC_TICK else 0.45
		_flash_proc_button.tooltip_text = "Quick hands: spend %d flash to advance the attack-speed counter by 1 tick." % PlayerStats.FLASH_COST_PROC_TICK

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
	_update_maintained_button()
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
	# Drawing consumes revealed peek knowledge — keep the NEXT display honest.
	update_peaked_display()

	# Cory: Regrowth — draw 4 when hand is empty
	if deck_manager.hand.is_empty():
		progression_triggers._trigger_skill_tree_cory_on_hand_empty()

	# Quick Study (WIS keystone): auto-draw 1 when the hand empties. draw_card()
	# does NOT touch turn_manager.tempo_until_draw, so the timed draw is untouched.
	# A failed draw (empty deck) emits no hand_updated, so this can't loop.
	var _qs_stats = player.get_stats() if player else null
	if _qs_stats and _qs_stats.keystone_wis_empty_draw and deck_manager.hand.is_empty():
		deck_manager.draw_card()

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

	# Identical cards collapse into one lettered stack; assign/keep slot letters
	# so playing a card never re-letters the rest, and build the render groups.
	_build_hand_groups(debuff_mgr)

	var group_count = _hand_groups.size()
	if group_count == 0:
		if selected_card_index >= 0:
			selected_card_index = -1
		update_deck_info()
		update_selected_display()
		update_card_highlights()
		return

	# Which card instances are newly drawn this update (for the slide-in anim).
	var new_card_set := {}
	for i in new_indices:
		if i < deck_manager.hand.size():
			new_card_set[deck_manager.hand[i].get_instance_id()] = true

	var card_width: float = 150.0
	var card_height: float = 210.0
	var container_width: float = hand_container.size.x
	if container_width <= 0:
		container_width = 1080.0  # fallback

	# Overlapping fan: cards sit ~45% over their neighbour at rest, and as the
	# hand grows past what fits in the band they compress further (more cards =
	# more overlap), always staying inside the container between the action
	# buttons (left) and the deck/maintained panels (right).
	var ideal_spacing: float = card_width * 0.55  # step between card centres at rest
	var spacing: float
	if group_count <= 1:
		spacing = 0.0
	else:
		var fit_spacing: float = (container_width - card_width) / float(group_count - 1)
		spacing = min(ideal_spacing, fit_spacing)  # never wider than the fan; tighten to fit

	# Center the hand
	var total_hand_width = card_width + spacing * max(group_count - 1, 0)
	var start_x = (container_width - total_hand_width) / 2.0
	if start_x < 0.0:
		start_x = 0.0
	var card_y = (hand_container.size.y - card_height) / 2.0
	if card_y < 0:
		card_y = 0.0

	# Fan rotation: slight arc for cards in hand
	var max_fan_angle: float = 3.0  # Max degrees for outermost card
	if group_count <= 1:
		max_fan_angle = 0.0

	# Draw pile position for draw animation origin (bottom-left of screen)
	var draw_origin = _get_draw_pile_pos()

	var dex_proc_active = deck_manager.next_attack_half_tempo or deck_manager.next_attack_mana_discount > 0
	var pocket_knife = false
	if dex_proc_active:
		var hand_inv = player.get_inventory()
		pocket_knife = hand_inv and hand_inv.has_pocket_knife_equipped()

	var anim_ordinal := 0
	for g in range(group_count):
		var group: Dictionary = _hand_groups[g]
		var rep: Card = group["rep"]
		var count: int = group["cards"].size()
		var rep_hand_index: int = deck_manager.hand.find(rep)

		var card_ui = CardUIScene.instantiate()
		hand_container.add_child(card_ui)
		# Debuff hexed/locked display keys off the card's real hand index.
		card_ui.setup(rep, rep_hand_index, debuff_mgr, dex_proc_active, pocket_knife)
		card_ui.set_stack_depth(count)
		# The instant stack has no play key — its badge reads AUTO instead.
		var badge_letter: String = "" if group["slot"] == HandSlotsScript.INSTANT_SLOT else _slot_letter(group["slot"])
		card_ui.set_keybind_badge(badge_letter, count, rep.is_slotted())
		group["card_ui"] = card_ui

		var final_pos = Vector2(start_x + g * spacing, card_y)

		# Fan rotation: arc from left to right
		var fan_t = 0.0
		if group_count > 1:
			fan_t = float(g) / float(group_count - 1) * 2.0 - 1.0  # -1..1
		var fan_angle = fan_t * max_fan_angle
		card_ui.set_fan_rotation(fan_angle)

		card_ui.z_index = g
		card_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if new_card_set.has(rep.get_instance_id()):
			# New card: animate sliding in from draw pile area
			card_ui.position = final_pos  # Set base for store
			card_ui.store_base_position()
			var delay = anim_ordinal * 0.08
			anim_ordinal += 1
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

# ---- Persistent hand-slot / stacking layer ----

func _slot_letter(slot: int) -> String:
	return HandSlotsScript.letter(slot)

func _build_hand_groups(debuff_mgr = null) -> void:
	## Reconcile the persistent slot map against the current hand, then build the
	## rendered view (one entry per occupied slot, ordered by slot index so cards
	## keep their left-to-right position as others are played).
	_hand_slots.reconcile(deck_manager.hand)
	var locked_idx: int = -1
	if debuff_mgr and debuff_mgr.has_method("get_locked_card_index"):
		locked_idx = debuff_mgr.get_locked_card_index()
	_hand_groups = _hand_slots.build_groups(deck_manager.hand, locked_idx)
	for g in _hand_groups:
		g["card_ui"] = null

func _select_slot(slot: int) -> void:
	## Route a card key press to the card occupying that lettered slot.
	for g in _hand_groups:
		if g["slot"] == slot:
			select_card(deck_manager.hand.find(g["rep"]))
			return
	# No card bound to that key — leave the current selection untouched.

func _wasd_step(dir: Vector2) -> void:
	## Move the active player one grid cell in a camera-relative direction.
	## `dir` is (right, forward) in view space: (0,1)=W, (0,-1)=S, (-1,0)=A,
	## (1,0)=D. It's projected onto the ground using the camera yaw, then snapped
	## to the nearest cardinal grid axis (movement is Manhattan — no diagonals).
	## `player` already tracks the active co-op character (see _switch_active_player).
	if player == null or not is_instance_valid(player):
		return
	if player.is_moving:
		return  # one hop at a time; tap again once the step lands
	if not grid_manager:
		return
	if _movement_locked():
		_notify_movement_locked()
		return

	# Camera ground basis: forward is where the camera looks (−offset on XZ),
	# right is forward rotated so +X is screen-right at yaw 0. The yaw is
	# quantized to the nearest 90° first (the camera itself settles there, but
	# mid-drag or scripted angles must not scramble the key→direction map),
	# then a tiny bias breaks exact-diagonal ties deterministically.
	var quantized_yaw := snappedf(_camera_yaw, PI / 2.0) + 0.0001
	var forward := Vector2(-sin(quantized_yaw), -cos(quantized_yaw))  # (x, z)
	var right := Vector2(-forward.y, forward.x)
	var world_dir := right * dir.x + forward * dir.y  # (x, z) on the ground

	# Snap to the dominant grid axis so a move is always one clean cell.
	var cell_delta: Vector2i
	if absf(world_dir.x) >= absf(world_dir.y):
		cell_delta = Vector2i(int(signf(world_dir.x)), 0)
	else:
		cell_delta = Vector2i(0, int(signf(world_dir.y)))
	if cell_delta == Vector2i.ZERO:
		return

	var target_cell := grid_manager.world_to_grid(player.position) + cell_delta
	var target_world := grid_manager.grid_to_world(target_cell)
	player.move_to_grid(target_world, 1)

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

func _on_non_play_discard(_card: Card) -> void:
	## Ladder Work (Ryan): count cards that reach the discard pile by means
	## other than being played; the count feeds next cycle's opening strike.
	var stats = player.get_stats() if player else null
	if stats and stats.has_skill_tree_passive("ladder_work"):
		stats.st_ladder_discard_count += 1
	# Abjurers Cane: every true discard raises the guard.
	if stats and player.get_inventory():
		for ac_w in player.get_inventory().equipped_weapons:
			if ac_w != null and ac_w.discard_gain_block > 0:
				stats.add_armor(ac_w.discard_gain_block)
				add_battle_log("Abjurers Cane: +%d block" % ac_w.discard_gain_block, Color(0.6, 0.75, 0.95))

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
		"improvised_ammo_blast":
			# Wrist Rocket: the discarded shell pops for 4 on the nearest enemy
			# and banks +10% crit for Improvised Ammo (stacks, battle-scoped).
			var ia_stats = player.get_stats() if player else null
			if ia_stats:
				ia_stats.improvised_ammo_crit_bonus += 10.0
				add_battle_log("Improvised Ammo sharpens: +%.0f%% crit, forever." % ia_stats.improvised_ammo_crit_bonus, Color(0.8, 0.7, 0.5))
			if enemy_spawner and player:
				var ia_near = _nearest_enemy_to(player.position, enemy_spawner.get_living_enemies())
				if ia_near:
					ia_near.take_damage(4, true)
					add_battle_log("The discarded shell pops! %s takes 4." % ia_near.enemy_name, Color(0.8, 0.7, 0.5))
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
					deck_manager.non_play_discard.emit(discarded)
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
	# Ring of Thomas the Train Tracks rides every shuffle.
	if player and player.get_inventory():
		player.get_inventory().on_deck_shuffled()

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
		"Staggered (10)": debuff = Debuff.create(Debuff.DebuffType.STAGGERED, 3, -1)
		"Drain (2)": debuff = Debuff.create(Debuff.DebuffType.DRAIN, 2, 3)
		"Weighted (1)": debuff = Debuff.create(Debuff.DebuffType.WEIGHTED, 3, -1)
		"Hexed (20)": debuff = Debuff.create(Debuff.DebuffType.HEXED, 20, 3)
		"Locked": debuff = Debuff.create(Debuff.DebuffType.LOCKED, 0, 2)
		"Rooted": debuff = Debuff.create(Debuff.DebuffType.ROOTED, 0, 2)
		"Tethered (3)":
			debuff = Debuff.create(Debuff.DebuffType.TETHERED, 0, 15)
			debuff_mgr.set_tether_origin(player.position)
		"Magnetized (1)": debuff = Debuff.create(Debuff.DebuffType.MAGNETIZED, 1, 3)
		"Linked (25)": debuff = Debuff.create(Debuff.DebuffType.LINKED, 0, 15)
		"Clumsy (30)": debuff = Debuff.create(Debuff.DebuffType.CLUMSY, 3, -1)
		"Vulnerable (25)": debuff = Debuff.create(Debuff.DebuffType.VULNERABLE, 25, 3)
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
			buff = Buff.create_blessed(1, 3, "Test")
		"Fortify":
			buff = Buff.create_fortify(15, "Test")
		"Enlightened (25%, 3)":
			buff = Buff.create_enlightened(25, 3, "Test")
		"Strengthen (+3, 3)":
			buff = Buff.create_strengthen(3, 3, "Test")
		"Bolster (+2, 3)":
			buff = Buff.create_bolster(2, 3, "Test")
		"Haste (+1)":
			buff = Buff.create_haste(1, 3, "Test")
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

		# Sphere-grid "Arm/Cyc" nodes: raw armor each cycle (no block-card bonuses).
		if regen_stats and regen_stats.sphere_bonus_armor_per_cycle > 0:
			regen_stats.current_armor += regen_stats.sphere_bonus_armor_per_cycle
			regen_stats.armor_changed.emit(regen_stats.current_armor)
			regen_stats.armor_gained.emit(regen_stats.sphere_bonus_armor_per_cycle)

		# Buff cycle-start effects (REGEN heal, FOCUSED mana, BLESSED draws, SMITH armor)
		if buff_mgr:
			var buff_result = buff_mgr.process_turn_start()
			if buff_result["extra_draws"] > 0:
				for d in range(buff_result["extra_draws"]):
					deck_manager.attempt_draw()

		# Debuff cycle-start effects (BURN damage, POISON, DRAIN, SHOCKED)
		if debuff_mgr:
			var debuff_result = debuff_mgr.process_turn_start()
			# Shocked: arc the accumulated damage to nearby allies (within 2 tiles).
			var ally_dmg: int = debuff_result.get("ally_damage", 0)
			if ally_dmg > 0:
				for ally in _all_players():
					if ally == player or not is_instance_valid(ally):
						continue
					var shock_diff = player.position - ally.position
					if Vector3(shock_diff.x, 0, shock_diff.z).length() <= grid_manager.grid_size * 2.5 \
							and ally.has_method("get_stats") and ally.get_stats():
						ally.get_stats().take_damage(ally_dmg, ally.get_debuff_manager(), ally.get_buff_manager())
						add_battle_log("Shocked arcs %d damage to an ally!" % ally_dmg, Color(1.0, 0.9, 0.3))

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

	# Helm per-cycle passives (Horned Nasal auto-purge, Mane void-resistance aura)
	_helm_on_cycle_passives()
	# Shield per-cycle passives (Vanguard's Regen, Spiked Shield's Thorns)
	_shield_on_cycle_passives()
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
		# Halo: heal allies within its AOE (3 tiles of the caster). The caster
		# always heals; a partner must be inside the radius.
		for ally in _all_players():
			if not is_instance_valid(ally) or not ally.get_stats():
				continue
			var halo_diff = ally.position - player.position
			if ally != player and Vector3(halo_diff.x, 0, halo_diff.z).length() > 3.0:
				continue
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
			# Self-damage is FLAT — your own INT doesn't sharpen the blast in
			# your hand. (The discard leg that hits an ENEMY stays INT-scaled.)
			var self_damage = card.damage
			if stats:
				stats.take_damage(self_damage)
			deck_manager.hand.remove_at(i)
			deck_manager.discard_pile.append(card)
			deck_manager.non_play_discard.emit(card)
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
				mana_regen_bonus += 10.0
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
					debuff_mgr.apply_debuff(Debuff.create_slowed(2, card.card_name))

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
			deck_manager.non_play_discard.emit(card)
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
			# Heal ALL allies — every party member, not just the card holder.
			var stats = player.get_stats()
			var heal_amt = card.heal_amount
			if stats:
				heal_amt = stats.get_effective_heal_amount(card.heal_amount)
				add_battle_log("Healthy Bliss heals all allies for %d!" % heal_amt, Color(0.4, 1.0, 0.5))
			for ally in _all_players():
				if not is_instance_valid(ally):
					continue
				var ally_stats = ally.get_stats()
				if ally_stats:
					ally_stats.heal(heal_amt)
			# Discard the card
			deck_manager.hand.remove_at(i)
			deck_manager.discard_pile.append(card)
			deck_manager.non_play_discard.emit(card)
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
		tt_stats.max_mana = max(10, tt_stats.max_mana - 30)
		tt_stats.adjust_temp_hand(-2)

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
	_update_mana_regen_indicator()
	# Keep the "refills in N tempo" tooltips on the point pools current.
	_update_flash_button()
	_update_brain_button()

func update_tempo_display() -> void:
	if tempo_label:
		tempo_label.text = "Tempo: %d/%d" % [tempo_manager.get_tempo(), tempo_manager.get_threshold()]
	if tempo_bar:
		tempo_bar.max_value = tempo_manager.get_threshold()
		tempo_bar.value = tempo_manager.get_tempo()
func update_deck_info() -> void:
	_update_draw_label()
	if discard_label:
		discard_label.text = "%d" % deck_manager.get_discard_pile_size()
	if _discard_pile_btn:
		_discard_pile_btn.tooltip_text = "Discard pile: %d card(s)" % deck_manager.get_discard_pile_size()
	if jailed_icon:
		jailed_icon.set_cards(deck_manager.jail_pile)
	_update_maintained_button()
	_refresh_pile_popup_if_open()

func _update_draw_label() -> void:
	var tempo_until = turn_manager.get_tempo_until_draw()
	if draw_label:
		# The small number is how many tempo until the next draw.
		draw_label.text = "%d" % int(tempo_until)
	if _draw_pile_btn:
		_draw_pile_btn.tooltip_text = "Draw pile: %d card(s)\nNext draw in %d tempo" % [deck_manager.get_draw_pile_size(), int(tempo_until)]
	if _hand_info_popup and _hand_info_popup.visible:
		_refresh_hand_info_popup()

func _toggle_hand_info_popup() -> void:
	if not _hand_info_popup:
		return
	if _hand_info_popup.visible:
		_hand_info_popup.visible = false
		return
	_refresh_hand_info_popup()
	_hand_info_popup.visible = true
	# Open to the right of the ⓘ button, clamped onto the screen.
	await get_tree().process_frame  # let the panel size itself to fresh content
	if not _hand_info_popup.visible:
		return
	var btn_rect = _hand_info_btn.get_global_rect()
	var pos = btn_rect.position + Vector2(btn_rect.size.x + 8, -_hand_info_popup.size.y / 2.0)
	var screen = get_viewport().get_visible_rect().size
	pos.x = clampf(pos.x, 8.0, screen.x - _hand_info_popup.size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, screen.y - _hand_info_popup.size.y - 8.0)
	_hand_info_popup.global_position = pos

func _refresh_hand_info_popup() -> void:
	if not _hand_info_vbox:
		return
	for child in _hand_info_vbox.get_children():
		child.queue_free()

	var stats = player.get_stats() if player else null
	var max_hand = stats.hand_size if stats else 0
	var current_hand = deck_manager.hand.size() if deck_manager else 0

	var title = Label.new()
	title.text = "Hand"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.45, 0.7, 1.0))
	_hand_info_vbox.add_child(title)

	var size_line = Label.new()
	size_line.text = "Current hand: %d / %d max" % [current_hand, max_hand]
	size_line.add_theme_font_size_override("font_size", 12)
	var over_max = current_hand > max_hand
	size_line.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3) if over_max else Color(0.85, 0.85, 0.9))
	_hand_info_vbox.add_child(size_line)

	var overflow_title = Label.new()
	overflow_title.text = "Overflow effects:"
	overflow_title.add_theme_font_size_override("font_size", 12)
	overflow_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	_hand_info_vbox.add_child(overflow_title)

	var effects: Array = overflow_manager.overflow_effects if overflow_manager else []
	if effects.is_empty():
		var none = Label.new()
		none.text = "  None active"
		none.add_theme_font_size_override("font_size", 11)
		none.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		_hand_info_vbox.add_child(none)
	else:
		for effect in effects:
			var line = Label.new()
			var source = " — %s" % effect.source_name if effect.source_name != "" else ""
			line.text = "  %s%s" % [effect.get_display_text(), source]
			line.add_theme_font_size_override("font_size", 11)
			line.add_theme_color_override("font_color", Color(0.95, 0.75, 0.4))
			_hand_info_vbox.add_child(line)

## The predictable damage a basic attack would deal right now: baseline + STR
## (via get_effective_physical_damage) + Weighted Strikes. Transient bonuses
## (dex proc stores, Strengthen, crits) are excluded — they resolve on swing.
func _get_basic_attack_display_damage() -> int:
	var stats = player.get_stats()
	var damage: int = stats.get_basic_attack_damage()
	if stats.keystone_str_weight_basic:
		var inv = player.get_inventory()
		if inv:
			damage += inv.get_single_hand_weight_damage_bonus()
	return damage

func _update_attack_button_text() -> void:
	if _attack_button:
		var proc_count = player.get_stats().get_attacks_until_proc()
		var proc_active = deck_manager.next_attack_half_tempo

		if _attack_damage_label:
			_attack_damage_label.text = str(_get_basic_attack_display_damage())
		if proc_active:
			var proc_tempo = 5 / 2  # Halved
			var btn_inv = player.get_inventory()
			if btn_inv and btn_inv.has_pocket_knife_equipped():
				proc_tempo = maxi(0, proc_tempo - 2)
			_attack_tempo_label.text = "%dT (PROC)" % proc_tempo
		else:
			_attack_tempo_label.text = "5T (%d)" % proc_count

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
			if _attack_tempo_label:
				_attack_tempo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
		else:
			# Clear custom styles — revert to default theme
			_attack_button.remove_theme_stylebox_override("normal")
			_attack_button.remove_theme_stylebox_override("hover")
			if _attack_tempo_label:
				_attack_tempo_label.remove_theme_color_override("font_color")

func update_selected_display() -> void:
	# Selection is now shown via golden border on the card — hide the text label
	if selected_label:
		selected_label.visible = false

func update_peaked_display() -> void:
	if not peaked_label:
		return
	# Brain-point peeks reveal the top N draw-pile cards; the overflow PEAK
	# mode reveals just the next one. Brain knowledge supersedes it when present.
	var names: Array[String] = []
	for c in deck_manager.get_brain_peeked_cards():
		names.append(c.card_name)
	if names.is_empty():
		var peaked = deck_manager.get_peaked_card()
		if peaked and deck_manager.current_overflow_mode == DeckManager.OverflowMode.PEAK:
			names.append(peaked.card_name)
	if names.is_empty():
		peaked_label.visible = false
	else:
		peaked_label.text = "NEXT: %s" % " → ".join(names)
		peaked_label.visible = true

func update_card_highlights() -> void:
	# Highlight the stack that contains the selected card.
	var sel_card: Card = null
	if selected_card_index >= 0 and selected_card_index < deck_manager.hand.size():
		sel_card = deck_manager.hand[selected_card_index]
	for g in _hand_groups:
		var card_ui = g["card_ui"]
		if card_ui and is_instance_valid(card_ui):
			card_ui.set_selected(sel_card != null and sel_card in g["cards"])

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
		# Sphere grid "Range +X" nodes
		if st_stats and st_stats.sphere_bonus_range > 0:
			effective_range += st_stats.sphere_bonus_range
		# Helm on-self range (Dragon Skull/Monocle) + 20/20 maintain
		effective_range += _helm_range_bonus(card)
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

	if not player.get_stats():
		return 0
	var buff_mgr = player.get_buff_manager()
	var is_ranged_attack = card.is_ranged and card.card_type == Card.CardType.ATTACK

	# High Ground is the one position-dependent flat the vacuum number skips;
	# feed it through the shared pipeline so Cursed still reduces it.
	var high_ground := 0
	if is_ranged_attack and _has_high_ground(player.position, target_enemy):
		high_ground = 4

	# Full player-side pipeline, shared with the card-face numbers.
	var total_damage = _card_player_damage(card, high_ground)

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


# Block cards whose _execute hardcodes the armor amount instead of reading
# the block fields — the display must match what add_armor actually gets.
const BLOCK_AMOUNT_OVERRIDES := {"hold_the_line": 5, "vengeful_shield": 5}

# Block cards whose _execute reads base_block (not block), so they miss the
# play-time Harnessed Power block bonus.
const BASE_BLOCK_CARDS := ["bob_and_weave", "fortify_alliance", "communal_donation", "shield_ready"]


func _card_player_damage(card: Card, extra_flat: int = 0) -> int:
	## The player-side damage pipeline for one card: every deterministic
	## stat / equipment / passive / keystone / standing-buff term, mirroring
	## Card.execute() and the play-time mods. Position- and enemy-dependent
	## terms are excluded; the hover preview passes them via extra_flat /
	## adds them on top. Shared by get_card_vacuum_values and
	## calculate_damage_preview so the two never drift apart.
	# Absorb Essence is defined as a flat 1 to everything — its payoff scales
	# through Energy Ball instead, so no player amplification applies here.
	if card.card_id == "absorb_essence":
		return 1

	var stats = player.get_stats()
	var buff_mgr = player.get_buff_manager()
	var debuff_mgr = player.get_debuff_manager()
	var on_self = card.get_on_self_bonus()

	var total = card.base_damage + card.bonus_damage + on_self["damage"] + extra_flat

	# Quivers and other ranged equipment.
	if card.is_ranged and stats.ranged_damage_bonus > 0:
		total += stats.ranged_damage_bonus
	# Deadeye Form keystone: ranged attacks scale with DEX instead of STR
	# (the physical pipeline adds STR/2 downstream, so swap in the delta).
	if card.is_ranged and stats.keystone_dex_ranged:
		total += floori(stats.dexterity / 2.0) - stats.get_strength_damage_bonus()
	# Killing Rhythm keystone: the armed flat DEX bonus lands on the next
	# attack (peek, don't consume).
	total += stats.pending_dex_bonus_damage
	# Tighten String charges: +6 on ranged attacks.
	if buff_mgr and buff_mgr.tighten_string_charges > 0 and card.is_ranged:
		total += 6
	# Harnessed Power: +30% of base with 2 or fewer cards in hand.
	var hp_mult = progression_triggers._get_jeremy_harnessed_power_multiplier()
	if hp_mult > 1.0:
		total += floori(card.base_damage * (hp_mult - 1.0))

	# Stat scaling by school: INT spell pipeline for SPELL cards, STR physical
	# (strength, enchantments, sphere, two-handed grip) for everything else.
	if card.school == Card.CardSchool.SPELL:
		total = stats.get_effective_spell_damage(total)
	else:
		total = stats.get_effective_physical_damage(total)

	# Standing buffs.
	if stats.is_empowered():
		total += stats.empower_damage_bonus
	if buff_mgr:
		total += buff_mgr.get_strengthen_bonus()
	# Swing for the Fences: heavy swings (tempo > 4) land the tempo again.
	if stats.has_skill_tree_passive("swing_for_the_fences") and card.tempo_cost > 4:
		total += card.tempo_cost
	# Ladder Work: banked discards cash in on the cycle's first attack.
	if stats.has_skill_tree_passive("ladder_work") and stats.st_ladder_banked > 0:
		total += stats.st_ladder_banked * 2

	# Cursed debuff: percentage reduction, applied last like the pipeline.
	if debuff_mgr:
		var reduction_pct = debuff_mgr.get_damage_reduction_percent()
		if reduction_pct > 0.0:
			total = max(1, floori(total * (1.0 - reduction_pct)))
	# Quick Shot: 2 base + HALF of everything on top (mirrors its _execute).
	if card.card_id == "quick_shot":
		total = card.base_damage + floori((total - card.base_damage) / 2.0)
	return max(0, total)


func get_card_vacuum_values(card: Card) -> Dictionary:
	## Effective card numbers for the current character "in a vacuum": base
	## value + every deterministic player-side term — stats, equipment,
	## passives, keystones, standing buffs/debuffs — with no enemy- or
	## position-specific modifiers (those stay on the hover preview, see
	## calculate_damage_preview). Feeds the numbers printed on the card face.
	## Returns effective values plus the base token each one replaces.
	var out := {}
	if not player or not is_instance_valid(player) or not player.is_inside_tree():
		return out
	var stats = player.get_stats()
	if not stats:
		return out
	var buff_mgr = player.get_buff_manager()
	var on_self = card.get_on_self_bonus()
	var hp_mult = progression_triggers._get_jeremy_harnessed_power_multiplier()

	# Damage.
	if card.card_type == Card.CardType.ATTACK and card.base_damage > 0:
		out["damage"] = _card_player_damage(card)
		out["damage_base"] = card.base_damage

	# Block — mirrors PlayerStats.add_armor without applying it, including
	# the per-card quirks (hardcoded amounts, base_block readers).
	var block_base: int
	if BLOCK_AMOUNT_OVERRIDES.has(card.card_id):
		block_base = BLOCK_AMOUNT_OVERRIDES[card.card_id]
	elif card.card_id in BASE_BLOCK_CARDS:
		block_base = card.base_block
	else:
		block_base = card.block if card.block > 0 else card.base_block
	if block_base > 0:
		var total_block = block_base + on_self["block"]
		# Harnessed Power's block leg only reaches cards whose _execute
		# reads the live block field.
		if hp_mult > 1.0 and not BLOCK_AMOUNT_OVERRIDES.has(card.card_id) \
				and card.card_id not in BASE_BLOCK_CARDS:
			total_block += floori(card.base_block * (hp_mult - 1.0))
		total_block += stats.enchantment_block_bonus + stats.sphere_bonus_block
		# Bolster is consumed by exactly one card's armor pipeline.
		if card.card_id == "smith_thy_soul" and buff_mgr:
			total_block += buff_mgr.get_bolster_bonus()
		if stats.has_skill_tree_passive("sword_specialist") \
				and player.get_inventory() and player.get_inventory().has_only_swords_equipped():
			total_block = floori(total_block * 1.25)
		out["block"] = total_block
		out["block_base"] = block_base

	# Heal — the full heal() pipeline: on-self item bonus, Harnessed Power's
	# heal leg, Blood Libation stacks, then INT/equipment/percent scaling.
	if card.heal_amount > 0:
		var raw = card.heal_amount + on_self["heal"]
		if hp_mult > 1.0:
			raw += floori(card.heal_amount * (hp_mult - 1.0))
		if stats.has_skill_tree_passive("blood_libation") and stats.sanguine_stacks > 0:
			raw += stats.sanguine_stacks
			if stats.sanguine_stacks >= 5:
				raw *= 2
		out["heal"] = stats.get_effective_heal_amount(raw)
		out["heal_base"] = card.heal_amount

	return out

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

	var selected = deck_manager.hand[selected_card_index]

	# Co-op: playing a card offers the same choice as multi-space movement —
	# play immediately, or lock it in and fire together with the partner's, so
	# one person can set up both characters before anything spends tempo.
	if is_multiplayer and _p2_player and not _card_play_confirmed:
		_show_card_confirm_dialog(deck_manager.hand[selected_card_index], target)
		return

	# Player can always queue cards — they append to the tick queue

	# Hide range + AOE indicators when playing a card (the AOE shading was
	# sticking around because playing clears selected_card_index directly
	# rather than through select_card).
	if range_indicator:
		range_indicator.hide_range()
	if aoe_indicator:
		aoe_indicator.hide_indicator()

	var card = deck_manager.hand[selected_card_index]
	var tempo_cost = card.get_burden_tempo_cost()
	# Specific Strike: +1 tempo per OTHER card in hand (mana handled in play_card).
	if card.card_id == "specific_strike":
		tempo_cost += max(0, deck_manager.hand.size() - 1)
	var resolve_tick = mini(card.resolve_tick, tempo_cost)  # Clamp resolve_tick to tempo_cost
	var is_ranged_attack = card.is_ranged and card.card_type == Card.CardType.ATTACK

	# Arcane Overflow: -1 tempo on spells when primed (had 0 mana after previous spell)
	var ao_stats = player.get_stats()
	if ao_stats and ao_stats.has_skill_tree_passive("arcane_overflow") and ao_stats.st_arcane_overflow_discount:
		if card.school == Card.CardSchool.SPELL:
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
	# Sky Attack leaps into the air as part of the shot, so it always counts as
	# firing from High Ground.
	var high_ground_applied = false
	if is_ranged_attack and (_has_high_ground(player.position, target) or card.card_id == "sky_attack"):
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

	# Capture the card UI before playing for animation. The selected card is
	# always its stack's representative, so its CardUI is the one on screen.
	var played_card_ui: CardUI = null
	if selected_card_index >= 0 and selected_card_index < deck_manager.hand.size():
		played_card_ui = _hand_ui_for_card(deck_manager.hand[selected_card_index])

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

		# The character's swing/cast animation fires when the card actually
		# RESOLVES (see _resolve_queued_card), not here at play time — the
		# wind-up ticks pass first.

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
				"mana_spent": result.get("mana_spent", 0),
				"health_spent": result.get("health_spent", 0),
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
			var s_ui = _hand_ui_for_card(card)
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
		_refresh_flag_buffs(player)
		player = prev_p
		deck_manager = prev_d
		# Restore the active player's hand/deck readout (resolution refreshed the
		# owner's hand into the shared display).
		_on_hand_updated()
		update_deck_info()
	else:
		_resolve_queued_card(card)
		_refresh_flag_buffs(player)

func _refresh_flag_buffs(p) -> void:
	## Surface any raw-flag effects (Raged Circulation, Quiver charges, etc.) as
	## visible badges immediately after a card resolves.
	if p and p.has_method("get_buff_manager"):
		var bm = p.get_buff_manager()
		if bm and bm.has_method("sync_flag_buffs"):
			bm.sync_flag_buffs()

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

	# Each hero keeps its own lettered hand; reset the slot map on the swap so
	# the incoming hand reletters cleanly from A.
	_hand_slots.reset()
	_prev_hand_card_ids.clear()

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
	deck_manager.release_draw_reservation(card)  # queued no more
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
		# Swing exactly when the hit lands (facing wherever the target is NOW).
		if player.has_method("play_animation"):
			player.play_animation("attack_slash", _facing_dir_toward(target))
			if target is Node3D and is_instance_valid(target) and player.has_method("face_toward"):
				player.face_toward(target.position)
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
			if ba_stats.consume_free_hand_echo() and is_instance_valid(target):
				target.take_damage(damage, true)
				add_battle_log("Free hand echo! The strike lands twice.", Color(1.0, 0.9, 0.4))

		if ba_debuff_mgr:
			ba_debuff_mgr.on_attack()

		var target_name = ""
		if target is Enemy and is_instance_valid(target):
			target_name = target.enemy_name
		add_battle_log("Basic Attack: %d damage to %s" % [damage, target_name], Color(0.4, 1.0, 0.5))
		print("[MAIN] Basic Attack resolved: dealt %d damage to %s" % [damage, target_name])
		return

	# The action happens NOW — play the character's animation at resolution
	# rather than back when the card was played and the wind-up began.
	_play_card_animation(card, target)

	# Execute the card's effect (damage, block, heal, etc.)
	# Arm passives the in-execution crit roll needs to see (Deadly's isolated
	# +50% crit damage, Serial Killer's ambush auto-crit).
	progression_triggers.arm_pre_attack_passives(card, target)
	deck_manager.execute_deferred_card(card, target, player)
	progression_triggers.clear_pre_attack_passives()

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
	# "Casting a spell" is defined by the school tag — offensive spells
	# (Fireball) count exactly like support ones (previously only paid
	# utility cards qualified, so Fireball never triggered caster passives).
	if card.school == Card.CardSchool.SPELL:
		progression_triggers._trigger_sphere_passives("on_spell_cast", {"card": card, "target": target})
		_try_arcane_echo(player.get_stats())

	# Skill tree passive triggers for card play
	progression_triggers._trigger_skill_tree_on_card_play(card, target)
	progression_triggers._trigger_skill_tree_stephen_on_card_play(card)
	progression_triggers._trigger_skill_tree_cory_on_card_play(card)
	progression_triggers._trigger_skill_tree_jeremy_on_card_play(card, target)
	if card.card_type == Card.CardType.ATTACK:
		progression_triggers._trigger_skill_tree_on_attack(card, target)
		var brad_bonus = progression_triggers._trigger_skill_tree_brad_on_attack(card, target)
		var stephen_bonus = progression_triggers._trigger_skill_tree_stephen_on_attack(card, target)
		var cory_bonus = progression_triggers._trigger_skill_tree_cory_on_attack(card, target)
		if (brad_bonus + stephen_bonus + cory_bonus) > 0 and target and target.has_method("take_damage"):
			target.take_damage(brad_bonus + stephen_bonus + cory_bonus, true)
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
		# Bow of Budding Blasts: a crit with a slotted card buds a bow turret.
		if card.slotted_in_item and bool(card.get_on_self_bonus().get("crit_bud_bow", false)):
			_spawn_bud_bow()

	# Cyclops Ring: hits of 25+ feed the counter — but never while a
	# Strengthen is active, so the empowered hits can't feed the next round.
	_ring_note_big_hit(card.last_damage_dealt)

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
			progression_triggers.arm_pre_attack_passives(replay_card, replay_target)
			replay_card.execute(replay_target, stats, deck_manager, damage_reduction, self_damage, buff_mgr)
			progression_triggers.clear_pre_attack_passives()
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

## Extra range a helm grants a card at play time. Kept in one place so the range
## preview and the range enforcement stay in lockstep.
##   - On-self +range from the item the card is slotted in (Dragon Skull +1 to
##     any offensive card; Monocle +5 to offensive ranged cards).
##   - 20/20 (Monocle's granted Maintain): +3 range on ranged offensive cards.
func _helm_range_bonus(card) -> int:
	if card == null or not card.is_offensive():
		return 0
	var bonus := 0
	if card.slotted_in_item and card.slotted_in_item.has_method("get_on_self_bonus"):
		var osb = card.slotted_in_item.get_on_self_bonus()
		var r := int(osb.get("range_offensive", 0))
		if r > 0 and (not osb.get("range_requires_ranged", false) or card.is_ranged):
			bonus += r
	if card.is_ranged and deck_manager:
		for mc in deck_manager.get_maintained_cards():
			if mc and mc.card_id == "twenty_twenty":
				bonus += 3
				break
	# Tigers Sunday Red: +range on ALL ranged offensive cards while equipped.
	if card.is_ranged and player and player.get_stats():
		bonus += maxi(0, player.get_stats().equipment_ranged_range_bonus)
	# Wand of Deliverance: +range on ALL cards while it is in a hand
	# (10% weaker — floored — from the off hand, like everything else).
	if player and player.get_inventory():
		for wr_w in player.get_inventory().equipped_weapons:
			if wr_w != null and wr_w.range_bonus_all_cards > 0:
				bonus += floori(wr_w.range_bonus_all_cards * wr_w.rider_scale())
	return bonus

## Shamans mask: playing a UTILITY card zaps a random enemy within 3 tiles for
## a little INT-scaled spell damage. (The utility heal is applied in execute().)
func _helm_card_world_effects(card, target = null) -> void:
	if not card or not card.slotted_in_item or not player or not enemy_spawner or not grid_manager:
		return
	var osb = card.slotted_in_item.get_on_self_bonus()

	# Shamans mask: a UTILITY card zaps a random enemy within 3. The zap is a
	# fixed 1 spell damage — capped at 1, no INT/enchant/sphere modifiers.
	if card.card_type == Card.CardType.UTILITY:
		var spell_dmg := int(osb.get("utility_spell_damage", 0))
		if spell_dmg > 0:
			var victim = _random_enemy_within(3)
			if victim:
				victim.take_damage(spell_dmg, true)
				add_battle_log("%s: %d spell damage to %s" % [card.slotted_in_item.item_name, spell_dmg, victim.enemy_name], Color(0.5, 0.85, 0.6))

	# Boot Holsters: a slotted instant (REACTION) hits the nearest enemy in 3.
	if card.card_type == Card.CardType.REACTION:
		var inst_dmg := int(osb.get("instant_damage_nearest", 0))
		if inst_dmg > 0:
			var nearest = _nearest_enemy_to(player.position, enemy_spawner.get_living_enemies())
			if nearest and grid_manager.get_distance_in_cells(player.position, nearest.position) <= 3:
				nearest.take_damage(inst_dmg, true)
				add_battle_log("%s: %d damage to %s" % [card.slotted_in_item.item_name, inst_dmg, nearest.enemy_name], Color(0.8, 0.7, 0.4))

	# Gauntlets of Dungeon Mastering: a slotted card play summons a wolf.
	var wolf_count := int(osb.get("summon_wolf", 0))
	for _wi in range(wolf_count):
		_spawn_wolf()

	# Slotted Sash: a slotted UTILITY card Weakens a random enemy within 5.
	if card.card_type == Card.CardType.UTILITY and int(osb.get("utility_weaken", 0)) > 0:
		var sash_victim = _random_enemy_within(5)
		if sash_victim and sash_victim.has_method("apply_debuff"):
			sash_victim.apply_debuff("weaken", int(osb["utility_weaken"]))
			add_battle_log("%s: %s Weakened" % [card.slotted_in_item.item_name, sash_victim.enemy_name], Color(0.6, 0.6, 0.85))

	# Tactical belt: a slotted card detonates around its target (enemies only).
	if int(osb.get("target_aoe_damage", 0)) > 0 and target and is_instance_valid(target) and "position" in target:
		var blast := int(osb["target_aoe_damage"])
		var blast_hits := 0
		for be in enemy_spawner.get_living_enemies():
			if be and is_instance_valid(be) and grid_manager.get_distance_in_cells(target.position, be.position) <= 1:
				be.take_damage(blast, true)
				blast_hits += 1
		if blast_hits > 0:
			add_battle_log("%s: explosive hits %d for %d" % [card.slotted_in_item.item_name, blast_hits, blast], Color(1.0, 0.6, 0.3))

	# Houdinis Slippers: any slotted card turns the player invisible for a while.
	var invis_tempo := int(osb.get("invisible_tempo", 0))
	if invis_tempo > 0:
		var bm = player.get_buff_manager()
		if bm:
			bm.apply_buff(Buff.create_invisible(invis_tempo, card.slotted_in_item.item_name))
			_set_player_invisible(true)
			add_battle_log("%s: you vanish for %d tempo" % [card.slotted_in_item.item_name, invis_tempo], Color(0.7, 0.7, 0.9))

	# Shadow Cowl: an offensive slotted card lets you shift — the next N tiles
	# of movement are free (no tempo, no flash).
	if card.is_offensive() and int(osb.get("offensive_shift", 0)) > 0:
		var cowl_stats = player.get_stats()
		if cowl_stats:
			cowl_stats.free_move_tiles += int(osb["offensive_shift"])
			add_battle_log("%s: shift — next %d tiles are free" % [card.slotted_in_item.item_name, int(osb["offensive_shift"])], Color(0.6, 0.6, 0.85))

## Elemental Trail Blazers: if the player moved on flash points and the boots are
## worn, ignite the tile they just left. Damage scales with INT like a spell.
func _maybe_drop_fire_trail(cell: Vector2i) -> void:
	if not player or not grid_manager:
		return
	var stats = player.get_stats()
	if not stats or not stats.flash_movement_enabled:
		return  # only "when moving with flash points"
	var inv = player.get_inventory()
	if not inv:
		return
	var dmg := 0
	var persist := 0
	for boot in inv.equipped_boots:
		if boot and boot.fire_trail_damage > 0:
			dmg = boot.fire_trail_damage
			persist = boot.fire_trail_tempo
			break
	if dmg <= 0:
		return
	# Skip if a fire spot already burns here.
	for spot in _fire_spots:
		if spot["cell"] == cell:
			return
	# Fire spots deal INT/5 (min 1) — deliberately NOT the full spell pipeline.
	var scaled: int = maxi(1, floori(stats.intelligence / 5.0))
	var node := _make_fire_spot_visual(grid_manager.grid_to_world(cell))
	add_child(node)
	_fire_spots.append({"cell": cell, "tempo": persist, "damage": scaled, "node": node})

func _make_fire_spot_visual(world_pos: Vector3) -> Node3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.35
	mesh.bottom_radius = 0.4
	mesh.height = 0.08
	n.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.45, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.05)
	n.material_override = mat
	n.position = Vector3(world_pos.x, 0.05, world_pos.z)
	return n

## Per-tempo: burn any enemy standing on a fire spot (which then extinguishes),
## and age out spots whose timer has run down.
func _update_fire_spots(amount: int) -> void:
	if _fire_spots.is_empty() or not grid_manager or not enemy_spawner:
		return
	var survivors: Array = []
	for spot in _fire_spots:
		var extinguished := false
		for e in enemy_spawner.get_living_enemies():
			if e and is_instance_valid(e) and grid_manager.world_to_grid(e.position) == spot["cell"]:
				e.take_damage(spot["damage"], true, DamageTypes.Type.FIRE)
				add_battle_log("Fire scorches %s for %d!" % [e.enemy_name, spot["damage"]], Color(1.0, 0.5, 0.1))
				extinguished = true
				break
		spot["tempo"] -= amount
		if extinguished or spot["tempo"] <= 0:
			if is_instance_valid(spot["node"]):
				spot["node"].queue_free()
		else:
			survivors.append(spot)
	_fire_spots = survivors

# ============================================
# BULLET CASINGS (Chewbaccas Bandolier)
# ============================================

## After a ranged offensive card, the bandolier ejects a casing. The first one
## lands on the wearer's square; while that square holds a casing, later ones
## bounce to a random adjacent square without one. Fully surrounded = no drop.
func _maybe_drop_bullet_casing(card) -> void:
	if not player or not grid_manager or card == null:
		return
	if not (card.is_offensive() and card.is_ranged):
		return
	var inv = player.get_inventory()
	if not inv:
		return
	var dmg := 0
	var persist := 0
	for chest in inv.equipped_chests:
		if chest and chest.casing_damage > 0:
			dmg = chest.casing_damage
			persist = maxi(1, chest.casing_tempo)
			break
	if dmg <= 0:
		return
	var player_cell: Vector2i = grid_manager.world_to_grid(player.position)
	var drop_cell := player_cell
	if _casing_at(player_cell):
		var open: Array = []
		for off in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1),
				Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]:
			var c: Vector2i = player_cell + off
			if not _casing_at(c) and not (c in player.blocked_tiles):
				open.append(c)
		if open.is_empty():
			print("[MAIN] Bandolier: fully surrounded by casings — no drop")
			return
		drop_cell = open[randi() % open.size()]
	var node := _make_casing_visual(grid_manager.grid_to_world(drop_cell))
	add_child(node)
	_bullet_casings.append({"cell": drop_cell, "tempo": persist, "damage": dmg, "node": node})

func _casing_at(cell: Vector2i) -> bool:
	for casing in _bullet_casings:
		if casing["cell"] == cell:
			return true
	return false

func _make_casing_visual(world_pos: Vector3) -> Node3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.12
	mesh.bottom_radius = 0.15
	mesh.height = 0.12
	n.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.65, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.45, 0.1)
	n.material_override = mat
	n.position = Vector3(world_pos.x, 0.07, world_pos.z)
	return n

## Per-tempo: a casing explodes when an enemy stands on it, or when its timer
## runs out — 8 damage to enemies within 1 square. Allies, summons, and the
## player are never hurt.
func _update_bullet_casings(amount: int) -> void:
	if _bullet_casings.is_empty() or not grid_manager or not enemy_spawner:
		return
	var survivors: Array = []
	for casing in _bullet_casings:
		var stepped := false
		for e in enemy_spawner.get_living_enemies():
			if e and is_instance_valid(e) and grid_manager.world_to_grid(e.position) == casing["cell"]:
				stepped = true
				break
		casing["tempo"] -= amount
		if stepped or casing["tempo"] <= 0:
			var blast_pos: Vector3 = grid_manager.grid_to_world(casing["cell"])
			var hit := 0
			for e in enemy_spawner.get_living_enemies():
				if e and is_instance_valid(e) and grid_manager.get_distance_in_cells(blast_pos, e.position) <= 1:
					e.take_damage(casing["damage"], true)
					hit += 1
			if hit > 0:
				add_battle_log("Casing explodes! %d damage to %d enem%s" % [casing["damage"], hit, "y" if hit == 1 else "ies"], Color(1.0, 0.7, 0.2))
			if is_instance_valid(casing["node"]):
				casing["node"].queue_free()
		else:
			survivors.append(casing)
	_bullet_casings = survivors

func _clear_bullet_casings() -> void:
	for casing in _bullet_casings:
		if is_instance_valid(casing["node"]):
			casing["node"].queue_free()
	_bullet_casings.clear()

# ============================================
# SANGUINE THE PENGUIN (Nine Ruins of Sanguine)
# ============================================

func _summon_penguin() -> void:
	if _penguin != null and is_instance_valid(_penguin):
		return
	if not grid_manager or not player:
		return
	var pcell: Vector2i = grid_manager.world_to_grid(player.position)
	var spawn := pcell + Vector2i(1, 0)
	for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = pcell + off
		if not (c in player.blocked_tiles) and not (c in _living_enemy_cells()):
			spawn = c
			break
	var peng = PenguinScript.new()
	add_child(peng)
	peng.setup(grid_manager, grid_manager.grid_to_world(spawn))
	# Every point Sanguine bleeds heals the wielder for half.
	peng.hurt.connect(func(amount):
		if player and player.get_stats() and amount > 0:
			player.get_stats().heal(maxi(1, floori(amount / 2.0))))
	peng.died.connect(func(p): _garmr_death_stack(p.position); _penguin = null)
	_penguin = peng
	add_battle_log("Sanguine the blood penguin waddles forth!", Color(0.9, 0.4, 0.4))

## Per-tempo: Sanguine mimics the wielder — never straying more than a square —
## and pecks a melee-range enemy every 5 tempo.
func _update_penguin(amount: int) -> void:
	if _penguin == null or not is_instance_valid(_penguin) or _penguin.is_dead:
		return
	if not grid_manager or not player:
		return
	var pcell: Vector2i = grid_manager.world_to_grid(player.position)
	var mycell: Vector2i = _penguin.get_cell()
	if absi(pcell.x - mycell.x) > 1 or absi(pcell.y - mycell.y) > 1:
		var dest := pcell + Vector2i(1, 0)
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			var c: Vector2i = pcell + off
			if not (c in player.blocked_tiles):
				dest = c
				break
		_penguin.move_to_cell(dest)
	_penguin.attack_accum += amount
	if _penguin.attack_accum >= _penguin.ATTACK_INTERVAL and enemy_spawner:
		_penguin.attack_accum = 0
		var prey = _nearest_enemy_to(_penguin.position, enemy_spawner.get_living_enemies())
		if prey and grid_manager.get_distance_in_cells(_penguin.position, prey.position) <= 1.5:
			prey.take_damage(_penguin.BASE_ATTACK, false)
			add_battle_log("Sanguine pecks %s for %d!" % [prey.enemy_name, _penguin.BASE_ATTACK], Color(0.9, 0.4, 0.4))
			_belthronding_share(_penguin.position, _penguin.BASE_ATTACK)

func _clear_penguin() -> void:
	if _penguin and is_instance_valid(_penguin):
		_penguin.queue_free()
	_penguin = null

# ============================================
# WEAPON CARD RIDERS (weapons pass 1) — generic post-resolution effects
# ============================================

func _feral_current_color(item: ItemData, card: Card) -> String:
	## The element a feral-slotted card counts as RIGHT NOW: a conversion
	## override when one is held, its slot's printed color otherwise.
	if card.has_meta("feral_color"):
		return str(card.get_meta("feral_color"))
	return item.get_slot_color(card)

func _feral_conversion_effects(card: Card) -> void:
	## Feral Evocation: playing a slotted elemental card converts every OTHER
	## card slotted in the staff that is currently IN HAND to its element —
	## cards not in hand keep their color (they weren't there to be swayed).
	## Each actual change zaps a random enemy within 4 squares. Conversion
	## resets when a card leaves the hand (cleared on draw in DeckManager).
	if card == null or card.slotted_in_item == null or not card.slotted_in_item.feral_weapon:
		return
	var fe_item = card.slotted_in_item
	var fe_color := _feral_current_color(fe_item, card)
	if fe_color == "":
		return
	for fe_other in deck_manager.hand:
		if fe_other == card or fe_other.slotted_in_item != fe_item:
			continue
		if _feral_current_color(fe_item, fe_other) == fe_color:
			continue
		fe_other.set_meta("feral_color", fe_color)
		add_battle_log("Feral Evocation: %s turns %s!" % [fe_other.card_name, fe_color], Color(0.8, 0.5, 1.0))
		if fe_item.feral_change_damage > 0:
			var fe_victim = _random_enemy_within(4)
			if fe_victim:
				fe_victim.take_damage(fe_item.feral_change_damage, true)
				add_battle_log("The staff lashes out: %d damage to %s!" % [fe_item.feral_change_damage, fe_victim.enemy_name], Color(0.8, 0.5, 1.0))

func _weapon_post_card_effects(card: Card, target) -> void:
	if card == null or not player or not deck_manager:
		return
	var stats = player.get_stats()
	if stats == null:
		return

	# Feral Evocation: the played color pollinates the rest of the hand.
	_feral_conversion_effects(card)

	# Shepherds Crook: every targeted card play pulls its target one square
	# toward the wielder — enemies and allies alike.
	if target != null and is_instance_valid(target) and target != player and player.get_inventory():
		var pull_amt := 0
		for pull_w in player.get_inventory().equipped_weapons:
			if pull_w != null and pull_w.card_pull_target > 0:
				pull_amt += pull_w.card_pull_target
		if pull_amt > 0:
			_pull_toward_player(target, pull_amt)

	# Hard Helmet (Construction Hammer): a utility play can trigger the instant.
	if card.card_type == Card.CardType.UTILITY:
		var hh = deck_manager.trigger_reactions("on_utility_played")
		for hh_card in hh:
			hh_card.execute(null, stats, deck_manager, 0.0, 0.0, player.get_buff_manager())
			var hh_victim = _get_nearest_enemy()
			if hh_victim:
				hh_victim.take_damage(2, true)
				add_battle_log("Hard Helmet clonks %s for 2!" % hh_victim.enemy_name, Color(0.8, 0.7, 0.4))

	# Psionic Flow, attack mode: the strike hits harder and shoves.
	if card.is_offensive() and target and is_instance_valid(target) and target is Enemy:
		var pf = deck_manager.trigger_reactions("psionic_flow")
		for _pf_card in pf:
			target.take_damage(8, true)
			if target.has_method("knockback"):
				target.knockback(player.position, 1)
			add_battle_log("Psionic Flow: +8 damage, target shoved back!", Color(0.6, 0.7, 1.0))

	# Poseidons Trident: the thrust continues through the target in a line.
	if card.is_offensive() and target and is_instance_valid(target) and target is Enemy \
			and card.last_damage_dealt > 0 and grid_manager and enemy_spawner:
		var pierce := 0
		var pt_inv = player.get_inventory()
		if pt_inv:
			for pw in pt_inv.equipped_weapons:
				if pw and pw.pierce_targets > 1:
					pierce = pw.pierce_targets
					break
		if pierce > 1:
			var dirv: Vector3 = target.position - player.position
			var step := Vector2i(signi(roundi(dirv.x)), 0) if absf(dirv.x) >= absf(dirv.z) \
				else Vector2i(0, signi(roundi(dirv.z)))
			if step != Vector2i.ZERO:
				var tcell: Vector2i = grid_manager.world_to_grid(target.position)
				for i in range(1, pierce):
					var c: Vector2i = tcell + step * i
					for e in enemy_spawner.get_living_enemies():
						if e != target and e and is_instance_valid(e) and grid_manager.world_to_grid(e.position) == c:
							e.take_damage(card.last_damage_dealt, true)
							add_battle_log("The trident runs %s through!" % e.enemy_name, Color(0.4, 0.7, 0.9))

	# Nine Ruins of Sanguine: attacks build Vitality; the ninth calls the penguin.
	if card.is_offensive():
		var nr_inv = player.get_inventory()
		if nr_inv:
			for vw in nr_inv.equipped_weapons:
				if vw and vw.vitality_weapon:
					var penguin_alive: bool = _penguin != null and is_instance_valid(_penguin)
					if not penguin_alive and vw.vitality_stacks < 9:
						vw.vitality_stacks += 1
						if vw.vitality_stacks >= 9:
							vw.vitality_stacks = 0
							var vt = deck_manager.trigger_reactions("on_vitality_9")
							for vt_card in vt:
								vt_card.execute(null, stats, deck_manager, 0.0, 0.0, player.get_buff_manager())
							_summon_penguin()
						else:
							print("[MAIN] %s: Vitality %d/9" % [vw.item_name, vw.vitality_stacks])
					break

# ============================================
# DEATH STACKS (Hide of Garmr Lv.3)
# ============================================

## Any death within the hide's radius — enemy, wolf, worm, or Frankenstein —
## feeds the frenzy: +5% crit damage per stack. The 5th stack purges them all
## and tears 10% of the wearer's CURRENT health away.
func _garmr_death_stack(death_pos: Vector3) -> void:
	if not player or not grid_manager:
		return
	var inv = player.get_inventory()
	var stats = player.get_stats()
	if not inv or not stats:
		return
	for chest in inv.equipped_chests:
		if chest == null or chest.death_crit_stack_radius <= 0:
			continue
		if grid_manager.get_distance_in_cells(player.position, death_pos) > chest.death_crit_stack_radius:
			continue
		chest.death_crit_stacks += 1
		if chest.death_crit_stacks >= 5:
			chest.death_crit_stacks = 0
			stats.death_stack_crit_damage = 0.0
			var recoil: int = maxi(1, floori(stats.current_health * 0.10))
			stats.take_direct_damage(recoil)
			add_battle_log("%s: frenzy purged — %d recoil damage!" % [chest.item_name, recoil], Color(0.9, 0.3, 0.3))
		else:
			stats.death_stack_crit_damage = chest.death_crit_stacks * chest.death_crit_damage_per_stack / 100.0
			add_battle_log("%s: %d death stack(s), +%d%% crit damage" % [chest.item_name,
				chest.death_crit_stacks, int(chest.death_crit_stacks * chest.death_crit_damage_per_stack)], Color(0.8, 0.5, 0.5))

# ============================================
# WOLVES (Gauntlets of Dungeon Mastering)
# ============================================

const WOLF_PACK_CAP := 3

func _spawn_wolf() -> void:
	if not grid_manager or not player:
		return
	_wolves = _wolves.filter(func(w): return is_instance_valid(w) and not w.is_dead)
	if _wolves.size() >= WOLF_PACK_CAP:
		add_battle_log("The pack is full (%d wolves)." % WOLF_PACK_CAP, Color(0.7, 0.7, 0.8))
		return
	var player_cell = grid_manager.world_to_grid(player.position)
	var spawn_cell = player_cell + Vector2i(1, 0)
	for off in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var c = player_cell + off
		if not (c in player.blocked_tiles) and not (c in _living_enemy_cells()):
			spawn_cell = c
			break
	var wolf = WolfScript.new()
	add_child(wolf)
	wolf.setup(grid_manager, grid_manager.grid_to_world(spawn_cell))
	wolf.died.connect(func(w): _garmr_death_stack(w.position); _wolves.erase(w))
	_wolves.append(wolf)
	add_battle_log("A wolf answers the call! (%d in the pack)" % _wolves.size(), Color(0.7, 0.7, 0.8))

func _clear_wolves() -> void:
	for w in _wolves:
		if is_instance_valid(w):
			w.queue_free()
	_wolves.clear()

## Per-tempo wolf AI: moves 2 tiles per 3 tempo toward the nearest enemy,
## attacks every 5 tempo when adjacent. Wolfpack: each OTHER living wolf grants
## +20% attack damage and +1 bleed stack on hits.
func _update_wolves(amount: int) -> void:
	if _wolves.is_empty():
		return
	_wolves = _wolves.filter(func(w): return is_instance_valid(w) and not w.is_dead)
	if not grid_manager or not enemy_spawner:
		return
	var enemies = enemy_spawner.get_living_enemies()
	var blocked = player.blocked_tiles
	var pack_others: int = max(0, _wolves.size() - 1)
	var wolf_cells: Array = []
	for w in _wolves:
		wolf_cells.append(w.get_cell())
	for w in _wolves.duplicate():
		if not is_instance_valid(w) or w.is_dead:
			continue
		var target_enemy = _nearest_enemy_to(w.position, enemies)
		if target_enemy == null:
			continue
		var tcell = grid_manager.world_to_grid(target_enemy.position)
		w.attack_accum += amount
		if _manhattan(w.get_cell(), tcell) <= 1:
			if w.attack_accum >= w.ATTACK_INTERVAL:
				w.attack_accum -= w.ATTACK_INTERVAL
				var dmg: int = floori(w.BASE_ATTACK * (1.0 + 0.2 * pack_others))
				target_enemy.take_damage(dmg, true)
				if target_enemy.has_method("apply_debuff"):
					target_enemy.apply_debuff("bleed", 1 + pack_others)
				add_battle_log("Wolf bites %s for %d (+%d bleed)!" % [target_enemy.enemy_name, dmg, 1 + pack_others], Color(0.7, 0.7, 0.8))
				_belthronding_share(w.position, dmg)
			continue
		w.move_accum += amount
		if w.move_accum >= w.MOVE_INTERVAL:
			w.move_accum -= w.MOVE_INTERVAL
			var cur = w.get_cell()
			wolf_cells.erase(cur)
			for _step in range(w.MOVE_STEPS):
				var tc = grid_manager.world_to_grid(target_enemy.position)
				if _manhattan(cur, tc) <= 1:
					break
				var nxt = _rat_step_toward(cur, tc, blocked, _living_enemy_cells(), wolf_cells)
				if nxt == cur:
					break
				cur = nxt
			wolf_cells.append(cur)
			if cur != w.get_cell():
				w.move_to_cell(cur)
	_wolves = _wolves.filter(func(w): return is_instance_valid(w) and not w.is_dead)

# ============================================
# RANGED PASS: SKELETONS, SPIRIT BOWS, MARK ZONES
# ============================================

## Sack of Bone Arrows: a kill made with a card slotted in the quiver raises a
## skeleton at half the victim's max health, on or beside the corpse's cell.
func _spawn_bone_skeleton(hp: int, near_pos: Vector3) -> void:
	if not grid_manager:
		return
	_skeletons = _skeletons.filter(func(s): return is_instance_valid(s) and not s.is_dead)
	if _skeletons.size() >= 3:
		add_battle_log("The bones will not answer — three skeletons already stand.", Color(0.8, 0.85, 0.75))
		return
	var corpse_cell = grid_manager.world_to_grid(near_pos)
	var spawn_cell = corpse_cell
	if spawn_cell in player.blocked_tiles or spawn_cell in _living_enemy_cells():
		for off in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var c = corpse_cell + off
			if not (c in player.blocked_tiles) and not (c in _living_enemy_cells()):
				spawn_cell = c
				break
	var skel = SkeletonScript.new()
	add_child(skel)
	skel.setup(grid_manager, grid_manager.grid_to_world(spawn_cell), hp)
	skel.died.connect(func(s): _garmr_death_stack(s.position); _skeletons.erase(s))
	_skeletons.append(skel)
	add_battle_log("A skeleton claws out of the kill! (%d/3, %d HP)" % [_skeletons.size(), hp], Color(0.8, 0.85, 0.75))

func _clear_skeletons() -> void:
	for s in _skeletons:
		if is_instance_valid(s):
			s.queue_free()
	_skeletons.clear()

## Per-tempo skeleton AI: sprints 4 tiles per tempo at the nearest enemy,
## swings for 5 every 5 tempo when adjacent.
func _update_skeletons(amount: int) -> void:
	if _skeletons.is_empty():
		return
	_skeletons = _skeletons.filter(func(s): return is_instance_valid(s) and not s.is_dead)
	if not grid_manager or not enemy_spawner:
		return
	var enemies = enemy_spawner.get_living_enemies()
	var blocked = player.blocked_tiles
	var skel_cells: Array = []
	for s in _skeletons:
		skel_cells.append(s.get_cell())
	for s in _skeletons.duplicate():
		if not is_instance_valid(s) or s.is_dead:
			continue
		var target_enemy = _nearest_enemy_to(s.position, enemies)
		if target_enemy == null:
			continue
		var tcell = grid_manager.world_to_grid(target_enemy.position)
		s.attack_accum += amount
		if _manhattan(s.get_cell(), tcell) <= 1:
			if s.attack_accum >= s.ATTACK_INTERVAL:
				s.attack_accum -= s.ATTACK_INTERVAL
				target_enemy.take_damage(s.BASE_ATTACK, true)
				add_battle_log("Skeleton rakes %s for %d!" % [target_enemy.enemy_name, s.BASE_ATTACK], Color(0.8, 0.85, 0.75))
				_belthronding_share(s.position, s.BASE_ATTACK)
			continue
		s.move_accum += amount
		if s.move_accum >= s.MOVE_INTERVAL:
			s.move_accum -= s.MOVE_INTERVAL
			var cur = s.get_cell()
			skel_cells.erase(cur)
			for _step in range(s.MOVE_STEPS):
				var tc = grid_manager.world_to_grid(target_enemy.position)
				if _manhattan(cur, tc) <= 1:
					break
				var nxt = _rat_step_toward(cur, tc, blocked, _living_enemy_cells(), skel_cells)
				if nxt == cur:
					break
				cur = nxt
			skel_cells.append(cur)
			if cur != s.get_cell():
				s.move_to_cell(cur)
	_skeletons = _skeletons.filter(func(s): return is_instance_valid(s) and not s.is_dead)

## Bow of Budding Blasts: the maintained Spirit Bow (one at a time).
func _summon_spirit_bow() -> void:
	if not grid_manager or not player:
		return
	_refresh_bow_instances()
	for b in _spirit_bows:
		if not b.is_bud:
			return  # one spirit bow at a time; the maintain is already up
	var player_cell = grid_manager.world_to_grid(player.position)
	var spawn_cell = player_cell + Vector2i(1, 0)
	for off in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var c = player_cell + off
		if not (c in player.blocked_tiles) and not (c in _living_enemy_cells()):
			spawn_cell = c
			break
	var bow = SpiritBowScript.new()
	add_child(bow)
	bow.setup(grid_manager, grid_manager.grid_to_world(spawn_cell), false)
	bow.died.connect(func(b): _garmr_death_stack(b.position); _spirit_bows.erase(b); _refresh_bow_instances())
	_spirit_bows.append(bow)
	_refresh_bow_instances()
	add_battle_log("A spirit bow takes shape beside you.", Color(0.5, 0.85, 0.8))

## Bow of Budding Blasts: a slotted crit buds a rooted bow turret (cap 4).
func _spawn_bud_bow() -> void:
	if not grid_manager or not player:
		return
	_refresh_bow_instances()
	var buds := 0
	for b in _spirit_bows:
		if b.is_bud:
			buds += 1
	if buds >= 4:
		return  # four bows is the max
	var player_cell = grid_manager.world_to_grid(player.position)
	var spawn_cell = player_cell + Vector2i(-1, 0)
	for off in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1), Vector2i(1,1), Vector2i(-1,-1)]:
		var c = player_cell + off
		if not (c in player.blocked_tiles) and not (c in _living_enemy_cells()):
			spawn_cell = c
			break
	var bow = SpiritBowScript.new()
	add_child(bow)
	bow.setup(grid_manager, grid_manager.grid_to_world(spawn_cell), true)
	bow.died.connect(func(b): _garmr_death_stack(b.position); _spirit_bows.erase(b); _refresh_bow_instances())
	_spirit_bows.append(bow)
	_refresh_bow_instances()
	add_battle_log("A bow buds from the crit! (%d bud%s)" % [buds + 1, "" if buds == 0 else "s"], Color(0.5, 0.85, 0.8))

func _clear_spirit_bows() -> void:
	for b in _spirit_bows:
		if is_instance_valid(b):
			b.queue_free()
	_spirit_bows.clear()
	_refresh_bow_instances()

## Keep PlayerStats.bow_instance_count matched to the living bow summons —
## the Bow of Budding Blasts reads it for its +2 damage / +5% crit stacking.
func _refresh_bow_instances() -> void:
	_spirit_bows = _spirit_bows.filter(func(b): return is_instance_valid(b) and not b.is_dead)
	var st = player.get_stats() if player else null
	if st:
		st.bow_instance_count = _spirit_bows.size()

## Per-tempo spirit-bow AI. The maintained bow stalks the nearest enemy one
## square per tempo and shoots every 4 tempo; buds are rooted and shoot every
## 5. Every bow's shot gains +2 damage per living bow and crits (x1.5) with
## 5% chance per living bow. The maintained bow dissolves the moment its
## Spirit Bow card stops being maintained.
func _update_element_pollination() -> void:
	## Elemental Weaver: cache the maintain's on/off state where enemies can
	## read it during their own debuff ticking. Recomputed every tempo tick, so
	## break, dismiss and unequip all propagate within a tick — never stored as
	## a set-and-forget flag (the break/restore paths would leak it).
	var pol_active := false
	if deck_manager:
		for pol_mc in deck_manager.maintained_cards:
			if pol_mc and pol_mc.card_id == "element_pollination":
				pol_active = true
				break
	Card.element_pollination_active = pol_active

func _make_bushel_visual(cell: Vector2i) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh_res := SphereMesh.new()
	mesh_res.radius = 0.22
	mesh_res.height = 0.32
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.85, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.6, 0.25)
	mat.emission_energy_multiplier = 0.6
	mesh_res.material = mat
	node.mesh = mesh_res
	node.position = grid_manager.grid_to_world(cell)
	node.position.y = 0.18
	add_child(node)
	return node

func _check_berry_bushels() -> void:
	## Crops (Shepherds Crook): an ally standing on a bushel eats it — 20 life,
	## 20 mana — and "ally" includes the player. One bushel, one meal.
	if _berry_bushels.is_empty() or not grid_manager:
		return
	for bb_p in _all_players():
		if not is_instance_valid(bb_p) or not bb_p.has_method("get_stats"):
			continue
		var bb_stats = bb_p.get_stats()
		if bb_stats == null:
			continue
		var bb_cell: Vector2i = grid_manager.world_to_grid(bb_p.position)
		for i in range(_berry_bushels.size() - 1, -1, -1):
			var bb = _berry_bushels[i]
			if bb["cell"] == bb_cell:
				bb_stats.heal(20)
				bb_stats.gain_mana(20)
				if is_instance_valid(bb["node"]):
					bb["node"].queue_free()
				_berry_bushels.remove_at(i)
				add_battle_log("Berries! +20 life, +20 mana.", Color(0.5, 0.9, 0.4))

func _clear_berry_bushels() -> void:
	for bb in _berry_bushels:
		if is_instance_valid(bb["node"]):
			bb["node"].queue_free()
	_berry_bushels.clear()

func _pull_toward_player(target, squares: int) -> void:
	## Shepherds Crook: reel a unit toward the player one cell at a time —
	## stopping at blocked tiles, and at arm's length (never onto the player).
	if not grid_manager or not is_instance_valid(target) or target == player:
		return
	var t_cell: Vector2i = grid_manager.world_to_grid(target.position)
	var p_cell: Vector2i = grid_manager.world_to_grid(player.position)
	var start_cell: Vector2i = t_cell
	for _i in range(squares):
		var diff: Vector2i = p_cell - t_cell
		if maxi(absi(diff.x), absi(diff.y)) <= 1:
			break  # already beside the shepherd
		var step := Vector2i(signi(diff.x), signi(diff.y))
		var next_cell: Vector2i = t_cell + step
		if next_cell == p_cell or (next_cell in player.blocked_tiles):
			break
		t_cell = next_cell
	if t_cell == start_cell:
		return
	var dest: Vector3 = grid_manager.grid_to_world(t_cell)
	if target.has_method("blink_to"):
		target.blink_to(dest)  # allies snap cleanly (grid + ground height)
	else:
		dest.y = target.position.y
		target.position = dest
		if "target_position" in target:
			target.target_position = dest
	var pull_name: String = target.enemy_name if "enemy_name" in target else "an ally"
	add_battle_log("The crook pulls %s a square closer." % pull_name, Color(0.5, 0.9, 0.4))

func _update_grounding_discount() -> void:
	## Grounding costs 5 less per absorbable Shock within 10 squares. The count
	## is stamped onto the hand copy each tempo tick so DeckManager can read it
	## at cost time without reaching into the world.
	if not deck_manager:
		return
	var gd_cards: Array = []
	for gd_c in deck_manager.hand:
		if gd_c and gd_c.card_id == "grounding":
			gd_cards.append(gd_c)
	if gd_cards.is_empty():
		return
	var gd_shock := 0
	if enemy_spawner and grid_manager and player:
		for gd_e in enemy_spawner.get_living_enemies():
			if gd_e and is_instance_valid(gd_e) and gd_e.shock_stacks > 0 \
					and grid_manager.get_distance_in_cells(player.position, gd_e.position) <= 10:
				gd_shock += gd_e.shock_stacks
		for gd_ally in _all_players():
			if is_instance_valid(gd_ally) and gd_ally.has_method("get_debuff_manager") \
					and grid_manager.get_distance_in_cells(player.position, gd_ally.position) <= 10:
				var gd_adm = gd_ally.get_debuff_manager()
				if gd_adm:
					var gd_sh = gd_adm.get_debuff(Debuff.DebuffType.SHOCKED)
					if gd_sh:
						gd_shock += maxi(gd_sh.value, 1)
	for gd_c2 in gd_cards:
		gd_c2.set_meta("grounding_discount", gd_shock * 5)

func _update_spirit_bows(amount: int) -> void:
	if _spirit_bows.is_empty():
		return
	_refresh_bow_instances()
	if not grid_manager or not enemy_spawner:
		return
	# Maintain check: no reserved Spirit Bow card, no spirit bow.
	var maintained := false
	if deck_manager:
		for mc in deck_manager.maintained_cards:
			if mc.card_id == "spirit_bow":
				maintained = true
				break
	for b in _spirit_bows.duplicate():
		if not b.is_bud and not maintained:
			add_battle_log("The spirit bow dissolves — its mana is no longer held.", Color(0.5, 0.85, 0.8))
			b.die()
	_refresh_bow_instances()
	var enemies = enemy_spawner.get_living_enemies()
	var blocked = player.blocked_tiles
	var instance_count: int = _spirit_bows.size()
	var bow_cells: Array = []
	for b in _spirit_bows:
		bow_cells.append(b.get_cell())
	for b in _spirit_bows.duplicate():
		if not is_instance_valid(b) or b.is_dead:
			continue
		var target_enemy = _nearest_enemy_to(b.position, enemies)
		if target_enemy == null:
			continue
		var tcell = grid_manager.world_to_grid(target_enemy.position)
		b.attack_accum += amount
		if _manhattan(b.get_cell(), tcell) <= b.ATTACK_RANGE:
			if b.attack_accum >= b.attack_interval():
				b.attack_accum -= b.attack_interval()
				var dmg: int = b.base_attack() + 2 * instance_count
				if randf() * 100.0 < 5.0 * instance_count:
					dmg = floori(dmg * 1.5)
					add_battle_log("The bow's shot crits!", Color(0.5, 0.85, 0.8))
				target_enemy.take_damage(dmg, true)
				add_battle_log("%s pierces %s for %d!" % ["A budded bow" if b.is_bud else "The spirit bow", target_enemy.enemy_name, dmg], Color(0.5, 0.85, 0.8))
				_belthronding_share(b.position, dmg)
				b.spend_attack()
			continue
		if b.is_bud:
			continue  # rooted where it sprouted
		b.move_accum += amount
		if b.move_accum >= b.SPIRIT_MOVE_INTERVAL:
			b.move_accum -= b.SPIRIT_MOVE_INTERVAL
			var cur = b.get_cell()
			bow_cells.erase(cur)
			var nxt = _rat_step_toward(cur, tcell, blocked, _living_enemy_cells(), bow_cells)
			bow_cells.append(nxt)
			if nxt != cur:
				b.move_to_cell(nxt)
	_refresh_bow_instances()

## Belthronding: when an ally (summons included) deals damage within the bow's
## radius of the wielder, the wielder takes a share of it as well.
func _belthronding_share(dealer_pos: Vector3, damage: int) -> void:
	if damage <= 0 or not player or not is_instance_valid(player) or not grid_manager:
		return
	var inv = player.get_inventory()
	if inv == null:
		return
	for w in inv.equipped_weapons:
		if w != null and w is ItemData and w.ally_damage_share_percent > 0.0:
			if grid_manager.get_distance_in_cells(dealer_pos, player.position) <= w.ally_damage_share_radius:
				var share: int = maxi(1, floori(damage * w.ally_damage_share_percent / 100.0))
				var st = player.get_stats()
				if st:
					st.take_direct_damage(share)
					add_battle_log("Belthronding drinks the echo — you take %d." % share, Color(0.8, 0.6, 0.6))
			return

## Territorial Mark (Bow of Arash): the corridor of cells within 2 squares of
## the arrow's flight line, shooter to target.
func _territorial_mark_cells(from_cell: Vector2i, to_cell: Vector2i) -> Array:
	var cells: Array = []
	var a := Vector2(from_cell)
	var b := Vector2(to_cell)
	var seg := b - a
	var seg_len_sq := seg.length_squared()
	for x in range(mini(from_cell.x, to_cell.x) - 2, maxi(from_cell.x, to_cell.x) + 3):
		for y in range(mini(from_cell.y, to_cell.y) - 2, maxi(from_cell.y, to_cell.y) + 3):
			var p := Vector2(x, y)
			var t := 0.0
			if seg_len_sq > 0.0:
				t = clampf((p - a).dot(seg) / seg_len_sq, 0.0, 1.0)
			if p.distance_to(a + seg * t) <= 2.0:
				cells.append(Vector2i(x, y))
	return cells

func _create_mark_zone(cells: Array, tempo: int) -> void:
	var nodes: Array = []
	for c in cells:
		var n := _make_mark_smoke_visual(grid_manager.grid_to_world(c))
		add_child(n)
		nodes.append(n)
	_mark_zones.append({"cells": cells, "tempo": tempo, "nodes": nodes})

## The blue glistening smoke of the mark: a translucent emissive disc per cell.
func _make_mark_smoke_visual(world_pos: Vector3) -> Node3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.42
	mesh.bottom_radius = 0.46
	mesh.height = 0.1
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.6, 0.95, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.55, 0.9)
	mat.emission_energy_multiplier = 0.6
	node.material_override = mat
	node.position = Vector3(world_pos.x, 0.06, world_pos.z)
	return node

func _clear_mark_zones() -> void:
	for z in _mark_zones:
		for n in z["nodes"]:
			if is_instance_valid(n):
				n.queue_free()
	_mark_zones.clear()
	if enemy_spawner:
		for e in enemy_spawner.get_living_enemies():
			e.zone_weakened = false

## Age the mark zones, then refresh which enemies stand in the blue smoke.
## zone_weakened is a persistent no-stack Weaken that lifts on leaving.
func _update_mark_zones(amount: int) -> void:
	if _mark_zones.is_empty():
		return
	var survivors: Array = []
	for z in _mark_zones:
		z["tempo"] -= amount
		if z["tempo"] > 0:
			survivors.append(z)
		else:
			for n in z["nodes"]:
				if is_instance_valid(n):
					n.queue_free()
	_mark_zones = survivors
	if enemy_spawner:
		for e in enemy_spawner.get_living_enemies():
			var cell = grid_manager.world_to_grid(e.position)
			var inside := false
			for z in _mark_zones:
				if cell in z["cells"]:
					inside = true
					break
			e.zone_weakened = inside

## Close is Favored (Belthronding): the trap in the hand springs on the first
## enemy found inside melee reach.
func _check_melee_range_reactions() -> void:
	if deck_manager == null or enemy_spawner == null or player == null or not grid_manager:
		return
	var has_trap := false
	for c in deck_manager.hand:
		if c.card_type == Card.CardType.REACTION and c.reaction_trigger == "on_enemy_melee_range":
			has_trap = true
			break
	if not has_trap:
		return
	var adj = null
	for e in enemy_spawner.get_living_enemies():
		if grid_manager.get_distance_in_cells(e.position, player.position) <= 1:
			adj = e
			break
	if adj == null:
		return
	var fired = deck_manager.trigger_reactions("on_enemy_melee_range")
	for card in fired:
		card.execute(adj, player.get_stats(), deck_manager, 0.0, 0.0, player.get_buff_manager())
		add_battle_log("Close is Favored! %s takes %d." % [adj.enemy_name, card.last_damage_dealt], Color(0.85, 0.75, 0.5))
		if card.erase_on_play:
			# Erased, not discarded — trigger_reactions parked it in the discard pile.
			deck_manager.discard_pile.erase(card)
			deck_manager.card_erased.emit(card)

## Colored slots (Mauls Sabre): the red slot's discard is a cost the player
## pays on their own terms — one picker per card owed, chained. The picker
## auto-resolves when only one candidate remains and the cost simply runs dry
## with the hand, so an empty or thin hand never soft-locks the play.
func _colored_slot_discard(card: Card) -> void:
	if card.slotted_in_item == null:
		return
	var fx: Dictionary = card.slotted_in_item.get_slot_effect(card)
	var owed: int = int(fx.get("discard", 0))
	if owed <= 0:
		return
	_pick_slot_discard(owed, card.slotted_in_item.get_slot_color(card))

func _pick_slot_discard(owed: int, color: String) -> void:
	if owed <= 0 or deck_manager.hand.is_empty():
		return
	show_hand_card_picker("%s slot — discard which card? (%d to go)" % [color.capitalize(), owed],
		func(picked):
			if picked != null:
				deck_manager.discard_card_from_hand(picked)
				add_battle_log("Discarded %s to the %s slot." % [picked.card_name, color], Color(1.0, 0.5, 0.5))
			_pick_slot_discard(owed - 1, color))

## Slotted-shield riders that need the world (shields pass 1): the Vengeful
## Shield's shove and the Slotted Rope Half Sleeve's discard.
func _shield_on_self_world_effects(card: Card, target) -> void:
	if card.slotted_in_item == null:
		return
	var osb = card.get_on_self_bonus()
	var shove: int = int(osb.get("knockback", 0))
	if shove > 0 and target != null and is_instance_valid(target) and target.has_method("knockback"):
		target.knockback(player.position, shove)
		add_battle_log("%s: %s is shoved back %d" % [card.slotted_in_item.item_name,
			target.enemy_name if "enemy_name" in target else "the target", shove], Color(0.8, 0.75, 0.6))
	var owed: int = int(osb.get("discard", 0))
	if owed > 0:
		_pick_slot_discard(owed, card.slotted_in_item.item_name)

## Slotted-item riders that need the world (ranged pass 1): Belthronding's
## conjure, the Rapid Recurve's second shot, the Stringless Sender's bounce,
## and the Sack of Bone Arrows' kill-raised skeleton.
func _ranged_on_self_world_effects(card: Card, target) -> void:
	if card.slotted_in_item == null:
		return
	var osb = card.get_on_self_bonus()
	# Belthronding: playing a slotted card loads the close-range trap.
	# Balance ruling: at most 3 copies may wait in the hand at once — the
	# stockpiled punishment nova is capped, not endless.
	var conjure_id: String = str(osb.get("conjure_on_play_id", ""))
	if conjure_id != "" and deck_manager:
		var held := 0
		for hc in deck_manager.hand:
			if hc.card_id == conjure_id:
				held += 1
		if held < 3:
			var trap = deck_manager._create_card_from_id(conjure_id)
			if trap:
				trap.shop_excluded = true
				deck_manager.add_card_to_hand(trap)
				add_battle_log("Close is Favored waits in your hand. (%d/3)" % (held + 1), Color(0.85, 0.75, 0.5))
	# The Rapid Recurve: the card fires a SECOND, fully separate shot — its
	# own crit roll, its own ailments, its own Strengthen charge — by
	# re-executing the card against the target. World effects don't re-run
	# for the second shot, so the doubling can never recurse.
	if bool(osb.get("double_shot", false)) and card.is_offensive() \
			and target != null and is_instance_valid(target) and "is_dead" in target and not target.is_dead:
		card.execute(target, player.get_stats(), deck_manager, 0.0, 0.0, player.get_buff_manager())
		add_battle_log("Double Shot! The second arrow takes %d." % card.last_damage_dealt, Color(1.0, 0.7, 0.4))
		# The second shot is its own hit for every counter that watches hits —
		# and its own crit, consumed here so the flag never leaks forward.
		_ring_note_big_hit(card.last_damage_dealt)
		var ds_bm = player.get_buff_manager()
		if ds_bm and ds_bm.last_crit_hit:
			ds_bm.last_crit_hit = false
			progression_triggers._trigger_skill_tree_on_crit(target)
	# Stringless Sender: 20% chance the shot bounces to the nearest other
	# enemy at full damage — last_damage_dealt already embeds the crit result,
	# so a crit success (or failure) is mimicked exactly.
	if float(osb.get("bounce_percent", 0.0)) > 0.0 and card.is_offensive() \
			and card.last_damage_dealt > 0 and target != null and is_instance_valid(target) \
			and randf() * 100.0 < float(osb["bounce_percent"]):
		var hop = null
		var hop_d := INF
		for ce in enemy_spawner.get_living_enemies():
			if ce and is_instance_valid(ce) and ce != target:
				var d = target.position.distance_to(ce.position)
				if d < hop_d:
					hop_d = d
					hop = ce
		if hop:
			hop.take_damage(card.last_damage_dealt, true)
			add_battle_log("The shot bounces! %s takes %d." % [hop.enemy_name, card.last_damage_dealt], Color(0.6, 0.8, 1.0))
	# Sack of Bone Arrows: a kill made with the slotted card raises a skeleton
	# at half the victim's max health.
	if bool(osb.get("kill_summon_skeleton", false)) and card.is_offensive() \
			and target != null and is_instance_valid(target) and "is_dead" in target and target.is_dead:
		_spawn_bone_skeleton(maxi(1, floori(target.max_health / 2.0)), target.position)

# ============================================
# RING PASS: BESPOKE PROCS, SHADOW FORM, WRAITHS, CLONES
# ============================================

## Every bespoke ring proc lands here (Inventory counts; main executes).
## Jeremy's doubled fire simply calls this twice.
func _on_custom_ring_fired(ring: ItemData, kind: String, value: int) -> void:
	var stats = player.get_stats()
	var buff_mgr = player.get_buff_manager()
	match kind:
		"zap":
			# Heal Stone / Gold Band / Emerald: 2 damage to a random enemy within 5.
			var near: Array = []
			for e in enemy_spawner.get_living_enemies():
				if grid_manager.get_distance_in_cells(player.position, e.position) <= 5:
					near.append(e)
			if near.size() > 0:
				var victim = near[randi() % near.size()]
				victim.take_damage(value, true)
				add_battle_log("%s sparks! %s takes %d." % [ring.item_name, victim.enemy_name, value], Color(0.9, 0.85, 0.5))
		"stone_hide":
			buff_mgr.apply_buff(Buff.create_resilient(value, 15, ring.item_name, DamageTypes.ALL))
			add_battle_log("Stone skin! %d%% resistance to all damage for 15 tempo." % value, Color(0.7, 0.65, 0.55))
		"cleanse_self":
			buff_mgr.apply_buff(Buff.create_cleanse(value, ring.item_name))
			add_battle_log("The Harnessed Sun burns a debuff away.", Color(1.0, 0.8, 0.3))
		"captain_planet":
			stats.heal(15)
			for _d in range(3):
				deck_manager.draw_card()
			for cid in ["fireball", "rise"]:
				var cp_card = deck_manager._create_card_from_id(cid)
				if cp_card:
					# Conjured copies never pollute the deck: erased 10 tempo
					# after arriving, played or not.
					cp_card.erase_tempo = 10
					deck_manager.add_card_to_hand(cp_card)
			add_battle_log("By your powers combined! Heal 15, draw 3, Fireball and Rise arrive (10 tempo).", Color(0.3, 0.8, 1.0))
		"cyclops_strengthen":
			buff_mgr.apply_buff(Buff.create_strengthen(value, 2, ring.item_name))
			ring.ring_counters["empowered"] = 2  # the ring's own hits sit out of the counter
			add_battle_log("The Cyclops Ring swells: Strengthen %d for 2 hits." % value, Color(1.0, 0.6, 0.4))
		"thomas_regen":
			buff_mgr.apply_buff(Buff.create_regen(value, 15, ring.item_name))
			add_battle_log("The wheels turn: %d Regen." % value, Color(0.4, 0.75, 1.0))
		"thomas_heal":
			stats.heal(value)
			add_battle_log("Right on schedule — heal %d." % value, Color(0.4, 0.75, 1.0))
		"nibelung_curse":
			_conjure_nibelung_curse(ring, value)
		"shadow_form":
			_enter_shadow_form(ring)
		"draupnir_clone":
			_spawn_draupnir_clone(ring)

## The Nibelung Curse: one copy may exist across every zone; the L3 ring
## multiplies the stored total by 1.5.
func _conjure_nibelung_curse(ring: ItemData, total: int) -> void:
	for zone in [deck_manager.hand, deck_manager.draw_pile, deck_manager.discard_pile, deck_manager.jail_pile]:
		for c in zone:
			if c.card_id == "the_nibelung_curse":
				print("[MAIN] Nibelung Curse already exists — a new one is not made")
				return
	var cv: int = floori(total * (1.5 if ring.item_level >= 3 else 1.0))
	var card = deck_manager._create_card_from_id("the_nibelung_curse")
	if card == null:
		return
	card.set_meta("curse_value", cv)
	card.description = "Target yourself to take %d healing, or an enemy to deal %d damage. Erased after use." % [cv, cv]
	deck_manager.add_card_to_hand(card)
	add_battle_log("The Nibelung Curse arrives, carrying %d." % cv, Color(0.9, 0.7, 0.3))

## The Precious: enter shadow form and let the wraiths out. Surviving wraiths
## return exactly as they were left (state kept on the ring); killed ones
## come back fresh next time.
func _enter_shadow_form(ring: ItemData) -> void:
	var stats = player.get_stats()
	if stats.shadow_form_tempo > 0:
		return
	stats.enter_shadow_form(tempo_manager.global_tempo)
	player.get_buff_manager().apply_buff(Buff.create_invisible(10, "Shadow Form"))
	_set_player_invisible(true)
	add_battle_log("You slip into shadow form — and you are not alone here.", Color(0.6, 0.5, 0.85))
	var count: int = 2 if ring.item_level >= 3 else 3
	var stored: Array = ring.ring_counters.get("wraiths", [])
	var player_cell = grid_manager.world_to_grid(player.position)
	for i in range(count):
		var cell := _random_free_cell_near(player_cell, 10)
		var world = grid_manager.grid_to_world(cell)
		if dungeon_manager:
			world.y = dungeon_manager.get_elevation_world_y(cell)
		var wraith = enemy_spawner.spawn_enemy(Enemy.EnemyType.RING_WRAITH, world)
		if i < stored.size() and stored[i] is Dictionary:
			var s: Dictionary = stored[i]
			wraith.current_health = clampi(int(s.get("hp", wraith.max_health)), 1, wraith.max_health)
			for k in ["burn_stacks", "cold_stacks", "poison_stacks", "shock_stacks",
					"bleed_stacks", "weaken_stacks", "vulnerable_stacks", "slow_stacks"]:
				wraith.set(k, int(s.get(k, 0)))
			wraith._update_status_indicators()
		_wraiths.append(wraith)
	_refresh_unit_tracker()

## Shadow form ended (expiry or badge click): the wraiths vanish, remembering
## everything.
func _on_shadow_form_ended() -> void:
	var ring: ItemData = null
	if player.get_inventory():
		for r in player.get_inventory().equipped_rings:
			if r != null and r.item_name == "The Precious":
				ring = r
				break
	var stored: Array = []
	for w in _wraiths:
		if is_instance_valid(w) and w.is_alive():
			var s: Dictionary = {"hp": w.current_health}
			for k in ["burn_stacks", "cold_stacks", "poison_stacks", "shock_stacks",
					"bleed_stacks", "weaken_stacks", "vulnerable_stacks", "slow_stacks"]:
				s[k] = int(w.get(k))
			stored.append(s)
			enemy_spawner.despawn_enemy(w)
	_wraiths.clear()
	if ring:
		ring.ring_counters["wraiths"] = stored
	var bm = player.get_buff_manager()
	if bm and bm.is_invisible():
		bm.remove_buff(Buff.BuffType.INVISIBLE)
	_set_player_invisible(false)
	add_battle_log("The shadow lifts. The wraiths withdraw — for now.", Color(0.6, 0.5, 0.85))
	_refresh_unit_tracker()

## A random unoccupied cell within `radius` squares (falls back to beside the
## anchor when the shadow is crowded).
func _random_free_cell_near(anchor: Vector2i, radius: int) -> Vector2i:
	for _try in range(40):
		var off := Vector2i(randi_range(-radius, radius), randi_range(-radius, radius))
		if off == Vector2i.ZERO:
			continue
		var c := anchor + off
		if not (c in player.blocked_tiles) and not (c in _living_enemy_cells()):
			return c
	return anchor + Vector2i(1, 1)

## Draupnir: drip a duplicate of the bearer. Normally blocked while one
## walks; the one exception is Jeremy's doubled fire, which lands on the same
## frame as the first and is allowed through.
func _spawn_draupnir_clone(ring: ItemData) -> void:
	var stats = player.get_stats()
	if stats.draupnir_clone_alive and Engine.get_process_frames() != _draupnir_spawn_frame:
		return
	var player_cell = grid_manager.world_to_grid(player.position)
	var spawn_cell = player_cell + Vector2i(1, 0)
	for off in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1), Vector2i(1,1), Vector2i(-1,-1)]:
		var c = player_cell + off
		if not (c in player.blocked_tiles) and not (c in _living_enemy_cells()):
			spawn_cell = c
			break
	var hp: int = maxi(1, floori(stats.max_health * (0.5 if ring.item_level >= 3 else 0.25)))
	var clone = CloneScript.new()
	add_child(clone)
	clone.setup(grid_manager, grid_manager.grid_to_world(spawn_cell), hp)
	clone.died.connect(func(c):
		_garmr_death_stack(c.position)
		_clones.erase(c)
		var st = player.get_stats()
		if st:
			st.draupnir_clone_alive = _clones.size() > 0
			player.get_buff_manager().apply_buff(Buff.create_strengthen(10, 2, "Draupnir"))
			add_battle_log("The duplicate shatters — Strengthen 10 for 2 attacks.", Color(0.9, 0.8, 0.4)))
	_clones.append(clone)
	stats.draupnir_clone_alive = true
	_draupnir_spawn_frame = Engine.get_process_frames()
	add_battle_log("Draupnir drips — a duplicate of you steps out (%d HP)." % hp, Color(0.9, 0.8, 0.4))

## Per-tempo clone AI: 2 tiles per 3 tempo toward the nearest enemy; swings
## every 7 tempo for a fraction of the bearer's basic attack, computed at the
## moment it lands. Its swings feed the bearer's attack-speed counter.
func _update_clones(amount: int) -> void:
	if _clones.is_empty():
		return
	_clones = _clones.filter(func(c): return is_instance_valid(c) and not c.is_dead)
	if not grid_manager or not enemy_spawner:
		return
	var stats = player.get_stats()
	var dmg_frac := 0.5
	if player.get_inventory():
		for r in player.get_inventory().equipped_rings:
			if r != null and r.item_name == "Draupnir" and r.item_level >= 3:
				dmg_frac = 0.75
	var enemies = enemy_spawner.get_living_enemies()
	var blocked = player.blocked_tiles
	var clone_cells: Array = []
	for c in _clones:
		clone_cells.append(c.get_cell())
	for c in _clones.duplicate():
		if not is_instance_valid(c) or c.is_dead:
			continue
		var target_enemy = _nearest_enemy_to(c.position, enemies)
		if target_enemy == null:
			continue
		var tcell = grid_manager.world_to_grid(target_enemy.position)
		c.attack_accum += amount
		if _manhattan(c.get_cell(), tcell) <= 1:
			if c.attack_accum >= c.ATTACK_INTERVAL:
				c.attack_accum -= c.ATTACK_INTERVAL
				var dmg: int = maxi(1, floori(stats.get_basic_attack_damage() * dmg_frac))
				target_enemy.take_damage(dmg, true)
				stats.register_attack(false)  # the echo advances the DEX counter, nothing else
				add_battle_log("Your duplicate strikes %s for %d!" % [target_enemy.enemy_name, dmg], Color(0.9, 0.8, 0.4))
				_belthronding_share(c.position, dmg)
			continue
		c.move_accum += amount
		if c.move_accum >= c.MOVE_INTERVAL:
			c.move_accum -= c.MOVE_INTERVAL
			var cur = c.get_cell()
			clone_cells.erase(cur)
			for _step in range(c.MOVE_STEPS):
				var tc = grid_manager.world_to_grid(target_enemy.position)
				if _manhattan(cur, tc) <= 1:
					break
				var nxt = _rat_step_toward(cur, tc, blocked, _living_enemy_cells(), clone_cells)
				if nxt == cur:
					break
				cur = nxt
			clone_cells.append(cur)
			if cur != c.get_cell():
				c.move_to_cell(cur)
	_clones = _clones.filter(func(c): return is_instance_valid(c) and not c.is_dead)
	if stats:
		stats.draupnir_clone_alive = _clones.size() > 0

## Marvolo Gaunt just saved the bearer — now the ring misunderstands. The
## debuff is real and purgeable; only NATURAL expiry detonates it.
func _on_marvolo_triggered() -> void:
	var dm = player.get_debuff_manager()
	if dm:
		dm.apply_debuff(Debuff.create_generic("Marvolo's Misunderstanding",
			"The ring's gift, misunderstood: take 25 damage when this expires — unless it is purged first.",
			25, 7, "Marvolo Gaunt"))
	add_battle_log("Marvolo Gaunt refuses your death — but the ring misunderstands.", Color(0.7, 0.9, 0.5))

func _on_player_debuff_expired(debuff: Debuff) -> void:
	if debuff.debuff_type == Debuff.DebuffType.GENERIC and debuff.source_name == "Marvolo Gaunt":
		player.get_stats().take_direct_damage(debuff.value)
		add_battle_log("Marvolo's Misunderstanding lands: %d damage." % debuff.value, Color(0.9, 0.4, 0.4))

func _on_player_buff_applied_ring(buff: Buff) -> void:
	if player and player.get_inventory():
		player.get_inventory().on_player_buff_applied(buff.buff_type)

## Cyclops Ring: a single player hit of 25+ counts. Only the ring's OWN two
## empowered hits are excluded — a Strengthen from any other source counts
## fine. The exclusion is tracked as a 2-hit counter set when the ring fires.
func _ring_note_big_hit(damage: int) -> void:
	if damage <= 0 or player == null or player.get_inventory() == null:
		return
	for r in player.get_inventory().equipped_rings:
		if r != null and r.item_name == "Cyclops Ring" and int(r.ring_counters.get("empowered", 0)) > 0:
			r.ring_counters["empowered"] = int(r.ring_counters["empowered"]) - 1
			return
	if damage < 25:
		return
	player.get_inventory().on_player_big_hit()

# ============================================
# SMOKE ZONES (smoke bomb) & GAUNTLET TRIGGERS
# ============================================

## Allies inside a cloud (2-square radius) stay invisible and hold +10% crit.
func _update_smoke_zones(amount: int) -> void:
	# Reset the smoke crit; re-applied below for anyone still inside a cloud.
	for p in _all_players():
		if is_instance_valid(p) and p.get_stats():
			p.get_stats().aura_crit_bonus = 0.0
	if _smoke_zones.is_empty():
		return
	var survivors: Array = []
	for zone in _smoke_zones:
		zone["tempo"] -= amount
		for p in _all_players():
			if not is_instance_valid(p) or not p.get_stats():
				continue
			if grid_manager.get_distance_in_cells(zone["position"], p.position) <= 2:
				p.get_stats().aura_crit_bonus = 10.0
				var bm = p.get_buff_manager()
				if bm:
					bm.apply_buff(Buff.create_invisible(2, "smoke bomb"))
		if zone["tempo"] > 0:
			survivors.append(zone)
	_smoke_zones = survivors

## Return Cut: armor just ate an entire enemy hit.
func _on_attack_fully_blocked() -> void:
	_shields_on_attack_blocked()
	if not deck_manager:
		return
	var triggered = deck_manager.trigger_reactions("on_attack_blocked")
	for card in triggered:
		card.execute(null, player.get_stats(), deck_manager, 0.0, 0.0, player.get_buff_manager())
	if triggered.size() > 0:
		_refresh_unit_tracker()

## Shields pass: armor swallowed an entire hit. The Sword Breaker taxes the
## melee swing that failed, and the Crooked Dueling Shield punishes the duelist
## who tried it.
func _shields_on_attack_blocked() -> void:
	if not player or not player.get_inventory():
		return
	var stats = player.get_stats()
	var attacker = stats.last_attacker if stats else null
	if attacker == null or not is_instance_valid(attacker):
		return
	var reach_diff: Vector3 = attacker.position - player.position
	var in_melee: bool = Vector3(reach_diff.x, 0, reach_diff.z).length() <= 1.5
	for shield in player.get_inventory().get_equipped_shields():
		if shield.blocked_melee_tempo_tax > 0 and in_melee and "next_melee_tempo_tax" in attacker:
			attacker.next_melee_tempo_tax = shield.blocked_melee_tempo_tax
			add_battle_log("%s: %s's next swing comes %d tempo late" % [shield.item_name,
				attacker.enemy_name, shield.blocked_melee_tempo_tax], Color(0.7, 0.8, 1.0))
		if shield.duelist_shield and attacker.has_method("apply_debuff"):
			# Weaken the attacker that isn't Weakened yet; punish the one that is.
			if "weaken_stacks" in attacker and attacker.weaken_stacks > 0:
				attacker.take_damage(5, true)
				add_battle_log("%s: 5 damage through the parry" % shield.item_name, Color(0.8, 0.85, 1.0))
			else:
				attacker.apply_debuff("weaken", 2)
				add_battle_log("%s: %s is Weakened 2" % [shield.item_name, attacker.enemy_name], Color(0.8, 0.85, 1.0))

## Spiked Mitts: bank armor gained; every threshold, gain thorns.
func _on_armor_gained_spiked(amount: int) -> void:
	if not player:
		return
	var inv = player.get_inventory()
	if not inv:
		return
	# Umbral Eclipse: every armor gain lashes out at an enemy in melee range.
	for ue_w in inv.equipped_weapons:
		if ue_w and ue_w.armor_gain_melee_damage > 0 and enemy_spawner and grid_manager:
			var ue_victim = _nearest_enemy_to(player.position, enemy_spawner.get_living_enemies())
			if ue_victim and grid_manager.get_distance_in_cells(player.position, ue_victim.position) <= 1.5:
				ue_victim.take_damage(ue_w.armor_gain_melee_damage, true)
				add_battle_log("%s: %d moonlit damage to %s" % [ue_w.item_name, ue_w.armor_gain_melee_damage, ue_victim.enemy_name], Color(0.6, 0.6, 0.9))
			break
	for g in inv.equipped_gauntlets:
		if g and g.armor_gain_thorns_threshold > 0:
			_spiked_armor_accum += amount
			while _spiked_armor_accum >= g.armor_gain_thorns_threshold:
				_spiked_armor_accum -= g.armor_gain_thorns_threshold
				var bm = player.get_buff_manager()
				if bm:
					bm.apply_buff(Buff.create_thorns(g.armor_gain_thorns_amount, 15, g.item_name))
					add_battle_log("%s: +%d thorns!" % [g.item_name, g.armor_gain_thorns_amount], Color(0.8, 0.7, 0.5))
			return

## World-scale gauntlet skills (need grid/enemies/tempo — routed from inventory).
func _on_gauntlet_world_skill(effect_id: String, gauntlet: ItemData, target) -> void:
	var stats = player.get_stats() if player else null
	match effect_id:
		"coming_in":
			# Pull yourself to the target from up to 5 squares.
			if target and is_instance_valid(target) and grid_manager:
				if grid_manager.get_distance_in_cells(player.position, target.position) > 5:
					add_battle_log("Coming in!: too far — 5 squares max", Color(1.0, 0.4, 0.4))
					return
				var tcell = grid_manager.world_to_grid(target.position)
				for off in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var c = tcell + off
					if not (c in player.blocked_tiles) and not (c in _living_enemy_cells()):
						player.blink_to(grid_manager.grid_to_world(c))
						progression_triggers._trigger_skill_tree_on_displacement()
						add_battle_log("Coming in!", Color(0.6, 0.8, 1.0))
						return
		"suck":
			# Pull every enemy within 2 squares of the cursor point toward it.
			var center = grid_manager.snap_to_grid(get_mouse_world_position())
			var pulled := 0
			for e in enemy_spawner.get_living_enemies():
				if not e or not is_instance_valid(e):
					continue
				if grid_manager.get_distance_in_cells(center, e.position) <= 2:
					var ccell = grid_manager.world_to_grid(center)
					for off in [Vector2i.ZERO, Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
						var c = ccell + off
						var taken := false
						for other in enemy_spawner.get_living_enemies():
							if other != e and is_instance_valid(other) and grid_manager.world_to_grid(other.position) == c:
								taken = true
								break
						if not taken and not (c in player.blocked_tiles):
							e.position = grid_manager.grid_to_world(c)
							pulled += 1
							break
			add_battle_log("Suck: %d enem%s pulled in!" % [pulled, "y" if pulled == 1 else "ies"], Color(0.6, 0.5, 0.9))
		"zeet":
			if target and is_instance_valid(target) and target.has_method("take_damage") and stats:
				var zdmg: int = int(stats.intelligence / 2.0)
				target.take_damage(zdmg, true, DamageTypes.Type.LIGHTNING)
				add_battle_log("Zeet! %d lightning damage" % zdmg, Color(0.5, 0.8, 1.0))
				# Lv.3: one bounce for quarter damage to an enemy near the target.
				if gauntlet.item_level >= 3:
					var bounce = null
					var bd := INF
					for e in enemy_spawner.get_living_enemies():
						if e != target and is_instance_valid(e) and grid_manager.get_distance_in_cells(target.position, e.position) <= 2:
							var d = target.position.distance_to(e.position)
							if d < bd:
								bd = d
								bounce = e
					if bounce:
						bounce.take_damage(maxi(1, zdmg / 4), true, DamageTypes.Type.LIGHTNING)
						add_battle_log("Zeet bounces to %s!" % bounce.enemy_name, Color(0.5, 0.8, 1.0))
		"slice":
			# A basic melee strike (fist formula: STR-scaled from 0 base), 2 tempo.
			if target and is_instance_valid(target) and target.has_method("take_damage") and stats:
				var sdmg: int = stats.get_effective_physical_damage(0)
				var bm = player.get_buff_manager()
				if bm and bm.roll_crit():
					sdmg = Card.crit_multiply(sdmg, stats, target)
				target.take_damage(sdmg, true)
				tempo_manager.add_tempo(2)
				add_battle_log("Slice! %d damage (2 tempo)" % sdmg, Color(0.9, 0.7, 0.5))
		"lethal_poke":
			# 0-base melee; a crit is multiplied a further x1.5 on top.
			if target and is_instance_valid(target) and target.has_method("take_damage") and stats:
				var pdmg: int = stats.get_effective_physical_damage(0)
				var pbm = player.get_buff_manager()
				if pbm and pbm.roll_crit():
					pdmg = floori(float(Card.crit_multiply(pdmg, stats, target)) * 1.5)
					add_battle_log("Lethal Poke CRITS!", Color(1.0, 0.5, 0.5))
				target.take_damage(pdmg, true)
				add_battle_log("Lethal Poke: %d damage" % pdmg, Color(0.8, 0.8, 0.8))
		"well_placed_guard":
			var bm2 = player.get_buff_manager()
			if bm2:
				bm2.apply_buff(Buff.create_thorns(5, 15, "Well placed guard"))
				add_battle_log("Well placed guard: +5 thorns", Color(0.8, 0.7, 0.5))
		"imbue_tree":
			var bm3 = player.get_buff_manager()
			if bm3:
				bm3.apply_buff(Buff.create_regen(5, 15, "imbue tree"))
				bm3.apply_buff(Buff.create_thorns(10, 15, "imbue tree"))
				add_battle_log("imbue tree: +5 regen, +10 thorns", Color(0.5, 0.9, 0.5))
		_:
			print("[MAIN] Unknown gauntlet world skill: %s" % effect_id)

func _clear_fire_spots() -> void:
	for spot in _fire_spots:
		if is_instance_valid(spot["node"]):
			spot["node"].queue_free()
	_fire_spots.clear()

## Corset of Cure: a debuff leaving the player conjures the belt's tonic.
func _on_player_debuff_removed(_debuff) -> void:
	if not player or not deck_manager:
		return
	var inv = player.get_inventory()
	if not inv:
		return
	for belt in inv.equipped_belts:
		if belt and belt.debuff_removed_conjure_id != "":
			var tonic = deck_manager._create_card_from_id(belt.debuff_removed_conjure_id)
			if tonic:
				deck_manager.add_card_to_hand(tonic)
				add_battle_log("%s: a %s appears in your hand" % [belt.item_name, tonic.card_name], Color(0.9, 0.6, 0.7))
			return

## Briarhide Plate / Adimantium: a hit breaking through the player's armor
## makes armored chests react ("exposed" per the chest spec = armor broken).
func _on_player_armor_broken() -> void:
	if player and player.get_inventory():
		player.get_inventory().on_player_exposed()
	# Reverberate Regrowth (Steve Rodgers, maintained): the armor that hit ate
	# comes back 5 tempo later. Only one debt is carried at a time.
	if not player or not deck_manager or not deck_manager.has_method("get_maintained_cards"):
		return
	var rr_stats = player.get_stats()
	if rr_stats == null or rr_stats.last_exposed_armor <= 0:
		return
	for rr in deck_manager.get_maintained_cards():
		if rr and rr.card_id == "reverberate_regrowth":
			rr_stats.pending_armor_return = rr_stats.last_exposed_armor
			rr_stats.pending_armor_return_tempo = 5
			add_battle_log("Reverberate Regrowth: %d armor will echo back in 5 tempo" % rr_stats.last_exposed_armor,
				Color(0.6, 0.75, 1.0))
			return

## Coffin Lid's Curse of the Living: the halved heal's leftover is passed on to
## every ally. from_ally = true so nothing bounces back through the curse.
func _on_curse_of_the_living_shared(amount: int) -> void:
	if amount <= 0:
		return
	var healed_any := 0
	for ally in _all_players():
		if ally == player or not is_instance_valid(ally) or not ally.get_stats():
			continue
		ally.get_stats().heal(amount, true)
		healed_any += 1
	if healed_any > 0:
		add_battle_log("Curse of the Living: %d ally(s) healed %d" % [healed_any, amount], Color(0.6, 0.5, 0.75))

## Shields pass: the per-cycle grants (Vanguard's Regen, Spiked Shield's Thorns).
func _shield_on_cycle_passives() -> void:
	if not player or not player.get_inventory():
		return
	var buff_mgr = player.get_buff_manager()
	if not buff_mgr:
		return
	for shield in player.get_inventory().get_equipped_shields():
		if shield.regen_per_cycle > 0:
			buff_mgr.apply_buff(Buff.create_regen(shield.regen_per_cycle, 15, shield.item_name))
		if shield.thorns_per_cycle > 0:
			buff_mgr.apply_buff(Buff.create_thorns(shield.thorns_per_cycle, 15, shield.item_name))

## A draw overflowed a full hand. Every equipped Overdraw rider collects.
func _on_overdraw_processed(_card: Card) -> void:
	if not player or not player.get_inventory():
		return
	var stats = player.get_stats()
	var buff_mgr = player.get_buff_manager()
	for shield in player.get_inventory().get_equipped_shields():
		if shield.overdraw_heal > 0 and stats:
			stats.heal(shield.overdraw_heal)
		if shield.overdraw_regen > 0 and buff_mgr:
			buff_mgr.apply_buff(Buff.create_regen(shield.overdraw_regen, 15, shield.item_name))
			add_battle_log("%s: Overdraw — +%d Regen" % [shield.item_name, shield.overdraw_regen], Color(0.5, 0.85, 0.5))
		if shield.overdraw_peak > 0:
			_overdraw_peak(shield)
		if shield.overdraw_card_id != "":
			_overdraw_conjure_to_manifest(shield)
		if shield.overdraw_spell_id != "":
			_overdraw_cast_spell(shield)

## Delfins: Peak reveals the top of the draw pile — up to X cards deep.
func _overdraw_peak(shield: ItemData) -> void:
	if not deck_manager or deck_manager.draw_pile.is_empty():
		return
	var depth: int = mini(shield.overdraw_peak, deck_manager.draw_pile.size())
	var names: Array[String] = []
	for i in range(depth):
		var seen: Card = deck_manager.draw_pile[deck_manager.draw_pile.size() - 1 - i]
		names.append(seen.card_name)
	# The peaked slot shows the very next card; the rest are named in the log.
	deck_manager.peaked_card = deck_manager.draw_pile.back()
	deck_manager.card_peaked.emit(deck_manager.peaked_card)
	add_battle_log("%s: Peak %d — %s" % [shield.item_name, depth, ", ".join(names)], Color(0.7, 0.8, 1.0))

## Slotted Rope Half Sleeve: a Cinquedea drops into the manifest zone, and each
## one waiting there stiffens your block cards by 1.
func _overdraw_conjure_to_manifest(shield: ItemData) -> void:
	if not overflow_manager:
		return
	if shield.conjured_in_manifest >= shield.overdraw_card_max:
		return
	var blade = Card.create_by_id(shield.overdraw_card_id)
	if blade == null:
		return
	overflow_manager.manifest_zone.append({
		"card": blade,
		"effect": null,
		"manifest_name": blade.card_name,
		"manifest_id": shield.overdraw_card_id,
		"manifest_description": blade.description,
		"manifest_value": blade.base_damage,
		"mana_cost": blade.mana_cost,
		"tempo_cost": blade.tempo_cost,
		"source_item": shield,
	})
	shield.conjured_in_manifest += 1
	if shield.overdraw_card_block > 0 and player.get_stats():
		player.get_stats().equipment_defense_card_block += shield.overdraw_card_block
	overflow_manager.manifest_card_added.emit(blade.card_name, blade)
	overflow_manager.overflow_effects_changed.emit()
	add_battle_log("%s: a %s waits in the manifest zone (%d/%d)" % [shield.item_name,
		blade.card_name, shield.conjured_in_manifest, shield.overdraw_card_max], Color(0.8, 0.8, 0.6))

## Castle wall: Overdraw looses Rain of Arrows — it costs a charge AND its mana.
## Short of either, the heal still lands and the arrows simply don't fly.
func _overdraw_cast_spell(shield: ItemData) -> void:
	var stats = player.get_stats()
	if stats == null:
		return
	if shield.overdraw_charges_left <= 0:
		add_battle_log("%s: no Overdraw charge — the archers are reloading" % shield.item_name, Color(0.7, 0.6, 0.5))
		return
	if not stats.spend_mana(shield.overdraw_spell_mana):
		add_battle_log("%s: not enough mana for %s" % [shield.item_name, shield.overdraw_spell_id], Color(0.7, 0.6, 0.5))
		return
	shield.overdraw_charges_left -= 1
	match shield.overdraw_spell_id:
		"rain_of_arrows":
			var rained = enemy_spawner.get_enemies_in_radius(player.position, 3.0)
			for en in rained:
				if en and is_instance_valid(en):
					en.take_damage(10, true)
			add_battle_log("Rain of Arrows! 10 damage to %d enem%s (%d charge(s) left)" % [rained.size(),
				"y" if rained.size() == 1 else "ies", shield.overdraw_charges_left], Color(0.85, 0.8, 0.5))
		_:
			print("[MAIN] Unknown Overdraw spell: %s" % shield.overdraw_spell_id)

## Boots of Speed: enough movement flash spent → shave 1 tempo off a hand card.
func _on_movement_flash_threshold() -> void:
	if not deck_manager or deck_manager.hand.is_empty():
		return
	# Prefer a card whose effective tempo can still drop. The reduction rides
	# temp_hand_tempo_reduction, so it lasts until the card is played or
	# discarded — never a permanent change to the card.
	var candidates: Array = []
	for c in deck_manager.hand:
		if c and c.get_burden_tempo_cost() > 0:
			candidates.append(c)
	if candidates.is_empty():
		return
	var pick = candidates[randi() % candidates.size()]
	pick.temp_hand_tempo_reduction += 1
	add_battle_log("Boots of Speed: -1 tempo on %s (until played or discarded)" % pick.card_name, Color(0.7, 0.9, 1.0))
	update_deck_info()

## Cyde Livingstons Sneakers: a run of consecutive attacks draws a card.
func _on_consecutive_attacks_reached() -> void:
	if not deck_manager:
		return
	deck_manager.draw_card()
	add_battle_log("Cyde Livingstons Sneakers: 5 attacks — draw a card!", Color(0.7, 0.9, 0.7))
	update_deck_info()

## Returns a random living enemy within `tiles` of the player, or null.
func _random_enemy_within(tiles: int):
	var candidates: Array = []
	for e in enemy_spawner.get_living_enemies():
		if e and is_instance_valid(e) and grid_manager.get_distance_in_cells(player.position, e.position) <= tiles:
			candidates.append(e)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]

## Feathered Hat: accumulate flash points spent; once the wearer has spent the
## helm's threshold, arm a guaranteed crit for the next ranged offensive card.
func _on_action_points_spent(pool: String, amount: int) -> void:
	if pool != "flash" or not player or amount <= 0:
		return
	var inv = player.get_inventory()
	var stats = player.get_stats()
	if not inv or not stats:
		return
	var threshold := 0
	for helm in inv.equipped_helms:
		if helm and helm.flash_crit_threshold > 0:
			threshold = helm.flash_crit_threshold
			break
	if threshold <= 0:
		return
	stats.flash_crit_accum += amount
	if stats.flash_crit_accum >= threshold and not stats.flash_crit_armed:
		stats.flash_crit_accum -= threshold  # carry any overflow toward the next one
		stats.flash_crit_armed = true
		add_battle_log("Feathered Hat: your next ranged attack will crit!", Color(0.8, 0.9, 1.0))

## Helm passives that tick once per tempo cycle (5 tempo):
##   - Horned Nasal Helm: purge N random debuffs off the wearer.
##   - Mane of Narashimha: refresh a +damage "void resistance" aura on enemies
##     within radius, and clear it from those who left the aura.
func _helm_on_cycle_passives() -> void:
	if not player:
		return
	var inv = player.get_inventory()
	if not inv:
		return
	var purge_count := 0
	var purge_interval := 1
	var aura_percent := 0.0
	var aura_radius := 0
	var summon_heal := 0
	for helm in inv.equipped_helms:
		if not helm:
			continue
		if helm.auto_purge_per_cycle > 0:
			purge_count += helm.auto_purge_per_cycle
			purge_interval = maxi(purge_interval, helm.auto_purge_interval_cycles)
		if helm.void_resistance_percent > aura_percent:
			aura_percent = helm.void_resistance_percent
			aura_radius = helm.void_resistance_radius
		summon_heal = maxi(summon_heal, helm.summon_heal_aura)

	# Gauntlet cycle passives: Cuffs of Current free draw; 3 count cooldown tick.
	if _three_count_cd > 0:
		_three_count_cd -= 1
	var cuffs_every := 0
	for g in inv.equipped_gauntlets:
		if g and g.draw_every_cycles > 0:
			cuffs_every = g.draw_every_cycles
			break
	if cuffs_every > 0:
		_cuffs_cycle_accum += 1
		if _cuffs_cycle_accum >= cuffs_every:
			_cuffs_cycle_accum = 0
			if deck_manager:
				deck_manager.draw_card()
				add_battle_log("Cuffs of Current: free draw", Color(0.5, 0.8, 1.0))
	else:
		_cuffs_cycle_accum = 0

	# Auto-purge runs on its own cadence (Horned Nasal: every 3 cycles).
	if purge_count > 0:
		_purge_cycle_accum += 1
		if _purge_cycle_accum < purge_interval:
			purge_count = 0  # not this cycle
		else:
			_purge_cycle_accum = 0
	else:
		_purge_cycle_accum = 0

	# Frankensteins Screws: heal summons below 25% HP within 3 tiles of the wearer.
	if summon_heal > 0 and grid_manager:
		for m in _frankensteins:
			if not is_instance_valid(m) or m.is_dead:
				continue
			if m.get_health_percent() < 0.25 and grid_manager.get_distance_in_cells(player.position, m.position) <= 3:
				m.heal(summon_heal)

	# Auto-purge: remove up to purge_count random debuffs from the wearer.
	if purge_count > 0:
		var dm = player.get_debuff_manager()
		if dm and dm.debuffs.size() > 0:
			var list = dm.debuffs.duplicate()
			list.shuffle()
			var removed := 0
			for i in range(min(purge_count, list.size())):
				dm.remove_debuff(list[i].debuff_type)
				removed += 1
			if removed > 0:
				add_battle_log("Horned Nasal Helm purges %d debuff(s)" % removed, Color(0.7, 0.6, 0.9))

	# Boots: keep the high-ground flag current, and read Jordan's missing-life rate.
	var stats = player.get_stats()
	if stats:
		stats.on_high_ground = _is_on_high_ground(player.position)
	var jordan_rate := 0.0
	var jordan_threshold := 0
	var greaves_regen := 0
	var greaves_radius := 0
	var greaves_resist := 0.0
	for boot in inv.equipped_boots:
		if boot and boot.missing_life_damage_rate > 0.0 and jordan_rate == 0.0:
			jordan_rate = boot.missing_life_damage_rate
			jordan_threshold = boot.missing_life_threshold
		if boot and boot.ally_regen_per_cycle > 0 and greaves_regen == 0:
			greaves_regen = boot.ally_regen_per_cycle
			greaves_radius = boot.ally_regen_radius
			greaves_resist = boot.ally_physical_resist

	# Guardian Greaves aura: allies (players and summons) within the radius are
	# healed and given mana each cycle; players also hold 5% physical resist
	# while inside. Resist is presence-based — reset first, then re-applied.
	for ally in _all_players():
		if is_instance_valid(ally) and ally.get_stats():
			ally.get_stats().aura_physical_resist = 0.0
	if greaves_regen > 0 and grid_manager:
		for ally in _all_players():
			if not is_instance_valid(ally) or grid_manager.get_distance_in_cells(player.position, ally.position) > greaves_radius:
				continue
			var a_st = ally.get_stats()
			if a_st:
				# Aura regen is not an "actual heal" — ring counters skip it.
				a_st._passive_heal = true
				a_st.heal(greaves_regen)
				a_st._passive_heal = false
				a_st.gain_mana(greaves_regen)
				a_st.aura_physical_resist = greaves_resist
		for m in _frankensteins:
			if is_instance_valid(m) and not m.is_dead and grid_manager.get_distance_in_cells(player.position, m.position) <= greaves_radius:
				m.heal(greaves_regen)

	# Void-resistance aura (Mane): presence-based, refreshed every cycle so it
	# follows the player. Also stamp Jordan's missing-life rate on every enemy.
	if enemy_spawner and grid_manager:
		for e in enemy_spawner.get_living_enemies():
			if not e or not is_instance_valid(e):
				continue
			if aura_percent > 0.0 and grid_manager.get_distance_in_cells(player.position, e.position) <= aura_radius:
				e.void_resistance_percent = aura_percent
			else:
				e.void_resistance_percent = 0.0
			e.missing_life_damage_rate = jordan_rate
			e.missing_life_threshold = jordan_threshold

## Dragon Skull: on a landed crit, breathe a fire cone in front of the wearer.
## Damage = the helm's base + INT/2 (spell-style scaling), fire-typed.
func _helm_crit_fire_cone(target) -> void:
	if not player or not enemy_spawner or not grid_manager:
		return
	if target == null or not is_instance_valid(target):
		return  # need a target to orient the cone
	var inv = player.get_inventory()
	if not inv:
		return
	var stats = player.get_stats()
	var intel: int = stats.intelligence if stats else 0
	for helm in inv.equipped_helms:
		if not helm or helm.crit_fire_cone_damage <= 0:
			continue
		var dmg: int = helm.crit_fire_cone_damage + int(intel / 2.0)
		var direction: Vector3 = (target.position - player.position)
		direction.y = 0.0
		if direction.length() < 0.01:
			continue
		direction = direction.normalized()
		var length := float(helm.crit_fire_cone_range) * grid_manager.grid_size
		var hit := enemy_spawner.get_enemies_in_cone(player.position, direction, length, 45.0)
		for e in hit:
			if e and is_instance_valid(e) and e.has_method("take_damage"):
				e.take_damage(dmg, true, DamageTypes.Type.FIRE)
		if not hit.is_empty():
			add_battle_log("%s breathes fire! %d damage to %d enemies" % [helm.item_name, dmg, hit.size()], Color(1.0, 0.5, 0.1))

func _is_target_in_card_range(card: Card, target) -> bool:
	if not target or not target is Node3D:
		return true
	# Can't hit an enemy through a wall — needs clear line of sight.
	if target is Enemy and dungeon_manager and grid_manager:
		var from_cell = grid_manager.world_to_grid(player.position)
		var to_cell = grid_manager.world_to_grid(target.position)
		if not dungeon_manager.has_line_of_sight(from_cell, to_cell):
			return false
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
		# Sphere grid "Range +X" nodes
		if st_stats and st_stats.sphere_bonus_range > 0:
			max_range += st_stats.sphere_bonus_range
		# Helm on-self range (Dragon Skull/Monocle) + 20/20 maintain
		max_range += _helm_range_bonus(card)
		return distance_tiles <= max_range + 0.5  # Small tolerance
	else:
		# Melee: must be adjacent (within ~1.5 tiles), Reach adds 1 square.
		# Dragon Skull's "+1 range on ANY offensive card" extends melee reach too
		# (the 20/20 and Monocle parts of the helper are ranged-gated internally).
		var melee_range = 1.5
		if card.has_reach:
			melee_range += 1.0
		# Spartan Spear: Reach while a shield is up.
		if player and player.get_stats():
			melee_range += float(player.get_stats().equipment_melee_reach)
		melee_range += float(_helm_range_bonus(card))
		# Crack of Mintaka: reach at targeting time is the hand — the most cards
		# the player COULD discard; the post-discard check is authoritative.
		if card.card_id == "crack_of_mintaka" and deck_manager:
			melee_range += float(deck_manager.hand.size())
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
	# Then aim precisely at the target so the attack lines up (the cardinal
	# `dir` above only feeds animations that key off a 4-way facing).
	if target and target is Node3D and is_instance_valid(target) and player.has_method("face_toward"):
		player.face_toward(target.position)
	# Worms Armageddon: only burst the Alaskan Bull Worm when its 10% summon hits.
	if card.card_id == "worms_armageddon" and card.rng_binary_succeeded() and player.has_method("show_worm_summon"):
		player.show_worm_summon()

func _get_card_play_target_pos(target) -> Vector2:
	## Returns a screen position to animate the card toward (in hand_container local coords).
	var cam = get_world_camera()
	if target is Enemy and is_instance_valid(target) and cam:
		var screen_pos = world_to_screen(target.position + Vector3(0, 0.5, 0))
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

func _get_draw_pile_pos() -> Vector2:
	## The draw pile button's position in hand_container local coords, so drawn
	## cards visibly emerge from the pile (mirror of _get_discard_pile_pos).
	if _draw_pile_btn and is_instance_valid(_draw_pile_btn):
		var btn_global = _draw_pile_btn.get_global_rect().get_center()
		var container_global = hand_container.get_global_rect().position
		return btn_global - container_global
	return Vector2(-80, 0)

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

	# Generic helm on-self world effects (independent of card_id).
	_helm_card_world_effects(card, target)

	# Chewbaccas Bandolier: any ranged offensive card ejects a casing.
	_maybe_drop_bullet_casing(card)

	# Weapon riders that watch every resolved card (weapons pass 1).
	_weapon_post_card_effects(card, target)

	# Slotted-item riders that need the world (ranged pass 1).
	_ranged_on_self_world_effects(card, target)

	# Colored slots (Mauls Sabre): the red slot's discard cost, player-chosen.
	_colored_slot_discard(card)

	# Shield on-self riders that need the world (shields pass 1).
	_shield_on_self_world_effects(card, target)

	# Mits of Chingiz "3 count": two offensive cards in a row add a Switch Kick
	# to the hand (then a 20-tempo cooldown).
	if card.is_offensive():
		_offensive_streak += 1
	else:
		_offensive_streak = 0
	if _offensive_streak >= 2 and _three_count_cd <= 0 \
			and deck_manager.inventory and deck_manager.inventory.has_passive_effect("three_count"):
		deck_manager.add_card_to_hand(Card.create_by_id("switch_kick"))
		# Cooldown comes from the gauntlet itself so the item and its tooltip
		# stay the single source of truth.
		_three_count_cd = 4
		for tc_g in deck_manager.inventory.equipped_gauntlets:
			if tc_g and tc_g.gauntlet_skill_effect_id == "three_count":
				_three_count_cd = maxi(1, tc_g.gauntlet_skill_cooldown)
				break
		_offensive_streak = 0
		add_battle_log("3 count! A Switch Kick slides into your hand", Color(0.9, 0.8, 0.5))

	# Shadow Obi: any card cheaper than 2 tempo zaps a random enemy.
	if player and player.get_inventory():
		for zap_belt in player.get_inventory().equipped_belts:
			if zap_belt and zap_belt.cheap_card_zap_damage > 0 and card.get_burden_tempo_cost() < 2:
				var zap_victim = _random_enemy_within(9999)
				if zap_victim:
					zap_victim.take_damage(zap_belt.cheap_card_zap_damage, true)
					add_battle_log("%s: %d damage to %s" % [zap_belt.item_name, zap_belt.cheap_card_zap_damage, zap_victim.enemy_name], Color(0.5, 0.4, 0.7))
				break

	match card.card_id:
		"its_alive":
			_resurrect_frankenstein()

		"stone_encase":
			# Strap of Stone: the armor landed in execute; the self-stun is ours.
			var se_dm = player.get_debuff_manager()
			if se_dm:
				se_dm.apply_debuff(Debuff.create(Debuff.DebuffType.STUN, 0, 5))
				add_battle_log("Stone Encase: encased — stunned for 5 tempo", Color(0.7, 0.65, 0.5))

		"poof_and_weave":
			var pw_bm = player.get_buff_manager()
			if pw_bm:
				pw_bm.apply_buff(Buff.create_invisible(5, "Poof and Weave"))
				_set_player_invisible(true)
			player.get_stats().add_armor(10)
			deck_manager.draw_card()
			add_battle_log("Poof and Weave: gone in a wisp (+10 armor, +1 card)", Color(0.7, 0.7, 0.9))

		"chain_lightning":
			if target and is_instance_valid(target):
				var cl_stats = player.get_stats()
				var cl_dmg: int = cl_stats.get_effective_spell_damage(10) if cl_stats else 10
				var cl_hit: Array = []
				var cl_current = target
				while cl_dmg > 0 and cl_current and is_instance_valid(cl_current):
					cl_current.take_damage(cl_dmg, true, DamageTypes.Type.LIGHTNING)
					cl_hit.append(cl_current)
					add_battle_log("Chain Lightning arcs: %d to %s" % [cl_dmg, cl_current.enemy_name], Color(0.5, 0.8, 1.0))
					cl_dmg -= 2
					var next_hop = null
					var hop_d := INF
					for ce in enemy_spawner.get_living_enemies():
						if ce and is_instance_valid(ce) and not (ce in cl_hit) \
								and grid_manager.get_distance_in_cells(cl_current.position, ce.position) <= 3:
							var d = cl_current.position.distance_to(ce.position)
							if d < hop_d:
								hop_d = d
								next_hop = ce
					cl_current = next_hop

		"ice_grenade":
			var ig_point = grid_manager.snap_to_grid(mouse_pos)
			var ig_stats = player.get_stats()
			var ig_dmg: int = ig_stats.get_effective_spell_damage(5) if ig_stats else 5
			var ig_hits := 0
			for ie in enemy_spawner.get_living_enemies():
				if ie and is_instance_valid(ie) and grid_manager.get_distance_in_cells(ig_point, ie.position) <= 2:
					ie.take_damage(ig_dmg, true, DamageTypes.Type.ICE)
					if ie.has_method("apply_debuff"):
						ie.apply_debuff("cold", 2)
					ig_hits += 1
			add_battle_log("Ice Grenade: %d enem%s chilled for %d" % [ig_hits, "y" if ig_hits == 1 else "ies", ig_dmg], Color(0.6, 0.85, 1.0))

		"poison_bomb":
			var pbm_point = grid_manager.snap_to_grid(mouse_pos)
			var pbm_hits := 0
			for pe in enemy_spawner.get_living_enemies():
				if pe and is_instance_valid(pe) and grid_manager.get_distance_in_cells(pbm_point, pe.position) <= 2:
					if pe.has_method("apply_debuff"):
						pe.apply_debuff("poison", 6)
						pbm_hits += 1
			add_battle_log("Poison Bomb: %d enem%s poisoned (6)" % [pbm_hits, "y" if pbm_hits == 1 else "ies"], Color(0.4, 0.8, 0.3))

		"fire_punch":
			if target and is_instance_valid(target):
				var fp_stats = player.get_stats()
				var fp_dmg: int = fp_stats.get_effective_physical_damage(0) if fp_stats else 0
				var fp_bm = player.get_buff_manager()
				if fp_bm and fp_bm.roll_crit():
					fp_dmg = Card.crit_multiply(fp_dmg, fp_stats, target)
				target.take_damage(fp_dmg, true, DamageTypes.Type.FIRE)
				add_battle_log("Fire Punch: %d damage" % fp_dmg, Color(1.0, 0.5, 0.2))
				# Fire path behind the target: 2 tiles along the strike direction,
				# reusing the Trail Blazers fire-spot system (INT/5 per spot).
				var fp_dir: Vector3 = (target.position - player.position)
				fp_dir.y = 0.0
				if fp_dir.length() > 0.01:
					fp_dir = fp_dir.normalized()
					var fp_int: int = maxi(1, floori((fp_stats.intelligence if fp_stats else 0) / 5.0))
					for step in [1, 2]:
						var fp_cell = grid_manager.world_to_grid(target.position + fp_dir * float(step) * grid_manager.grid_size)
						var fp_taken := false
						for spot in _fire_spots:
							if spot["cell"] == fp_cell:
								fp_taken = true
								break
						if not fp_taken:
							var fp_node := _make_fire_spot_visual(grid_manager.grid_to_world(fp_cell))
							add_child(fp_node)
							_fire_spots.append({"cell": fp_cell, "tempo": 3, "damage": fp_int, "node": fp_node})
				# Conjure the Erase-5 copy — the copy never copies itself.
				if not card.has_meta("fire_punch_copy"):
					var fp_copy = Card.create_by_id("fire_punch")
					fp_copy.erase_tempo = 5
					fp_copy.set_meta("fire_punch_copy", true)
					deck_manager.add_card_to_hand(fp_copy)

		"crack_of_mintaka":
			var cm_target = target
			var cm_lv3: bool = card.granted_by_item != null and card.granted_by_item.item_level >= 3
			show_hand_multi_picker("Crack of Mintaka — discard how many?", func(picked: Array):
				var cm_x: int = picked.size()
				for pc in picked:
					deck_manager.discard_card_from_hand(pc)
				if cm_target == null or not is_instance_valid(cm_target):
					add_battle_log("Crack of Mintaka: no target — %d card(s) spent" % cm_x, Color(1.0, 0.4, 0.4))
					return
				var cm_dist: int = grid_manager.get_distance_in_cells(player.position, cm_target.position)
				if cm_dist > cm_x:
					add_battle_log("Crack of Mintaka: the belt falls short (%d needed, %d discarded)" % [cm_dist, cm_x], Color(1.0, 0.4, 0.4))
					return
				var cm_stats = player.get_stats()
				var cm_dmg: int = cm_stats.get_effective_physical_damage(10)
				var cm_mult: int = 5 if cm_lv3 else 3
				var cm_bonus: float = float(cm_x * cm_mult) / 100.0
				cm_stats.temp_crit_damage_bonus += cm_bonus
				var cm_bm = player.get_buff_manager()
				if cm_bm and cm_bm.roll_crit():
					cm_dmg = Card.crit_multiply(cm_dmg, cm_stats, cm_target)
					add_battle_log("Crack of Mintaka CRITS!", Color(1.0, 0.6, 0.3))
				cm_stats.temp_crit_damage_bonus = maxf(0.0, cm_stats.temp_crit_damage_bonus - cm_bonus)
				cm_target.take_damage(cm_dmg, true)
				add_battle_log("Crack of Mintaka: %d damage at range %d" % [cm_dmg, cm_x], Color(0.9, 0.8, 0.5)))

		"smoke_bomb":
			var smoke_pos = grid_manager.snap_to_grid(mouse_pos)
			_smoke_zones.append({"position": smoke_pos, "tempo": 8})
			add_battle_log("Smoke bomb! Allies inside vanish (8 tempo)", Color(0.7, 0.7, 0.7))

		"shift":
			# Rollerblades: free move, but bounded — up to 2 tiles.
			var shift_pos = grid_manager.snap_to_grid(mouse_pos)
			var shift_cell = grid_manager.world_to_grid(shift_pos)
			var shift_dist = grid_manager.get_distance_in_cells(player.position, shift_pos)
			if shift_dist > 2:
				add_battle_log("shift: too far — 2 spaces max", Color(1.0, 0.4, 0.4))
			elif shift_cell in player.blocked_tiles:
				add_battle_log("shift: cannot move into a wall or obstacle!", Color(1.0, 0.4, 0.4))
			else:
				player.blink_to(shift_pos)
				progression_triggers._trigger_skill_tree_on_displacement()

		"escape_and_bewilder":
			# Houdinis Slippers: blink up to 5; stun everyone near the vacated tile.
			var eb_origin: Vector3 = player.position
			var eb_pos = grid_manager.snap_to_grid(mouse_pos)
			var eb_cell = grid_manager.world_to_grid(eb_pos)
			if grid_manager.get_distance_in_cells(eb_origin, eb_pos) > 5:
				add_battle_log("Escape and bewilder: too far — 5 spaces max", Color(1.0, 0.4, 0.4))
			elif eb_cell in player.blocked_tiles:
				add_battle_log("Escape and bewilder: cannot blink into a wall!", Color(1.0, 0.4, 0.4))
			else:
				player.blink_to(eb_pos)
				progression_triggers._trigger_skill_tree_on_displacement()
				var stunned := 0
				for e in enemy_spawner.get_living_enemies():
					if e and is_instance_valid(e) and grid_manager.get_distance_in_cells(eb_origin, e.position) <= 3:
						e.apply_debuff("stun", 3)  # 3 tempo, as the card says
						stunned += 1
				if stunned > 0:
					add_battle_log("Escape and bewilder: %d enem%s stunned!" % [stunned, "y" if stunned == 1 else "ies"], Color(0.7, 0.7, 0.95))

		"donate_cleats":
			# Cyde Livingstons Sneakers: lend an ally (or yourself) +5 AGI / +4 DEX for 5 tempo.
			var dc_node = target if (target and is_instance_valid(target) and target.has_method("get_stats")) else player
			var dc_stats = dc_node.get_stats()
			if dc_stats:
				dc_stats.base_agility += 5
				dc_stats.base_dexterity += 4
				dc_stats.recalculate_derived_stats()
				schedule_delayed_effect(5, func():
					if is_instance_valid(dc_node) and dc_node.get_stats():
						dc_stats.base_agility -= 5
						dc_stats.base_dexterity -= 4
						dc_stats.recalculate_derived_stats(), "donate_cleats")
				add_battle_log("Donate Cleats: +5 AGI, +4 DEX for 5 tempo", Color(0.6, 0.9, 0.6))

		"terrain_formation":
			# Mountain Boots: raise a walkable hill (works under units too); 5 tempo.
			var tf_cell = grid_manager.world_to_grid(grid_manager.snap_to_grid(mouse_pos))
			var tf_handle = dungeon_manager.build_high_ground(tf_cell, 1, 1) if dungeon_manager else {}
			if tf_handle.get("cells", []).is_empty():
				add_battle_log("Terrain formation: no ground to raise there", Color(1.0, 0.4, 0.4))
			else:
				schedule_delayed_effect(5, func():
					if dungeon_manager:
						dungeon_manager.remove_high_ground(tf_handle), "terrain_formation")
				add_battle_log("Terrain formation: a hill rises! (5 tempo)", Color(0.7, 0.6, 0.4))

		"mend":
			# Guardian Greaves: allies within 4 restore 20% HP/mana + armor = health
			# restored. At item Lv.3 the restore doubles to 40%/40%.
			var mend_pct := 0.4 if (card.granted_by_item and card.granted_by_item.item_level >= 3) else 0.2
			var mend_healed := 0
			for ally in _all_players():
				if not is_instance_valid(ally) or grid_manager.get_distance_in_cells(player.position, ally.position) > 4:
					continue
				var a_st = ally.get_stats()
				if a_st:
					var heal_amt: int = maxi(1, floori(a_st.max_health * mend_pct))
					a_st.heal(heal_amt)
					a_st.gain_mana(maxi(1, floori(a_st.max_mana * mend_pct)))
					a_st.add_armor(heal_amt)
					mend_healed += 1
			for m in _frankensteins:
				if is_instance_valid(m) and not m.is_dead and grid_manager.get_distance_in_cells(player.position, m.position) <= 4:
					m.heal(maxi(1, floori(m.max_health * mend_pct)))
					mend_healed += 1
			add_battle_log("Mend: %d all%s restored" % [mend_healed, "y" if mend_healed == 1 else "ies"], Color(0.5, 0.9, 0.7))

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
				bm.apply_buff(Buff.create_blessed(2, 4, "Succumb"))
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

		"crops":
			# Shepherds Crook: 5 berry bushels at random open cells within 8
			# squares. They last until an ally eats them; enemies trample past.
			var cr_cells: Array = []
			var cr_pcell: Vector2i = grid_manager.world_to_grid(player.position)
			var cr_tries := 0
			while cr_cells.size() < 5 and cr_tries < 200:
				cr_tries += 1
				var cr_off := Vector2i(randi_range(-8, 8), randi_range(-8, 8))
				if absi(cr_off.x) + absi(cr_off.y) > 8 or cr_off == Vector2i.ZERO:
					continue
				var cr_cell: Vector2i = cr_pcell + cr_off
				if cr_cell in player.blocked_tiles or cr_cell in cr_cells:
					continue
				var cr_dup := false
				for cr_b in _berry_bushels:
					if cr_b["cell"] == cr_cell:
						cr_dup = true
						break
				if not cr_dup:
					cr_cells.append(cr_cell)
			for cr_c in cr_cells:
				_berry_bushels.append({"cell": cr_c, "node": _make_bushel_visual(cr_c)})
			add_battle_log("Crops! %d berry bushels take root." % cr_cells.size(), Color(0.5, 0.9, 0.4))

		"clear_mind":
			# Wand of Clarity: purge 3 random debuffs — whole stacks — and
			# draw 1 card for each actually purged.
			var cm_dm = player.get_debuff_manager()
			var cm_purged := 0
			if cm_dm:
				for _cm_i in range(3):
					if cm_dm.debuffs.is_empty():
						break
					var cm_pick = cm_dm.debuffs[randi() % cm_dm.debuffs.size()]
					cm_dm.remove_debuff(cm_pick.debuff_type)
					cm_purged += 1
			for _cm_d in range(cm_purged):
				deck_manager.draw_card()
			if cm_purged > 0:
				add_battle_log("Clear Mind: %d debuff(s) purged, %d card(s) drawn." % [cm_purged, cm_purged], Color(0.7, 0.9, 1.0))
			else:
				add_battle_log("Clear Mind: nothing clouding you.", Color(0.7, 0.9, 1.0))

		"grounding":
			# Reaction Rod: absorb every Shock within 10 squares — enemies,
			# allies and the wielder — then 10 damage to each enemy in radius,
			# shocked or not. (The -5 mana per Shock landed at cost time.)
			var gr_absorbed := 0
			var gr_hit: Array = []
			for gr_e in enemy_spawner.get_living_enemies():
				if gr_e and is_instance_valid(gr_e) \
						and grid_manager.get_distance_in_cells(player.position, gr_e.position) <= 10:
					gr_hit.append(gr_e)
					if gr_e.shock_stacks > 0:
						gr_absorbed += gr_e.shock_stacks
						gr_e.shock_stacks = 0
						if gr_e.has_method("_update_status_indicators"):
							gr_e._update_status_indicators()
			for gr_ally in _all_players():
				if not is_instance_valid(gr_ally) or not gr_ally.has_method("get_debuff_manager"):
					continue
				if grid_manager.get_distance_in_cells(player.position, gr_ally.position) > 10:
					continue
				var gr_adm = gr_ally.get_debuff_manager()
				if gr_adm:
					var gr_sh = gr_adm.get_debuff(Debuff.DebuffType.SHOCKED)
					if gr_sh:
						gr_absorbed += maxi(gr_sh.value, 1)
						gr_adm.remove_debuff(Debuff.DebuffType.SHOCKED)
			for gr_e2 in gr_hit:
				gr_e2.take_damage(10, true, DamageTypes.Type.LIGHTNING)
			_apply_misery_spread(gr_hit)
			add_battle_log("Grounding! %d Shock absorbed — 10 damage to %d enemies." % [gr_absorbed, gr_hit.size()], Color(1.0, 1.0, 0.4))

		"from_the_ashes":
			# Wand of the Phoenix Feather: purge every self-Burn stack; enemies
			# within 3 squares take 5 damage per stack, the wielder heals 5 per
			# stack (Lv.3: 8) and gains Regen worth half the stacks (Lv.3: 3/4).
			var fta_dm = player.get_debuff_manager()
			var fta_burn := 0
			if fta_dm:
				var fta_d = fta_dm.get_debuff(Debuff.DebuffType.BURN)
				if fta_d:
					fta_burn = maxi(fta_d.value, 0)
					fta_dm.remove_debuff(Debuff.DebuffType.BURN)
			if fta_burn > 0:
				var fta_lv3: bool = card.granted_by_item != null and card.granted_by_item.item_level >= 3
				var fta_hit = enemy_spawner.get_enemies_in_radius(player.position, 3.0)
				for fta_e in fta_hit:
					fta_e.take_damage(fta_burn * 5, true, DamageTypes.Type.FIRE)
				_apply_misery_spread(fta_hit)
				var fta_stats = player.get_stats()
				if fta_stats:
					fta_stats.heal(fta_burn * (8 if fta_lv3 else 5))
				var fta_regen: int = ceili(fta_burn * (0.75 if fta_lv3 else 0.5))
				var fta_bm = player.get_buff_manager()
				if fta_bm and fta_regen > 0:
					fta_bm.apply_buff(Buff.create_regen(fta_regen, -1, "From the Ashes"))
				add_battle_log("From the Ashes! %d Burn purged — %d damage to %d enemies, healed %d." % [fta_burn, fta_burn * 5, fta_hit.size(), fta_burn * (8 if fta_lv3 else 5)], Color(1.0, 0.5, 0.2))
			else:
				add_battle_log("From the Ashes fizzles — no Burn to purge.", Color(1.0, 0.5, 0.2))

		"sprinkle_bomb":
			# Bladed Doughnut Lv.3: the Sprinkle detonates as an AOE circle.
			var sb_center = target.position if target else grid_manager.snap_to_grid(mouse_pos)
			var sb_dmg = card.last_damage_dealt
			var sb_hit = enemy_spawner.get_enemies_in_radius(sb_center, card.aoe_range if card.aoe_range > 0 else 2.0)
			for en in sb_hit:
				en.take_damage(sb_dmg, true)
			_apply_misery_spread(sb_hit)
			add_battle_log("Sprinkle Bomb! %d damage to %d enemies" % [sb_dmg, sb_hit.size()], Color(1.0, 0.6, 0.85))
			print("[MAIN] Sprinkle Bomb hit %d enemies for %d" % [sb_hit.size(), sb_dmg])

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

		"detonova":
			# Supernova Cuirass: purge the banked stacks and vent them as fire
			# damage 2 squares around the wearer. Flat banked total — no INT.
			var dn_item = card.granted_by_item
			if dn_item:
				var dn_amount: int = floori(dn_item.banked_damage)
				dn_item.banked_damage = 0.0
				dn_item.banked_stacks = 0
				if dn_amount > 0:
					var dn_hit = enemy_spawner.get_enemies_in_radius(player.position, 2.0)
					for dn_en in dn_hit:
						dn_en.take_damage(dn_amount, true, DamageTypes.Type.FIRE)
					add_battle_log("Detonova! %d fire damage to %d enemies" % [dn_amount, dn_hit.size()], Color(1.0, 0.5, 0.1))
				else:
					add_battle_log("Detonova fizzles — nothing banked", Color(0.7, 0.6, 0.5))

		"huck":
			# Castle wall: throw the wall. Everything you were hiding behind,
			# delivered at once — and then you have nothing behind.
			var hk_stats = player.get_stats()
			var hk_armor: int = hk_stats.current_armor if hk_stats else 0
			if hk_armor <= 0:
				add_battle_log("Huck: no armor to throw", Color(0.7, 0.6, 0.5))
			elif target and is_instance_valid(target) and target.has_method("take_damage"):
				hk_stats.current_armor = 0
				hk_stats.armor_changed.emit(0)
				target.take_damage(hk_armor, true)
				add_battle_log("Huck! %d damage to %s — the wall is gone" % [hk_armor, target.enemy_name],
					Color(0.8, 0.7, 0.5))

		"bouncing_shield":
			# Steve Rodgers: the shield leaves your arm (half your armor goes
			# with it), then chains from body to body, each one sending back
			# block and temporary mana.
			var bs_stats = player.get_stats()
			if bs_stats and bs_stats.current_armor > 0:
				var bs_lost: int = floori(bs_stats.current_armor / 2.0)
				bs_stats.current_armor -= bs_lost
				bs_stats.armor_changed.emit(bs_stats.current_armor)
			var bs_hit: Array = []
			var bs_from = target
			while bs_from != null and is_instance_valid(bs_from) and bs_hit.size() < 5:
				# Remember where it struck before the hit, so a kill still tells
				# the shield where to bounce from.
				var bs_at: Vector3 = bs_from.position
				bs_from.take_damage(5, true)
				bs_hit.append(bs_from)
				var bs_next = null
				var bs_best := 99.0
				for bs_en in enemy_spawner.get_living_enemies():
					if bs_en == null or not is_instance_valid(bs_en) or bs_en in bs_hit:
						continue
					var bs_d: float = grid_manager.get_distance_in_cells(bs_at, bs_en.position)
					if bs_d <= 5.0 and bs_d < bs_best:
						bs_best = bs_d
						bs_next = bs_en
				bs_from = bs_next
			if bs_hit.size() > 0 and bs_stats:
				# A forged Bastion holds its temp mana 20 tempo instead of 15.
				var bs_tempo: int = 20 if (card.granted_by_item and card.granted_by_item.item_level >= 2) else 15
				bs_stats.add_armor(5 * bs_hit.size())
				bs_stats.add_temp_mana(10 * bs_hit.size(), bs_tempo)
				add_battle_log("Bouncing Shield! %d target(s) — +%d block, +%d temp mana for %d tempo" % [
					bs_hit.size(), 5 * bs_hit.size(), 10 * bs_hit.size(), bs_tempo], Color(0.6, 0.75, 1.0))
			else:
				add_battle_log("Bouncing Shield: it comes straight back", Color(0.7, 0.6, 0.5))

		"earth_rattle":
			# Bessy: smash the ground — a quake around the impact tile.
			var er_center: Vector3 = target.position if (target != null and is_instance_valid(target)) else grid_manager.snap_to_grid(mouse_pos)
			var er_hit = enemy_spawner.get_enemies_in_radius(er_center, 3.0)
			for er_en in er_hit:
				if er_en and is_instance_valid(er_en):
					er_en.take_damage(40, true)
					if er_en.has_method("apply_debuff"):
						er_en.apply_debuff("slow", 2)
						er_en.apply_debuff("weaken", 2)
			add_battle_log("Earth Rattle! %d enem%s quake — Slowed and Weakened" % [er_hit.size(), "y" if er_hit.size() == 1 else "ies"], Color(0.7, 0.5, 0.3))

		"wrath_of_the_sea":
			# Poseidons Trident: blink, then the sea bursts in a 4x4 around the
			# landing — damage = the mana the card drank, through the STR pipeline.
			var ws_pos = grid_manager.snap_to_grid(mouse_pos)
			var ws_cell = grid_manager.world_to_grid(ws_pos)
			if ws_cell in player.blocked_tiles:
				add_battle_log("Wrath of the Sea: cannot land there!", Color(1.0, 0.4, 0.4))
			else:
				player.blink_to(ws_pos)
				progression_triggers._trigger_skill_tree_on_displacement()
				var ws_stats = player.get_stats()
				var ws_dmg: int = ws_stats.get_effective_physical_damage(card.last_percent_mana_paid) if ws_stats else card.last_percent_mana_paid
				var ws_lv3: bool = card.granted_by_item != null and card.granted_by_item.item_level >= 3
				var ws_hits := 0
				for ws_en in enemy_spawner.get_living_enemies():
					if ws_en and is_instance_valid(ws_en):
						var ws_ec: Vector2i = grid_manager.world_to_grid(ws_en.position)
						if ws_ec.x >= ws_cell.x - 1 and ws_ec.x <= ws_cell.x + 2 \
								and ws_ec.y >= ws_cell.y - 1 and ws_ec.y <= ws_cell.y + 2:
							ws_en.take_damage(ws_dmg, true)
							if is_instance_valid(ws_en) and ws_en.has_method("knockback"):
								ws_en.knockback(ws_pos, 2)
							ws_hits += 1
				if ws_hits > 0 and ws_stats:
					ws_stats.gain_mana((18 if ws_lv3 else 15) * ws_hits)
				add_battle_log("Wrath of the Sea! %d damage to %d — the tide throws them back" % [ws_dmg, ws_hits], Color(0.3, 0.6, 0.9))

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
				target.apply_debuff("stun", 15)
				# Deal what the card face shows — the full stat-scaled number.
				var vine_dmg := _card_player_damage(card)
				for cyc in range(1, 4):
					schedule_delayed_effect(cyc * 5, _vines_tick.bind(target, vine_dmg), "vines")
				add_battle_log("Vines! Held the enemy for 3 turns (%d dmg/turn)" % vine_dmg, Color(0.4, 0.8, 0.3))
				print("[MAIN] Vines: held target, %d damage x3 cycles" % vine_dmg)

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
					hit_enemy.apply_debuff("disarmed", 5)
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

		"improvised_ammo":
			# Wrist Rocket: the played copy also weakens its target.
			if target and is_instance_valid(target) and target.has_method("apply_debuff"):
				target.apply_debuff("weaken", 3)
				add_battle_log("Improvised Ammo weakens %s (3 stacks)." % target.enemy_name, Color(0.8, 0.7, 0.5))

		"cupids_golden_arrow":
			# Cupids Bow: 2 Vulnerable always; 50% (pre-rolled) taunt; golden mark.
			if target and is_instance_valid(target):
				if target.has_method("apply_debuff"):
					target.apply_debuff("vulnerable", 2)
				if card.rng_binary_succeeded() and target.has_method("apply_taunt"):
					target.apply_taunt(player, 5)
					add_battle_log("%s is drawn helplessly toward you!" % target.enemy_name, Color(1.0, 0.75, 0.5))
				if target.has_method("apply_cupid_mark") and target.apply_cupid_mark(true):
					add_battle_log("%s turns into a tree!" % target.enemy_name, Color(0.4, 0.8, 0.4))

		"cupids_lead_arrow":
			# Cupids Bow: 2 Weaken always; 50% (pre-rolled) fear; lead mark.
			if target and is_instance_valid(target):
				if target.has_method("apply_debuff"):
					target.apply_debuff("weaken", 2)
				if card.rng_binary_succeeded() and target.has_method("apply_fear"):
					target.apply_fear(player, 5)
					add_battle_log("%s flees from you in dread!" % target.enemy_name, Color(0.75, 0.55, 0.95))
				if target.has_method("apply_cupid_mark") and target.apply_cupid_mark(false):
					add_battle_log("%s turns into a tree!" % target.enemy_name, Color(0.4, 0.8, 0.4))

		"territorial_mark":
			# Bow of Arash: the flight corridor glistens blue for 25 tempo;
			# enemies inside it are Weakened until they leave.
			if target and is_instance_valid(target) and grid_manager:
				var tm_from = grid_manager.world_to_grid(player.position)
				var tm_to = grid_manager.world_to_grid(target.position)
				_create_mark_zone(_territorial_mark_cells(tm_from, tm_to), 25)
				_update_mark_zones(0)
				add_battle_log("The arrow's path glistens with blue smoke — the land is marked.", Color(0.45, 0.65, 0.95))

		"spirit_bow":
			_summon_spirit_bow()

		"tricks_of_alberich":
			# Ring of Nibelung: taunt 4 squares; profit from every enemy caught.
			var toa_caught = enemy_spawner.get_enemies_in_radius(player.position, 4.0)
			for te in toa_caught:
				if te.has_method("apply_taunt"):
					te.apply_taunt(player, 5)  # the spec's 5 tempo
			var toa_stats = player.get_stats()
			var toa_bm = player.get_buff_manager()
			if toa_bm:
				toa_bm.apply_buff(Buff.create_might(10, 5, "Tricks of Alberich"))
			if toa_stats and toa_caught.size() > 0:
				toa_stats.add_armor(4 * toa_caught.size())
			if toa_bm and toa_caught.size() > 0:
				toa_bm.apply_buff(Buff.create_regen(2 * toa_caught.size(), 15, "Tricks of Alberich"))
			add_battle_log("Tricks of Alberich! %d enem%s taunted — +10 STR, +%d armor, %d Regen." % [
				toa_caught.size(), "y" if toa_caught.size() == 1 else "ies",
				4 * toa_caught.size(), 2 * toa_caught.size()], Color(0.9, 0.7, 0.3))

		"the_nibelung_curse":
			# The stored total goes wherever it's pointed: an enemy takes it as
			# damage; yourself (or no valid enemy target) takes it as healing.
			var nc_value: int = int(card.get_meta("curse_value", 0))
			if target != null and is_instance_valid(target) and target is Enemy:
				target.take_damage(nc_value, true)
				add_battle_log("The Nibelung Curse strikes %s for %d!" % [target.enemy_name, nc_value], Color(0.9, 0.7, 0.3))
			else:
				player.get_stats().heal(nc_value)
				add_battle_log("You embrace the Nibelung Curse: heal %d." % nc_value, Color(0.9, 0.7, 0.3))

		"worms_armageddon":
			# Rain meteors: stat-scaled damage (matching the card face) to every
			# enemy; on the 10% proc, summon two REAL Alaskan Bull Worms.
			var wa_dmg = _card_player_damage(card)
			var wa_hit = enemy_spawner.get_living_enemies()
			for en in wa_hit:
				en.take_damage(wa_dmg, true)
			_apply_misery_spread(wa_hit)
			add_battle_log("Worms Armageddon! %d damage to %d enemies" % [wa_dmg, wa_hit.size()], Color(0.6, 0.4, 0.2))
			print("[MAIN] Worms Armageddon hit %d enemies for %d" % [wa_hit.size(), wa_dmg])
			if card.rng_binary_succeeded():
				_spawn_bull_worms(2)

		"harness_lightning":
			# Orb: 4 damage every 5 tempo for 30 tempo to a random enemy within 3.
			for tick in range(1, 7):
				schedule_delayed_effect(tick * 5, _harness_lightning_tick, "harness_lightning")
			add_battle_log("Harness Lightning! An orb crackles for 30 tempo.", Color(0.7, 0.8, 1.0))
			print("[MAIN] Harness Lightning orb created.")

		"try_this":
			# Ally +3 mana pool / +2 hand size for 10 tempo (10% backfires, permanent).
			# Backfire uses the pre-rolled outcome so it matches the card preview.
			var tt_stats = target.get_stats() if target is Player else player.get_stats()
			if tt_stats:
				var tt_backfired: bool = card.rng_binary_succeeded() if card.has_been_rolled() else randf() < 0.1
				if tt_backfired:
					tt_stats.max_mana = max(10, tt_stats.max_mana - 30)
					tt_stats.adjust_temp_hand(-2)
					add_battle_log("Try This backfired! -30 mana pool, -2 hand size", Color(1.0, 0.5, 0.4))
				else:
					tt_stats.max_mana += 30
					tt_stats.adjust_temp_hand(2)
					schedule_delayed_effect(10, _try_this_revert.bind(tt_stats), "try_this")
					add_battle_log("Try This! +30 mana pool, +2 hand size for 10 tempo", Color(0.6, 1.0, 0.6))

		"shuriken":
			# Deal 3 damage to a RANDOM living enemy, as the card describes.
			var sk_enemies = enemy_spawner.get_living_enemies()
			if sk_enemies.size() > 0:
				var sk_target = sk_enemies[randi() % sk_enemies.size()]
				var sk_dmg := _card_player_damage(card)
				sk_target.take_damage(sk_dmg, true)
				add_battle_log("Shuriken hit %s for %d!" % [sk_target.enemy_name, sk_dmg], Color(0.8, 0.9, 1.0))
			else:
				add_battle_log("Shuriken thrown, but no enemies present.", Color(0.7, 0.7, 0.7))

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
				enemy.apply_taunt(player, 10)
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
			var charge_hit: Array = []

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
					if not enemy in charge_hit:
						charge_hit.append(enemy)

				final_pos = next_pos

			# Move player to final position
			final_pos = grid_manager.snap_to_grid(final_pos)
			player.position = final_pos
			player.target_position = final_pos
			_apply_misery_spread(charge_hit)
			print("[MAIN] Charge: moved to %s, hit %d enemies for %d damage" % [final_pos, charge_hit.size(), card.last_damage_dealt])

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
			# Damage scales with the distance ACTUALLY leaped (3 per tile), not the
			# max STR leap — a short hop hits softer, as the card describes.
			var leap_damage = card.last_damage_dealt
			if leap_distance > 0 and actual_leap < leap_distance:
				leap_damage = maxi(1, floori(card.last_damage_dealt * float(actual_leap) / float(leap_distance)))
			# Deal AOE damage to enemies at landing
			var landing_enemies = enemy_spawner.get_enemies_in_radius(leap_target, 1.5)
			for enemy in landing_enemies:
				enemy.take_damage(leap_damage, true)
			_apply_misery_spread(landing_enemies)
			print("[MAIN] Heroic Leap: jumped %d/%d tiles to %s, hit %d enemies for %d damage" % [actual_leap, leap_distance, leap_target, landing_enemies.size(), leap_damage])

		"surrounding_ice":
			# AOE circle around player - uses the pre-rolled per-enemy outcomes
			# so Loaded Die / House Money chance boosts actually apply.
			var nearby = enemy_spawner.get_enemies_in_radius(player.position, card.aoe_range)
			var ice_hit: Array = []
			var misses = 0
			for enemy in nearby:
				if card.get_rng_outcome(enemy):
					enemy.take_damage(card.last_damage_dealt, true)
					ice_hit.append(enemy)
				else:
					misses += 1
			_apply_misery_spread(ice_hit)
			print("[MAIN] Surrounding Ice: %d hits, %d misses out of %d enemies" % [ice_hit.size(), misses, nearby.size()])

		"snowballs_chance":
			# Searing fire line 3 spaces forward - always hits
			var sbc_diff = mouse_pos - player.position
			var direction = Vector3(sbc_diff.x, 0, sbc_diff.z).normalized()
			var fire_end = player.position + direction * card.aoe_range
			var fire_enemies = enemy_spawner.get_enemies_in_line(player.position, fire_end, 0.8)
			var sbc_hit: Array = []
			for enemy in fire_enemies:
				enemy.take_damage(card.last_damage_dealt, true)
				sbc_hit.append(enemy)
			print("[MAIN] Snowball's Chance: fire line hit %d enemies for %d damage" % [fire_enemies.size(), card.last_damage_dealt])
			# 50% to also spread snowball cone — uses the pre-rolled outcome so
			# the result matches the card preview.
			var sbc_cone: bool = card.rng_binary_succeeded() if card.has_been_rolled() else randf() < 0.5
			if sbc_cone:
				var cone_enemies = enemy_spawner.get_enemies_in_cone(player.position, direction, card.aoe_range, 45.0)
				var extra_hits = 0
				for enemy in cone_enemies:
					if not enemy in fire_enemies:
						enemy.take_damage(card.last_damage_dealt, true)
						sbc_hit.append(enemy)
						extra_hits += 1
				print("[MAIN] Snowball's Chance: snowball cone hit %d additional enemies!" % extra_hits)
			_apply_misery_spread(sbc_hit)

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
				enemy.apply_debuff("disarmed", 5)
			_apply_misery_spread(sd_nearby)
			print("[MAIN] Sweeping Disarm: hit %d nearby enemies for %d damage, disarmed" % [sd_nearby.size(), card.last_damage_dealt])

		"shadows":
			_set_player_invisible(true)

		"barricade":
			_spawn_barricade()

		"rise":
			var rise_pos = grid_manager.snap_to_grid(get_mouse_world_position())
			_spawn_pillar(rise_pos)

		"absorb_essence":
			# A flat 1 damage to ALL things on the battlefield (enemies,
			# obstacles, self) — deliberately NOT stat-scaled. The payoff scales
			# through Energy Ball, which does take the caster's amplifications.
			var absorb_total_damage = 0
			var all_enemies = enemy_spawner.get_living_enemies()
			for enemy in all_enemies:
				enemy.take_damage(1, true)
				absorb_total_damage += 1
			_apply_misery_spread(all_enemies)
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

	# Feral Evocation: the play and its world effects have fully resolved —
	# drop the element remap so nothing later inherits it.
	Card.active_element_remap = ""

func _is_ui_window_open() -> bool:
	## True when any scrollable HUD window is open. Mouse-wheel/drag over the
	## battlefield should not zoom/orbit the camera while the player is reading
	## or scrolling one of these windows.
	if character_panel and character_panel.is_open():
		return true
	if trade_ui and trade_ui.visible:
		return true
	if enemy_inspect_ui and enemy_inspect_ui.visible:
		return true
	if help_panel and help_panel.visible:
		return true
	if deck_list_panel and deck_list_panel.visible:
		return true
	if maintained_list_panel and maintained_list_panel.visible:
		return true
	if pile_popup_panel and pile_popup_panel.visible:
		return true
	if _donation_panel and _donation_panel.visible:
		return true
	if skill_tree_ui and skill_tree_ui.visible:
		return true
	if manifest_ui and manifest_ui.visible:
		return true
	if quiver_ui and quiver_ui.visible:
		return true
	if _chest_modal_open:
		return true
	if _tab_menu_panel and _tab_menu_panel.visible:
		return true
	if sandbox_ui and sandbox_ui.visible and sandbox_ui.has_method("is_menu_open") and sandbox_ui.is_menu_open():
		return true
	return false

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
			if _try_interact_town_portal():
				return
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

		# Burden relief: J jails the selected Burden card from hand (1m + 1t),
		# resetting its accumulated cost. It sits in jail for 30 tempo.
		if event.keycode == KEY_J:
			if selected_card_index >= 0 and selected_card_index < deck_manager.hand.size():
				var bcard = deck_manager.hand[selected_card_index]
				if bcard.has_burden:
					if deck_manager.jail_burden_card(selected_card_index):
						tempo_manager.add_tempo(bcard.burden_jail_cost_tempo)
						selected_card_index = -1
						if range_indicator:
							range_indicator.hide_range()
						add_battle_log("%s jailed to shed its burden (back in %d tempo)." % [bcard.card_name, bcard.burden_jail_duration], Color(0.8, 0.6, 1.0))
					else:
						add_battle_log("Cannot jail — no burden built up (or not enough mana).", Color(1.0, 0.5, 0.4))
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

		# WASD: step one grid cell in the camera-relative direction. A quick
		# alternative to right-clicking for short hops; right-click still works.
		match event.keycode:
			KEY_W:
				_wasd_step(Vector2(0, 1))
				return
			KEY_S:
				_wasd_step(Vector2(0, -1))
				return
			KEY_A:
				_wasd_step(Vector2(-1, 0))
				return
			KEY_D:
				_wasd_step(Vector2(1, 0))
				return

		# Card selection — keys map to persistent number-row slots, not hand order.
		for i in range(CARD_KEYS.size()):
			if event.keycode == CARD_KEYS[i]:
				_select_slot(i)
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
			if aoe_indicator:
				aoe_indicator.hide_indicator()
			update_selected_display()
			update_card_highlights()
			move_dialog.hide_dialog()
			_hide_card_confirm_dialog()
			if enemy_inspect_ui:
				enemy_inspect_ui.hide_panel()
			character_panel.hide_panel()
			skill_tree_ui.hide_panel()
			if trade_ui:
				trade_ui.close()
	
	# Left click - play card or use gauntlet skill
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Mythic reveal sequence: clicking the present opens it; clicking the
		# revealed icon claims the item.
		if _try_click_mythic_reveal():
			return

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
			if buff_mgr and buff_mgr.has_poisoned_blood() and card.heal_amount > 0:
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

			# Co-op: right-clicking your partner opens the ally menu (Trade)
			# instead of being treated as a move order.
			if is_multiplayer and _p2_player:
				var clicked_ally: Player = _player_at_position(mouse_pos)
				if clicked_ally and clicked_ally != player:
					_show_ally_menu(clicked_ally, event.position)
					return

			# Glued while your own action ticks — no new move orders.
			if _movement_locked():
				_notify_movement_locked()
				return

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

	# Mouse wheel zoom — skip while a UI window is open so scrolling its
	# contents doesn't also zoom/move the battlefield behind it.
	if event is InputEventMouseButton and event.pressed and not _is_ui_window_open():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = max(CAMERA_ZOOM_MIN, _camera_distance - CAMERA_ZOOM_STEP)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = min(CAMERA_ZOOM_MAX, _camera_distance + CAMERA_ZOOM_STEP)
			_update_camera()

	# Camera orbit - left click drag when no card is selected
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Only start orbiting if no card action is pending and no UI window
			# is capturing the drag (otherwise dragging a scrollbar spins the map).
			if selected_card_index < 0 and _pending_quiver_card == null and not _is_ui_window_open():
				_camera_orbiting = true
				_camera_drag_start = event.position
		else:
			# The camera stays exactly where the player leaves it — no snap.
			# WASD stays safe at any yaw because _wasd_step quantizes the
			# camera angle itself when projecting keys onto the grid.
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
	# Act-1 mythic cap: once this character's act-1 mythic dropped, act-1
	# chests stop offering mythics too.
	dungeon_manager.block_act1_mythics = DropRates.act1_mythic_locked(current_character)
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

func _player_blocked_tiles() -> Array[Vector2i]:
	## Walls + pits + barricades — impassable for the player.
	var tiles: Array[Vector2i] = []
	if dungeon_manager:
		tiles.append_array(dungeon_manager.get_wall_tiles())
		for p in dungeon_manager.pit_tiles.keys():
			tiles.append(p)
	for obs in barricade_obstacles:
		tiles.append(grid_manager.world_to_grid(obs["position"]))
	return tiles

func _enemy_blocked_tiles() -> Array[Vector2i]:
	## Everything the player is blocked by, plus forest tree trunks (the player
	## may climb those; enemies cannot).
	var enemy_tiles: Array[Vector2i] = _player_blocked_tiles()
	if dungeon_manager:
		for tree in dungeon_manager.tree_nodes:
			enemy_tiles.append(tree["grid_pos"])
	return enemy_tiles

func _sync_dungeon_blocked_tiles() -> void:
	## Combines dungeon walls + barricades + pits for pathfinding. Forest tree
	## trunks additionally block enemies (the player may climb them).
	var tiles := _player_blocked_tiles()
	player.blocked_tiles = tiles
	var enemy_tiles := _enemy_blocked_tiles()
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
			env.ambient_light_energy = 0.90  # bright, sun-dappled woodland
		else:
			# High ambient fill: 16-bit terrain is painted mostly flat, so
			# shadowed cliff faces stay a readable warm tan instead of black.
			env.ambient_light_energy = 1.0
		# No volumetric distance fog: depth haze is a modern rendering cue the
		# 16-bit style forbids. Underground gloom comes from ambient + torches.
		env.fog_enabled = false
		# No SSAO: soft screen-space AO is a modern rendering tell the 16-bit
		# style spec forbids — contact shading is painted into sprites instead.
		env.ssao_enabled = false

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
		else:
			# Compress lit-vs-shadow range outdoors: painted 16-bit terrain
			# carries its own shading, so the sun only needs to suggest form.
			energy *= 0.75
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
				torch.omni_attenuation = 2.0  # tighter falloff, less modern gradient
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
		"Wooden Sword": item = ItemData.create_wooden_sword()
		"Bladed Doughnut": item = ItemData.create_bladed_doughnut()
		_:
			# Any other item (all helms, etc.) resolves by name via factory discovery.
			item = ItemData.create_by_name(item_name)

	if item:
		var inv = player.get_inventory()
		# Find first empty equipment slot
		var slot_array = inv._get_slot_array(item.item_type)
		var max_slots = inv._get_max_slots(item.item_type)

		for i in range(max_slots):
			if slot_array[i] == null:
				# Can fail (carry gate / grip-locked hand) — fall through to storage
				if inv.equip_item(item, i):
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
	# Slotted Rope Half Sleeve: spending a Cinquedea takes its +1 block with it.
	# Read before activate_manifest pops the entry.
	var sleeve: ItemData = null
	if index >= 0 and index < overflow_manager.manifest_zone.size():
		var entry: Dictionary = overflow_manager.manifest_zone[index]
		sleeve = entry.get("source_item", null)
		# Item-conjured blades keep their own mana cost; the zone's own
		# manifests (skeletons, mushrooms) remain free as they always were.
		if sleeve != null and int(entry.get("mana_cost", 0)) > 0:
			if not player.get_stats().spend_mana(int(entry["mana_cost"])):
				add_battle_log("Not enough mana for %s" % entry.get("manifest_name", "that"), Color(1.0, 0.4, 0.4))
				return

	var result = overflow_manager.activate_manifest(index)

	if result.is_empty():
		return

	# Unequipping the source already gave its block back, so only a blade that
	# is still counted takes a point with it.
	if sleeve != null and sleeve.conjured_in_manifest > 0:
		sleeve.conjured_in_manifest -= 1
		if sleeve.overdraw_card_block > 0 and player.get_stats():
			player.get_stats().equipment_defense_card_block -= sleeve.overdraw_card_block

	# Execute manifest effect
	match result["manifest_id"]:
		"cinquedea":
			# Range 4, 6 damage, 1 Weaken — the nearest enemy in reach.
			var cq_victim = _nearest_enemy_to(player.position, enemy_spawner.get_living_enemies())
			if cq_victim and grid_manager.get_distance_in_cells(player.position, cq_victim.position) <= 4:
				cq_victim.take_damage(6, true)
				if is_instance_valid(cq_victim) and cq_victim.has_method("apply_debuff"):
					cq_victim.apply_debuff("weaken", 1)
				add_battle_log("Cinquedea: 6 damage and 1 Weaken to %s" % cq_victim.enemy_name, Color(0.85, 0.85, 0.7))
			else:
				add_battle_log("Cinquedea: nothing within 4 squares", Color(0.7, 0.6, 0.5))
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
					if stats.consume_free_hand_echo() and is_instance_valid(rand_enemy):
						rand_enemy.take_damage(result["manifest_value"], true)
						add_battle_log("Free hand echo! The shuriken strikes twice.", Color(1.0, 0.9, 0.4))
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
			var quiver_dr_hp = maxi(1, ceili(mana_cost / 10.0))
			stats.take_damage(quiver_dr_hp)
			buff_mgr.consume_demonic_rage()
			print("[MAIN] Quiver: Demonic Rage paid %d health instead of %d mana" % [quiver_dr_hp, mana_cost])
		else:
			stats.spend_mana(mana_cost)

	# Execute the card
	var damage_reduction = debuff_mgr.get_damage_reduction_percent() if debuff_mgr else 0.0
	var self_damage = debuff_mgr.get_self_damage_percent() if debuff_mgr else 0.0
	progression_triggers.arm_pre_attack_passives(card, target)
	card.execute(target, stats, deck_manager, damage_reduction, self_damage, buff_mgr)
	progression_triggers.clear_pre_attack_passives()

	# Register attack for attack speed counter (DEX proc)
	if card.card_type == Card.CardType.ATTACK:
		stats.register_attack()
		# Free hand: the 12th attack echoes — the card runs again, free.
		if stats.consume_free_hand_echo():
			card.execute(target, stats, deck_manager, damage_reduction, self_damage, buff_mgr)
			add_battle_log("Free hand echo: %s strikes twice!" % card.card_name, Color(1.0, 0.9, 0.4))

	# Notify debuffs of attack
	if debuff_mgr and card.card_type == Card.CardType.ATTACK:
		debuff_mgr.on_attack()

	# Apply tempo
	var tempo_cost = card.get_burden_tempo_cost()
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
	WorldText.crisp(label)
	marker.add_child(label)

# ============================================
# ALASKAN BULL WORMS (Worm's Armageddon summon)
# ============================================

func _spawn_bull_worms(count: int) -> void:
	## Summon burrowed worm allies on free tiles beside the player.
	if not grid_manager:
		return
	var player_cell = grid_manager.world_to_grid(player.position)
	var blocked = player.blocked_tiles
	var enemy_cells = _living_enemy_cells()
	var offsets = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, -1), Vector2i(2, 0), Vector2i(0, 2),
	]
	var spawned = 0
	var used: Array = []
	for off in offsets:
		if spawned >= count:
			break
		var cell = player_cell + off
		if cell == player_cell or cell in blocked or cell in enemy_cells or cell in used:
			continue
		used.append(cell)
		var worm = SummonedWormScript.new()
		add_child(worm)
		worm.setup(grid_manager, grid_manager.grid_to_world(cell))
		worm.died.connect(func(w): _garmr_death_stack(w.position); _summoned_worms.erase(w))
		_summoned_worms.append(worm)
		spawned += 1
	if spawned > 0:
		add_battle_log("The ground rumbles — %d Alaskan Bull Worm(s) burrow up!" % spawned, Color(0.85, 0.75, 0.9))

func _clear_summoned_worms() -> void:
	for worm in _summoned_worms:
		if is_instance_valid(worm):
			worm.queue_free()
	_summoned_worms.clear()

func _update_summoned_worms() -> void:
	## Per-tempo worm AI: burrowed worms crawl 1 tile toward the nearest enemy
	## (untargetable); on contact they surface and bite for 6 each tempo.
	## Surfaced worms can be swatted by adjacent enemies.
	if _summoned_worms.is_empty():
		return
	_summoned_worms = _summoned_worms.filter(func(w): return is_instance_valid(w) and not w.is_dead)
	if not grid_manager or not enemy_spawner:
		return
	var enemies = enemy_spawner.get_living_enemies()
	var blocked = player.blocked_tiles

	# Enemies swat adjacent SURFACED worms (burrowed = untargetable).
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var ecell = grid_manager.world_to_grid(enemy.position)
		for worm in _summoned_worms.duplicate():
			if not is_instance_valid(worm) or worm.is_dead or worm.burrowed:
				continue
			if _manhattan(worm.get_cell(), ecell) == 1:
				worm.take_damage(enemy.attack_damage)
				break

	var worm_cells: Array = []
	for worm in _summoned_worms:
		if is_instance_valid(worm) and not worm.is_dead:
			worm_cells.append(worm.get_cell())

	for worm in _summoned_worms.duplicate():
		if not is_instance_valid(worm) or worm.is_dead:
			continue
		var target_enemy = _nearest_enemy_to(worm.position, enemies)
		if target_enemy == null:
			continue
		var wcell = worm.get_cell()
		var tcell = grid_manager.world_to_grid(target_enemy.position)
		if _manhattan(wcell, tcell) <= 1:
			# Bite! Surfacing ends the burrow (worm becomes targetable).
			if worm.burrowed:
				worm.surface()
				add_battle_log("A Bull Worm erupts from the ground!", Color(0.85, 0.75, 0.9))
			target_enemy.take_damage(worm.CONTACT_DAMAGE, true)
			add_battle_log("Bull Worm bites %s for %d!" % [target_enemy.enemy_name, worm.CONTACT_DAMAGE], Color(0.85, 0.75, 0.9))
			_belthronding_share(worm.position, worm.CONTACT_DAMAGE)
			continue
		# 1 movement per tempo while hunting.
		var next_cell = _rat_step_toward(wcell, tcell, blocked, _living_enemy_cells(), worm_cells)
		if next_cell != wcell:
			worm_cells.erase(wcell)
			worm_cells.append(next_cell)
			worm.move_to_cell(next_cell)

	_summoned_worms = _summoned_worms.filter(func(w): return is_instance_valid(w) and not w.is_dead)

func _living_enemy_cells() -> Array:
	var cells: Array = []
	if not grid_manager or not enemy_spawner:
		return cells
	for e in enemy_spawner.get_living_enemies():
		cells.append(grid_manager.world_to_grid(e.position))
	return cells

# ============================================
# FRANKENSTEINS MONSTER (ITS ALIVE!!!!! summon)
# ============================================

## Raise the nearest corpse into a Frankensteins Monster. Called by the
## its_alive card's world effect. No corpse in reach → the card fizzles.
func _resurrect_frankenstein() -> void:
	if not grid_manager or not player:
		return
	# Drop any corpses whose tile is now occupied by a living enemy or the player.
	var player_cell = grid_manager.world_to_grid(player.position)
	var enemy_cells = _living_enemy_cells()
	# Pick the corpse closest to the player.
	var best_idx := -1
	var best_dist := INF
	for i in range(_corpses.size()):
		var d = player.position.distance_to(_corpses[i]["position"])
		if d < best_dist:
			best_dist = d
			best_idx = i
	if best_idx < 0:
		add_battle_log("ITS ALIVE!!!!! fizzles — no corpse to raise.", Color(0.7, 0.7, 0.7))
		return
	var corpse = _corpses[best_idx]
	_corpses.remove_at(best_idx)
	# Find a free tile at/near the corpse (its own cell first).
	var spawn_cell: Vector2i = corpse["cell"]
	var blocked = player.blocked_tiles
	if spawn_cell == player_cell or spawn_cell in enemy_cells or spawn_cell in blocked:
		var placed := false
		for off in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var c = corpse["cell"] + off
			if c != player_cell and not (c in enemy_cells) and not (c in blocked):
				spawn_cell = c
				placed = true
				break
		if not placed:
			add_battle_log("ITS ALIVE!!!!! fizzles — no room to raise the corpse.", Color(0.7, 0.7, 0.7))
			return
	var stats = player.get_stats()
	var summoner_int: int = stats.intelligence if stats else 0
	var monster = FrankensteinScript.new()
	add_child(monster)
	monster.setup(grid_manager, grid_manager.grid_to_world(spawn_cell), summoner_int)
	monster.died.connect(func(m): _garmr_death_stack(m.position); _frankensteins.erase(m))
	_frankensteins.append(monster)
	add_battle_log("ITS ALIVE!!!!! A Frankensteins Monster rises (%d HP)!" % monster.max_health, Color(0.6, 0.9, 0.6))

func _clear_frankensteins() -> void:
	for m in _frankensteins:
		if is_instance_valid(m):
			m.queue_free()
	_frankensteins.clear()
	_corpses.clear()

## Per-tempo Frankenstein AI. Moves MOVE_STEPS tiles every MOVE_INTERVAL tempo
## toward the nearest enemy, and attacks every ATTACK_INTERVAL tempo when adjacent.
func _update_frankensteins(amount: int) -> void:
	if _frankensteins.is_empty():
		return
	_frankensteins = _frankensteins.filter(func(m): return is_instance_valid(m) and not m.is_dead)
	if not grid_manager or not enemy_spawner:
		return
	var enemies = enemy_spawner.get_living_enemies()
	var blocked = player.blocked_tiles

	# NOTE: enemies treat the monster like any other unit. Today enemy AI only
	# targets players, so nothing here makes enemies attack it — making summons
	# real targets in enemy target-selection is an enemy-AI pass.

	var mon_cells: Array = []
	for m in _frankensteins:
		if is_instance_valid(m) and not m.is_dead:
			mon_cells.append(m.get_cell())

	for m in _frankensteins.duplicate():
		if not is_instance_valid(m) or m.is_dead:
			continue
		var target_enemy = _nearest_enemy_to(m.position, enemies)
		if target_enemy == null:
			continue
		var tcell = grid_manager.world_to_grid(target_enemy.position)
		# Attack on cadence when adjacent.
		m.attack_accum += amount
		if _manhattan(m.get_cell(), tcell) <= 1:
			if m.attack_accum >= m.ATTACK_INTERVAL:
				m.attack_accum -= m.ATTACK_INTERVAL
				target_enemy.take_damage(m.attack_damage, true)
				add_battle_log("Frankensteins Monster smashes %s for %d!" % [target_enemy.enemy_name, m.attack_damage], Color(0.6, 0.9, 0.6))
				_belthronding_share(m.position, m.attack_damage)
			continue
		# Move on cadence: MOVE_STEPS tiles per MOVE_INTERVAL tempo. get_cell()
		# only updates once _process lerps the body, so walk the path locally and
		# issue a single move to the end tile. One move action per tick (overflow
		# stays banked in move_accum) keeps cadence stable if amount is large.
		m.move_accum += amount
		if m.move_accum >= m.MOVE_INTERVAL:
			m.move_accum -= m.MOVE_INTERVAL
			var cur = m.get_cell()
			mon_cells.erase(cur)
			for _step in range(m.MOVE_STEPS):
				var tc = grid_manager.world_to_grid(target_enemy.position)
				if _manhattan(cur, tc) <= 1:
					break
				var nxt = _rat_step_toward(cur, tc, blocked, _living_enemy_cells(), mon_cells)
				if nxt == cur:
					break
				cur = nxt
			mon_cells.append(cur)
			if cur != m.get_cell():
				m.move_to_cell(cur)

	_frankensteins = _frankensteins.filter(func(m): return is_instance_valid(m) and not m.is_dead)

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

func _ally_stats_by_name(ally_name: String):
	## Resolve an ally display name (from the donation panel) to its PlayerStats.
	## Currently the co-op partner; summoned creatures have no stats object.
	var candidates: Array = []
	if _p1_player and _p1_player != player:
		candidates.append(_p1_player)
	if _p2_player and _p2_player != player:
		candidates.append(_p2_player)
	for p in candidates:
		if not is_instance_valid(p) or not p.has_method("get_stats"):
			continue
		var s = p.get_stats()
		if s and s.character_data and s.character_data.character_name == ally_name:
			return s
	return null

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
			# Route the allocation to the actual ally's stats (co-op partner).
			var ally_stats = _ally_stats_by_name(ally_name)
			if ally_stats:
				ally_stats.heal(heal_amount)
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
	## Fade the actual 3D figure while Invisible is active. (The old code faded
	## player.mesh — the hidden prototype capsule — so nothing showed on screen.)
	if player and player.has_method("set_translucent"):
		player.set_translucent(invisible)
		print("[MAIN] Player invisibility %s" % ("on (translucent)" if invisible else "off"))

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
	WorldText.crisp(label)
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
	## Syncs blockers to the player and all enemies for pathfinding. Defers to
	## the full dungeon sync (walls + pits + barricades + tree trunks) so no
	## call site silently un-blocks hazards; outside a dungeon only barricades
	## exist.
	if dungeon_manager:
		_sync_dungeon_blocked_tiles()
		return
	var tiles: Array[Vector2i] = []
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
# TOWN PORTAL (Return Scroll)
# ============================================

var _town_portal_node: Node3D = null
# Set by town when the player steps back through their portal: the world spot
# to restore them to (and re-open the battle-side portal at).
var portal_return_position = null

func spawn_town_portal(at = null) -> void:
	## Right-clicking the Return Scroll conjures a purple portal on the tile
	## beside the player (or exactly at `at` when re-opening after a return).
	## [Shift] next to it travels home to town — where its twin awaits.
	if is_instance_valid(_town_portal_node):
		_town_portal_node.queue_free()

	var portal_root = Node3D.new()
	portal_root.name = "TownPortal"
	var spot
	if at != null:
		spot = at
	else:
		spot = grid_manager.snap_to_grid(player.position + Vector3(grid_manager.grid_size, 0, 0))
	portal_root.position = Vector3(spot.x, 0, spot.z)

	# Swirling purple oval — a flattened torus standing upright.
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.75
	ring.mesh = torus
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.position = Vector3(0, 1.1, 0)
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.6, 0.25, 0.95)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.55, 0.2, 0.9)
	ring_mat.emission_energy_multiplier = 1.6
	ring.material_override = ring_mat
	portal_root.add_child(ring)

	# Glowing translucent film inside the ring.
	var film = MeshInstance3D.new()
	var disc = CylinderMesh.new()
	disc.top_radius = 0.58
	disc.bottom_radius = 0.58
	disc.height = 0.05
	film.mesh = disc
	film.rotation_degrees = Vector3(90, 0, 0)
	film.position = Vector3(0, 1.1, 0)
	var film_mat = StandardMaterial3D.new()
	film_mat.albedo_color = Color(0.75, 0.45, 1.0, 0.55)
	film_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	film_mat.emission_enabled = true
	film_mat.emission = Color(0.7, 0.4, 1.0)
	film_mat.emission_energy_multiplier = 1.2
	film.material_override = film_mat
	portal_root.add_child(film)

	var label = Label3D.new()
	label.text = "Town Portal"
	label.modulate = Color(0.85, 0.6, 1.0)
	label.position = Vector3(0, 2.3, 0)
	WorldText.crisp(label, 18)
	portal_root.add_child(label)

	var interact_label = Label3D.new()
	interact_label.text = "[Shift] Enter"
	interact_label.modulate = Color(1.0, 0.9, 0.4)
	interact_label.position = Vector3(0, 2.0, 0)
	WorldText.crisp(interact_label, 14)
	portal_root.add_child(interact_label)

	_town_portal_node = portal_root
	add_child(portal_root)
	add_battle_log("A town portal shimmers open beside you.", Color(0.8, 0.55, 1.0))
	print("[MAIN] Town portal opened at %s" % portal_root.position)

func _try_interact_town_portal() -> bool:
	if not is_instance_valid(_town_portal_node):
		return false
	var flat_dist = Vector2(player.position.x - _town_portal_node.position.x,
			player.position.z - _town_portal_node.position.z).length()
	if flat_dist > grid_manager.grid_size * 1.6:
		return false
	# Going through the scroll's portal: its twin opens in town, remembering
	# this spot so stepping back through returns the player right here.
	_pending_portal_return = {
		"world_level": current_world_level,
		"position": _town_portal_node.position,
	}
	_travel_to_town()
	return true

var _pending_portal_return: Dictionary = {}

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
	cylinder.radial_segments = 8  # faceted, not smooth-round
	pillar_mesh.mesh = cylinder
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.62, 0.45)  # warm cast over the rock tiles
	mat.albedo_texture = load("res://assets/textures/tile_rock.png")
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.25, 0.25, 0.25)
	mat.roughness = 1.0
	pillar_mesh.material_override = mat
	pillar_mesh.position = Vector3(0, 1.0, 0)  # Center of cylinder at Y=1
	pillar_root.add_child(pillar_mesh)

	var label = Label3D.new()
	label.text = "Pillar"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	label.position = Vector3(0, 2.3, 0)
	WorldText.crisp(label)
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
		"Skip (3)":
			effect = OverflowEffect.create_skip(3, "Test")
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
	# Tight Rope: fires only on the hit that dropped the player below 20% health.
	var tr_stats = player.get_stats()
	if tr_stats and tr_stats.max_health > 0:
		var pct := float(tr_stats.current_health) / float(tr_stats.max_health)
		var prev_pct := float(tr_stats.current_health + _amount) / float(tr_stats.max_health)
		if pct < 0.2 and prev_pct >= 0.2:
			var low_triggered = deck_manager.trigger_reactions("on_health_below_20")
			for card in low_triggered:
				card.execute(null, tr_stats, deck_manager, 0.0, 0.0, player.get_buff_manager())
			if low_triggered.size() > 0:
				_refresh_unit_tracker()
		# Preemptive Answer (Divine Resistance): fires on the hit that dropped
		# the player to 25% health or below.
		if pct <= 0.25 and prev_pct > 0.25:
			var pa_triggered = deck_manager.trigger_reactions("on_hp_below_25")
			for card in pa_triggered:
				card.execute(null, tr_stats, deck_manager, 0.0, 0.0, player.get_buff_manager())
			if pa_triggered.size() > 0:
				add_battle_log("Preemptive Answer! Debuffs purged, healed 20.", Color(0.9, 0.9, 0.6))
				_refresh_unit_tracker()
		# Hammer of Ajax: taking a hit below 30% health feeds the pain.
		if pct < 0.3 and deck_manager:
			var fitp = deck_manager.trigger_reactions("on_damage_taken_low")
			for fitp_card in fitp:
				fitp_card.execute(null, tr_stats, deck_manager, 0.0, 0.0, player.get_buff_manager())
			if fitp.size() > 0:
				_refresh_unit_tracker()
		# Axe's Axe: five hits taken wind the Death Vortexes — every copy in
		# hand spins at once; a copy that kills climbs back into the hand.
		tr_stats.hit_streak = mini(5, tr_stats.hit_streak + 1)
		if tr_stats.hit_streak >= 5 and deck_manager and enemy_spawner:
			var vortexes = deck_manager.trigger_reactions("on_hit_streak_5")
			if vortexes.size() > 0:
				tr_stats.hit_streak = 0
				for dv_card in vortexes:
					var spun = enemy_spawner.get_enemies_in_radius(player.position, 1.5)
					var dv_kills := 0
					for dv_en in spun:
						if dv_en and is_instance_valid(dv_en) and not dv_en.is_dead:
							dv_en.take_damage(15, true)
							if dv_en.is_dead:
								dv_kills += 1
					add_battle_log("Death Vortex! 15 damage to %d enem%s" % [spun.size(), "y" if spun.size() == 1 else "ies"], Color(0.9, 0.3, 0.3))
					if dv_kills > 0 and deck_manager.discard_pile.has(dv_card):
						deck_manager.discard_pile.erase(dv_card)
						deck_manager.add_card_to_hand(dv_card)
						add_battle_log("The Vortex returns to your hand!", Color(0.9, 0.5, 0.3))
		# Psionic Flow, guard mode: an ally (self in solo) was struck within reach.
		if deck_manager and tr_stats.last_attacker and is_instance_valid(tr_stats.last_attacker):
			var pf_guard = deck_manager.trigger_reactions("psionic_flow")
			for _pfg in pf_guard:
				tr_stats.heal(8)
				if tr_stats.last_attacker.has_method("knockback"):
					tr_stats.last_attacker.knockback(player.position, 1)
				add_battle_log("Psionic Flow guards: 8 restored, attacker shoved!", Color(0.6, 0.7, 1.0))
		# Wooden Plank: the hit that drops you below half health starts a
		# trickle of Regen.
		if pct < 0.5 and prev_pct >= 0.5:
			var wp_inv = player.get_inventory()
			var wp_bm = player.get_buff_manager()
			if wp_inv and wp_bm:
				for wp_chest in wp_inv.equipped_chests:
					if wp_chest and wp_chest.low_health_regen > 0:
						wp_bm.apply_buff(Buff.create_regen(wp_chest.low_health_regen, 15, wp_chest.item_name))
						add_battle_log("%s: +%d Regen" % [wp_chest.item_name, wp_chest.low_health_regen], Color(0.5, 0.9, 0.5))
	# Cover: an ally taking damage (self in solo) fires its mitigation reaction.
	var cover_reactions = deck_manager.trigger_reactions("on_ally_damage_taken")
	for card in cover_reactions:
		card.execute(null, player.get_stats(), deck_manager, 0.0, 0.0, player.get_buff_manager())
	if triggered.size() > 0 or cover_reactions.size() > 0:
		_refresh_unit_tracker()

func _on_ally_damage_taken(_amount: int, victim) -> void:
	## Co-op: the PARTNER took damage. If the other player holds Cover and is
	## within 2 tiles, their reaction mitigates it — the ally is restored by the
	## defender's hand size (post-damage approximation of "reduce it").
	if not is_instance_valid(victim):
		return
	var defender = _p1_player if victim == _p2_player else _p2_player
	if defender == null or not is_instance_valid(defender):
		return
	var diff = defender.position - victim.position
	if Vector3(diff.x, 0, diff.z).length() > 2.0:
		return
	var defender_deck = _p1_deck_manager if defender == _p1_player else _p2_deck_manager
	if defender_deck == null:
		return
	var cover_reactions = defender_deck.trigger_reactions("on_ally_damage_taken")
	for card in cover_reactions:
		# player_stats = the VICTIM (who gets the mitigation); deck = defender's
		# (whose hand size sets the amount).
		card.execute(null, victim.get_stats(), defender_deck, 0.0, 0.0, defender.get_buff_manager())
	if cover_reactions.size() > 0:
		add_battle_log("Cover! Ally's damage mitigated.", Color(0.5, 0.85, 1.0))
		_refresh_unit_tracker()

	var stats = player.get_stats()
	var non_fatal: bool = stats != null and stats.current_health > 0
	if not non_fatal:
		return


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
	# The 8-HP cost is paid inside PlayerStats._pay_whispers_cost() (routed to the
	# actual caster, non-lethal on a self-cast) — this handler just narrates.
	add_battle_log("Shepherd's Mark: Lethal damage prevented! 1 HP + 10 armor!", Color(0.3, 0.7, 1.0))
	add_battle_log("Shepherd's Mark: the caster pays 8 HP.", Color(0.9, 0.3, 0.3))

# ============================================
# LOOT DROP SYSTEM
# ============================================

func _on_loot_dropped(loot: Dictionary, pos: Vector3) -> void:
	## Enemies drop their loot ON THE GROUND: a glinting pile appears on the
	## tile where they died, and whoever walks onto it scoops it up. Looting is
	## TEMPO-FREE — nothing in the pickup path adds tempo; only the walk to
	## reach the pile costs the usual movement tempo.
	if _pending_doughnut_drop:
		# First-room tutorial: this rat carried the Bladed Doughnut. Olorin
		# steps in to explain item levels while it glints on the ground.
		_pending_doughnut_drop = false
		loot["item"] = ItemData.create_bladed_doughnut()
		if olorin:
			olorin.show_item_levels_intro()
	elif _pending_mythic_item:
		# The act-mythic layer fired on this kill (see _on_enemy_killed).
		loot["item"] = _pending_mythic_item
		_pending_mythic_item = null
		add_battle_log("A MYTHIC drops: %s!" % loot["item"].item_name, Color(0.9, 0.35, 0.9))
	_spawn_loot_drop(loot, pos)

func _spawn_loot_drop(loot: Dictionary, pos: Vector3) -> void:
	var has_any: bool = int(loot.get("gold", 0)) > 0 \
		or loot.get("item") != null or loot.get("card") != null \
		or loot.get("card_pack") != null \
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
	if loot.get("card_pack") != null:
		# A sealed pack: a fat card-shaped box in its tier color.
		var pack := CardPack.create(loot["card_pack"])
		var p := _loot_mesh(drop, _mesh_box(Vector3(0.13, 0.17, 0.05)), Vector3(0.14, 0.12, 0.08), pack.get_tier_color(), true)
		p.rotation_degrees = Vector3(-10, -20, 0)
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

# ---- Mythic reveal ceremony -------------------------------------------------

var _mythic_reveals: Array = []  # active MythicReveal nodes

func _start_mythic_reveal(item: ItemData, looter: Player) -> void:
	## Looting a mythic kicks off the ceremony (glow → present → icon) instead
	## of a quiet inventory insert; _finish_mythic_reveal stores it on claim.
	var reveal := MythicReveal.start(item, looter.position)
	add_child(reveal)
	reveal.claimed.connect(func(claimed_item): _finish_mythic_reveal(claimed_item, looter))
	reveal.tree_exited.connect(func(): _mythic_reveals.erase(reveal))
	_mythic_reveals.append(reveal)
	add_battle_log("A MYTHIC reveals itself: %s!" % item.item_name, Color(0.9, 0.35, 0.9))

func _finish_mythic_reveal(item: ItemData, looter: Player) -> void:
	var inv = looter.get_inventory() if is_instance_valid(looter) else (player.get_inventory() if player else null)
	if inv == null:
		return
	if inv.store_item(item) or inv.stash_item(item):
		add_battle_log("MYTHIC claimed: %s!" % item.item_name, Color(0.9, 0.35, 0.9))
		# Mythic ownership history: Mythic Molds can only recreate mythics the
		# character has actually held.
		if current_character and not current_character.owned_mythic_names.has(item.item_name):
			current_character.owned_mythic_names.append(item.item_name)
	else:
		add_battle_log("Inventory AND stash full! %s slipped away..." % item.item_name, Color(1.0, 0.4, 0.4))

func _try_click_mythic_reveal() -> bool:
	if _mythic_reveals.is_empty():
		return false
	var mouse_pos = get_mouse_world_position()
	for reveal in _mythic_reveals.duplicate():
		if is_instance_valid(reveal) and reveal.try_click(mouse_pos):
			return true
	return false

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
	if _loot_tooltip:
		_loot_tooltip.visible = false

func _loot_summary(loot: Dictionary) -> String:
	var parts: Array[String] = []
	var gold = int(loot.get("gold", 0))
	if gold > 0:
		parts.append("+%d Gold" % gold)
	var stones = int(loot.get("culling_stones", 0))
	if stones > 0:
		parts.append("+%d Culling Stone%s" % [stones, "s" if stones > 1 else ""])
	var item: ItemData = loot.get("item")
	if item:
		parts.append("Item: %s" % item.item_name)
	var card: Card = loot.get("card")
	if card:
		parts.append("Card: %s" % card.card_name)
	if loot.get("card_pack") != null:
		parts.append("%s" % CardPack.create(loot["card_pack"]).get_display_name())
	return "\n".join(parts)

## Hovering a loot pile shows what's inside it (called every frame from
## _process; cheap — bails immediately unless loot exists on the ground).
func _update_loot_hover() -> void:
	if _loot_drops.is_empty():
		if _loot_tooltip:
			_loot_tooltip.visible = false
		return
	var mouse_world = get_mouse_world_position()
	var hovered: Dictionary = {}
	if mouse_world != Vector3.ZERO:
		var cell: Vector2i = grid_manager.world_to_grid(mouse_world)
		for entry in _loot_drops:
			if entry["cell"] == cell:
				hovered = entry
				break
	if hovered.is_empty():
		if _loot_tooltip:
			_loot_tooltip.visible = false
		return
	_ensure_loot_tooltip()
	_loot_tooltip_label.text = "Loot (walk over to pick up)\n" + _loot_summary(hovered["loot"])
	_loot_tooltip.visible = true
	# Beside the cursor, kept on screen
	var mouse_pos = get_viewport().get_mouse_position()
	_loot_tooltip.reset_size()
	var pos = mouse_pos + Vector2(18, -12)
	var screen = get_viewport().get_visible_rect().size
	if pos.x + _loot_tooltip.size.x > screen.x:
		pos.x = mouse_pos.x - _loot_tooltip.size.x - 12
	if pos.y + _loot_tooltip.size.y > screen.y:
		pos.y = screen.y - _loot_tooltip.size.y - 8
	_loot_tooltip.position = pos

func _ensure_loot_tooltip() -> void:
	if _loot_tooltip and is_instance_valid(_loot_tooltip):
		return
	var ui = $UI as CanvasLayer
	_loot_tooltip = PanelContainer.new()
	_loot_tooltip.name = "LootTooltip"
	_loot_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.09, 0.06, 0.94)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.7, 0.3)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_loot_tooltip.add_theme_stylebox_override("panel", style)
	_loot_tooltip_label = Label.new()
	_loot_tooltip_label.add_theme_font_size_override("font_size", 14)
	_loot_tooltip_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_loot_tooltip.add_child(_loot_tooltip_label)
	ui.add_child(_loot_tooltip)

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
	if item and item.rarity == ItemData.Rarity.MYTHIC:
		# Mythics don't slip quietly into the bag: the reveal sequence takes
		# over (expanding glow → present → icon), and the item lands in the
		# inventory when the player clicks the revealed icon.
		_start_mythic_reveal(item, looter)
		item = null
	if item:
		var inventory = looter.get_inventory()
		if inventory:
			if inventory.store_item(item):
				messages.append("Item: %s" % item.item_name)
				# Mythic ownership history: Mythic Molds can only recreate
				# mythics the character has actually held.
				if item.rarity == ItemData.Rarity.MYTHIC and current_character \
						and not current_character.owned_mythic_names.has(item.item_name):
					current_character.owned_mythic_names.append(item.item_name)
				# First-room tutorial: picking up the Bladed Doughnut prompts
				# Olorin's skill lesson; once the player moves again, he gets
				# hungry (see _check_doughnut_farewell).
				if item.item_name == "Bladed Doughnut" and olorin \
						and not olorin.has_seen("bladed_doughnut_farewell"):
					olorin.show_bladed_doughnut_skill()
					_doughnut_farewell_armed = true
					_doughnut_item = item
					_doughnut_looter = looter
					_doughnut_pickup_cell = grid_manager.world_to_grid(looter.position)
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

	# Card pack - rips open on pickup, cards go to inventory
	if loot.get("card_pack") != null:
		var pack := CardPack.create(loot["card_pack"])
		var inventory = looter.get_inventory()
		if inventory:
			var pulled: Array[String] = []
			for pc in pack.open():
				if inventory.store_card(pc):
					pulled.append(pc.card_name)
				else:
					messages.append("Card dropped (inventory full): %s" % pc.card_name)
			messages.append("%s: %s" % [pack.get_display_name(), ", ".join(pulled)])
			add_battle_log("Ripped open a %s!" % pack.get_display_name(), pack.get_tier_color())

	if messages.size() > 0:
		var loot_text = "Looted: " + ", ".join(messages)
		add_battle_log(loot_text, Color(1.0, 0.85, 0.2))
		print("[MAIN] %s" % loot_text)

# ============================================
# FIRST-ROOM TUTORIAL: OLORIN TAKES THE DOUGHNUT
# ============================================

## Armed when the player scoops up the Bladed Doughnut. The moment they move
## off the pickup tile (dialogs closed), Olorin reappears, conjures the
## doughnut overhead, and takes it with him.
func _check_doughnut_farewell() -> void:
	if not _doughnut_farewell_armed or olorin == null or olorin.is_busy():
		return
	if not is_instance_valid(_doughnut_looter):
		_doughnut_farewell_armed = false
		_doughnut_item = null
		return
	var cell: Vector2i = grid_manager.world_to_grid(_doughnut_looter.position)
	if cell == _doughnut_pickup_cell:
		return
	_doughnut_farewell_armed = false
	_trade_doughnut_for_wooden_sword()
	olorin.show_doughnut_farewell()

## Olorin takes the Bladed Doughnut and leaves the Wooden Sword in exchange —
## his teaching prop for card slots, on-self bonuses, and item-granted cards.
func _trade_doughnut_for_wooden_sword() -> void:
	if _doughnut_item == null:
		return
	var inv = _doughnut_looter.get_inventory() if is_instance_valid(_doughnut_looter) else null
	if inv:
		if inv.stored_items.has(_doughnut_item):
			inv.stored_items.erase(_doughnut_item)
			inv.storage_changed.emit()
		elif inv.stash_items.has(_doughnut_item):
			inv.stash_items.erase(_doughnut_item)
			inv.storage_changed.emit()
		else:
			# Equipped in the brief window between pickup and moving — unequip
			# (reversing its bonuses) and remove.
			inv._destroy_equipped_item(_doughnut_item)
		add_battle_log("Olorin took the Bladed Doughnut!", Color(0.9, 0.35, 0.9))
		var sword = ItemData.create_wooden_sword()
		if not inv.store_item(sword) and not inv.stash_item(sword):
			# Both full (the doughnut's slot was just freed, so this is unlikely)
			print("[MAIN] No room for the Wooden Sword — gift lost")
		else:
			add_battle_log("Received: Wooden Sword", Color(0.85, 0.7, 0.45))
	_doughnut_item = null
	_doughnut_looter = null

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
		sphere_inventory.load_spheres(inv_data.get("spheres", {}))
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
			inv.stored_items = inv_data.get("stored_items", inv.stored_items)
			inv.rack_items = inv_data.get("rack_items", inv.rack_items)
			inv.rack_cooldown_tempo = inv_data.get("rack_cooldown_tempo", 0)
			inv.stored_cards = inv_data.get("stored_cards", inv.stored_cards)
			inv.stash_items = inv_data.get("stash_items", inv.stash_items)
			inv.culling_stones = inv_data.get("culling_stones", inv.culling_stones)
			inv.mythic_molds = inv_data.get("mythic_molds", inv.mythic_molds)
			inv.ensure_return_scroll()  # older saves predate the scroll
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
	# City-loop state (satchel, city, pending calamity) rides along untouched.
	CityBridge.carry_keys(player_progression, progression)
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
			"stored_items": inv.stored_items.duplicate(),
			"stored_cards": inv.stored_cards.duplicate(),
			"stash_items": inv.stash_items.duplicate(),
			"culling_stones": inv.culling_stones,
			"mythic_molds": inv.mythic_molds,
			"rack_items": inv.rack_items.duplicate(),
			"rack_cooldown_tempo": inv.rack_cooldown_tempo,
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
	# Arriving via the Return Scroll portal: hand town the twin's anchor.
	if not _pending_portal_return.is_empty() and "portal_return" in town_scene:
		town_scene.portal_return = _pending_portal_return
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
	# Full-color tiles: keep only a dim theme cast so out-of-bounds terrain
	# reads as darker painted ground rather than a solid tint.
	var ground_cast: Color = dungeon_manager.get_palette().get("ground", Color(0.15, 0.12, 0.1))
	mat.albedo_color = Color(0.55, 0.55, 0.55).lerp(ground_cast, 0.35)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 1.0
	# Same pixel tile style as the arena floor (tinted darker by the ground
	# colour) so the world beyond the walls matches the sprite art style.
	# Grass swaps to the accent-free far variant: flowers/tufts under the dark
	# tint would read as scattered noise specks across the whole backdrop.
	var tex_path: String = dungeon_manager.floor_texture_path()
	if tex_path.ends_with("tile_grass.png"):
		tex_path = "res://assets/textures/tile_grass_far.png"
	mat.albedo_texture = load(tex_path)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.25, 0.25, 0.25)  # 4x4 variant sheet: 1 tile/unit
	ground.material_override = mat
	ground.position = Vector3(dungeon_manager.GRID_W / 2.0, -0.12, dungeon_manager.GRID_H / 2.0)
	add_child(ground)

# ============================================
# MINIMAP
# ============================================


# Minimap, tab menu, quest log, and expanded map moved to
# scripts/ui/minimap_tab_ui.gd
