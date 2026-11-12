extends SceneTree

## The sheet's 2026-11-11 rows, batch C (docs/new_cards/C.md): the melee and
## movement cards — Lunge, Grapple Chain, Back Pedal, Deliberate Arch,
## Harvest, Momentous Slam, Bastion Battle, Acro-medic. Every card is played
## through the REAL play path in a booted main.tscn (the dojo):
## main.play_selected_card charges the mana, TempoManager ticks the tempo,
## _resolve_queued_card runs the executor and main's world effects.
## Run: godot --headless --path . --script tests/test_new_cards_c.gd

var failures := 0
var main = null
var stats: PlayerStats
var dm: DeckManager
var tm: TempoManager
var gm
var bm: BuffManager
var dbm: DebuffManager
var _t0 := 0
var _home := Vector2i.ZERO  # an open tile mid-room every check starts from

func _check(ok: bool, msg: String) -> void:
	if ok:
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
	print("=== New cards, batch C ===")
	TempoManager.preferred_swing_hold = 0  # resolve on the tick, no swing wait
	await _boot()
	if main == null:
		print("=== %d failure(s) ===" % failures)
		quit(1)
		return
	_test_registry()
	_test_lunge()
	_test_grapple_chain()
	_test_back_pedal()
	_test_deliberate_arch()
	_test_harvest()
	_test_momentous_slam()
	_test_bastion_battle()
	_test_acro_medic()
	print("=== %d failure(s) ===" % failures)
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
	if main.player == null:
		_check(false, "the dojo is up")
		main = null
		return
	stats = main.player.get_stats()
	dm = main.deck_manager
	tm = main.tempo_manager
	gm = main.grid_manager
	bm = main.player.get_buff_manager()
	dbm = main.player.get_debuff_manager()
	_home = gm.world_to_grid(main.player.position) + Vector2i(-2, -3)
	tm.card_resolved.connect(_on_resolved)  # after main's own handler

func _pc() -> Vector2i:
	return gm.world_to_grid(main.player.position)

func _cell(node) -> Vector2i:
	return gm.world_to_grid(node.position)

func _stand(node, cell: Vector2i) -> void:
	var pos: Vector3 = main._ground_pos(cell)
	node.position = pos
	node.target_position = pos

## Clear the field and stand fresh dummies at these offsets from home.
func _field(offsets: Array) -> Array:
	var old: Array = main.enemy_spawner.enemies.duplicate()
	var out: Array = []
	for off in offsets:
		out.append(main.enemy_spawner.spawn_enemy(Enemy.EnemyType.DUMMY, main._ground_pos(_home + off)))
	for e in old:
		main.enemy_spawner.despawn_enemy(e)
	return out

func _lost(e) -> int:
	return (e.max_health - e.current_health)

## A clean slate: the hero back home, the allies out of the way, no queued
## ticks, empty piles (no draws), no statuses, plenty of health and mana.
func _fresh() -> void:
	_drain()
	main._pending_resolve_queue.clear()
	main.glut_tempo_remaining = 0
	main.draw_timer.tempo_until_draw = 1e9  # no timed draws mid-check
	_stand(main.player, _home)
	for i in range(main._dojo_allies.size()):
		_stand(main._dojo_allies[i], _home + Vector2i(7, -4 + i))
	dm.hand.clear()
	dm.draw_pile.clear()
	dm.discard_pile.clear()
	dm.jail_pile.clear()
	dm.next_attack_half_tempo = false
	dm.next_attack_mana_discount = 0
	bm.buffs.clear()
	bm.tighten_string_charges = 0
	dbm.clear_all_debuffs()
	NewCardsC.back_pedal_spent(main.player)
	main._set_player_invisible(false)
	stats.skill_tree_passives.erase("now_you_see_me")
	stats.max_health = 500
	stats.current_health = 500
	stats.current_temp_health = 0
	stats.current_armor = 0
	stats.current_carry_load = 0
	stats.max_mana = 2000
	stats.current_mana = 1000

func _drain() -> void:
	var guard := 0
	while tm._pending_ticks > 0 and guard < 200:
		tm._process_one_tick()
		guard += 1

func _queued(card: Card) -> bool:
	for e in main._pending_resolve_queue:
		if e["card"] == card:
			return true
	return false

var _probe: Callable = Callable()
var _snap: Dictionary = {}

## Runs right after main resolved the card, BEFORE that tick's tempo reaches
## the timers — so a "10 tempo" status reads 10, not 9.
func _on_resolved(_card: Card) -> void:
	if _probe.is_valid():
		_snap = _probe.call()
		_probe = Callable()

## Play `card` through main.play_selected_card and tick until it RESOLVES.
## `probe` (returns a Dictionary) is read the moment the card resolves.
func _play(card: Card, target, probe: Callable = Callable()) -> Dictionary:
	if not (card in dm.hand):
		dm.hand.append(card)
	main.selected_card_index = dm.hand.find(card)
	main._card_play_confirmed = true
	var m0: float = stats.current_mana
	_t0 = tm.global_tempo
	_snap = {}
	_probe = probe
	main.play_selected_card(target)
	var spent := int(round(m0 - stats.current_mana))
	var played: bool = not (card in dm.hand)
	if _probe.is_valid() and played and not _queued(card):
		_on_resolved(card)  # a 0-tempo card resolved inside the play
	var guard := 0
	while _queued(card) and tm._pending_ticks > 0 and guard < 50:
		tm._process_one_tick()
		guard += 1
	_probe = Callable()
	return {"played": played, "mana": spent, "snap": _snap}

## Tick out the rest of the play; the tempo the whole play cost.
func _finish() -> int:
	_drain()
	return tm.global_tempo - _t0

## A hit is the stat-scaled number, or its crit (5% innate crit stays on).
func _hit(dealt: int, expect: int, e = null) -> bool:
	return dealt == expect or dealt == Card.crit_multiply(expect, stats, e)

func _phys(base: int) -> int:
	return stats.get_effective_physical_damage(base)

func _strengthen_left() -> int:
	return bm.get_buffs(Buff.BuffType.STRENGTHEN).size()

func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

# ---------------------------------------------------------------- registry

func _test_registry() -> void:
	print("-- The rows and their shapes --")
	for cid in ["lunge", "grapple_chain", "deliberate_arch", "bastion_battle"]:
		var c := Card.create_by_id(cid)
		_check(c != null and c.is_offensive() and not c.is_attack() and c.school != Card.CardSchool.SPELL,
			"%s is a plain Offensive card: offensive, neither attack nor spell" % cid)
		_check(c != null and not c.is_ranged, "%s is melee" % cid)
	for cid in ["harvest", "momentous_slam"]:
		var c := Card.create_by_id(cid)
		_check(c != null and c.is_attack() and not c.is_ranged, "%s is a melee attack" % cid)
	for cid in ["back_pedal", "acro_medic"]:
		var c := Card.create_by_id(cid)
		_check(c != null and c.card_type == Card.CardType.UTILITY and not c.is_offensive(), "%s is a utility" % cid)
	_check(Card.create_by_id("acro_medic").is_heal_card(), "Acro-medic is a heal card (Poisoned Blood reads it)")
	_check("acro_medic" in main.SUMMON_ALLY_CARDS, "Acro-medic may be aimed at a summon")

# ---------------------------------------------------------------- Lunge

func _test_lunge() -> void:
	print("-- Lunge --")
	# 4 tiles off: a 3-tile walk to the square beside it, then the hit.
	_fresh()
	var e: Enemy = _field([Vector2i(4, 0)])[0]
	var c := Card.create_by_id("lunge")
	stats.add_skill_tree_passive("now_you_see_me")
	stats.st_nysm_last_tempo = -100
	bm.apply_buff(Buff.create_strengthen(15, 1, "test"))
	_check(main._is_target_in_card_range(c, e), "an enemy 4 tiles off may be targeted (3 tiles of walk + the adjacent square)")
	_check(not main._is_target_in_card_range(Card.create_by_id("shiv"), e), "an ordinary melee card may not")
	var r := _play(c, e)
	var t := _finish()
	_check(r["played"] and r["mana"] == 80 and t == 5, "charges 80 mana and 5 tempo (charged %d / %d)" % [r["mana"], t])
	_check(_pc() == _home + Vector2i(3, 0), "the hero walked 3 tiles to the square beside the enemy (at %s)" % str(_pc() - _home))
	_check(_hit(_lost(e), _phys(9), e), "deals 9 (scaled %d, dealt %d)" % [_phys(9), _lost(e)])
	_check(_strengthen_left() == 1, "a plain Offensive card neither takes nor spends an attack's Strengthen")
	_check(bm.has_buff(Buff.BuffType.INVISIBLE), "the walk counts as a displacement (Now You See Me)")

	# It resolves on its 5th tick.
	_fresh()
	e = _field([Vector2i(2, 0)])[0]
	c = Card.create_by_id("lunge")
	dm.hand.append(c)
	main.selected_card_index = 0
	main._card_play_confirmed = true
	main.play_selected_card(e)
	for _i in range(4):
		tm._process_one_tick()
	_check(_lost(e) == 0 and _pc() == _home, "nothing lands for 4 ticks")
	tm._process_one_tick()
	_check(_lost(e) > 0 and _pc() == _home + Vector2i(1, 0), "the walk and the hit land on the 5th tick")
	_drain()

	# Already adjacent: no walk, no displacement, the hit lands.
	_fresh()
	e = _field([Vector2i(1, 1)])[0]
	stats.add_skill_tree_passive("now_you_see_me")
	stats.st_nysm_last_tempo = -100
	_play(Card.create_by_id("lunge"), e)
	_finish()
	_check(_pc() == _home and _hit(_lost(e), _phys(9), e), "already beside the enemy: no step, 9 damage")
	_check(not bm.has_buff(Buff.BuffType.INVISIBLE), "no step, no displacement")

	# Disarm does not stop a plain Offensive card.
	_fresh()
	e = _field([Vector2i(2, 0)])[0]
	dbm.apply_debuff(Debuff.create(Debuff.DebuffType.DISARM, 0, 20))
	r = _play(Card.create_by_id("lunge"), e)
	_finish()
	_check(r["played"] and _lost(e) > 0, "a Disarmed hero still lunges")

	# Too far: 5 tiles of walk would be needed.
	_fresh()
	e = _field([Vector2i(6, 0)])[0]
	c = Card.create_by_id("lunge")
	_check(not main._is_target_in_card_range(c, e), "an enemy 6 tiles off is refused at the click")
	r = _play(c, e)  # forced past the click: the wind-up ends with no landing
	_finish()
	_check(_pc() == _home and _lost(e) == 0 and c.last_damage_dealt == 0, "no landing at resolve: no step and the damage is lost")

	# A free path: the walk goes round a unit in the way and never onto one.
	_fresh()
	var two: Array = _field([Vector2i(3, 0), Vector2i(1, 0)])
	c = Card.create_by_id("lunge")
	_check(main._is_target_in_card_range(c, two[0]), "an enemy behind another may be lunged at round the side")
	_play(c, two[0])
	_finish()
	_check(_cheb(_pc(), _cell(two[0])) == 1 and _pc() != _cell(two[1]) and _pc() != _home,
		"the hero lands on a free square beside the target (at %s)" % str(_pc() - _home))
	_check(_hit(_lost(two[0]), _phys(9), two[0]) and _lost(two[1]) == 0, "and hits the target only")

	# Walled in by units: no free tile to step to.
	_fresh()
	var ring: Array = _field([Vector2i(3, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)])
	_check(not main._is_target_in_card_range(Card.create_by_id("lunge"), ring[0]), "boxed in on all four sides: the lunge is refused")

# ---------------------------------------------------------------- Grapple Chain

func _test_grapple_chain() -> void:
	print("-- Grapple Chain --")
	_fresh()
	var e: Enemy = _field([Vector2i(2, 0)])[0]
	var c := Card.create_by_id("grapple_chain")
	bm.apply_buff(Buff.create_strengthen(15, 1, "test"))
	_check(main._is_target_in_card_range(c, e), "Reach 2: an enemy 2 tiles off may be targeted")
	_check(not main._is_target_in_card_range(Card.create_by_id("shiv"), e), "an ordinary melee card may not")
	var r := _play(c, e, func(): return {"slow": e.slow_stacks})
	var t := _finish()
	_check(r["played"] and r["mana"] == 75 and t == 5, "charges 75 mana and 5 tempo (charged %d / %d)" % [r["mana"], t])
	_check(_hit(_lost(e), _phys(6), e), "deals 6 (scaled %d, dealt %d)" % [_phys(6), _lost(e)])
	_check(_cell(e) == _home + Vector2i(1, 0), "the enemy is pulled 1 tile toward the hero")
	_check(int(r["snap"].get("slow", 0)) == 1, "it ends adjacent: Slowed 1 (a stack is 5 tempo)")
	_check(_strengthen_left() == 1, "a plain Offensive card leaves an attack's Strengthen alone")

	_fresh()
	e = _field([Vector2i(3, 0)])[0]
	_check(not main._is_target_in_card_range(Card.create_by_id("grapple_chain"), e), "3 tiles off is out of reach")

	# A diagonal hook comes in on the diagonal.
	_fresh()
	e = _field([Vector2i(2, 2)])[0]
	r = _play(Card.create_by_id("grapple_chain"), e, func(): return {"slow": e.slow_stacks})
	_finish()
	_check(_cell(e) == _home + Vector2i(1, 1) and int(r["snap"].get("slow", 0)) == 1, "a diagonal pull lands on the diagonal neighbour, Slowed")

	# Something in the way: no pull, so it does not end adjacent.
	_fresh()
	var two: Array = _field([Vector2i(2, 0), Vector2i(1, 0)])
	r = _play(Card.create_by_id("grapple_chain"), two[0], func(): return {"slow": two[0].slow_stacks})
	_finish()
	_check(_cell(two[0]) == _home + Vector2i(2, 0) and int(r["snap"].get("slow", 0)) == 0 and _lost(two[0]) > 0,
		"a unit in the way: the hit lands, no pull, no Slow")

	# Already adjacent: nowhere to pull, Slowed all the same.
	_fresh()
	e = _field([Vector2i(1, 0)])[0]
	r = _play(Card.create_by_id("grapple_chain"), e, func(): return {"slow": e.slow_stacks})
	_finish()
	_check(_cell(e) == _home + Vector2i(1, 0) and int(r["snap"].get("slow", 0)) == 1, "an adjacent enemy stays put and is Slowed 1")

# ---------------------------------------------------------------- Back Pedal

func _test_back_pedal() -> void:
	print("-- Back Pedal --")
	_fresh()
	var e: Enemy = _field([Vector2i(-2, 0)])[0]
	var r := _play(Card.create_by_id("back_pedal"), main.player)
	var t := _finish()
	_check(r["played"] and r["mana"] == 50 and t == 0, "charges 50 mana and no tempo (charged %d / %d)" % [r["mana"], t])
	_check(_pc() == _home + Vector2i(2, 0), "steps 2 tiles straight away from the nearest enemy (at %s)" % str(_pc() - _home))
	_check(bm.has_buff(Buff.BuffType.STEADY), "gains Steady (its own play, 0 tempo, does not spend it)")
	_check(_lost(e) == 0, "and hurts nobody")

	# The rider: a ranged offensive card costs 2 less tempo. Dagger Throw (1
	# tempo) becomes free on its own, so Steady is still there afterwards.
	var dagger := Card.create_by_id("dagger_throw")
	_check(NewCardsC.back_pedal_tempo_cut(main.player, dagger) == 2, "the next ranged offensive card is cut by 2 tempo")
	_check(NewCardsC.back_pedal_tempo_cut(main.player, Card.create_by_id("shiv")) == 0, "a melee card is not")
	_check(NewCardsC.back_pedal_tempo_cut(main.player, Card.create_by_id("heal")) == 0, "a ranged card that is not offensive is not")
	_play(dagger, e)
	t = _finish()
	_check(t == 0 and _lost(e) > 0, "Dagger Throw (1 tempo) costs nothing after the cut")
	_check(bm.has_buff(Buff.BuffType.STEADY), "it was free on its own: Steady still stands")
	_check(NewCardsC.back_pedal_tempo_cut(main.player, Card.create_by_id("dagger_throw")) == 0, "the rider is spent by that one action")
	var shiv := Card.create_by_id("shiv")
	_stand(e, _pc() + Vector2i(-1, 0))
	_play(shiv, e)
	t = _finish()
	_check(t == 0 and not bm.has_buff(Buff.BuffType.STEADY), "the action after it is Steady's: no tempo, Steady spent")

	# A dearer ranged offensive card: 5 tempo, cut to 3, then Steady makes it free.
	_fresh()
	e = _field([Vector2i(-2, 0)])[0]
	_play(Card.create_by_id("back_pedal"), main.player)
	_finish()
	var slow_shot := Card.create_by_id("dagger_throw")
	slow_shot.tempo_cost = 5
	_play(slow_shot, e)
	t = _finish()
	_check(t == 0 and not bm.has_buff(Buff.BuffType.STEADY), "a 5-tempo ranged offensive card is made free by Steady, which is spent")

	# Any other card as the action ends the rider.
	_fresh()
	e = _field([Vector2i(-1, 0)])[0]
	_play(Card.create_by_id("back_pedal"), main.player)
	_finish()
	_stand(e, _pc() + Vector2i(-1, 0))
	_play(Card.create_by_id("shiv"), e)
	_finish()
	_check(NewCardsC.back_pedal_tempo_cut(main.player, Card.create_by_id("dagger_throw")) == 0, "a melee card as the action: the rider is gone")
	var shot := Card.create_by_id("dagger_throw")
	shot.tempo_cost = 4
	_play(shot, e)
	t = _finish()
	_check(t == 4, "the ranged card after it pays its full tempo (paid %d)" % t)

	# Something behind: as far as the way is free.
	_fresh()
	var two: Array = _field([Vector2i(-1, 0), Vector2i(2, 0)])
	_play(Card.create_by_id("back_pedal"), main.player)
	_finish()
	_check(_pc() == _home + Vector2i(1, 0) and bm.has_buff(Buff.BuffType.STEADY), "a unit 2 tiles behind: 1 step, Steady all the same")

	# A diagonal enemy is backed away from on the diagonal.
	_fresh()
	_field([Vector2i(-2, -2)])
	_play(Card.create_by_id("back_pedal"), main.player)
	_finish()
	_check(_pc() == _home + Vector2i(2, 2), "a diagonal enemy: 2 diagonal steps away (at %s)" % str(_pc() - _home))

	# Nobody to back away from: Steady only.
	_fresh()
	_field([])
	_play(Card.create_by_id("back_pedal"), main.player)
	_finish()
	_check(_pc() == _home and bm.has_buff(Buff.BuffType.STEADY), "no enemy on the field: no step, Steady")

# ---------------------------------------------------------------- Deliberate Arch

func _test_deliberate_arch() -> void:
	print("-- Deliberate Arch --")
	_fresh()
	var es: Array = _field([Vector2i(1, 0), Vector2i(1, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 2)])
	var c := Card.create_by_id("deliberate_arch")
	bm.apply_buff(Buff.create_strengthen(15, 1, "test"))
	var r := _play(c, main.player, func(): return {"glut": main.glut_tempo_remaining - tm._pending_ticks})
	_check(r["played"] and r["mana"] == 80, "charges 80 mana (charged %d)" % r["mana"])
	var first: int = _lost(es[0])
	_check(_hit(first, _phys(18)), "deals 18 (scaled %d, dealt %d)" % [_phys(18), first])
	_check(_lost(es[1]) == first and _lost(es[2]) == first and _lost(es[3]) == first, "to every adjacent enemy, diagonals included")
	_check(_lost(es[4]) == 0 and _lost(es[5]) == 0, "and none 2 tiles off")
	_check(int(r["snap"].get("glut", 0)) == 10, "Glut 10 once the play has run out (%d)" % int(r["snap"].get("glut", 0)))
	_check(_strengthen_left() == 1, "a plain Offensive card leaves an attack's Strengthen alone")
	var t := _finish()
	_check(t == 5, "costs 5 tempo (cost %d)" % t)
	main.glut_tempo_remaining = 0

	# It resolves on its 3rd tick.
	_fresh()
	es = _field([Vector2i(1, 0)])
	c = Card.create_by_id("deliberate_arch")
	dm.hand.append(c)
	main.selected_card_index = 0
	main._card_play_confirmed = true
	main.play_selected_card(main.player)
	tm._process_one_tick()
	tm._process_one_tick()
	_check(_lost(es[0]) == 0, "nothing lands for 2 ticks")
	tm._process_one_tick()
	_check(_lost(es[0]) > 0, "the swing lands on the 3rd tick")
	_drain()
	main.glut_tempo_remaining = 0

# ---------------------------------------------------------------- Harvest

func _test_harvest() -> void:
	print("-- Harvest --")
	_fresh()
	var e: Enemy = _field([Vector2i(1, 0)])[0]
	var c := Card.create_by_id("harvest")
	for cid in ["block", "block", "shiv", "heal"]:
		dm.discard_pile.append(Card.create_by_id(cid))
	var r := _play(c, e)
	var t := _finish()
	_check(r["played"] and r["mana"] == 60 and t == 5, "charges 60 mana and 5 tempo (charged %d / %d)" % [r["mana"], t])
	_check(_hit(_lost(e), _phys(6), e), "deals 6 (scaled %d, dealt %d)" % [_phys(6), _lost(e)])
	_check(dm.discard_pile.size() == 1 and dm.discard_pile[0] == c, "the discard pile is emptied (the played Harvest alone rests there)")
	_check(dm.hand.size() == 1 and dm.draw_pile.size() == 3, "its 4 cards went to the draw pile and 1 was drawn (hand %d, draw %d)" % [dm.hand.size(), dm.draw_pile.size()])

	# A thin discard pile earns no Heavy Greedy Cheese, and an attack takes Strengthen.
	_fresh()
	e = _field([Vector2i(1, 0)])[0]
	c = Card.create_by_id("harvest")
	dm.discard_pile.append(Card.create_by_id("block"))
	bm.apply_buff(Buff.create_strengthen(15, 1, "test"))
	_play(c, e)
	_finish()
	_check(dm.discard_pile.size() == 1 and dm.discard_pile[0] == c and dm.hand.size() == 1 and dm.hand[0].card_id == "block",
		"one card in the discard: shuffled in and drawn, no Cheese added")
	_check(_hit(_lost(e), _phys(6) + 15, e) and _strengthen_left() == 0, "an Attack: Strengthen rides and is spent (dealt %d)" % _lost(e))

	# Empty discard pile: the draw comes off the draw pile as it stands.
	_fresh()
	e = _field([Vector2i(1, 0)])[0]
	dm.draw_pile.append(Card.create_by_id("block"))
	_play(Card.create_by_id("harvest"), e)
	_finish()
	_check(dm.hand.size() == 1 and dm.draw_pile.is_empty(), "an empty discard pile: it still draws 1")

	# Disarm stops an Attack.
	_fresh()
	e = _field([Vector2i(1, 0)])[0]
	dbm.apply_debuff(Debuff.create(Debuff.DebuffType.DISARM, 0, 20))
	r = _play(Card.create_by_id("harvest"), e)
	_finish()
	_check(not r["played"], "a Disarmed hero cannot play it")

# ---------------------------------------------------------------- Momentous Slam

func _test_momentous_slam() -> void:
	print("-- Momentous Slam --")
	_fresh()
	var e: Enemy = _field([Vector2i(1, 0)])[0]
	stats.current_carry_load = 47
	var c := Card.create_by_id("momentous_slam")
	var r := _play(c, e)
	var t := _finish()
	_check(r["played"] and r["mana"] == 40 and t == 5, "charges 40 mana and 5 tempo (charged %d / %d)" % [r["mana"], t])
	_check(_hit(_lost(e), _phys(3 + 4), e), "carrying 47: 3 + 4 (scaled %d, dealt %d)" % [_phys(7), _lost(e)])
	_check(c.bonus_damage == 0, "the weight bonus does not stick to the card")

	_fresh()
	e = _field([Vector2i(1, 0)])[0]
	stats.current_carry_load = 9
	_play(Card.create_by_id("momentous_slam"), e)
	_finish()
	_check(_hit(_lost(e), _phys(3), e), "carrying 9: the bare 3 (dealt %d)" % _lost(e))

	_fresh()
	e = _field([Vector2i(1, 0)])[0]
	stats.current_carry_load = 120
	bm.apply_buff(Buff.create_strengthen(15, 1, "test"))
	_play(Card.create_by_id("momentous_slam"), e)
	_finish()
	_check(_hit(_lost(e), _phys(3 + 12) + 15, e) and _strengthen_left() == 0,
		"carrying 120: 3 + 12, and an Attack takes Strengthen (dealt %d)" % _lost(e))

# ---------------------------------------------------------------- Bastion Battle

func _bb_play(own_armor: int, foe_armor: int) -> Dictionary:
	_fresh()
	var e: Enemy = _field([Vector2i(1, 0)])[0]
	stats.current_armor = own_armor
	e.current_armor = foe_armor
	var before: int = e.current_health + e.current_armor
	var r := _play(Card.create_by_id("bastion_battle"), e, func(): return {"disarm": e.disarmed_tempo, "on": e.is_disarmed})
	var t := _finish()
	r["tempo"] = t
	r["dealt"] = before - (e.current_health + e.current_armor)
	r["enemy"] = e
	return r

func _test_bastion_battle() -> void:
	print("-- Bastion Battle --")
	var r := _bb_play(0, 0)
	_check(r["played"] and r["mana"] == 25 and r["tempo"] == 3, "charges 25 mana and 3 tempo (charged %d / %d)" % [r["mana"], r["tempo"]])
	_check(_hit(r["dealt"], _phys(5), r["enemy"]), "armor 0 vs 0: the bare 5 (scaled %d, dealt %d)" % [_phys(5), r["dealt"]])
	_check(bool(r["snap"].get("on", false)) and int(r["snap"].get("disarm", 0)) == 10, "the enemy has no armor: Disarm 2 (10 tempo, read %d)" % int(r["snap"].get("disarm", 0)))

	r = _bb_play(6, 0)
	_check(_hit(r["dealt"], _phys(15), r["enemy"]), "armor 6 vs 0: +10 (scaled %d, dealt %d)" % [_phys(15), r["dealt"]])
	_check(int(r["snap"].get("disarm", 0)) == 10, "and Disarm 2")

	r = _bb_play(30, 4)
	_check(_hit(r["dealt"], _phys(15), r["enemy"]), "armor 30 vs 4: +10 (dealt %d)" % r["dealt"])
	_check(int(r["snap"].get("disarm", 0)) == 0, "the enemy had armor before the hit: no Disarm, though the hit stripped it")

	r = _bb_play(3, 40)
	_check(_hit(r["dealt"], _phys(5), r["enemy"]), "armor 3 vs 40: the bare 5 (dealt %d)" % r["dealt"])
	_check(int(r["snap"].get("disarm", 0)) == 0, "and no Disarm")

	r = _bb_play(7, 7)
	_check(_hit(r["dealt"], _phys(5), r["enemy"]), "equal armor is not more armor: the bare 5 (dealt %d)" % r["dealt"])

	# Plain Offensive: no Strengthen, and Disarm does not stop it.
	_fresh()
	var e: Enemy = _field([Vector2i(1, 0)])[0]
	bm.apply_buff(Buff.create_strengthen(15, 1, "test"))
	dbm.apply_debuff(Debuff.create(Debuff.DebuffType.DISARM, 0, 20))
	var r2 := _play(Card.create_by_id("bastion_battle"), e)
	_finish()
	_check(r2["played"] and _hit(_lost(e), _phys(5), e) and _strengthen_left() == 1,
		"a Disarmed hero plays it; an attack's Strengthen is left alone (dealt %d)" % _lost(e))

# ---------------------------------------------------------------- Acro-medic

func _test_acro_medic() -> void:
	print("-- Acro-medic --")
	if main._dojo_allies.is_empty():
		_check(false, "the dojo has an ally to heal")
		return
	var ally = main._dojo_allies[0]
	var a_stats: PlayerStats = ally.get_stats()
	_fresh()
	_field([])
	_stand(ally, _home + Vector2i(4, 0))
	a_stats.max_health = maxi(a_stats.max_health, 200)
	a_stats.current_health = 50
	var c := Card.create_by_id("acro_medic")
	stats.add_skill_tree_passive("now_you_see_me")
	stats.st_nysm_last_tempo = -100
	_check(main._is_target_in_card_range(c, ally), "an ally 4 tiles off is in range (5)")
	_check(NewCardsC.acro_medic_can_play(main, ally), "and has a free spot beside them")
	var expect: int = a_stats.get_effective_heal_amount(10)
	var r := _play(c, ally)
	var t := _finish()
	_check(r["played"] and r["mana"] == 70 and t == 1, "charges 70 mana and 1 tempo (charged %d / %d)" % [r["mana"], t])
	_check(_pc() == _home + Vector2i(3, 0), "blinks to the free spot beside the ally nearest the caster (at %s)" % str(_pc() - _home))
	_check(a_stats.current_health - 50 == expect, "heals the ally for 10 (their healing bonuses apply: %d, healed %d)" % [expect, a_stats.current_health - 50])
	_check(stats.current_health == 500, "the caster is not the one healed")
	_check(bm.has_buff(Buff.BuffType.INVISIBLE), "the blink is a displacement (Now You See Me)")

	# Out of range, and yourself.
	_fresh()
	_field([])
	_stand(ally, _home + Vector2i(7, 0))
	_check(not main._is_target_in_card_range(Card.create_by_id("acro_medic"), ally), "an ally 7 tiles off is out of range")
	_check(not NewCardsC.acro_medic_can_play(main, main.player), "yourself is refused at the click")

	# Already beside them: no blink, the heal lands.
	_fresh()
	_field([])
	_stand(ally, _home + Vector2i(1, 1))
	a_stats.current_health = 50
	_play(Card.create_by_id("acro_medic"), ally)
	_finish()
	_check(_pc() == _home and a_stats.current_health - 50 == expect, "already beside the ally: no blink, healed %d" % (a_stats.current_health - 50))

	# No free spot beside them: refused at the click; forced, no blink and no heal.
	_fresh()
	_stand(ally, _home + Vector2i(4, 0))
	var ring: Array = []
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if dx != 0 or dz != 0:
				ring.append(Vector2i(4 + dx, dz))
	_field(ring)
	a_stats.current_health = 50
	_check(not NewCardsC.acro_medic_can_play(main, ally), "an ally with every neighbour taken is refused at the click")
	_play(Card.create_by_id("acro_medic"), ally)
	_finish()
	_check(_pc() == _home and a_stats.current_health == 50, "forced past the click: nowhere to land, no heal")

	# Poisoned Blood: a heal card, so the heal lands as damage.
	_fresh()
	_field([])
	_stand(ally, _home + Vector2i(3, 0))
	a_stats.current_health = 100
	a_stats.current_armor = 0
	a_stats.current_temp_health = 0
	bm.apply_buff(Buff.create_poisoned_blood(1, "test"))
	_play(Card.create_by_id("acro_medic"), ally)
	_finish()
	_check(a_stats.current_health < 100 and not bm.has_poisoned_blood(), "under Poisoned Blood the heal hurts the ally and a charge is spent (health %d)" % a_stats.current_health)
	a_stats.current_health = a_stats.max_health
	PlayerStats.heal_to_damage = false
