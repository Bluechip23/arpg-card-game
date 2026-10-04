extends SceneTree

## Regression checks for the card-sheet pass: the numbers and mechanics the
## design sheet changed (Block, Roar, Maintain costs, Cover mitigation, timed
## Stagger/Slow/Strengthen, Trip, Empower-on-draw, Elixir, Parry, Poke, Smith
## thy Soul, Self Infliction, Basic Attack, Healthy Bliss as an instant,
## Bottomless Quiver into the Manifest zone, Misery spreading every debuff,
## Sky Attack's discard, Adrenaline Shot's distinct cards).
## Run: godot --headless --path . --script tests/test_card_sheet_pass.gd

var failures := 0
var main = null

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Card sheet pass ===")
	_run()

func _run() -> void:
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	main = packed.instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(6):
		await process_frame
	var stats: PlayerStats = main.player.get_stats()
	var dm = main.deck_manager
	var bm: BuffManager = main.player.get_buff_manager()
	var dbm: DebuffManager = main.player.get_debuff_manager()
	var enemies: Array = main.enemy_spawner.get_living_enemies()
	var dummy: Enemy = enemies[0] if enemies.size() > 0 else null

	print("-- Factory numbers --")
	var blk := Card.create_block()
	_check(blk.block == 8 and blk.mana_cost == 20 and blk.tempo_cost == 2, "Block: 8 armor for 2 mana, 2 tempo")
	var roar := Card.create_roar()
	_check(roar.mana_cost == 20 and roar.tempo_cost == 0 and is_equal_approx(roar.aoe_range, 3.5), "Roar: 2 mana, 0 tempo, within 3 squares")
	_check(Card.create_armored_discipline().maintain_cost == 50, "Armored Discipline holds 5M")
	_check(Card.create_cover().tempo_cost == 2, "Cover costs 2 tempo")
	var ca := Card.create_collect_arrows()
	_check(ca.tempo_cost == 4 and ca.glut_tempo == 15, "Collect Arrows: 4 tempo, keeps Glut 15")
	_check(Card.create_fountain_of_life().card_name == "Fountain of Health", "Fountain of Life is now named Fountain of Health (id kept)")
	_check(Card.create_oops().base_damage == 3, "Oops hits for 3")
	_check(not Card.create_worms_armageddon().is_aoe, "Worms Armageddon is single target")
	_check(Card.create_charge().target_types == ["point"], "Charge needs no target — a direction")
	_check(Card.create_armor_break().card_type == Card.CardType.ATTACK and Card.create_armor_break().is_attack(), "Armor Break is an Attack (the sheet's type), cast on yourself")
	_check(Card.create_healthy_bliss().card_type == Card.CardType.REACTION, "Healthy Bliss is an instant")
	_check(Card.create_meditate().glut_tempo == 5, "Meditate: Glut 5")
	var ba = Card.create_by_id("basic_attack")
	_check(ba != null and ba.mana_cost == 0 and ba.tempo_cost == 5 and ba.card_name == "Basic Attack",
		"Basic Attack: a free 0m / 5t proc card")
	_check(Card.DROP_EXCLUDED_CARD_IDS.has("basic_attack"), "Basic Attack never drops")

	print("-- Cover: straight mitigation before the hit --")
	stats.current_armor = 0
	stats.current_health = stats.max_health
	dm.hand.clear()
	stats.max_health = maxi(stats.max_health, 100)  # room for two hits without a defeat
	stats.current_health = stats.max_health
	var hp0: int = stats.current_health
	stats.take_damage(12, dbm, bm)
	var plain: int = hp0 - stats.current_health
	stats.current_health = stats.max_health
	stats.current_armor = 0
	var cover := Card.create_cover()
	dm.hand.append(cover)
	dm.hand.append(Card.create_draw())
	dm.hand.append(Card.create_draw())
	stats.take_damage(12, dbm, bm)
	var covered: int = stats.max_health - stats.current_health
	_check(covered == maxi(0, plain - 3), "Cover soaks the hand size, itself included (%d -> %d)" % [plain, covered])
	_check(not dm.hand.has(cover) and dm.discard_pile.has(cover), "Cover fires and is discarded")
	dm.hand.clear()

	print("-- Cover protects summons too --")
	dm.hand.clear()
	var sum_cover := Card.create_cover()
	dm.hand.append(sum_cover)
	dm.hand.append(Card.create_draw())
	main._spawn_summon(20, main.player.position, "skeleton")
	var sk = main._skeletons.back() if main._skeletons.size() > 0 else null
	if sk:
		var sk_hp: int = sk.health
		sk.take_damage(5)
		_check(sk.health == sk_hp - 3, "a summon beside you takes 5 - 2 (hand size) = 3 (%d)" % (sk_hp - sk.health))
	else:
		_check(false, "could not spawn a skeleton to test Cover on summons")
	dm.hand.clear()

	print("-- Poisoned Blood turns every heal card into damage --")
	stats.max_health = maxi(stats.max_health, 100)
	stats.current_health = 50
	stats.current_armor = 0
	bm.apply_buff(Buff.create_poisoned_blood(5, "Test"))
	Card.create_the_lights_favor().execute(main.player, stats, dm, 0.0, 0.0, bm)
	_check(stats.current_health < 50, "The Light's Favor (not a routed heal) hurts under Poisoned Blood (%d)" % stats.current_health)
	stats.current_health = 50
	Card.create_biscuit().execute(null, stats, dm, 0.0, 0.0, bm)
	_check(stats.current_health < 50, "Biscuit's full heal lands as damage (%d)" % stats.current_health)
	PlayerStats.heal_to_damage = false
	bm.remove_buff(Buff.BuffType.POISONED_BLOOD)
	stats.current_health = 50
	Card.create_healing_potion().execute(null, stats, dm, 0.0, 0.0, bm)
	_check(stats.current_health > 50, "with it gone, heals heal again")
	stats.current_health = stats.max_health

	print("-- Timed Stagger / Slow --")
	dbm.clear_all_debuffs()
	Card.create_tower_shield().execute(null, stats, dm, 0.0, 0.0, bm)
	var stag = dbm.get_debuff(Debuff.DebuffType.STAGGERED)
	_check(stag != null and stag.clock_timed and stag.duration == 40, "Tower Shield: Staggered for 40 tempo")
	_check(dbm.get_attack_mana_increase() > 0, "Staggered taxes attack cards")
	dbm.on_card_played(true)
	dbm.on_card_played(true)
	_check(dbm.has_debuff(Debuff.DebuffType.STAGGERED), "attack plays do not burn a timed Stagger")
	dbm.advance_time(40)
	_check(not dbm.has_debuff(Debuff.DebuffType.STAGGERED), "the clock ends it")
	Card.create_approach().execute(null, stats, dm, 0.0, 0.0, bm)
	var slow = dbm.get_debuff(Debuff.DebuffType.SLOWED)
	_check(slow != null and slow.clock_timed and slow.duration == 10, "Approach: Slowed for 10 tempo")
	dbm.consume_slowed_stack()
	_check(dbm.has_debuff(Debuff.DebuffType.SLOWED), "moving does not burn a timed Slow")
	dbm.clear_all_debuffs()

	print("-- Trip --")
	if dummy:
		dummy.apply_debuff("trip", 10)
		_check(dummy.tripped_tempo == 10 and dummy.has_debuff_type("trip"), "Trip: movement -4 for 10 tempo")
		dummy.tripped_tempo = 0

	print("-- Empower marks attack cards as they are drawn --")
	dm.hand.clear()
	stats.empowered_cards_remaining = 0
	stats.apply_empower(2)
	var e_block := Card.create_block()
	var e_slash := Card.create_slash()
	dm.draw_pile.append(e_block)
	dm.draw_pile.append(e_slash)  # top of the pile
	dm.draw_card()
	dm.draw_card()
	_check(e_slash.draw_empowered and not e_block.draw_empowered, "only the drawn attack is empowered")
	_check(stats.empowered_cards_remaining == 1, "one charge left for the next attack drawn")
	stats.empowered_cards_remaining = 0
	dm.hand.clear()

	print("-- Elixir: your poison cards heal instead --")
	Card.create_elixir().execute(null, stats, dm, 0.0, 0.0, bm)
	if dummy:
		dummy.poison_stacks = 0
		dummy.current_health = maxi(1, dummy.max_health - 40)
		var dhp: int = dummy.current_health
		Card.create_by_id("hemotoxins").execute(dummy, stats, dm, 0.0, 0.0, bm)
		_check(dummy.poison_stacks == 0 and dummy.current_health > dhp, "a poison card under Elixir heals its target")
	Card.elixir_poison_heals = false
	stats.elixir_tempo = 0
	if dummy:
		Card.create_by_id("hemotoxins").execute(dummy, stats, dm, 0.0, 0.0, bm)
		_check(dummy.poison_stacks > 0, "without Elixir it poisons again")
		dummy.poison_stacks = 0

	print("-- Empower reaches hard-coded attacks --")
	var trip_plain := Card.create_trip()
	trip_plain.execute(dummy, stats, dm, 0.0, 0.0, null)
	var trip_emp := Card.create_trip()
	trip_emp.draw_empowered = true
	trip_emp.execute(dummy, stats, dm, 0.0, 0.0, null)
	_check(trip_emp.last_damage_dealt >= trip_plain.last_damage_dealt + 3, "Trip gains Empower's +3 (%d vs %d)" % [trip_emp.last_damage_dealt, trip_plain.last_damage_dealt])
	_check(trip_emp.bonus_damage == 0, "the +3 does not stick to the card")
	if dummy:
		dummy.tripped_tempo = 0

	print("-- Parry: 10% physical, one attack --")
	bm.remove_buff(Buff.BuffType.BRACE)
	var parry_brace := Buff.create_brace(10, 1, "Parry")
	parry_brace.damage_type = DamageTypes.Type.PHYSICAL
	bm.apply_buff(parry_brace)
	_check(bm.calculate_damage_reduction(100, DamageTypes.Type.FIRE) == 100, "a fire hit passes the physical brace")
	_check(bm.calculate_damage_reduction(100, DamageTypes.Type.PHYSICAL) == 90, "a physical hit is cut 10%")
	_check(not bm.has_buff(Buff.BuffType.BRACE), "…and the brace is spent")

	print("-- Poke: half scaling --")
	var poke := Card.create_poke()
	poke.execute(dummy, stats, dm, 0.0, 0.0, null)
	var full: int = stats.get_effective_physical_damage(2)
	_check(poke.last_damage_dealt == 2 + floori((full - 2) / 2.0), "Poke = 2 + half the modifiers (%d)" % poke.last_damage_dealt)

	print("-- Smith thy Soul --")
	stats.current_armor = 0
	stats.current_health = 60
	stats.current_mana = 40.0
	bm.remove_buff(Buff.BuffType.BOLSTER)
	stats.equipment_defense_card_block = 0
	Card.create_smith_thy_soul().execute(null, stats, dm, 0.0, 0.0, null)
	_check(stats.current_armor == 5, "((60 + 40) / 2) / 10 = 5 armor (got %d)" % stats.current_armor)
	stats.current_health = stats.max_health

	print("-- Self Infliction: timed stats --")
	var str0: int = stats.base_strength
	var det0: int = stats.get_temp_determination_bonus()
	Card.create_self_infliction().execute(null, stats, dm, 0.0, 0.0, bm)
	_check(stats.base_strength == str0, "no permanent STR")
	_check(stats.get_temp_determination_bonus() == det0 + 5, "+5 DET on a timer")
	stats.current_health = stats.max_health

	print("-- Bloodlust: Strengthen on the clock --")
	bm.remove_buff(Buff.BuffType.STRENGTHEN)
	Card.create_bloodlust().execute(null, stats, dm, 0.0, 0.0, bm)
	_check(bm.consume_strengthen() == 3 and bm.consume_strengthen() == 3 and bm.consume_strengthen() == 3 \
		and bm.consume_strengthen() == 3, "+3 on every attack while it lasts")
	bm.advance_time(20)
	_check(bm.get_strengthen_bonus() == 0, "gone after 20 tempo")
	dbm.clear_all_debuffs()

	print("-- Healthy Bliss fires as an instant --")
	dm.hand.clear()
	var bliss := Card.create_healthy_bliss()
	dm.hand.append(bliss)
	_check(dm.fire_reaction(bliss) and dm.discard_pile.has(bliss), "fire_reaction discards the chosen instant")

	print("-- Bottomless Quiver fills the Manifest zone --")
	var om = main.overflow_manager
	om.manifest_zone.clear()
	var q_eff := OverflowEffect.create_quiver(5, "Test")
	om.add_overflow_effect(q_eff)
	var q_attack := Card.create_slash()
	om._process_quiver(q_attack, q_eff)
	om._process_quiver(Card.create_block(), q_eff)
	_check(om.manifest_zone.size() == 1 and om.manifest_zone[0]["manifest_id"] == "quiver_card"
		and om.manifest_zone[0]["card"] == q_attack, "attack overflow goes to the Manifest zone")
	_check(q_eff.charges == 3, "every overflowed card spends a charge")
	_check(om.remove_manifest_card(q_attack) and om.manifest_zone.is_empty(), "played out of the zone")
	om.remove_overflow_effect(q_eff)

	print("-- Misery Loves Company spreads every debuff --")
	if enemies.size() >= 2:
		var e1: Enemy = enemies[0]
		var e2: Enemy = enemies[1]
		e1.weaken_stacks = 3
		e1.apply_debuff("root", 10)
		e2.weaken_stacks = 0
		main._misery_active = true
		main._apply_misery_spread([e1, e2])
		_check(e2.weaken_stacks == 3, "Weaken spread (not just the four DoTs)")
		_check(e2.rooted_tempo >= 10, "timed debuffs spread too")
		e1.weaken_stacks = 0
		e2.weaken_stacks = 0
		e1.rooted_tempo = 0
		e2.rooted_tempo = 0

	print("-- Sky Attack uses the discarded card's damage --")
	dm.hand.clear()
	var sa := Card.create_sky_attack()
	var fodder := Card.create_slash()
	dm.hand.append(sa)
	dm.hand.append(fodder)
	sa.picked_card = fodder
	sa.execute(dummy, stats, dm, 0.0, 0.0, null)
	_check(sa.last_damage_dealt >= 10 and dm.discard_pile.has(fodder), "discarding a 10-damage card fires for 10+ (%d)" % sa.last_damage_dealt)
	var sa2 := Card.create_sky_attack()
	var dud := Card.create_draw()
	dm.hand.append(dud)
	sa2.picked_card = dud
	sa2.execute(dummy, stats, dm, 0.0, 0.0, null)
	_check(sa2.last_damage_dealt == 0, "a card with no damage makes the leap whiff")
	dm.hand.clear()

	print("-- Adrenaline Shot: +3 and +2 on different cards --")
	var a1 := Card.create_slash()
	var a2 := Card.create_block()
	dm.hand.append(a1)
	dm.hand.append(a2)
	main._adrenaline_delayed(dm)
	var cuts := [a1.temp_hand_tempo_reduction, a2.temp_hand_tempo_reduction]
	cuts.sort()
	_check(cuts == [-3, -2], "one card +3, the other +2 (%s)" % str(cuts))
	dm.hand.clear()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
