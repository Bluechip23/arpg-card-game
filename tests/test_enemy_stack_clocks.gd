extends SceneTree

## Enemy-side status model after the designer's revised sheet, driven on a
## bare grid (no main.tscn):
##  - "A stack is 5 tempo": Slow, Vulnerable and Weaken fall one stack per
##    5 tempo on their own clocks and are never burned by moves, hits or
##    attacks; applying more adds stacks while the clock keeps running.
##  - Shock ticks itself AND arcs the same damage to the nearest other enemy
##    within 2 squares.
##  - Cold thaws 3 stacks per cycle (Frozen at 5 unchanged).
##  - Disarm, Root and Curse timers add; "disarm_attacks" is 5 tempo of
##    Disarm per stack.
##  - Wear Down lasts 2 enemy attacks, refreshed by every player hit.
##  - Lowered physical defense is grouped stacks: the strongest group still
##    holding a stack sets the reduction (4 at 10% + 2 at 50% → 50%, then 10%).
##  - Blind lands as a 1-stack debuff with no PlayerStats flag.
## Run: godot --headless --path . --script tests/test_enemy_stack_clocks.gd

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
	print("=== Enemy stack clocks ===")
	main = FakeMain.new()
	get_root().add_child(main)
	gm = GridManager.new()
	main.add_child(gm)
	spawner = FakeSpawner.new()
	main.add_child(spawner)
	main.enemy_spawner = spawner
	await process_frame

	_test_slow()
	_test_vulnerable()
	_test_weaken()
	_test_shock_arc()
	_test_cold_thaw()
	_test_additive_timers()
	_test_disarm_attacks()
	_test_wear_down()
	_test_phys_defense_groups()
	_test_blind()

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

const MOVE := {"name": "move", "tempo_cost": 2}

# ---------------------------------------------------------------------------

func _test_slow() -> void:
	print("--- Slow: stacks on a 5-tempo clock, moves burn nothing ---")
	var p := _unit(Vector2i(2, 2))
	var e := _enemy(Enemy.EnemyType.MINION, Vector2i(6, 2))
	var base: int = e._effective_cost(MOVE)
	e.apply_debuff("slow", 2)
	_check(e.slow_stacks == 2, "2 Slow applied")
	_check(e._effective_cost(MOVE) == base + Debuff.SLOWED_TEMPO_PER_TILE - 1,
		"a movement action costs +%d tempo while slowed (%d -> %d)" % [Debuff.SLOWED_TEMPO_PER_TILE - 1, base, e._effective_cost(MOVE)])
	e._consume_fire_taxes(MOVE)
	e._consume_fire_taxes(MOVE)
	_check(e.slow_stacks == 2, "firing two moves burns no stack")
	e._tick_timed_statuses(4)
	_check(e.slow_stacks == 2, "4 tempo: nothing falls yet")
	e._tick_timed_statuses(1)
	_check(e.slow_stacks == 1 and e.slow_clock == 0, "5 tempo: one stack falls")
	e.apply_debuff("slow", 1)
	e._tick_timed_statuses(3)
	_check(e.slow_stacks == 2, "a fresh stack adds on; the clock keeps running (3 in)")
	e._tick_timed_statuses(2)
	_check(e.slow_stacks == 1, "…so the next stack falls at 5, not 8")
	_check(e._effective_cost(MOVE) == base + Debuff.SLOWED_TEMPO_PER_TILE - 1, "still taxed with one stack left")
	e._tick_timed_statuses(5)
	_check(e.slow_stacks == 0 and not e.has_debuff_type("slow"), "the last stack falls; Slow is gone")
	_check(e._effective_cost(MOVE) == base, "movement cost is back to normal")
	e._tick_timed_statuses(7)
	e.apply_debuff("slow", 1)
	e._tick_timed_statuses(4)
	_check(e.slow_stacks == 1, "a stack applied after Slow ended gets its own full 5 tempo")
	_free_all([e, p])

func _test_vulnerable() -> void:
	print("--- Vulnerable: +30% on every hit, stacks fall on the clock ---")
	var p := _unit(Vector2i(2, 2))
	var e := _enemy(Enemy.EnemyType.MINION, Vector2i(3, 2))
	e.apply_debuff("vulnerable", 2)
	var hp0: int = e.current_health
	e.take_damage(100, true, DamageTypes.Type.PHYSICAL)
	_check(hp0 - e.current_health == 130, "a player hit lands +30%% (took %d)" % (hp0 - e.current_health))
	_check(e.vulnerable_stacks == 2, "the hit burns no stack")
	hp0 = e.current_health
	e.take_damage(100, true, DamageTypes.Type.PHYSICAL)
	_check(hp0 - e.current_health == 130 and e.vulnerable_stacks == 2, "the second hit lands +30% too, still 2 stacks")
	hp0 = e.current_health
	e.take_damage(100, false)
	_check(hp0 - e.current_health == 100, "non-player damage (a DoT tick) gets no bonus")
	e._tick_timed_statuses(5)
	_check(e.vulnerable_stacks == 1, "5 tempo: one stack falls")
	e._tick_timed_statuses(5)
	_check(e.vulnerable_stacks == 0 and not e.has_debuff_type("vulnerable"), "10 tempo: Vulnerable is gone")
	hp0 = e.current_health
	e.take_damage(100, true, DamageTypes.Type.PHYSICAL)
	_check(hp0 - e.current_health == 100, "hits are back to normal")
	_free_all([e, p])

func _test_weaken() -> void:
	print("--- Weaken: -30% on every attack, stacks fall on the clock ---")
	var p := _unit(Vector2i(2, 2))
	var e := _enemy(Enemy.EnemyType.MINION, Vector2i(3, 2))
	e.apply_debuff("weaken", 2)
	var hp0: int = p.hp()
	e._deal_damage_to_player(p, 10, "Attack")
	_check(hp0 - p.hp() == 7, "a weakened attack deals -30%% (dealt %d)" % (hp0 - p.hp()))
	_check(e.weaken_stacks == 2, "the attack burns no stack")
	hp0 = p.hp()
	e._deal_damage_to_player(p, 10, "Attack")
	_check(hp0 - p.hp() == 7 and e.weaken_stacks == 2, "the second attack is weakened too, still 2 stacks")
	e._tick_timed_statuses(5)
	_check(e.weaken_stacks == 1, "5 tempo: one stack falls")
	e._tick_timed_statuses(5)
	_check(e.weaken_stacks == 0 and not e.has_debuff_type("weaken"), "10 tempo: Weaken is gone")
	hp0 = p.hp()
	e._deal_damage_to_player(p, 10, "Attack")
	_check(hp0 - p.hp() == 10, "attacks are back to full")
	_free_all([e, p])

func _test_shock_arc() -> void:
	print("--- Shock: ticks itself and arcs to the nearest enemy within 2 ---")
	var p := _unit(Vector2i(0, 0))
	var a := _enemy(Enemy.EnemyType.MINION, Vector2i(5, 5))
	var near := _enemy(Enemy.EnemyType.MINION, Vector2i(6, 5))   # 1 away: the arc target
	var mid := _enemy(Enemy.EnemyType.MINION, Vector2i(5, 7))    # 2 away: in range, but not nearest
	var far := _enemy(Enemy.EnemyType.MINION, Vector2i(8, 5))    # 3 away: out of range
	a.apply_debuff("shock", 3)
	_check(a.shock_stacks == 3, "3 Shock applied")
	var hp_a: int = a.current_health
	var hp_near: int = near.current_health
	var hp_mid: int = mid.current_health
	var hp_far: int = far.current_health
	a._tick_status_durations()
	_check(hp_a - a.current_health == 3, "the tick deals its stacks (3) to itself")
	_check(hp_near - near.current_health == 3, "…and arcs 3 to the nearest enemy")
	_check(mid.current_health == hp_mid, "the second enemy in range is not hit (one target only)")
	_check(far.current_health == hp_far, "an enemy 3 squares away is out of the arc")
	_check(a.shock_stacks == 2, "then it loses a stack")
	_check(near.shock_stacks == 0, "the arc is damage, not Shock")
	# With no one in range, only the self tick lands.
	near.free()
	mid.free()
	hp_a = a.current_health
	hp_far = far.current_health
	a._tick_status_durations()
	_check(hp_a - a.current_health == 2 and far.current_health == hp_far, "no enemy within 2: the tick only hurts itself")
	_free_all([a, far, p])

func _test_cold_thaw() -> void:
	print("--- Cold: thaws 3 per cycle, Frozen at 5 ---")
	var p := _unit(Vector2i(0, 0))
	var e := _enemy(Enemy.EnemyType.MINION, Vector2i(5, 5))
	e.apply_debuff("cold", 4)
	_check(e.cold_stacks == 4 and not e.is_frozen, "4 Cold: not yet frozen")
	e._tick_status_durations()
	_check(e.cold_stacks == 1, "one cycle thaws 3 stacks (4 -> 1)")
	e._tick_status_durations()
	_check(e.cold_stacks == 0 and not e.has_debuff_type("cold"), "the next cycle clears the last one")
	e.apply_debuff("cold", 5)
	_check(e.is_frozen and e.cold_stacks == 0 and e.frozen_tempo == 5, "5 Cold still freezes for 5 tempo")
	_free_all([e, p])

func _test_additive_timers() -> void:
	print("--- Disarm / Root / Curse: a second application adds to the timer ---")
	var p := _unit(Vector2i(0, 0))
	var e := _enemy(Enemy.EnemyType.MINION, Vector2i(5, 5))
	e.apply_debuff("disarmed", 5)
	e.apply_debuff("disarmed", 3)
	_check(e.is_disarmed and e.disarmed_tempo == 8, "Disarm 5 then 3 = 8 tempo (got %d)" % e.disarmed_tempo)
	e.apply_debuff("root", 4)
	e.apply_debuff("root", 2)
	_check(e.rooted_tempo == 6, "Root 4 then 2 = 6 tempo (got %d)" % e.rooted_tempo)
	e.apply_debuff("cursed", 10)
	e.apply_debuff("cursed", 5)
	_check(e.cursed_tempo == 15, "Curse 10 then 5 = 15 tempo (got %d)" % e.cursed_tempo)
	e._tick_timed_statuses(8)
	_check(not e.is_disarmed and e.disarmed_tempo == 0, "Disarm runs out at 8")
	_check(e.rooted_tempo == 0 and e.cursed_tempo == 7, "Root is out; Curse has 7 left")
	_free_all([e, p])

func _test_disarm_attacks() -> void:
	print("--- disarm_attacks: 5 tempo of Disarm per stack ---")
	var p := _unit(Vector2i(2, 2))
	var e := _enemy(Enemy.EnemyType.MINION, Vector2i(3, 2))
	e.apply_debuff("disarm_attacks", 1)
	_check(e.is_disarmed and e.disarmed_tempo == 5, "1 stack = 5 tempo of Disarm (got %d)" % e.disarmed_tempo)
	_check(e.has_debuff_type("disarm_attacks") and e.has_debuff_type("disarmed"), "both keys report the timed disarm")
	_check(e.disarmed_attacks == 0, "no attack-skip counter is kept")
	var names: Array = []
	for eff in e.get_active_effects():
		names.append(eff["name"])
	_check("Disarm" in names and not ("Disarmed" in names), "one Disarm badge, no separate Disarmed badge")
	var hp0: int = p.hp()
	e._try_attack(p)
	_check(p.hp() == hp0, "it cannot attack while disarmed")
	e.apply_debuff("disarm_attacks", 2)
	_check(e.disarmed_tempo == 15, "2 more stacks add 10 tempo (got %d)" % e.disarmed_tempo)
	e._tick_timed_statuses(15)
	_check(not e.is_disarmed and not e.has_debuff_type("disarm_attacks"), "it runs out with the timer")
	_place(e, Vector2i(3, 2))
	hp0 = p.hp()
	e._try_attack(p)
	_check(p.hp() < hp0, "…and it can attack again")
	_free_all([e, p])

func _test_wear_down() -> void:
	print("--- Wear Down: lasts 2 enemy attacks ---")
	var p := _unit(Vector2i(2, 2))
	var e := _enemy(Enemy.EnemyType.MINION, Vector2i(3, 2))
	e.apply_wear_down(15)
	_check(e.wear_down_attacks == 2 and e.attack_reduction == 0, "armed for 2 attacks; nothing reduced until a hit lands")
	e.take_damage(5, true, DamageTypes.Type.PHYSICAL)
	_check(e.attack_reduction == 1, "a player hit under Wear Down raises the reduction to 1")
	e.take_damage(5, true, DamageTypes.Type.PHYSICAL)
	_check(e.attack_reduction == 2 and e.wear_down_attacks == 2, "a second hit: reduction 2, charges held at 2")
	e.take_damage(5, false)
	_check(e.attack_reduction == 2, "a DoT tick is not a hit")
	var tip: Dictionary = e.get_effect_tooltip("Wear Down")
	_check(tip["remaining"] == "Attacks left: 2", "tooltip counts attacks left (%s)" % str(tip["remaining"]))
	var hp0: int = p.hp()
	e._deal_damage_to_player(p, 10, "Attack")
	_check(hp0 - p.hp() == 8, "its first attack is reduced by 2 (dealt %d)" % (hp0 - p.hp()))
	_check(e.wear_down_attacks == 1 and e.attack_reduction == 2, "…and spends a charge")
	hp0 = p.hp()
	e._deal_damage_to_player(p, 10, "Attack")
	_check(hp0 - p.hp() == 8, "its second attack is still reduced")
	_check(e.wear_down_attacks == 0 and e.attack_reduction == 0, "after 2 attacks the reduction clears")
	hp0 = p.hp()
	e._deal_damage_to_player(p, 10, "Attack")
	_check(hp0 - p.hp() == 10, "the third attack is at full strength")
	e.take_damage(5, true, DamageTypes.Type.PHYSICAL)
	_check(e.attack_reduction == 0, "a hit without Wear Down armed does nothing")
	# Tempo never ends it: only its attacks do.
	e.apply_wear_down(15)
	e.take_damage(5, true, DamageTypes.Type.PHYSICAL)
	e._tick_timed_statuses(50)
	_check(e.wear_down_attacks == 2 and e.attack_reduction == 1, "50 tempo later it still holds — only attacks spend it")
	_free_all([e, p])

func _test_phys_defense_groups() -> void:
	print("--- Lowered physical defense: grouped stacks, strongest in force ---")
	var p := _unit(Vector2i(2, 2))
	var e := _enemy(Enemy.EnemyType.MINION, Vector2i(3, 2))
	e.apply_phys_defense_debuff(10.0, 4)
	_check(is_equal_approx(e.get_phys_defense_debuff_percent(), 10.0), "4 stacks at 10%: -10% in force")
	e.apply_phys_defense_debuff(50.0, 2)
	_check(is_equal_approx(e.get_phys_defense_debuff_percent(), 50.0), "+2 stacks at 50%: -50% in force")
	_check(e.get_phys_defense_debuff_stacks() == 6, "6 stacks on the badge")
	var hp0: int = e.current_health
	e.take_damage(100, true, DamageTypes.Type.PHYSICAL)
	_check(hp0 - e.current_health == 150, "a physical hit lands +50%% (took %d)" % (hp0 - e.current_health))
	hp0 = e.current_health
	e.take_damage(100, true, DamageTypes.Type.FIRE)
	_check(hp0 - e.current_health == 100, "a fire hit is unaffected")
	e._tick_timed_statuses(5)
	_check(is_equal_approx(e.get_phys_defense_debuff_percent(), 50.0) and e.get_phys_defense_debuff_stacks() == 4,
		"5 tempo: each group sheds one stack (3 at 10%, 1 at 50%) — still -50%")
	e._tick_timed_statuses(5)
	_check(is_equal_approx(e.get_phys_defense_debuff_percent(), 10.0) and e.get_phys_defense_debuff_stacks() == 2,
		"10 tempo: the 50% group is spent, -10% for what the first group has left")
	hp0 = e.current_health
	e.take_damage(100, true, DamageTypes.Type.PHYSICAL)
	_check(hp0 - e.current_health == 110, "now a physical hit lands +10%% (took %d)" % (hp0 - e.current_health))
	e._tick_timed_statuses(10)
	_check(e.phys_defense_groups.is_empty() and is_equal_approx(e.get_phys_defense_debuff_percent(), 0.0),
		"20 tempo: every stack is gone")
	hp0 = e.current_health
	e.take_damage(100, true, DamageTypes.Type.PHYSICAL)
	_check(hp0 - e.current_health == 100, "hits are back to normal")
	# A later group runs on its own clock.
	e.apply_phys_defense_debuff(20.0, 1)
	e._tick_timed_statuses(3)
	e.apply_phys_defense_debuff(30.0, 1)
	e._tick_timed_statuses(2)
	_check(is_equal_approx(e.get_phys_defense_debuff_percent(), 30.0), "the first group expires on its own clock; the later one stays")
	e._tick_timed_statuses(3)
	_check(e.phys_defense_groups.is_empty(), "…until its own 5 tempo are up")
	var names: Array = []
	e.apply_phys_defense_debuff(10.0, 1)
	for eff in e.get_active_effects():
		names.append(eff["name"])
	_check("Exposed Defense" in names, "it shows as Exposed Defense")
	_check("10%" in str(e.get_effect_tooltip("Exposed Defense")["desc"]), "with a tooltip naming the percent")
	_free_all([e, p])

func _test_blind() -> void:
	print("--- Blind: a 1-stack debuff, no PlayerStats flag ---")
	var p := _unit(Vector2i(2, 2))
	var hawk := _enemy(Enemy.EnemyType.GIANT_HAWK, Vector2i(3, 2))
	hawk.attack_blind_chance = 1.0
	_check(hawk._try_swoop(p), "Swoop lands")
	var blind = p.dm.get_debuff(Debuff.DebuffType.BLIND)
	_check(blind != null and blind.value == 1 and blind.duration == -1, "Blind is 1 stack on its own clock (value %d, duration %d)" % [blind.value if blind else -99, blind.duration if blind else -99])
	_check(p.dm.is_blinded(), "the debuff manager reports Blind")
	_check(not p.stats.is_blinded and p.stats.blind_tempo == 0, "PlayerStats.is_blinded / blind_tempo are left alone")
	p.dm.advance_time(5)
	_check(not p.dm.has_debuff(Debuff.DebuffType.BLIND), "it runs out after 5 tempo")
	_free_all([hawk, p])
