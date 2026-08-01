extends SceneTree

## Dev helper: boot the battle with a given character, spawn a sampler of
## MonsterKit-sprited enemies near the player, and capture idle / attack frames.
## Runs in slow motion so Tween/frame animations get caught by software GL.
##   ... --script tests/_capture_battle_sprites.gd -- <prefix> <Character>

var _main: Node = null
var _cam: Camera3D = null
var _frames := 0
var _prefix := "/tmp/battle_sprites"
var _trig := -999
var _keep_ui := false  # pass "keepui" as 3rd arg to leave the HUD visible

func _initialize() -> void:
	Engine.time_scale = 0.12
	var args := OS.get_cmdline_user_args()
	var who := "Brad"
	if args.size() > 0:
		_prefix = args[0]
	if args.size() > 1:
		who = args[1]
	if args.size() > 2 and args[2] == "keepui":
		_keep_ui = true
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	_main = packed.instantiate()
	_main.set("starting_character", _make_char(who))
	get_root().add_child(_main)

func _make_char(who: String) -> CharacterData:
	match who:
		"Ryan": return CharacterData.create_ryan()
		"Jeremy": return CharacterData.create_jeremy()
		"Stephen": return CharacterData.create_stephen()
		"Cory": return CharacterData.create_cory()
		_: return CharacterData.create_brad()

func _process(_delta: float) -> bool:
	_frames += 1
	var player := _main.get_node_or_null("Player")
	# Every frame: dismiss dialogs, hide HUD, keep our camera glued to the player.
	_press_continue(get_root())
	_hide_ui()
	if _cam and is_instance_valid(player):
		var p: Vector3 = player.global_position
		_cam.global_position = p + Vector3(1.4, 3.0, 4.6)
		_cam.look_at(p + Vector3(1.2, 0.4, 0.3), Vector3.UP)
		_cam.current = true
	match _frames:
		24:
			_respawn_enemies(player)
		30:
			_add_camera()
		70:
			_save("_idle.png")
		80:
			if player: player.play_animation("attack_slash", CharacterAnimator.Direction.EAST)
			_poke_enemies("attack")
			_trig = _frames
		230:
			if player: player.play_animation("heavy_swing", CharacterAnimator.Direction.SOUTH)
			_poke_enemies("hit")
			_trig = _frames
		390:
			quit()
	var dt := _frames - _trig
	if _trig == 80 and dt in [10, 22, 36]:
		_save("_attack_%d.png" % dt)
	if _trig == 230 and dt in [12, 28]:
		_save("_axe_%d.png" % dt)
	return false

func _respawn_enemies(player: Node) -> void:
	var spawner := _main.get_node_or_null("EnemySpawner")
	if spawner == null or player == null:
		return
	spawner.clear_enemies()
	var p: Vector3 = player.global_position
	var kinds := [Enemy.EnemyType.WOLF, Enemy.EnemyType.SKELETON, Enemy.EnemyType.SLUDGE,
			Enemy.EnemyType.GIANT_HAWK, Enemy.EnemyType.TREANT, Enemy.EnemyType.SWARM,
			Enemy.EnemyType.SEWER_CROC, Enemy.EnemyType.COYOTE]
	var offsets := [Vector3(2, 0, -1), Vector3(3, 0, 0.6), Vector3(1.5, 0, 1.8),
			Vector3(4, 0, -1.5), Vector3(4.5, 0, 1), Vector3(0.5, 0, -2),
			Vector3(1, 0, -1.2), Vector3(3.5, 0, 2.2)]
	for i in range(kinds.size()):
		spawner.spawn_enemy(kinds[i], p + offsets[i])

func _poke_enemies(action: String) -> void:
	var spawner := _main.get_node_or_null("EnemySpawner")
	if spawner == null:
		return
	for e in spawner.enemies:
		if is_instance_valid(e):
			e._play_enemy_animation(action)

func _hide_ui() -> void:
	if _keep_ui:
		return
	for child in _main.get_children():
		if child is CanvasLayer:
			child.visible = false

func _press_continue(node: Node) -> void:
	# Auto-dismiss tutorial/mentor dialogs wherever they appear in the tree.
	for child in node.get_children():
		if child is BaseButton and not child.disabled and child.is_visible_in_tree():
			var label: String = child.text.to_lower()
			if "continue" in label or "got it" in label or "close" in label:
				child.pressed.emit()
		_press_continue(child)

func _add_camera() -> void:
	_cam = Camera3D.new()
	_main.add_child(_cam)
	_cam.current = true

func _save(suffix: String) -> void:
	get_root().get_texture().get_image().save_png(_prefix + suffix)
	print("[capture] " + _prefix + suffix)
