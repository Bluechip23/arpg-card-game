extends SceneTree

## Burn and Poison after the designer's 2026-11-23 rules, the same on
## enemies and players, driven on a bare grid (no main.tscn):
##  - Both tick every 2 tempo, counted from when the first stack lands.
##  - Poison deals its stacks and loses 1 (20, 19, 18...); while poisoned,
##    healing is cut 25% — but poison turned to healing (Elixir) heals in
##    full and carries none of the cut.
##  - Burn deals its stacks + 3 and 2 more that lands on armor (on health
##    when there is none), then 5 stacks are used up; each stack lowers every
##    resistance by 0.5%, and the tick is not raised by its own drop.
## Run: godot --headless --path . --script tests/test_burn_poison_rework.gd

const EnemyScene = preload("res://scenes/battle/enemy.tscn")
var failures: int = 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

## A player-side unit with the real stat and debuff pipeline, so enemy hits
## and debuffs land the way they do on a Player.
class FakePlayer extends Node3D:
	var stats: PlayerStats = null
	var dm: DebuffManager = null
	func _init() -> void:
		stats = PlayerStats.new()
		stats.max_health = 500
		stats.current_health = 500
		dm = DebuffManager.new()
		add_child(dm)
		dm.initialize(stats, self)
	func get_stats() -> PlayerStats:
		return stats
	func get_debuff_manager() -> DebuffManager:
		return dm
	func hp() -> int:
		return stats.current_health

## Just enough of EnemySpawner for Enemy._player_units().
class FakeSpawner extends Node:
	var player: Node3D = null
	var players: Array = []
	var summons: Array = []
	func _living_players() -> Array:
		var out: Array = []
		for p in players:
			if is_instance_valid(p) and p.get_stats().current_health > 0:
				out.append(p)
		return out
	func _living_summons() -> Array:
		return summons

## Just enough of Main: the enemies' parent, carrying the spawner.
class FakeMain extends Node3D:
	var enemy_spawner: FakeSpawner = null
	var player: Node3D = null

var main: FakeMain
var gm: GridManager
var spawner: FakeSpawner

func _initialize() -> void:
	_run()

func _run() -> void:
	print("=== Burn and Poison rework ===")
	main = FakeMain.new()
	get_root().add_child(main)
	gm = GridManager.new()
	main.add_child(gm)
	spawner = FakeSpawner.new()
	main.add_child(spawner)
	main.enemy_spawner = spawner
	await process_frame

	_test_enemy_poison()
	_test_enemy_burn()
	_test_enemy_burn_resist()
	_test_player_poison()
	_test_player_burn()
	_test_elixir()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

# ---------------------------------------------------------------------------

func _unit(cell: Vector2i) -> FakePlayer:
	var p := FakePlayer.new()
	main.add_child(p)
	p.position = gm.grid_to_world(cell)
	spawner.players.append(p)
	if spawner.player == null:
		spawner.player = p
	main.player = p
	return p

func _clear_units() -> void:
	for p in spawner.players:
		p.queue_free()
	spawner.players.clear()
	spawner.player = null
	main.player = null

func _enemy(type: Enemy.EnemyType, cell: Vector2i) -> Enemy:
	var e: Enemy = EnemyScene.instantiate()
	main.add_child(e)
	e.initialize(type, gm)
	_place(e, cell)
	# A big, bare pool so every hit reads straight off current_health.
	e.current_armor = 0
	e.max_health = 10000
	e.current_health = 10000
	e.unit_cells_provider = func() -> Array:
		var cells: Array = []
		for p in spawner._living_players():
			cells.append(gm.world_to_grid(p.position))
		return cells
	return e

func _place(e: Enemy, cell: Vector2i) -> void:
	e.position = gm.grid_to_world(cell)
	e.target_position = e.position
	e.is_moving = false
	e._move_path.clear()

## Frees the enemies at once (so later _sibling_enemies() scans do not see
## them) and lets the player units go through _clear_units.
func _free_all(nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n) and n is Enemy:
			n.free()
	_clear_units()

# ---------------------------------------------------------------------------

func _test_enemy_poison() -> void:
	print("--- Poison on an enemy: 20, 19, 18... one tick every 2 tempo ---")
	var p := _unit(Vector2i(0, 0))
	var e := _enemy(Enemy.EnemyType.MINION, Vector2i(9, 9))
	e.apply_debuff("poison", 20)
	var hp: int = e.current_health
	e.on_tempo_advanced(1, p)
	_check(e.current_health == hp, "nothing after 1 tempo")
	e.on_tempo_advanced(1, p)
	_check(hp - e.current_health == 20 and e.poison_stacks == 19, "2 tempo: 20 damage, 19 left (%d, %d)" % [hp - e.current_health, e.poison_stacks])
	e.on_tempo_advanced(2, p)
	_check(hp - e.current_health == 39 and e.poison_stacks == 18, "4 tempo: 19 more, 18 left")
	e.on_tempo_advanced(4, p)
	_check(hp - e.current_health == 39 + 18 + 17 and e.poison_stacks == 16, "a 4-tempo step ticks twice: 18 then 17")
	# The 5-tempo cycle no longer ticks it.
	hp = e.current_health
	e._tick_status_durations()
	_check(e.current_health == hp and e.poison_stacks == 16, "the 5-tempo cycle leaves Poison alone")
	# Healing is cut by a quarter while poisoned.
	e.current_health = 5000
	e._regenerate(100)
	_check(e.current_health == 5075, "a 100 heal on a poisoned enemy heals 75 (%d)" % (e.current_health - 5000))
	e.poison_stacks = 0
	e._regenerate(100)
	_check(e.current_health == 5175, "…and 100 once the poison is gone")
	_free_all([e, p])

func _test_enemy_burn() -> void:
	print("--- Burn on an enemy: stacks + 3, 2 more to armor, 5 used per tick ---")
	var p := _unit(Vector2i(0, 0))
	var e := _enemy(Enemy.EnemyType.MINION, Vector2i(9, 9))
	e.apply_debuff("burn", 20)
	var hp: int = e.current_health
	e.on_tempo_advanced(2, p)
	_check(hp - e.current_health == 25 and e.burn_stacks == 15, "20 Burn, no armor: 23 + 2 to health, 15 left (%d, %d)" % [hp - e.current_health, e.burn_stacks])
	e.on_tempo_advanced(2, p)
	_check(hp - e.current_health == 25 + 20 and e.burn_stacks == 10, "then 15 Burn: 20, 10 left")
	e.on_tempo_advanced(4, p)
	_check(hp - e.current_health == 25 + 20 + 15 + 10 and e.burn_stacks == 0, "then 15 and 10, and the Burn is spent")
	hp = e.current_health
	e.on_tempo_advanced(6, p)
	_check(e.current_health == hp, "no Burn, no tick")
	# Fewer than 5 stacks: the tick uses what is there.
	e.apply_debuff("burn", 3)
	e.on_tempo_advanced(2, p)
	_check(hp - e.current_health == 8 and e.burn_stacks == 0, "3 Burn: 6 + 2, all 3 used")
	# Armor soaks the tick like any hit.
	hp = e.current_health
	e.current_armor = 10
	e.apply_debuff("burn", 10)
	e.on_tempo_advanced(2, p)
	_check(e.current_armor == 0 and hp - e.current_health == 5, "10 Burn into 10 armor: the armor goes and 5 reaches health (%d armor, %d lost)" % [e.current_armor, hp - e.current_health])
	# The clock starts when the first stack lands, not on a shared beat.
	e.burn_stacks = 0
	e.on_tempo_advanced(1, p)
	e.apply_debuff("burn", 1)
	hp = e.current_health
	e.on_tempo_advanced(1, p)
	_check(e.current_health == hp, "1 tempo after it lands: not yet")
	e.on_tempo_advanced(1, p)
	_check(hp - e.current_health == 6, "2 tempo after it lands: 1 + 3 + 2")
	_free_all([e, p])

func _test_enemy_burn_resist() -> void:
	print("--- Burn lowers every resistance 0.5% per stack ---")
	var p := _unit(Vector2i(0, 0))
	var e := _enemy(Enemy.EnemyType.MINION, Vector2i(9, 9))
	e.damage_resistances[DamageTypes.Type.FIRE] = 50.0
	var hp: int = e.current_health
	e.take_damage(100, false, DamageTypes.Type.FIRE)
	_check(hp - e.current_health == 50, "50% fire resist: 100 lands as 50")
	e.burn_stacks = 20
	hp = e.current_health
	e.take_damage(100, false, DamageTypes.Type.FIRE)
	_check(hp - e.current_health == 60, "20 Burn: the resist is 40%%, 100 lands as 60 (%d)" % (hp - e.current_health))
	hp = e.current_health
	e.take_damage(100, false, DamageTypes.Type.LIGHTNING)
	_check(hp - e.current_health == 110, "a type it never resisted goes below 0: 100 lands as 110 (%d)" % (hp - e.current_health))
	# The Burn tick itself is not raised by its own drop.
	hp = e.current_health
	e._tick_burn_poison()
	_check(hp - e.current_health == 25, "the tick still deals 20 + 3 + 2 (%d)" % (hp - e.current_health))
	_free_all([e, p])

func _test_player_poison() -> void:
	print("--- Poison on a player: the same clock, and healing cut 25% ---")
	var p := _unit(Vector2i(0, 0))
	p.stats.intelligence = 0  # no flat heal bonus: heals read as written
	p.dm.apply_debuff(Debuff.create(Debuff.DebuffType.POISON, 20, 15))
	p.dm.advance_time(2)
	_check(p.hp() == 480, "2 tempo: 20 damage (%d)" % (500 - p.hp()))
	p.dm.advance_time(2)
	_check(p.hp() == 461, "4 tempo: 19 more")
	p.dm.advance_time(30)
	var left = p.dm.get_debuff(Debuff.DebuffType.POISON)
	_check(left != null and left.value == 3, "34 tempo in it is still ticking down — no 15-tempo timer ends it (%s)" % (str(left.value) if left else "gone"))
	_check(is_equal_approx(p.stats.poison_heal_cut, 0.25), "the carrier's healing is cut")
	p.stats.current_health = 100
	p.stats.heal(100)
	_check(p.hp() == 175, "a 100 heal heals 75 (%d)" % (p.hp() - 100))
	p.dm.remove_debuff(Debuff.DebuffType.POISON)
	p.stats.heal(100)
	_check(p.hp() == 275, "…and 100 once the poison is gone")
	_clear_units()

func _test_player_burn() -> void:
	print("--- Burn on a player: stacks + 3, 2 more to armor, 5 used, resistances down ---")
	var p := _unit(Vector2i(0, 0))
	p.dm.apply_debuff(Debuff.create(Debuff.DebuffType.BURN, 12))
	_check(is_equal_approx(p.stats.burn_resist_drop, 6.0), "12 Burn: every resistance down 6%")
	p.stats.damage_resistances[DamageTypes.Type.FIRE] = 26.0
	p.stats.take_damage(100, null, null, DamageTypes.Type.FIRE)
	_check(p.hp() == 420, "26%% fire resist is 20%%: 100 lands as 80 (%d)" % (500 - p.hp()))
	p.stats.current_health = 500
	p.dm.advance_time(2)
	_check(p.hp() == 483, "the tick deals 12 + 3 + 2, not raised by its own drop (%d)" % (500 - p.hp()))
	var burn = p.dm.get_debuff(Debuff.DebuffType.BURN)
	_check(burn != null and burn.value == 7 and is_equal_approx(p.stats.burn_resist_drop, 3.5), "7 Burn left, the drop follows it")
	p.stats.current_armor = 4
	p.dm.advance_time(2)
	_check(p.stats.current_armor == 0 and p.hp() == 483 - 8, "7 Burn into 4 armor: the armor goes, 8 reaches health (%d)" % (483 - p.hp()))
	p.dm.advance_time(2)
	_check(p.hp() == 475 - 7 and not p.dm.has_debuff(Debuff.DebuffType.BURN), "the last 2 Burn: 7, and it is gone")
	_check(is_zero_approx(p.stats.burn_resist_drop), "the resistances are back")
	_clear_units()

func _test_elixir() -> void:
	print("--- Poison turned to healing carries none of the cut ---")
	var p := _unit(Vector2i(0, 0))
	p.stats.intelligence = 0  # no flat heal bonus: heals read as written
	p.dm.apply_debuff(Debuff.create(Debuff.DebuffType.POISON, 10, 15))
	p.stats.elixir_stacks = 1
	p.stats.current_health = 100
	p.dm.advance_time(2)
	_check(p.hp() == 110 and p.stats.elixir_stacks == 0, "the Elixir tick heals the full 10 (%d)" % (p.hp() - 100))
	# While Elixir stacks are up, other healing is not cut either.
	p.stats.elixir_stacks = 1
	p.stats.current_health = 100
	p.stats.heal(100)
	_check(p.hp() == 200, "with poison turning to healing, a 100 heal heals 100 (%d)" % (p.hp() - 100))
	p.stats.elixir_stacks = 0
	p.stats.heal(100)
	_check(p.hp() == 275, "Elixir spent: the cut is back (%d)" % (p.hp() - 200))
	# Poison from a card played under Elixir heals at once, in full.
	p.stats.current_health = 100
	Card.elixir_poison_heals = true
	p.dm.apply_debuff(Debuff.create(Debuff.DebuffType.POISON, 8, 15))
	Card.elixir_poison_heals = false
	_check(p.hp() == 108, "poison applied under Elixir heals its full 8 on a poisoned carrier (%d)" % (p.hp() - 100))
	_clear_units()
