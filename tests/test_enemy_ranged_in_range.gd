extends SceneTree

## Designer, 2026-11-07: "if the enemy has a ranged attack, they should
## perform the ranged attack if they are in range." Checked in a booted
## main.tscn (the dojo):
##  - the Crypt Crawler throws its Web from range at unwebbed prey (and walks
##    in to bite once they hold the Paralysis card);
##  - the Spirit Collector casts Collect Soul from range when none of his
##    souls is held (and walks in to swing once one is);
##  - a ranged enemy's walk stops where its attack can reach, and does not
##    start at all when it already stands in reach; melee walkers still walk
##    their full move;
##  - methodical (designer, 2026-11-07): a wound-up attack is carried out even
##    if its target walked off (no chase), and the spiders' webs are aimed
##    when their wind-up begins — a crawler's web that misses is strung on the
##    floor, and whoever then steps in it is caught;
##  - the Spirit Collector casts from range until two of his souls are held.
## Run: godot --headless --path . --script tests/test_enemy_ranged_in_range.gd

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
	_test_crawler()
	_test_collector()
	_test_walk_stops_in_reach()
	_test_methodical()
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
		return
	var stats = main.player.get_stats()
	stats.max_health = 500
	stats.current_health = 500
	stats.current_armor = 0
	_dir = _open_direction()

## The straight line out of the player's cell with the most open floor, so
## spawned walkers have room to walk.
var _dir := Vector2i(1, 0)

func _open_direction() -> Vector2i:
	var best := Vector2i(1, 0)
	var best_n := -1
	var gm = main.grid_manager
	var start: Vector2i = _player_cell()
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := 0
		for i in range(1, 12):
			var c: Vector2i = start + d * i
			if c.x < 0 or c.y < 0 or c.x >= gm.grid_width or c.y >= gm.grid_height:
				break
			n += 1
		if n > best_n:
			best_n = n
			best = d
	return best

func _player_cell() -> Vector2i:
	return main.grid_manager.world_to_grid(main.player.position)

func _spawn(type: int, squares: int) -> Enemy:
	## An enemy `squares` cells from the player along the open line, still and ready.
	var e: Enemy = main.enemy_spawner.spawn_enemy(type, main._ground_pos(_player_cell() + _dir * squares))
	e.chosen_action = {}
	e.action_tempo_counter = 0
	return e

func _despawn(e: Enemy) -> void:
	if e and is_instance_valid(e):
		main.enemy_spawner.despawn_enemy(e)

func _clear_hand(cid: String) -> void:
	var deck = main.player.get_deck_manager()
	for i in range(deck.hand.size() - 1, -1, -1):
		if deck.hand[i].card_id == cid:
			deck.hand.remove_at(i)

func _end_cell(e: Enemy) -> Vector2i:
	return e.intended_cell()

func _dist_to_player(cell: Vector2i) -> int:
	var p := _player_cell()
	return absi(cell.x - p.x) + absi(cell.y - p.y)

# --------------------------------------------------------------- Crawler

func _test_crawler() -> void:
	print("-- Crypt Crawler --")
	_clear_hand("paralysis")
	var c := _spawn(Enemy.EnemyType.CRYPT_CRAWLER, 3)
	c._choose_action(main.player)
	_check(str(c.chosen_action.get("name", "")) == "web", "3 squares off, unwebbed prey: it throws the web (chose %s)" % c.chosen_action.get("name", ""))
	c._execute_action("web", main.player)
	var webbed: bool = c._hand_has_card_id(main.player, "paralysis")
	_check(webbed, "the web lands from 3 squares: Paralysis in the hand")
	c.chosen_action = {}
	c._choose_action(main.player)
	_check(str(c.chosen_action.get("name", "")) == "move", "prey already webbed: it walks in to bite")
	_despawn(c)
	_clear_hand("paralysis")
	var far := _spawn(Enemy.EnemyType.CRYPT_CRAWLER, Enemy.CRAWLER_WEB_RANGE + 1)
	far._choose_action(main.player)
	_check(str(far.chosen_action.get("name", "")) == "move", "beyond the web's reach: it closes in")
	_despawn(far)

# ------------------------------------------------------------- Collector

func _test_collector() -> void:
	print("-- Spirit Collector --")
	_clear_hand("release_soul")
	main.player.get_stats().current_health = 500
	var s := _spawn(Enemy.EnemyType.SPIRIT_COLLECTOR, 3)
	s._choose_action(main.player)
	_check(str(s.chosen_action.get("name", "")) == "collect_soul", "3 squares off: Collect Soul (chose %s)" % s.chosen_action.get("name", ""))
	s._execute_action("collect_soul", main.player)
	_check(int(main.player.get_stats().current_health) < 500, "the soul is drawn out from 3 squares: it hurts")
	_check(s._hand_has_card_id(main.player, "release_soul"), "and Release Soul is in the hand")
	s.chosen_action = {}
	s._choose_action(main.player)
	_check(str(s.chosen_action.get("name", "")) == "collect_soul", "one soul held: he still casts from range")
	s._execute_action("collect_soul", main.player)
	s.chosen_action = {}
	s._choose_action(main.player)
	_check(str(s.chosen_action.get("name", "")) == "move", "two of his souls held: he walks in to swing")
	_despawn(s)
	_clear_hand("release_soul")
	main.player.get_debuff_manager().clear_all_debuffs()
	main.player.get_stats().current_health = 500

# --------------------------------------------------------- Walk and reach

func _test_walk_stops_in_reach() -> void:
	print("-- The walk stops in reach --")
	# Giant Hawk: range 2, an 8-square flight.
	var hawk := _spawn(Enemy.EnemyType.GIANT_HAWK, 7)
	hawk._try_move(main.player)
	var hd := _dist_to_player(_end_cell(hawk))
	_check(hd == 2, "a Giant Hawk 7 squares off flies in to its swoop range, 2 (ends %d off)" % hd)
	_despawn(hawk)
	# Grave Titan: Boulder Roll from 3, a 4-square walk.
	var titan := _spawn(Enemy.EnemyType.GRAVE_TITAN, 6)
	titan._try_move(main.player)
	var td := _dist_to_player(_end_cell(titan))
	_check(td == 3, "a Grave Titan 6 squares off stops at boulder range, 3 (ends %d off)" % td)
	_despawn(titan)
	var near := _spawn(Enemy.EnemyType.GRAVE_TITAN, 3)
	near._try_move(main.player)
	_check(not near.is_moving, "a Grave Titan already 3 squares off holds its ground")
	_despawn(near)
	# A melee walker is untouched: the Zombie walks its full 3.
	var z := _spawn(Enemy.EnemyType.ZOMBIE, 5)
	z._try_move(main.player)
	var zd := _dist_to_player(_end_cell(z))
	_check(zd == 2, "a Zombie 5 squares off still walks its full 3 squares (ends %d off)" % zd)
	_despawn(z)
	# Silenced, a caster's spell is out: it walks on as before.
	var mage := _spawn(Enemy.EnemyType.SPARK_MAGE, 6)
	mage.is_silenced = true
	_check(mage._ranged_reach(main.player) == 0, "a silenced caster has no ranged reach")
	mage.is_silenced = false
	_check(mage._ranged_reach(main.player) == int(mage.attack_range), "unsilenced, its reach is its range")
	_despawn(mage)

func _step_player(by: Vector2i) -> void:
	var c := _player_cell() + by
	main.player.position = main._ground_pos(c)
	main.player.target_position = main.player.position
	if "is_moving" in main.player:
		main.player.is_moving = false

func _side() -> Vector2i:
	return Vector2i(_dir.y, _dir.x)   # a step across the open line

func _test_methodical() -> void:
	print("-- Methodical wind-ups --")
	var home := _player_cell()
	# A Grave Titan's Smash wound up; the player steps off: it still swings.
	main.player.get_stats().current_health = 500
	var titan := _spawn(Enemy.EnemyType.GRAVE_TITAN, 1)
	var t_cell: Vector2i = main.grid_manager.world_to_grid(titan.position)
	_step_player(-_dir * 3)
	var smash := titan._get_action("titan_smash")
	titan._execute_now(smash, main.player)
	_check(not titan.is_moving and main.grid_manager.world_to_grid(titan.position) == t_cell, "a wound-up Smash whose target stepped off is carried out where it stands — no chase")
	_check(int(main.player.get_stats().current_health) == 500, "and it lands on nothing")
	_despawn(titan)
	_step_player(home - _player_cell())

	# Crypt Crawler: aimed web, prey stays — caught.
	_clear_hand("paralysis")
	var c := _spawn(Enemy.EnemyType.CRYPT_CRAWLER, 3)
	c._choose_action(main.player)
	_check(c._aim_cell == _player_cell(), "the web is aimed at its prey's square when the wind-up begins")
	c._execute_now(c.chosen_action, main.player)
	_check(c._hand_has_card_id(main.player, "paralysis"), "prey still there: webbed")
	_clear_hand("paralysis")
	# Aimed, then the prey steps aside — and out of reach — before it lands.
	c.chosen_action = {}
	c._choose_action(main.player)
	var aimed := c._aim_cell
	_step_player(_side() + -_dir * 3)
	_check(c._get_cell_distance(main.player) > Enemy.CRAWLER_WEB_RANGE, "the prey is now out of the web's reach")
	c._execute_now(c.chosen_action, main.player)
	_check(not c._hand_has_card_id(main.player, "paralysis"), "it throws anyway and misses")
	_check(c.floor_web_cells() == [aimed], "the web is strung on the floor where its prey stood")
	c.chosen_action = {}
	_step_player(home - _player_cell())
	c._choose_action(main.player)
	_check(str(c.chosen_action.get("name", "")) == "web", "a web on the floor does not stop it throwing again")
	# Walking into the floor web catches you.
	c._check_floor_webs()
	_check(c._hand_has_card_id(main.player, "paralysis") and c.floor_web_cells().is_empty(), "stepping into the floor web: caught, and that web is spent")
	_clear_hand("paralysis")
	_despawn(c)

	# Magma Spider: Fire Web aimed, the prey walks out of range: it still lands.
	var m := _spawn(Enemy.EnemyType.MAGMA_SPIDER, 2)
	m._choose_action(main.player)
	_check(str(m.chosen_action.get("name", "")) == "fire_web", "a Magma Spider 2 squares off winds up its Fire Web")
	_step_player(-_dir * 4)
	_check(m._try_fire_web(main.player), "its prey walked out of range: the Fire Web lands where they stood all the same")
	_despawn(m)
	_step_player(home - _player_cell())
	main.player.get_debuff_manager().clear_all_debuffs()
