extends SceneTree

## Brad and Cory passives after the design pass on the audit: In the Trenches
## charges return one by one, The Way of the Plate really refunds tempo, a
## tied Ancestral Aid hand does nothing, Redemption arms only on Brad's own
## heals and adds to Enlightened, Life Steal covers passive hits and the auto
## attack, Solemn Independence is a hit modifier that blocks every ally heal,
## Self Reliance cuts a card's cost instead of refunding mana, Eat is a hit
## modifier on direct hits only, and Territorial Death fires when Cory walks.
## Run: godot --headless --path . --script tests/test_passive_feedback.gd

var failures := 0
var main = null

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _grant(stats, id: String, level: int = 15) -> void:
	stats.add_skill_tree_passive(id)
	stats.passive_levels[id] = level

func _initialize() -> void:
	print("=== Passive feedback test ===")
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
	var pt = main.progression_triggers
	# Solemn Independence needs three enemies close by: the dojo has two
	# dummies, so stand up a third.
	main.enemy_spawner.spawn_enemy(Enemy.EnemyType.DUMMY, main.grid_manager.grid_to_world(main.grid_manager.world_to_grid(main.player.position) + Vector2i(3, 3)))
	var dummies: Array = main.enemy_spawner.get_living_enemies()
	_check(dummies.size() >= 3, "three dummies stand ready (%d)" % dummies.size())
	var dummy: Enemy = dummies[0]
	# Hits in these checks must not be modified by passives the earlier
	# sections granted: each section clears what it set.

	_test_in_the_trenches(stats, pt, dummy)
	_test_way_of_the_plate(stats, pt)
	_test_ancestral_tie(stats, pt)
	_test_redemption(stats, pt)
	_test_life_steal(stats, pt, dummy)
	_test_solemn(stats, pt, dummies)
	_test_self_reliance_cost(stats, pt)
	_test_eat(stats, pt, dummy)
	_test_territorial_walk(stats, pt, dummy)

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_in_the_trenches(stats, pt, dummy: Enemy) -> void:
	print("-- In the Trenches: charges return one by one --")
	_grant(stats, "in_the_trenches")
	var tm = main.tempo_manager
	tm.global_tempo = 50
	stats.st_itt_charges = 2
	stats.st_itt_spent = []
	pt._trigger_skill_tree_brad_itt_on_enter(dummy)
	_check(stats.st_itt_charges == 1 and stats.st_itt_spent == [50], "the free attack spends one charge and stamps it")
	tm.global_tempo = 56
	pt._trigger_skill_tree_brad_itt_on_enter(dummy)
	_check(stats.st_itt_charges == 0 and stats.st_itt_spent == [50, 56], "the second charge is spent six tempo later")
	tm.global_tempo = 60
	pt._itt_try_refresh_charges(stats)
	_check(stats.st_itt_charges == 1 and stats.st_itt_spent == [56], "ten tempo after the first spend, that charge alone is back")
	tm.global_tempo = 66
	pt._itt_try_refresh_charges(stats)
	_check(stats.st_itt_charges == 2 and stats.st_itt_spent.is_empty(), "the second returns on its own clock")
	stats.skill_tree_passives.erase("in_the_trenches")

func _test_way_of_the_plate(stats, pt) -> void:
	print("-- The Way of the Plate refunds tempo --")
	_grant(stats, "the_way_of_the_plate")  # rank 15: every 2nd defense card
	var tm = main.tempo_manager
	tm.global_tempo = 20
	tm.current_tempo = 3
	stats.st_defense_cards_played = 1
	stats.current_mana = 10
	pt._trigger_skill_tree_brad_on_defense_card_play(Card.create_harden())
	_check(tm.global_tempo == 19 and tm.current_tempo == 2, "the refund winds the clock back one tempo (%d global, %d in cycle)" % [tm.global_tempo, tm.current_tempo])
	_check(stats.current_mana == 20, "…and gives 10 mana back")
	tm.current_tempo = 0
	stats.st_defense_cards_played = 1
	pt._trigger_skill_tree_brad_on_defense_card_play(Card.create_harden())
	_check(tm.current_tempo == 0 and tm.global_tempo == 18, "the cycle counter never goes below zero")
	stats.skill_tree_passives.erase("the_way_of_the_plate")

func _test_ancestral_tie(stats, pt) -> void:
	print("-- Ancestral Aid: a tied hand does nothing --")
	_grant(stats, "ancestral_aid")
	main.deck_manager.hand.clear()
	main.deck_manager.hand.append(Card.create_slash())
	main.deck_manager.hand.append(Card.create_harden())
	stats.current_health = 1
	stats.st_ancestral_cycle_counter = 4
	pt._trigger_skill_tree_brad_on_cycle()
	_check(stats.current_health == 1, "one attack and one defense in hand: no heal (%d/%d)" % [stats.current_health, stats.max_health])
	_check(stats.st_ancestral_cycle_counter == 0, "…though the five-cycle count still restarts")
	stats.skill_tree_passives.erase("ancestral_aid")

func _test_redemption(stats, pt) -> void:
	print("-- Redemption: Brad's own heals, on top of Enlightened --")
	_grant(stats, "redemption")
	var bm = main.player.get_buff_manager()
	for b in bm.buffs.duplicate():
		bm.remove_buff(b.buff_type)
	stats.st_redemption_crit = 0
	stats.current_health = 1
	stats.heal(5, true)
	pt._trigger_skill_tree_brad_on_heal()
	_check(stats.st_redemption_crit == 0, "a heal an ally gave him does not arm it")
	stats._ally_cast = true
	stats.heal(5)
	stats._ally_cast = false
	_check(stats.last_heal_from_ally, "a heal performed by an ally's card counts as an ally heal")
	stats.current_health = 1
	stats.heal(5)
	_check(not stats.last_heal_from_ally, "his own heal does not")
	_check(stats.st_redemption_crit == 15, "…and arms 15% for the next attack")
	bm.apply_buff(Buff.create_enlightened(10, 3, "Elsewhere"))
	_check(bm.get_buff(Buff.BuffType.ENLIGHTENED).value == 10 and stats.st_redemption_crit == 15,
		"it sits beside an Enlightened buff instead of merging into it")
	var crits := 0
	for _i in range(40):
		stats.st_redemption_crit = 90
		bm.remove_buff(Buff.BuffType.ENLIGHTENED)
		bm.apply_buff(Buff.create_enlightened(10, 3, "Elsewhere"))
		if bm.roll_crit():
			crits += 1
	_check(crits == 40, "10%% Enlightened + 90%% Redemption always crits (%d/40)" % crits)
	_check(stats.st_redemption_crit == 0, "the roll spends it")
	bm.remove_buff(Buff.BuffType.ENLIGHTENED)
	stats.skill_tree_passives.erase("redemption")

func _test_life_steal(stats, pt, dummy: Enemy) -> void:
	print("-- Life Steal: passive hits and the auto attack --")
	_grant(stats, "life_steal")  # rank 15: 8%
	var bm = main.player.get_buff_manager()
	stats.current_health = 1
	var hp0: int = stats.current_health
	pt._brad_passive_hit(dummy, 50)
	_check(stats.current_health >= hp0 + 4, "a passive-generated 50 damage hit steals at least 4 (%d → %d)" % [hp0, stats.current_health])
	hp0 = stats.current_health
	var gm = main.grid_manager
	dummy.position = gm.grid_to_world(gm.world_to_grid(main.player.position) + Vector2i(1, 0))
	dummy.target_position = dummy.position
	bm.apply_buff(Buff.create_steady("test"))
	var dummy_hp: int = dummy.current_health
	main._execute_basic_attack(dummy)
	_check(dummy.current_health < dummy_hp, "a Steady auto attack lands at once")
	_check(stats.current_health > hp0, "…and life steals (%d → %d)" % [hp0, stats.current_health])
	stats.skill_tree_passives.erase("life_steal")

func _test_solemn(stats, pt, dummies: Array) -> void:
	print("-- Solemn Independence: a hit modifier, no ally heals at all --")
	_grant(stats, "solemn_independence")  # rank 15: +12%
	var gm = main.grid_manager
	var pcell: Vector2i = gm.world_to_grid(main.player.position)
	var offsets := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]
	for i in range(mini(3, dummies.size())):
		dummies[i].position = gm.grid_to_world(pcell + offsets[i])
		dummies[i].target_position = dummies[i].position
	pt.refresh_solemn()
	_check(stats.solemn_active, "three dummies beside him: surrounded")
	var a: Enemy = dummies[0]
	var b: Enemy = dummies[1]
	var hp_a: int = a.current_health
	var hp_b: int = b.current_health
	a.take_damage(100, true)
	b.take_damage(100, true)
	_check(hp_a - a.current_health == 112 and hp_b - b.current_health == 112,
		"every enemy hit takes +12%% (%d and %d)" % [hp_a - a.current_health, hp_b - b.current_health])
	stats.current_health = 1
	var hp0: int = stats.current_health
	stats.heal(10, true)
	_check(stats.current_health == hp0, "an ally aura heal is refused")
	stats._ally_cast = true
	stats.heal(10)
	stats._ally_cast = false
	_check(stats.current_health == hp0, "an ally's heal card is refused too")
	stats.heal(10)
	_check(stats.current_health > hp0, "his own heal still lands")
	for i in range(mini(3, dummies.size())):
		dummies[i].position = gm.grid_to_world(pcell + Vector2i(6 + i, 6))
		dummies[i].target_position = dummies[i].position
	main._on_player_move_completed()
	_check(not stats.solemn_active, "stepping away (or them leaving) clears it on the move, not at the next cycle")
	var c: Enemy = dummies[2]
	var hp_c: int = c.current_health
	c.take_damage(100, true)
	_check(hp_c - c.current_health == 100, "…and hits are plain again")
	stats.skill_tree_passives.erase("solemn_independence")

func _test_self_reliance_cost(stats, pt) -> void:
	print("-- Self Reliance: a cost cut on a card in hand --")
	_grant(stats, "self_reliance")
	_grant(stats, "energy_barrier")
	stats.st_cards_this_cycle.clear()
	stats.st_self_reliance_discount = false
	stats.st_mana_gain_counter = 0
	main.deck_manager.hand.clear()
	var held := Card.create_peshtigos_kiss()
	main.deck_manager.hand.append(held)
	var mana0: int = stats.current_mana
	for _i in range(3):
		pt._trigger_skill_tree_cory_on_card_play(Card.create_slash())
	_check(held.temp_mana_discount == 60, "the held 60m card is cut by its whole cost at rank 15 (got %d)" % held.temp_mana_discount)
	_check(stats.current_mana == mana0 and stats.st_mana_gain_counter == 0, "no mana was gained, so Energy Barrier did not count it")
	var hand_cards: int = main.deck_manager.hand.size()
	_check(hand_cards == 1 and held in main.deck_manager.hand, "the discounted card stays in hand")
	main.deck_manager.hand.clear()
	stats.skill_tree_passives.erase("self_reliance")
	stats.skill_tree_passives.erase("energy_barrier")

func _test_eat(stats, pt, dummy: Enemy) -> void:
	print("-- Eat: a modifier on direct hits only --")
	_grant(stats, "eat")  # rank 15: threshold 39%
	dummy.current_health = maxi(1, dummy.max_health / 10)  # 10%: 29 points under
	var hp0: int = dummy.current_health
	dummy.take_damage(1, true)
	_check(hp0 - dummy.current_health == 1, "a 1 damage hit floors to 1 (%d)" % (hp0 - dummy.current_health))
	dummy.current_health = dummy.max_health
	dummy.current_health = maxi(1, dummy.max_health / 10)
	hp0 = dummy.current_health
	var pre_pct := 100.0 * float(hp0) / float(dummy.max_health)
	var expected: int = floori(10 * (1.0 + (39.0 - pre_pct) / 100.0))
	dummy.current_health = dummy.max_health
	dummy.take_damage(10, true)
	_check(dummy.max_health - dummy.current_health == 10, "at full health a 10 damage hit is 10")
	dummy.current_health = hp0
	dummy.take_damage(10, true)
	_check(hp0 - dummy.current_health == expected, "at %d%% health the same hit is %d (%d)" % [roundi(pre_pct), expected, hp0 - dummy.current_health])
	dummy.current_health = hp0
	dummy.take_damage(10, false)
	_check(hp0 - dummy.current_health == 10, "a DoT tick (from_player = false) is not boosted")
	dummy.current_health = dummy.max_health
	stats.skill_tree_passives.erase("eat")

func _test_territorial_walk(stats, pt, dummy: Enemy) -> void:
	print("-- Territorial Death: Cory walking up counts --")
	_grant(stats, "territorial_death")
	var gm = main.grid_manager
	var pcell: Vector2i = gm.world_to_grid(main.player.position)
	dummy.position = gm.grid_to_world(pcell + Vector2i(1, 0))
	dummy.target_position = dummy.position
	dummy.slow_stacks = 1
	main._enemy_melee_state[dummy.get_instance_id()] = false
	stats.st_territorial_last_tempo = -100
	main._on_player_move_completed()
	_check(dummy.slow_stacks == 2, "ending a move beside a slowed enemy re-applies a stack (%d)" % dummy.slow_stacks)
	stats.st_territorial_last_tempo = -100
	main.player.position = gm.grid_to_world(pcell + Vector2i(-5, 0))
	main._on_player_move_completed()
	_check(dummy.slow_stacks == 3, "walking away re-applies one too (%d)" % dummy.slow_stacks)
	main.player.position = gm.grid_to_world(pcell)
	stats.skill_tree_passives.erase("territorial_death")
