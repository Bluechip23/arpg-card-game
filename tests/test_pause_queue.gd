extends SceneTree

## Pausing freezes the battle, not the action queue: the ▾ beside the tick
## bar and the queue's ✕ buttons keep working while the tree is paused, so
## a player can stop the clock, open the queue and pull a queued card.
## Run: godot --headless --path . --script tests/test_pause_queue.gd

var _main: Node = null
var _frames := 0
var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	_main = packed.instantiate()
	_main.set("starting_character", CharacterData.create_stephen())
	_main.set("current_interior_id", "dojo")
	get_root().add_child(_main)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 12:
		return false
	_run()
	print("=== %d failure(s) ===" % failures)
	paused = false
	quit(1 if failures > 0 else 0)
	return true

func _run() -> void:
	print("=== Pause + action queue test ===")
	var dm = _main.deck_manager
	var dummy: Enemy = _main.enemy_spawner.get_living_enemies()[0]
	var gm = _main.grid_manager
	dummy.position = gm.grid_to_world(gm.world_to_grid(_main.player.position) + Vector2i(1, 0))
	dummy.target_position = dummy.position

	# Queue an attack (it winds up over tempo), then pause.
	# Two attacks: the first begins ticking at once (locked in), the second
	# waits behind it and can still be pulled.
	var first := Card.create_slash()
	var slash := Card.create_slash()
	dm.hand.clear()
	dm.hand.append(first)
	dm.hand.append(slash)
	_main.select_card(0)
	_main.play_selected_card(dummy)
	_main.select_card(0)
	_main.play_selected_card(dummy)
	_check(_main._pending_resolve_queue.size() == 2, "two attacks are waiting in the queue (%d)" % _main._pending_resolve_queue.size())
	_main._on_pause_pressed()
	_check(paused and _main._is_paused, "the stop sign pauses the tree")
	_check(_main._pause_button.can_process(), "the pause button keeps processing while paused")
	_check(_main._queue_toggle_btn.can_process(), "so does the queue's ▾")

	# Open the queue and cancel the card, all while paused.
	_main._toggle_action_queue()
	_check(_main._queue_open and _main._queue_panel.visible and _main._queue_panel.can_process(), "the queue opens while paused and its rows process")
	var cancel_btn: Button = null
	for row in _main._queue_list.get_children():
		for c in row.get_children():
			if c is Button:
				cancel_btn = c
	_check(cancel_btn != null and cancel_btn.can_process(), "the row carries a live ✕ button")
	if cancel_btn:
		cancel_btn.pressed.emit()
	_check(_main._pending_resolve_queue.size() == 1, "pressing ✕ while paused pulls the waiting action")
	_check(slash in dm.hand, "…and the card is back in hand")
	_main._on_pause_pressed()
	_check(not paused, "the play button resumes")
