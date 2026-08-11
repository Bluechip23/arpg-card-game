extends SceneTree

## Verifies the item crafting system: rarity copy requirements, forging items
## to higher levels (stat boost at Lv.2, skill transformation at Lv.3), and
## molding mythics into redeemable Mythic Molds.
## Run: godot --headless --path . --script tests/test_item_forge.gd

const Fixtures = preload("res://tests/item_fixtures.gd")

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _make_inventory() -> Inventory:
	var inv = Inventory.new()
	inv.initialize("Ryan")
	return inv

func _initialize() -> void:
	print("=== Item forge test ===")

	_test_copy_requirements()
	_test_basic_forge()
	_test_forge_requires_copies()
	_test_legendary_path()
	_test_level_overrides()
	_test_fodder_rules()
	_test_mythic_molding()
	_test_loot_pools()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_copy_requirements() -> void:
	print("-- Copy requirements --")
	var common = Fixtures.sword()
	_check(common.rarity == ItemData.Rarity.COMMON, "fixture sword defaults to Common")
	_check(common.get_max_level() == 2, "common items cap at level 2")
	_check(common.get_copies_for_next_level() == 3, "common Lv.2 costs 3 extra copies (4 found total)")

	var rare = Fixtures.greatsword()
	_check(rare.rarity == ItemData.Rarity.RARE and rare.get_copies_for_next_level() == 3,
		"rare Lv.2 costs 3 extra copies")

	var leg = Fixtures.legendary_shield()
	_check(leg.rarity == ItemData.Rarity.LEGENDARY, "fixture shield is Legendary")
	_check(leg.get_max_level() == 3, "legendary items cap at level 3")
	_check(leg.get_copies_for_next_level() == 1, "legendary Lv.2 costs 1 extra copy (2 found total)")
	leg.item_level = 2
	_check(leg.get_copies_for_next_level() == 2, "legendary Lv.3 costs 2 more copies (4 found total)")

	var myth = Fixtures.mythic_gauntlets()
	_check(myth.rarity == ItemData.Rarity.MYTHIC and myth.get_max_level() == 3,
		"mythic items cap at level 3")

func _test_basic_forge() -> void:
	print("-- Forging a common item to Lv.2 --")
	var inv = _make_inventory()
	var target = Fixtures.sword()
	inv.store_item(target)
	for i in range(3):
		inv.store_item(Fixtures.sword())

	_check(ItemForge.can_forge(inv, target), "4 copies found -> can forge")
	var dmg_before = target.weapon_damage
	_check(ItemForge.forge(inv, target), "forge succeeds")
	_check(target.item_level == 2, "item is now Lv.2")
	_check(inv.stored_items.size() == 1 and inv.stored_items[0] == target,
		"3 fodder copies consumed, upgraded item kept")
	_check(target.weapon_damage == dmg_before + 1, "Lv.2 stat boost: +1 weapon damage")
	_check(target.on_self_damage == 2, "Lv.2 boost leaves non-stat fields alone")
	_check(target.get_display_name() == "Test Sword (Lv.2)", "display name shows the level")
	_check(not target.can_level_up(), "common item cannot go past Lv.2")
	_check(not ItemForge.can_forge(inv, target), "no further forging at max level")
	inv.free()

func _test_forge_requires_copies() -> void:
	print("-- Forge is blocked without enough copies --")
	var inv = _make_inventory()
	var target = Fixtures.helm()
	inv.store_item(target)
	inv.store_item(Fixtures.helm())
	inv.store_item(Fixtures.helm())
	_check(not ItemForge.can_forge(inv, target), "3 found (need 4) -> cannot forge")
	_check(not ItemForge.forge(inv, target), "forge refuses")
	_check(target.item_level == 1 and inv.stored_items.size() == 3, "nothing consumed")

	# Copies split between inventory and stash both count
	inv.stash_item(Fixtures.helm())
	_check(ItemForge.can_forge(inv, target), "stash copies count toward the forge")
	inv.free()

func _test_legendary_path() -> void:
	print("-- Legendary path: Lv.1 -> Lv.2 -> Lv.3 --")
	var inv = _make_inventory()
	var target = Fixtures.legendary_shield()
	inv.store_item(target)
	inv.store_item(Fixtures.legendary_shield())

	var armor_before = target.armor_bonus
	_check(ItemForge.forge(inv, target), "2 found total -> forged to Lv.2")
	_check(target.item_level == 2 and target.armor_bonus == armor_before + 1,
		"Lv.2 is a pure stat boost")
	_check(target.block_bonus_to_defense_cards == 2, "block bonus boosted at Lv.2")
	_check(target.special_effect == ItemData.SpecialEffect.NONE, "skill not yet transformed")

	# Two more copies for level 3
	inv.store_item(Fixtures.legendary_shield())
	_check(not ItemForge.can_forge(inv, target), "1 more copy (need 2) -> blocked")
	inv.store_item(Fixtures.legendary_shield())
	_check(ItemForge.forge(inv, target), "4 found total -> forged to Lv.3")
	_check(target.item_level == 3, "item is now Lv.3")
	_check(target.block_bonus_to_defense_cards == 3, "Lv.3 override: +3 block to defense cards")
	_check(target.special_effect == ItemData.SpecialEffect.ARMOR_ON_ARMOR_GAIN
		and target.special_effect_value == 3, "Lv.3 power spike: armor-on-armor-gain skill unlocked")
	_check(target.description == target.level_3_description, "description explains the transformed skill")
	_check(inv.stored_items.size() == 1, "all fodder consumed")

	# Mythic skill transformation
	var myth = Fixtures.mythic_gauntlets()
	myth.level_up()
	myth.level_up()
	_check(myth.item_level == 3 and myth.gauntlet_skill_effect_id == "test_skill_awakened",
		"mythic Lv.3 swaps in the awakened skill")
	_check(myth.gauntlet_skill_cooldown == 3, "awakened skill has reduced cooldown")
	inv.free()

func _test_level_overrides() -> void:
	print("-- Bespoke level overrides --")

	# Lv.2: an item with level_2_overrides applies those INSTEAD of the
	# default +1-to-every-nonzero-bonus boost.
	var item = Fixtures.sword()
	var dmg = item.weapon_damage
	item.level_2_overrides = {"weapon_damage": dmg + 5, "on_self_damage": 4}
	item.level_2_description = "A different beast at Lv.2"
	item.level_up()
	_check(item.weapon_damage == dmg + 5, "bespoke Lv.2 override sets its own values")
	_check(item.on_self_damage == 4, "bespoke Lv.2 override can touch non-stat fields")
	_check(item.description == "A different beast at Lv.2", "bespoke Lv.2 description applies")

	# Default path is untouched for items without overrides.
	var plain = Fixtures.sword()
	var plain_dmg = plain.weapon_damage
	plain.level_up()
	_check(plain.weapon_damage == plain_dmg + 1, "items without overrides keep the default +1 boost")

	# Lv.3 can rewrite the granted-card list; built instances reset so the
	# new cards are constructed on the next equip.
	var relic = Fixtures.mythic_gauntlets()
	relic.granted_cards_built = true
	var stale := Card.create_dagger_throw()
	stale.granted_by_item = relic
	relic.granted_card_instances.append(stale)
	relic.level_3_overrides["granted_card_ids"] = ["healing_potion"]
	relic.level_up()  # -> Lv.2
	relic.level_up()  # -> Lv.3 transformation
	_check(relic.granted_card_ids.size() == 1 and relic.granted_card_ids[0] == "healing_potion",
		"Lv.3 override rewrites the granted-card list")
	_check(relic.granted_card_instances.is_empty() and not relic.granted_cards_built,
		"stale granted-card instances reset so the new cards build on equip")

func _test_fodder_rules() -> void:
	print("-- Fodder rules --")
	var inv = _make_inventory()
	var target = Fixtures.sword()
	inv.store_item(target)
	for i in range(3):
		inv.store_item(Fixtures.sword())

	# A fodder copy with a slotted card is protected
	var card = Card.create_slash()
	inv.stored_items[1].slot_card(card)
	_check(ItemForge.get_fodder_copies(inv, target).size() == 2,
		"copies holding enchanted cards are not fodder")
	_check(not ItemForge.can_forge(inv, target), "not enough clean copies -> blocked")

	# A copy that GRANTS cards on its own (built once it was first equipped)
	# is still fodder — its intrinsic cards die with it, nothing of the
	# player's is lost.
	var granting = inv.stored_items[2]
	granting.granted_cards_built = true
	var granted := Card.create_dagger_throw()
	granted.granted_by_item = granting
	granting.granted_card_instances.append(granted)
	_check(ItemForge.get_fodder_copies(inv, target).has(granting),
		"previously-equipped card-granting copies remain valid fodder")

	# An equipped item cannot be the forge target
	var equipped_target = Fixtures.helm()
	inv.equip_item(equipped_target, 0)
	for i in range(3):
		inv.store_item(Fixtures.helm())
	_check(not ItemForge.can_forge(inv, equipped_target), "equipped items must be unequipped to forge")
	inv.free()

func _test_mythic_molding() -> void:
	print("-- Mythic molding --")
	var inv = _make_inventory()
	var a = Fixtures.mythic_gauntlets()
	var b = ItemData.create_bladed_doughnut()
	inv.store_item(a)
	inv.stash_item(b)

	# Having been equipped (granted-card instances built) does not block molding.
	a.granted_cards_built = true
	var a_card := Card.create_dagger_throw()
	a_card.granted_by_item = a
	a.granted_card_instances.append(a_card)

	_check(ItemForge.get_moldable_mythics(inv).size() == 2, "both spare mythics are moldable")
	_check(ItemForge.mold_mythics(inv, a, b), "2 mythics mold into 1 Mythic Mold")
	_check(inv.get_mythic_mold_count() == 1, "mold counter incremented")
	_check(inv.stored_items.is_empty() and inv.stash_items.is_empty(), "both mythics consumed")

	# Non-mythics can't be molded
	var c = Fixtures.sword()
	var d = ItemData.create_bladed_doughnut()
	inv.store_item(c)
	inv.store_item(d)
	_check(not ItemForge.mold_mythics(inv, c, d), "non-mythic cannot be molded")

	# The ownership gate: molds only recreate mythics the character has owned.
	_check(ItemForge.redeem_mold(inv, "Bladed Doughnut", ["Some Other Mythic"]) == null,
		"molds cannot craft mythics outside the owned list")
	_check(inv.get_mythic_mold_count() == 1, "a refused redeem consumes no mold")

	# Redeem the mold for an owned mythic of choice
	var crafted = ItemForge.redeem_mold(inv, "Bladed Doughnut", ["Bladed Doughnut"])
	_check(crafted != null and crafted.item_name == "Bladed Doughnut",
		"mold redeemed for the chosen owned mythic")
	_check(crafted.item_level == 1, "redeemed mythic starts at level 1")
	_check(inv.get_mythic_mold_count() == 0, "mold consumed")
	_check(inv.stored_items.has(crafted), "crafted mythic lands in inventory")
	_check(ItemForge.redeem_mold(inv, "Bladed Doughnut") == null, "no mold -> no redeem")
	inv.free()

func _test_loot_pools() -> void:
	print("-- Loot pools --")
	# Only Common and Mythic tiers hold items right now; the loot rollers fall
	# back to Common when a rolled tier's pool is empty.
	for r in [ItemData.Rarity.COMMON, ItemData.Rarity.MYTHIC]:
		var pool = ItemData.get_items_of_rarity(r)
		_check(pool.size() > 0, "rarity tier %d has %d item(s)" % [r, pool.size()])
		for item in pool:
			_check(item.item_level == 1, "%s drops at level 1" % item.item_name)
	# Mythics exist across the gear slots now (helms, boots, gauntlets) alongside
	# the story's Bladed Doughnut — every one of them must reach forge level 3.
	var mythic_count := 0
	for item in ItemData.get_all_items():
		if item.rarity == ItemData.Rarity.MYTHIC:
			mythic_count += 1
			_check(item.get_max_level() == 3,
				"%s (mythic) forges to level 3" % item.item_name)
	_check(mythic_count > 1, "the roster carries %d mythics" % mythic_count)

	var by_name = ItemData.create_by_name("Wooden Sword")
	_check(by_name != null and by_name.item_name == "Wooden Sword", "create_by_name finds items")
	_check(ItemData.create_by_name("Nonexistent") == null, "create_by_name returns null for unknowns")
