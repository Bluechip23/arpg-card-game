extends SceneTree
var _out := "/tmp/nomana.png"
var _main = null
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: _out = a[0]
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate()
	_main.set("starting_character", CharacterData.create_jeremy())
	_main.set("current_interior_id", "dojo")
	get_root().add_child(_main)
	_run.call_deferred()
func _run() -> void:
	for _i in range(30): await process_frame
	var g := 0
	while _main.olorin and _main.olorin.is_busy() and g < 20:
		_main.olorin._close(); g += 1
		await process_frame
	_main._camera_distance = 3.0
	_main._update_camera()
	_main.player.get_stats().current_mana = 0
	var c := Card.create_by_id("fireball")
	_main.deck_manager.hand.append(c)
	_main.selected_card_index = _main.deck_manager.hand.size() - 1
	var cell: Vector2i = _main.grid_manager.world_to_grid(_main.player.position)
	var w = _main.enemy_spawner.spawn_enemy(Enemy.EnemyType.WOLF, _main._ground_pos(cell + Vector2i(2, 0)))
	for _i in range(3): await process_frame
	print("[probe] mana ", _main.player.get_stats().current_mana, " cost ", c.mana_cost)
	_main.play_selected_card(w)
	for _i in range(14): await process_frame
	var sv: SubViewport = _main._world_viewport
	var img: Image = sv.get_texture().get_image()
	var p: Vector2 = _main.get_world_camera().unproject_position(_main.player.position)
	var r := Rect2i(int(p.x) - 220, int(p.y) - 420, 440, 500).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(r).save_png(_out)
	var found := false
	for n in _main.player._figure.get_children():
		if n is Sprite3D and n.texture and n.texture.resource_path.ends_with("no_mana.png"):
			found = true
			print("[probe] sign y ", n.position.y, " global ", n.global_position, " fig ", _main.player._figure.global_position)
	print("[probe] no-mana sign shown: ", found)
	quit()
