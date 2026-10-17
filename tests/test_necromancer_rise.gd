extends SceneTree

## Necromancer — Raise the Fallen (designer's rule, 2026-10-11; replaces the
## old "five summon deaths raise a Bone Dragon"):
##  - a summon of his that dies rises again as a Skeleton, wherever it fell,
##    and costs him 10 health;
##  - any other ally that dies within 8 squares of him rises as a Skeleton
##    (and costs him nothing);
##  - a risen Skeleton rises no further and its death costs him nothing;
##  - nothing rises once he is dead, and no Bone Dragon ever appears.
## Checked in a booted main.tscn (the dojo).
## Run: godot --headless --path . --script tests/test_necromancer_rise.gd

var failures: int = 0
var main = null

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	await _boot()
	if main == null:
		print("=== %d failure(s) ===" % failures)
		quit(1)
		return
	_test_summon_death()
	_test_risen_do_not_chain()
	_test_ally_in_range()
	_test_ally_out_of_range()
	_test_no_dragon()
	_test_dead_necromancer()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _settle(frames: int = 6) -> void:
	for _i in range(frames):
		await process_frame

func _boot() -> void:
	print("-- Booting main.tscn as the dojo --")
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
	_check(main.player != null and main.enemy_spawner != null, "the dojo is up")
	if main.player == null:
		main = null

func _player_cell() -> Vector2i:
	return main.grid_manager.world_to_grid(main.player.position)

func _spawn(type: int, offset: Vector2i) -> Enemy:
	var e: Enemy = main.enemy_spawner.spawn_enemy(type, main._ground_pos(_player_cell() + offset))
	e.target_position = e.position
	return e

func _despawn(e: Enemy) -> void:
	if e and is_instance_valid(e):
		main.enemy_spawner.despawn_enemy(e)

func _living(type: int) -> Array:
	var out: Array = []
	for e in main.enemy_spawner.get_living_enemies():
		if e.enemy_type == type:
			out.append(e)
	return out

func _risen() -> Array:
	var out: Array = []
	for e in _living(Enemy.EnemyType.SKELETON):
		if e.necro_risen:
			out.append(e)
	return out

func _clear_field() -> void:
	for e in main.enemy_spawner.get_living_enemies().duplicate():
		if not e.is_training_dummy:
			_despawn(e)

func _kill(e: Enemy) -> void:
	e.take_damage(9999, false, DamageTypes.Type.PHYSICAL, true)

# ---------------------------------------------------------------- tests

func _test_summon_death() -> void:
	print("-- A summon dies: it rises as a Skeleton and the Necromancer takes 10 --")
	_clear_field()
	var necro := _spawn(Enemy.EnemyType.NECROMANCER, Vector2i(6, 0))
	var hp_before := necro.current_health
	necro._try_necro_summon(main.player)
	var summons: Array = []
	for e in main.enemy_spawner.get_living_enemies():
		if e.raised_by == necro:
			summons.append(e)
	_check(summons.size() == 1, "Summon raised one servant tagged raised_by")
	if summons.is_empty():
		return
	var servant: Enemy = summons[0]
	var risen_before := _risen().size()
	_kill(servant)
	_check(necro.current_health == hp_before - Enemy.NECRO_SUMMON_DEATH_DAMAGE,
		"the Necromancer took %d (%d -> %d)" % [Enemy.NECRO_SUMMON_DEATH_DAMAGE, hp_before, necro.current_health])
	_check(_risen().size() == risen_before + 1, "the servant rose again as a Skeleton")
	if _risen().size() > 0:
		var sk: Enemy = _risen()[0]
		_check(sk.raised_by == null, "the risen Skeleton is not one of his summons")
		_check(main.grid_manager.get_distance_in_cells(sk.position, servant.position) <= 1,
			"it rose where the servant fell")

func _test_risen_do_not_chain() -> void:
	print("-- A risen Skeleton dies: nothing rises, nothing is owed --")
	var necro: Enemy = _living(Enemy.EnemyType.NECROMANCER)[0] if _living(Enemy.EnemyType.NECROMANCER).size() > 0 else null
	if necro == null or _risen().is_empty():
		_check(false, "setup: a Necromancer and a risen Skeleton exist")
		return
	var hp_before := necro.current_health
	var sk: Enemy = _risen()[0]
	var count_before := _risen().size()
	_kill(sk)
	_check(_risen().size() == count_before - 1, "no second Skeleton rose from the risen one")
	_check(necro.current_health == hp_before, "the Necromancer took nothing for it")

func _test_ally_in_range() -> void:
	print("-- An ally dies within 8 squares: it rises, free of charge --")
	var necro: Enemy = _living(Enemy.EnemyType.NECROMANCER)[0]
	var hp_before := necro.current_health
	var zombie := _spawn(Enemy.EnemyType.ZOMBIE, Vector2i(2, 0))  # 4 squares from the Necromancer
	var count_before := _risen().size()
	_kill(zombie)
	_check(_risen().size() == count_before + 1, "the Zombie rose as a Skeleton")
	_check(necro.current_health == hp_before, "an ally's death costs the Necromancer nothing")
	for sk in _risen():
		_despawn(sk)

func _test_ally_out_of_range() -> void:
	print("-- An ally dies 12 squares away: it stays dead --")
	var necro: Enemy = _living(Enemy.EnemyType.NECROMANCER)[0]
	var zombie := _spawn(Enemy.EnemyType.ZOMBIE, Vector2i(-6, 0))  # 12 squares from the Necromancer at +6
	var count_before := _risen().size()
	_kill(zombie)
	_check(_risen().size() == count_before, "no Skeleton rose out of range")
	_check(necro.is_alive(), "the Necromancer is untouched")

func _test_no_dragon() -> void:
	print("-- Five summon deaths raise no Bone Dragon --")
	var necro: Enemy = _living(Enemy.EnemyType.NECROMANCER)[0]
	necro.current_health = 500  # survive the echoes
	for _i in range(5):
		necro._try_necro_summon(main.player)
		for e in main.enemy_spawner.get_living_enemies().duplicate():
			if e.raised_by == necro:
				_kill(e)
	_check(_living(Enemy.EnemyType.BONE_DRAGON).is_empty(), "no Bone Dragon after five summon deaths")
	_check(necro.current_health == 500 - 5 * Enemy.NECRO_SUMMON_DEATH_DAMAGE, "five echoes of %d" % Enemy.NECRO_SUMMON_DEATH_DAMAGE)
	for sk in _risen():
		_despawn(sk)

func _test_dead_necromancer() -> void:
	print("-- Once he is dead, nothing rises --")
	var necro: Enemy = _living(Enemy.EnemyType.NECROMANCER)[0]
	necro._try_necro_summon(main.player)
	var servant: Enemy = null
	for e in main.enemy_spawner.get_living_enemies():
		if e.raised_by == necro:
			servant = e
	_kill(necro)
	_check(not necro.is_alive(), "the Necromancer is dead")
	var count_before := _risen().size()
	if servant:
		_kill(servant)
	_check(_risen().size() == count_before, "his servant stays dead without him")
