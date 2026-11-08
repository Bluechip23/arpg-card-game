extends SceneTree

## Phase 2 wiring audit, slice enemies_b (docs/audit/wiring/enemies_b.md):
## each enemy's compendium text (Enemy.get_all_enemy_data `_specials` and
## `_actions`) and each summon's card / item text, checked against what the
## code does, in a booted main.tscn (the dojo). Only what no existing test
## already asserts is checked here; the report names the existing tests for
## the rest.
## Run: godot --headless --path . --script tests/test_wiring_enemies_b.gd

var failures: int = 0
var main = null
var gm = null
var P := Vector2i(9, 7)   # where the player stands for every check

## A player-side unit with no stats pipeline: counts the hits it takes and
## carries a debuff manager, as a summon does.
class Bystander extends Node3D:
	var is_dead: bool = false
	var hits: int = 0
	var last_damage: int = 0
	var dm: DebuffManager = null
	func take_damage(amount: int, _from_status := false) -> void:
		hits += 1
		last_damage = amount
	func get_debuff_manager() -> DebuffManager:
		if dm == null:
			dm = DebuffManager.new()
			add_child(dm)
			dm.initialize(null, self)
		return dm

const MY_TYPES := ["PIPE_CRAWLER", "SEWER_CROC", "RAT_KING", "SWARM", "WEREGOAT", "WYVERN", "ROC",
	"ICE_TROLL", "SNOW_WRAITH", "GRANITE_COLOSSUS", "WHITE_MANTICORE", "SABERTOOTH", "CERBERUS",
	"SUCCUBUS", "DEMON", "IFRIT", "MIND_EATER", "SPECTER", "MAGMA_SPIDER", "PIT_FIEND", "ASH_HARPY",
	"INFLAMED_MINOTAUR", "CHERUB", "DJINN", "CORRUPTED_ARCHANGEL", "RING_WRAITH", "DUMMY", "RAT_NEST",
	"GRAVESTONE", "GRAVE_DIGGER", "HELL_DOOR", "THANATOS", "AIR_TOTEM", "EARTH_TOTEM",
	"LIGHTNING_TOTEM", "FIRE_TOTEM", "ICE_TOTEM"]

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	_test_compendium_tables()
	await _boot()
	if main == null:
		print("=== %d failure(s) ===" % failures)
		quit(1)
		return
	await _clear_field()
	_test_pipe_crawler()
	_test_swarm()
	await _test_wyvern()
	_test_ice_troll()
	_test_snow_wraith()
	_test_granite_colossus()
	_test_sabertooth()
	_test_cerberus_swipe()
	_test_succubus_snap()
	_test_demon()
	await _test_ifrit()
	_test_mind_eater()
	_test_specter_spit()
	_test_minotaur()
	_test_djinn()
	_test_ring_wraith()
	_test_dummy()
	await _test_thanatos()
	_test_totems()
	_test_mockups()
	await _clear_field()
	await _test_wolves()
	await _test_bone_skeleton()
	await _test_spirit_bows()
	await _test_clone()
	await _test_specter_summon()
	await _test_worms()
	await _test_frankenstein()
	await _test_penguin()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

# ------------------------------------------------------------------ helpers

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
	gm = main.grid_manager
	_place_player(P)
	_reset_hp()

func _clear_field() -> void:
	for e in main.enemy_spawner.get_living_enemies():
		main.enemy_spawner.despawn_enemy(e)
	for arr in [main._wolves, main._skeletons, main._spirit_bows, main._clones, main._specters, main._summoned_worms, main._frankensteins]:
		for s in arr:
			if is_instance_valid(s):
				s.queue_free()
		arr.clear()
	if main._penguin and is_instance_valid(main._penguin):
		main._penguin.queue_free()
	main._penguin = null
	main.enemy_spawner.summons = []
	await _settle(2)

func _place_player(cell: Vector2i) -> void:
	main.player.position = main._ground_pos(cell)
	main.player.target_position = main.player.position
	if "is_moving" in main.player:
		main.player.is_moving = false

func _spawn(type: int, offset: Vector2i) -> Enemy:
	var e: Enemy = main.enemy_spawner.spawn_enemy(type, main._ground_pos(P + offset))
	e.chosen_action = {}
	return e

func _despawn(e: Enemy) -> void:
	if e and is_instance_valid(e):
		main.enemy_spawner.despawn_enemy(e)

func _stats():
	return main.player.get_stats()

func _pdm():
	return main.player.get_debuff_manager()

func _hp() -> int:
	return int(_stats().current_health)

func _reset_hp() -> void:
	var st = _stats()
	st.max_health = 5000
	st.current_health = 5000
	st.current_armor = 0
	_pdm().clear_all_debuffs()
	_place_player(P)

func _cell(n: Node3D) -> Vector2i:
	return gm.world_to_grid(n.position)

func _bystander(offset: Vector2i) -> Bystander:
	var b := Bystander.new()
	b.position = main._ground_pos(P + offset)
	main.add_child(b)
	return b

func _set_cell(s: Node3D, cell: Vector2i) -> void:
	s.position = main._ground_pos(cell)
	s.position.y = 0.0
	if "_target_position" in s:
		s._target_position = s.position
		s._is_moving = false

# ------------------------------------------------------ compendium vs tables

func _test_compendium_tables() -> void:
	print("-- Compendium text vs the action tables and EnemyDefs --")
	var by_name := {}
	for d in Enemy.get_all_enemy_data():
		by_name[d["name"]] = d
	var move_re := RegEx.new()
	move_re.compile("Move(?: away)? \\((\\d+) tempo\\): (\\d+) space")
	var res_re := RegEx.new()
	res_re.compile("[Rr]esists (\\d+)% physical ?/ ?(\\d+)% fire ?/ ?(\\d+)% lightning")
	var res_same_re := RegEx.new()
	res_same_re.compile("[Rr]esists (\\d+)% physical/fire/lightning")
	for key in MY_TYPES:
		var t: int = Enemy.EnemyType[key]
		var def: Dictionary = EnemyDefs.DEFS[key]
		var d: Dictionary = by_name.get(def["name"], {})
		_check(not d.is_empty(), "%s: in the compendium" % key)
		if d.is_empty():
			continue
		var real: Array = Enemy.actions_for_type(t)
		var shown: Array = d["actions"]
		_check(shown.size() == real.size(), "%s: compendium lists %d actions, the table has %d" % [key, shown.size(), real.size()])
		var tempo_ok := true
		for i in range(mini(shown.size(), real.size())):
			if int(shown[i]["tempo"]) != int(real[i]["tempo_cost"]):
				tempo_ok = false
		_check(tempo_ok, "%s: every compendium tempo matches its action's tempo_cost" % key)
		var text: String = str(d["special"])
		var m := move_re.search(text)
		if m:
			var move_cost := -1
			for a in real:
				if Enemy.MOVEMENT_ACTIONS.has(str(a["name"])) or str(a["name"]) == "move":
					move_cost = int(a["tempo_cost"])
					break
			# The Colossus' Move line is flagged (its table is empty): skip the tempo half.
			if key != "GRANITE_COLOSSUS":
				_check(move_cost == int(m.get_string(1)), "%s: Move costs %s tempo (table %d)" % [key, m.get_string(1), move_cost])
			_check(int(def.get("move", 0.0)) == int(m.get_string(2)), "%s: Move covers %s spaces (defs %d)" % [key, m.get_string(2), int(def.get("move", 0.0))])
		var r := res_re.search(text)
		var resists: Array = def.get("resists", [0, 0, 0])
		if r:
			_check(resists == [int(r.get_string(1)), int(r.get_string(2)), int(r.get_string(3))], "%s: resists %s as the text says" % [key, str(resists)])
		var rs := res_same_re.search(text)
		if rs:
			var v := int(rs.get_string(1))
			_check(resists == [v, v, v], "%s: resists %d%% physical/fire/lightning (%s)" % [key, v, str(resists)])
		if text.begins_with("Flying") or "Flying:" in text:
			_check(bool(def.get("immune_to_high_ground", false)), "%s: Flying, so immune to the high-ground bonus" % key)
		if "Grants no XP" in text or "grants no XP" in text:
			_check(int(def.get("xp", -1)) == 0, "%s: grants no XP" % key)
	# Base numbers the text quotes directly (armor, range, the main hit).
	var quoted := {
		"PIPE_CRAWLER": {"damage": 5}, "SEWER_CROC": {"armor": 20, "damage": 12},
		"RAT_KING": {"armor": 10, "damage": 6}, "SWARM": {"damage": 3}, "WEREGOAT": {"damage": 6},
		"WYVERN": {"damage": 25}, "ROC": {"armor": 15, "damage": 8}, "ICE_TROLL": {"damage": 13},
		"SNOW_WRAITH": {"damage": 5, "range": 5}, "WHITE_MANTICORE": {"damage": 15},
		"CERBERUS": {"damage": 25}, "SUCCUBUS": {"armor": 5, "range": 4}, "DEMON": {"damage": 8},
		"IFRIT": {"damage": 45}, "MIND_EATER": {"range": 6, "move": 0}, "SPECTER": {"damage": 2, "range": 2},
		"MAGMA_SPIDER": {"move": 0}, "ASH_HARPY": {"damage": 3}, "INFLAMED_MINOTAUR": {"damage": 35},
		"CHERUB": {"armor": 5, "damage": 2, "range": 4}, "DJINN": {"damage": 35, "range": 5},
		"RING_WRAITH": {"damage": 15}, "THANATOS": {"damage": 25},
		"GRANITE_COLOSSUS": {"health": 350, "armor": 250}, "HELL_DOOR": {"health": 150},
		"GRAVESTONE": {"health": 10}, "RAT_NEST": {"health": 15}, "GRAVE_DIGGER": {"health": 20},
	}
	for key in quoted:
		var def: Dictionary = EnemyDefs.DEFS[key]
		for f in quoted[key]:
			var got = def.get(f, 0)
			_check(int(got) == int(quoted[key][f]), "%s: %s %d as the text quotes (defs %s)" % [key, f, quoted[key][f], str(got)])
	_check(Enemy.FIRE_WEB_RANGE == 3, "Magma Spider: Fire Web range 3")
	_check(Enemy.WYVERN_TALON_RANGE == 3, "Wyvern: Talon Grab reach 3")
	_check(Enemy.IFRIT_BREATH_RANGE == 4, "Ifrit: Fire Breath used from up to 4 tiles out")
	_check(Enemy.THANATOS_BOLT_RANGE == 6 and Enemy.THANATOS_REAP_BLEED == 6 and Enemy.THANATOS_SERVANTS == 2, "Thanatos: bolt reach 6, Reap 6 Bleed, two servants at most")
	for key in ["RAT_NEST", "GRAVESTONE", "HELL_DOOR", "AIR_TOTEM", "EARTH_TOTEM", "LIGHTNING_TOTEM", "FIRE_TOTEM", "ICE_TOTEM"]:
		_check(bool(EnemyDefs.DEFS[key].get("is_structure", false)) and float(EnemyDefs.DEFS[key].get("move", 1.0)) == 0.0,
			"%s: a structure that holds its square" % key)

# --------------------------------------------------------------- the enemies

func _test_pipe_crawler() -> void:
	print("-- Pipe Crawler --")
	_reset_hp()
	var e := _spawn(Enemy.EnemyType.PIPE_CRAWLER, Vector2i(1, 0))
	seed(4242)
	var disarms := 0
	var dmg_ok := true
	var dur_ok := true
	for i in range(200):
		_pdm().clear_all_debuffs()
		var hp0 := _hp()
		e._try_pipe_claw(main.player)
		if hp0 - _hp() != e.attack_damage:
			dmg_ok = false
		var d = _pdm().get_debuff(Debuff.DebuffType.DISARM)
		if d != null:
			disarms += 1
			if d.duration != 5:
				dur_ok = false
	_check(dmg_ok, "Pipe Crawler: Claw deals its %d damage" % e.attack_damage)
	_check(disarms >= 30 and disarms <= 70, "Pipe Crawler: about 25%% of claws disarm (%d of 200)" % disarms)
	_check(dur_ok and disarms > 0, "Pipe Crawler: the disarm lasts 5 tempo")
	_despawn(e)

func _test_swarm() -> void:
	print("-- Swarm --")
	_reset_hp()
	var e := _spawn(Enemy.EnemyType.SWARM, Vector2i(1, 0))
	_check(int(e.move_distance) == 8 and int(e._get_action("move")["tempo_cost"]) == 3, "Swarm: Move is 8 spaces for 3 tempo")
	e._choose_action(main.player)
	_check(str(e.chosen_action.get("name", "")) == "attack", "Swarm: beside its prey it attacks")
	var hp0 := _hp()
	e._try_attack(main.player)
	_check(hp0 - _hp() == e.attack_damage and e.attack_damage == 3, "Swarm: Attack deals 3 (%d)" % (hp0 - _hp()))
	_despawn(e)

func _test_wyvern() -> void:
	print("-- Wyvern --")
	_reset_hp()
	var w := _spawn(Enemy.EnemyType.WYVERN, Vector2i(3, 0))
	_check(w.immune_to_high_ground, "Wyvern: flies (ignores the high-ground bonus)")
	w._choose_wyvern_action(3)
	_check(str(w.chosen_action.get("name", "")) == "talon_grab", "Wyvern: 3 squares off, Talon Grab")
	var landed_ok := true
	var far_ok := true
	var dmg_ok := true
	var expect := maxi(1, roundi(25 * w._pps_dmg))
	for i in range(12):
		_place_player(P)
		w._talon_cooldown = 0
		var hp0 := _hp()
		w._try_talon_grab(main.player)
		if hp0 - _hp() != expect:
			dmg_ok = false
		var dest: Vector2i = gm.world_to_grid(main.player.target_position)
		if not main.dungeon_manager.is_floor(dest) or dest.x < 0 or dest.y < 0 or dest.x >= gm.grid_width or dest.y >= gm.grid_height:
			landed_ok = false
		var d: float = Vector2(dest - P).length()
		if d > 8.6 or d < 1.0:
			far_ok = false
	_check(dmg_ok, "Wyvern: Talon Grab deals 25 (band-scaled %d)" % expect)
	_check(landed_ok, "Wyvern: the prey is dragged onto open floor, never off the map")
	_check(far_ok, "Wyvern: …up to 8 squares away")
	_check(w._talon_cooldown == 10, "Wyvern: then a 2-cycle (10 tempo) cooldown")
	_place_player(P)
	_set_enemy_cell(w, P + Vector2i(1, 0))
	w._choose_wyvern_action(1)
	_check(str(w.chosen_action.get("name", "")) == "wyvern_bite", "Wyvern: on cooldown, beside its prey, it bites")
	var hp1 := _hp()
	w._execute_action("wyvern_bite", main.player)
	_check(hp1 - _hp() == w.attack_damage, "Wyvern: Bite deals its 25 (band-scaled %d)" % w.attack_damage)
	_despawn(w)
	_place_player(P)
	await _settle(2)

func _set_enemy_cell(e: Enemy, cell: Vector2i) -> void:
	e.position = main._ground_pos(cell)
	e.target_position = e.position
	e.is_moving = false
	e._move_path.clear()

func _test_ice_troll() -> void:
	print("-- Ice Troll --")
	_reset_hp()
	var t := _spawn(Enemy.EnemyType.ICE_TROLL, Vector2i(1, 0))
	var hp0 := _hp()
	t._try_ice_club(main.player)
	_check(hp0 - _hp() == t.attack_damage, "Ice Troll: Club deals 13 (band-scaled %d)" % t.attack_damage)
	var cold = _pdm().get_debuff(Debuff.DebuffType.COLD)
	var brittle = _pdm().get_debuff(Debuff.DebuffType.BRITTLE)
	_check(cold != null and cold.value == 1 and cold.duration == 5, "Ice Troll: every attack adds a stack of Cold (5 tempo)")
	_check(brittle != null and brittle.value == 1, "Ice Troll: …and a stack of Brittle")
	_check(t._get_action("ice_club")["tempo_cost"] == 4, "Ice Troll: Club is 4 tempo")
	# Four Cold already: the club's stack freezes them, and Clobber follows.
	_reset_hp()
	_pdm().apply_debuff(Debuff.create(Debuff.DebuffType.COLD, 4, 5))
	hp0 = _hp()
	t._try_ice_club(main.player)
	var clobber := maxi(1, roundi(50 * t._pps_dmg))
	_check(_pdm().has_debuff(Debuff.DebuffType.FROZEN), "Ice Troll: the fifth Cold freezes")
	_check(hp0 - _hp() == t.attack_damage + clobber, "Ice Troll: a freezing club triggers Clobber (50, band-scaled %d): %d in all" % [clobber, hp0 - _hp()])
	_reset_hp()
	_despawn(t)

func _test_snow_wraith() -> void:
	print("-- Snow Wraith --")
	_reset_hp()
	var w := _spawn(Enemy.EnemyType.SNOW_WRAITH, Vector2i(4, 0))
	w._last_seen_target = main.player
	w._choose_snow_wraith_action(4)
	_check(str(w.chosen_action.get("name", "")) == "snowball", "Snow Wraith: 4 squares off (range 5), it opens with Snowball")
	var hp0 := _hp()
	w._try_snowball(main.player)
	var slowed = _pdm().get_debuff(Debuff.DebuffType.SLOWED)
	var cold = _pdm().get_debuff(Debuff.DebuffType.COLD)
	_check(_hp() == hp0, "Snow Wraith: Snowball deals no damage")
	_check(slowed != null and slowed.clock_timed and slowed.duration == 3, "Snow Wraith: Snowball Slows for 3 tempo")
	_check(cold != null and cold.value == 2, "Snow Wraith: …and adds 2 Cold")
	w._choose_snow_wraith_action(4)
	_check(str(w.chosen_action.get("name", "")) == "ice_blast", "Snow Wraith: once they are Slowed, Ice Blast")
	_reset_hp()
	hp0 = _hp()
	w._try_ice_blast(main.player)
	_check(hp0 - _hp() == w.attack_damage, "Snow Wraith: Ice Blast deals 5 (band-scaled %d) without armor" % w.attack_damage)
	slowed = _pdm().get_debuff(Debuff.DebuffType.SLOWED)
	_check(slowed != null and slowed.duration == 3, "Snow Wraith: Ice Blast Slows for 3 tempo")
	_reset_hp()
	_stats().current_armor = 40
	var pool0 := _hp() + int(_stats().current_armor)
	w._try_ice_blast(main.player)
	var pool1 := _hp() + int(_stats().current_armor)
	_check(pool0 - pool1 == w.attack_damage + 3, "Snow Wraith: Ice Blast +3 against armor (%d)" % (pool0 - pool1))
	_check(w._get_action("snowball")["tempo_cost"] == 8 and w._get_action("ice_blast")["tempo_cost"] == 5, "Snow Wraith: Snowball 8 tempo, Ice Blast 5")
	_reset_hp()
	_despawn(w)

func _test_granite_colossus() -> void:
	print("-- Granite Colossus --")
	var g := _spawn(Enemy.EnemyType.GRANITE_COLOSSUS, Vector2i(2, 0))
	g._choose_action(main.player)
	_check(g.actions.is_empty() and g.chosen_action.is_empty(), "Granite Colossus: no actions on the sheet yet — it only stands")
	_despawn(g)

func _test_sabertooth() -> void:
	print("-- Sabertooth Tiger --")
	_reset_hp()
	var t := _spawn(Enemy.EnemyType.SABERTOOTH, Vector2i(1, 0))
	seed(777)
	var crits := 0
	var crit_bleeds := true
	for i in range(300):
		_pdm().clear_all_debuffs()
		t.strengthen_stacks = 0
		var hp0 := _hp()
		t._sabertooth_strike(main.player, 10, "Probe")
		var dealt := hp0 - _hp()
		if dealt == 15:
			crits += 1
			var b = _pdm().get_debuff(Debuff.DebuffType.BLEED)
			if b == null or b.value != 6:
				crit_bleeds = false
		_reset_hp()
	_check(crits >= 80 and crits <= 130, "Sabertooth: about 35%% of strikes crit for 1.5x (%d of 300)" % crits)
	_check(crits > 0 and crit_bleeds, "Sabertooth: a crit inflicts 6 Bleed")
	# Sunken Bite: 10 damage + 8 Bleed (6 more on a crit).
	seed(1)
	_reset_hp()
	var hp0 := _hp()
	t._try_sunken_bite(main.player)
	var dealt := hp0 - _hp()
	var bleed = _pdm().get_debuff(Debuff.DebuffType.BLEED)
	_check((dealt == 10 and bleed != null and bleed.value == 8) or (dealt == 15 and bleed != null and bleed.value == 14), "Sunken Bite: 10 damage + 8 Bleed (%d dealt, bleed %s)" % [dealt, str(bleed.value if bleed else 0)])
	_reset_hp()
	_despawn(t)

func _test_cerberus_swipe() -> void:
	print("-- Cerberus --")
	_reset_hp()
	var c := _spawn(Enemy.EnemyType.CERBERUS, Vector2i(1, 0))
	var hp0 := _hp()
	c._try_swipe(main.player)
	var bleed = _pdm().get_debuff(Debuff.DebuffType.BLEED)
	_check(bleed != null and bleed.value == 8 and _hp() == hp0, "Cerberus: Swipe lays 8 Bleed and no wound of its own")
	_reset_hp()
	_despawn(c)

func _test_succubus_snap() -> void:
	print("-- Succubus --")
	_reset_hp()
	var s := _spawn(Enemy.EnemyType.SUCCUBUS, Vector2i(3, 0))
	var st = _stats()
	st.max_mana = 100
	st.current_mana = 20
	var hp0 := _hp()
	s._try_damaging_snap(main.player)
	_check(hp0 - _hp() == 80 / 20 + 4, "Succubus: Damaging Snap = missing mana / 20 + 4 (%d)" % (hp0 - _hp()))
	st.current_mana = 60
	s._try_mana_drain(main.player)
	_check(int(st.current_mana) == 50, "Succubus: Mana Drain takes 10 mana from range 3 (%d)" % int(st.current_mana))
	st.current_mana = st.max_mana
	_reset_hp()
	_despawn(s)

func _test_demon() -> void:
	print("-- Demon --")
	_reset_hp()
	var d := _spawn(Enemy.EnemyType.DEMON, Vector2i(1, 0))
	d._try_demon_cuff(main.player)
	var cuff = _pdm().get_debuff(Debuff.DebuffType.CUFFED)
	_check(cuff != null and cuff.duration == 15, "Demon: Cuff — no draws for 15 tempo")
	var hp0 := _hp()
	d._execute_action("demon_attack", main.player)
	_check(hp0 - _hp() == d.attack_damage, "Demon: Attack deals 8 (band-scaled %d)" % d.attack_damage)
	_check(Enemy.is_async_action(d._get_action("mimic")) and Enemy.is_async_action(d._get_action("demon_cuff")), "Demon: Mimic and Cuff are Async")
	_reset_hp()
	_despawn(d)

func _test_ifrit() -> void:
	print("-- Ifrit --")
	_reset_hp()
	var f := _spawn(Enemy.EnemyType.IFRIT, Vector2i(-3, 0))   # the player is 3 squares east of it
	var inside := _bystander(Vector2i(-1, 2))    # forward 2, aside 2: inside the 5x5
	var outside := _bystander(Vector2i(-1, 3))   # aside 3: outside
	main.enemy_spawner.summons = [inside, outside]
	f._choose_ifrit_action(3)
	_check(str(f.chosen_action.get("name", "")) == "fire_breath", "Ifrit: 3 tiles out it breathes fire")
	var walls0: int = main._fire_walls.size()
	var hp0 := _hp()
	f._try_fire_breath(main.player)
	var burn = _pdm().get_debuff(Debuff.DebuffType.BURN)
	_check(_hp() < hp0, "Ifrit: Fire Breath burns the player in the 5x5 (%d)" % (hp0 - _hp()))
	_check(burn != null and burn.value >= 5, "Ifrit: …and lays 5 Burn")
	_check(inside.hits == 1 and outside.hits == 0, "Ifrit: a unit inside the 5x5 is hit, one beside it is not")
	# Designer, 2026-11-08: the breath goes on as a 6-tempo Channel, and the
	# 25 tiles burn while it does and 3 tempo after (this tempo + 6 + 3;
	# tests/test_open_fixes_enemies.gd).
	_check(main._fire_walls.size() == walls0 + 1 and main._fire_walls.back()["tiles"].size() == 25 and int(main._fire_walls.back()["tempo_left"]) == 10,
		"Ifrit: the 25 tiles keep burning while he breathes on, then 3 tempo")
	_check(f.is_channeling(), "Ifrit: …and he channels the breath")
	f._reset_action_clocks()
	main.enemy_spawner.summons = []
	inside.queue_free()
	outside.queue_free()
	# Backflip: a single blow over 40 sends it 3 squares backwards.
	_reset_hp()
	_set_enemy_cell(f, P + Vector2i(-1, 0))
	PlayerStats.hit_source_direct = true
	f.take_damage(30, true, DamageTypes.Type.FIRE)
	_check(_cell(f) == P + Vector2i(-1, 0), "Ifrit: a blow of 30 does not move it")
	f.take_damage(60, true, DamageTypes.Type.FIRE)
	await _settle(2)
	var dest: Vector2i = gm.world_to_grid(f.target_position)
	_check(dest == P + Vector2i(-4, 0), "Ifrit: a blow over 40 backflips it 3 squares away (%s)" % str(dest))
	PlayerStats.hit_source_direct = false
	_reset_hp()
	_despawn(f)
	await _settle(2)

func _test_mind_eater() -> void:
	print("-- Mind Eater --")
	_reset_hp()
	var m := _spawn(Enemy.EnemyType.MIND_EATER, Vector2i(5, 0))
	m._try_mind_cuff(main.player)
	var cuff = _pdm().get_debuff(Debuff.DebuffType.CUFFED)
	_check(cuff != null and cuff.duration == 15, "Mind Eater: Manipulate Mind Space — no draws for 15 tempo, from 5 squares")
	_check(m.actions.size() == 2 and m.actions.filter(func(a): return Enemy.MOVEMENT_ACTIONS.has(str(a["name"])) or str(a["name"]) == "move").is_empty() and int(m.move_distance) == 0, "Mind Eater: it never moves")
	_reset_hp()
	_despawn(m)

func _test_specter_spit() -> void:
	print("-- Specter --")
	_reset_hp()
	var s := _spawn(Enemy.EnemyType.SPECTER, Vector2i(2, 0))
	var hp0 := _hp()
	s._try_spirit_spit(main.player)
	_check(hp0 - _hp() == s.attack_damage, "Specter: Spirit Spit hits for 2 (band-scaled %d) at range 2" % s.attack_damage)
	_set_enemy_cell(s, P + Vector2i(3, 0))
	hp0 = _hp()
	s._try_spirit_spit(main.player)
	_check(_hp() == hp0, "Specter: …not from 3 squares (it moves instead)")
	_reset_hp()
	_despawn(s)

func _test_minotaur() -> void:
	print("-- Inflamed Minotaur --")
	_reset_hp()
	var m := _spawn(Enemy.EnemyType.INFLAMED_MINOTAUR, Vector2i(1, 0))
	var hp0 := _hp()
	m._execute_action("minotaur_attack", main.player)
	var burn = _pdm().get_debuff(Debuff.DebuffType.BURN)
	_check(hp0 - _hp() == m.attack_damage and burn != null and burn.value >= 2, "Minotaur: Attack deals 35 (band-scaled %d) + 2 Burn" % m.attack_damage)
	m.slow_stacks = 4
	m._minotaur_labyrinth_leap()
	_check(m._minotaur_leap_spaces == 10, "Minotaur: each Slow stack shortens the 14-space leap by 1 (%d)" % m._minotaur_leap_spaces)
	_check(main.dungeon_manager.is_floor(_cell(m)), "Minotaur: he lands on open floor")
	_check(m._minotaur_rush_pending and int(m.chosen_action["tempo_cost"]) >= 5 and int(m.chosen_action["tempo_cost"]) <= 15, "Minotaur: Bull Rush follows 5 to 15 tempo after landing")
	_reset_hp()
	_despawn(m)

func _test_djinn() -> void:
	print("-- Djinn --")
	_reset_hp()
	var dj := _spawn(Enemy.EnemyType.DJINN, Vector2i(5, 0))
	var near := _bystander(Vector2i(0, 4))    # 4 from the player: the bound reaches
	var far := _bystander(Vector2i(0, -6))    # 6 from the player, 10 from near: out of every bound
	main.enemy_spawner.summons = [near, far]
	var hp0 := _hp()
	dj._try_chain_lightning(main.player)
	_check(hp0 - _hp() > 0, "Djinn: Chain Lightning strikes the player from 5 squares")
	_check(near.hits == 1 and near.last_damage == dj.attack_damage, "Djinn: …and bounds 4 squares on for 35 (band-scaled %d)" % dj.attack_damage)
	_check(far.hits == 0, "Djinn: a unit beyond every bound is spared")
	main.enemy_spawner.summons = []
	near.queue_free()
	far.queue_free()
	_set_enemy_cell(dj, P + Vector2i(6, 0))
	hp0 = _hp()
	dj._try_chain_lightning(main.player)
	_check(_hp() == hp0, "Djinn: from 6 squares the cast does not reach")
	# Wishes: every attack on him puts 3 in the hand, each searing for 1/3 of the hit.
	var deck = main.deck_manager
	var before: int = 0
	for c in deck.hand:
		if c.card_id == "djinn_wish":
			before += 1
	PlayerStats.hit_source_direct = true
	var hp_dj: int = dj.current_health
	dj.take_damage(30, true)
	PlayerStats.hit_source_direct = false
	var dealt: int = hp_dj - dj.current_health
	var wishes: Array = []
	for c in deck.hand:
		if c.card_id == "djinn_wish":
			wishes.append(c)
	_check(wishes.size() == before + 3, "Djinn: an attack on him puts 3 Wishes in the hand (%d)" % (wishes.size() - before))
	if not wishes.is_empty():
		var w: Card = wishes.back()
		_check(w.held_damage_per_cycle == floori(dealt / 3.0), "Djinn: each Wish sears for 1/3 of the hit per cycle (%d of %d)" % [w.held_damage_per_cycle, dealt])
		_check(w.mana_cost == 60 and w.tempo_cost == 0, "Djinn: a Wish costs 60 mana, 0 tempo")
	for c in wishes:
		deck.hand.erase(c)
	_reset_hp()
	_despawn(dj)

func _test_ring_wraith() -> void:
	print("-- Ring Wraith --")
	_reset_hp()
	var w := _spawn(Enemy.EnemyType.RING_WRAITH, Vector2i(1, 0))
	var other := _spawn(Enemy.EnemyType.SWARM, Vector2i(-1, 0))
	main.player.get_buff_manager().apply_buff(Buff.create_invisible(10, "Shadow Form"))
	_check(w._can_act_now(main.player), "Ring Wraith: acts though you are invisible (shadow form does not hide you)")
	_check(not other._can_act_now(main.player), "…where any other enemy loses you")
	main.player.get_buff_manager().remove_buff(Buff.BuffType.INVISIBLE)
	_check(w.xp_reward == 0 and main.enemy_spawner._generate_loot(w).is_empty(), "Ring Wraith: no XP and no loot")
	_check(w._get_action("attack")["tempo_cost"] == 2 and w.attack_damage == 15, "Ring Wraith: Attack is 15 damage every 2 tempo")
	_despawn(w)
	_despawn(other)
	# Resummons on death: The Precious lets them out with shadow form; one
	# killed comes back fresh the next time, a survivor as it was left.
	var ring: ItemData = load("res://data/items/the_precious.tres").duplicate()
	ring.item_level = 1
	ring.ring_counters = {}
	var inv = main.player.get_inventory()
	var rings_before: Array = inv.equipped_rings.duplicate()
	inv.equipped_rings.clear()
	inv.equipped_rings.append(ring)
	_stats().shadow_form_tempo = 0
	main._enter_shadow_form(ring)
	var first: Array = main._wraiths.duplicate()
	_check(first.size() == 3, "Ring Wraith: The Precious lets 3 out with shadow form (%d)" % first.size())
	if first.size() == 3:
		first[0].take_damage(99999, true)
		first[1].current_health = 40
		_stats().shadow_form_tempo = 0
		main._on_shadow_form_ended()
		main._enter_shadow_form(ring)
		var hps: Array = []
		for x in main._wraiths:
			hps.append(x.current_health)
		_check(main._wraiths.size() == 3 and 40 in hps and hps.count(main._wraiths[0].max_health) == 2,
			"Ring Wraith: the slain one resummons fresh, the wounded one returns as it was (%s)" % str(hps))
		_stats().shadow_form_tempo = 0
		main._on_shadow_form_ended()
	inv.equipped_rings.clear()
	for r in rings_before:
		inv.equipped_rings.append(r)

func _test_dummy() -> void:
	print("-- Training Dummy --")
	var d := _spawn(Enemy.EnemyType.DUMMY, Vector2i(2, 0))
	d.take_damage(99999, true)
	_check(d.is_alive() and d.current_health == d.max_health, "Dummy: a killing blow only refills it")
	_check(d.xp_reward == 0 and d.actions.is_empty(), "Dummy: no XP, and it never strikes")
	_despawn(d)

func _test_thanatos() -> void:
	print("-- Thanatos --")
	_reset_hp()
	var th := _spawn(Enemy.EnemyType.THANATOS, Vector2i(1, 0))
	var hp0 := _hp()
	th._execute_action("thanatos_reap", main.player)
	var bleed = _pdm().get_debuff(Debuff.DebuffType.BLEED)
	_check(hp0 - _hp() == th.attack_damage and bleed != null and bleed.value == 6, "Thanatos: Reap deals 25 (band-scaled %d) + 6 Bleed" % th.attack_damage)
	_reset_hp()
	if main.deck_manager.hand.is_empty():
		main.deck_manager.draw_card()
	_set_enemy_cell(th, P + Vector2i(6, 0))
	hp0 = _hp()
	th._try_death_bolt(main.player)
	var hexes: Array = _pdm().get_hexed_debuffs()
	_check(hp0 - _hp() == Enemy.THANATOS_BOLT_DAMAGE, "Thanatos: Death Bolt hits for 15 at 6 squares")
	_check(hexes.size() == 1 and hexes[0].value == 30 and hexes[0].duration == 25, "Thanatos: …and Hexes a card (+30 mana, 25 tempo)")
	_reset_hp()
	_set_enemy_cell(th, P + Vector2i(7, 0))
	hp0 = _hp()
	th._try_death_bolt(main.player)
	_check(_hp() == hp0, "Thanatos: from 7 squares the bolt does not land")
	# Raise the Dead: two servants at most; a fallen servant rises as a
	# Skeleton and costs him 10 health.
	_set_enemy_cell(th, P + Vector2i(1, 0))
	var a: Enemy = th._necro_spawn(Enemy.EnemyType.ZOMBIE)
	var b: Enemy = th._necro_spawn(Enemy.EnemyType.ZOMBIE)
	seed(3)
	var raised := false
	for i in range(40):
		th._choose_thanatos_action(1)
		if str(th.chosen_action.get("name", "")) == "summon_skeleton":
			raised = true
	_check(a != null and b != null and not raised, "Thanatos: with two servants up he raises no more")
	var skel_before := 0
	for e in main.enemy_spawner.get_living_enemies():
		if e.enemy_type == Enemy.EnemyType.SKELETON:
			skel_before += 1
	var th_hp: int = th.current_health
	var th_armor: int = th.current_armor
	a.take_damage(99999, true)
	await _settle(3)
	var skel_after := 0
	for e in main.enemy_spawner.get_living_enemies():
		if e.enemy_type == Enemy.EnemyType.SKELETON:
			skel_after += 1
	_check(skel_after == skel_before + 1, "Thanatos: a fallen servant rises again as a Skeleton")
	_check(th.current_health == th_hp - 10 and th.current_armor == th_armor, "Thanatos: …and costs him 10 health (%d -> %d, armor %d -> %d)" % [th_hp, th.current_health, th_armor, th.current_armor])
	_check(th._necro_summons_alive == 1, "Thanatos: one servant left, so he may raise another")
	for e in main.enemy_spawner.get_living_enemies():
		_despawn(e)
	_reset_hp()
	await _settle(2)

func _test_totems() -> void:
	print("-- Totems --")
	_reset_hp()
	var lt := _spawn(Enemy.EnemyType.LIGHTNING_TOTEM, Vector2i(2, 0))
	var in_reach := _bystander(Vector2i(2, 4))   # 4 from the totem
	var beyond := _bystander(Vector2i(2, -5))    # 5 from the totem
	main.enemy_spawner.summons = [in_reach, beyond]
	var hp0 := _hp()
	lt._totem_pulse()
	var shock = _pdm().get_debuff(Debuff.DebuffType.SHOCKED)
	_check(shock != null and shock.value == 1, "Lightning Totem: Shocks the player within 4 (1 Shock)")
	_check(in_reach.dm != null and in_reach.dm.has_debuff(Debuff.DebuffType.SHOCKED), "Lightning Totem: …and every other unit within 4")
	_check(beyond.dm == null or not beyond.dm.has_debuff(Debuff.DebuffType.SHOCKED), "Lightning Totem: not one 5 away")
	_check(hp0 - _hp() > 0 and in_reach.hits == 0, "Lightning Totem: strikes the nearest of them (the player, %d lightning)" % (hp0 - _hp()))
	_check(lt.xp_reward == 0 and main.enemy_spawner._generate_loot(lt).is_empty(), "Lightning Totem: no XP, no loot")
	main.enemy_spawner.summons = []
	in_reach.queue_free()
	beyond.queue_free()
	_despawn(lt)
	_reset_hp()
	var et := _spawn(Enemy.EnemyType.EARTH_TOTEM, Vector2i(1, 0))
	PlayerStats.hit_source_direct = true
	hp0 = _hp()
	et.take_damage(3, true)
	PlayerStats.hit_source_direct = false
	_check(hp0 - _hp() == 5, "Earth Totem: Thorns — a direct hit on it costs the attacker 5 (%d)" % (hp0 - _hp()))
	_despawn(et)
	_reset_hp()

func _test_mockups() -> void:
	print("-- Mock-ups --")
	for key in ["PIT_FIEND", "CORRUPTED_ARCHANGEL"]:
		var def: Dictionary = EnemyDefs.DEFS[key]
		var t: int = Enemy.EnemyType[key]
		_check(bool(def.get("mockup", false)) and Enemy.actions_for_type(t).is_empty(), "%s: a design mock-up with no moves, as the compendium says" % key)
		var d := {}
		for row in Enemy.get_all_enemy_data():
			if row["name"] == def["name"]:
				d = row
		_check("Design mock-up" in str(d.get("special", "")), "%s: the compendium names it a mock-up" % key)

# --------------------------------------------------------------- the summons

func _dummy_at(cell: Vector2i) -> Enemy:
	var e: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.DUMMY, main._ground_pos(cell))
	e.chosen_action = {}
	return e

func _test_wolves() -> void:
	print("-- Wolves (Gauntlets of Dungeon Mastering) --")
	await _clear_field()
	_reset_hp()
	for i in range(4):
		main._spawn_wolf()
	_check(main._wolves.size() == 3, "Wolves: a pack of 3 at most (%d)" % main._wolves.size())
	var w = main._wolves[0]
	_check(w.max_health == 20 and w.health == 20, "Wolf: 20 HP")
	# Two wolves beside a dummy: each bites for 5 x (1 + 20% per other wolf) and bleeds.
	main._wolves[2].queue_free()
	main._wolves.remove_at(2)
	var d := _dummy_at(P + Vector2i(0, -4))
	var dcell := _cell(d)
	_set_cell(main._wolves[0], dcell + Vector2i(-1, 0))
	_set_cell(main._wolves[1], dcell + Vector2i(1, 0))
	var hp0: int = d.current_health
	main._update_wolves(4)
	_check(d.current_health == hp0, "Wolves: no bite before 5 tempo")
	main._update_wolves(1)
	_check(hp0 - d.current_health == 2 * floori(5 * 1.2), "Wolves: two pack-mates each bite for 6 (5 +20%%): %d" % (hp0 - d.current_health))
	_check(d.bleed_stacks >= 2, "Wolves: their bites bleed (+1 per other wolf): %d" % d.bleed_stacks)
	# Moves 2 squares every 3 tempo.
	var lone = main._wolves[1]
	main._wolves[0].queue_free()
	main._wolves.remove_at(0)
	_set_cell(lone, dcell + Vector2i(6, 0))
	lone.move_accum = 0
	main._update_wolves(2)
	_check(lone.get_destination_cell() == dcell + Vector2i(6, 0), "Wolf: no step before 3 tempo")
	main._update_wolves(1)
	_check(lone.get_destination_cell() == dcell + Vector2i(4, 0), "Wolf: 2 squares every 3 tempo (%s)" % str(lone.get_destination_cell()))
	# Shepherd's Mark (MarkableSummon): survive a lethal blow at 1 HP with armor; the caster pays 8.
	lone.shepherd_mark_caster = _stats()   # Card._execute_shepherds_mark marks with the caster's stats
	lone.shepherd_mark_armor = 5
	lone.shepherd_mark_tempo = 10
	var php := _hp()
	lone.take_damage(999)
	_check(not lone.is_dead and lone.health == 1 and lone.armor == 5, "Markable summon: Shepherd's Mark — survives at 1 HP with its armor")
	_check(php - _hp() == 8, "Markable summon: …and the caster takes 8")
	lone.heal(5)
	_check(lone.health == 6, "Healable summon: heals land on it")
	await _clear_field()

func _test_bone_skeleton() -> void:
	print("-- Bone-arrow skeletons (Sack of Bone Arrows) --")
	await _clear_field()
	for i in range(4):
		main._spawn_bone_skeleton(14, main._ground_pos(P + Vector2i(0, -3)))
	_check(main._skeletons.size() == 3, "Bone skeletons: up to 3 at once (%d)" % main._skeletons.size())
	var s = main._skeletons[0]
	_check(s.max_health == 14 and s.base_attack == 5 and s.move_steps == 4 and s.move_interval == 1 and s.attack_interval == 5,
		"Bone skeleton: the victim's half health, 5 damage, 4 squares a tempo, attacks every 5 tempo")
	await _clear_field()

func _test_spirit_bows() -> void:
	print("-- Spirit bows (Bow of Budding Blasts) --")
	await _clear_field()
	for i in range(5):
		main._spawn_bud_bow()
	var buds: Array = main._spirit_bows.filter(func(b): return b.is_bud)
	_check(buds.size() == 4, "Budded bows: up to 4 at once (%d)" % buds.size())
	var bud = buds[0]
	bud.spend_attack()
	_check(not bud.is_dead, "Budded bow: one shot spent, it stands")
	bud.spend_attack()
	_check(bud.is_dead, "Budded bow: …it withers after 2 attacks")
	await _clear_field()
	main._summon_spirit_bow()
	var spirit = main._spirit_bows[0] if not main._spirit_bows.is_empty() else null
	_check(spirit != null and not spirit.is_bud, "Spirit Bow: the maintained bow takes shape")
	main._update_spirit_bows(1)
	_check(spirit == null or spirit.is_dead, "Spirit Bow: with no mana held for it, it dissolves")
	await _clear_field()

func _test_clone() -> void:
	print("-- Draupnir's duplicate --")
	await _clear_field()
	var ring: ItemData = load("res://data/items/draupnir.tres").duplicate()
	ring.item_level = 1
	var st = _stats()
	st.max_health = 400
	st.current_health = 400
	st.draupnir_clone_alive = false
	main._spawn_draupnir_clone(ring)
	_check(main._clones.size() == 1, "Draupnir: a duplicate drips out")
	var c = main._clones[0]
	_check(c.max_health == 100, "Draupnir: a quarter of your health (%d of 400)" % c.max_health)
	_check(c.MOVE_STEPS == 2 and c.MOVE_INTERVAL == 3 and c.ATTACK_INTERVAL == 7, "Draupnir: moves 2 squares per 3 tempo, swings every 7")
	await _settle(1)
	main._spawn_draupnir_clone(ring)
	_check(main._clones.size() == 1, "Draupnir: only one at a time")
	c.take_damage(9999)
	await _settle(1)
	var bm = main.player.get_buff_manager()
	_check(bm.has_buff(Buff.BuffType.STRENGTHEN), "Draupnir: when a duplicate dies, Strengthen")
	bm.remove_buff(Buff.BuffType.STRENGTHEN)
	_reset_hp()
	await _clear_field()

func _test_specter_summon() -> void:
	print("-- Seance specter --")
	await _clear_field()
	var sp = main._spawn_specter(P + Vector2i(0, -3), 12)
	_check(sp != null and sp.max_health == 12 and sp.death_damage == 12, "Seance specter: HP from the rank, its death damage the same")
	sp.tick(24)
	_check(not sp.is_dead, "Seance specter: still standing at 24 tempo")
	sp.tick(1)
	_check(sp.is_dead, "Seance specter: fades at 25 tempo")
	var sp2 = main._spawn_specter(P + Vector2i(0, -3), 12)
	var killer := _dummy_at(P + Vector2i(1, -3))
	var hp0: int = killer.current_health
	sp2.last_attacker = killer
	sp2.take_damage(999)
	_check(hp0 - killer.current_health == 12, "Seance specter: destroyed, its HP lands on its killer (%d)" % (hp0 - killer.current_health))
	await _clear_field()

func _test_worms() -> void:
	print("-- Alaskan Bull Worms (Worms Armageddon) --")
	await _clear_field()
	_reset_hp()
	main._spawn_bull_worms(2)
	_check(main._summoned_worms.size() == 2, "Bull Worms: two burrow up")
	var w = main._summoned_worms[0]
	_check(w.max_health == 12 and w.burrowed, "Bull Worm: 12 HP, burrowed")
	w.take_damage(5)
	_check(w.health == 12, "Bull Worm: untargetable while burrowed")
	main._summoned_worms[1].queue_free()
	main._summoned_worms.remove_at(1)
	var d := _dummy_at(P + Vector2i(0, -4))
	_set_cell(w, _cell(d) + Vector2i(3, 0))
	main._update_summoned_worms()
	_check(w.get_destination_cell() == _cell(d) + Vector2i(2, 0) and w.burrowed, "Bull Worm: 1 movement per tempo, still burrowed")
	_set_cell(w, _cell(d) + Vector2i(1, 0))
	var hp0: int = d.current_health
	main._update_summoned_worms()
	_check(not w.burrowed and hp0 - d.current_health == 6, "Bull Worm: surfaces to attack, for 6 (%d)" % (hp0 - d.current_health))
	w.take_damage(5)
	_check(w.health == 7, "Bull Worm: surfaced, it can be hit")
	await _clear_field()

func _test_frankenstein() -> void:
	print("-- Frankensteins Monster (ITS ALIVE!!!!!) --")
	await _clear_field()
	var m = main.FrankensteinScript.new()
	main.add_child(m)
	m.setup(gm, main._ground_pos(P + Vector2i(-6, -4)), 40)
	main._frankensteins.append(m)
	_check(m.max_health == 50 + 32 and m.attack_damage == 10 + 10 and is_equal_approx(m.resist_percent, 9.0),
		"Frankenstein: 50 + INT x0.8 HP, 10 + INT x0.25 attack, 5% + INT/10 resist (INT 40)")
	_check(m._absorb(100) == 91, "Frankenstein: the resist takes 9% off every hit")
	var d := _dummy_at(P + Vector2i(0, -4))
	_set_cell(m, _cell(d) + Vector2i(-6, 0))
	m.move_accum = 0
	main._update_frankensteins(7)
	_check(m.get_destination_cell() == _cell(d) + Vector2i(-6, 0), "Frankenstein: no step before 8 tempo")
	main._update_frankensteins(1)
	_check(m.get_destination_cell() == _cell(d) + Vector2i(-2, 0), "Frankenstein: 4 spaces every 8 tempo (%s)" % str(m.get_destination_cell()))
	_set_cell(m, _cell(d) + Vector2i(-1, 0))
	m.attack_accum = 0
	var hp0: int = d.current_health
	main._update_frankensteins(5)
	_check(hp0 - d.current_health == 20, "Frankenstein: attacks every 5 tempo for 10 + INT x0.25 (%d)" % (hp0 - d.current_health))
	await _clear_field()

func _test_penguin() -> void:
	print("-- Sanguine the Penguin --")
	await _clear_field()
	_reset_hp()
	main._summon_penguin()
	var p = main._penguin
	_check(p != null and p.max_health == 50, "Sanguine: 50 HP")
	if p == null:
		return
	var pc: Vector2i = p.get_cell()
	_check(maxi(absi(pc.x - P.x), absi(pc.y - P.y)) <= 1, "Sanguine: waddles out beside you")
	var st = _stats()
	st.current_health = 4000
	st.heal(5)
	var half_heal: int = _hp() - 4000   # a heal of 5 through the player's own heal modifiers
	st.current_health = 4000
	p.take_damage(10)
	_check(_hp() - 4000 == half_heal and half_heal > 0, "Sanguine: damage he takes heals you half as much (10 -> a heal of 5, landed %d)" % (_hp() - 4000))
	var d := _dummy_at(p.get_cell() + Vector2i(0, -1))
	p.attack_accum = 0
	var hp0: int = d.current_health
	main._update_penguin(4)
	_check(d.current_health == hp0, "Sanguine: no peck before 5 tempo")
	main._update_penguin(1)
	_check(hp0 - d.current_health == 8, "Sanguine: 8 damage every 5 tempo (%d)" % (hp0 - d.current_health))
	_place_player(P + Vector2i(3, 0))
	main._update_penguin(1)
	var pc2: Vector2i = p.get_destination_cell()
	_check(maxi(absi(pc2.x - (P.x + 3)), absi(pc2.y - P.y)) <= 1, "Sanguine: stays beside you as you move (%s)" % str(pc2))
	_reset_hp()
	await _clear_field()
