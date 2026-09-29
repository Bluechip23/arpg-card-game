extends SceneTree

## Enemy reach is measured in grid steps when the swing lands: a wererat
## beside the player bites, one on the diagonal does not (it closes in
## instead), and a bite lined up on a player who then stepped away misses.
## Run: godot --headless --path . --script tests/test_enemy_reach.gd

const EnemyScene = preload("res://scenes/battle/enemy.tscn")

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

class FakePlayer extends Node3D:
	var stats: PlayerStats = null
	var hits := 0
	func get_stats() -> PlayerStats:
		return stats
	func take_damage(amount: int, _ignore = null) -> void:
		hits += 1
		stats.take_damage(amount)

var _ran := false

func _process(_d: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
	return true

func _run() -> void:
	print("=== Enemy reach test ===")
	var holder := Node3D.new()
	get_root().add_child(holder)
	var gm := GridManager.new()
	holder.add_child(gm)
	var target := FakePlayer.new()
	target.stats = PlayerStats.new()
	holder.add_child(target)
	target.position = gm.grid_to_world(Vector2i(5, 5))
	var rat: Enemy = EnemyScene.instantiate()
	holder.add_child(rat)
	rat.initialize(Enemy.EnemyType.WERERAT, gm)

	# Beside the player: in reach.
	rat.position = gm.grid_to_world(Vector2i(6, 5))
	var hp0: int = target.stats.current_health
	_check(rat._in_attack_range(target), "a wererat on the next tile is in reach")
	rat._try_bite(target)
	_check(target.stats.current_health < hp0, "…and its bite lands")

	# On the diagonal: not adjacent on this grid, so no bite.
	rat.position = gm.grid_to_world(Vector2i(6, 6))
	rat.is_moving = false
	hp0 = target.stats.current_health
	_check(not rat._in_attack_range(target), "a wererat on the diagonal is out of reach")
	rat._try_bite(target)
	_check(target.stats.current_health == hp0, "…so its bite does not land")

	# Lined up beside the player, then the player walks two tiles away
	# before the bite fires: it misses.
	rat.position = gm.grid_to_world(Vector2i(6, 5))
	rat.is_moving = false
	rat._choose_action(target)
	_check(str(rat.chosen_action.get("name", "")) == "bite", "beside the player the rat lines up a bite")
	target.position = gm.grid_to_world(Vector2i(3, 5))
	hp0 = target.stats.current_health
	var fired := rat._execute_action("bite", target)
	_check(target.stats.current_health == hp0, "a bite that fires after the player stepped away does not hit")
	_check(fired, "…the rat closes in instead")
