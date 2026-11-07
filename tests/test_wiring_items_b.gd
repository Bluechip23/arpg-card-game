extends SceneTree

## Phase 2 wiring audit, items slice B (docs/audit/wiring/items_b.md): 63
## items from Emerald to Ring of Stone Hide. Boots main.tscn as the dojo and
## equips every item through the real Inventory, so the stat block, the
## granted cards and each described rider run through the game's own code.
##  - Every item: the stat tokens in its description ("+6 STR", "+25 life",
##    "+125 mana", "+1 hand size", "5% resistance") land on the wearer and
##    leave with the item; its granted cards reach the deck and leave too.
##  - Then each item's described behaviour, one check per claim.
## Run: godot --headless --path . --script tests/test_wiring_items_b.gd

const SLICE := ["emerald", "equator", "fallens_wrath", "fanned_bracers", "feathered_hat",
	"feral_evocation", "fire_book", "fire_quiver", "frankensteins_screws", "friendship_ring",
	"frost_book", "frost_quiver", "gauntlets_of_dungeon_mastering", "girdle_of_aphrodite",
	"gold_band", "gravity_gauntlets", "guardian_greaves", "hallowed_trunk", "hammer_of_ajax",
	"hannibals_mask", "harnessed_sun", "heal_stone", "hermes_boots", "hide_of_garmr", "holster",
	"horned_nasal_helm", "houdinis_slippers", "ice_orb", "jordan_1s", "kettle_hat",
	"knife_toed_boots", "laurentius_lost_spear", "leather_belt", "leather_boots", "leather_cap",
	"leather_gauntlets", "legend_has_it", "lions_halberd", "long_bow", "magic_staff", "mail_coif",
	"mane_of_narashimha", "marvolo_gaunt", "mauls_sabre", "medic_wraps", "megingjord",
	"mits_of_chingiz", "momentum_mits", "monocle", "mountain_boots", "nine_ruins_of_sanguine",
	"orions_belt", "pick", "pocket_knife", "poseidons_trident", "potion_belt", "presence_of_mind",
	"quiver_of_wet_stones", "reaction_rod", "reaper_scythe", "return_scroll", "ring_of_nibelung",
	"ring_of_stone_hide"]

var failures := 0
var main = null
var stats = null
var dm = null
var bm = null
var inv = null
var dummies: Array = []

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Wiring audit: items B ===")
	_run()

func _settle(frames: int = 6) -> void:
	for _i in range(frames):
		await process_frame

func _run() -> void:
	TempoManager.preferred_swing_hold = 0
	main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	await _settle()
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	stats = main.player.get_stats()
	dm = main.deck_manager
	bm = main.player.get_buff_manager()
	inv = main.player.get_inventory()
	dummies = main.enemy_spawner.get_living_enemies()
	_check(dummies.size() >= 2, "the dojo has two dummies (%d)" % dummies.size())
	inv.enforce_mythic_limit = false
	inv._bulk_build_switch = true
	_strip()
	stats.max_health = 300
	stats.current_health = 300
	stats.equipment_crit_bonus = -100.0  # exact comparisons: no random crits
	for d in dummies:
		_reset_dummy(d)

	_test_stat_blocks()
	_test_granted_cards()
	_place_dummies()
	_test_flat_damage_riders()
	_test_elemental_riders()
	_test_weapon_riders()
	_test_crit_riders()
	_test_control_riders()
	_test_self_riders()
	_test_summon_and_stealth_riders()
	_test_cost_riders()
	_test_ring_zaps()
	_test_ring_bespoke()
	_test_cycle_passives()
	_test_armor_clocks()
	_test_gauntlet_skills()
	_test_bespoke_weapons()
	_test_misc_items()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

# ------------------------------------------------------------------ helpers

func _reset_dummy(d: Enemy) -> void:
	d.max_health = 1000
	d.current_health = 1000
	d.current_armor = 0
	d.damage_resistances = {}
	for k in ["burn_stacks", "cold_stacks", "poison_stacks", "shock_stacks", "bleed_stacks",
			"vulnerable_stacks", "weaken_stacks", "slow_stacks", "rooted_tempo", "taunt_tempo",
			"void_resistance_percent", "missing_life_damage_rate"]:
		if k in d:
			d.set(k, 0)
	d.taunt_target = null

## Take every piece off, so each item is measured alone.
func _strip() -> void:
	for t in [ItemData.ItemType.HELM, ItemData.ItemType.CHEST, ItemData.ItemType.RING,
			ItemData.ItemType.BELT, ItemData.ItemType.BOOTS, ItemData.ItemType.GAUNTLETS,
			ItemData.ItemType.WEAPON]:
		for i in range(inv._get_max_slots(t)):
			if inv.get_equipped_item(t, i) != null:
				inv.unequip_item(t, i)

## Equip a fresh copy of `id` in its first slot (main hand for hand items).
func _equip(id: String) -> ItemData:
	var item := ItemData.create(id)
	var ok: bool = inv.equip_item(item, 0)
	_check(ok, "%s equips through the Inventory (%s)" % [id, inv.last_refusal])
	return item

func _unequip(item: ItemData) -> void:
	var arr: Array = inv._get_slot_array(item.item_type)
	var idx := arr.find(item)
	if idx >= 0:
		inv.unequip_item(item.item_type, idx)

## Slot a card into an item's first bonus slot (as the slot panel does).
func _slot(card: Card, item: ItemData) -> Card:
	card.slotted_in_item = item
	item.slotted_cards.append(card)
	return card

func _snapshot() -> Dictionary:
	return {
		"STR": stats.base_strength, "DEX": stats.base_dexterity, "INT": stats.base_intelligence,
		"WIS": stats.base_wisdom, "AGI": stats.base_agility, "DET": stats.determination,
		"health": stats.max_health, "mana": stats.max_mana, "hand": stats.equipment_hand_bonus,
		"resist": stats.equipment_resistance_bonus, "crit": stats.equipment_crit_bonus,
		"heals": stats.healing_bonus, "block": stats.equipment_defense_card_block,
	}

## The stat tokens an item's description promises: {"STR": 6, "health": 25, ...}.
## Only the item's own sentence is read — a granted card's text ("gain 10 STR")
## carries no sign and is skipped, and an "Upgraded:" tail is cut.
static func _promised(desc: String) -> Dictionary:
	var text := desc.split("Upgraded:")[0]
	var out := {}
	var re := RegEx.new()
	re.compile("(?<![\\w%])([+-]\\d+) (STR|DEX|INT|WIS|AGI|DET)\\b")
	for m in re.search_all(text):
		out[m.get_string(2)] = int(m.get_string(1))
	re.compile("(?<![\\w%])([+-]\\d+) (health|life)\\b")
	for m in re.search_all(text):
		out["health"] = int(m.get_string(1))
	re.compile("^\\+(\\d+) mana\\.")
	var mm := re.search(text)
	if mm:
		out["mana"] = int(mm.get_string(1))
	re.compile("\\+(\\d+) mana[,.]")
	if not out.has("mana"):
		mm = re.search(text)
		if mm and text.find(mm.get_string(0)) < 40:
			out["mana"] = int(mm.get_string(1))
	re.compile("\\+(\\d+) hand size")
	mm = re.search(text)
	if mm:
		out["hand"] = int(mm.get_string(1))
	re.compile("(\\d+)% resistance to all damage")
	mm = re.search(text)
	if mm and not text.contains("stone skin"):
		out["resist"] = float(mm.get_string(1))
	re.compile("\\+(\\d+)% crit chance")
	mm = re.search(text)
	if mm:
		out["crit"] = float(mm.get_string(1))
	re.compile("\\+(\\d+) to heals")
	mm = re.search(text)
	if mm:
		out["heals"] = int(mm.get_string(1))
	re.compile("\\+(\\d+) block on block-applying cards")
	mm = re.search(text)
	if mm:
		out["block"] = int(mm.get_string(1))
	return out

# ---------------------------------------------------------------- stat blocks

func _test_stat_blocks() -> void:
	print("-- Every item: the described stat block lands and leaves --")
	for id in SLICE:
		var proto := ItemData.create(id)
		_check(proto != null, "%s loads from data/items" % id)
		if proto == null or proto.special_id != "":
			continue
		var want := _promised(proto.description)
		_strip()
		var before := _snapshot()
		var item := _equip(id)
		var after := _snapshot()
		var keys := ["STR", "DEX", "INT", "WIS", "AGI", "DET", "health", "mana", "hand", "resist", "crit", "heals", "block"]
		var bad: Array = []
		for k in keys:
			var got = after[k] - before[k]
			var expect = want.get(k, 0)
			if absf(float(got) - float(expect)) > 0.001:
				bad.append("%s %s (text %s)" % [k, str(got), str(expect)])
		_check(bad.is_empty(), "%s: equipping gives exactly the described stats %s" % [id, str(bad)])
		_unequip(item)
		var back := _snapshot()
		var left: Array = []
		for k in keys:
			if absf(float(back[k]) - float(before[k])) > 0.001:
				left.append(k)
		_check(left.is_empty(), "%s: unequipping takes them all back %s" % [id, str(left)])
	_strip()

func _all_zones() -> Array:
	var out: Array = []
	out.append_array(dm.draw_pile)
	out.append_array(dm.hand)
	out.append_array(dm.discard_pile)
	out.append_array(dm.jail_pile)
	out.append_array(dm.maintained_cards)
	return out

func _test_granted_cards() -> void:
	print("-- Granted cards reach the deck with the item and leave with it --")
	for id in SLICE:
		var proto := ItemData.create(id)
		if proto == null or proto.granted_card_ids.is_empty():
			continue
		_strip()
		var item := _equip(id)
		var zones := _all_zones()
		var found: Array = []
		for c in zones:
			if c.granted_by_item == item:
				found.append(c.card_id)
		var want: Array = Array(proto.granted_card_ids)
		found.sort()
		want.sort()
		_check(found == want, "%s: granted %s are in the deck (%s)" % [id, str(want), str(found)])
		_unequip(item)
		var stray := 0
		for c in _all_zones():
			if c.granted_by_item == item:
				stray += 1
		_check(stray == 0, "%s: its granted cards leave the deck when unequipped (%d left)" % [id, stray])
	_strip()

# ---------------------------------------------------------------- play path

func _pcell() -> Vector2i:
	return main.grid_manager.world_to_grid(main.player.position)

func _place(who, cell: Vector2i) -> void:
	who.position = main._ground_pos(cell)
	if "target_position" in who:
		who.target_position = who.position

## Dummy 0 stands beside the player (melee), dummy 1 three squares east.
func _place_dummies() -> void:
	_place(dummies[0], _pcell() + Vector2i(1, 0))
	_place(dummies[1], _pcell() + Vector2i(3, 0))
	for d in dummies:
		_reset_dummy(d)

## Play `card` the way the player does: into the hand, selected, played on
## `target`, then the tempo clock ticked until it has resolved.
func _play(card: Card, target) -> bool:
	if not (card in dm.hand):
		dm.hand.append(card)
	stats.current_mana = stats.max_mana
	main.select_card(dm.hand.find(card))
	if main.selected_card_index < 0:
		return false
	main.play_selected_card(target)
	var guard := 0
	while (main._pending_resolve_queue.size() > 0 or main.tempo_manager.is_ticking()) and guard < 200:
		if main.tempo_manager.is_ticking():
			main.tempo_manager._process_one_tick()
		else:
			await process_frame
		guard += 1
	return true

## Resolve `card` on `target` through main's own resolution step (the one
## the tempo clock calls when the card's tick comes): executor, riders and
## world effects, without spending the clock — so a cycle boundary cannot
## tick a stack off before it is read.
func _resolve(card: Card, target) -> void:
	main._pending_resolve_queue.append({"card": card, "target": target, "owner_index": 0,
		"data": {"hit_landing": true, "anim_played": true}})
	main._resolve_queued_card(card)

## Damage a resolved card does to dummy `d` (reset first).
func _dmg(card: Card, d: Enemy) -> int:
	_reset_dummy(d)
	# The free-hand stance echoes every 12th attack: keep the count clear so
	# one measured play is one blow.
	stats._free_hand_attack_count = 0
	stats._pending_free_hand_echo = false
	_resolve(card, d)
	return 1000 - d.current_health

## A copy of `card_id` in one of `item`'s bonus slots.
func _slotted(card_id: String, item: ItemData) -> Card:
	var card := Card.create_by_id(card_id)
	if not item.slot_card(card):
		# The slot's label gate refuses this card: seat it in the next bonus
		# slot by hand (the rider logic does not care how it got there).
		card.set_meta("slot_color_index", item._next_free_slot_index())
		item.slotted_cards.append(card)
		card.slotted_in_item = item
	return card

func _clear_slots(item: ItemData) -> void:
	for c in item.slotted_cards:
		c.slotted_in_item = null
		if c.has_meta("slot_color_index"):
			c.remove_meta("slot_color_index")
	item.slotted_cards.clear()

# ------------------------------------------------------- on-self damage riders

func _test_flat_damage_riders() -> void:
	print("-- On-self: cards that deal damage deal +N --")
	var plain: int = _dmg(Card.create_by_id("slash"), dummies[0])
	_check(plain > 0, "a plain Slash lands (%d)" % plain)
	for row in [["leather_belt", 1], ["holster", 2], ["pick", 5], ["lions_halberd", 10],
			["fire_quiver", 2], ["frost_quiver", 1], ["quiver_of_wet_stones", 2], ["long_bow", 2]]:
		_strip()
		var item := _equip(row[0])
		# The baseline is taken with the item on (its STR scales the hit too).
		var worn: int = _dmg(Card.create_by_id("slash"), dummies[0])
		var got: int = _dmg(_slotted("slash", item), dummies[0])
		_check(got == worn + int(row[1]), "%s: a slotted damaging card deals +%d (%d vs %d)" % [row[0], row[1], got, worn])
	_strip()
	# Feathered Hat: +5 on a damaging card.
	var hat := _equip("feathered_hat")
	var hat_dmg: int = _dmg(_slotted("slash", hat), dummies[0])
	_check(hat_dmg == plain + 5, "feathered_hat: a slotted damaging card deals +5 (%d vs %d)" % [hat_dmg, plain])
	_strip()

func _test_elemental_riders() -> void:
	print("-- On-self: offensive cards that hit apply Burn / Cold / Bleed --")
	var d: Enemy = dummies[0]
	for row in [["equator", "burn_stacks", 4], ["fire_quiver", "burn_stacks", 1],
			["frost_quiver", "cold_stacks", 1], ["horned_nasal_helm", "bleed_stacks", 1]]:
		_strip()
		var item := _equip(row[0])
		_reset_dummy(d)
		_resolve(_slotted("slash", item), d)
		_check(int(d.get(row[1])) == int(row[2]), "%s: a slotted Slash that hits applies %d %s (%d)" % [row[0], row[2], row[1], int(d.get(row[1]))])
		_reset_dummy(d)
		_resolve(_slotted("block", item), main.player)
		_check(int(d.get(row[1])) == 0, "%s: a slotted non-offensive card applies none" % row[0])
	_strip()
	# Frost Quiver: any slotted card gains you 2 armor.
	var fq := _equip("frost_quiver")
	stats.current_armor = 0
	_resolve(_slotted("draw", fq), main.player)
	_check(stats.current_armor == 2, "frost_quiver: a slotted Draw gains you 2 armor (%d)" % stats.current_armor)
	stats.current_armor = 0
	_strip()
	# Quiver of Wet Stones: offensive cards deal 4 more to armor.
	var ws := _equip("quiver_of_wet_stones")
	var plain_d: Enemy = dummies[1]
	_reset_dummy(plain_d)
	plain_d.current_armor = 50
	_resolve(Card.create_by_id("slash"), plain_d)
	var plain_left: int = plain_d.current_armor
	_reset_dummy(d)
	d.current_armor = 50
	_resolve(_slotted("slash", ws), d)
	# The slotted Slash also hits 2 harder (its +2 damage rider), which the
	# armor eats first: 4 shred + 2 extra damage = 6 more armor gone.
	_check(plain_left - d.current_armor == 6, "quiver_of_wet_stones: a slotted hit strips 4 extra armor on top of its +2 (%d vs %d)" % [d.current_armor, plain_left])
	_reset_dummy(d)
	_reset_dummy(plain_d)
	_strip()

func _test_weapon_riders() -> void:
	print("-- Spell weapons: every damaging offensive card --")
	var d: Enemy = dummies[0]
	var plain: int = _dmg(Card.create_by_id("slash"), d)
	for row in [["fire_book", "burn_stacks", 1, 1], ["frost_book", "cold_stacks", 1, 1],
			["ice_orb", "cold_stacks", 2, 2], ["magic_staff", "", 0, 4], ["reaper_scythe", "vulnerable_stacks", 1, -1]]:
		_strip()
		_equip(row[0])
		# Unslotted: the weapon's rider covers every damaging offensive card.
		var got: int = _dmg(Card.create_by_id("slash"), d)
		if int(row[3]) >= 0:
			_check(got == plain + int(row[3]), "%s: an unslotted Slash deals +%d (%d vs %d)" % [row[0], row[3], got, plain])
		if row[1] != "":
			_check(int(d.get(row[1])) == int(row[2]), "%s: an unslotted Slash applies %d %s (%d)" % [row[0], row[2], row[1], int(d.get(row[1]))])
			_reset_dummy(d)
			_resolve(Card.create_by_id("block"), main.player)
			_check(int(d.get(row[1])) == 0, "%s: a defense card applies nothing" % row[0])
	_strip()
	_reset_dummy(d)

## The crit riders live only while the slotted card resolves: read them at
## the moment the blow lands (the enemy's `damaged` signal).
var _seen_crit_chance := 0.0
var _seen_crit_dmg := 0.0
var _seen_melee_bonus := -1

func _watch_hit(_amount: int) -> void:
	_seen_crit_chance = stats.temp_on_self_crit_bonus
	_seen_crit_dmg = stats.temp_crit_damage_bonus
	_seen_melee_bonus = stats.equipment_melee_crit_bonus if stats.resolving_melee_offensive else 0

func _test_crit_riders() -> void:
	print("-- Crit riders: Feathered Hat, Monocle, Knife Toed Boots --")
	var d: Enemy = dummies[1]
	_reset_dummy(d)
	d.damaged.connect(_watch_hit)
	var hat := _equip("feathered_hat")
	_resolve(_slotted("slash", hat), d)
	_check(is_equal_approx(_seen_crit_dmg, 0.10), "feathered_hat: a slotted card resolves with +10%% crit damage (%.2f)" % _seen_crit_dmg)
	_check(stats.temp_crit_damage_bonus == 0.0, "feathered_hat: the +10% crit damage ends with the card")
	stats.flash_crit_accum = 10
	stats.flash_crit_armed = false
	_resolve(_slotted("draw", hat), main.player)
	_check(stats.flash_crit_accum == 8, "feathered_hat: any slotted card takes 2 off the flash counter (%d)" % stats.flash_crit_accum)
	stats.flash_crit_accum = 0
	stats.current_flash_points = 30
	stats.spend_flash_points(24)
	_check(not stats.flash_crit_armed, "feathered_hat: 24 flash spent does not arm the crit")
	stats.spend_flash_points(1)
	_check(stats.flash_crit_armed and stats.flash_crit_accum == 0, "feathered_hat: the 25th flash point arms a crit and resets the counter")
	_resolve(Card.create_by_id("slash"), dummies[0])
	_check(stats.flash_crit_armed, "feathered_hat: a melee card leaves the armed crit waiting")
	_seen_crit_chance = 0.0
	_resolve(Card.create_by_id("dagger_throw"), d)
	_check(_seen_crit_chance >= 100.0 and not stats.flash_crit_armed, "feathered_hat: the next ranged offensive card crits and spends it (%.0f)" % _seen_crit_chance)
	_strip()
	var mono := _equip("monocle")
	var ranged := _slotted("dagger_throw", mono)
	var melee := _slotted("slash", mono)
	_check(main._helm_range_bonus(ranged) == 5, "monocle: a slotted ranged offensive card gains +5 range (%d)" % main._helm_range_bonus(ranged))
	_check(main._helm_range_bonus(melee) == 0, "monocle: a slotted melee card gains none (%d)" % main._helm_range_bonus(melee))
	_seen_crit_chance = 0.0
	_resolve(ranged, d)
	_check(is_equal_approx(_seen_crit_chance, 25.0), "monocle: a slotted ranged offensive card resolves with +25%% crit (%.0f)" % _seen_crit_chance)
	_seen_crit_chance = 0.0
	_resolve(Card.create_by_id("slash"), dummies[0])
	_check(_seen_crit_chance == 0.0, "monocle: an unslotted card gets no crit rider")
	# A card in the Monocle's plain slot carries none of its riders.
	_clear_slots(mono)
	_slotted("quick_shot", mono)
	var plain_slot := _slotted("dagger_throw", mono)
	_check(mono.is_vanilla_slot(plain_slot) and main._helm_range_bonus(plain_slot) == 0,
		"monocle: a card in its plain slot gains no range (%d)" % main._helm_range_bonus(plain_slot))
	_strip()
	var bow := _equip("long_bow")
	_check(main._helm_range_bonus(_slotted("trick_shot", bow)) == 2, "long_bow: a slotted offensive card gains +2 range")
	_strip()
	# Knife Toed Boots: a melee offensive crit adds a flat 10.
	_equip("knife_toed_boots")
	_seen_melee_bonus = -1
	_resolve(Card.create_by_id("slash"), d)
	_check(_seen_melee_bonus == 10, "knife_toed_boots: a melee offensive card resolves with the flat +10 crit rider (%d)" % _seen_melee_bonus)
	_seen_melee_bonus = -1
	_resolve(Card.create_by_id("dagger_throw"), d)
	_check(_seen_melee_bonus == 0, "knife_toed_boots: a ranged card does not (%d)" % _seen_melee_bonus)
	stats.resolving_melee_offensive = true
	var mult: float = stats.get_crit_damage_multiplier()
	_check(Card.crit_multiply(20, stats) == floori(20 * mult) + 10, "knife_toed_boots: a melee crit lands the multiplied hit +10")
	stats.resolving_melee_offensive = false
	_check(Card.crit_multiply(20, stats) == floori(20 * mult), "knife_toed_boots: a non-melee crit gets no +10")
	_strip()
	d.damaged.disconnect(_watch_hit)
	_reset_dummy(d)

func _test_control_riders() -> void:
	print("-- Girdle (taunt / support heal), Gravity Gauntlets (hold) --")
	var d: Enemy = dummies[0]
	var girdle := _equip("girdle_of_aphrodite")
	_reset_dummy(d)
	_resolve(_slotted("slash", girdle), d)
	_check(d.taunt_tempo == 15 and d.taunt_target == main.player, "girdle_of_aphrodite: a slotted offensive card Taunts its target for 15 tempo (%d)" % d.taunt_tempo)
	stats.current_health = 100
	_resolve(_slotted("block", girdle), main.player)
	_check(stats.current_health == 100 + stats.get_effective_heal_amount(15), "girdle_of_aphrodite: a slotted defense card heals its target 15 (%d)" % stats.current_health)
	stats.current_health = stats.max_health
	_strip()
	var gg := _equip("gravity_gauntlets")
	_reset_dummy(d)
	_resolve(_slotted("slash", gg), d)
	_check(d.rooted_tempo == 5, "gravity_gauntlets: a slotted offensive card holds the target 5 tempo (%d)" % d.rooted_tempo)
	_reset_dummy(d)
	_resolve(_slotted("block", gg), main.player)
	_check(d.rooted_tempo == 0, "gravity_gauntlets: a non-offensive card holds nothing")
	_strip()
	_reset_dummy(d)

func _test_self_riders() -> void:
	print("-- Hammer of Ajax, Hannibals Mask, Presence of Mind, Hermes Boots --")
	var d: Enemy = dummies[0]
	var ham := _equip("hammer_of_ajax")
	var worn: int = _dmg(Card.create_by_id("slash"), d)
	var got: int = _dmg(_slotted("slash", ham), d)
	_check(got == worn + floori(stats.max_health * 0.10), "hammer_of_ajax: a slotted offensive card adds 10%% of max health (%d vs %d, max %d)" % [got, worn, stats.max_health])
	_strip()
	var mask := _equip("hannibals_mask")
	stats.current_health = 100
	var dealt: int = _dmg(Card.create_by_id("slash"), d)
	_check(stats.current_health == 100, "hannibals_mask: an unslotted attack drinks nothing (%d)" % stats.current_health)
	dealt = _dmg(_slotted("slash", mask), d)
	var want_heal: int = stats.get_effective_heal_amount(maxi(1, floori(dealt * 0.15)))
	_check(stats.current_health == 100 + want_heal, "hannibals_mask: a slotted attack heals 15%% of its %d damage (%d)" % [dealt, stats.current_health - 100])
	stats.current_health = 100
	_dmg(_slotted("fireball", mask), d)
	_check(stats.current_health == 100, "hannibals_mask: a slotted spell is not an Attack card — no lifesteal (%d)" % stats.current_health)
	stats.current_health = stats.max_health
	_strip()
	var pom := _equip("presence_of_mind")
	var pom_bonus: int = floori(stats.max_mana * 0.10)
	stats.current_armor = 0
	_resolve(Card.create_by_id("block"), main.player)
	var plain_block: int = stats.current_armor
	stats.current_armor = 0
	_resolve(_slotted("block", pom), main.player)
	_check(stats.current_armor == plain_block + pom_bonus, "presence_of_mind: a slotted Block gains 10%% of max mana as extra block (%d vs %d + %d)" % [stats.current_armor, plain_block, pom_bonus])
	stats.current_armor = 0
	_resolve(_slotted("draw", pom), main.player)
	_check(stats.current_armor == pom_bonus, "presence_of_mind: any card gets it (a slotted Draw: %d)" % stats.current_armor)
	stats.current_armor = 0
	_strip()
	var hermes := _equip("hermes_boots")
	stats.current_flash_points = 0
	_resolve(_slotted("draw", hermes), main.player)
	_check(stats.current_flash_points == 1, "hermes_boots: any slotted card restores 1 flash point (%d)" % stats.current_flash_points)
	_check(is_equal_approx(stats.equipment_trap_damage_percent, 25.0), "hermes_boots: traps deal 25% more")
	_strip()
	_reset_dummy(d)

func _test_summon_and_stealth_riders() -> void:
	print("-- Dungeon Mastering wolves, Houdini's invisibility, Momentum draw --")
	var gdm := _equip("gauntlets_of_dungeon_mastering")
	main._clear_wolves()
	for i in range(4):
		_resolve(_slotted("draw", gdm), main.player)
		_clear_slots(gdm)
	_check(main._wolves.size() == 3, "gauntlets_of_dungeon_mastering: any slotted card summons a wolf, up to a pack of 3 (%d)" % main._wolves.size())
	if main._wolves.size() > 0:
		var w = main._wolves[0]
		_check(w.max_health == 20 and w.ATTACK_INTERVAL == 5 and w.MOVE_INTERVAL == 3 and w.MOVE_STEPS == 2,
			"gauntlets_of_dungeon_mastering: a wolf has 20 HP, attacks every 5 tempo, moves 2 per 3 tempo")
	main._clear_wolves()
	# A card in a plain slot carries no rider: no wolf.
	_slotted("draw", gdm)
	var plain_card := _slotted("draw", gdm)
	_check(gdm.is_vanilla_slot(plain_card), "gauntlets_of_dungeon_mastering: the second card sits in a plain slot")
	_resolve(plain_card, main.player)
	_check(main._wolves.size() == 0, "gauntlets_of_dungeon_mastering: a plain-slot card summons no wolf (%d)" % main._wolves.size())
	main._clear_wolves()
	_strip()
	var hs := _equip("houdinis_slippers")
	bm.remove_buff(Buff.BuffType.INVISIBLE)
	_resolve(_slotted("draw", hs), main.player)
	var inv_buff = bm.get_buff(Buff.BuffType.INVISIBLE)
	_check(inv_buff != null and inv_buff.duration == 5, "houdinis_slippers: any slotted card makes you invisible for 5 tempo (%s)" % str(inv_buff.duration if inv_buff else -1))
	bm.remove_buff(Buff.BuffType.INVISIBLE)
	main._set_player_invisible(false)
	_clear_slots(hs)
	_slotted("draw", hs)
	var hs_plain := _slotted("draw", hs)
	_resolve(hs_plain, main.player)
	_check(bm.get_buff(Buff.BuffType.INVISIBLE) == null, "houdinis_slippers: a plain-slot card does not")
	bm.remove_buff(Buff.BuffType.INVISIBLE)
	main._set_player_invisible(false)
	_strip()
	var mm := _equip("momentum_mits")
	dm.hand.clear()
	for i in range(5):
		dm.draw_pile.append(Card.create_by_id("block"))
	_resolve(_slotted("block", mm), main.player)
	_check(dm.hand.size() == 1, "momentum_mits: any slotted card draws you a card (hand %d)" % dm.hand.size())
	dm.hand.clear()
	_strip()

func _test_cost_riders() -> void:
	print("-- Potion Belt tempo refund, Megingjord mana doubling --")
	var pb := _equip("potion_belt")
	var pot := _slotted("healing_potion", pb)
	_check(pot.get_burden_tempo_cost() == Card.create_by_id("healing_potion").get_burden_tempo_cost() - 1,
		"potion_belt: a slotted utility card costs 1 less tempo (%d)" % pot.get_burden_tempo_cost())
	var blk := _slotted("block", pb)
	_check(blk.get_burden_tempo_cost() == Card.create_by_id("block").get_burden_tempo_cost(), "potion_belt: a slotted defense card does not")
	_strip()
	var meg := _equip("megingjord")
	var plain_cost: int = int(dm.compute_play_cost(Card.create_by_id("slash"), 0)["mana"])
	var slotted_cost: int = int(dm.compute_play_cost(_slotted("slash", meg), 0)["mana"])
	_check(slotted_cost == plain_cost * 2, "megingjord: a slotted card costs double mana (%d vs %d)" % [slotted_cost, plain_cost])
	_clear_slots(meg)
	var draw_cost: int = int(dm.compute_play_cost(_slotted("healing_potion", meg), 0)["mana"])
	_check(draw_cost == Card.create_by_id("healing_potion").mana_cost * 2, "megingjord: any card, not only damaging ones (%d)" % draw_cost)
	_strip()

# ---------------------------------------------------------------- rings

func _dummy_loss() -> int:
	var lost := 0
	for d in dummies:
		lost += 1000 - d.current_health
	return lost

func _reset_dummies() -> void:
	for d in dummies:
		_reset_dummy(d)

func _test_ring_zaps() -> void:
	print("-- Heal Stone / Gold Band / Emerald: 2 damage to a random enemy within 5 --")
	_place_dummies()
	var em := _equip("emerald")
	dummies[1].apply_debuff("poison", 4)
	_check(_dummy_loss() == 0, "emerald: 4 Poison applied — no zap yet")
	dummies[1].apply_debuff("poison", 1)
	_check(_dummy_loss() == 2, "emerald: the 5th Poison zaps an enemy within 5 for 2 (%d)" % _dummy_loss())
	_strip()
	_reset_dummies()
	_equip("gold_band")
	stats.add_armor(4)
	_check(_dummy_loss() == 0, "gold_band: 4 shield gained — no zap yet")
	stats.add_armor(6)
	_check(_dummy_loss() == 4, "gold_band: 10 shield gained -> two zaps of 2 (%d)" % _dummy_loss())
	stats.current_armor = 0
	_strip()
	_reset_dummies()
	_equip("heal_stone")
	stats.current_health = 100
	stats.heal(5)
	_check(_dummy_loss() == 2, "heal_stone: a heal of 5+ zaps an enemy for 2 (%d)" % _dummy_loss())
	_reset_dummies()
	var hs = inv.equipped_rings[0]
	var banked: int = int(hs.ring_counters.get("heal", 0))
	stats.current_health = 100
	stats.apply_life_steal(10)
	_check(int(hs.ring_counters.get("heal", 0)) == banked and _dummy_loss() == 0, "heal_stone: lifesteal does not count")
	bm.apply_buff(Buff.create_regen(10, 15, "test"))
	bm.process_turn_start()
	_check(int(hs.ring_counters.get("heal", 0)) == banked and _dummy_loss() == 0, "heal_stone: regen does not count")
	bm.remove_buff(Buff.BuffType.REGEN)
	stats.current_health = stats.max_health
	_strip()
	# Out of reach: an enemy 6+ squares away is never zapped.
	_reset_dummies()
	_place(dummies[0], _pcell() + Vector2i(7, 0))
	_place(dummies[1], _pcell() + Vector2i(0, 8))
	_equip("heal_stone")
	stats.current_health = 100
	stats.heal(5)
	_check(_dummy_loss() == 0, "heal_stone: enemies beyond 5 squares are not zapped (%d)" % _dummy_loss())
	stats.current_health = stats.max_health
	_strip()
	_place_dummies()

func _test_ring_bespoke() -> void:
	print("-- Harnessed Sun, Stone Hide, Nibelung, Marvolo, Friendship, Legend --")
	var d: Enemy = dummies[1]
	_reset_dummy(d)
	_equip("harnessed_sun")
	d.apply_debuff("burn", 1)
	_check(d.burn_stacks == 3, "harnessed_sun: a 1-Burn application lands as 3 (+2) (%d)" % d.burn_stacks)
	var sun = inv.equipped_rings[0]
	_check(int(sun.ring_counters.get("burn", 0)) == 3, "harnessed_sun: all 3 count toward the 25 (%d)" % int(sun.ring_counters.get("burn", 0)))
	var pdm = main.player.get_debuff_manager()
	pdm.clear_all_debuffs()
	pdm.apply_debuff(Debuff.create(Debuff.DebuffType.SLOWED, 1, 15))
	for i in range(7):
		d.apply_debuff("burn", 1)  # 3 counted each: 3 + 21 = 24
	_check(pdm.debuffs.size() == 1, "harnessed_sun: 24 Burn applied — your debuff stays")
	d.apply_debuff("burn", 1)
	_check(pdm.debuffs.size() == 0, "harnessed_sun: the 25th Burn cleanses a debuff on you (%d left)" % pdm.debuffs.size())
	_strip()
	_reset_dummy(d)
	# Ring of Stone Hide: +4 block on block cards; 100 block -> stone skin.
	stats.current_armor = 0
	_resolve(Card.create_by_id("block"), main.player)
	var plain_block: int = stats.current_armor
	_equip("ring_of_stone_hide")
	stats.current_armor = 0
	_resolve(Card.create_by_id("block"), main.player)
	_check(stats.current_armor == plain_block + 4, "ring_of_stone_hide: a Block gives +4 (%d vs %d)" % [stats.current_armor, plain_block])
	bm.remove_buff(Buff.BuffType.RESILIENT)
	stats.current_armor = 0
	stats.add_armor(100)
	var rb = bm.get_buff(Buff.BuffType.RESILIENT)
	_check(rb != null and rb.value == 10 and rb.duration == 15, "ring_of_stone_hide: 100 block gained -> 10%% resistance for 15 tempo (%s)" % (str([rb.value, rb.duration]) if rb else "none"))
	bm.remove_buff(Buff.BuffType.RESILIENT)
	stats.current_armor = 0
	_strip()
	# Ring of Nibelung: after 5 heals, the Curse carries the healed total.
	_equip("ring_of_nibelung")
	dm.hand.clear()
	var total := 0
	for i in range(5):
		stats.current_health = 100
		stats.heal(4)
		total += stats.current_health - 100
	var curse: Card = null
	for c in dm.hand:
		if c.card_id == "the_nibelung_curse":
			curse = c
	_check(curse != null and int(curse.get_meta("curse_value", 0)) == total,
		"ring_of_nibelung: the 5th heal brings the Curse carrying the healed total %d (%s)" % [total, str(curse.get_meta("curse_value", 0)) if curse else "none"])
	_check(curse != null and curse.mana_cost == 70 and curse.tempo_cost == 5 and curse.erase_on_play,
		"ring_of_nibelung: the Curse costs 70 mana, 5 tempo and is erased")
	for i in range(5):
		stats.current_health = 100
		stats.heal(4)
	var copies := 0
	for c in _all_zones():
		if c.card_id == "the_nibelung_curse":
			copies += 1
	_check(copies == 1, "ring_of_nibelung: only one copy can exist (%d)" % copies)
	dm.hand.clear()
	stats.current_health = stats.max_health
	_strip()
	# Marvolo Gaunt: the lethal blow, the heal, the Misunderstanding.
	var mg := _equip("marvolo_gaunt")
	pdm.clear_all_debuffs()
	stats.invulnerable_tempo = 0
	stats.current_armor = 0
	stats.current_health = 10
	stats.take_direct_damage(50)
	_check(stats.current_health == 1 + stats.get_effective_heal_amount(25), "marvolo_gaunt: a lethal blow leaves you at 1 and heals 25 (%d)" % stats.current_health)
	_check(stats.invulnerable_tempo == 3, "marvolo_gaunt: invulnerable for 3 tempo")
	var mis = null
	for db in pdm.debuffs:
		if db.debuff_type == Debuff.DebuffType.GENERIC and db.source_name == "Marvolo Gaunt":
			mis = db
	_check(mis != null and mis.value == 25 and mis.duration == 7, "marvolo_gaunt: Marvolo's Misunderstanding — 25 damage in 7 tempo")
	stats.invulnerable_tempo = 0
	var hp: int = stats.current_health
	pdm.advance_time(7)
	_check(stats.current_health == hp - 25, "marvolo_gaunt: left alone it lands for 25 (%d -> %d)" % [hp, stats.current_health])
	_check(int(mg.ring_counters.get("cd", 0)) == 50, "marvolo_gaunt: then a 50-tempo cooldown")
	# Purged before it lands: no damage.
	mg.ring_counters["cd"] = 0
	stats.current_health = 10
	stats.take_direct_damage(50)
	stats.invulnerable_tempo = 0
	hp = stats.current_health
	pdm.remove_debuff(Debuff.DebuffType.GENERIC)
	pdm.advance_time(10)
	_check(stats.current_health == hp, "marvolo_gaunt: purged, the Misunderstanding deals nothing")
	stats.current_health = stats.max_health
	_strip()
	# Friendship Ring: +5 to heals. Legend Has It: 5% resistance to all damage.
	stats.current_health = 100
	stats.heal(10)
	var plain_heal: int = stats.current_health - 100
	_equip("friendship_ring")
	stats.current_health = 100
	stats.heal(10)
	_check(stats.current_health - 100 == plain_heal + 5, "friendship_ring: heals are 5 larger (%d vs %d)" % [stats.current_health - 100, plain_heal])
	_strip()
	stats.current_health = 200
	stats.current_armor = 0
	stats.take_damage(100)
	var plain_hit: int = 200 - stats.current_health
	_equip("legend_has_it")
	stats.current_health = 200
	stats.current_armor = 0
	stats.take_damage(100)
	_check(200 - stats.current_health == plain_hit - 5, "legend_has_it: a 100 hit lands 5 lighter (%d vs %d)" % [200 - stats.current_health, plain_hit])
	stats.current_health = stats.max_health
	_strip()

# ------------------------------------------------------------ cycle passives

func _test_cycle_passives() -> void:
	print("-- Horned Nasal Helm, Mane, Jordan 1s, Frankenstein's Screws, Guardian Greaves --")
	var pdm = main.player.get_debuff_manager()
	_equip("horned_nasal_helm")
	main._purge_cycle_accum = 0
	pdm.clear_all_debuffs()
	pdm.apply_debuff(Debuff.create(Debuff.DebuffType.SLOWED, 1, 60))
	pdm.apply_debuff(Debuff.create(Debuff.DebuffType.BURN, 1, 60))
	pdm.apply_debuff(Debuff.create(Debuff.DebuffType.POISON, 1, 60))
	main._helm_on_cycle_passives()
	main._helm_on_cycle_passives()
	_check(pdm.debuffs.size() == 3, "horned_nasal_helm: 10 tempo in, nothing purged (%d)" % pdm.debuffs.size())
	main._helm_on_cycle_passives()
	_check(pdm.debuffs.size() == 1, "horned_nasal_helm: at 15 tempo 2 random debuffs are purged (%d left)" % pdm.debuffs.size())
	pdm.clear_all_debuffs()
	_strip()
	# Mane of Narashimha: enemies within 2 take 5% more from you.
	_place_dummies()
	_place(dummies[1], _pcell() + Vector2i(0, 2))  # 2 squares off
	_equip("mane_of_narashimha")
	var near: Enemy = dummies[0]
	var worn: int = _dmg(Card.create_by_id("lethal_poke") if false else Card.create_by_id("slash"), near)
	main._helm_on_cycle_passives()
	_check(near.void_resistance_percent == 5.0, "mane_of_narashimha: an enemy beside you is in the void aura")
	_check(dummies[1].void_resistance_percent == 5.0, "mane_of_narashimha: an enemy 2 squares off is in it too")
	var in_aura: int = 0
	near.current_health = 1000
	_resolve(Card.create_by_id("slash"), near)
	in_aura = 1000 - near.current_health
	_check(in_aura == floori(worn * 1.05), "mane_of_narashimha: your hit lands 5%% harder in the aura (%d vs %d)" % [in_aura, worn])
	_place(dummies[1], _pcell() + Vector2i(3, 0))
	main._helm_on_cycle_passives()
	_check(dummies[1].void_resistance_percent == 0.0, "mane_of_narashimha: 3 squares off, out of the aura")
	near.current_health = 1000
	near.take_damage(20, false)
	_check(1000 - near.current_health == 20, "mane_of_narashimha: only YOUR damage is raised (a non-player hit: %d)" % (1000 - near.current_health))
	_strip()
	main._helm_on_cycle_passives()
	_check(near.void_resistance_percent == 0.0, "mane_of_narashimha: unequipped, the aura is gone next cycle")
	# Jordan 1s: below 50% enemy health, +0.5 per missing %.
	_reset_dummies()
	_place_dummies()
	_equip("jordan_1s")
	main._helm_on_cycle_passives()
	near.current_health = 1000
	near.take_damage(10, true)
	_check(1000 - near.current_health == 10, "jordan_1s: at full health no bonus (%d)" % (1000 - near.current_health))
	near.current_health = 500
	near.take_damage(10, true)
	_check(500 - near.current_health == 10, "jordan_1s: at exactly 50%% no bonus — 'below 50%%' (%d)" % (500 - near.current_health))
	near.current_health = 400
	near.take_damage(10, true)
	_check(400 - near.current_health == 10 + 30, "jordan_1s: at 40%% a 10 hit gains 0.5 x 60 = 30 (%d)" % (400 - near.current_health))
	_strip()
	main._helm_on_cycle_passives()
	near.current_health = 400
	near.take_damage(10, true)
	_check(400 - near.current_health == 10, "jordan_1s: unequipped, no bonus after the next cycle")
	_reset_dummies()
	# Frankenstein's Screws: summons below 25% within 3 heal 3 per cycle.
	_equip("frankensteins_screws")
	main._clear_wolves()
	main._spawn_wolf()
	main._spawn_wolf()
	var low = main._wolves[0]
	var ok_wolf = main._wolves[1]
	low.health = 4
	ok_wolf.health = 10
	main._helm_on_cycle_passives()
	_check(low.health == 7, "frankensteins_screws: a summon below 25%% beside you heals 3 (%d)" % low.health)
	_check(ok_wolf.health == 10, "frankensteins_screws: one at 50%% is left alone (%d)" % ok_wolf.health)
	low.health = 4
	_place(low, _pcell() + Vector2i(0, 4))
	main._helm_on_cycle_passives()
	_check(low.health == 4, "frankensteins_screws: 4 squares away, no heal (%d)" % low.health)
	main._clear_wolves()
	_strip()
	# Guardian Greaves: 6 health and 60 mana a cycle to allies within 4, 5% physical resist inside.
	_equip("guardian_greaves")
	stats.current_health = 100
	stats.current_mana = 0
	main._spawn_wolf()
	var pup = main._wolves[0]
	pup.health = 5
	main._helm_on_cycle_passives()
	_check(stats.current_health == 100 + stats.get_effective_heal_amount(6), "guardian_greaves: you regain 6 health a cycle (%d)" % stats.current_health)
	_check(int(stats.current_mana) == mini(60, stats.max_mana), "guardian_greaves: and 60 mana, up to the pool (%d of max %d)" % [int(stats.current_mana), stats.max_mana])
	_check(stats.aura_physical_resist == 5.0, "guardian_greaves: and 5% physical resistance inside the aura")
	_check(pup.health == 11, "guardian_greaves: an ally summon within 4 regains 6 too (%d)" % pup.health)
	_strip()
	main._helm_on_cycle_passives()
	_check(stats.aura_physical_resist == 0.0, "guardian_greaves: off, the resistance leaves next cycle")
	main._clear_wolves()
	stats.current_health = stats.max_health
	stats.current_mana = stats.max_mana

func _test_armor_clocks() -> void:
	print("-- Kettle Hat / Mail Coif unerring armor, Hallowed Trunk regen --")
	for row in [["kettle_hat", 2], ["mail_coif", 5]]:
		var item := _equip(row[0])
		stats.unerring_armor = 0
		inv.process_turn()
		inv.process_turn()
		_check(stats.unerring_armor == 0, "%s: 10 tempo in, no armor yet" % row[0])
		inv.process_turn()
		_check(stats.unerring_armor == mini(int(row[1]), stats.get_unerring_cap()), "%s: at 15 tempo, +%d unerring armor (%d)" % [row[0], row[1], stats.unerring_armor])
		inv.process_turn()
		inv.process_turn()
		_unequip(item)
		_check(item.armor_per_tempo_accum == 0, "%s: unequipping resets the counter" % row[0])
		stats.unerring_armor = 0
	# Hallowed Trunk: every 10 armor removed, 1 Regen.
	_equip("hallowed_trunk")
	bm.remove_buff(Buff.BuffType.REGEN)
	stats.current_armor = 30
	stats.take_damage(9, null, bm)
	_check(bm.get_buff(Buff.BuffType.REGEN) == null, "hallowed_trunk: 9 armor removed, no regen yet")
	stats.take_damage(1, null, bm)
	var rg = bm.get_buff(Buff.BuffType.REGEN)
	_check(rg != null and rg.value == 1, "hallowed_trunk: the 10th armor point removed grants 1 Regen")
	bm.remove_buff(Buff.BuffType.REGEN)
	stats.current_armor = 0
	var hp: int = stats.current_health
	stats.take_damage(20, null, bm)
	_check(bm.get_buff(Buff.BuffType.REGEN) == null and stats.current_health == hp - 20, "hallowed_trunk: health lost does not count below Lv.3")
	stats.current_health = stats.max_health
	_strip()

# ------------------------------------------------------------ gauntlet skills

## Fire a gauntlet skill the way its button does (mana, cooldown, 1 tempo).
func _skill(g: ItemData, target) -> bool:
	stats.current_mana = stats.max_mana
	var before: float = stats.current_mana
	main.tempo_manager.current_tempo = 0  # the skill's 1 tempo must not close a cycle mid-check
	stats._tempo_until_mana_regen = 99  # nor tick mana regen into the price
	var t0: int = main.tempo_manager.get_global_tempo()
	main._fire_gauntlet_skill(g, target)
	var paid: int = int(round(before - stats.current_mana))
	_check(paid == g.gauntlet_skill_mana_cost, "%s: %s costs %d mana (paid %d)" % [g.item_name, g.gauntlet_skill_name, g.gauntlet_skill_mana_cost, paid])
	_check(main.tempo_manager.get_global_tempo() - t0 == 1, "%s: the skill takes 1 tempo" % g.item_name)
	return g.is_on_cooldown()

## The described cooldown in tempo: N cycles of 5 tempo, then ready again.
func _cooldown(g: ItemData, tempo: int) -> void:
	_check(g.current_cooldown * 5 == tempo, "%s: %d tempo cooldown (%d)" % [g.item_name, tempo, g.current_cooldown * 5])
	for i in range(tempo / 5):
		inv.process_turn()
	_check(not g.is_on_cooldown(), "%s: ready again after %d tempo" % [g.item_name, tempo])

func _test_gauntlet_skills() -> void:
	print("-- Gauntlet skills --")
	_place_dummies()
	var d: Enemy = dummies[0]
	var fb := _equip("fanned_bracers")
	_check(_skill(fb, d), "fanned_bracers: Fan Save fires")
	_check(d.weaken_stacks == 1, "fanned_bracers: Fan Save inflicts 1 Weaken (%d)" % d.weaken_stacks)
	_cooldown(fb, 10)
	_strip()
	_reset_dummy(d)
	var gdm := _equip("gauntlets_of_dungeon_mastering")
	dm.hand.clear()
	dm.discard_pile.clear()
	var a := Card.create_by_id("slash")
	var b := Card.create_by_id("block")
	dm.discard_pile.append(a)
	dm.discard_pile.append(b)
	_check(_skill(gdm, a), "gauntlets_of_dungeon_mastering: House Rule fires")
	_check(a in dm.hand and not (a in dm.discard_pile) and b in dm.discard_pile,
		"gauntlets_of_dungeon_mastering: House Rule puts the picked discard card in your hand")
	_cooldown(gdm, 20)
	dm.hand.clear()
	dm.discard_pile.clear()
	_strip()
	# Gravity Gauntlets — Suck: enemies within 2 squares of the point are pulled in.
	var gg := _equip("gravity_gauntlets")
	var center: Vector2i = _pcell() + Vector2i(4, 0)
	_place(dummies[0], center + Vector2i(2, 0))
	_place(dummies[1], center + Vector2i(0, 4))
	var cam = main.get_world_camera()
	main.mouse_override = cam.unproject_position(main.grid_manager.grid_to_world(center))
	_check(_skill(gg, null), "gravity_gauntlets: Suck fires")
	var c0: Vector2i = main.grid_manager.world_to_grid(dummies[0].position)
	var c1: Vector2i = main.grid_manager.world_to_grid(dummies[1].position)
	_check(absi(c0.x - center.x) + absi(c0.y - center.y) <= 1, "gravity_gauntlets: an enemy 2 squares off is pulled into the target area (%s vs %s)" % [c0, center])
	_check(c1 == center + Vector2i(0, 4), "gravity_gauntlets: one 4 squares off stays put")
	main.mouse_override = Vector2(-1, -1)
	_cooldown(gg, 10)
	_strip()
	_place_dummies()
	# Hallowed Trunk — imbue tree: 5 Regen and 10 Thorns.
	var ht := _equip("hallowed_trunk")
	bm.remove_buff(Buff.BuffType.REGEN)
	bm.remove_buff(Buff.BuffType.THORNS)
	_check(_skill(ht, null), "hallowed_trunk: imbue tree fires")
	var rg = bm.get_buff(Buff.BuffType.REGEN)
	var th = bm.get_buff(Buff.BuffType.THORNS)
	_check(rg != null and rg.value == 5 and th != null and th.value == 10, "hallowed_trunk: imbue tree grants 5 Regen and 10 Thorns")
	_cooldown(ht, 10)
	bm.remove_buff(Buff.BuffType.REGEN)
	bm.remove_buff(Buff.BuffType.THORNS)
	_strip()
	# Medic Wraps — Slurp and pad: heal an ally 5, gain 3 armor.
	var mw := _equip("medic_wraps")
	stats.current_health = 100
	stats.current_armor = 0
	_check(_skill(mw, main.player), "medic_wraps: Slurp and pad fires")
	_check(stats.current_health == 100 + stats.get_effective_heal_amount(5) and stats.current_armor == 3,
		"medic_wraps: heals 5 and gains 3 armor (hp +%d, armor %d)" % [stats.current_health - 100, stats.current_armor])
	_cooldown(mw, 15)
	stats.current_health = stats.max_health
	stats.current_armor = 0
	_strip()
	# Momentum Mits — Continue to move: draw a card.
	var mom := _equip("momentum_mits")
	dm.hand.clear()
	dm.draw_pile.append(Card.create_by_id("block"))
	_check(_skill(mom, null), "momentum_mits: Continue to move fires")
	_check(dm.hand.size() == 1, "momentum_mits: Continue to move draws a card (%d)" % dm.hand.size())
	_cooldown(mom, 25)
	dm.hand.clear()
	_strip()
	# Mits of Chingiz — 3 count: two offensive cards in a row add a Switch Kick.
	var mc := _equip("mits_of_chingiz")
	main._offensive_streak = 0
	main._three_count_cd = 0
	dm.hand.clear()
	_resolve(Card.create_by_id("slash"), d)
	_check(dm.hand.is_empty(), "mits_of_chingiz: one offensive card adds nothing")
	_resolve(Card.create_by_id("slash"), d)
	var kicks := 0
	for c in dm.hand:
		if c.card_id == "switch_kick":
			kicks += 1
	_check(kicks == 1, "mits_of_chingiz: the second offensive card in a row adds a Switch Kick (%d)" % kicks)
	_check(main._three_count_cd * 5 == 20, "mits_of_chingiz: then a 20 tempo cooldown (%d)" % (main._three_count_cd * 5))
	dm.hand.clear()
	_resolve(Card.create_by_id("slash"), d)
	_resolve(Card.create_by_id("slash"), d)
	_check(dm.hand.is_empty(), "mits_of_chingiz: on cooldown, no second kick")
	for i in range(4):
		main._helm_on_cycle_passives()
	main._offensive_streak = 0
	_resolve(Card.create_by_id("block"), main.player)
	_resolve(Card.create_by_id("slash"), d)
	_check(dm.hand.is_empty(), "mits_of_chingiz: a defense card between breaks the count")
	_resolve(Card.create_by_id("slash"), d)
	_check(dm.hand.size() == 1, "mits_of_chingiz: 20 tempo later it fires again")
	dm.hand.clear()
	_strip()
	_reset_dummies()

# ------------------------------------------------------------ bespoke weapons

## Play `card` through the deck (costs, combo bookkeeping) and resolve it at
## once, without spending the tempo clock.
func _play_now(card: Card, target) -> bool:
	if not (card in dm.hand):
		dm.hand.append(card)
	stats.current_mana = stats.max_mana
	var res: Dictionary = dm.play_card(dm.hand.find(card), target, main.player, true)
	if not res["played"]:
		return false
	_resolve(card, target)
	return true

func _test_bespoke_weapons() -> void:
	print("-- Fallen's Wrath, Feral Evocation, Mauls Sabre, Nine Ruins, Trident, Reaction Rod, Reaper Scythe, Pocket Knife, Laurentius --")
	_place_dummies()
	var d: Enemy = dummies[0]
	# Fallen's Wrath.
	var fw := _equip("fallens_wrath")
	var worn: int = _dmg(Card.create_by_id("slash"), d)
	stats.current_armor = 0
	for i in range(3):
		stats.take_damage(1)
	_check(fw.wrath == 3, "fallens_wrath: each damage instance you take grants 1 Wrath (%d)" % fw.wrath)
	var wr: int = _dmg(Card.create_by_id("slash"), d)
	_check(wr == worn + 3, "fallens_wrath: your attacks deal +Wrath damage (%d vs %d)" % [wr, worn])
	fw.wrath = 30
	stats.take_damage(1)
	_check(fw.wrath == 30, "fallens_wrath: Wrath caps at 30")
	fw.wrath = 0
	# Same health for both blows (Determination moves STR with health).
	stats.current_health = 200
	worn = _dmg(Card.create_by_id("slash"), d)
	fw.wrath = 0
	stats.current_health = 200
	var od: int = _dmg(_slotted("slash", fw), d)
	var extra: int = floori(worn * 1.5) - worn
	_check(od == worn + extra, "fallens_wrath: a slotted card deals 1.5x the whole hit (%d vs %d)" % [od, worn])
	_check(stats.current_health == 200 - ceili(extra / 2.0), "fallens_wrath: and you take half the bonus yourself (%d)" % (200 - stats.current_health))
	fw.wrath = 0
	stats.current_health = stats.max_health
	_strip()
	# Feral Evocation: a slotted card converts the others in hand; 4 damage each.
	var fe := _equip("feral_evocation")
	var red := Card.create_by_id("fireball")
	var blue := Card.create_by_id("ice_grenade")
	_check(fe.slot_card(red) and fe.slot_card(blue), "feral_evocation: a red and a blue card take their colored slots")
	dm.hand.clear()
	dm.hand.append(blue)
	_reset_dummies()
	main._weapon_post_card_effects(red, d)
	_check(blue.has_meta("feral_color") and str(blue.get_meta("feral_color")) == "red", "feral_evocation: playing the red card turns the blue card in hand red")
	_check(_dummy_loss() == 4, "feral_evocation: the conversion deals 4 damage to an enemy within 4 (%d)" % _dummy_loss())
	_reset_dummies()
	main._weapon_post_card_effects(red, d)
	_check(_dummy_loss() == 0, "feral_evocation: already red — no conversion, no damage")
	dm.hand.clear()
	dm.draw_pile.append(blue)
	dm.draw_card()
	_check(not blue.has_meta("feral_color"), "feral_evocation: a converted card reverts once it has left the hand")
	_check(Inventory.is_two_hand_only(fe), "feral_evocation: two-handed")
	dm.hand.clear()
	_strip()
	# Mauls Sabre: the blue slot and the red slot.
	var ms := _equip("mauls_sabre")
	_check(Inventory.is_two_hand_only(ms), "mauls_sabre: two-handed")
	var blue_c := _slotted("slash", ms)
	var red_c := _slotted("slash", ms)
	_check(ms.get_slot_color(blue_c) == "blue" and ms.get_slot_color(red_c) == "red", "mauls_sabre: the first two slots are blue then red")
	var plain: int = _dmg(Card.create_by_id("slash"), d)
	stats.current_armor = 0
	var bd: int = _dmg(blue_c, d)
	_check(bd == plain + 5 and d.weaken_stacks == 1 and stats.current_armor == 8,
		"mauls_sabre: blue slot +5 damage, 1 Weaken, +8 block (%d vs %d, weaken %d, armor %d)" % [bd, plain, d.weaken_stacks, stats.current_armor])
	stats.current_armor = 0
	dm.hand.clear()
	var other := Card.create_by_id("block")
	dm.hand.append(other)
	_reset_dummy(d)
	_play_now(red_c, d)
	var rd: int = 1000 - d.current_health
	_check(rd == plain + 15, "mauls_sabre: red slot +15 damage (%d vs %d)" % [rd, plain])
	_check(other in dm.discard_pile, "mauls_sabre: playing the red card discards a card of your choice")
	_reset_dummy(d)
	_play_now(blue_c, d)
	_check(d.vulnerable_stacks == 1, "mauls_sabre: blue right after red also applies 1 Vulnerable (%d)" % d.vulnerable_stacks)
	_check(red_c.get_burden_tempo_cost() == red_c.tempo_cost - 1, "mauls_sabre: red right after blue costs 1 less tempo")
	stats.current_armor = 0
	dm.hand.clear()
	dm.discard_pile.clear()
	_strip()
	# Nine Ruins of Sanguine: attacks build Vitality (+2 damage, +1% lifesteal each).
	var nr := _equip("nine_ruins_of_sanguine")
	main._clear_penguin()
	var nr_worn: int = _dmg(Card.create_by_id("slash"), d)
	_check(nr.vitality_stacks == 1, "nine_ruins_of_sanguine: an attack grants 1 Vitality (%d)" % nr.vitality_stacks)
	nr.vitality_stacks = 3
	stats.current_health = 100
	var nr_hit: int = _dmg(Card.create_by_id("slash"), d)
	_check(nr_hit == nr_worn + 6, "nine_ruins_of_sanguine: 3 Vitality: +6 attack damage (%d vs %d)" % [nr_hit, nr_worn])
	_check(stats.current_health == 100 + stats.get_effective_heal_amount(maxi(1, floori(nr_hit * 0.03))),
		"nine_ruins_of_sanguine: and 3%% lifesteal (+%d)" % (stats.current_health - 100))
	_check(nr.vitality_stacks == 4, "nine_ruins_of_sanguine: the hit added one more")
	nr.vitality_stacks = 0
	main._summon_penguin()
	var peng = main._penguin
	_check(peng != null and peng.max_health == 50 and peng.BASE_ATTACK == 8 and peng.ATTACK_INTERVAL == 5,
		"nine_ruins_of_sanguine: Sanguine has 50 HP and pecks 8 every 5 tempo")
	_dmg(Card.create_by_id("slash"), d)
	_check(nr.vitality_stacks == 0, "nine_ruins_of_sanguine: no Vitality while he lives")
	stats.current_health = 100
	peng.take_damage(10)
	_check(stats.current_health == 100 + stats.get_effective_heal_amount(5), "nine_ruins_of_sanguine: damage he takes heals you half (+%d)" % (stats.current_health - 100))
	main._clear_penguin()
	stats.current_health = stats.max_health
	_strip()
	# Poseidons Trident: attacks strike 2 squares in a line.
	_equip("poseidons_trident")
	_reset_dummies()
	_place(dummies[0], _pcell() + Vector2i(1, 0))
	_place(dummies[1], _pcell() + Vector2i(2, 0))
	_resolve(Card.create_by_id("slash"), dummies[0])
	var first: int = 1000 - dummies[0].current_health
	_check(first > 0 and 1000 - dummies[1].current_health == first, "poseidons_trident: the square behind the target takes the same hit (%d / %d)" % [first, 1000 - dummies[1].current_health])
	_reset_dummies()
	_place(dummies[1], _pcell() + Vector2i(3, 0))
	_resolve(Card.create_by_id("slash"), dummies[0])
	_check(dummies[1].current_health == 1000, "poseidons_trident: a third square is out of reach")
	_strip()
	_place_dummies()
	# Reaction Rod: a melee striker takes 4 Shock.
	_equip("reaction_rod")
	_reset_dummy(d)
	inv.on_attacked_by(d, true)
	_check(d.shock_stacks == 4, "reaction_rod: an enemy striking from melee takes 4 Shock (%d)" % d.shock_stacks)
	_reset_dummy(d)
	inv.on_attacked_by(d, false)
	_check(d.shock_stacks == 0, "reaction_rod: a ranged striker does not")
	_strip()
	# Reaper Scythe: lifesteal above half, mana below; 10% cheaper below half.
	_equip("reaper_scythe")
	_reset_dummy(d)
	stats.current_health = 100
	stats.current_mana = 0
	var rs_hit: int = _dmg(Card.create_by_id("slash"), d)
	_check(stats.current_health == 100 + stats.get_effective_heal_amount(maxi(1, floori(rs_hit * 0.10))) and int(stats.current_mana) == 0,
		"reaper_scythe: above half health, 10%% lifesteal (+%d)" % (stats.current_health - 100))
	_check(d.vulnerable_stacks == 1, "reaper_scythe: damaging offensive cards apply 1 Vulnerable")
	_reset_dummy(d)
	d.current_health = 400
	stats.current_health = 100
	stats.current_mana = 0
	_resolve(Card.create_by_id("slash"), d)
	var rs_low: int = 400 - d.current_health
	_check(stats.current_health == 100 and int(stats.current_mana) == maxi(1, floori(rs_low * 0.10)),
		"reaper_scythe: below half, 10%% of the damage returns as mana (+%d)" % int(stats.current_mana))
	var full_cost: int = int(dm.compute_play_cost(Card.create_by_id("slash"), 0, dummies[1])["mana"])
	_reset_dummy(d)
	d.current_health = 400
	var low_cost: int = int(dm.compute_play_cost(Card.create_by_id("slash"), 0, d)["mana"])
	_check(low_cost == floori(full_cost * 0.9), "reaper_scythe: a card aimed below half costs 10%% less (%d vs %d)" % [low_cost, full_cost])
	stats.current_health = stats.max_health
	stats.current_mana = stats.max_mana
	_strip()
	_reset_dummy(d)
	# Pocket Knife: while the DEX proc is armed, attacks cost 2 less tempo and land on the first tick.
	for knife in [false, true]:
		if knife:
			_equip("pocket_knife")
		dm.hand.clear()
		var ew := Card.create_by_id("exacerbate_wounds")
		dm.hand.append(ew)
		dm.next_attack_half_tempo = true
		main.select_card(0)
		main.play_selected_card(d)
		var entry: Dictionary = {}
		for e in main.tempo_manager._active_cards:
			if e["card"] == ew:
				entry = e
		if knife:
			_check(not entry.is_empty() and entry["total_ticks"] == maxi(0, 7 / 2 - 2) and entry["resolve_tick"] == 1,
				"pocket_knife: a DEX-proc'd 7-tempo attack takes 3 - 2 = 1 tempo and resolves on tick 1 (%s)" % str([entry.get("total_ticks"), entry.get("resolve_tick")]))
		else:
			_check(not entry.is_empty() and entry["total_ticks"] == 7 / 2, "pocket_knife: (without it the proc'd attack takes %d)" % entry.get("total_ticks", -1))
		var guard := 0
		while main.tempo_manager.is_ticking() and guard < 50:
			main.tempo_manager._process_one_tick()
			guard += 1
		dm.next_attack_half_tempo = false
	_strip()
	_reset_dummies()
	# Laurentius's Lost Spear: slotted self-target cards may target allies.
	var ll := _equip("laurentius_lost_spear")
	var blk := _slotted("harden", ll)
	_check(blk.target_types.has("ally"), "laurentius_lost_spear: a slotted self-target card may target an ally")
	_slotted("patience", ll)
	var plain_blk := _slotted("composed_response", ll)
	_check(ll.is_vanilla_slot(plain_blk) and not plain_blk.target_types.has("ally"), "laurentius_lost_spear: a plain-slot card may not")
	# One Psionic Flow in hand: an attack gains +8 damage and shoves the target back 1.
	dm.hand.clear()
	var pf := Card.create_by_id("psionic_flow")
	dm.hand.append(pf)
	var ll_worn: int = _dmg(Card.create_by_id("slash"), dummies[1])  # the flow fires here
	_check(not (pf in dm.hand), "laurentius_lost_spear: a Psionic Flow fires when you play an attack")
	var start_cell: Vector2i = main.grid_manager.world_to_grid(dummies[1].position)
	_place(dummies[1], _pcell() + Vector2i(1, 0))
	dm.hand.clear()
	var plain_hit: int = _dmg(Card.create_by_id("slash"), dummies[1])
	dm.hand.append(Card.create_by_id("psionic_flow"))
	_place(dummies[1], _pcell() + Vector2i(1, 0))
	var flow_hit: int = _dmg(Card.create_by_id("slash"), dummies[1])
	_check(flow_hit == plain_hit + 8, "laurentius_lost_spear: Psionic Flow adds 8 damage (%d vs %d)" % [flow_hit, plain_hit])
	_check(main.grid_manager.world_to_grid(dummies[1].position) == _pcell() + Vector2i(2, 0), "laurentius_lost_spear: and shoves the target back 1")
	dm.hand.clear()
	_strip()
	_place_dummies()

func _test_misc_items() -> void:
	print("-- Mountain Boots, Return Scroll, granted card prices --")
	var d: Enemy = dummies[0]
	_equip("mountain_boots")
	stats.on_high_ground = false
	var flat: int = _dmg(Card.create_by_id("slash"), d)
	stats.on_high_ground = true
	var high: int = _dmg(Card.create_by_id("slash"), d)
	_check(high == floori(flat * 1.2), "mountain_boots: an offensive card from high ground deals 20%% more (%d vs %d)" % [high, flat])
	stats.on_high_ground = false
	var vm_flat: int = _dmg(Card.create_by_id("volatile_mixture"), d)
	stats.on_high_ground = true
	var vm_high: int = _dmg(Card.create_by_id("volatile_mixture"), d)
	_check(vm_high == vm_flat, "mountain_boots: a damaging non-offensive card gets nothing (%d vs %d)" % [vm_high, vm_flat])
	stats.on_high_ground = false
	_strip()
	# Return Scroll: right-click opens a portal home.
	var scroll: ItemData = null
	for it in inv.stored_items:
		if it and it.special_id == "return_scroll":
			scroll = it
	_check(scroll != null, "return_scroll: the hero carries one")
	_check(not inv.equip_item(ItemData.create("return_scroll"), 0), "return_scroll: it cannot be equipped")
	if scroll:
		main.character_panel._on_stored_item_right_clicked(scroll, inv.stored_items.find(scroll))
		_check(is_instance_valid(main._town_portal_node), "return_scroll: right-clicking it opens a portal")
		if is_instance_valid(main._town_portal_node):
			_check(main.grid_manager.get_distance_in_cells(main.player.position, main._town_portal_node.position) <= 1,
				"return_scroll: the portal stands beside you")
	# Granted cards: the prices the item text quotes.
	for row in [["serene_center", 30, 4], ["purge_wrath", 55, 8], ["its_alive", 20, 5], ["mend", 30, 4],
			["resourceful_replenish", -1, 2], ["ragnarok", 45, 5], ["escape_and_bewilder", 50, 2], ["shiv", 5, 1],
			["neither_man_nor_beast", 10, 2], ["terrain_formation", 25, 3], ["twenty_twenty", -1, 3],
			["wrath_of_the_sea", -1, 8], ["mind_over_matter", 20, 2], ["grounding", 200, 10], ["tricks_of_alberich", 50, 6]]:
		var c := Card.create_by_id(row[0])
		_check(c != null, "%s exists" % row[0])
		if c == null:
			continue
		var mana: int = c.maintain_cost if c.card_type == Card.CardType.POWER and c.maintain_cost > 0 else c.mana_cost
		_check((int(row[1]) < 0 or mana == int(row[1])) and c.tempo_cost == int(row[2]),
			"%s costs %s mana, %d tempo as its item says (%d, %d)" % [row[0], str(row[1]) if int(row[1]) >= 0 else "-", row[2], mana, c.tempo_cost])
