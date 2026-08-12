extends SceneTree

## Dev helper: boot the battle scene, spawn enemies near the player, and
## capture the default game camera at two zoom levels — for eyeballing the
## world-text (names, health, waypoint labels) legibility and size.
## Run under xvfb + software GL:
##   ... --script tests/_capture_labels.gd -- <prefix>

var _main: Node = null
var _frames := 0
var _prefix := "/tmp/labels"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	_main = packed.instantiate()
	var who := CharacterData.create_brad()
	who.seen_tutorial_ids.append("combat_intro")  # keep Olorin's dialog out of the shot
	_main.set("starting_character", who)
	get_root().add_child(_main)

func _process(_delta: float) -> bool:
	_frames += 1
	match _frames:
		20:
			_spawn_enemies()
		60:
			_save("_default.png")
			_zoom(0.55)
		75:
			_save("_zoomed_out.png")
		90:
			quit()
	return false

func _spawn_enemies() -> void:
	var spawner = _main.get("enemy_spawner")
	var player = _main.get_node_or_null("Player")
	if spawner == null or player == null:
		return
	var p: Vector3 = player.position
	spawner.spawn_enemy(Enemy.EnemyType.SKELETON, p + Vector3(3, 0, 1))
	spawner.spawn_enemy(Enemy.EnemyType.WERERAT, p + Vector3(4, 0, -2))
	spawner.spawn_enemy(Enemy.EnemyType.ARMORED_TROLL, p + Vector3(2, 0, -3))

func _zoom(factor: float) -> void:
	## Pull the game camera out to a tactical zoom (smaller factor = further).
	if "_camera_distance" in _main:
		_main.set("_camera_distance", _main.get("_camera_distance") / factor)
		if _main.has_method("_update_camera"):
			_main.call("_update_camera")

func _save(suffix: String) -> void:
	var img := get_root().get_texture().get_image()
	img.save_png(_prefix + suffix)
	print("[capture] " + _prefix + suffix)
