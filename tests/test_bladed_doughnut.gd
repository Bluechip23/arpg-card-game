extends SceneTree

## Verifies the first-room tutorial items: the Bladed Doughnut mythic (its
## Sprinkle-conjuring on-kill skill and the level-3 Sprinkle Bomb upgrade)
## and the Wooden Sword Olorin trades for it (card slot with on-self bonus,
## granted Splinter card, enemy bleed).
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
	_test_wooden_sword()
	_test_splinter_and_bleed()

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
	# Mechanics test = testing ground: the story-mode mythic equip limit is off
	# here, same as the sandbox (the doughnut is a Mythic).
	inv.enforce_mythic_limit = false
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

	# A full hand rejects the conjured card instead of overflowing
	while dm.hand.size() < dm.get_hand_cap():
		dm.hand.append(Card.create_slash())
	inv.on_enemy_killed()
	_check(dm.hand.size() == dm.get_hand_cap(),
		"hand full -> the conjured card fizzles instead of overflowing")

	dm.free()
	inv.free()

func _test_wooden_sword() -> void:
	print("-- The Wooden Sword (Olorin's trade) --")
	var sword = ItemData.create_wooden_sword()
	_check(sword.rarity == ItemData.Rarity.COMMON, "Wooden Sword is Common (Basic no longer exists)")
	_check(sword.strength_bonus == 0 and sword.weapon_damage == 0 and sword.armor_bonus == 0
		and sword.health_bonus == 0 and sword.mana_bonus == 0,
		"provides no stats")
	_check(sword.card_slots == 1, "has 1 card slot")
	_check(sword.on_self_damage == 1, "on-self: attacks deal +1 damage")
	_check(sword.get_on_self_bonus()["damage"] == 1, "on-self bonus flows to slotted cards")
	_check(sword.special_effect == ItemData.SpecialEffect.GRANT_CARDS
		and sword.granted_card_ids.size() == 1 and sword.granted_card_ids[0] == "splinter",
		"grants Splinter while equipped")

	# A slotted attack card picks up the +1 on-self damage
	var slash = Card.create_slash()
	_check(sword.can_slot_card(slash), "attack cards fit the slot")
	sword.slot_card(slash)
	_check(slash.get_on_self_bonus()["damage"] == 1, "slotted Slash gains the +1 damage bonus")

	# Equipping brings Splinter into the deck; unequipping removes it
	var inv = Inventory.new()
	inv.initialize("Ryan")
	# Mechanics test = testing ground: the story-mode mythic equip limit is off
	# here, same as the sandbox (the doughnut is a Mythic).
	inv.enforce_mythic_limit = false
	var dm = DeckManager.new()
	inv.connect_deck_manager(dm)
	var gifted = ItemData.create_wooden_sword()
	_check(inv.equip_item(gifted, 0), "Wooden Sword equips as a weapon")
	var in_deck = dm.discard_pile.filter(func(c): return c.card_id == "splinter")
	_check(in_deck.size() == 1, "equipping grants Splinter into the deck")
	_check(in_deck[0].granted_by_item == gifted, "Splinter is owned by the sword")
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	_check(dm.discard_pile.filter(func(c): return c.card_id == "splinter").is_empty(),
		"unequipping pulls Splinter back out of the deck")
	dm.free()
	inv.free()

func _test_splinter_and_bleed() -> void:
	print("-- Splinter and enemy bleed --")
	var s = Card.create_splinter()
	_check(s.mana_cost == 20 and s.tempo_cost == 2, "Splinter costs 20 mana / 2 tempo (post mana rescale)")
	_check(s.is_ranged and s.get_effective_range() == 3, "Splinter has range 3")
	_check(s.base_damage == 0, "Splinter deals no direct damage")

	var enemy = Enemy.new()
	enemy.apply_debuff("bleed", 1)
	_check(enemy.bleed_stacks == 1, "enemies can bleed (1 stack applied)")
	enemy.apply_debuff("bleed", 2)
	_check(enemy.bleed_stacks == 3, "bleed stacks accumulate")
	_check(enemy.get_active_effects().any(func(e): return e["name"] == "Bleed"),
		"bleed shows in the enemy's status effects")
	enemy.free()
