extends SceneTree

## The tempo action queue's commitment rules:
##  - an owner is "busy" (movement-locked) while any of their actions tick
##  - a queued action can be cancelled only BEFORE its own ticks start
##  - the currently ticking action is locked in
## Run: godot --headless --path . --script tests/test_action_queue.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Action queue test ===")

	var stats = load("res://scripts/character/player_stats.gd").new()
	stats.initialize(CharacterData.create_ryan())
	var tm = load("res://scripts/battle/tempo_manager.gd").new()
	tm.initialize(stats)

	var a := Card.create_slash()
	var b := Card.create_slash()
	var c := Card.create_block()

	_check(not tm.owner_is_busy(0), "an idle owner is not busy (free to move)")

	tm.add_card_tempo(5, a, 5, 0)
	_check(tm.is_card_started(a), "the first action starts ticking immediately — locked in")
	_check(tm.owner_is_busy(0), "owner is busy (movement-locked) while their action ticks")
	_check(not tm.owner_is_busy(1), "a co-op partner's queue does not lock this owner")

	tm.add_card_tempo(4, b, 4, 0)
	tm.add_card_tempo(3, c, 3, 0)
	_check(not tm.is_card_started(b), "the second action waits its turn — still cancellable")
	_check(not tm.is_card_started(c), "the third action waits too")

	var refunded: int = tm.cancel_card_ticks(b)
	_check(refunded == 4, "cancelling an unstarted action refunds its full tempo (got %d)" % refunded)
	_check(tm.is_card_started(a), "the ticking action is unaffected by the cancel")
	_check(not tm.is_card_started(c), "later actions re-chain but still have not started")
	_check(tm.owner_is_busy(0), "owner stays busy until the remaining queue drains")

	tm.cancel_card_ticks(c)
	_check(tm.owner_is_busy(0), "the started action alone still pins the owner in place")

	tm.cancel_card_ticks(a)  # simulates the dead-target path clearing everything
	_check(not tm.owner_is_busy(0), "owner is free once nothing remains")

	stats.free()
	tm.free()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
