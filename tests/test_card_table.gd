extends SceneTree

## The design sheet (name / id / type / slots / rarity) is the source of
## truth for every card's rarity, slot labels and Engrave flag, and card
## drops roll by that rarity. Spot-checks the tables against the sheet and
## exercises the four cards the sheet added.
## Run: godot --headless --path . --script tests/test_card_table.gd

var failures := 0

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

	# The four new cards.
	var pk := Card.create_by_id("peshtigos_kiss")
	_check(pk != null and pk.get_rarity() == Card.Rarity.MYTHIC and pk.school == Card.CardSchool.SPELL
		and pk.is_ranged and pk.is_aoe and pk.slot_labels == [K.STAFF, K.WAND], "Peshtigo's Kiss: Mythic ranged fire spell, Staff / Wand")
	var be := Card.create_by_id("barbed_exterior")
	var fa := Card.create_by_id("forever_armor")
	var cr := Card.create_by_id("composed_response")
	_check(be.get_rarity() == Card.Rarity.RARE and be.slot_labels == [K.CROWN, K.AXE], "Barbed Exterior: Rare, Crown / Axe")
	_check(fa.get_rarity() == Card.Rarity.RARE and fa.slot_labels == [K.CROWN, K.BUCKLER, K.SWORD], "Forever Armor: Rare, Crown / Buckler / Sword")
	_check(cr.get_rarity() == Card.Rarity.RARE and cr.slot_labels == [K.SPEAR], "Composed Response: Rare, Spear")
	var stats := PlayerStats.new()
	var dm := DebuffManager.new()
	var bm := BuffManager.new()
	bm.debuff_manager = dm
	var armor0: int = stats.current_armor
	be.execute(null, stats, null, 0.0, 0.0, bm)
	_check(stats.current_armor == armor0 + 4, "Barbed Exterior grants 4 armor")
	_check(bm.has_buff(Buff.BuffType.THORNS), "…and Thorns")
	fa.execute(null, stats, null, 0.0, 0.0, bm)
	_check(stats.current_armor == armor0 + 10 and bm.should_ignore_armor_decay(), "Forever Armor grants 6 armor and stops decay")
	cr.execute(null, stats, null, 0.0, 0.0, bm)
	_check(stats.current_armor == armor0 + 13 and bm.has_buff(Buff.BuffType.BRACE), "Composed Response grants 3 armor and Brace")

	# Drops roll by rarity and by tier.
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
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for _i in range(400):
		var card := DropRates.roll_card(DropRates.ENEMY_CARD_WEIGHTS[DropRates.TIER_BOSS], rng)
		seen[card.get_rarity()] = true
		if Card.DROP_EXCLUDED_CARD_IDS.has(card.card_id):
			_check(false, "a token dropped (%s)" % card.card_id)
	_check(seen.has(Card.Rarity.COMMON) and seen.has(Card.Rarity.RARE) and seen.has(Card.Rarity.LEGENDARY),
		"boss rolls produce commons, rares and legendaries")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
