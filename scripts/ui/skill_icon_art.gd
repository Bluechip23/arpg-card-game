class_name SkillIconArt
extends RefCounted

## Craftpix skill-icon lookup for buffs/debuffs, passives and card art.
##
## The three 100-icon packs are exported at 48px into
## assets/textures/craftpix/icons/ as rpg_N, game_N and pack_N (see
## tools/build_craftpix_props.py build_skill_icons). Every explicit pick lives
## in the tables below so the final art pass is a one-line edit per entry;
## anything unmapped falls back to a themed pool chosen deterministically from
## the id, so every status, passive and card shows *something* from the packs.
##
##   SkillIconArt.status("Life Steal")  -> Texture2D or null
##   SkillIconArt.passive("eagle_eye")  -> Texture2D (pooled fallback)
##   SkillIconArt.card(card)            -> Texture2D (pooled fallback)

const DIR := "res://assets/textures/craftpix/icons/"

# ---------------------------------------------------------------------------
# Buffs / debuffs (StatusIcons key: lower snake case, apostrophes stripped).
# ---------------------------------------------------------------------------
const STATUS := {
	# Buffs
	"thorns": "rpg_61", "focused": "rpg_47", "regen": "rpg_62",
	"blessed": "game_65", "fortify": "game_12", "enlightened": "pack_17",
	"strengthen": "rpg_42", "bolster": "pack_38", "haste": "game_37",
	"cleanse": "game_82", "smith": "rpg_64", "steady": "pack_27",
	"brace": "game_51", "resilient": "pack_24", "life_steal": "game_70",
	"morphine": "game_60", "wear_down": "game_56", "invisible": "rpg_43",
	"armor_break": "rpg_67", "shield_ready": "pack_75",
	"repelled_block": "rpg_68", "shield_of_growth": "rpg_28",
	"demonic_rage": "rpg_52", "poisoned_blood": "game_1", "elixir": "rpg_74",
	"keen": "game_18", "might": "rpg_90", "raged_circulation": "game_32",
	"understanding": "game_5", "approach": "pack_62",
	"enchanted_quiver": "game_68", "tighten_string": "pack_28",
	"loaded_die": "game_88", "taunt": "rpg_33", "tree": "rpg_63",
	"cupid": "pack_83", "marked": "game_86",
	# Debuffs
	"bleed": "rpg_21", "stun": "rpg_93", "disarm": "rpg_67", "silence": "rpg_9",
	"burn": "rpg_27", "poison": "rpg_45", "cursed": "pack_3", "frozen": "rpg_2",
	"cuffed": "game_73", "shocked": "rpg_11", "slowed": "rpg_26",
	"staggered": "game_56", "drain": "rpg_69", "weighted": "game_29",
	"hexed": "rpg_77", "locked": "game_2", "rooted": "pack_49",
	"clumsy": "rpg_91", "vulnerable": "game_86", "brittle": "game_23",
	"cold": "rpg_83", "blind": "game_48", "weakened": "rpg_58",
	"exposed": "rpg_16", "fear": "rpg_10",
}

# ---------------------------------------------------------------------------
# Skill-tree passives (SkillOption.passive_id).
# ---------------------------------------------------------------------------
const PASSIVES := {
	# Brad — Berserker / Warden / The Ancient / The Fallen
	"enraged_will": "rpg_42", "directed_strength": "rpg_90", "life_steal": "game_70",
	"in_the_trenches": "game_57", "the_way_of_the_plate": "pack_27", "pristine_armor": "game_52",
	"stone_skin": "rpg_86", "ancestral_aid": "game_63", "vines_codependence": "rpg_63",
	"point_to_prove": "pack_30", "redemption": "pack_21", "solemn_independence": "pack_78",
	# Archer — The Apex / Sentinel / Ranger / Avenger
	"deadly": "pack_92", "easy_target": "pack_88", "skilled_momentum": "pack_62",
	"clean_exchange": "game_11", "exposed_blind_spot": "game_86", "lethal_resourcefulness": "pack_87",
	"eagle_eye": "pack_56", "scouted": "rpg_16", "laced_arrow": "game_68",
	"patience_is_a_virtue": "rpg_66", "swing_for_the_fences": "game_74", "dominate": "rpg_50",
}

# Pool per archetype for passives that have no explicit pick yet.
const PASSIVE_POOLS := {
	"Berserker": ["rpg_42", "rpg_50", "rpg_52", "rpg_90", "game_64", "game_74"],
	"Warden": ["game_12", "game_52", "pack_27", "pack_69", "pack_76", "rpg_61"],
	"The Ancient": ["rpg_63", "rpg_86", "game_57", "pack_49", "rpg_88", "game_63"],
	"The Fallen": ["pack_21", "pack_23", "pack_78", "rpg_43", "game_78", "game_65"],
	"The Apex": ["pack_92", "pack_85", "pack_88", "pack_95", "rpg_67", "rpg_69"],
	"Sentinel": ["game_11", "game_86", "pack_87", "pack_56", "rpg_16", "pack_75"],
	"Ranger": ["pack_55", "pack_63", "game_68", "pack_61", "game_48", "pack_56"],
	"Avenger": ["rpg_66", "game_74", "rpg_50", "rpg_92", "pack_84", "game_44"],
}
const PASSIVE_POOL_DEFAULT := ["rpg_47", "game_5", "pack_17", "game_88", "rpg_41", "pack_38"]

# ---------------------------------------------------------------------------
# Cards (Card.card_id).
# ---------------------------------------------------------------------------
const CARDS := {
	# Melee / physical attacks
	"slash": "pack_82", "slice": "pack_84", "heavy_swing": "rpg_92",
	"savage_strike": "pack_95", "savage_strike_copy": "pack_95",
	"reckless_strike": "rpg_69", "basic_attack": "game_43", "poke": "rpg_35",
	"shiv": "pack_92", "dagger_throw": "pack_85", "cinquedea": "pack_85",
	"shuriken": "pack_100", "shuriken_pouch": "pack_100",
	"specific_strike": "pack_88", "return_cut": "game_11", "blade_barrage": "rpg_67",
	"sweeping_disarm": "rpg_68", "exposed_artery": "rpg_21", "splinter": "pack_63",
	"charge": "rpg_50", "heroic_leap": "pack_24", "shield_slam": "pack_27",
	"bouncing_shield": "game_52", "fire_punch": "game_9", "switch_kick": "pack_80",
	"consecutive_snap": "game_11", "down_town": "game_11", "best_offense": "rpg_42",
	"exhausted_assault": "rpg_58", "trip": "game_44", "push": "rpg_20",
	"choke": "game_50", "thrown_stone": "rpg_58", "huck": "rpg_58",
	"improvised_ammo": "rpg_58", "sky_attack": "rpg_27", "sky_fall": "rpg_27",
	"roar": "rpg_32", "taunt": "rpg_33", "meister_of_faustmesser": "rpg_90",
	# Bow / ranged
	"rain_of_arrows": "pack_63", "multishot": "pack_63", "quick_arrow": "pack_55",
	"quick_shot": "pack_55", "spirit_arrow": "pack_55", "spirit_bow": "pack_55",
	"lead_arrow": "game_68", "balistic_arrow": "pack_61", "trick_shot": "pack_88",
	"lethal_recall": "pack_88", "cupids_golden_arrow": "pack_83",
	"cupids_lead_arrow": "pack_83", "reload": "game_43", "collect_arrows": "game_43",
	"bottomless_quiver": "game_43", "enchanted_quiver": "game_68",
	"tighten_string": "pack_28", "twenty_twenty": "pack_56", "mark": "game_86",
	"territorial_mark": "game_48", "shepherds_mark": "game_48",
	"round_em_up": "game_48", "neither_man_nor_beast": "game_48",
	# Spells
	"fireball": "game_26", "spark": "rpg_12", "chain_lightning": "rpg_12",
	"god_of_thunder": "rpg_25", "harness_lightning": "pack_70", "crack_of_mintaka": "rpg_25",
	"energy_ball": "rpg_47", "energy_barrier": "rpg_41", "mage_shield": "game_12",
	"magic_barrier": "game_12", "ice_grenade": "rpg_2", "cryonics": "rpg_2",
	"surrounding_ice": "pack_65", "snowballs_chance": "pack_65",
	"stone_encase": "rpg_86", "earth_rattle": "game_57", "terrain_formation": "game_57",
	"grounding": "game_57", "vines": "rpg_63", "vined_encasing": "pack_49",
	"bark_up": "rpg_63", "crops": "rpg_63", "reverberate_regrowth": "rpg_63",
	"element_pollination": "rpg_88", "death_vortex": "game_77",
	"release_soul": "rpg_43", "shadows": "game_78", "invisible": "rpg_43",
	"blink": "game_39", "polymorph": "game_10", "mirror_mirror": "game_39",
	"tricks_of_alberich": "game_39", "escape_and_bewilder": "game_39",
	"poof_and_weave": "game_39", "detonova": "rpg_55", "internal_combustion": "rpg_27",
	"ragnarok": "game_71", "from_the_ashes": "game_71", "gift_from_the_phoenix": "game_71",
	"wrath_of_the_sea": "rpg_11", "gargle_and_spit": "rpg_11", "psionic_flow": "game_3",
	"mind_over_matter": "game_63", "mind_mend": "game_63", "mana_surge": "game_6",
	"gain_mana": "game_6", "djinn_wish": "game_73", "hope_this_works": "game_73",
	"the_lights_favor": "rpg_5", "gift_from_the_gods": "pack_18", "halo": "pack_23",
	"balance_of_alnilam": "game_88", "protection_from_alnitak": "game_12",
	"curse_of_the_living": "pack_3", "the_nibelung_curse": "pack_3",
	"cultish_wounds": "pack_3", "reapers_taking": "pack_3", "misery_loves_company": "pack_9",
	"succumb": "pack_8", "give_in": "pack_8", "last_breath": "rpg_9",
	"its_alive": "game_69", "living_armor": "game_69", "absorb_essence": "game_66",
	"purge_wrath": "game_82", "worms_armageddon": "rpg_71", "spider_senses": "game_53",
	# Traps / bombs / alchemy
	"poison_bomb": "pack_98", "sprinkle_bomb": "pack_98", "smoke_bomb": "pack_98",
	"volatile_mixture": "pack_98", "sprinkle": "game_1", "hemotoxins": "game_1",
	"poisoned_blood": "game_1", "elixir": "rpg_74", "healing_potion": "pack_50",
	"healing_tonic": "pack_50", "gulped_potion": "pack_50", "potion_of_continuance": "pack_50",
	"try_this": "pack_50", "deep_pockets": "pack_50", "morphine": "game_60",
	"adrenaline_shot": "game_60", "biscuit": "game_60", "mixed_bag": "game_88",
	# Defense
	"block": "game_52", "parry": "game_11", "cover": "pack_76", "hold_the_line": "game_57",
	"barricade": "game_57", "hunker_down": "pack_78", "turtle_up": "rpg_86",
	"adimantium_wall": "rpg_86", "hard_helmet": "pack_69", "harden": "rpg_86",
	"brace": "pack_76", "fortify": "game_12", "fortify_alliance": "game_12",
	"tower_shield": "pack_69", "vengeful_shield": "rpg_61", "thorns": "rpg_61",
	"shield_ready": "pack_75", "repelled_block": "rpg_68", "shield_of_growth": "rpg_28",
	"armored_discipline": "game_52", "defensive_awareness": "pack_56",
	"defensive_sacrifice": "pack_86", "armor_patch": "rpg_64", "clang_up": "pack_27",
	"regal_etching": "pack_27", "fleet_etching": "pack_62",
	# Healing / buffs / utility
	"heal": "game_99", "fountain_of_life": "game_99", "mend": "rpg_30",
	"minor_wounds": "rpg_30", "regen": "rpg_62", "healthy_bliss": "game_99",
	"healthy_habit": "game_99", "resourceful_replenish": "game_99",
	"down_but_not_out": "rpg_62", "life_steal": "game_70", "bloodlust": "game_70",
	"life_swap": "game_32", "raged_circulation": "game_32", "self_infliction": "rpg_21",
	"feed_into_the_pain": "rpg_21", "exacerbate_wounds": "rpg_21",
	"demonic_rage": "rpg_52", "might": "rpg_90", "strengthen": "rpg_42",
	"empower": "game_64", "keen": "game_18", "enlightened": "pack_17",
	"understanding": "game_5", "meditate": "pack_79", "serene_center": "pack_79",
	"monk_of_the_night": "pack_79", "clear_mind": "rpg_47", "deep_breaths": "pack_41",
	"premeditated": "rpg_47", "preemptive_answer": "rpg_47", "anticipation": "rpg_16",
	"patience": "rpg_66", "preparation": "game_5", "prepare": "game_5", "draw": "game_5",
	"discard": "game_41", "smith": "rpg_64", "smith_thy_soul": "rpg_64",
	"item_mastery": "rpg_64", "haste": "game_37", "slowed": "rpg_26",
	"paralysis": "pack_70", "wear_down": "game_56", "armor_break": "rpg_67",
	"swap": "game_72", "shift": "game_72", "reposition": "game_72",
	"stance_switch": "pack_30", "bob_and_weave": "pack_62", "approach": "pack_62",
	"tight_rope": "pack_62", "donate_cleats": "pack_62", "shed_weight": "game_29",
	"communal_donation": "pack_44", "provider": "pack_44", "friendship": "pack_83",
	"negotiate": "game_88", "lady_luck": "game_88", "house_money": "game_88",
	"risk_it": "game_88", "loaded_die": "game_88", "oops": "game_10",
	"release_tension": "pack_28", "song_of_a_swords_sing": "pack_28",
	"rise": "pack_24", "petey_the_pet_rock": "rpg_86", "m_for_mini": "rpg_53",
	# Enchantments
	"enchantment_attack": "game_25", "enchantment_defense": "game_29",
	"enchantment_mana_regen": "game_36", "enchantment_movement": "rpg_53",
}

# Pools keyed by "<CardType>" or "<CardType>_SPELL" / "_TRAP".
const CARD_POOLS := {
	"ATTACK": ["pack_82", "pack_84", "pack_85", "pack_89", "pack_91", "pack_92", "pack_95",
		"rpg_67", "rpg_68", "rpg_69", "rpg_92", "game_43", "game_11", "game_44"],
	"ATTACK_SPELL": ["rpg_5", "rpg_12", "rpg_22", "rpg_25", "rpg_37", "rpg_55", "rpg_57",
		"game_26", "game_9", "game_35", "pack_31", "pack_34"],
	"ATTACK_TRAP": ["game_45", "game_53", "pack_4", "pack_98", "rpg_71"],
	"DEFENSE": ["game_12", "game_52", "pack_27", "pack_69", "pack_76", "rpg_61", "rpg_86", "game_2"],
	"UTILITY": ["game_5", "rpg_47", "game_88", "pack_23", "rpg_30", "game_51", "pack_50",
		"rpg_41", "game_6", "pack_44"],
	"UTILITY_SPELL": ["rpg_41", "rpg_47", "game_6", "game_3", "rpg_53", "game_36", "pack_17"],
	"UTILITY_TRAP": ["game_45", "game_53", "pack_4", "pack_98"],
	"REACTION": ["game_37", "rpg_68", "rpg_44", "pack_33", "game_11", "pack_75"],
	"POWER": ["rpg_42", "rpg_90", "game_64", "pack_30", "rpg_50", "game_74"],
	"ENCHANTMENT": ["game_29", "rpg_53", "game_25", "game_36", "game_73", "rpg_86"],
	"UNPLAYABLE": ["game_10", "rpg_10", "pack_3", "rpg_77", "game_40"],
}
const CARD_POOL_DEFAULT := ["game_5", "rpg_47", "game_88", "rpg_41"]

static var _cache: Dictionary = {}


static func texture(key: String) -> Texture2D:
	## Texture for a pack key ("rpg_61"), cached; null when the export is missing.
	if key == "":
		return null
	if _cache.has(key):
		return _cache[key]
	var path := DIR + key + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_cache[key] = tex
	return tex


static func status(effect_name: String) -> Texture2D:
	var key := effect_name.to_lower().replace(" ", "_").replace("'", "")
	return texture(STATUS.get(key, ""))


static func passive(passive_id: String, archetype: String = "") -> Texture2D:
	if PASSIVES.has(passive_id):
		return texture(PASSIVES[passive_id])
	var pool: Array = PASSIVE_POOLS.get(archetype, PASSIVE_POOL_DEFAULT)
	return texture(_pick(pool, passive_id))


static func card(c) -> Texture2D:
	## Card art for a Card (or anything with card_id/card_type/school).
	if c == null:
		return null
	var cid: String = str(c.get("card_id"))
	if CARDS.has(cid):
		return texture(CARDS[cid])
	return texture(_pick(_card_pool(c), cid))


static func card_by_id(cid: String) -> Texture2D:
	if CARDS.has(cid):
		return texture(CARDS[cid])
	return texture(_pick(CARD_POOL_DEFAULT, cid))


static func _card_pool(c) -> Array:
	var type_names := Card.CardType.keys()
	var t: int = int(c.get("card_type"))
	var base: String = type_names[t] if t >= 0 and t < type_names.size() else "UTILITY"
	var school: int = int(c.get("school"))
	var suffix := ""
	if school == Card.CardSchool.SPELL:
		suffix = "_SPELL"
	elif school == Card.CardSchool.TRAP:
		suffix = "_TRAP"
	if suffix != "" and CARD_POOLS.has(base + suffix):
		return CARD_POOLS[base + suffix]
	return CARD_POOLS.get(base, CARD_POOL_DEFAULT)


static func _pick(pool: Array, id: String) -> String:
	if pool.is_empty():
		return ""
	return pool[absi(id.hash()) % pool.size()]
