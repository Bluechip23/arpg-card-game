extends RefCounted

## Test-only ItemData fixtures.
## The game's real item list (ItemData.create_*) is intentionally tiny, but the
## mechanics the old items exercised — shields, bows, dual wielding, mastery
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

## Hammer with a STR 15 mastery breakpoint that grants Heavy Swing.
static func mastery_sledge() -> ItemData:
	var item = _base("Test Sledge", ItemData.ItemType.WEAPON)
	item.weapon_subtype = ItemData.WeaponSubtype.HAMMER
	item.item_type_name = "Weapon"
	item.weight = 90
	item.weapon_damage = 12
	item.mastery_stat = "strength"
	item.mastery_threshold = 15
	item.mastery_card_ids.assign(["heavy_swing"])
	item.mastery_description = "grants Heavy Swing while wielded"
	return item

## Polearm with a DEX 15 mastery breakpoint that grants Sweeping Disarm.
static func mastery_fang() -> ItemData:
	var item = polearm(40)
	item.item_name = "Test Fang"
	item.mastery_stat = "dexterity"
	item.mastery_threshold = 15
	item.mastery_card_ids.assign(["sweeping_disarm"])
	item.mastery_description = "grants Sweeping Disarm while wielded"
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
	item.ring_trigger = ItemData.RingTrigger.ON_PLAY_UTILITY_CARD
	item.ring_effect = ItemData.RingEffect.GAIN_MANA
	item.ring_effect_value = 1
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

## Gauntlets that raise hand size (persistence tests).
static func hand_size_gauntlets() -> ItemData:
	var item = _base("Test Grip Gauntlets", ItemData.ItemType.GAUNTLETS)
	item.item_type_name = "Gauntlets"
	item.weight = 3
	item.hand_size_bonus = 2
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
