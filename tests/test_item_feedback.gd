extends SceneTree

## Item feedback pass: Armor Chopper on melee attacks and the auto attack,
## Earth Book / Thick Steel on armor-granting cards of any type (and no
## leak), the elemental books on every damaging offensive card, Megingjörð
## doubling the whole hit, Blue Robe re-rolling per enemy, the Girdle on
## tagged instants, Tigers on ranged offensive only, Belthronding sharing
## every ally's damage but the wearer's own, Close is Favored on entry
## only, the Nine Ruins 5-tempo window, Wrath of the Sea shoving to the
## burst's edge, the Bastion's armor coming back, Burgonet as the unerring
## clock, and the gauntlet skills' mana.
## Run: godot --headless --path . --script tests/test_item_feedback.gd

var failures := 0
var main = null

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Item feedback test ===")
	_run()

func _place(gm, who, cell: Vector2i) -> void:
	who.position = gm.grid_to_world(cell)
	if "target_position" in who:
		who.target_position = who.position

func _slot(card: Card, item: ItemData) -> Card:
	card.slotted_in_item = item
	item.slotted_cards.append(card)
	return card

func _reset_dummy(d: Enemy) -> void:
	d.max_health = 1000
	d.current_health = 1000
	d.current_armor = 0
	d.damage_resistances = {}

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
	var inv = main.player.get_inventory()
	var dummies: Array = main.enemy_spawner.get_living_enemies()
	_check(dummies.size() >= 2, "the dojo has two dummies (%d)" % dummies.size())
	stats.max_health = maxi(stats.max_health, 100)
	stats.current_health = stats.max_health
	inv.enforce_mythic_limit = false
	inv._bulk_build_switch = true
	for d in dummies:
		_reset_dummy(d)
	stats.equipment_crit_bonus = -100.0  # exact comparisons: no random crits

	_test_gauntlet_mana()
	_test_burgonet()
	_test_armor_chopper(stats, dm, bm, inv, dummies[0])
	_test_armor_riders(stats, dm, bm, dummies[0])
	_test_books(stats, dm, bm, dummies[0])
	_test_megingjord(stats, dm, bm, dummies[0])
	_test_blue_robe(stats, dm, bm, dummies)
	_test_girdle(stats, dm, bm, dummies[0])
	_test_tigers(stats)
	_test_belthronding(stats, inv, dummies[0])
	_test_close_is_favored(stats, dm, dummies[0])
	_test_nine_ruins(stats, dm, inv, dummies[0])
	_test_wrath_edge(dummies)
	_test_bastion(stats, dummies[0])

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_gauntlet_mana() -> void:
	print("-- Gauntlet skill mana --")
	var want: Array = [
		[ItemData.create_gravity_gauntlets(), "Suck", 10],
		[ItemData.create_spiked_mitts(), "Well placed guard", 15],
		[ItemData.create_cuffs_of_current(), "Zeet", 35],
		[ItemData.create_copper_bracers(), "Clang", 25],
		[ItemData.create_fanned_bracers(), "Fan Save", 25],
	]
	for row in want:
		var item: ItemData = row[0]
		_check(item.gauntlet_skill_name == row[1] and item.gauntlet_skill_mana_cost == row[2],
			"%s: %s costs %d mana (%d)" % [item.item_name, row[1], row[2], item.gauntlet_skill_mana_cost])

func _test_burgonet() -> void:
	print("-- Burgonet is only the unerring clock --")
	var b := ItemData.create_burgonet()
	_check(b.block_bonus_to_defense_cards == 0 and b.block_to_armorless_defense_cards == 0,
		"no card riders remain")
	_check(b.special_effect == ItemData.SpecialEffect.ARMOR_PER_TURN and b.special_effect_value == 2 \
		and b.armor_per_tempo_interval == 5, "2 armor every 5 tempo")

func _test_armor_chopper(stats, dm, bm, inv, d: Enemy) -> void:
	print("-- Armor Chopper: melee attack cards and the auto attack --")
	stats.equipment_armor_shred = 10
	_reset_dummy(d)
	d.current_armor = 500
	var slash := Card.create_slash()
	slash.execute(d, stats, dm, 0.0, 0.0, bm)
	var after_slash: int = d.current_armor
	stats.equipment_armor_shred = 0
	d.current_armor = 500
	Card.create_slash().execute(d, stats, dm, 0.0, 0.0, bm)
	_check(d.current_armor - after_slash == 10, "Slash shreds 10 extra armor (%d)" % (d.current_armor - after_slash))
	stats.equipment_armor_shred = 10
	d.current_armor = 500
	var vm := Card.create_volatile_mixture()
	vm.execute(d, stats, dm, 0.0, 0.0, bm)
	var vm_on: int = d.current_armor
	stats.equipment_armor_shred = 0
	d.current_armor = 500
	Card.create_volatile_mixture().execute(d, stats, dm, 0.0, 0.0, bm)
	_check(d.current_armor == vm_on, "a damaging utility card shreds nothing extra")
	stats.equipment_armor_shred = 10
	d.current_armor = 500
	var fb := Card.create_fireball()
	fb.execute(d, stats, dm, 0.0, 0.0, bm)
	var fb_on: int = d.current_armor
	stats.equipment_armor_shred = 0
	d.current_armor = 500
	Card.create_fireball().execute(d, stats, dm, 0.0, 0.0, bm)
	_check(fb.is_ranged and d.current_armor == fb_on, "a ranged attack card (Fireball) shreds nothing extra")
	# The auto attack is a melee attack.
	var gm = main.grid_manager
	var pcell: Vector2i = gm.world_to_grid(main.player.position)
	_place(gm, d, pcell + Vector2i(1, 0))
	stats.equipment_armor_shred = 10
	d.current_armor = 500
	main._execute_basic_attack(d, true)
	var ba_on: int = d.current_armor
	stats.equipment_armor_shred = 0
	d.current_armor = 500
	main._execute_basic_attack(d, true)
	_check(d.current_armor - ba_on == 10, "the auto attack shreds 10 extra armor (%d)" % (d.current_armor - ba_on))
	# A bow's shot is not.
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	inv.unequip_item(ItemData.ItemType.WEAPON, 1)
	_check(inv.equip_item(ItemData.create_short_bow(), 0), "a bow equips")
	_place(gm, d, pcell + Vector2i(3, 0))
	stats.equipment_armor_shred = 10
	d.current_armor = 500
	main._execute_basic_attack(d, true)
	var bow_on: int = d.current_armor
	stats.equipment_armor_shred = 0
	d.current_armor = 500
	main._execute_basic_attack(d, true)
	_check(main._basic_attack_reach() == 5, "the bow reaches 5 (%d)" % main._basic_attack_reach())
	_check(d.current_armor < 500, "the bow's auto attack lands at 3 tiles (armor %d)" % d.current_armor)
	_check(d.current_armor == bow_on, "a bow's auto attack shreds nothing extra (%d vs %d)" % [d.current_armor, bow_on])
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	_reset_dummy(d)

func _test_armor_riders(stats, dm, bm, d: Enemy) -> void:
	print("-- Earth Book / Thick Steel: armor-granting cards of any type --")
	stats.equipment_defense_card_block = 1
	stats.current_armor = 0
	Card.create_parry().execute(d, stats, dm, 0.0, 0.0, bm)
	_check(stats.current_armor == 6, "Parry (defense, 5 armor) grants 6 (%d)" % stats.current_armor)
	stats.current_armor = 0
	Card.create_vengeful_shield().execute(main.player, stats, dm, 0.0, 0.0, bm)
	_check(stats.current_armor == 6, "Vengeful Shield (an instant, 5 armor) grants 6 (%d)" % stats.current_armor)
	stats.current_armor = 0
	Card.create_slash().execute(d, stats, dm, 0.0, 0.0, bm)
	_check(not stats.defense_card_bonus_pending, "an armorless card leaves the rider disarmed")
	stats.add_armor(3)
	_check(stats.current_armor == 3, "a later plain armor gain carries no leftover bonus (%d)" % stats.current_armor)
	stats.equipment_defense_card_block = 0
	stats.current_armor = 0

func _hit(card: Card, stats, dm, bm, d: Enemy) -> int:
	_reset_dummy(d)
	card.execute(d, stats, dm, 0.0, 0.0, bm)
	return 1000 - d.current_health

func _test_books(stats, dm, bm, d: Enemy) -> void:
	print("-- Fire / Frost Book, Ice Orb: every damaging offensive card --")
	stats.equipment_attack_card_damage = 0
	var slash_base: int = _hit(Card.create_slash(), stats, dm, bm, d)
	var fb0 := Card.create_fireball()  # its AoE lands in main: read the computed hit
	_hit(fb0, stats, dm, bm, d)
	var fb_base: int = fb0.last_damage_dealt
	var vm_base: int = _hit(Card.create_volatile_mixture(), stats, dm, bm, d)
	stats.equipment_attack_card_damage = 1
	var slash_on: int = _hit(Card.create_slash(), stats, dm, bm, d)
	var fb1 := Card.create_fireball()
	_hit(fb1, stats, dm, bm, d)
	var fb_on: int = fb1.last_damage_dealt
	var vm_on: int = _hit(Card.create_volatile_mixture(), stats, dm, bm, d)
	stats.equipment_attack_card_damage = 0
	_check(slash_on >= slash_base + 1, "Slash deals +1 (%d → %d)" % [slash_base, slash_on])
	_check(fb_base > 0 and fb_on >= fb_base + 1, "Fireball, an offensive spell, deals +1 (%d → %d)" % [fb_base, fb_on])
	_check(vm_on == vm_base, "Volatile Mixture, a damaging utility, gets nothing (%d → %d)" % [vm_base, vm_on])

func _test_megingjord(stats, dm, bm, d: Enemy) -> void:
	print("-- Megingjörð: the whole hit is doubled --")
	# No crits: the innate 5% would spoil an exact doubling.
	var crit_prev: float = stats.equipment_crit_bonus
	stats.equipment_crit_bonus = -100.0
	var belt := ItemData.create_megingjord()
	var plain: int = _hit(Card.create_slash(), stats, dm, bm, d)
	var doubled: int = _hit(_slot(Card.create_slash(), belt), stats, dm, bm, d)
	_check(doubled == plain * 2, "a slotted Slash deals exactly twice (%d vs %d)" % [doubled, plain])
	_check(PlayerStats.hit_multiplier == 1.0, "the multiplier is cleared when the card finishes")
	var vm_plain: int = _hit(Card.create_volatile_mixture(), stats, dm, bm, d)
	var vm_slot: int = _hit(_slot(Card.create_volatile_mixture(), belt), stats, dm, bm, d)
	_check(vm_slot == vm_plain, "a slotted non-offensive card is not doubled (%d vs %d)" % [vm_slot, vm_plain])
	stats.equipment_crit_bonus = crit_prev

func _hit_resisting(card: Card, res: Dictionary, stats, dm, bm, d: Enemy) -> int:
	_reset_dummy(d)
	d.damage_resistances = res.duplicate()
	card.execute(d, stats, dm, 0.0, 0.0, bm)
	return 1000 - d.current_health

func _test_blue_robe(stats, dm, bm, dummies: Array) -> void:
	print("-- Blue Robe: each enemy struck takes the type it resists least --")
	var a: Enemy = dummies[0]
	var b: Enemy = dummies[1]
	_reset_dummy(a)
	_reset_dummy(b)
	a.damage_resistances = {DamageTypes.Type.FIRE: 50.0, DamageTypes.Type.PHYSICAL: 0.0}
	b.damage_resistances = {DamageTypes.Type.FIRE: 0.0, DamageTypes.Type.PHYSICAL: 50.0}
	PlayerStats.adaptive_damage_type = false
	b.take_damage(20, true, DamageTypes.Type.PHYSICAL)
	_check(1000 - b.current_health == 10, "without the robe a physical hit on the physical-resister is halved (%d)" % (1000 - b.current_health))
	_reset_dummy(b)
	b.damage_resistances = {DamageTypes.Type.FIRE: 0.0, DamageTypes.Type.PHYSICAL: 50.0}
	PlayerStats.adaptive_damage_type = true
	a.take_damage(20, true, DamageTypes.Type.FIRE)
	b.take_damage(20, true, DamageTypes.Type.PHYSICAL)
	_check(1000 - a.current_health == 20 and 1000 - b.current_health == 20,
		"with it both enemies take the full 20, each by its own weakest type (%d, %d)" % [1000 - a.current_health, 1000 - b.current_health])
	PlayerStats.adaptive_damage_type = false
	var robe := ItemData.create_blue_robe()
	var phys_res := {DamageTypes.Type.FIRE: 0.0, DamageTypes.Type.PHYSICAL: 50.0}
	var full: int = _hit(Card.create_slash(), stats, dm, bm, a)
	var plain: int = _hit_resisting(Card.create_slash(), phys_res, stats, dm, bm, a)
	var adapted: int = _hit_resisting(_slot(Card.create_slash(), robe), phys_res, stats, dm, bm, a)
	_check(plain < full and adapted == full, "a slotted Slash on a physical-resister lands as fire, unresisted (%d / %d / full %d)" % [plain, adapted, full])
	_check(not PlayerStats.adaptive_damage_type, "the flag is cleared when the card finishes")
	_reset_dummy(a)
	_reset_dummy(b)

func _test_girdle(stats, dm, bm, d: Enemy) -> void:
	print("-- Girdle of Aphrodite: tagged instants count as support --")
	var girdle := ItemData.create_girdle_of_aphrodite()
	stats.current_health = 50
	_slot(Card.create_vengeful_shield(), girdle).execute(main.player, stats, dm, 0.0, 0.0, bm)
	_check(stats.current_health >= 65, "Vengeful Shield (instant tagged defense) heals its target 15 (%d)" % stats.current_health)
	stats.current_health = 50
	_slot(Card.create_sanguine_the_penguin(), girdle).execute(main.player, stats, dm, 0.0, 0.0, bm)
	_check(stats.current_health == 50, "an untagged instant heals nothing (%d)" % stats.current_health)
	stats.current_health = 50
	_slot(Card.create_block(), girdle).execute(main.player, stats, dm, 0.0, 0.0, bm)
	_check(stats.current_health >= 65, "Block (defense) heals 15 (%d)" % stats.current_health)
	stats.current_health = 50
	_slot(Card.create_slash(), girdle).execute(d, stats, dm, 0.0, 0.0, bm)
	_check(stats.current_health == 50, "an offensive card heals nothing (%d)" % stats.current_health)
	stats.current_health = stats.max_health
	stats.current_armor = 0
	_reset_dummy(d)

func _test_tigers(stats) -> void:
	print("-- Tigers Sunday Red: ranged OFFENSIVE cards only --")
	stats.equipment_ranged_range_bonus = 1
	var fb := Card.create_fireball()
	var tonic := Card.create_healing_tonic()
	_check(fb.is_ranged and main._helm_range_bonus(fb) == 1, "Fireball gets +1 range")
	_check(tonic.is_ranged and not tonic.is_offensive() and main._helm_range_bonus(tonic) == 0, "Healing Tonic (ranged utility) gets nothing")
	_check(main._helm_range_bonus(Card.create_slash()) == 0, "a melee card gets nothing")
	stats.equipment_ranged_range_bonus = 0

func _test_belthronding(stats, inv, d: Enemy) -> void:
	print("-- Belthronding: every ally's damage but your own --")
	_check(inv.equip_item(ItemData.create_belthronding(), 0), "Belthronding equips")
	var gm = main.grid_manager
	var pcell: Vector2i = gm.world_to_grid(main.player.position)
	stats.current_health = 100
	main._belthronding_share(main.player.position, 50, main.player)
	_check(stats.current_health == 100, "the wearer's own damage is never shared")
	main._belthronding_share(gm.grid_to_world(pcell + Vector2i(2, 0)), 50, null)
	_check(stats.current_health == 95, "a summon 2 squares away: the wearer takes 10%% (%d)" % stats.current_health)
	main._belthronding_share(gm.grid_to_world(pcell + Vector2i(3, 0)), 50, d)
	_check(stats.current_health == 90, "an ally 3 squares away counts (%d)" % stats.current_health)
	main._belthronding_share(gm.grid_to_world(pcell + Vector2i(4, 0)), 50, null)
	_check(stats.current_health == 90, "4 squares away is outside the radius (%d)" % stats.current_health)
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	stats.current_health = stats.max_health

func _test_close_is_favored(stats, dm, d: Enemy) -> void:
	print("-- Close is Favored: only an enemy ENTERING the next tile --")
	var gm = main.grid_manager
	var pcell: Vector2i = gm.world_to_grid(main.player.position)
	_reset_dummy(d)
	dm.hand.clear()
	dm.hand.append(Card.create_close_is_favored())
	main._enemy_melee_state.clear()
	_place(gm, d, pcell + Vector2i(1, 0))
	main._update_enemy_melee_state(d, false)
	_check(dm.hand.size() == 1, "an enemy already adjacent when the card arrives does not spring it")
	main._on_tempo_advanced(main.tempo_manager.global_tempo_total if "global_tempo_total" in main.tempo_manager else 0, 1)
	_check(dm.hand.size() == 1, "a tempo passing with it still adjacent does not either")
	_place(gm, d, pcell + Vector2i(3, 0))
	main._update_enemy_melee_state(d, true)
	_place(gm, d, pcell + Vector2i(1, 0))
	main._update_enemy_melee_state(d, true)
	_check(dm.hand.is_empty() and d.current_health < 1000, "stepping back in springs it (hp %d)" % d.current_health)
	dm.hand.clear()
	_reset_dummy(d)

func _test_nine_ruins(stats, dm, inv, d: Enemy) -> void:
	print("-- Nine Ruins: the nine hold 5 tempo for Sanguine's card --")
	var nr := ItemData.create_nine_ruins_of_sanguine()
	_check(inv.equip_item(nr, 0), "Nine Ruins equips")
	main._clear_penguin()
	dm.hand.clear()
	dm.draw_pile.clear()
	dm.discard_pile.clear()
	var sang := Card.create_sanguine_the_penguin()
	dm.draw_pile.append(sang)
	nr.vitality_stacks = 8
	main._weapon_post_card_effects(Card.create_slash(), d)
	_check(nr.vitality_stacks == 9 and not main._vitality_window.is_empty(), "the ninth attack opens the window (stacks %d)" % nr.vitality_stacks)
	_check(main._penguin == null, "no card in hand: no penguin yet")
	main._update_vitality_window(3)
	_check(nr.vitality_stacks == 9 and main._penguin == null, "3 tempo in, the stacks still hold")
	dm.draw_pile.erase(sang)
	dm.hand.append(sang)
	main._update_vitality_window(1)
	_check(main._penguin != null and is_instance_valid(main._penguin), "the card arriving in hand calls Sanguine")
	_check(nr.vitality_stacks == 0 and main._vitality_window.is_empty(), "the stacks purge and the window closes")
	main._clear_penguin()
	# The window closing without the card: purge, discard, no penguin.
	dm.hand.clear()
	dm.discard_pile.clear()
	var sang2 := Card.create_sanguine_the_penguin()
	dm.draw_pile.append(sang2)
	nr.vitality_stacks = 8
	main._weapon_post_card_effects(Card.create_slash(), d)
	main._update_vitality_window(5)
	_check(nr.vitality_stacks == 0 and main._vitality_window.is_empty(), "5 tempo without the card purges the stacks")
	_check(main._penguin == null, "no penguin comes")
	_check(sang2 in dm.discard_pile and not (sang2 in dm.draw_pile), "Sanguine's card is discarded")
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	dm.draw_pile.clear()
	dm.discard_pile.clear()

func _test_wrath_edge(dummies: Array) -> void:
	print("-- Wrath of the Sea: every enemy shoved to the burst's edge --")
	var gm = main.grid_manager
	var a: Enemy = dummies[0]
	var b: Enemy = dummies[1]
	var pcell: Vector2i = gm.world_to_grid(main.player.position)
	var bmin: Vector2i = pcell + Vector2i(2, -1)
	var bmax: Vector2i = bmin + Vector2i(3, 3)
	_place(gm, a, bmin + Vector2i(1, 1))
	_place(gm, b, bmin + Vector2i(3, 2))
	main._shove_to_burst_edge(a, bmin, bmax)
	main._shove_to_burst_edge(b, bmin, bmax)
	var ac: Vector2i = gm.world_to_grid(a.position)
	var bc: Vector2i = gm.world_to_grid(b.position)
	_check(ac == bmin + Vector2i(0, 1), "an inner enemy is pushed to the nearest edge cell (%s)" % str(ac - bmin))
	_check(bc == bmin + Vector2i(3, 2), "an enemy already on the edge stays put (%s)" % str(bc - bmin))

func _test_bastion(stats, d: Enemy) -> void:
	print("-- Bouncing Shield: the armor comes back with the shield --")
	_reset_dummy(d)
	stats.current_armor = 20
	main._bastion_armor_out = 0
	main._apply_card_world_effects(Card.create_bouncing_shield(), d)
	var in_flight: int = stats.current_armor
	_check(main._bastion_armor_out == 10, "half the armor (10) leaves with the shield (%d)" % main._bastion_armor_out)
	main._update_bastion_return(3)
	_check(stats.current_armor == in_flight, "3 tempo in it is still away (%d)" % stats.current_armor)
	main._update_bastion_return(2)
	_check(stats.current_armor == in_flight + 10 and main._bastion_armor_out == 0, "after 5 tempo the 10 armor returns (%d)" % stats.current_armor)
	stats.current_armor = 0
	_reset_dummy(d)
