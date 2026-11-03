extends SceneTree

## Verifies the 2026-11-03 batch: hold-to-walk key bookkeeping
## (HeldMoveKeys), the gauntlet skill's green "armed" outline, the Draw-pile
## clock icon's size and fade, the heal / armour icons existing, and the
## hero's full drawn-swing time covering its hit frame.
## Run: godot --headless --path . --script tests/test_hold_move_and_hud_marks.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _key(code: int, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _initialize() -> void:
	print("=== Hold-to-walk & HUD marks test ===")

	# --- HeldMoveKeys ---
	_check(HeldMoveKeys.is_move_key(KEY_W) and HeldMoveKeys.is_move_key(KEY_D), "WASD are move keys")
	_check(not HeldMoveKeys.is_move_key(KEY_Q), "Q is not a move key")
	_check(HeldMoveKeys.dir_for(KEY_W) == Vector2(0, 1), "W walks up the view")
	_check(HeldMoveKeys.dir_for(KEY_A) == Vector2(-1, 0), "A walks left")
	var held := HeldMoveKeys.new()
	_check(held.current_dir() == Vector2.ZERO, "nothing held: no walking")
	_key(KEY_W, true)
	held.press(KEY_W)
	_check(held.current_dir() == Vector2(0, 1), "W held: keeps walking up")
	_key(KEY_D, true)
	held.press(KEY_D)
	_check(held.current_dir() == Vector2(1, 0), "D pressed over W: the newest key wins")
	_key(KEY_D, false)
	_check(held.current_dir() == Vector2(0, 1), "D let go: back to W, still held")
	_key(KEY_W, false)
	_check(held.current_dir() == Vector2.ZERO, "W let go: walking stops")
	_key(KEY_S, true)
	held.press(KEY_S)
	held.clear()
	_check(held.current_dir() == Vector2.ZERO, "clear() ends a hold")
	_key(KEY_S, false)

	# --- Gauntlet skill armed outline ---
	var g := ItemData.new()
	g.gauntlet_skill_type = ItemData.GauntletSkillType.ACTIVE
	g.gauntlet_skill_name = "Test"
	g.gauntlet_skill_effect_id = "none"
	var ui := GauntletSkillUI.new()
	get_root().add_child(ui)
	ui.setup(g)
	_check(not ui.is_armed(), "a fresh skill circle is not armed")
	ui.set_armed(true)
	_check(ui.is_armed(), "set_armed(true) shows the green outline")
	ui.set_armed(false)
	_check(not ui.is_armed(), "set_armed(false) clears it")
	ui.queue_free()

	# --- Draw-pile clock icon: as tall as the Draw pile, never near-invisible ---
	_check(is_equal_approx(PilePassiveIcon.SIZE, 55.0), "clock icon is the Draw pile's height (55)")
	_check(PilePassiveIcon.COL_UNLIT.a >= 0.75, "unlit bands stay clearly visible")
	_check(PilePassiveIcon.ALPHA_UNEQUIPPED >= 0.5, "unequipped icon stays visible")

	# --- Overhead heal / armour icons ---
	_check(ResourceLoader.exists(SpriteFigure.HEAL_ICON), "heal heart icon exists")
	_check(ResourceLoader.exists(SpriteFigure.ARMOR_ICON), "armour shield icon exists")

	# --- A drawn swing's full time covers its hit frame ---
	var fig := SpriteFigure.new()
	get_root().add_child(fig)
	var data := CharacterData.new()
	data.character_name = "Stephen"
	data.base_character = "Stephen"
	fig.setup(SpriteFigure.preset_for(data))
	for dir in [0, 1, 2, 3]:
		if fig.has_drawn_action("basic_attack", dir):
			var hit: float = fig.hit_delay("basic_attack", dir)
			var total: float = fig.action_time("basic_attack", dir)
			_check(total > hit and hit > 0.0, "Stephen's swing (dir %d) runs past its blow: %.2fs > %.2fs" % [dir, total, hit])
			break
	fig.queue_free()

	print("=== %s ===" % ("ALL PASSED" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)
