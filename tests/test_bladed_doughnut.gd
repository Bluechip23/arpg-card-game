extends SceneTree

## Verifies the first-room tutorial reward: the Bladed Doughnut mythic, its
## Sprinkle-conjuring on-kill skill, and the level-3 Sprinkle Bomb upgrade.
## Run: godot --headless --path . --script tests/test_bladed_doughnut.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Bladed Doughnut test ===")

	_test_item()
	_test_sprinkle_cards()
	_test_on_kill_conjure()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_item() -> void:
	print("-- The item --")
	var d = ItemData.create_bladed_doughnut()
	_check(d.rarity == ItemData.Rarity.MYTHIC, "Bladed Doughnut is Mythic")
	_check(d.strength_bonus == 15, "offers +15 STR")
	_check(d.on_kill_card_id == "sprinkle", "skill: on kill, conjure a Sprinkle")
	_check(d.get_max_level() == 3, "mythic — three levels")

	d.level_up()
	_check(d.item_level == 2 and d.strength_bonus == 16, "Lv.2 stat boost: STR 15 -> 16")
	_check(d.on_kill_card_id == "sprinkle", "Lv.2 leaves the skill untouched")

	d.level_up()
	_check(d.item_level == 3 and d.on_kill_card_id == "sprinkle_bomb",
		"Lv.3 power spike: Sprinkle becomes Sprinkle Bomb")
	_check(d.description == d.level_3_description, "description explains the upgraded skill")

	_check(ItemData.get_items_of_rarity(ItemData.Rarity.MYTHIC).any(
		func(i): return i.item_name == "Bladed Doughnut"),
		"doughnut is a real mythic (redeemable via Mythic Mold)")

func _test_sprinkle_cards() -> void:
	print("-- The Sprinkle cards --")
	var s = Card.create_sprinkle()
	_check(s.mana_cost == 0 and s.tempo_cost == 0, "Sprinkle costs 0 mana / 0 tempo")
	_check(s.damage == 25 and s.base_damage == 25, "Sprinkle deals 25 damage")
	_check(s.card_type == Card.CardType.ATTACK, "Sprinkle is an attack card")
	_check(s.erase_on_play, "Sprinkle is erased after play (never pollutes the deck)")
	_check(s.shop_excluded, "Sprinkle never appears in the Card Dealer's shop")

	var b = Card.create_sprinkle_bomb()
	_check(b.mana_cost == 0 and b.tempo_cost == 0 and b.damage == 25, "Sprinkle Bomb is 0/0, 25 damage")
	_check(b.is_aoe and b.aoe_shape == "circle", "Sprinkle Bomb is an AOE circle")
	_check(b.erase_on_play and b.shop_excluded, "Sprinkle Bomb erased after play, shop-excluded")

func _test_on_kill_conjure() -> void:
	print("-- On-kill conjuring --")
	var inv = Inventory.new()
	inv.initialize("Ryan")
	var dm = DeckManager.new()
	inv.connect_deck_manager(dm)

	# No doughnut equipped -> kills conjure nothing
	inv.on_enemy_killed()
	_check(dm.hand.is_empty(), "no doughnut equipped -> no card conjured")

	var d = ItemData.create_bladed_doughnut()
	_check(inv.equip_item(d, 0), "doughnut equips as a weapon")
	inv.on_enemy_killed()
	_check(dm.hand.size() == 1 and dm.hand[0].card_id == "sprinkle",
		"kill with doughnut equipped -> Sprinkle conjured into hand")
	inv.on_enemy_killed()
	_check(dm.hand.size() == 2, "every kill conjures another Sprinkle")

	# Level 3 conjures the bomb instead
	d.level_up()
	d.level_up()
	inv.on_enemy_killed()
	_check(dm.hand.size() == 3 and dm.hand[2].card_id == "sprinkle_bomb",
		"Lv.3 doughnut conjures a Sprinkle Bomb instead")

	dm.free()
	inv.free()
