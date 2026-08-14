extends SceneTree

## Weapons pass 1: the 20 weapons — factories, granted cards, hand-pairing
## synergies (Spartan shield / Side Card Sabre), Wrath, Vitality fields, kill
## flash banking, and Bessy's attack-speed penalty.
## Run: godot --headless --path . --script tests/test_weapons_pass.gd

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
	stats.max_health = 200
	stats.current_health = 200
	stats.base_strength = 60
	stats.strength = 60
	return stats

func _mk_inv(stats: PlayerStats) -> Inventory:
	var inv = Inventory.new()
	get_root().add_child(inv)
	inv.initialize("Ryan")
	inv.connect_player_stats(stats)
	inv.enforce_mythic_limit = false
	return inv

func _initialize() -> void:
	print("=== Weapons pass test ===")
	_test_roster()
	_test_cards()
	_test_pairing()
	_test_spartan()
	_test_wrath()
	_test_bessy_and_flash()
	_test_stephen_swap_perk()
	_test_mauls_sabre()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_mauls_sabre() -> void:
	print("-- Mauls Sabre: colored slots --")
	var sabre = ItemData.create_mauls_sabre()
	_check(sabre.slot_colors == ["blue", "red"], "a blue slot and a red slot")
	_check(sabre.hand_size_bonus == 1, "+1 hand size")
	var blue_fx: Dictionary = sabre.slot_effects[0]
	var red_fx: Dictionary = sabre.slot_effects[1]
	_check(blue_fx.get("block", 0) == 8 and blue_fx.get("damage", 0) == 5 and blue_fx.get("weaken", 0) == 1,
		"blue payload: 8 block, +5 damage, 1 Weaken")
	_check(red_fx.get("discard", 0) == 2 and red_fx.get("damage", 0) == 15,
		"red payload: discard 2, +15 damage")
	# Slot order decides the color.
	var first = Card.create_slice()
	var second = Card.create_quick_shot()
	_check(sabre.slot_card(first) and sabre.slot_card(second), "two cards slot into the staff")
	_check(sabre.get_slot_color(first) == "blue" and sabre.get_slot_color(second) == "red",
		"first card takes blue, second takes red")
	_check(sabre.get_slot_effect(second).get("combo_after", "") == "blue", "red combos off blue")
	# The red-after-blue combo shaves 1 tempo, live on the card face.
	var base := second.get_burden_tempo_cost()
	_check(base == second.tempo_cost, "no combo primed: full tempo")
	sabre.last_color_played = "blue"
	_check(second.get_burden_tempo_cost() == max(0, base - 1), "blue primed: red costs 1 less tempo")
	sabre.last_color_played = "red"
	_check(second.get_burden_tempo_cost() == base, "wrong color primed: full tempo again")
	# An uncolored item is untouched by the machinery.
	var plain = ItemData.create_pick()
	var pc = Card.create_slice()
	plain.slot_card(pc)
	_check(plain.get_slot_color(pc) == "" and plain.get_slot_effect(pc).is_empty(),
		"uncolored slots report no color and no payload")

func _test_stephen_swap_perk() -> void:
	print("-- Stephen: man of arms --")
	var stats = _mk_stats()
	var inv = Inventory.new()
	get_root().add_child(inv)
	inv.initialize("Stephen")
	inv.connect_player_stats(stats)
	_check(inv.get_swap_tempo_cost(ItemData.ItemType.WEAPON) == 1,
		"Stephen swaps weapons for 1 tempo")
	_check(inv.get_swap_tempo_cost(ItemData.ItemType.CHEST) == 8,
		"armor still costs Stephen full price")
	# Build switch: a weapons-only difference is free.
	var sword = ItemData.create_short_sword()
	inv.equip_item(sword, 0)
	inv.switch_build(1)  # initializes build 2 as a copy
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	inv.stored_items.append(sword)
	var pick = ItemData.create_pick()
	inv.equip_item(pick, 0)
	var back = inv.switch_build(0)  # restore the sword build: only hands differ
	_check(back["success"] and back["tempo_cost"] == 0,
		"weapons-only build switch is free (cost %d)" % back["tempo_cost"])
	stats.free()
	inv.free()

	# Everyone else pays the old rates.
	var stats2 = _mk_stats()
	var inv2 = _mk_inv(stats2)
	_check(inv2.get_swap_tempo_cost(ItemData.ItemType.WEAPON) == 2,
		"Ryan still swaps weapons for 2")
	stats2.free()
	inv2.free()

func _test_roster() -> void:
	print("-- Roster --")
	var names := ["Pick", "Rusty Dagger", "Construction Hammer", "Short Sword", "Wooden Spear",
		"Armor Chopper", "Lions Halberd", "Spartan Spear", "Side Card Sabre",
		"Axe's Axe", "Bessy", "Hammer of Ajax", "Laurentius's Lost Spear", "Mauls Sabre",
		"Fallen's Wrath", "Nine Ruins of Sanguine",
		"Sabre Tooth", "Poseidons Trident", "Sword of Theseus", "Umbral Eclipse"]
	for nm in names:
		var item = ItemData.create_by_name(nm)
		_check(item != null and item.item_type == ItemData.ItemType.WEAPON, "%s exists as a weapon" % nm)
	var mythic_names := ["Sabre Tooth", "Poseidons Trident", "Sword of Theseus", "Umbral Eclipse"]
	for nm in mythic_names:
		var m = ItemData.create_by_name(nm)
		_check(m.rarity == ItemData.Rarity.MYTHIC and m.appearance != "" and m.appearance_icon != "",
			"%s is a mythic with appearance + icon" % nm)
	_check(ItemData.create_bessy().weapon_damage == 15, "Bessy carries the only base weapon damage (15)")

func _test_cards() -> void:
	print("-- Granted cards --")
	var slice = Card.create_by_id("slice")
	_check(slice.mana_cost == 10 and slice.tempo_cost == 3 and slice.base_damage == 15,
		"Slice: 10m/3t, 15 damage")
	var er = Card.create_by_id("earth_rattle")
	_check(er.mana_cost == 60 and er.tempo_cost == 6, "Earth Rattle: 60m/6t")
	var ws = Card.create_by_id("wrath_of_the_sea")
	_check(is_equal_approx(ws.percent_mana_cost, 0.5) and ws.tempo_cost == 8,
		"Wrath of the Sea costs half your current mana, 8 tempo")
	var monk = Card.create_by_id("monk_of_the_night")
	_check(monk.card_type == Card.CardType.POWER and monk.maintain_cost == 50,
		"Monk of the Night maintains at 50")
	for pair in [["hard_helmet", "on_utility_played"], ["death_vortex", "on_hit_streak_5"],
			["feed_into_the_pain", "on_damage_taken_low"], ["psionic_flow", "psionic_flow"],
			["sanguine_the_penguin", "on_vitality_9"]]:
		var inst = Card.create_by_id(pair[0])
		_check(inst.card_type == Card.CardType.REACTION and inst.reaction_trigger == pair[1],
			"%s is an instant on '%s'" % [pair[0], pair[1]])
	for cid in ["hard_helmet", "slice", "death_vortex", "earth_rattle", "feed_into_the_pain",
			"psionic_flow", "purge_wrath", "sanguine_the_penguin", "wrath_of_the_sea", "monk_of_the_night"]:
		_check(Card.DROP_EXCLUDED_CARD_IDS.has(cid), "%s never drops randomly" % cid)
	var aa = ItemData.create_axes_axe()
	_check(aa.granted_card_ids.count("death_vortex") == 3, "Axe's Axe grants 3 Death Vortexes")
	var ll = ItemData.create_laurentius_lost_spear()
	_check(ll.granted_card_ids.count("psionic_flow") == 2, "Laurentius grants 2 Psionic Flows")

func _test_pairing() -> void:
	print("-- Side Card Sabre pairing --")
	var stats = _mk_stats()
	var inv = _mk_inv(stats)
	var main_sword = ItemData.create_short_sword()
	var sabre = ItemData.create_side_card_sabre()
	inv.equip_item(main_sword, 0)
	inv.equip_item(sabre, 1)
	_check(sabre.pair_active, "sabre pairs beside a main-hand sword")
	_check(inv._effective_item_weight(sabre, 1) == 0, "paired sabre is weightless")
	_check(int(sabre.get_on_self_bonus().get("pair_tempo_reduction", 0)) == 1,
		"paired sabre discounts slotted cards 1 tempo")
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	_check(not sabre.pair_active, "losing the main weapon breaks the pair")
	_check(inv._effective_item_weight(sabre, 1) == sabre.weight, "unpaired sabre weighs its 20 again")
	stats.free()
	inv.free()

func _test_spartan() -> void:
	print("-- Spartan Spear shield synergy --")
	var stats = _mk_stats()
	var inv = _mk_inv(stats)
	var spear = ItemData.create_spartan_spear()
	inv.equip_item(spear, 0)
	_check(stats.equipment_melee_reach == 0, "no shield -> no reach")
	var shield = ItemData.new()
	shield.item_name = "Test Shield"
	shield.item_type = ItemData.ItemType.WEAPON
	shield.weapon_subtype = ItemData.WeaponSubtype.SHIELD
	shield.weight = 10
	inv.equip_item(shield, 1)
	_check(stats.equipment_melee_reach == 1 and stats.equipment_shield_melee_damage == 2,
		"shield up -> Reach + 2 melee damage")
	inv.unequip_item(ItemData.ItemType.WEAPON, 1)
	_check(stats.equipment_melee_reach == 0 and stats.equipment_shield_melee_damage == 0,
		"shield down -> synergy off")
	stats.free()
	inv.free()

func _test_wrath() -> void:
	print("-- Fallen's Wrath --")
	var stats = _mk_stats()
	var inv = _mk_inv(stats)
	var sword = ItemData.create_fallens_wrath()
	inv.equip_item(sword, 0)
	for _i in range(9):
		stats.take_damage(2)
	_check(sword.wrath == 9, "nine hits -> 9 Wrath (has %d)" % sword.wrath)
	var hp_before: int = stats.current_health
	stats.take_damage(20)
	# The 10th instance raises Wrath to 10 BEFORE amplification, so the hit
	# lands at 150%.
	_check(sword.wrath == 10, "tenth hit -> 10 Wrath")
	_check(hp_before - stats.current_health == 30, "at 10+ Wrath a 20 hit lands as 30 (took %d)" % (hp_before - stats.current_health))
	# Purge Wrath arms the percent and resets the counter.
	var pw = Card.create_by_id("purge_wrath")
	var dm = DeckManager.new()
	get_root().add_child(dm)
	pw.execute(null, stats, dm, 0.0, 0.0, null)
	_check(stats.pending_wrath_percent == 10 and sword.wrath == 0,
		"Purge Wrath: +10%% armed, Wrath reset")
	stats.free()
	inv.free()
	dm.free()

func _test_bessy_and_flash() -> void:
	print("-- Bessy & Axe's Axe --")
	var stats = _mk_stats()
	var inv = _mk_inv(stats)
	# The raw channel first (carry weight also moves the threshold, so isolate).
	var base_threshold: int = stats.get_attack_speed_threshold()
	stats.equipment_attack_speed_penalty = 5
	_check(stats.get_attack_speed_threshold() == base_threshold + 5,
		"attack-speed penalty channel slows procs by 5")
	stats.equipment_attack_speed_penalty = 0
	var bessy = ItemData.create_bessy()
	_check(inv.equip_item(bessy, 0), "Bessy equips at 60 STR")
	_check(stats.equipment_attack_speed_penalty == 5, "Bessy sets the penalty while wielded")
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	_check(stats.equipment_attack_speed_penalty == 0, "penalty clears on unequip")

	var axe = ItemData.create_axes_axe()
	inv.equip_item(axe, 0)
	stats.current_flash_points = stats.get_max_flash_points()
	var cap: int = stats.get_max_flash_points()
	inv.on_enemy_killed()
	_check(stats.current_flash_points == cap + 5,
		"Axe's Axe banks 5 flash past the cap (%d/%d)" % [stats.current_flash_points, cap])
	stats.free()
	inv.free()
