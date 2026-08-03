extends SceneTree

## Phase 8 screenshot harness: renders each key scene and saves PNGs to
## docs/screens/ for the style verification passes.
##
## Run under a virtual framebuffer (headless GL cannot render):
##   xvfb-run -a godot --rendering-driver opengl3 \
##       --script tools/capture_screens.gd
##
## Captures: battle composite (low-res world + full-res UI), battle with
## enemy sampler, character select, sprite viewer demo, bestiary stages.

const OUT := "res://docs/screens"

var _jobs: Array = []
var _current: Dictionary = {}
var _scene: Node = null
var _frames := 0


func _initialize() -> void:
	Engine.time_scale = 0.15
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_jobs = [
		{"name": "battle_brad", "kind": "battle", "who": "Brad", "wait": 70},
		{"name": "battle_ryan", "kind": "battle", "who": "Ryan", "wait": 70},
		{"name": "character_select", "kind": "scene",
			"path": "res://scenes/character/character_select.tscn", "wait": 60},
		{"name": "sprite_viewer", "kind": "scene",
			"path": "res://scenes/demo/character_viewer.tscn", "wait": 30},
	]
	_next_job()


func _next_job() -> void:
	if _scene:
		_scene.queue_free()
		_scene = null
	if _jobs.is_empty():
		quit()
		return
	_current = _jobs.pop_front()
	_frames = 0
	match _current["kind"]:
		"battle":
			var packed: PackedScene = load("res://scenes/core/main.tscn")
			_scene = packed.instantiate()
			var who: String = _current["who"]
			var data: CharacterData
			match who:
				"Ryan": data = CharacterData.create_ryan()
				"Jeremy": data = CharacterData.create_jeremy()
				"Stephen": data = CharacterData.create_stephen()
				"Cory": data = CharacterData.create_cory()
				_: data = CharacterData.create_brad()
			_scene.set("starting_character", data)
			get_root().add_child(_scene)
		"scene":
			_scene = (load(_current["path"]) as PackedScene).instantiate()
			get_root().add_child(_scene)


func _process(_d: float) -> bool:
	_frames += 1
	if _scene == null:
		return false
	if _current["kind"] == "battle":
		_press_continue(get_root())
		if _frames == 24:
			_spawn_sampler()
	if _frames >= int(_current["wait"]):
		var img := get_root().get_texture().get_image()
		var path := "%s/%s.png" % [OUT, _current["name"]]
		img.save_png(ProjectSettings.globalize_path(path))
		print("[capture] " + path)
		_next_job()
	return false


func _spawn_sampler() -> void:
	var spawner = _scene.get_node_or_null("EnemySpawner")
	var player = _scene.get_node_or_null("Player")
	if spawner == null or player == null:
		return
	spawner.clear_enemies()
	var p: Vector3 = player.global_position
	var kinds := [Enemy.EnemyType.WERERAT, Enemy.EnemyType.RAT_KING,
			Enemy.EnemyType.FIRE_GOBLIN_SOLDIER, Enemy.EnemyType.FIRE_GOBLIN_MAGE,
			Enemy.EnemyType.ARMORED_TROLL, Enemy.EnemyType.WOLF,
			Enemy.EnemyType.SKELETON, Enemy.EnemyType.SLUDGE]
	var offsets := [Vector3(2, 0, -1), Vector3(3, 0, 0.6), Vector3(1.5, 0, 1.8),
			Vector3(4, 0, -1.5), Vector3(4.5, 0, 1), Vector3(0.5, 0, -2),
			Vector3(1, 0, -1.2), Vector3(3.5, 0, 2.2)]
	for i in range(kinds.size()):
		spawner.spawn_enemy(kinds[i], p + offsets[i])


func _press_continue(node: Node) -> void:
	for child in node.get_children():
		if child is BaseButton and not child.disabled and child.is_visible_in_tree():
			var label: String = child.text.to_lower()
			if "continue" in label or "got it" in label or "close" in label:
				child.pressed.emit()
		_press_continue(child)
