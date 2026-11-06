extends SceneTree

## The Crypt Crawler's Web (the designer's web board, 2026-11-06;
## tools/cut_pose_boards.py "crypt_crawler_web" / "_ball" / "_webart"):
## Throw.png (its fifth board, drawn to match its idle) is the corpse on its
## back rising, pulling strands of web from the spider, gathering them into a
## ball over its head, the throw, and sinking again, four facing rows. The ball flies
## to its prey (Ball.png) and where it lands the web (Web.png) is strung
## about their feet, held while they hold the Paralysis card.
## Run: godot --headless --path . --script tests/test_crypt_crawler_web.gd

var failures := 0
var main = null

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _settle(frames: int = 6) -> void:
	for _i in range(frames):
		await process_frame

func _thrown(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is ThrownSprite:
			out.append(c)
	return out

func _run() -> void:
	print("=== Crypt Crawler web test ===")
	var fig := SpriteEnemyFigure.new()
	root.add_child(fig)
	fig.setup("crypt_crawler")
	await process_frame
	var cell: int = fig._cp_cell
	_check(fig._cp_sheets.has("Throw") and fig._cp_frame_count("Throw") == 7, "a seven-frame Throw sheet (%s)" % ("smooth" if fig.smooth else "pixel"))
	if fig._cp_sheets.has("Throw"):
		_check(fig._cp_sheets["Throw"].get_height() == 4 * cell, "in the four facing rows, the Idle sheet's cells")
		var img: Image = fig._cp_sheets["Throw"].get_image()
		if img.is_compressed():
			img.decompress()
		var drawn := true
		for row in range(4):
			for col in range(7):
				if img.get_region(Rect2i(col * cell, row * cell, cell, cell)).get_used_rect().size.y < cell * 0.4:
					drawn = false
		_check(drawn, "every frame of the four rows holds it")
	for nm in ["Ball", "Web"]:
		_check(ResourceLoader.exists(fig._sheet_folder + "/%s.png" % nm), "%s.png beside its sheets" % nm)
	fig.free()

	main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	await _settle()
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	var pc: Vector2i = main.grid_manager.world_to_grid(main.player.position)
	var cc: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.CRYPT_CRAWLER, main._ground_pos(pc + Vector2i(2, 0)))
	cc.chosen_action = {}
	await _settle(2)
	var before := _thrown(main).size()
	cc._execute_action("web", main.player)
	var f: SpriteEnemyFigure = cc._enemy_figure
	_check(f._cp_anim == "Throw", "its Web plays the throw board (%s)" % f._cp_anim)
	var balls := _thrown(main)
	_check(balls.size() - before == 1, "a ball of web flies at its prey")
	var web = f.last_spot
	_check(web is SpotEffect and is_instance_valid(web), "the web is laid where it lands")
	if not (web is SpotEffect):
		print("=== %d failure(s) ===" % failures)
		quit(1)
		return
	var pl: Vector3 = main.player.global_position
	_check(Vector2(web.global_position.x - pl.x, web.global_position.z - pl.z).length() < 0.05, "about its prey's feet")
	_check(web._delay > 0.0 and balls.size() > 0 and absf(web._delay - balls[balls.size() - 1].total_time()) < 0.05, "it shows as the ball lands")
	await create_timer(web.total_time() + 0.6).timeout
	_check(is_instance_valid(web) and web._sprite.visible and web._sprite.modulate.a > 0.9, "the web stays while the Paralysis card is in hand")
	var deck = main.player.get_deck_manager()
	for c in deck.hand.duplicate():
		if c.card_id == "paralysis":
			deck.hand.erase(c)
	await create_timer(0.5).timeout
	_check(not is_instance_valid(web), "once the card is gone, the web is gone")
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
