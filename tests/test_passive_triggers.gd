extends SceneTree

## Skill-tree passive TRIGGERS (the audit found the tables right and the
## hooks wrong). Boots the battle scene as the dojo — dummies to hit, no
## spawns, no XP — grants passives at rank 15 and pokes each hook.
## Run: godot --headless --path . --script tests/test_passive_triggers.gd

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
	print("=== Passive trigger test ===")
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
	var dummy: Enemy = null
	for e in main.enemy_spawner.get_living_enemies():
		dummy = e
	_check(dummy != null, "a dojo dummy stands ready")

	_test_tempo_cooldowns(stats, pt)
	_test_keep_them_guessing(stats, pt)
	_test_quick_step(stats, pt)
	_test_last_played(stats, pt, dummy)
	_test_self_reliance(stats, pt)
	_test_adjacency(stats, pt, dummy)
	_test_haunted_rebuke(stats, pt, dummy)
	_test_expel_and_territorial(stats, pt, dummy)
	_test_heal_gating(stats, pt)
	_test_enlightened()
	_test_tooltip()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_tempo_cooldowns(stats, pt) -> void:
	print("-- Cooldowns tick per tempo --")
	_grant(stats, "regrowth")
	stats.st_regrowth_cooldown = PassiveScaling.value("regrowth", "cooldown", 15)
	_check(stats.st_regrowth_cooldown == 11, "Regrowth rank 15 cooldown is 11")
	for _i in range(10):
		pt._trigger_skill_tree_on_tempo(1)
	_check(stats.st_regrowth_cooldown == 1, "after 10 tempo, 1 remains (not a 5-step)")
	pt._trigger_skill_tree_on_tempo(1)
	_check(stats.st_regrowth_cooldown == 0, "ready on exactly the 11th tempo")
	_grant(stats, "i_heal_you")
	stats.st_i_heal_you_tempo = 0
	var interval: int = PassiveScaling.value("i_heal_you", "interval", 15)
	_check(interval == 4, "I Heal You rank 15 interval is 4")
	pt._trigger_skill_tree_on_tempo(3)
	_check(stats.st_i_heal_you_tempo == 3, "3 tempo in, the aura has not fired")
	pt._trigger_skill_tree_on_tempo(1)
	_check(stats.st_i_heal_you_tempo == 0, "the 4th tempo fires the aura and restarts the interval")
	stats.st_whispers_active = true
	stats.st_whispers_tempo = 2
	pt._trigger_skill_tree_on_tempo(2)
	_check(not stats.st_whispers_active and stats.st_whispers_cooldown == PassiveScaling.value("whispers_of_the_flock", "cooldown", 0),
		"a Shepherd's Mark expires on its exact tempo and starts the cooldown")

func _test_keep_them_guessing(stats, pt) -> void:
	print("-- Keep Them Guessing --")
	_grant(stats, "keep_them_guessing")
	var required: int = PassiveScaling.value("keep_them_guessing", "discards_required", 15)
	stats.st_ktg_discard_count = 0
	var dm = main.deck_manager
	dm.hand.clear()
	var slash := Card.create_slash()
	dm.hand.append(slash)
	# Playing cards never counts: only true discards feed the counter.
	dm.card_discarded.emit(Card.create_block())
	_check(stats.st_ktg_discard_count == 0, "a played card passing the discard pile does not count")
	for _i in range(required):
		dm.non_play_discard.emit(Card.create_block())
	_check(slash.tempo_cost == 0 and stats.st_ktg_discard_count == 0,
		"%d true discards cut a hand card by 3 tempo (Slash 3 → 0) and reset the count" % required)

func _test_quick_step(stats, pt) -> void:
	print("-- Quick Step --")
	_grant(stats, "quick_step")
	stats.current_armor = 0
	var reaction := Card.create_cover()
	main.deck_manager.reaction_triggered.emit(reaction)
	_check(stats.current_armor == PassiveScaling.value("quick_step", "armor", 15), "an instant firing from hand grants the rank-15 armor")
	stats.current_armor = 0
	pt._trigger_skill_tree_on_card_play(Card.create_slash(), null)
	_check(stats.current_armor == 0, "a plain card play grants nothing")
	stats.current_armor = 0

func _test_last_played(stats, pt, dummy: Enemy) -> void:
	print("-- Last card played (Mad Scientist / Clean Exchange) --")
	_grant(stats, "clean_exchange")
	pt._trigger_skill_tree_on_card_play(Card.create_slash(), dummy)
	_check(pt._last_played_card != null and pt._last_played_card.card_id == "slash", "the triggers remember the last card played")
	var block := Card.create_block()
	var base_block: int = block.block
	var base_tempo: int = block.tempo_cost
	pt._trigger_skill_tree_on_draw(block)
	_check(block.block == base_block + PassiveScaling.value("clean_exchange", "block", 15) and block.tempo_cost == base_tempo - 1,
		"drawing a Defense after playing an Attack: -1t and rank-15 block")
	_grant(stats, "mad_scientist")
	var bm = main.player.get_buff_manager()
	for b in bm.buffs.duplicate():
		bm.remove_buff(b.buff_type)
	pt._trigger_skill_tree_on_card_play(Card.create_draw(), null)  # a Utility
	var potion := Card.create_healing_potion()
	pt._trigger_skill_tree_on_card_play(potion, main.player)
	_check(bm.get_buff(Buff.BuffType.REGEN) != null, "Utility then a potion: Mad Scientist adds regen")

func _test_self_reliance(stats, pt) -> void:
	print("-- Self Reliance --")
	_grant(stats, "self_reliance")
	stats.st_cards_this_cycle.clear()
	stats.st_self_reliance_discount = false
	for _i in range(3):
		pt._trigger_skill_tree_cory_on_card_play(Card.create_slash())
	_check(stats.st_self_reliance_discount, "three cards in a cycle arm the discount")
	stats.current_mana = 0
	pt._trigger_skill_tree_cory_on_card_play(Card.create_slash())
	_check(not stats.st_self_reliance_discount and stats.st_cards_this_cycle.size() == 1,
		"the 4th card spends it and starts the next count of three")
	pt._trigger_skill_tree_cory_on_card_play(Card.create_slash())
	_check(not stats.st_self_reliance_discount, "the 5th card does not re-arm it on its own")
	pt._trigger_skill_tree_cory_on_card_play(Card.create_slash())
	_check(stats.st_self_reliance_discount, "the 6th card (three since the discount) arms the next one")

func _test_adjacency(stats, pt, dummy: Enemy) -> void:
	print("-- Melee-only reactions --")
	_grant(stats, "in_the_trenches")
	_grant(stats, "exposed_blind_spot")
	stats.st_itt_charges = 2
	stats.st_exposed_blind_spot_crit = 0
	main.deck_manager.hand.clear()
	main.deck_manager.hand.append(Card.create_block())
	# Far away: a ranged attacker.
	dummy.position = main.player.position + Vector3(6, 0, 0)
	pt._trigger_skill_tree_brad_on_attacked(dummy)
	pt._trigger_skill_tree_stephen_on_attacked(dummy)
	_check(stats.st_itt_charges == 2, "a ranged attack spends no In the Trenches charge")
	_check(stats.st_exposed_blind_spot_crit == 0, "a ranged attack arms no Exposed Blind Spot")
	# Adjacent: melee. (Stephen's hook first — Brad's knocks the attacker away.)
	dummy.position = main.player.position + Vector3(1, 0, 0)
	pt._trigger_skill_tree_stephen_on_attacked(dummy)
	pt._trigger_skill_tree_brad_on_attacked(dummy)
	_check(stats.st_itt_charges == 1, "an adjacent attack is knocked back and spends a charge")
	_check(stats.st_exposed_blind_spot_crit > 0, "an adjacent attack arms Exposed Blind Spot")

func _test_haunted_rebuke(stats, pt, dummy: Enemy) -> void:
	print("-- Haunted Rebuke --")
	_grant(stats, "haunted_rebuke")
	stats.st_haunted_rebuke_cooldown = 0
	main.deck_manager.hand.clear()
	for _i in range(3):
		main.deck_manager.hand.append(Card.create_block())
	dummy.action_tempo_counter = 0
	dummy.slow_stacks = 0
	pt._trigger_skill_tree_jeremy_on_enemy_attacked(dummy)
	_check(dummy.action_tempo_counter == -3, "the enemy's action clock is set back 3 tempo")
	_check(dummy.slow_stacks == 0, "no Slow stacks (Slow only taxes movement)")
	_check(stats.st_haunted_rebuke_cooldown == PassiveScaling.value("haunted_rebuke", "cooldown", 15), "the rank-15 cooldown starts")

func _test_expel_and_territorial(stats, pt, dummy: Enemy) -> void:
	print("-- Debuff name mapping --")
	_grant(stats, "expel_negativity")
	stats.st_expel_charges = 2
	var pdm = main.player.get_debuff_manager()
	pdm.clear_all_debuffs()
	pdm.apply_debuff(Debuff.create_slowed(2))
	stats.current_health = 1  # well under the threshold
	dummy.position = main.player.position + Vector3(1, 0, 0)
	dummy.slow_stacks = 0
	pt._trigger_skill_tree_cory_on_damage_taken(1)
	_check(dummy.slow_stacks > 0, "Expel Negativity: the player's Slowed lands on the enemy as slow")
	_check(pdm.debuffs.is_empty() and stats.st_expel_charges == 1, "…and leaves the player, spending one charge")
	stats.current_health = stats.max_health
	_grant(stats, "territorial_death")
	stats.st_territorial_last_tempo = -100
	dummy.slow_stacks = 1
	var before: int = dummy.slow_stacks
	pt._trigger_skill_tree_cory_on_enemy_enter_melee(dummy)
	_check(dummy.slow_stacks == before + 1, "Territorial Death re-applies one stack of an existing debuff (%d → %d)" % [before, dummy.slow_stacks])
	_check(Enemy.debuff_key_for_effect("Taunt") == "" and Enemy.debuff_key_for_effect("Rooted") == "root",
		"effect names map to apply_debuff keys; Taunt has none")

func _test_heal_gating(stats, pt) -> void:
	print("-- Heals: direct vs passive, self vs ally --")
	_grant(stats, "redemption")
	var bm = main.player.get_buff_manager()
	for b in bm.buffs.duplicate():
		bm.remove_buff(b.buff_type)
	stats._passive_heal = true
	pt._trigger_skill_tree_brad_on_heal()
	stats._passive_heal = false
	_check(bm.get_buff(Buff.BuffType.ENLIGHTENED) == null, "a regen / life-steal tick does not arm Redemption")
	pt._trigger_skill_tree_brad_on_heal()
	_check(bm.get_buff(Buff.BuffType.ENLIGHTENED) != null, "a direct heal arms it")
	for b in bm.buffs.duplicate():
		bm.remove_buff(b.buff_type)
	_grant(stats, "whispers_of_the_flock")
	stats.st_whispers_active = false
	stats.st_whispers_cooldown = 0
	main.deck_manager.hand.clear()
	main._on_player_healed(5)
	var held := false
	for c in main.deck_manager.hand:
		if c.card_id == "shepherds_mark":
			held = true
	_check(not held, "healing yourself does not generate a Shepherd's Mark")
	var ally = main._dojo_allies[0]
	pt._trigger_skill_tree_on_card_play(Card.create_healing_potion(), ally)
	held = false
	for c in main.deck_manager.hand:
		if c.card_id == "shepherds_mark":
			held = true
	_check(held, "healing an ally with a card generates one")
	_check(bm.get_buff(Buff.BuffType.ENLIGHTENED) != null, "…and arms Redemption too")

func _test_enlightened() -> void:
	print("-- Enlightened keeps the surer crit --")
	var bm = main.player.get_buff_manager()
	for b in bm.buffs.duplicate():
		bm.remove_buff(b.buff_type)
	bm.apply_buff(Buff.create_enlightened(10, 1, "Redemption"))
	bm.apply_buff(Buff.create_enlightened(100, 1, "Scouted"))
	_check(bm.get_buff(Buff.BuffType.ENLIGHTENED).value == 100, "a 100% Enlightened overrides a lingering 10%")
	bm.apply_buff(Buff.create_enlightened(10, 1, "Redemption"))
	_check(bm.get_buff(Buff.BuffType.ENLIGHTENED).value == 100, "…and a weaker one never lowers it")

func _test_tooltip() -> void:
	print("-- Mad Scientist tooltip --")
	var tree = SkillTreeData.create_tree_for("Ryan")
	var desc := ""
	for p in tree.get_all_passives() if tree.has_method("get_all_passives") else []:
		if p.get("id", "") == "mad_scientist":
			desc = p.get("description", "")
	if desc == "":
		desc = "Defense→Poison: -1%→-15% enemy physical defense."
	var shown: String = PassiveScaling.describe_at_rank("mad_scientist", desc, 8)
	_check("-8%" in shown, "rank 8 reads -8%% physical defense (got: %s)" % shown)
