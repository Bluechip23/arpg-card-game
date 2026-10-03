extends SceneTree

## Jeremy and Ryan passives after the design pass: Arcane Overflow primes
## when a spell's wind-up begins and is spent once at play; I Heal You
## reaches every ally within 3 cells; Magic Barrier goes up before the hit;
## Harnessed Power scales damage, armor and healing at resolve; Whispers'
## cooldown runs from the grant and marks summons; Seance raises a real
## summon that answers its killer; Kinetic Armor is strictly more than;
## Haunted Rebuke taxes the next action by exactly 3; Keep Them Guessing
## runs on tempo; From the Hip's tempo cut ignores mana; Surprise Opener's
## first-source needs an untouched enemy.
## Run: godot --headless --path . --script tests/test_passive_feedback2.gd

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
	print("=== Passive feedback test 2 (Jeremy / Ryan) ===")
	_run()

func _run() -> void:
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	main = packed.instantiate()
	main.set("starting_character", CharacterData.create_jeremy())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(6):
		await process_frame
	var stats = main.player.get_stats()
	var pt = main.progression_triggers
	var dummies: Array = main.enemy_spawner.get_living_enemies()
	_check(dummies.size() >= 2, "the dojo has dummies (%d)" % dummies.size())
	var dummy: Enemy = dummies[0]
	stats.max_health = maxi(stats.max_health, 100)

	_test_arcane_overflow(stats, pt)
	_test_i_heal_you(stats, pt)
	_test_mages_favor(stats, pt, dummy)
	_test_harnessed(stats, pt, dummy)
	_test_whispers(stats, pt)
	_test_seance(stats, pt, dummy)
	_test_kinetic(stats, pt, dummy)
	_test_haunted(stats, pt, dummy)
	_test_keep_them_guessing(stats, pt)
	_test_from_the_hip(stats, pt)
	_test_surprise_opener(stats, pt, dummy)

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _spell(points: bool = false) -> Card:
	var c := Card.create_spark()
	c.school = Card.CardSchool.SPELL
	if points:
		c.target_types = ["point"]
	return c

func _test_arcane_overflow(stats, pt) -> void:
	print("-- Arcane Overflow: primes when the wind-up begins --")
	_grant(stats, "arcane_overflow")
	stats.st_arcane_overflow_discount = false
	stats.st_arcane_overflow_last_tempo = -100
	stats.current_mana = 30
	var spell := _spell()
	pt._trigger_skill_tree_jeremy_on_card_play(spell, null)
	_check(not stats.st_arcane_overflow_discount, "resolving a spell no longer primes it")
	pt.on_card_ticks_started(spell)
	_check(not stats.st_arcane_overflow_discount, "a wind-up beginning with mana left does not prime")
	stats.current_mana = 0
	pt.on_card_ticks_started(spell)
	_check(stats.st_arcane_overflow_discount, "a wind-up beginning at 0 mana primes the next spell")
	stats.st_arcane_overflow_discount = false
	var tm = main.tempo_manager
	var seen: Array = []
	tm.card_started.connect(func(c): seen.append(c))
	var carrier := _spell()
	tm.start_card_ticks(carrier, 3, 1)
	tm._process_one_tick()
	_check(seen.size() == 1 and seen[0] == carrier, "the tempo manager announces a card's first tick")
	tm._process_one_tick()
	_check(seen.size() == 1, "…and only its first")
	tm._active_cards.clear()
	stats.skill_tree_passives.erase("arcane_overflow")

func _test_i_heal_you(stats, pt) -> void:
	print("-- I Heal You: every ally within 3 cells --")
	_grant(stats, "i_heal_you")
	var gm = main.grid_manager
	var pcell: Vector2i = gm.world_to_grid(main.player.position)
	main._spawn_wolf()
	var near = main._wolves.back()
	near.position = gm.grid_to_world(pcell + Vector2i(2, 1))
	main._spawn_wolf()
	var far = main._wolves.back()
	far.position = gm.grid_to_world(pcell + Vector2i(5, 0))
	main._on_tempo_advanced(main.tempo_manager.global_tempo, 1)  # refresh the summons list
	near.health = 10
	far.health = 10
	var healed: int = pt._i_heal_you_pulse()
	_check(near.health == 13, "a wolf 3 cells away is healed 3 (%d)" % near.health)
	_check(far.health == 10, "a wolf 5 cells away is not")
	_check(healed >= 1, "the pulse reports what it healed (%d)" % healed)
	main._clear_wolves()
	stats.skill_tree_passives.erase("i_heal_you")

func _test_mages_favor(stats, pt, dummy: Enemy) -> void:
	print("-- A Mage's Favor: the barrier is up before the blow --")
	var dm = main.deck_manager
	dm.hand.clear()
	var barrier := Card.create_magic_barrier(10)
	_check(barrier.reaction_trigger == "on_incoming_attack", "Magic Barrier reacts to the incoming attack")
	dm.hand.append(barrier)
	stats.current_armor = 0
	stats.current_health = 50
	var gm = main.grid_manager
	dummy.position = gm.grid_to_world(gm.world_to_grid(main.player.position) + Vector2i(1, 0))
	dummy.target_position = dummy.position
	dummy.attack_damage = 6
	dummy._deal_damage_to_player(main.player, 6, "Attack")
	_check(not (barrier in dm.hand), "the barrier left the hand as the enemy swung")
	_check(stats.current_health == 50, "…and its 10 armor ate the 6 damage before it landed (hp %d, armor %d)" % [stats.current_health, stats.current_armor])
	stats.current_armor = 0

func _test_harnessed(stats, pt, dummy: Enemy) -> void:
	print("-- Harnessed Power: a multiplier on what the card produces --")
	_grant(stats, "harnessed_power")  # rank 15: +32%
	var dm = main.deck_manager
	dm.hand.clear()
	dm.hand.append(Card.create_slash())
	dm.hand.append(Card.create_harden())
	_check(is_equal_approx(pt._get_jeremy_harnessed_power_multiplier(), 1.32), "with the played card one of two in hand the multiplier is 1.32")
	dm.hand.append(Card.create_block())
	_check(is_equal_approx(pt._get_jeremy_harnessed_power_multiplier(), 1.0), "three in hand: no bonus")
	PlayerStats.harnessed_mult = 1.32
	stats.current_armor = 0
	stats.add_armor(10)
	_check(stats.current_armor >= 13, "armor gained while armed is scaled (10 → %d)" % stats.current_armor)
	stats.current_health = 1
	stats.heal(10)
	var healed_to: int = stats.current_health
	PlayerStats.harnessed_mult = 1.0
	stats.current_health = 1
	stats.heal(10)
	_check(healed_to > stats.current_health, "a heal while armed is bigger than the same heal unarmed (%d vs %d)" % [healed_to, stats.current_health])
	PlayerStats.harnessed_mult = 1.32
	var hp0: int = dummy.current_health
	dummy.take_damage(100, true)
	_check(hp0 - dummy.current_health == 132, "a direct hit is scaled (100 → %d)" % (hp0 - dummy.current_health))
	PlayerStats.harnessed_mult = 1.0
	dummy.current_health = dummy.max_health
	stats.current_armor = 0
	stats.skill_tree_passives.erase("harnessed_power")

func _test_whispers(stats, pt) -> void:
	print("-- Whispers of the Flock: cooldown from the grant, marks on summons --")
	_grant(stats, "whispers_of_the_flock")
	var dm = main.deck_manager
	dm.hand.clear()
	stats.st_whispers_active = false
	stats.st_whispers_cooldown = 0
	main._spawn_wolf()
	var wolf = main._wolves.back()
	main._on_tempo_advanced(main.tempo_manager.global_tempo, 1)
	_check(main._is_summon(wolf), "a wolf is a summon")
	pt._trigger_skill_tree_on_card_play(Card.create_healing_potion(), wolf)
	var mark: Card = null
	for c in dm.hand:
		if c.card_id == "shepherds_mark":
			mark = c
	_check(mark != null, "healing a summon with a card grants a Shepherd's Mark")
	_check(stats.st_whispers_cooldown == PassiveScaling.value("whispers_of_the_flock", "cooldown", 15), "…and the cooldown starts right then (%d)" % stats.st_whispers_cooldown)
	if mark:
		mark.execute(wolf, stats, dm, 0.0, 0.0, main.player.get_buff_manager())
		_check(wolf.shepherd_mark_caster == stats and wolf.shepherd_mark_tempo == 10, "the mark sits on the wolf for 10 tempo")
		stats.current_health = 50
		wolf.health = 5
		wolf.take_damage(50)
		_check(not wolf.is_dead and wolf.health == 1, "a lethal blow leaves the marked wolf at 1 HP")
		_check(wolf.armor == 19, "…with the rank-15 mark's 19 armor (%d)" % wolf.armor)
		_check(stats.current_health == 42, "…and Jeremy paid 8 (%d)" % stats.current_health)
	main._clear_wolves()
	dm.hand.clear()
	stats.skill_tree_passives.erase("whispers_of_the_flock")

func _test_seance(stats, pt, dummy: Enemy) -> void:
	print("-- Seance: a Specter summon on the aimed empty tile --")
	_grant(stats, "seance")  # rank 15: 33 HP
	var gm = main.grid_manager
	var pcell: Vector2i = gm.world_to_grid(main.player.position)
	var aim_cell: Vector2i = pcell + Vector2i(3, 0)
	dummy.position = gm.grid_to_world(pcell + Vector2i(6, 6))
	dummy.target_position = dummy.position
	var aim: Vector3 = gm.grid_to_world(aim_cell)
	pt._trigger_skill_tree_jeremy_on_card_play(_spell(true), main.player, aim)
	_check(main._specters.size() == 1, "a point-targeted spell at an empty tile raises one Specter")
	if main._specters.is_empty():
		return
	var sp = main._specters[0]
	_check(gm.world_to_grid(sp.position) == aim_cell, "…on that tile")
	_check(sp.health == 33 and sp.death_damage == 33, "rank 15: 33 HP, 33 death damage")
	pt._trigger_skill_tree_jeremy_on_card_play(_spell(true), main.player, aim)
	_check(main._specters.size() == 1, "the tile is no longer empty: no second Specter there")
	pt._trigger_skill_tree_jeremy_on_card_play(_spell(false), main.player, aim)
	_check(main._specters.size() == 1, "a spell without a point target raises nothing")
	main._on_tempo_advanced(main.tempo_manager.global_tempo, 1)
	_check(sp in main.enemy_spawner.summons, "enemies see it as a summon to target")
	# An enemy kills it: the killer takes its HP.
	dummy.position = gm.grid_to_world(aim_cell + Vector2i(1, 0))
	dummy.target_position = dummy.position
	dummy.attack_damage = 40
	var hp0: int = dummy.current_health
	dummy._deal_damage_to_player(sp, 40, "Attack")
	_check(sp.is_dead and main._specters.is_empty(), "a 40 damage hit destroys the 33 HP Specter")
	_check(hp0 - dummy.current_health == 33, "…and its killer takes 33 (%d)" % (hp0 - dummy.current_health))
	dummy.current_health = dummy.max_health
	var sp2 = main._spawn_specter(aim_cell, 10)
	main._update_specters(25)
	_check(sp2.is_dead and main._specters.is_empty(), "a Specter fades after 25 tempo")
	stats.skill_tree_passives.erase("seance")

func _test_kinetic(stats, pt, dummy: Enemy) -> void:
	print("-- Kinetic Armor: strictly more than --")
	_grant(stats, "kinetic_armor")  # rank 15: 16 tempo
	var gm = main.grid_manager
	dummy.position = gm.grid_to_world(gm.world_to_grid(main.player.position) + Vector2i(1, 0))
	dummy.target_position = dummy.position
	dummy.shock_stacks = 0
	main.deck_manager.hand.clear()
	main.deck_manager.hand.append(Card.create_harden())
	stats.current_armor = 5
	stats.st_kinetic_armor_tempo = 0
	stats.st_kinetic_armor_triggered = false
	pt._trigger_skill_tree_on_tempo(16)
	_check(dummy.shock_stacks == 0, "at exactly 16 tempo of armor nothing fires")
	pt._trigger_skill_tree_on_tempo(1)
	_check(dummy.shock_stacks >= 1, "the 17th tempo fires it (%d shock)" % dummy.shock_stacks)
	dummy.shock_stacks = 0
	stats.current_armor = 0
	stats.skill_tree_passives.erase("kinetic_armor")

func _test_haunted(stats, pt, dummy: Enemy) -> void:
	print("-- Haunted Rebuke: exactly +3 on the next action --")
	_grant(stats, "haunted_rebuke")
	stats.st_haunted_rebuke_cooldown = 0
	main.deck_manager.hand.clear()
	for _i in range(3):
		main.deck_manager.hand.append(Card.create_block())
	dummy.next_action_tempo_tax = 0
	pt._trigger_skill_tree_jeremy_on_enemy_attacked(dummy)
	_check(dummy.next_action_tempo_tax == 3, "the enemy's next action is taxed 3 tempo")
	var action := {"name": "attack", "tempo": 4}
	var base: int = dummy.windup_of(action)
	_check(dummy._effective_cost(action) == base + 3, "its wind-up reads base + 3 (%d)" % dummy._effective_cost(action))
	dummy._consume_fire_taxes(action)
	_check(dummy.next_action_tempo_tax == 0 and dummy._effective_cost(action) == base, "firing the action spends the tax")
	main.deck_manager.hand.clear()
	stats.skill_tree_passives.erase("haunted_rebuke")

func _test_keep_them_guessing(stats, pt) -> void:
	print("-- Keep Them Guessing: 5 tempo, not a cycle --")
	var dm = main.deck_manager
	dm.hand.clear()
	var slash := Card.create_slash()
	dm.hand.append(slash)
	slash.apply_temp_mod(0, 2, 0)
	dm.tick_temp_mods(2)
	_check(slash.temp_hand_tempo_reduction == 2 and slash.temp_mod_tempo_left == 3, "two tempo in, the cut still holds")
	dm.tick_temp_mods(3)
	_check(slash.temp_hand_tempo_reduction == 0 and slash.temp_mod_tempo_left == 0, "it runs out on its fifth tempo")
	dm.hand.clear()

func _test_from_the_hip(stats, pt) -> void:
	print("-- From the Hip: the tempo cut needs no mana cost --")
	_grant(stats, "from_the_hip")  # rank 15: -75m / -2t
	stats.st_from_hip_card = null
	var free_attack := Card.create_slash()
	free_attack.mana_cost = 0
	free_attack.tempo_cost = 3
	main.deck_manager.hand.append(free_attack)
	pt._trigger_skill_tree_on_draw(free_attack)
	_check(free_attack.tempo_cost == 1 and free_attack.mana_cost == 0, "a 0-mana attack drawn at rank 15 still gets -2 tempo (%d)" % free_attack.tempo_cost)
	var paid := Card.create_slash()
	paid.mana_cost = 20
	paid.tempo_cost = 3
	pt._trigger_skill_tree_on_draw(paid)
	_check(free_attack.tempo_cost == 3, "drawing the next attack restores the previous card")
	_check(paid.mana_cost == 0 and paid.tempo_cost == 1, "a 20m attack is cut to 0m / 1t")
	main.deck_manager.hand.clear()
	stats.st_from_hip_card = null
	stats.skill_tree_passives.erase("from_the_hip")

func _test_surprise_opener(stats, pt, dummy: Enemy) -> void:
	print("-- Surprise Opener: first source means untouched --")
	_grant(stats, "surprise_opener")  # rank 15: 8 / 15 / 17
	stats.st_enemy_first_strikes.clear()
	dummy.current_health = dummy.max_health
	dummy.current_armor = 0
	dummy.has_been_damaged = false
	var card := Card.create_slash()
	pt.arm_pre_attack_passives(card, dummy)
	var hp0: int = dummy.current_health
	pt._trigger_skill_tree_on_attack(card, dummy)
	_check(hp0 - dummy.current_health == 8 + 15 + 17, "an untouched, unarmored enemy takes the full 40 bonus (%d)" % (hp0 - dummy.current_health))
	stats.st_enemy_first_strikes.clear()
	dummy.current_health = dummy.max_health
	dummy.take_damage(1, false)   # a DoT tick: healed back to full afterwards
	dummy.current_health = dummy.max_health
	_check(dummy.has_been_damaged, "a 1 damage tick marks the enemy as damaged even at full health")
	pt.arm_pre_attack_passives(card, dummy)
	hp0 = dummy.current_health
	pt._trigger_skill_tree_on_attack(card, dummy)
	_check(hp0 - dummy.current_health == 8 + 15, "…so the first-source bonus is gone: 23 (%d)" % (hp0 - dummy.current_health))
	dummy.current_health = dummy.max_health
	stats.skill_tree_passives.erase("surprise_opener")
