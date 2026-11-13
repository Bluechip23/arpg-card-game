extends SceneTree

## New sheet cards, batch E (scripts/cards/new_cards_e.gd): Ward of Hallow
## Glass, The Ledger, Both Sides of the Candle, Thickened Nature, Flames of
## Alexandria, Surprise Pick Up, Inspiring Whistle, Stoked Pride. Every card
## is played through the REAL play path in a booted main.tscn (the dojo):
## DeckManager.play_card charges the mana, TempoManager ticks the tempo,
## _resolve_queued_card runs the executor and main's world effects.
## Run: godot --headless --path . --script tests/test_new_cards_e.gd

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
var _home: Vector3

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
	print("=== New cards: batch E ===")
	TempoManager.preferred_swing_hold = 0  # resolve on the tick, no swing wait
	await _boot()
	if main == null:
		print("=== %d failure(s) ===" % failures)
		quit(1)
		return
	_test_costs()
	_test_ward()
	_test_ledger()
	_test_candle()
	_test_flames()
	_test_fog()
	_test_whistle()
	_test_crate()
	await _settle(2)
	_test_pride()
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
	_home = main.player.position
	tm.card_resolved.connect(_on_resolved)  # after main's own handler

func _pc() -> Vector2i:
	return gm.world_to_grid(main.player.position)

func _stand(cell: Vector2i) -> void:
	var w: Vector3 = gm.grid_to_world(cell)
	main.player.position = Vector3(w.x, main.player.position.y, w.z)
	main.player.target_position = main.player.position

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

func _fresh() -> void:
	_drain()
	main.mouse_override = Vector2(-1, -1)
	main.player.position = _home
	main.player.target_position = _home
	main._pending_resolve_queue.clear()
	main.glut_tempo_remaining = 0
	main.draw_timer.tempo_until_draw = 1e9  # no timed draws mid-check
	for s in main._skeletons.duplicate():
		if is_instance_valid(s) and not s.is_dead:
			s.die()
	main._skeletons.clear()
	for o in main.get_node("UI").get_children():
		if o.name.begins_with("ChoicePicker") or o.name.begins_with("FullCardPicker"):
			o.name = "ClosedPicker"  # freed at the frame's end; the next prompt takes the name
			o.queue_free()
	NewCardsE.clear_fogs(main)
	for crate in NewCardsE._list(main, NewCardsE.CRATES):
		if is_instance_valid(crate["node"]):
			crate["node"].free()
	main.set_meta(NewCardsE.CRATES, [])
	NewCardsE.clear_stats(stats)
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
## the timers — so a "10 tempo" window reads 10, not 9.
func _on_resolved(_card: Card) -> void:
	if _probe.is_valid():
		_snap = _probe.call()
		_probe = Callable()

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

func _finish() -> int:
	_drain()
	main.mouse_override = Vector2(-1, -1)
	return tm.global_tempo - _t0

func _tempo(n: int) -> void:
	for _i in range(n):
		tm.add_tempo(1)

func _hit(dealt: int, expect: int, e = null) -> bool:
	return dealt == expect or dealt == Card.crit_multiply(expect, stats, e)

func _heal_of(amount: int) -> int:
	var h: int = stats.current_health
	stats.current_health = 300
	stats.heal(amount)
	var got := stats.current_health - 300
	stats.current_health = h
	return got

## What a grant of `amount` armor really adds (flat bonuses ride every grant).
func _armor_of(amount: int) -> int:
	var a: int = stats.current_armor
	stats.current_armor = 0
	stats.add_armor(amount)
	var got: int = stats.current_armor
	stats.current_armor = a
	return got

func _badge(key: String) -> Buff:
	bm.sync_flag_buffs()
	return bm._get_generic(key)

func _buttons(root: Node) -> Array:
	return root.find_children("*", "Button", true, false)

# ---------------------------------------------------------------- costs

func _test_costs() -> void:
	print("-- Mana and tempo charged by the play path --")
	for cid in NewCardsE.CARD_IDS:
		var c := Card.create_by_id(cid)
		_check(c != null, "%s exists" % cid)
		if c == null:
			continue
		_fresh()
		var e: Enemy = _field([Vector2i(1, 0)])[0]
		var tgt = e if "enemy" in c.target_types else main.player
		var aim = null if "enemy" in c.target_types else Vector2i(0, -2)
		var r := _play(c, tgt, aim)
		var t := _finish()
		_check(r["played"], "%s plays" % cid)
		_check(r["mana"] == c.mana_cost, "%s charges %d mana (charged %d)" % [cid, c.mana_cost, r["mana"]])
		_check(t == c.tempo_cost, "%s costs %d tempo (ticked %d)" % [cid, c.tempo_cost, t])
	_fresh()

# ---------------------------------------------------------------- Ward of Hallow Glass

func _test_ward() -> void:
	print("-- Ward of Hallow Glass --")
	_fresh()
	_field([Vector2i(3, 0)])
	var ward := Card.create_by_id("ward_of_hallow_glass")
	_check(ward.card_type == Card.CardType.DEFENSE and ward.school == Card.CardSchool.SPELL, "a Defense card of the Spell school")
	var expect: int = _armor_of(6 + floori(stats.intelligence / 2.0))
	var r := _play(ward, main.player, null, func(): return {
		"armor": stats.current_armor, "window": int(stats.get_meta(NewCardsE.WARD_TEMPO, 0))})
	_check(r["snap"].get("armor", -1) == expect, "armor = 6 + INT/2 (INT %d) through the armor path: %d (%d)" % [stats.intelligence, expect, r["snap"].get("armor", -1)])
	_check(r["snap"].get("window", 0) == 10, "the window runs 10 tempo (%d)" % r["snap"].get("window", 0))
	_check(ward.block == 6, "the card's printed block is back to 6 after the play (%d)" % ward.block)
	_finish()
	var left: int = int(stats.get_meta(NewCardsE.WARD_TEMPO, 0))
	_check(left == 10 - (ward.tempo_cost - ward.resolve_tick) - 1, "the clock ran with the card's remaining ticks (%d left)" % left)
	var badge := _badge("ward_of_hallow_glass")
	_check(badge != null and badge.duration == left, "a badge shows the countdown")
	var fb := Card.create_by_id("fireball")   # an offensive spell
	fb.requires_engraving = false             # the engrave gate is test_engrave's
	var spark := Card.create_by_id("spark")
	var slice := Card.create_by_id("slice")   # an attack
	var blk := Card.create_by_id("block")
	dm.hand.append_array([fb, spark, slice, blk])
	stats.current_armor = maxi(stats.current_armor, 5)
	_check(int(dm.greedy_tax(fb)["tempo"]) == -1 and int(dm.greedy_tax(spark)["tempo"]) == -1, "with armor up, offensive spells in hand show 1 less tempo")
	_check(int(dm.greedy_tax(slice)["tempo"]) == 0 and int(dm.greedy_tax(blk)["tempo"]) == 0, "an attack and a defense card are not cut")
	stats.current_armor = 0
	_check(int(dm.greedy_tax(fb)["tempo"]) == 0, "no armor: no cut")
	stats.current_armor = 5
	var fr := _play(fb, main.player, Vector2i(3, 0))
	var ft := _finish()
	_check(fr["played"] and ft == fb.tempo_cost - 1, "Fireball costs %d tempo, one less (ticked %d)" % [fb.tempo_cost - 1, ft])
	_tempo(10)
	stats.current_armor = 5
	_check(int(stats.get_meta(NewCardsE.WARD_TEMPO, 0)) == 0 and int(dm.greedy_tax(spark)["tempo"]) == 0, "after the 10 tempo the cut is gone")
	_check(_badge("ward_of_hallow_glass") == null, "…and so is the badge")

# ---------------------------------------------------------------- The Ledger

func _test_ledger() -> void:
	print("-- The Ledger --")
	_fresh()
	var e: Enemy = _field([Vector2i(1, 0)])[0]
	# Without the Ledger nothing is banked.
	_play(Card.create_by_id("slice"), e)
	_finish()
	_check(not stats.has_meta(NewCardsE.LEDGER_BANK), "no Ledger: no bank")
	_play(Card.create_by_id("the_ledger"), main.player)
	_finish()
	_check(bool(stats.get_meta(NewCardsE.LEDGER_ON, false)), "The Ledger stands")
	_check(_badge("the_ledger") != null, "its badge shows")
	e = _field([Vector2i(1, 0)])[0]
	_play(Card.create_by_id("slice"), e)
	_finish()
	var d1 := _lost(e)
	var bank: float = float(stats.get_meta(NewCardsE.LEDGER_BANK, 0.0))
	_check(d1 > 0 and is_equal_approx(bank, d1 * 0.1), "a direct hit of %d banks 10%%: %.1f" % [d1, bank])
	_play(Card.create_by_id("slice"), e)
	_finish()
	var d2 := _lost(e)
	bank = float(stats.get_meta(NewCardsE.LEDGER_BANK, 0.0))
	_check(is_equal_approx(bank, d2 * 0.1), "the bank accumulates, fractions kept: %.1f of %d dealt" % [bank, d2])
	var badge := _badge("the_ledger")
	_check(badge != null and badge.stacks == maxi(1, floori(bank)) and ("Banked: %d" % floori(bank)) in badge.description, "the badge carries the bank's number (%d)" % floori(bank))
	# A utility play neither banks nor spends.
	_play(Card.create_by_id("gain_mana"), main.player)
	_finish()
	_check(is_equal_approx(float(stats.get_meta(NewCardsE.LEDGER_BANK, 0.0)), bank), "a utility card leaves the bank alone")
	# A Defense card spends it as healing.
	var want: int = _heal_of(floori(bank))
	stats.current_health = 300
	_play(Card.create_by_id("block"), main.player)
	_finish()
	_check(stats.current_health - 300 == want and want > 0, "a Defense card heals for the whole bank: %d (%d)" % [want, stats.current_health - 300])
	_check(is_equal_approx(float(stats.get_meta(NewCardsE.LEDGER_BANK, -1.0)), 0.0), "…and empties it")
	# A Maintain: it outlasts the enemies, and ends when the maintain is dropped.
	_check(dm.maintained_cards.any(func(c): return c.card_id == "the_ledger"), "The Ledger sits in the maintained pile")
	main._on_all_enemies_defeated()
	NewCardsE.refresh_ledger(main)
	_check(bool(stats.get_meta(NewCardsE.LEDGER_ON, false)), "the enemies' defeat does not close it")
	for mc in dm.maintained_cards.duplicate():
		if mc.card_id == "the_ledger":
			dm.maintained_cards.erase(mc)
	NewCardsE.refresh_ledger(main)
	_check(not stats.has_meta(NewCardsE.LEDGER_ON) and not stats.has_meta(NewCardsE.LEDGER_BANK) and _badge("the_ledger") == null,
		"dropping the maintain closes the book and the bank is lost")

# ---------------------------------------------------------------- Both Sides of the Candle

func _test_candle() -> void:
	print("-- Both Sides of the Candle --")
	_fresh()
	var e: Enemy = _field([Vector2i(1, 0)])[0]
	e.max_health = 5000
	e.current_health = 5000
	_play(Card.create_by_id("both_sides_of_the_candle"), main.player)
	_finish()
	_check(int(stats.get_meta(NewCardsE.CANDLE, 0)) == 5, "5 charges on the target (yourself)")
	var badge := _badge("both_sides_of_the_candle")
	_check(badge != null and badge.stacks == 5, "a charge badge shows 5")
	var slice := Card.create_by_id("slice")
	var spark := Card.create_by_id("spark")
	dm.hand.append_array([slice, spark])
	_check(int(dm.greedy_tax(slice)["tempo"]) == -2, "an attack in hand shows 2 less tempo")
	_check(int(dm.greedy_tax(spark)["tempo"]) == 0, "a spell does not")
	stats.current_armor = 30
	var r := _play(slice, e)
	var t := _finish()
	_check(t == slice.tempo_cost - 2, "the attack costs %d tempo (ticked %d)" % [slice.tempo_cost - 2, t])
	_check(e.burn_stacks == 8, "the enemy hit takes 8 Burn (%d)" % e.burn_stacks)
	_check(r["health"] == 50 or 500 - stats.current_health == 50, "the attacker pays 10%% of max health: 50 (%d)" % (500 - stats.current_health))
	_check(stats.current_armor == 30, "armor does not absorb it (%d)" % stats.current_armor)
	_check(int(stats.get_meta(NewCardsE.CANDLE, 0)) == 4, "one charge spent (4 left)")
	# A spell spends nothing and pays nothing.
	stats.current_health = 500
	_play(spark, e)
	_finish()
	_check(int(stats.get_meta(NewCardsE.CANDLE, 0)) == 4 and stats.current_health == 500, "a spell neither spends a charge nor costs health")
	for i in range(4):
		stats.current_health = 500
		_play(Card.create_by_id("slice"), e)
		_finish()
	_check(int(stats.get_meta(NewCardsE.CANDLE, 0)) == 0 and stats.current_health == 450, "the 5th attack spends the last charge")
	_check(_badge("both_sides_of_the_candle") == null, "the badge is gone")
	stats.current_health = 500
	var burn_before: int = e.burn_stacks
	var last := Card.create_by_id("slice")
	_play(last, e)
	var lt := _finish()
	_check(lt == last.tempo_cost and stats.current_health == 500, "a 6th attack is an ordinary one (tempo %d, health %d)" % [lt, stats.current_health])
	_check(e.burn_stacks <= burn_before, "…with no Burn")

# ---------------------------------------------------------------- Flames of Alexandria

func _test_flames() -> void:
	print("-- Flames of Alexandria --")
	_fresh()
	var es: Array = _field([Vector2i(2, 0), Vector2i(-2, 0), Vector2i(8, 0)])
	var front: Enemy = es[0]
	var behind: Enemy = es[1]
	var far: Enemy = es[2]
	for e in es:
		e.max_health = 5000
		e.current_health = 5000
	var flames := Card.create_by_id("flames_of_alexandria")
	_check(flames.is_offensive() and not flames.is_attack() and flames.school == Card.CardSchool.SPELL, "an offensive spell")
	var held_a := Card.create_by_id("slice")
	var held_b := Card.create_by_id("block")
	dm.hand.append_array([held_a, held_b])
	for i in range(4):
		dm.draw_pile.append(Card.create_by_id("slice"))
	for i in range(5):
		dm.discard_pile.append(Card.create_by_id("block"))
	var discards := [0]
	var on_discard := func(_c): discards[0] += 1
	dm.non_play_discard.connect(on_discard)
	var cap: int = dm.get_hand_cap()
	_play(flames, main.player, Vector2i(2, 0))
	_finish()
	# (The two may be drawn straight back: they are shuffled into the draw pile.)
	_check(discards[0] == 2, "the hand held before is discarded, as true discards (on-discard effects fire): %d" % discards[0])
	var expect_draw: int = mini(mini(10, cap), 11)
	_check(dm.hand.size() == expect_draw, "then 10 are drawn, the ones past a full hand overdrawing (%d kept for hand size %d): hand %d" % [expect_draw, cap, dm.hand.size()])
	_check(dm.hand.size() + dm.draw_pile.size() == 11, "the discard pile was shuffled into the draw pile first (11 cards between pile and hand: %d)" % (dm.hand.size() + dm.draw_pile.size()))
	_check(dm.discard_pile.size() == 1 and dm.discard_pile[0] == flames, "only Flames itself rests in the discard pile")
	_check(_lost(front) == 0, "nothing burns before the choice")
	var picker = main.get_node("UI").get_node_or_null("FullCardPicker")
	_check(picker != null, "the picker opens over the drawn cards")
	if picker == null:
		dm.non_play_discard.disconnect(on_discard)
		return
	var toggles: Array = []
	var confirm: Button = null
	for b in _buttons(picker):
		if b.toggle_mode:
			toggles.append(b)
		elif b.text.begins_with("Confirm"):
			confirm = b
	_check(toggles.size() == expect_draw and confirm != null and not confirm.disabled, "any number may be chosen: Confirm is live with none picked")
	toggles[0].button_pressed = true
	toggles[1].button_pressed = true
	var hand_before: int = dm.hand.size()
	picker.name = "ClosedPicker"
	confirm.pressed.emit()
	var per: int = stats.get_effective_spell_damage(3)
	_check(dm.hand.size() == hand_before - 2 and discards[0] == 4, "the 2 chosen cards are discarded")
	_check(_lost(front) == 2 * per, "the enemy in the cone takes 3 fire (INT-scaled to %d) per card: %d (%d)" % [per, 2 * per, _lost(front)])
	_check(_lost(behind) == 0 and _lost(far) == 0, "enemies behind or past the cone take none")
	var burn: Debuff = dbm.get_debuff(Debuff.DebuffType.BURN)
	_check(burn != null and burn.value == 2, "1 Burn on yourself per card: %d" % (burn.value if burn else 0))
	dm.non_play_discard.disconnect(on_discard)

	# Choosing none: no damage, no Burn.
	_fresh()
	front = _field([Vector2i(2, 0)])[0]
	for i in range(3):
		dm.draw_pile.append(Card.create_by_id("slice"))
	_play(Card.create_by_id("flames_of_alexandria"), main.player, Vector2i(2, 0))
	_finish()
	picker = main.get_node("UI").get_node_or_null("FullCardPicker")
	if picker:
		for b in _buttons(picker):
			if not b.toggle_mode and b.text.begins_with("Confirm"):
				b.pressed.emit()
	_check(_lost(front) == 0 and dbm.get_debuff(Debuff.DebuffType.BURN) == null and dm.hand.size() == 3, "discarding none: no damage, no Burn, the 3 drawn cards kept")

# ---------------------------------------------------------------- Thickened Nature

func _test_fog() -> void:
	print("-- Thickened Nature --")
	_fresh()
	var es: Array = _field([Vector2i(0, -3), Vector2i(1, -4), Vector2i(3, 0)])
	var inside: Enemy = es[0]
	var corner: Enemy = es[1]
	var outside: Enemy = es[2]
	var fog := Card.create_by_id("thickened_nature")
	var r := _play(fog, main.player, Vector2i(0, -3), func():
		var z: Array = NewCardsE._list(main, NewCardsE.FOGS)
		return {"zones": z.size(), "cells": z[0]["cells"].size() if z.size() > 0 else 0,
			"tempo": z[0]["tempo"] if z.size() > 0 else 0, "nodes": z[0]["nodes"].size() if z.size() > 0 else 0})
	_check(r["snap"].get("zones", 0) == 1 and r["snap"].get("cells", 0) == 9, "a fog 3 squares across (9 tiles)")
	_check(r["snap"].get("tempo", 0) == 15, "lasting 15 tempo (%d)" % r["snap"].get("tempo", 0))
	_check(r["snap"].get("nodes", 0) == 9, "every tile wears the fog")
	_check(inside.slow_stacks == 1 and corner.slow_stacks == 1, "enemies inside are Slowed 1 (%d, %d)" % [inside.slow_stacks, corner.slow_stacks])
	_check(outside.slow_stacks == 0, "one outside is not")
	_finish()
	_tempo(3)
	_check(inside.slow_stacks == 1, "the Slow is held at 1, not piled up (%d)" % inside.slow_stacks)
	_tempo(4)
	_check(inside.slow_stacks == 1, "…and topped up when its stack runs out (%d)" % inside.slow_stacks)
	main._on_enemy_movement_completed(outside)
	_check(outside.rooted_tempo == 0, "a move ending outside the fog roots nothing")
	main._on_enemy_movement_completed(inside)
	_check(inside.rooted_tempo == 5, "a move ending inside it: Rooted 5 (%d)" % inside.rooted_tempo)
	_tempo(8)
	_check(NewCardsE._list(main, NewCardsE.FOGS).is_empty(), "the fog is gone after its 15 tempo")
	inside.rooted_tempo = 0
	main._on_enemy_movement_completed(inside)
	_check(inside.rooted_tempo == 0, "…and roots no more")

# ---------------------------------------------------------------- Inspiring Whistle

func _spawn_skeleton(off: Vector2i, hp: int = 50):
	main._spawn_summon(hp, main._ground_pos(_pc() + off), "skeleton")
	var s = main._skeletons.back()
	s.move_interval = 1000000  # the test holds it still: only the Whistle moves it
	return s

func _test_whistle() -> void:
	print("-- Inspiring Whistle --")
	_fresh()
	var e: Enemy = _field([Vector2i(0, -7)])[0]
	var wh := Card.create_by_id("inspiring_whistle")
	_check("enemy" in wh.target_types, "it takes an enemy")
	# No summons: draw a card.
	dm.draw_pile.append(Card.create_by_id("block"))
	_play(wh, e)
	_finish()
	_check(dm.hand.size() == 1 and dm.hand[0].card_id == "block", "with no summons it draws a card")

	_fresh()
	e = _field([Vector2i(0, -7)])[0]
	var s = _spawn_skeleton(Vector2i(0, -1))
	var start: Vector2i = s.get_destination_cell()
	_check(start == _pc() + Vector2i(0, -1), "a skeleton stands beside the caster")
	dm.draw_pile.append(Card.create_by_id("block"))
	_play(Card.create_by_id("inspiring_whistle"), e)
	_finish()
	_check(dm.hand.is_empty(), "with a summon it does not draw")
	_check(s.get_destination_cell() == start + Vector2i(0, -3), "the summon moves 3 tiles toward the chosen enemy (%s -> %s)" % [start, s.get_destination_cell()])
	_check(s.brace_percent == 30 and s.brace_hits == 2, "out of reach: Brace 30%% for 2 hits (%d%%, %d)" % [s.brace_percent, s.brace_hits])
	var h: int = s.health
	s.take_damage(10)
	_check(h - s.health == 7, "a 10 hit lands for 7 (%d)" % (h - s.health))
	h = s.health
	s.take_damage(10)
	_check(h - s.health == 7 and s.brace_hits == 0, "the second too (%d)" % (h - s.health))
	h = s.health
	s.take_damage(10)
	_check(h - s.health == 10, "the third lands whole (%d)" % (h - s.health))

	_fresh()
	e = _field([Vector2i(0, -4)])[0]
	s = _spawn_skeleton(Vector2i(0, -1))
	start = s.get_destination_cell()
	_play(Card.create_by_id("inspiring_whistle"), e)
	_finish()
	_check(s.get_destination_cell() == start + Vector2i(0, -2), "it stops beside the enemy (2 of its 3 tiles)")
	_check(s.brace_percent == 60 and s.brace_hits == 2, "within its reach: Brace doubled to 60%% (%d%%)" % s.brace_percent)
	h = s.health
	s.take_damage(10)
	_check(h - s.health == 4, "a 10 hit lands for 4 (%d)" % (h - s.health))
	var badges: Array = s.get_status_effects()
	_check(badges.size() == 1 and badges[0]["name"] == "Brace" and badges[0]["stacks"] == 1, "the Allies tab shows its Brace")

# ---------------------------------------------------------------- Surprise Pick Up

func _crates() -> Array:
	return NewCardsE._list(main, NewCardsE.CRATES)

func _press_choice(index: int) -> bool:
	var picker = main.get_node("UI").get_node_or_null("ChoicePicker")
	if picker == null:
		return false
	var btns: Array = _buttons(picker)
	if index >= btns.size():
		return false
	picker.name = "ChoicePickerDone"  # it frees at the frame's end; the next prompt takes the name
	btns[index].pressed.emit()
	return true

func _test_crate() -> void:
	print("-- Surprise Pick Up --")
	_fresh()
	_field([Vector2i(6, 0)])
	var pick := Card.create_by_id("surprise_pick_up")
	var spot: Vector2i = _pc() + Vector2i(0, -2)
	var r := _play(pick, main.player, Vector2i(0, -2), func(): return {"jail": pick.jail_time_remaining, "jailed": dm.jail_pile.has(pick)})
	_finish()
	# Jailed as it is played: its own wind-up (resolves on tick 6) has run 5 of the 40.
	_check(r["snap"].get("jailed", false) and r["snap"].get("jail", 0) == 40 - (pick.resolve_tick - 1), "Jail 40 from the play (%d left as it resolves)" % r["snap"].get("jail", 0))
	_check(_crates().size() == 1 and _crates()[0]["cell"] == spot, "a crate lands on the aimed tile")
	var node = _crates()[0]["node"]
	_check(is_instance_valid(node) and node.get_child_count() == 1 and node.get_child(0) is Sprite3D, "it wears the pack's chest sprite")
	_tempo(8)
	_check(_crates().size() == 1, "nobody on it: it waits")
	_stand(spot)
	_tempo(3)
	_stand(spot + Vector2i(0, 1))
	_tempo(1)
	_stand(spot)
	_tempo(4)
	_check(main.get_node("UI").get_node_or_null("ChoicePicker") == null and _crates().size() == 1, "stepping off restarts the count (4 tempo back on it: still shut)")
	_tempo(1)
	_check(main.get_node("UI").get_node_or_null("ChoicePicker") != null, "5 tempo standing on it: the choice is offered")
	_tempo(3)
	_check(_crates().size() == 1, "the crate waits for the choice")
	var armor_want: int = _armor_of(20)
	var mana0: float = stats.current_mana
	stats.current_armor = 0
	_check(_press_choice(0), "the first bundle is picked")
	_check(_crates().is_empty() and (not is_instance_valid(node) or node.is_queued_for_deletion()), "the crate is gone")
	_check(stats.current_temp_health == 20, "20 temp HP (%d)" % stats.current_temp_health)
	_check(int(round(stats.current_mana - mana0)) == 20, "20 mana (%d)" % int(round(stats.current_mana - mana0)))
	_check(stats.current_armor == armor_want, "20 armor (%d of %d)" % [stats.current_armor, armor_want])
	var thorns: Buff = bm.get_buff(Buff.BuffType.THORNS)
	var keen: Buff = bm.get_buff(Buff.BuffType.KEEN)
	_check(thorns != null and thorns.value == 20, "20 Thorns")
	_check(keen != null and keen.value == 20 and keen.duration == 10, "Keen 20%% for 10 tempo")

	# The other bundle.
	_fresh()
	_field([Vector2i(6, 0)])
	_play(Card.create_by_id("surprise_pick_up"), main.player, Vector2i(0, -2))
	_finish()
	for i in range(3):
		dm.draw_pile.append(Card.create_by_id("block"))
	stats.current_brain_points = 0
	stats.current_flash_points = 0
	_stand(spot)
	_tempo(5)
	_check(_press_choice(1), "the second bundle is picked")
	_check(dm.hand.size() == 3, "draw 3 (%d)" % dm.hand.size())
	var blessed: Buff = bm.get_buff(Buff.BuffType.BLESSED)
	_check(blessed != null and blessed.value == 2 and blessed.charges == 3, "Blessed 2 for 3 cycles")
	_check(stats.current_brain_points == stats.get_max_brain_points() and stats.current_flash_points == stats.get_max_flash_points(),
		"every Brain and Flash point is back (%d/%d, %d/%d)" % [stats.current_brain_points, stats.get_max_brain_points(), stats.current_flash_points, stats.get_max_flash_points()])
	_check(_crates().is_empty(), "the crate is spent")

# ---------------------------------------------------------------- Stoked Pride

func _lions() -> Array:
	return main._skeletons.filter(func(s): return is_instance_valid(s) and not s.is_dead and s.kind == "pride_lion")

func _test_pride() -> void:
	print("-- Stoked Pride --")
	_fresh()
	var e: Enemy = _field([Vector2i(1, 0)])[0]
	_play(Card.create_by_id("stoked_pride"), main.player)
	_finish()
	_check(stats.has_meta(NewCardsE.PRIDE_MARK), "the ally (yourself) is marked")
	_check(_badge("stoked_pride") != null, "a badge shows the mark")
	_check(_lions().is_empty(), "no lion until they are attacked")
	e._deal_damage_to_player(main.player, 12, "Test Bite")
	_check(stats.current_health == 500, "the marked ally takes no damage (%d)" % stats.current_health)
	_check(_lions().size() == 1, "a lion is summoned")
	if _lions().is_empty():
		return
	var lion = _lions()[0]
	_check(lion.display_name == "Lion" and lion.max_health == 30 and lion.base_attack == 0, "30 health, no attack")
	_check(NewCardsE._chebyshev(lion.get_destination_cell(), _pc()) == 1, "on a free tile beside them")
	_check(lion.health == 18, "the attack's 12 lands on the lion (%d/30)" % lion.health)
	_check(not stats.has_meta(NewCardsE.PRIDE_MARK), "the mark is spent")
	_check(lion in main._all_summons() and lion.summoner == main.player, "it is a summon of the caster")
	e._deal_damage_to_player(main.player, 12, "Test Bite")
	_check(stats.current_health == 500 and lion.health == 6 and _lions().size() == 1, "it keeps taking attacks aimed at them (%d/30), no second lion" % lion.health)
	# More than 2 squares away it cannot.
	var here: Vector2i = _pc()
	_stand(here + Vector2i(0, -4))
	var far: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.DUMMY, main._ground_pos(_pc() + Vector2i(1, 0)))
	far._deal_damage_to_player(main.player, 12, "Test Bite")
	_check(stats.current_health < 500 and lion.health == 6, "beyond 2 squares the blow lands on the ally (%d)" % stats.current_health)
	_tempo(4)
	_check(NewCardsE._chebyshev(lion.get_destination_cell(), _pc()) <= 1, "the lion follows its ward")
	stats.current_health = 500
	far._deal_damage_to_player(main.player, 12, "Test Bite")
	_check(stats.current_health == 500 and (lion.is_dead or not is_instance_valid(lion) or lion.health <= 0), "back in reach it takes the next blow, and falls")
	far._deal_damage_to_player(main.player, 12, "Test Bite")
	_check(stats.current_health < 500, "with the lion dead the ally is hit again (%d)" % stats.current_health)
	_check(_badge("stoked_pride") == null, "and the badge is gone")
