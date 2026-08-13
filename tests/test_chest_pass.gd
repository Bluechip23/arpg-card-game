extends SceneTree

## Chests pass 1: the 19 chest pieces — factories, granted cards, and the new
## combat channels (Exposed armor reactions, banked damage, thorns-by-damage,
## Keen/Might buffs, jail release, health costs, resist scaling).
## Run: godot --headless --path . --script tests/test_chest_pass.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _mk_stats() -> PlayerStats:
	var stats = PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(CharacterData.create_ryan())
	# A roomy health pool so damage-math checks never clip at 0.
	stats.max_health = 200
	stats.current_health = 200
	return stats

func _mk_inv(stats: PlayerStats) -> Inventory:
	var inv = Inventory.new()
	get_root().add_child(inv)
	inv.initialize("Ryan")
	inv.connect_player_stats(stats)
	return inv

func _initialize() -> void:
	print("=== Chests pass test ===")

	_test_roster()
	_test_weights_and_stats()
	_test_granted_cards()
	_test_exposed_reactions()
	_test_keen_and_might()
	_test_thorns_by_damage()
	_test_jail_release()
	_test_resist_scaling()
	_test_gold_heal()
	_test_movement_surcharge()
	_test_hannibals_rename()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_roster() -> void:
	print("-- Roster --")
	var chests: Array = []
	for item in ItemData.get_all_items():
		if item.item_type == ItemData.ItemType.CHEST:
			chests.append(item)
	_check(chests.size() == 19, "19 chest pieces exist (found %d)" % chests.size())
	var by_rarity := {ItemData.Rarity.COMMON: 0, ItemData.Rarity.RARE: 0,
		ItemData.Rarity.LEGENDARY: 0, ItemData.Rarity.MYTHIC: 0}
	for chest in chests:
		by_rarity[chest.rarity] += 1
	_check(by_rarity[ItemData.Rarity.COMMON] == 4, "4 common chests")
	_check(by_rarity[ItemData.Rarity.RARE] == 4, "4 rare chests")
	_check(by_rarity[ItemData.Rarity.LEGENDARY] == 7, "7 legendary chests")
	_check(by_rarity[ItemData.Rarity.MYTHIC] == 4, "4 mythic chests")
	for chest in chests:
		if chest.rarity == ItemData.Rarity.MYTHIC:
			_check(chest.appearance != "" and chest.appearance_icon != "",
				"%s ships appearance + icon" % chest.item_name)

func _test_weights_and_stats() -> void:
	print("-- Weights & stats --")
	# The four heavies came down 100 each in review.
	_check(ItemData.create_supernova_cuirass().weight == 250, "Supernova Cuirass weighs 250")
	_check(ItemData.create_briarhide_plate().weight == 300, "Briarhide Plate weighs 300")
	_check(ItemData.create_adimantium().weight == 350, "Adimantium weighs 350")
	_check(ItemData.create_divine_resistance().weight == 400, "Divine Resistance weighs 400")
	var cloth = ItemData.create_tattered_cloth()
	_check(cloth.item_name == "Tattered Cloth", "Tattered Cloth spelling")
	_check(cloth.determination_bonus == 2 and cloth.agility_bonus == 2 \
		and cloth.wisdom_bonus == 2 and cloth.dexterity_bonus == 2 and cloth.health_bonus == 5,
		"Tattered Cloth stat spread (balance: 5 health)")
	var plank = ItemData.create_wooden_plank()
	_check(plank.health_bonus == 15 and plank.low_health_regen == 1,
		"Wooden Plank: 15 health + 1 Regen below half")
	var velvet = ItemData.create_velvet_plate()
	_check(velvet.weight == 120 and velvet.strength_bonus == 5 and velvet.on_self_heal == 10,
		"Velvet Plate: w120, +5 STR, heal 10")
	var tigers = ItemData.create_tigers_sunday_red()
	_check(tigers.on_self_offensive_heal_percent == 3.0, "Tigers heals 3% (Lv3 6%)")
	var cowl = ItemData.create_shadow_cowl()
	_check(cowl.health_bonus == -10 and cowl.card_slots == 4, "Shadow Cowl: -10 health, 4 slots")
	var adim = ItemData.create_adimantium()
	adim.item_level = 2
	adim.level_up()  # -> 3
	_check(adim.exposed_armor_gain == 15 and adim.exposed_armor_cooldown_cycles == 10,
		"Adimantium Lv.3: 15 armor on armor-break, 10-cycle cooldown")
	var divine = ItemData.create_divine_resistance()
	_check(divine.resist_per_missing10 == 1.0 and divine.resist_missing_step == 8,
		"Divine Resistance: 1% per 8% missing")
	divine.item_level = 2
	divine.level_up()  # -> 3
	_check(divine.resist_per_missing10 == 1.5 and divine.resist_missing_step == 7,
		"Divine Resistance Lv.3: 1.5% per 7% missing")

func _test_granted_cards() -> void:
	print("-- Granted cards --")
	var cm_ids = ItemData.create_chain_mail().granted_card_ids
	_check(cm_ids.size() == 1 and cm_ids.has("clang_up"), "Chain Mail grants Clang Up")
	var trench = ItemData.create_trench_of_tranquility()
	_check(trench.granted_card_ids.has("mind_mend") and trench.granted_card_ids.has("deep_breaths"),
		"Trench of Tranquility grants Mind Mend + Deep Breaths")
	var mm = Card.create_by_id("mind_mend")
	_check(mm != null and mm.health_cost == 15 and mm.mana_cost == 0,
		"Mind Mend costs 15 health, no mana")
	var wall = Card.create_by_id("adimantium_wall")
	_check(wall.block == 40 and wall.jail_on_play == 40, "Adimantium Wall: 40 block, jailed 40")
	var rag = Card.create_by_id("ragnarok")
	_check(rag.jail_on_play == 30, "Ragnarok jails itself 30")
	var pa = Card.create_by_id("preemptive_answer")
	_check(pa.card_type == Card.CardType.REACTION and pa.reaction_trigger == "on_hp_below_25" \
		and pa.tempo_cost == 0, "Preemptive Answer is an instant on the 25% trigger")
	var dn = Card.create_by_id("detonova")
	_check(dn.damage_type == DamageTypes.Type.FIRE and dn.aoe_range == 2.0,
		"Detonova: fire, 2 squares around you")
	for cid in ["clang_up", "negotiate", "detonova", "mind_mend", "deep_breaths",
			"vined_encasing", "adimantium_wall", "preemptive_answer", "ragnarok"]:
		_check(Card.DROP_EXCLUDED_CARD_IDS.has(cid), "%s never drops randomly" % cid)

func _test_exposed_reactions() -> void:
	print("-- Exposed reactions --")
	var stats = _mk_stats()
	stats.base_strength = 60  # carry capacity for the 300/350-weight plates
	stats.strength = 60
	var inv = _mk_inv(stats)
	inv.enforce_mythic_limit = false  # level-gated; not what this test is about
	var briar = ItemData.create_briarhide_plate()
	var briar_ok := inv.equip_item(briar)
	_check(briar_ok, "Briarhide equips at 60 STR")
	var armor_before = stats.current_armor
	inv.on_player_exposed()
	_check(stats.current_armor >= armor_before + 5, "Briarhide: +5 armor when Exposed")
	var again = stats.current_armor
	inv.on_player_exposed()
	_check(stats.current_armor >= again + 5, "Briarhide has no cooldown")
	inv.unequip_item(ItemData.ItemType.CHEST, 0)

	var adim = ItemData.create_adimantium()
	var adim_ok := inv.equip_item(adim)
	_check(adim_ok, "Adimantium equips at 60 STR")
	var before_adim = stats.current_armor
	inv.on_player_exposed()
	_check(stats.current_armor >= before_adim + 10, "Adimantium: +10 armor when Exposed")
	_check(adim.exposed_armor_cd_left == 15, "Adimantium cooldown armed (15 cycles)")
	var cd_armor = stats.current_armor
	inv.on_player_exposed()
	_check(stats.current_armor == cd_armor, "Adimantium proc respects the cooldown")
	inv.process_turn()
	_check(adim.exposed_armor_cd_left == 14, "cooldown ticks down per cycle")
	stats.free()
	inv.free()

func _test_keen_and_might() -> void:
	print("-- Keen & Might (Ragnarok buffs) --")
	var stats = _mk_stats()
	var bm = BuffManager.new()
	get_root().add_child(bm)
	bm.initialize(stats)
	bm.apply_buff(Buff.create_keen(100, 10, "test"))
	_check(bm.roll_crit(0), "Keen 100% guarantees the crit roll")
	bm.apply_buff(Buff.create_might(5, 10, "test"))
	_check(stats.temp_strength_bonus == 5, "Might mirrors +5 STR onto temp_strength_bonus")
	var base_dmg = stats.get_strength_damage_bonus()
	bm.apply_buff(Buff.create_might(5, 10, "test"))
	_check(stats.temp_strength_bonus == 10, "Might stacks")
	_check(stats.get_strength_damage_bonus() >= base_dmg + 2, "Might raises STR damage")
	bm.remove_buff(Buff.BuffType.MIGHT)
	_check(stats.temp_strength_bonus == 0, "removing Might clears the bonus")
	stats.free()
	bm.free()

func _test_thorns_by_damage() -> void:
	print("-- Vined Encasing thorns --")
	var stats = _mk_stats()
	var bm = BuffManager.new()
	get_root().add_child(bm)
	bm.initialize(stats)
	var vined = Buff.create_thorns(20, 20, "Vined Encasing")
	vined.decay_by_damage = true
	bm.apply_buff(vined)
	bm.decay_thorns_by_damage(7)
	_check(bm.get_thorns_damage() == 13, "thorns shed value equal to damage received (20 - 7)")
	bm.decay_thorns_by_damage(13)
	_check(not bm.has_buff(Buff.BuffType.THORNS), "thorns buff dies at 0")
	# Ordinary thorns still decay 1 per hit and ignore the damage path.
	bm.apply_buff(Buff.create_thorns(5, 15, "Studded belt"))
	bm.decay_thorns_by_damage(3)
	_check(bm.get_thorns_damage() == 5, "normal thorns ignore damage decay")
	stats.free()
	bm.free()

func _test_jail_release() -> void:
	print("-- Ragnarok jail release --")
	var dm = DeckManager.new()
	get_root().add_child(dm)
	var jailed_a = Card.create_by_id("clang_up")
	jailed_a.jail_time_remaining = 25
	var jailed_b = Card.create_by_id("deep_breaths")
	jailed_b.jail_time_remaining = 40
	var rag = Card.create_by_id("ragnarok")
	rag.jail_time_remaining = 30
	dm.jail_pile.append(jailed_a)
	dm.jail_pile.append(jailed_b)
	dm.jail_pile.append(rag)
	var released = dm.release_jailed_to_hand(rag)
	_check(released == 2, "released the 2 other jailed cards")
	_check(dm.jail_pile.size() == 1 and dm.jail_pile[0] == rag,
		"Ragnarok stays jailed while it releases the others")
	_check(dm.hand.has(jailed_a) and dm.hand.has(jailed_b), "released cards land in hand")
	_check(jailed_a.jail_time_remaining == 0, "released cards carry no jail time")
	dm.free()

func _test_resist_scaling() -> void:
	print("-- Resist scaling --")
	# Divine Resistance: 1% per full 8% missing health.
	var stats = _mk_stats()
	stats.equipment_resist_per_missing10 = 1.0
	stats.equipment_resist_missing_step = 8
	stats.current_health = 100  # 50% missing -> 6 full steps of 8% -> +6%
	var hp_before: int = stats.current_health
	stats.take_damage(100)
	var dmg_taken: int = hp_before - stats.current_health
	_check(dmg_taken == 94, "at 50%% missing health, 100 damage lands as 94 (took %d)" % dmg_taken)
	stats.free()

	# Smithed Excellence: +10% physical resist only while armor is up.
	var stats2 = _mk_stats()
	stats2.equipment_block_physical_resist = 10.0
	var hp2: int = stats2.current_health
	stats2.take_damage(100)
	_check(hp2 - stats2.current_health == 100, "no armor -> no block resist (took %d)" % (hp2 - stats2.current_health))
	var stats3 = _mk_stats()
	stats3.equipment_block_physical_resist = 10.0
	stats3.current_armor = 20
	var hp3: int = stats3.current_health + stats3.current_armor
	stats3.take_damage(100)
	var total_lost: int = hp3 - (stats3.current_health + stats3.current_armor)
	_check(total_lost == 90, "with armor up, 100 physical lands as 90 (took %d)" % total_lost)
	stats2.free()
	stats3.free()

	# Supernova Cuirass: 10% absorbed into the cuirass, 2% mitigated outright.
	var stats4 = _mk_stats()
	stats4.base_strength = 60  # carry capacity for the 250-weight cuirass
	stats4.strength = 60
	var inv4 = _mk_inv(stats4)
	var nova = ItemData.create_supernova_cuirass()
	_check(inv4.equip_item(nova), "Supernova equips")
	var hp4: int = stats4.current_health
	stats4.take_damage(100)
	_check(is_equal_approx(nova.banked_damage, 10.0), "absorbed 10 into the cuirass (banked %.1f)" % nova.banked_damage)
	_check(nova.banked_stacks == 1, "one stack per hit")
	_check(hp4 - stats4.current_health == 88, "hit reduced by 12%% (took %d)" % (hp4 - stats4.current_health))
	nova.banked_stacks = nova.damage_bank_max_stacks
	var hp5: int = stats4.current_health
	stats4.take_damage(100)
	_check(hp5 - stats4.current_health == 100, "a full cuirass absorbs nothing")
	stats4.free()
	inv4.free()

	# Armor break: the signal that drives Briarhide/Adimantium reactions.
	var stats5 = _mk_stats()
	var broke := [0]
	stats5.armor_broken.connect(func(): broke[0] += 1)
	stats5.current_armor = 10
	stats5.take_damage(30)
	_check(broke[0] == 1, "breaking through armor emits armor_broken")
	stats5.take_damage(30)
	_check(broke[0] == 1, "armorless hits do not emit armor_broken")
	stats5.free()

func _test_gold_heal() -> void:
	print("-- Suit and Tie gold heal --")
	var stats = _mk_stats()
	stats.equipment_gold_gain_heal = 3
	stats.take_direct_damage(10)
	var hp: int = stats.current_health
	stats.gain_gold(5)
	_check(stats.current_health >= hp + 3, "gaining gold heals at least the base 3")
	stats.free()

func _test_movement_surcharge() -> void:
	print("-- Adimantium movement --")
	var tm = TempoManager.new()
	get_root().add_child(tm)
	var stats = _mk_stats()
	tm.player_stats = stats
	var before: int = tm.global_tempo
	tm.add_movement_tempo()
	_check(tm.global_tempo == before + 1, "a tile normally costs 1 tempo")
	stats.movement_tempo_surcharge = 1
	tm.add_movement_tempo()
	_check(tm.global_tempo == before + 3, "with Adimantium, a tile costs 2 tempo")
	# Shadow Cowl shift: free tiles cost nothing at all.
	stats.free_move_tiles = 2
	tm.add_movement_tempo()
	tm.add_movement_tempo()
	_check(tm.global_tempo == before + 3, "shift tiles are tempo-free")
	_check(stats.free_move_tiles == 0, "shift tiles are consumed")
	stats.free()
	tm.free()

func _test_hannibals_rename() -> void:
	print("-- Hannibals Mask rename --")
	var mask = ItemData.create_hannibals_mask()
	_check(mask.item_name == "Hannibals Mask", "the mask is spelled Hannibals")
	_check(ItemData.create_by_name("Hannibals Mask") != null, "create_by_name finds the new spelling")
	var old = ItemData.create_by_name("Hanibals Mask")
	_check(old != null and old.item_name == "Hannibals Mask",
		"old saves with the misspelling still resolve (alias)")
