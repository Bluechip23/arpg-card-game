extends SceneTree

## Sheet batch D (docs/new_cards/D.md): Berserker's Tithe, Internal Sickness,
## Fan of Knives, Static Sting, Feint, Cadence, Grit, Spine Release. Every
## card is played through the REAL play path in a booted main.tscn (the
## dojo): DeckManager.play_card charges the mana, TempoManager ticks the
## card's tempo, _resolve_queued_card runs the executor and main's world
## effects. Each check asserts what the card's text says.
## Run: godot --headless --path . --script tests/test_new_cards_d.gd

var failures := 0
var main = null
var stats: PlayerStats
var dm: DeckManager
var tm: TempoManager
var gm
var bm: BuffManager
var dbm: DebuffManager
var _t0 := 0

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
	print("=== New cards: batch D ===")
	TempoManager.preferred_swing_hold = 0  # resolve on the tick, no swing wait
	await _boot()
	if main == null:
		print("=== %d failure(s) ===" % failures)
		quit(1)
		return
	_test_taxonomy()
	_test_tithe()
	_test_tithe_ticker()
	_test_internal_sickness()
	_test_fan_of_knives()
	_test_static_sting()
	_test_feint()
	_test_cadence()
	_test_grit()
	_test_spine_release()
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
	tm.card_resolved.connect(_on_resolved)  # after main's own handler

func _pc() -> Vector2i:
	return gm.world_to_grid(main.player.position)

## Clear the field and stand fresh dummies at these offsets from the player.
func _field(offsets: Array) -> Array:
	var old: Array = main.enemy_spawner.enemies.duplicate()
	var out: Array = []
	for off in offsets:
		out.append(main.enemy_spawner.spawn_enemy(Enemy.EnemyType.DUMMY, main._ground_pos(_pc() + off)))
	for e in old:
		main.enemy_spawner.despawn_enemy(e)
	return out

func _lost(e) -> int:
	return e.max_health - e.current_health

## A clean slate: no queued ticks, empty piles (no draws), no statuses,
## plenty of health and mana, the DEX proc unarmed.
func _fresh() -> void:
	_drain()
	main._pending_resolve_queue.clear()
	main.glut_tempo_remaining = 0
	main.draw_timer.tempo_until_draw = 1e9  # no timed draws mid-check
	# Summons and arrows left by an earlier check would hit this one's dummies.
	for s in main._skeletons.duplicate():
		if is_instance_valid(s) and not s.is_dead:
			s.die()
	main._skeletons.clear()
	main._clear_summoned_worms()
	main._clear_spirit_bows()
	main.pending_sky_falls.clear()
	dm.hand.clear()
	dm.draw_pile.clear()
	dm.discard_pile.clear()
	dm.jail_pile.clear()
	for mc in dm.maintained_cards.duplicate():
		dm.maintained_cards.erase(mc)
	stats.maintained_mana = 0
	dm.next_attack_half_tempo = false
	dm.next_attack_mana_discount = 0
	bm.buffs.clear()
	bm.tighten_string_charges = 0
	bm.understanding_tempo = 0
	dbm.clear_all_debuffs()
	stats.max_health = 500
	stats.current_health = 500
	stats.current_temp_health = 0
	stats.current_armor = 0
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
## the timers — so a "5 tempo" status reads 5, not 4.
func _on_resolved(_card: Card) -> void:
	if _probe.is_valid():
		_snap = _probe.call()
		_probe = Callable()

## Play `card` through main.play_selected_card and tick until it RESOLVES
## (the remaining wind-down ticks wait for _finish). `aim` is a grid offset
## from the player for point-aimed cards (the mouse is pointed there).
## `probe` (returns a Dictionary) is read the moment the card resolves.
func _play(card: Card, target, aim = null, probe: Callable = Callable()) -> Dictionary:
	if not (card in dm.hand):
		dm.hand.append(card)
	main.selected_card_index = dm.hand.find(card)
	main._card_play_confirmed = true
	if aim != null:
		var aim_w: Vector3 = main._ground_pos(_pc() + aim)
		main.mouse_override = main.get_world_camera().unproject_position(aim_w)
	var m0: float = stats.current_mana
	var h0: int = stats.current_health
	_t0 = tm.global_tempo
	_snap = {}
	_probe = probe
	main.play_selected_card(target)
	var spent := int(round(m0 - stats.current_mana))
	var hp_spent := h0 - stats.current_health
	var played: bool = not (card in dm.hand)
	if _probe.is_valid() and played and not _queued(card):
		_on_resolved(card)  # a 0-tempo card resolved inside the play
	var guard := 0
	while _queued(card) and tm._pending_ticks > 0 and guard < 50:
		tm._process_one_tick()
		guard += 1
	_probe = Callable()
	return {"played": played, "mana": spent, "health": hp_spent, "snap": _snap}

## Tick out the rest of the play; the tempo the whole play cost.
func _finish() -> int:
	_drain()
	main.mouse_override = Vector2(-1, -1)
	return tm.global_tempo - _t0

func _tempo(n: int) -> void:
	for _i in range(n):
		tm.add_tempo(1)

## A hit is the stat-scaled number, or its crit (5% innate crit stays on).
func _hit(dealt: int, expect: int, e = null) -> bool:
	return dealt == expect or dealt == Card.crit_multiply(expect, stats, e)

## What a heal of `amount` actually restores (the player's healing bonuses apply).
func _heal_of(amount: int) -> int:
	stats.current_health = 300
	stats.heal(amount)
	var got := stats.current_health - 300
	stats.current_health = 500
	return got

func _phys(base: int) -> int:
	return stats.get_effective_physical_damage(base)

func _spell(base: int) -> int:
	return stats.get_effective_spell_damage(base)


## _fresh, with crits off (the 5% innate roll would blur the sums) and the
## DEX counter full.
func _clean() -> void:
	_fresh()
	stats.equipment_crit_bonus = -1000.0
	stats.current_attack_counter = stats.get_attack_speed_threshold()

## A killable enemy that does nothing, `hp` from death.
func _mob(off: Vector2i, hp: int) -> Enemy:
	var e: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.MINION, main._ground_pos(_pc() + off))
	e.chosen_action = {}
	e.current_armor = 0
	e.current_health = hp
	return e

func _answer_picker(count: int) -> bool:
	var picker = main.get_node("UI").find_child("HandMultiPicker", true, false)
	if picker == null:
		return false
	var toggles: Array = picker.find_children("*", "Button", true, false).filter(func(b): return b.toggle_mode)
	for i in range(mini(count, toggles.size())):
		toggles[i].button_pressed = true
	picker.name = "AnsweredPicker"
	for b in picker.find_children("*", "Button", true, false):
		if b.text == "Done":
			b.pressed.emit()
	return true

# ---------------------------------------------------------------- taxonomy

func _test_taxonomy() -> void:
	print("-- Shapes --")
	var t := Card.create_by_id("berserkers_tithe")
	_check(t.is_attack() and t.is_offensive() and t.conditional_range, "Berserker's Tithe: a Conditional attack")
	for cid in ["internal_sickness", "static_sting"]:
		var c := Card.create_by_id(cid)
		_check(c.is_offensive() and not c.is_attack() and c.school != Card.CardSchool.SPELL and c.is_mixed_offensive(),
			"%s: plain Offensive — neither attack nor spell" % cid)
		_check(c.is_ranged and c.get_effective_range() == 5, "%s: ranged 5" % cid)
	var f := Card.create_by_id("fan_of_knives")
	_check(f.is_attack() and f.get_effective_range() == 2, "Fan of Knives: an attack reaching 2")
	var s := Card.create_by_id("spine_release")
	_check(s.school == Card.CardSchool.SPELL and not s.is_offensive(), "Spine Release: a utility spell, not offensive")
	var fe := Card.create_by_id("feint")
	_check(fe.card_type == Card.CardType.UTILITY and not fe.is_offensive(), "Feint: a utility")

# ---------------------------------------------------------------- Berserker's Tithe

func _test_tithe() -> void:
	print("-- Berserker's Tithe --")
	_clean()
	var e: Enemy = _field([Vector2i(1, 0)])[0]
	var bt := Card.create_by_id("berserkers_tithe")
	var r := _play(bt, e, null, func(): return {"left": NewCardsD.tithe_left(bt), "glut": main.glut_tempo_remaining, "lost": _lost(e)})
	var t := _finish()
	_check(r["played"] and r["mana"] == 0 and t == 6, "costs 0 mana and 6 tempo (%d mana, %d tempo)" % [r["mana"], t])
	_check(r["snap"].get("lost") == _phys(12), "12 damage (%s)" % str(r["snap"].get("lost")))
	_check(main.glut_tempo_remaining > 0, "Glut (%d left after the play)" % main.glut_tempo_remaining)
	_check(dm.discard_pile.has(bt) and bt.tempo_cost == 12, "no kill: discarded, tempo doubled to 12 (%d)" % bt.tempo_cost)
	_check(r["snap"].get("left") == 40, "the change lasts 40 tempo (%s)" % str(r["snap"].get("left")))
	var after_play: int = NewCardsD.tithe_left(bt)
	_check(after_play < 40 and after_play >= 34, "the 40 runs down in the discard pile (%d after the play's own ticks)" % after_play)
	# Played again while doubled: 12 tempo, and another miss does not compound.
	main.glut_tempo_remaining = 0
	dm.discard_pile.erase(bt)
	r = _play(bt, e, null, func(): return {"left": NewCardsD.tithe_left(bt), "tempo": bt.tempo_cost})
	t = _finish()
	_check(t == 12, "while doubled it costs 12 tempo (%d)" % t)
	_check(r["snap"].get("tempo") == 12 and r["snap"].get("left") == 40, "a second miss stays at 12 (never 24) and restarts the 40 (%s)" % str(r["snap"]))
	# A kill: into the draw pile, tempo halved — from the card's own 6, not from 12.
	main.glut_tempo_remaining = 0
	dm.discard_pile.erase(bt)
	var rat := _mob(Vector2i(0, -1), 5)
	r = _play(bt, rat)
	_finish()
	_check(rat.is_dead, "the blow kills")
	_check(dm.draw_pile.has(bt) and not dm.discard_pile.has(bt), "a kill: the card goes to the draw pile")
	_check(bt.tempo_cost == 3, "…with its tempo halved to 3 (%d)" % bt.tempo_cost)
	# The effect ends 40 tempo after it began, in whatever pile the card is.
	_tempo(NewCardsD.tithe_left(bt) - 1)
	_check(bt.tempo_cost == 3 and NewCardsD.tithe_left(bt) == 1, "still halved with 1 tempo left (%d)" % NewCardsD.tithe_left(bt))
	_tempo(1)
	_check(bt.tempo_cost == 6 and NewCardsD.tithe_left(bt) == 0, "after 40 tempo it is back to 6 (%d)" % bt.tempo_cost)
	# Jail does not freeze it.
	_clean()
	var jt := Card.create_by_id("berserkers_tithe")
	NewCardsD.tithe_settle(jt, dm, false)
	jt.jail_time_remaining = 100
	dm.jail_pile.append(jt)
	_tempo(10)
	_check(NewCardsD.tithe_left(jt) == 30, "the countdown runs in jail too (%d)" % NewCardsD.tithe_left(jt))
	# Halved while in hand: the play really costs 3.
	_clean()
	e = _field([Vector2i(1, 0)])[0]
	var ht := Card.create_by_id("berserkers_tithe")
	NewCardsD.tithe_settle(ht, dm, true)
	_play(ht, e)
	t = _finish()
	_check(t == 3, "while halved it costs 3 tempo (%d)" % t)

func _test_tithe_ticker() -> void:
	print("-- Berserker's Tithe: the countdown on the card face --")
	_clean()
	var bt := Card.create_by_id("berserkers_tithe")
	var face = load("res://scenes/cards/card_ui.tscn").instantiate()
	main.get_node("UI").add_child(face)
	face.setup(bt, 0)
	var ticker = face.find_child("TempoTicker", true, false)
	_check(ticker != null and not ticker.visible, "no ticker while the card has no tempo effect")
	NewCardsD.tithe_settle(bt, dm, false)
	dm.discard_pile.append(bt)
	face.setup(bt, 0)
	ticker = face.find_child("TempoTicker", true, false)
	_check(ticker != null and ticker.visible and ticker.text == "Tempo doubled: 40", "doubled: the face reads the 40 left (%s)" % (ticker.text if ticker else "none"))
	_check(ticker != null and ticker.position.y > CardUI.CARD_H * 0.85, "…on the bottom of the card")
	_tempo(7)
	if ticker:
		ticker.refresh()
	_check(ticker != null and ticker.text == "Tempo doubled: 33", "it counts down with the tempo (%s)" % (ticker.text if ticker else "none"))
	NewCardsD.tithe_settle(bt, dm, true)
	if ticker:
		ticker.refresh()
	_check(ticker != null and ticker.text == "Tempo halved: 40", "halved reads halved (%s)" % (ticker.text if ticker else "none"))
	_tempo(40)
	if ticker:
		ticker.refresh()
	_check(ticker != null and not ticker.visible, "the ticker goes when the effect ends")
	face.queue_free()

# ---------------------------------------------------------------- Internal Sickness

func _test_internal_sickness() -> void:
	print("-- Internal Sickness --")
	_clean()
	var e: Enemy = _field([Vector2i(4, 0)])[0]
	bm.apply_buff(Buff.create_strengthen(7, 3, "test"))
	dbm.apply_debuff(Debuff.create(Debuff.DebuffType.DISARM, 0, 10))
	var counter0: int = stats.current_attack_counter
	for i in range(3):
		dm.draw_pile.append(Card.create_by_id("block"))
	var isk := Card.create_by_id("internal_sickness")
	var r := _play(isk, e)
	var t := _finish()
	_check(r["played"], "Disarm does not stop a plain Offensive card")
	_check(r["mana"] == 80 and t == 1, "costs 80 mana and 1 tempo (%d mana, %d tempo)" % [r["mana"], t])
	_check(_lost(e) == _phys(10), "10 damage at range 4, without Strengthen (%d)" % _lost(e))
	var str_buff = bm.get_buff(Buff.BuffType.STRENGTHEN)
	_check(str_buff != null and str_buff.charges == 3, "Strengthen is not spent (it is for attacks)")
	_check(stats.current_attack_counter == counter0, "the attack-speed counter does not tick")
	_check(dm.discard_pile.has(isk) and dm.hand.is_empty(), "no kill: discarded, nothing drawn")
	# The kill.
	_clean()
	var rat := _mob(Vector2i(3, 0), 5)
	for i in range(3):
		dm.draw_pile.append(Card.create_by_id("block"))
	isk = Card.create_by_id("internal_sickness")
	r = _play(isk, rat, null, func(): return {"jail": isk.jail_time_remaining, "hand": dm.hand.size()})
	_check(rat.is_dead, "the hit kills")
	_check(r["snap"].get("hand") == 2 and dm.draw_pile.size() == 1, "a kill draws 2 (hand %s)" % str(r["snap"].get("hand")))
	# (Jail clocks fall 5 a cycle, so the 15 is read as the card resolves.)
	_check(dm.jail_pile.has(isk) and not dm.discard_pile.has(isk) and r["snap"].get("jail") == 15,
		"…and jails the card for 15 tempo (%s)" % str(r["snap"].get("jail")))
	_finish()
	_tempo(20)
	_check(dm.discard_pile.has(isk) and not isk.is_jailed(), "released to the discard pile afterwards")

# ---------------------------------------------------------------- Fan of Knives

func _test_fan_of_knives() -> void:
	print("-- Fan of Knives --")
	_clean()
	var foes: Array = _field([Vector2i(1, 0), Vector2i(0, -2), Vector2i(4, 0)])
	var fodder: Array = []
	for i in range(4):
		fodder.append(Card.create_by_id("block"))
		dm.hand.append(fodder[i])
	var fk := Card.create_by_id("fan_of_knives")
	var r := _play(fk, main.player)
	_check(r["played"] and r["mana"] == 65, "costs 65 mana (%d)" % r["mana"])
	_check(_answer_picker(3), "you choose the cards to discard")
	var t := _finish()
	_check(t == 8, "costs 8 tempo (%d)" % t)
	_check(dm.discard_pile.filter(func(c): return c in fodder).size() == 3 and dm.hand.size() == 1, "the 3 chosen cards are discarded")
	_check(_lost(foes[0]) + _lost(foes[1]) == 3 * _phys(4), "3 knives of 4 damage among the enemies within 2 (%d)" % (_lost(foes[0]) + _lost(foes[1])))
	_check(_lost(foes[0]) % _phys(4) == 0, "each knife is its own 4-damage hit")
	_check(_lost(foes[2]) == 0, "an enemy 4 away is never hit")
	# The ceiling is 5.
	_clean()
	foes = _field([Vector2i(1, 0)])
	for i in range(7):
		dm.hand.append(Card.create_by_id("block"))
	fk = Card.create_by_id("fan_of_knives")
	_play(fk, main.player)
	_answer_picker(7)
	_finish()
	_check(dm.hand.size() == 2, "at most 5 cards are discarded (%d left of 7)" % dm.hand.size())
	_check(_lost(foes[0]) == 5 * _phys(4), "5 knives (%d)" % _lost(foes[0]))
	# Strengthen rides each knife (an attack), a charge per hit.
	_clean()
	foes = _field([Vector2i(1, 0)])
	bm.apply_buff(Buff.create_strengthen(3, 2, "test"))
	for i in range(3):
		dm.hand.append(Card.create_by_id("block"))
	_play(Card.create_by_id("fan_of_knives"), main.player)
	_answer_picker(3)
	_finish()
	_check(_lost(foes[0]) == 3 * _phys(4) + 6 and not bm.has_buff(Buff.BuffType.STRENGTHEN), "Strengthen adds to a knife per charge (%d)" % _lost(foes[0]))
	# Nobody in reach: the cards are still discarded.
	_clean()
	foes = _field([Vector2i(4, 0)])
	for i in range(2):
		dm.hand.append(Card.create_by_id("block"))
	_play(Card.create_by_id("fan_of_knives"), main.player)
	_answer_picker(2)
	_finish()
	_check(dm.hand.is_empty() and _lost(foes[0]) == 0, "no enemy within 2: the discards are spent, nothing is hit")
	# Nothing chosen.
	_clean()
	foes = _field([Vector2i(1, 0)])
	dm.hand.append(Card.create_by_id("block"))
	_play(Card.create_by_id("fan_of_knives"), main.player)
	_answer_picker(0)
	_finish()
	_check(dm.hand.size() == 1 and _lost(foes[0]) == 0, "discarding nothing throws nothing")

# ---------------------------------------------------------------- Static Sting

func _test_static_sting() -> void:
	print("-- Static Sting --")
	_clean()
	var foes: Array = _field([Vector2i(2, 0), Vector2i(3, 1), Vector2i(2, -4)])
	bm.apply_buff(Buff.create_strengthen(7, 3, "test"))
	var ss := Card.create_by_id("static_sting")
	var r := _play(ss, foes[0], null, func(): return {"a": foes[0].shock_stacks, "b": foes[1].shock_stacks, "lost": _lost(foes[0])})
	var t := _finish()
	_check(r["mana"] == 30 and t == 2, "costs 30 mana and 2 tempo (%d mana, %d tempo)" % [r["mana"], t])
	_check(r["snap"].get("lost") == _phys(2), "2 damage, no Strengthen (%s)" % str(r["snap"].get("lost")))
	_check(ss.damage_type == DamageTypes.Type.LIGHTNING, "lightning damage")
	_check(r["snap"].get("a") == 2 and r["snap"].get("b") == 0, "2 Shock on the target; no arc from a target that had none")
	var str_buff = bm.get_buff(Buff.BuffType.STRENGTHEN)
	_check(str_buff != null and str_buff.charges == 3, "Strengthen is not spent")
	# Already Shocked: the charge arcs.
	foes[0].shock_stacks = 3
	foes[1].shock_stacks = 0
	foes[2].shock_stacks = 0
	r = _play(Card.create_by_id("static_sting"), foes[0], null, func(): return {"a": foes[0].shock_stacks, "b": foes[1].shock_stacks, "c": foes[2].shock_stacks})
	_finish()
	_check(r["snap"].get("a") == 5, "a Shocked target takes 2 more Shock (%s)" % str(r["snap"].get("a")))
	_check(r["snap"].get("b") == 1, "…and 1 Shock arcs to the nearest other enemy within 2 (%s)" % str(r["snap"].get("b")))
	_check(r["snap"].get("c") == 0, "an enemy further than 2 from the target gets nothing")
	# Nobody within 2 of the target: no arc.
	_clean()
	foes = _field([Vector2i(2, 0), Vector2i(2, -4)])
	foes[0].shock_stacks = 1
	r = _play(Card.create_by_id("static_sting"), foes[0], null, func(): return {"a": foes[0].shock_stacks, "b": foes[1].shock_stacks})
	_finish()
	_check(r["snap"].get("a") == 3 and r["snap"].get("b") == 0, "no enemy within 2: the arc has nowhere to go")

# ---------------------------------------------------------------- Feint

func _test_feint() -> void:
	print("-- Feint --")
	_clean()
	var foes: Array = _field([Vector2i(1, 0), Vector2i(0, -1)])
	var slash := Card.create_by_id("slash")
	var block := Card.create_by_id("block")
	var spark := Card.create_by_id("spark")  # an offensive spell: not an attack
	dm.hand.append(slash)
	dm.hand.append(block)
	dm.hand.append(spark)
	var slash_tempo: int = slash.get_burden_tempo_cost()
	var fe := Card.create_by_id("feint")
	var r := _play(fe, foes[0], null, func(): return {"v": foes[0].vulnerable_stacks})
	var t := _finish()
	_check(r["played"] and r["mana"] == 60 and t == 0, "costs 60 mana and 0 tempo (%d mana, %d tempo)" % [r["mana"], t])
	_check(r["snap"].get("v") == 2, "2 Vulnerable on the enemy (%s)" % str(r["snap"].get("v")))
	_check(slash.bonus_damage == 5 and slash.get_burden_tempo_cost() == slash_tempo + 2, "the attack in hand gains +5 damage and +2 tempo")
	_check(block.bonus_damage == 0 and spark.bonus_damage == 0 and spark.temp_hand_tempo_reduction == 0, "only an attack card is picked — not a spell, not a block")
	_check(int(main.get_card_vacuum_values(slash).get("damage", 0)) == _phys(15), "the hand shows the raised damage (%s)" % str(main.get_card_vacuum_values(slash).get("damage")))
	# The buffed attack is played: +5, +2 tempo, and then it is over.
	r = _play(slash, foes[1])
	t = _finish()
	_check(_lost(foes[1]) == _phys(15), "the buffed Slash deals 10 + 5 (%d)" % _lost(foes[1]))
	_check(t == slash_tempo + 2, "…for 2 more tempo (%d)" % t)
	_check(slash.bonus_damage == 0 and slash.get_burden_tempo_cost() == slash_tempo, "played: the rider is gone")
	# Leaving the hand ends it too.
	_clean()
	foes = _field([Vector2i(1, 0)])
	slash = Card.create_by_id("slash")
	dm.hand.append(slash)
	_play(Card.create_by_id("feint"), foes[0])
	_finish()
	_check(slash.bonus_damage == 5, "(set up again)")
	dm.discard_card_from_hand(slash)
	_check(slash.bonus_damage == 0 and slash.get_burden_tempo_cost() == slash_tempo, "discarded from hand: the rider is gone")
	# No attack in hand: only the Vulnerable.
	_clean()
	foes = _field([Vector2i(1, 0)])
	block = Card.create_by_id("block")
	dm.hand.append(block)
	r = _play(Card.create_by_id("feint"), foes[0], null, func(): return {"v": foes[0].vulnerable_stacks})
	_finish()
	_check(r["snap"].get("v") == 2 and block.bonus_damage == 0 and block.temp_hand_tempo_reduction == 0, "no attack in hand: just the Vulnerable")

# ---------------------------------------------------------------- Cadence

func _test_cadence() -> void:
	print("-- Cadence --")
	_clean()
	var threshold: int = stats.get_attack_speed_threshold()
	stats.current_attack_counter = 8
	var cd := Card.create_by_id("cadence")
	var r := _play(cd, main.player)
	var t := _finish()
	_check(r["played"] and r["mana"] == 10 and t == 1, "costs 10 mana and 1 tempo (%d mana, %d tempo)" % [r["mana"], t])
	_check(stats.current_attack_counter == 3, "the attack-speed counter advances by 5 (8 -> %d)" % stats.current_attack_counter)
	_check(not bm.has_buff(Buff.BuffType.HASTE) and not dm.next_attack_half_tempo, "no proc, no Haste")
	# It crosses the line: the proc fires, and Haste 1 for one move.
	_clean()
	stats.current_attack_counter = 3
	_play(Card.create_by_id("cadence"), main.player)
	_finish()
	_check(dm.next_attack_half_tempo, "the 5 ticks trigger the DEX proc")
	_check(stats.current_attack_counter == threshold - 2, "the ticks left over start the next count (%d of %d)" % [stats.current_attack_counter, threshold])
	var haste = bm.get_buff(Buff.BuffType.HASTE)
	_check(haste != null and haste.value == 1 and haste.charges == 1, "Haste 1 for the next move")
	dm.next_attack_half_tempo = false
	dm.next_attack_mana_discount = 0

# ---------------------------------------------------------------- Grit

func _armor_of(amount: int) -> int:
	return amount + stats.enchantment_block_bonus + stats.sphere_bonus_block + stats.get_defense_card_block()

func _test_grit() -> void:
	print("-- Grit --")
	_clean()
	var g := Card.create_by_id("grit")
	var r := _play(g, main.player, null, func(): return {"armor": stats.current_armor})
	var t := _finish()
	_check(r["played"] and r["mana"] == 30 and t == 2, "costs 30 mana and 2 tempo (%d mana, %d tempo)" % [r["mana"], t])
	_check(r["snap"].get("armor") == 0 and not bm.has_buff(Buff.BuffType.BOLSTER), "at full health: no armor, no Bolster (%s)" % str(r["snap"].get("armor")))
	_clean()
	stats.current_health = 325  # 35% missing: three whole steps
	r = _play(Card.create_by_id("grit"), main.player, null, func(): return {"armor": stats.current_armor})
	_finish()
	_check(r["snap"].get("armor") == _armor_of(6), "35%% missing: 2 armor x 3 (%s)" % str(r["snap"].get("armor")))
	_check(not bm.has_buff(Buff.BuffType.BOLSTER), "above 30% health: no Bolster")
	_clean()
	stats.current_health = 150  # exactly 30%: not below
	r = _play(Card.create_by_id("grit"), main.player, null, func(): return {"armor": stats.current_armor})
	_finish()
	_check(r["snap"].get("armor") == _armor_of(14) and not bm.has_buff(Buff.BuffType.BOLSTER), "at exactly 30%%: 14 armor, no Bolster (%s)" % str(r["snap"].get("armor")))
	_clean()
	stats.current_health = 140  # 28% health, 72% missing
	r = _play(Card.create_by_id("grit"), main.player, null, func(): return {"armor": stats.current_armor})
	_finish()
	_check(r["snap"].get("armor") == _armor_of(14), "72%% missing: 2 armor x 7 (%s)" % str(r["snap"].get("armor")))
	var bol = bm.get_buff(Buff.BuffType.BOLSTER)
	_check(bol != null and bol.value == 2 + stats.sphere_bolster_amp and bol.charges == 3, "below 30%: Bolster 2")
	# The Bolster it left adds to the next armor gain.
	stats.current_armor = 0
	r = _play(Card.create_by_id("grit"), main.player, null, func(): return {"armor": stats.current_armor})
	_finish()
	_check(r["snap"].get("armor") == _armor_of(14 + 2 + stats.sphere_bolster_amp), "a second Grit gains Bolster's +2 (%s)" % str(r["snap"].get("armor")))

# ---------------------------------------------------------------- Spine Release

func _test_spine_release() -> void:
	print("-- Spine Release --")
	_clean()
	var foes: Array = _field([Vector2i(1, 0), Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, 0)])
	bm.apply_buff(Buff.create_thorns(10, 50, "test"))
	stats.maintained_thorns = 4
	var sr := Card.create_by_id("spine_release")
	var r := _play(sr, main.player)
	var t := _finish()
	_check(r["played"] and r["mana"] == 70 and t == 2, "costs 70 mana and 2 tempo (%d mana, %d tempo)" % [r["mana"], t])
	var hits: Array = [_lost(foes[0]), _lost(foes[1]), _lost(foes[2])]
	_check(hits[0] + hits[1] + hits[2] == 10, "all 10 Thorns are dealt to the enemies around you (%s)" % str(hits))
	_check(hits[2] == 3 and mini(hits[0], hits[1]) == 3 and maxi(hits[0], hits[1]) == 4, "split equally, diagonal included; the odd point goes to a nearest one (%s)" % str(hits))
	_check(_lost(foes[3]) == 0, "two tiles away is not in the circle")
	_check(not bm.has_buff(Buff.BuffType.THORNS), "the Thorns are spent")
	_check(bm.get_thorns_damage() == 4, "maintained thorns are not spent (%d)" % bm.get_thorns_damage())
	stats.maintained_thorns = 0
	# Nobody adjacent: the Thorns stay.
	_clean()
	foes = _field([Vector2i(2, 0)])
	bm.apply_buff(Buff.create_thorns(6, 50, "test"))
	r = _play(Card.create_by_id("spine_release"), main.player)
	_finish()
	_check(r["mana"] == 70 and NewCardsD.spendable_thorns(bm) == 6 and _lost(foes[0]) == 0, "no enemy beside you: nothing is spent")
	# Flat damage: one enemy takes exactly the Thorns.
	_clean()
	foes = _field([Vector2i(-1, -1)])
	bm.apply_buff(Buff.create_thorns(7, 50, "test"))
	_play(Card.create_by_id("spine_release"), main.player)
	_finish()
	_check(_lost(foes[0]) == 7, "one enemy takes them all, unscaled (%d)" % _lost(foes[0]))
	# A spell: Silence stops it.
	_clean()
	foes = _field([Vector2i(1, 0)])
	bm.apply_buff(Buff.create_thorns(7, 50, "test"))
	dbm.apply_debuff(Debuff.create(Debuff.DebuffType.SILENCE, 0, 10))
	r = _play(Card.create_by_id("spine_release"), main.player)
	_finish()
	_check(not r["played"] and NewCardsD.spendable_thorns(bm) == 7, "Silence blocks it (a spell)")
