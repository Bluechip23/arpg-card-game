extends SceneTree

## Enemy action keywords: Sync (default), Async, Channel, Disruptable, Trigger.
## Drives a bare enemy one tempo at a time and checks the exact firing order
## against the worked examples in docs/ENEMY_ACTION_KEYWORDS.md.
## Run: godot --headless --path . --script tests/test_enemy_action_keywords.gd

var failures := 0
var _fired: Array = []   # names fired during the current tempo

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Enemy action keywords ===")
	_run()

func _run() -> void:
	var holder := Node3D.new()
	get_root().add_child(holder)
	var gm := GridManager.new()
	holder.add_child(gm)
	await process_frame

	_test_defaults_unchanged(holder, gm)
	_test_async_vs_sync(holder, gm)
	_test_three_clocks(holder, gm)
	_test_channel(holder, gm)
	_test_disruptable(holder, gm)
	_test_trigger(holder, gm)
	_test_stun_resets_every_clock(holder, gm)
	_test_display_and_descriptions(holder, gm)
	_test_compendium_keywords()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

# ---------------------------------------------------------------------------

func _make_enemy(holder: Node3D, gm: GridManager, action_table: Array) -> Array:
	## A MINION with a custom action table, its target one tile away.
	var e: Enemy = load("res://scenes/battle/enemy.tscn").instantiate()
	holder.add_child(e)
	e.initialize(Enemy.EnemyType.MINION, gm)
	e.position = gm.grid_to_world(Vector2i(5, 5))
	e.max_health = 9999
	e.current_health = 9999
	e.current_armor = 0
	e.max_armor = 0
	e.attack_range = 1.5
	var typed: Array[Dictionary] = []
	for a in action_table:
		typed.append(a)
	e.actions = typed
	e._reset_action_clocks()
	e.action_fired.connect(func(_enemy, nm): _fired.append(nm))
	var target := Node3D.new()
	target.position = gm.grid_to_world(Vector2i(6, 5))
	holder.add_child(target)
	return [e, target]

func _run_ticks(e: Enemy, target: Node3D, count: int) -> Array:
	## Advance one tempo at a time; returns one Array of fired names per tempo.
	var log: Array = []
	for _i in range(count):
		_fired = []
		e.on_tempo_advanced(1, target)
		log.append(_fired.duplicate())
	return log

func _fire_ticks(log: Array, nm: String) -> Array:
	## 1-based tempo numbers at which `nm` fired.
	var out: Array = []
	for i in range(log.size()):
		if nm in log[i]:
			out.append(i + 1)
	return out

func _test_defaults_unchanged(holder: Node3D, gm: GridManager) -> void:
	print("-- Sync default (today's enemies) --")
	var pair = _make_enemy(holder, gm, [
		{"name": "attack", "tempo_cost": 3},
		{"name": "move", "tempo_cost": 5},
	])
	var e: Enemy = pair[0]
	var log = _run_ticks(e, pair[1], 9)
	_check(_fire_ticks(log, "attack") == [3, 6, 9], "one shared clock: attack at 3, 6, 9 (got %s)" % [_fire_ticks(log, "attack")])
	_check(Enemy.action_keywords(e.actions[0]).is_empty(), "an untagged action shows no keywords (Sync/Immediate/Non-interruptible are implicit)")
	_check(Enemy.describe_action(e.actions[0]) == "Attack · 3 tempo", "describe_action for a plain action")
	_check(e.get_display_action()["kind"] == "sync", "display action reports the sync clock")
	# Lumped tempo is processed per unit: 3 tempo at once fires the same way.
	_fired = []
	e.on_tempo_advanced(3, pair[1])
	_check(_fired == ["attack"], "a 3-tempo lump still fires the 3-tempo attack exactly once")
	e.queue_free()

func _test_async_vs_sync(holder: Node3D, gm: GridManager) -> void:
	print("-- Example 1: Punch 3 Async, Kick 5 Sync --")
	var pair = _make_enemy(holder, gm, [
		{"name": "punch", "tempo_cost": 3, "async": true},
		{"name": "kick", "tempo_cost": 5},
	])
	var e: Enemy = pair[0]
	var log = _run_ticks(e, pair[1], 15)
	_check(_fire_ticks(log, "punch") == [3, 6, 9, 12, 15], "punch every 3 tempo on its own clock (got %s)" % [_fire_ticks(log, "punch")])
	_check(_fire_ticks(log, "kick") == [8, 14], "kick waits for the first punch, fires at 8, then restarts only after punch fires (14) (got %s)" % [_fire_ticks(log, "kick")])
	_check(Enemy.action_keywords(e.actions[0]) == ["Async"], "punch carries the Async keyword")
	e.queue_free()

func _test_three_clocks(holder: Node3D, gm: GridManager) -> void:
	print("-- Example 2: Punch 3 Async, Kick 5 Sync, Power Bomb 9 Async --")
	var pair = _make_enemy(holder, gm, [
		{"name": "punch", "tempo_cost": 3, "async": true},
		{"name": "kick", "tempo_cost": 5},
		{"name": "power_bomb", "tempo_cost": 9, "async": true},
	])
	var e: Enemy = pair[0]
	var log = _run_ticks(e, pair[1], 24)
	_check(_fire_ticks(log, "punch") == [3, 6, 9, 12, 15, 18, 21, 24], "punch every 3 (got %s)" % [_fire_ticks(log, "punch")])
	_check(_fire_ticks(log, "power_bomb") == [9, 18], "power bomb every 9 (got %s)" % [_fire_ticks(log, "power_bomb")])
	_check(_fire_ticks(log, "kick") == [14, 23], "kick starts only once every Async clock sits at 0: tempo 10 -> 14, 19 -> 23 (got %s)" % [_fire_ticks(log, "kick")])
	_check(log[8] == ["punch", "power_bomb"], "punch and power bomb both fire on tempo 9")
	e.queue_free()

func _test_channel(holder: Node3D, gm: GridManager) -> void:
	print("-- Channel --")
	var pair = _make_enemy(holder, gm, [
		{"name": "blast", "tempo_cost": 8, "channel": 5},
		{"name": "jab", "tempo_cost": 2, "async": true},
	])
	var e: Enemy = pair[0]
	var target: Node3D = pair[1]
	_check(Enemy.windup_of(e.actions[0]) == 3, "8 tempo / Channel 5 winds up for 3")
	# Blast is Sync, so it may only start once the Async jab has fired (tempo
	# 2): wind-up 3-5, channel 6-10, resolve at 10. The jab fires at 2 and 4,
	# sits at 1 when the channel freezes it, and lands again at 11.
	var channeling_at: Array = []
	var log: Array = []
	for i in range(11):
		_fired = []
		e.on_tempo_advanced(1, target)
		log.append(_fired.duplicate())
		if e.is_channeling():
			channeling_at.append(i + 1)
	_check(_fire_ticks(log, "blast") == [10], "blast: starts at 3 (after jab's gap), winds up 3 tempo, channels 5, resolves at 10 (got %s)" % [_fire_ticks(log, "blast")])
	_check(channeling_at == [5, 6, 7, 8, 9], "channel runs through tempo 6-10 (seen channeling after tempo %s)" % [channeling_at])
	_check(_fire_ticks(log, "jab") == [2, 4, 11], "the Async jab is paused by the channel: 2, 4, then not again until 11 (got %s)" % [_fire_ticks(log, "jab")])
	_check(Enemy.action_keywords(e.actions[0]) == ["Channel 5"], "blast carries Channel 5")

	# Planted while channeling: no movement.
	var pair2 = _make_enemy(holder, gm, [{"name": "beam", "tempo_cost": 5, "channel": 5}])
	var e2: Enemy = pair2[0]
	_run_ticks(e2, pair2[1], 2)
	_check(e2.is_channeling(), "a stand-alone channel starts counting the tempo it is chosen")
	var shown = e2.get_display_action()
	_check(shown["kind"] == "channel" and shown["counter"] == 2 and shown["cost"] == 5, "display shows the channel 2/5")
	e2.move_towards_target(gm.grid_to_world(Vector2i(9, 5)))
	_check(not e2.is_moving, "a channeling enemy cannot move")
	var log2 = _run_ticks(e2, pair2[1], 3)
	_check(_fire_ticks(log2, "beam") == [3], "stand-alone Channel 5 resolves on the 5th tempo")
	e.queue_free()
	e2.queue_free()

func _test_disruptable(holder: Node3D, gm: GridManager) -> void:
	print("-- Disruptable --")
	var pair = _make_enemy(holder, gm, [{"name": "slam", "tempo_cost": 5, "disrupt": 10}])
	var e: Enemy = pair[0]
	var target: Node3D = pair[1]
	_run_ticks(e, target, 3)
	_check(e.action_tempo_counter == 3, "slam has counted 3")
	e.take_damage(6, true)
	_check(e.action_tempo_counter == 3, "6 damage is under the threshold: clock keeps its count")
	e.take_damage(4, true)
	_check(e.action_tempo_counter == 0, "10 damage total restarts the clock from 0")
	var log = _run_ticks(e, target, 5)
	_check(_fire_ticks(log, "slam") == [5], "slam fires 5 tempo after the disruption")

	# A Disruptable channel collapses.
	var pair2 = _make_enemy(holder, gm, [{"name": "beam", "tempo_cost": 6, "channel": 4, "disrupt": 5}])
	var e2: Enemy = pair2[0]
	_run_ticks(e2, pair2[1], 3)
	_check(e2.is_channeling(), "beam is channeling after its 2-tempo wind-up")
	e2.take_damage(5, true)
	_check(not e2.is_channeling() and e2.action_tempo_counter == 0, "5 damage breaks the channel and restarts the clock")
	var log2 = _run_ticks(e2, pair2[1], 6)
	_check(_fire_ticks(log2, "beam") == [6], "beam resolves 6 tempo after the break")
	_check(Enemy.action_keywords(e2.actions[0]) == ["Channel 4", "Disruptable 5"], "keywords list Channel then Disruptable")

	# Non-interruptible default: damage never touches an untagged clock.
	var pair3 = _make_enemy(holder, gm, [{"name": "attack", "tempo_cost": 5}])
	var e3: Enemy = pair3[0]
	_run_ticks(e3, pair3[1], 3)
	e3.take_damage(50, true)
	_check(e3.action_tempo_counter == 3, "untagged action is Non-interruptible")
	e.queue_free()
	e2.queue_free()
	e3.queue_free()

func _test_trigger(holder: Node3D, gm: GridManager) -> void:
	print("-- Trigger --")
	var pair = _make_enemy(holder, gm, [
		{"name": "attack", "tempo_cost": 5},
		{"name": "retaliate", "trigger": "damaged"},
		{"name": "last_stand", "trigger": "half_health"},
	])
	var e: Enemy = pair[0]
	var target: Node3D = pair[1]
	e.max_health = 100
	e.current_health = 100
	_run_ticks(e, target, 1)  # the enemy has seen its target
	_fired = []
	e.take_damage(10, true)
	_check(_fired == ["retaliate"], "Trigger: damaged fires retaliate with no clock (got %s)" % [_fired])
	_check(e.action_tempo_counter == 1, "a triggered action leaves the sync clock alone")
	_fired = []
	e.take_damage(45, true)  # 90 -> 45: crosses half health
	_check("last_stand" in _fired and "retaliate" in _fired, "half_health fires alongside damaged when the hit crosses 50%% (got %s)" % [_fired])
	_fired = []
	e.take_damage(5, true)
	_check(_fired == ["retaliate"], "half_health only fires on the crossing")
	_check(Enemy.action_keywords(e.actions[1]) == ["Trigger: Damaged"], "trigger keyword reads Trigger: Damaged")
	_check(Enemy.describe_action(e.actions[1]) == "Retaliate · Trigger: Damaged", "triggered actions describe without a tempo")
	_check(e.get_display_action()["name"] == "attack", "triggered actions never sit on the display clock")
	e.queue_free()

func _test_stun_resets_every_clock(holder: Node3D, gm: GridManager) -> void:
	print("-- Stun --")
	var pair = _make_enemy(holder, gm, [
		{"name": "punch", "tempo_cost": 3, "async": true},
		{"name": "kick", "tempo_cost": 5},
	])
	var e: Enemy = pair[0]
	_run_ticks(e, pair[1], 5)
	_check(e._async_counters.get("punch", 0) == 2 and e.action_tempo_counter == 2, "clocks mid-count before the stun")
	e.apply_stun(2)
	_check(e._async_counters.get("punch", 0) == 0 and e.action_tempo_counter == 0 and e.chosen_action.is_empty(), "stun resets the Async clock and the Sync clock")
	e.queue_free()

func _test_display_and_descriptions(holder: Node3D, gm: GridManager) -> void:
	print("-- Display --")
	var pair = _make_enemy(holder, gm, [
		{"name": "punch", "tempo_cost": 3, "async": true},
		{"name": "kick", "tempo_cost": 5, "label": "Roundhouse"},
	])
	var e: Enemy = pair[0]
	_run_ticks(e, pair[1], 4)  # punch 1/3, kick 1/5
	var shown = e.get_display_action()
	_check(shown["kind"] == "async" and shown["name"] == "punch", "the bar shows whichever clock fires soonest (punch)")
	_check(Enemy.action_kind_color("async") == Enemy.ACTION_COLOR_ASYNC and Enemy.action_kind_color("sync") == Enemy.ACTION_COLOR_SYNC, "clock kinds map to their colours")
	_check(e.get_action_lines() == ["Punch · 3 tempo · Async", "Roundhouse · 5 tempo"], "inspect lines use labels and keywords (got %s)" % [e.get_action_lines()])
	e.queue_free()

func _test_compendium_keywords() -> void:
	print("-- Compendium --")
	var data = Enemy.get_all_enemy_data()
	var i := 0
	var drift := 0
	for t in Enemy.EnemyType.values():
		var shown: Array = data[i]["actions"]
		var real: Array = Enemy.actions_for_type(t)
		if not shown.is_empty():
			if shown.size() != real.size():
				drift += 1
			else:
				for k in range(shown.size()):
					if int(shown[k]["tempo"]) != int(real[k]["tempo_cost"]):
						drift += 1
		for a in shown:
			if not a.has("keywords"):
				drift += 1
		i += 1
	_check(drift == 0, "compendium action lists line up with the live action tables (drift %d)" % drift)
