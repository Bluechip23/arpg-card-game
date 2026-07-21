extends SceneTree

## Verifies the item crafting system: rarity copy requirements, forging items
## to higher levels (stat boost at Lv.2, skill transformation at Lv.3), and
## molding mythics into redeemable Mythic Molds.
## Run: godot --headless --path . --script tests/test_item_forge.gd

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
	_test_fodder_rules()
	_test_mythic_molding()
	_test_loot_pools()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_copy_requirements() -> void:
	print("-- Copy requirements --")
	var basic = ItemData.create_iron_sword()
	_check(basic.rarity == ItemData.Rarity.BASIC, "Iron Sword is Basic")
	_check(basic.get_max_level() == 2, "basic items cap at level 2")
	_check(basic.get_copies_for_next_level() == 3, "basic Lv.2 costs 3 extra copies (4 found total)")

	var common = ItemData.create_gold_ring()
	_check(common.rarity == ItemData.Rarity.COMMON and common.get_copies_for_next_level() == 3,
		"common Lv.2 costs 3 extra copies")

	var rare = ItemData.create_heavy_greatsword()
	_check(rare.rarity == ItemData.Rarity.RARE and rare.get_copies_for_next_level() == 3,
		"rare Lv.2 costs 3 extra copies")

	var leg = ItemData.create_dawnbreaker_greatsword()
	_check(leg.rarity == ItemData.Rarity.LEGENDARY, "Dawnbreaker is Legendary")
	_check(leg.get_max_level() == 3, "legendary items cap at level 3")
	_check(leg.get_copies_for_next_level() == 1, "legendary Lv.2 costs 1 extra copy (2 found total)")
	leg.item_level = 2
	_check(leg.get_copies_for_next_level() == 2, "legendary Lv.3 costs 2 more copies (4 found total)")

	var myth = ItemData.create_worldsplitter_gauntlets()
	_check(myth.rarity == ItemData.Rarity.MYTHIC and myth.get_max_level() == 3,
		"mythic items cap at level 3")

func _test_basic_forge() -> void:
	print("-- Forging a basic item to Lv.2 --")
	var inv = _make_inventory()
	var target = ItemData.create_iron_sword()
	inv.store_item(target)
	for i in range(3):
		inv.store_item(ItemData.create_iron_sword())

	_check(ItemForge.can_forge(inv, target), "4 copies found -> can forge")
	var dmg_before = target.weapon_damage
	_check(ItemForge.forge(inv, target), "forge succeeds")
	_check(target.item_level == 2, "item is now Lv.2")
	_check(inv.stored_items.size() == 1 and inv.stored_items[0] == target,
		"3 fodder copies consumed, upgraded item kept")
	_check(target.weapon_damage == dmg_before + 1, "Lv.2 stat boost: +1 weapon damage")
	_check(target.on_self_damage == 2, "Lv.2 boost leaves non-stat fields alone")
	_check(target.get_display_name() == "Iron Sword (Lv.2)", "display name shows the level")
	_check(not target.can_level_up(), "basic item cannot go past Lv.2")
	_check(not ItemForge.can_forge(inv, target), "no further forging at max level")
	inv.free()

func _test_forge_requires_copies() -> void:
	print("-- Forge is blocked without enough copies --")
	var inv = _make_inventory()
	var target = ItemData.create_iron_helm()
	inv.store_item(target)
	inv.store_item(ItemData.create_iron_helm())
	inv.store_item(ItemData.create_iron_helm())
	_check(not ItemForge.can_forge(inv, target), "3 found (need 4) -> cannot forge")
	_check(not ItemForge.forge(inv, target), "forge refuses")
	_check(target.item_level == 1 and inv.stored_items.size() == 3, "nothing consumed")

	# Copies split between inventory and stash both count
	inv.stash_item(ItemData.create_iron_helm())
	_check(ItemForge.can_forge(inv, target), "stash copies count toward the forge")
	inv.free()

func _test_legendary_path() -> void:
	print("-- Legendary path: Lv.1 -> Lv.2 -> Lv.3 --")
	var inv = _make_inventory()
	var target = ItemData.create_aegis_of_the_colossus()
	inv.store_item(target)
	inv.store_item(ItemData.create_aegis_of_the_colossus())

	var armor_before = target.armor_bonus
	_check(ItemForge.forge(inv, target), "2 found total -> forged to Lv.2")
	_check(target.item_level == 2 and target.armor_bonus == armor_before + 1,
		"Lv.2 is a pure stat boost")
	_check(target.block_bonus_to_defense_cards == 2, "block bonus boosted at Lv.2")
	_check(target.special_effect == ItemData.SpecialEffect.NONE, "skill not yet transformed")

	# Two more copies for level 3
	inv.store_item(ItemData.create_aegis_of_the_colossus())
	_check(not ItemForge.can_forge(inv, target), "1 more copy (need 2) -> blocked")
	inv.store_item(ItemData.create_aegis_of_the_colossus())
	_check(ItemForge.forge(inv, target), "4 found total -> forged to Lv.3")
	_check(target.item_level == 3, "item is now Lv.3")
	_check(target.block_bonus_to_defense_cards == 3, "Lv.3 override: +3 block to defense cards")
	_check(target.special_effect == ItemData.SpecialEffect.ARMOR_ON_ARMOR_GAIN
		and target.special_effect_value == 3, "Lv.3 power spike: armor-on-armor-gain skill unlocked")
	_check(target.description == target.level_3_description, "description explains the transformed skill")
	_check(inv.stored_items.size() == 1, "all fodder consumed")

	# Mythic skill transformation
	var myth = ItemData.create_worldsplitter_gauntlets()
	myth.level_up()
	myth.level_up()
	_check(myth.item_level == 3 and myth.gauntlet_skill_effect_id == "worldsplitter_awakened",
		"mythic Lv.3 swaps in the awakened skill")
	_check(myth.gauntlet_skill_cooldown == 3, "awakened skill has reduced cooldown")
	inv.free()

func _test_fodder_rules() -> void:
	print("-- Fodder rules --")
	var inv = _make_inventory()
	var target = ItemData.create_iron_sword()
	inv.store_item(target)
	for i in range(3):
		inv.store_item(ItemData.create_iron_sword())

	# A fodder copy with a slotted card is protected
	var card = Card.create_slash()
	inv.stored_items[1].slot_card(card)
	_check(ItemForge.get_fodder_copies(inv, target).size() == 2,
		"copies holding enchanted cards are not fodder")
	_check(not ItemForge.can_forge(inv, target), "not enough clean copies -> blocked")

	# An equipped item cannot be the forge target
	var equipped_target = ItemData.create_iron_helm()
	inv.equip_item(equipped_target, 0)
	for i in range(3):
		inv.store_item(ItemData.create_iron_helm())
	_check(not ItemForge.can_forge(inv, equipped_target), "equipped items must be unequipped to forge")
	inv.free()

func _test_mythic_molding() -> void:
	print("-- Mythic molding --")
	var inv = _make_inventory()
	var a = ItemData.create_worldsplitter_gauntlets()
	var b = ItemData.create_eternity_quiver()
	inv.store_item(a)
	inv.stash_item(b)

	_check(ItemForge.get_moldable_mythics(inv).size() == 2, "both spare mythics are moldable")
	_check(ItemForge.mold_mythics(inv, a, b), "2 mythics mold into 1 Mythic Mold")
	_check(inv.get_mythic_mold_count() == 1, "mold counter incremented")
	_check(inv.stored_items.is_empty() and inv.stash_items.is_empty(), "both mythics consumed")

	# Non-mythics can't be molded
	var c = ItemData.create_iron_sword()
	var d = ItemData.create_crown_of_the_first_king()
	inv.store_item(c)
	inv.store_item(d)
	_check(not ItemForge.mold_mythics(inv, c, d), "non-mythic cannot be molded")

	# The ownership gate: molds only recreate mythics the character has owned.
	_check(ItemForge.redeem_mold(inv, "Eternity Quiver", ["Worldsplitter Gauntlets"]) == null,
		"molds cannot craft mythics outside the owned list")
	_check(inv.get_mythic_mold_count() == 1, "a refused redeem consumes no mold")

	# Redeem the mold for an owned mythic of choice
	var crafted = ItemForge.redeem_mold(inv, "Eternity Quiver", ["Eternity Quiver", "Worldsplitter Gauntlets"])
	_check(crafted != null and crafted.item_name == "Eternity Quiver",
		"mold redeemed for the chosen owned mythic")
	_check(crafted.item_level == 1, "redeemed mythic starts at level 1")
	_check(inv.get_mythic_mold_count() == 0, "mold consumed")
	_check(inv.stored_items.has(crafted), "crafted mythic lands in inventory")
	_check(ItemForge.redeem_mold(inv, "Eternity Quiver") == null, "no mold -> no redeem")
	inv.free()

func _test_loot_pools() -> void:
	print("-- Loot pools --")
	for r in [ItemData.Rarity.BASIC, ItemData.Rarity.COMMON, ItemData.Rarity.RARE,
			ItemData.Rarity.LEGENDARY, ItemData.Rarity.MYTHIC]:
		var pool = ItemData.get_items_of_rarity(r)
		_check(pool.size() > 0, "rarity tier %d has %d item(s)" % [r, pool.size()])
		for item in pool:
			_check(item.item_level == 1, "%s drops at level 1" % item.item_name)

	var by_name = ItemData.create_by_name("Iron Sword")
	_check(by_name != null and by_name.item_name == "Iron Sword", "create_by_name finds items")
	_check(ItemData.create_by_name("Nonexistent") == null, "create_by_name returns null for unknowns")
