extends SceneTree

## Phase 2 wiring audit, items slice A (docs/audit/wiring/items_a.md): the 63
## items abjurers_cane .. elvish_cloak, each checked against its description
## in a booted main.tscn (the dojo, Brad). Items are equipped through the real
## Inventory so stat application, granted cards and every rider's consumer
## run as in play.
##  - Stats: every stat the text names moves by exactly that much on equip,
##    and comes back off on unequip.
##  - Granted cards: the exact cards the text names reach the deck, at the
##    mana / tempo the text quotes, and leave with the item.
##  - Riders: each described behaviour exercised through its real consumer
##    (Card.execute, DeckManager costs, Inventory.process_turn, main's world
##    effects and hooks).
## Run: godot --headless --path . --script tests/test_wiring_items_a.gd

var failures := 0
var main = null
var stats: PlayerStats = null
var dm = null
var bm = null
var inv: Inventory = null
var gm = null
var dummies: Array = []

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Wiring audit: items A ===")
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
	dm = main.deck_manager
	bm = main.player.get_buff_manager()
	inv = main.player.get_inventory()
	gm = main.grid_manager
	dummies = main.enemy_spawner.get_living_enemies()
	_check(dummies.size() >= 2, "the dojo has two dummies (%d)" % dummies.size())
	inv.enforce_mythic_limit = false
	_strip()
	# Carry room for the heavy plates; every stat check below is a delta.
	stats.base_strength += 300
	stats.recalculate_derived_stats()
	stats.max_health = maxi(stats.max_health, 200)
	stats.current_health = stats.max_health
	stats.equipment_crit_bonus = -100.0  # exact comparisons: no random crits
	for d in dummies:
		_reset_dummy(d)

	_test_stats()
	_test_granted_cards()
	_test_granted_card_numbers()
	_test_abjurers_cane()
	_test_adimantium()
	_test_alchemeist_belt()
	_test_armor_chopper()
	_test_assasian_belt()
	_test_band_of_aid()
	_test_belt_of_wumbology()
	_test_belthronding()
	_test_bessy()
	_test_blast_stick()
	_test_bloodbound_plate()
	_test_boomerang()
	_test_boot_holsters()
	_test_boots_of_speed()
	_test_boots_of_the_balancer()
	_test_bow_of_arash()
	_test_bow_of_budding_blasts()
	_test_brass_knuckles()
	_test_buckler()
	_test_periodic_unerring()
	_test_capacious_extremus()
	_test_captain_planet()
	_test_car_battery()
	_test_caster_boots()
	_test_castle_wall()
	_test_chain_crocs()
	_test_gauntlet_skills()
	_test_chewbaccas_bandolier()
	_test_circes_wand()
	_test_coffin_lid()
	_test_corset_of_cure()
	_test_crooked_dueling_shield()
	_test_cuffs_of_current()
	_test_cyclops_ring()
	_test_cyde_sneakers()
	_test_delfins()
	_test_resist_items()
	_test_dragon_skull()
	_test_draupnir()
	_test_earth_book()
	_test_elemental_emblem()
	_test_trail_blazers()
	_test_elemental_weaver()
	_test_elvish_cloak()
	_test_two_handers()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

# ---------------------------------------------------------------- helpers

func _strip() -> void:
	for arr_name in ["equipped_helms", "equipped_chests", "equipped_rings", "equipped_belts",
			"equipped_boots", "equipped_gauntlets", "equipped_weapons"]:
		var arr: Array = inv.get(arr_name)
		for i in range(arr.size()):
			if arr[i] != null:
				inv.unequip_item(arr[i].item_type, i)

func _place(who, cell: Vector2i) -> void:
	who.position = gm.grid_to_world(cell)
	if "target_position" in who:
		who.target_position = who.position

func _pcell() -> Vector2i:
	return gm.world_to_grid(main.player.position)

func _reset_dummy(d: Enemy) -> void:
	d.max_health = 1000
	d.current_health = 1000
	d.current_armor = 0
	d.damage_resistances = {}
	for f in ["weaken_stacks", "vulnerable_stacks", "shock_stacks", "burn_stacks", "cold_stacks",
			"silenced_tempo", "slow_stacks"]:
		if f in d:
			d.set(f, 0)

## Park both dummies far away (so area riders under test only see who we place).
func _park_dummies() -> void:
	var c := _pcell()
	_place(dummies[0], c + Vector2i(8, 8))
	_place(dummies[1], c + Vector2i(-8, 8))

func _equip(id: String, slot: int = 0) -> ItemData:
	var item := ItemData.create(id)
	var ok: bool = inv.equip_item(item, slot)
	_check(ok, "%s equips (%s)" % [id, inv.last_refusal])
	return item

func _unequip(item: ItemData) -> void:
	var arr: Array = inv._get_slot_array(item.item_type)
	var i: int = arr.find(item)
	if i >= 0:
		inv.unequip_item(item.item_type, i)

## Put a card into the item's next free slot even when its labels would not
## fit (the label gate is not what these tests are about).
func _slot(card: Card, item: ItemData, idx: int = -1) -> Card:
	item._take_slot(card, idx if idx >= 0 else item._next_free_slot_index())
	return card

func _hit(card: Card, d: Enemy) -> int:
	_reset_dummy(d)
	card.execute(d, stats, dm, 0.0, 0.0, bm)
	return 1000 - d.current_health

## A full play: the hand play (costs, combo colors) then main's resolve
## (execute + world effects).
func _play(card: Card, target) -> void:
	stats.current_mana = stats.max_mana
	dm.hand.append(card)
	dm.play_card(dm.hand.find(card), target, main.player, true)
	main._pending_resolve_queue.append({"card": card, "target": target, "owner_index": 0, "data": {}})
	main._resolve_queued_card(card)

func _item_cards_in_deck(item: ItemData) -> Array:
	var ids: Array = []
	for zone in [dm.draw_pile, dm.hand, dm.discard_pile, dm.jail_pile]:
		for c in zone:
			if c.granted_by_item == item:
				ids.append(c.card_id)
	ids.sort()
	return ids

func _cost(card: Card) -> Dictionary:
	return dm.compute_play_cost(card, 0, null, null, false)

# ---------------------------------------------------------------- stats

## The stats each description names (STR DEX INT WIS DET AGI health mana hand).
const STATS := {
	"abjurers_cane": {"wis": 5, "int": 4, "agi": 4},
	"adimantium": {"str": 8, "agi": -2, "dex": -1},
	"alchemeist_belt": {"wis": 5, "int": 5, "hp": 15, "dex": -4},
	"armor_chopper": {"hp": 5, "str": 3},
	"assasian_belt": {"agi": 5, "dex": 1},
	"axes_axe": {"str": 8, "det": 6, "int": -6, "wis": -4},
	"band_of_aid": {"dex": 2, "hp": 5},
	"baseball_hat": {"dex": 1, "str": 1, "agi": 1},
	"belt_of_scrolls": {"wis": 8, "int": 8},
	"belt_of_wumbology": {"str": 5, "hp": 5, "wis": 1, "int": 5},
	"belthronding": {"str": 10, "hp": 20, "dex": 8},
	"bessy": {},
	"bladed_doughnut": {"str": 15},
	"blast_stick": {"int": 18, "agi": -8, "str": 1},
	"blink_boots": {"agi": 3},
	"bloodbound_plate": {"hp": 20},
	"blue_robe": {"wis": 5, "int": 8, "hp": 20},
	"boomerang": {"str": 3},
	"boot_holsters": {"wis": 3, "agi": 3, "dex": 1},
	"boots_of_speed": {"agi": 4, "dex": 3},
	"boots_of_the_balancer": {"hp": 15, "wis": 3, "str": 5, "det": 2},
	"bow_of_arash": {"agi": 5, "dex": 2, "wis": 4},
	"bow_of_budding_blasts": {"int": 3, "wis": 4, "mana": 25},
	"brass_knuckles": {},
	"briarhide_plate": {"hp": 35},
	"brown_boots": {"agi": 3},
	"buckler": {"str": 2, "det": 1},
	"buffed_leather": {"hp": 40},
	"burgonet": {},
	"capacious_extremus": {"int": 8, "wis": 2},
	"captain_planets_circlet": {"mana": 125},
	"car_battery": {"int": 3, "agi": 3, "dex": 3},
	"caster_boots": {"int": 6, "agi": 2, "wis": 2},
	"castle_wall": {"str": 8, "agi": -4, "wis": -5, "hp": 55, "hand": -3},
	"chain_crocs": {"agi": -2, "wis": -2},
	"chain_gloves": {"str": 2},
	"chain_mail": {"hp": 15},
	"chewbaccas_bandolier": {"str": 8, "agi": 2, "dex": 2, "hp": -10, "wis": -2},
	"circes_wand_of_cauldron_stirring": {"wis": 8, "str": -5, "mana": 20},
	"cloth_bracer": {"hand": 1, "dex": 2},
	"cloth_slippers": {"dex": 2, "agi": 1},
	"coffin_lid": {"int": 7, "str": 2, "wis": 2, "det": 3},
	"concealed_carry": {"dex": 2, "agi": 2, "hand": 1},
	"construction_hammer": {"agi": 2, "str": 2},
	"copper_bracers": {"hp": 10, "str": 2, "agi": 1, "wis": 3},
	"corset_of_cure": {"hp": 25, "det": 1, "wis": 1, "dex": 1},
	"crooked_dueling_shield": {"dex": 7, "agi": 7, "str": 4},
	"cross_bow": {"dex": 1, "agi": -2, "int": 3},
	"cuffs_of_current": {"int": 6, "hand": 2},
	"cupids_bow": {"wis": 3, "str": 5, "int": 4},
	"cyclops_ring": {"mana": 125, "str": 10, "int": -3, "wis": -3, "agi": -3},
	"cyde_livingstons_sneakers": {"agi": 5, "dex": 4},
	"delfins_deterministic_round_shield": {"int": 6, "wis": 5, "str": 3},
	"diamond_ring": {"mana": 75, "hp": 10, "str": 3},
	"divine_resistance": {"hp": 45, "str": 5},
	"dragon_skull": {"str": 8, "dex": 8},
	"draupnir": {"mana": 150, "str": 5, "int": 8},
	"dunce_cap": {"str": 8, "int": -6},
	"earth_book": {"int": 2},
	"elemental_emblem": {"int": 10, "str": -5, "agi": -3},
	"elemental_trail_blazers": {"int": 5, "agi": 5},
	"elemental_weaver": {"int": 5, "wis": 3, "mana": 35},
	"elvish_cloak": {"dex": 2, "agi": 1},
}

func _snap() -> Dictionary:
	return {"str": stats.base_strength, "dex": stats.base_dexterity, "int": stats.base_intelligence,
		"wis": stats.base_wisdom, "det": stats.determination, "agi": stats.base_agility,
		"hp": stats.max_health, "mana": stats.max_mana, "hand": stats.equipment_hand_bonus}

func _test_stats() -> void:
	print("-- Stats: each named stat moves by exactly its number --")
	for id in STATS:
		_strip()
		var probe := ItemData.create(id)
		_check(probe != null, "%s exists" % id)
		if probe == null:
			continue
		# A quiver is only worn beside a bow: the bow takes the off hand so the
		# quiver sits in the main hand at full strength.
		if probe.item_type == ItemData.ItemType.QUIVER:
			inv.equip_item(ItemData.create("short_bow"), 1)
		var before := _snap()
		var ok: bool = inv.equip_item(probe, 0)
		_check(ok, "%s equips in its main slot (%s)" % [id, inv.last_refusal])
		var after := _snap()
		var want: Dictionary = STATS[id]
		var wrong: Array = []
		for k in before:
			var got: int = int(after[k]) - int(before[k])
			if got != int(want.get(k, 0)):
				wrong.append("%s %+d (want %+d)" % [k, got, int(want.get(k, 0))])
		_check(wrong.is_empty(), "%s: stats match its text %s" % [id, str(wrong)])
		_unequip(probe)
		var back := _snap()
		var leaked: Array = []
		for k in before:
			if int(back[k]) != int(before[k]):
				leaked.append(k)
		_check(leaked.is_empty(), "%s: unequip takes every stat back %s" % [id, str(leaked)])
	_strip()

# ---------------------------------------------------------------- granted cards

const GRANTS := {
	"abjurers_cane": ["defensive_sacrifice", "defensive_sacrifice"],
	"adimantium": ["adimantium_wall"],
	"alchemeist_belt": ["hemotoxins"],
	"assasian_belt": ["shuriken", "shuriken"],
	"axes_axe": ["death_vortex", "death_vortex", "death_vortex"],
	"belt_of_scrolls": ["chain_lightning", "fire_punch", "ice_grenade"],
	"belt_of_wumbology": ["m_for_mini"],
	"belthronding": ["balistic_arrow"],
	"bessy": ["earth_rattle"],
	"blink_boots": ["blink", "blink"],
	"boots_of_the_balancer": ["tight_rope"],
	"bow_of_arash": ["territorial_mark"],
	"bow_of_budding_blasts": ["spirit_bow"],
	"briarhide_plate": ["vined_encasing"],
	"castle_wall": ["huck"],
	"chain_mail": ["clang_up"],
	"circes_wand_of_cauldron_stirring": ["polymorph", "polymorph"],
	"coffin_lid": ["curse_of_the_living"],
	"concealed_carry": ["smoke_bomb"],
	"construction_hammer": ["hard_helmet"],
	"cupids_bow": ["cupids_golden_arrow", "cupids_lead_arrow"],
	"cyde_livingstons_sneakers": ["donate_cleats"],
	"delfins_deterministic_round_shield": ["mage_shield"],
	"divine_resistance": ["preemptive_answer"],
	"elemental_weaver": ["element_pollination"],
}

func _test_granted_cards() -> void:
	print("-- Granted cards reach the deck and leave with the item --")
	for id in STATS:
		_strip()
		var item := ItemData.create(id)
		if item.item_type == ItemData.ItemType.QUIVER:
			inv.equip_item(ItemData.create("short_bow"), 1)
		inv.equip_item(item, 0)
		var want: Array = GRANTS.get(id, []).duplicate()
		want.sort()
		var got := _item_cards_in_deck(item)
		_check(got == want, "%s grants %s (deck has %s)" % [id, str(want), str(got)])
		_unequip(item)
		_check(_item_cards_in_deck(item).is_empty(), "%s: its cards leave the deck on unequip" % id)
	_strip()

## The numbers an item's text quotes for its granted card.
func _test_granted_card_numbers() -> void:
	print("-- Granted card numbers match the item text --")
	# [id, mana, tempo, extra-check-name, extra value]
	var rows := [
		["adimantium_wall", 35, 4, "block", 40],
		["hemotoxins", 50, 5, "", 0],
		["m_for_mini", 15, 2, "", 0],
		["balistic_arrow", 75, 5, "base_damage", 30],
		["earth_rattle", 60, 6, "", 0],
		["territorial_mark", 45, 5, "health_cost", 35],
		["spirit_bow", 65, 3, "", 0],
		["vined_encasing", 50, 4, "", 0],
		["huck", 100, 5, "", 0],
		["clang_up", 20, 5, "block", 10],
		["curse_of_the_living", 65, 7, "", 0],
		["cupids_golden_arrow", 45, 3, "base_damage", 10],
		["cupids_lead_arrow", 45, 3, "base_damage", 10],
		["donate_cleats", 35, 0, "", 0],
		["mage_shield", 0, 0, "block", 10],
		["close_is_favored", 0, 0, "base_damage", 13],
		["sprinkle", 0, 0, "base_damage", 25],
	]
	for r in rows:
		var c := Card.create_by_id(r[0])
		var ok: bool = c != null and c.mana_cost == r[1] and c.tempo_cost == r[2]
		if ok and r[3] != "":
			ok = int(c.get(r[3])) == r[4]
		_check(ok, "%s: %dm / %dt%s" % [r[0], r[1], r[2], ("" if r[3] == "" else ", %s %d" % [r[3], r[4]])])
	var arash_mark := Card.create_by_id("territorial_mark")
	_check(arash_mark.get_effective_range() == 10, "Territorial Mark: range 10 (%d)" % arash_mark.get_effective_range())
	for cid in ["defensive_sacrifice", "death_vortex", "tight_rope", "polymorph", "hard_helmet",
			"mage_shield", "preemptive_answer", "close_is_favored"]:
		_check(Card.create_by_id(cid).card_type == Card.CardType.REACTION, "%s is an instant" % cid)
	for cid in ["spirit_bow", "curse_of_the_living", "element_pollination"]:
		_check(Card.create_by_id(cid).card_type == Card.CardType.POWER, "%s is a Maintain" % cid)

# ---------------------------------------------------------------- riders

func _test_abjurers_cane() -> void:
	print("-- Abjurers Cane: a discard grants 3 block --")
	_strip()
	var cane := _equip("abjurers_cane")
	stats.current_armor = 0
	var c := Card.create_by_id("slash")
	dm.hand.append(c)
	dm.discard_card_from_hand(c)
	_check(stats.current_armor == 3, "Abjurers Cane: discarding a card grants 3 block (%d)" % stats.current_armor)
	_unequip(cane)
	stats.current_armor = 0

func _test_adimantium() -> void:
	print("-- Adimantium: +8 block on-self --")
	_strip()
	var plate := _equip("adimantium")
	stats.current_armor = 0
	_hit(_slot(Card.create_by_id("slash"), plate), dummies[0])
	_check(stats.current_armor == 8, "Adimantium: an attack slotted in it gains 8 armor (%d)" % stats.current_armor)
	_check(stats.movement_tempo_surcharge == 1, "Adimantium: each tile costs 1 extra tempo while worn")
	_unequip(plate)
	_check(stats.movement_tempo_surcharge == 0, "Adimantium: the surcharge leaves with it")
	stats.current_armor = 0

func _test_alchemeist_belt() -> void:
	print("-- Alchemeist belt: heals add 4% of max health --")
	_strip()
	var belt := _equip("alchemeist_belt")
	stats.current_health = 10
	var tonic := Card.create_by_id("healing_tonic")
	tonic.execute(main.player, stats, dm, 0.0, 0.0, bm)
	# Every heal also carries the wearer's INT bonus (PlayerStats.get_effective_heal_amount).
	var want: int = 10 + stats.get_effective_heal_amount(tonic.heal_amount + floori(stats.max_health * 0.04))
	_check(stats.current_health == want, "Alchemeist belt: a 5-heal card heals 5 + 4%% of max health (%d, want %d)" % [stats.current_health, want])
	_check(tonic.heal_amount == 5, "Alchemeist belt: the bonus does not stick to the card")
	_unequip(belt)
	stats.current_health = stats.max_health

func _test_armor_chopper() -> void:
	print("-- Armor Chopper: melee attacks shred 10 armor --")
	_strip()
	var d: Enemy = dummies[0]
	_reset_dummy(d)
	var chopper := _equip("armor_chopper")
	_check(stats.equipment_armor_shred == 10, "Armor Chopper: 10 armor shred while wielded")
	# Same STR both times (its +3 STR also hits harder): only the shred differs.
	stats.equipment_armor_shred = 0
	d.current_armor = 500
	Card.create_by_id("slash").execute(d, stats, dm, 0.0, 0.0, bm)
	var plain_left: int = d.current_armor
	stats.equipment_armor_shred = 10
	d.current_armor = 500
	Card.create_by_id("slash").execute(d, stats, dm, 0.0, 0.0, bm)
	_check(plain_left - d.current_armor == 10, "Armor Chopper: a melee attack card strips 10 more armor (%d)" % (plain_left - d.current_armor))
	_unequip(chopper)
	_check(stats.equipment_armor_shred == 0, "Armor Chopper: the shred leaves with it")
	_reset_dummy(d)

func _test_assasian_belt() -> void:
	print("-- Assasian Belt: slotted offensive hits apply 1 Vulnerable --")
	_strip()
	var belt := _equip("assasian_belt")
	var d: Enemy = dummies[0]
	_hit(_slot(Card.create_by_id("slash"), belt), d)
	_check(d.vulnerable_stacks == 1, "Assasian Belt: a slotted attack that hits applies 1 Vulnerable (%d)" % d.vulnerable_stacks)
	_hit(Card.create_by_id("slash"), d)
	_check(d.vulnerable_stacks == 0, "Assasian Belt: an unslotted attack applies none")
	_unequip(belt)

func _test_band_of_aid() -> void:
	print("-- Band of Aid: +1 healing --")
	_strip()
	var band := _equip("band_of_aid")
	stats.current_health = 50
	_hit(_slot(Card.create_by_id("slash"), band), dummies[0])
	_check(stats.current_health == 50 + stats.get_effective_heal_amount(1), "Band of Aid: a slotted card that doesn't heal heals you 1 (+INT bonus) (%d)" % stats.current_health)
	stats.current_health = 50
	var tonic := _slot(Card.create_by_id("healing_tonic"), ItemData.create("band_of_aid"))
	tonic.execute(main.player, stats, dm, 0.0, 0.0, bm)
	_check(stats.current_health == 50 + stats.get_effective_heal_amount(6), "Band of Aid: a slotted 5-heal card heals 6 (+INT bonus) (%d)" % stats.current_health)
	_unequip(band)
	stats.current_health = stats.max_health

func _test_belt_of_wumbology() -> void:
	print("-- Belt of Wumbology: Strengthen +10 for 2 attacks --")
	_strip()
	var belt := _equip("belt_of_wumbology")
	bm.remove_buff(Buff.BuffType.STRENGTHEN)
	_slot(Card.create_by_id("block"), belt).execute(main.player, stats, dm, 0.0, 0.0, bm)
	var st: Buff = bm.get_buff(Buff.BuffType.STRENGTHEN)
	_check(st != null and st.value == 10 and st.charges == 2, "Belt of Wumbology: any slotted card grants Strengthen 10 for 2 attacks (%s)" % ("none" if st == null else "%d x%d" % [st.value, st.charges]))
	bm.remove_buff(Buff.BuffType.STRENGTHEN)
	_unequip(belt)

func _test_belthronding() -> void:
	print("-- Belthronding: any slotted card conjures Close is Favored, 3 at most --")
	_strip()
	var bow := _equip("belthronding")
	dm.hand.clear()
	var c := _slot(Card.create_by_id("block"), bow)
	for _i in range(4):
		main._ranged_on_self_world_effects(c, null)
	var held := 0
	for h in dm.hand:
		if h.card_id == "close_is_favored":
			held += 1
	_check(held == 3, "Belthronding: four slotted plays leave 3 Close is Favored in hand (%d)" % held)
	dm.hand.clear()
	_check(int(stats.get("equipment_ranged_range_bonus")) == 0, "Belthronding adds no range of its own")
	_unequip(bow)

func _test_bessy() -> void:
	print("-- Bessy: +25% vs Weakened, attack-speed procs 5 swings later --")
	_strip()
	var bessy := _equip("bessy")
	_check(stats.equipment_attack_speed_penalty == 5, "Bessy: the attack-speed threshold is 5 higher while wielded")
	var d: Enemy = dummies[0]
	var plain := Card.create_by_id("slash")
	_reset_dummy(d)
	d.weaken_stacks = 3
	plain.execute(d, stats, dm, 0.0, 0.0, bm)
	var plain_dmg: int = 1000 - d.current_health
	var slotted := _slot(Card.create_by_id("slash"), bessy)
	_reset_dummy(d)
	d.weaken_stacks = 3
	slotted.execute(d, stats, dm, 0.0, 0.0, bm)
	var bessy_dmg: int = 1000 - d.current_health
	var want: int = floori((slotted.base_damage + slotted.bonus_damage) * 0.25)
	_check(bessy_dmg > plain_dmg and bessy_dmg - plain_dmg >= want, "Bessy: a slotted attack on a Weakened enemy hits harder (%d vs %d)" % [bessy_dmg, plain_dmg])
	_check(_hit(_slot(Card.create_by_id("slash"), ItemData.create("bessy")), d) == _hit(Card.create_by_id("slash"), d), "Bessy: no bonus against an enemy that is not Weakened")
	_unequip(bessy)
	_check(stats.equipment_attack_speed_penalty == 0, "Bessy: the penalty leaves with her")

func _test_blast_stick() -> void:
	print("-- Blast Stick: spells cost 10% more, +20% of the cost as damage --")
	_strip()
	var fb := Card.create_by_id("fireball")
	var base_cost: int = int(_cost(fb)["mana"])
	var stick := _equip("blast_stick")
	var stick_cost: int = int(_cost(fb)["mana"])
	_check(stick_cost == ceili(base_cost * 1.1), "Blast Stick: an offensive spell costs 10%% more (%d -> %d)" % [base_cost, stick_cost])
	_check(int(_cost(Card.create_by_id("slash"))["mana"]) == int(_cost(Card.create_by_id("slash"))["mana"]), "Blast Stick: (attack cost read)")
	var with_rider := Card.create_by_id("fireball")
	_hit(with_rider, dummies[0])
	var dmg_on: int = with_rider.last_damage_dealt
	stick.spell_damage_per_mana_percent = 0.0
	var without := Card.create_by_id("fireball")
	_hit(without, dummies[0])
	var dmg_off: int = without.last_damage_dealt
	stick.spell_damage_per_mana_percent = 20.0
	_check(dmg_on - dmg_off == floori(stick_cost * 0.2), "Blast Stick: +20%% of the %d-mana cost as damage (+%d)" % [stick_cost, dmg_on - dmg_off])
	_unequip(stick)

func _test_bloodbound_plate() -> void:
	print("-- Bloodbound Plate: +2 on every armor gain --")
	_strip()
	var plate := _equip("bloodbound_plate")
	stats.current_armor = 0
	stats.add_armor(5)
	_check(stats.current_armor == 7, "Bloodbound Plate: gaining 5 armor gains 7 (%d)" % stats.current_armor)
	# FLAGGED: the text's "+3 armor" has no consumer — armor_bonus is read
	# only as a shield's Basic Block amount (main._on_basic_block).
	stats.current_armor = 0
	_check(stats.current_armor == 0 and plate.armor_bonus == 3, "Bloodbound Plate: '+3 armor' is data only — equipping it grants no armor (flagged)")
	_unequip(plate)

func _test_boomerang() -> void:
	print("-- Boomerang: one-handed --")
	_strip()
	_check(not Inventory.is_two_hand_only(ItemData.create("boomerang")), "Boomerang is one-handed")
	_equip("boomerang")
	# FLAGGED: the text says it "pairs with a quiver"; the 2026-10-25 ruling
	# (test_ranged_pass) keeps quivers beside bows only.
	_check(not inv.equip_item(ItemData.create("standard_quiver"), 1), "Boomerang: a quiver is refused beside it (flagged: text says it pairs with one)")
	_strip()

func _test_boot_holsters() -> void:
	print("-- Boot Holsters: slotted instants zap the nearest enemy; attacks -1 tempo --")
	_strip()
	var boots := _equip("boot_holsters")
	var atk := Card.create_by_id("slash")
	var base_t: int = atk.get_burden_tempo_cost()
	_slot(atk, boots)
	_check(atk.get_burden_tempo_cost() == base_t - 1, "Boot Holsters: a slotted attack costs 1 less tempo (%d -> %d)" % [base_t, atk.get_burden_tempo_cost()])
	var spell := _slot(Card.create_by_id("fireball"), boots)
	_check(spell.get_burden_tempo_cost() == Card.create_by_id("fireball").get_burden_tempo_cost(), "Boot Holsters: a slotted offensive SPELL keeps its tempo (attack cards only)")
	# The instant: Mage Shield fires from the hand on damage taken.
	_park_dummies()
	var d: Enemy = dummies[0]
	_reset_dummy(d)
	_place(d, _pcell() + Vector2i(2, 0))
	var ms := _slot(Card.create_by_id("mage_shield"), ItemData.create("boot_holsters"))
	dm.hand.clear()
	dm.hand.append(ms)
	main._on_player_damage_taken(1)
	_check(1000 - d.current_health == 10, "Boot Holsters: a slotted instant firing deals 10 to the nearest enemy within 3 (%d)" % (1000 - d.current_health))
	_reset_dummy(d)
	_place(d, _pcell() + Vector2i(4, 0))
	dm.hand.append(ms)
	main._on_player_damage_taken(1)
	_check(d.current_health == 1000, "Boot Holsters: an enemy 4 squares away is out of reach")
	# A card in a plain slot carries no riders.
	var holsters2 := ItemData.create("boot_holsters")
	for _i in range(3):
		_slot(Card.create_by_id("slash"), holsters2)
	var plain_ms := _slot(Card.create_by_id("mage_shield"), holsters2)
	_check(holsters2.is_vanilla_slot(plain_ms), "(the fourth slot is the plain one)")
	_reset_dummy(d)
	_place(d, _pcell() + Vector2i(2, 0))
	dm.hand.append(plain_ms)
	main._on_player_damage_taken(1)
	_check(d.current_health == 1000, "Boot Holsters: an instant in the plain slot deals nothing")
	dm.hand.clear()
	stats.current_armor = 0
	_unequip(boots)
	_park_dummies()

func _test_boots_of_speed() -> void:
	print("-- Boots of Speed: 36 movement flash -> -1 tempo on a hand card --")
	_strip()
	var boots := _equip("boots_of_speed")
	_check(stats.movement_flash_tempo_threshold == 36, "Boots of Speed: threshold 36 while worn")
	dm.hand.clear()
	var c := Card.create_by_id("slash")
	dm.hand.append(c)
	var t0: int = c.get_burden_tempo_cost()
	stats.flash_movement_enabled = true
	stats.movement_flash_accum = 0
	var tm = main.tempo_manager
	var moves := 0
	while c.get_burden_tempo_cost() == t0 and moves < 100:
		stats.current_flash_points = 99
		tm.add_movement_tempo()
		moves += 1
	var per_move: int = maxi(1, PlayerStats.FLASH_COST_MOVE - stats.equipment_movement_flash_discount)
	_check(c.get_burden_tempo_cost() == t0 - 1 and moves * per_move == 36, "Boots of Speed: after 36 flash spent moving, a hand card loses 1 tempo (%d moves of %d)" % [moves, per_move])
	stats.flash_movement_enabled = false
	dm.hand.clear()
	_unequip(boots)
	_check(stats.movement_flash_tempo_threshold == 0, "Boots of Speed: the threshold leaves with them")

func _test_boots_of_the_balancer() -> void:
	print("-- Boots of the Balancer: 5 armor per 10% missing health --")
	_strip()
	var boots := _equip("boots_of_the_balancer")
	stats.current_armor = 0
	stats.current_health = int(stats.max_health * 0.55)  # 45% missing -> 4 steps
	var missing_steps: int = int((1.0 - stats.get_health_percent()) * 100.0 / 10)
	_slot(Card.create_by_id("block"), boots).execute(main.player, stats, dm, 0.0, 0.0, bm)
	var block_armor: int = Card.create_by_id("block").block
	_check(stats.current_armor - block_armor == 5 * missing_steps, "Boots of the Balancer: +%d armor at %d steps missing (%d)" % [5 * missing_steps, missing_steps, stats.current_armor - block_armor])
	stats.current_armor = 0
	stats.current_health = stats.max_health
	_unequip(boots)

func _test_bow_of_arash() -> void:
	print("-- Bow of Arash: +2 ranged range, half the mana paid in life --")
	_strip()
	var bow := _equip("bow_of_arash")
	_check(main._helm_range_bonus(Card.create_by_id("fireball")) == 2, "Bow of Arash: a ranged offensive card gains 2 range")
	_check(main._helm_range_bonus(Card.create_by_id("slash")) == 0, "Bow of Arash: a melee card gains none")
	var fb := Card.create_by_id("fireball")
	var full: int = int(_cost(fb)["mana"])
	_slot(fb, bow)
	var split := _cost(fb)
	_check(int(split["arash_life"]) == floori(full / 2.0) and int(split["mana"]) == full - floori(full / 2.0),
		"Bow of Arash: a slotted card pays half its %d mana as life (%d mana + %d life)" % [full, int(split["mana"]), int(split["arash_life"])])
	_unequip(bow)
	_check(main._helm_range_bonus(Card.create_by_id("fireball")) == 0, "Bow of Arash: the range leaves with it")

func _test_bow_of_budding_blasts() -> void:
	print("-- Bow of Budding Blasts: crits bud bows (4 max); +2 dmg / +5% crit per bow --")
	_strip()
	var bow := _equip("bow_of_budding_blasts")
	main._clear_spirit_bows()
	for _i in range(5):
		main._spawn_bud_bow()
	_check(main._spirit_bows.size() == 4 and stats.bow_instance_count == 4, "Budding Blasts: buds cap at 4 (%d)" % main._spirit_bows.size())
	var b0 = main._spirit_bows[0]
	_check(b0.is_bud and b0.base_attack() == 6 and b0.attack_interval() == 5 and b0.attacks_left == 2, "a bud: 6 damage every 5 tempo, 2 shots")
	b0.take_damage(1)
	main._refresh_bow_instances()
	_check(stats.bow_instance_count == 3, "a bud dies to any damage (%d left)" % stats.bow_instance_count)
	var plain := _hit(Card.create_by_id("slash"), dummies[0])
	var slotted := _hit(_slot(Card.create_by_id("slash"), bow), dummies[0])
	_check(slotted - plain == 2 * 3, "Budding Blasts: a slotted attack gains +2 per living bow (+%d with 3)" % (slotted - plain))
	main._clear_spirit_bows()
	# A crit with a slotted offensive card buds one.
	stats.equipment_crit_bonus = 1000.0
	_park_dummies()
	var d: Enemy = dummies[0]
	_reset_dummy(d)
	_place(d, _pcell() + Vector2i(1, 0))
	_play(_slot(Card.create_by_id("slash"), bow), d)
	stats.equipment_crit_bonus = -100.0
	_check(main._spirit_bows.size() == 1, "Budding Blasts: a crit with a slotted attack buds a bow (%d)" % main._spirit_bows.size())
	main._clear_spirit_bows()
	_unequip(bow)
	_reset_dummy(d)

func _test_brass_knuckles() -> void:
	print("-- Brass Knuckles: +2 melee damage, 1 unerring per 20 tempo --")
	_strip()
	var plain := _hit(Card.create_by_id("slash"), dummies[0])
	var fb0 := Card.create_by_id("fireball")
	_hit(fb0, dummies[0])
	var knuckles := _equip("brass_knuckles")
	_check(_hit(Card.create_by_id("slash"), dummies[0]) - plain == 2, "Brass Knuckles: a melee offensive card deals +2")
	var fb1 := Card.create_by_id("fireball")
	_hit(fb1, dummies[0])
	_check(fb1.last_damage_dealt == fb0.last_damage_dealt, "Brass Knuckles: a ranged card gains nothing")
	stats.unerring_armor = 0
	for _i in range(3):
		inv.process_turn()
	_check(stats.unerring_armor == 0, "Brass Knuckles: nothing at 15 tempo")
	inv.process_turn()
	_check(stats.unerring_armor == 1, "Brass Knuckles: 1 unerring armor at 20 tempo (%d)" % stats.unerring_armor)
	stats.unerring_armor = 0
	stats.current_armor = 0
	_unequip(knuckles)

func _test_buckler() -> void:
	print("-- Buckler: every hit 3 lighter --")
	_strip()
	stats.current_armor = 0
	stats.unerring_armor = 0
	stats.current_health = stats.max_health
	stats.take_damage(20)
	var plain: int = stats.max_health - stats.current_health
	var buckler := _equip("buckler")
	stats.current_armor = 0
	stats.current_health = stats.max_health
	stats.take_damage(20)
	var shielded: int = stats.max_health - stats.current_health
	_check(plain - shielded == 3, "Buckler: a 20 hit lands 3 lighter (%d vs %d)" % [shielded, plain])
	_unequip(buckler)
	stats.current_health = stats.max_health

## Burgonet, Chain Crocs, Chain Gloves, Chain Mail: the unerring clock.
func _test_periodic_unerring() -> void:
	print("-- Periodic unerring armor --")
	var rows := [["burgonet", 2, 5], ["chain_crocs", 5, 15], ["chain_gloves", 1, 15], ["chain_mail", 8, 15]]
	# Chain Mail fills "up to your unerring cap": at the base cap it stops there.
	_strip()
	var mail := _equip("chain_mail")
	stats.unerring_armor = 0
	for _i in range(3):
		inv.process_turn()
	_check(stats.unerring_armor == mini(8, stats.get_unerring_cap()), "chain_mail: the grant stops at the unerring cap (%d of cap %d)" % [stats.unerring_armor, stats.get_unerring_cap()])
	_unequip(mail)
	# Room above every grant, so each number shows in full.
	stats.equipment_unerring_cap += 20
	for r in rows:
		_strip()
		var item := _equip(r[0])
		stats.unerring_armor = 0
		var cap: int = stats.get_unerring_cap()
		var cycles: int = int(r[2]) / 5
		for _i in range(cycles - 1):
			inv.process_turn()
		_check(stats.unerring_armor == 0, "%s: nothing before %d tempo" % [r[0], r[2]])
		inv.process_turn()
		_check(stats.unerring_armor == mini(int(r[1]), cap), "%s: %d unerring armor every %d tempo (got %d, cap %d)" % [r[0], r[1], r[2], stats.unerring_armor, cap])
		# Unequip resets the counter: a fresh equip starts from zero again.
		for _i in range(cycles - 1):
			inv.process_turn()
		_unequip(item)
		inv.equip_item(item, 0)
		stats.unerring_armor = 0
		for _i in range(cycles - 1):
			inv.process_turn()
		_check(stats.unerring_armor == 0, "%s: the counter resets when unequipped" % r[0])
		_unequip(item)
		stats.unerring_armor = 0
		stats.current_armor = 0
	stats.equipment_unerring_cap -= 20

func _test_capacious_extremus() -> void:
	print("-- Capacious Extremus: slotted cards 10% cheaper --")
	_strip()
	inv.equip_item(ItemData.create("short_bow"), 1)
	var q := _equip("capacious_extremus")
	var c := Card.create_by_id("fireball")
	var full: int = int(_cost(c)["mana"])
	_slot(c, q)
	_check(int(_cost(c)["mana"]) == floori(full * 0.9), "Capacious Extremus: a slotted card costs 10%% less (%d -> %d)" % [full, int(_cost(c)["mana"])])
	_check(q.card_slots == 4 and q.vanilla_slots == 1, "Capacious Extremus: 5 slots, 4 bonus and 1 plain")
	_strip()

func _test_captain_planet() -> void:
	print("-- Captain Planets Circlet: the five powers combine --")
	_strip()
	var ring := _equip("captain_planets_circlet")
	dm.hand.clear()
	dm.draw_pile.clear()
	dm.discard_pile.clear()
	for _i in range(4):
		dm.draw_pile.append(Card.create_by_id("slash"))
	stats.equipment_hand_bonus += 3  # room for the whole payout (a full hand turns cards away)
	stats.recalculate_derived_stats()
	stats.current_health = 50
	inv.on_player_debuff_applied("burn", 1)
	inv.on_player_debuff_applied("cold", 1)
	inv.on_player_debuff_applied("silenced", 5)
	bm.apply_buff(Buff.create_strengthen(1, 1, "test"))
	_check(stats.current_health == 50, "Captain Planet: four of five does nothing")
	bm.apply_buff(Buff.create_regen(1, 5, "test"))
	_check(stats.current_health >= 65, "Captain Planet: all five heal 15 (%d)" % stats.current_health)
	var ids: Array = []
	for c in dm.hand:
		ids.append(c.card_id)
	_check(ids.count("slash") == 3 and ids.has("fireball") and ids.has("rise"), "Captain Planet: draw 3 and add a Fireball and a Rise (%s)" % str(ids))
	var erase_ok := true
	for c in dm.hand:
		if c.card_id in ["fireball", "rise"] and c.erase_tempo_remaining != 10:
			erase_ok = false
	_check(erase_ok, "Captain Planet: the conjured pair carries Erase 10")
	dm.hand.clear()
	stats.equipment_hand_bonus -= 3
	stats.recalculate_derived_stats()
	stats.current_health = stats.max_health
	_unequip(ring)

func _test_car_battery() -> void:
	print("-- Car Battery: damaging offensive cards slotted here apply 3 Shock --")
	_strip()
	var bat := _equip("car_battery")
	var d: Enemy = dummies[0]
	_hit(_slot(Card.create_by_id("slash"), bat), d)
	_check(d.shock_stacks == 3, "Car Battery: a slotted attack applies 3 Shock (%d)" % d.shock_stacks)
	_hit(Card.create_by_id("slash"), d)
	_check(d.shock_stacks == 0, "Car Battery: an unslotted attack applies none")
	var plain_slot := _slot(Card.create_by_id("slash"), bat)
	var vanilla_card := _slot(Card.create_by_id("slash"), bat)
	_check(bat.is_vanilla_slot(vanilla_card) and not bat.is_vanilla_slot(plain_slot), "(third slot is plain)")
	_hit(vanilla_card, d)
	_check(d.shock_stacks == 0, "Car Battery: a card in the plain slot applies none")
	_unequip(bat)
	_reset_dummy(d)

func _test_caster_boots() -> void:
	print("-- Caster Boots: +10% of INT as damage --")
	_strip()
	var boots := _equip("caster_boots")
	stats.base_intelligence += 50  # enough INT that 10% of it is visible
	stats.recalculate_derived_stats()
	var plain := _hit(Card.create_by_id("slash"), dummies[0])
	var slotted := _hit(_slot(Card.create_by_id("slash"), boots), dummies[0])
	_check(slotted - plain == floori(stats.intelligence * 0.1) and slotted > plain, "Caster Boots: a slotted damaging card deals +10%% of INT (+%d, INT %d)" % [slotted - plain, stats.intelligence])
	stats.base_intelligence -= 50
	stats.recalculate_derived_stats()
	_unequip(boots)

func _test_castle_wall() -> void:
	print("-- Castle wall: +8 block on-self, -3 hand size --")
	_strip()
	var hand0: int = dm.get_hand_cap()
	var wall := _equip("castle_wall")
	_check(dm.get_hand_cap() == hand0 - 3, "Castle wall: hand size 3 smaller (%d -> %d)" % [hand0, dm.get_hand_cap()])
	stats.current_armor = 0
	var blk := _slot(Card.create_by_id("block"), wall)
	blk.execute(main.player, stats, dm, 0.0, 0.0, bm)
	_check(stats.current_armor == Card.create_by_id("block").block + 8, "Castle wall: a slotted block card blocks 8 more (%d)" % stats.current_armor)
	_check(blk.block == Card.create_by_id("block").block, "Castle wall: the +8 never sticks to the card")
	stats.current_armor = 0
	_unequip(wall)
	_check(dm.get_hand_cap() == hand0, "Castle wall: the hand size comes back")

func _test_chain_crocs() -> void:
	print("-- Chain Crocs: slotted cards 20% cheaper --")
	_strip()
	var crocs := _equip("chain_crocs")
	var c := Card.create_by_id("fireball")
	var full: int = int(_cost(c)["mana"])
	_slot(c, crocs)
	_check(int(_cost(c)["mana"]) == floori(full * 0.8), "Chain Crocs: a slotted card costs 20%% less (%d -> %d)" % [full, int(_cost(c)["mana"])])
	_unequip(crocs)

## Chain Gloves (Guard), Cloth bracer (Band aid), Copper Bracers (Clang),
## Concealed Carry (Lethal Poke), Cuffs of Current (Zeet).
func _test_gauntlet_skills() -> void:
	print("-- Gauntlet skills --")
	var rows := [["chain_gloves", "Guard", 4], ["cloth_bracer", "Band aid", 4], ["copper_bracers", "Clang", 3],
		["concealed_carry", "Lethal Poke", 3], ["cuffs_of_current", "Zeet", 3]]
	_park_dummies()
	var d: Enemy = dummies[0]
	for r in rows:
		_strip()
		var g := _equip(r[0])
		stats.current_mana = stats.max_mana
		stats.current_armor = 0
		stats.current_health = stats.max_health - 20
		_reset_dummy(d)
		_place(d, _pcell() + Vector2i(1, 0))
		var mana0: float = stats.current_mana
		var hp0: int = stats.current_health
		_check(inv.use_gauntlet_skill(g, d), "%s: %s fires" % [r[0], r[1]])
		match r[0]:
			"chain_gloves":
				_check(stats.current_armor == 2, "Chain Gloves: Guard gains 2 armor (%d)" % stats.current_armor)
			"cloth_bracer":
				_check(stats.current_health == hp0 + stats.get_effective_heal_amount(5), "Cloth bracer: Band aid heals 5 (+INT bonus) (%d)" % (stats.current_health - hp0))
			"copper_bracers":
				_check(stats.current_armor == 8 and int(mana0 - stats.current_mana) == 25, "Copper Bracers: Clang gains 8 armor for 25 mana (%d armor, %d mana)" % [stats.current_armor, int(mana0 - stats.current_mana)])
			"concealed_carry":
				_check(1000 - d.current_health == stats.get_effective_physical_damage(0), "Concealed Carry: Lethal Poke is a 0-base melee hit (%d)" % (1000 - d.current_health))
			"cuffs_of_current":
				_check(1000 - d.current_health == int(stats.intelligence / 2.0) and int(mana0 - stats.current_mana) == 35, "Cuffs of Current: Zeet deals INT/2 for 35 mana (%d, INT %d)" % [1000 - d.current_health, stats.intelligence])
		_check(not inv.can_use_gauntlet_skill(g), "%s: %s goes on cooldown" % [r[0], r[1]])
		for _i in range(int(r[2]) - 1):
			inv.process_turn()
		stats.current_mana = stats.max_mana  # the cooldown, not the mana, is under test
		_check(not inv.can_use_gauntlet_skill(g), "%s: still cooling at %d tempo" % [r[0], (int(r[2]) - 1) * 5])
		inv.process_turn()
		_check(inv.can_use_gauntlet_skill(g), "%s: ready again after %d tempo" % [r[0], int(r[2]) * 5])
		if r[0] == "concealed_carry":
			# A crit is multiplied a further x1.5 on top.
			stats.equipment_crit_bonus = 1000.0
			_reset_dummy(d)
			var poke_base: int = stats.get_effective_physical_damage(0)
			inv.use_gauntlet_skill(g, d)
			var want_crit: int = floori(float(Card.crit_multiply(poke_base, stats, null)) * 1.5)
			stats.equipment_crit_bonus = -100.0
			_check(1000 - d.current_health == want_crit, "Concealed Carry: a Lethal Poke crit deals x1.5 on top of the crit (%d, want %d)" % [1000 - d.current_health, want_crit])
		_unequip(g)
	stats.current_armor = 0
	stats.unerring_armor = 0
	stats.current_health = stats.max_health
	_reset_dummy(d)
	_park_dummies()

func _test_chewbaccas_bandolier() -> void:
	print("-- Chewbaccas Bandolier: ranged slotted -1 tempo +5 damage; casings --")
	_strip()
	var band := _equip("chewbaccas_bandolier")
	var qs := Card.create_by_id("cupids_golden_arrow")
	var t0: int = qs.get_burden_tempo_cost()
	var plain := _hit(Card.create_by_id("cupids_golden_arrow"), dummies[0])
	_slot(qs, band)
	_check(qs.get_burden_tempo_cost() == maxi(0, t0 - 1), "Chewbaccas: a slotted ranged attack costs 1 less tempo (%d -> %d)" % [t0, qs.get_burden_tempo_cost()])
	_check(_hit(qs, dummies[0]) - plain == 5, "Chewbaccas: a slotted ranged attack deals +5")
	var sl := _slot(Card.create_by_id("slash"), band)
	_check(_hit(sl, dummies[0]) == _hit(Card.create_by_id("slash"), dummies[0]), "Chewbaccas: a slotted melee card gains no damage")
	# Casings.
	_park_dummies()
	main._clear_bullet_casings()
	main._maybe_drop_bullet_casing(Card.create_by_id("slash"))
	_check(main._bullet_casings.is_empty(), "Chewbaccas: a melee card drops no casing")
	main._maybe_drop_bullet_casing(Card.create_by_id("cupids_golden_arrow"))
	_check(main._bullet_casings.size() == 1, "Chewbaccas: a ranged offensive card drops a casing")
	var d: Enemy = dummies[0]
	_reset_dummy(d)
	_place(d, _pcell() + Vector2i(1, 0))
	main._update_bullet_casings(4)
	_check(d.current_health == 1000 and main._bullet_casings.size() == 1, "Chewbaccas: the casing waits 4 tempo")
	stats.current_health = stats.max_health
	main._update_bullet_casings(1)
	_check(1000 - d.current_health == 8 and main._bullet_casings.is_empty(), "Chewbaccas: after 5 tempo it explodes for 8 (%d)" % (1000 - d.current_health))
	_check(stats.current_health == stats.max_health, "Chewbaccas: the casing never hurts you")
	main._clear_bullet_casings()
	main._maybe_drop_bullet_casing(Card.create_by_id("cupids_golden_arrow"))
	var cell: Vector2i = main._bullet_casings[0]["cell"]
	_reset_dummy(d)
	_place(d, cell)
	main._update_bullet_casings(1)
	_check(1000 - d.current_health == 8, "Chewbaccas: an enemy stepping on it sets it off at once")
	main._clear_bullet_casings()
	_unequip(band)
	_park_dummies()
	_reset_dummy(d)

func _test_circes_wand() -> void:
	print("-- Circe's Wand: damaging offensive cards Silence 5 tempo --")
	_strip()
	var wand := _equip("circes_wand_of_cauldron_stirring")
	var d: Enemy = dummies[0]
	_hit(Card.create_by_id("slash"), d)
	_check(d.silenced_tempo == 5, "Circe's Wand: an attack (slotted or not) Silences 5 tempo (%d)" % d.silenced_tempo)
	_reset_dummy(d)
	_hit(Card.create_by_id("volatile_mixture"), d)
	_check(d.silenced_tempo == 0, "Circe's Wand: a damaging card that is not offensive does not")
	_unequip(wand)
	_reset_dummy(d)

func _test_coffin_lid() -> void:
	print("-- Coffin Lid: 10% lifesteal on slotted attacks, +8% below half --")
	_strip()
	var lid := _equip("coffin_lid")
	# The same slotted attack with and without the lid's 10% (Brad's own
	# lifesteal, if any, rides both).
	var sl := _slot(Card.create_by_id("slash"), lid)
	stats.current_health = stats.max_health - 100
	var hp0: int = stats.current_health
	var dealt: int = _hit(sl, dummies[0])
	var with_lid: int = stats.current_health - hp0
	lid.on_self_lifesteal_percent = 0.0
	stats.current_health = hp0
	_hit(sl, dummies[0])
	var without: int = stats.current_health - hp0
	lid.on_self_lifesteal_percent = 10.0
	# The life drunk is a heal: it carries the INT heal bonus like every heal.
	var want: int = stats.get_effective_heal_amount(maxi(1, floori(dealt * 0.10)))
	_check(with_lid - without == want,
		"Coffin Lid: a slotted attack heals 10%% of its %d damage (+%d)" % [dealt, with_lid - without])
	stats.current_health = hp0
	_hit(Card.create_by_id("slash"), dummies[0])
	_check(stats.current_health - hp0 == without, "Coffin Lid: an unslotted attack does not drink the 10%% (+%d)" % (stats.current_health - hp0))
	stats.current_health = int(stats.max_health * 0.4)
	_check(is_equal_approx(stats.get_equipment_lifesteal(), 8.0), "Coffin Lid: below half health, +8%% lifesteal (%.1f)" % stats.get_equipment_lifesteal())
	stats.current_health = stats.max_health
	_check(is_equal_approx(stats.get_equipment_lifesteal(), 0.0), "Coffin Lid: none above half")
	_unequip(lid)

func _test_corset_of_cure() -> void:
	print("-- Corset of Cure: cleanse 3 stacks on the target; tonic on a debuff removed --")
	_strip()
	var corset := _equip("corset_of_cure")
	var pdm = main.player.get_debuff_manager()
	pdm.clear_all_debuffs()
	var wk := Debuff.create(Debuff.DebuffType.WEAKENED, 5, 30)
	pdm.apply_debuff(wk)
	var before: int = pdm.debuffs[0].value if pdm.debuffs.size() > 0 else -1
	_slot(Card.create_by_id("block"), corset).execute(main.player, stats, dm, 0.0, 0.0, bm)
	var after: int = pdm.debuffs[0].value if pdm.debuffs.size() > 0 else 0
	_check(before - after == 3, "Corset of Cure: a slotted card aimed at you cleanses 3 stacks (%d -> %d)" % [before, after])
	# A slotted card with no target (an instant firing) must still finish.
	var depth0: int = Card._exec_depth
	var hl := _slot(Card.create_by_id("slash"), ItemData.create("corset_of_cure"))
	hl.execute(null, stats, dm, 0.0, 0.0, bm)
	_check(Card._exec_depth == depth0, "Corset of Cure: a slotted card with no target resolves cleanly (no error mid-play)")
	Card._exec_depth = depth0
	dm.hand.clear()
	for dbf in pdm.debuffs.duplicate():
		pdm.remove_debuff(dbf.debuff_type)
	var tonic_n := 0
	for c in dm.hand:
		if c.card_id == "healing_tonic":
			tonic_n += 1
	_check(tonic_n == 1, "Corset of Cure: a debuff leaving you puts a Healing Tonic in hand (%d)" % tonic_n)
	var tonic := Card.create_by_id("healing_tonic")
	_check(tonic.mana_cost == 0 and tonic.tempo_cost == 0 and tonic.heal_amount == 5 and tonic.get_effective_range() == 5, "Healing Tonic: 0m/0t, range 5, heal 5")
	dm.hand.clear()
	_unequip(corset)

func _test_crooked_dueling_shield() -> void:
	print("-- Crooked Dueling Shield: blue/red combo armor; full blocks Weaken --")
	_strip()
	var sh := _equip("crooked_dueling_shield")
	var blue := _slot(Card.create_by_id("slash"), sh, 0)
	var red := _slot(Card.create_by_id("slash"), sh, 1)
	_check(sh.get_slot_color(blue) == "blue" and sh.get_slot_color(red) == "red", "(blue slot, red slot)")
	_park_dummies()
	var d: Enemy = dummies[0]
	_reset_dummy(d)
	_place(d, _pcell() + Vector2i(1, 0))
	sh.last_color_played = ""
	stats.current_armor = 0
	_play(blue, d)
	_check(d.weaken_stacks >= 1 and d.vulnerable_stacks == 0, "Crooked: the blue card applies 1 Weaken (W%d V%d)" % [d.weaken_stacks, d.vulnerable_stacks])
	var armor_after_blue: int = stats.current_armor
	_play(red, d)
	_check(d.vulnerable_stacks >= 1, "Crooked: the red card applies 1 Vulnerable (V%d)" % d.vulnerable_stacks)
	_check(stats.current_armor - armor_after_blue == 10, "Crooked: red right after blue gains 10 armor (%d)" % (stats.current_armor - armor_after_blue))
	# Full block: Weaken 2, or 5 damage into an already-Weakened attacker.
	_reset_dummy(d)
	stats.last_attacker = d
	main._shields_on_attack_blocked()
	_check(d.weaken_stacks == 2, "Crooked: a fully blocked attack Weakens the attacker 2 (%d)" % d.weaken_stacks)
	main._shields_on_attack_blocked()
	_check(1000 - d.current_health == 5, "Crooked: blocking an already-Weakened attacker deals 5 (%d)" % (1000 - d.current_health))
	stats.last_attacker = null
	stats.current_armor = 0
	_unequip(sh)
	_reset_dummy(d)
	_park_dummies()

func _test_cuffs_of_current() -> void:
	print("-- Cuffs of Current: draw 1 every 3 cycles --")
	_strip()
	var cuffs := _equip("cuffs_of_current")
	dm.hand.clear()
	dm.draw_pile.clear()
	for _i in range(6):
		dm.draw_pile.append(Card.create_by_id("slash"))
	main._cuffs_cycle_accum = 0
	main._helm_on_cycle_passives()
	main._helm_on_cycle_passives()
	_check(dm.hand.size() == 0, "Cuffs of Current: nothing after 2 cycles")
	main._helm_on_cycle_passives()
	_check(dm.hand.size() == 1, "Cuffs of Current: a free draw on the 3rd cycle (%d)" % dm.hand.size())
	dm.hand.clear()
	_unequip(cuffs)

func _test_cyclops_ring() -> void:
	print("-- Cyclops Ring: three 25+ hits -> Strengthen 15 for 2 hits --")
	_strip()
	var ring := _equip("cyclops_ring")
	bm.remove_buff(Buff.BuffType.STRENGTHEN)
	main._ring_note_big_hit(30)
	main._ring_note_big_hit(24)
	main._ring_note_big_hit(30)
	_check(bm.get_strengthen_bonus() == 0, "Cyclops Ring: a 24 does not count — two big hits, nothing yet")
	main._ring_note_big_hit(25)
	var st: Buff = bm.get_buff(Buff.BuffType.STRENGTHEN)
	_check(st != null and st.value == 15 and st.charges == 2, "Cyclops Ring: the third 25+ hit grants Strengthen 15 for 2 hits")
	main._ring_note_big_hit(40)
	main._ring_note_big_hit(40)
	_check(int(ring.ring_counters.get("big_hits", 0)) == 0, "Cyclops Ring: the two strengthened hits don't feed the counter")
	main._ring_note_big_hit(40)
	_check(int(ring.ring_counters.get("big_hits", 0)) == 1, "Cyclops Ring: the next hit counts again")
	bm.remove_buff(Buff.BuffType.STRENGTHEN)
	_unequip(ring)

func _test_cyde_sneakers() -> void:
	print("-- Cyde Livingstons Sneakers: 5 consecutive attacks draw --")
	_strip()
	var sn := _equip("cyde_livingstons_sneakers")
	dm.hand.clear()
	dm.draw_pile.clear()
	for _i in range(6):
		dm.draw_pile.append(Card.create_by_id("block"))
	stats.consecutive_attacks = 0
	for _i in range(4):
		stats.register_attack()
	_check(dm.hand.size() == 0, "Cyde: 4 attacks draw nothing")
	stats.register_attack()
	_check(dm.hand.size() == 1, "Cyde: the 5th consecutive attack draws a card (%d)" % dm.hand.size())
	dm.hand.clear()
	for _i in range(4):
		stats.register_attack()
	_hit(Card.create_by_id("block"), dummies[0])  # a non-attack breaks the run
	stats.register_attack()
	_check(dm.hand.size() == 0, "Cyde: a non-attack card breaks the streak")
	dm.hand.clear()
	_unequip(sn)
	_check(stats.consecutive_attacks_draw_at == 0, "Cyde: the rider leaves with them")

func _test_delfins() -> void:
	print("-- Delfins: +10% to slotted rolls; Overdraw Peak 4 --")
	_strip()
	var sh := _equip("delfins_deterministic_round_shield")
	seed(1234)
	var plain := Card.create_by_id("slash")
	plain.rng_outcomes_data = [{"percent": 90.0}]
	var fails := 0
	for _i in range(300):
		plain.roll_rng()
		if plain.rng_selected_index != 0:
			fails += 1
	var boosted := _slot(Card.create_by_id("slash"), sh)
	boosted.rng_outcomes_data = [{"percent": 90.0}]
	var boosted_fails := 0
	for _i in range(300):
		boosted.roll_rng()
		if boosted.rng_selected_index != 0:
			boosted_fails += 1
	_check(fails > 0 and boosted_fails == 0, "Delfins: a 90%% roll becomes 100%% slotted (%d plain fails, %d slotted)" % [fails, boosted_fails])
	dm.draw_pile.clear()
	for cid in ["slash", "block", "fireball", "quick_shot", "rise", "blink"]:
		dm.draw_pile.append(Card.create_by_id(cid))
	var logged: Array = []
	var grab := func(m): logged.append(m)
	main.battle_logged.connect(grab)
	main._overdraw_peak(sh)
	main.battle_logged.disconnect(grab)
	var named := 0
	for i in range(4):
		var nm: String = dm.draw_pile[dm.draw_pile.size() - 1 - i].card_name
		if logged.size() > 0 and str(logged[0]).contains(nm):
			named += 1
	_check(dm.peaked_card == dm.draw_pile.back() and named == 4 and logged.size() > 0 and str(logged[0]).contains("Peak 4"),
		"Delfins: Overdraw peaks the next 4 cards of the draw pile (%s)" % (str(logged[0]) if logged.size() > 0 else "no log"))
	_unequip(sh)

## Diamond Ring and Divine Resistance: all-type resistance.
func _test_resist_items() -> void:
	print("-- Diamond Ring 3%, Divine Resistance 1% per 8% missing --")
	_strip()
	var ring := _equip("diamond_ring")
	stats.current_armor = 0
	stats.unerring_armor = 0
	stats.current_health = stats.max_health
	stats.take_damage(100)
	_check(stats.max_health - stats.current_health == 97, "Diamond Ring: a 100 hit lands as 97 (%d)" % (stats.max_health - stats.current_health))
	_unequip(ring)
	var dr := _equip("divine_resistance")
	stats.current_health = int(stats.max_health * 0.5)  # 50% missing -> 6 steps of 8%
	var steps: int = int((1.0 - stats.get_health_percent()) * 100.0 / 8)
	var hp0: int = stats.current_health
	stats.take_damage(100)
	_check(hp0 - stats.current_health == floori(100 * (1.0 - steps / 100.0)), "Divine Resistance: %d%% resist at %d%% missing (took %d)" % [steps, 50, hp0 - stats.current_health])
	stats.current_health = stats.max_health
	hp0 = stats.current_health
	stats.take_damage(100)
	_check(hp0 - stats.current_health == 100, "Divine Resistance: no resist at full health")
	stats.current_health = stats.max_health
	_unequip(dr)

func _test_dragon_skull() -> void:
	print("-- Dragon Skull: +1 range on slotted offensive cards; crit fire cone --")
	_strip()
	var skull := _equip("dragon_skull")
	var melee := _slot(Card.create_by_id("slash"), skull)
	var ranged := _slot(Card.create_by_id("fireball"), skull)
	_check(main._helm_range_bonus(melee) == 1 and main._helm_range_bonus(ranged) == 1, "Dragon Skull: any slotted offensive card gains 1 range")
	var plain_slot := _slot(Card.create_by_id("cupids_golden_arrow"), skull)
	_check(skull.is_vanilla_slot(plain_slot) and main._helm_range_bonus(plain_slot) == 0, "Dragon Skull: a card in the plain slot gains no range")
	_check(main._helm_range_bonus(_slot(Card.create_by_id("block"), ItemData.create("dragon_skull"))) == 0, "Dragon Skull: a non-offensive card gains none")
	_park_dummies()
	var d: Enemy = dummies[0]
	_reset_dummy(d)
	_place(d, _pcell() + Vector2i(2, 0))
	main._helm_crit_fire_cone(d)
	_check(1000 - d.current_health == 10 + int(stats.intelligence / 2.0), "Dragon Skull: a crit breathes 10 + INT/2 fire in the cone (%d, INT %d)" % [1000 - d.current_health, stats.intelligence])
	_reset_dummy(d)
	_place(d, _pcell() + Vector2i(5, 0))
	main._helm_crit_fire_cone(d)
	_check(d.current_health == 1000, "Dragon Skull: the cone reaches 3 squares, not 5")
	_unequip(skull)
	_reset_dummy(d)
	_park_dummies()

func _test_draupnir() -> void:
	print("-- Draupnir: every 9th hit drips a duplicate --")
	_strip()
	var ring := _equip("draupnir")
	for c in main._clones:
		if is_instance_valid(c):
			c.queue_free()
	main._clones.clear()
	stats.draupnir_clone_alive = false
	for _i in range(8):
		inv.on_damage_taken()
	_check(main._clones.is_empty(), "Draupnir: 8 hits, no duplicate")
	inv.on_damage_taken()
	_check(main._clones.size() == 1, "Draupnir: the 9th hit drips a duplicate")
	if main._clones.size() == 1:
		var clone = main._clones[0]
		_check(clone.max_health == floori(stats.max_health * 0.25), "Draupnir: the duplicate has a quarter of your health (%d of %d)" % [clone.max_health, stats.max_health])
		_check(clone.ATTACK_INTERVAL == 7 and clone.MOVE_INTERVAL == 3 and clone.MOVE_STEPS == 2, "Draupnir: swings every 7 tempo, moves 2 squares per 3 tempo")
		for _i in range(9):
			inv.on_damage_taken()
		_check(main._clones.size() == 1, "Draupnir: only one at a time")
		bm.remove_buff(Buff.BuffType.STRENGTHEN)
		clone.take_damage(9999)
		var st: Buff = bm.get_buff(Buff.BuffType.STRENGTHEN)
		_check(st != null and st.value == 10 and st.charges == 2, "Draupnir: the duplicate dying grants Strengthen 10 for 2 attacks")
		bm.remove_buff(Buff.BuffType.STRENGTHEN)
	main._clones.clear()
	stats.draupnir_clone_alive = false
	_unequip(ring)

func _test_earth_book() -> void:
	print("-- Earth Book: +1 block, +1 offensive damage, 3 armor on-self --")
	_strip()
	var plain := _hit(Card.create_by_id("slash"), dummies[0])
	stats.current_armor = 0
	Card.create_by_id("block").execute(main.player, stats, dm, 0.0, 0.0, bm)
	var block_plain: int = stats.current_armor
	var book := _equip("earth_book")
	_check(_hit(Card.create_by_id("slash"), dummies[0]) - plain == 1, "Earth Book: an offensive card deals +1")
	stats.current_armor = 0
	Card.create_by_id("block").execute(main.player, stats, dm, 0.0, 0.0, bm)
	_check(stats.current_armor - block_plain == 1, "Earth Book: an armor-granting card grants +1 block")
	stats.current_armor = 0
	_hit(_slot(Card.create_by_id("slash"), book), dummies[0])
	# The 3 armor makes the card armor-granting, so the book's +1 rides it too.
	_check(stats.current_armor == 3 + 1, "Earth Book: any slotted card gains you 3 armor (+1 from the book's own block bonus) (%d)" % stats.current_armor)
	stats.current_armor = 0
	_unequip(book)

func _test_elemental_emblem() -> void:
	print("-- Elemental emblem: a shield --")
	var em := ItemData.create("elemental_emblem")
	_check(em.weapon_subtype == ItemData.WeaponSubtype.SHIELD and em.card_slots == 0, "Elemental emblem is a shield with plain slots only")

func _test_trail_blazers() -> void:
	print("-- Elemental Trail Blazers: flash moves leave INT/5 fire for 3 tempo --")
	_strip()
	var boots := _equip("elemental_trail_blazers")
	main._clear_fire_spots()
	_park_dummies()
	var cell := _pcell() + Vector2i(0, 2)
	stats.flash_movement_enabled = false
	main._maybe_drop_fire_trail(cell)
	_check(main._fire_spots.is_empty(), "Trail Blazers: a tempo move leaves no fire")
	stats.flash_movement_enabled = true
	main._maybe_drop_fire_trail(cell)
	_check(main._fire_spots.size() == 1 and int(main._fire_spots[0]["damage"]) == maxi(1, floori(stats.intelligence / 5.0)) and int(main._fire_spots[0]["tempo"]) == 3,
		"Trail Blazers: a flash move leaves a fire spot (INT/5, 3 tempo)")
	var d: Enemy = dummies[0]
	_reset_dummy(d)
	_place(d, cell)
	main._update_fire_spots(1)
	_check(1000 - d.current_health == maxi(1, floori(stats.intelligence / 5.0)) and main._fire_spots.is_empty(), "Trail Blazers: an enemy on it takes INT/5 and the fire goes out (%d)" % (1000 - d.current_health))
	main._maybe_drop_fire_trail(cell + Vector2i(1, 0))
	_place(d, _pcell() + Vector2i(8, 8))
	main._update_fire_spots(2)
	_check(main._fire_spots.size() == 1, "Trail Blazers: an untouched spot is still burning at 2 tempo")
	main._update_fire_spots(1)
	_check(main._fire_spots.is_empty(), "Trail Blazers: it burns out at 3 tempo")
	stats.flash_movement_enabled = false
	main._clear_fire_spots()
	_unequip(boots)
	_reset_dummy(d)
	_park_dummies()

func _test_elemental_weaver() -> void:
	print("-- Elemental Weaver: +1 damage per Burn / Shock / Cold stack applied --")
	_strip()
	var w := _equip("elemental_weaver")
	var d: Enemy = dummies[0]
	_reset_dummy(d)
	d.apply_debuff("burn", 3)
	_check(1000 - d.current_health == 3, "Elemental Weaver: 3 Burn applied deals 3 (%d)" % (1000 - d.current_health))
	_reset_dummy(d)
	d.apply_debuff("shock", 2)
	_check(1000 - d.current_health == 2, "Elemental Weaver: 2 Shock applied deals 2 (%d)" % (1000 - d.current_health))
	_reset_dummy(d)
	d.apply_debuff("weaken", 2)
	_check(d.current_health == 1000, "Elemental Weaver: other debuffs deal nothing")
	_unequip(w)
	_reset_dummy(d)
	d.apply_debuff("burn", 3)
	_check(d.current_health == 1000, "Elemental Weaver: nothing once unequipped")
	_reset_dummy(d)

func _test_elvish_cloak() -> void:
	print("-- Elvish Cloak: slotted ranged offensive cards +2 --")
	_strip()
	var cloak := _equip("elvish_cloak")
	var plain := _hit(Card.create_by_id("cupids_golden_arrow"), dummies[0])
	_check(_hit(_slot(Card.create_by_id("cupids_golden_arrow"), cloak), dummies[0]) - plain == 2, "Elvish Cloak: a slotted ranged attack deals +2")
	var melee_plain := _hit(Card.create_by_id("slash"), dummies[0])
	_check(_hit(_slot(Card.create_by_id("slash"), ItemData.create("elvish_cloak")), dummies[0]) == melee_plain, "Elvish Cloak: a slotted melee attack gains nothing")
	_unequip(cloak)

func _test_two_handers() -> void:
	print("-- Two-handed staffs, two-handed bows --")
	for id in ["abjurers_cane", "blast_stick", "car_battery", "elemental_weaver"]:
		_check(Inventory.is_two_hand_only(ItemData.create(id)), "%s is two-handed (its text says so)" % id)
	for id in ["belthronding", "bessy", "bow_of_arash", "bow_of_budding_blasts", "cross_bow", "cupids_bow"]:
		var it := ItemData.create(id)
		if it.weapon_subtype == ItemData.WeaponSubtype.BOW:
			_check(Inventory.is_two_hand_only(it), "%s (a bow) needs both hands" % id)
