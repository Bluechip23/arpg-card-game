class_name CardPack
extends RefCounted

## A sealed pack of cards dropped by enemies and chests alongside single-card
## drops. Pack tiers reuse the item rarity ladder (Common / Rare / Legendary /
## Mythic); a higher-tier pack holds more cards and shifts the rarity weights
## of what's inside toward the rare end — but less rare cards always show up
## more frequently (see DropRates.PACK_CARD_WEIGHTS).

var tier: ItemData.Rarity = ItemData.Rarity.COMMON

static func create(p_tier: ItemData.Rarity) -> CardPack:
	var pack := CardPack.new()
	pack.tier = p_tier
	return pack

func get_tier_name() -> String:
	match tier:
		ItemData.Rarity.COMMON: return "Common"
		ItemData.Rarity.RARE: return "Rare"
		ItemData.Rarity.LEGENDARY: return "Legendary"
		ItemData.Rarity.MYTHIC: return "Mythic"
	return "Unknown"

func get_display_name() -> String:
	return "%s Card Pack" % get_tier_name()

## Same palette as items of the matching rarity, so a pack reads at a glance.
func get_tier_color() -> Color:
	match tier:
		ItemData.Rarity.COMMON: return Color(0.45, 0.85, 0.45)
		ItemData.Rarity.RARE: return Color(0.4, 0.6, 1.0)
		ItemData.Rarity.LEGENDARY: return Color(1.0, 0.6, 0.2)
		ItemData.Rarity.MYTHIC: return Color(0.9, 0.35, 0.9)
	return Color.WHITE

## Rip the pack open: rolls the card count and each card's rarity from the
## tier's tables. Pass an RNG for deterministic sources; omit for global
## randomness (a chest pack's CONTENTS may roll fresh even when the chest
## itself is seeded — the surprise is the point of a pack).
func open(rng: RandomNumberGenerator = null) -> Array:
	var cards: Array = []
	var count: int = int(DropRates.PACK_CARD_COUNT.get(tier, 3))
	var weights: Dictionary = DropRates.PACK_CARD_WEIGHTS.get(tier, DropRates.CARD_WEIGHTS)
	for _i in range(count):
		var rarity = DropRates.roll_weighted(weights, rng)
		var ids: Array = Card.get_droppable_ids_of_rarity(rarity)
		if ids.is_empty():
			ids = Card.get_droppable_ids_of_rarity(Card.Rarity.BASIC)
		var pick: int = (rng.randi() if rng else randi()) % ids.size()
		cards.append(Card.create_by_id(ids[pick]))
	return cards
