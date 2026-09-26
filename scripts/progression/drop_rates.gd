class_name DropRates
extends RefCounted

## Every loot-tuning knob in one place, plus the per-act mythic pity system.
##
## DROP BUDGET (the design math these numbers encode):
## A 30-50h story playthrough should produce ~1,000 item drops and land the
## player ~10 mythics — enough for one Lv.3 mythic (7 mythic drops guarantee
## one via Mythic Molds) while keeping 3-4 spares for the build. Legendaries
## ~3%, rares ~12% of item drops; commons fill the rest so something
## always trickles in. Cards drop alongside items so "empty" kills still
## feel like potential progression.
##
## ACT MYTHIC PITY ("mythic creep"):
## Each act all-but-guarantees one mythic per character. Until the act's
## mythic drops, every story kill raises the chance
## (MYTHIC_CREEP_BASE + kills * MYTHIC_CREEP_STEP); once it drops the act
## returns to the per-tier baseline for good. Act 1 is the exception: after
## its one mythic, act 1 never drops mythics again for that character
## (baseline 0, chests locked too). State lives on CharacterData
## (act_mythic_found / act_mythic_kills) so it survives saves, re-entering
## acts, and re-running the story on the same character.
## With base 0.2% + 0.05%/kill the act mythic typically lands around kill
## ~60 and is near-certain by kill ~150.

# ---- Enemy tiers ------------------------------------------------------------
# "trash" enemies never roll mythics on their own (the creep still counts
# their kills and can pop on any kill); better enemies keep a baseline
# mythic chance after the act's guaranteed one has dropped.
const TIER_TRASH := "trash"
const TIER_MID := "mid"
const TIER_ELITE := "elite"
const TIER_BOSS := "boss"

# ---- Mythic pity ------------------------------------------------------------
const MYTHIC_CREEP_BASE: float = 0.002   # chance on the 1st kill of an act
const MYTHIC_CREEP_STEP: float = 0.0005  # added per kill until the mythic drops

# Baseline mythic chance per kill AFTER the act's guaranteed mythic dropped.
const MYTHIC_BASELINE_BY_TIER := {
	TIER_TRASH: 0.0,
	TIER_MID: 0.002,
	TIER_ELITE: 0.01,
	TIER_BOSS: 0.05,
}

# ---- Item rarity weights ----------------------------------------------------
# Chests: commons and rares only. Legendaries come from enemies, and mythics
# exclusively from the per-kill pity layer — a chest is a steady trickle of
# gear, never a jackpot.
const CHEST_ITEM_WEIGHTS := {
	ItemData.Rarity.COMMON: 85,
	ItemData.Rarity.RARE: 15,
}

# Enemy item drops per tier. NO mythic key — mythics come exclusively from
# the per-kill pity layer above, so the numbers stay in one system.
const ENEMY_ITEM_WEIGHTS := {
	TIER_TRASH: {
		ItemData.Rarity.COMMON: 92,
		ItemData.Rarity.RARE: 8,
	},
	TIER_MID: {
		ItemData.Rarity.COMMON: 78,
		ItemData.Rarity.RARE: 18,
		ItemData.Rarity.LEGENDARY: 4,
	},
	TIER_ELITE: {
		ItemData.Rarity.COMMON: 55,
		ItemData.Rarity.RARE: 35,
		ItemData.Rarity.LEGENDARY: 10,
	},
	TIER_BOSS: {
		ItemData.Rarity.COMMON: 20,
		ItemData.Rarity.RARE: 55,
		ItemData.Rarity.LEGENDARY: 25,
	},
}

# ---- Card rarity weights ----------------------------------------------------
# Cards drop by their rarity (the design sheet's rarity column). Chests and
# any source without a tier use CARD_WEIGHTS; enemies use their loot tier's
# row, so a boss is where the legendary and mythic cards live. All cards
# are obtainable through play — rarity only shapes how often. The Basic
# tier holds only tokens and status cards now, so it never drops.
const CARD_WEIGHTS := {
	Card.Rarity.COMMON: 68,
	Card.Rarity.RARE: 24,
	Card.Rarity.LEGENDARY: 7,
	Card.Rarity.MYTHIC: 1,
}

const ENEMY_CARD_WEIGHTS := {
	TIER_TRASH: {
		Card.Rarity.COMMON: 80,
		Card.Rarity.RARE: 17,
		Card.Rarity.LEGENDARY: 3,
	},
	TIER_MID: CARD_WEIGHTS,
	TIER_ELITE: {
		Card.Rarity.COMMON: 50,
		Card.Rarity.RARE: 35,
		Card.Rarity.LEGENDARY: 12,
		Card.Rarity.MYTHIC: 3,
	},
	TIER_BOSS: {
		Card.Rarity.COMMON: 30,
		Card.Rarity.RARE: 45,
		Card.Rarity.LEGENDARY: 20,
		Card.Rarity.MYTHIC: 5,
	},
}

# ---- Card packs ---------------------------------------------------------------
# When a card drop succeeds, this fraction of the time it arrives as a sealed
# PACK instead of a single card. Pack tiers reuse the item rarity ladder.
const PACK_CHANCE_OF_CARD_DROP: float = 0.25

# Which tier of pack drops (same shape for enemies and chests for now).
const PACK_TIER_WEIGHTS := {
	ItemData.Rarity.COMMON: 70,
	ItemData.Rarity.RARE: 22,
	ItemData.Rarity.LEGENDARY: 7,
	ItemData.Rarity.MYTHIC: 1,
}

# Cards per pack, by pack tier. First-pass numbers — balance later.
const PACK_CARD_COUNT := {
	ItemData.Rarity.COMMON: 3,
	ItemData.Rarity.RARE: 4,
	ItemData.Rarity.LEGENDARY: 4,
	ItemData.Rarity.MYTHIC: 5,
}

# Card-rarity weights INSIDE a pack, by pack tier. Higher tiers drop the
# floor rarities and lean rarer, but the cheap end always outweighs the
# expensive end of whatever range the tier offers.
const PACK_CARD_WEIGHTS := {
	ItemData.Rarity.COMMON: {
		Card.Rarity.COMMON: 78,
		Card.Rarity.RARE: 19,
		Card.Rarity.LEGENDARY: 3,
	},
	ItemData.Rarity.RARE: {
		Card.Rarity.COMMON: 58,
		Card.Rarity.RARE: 32,
		Card.Rarity.LEGENDARY: 9,
		Card.Rarity.MYTHIC: 1,
	},
	ItemData.Rarity.LEGENDARY: {
		Card.Rarity.COMMON: 30,
		Card.Rarity.RARE: 45,
		Card.Rarity.LEGENDARY: 20,
		Card.Rarity.MYTHIC: 5,
	},
	ItemData.Rarity.MYTHIC: {
		Card.Rarity.RARE: 40,
		Card.Rarity.LEGENDARY: 40,
		Card.Rarity.MYTHIC: 20,
	},
}

# ---- Early-game pity ----------------------------------------------------------
# A fresh character should start growing their deck and kit right away. Until
# a character has pulled EARLY_PITY_DROPS cards (and, separately, items) from
# kills, every story kill that rolled nothing of that kind gets a second,
# generous roll: a card from the normal card table, or a COMMON item. Once
# either counter fills, that side of the pity switches off for good.
const EARLY_PITY_DROPS := 3
const EARLY_PITY_CARD_CHANCE: float = 0.35
const EARLY_PITY_ITEM_CHANCE: float = 0.35

# ---- Helpers ----------------------------------------------------------------

## Weighted pick over a {key: weight} table. Pass an RNG for deterministic
## sources (seeded chests); omit it to use global randomness.
static func roll_weighted(weights: Dictionary, rng: RandomNumberGenerator = null):
	var total := 0
	for key in weights:
		total += int(weights[key])
	var roll: int
	if rng:
		roll = rng.randi_range(1, total)
	else:
		roll = randi_range(1, total)
	for key in weights:
		roll -= int(weights[key])
		if roll <= 0:
			return key
	return weights.keys().back()

## The mythic-creep chance on the Nth story kill of an act (1-based).
static func creep_chance(kills: int) -> float:
	return MYTHIC_CREEP_BASE + MYTHIC_CREEP_STEP * maxi(0, kills - 1)

## The mythic chance for this kill given the character's act state.
## found = the act's guaranteed mythic has already dropped.
static func mythic_chance(act: int, found: bool, kills: int, tier: String) -> float:
	if not found:
		return creep_chance(kills)
	if act == 1:
		return 0.0  # act 1 caps at one mythic per character, forever
	return float(MYTHIC_BASELINE_BY_TIER.get(tier, 0.0))

## Roll the per-kill mythic layer for a story kill, advancing the character's
## pity state. Returns true when a mythic should drop from this kill.
static func roll_act_mythic_kill(character, act: int, tier: String,
		rng: RandomNumberGenerator = null) -> bool:
	if character == null:
		return false
	var found: bool = character.act_mythic_found.has(act)
	var kills := 0
	if not found:
		kills = int(character.act_mythic_kills.get(act, 0)) + 1
		character.act_mythic_kills[act] = kills
	var chance := mythic_chance(act, found, kills, tier)
	if chance <= 0.0:
		return false
	var roll: float = rng.randf() if rng else randf()
	if roll >= chance:
		return false
	if not found:
		# The act's guaranteed mythic just dropped — back to baseline for good.
		character.act_mythic_found.append(act)
		character.act_mythic_kills.erase(act)
	return true

## True when act-1 chests must stop offering mythics for this character.
static func act1_mythic_locked(character) -> bool:
	return character != null and character.act_mythic_found.has(1)

## Early-game pity for a story kill's loot (mutates `loot` in place). Counts
## any card/pack or item already in the pile toward the character's early
## counters, and while a counter is still short, gives an empty slot one
## extra roll. Pity items are always commons.
static func apply_early_pity(character, loot: Dictionary,
		rng: RandomNumberGenerator = null) -> void:
	if character == null or loot.is_empty():
		return
	var has_card: bool = loot.get("card") != null or loot.get("card_pack") != null
	if character.early_card_drops < EARLY_PITY_DROPS:
		if not has_card:
			var roll: float = rng.randf() if rng else randf()
			if roll < EARLY_PITY_CARD_CHANCE:
				loot["card"] = roll_card(CARD_WEIGHTS, rng)
				has_card = true
		if has_card:
			character.early_card_drops += 1
	var has_item: bool = loot.get("item") != null
	if character.early_item_drops < EARLY_PITY_DROPS:
		if not has_item:
			var roll: float = rng.randf() if rng else randf()
			if roll < EARLY_PITY_ITEM_CHANCE:
				var pool = ItemData.get_items_of_rarity(ItemData.Rarity.COMMON)
				if not pool.is_empty():
					var idx: int = rng.randi() % pool.size() if rng else randi() % pool.size()
					loot["item"] = pool[idx]
					has_item = true
		if has_item:
			character.early_item_drops += 1

## One card off a card-rarity table (CARD_WEIGHTS unless a tier's row is
## passed). A tier with no droppable card falls back to the commons.
static func roll_card(weights: Dictionary = CARD_WEIGHTS, rng: RandomNumberGenerator = null) -> Card:
	var rarity = roll_weighted(weights, rng)
	var ids = Card.get_droppable_ids_of_rarity(rarity)
	if ids.is_empty():
		ids = Card.get_droppable_ids_of_rarity(Card.Rarity.COMMON)
	ids.sort()
	var idx: int = rng.randi() % ids.size() if rng else randi() % ids.size()
	return Card.create_by_id(ids[idx])
