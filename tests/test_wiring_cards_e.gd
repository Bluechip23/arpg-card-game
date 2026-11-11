extends SceneTree

## Phase 2 wiring audit, card slice E (docs/audit/wiring/cards_e.md):
## Sky Attack … Wrath of the Sea. Every card is played through the REAL play
## path in a booted main.tscn (the dojo): DeckManager.play_card charges the
## mana, TempoManager ticks the card's tempo, _resolve_queued_card runs the
## executor and main's world effects. Each check asserts what the card's
## description says.
## Run: godot --headless --path . --script tests/test_wiring_cards_e.gd

var failures := 0
var main = null
var stats: PlayerStats
var dm: DeckManager
var tm: TempoManager
var gm
var bm: BuffManager
var dbm: DebuffManager
var _t0 := 0

const SLICE := ["sky_attack", "sky_fall", "slash", "slice", "smith_thy_soul", "smoke_bomb",
	"snowballs_chance", "song_of_a_swords_sing", "spark", "specific_strike", "spider_senses",
	"spirit_arrow", "spirit_bow", "splinter", "sprinkle", "sprinkle_bomb", "stance_switch",
	"stone_encase", "succumb", "summon_battle_turtle", "summon_shadow_hound", "summon_skeleton",
	"surrounding_ice", "swap", "sweeping_disarm", "switch_kick", "taunt", "terrain_formation",
	"territorial_mark", "the_lights_favor", "the_nibelung_curse", "thrown_stone", "tight_rope",
	"tighten_string", "tower_shield", "trick_shot", "tricks_of_alberich", "trip", "try_this",
	"turtle_power", "turtle_up", "twenty_twenty", "understanding", "vengeful_shield",
	"vined_encasing", "vines", "volatile_mixture", "wear_down", "worms_armageddon",
	"worst_that_could_happen", "wrath_of_the_sea"]

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
	print("=== Wiring audit: cards E ===")
	TempoManager.preferred_swing_hold = 0  # resolve on the tick, no swing wait
	await _boot()
	if main == null:
		print("=== %d failure(s) ===" % failures)
		quit(1)
		return
	_test_costs()
	_test_sky()
	_test_s_attacks()
	_test_smith_smoke_snow()
	_test_song_spark_specific()
	_test_spider_spirit()
	_test_splinter_sprinkle_stance()
	_test_stone_succumb()
	_test_summons()
	_test_ice_swap_disarm()
	_test_taunt_terrain_mark()
	_test_lights_curse_stone()
	_test_tight()
	_test_tower_trick_tricks_trip()
	_test_try_turtle_twenty()
	_test_understanding_vengeful_vined()
	_test_vines_volatile_wear()
	_test_worms_worst_wrath()
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

# ---------------------------------------------------------------- costs

## Every hand-playable card in the slice charges its card's mana and tempo.
func _test_costs() -> void:
	print("-- Mana and tempo charged by the play path --")
	for cid in SLICE:
		var c := Card.create_by_id(cid)
		_check(c != null, "%s exists" % cid)
		if c == null or c.card_type == Card.CardType.REACTION:
			continue
		_fresh()
		var e: Enemy = _field([Vector2i(1, 0)])[0]
		var tgt = e
		var aim = null
		if not ("enemy" in c.target_types):
			tgt = main.player
			aim = Vector2i(0, -2)  # into the room (south of the start is the door)
		if c.requires_engraving:
			# The engrave gate itself is test_engrave's; here only the price.
			c.requires_engraving = false
		var expect_mana: int = c.mana_cost
		if cid == "summon_skeleton":
			expect_mana = maxi(0, DeckManager.SUMMON_SKELETON_BASE_MANA - stats.intelligence)
		elif cid == "wrath_of_the_sea":
			expect_mana = floori(stats.current_mana * c.percent_mana_cost)
		dm.draw_pile.append(Card.create_by_id("block"))  # a draw takes this, not the played card
		var r := _play(c, tgt, aim)
		var t := _finish()
		_check(r["played"], "%s plays" % cid)
		_check(r["mana"] == expect_mana, "%s charges %d mana (charged %d)" % [cid, expect_mana, r["mana"]])
		_check(t == c.tempo_cost, "%s costs %d tempo (ticked %d)" % [cid, c.tempo_cost, t])
	_tempo(30)  # let every delayed effect of the loop (Succumb, Try This, Spark…) run out
	# Territorial Mark also costs 35 health.
	_fresh()
	var tme: Enemy = _field([Vector2i(3, 0)])[0]
	var tmr := _play(Card.create_by_id("territorial_mark"), tme)
	_finish()
	_check(tmr["health"] == 35, "territorial_mark costs 35 health (%d)" % tmr["health"])

# ---------------------------------------------------------------- Sky

func _test_sky() -> void:
	print("-- Sky Attack --")
	_fresh()
	var e: Enemy = _field([Vector2i(3, 0)])[0]
	var fodder := Card.create_by_id("slice")
	dm.hand.append(fodder)
	var sa := Card.create_by_id("sky_attack")
	sa.picked_card = fodder
	_play(sa, e)
	_check(not dm.hand.has(fodder) and dm.discard_pile.has(fodder), "Sky Attack discards the chosen card")
	_check(_hit(_lost(e), _phys(15 + 4), e), "…and shoots for its damage plus High Ground's +4 (%d)" % _lost(e))
	_finish()
	_check(sa.bonus_damage == 0, "the High Ground bonus is undone after the shot")

	print("-- Sky Fall: lands 10 tempo after it is shot --")
	for phase in [0, 3]:
		_fresh()
		_tempo(phase)
		var se: Enemy = _field([Vector2i(3, 0)])[0]
		var sf := Card.create_by_id("sky_fall")
		_play(sf, main.player, Vector2i(3, 0))
		var resolved_at: int = tm.global_tempo
		_check(_lost(se) == 0, "phase %d: nothing lands on the shot" % phase)
		var landed_at := -1
		for _i in range(15):
			if tm._pending_ticks > 0:
				tm._process_one_tick()
			else:
				tm.add_tempo(1)
			if _lost(se) > 0 and landed_at < 0:
				landed_at = tm.global_tempo
		_check(landed_at - resolved_at == 9, "phase %d: it lands on the 10th tempo counting the shot's own (%d after)" % [phase, landed_at - resolved_at])
		_check(_lost(se) == _phys(18), "phase %d: for 18 damage (%d)" % [phase, _lost(se)])

# ---------------------------------------------------------------- Slash / Slice

func _test_s_attacks() -> void:
	print("-- Slash / Slice --")
	_fresh()
	var e: Enemy = _field([Vector2i(1, 0)])[0]
	_play(Card.create_by_id("slash"), e)
	_check(_hit(_lost(e), _phys(10), e), "Slash deals 10 (%d)" % _lost(e))
	_finish()
	_fresh()
	e = _field([Vector2i(1, 0)])[0]
	_play(Card.create_by_id("slice"), e)
	_check(_hit(_lost(e), _phys(15), e), "Slice deals 15 (%d)" % _lost(e))
	_finish()

# ---------------------------------------------------------------- Smith / smoke / snowballs

func _test_smith_smoke_snow() -> void:
	print("-- Smith thy Soul --")
	_fresh()
	stats.current_health = 300
	stats.current_mana = 500
	var sts := Card.create_by_id("smith_thy_soul")
	var sr := _play(sts, main.player, null, func(): return {"armor": stats.current_armor})
	var expect := (300 + (500 - sts.mana_cost)) / 2 / 10
	_check(sr["snap"].get("armor", -1) == expect, "armor = ((health + mana) / 2) / 10 = %d (%d)" % [expect, sr["snap"].get("armor", -1)])
	_finish()

	print("-- smoke bomb --")
	_fresh()
	_field([Vector2i(6, 0)])
	var sb := Card.create_by_id("smoke_bomb")
	var sbr := _play(sb, main.player, Vector2i(0, 0), func(): return {"jail": sb.jail_time_remaining, "jailed": dm.jail_pile.has(sb)})
	_check(sbr["snap"].get("jailed", false) and sbr["snap"].get("jail", 0) == 20, "jailed for 20 tempo after play (%d)" % sbr["snap"].get("jail", 0))
	tm.add_tempo(1)
	_check(bm.has_buff(Buff.BuffType.INVISIBLE), "standing in the smoke: invisible")
	_check(is_equal_approx(stats.aura_crit_bonus, 10.0), "…and +10% crit")
	main.player.position = gm.grid_to_world(_pc() + Vector2i(3, 0))
	tm.add_tempo(1)
	_check(is_equal_approx(stats.aura_crit_bonus, 0.0), "stepping 3 squares out drops the crit (2-square radius)")
	main.player.position = gm.grid_to_world(_pc() - Vector2i(3, 0))
	_tempo(10)
	_check(main._smoke_zones.is_empty() and is_equal_approx(stats.aura_crit_bonus, 0.0), "the cloud is gone after 8 tempo")
	_finish()

	print("-- A Snowball's Chance --")
	_fresh()
	var se: Enemy = _field([Vector2i(2, 0)])[0]
	var sbc := Card.create_by_id("snowballs_chance")
	sbc.rng_selected_index = -2  # the 50% misses
	_play(sbc, main.player, Vector2i(3, 0))
	_check(_lost(se) == _spell(10), "fire 3 spaces forward deals 10 (%d), no snowballs on a miss" % _lost(se))
	_finish()
	_fresh()
	se = _field([Vector2i(2, 0)])[0]
	var far: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.DUMMY, main._ground_pos(_pc() + Vector2i(4, 0)))
	sbc = Card.create_by_id("snowballs_chance")
	sbc.rng_selected_index = -2
	_play(sbc, main.player, Vector2i(3, 0))
	_check(_lost(far) == 0, "the fire stops at 3 spaces")
	_finish()
	_fresh()
	se = _field([Vector2i(2, 0)])[0]
	sbc = Card.create_by_id("snowballs_chance")
	sbc.rng_selected_index = 0  # the 50% lands
	_play(sbc, main.player, Vector2i(3, 0))
	var extra: int = _lost(se) - _spell(10)
	_check(extra > 0 and extra % _spell(4) == 0, "on the 50%%, snowballs (4 each) also strike (%d extra)" % extra)
	_finish()

# ---------------------------------------------------------------- Song / Spark / Specific Strike

func _test_song_spark_specific() -> void:
	print("-- Song of a Swords Sing --")
	_fresh()
	var e: Enemy = _field([Vector2i(1, 0)])[0]
	e.apply_debuff("burn", 3)
	e.apply_debuff("weaken", 1)
	var sg := _play(Card.create_by_id("song_of_a_swords_sing"), e, null, func(): return {"dis": e.disarmed_tempo, "armor": stats.current_armor})
	_check(sg["snap"].get("dis") == 5, "disarms for 5 tempo (%s)" % str(sg["snap"].get("dis")))
	_check(sg["snap"].get("armor") == 4, "3 Burn + 1 Weaken = 2 kinds = 4 armor (%s)" % str(sg["snap"].get("armor")))
	_finish()

	print("-- Spark --")
	_fresh()
	e = _field([Vector2i(2, 0)])[0]
	var a := Card.create_by_id("slash")
	var b := Card.create_by_id("slice")
	dm.hand.append(a)
	dm.hand.append(b)
	_play(Card.create_by_id("spark"), e)
	_check(_hit(_lost(e), _spell(3), e), "Spark deals 3 (%d)" % _lost(e))
	_check(a.temp_hand_tempo_reduction == 2 and b.temp_hand_tempo_reduction == 2, "-2 tempo on two cards in hand")
	_finish()
	_tempo(15)
	_check(a.temp_hand_tempo_reduction == 0 and b.temp_hand_tempo_reduction == 0, "15 tempo later, +2 tempo back on two cards")

	print("-- Specific Strike --")
	_fresh()
	e = _field([Vector2i(1, 0)])[0]
	dm.hand.append(Card.create_by_id("slash"))
	dm.hand.append(Card.create_by_id("slash"))
	var ss := Card.create_by_id("specific_strike")
	var r := _play(ss, e)
	_check(_hit(_lost(e), _phys(13), e), "deals 13 (%d)" % _lost(e))
	_check(r["mana"] == ss.mana_cost + 20, "+1m (10) per other card in hand: %d" % r["mana"])
	_check(_finish() == ss.tempo_cost + 2, "+1 tempo per other card in hand")

# ---------------------------------------------------------------- Spider / Spirit

func _test_spider_spirit() -> void:
	print("-- Spider Senses --")
	_fresh()
	var spider := Card.create_by_id("spider_senses")
	dm.hand.append(spider)
	stats.take_damage(3, dbm, bm)
	_check(stats.current_armor == 5 and not dm.hand.has(spider), "taking damage fires it: +5 armor")

	print("-- Spirit Arrow --")
	_fresh()
	var foes := _field([Vector2i(2, 0), Vector2i(7, 0), Vector2i(2, 2)])
	var sa := Card.create_by_id("spirit_arrow")
	_play(sa, main.player, Vector2i(1, 0))
	_check(_lost(foes[0]) > 0 and _lost(foes[0]) == _lost(foes[1]) and _hit(_lost(foes[0]), _phys(8), foes[0]),
		"pierces every enemy on the line for 8 (%d, %d)" % [_lost(foes[0]), _lost(foes[1])])
	_check(_lost(foes[2]) == 0, "an enemy off the line is untouched")
	_finish()

	print("-- Spirit Bow --")
	_fresh()
	var be: Enemy = _field([Vector2i(5, 0)])[0]
	var bow := Card.create_by_id("spirit_bow")
	_play(bow, main.player)
	_finish()
	_check(dm.maintained_cards.has(bow) and stats.maintained_mana == bow.maintain_cost, "maintained: 65 mana held")
	var bows: Array = main._spirit_bows.filter(func(x): return not x.is_bud)
	_check(bows.size() == 1, "a spirit bow is summoned")
	if bows.size() == 1:
		var sb = bows[0]
		_check(sb.SPIRIT_MOVE_INTERVAL == 1 and sb.base_attack() == 10 and sb.attack_interval() == 4,
			"it steps 1 square per tempo and shoots 10 every 4 tempo")
		var hp0: int = be.current_health
		sb.attack_accum = 0
		_tempo(3)
		_check(be.current_health == hp0, "no shot before 4 tempo")
		_tempo(1)
		var shot: int = hp0 - be.current_health
		_check(shot == 10 or shot == 15, "a 10-damage shot on the 4th tempo (%d)" % shot)
		dm.maintained_cards.erase(bow)
		stats.maintained_mana = 0
		_tempo(1)
		_check(main._spirit_bows.filter(func(x): return is_instance_valid(x) and not x.is_dead and not x.is_bud).is_empty(),
			"it dissolves once the mana is no longer reserved")

# ---------------------------------------------------------------- Splinter / Sprinkle / Stance

func _test_splinter_sprinkle_stance() -> void:
	print("-- Splinter --")
	_fresh()
	var e: Enemy = _field([Vector2i(3, 0)])[0]
	var sp := Card.create_by_id("splinter")
	_play(sp, e)
	_check(e.bleed_stacks == 1 and _lost(e) == 0, "applies 1 Bleed, no damage")
	_check(sp.get_effective_range() == 3, "range 3")
	_finish()

	print("-- Sprinkle / Sprinkle Bomb --")
	_fresh()
	e = _field([Vector2i(1, 0)])[0]
	var spr := Card.create_by_id("sprinkle")
	_play(spr, e)
	_check(_hit(_lost(e), _phys(25), e), "Sprinkle deals 25 (%d)" % _lost(e))
	_finish()
	_check(not dm.discard_pile.has(spr) and not dm.hand.has(spr), "Sprinkle is erased after play")
	_fresh()
	var bombed := _field([Vector2i(3, 0), Vector2i(5, 0), Vector2i(3, 3)])
	var sbomb := Card.create_by_id("sprinkle_bomb")
	_play(sbomb, main.player, Vector2i(3, 0))
	_check(_lost(bombed[0]) > 0 and _lost(bombed[0]) == _lost(bombed[1]) and _hit(_lost(bombed[0]), _spell(25), bombed[0]),
		"Sprinkle Bomb hits every enemy within 2 tiles for 25 (%d, %d)" % [_lost(bombed[0]), _lost(bombed[1])])
	_check(_lost(bombed[2]) == 0, "…not one 3 tiles out")
	_finish()
	_check(not dm.discard_pile.has(sbomb), "Sprinkle Bomb is erased after play")

	print("-- Stance Switch --")
	_fresh()
	e = _field([Vector2i(1, 0)])[0]
	e.current_armor = 15
	_play(Card.create_by_id("stance_switch"), e)
	_check(e.current_armor == 5 and e.vulnerable_stacks == 2, "removes 10 armor and applies 2 Vulnerable")
	_finish()
	_fresh()
	e = _field([Vector2i(1, 0)])[0]
	_play(Card.create_by_id("stance_switch"), e)
	_check(e.current_armor == 0 and e.vulnerable_stacks == 2, "no armor: just 2 Vulnerable")
	_finish()

# ---------------------------------------------------------------- Stone Encase / Succumb

func _test_stone_succumb() -> void:
	print("-- Stone Encase --")
	_fresh()
	_field([Vector2i(5, 0)])
	bm.apply_buff(Buff.create_fortify(50, "test"))  # hold the armor still across the cycle
	var se := _play(Card.create_by_id("stone_encase"), main.player, null, func():
		var d = dbm.get_debuff(Debuff.DebuffType.STUN)
		return {"armor": stats.current_armor, "stun": d.duration if d else 0, "locked": not dbm.can_play_cards()})
	_check(se["snap"].get("armor") == 50, "+50 armor (%s)" % str(se["snap"].get("armor")))
	_check(se["snap"].get("stun") == 5 and se["snap"].get("locked"), "stunned for 5 tempo (%s)" % str(se["snap"].get("stun")))
	_finish()

	print("-- Succumb --")
	_fresh()
	_field([Vector2i(5, 0)])
	var su := Card.create_by_id("succumb")
	su.requires_engraving = false  # the engrave gate is test_engrave's
	_play(su, main.player)
	_finish()
	_check(bm.has_buff(Buff.BuffType.FORTIFY) and bm.get_buff(Buff.BuffType.FORTIFY).duration == 20, "Fortify for 20 tempo")
	var bl = bm.get_buff(Buff.BuffType.BLESSED)
	_check(bl != null and bl.value == 2 and bl.charges * 5 == 20, "Blessed 2 for 20 tempo (4 cycles)")
	var st = bm.get_buff(Buff.BuffType.STRENGTHEN)
	_check(st != null and st.value == 5 and st.duration == 20, "Strengthen 5 for 20 tempo")
	var rs = bm.get_buff(Buff.BuffType.RESILIENT)
	_check(rs != null and rs.value == 20 and rs.duration == 20, "Resilient 20% for 20 tempo")
	var hp0 := stats.current_health
	_tempo(9)
	_check(stats.current_health == hp0, "nothing at 9 tempo")
	_tempo(1)
	_check(stats.current_health < hp0, "after 10 tempo: takes the 10 damage (%d)" % (hp0 - stats.current_health))
	var hp1 := stats.current_health
	_tempo(10)
	_check(stats.current_health < hp1, "after 10 more: takes 10 more")
	for t in [Debuff.DebuffType.CUFFED, Debuff.DebuffType.DRAIN, Debuff.DebuffType.DISARM]:
		var d = dbm.get_debuff(t)
		_check(d != null and d.duration == 10, "…and %s for 10 tempo" % Debuff.DebuffType.keys()[t])

# ---------------------------------------------------------------- Summons

func _summons(kind: String) -> Array:
	return main._skeletons.filter(func(s): return is_instance_valid(s) and not s.is_dead and s.kind == kind)

func _test_summons() -> void:
	print("-- Summon cards (stat blocks: test_summon_cards) --")
	for row in [["summon_skeleton", "card_skeleton", 1], ["summon_shadow_hound", "shadow_hound", 1],
			["summon_battle_turtle", "battle_turtle", 1], ["turtle_power", "battle_turtle", 3]]:
		_fresh()
		_field([Vector2i(8, 0)])
		for s in main._skeletons.duplicate():
			s.die()
		main._skeletons.clear()
		_play(Card.create_by_id(row[0]), main.player, Vector2i(0, -2))
		_finish()
		var got := _summons(row[1])
		_check(got.size() == row[2], "%s raises %d %s (%d)" % [row[0], row[2], row[1], got.size()])
		if got.size() > 0:
			var hp: int = 25 if row[1] == "battle_turtle" else 10
			_check(got[0].max_health == hp, "%s: %d HP" % [row[0], hp])
		for s in main._skeletons.duplicate():
			s.die()
		main._skeletons.clear()

# ---------------------------------------------------------------- Ice / Swap / Disarm

func _test_ice_swap_disarm() -> void:
	print("-- Surrounding Ice --")
	_fresh()
	var foes := _field([Vector2i(1, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(3, 0)])
	var ice := Card.create_by_id("surrounding_ice")
	ice.rng_selected_index = 0
	ice.rng_outcomes[foes[0].get_instance_id()] = true
	ice.rng_outcomes[foes[1].get_instance_id()] = true
	ice.rng_outcomes[foes[2].get_instance_id()] = false  # the 30% miss
	ice.rng_outcomes[foes[3].get_instance_id()] = true
	_play(ice, main.player)
	_check(_lost(foes[0]) == _spell(15) and _lost(foes[1]) == _spell(15), "hits within two squares for its damage (%d)" % _lost(foes[0]))
	_check(_lost(foes[2]) == 0, "a missed roll spares that enemy")
	_check(_lost(foes[3]) == 0, "three squares out is untouched")
	_check(is_equal_approx(ice.chance_effect_percent, 70.0), "30% miss chance per enemy (70% to hit)")
	_finish()

	print("-- Swap --")
	_fresh()
	var se: Enemy = _field([Vector2i(3, 0)])[0]
	var p0: Vector2i = _pc()
	var e0: Vector2i = gm.world_to_grid(se.position)
	_play(Card.create_by_id("swap"), se)
	_check(_pc() == e0 and gm.world_to_grid(se.position) == p0, "switches positions with the enemy")
	_finish()
	main.player.position = gm.grid_to_world(p0)
	main.player.target_position = main.player.position

	print("-- Sweeping Disarm --")
	_fresh()
	foes = _field([Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 0)])
	var swd := _play(Card.create_by_id("sweeping_disarm"), main.player, null, func(): return {"a": foes[0].disarmed_tempo, "b": foes[1].disarmed_tempo})
	_check(swd["snap"].get("a") == 5 and swd["snap"].get("b") == 5, "surrounding enemies (diagonal too) disarmed for 5 tempo")
	_check(_hit(_lost(foes[0]), _phys(3), foes[0]) and _lost(foes[0]) == _lost(foes[1]), "…and take 3 (%d)" % _lost(foes[0]))
	_check(foes[2].disarmed_tempo == 0 and _lost(foes[2]) == 0, "two squares away is untouched")
	_finish()

	print("-- Switch Kick --")
	_fresh()
	var ke: Enemy = _field([Vector2i(1, 0)])[0]
	var skr := _play(Card.create_by_id("switch_kick"), ke, null, func(): return {"dis": ke.disarmed_tempo})
	_check(_hit(_lost(ke), _phys(2), ke) and skr["snap"].get("dis") == 5, "2 damage and Disarm for 5 tempo (%d dmg, %s tempo)" % [_lost(ke), str(skr["snap"].get("dis"))])
	_finish()

# ---------------------------------------------------------------- Taunt / Terrain / Territorial Mark

func _test_taunt_terrain_mark() -> void:
	print("-- Taunt --")
	_fresh()
	var foes := _field([Vector2i(3, 0), Vector2i(0, 4)])
	var tr := _play(Card.create_by_id("taunt"), main.player, null, func(): return {"t": foes[0].taunt_tempo})
	_check(foes[0].taunt_target == main.player and tr["snap"].get("t") == 10, "an enemy 3 squares away is taunted for 10 tempo")
	_check(foes[1].taunt_target == null, "one 4 squares away (outside the 6-square diameter) is not")
	_finish()

	print("-- Terrain formation --")
	_fresh()
	_field([Vector2i(6, 0)])
	var cell: Vector2i = _pc() + Vector2i(0, -2)
	var dmgr = main.dungeon_manager
	var before: int = dmgr.get_elevation(cell)
	_play(Card.create_by_id("terrain_formation"), main.player, Vector2i(0, -2))
	_check(dmgr.get_elevation(cell) > before, "a hill rises where aimed")
	_finish()  # 3 tempo (the resolving tick counts as the first)
	_tempo(1)
	_check(dmgr.get_elevation(cell) > before, "still up at 4 tempo")
	_tempo(1)
	_check(dmgr.get_elevation(cell) == before, "gone after 5 tempo")

	print("-- Territorial Mark --")
	_fresh()
	foes = _field([Vector2i(6, 0), Vector2i(3, 2), Vector2i(3, 4)])
	var tmk := Card.create_by_id("territorial_mark")
	_check(tmk.get_effective_range() == 10, "range 10")
	_play(tmk, foes[0])
	_check(_hit(_lost(foes[0]), _phys(15), foes[0]), "deals 15 (%d)" % _lost(foes[0]))
	_finish()
	_check(foes[1].zone_weakened, "an enemy 2 squares beside the arrow's path is Weakened")
	_check(not foes[2].zone_weakened, "one 4 squares off it is not")
	foes[1].position = gm.grid_to_world(_pc() + Vector2i(3, 5))
	tm.add_tempo(1)
	_check(not foes[1].zone_weakened, "leaving the smoke ends the Weaken")
	_tempo(25)
	_check(main._mark_zones.is_empty(), "the smoke lasts 25 tempo")

# ---------------------------------------------------------------- Light's Favor / Nibelung / Thrown Stone

func _test_lights_curse_stone() -> void:
	print("-- The Light's Favor --")
	_fresh()
	_field([Vector2i(5, 0)])
	var heal5 := _heal_of(5)
	stats.current_health = 400
	dm.draw_pile.append(Card.create_by_id("slash"))
	_play(Card.create_by_id("the_lights_favor"), main.player)
	_check(stats.current_health == 400 + heal5 and dm.hand.size() == 1, "heals 5 (%d after healing bonuses) and draws a card" % heal5)
	_finish()

	print("-- The Nibelung Curse --")
	_fresh()
	var e: Enemy = _field([Vector2i(2, 0)])[0]
	var nc := Card.create_by_id("the_nibelung_curse")
	nc.set_meta("curse_value", 37)
	_play(nc, e)
	_check(_lost(e) == 37, "aimed at an enemy: deals the stored healing as damage")
	_finish()
	_check(not dm.discard_pile.has(nc), "erased after use")
	_fresh()
	_field([Vector2i(5, 0)])
	var heal37 := _heal_of(37)
	stats.current_health = 400
	nc = Card.create_by_id("the_nibelung_curse")
	nc.set_meta("curse_value", 37)
	_play(nc, main.player)
	_check(stats.current_health == 400 + heal37, "aimed at yourself: takes the stored healing (%d)" % (stats.current_health - 400))
	_finish()

	print("-- Thrown Stone --")
	_fresh()
	e = _field([Vector2i(4, 0)])[0]
	dm.draw_pile.append(Card.create_by_id("thrown_stone"))
	dm.draw_card()
	_check(_lost(e) == 4, "On Draw: 4 damage to a random enemy")
	var stone: Card = dm.hand[0] if dm.hand.size() > 0 else Card.create_by_id("thrown_stone")
	var hp0: int = e.current_health
	_play(stone, e)
	_check(_hit(hp0 - e.current_health, _phys(4), e), "played: 4 damage to an enemy (%d)" % (hp0 - e.current_health))
	_finish()

# ---------------------------------------------------------------- Tight Rope / Tighten String

func _test_tight() -> void:
	print("-- Tight Rope --")
	_fresh()
	_field([Vector2i(5, 0)])
	var tr := Card.create_by_id("tight_rope")
	dm.hand.append(tr)
	stats.current_health = 150  # 30%
	stats.take_damage(10, dbm, bm)
	_check(dm.hand.has(tr), "a hit that stays above 20% does not fire it")
	stats.take_damage(60, dbm, bm)
	_check(not dm.hand.has(tr), "a hit that puts you below 20% fires it")
	_check(stats.current_temp_health == 20 and stats.temp_health_tempo_remaining == 5, "+20 temp health for 5 tempo")
	var st = bm.get_buff(Buff.BuffType.STRENGTHEN)
	_check(st != null and st.value == 15 and st.charges == 1, "+15 damage on the next attack")

	print("-- Tighten String --")
	_fresh()
	var e: Enemy = _field([Vector2i(4, 0)])[0]
	_play(Card.create_by_id("tighten_string"), main.player)
	_finish()
	_check(bm.tighten_string_charges == 3, "3 charges")
	for i in range(4):
		var hp0: int = e.current_health
		var ts := Card.create_by_id("thrown_stone")
		var reach0: int = ts.get_effective_range()
		var en_before: bool = bm.has_buff(Buff.BuffType.KEEN)
		_play(ts, e)
		var dealt: int = hp0 - e.current_health
		var t := _finish()
		if i < 3:
			_check(t == ts.tempo_cost + 3 and _hit(dealt, _phys(4 + 6), e), "ranged attack %d: +3 tempo, +6 damage (%d tempo, %d dmg)" % [i + 1, t, dealt])
		else:
			_check(t == ts.tempo_cost and _hit(dealt, _phys(4), e), "the 4th ranged attack is plain (%d tempo, %d dmg)" % [t, dealt])
		_check(ts.get_effective_range() == reach0, "the +6 range is undone after the shot")
	# +6 range and +20% crit while a charge is held (play-time mods).
	_fresh()
	bm.tighten_string_charges = 1
	var ts2 := Card.create_by_id("thrown_stone")
	var reach := ts2.get_effective_range()
	dm.hand.append(ts2)
	main.selected_card_index = 0
	_t0 = tm.global_tempo
	main.play_selected_card(e)
	_check(ts2.get_effective_range() == reach + 6, "+6 range on the charged shot")
	var en = bm.get_buff(Buff.BuffType.KEEN)
	_check(en != null and en.value == 20, "+20% crit on the charged shot")
	_finish()
	# "Next 3 ranged attacks PLAYED": four shots queued back to back (none
	# resolved yet) — only the first three are strung.
	_fresh()
	bm.tighten_string_charges = 3
	var queued: Array = []
	for _i in range(4):
		var q := Card.create_by_id("thrown_stone")
		dm.hand.append(q)
		main.selected_card_index = dm.hand.find(q)
		main.play_selected_card(e)
		queued.append(q)
	var strung := 0
	for entry in main._pending_resolve_queue:
		if entry["card"] in queued and entry["data"].get("tighten_applied", false):
			strung += 1
	_check(strung == 3, "queued before any resolves, only 3 of 4 ranged attacks are strung (%d)" % strung)
	_drain()
	_check(bm.tighten_string_charges == 0, "and the charges are spent (%d)" % bm.tighten_string_charges)
	_check(queued.all(func(q): return q.bonus_damage == 0 and q.range_modifier == 0), "every shot's +6 damage / +6 range is undone")

# ---------------------------------------------------------------- Tower / Trick / Tricks / Trip

func _test_tower_trick_tricks_trip() -> void:
	print("-- Tower Shield --")
	_fresh()
	_field([Vector2i(5, 0)])
	bm.apply_buff(Buff.create_fortify(50, "test"))
	var tw := _play(Card.create_by_id("tower_shield"), main.player, null, func():
		var d = dbm.get_debuff(Debuff.DebuffType.STAGGERED)
		return {"armor": stats.current_armor, "stag": d.duration if d and d.clock_timed else 0})
	_check(tw["snap"].get("armor") == 40, "+40 armor")
	_check(tw["snap"].get("stag") == 40, "staggered for 40 tempo (%s)" % str(tw["snap"].get("stag")))
	_finish()

	print("-- Trick Shot --")
	_fresh()
	var foes := _field([Vector2i(3, 0), Vector2i(3, 2)])
	var ts := Card.create_by_id("trick_shot")
	ts.rng_selected_index = -2  # the 80% fails
	_play(ts, foes[0])
	_check(_hit(_lost(foes[0]), _phys(8), foes[0]) and _lost(foes[1]) == 0, "8 damage; a failed 80% roll does not bounce")
	_finish()
	_fresh()
	foes = _field([Vector2i(3, 0), Vector2i(3, 2)])
	ts = Card.create_by_id("trick_shot")
	ts.rng_selected_index = 0
	_play(ts, foes[0])
	_check(_lost(foes[1]) > 0 and _lost(foes[1]) == _lost(foes[0]), "the 80% bounce repeats the hit on the next enemy")
	_finish()
	# The odds of each further bounce fall by 20%: 80, 60, 40, 20, then none.
	var chain := _field([Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4), Vector2i(3, 5), Vector2i(3, 6)])
	seed(1)
	var max_bounces := 0
	for _n in range(40):
		var t2 := Card.create_by_id("trick_shot")
		t2.base_damage = 1
		t2.rng_selected_index = 0
		var before: Array = chain.map(func(x): return x.current_health)
		t2.execute(chain[0], stats, dm, 0.0, 0.0, bm)
		var hit := 0
		for i in range(chain.size()):
			if chain[i].current_health < before[i]:
				hit += 1
		max_bounces = maxi(max_bounces, hit - 1)
	_check(max_bounces <= 4, "never more than 4 bounces (80/60/40/20%%): %d" % max_bounces)

	print("-- Tricks of Alberich --")
	_fresh()
	foes = _field([Vector2i(2, 0), Vector2i(0, 4), Vector2i(5, 0)])
	var toa := _play(Card.create_by_id("tricks_of_alberich"), main.player, null, func():
		var m = bm.get_buff(Buff.BuffType.MIGHT)
		var g = bm.get_buff(Buff.BuffType.REGEN)
		return {"t0": foes[0].taunt_tempo, "t1": foes[1].taunt_tempo, "far": foes[2].taunt_target == null,
			"might": [m.value, m.duration] if m else [], "armor": stats.current_armor, "regen": g.value if g else 0})
	var ts_: Dictionary = toa["snap"]
	_check(ts_.get("t0") == 5 and ts_.get("t1") == 5 and ts_.get("far"), "taunts enemies in a 4-square radius for 5 tempo")
	_check(ts_.get("might") == [10, 5], "+10 STR for the taunt's 5 tempo (%s)" % str(ts_.get("might")))
	_check(ts_.get("armor") == 8, "+4 armor per enemy taunted (%s)" % str(ts_.get("armor")))
	_check(ts_.get("regen") == 4, "+2 Regen per enemy taunted (%s)" % str(ts_.get("regen")))
	_finish()

	print("-- Trip --")
	_fresh()
	var te: Enemy = _field([Vector2i(1, 0)])[0]
	var trr := _play(Card.create_by_id("trip"), te, null, func(): return {"slow": te.slow_stacks})
	_check(_hit(_lost(te), _phys(5), te), "5 damage (%d)" % _lost(te))
	_check(trr["snap"].get("slow") == 2 and not te.has_debuff_type("trip"), "Slowed 2, no Tripped debuff (%s)" % str(trr["snap"].get("slow")))
	_finish()

# ---------------------------------------------------------------- Try This / Turtles / 20/20

func _test_try_turtle_twenty() -> void:
	print("-- Try This! --")
	_fresh()
	_field([Vector2i(5, 0)])
	var mm0 := stats.max_mana
	var hs0 := stats.hand_size
	var tt := Card.create_by_id("try_this")
	tt.rng_selected_index = -2  # no reverse
	_play(tt, main.player)
	_check(stats.max_mana == mm0 + 30 and stats.hand_size == hs0 + 2, "+3 mana pool, +2 hand size")
	_finish()
	_tempo(10)
	_check(stats.max_mana == mm0 and stats.hand_size == hs0, "for 10 tempo")
	_fresh()
	mm0 = stats.max_mana
	hs0 = stats.hand_size
	tt = Card.create_by_id("try_this")
	tt.rng_selected_index = 0  # the 10% reverse
	_play(tt, main.player)
	_check(stats.max_mana == mm0 - 30 and stats.hand_size == hs0 - 2, "the 10% reverse: -3 mana pool, -2 hand size")
	_finish()
	_tempo(10)
	_check(stats.max_mana == mm0 and stats.hand_size == hs0, "…also for 10 tempo")
	_check(is_equal_approx(tt.rng_outcomes_data[0].percent, 10.0), "a 10% chance")

	print("-- Turtle Up --")
	_fresh()
	_field([Vector2i(5, 0)])
	var tu := _play(Card.create_by_id("turtle_up"), main.player, null, func():
		var f = bm.get_buff(Buff.BuffType.FORTIFY)
		return {"f": f.duration if f else 0})
	_check(tu["snap"].get("f") == 20, "Fortify for 20 tempo")
	_finish()

	print("-- 20/20 --")
	_fresh()
	var bowshot := Card.create_by_id("thrown_stone")
	var melee := Card.create_by_id("slash")
	var r0: int = main._helm_range_bonus(bowshot)
	var tw := Card.create_by_id("twenty_twenty")
	_play(tw, main.player)
	_finish()
	_check(dm.maintained_cards.has(tw), "maintained")
	_check(main._helm_range_bonus(bowshot) == r0 + 3, "+3 range on ranged offensive cards")
	_check(main._helm_range_bonus(melee) == 0, "not on melee cards")
	_check(main._helm_range_bonus(Card.create_by_id("swap")) == 0, "not on ranged non-offensive cards")

# ---------------------------------------------------------------- Understanding / Vengeful / Vined

func _test_understanding_vengeful_vined() -> void:
	print("-- Understanding --")
	_fresh()
	var e: Enemy = _field([Vector2i(1, 0)])[0]
	_play(Card.create_by_id("understanding"), main.player)
	_finish()
	_check(not bm.has_buff(Buff.BuffType.KEEN), "no crit before the delay")
	_tempo(8)
	_check(not bm.has_buff(Buff.BuffType.KEEN), "still waiting at 9 tempo")
	_tempo(1)
	_check(bm.has_buff(Buff.BuffType.KEEN), "armed after 10 tempo")
	_play(Card.create_by_id("slice"), e)
	_check(_lost(e) == Card.crit_multiply(_phys(15), stats, e), "the next damaging card auto-crits (%d)" % _lost(e))
	_finish()
	_check(not bm.has_buff(Buff.BuffType.KEEN), "only that one")

	print("-- Vengeful Shield --")
	_fresh()
	var foes := _field([Vector2i(1, 0), Vector2i(3, 0)])
	var vs := Card.create_by_id("vengeful_shield")
	dm.hand.append(vs)
	main._on_player_armor_broken()
	_check(not dm.hand.has(vs) and stats.current_armor == 5, "exposed: it fires for 5 armor")
	_check(foes[0].is_stunned and foes[0].stun_tempo == 5, "…and stuns the enemy in melee range for 5 tempo")
	_check(not foes[1].is_stunned, "not one out of melee range")

	print("-- Vined Encasing --")
	_fresh()
	_field([Vector2i(5, 0)])
	bm.apply_buff(Buff.create_fortify(50, "test"))
	stats.current_armor = 12
	var ve := _play(Card.create_by_id("vined_encasing"), main.player, null, func():
		var t = bm.get_buff(Buff.BuffType.THORNS)
		return {"th": [t.value, t.duration, t.decay_by_damage] if t else []})
	_check(ve["snap"].get("th") == [12, 20, true], "1 thorn per armor (12) for 20 tempo, shed X per X damage (%s)" % str(ve["snap"].get("th")))
	_finish()

# ---------------------------------------------------------------- Vines / Volatile / Wear Down

func _test_vines_volatile_wear() -> void:
	print("-- Vines --")
	_fresh()
	var e: Enemy = _field([Vector2i(3, 0)])[0]
	var vn := Card.create_by_id("vines")
	var vr := _play(vn, e, null, func(): return {"root": e.rooted_tempo})
	var per: int = main._card_player_damage(vn)
	_check(vr["snap"].get("root") == 15, "held in place for 15 tempo (%s)" % str(vr["snap"].get("root")))
	_finish()
	var lost := []
	for _i in range(3):
		_tempo(5)
		lost.append(_lost(e))
	_check(lost[0] == per and lost[1] == 2 * per and lost[2] == 3 * per, "4 damage every 5 tempo, three times (%s)" % str(lost))

	print("-- Volatile Mixture --")
	_fresh()
	var foes := _field([Vector2i(2, 0), Vector2i(4, 0)])
	var vm := Card.create_by_id("volatile_mixture")
	dm.hand.append(vm)
	dm.discard_card_from_hand(vm)
	_check(_lost(foes[0]) == _spell(8) and _lost(foes[1]) == 0, "On Discard: 8 to the nearest enemy (%d)" % _lost(foes[0]))
	_fresh()
	foes = _field([Vector2i(2, 0)])
	vm = Card.create_by_id("volatile_mixture")
	dm.hand.append(vm)
	vm.set_meta("vm_in_hand_since", tm.global_tempo)
	var hp0 := stats.current_health
	_tempo(4)
	_check(dm.hand.has(vm) and stats.current_health == hp0, "4 tempo in hand: nothing yet")
	_tempo(1)
	_check(not dm.hand.has(vm) and dm.discard_pile.has(vm), "5 tempo in hand: discarded")
	_check(hp0 - stats.current_health == 8, "…after 8 self-damage (%d)" % (hp0 - stats.current_health))

	print("-- Wear Down --")
	_fresh()
	e = _field([Vector2i(1, 0)])[0]
	var wdr := _play(Card.create_by_id("wear_down"), main.player, null, func():
		var w = bm.get_buff(Buff.BuffType.WEAR_DOWN)
		return {"w": w.duration if w else 0})
	_finish()
	_check(wdr["snap"].get("w") == 15, "lasts 15 tempo")
	_play(Card.create_by_id("slice"), e)
	_finish()
	_check(e.attack_reduction == 1, "a hit: enemy attack -1")
	_play(Card.create_by_id("slice"), e)
	_finish()
	_check(e.attack_reduction == 2, "a consecutive hit: -2")

# ---------------------------------------------------------------- Worms / Worst / Wrath

func _test_worms_worst_wrath() -> void:
	print("-- Worms Armageddon --")
	_fresh()
	var foes := _field([Vector2i(4, 0), Vector2i(4, 1)])
	var wa := Card.create_by_id("worms_armageddon")
	wa.rng_selected_index = -2
	var w0: int = main._summoned_worms.size()
	_play(wa, foes[0])
	_check(_lost(foes[0]) == main._card_player_damage(wa) and _lost(foes[1]) == 0, "23 damage to a single target (%d)" % _lost(foes[0]))
	_check(main._summoned_worms.size() == w0, "no worms on the 90%")
	_finish()
	_fresh()
	foes = _field([Vector2i(4, 0)])
	wa = Card.create_by_id("worms_armageddon")
	wa.rng_selected_index = 0
	_play(wa, foes[0])
	_check(main._summoned_worms.size() == w0 + 2, "the 10%: two Alaskan Bull Worms")
	if main._summoned_worms.size() > 0:
		var wm = main._summoned_worms.back()
		_check(wm.max_health == 12 and wm.CONTACT_DAMAGE == 6 and wm.burrowed, "each 12 HP, 6 damage, burrowed")
	_finish()
	_check(is_equal_approx(float(wa.rng_outcomes_data[0]["percent"]), 10.0), "a 10% chance")

	print("-- What's the Worst? --")
	_fresh()
	var e: Enemy = _field([Vector2i(1, 0)])[0]
	var wt := Card.create_by_id("worst_that_could_happen")
	wt.rng_selected_index = 0
	_play(wt, e)
	var base_lost: int = _lost(e) - 15
	_check(_hit(base_lost, _phys(5), e) and not e.is_stunned, "heads: 5 damage +15 (%d)" % _lost(e))
	_finish()
	_fresh()
	e = _field([Vector2i(1, 0)])[0]
	wt = Card.create_by_id("worst_that_could_happen")
	wt.rng_selected_index = 1
	var wtr := _play(wt, e, null, func(): return {"stun": e.stun_tempo})
	_check(_hit(_lost(e), _phys(5), e) and wtr["snap"].get("stun") == 5, "tails: 5 damage, stunned 5 tempo (%s)" % str(wtr["snap"].get("stun")))
	_finish()

	print("-- Wrath of the Sea --")
	_fresh()
	stats.current_mana = 400
	# Burst 4x4 around the landing (cells -1..+2), landing 3 squares north.
	foes = _field([Vector2i(1, -2), Vector2i(-1, -4), Vector2i(5, -3)])
	var dest: Vector2i = _pc() + Vector2i(0, -3)
	var inside := [foes[0], foes[1]]
	var ws := Card.create_by_id("wrath_of_the_sea")
	var r := _play(ws, main.player, Vector2i(0, -3))
	_check(r["mana"] == 200, "spends HALF your current mana (%d)" % r["mana"])
	_check(_pc() == dest, "blinks to the point")
	var expect := _phys(200)
	_check(_lost(inside[0]) == expect and _lost(inside[1]) == expect, "the mana spent (plus STR) to every enemy in the 4x4 (%d)" % _lost(inside[0]))
	_check(_lost(foes[2]) == 0, "not outside it")
	var mana_after_hit := stats.current_mana
	_check(int(mana_after_hit) == 200 + 30, "+15 mana per enemy hit (%d)" % int(mana_after_hit))
	for en in inside:
		var c: Vector2i = gm.world_to_grid(en.position)
		var on_edge: bool = c.x == dest.x - 1 or c.x == dest.x + 2 or c.y == dest.y - 1 or c.y == dest.y + 2
		_check(on_edge, "shoved to the burst's edge (%s)" % str(c))
	_finish()
