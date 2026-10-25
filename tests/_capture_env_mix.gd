extends SceneTree
## Dev helper: a real level with the hero and a mix of enemies standing
## around them, to judge the figures against the game's own environment.
##   -- <out.png> <interior_id or ""> <world_level> <ENEMY,ENEMY,...> [hero] [zoom]
var _main: Node = null
var _frames := 0
var _args: PackedStringArray

func _initialize() -> void:
	_args = OS.get_cmdline_user_args()
	_main = load("res://scenes/core/main.tscn").instantiate()
	var hero: String = _args[4] if _args.size() > 4 else "Brad"
	var cd: CharacterData = CharacterData.create_brad()
	for c in CharacterData.get_all_characters():
		if c.character_name == hero:
			cd = c
	_main.set("starting_character", cd)
	_main.set("current_interior_id", _args[1])
	_main.set("current_world_level", int(_args[2]))
	get_root().add_child(_main)

func _process(_d: float) -> bool:
	_frames += 1
	if _main.olorin and _main.olorin.has_method("is_busy") and _main.olorin.is_busy():
		_main.olorin._close()
	if _frames == 40:
		var dm = _main.dungeon_manager
		var pc: Vector2i = _main.grid_manager.world_to_grid(_main.player.position)
		var kinds: PackedStringArray = _args[3].split(",")
		# Free floor cells in rings round the hero, two apart so figures don't overlap.
		var cells: Array = []
		for r in [2, 3, 4, 5]:
			for dz in range(-r, r + 1):
				for dx in range(-r - 2, r + 3):
					var c: Vector2i = pc + Vector2i(dx, dz)
					if maxi(absi(dx) - 2, absi(dz)) != r or not dm.is_floor(c):
						continue
					var ok := true
					for o in cells:
						if absi(o.x - c.x) < 2 and absi(o.y - c.y) < 2:
							ok = false
					if ok:
						cells.append(c)
		var i := 0
		for k in kinds:
			if not Enemy.EnemyType.has(k) or i >= cells.size():
				print("skip ", k)
				continue
			var e = _main.enemy_spawner.spawn_enemy(Enemy.EnemyType[k], _main._ground_pos(cells[i]))
			if e and e.has_method("set_hidden"):
				e.set_hidden(false)
			i += 1
		dm.reveal_around(pc)
		_main._update_fog_of_war()
		_main._camera_focus = _main.player.position
		if _args.size() > 5:
			_main._camera_distance = float(_args[5])
		_main._update_camera()
		for n in _main.get_children():
			if n is CanvasLayer and n.name != "WorldRenderLayer":
				n.visible = false
	if _frames == 70:
		get_root().get_texture().get_image().save_png(_args[0])
		print("[capture] ", _args[0])
		quit()
	return false
