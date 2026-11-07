extends SceneTree

## Phase 2 wiring audit — the 60 skill-tree passives (Brad, Cory, Jeremy,
## Ryan, Stephen). For each: the trigger, the effect, the rank scaling at
## rank 1 and rank 15 (max), and the cooldown, against the skill-tree text in
## skill_tree_data.gd. Boots the battle scene as the dojo (dummies to hit, no
## spawns, no XP); each section grants ONLY its passive at the rank under test.
## Report: docs/audit/wiring/passives.md
## Run: godot --headless --path . --script tests/test_wiring_passives.gd

var failures := 0
var main = null
var stats = null
var pt = null
var dm = null
var gm = null
var dummies: Array = []

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Wiring audit: skill-tree passives ===")
	_run()

func _run() -> void:
	TempoManager.preferred_swing_hold = 0  # blows land at once
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	main = packed.instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(6):
		await process_frame
	stats = main.player.get_stats()
	pt = main.progression_triggers
	dm = main.deck_manager
	gm = main.grid_manager
	stats.max_health = 100
	# A real swing to measure (Brad's bare 0-base hit is 1): rank differences show.
	stats.enchantment_damage_bonus = 20
	# Five dummies: the dojo's two and three more, for the "N enemies near" passives.
	var pcell: Vector2i = gm.world_to_grid(main.player.position)
	for i in range(3):
		main.enemy_spawner.spawn_enemy(Enemy.EnemyType.DUMMY, gm.grid_to_world(pcell + Vector2i(8 + i, 8)))
	dummies = main.enemy_spawner.get_living_enemies()
	_check(dummies.size() >= 5, "five dummies stand ready (%d)" % dummies.size())
	_check(_all_passive_ids().size() == 60, "the five trees hold 60 passives (%d)" % _all_passive_ids().size())

	# Brad
	_t_enraged_will()
	_t_in_the_trenches()
	_t_stone_skin()
	_t_point_to_prove()
	_t_directed_strength()
	_t_way_of_the_plate()
	_t_ancestral_aid()
	_t_redemption()
	_t_life_steal()
	_t_pristine_armor()
	_t_vines_codependence()
	_t_solemn_independence()
	# Cory
	_t_energy_barrier()
	_t_prey_on_the_weak()
	_t_wither()
	_t_budding()
	_t_eat()
	_t_expel_negativity()
	_t_circle_of_life()
	_t_territorial_death()
	_t_self_reliance()
	_t_death_as_lifeblood()
	_t_serial_killer()
	_t_regrowth()
	# Jeremy
	_t_arcane_overflow()
	_t_i_heal_you()
	_t_tricks_of_death()
	_t_mages_favor()
	_t_harnessed_power()
	_t_whispers()
	_t_seance()
	_t_kinetic_armor()
	_t_mana_surge()
	_t_haunted_rebuke()
	_t_blood_libation()
	_t_fresh_start()
	# Ryan
	_t_keep_them_guessing()
	_t_quick_step()
	_t_stimulant()
	_t_now_you_see_me()
	_t_from_the_hip()
	_t_ladder_work()
	_t_pop_rocks()
	_t_surprise_opener()
	_t_nimble_assault()
	_t_lets_dance()
	_t_mad_scientist()
	_t_eye_scrape()
	# Stephen
	_t_deadly()
	_t_clean_exchange()
	_t_eagle_eye()
	_t_patience()
	_t_easy_target()
	_t_exposed_blind_spot()
	_t_scouted()
	_t_swing_for_the_fences()
	_t_skilled_momentum()
	_t_lethal_resourcefulness()
	_t_elemental_conclusion()
	_t_dominate()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

# ============================================================
# Helpers
# ============================================================

func _all_passive_ids() -> Array:
	var ids: Array = []
	for who in ["Brad", "Cory", "Jeremy", "Ryan", "Stephen"]:
		var tree = SkillTreeData.create_tree_for(who)
		for row in tree.rows:
			for opt in row.options:
				if opt.passive_id != "" and not opt.name.contains("Option"):
					ids.append(opt.passive_id)
	return ids

## Exactly one passive, at `rank`: nothing else may add to what is measured.
func _only(id: String, rank: int) -> void:
	stats.skill_tree_passives.clear()
	stats.passive_levels.clear()
	stats.add_skill_tree_passive(id)
	stats.passive_levels[id] = rank

func _v(id: String, key: String, rank: int):
	return PassiveScaling.value(id, key, rank)

## A clean player: full health, no armor, temp HP, buffs or debuffs, an empty hand.
func _fresh() -> void:
	stats.current_health = stats.max_health
	stats.current_temp_health = 0
	stats.current_armor = 0
	stats.current_mana = stats.max_mana
	stats.solemn_active = false
	stats.last_heal_from_ally = false
	stats._passive_heal = false
	PlayerStats.heal_to_damage = false
	PlayerStats.harnessed_mult = 1.0
	PlayerStats.hit_source_offensive = false
	PlayerStats.hit_source_direct = false
	var bm = main.player.get_buff_manager()
	for b in bm.buffs.duplicate():
		bm.remove_buff(b.buff_type)
	bm.last_crit_hit = false
	bm.set("crit_hits", 0)
	main.player.get_debuff_manager().clear_all_debuffs()
	dm.hand.clear()
	_park()

## Every dummy far away, whole, unarmored and clean.
func _park() -> void:
	var pcell: Vector2i = gm.world_to_grid(main.player.position)
	for i in range(dummies.size()):
		var e: Enemy = dummies[i]
		if not is_instance_valid(e):
			continue
		_put(e, Vector2i(10 + 2 * i, 10))
		_reset_enemy(e)
	main._enemy_melee_state.clear()

func _reset_enemy(e: Enemy) -> void:
	e.max_health = 10000
	e.current_health = e.max_health
	e.current_armor = 0
	e.max_armor = 0
	e.poison_stacks = 0
	e.burn_stacks = 0
	e.cold_stacks = 0
	e.shock_stacks = 0
	e.slow_stacks = 0
	e.stun_tempo = 0
	e.is_stunned = false
	e.has_been_damaged = false
	e.last_player_hit_damage = 0
	e.invisible_to_players.clear()
	e.next_action_tempo_tax = 0
	e.vulnerable_stacks = 0
	e.weaken_stacks = 0

## Stand an enemy on the cell `offset` from the player.
func _put(e: Enemy, offset: Vector2i) -> void:
	var pcell: Vector2i = gm.world_to_grid(main.player.position)
	e.position = gm.grid_to_world(pcell + offset)
	e.target_position = e.position

## Wind the global clock on by `n` tempo for the passives that stamp the global
## tempo, and tick the count-down cooldowns the same amount (main's
## _on_tempo_advanced calls _trigger_skill_tree_on_tempo every tempo).
func _advance(n: int) -> void:
	main.tempo_manager.global_tempo += n
	pt._trigger_skill_tree_on_tempo(n)

func _now() -> int:
	return main.tempo_manager.get_global_tempo()

func _hand_has(id: String) -> Card:
	for c in dm.hand:
		if c.card_id == id:
			return c
	return null

## Resolve a card through main's real resolution path (riders, world effects,
## the card-play passive hooks).
func _resolve(card: Card, target) -> void:
	main._pending_resolve_queue.append({"card": card, "target": target, "owner_index": 0, "data": {}})
	main._resolve_queued_card(card)

func _fill_draw_pile(n: int, id: String = "block") -> void:
	dm.draw_pile.clear()
	dm.discard_pile.clear()
	for _i in range(n):
		dm.draw_pile.append(Card.create_by_id(id))

# ============================================================
# BRAD
# ============================================================

func _t_enraged_will() -> void:
	print("-- Enraged Will --")
	for r in [1, 15]:
		_only("enraged_will", r)
		_fresh()
		var thr: float = _v("enraged_will", "hp_threshold", r)
		var cd: int = _v("enraged_will", "cooldown", r)
		var a: Enemy = dummies[0]
		var b: Enemy = dummies[1]
		var far: Enemy = dummies[2]
		_put(a, Vector2i(1, 0))
		_put(b, Vector2i(1, 1))
		_put(far, Vector2i(3, 0))
		stats.st_enraged_will_last_tempo = -1000
		# Exactly at the threshold is not "below" it.
		stats.current_health = roundi(stats.max_health * thr)
		pt._trigger_skill_tree_brad_on_damage_taken(1)
		_check(a.current_health == a.max_health, "Enraged Will r%d: at exactly %d%% HP nothing swings" % [r, roundi(thr * 100)])
		# Real path: a hit that drops Brad below the threshold.
		stats.current_health = roundi(stats.max_health * thr) + 1
		var swing: int = stats.get_effective_physical_damage(0)
		stats.take_damage(2)
		_check(a.max_health - a.current_health == swing and b.max_health - b.current_health == swing,
			"Enraged Will r%d: dropping below %d%% swings at every enemy in reach for %d (%d, %d)" % [r, roundi(thr * 100), swing, a.max_health - a.current_health, b.max_health - b.current_health])
		_check(far.current_health == far.max_health, "Enraged Will r%d: an enemy 3 tiles off is out of reach" % r)
		_check(stats.st_enraged_will_last_tempo == _now(), "Enraged Will r%d: the cooldown starts" % r)
		var hp_a: int = a.current_health
		_advance(cd - 1)
		pt._trigger_skill_tree_brad_on_damage_taken(1)
		_check(a.current_health == hp_a, "Enraged Will r%d: %d tempo later (cooldown %d) it does not swing again" % [r, cd - 1, cd])
		_advance(1)
		pt._trigger_skill_tree_brad_on_damage_taken(1)
		_check(a.current_health < hp_a, "Enraged Will r%d: after %d tempo it swings again" % [r, cd])
	# Mana per kill: 10 mana (the displayed unit) for each enemy the swing kills.
	# (Dojo dummies refill on a killing blow: these two are made mortal.)
	_only("enraged_will", 15)
	_fresh()
	var pcell: Vector2i = gm.world_to_grid(main.player.position)
	var victims: Array = []
	for off in [Vector2i(1, 0), Vector2i(0, 1)]:
		var v: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.DUMMY, gm.grid_to_world(pcell + off))
		v.is_training_dummy = false
		v.current_health = 1
		v.current_armor = 0
		victims.append(v)
	stats.current_mana = 0
	stats.st_enraged_will_last_tempo = -1000
	stats.current_health = 5
	pt._trigger_skill_tree_brad_on_damage_taken(1)
	_check(int(stats.current_mana) == 20, "Enraged Will: two kills by the swing gain 10 mana each (%d)" % int(stats.current_mana))

func _t_in_the_trenches() -> void:
	print("-- In the Trenches --")
	for r in [1, 15]:
		_only("in_the_trenches", r)
		_fresh()
		var e: Enemy = dummies[0]
		stats.st_itt_charges = 2
		stats.st_itt_spent.clear()
		var mod: int = _v("in_the_trenches", "damage_mod", r)
		var expect: int = maxi(1, roundi(stats.get_effective_physical_damage(0) * (100 + mod) / 100.0))
		_put(e, Vector2i(3, 0))
		main._update_enemy_melee_state(e, true)
		_put(e, Vector2i(1, 0))
		main._update_enemy_melee_state(e, true)
		_check(e.max_health - e.current_health == expect, "In the Trenches r%d: an enemy stepping adjacent takes a free %d%% attack (%d, got %d)" % [r, 100 + mod, expect, e.max_health - e.current_health])
		_check(stats.st_itt_charges == 1, "In the Trenches r%d: the free attack spends a charge" % r)
		# Attacked from adjacent: knocked back, second charge.
		var before: Vector3 = e.position
		main._on_enemy_attacked_player(e, main.player)
		_check(e.position.distance_to(main.player.position) > before.distance_to(main.player.position) and stats.st_itt_charges == 0,
			"In the Trenches r%d: an adjacent attacker is knocked back (2nd charge)" % r)
		_put(e, Vector2i(1, 0))
		var hp: int = e.current_health
		main._enemy_melee_state[e.get_instance_id()] = false
		main._update_enemy_melee_state(e, true)
		_check(e.current_health == hp, "In the Trenches r%d: with no charges left nothing fires" % r)
		_advance(10)
		main._enemy_melee_state[e.get_instance_id()] = false
		main._update_enemy_melee_state(e, true)
		_check(e.current_health < hp, "In the Trenches r%d: 10 tempo later a charge is back" % r)

func _t_stone_skin() -> void:
	print("-- Stone Skin --")
	for r in [1, 15]:
		_only("stone_skin", r)
		_fresh()
		var pct: float = _v("stone_skin", "resist", r)
		var expect: int = 1000 - floori(1000 * (1.0 - pct / 100.0))
		for t in [DamageTypes.Type.PHYSICAL, DamageTypes.Type.FIRE, DamageTypes.Type.LIGHTNING]:
			stats.max_health = 2000
			stats.current_health = 2000
			stats.take_damage(1000, null, null, t)
			_check(2000 - stats.current_health == 1000 - expect, "Stone Skin r%d: %s damage reduced by %.2f%% (1000 → %d, took %d)" % [r, DamageTypes.Type.keys()[t], pct, 1000 - expect, 2000 - stats.current_health])
		stats.current_health = 2000
		stats.take_damage(1000, null, null, DamageTypes.Type.ICE)
		_check(2000 - stats.current_health == 1000, "Stone Skin r%d: ice damage is not reduced" % r)
		stats.max_health = 100
		stats.current_health = 100

func _t_point_to_prove() -> void:
	print("-- Point to Prove --")
	for r in [1, 15]:
		_only("point_to_prove", r)
		_fresh()
		var pdm = main.player.get_debuff_manager()
		var cost: int = maxi(1, ceili(stats.max_health * int(_v("point_to_prove", "hp_percent", r)) / 100.0))
		for dt in [Debuff.DebuffType.STUN, Debuff.DebuffType.SILENCE, Debuff.DebuffType.DISARM]:
			stats.current_health = stats.max_health
			var seen := [false]
			var cb := func(_d): seen[0] = true
			pdm.point_to_prove_triggered.connect(cb)
			pdm.apply_debuff(Debuff.create(dt, 0, 5))
			pdm.point_to_prove_triggered.disconnect(cb)
			_check(seen[0], "Point to Prove r%d: %s offers the sacrifice" % [r, Debuff.DebuffType.keys()[dt]])
			main.point_to_prove_dialog.confirmed.emit(dt)
			_check(stats.current_health == stats.max_health - cost and pdm.get_debuff(dt) == null,
				"Point to Prove r%d: confirming pays %d HP (%d%%) and ignores %s" % [r, cost, _v("point_to_prove", "hp_percent", r), Debuff.DebuffType.keys()[dt]])
		var seen2 := [false]
		var cb2 := func(_d): seen2[0] = true
		pdm.point_to_prove_triggered.connect(cb2)
		pdm.apply_debuff(Debuff.create_slowed(2))
		pdm.point_to_prove_triggered.disconnect(cb2)
		_check(not seen2[0], "Point to Prove r%d: Slowed is not one of the three" % r)
		pdm.clear_all_debuffs()

func _t_directed_strength() -> void:
	print("-- Directed Strength --")
	for r in [1, 15]:
		_only("directed_strength", r)
		_fresh()
		stats.current_health = 60
		var high: int = stats.strength
		stats.current_health = 40
		var low: int = stats.strength
		# Determination moves STR with health too: compare the passive's own share.
		_check(stats._directed_strength_mod() == r and low >= high,
			"Directed Strength r%d: below 50%% health it adds +%d STR (mod %d)" % [r, r, stats._directed_strength_mod()])
		stats.current_health = 60
		_check(stats._directed_strength_mod() == 0, "Directed Strength r%d: back above 50%% it is lost" % r)

func _t_way_of_the_plate() -> void:
	print("-- The Way of the Plate --")
	for r in [1, 15]:
		_only("the_way_of_the_plate", r)
		_fresh()
		var n: int = _v("the_way_of_the_plate", "cards_required", r)
		stats.st_defense_cards_played = 0
		main.tempo_manager.global_tempo = 100
		stats.current_mana = 0
		for _i in range(n - 1):
			pt._trigger_skill_tree_brad_on_defense_card_play(Card.create_by_id("block"))
		_check(int(stats.current_mana) == 0 and _now() == 100, "The Way of the Plate r%d: %d Defense cards refund nothing" % [r, n - 1])
		pt._trigger_skill_tree_brad_on_defense_card_play(Card.create_by_id("block"))
		_check(int(stats.current_mana) == 10 and _now() == 99, "The Way of the Plate r%d: the %dth refunds 10 mana and 1 tempo (%d mana, tempo %d)" % [r, n, int(stats.current_mana), _now()])

func _t_ancestral_aid() -> void:
	print("-- Ancestral Aid --")
	for r in [1, 15]:
		_only("ancestral_aid", r)
		_fresh()
		stats.st_ancestral_cycle_counter = 0
		var fb := Card.create_by_id("fireball")  # 80m offensive spell
		dm.hand.append(fb)
		dm.hand.append(Card.create_by_id("slash"))
		dm.hand.append(Card.create_by_id("block"))
		for _i in range(4):
			pt._trigger_skill_tree_brad_on_cycle()
		var cut: int = 0
		for c in dm.hand:
			cut += c.temp_mana_discount
		_check(cut == 0, "Ancestral Aid r%d: four cycles do nothing" % r)
		# Only the fireball can take the whole discount; make it the one picked.
		dm.hand[1].mana_cost = 0
		pt._trigger_skill_tree_brad_on_cycle()
		var disc: int = mini(int(_v("ancestral_aid", "mana_discount", r)), 80)
		_check(fb.temp_mana_discount == disc and fb.temp_mod_tempo_left == 5,
			"Ancestral Aid r%d: the 5th cycle, more offensive cards: a random offensive card -%dm for 5 tempo (%d)" % [r, disc, fb.temp_mana_discount])
		dm._process_temp_mods()
		_check(fb.temp_mana_discount == 0, "Ancestral Aid r%d: the discount ends after 5 tempo" % r)
		dm.hand.clear()
		dm.hand.append(Card.create_by_id("block"))
		dm.hand.append(Card.create_by_id("vengeful_shield"))  # an instant tagged defense
		dm.hand.append(Card.create_by_id("slash"))
		stats.current_health = 50
		for _i in range(5):
			pt._trigger_skill_tree_brad_on_cycle()
		var heal: int = stats.get_effective_heal_amount(int(_v("ancestral_aid", "heal", r)))
		_check(stats.current_health == 50 + heal, "Ancestral Aid r%d: more defense cards (a defense-tagged instant counts) heals %d (%d)" % [r, heal, stats.current_health - 50])

func _t_redemption() -> void:
	print("-- Redemption --")
	for r in [1, 15]:
		_only("redemption", r)
		_fresh()
		stats.st_redemption_crit = 0
		stats.current_health = 50
		stats.heal(5)  # Brad's own direct heal (the healed signal)
		_check(stats.st_redemption_crit == r, "Redemption r%d: healing himself arms +%d%% crit" % [r, r])
		pt.arm_pre_attack_passives(Card.create_by_id("block"), null)
		main.player.get_buff_manager().roll_crit()
		pt.clear_pre_attack_passives()
		_check(stats.st_redemption_crit == r, "Redemption r%d: a non-offensive card's roll does not spend it" % r)
		pt.arm_pre_attack_passives(Card.create_by_id("slash"), dummies[0])
		main.player.get_buff_manager().roll_crit()
		pt.clear_pre_attack_passives()
		_check(stats.st_redemption_crit == 0, "Redemption r%d: the next offensive card's roll spends it" % r)
		pt._trigger_skill_tree_on_card_play(Card.create_by_id("healing_potion"), main._dojo_allies[0])
		_check(stats.st_redemption_crit == r, "Redemption r%d: healing an ally arms it too" % r)
		stats.st_redemption_crit = 0

func _t_life_steal() -> void:
	print("-- Life Steal --")
	for r in [1, 15]:
		_only("life_steal", r)
		_fresh()
		var pct: float = _v("life_steal", "percent", r)
		stats.current_health = 10
		var e: Enemy = dummies[0]
		_put(e, Vector2i(1, 0))
		var slash := Card.create_by_id("slash")
		_resolve(slash, e)
		var dealt: int = e.max_health - e.current_health
		var expect: int = maxi(1, floori(dealt * pct / 100.0))
		_check(dealt > 0 and stats.current_health - 10 == stats.get_effective_heal_amount(expect),
			"Life Steal r%d: an attack card dealing %d heals %d%% → %d (healed %d)" % [r, dealt, int(pct), expect, stats.current_health - 10])
		stats.current_health = 10
		pt._brad_passive_hit(e, 200)
		var stolen: int = maxi(1, floori(200 * pct / 100.0))
		_check(stats.current_health - 10 == stats.get_effective_heal_amount(stolen), "Life Steal r%d: a passive hit of 200 steals %d%% = %d (healed %d)" % [r, int(pct), stolen, stats.current_health - 10])

func _t_pristine_armor() -> void:
	print("-- Pristine Armor --")
	for r in [1, 15]:
		_only("pristine_armor", r)
		_fresh()
		stats.st_consecutive_defense = 0
		var a: int = _v("pristine_armor", "armor", r)
		var s: int = _v("pristine_armor", "streak_bonus", r)
		pt._trigger_skill_tree_brad_on_defense_card_play(Card.create_by_id("block"))
		_check(stats.current_armor == a, "Pristine Armor r%d: a Defense card grants +%d armor" % [r, a])
		pt._trigger_skill_tree_brad_on_defense_card_play(Card.create_by_id("block"))
		pt._trigger_skill_tree_brad_on_defense_card_play(Card.create_by_id("block"))
		_check(stats.current_armor == 3 * a + s, "Pristine Armor r%d: three in a row add +%d more (%d)" % [r, s, stats.current_armor])
		# A non-Defense card in between breaks the streak (main's resolve path).
		stats.current_armor = 0
		pt._trigger_skill_tree_brad_on_defense_card_play(Card.create_by_id("block"))
		pt._trigger_skill_tree_brad_on_defense_card_play(Card.create_by_id("block"))
		_resolve(Card.create_by_id("draw"), null)
		var before: int = stats.current_armor
		pt._trigger_skill_tree_brad_on_defense_card_play(Card.create_by_id("block"))
		_check(stats.current_armor - before == a, "Pristine Armor r%d: a utility in between resets the streak" % r)

func _t_vines_codependence() -> void:
	print("-- Vines Codependence --")
	for r in [1, 15]:
		_only("vines_codependence", r)
		_fresh()
		var bm = main.player.get_buff_manager()
		stats.current_health = 50
		stats.heal(5)
		var th = bm.get_buff(Buff.BuffType.THORNS)
		var rg = bm.get_buff(Buff.BuffType.REGEN)
		var t_exp: int = _v("vines_codependence", "thorns", r)
		var r_exp: int = _v("vines_codependence", "regen", r)
		_check(th != null and th.value == t_exp and th.duration == 5, "Vines Codependence r%d: a direct heal grants %d thorns for 5 tempo" % [r, t_exp])
		_check((r_exp == 0 and rg == null) or (rg != null and rg.value == r_exp and rg.duration == 5), "Vines Codependence r%d: and %d regen for 5 tempo" % [r, r_exp])
		for b in bm.buffs.duplicate():
			bm.remove_buff(b.buff_type)
		stats._passive_heal = true
		stats.heal(5)
		stats._passive_heal = false
		_check(bm.get_buff(Buff.BuffType.THORNS) == null, "Vines Codependence r%d: a regen / life-steal heal does not count" % r)

func _t_solemn_independence() -> void:
	print("-- Solemn Independence --")
	for r in [1, 15]:
		_only("solemn_independence", r)
		_fresh()
		_put(dummies[0], Vector2i(1, 0))
		_put(dummies[1], Vector2i(0, 1))
		_put(dummies[2], Vector2i(2, 0))
		pt.refresh_solemn()
		_check(stats.solemn_active, "Solemn Independence r%d: three enemies within 2 tiles" % r)
		var pct: int = _v("solemn_independence", "damage_percent", r)
		PlayerStats.hit_source_offensive = true
		dummies[0].take_damage(100, true)
		PlayerStats.hit_source_offensive = false
		_check(dummies[0].max_health - dummies[0].current_health == 100 + pct, "Solemn Independence r%d: an offensive hit of 100 lands for %d" % [r, 100 + pct])
		pt._trigger_skill_tree_on_cycle()
		_check(stats.current_armor == int(_v("solemn_independence", "armor", r)), "Solemn Independence r%d: +%d armor per cycle" % [r, _v("solemn_independence", "armor", r)])
		stats.current_health = 50
		stats.heal(10, true)
		_check(stats.current_health == 50, "Solemn Independence r%d: an ally's heal is refused" % r)
		_put(dummies[2], Vector2i(5, 0))
		pt.refresh_solemn()
		_check(not stats.solemn_active, "Solemn Independence r%d: two enemies near is not surrounded" % r)

# ============================================================
# CORY
# ============================================================

func _t_energy_barrier() -> void:
	print("-- Energy Barrier --")
	for r in [1, 15]:
		_only("energy_barrier", r)
		_fresh()
		stats.st_mana_gain_counter = 0
		stats.current_mana = 0
		stats.gain_mana(5)
		stats.mana_gained.emit(5, true)  # a regen tick
		stats.gain_mana(5)
		_check(_hand_has("energy_barrier") == null, "Energy Barrier r%d: two gains and a regen tick add nothing" % r)
		stats.gain_mana(5)
		var eb := _hand_has("energy_barrier")
		var armor: int = _v("energy_barrier", "armor", r)
		_check(eb != null and eb.block == armor and eb.mana_cost == 0 and eb.tempo_cost == 0 and eb.erase_tempo == 1,
			"Energy Barrier r%d: the 3rd non-regen gain adds a 0m/0t Energy Barrier for %d armor, Erase 1" % [r, armor])

func _t_prey_on_the_weak() -> void:
	print("-- Prey on the Weak --")
	for r in [1, 15]:
		_only("prey_on_the_weak", r)
		_fresh()
		var e: Enemy = dummies[0]
		e.current_health = 4000  # 40%
		e.apply_debuff("poison", 1)
		var dmg: int = _v("prey_on_the_weak", "damage", r)
		_check(4000 - e.current_health == dmg, "Prey on the Weak r%d: a new debuff on an enemy below 50%% deals %d (%d)" % [r, dmg, 4000 - e.current_health])
		var hp: int = e.current_health
		e.apply_debuff("poison", 1)
		_check(e.current_health == hp, "Prey on the Weak r%d: re-stacking the same debuff does not" % r)
		e.current_health = 6000
		e.apply_debuff("burn", 1)
		_check(e.current_health == 6000, "Prey on the Weak r%d: above 50%% nothing" % r)

func _t_wither() -> void:
	print("-- Wither (FLAGGED: what a charge means) --")
	for r in [1, 15]:
		_only("wither", r)
		_fresh()
		var e: Enemy = dummies[0]
		var cd: int = _v("wither", "cooldown", r)
		stats.st_wither_last_tempo = -1000
		e.apply_debuff("poison", 2)
		_check(e.poison_stacks == 3, "Wither r%d: +1 charge on the applied debuff (poison 2 → %d)" % [r, e.poison_stacks])
		_check(stats.st_wither_last_tempo == _now(), "Wither r%d: the cooldown starts" % r)
		if cd > 1:
			_advance(cd - 1)
			e.apply_debuff("poison", 2)
			_check(e.poison_stacks == 5, "Wither r%d: within the %d-tempo cooldown no +1 (%d)" % [r, cd, e.poison_stacks])
			_advance(1)
		else:
			_advance(1)
		e.apply_debuff("burn", 1)
		_check(e.burn_stacks == 2, "Wither r%d: after %d tempo it adds +1 again, on any debuff (tempo gated)" % [r, cd])

func _t_budding() -> void:
	print("-- Budding --")
	for r in [1, 15]:
		_only("budding", r)
		_fresh()
		stats.st_budding_types.clear()
		stats.st_budding_last_type = ""
		stats.current_health = 50
		var amt: int = _v("budding", "amount", r)
		pt._trigger_skill_tree_cory_on_card_play(Card.create_by_id("slash"))
		pt._trigger_skill_tree_cory_on_card_play(Card.create_by_id("draw"))
		pt._trigger_skill_tree_cory_on_card_play(Card.create_by_id("draw"))  # back to back: starts over
		pt._trigger_skill_tree_cory_on_card_play(Card.create_by_id("block"))
		_check(stats.current_health == 50 and stats.current_temp_health == 0, "Budding r%d: two utilities back to back break the chain" % r)
		pt._trigger_skill_tree_cory_on_card_play(Card.create_by_id("slash"))
		var heal: int = stats.get_effective_heal_amount(amt)
		_check(stats.current_health == 50 + heal and stats.current_temp_health == amt and stats.temp_health_tempo_remaining == 15,
			"Budding r%d: utility, defense, offensive (none back to back) heals %d and gives %d temp HP for 15 tempo" % [r, heal, amt])

func _t_eat() -> void:
	print("-- Eat --")
	for r in [1, 15]:
		_only("eat", r)
		_fresh()
		var e: Enemy = dummies[0]
		var thr: int = _v("eat", "threshold_percent", r)
		e.current_health = 500  # 5%
		PlayerStats.hit_source_direct = true
		e.take_damage(100, true)
		PlayerStats.hit_source_direct = false
		var expect: int = (100 * (10000 + (thr - 5) * 100)) / 10000
		_check(500 - e.current_health == expect, "Eat r%d: an enemy at 5%% (threshold %d%%) takes +%d%% from a direct hit (%d)" % [r, thr, thr - 5, 500 - e.current_health])
		e.current_health = 5000
		PlayerStats.hit_source_direct = true
		e.take_damage(100, true)
		PlayerStats.hit_source_direct = false
		_check(5000 - e.current_health == 100, "Eat r%d: above the threshold no bonus" % r)
		stats.current_health = 50
		e.last_hit_direct = true
		pt._trigger_skill_tree_cory_on_kill(e)
		var heal: int = stats.get_effective_heal_amount(maxi(1, floori(stats.max_health * int(_v("eat", "heal_percent", r)) / 100.0)))
		_check(stats.current_health == 50 + heal, "Eat r%d: a kill by Cory's own hit heals %d%% of max HP (%d)" % [r, _v("eat", "heal_percent", r), stats.current_health - 50])
		stats.current_health = 50
		e.last_hit_direct = false
		pt._trigger_skill_tree_cory_on_kill(e)
		_check(stats.current_health == 50, "Eat r%d: a kill by a tick or a summon heals nothing" % r)

func _t_expel_negativity() -> void:
	print("-- Expel Negativity --")
	for r in [1, 15]:
		_only("expel_negativity", r)
		_fresh()
		var pdm = main.player.get_debuff_manager()
		var e: Enemy = dummies[0]
		_put(e, Vector2i(1, 0))
		var thr: float = _v("expel_negativity", "hp_threshold", r)
		stats.st_expel_charges = 2
		stats.st_expel_last_used_tempo = -1000
		pdm.apply_debuff(Debuff.create_slowed(2))
		stats.current_health = roundi(stats.max_health * thr)
		pt._trigger_skill_tree_cory_on_damage_taken(1)
		_check(e.slow_stacks == 0 and stats.st_expel_charges == 2, "Expel Negativity r%d: exactly at %d%% is not below it" % [r, roundi(thr * 100)])
		stats.current_health = roundi(stats.max_health * thr) + 1
		stats.take_damage(2)
		_check(e.slow_stacks == 2 and pdm.debuffs.is_empty() and stats.st_expel_charges == 1,
			"Expel Negativity r%d: dropping below %d%% moves Slowed to the nearest enemy, one charge" % [r, roundi(thr * 100)])
		pdm.apply_debuff(Debuff.create_slowed(1))
		pdm.apply_debuff(Debuff.create(Debuff.DebuffType.BURN, 2, 15))
		pt._trigger_skill_tree_cory_on_damage_taken(1)
		_check(pdm.debuffs.size() == 1 and stats.st_expel_charges == 0, "Expel Negativity r%d: one charge per hit (one of two debuffs moved)" % r)
		pt._trigger_skill_tree_cory_on_damage_taken(1)
		_check(pdm.debuffs.size() == 1, "Expel Negativity r%d: both charges spent, nothing more" % r)
		_advance(10)
		pt._trigger_skill_tree_cory_on_damage_taken(1)
		_check(pdm.debuffs.is_empty() and stats.st_expel_charges == 1, "Expel Negativity r%d: 10 tempo later the charges are back" % r)

func _t_circle_of_life() -> void:
	print("-- Circle of Life --")
	for r in [1, 15]:
		_only("circle_of_life", r)
		_fresh()
		var amt: int = _v("circle_of_life", "amount", r)
		dm.deck_shuffled.emit()
		var s = main.player.get_buff_manager().get_buff(Buff.BuffType.STRENGTHEN)
		_check(stats.current_armor == amt, "Circle of Life r%d: shuffling the deck grants %d armor" % [r, amt])
		_check(s != null and s.value == amt and s.charges == 3 and s.offensive_reach, "Circle of Life r%d: and +%d damage on the next 3 offensive cards" % [r, amt])

func _t_territorial_death() -> void:
	print("-- Territorial Death --")
	for r in [1, 15]:
		_only("territorial_death", r)
		_fresh()
		var e: Enemy = dummies[0]
		var cd: int = _v("territorial_death", "cooldown", r)
		stats.st_territorial_last_tempo = -1000
		e.poison_stacks = 2
		_put(e, Vector2i(3, 0))
		main._update_enemy_melee_state(e, true)
		_put(e, Vector2i(1, 0))
		main._update_enemy_melee_state(e, true)
		_check(e.poison_stacks == 3, "Territorial Death r%d: entering melee re-applies a debuff it has (poison 2 → %d)" % [r, e.poison_stacks])
		_put(e, Vector2i(3, 0))
		main._update_enemy_melee_state(e, true)
		_check(e.poison_stacks == (4 if cd <= 0 else 3), "Territorial Death r%d: leaving within the %d-tempo cooldown does nothing" % [r, cd])
		_advance(cd)
		_put(e, Vector2i(1, 0))
		main._update_enemy_melee_state(e, true)
		_check(e.poison_stacks == 4, "Territorial Death r%d: after %d tempo it fires again" % [r, cd])

func _t_self_reliance() -> void:
	print("-- Self Reliance --")
	for r in [1, 15]:
		_only("self_reliance", r)
		_fresh()
		stats.st_cards_this_cycle.clear()
		stats.st_self_reliance_discount = false
		var held := Card.create_by_id("peshtigos_kiss")  # 60m
		dm.hand.append(held)
		pt._trigger_skill_tree_cory_on_card_play(Card.create_by_id("slash"))
		pt._trigger_skill_tree_cory_on_card_play(Card.create_by_id("slash"))
		pt._trigger_skill_tree_cory_on_cycle()
		pt._trigger_skill_tree_cory_on_card_play(Card.create_by_id("slash"))
		_check(held.temp_mana_discount == 0, "Self Reliance r%d: three cards across two cycles do nothing" % r)
		pt._trigger_skill_tree_cory_on_card_play(Card.create_by_id("slash"))
		pt._trigger_skill_tree_cory_on_card_play(Card.create_by_id("slash"))
		var d: int = mini(int(_v("self_reliance", "mana_discount", r)), 60)
		_check(held.temp_mana_discount == d, "Self Reliance r%d: 3 cards in one cycle cut a hand card by %dm (%d)" % [r, d, held.temp_mana_discount])

func _t_death_as_lifeblood() -> void:
	print("-- Death as Lifeblood --")
	for r in [1, 15]:
		_only("death_as_lifeblood", r)
		_fresh()
		# Four within 2 squares (the grid is walked without diagonals, so (1,1)
		# is 2 squares away) and one at (2,1): 3 squares.
		_put(dummies[0], Vector2i(1, 0))
		_put(dummies[1], Vector2i(0, 2))
		_put(dummies[2], Vector2i(1, 1))
		_put(dummies[3], Vector2i(-2, 0))
		_put(dummies[4], Vector2i(2, 1))
		stats.current_health = 10
		var per: int = _v("death_as_lifeblood", "regen_per_enemy", r)
		var cap: int = _v("death_as_lifeblood", "max_enemies", r)
		var expect: int = stats.get_effective_heal_amount(mini(4, cap) * per)
		pt._trigger_skill_tree_cory_on_cycle()
		_check(stats.current_health == 10 + expect, "Death as Lifeblood r%d: each cycle %d HP per enemy within 2 squares, up to %d (%d enemies → +%d, got +%d)" % [r, per, cap, mini(4, cap), expect, stats.current_health - 10])

func _t_serial_killer() -> void:
	print("-- Serial Killer --")
	for r in [1, 15]:
		_only("serial_killer", r)
		_fresh()
		stats.st_serial_killer_enemies.clear()
		var e: Enemy = dummies[0]
		var thr: float = _v("serial_killer", "hp_threshold", r)
		e.current_health = roundi(e.max_health * thr) + 10
		e.take_damage(10, true)
		_check(not (main.player in e.invisible_to_players), "Serial Killer r%d: exactly at %d%% is not below it" % [r, roundi(thr * 100)])
		e.take_damage(1, true)
		_check(main.player in e.invisible_to_players, "Serial Killer r%d: dropping below %d%% makes Cory invisible to it" % [r, roundi(thr * 100)])
		pt.arm_pre_attack_passives(Card.create_by_id("slash"), e)
		var en = main.player.get_buff_manager().get_buff(Buff.BuffType.ENLIGHTENED)
		pt.clear_pre_attack_passives()
		_check(not (main.player in e.invisible_to_players) and en != null and en.value == 100, "Serial Killer r%d: attacking it reveals him with an auto-crit" % r)
		e.take_damage(1, true)
		_check(not (main.player in e.invisible_to_players), "Serial Killer r%d: only the first time" % r)

func _t_regrowth() -> void:
	print("-- Regrowth --")
	for r in [1, 15]:
		_only("regrowth", r)
		_fresh()
		var cd: int = _v("regrowth", "cooldown", r)
		stats.st_regrowth_cooldown = 0
		_fill_draw_pile(12)
		dm.hand.append(Card.create_by_id("block"))
		dm.hand.clear()
		dm.hand_updated.emit()
		_check(dm.hand.size() == 4 and stats.st_regrowth_cooldown == cd, "Regrowth r%d: emptying the hand draws 4, cooldown %d" % [r, cd])
		dm.hand.clear()
		dm.hand_updated.emit()
		_check(dm.hand.is_empty(), "Regrowth r%d: on cooldown it does not draw" % r)
		_advance(cd - 1)
		dm.hand_updated.emit()
		_check(dm.hand.is_empty(), "Regrowth r%d: %d tempo in, still cooling down" % [r, cd - 1])
		_advance(1)
		dm.hand_updated.emit()
		_check(dm.hand.size() == 4, "Regrowth r%d: ready after %d tempo" % [r, cd])
		dm.hand.clear()
		dm.draw_pile.clear()

# ============================================================
# JEREMY
# ============================================================

func _spell() -> Card:
	var c := Card.create_by_id("spark")
	c.school = Card.CardSchool.SPELL
	return c

func _t_arcane_overflow() -> void:
	print("-- Arcane Overflow --")
	for r in [1, 15]:
		_only("arcane_overflow", r)
		_fresh()
		var cd: int = _v("arcane_overflow", "cooldown", r)
		stats.st_arcane_overflow_discount = false
		stats.st_arcane_overflow_last_tempo = -1000
		stats.current_mana = 0
		var sp := _spell()
		sp.mana_cost = 10
		pt.on_card_ticks_started(Card.create_by_id("slash"))
		_check(not stats.st_arcane_overflow_discount, "Arcane Overflow r%d: an attack (not a spell) at 0 mana does not prime" % r)
		pt.on_card_ticks_started(sp)
		_check(stats.st_arcane_overflow_discount, "Arcane Overflow r%d: a spell cast leaving 0 mana primes -1 tempo" % r)
		stats.st_arcane_overflow_discount = false
		_advance(cd - 1)
		pt.on_card_ticks_started(sp)
		_check(not stats.st_arcane_overflow_discount, "Arcane Overflow r%d: within the %d-tempo cooldown it does not" % [r, cd])
		_advance(1)
		pt.on_card_ticks_started(sp)
		_check(stats.st_arcane_overflow_discount, "Arcane Overflow r%d: after %d tempo it primes again" % [r, cd])
		# Spent at play on the next OFFENSIVE card: one tempo less, once.
		stats.current_mana = stats.max_mana
		var e: Enemy = dummies[0]
		_put(e, Vector2i(1, 0))
		var tm = main.tempo_manager
		tm._active_cards.clear()
		main._pending_resolve_queue.clear()
		var s1 := Card.create_by_id("slash")
		dm.hand.append(s1)
		main.select_card(0)
		main.play_selected_card(e)
		var ticks: int = tm._active_cards.back()["total_ticks"] if not tm._active_cards.is_empty() else -1
		_check(ticks == 2 and not stats.st_arcane_overflow_discount, "Arcane Overflow r%d: the next offensive card costs -1 tempo (Slash 3 → %d)" % [r, ticks])
		tm._active_cards.clear()
		main._pending_resolve_queue.clear()
		tm._ticking = false
		stats.st_arcane_overflow_discount = false

func _t_i_heal_you() -> void:
	print("-- I Heal You --")
	for r in [1, 15]:
		_only("i_heal_you", r)
		_fresh()
		var iv: int = _v("i_heal_you", "interval", r)
		var near = main._dojo_allies[0]
		var far = main._dojo_allies[1] if main._dojo_allies.size() > 1 else null
		var pcell: Vector2i = gm.world_to_grid(main.player.position)
		near.position = gm.grid_to_world(pcell + Vector2i(2, 1))
		if far:
			far.position = gm.grid_to_world(pcell + Vector2i(3, 1))
		var ns = near.get_stats()
		ns.solemn_active = false
		ns.current_health = 10
		if far:
			far.get_stats().current_health = 10
		stats.st_i_heal_you_tempo = 0
		_advance(iv - 1)
		_check(ns.current_health == 10, "I Heal You r%d: %d tempo in, nothing yet" % [r, iv - 1])
		_advance(1)
		_check(ns.current_health == 10 + ns.get_effective_heal_amount(3), "I Heal You r%d: every %d tempo an ally 3 squares away is healed 3" % [r, iv])
		if far:
			_check(far.get_stats().current_health == 10, "I Heal You r%d: an ally 4 squares away is not" % r)

func _t_tricks_of_death() -> void:
	print("-- Tricks of Death --")
	for r in [1, 15]:
		stats.skill_tree_passives.clear()
		var base: float = stats.get_chance_boost()
		_only("tricks_of_death", r)
		var add: float = _v("tricks_of_death", "chance", r)
		_check(is_equal_approx(stats.get_chance_boost() - base, add), "Tricks of Death r%d: card chances +%.1f points" % [r, add])

func _t_mages_favor() -> void:
	print("-- A Mage's Favor --")
	for r in [1, 15]:
		_only("a_mage's_favor", r)
		_fresh()
		pt._trigger_skill_tree_jeremy_on_rng_reroll()
		var mb := _hand_has("magic_barrier")
		var armor: int = _v("a_mage's_favor", "armor", r)
		_check(mb != null and mb.block == armor and mb.card_type == Card.CardType.REACTION and mb.reaction_trigger == "on_incoming_attack" and mb.mana_cost == 0 and mb.tempo_cost == 0,
			"A Mage's Favor r%d: a reroll batch that changed an outcome adds one 0m/0t Magic Barrier instant (%d armor) that fires on an incoming attack" % [r, armor])
		_check(dm.hand.size() == 1, "A Mage's Favor r%d: one per batch" % r)
		if mb:
			mb.execute(null, stats, dm, 0.0, 0.0, main.player.get_buff_manager())
			_check(stats.current_armor == armor, "A Mage's Favor r%d: the barrier grants %d armor" % [r, armor])

func _t_harnessed_power() -> void:
	print("-- Harnessed Power --")
	for r in [1, 15]:
		_only("harnessed_power", r)
		_fresh()
		var pct: int = _v("harnessed_power", "percent", r)
		dm.hand.append(Card.create_by_id("slash"))
		dm.hand.append(Card.create_by_id("slash"))
		dm.hand.append(Card.create_by_id("slash"))
		_check(is_equal_approx(pt._get_jeremy_harnessed_power_multiplier(), 1.0), "Harnessed Power r%d: 3 cards in hand, no bonus" % r)
		dm.hand.pop_back()
		var m: float = pt._get_jeremy_harnessed_power_multiplier()
		_check(is_equal_approx(m, 1.0 + pct / 100.0), "Harnessed Power r%d: 2 cards in hand, x%.2f" % [r, m])
		PlayerStats.harnessed_mult = m
		var e: Enemy = dummies[0]
		e.take_damage(100, true)
		stats.add_armor(100)
		stats.current_health = 10
		stats.heal(50)
		PlayerStats.harnessed_mult = 1.0
		_check(e.max_health - e.current_health == 100 + pct, "Harnessed Power r%d: damage +%d%%" % [r, pct])
		_check(stats.current_armor == 100 + pct, "Harnessed Power r%d: armor gain +%d%%" % [r, pct])
		_check(stats.current_health == 10 + stats.get_effective_heal_amount(floori(50 * m)), "Harnessed Power r%d: healing +%d%%" % [r, pct])

func _t_whispers() -> void:
	print("-- Whispers of the Flock --")
	for r in [1, 15]:
		_only("whispers_of_the_flock", r)
		_fresh()
		var cd: int = _v("whispers_of_the_flock", "cooldown", r)
		var armor: int = _v("whispers_of_the_flock", "armor", r)
		stats.st_whispers_active = false
		stats.st_whispers_cooldown = 0
		var ally = main._dojo_allies[0]
		pt._trigger_skill_tree_on_card_play(Card.create_by_id("healing_potion"), ally)
		var mark := _hand_has("shepherds_mark")
		_check(mark != null and mark.erase_tempo == 10 and stats.st_whispers_cooldown == cd, "Whispers r%d: healing an ally adds a Shepherd's Mark (Erase 10), cooldown %d" % [r, cd])
		dm.hand.clear()
		pt._trigger_skill_tree_on_card_play(Card.create_by_id("healing_potion"), ally)
		_check(_hand_has("shepherds_mark") == null, "Whispers r%d: on cooldown, no second mark" % r)
		# (The dojo's ally dummy refills on a lethal blow; a plain ally's stats.)
		var as_ := PlayerStats.new()
		get_root().add_child(as_)
		as_.max_health = 50
		as_.current_armor = 0
		as_.st_whispers_active = true
		as_.st_whispers_tempo = 10
		as_.st_whispers_caster = stats
		as_.current_health = 5
		stats.current_health = 50
		as_.take_direct_damage(50)
		_check(as_.current_health == 1 and as_.current_armor == armor and stats.current_health == 42,
			"Whispers r%d: the marked ally survives lethal at 1 HP with %d armor; Jeremy takes 8 (%d HP, %d armor, Jeremy %d)" % [r, armor, as_.current_health, as_.current_armor, stats.current_health])
		as_.queue_free()
		_advance(cd)
		_check(stats.st_whispers_cooldown == 0, "Whispers r%d: the cooldown ends after %d tempo" % [r, cd])

func _t_seance() -> void:
	print("-- Seance --")
	for r in [1, 15]:
		_only("seance", r)
		_fresh()
		var pcell: Vector2i = gm.world_to_grid(main.player.position)
		var aim_cell: Vector2i = pcell + Vector2i(3, -2)
		var sp := _spell()
		sp.target_types = ["point"]
		var before: int = main._specters.size()
		pt._trigger_skill_tree_jeremy_on_card_play(sp, null, gm.grid_to_world(aim_cell))
		var hp: int = _v("seance", "specter", r)
		_check(main._specters.size() == before + 1, "Seance r%d: an offensive card aimed at an empty tile raises a Specter" % r)
		if main._specters.size() > before:
			var s = main._specters.back()
			_check(s.health == hp and s.death_damage == hp, "Seance r%d: %d HP, %d damage to its killer" % [r, hp, hp])
		main._update_specters(25)
		_check(main._specters.size() == before, "Seance r%d: it fades after 25 tempo" % r)

func _t_kinetic_armor() -> void:
	print("-- Kinetic Armor --")
	for r in [1, 15]:
		_only("kinetic_armor", r)
		_fresh()
		var t: int = _v("kinetic_armor", "tempo", r)
		var e: Enemy = dummies[0]
		_put(e, Vector2i(1, 0))
		dm.hand.append(Card.create_by_id("block"))
		dm.draw_pile.clear()
		dm.discard_pile.clear()
		dm.draw_pile.append(Card.create_by_id("block"))
		dm.discard_pile.append(Card.create_by_id("vengeful_shield"))  # defensive by its tag
		dm.discard_pile.append(Card.create_by_id("slash"))
		stats.current_armor = 5
		stats.st_kinetic_armor_tempo = 0
		stats.st_kinetic_armor_triggered = false
		pt._trigger_skill_tree_on_tempo(t)
		_check(e.shock_stacks == 0, "Kinetic Armor r%d: %d tempo of armor is not more than %d" % [r, t, t])
		pt._trigger_skill_tree_on_tempo(1)
		_check(e.shock_stacks == 3, "Kinetic Armor r%d: past %d tempo the nearest enemy gets shock = defense cards in the deck (3, got %d)" % [r, t, e.shock_stacks])
		pt._trigger_skill_tree_on_tempo(5)
		_check(e.shock_stacks == 3, "Kinetic Armor r%d: once per retention" % r)
		dm.draw_pile.clear()
		dm.discard_pile.clear()

func _t_mana_surge() -> void:
	print("-- Mana Surge --")
	for r in [1, 15]:
		_only("mana_surge", r)
		_fresh()
		stats.st_mana_spent_window.clear()
		var big := Card.create_by_id("slash")
		big.mana_cost = 50
		pt._trigger_skill_tree_jeremy_on_card_play(big, null)
		_advance(6)
		pt._trigger_skill_tree_jeremy_on_card_play(big, null)
		_check(_hand_has("mana_surge") == null, "Mana Surge r%d: 100 mana over 6 tempo adds nothing" % r)
		_advance(5)
		pt._trigger_skill_tree_jeremy_on_card_play(big, null)
		var ms := _hand_has("mana_surge")
		var dmg: int = _v("mana_surge", "damage", r)
		_check(ms != null and ms.base_damage == dmg and ms.mana_cost == 0 and ms.tempo_cost == 2,
			"Mana Surge r%d: 100 mana within 5 tempo adds a 0m/2t Mana Surge dealing %d" % [r, dmg])
		if ms:
			stats.current_mana = 0
			var e: Enemy = dummies[0]
			ms.execute(e, stats, dm, 0.0, 0.0, main.player.get_buff_manager())
			_check(int(stats.current_mana) == 10 and e.current_health < e.max_health, "Mana Surge r%d: playing it deals damage and gains 10 mana" % r)
			_check("10 mana" in ms.description, "Mana Surge r%d: the card says it gains 10 mana (%s)" % [r, ms.description])

func _t_haunted_rebuke() -> void:
	print("-- Haunted Rebuke --")
	for r in [1, 15]:
		_only("haunted_rebuke", r)
		_fresh()
		var cd: int = _v("haunted_rebuke", "cooldown", r)
		var e: Enemy = dummies[0]
		stats.st_haunted_rebuke_cooldown = 0
		dm.hand.append(Card.create_by_id("block"))
		dm.hand.append(Card.create_by_id("block"))
		main._on_enemy_attacked_player(e, main.player)
		_check(e.next_action_tempo_tax == 0, "Haunted Rebuke r%d: 2 defense cards in hand do nothing" % r)
		dm.hand.append(Card.create_by_id("vengeful_shield"))  # defensive by its tag
		main._on_enemy_attacked_player(e, main.player)
		_check(e.next_action_tempo_tax == 3 and stats.st_haunted_rebuke_cooldown == cd, "Haunted Rebuke r%d: with 3 defensive cards (a defense-tagged instant counts) the attacker's next action takes +3 tempo, cooldown %d" % [r, cd])
		_advance(cd - 1)
		main._on_enemy_attacked_player(e, main.player)
		_check(e.next_action_tempo_tax == 3, "Haunted Rebuke r%d: on cooldown no more" % r)
		_advance(1)
		main._on_enemy_attacked_player(e, main.player)
		_check(e.next_action_tempo_tax == 6, "Haunted Rebuke r%d: ready after %d tempo" % [r, cd])

func _t_blood_libation() -> void:
	print("-- Blood Libation --")
	for r in [1, 15]:
		_only("blood_libation", r)
		_fresh()
		var per: int = _v("blood_libation", "heal_per_stack", r)
		stats.sanguine_stacks = 0
		stats.take_damage(1)
		stats.take_damage(1)
		_check(stats.sanguine_stacks == 2, "Blood Libation r%d: each damage taken adds a Sanguine stack" % r)
		stats.current_health = 10
		stats.heal(5)
		_check(stats.current_health == 10 + stats.get_effective_heal_amount(5 + 2 * per), "Blood Libation r%d: each stack adds +%d to his heals" % [r, per])
		for _i in range(7):
			stats.take_damage(1)
		_check(stats.sanguine_stacks == 5, "Blood Libation r%d: max 5 stacks" % r)
		stats.current_health = 50
		stats.heal(5)
		_check(stats.sanguine_stacks == 0 and stats.current_health == mini(100, 40 + stats.get_effective_heal_amount((5 + 5 * per) * 2)),
			"Blood Libation r%d: at 5 stacks he takes 10, then the heal lands doubled, stacks consumed (%d)" % [r, stats.current_health])
		stats.current_health = 5
		stats.sanguine_stacks = 5
		stats.boost_performed_heal(1)
		_check(stats.current_health == 1, "Blood Libation r%d: the 10 damage is non-lethal" % r)

func _t_fresh_start() -> void:
	print("-- Fresh Start --")
	for r in [1, 15]:
		_only("fresh_start", r)
		_fresh()
		var cd: int = _v("fresh_start", "cooldown", r)
		var pdm = main.player.get_debuff_manager()
		stats.st_fresh_start_last_tempo = -1000
		pt._trigger_skill_tree_jeremy_on_card_play(Card.create_by_id("draw"), null)
		_check(stats.st_fresh_start_last_tempo == -1000, "Fresh Start r%d: nothing to cleanse, no cooldown spent" % r)
		dm.hand.append(Card.create_by_id("block"))
		pdm.apply_debuff(Debuff.create(Debuff.DebuffType.BURN, 2, 15))
		pt._trigger_skill_tree_jeremy_on_card_play(Card.create_by_id("draw"), null)
		_check(pdm.debuffs.size() == 1, "Fresh Start r%d: a card that leaves cards in hand cleanses nothing" % r)
		dm.hand.clear()
		pt._trigger_skill_tree_jeremy_on_card_play(Card.create_by_id("draw"), null)
		_check(pdm.debuffs.is_empty() and stats.st_fresh_start_last_tempo == _now(), "Fresh Start r%d: emptying the hand cleanses a debuff" % r)
		pdm.apply_debuff(Debuff.create(Debuff.DebuffType.BURN, 2, 15))
		_advance(cd - 1)
		pt._trigger_skill_tree_jeremy_on_card_play(Card.create_by_id("draw"), null)
		_check(pdm.debuffs.size() == 1, "Fresh Start r%d: within the %d-tempo cooldown no" % [r, cd])
		_advance(1)
		pt._trigger_skill_tree_jeremy_on_card_play(Card.create_by_id("draw"), null)
		_check(pdm.debuffs.is_empty(), "Fresh Start r%d: after %d tempo yes" % [r, cd])

# ============================================================
# RYAN
# ============================================================

func _t_keep_them_guessing() -> void:
	print("-- Keep Them Guessing --")
	for r in [1, 15]:
		_only("keep_them_guessing", r)
		_fresh()
		var n: int = _v("keep_them_guessing", "discards_required", r)
		stats.st_ktg_discard_count = 0
		var slash := Card.create_by_id("slash")
		dm.hand.append(slash)
		for _i in range(n - 1):
			dm.non_play_discard.emit(Card.create_by_id("block"))
		dm.card_discarded.emit(Card.create_by_id("block"))  # a play passing the pile: not a discard
		_check(slash.temp_hand_tempo_reduction == 0, "Keep Them Guessing r%d: %d discards (and a play) do nothing" % [r, n - 1])
		dm.non_play_discard.emit(Card.create_by_id("block"))
		_check(slash.temp_hand_tempo_reduction == 3 and slash.temp_mod_tempo_left == 5, "Keep Them Guessing r%d: the %dth discard cuts a hand card by 3 tempo for 5 tempo" % [r, n])

func _t_quick_step() -> void:
	print("-- Quick Step --")
	for r in [1, 15]:
		_only("quick_step", r)
		_fresh()
		dm.reaction_triggered.emit(Card.create_by_id("cover"))
		_check(stats.current_armor == int(_v("quick_step", "armor", r)), "Quick Step r%d: an instant fired from hand grants %d armor" % [r, _v("quick_step", "armor", r)])
		stats.current_armor = 0
		pt._trigger_skill_tree_on_card_play(Card.create_by_id("slash"), null)
		_check(stats.current_armor == 0, "Quick Step r%d: a played card grants nothing" % r)

func _t_stimulant() -> void:
	print("-- Stimulant --")
	for r in [1, 15]:
		_only("stimulant", r)
		_fresh()
		var cd: int = _v("stimulant", "cooldown", r)
		stats.st_stimulant_cooldown = 0
		_fill_draw_pile(10)
		var pot := Card.create_by_id("healing_potion")
		pt._trigger_skill_tree_on_card_play(pot, main.player)
		_check(dm.hand.size() == 1 and stats.st_stimulant_cooldown == cd, "Stimulant r%d: healing with a Pocket card draws a card, cooldown %d" % [r, cd])
		pt._trigger_skill_tree_on_card_play(pot, main.player)
		_check(dm.hand.size() == 1, "Stimulant r%d: on cooldown no draw" % r)
		_advance(cd)
		pt._trigger_skill_tree_on_card_play(Card.create_by_id("heal"), main.player)
		_check(dm.hand.size() == 2, "Stimulant r%d: ready after %d tempo" % [r, cd])
		# Poisoned Blood turned the heal into damage: nobody was healed.
		stats.st_stimulant_cooldown = 0
		PlayerStats.heal_to_damage = true
		pt._trigger_skill_tree_on_card_play(pot, main.player)
		PlayerStats.heal_to_damage = false
		_check(dm.hand.size() == 2 and stats.st_stimulant_cooldown == 0, "Stimulant r%d: a heal Poisoned Blood flipped to damage heals nobody: no draw, no cooldown" % r)
		pt._trigger_skill_tree_on_card_play(Card.create_by_id("dagger_throw"), dummies[0])
		_check(dm.hand.size() == 2, "Stimulant r%d: a Pocket card that heals nobody does nothing" % r)
		dm.draw_pile.clear()

func _t_now_you_see_me() -> void:
	print("-- Now You See Me --")
	for r in [1, 15]:
		_only("now_you_see_me", r)
		_fresh()
		var cd: int = _v("now_you_see_me", "cooldown", r)
		stats.st_nysm_last_tempo = -1000
		var bm = main.player.get_buff_manager()
		pt._trigger_skill_tree_on_displacement()
		var inv = bm.get_buff(Buff.BuffType.INVISIBLE)
		_check(inv != null and inv.duration == 5, "Now You See Me r%d: a displacement grants invisibility for 5 tempo" % r)
		bm.remove_buff(Buff.BuffType.INVISIBLE)
		_advance(cd - 1)
		pt._trigger_skill_tree_on_displacement()
		_check(bm.get_buff(Buff.BuffType.INVISIBLE) == null, "Now You See Me r%d: within the %d-tempo cooldown nothing" % [r, cd])
		bm.remove_buff(Buff.BuffType.INVISIBLE)
		_advance(1)
		pt._trigger_skill_tree_on_displacement()
		_check(bm.get_buff(Buff.BuffType.INVISIBLE) != null, "Now You See Me r%d: after %d tempo again" % [r, cd])
		bm.remove_buff(Buff.BuffType.INVISIBLE)
		main._set_player_invisible(false)

func _t_from_the_hip() -> void:
	print("-- From the Hip --")
	for r in [1, 15]:
		_only("from_the_hip", r)
		_fresh()
		stats.st_from_hip_card = null
		var a := Card.create_by_id("multishot")  # 30m / 6t attack
		pt._trigger_skill_tree_on_draw(a)
		var m: int = mini(int(_v("from_the_hip", "mana", r)), 30)
		var t: int = _v("from_the_hip", "tempo", r)
		_check(a.mana_cost == 30 - m and a.tempo_cost == 6 - t, "From the Hip r%d: a drawn attack costs -%dm/-%dt (%dm/%dt)" % [r, m, t, a.mana_cost, a.tempo_cost])
		var b := Card.create_by_id("block")
		pt._trigger_skill_tree_on_draw(b)
		_check(a.mana_cost == 30 and a.tempo_cost == 6 and b.mana_cost == 20, "From the Hip r%d: the next draw (not an attack) ends it — only the most recent card" % r)
		pt._trigger_skill_tree_on_draw(a)
		pt._trigger_skill_tree_on_card_play(Card.create_by_id("draw"), null)
		_check(a.mana_cost == 30 and a.tempo_cost == 6, "From the Hip r%d: any card played ends it" % r)

func _t_ladder_work() -> void:
	print("-- Ladder Work --")
	for r in [1, 15]:
		stats.skill_tree_passives.clear()
		var dex0: int = stats.dexterity
		var agi0: int = stats.agility
		_only("ladder_work", r)
		_fresh()
		_check(stats.dexterity - dex0 == int(_v("ladder_work", "dexterity", r)) and stats.agility - agi0 == int(_v("ladder_work", "agility", r)),
			"Ladder Work r%d: +%d DEX, +%d AGI" % [r, _v("ladder_work", "dexterity", r), _v("ladder_work", "agility", r)])
		stats.st_ladder_discard_count = 0
		stats.st_ladder_banked = 0
		for _i in range(3):
			dm.non_play_discard.emit(Card.create_by_id("block"))
		pt._trigger_skill_tree_on_cycle()
		var e: Enemy = dummies[0]
		var per: int = _v("ladder_work", "damage_per_discard", r)
		pt._trigger_skill_tree_on_attack(Card.create_by_id("slash"), e)
		_check(e.max_health - e.current_health == 3 * per, "Ladder Work r%d: the first attack this cycle deals +%d per card discarded last cycle (3 → %d)" % [r, per, e.max_health - e.current_health])
		var hp: int = e.current_health
		pt._trigger_skill_tree_on_attack(Card.create_by_id("slash"), e)
		_check(e.current_health == hp, "Ladder Work r%d: only the first attack" % r)

func _t_pop_rocks() -> void:
	print("-- Pop Rocks --")
	for r in [1, 15]:
		_only("pop_rocks", r)
		_fresh()
		var cd: int = _v("pop_rocks", "cooldown", r)
		stats.st_pop_rocks_last_tempo = -1000
		var e: Enemy = dummies[0]
		e.apply_debuff("poison", 6)
		_check(e.current_health == e.max_health, "Pop Rocks r%d: poisoning a clean enemy does nothing" % r)
		e.apply_debuff("poison", 3)
		_check(e.max_health - e.current_health == 3, "Pop Rocks r%d: poisoning a poisoned enemy deals 1/3 of its stacks (9 → 3)" % r)
		var hp: int = e.current_health
		_advance(cd - 1)
		e.apply_debuff("poison", 3)
		_check(e.current_health == hp, "Pop Rocks r%d: within the %d-tempo cooldown nothing" % [r, cd])
		_advance(1)
		e.apply_debuff("poison", 3)
		_check(hp - e.current_health == 5, "Pop Rocks r%d: after %d tempo again (15 stacks → 5)" % [r, cd])

func _t_surprise_opener() -> void:
	print("-- Surprise Opener --")
	for r in [1, 15]:
		_only("surprise_opener", r)
		_fresh()
		stats.st_enemy_first_strikes.clear()
		var e: Enemy = dummies[0]
		var slash := Card.create_by_id("slash")
		pt.arm_pre_attack_passives(slash, e)
		pt.clear_pre_attack_passives()
		pt._trigger_skill_tree_on_attack(slash, e)
		var all3: int = int(_v("surprise_opener", "first_strike", r)) + int(_v("surprise_opener", "no_armor", r)) + int(_v("surprise_opener", "first_source", r))
		_check(e.max_health - e.current_health == all3, "Surprise Opener r%d: first strike on an untouched, unarmored enemy: +%d (got %d)" % [r, all3, e.max_health - e.current_health])
		var hp: int = e.current_health
		pt._trigger_skill_tree_on_attack(slash, e)
		_check(e.current_health == hp, "Surprise Opener r%d: only the first strike" % r)
		var f: Enemy = dummies[1]
		f.current_armor = 5
		f.take_damage(5, false)
		f.current_armor = 5
		pt.arm_pre_attack_passives(slash, f)
		pt.clear_pre_attack_passives()
		var fhp: int = f.current_health
		var farm: int = f.current_armor
		pt._trigger_skill_tree_on_attack(slash, f)
		var fs: int = _v("surprise_opener", "first_strike", r)
		_check((fhp + farm) - (f.current_health + f.current_armor) == fs, "Surprise Opener r%d: an armored, already-hurt enemy gets only the +%d" % [r, fs])

func _t_nimble_assault() -> void:
	print("-- Nimble Assault --")
	for r in [1, 15]:
		_only("nimble_assault", r)
		_fresh()
		var cd: int = _v("nimble_assault", "cooldown", r)
		stats.st_nimble_last_tempo = -1000
		_fill_draw_pile(10, "draw")
		dm.hand.append(Card.create_by_id("vengeful_shield"))
		pt._trigger_skill_tree_on_card_play(Card.create_by_id("slash"), null)
		_check(dm.hand.size() == 1, "Nimble Assault r%d: a defense card in hand (a defense-tagged instant counts): no draw" % r)
		dm.hand.clear()
		dm.hand.append(Card.create_by_id("draw"))
		pt._trigger_skill_tree_on_card_play(Card.create_by_id("slash"), null)
		_check(dm.hand.size() == 2, "Nimble Assault r%d: cards but no Defense: an offensive play draws" % r)
		_advance(cd - 1)
		pt._trigger_skill_tree_on_card_play(Card.create_by_id("slash"), null)
		_check(dm.hand.size() == 2, "Nimble Assault r%d: within the %d-tempo cooldown no" % [r, cd])
		_advance(1)
		pt._trigger_skill_tree_on_card_play(Card.create_by_id("draw"), null)
		_check(dm.hand.size() == 2, "Nimble Assault r%d: a utility play does not draw" % r)
		pt._trigger_skill_tree_on_card_play(Card.create_by_id("slash"), null)
		_check(dm.hand.size() == 3, "Nimble Assault r%d: after %d tempo yes" % [r, cd])
		dm.draw_pile.clear()

func _t_lets_dance() -> void:
	print("-- Let's Dance --")
	for r in [1, 15]:
		_only("let's_dance", r)
		_fresh()
		var div: int = _v("let's_dance", "divisor", r)
		var e: Enemy = dummies[0]
		_put(e, Vector2i(3, 0))
		_put(dummies[1], Vector2i(4, 0))
		main.tempo_manager.spaces_moved_this_cycle = 8
		pt._trigger_skill_tree_on_cycle()
		var amt: int = floori(8 / float(div))
		_check(stats.current_armor == amt and e.max_health - e.current_health == amt and dummies[1].current_health == dummies[1].max_health,
			"Let's Dance r%d: 8 spaces ÷ %d = %d armor and %d damage to the nearest enemy within 3" % [r, div, amt, amt])
		main.tempo_manager.spaces_moved_this_cycle = 0

func _t_mad_scientist() -> void:
	print("-- Mad Scientist --")
	for r in [1, 15]:
		_only("mad_scientist", r)
		_fresh()
		var bm = main.player.get_buff_manager()
		pt._trigger_skill_tree_on_card_play(Card.create_by_id("draw"), null)
		pt._trigger_skill_tree_on_card_play(Card.create_by_id("healing_potion"), main.player)
		var rg = bm.get_buff(Buff.BuffType.REGEN)
		_check(rg != null and rg.value == int(_v("mad_scientist", "regen", r)), "Mad Scientist r%d: Utility → Heal potion: +%d regen" % [r, _v("mad_scientist", "regen", r)])
		pt._trigger_skill_tree_on_card_play(Card.create_by_id("slash"), null)
		pt._trigger_skill_tree_on_card_play(Card.create_by_id("healing_potion"), main.player)
		var st = bm.get_buff(Buff.BuffType.STRENGTHEN)
		_check(st != null and st.value == int(_v("mad_scientist", "strengthen", r)) and st.charges == 3, "Mad Scientist r%d: Attack → Heal potion: +%d strengthen for 3 attacks" % [r, _v("mad_scientist", "strengthen", r)])
		# Poison Bomb poisons every enemy around its aim: the riders land on them.
		var a: Enemy = dummies[0]
		var b: Enemy = dummies[1]
		var aim: Vector3 = gm.snap_to_grid(main.get_mouse_world_position())
		a.position = aim
		a.target_position = aim
		b.position = aim + Vector3(1, 0, 0)
		b.target_position = b.position
		pt._trigger_skill_tree_on_card_play(Card.create_by_id("draw"), null)
		var bomb := Card.create_by_id("poison_bomb")
		main._apply_card_world_effects(bomb, null)
		_check(a.poison_stacks == 6 and b.poison_stacks == 6, "Mad Scientist r%d: (Poison Bomb poisons both enemies at its aim for 6)" % r)
		pt._trigger_skill_tree_on_card_play(bomb, null)
		var extra: int = _v("mad_scientist", "poison", r)
		_check(a.poison_stacks == 6 + extra and b.poison_stacks == 6 + extra, "Mad Scientist r%d: Utility → Poison Bomb: +%d poison on every enemy it poisoned (%d, %d)" % [r, extra, a.poison_stacks, b.poison_stacks])
		pt._trigger_skill_tree_on_card_play(Card.create_by_id("block"), null)
		main._apply_card_world_effects(bomb, null)
		pt._trigger_skill_tree_on_card_play(bomb, null)
		var pd: int = _v("mad_scientist", "phys_defense", r)
		_check(is_equal_approx(a.get_phys_defense_debuff_percent(), float(pd)) and is_equal_approx(b.get_phys_defense_debuff_percent(), float(pd)),
			"Mad Scientist r%d: Defense → Poison Bomb: -%d%% physical defense on them for 5 tempo" % [r, pd])
		a._tick_timed_statuses(5)
		_check(is_equal_approx(a.get_phys_defense_debuff_percent(), 0.0), "Mad Scientist r%d: the lowered defense ends after 5 tempo" % r)
		b._tick_timed_statuses(5)

func _t_eye_scrape() -> void:
	print("-- Eye Scrape --")
	for r in [1, 15]:
		_only("eye_scrape", r)
		_fresh()
		var n: int = _v("eye_scrape", "crits_required", r)
		var bm = main.player.get_buff_manager()
		stats.st_crit_counter = 0
		stats.st_eye_scrape_last_tempo = -1000
		for _i in range(n - 1):
			pt._trigger_skill_tree_on_crit(dummies[0])
		_check(bm.get_buff(Buff.BuffType.INVISIBLE) == null, "Eye Scrape r%d: %d crits do nothing" % [r, n - 1])
		pt._trigger_skill_tree_on_crit(dummies[0])
		var inv = bm.get_buff(Buff.BuffType.INVISIBLE)
		_check(inv != null and inv.duration == 5, "Eye Scrape r%d: the %dth critical strike grants invisibility for 5 tempo" % [r, n])
		bm.remove_buff(Buff.BuffType.INVISIBLE)
		for _i in range(n):
			pt._trigger_skill_tree_on_crit(dummies[0])
		_check(bm.get_buff(Buff.BuffType.INVISIBLE) == null, "Eye Scrape r%d: within the 10-tempo cooldown nothing" % r)
		_advance(10)
		pt._trigger_skill_tree_on_crit(dummies[0])
		_check(bm.get_buff(Buff.BuffType.INVISIBLE) != null, "Eye Scrape r%d: after 10 tempo the counted crits fire it" % r)
		bm.remove_buff(Buff.BuffType.INVISIBLE)
		main._set_player_invisible(false)
	# A multi-hit card that crits on several hits is several critical strikes.
	_only("eye_scrape", 13)  # every 3rd crit
	_fresh()
	var bm2 = main.player.get_buff_manager()
	stats.st_crit_counter = 0
	stats.st_eye_scrape_last_tempo = -1000
	var e: Enemy = dummies[0]
	_put(e, Vector2i(3, 0))
	bm2.apply_buff(Buff.create_enlightened(100, 3, "test"))
	var ms := Card.create_by_id("multishot")
	_resolve(ms, e)
	_check(bm2.get_buff(Buff.BuffType.INVISIBLE) != null, "Eye Scrape: a Multishot critting on all 3 hits counts 3 critical strikes (rank 13: every 3rd)")
	bm2.remove_buff(Buff.BuffType.INVISIBLE)
	main._set_player_invisible(false)

# ============================================================
# STEPHEN
# ============================================================

func _t_deadly() -> void:
	print("-- Deadly --")
	for r in [1, 15]:
		_only("deadly", r)
		_fresh()
		var e: Enemy = dummies[0]
		_put(e, Vector2i(2, 0))
		_check(pt.deadly_flat_bonus(e) == int(_v("deadly", "damage", r)), "Deadly r%d: +%d damage on a target with no allies within 2 spaces" % [r, _v("deadly", "damage", r)])
		pt.arm_pre_attack_passives(Card.create_by_id("slash"), e)
		var mult: float = stats.get_crit_damage_multiplier()
		pt.clear_pre_attack_passives()
		var mult_off: float = stats.get_crit_damage_multiplier()
		_check(is_equal_approx(mult - mult_off, int(_v("deadly", "crit_damage", r)) / 100.0),
			"Deadly r%d: and +%d%% crit damage (x%.2f vs x%.2f)" % [r, _v("deadly", "crit_damage", r), mult, mult_off])
		_put(dummies[1], Vector2i(2, 2))
		_check(pt.deadly_flat_bonus(e) == 0, "Deadly r%d: an ally 2 spaces from the target cancels it" % r)

func _t_clean_exchange() -> void:
	print("-- Clean Exchange --")
	for r in [1, 15]:
		_only("clean_exchange", r)
		_fresh()
		var blk: int = _v("clean_exchange", "block", r)
		pt._trigger_skill_tree_on_card_play(Card.create_by_id("slash"), null)
		var d := Card.create_by_id("block")
		pt._trigger_skill_tree_on_draw(d)
		_check(d.temp_hand_tempo_reduction == 1 and d.temp_flat_block == blk, "Clean Exchange r%d: a Defense drawn after an offensive play: -1t and +%d block" % [r, blk])
		pt._trigger_skill_tree_on_card_play(Card.create_by_id("block"), null)
		var o := Card.create_by_id("slash")
		pt._trigger_skill_tree_on_draw(o)
		_check(o.temp_hand_tempo_reduction == 1 and o.temp_flat_block == blk, "Clean Exchange r%d: vice versa: an attack drawn after a Defense play" % r)
		var u := Card.create_by_id("draw")
		pt._trigger_skill_tree_on_draw(u)
		_check(u.temp_hand_tempo_reduction == 0 and u.temp_flat_block == 0, "Clean Exchange r%d: a utility drawn gets nothing" % r)
		stats.current_armor = 0
		var e: Enemy = dummies[0]
		_put(e, Vector2i(1, 0))
		o.tempo_cost = maxi(0, o.tempo_cost - o.temp_hand_tempo_reduction)
		_resolve(o, e)
		_check(stats.current_armor == blk and e.current_health < e.max_health, "Clean Exchange r%d: the attack deals its damage and gains the %d block when played" % [r, blk])

func _t_eagle_eye() -> void:
	print("-- Eagle Eye --")
	for r in [1, 15]:
		_only("eagle_eye", r)
		_fresh()
		var ms := Card.create_by_id("multishot")
		var rng: int = maxi(1, main._ranged_card_max_range(ms, true))
		var bonus: int = maxi(1, roundi(rng * int(_v("eagle_eye", "multiplier", r)) / 100.0))
		var got: int = pt._trigger_skill_tree_stephen_on_attack(ms, null, null)
		_check(got == bonus, "Eagle Eye r%d: a ranged offensive card adds %d%% of its range %d = +%d (got %d)" % [r, _v("eagle_eye", "multiplier", r), rng, bonus, got])
		_check(pt._trigger_skill_tree_stephen_on_attack(Card.create_by_id("slash"), null, null) == 0, "Eagle Eye r%d: a melee card gets nothing" % r)

func _t_patience() -> void:
	print("-- Patience is a Virtue --")
	for r in [1, 15]:
		_only("patience_is_a_virtue", r)
		_fresh()
		pt._trigger_skill_tree_stephen_on_glut(10)
		var n := 0
		for c in dm.hand:
			if c.card_id == "endured_tolerance":
				n += 1
		_check(n == 2, "Patience is a Virtue r%d: 10 Glut puts 2 Endured Tolerance in hand (%d)" % [r, n])
		var et := _hand_has("endured_tolerance")
		if et:
			_check(et.card_type == Card.CardType.DEFENSE and et.mana_cost == 20 and et.tempo_cost == 1 and et.erase_tempo == 20,
				"Patience is a Virtue r%d: Endured Tolerance is a 20m/1t Defense with Erase 20" % r)
			et.execute(null, stats, dm, 0.0, 0.0, main.player.get_buff_manager())
			var res = main.player.get_buff_manager().get_buff(Buff.BuffType.RESILIENT)
			var pct: int = _v("patience_is_a_virtue", "resist", r)
			_check(res != null and res.value == pct and res.duration == 5 and res.damage_type == -1, "Patience is a Virtue r%d: it grants %d%% resistance to all damage for 5 tempo" % [r, pct])
			_hand_has("endured_tolerance").execute(null, stats, dm, 0.0, 0.0, main.player.get_buff_manager())
			res = main.player.get_buff_manager().get_buff(Buff.BuffType.RESILIENT)
			_check(res != null and res.value == pct and res.duration == 10, "Patience is a Virtue r%d: another copy adds 5 more tempo" % r)

func _t_easy_target() -> void:
	print("-- Easy Target --")
	for r in [1, 15]:
		_only("easy_target", r)
		_fresh()
		var e: Enemy = dummies[0]
		e.max_armor = 10
		e.current_armor = 10
		e.exposed_cooldown_tempo = 0
		e.take_damage(30, true)
		var lost: int = e.max_health - e.current_health
		var st = main.player.get_buff_manager().get_buff(Buff.BuffType.STRENGTHEN)
		_check(lost == 20 + 30, "Easy Target r%d: exposing the enemy deals the 30 hit again (20 through armor + 30 = %d)" % [r, lost])
		_check(st != null and st.value == r and st.charges == 3, "Easy Target r%d: and +%d Strengthen for 3 attacks" % [r, r])

func _t_exposed_blind_spot() -> void:
	print("-- Exposed Blind Spot --")
	for r in [1, 15]:
		_only("exposed_blind_spot", r)
		_fresh()
		var e: Enemy = dummies[0]
		var per: float = _v("exposed_blind_spot", "crit_per_card", r)
		dm.hand.append(Card.create_by_id("block"))
		dm.hand.append(Card.create_by_id("fireball"))
		dm.hand.append(Card.create_by_id("slash"))
		stats.st_exposed_blind_spot_crit = 0.0
		_put(e, Vector2i(4, 0))
		main._on_enemy_attacked_player(e, main.player)
		_check(stats.st_exposed_blind_spot_crit == 0.0, "Exposed Blind Spot r%d: a ranged blow arms nothing" % r)
		_put(e, Vector2i(1, 0))
		main._on_enemy_attacked_player(e, main.player)
		_check(is_equal_approx(stats.st_exposed_blind_spot_crit, 2 * per), "Exposed Blind Spot r%d: a melee blow arms %.2f%% per non-attack card (2 → %.2f)" % [r, per, stats.st_exposed_blind_spot_crit])
		pt.arm_pre_attack_passives(Card.create_by_id("slash"), e)
		main.player.get_buff_manager().roll_crit()
		pt.clear_pre_attack_passives()
		_check(stats.st_exposed_blind_spot_crit == 0.0, "Exposed Blind Spot r%d: spent on the next attack's roll" % r)

func _t_scouted() -> void:
	print("-- Scouted --")
	for r in [1, 15]:
		_only("scouted", r)
		_fresh()
		var e: Enemy = dummies[0]
		stats.st_scouted_target_id = -1
		stats.st_scouted_hits = 0
		stats.st_scouted_bonus_active = false
		for _i in range(3):
			pt._trigger_skill_tree_stephen_on_attack(Card.create_by_id("slash"), e)
		_check(stats.st_scouted_bonus_active, "Scouted r%d: 3 hits in a row on one enemy arm it" % r)
		var ms := Card.create_by_id("multishot")
		var base_range: int = main._ranged_card_max_range(ms, true)
		stats.st_scouted_bonus_active = false
		var off_range: int = main._ranged_card_max_range(ms, true)
		stats.st_scouted_bonus_active = true
		_check(base_range - off_range == int(_v("scouted", "range", r)), "Scouted r%d: +%d range on the next attack (%d vs %d)" % [r, _v("scouted", "range", r), base_range, off_range])
		var mult_off: float = stats.get_crit_damage_multiplier()
		pt.arm_pre_attack_passives(Card.create_by_id("slash"), dummies[1])
		var mult: float = stats.get_crit_damage_multiplier()
		var crit_hit: bool = main.player.get_buff_manager().roll_crit()
		pt.clear_pre_attack_passives()
		_check(crit_hit, "Scouted r%d: the next attack on ANY enemy auto-crits" % r)
		_check(is_equal_approx(mult - mult_off, 2 * r / 100.0), "Scouted r%d: with +%d%% crit damage (x%.2f vs x%.2f)" % [r, 2 * r, mult, mult_off])
		pt._trigger_skill_tree_stephen_on_attack(Card.create_by_id("slash"), dummies[1])
		_check(not stats.st_scouted_bonus_active, "Scouted r%d: spent by that attack" % r)

func _t_swing_for_the_fences() -> void:
	print("-- Swing for the Fences --")
	for r in [1, 15]:
		_only("swing_for_the_fences", r)
		_fresh()
		var e: Enemy = dummies[0]
		var ms := Card.create_by_id("multishot")  # 6 tempo
		var expect: int = maxi(1, roundi(6 * int(_v("swing_for_the_fences", "multiplier", r)) / 100.0))
		_check(pt._trigger_skill_tree_stephen_on_attack(ms, e) == expect, "Swing for the Fences r%d: a 6-tempo card deals %d%% of 6 = +%d" % [r, _v("swing_for_the_fences", "multiplier", r), expect])
		var s := Card.create_by_id("slash")
		s.tempo_cost = 4
		_check(pt._trigger_skill_tree_stephen_on_attack(s, e) == 0, "Swing for the Fences r%d: 4 tempo is not >4" % r)
		_put(e, Vector2i(2, 0))
		var big := Card.create_by_id("block")
		big.tempo_cost = 5
		pt._trigger_skill_tree_stephen_on_attack(big, null)
		var exp5: int = maxi(1, roundi(5 * int(_v("swing_for_the_fences", "multiplier", r)) / 100.0))
		_check(e.max_health - e.current_health == exp5, "Swing for the Fences r%d: a damageless 5-tempo card sends +%d to the nearest enemy" % [r, exp5])

func _t_skilled_momentum() -> void:
	print("-- Skilled Momentum --")
	for r in [1, 15]:
		_only("skilled_momentum", r)
		_fresh()
		var n: int = _v("skilled_momentum", "attacks_required", r)
		stats.st_consecutive_attacks = 0
		stats.st_skilled_momentum_last_tempo = -1000
		stats.st_skilled_momentum_echo = false
		for _i in range(n):
			pt._trigger_skill_tree_stephen_on_attack(Card.create_by_id("slash"), null)
		_check(not stats.st_skilled_momentum_echo, "Skilled Momentum r%d: %d attacks in a row arm nothing yet" % [r, n])
		pt._trigger_skill_tree_stephen_on_attack(Card.create_by_id("slash"), null)
		_check(stats.st_skilled_momentum_echo, "Skilled Momentum r%d: the next attack after %d in a row is played twice" % [r, n])
		stats.st_skilled_momentum_echo = false
		for _i in range(n + 1):
			pt._trigger_skill_tree_stephen_on_attack(Card.create_by_id("slash"), null)
		_check(not stats.st_skilled_momentum_echo, "Skilled Momentum r%d: within the 10-tempo cooldown no" % r)
		stats.st_consecutive_attacks = 0
		for _i in range(n - 1):
			pt._trigger_skill_tree_stephen_on_attack(Card.create_by_id("slash"), null)
		pt._trigger_skill_tree_stephen_on_card_play(Card.create_by_id("draw"))
		_check(stats.st_consecutive_attacks == 0, "Skilled Momentum r%d: a non-attack breaks the streak" % r)
	# The echo really plays the card twice (main's resolve path).
	_only("skilled_momentum", 15)
	_fresh()
	var e: Enemy = dummies[0]
	_put(e, Vector2i(1, 0))
	stats.st_consecutive_attacks = 3
	stats.st_skilled_momentum_last_tempo = -1000
	var s := Card.create_by_id("slash")
	_resolve(s, e)
	var once: int = s.last_damage_dealt
	_check(once > 0 and e.max_health - e.current_health >= 2 * once - 1, "Skilled Momentum: the armed attack lands twice (%d total, %d each)" % [e.max_health - e.current_health, once])

func _t_lethal_resourcefulness() -> void:
	print("-- Lethal Resourcefulness --")
	for r in [1, 15]:
		_only("lethal_resourcefulness", r)
		_fresh()
		var cd: int = _v("lethal_resourcefulness", "cooldown", r)
		stats.st_lethal_last_tempo = -1000
		var e: Enemy = dummies[0]
		_put(e, Vector2i(1, 0))
		for _i in range(4):
			dm.hand.append(Card.create_by_id("block"))
		pt._trigger_skill_tree_stephen_on_card_play(Card.create_by_id("draw"))
		_check(e.current_health == e.max_health, "Lethal Resourcefulness r%d: 4 cards in hand: no free attack" % r)
		dm.hand.pop_back()
		pt._trigger_skill_tree_stephen_on_card_play(Card.create_by_id("slash"))
		_check(e.current_health == e.max_health, "Lethal Resourcefulness r%d: an attack card does not trigger it" % r)
		main.player.get_buff_manager().apply_buff(Buff.create_steady("test"))
		pt._trigger_skill_tree_stephen_on_card_play(Card.create_by_id("draw"))
		_check(e.current_health < e.max_health and stats.st_lethal_last_tempo == _now(), "Lethal Resourcefulness r%d: 3 cards + a non-attack: a free basic attack" % r)
		var hp: int = e.current_health
		_advance(cd - 1)
		pt._trigger_skill_tree_stephen_on_card_play(Card.create_by_id("draw"))
		_check(e.current_health == hp, "Lethal Resourcefulness r%d: within the %d-tempo cooldown no" % [r, cd])

func _t_elemental_conclusion() -> void:
	print("-- Elemental Conclusion --")
	var e: Enemy = dummies[0]
	_only("elemental_conclusion", 15)
	_fresh()
	var plus := 0
	for _i in range(20):
		e.burn_stacks = 0
		e.apply_debuff("burn", 2)
		plus += e.burn_stacks - 2
	_check(plus == 20, "Elemental Conclusion r15: 100%% — every burn gets +1 charge (%d of 20)" % plus)
	e.cold_stacks = 0
	e.apply_debuff("cold", 1)
	e.shock_stacks = 0
	e.apply_debuff("shock", 1)
	_check(e.cold_stacks == 2 and e.shock_stacks == 2, "Elemental Conclusion r15: cold and shock too")
	e.poison_stacks = 0
	e.apply_debuff("poison", 1)
	_check(e.poison_stacks == 1, "Elemental Conclusion r15: poison is not one of the three")
	_only("elemental_conclusion", 1)
	seed(12345)
	plus = 0
	for _i in range(400):
		e.burn_stacks = 0
		e.apply_debuff("burn", 2)
		plus += e.burn_stacks - 2
	_check(plus > 150 and plus < 250, "Elemental Conclusion r1: about 50%% (%d of 400)" % plus)
	e.burn_stacks = 0
	e.cold_stacks = 0
	e.shock_stacks = 0

func _t_dominate() -> void:
	print("-- Dominate --")
	for r in [1, 15]:
		_only("dominate", r)
		_fresh()
		stats.st_dominate_cooldown = 0
		pt._trigger_skill_tree_stephen_on_dex_proc()
		var ba := _hand_has("basic_attack")
		var st = main.player.get_buff_manager().get_buff(Buff.BuffType.STRENGTHEN)
		_check(ba != null and ba.mana_cost == 30 and ba.tempo_cost == 0, "Dominate r%d: an attack speed proc adds a 30m/0t basic attack card" % r)
		_check(st != null and st.value == int(_v("dominate", "strengthen", r)) and st.charges == 3, "Dominate r%d: and +%d Strengthen for 3 attacks" % [r, _v("dominate", "strengthen", r)])
		dm.hand.clear()
		_advance(4)
		pt._trigger_skill_tree_stephen_on_dex_proc()
		_check(_hand_has("basic_attack") == null, "Dominate r%d: within the 5-tempo cooldown no" % r)
		_advance(1)
		pt._trigger_skill_tree_stephen_on_dex_proc()
		_check(_hand_has("basic_attack") != null, "Dominate r%d: after 5 tempo yes" % r)
