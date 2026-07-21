class_name DropRates
extends RefCounted

## Every loot-tuning knob in one place, plus the per-act mythic pity system.
##
## DROP BUDGET (the design math these numbers encode):
## A 30-50h story playthrough should produce ~1,000 item drops and land the
## player ~10 mythics — enough for one Lv.3 mythic (7 mythic drops guarantee
## one via Mythic Molds) while keeping 3-4 spares for the build. Legendaries
## ~3%, rares ~12% of item drops; commons/basics fill the rest so something
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
# Chests: flat baseline. Mythic/legendary stay at baseline in every act
# (act 1 additionally locks chest mythics once its mythic is found).
const CHEST_ITEM_WEIGHTS := {
	ItemData.Rarity.BASIC: 54,
	ItemData.Rarity.COMMON: 30,
	ItemData.Rarity.RARE: 12,
	ItemData.Rarity.LEGENDARY: 3,
	ItemData.Rarity.MYTHIC: 1,
}

# Enemy item drops per tier. NO mythic key — mythics come exclusively from
# the per-kill pity layer above, so the numbers stay in one system.
const ENEMY_ITEM_WEIGHTS := {
	TIER_TRASH: {
		ItemData.Rarity.BASIC: 62,
		ItemData.Rarity.COMMON: 30,
		ItemData.Rarity.RARE: 8,
	},
	TIER_MID: {
		ItemData.Rarity.BASIC: 45,
		ItemData.Rarity.COMMON: 33,
		ItemData.Rarity.RARE: 18,
		ItemData.Rarity.LEGENDARY: 4,
	},
	TIER_ELITE: {
		ItemData.Rarity.BASIC: 20,
		ItemData.Rarity.COMMON: 35,
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
# One table for every card source (enemies and chests). All cards are
# obtainable through play — rarity only shapes how often.
const CARD_WEIGHTS := {
	Card.Rarity.BASIC: 38,
	Card.Rarity.COMMON: 34,
	Card.Rarity.RARE: 20,
	Card.Rarity.LEGENDARY: 6,
	Card.Rarity.MYTHIC: 2,
}

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
