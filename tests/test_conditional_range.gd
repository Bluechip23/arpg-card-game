extends SceneTree

## Conditional keyword: a card is melee or ranged depending on the held weapon
## (bow = ranged, +1 tempo; anything else = melee). Resolved as the card enters
## the hand and again on every equipment change. Exacerbate Wounds is the
## first such card.
## Run: godot --headless --path . --script tests/test_conditional_range.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Conditional range test ===")

	# --- The card on its own ---
	var ew := Card.create_exacerbate_wounds()
	_check(ew.conditional_range and ew.has_keyword("conditional"), "Exacerbate Wounds is conditional")
	_check(not ew.has_keyword("melee") and not ew.has_keyword("ranged"), "conditional replaces the melee/ranged tag")
	_check(not ew.is_ranged, "starts melee before any weapon is known")
	var base_cost := ew.get_burden_tempo_cost()
	ew.apply_conditional_range(true)
	_check(ew.is_ranged and ew.get_effective_range() == 5, "a bow makes it ranged at base range 5")
	_check(ew.get_burden_tempo_cost() == base_cost + 1, "ranged play costs +1 tempo (%d -> %d)" % [base_cost, ew.get_burden_tempo_cost()])
	_check(ew.get_range_display() == "Conditional (Ranged)", "range label reads Conditional (Ranged)")
	ew.apply_conditional_range(false)
	_check(not ew.is_ranged and ew.get_burden_tempo_cost() == base_cost, "a blade makes it melee with no surcharge")
	_check(ew.get_range_display() == "Conditional (Melee)", "range label reads Conditional (Melee)")

	var poke := Card.create_poke()
	poke.apply_conditional_range(true)
	_check(not poke.is_ranged, "a fixed-melee card ignores the weapon")

	# The basic Attack card is Conditional too: it adopts the weapon's reach.
	var attack := Card.create_slash()
	_check(attack.card_name == "Attack" and attack.conditional_range and attack.has_keyword("conditional"), "the Attack card is Conditional")
	attack.apply_conditional_range(true)
	_check(attack.is_ranged and attack.get_effective_range() == 5, "Attack becomes Ranged 5 with a ranged weapon")
	attack.apply_conditional_range(false)
	_check(not attack.is_ranged, "Attack is melee with a melee weapon")

	# --- Through the deck: the held weapon decides as cards enter the hand ---
	var data := CharacterData.create_stephen()
	var stats = load("res://scripts/character/player_stats.gd").new()
	get_root().add_child(stats)
	stats.initialize(data)
	var inv = load("res://scripts/progression/inventory.gd").new()
	get_root().add_child(inv)
	inv.initialize(data.character_name)
	inv.connect_player_stats(stats)
	var dm = load("res://scripts/cards/deck_manager.gd").new()
	get_root().add_child(dm)
	dm.connect_player_stats(stats)
	dm.connect_inventory(inv)

	var drawn := Card.create_exacerbate_wounds()
	dm.draw_pile.append(drawn)
	dm.draw_card()
	_check(drawn in dm.hand and not drawn.is_ranged, "drawn with empty hands: melee")

	var bow := ItemData.create_short_bow()
	_check(inv.equip_item(bow, 0), "bow equips")
	_check(inv.holds_ranged_weapon(), "inventory reports a ranged weapon in hand")
	_check(drawn.is_ranged, "equipping a bow flips the card in hand to ranged")
	_check(drawn.get_burden_tempo_cost() == drawn.tempo_cost + 1, "…and it now costs +1 tempo")

	var added := Card.create_exacerbate_wounds()
	dm.add_card_to_hand(added)
	_check(added.is_ranged, "a card added to hand while holding a bow enters ranged")

	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	_check(not inv.holds_ranged_weapon(), "bow unequipped")
	_check(not drawn.is_ranged and not added.is_ranged, "unequipping the bow flips both back to melee")

	# Magic weapons make the basic ATTACK card ranged — and only it: other
	# Conditional cards still go by the bow alone.
	var wand := ItemData.create_wand_of_clarity()
	_check(inv.equip_item(wand, 0), "wand equips")
	_check(inv.holds_magic_weapon() and not inv.holds_ranged_weapon(), "a wand is a magic weapon, not a ranged one")
	var atk_in_hand := Card.create_slash()
	dm.add_card_to_hand(atk_in_hand)
	_check(atk_in_hand.is_ranged and atk_in_hand.get_effective_range() == 5, "Attack drawn with a wand in hand is Ranged 5")
	_check(not drawn.is_ranged and not added.is_ranged, "Exacerbate Wounds stays melee with a wand")
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	var staff := ItemData.create_magic_staff()
	_check(inv.equip_item(staff, 0), "staff equips")
	_check(inv.holds_magic_weapon() and atk_in_hand.is_ranged, "a staff keeps the Attack card ranged")
	_check(inv.held_weapon_kind() == "staff", "the held weapon kind reads staff")
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	_check(not inv.holds_magic_weapon() and not atk_in_hand.is_ranged, "bare hands: the Attack card is melee again")
	_check(inv.held_weapon_kind() == "none", "bare hands read as no weapon kind")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
