extends RefCounted

## Test-only ItemData fixtures.
## The game's real item list (ItemData.create_*) is intentionally tiny, but the
## mechanics the old items exercised — shields, bows, dual wielding
## breakpoints, ring triggers, quiver slots — are all still live systems.
## These builders hand the tests stand-in gear without reintroducing game
## content. Usage: const Fixtures = preload("res://tests/item_fixtures.gd")

static func _base(item_name: String, type: int) -> ItemData:
	var item = ItemData.new()
	item.item_name = item_name
	item.item_type = type
	return item

static func sword(weight := 80, damage := 10) -> ItemData:
	var item = _base("Test Sword", ItemData.ItemType.WEAPON)
	item.weapon_subtype = ItemData.WeaponSubtype.SWORD
	item.item_type_name = "Weapon"
	item.weight = weight
	item.weapon_damage = damage
	item.card_slots = 1
	item.on_self_damage = 2
	return item

static func greatsword() -> ItemData:
	var item = _base("Test Greatsword", ItemData.ItemType.WEAPON)
	item.weapon_subtype = ItemData.WeaponSubtype.SWORD
	item.item_type_name = "Weapon"
	item.rarity = ItemData.Rarity.RARE
	item.weight = 130
	item.weapon_damage = 25
	return item

static func dagger(weight := 10) -> ItemData:
	var item = _base("Test Dagger", ItemData.ItemType.WEAPON)
	item.weapon_subtype = ItemData.WeaponSubtype.DAGGER
	item.item_type_name = "Weapon"
	item.weight = weight
	item.weapon_damage = 4
	return item

static func polearm(weight := 40) -> ItemData:
	var item = _base("Test Polearm", ItemData.ItemType.WEAPON)
	item.weapon_subtype = ItemData.WeaponSubtype.POLEARM
	item.item_type_name = "Weapon"
	item.weight = weight
	item.weapon_damage = 6
	return item

static func shield(weight := 4) -> ItemData:
	var item = _base("Test Shield", ItemData.ItemType.WEAPON)
	item.weapon_subtype = ItemData.WeaponSubtype.SHIELD
	item.item_type_name = "Shield"
	item.weight = weight
	item.armor_bonus = 5
	return item

static func bow(weight := 30) -> ItemData:
	var item = _base("Test Bow", ItemData.ItemType.WEAPON)
	item.weapon_subtype = ItemData.WeaponSubtype.BOW
	item.item_type_name = "Bow"
	item.weight = weight
	item.weapon_damage = 3
	return item

static func staff(weight := 20) -> ItemData:
	var item = _base("Test Staff", ItemData.ItemType.WEAPON)
	item.weapon_subtype = ItemData.WeaponSubtype.STAFF
	item.item_type_name = "Weapon"
	item.weight = weight
	item.weapon_damage = 5
	return item

## Heavy test hammer.
static func mastery_sledge() -> ItemData:
	# Grants Heavy Swing via the live granted-cards system (the old mastery
	# breakpoint rider was removed with that system) — the war-rack test uses
	# the card to verify owned cards rush to hand on swaps.
	var item = _base("Test Sledge", ItemData.ItemType.WEAPON)
	item.weapon_subtype = ItemData.WeaponSubtype.HAMMER
	item.item_type_name = "Weapon"
	item.weight = 90
	item.weapon_damage = 12
	item.granted_card_ids.assign(["heavy_swing"])
	return item

## Test polearm.
static func mastery_fang() -> ItemData:
	var item = polearm(40)
	item.item_name = "Test Fang"
	return item

static func helm() -> ItemData:
	var item = _base("Test Helm", ItemData.ItemType.HELM)
	item.item_type_name = "Helm"
	item.weight = 3
	item.card_slots = 1
	item.on_self_block = 1
	return item

static func belt() -> ItemData:
	var item = _base("Test Belt", ItemData.ItemType.BELT)
	item.item_type_name = "Belt"
	item.weight = 1
	return item

## Belt that boosts all healing (persistence tests).
static func healing_belt() -> ItemData:
	var item = belt()
	item.item_name = "Test Healing Belt"
	item.healing_bonus = 2
	return item

static func ring(item_name := "Test Ring") -> ItemData:
	var item = _base(item_name, ItemData.ItemType.RING)
	item.item_type_name = "Ring"
	item.weight = 0
	return item

## Ring with a live trigger (fires on utility-card plays).
static func trigger_ring() -> ItemData:
	var item = ring("Test Trigger Ring")
	return item

## Ring carrying a chance boost (persistence tests).
static func chance_ring() -> ItemData:
	var item = ring("Test Chance Ring")
	item.special_effect = ItemData.SpecialEffect.CHANCE_BOOST
	item.special_effect_value = 3
	return item

static func quiver() -> ItemData:
	var item = _base("Test Quiver", ItemData.ItemType.QUIVER)
	item.item_type_name = "Quiver"
	item.weight = 2
	item.ranged_damage_bonus = 1
	item.card_slots = 1
	item.allowed_card_keywords = [Card.CardKeyword.ARROW]
	return item

## Gauntlets that raise hand size via the INCREASE_HAND_SIZE special effect
## (persistence tests double as the effect's guardian test).
static func hand_size_gauntlets() -> ItemData:
	var item = _base("Test Hand-Size Gauntlets", ItemData.ItemType.GAUNTLETS)
	item.item_type_name = "Gauntlets"
	item.weight = 3
	item.special_effect = ItemData.SpecialEffect.INCREASE_HAND_SIZE
	item.special_effect_value = 2
	return item

## Legendary shield with a Lv.3 transformation (forge tests) — mirrors the
## old Aegis of the Colossus shape.
static func legendary_shield() -> ItemData:
	var item = shield(45)
	item.item_name = "Test Legendary Shield"
	item.rarity = ItemData.Rarity.LEGENDARY
	item.armor_bonus = 8
	item.block_bonus_to_defense_cards = 1
	item.card_slots = 1
	item.on_self_block = 2
	item.level_3_overrides = {
		"block_bonus_to_defense_cards": 3,
		"special_effect": ItemData.SpecialEffect.ARMOR_ON_ARMOR_GAIN,
		"special_effect_value": 3,
	}
	item.level_3_description = "Transformed: +3 block to defense cards, +3 Armor on every Armor gain."
	return item

## Mythic gauntlets whose Lv.3 rewrites the skill (forge tests) — mirrors the
## old Worldsplitter Gauntlets shape.
static func mythic_gauntlets() -> ItemData:
	var item = _base("Test Mythic Gauntlets", ItemData.ItemType.GAUNTLETS)
	item.item_type_name = "Gauntlets"
	item.rarity = ItemData.Rarity.MYTHIC
	item.weight = 5
	item.strength_bonus = 3
	item.gauntlet_skill_type = ItemData.GauntletSkillType.ACTIVE
	item.gauntlet_skill_name = "Test Skill"
	item.gauntlet_skill_description = "Deal 20 damage"
	item.gauntlet_skill_cooldown = 4
	item.gauntlet_skill_mana_cost = 3
	item.gauntlet_skill_effect_id = "test_skill"
	item.level_3_overrides = {
		"gauntlet_skill_effect_id": "test_skill_awakened",
		"gauntlet_skill_name": "Test Skill Awakened",
		"gauntlet_skill_cooldown": 3,
	}
	item.level_3_description = "Transformed: awakened test skill."
	return item
