extends SceneTree

## Stephen's passives after the design pass, and the Offensive rule they
## hang on: "offensive" is a rider (every Attack card, plus any card the
## sheet tags offensive), not "deals damage". Deadly and Eagle Eye read
## the rider (spells included) and Deadly covers the auto attack; Clean
## Exchange trades on it; Patience hands over Endured Tolerance as a draw
## (one per 5 Glut); Exposed Blind Spot keeps its fraction and only attacks spend it;
## Swing for the Fences counts every >4 tempo card; Skilled Momentum plays
## the card again in full; Lethal Resourcefulness is a real auto attack
## at the weapon's reach.
## Run: godot --headless --path . --script tests/test_passive_feedback3.gd

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
	print("=== Passive feedback test 3 (Stephen / offensive rider) ===")
	_run()

func _run() -> void:
	# The rules, not the timing: blows land at once (no hit wait for the
	# heroes' drawn attacks, test_hit_wait.gd covers it).
	TempoManager.preferred_swing_hold = 0
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	main = packed.instantiate()
	main.set("starting_character", CharacterData.create_stephen())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(6):
		await process_frame
	var stats = main.player.get_stats()
	var pt = main.progression_triggers
	var dummies: Array = main.enemy_spawner.get_living_enemies()
	_check(dummies.size() >= 2, "the dojo has two dummies (%d)" % dummies.size())
	stats.max_health = maxi(stats.max_health, 100)

	_test_offensive_rule()
	_test_deadly(stats, pt, dummies)
	_test_clean_exchange(stats, pt)
	_test_eagle_eye(stats, pt, dummies[0])
	_test_patience(stats, pt, dummies[0])
	_test_exposed_blind_spot(stats, pt, dummies[0])
	_test_swing(stats, pt, dummies[0])
	_test_skilled_momentum(stats, pt, dummies[0])
	_test_lethal(stats, pt, dummies[0])

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_offensive_rule() -> void:
	print("-- Offensive is a rider --")
	_check(Card.create_by_id("fireball").is_offensive(), "Fireball (an Attack-type spell) is offensive")
	_check(Card.create_by_id("slash").is_offensive(), "every Attack card is offensive")
	var vm := Card.create_by_id("volatile_mixture")
	_check(vm.base_damage > 0 and not vm.is_offensive(), "a damaging Utility without the tag is not offensive")
	var hl := Card.create_by_id("harness_lightning")
	_check(hl.has_keyword("offensive") and hl.is_offensive(), "a Utility the sheet tags offensive is")

func _place(gm, who, cell: Vector2i) -> void:
	who.position = gm.grid_to_world(cell)
	if "target_position" in who:
		who.target_position = who.position

func _test_deadly(stats, pt, dummies: Array) -> void:
	print("-- Deadly: offensive cards, the auto attack, grid distance --")
	_grant(stats, "deadly")  # rank 15: +16 damage
	var gm = main.grid_manager
	var pcell: Vector2i = gm.world_to_grid(main.player.position)
	var a: Enemy = dummies[0]
	var b: Enemy = dummies[1]
	_place(gm, a, pcell + Vector2i(1, 0))
	_place(gm, b, pcell + Vector2i(3, 1))   # 2 right and 1 down of a: 3 cells
	_check(pt._deadly_isolated(a), "an ally 3 cells away (diagonal (2,1)) leaves the target isolated")
	_place(gm, b, pcell + Vector2i(2, 1))   # 1 right and 1 down of a: 2 cells
	_check(not pt._deadly_isolated(a), "an ally 2 cells away keeps it company")
	_place(gm, b, pcell + Vector2i(6, 6))
	var spell := Card.create_by_id("fireball")
	_check(pt._trigger_skill_tree_stephen_on_attack(spell, a) >= 16, "an offensive spell on an isolated target gets the +16")
	var util := Card.create_by_id("volatile_mixture")
	_check(pt._trigger_skill_tree_stephen_on_attack(util, a) == 0, "a non-offensive utility gets nothing")
	# The auto attack: the Deadly bonus rides the swing.
	var bm = main.player.get_buff_manager()
	bm.apply_buff(Buff.create_steady("test"))
	var hp0: int = a.current_health
	var base: int = main._get_basic_attack_display_damage()
	main._execute_basic_attack(a)
	_check(hp0 - a.current_health >= base + 16, "the auto attack on an isolated target lands base + 16 (%d, base %d)" % [hp0 - a.current_health, base])
	a.current_health = a.max_health
	stats.skill_tree_passives.erase("deadly")

func _test_clean_exchange(stats, pt) -> void:
	print("-- Clean Exchange: the offensive rider --")
	_grant(stats, "clean_exchange")
	pt._last_played_card = Card.create_by_id("fireball")  # an offensive spell
	var drawn := Card.create_by_id("harden")
	main.deck_manager.hand.append(drawn)
	pt._trigger_skill_tree_on_draw(drawn)
	_check(drawn.temp_hand_tempo_reduction == 1 and drawn.temp_flat_block == 8, "a Defense drawn after an offensive spell gets -1t and a flat +8 block")
	main.deck_manager.tick_temp_mods(25)
	_check(drawn.temp_hand_tempo_reduction == 1 and drawn.temp_flat_block == 8, "...with no time limit: 25 tempo later it still rides the card")
	main.deck_manager.hand.erase(drawn)
	drawn.clear_temp_mods()
	_check(drawn.temp_hand_tempo_reduction == 0 and drawn.temp_flat_block == 0, "...and it ends when the card leaves the hand")
	pt._last_played_card = Card.create_by_id("harden")
	var atk := Card.create_by_id("slash")
	main.deck_manager.hand.append(atk)
	pt._trigger_skill_tree_on_draw(atk)
	_check(atk.temp_hand_tempo_reduction == 1 and atk.temp_flat_block == 8 and atk.block == 0, "an attack drawn after a Defense gets -1t and the same flat +8 block, its own block still 0")
	var gm = main.grid_manager
	var dummies: Array = main.enemy_spawner.get_living_enemies()
	_place(gm, dummies[0], gm.world_to_grid(main.player.position) + Vector2i(1, 0))
	stats.current_armor = 0
	var hp0: int = dummies[0].current_health
	main._pending_resolve_queue.append({"card": atk, "target": dummies[0], "owner_index": 0, "data": {}})
	main._resolve_queued_card(atk)
	_check(dummies[0].current_health < hp0 and stats.current_armor >= 8, "resolving it deals the damage and gains the 8 block once (%d armor)" % stats.current_armor)
	_check(atk.temp_flat_block == 0, "…and the grant is spent")
	stats.current_armor = 0
	dummies[0].current_health = dummies[0].max_health
	pt._last_played_card = Card.create_by_id("volatile_mixture")  # damaging, not offensive
	var drawn2 := Card.create_by_id("harden")
	main.deck_manager.hand.append(drawn2)
	pt._trigger_skill_tree_on_draw(drawn2)
	_check(drawn2.temp_hand_tempo_reduction == 0, "…but not after a damaging utility without the tag")
	main.deck_manager.hand.clear()
	stats.skill_tree_passives.erase("clean_exchange")

func _test_eagle_eye(stats, pt, dummy: Enemy) -> void:
	print("-- Eagle Eye: the card's full range --")
	_grant(stats, "eagle_eye")  # rank 15: 142%
	var gm = main.grid_manager
	_place(gm, dummy, gm.world_to_grid(main.player.position) + Vector2i(2, 0))
	var shot := Card.create_by_id("fireball")
	shot.is_ranged = true
	shot.range_modifier = 0
	stats.st_scouted_bonus_active = false
	stats.sphere_bonus_range = 0
	var plain: int = pt._trigger_skill_tree_stephen_on_attack(shot, dummy)
	_check(plain == roundi(5 * 1.42), "base range 5 → %d bonus (%d)" % [roundi(5 * 1.42), plain])
	stats.sphere_bonus_range = 3
	var boosted: int = pt._trigger_skill_tree_stephen_on_attack(shot, dummy)
	_check(boosted == roundi(8 * 1.42), "+3 range from the sphere grid counts on top (%d)" % boosted)
	stats.sphere_bonus_range = 0
	stats.skill_tree_passives.erase("eagle_eye")

func _test_patience(stats, pt, _dummy: Enemy) -> void:
	print("-- Patience is a Virtue: Endured Tolerance per 5 Glut, as a draw --")
	_grant(stats, "patience_is_a_virtue")  # rank 15: 30%
	var dm = main.deck_manager
	var bm = main.player.get_buff_manager()
	var count_et := func() -> int:
		return dm.hand.filter(func(c): return c.card_id == "endured_tolerance").size()
	for g in [[5, 1], [10, 2], [15, 3]]:
		dm.hand.clear()
		main.glut_tempo_remaining = g[0]
		pt._trigger_skill_tree_stephen_on_glut(g[0])
		_check(count_et.call() == g[1], "Glut %d puts %d Endured Tolerance in hand (%d)" % [g[0], g[1], count_et.call()])
		_check(main.glut_tempo_remaining == g[0], "…and the Glut is left whole (%d)" % main.glut_tempo_remaining)
	var et: Card = dm.hand[0]
	_check(et.card_type == Card.CardType.DEFENSE and et.mana_cost == 20 and et.tempo_cost == 1 and et.erase_tempo == 20,
		"Endured Tolerance is a 20m/1t Defense card with Erase 20")
	_check("30%" in et.description, "its text shows the rank's 30%% (%s)" % et.description)

	# A full hand keeps what fits and loses the rest.
	dm.hand.clear()
	while dm.hand.size() < dm.get_hand_cap() - 1:
		dm.hand.append(Card.create_by_id("block"))
	pt._trigger_skill_tree_stephen_on_glut(10)
	_check(count_et.call() == 1 and dm.hand.size() == dm.get_hand_cap(), "with one slot free, 1 of 2 arrives and the other is lost")

	# It counts as drawn: Clean Exchange sees a Defense card after an attack.
	dm.hand.clear()
	_grant(stats, "clean_exchange")
	pt._last_played_card = Card.create_by_id("slash")
	pt._trigger_skill_tree_stephen_on_glut(5)
	var ce: Card = dm.hand[0]
	_check(ce.untimed_tempo_reduction == 1, "Clean Exchange takes 1 tempo off it, as off any drawn Defense card")
	stats.skill_tree_passives.erase("clean_exchange")

	# Its Erase fuse waits for the Glut to end.
	var fuse0: int = ce.erase_tempo_remaining
	main.glut_tempo_remaining = 5
	dm._process_erase_timers()
	_check(ce.erase_tempo_remaining == fuse0, "while Glutted the Erase fuse holds (%d)" % ce.erase_tempo_remaining)
	main.glut_tempo_remaining = 0
	dm._process_erase_timers()
	_check(ce.erase_tempo_remaining == fuse0 - 5, "once the Glut ends it burns (%d -> %d)" % [fuse0, ce.erase_tempo_remaining])

	# Played: 30% resistance to all damage for 5 tempo; a second copy adds 5.
	bm.buffs.clear()
	ce.execute(null, stats, dm, 0, 0, bm)
	var r: Buff = bm._resilient_of_type(DamageTypes.ALL)
	_check(r != null and r.value == 30 and r.duration == 5, "played: 30%% resistance to all damage for 5 tempo (%s)" % (str([r.value, r.duration]) if r else "none"))
	Card.create_endured_tolerance(30).execute(null, stats, dm, 0, 0, bm)
	r = bm._resilient_of_type(DamageTypes.ALL)
	_check(r.value == 30 and r.duration == 10, "a second copy adds 5 tempo and keeps the %% (%d%%, %d tempo)" % [r.value, r.duration])
	_check(bm.get_resilient_percent(DamageTypes.Type.PHYSICAL) == 30 and bm.get_resilient_percent(DamageTypes.Type.FIRE) == 30,
		"it covers every damage type")
	bm.buffs.clear()
	dm.hand.clear()
	main.glut_tempo_remaining = 0
	stats.skill_tree_passives.erase("patience_is_a_virtue")

func _test_exposed_blind_spot(stats, pt, dummy: Enemy) -> void:
	print("-- Exposed Blind Spot: fractions kept, attacks only --")
	_grant(stats, "exposed_blind_spot", 2)  # rank 2: 1.25% per card
	var gm = main.grid_manager
	_place(gm, dummy, gm.world_to_grid(main.player.position) + Vector2i(1, 0))
	main.deck_manager.hand.clear()
	main.deck_manager.hand.append(Card.create_by_id("fireball"))   # an offensive SPELL: non-attack ("a hand full of offensive spells works")
	main.deck_manager.hand.append(Card.create_by_id("harden"))     # non-attack
	main.deck_manager.hand.append(Card.create_by_id("healing_potion"))  # non-attack
	main.deck_manager.hand.append(Card.create_by_id("slash"))      # an attack: not counted
	stats.st_exposed_blind_spot_crit = 0.0
	pt._trigger_skill_tree_stephen_on_attacked(dummy)
	_check(is_equal_approx(stats.st_exposed_blind_spot_crit, 3.75), "three non-attack cards (the offensive spell among them) at rank 2 arm 3.75%% — the Slash is not counted (%.2f)" % stats.st_exposed_blind_spot_crit)
	var bm = main.player.get_buff_manager()
	stats.st_pre_attack_is_attack = false
	bm.roll_crit()
	_check(is_equal_approx(stats.st_exposed_blind_spot_crit, 3.75), "a spell's roll neither uses nor spends it")
	stats.st_pre_attack_is_attack = true
	bm.roll_crit()
	_check(is_equal_approx(stats.st_exposed_blind_spot_crit, 0.0), "an attack's roll spends it")
	stats.st_pre_attack_is_attack = false
	main.deck_manager.hand.clear()
	stats.skill_tree_passives.erase("exposed_blind_spot")

func _test_swing(stats, pt, dummy: Enemy) -> void:
	print("-- Swing for the Fences: every card over 4 tempo --")
	_grant(stats, "swing_for_the_fences")  # rank 15: 380%
	var gm = main.grid_manager
	_place(gm, dummy, gm.world_to_grid(main.player.position) + Vector2i(4, 0))
	var slow_defense := Card.create_by_id("harden")
	slow_defense.tempo_cost = 5
	var hp0: int = dummy.current_health
	var bonus: int = pt._trigger_skill_tree_stephen_on_attack(slow_defense, main.player)
	_check(bonus == 0 and hp0 - dummy.current_health == 19, "a 5-tempo Defense card with no enemy target hits the nearest enemy for 19 (%d)" % (hp0 - dummy.current_health))
	var slow_attack := Card.create_by_id("slash")
	slow_attack.tempo_cost = 6
	_check(pt._trigger_skill_tree_stephen_on_attack(slow_attack, dummy) >= 23, "a 6-tempo attack adds 23 to its own target")
	dummy.current_health = dummy.max_health
	stats.skill_tree_passives.erase("swing_for_the_fences")

func _test_skilled_momentum(stats, pt, dummy: Enemy) -> void:
	print("-- Skilled Momentum: played twice, in full --")
	_grant(stats, "skilled_momentum")  # rank 15: 3 attacks
	var gm = main.grid_manager
	_place(gm, dummy, gm.world_to_grid(main.player.position) + Vector2i(1, 0))
	stats.st_consecutive_attacks = 3
	stats.st_skilled_momentum_last_tempo = -100
	stats.st_skilled_momentum_echo = false
	var slash := Card.create_by_id("slash")
	var hp0: int = dummy.current_health
	pt._trigger_skill_tree_stephen_on_attack(slash, dummy)
	_check(stats.st_skilled_momentum_echo and dummy.current_health == hp0, "the streak arms a second play instead of repeating a number")
	main._pending_resolve_queue.append({"card": slash, "target": dummy, "owner_index": 0, "data": {}})
	main._resolve_queued_card(slash)
	var dealt: int = hp0 - dummy.current_health
	_check(dealt >= 2 * slash.base_damage, "the resolve runs the attack twice (%d damage from a %d base)" % [dealt, slash.base_damage])
	_check(not stats.st_skilled_momentum_echo, "…and the echo is spent")
	dummy.current_health = dummy.max_health
	stats.skill_tree_passives.erase("skilled_momentum")

func _test_lethal(stats, pt, dummy: Enemy) -> void:
	print("-- Lethal Resourcefulness: a real auto attack at the weapon's reach --")
	_grant(stats, "lethal_resourcefulness")
	var gm = main.grid_manager
	var pcell: Vector2i = gm.world_to_grid(main.player.position)
	main.deck_manager.hand.clear()
	stats.st_lethal_last_tempo = -100
	_place(gm, dummy, pcell + Vector2i(3, 0))
	var hp0: int = dummy.current_health
	pt._trigger_skill_tree_stephen_on_card_play(Card.create_by_id("harden"))
	_check(dummy.current_health == hp0 and stats.st_lethal_last_tempo == -100, "bare-handed, an enemy 3 tiles off is out of reach: no attack, no cooldown spent")
	var inv = main.player.get_inventory()
	_check(inv.equip_item(ItemData.create("short_bow"), 0), "a bow equips")
	pt._trigger_skill_tree_stephen_on_card_play(Card.create_by_id("slash"))  # an attack never triggers it
	_check(dummy.current_health == hp0, "an attack card does not trigger it")
	pt._trigger_skill_tree_stephen_on_card_play(Card.create_by_id("harden"))
	_check(dummy.current_health < hp0, "with a bow the free auto attack reaches 3 tiles (%d damage)" % (hp0 - dummy.current_health))
	_check(stats.st_lethal_last_tempo != -100, "…and the cooldown is spent")
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	dummy.current_health = dummy.max_health
	stats.skill_tree_passives.erase("lethal_resourcefulness")
