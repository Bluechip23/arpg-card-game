extends SceneTree

## Mountains second pass (docs/ENEMY_SHEET.tsv), driven on a bare grid: the
## Weregoat's Charge picks the lane that hits the most units and stuns where
## it lands; the Sabertooth's Track locks it onto the nearest unit; the Roc
## dives from 6 squares and backs off while the dive is down; the White
## Manticore's Clumsy runs on the clock for 3 cycles.
## Run: godot --headless --path . --script tests/test_sheet_mountains.gd

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
	print("=== Mountains sheet pass ===")
	main = FakeMain.new()
	get_root().add_child(main)
	gm = GridManager.new()
	main.add_child(gm)
	spawner = FakeSpawner.new()
	main.add_child(spawner)
	main.enemy_spawner = spawner
	await process_frame

	_test_weregoat()
	_test_sabertooth()
	_test_roc()
	_test_manticore()

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
	return p

func _clear_units() -> void:
	for p in spawner.players:
		p.queue_free()
	spawner.players.clear()
	spawner.player = null

func _enemy(type: Enemy.EnemyType, cell: Vector2i) -> Enemy:
	var e: Enemy = EnemyScene.instantiate()
	main.add_child(e)
	e.initialize(type, gm)
	_place(e, cell)
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

func _cell(n: Node3D) -> Vector2i:
	return gm.world_to_grid(n.position)

func _dist(a: Node3D, b: Node3D) -> int:
	return gm.get_distance_in_cells(a.position, b.position)

func _settle(e: Enemy) -> void:
	## Finish any glide at once — the physics step is not running here.
	if e.is_moving:
		_place(e, e.intended_cell())

func _chosen(e: Enemy) -> String:
	return str(e.chosen_action.get("name", ""))

# ---------------------------------------------------------------------------

func _test_weregoat() -> void:
	print("--- Weregoat: Charge ---")
	var a := _unit(Vector2i(4, 5))
	var b := _unit(Vector2i(6, 5))
	var c := _unit(Vector2i(5, 2))   # off every straight line through two units
	var goat := _enemy(Enemy.EnemyType.WEREGOAT, Vector2i(2, 5))
	goat._choose_action(a)
	_check(_chosen(goat) == "goat_charge", "two squares off, the goat lines up a Charge")
	# The spawner points it at the lone unit; the lane with two on it still wins.
	_check(goat._try_goat_charge(c), "Charge fires")
	_check(a.hp() == 492 and b.hp() == 492, "both units on the lane take 8 (%d, %d)" % [a.hp(), b.hp()])
	_check(c.hp() == 500, "the unit off the lane is untouched")
	_check(_cell(goat) == Vector2i(7, 5), "the goat pulls up on the square past its last victim (%s)" % str(_cell(goat)))
	_check(not goat.is_moving and goat._move_path.is_empty(), "the charge is a leap: no glide left queued")
	_check(b.dm.has_debuff(Debuff.DebuffType.STUN), "the unit within 1 square of the landing is Stunned")
	_check(not a.dm.has_debuff(Debuff.DebuffType.STUN) and not c.dm.has_debuff(Debuff.DebuffType.STUN),
		"…and nobody further off is")
	var stun = b.dm.get_debuff(Debuff.DebuffType.STUN)
	_check(stun != null and stun.duration == 3, "…for 3 tempo")

	# Nobody on a straight line: it charges the route and lands beside its target.
	_clear_units()
	var d := _unit(Vector2i(6, 7))
	_place(goat, Vector2i(2, 5))
	_check(goat._try_goat_charge(d), "Charge fires with nobody on a straight line")
	_check(_dist(goat, d) == 1, "…the goat charges the route and lands beside its target (%s)" % str(_cell(goat)))
	_check(d.hp() == 500, "…nothing was in the path, so no damage")
	_check(d.dm.has_debuff(Debuff.DebuffType.STUN), "…but the landing stuns them")

	# A wall across the lane: the charge stops short and nothing is hit through it.
	_clear_units()
	var f := _unit(Vector2i(7, 5))
	_place(goat, Vector2i(2, 5))
	goat.blocked_tiles.append(Vector2i(5, 5))
	goat._try_goat_charge(f)
	_check(f.hp() == 500, "a wall across the lane: nothing is hit through it")
	_check(_cell(goat) != Vector2i(5, 5) and _cell(goat) != Vector2i(7, 5), "…and the goat never lands in the wall or on the unit (%s)" % str(_cell(goat)))
	goat.blocked_tiles.clear()

	# Disarmed: no charge, it just walks.
	_clear_units()
	var g := _unit(Vector2i(6, 5))
	_place(goat, Vector2i(2, 5))
	goat.is_disarmed = true
	goat._try_goat_charge(g)
	_check(g.hp() == 500 and _cell(goat) == Vector2i(2, 5), "disarmed, the goat walks instead of charging")
	goat.is_disarmed = false
	goat.queue_free()
	_clear_units()

func _test_sabertooth() -> void:
	print("--- Sabertooth: Track lock ---")
	var near := _unit(Vector2i(5, 7))   # 2 squares off
	var far := _unit(Vector2i(9, 5))    # 4 squares off — the one the spawner hands it
	var tiger := _enemy(Enemy.EnemyType.SABERTOOTH, Vector2i(5, 5))
	_check(tiger._try_track(far), "Track fires")
	_check(tiger._track_target == near, "Track marks the nearest unit, not the spawner's target")
	_check(tiger.strengthen_stacks == 15, "+15 Strengthen")
	_check(tiger._move_target_for(far) == near, "moves and strikes now go to the quarry")
	tiger._choose_action(far)
	_check(_chosen(tiger) == "move", "two squares from the quarry it closes in")
	_place(tiger, Vector2i(5, 6))
	tiger._choose_action(far)
	_check(_chosen(tiger) == "bite_and_claw", "beside the quarry it lines up Bite and Claw though the spawner's target is 5 squares off")
	_check(tiger._execute_action("bite_and_claw", tiger._move_target_for(far)), "Bite and Claw fires")
	var dealt := 500 - near.hp()
	# Bite 6 + 15 (or 32 on a crit), then Claw 3 (or 5 on a crit) with no
	# Strengthen left: 24, 26, 35 or 37.
	_check(dealt in [24, 26, 35, 37], "Bite spends the +15 on the first blow, Claw rolls on its own: %d dealt" % dealt)
	_check(far.hp() == 500, "the spawner's target is left alone")
	_check(tiger.strengthen_stacks == 0, "the Track Strengthen is spent")
	# The quarry falls: the lock clears and the tiger goes back to the spawner's target.
	near.stats.current_health = 0
	_check(tiger._move_target_for(far) == far, "when the quarry dies the tiger goes back to the spawner's target")
	_check(tiger._track_target == null, "…and the lock is cleared")
	tiger._choose_action(far)
	_check(_chosen(tiger) == "move", "…so it measures to that target again")
	tiger.queue_free()
	_clear_units()

func _test_roc() -> void:
	print("--- Roc: dive, then back off ---")
	var p := _unit(Vector2i(8, 5))
	var roc := _enemy(Enemy.EnemyType.ROC, Vector2i(2, 5))   # 6 squares off
	var fired: Array = []
	roc.action_fired.connect(func(_e, nm): fired.append(nm))
	_check(_dist(roc, p) == 6, "set-up: the Roc starts 6 squares from the player")
	var dive_tempo := 0
	for t in range(1, 13):
		roc.on_tempo_advanced(1, p)
		_settle(roc)
		if "dive_bomb" in fired:
			dive_tempo = t
			break
	_check(dive_tempo > 0, "from 6 squares the Roc dives (tempo %d)" % dive_tempo)
	_check(_dist(roc, p) == 1, "…and lands beside the player (%s)" % str(_cell(roc)))
	# attack_damage carries the level-band scale (the sheet gives the dive no number).
	_check(p.hp() == 500 - roc.attack_damage, "…for its attack damage (%d)" % roc.attack_damage)
	_check(roc._dive_cooldown == 5, "the dive goes on a 5-tempo cooldown")
	_check(not roc.is_moving and roc._move_path.is_empty(), "the dive is a leap: no glide left queued")
	_check(_chosen(roc) == "roc_retreat", "with the dive down it picks the retreat straight away")
	# While the dive is down it backs off and never dives.
	fired.clear()
	var dived_early := false
	var ticks := 0
	while roc._dive_cooldown > 0 and ticks < 20:
		roc.on_tempo_advanced(1, p)
		_settle(roc)
		ticks += 1
		if "dive_bomb" in fired:
			dived_early = true
	_check(not dived_early, "no second dive while the cooldown runs")
	_check("roc_retreat" in fired, "it retreats while the dive is on cooldown")
	_check(_dist(roc, p) > 1, "…and is no longer beside the player when the cooldown ends (%d squares)" % _dist(roc, p))
	# The dive is back and the player is still within 6: it dives again.
	fired.clear()
	for _t in range(12):
		roc.on_tempo_advanced(1, p)
		_settle(roc)
		if "dive_bomb" in fired:
			break
	_check("dive_bomb" in fired and _dist(roc, p) == 1, "once the dive is back it dives again and lands beside them")
	# Out of the dive's reach it still backs off rather than idling.
	_place(roc, Vector2i(2, 5))
	p.position = gm.grid_to_world(Vector2i(12, 5))
	roc._dive_cooldown = 0
	roc._choose_action(p)
	_check(_chosen(roc) == "roc_retreat", "10 squares off with the dive ready it still backs off (the sheet: always away)")
	_check(roc._try_roc_retreat(p), "…and the retreat moves it")
	_settle(roc)
	_check(_dist(roc, p) == 11, "…one square further off (%d squares)" % _dist(roc, p))
	# Cornered by walls on three sides (a live map rings itself with walls, so
	# the grid edge never comes into it): nothing is further off, so it holds
	# and reports it could not move.
	_place(roc, Vector2i(5, 5))
	p.position = gm.grid_to_world(Vector2i(6, 5))
	roc.blocked_tiles.append(Vector2i(4, 5))
	roc.blocked_tiles.append(Vector2i(5, 4))
	roc.blocked_tiles.append(Vector2i(5, 6))
	_check(not roc._try_roc_retreat(p), "cornered, the retreat reports it could not move")
	roc.blocked_tiles.clear()
	# Eye Scrape: only after a unit has crowded it for more than 3 tempo.
	_place(roc, Vector2i(5, 5))
	p.position = gm.grid_to_world(Vector2i(6, 5))
	roc._roc_melee_tempo = 3
	_check(not roc._try_eye_scrape(p), "Eye Scrape does not land at 3 tempo in melee reach")
	roc._roc_melee_tempo = 4
	_check(roc._try_eye_scrape(p), "…it lands once they have stayed more than 3 tempo")
	var weak = p.dm.get_debuff(Debuff.DebuffType.WEAKENED)
	_check(weak != null and weak.value == 2, "…for 2 Weakened")
	roc.queue_free()
	_clear_units()

func _test_manticore() -> void:
	print("--- White Manticore: Clumsy on the clock ---")
	var m := _unit(Vector2i(5, 5))
	var cat := _enemy(Enemy.EnemyType.WHITE_MANTICORE, Vector2i(6, 5))
	_check(cat._try_stinger(m), "Stinger lands")
	var poison = m.dm.get_debuff(Debuff.DebuffType.POISON)
	_check(poison != null and poison.value == 8, "Stinger lays 8 Poison")
	_check(cat._stinger_cooldown == 5, "Stinger goes on its 5-tempo cooldown")
	var cl = m.dm.get_debuff(Debuff.DebuffType.CLUMSY)
	_check(cl != null and cl.clock_timed and cl.duration == 15, "Clumsy runs on the clock for 15 tempo (3 cycles)")
	_check(m.dm.get_clumsy_chance() == 30, "…30% to discard while it lasts")
	_check(cl != null and "15 tempo left" in cl.description, "…and the description says so: %s" % (cl.description if cl else "-"))
	for is_attack in [false, true, false, false]:
		m.dm.on_card_played(is_attack)
	_check(m.dm.has_debuff(Debuff.DebuffType.CLUMSY) and m.dm.get_clumsy_chance() == 30, "cards played do not burn a clock-timed Clumsy")
	m.dm.advance_time(14)
	_check(m.dm.has_debuff(Debuff.DebuffType.CLUMSY), "14 tempo on it still holds")
	_check("1 tempo left" in m.dm.get_debuff(Debuff.DebuffType.CLUMSY).description, "…with 1 tempo left")
	m.dm.advance_time(1)
	_check(not m.dm.has_debuff(Debuff.DebuffType.CLUMSY) and m.dm.get_clumsy_chance() == 0, "at 15 tempo it runs out")
	var text := ""
	for d in Enemy.get_all_enemy_data():
		if d["name"] == "White Manticore":
			text = str(d["special"])
	_check("Clumsy for 3 cycles (15 tempo)" in text, "the compendium says Clumsy for 3 cycles (15 tempo)")
	cat.queue_free()
	_clear_units()
