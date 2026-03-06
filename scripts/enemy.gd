class_name Enemy
extends CharacterBody3D

## Enemy with per-species skills, tempo-driven action selection, and visual tempo bar.
## Each enemy chooses ONE action at the start of its turn. Global tempo accumulates on
## the enemy's personal counter. When it reaches the chosen action's tempo cost, the
## action fires, the counter resets, and a new action is chosen.

signal damaged(amount: int)
signal died(enemy: Enemy)
signal turn_completed  # Kept for compat

enum EnemyType { MINION, ELITE, BOSS, WERERAT, SKELETON, ARMORED_TROLL }

@export var enemy_name: String = "Enemy"
@export var enemy_type: EnemyType = EnemyType.MINION
@export var max_health: int = 30
@export var move_speed: float = 2.5   # Units per second
@export var attack_damage: int = 2
@export var attack_range: float = 1.5  # In world units (grid cells)
@export var aggro_range: float = 8.0   # In world units
@export var move_distance: float = 1.0 # Units per action (1 grid cell)
var xp_reward: int = 5                 # XP granted to player on kill

var current_health: int = 30
var max_armor: int = 0
var current_armor: int = 0
var is_exposed: bool = false          # True once armor has been broken to 0
var bonus_damage_next_hit: int = 0    # Applied on the next take_damage call, then cleared
var target: Node3D = null
var is_moving: bool = false
var target_position: Vector3
var is_dead: bool = false

var grid_manager: GridManager
var blocked_tiles: Array[Vector2i] = []  # Set by main.gd for barricade obstacles
var pillar_tiles: Array[Vector2i] = []   # Set by main.gd for rise pillars (traps enemy on top)

# Armor Break: set by card.execute() before attack, cleared after
var armor_break_incoming: bool = false

# Status effects applied by player cards (duration in tempo cycles, 1 cycle = 5 global tempo)
var taunt_target: Node3D = null
var taunt_tempo: int = 0       # Remaining tempo cycles for taunt
var attack_reduction: int = 0
var wear_down_tempo: int = 0   # Remaining tempo cycles for wear down
var slow_amount: int = 0       # Movement reduction from slow debuff
var slow_tempo: int = 0        # Remaining tempo cycles for slow
var is_disarmed: bool = false   # Cannot attack when disarmed
var disarmed_tempo: int = 0    # Remaining tempo cycles for disarm
var is_marked: bool = false    # Takes extra damage from player attacks
var marked_tempo: int = 0      # Remaining tempo for mark
var cold_stacks: int = 0       # Cold stacks - at 5, becomes frozen
var is_frozen: bool = false    # Cannot act when frozen
var frozen_tempo: int = 0      # Remaining tempo for frozen
var is_stunned: bool = false   # Cannot act when stunned
var stun_tempo: int = 0        # Remaining tempo cycles for stun
var burn_stacks: int = 0       # Burn damage tracker (doubles each cycle)
var burn_damage_next: int = 1  # Burn damage doubles each cycle (1, 2, 4, 8...)

# ============================================
# TEMPO ACTION SYSTEM
# ============================================

## Independent per-enemy tempo counter. Increments with global tempo.
var action_tempo_counter: int = 0

## Accumulator for tracking tempo cycles (used for status effect durations).
var _cycle_accumulator: int = 0

## All available actions for this enemy species.
## Each entry: { "name": String, "tempo_cost": int }
var actions: Array[Dictionary] = []

## Currently chosen action. The enemy commits to this action and waits for tempo.
var chosen_action: Dictionary = {}

## Armored Troll passive: accumulator for regeneration (heals 2 HP every 6 global tempo).
var regen_accumulator: int = 0

# ============================================
# TEMPO BAR VISUALS
# ============================================

var _tempo_bar_bg: MeshInstance3D
var _tempo_bar_fg: MeshInstance3D
var _action_label: Label3D
var _tempo_bar_width: float = 0.6

# Armor bar visuals (gray bar below health, only for armored enemies)
var _armor_bar_bg: MeshInstance3D
var _armor_bar_fg: MeshInstance3D
var _armor_label: Label3D
var _armor_bar_width: float = 0.6

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var health_label: Label3D = $HealthLabel
@onready var name_label: Label3D = $NameLabel
@onready var outline: MeshInstance3D = $Outline

func _ready() -> void:
	current_health = max_health
	target_position = position
	update_health_display()
	update_name_display()
	update_outline()

func initialize(type: EnemyType, gm: GridManager = null) -> void:
	enemy_type = type
	grid_manager = gm

	match enemy_type:
		EnemyType.MINION:
			enemy_name = "Minion"
			max_health = 25
			attack_damage = 3
			move_distance = 1.0
			xp_reward = 5
			_set_mesh_color(Color(0.8, 0.2, 0.2))

		EnemyType.ELITE:
			enemy_name = "Elite"
			max_health = 80
			attack_damage = 6
			move_distance = 0.8
			xp_reward = 10
			_set_mesh_color(Color(0.6, 0.1, 0.1))

		EnemyType.BOSS:
			enemy_name = "Boss"
			max_health = 200
			attack_damage = 10
			move_distance = 0.5
			xp_reward = 25
			_set_mesh_color(Color(0.4, 0.0, 0.2))

		EnemyType.WERERAT:
			enemy_name = "Wererat"
			max_health = 15
			attack_damage = 3
			move_distance = 1.0
			xp_reward = 5
			_set_mesh_color(Color(0.5, 0.35, 0.2))  # Brown

		EnemyType.SKELETON:
			enemy_name = "Skeleton"
			max_health = 18
			max_armor = 10
			attack_damage = 5
			move_distance = 1.0
			xp_reward = 5
			_set_mesh_color(Color(0.85, 0.85, 0.75))  # Bone white

		EnemyType.ARMORED_TROLL:
			enemy_name = "Armored Troll"
			max_health = 45
			max_armor = 30
			attack_damage = 4
			move_distance = 1.0
			xp_reward = 8
			_set_mesh_color(Color(0.2, 0.4, 0.15))  # Dark green

	current_health = max_health
	current_armor = max_armor
	update_health_display()
	update_name_display()
	update_outline()
	_setup_actions()
	_setup_tempo_bar()
	_setup_armor_bar()

	if grid_manager:
		position = grid_manager.snap_to_grid(position)
		target_position = position

func _set_mesh_color(color: Color) -> void:
	if mesh:
		var mat = mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			mat.albedo_color = color

func _setup_actions() -> void:
	## Define available actions per enemy species.
	match enemy_type:
		EnemyType.MINION:
			actions = [
				{"name": "attack", "tempo_cost": 3},
				{"name": "move",   "tempo_cost": 5},
			]
		EnemyType.ELITE:
			actions = [
				{"name": "attack", "tempo_cost": 4},
				{"name": "move",   "tempo_cost": 6},
			]
		EnemyType.BOSS:
			actions = [
				{"name": "attack", "tempo_cost": 5},
				{"name": "move",   "tempo_cost": 8},
			]
		EnemyType.WERERAT:
			actions = [
				{"name": "move",   "tempo_cost": 2},
				{"name": "bite",   "tempo_cost": 2},
				{"name": "scurry", "tempo_cost": 4},
			]
		EnemyType.SKELETON:
			actions = [
				{"name": "move",   "tempo_cost": 5},
				{"name": "attack", "tempo_cost": 4},
			]
		EnemyType.ARMORED_TROLL:
			actions = [
				{"name": "move",  "tempo_cost": 4},
				{"name": "kick",  "tempo_cost": 3},
				{"name": "smash", "tempo_cost": 6},
			]

# ============================================
# COMPENDIUM DATA
# ============================================

static func get_all_enemy_data() -> Array:
	## Returns compendium-friendly data for every enemy type.
	## Single source of truth — compendium reads from here.
	var _type_display := {
		EnemyType.MINION: "Minion",
		EnemyType.ELITE: "Elite",
		EnemyType.BOSS: "Boss",
		EnemyType.WERERAT: "Minion",
		EnemyType.SKELETON: "Minion",
		EnemyType.ARMORED_TROLL: "Elite",
	}
	var _stats := {
		EnemyType.MINION: {"name": "Minion", "health": 25, "armor": 0, "damage": 3, "xp": 5},
		EnemyType.ELITE: {"name": "Elite", "health": 80, "armor": 0, "damage": 6, "xp": 10},
		EnemyType.BOSS: {"name": "Boss", "health": 200, "armor": 0, "damage": 10, "xp": 25},
		EnemyType.WERERAT: {"name": "Wererat", "health": 15, "armor": 0, "damage": 3, "xp": 5},
		EnemyType.SKELETON: {"name": "Skeleton", "health": 18, "armor": 10, "damage": 5, "xp": 5},
		EnemyType.ARMORED_TROLL: {"name": "Armored Troll", "health": 45, "armor": 30, "damage": 4, "xp": 8},
	}
	var _actions := {
		EnemyType.MINION: [{"name": "Attack", "tempo": 3}, {"name": "Move", "tempo": 5}],
		EnemyType.ELITE: [{"name": "Attack", "tempo": 4}, {"name": "Move", "tempo": 6}],
		EnemyType.BOSS: [{"name": "Attack", "tempo": 5}, {"name": "Move", "tempo": 8}],
		EnemyType.WERERAT: [{"name": "Move", "tempo": 2}, {"name": "Bite", "tempo": 2}, {"name": "Scurry", "tempo": 4}],
		EnemyType.SKELETON: [{"name": "Move", "tempo": 5}, {"name": "Attack", "tempo": 4}],
		EnemyType.ARMORED_TROLL: [{"name": "Move", "tempo": 4}, {"name": "Kick", "tempo": 3}, {"name": "Smash", "tempo": 6}],
	}
	var _specials := {
		EnemyType.MINION: "Basic enemy.\nAt range ≤1: Attacks.\nOtherwise: Moves toward player.",
		EnemyType.ELITE: "Stronger than minions.\nAt range ≤1: Attacks.\nOtherwise: Moves toward player.",
		EnemyType.BOSS: "High health and damage.\nAt range ≤1: Attacks.\nOtherwise: Moves toward player.",
		EnemyType.WERERAT: "Fast and evasive.\nAt range ≤1: Bites.\nAt range ≥6: Scurries (dashes away).\nOtherwise: Moves toward player.",
		EnemyType.SKELETON: "Has armor that must be broken.\nAt range ≤1: Attacks.\nOtherwise: Moves toward player.",
		EnemyType.ARMORED_TROLL: "Regenerates 2 HP every 6 global tempo.\nAt range ≤1: 60% Smash / 40% Kick.\nOtherwise: Moves toward player.",
	}

	var result: Array = []
	for enemy_type in EnemyType.values():
		var s = _stats[enemy_type]
		result.append({
			"name": s["name"],
			"type": _type_display[enemy_type],
			"health": s["health"],
			"armor": s["armor"],
			"damage": s["damage"],
			"xp": s["xp"],
			"actions": _actions[enemy_type],
			"special": _specials[enemy_type],
		})
	return result

# ============================================
# TEMPO BAR SETUP
# ============================================

func _setup_tempo_bar() -> void:
	# Background bar (dark)
	_tempo_bar_bg = MeshInstance3D.new()
	var bg_quad = QuadMesh.new()
	bg_quad.size = Vector2(_tempo_bar_width, 0.06)
	_tempo_bar_bg.mesh = bg_quad
	var bg_mat = StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.15, 0.15, 0.1, 0.7)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.no_depth_test = true
	_tempo_bar_bg.material_override = bg_mat
	_tempo_bar_bg.position = Vector3(0, 1.15, 0)
	_tempo_bar_bg.visible = false
	add_child(_tempo_bar_bg)

	# Foreground bar (yellow fill)
	_tempo_bar_fg = MeshInstance3D.new()
	var fg_quad = QuadMesh.new()
	fg_quad.size = Vector2(0.01, 0.06)
	_tempo_bar_fg.mesh = fg_quad
	var fg_mat = StandardMaterial3D.new()
	fg_mat.albedo_color = Color(1.0, 0.85, 0.0, 0.9)  # Yellow
	fg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fg_mat.no_depth_test = true
	_tempo_bar_fg.material_override = fg_mat
	_tempo_bar_fg.position = Vector3(0, 1.15, 0.001)  # Slightly in front
	_tempo_bar_fg.visible = false
	add_child(_tempo_bar_fg)

	# Action label (above tempo bar)
	_action_label = Label3D.new()
	_action_label.position = Vector3(0, 1.25, 0)
	_action_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_action_label.font_size = 14
	_action_label.modulate = Color(1.0, 0.85, 0.0)  # Yellow text
	_action_label.text = ""
	add_child(_action_label)

	# Move name label up to make room for the tempo bar
	if name_label:
		name_label.position.y = 1.35

func _setup_armor_bar() -> void:
	if max_armor <= 0:
		return

	# Background bar (dark)
	_armor_bar_bg = MeshInstance3D.new()
	var bg_quad = QuadMesh.new()
	bg_quad.size = Vector2(_armor_bar_width, 0.06)
	_armor_bar_bg.mesh = bg_quad
	var bg_mat = StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.15, 0.15, 0.15, 0.7)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.no_depth_test = true
	_armor_bar_bg.material_override = bg_mat
	_armor_bar_bg.position = Vector3(0, 0.75, 0)
	add_child(_armor_bar_bg)

	# Foreground bar (gray fill)
	_armor_bar_fg = MeshInstance3D.new()
	var fg_quad = QuadMesh.new()
	fg_quad.size = Vector2(_armor_bar_width, 0.06)
	_armor_bar_fg.mesh = fg_quad
	var fg_mat = StandardMaterial3D.new()
	fg_mat.albedo_color = Color(0.6, 0.6, 0.6, 0.9)  # Gray
	fg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fg_mat.no_depth_test = true
	_armor_bar_fg.material_override = fg_mat
	_armor_bar_fg.position = Vector3(0, 0.75, 0.001)
	add_child(_armor_bar_fg)

	# Armor value label
	_armor_label = Label3D.new()
	_armor_label.position = Vector3(0, 0.75, 0.002)
	_armor_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_armor_label.font_size = 14
	_armor_label.modulate = Color(0.9, 0.9, 0.9)
	add_child(_armor_label)

	_update_armor_bar()

func _update_armor_bar() -> void:
	if not _armor_bar_bg:
		return

	if max_armor <= 0 or current_armor <= 0:
		_armor_bar_bg.visible = max_armor > 0  # Keep BG visible if enemy had armor (shows empty)
		_armor_bar_fg.visible = false
		if _armor_label:
			_armor_label.text = "0" if max_armor > 0 else ""
		return

	_armor_bar_bg.visible = true
	_armor_bar_fg.visible = true

	var progress = clampf(float(current_armor) / float(max_armor), 0.0, 1.0)
	var current_width = _armor_bar_width * progress

	var fg_mesh = _armor_bar_fg.mesh as QuadMesh
	if fg_mesh:
		fg_mesh.size.x = max(0.01, current_width)

	_armor_bar_fg.position.x = -(_armor_bar_width - current_width) / 2.0

	if _armor_label:
		_armor_label.text = str(current_armor)

# ============================================
# TEMPO-DRIVEN ACTION HANDLING
# ============================================

## Called by EnemySpawner whenever global tempo advances.
func on_tempo_advanced(amount: int, player_node: Node3D) -> void:
	if is_dead:
		return

	action_tempo_counter += amount
	_cycle_accumulator += amount

	# Armored Troll passive: regenerate 2 HP every 6 global tempo
	if enemy_type == EnemyType.ARMORED_TROLL:
		regen_accumulator += amount
		while regen_accumulator >= 6:
			regen_accumulator -= 6
			_regenerate(2)

	# Tick status effect durations once per tempo cycle (every 5 global tempo)
	while _cycle_accumulator >= 5:
		_cycle_accumulator -= 5
		_tick_status_durations()

	_check_and_fire_actions(player_node)
	_update_tempo_bar()

func _tick_status_durations() -> void:
	if taunt_tempo > 0:
		taunt_tempo -= 1
		if taunt_tempo <= 0:
			taunt_target = null
			print("[%s] Taunt expired" % enemy_name)

	if wear_down_tempo > 0:
		wear_down_tempo -= 1
		if wear_down_tempo <= 0:
			attack_reduction = 0
			print("[%s] Wear Down expired, attack restored" % enemy_name)

	if slow_tempo > 0:
		slow_tempo -= 1
		if slow_tempo <= 0:
			slow_amount = 0
			print("[%s] Slow expired, movement restored" % enemy_name)

	if disarmed_tempo > 0:
		disarmed_tempo -= 1
		if disarmed_tempo <= 0:
			is_disarmed = false
			print("[%s] Disarm expired, can attack again" % enemy_name)

	if marked_tempo > 0:
		marked_tempo -= 1
		if marked_tempo <= 0:
			is_marked = false
			print("[%s] Mark expired" % enemy_name)

	if frozen_tempo > 0:
		frozen_tempo -= 1
		if frozen_tempo <= 0:
			is_frozen = false
			print("[%s] Frozen expired, can act again" % enemy_name)

	if stun_tempo > 0:
		stun_tempo -= 1
		if stun_tempo <= 0:
			is_stunned = false
			print("[%s] Stun expired, can act again" % enemy_name)

	# Burn: deal doubling damage each cycle (1, 2, 4, 8...)
	if burn_stacks > 0:
		take_damage(burn_damage_next, false)
		print("[%s] Burn deals %d damage (doubles next cycle)" % [enemy_name, burn_damage_next])
		burn_damage_next *= 2
		burn_stacks -= 1
		if burn_stacks <= 0:
			burn_damage_next = 1
			print("[%s] Burn expired" % enemy_name)

	_update_status_indicators()

func _check_and_fire_actions(player_node: Node3D) -> void:
	if not player_node:
		return

	# Skip actions if stunned or frozen
	if is_stunned:
		print("[%s] Stunned - cannot act!" % enemy_name)
		return
	if is_frozen:
		print("[%s] Frozen - cannot act!" % enemy_name)
		return

	# Skip actions if player is invisible
	if player_node.has_method("get_buff_manager"):
		var p_buff_mgr = player_node.get_buff_manager()
		if p_buff_mgr and p_buff_mgr.is_invisible():
			return

	# Choose action if we don't have one yet
	if chosen_action.is_empty():
		_choose_action(player_node)

	if chosen_action.is_empty():
		return

	# Fire when enough tempo has accumulated for the chosen action
	if action_tempo_counter >= chosen_action["tempo_cost"]:
		var move_target = player_node
		if taunt_target and is_instance_valid(taunt_target):
			move_target = taunt_target

		_execute_action(chosen_action["name"], move_target)
		action_tempo_counter = 0
		chosen_action = {}
		# Immediately choose next action so the bar shows what's coming
		_choose_action(player_node)

# ============================================
# AI - ACTION SELECTION
# ============================================

func _choose_action(player_node: Node3D) -> void:
	if actions.is_empty() or not player_node:
		chosen_action = {}
		return

	var distance = _get_cell_distance(player_node)

	match enemy_type:
		EnemyType.WERERAT:
			_choose_wererat_action(distance)
		EnemyType.SKELETON:
			_choose_skeleton_action(distance)
		EnemyType.ARMORED_TROLL:
			_choose_troll_action(distance)
		_:
			_choose_legacy_action(distance)

	if not chosen_action.is_empty():
		print("[%s] Chose action: %s (cost: %d tempo)" % [enemy_name, chosen_action["name"], chosen_action["tempo_cost"]])

func _get_cell_distance(target_node: Node3D) -> int:
	if grid_manager:
		return grid_manager.get_distance_in_cells(position, target_node.position)
	var diff = target_node.position - position
	return int(Vector3(diff.x, 0, diff.z).length())

func _choose_wererat_action(distance: int) -> void:
	if distance <= 1:
		chosen_action = _get_action("bite")
	elif distance >= 6:
		chosen_action = _get_action("scurry")
	else:
		chosen_action = _get_action("move")

func _choose_skeleton_action(distance: int) -> void:
	if distance <= 1:
		chosen_action = _get_action("attack")
	else:
		chosen_action = _get_action("move")

func _choose_troll_action(distance: int) -> void:
	if distance <= 1:
		# 60% smash (heavy), 40% kick (fast)
		if randf() < 0.6:
			chosen_action = _get_action("smash")
		else:
			chosen_action = _get_action("kick")
	else:
		chosen_action = _get_action("move")

func _choose_legacy_action(distance: int) -> void:
	## Legacy behavior for MINION/ELITE/BOSS types.
	if distance <= 1:
		for action in actions:
			if action["name"] == "attack":
				chosen_action = action
				return
	chosen_action = _get_action("move")
	if chosen_action.is_empty() and actions.size() > 0:
		chosen_action = actions[0]

func _get_action(action_name: String) -> Dictionary:
	for action in actions:
		if action["name"] == action_name:
			return action
	return actions[0] if actions.size() > 0 else {}

# ============================================
# ACTION EXECUTION
# ============================================

func _execute_action(action_name: String, move_target: Node3D) -> bool:
	match action_name:
		"attack":
			return _try_attack(move_target)
		"move":
			return _try_move(move_target)
		"bite":
			return _try_bite(move_target)
		"scurry":
			return _try_scurry(move_target)
		"kick":
			return _try_kick(move_target)
		"smash":
			return _try_smash(move_target)
		_:
			push_warning("[%s] Unknown action: %s" % [enemy_name, action_name])
			return false

func _try_attack(target_node: Node3D) -> bool:
	if is_disarmed:
		print("[%s] Disarmed - cannot attack!" % enemy_name)
		return _try_move(target_node)
	var diff = target_node.position - position
	var flat_dist = Vector3(diff.x, 0, diff.z).length()
	if flat_dist <= attack_range:
		_deal_damage_to_player(target_node, attack_damage, "Attack")
		turn_completed.emit()
		return true
	return _try_move(target_node)

func _try_move(target_node: Node3D) -> bool:
	var diff = target_node.position - position
	var flat_dist = Vector3(diff.x, 0, diff.z).length()
	if flat_dist <= aggro_range:
		move_towards_target(target_node.position)
		return true
	return false  # Out of aggro range - idle

func _try_bite(target_node: Node3D) -> bool:
	if is_disarmed:
		return _try_move(target_node)
	var diff = target_node.position - position
	var flat_dist = Vector3(diff.x, 0, diff.z).length()
	if flat_dist <= attack_range:
		_deal_damage_to_player(target_node, 3, "Bite")
		turn_completed.emit()
		return true
	return _try_move(target_node)

func _try_scurry(target_node: Node3D) -> bool:
	## Wererat dashes 5 tiles toward the target.
	var tiles = 5
	var effective_tiles = tiles
	if slow_amount > 0:
		effective_tiles = max(1, tiles - slow_amount)
	_dash_towards_target(target_node.position, effective_tiles)
	print("[%s] Scurries %d tiles toward target!" % [enemy_name, effective_tiles])
	return true

func _try_kick(target_node: Node3D) -> bool:
	if is_disarmed:
		return _try_move(target_node)
	var diff = target_node.position - position
	var flat_dist = Vector3(diff.x, 0, diff.z).length()
	if flat_dist <= attack_range:
		_deal_damage_to_player(target_node, 4, "Kick")
		turn_completed.emit()
		return true
	return _try_move(target_node)

func _try_smash(target_node: Node3D) -> bool:
	if is_disarmed:
		return _try_move(target_node)
	var diff = target_node.position - position
	var flat_dist = Vector3(diff.x, 0, diff.z).length()
	if flat_dist <= attack_range:
		_deal_damage_to_player(target_node, 10, "Smash")
		# Inject Lightly Dazed card into player's hand
		if target_node.has_method("get_deck_manager"):
			var dm = target_node.get_deck_manager()
			if dm:
				dm.add_card_to_hand(Card.create_lightly_dazed())
				print("[%s] Smash added Lightly Dazed to player's hand!" % enemy_name)
		turn_completed.emit()
		return true
	return _try_move(target_node)

## Deal damage to the player with attack flash.
func _deal_damage_to_player(player_node: Node3D, base_damage: int, attack_name: String) -> void:
	var effective_damage = max(0, base_damage - attack_reduction)
	print("[%s] %s for %d damage! (base %d, reduction %d)" % [enemy_name, attack_name, effective_damage, base_damage, attack_reduction])

	if player_node.has_method("get_stats"):
		var player_stats_ref = player_node.get_stats()
		if player_stats_ref and effective_damage > 0:
			var debuff_mgr = null
			var buff_mgr = null
			if player_node.has_method("get_debuff_manager"):
				debuff_mgr = player_node.get_debuff_manager()
			if player_node.has_method("get_buff_manager"):
				buff_mgr = player_node.get_buff_manager()

			# Check Repelled Block: if armor fully blocks the attack, negate damage and push
			if buff_mgr and buff_mgr.has_buff(Buff.BuffType.REPELLED_BLOCK):
				if player_stats_ref.current_armor >= effective_damage:
					# Fully blocked - consume the buff, negate damage, push enemy back 4 and player back 2
					var rb = buff_mgr.get_buff(Buff.BuffType.REPELLED_BLOCK)
					rb.use_charge()
					if rb.is_expired():
						buff_mgr.remove_buff(Buff.BuffType.REPELLED_BLOCK)
					# Push enemy away from player
					knockback(player_node.position, 4)
					# Push player away from enemy
					if player_node.has_method("blink_to") and grid_manager:
						var player_diff = player_node.position - position
						var player_dir = Vector3(player_diff.x, 0, player_diff.z).normalized()
						var player_new_pos = player_node.position + player_dir * 2.0
						player_new_pos = grid_manager.snap_to_grid(player_new_pos)
						player_node.position = player_new_pos
						player_node.target_position = player_new_pos
					print("[%s] Repelled Block triggered! Enemy pushed back 4, player pushed back 2" % enemy_name)
					return  # Skip damage entirely

			player_stats_ref.take_damage(effective_damage, debuff_mgr, buff_mgr)

			if player_node.has_method("get_inventory"):
				var p_inventory = player_node.get_inventory()
				if p_inventory:
					p_inventory.on_damage_taken()

	if mesh:
		var tween = create_tween()
		var mat = mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			var orig_color = mat.albedo_color
			tween.tween_property(mat, "albedo_color", Color.ORANGE, 0.1)
			tween.tween_property(mat, "albedo_color", orig_color, 0.1)

## Dash multiple tiles toward a position in one action.
## Stops at any barricade tile encountered along the path.
func _dash_towards_target(pos: Vector3, tiles: int) -> void:
	# Enemies trapped on a rise pillar cannot dash
	if grid_manager:
		var current_cell = grid_manager.world_to_grid(position)
		if current_cell in pillar_tiles:
			print("[%s] Trapped on pillar - cannot dash!" % enemy_name)
			return

	var diff = pos - position
	var direction = Vector3(diff.x, 0, diff.z).normalized()
	if grid_manager:
		# Step tile by tile and stop before any blocked tile
		var last_valid = position
		for i in range(1, tiles + 1):
			var step_pos = position + direction * (i * 1.0)
			step_pos = grid_manager.snap_to_grid(step_pos)
			var step_cell = grid_manager.world_to_grid(step_pos)
			if step_cell in blocked_tiles:
				print("[%s] Dash blocked by barricade at tile %d!" % [enemy_name, i])
				break
			last_valid = step_pos
		if last_valid == position:
			return  # Can't move at all
		target_position = last_valid
	else:
		var new_target = position + direction * (tiles * 1.0)
		target_position = new_target
	is_moving = true

## Armored Troll passive: heal HP with green flash.
func _regenerate(amount: int) -> void:
	if is_dead:
		return
	var healed = min(amount, max_health - current_health)
	if healed <= 0:
		return
	current_health += healed
	update_health_display()
	print("[%s] Regenerates %d health! (%d/%d)" % [enemy_name, healed, current_health, max_health])
	if mesh:
		var tween = create_tween()
		var mat = mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			var orig_color = mat.albedo_color
			tween.tween_property(mat, "albedo_color", Color.GREEN, 0.15)
			tween.tween_property(mat, "albedo_color", orig_color, 0.15)

# ============================================
# TEMPO BAR VISUAL UPDATE
# ============================================

func _update_tempo_bar() -> void:
	if not _tempo_bar_bg or not _tempo_bar_fg:
		return

	if chosen_action.is_empty():
		_tempo_bar_bg.visible = false
		_tempo_bar_fg.visible = false
		if _action_label:
			_action_label.text = ""
		return

	_tempo_bar_bg.visible = true
	_tempo_bar_fg.visible = true

	var cost = chosen_action.get("tempo_cost", 1)
	var progress = clampf(float(action_tempo_counter) / float(cost), 0.0, 1.0)
	var current_width = _tempo_bar_width * progress

	var fg_mesh = _tempo_bar_fg.mesh as QuadMesh
	if fg_mesh:
		fg_mesh.size.x = max(0.01, current_width)

	# Offset foreground so the bar fills from left to right
	_tempo_bar_fg.position.x = -(_tempo_bar_width - current_width) / 2.0

	if _action_label:
		_action_label.text = chosen_action.get("name", "").capitalize()

# ============================================
# PHYSICS
# ============================================

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if is_moving:
		var diff = target_position - position
		var flat_diff = Vector3(diff.x, 0, diff.z)
		var distance = flat_diff.length()

		if distance < 0.1:
			position = target_position
			is_moving = false
			velocity = Vector3.ZERO
			turn_completed.emit()
		else:
			velocity = flat_diff.normalized() * move_speed
	else:
		velocity = Vector3.ZERO

	move_and_slide()

# ============================================
# MOVEMENT & COMBAT
# ============================================

func set_target(new_target: Node3D) -> void:
	target = new_target

func move_towards_target(pos: Vector3) -> void:
	# Enemies trapped on a rise pillar cannot move until it expires
	if grid_manager:
		var current_cell = grid_manager.world_to_grid(position)
		if current_cell in pillar_tiles:
			print("[%s] Trapped on pillar - cannot move!" % enemy_name)
			return

	var diff = pos - position
	var direction = Vector3(diff.x, 0, diff.z).normalized()
	var effective_move = move_distance
	if slow_amount > 0 and grid_manager:
		effective_move = max(0, move_distance - slow_amount * grid_manager.grid_size)
	elif slow_amount > 0:
		effective_move = max(0, move_distance - slow_amount * 1.0)
	if effective_move <= 0:
		print("[%s] Too slowed to move!" % enemy_name)
		return
	var new_target = position + direction * effective_move

	if grid_manager:
		new_target = grid_manager.snap_to_grid(new_target)
		# Don't walk into barricade tiles
		var target_cell = grid_manager.world_to_grid(new_target)
		if target_cell in blocked_tiles:
			print("[%s] Path blocked by barricade!" % enemy_name)
			return

	target_position = new_target
	is_moving = true

func attack_player(player_node: Node3D) -> void:
	_deal_damage_to_player(player_node, attack_damage, "Attack")

# ============================================
# TAKING DAMAGE
# ============================================

## Deal damage to this enemy. Armor absorbs first, remainder hits health.
## Set from_player = true when the damage originates from the player's card/attack.
## Returns true if the enemy was just Exposed (armor broken to 0).
func take_damage(amount: int, from_player: bool = false) -> bool:
	if is_dead:
		return false

	if wear_down_tempo > 0:
		attack_reduction += 1
		print("[%s] Wear Down stacks! Attack reduced by %d" % [enemy_name, attack_reduction])
		_update_status_indicators()

	# Apply premeditated bonus damage (only from player attacks)
	if from_player and bonus_damage_next_hit > 0:
		print("[%s] Premeditated bonus: +%d damage!" % [enemy_name, bonus_damage_next_hit])
		amount += bonus_damage_next_hit
		bonus_damage_next_hit = 0

	# Armor Break: double damage to armor, no health damage. Zero effect on unarmored.
	var just_exposed = false
	if armor_break_incoming and current_armor <= 0:
		amount = 0
		print("[%s] Armor Break: no armor to break, no damage dealt" % enemy_name)
	elif armor_break_incoming and current_armor > 0:
		var doubled = amount * 2
		var armor_absorbed = min(current_armor, doubled)
		current_armor -= armor_absorbed
		print("[%s] Armor Break! %d doubled damage to armor! Armor: %d/%d" % [enemy_name, armor_absorbed, current_armor, max_armor])
		_update_armor_bar()
		if current_armor <= 0:
			just_exposed = true
			is_exposed = true
			print("[%s] EXPOSED! Armor broken!" % enemy_name)
		amount = 0  # No spillover to health
	elif current_armor > 0:
		# Normal armor absorbs damage first
		var was_armored = current_armor > 0
		var armor_absorbed = min(current_armor, amount)
		current_armor -= armor_absorbed
		amount -= armor_absorbed
		print("[%s] Armor absorbed %d damage! Armor: %d/%d" % [enemy_name, armor_absorbed, current_armor, max_armor])
		_update_armor_bar()
		if was_armored and current_armor <= 0:
			just_exposed = true
			is_exposed = true
			print("[%s] EXPOSED! Armor broken!" % enemy_name)

	# Remaining damage hits health (skipped if armor break consumed all damage)
	if amount > 0:
		current_health -= amount
		current_health = max(0, current_health)

	damaged.emit(amount)
	update_health_display()

	# Floating damage number
	_spawn_damage_number(amount, just_exposed)

	if mesh:
		var tween = create_tween()
		var mat = mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			var orig_color = mat.albedo_color
			tween.tween_property(mat, "albedo_color", Color.RED, 0.1)
			tween.tween_property(mat, "albedo_color", orig_color, 0.1)

	print("[%s] Took damage! Health: %d/%d, Armor: %d/%d" % [enemy_name, current_health, max_health, current_armor, max_armor])

	if current_health <= 0:
		die()

	return just_exposed

# ============================================
# FLOATING DAMAGE NUMBERS
# ============================================

func _spawn_damage_number(amount: int, was_exposed: bool = false) -> void:
	if amount <= 0:
		return

	var label = Label3D.new()
	label.text = str(amount)
	label.font_size = 28 if amount >= 10 else 22
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 50

	# Color based on damage significance
	if was_exposed:
		label.modulate = Color(1.0, 0.5, 0.0)  # Orange for armor break
		label.font_size = 32
		label.text = str(amount) + "!"
	elif amount >= 15:
		label.modulate = Color(1.0, 0.2, 0.2)  # Bright red for big hits
		label.font_size = 32
	elif amount >= 8:
		label.modulate = Color(1.0, 0.5, 0.3)  # Orange-red for medium hits
	else:
		label.modulate = Color(1.0, 0.85, 0.5)  # Yellow for small hits

	# Random horizontal offset to avoid stacking
	var x_offset = randf_range(-0.3, 0.3)
	label.position = position + Vector3(x_offset, 1.5, 0)
	get_parent().add_child(label)

	# Animate: float up and fade out
	var tween = label.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 1.5, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.3)
	# Slight scale up then down
	tween.tween_property(label, "font_size", label.font_size + 6, 0.1)
	tween.chain()
	tween.tween_property(label, "font_size", label.font_size, 0.3)

	tween.chain()
	tween.tween_callback(label.queue_free)

# ============================================
# STATUS EFFECTS
# ============================================

func apply_taunt(taunter: Node3D, cycles: int) -> void:
	taunt_target = taunter
	taunt_tempo = cycles
	print("[%s] Taunted for %d tempo cycles" % [enemy_name, cycles])
	_update_status_indicators()

func set_armor_break_incoming(value: bool) -> void:
	armor_break_incoming = value

func apply_wear_down(cycles: int) -> void:
	wear_down_tempo = max(wear_down_tempo, cycles)
	print("[%s] Wear Down applied for %d tempo cycles" % [enemy_name, wear_down_tempo])
	_update_status_indicators()

func apply_debuff(debuff_name: String, value: int) -> void:
	match debuff_name:
		"stun":
			is_stunned = true
			stun_tempo = max(stun_tempo, value)
			# Reset action tempo counter so stun delays their next action
			action_tempo_counter = 0
			chosen_action = {}
			print("[%s] Stunned for %d tempo cycles!" % [enemy_name, stun_tempo])
		"slow":
			slow_amount = value
			slow_tempo = 2  # Lasts 2 tempo cycles
			print("[%s] Slowed by %d movement for 2 tempo cycles" % [enemy_name, value])
		"disarmed":
			is_disarmed = true
			disarmed_tempo = value
			print("[%s] Disarmed for %d tempo cycles" % [enemy_name, value])
		"marked":
			is_marked = true
			marked_tempo = value
			print("[%s] Marked for %d tempo cycles" % [enemy_name, value])
		"silenced":
			print("[%s] Silenced for %d tempo cycles" % [enemy_name, value])
		"choke_dot":
			print("[%s] Choke DoT for %d tempo cycles" % [enemy_name, value])
		"burn":
			burn_stacks += value
			print("[%s] Burning! Stacks: %d" % [enemy_name, burn_stacks])
		"cold":
			cold_stacks += value
			print("[%s] Cold applied! Stacks: %d/5" % [enemy_name, cold_stacks])
			if cold_stacks >= 5:
				cold_stacks = 0
				is_frozen = true
				frozen_tempo = max(frozen_tempo, 1)  # Frozen for 1 tempo cycle
				# Reset action tempo counter so frozen delays their next action
				action_tempo_counter = 0
				chosen_action = {}
				print("[%s] FROZEN! Cold reached 5 stacks!" % enemy_name)
		_:
			print("[%s] Unknown debuff: %s" % [enemy_name, debuff_name])
	_update_status_indicators()

func apply_stun(tempo_cycles: int = 1) -> void:
	apply_debuff("stun", tempo_cycles)

func knockback(away_from: Vector3, spaces: int = 1) -> void:
	if is_dead:
		return
	if not grid_manager:
		return
	var diff = position - away_from
	# Determine grid direction: allow diagonal by using sign of each axis
	var dir_x = 0
	var dir_z = 0
	if abs(diff.x) > 0.1:
		dir_x = 1 if diff.x > 0 else -1
	if abs(diff.z) > 0.1:
		dir_z = 1 if diff.z > 0 else -1
	if dir_x == 0 and dir_z == 0:
		return
	# Step tile-by-tile, stopping at blocked tiles
	var current_cell = grid_manager.world_to_grid(position)
	var last_valid_cell = current_cell
	for i in range(spaces):
		var next_cell = Vector2i(current_cell.x + dir_x * (i + 1), current_cell.y + dir_z * (i + 1))
		if next_cell in blocked_tiles:
			break
		last_valid_cell = next_cell
	var new_pos = grid_manager.grid_to_world(last_valid_cell)
	position = new_pos
	target_position = new_pos
	print("[%s] Knocked back %d space(s)" % [enemy_name, spaces])

# ============================================
# HEALTH & DISPLAY
# ============================================

func update_health_display() -> void:
	if health_label:
		health_label.text = "%d / %d" % [current_health, max_health]

func update_outline() -> void:
	if not outline:
		return
	var mat = outline.get_surface_override_material(0) as StandardMaterial3D
	match enemy_type:
		EnemyType.ELITE:
			outline.visible = true
			if mat:
				mat.albedo_color = Color(1.0, 0.85, 0.0, 0.8)
		EnemyType.BOSS:
			outline.visible = true
			if mat:
				mat.albedo_color = Color(0.8, 0.0, 0.8, 0.8)
		EnemyType.ARMORED_TROLL:
			outline.visible = true
			if mat:
				mat.albedo_color = Color(0.0, 0.8, 0.2, 0.8)  # Green glow
		_:
			outline.visible = false

func update_name_display() -> void:
	if name_label:
		name_label.text = enemy_name
		match enemy_type:
			EnemyType.ELITE:
				name_label.modulate = Color(1.0, 0.85, 0.0)
			EnemyType.BOSS:
				name_label.modulate = Color(0.8, 0.0, 0.8)
			EnemyType.ARMORED_TROLL:
				name_label.modulate = Color(0.4, 1.0, 0.3)  # Green
			_:
				name_label.modulate = Color(1.0, 1.0, 1.0)

func die() -> void:
	is_dead = true
	chosen_action = {}
	print("[%s] Defeated!" % enemy_name)
	died.emit(self)

	# Hide tempo bar on death
	if _tempo_bar_bg:
		_tempo_bar_bg.visible = false
	if _tempo_bar_fg:
		_tempo_bar_fg.visible = false
	if _action_label:
		_action_label.text = ""
	# Hide armor bar on death
	if _armor_bar_bg:
		_armor_bar_bg.visible = false
	if _armor_bar_fg:
		_armor_bar_fg.visible = false
	if _armor_label:
		_armor_label.text = ""

	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.5)
	tween.tween_callback(queue_free)

func is_alive() -> bool:
	return not is_dead

# ============================================
# STATUS EFFECT DATA & VISUAL INDICATORS
# ============================================

## Status indicator container (circles above enemy head)
var _status_container: Node3D = null
var _status_nodes: Array = []  # [{node: Node3D, ...}]
const MAX_VISIBLE_STATUS: int = 5

## Returns a list of active status effects as dictionaries.
## Each: { "name": String, "color": Color, "stacks": int }
func get_active_effects() -> Array[Dictionary]:
	var effects: Array[Dictionary] = []

	if taunt_tempo > 0:
		effects.append({"name": "Taunt", "color": Color(1.0, 0.6, 0.0), "stacks": taunt_tempo})
	if wear_down_tempo > 0:
		var wd_stacks = attack_reduction if attack_reduction > 0 else wear_down_tempo
		effects.append({"name": "Wear Down", "color": Color(0.9, 0.6, 0.3), "stacks": wd_stacks})
	if slow_tempo > 0:
		effects.append({"name": "Slow", "color": Color(0.4, 0.6, 1.0), "stacks": slow_amount})
	if is_disarmed and disarmed_tempo > 0:
		effects.append({"name": "Disarm", "color": Color(0.8, 0.3, 0.3), "stacks": disarmed_tempo})
	if is_marked and marked_tempo > 0:
		effects.append({"name": "Marked", "color": Color(1.0, 0.2, 0.2), "stacks": marked_tempo})
	if is_exposed:
		effects.append({"name": "Exposed", "color": Color(1.0, 1.0, 0.3), "stacks": 1})
	if is_stunned and stun_tempo > 0:
		effects.append({"name": "Stun", "color": Color(1.0, 1.0, 0.0), "stacks": stun_tempo})
	if is_frozen and frozen_tempo > 0:
		effects.append({"name": "Frozen", "color": Color(0.5, 0.8, 1.0), "stacks": frozen_tempo})
	if burn_stacks > 0:
		effects.append({"name": "Burn", "color": Color(1.0, 0.5, 0.0), "stacks": burn_stacks})
	if cold_stacks > 0:
		effects.append({"name": "Cold", "color": Color(0.4, 0.7, 1.0), "stacks": cold_stacks})

	return effects

func _update_status_indicators() -> void:
	## Renders colored circles above the enemy's head for active buffs/debuffs.
	## Each circle has a small number showing stacks, positioned at the bottom-right.
	## Caps at MAX_VISIBLE_STATUS on the battlefield; shows "+" if more exist.
	if not is_instance_valid(self):
		return

	# Create the container on first use
	if not _status_container:
		_status_container = Node3D.new()
		_status_container.position = Vector3(0, 1.9, 0)
		add_child(_status_container)

	# Remove old nodes
	for entry in _status_nodes:
		if is_instance_valid(entry["node"]):
			entry["node"].queue_free()
	_status_nodes.clear()

	var effects = get_active_effects()
	if effects.is_empty():
		return

	var show_count = min(effects.size(), MAX_VISIBLE_STATUS)
	var has_overflow = effects.size() > MAX_VISIBLE_STATUS
	var total_slots = show_count + (1 if has_overflow else 0)

	var circle_size: float = 0.12
	var spacing: float = 0.28
	var start_x: float = -(total_slots - 1) * spacing / 2.0

	for i in range(show_count):
		var eff = effects[i]
		var node = _create_status_circle(eff["color"], eff["stacks"], circle_size)
		node.position = Vector3(start_x + i * spacing, 0, 0)
		_status_container.add_child(node)
		_status_nodes.append({"node": node})

	# Overflow indicator "+"
	if has_overflow:
		var plus_label = Label3D.new()
		plus_label.text = "+"
		plus_label.font_size = 20
		plus_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		plus_label.modulate = Color(1, 1, 1)
		plus_label.position = Vector3(start_x + show_count * spacing, 0, 0)
		_status_container.add_child(plus_label)
		_status_nodes.append({"node": plus_label})

func _create_status_circle(color: Color, stacks: int, radius: float) -> Node3D:
	## Creates a billboard colored circle with a stack count number at the bottom-right.
	var root = Node3D.new()

	# Circle mesh (flat disc facing camera via billboard)
	var circle_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 0.3
	circle_mesh.mesh = sphere
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	circle_mesh.material_override = mat
	root.add_child(circle_mesh)

	# Stack count label (bottom-right of circle)
	if stacks > 0:
		var label = Label3D.new()
		label.text = str(stacks)
		label.font_size = 16
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(1, 1, 1)
		label.outline_modulate = Color(0, 0, 0)
		label.outline_size = 4
		label.position = Vector3(radius * 0.6, -radius * 0.5, 0.01)
		root.add_child(label)

	return root
