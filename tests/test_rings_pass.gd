extends SceneTree

## Rings pass 1: the 16 rings — factories, rarity spread, the duplicate-equip
## rule, cumulative never-resetting counters, every bespoke proc (zap, stone
## hide, harnessed cleanse, Captain Planet, Cyclops, Thomas, Nibelung,
## Draupnir, The Precious), Jeremy's double-trigger on custom procs, Marvolo's
## lethal save + invulnerability, shadow form mana/point swings, and the
## GENERIC player debuff with natural-expiry-only detonation.
## Run: godot --headless --path . --script tests/test_rings_pass.gd

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
	return stats

func _mk_inv(stats: PlayerStats, who: String = "Ryan") -> Inventory:
	var inv = Inventory.new()
	get_root().add_child(inv)
	inv.initialize(who)
	inv.connect_player_stats(stats)
	inv.enforce_mythic_limit = false
	return inv

func _initialize() -> void:
	print("=== Rings pass test ===")
	_test_roster()
	_test_duplicate_rule()
	_test_zap_counters()
	_test_captain_planet()
	_test_thomas_and_cyclops()
	_test_precious_and_draupnir_counters()
	_test_jeremy_double()
	_test_marvolo()
	_test_shadow_form_stats()
	_test_generic_debuff()
	_test_cards_and_wraith()
	_test_ring_mana()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_ring_mana() -> void:
	## Rings are the mana slot: every one carries a pool by rarity, and the
	## rule lives in _new_ring so future rings can't be forgotten.
	print("-- Rings carry the mana --")
	var by_rarity := {ItemData.Rarity.COMMON: 50, ItemData.Rarity.RARE: 75,
		ItemData.Rarity.LEGENDARY: 125, ItemData.Rarity.MYTHIC: 150}
	var rings := 0
	for item in ItemData.get_all_items():
		if item.item_type != ItemData.ItemType.RING:
			continue
		rings += 1
		var want: int = by_rarity[item.rarity]
		_check(item.mana_bonus == want, "%s (%s) carries %d mana (has %d)" % [
			item.item_name, item.get_rarity_name(), want, item.mana_bonus])
		_check(item.description.begins_with("+%d mana." % want),
			"%s says so in its description" % item.item_name)
	_check(rings == 16, "all 16 rings checked (saw %d)" % rings)
	# The pool actually lands on the wearer, and leaves with the ring.
	var stats = PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(CharacterData.create_jeremy())
	var inv = Inventory.new()
	get_root().add_child(inv)
	inv.initialize("Jeremy")
	inv.connect_player_stats(stats)
	inv.enforce_mythic_limit = false
	var base_mana: int = stats.max_mana
	inv.equip_item(ItemData.create_heal_stone(), 0)
	_check(stats.max_mana == base_mana + 50, "a common ring adds its 50 to the pool")
	inv.equip_item(ItemData.create_draupnir(), 1)
	_check(stats.max_mana == base_mana + 200, "a mythic beside it brings the pool to +200")
	inv.unequip_item(ItemData.ItemType.RING, 1)
	_check(stats.max_mana == base_mana + 50, "and the pool leaves with the ring")
	stats.free()
	inv.free()

func _test_roster() -> void:
	print("-- Roster --")
	var names := ["Heal Stone", "Gold Band", "Emerald", "Friendship Ring", "Scholars Signet",
		"Diamond Ring", "Captain Planets Circlet", "Cyclops Ring", "Ring of Stone Hide",
		"Legend Has It", "Harnessed Sun", "Marvolo Gaunt", "The Precious", "Ring of Nibelung",
		"Draupnir", "Ring of Thomas the Train Tracks"]
	for nm in names:
		var item = ItemData.create_by_name(nm)
		_check(item != null and item.item_type == ItemData.ItemType.RING, "%s exists as a ring" % nm)
	var counts := {ItemData.Rarity.COMMON: 0, ItemData.Rarity.RARE: 0,
		ItemData.Rarity.LEGENDARY: 0, ItemData.Rarity.MYTHIC: 0}
	for nm in names:
		counts[ItemData.create_by_name(nm).rarity] += 1
	_check(counts[ItemData.Rarity.COMMON] == 3, "3 commons (got %d)" % counts[ItemData.Rarity.COMMON])
	_check(counts[ItemData.Rarity.RARE] == 3, "3 rares (got %d)" % counts[ItemData.Rarity.RARE])
	_check(counts[ItemData.Rarity.LEGENDARY] == 6, "6 legendaries (got %d)" % counts[ItemData.Rarity.LEGENDARY])
	_check(counts[ItemData.Rarity.MYTHIC] == 4, "4 mythics (got %d)" % counts[ItemData.Rarity.MYTHIC])
	var cyc = ItemData.create_cyclops_ring()
	_check(cyc.strength_bonus == 10 and cyc.intelligence_bonus == -3, "Cyclops Ring carries its downsides")
	_check(ItemData.create_friendship_ring().healing_bonus == 5, "Friendship Ring: +5 to heals")
	_check(ItemData.create_ring_of_stone_hide().block_bonus_to_defense_cards == 4, "Stone Hide: +4 block on block cards")

func _test_duplicate_rule() -> void:
	print("-- Duplicate-equip rule --")
	var stats = _mk_stats()
	var inv = _mk_inv(stats)
	_check(inv.equip_item(ItemData.create_heal_stone(), 0), "first Heal Stone equips")
	_check(inv.equip_item(ItemData.create_heal_stone(), 1), "second Heal Stone equips (common allows 2)")
	inv.unequip_item(ItemData.ItemType.RING, 1)
	_check(inv.equip_item(ItemData.create_marvolo_gaunt(), 1), "Marvolo Gaunt equips")
	inv.unequip_item(ItemData.ItemType.RING, 0)
	_check(not inv.equip_item(ItemData.create_marvolo_gaunt(), 0), "a second Marvolo Gaunt is refused (legendary max 1)")
	stats.free()
	inv.free()

func _test_zap_counters() -> void:
	print("-- Zap counters (cumulative, never reset) --")
	var stats = _mk_stats()
	var inv = _mk_inv(stats)
	var fired: Array = []
	inv.custom_ring_fired.connect(func(r, k, v): fired.append([r.item_name, k, v]))
	var hs = ItemData.create_heal_stone()
	inv.equip_item(hs, 0)
	inv.on_healed(3)
	_check(fired.is_empty() and int(hs.ring_counters.get("heal", 0)) == 3, "3 healing banks, no proc yet")
	inv.on_healed(3)
	_check(fired.size() == 1 and fired[0][1] == "zap" and fired[0][2] == 2, "6 healing -> one 2-damage zap")
	_check(int(hs.ring_counters.get("heal", 0)) == 1, "remainder carries (cumulative counter)")
	fired.clear()
	inv.on_healed(14)
	_check(fired.size() == 3, "15 banked healing -> three zaps")
	fired.clear()
	# Gold Band rides armor; Emerald rides poison; Harnessed Sun rides burn.
	var gb = ItemData.create_gold_band()
	inv.equip_item(gb, 1)
	inv.on_armor_gained(10)
	_check(fired.size() == 2 and fired[0][0] == "Gold Band", "10 shield -> two Gold Band zaps")
	fired.clear()
	inv.unequip_item(ItemData.ItemType.RING, 0)
	var em = ItemData.create_emerald()
	inv.equip_item(em, 0)
	inv.on_player_debuff_applied("poison", 5)
	_check(fired.size() == 1 and fired[0][0] == "Emerald", "5 poison -> Emerald zap")
	fired.clear()
	inv.unequip_item(ItemData.ItemType.RING, 0)
	var sun = ItemData.create_harnessed_sun()
	inv.equip_item(sun, 0)
	inv.on_player_debuff_applied("burn", 24)
	_check(fired.is_empty(), "24 burn: not yet")
	inv.on_player_debuff_applied("burn", 2)
	_check(fired.size() == 1 and fired[0][1] == "cleanse_self", "26 burn -> cleanse")
	stats.free()
	inv.free()

func _test_captain_planet() -> void:
	print("-- Captain Planets Circlet --")
	var stats = _mk_stats()
	var inv = _mk_inv(stats)
	var fired: Array = []
	inv.custom_ring_fired.connect(func(_r, k, _v): fired.append(k))
	inv.equip_item(ItemData.create_captain_planets_circlet(), 0)
	inv.on_player_debuff_applied("burn", 1)
	inv.on_player_debuff_applied("cold", 1)
	inv.on_player_debuff_applied("silenced", 1)
	inv.on_player_buff_applied(Buff.BuffType.STRENGTHEN)
	_check(fired.is_empty(), "four of five: nothing yet")
	inv.on_player_buff_applied(Buff.BuffType.REGEN)
	_check(fired == ["captain_planet"], "all five -> the powers combine")
	fired.clear()
	inv.on_player_debuff_applied("burn", 1)
	_check(fired.is_empty(), "checklist reset after firing")
	stats.free()
	inv.free()

func _test_thomas_and_cyclops() -> void:
	print("-- Thomas & Cyclops --")
	var stats = _mk_stats()
	var inv = _mk_inv(stats)
	var fired: Array = []
	inv.custom_ring_fired.connect(func(_r, k, v): fired.append([k, v]))
	inv.equip_item(ItemData.create_ring_of_thomas_the_train_tracks(), 0)
	inv.on_deck_shuffled()
	inv.on_deck_shuffled()
	_check(fired == [["thomas_regen", 7], ["thomas_regen", 7]], "two shuffles: 7 Regen each")
	inv.on_deck_shuffled()
	_check(fired.size() == 4 and fired[3] == ["thomas_heal", 25], "3rd shuffle also heals 25")
	fired.clear()
	inv.equip_item(ItemData.create_cyclops_ring(), 1)
	inv.on_player_big_hit()
	inv.on_player_big_hit()
	_check(fired.is_empty(), "two big hits: not yet")
	inv.on_player_big_hit()
	_check(fired.size() == 1 and fired[0] == ["cyclops_strengthen", 15], "third 25+ hit -> Strengthen 15")
	stats.free()
	inv.free()

func _test_precious_and_draupnir_counters() -> void:
	print("-- The Precious & Draupnir hit counters --")
	var stats = _mk_stats()
	var inv = _mk_inv(stats)
	var fired: Array = []
	inv.custom_ring_fired.connect(func(_r, k, _v): fired.append(k))
	inv.equip_item(ItemData.create_the_precious(), 0)
	for _i in range(3):
		inv.on_damage_taken()
	_check(fired.is_empty(), "three hits: still standing")
	inv.on_damage_taken()
	_check(fired == ["shadow_form"], "the 4th hit drags you under")
	fired.clear()
	inv.unequip_item(ItemData.ItemType.RING, 0)
	inv.equip_item(ItemData.create_draupnir(), 0)
	for _i in range(9):
		inv.on_damage_taken()
	_check(fired == ["draupnir_clone"], "the 9th hit drips a duplicate")
	fired.clear()
	stats.draupnir_clone_alive = true
	for _i in range(9):
		inv.on_damage_taken()
	_check(fired.is_empty(), "trigger waits while a duplicate walks")
	stats.free()
	inv.free()

func _test_jeremy_double() -> void:
	print("-- Jeremy doubles custom procs --")
	var stats = _mk_stats()
	var inv = _mk_inv(stats, "Jeremy")
	_check(inv.ring_slots == 3, "Jeremy runs 3 ring slots")
	var fired: Array = []
	inv.custom_ring_fired.connect(func(_r, k, _v): fired.append(k))
	inv.equip_item(ItemData.create_heal_stone(), 0)
	inv.ring_cycle_count = 3  # arms the every-3rd-cycle double
	inv.ring_triggered_this_turn = false
	inv.on_healed(5)
	_check(fired == ["zap", "zap"], "an armed Jeremy fires the proc twice")
	stats.free()
	inv.free()

func _test_marvolo() -> void:
	print("-- Marvolo Gaunt --")
	var stats = _mk_stats()
	var inv = _mk_inv(stats)
	var mg = ItemData.create_marvolo_gaunt()
	inv.equip_item(mg, 0)
	var saved := [false]
	stats.marvolo_triggered.connect(func(): saved[0] = true)
	stats.take_direct_damage(999)
	_check(saved[0], "lethal blow triggers the save")
	_check(stats.current_health > 0, "survived (health %d)" % stats.current_health)
	_check(stats.invulnerable_tempo == 3, "invulnerable for 3 tempo")
	_check(int(mg.ring_counters.get("cd", 0)) == 50, "50-tempo cooldown set")
	var hp_before: int = stats.current_health
	stats.take_damage(50)
	_check(stats.current_health == hp_before, "invulnerability eats the next enemy hit")
	stats.take_direct_damage(5)
	_check(stats.current_health == hp_before - 5, "self-paid costs still bite while invulnerable")
	hp_before = stats.current_health
	stats.process_tempo(3)
	stats.take_damage(5)
	_check(stats.current_health == hp_before - 5, "invulnerability expires after 3 tempo")
	# On cooldown: the next lethal blow is really lethal.
	var died := [false]
	stats.died.connect(func(): died[0] = true)
	stats.take_direct_damage(999)
	_check(died[0], "on cooldown, death is death")
	stats.free()
	inv.free()

func _test_shadow_form_stats() -> void:
	print("-- Shadow form stat swings --")
	var stats = _mk_stats()
	stats.max_mana = 100
	stats.current_mana = 100
	var brain_before: int = stats.current_brain_points
	var flash_before: int = stats.current_flash_points
	stats.enter_shadow_form(0)
	_check(stats.max_mana == 50, "max mana halved (got %d)" % stats.max_mana)
	_check(stats.current_brain_points == brain_before + 10, "+10 brain, past the cap")
	_check(stats.current_flash_points == flash_before + 10, "+10 flash, past the cap")
	_check(stats.shadow_form_tempo == 10, "10 tempo on the clock")
	stats.process_tempo(4)
	_check(stats.shadow_form_tempo == 6, "the clock ticks per tempo")
	stats.exit_shadow_form()
	_check(stats.max_mana == 100, "max mana restored on exit")
	_check(stats.shadow_form_tempo == 0, "form over")
	stats.free()

func _test_generic_debuff() -> void:
	print("-- GENERIC debuff (Marvolo's Misunderstanding) --")
	var d = Debuff.create_generic("Marvolo's Misunderstanding", "Take 25 when this expires.", 25, 7, "Marvolo Gaunt")
	_check(d.debuff_name == "Marvolo's Misunderstanding", "custom name survives creation")
	var dm = DebuffManager.new()
	get_root().add_child(dm)
	dm.apply_debuff(d)
	_check(d.debuff_name == "Marvolo's Misunderstanding", "custom name survives application")
	var expired: Array = []
	dm.debuff_expired.connect(func(db): expired.append(db.debuff_name))
	dm.remove_debuff(Debuff.DebuffType.GENERIC)
	_check(expired.is_empty(), "a purge never counts as expiry")
	var d2 = Debuff.create_generic("Marvolo's Misunderstanding", "Take 25.", 25, 7, "Marvolo Gaunt")
	dm.apply_debuff(d2)
	dm.advance_time(5)
	dm.advance_time(5)
	_check(expired == ["Marvolo's Misunderstanding"], "natural expiry fires the detonation signal")
	dm.free()

func _test_cards_and_wraith() -> void:
	print("-- Granted cards & the wraith --")
	for cid in ["tricks_of_alberich", "the_nibelung_curse"]:
		var card = Card.create_by_id(cid)
		_check(card != null and card.card_id == cid, "%s exists" % cid)
	var nc = Card.create_by_id("the_nibelung_curse")
	_check(nc.erase_on_play and "self" in nc.target_types and "enemy" in nc.target_types,
		"the Curse can point either way, then is erased")
	var rn = ItemData.create_ring_of_nibelung()
	_check(rn.granted_card_ids.size() == 1 and rn.granted_card_ids[0] == "tricks_of_alberich",
		"Nibelung grants Tricks of Alberich")
	_check(Enemy.EnemyType.RING_WRAITH >= 0, "RING_WRAITH exists at the enum tail")
	_check(Card.DROP_EXCLUDED_CARD_IDS.has("the_nibelung_curse"), "the Curse never drops randomly")
