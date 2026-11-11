extends SceneTree

## Phase 2 wiring audit, card slice C (docs/audit/wiring/cards_c.md): Heavy
## Swing … Poison Bomb, 51 cards. Each card's description checked against
## the code that runs it, in a booted main.tscn (the dojo):
##  - the cost table: every card played through the real play path
##    (Main.select_card + play_selected_card, the tick clock drained) charges
##    exactly its .tres mana and tempo; unplayables and instants are refused;
##  - per card, the described effect, resolved through Main._resolve_queued_card
##    (the same entry the tick clock calls) or the real trigger site.
## Run: godot --headless --path . --script tests/test_wiring_cards_c.gd

var failures: int = 0
var main = null
var stats: PlayerStats = null
var dm = null
var bm: BuffManager = null
var dbm: DebuffManager = null
var tm = null
var A: Enemy = null   # dojo dummies, moved around per test
var B: Enemy = null
var C: Enemy = null
var home := Vector2i(9, 11)

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	TempoManager.preferred_swing_hold = 0  # blows land at once
	await _boot()
	if main == null:
		print("=== %d failure(s) ===" % failures)
		quit(1)
		return
	_test_costs()
	_test_heavy_swing()
	_test_hemotoxins()
	_test_heroic_leap()
	_test_hold_the_line()
	_test_odds_cards()
	_test_huck()
	_test_hunker_down()
	_test_ice_grenade()
	_test_if_pigs_could_fly()
	_test_improvised_ammo()
	_test_infest()
	_test_internal_combustion()
	_test_item_mastery()
	_test_its_alive()
	_test_lady_luck()
	_test_last_breath()
	_test_lead_arrow()
	_test_lethal_recall()
	_test_life_steal()
	_test_life_swap()
	_test_lightly_dazed()
	_test_living_armor()
	_test_m_for_mini()
	_test_mage_shield()
	_test_magic_barrier()
	_test_mana_surge()
	_test_mark()
	_test_meditate()
	_test_meister()
	_test_mend()
	_test_mind_mend()
	_test_mind_over_matter()
	_test_minor_wounds()
	_test_mirror_mirror()
	_test_misery()
	_test_mixed_bag()
	_test_monk()
	_test_morphine()
	_test_multishot()
	_test_negotiate()
	_test_neither_man_nor_beast()
	_test_oops()
	_test_out_of_guesses()
	_test_paralysis()
	_test_parry()
	_test_patience()
	_test_peshtigo()
	_test_petey()
	_test_poison_bomb()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

# ------------------------------------------------------------------ setup

func _settle(frames: int = 6) -> void:
	for _i in range(frames):
		await process_frame

func _boot() -> void:
	print("-- Booting main.tscn as the dojo --")
	main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	await _settle(8)
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	_check(main.player != null and main.enemy_spawner != null, "the dojo is up")
	if main.player == null:
		main = null
		return
	stats = main.player.get_stats()
	dm = main.deck_manager
	bm = main.player.get_buff_manager()
	dbm = main.player.get_debuff_manager()
	tm = main.tempo_manager
	var enemies: Array = main.enemy_spawner.get_living_enemies()
	A = enemies[0]
	B = enemies[1]
	C = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.DUMMY, main._ground_pos(Vector2i(2, 6)))
	home = main.grid_manager.world_to_grid(main.player.position)

func _cell(n: Node3D) -> Vector2i:
	return main.grid_manager.world_to_grid(n.position)

func _put(n: Node3D, cell: Vector2i) -> void:
	n.position = main._ground_pos(cell)
	if "target_position" in n:
		n.target_position = n.position
	if "is_moving" in n:
		n.is_moving = false

## Fresh pools, no statuses, no crit (exact numbers), every dummy parked far
## from the player and reset.
func _fresh() -> void:
	main.glut_tempo_remaining = 0
	main.selected_card_index = -1
	main._misery_active = false
	main.mouse_override = Vector2(-1, -1)
	_put(main.player, home)
	stats.max_health = 500
	stats.current_health = 500
	stats.current_temp_health = 0
	stats.temp_health_tempo_remaining = 0
	stats.current_armor = 0
	stats.max_mana = 5000
	stats.current_mana = 1000.0
	stats.sphere_bonus_crit = -float(PlayerStats.base_crit_chance)  # cancel the innate 5%: exact numbers
	stats.next_odds_boost = 0.0
	stats.pending_mana_ward = false
	dbm.clear_all_debuffs()
	for b in bm.buffs.duplicate():
		bm.remove_buff(b.buff_type)
	dm.hand.clear()
	var parks := [Vector2i(5, 4), Vector2i(5, 8), Vector2i(2, 6)]
	var i := 0
	for e in [A, B, C]:
		_put(e, parks[i])
		i += 1
		e.max_health = 100000
		e.current_health = 100000
		e.current_armor = 0
		for k in Main.MISERY_KINDS:
			if k[1] in e:
				e.set(k[1], 0)
		e.is_marked = false
		e.narashimha_tempo = 0
		e.narashimha_heal_cap = -1

## Stand an enemy next to (east of) the player.
func _beside(e: Enemy, off: Vector2i = Vector2i(1, 0)) -> void:
	_put(e, home + off)

func _aim_at(world: Vector3) -> void:
	main.mouse_override = main.get_world_camera().unproject_position(world)

func _lost(e: Enemy, before: int) -> int:
	return before - e.current_health

## Play `card` through the real path: select it, play it, drain the tick
## clock. Returns what the play cost and whether it went through.
func _play(card: Card, target, extra_hand: Array = []) -> Dictionary:
	dm.hand.clear()
	for c in extra_hand:
		dm.hand.append(c)
	dm.hand.append(card)
	main.glut_tempo_remaining = 0
	main.selected_card_index = -1
	main.select_card(dm.hand.find(card))
	var m0: float = stats.current_mana + stats.current_temp_mana
	var h0: int = stats.current_health
	var t0: int = tm.global_tempo
	var reserved0: int = stats.maintained_mana
	main.play_selected_card(target)
	var played: bool = main.selected_card_index == -1
	var mana_paid: int = roundi(m0 - (stats.current_mana + stats.current_temp_mana))
	var health_paid: int = h0 - stats.current_health
	var guard := 0
	while tm._pending_ticks > 0 and guard < 400:
		tm._process_one_tick()
		guard += 1
	main._close_maintain_prompt()
	return {"played": played, "mana": mana_paid, "health": health_paid, "tempo": tm.global_tempo - t0,
		"reserved": stats.maintained_mana - reserved0}

## Resolve a card the way the tick clock does (Main._resolve_queued_card):
## execute, world effects, Lethal Recall memory, odds bookkeeping, Glut.
func _resolve(card: Card, target) -> void:
	main._pending_resolve_queue.append({"card": card, "target": target, "owner_index": 0,
		"data": {"aim_world": null}})
	main._resolve_queued_card(card)

## Advance the real tempo clock one tick at a time (enemies, buffs, cycles).
func _ticks(n: int) -> void:
	for _i in range(n):
		tm._process_one_tick()

func _target_for(card: Card):
	if "enemy" in card.target_types:
		return A
	return main.player

# ------------------------------------------------------------------ costs

func _test_costs() -> void:
	print("-- Cost table: each card charges its own mana and tempo --")
	var playable := ["heavy_swing", "hemotoxins", "heroic_leap", "hold_the_line", "hope_this_works",
		"house_money", "huck", "hunker_down", "ice_grenade", "if_pigs_could_fly", "improvised_ammo",
		"infest", "internal_combustion", "item_mastery", "its_alive", "lady_luck", "last_breath",
		"lead_arrow", "lethal_recall", "life_steal", "life_swap", "living_armor", "loaded_die",
		"m_for_mini", "mana_surge", "mark", "meditate", "meister_of_faustmesser", "mend",
		"mind_mend", "mind_over_matter", "mirror_mirror", "misery_loves_company", "mixed_bag",
		"monk_of_the_night", "morphine", "multishot", "negotiate", "neither_man_nor_beast", "oops",
		"out_of_guesses", "paralysis", "parry", "patience", "peshtigos_kiss", "poison_bomb"]
	for cid in playable:
		_fresh()
		_beside(A)
		var card := Card.create_by_id(cid)
		var want_mana: int = card.mana_cost
		var want_tempo: int = card.tempo_cost
		var r := _play(card, _target_for(card), [Card.create_by_id("slash")])
		_check(r["played"] and r["mana"] == want_mana and r["tempo"] == want_tempo,
			"%s: played for its %d mana / %d tempo (paid %d / %d)" % [cid, want_mana, want_tempo, r["mana"], r["tempo"]])
		if card.health_cost > 0:
			_check(r["health"] == card.health_cost, "%s: also costs %d health (paid %d)" % [cid, card.health_cost, r["health"]])
		if card in dm.maintained_cards:
			dm.dismiss_maintained_card(dm.maintained_cards.find(card))
	for cid in ["lightly_dazed", "minor_wounds", "petey_the_pet_rock", "mage_shield", "magic_barrier"]:
		_fresh()
		var card := Card.create_by_id(cid)
		var r := _play(card, main.player)
		_check(not r["played"] and r["mana"] == 0 and r["tempo"] == 0 and dm.hand.has(card),
			"%s cannot be played from hand (unplayable / instant)" % cid)

# ------------------------------------------------------------------ cards

func _test_heavy_swing() -> void:
	print("-- Heavy Swing --")
	_fresh()
	_beside(A)
	var hs := Card.create_by_id("heavy_swing")
	var r := _play(hs, A, [Card.create_by_id("block")])
	_check(not r["played"] and dm.hand.has(hs) and r["mana"] == 0, "Heavy Swing is refused while a non-offensive card (Block) is in hand")
	_fresh()
	_beside(A)
	var hp: int = A.current_health
	hs = Card.create_by_id("heavy_swing")
	r = _play(hs, A, [Card.create_by_id("slash"), Card.create_by_id("fireball")])
	_check(r["played"] and _lost(A, hp) == stats.get_effective_physical_damage(20),
		"with only offensive cards beside it, it deals 20 (+STR) (%d)" % _lost(A, hp))

func _test_hemotoxins() -> void:
	print("-- Hemotoxins --")
	_fresh()
	Card.elixir_poison_heals = false
	_resolve(Card.create_by_id("hemotoxins"), A)
	_check(A.poison_stacks == 10, "Hemotoxins: 10 Poison on a healthy target (%d)" % A.poison_stacks)
	A.poison_stacks = 0
	A.current_health = 49000
	_resolve(Card.create_by_id("hemotoxins"), A)
	_check(A.poison_stacks == 20, "…20 Poison on a target below 50%% health (%d)" % A.poison_stacks)

func _test_heroic_leap() -> void:
	print("-- Heroic Leap --")
	_fresh()
	var leap: int = maxi(2, stats.strength)
	# A full leap (aimed past STR tiles): lands STR tiles away, the enemy beside the landing is hit.
	_put(A, home + Vector2i(leap + 1, 0))
	_aim_at(main._ground_pos(home + Vector2i(leap + 3, 0)))
	var hp: int = A.current_health
	_resolve(Card.create_by_id("heroic_leap"), main.player)
	var full_dmg: int = _lost(A, hp)
	_check(_cell(main.player) == home + Vector2i(leap, 0), "Heroic Leap jumps STR (%d) tiles (landed %s)" % [leap, str(_cell(main.player))])
	_check(full_dmg == stats.get_effective_physical_damage(leap * 3), "…and the landing hits for damage from the distance (%d)" % full_dmg)
	# A short hop (one tile) hits softer.
	_fresh()
	_put(A, home + Vector2i(2, 0))
	_aim_at(main._ground_pos(home + Vector2i(1, 0)))
	hp = A.current_health
	_resolve(Card.create_by_id("heroic_leap"), main.player)
	_check(_cell(main.player) == home + Vector2i(1, 0) and _lost(A, hp) > 0 and _lost(A, hp) < full_dmg,
		"a 1-tile hop deals less than the full leap (%d < %d)" % [_lost(A, hp), full_dmg])

func _test_hold_the_line() -> void:
	print("-- Hold the Line --")
	_fresh()
	var ally = main._dojo_allies[0] if main._dojo_allies.size() > 0 else null
	var ally_armor: int = ally.get_stats().current_armor if ally else 0
	var det0: int = stats.get_temp_determination_bonus()
	_resolve(Card.create_by_id("hold_the_line"), main.player)
	var might = bm.get_buff(Buff.BuffType.MIGHT)
	_check(stats.current_armor == 5, "Hold the Line: +5 armor (%d)" % stats.current_armor)
	_check(stats.get_temp_determination_bonus() - det0 == 2, "…+2 DET")
	_check(might != null and might.value == 2 and might.duration == 15, "…+2 STR (Might) for 15 tempo")
	_check(ally != null and ally.get_stats().current_armor - ally_armor == 5, "…on every ally, not only you")

func _test_odds_cards() -> void:
	print("-- Hope This Works / Loaded Die / House Money --")
	_fresh()
	stats.current_health = 400
	var htw := Card.create_by_id("hope_this_works")
	htw.rng_selected_index = 0  # the 50% landed
	_resolve(htw, main.player)
	var strg = bm.get_buff(Buff.BuffType.STRENGTHEN)
	# Every heal runs the heal pipeline (+INT bonus, healing gear), as damage runs STR.
	_check(stats.current_health == 400 + stats.get_effective_heal_amount(5), "Hope This Works (success): heals the ally 5 (+INT) (%d)" % stats.current_health)
	_check(strg != null and strg.charges == 3, "…and Strengthens their next 3 attacks")
	_fresh()
	stats.current_health = 400
	htw = Card.create_by_id("hope_this_works")
	htw.rng_selected_index = -2  # the 50% missed
	_resolve(htw, main.player)
	_check(stats.current_health == 400 and not bm.has_buff(Buff.BuffType.STRENGTHEN), "…(fail) does nothing")
	_check(is_equal_approx(float(Card.create_by_id("hope_this_works").rng_outcomes_data[0].percent), 50.0), "…a 50% chance")
	_fresh()
	var dog = main._dojo_allies[0]
	var dog_st = dog.get_stats()
	dog_st.current_health = 100
	htw = Card.create_by_id("hope_this_works")
	htw.rng_selected_index = 0
	_resolve(htw, dog)
	_check(dog_st.current_health > 100 and dog.get_buff_manager().has_buff(Buff.BuffType.STRENGTHEN) and stats.current_health == 500,
		"…aimed at an ally, the ally is healed and strengthened, not the caster")
	dog.get_buff_manager().remove_buff(Buff.BuffType.STRENGTHEN)
	dog_st.current_health = dog_st.max_health

	_fresh()
	var held := Card.create_by_id("hope_this_works")
	dm.hand.append(held)
	_resolve(Card.create_by_id("loaded_die"), main.player)
	_check(is_equal_approx(stats.next_odds_boost, 10.0), "Loaded Die: the next chance card is +10%% (%.0f)" % stats.next_odds_boost)
	_resolve(Card.create_by_id("hope_this_works"), main.player)
	_check(stats.next_odds_boost == 0.0, "…spent by the next card with a probability")

	_fresh()
	held = Card.create_by_id("hope_this_works")
	dm.hand.append(held)
	_resolve(Card.create_by_id("house_money"), main.player)
	_check(stats.next_odds_boost >= 100.0, "House Money: the next odds are boosted to certain")
	_check(held.rng_binary_succeeded(), "…the chance card in hand re-rolls and triggers")
	var oops := Card.create_by_id("oops")
	oops.roll_rng([], stats.get_chance_boost() + stats.next_odds_boost)
	_check(oops.rng_selected_index == 0, "…a multi-outcome card lands its best outcome")

func _test_huck() -> void:
	print("-- Huck --")
	_fresh()
	_beside(A)
	stats.current_armor = 30
	var hp: int = A.current_health
	_resolve(Card.create_by_id("huck"), A)
	_check(_lost(A, hp) == 30 and stats.current_armor == 0, "Huck: deals your armor (30) and you lose all of it (%d, armor %d)" % [_lost(A, hp), stats.current_armor])

func _test_hunker_down() -> void:
	print("-- Hunker Down --")
	_fresh()
	_resolve(Card.create_by_id("hunker_down"), main.player)
	var f = bm.get_buff(Buff.BuffType.FORTIFY)
	_check(f != null and f.duration == 30, "Hunker Down: Fortify for 30 tempo")

func _test_ice_grenade() -> void:
	print("-- Ice Grenade --")
	_fresh()
	_put(A, home + Vector2i(3, 0))
	_put(B, home + Vector2i(5, 0))   # 2 squares from A
	_put(C, home + Vector2i(6, 0))   # 3 squares from A
	var ha: int = A.current_health
	var hb: int = B.current_health
	var hc: int = C.current_health
	var ig := Card.create_by_id("ice_grenade")
	_aim_at(A.position)
	var r := _play(ig, main.player)
	_check(_lost(A, ha) == stats.get_effective_spell_damage(5) and _lost(B, hb) == stats.get_effective_spell_damage(5),
		"Ice Grenade: 5 damage (+INT) within 2 squares of the aim (A %d, B %d)" % [_lost(A, ha), _lost(B, hb)])
	_check(_lost(C, hc) == 0, "…nothing 3 squares out")
	_check(r["played"] and dm.hand.has(ig), "…two shots: the grenade stays in hand after the first")
	_aim_at(C.position)
	hc = C.current_health
	r = _play(ig, main.player)
	_check(_lost(C, hc) > 0 and not dm.hand.has(ig), "…the second, aimed separately, lands where it is aimed and spends the card")
	dm.discard_pile.erase(ig)
	dm.draw_pile.append(ig)
	dm.draw_card()
	_check(dm.hand.has(ig) and ig.consecutive_uses == 0, "…drawn again, it has both shots back")
	# Cold amount, without the tick clock decaying it.
	_fresh()
	_put(A, home + Vector2i(3, 0))
	_aim_at(A.position)
	_resolve(Card.create_by_id("ice_grenade"), main.player)
	_check(A.cold_stacks == 2, "…2 Cold on each enemy hit (%d)" % A.cold_stacks)

func _test_if_pigs_could_fly() -> void:
	print("-- If Pigs Could Fly --")
	_fresh()
	var int0: int = stats.base_intelligence
	stats.base_intelligence = 16  # diameter 2 → radius 1
	stats.recalculate_derived_stats()
	_put(A, home + Vector2i(3, 0))
	_put(B, home + Vector2i(4, 0))
	_put(C, home + Vector2i(5, 0))
	var ha: int = A.current_health
	var hb: int = B.current_health
	var hc: int = C.current_health
	_resolve(Card.create_by_id("if_pigs_could_fly"), A)
	var want: int = stats.get_effective_spell_damage(15)
	_check(_lost(A, ha) == want and _lost(B, hb) == want, "If Pigs Could Fly: 15 to the target and the area around it (%d, %d)" % [_lost(A, ha), _lost(B, hb)])
	_check(_lost(C, hc) == 0, "…the area is INT/8 wide (INT 16: the next tile only)")
	stats.base_intelligence = int0
	stats.recalculate_derived_stats()

func _test_improvised_ammo() -> void:
	print("-- Improvised Ammo --")
	_fresh()
	_beside(A)
	var hp: int = A.current_health
	_resolve(Card.create_by_id("improvised_ammo"), A)
	_check(_lost(A, hp) == stats.get_effective_physical_damage(8) and A.weaken_stacks == 3,
		"Improvised Ammo: 8 damage and 3 Weaken (%d, %d)" % [_lost(A, hp), A.weaken_stacks])
	_fresh()
	_beside(A)
	var bonus0: float = stats.improvised_ammo_crit_bonus
	var ia := Card.create_by_id("improvised_ammo")
	dm.hand.append(ia)
	hp = A.current_health
	dm.discard_card_from_hand(ia)
	_check(_lost(A, hp) == 4, "…discarded: 4 damage to the nearest enemy (%d)" % _lost(A, hp))
	_check(is_equal_approx(stats.improvised_ammo_crit_bonus - bonus0, 10.0), "…and Improvised Ammo gains +10% crit")
	_check(PlayerStats.EQUIPMENT_SAVE_FIELDS.has("improvised_ammo_crit_bonus"), "…permanently (saved with the character)")
	stats.improvised_ammo_crit_bonus = bonus0

func _test_infest() -> void:
	print("-- Infest --")
	_fresh()
	var hatched := [0]
	var inf := Card.create_by_id("infest")
	inf.hatch_handler = func(): hatched[0] += 1
	dm.hand.append(inf)
	dm.tick_temp_mods(4)
	_check(hatched[0] == 0 and dm.hand.has(inf), "Infest: still a brood after 4 tempo in hand")
	dm.tick_temp_mods(1)
	_check(hatched[0] == 1 and not dm.hand.has(inf), "…hatches at 5 tempo in hand (the Rat King binds 2 Wererats: test_rat_king_infest.gd)")
	_fresh()
	inf = Card.create_by_id("infest")
	inf.hatch_handler = func(): hatched[0] += 1
	var r := _play(inf, main.player)
	_check(r["played"] and r["mana"] == 50 and r["tempo"] == 0 and not dm.discard_pile.has(inf), "…played (50 mana, 0 tempo) it is erased")
	_fresh()
	inf = Card.create_by_id("infest")
	inf.hatch_handler = func(): hatched[0] += 1
	dm.hand.append(inf)
	dm.discard_card_from_hand(inf)
	dm.tick_temp_mods(10)
	_check(hatched[0] == 1 and not dm.discard_pile.has(inf), "…discarded it is erased and never hatches")

func _test_internal_combustion() -> void:
	print("-- Internal Combustion --")
	_fresh()
	_put(A, home + Vector2i(2, 0))
	_put(B, home + Vector2i(5, 0))
	stats.current_armor = 20
	var ha: int = A.current_health
	var hb: int = B.current_health
	_resolve(Card.create_by_id("internal_combustion"), main.player)
	_check(stats.current_armor == 10, "Internal Combustion: removes half your armor (%d left)" % stats.current_armor)
	_check(_lost(A, ha) == 10 and _lost(B, hb) == 0, "…and deals that much around you (%d near, %d far)" % [_lost(A, ha), _lost(B, hb)])

func _test_item_mastery() -> void:
	print("-- Item Mastery --")
	_fresh()
	var inv = main.player.get_inventory()
	var sword := ItemData.create("wooden_sword")
	inv.equip_item(sword, 0)
	var granted: Card = null
	for c in dm.draw_pile + dm.discard_pile + dm.hand:
		if c.card_id == "splinter":
			granted = c
	var slotted := Card.create_by_id("slash")
	slotted.slotted_in_item = sword
	sword.slotted_cards.append(slotted)
	dm.discard_pile.append(slotted)
	if granted:
		dm.hand.erase(granted)
		dm.discard_pile.erase(granted)
		if not dm.draw_pile.has(granted):
			dm.draw_pile.append(granted)
	var plain := Card.create_by_id("block")
	dm.draw_pile.append(plain)
	_resolve(Card.create_by_id("item_mastery"), main.player)
	_check(granted != null and dm.hand.has(granted), "Item Mastery: a card an item grants comes to hand")
	_check(dm.hand.has(slotted) and not dm.discard_pile.has(slotted), "…and a card slotted in an item")
	_check(not dm.hand.has(plain), "…but no plain deck card")
	sword.slotted_cards.erase(slotted)
	dm.hand.erase(slotted)
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)

func _test_its_alive() -> void:
	print("-- ITS ALIVE!!!!! --")
	_fresh()
	main._corpses.clear()
	main._clear_frankensteins()
	var corpse_cell: Vector2i = home + Vector2i(-2, 0)
	var corpse_pos: Vector3 = main._ground_pos(corpse_cell)
	main._corpses.append({"cell": corpse_cell, "position": corpse_pos})
	_aim_at(corpse_pos)
	_resolve(Card.create_by_id("its_alive"), main.player)
	_check(main._frankensteins.size() == 1 and main._corpses.is_empty(), "ITS ALIVE: the nearby corpse rises as Frankensteins Monster")
	main._clear_frankensteins()

func _test_lady_luck() -> void:
	print("-- Lady Luck --")
	_fresh()
	_resolve(Card.create_by_id("lady_luck"), main.player)
	var en = bm.get_buff(Buff.BuffType.KEEN)
	_check(en != null and en.value == 30 and en.charges == 5, "Lady Luck: the blessed ally gets +30% crit for 5 attacks")
	var dog = main._dojo_allies[0]
	_fresh()
	_resolve(Card.create_by_id("lady_luck"), dog)
	_check(dog.get_buff_manager().has_buff(Buff.BuffType.KEEN) and not bm.has_buff(Buff.BuffType.KEEN), "…aimed at an ally, the ally is blessed")
	dog.get_buff_manager().remove_buff(Buff.BuffType.KEEN)

func _test_last_breath() -> void:
	print("-- Last Breath --")
	_fresh()
	_beside(A)
	stats.current_mana = 40.0
	var hp: int = A.current_health
	_resolve(Card.create_by_id("last_breath"), A)
	_check(stats.current_mana == 0.0, "Last Breath consumes all remaining mana")
	_check(_lost(A, hp) == stats.get_effective_physical_damage(12), "…3 damage per 10 mana (x10 scale): 40 mana → 12 (+STR) (%d)" % _lost(A, hp))

func _test_lead_arrow() -> void:
	print("-- Lead Arrow --")
	_fresh()
	_put(A, home + Vector2i(2, 0))
	var la := Card.create_by_id("lead_arrow")
	var hp: int = A.current_health
	_resolve(la, A)
	_check(_lost(A, hp) == floori(stats.get_effective_physical_damage(10) * 1.8), "Lead Arrow: 1.8x damage (%d)" % _lost(A, hp))
	_check(la.requires_high_ground and not main._has_high_ground(main.player.position, A), "…requires high ground (flat dojo floor: no)")
	# The click on the enemy is refused without high ground.
	_fresh()
	_put(A, home + Vector2i(2, 0))
	la = Card.create_by_id("lead_arrow")
	dm.hand.append(la)
	main.select_card(0)
	_aim_at(A.position + Vector3(0, 0.6, 0))
	var picked = main.enemy_under_mouse()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(400, 300)
	var m0: float = stats.current_mana
	main._input(ev)
	_check(picked == A, "(the test cursor is on the enemy)")
	_check(dm.hand.has(la) and stats.current_mana == m0, "…clicking an enemy from flat ground does not fire it")
	# Control: the same click with a plain ranged arrow does fire.
	dm.hand.clear()
	var ctl := Card.create_by_id("mixed_bag")
	dm.hand.append(ctl)
	main.selected_card_index = -1
	main.select_card(0)
	main._input(ev)
	_check(not dm.hand.has(ctl), "(control: the same click fires Mixed Bag)")
	var g := 0
	while tm._pending_ticks > 0 and g < 50:
		tm._process_one_tick()
		g += 1
	main.selected_card_index = -1

func _test_lethal_recall() -> void:
	print("-- Lethal Recall --")
	_fresh()
	var ms := Card.create_by_id("mage_shield")
	dm.hand.append(ms)
	stats.take_damage(5, dbm, bm)
	var after_instant: int = stats.current_armor
	_check(after_instant == 10, "(Mage Shield fired: +10 block)")
	_resolve(Card.create_by_id("lethal_recall"), main.player)
	_check(stats.current_armor == after_instant + 20, "Lethal Recall: the last instant's effect triggers 2 more times (+20, armor %d)" % stats.current_armor)

func _test_life_steal() -> void:
	print("-- Life Steal --")
	_fresh()
	_beside(A)
	stats.current_health = 300
	_resolve(Card.create_by_id("life_steal"), main.player)
	_check(bm.has_buff(Buff.BuffType.LIFE_STEAL), "Life Steal: armed")
	var hp: int = A.current_health
	_resolve(Card.create_by_id("slash"), A)
	var dealt: int = _lost(A, hp)
	_check(dealt > 0 and stats.current_health == 300 + stats.get_effective_heal_amount(dealt), "…the next attack heals for the damage it did (+INT, the heal pipeline) (%d → hp %d)" % [dealt, stats.current_health])
	_check(not bm.has_buff(Buff.BuffType.LIFE_STEAL), "…once")

func _test_life_swap() -> void:
	print("-- Life Swap --")
	_fresh()
	_beside(A)
	stats.current_health = 300
	stats.current_mana = 200.0
	var hp: int = A.current_health
	_resolve(Card.create_by_id("life_swap"), main.player)
	_check(stats.current_health == 20 and int(stats.current_mana) == 3000, "Life Swap: HP and mana pools exchange at 10 mana = 1 HP (hp %d, mana %d)" % [stats.current_health, int(stats.current_mana)])
	_check(_lost(A, hp) == 280, "…the HP lost (280) hits the enemy in melee range (%d)" % _lost(A, hp))

func _test_lightly_dazed() -> void:
	print("-- Lightly Dazed --")
	_fresh()
	var ld := Card.create_by_id("lightly_dazed")
	while dm.hand.size() < dm.get_hand_cap():
		dm.hand.append(Card.create_by_id("slash"))
	dm.add_card_to_hand(ld)
	_check(dm.hand.has(ld), "Lightly Dazed: Linger — joins a full hand")
	dm.hand.erase(ld)
	dm.discard_pile.append(ld)
	for _i in range(7):
		dm._process_erase_timers()
	_check(dm.discard_pile.has(ld), "…still there after 35 tempo")
	dm._process_erase_timers()
	_check(not dm.discard_pile.has(ld), "…erased after 40")

func _test_living_armor() -> void:
	print("-- Living Armor --")
	_fresh()
	bm.apply_buff(Buff.create_regen(3, 15, "Test"))
	bm.apply_buff(Buff.create_fortify(15, "Test"))
	bm.remove_buff(Buff.BuffType.REGEN)
	_resolve(Card.create_by_id("living_armor"), main.player)
	var rg = bm.get_buff(Buff.BuffType.REGEN)
	_check(rg != null and rg.value == 3, "Living Armor: Regen back up to the Fortify's number (3)")
	_resolve(Card.create_by_id("living_armor"), main.player)
	_check(bm.get_buff(Buff.BuffType.REGEN).value == 3, "…and never past it")

func _test_m_for_mini() -> void:
	print("-- M for Mini --")
	_fresh()
	_beside(A)
	_resolve(Card.create_by_id("m_for_mini"), A)
	_check(A.vulnerable_stacks == 2 and A.weaken_stacks == 2, "M for Mini: 2 Vulnerable and 2 Weaken (%d, %d)" % [A.vulnerable_stacks, A.weaken_stacks])

func _test_mage_shield() -> void:
	print("-- Mage Shield --")
	_fresh()
	var ms := Card.create_by_id("mage_shield")
	dm.hand.append(ms)
	stats.take_damage(5, dbm, bm)
	_check(stats.current_armor == 10 and not dm.hand.has(ms), "Mage Shield: taking damage fires it for 10 block")

func _test_magic_barrier() -> void:
	print("-- Magic Barrier --")
	_fresh()
	var mb := Card.create_by_id("magic_barrier")
	dm.hand.append(mb)
	main._on_enemy_attacking_player(A, main.player)
	_check(stats.current_armor == 8 and not dm.hand.has(mb), "Magic Barrier: an incoming attack fires it for 8 armor")
	_check(not dm.discard_pile.has(mb), "…and it is consumed (erased)")

func _test_mana_surge() -> void:
	print("-- Mana Surge --")
	_fresh()
	_put(A, home + Vector2i(3, 0))
	var ms := Card.create_by_id("mana_surge")
	var hp: int = A.current_health
	var r := _play(ms, A)
	_check(_lost(A, hp) == stats.get_effective_spell_damage(5), "Mana Surge: 5 damage (%d)" % _lost(A, hp))
	_check(not dm.discard_pile.has(ms) and not dm.hand.has(ms), "…erased after play")
	_fresh()
	var m0: float = stats.current_mana
	_resolve(Card.create_by_id("mana_surge"), A)
	_check(int(stats.current_mana - m0) == 10, "…gains 10 mana on the x10 scale (text: 'gain 1 mana') (%d)" % int(stats.current_mana - m0))

func _test_mark() -> void:
	print("-- Mark --")
	_fresh()
	_put(A, home + Vector2i(3, 0))
	_resolve(Card.create_by_id("mark"), A)
	_check(A.marked_tempo == 25, "Mark: 25 tempo (%d)" % A.marked_tempo)
	var hp: int = A.current_health
	A.take_damage(100, true)
	_check(_lost(A, hp) == 115, "…your hits on it land 15%% harder (%d)" % _lost(A, hp))
	# FLAGGED: "from your attacks" — every player hit counts today, a spell too.
	var fb := Card.create_by_id("fireball")
	fb.execute(A, stats, dm, 0.0, 0.0, null)
	hp = A.current_health
	main._apply_card_world_effects(fb, A)
	_check(_lost(A, hp) == fb.last_damage_dealt + ceili(fb.last_damage_dealt * 0.15), "…(as built, a spell's hit is marked up too: %d of %d)" % [_lost(A, hp), fb.last_damage_dealt])
	_ticks(24)
	_check(A.has_debuff_type("marked"), "…still marked after 24 tempo")
	_ticks(1)
	_check(not A.has_debuff_type("marked"), "…and it wears off after 25 tempo")

func _test_meditate() -> void:
	print("-- Meditate --")
	_fresh()
	stats.current_health = 100
	for _i in range(3):
		dm.hand.append(Card.create_by_id("slash"))
	for _i in range(20):
		dm.draw_pile.append(Card.create_by_id("block"))
	_resolve(Card.create_by_id("meditate"), main.player)
	_check(dm.hand.size() == dm.get_hand_cap() - 2, "Meditate: discards the hand and draws to full -2 (%d/%d)" % [dm.hand.size(), dm.get_hand_cap()])
	_check(stats.current_health == 400, "…heals to 80%% (%d)" % stats.current_health)
	_check(main.glut_tempo_remaining == 5, "…Glut 5")
	main.glut_tempo_remaining = 0

func _test_meister() -> void:
	print("-- Meister of Faustmesser --")
	_fresh()
	dm.discard_pile.clear()
	var free := Card.create_by_id("meditate")   # 0 mana
	var paid := Card.create_by_id("slash")
	dm.discard_pile.append(free)
	dm.discard_pile.append(paid)
	var mf := Card.create_by_id("meister_of_faustmesser")
	_play(mf, main.player)
	_check(dm.hand.has(free) and not dm.hand.has(paid), "Meister of Faustmesser: zero-cost cards in the discard pile come to hand, others stay")
	_check(dm.jail_pile.has(mf) and mf.jail_time_remaining == 20, "…and the card is jailed for 20")
	dm.jail_pile.erase(mf)

func _test_mend() -> void:
	print("-- Mend --")
	_fresh()
	var near = main._dojo_allies[0]
	var far = main._dojo_allies[1]
	_put(near, home + Vector2i(2, 2))
	_put(far, home + Vector2i(4, 2))
	near.get_stats().current_health = 0 + near.get_stats().max_health / 2
	far.get_stats().current_health = far.get_stats().max_health / 2
	var near_hp: int = near.get_stats().current_health
	var far_hp: int = far.get_stats().current_health
	var near_armor: int = near.get_stats().current_armor
	stats.current_health = 100
	stats.current_mana = 0.0
	stats.max_mana = 500
	_resolve(Card.create_by_id("mend"), main.player)
	var mend_heal: int = stats.get_effective_heal_amount(100)  # 20% of 500, through the heal pipeline
	_check(stats.current_health == 100 + mend_heal and int(stats.current_mana) == 100, "Mend: 20%% health (+INT) and 20%% mana restored (hp %d, mana %d)" % [stats.current_health, int(stats.current_mana)])
	_check(stats.current_armor == mend_heal, "…and armor equal to the health restored (%d)" % stats.current_armor)
	var gained: int = near.get_stats().current_health - near_hp
	_check(gained > 0 and near.get_stats().current_armor - near_armor == gained, "…an ally within 4 squares too")
	_check(far.get_stats().current_health == far_hp, "…not one 6 squares away")
	_put(near, Vector2i(12, 4))
	_put(far, Vector2i(12, 8))

func _test_mind_mend() -> void:
	print("-- Mind Mend --")
	_fresh()
	stats.current_mana = 0.0
	var mm := Card.create_by_id("mind_mend")
	var r := _play(mm, main.player)
	_check(r["mana"] <= 0 and r["health"] == 15, "Mind Mend: costs 15 health, no mana")
	_fresh()
	stats.current_mana = 0.0
	_resolve(Card.create_by_id("mind_mend"), main.player)
	_check(int(stats.current_mana) == 60, "…restores 60 mana (%d)" % int(stats.current_mana))

func _test_mind_over_matter() -> void:
	print("-- Mind over Matter --")
	_fresh()
	stats.current_mana = 100.0
	_resolve(Card.create_by_id("mind_over_matter"), main.player)
	stats.take_damage(40, dbm, bm)
	_check(stats.current_health == 500 and int(stats.current_mana) == 80, "Mind over Matter: the next hit is halved and paid in mana, 1 per point (hp %d, mana %d)" % [stats.current_health, int(stats.current_mana)])
	stats.take_damage(10, dbm, bm)
	_check(stats.current_health == 490, "…only the next hit")

func _test_minor_wounds() -> void:
	print("-- Minor Wounds --")
	_fresh()
	var mw := Card.create_by_id("minor_wounds")
	dm.draw_pile.append(mw)
	dm.draw_card()
	_check(stats.current_health == 498, "Minor Wounds: 2 damage to self on draw (%d)" % stats.current_health)
	dm.hand.erase(mw)
	dm.draw_pile.append(mw)
	for _i in range(8):
		dm._process_erase_timers()
	_check(not dm.draw_pile.has(mw), "…Erase 40")

func _test_mirror_mirror() -> void:
	print("-- Mirror Mirror --")
	_fresh()
	var src := Card.create_by_id("fireball")
	dm.hand.append(src)
	dm.hand.append(Card.create_by_id("block"))
	var mm := Card.create_by_id("mirror_mirror")
	mm.picked_card = src
	_resolve(mm, main.player)
	var copies: Array = dm.hand.filter(func(c): return c.card_id == "fireball")
	var dup: Card = null
	for c in copies:
		if c != src:
			dup = c
	_check(copies.size() == 2 and dup != null, "Mirror Mirror: the chosen card is duplicated into the hand")
	_check(dup != null and dup.erase_tempo == 5 and src.erase_tempo == 0, "…the duplicate has Erase 5")

func _test_misery() -> void:
	print("-- Misery Loves Company --")
	_fresh()
	_put(A, home + Vector2i(1, 0))
	_put(B, home + Vector2i(0, 1))
	A.apply_debuff("poison", 4)
	dbm.apply_debuff(Debuff.create(Debuff.DebuffType.BURN, 3, 15))
	_resolve(Card.create_by_id("misery_loves_company"), main.player)
	stats.current_armor = 4
	_resolve(Card.create_by_id("internal_combustion"), main.player)
	_check(B.poison_stacks >= 4, "Misery Loves Company: the next AOE spreads a hit enemy's debuff to every enemy hit (%d)" % B.poison_stacks)
	_check(A.burn_stacks >= 3 and B.burn_stacks >= 3, "…and your own debuffs too")
	_check(not main._misery_active, "…once")

func _test_mixed_bag() -> void:
	print("-- Mixed Bag --")
	_fresh()
	_put(A, home + Vector2i(3, 0))
	var hp: int = A.current_health
	var mb := Card.create_by_id("mixed_bag")
	_resolve(mb, A)
	_check(mb.is_ranged and _lost(A, hp) == stats.get_effective_physical_damage(7), "Mixed Bag: a standard ranged arrow (%d)" % _lost(A, hp))

func _test_monk() -> void:
	print("-- Monk of the Night --")
	_fresh()
	_beside(A)
	var monk := Card.create_by_id("monk_of_the_night")
	var r := _play(monk, main.player)
	_check(dm.maintained_cards.has(monk) and r["reserved"] == 50, "Monk of the Night: maintained (50 mana held)")
	var hp: int = A.current_health
	var hs := Card.create_by_id("heavy_swing")
	_resolve(hs, A)
	_check(stats.current_armor == floori(_lost(A, hp) * 0.1), "…an attack grants 10%% of its damage as block (%d of %d)" % [stats.current_armor, _lost(A, hp)])
	stats.current_armor = 0
	_resolve(Card.create_by_id("fireball"), A)
	_check(stats.current_armor == 0, "…a spell does not")
	dm.dismiss_maintained_card(dm.maintained_cards.find(monk))

func _test_morphine() -> void:
	print("-- Morphine --")
	_fresh()
	_resolve(Card.create_by_id("morphine"), main.player)
	_check(stats.current_temp_health == 4, "Morphine: +4 temp HP")
	var temp_gone_at := -1
	var hurt_at := -1
	for t in range(1, 21):
		_ticks(1)
		if temp_gone_at < 0 and stats.current_temp_health == 0:
			temp_gone_at = t
		if hurt_at < 0 and stats.current_health < 500:
			hurt_at = t
	# FLAGGED: temp HP runs on the cycle clock (5 a cycle), so the 4 temp HP go
	# at the third cycle boundary — 11 to 15 tempo after the play — while the
	# 2 damage lands at exactly 15. Pinned as it is now.
	_check(temp_gone_at >= 11 and temp_gone_at <= 15, "…the temp HP goes on the third cycle boundary, 11-15 tempo (gone at %d)" % temp_gone_at)
	_check(hurt_at == 15 and stats.current_health == 498, "…then you take 2 damage (at %d, hp %d)" % [hurt_at, stats.current_health])

func _test_multishot() -> void:
	print("-- Multishot --")
	_fresh()
	_put(A, home + Vector2i(3, 0))
	var hp: int = A.current_health
	stats.sphere_bonus_crit = -100.0  # no crit at all, even with the +30% step
	_resolve(Card.create_by_id("multishot"), A)
	stats.sphere_bonus_crit = -float(PlayerStats.base_crit_chance)
	_check(_lost(A, hp) == 3 * stats.get_effective_physical_damage(7), "Multishot: 7 damage 3 times (%d)" % _lost(A, hp))
	_check(main.glut_tempo_remaining == 5, "…Glut 5")
	main.glut_tempo_remaining = 0
	# Each hit gains 10% crit: with no innate crit the third shot rolls at 30%.
	var crits := 0
	for _i in range(300):
		var shot := Card.create_by_id("multishot")
		A.current_health = 100000
		hp = A.current_health
		shot.execute(A, stats, dm, 0.0, 0.0, bm)
		if _lost(A, hp) > 3 * stats.get_effective_physical_damage(7):
			crits += 1
	# P(at least one crit in 10/20/30%) = 1 - .9*.8*.7 = 49.6%
	_check(crits > 100 and crits < 200, "…each hit gains 10%% crit chance (%d/300 volleys crit)" % crits)

func _test_negotiate() -> void:
	print("-- Negotiate --")
	_fresh()
	_put(A, home + Vector2i(3, 0))
	var g0: int = stats.gold
	_resolve(Card.create_by_id("negotiate"), A)
	_check(stats.gold - g0 == 5, "Negotiate: steal 5 gold")

func _test_neither_man_nor_beast() -> void:
	print("-- Neither Man nor Beast --")
	_fresh()
	_beside(A)
	A.current_armor = 50
	A.damage_resistances = {DamageTypes.Type.PHYSICAL: 50.0}
	var hp: int = A.current_health
	_resolve(Card.create_by_id("neither_man_nor_beast"), A)
	_check(_lost(A, hp) == stats.get_effective_physical_damage(10) and A.current_armor == 50,
		"Neither Man nor Beast: 10 damage through armor and resistance (%d, armor %d)" % [_lost(A, hp), A.current_armor])
	var low: int = A.current_health
	A._regenerate(1000)
	_check(A.current_health == low, "…the target cannot heal it back")
	_ticks(10)
	A._regenerate(1000)
	_check(A.current_health > low, "…after 10 tempo it can")
	A.damage_resistances = {}

func _test_oops() -> void:
	print("-- Oops --")
	var want := {0: 5, 1: 3, 2: 2}
	for idx in want:
		_fresh()
		_beside(A)
		var o := Card.create_by_id("oops")
		o.rng_selected_index = idx
		var hp: int = A.current_health
		_resolve(o, A)
		_check(_lost(A, hp) == want[idx] * stats.get_effective_physical_damage(3), "Oops outcome %d: %d hits of 3 (%d)" % [idx, want[idx], _lost(A, hp)])
	var o2 := Card.create_by_id("oops")
	var pcts: Array = []
	for d in o2.rng_outcomes_data:
		pcts.append(int(d.percent))
	_check(pcts == [30, 40, 30], "…30% / 40% / 30%")

func _test_out_of_guesses() -> void:
	print("-- Out of Guesses --")
	_fresh()
	for _i in range(3):
		dm.hand.append(Card.create_by_id("slash"))
	var old: Array = dm.hand.duplicate()
	for _i in range(10):
		dm.draw_pile.append(Card.create_by_id("block"))
	_resolve(Card.create_by_id("out_of_guesses"), main.player)
	var fresh_count := 0
	for c in dm.hand:
		if c.card_id == "block":
			fresh_count += 1
	_check(fresh_count == 3 and dm.hand.size() == 3, "Out of Guesses: discards the hand and draws that many (%d)" % fresh_count)
	_check(old.all(func(c): return dm.discard_pile.has(c)), "…the old hand is in the discard pile")

func _test_paralysis() -> void:
	print("-- Paralysis --")
	_fresh()
	var pa := Card.create_by_id("paralysis")
	dm.hand.append(pa)
	var moved: bool = main.player.move_to_grid(main._ground_pos(home + Vector2i(0, 1)), 1)
	_check(not moved and main.player._is_webbed(), "Paralysis: you cannot move while it is in hand")
	var r := _play(pa, main.player)
	_check(r["played"] and r["mana"] == 10 and r["tempo"] == 5 and not dm.discard_pile.has(pa), "…play it (10 mana, 5 tempo) to tear it free — it is gone")
	_check(not main.player._is_webbed(), "…and you can move again")

func _test_parry() -> void:
	print("-- Parry --")
	_fresh()
	_beside(A)
	var hp: int = A.current_health
	_resolve(Card.create_by_id("parry"), A)
	_check(stats.current_armor == 5 and _lost(A, hp) == stats.get_effective_physical_damage(5), "Parry: 5 armor, 5 damage (%d)" % _lost(A, hp))
	var br = bm.get_buff(Buff.BuffType.BRACE)
	_check(br != null and br.value == 10 and br.charges == 1 and br.damage_type == DamageTypes.Type.PHYSICAL, "…10% physical resistance for 1 attack")

func _test_patience() -> void:
	print("-- Patience --")
	_fresh()
	for _i in range(10):
		dm.draw_pile.append(Card.create_by_id("block"))
	var pat := Card.create_by_id("patience")
	_play(pat, main.player)
	var left := -1
	for d in main._delayed_effects:
		if d.label == "patience":
			left = d.remaining
	_check(left == 15 - pat.tempo_cost, "Patience: the draw is due 15 tempo after the play (%d left after its own %d)" % [left, pat.tempo_cost])
	main._delayed_effects = main._delayed_effects.filter(func(d): return d.label != "patience")
	_fresh()
	for _i in range(10):
		dm.draw_pile.append(Card.create_by_id("block"))
	_resolve(Card.create_by_id("patience"), main.player)
	var n0: int = dm.hand.size()
	main._process_delayed_effects(14)
	_check(dm.hand.size() == n0, "Patience: nothing before 15 tempo")
	main._process_delayed_effects(1)
	_check(dm.hand.size() == n0 + 3, "…in 15 tempo, draw 3 (%d → %d)" % [n0, dm.hand.size()])

func _test_peshtigo() -> void:
	print("-- Peshtigo's Kiss (full coverage: test_peshtigo_live.gd) --")
	_fresh()
	var pk := Card.create_by_id("peshtigos_kiss")
	_check(pk.maintain_cost == 60 and pk.is_fire_spell, "Peshtigo's Kiss: Maintain 60, a fire spell")

func _test_petey() -> void:
	print("-- Petey the Pet Rock --")
	_fresh()
	for _i in range(10):
		dm.draw_pile.append(Card.create_by_id("block"))
	var pr := Card.create_by_id("petey_the_pet_rock")
	dm.draw_pile.append(pr)
	dm.draw_card()
	_check(dm.hand.has(pr) and dm.hand.size() == 4, "Petey: on draw, draw 3 cards (hand %d)" % dm.hand.size())
	main._apply_in_hand_debuffs()
	var sl = dbm.get_debuff(Debuff.DebuffType.SLOWED)
	_check(sl != null and sl.value == 2, "…while in hand: Slowed 2")
	var others: int = dm.hand.size() - 1
	dm.discard_card_from_hand(pr)
	_check(dm.hand.size() == others - 2, "…on discard: discard 2 cards (%d → %d)" % [others, dm.hand.size()])

func _test_poison_bomb() -> void:
	print("-- Poison Bomb --")
	_fresh()
	_put(A, home + Vector2i(3, 0))
	_put(B, home + Vector2i(5, 0))
	_put(C, home + Vector2i(6, 0))
	_aim_at(A.position)
	_resolve(Card.create_by_id("poison_bomb"), main.player)
	_check(A.poison_stacks == 6 and B.poison_stacks == 6, "Poison Bomb: 6 Poison on every enemy within 2 squares (%d, %d)" % [A.poison_stacks, B.poison_stacks])
	_check(C.poison_stacks == 0, "…none 3 squares out")
