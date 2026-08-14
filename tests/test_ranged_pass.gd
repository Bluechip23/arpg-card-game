extends SceneTree

## Ranged pass 1: the 19 bows & quivers — factories, rarity spread, hand
## rules (two-handed bows, one-handed throwers, quiver pairing), ARROW slot
## gating, the new on-self riders (tempo delta, jail, double shot, bounce,
## mana-to-life, kill-skeleton, conjure, bud-on-crit), granted cards, and the
## enemy-side fear / cupid-mark / tree-form plumbing.
## Run: godot --headless --path . --script tests/test_ranged_pass.gd

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

func _mk_inv(stats: PlayerStats) -> Inventory:
	var inv = Inventory.new()
	get_root().add_child(inv)
	inv.initialize("Ryan")
	inv.connect_player_stats(stats)
	inv.enforce_mythic_limit = false
	return inv

func _initialize() -> void:
	print("=== Ranged pass test ===")
	_test_roster()
	_test_hand_rules()
	_test_slot_gating()
	_test_on_self_riders()
	_test_granted_cards()
	_test_tempo_delta()
	_test_enemy_plumbing()
	_test_summon_scripts()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_roster() -> void:
	print("-- Roster --")
	var bows := ["Short Bow", "Cross Bow", "Long Bow", "Tightened Cross Bow", "Cupids Bow",
		"The Rapid Recurve", "Stringless Sender", "Bow of Arash", "Belthronding",
		"Bow of Budding Blasts"]
	for nm in bows:
		var item = ItemData.create_by_name(nm)
		_check(item != null and item.item_type == ItemData.ItemType.WEAPON
			and item.weapon_subtype == ItemData.WeaponSubtype.BOW, "%s exists as a bow" % nm)
	for nm in ["Boomerang", "Wrist Rocket"]:
		var item = ItemData.create_by_name(nm)
		_check(item != null and item.item_type == ItemData.ItemType.WEAPON
			and item.weapon_subtype == ItemData.WeaponSubtype.OTHER, "%s exists as a one-handed thrower" % nm)
	var quivers := ["Standard Quiver", "Fire Quiver", "Quiver of Wet Stones", "Frost Quiver",
		"Shock Quiver", "Sack of Bone Arrows", "Capacious Extremus"]
	for nm in quivers:
		var item = ItemData.create_by_name(nm)
		_check(item != null and item.item_type == ItemData.ItemType.QUIVER, "%s exists as a quiver" % nm)
	# Rarity spread: 4 common, 6 rare, 6 legendary, 3 mythic.
	var counts := {ItemData.Rarity.COMMON: 0, ItemData.Rarity.RARE: 0,
		ItemData.Rarity.LEGENDARY: 0, ItemData.Rarity.MYTHIC: 0}
	for nm in bows + ["Boomerang", "Wrist Rocket"] + quivers:
		counts[ItemData.create_by_name(nm).rarity] += 1
	_check(counts[ItemData.Rarity.COMMON] == 4, "4 commons (got %d)" % counts[ItemData.Rarity.COMMON])
	_check(counts[ItemData.Rarity.RARE] == 6, "6 rares (got %d)" % counts[ItemData.Rarity.RARE])
	_check(counts[ItemData.Rarity.LEGENDARY] == 6, "6 legendaries (got %d)" % counts[ItemData.Rarity.LEGENDARY])
	_check(counts[ItemData.Rarity.MYTHIC] == 3, "3 mythics (got %d)" % counts[ItemData.Rarity.MYTHIC])
	# Spot stats.
	var xb = ItemData.create_cross_bow()
	_check(xb.agility_bonus == -2 and xb.intelligence_bonus == 3, "Cross Bow carries its -2 AGI")
	var wr = ItemData.create_wrist_rocket()
	_check(wr.crit_chance_percent == 10.0 and wr.card_slots == 1, "Wrist Rocket: +10% crit, 1 slot")
	var arash = ItemData.create_bow_of_arash()
	_check(arash.ranged_range_bonus == 2 and arash.level_3_overrides.get("ranged_range_bonus", 0) == 3,
		"Bow of Arash: +2 range, +3 at level 3")
	var belth = ItemData.create_belthronding()
	_check(belth.ally_damage_share_percent == 10.0 and belth.ally_damage_share_radius == 3,
		"Belthronding: 10% ally-damage share within 3")

func _test_hand_rules() -> void:
	print("-- Hand rules --")
	var bow = ItemData.create_short_bow()
	_check(Inventory.is_two_hand_only(bow), "Short Bow is two-hand only")
	_check(not Inventory.is_two_hand_only(ItemData.create_boomerang()), "Boomerang is one-handed")
	_check(not Inventory.is_two_hand_only(ItemData.create_wrist_rocket()), "Wrist Rocket is one-handed")
	var stats = _mk_stats()
	var inv = _mk_inv(stats)
	_check(inv.equip_item(bow, 0), "bow equips in the main hand")
	var quiver = ItemData.create_standard_quiver()
	_check(inv.hand_conflict_reason(quiver, 1) == "", "a quiver may ride beside the bow")
	_check(inv.equip_item(quiver, 1), "quiver equips in the off hand")
	var sword = ItemData.create_short_sword()
	_check(inv.hand_conflict_reason(sword, 1) != "", "a second weapon may not")
	stats.free()
	inv.free()
	# One-handed throwers pair with a quiver too.
	var stats2 = _mk_stats()
	var inv2 = _mk_inv(stats2)
	_check(inv2.equip_item(ItemData.create_boomerang(), 0), "boomerang equips")
	_check(inv2.equip_item(ItemData.create_fire_quiver(), 1), "a quiver rides beside the boomerang")
	stats2.free()
	inv2.free()

func _test_slot_gating() -> void:
	print("-- ARROW slot gating --")
	var quiver = ItemData.create_standard_quiver()
	var arrow = Card.create_quick_shot()
	var not_arrow = Card.create_slice()
	_check(quiver.can_slot_card(arrow), "quiver accepts an ARROW card")
	_check(not quiver.can_slot_card(not_arrow), "quiver refuses a non-ARROW card")
	_check(quiver.slot_card(arrow), "arrow slots into the quiver")
	_check(arrow.slotted_in_item == quiver, "the card knows its quiver")
	var bow = ItemData.create_long_bow()
	_check(bow.can_slot_card(Card.create_slice()), "a bow accepts standard attacks too")

func _test_on_self_riders() -> void:
	print("-- On-self riders --")
	var osb = ItemData.create_the_rapid_recurve().get_on_self_bonus()
	_check(bool(osb.get("double_shot", false)), "Rapid Recurve: double shot")
	_check(int(osb.get("jail_tempo", 0)) == 20, "Rapid Recurve: jail 20")
	_check(float(osb.get("mana_multiplier", 1.0)) == 1.5, "Rapid Recurve: 1.5x mana")
	osb = ItemData.create_stringless_sender().get_on_self_bonus()
	_check(int(osb.get("tempo_penalty", 0)) == -1, "Stringless Sender: -1 tempo")
	_check(int(osb.get("mana_reduction", 0)) == -10, "Stringless Sender: +10 mana")
	_check(float(osb.get("bounce_percent", 0.0)) == 20.0, "Stringless Sender: 20% bounce")
	osb = ItemData.create_bow_of_arash().get_on_self_bonus()
	_check(bool(osb.get("mana_to_life", false)), "Bow of Arash: mana-to-life")
	osb = ItemData.create_sack_of_bone_arrows().get_on_self_bonus()
	_check(bool(osb.get("kill_summon_skeleton", false)), "Sack of Bone Arrows: kill-skeleton")
	osb = ItemData.create_belthronding().get_on_self_bonus()
	_check(str(osb.get("conjure_on_play_id", "")) == "close_is_favored", "Belthronding: conjures the trap")
	osb = ItemData.create_bow_of_budding_blasts().get_on_self_bonus()
	_check(bool(osb.get("crit_bud_bow", false)), "Budding Blasts: bud on crit")
	osb = ItemData.create_shock_quiver().get_on_self_bonus()
	_check(int(osb.get("apply_shock", 0)) == 2, "Shock Quiver: 2 shock")
	osb = ItemData.create_quiver_of_wet_stones().get_on_self_bonus()
	_check(int(osb.get("armor_shred", 0)) == 4, "Wet Stones: 4 armor shred")
	osb = ItemData.create_capacious_extremus().get_on_self_bonus()
	_check(float(osb.get("mana_reduction_percent", 0.0)) == 10.0, "Capacious Extremus: -10% mana")

func _test_granted_cards() -> void:
	print("-- Granted cards --")
	for cid in ["improvised_ammo", "cupids_golden_arrow", "cupids_lead_arrow",
			"territorial_mark", "balistic_arrow", "close_is_favored", "spirit_bow"]:
		var card = Card.create_by_id(cid)
		_check(card != null and card.card_id == cid, "%s exists" % cid)
	var ia = Card.create_by_id("improvised_ammo")
	_check(ia.has_on_discard and ia.on_discard_effect == "improvised_ammo_blast",
		"Improvised Ammo triggers on discard")
	var tm = Card.create_by_id("territorial_mark")
	_check(tm.health_cost == 35 and tm.mana_cost == 45, "Territorial Mark costs 45 mana + 35 health")
	var cif = Card.create_by_id("close_is_favored")
	_check(cif.card_type == Card.CardType.REACTION and cif.reaction_trigger == "on_enemy_melee_range"
		and cif.erase_on_play, "Close is Favored is an erasing Instant")
	var sb = Card.create_by_id("spirit_bow")
	_check(sb.maintain_cost == 65, "Spirit Bow maintains 65 mana")
	var ba = Card.create_by_id("balistic_arrow")
	_check(ba.is_aoe and ba.aoe_shape == "line", "Balistic Arrow pierces in a line")
	# Wrist Rocket grants two copies.
	var wr = ItemData.create_wrist_rocket()
	_check(wr.granted_card_ids.size() == 2 and wr.granted_card_ids[0] == "improvised_ammo",
		"Wrist Rocket grants 2 copies of Improvised Ammo")

func _test_tempo_delta() -> void:
	print("-- Tempo delta --")
	var slow_bow = ItemData.create_tightened_cross_bow()
	var arrow = Card.create_quick_shot()
	var base := arrow.get_burden_tempo_cost()
	slow_bow.slot_card(arrow)
	_check(arrow.get_burden_tempo_cost() == base + 1, "Tightened Cross Bow: +1 tempo on slotted cards")
	slow_bow.unslot_card(0)
	var fast_bow = ItemData.create_stringless_sender()
	var arrow2 = Card.create_down_town()
	var base2 := arrow2.get_burden_tempo_cost()
	fast_bow.slot_card(arrow2)
	_check(arrow2.get_burden_tempo_cost() == max(0, base2 - 1), "Stringless Sender: -1 tempo on slotted cards")

func _test_enemy_plumbing() -> void:
	print("-- Enemy plumbing (fear / cupid / tree) --")
	var enemy_script = load("res://scripts/battle/enemy.gd")
	var e = enemy_script.new()
	var source := Node3D.new()
	get_root().add_child(source)
	e.apply_fear(source, 2)
	_check(e.fear_tempo == 2 and e.fear_source == source, "fear lands")
	_check(not e.apply_cupid_mark(true), "one mark alone does not transform")
	_check(e.cupid_golden and not e.cupid_lead, "golden mark recorded")
	_check(e.apply_cupid_mark(false), "the second mark completes the pair")
	_check(e.tree_tempo == 4 and e.tree_regen_ticks == 3, "tree form: 4 tempo, 3 regen ticks")
	_check(not e.cupid_golden and not e.cupid_lead, "marks consumed by the transform")
	# The tree cannot act and regenerates 3 on each of its first 3 tempo.
	e.max_health = 100
	e.current_health = 50
	e.on_tempo_advanced(1, null)
	_check(e.current_health == 53 and e.tree_tempo == 3, "tree heals 3 per tempo (health %d)" % e.current_health)
	e.on_tempo_advanced(3, null)
	_check(e.tree_tempo == 0 and e.current_health == 59, "tree form expires after 4 tempo, healed 9 total")
	# zone_weakened chips in only when no weaken stacks are present.
	e.zone_weakened = true
	var fx_names := []
	for fx in e.get_active_effects():
		fx_names.append(fx["name"])
	_check("Weaken" in fx_names, "Territorial Mark shows a Weaken chip")
	e.free()
	source.free()

func _test_summon_scripts() -> void:
	print("-- Summon scripts --")
	var skel_script = load("res://scripts/battle/summoned_skeleton.gd")
	_check(skel_script != null, "summoned_skeleton.gd loads")
	var s = skel_script.new()
	_check(s.BASE_ATTACK == 5 and s.MOVE_STEPS == 4 and s.ATTACK_INTERVAL == 5,
		"skeleton stat block: 5 damage, 4 squares/tempo, attacks every 5")
	s.max_health = 30
	s.health = 30
	s.free()
	var bow_script = load("res://scripts/battle/spirit_bow_summon.gd")
	_check(bow_script != null, "spirit_bow_summon.gd loads")
	var b = bow_script.new()
	b.is_bud = true
	b.max_health = 1
	b.health = 1
	b.attacks_left = 2
	_check(b.base_attack() == 6 and b.attack_interval() == 5, "bud: 6 damage every 5 tempo")
	b.take_damage(0)
	# Any source of damage kills a bud outright (0 would round to nothing).
	_check(b.is_dead, "any damage kills a bud instantly")
	var spirit = bow_script.new()
	_check(spirit.base_attack() == 10 and spirit.attack_interval() == 4, "spirit bow: 10 damage every 4 tempo")
	spirit.free()
