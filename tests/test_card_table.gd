extends SceneTree

## The design sheet (name / id / type / slots / rarity) is the source of
## truth for every card's rarity, slot labels and Engrave flag, and card
## drops roll by that rarity. Spot-checks the tables against the sheet and
## exercises the four cards the sheet added.
## Run: godot --headless --path . --script tests/test_card_table.gd

var failures := 0

class _Dummy extends RefCounted:
	var taken := 0
	func take_damage(amount: int, _ignore = false) -> void:
		taken += amount

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _labels(cid: String) -> Array:
	return Card.create_by_id(cid).slot_labels

func _initialize() -> void:
	print("=== Card sheet test ===")
	var K = Card.CardKeyword

	# Rarities straight off the sheet.
	_check(Card.create_by_id("harden").get_rarity() == Card.Rarity.RARE, "Harden is Rare")
	_check(Card.create_by_id("armor_break").get_rarity() == Card.Rarity.COMMON, "Armor Break is Common")
	_check(Card.create_by_id("internal_combustion").get_rarity() == Card.Rarity.LEGENDARY, "Internal Combustion is Legendary")
	_check(Card.create_by_id("life_swap").get_rarity() == Card.Rarity.MYTHIC, "Life Swap is Mythic")
	_check(Card.create_by_id("slash").get_rarity() == Card.Rarity.COMMON, "the Attack card is Common")
	_check(Card.create_by_id("fountain_of_life").get_rarity() == Card.Rarity.LEGENDARY, "Fountain of Life reads the sheet's Fountain of Health row")
	_check(Card.create_by_id("shadows").get_rarity() == Card.Rarity.LEGENDARY, "a lower-case 'legendary' on the sheet still lands")
	var counts := {}
	for cid in Card.CARD_RARITIES:
		var r = Card.CARD_RARITIES[cid]
		counts[r] = int(counts.get(r, 0)) + 1
	_check(int(counts.get(Card.Rarity.COMMON, 0)) >= 92, "at least the sheet's 92 commons are labelled (%d)" % int(counts.get(Card.Rarity.COMMON, 0)))
	_check(int(counts.get(Card.Rarity.MYTHIC, 0)) >= 9, "at least the sheet's 9 mythics are labelled")

	# Slot labels: several labels, one label, none, and 'stave' as the tome.
	_check(_labels("approach") == [K.BULWARK, K.BUCKLER], "Approach: Bulwark / Buckler")
	_check(_labels("the_lights_favor") == [K.POCKET, K.WAND, K.GEM, K.STAFF, K.TOME], "The Light's Favor lists five slots, 'stave' as Tome")
	_check(_labels("poke") == [K.POCKET], "Poke: Pocket")
	_check(_labels("quick_arrow").is_empty(), "Quick Arrow lost its old Arrow label: deck-only now")
	_check(_labels("charge").is_empty() and not Card.create_by_id("charge").is_slottable(), "Charge is deck-only")
	_check(_labels("reckless_strike") == [K.AXE, K.HAMMER, K.SWORD], "Reckless Strike: Axe / Hammer / Sword (missing comma on the sheet)")
	_check(_labels("friendship") == [K.STAFF, K.WAND, K.GEM, K.SWORD], "Friendship: the sheet's 'swrod' is Sword")
	_check(Card.create_slash().slot_labels.is_empty(), "the Attack card carries no label")
	# Factories that used to set their own label now read the sheet.
	_check(_labels("sky_fall") == [K.ARROW, K.WAND], "Sky Fall: Arrow / Wand from the sheet")
	_check(_labels("last_breath") == [K.STAFF, K.WAND, K.AXE], "Last Breath: Staff / Wand / Axe")
	# A cloned or re-identified card takes the sheet's labels too.
	var c := Card.new()
	c.card_id = "bob_and_weave"
	_check(c.slot_labels == [K.POCKET, K.DAGGER, K.SWIFT, K.SPEAR], "assigning an id applies the sheet's labels")
	# Cards off the sheet keep their factory labels.
	_check(Card.create_by_id("improvised_ammo").card_keyword == K.ARROW, "an item-kit card keeps its factory label")

	# Engrave column.
	for cid in ["shield_slam", "succumb", "cover", "absorb_essence", "fireball", "vengeful_shield", "shield_ready"]:
		var e := Card.create_by_id(cid)
		_check(e.requires_engraving and e.is_slottable(), "%s is an Engrave card with a slot to live in" % cid)
	_check(not Card.create_by_id("harden").requires_engraving, "Harden is not Engrave")

	# The four new cards, as the sheet describes them.
	var pk := Card.create_by_id("peshtigos_kiss")
	_check(pk != null and pk.get_rarity() == Card.Rarity.MYTHIC and pk.school == Card.CardSchool.SPELL
		and pk.is_ranged and pk.is_aoe and pk.slot_labels == [K.STAFF, K.WAND], "Peshtigo's Kiss: Mythic ranged fire spell, Staff / Wand")
	_check(pk.mana_cost == 60 and pk.tempo_cost == 5 and pk.maintain_cost == 60 and not pk.auto_maintain,
		"Peshtigo's Kiss costs 60 mana / 5 tempo and may be maintained by choice")
	var be := Card.create_by_id("barbed_exterior")
	var fa := Card.create_by_id("forever_armor")
	var cr := Card.create_by_id("composed_response")
	_check(be.get_rarity() == Card.Rarity.RARE and be.slot_labels == [K.CROWN, K.AXE], "Barbed Exterior: Rare, Crown / Axe")
	_check(be.mana_cost == 20 and be.tempo_cost == 4 and be.auto_maintain and be.maintain_cost == 20, "Barbed Exterior is a Maintain card (20 mana / 4 tempo)")
	_check(fa.get_rarity() == Card.Rarity.RARE and fa.slot_labels == [K.CROWN, K.BUCKLER, K.SWORD], "Forever Armor: Rare, Crown / Buckler / Sword")
	_check(fa.mana_cost == 20 and fa.tempo_cost == 4 and fa.auto_maintain and fa.maintain_cost == 20, "Forever Armor is a Maintain card (20 mana / 4 tempo)")
	_check(cr.get_rarity() == Card.Rarity.RARE and cr.slot_labels == [K.SPEAR], "Composed Response: Rare, Spear")
	_check(cr.mana_cost == 30 and cr.tempo_cost == 2, "Composed Response costs 30 mana / 2 tempo")

	var stats := PlayerStats.new()
	var dm := DebuffManager.new()
	var bm := BuffManager.new()
	bm.debuff_manager = dm
	bm.owner_stats = stats
	be.execute(null, stats, null, 0.0, 0.0, bm)
	_check(stats.maintained_thorns == 5 and bm.get_thorns_damage() == 5, "Barbed Exterior: 5 thorns while maintained")
	var hit := {"taken": 0}
	var dummy := _Dummy.new()
	bm.on_attacked(dummy)
	bm.on_attacked(dummy)
	_check(dummy.taken == 10 and bm.get_thorns_damage() == 5, "…they strike every attacker and never wear down")
	stats.maintained_thorns = 0
	var cap0: int = stats.get_unerring_cap()
	fa.execute(null, stats, null, 0.0, 0.0, bm)
	_check(stats.get_unerring_cap() == cap0 + 6, "Forever Armor: +6 max unerring armor while maintained")
	stats.add_unerring_armor(cap0 + 6)
	stats.set_maintained_unerring_cap(0)
	_check(stats.get_unerring_cap() == cap0 and stats.unerring_armor <= cap0, "…the cap and any shell above it fall away when the card leaves")

	var deck = load("res://scripts/cards/deck_manager.gd").new()
	var om = load("res://scripts/effects/overflow_manager.gd").new()
	om.initialize(stats)
	deck.connect_overflow_manager(om)
	cr.execute(null, stats, deck, 0.0, 0.0, bm)
	var effects: Array = om.get_effects_by_type(OverflowEffect.OverflowType.OVERCHARGE)
	_check(effects.size() == 1 and effects[0].overcharge_effect_id == "composed_reaction" and effects[0].charges == 5,
		"Composed Response grants Overflow 5 that makes Composed Reactions")
	var fired: Array = []
	om.overcharge_triggered.connect(func(id, _v): fired.append(id))
	om._process_overcharge(effects[0])
	_check(fired == ["composed_reaction"] and effects[0].charges == 4, "each overflow spends one of the five")
	var token := Card.create_composed_reaction()
	_check(token.card_type == Card.CardType.REACTION and token.reaction_trigger == "on_damage_taken" and token.linger,
		"the Composed Reaction is an on-attacked reaction that lingers in a full hand")
	_check(Card.DROP_EXCLUDED_CARD_IDS.has("composed_reaction"), "…and never drops")
	var armor0: int = stats.current_armor
	token.execute(null, stats, deck, 0.0, 0.0, bm)
	_check(stats.current_armor == armor0 + 5 and token.damage == 5, "Composed Reaction: 5 armor, 5 damage")

	# Maintain-on-play: a played Barbed Exterior lands in the maintained pile.
	deck.connect_player_stats(stats)
	deck.hand.append(Card.create_by_id("barbed_exterior"))
	stats.current_mana = 100
	var played: Dictionary = deck.play_card(0, null)
	_check(played.get("played", false) and deck.maintained_cards.size() == 1 and deck.maintained_cards[0].card_id == "barbed_exterior",
		"a played Barbed Exterior is maintained, not discarded")
	_check(stats.maintained_mana == 20, "…reserving its 20 mana")
	_check(not deck.can_maintain(pk), "Peshtigo's Kiss cannot be maintained on a %d-mana pool with 20 already reserved" % stats.max_mana)
	stats.max_mana = 200
	_check(deck.can_maintain(pk), "…but can once 60 mana is free")

	# Drops roll by type, then rarity by tier.
	var type_total := 0
	for t in DropRates.CARD_TYPE_WEIGHTS:
		type_total += int(DropRates.CARD_TYPE_WEIGHTS[t])
	_check(type_total == 100, "card type weights sum to 100")
	_check(not DropRates.CARD_TYPE_WEIGHTS.has(Card.CardType.UNPLAYABLE), "unplayable cards never drop")
	_check(Card.get_droppable_ids_of_type_and_rarity(Card.CardType.DEFENSE, Card.Rarity.RARE).has("harden"),
		"Harden is a Rare Defense drop")
	for tier in [DropRates.TIER_TRASH, DropRates.TIER_MID, DropRates.TIER_ELITE, DropRates.TIER_BOSS]:
		var w: Dictionary = DropRates.ENEMY_CARD_WEIGHTS[tier]
		var total := 0
		for r in w:
			total += int(w[r])
		_check(total == 100, "%s card weights sum to 100" % tier)
	_check(not DropRates.ENEMY_CARD_WEIGHTS[DropRates.TIER_TRASH].has(Card.Rarity.MYTHIC), "trash never drops a mythic card")
	_check(int(DropRates.ENEMY_CARD_WEIGHTS[DropRates.TIER_BOSS][Card.Rarity.LEGENDARY]) >
		int(DropRates.CARD_WEIGHTS[Card.Rarity.LEGENDARY]), "bosses drop legendary cards more often than chests")
	var seen := {}
	var seen_types := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for _i in range(400):
		var card := DropRates.roll_card(DropRates.ENEMY_CARD_WEIGHTS[DropRates.TIER_BOSS], rng)
		seen[card.get_rarity()] = true
		seen_types[card.card_type] = true
		if Card.DROP_EXCLUDED_CARD_IDS.has(card.card_id):
			_check(false, "a token dropped (%s)" % card.card_id)
	_check(seen.has(Card.Rarity.COMMON) and seen.has(Card.Rarity.RARE) and seen.has(Card.Rarity.LEGENDARY),
		"boss rolls produce commons, rares and legendaries")
	_check(seen_types.has(Card.CardType.ATTACK) and seen_types.has(Card.CardType.UTILITY) and seen_types.has(Card.CardType.DEFENSE),
		"…and attacks, utility and defense cards alike")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
