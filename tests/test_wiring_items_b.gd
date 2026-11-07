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
