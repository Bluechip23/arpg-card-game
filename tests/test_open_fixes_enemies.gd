extends SceneTree

## Fix pass (2026-11-08), enemies: each enemy's compendium text
## (Enemy.description_for) and the designer's rulings of 2026-11-08, proved in
## a booted dojo — the nest Archer Rat, Cerberus (third head, venom
## aftermath, Guardian of Death), the Vampire's Absorbs, the Ifrit's breath
## channel, the Ice Troll's queued Clobber and the Djinn's wishes on spells.
## Run: godot --headless --path . --script tests/test_open_fixes_enemies.gd

var failures: int = 0
var main = null
var gm = null
var P := Vector2i(9, 7)   # where the player stands for every check

## A player-side summon with a health pool (as Summon has).
class Pet extends Node3D:
	var is_dead: bool = false
	var display_name: String = "Pet"
	var max_health: int = 40
	var health: int = 40
	func take_damage(amount: int, _from_status := false) -> void:
		health -= amount

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	print("=== Open fixes: enemies ===")
	TempoManager.preferred_swing_hold = 0
	await _boot()
	if main == null:
		print("=== %d failure(s) ===" % failures)
		quit(1)
		return
	await _clear_field()
	_test_archer_rat()
	_test_cerberus_third_head()
	_test_cerberus_venom_after_death()
	_test_cerberus_guardian_summons()
	_test_vampire()
	_test_ifrit()
	_test_ice_troll()
	await _test_djinn_spell()
	_test_unit_health_summon()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

# ------------------------------------------------------------------ helpers

func _settle(frames: int = 6) -> void:
	for _i in range(frames):
		await process_frame

func _boot() -> void:
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
	if main.player == null:
		main = null
		return
	gm = main.grid_manager
	_reset_hp()

func _clear_field() -> void:
	for e in main.enemy_spawner.get_living_enemies():
		main.enemy_spawner.despawn_enemy(e)
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
	main.player.untargetable = false
	_place_player(P)

func _cell(n: Node3D) -> Vector2i:
	return gm.world_to_grid(n.position)

func _scaled(e: Enemy, base: int) -> int:
	return maxi(1, roundi(base * e._pps_dmg))

## One tempo the way main runs it: the enemies act, then fire fuses burn down.
func _tempo() -> void:
	main.enemy_spawner.on_tempo_advanced(1)
	main._tick_fire_walls(1)

func _last_path_cell(e: Enemy) -> Vector2i:
	if e._move_path.is_empty():
		return _cell(e)
	return gm.world_to_grid(e._move_path[e._move_path.size() - 1])

# -------------------------------------------------------------------- tests

func _test_archer_rat() -> void:
	print("-- Archer Rat (nest): 'At range ≤2: Scurries 5 tiles away … At range >6: Moves 2 tiles closer' --")
	_reset_hp()
	var r := _spawn(Enemy.EnemyType.ARCHER_RAT, Vector2i(-2, 0))
	var here := _cell(r)
	# Released, not yet on its perch: it scrambles for the high ground first.
	r.perch_cell = here + Vector2i(-3, 0)
	r._choose_archer_rat_action(2)
	_check(str(r.chosen_action.get("name", "")) == "get_into_range", "before it reaches its perch it climbs (even at range 2)")
	# On the perch now.
	r.perch_cell = here
	r._choose_archer_rat_action(2)
	_check(str(r.chosen_action.get("name", "")) == "scurry_away", "on its perch at range 2 it scurries away (was: shot at point blank)")
	r._choose_archer_rat_action(4)
	_check(str(r.chosen_action.get("name", "")) == "shoot", "at range 3-6 it shoots")
	r._choose_archer_rat_action(8)
	_check(str(r.chosen_action.get("name", "")) == "get_into_range", "past 6 it closes in (was: waited on the perch)")
	# Close in: the step goes toward its prey, not back up to the perch.
	_place_player(here + Vector2i(9, 0))
	r._move_path.clear()
	r._try_get_into_range(main.player)
	var to: Vector2i = _last_path_cell(r)
	_check(to.x > here.x, "closing in walks toward its prey (%s -> %s)" % [here, to])
	# Off the perch, at range 4, it shoots rather than climbing back.
	r.position = main._ground_pos(here + Vector2i(1, 0))
	r.target_position = r.position
	r._move_path.clear()
	r.is_moving = false
	r._choose_archer_rat_action(4)
	_check(str(r.chosen_action.get("name", "")) == "shoot", "once released from its perch it fights like any Archer Rat")
	_despawn(r)
	_reset_hp()

func _test_cerberus_third_head() -> void:
	print("-- Cerberus: 'below 33% the third head as well (25, and he feeds on the wound)' --")
	_reset_hp()
	var c := _spawn(Enemy.EnemyType.CERBERUS, Vector2i(1, 0))
	c.current_health = c.max_health / 4
	# Armor soaks every head: no wound, so nothing to feed on.
	_stats().current_armor = 100000
	var hp_c: int = c.current_health
	c._try_cerberus_bite(main.player)
	_check(_hp() == 5000, "the bites land on armor only")
	_check(c.current_health == hp_c, "no wound, no feeding (healed %d)" % (c.current_health - hp_c))
	# Untargetable (Cryonics): the heads find only ice.
	_stats().current_armor = 0
	main.player.untargetable = true
	c._try_cerberus_bite(main.player)
	_check(c.current_health == hp_c, "an untargetable target feeds him nothing (healed %d)" % (c.current_health - hp_c))
	main.player.untargetable = false
	# A real wound: he heals exactly what the third head took.
	_pdm().clear_all_debuffs()
	var hp0 := _hp()
	c._try_cerberus_bite(main.player)
	var lost := hp0 - _hp()
	var healed: int = c.current_health - hp_c
	_check(lost > 0 and healed > 0 and healed * 3 == lost, "he feeds on the third head's wound: healed %d of %d lost to three heads" % [healed, lost])
	_despawn(c)
	_reset_hp()

func _test_cerberus_venom_after_death() -> void:
	print("-- Cerberus: 'the moment the stun is gone, 2 Vulnerable and Cuffed for 10 tempo' (he died meanwhile) --")
	_reset_hp()
	var c := _spawn(Enemy.EnemyType.CERBERUS, Vector2i(1, 0))
	c._try_venom_tail(main.player)
	_check(_pdm().has_debuff(Debuff.DebuffType.STUN), "Venom Tail stuns")
	c.take_damage(100000, false)
	_check(c.is_dead, "Cerberus falls while the stun holds")
	main.enemy_spawner.on_tempo_advanced(1)
	_check(not _pdm().has_debuff(Debuff.DebuffType.VULNERABLE), "while the stun holds, nothing follows")
	_pdm().remove_debuff(Debuff.DebuffType.STUN)
	main.enemy_spawner.on_tempo_advanced(1)
	var vuln = _pdm().get_debuff(Debuff.DebuffType.VULNERABLE)
	var cuff = _pdm().get_debuff(Debuff.DebuffType.CUFFED)
	_check(vuln != null and vuln.value == 2, "the stun gone: 2 Vulnerable, though he is dead")
	_check(cuff != null and cuff.duration == 10, "…and Cuffed for 10 tempo")
	_pdm().clear_all_debuffs()
	main.enemy_spawner.on_tempo_advanced(1)
	_check(not _pdm().has_debuff(Debuff.DebuffType.VULNERABLE), "it lands once")
	_despawn(c)
	_reset_hp()

func _test_cerberus_guardian_summons() -> void:
	print("-- Cerberus: 'Brace … EVERY time any unit within 8 squares — foe or ally … drops below half' (a summon) --")
	_reset_hp()
	var c := _spawn(Enemy.EnemyType.CERBERUS, Vector2i(1, 0))
	var pet := Pet.new()
	pet.position = main._ground_pos(P + Vector2i(0, 2))
	main.add_child(pet)
	main.enemy_spawner.summons = [pet]
	c._guardian_scan()
	var before: int = c._brace_charges
	pet.health = 10   # below half of 40
	c._guardian_scan()
	_check(c._brace_charges == before + 5, "a summon dropping below half within 8 gives him Brace for 5 hits (%d -> %d)" % [before, c._brace_charges])
	c._guardian_scan()
	_check(c._brace_charges == before + 5, "only the drop counts, not staying low")
	main.enemy_spawner.summons = []
	pet.queue_free()
	_despawn(c)
	_reset_hp()

func _test_vampire() -> void:
	print("-- Vampire: 'Absorb (3 tempo, always right after Bat Form) … 20 the first time, then 10' --")
	_reset_hp()
	var v := _spawn(Enemy.EnemyType.VAMPIRE, Vector2i(1, 0))
	v.current_health = v.max_health / 2 + 1
	v.take_damage(5, false)
	_check(v._bat_form_charges == 1 and v._vamp_absorb_pending, "below half: Bat Form, Absorb owed")
	v.take_damage(5, false)
	_check(v._bat_form_charges == 0, "a second hit before the Absorb: the second Bat Form")
	_place_player(_cell(v) + Vector2i(1, 0))
	v.chosen_action = {}
	v._choose_action(main.player)
	_check(str(v.chosen_action.get("name", "")) == "absorb", "Absorb comes next")
	var hp0 := _hp()
	v._execute_action("absorb", main.player)
	_check(hp0 - _hp() == _scaled(v, 20), "the first Absorb drains 20 (scaled %d): %d" % [_scaled(v, 20), hp0 - _hp()])
	v.chosen_action = {}
	v._choose_action(main.player)
	_check(str(v.chosen_action.get("name", "")) == "absorb", "the second Bat Form gets its own Absorb")
	hp0 = _hp()
	v._execute_action("absorb", main.player)
	_check(hp0 - _hp() == _scaled(v, 10), "…for 10 (scaled %d): %d" % [_scaled(v, 10), hp0 - _hp()])
	v.chosen_action = {}
	v._choose_action(main.player)
	_check(str(v.chosen_action.get("name", "")) != "absorb", "and then no more")
	_despawn(v)
	_reset_hp()

func _test_ifrit() -> void:
	print("-- Ifrit: 'he continues to breathe the fire for an additional 6 tempo … a channel' --")
	_reset_hp()
	var f := _spawn(Enemy.EnemyType.IFRIT, Vector2i(-3, 0))
	var a: Dictionary = f._get_action("breathe_on")
	_check(Enemy.channel_of(a) == 6, "the breath's continuation is a Channel 6")
	_check("Channel 6" in Enemy.describe_action(a), "the inspect line says Channel 6")
	var text := Enemy.description_for(Enemy.EnemyType.IFRIT)
	_check("6 more tempo" in text and "Channel 6" in text, "the compendium says so")
	var walls0: int = main._fire_walls.size()
	f.chosen_action = f._get_action("fire_breath")
	f.action_tempo_counter = 7
	var hp0 := _hp()
	_tempo()
	_check(_hp() < hp0, "the breath lands (%d)" % (hp0 - _hp()))
	_check(f.is_channeling() and str(f._channel_action.get("name", "")) == "breathe_on", "…and he keeps breathing (channeling)")
	_check(main._fire_walls.size() == walls0 + 1, "the 5x5 is alight")
	var wall: Dictionary = main._fire_walls.back() if main._fire_walls.size() > walls0 else {}
	# Stand beside him: a channeling Ifrit cannot strike or move.
	_place_player(_cell(f) + Vector2i(1, 0))
	var where := _cell(f)
	hp0 = _hp()
	var still_burning := 0
	var channel_tempo := 0
	for i in range(6):
		if f.is_channeling():
			channel_tempo += 1
		_tempo()
		if main._fire_walls.has(wall):
			still_burning += 1
	_check(channel_tempo == 6, "he channels for 6 tempo (%d)" % channel_tempo)
	_check(_hp() == hp0 and _cell(f) == where, "while breathing he neither strikes nor moves")
	_check(still_burning == 6, "the 5x5 burns all the while he breathes (%d of 6)" % still_burning)
	_check(not f.is_channeling(), "the channel is over after 6 tempo")
	_check(int(wall.get("tempo_left", 0)) <= 3 and main._fire_walls.has(wall), "once the breath is over the tiles burn on for 3 tempo (fuse %d)" % int(wall.get("tempo_left", 0)))
	for _i in range(3):
		_tempo()
	_check(not main._fire_walls.has(wall), "and then go out")
	# A stun cuts the breath short: the channel breaks and the flames go out.
	_reset_hp()
	f.chosen_action = f._get_action("fire_breath")
	f.action_tempo_counter = 7
	_tempo()
	_check(f.is_channeling(), "a second breath, breathing on")
	wall = main._fire_walls.back()
	_tempo()
	f.apply_stun(3)
	_check(not f.is_channeling(), "a stun breaks the channel")
	_check(main._fire_walls.has(wall) and int(wall["tempo_left"]) == 3, "…the breath is over: its tiles burn their last 3 tempo (fuse %d)" % int(wall["tempo_left"]))
	_despawn(f)
	_reset_hp()

func _test_ice_troll() -> void:
	print("-- Ice Troll: Clobber 'a 10 tempo cost if queued up or an auto trigger against a frozen enemy' --")
	_reset_hp()
	var t := _spawn(Enemy.EnemyType.ICE_TROLL, Vector2i(1, 0))
	var a: Dictionary = t._get_action("clobber")
	_check(str(a.get("name", "")) == "clobber" and int(a["tempo_cost"]) == 10, "Clobber is a 10-tempo action")
	_check(not Enemy.is_async_action(a) and not Enemy.is_trigger_action(a) and Enemy.channel_of(a) == 0, "…Sync, Immediate")
	_check("Clobber (10 tempo)" in Enemy.description_for(Enemy.EnemyType.ICE_TROLL), "the compendium says so")
	var seen := {}
	for _i in range(60):
		t.chosen_action = {}
		t._choose_ice_troll_action(1)
		seen[str(t.chosen_action.get("name", ""))] = true
	_check(seen.has("clobber") and seen.has("ice_club"), "in reach it queues Clobber as well as Club (%s)" % str(seen.keys()))
	t.chosen_action = {}
	t._choose_ice_troll_action(3)
	_check(str(t.chosen_action.get("name", "")) == "move", "out of reach it walks")
	var hp0 := _hp()
	t._execute_action("clobber", main.player)
	_check(hp0 - _hp() == _scaled(t, 50), "a queued Clobber deals 50 (band-scaled %d): %d" % [_scaled(t, 50), hp0 - _hp()])
	_check(_pdm().has_debuff(Debuff.DebuffType.COLD) and _pdm().has_debuff(Debuff.DebuffType.BRITTLE), "…and, like every Ice Troll attack, adds Cold and Brittle")
	# The auto trigger stays.
	_reset_hp()
	_pdm().apply_debuff(Debuff.create(Debuff.DebuffType.COLD, 4, 5))
	hp0 = _hp()
	t._try_ice_club(main.player)
	_check(hp0 - _hp() == t.attack_damage + _scaled(t, 50), "a freezing Club still triggers Clobber at once")
	_despawn(t)
	_reset_hp()

func _test_djinn_spell() -> void:
	print("-- Djinn: wishes 'per hit — so spells will be included' --")
	_reset_hp()
	var dj := _spawn(Enemy.EnemyType.DJINN, Vector2i(1, 0))
	dj.max_health = 10000
	dj.current_health = 10000
	var deck = main.deck_manager
	var spell: Card = null
	for id in ["spark", "fireball", "fire_bolt", "lightning_bolt", "magic_missile"]:
		var c: Card = Card.create_by_id(id)
		if c and c.school == Card.CardSchool.SPELL and c.is_offensive() and not c.is_attack():
			spell = c
			break
	_check(spell != null, "a damaging spell card to cast (%s)" % (spell.card_id if spell else "none"))
	if spell == null:
		_despawn(dj)
		return
	var st = _stats()
	st.max_mana = 1000
	st.current_mana = 1000
	st.current_attack_counter = 99
	deck.hand.clear()
	deck.hand.append(spell)
	main.tempo_manager.current_tempo = 0
	main.selected_card_index = 0
	var hp_dj: int = dj.current_health
	main.play_selected_card(dj)
	var guard := 0
	while guard < 40:
		var queued := false
		for e in main._pending_resolve_queue:
			queued = queued or e["card"] == spell
		if not queued:
			break
		main.tempo_manager._process_one_tick()
		guard += 1
	await _settle(2)
	var dealt: int = hp_dj - dj.current_health
	var wishes := 0
	for c in deck.hand:
		if c.card_id == "djinn_wish":
			wishes += 1
	_check(dealt > 0, "the spell hits the Djinn (%d)" % dealt)
	_check(wishes == 3, "a spell's hit puts 3 Wishes in the hand, as an attack's does (%d)" % wishes)
	_check("attacks and spells alike" in Enemy.description_for(Enemy.EnemyType.DJINN), "the compendium says hits, spells included")
	deck.hand.clear()
	_despawn(dj)
	_reset_hp()

## Enemy._unit_health reads a summon's `health` (Vampire's Absorb picks the
## healthiest unit; the Sabertooth's Track drops a quarry at 0).
func _test_unit_health_summon() -> void:
	print("-- A summon's health, as an enemy reads it --")
	main.deck_manager.maintained_cards.append(Card.create_by_id("spirit_bow"))
	main._summon_spirit_bow()
	var bow = main._spirit_bows.back() if main._spirit_bows.size() > 0 else null
	var e := _spawn(Enemy.EnemyType.SABERTOOTH, Vector2i(4, 0))
	_check(bow != null and e._unit_health(bow) == int(bow.health) and int(bow.health) > 0,
		"a living summon reads its health (%d)" % (e._unit_health(bow) if bow else -1))
	main._clear_spirit_bows()
	main.deck_manager.maintained_cards.clear()
