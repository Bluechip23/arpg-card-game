extends SceneTree

## Regression checks for the card/item audit fixes: default damage, Empower
## spend, the Burgonet bonus on every armor-granting defense card, bonus
## damage on hard-coded executors, true-discard counting, Down But Not Out,
## Resilient stacking, Repelled Block melee-only, Phoenix crossing, Element
## Pollination freeze, timed Determination, Healing Tonic range, Shed Weight,
## Oops live roll, the level-2 forge boost and the Girdle's Lv3 DET.
## Run: godot --headless --path . --script tests/test_card_item_audit.gd

var failures := 0
var main = null

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Card & item audit fixes ===")
	_run()

func _run() -> void:
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	main = packed.instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(6):
		await process_frame
	var stats = main.player.get_stats()
	var dm = main.deck_manager
	var bm = main.player.get_buff_manager()
	var dummy: Enemy = null
	for e in main.enemy_spawner.get_living_enemies():
		dummy = e

	print("-- Default damage --")
	_check(Card.create_draw().damage == 0 and not Card.create_draw().is_offensive(), "a utility card is not offensive by default")
	_check(Card.create_block().is_offensive() == false, "Block is not offensive")
	_check(Card.create_slash().is_offensive() and Card.create_slash().damage == 10, "Slash still deals its 10")

	print("-- Empower --")
	stats.empowered_cards_remaining = 2
	Card.create_draw().execute(null, stats, dm, 0.0, 0.0, bm)
	_check(stats.empowered_cards_remaining == 2, "a utility card spends no Empower charge")
	Card.create_slash().execute(dummy, stats, dm, 0.0, 0.0, bm)
	_check(stats.empowered_cards_remaining == 1, "an attack spends one")
	stats.empowered_cards_remaining = 0

	print("-- Burgonet / Thick Steel on every armor-granting defense card --")
	stats.current_armor = 0
	stats.equipment_defense_card_block = 2
	Card.create_parry().execute(dummy, stats, dm, 0.0, 0.0, bm)
	_check(stats.current_armor == 7, "Parry (5 armor, outside _execute_block) grants 5 + 2 (%d)" % stats.current_armor)
	stats.current_armor = 0
	Card.create_slash().execute(dummy, stats, dm, 0.0, 0.0, bm)
	stats.add_armor(3)
	_check(stats.current_armor == 3, "a later plain armor gain carries no leftover bonus")
	stats.equipment_defense_card_block = 0
	stats.current_armor = 0

	print("-- Bonus damage reaches hard-coded executors --")
	var parry := Card.create_parry()
	parry.bonus_damage = 4
	parry.execute(dummy, stats, dm, 0.0, 0.0, bm)
	_check(parry.last_damage_dealt >= stats.get_effective_physical_damage(9), "Parry deals its 5 plus the +4 bonus (%d)" % parry.last_damage_dealt)
	stats.current_armor = 0
	var pigs := Card.create_if_pigs_could_fly()
	pigs.bonus_damage = 5
	pigs.execute(dummy, stats, dm, 0.0, 0.0, bm)
	_check(pigs.last_damage_dealt >= stats.get_effective_spell_damage(20), "If Pigs Could Fly deals 15 plus the +5 bonus (%d)" % pigs.last_damage_dealt)

	print("-- Discards vs plays --")
	dm.hand.clear()
	dm.true_discards_this_cycle = 0
	dm.discards_this_cycle = 0
	var b := Card.create_block()
	dm.hand.append(b)
	dm.discard_card_from_hand(b)
	_check(dm.true_discards_this_cycle == 1, "a true discard counts (%d)" % dm.true_discards_this_cycle)
	var before: int = dm.true_discards_this_cycle
	dm.card_discarded.emit(Card.create_slash())
	_check(dm.true_discards_this_cycle == before, "a played card passing the discard pile does not")

	print("-- Down But Not Out --")
	var pdm = main.player.get_debuff_manager()
	pdm.clear_all_debuffs()
	pdm.apply_debuff(Debuff.create_slowed(4))
	stats.current_health = 1
	var dbno := Card.create_down_but_not_out()
	dbno.execute(main.player, stats, dm, 0.0, 0.0, bm)
	_check(stats.current_health >= 5, "heals the visible stack count (Slowed 4 → at least +4, now %d)" % stats.current_health)
	pdm.clear_all_debuffs()
	stats.current_health = stats.max_health

	print("-- Resilient keeps the stronger value --")
	for buff in bm.buffs.duplicate():
		bm.remove_buff(buff.buff_type)
	bm.apply_buff(Buff.create_resilient(2, 3, "Smithed"))
	bm.apply_buff(Buff.create_resilient(10, 15, "Stone Hide"))
	_check(bm.get_buff(Buff.BuffType.RESILIENT).value == 10, "a 10% Resilient overrides a 2%")
	bm.remove_buff(Buff.BuffType.RESILIENT)

	print("-- Repelled Block is melee-only --")
	bm.apply_buff(Buff.create_repelled_block("test"))
	stats.current_armor = 0
	stats.current_health = stats.max_health
	dummy.position = main.player.position + Vector3(6, 0, 0)
	dummy._deal_damage_to_player(main.player, 1, "Ember")
	_check(bm.has_buff(Buff.BuffType.REPELLED_BLOCK), "a ranged hit passes under it")
	dummy.position = main.player.position + Vector3(1, 0, 0)
	dummy._deal_damage_to_player(main.player, 1, "Claw")
	_check(not bm.has_buff(Buff.BuffType.REPELLED_BLOCK), "an unblocked melee hit spends it")
	stats.current_health = stats.max_health

	print("-- Gift from the Phoenix fires on the crossing --")
	dm.hand.clear()
	dm.hand.append(Card.create_gift_from_the_phoenix())
	# Already low: a change that stays below half is not a crossing.
	main._last_hp_ratio = 0.3
	stats.current_health = 4
	main._on_player_health_changed(4, stats.max_health)
	_check(dm.hand.size() == 1, "a change while already under half does not fire it")
	# From healthy to under half: the crossing fires it.
	main._last_hp_ratio = 0.9
	main._on_player_health_changed(4, stats.max_health)
	_check(dm.hand.is_empty(), "dropping under half fires it")
	dm.hand.clear()
	stats.current_health = stats.max_health

	print("-- Element Pollination --")
	Card.element_pollination_active = true
	dummy.shock_stacks = 0
	dummy.stun_tempo = 0
	dummy.apply_debuff("shock", 5)
	_check(dummy.stun_tempo == 5, "5 Shock freezes for 5 tempo like Cold")
	Card.element_pollination_active = false

	print("-- Timed Determination --")
	var det_before: float = stats.get_determination_modifier()
	stats.add_temp_determination(2, 20)
	_check(stats.get_temp_determination_bonus() == 2, "Hold the Line's +2 DET is a timed bonus")
	stats.process_tempo(20)
	_check(stats.get_temp_determination_bonus() == 0 and is_equal_approx(stats.get_determination_modifier(), det_before), "…and expires after 20 tempo")

	print("-- Small card fixes --")
	var tonic := Card.create_healing_tonic()
	_check(tonic.is_ranged and tonic.get_effective_range() == 5, "Healing Tonic reaches 5 squares")
	_check(Card.create_healthy_bliss().card_type == Card.CardType.UNPLAYABLE, "Healthy Bliss cannot be played from hand")
	dm.hand.clear()
	var shed := Card.create_shed_weight()
	var slash := Card.create_slash()
	dm.hand.append(shed)
	dm.hand.append(Card.create_block())
	dm.hand.append(slash)
	shed.execute(null, stats, dm, 0.0, 0.0, bm)
	_check(slash.tempo_cost == 3 and slash.temp_hand_tempo_reduction == 1, "Shed Weight cuts tempo in hand only, never the deck's cost")
	dm.hand.clear()
	var oops := Card.create_oops()
	oops.rng_selected_index = -1
	var hp_before: int = dummy.current_health
	oops.execute(dummy, stats, dm, 0.0, 0.0, bm)
	_check(dummy.current_health < hp_before, "an unrolled Oops still rolls its hits live")

	print("-- Forge --")
	var hat := ItemData.create_kettle_hat()
	hat.level_up()
	_check(hat.special_effect_value == 3, "Kettle Hat Lv.2 grants 3 per tick (was a no-op)")
	var knuckles := ItemData.create_brass_knuckles()
	var melee_before: int = knuckles.damage_bonus_to_melee_cards
	knuckles.level_up()
	_check(knuckles.damage_bonus_to_melee_cards == melee_before + 1, "Brass Knuckles Lv.2 boosts its melee bonus")
	var girdle := ItemData.create_girdle_of_aphrodite()
	girdle.level_up()
	girdle.level_up()
	_check(girdle.determination_bonus == 3, "Girdle of Aphrodite keeps +3 DET at Lv.3 (%d)" % girdle.determination_bonus)

	await _round_two(stats, dm, bm, dummy)

	main.queue_free()
	await process_frame
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _round_two(stats, dm, bm, dummy: Enemy) -> void:
	print("-- Instant site effects (what Lethal Recall replays) --")
	var chickens: Array = []
	for e in main.enemy_spawner.get_living_enemies():
		if e.enemy_type == Enemy.EnemyType.DUMMY:
			chickens.append(e)
	var far: Enemy = chickens[0]
	far.position = main.player.position + Vector3(4, 0, 0)
	far.current_health = far.max_health
	main._fire_instant_site_effect(Card.create_reapers_taking(), {"target": far})
	var reach: float = Vector2(main.player.position.x - far.position.x, main.player.position.z - far.position.z).length()
	_check(reach <= 1.6, "Reaper's Taking teleports the player beside the victim (%.1f away)" % reach)
	_check(far.current_health == far.max_health - 20, "…and cuts for 20 (%d/%d)" % [far.current_health, far.max_health])
	far.is_stunned = false
	main._fire_instant_site_effect(Card.create_vengeful_shield(), {"target": far})
	_check(far.is_stunned, "Vengeful Shield's site effect stuns the adjacent attacker")
	_check(main._last_played_card != null and main._last_played_card.card_id == "vengeful_shield", "the site records the instant for Lethal Recall")
	var ally = main._dojo_allies[0]
	var a_st = ally.get_stats()
	a_st.current_health = 100
	main._fire_instant_site_effect(Card.create_psionic_flow(), {"mode": "guard", "victim": ally, "attacker": far})
	_check(a_st.current_health >= 108, "Psionic Flow guard mode heals the struck ALLY at least 8 (%d)" % a_st.current_health)

	print("-- Trick Shot bounces between enemies --")
	var other: Enemy = chickens[1]
	other.current_health = other.max_health
	other.position = far.position + Vector3(1, 0, 0)
	var shot := Card.create_trick_shot()
	shot.rng_selected_index = 0  # the first bounce is pre-rolled to hit
	shot.execute(far, stats, dm, 0.0, 0.0, bm)
	_check(other.current_health < other.max_health, "the bounce lands on a DIFFERENT enemy")

	print("-- Item Mastery moves the real cards --")
	var inv = main.player.get_inventory()
	var sword := ItemData.create_wooden_sword()
	inv.equip_item(sword, 0)
	var splinter: Card = null
	for c in dm.draw_pile + dm.discard_pile + dm.hand:
		if c.card_id == "splinter":
			splinter = c
	_check(splinter != null, "the equipped Wooden Sword grants a real Splinter into the deck")
	if splinter:
		dm.hand.erase(splinter)
		if not dm.draw_pile.has(splinter) and not dm.discard_pile.has(splinter):
			dm.draw_pile.append(splinter)
		var deck_before: int = dm.draw_pile.size() + dm.discard_pile.size() + dm.hand.size()
		main._apply_card_world_effects(Card.create_item_mastery(), null)
		var deck_after: int = dm.draw_pile.size() + dm.discard_pile.size() + dm.hand.size()
		_check(dm.hand.has(splinter) and not dm.draw_pile.has(splinter), "Item Mastery moves the granted card into hand")
		_check(deck_after == deck_before, "…without duplicating anything (%d → %d cards)" % [deck_before, deck_after])
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)

	print("-- It's Alive raises the corpse at the aim --")
	main._corpses.clear()
	main._frankensteins.clear()
	var corpse_pos: Vector3 = main.player.position + Vector3(-3, 0, 0)
	main._corpses.append({"cell": main.grid_manager.world_to_grid(corpse_pos), "position": corpse_pos})
	main._resurrect_frankenstein(main.player.position + Vector3(3, 0, -3))
	_check(main._frankensteins.is_empty() and main._corpses.size() == 1, "aiming far from the corpse fizzles")
	main._resurrect_frankenstein(corpse_pos)
	_check(main._frankensteins.size() == 1 and main._corpses.is_empty(), "aiming at the corpse raises it")
	main._clear_frankensteins()

	print("-- Odds boosts last until a chance card is played --")
	stats.next_odds_boost = 100.0
	var tt := Card.create_try_this()
	tt.roll_rng([], stats.get_chance_boost() + stats.next_odds_boost)
	_check(not tt.rng_binary_succeeded(), "House Money keeps Try This from backfiring (its chance is a downside)")
	var oops2 := Card.create_oops()
	oops2.roll_rng([], 100.0)
	_check(oops2.rng_selected_index == 0, "a +100 boost makes Oops's best outcome (5 hits) certain")
	dm.hand.clear()
	main._on_hand_updated()
	_check(is_equal_approx(stats.next_odds_boost, 100.0), "a hand refresh does not spend the boost")
	stats.next_odds_boost = 0.0

	print("-- Living Armor tops Regen up to the Fortify mark --")
	for buff in bm.buffs.duplicate():
		bm.remove_buff(buff.buff_type)
	bm.apply_buff(Buff.create_regen(3, 15, "test"))
	bm.apply_buff(Buff.create_fortify(20, "test"))
	_check(bm.get_buff(Buff.BuffType.FORTIFY).value == 3, "Fortify stamps the Regen you had (3) as its number")
	bm.remove_buff(Buff.BuffType.REGEN)
	Card.create_living_armor().execute(null, stats, dm, 0.0, 0.0, bm)
	var regen = bm.get_buff(Buff.BuffType.REGEN)
	_check(regen != null and regen.value == 3, "Living Armor brings Regen back to 3")
	Card.create_living_armor().execute(null, stats, dm, 0.0, 0.0, bm)
	_check(bm.get_buff(Buff.BuffType.REGEN).value == 3, "…and never past the mark")
	for buff in bm.buffs.duplicate():
		bm.remove_buff(buff.buff_type)
