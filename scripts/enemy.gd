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

# Status effects applied by player cards (duration in tempo cycles, 1 cycle = 5 global tempo)
var taunt_target: Node3D = null
var taunt_tempo: int = 0       # Remaining tempo cycles for taunt
var attack_reduction: int = 0
var wear_down_tempo: int = 0   # Remaining tempo cycles for wear down
var slow_amount: int = 0       # Movement reduction from slow debuff
var slow_tempo: int = 0        # Remaining tempo cycles for slow
var is_disarmed: bool = false   # Cannot attack when disarmed
var disarmed_tempo: int = 0    # Remaining tempo cycles for disarm

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
			_set_mesh_color(Color(0.8, 0.2, 0.2))

		EnemyType.ELITE:
			enemy_name = "Elite"
			max_health = 80
			attack_damage = 6
			move_distance = 0.8
			_set_mesh_color(Color(0.6, 0.1, 0.1))

		EnemyType.BOSS:
			enemy_name = "Boss"
			max_health = 200
			attack_damage = 10
			move_distance = 0.5
			_set_mesh_color(Color(0.4, 0.0, 0.2))

		EnemyType.WERERAT:
			enemy_name = "Wererat"
			max_health = 15
			attack_damage = 3
			move_distance = 1.0
			_set_mesh_color(Color(0.5, 0.35, 0.2))  # Brown

		EnemyType.SKELETON:
			enemy_name = "Skeleton"
			max_health = 18
			max_armor = 10
			attack_damage = 5
			move_distance = 1.0
			_set_mesh_color(Color(0.85, 0.85, 0.75))  # Bone white

		EnemyType.ARMORED_TROLL:
			enemy_name = "Armored Troll"
			max_health = 45
			max_armor = 30
			attack_damage = 4
			move_distance = 1.0
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

func _check_and_fire_actions(player_node: Node3D) -> void:
	if not player_node:
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
func _dash_towards_target(pos: Vector3, tiles: int) -> void:
	var diff = pos - position
	var direction = Vector3(diff.x, 0, diff.z).normalized()
	var new_target = position + direction * (tiles * 1.0)
	if grid_manager:
		new_target = grid_manager.snap_to_grid(new_target)
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

	# Apply premeditated bonus damage (only from player attacks)
	if from_player and bonus_damage_next_hit > 0:
		print("[%s] Premeditated bonus: +%d damage!" % [enemy_name, bonus_damage_next_hit])
		amount += bonus_damage_next_hit
		bonus_damage_next_hit = 0

	# Armor absorbs damage first
	var just_exposed = false
	if current_armor > 0:
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

	# Remaining damage hits health
	if amount > 0:
		current_health -= amount
		current_health = max(0, current_health)

	damaged.emit(amount)
	update_health_display()

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
# STATUS EFFECTS
# ============================================

func apply_taunt(taunter: Node3D, cycles: int) -> void:
	taunt_target = taunter
	taunt_tempo = cycles
	print("[%s] Taunted for %d tempo cycles" % [enemy_name, cycles])

func apply_wear_down(cycles: int) -> void:
	wear_down_tempo = max(wear_down_tempo, cycles)
	print("[%s] Wear Down applied for %d tempo cycles" % [enemy_name, wear_down_tempo])

func apply_debuff(debuff_name: String, value: int) -> void:
	match debuff_name:
		"slow":
			slow_amount = value
			slow_tempo = 2  # Lasts 2 tempo cycles
			print("[%s] Slowed by %d movement for 2 tempo cycles" % [enemy_name, value])
		"disarmed":
			is_disarmed = true
			disarmed_tempo = value
			print("[%s] Disarmed for %d tempo cycles" % [enemy_name, value])
		"silenced":
			print("[%s] Silenced for %d tempo cycles" % [enemy_name, value])
		"choke_dot":
			print("[%s] Choke DoT for %d tempo cycles" % [enemy_name, value])
		_:
			print("[%s] Unknown debuff: %s" % [enemy_name, debuff_name])

func knockback(away_from: Vector3, spaces: int = 1) -> void:
	if is_dead:
		return
	var diff = position - away_from
	var direction = Vector3(diff.x, 0, diff.z).normalized()
	var new_pos = position + direction * (spaces * 1.0)
	if grid_manager:
		new_pos = grid_manager.snap_to_grid(new_pos)
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
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(queue_free)

func is_alive() -> bool:
	return not is_dead
