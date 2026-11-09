extends SceneTree

## The in-game level-up stat allocation (designer, 2026-11-09): opened from
## "Stat Points" in the Passives / Sphere Grid panel, it shows the
## training-ground painting across the screen with the allocation box in the
## painting's empty middle; spending and confirming still work.
## Run: godot --headless --path . --script tests/test_levelup_stat_screen.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	print("=== Level-up stat screen ===")
	await process_frame
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(8):
		await process_frame
	var g := 0
	while main.olorin and main.olorin.is_busy() and g < 10:
		main.olorin._close()
		g += 1
		await process_frame
	var st = main.player.get_stats()
	var ui = main.skill_tree_ui
	st.unspent_stat_points = 3
	ui.player_stats = st
	ui.show_panel()
	await process_frame
	ui._open_stat_allocation()
	await process_frame
	await process_frame
	var back: Control = ui._stat_alloc_backdrop
	_check(back != null and is_instance_valid(back), "the allocation opens over a backdrop")
	_check(back.get_node_or_null("AllocBoard") is TextureRect and back.get_node("AllocBoard").texture != null,
		"the backdrop is the training-ground painting")
	var screen: Vector2 = get_root().get_visible_rect().size
	_check(back.size.is_equal_approx(screen), "it covers the screen")
	# The box inside the painting's empty middle, as drawn now.
	var k: float = maxf(screen.x / ui.STAT_ALLOC_BOARD_SIZE.x, screen.y / ui.STAT_ALLOC_BOARD_SIZE.y)
	var off: Vector2 = (screen - ui.STAT_ALLOC_BOARD_SIZE * k) * 0.5
	var space := Rect2(off + ui.STAT_ALLOC_BOARD_SPACE.position * k, ui.STAT_ALLOC_BOARD_SPACE.size * k)
	var p: Control = ui._stat_alloc_panel
	var box := Rect2(p.position, p.size * p.scale)
	_check(space.grow(1.0).encloses(box), "the box sits in the painting's empty middle")

	var str0: int = st.base_strength
	var plus: Button = null
	for b in p.find_children("*", "Button", true, false):
		if str(b.text) == "+":
			plus = b
			break
	_check(plus != null, "the stat rows have + buttons")
	if plus:
		plus.pressed.emit()
	var confirm: Button = null
	for b in p.find_children("*", "Button", true, false):
		if str(b.text) == "Confirm":
			confirm = b
	if confirm:
		confirm.pressed.emit()
	await process_frame
	await process_frame
	_check(st.base_strength == str0 + 1 and st.unspent_stat_points == 2, "spending a point and confirming still works")
	_check(ui._stat_alloc_backdrop == null or not is_instance_valid(ui._stat_alloc_backdrop), "the painting closes with the box")
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
