extends SceneTree

## Phase 2 wiring audit, items slice C (docs/audit/wiring/items_c.md): the 63
## items from Ring of Thomas the Train Tracks to Wrist Rocket, checked against
## their tooltip text in a booted main.tscn (the dojo). Items are equipped
## through the real Inventory so the stat block, granted cards and riders all
## take the same path a player's gear does; slotted cards are played through
## Card.execute + main's world-effects step (the play scope) or through
## main.play_selected_card when the tempo/mana price matters.
## Run: godot --headless --path . --script tests/test_wiring_items_c.gd

var failures := 0
var main = null
var stats: PlayerStats = null
var dm = null
var bm = null
var dbm = null
var inv: Inventory = null
var dummies: Array = []

const ITEMS := ["ring_of_thomas_the_train_tracks", "rollerblades", "roman_bracers",
	"rusty_dagger", "sabre_tooth", "sack_of_bone_arrows", "scholars_cap", "scholars_signet",
	"shadow_cowl", "shadow_obi", "shamans_mask", "shepherds_crook", "shock_quiver",
	"short_bow", "short_sword", "side_card_sabre", "sleeved_katar",
	"slotted_rope_half_sleeve", "smithed_excellence", "spartan_spear",
	"spidey_web_shooters", "spiked_mitts", "spiked_shield", "standard_quiver",
	"steel_boots", "steel_plate", "steve_rodgers_bastion", "strap_of_stone",
	"stringless_sender", "studded_belt", "suit_and_tie", "summoners_cap",
	"supernova_cuirass", "sword_breaker", "sword_of_theseus", "tactical_belt",
	"tattered_cloth", "techno_wraps", "the_headbandz", "the_precious",
	"the_rapid_recurve", "the_slotted_sash", "theif_hat", "thick_steel_helm",
	"tigers_sunday_red", "tightened_cross_bow", "titanium_toe_tuckers",
	"treebeards_branch", "trench_of_tranquility", "umbral_eclipse", "vanguard",
	"velvet_plate", "vengeful_shield", "waistband", "wand_of_clarity",
	"wand_of_deliverance", "wand_of_the_phoenix_feather", "wizard_hat",
	"wooden_plank", "wooden_shield", "wooden_spear", "wooden_sword", "wrist_rocket"]

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Wiring audit: items C ===")
	_run()

# ------------------------------------------------------------------ harness

func _run() -> void:
	TempoManager.preferred_swing_hold = 0  # blows land at once (test_hit_wait covers the wait)
	main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(8):
		await process_frame
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	stats = main.player.get_stats()
	dm = main.deck_manager
	bm = main.player.get_buff_manager()
	dbm = main.player.get_debuff_manager()
	inv = main.player.get_inventory()
	dummies = main.enemy_spawner.get_living_enemies()
	_check(dummies.size() >= 2, "the dojo has two dummies (%d)" % dummies.size())
	inv.enforce_mythic_limit = false
	inv.enforce_deck_cap = false
	stats.base_strength += 400  # carry capacity for every piece in the slice
	stats.recalculate_derived_stats()

	_test_equip_all()
	_test_slot_counts()
	_test_granted_card_prices()
	_test_rings()
	_test_boots()
	_test_gauntlets()
	_test_helms()
	_test_chests()
	_test_belts()
	_test_quivers()
	_test_bows()
	_test_weapons()
	_test_shields()
	_test_wands()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _clear_gear() -> void:
	for arr_type in [[inv.equipped_helms, ItemData.ItemType.HELM], [inv.equipped_chests, ItemData.ItemType.CHEST],
			[inv.equipped_rings, ItemData.ItemType.RING], [inv.equipped_belts, ItemData.ItemType.BELT],
			[inv.equipped_boots, ItemData.ItemType.BOOTS], [inv.equipped_gauntlets, ItemData.ItemType.GAUNTLETS]]:
		var arr: Array = arr_type[0]
		for i in range(arr.size()):
			if arr[i] != null:
				inv.unequip_item(arr_type[1], i)
	# Off hand first (a quiver comes off with its bow).
	for i in range(inv.equipped_weapons.size() - 1, -1, -1):
		var w = inv.equipped_weapons[i]
		if w != null:
			inv.unequip_item(w.item_type, i)

func _fresh() -> void:
	## A clean slate between items: no gear, full health, no statuses.
	_clear_gear()
	for b in bm.buffs.duplicate():
		bm.remove_buff_instance(b)
	dbm.clear_all_debuffs()
	stats.max_health = maxi(stats.max_health, 500)
	stats.current_health = stats.max_health
	stats.current_armor = 0
	stats.unerring_armor = 0
	stats.current_mana = stats.max_mana
	stats.equipment_crit_bonus = -100.0  # exact comparisons: no random crits
	stats.pending_melee_damage_bonus = 0
	stats.free_move_tiles = 0
	stats.last_attack_target = null
	for d in dummies:
		_reset_dummy(d)
	_place_dummies()

func _reset_dummy(d: Enemy) -> void:
	d.max_health = 1000
	d.current_health = 1000
	d.current_armor = 0
	d.damage_resistances = {}
	for k in ["burn_stacks", "cold_stacks", "poison_stacks", "shock_stacks", "bleed_stacks",
			"weaken_stacks", "vulnerable_stacks", "slow_stacks", "disarmed_tempo", "rooted_tempo"]:
		d.set(k, 0)
	d.is_disarmed = false

func _pcell() -> Vector2i:
	return main.grid_manager.world_to_grid(main.player.position)

func _place(who, cell: Vector2i) -> void:
	who.position = main.grid_manager.grid_to_world(cell)
	if "target_position" in who:
		who.target_position = who.position

func _place_dummies() -> void:
	## Dummy A beside the player (east), dummy B three tiles further.
	_place(dummies[0], _pcell() + Vector2i(1, 0))
	_place(dummies[1], _pcell() + Vector2i(4, 0))

func _equip(id: String, slot: int = 0) -> ItemData:
	var item := ItemData.create(id)
	if item.item_type == ItemData.ItemType.QUIVER:
		var bow_ok := inv.equip_item(ItemData.create("short_bow"), 0)
		_check(bow_ok, "%s: a bow goes on first" % id)
		slot = 1
	var ok := inv.equip_item(item, slot)
	_check(ok, "%s equips (%s)" % [id, inv.last_refusal])
	stats.current_health = stats.max_health
	return item

func _slot(card: Card, item: ItemData) -> Card:
	## Into the item's first BONUS slot (slot gating is not under test). One
	## card at a time: whatever sat there is taken out first.
	for old in item.slotted_cards:
		old.slotted_in_item = null
	item.slotted_cards.clear()
	card.slotted_in_item = item
	item.slotted_cards.append(card)
	card.set_meta("slot_color_index", 0)
	return card

func _slot_plain(card: Card, item: ItemData) -> Card:
	## Into the item's first PLAIN (vanilla) slot: no on-self riders at all.
	for old in item.slotted_cards:
		old.slotted_in_item = null
	item.slotted_cards.clear()
	card.slotted_in_item = item
	item.slotted_cards.append(card)
	card.set_meta("slot_color_index", item.card_slots)
	return card

func _exec(card: Card, target) -> void:
	## A card's play as main resolves it: execute + world effects inside the
	## play scope.
	PlayerStats.hit_source_offensive = card.is_offensive()
	PlayerStats.hit_source_direct = true
	Card.play_scope_open = true
	card.execute(target, stats, dm, 0.0, 0.0, bm)
	main._apply_card_world_effects(card, target)
	Card.close_play_scope(stats)
	PlayerStats.hit_source_offensive = false
	PlayerStats.hit_source_direct = false

func _play(card: Card, target) -> bool:
	## The real pipeline: hand -> select -> play_selected_card (prices paid,
	## tempo queued) -> the queued resolution, fired now.
	dm.hand.clear()
	dm.hand.append(card)
	main.select_card(0)
	var before: int = main._pending_resolve_queue.size()
	main.play_selected_card(target)
	var queued := false
	for e in main._pending_resolve_queue:
		if e["card"] == card:
			queued = true
	if queued:
		main._resolve_queued_card(card)
	return queued or main._pending_resolve_queue.size() != before or not (card in dm.hand)

func _dmg(d: Enemy) -> int:
	return 1000 - d.current_health

func _regen() -> int:
	var t := 0
	for b in bm.get_buffs(Buff.BuffType.REGEN):
		t += b.value
	return t

func _thorns() -> int:
	return bm.get_thorns_damage()

func _count_in_deck(card_id: String) -> int:
	var n := 0
	for zone in [dm.hand, dm.draw_pile, dm.discard_pile, dm.jail_pile]:
		for c in zone:
			if c.card_id == card_id:
				n += 1
	return n

# ------------------------------------------------- every item: stats & cards

func _test_equip_all() -> void:
	print("-- Every item: stat block and granted cards through the real Inventory --")
	for id in ITEMS:
		_fresh()
		var item := ItemData.create(id)
		_check(item != null and item.item_name != "Unknown Item", "%s loads" % id)
		var pre_bow: ItemData = null
		var slot := 0
		var scale := 1.0
		if item.item_type == ItemData.ItemType.QUIVER:
			pre_bow = ItemData.create("short_bow")
			inv.equip_item(pre_bow, 0)
			slot = 1
			scale = inv.get_off_hand_modifier()
		var before := {"str": stats.base_strength, "dex": stats.base_dexterity,
			"int": stats.base_intelligence, "wis": stats.base_wisdom, "agi": stats.base_agility,
			"det": stats.determination, "hp": stats.max_health, "mana": stats.max_mana,
			"hand": stats.equipment_hand_bonus}
		var granted_before := {}
		for cid in item.granted_card_ids:
			granted_before[cid] = _count_in_deck(cid)
		var ok := inv.equip_item(item, slot)
		_check(ok, "%s equips through the Inventory (%s)" % [id, inv.last_refusal])
		if not ok:
			continue
		var want := {"str": item.strength_bonus, "dex": item.dexterity_bonus,
			"int": item.intelligence_bonus, "wis": item.wisdom_bonus, "agi": item.agility_bonus,
			"det": item.determination_bonus, "hp": item.health_bonus, "mana": item.mana_bonus}
		var got := {"str": stats.base_strength - before["str"], "dex": stats.base_dexterity - before["dex"],
			"int": stats.base_intelligence - before["int"], "wis": stats.base_wisdom - before["wis"],
			"agi": stats.base_agility - before["agi"], "det": stats.determination - before["det"],
			"hp": stats.max_health - before["hp"], "mana": stats.max_mana - before["mana"]}
		var all_ok := true
		for k in want:
			var exp_v: int = ItemData.off_hand_stat(int(want[k]), scale) if scale != 1.0 else int(want[k])
			if int(got[k]) != exp_v:
				all_ok = false
		_check(all_ok, "%s: stat block lands on the wearer (want %s, got %s)" % [id, str(want), str(got)])
		_check(stats.equipment_hand_bonus - before["hand"] == item.hand_size_bonus,
			"%s: hand size +%d" % [id, item.hand_size_bonus])
		# Granted cards reach the deck, one copy per id listed.
		var need := {}
		for cid in item.granted_card_ids:
			need[cid] = int(need.get(cid, 0)) + 1
		for cid in need:
			_check(_count_in_deck(cid) - int(granted_before[cid]) == int(need[cid]),
				"%s: grants %d x %s into the deck" % [id, need[cid], cid])
		# ...and leave with it.
		_clear_gear()
		for cid in need:
			_check(_count_in_deck(cid) == int(granted_before[cid]), "%s: %s leaves the deck on unequip" % [id, cid])
		_check(stats.base_strength == before["str"] and stats.max_health == before["hp"] \
			and stats.max_mana == before["mana"], "%s: unequip gives the stat block back" % id)


# --------------------------------------- slot counts the tooltips spell out

func _test_slot_counts() -> void:
	print("-- Card slots named in the tooltips (bonus, plain) --")
	var want := {
		"sack_of_bone_arrows": [2, 1], "shepherds_crook": [4, 2], "shock_quiver": [2, 1],
		"slotted_rope_half_sleeve": [2, 2], "standard_quiver": [2, 0], "stringless_sender": [2, 2],
		"sword_breaker": [3, 0], "sword_of_theseus": [5, 2], "the_headbandz": [5, 1],
		"the_rapid_recurve": [2, 1], "the_slotted_sash": [6, 1], "tightened_cross_bow": [2, 1],
		"treebeards_branch": [2, 1], "vengeful_shield": [3, 1], "wand_of_clarity": [1, 2],
		"wand_of_deliverance": [2, 1], "wand_of_the_phoenix_feather": [2, 2], "wooden_sword": [1, 0],
	}
	for id in want:
		var it := ItemData.create(id)
		_check(it.card_slots == want[id][0] and it.vanilla_slots == want[id][1],
			"%s: %d bonus + %d plain slots (%d + %d)" % [id, want[id][0], want[id][1], it.card_slots, it.vanilla_slots])

# ------------------------------------------- granted cards: the item's prices

func _test_granted_card_prices() -> void:
	print("-- Granted cards: the numbers each item's tooltip quotes --")
	var want := [
		# [card_id, mana, tempo, note]
		["shift", 0, 0, "Rollerblades: shift (0 mana / 0 tempo)"],
		["slice", 10, 3, "Short Sword: Slice (10 mana, 3 tempo)"],
		["poof_and_weave", 40, 5, "Shadow Obi: Poof and Weave (40 mana, 5 tempo)"],
		["crops", 70, 7, "Shepherds Crook: Crops (70 mana, 7 tempo)"],
		["cinquedea", 10, 0, "Slotted Rope Half Sleeve: Cinquedea (10 mana, 0 tempo)"],
		["reverberate_regrowth", 55, -1, "Bastion: Reverberate Regrowth (55 mana)"],
		["bouncing_shield", 55, 4, "Bastion: Bouncing Shield (55 mana, 4 tempo)"],
		["stone_encase", 45, 5, "Strap of Stone: Stone Encase (45 mana, 5 tempo)"],
		["negotiate", 20, 3, "Suit and Tie: Negotiate (20 mana, 3 tempo)"],
		["detonova", 60, 5, "Supernova Cuirass: Detonova (60 mana, 5 tempo)"],
		["song_of_a_swords_sing", 35, 3, "Sword Breaker: Song of a Swords Sing (35 mana, 3 tempo)"],
		["out_of_guesses", 15, 3, "The Headbandz: Out of Guesses (15 mana / 3 tempo)"],
		["bark_up", 45, 3, "Treebeards Branch: Bark Up (45 mana, 3 tempo)"],
		["mind_mend", 0, 3, "Trench: Mind Mend (costs health, 3 tempo)"],
		["deep_breaths", 30, 4, "Trench: Deep Breaths (30 mana, 4 tempo)"],
		["monk_of_the_night", 50, 4, "Umbral Eclipse: Monk of the Night (50 mana, 4 tempo)"],
		["clear_mind", 50, 4, "Wand of Clarity: Clear Mind (50 mana, 4 tempo)"],
		["from_the_ashes", 80, 2, "Phoenix Feather: From the Ashes (80 mana, 2 tempo)"],
		["improvised_ammo", 45, 0, "Wrist Rocket: Improvised Ammo (45 mana, 0 tempo)"],
	]
	for row in want:
		var c := Card.create_by_id(row[0])
		_check(c != null and c.mana_cost == row[1] and (row[2] < 0 or c.tempo_cost == row[2]),
			"%s (got %d mana, %d tempo)" % [row[3], c.mana_cost if c else -1, c.tempo_cost if c else -1])
	var sl := Card.create_by_id("slice")
	_check(sl.base_damage == 15, "Slice deals 15 damage")
	var cq := Card.create_by_id("cinquedea")
	_check(cq.base_damage == 6 and cq.get_effective_range() == 4, "Cinquedea: 6 damage at range 4")
	_fresh()
	stats.current_armor = 0
	_exec(Card.create_by_id("stone_encase"), main.player)
	_check(stats.current_armor == 50 and dbm.get_debuff(Debuff.DebuffType.STUN) != null, "Stone Encase: gain 50 armor and become stunned (%d)" % stats.current_armor)
	dbm.clear_all_debuffs()
	var mm := Card.create_by_id("mind_mend")
	_check(mm.health_cost == 15, "Mind Mend costs 15 HEALTH")
	_check(Card.create_by_id("deep_breaths").heal_amount == 20, "Deep Breaths heals 20")
	_check(Card.create_by_id("return_cut").card_type == Card.CardType.REACTION, "Return Cut is an Instant")
	_check(Card.create_by_id("reverberate_regrowth").maintain_cost == 55, "Reverberate Regrowth is a 55-mana Maintain")
	_check(Card.create_by_id("monk_of_the_night").maintain_cost == 50, "Monk of the Night is a 50-mana Maintain")
	var ia := Card.create_by_id("improvised_ammo")
	_check(ia.base_damage == 8 and ia.has_on_discard, "Improvised Ammo: 8 damage, a discard effect")
	var dn := Card.create_by_id("detonova")
	_check(dn.damage_type == DamageTypes.Type.FIRE and dn.aoe_range == 2.0, "Detonova: fire, 2 squares around you")
	_check(Card.create_by_id("heal") != null and Card.create_by_id("splinter") != null,
		"Summoners Cap's Heal and Wooden Sword's Splinter exist")
	# The Headbandz Lv.3: Out of Guesses quickens to 1 tempo.
	_fresh()
	var hb := ItemData.create("the_headbandz")
	hb.level_up()
	hb.level_up()
	_check(hb.item_level == 3 and is_equal_approx(hb.on_self_mana_reduction_percent, 35.0),
		"The Headbandz Lv.3: 35% off slotted cards")
	inv.equip_item(hb, 0)
	var oog: Card = null
	for c in hb.granted_card_instances:
		if c.card_id == "out_of_guesses":
			oog = c
	_check(oog != null and oog.get_burden_tempo_cost() == 1, "The Headbandz Lv.3: Out of Guesses costs 1 tempo")
	_clear_gear()

# ------------------------------------------------------------------- rings

func _test_rings() -> void:
	print("-- Rings --")
	# Ring of Thomas the Train Tracks: every shuffle 7 Regen; every 3rd heals 25.
	_fresh()
	var thomas := _equip("ring_of_thomas_the_train_tracks")
	stats.current_health = stats.max_health - 100
	dm.deck_shuffled.emit()
	_check(_regen() == 7, "Thomas: a shuffle grants 7 Regen (%d)" % _regen())
	var hp1: int = stats.current_health
	dm.deck_shuffled.emit()
	_check(stats.current_health == hp1, "Thomas: the 2nd shuffle does not heal")
	var hp2: int = stats.current_health
	dm.deck_shuffled.emit()
	_check(stats.current_health - hp2 >= 25, "Thomas: every 3rd shuffle also heals 25 (%d)" % (stats.current_health - hp2))
	_clear_gear()
	_fresh()
	thomas = ItemData.create("ring_of_thomas_the_train_tracks")
	thomas.level_up()
	thomas.level_up()
	_check(thomas.mana_bonus == 151 and thomas.determination_bonus == 8 and thomas.health_bonus == 11,
		"Thomas Lv.3: +151 mana, +8 DET, +11 health")
	inv.equip_item(thomas, 0)
	stats.current_health = stats.max_health - 100
	dm.deck_shuffled.emit()
	_check(_regen() == 10, "Thomas Lv.3: a shuffle grants 10 Regen (%d)" % _regen())
	var hp3: int = stats.current_health
	dm.deck_shuffled.emit()
	_check(stats.current_health - hp3 >= 35, "Thomas Lv.3: every 2nd shuffle heals 35 (%d)" % (stats.current_health - hp3))
	_clear_gear()

	# The Precious: every 4th enemy hit -> shadow form, three wraiths.
	_fresh()
	var prec := _equip("the_precious")
	var mana_before: int = stats.max_mana
	var brain_before: int = stats.current_brain_points
	var flash_before: int = stats.current_flash_points
	var foes_before: int = main.enemy_spawner.get_living_enemies().size()
	for _h in range(3):
		dummies[0]._deal_damage_to_player(main.player, 1, "Attack")
	_check(stats.shadow_form_tempo == 0, "The Precious: three hits are not enough")
	dummies[0]._deal_damage_to_player(main.player, 1, "Attack")
	_check(stats.shadow_form_tempo == 10, "The Precious: the 4th enemy hit drags you into shadow form for 10 tempo")
	_check(stats.max_mana == mana_before - (mana_before - floori(mana_before / 2.0)), "The Precious: max mana is halved inside (%d -> %d)" % [mana_before, stats.max_mana])
	_check(stats.current_brain_points == brain_before + 10 and stats.current_flash_points == flash_before + 10,
		"The Precious: +10 brain and +10 flash points")
	var wraiths: Array = main._wraiths.filter(func(w): return is_instance_valid(w))
	_check(wraiths.size() == 3, "The Precious: THREE ring wraiths hunt you (%d)" % wraiths.size())
	if wraiths.size() > 0:
		var w: Enemy = wraiths[0]
		var atk_t := 0
		var mv_t := 0
		for a in w.actions:
			if a["name"] == "attack": atk_t = int(a["tempo_cost"])
			if a["name"] == "move": mv_t = int(a["tempo_cost"])
		_check(w.max_health == 100 and w.attack_damage == 15 and atk_t == 2 and mv_t == 4,
			"The Precious: a wraith has 100 HP, 15 damage every 2 tempo, moves every 4 (%d HP, %d dmg, %d/%d)" % [w.max_health, w.attack_damage, atk_t, mv_t])
		_check(is_equal_approx(w.move_distance, 5.0), "The Precious: a wraith moves 5 squares (%.1f)" % w.move_distance)
		w.current_health = 37
	_check(bm.is_invisible(), "The Precious: shadow form hides you")
	Card.create_by_id("slash").execute(dummies[0], stats, dm, 0.0, 0.0, bm)
	_check(bm.is_invisible(), "The Precious: attacking does not reveal you")
	# Clicking the badge leaves — but only after 1 tempo inside.
	var badge := BuffIconUI.new()
	get_root().add_child(badge)
	badge.buff = bm.get_buff(Buff.BuffType.INVISIBLE)
	badge.buff_manager = bm
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	badge._gui_input(click)
	_check(stats.shadow_form_tempo == 10, "The Precious: the badge holds you in until a tempo has passed")
	stats.shadow_form_tempo = 9
	badge._gui_input(click)
	_check(stats.shadow_form_tempo == 0 and main._wraiths.is_empty(), "The Precious: after 1 tempo, clicking the badge leaves shadow form")
	badge.free()
	stats.exit_shadow_form()
	_check(main._wraiths.is_empty() and stats.max_mana == mana_before, "The Precious: leaving returns the mana and sends the wraiths away")
	var stored: Array = prec.ring_counters.get("wraiths", [])
	_check(stored.size() == 3 and int(stored[0]["hp"]) == 37, "The Precious: survivors are remembered exactly as they were left")
	for _h in range(4):
		dummies[0]._deal_damage_to_player(main.player, 1, "Attack")
	var back: Array = main._wraiths.filter(func(w): return is_instance_valid(w))
	_check(back.size() == 3 and back[0].current_health == 37, "The Precious: they return as they were left")
	stats.exit_shadow_form()
	_clear_gear()
	_fresh()
	prec = ItemData.create("the_precious")
	prec.level_up()
	prec.level_up()
	_check(prec.dexterity_bonus == 8 and prec.wisdom_bonus == 3 and prec.mana_bonus == 151 and prec.intelligence_bonus == -2,
		"The Precious Lv.3: +151 mana, +8 DEX, -2 INT, +3 WIS")
	inv.equip_item(prec, 0)
	for _h in range(4):
		dummies[0]._deal_damage_to_player(main.player, 1, "Attack")
	var two: Array = main._wraiths.filter(func(w): return is_instance_valid(w))
	_check(two.size() == 2, "The Precious Lv.3: TWO wraiths (%d)" % two.size())
	stats.exit_shadow_form()
	_clear_gear()
	_check(main.enemy_spawner.get_living_enemies().size() == foes_before, "no wraith is left behind")

# ------------------------------------------------------------------- boots

func _test_boots() -> void:
	print("-- Boots --")
	# Rollerblades: a slotted instant gains 10 armor; movement flash -1.
	_fresh()
	var rb := _equip("rollerblades")
	var vs := _slot(Card.create_by_id("vengeful_shield"), rb)
	stats.current_armor = 0
	_exec(vs, main.player)
	_check(stats.current_armor == 15, "Rollerblades: a slotted instant (5 armor) gains 10 more (%d)" % stats.current_armor)
	stats.current_armor = 0
	var plain_slash := _slot(Card.create_by_id("slash"), rb)
	_exec(plain_slash, dummies[0])
	_check(stats.current_armor == 0, "Rollerblades: a slotted non-instant gains no armor")
	stats.flash_movement_enabled = true
	stats.current_flash_points = 10
	main.tempo_manager.add_movement_tempo()
	_check(stats.current_flash_points == 10 - (PlayerStats.FLASH_COST_MOVE - 1),
		"Rollerblades: a flash move costs 1 less (%d left)" % stats.current_flash_points)
	stats.flash_movement_enabled = false
	# Shift: move up to 2 spaces, free.
	var shift_card: Card = null
	for c in rb.granted_card_instances:
		if c.card_id == "shift":
			shift_card = c
	var home: Vector2i = _pcell()
	var cam = main.get_world_camera()
	_place(dummies[0], home + Vector2i(0, 3))
	_place(dummies[1], home + Vector2i(0, 4))
	main.mouse_override = cam.unproject_position(main.grid_manager.grid_to_world(home + Vector2i(-2, 0)))
	_exec(shift_card, main.player)
	_check(_pcell() == home + Vector2i(-2, 0), "Rollerblades: Shift moves you 2 spaces")
	main.mouse_override = cam.unproject_position(main.grid_manager.grid_to_world(_pcell() + Vector2i(-3, 0)))
	var before_shift: Vector2i = _pcell()
	_exec(shift_card, main.player)
	_check(_pcell() == before_shift, "Rollerblades: ...but no further than 2")
	main.mouse_override = Vector2(-1, -1)
	_place(main.player, home)
	_clear_gear()

	# Steel Boots: 1 unerring armor every 15 tempo.
	_fresh()
	_equip("steel_boots")
	stats.unerring_armor = 0
	inv.process_turn()
	inv.process_turn()
	_check(stats.unerring_armor == 0, "Steel Boots: nothing after 10 tempo")
	inv.process_turn()
	_check(stats.unerring_armor == mini(1, stats.get_unerring_cap()), "Steel Boots: 1 unerring armor at 15 tempo (%d)" % stats.unerring_armor)
	_clear_gear()

	# Titanium Toe Tuckers: any slotted card +8 armor; sidestep +2.
	_fresh()
	var ttt := _equip("titanium_toe_tuckers")
	var tslash := _slot(Card.create_by_id("slash"), ttt)
	stats.current_armor = 0
	_exec(tslash, dummies[0])
	_check(stats.current_armor == 8, "Titanium Toe Tuckers: a slotted attack provides +8 armor (%d)" % stats.current_armor)
	stats.current_armor = 0
	stats.current_flash_points = 20
	stats.spend_flash_for_block()
	_check(stats.current_armor == PlayerStats.FLASH_BLOCK_ARMOR + 2, "Titanium Toe Tuckers: side step gives 2 more armor (%d)" % stats.current_armor)
	_clear_gear()

# --------------------------------------------------------------- gauntlets

func _skill(g: ItemData, target) -> Dictionary:
	## Fire a gauntlet skill as the skill bar does; report what it cost.
	## (The clock is set to the start of a cycle so the skill's own tempo never
	## rolls a cycle over and ticks the fresh cooldown; mana regen on that tempo
	## is excluded by watching the lowest mana seen.)
	stats.current_mana = stats.max_mana
	main.tempo_manager.current_tempo = 0
	var m0: int = int(stats.current_mana)
	var low := [m0]
	var watch := func(cur, _mx): low[0] = mini(low[0], int(cur))
	stats.mana_changed.connect(watch)
	var t0: int = main.tempo_manager.global_tempo
	main._fire_gauntlet_skill(g, target)
	stats.mana_changed.disconnect(watch)
	return {"mana": m0 - low[0], "tempo": main.tempo_manager.global_tempo - t0, "cd": g.current_cooldown}

func _test_gauntlets() -> void:
	print("-- Gauntlets --")
	# Roman Bracers: slotted melee offensive +5; Slice for 2 tempo, 10 tempo CD.
	_fresh()
	var rbr := _equip("roman_bracers")
	var base_slash := Card.create_by_id("slash")
	base_slash.execute(dummies[0], stats, dm, 0.0, 0.0, bm)
	var plain: int = _dmg(dummies[0])
	_reset_dummy(dummies[0])
	_exec(_slot(Card.create_by_id("slash"), rbr), dummies[0])
	_check(_dmg(dummies[0]) == plain + 5, "Roman Bracers: a slotted melee attack deals +5 (%d vs %d)" % [_dmg(dummies[0]), plain])
	_reset_dummy(dummies[0])
	var fb := Card.create_by_id("fireball")
	fb.execute(dummies[0], stats, dm, 0.0, 0.0, bm)
	var fb_plain: int = fb.last_damage_dealt
	_reset_dummy(dummies[0])
	var fb2 := _slot(Card.create_by_id("fireball"), rbr)
	fb2.execute(dummies[0], stats, dm, 0.0, 0.0, bm)
	_check(fb2.last_damage_dealt == fb_plain, "Roman Bracers: a ranged card gets nothing")
	_reset_dummy(dummies[0])
	var r := _skill(rbr, dummies[0])
	_check(_dmg(dummies[0]) > 0, "Roman Bracers: Slice strikes the enemy (%d)" % _dmg(dummies[0]))
	_check(r["tempo"] == 2, "Roman Bracers: Slice costs 2 tempo (%d)" % r["tempo"])
	_check(r["cd"] * 5 == 10, "Roman Bracers: Slice has a 10 tempo cooldown")
	_clear_gear()

	# Sleeved Katar: +25% crit damage, +5% crit; Defense one with offense.
	_fresh()
	var cd0: float = stats.equipment_crit_damage_bonus
	var cc0: float = stats.equipment_crit_bonus
	var sk := _equip("sleeved_katar")
	_check(is_equal_approx(stats.equipment_crit_damage_bonus - cd0, 0.25), "Sleeved Katar: +25% crit damage")
	_check(is_equal_approx(stats.equipment_crit_bonus - cc0, 5.0), "Sleeved Katar: +5% crit chance")
	stats.equipment_crit_bonus = -100.0
	plain = _slash_plain()
	stats.current_armor = 0
	r = _skill(sk, null)
	_check(stats.current_armor == 5, "Sleeved Katar: the skill grants 5 armor (%d)" % stats.current_armor)
	_check(r["cd"] * 5 == 25, "Sleeved Katar: 25 tempo cooldown")
	_reset_dummy(dummies[0])
	Card.create_by_id("slash").execute(dummies[0], stats, dm, 0.0, 0.0, bm)
	_check(_dmg(dummies[0]) == plain + 5, "Sleeved Katar: the next melee card deals +5 (%d vs %d)" % [_dmg(dummies[0]), plain])
	_reset_dummy(dummies[0])
	Card.create_by_id("slash").execute(dummies[0], stats, dm, 0.0, 0.0, bm)
	_check(_dmg(dummies[0]) == plain, "Sleeved Katar: ...only the next one")
	_clear_gear()

	# Spidey Web Shooters: slotted offensive Disarms 5 tempo; Coming in!.
	_fresh()
	var sw := _equip("spidey_web_shooters")
	_exec(_slot(Card.create_by_id("slash"), sw), dummies[0])
	_check(dummies[0].is_disarmed and dummies[0].disarmed_tempo == 5, "Spidey: a slotted offensive card Disarms for 5 tempo (%d)" % dummies[0].disarmed_tempo)
	var start: Vector2i = _pcell()
	_place(dummies[1], start + Vector2i(5, 0))
	r = _skill(sw, dummies[1])
	var now_d: int = main.grid_manager.get_distance_in_cells(main.player.position, dummies[1].position)
	_check(now_d <= 1, "Spidey: Coming in! pulls you to a target 5 squares away (now %d)" % now_d)
	_check(r["cd"] * 5 == 10, "Spidey: Coming in! has a 10 tempo cooldown")
	_place(main.player, start)
	_clear_gear()

	# Spiked Mitts: any card +5 armor; every 25 armor -> 5 thorns; skill 5 thorns.
	_fresh()
	var smt := _equip("spiked_mitts")
	main._spiked_armor_accum = 0
	stats.current_armor = 0
	_exec(_slot(Card.create_by_id("slash"), smt), dummies[0])
	_check(stats.current_armor == 5, "Spiked Mitts: ANY slotted card provides +5 armor (%d)" % stats.current_armor)
	for b in bm.buffs.duplicate():
		bm.remove_buff_instance(b)
	stats.add_armor(20)
	_check(_thorns() == 5, "Spiked Mitts: 25 armor gained -> 5 thorns (%d)" % _thorns())
	for b in bm.buffs.duplicate():
		bm.remove_buff_instance(b)
	r = _skill(smt, null)
	_check(_thorns() == 5 and r["mana"] == 15 and r["cd"] * 5 == 15,
		"Spiked Mitts: Well placed guard — 5 thorns, 15 mana, 15 tempo CD (%d, %d, %d)" % [_thorns(), r["mana"], r["cd"] * 5])
	_clear_gear()

	# Techno Wraps: Future is bright — discard into the draw pile.
	_fresh()
	var tw := _equip("techno_wraps")
	var moved := Card.create_by_id("slash")
	dm.discard_pile.append(moved)
	r = _skill(tw, null)
	_check(not (moved in dm.discard_pile) and moved in dm.draw_pile, "Techno Wraps: the discard pile shuffles into the draw pile")
	_check(r["cd"] * 5 == 15, "Techno Wraps: 15 tempo cooldown")
	_clear_gear()

# ------------------------------------------------------------------- helms

func _test_helms() -> void:
	print("-- Helms --")
	# Scholars Cap: +5 max brain, Peek -1, slotted card +2 brain.
	_fresh()
	var mb0: int = stats.get_max_brain_points()
	var pk0: int = stats.get_next_brain_peek_cost()
	var sc := _equip("scholars_cap")
	_check(stats.get_max_brain_points() == mb0 + 5 + 5, "Scholars Cap: +5 max brain points (on top of its +5 WIS) (%d -> %d)" % [mb0, stats.get_max_brain_points()])
	_check(stats.get_next_brain_peek_cost() == maxi(1, pk0 - 1), "Scholars Cap: Peek costs 1 less")
	stats.current_brain_points = 0
	_exec(_slot(Card.create_by_id("slash"), sc), dummies[0])
	_check(stats.current_brain_points == 2, "Scholars Cap: any slotted card regains 2 brain points (%d)" % stats.current_brain_points)
	_clear_gear()
	var sc3 := ItemData.create("scholars_cap")
	sc3.level_up()
	sc3.level_up()
	_check(sc3.wisdom_bonus == 7 and sc3.brain_points_bonus == 7 and sc3.on_self_brain_regen == 3,
		"Scholars Cap Lv.3: +7 WIS, +7 max brain, regains 3")

	# Shamans mask: slotted utility heals 3 and zaps an enemy within 3 for 1.
	_fresh()
	var sm := _equip("shamans_mask")
	stats.current_health = stats.max_health - 100
	var hp0: int = stats.current_health
	_exec(Card.create_by_id("heal"), main.player)
	var plain_heal: int = stats.current_health - hp0
	stats.current_health = stats.max_health - 100
	hp0 = stats.current_health
	_exec(_slot(Card.create_by_id("heal"), sm), main.player)
	# The rider is a heal of 3 through the wearer's heal pipeline (INT and
	# healing bonuses apply to every heal, PlayerStats.heal).
	_check(stats.current_health - hp0 == plain_heal + stats.get_effective_heal_amount(3), "Shamans mask: a slotted utility card heals 3 (%d vs %d)" % [stats.current_health - hp0, plain_heal])
	_check(_dmg(dummies[0]) == 1 and _dmg(dummies[1]) == 0, "Shamans mask: 1 spell damage to the enemy within 3, not the one at 5")
	_reset_dummy(dummies[0])
	stats.current_health = stats.max_health - 100
	hp0 = stats.current_health
	_exec(_slot(Card.create_by_id("slash"), sm), dummies[0])
	_check(stats.current_health == hp0, "Shamans mask: a non-utility card neither heals...")
	_check(_dmg(dummies[1]) == 0, "...nor zaps")
	# A utility-TAGGED instant is a utility card (docs/CARD_TAXONOMY.md):
	# Healthy Bliss (Instant, tags reaction/utility/spell).
	_reset_dummy(dummies[0])
	var hbl := _slot(Card.create_by_id("healthy_bliss"), sm)
	hbl.heal_amount = 0  # only the rider's heal is measured
	stats.current_health = stats.max_health - 100
	hp0 = stats.current_health
	_exec(hbl, main.player)
	_check(stats.current_health - hp0 == stats.get_effective_heal_amount(3) and _dmg(dummies[0]) == 1,
		"Shamans mask: a utility-tagged instant counts as a utility card (healed %d, zapped %d)" % [stats.current_health - hp0, _dmg(dummies[0])])
	_clear_gear()

	# Summoners Cap: +3 on a heal card; a non-heal card heals you 3.
	_fresh()
	var scap := _equip("summoners_cap")
	stats.current_health = stats.max_health - 100
	hp0 = stats.current_health
	_exec(Card.create_by_id("heal"), main.player)
	plain_heal = stats.current_health - hp0
	stats.current_health = stats.max_health - 100
	hp0 = stats.current_health
	_exec(_slot(Card.create_by_id("heal"), scap), main.player)
	_check(stats.current_health - hp0 == plain_heal + 3, "Summoners Cap: a slotted heal heals 3 more (%d)" % (stats.current_health - hp0))
	stats.current_health = stats.max_health - 100
	hp0 = stats.current_health
	_exec(_slot(Card.create_by_id("slash"), scap), dummies[0])
	_check(stats.current_health - hp0 >= 3, "Summoners Cap: a slotted card that doesn't heal heals you 3 (%d)" % (stats.current_health - hp0))
	_clear_gear()

	# The Headbandz: slotted cards cost 20% less mana.
	_fresh()
	var hb := _equip("the_headbandz")
	var fbc := Card.create_by_id("fireball")
	dm.hand.clear()
	dm.hand.append(fbc)
	var full: int = int(dm.compute_play_cost(fbc, 0, dummies[0])["mana"])
	_slot(fbc, hb)
	var cut: int = int(dm.compute_play_cost(fbc, 0, dummies[0])["mana"])
	_check(cut == floori(full * 0.8), "The Headbandz: a slotted card costs 20%% less mana (%d -> %d)" % [full, cut])
	dm.hand.clear()
	_clear_gear()

	# Thick Steel Helm: 10% resistance to all; armor cards +2.
	_fresh()
	_equip("thick_steel_helm")
	var before: int = stats.current_health
	stats.take_damage(100, null, null, DamageTypes.Type.FIRE)
	_check(before - stats.current_health == 90, "Thick Steel Helm: 10%% resistance to all damage (fire 100 -> %d)" % (before - stats.current_health))
	stats.current_armor = 0
	Card.create_by_id("parry").execute(dummies[0], stats, dm, 0.0, 0.0, bm)
	_check(stats.current_armor == 7, "Thick Steel Helm: an armor card grants 2 more (Parry 5 -> %d)" % stats.current_armor)
	stats.current_armor = 0
	Card.create_by_id("vengeful_shield").execute(main.player, stats, dm, 0.0, 0.0, bm)
	_check(stats.current_armor == 7, "Thick Steel Helm: ...of any type (an instant, %d)" % stats.current_armor)
	_clear_gear()

	# Wizard Hat: every 3rd attack arms +5 spell power on the next spell.
	_fresh()
	_equip("wizard_hat")
	_reset_dummy(dummies[0])
	var f0 := Card.create_by_id("fireball")
	f0.execute(dummies[0], stats, dm, 0.0, 0.0, bm)
	var fb_base: int = f0.last_damage_dealt
	stats.register_attack()
	stats.register_attack()
	_check(stats.pending_spell_power_bonus == 0, "Wizard Hat: two attacks arm nothing")
	stats.register_attack()
	_check(stats.pending_spell_power_bonus == 5, "Wizard Hat: the 3rd attack arms +5 spell power")
	var f1 := Card.create_by_id("fireball")
	f1.execute(dummies[0], stats, dm, 0.0, 0.0, bm)
	_check(f1.last_damage_dealt == fb_base + 5, "Wizard Hat: the next spell deals +5 (%d vs %d)" % [f1.last_damage_dealt, fb_base])
	_check(stats.pending_spell_power_bonus == 0, "Wizard Hat: ...and spends it")
	_clear_gear()

# ------------------------------------------------------------------ chests

func _slash_plain() -> int:
	_reset_dummy(dummies[0])
	Card.create_by_id("slash").execute(dummies[0], stats, dm, 0.0, 0.0, bm)
	var d: int = _dmg(dummies[0])
	_reset_dummy(dummies[0])
	return d

func _test_chests() -> void:
	print("-- Chests --")
	# Shadow Cowl: slotted offensive +2 damage, next 2 tiles free.
	_fresh()
	var plain: int = _slash_plain()
	var cowl := _equip("shadow_cowl")
	_exec(_slot(Card.create_by_id("slash"), cowl), dummies[0])
	_check(_dmg(dummies[0]) == plain + 2, "Shadow Cowl: a slotted offensive card deals +2 (%d vs %d)" % [_dmg(dummies[0]), plain])
	_check(stats.free_move_tiles == 2, "Shadow Cowl: ...and makes the next 2 tiles free")
	var t0: int = main.tempo_manager.global_tempo
	main.tempo_manager.add_movement_tempo()
	main.tempo_manager.add_movement_tempo()
	_check(main.tempo_manager.global_tempo == t0, "Shadow Cowl: the 2 tiles cost no tempo")
	stats.free_move_tiles = 0
	stats.current_armor = 0
	_exec(_slot(Card.create_by_id("parry"), cowl), dummies[0])
	_check(stats.free_move_tiles == 0 or Card.create_by_id("parry").is_offensive(), "Shadow Cowl: a non-offensive card shifts nothing")
	_clear_gear()

	# Smithed Excellence: slotted card -> 2% all-resist for 3 tempo; armor -> +10% physical.
	_fresh()
	var smith := _equip("smithed_excellence")
	stats.current_armor = 30
	var pool: int = stats.current_health + stats.current_armor
	stats.take_damage(100)
	_check(pool - (stats.current_health + stats.current_armor) == 90, "Smithed Excellence: with block up, 10%% more physical resistance (took %d)" % (pool - (stats.current_health + stats.current_armor)))
	stats.current_armor = 0
	_exec(_slot(Card.create_by_id("slash"), smith), dummies[0])
	var res = bm.get_buff(Buff.BuffType.RESILIENT)
	_check(res != null and bm.get_resilient_percent(DamageTypes.Type.FIRE) == 2 and res.duration == 3,
		"Smithed Excellence: a slotted card grants 2%% resistance to all types for 3 tempo (%s)" % ("%d%%/%d" % [bm.get_resilient_percent(DamageTypes.Type.FIRE), res.duration] if res else "none"))
	_clear_gear()

	# Steel Plate: 8 unerring armor every 20 tempo (up to the cap).
	_fresh()
	_equip("steel_plate")
	stats.unerring_armor = 0
	for _c in range(3):
		inv.process_turn()
	_check(stats.unerring_armor == 0, "Steel Plate: nothing at 15 tempo")
	inv.process_turn()
	_check(stats.unerring_armor == mini(8, stats.get_unerring_cap()), "Steel Plate: at 20 tempo, up to your unerring cap (%d, cap %d)" % [stats.unerring_armor, stats.get_unerring_cap()])
	stats.equipment_unerring_cap += 50
	stats.unerring_armor = 0
	for _c in range(4):
		inv.process_turn()
	_check(stats.unerring_armor == 8, "Steel Plate: 8 unerring armor every 20 tempo with room under the cap (%d)" % stats.unerring_armor)
	stats.equipment_unerring_cap -= 50
	_clear_gear()

	# Supernova Cuirass: 10% of a hit banked as a stack, 2% mitigated; max 10;
	# Detonova spends the bank as fire 2 squares around you, no INT.
	_fresh()
	var nova := _equip("supernova_cuirass")
	var hpn: int = stats.current_health
	stats.take_damage(100)
	_check(hpn - stats.current_health == 88 and is_equal_approx(nova.banked_damage, 10.0) and nova.banked_stacks == 1,
		"Supernova: a 100 hit lands as 88, 10 harnessed as one stack (%d, %.1f)" % [hpn - stats.current_health, nova.banked_damage])
	nova.banked_stacks = 10
	hpn = stats.current_health
	stats.take_damage(100)
	_check(hpn - stats.current_health == 100, "Supernova: with no stack room (10) it absorbs nothing")
	nova.banked_stacks = 1
	var deto: Card = null
	for c in nova.granted_card_instances:
		if c.card_id == "detonova":
			deto = c
	_reset_dummy(dummies[0])
	_reset_dummy(dummies[1])
	_exec(deto, main.player)
	_check(_dmg(dummies[0]) == 10 and _dmg(dummies[1]) == 0, "Supernova: Detonova deals the absorbed 10 within 2 squares, unscaled by INT (%d / %d)" % [_dmg(dummies[0]), _dmg(dummies[1])])
	_check(nova.banked_stacks == 0 and is_equal_approx(nova.banked_damage, 0.0), "Supernova: Detonova purges the stacks")
	_clear_gear()

	# Suit and Tie: heal 3 on gold.
	_fresh()
	_equip("suit_and_tie")
	stats.current_health = stats.max_health - 50
	var hp: int = stats.current_health
	stats.gain_gold(5)
	_check(stats.current_health - hp >= 3, "Suit and Tie: obtaining gold heals 3 (%d)" % (stats.current_health - hp))
	_clear_gear()

	# Tigers Sunday Red: +1 range on ranged offensive; HP-gap damage /4; 3% heal.
	_fresh()
	var tsr := _equip("tigers_sunday_red")
	_check(main._helm_range_bonus(Card.create_by_id("fireball")) == 1, "Tigers: +1 range on a ranged offensive card")
	_check(main._helm_range_bonus(Card.create_by_id("heal")) == 0, "Tigers: no range on a ranged utility card")
	var big := Card.create_by_id("slash")
	big.base_damage = 40
	_reset_dummy(dummies[0])
	big.execute(dummies[0], stats, dm, 0.0, 0.0, bm)
	var at_full: int = _dmg(dummies[0])
	_reset_dummy(dummies[0])
	dummies[0].current_health = 500  # 50% vs the wearer's 100%: gap 50 / 4 = 12.5%
	big.execute(dummies[0], stats, dm, 0.0, 0.0, bm)
	var at_half: int = 500 - dummies[0].current_health
	_check(at_half - at_full == floori(40 * 12.5 / 100.0), "Tigers: +(HP-gap / 4)%% damage (%d vs %d)" % [at_half, at_full])
	stats.current_health = stats.max_health - 100
	hp = stats.current_health
	_reset_dummy(dummies[0])
	_exec(_slot(Card.create_by_id("slash"), tsr), dummies[0])
	_check(stats.current_health - hp == stats.get_effective_heal_amount(floori(stats.max_health * 0.03)), "Tigers: a slotted offensive card heals 3%% of max health (%d)" % (stats.current_health - hp))
	_clear_gear()
	var tsr3 := ItemData.create("tigers_sunday_red")
	tsr3.level_up()
	tsr3.level_up()
	_check(tsr3.hp_diff_damage_divisor == 3 and is_equal_approx(tsr3.on_self_offensive_heal_percent, 6.0)
		and tsr3.health_bonus == 16 and tsr3.agility_bonus == 6 and tsr3.dexterity_bonus == 6,
		"Tigers Lv.3: /3 gap, 6% heal, +16 health, +6 AGI, +6 DEX")

	# Trench of Tranquility: non-heal card heals you 5; heal card heals 5 more.
	_fresh()
	var tr := _equip("trench_of_tranquility")
	stats.current_health = stats.max_health - 100
	hp = stats.current_health
	_exec(Card.create_by_id("heal"), main.player)
	var plain_heal: int = stats.current_health - hp
	stats.current_health = stats.max_health - 100
	hp = stats.current_health
	_exec(_slot(Card.create_by_id("heal"), tr), main.player)
	_check(stats.current_health - hp == plain_heal + 5, "Trench: a slotted heal card heals 5 more (%d vs %d)" % [stats.current_health - hp, plain_heal])
	stats.current_health = stats.max_health - 100
	hp = stats.current_health
	_exec(_slot(Card.create_by_id("slash"), tr), dummies[0])
	_check(stats.current_health - hp >= 5, "Trench: a slotted card that doesn't heal heals you 5 (%d)" % (stats.current_health - hp))
	_clear_gear()

	# Velvet Plate: any slotted card heals you 5.
	_fresh()
	var vp := _equip("velvet_plate")
	stats.current_health = stats.max_health - 100
	hp = stats.current_health
	_exec(_slot(Card.create_by_id("slash"), vp), dummies[0])
	_check(stats.current_health - hp >= 5, "Velvet Plate: a slotted attack heals you 5 (%d)" % (stats.current_health - hp))
	_clear_gear()

	# Wooden Plank: dropping below 50% grants 1 Regen.
	_fresh()
	_equip("wooden_plank")
	stats.current_health = int(stats.max_health * 0.55)
	dummies[0]._deal_damage_to_player(main.player, int(stats.max_health * 0.1), "Attack")
	_check(_regen() == 1, "Wooden Plank: the hit that drops you below half grants 1 Regen (%d)" % _regen())
	dummies[0]._deal_damage_to_player(main.player, 5, "Attack")
	_check(_regen() == 1, "Wooden Plank: further hits below half grant no more")
	_clear_gear()

# ------------------------------------------------------------------- belts

func _test_belts() -> void:
	print("-- Belts --")
	# Shadow Obi: +5 while invisible; a card under 2 tempo zaps an enemy for 3.
	_fresh()
	var plain: int = _slash_plain()
	var obi := _equip("shadow_obi")
	var s1 := _slot(Card.create_by_id("slash"), obi)
	s1.execute(dummies[0], stats, dm, 0.0, 0.0, bm)
	_check(_dmg(dummies[0]) == plain, "Shadow Obi: no bonus while visible")
	_reset_dummy(dummies[0])
	bm.apply_buff(Buff.create_invisible(10, "test"))
	s1.execute(dummies[0], stats, dm, 0.0, 0.0, bm)
	_check(_dmg(dummies[0]) == plain + 5, "Shadow Obi: +5 damage while invisible (%d vs %d)" % [_dmg(dummies[0]), plain])
	bm.remove_buff(Buff.BuffType.INVISIBLE)
	_reset_dummy(dummies[0])
	_reset_dummy(dummies[1])
	var cheap := Card.create_by_id("heal")
	cheap.tempo_cost = 1
	_exec(cheap, main.player)
	_check(_dmg(dummies[0]) + _dmg(dummies[1]) == 3, "Shadow Obi: an unslotted 1-tempo card deals 3 to a random enemy (%d)" % (_dmg(dummies[0]) + _dmg(dummies[1])))
	_reset_dummy(dummies[0])
	_reset_dummy(dummies[1])
	_exec(Card.create_by_id("heal"), main.player)  # 2 tempo
	_check(_dmg(dummies[0]) + _dmg(dummies[1]) == 0, "Shadow Obi: a 2-tempo card zaps nothing")
	_clear_gear()

	# Strap of Stone: 10 unerring every 20 tempo; slotted card 10% physical for 10 tempo.
	_fresh()
	var strap := _equip("strap_of_stone")
	stats.equipment_unerring_cap += 50
	stats.unerring_armor = 0
	for _c in range(3):
		inv.process_turn()
	_check(stats.unerring_armor == 0, "Strap of Stone: nothing at 15 tempo")
	inv.process_turn()
	_check(stats.unerring_armor == 10, "Strap of Stone: 10 unerring armor every 20 tempo (%d)" % stats.unerring_armor)
	stats.equipment_unerring_cap -= 50
	stats.unerring_armor = 0
	for _c in range(4):
		inv.process_turn()
	_check(stats.unerring_armor == mini(10, stats.get_unerring_cap()), "Strap of Stone: ...up to your unerring cap (%d)" % stats.unerring_armor)
	_exec(_slot(Card.create_by_id("slash"), strap), dummies[0])
	var res = bm.get_buff(Buff.BuffType.RESILIENT)
	_check(res != null and bm.get_resilient_percent(DamageTypes.Type.PHYSICAL) == 10 and res.duration == 10
		and bm.get_resilient_percent(DamageTypes.Type.FIRE) == 0,
		"Strap of Stone: a slotted card grants 10% physical resistance for 10 tempo")
	_clear_gear()

	# Studded belt: any slotted card -> 3 thorns.
	_fresh()
	var sb := _equip("studded_belt")
	_exec(_slot(Card.create_by_id("parry"), sb), dummies[0])
	_check(_thorns() == 3, "Studded belt: any slotted card gains you 3 thorns (%d)" % _thorns())
	_clear_gear()

	# Tactical belt: a card aimed at an enemy blasts 2 around its target.
	_fresh()
	var tb := _equip("tactical_belt")
	_place(dummies[1], _pcell() + Vector2i(2, 0))  # beside dummy A
	var hp0: int = stats.current_health
	var tc := _slot(Card.create_by_id("slash"), tb)
	_exec(tc, dummies[0])
	_check(_dmg(dummies[1]) == 2, "Tactical belt: the enemy beside the target takes 2 (%d)" % _dmg(dummies[1]))
	_check(_dmg(dummies[0]) == tc.last_damage_dealt + 2, "Tactical belt: ...and so does the target")
	_check(stats.current_health == hp0, "Tactical belt: the wielder (an ally beside the target) is unharmed")
	# Only a card AIMED AT AN ENEMY detonates: a slotted self-cast card (a heal
	# on yourself) must not blast the enemies standing next to you.
	_place_dummies()
	_reset_dummy(dummies[0])
	_exec(_slot(Card.create_by_id("heal"), tb), main.player)
	_check(_dmg(dummies[0]) == 0, "Tactical belt: a card aimed at yourself detonates nothing (%d to the enemy beside you)" % _dmg(dummies[0]))
	# Its plain slot confers nothing.
	_place(dummies[1], _pcell() + Vector2i(2, 0))
	_reset_dummy(dummies[1])
	_exec(_slot_plain(Card.create_by_id("slash"), tb), dummies[0])
	_check(_dmg(dummies[1]) == 0, "Tactical belt: a card in the plain slot detonates nothing (%d)" % _dmg(dummies[1]))
	_clear_gear()

	# The Slotted Sash: offensive +2; defense +2 armor; utility Weakens an enemy within 5.
	_fresh()
	plain = _slash_plain()
	var sash := _equip("the_slotted_sash")
	_exec(_slot(Card.create_by_id("slash"), sash), dummies[0])
	_check(_dmg(dummies[0]) == plain + 2, "Slotted Sash: offensive cards +2 damage (%d vs %d)" % [_dmg(dummies[0]), plain])
	stats.current_armor = 0
	_exec(_slot(Card.create_by_id("parry"), sash), dummies[0])
	_check(stats.current_armor == 7, "Slotted Sash: defense cards +2 armor (Parry 5 -> %d)" % stats.current_armor)
	# A defense-TAGGED instant is a defense card (docs/CARD_TAXONOMY.md):
	# Vengeful Shield (Instant, tags reaction/defense, 5 armor).
	stats.current_armor = 0
	_exec(_slot(Card.create_by_id("vengeful_shield"), sash), main.player)
	_check(stats.current_armor == 7, "Slotted Sash: a defense-tagged instant counts as a defense card (Vengeful Shield 5 -> %d)" % stats.current_armor)
	_reset_dummy(dummies[0])
	_reset_dummy(dummies[1])
	var hbl := _slot(Card.create_by_id("healthy_bliss"), sash)
	hbl.heal_amount = 0
	_exec(hbl, main.player)
	_check(dummies[0].weaken_stacks + dummies[1].weaken_stacks == 1, "Slotted Sash: a utility-tagged instant Weakens like a utility card")
	# Its 1 plain slot confers nothing (the riders live in the 6 bonus slots).
	_reset_dummy(dummies[0])
	_reset_dummy(dummies[1])
	_exec(_slot_plain(Card.create_by_id("heal"), sash), main.player)
	_check(dummies[0].weaken_stacks + dummies[1].weaken_stacks == 0, "Slotted Sash: a utility card in the plain slot Weakens nothing")
	_reset_dummy(dummies[0])
	_reset_dummy(dummies[1])
	_exec(_slot(Card.create_by_id("heal"), sash), main.player)
	_check(dummies[0].weaken_stacks + dummies[1].weaken_stacks == 1, "Slotted Sash: a utility card Weakens a random enemy within 5")
	_clear_gear()

	# Waistband: any slotted card +2 armor.
	_fresh()
	var wb := _equip("waistband")
	stats.current_armor = 0
	_exec(_slot(Card.create_by_id("slash"), wb), dummies[0])
	_check(stats.current_armor == 2, "Waistband: any slotted card gains you 2 armor (%d)" % stats.current_armor)
	_clear_gear()

# ----------------------------------------------------------------- quivers

func _test_quivers() -> void:
	print("-- Quivers (always worn in the off hand, beside a bow) --")
	# Standard Quiver: +1 range on offensive cards.
	_fresh()
	var sq := _equip("standard_quiver")
	_check(sq.is_in_off_hand, "Standard Quiver sits in the off hand")
	var arrow := _slot(Card.create_by_id("quick_shot"), sq)
	_check(int(sq.get_on_self_bonus().get("range_offensive", 0)) == 0 and main._helm_range_bonus(arrow) == 0,
		"Standard Quiver (FLAG): the off hand floors its +1 range to 0 (%d)" % main._helm_range_bonus(arrow))
	_clear_gear()

	# Shock Quiver: 2 Shock on a hit, +5% crit.
	_fresh()
	var shq := _equip("shock_quiver")
	var osb: Dictionary = shq.get_on_self_bonus()
	_check(int(osb.get("apply_shock", 0)) == 1 and is_equal_approx(float(osb.get("crit_percent", 0.0)), 4.5),
		"Shock Quiver (FLAG): the off hand makes 2 Shock / 5%% crit into %d / %.1f%%" % [int(osb.get("apply_shock", 0)), float(osb.get("crit_percent", 0.0))])
	var qs := _slot(Card.create_by_id("quick_shot"), shq)
	_place(dummies[0], _pcell() + Vector2i(2, 0))
	qs.execute(dummies[0], stats, dm, 0.0, 0.0, bm)
	_check(dummies[0].shock_stacks == 1, "Shock Quiver: a slotted hit applies its (off-hand) Shock (%d)" % dummies[0].shock_stacks)
	_clear_gear()

	# Sack of Bone Arrows: a slotted kill raises a skeleton at half max health.
	_fresh()
	var sack := _equip("sack_of_bone_arrows")
	for s in main._skeletons:
		if is_instance_valid(s):
			s.queue_free()
	main._skeletons.clear()
	var victims: Array = []
	for i in range(4):
		var e: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.values()[0], main.grid_manager.grid_to_world(_pcell() + Vector2i(2, i - 1)))
		e.chosen_action = {}
		e.max_health = 40
		e.current_health = 1
		victims.append(e)
	var shot := _slot(Card.create_by_id("quick_shot"), sack)
	_exec(shot, victims[0])
	var skels: Array = main._skeletons.filter(func(s): return is_instance_valid(s) and not s.is_dead)
	_check(victims[0].is_dead and skels.size() == 1, "Sack of Bone Arrows: a kill with a slotted offensive card raises a skeleton")
	if skels.size() > 0:
		var sk = skels[0]
		_check(sk.max_health == 20 and sk.base_attack == 5 and sk.move_steps == 4 and sk.attack_interval == 5,
			"Sack: half the victim's max health (20), 5 damage, 4 squares, attacks every 5 (%d HP)" % sk.max_health)
	for i in range(1, 4):
		_exec(shot, victims[i])
	skels = main._skeletons.filter(func(s): return is_instance_valid(s) and not s.is_dead)
	_check(skels.size() == 3, "Sack: up to 3 at once (%d after 4 kills)" % skels.size())
	for s in main._skeletons:
		if is_instance_valid(s):
			s.queue_free()
	main._skeletons.clear()
	for e in victims:
		if is_instance_valid(e) and not e.is_dead:
			main.enemy_spawner.despawn_enemy(e)
	_clear_gear()

# -------------------------------------------------------------------- bows

func _test_bows() -> void:
	print("-- Bows --")
	# Short Bow: two-handed; a quiver pairs with it.
	_fresh()
	_check(Inventory.is_two_hand_only(ItemData.create("short_bow")), "Short Bow is two-handed")
	_equip("short_bow")
	_check(inv.hand_conflict_reason(ItemData.create("short_sword"), 1) != "", "Short Bow: no second weapon")
	_check(inv.equip_item(ItemData.create("standard_quiver"), 1), "Short Bow: pairs with a quiver")
	_clear_gear()

	# Stringless Sender: -1 tempo, +10 mana; 20% bounce at full damage.
	_fresh()
	var ss := _equip("stringless_sender")
	var arrow := Card.create_by_id("quick_shot")
	dm.hand.clear()
	dm.hand.append(arrow)
	var t_full: int = arrow.get_burden_tempo_cost()
	var m_full: int = int(dm.compute_play_cost(arrow, 0, dummies[0])["mana"])
	_slot(arrow, ss)
	_check(arrow.get_burden_tempo_cost() == maxi(0, t_full - 1), "Stringless Sender: 1 less tempo")
	_check(int(dm.compute_play_cost(arrow, 0, dummies[0])["mana"]) == m_full + 10, "Stringless Sender: 10 more mana")
	dm.hand.clear()
	_place(dummies[0], _pcell() + Vector2i(2, 0))
	_place(dummies[1], _pcell() + Vector2i(4, 0))
	seed(1234)
	var bounces := 0
	var exact := true
	for _i in range(100):
		_reset_dummy(dummies[0])
		_reset_dummy(dummies[1])
		_exec(arrow, dummies[0])
		if _dmg(dummies[1]) > 0:
			bounces += 1
			if _dmg(dummies[1]) != arrow.last_damage_dealt:
				exact = false
	_check(bounces >= 10 and bounces <= 30, "Stringless Sender: ~20%% of shots bounce (%d/100)" % bounces)
	_check(exact, "Stringless Sender: the bounce lands at full damage")
	_clear_gear()

	# The Rapid Recurve: 1.5x mana, jailed 20 tempo, Double Shot.
	_fresh()
	var rr := _equip("the_rapid_recurve")
	var ra := Card.create_by_id("quick_shot")
	dm.hand.clear()
	dm.hand.append(ra)
	var m0: int = int(dm.compute_play_cost(ra, 0, dummies[0])["mana"])
	_slot(ra, rr)
	_check(int(dm.compute_play_cost(ra, 0, dummies[0])["mana"]) == ceili(m0 * 1.5), "Rapid Recurve: 1.5x mana")
	_place(dummies[0], _pcell() + Vector2i(2, 0))
	_reset_dummy(dummies[0])
	var one := Card.create_by_id("quick_shot")
	one.execute(dummies[0], stats, dm, 0.0, 0.0, bm)
	var single: int = _dmg(dummies[0])
	_reset_dummy(dummies[0])
	stats.current_mana = stats.max_mana
	_play(ra, dummies[0])
	_check(_dmg(dummies[0]) == single * 2, "Rapid Recurve: Double Shot hits a second time at full damage (%d vs %d)" % [_dmg(dummies[0]), single])
	_check(ra in dm.jail_pile and ra.jail_time_remaining == 20, "Rapid Recurve: the card is jailed 20 tempo after play")
	dm.jail_pile.erase(ra)
	_clear_gear()

	# Tightened Cross Bow: +5 damage, +1 tempo.
	_fresh()
	var tcb := _equip("tightened_cross_bow")
	# (Not Quick Shot: it adds only half of every modifier by its own rule.)
	var xa := Card.create_by_id("slash")
	xa.is_ranged = true
	var xt: int = xa.get_burden_tempo_cost()
	_place(dummies[0], _pcell() + Vector2i(2, 0))
	_reset_dummy(dummies[0])
	xa.execute(dummies[0], stats, dm, 0.0, 0.0, bm)
	var xd: int = _dmg(dummies[0])
	_slot(xa, tcb)
	_reset_dummy(dummies[0])
	xa.execute(dummies[0], stats, dm, 0.0, 0.0, bm)
	_check(_dmg(dummies[0]) == xd + 5, "Tightened Cross Bow: +5 damage (%d vs %d)" % [_dmg(dummies[0]), xd])
	_check(xa.get_burden_tempo_cost() == xt + 1, "Tightened Cross Bow: +1 tempo")
	_clear_gear()

	# Wrist Rocket: +10% crit, one-handed; "pairs with a quiver".
	_fresh()
	var c0: float = stats.equipment_crit_bonus
	_equip("wrist_rocket")
	_check(is_equal_approx(stats.equipment_crit_bonus - c0, 10.0), "Wrist Rocket: +10% crit chance")
	_check(not Inventory.is_two_hand_only(ItemData.create("wrist_rocket")), "Wrist Rocket is one-handed")
	_check(inv.hand_conflict_reason(ItemData.create("standard_quiver"), 1) != "",
		"Wrist Rocket (FLAG): a quiver is refused beside it (designer 2026-10-25), though its text says it pairs with one")
	_clear_gear()

# ----------------------------------------------------------------- weapons

func _crit_rate(card: Card, n: int) -> int:
	## Crits out of n plays with the wearer's own crit chance zeroed.
	stats.equipment_crit_bonus = -float(stats.base_crit_chance)
	seed(4321)
	var crits := 0
	for _i in range(n):
		_reset_dummy(dummies[0])
		bm.last_crit_hit = false
		card.execute(dummies[0], stats, dm, 0.0, 0.0, bm)
		if bm.last_crit_hit:
			crits += 1
	bm.last_crit_hit = false
	stats.equipment_crit_bonus = -100.0
	return crits

func _test_weapons() -> void:
	print("-- Weapons --")
	# Rusty Dagger: any slotted card +15% crit chance.
	_fresh()
	var rd := _equip("rusty_dagger")
	var none: int = _crit_rate(Card.create_by_id("slash"), 200)
	var with: int = _crit_rate(_slot(Card.create_by_id("slash"), rd), 200)
	_check(none == 0 and with >= 18 and with <= 42, "Rusty Dagger: a slotted card crits ~15%% of the time from 0%% (%d/200, unslotted %d)" % [with, none])
	_clear_gear()

	# Sabre Tooth: 5 Bleed on a hit; the same target twice -> extra tick + 5 Bleed.
	_fresh()
	var st := _equip("sabre_tooth")
	var sc := _slot(Card.create_by_id("slash"), st)
	var c0: int = stats.current_attack_counter
	sc.execute(dummies[0], stats, dm, 0.0, 0.0, bm)
	var c1: int = stats.current_attack_counter
	_check(dummies[0].bleed_stacks == 5, "Sabre Tooth: an offensive hit applies 5 Bleed (%d)" % dummies[0].bleed_stacks)
	sc.execute(dummies[0], stats, dm, 0.0, 0.0, bm)
	var c2: int = stats.current_attack_counter
	_check(dummies[0].bleed_stacks == 15, "Sabre Tooth: striking the same target again rakes 5 more Bleed (%d = 5 + 5 + 5)" % dummies[0].bleed_stacks)
	_check((c1 - c2) - (c0 - c1) == 1, "Sabre Tooth: ...and ticks the attack-speed counter once more (%d, %d, %d)" % [c0, c1, c2])
	_reset_dummy(dummies[1])
	_place(dummies[1], _pcell() + Vector2i(0, 1))
	sc.execute(dummies[1], stats, dm, 0.0, 0.0, bm)
	_check(dummies[1].bleed_stacks == 5, "Sabre Tooth: a new target is not 'the same target' (%d)" % dummies[1].bleed_stacks)
	_clear_gear()

	# Shepherds Crook: all healing +5; targeted cards pull the target 1 square.
	_fresh()
	var hb0: int = stats.healing_bonus
	_equip("shepherds_crook")
	_check(Inventory.is_two_hand_only(ItemData.create("shepherds_crook")), "Shepherds Crook is two-handed")
	_check(stats.healing_bonus - hb0 == 5, "Shepherds Crook: +5 healing bonus")
	# Any heal (PlayerStats.heal: cards, riders, regen alike) carries it.
	stats.current_health = stats.max_health - 100
	var hp: int = stats.current_health
	stats.heal(10)
	var with_crook: int = stats.current_health - hp
	stats.healing_bonus -= 5
	stats.current_health = stats.max_health - 100
	stats.heal(10)
	var without: int = stats.current_health - hp
	stats.healing_bonus += 5
	_check(with_crook == without + 5, "Shepherds Crook: all your healing heals 5 more (%d vs %d)" % [with_crook, without])
	var far: Vector2i = _pcell() + Vector2i(4, 0)
	_place(dummies[1], far)
	_exec(Card.create_by_id("quick_shot"), dummies[1])
	_check(main.grid_manager.world_to_grid(dummies[1].position) == far - Vector2i(1, 0), "Shepherds Crook: a targeted card pulls its target 1 square toward you")
	if main._dojo_allies.size() > 0:
		var ally = main._dojo_allies[0]
		var afar: Vector2i = _pcell() + Vector2i(0, 4)
		ally.blink_to(main.grid_manager.grid_to_world(afar))
		_exec(Card.create_by_id("heal"), ally)
		_check(main.grid_manager.world_to_grid(ally.position) == afar - Vector2i(0, 1), "Shepherds Crook: allies are pulled too")
	else:
		_check(false, "Shepherds Crook: the dojo has an ally dummy to pull")
	_clear_gear()

	# Side Card Sabre: off hand beside a main-hand weapon -> weightless, slotted -1 tempo.
	_fresh()
	_equip("short_sword", 0)
	var w_main: int = inv.get_total_weight()
	var scs := _equip("side_card_sabre", 1)
	_check(scs.pair_active and inv.get_total_weight() == w_main, "Side Card Sabre: weightless beside a main-hand sword (%d vs %d)" % [inv.get_total_weight(), w_main])
	var pc := Card.create_by_id("slash")
	var pt: int = pc.get_burden_tempo_cost()
	_slot(pc, scs)
	_check(pc.get_burden_tempo_cost() == pt - 1, "Side Card Sabre: its slotted cards cost 1 less tempo")
	_clear_gear()
	_fresh()
	_equip("wooden_shield", 0)
	var scs2 := _equip("side_card_sabre", 1)
	_check(not scs2.pair_active, "Side Card Sabre: a shield in the main hand doesn't count")
	_clear_gear()

	# Spartan Spear: with a shield, Reach and +2 melee damage.
	_fresh()
	_equip("spartan_spear", 0)
	var plain: int = _slash_plain()
	_place(dummies[0], _pcell() + Vector2i(2, 0))
	_check(not main._is_target_in_card_range(Card.create_by_id("slash"), dummies[0]), "Spartan Spear: no Reach without a shield")
	_place_dummies()
	_check(stats.equipment_melee_reach == 0 and stats.equipment_shield_melee_damage == 0, "Spartan Spear: nothing without a shield")
	_equip("slotted_rope_half_sleeve", 1)  # a shield with no STR of its own
	_check(stats.equipment_melee_reach == 1, "Spartan Spear: a shield grants Reach")
	_place(dummies[0], _pcell() + Vector2i(2, 0))
	_check(main._is_target_in_card_range(Card.create_by_id("slash"), dummies[0]), "Spartan Spear: Reach — a melee card hits 2 squares away")
	_place_dummies()
	_check(_slash_plain() == plain + 2, "Spartan Spear: ...and +2 melee damage (%d vs %d)" % [_slash_plain(), plain])
	_clear_gear()

	# Sword of Theseus: 2 Slow on a hit; +1 damage per Slow already there; 5% lifesteal.
	_fresh()
	var ls0: float = stats.equipment_lifesteal_bonus
	var sot := _equip("sword_of_theseus")
	plain = _slash_plain()
	_check(is_equal_approx(stats.equipment_lifesteal_bonus - ls0, 5.0), "Sword of Theseus: 5% lifesteal")
	var tc := _slot(Card.create_by_id("slash"), sot)
	tc.execute(dummies[0], stats, dm, 0.0, 0.0, bm)
	_check(dummies[0].slow_stacks == 2 and _dmg(dummies[0]) == plain, "Sword of Theseus: a hit applies 2 Slow (%d)" % dummies[0].slow_stacks)
	var first: int = _dmg(dummies[0])
	tc.execute(dummies[0], stats, dm, 0.0, 0.0, bm)
	_check(_dmg(dummies[0]) - first == plain + 2, "Sword of Theseus: +1 damage per Slow on the target (%d vs %d)" % [_dmg(dummies[0]) - first, plain])
	_clear_gear()
	var sot3 := ItemData.create("sword_of_theseus")
	sot3.level_up()
	sot3.level_up()
	_check(sot3.on_self_apply_slow == 3 and is_equal_approx(sot3.lifesteal_percent, 8.0) and sot3.strength_bonus == 9 and sot3.determination_bonus == 8,
		"Sword of Theseus Lv.3: 3 Slow, 8% lifesteal, +9 STR, +8 DET")

	# Umbral Eclipse: gaining armor hits an enemy in melee for 5; Insight restores 2 flash.
	_fresh()
	_equip("umbral_eclipse")
	stats.add_armor(4)
	_check(_dmg(dummies[0]) == 5 and _dmg(dummies[1]) == 0, "Umbral Eclipse: gaining armor deals 5 to the enemy in melee range (%d)" % _dmg(dummies[0]))
	_reset_dummy(dummies[0])
	_place(dummies[0], _pcell() + Vector2i(3, 0))
	stats.add_armor(4)
	_check(_dmg(dummies[0]) == 0, "Umbral Eclipse: nothing when no enemy is in melee range")
	_place_dummies()
	stats.current_brain_points = 50
	stats.current_flash_points = 0
	dm.hand.clear()
	if dm.draw_pile.is_empty():
		dm.draw_pile.append(Card.create_by_id("slash"))
	main._on_brain_draw_pressed()
	_check(stats.current_flash_points == 2, "Umbral Eclipse: an Insight draw restores 2 flash points (%d)" % stats.current_flash_points)
	_clear_gear()
	var ue3 := ItemData.create("umbral_eclipse")
	ue3.level_up()
	ue3.level_up()
	_check(ue3.armor_gain_melee_damage == 8 and ue3.insight_flash_restore == 3 and ue3.wisdom_bonus == 9
		and ue3.agility_bonus == 9 and ue3.strength_bonus == 4 and ue3.mana_bonus == 16,
		"Umbral Eclipse Lv.3: 8 damage, 3 flash, +9 WIS, +9 AGI, +4 STR, +16 mana")

	# Wooden Spear: 1 Bleed on a hit.
	_fresh()
	var ws := _equip("wooden_spear")
	_exec(_slot(Card.create_by_id("slash"), ws), dummies[0])
	_check(dummies[0].bleed_stacks == 1, "Wooden Spear: an offensive hit applies 1 Bleed")
	_clear_gear()

	# Wooden Sword: +1 damage on a damaging slotted card.
	_fresh()
	plain = _slash_plain()
	var wsw := _equip("wooden_sword")
	_exec(_slot(Card.create_by_id("slash"), wsw), dummies[0])
	_check(_dmg(dummies[0]) == plain + 1, "Wooden Sword: +1 damage (%d vs %d)" % [_dmg(dummies[0]), plain])
	_check(wsw.card_slots + wsw.vanilla_slots == 1, "Wooden Sword: 1 card slot")
	_clear_gear()

# ----------------------------------------------------------------- shields

func _test_shields() -> void:
	print("-- Shields (main hand) --")
	# Slotted Rope Half Sleeve.
	_fresh()
	var fl0: int = stats.get_max_flash_points()
	var rope := _equip("slotted_rope_half_sleeve")
	_check(stats.get_max_flash_points() == fl0 + 4 + 4, "Rope Sleeve: +4 flash points (on top of its +4 AGI) (%d -> %d)" % [fl0, stats.get_max_flash_points()])
	stats.current_armor = 0
	Card.create_by_id("parry").execute(dummies[0], stats, dm, 0.0, 0.0, bm)
	_check(stats.current_armor == 2, "Rope Sleeve: -3 block from your block cards (Parry 5 -> %d)" % stats.current_armor)
	stats.current_armor = 0
	dm.hand.clear()
	var victim := Card.create_by_id("quick_shot")
	dm.hand.append(victim)
	_exec(_slot(Card.create_by_id("slash"), rope), dummies[0])
	# FLAG: the rider's +3 armor is the card's first armor grant, so the
	# sleeve's own -3 (PlayerStats.add_armor's defense-card channel, "any type"
	# since the Thick Steel ruling) eats it whole.
	_check(stats.current_armor == 0, "Rope Sleeve (FLAG): a slotted card that blocks nothing nets 3 - 3 = 0 armor, not +3 (%d)" % stats.current_armor)
	_check(not (victim in dm.hand) and victim in dm.discard_pile, "Rope Sleeve: any slotted card discards a card")
	stats.current_armor = 0
	_exec(_slot(Card.create_by_id("block"), rope), main.player)
	_check(stats.current_armor == 8, "Rope Sleeve: a slotted block card gets +3 block (Block 8 - 3 + 3 = %d)" % stats.current_armor)
	main.overflow_manager.manifest_zone.clear()
	for _o in range(6):
		main._on_overdraw_processed(null)
	var blades := 0
	for m in main.overflow_manager.manifest_zone:
		if str(m.get("manifest_id", "")) == "cinquedea":
			blades += 1
	_check(blades == 5, "Rope Sleeve: Overdraw drops a Cinquedea into the manifest zone, up to 5 (%d)" % blades)
	stats.current_armor = 0
	Card.create_by_id("block").execute(main.player, stats, dm, 0.0, 0.0, bm)
	_check(stats.current_armor == 10, "Rope Sleeve: each waiting Cinquedea gives block cards +1 (Block 8 - 3 + 5 = %d)" % stats.current_armor)
	# Spend one: its point goes with it (and it strikes 6 + 1 Weaken within 4).
	_reset_dummy(dummies[0])
	stats.current_mana = stats.max_mana
	var cq_idx := -1
	for i in range(main.overflow_manager.manifest_zone.size()):
		if str(main.overflow_manager.manifest_zone[i].get("manifest_id", "")) == "cinquedea":
			cq_idx = i
	main._on_manifest_card_clicked(cq_idx)
	_check(_dmg(dummies[0]) == 6 and dummies[0].weaken_stacks == 1, "Rope Sleeve: a Cinquedea deals 6 and 1 Weaken (%d)" % _dmg(dummies[0]))
	stats.current_armor = 0
	Card.create_by_id("block").execute(main.player, stats, dm, 0.0, 0.0, bm)
	_check(stats.current_armor == 9, "Rope Sleeve: spending a Cinquedea takes its point with it (%d)" % stats.current_armor)
	main.overflow_manager.manifest_zone.clear()
	_clear_gear()
	_check(stats.equipment_defense_card_block == 0, "Rope Sleeve: unequipping gives every point back (%d)" % stats.equipment_defense_card_block)

	# Spiked Shield: 1 Thorns every cycle.
	_fresh()
	_equip("spiked_shield")
	main._shield_on_cycle_passives()
	_check(_thorns() == 1, "Spiked Shield: 1 Thorns every cycle (%d)" % _thorns())
	_clear_gear()

	# Steve Rodgers Bastion: every enemy hit gives 5 mana (Lv.2: 7).
	_fresh()
	_equip("steve_rodgers_bastion")
	stats.current_mana = 0
	dummies[0]._deal_damage_to_player(main.player, 1, "Attack")
	_check(int(stats.current_mana) == 5, "Bastion: an enemy hit gives you 5 mana (%d)" % int(stats.current_mana))
	_clear_gear()
	_fresh()
	var b2 := ItemData.create("steve_rodgers_bastion")
	b2.level_up()
	_check(b2.item_level == 2 and b2.damage_taken_mana_gain == 7 and b2.strength_bonus == 6 and b2.determination_bonus == 5 and b2.mana_bonus == 30,
		"Bastion Lv.2: 7 mana per hit, +6 STR, +5 DET, +30 mana")
	inv.equip_item(b2, 0)
	stats.current_mana = 0
	dummies[0]._deal_damage_to_player(main.player, 1, "Attack")
	_check(int(stats.current_mana) == 7, "Bastion Lv.2: 7 mana per hit (%d)" % int(stats.current_mana))
	_clear_gear()

	# Sword Breaker: any card +4 armor and Fortify 5; a swallowed melee hit taxes 2 tempo.
	_fresh()
	var sbk := _equip("sword_breaker")
	stats.current_armor = 0
	_exec(_slot(Card.create_by_id("slash"), sbk), dummies[0])
	var fort = bm.get_buff(Buff.BuffType.FORTIFY)
	_check(stats.current_armor == 4 and fort != null and fort.duration == 5, "Sword Breaker: any slotted card gains 4 armor and Fortify for 5 tempo")
	stats.current_armor = 50
	dummies[0].next_melee_tempo_tax = 0
	dummies[0]._deal_damage_to_player(main.player, 5, "Attack")
	_check(dummies[0].next_melee_tempo_tax == 2, "Sword Breaker: melee damage the armor swallows whole costs that enemy 2 tempo (%d)" % dummies[0].next_melee_tempo_tax)
	var swing := {"name": "attack", "tempo_cost": 3}
	var taxed: int = dummies[0]._effective_cost(swing)
	dummies[0].next_melee_tempo_tax = 0
	_check(taxed == dummies[0]._effective_cost(swing) + 2, "Sword Breaker: ...on its next melee attack's wind-up")
	dummies[0].current_health = 1000
	stats.current_armor = 0
	dummies[0]._deal_damage_to_player(main.player, 5, "Attack")
	_check(dummies[0].next_melee_tempo_tax == 0, "Sword Breaker: a hit that gets through taxes nothing")
	dummies[0].next_melee_tempo_tax = 0
	_clear_gear()

	# Treebeards Branch: any card 3 Thorns; Overdraw 3 Regen.
	_fresh()
	var tbr := _equip("treebeards_branch")
	_exec(_slot(Card.create_by_id("slash"), tbr), dummies[0])
	_check(_thorns() == 3, "Treebeards Branch: any slotted card gains you 3 Thorns (%d)" % _thorns())
	main._on_overdraw_processed(null)
	_check(_regen() == 3, "Treebeards Branch: Overdraw grants 3 Regen (%d)" % _regen())
	_clear_gear()

	# Vanguard: hits 3 lighter; 1 Regen every cycle.
	_fresh()
	_equip("vanguard")
	var hp: int = stats.current_health
	stats.take_damage(10)
	_check(hp - stats.current_health == 7, "Vanguard: a hit is 3 damage lighter (10 -> %d)" % (hp - stats.current_health))
	main._shield_on_cycle_passives()
	_check(_regen() == 1, "Vanguard: 1 Regen every cycle")
	_clear_gear()

	# Vengeful Shield: shove the enemy target back 1; no target -> every adjacent enemy.
	_fresh()
	var vsh := _equip("vengeful_shield")
	var a0: Vector2i = main.grid_manager.world_to_grid(dummies[0].position)
	_exec(_slot(Card.create_by_id("slash"), vsh), dummies[0])
	_check(main.grid_manager.world_to_grid(dummies[0].position) == a0 + Vector2i(1, 0), "Vengeful Shield: the enemy target is shoved back 1")
	_place_dummies()
	_place(dummies[1], _pcell() + Vector2i(-1, 0))
	_exec(_slot(Card.create_by_id("parry"), vsh), main.player)
	_check(main.grid_manager.world_to_grid(dummies[0].position) == _pcell() + Vector2i(2, 0)
		and main.grid_manager.world_to_grid(dummies[1].position) == _pcell() + Vector2i(-2, 0),
		"Vengeful Shield: a card with no enemy target shoves every adjacent enemy")
	_clear_gear()

	# Wooden Shield: a melee striker takes 1 Bleed.
	_fresh()
	_equip("wooden_shield")
	dummies[0]._deal_damage_to_player(main.player, 1, "Attack")
	_check(dummies[0].bleed_stacks == 1, "Wooden Shield: an enemy that strikes you in melee takes 1 Bleed")
	_place(dummies[1], _pcell() + Vector2i(4, 0))
	dummies[1]._deal_damage_to_player(main.player, 1, "Attack")
	_check(dummies[1].bleed_stacks == 0, "Wooden Shield: a ranged striker does not")
	_clear_gear()

# ------------------------------------------------------------------- wands

func _test_wands() -> void:
	print("-- Wands --")
	# Wand of Clarity: no debuffs -> all cards 15% less mana; slotted +2 brain +2 flash.
	_fresh()
	var fbc := Card.create_by_id("fireball")
	dm.hand.clear()
	dm.hand.append(fbc)
	var full: int = int(dm.compute_play_cost(fbc, 0, dummies[0])["mana"])
	var wc := _equip("wand_of_clarity")
	_check(int(dm.compute_play_cost(fbc, 0, dummies[0])["mana"]) == floori(full * 0.85), "Wand of Clarity: no debuffs -> ALL cards 15% less mana")
	dbm.apply_debuff(Debuff.create(Debuff.DebuffType.BURN, 1, 15))
	_check(int(dm.compute_play_cost(fbc, 0, dummies[0])["mana"]) == full, "Wand of Clarity: a debuff takes the discount away")
	dbm.clear_all_debuffs()
	dm.hand.clear()
	stats.current_brain_points = 0
	stats.current_flash_points = 0
	_exec(_slot(Card.create_by_id("slash"), wc), dummies[0])
	_check(stats.current_brain_points == 2 and stats.current_flash_points == 2, "Wand of Clarity: a slotted card regains 2 brain and 2 flash")
	_clear_gear()

	# Wand of Deliverance: +2 range on all cards; damaging offensive +2.
	_fresh()
	var plain: int = _slash_plain()
	_equip("wand_of_deliverance")
	_check(main._helm_range_bonus(Card.create_by_id("heal")) == 2 and main._helm_range_bonus(Card.create_by_id("fireball")) == 2,
		"Wand of Deliverance: all your cards gain +2 range")
	_check(_slash_plain() == plain + 2, "Wand of Deliverance: damaging offensive cards deal +2")
	_clear_gear()

	# Wand of the Phoenix Feather: applying Burn burns you 1, once per play.
	_fresh()
	var ph := _equip("wand_of_the_phoenix_feather")
	main._phoenix_singed_this_play = false
	dummies[0].apply_debuff("burn", 3)
	dummies[0].apply_debuff("burn", 3)
	var my_burn = dbm.get_debuff(Debuff.DebuffType.BURN)
	_check(my_burn != null and my_burn.value == 1, "Phoenix Feather: applying Burn burns you 1 — once per play (%s)" % (str(my_burn.value) if my_burn else "none"))
	main._phoenix_singed_this_play = false
	dbm.clear_all_debuffs()
	# From the Ashes: purge 4 Burn -> 20 to enemies within 3, heal 20, Regen 2.
	dbm.apply_debuff(Debuff.create(Debuff.DebuffType.BURN, 4, 15))
	stats.current_health = stats.max_health - 100
	var hp: int = stats.current_health
	var fta: Card = null
	for c in ph.granted_card_instances:
		if c.card_id == "from_the_ashes":
			fta = c
	_reset_dummy(dummies[0])
	_reset_dummy(dummies[1])
	_exec(fta, main.player)
	_check(dbm.get_debuff(Debuff.DebuffType.BURN) == null, "From the Ashes: all your Burn is purged")
	_check(_dmg(dummies[0]) == 20 and _dmg(dummies[1]) == 0, "From the Ashes: enemies within 3 take 5 per stack (%d / %d)" % [_dmg(dummies[0]), _dmg(dummies[1])])
	_check(stats.current_health - hp >= 20, "From the Ashes: heal 5 per stack (%d)" % (stats.current_health - hp))
	_check(_regen() == 2, "From the Ashes: Regen equal to half of it (%d)" % _regen())
	_clear_gear()
	var ph3 := ItemData.create("wand_of_the_phoenix_feather")
	ph3.level_up()
	ph3.level_up()
	_check(ph3.health_bonus == 45 and ph3.wisdom_bonus == 5, "Phoenix Feather Lv.3: +45 health, +5 WIS")
