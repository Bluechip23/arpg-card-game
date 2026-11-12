extends SceneTree

## Sheet batch B (docs/new_cards/B.md): the instants (Soul Consumption, Not So
## Fast, Spiteful Sting, Pocket Shiv), the jail cards (Slow and Steady Wins, Self
## Admission) and the deck-order cards (Reverse Reverse, Foresight).
## Every card runs through the real Main in the dojo: hand-played cards go
## through play_selected_card and the tempo queue, instants fire from their
## real trigger sites (an enemy dying, an enemy's blow, a wounded ally, a
## discard), and the pickers are answered by pressing their buttons.
## Run: godot --headless --path . --script tests/test_new_cards_b.gd

const HOME := Vector2i(8, 6)

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
	print("=== New cards: batch B ===")
	TempoManager.preferred_swing_hold = 0  # resolve on the tick, no swing wait
	await _boot()
	if main == null:
		print("=== %d failure(s) ===" % failures)
		quit(1)
		return
	_test_data()
	_test_soul_consumption()
	_test_not_so_fast()
	_test_spiteful_sting()
	await _test_pocket_shiv()
	_test_deep_breaths()
	_test_self_admission()
	await _test_reverse_reverse()
	await _test_foresight()
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

func _cell(node) -> Vector2i:
	return gm.world_to_grid(node.position)

func _place(node, off: Vector2i) -> void:
	node.position = main._ground_pos(HOME + off)
	node.target_position = node.position

## Clear the field and stand fresh enemies at these offsets from HOME.
func _field(offsets: Array, type: int = Enemy.EnemyType.DUMMY) -> Array:
	var old: Array = main.enemy_spawner.enemies.duplicate()
	var out: Array = []
	for off in offsets:
		var e: Enemy = main.enemy_spawner.spawn_enemy(type, main._ground_pos(HOME + off))
		e.chosen_action = {}
		out.append(e)
	for e in old:
		main.enemy_spawner.despawn_enemy(e)
	return out

func _rat(off: Vector2i, hp: int) -> Enemy:
	var r: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.MINION, main._ground_pos(HOME + off))
	r.chosen_action = {}
	r.current_armor = 0
	r.current_health = hp
	return r

func _lost(e) -> int:
	return e.max_health - e.current_health

func _fresh() -> void:
	_drain()
	_close_pickers()
	main._pending_resolve_queue.clear()
	main.glut_tempo_remaining = 0
	main.draw_timer.tempo_until_draw = 1e9  # no timed draws mid-check
	_place(main.player, Vector2i.ZERO)
	main._player_last_grid_cell = HOME
	for a in main._dojo_allies:
		_place(a, Vector2i(-7, -5))  # out of every range until a check calls one in
	dm.hand.clear()
	dm.draw_pile.clear()
	dm.discard_pile.clear()
	dm.jail_pile.clear()
	dm.brain_peek_depth = 0
	dm.next_attack_half_tempo = false
	dm.next_attack_mana_discount = 0
	bm.buffs.clear()
	dbm.clear_all_debuffs()
	stats.max_health = 500
	stats.current_health = 500
	stats.current_temp_health = 0
	stats.current_armor = 0
	stats.max_mana = 2000
	stats.current_mana = 1000
	stats.current_brain_points = 0
	stats.hit_streak = 0

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

func _on_resolved(_card: Card) -> void:
	if _probe.is_valid():
		_snap = _probe.call()
		_probe = Callable()

## Play `card` through main.play_selected_card and tick until it RESOLVES.
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

func _heal_of(amount: int) -> int:
	stats.current_health = 300
	stats.heal(amount)
	var got := stats.current_health - 300
	stats.current_health = 500
	return got

func _c(id: String) -> Card:
	return Card.create_by_id(id)

# -- pickers: the live overlay of a kind, and its buttons

## The live picker overlay of a kind. A picker opened from another picker's
## answer is added while the old overlay is still queued for deletion, so the
## engine renames it; they are told apart by what they hold instead (the
## full-card picker's cards are toggle buttons).
func _picker(kind: String) -> Node:
	var ui = main.get_node_or_null("UI")
	if ui == null:
		return null
	for ch in ui.get_children():
		if not (ch is ColorRect) or ch.is_queued_for_deletion() \
				or ch.process_mode != Node.PROCESS_MODE_ALWAYS or ch.mouse_filter != Control.MOUSE_FILTER_STOP:
			continue
		var full := false
		for b in _buttons(ch):
			if b.toggle_mode:
				full = true
		if (kind == "FullCardPicker") == full:
			return ch
	return null

func _close_pickers() -> void:
	for kind in ["HandCardPicker", "FullCardPicker"]:
		var p := _picker(kind)
		while p != null:
			p.free()
			p = _picker(kind)

func _buttons(root: Node) -> Array:
	var out: Array = []
	for ch in root.get_children():
		if ch is Button:
			out.append(ch)
		out.append_array(_buttons(ch))
	return out

## Press the hand-card picker's button with this label ("Cancel" included).
func _hand_pick(label: String) -> bool:
	var p := _picker("HandCardPicker")
	if p == null:
		return false
	for b in _buttons(p):
		if b.text == label:
			b.pressed.emit()
			return true
	return false

## The full-card picker's card labels, in the order shown.
func _full_count() -> int:
	var p := _picker("FullCardPicker")
	if p == null:
		return -1
	var n := 0
	for b in _buttons(p):
		if b.toggle_mode:
			n += 1
	return n

## Toggle the full-card picker's i-th card and confirm.
func _full_pick(i: int) -> bool:
	var p := _picker("FullCardPicker")
	if p == null:
		return false
	var toggles: Array = []
	var confirm: Button = null
	for b in _buttons(p):
		if b.toggle_mode:
			toggles.append(b)
		elif b.text.begins_with("Confirm"):
			confirm = b
	if i >= toggles.size() or confirm == null:
		return false
	toggles[i].button_pressed = true
	if confirm.disabled:
		return false
	confirm.pressed.emit()
	return true

# ---------------------------------------------------------------- data

func _test_data() -> void:
	print("-- The cards as built --")
	for row in [["soul_consumption", 0, 0], ["not_so_fast", 0, 0], ["spiteful_sting", 0, 0], ["pocket_shiv", 0, 0]]:
		var c := _c(row[0])
		_check(c != null and c.card_type == Card.CardType.REACTION and c.mana_cost == row[1] and c.tempo_cost == row[2],
			"%s is a free instant" % row[0])
		_check(c.reaction_trigger != "on_damage_taken" and c.reaction_trigger != "on_ally_damage_taken",
			"%s has a trigger of its own (%s), not Cover's or Whirling Weapon's" % [row[0], c.reaction_trigger])
	_check(_c("soul_consumption").school == Card.CardSchool.SPELL, "soul_consumption is a spell instant")
	_check(_c("not_so_fast").is_attack() and _c("spiteful_sting").is_attack() and _c("pocket_shiv").is_attack(),
		"the other three instants are attacks")
	var db := _c("slow_and_steady_wins")
	_check(db.card_name == "Slow and Steady Wins" and db.mana_cost == 100 and db.tempo_cost == 6 and db.resolve_tick == 4,
		"slow_and_steady_wins: 100 mana, 6 tempo, resolves on 4")
	_check(not ("Instant" in db.description), "slow_and_steady_wins does not read as an instant to Lethal Recall")
	_check(_c("deep_breaths").card_id == "deep_breaths" and _c("deep_breaths").heal_amount > 0,
		"the item's Deep Breaths (heal) is left alone")
	var rr := _c("reverse_reverse")
	_check(rr.mana_cost == 50 and rr.tempo_cost == 3 and rr.resolve_tick == 1, "reverse_reverse: 50 mana, 3 tempo, resolves on 1")
	_check(rr.get_effect_draw_count() == 1, "reverse_reverse holds a hand slot for its draw")
	var sa := _c("self_admission")
	_check(sa.mana_cost == 10 and sa.tempo_cost == 0, "self_admission: 10 mana, 0 tempo")
	var fs := _c("foresight")
	_check(fs.mana_cost == 20 and fs.tempo_cost == 0, "foresight: 20 mana, 0 tempo")

# ---------------------------------------------------------------- instants

func _test_soul_consumption() -> void:
	print("-- Soul Consumption --")
	_fresh()
	var foes := _field([Vector2i(3, 0), Vector2i(1, 4), Vector2i(-7, 3)])
	var rat := _rat(Vector2i(1, 0), 5)
	var sc := _c("soul_consumption")
	dm.hand.append(sc)
	var drawn := _c("block")
	dm.draw_pile.append(drawn)
	foes[2].take_damage(3, true)
	_check(dm.hand.has(sc), "a wound that does not kill leaves it in hand")
	rat.take_damage(999, true)
	_check(rat.is_dead, "the rat dies")
	_check(not dm.hand.has(sc) and dm.discard_pile.has(sc), "it fires from the hand when an enemy dies")
	_check(_lost(foes[0]) == 6, "6 damage to the nearest other enemy within 3 of the kill (%d)" % _lost(foes[0]))
	_check(_lost(foes[1]) == 0, "an enemy 4 squares from the kill is untouched")
	_check(dm.hand.has(drawn), "and a card is drawn")
	_check(main._last_played_card == sc, "Lethal Recall remembers it as the last instant")

	# Kill credit: only the players' kills feed it.
	_fresh()
	var witness: Enemy = _field([Vector2i(2, 0)])[0]
	var own_death := _rat(Vector2i(1, 0), 5)
	var sc_k := _c("soul_consumption")
	dm.hand.append(sc_k)
	own_death.take_damage(999, false)
	_check(own_death.is_dead and not own_death.kill_credit_player and dm.hand.has(sc_k) and _lost(witness) == 0,
		"an enemy that dies to something else (not your blow) does not set it off")
	var dot_death := _rat(Vector2i(1, 0), 5)
	dot_death._dot_hit("Poison", 999)
	_check(dot_death.is_dead and dot_death.kill_credit_player and not dm.hand.has(sc_k),
		"a kill by your damage-over-time is your kill")

	# The chain: its 6 kills the next rat, and the second copy answers THAT death.
	_fresh()
	var far: Enemy = _field([Vector2i(6, 0)])[0]
	var r1 := _rat(Vector2i(1, 0), 5)
	var r2 := _rat(Vector2i(3, 0), 6)
	var a := _c("soul_consumption")
	var b := _c("soul_consumption")
	dm.hand.append(a)
	dm.hand.append(b)
	dm.draw_pile.append(_c("block"))
	dm.draw_pile.append(_c("block"))
	r1.take_damage(999, true)
	_check(r2.is_dead, "its 6 damage kills the 6-health rat two squares off")
	_check(_lost(far) == 6, "the second copy chains off that kill: 6 to the enemy 3 from the second rat, 5 from the first (%d)" % _lost(far))
	_check(not dm.hand.has(a) and not dm.hand.has(b) and dm.hand.size() == 2, "both copies fired and each drew a card (hand %d)" % dm.hand.size())

	# No other enemy in reach: it still fires and draws.
	_fresh()
	_field([Vector2i(-7, 3)])
	var lone := _rat(Vector2i(1, 0), 5)
	var sc3 := _c("soul_consumption")
	dm.hand.append(sc3)
	dm.draw_pile.append(_c("block"))
	lone.take_damage(999, true)
	_check(dm.discard_pile.has(sc3) and dm.hand.size() == 1, "with no enemy within 3 it still fires and draws")

	# A spell instant: Silence holds it.
	_fresh()
	var hush := _rat(Vector2i(1, 0), 5)
	var sc4 := _c("soul_consumption")
	dm.hand.append(sc4)
	dbm.apply_debuff(Debuff.new(Debuff.DebuffType.SILENCE, 0, 10))
	if dbm.can_play_spell_cards():
		_check(false, "the harness could not Silence the player")
	else:
		hush.take_damage(999, true)
		_check(dm.hand.has(sc4), "Silenced: the spell instant stays in hand")

func _test_not_so_fast() -> void:
	print("-- Not So Fast --")
	_fresh()
	var ally = main._dojo_allies[0] if not main._dojo_allies.is_empty() else null
	_check(ally != null, "the dojo has an ally to protect")
	if ally == null:
		return
	# You at (0,0), the ally at (2,0). (1,0) touches both tiles; (-1,0) only
	# the take-off, (3,1) only the landing; (5,0) neither.
	var foes := _field([Vector2i(1, 0), Vector2i(-1, 0), Vector2i(3, 1), Vector2i(5, 0)])
	_place(ally, Vector2i(2, 0))
	var nsf := _c("not_so_fast")
	dm.hand.append(nsf)
	dm.hand.append(_c("block"))
	# Your own wounds do not set it off — and it is not a Cover (no soak).
	stats.take_damage(10, dbm, bm)
	_check(dm.hand.has(nsf) and stats.current_health == 490, "your own hit: it stays in hand and soaks nothing (health %d)" % stats.current_health)
	var ally_hp: int = ally.get_stats().current_health
	ally.get_stats().take_damage(10)
	_check(not dm.hand.has(nsf) and dm.discard_pile.has(nsf), "an ally within 6 is hit: it fires")
	_check(_cell(main.player) == HOME + Vector2i(2, 0) and _cell(ally) == HOME, "you and the ally swap places")
	_check(ally.get_stats().current_health == ally_hp - 10, "the ally still takes the hit")
	_check(_lost(foes[1]) == 6, "6 to the enemy beside the take-off tile (%d)" % _lost(foes[1]))
	_check(_lost(foes[2]) == 6, "6 to the enemy beside the landing tile, diagonals count (%d)" % _lost(foes[2]))
	_check(_lost(foes[0]) == 6, "an enemy beside both tiles takes it once (%d)" % _lost(foes[0]))
	_check(_lost(foes[3]) == 0, "an enemy beside neither is untouched")

	# Seven squares away is out of reach.
	_fresh()
	_field([Vector2i(1, 0)])
	_place(ally, Vector2i(7, 0))
	var far := _c("not_so_fast")
	dm.hand.append(far)
	ally.get_stats().take_damage(10)
	_check(dm.hand.has(far) and _cell(main.player) == HOME, "an ally 7 squares away: nothing")
	# Six is in.
	_place(ally, Vector2i(6, 0))
	ally.get_stats().take_damage(10)
	_check(not dm.hand.has(far) and _cell(main.player) == HOME + Vector2i(6, 0), "an ally 6 squares away: it fires")

	# One copy per hit: a second would only swap straight back.
	_fresh()
	_field([Vector2i(1, 0)])
	_place(ally, Vector2i(2, 0))
	var n1 := _c("not_so_fast")
	var n2 := _c("not_so_fast")
	dm.hand.append(n1)
	dm.hand.append(n2)
	ally.get_stats().take_damage(10)
	_check(dm.hand.size() == 1 and _cell(main.player) == HOME + Vector2i(2, 0), "two copies: one fires per hit")

	# Swap itself still works through the shared position trade.
	_fresh()
	var se: Enemy = _field([Vector2i(3, 0)])[0]
	_play(_c("swap"), se)
	_check(_cell(main.player) == HOME + Vector2i(3, 0) and _cell(se) == HOME, "the Swap card still trades places with its target")
	_finish()

func _test_spiteful_sting() -> void:
	print("-- Spiteful Sting --")
	_fresh()
	var foes := _field([Vector2i(1, 1), Vector2i(2, 0)])
	var ss := _c("spiteful_sting")
	dm.hand.append(ss)
	var drawn := _c("block")
	dm.draw_pile.append(drawn)
	foes[1]._deal_damage_to_player(main.player, 3, "Bite")
	_check(dm.hand.has(ss) and foes[1].poison_stacks == 0, "a hit from 2 squares away: nothing")
	stats.take_damage(3, dbm, bm)
	_check(dm.hand.has(ss), "damage with no attacker (a cost, a tick): nothing")
	foes[0]._deal_damage_to_player(main.player, 3, "Bite")
	_check(not dm.hand.has(ss) and dm.discard_pile.has(ss), "a hit from an adjacent enemy (diagonal): it fires")
	_check(foes[0].poison_stacks == 4, "4 Poison on the attacker (%d)" % foes[0].poison_stacks)
	_check(foes[1].poison_stacks == 0, "only the attacker is poisoned")
	_check(dm.hand.has(drawn), "and a card is drawn")
	_check(main._last_played_card == ss, "Lethal Recall remembers it")
	# Lethal Recall's replay runs the same site effect with no attacker in hand.
	dm.draw_pile.append(_c("block"))
	main._fire_instant_site_effect(ss, {"target": null, "replay": true})
	_check(foes[0].poison_stacks == 8 and dm.hand.size() == 2, "a replay poisons the enemy in melee range again and draws")

func _test_pocket_shiv() -> void:
	print("-- Pocket Shiv --")
	_fresh()
	var foes := _field([Vector2i(1, 0), Vector2i(3, 0)])
	var shiv := _c("pocket_shiv")
	var junk := _c("block")
	var keep := _c("block")
	dm.hand.append(shiv)
	dm.hand.append(junk)
	dm.hand.append(keep)
	stats.current_mana = 500
	# A PLAYED card reaching the discard pile is not a discard.
	_play(keep, main.player)
	_finish()
	await process_frame
	_check(dm.hand.has(shiv), "playing a card does not set it off")
	stats.current_mana = 500
	dm.discard_card_from_hand(junk)
	await process_frame
	_check(not dm.hand.has(shiv) and dm.discard_pile.has(shiv), "discarding another card from the hand fires it")
	_check(int(stats.current_mana) == 510, "gain 10 mana (%d)" % int(stats.current_mana))
	_check(_lost(foes[0]) == 5, "5 damage to the enemy in melee range (%d)" % _lost(foes[0]))
	_check(_lost(foes[1]) == 0, "not to one 3 squares away")

	# No enemy in melee range: the mana is still gained.
	_fresh()
	var off: Enemy = _field([Vector2i(3, 0)])[0]
	var s2 := _c("pocket_shiv")
	var j2 := _c("block")
	dm.hand.append(s2)
	dm.hand.append(j2)
	stats.current_mana = 500
	dm.discard_card_from_hand(j2)
	await process_frame
	_check(dm.discard_pile.has(s2) and int(stats.current_mana) == 510 and _lost(off) == 0,
		"no enemy in melee range: it fires for the mana alone")

	# Discarding the Shiv itself does nothing; a second Shiv answers it.
	_fresh()
	var near: Enemy = _field([Vector2i(1, 0)])[0]
	var lone := _c("pocket_shiv")
	dm.hand.append(lone)
	stats.current_mana = 500
	dm.discard_card_from_hand(lone)
	await process_frame
	_check(int(stats.current_mana) == 500 and _lost(near) == 0, "discarding Pocket Shiv itself: nothing")

	# An instant firing is spent, not discarded.
	_fresh()
	var foe: Enemy = _field([Vector2i(1, 0)])[0]
	var s3 := _c("pocket_shiv")
	var sting := _c("spiteful_sting")
	dm.hand.append(s3)
	dm.hand.append(sting)
	dm.draw_pile.append(_c("block"))  # Sting's draw
	foe._deal_damage_to_player(main.player, 1, "Bite")
	await process_frame
	_check(not dm.hand.has(sting) and dm.hand.has(s3), "another instant firing from the hand is not a discard")

	# Two Shivs both answer one discard.
	_fresh()
	var two: Enemy = _field([Vector2i(1, 0)])[0]
	var j3 := _c("block")
	for c in [_c("pocket_shiv"), _c("pocket_shiv"), j3]:
		dm.hand.append(c)
	stats.current_mana = 500
	dm.discard_card_from_hand(j3)
	await process_frame
	_check(int(stats.current_mana) == 520 and _lost(two) == 10 and dm.hand.is_empty(), "two copies: +20 mana, 10 damage")

# ---------------------------------------------------------------- jail

func _test_deep_breaths() -> void:
	print("-- Slow and Steady Wins (slow_and_steady_wins) --")
	_fresh()
	var foes := _field([Vector2i(1, 0)])
	var in_hand := _c("spider_senses")
	var in_draw := _c("vengeful_shield")
	var in_discard := _c("composed_reaction")
	var plain_h := _c("block")
	var plain_d := _c("block")
	var plain_x := _c("block")
	dm.hand.append(in_hand)
	dm.hand.append(plain_h)
	dm.draw_pile.append(in_draw)
	dm.draw_pile.append(plain_d)
	dm.discard_pile.append(in_discard)
	dm.discard_pile.append(plain_x)
	var db := _c("slow_and_steady_wins")
	var r := _play(db, main.player, func():
		return {"jail": dm.jail_pile.duplicate(), "times": dm.jail_pile.map(func(c): return c.jail_time_remaining),
			"temp": stats.current_temp_health})
	var t := _finish()
	_check(r["played"] and r["mana"] == 100, "costs 100 mana (%d)" % r["mana"])
	_check(t == 6, "costs 6 tempo (%d)" % t)
	var jailed: Array = r["snap"].get("jail", [])
	_check(jailed.size() == 3 and in_hand in jailed and in_draw in jailed and in_discard in jailed,
		"jails the instants in the hand, the draw pile and the discard pile (%d)" % jailed.size())
	_check(r["snap"].get("times") == [20, 20, 20], "each for 20 tempo (%s)" % str(r["snap"].get("times")))
	_check(r["snap"].get("temp") == 30, "10 temp HP per card jailed: 30 (%s)" % str(r["snap"].get("temp")))
	_check(dm.hand.has(plain_h) and dm.draw_pile.has(plain_d) and dm.discard_pile.has(plain_x),
		"other cards stay where they were")
	# Time served: back to the discard pile, like every jailed card.
	for c in dm.jail_pile:
		c.jail_time_remaining = 5
	dm.process_turn()
	_check(dm.jail_pile.is_empty() and dm.discard_pile.has(in_draw), "they return through the usual jail release")
	# The next trigger of a returned instant grants 10 armor on top of its own 5.
	dm.discard_pile.erase(in_draw)
	dm.hand.append(in_draw)
	stats.current_armor = 0
	main._on_player_armor_broken()
	_check(not dm.hand.has(in_draw) and stats.current_armor == 15, "a returned Vengeful Shield triggers for its 5 armor + 10 (%d)" % stats.current_armor)
	_check(foes[0].is_stunned, "…and its own effect still lands (the stun)")
	# Once only.
	dm.discard_pile.erase(in_draw)
	dm.hand.append(in_draw)
	stats.current_armor = 0
	main._on_player_armor_broken()
	_check(stats.current_armor == 5, "the trigger after that is back to its own 5 (%d)" % stats.current_armor)

	# Nothing to jail: no temp HP.
	_fresh()
	dm.hand.append(_c("block"))
	_play(_c("slow_and_steady_wins"), main.player)
	_finish()
	_check(dm.jail_pile.is_empty() and stats.current_temp_health == 0, "no instants anywhere: nothing jailed, no temp HP")

func _test_self_admission() -> void:
	print("-- Self Admission --")
	_fresh()
	var foe: Enemy = _field([Vector2i(1, 0)])[0]
	var heal20 := _heal_of(20)
	var sa := _c("self_admission")
	var pick := _c("block")
	var other := _c("draw")
	dm.hand.append(sa)
	dm.hand.append(other)
	dm.hand.append(pick)
	sa.picked_card = pick
	var r := _play(sa, main.player)
	var t := _finish()
	_check(r["played"] and r["mana"] == 10 and t == 0, "costs 10 mana, 0 tempo (%d mana, %d tempo)" % [r["mana"], t])
	_check(dm.jail_pile.has(pick) and pick.jail_time_remaining == 20 and not dm.hand.has(pick), "the chosen card is jailed for 20 tempo")
	_check(dm.hand.has(other), "the other hand card stays")
	_check(bm.get_buff(Buff.BuffType.STRENGTHEN) == null, "no payoff while it is away")
	# Four cycles of jail, then the discard pile — still no payoff.
	for _i in range(4):
		dm.process_turn()
	_check(dm.discard_pile.has(pick) and not pick.is_jailed(), "after 20 tempo it is released to the discard pile")
	_check(bm.get_buff(Buff.BuffType.STRENGTHEN) == null, "released is not yet 'in your hand'")
	# Drawn again: the payoff.
	dm.discard_pile.erase(pick)
	dm.draw_pile.append(pick)
	stats.current_health = 400
	stats.current_mana = 500
	dm.draw_card()
	var st = bm.get_buff(Buff.BuffType.STRENGTHEN)
	_check(dm.hand.has(pick) and st != null and st.value == 5, "back in hand: Strengthen 5")
	_check(stats.current_health == 400 + heal20, "heal 20 (%d)" % (stats.current_health - 400))
	_check(int(stats.current_mana) == 520, "gain 20 mana (%d)" % int(stats.current_mana))
	_check(pick.temp_hand_tempo_reduction == 1, "the card costs 1 less tempo")
	stats.current_health = 500
	var rp := _play(pick, main.player)
	var tp := _finish()
	_check(rp["played"] and tp == pick.tempo_cost - 1, "…and plays for %d tempo instead of %d (%d)" % [pick.tempo_cost - 1, pick.tempo_cost, tp])
	# Once only: the next time it is drawn nothing more happens.
	bm.buffs.clear()
	dm.discard_pile.erase(pick)
	dm.draw_pile.append(pick)
	stats.current_mana = 500
	dm.draw_card()
	_check(bm.get_buff(Buff.BuffType.STRENGTHEN) == null and int(stats.current_mana) == 500 and pick.temp_hand_tempo_reduction == 0,
		"the payoff is paid once")

	# Freed straight to the hand (Ragnarok's release) pays off at once.
	_fresh()
	_field([Vector2i(1, 0)])
	var sa2 := _c("self_admission")
	var pick2 := _c("block")
	dm.hand.append(sa2)
	dm.hand.append(pick2)
	sa2.picked_card = pick2
	_play(sa2, main.player)
	_finish()
	stats.current_mana = 500
	dm.release_jailed_to_hand()
	_check(dm.hand.has(pick2) and int(stats.current_mana) == 520 and pick2.temp_hand_tempo_reduction == 1,
		"a card freed straight into the hand pays off there")

	# Nothing else in hand: the card is spent and nothing is jailed.
	_fresh()
	var sa3 := _c("self_admission")
	var r3 := _play(sa3, main.player)
	_finish()
	_check(r3["played"] and dm.jail_pile.is_empty(), "an empty hand: nothing to jail")
	foe = null

# ---------------------------------------------------------------- deck order

func _test_reverse_reverse() -> void:
	print("-- Reverse Reverse --")
	_fresh()
	_field([Vector2i(5, 0)])
	var rr := _c("reverse_reverse")
	var a := _c("block")
	var b := _c("slash")
	var top := _c("draw")
	var under := _c("spark")
	dm.hand.append(rr)
	dm.hand.append(a)
	dm.hand.append(b)
	dm.draw_pile.append(under)
	dm.draw_pile.append(top)
	var r := _play(rr, main.player, func(): return {"hand": dm.hand.duplicate(), "t": tm.global_tempo - _t0})
	_check(r["played"] and r["mana"] == 50, "costs 50 mana (%d)" % r["mana"])
	_check(top in r["snap"].get("hand", []), "draws 1 when it resolves")
	_check(_picker("HandCardPicker") != null, "then asks which hand card goes back")
	# The pick is owed: Cancel brings the picker back.
	_check(_hand_pick("Cancel"), "Cancel can be pressed")
	await _settle(2)
	_check(_picker("HandCardPicker") != null, "Cancel re-opens the picker")
	_check(_hand_pick(b.card_name), "pick %s" % b.card_name)
	_check(dm.draw_pile.back() == b and not dm.hand.has(b), "the chosen card sits on top of the draw pile")
	_check(dm.hand.has(a) and dm.hand.has(top) and dm.hand.size() == 2, "the rest of the hand is untouched")
	_check(dm.draw_pile.size() == 2 and dm.draw_pile[0] == under, "the pile under it keeps its order")
	var t := _finish()
	_check(t == 3, "costs 3 tempo (%d)" % t)
	_check(dm.draw_card() == b, "the next draw is that card")

	# One card in hand after the draw: it goes back with no picker.
	_fresh()
	var solo := _c("draw")
	dm.draw_pile.append(solo)
	_play(_c("reverse_reverse"), main.player)
	_finish()
	_check(_picker("HandCardPicker") == null and dm.draw_pile.back() == solo and dm.hand.is_empty(),
		"a lone drawn card goes straight back on top")

func _test_foresight() -> void:
	print("-- Foresight --")
	# The price: 20, 2 less per Brain point held, never below 0.
	_fresh()
	var fs := _c("foresight")
	dm.hand.append(fs)
	dm.hand_updated.emit()
	_check(fs.mana_cost == 20, "no Brain points: 20 mana on the card")
	stats.current_brain_points = 3
	stats.brain_points_changed.emit(3, stats.get_max_brain_points())
	_check(fs.mana_cost == 14, "3 Brain points: the card in hand shows 14 (%d)" % fs.mana_cost)
	dm.draw_pile.append(_c("block"))
	var r := _play(fs, main.player)
	_finish()
	_check(r["played"] and r["mana"] == 14, "…and 14 is what it charges (%d)" % r["mana"])
	_fresh()
	var free := _c("foresight")
	stats.current_brain_points = 15
	dm.draw_pile.append(_c("block"))
	var rf := _play(free, main.player)
	_finish()
	_check(rf["played"] and rf["mana"] == 0 and free.mana_cost == 0, "15 Brain points: free, never below 0 (%d)" % rf["mana"])
	_check(stats.current_brain_points == 15, "the Brain points are held, not spent")

	# The look: one to the hand, one to the bottom, one stays on top.
	_fresh()
	var z := _c("spark")
	var c3 := _c("draw")
	var c2 := _c("slash")
	var c1 := _c("block")
	for c in [z, c3, c2, c1]:
		dm.draw_pile.append(c)  # c1 is the top
	var f2 := _c("foresight")
	var r2 := _play(f2, main.player)
	_check(r2["played"] and r2["mana"] == 20, "costs 20 mana with no Brain points (%d)" % r2["mana"])
	_check(_full_count() == 3, "shows the top 3 cards (%d)" % _full_count())
	_check(dm.draw_pile.size() == 4, "nothing moves until a card is picked")
	_check(_full_pick(1), "pick the second card for the hand")
	_check(dm.hand.has(c2) and not dm.draw_pile.has(c2), "it goes to the hand")
	await _settle(2)
	_check(_full_count() == 2, "then the other two are offered for the bottom (%d)" % _full_count())
	_check(_full_pick(1), "pick the deeper one")
	_check(Array(dm.draw_pile) == [c3, z, c1], "it goes to the bottom; the third stays on top (%s)" % str(dm.draw_pile.map(func(c): return c.card_id)))
	await _settle(2)
	_check(_picker("FullCardPicker") == null, "and the look is over")
	_check(_finish() == 0, "costs 0 tempo")

	# Two cards: one to the hand, the other to the bottom, no second question.
	_fresh()
	var p := _c("block")
	var q := _c("slash")
	dm.draw_pile.append(q)
	dm.draw_pile.append(p)
	_play(_c("foresight"), main.player)
	_check(_full_count() == 2 and _full_pick(0), "two cards on the pile: pick one for the hand")
	_check(dm.hand.has(p) and Array(dm.draw_pile) == [q], "the other is all that is left")
	_finish()
	await _settle(2)

	# One card: it is simply taken.
	_fresh()
	var only := _c("block")
	dm.draw_pile.append(only)
	_play(_c("foresight"), main.player)
	_finish()
	_check(dm.hand.has(only) and dm.draw_pile.is_empty() and _picker("FullCardPicker") == null, "one card on the pile: it goes to the hand")

	# A full hand: the pick stays on top instead of being lost.
	_fresh()
	var t1 := _c("block")
	var t2 := _c("slash")
	dm.draw_pile.append(t2)
	dm.draw_pile.append(t1)
	var f5 := _c("foresight")
	dm.hand.append(f5)
	while dm.hand.size() < dm.get_hand_cap() + 1:
		dm.hand.append(_c("block"))  # full even once Foresight has left it
	_play(f5, main.player)
	var before: int = dm.hand.size()
	_check(_full_pick(0), "full hand: pick the top card")
	_check(dm.hand.size() == before and dm.draw_pile.has(t1) and dm.draw_pile.has(t2), "a full hand keeps the card in the draw pile")
	_finish()
	await _settle(2)
