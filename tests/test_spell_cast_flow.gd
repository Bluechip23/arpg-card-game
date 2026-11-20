extends SceneTree

## The heroes' spell casts flow and land (designer, 2026-11-20: "still feels
## a bit choppy ... get it to land correctly"): each cast frame cross-fades
## from the one before (SpriteFigure SPELL_CAST_BLEND), and a thrown spell
## (Fireball) resolves when its missile lands, not as it leaves the hand.
## Run: godot --headless --path . --script tests/test_spell_cast_flow.gd

var failures := 0
var main = null

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for hero in ["Brad", "Cory", "Stephen", "Jeremy", "Ryan"]:
		var a: Dictionary = SpriteFigure.ROSTER[hero]["actions"]["spell_cast"]
		_check(float(a.get("blend", 0.0)) > 0.0, "%s's spell cast cross-fades its frames" % hero)

	main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_jeremy())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for i in 10: await process_frame
	var fig = main.player._figure
	fig.play_action("spark", CharacterAnimator.Direction.SOUTH, true)
	_check(fig._action_ghost != null and not fig._action_ghost.visible, "the cast's first frame shows alone")
	var frame_t: float = fig._frames[0]["t"]
	fig._process(frame_t + 0.001)   # on to the second frame
	_check(fig._action_ghost.visible and fig._action_ghost.modulate.a > 0.5, "the next frame starts with the last one over it")
	fig._process(frame_t * SpriteFigure.SPELL_CAST_BLEND * 0.5)
	var mid: float = fig._action_ghost.modulate.a
	_check(fig._action_ghost.visible and mid < 0.5, "...fading (%.2f)" % mid)
	fig._process(frame_t * SpriteFigure.SPELL_CAST_BLEND)
	_check(not fig._action_ghost.visible, "...and gone well before the next frame")

	# Fireball: the hit waits for the flight.
	var cell: Vector2i = main.grid_manager.world_to_grid(main.player.position)
	var fb := Card.create_by_id("fireball")
	var data := {"aim_world": main._ground_pos(cell + Vector2i(5, 0))}
	var flight: float = main._launch_spell_missile(fb, main.player, data, 0.0)
	_check(flight > 0.2, "Fireball's resolution waits for its flight (%.2f s)" % flight)
	_check(fb.has_meta("missile_thrown"), "...and the world effect will not throw a second one")
	_check(main._launch_spell_missile(Card.create_by_id("spark"), main.player, data, 0.0) == 0.0, "a spell with no missile does not wait")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
