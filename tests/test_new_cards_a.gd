extends SceneTree

## New sheet cards, batch A (docs/new_cards/A.md): The Wolf's Howl, Spirit
## Armor, Ember Heart, Lodestone Field, Warden's Hound, War Shout, Stone
## Wheel, Arcane Tide, Clarity. Every card is played through the real play
## path in a booted main.tscn (the dojo): DeckManager.play_card charges the
## mana, TempoManager ticks the card's tempo, main resolves it and runs its
## world effects; the maintains are then driven by real tempo and cycles.
## Run: godot --headless --path . --script tests/test_new_cards_a.gd

var failures := 0
var passes := 0
var main = null
var stats: PlayerStats
var dm: DeckManager
var tm: TempoManager
var gm
var bm: BuffManager
var dbm: DebuffManager
var _t0 := 0
var _cycles := 0
var _focus_payouts := 0
var _armor_gained := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		passes += 1
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _settle(frames: int = 6) -> void:
	for _i in range(frames):
		await process_frame

func _run() -> void:
	print("=== New cards: batch A ===")
	TempoManager.preferred_swing_hold = 0  # resolve on the tick, no swing wait
	await _boot()
	if main == null:
		print("=== %d failure(s) ===" % failures)
		quit(1)
		return
	_test_wolfs_howl()
	_test_spirit_armor()
	_test_ember_heart()
	_test_lodestone_field()
	_test_wardens_hound()
	_test_war_shout()
	_test_stone_wheel()
	_test_arcane_tide()
	_test_clarity()
	print("=== %d passed, %d failure(s) ===" % [passes, failures])
	quit(1 if failures > 0 else 0)

# ---------------------------------------------------------------- harness

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
	if main.player == null or main._dojo_allies.size() < 2:
		_check(false, "the dojo is up with its two ally dummies")
		main = null
		return
	stats = main.player.get_stats()
	dm = main.deck_manager
	tm = main.tempo_manager
	gm = main.grid_manager
	bm = main.player.get_buff_manager()
	dbm = main.player.get_debuff_manager()
	tm.tempo_threshold_reached.connect(func(times): _cycles += times)
	stats.mana_gained.connect(func(amount, _regen = false):
		if int(amount) == 10 and not _regen:
			_focus_payouts += 1)
	stats.armor_gained.connect(func(amount): _armor_gained += int(amount))

func _pc() -> Vector2i:
	return gm.world_to_grid(main.player.position)

func _ally(i: int = 0):
	return main._dojo_allies[i]

## Stand an ally dummy at a grid offset from the player.
func _place(ally, off: Vector2i) -> void:
	var w: Vector3 = main._ground_pos(_pc() + off)
	ally.position = w
	ally.target_position = w

## Clear the field and stand fresh dummies at these offsets from the player.
func _field(offsets: Array) -> Array:
	var old: Array = main.enemy_spawner.enemies.duplicate()
	var out: Array = []
	for off in offsets:
		var e: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.DUMMY, main._ground_pos(_pc() + off))
		e.chosen_action = {}
		e.max_health = 1000
		e.current_health = 1000
		e.current_armor = 0
		out.append(e)
	for e in old:
		main.enemy_spawner.despawn_enemy(e)
	return out

func _lost(e) -> int:
	return e.max_health - e.current_health

func _drain() -> void:
	var guard := 0
	while tm._pending_ticks > 0 and guard < 200:
		tm._process_one_tick()
		guard += 1

## A clean slate: nothing queued, empty piles, no statuses, no maintains,
## plenty of health and mana, no stray crits, the allies parked far away.
func _fresh() -> void:
	_drain()
	main._pending_resolve_queue.clear()
	main.draw_timer.tempo_until_draw = 1e9
	dm.hand.clear()
	dm.draw_pile.clear()
	dm.discard_pile.clear()
	dm.jail_pile.clear()
	dm.maintained_cards.clear()
	stats.maintained_mana = 0
	dm.maintained_changed.emit()
	bm.buffs.clear()
	dbm.clear_all_debuffs()
	for a in main._dojo_allies:
		a.get_buff_manager().buffs.clear()
		a.get_stats().current_armor = 0
	_place(_ally(0), Vector2i(0, -9))
	_place(_ally(1), Vector2i(1, -9))
	stats.equipment_crit_bonus = -5.0  # cancels the innate 5%
	stats.max_health = 500
	stats.current_health = 500
	stats.current_temp_health = 0
	stats.current_armor = 0
	stats.max_mana = 2000
	stats.current_mana = 1000
	_field([])
	NewCardsA.tick(main)

func _queued(card: Card) -> bool:
	for e in main._pending_resolve_queue:
		if e["card"] == card:
			return true
	return false

## Play `card` through main.play_selected_card and run its whole tempo.
## Returns what the play charged.
func _play(card: Card, target) -> Dictionary:
	if not (card in dm.hand):
		dm.hand.append(card)
	main.selected_card_index = dm.hand.find(card)
	main._card_play_confirmed = true
	var m0: float = stats.current_mana
	_t0 = tm.global_tempo
	main.play_selected_card(target)
	var spent := int(round(m0 - stats.current_mana))
	var played: bool = not (card in dm.hand)
	_drain()
	return {"played": played, "mana": spent, "tempo": tm.global_tempo - _t0}

func _costs(r: Dictionary, mana: int, tempo: int) -> bool:
	return r["played"] and r["mana"] == mana and r["tempo"] == tempo

func _cost_str(r: Dictionary) -> String:
	return "played %s, %d mana / %d tempo" % [str(r["played"]), r["mana"], r["tempo"]]

func _tempo(n: int) -> void:
	for _i in range(n):
		tm.add_tempo(1)

## Tick one tempo at a time until the next cycle start has run.
func _to_next_cycle() -> void:
	var c0 := _cycles
	var guard := 0
	while _cycles == c0 and guard < 10:
		tm.add_tempo(1)
		guard += 1

func _strengthen(mgr: BuffManager) -> int:
	return mgr.get_strengthen_bonus()

func _timed_keen(mgr: BuffManager) -> Buff:
	return mgr._timed_keen()

## One Slash through the real path on a fresh dummy: the damage it dealt.
func _slash() -> int:
	var e: Enemy = _field([Vector2i(1, 0)])[0]
	_play(Card.create_by_id("slash"), e)
	return _lost(e)

# ---------------------------------------------------------------- cards

func _test_wolfs_howl() -> void:
	print("-- The Wolf's Howl --")
	_fresh()
	var base := _slash()
	var near = _ally(0)
	var far = _ally(1)
	_place(near, Vector2i(0, -2))
	_place(far, Vector2i(0, -3))
	var howl := Card.create_by_id("the_wolfs_howl")
	var r := _play(howl, main.player)
	_check(_costs(r, 180, 5), "The Wolf's Howl costs 180 mana / 5 tempo (%s)" % _cost_str(r))
	_check(dm.maintained_cards.has(howl) and stats.maintained_mana == 180, "it is maintained, reserving 180 mana (%d)" % stats.maintained_mana)
	_check(_strengthen(bm) == 5, "the howler has Strengthen 5 (%d)" % _strengthen(bm))
	_check(_strengthen(near.get_buff_manager()) == 5, "an ally 2 squares away has Strengthen 5 (%d)" % _strengthen(near.get_buff_manager()))
	_check(_strengthen(far.get_buff_manager()) == 0, "an ally 3 squares away has none (%d)" % _strengthen(far.get_buff_manager()))
	# An aura, not a grant: attacks do not spend it.
	var hits: Array = []
	for _i in range(4):
		hits.append(_slash())
	_check(hits.min() == hits.max() and hits[0] > base, "four Slashes in the howl all hit harder than one without (%s vs %d)" % [str(hits), base])
	_check(_strengthen(bm) == 5, "after four attacks the howl is still Strengthen 5 (%d)" % _strengthen(bm))
	# A carded Strengthen rides beside it and spends its own attacks.
	bm.apply_buff(Buff.create_strengthen(3, 2, "test"))
	_check(_strengthen(bm) == 8 and NewCardsA.howl_aura_of(bm).value == 5, "a carded Strengthen 3 stands beside the aura (total %d, aura %d)" % [_strengthen(bm), NewCardsA.howl_aura_of(bm).value])
	_slash()
	_slash()
	_check(_strengthen(bm) == 5, "once its 2 attacks are spent only the howl's 5 remains (%d)" % _strengthen(bm))
	# The aura follows positions every tempo.
	_place(far, Vector2i(1, -1))
	_place(near, Vector2i(0, -4))
	_tempo(1)
	_check(_strengthen(far.get_buff_manager()) == 5, "an ally who steps in gains it on the next tempo (%d)" % _strengthen(far.get_buff_manager()))
	_check(_strengthen(near.get_buff_manager()) == 0, "an ally who steps out loses it (%d)" % _strengthen(near.get_buff_manager()))
	_tempo(12)
	_check(_strengthen(bm) == 5 and _strengthen(far.get_buff_manager()) == 5, "it does not run out while they stand in it (12 tempo on)")
	# Dropping the maintain ends it at once.
	dm.dismiss_maintained_card(dm.maintained_cards.find(howl))
	_check(_strengthen(bm) == 0 and _strengthen(far.get_buff_manager()) == 0, "dismissing the maintain ends the aura (%d / %d)" % [_strengthen(bm), _strengthen(far.get_buff_manager())])
	_check(_slash() == base, "a Slash after the howl ends is back to its base damage")

func _test_spirit_armor() -> void:
	print("-- Spirit Armor --")
	_fresh()
	var near = _ally(0)
	var far = _ally(1)
	_place(near, Vector2i(0, -5))
	_place(far, Vector2i(0, -6))
	var sa := Card.create_by_id("spirit_armor")
	var r := _play(sa, main.player)
	_check(_costs(r, 90, 4), "Spirit Armor costs 90 mana / 4 tempo (%s)" % _cost_str(r))
	_check(dm.maintained_cards.has(sa) and stats.maintained_mana == 90, "it is maintained, reserving 90 mana")
	_armor_gained = 0
	near.get_stats().current_armor = 0
	_to_next_cycle()
	_check(_armor_gained == 2, "the caster gains 2 armor at the cycle start (%d)" % _armor_gained)
	_check(near.get_stats().current_armor == 2, "an ally 5 squares away gains 2 armor (%d)" % near.get_stats().current_armor)
	_check(far.get_stats().current_armor == 0, "an ally 6 squares away gains none (%d)" % far.get_stats().current_armor)
	_to_next_cycle()
	_check(near.get_stats().current_armor == 4, "and 2 more the next cycle (%d)" % near.get_stats().current_armor)
	dm.dismiss_maintained_card(dm.maintained_cards.find(sa))
	_to_next_cycle()
	_check(near.get_stats().current_armor == 4, "nothing once the maintain is dropped (%d)" % near.get_stats().current_armor)

func _test_ember_heart() -> void:
	print("-- Ember Heart --")
	_fresh()
	var eh := Card.create_by_id("ember_heart")
	var r := _play(eh, main.player)
	_check(_costs(r, 90, 1), "Ember Heart costs 90 mana / 1 tempo (%s)" % _cost_str(r))
	_check(dm.maintained_cards.has(eh) and stats.maintained_mana == 90, "it is maintained, reserving 90 mana")
	# Exact numbers: one cycle pass of the maintain.
	var e: Enemy = _field([Vector2i(0, -4)])[0]
	dbm.apply_debuff(Debuff.create(Debuff.DebuffType.BURN, 5, 15))
	NewCardsA.cycle(main)
	var burn = dbm.get_debuff(Debuff.DebuffType.BURN)
	_check(burn != null and burn.value == 3, "2 of the caster's 5 Burn leave (%d left)" % (burn.value if burn else 0))
	_check(e.burn_stacks == 2, "the enemy 4 squares away takes the 2 Burn (%d)" % e.burn_stacks)
	_check(_lost(e) == 6, "each stack deals 3 as it lands: 6 (%d)" % _lost(e))
	# A single stack moves alone and the Burn is gone.
	burn.value = 1
	NewCardsA.cycle(main)
	_check(dbm.get_debuff(Debuff.DebuffType.BURN) == null, "a lone stack transfers and the caster's Burn ends")
	_check(e.burn_stacks == 3 and _lost(e) == 9, "the enemy has 3 Burn and took 3 more (%d Burn, %d lost)" % [e.burn_stacks, _lost(e)])
	# Nobody in reach: the Burn stays.
	e = _field([Vector2i(0, -5)])[0]
	dbm.apply_debuff(Debuff.create(Debuff.DebuffType.BURN, 4, 15))
	NewCardsA.cycle(main)
	_check(dbm.get_debuff(Debuff.DebuffType.BURN).value == 4 and _lost(e) == 0 and e.burn_stacks == 0, "with no enemy within 4 nothing transfers")
	# The real cycle: the transfer runs before the caster's own Burn tick.
	dbm.clear_all_debuffs()
	e = _field([Vector2i(1, 0)])[0]
	dbm.apply_debuff(Debuff.create(Debuff.DebuffType.BURN, 5, 15))
	_to_next_cycle()
	burn = dbm.get_debuff(Debuff.DebuffType.BURN)
	_check(burn != null and burn.value == 2, "over a real cycle: 2 transferred, then the caster's Burn ticks 1 off (%d left)" % (burn.value if burn else 0))
	_check(_lost(e) >= 6, "the enemy took the transfer's 6 (lost %d)" % _lost(e))
	# No maintain, no transfer.
	dm.dismiss_maintained_card(dm.maintained_cards.find(eh))
	dbm.clear_all_debuffs()
	e = _field([Vector2i(1, 0)])[0]
	dbm.apply_debuff(Debuff.create(Debuff.DebuffType.BURN, 5, 15))
	NewCardsA.cycle(main)
	_check(dbm.get_debuff(Debuff.DebuffType.BURN).value == 5 and _lost(e) == 0, "without the maintain the Burn stays put")
	dbm.clear_all_debuffs()

func _test_lodestone_field() -> void:
	print("-- Lodestone Field --")
	_fresh()
	var lf := Card.create_by_id("lodestone_field")
	var r := _play(lf, main.player)
	_check(_costs(r, 100, 5), "Lodestone Field costs 100 mana / 5 tempo (%s)" % _cost_str(r))
	_check(dm.maintained_cards.has(lf) and stats.maintained_mana == 100, "it is maintained, reserving 100 mana")
	var es := _field([Vector2i(0, -2), Vector2i(0, -3)])
	var near: Enemy = es[0]
	var far: Enemy = es[1]
	NewCardsA.cycle(main)
	_check(near.slow_stacks == 1, "an enemy 2 squares away is Slowed 1 at the cycle start (%d)" % near.slow_stacks)
	_check(far.slow_stacks == 0, "an enemy 3 squares away is not (%d)" % far.slow_stacks)
	# Shock holds inside the field, decays outside it.
	near.apply_debuff("shock", 3)
	far.apply_debuff("shock", 3)
	var n0: int = near.shock_stacks
	var f0: int = far.shock_stacks
	var lost0: int = _lost(near)
	near._tick_status_durations()
	far._tick_status_durations()
	_check(near.shock_stacks == n0, "Shock on the enemy in the field does not decay (%d of %d)" % [near.shock_stacks, n0])
	_check(_lost(near) - lost0 >= n0, "it still deals its damage (%d)" % (_lost(near) - lost0))
	_check(far.shock_stacks == f0 - 1, "Shock outside the field loses its stack (%d of %d)" % [far.shock_stacks, f0])
	# Over a real cycle.
	es = _field([Vector2i(1, 0)])
	near = es[0]
	_to_next_cycle()
	_check(near.slow_stacks >= 1, "a real cycle start Slows the enemy in the field (%d)" % near.slow_stacks)
	# The field follows the caster's maintain: dropped, Shock decays again.
	near.apply_debuff("shock", 3)
	n0 = near.shock_stacks
	dm.dismiss_maintained_card(dm.maintained_cards.find(lf))
	near._tick_status_durations()
	_check(near.shock_stacks == n0 - 1, "with the maintain dropped Shock decays again (%d of %d)" % [near.shock_stacks, n0])
	var s0: int = near.slow_stacks
	NewCardsA.cycle(main)
	_check(near.slow_stacks <= s0, "and no more Slow is applied")

func _test_wardens_hound() -> void:
	print("-- Warden's Hound --")
	_fresh()
	# Without the Hound a jailing grants nothing.
	var jb := Card.create_by_id("block")
	jb.jail_on_play = 10
	_play(jb, main.player)
	_check(dm.jail_pile.has(jb), "a jail-on-play card goes to jail")
	_check(_timed_keen(bm) == null and bm.get_buff(Buff.BuffType.THORNS) == null, "no Hound: no Keen, no Thorns")
	_fresh()
	var wh := Card.create_by_id("wardens_hound")
	var r := _play(wh, main.player)
	_check(_costs(r, 60, 0), "Warden's Hound costs 60 mana / 0 tempo (%s)" % _cost_str(r))
	_check(dm.maintained_cards.has(wh) and stats.maintained_mana == 60, "it is maintained, reserving 60 mana")
	_check(_timed_keen(bm) == null, "nothing until a card is jailed")
	# Jail-on-play.
	jb = Card.create_by_id("block")
	jb.jail_on_play = 10
	jb.tempo_cost = 0
	jb.resolve_tick = 0
	_play(jb, main.player)
	var keen := _timed_keen(bm)
	var thorns := bm.get_buff(Buff.BuffType.THORNS)
	_check(dm.jail_pile.has(jb), "the card is jailed")
	_check(keen != null and keen.value == 2 and keen.duration == 10, "jailing a card grants Keen 2%% for 10 tempo (%s)" % (("%d%% / %d" % [keen.value, keen.duration]) if keen else "none"))
	_check(thorns != null and thorns.value == 5, "and 5 Thorns (%d)" % (thorns.value if thorns else 0))
	# A Burden card jailed from hand.
	var burden := Card.create_by_id("block")
	burden.has_burden = true
	burden.burden_plays = 1
	dm.hand.append(burden)
	_check(dm.jail_burden_card(dm.hand.find(burden)), "a Burden card is jailed from hand")
	keen = _timed_keen(bm)
	thorns = bm.get_buff(Buff.BuffType.THORNS)
	_check(keen != null and keen.value == 4, "a second jailing stacks Keen to 4%% (%d)" % (keen.value if keen else 0))
	_check(thorns != null and thorns.value == 10, "and Thorns to 10 (%d)" % (thorns.value if thorns else 0))
	# The Jailed overflow.
	var oj := Card.create_by_id("block")
	dm.overflow_manager._process_jailed(oj, OverflowEffect.new(OverflowEffect.OverflowType.JAILED, "Jailed", 0, 3))
	keen = _timed_keen(bm)
	_check(dm.jail_pile.has(oj) and keen != null and keen.value == 6, "a card jailed by overflow counts too (Keen %d%%)" % (keen.value if keen else 0))

func _test_war_shout() -> void:
	print("-- War Shout --")
	_fresh()
	var near = _ally(0)
	var far = _ally(1)
	_place(near, Vector2i(0, -3))
	_place(far, Vector2i(0, -4))
	var r := _play(Card.create_by_id("war_shout"), main.player)
	_check(_costs(r, 30, 3), "War Shout costs 30 mana / 3 tempo (%s)" % _cost_str(r))
	var mine := bm.get_buff(Buff.BuffType.STRENGTHEN)
	var theirs = near.get_buff_manager().get_buff(Buff.BuffType.STRENGTHEN)
	_check(mine != null and mine.value == 3 and mine.charges == 3, "the caster gains Strengthen 3 for 3 attacks (%s)" % (("%d x%d" % [mine.value, mine.charges]) if mine else "none"))
	_check(theirs != null and theirs.value == 3 and theirs.charges == 3, "an ally 3 squares away gains Strengthen 3 for 3 attacks")
	_check(far.get_buff_manager().get_buff(Buff.BuffType.STRENGTHEN) == null, "an ally 4 squares away gains nothing")
	_check(dm.maintained_cards.is_empty(), "War Shout is not maintained")

func _test_stone_wheel() -> void:
	print("-- Stone Wheel --")
	_fresh()
	var ally = _ally(0)
	_place(ally, Vector2i(0, -4))
	var r := _play(Card.create_by_id("stone_wheel"), ally)
	_check(_costs(r, 50, 2), "Stone Wheel costs 50 mana / 2 tempo (%s)" % _cost_str(r))
	var k := _timed_keen(ally.get_buff_manager())
	_check(k != null and k.value == 15 and k.duration == 10, "the targeted ally has Keen 15%% for 10 tempo (%s)" % (("%d%% / %d" % [k.value, k.duration]) if k else "none"))
	_check(ally.get_buff_manager().get_keen_crit_chance() == 15, "their crit chance from Keen is 15 (%d)" % ally.get_buff_manager().get_keen_crit_chance())
	_check(_timed_keen(bm) == null, "the caster gains nothing from an ally cast")
	# Self cast.
	_fresh()
	_play(Card.create_by_id("stone_wheel"), main.player)
	k = _timed_keen(bm)
	_check(k != null and k.value == 15, "cast on yourself it is your Keen 15%% (%d)" % (k.value if k else 0))
	_check(k != null and k.duration > 0 and k.duration <= 10, "on the clock (%d tempo left)" % (k.duration if k else 0))
	_tempo(10)
	_check(_timed_keen(bm) == null, "and gone after 10 tempo")

func _test_arcane_tide() -> void:
	print("-- Arcane Tide --")
	_fresh()
	var ally = _ally(0)
	_place(ally, Vector2i(0, -4))
	var r := _play(Card.create_by_id("arcane_tide"), ally)
	_check(_costs(r, 30, 2), "Arcane Tide costs 30 mana / 2 tempo (%s)" % _cost_str(r))
	var at = ally.get_buff_manager().get_buff(Buff.BuffType.ATTUNE)
	_check(at != null and at.value == 3 and at.charges == 3, "the targeted ally has Attune 3 for 3 spells (%s)" % (("%d x%d" % [at.value, at.charges]) if at else "none"))
	_check(bm.get_buff(Buff.BuffType.ATTUNE) == null, "the caster gains nothing from an ally cast")
	_fresh()
	_play(Card.create_by_id("arcane_tide"), main.player)
	at = bm.get_buff(Buff.BuffType.ATTUNE)
	_check(at != null and at.value == 3 and at.charges == 3, "cast on yourself it is your Attune 3, unspent by the cast itself (%s)" % (("%d x%d" % [at.value, at.charges]) if at else "none"))
	_check(bm.get_attune_bonus() == 3, "the next offensive spell reads +3 (%d)" % bm.get_attune_bonus())

func _test_clarity() -> void:
	print("-- Clarity --")
	_fresh()
	var r := _play(Card.create_by_id("clarity"), main.player)
	_check(_costs(r, 10, 3), "Clarity costs 10 mana / 3 tempo (%s)" % _cost_str(r))
	_check(bm.has_buff(Buff.BuffType.FOCUSED), "the caster is Focused")
	var at := bm.get_buff(Buff.BuffType.ATTUNE)
	_check(at != null and at.value == 2 and at.charges == 3, "and has Attune 2 for 3 spells (%s)" % (("%d x%d" % [at.value, at.charges]) if at else "none"))
	# Exactly two cycle starts pay +10 mana, wherever in the cycle it lands.
	for offset in range(5):
		_fresh()
		var guard := 0
		while tm.current_tempo != offset and guard < 10:
			tm.add_tempo(1)
			guard += 1
		stats.current_mana = 100
		_focus_payouts = 0
		_play(Card.create_by_id("clarity"), main.player)
		_tempo(20)
		_check(_focus_payouts == 2, "played at cycle tempo %d: Focused pays +10 mana at exactly 2 cycle starts (%d)" % [offset, _focus_payouts])
		_check(not bm.has_buff(Buff.BuffType.FOCUSED), "and Focused is gone afterwards")
