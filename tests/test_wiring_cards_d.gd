extends SceneTree

## Phase 2 wiring audit, card slice D (docs/audit/wiring/cards_d.md):
## poisoned_blood … skeleton_army. Every card is played through the real
## path where it can be (main.select_card + play_selected_card, the tempo
## clock drained tick by tick), so the mana and tempo it charges are the
## ones a player pays, and each check asserts what the card's text says.
## Instants are fired from their real trigger sites.
## Run: godot --headless --path . --script tests/test_wiring_cards_d.gd

var failures: int = 0
var main = null
var dm = null
var stats: PlayerStats = null
var bm: BuffManager = null
var dbm: DebuffManager = null
var tm = null
var _spawned: Array = []
var origin := Vector2i.ZERO        # an open patch of the dojo floor
var _playing: Card = null
var _probe: Callable
var snap: Dictionary = {}          # the state the moment the played card resolved

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	TempoManager.preferred_swing_hold = 0
	await _boot()
	if main == null:
		print("=== %d failure(s) ===" % failures)
		quit(1)
		return
	var tests := [
		"_t_poisoned_blood", "_t_poke", "_t_polymorph", "_t_poof_and_weave",
		"_t_potion_of_continuance", "_t_preemptive_answer", "_t_premeditated",
		"_t_preparation", "_t_prepare", "_t_protection_from_alnitak", "_t_provider",
		"_t_psionic_flow", "_t_purge_wrath", "_t_push", "_t_quick_arrow",
		"_t_quick_shot", "_t_raged_circulation", "_t_ragnarok", "_t_rain_of_arrows",
		"_t_reapers_taking", "_t_reckless_strike", "_t_regal_etching",
		"_t_release_soul", "_t_release_tension", "_t_reload", "_t_repelled_block",
		"_t_reposition", "_t_resourceful_replenish", "_t_return_cut",
		"_t_reverberate_regrowth", "_t_rise", "_t_risk_it", "_t_roar", "_t_roll",
		"_t_round_em_up", "_t_sanguine", "_t_savage_strike", "_t_savage_strike_copy",
		"_t_self_infliction", "_t_serene_center", "_t_shadows", "_t_shed_weight",
		"_t_shepherds_mark", "_t_shield_of_growth", "_t_shield_ready",
		"_t_shield_slam", "_t_shift", "_t_shiv", "_t_shuriken",
		"_t_shuriken_pouch", "_t_skeleton_army",
	]
	for t in tests:
		_reset()
		call(t)
		_cleanup()
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
	dm = main.deck_manager
	stats = main.player.get_stats()
	bm = main.player.get_buff_manager()
	dbm = main.player.get_debuff_manager()
	tm = main.tempo_manager
	# The dojo's own chickens would sit in every radius check: clear them.
	for e in main.enemy_spawner.get_living_enemies().duplicate():
		main.enemy_spawner.despawn_enemy(e)
	# A clear floor around the player for the movement cards: the dojo room
	# runs 4 squares left, 11 right, 3 down and well up from here.
	origin = main.grid_manager.world_to_grid(main.player.position) + Vector2i(-4, -2)
	_place_player(origin)
	# Connected after main's own handler: fires once the card has resolved.
	tm.card_resolved.connect(_on_resolved)

# ------------------------------------------------------------ helpers

func _reset() -> void:
	_drain()
	dm.hand.clear()
	dm.discard_pile.clear()
	dm.jail_pile.clear()
	dm.draw_pile.clear()
	for _i in range(12):
		dm.draw_pile.append(Card.create_by_id("slash"))
	dm.maintained_cards.clear()
	stats.maintained_mana = 0
	stats.max_health = 500
	stats.current_health = 500
	stats.current_armor = 0
	stats.current_temp_health = 0
	stats.max_mana = 3000
	stats.current_mana = 3000.0
	dbm.clear_all_debuffs()
	for b in bm.buffs.duplicate():
		bm.remove_buff_instance(b)
	# No crits: a -5% Keen cancels the innate 5% so every damage check is exact.
	bm.apply_buff(Buff.create_keen(-5, 99999, "test: no crits"))
	dm.prep_utility_discount = 0
	dm.prep_utility_charges = 0
	dm.prep_utility_persist = false
	_place_player(origin)

func _cleanup() -> void:
	_drain()
	for e in _spawned:
		if e and is_instance_valid(e):
			main.enemy_spawner.despawn_enemy(e)
	_spawned.clear()
	PlayerStats.heal_to_damage = false

func _drain() -> void:
	var guard := 0
	while tm._pending_ticks > 0 and guard < 200:
		tm._process_one_tick()
		guard += 1

func _cell() -> Vector2i:
	return main.grid_manager.world_to_grid(main.player.position)

func _place_player(cell: Vector2i) -> void:
	main.player.position = main._ground_pos(cell)
	main.player.target_position = main.player.position
	if "is_moving" in main.player:
		main.player.is_moving = false

func _dummy(offset: Vector2i) -> Enemy:
	## A training dummy `offset` cells from the player: stands still, never
	## strikes, a lethal blow refills it.
	var e: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.DUMMY, main._ground_pos(_cell() + offset))
	e.chosen_action = {}
	_spawned.append(e)
	return e

func _ecell(e) -> Vector2i:
	return main.grid_manager.world_to_grid(e.position)

func _aim(offset: Vector2i) -> Vector3:
	return main.grid_manager.snap_to_grid(main.grid_manager.grid_to_world(_cell() + offset))

func _on_resolved(card: Card) -> void:
	if card == _playing and snap.is_empty():
		_take_snap()

func _take_snap() -> void:
	snap = {"armor": stats.current_armor, "hp": stats.current_health, "mana": int(stats.current_mana),
		"invisible": bm.is_invisible(), "jail": _playing.jail_time_remaining,
		"in_jail": _playing in dm.jail_pile}
	if _probe.is_valid():
		snap["probe"] = _probe.call()

func _play(card: Card, target, aim = null, probe: Callable = Callable()) -> Dictionary:
	## Play `card` from the hand through main.play_selected_card, then drain
	## the tempo clock. Returns the mana it took and the ticks it queued;
	## `snap` holds the state the moment it resolved (and `probe`'s answer).
	_playing = card
	_probe = probe
	snap = {}
	if not (card in dm.hand):
		dm.hand.append(card)
	var idx: int = dm.hand.find(card)
	if aim != null:
		main._last_aim_world = aim
	var mana0: float = stats.current_mana
	main.select_card(idx)
	main.selected_card_index = idx
	main.play_selected_card(target)
	var mana_spent: int = int(round(mana0 - stats.current_mana))
	var ticks: int = tm._pending_ticks
	var played: bool = not (card in dm.hand) or card.sticky > 0
	if played and ticks == 0 and snap.is_empty():
		_take_snap()  # a 0-tempo card resolved inside the play
	_drain()
	_playing = null
	return {"mana": mana_spent, "tempo": ticks, "played": played}

func _cost_ok(r: Dictionary, mana: int, tempo: int) -> bool:
	return r["played"] and r["mana"] == mana and r["tempo"] == tempo

func _cost_msg(name: String, r: Dictionary, mana: int, tempo: int) -> String:
	return "%s charges %d mana / %d tempo through the play path (paid %d / %d)" % [name, mana, tempo, r["mana"], r["tempo"]]

func _no_crit_hit(card: Card) -> bool:
	return not bm.last_crit_hit

# ------------------------------------------------------------ cards

func _t_poisoned_blood() -> void:
	print("-- Poisoned Blood --")
	var c := Card.create_by_id("poisoned_blood")
	var r := _play(c, main.player)
	_check(_cost_ok(r, 10, 2), _cost_msg("Poisoned Blood", r, 10, 2))
	var pb = bm.get_buff(Buff.BuffType.POISONED_BLOOD)
	_check(pb != null and pb.charges == 5, "Poisoned Blood: 5 heal instances armed (%s)" % (str(pb.charges) if pb else "none"))
	# An ally healed under it is hurt instead.
	var ally = main._dojo_allies[0] if main._dojo_allies.size() > 0 else null
	if ally:
		var ast = ally.get_stats()
		ast.current_health = 200
		var heal := Card.create_by_id("heal")
		heal.mana_cost = 0
		_play(heal, ally)
		_check(ast.current_health < 200, "Poisoned Blood: a heal on an ally deals damage instead (%d)" % ast.current_health)
		_check(pb.charges == 4, "Poisoned Blood: that heal spent one instance (%d left)" % pb.charges)
	# Yourself.
	stats.current_health = 300
	var heal2 := Card.create_by_id("heal")
	heal2.mana_cost = 0
	_play(heal2, main.player)
	_check(stats.current_health < 300, "Poisoned Blood: a heal on yourself deals damage instead (%d)" % stats.current_health)
	# A summon.
	main._spawn_summon(20, main.player.position, "skeleton")
	var sk = main._skeletons.back() if main._skeletons.size() > 0 else null
	if sk:
		sk.health = 10
		var heal3 := Card.create_by_id("heal")
		bm.consume_poisoned_blood()  # (spent by execute below instead)
		bm.apply_buff(Buff.create_poisoned_blood(1, "Test"))
		heal3.execute(sk, stats, dm, 0.0, 0.0, bm)
		_check(sk.health < 10 or sk.is_dead, "Poisoned Blood: a heal on a summon deals damage instead (%d)" % sk.health)
		main._skeletons.erase(sk)
		sk.queue_free()
	PlayerStats.heal_to_damage = false
	bm.remove_buff(Buff.BuffType.POISONED_BLOOD)
	bm.apply_buff(Buff.create_poisoned_blood(5, "Test"))
	for _i in range(5):
		bm.consume_poisoned_blood()
	_check(not bm.has_poisoned_blood(), "Poisoned Blood: gone after 5 instances")

func _t_poke() -> void:
	print("-- Poke --")
	var d := _dummy(Vector2i(1, 0))
	var c := Card.create_by_id("poke")
	var hp0: int = d.current_health
	var r := _play(c, d)
	_check(_cost_ok(r, 0, 0), _cost_msg("Poke", r, 0, 0))
	var full: int = stats.get_effective_physical_damage(2)
	var want: int = 2 + floori((full - 2) / 2.0)
	_check(c.last_damage_dealt == want and hp0 - d.current_health == want,
		"Poke: 2 + half the modifiers (%d, want %d)" % [hp0 - d.current_health, want])
	_check(c.get_effective_range() == 0, "Poke is melee")

func _t_polymorph() -> void:
	print("-- Polymorph (instant) --")
	var c := Card.create_by_id("polymorph")
	_check(c.card_type == Card.CardType.REACTION and c.mana_cost == 0 and c.tempo_cost == 0, "Polymorph: a free instant")
	dm.hand.append(c)
	var refused: Dictionary = dm.play_card(dm.hand.find(c), null, main.player)
	_check(not refused["played"], "Polymorph cannot be played by hand")
	var mage: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.FIRE_GOBLIN_MAGE, main._ground_pos(_cell() + Vector2i(4, 0)))
	_spawned.append(mage)
	for dn in ["vulnerable", "weaken", "burn", "poison"]:
		mage.apply_debuff(dn, 1)
	_check(c in dm.hand and mage.polymorph_tempo == 0, "four distinct debuffs: not yet")
	mage.apply_debuff("bleed", 1)
	_check(not (c in dm.hand) and c in dm.jail_pile and c.jail_time_remaining == 25,
		"the 5th distinct debuff fires it, and it is jailed 25 tempo (%d)" % c.jail_time_remaining)
	_check(mage.polymorph_tempo > 0, "the enemy is a pig")
	_check(mage._ranged_reach(main.player) == 0, "a pig cannot shoot or cast — only walk and bite")
	mage._choose_action(main.player)
	var act := str(mage.chosen_action.get("name", ""))
	_check(Enemy.MOVEMENT_ACTIONS.has(act), "a pig walks — the mage's own move, never Ember (%s)" % act)
	mage.position = main._ground_pos(_cell() + Vector2i(1, 0))
	mage._choose_action(main.player)
	act = str(mage.chosen_action.get("name", ""))
	_check(act != "ember", "…even beside you a pig mage casts nothing (%s)" % act)
	var sold: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.FIRE_GOBLIN_SOLDIER, main._ground_pos(_cell() + Vector2i(0, 1)))
	_spawned.append(sold)
	sold.apply_debuff("polymorph", 5)
	sold._choose_action(main.player)
	var sact := str(sold.chosen_action.get("name", ""))
	_check(sact != "" and not Enemy.NON_MELEE_ACTIONS.has(sact), "a pig beside you makes its basic melee attack (%s)" % sact)
	tm.add_tempo(5)
	_check(mage.polymorph_tempo == 0, "the pig wears off after 5 tempo")

func _t_poof_and_weave() -> void:
	print("-- Poof and Weave --")
	var c := Card.create_by_id("poof_and_weave")
	var h0: int = dm.hand.size()
	var r := _play(c, main.player)
	_check(_cost_ok(r, 40, 5), _cost_msg("Poof and Weave", r, 40, 5))
	_check(snap.get("armor") == 10, "Poof and Weave: +10 armor (%s)" % str(snap.get("armor")))
	_check(dm.hand.size() == h0 + 1, "Poof and Weave: draws a card")
	_check(snap.get("invisible", false), "Poof and Weave: invisible")
	# It landed on tick 1 of 5; the tick it lands on counts, so 5 ticks end it.
	_check(not bm.is_invisible(), "the invisibility lasts 5 tempo")

func _t_potion_of_continuance() -> void:
	print("-- Potion of Continuance --")
	var c := Card.create_by_id("potion_of_continuance")
	var r := _play(c, main.player)
	_check(_cost_ok(r, 30, 2), _cost_msg("Potion of Continuance", r, 30, 2))
	_check(dm.hand.size() == 2, "Potion of Continuance: draws 2 (%d in hand)" % dm.hand.size())

func _t_preemptive_answer() -> void:
	print("-- Preemptive Answer (instant) --")
	var c := Card.create_by_id("preemptive_answer")
	dm.hand.append(c)
	for t in [Debuff.DebuffType.WEAKENED, Debuff.DebuffType.VULNERABLE, Debuff.DebuffType.SLOWED, Debuff.DebuffType.BLIND]:
		dbm.apply_debuff(Debuff.create(t, 1, 20))
	var n0: int = dbm.debuffs.size()
	stats.current_health = 150  # 30%
	var heals: Array = []
	var cb := func(amount, _a = null, _b = null): heals.append(int(amount))
	stats.healed.connect(cb)
	stats.take_damage(50, dbm, bm)  # -> 100 = 20%
	stats.healed.disconnect(cb)
	_check(not (c in dm.hand), "Preemptive Answer fires on the hit that drops you to 25%")
	_check(dbm.debuffs.size() == n0 - 3, "Preemptive Answer purges 3 debuffs (%d -> %d)" % [n0, dbm.debuffs.size()])
	_check(heals.size() == 1 and heals[0] == stats.get_effective_heal_amount(20),
		"Preemptive Answer heals 20 (+heal power) (%s)" % str(heals))

func _t_premeditated() -> void:
	print("-- Premeditated --")
	var d := _dummy(Vector2i(1, 0))
	d.current_armor = 3
	d.max_armor = maxi(d.max_armor, 3) if "max_armor" in d else 0
	var c := Card.create_by_id("premeditated")
	var r := _play(c, d)
	_check(_cost_ok(r, 20, 4), _cost_msg("Premeditated", r, 20, 4))
	_check(c.last_damage_dealt == stats.get_effective_physical_damage(8) or bm.last_crit_hit, "Premeditated: deals 8 (+modifiers)")
	_check(d.premeditated_card_bonus == 15, "Premeditated: breaking the armor marks the enemy for +15")
	var hp0: int = d.current_health
	var s := Card.create_by_id("slash")
	_play(s, d)
	var first: int = hp0 - d.current_health
	var hp1: int = d.current_health
	var s2 := Card.create_by_id("slash")
	_play(s2, d)
	var second: int = hp1 - d.current_health
	_check(first == second + 15, "the next card at that enemy deals +15 on top of its effect (%d vs %d)" % [first, second])
	_check(d.premeditated_card_bonus == 0, "…only the next one")

func _t_preparation() -> void:
	print("-- Preparation --")
	var c := Card.create_by_id("preparation")
	var r := _play(c, main.player)
	_check(_cost_ok(r, 30, 3), _cost_msg("Preparation", r, 30, 3))
	var d := _dummy(Vector2i(1, 0))
	_play(Card.create_by_id("slash"), d)  # an attack between does not break it
	var u1 := Card.create_by_id("reload")
	var r1 := _play(u1, main.player)
	_check(r1["mana"] == 30 - 20, "Preparation: the next utility card costs 2 less (%d)" % r1["mana"])
	var r2 := _play(Card.create_by_id("reload"), main.player)
	_check(r2["mana"] == 30 - 20, "Preparation: …and the one after (%d)" % r2["mana"])
	var r3 := _play(Card.create_by_id("reload"), main.player)
	_check(r3["mana"] == 30, "Preparation: the third pays full price (%d)" % r3["mana"])

func _t_prepare() -> void:
	print("-- Prepare --")
	var c := Card.create_by_id("prepare")
	var r := _play(c, main.player)
	_check(_cost_ok(r, 30, 0), _cost_msg("Prepare", r, 30, 0))
	_check(dm.hand.size() == 3, "Prepare: draws 3 (%d)" % dm.hand.size())
	dm.hand.clear()
	var held := Card.create_by_id("prepare")
	dm.hand.append(held)
	dm._process_erase_timers()
	_check(not (held in dm.hand) and not (held in dm.discard_pile), "Prepare: Erase 1 — erased at the next tick it sits in hand")

func _t_protection_from_alnitak() -> void:
	print("-- Protection From Alnitak --")
	var c := Card.create_by_id("protection_from_alnitak")
	dm.hand.append(Card.create_by_id("draw"))
	dm.hand.append(Card.create_by_id("draw"))
	var r := _play(c, main.player)
	_check(_cost_ok(r, 20, 1), _cost_msg("Protection From Alnitak", r, 20, 1))
	_check(snap.get("armor") == 10, "Protection From Alnitak: +10 armor (%s)" % str(snap.get("armor")))
	var br = bm.get_buff(Buff.BuffType.BRACE)
	var want: int = dm.get_hand_cap() - 2
	_check(br != null and br.value == want and br.charges == 5,
		"Brace = empty hand slots (%d%%) for 5 attacks (%s)" % [want, ("%d%% x%d" % [br.value, br.charges]) if br else "none"])

func _t_provider() -> void:
	print("-- Provider --")
	var ally = main._dojo_allies[0] if main._dojo_allies.size() > 0 else null
	if ally == null:
		_check(false, "the dojo has an ally dummy")
		return
	var ast = ally.get_stats()
	ast.current_health = 100
	ast.current_mana = 0.0
	var c := Card.create_by_id("provider")
	var r := _play(c, ally)
	_check(_cost_ok(r, 10, 1), _cost_msg("Provider", r, 10, 1))
	_check(ast.current_health == 100 + ast.get_effective_heal_amount(6), "Provider: heals the ally 6 (+their heal power) (%d)" % ast.current_health)
	_check(int(ast.current_mana) == 10, "Provider: gives the ally 1 mana (10 on the x10 scale) (%d)" % int(ast.current_mana))
	_check(c.get_effective_range() == 7, "Provider: ranged +2 (7)")
	dm.discard_pile.erase(c)
	var r2 := _play(c, ally)
	_check(_cost_ok(r2, 20, 2), "Provider: Burden — the second play costs +1 mana / +1 tempo (%d / %d)" % [r2["mana"], r2["tempo"]])

func _t_psionic_flow() -> void:
	print("-- Psionic Flow (instant) --")
	var d := _dummy(Vector2i(1, 0))
	var c := Card.create_by_id("psionic_flow")
	dm.hand.append(c)
	var s := Card.create_by_id("slash")
	var hp0: int = d.current_health
	_play(s, d)
	_check(not (c in dm.hand), "Psionic Flow fires when you play an attack")
	_check(hp0 - d.current_health == s.last_damage_dealt + 8, "…for +8 damage (%d vs %d)" % [hp0 - d.current_health, s.last_damage_dealt])
	_check(_ecell(d) == _cell() + Vector2i(2, 0), "…and pushes the target back 1 (%s)" % str(_ecell(d) - _cell()))
	# Guard mode: an ally within 3 squares is struck.
	var ally = main._dojo_allies[0] if main._dojo_allies.size() > 0 else null
	if ally:
		var c2 := Card.create_by_id("psionic_flow")
		dm.hand.append(c2)
		ally.position = main._ground_pos(_cell() + Vector2i(0, -2))
		var foe := _dummy(Vector2i(0, -3))
		var ast = ally.get_stats()
		ast.current_health = 200
		ast.current_armor = 0
		ast.last_attacker = foe
		ast.take_damage(20)
		_check(not (c2 in dm.hand), "Psionic Flow fires when an ally within 3 squares takes damage")
		_check(ast.current_health > 180, "…restoring 8 to them (%d)" % ast.current_health)
		_check(_ecell(foe) == _cell() + Vector2i(0, -4), "…and pushing the attacker back 1 (%s)" % str(_ecell(foe) - _cell()))
		# The other trigger then does nothing: the card is gone.
		var hp1: int = d.current_health
		var s2 := Card.create_by_id("slash")
		_play(s2, d)
		_check(hp1 - d.current_health == s2.last_damage_dealt, "whichever comes first: one card, one trigger")

func _t_purge_wrath() -> void:
	print("-- Purge Wrath --")
	var d := _dummy(Vector2i(1, 0))
	var plain := Card.create_by_id("slash")
	plain.execute(d, stats, dm, 0.0, 0.0, null)
	var base: int = plain.last_damage_dealt
	var inv = main.player.get_inventory()
	var sword = ItemData.create("fallens_wrath")
	inv.equip_item(sword, 0)
	sword.wrath = 20
	var c := Card.create_by_id("purge_wrath")
	var r := _play(c, main.player)
	_check(_cost_ok(r, 55, 8), _cost_msg("Purge Wrath", r, 55, 8))
	_check(sword.wrath == 0, "Purge Wrath: Wrath resets to 0")
	_check(stats.pending_wrath_percent == 20 and stats.pending_wrath_flat == floori(20 * sword.rider_scale()),
		"Purge Wrath: the next attack is armed with +20%% and the flat +%d" % stats.pending_wrath_flat)
	var s := Card.create_by_id("slash")
	var flat: int = stats.pending_wrath_flat
	_play(s, d)
	_check(s.last_damage_dealt > base + flat, "the next attack hits for its damage + the flat Wrath + Wrath%% (%d vs plain %d)" % [s.last_damage_dealt, base])
	_check(stats.pending_wrath_percent == 0 and stats.pending_wrath_flat == 0, "…and only that attack")
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)

func _t_push() -> void:
	print("-- Push --")
	var d := _dummy(Vector2i(1, 0))
	var c := Card.create_by_id("push")
	var r := _play(c, d)
	_check(_cost_ok(r, 10, 1), _cost_msg("Push", r, 10, 1))
	_check(_ecell(d) == _cell() + Vector2i(3, 0), "Push: the unit moves 2 squares away (%s)" % str(_ecell(d) - _cell()))

func _t_quick_arrow() -> void:
	print("-- Quick Arrow --")
	var d := _dummy(Vector2i(5, 0))
	var c := Card.create_by_id("quick_arrow")
	var hp0: int = d.current_health
	var r := _play(c, d)
	_check(r["played"] and r["mana"] == 0, "Quick Arrow: 0 mana (paid %d, %d tempo)" % [r["mana"], r["tempo"]])
	_check(hp0 - d.current_health == stats.get_effective_physical_damage(4), "Quick Arrow: deals 4 (+modifiers) at range 5 (%d)" % (hp0 - d.current_health))
	# Enchanted Quiver creates it after a ranged attack.
	bm.enchanted_quiver_charges = 1
	dm.hand.clear()
	_play(Card.create_by_id("quick_shot"), d)
	var made: Array = dm.hand.filter(func(h): return h.card_id == "quick_arrow")
	_check(made.size() == 1, "Enchanted Quiver puts a Quick Arrow in hand after a ranged attack")
	bm.enchanted_quiver_charges = 0

func _t_quick_shot() -> void:
	print("-- Quick Shot --")
	var d := _dummy(Vector2i(4, 0))
	var c := Card.create_by_id("quick_shot")
	var hp0: int = d.current_health
	var r := _play(c, d)
	_check(_cost_ok(r, 10, 1), _cost_msg("Quick Shot", r, 10, 1))
	var full: int = stats.get_effective_physical_damage(2)
	var want: int = 2 + floori((full - 2) / 2.0)
	_check(hp0 - d.current_health == want, "Quick Shot: 2 + half modifiers (%d, want %d)" % [hp0 - d.current_health, want])
	_check(dm.hand.size() == 1, "Quick Shot: draws a card")

func _t_raged_circulation() -> void:
	print("-- Raged Circulation --")
	var ally = main._dojo_allies[0] if main._dojo_allies.size() > 0 else null
	if ally == null:
		_check(false, "the dojo has an ally dummy")
		return
	var ast = ally.get_stats()
	ast.current_health = 100
	var plain: int = ast.get_effective_heal_amount(10)
	var c := Card.create_by_id("raged_circulation")
	ally.position = main._ground_pos(_cell() + Vector2i(0, 3))
	var r := _play(c, ally)
	_check(_cost_ok(r, 20, 2), _cost_msg("Raged Circulation", r, 20, 2))
	_check(is_equal_approx(ast.healing_boost_percent, 0.3), "Raged Circulation: the TARGET receives +30% healing")
	_check(is_equal_approx(stats.healing_boost_percent, 0.0), "…not the caster")
	ast.heal(10)
	_check(ast.current_health == 100 + floori(plain * 1.3), "a heal lands 30%% larger (%d)" % (ast.current_health - 100))
	ast.current_health = 100
	var abm = ally.get_buff_manager()
	abm.apply_buff(Buff.create_regen(10, 15, "Test"))
	abm.process_turn_start()
	_check(ast.current_health == 100 + floori(plain * 1.3), "regen lands 30%% larger too (%d)" % (ast.current_health - 100))
	abm.remove_buff(Buff.BuffType.REGEN)
	for _i in range(3):
		ast.process_turn()
	_check(ast.healing_boost_percent == 0.0, "Raged Circulation ends after 15 tempo")

func _t_ragnarok() -> void:
	print("-- Ragnarok --")
	var j1 := Card.create_by_id("slash")
	var j2 := Card.create_by_id("block")
	j1.jail_time_remaining = 20
	j2.jail_time_remaining = 20
	dm.jail_pile.append(j1)
	dm.jail_pile.append(j2)
	stats.current_health = 300
	bm.remove_buff(Buff.BuffType.KEEN)
	var c := Card.create_by_id("ragnarok")
	var r := _play(c, main.player)
	_check(_cost_ok(r, 45, 5), _cost_msg("Ragnarok", r, 45, 5))
	_check(j1 in dm.hand and j2 in dm.hand, "Ragnarok: every jailed card is released into the hand")
	_check(stats.current_health >= 300 + 20, "Ragnarok: heals 10 per released card (%d)" % (stats.current_health - 300))
	var keen = bm.get_buff(Buff.BuffType.KEEN)
	var might = bm.get_buff(Buff.BuffType.MIGHT)
	_check(keen != null and keen.value == 20 and might != null and might.value == 10,
		"Ragnarok: +10%% crit and +5 STR per card (%s / %s)" % [str(keen.value) if keen else "-", str(might.value) if might else "-"])
	_check(snap.get("in_jail", false) and snap.get("jail") == 30, "Ragnarok: jailed for 30 tempo after play (%s)" % str(snap.get("jail")))

func _t_rain_of_arrows() -> void:
	print("-- Rain of Arrows (Castle Wall Overdraw) --")
	var near := _dummy(Vector2i(2, 0))
	var far := _dummy(Vector2i(5, 0))
	var wall = ItemData.create("castle_wall")
	var inv = main.player.get_inventory()
	inv.equip_item(wall, 0)
	wall.overdraw_charges_left = 1
	var hn: int = near.current_health
	var hf: int = far.current_health
	var m0: float = stats.current_mana
	main._overdraw_cast_spell(wall)
	_check(hn - near.current_health == 10, "Rain of Arrows: 10 damage within 3 squares (%d)" % (hn - near.current_health))
	_check(hf == far.current_health, "…and nothing beyond")
	_check(int(m0 - stats.current_mana) == 45, "…for its 45 mana (%d)" % int(m0 - stats.current_mana))
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)

func _t_reapers_taking() -> void:
	print("-- Reaper's Taking (instant) --")
	var d := _dummy(Vector2i(4, 0))
	var c := Card.create_by_id("reapers_taking")
	dm.hand.append(c)
	d.current_health = 130  # 26% of 500
	d.take_damage(10, true)
	var hp: int = d.current_health
	_check(not (c in dm.hand), "Reaper's Taking fires when an enemy within 5 drops below 25%")
	_check(hp <= 120 - 20, "…and deals 20 (%d)" % hp)
	var dist: int = main.grid_manager.get_distance_in_cells(main.player.position, d.position)
	_check(dist <= 1, "…after teleporting beside it (distance %d)" % dist)

func _t_reckless_strike() -> void:
	print("-- Reckless Strike --")
	var d := _dummy(Vector2i(1, 0))
	var c := Card.create_by_id("reckless_strike")
	var hp0: int = d.current_health
	var r := _play(c, d)
	_check(_cost_ok(r, 10, 4), _cost_msg("Reckless Strike", r, 10, 4))
	_check(hp0 - d.current_health == stats.get_effective_physical_damage(15), "Reckless Strike: deals 15 (+modifiers) (%d)" % (hp0 - d.current_health))
	var wounds: Array = dm.draw_pile.filter(func(x): return x.card_id == "minor_wounds")
	_check(wounds.size() == 2, "Reckless Strike: 2 Minor Wounds added to your deck (%d)" % wounds.size())

func _t_regal_etching() -> void:
	print("-- Regal Etching --")
	var c := Card.create_by_id("regal_etching")
	dm.hand.append(c)
	var refused: Dictionary = dm.play_card(dm.hand.find(c), main.player, main.player)
	_check(not refused["played"], "Regal Etching: Engrave — refused while not slotted")
	var helm := ItemData.new()
	helm.item_type = ItemData.ItemType.HELM
	helm.card_slots = 1
	helm.slot_card(c)
	var r := _play(c, main.player)
	_check(_cost_ok(r, 5, 2), _cost_msg("Regal Etching", r, 5, 2))
	_check(dm.hand.size() == 1, "Regal Etching: draws a card")

func _t_release_soul() -> void:
	print("-- Release Soul --")
	var c := Card.create_by_id("release_soul")
	_check(c.in_hand_debuff == "drain_1" and c.held_damage_per_cycle == 5,
		"Release Soul: Drain while held, saps 5 per 5-tempo cycle (1 per tempo)")
	dm.hand.append(c)
	var hp0: int = stats.current_health
	dm.process_turn()
	_check(hp0 - stats.current_health == 5, "a cycle in hand saps 5 (%d)" % (hp0 - stats.current_health))
	var col: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.SPIRIT_COLLECTOR, main._ground_pos(_cell() + Vector2i(6, 6)))
	_spawned.append(col)
	col.chosen_action = {}
	var s0: int = col.strengthen_stacks
	var r := _play(c, main.player)
	_check(_cost_ok(r, 15, 2), _cost_msg("Release Soul", r, 15, 2))
	_check(col.strengthen_stacks == s0 + 5, "Release Soul: every Spirit Collector gains 5 Strengthen")
	_check(not (c in dm.discard_pile) and not (c in dm.hand), "Release Soul: released (erased), not discarded")

func _t_release_tension() -> void:
	print("-- Release Tension --")
	var d := _dummy(Vector2i(1, 0))
	d.apply_debuff("vulnerable", 2)
	d.apply_debuff("weaken", 2)
	var v0: int = d.vulnerable_stacks
	var w0: int = d.weaken_stacks
	stats.current_health = 300
	var c := Card.create_by_id("release_tension")
	c.rt_chosen_debuff = "weaken"
	var r := _play(c, d, null, func(): return [d.weaken_stacks, d.vulnerable_stacks])
	_check(_cost_ok(r, 30, 5), _cost_msg("Release Tension", r, 30, 5))
	var st: Array = snap.get("probe", [-1, -1])
	_check(st[0] == w0 - 1 and st[1] == v0, "Release Tension: one stack of the CHOSEN debuff comes off (weaken %d -> %d, vulnerable %d)" % [w0, st[0], st[1]])
	_check(stats.current_health == 300 + stats.get_effective_heal_amount(3), "Release Tension: heals 3 per debuff removed (%d)" % (stats.current_health - 300))

func _t_reload() -> void:
	print("-- Reload --")
	var c := Card.create_by_id("reload")
	var r := _play(c, main.player)
	_check(_cost_ok(r, 30, 3), _cost_msg("Reload", r, 30, 3))
	_check(dm.hand.size() == 3, "Reload: draws 3 (%d)" % dm.hand.size())

func _t_repelled_block() -> void:
	print("-- Repelled Block --")
	var c := Card.create_by_id("repelled_block")
	var r := _play(c, main.player)
	_check(_cost_ok(r, 30, 3), _cost_msg("Repelled Block", r, 30, 3))
	_check(snap.get("armor") == 5, "Repelled Block: +5 armor (%s)" % str(snap.get("armor")))
	stats.current_armor = 5
	var foe: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.FIRE_GOBLIN_SOLDIER, main._ground_pos(_cell() + Vector2i(1, 0)))
	_spawned.append(foe)
	foe.chosen_action = {}
	var start := _cell()
	var hp0: int = stats.current_health
	foe._deal_damage_to_player(main.player, 4, "test")
	_check(stats.current_health == hp0, "a fully blocked melee hit: 0 damage")
	_check(_ecell(foe) == start + Vector2i(5, 0), "…the enemy is pushed back 4 (%s)" % str(_ecell(foe) - start))
	_check(_cell() == start + Vector2i(-2, 0), "…and you are pushed back 2 (%s)" % str(_cell() - start))
	_check(not bm.has_buff(Buff.BuffType.REPELLED_BLOCK), "…and the stance is spent")
	# Armor that fails: the damage lands.
	_place_player(Vector2i(0, 0))
	stats.current_armor = 2
	bm.apply_buff(Buff.create_repelled_block("Test"))
	foe.position = main._ground_pos(_cell() + Vector2i(1, 0))
	var hp1: int = stats.current_health
	foe._deal_damage_to_player(main.player, 10, "test")
	_check(stats.current_health < hp1, "if the armor gives out, you take the damage")

func _t_reposition() -> void:
	print("-- Reposition --")
	var junk := Card.create_by_id("block")
	dm.hand.append(junk)
	var c := Card.create_by_id("reposition")
	c.picked_card = junk
	var r := _play(c, main.player)
	_check(_cost_ok(r, 10, 2), _cost_msg("Reposition", r, 10, 2))
	_check(junk in dm.discard_pile and not (junk in dm.hand), "Reposition: the chosen card is discarded")
	_check(dm.hand.size() == 1 and dm.hand[0].card_id == "slash", "Reposition: a new one is drawn")

func _t_resourceful_replenish() -> void:
	print("-- Resourceful Replenish --")
	var c := Card.create_by_id("resourceful_replenish")
	var r := _play(c, main.player)
	_check(_cost_ok(r, 20, 2), _cost_msg("Resourceful Replenish", r, 20, 2))
	_check(c in dm.maintained_cards, "Resourceful Replenish: maintained")
	var d := _dummy(Vector2i(1, 0))
	stats.current_health = 200
	var s := Card.create_by_id("slash")
	s.bonus_damage = 100
	_play(s, d)
	var healed: int = stats.current_health - 200
	# The same swing without it (other lifesteal sources stay in both).
	dm.maintained_cards.erase(c)
	stats.current_health = 200
	var s0 := Card.create_by_id("slash")
	s0.bonus_damage = 100
	_play(s0, d)
	var healed0: int = stats.current_health - 200
	var five: int = floori(s.last_damage_dealt * 0.05)
	_check(s0.last_damage_dealt == s.last_damage_dealt and healed - healed0 >= five and healed - healed0 <= five + 1,
		"your attacks heal 5%% of the damage dealt (+%d on %d)" % [healed - healed0, s.last_damage_dealt])

func _t_return_cut() -> void:
	print("-- Return Cut (instant) --")
	var foe := _dummy(Vector2i(1, 0))
	var c := Card.create_by_id("return_cut")
	dm.hand.append(c)
	stats.current_armor = 20
	stats.last_attacker = foe
	var hp0: int = foe.current_health
	stats.take_damage(5, dbm, bm)
	_check(not (c in dm.hand), "Return Cut fires when an attack fails to break your armor")
	_check(hp0 - foe.current_health == stats.get_effective_physical_damage(0) or hp0 > foe.current_health,
		"…and counters with a melee strike (%d)" % (hp0 - foe.current_health))

func _t_reverberate_regrowth() -> void:
	print("-- Reverberate Regrowth --")
	var c := Card.create_by_id("reverberate_regrowth")
	var r := _play(c, main.player)
	_check(_cost_ok(r, 55, 3), _cost_msg("Reverberate Regrowth", r, 55, 3))
	_check(c in dm.maintained_cards, "Reverberate Regrowth: maintained")
	stats.current_armor = 10
	stats.take_damage(15, dbm, bm)
	_check(stats.current_armor == 0, "the armor is broken through")
	tm.add_tempo(4)
	_check(stats.current_armor == 0, "…nothing comes back before 5 tempo")
	tm.add_tempo(1)
	_check(stats.current_armor == 10, "…the 10 armor the hit ate comes back 5 tempo later (%d)" % stats.current_armor)

func _t_rise() -> void:
	print("-- Rise --")
	var c := Card.create_by_id("rise")
	var aim := _aim(Vector2i(3, 0))
	var n0: int = main.active_pillars.size()
	main.mouse_override = Vector2(0, 0)  # the cursor has wandered off by the time it lands
	var r := _play(c, main.player, aim)
	main.mouse_override = Vector2(-1, -1)
	_check(_cost_ok(r, 10, 4), _cost_msg("Rise", r, 10, 4))
	_check(main.active_pillars.size() == n0 + 1, "Rise: a structure stands on the map")
	if main.active_pillars.size() > n0:
		var p: Vector3 = main.active_pillars.back()["position"]
		_check(main.grid_manager.world_to_grid(p) == _cell() + Vector2i(3, 0), "…on the aimed tile (%s)" % str(main.grid_manager.world_to_grid(p) - _cell()))

func _t_risk_it() -> void:
	print("-- Risk It --")
	var c := Card.create_by_id("risk_it")
	_check(c.rng_outcomes_data.size() == 1 and is_equal_approx(float(c.rng_outcomes_data[0]["percent"]), 30.0), "Risk It: a 30% chance")
	c.rng_selected_index = 0
	var r := _play(c, main.player)
	_check(_cost_ok(r, 10, 0), _cost_msg("Risk It", r, 10, 0))
	_check(dm.hand.any(func(h): return h.card_id == "biscuit"), "Risk It: on success you receive the Biscuit")
	dm.hand.clear()
	var c2 := Card.create_by_id("risk_it")
	c2.rng_selected_index = -2
	_play(c2, main.player)
	_check(not dm.hand.any(func(h): return h.card_id == "biscuit"), "Risk It: on a miss, nothing")

func _t_roar() -> void:
	print("-- Roar --")
	var near := _dummy(Vector2i(2, 0))
	var edge := _dummy(Vector2i(0, -3))
	var far := _dummy(Vector2i(0, -5))
	var c := Card.create_by_id("roar")
	var r := _play(c, main.player)
	_check(_cost_ok(r, 20, 0), _cost_msg("Roar", r, 20, 0))
	_check(_ecell(near) == _cell() + Vector2i(3, 0), "Roar: an enemy within 3 is knocked back 1 (%s)" % str(_ecell(near) - _cell()))
	_check(_ecell(edge) == _cell() + Vector2i(0, -4), "…an enemy 3 squares away too")
	_check(_ecell(far) == _cell() + Vector2i(0, -5), "…but not one 5 away")

func _t_roll() -> void:
	print("-- Roll --")
	var d := _dummy(Vector2i(3, 0))
	var c := Card.create_by_id("roll")
	var hp0: int = d.current_health
	var start := _cell()
	var r := _play(c, main.player, _aim(Vector2i(6, 0)), func(): return [d.is_disarmed, d.disarmed_tempo])
	_check(_cost_ok(r, 10, 5), _cost_msg("Roll", r, 10, 5))
	_check(_cell() == start + Vector2i(2, 0), "Roll: the roll ends on hitting a character (%s)" % str(_cell() - start))
	_check(hp0 - d.current_health == 10, "…an enemy takes 10 (%d)" % (hp0 - d.current_health))
	var dis: Array = snap.get("probe", [false, 0])
	_check(dis[0] and dis[1] == 5, "…and is disarmed for 5 tempo (%d)" % dis[1])
	_place_player(origin)
	d.position = main._ground_pos(origin + Vector2i(0, -6))
	var c2 := Card.create_by_id("roll")
	var s2 := _cell()
	_play(c2, main.player, _aim(Vector2i(9, 0)))
	_check(_cell() == s2 + Vector2i(5, 0), "Roll: X = its tempo cost, max 5 (%s)" % str(_cell() - s2))

func _t_round_em_up() -> void:
	print("-- Round 'Em Up --")
	var near := _dummy(Vector2i(6, 0))
	var far := _dummy(Vector2i(8, 0))
	var c := Card.create_by_id("round_em_up")
	main.mouse_override = Vector2(0, 0)
	var r := _play(c, main.player, _aim(Vector2i(4, 0)))
	main.mouse_override = Vector2(-1, -1)
	_check(_cost_ok(r, 20, 3), _cost_msg("Round 'Em Up", r, 20, 3))
	_check(_ecell(near) == _cell() + Vector2i(5, 0), "Round 'Em Up: an enemy 2 from the picked point is pulled toward it (%s)" % str(_ecell(near) - _cell()))
	_check(_ecell(far) == _cell() + Vector2i(8, 0), "…one outside the 5 diameter stays put")

func _t_sanguine() -> void:
	print("-- Sanguine the Penguin (instant) --")
	var c := Card.create_by_id("sanguine_the_penguin")
	dm.hand.append(c)
	var ruins = ItemData.create("nine_ruins_of_sanguine")
	ruins.vitality_stacks = 9
	main._clear_penguin()
	var ok: bool = main._try_call_penguin(ruins)
	_check(ok and not (c in dm.hand), "at 9 Vitality the instant fires")
	_check(ruins.vitality_stacks == 0, "…the stacks purge")
	var p = main._penguin
	_check(p != null and p.max_health == 50, "…Sanguine waddles forth with 50 HP")
	if p:
		_check(main.grid_manager.get_distance_in_cells(main.player.position, p.position) <= 1, "…beside you")
		_check(p.BASE_ATTACK == 8 and p.ATTACK_INTERVAL == 5, "…8 damage every 5 tempo")
		stats.current_health = 300
		p.take_damage(10)
		_check(stats.current_health == 300 + stats.get_effective_heal_amount(5), "damage he takes heals you half as much (%d)" % (stats.current_health - 300))
		var d := _dummy(Vector2i(4, 4))
		d.position = main._ground_pos(main.grid_manager.world_to_grid(p.position) + Vector2i(1, 0))
		var hp0: int = d.current_health
		main._update_penguin(5)
		_check(hp0 - d.current_health == p.outgoing_damage(8), "…and pecks a neighbour for 8 (%d)" % (hp0 - d.current_health))
	main._clear_penguin()

func _t_savage_strike() -> void:
	print("-- Savage Strike --")
	var d := _dummy(Vector2i(1, 0))
	var c := Card.create_by_id("savage_strike")
	var hp0: int = d.current_health
	var r := _play(c, d)
	_check(_cost_ok(r, 20, 2), _cost_msg("Savage Strike", r, 20, 2))
	_check(hp0 - d.current_health == stats.get_effective_physical_damage(6), "Savage Strike: deals 6 (+modifiers)")
	var copies: Array = dm.discard_pile.filter(func(x): return x.card_id == "savage_strike_copy")
	_check(copies.size() == 1, "Savage Strike: a copy lands in the discard pile")
	if copies.size() == 1:
		_check(copies[0].erase_tempo == 20 and copies[0].erase_tempo_remaining == 20, "…the copy has Erase 20")

func _t_savage_strike_copy() -> void:
	print("-- Savage Strike (copy) --")
	var d := _dummy(Vector2i(1, 0))
	var c := Card.create_by_id("savage_strike_copy")
	var hp0: int = d.current_health
	var r := _play(c, d)
	_check(_cost_ok(r, 20, 2), _cost_msg("Savage Strike copy", r, 20, 2))
	_check(hp0 - d.current_health == stats.get_effective_physical_damage(6), "the copy deals 6 (+modifiers)")
	_check(not dm.discard_pile.any(func(x): return x != c and x.card_id == "savage_strike_copy"), "the copy makes no further copy")
	var held := Card.create_by_id("savage_strike_copy")
	dm.hand.append(held)
	for _i in range(3):
		dm._process_erase_timers()
	_check(held in dm.hand, "Erase 20: still there after 15 tempo in hand")
	dm._process_erase_timers()
	_check(not (held in dm.hand), "Erase 20: erased after 20 tempo in hand")

func _t_self_infliction() -> void:
	print("-- Self Infliction --")
	stats.current_health = 400
	var c := Card.create_by_id("self_infliction")
	var r := _play(c, main.player)
	_check(_cost_ok(r, 20, 3), _cost_msg("Self Infliction", r, 20, 3))
	_check(stats.current_health == 80, "Self Infliction: 80%% of remaining health dealt to self (400 -> %d)" % stats.current_health)
	var might = bm.get_buff(Buff.BuffType.MIGHT)
	_check(might != null and might.value == 5 and might.duration <= 10 and might.duration > 0, "…+5 strength for 10 tempo")
	_check(stats.get_temp_determination_bonus() == 5 and stats._temp_det_buffs.any(func(b): return int(b["amount"]) == 5 and int(b["tempo"]) <= 10 and int(b["tempo"]) > 0), "…+5 determination for 10 tempo")

func _t_serene_center() -> void:
	print("-- Serene Center --")
	stats.max_mana = 200
	stats.current_mana = 40.0
	stats.current_health = 450
	stats.current_temp_health = 100
	stats.temp_health_tempo_remaining = 20
	var c := Card.create_by_id("serene_center")
	var r := _play(c, main.player)
	_check(r["played"] and r["tempo"] == 4, "Serene Center: plays for %d tempo" % r["tempo"])
	_check(snap.get("hp") == 300 and stats.current_temp_health == 0, "health = half max + half temp, temp consumed (450+100t -> %s)" % str(snap.get("hp")))
	_check(snap.get("mana") == 100, "mana = half its maximum, raised from 1 (%s)" % str(snap.get("mana")))
	stats.current_mana = 190.0
	stats.current_health = 490
	_play(Card.create_by_id("serene_center"), main.player)
	_check(snap.get("hp") == 250 and snap.get("mana") == 100, "…or lowered (%s hp, %s mana)" % [str(snap.get("hp")), str(snap.get("mana"))])

func _t_shadows() -> void:
	print("-- Shadows --")
	var c := Card.create_by_id("shadows")
	var r := _play(c, main.player)
	_check(_cost_ok(r, 10, 4), _cost_msg("Shadows", r, 10, 4))
	_check(snap.get("invisible", false), "Shadows: invisible")
	# Landed on tick 1 of 4 (the landing tick counts): 4 of its 10 are gone.
	tm.add_tempo(5)
	_check(bm.is_invisible(), "…still at 9 tempo")
	tm.add_tempo(1)
	_check(not bm.is_invisible(), "…gone after 10 tempo")

func _t_shed_weight() -> void:
	print("-- Shed Weight --")
	var blk := Card.create_by_id("block")
	var veng := Card.create_by_id("vengeful_shield")
	var sl := Card.create_by_id("slash")
	dm.hand.append(blk)
	dm.hand.append(veng)
	dm.hand.append(sl)
	var c := Card.create_by_id("shed_weight")
	var r := _play(c, main.player)
	_check(_cost_ok(r, 40, 2), _cost_msg("Shed Weight", r, 40, 2))
	_check(not (blk in dm.hand) and not (veng in dm.hand), "Shed Weight: every defensive card is discarded — the Defense type and the defense-tagged instant")
	_check(sl in dm.hand and sl.temp_hand_tempo_reduction == 2, "…and the non-defensive card loses 1 tempo per card discarded (%d)" % sl.temp_hand_tempo_reduction)

func _t_shepherds_mark() -> void:
	print("-- Shepherd's Mark --")
	var ally = main._dojo_allies[0] if main._dojo_allies.size() > 0 else null
	if ally == null:
		_check(false, "the dojo has an ally dummy")
		return
	ally.position = main._ground_pos(_cell() + Vector2i(0, 3))
	var lvl: int = stats.get_passive_level("whispers_of_the_flock")
	var arm: int = PassiveScaling.value("whispers_of_the_flock", "armor", lvl)
	var c := Card.create_shepherds_mark(arm)
	_check(c.erase_tempo == 10 and c.school == Card.CardSchool.SPELL and c.get_effective_range() == 7, "Shepherd's Mark: a ranged 7 spell with Erase 10")
	var r := _play(c, ally)
	_check(_cost_ok(r, 0, 0), _cost_msg("Shepherd's Mark", r, 0, 0))
	var ast = ally.get_stats()
	_check(ast.st_whispers_active and ast.st_whispers_tempo == 10, "the ally is marked for 10 tempo")
	ast.current_health = 20
	ast.current_armor = 0
	stats.current_health = 300
	# The dojo dog refills itself the moment it reaches 0; unhook that so the
	# hit is the lethal one a real ally would take.
	var refills: Array = ast.health_changed.get_connections()
	for conn in refills:
		ast.health_changed.disconnect(conn["callable"])
	ast.take_damage(500)
	for conn in refills:
		ast.health_changed.connect(conn["callable"])
	_check(ast.current_health == 1, "a lethal hit leaves them at 1 HP")
	_check(ast.current_armor == arm, "…with %d armor, the number on the card" % arm)
	_check(300 - stats.current_health == 8, "…and the caster takes 8 (%d)" % (300 - stats.current_health))

func _t_shield_of_growth() -> void:
	print("-- Shield of Growth --")
	var c := Card.create_by_id("shield_of_growth")
	var r := _play(c, main.player)
	_check(_cost_ok(r, 40, 5), _cost_msg("Shield of Growth", r, 40, 5))
	stats.current_armor = 0
	stats.take_damage(7, dbm, bm)
	_check(stats.current_armor == 7, "Shield of Growth: damage done to you grows your armor (%d)" % stats.current_armor)
	_check(not dbm.can_play_attack_cards(), "…and you are disarmed")
	# It landed on tick 1 of 5 (the landing tick counts): 5 of its 10 are gone.
	tm.add_tempo(4)
	_check(bm.has_buff(Buff.BuffType.SHIELD_OF_GROWTH) and not dbm.can_play_attack_cards(), "…still at 9 tempo")
	tm.add_tempo(1)
	_check(not bm.has_buff(Buff.BuffType.SHIELD_OF_GROWTH) and dbm.can_play_attack_cards(), "…both end after 10 tempo")

func _t_shield_ready() -> void:
	print("-- Shield Ready --")
	var c := Card.create_by_id("shield_ready")
	_check(c.requires_engraving, "Shield Ready: Engrave")
	c.slotted_in_item = ItemData.new()
	var r := _play(c, main.player)
	_check(_cost_ok(r, 20, 4), _cost_msg("Shield Ready", r, 20, 4))
	_check(snap.get("armor") == 5, "Shield Ready: +5 armor now (%s)" % str(snap.get("armor")))
	# Landed on tick 1 of 4 (the landing tick counts): 4 of the 5 have passed.
	var a4: int = stats.current_armor
	tm.add_tempo(1)
	_check(stats.current_armor == a4 + 5, "…5 more 5 tempo later (%d -> %d)" % [a4, stats.current_armor])

func _t_shield_slam() -> void:
	print("-- Shield Slam --")
	var d := _dummy(Vector2i(1, 0))
	var c := Card.create_by_id("shield_slam")
	_check(c.requires_engraving and c.resolve_tick == 7, "Shield Slam: Engrave, lands on tick 7")
	c.slotted_in_item = ItemData.new()
	stats.current_armor = 30
	var hp0: int = d.current_health
	var probe := func(): return [hp0 - d.current_health, stats.current_armor]
	var r := _play(c, d, null, probe)
	_check(_cost_ok(r, 50, 10), _cost_msg("Shield Slam", r, 50, 10))
	var got: Array = snap.get("probe", [0, 0])
	# Armor decays 2 a cycle, so the armor it reads is what is left on tick 7.
	_check(got[0] > 0 and got[0] >= 30 - 4 and got[0] <= 30, "Shield Slam: damage = your current armor (%d)" % got[0])
	_check(got[1] == got[0] / 2, "…then you lose half your armor (%d left of %d)" % [got[1], got[0]])

func _t_shift() -> void:
	print("-- shift --")
	var c := Card.create_by_id("shift")
	var start := _cell()
	var r := _play(c, main.player, _aim(Vector2i(2, 0)))
	_check(_cost_ok(r, 0, 0), _cost_msg("shift", r, 0, 0))
	_check(_cell() == start + Vector2i(2, 0), "shift: move up to 2 spaces (%s)" % str(_cell() - start))
	var c2 := Card.create_by_id("shift")
	var s2 := _cell()
	_play(c2, main.player, _aim(Vector2i(3, 0)))
	_check(_cell() == s2, "…not 3")

func _t_shiv() -> void:
	print("-- Shiv --")
	var d := _dummy(Vector2i(1, 0))
	var c := Card.create_by_id("shiv")
	var hp0: int = d.current_health
	var r := _play(c, d)
	_check(_cost_ok(r, 5, 1), _cost_msg("Shiv", r, 5, 1))
	_check(c.get_effective_range() == 0, "Shiv: melee")
	_check(hp0 - d.current_health == stats.get_effective_physical_damage(2), "Shiv: 2 damage (+modifiers) (%d)" % (hp0 - d.current_health))

func _t_shuriken() -> void:
	print("-- Shuriken --")
	var near := _dummy(Vector2i(2, 0))
	var far := _dummy(Vector2i(6, 0))
	var c := Card.create_by_id("shuriken")
	var hn: int = near.current_health
	var hf: int = far.current_health
	var r := _play(c, main.player)
	_check(_cost_ok(r, 0, 0), _cost_msg("Shuriken", r, 0, 0) + " — Free")
	_check(hn - near.current_health == main._card_player_damage(c), "Shuriken: 3 (+modifiers) to an enemy within range (%d)" % (hn - near.current_health))
	_check(hf == far.current_health, "…never one out of range (3)")

func _t_shuriken_pouch() -> void:
	print("-- Shuriken Pouch --")
	var d := _dummy(Vector2i(2, 0))
	var c := Card.create_by_id("shuriken_pouch")
	var r := _play(c, main.player)
	_check(_cost_ok(r, 30, 2), _cost_msg("Shuriken Pouch", r, 30, 2))
	var om = main.overflow_manager
	var eff = om.get_first_effect_of_type(OverflowEffect.OverflowType.MANIFEST)
	_check(eff != null and eff.manifest_effect_id == "shuriken" and eff.charges == 3, "Shuriken Pouch: Manifest 3")
	var over := Card.create_by_id("block")
	om.process_overflow(over)
	var zone: Array = om.get_manifest_zone()
	_check(zone.size() > 0 and zone.back()["manifest_id"] == "shuriken" and zone.back()["card"] == over, "an overflow card becomes a Shuriken")
	_check(zone.size() > 0 and zone.back()["mana_cost"] == 0 and zone.back()["tempo_cost"] == 0, "…free")
	var hp0: int = d.current_health
	var att0: int = stats.attacks_this_cycle if "attacks_this_cycle" in stats else -1
	main._on_manifest_card_clicked(zone.size() - 1)
	_check(hp0 - d.current_health == 3, "the Shuriken deals 3 to a random enemy (%d)" % (hp0 - d.current_health))
	for e in om.overflow_effects.duplicate():
		om.remove_overflow_effect(e)

func _t_skeleton_army() -> void:
	print("-- Skeleton Army --")
	for s in main._skeletons.duplicate():
		if is_instance_valid(s):
			s.queue_free()
	main._skeletons.clear()
	var c := Card.create_by_id("skeleton_army")
	main.mouse_override = Vector2(0, 0)
	var aim := _aim(Vector2i(0, -3))
	var r := _play(c, main.player, aim, func(): return main._skeletons.filter(func(s): return is_instance_valid(s) and s.kind == "card_skeleton").map(func(s): return main.grid_manager.world_to_grid(s.position)))
	main.mouse_override = Vector2(-1, -1)
	_check(_cost_ok(r, 130, 7), _cost_msg("Skeleton Army", r, 130, 7))
	var sk: Array = main._skeletons.filter(func(s): return is_instance_valid(s) and s.kind == "card_skeleton")
	_check(sk.size() == 4, "Skeleton Army: 4 skeletons (%d)" % sk.size())
	var ok := true
	for s in sk:
		if not (s.max_health == 10 and s.base_attack == 6 and s.attack_interval == 5 and s.move_steps == 1 and s.move_interval == 1):
			ok = false
	_check(ok, "…10 HP each, move 1 every tempo, 6 damage every 5 tempo")
	var at: Array = snap.get("probe", [])
	var acell: Vector2i = main.grid_manager.world_to_grid(aim)
	var near := at.filter(func(cc): return absi(cc.x - acell.x) <= 1 and absi(cc.y - acell.y) <= 1)
	_check(at.size() == 4 and near.size() == 4 and acell in at, "…standing up on and around the aimed point (%s)" % str(at.map(func(cc): return cc - acell)))
