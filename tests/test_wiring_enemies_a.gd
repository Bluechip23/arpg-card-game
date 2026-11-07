extends SceneTree

## Phase 2 wiring audit, slice enemies_a (docs/audit/wiring/enemies_a.md).
## For each enemy in the slice, the compendium text (Enemy.get_all_enemy_data
## `_specials` / `_actions`) against what the code does: action names and
## tempo, damage, riders, ranges, move spaces and passives. Checked in a booted
## main.tscn (the dojo), firing the real choosers and executors.
## Damage numbers in the compendium are base numbers; the game scales them by
## Enemy.passive_power_scale (the compendium says so under each scaled entry),
## so every expected hit below is the base scaled the same way.
## Run: godot --headless --path . --script tests/test_wiring_enemies_a.gd

var failures: int = 0
var main = null

const SLICE := ["MINION", "ELITE", "BOSS", "WERERAT", "SKELETON", "ARMORED_TROLL", "ARCHER_RAT",
	"HYDRA", "FIRE_GOBLIN_SOLDIER", "FIRE_GOBLIN_MAGE", "FIRE_GOBLIN_SHAMAN", "GIANT_BEAVER",
	"MINI_BEAR", "LARGE_BEAR", "WOLF", "COYOTE", "BUGBEAR", "INFECTED_HUNTER", "GIANT_HAWK",
	"TREANT", "ICE_MAGE", "FIRE_MAGE", "SPARK_MAGE", "AIR_MAGE", "EARTH_MAGE", "ZOMBIE",
	"WEREWOLF", "TREASURE_BUNNY", "VAMPIRE", "NECROMANCER", "BONE_DRAGON", "SPIRIT_COLLECTOR",
	"GRAVE_TITAN", "CRYPT_CRAWLER", "SCREECHER", "CONSUMED", "SLUDGE"]

## "Move (N tempo): X spaces" in the compendium, per type (X).
const MOVE_SPACES := {
	"ARMORED_TROLL": 2, "ARCHER_RAT": 2, "HYDRA": 3, "FIRE_GOBLIN_SOLDIER": 4,
	"FIRE_GOBLIN_MAGE": 2, "FIRE_GOBLIN_SHAMAN": 2, "GIANT_BEAVER": 3, "MINI_BEAR": 5,
	"LARGE_BEAR": 6, "WOLF": 4, "COYOTE": 4, "BUGBEAR": 6, "INFECTED_HUNTER": 2,
	"GIANT_HAWK": 8, "TREANT": 9, "ICE_MAGE": 3, "FIRE_MAGE": 2, "SPARK_MAGE": 2,
	"AIR_MAGE": 6, "EARTH_MAGE": 5, "ZOMBIE": 3, "WEREWOLF": 3, "TREASURE_BUNNY": 2,
	"VAMPIRE": 5, "NECROMANCER": 8, "BONE_DRAGON": 5, "GRAVE_TITAN": 4,
	"CRYPT_CRAWLER": 3, "SCREECHER": 4, "CONSUMED": 5, "SLUDGE": 3,
}

## "Range N" / "range N" / "reach N" in the compendium, per type.
const RANGES := {
	"ARCHER_RAT": 6, "FIRE_GOBLIN_MAGE": 4, "FIRE_GOBLIN_SHAMAN": 5, "GIANT_HAWK": 2,
	"ICE_MAGE": 3, "FIRE_MAGE": 2, "SPARK_MAGE": 6, "AIR_MAGE": 8, "NECROMANCER": 10,
	"SLUDGE": 6,
}

## A summon-like player-side unit (no stats pipeline): counts the hits it takes.
class Bystander extends Node3D:
	var is_dead: bool = false
	var hits: int = 0
	var last_damage: int = 0
	func take_damage(amount: int) -> void:
		hits += 1
		last_damage = amount

var _hits: Array = []   # [attack_name, damage] for every hit_landed on a watched enemy

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
	_test_tables()
	await _settle(2)
	_test_brutes()
	await _settle(2)
	_test_wererat()
	await _settle(2)
	_test_skeleton()
	await _settle(2)
	_test_troll()
	await _settle(2)
	_test_archer_rat()
	await _settle(2)
	_test_hydra()
	await _settle(2)
	_test_goblins()
	await _settle(2)
	_test_beaver()
	await _settle(2)
	await _test_bears()
	await _settle(2)
	_test_wolf_coyote_bugbear()
	await _settle(2)
	_test_hunter()
	await _settle(2)
	_test_hawk()
	await _settle(2)
	_test_treant()
	await _settle(2)
	_test_mages()
	await _settle(2)
	_test_zombie()
	await _settle(2)
	_test_werewolf()
	await _settle(2)
	_test_bunny()
	await _settle(2)
	_test_vampire()
	await _settle(2)
	_test_necromancer()
	await _settle(2)
	_test_bone_dragon()
	await _settle(2)
	_test_collector()
	await _settle(2)
	_test_titan()
	await _settle(2)
	_test_crawler()
	await _settle(2)
	_test_screecher()
	await _settle(2)
	_test_consumed()
	await _settle(2)
	_test_sludge()
	await _settle(2)
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
	_reset_player()
	_dir = _open_direction()

var _dir := Vector2i(1, 0)
var _home := Vector2i.ZERO

func _open_direction() -> Vector2i:
	var best := Vector2i(1, 0)
	var best_n := -1
	var gm = main.grid_manager
	var start: Vector2i = _player_cell()
	_home = start
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := 0
		for i in range(1, 14):
			var c: Vector2i = start + d * i
			if c.x < 0 or c.y < 0 or c.x >= gm.grid_width or c.y >= gm.grid_height:
				break
			n += 1
		if n > best_n:
			best_n = n
			best = d
	_room = best_n
	return best

var _room := 0

func _player_cell() -> Vector2i:
	return main.grid_manager.world_to_grid(main.player.position)

func _side() -> Vector2i:
	return Vector2i(_dir.y, _dir.x)

func _reset_player() -> void:
	var stats = main.player.get_stats()
	stats.max_health = 900
	stats.current_health = 900
	stats.current_armor = 0
	stats.max_mana = 200
	stats.current_mana = 200
	main.player.get_debuff_manager().clear_all_debuffs()
	main.player.position = main._ground_pos(_home) if _home != Vector2i.ZERO else main.player.position
	main.player.target_position = main.player.position
	if "is_moving" in main.player:
		main.player.is_moving = false

func _clear_hand(cid: String) -> void:
	var deck = main.player.get_deck_manager()
	for i in range(deck.hand.size() - 1, -1, -1):
		if deck.hand[i].card_id == cid:
			deck.hand.remove_at(i)

func _hand_count(cid: String) -> int:
	var n := 0
	for c in main.player.get_deck_manager().hand:
		if c.card_id == cid:
			n += 1
	return n

func _spawn(type_name: String, squares: int, side: int = 0) -> Enemy:
	## An enemy `squares` cells from the player along the open line, still and ready.
	var cell: Vector2i = _player_cell() + _dir * squares + _side() * side
	var e: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType[type_name], main._ground_pos(cell))
	e.chosen_action = {}
	e.action_tempo_counter = 0
	e.hit_landed.connect(_on_hit)
	return e

func _on_hit(_e, victim, attack_name: String, damage: int, _lost: int) -> void:
	_hits.append([attack_name, damage, victim])

func _despawn(e) -> void:
	if e and is_instance_valid(e):
		main.enemy_spawner.despawn_enemy(e)

## Total damage the watched enemies landed while running `action` once.
func _fire(e: Enemy, action: String) -> int:
	_hits.clear()
	e._execute_action(action, main.player)
	var total := 0
	for h in _hits:
		total += int(h[1])
	return total

## The compendium's base number, scaled the way initialize() scales it.
func _scaled(type_name: String, base: int) -> int:
	var lvl := int(EnemyDefs.DEFS[type_name].get("intended_level", 0))
	return maxi(1, roundi(base * Enemy.passive_power_scale(lvl)["dmg"]))

func _chose(e: Enemy) -> String:
	e.chosen_action = {}
	e._choose_action(main.player)
	return str(e.chosen_action.get("name", ""))

func _dist_to_player(cell: Vector2i) -> int:
	var p := _player_cell()
	return absi(cell.x - p.x) + absi(cell.y - p.y)

func _debuff_value(t: int) -> int:
	var total := 0
	for d in main.player.get_debuff_manager().debuffs:
		if d.debuff_type == t:
			total += int(d.value)
	return total

func _debuff_count(t: int) -> int:
	var n := 0
	for d in main.player.get_debuff_manager().debuffs:
		if d.debuff_type == t:
			n += 1
	return n

func _resist(e: Enemy, t: int) -> int:
	return int(e.damage_resistances.get(t, 0.0))

# ------------------------------------------------------------ Data tables

func _test_tables() -> void:
	print("-- Compendium tables vs the action tables --")
	var data: Array = Enemy.get_all_enemy_data()
	for k in SLICE:
		var t: int = Enemy.EnemyType[k]
		var real: Array = Enemy.actions_for_type(t)
		var shown: Array = data[t]["actions"]
		var same := real.size() == shown.size()
		if same:
			for i in range(real.size()):
				if int(real[i]["tempo_cost"]) != int(shown[i]["tempo"]):
					same = false
		_check(same, "%s: compendium actions and tempo match actions_for_type (%d actions)" % [k, real.size()])
		var e: Enemy = main.enemy_spawner.spawn_enemy(t, main._ground_pos(_player_cell() + _dir * 6))
		if MOVE_SPACES.has(k):
			_check(int(e.move_distance) == int(MOVE_SPACES[k]), "%s: Move covers %d spaces (move_distance %s)" % [k, MOVE_SPACES[k], e.move_distance])
		if RANGES.has(k):
			_check(int(e.attack_range) == int(RANGES[k]), "%s: range %d (attack_range %s)" % [k, RANGES[k], e.attack_range])
		_despawn(e)

# ---------------------------------------------------- Minion / Elite / Boss

func _test_brutes() -> void:
	print("-- Minion / Elite / Boss --")
	for pair in [["MINION", 3], ["ELITE", 6], ["BOSS", 10]]:
		var k: String = pair[0]
		var e := _spawn(k, 1)
		_check(_chose(e) == "attack", "%s: at range 1 it attacks" % k)
		_check(_fire(e, "attack") == _scaled(k, pair[1]), "%s: Attack hits for its damage (%d)" % [k, _scaled(k, pair[1])])
		_despawn(e)
		var f := _spawn(k, 3)
		_check(_chose(f) == "move", "%s: otherwise it moves toward the player" % k)
		_despawn(f)
	_reset_player()

# ----------------------------------------------------------------- Wererat

func _test_wererat() -> void:
	print("-- Wererat --")
	var e := _spawn("WERERAT", 1)
	_check(_chose(e) == "bite", "Wererat: at range 1 it bites")
	_check(_fire(e, "bite") == _scaled("WERERAT", 3), "Wererat: Bite hits for 3 (scaled %d)" % _scaled("WERERAT", 3))
	_despawn(e)
	var m := _spawn("WERERAT", 3)
	_check(_chose(m) == "move", "Wererat: at range 3 it moves")
	_despawn(m)
	if _room >= 8:
		var s := _spawn("WERERAT", 8)
		_check(_chose(s) == "scurry", "Wererat: at range 6+ it scurries")
		s._try_scurry(main.player)
		var d := _dist_to_player(s.intended_cell())
		_check(d == 3, "Wererat: Scurry dashes 5 tiles toward you (8 -> %d)" % d)
		_despawn(s)
	_reset_player()

# ---------------------------------------------------------------- Skeleton

func _test_skeleton() -> void:
	print("-- Skeleton --")
	var e := _spawn("SKELETON", 1)
	_check(_chose(e) == "attack", "Skeleton: at range 1 it attacks")
	_check(_fire(e, "attack") == _scaled("SKELETON", 6), "Skeleton: Attack hits for 6 (scaled)")
	_despawn(e)
	var f := _spawn("SKELETON", 3)
	_check(_chose(f) == "move", "Skeleton: otherwise it moves")
	_despawn(f)
	_reset_player()

# ----------------------------------------------------------- Armored Troll

func _test_troll() -> void:
	print("-- Armored Troll --")
	var e := _spawn("ARMORED_TROLL", 1)
	var P := DamageTypes.Type
	_check(_resist(e, P.PHYSICAL) == 30 and _resist(e, P.FIRE) == 15 and _resist(e, P.LIGHTNING) == 15, "Troll: resists 30% physical / 15% fire / 15% lightning")
	e.current_health = e.max_health - 10
	e.on_tempo_advanced(6, null)
	_check(e.current_health == e.max_health - 7, "Troll: regenerates 3 HP every 6 global tempo")
	seed(4242)
	var smash := 0
	for _i in range(400):
		var n := _chose(e)
		if n == "smash":
			smash += 1
	_check(smash > 200 and smash < 280, "Troll: at range 1 it Smashes ~60%% of the time (%d/400), Kicks otherwise" % smash)
	_check(_fire(e, "kick") == _scaled("ARMORED_TROLL", 6), "Troll: Kick hits for 6 (scaled)")
	_clear_hand("lightly_dazed")
	_check(_fire(e, "smash") == _scaled("ARMORED_TROLL", 14), "Troll: Smash hits for 14 (scaled)")
	_check(_hand_count("lightly_dazed") == 1, "Troll: Smash adds a Lightly Dazed card")
	_clear_hand("lightly_dazed")
	_despawn(e)
	var f := _spawn("ARMORED_TROLL", 3)
	_check(_chose(f) == "move", "Troll: out of reach it moves")
	_despawn(f)
	_reset_player()

# -------------------------------------------------------------- Archer Rat

func _test_archer_rat() -> void:
	print("-- Archer Rat --")
	var a := _spawn("ARCHER_RAT", 2)
	_check(_chose(a) == "scurry_away", "Archer Rat: at range 2 it scurries away")
	a._try_scurry_away(main.player)
	var d := _dist_to_player(a.intended_cell())
	_check(d == 7 or _room < 7, "Archer Rat: Scurry Away runs 5 tiles (2 -> %d)" % d)
	_despawn(a)
	for r in [3, 6]:
		var b := _spawn("ARCHER_RAT", r)
		_check(_chose(b) == "shoot", "Archer Rat: at range %d it shoots" % r)
		_check(_fire(b, "shoot") == _scaled("ARCHER_RAT", 2), "Archer Rat: a shot at range %d hits for 2 (scaled)" % r)
		_despawn(b)
	if _room >= 9:
		var c := _spawn("ARCHER_RAT", 9)
		_check(_chose(c) == "get_into_range", "Archer Rat: beyond range 6 it moves closer")
		c._try_get_into_range(main.player)
		var cd := _dist_to_player(c.intended_cell())
		_check(cd == 7, "Archer Rat: Get Into Range moves 2 tiles (9 -> %d)" % cd)
		_despawn(c)
	_reset_player()

# ------------------------------------------------------------------- Hydra

func _test_hydra() -> void:
	print("-- Hydra --")
	var h := _spawn("HYDRA", 1)
	var P := DamageTypes.Type
	_check(_resist(h, P.PHYSICAL) == 25 and _resist(h, P.FIRE) == 25 and _resist(h, P.LIGHTNING) == 25, "Hydra: resists 25% physical / fire / lightning")
	_check(_chose(h) == "hydra_attack", "Hydra: at range 1 she Strikes")
	_check(_fire(h, "hydra_attack") == h.attack_damage, "Hydra: Strike is 7 + strength (strength 0: %d)" % h.attack_damage)
	var base_max := h.max_health
	h.take_damage(4, false)   # not the player's: still a hit
	_check(h.strength == 2, "Hydra: +2 strength per hit, whoever lands it (%d)" % h.strength)
	_check(_fire(h, "hydra_attack") == h.attack_damage + 2, "Hydra: Strike adds her strength")
	h.take_damage(4, true)
	h.take_damage(4, true)
	_check(not h.hydra_heal_unlocked, "Hydra: Heal is locked before the 4th hit")
	h.take_damage(4, true)
	_check(h.max_health == base_max + 40 and h.hydra_heal_unlocked, "Hydra: the 4th hit gives +40 max HP and unlocks Heal")
	h.current_health = h.max_health / 3
	_check(_chose(h) == "hydra_heal", "Hydra: hurt with Heal unlocked, she heals")
	h._execute_action("hydra_heal", main.player)
	_check(h.current_health == h.max_health, "Hydra: Heal restores her to full")
	_despawn(h)
	var m := _spawn("HYDRA", 3)
	_check(_chose(m) == "hydra_move", "Hydra: out of reach she moves")
	_despawn(m)
	_reset_player()

# ----------------------------------------------------------------- Goblins

func _test_goblins() -> void:
	print("-- Fire Goblins --")
	var s := _spawn("FIRE_GOBLIN_SOLDIER", 1)
	_check(_chose(s) == "goblin_attack", "Goblin Soldier: adjacent it attacks")
	_check(_fire(s, "goblin_attack") == _scaled("FIRE_GOBLIN_SOLDIER", 2), "Goblin Soldier: Attack hits for 2")
	_despawn(s)
	var dm = main.player.get_debuff_manager()
	var m := _spawn("FIRE_GOBLIN_MAGE", 4)
	_check(_chose(m) == "ember", "Goblin Mage: at range 4 it casts Ember")
	var burn0 := _debuff_value(Debuff.DebuffType.BURN)
	_check(_fire(m, "ember") == _scaled("FIRE_GOBLIN_MAGE", 7), "Goblin Mage: Ember hits for 7 (scaled)")
	_check(_debuff_value(Debuff.DebuffType.BURN) == burn0 + 1, "Goblin Mage: Ember adds 1 Burn")
	_despawn(m)
	var m5 := _spawn("FIRE_GOBLIN_MAGE", 5)
	_check(_chose(m5) == "goblin_move", "Goblin Mage: beyond range 4 it moves")
	_despawn(m5)
	dm.clear_all_debuffs()
	var sh := _spawn("FIRE_GOBLIN_SHAMAN", 5)
	seed(7)
	var n := _chose(sh)
	_check(n == "fire_wall" or n == "sear_wounds", "Goblin Shaman: at range 5 it casts (%s)" % n)
	main._fire_walls.clear()
	sh._try_fire_wall(main.player)
	var wall: Dictionary = main._fire_walls[0] if main._fire_walls.size() > 0 else {}
	_check(not wall.is_empty() and int(wall["damage"]) == _scaled("FIRE_GOBLIN_SHAMAN", 6) and int(wall["burn"]) == 3, "Goblin Shaman: Fire Wall raises a wall worth 6 damage + 3 burn (%s)" % str(wall.get("damage", "-")))
	var hp0 := int(main.player.get_stats().current_health)
	burn0 = _debuff_value(Debuff.DebuffType.BURN)
	main._check_fire_walls(wall["tiles"][0] if not wall.is_empty() else Vector2i(-1, -1))
	_check(int(main.player.get_stats().current_health) < hp0 and _debuff_value(Debuff.DebuffType.BURN) == burn0 + 3, "Goblin Shaman: walking into the wall burns you (6 + 3 Burn)")
	main._fire_walls.clear()
	var ally := _spawn("ZOMBIE", 3, 2)
	var weak := _spawn("ZOMBIE", 4, 2)
	ally.current_health = 5
	weak.current_health = 2
	sh.current_health = sh.max_health
	sh._try_sear_wounds()
	_check(ally.current_health == 9, "Goblin Shaman: Sear Wounds — 2 to an ally, then heals it 6 (5 -> %d)" % ally.current_health)
	_check(weak.is_dead, "Goblin Shaman: Sear Wounds can kill")
	_despawn(ally)
	_despawn(weak)
	# Fire Wall's keywords (compendium: "8 · Channel 4 · Disruptable 8"): 4
	# tempo of wind-up, then a 4-tempo channel that 8 damage breaks.
	var shown: Array = Enemy.get_all_enemy_data()[Enemy.EnemyType.FIRE_GOBLIN_SHAMAN]["actions"][0]["keywords"]
	_check(shown == ["Channel 4", "Disruptable 8"], "Goblin Shaman: the compendium lists Fire Wall as Channel 4, Disruptable 8 (%s)" % str(shown))
	sh.chosen_action = sh._get_action("fire_wall")
	sh.action_tempo_counter = 0
	sh.on_tempo_advanced(4, main.player)
	_check(sh.is_channeling(), "Goblin Shaman: after 4 tempo of wind-up Fire Wall channels")
	sh.take_damage(8, false, DamageTypes.Type.FIRE)
	_check(not sh.is_channeling() and sh.action_tempo_counter == 0, "Goblin Shaman: 8 damage while channeling breaks the Fire Wall")
	main._fire_walls.clear()
	sh.chosen_action = sh._get_action("fire_wall")
	sh.action_tempo_counter = 0
	sh.current_health = sh.max_health
	sh.on_tempo_advanced(8, main.player)
	_check(main._fire_walls.size() == 1, "Goblin Shaman: left alone, the wall goes up at the end of tempo 8")
	main._fire_walls.clear()
	_despawn(sh)
	var sh2 := _spawn("FIRE_GOBLIN_SHAMAN", 6)
	_check(_chose(sh2) == "goblin_move", "Goblin Shaman: beyond range 5 it moves")
	_despawn(sh2)
	_reset_player()

# ------------------------------------------------------------------ Beaver

func _test_beaver() -> void:
	print("-- Giant Beaver --")
	var b := _spawn("GIANT_BEAVER", 1)
	_check(_resist(b, DamageTypes.Type.PHYSICAL) == 25, "Beaver: resists 25% physical")
	_check(_chose(b) == "chomp", "Beaver: adjacent it Chomps")
	_check(_fire(b, "chomp") == _scaled("GIANT_BEAVER", 9), "Beaver: Chomp hits for 9 (scaled)")
	var stun = main.player.get_debuff_manager().get_debuff(Debuff.DebuffType.STUN)
	_check(stun != null and stun.duration == 3, "Beaver: Chomp stuns 3 tempo")
	_check(_chose(b) == "tail_whip" and int(b.chosen_action["tempo_cost"]) == 2, "Beaver: Tail Whip follows, 2 tempo later")
	_check(_fire(b, "tail_whip") == _scaled("GIANT_BEAVER", 6), "Beaver: Tail Whip hits for 6 (scaled)")
	var vuln = main.player.get_debuff_manager().get_debuff(Debuff.DebuffType.VULNERABLE)
	_check(vuln != null and vuln.value == 5 and vuln.uses_stack_clock(), "Beaver: Tail Whip lays 5 Vulnerable stacks (5 tempo each)")
	_check(_chose(b) == "chomp", "Beaver: then back to Chomp")
	_despawn(b)
	_reset_player()

# ------------------------------------------------------------------- Bears

func _test_bears() -> void:
	print("-- Mini Bear --")
	var a := _spawn("MINI_BEAR", 1)
	var b := _spawn("MINI_BEAR", 3, 2)
	_check(_chose(a) == "mini_bear_attack", "Mini Bear: adjacent it attacks")
	_check(_fire(a, "mini_bear_attack") == _scaled("MINI_BEAR", 4), "Mini Bear: Attack hits for 4 (scaled)")
	b.take_damage(1, true)
	_check(a.pack_attack_bonus == 2, "Mini Bear: a packmate in sight hurt: +2 attack damage")
	_check(_fire(a, "mini_bear_attack") == _scaled("MINI_BEAR", 4) + 2, "Mini Bear: the bonus lands on its Attack")
	_despawn(b)
	await _settle(2)

	print("-- Large Bear --")
	var dm = main.player.get_debuff_manager()
	dm.clear_all_debuffs()
	var bear := _spawn("LARGE_BEAR", 1, 0)
	_check(_fire(bear, "maul") == _scaled("LARGE_BEAR", 12), "Large Bear: Maul hits for 12 (scaled)")
	_check(_debuff_value(Debuff.DebuffType.BLEED) == 4, "Large Bear: Maul adds 4 Bleed")
	# Mini bears present: +1 Strengthen every time it is hurt, any source.
	bear.take_damage(2, false)
	_check(bear.strengthen_stacks == 1, "Large Bear: with Mini Bears present, +1 Strengthen when hurt")
	_check(_fire(bear, "maul") == _scaled("LARGE_BEAR", 12) + 1, "Large Bear: Strengthen adds +1 damage to Maul")
	_despawn(a)
	await _settle(2)
	bear.strengthen_stacks = 0
	bear.take_damage(2, false)
	_check(bear.strengthen_stacks == 0, "Large Bear: no Mini Bears, no Strengthen")
	dm.clear_all_debuffs()
	bear.current_health = bear.max_health / 2 + 2
	bear.take_damage(5, false)
	_check(_resist(bear, DamageTypes.Type.PHYSICAL) == 30, "Large Bear: below 50% it gains 30% physical resistance")
	var raged := _fire(bear, "maul")
	_check(raged == roundi(_scaled("LARGE_BEAR", 12) * 1.5), "Large Bear: raging, attacks deal 1.5x (%d)" % raged)
	_check(_debuff_value(Debuff.DebuffType.BLEED) == 8, "Large Bear: raging, double Bleed (%d)" % _debuff_value(Debuff.DebuffType.BLEED))
	var hp := bear.current_health
	main.on_player_bled(3)
	_check(bear.current_health == hp + 3, "Large Bear: raging, it heals from your bleed damage")
	bear.current_health = bear.max_health
	_check(_resist(bear, DamageTypes.Type.PHYSICAL) == 30, "Large Bear: the resistance stays after healing above 50% (forever)")
	bear.take_damage(bear.current_health - bear.max_health / 5 + 1, false, DamageTypes.Type.FIRE)
	_check(bear._drops_to_all_fours, "Large Bear: drops to all fours below 20% HP")
	_despawn(bear)
	dm.clear_all_debuffs()
	var r := _spawn("LARGE_BEAR", 4)
	_check(_chose(r) == "roar", "Large Bear: within 4 squares, Roar is chosen")
	_check(r._roar_cooldown == 15, "Large Bear: Roar then waits 15 tempo")
	_check(_chose(r) == "move", "Large Bear: on cooldown, out of reach, it moves")
	r._try_roar(main.player)
	_check(dm.get_debuff(Debuff.DebuffType.VULNERABLE) != null, "Large Bear: Roar leaves everything within 4 squares Vulnerable")
	_despawn(r)
	dm.clear_all_debuffs()
	var far := _spawn("LARGE_BEAR", 5)
	far._try_roar(main.player)
	_check(dm.get_debuff(Debuff.DebuffType.VULNERABLE) == null, "Large Bear: Roar does not reach 5 squares")
	_despawn(far)
	_reset_player()

# ----------------------------------------------- Wolf / Coyote / Bugbear

func _test_wolf_coyote_bugbear() -> void:
	print("-- Wolf --")
	var w := _spawn("WOLF", 1)
	_check(_fire(w, "wolf_bite") == _scaled("WOLF", 7), "Wolf: alone, Bite hits for 7 (scaled)")
	w.current_health = w.max_health - 10
	w.on_tempo_advanced(5, null)
	_check(w.current_health == w.max_health - 10, "Wolf: alone, no regen")
	var w2 := _spawn("WOLF", 4)
	_check(_fire(w, "wolf_bite") == _scaled("WOLF", 7) + 2, "Wolf: within 4 tiles of another wolf, +2 damage")
	w.on_tempo_advanced(5, null)
	_check(w.current_health == w.max_health - 8, "Wolf: and +2 HP regen a cycle")
	_despawn(w2)
	_despawn(w)
	print("-- Coyote --")
	var c := _spawn("COYOTE", 1)
	_check(_chose(c) == "coyote_nip", "Coyote: adjacent it Nips")
	_check(_fire(c, "coyote_nip") == _scaled("COYOTE", 2), "Coyote: Nip hits for 2")
	_despawn(c)
	print("-- Bugbear --")
	var b := _spawn("BUGBEAR", 1)
	_check(_chose(b) == "bugbear_strike", "Bugbear: adjacent it Strikes")
	_check(_fire(b, "bugbear_strike") == _scaled("BUGBEAR", 6) + 8, "Bugbear: First Strike — +8 before you have hit it")
	b.take_damage(1, true)
	_check(_fire(b, "bugbear_strike") == _scaled("BUGBEAR", 6), "Bugbear: once you have hit it, Strike is 6 (scaled)")
	_despawn(b)
	_reset_player()

# ------------------------------------------------------------------ Hunter

func _test_hunter() -> void:
	print("-- Infected Hunter --")
	var h := _spawn("INFECTED_HUNTER", 1)
	_check(_fire(h, "cleave") == _scaled("INFECTED_HUNTER", 8), "Hunter: Cleave hits for 8 (scaled)")
	_despawn(h)
	for r in [2, 7]:
		var f := _spawn("INFECTED_HUNTER", r)
		f._net_cooldown = 8
		_check(_chose(f) == "hook", "Hunter: Hook reaches range %d" % r)
		_despawn(f)
	if _room >= 8:
		var g := _spawn("INFECTED_HUNTER", 8)
		g._net_cooldown = 8
		_check(_chose(g) == "move", "Hunter: no Hook beyond range 7")
		_despawn(g)
	var n := _spawn("INFECTED_HUNTER", 3)
	n._hook_recharge = 8
	_check(_chose(n) == "net_throw", "Hunter: Net Throw within 3 squares")
	_despawn(n)
	var n4 := _spawn("INFECTED_HUNTER", 4)
	n4._hook_recharge = 8
	_check(_chose(n4) == "move", "Hunter: no Net Throw at 4 squares")
	_despawn(n4)
	_reset_player()

# -------------------------------------------------------------------- Hawk

func _test_hawk() -> void:
	print("-- Giant Hawk --")
	var h := _spawn("GIANT_HAWK", 2)
	_check(h.immune_to_high_ground, "Hawk: flying — ignores your high-ground bonus")
	_check(not main._has_high_ground(main.player.position, h), "Hawk: the high-ground check never favours you against it")
	_check(_chose(h) == "swoop", "Hawk: Swoop reaches 2")
	_check(_fire(h, "swoop") == _scaled("GIANT_HAWK", 9), "Hawk: Swoop hits for 9 (scaled)")
	_check(is_equal_approx(h.attack_blind_chance, 0.2), "Hawk: 20% chance to Blind")
	h.attack_blind_chance = 1.0
	main.player.get_debuff_manager().clear_all_debuffs()
	_fire(h, "swoop")
	var bl = main.player.get_debuff_manager().get_debuff(Debuff.DebuffType.BLIND)
	_check(bl != null and bl.value == 1, "Hawk: the Blind is 1 stack (5 tempo)")
	_despawn(h)
	var f := _spawn("GIANT_HAWK", 3)
	_check(_chose(f) == "move", "Hawk: at 3 squares it moves")
	_despawn(f)
	_reset_player()

# ------------------------------------------------------------------ Treant

func _test_treant() -> void:
	print("-- Treant --")
	var t := _spawn("TREANT", 1)
	var P := DamageTypes.Type
	_check(_resist(t, P.PHYSICAL) == 25 and _resist(t, P.LIGHTNING) == 55 and _resist(t, P.FIRE) == -10, "Treant: 25% physical / 55% lightning, 10% extra fire")
	_check(t.damage_type == P.EARTH, "Treant: its damage is earth")
	_check(_fire(t, "treant_slam") == _scaled("TREANT", 14), "Treant: Slam hits for 14 (scaled)")
	_fire(t, "root")
	var root = main.player.get_debuff_manager().get_debuff(Debuff.DebuffType.ROOTED)
	_check(root != null and root.duration == 8, "Treant: Root pins you for 8 tempo")
	t.current_health = roundi(t.max_health * 0.7)
	var hp := t.current_health
	t.on_tempo_advanced(5, null)
	_check(t.current_health == hp + 5, "Treant: heals 5 HP every 5 tempo above 60%")
	t.current_health = roundi(t.max_health * 0.39)
	hp = t.current_health
	t.on_tempo_advanced(5, null)
	_check(t.current_health == hp + 9, "Treant: +2 per 10%% below 60%% (39%%: 5 + 4 = %d)" % (t.current_health - hp))
	var bm = main.player.get_buff_manager()
	bm.apply_buff(Buff.create_thorns(7))
	t.current_health = roundi(t.max_health * 0.7)
	hp = t.current_health
	t._treant_thorn_accumulator = 0
	t.regen_accumulator = 0
	t.on_tempo_advanced(10, null)
	_check(bm.get_buff(Buff.BuffType.THORNS) == null, "Treant: every 10 tempo it strips your thorns")
	_check(t.current_health == hp + 7 + 10, "Treant: and heals for the total (7 thorns + 2 regen ticks)")
	_despawn(t)
	var r := _spawn("TREANT", 3)
	_check(_chose(r) == "root", "Treant: out of melee, within 4, it Roots")
	r.current_health = r.max_health / 3
	_check(_chose(r) == "treant_heal", "Treant: badly hurt and out of melee it stops to mend")
	_despawn(r)
	_reset_player()

# ------------------------------------------------------------------- Mages

func _test_mages() -> void:
	print("-- Mages --")
	var P := DamageTypes.Type
	var dm = main.player.get_debuff_manager()
	var specs := [
		["ICE_MAGE", "frost_bolt", 6, P.ICE],
		["FIRE_MAGE", "fire_bolt", 7, P.FIRE],
		["SPARK_MAGE", "spark_bolt", 3, P.LIGHTNING],
		["AIR_MAGE", "gust", 5, P.WIND],
		["EARTH_MAGE", "boulder", 9, P.EARTH],
	]
	for s in specs:
		var k: String = s[0]
		dm.clear_all_debuffs()
		var r := int(RANGES.get(k, 1))
		if r > _room:
			continue
		var m := _spawn(k, r)
		m._totem_cooldown = 999   # the totem is test_totems' business
		_check(_chose(m) == s[1], "%s: at its range (%d) it casts %s" % [k, r, s[1]])
		_check(m.damage_type == s[3], "%s: its damage type is right" % k)
		_check(_fire(m, s[1]) == _scaled(k, s[2]), "%s: %s hits for %d (scaled)" % [k, s[1], s[2]])
		_check(m._get_action("raise_totem").get("tempo_cost", 0) == 6, "%s: Raise Totem is 6 tempo" % k)
		_despawn(m)
		if r + 1 <= _room:
			var f := _spawn(k, r + 1)
			f._totem_cooldown = 999
			_check(_chose(f) == "move", "%s: beyond its range it moves" % k)
			_despawn(f)
	dm.clear_all_debuffs()
	var ice := _spawn("ICE_MAGE", 3)
	_fire(ice, "frost_bolt")
	_check(dm.get_debuff(Debuff.DebuffType.SLOWED) != null, "Ice Mage: Frost Bolt Slows")
	_despawn(ice)
	dm.clear_all_debuffs()
	var fire := _spawn("FIRE_MAGE", 2)
	_fire(fire, "fire_bolt")
	_check(_debuff_value(Debuff.DebuffType.BURN) == 2, "Fire Mage: Fire Bolt adds 2 Burn")
	_despawn(fire)
	dm.clear_all_debuffs()
	var spark := _spawn("SPARK_MAGE", 6)
	_fire(spark, "spark_bolt")
	var sh = dm.get_debuff(Debuff.DebuffType.SHOCKED)
	_check(sh != null and sh.value == 1, "Spark Mage: Spark adds 1 Shock")
	_despawn(spark)
	var earth := _spawn("EARTH_MAGE", 1)
	var arm := earth.current_armor
	earth.take_damage(3, true)
	_check(earth.current_armor == arm + 4, "Earth Mage: gains 4 armor every time it is hit")
	_despawn(earth)
	_reset_player()

# ------------------------------------------------------------------ Zombie

func _test_zombie() -> void:
	print("-- Zombie --")
	var z := _spawn("ZOMBIE", 1)
	_check(_chose(z) == "attack", "Zombie: at range 1 it attacks")
	_check(_fire(z, "attack") == _scaled("ZOMBIE", 5), "Zombie: Attack hits for 5 (scaled)")
	_despawn(z)
	if _room >= 6:
		var w := _spawn("ZOMBIE", 6)
		_check(_chose(w) == "move", "Zombie: otherwise it shambles toward you")
		w._try_move(main.player)
		_check(_dist_to_player(w.intended_cell()) == 3, "Zombie: 3 spaces a shamble")
		_despawn(w)
	_reset_player()

# ---------------------------------------------------------------- Werewolf

func _test_werewolf() -> void:
	print("-- Werewolf --")
	var w := _spawn("WEREWOLF", 1)
	var P := DamageTypes.Type
	_check(_resist(w, P.PHYSICAL) == 25 and _resist(w, P.FIRE) == 25 and _resist(w, P.LIGHTNING) == 25, "Werewolf: resists 25% physical/fire/lightning")
	_check(_chose(w) == "werewolf_claw" and int(w.chosen_action["tempo_cost"]) == 5, "Werewolf: the first Claw arms in 5")
	_check(_fire(w, "werewolf_claw") == _scaled("WEREWOLF", 10), "Werewolf: Claw hits for 10 (scaled)")
	_check(_chose(w) == "werewolf_claw" and int(w.chosen_action["tempo_cost"]) == 4, "Werewolf: the next on the same target arms in 4")
	_fire(w, "werewolf_claw")
	_check(int(w.chosen_action.get("tempo_cost", 0)) == 4 and _chose(w) == "werewolf_claw" and int(w.chosen_action["tempo_cost"]) == 3, "Werewolf: then 3")
	main.player.get_stats().current_armor = 20
	_check(_fire(w, "werewolf_claw") == _scaled("WEREWOLF", 10) + 3, "Werewolf: +3 vs armor")
	main.player.get_stats().current_armor = 0
	main.player.get_debuff_manager().apply_debuff(Debuff.create(Debuff.DebuffType.BLEED, 1, 15))
	var raked := _fire(w, "werewolf_claw")
	_check(raked == _scaled("WEREWOLF", 10) + _scaled("WEREWOLF", 10) / 2 and _hits.size() == 2, "Werewolf: a debuffed target is raked a second time for half (%d)" % raked)
	_despawn(w)
	_reset_player()

# ----------------------------------------------------------- Treasure Bunny

func _test_bunny() -> void:
	print("-- Treasure Bunny --")
	var b := _spawn("TREASURE_BUNNY", 2)
	var names: Array = []
	for a in b.actions:
		names.append(str(a["name"]))
	_check(names == ["flee", "vanish"] and b.attack_damage == 0, "Bunny: never attacks (flee, vanish only)")
	_check(_chose(b) == "flee", "Bunny: it flees at first")
	b._try_flee(main.player)
	_check(_dist_to_player(b.intended_cell()) == 4 or _room < 4, "Bunny: a flee runs 2 spaces away (2 -> %d)" % _dist_to_player(b.intended_cell()))
	b.on_tempo_advanced(14, null)
	_check(_chose(b) == "flee", "Bunny: still fleeing at 14 tempo")
	b.on_tempo_advanced(1, null)
	_check(_chose(b) == "vanish", "Bunny: after 3 cycles (15 tempo) it vanishes")
	_despawn(b)
	_reset_player()

# ------------------------------------------------------------------ Vampire

func _test_vampire() -> void:
	print("-- Vampire --")
	var v := _spawn("VAMPIRE", 1)
	var P := DamageTypes.Type
	_check(_resist(v, P.PHYSICAL) == 10 and _resist(v, P.FIRE) == 10 and _resist(v, P.LIGHTNING) == 10, "Vampire: resists 10% physical/fire/lightning")
	v.current_health = v.max_health - 30
	_check(_fire(v, "vampire_bite") == _scaled("VAMPIRE", 10), "Vampire: Bite hits for 10 (scaled)")
	_check(v.current_health == v.max_health - 30 + _scaled("VAMPIRE", 10), "Vampire: Bite heals 100% of the health damage")
	main.player.get_stats().current_armor = 100
	var hp := v.current_health
	_fire(v, "vampire_bite")
	_check(v.current_health == hp, "Vampire: a bite into armor heals nothing")
	main.player.get_stats().current_armor = 0
	v.current_health = v.max_health / 2 + 1
	v.take_damage(3, true)
	_check(v._bat_form_charges == 1 and v._vamp_absorb_pending, "Vampire: below 50% — Bat Form (a charge spent), Absorb next")
	_check(_chose(v) == "absorb", "Vampire: Absorb always follows Bat Form")
	var first := _fire(v, "absorb")
	_check(first == _scaled("VAMPIRE", 20), "Vampire: the first Absorb drains 20 (scaled %d)" % first)
	v.current_health = v.max_health / 2 + 1
	v.take_damage(3, true)
	_check(v._bat_form_charges == 0, "Vampire: the second Bat Form spends the last charge")
	_check(_fire(v, "absorb") == _scaled("VAMPIRE", 10), "Vampire: the second Absorb drains 10")
	v.take_damage(3, true)
	_check(v._bat_form_charges == 0 and not v._vamp_absorb_pending, "Vampire: no charges back — no third Bat Form")
	_despawn(v)
	_reset_player()

# -------------------------------------------------------------- Necromancer

func _test_necromancer() -> void:
	print("-- Necromancer --")
	var n := _spawn("NECROMANCER", 3)
	var P := DamageTypes.Type
	_check(_resist(n, P.FIRE) == 15 and _resist(n, P.LIGHTNING) == 15 and _resist(n, P.PHYSICAL) == 0, "Necromancer: resists 15% fire/lightning")
	_check(_fire(n, "dark_bolt") == _scaled("NECROMANCER", 4), "Necromancer: Bolt hits for 4")
	var hexes := 0
	var ok := true
	for d in main.player.get_debuff_manager().debuffs:
		if d.debuff_type == Debuff.DebuffType.HEXED:
			hexes += 1
			ok = ok and d.value == 30 and d.duration == 25
	_check(hexes == 2 and ok, "Necromancer: Bolt Hexes 2 cards (+30 mana, up to 25 tempo)")
	var before: int = main.enemy_spawner.get_living_enemies().size()
	n._try_necro_summon(main.player)
	var after: Array = main.enemy_spawner.get_living_enemies()
	var raised = null
	for e in after:
		if e.get("raised_by") == n:
			raised = e
	_check(after.size() == before + 1 and raised != null and raised.enemy_type in [Enemy.EnemyType.SKELETON, Enemy.EnemyType.ZOMBIE], "Necromancer: Summon raises a skeleton or zombie")
	_despawn(raised)
	_despawn(n)
	_reset_player()

# -------------------------------------------------------------- Bone Dragon

func _test_bone_dragon() -> void:
	print("-- Bone Dragon --")
	var d := _spawn("BONE_DRAGON", 1)
	var P := DamageTypes.Type
	_check(_resist(d, P.PHYSICAL) == 45 and _resist(d, P.FIRE) == 45, "Bone Dragon: resists 45% physical / 45% fire")
	_check(_fire(d, "dragon_bite") == _scaled("BONE_DRAGON", 12), "Bone Dragon: Bite hits for 12 (scaled)")
	d.gravestone_provider = func() -> int: return 3
	d.current_health = d.max_health - 20
	d.regen_accumulator = 0
	d.on_tempo_advanced(5, null)
	_check(d.current_health == d.max_health - 17, "Bone Dragon: 1 health a cycle per standing gravestone (3 stones)")
	_despawn(d)
	var b := _spawn("BONE_DRAGON", 4)
	_check(_chose(b) == "breath_swarm", "Bone Dragon: within 6 squares it breathes")
	var swarms0 := 0
	for e in main.enemy_spawner.get_living_enemies():
		if e.enemy_type == Enemy.EnemyType.SWARM:
			swarms0 += 1
	_check(_fire(b, "breath_swarm") == _scaled("BONE_DRAGON", 12), "Bone Dragon: Breath Swarm hits for 12 down the line")
	var swarms: Array = []
	for e in main.enemy_spawner.get_living_enemies():
		if e.enemy_type == Enemy.EnemyType.SWARM:
			swarms.append(e)
	_check(swarms.size() == swarms0 + 1, "Bone Dragon: a Swarm hatches beside the one it hit")
	for s in swarms:
		_despawn(s)
	_despawn(b)
	_reset_player()

# --------------------------------------------------------- Spirit Collector

func _test_collector() -> void:
	print("-- Spirit Collector --")
	var c := _spawn("SPIRIT_COLLECTOR", 1)
	_check(_fire(c, "collector_swing") == _scaled("SPIRIT_COLLECTOR", 8), "Collector: Strike hits for 8 (scaled)")
	c.strengthen_stacks = 5
	_check(_fire(c, "collector_swing") == _scaled("SPIRIT_COLLECTOR", 8) + 5, "Collector: Strengthen adds to Strike")
	_clear_hand("release_soul")
	_check(_fire(c, "collect_soul") == _scaled("SPIRIT_COLLECTOR", 8) + 5, "Collector: Strengthen adds to Collect Soul too")
	c.on_tempo_advanced(30, null)
	_check(c.strengthen_stacks == 5, "Collector: its Strengthen never fades")
	_despawn(c)
	_clear_hand("release_soul")
	var f := _spawn("SPIRIT_COLLECTOR", 4)
	_check(_chose(f) == "collect_soul", "Collector: Collect Soul reaches 4 while you hold fewer than 2 souls")
	_despawn(f)
	if _room >= 5:
		var g := _spawn("SPIRIT_COLLECTOR", 5)
		_check(_chose(g) == "move", "Collector: not at 5")
		_despawn(g)
	main.player.get_debuff_manager().clear_all_debuffs()
	_reset_player()

# --------------------------------------------------------------- Grave Titan

func _test_titan() -> void:
	print("-- Grave Titan --")
	var t := _spawn("GRAVE_TITAN", 1)
	_check(t.max_armor == roundi(30 * Enemy.passive_power_scale(12)["hp"]), "Titan: 30 armor (scaled %d)" % t.max_armor)
	_check(_chose(t) == "titan_smash", "Titan: adjacent it Smashes")
	_check(_fire(t, "titan_smash") == _scaled("GRAVE_TITAN", 15), "Titan: Smash hits for 15 (scaled)")
	_despawn(t)
	var b := _spawn("GRAVE_TITAN", 3)
	_check(_chose(b) == "boulder_roll", "Titan: Boulder Roll at range 3")
	_check(_fire(b, "boulder_roll") == _scaled("GRAVE_TITAN", 15), "Titan: Boulder Roll hits for 15 (scaled)")
	_despawn(b)
	var m := _spawn("GRAVE_TITAN", 4)
	_check(_chose(m) == "move", "Titan: at 4 it walks")
	_despawn(m)
	_reset_player()

# ------------------------------------------------------------- Crypt Crawler

func _test_crawler() -> void:
	print("-- Crypt Crawler --")
	_clear_hand("paralysis")
	var c := _spawn("CRYPT_CRAWLER", 1)
	_check(_chose(c) == "crawler_bite", "Crawler: adjacent it bites")
	for i in range(3):
		_check(_fire(c, "crawler_bite") == _scaled("CRYPT_CRAWLER", 6), "Crawler: Bite %d hits for 6" % (i + 1))
	_check(_chose(c) == "web", "Crawler: after 3 consecutive attacks it webs you")
	c._execute_action("web", main.player)
	_check(_hand_count("paralysis") == 1, "Crawler: Web adds a Paralysis card")
	var card: Card = Card.create_by_id("paralysis")
	_check(card.mana_cost == 10 and card.tempo_cost == 5, "Crawler: Paralysis costs 10 mana / 5 tempo")
	_clear_hand("paralysis")
	_despawn(c)
	var w := _spawn("CRYPT_CRAWLER", 4)
	_check(_chose(w) == "web", "Crawler: it throws the web from 4 squares")
	_despawn(w)
	_reset_player()

# ----------------------------------------------------------------- Screecher

func _test_screecher() -> void:
	print("-- Screecher --")
	var s := _spawn("SCREECHER", 1)
	_check(s.is_hidden(), "Screecher: invisible until it strikes")
	PlayerStats.hit_source_direct = true
	var hp := s.current_health
	s.take_damage(5, true)
	_check(s.current_health == hp, "Screecher: unseen, your direct attack finds nothing")
	PlayerStats.hit_source_direct = false
	s.take_damage(2, false)
	_check(s.current_health == hp - 2, "Screecher: poison/burn ticks still land")
	_check(int(s.move_distance) == 4 and s._effective_cost(s._get_action("move")) == 2, "Screecher: unseen it drifts 4 spaces for 2 tempo")
	_check(_chose(s) == "screech", "Screecher: adjacent it screeches")
	_check(_fire(s, "screech") == _scaled("SCREECHER", 5), "Screecher: Screech hits for 5")
	_check(not s.is_hidden(), "Screecher: seen once it strikes")
	_check(int(s.move_distance) == 2 and s._effective_cost(s._get_action("move")) == 5, "Screecher: while seen, 2 spaces for 5 tempo")
	s.on_tempo_advanced(2, null)
	_check(not s.is_hidden(), "Screecher: still seen after 2 tempo")
	s.on_tempo_advanced(1, null)
	_check(s.is_hidden() and int(s.move_distance) == 4, "Screecher: hidden again after 3 tempo")
	_despawn(s)
	_reset_player()

# ------------------------------------------------------------------ Consumed

func _test_consumed() -> void:
	print("-- The Consumed --")
	var c := _spawn("CONSUMED", 1)
	_check(_chose(c) == "attack", "Consumed: adjacent it attacks")
	_check(_fire(c, "attack") == _scaled("CONSUMED", 8), "Consumed: Attack hits for 8 (scaled)")
	var ccell: Vector2i = main.grid_manager.world_to_grid(c.position)
	var ally := _spawn("ZOMBIE", 1, 1)   # beside the Consumed
	ally.max_health = 50
	ally.current_health = 50
	var pet := Bystander.new()
	pet.position = main._ground_pos(ccell + _dir)
	main.add_child(pet)
	main.enemy_spawner.summons = [pet]
	var far := Bystander.new()
	far.position = main._ground_pos(ccell + _dir * 4)
	main.add_child(far)
	main.enemy_spawner.summons = [pet, far]
	_hits.clear()
	c.take_damage(c.current_health + c.current_armor + 5, true)
	_check(c.is_dead, "Consumed: dies")
	var on_player := false
	for h in _hits:
		if h[0] == "Death Burst" and h[2] == main.player and int(h[1]) == _scaled("CONSUMED", 8):
			on_player = true
	_check(on_player, "Consumed: on death it explodes on the player beside it (8)")
	_check(ally.current_health == 42, "Consumed: and on an enemy beside it (8)")
	_check(pet.hits == 1 and pet.last_damage == _scaled("CONSUMED", 8), "Consumed: and on a summon beside it — everything nearby")
	_check(far.hits == 0, "Consumed: not on a unit 4 squares off")
	main.enemy_spawner.summons = []
	pet.queue_free()
	far.queue_free()
	_despawn(ally)
	_despawn(c)
	_reset_player()

# ------------------------------------------------------------------- Sludge

func _test_sludge() -> void:
	print("-- Sludge --")
	var s := _spawn("SLUDGE", 1)
	_check(_chose(s) == "sludge_melee", "Sludge: adjacent it uses Melee")
	_check(_fire(s, "sludge_melee") == _scaled("SLUDGE", 3), "Sludge: Melee hits for 3")
	_despawn(s)
	var p := _spawn("SLUDGE", 6)
	_check(_chose(p) == "sludge_spit", "Sludge: at range 6 it Spits")
	_check(_fire(p, "sludge_spit") == _scaled("SLUDGE", 3), "Sludge: Spit hits for 3")
	_despawn(p)
	if _room >= 7:
		var m := _spawn("SLUDGE", 7)
		_check(_chose(m) == "move", "Sludge: beyond 6 it moves")
		_despawn(m)
	_reset_player()
