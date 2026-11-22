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
	"blessed": "game_65", "fortify": "game_12",
	"strengthen": "rpg_42", "bolster": "pack_38", "haste": "game_37",
	"cleanse": "game_82", "smith": "rpg_64", "steady": "pack_27",
	"brace": "game_51", "resilient": "pack_24", "life_steal": "game_70",
	"morphine": "game_60", "wear_down": "game_56", "invisible": "rpg_43",
	"armor_break": "rpg_67", "shield_ready": "pack_75",
	"repelled_block": "rpg_68", "shield_of_growth": "rpg_28",
	"demonic_rage": "rpg_52", "poisoned_blood": "game_1", "elixir": "rpg_74",
	"keen": "game_18", "attune": "pack_60", "might": "rpg_90", "raged_circulation": "game_32",
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
	# Brad — Berserker / Warden / The Ancient / The Fallen. All twelve passive_*
	# keys are the designer's own picks (tools/cut_passive_icons.py).
	"enraged_will": "passive_enraged_will", "directed_strength": "passive_directed_strength",
	"life_steal": "passive_life_steal",
	"in_the_trenches": "passive_in_the_trenches", "the_way_of_the_plate": "passive_the_way_of_the_plate", "pristine_armor": "passive_pristine_armor",
	"stone_skin": "passive_stone_skin", "ancestral_aid": "passive_ancestral_aid", "vines_codependence": "passive_vines_codependence",
	"point_to_prove": "passive_point_to_prove", "redemption": "passive_redemption", "solemn_independence": "passive_solemn_independence",
	# Stephen — The Apex / Sentinel / Ranger / Avenger: all twelve the designer's picks.
	"deadly": "passive_deadly", "easy_target": "passive_easy_target", "skilled_momentum": "passive_skilled_momentum",
	"clean_exchange": "passive_clean_exchange", "exposed_blind_spot": "passive_exposed_blind_spot", "lethal_resourcefulness": "passive_lethal_resourcefulness",
	"eagle_eye": "passive_eagle_eye", "scouted": "passive_scouted", "elemental_conclusion": "passive_elemental_conclusion",
	"patience_is_a_virtue": "passive_patience_is_a_virtue", "swing_for_the_fences": "passive_swing_for_the_fences", "dominate": "passive_dominate",
	# Ryan — Relentless Blade / Light Foot / Apothecary / Shadow Blade: all twelve the designer's picks.
	"keep_them_guessing": "passive_keep_them_guessing", "from_the_hip": "passive_from_the_hip", "nimble_assault": "passive_nimble_assault",
	"quick_step": "passive_quick_step", "ladder_work": "passive_ladder_work", "let's_dance": "passive_lets_dance",
	"stimulant": "passive_stimulant", "pop_rocks": "passive_pop_rocks", "mad_scientist": "passive_mad_scientist",
	"now_you_see_me": "passive_now_you_see_me", "surprise_opener": "passive_surprise_opener", "eye_scrape": "passive_eye_scrape",
	# Jeremy — Evocation / Shepherd / Poltergeist / Abjurer: all twelve the designer's picks.
	"arcane_overflow": "passive_arcane_overflow", "harnessed_power": "passive_harnessed_power", "mana_surge": "passive_mana_surge",
	"i_heal_you": "passive_i_heal_you", "whispers_of_the_flock": "passive_whispers_of_the_flock", "blood_libation": "passive_blood_libation",
	"tricks_of_death": "passive_tricks_of_death", "seance": "passive_seance", "haunted_rebuke": "passive_haunted_rebuke",
	"a_mage's_favor": "passive_a_mages_favor", "kinetic_armor": "passive_kinetic_armor", "fresh_start": "passive_fresh_start",
	# Cory — Monk / Lurker / Atrophist / Druid: all twelve the designer's picks.
	"energy_barrier": "passive_energy_barrier", "expel_negativity": "passive_expel_negativity", "self_reliance": "passive_self_reliance",
	"prey_on_the_weak": "passive_prey_on_the_weak", "eat": "passive_eat", "serial_killer": "passive_serial_killer",
	"wither": "passive_wither", "territorial_death": "passive_territorial_death", "death_as_lifeblood": "passive_death_as_lifeblood",
	"budding": "passive_budding", "circle_of_life": "passive_circle_of_life", "regrowth": "passive_regrowth",
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
# Painted card art (Card.card_id): the designer's full paintings, cut by
# tools/cut_card_art.py. A card listed here shows its painting in the card
# face's art window; everywhere an icon is wanted it keeps its CARDS icon.
# ---------------------------------------------------------------------------
const CARD_ART_DIR := "res://assets/textures/cards/art/"
const CARD_PAINTINGS := {
	"basic_attack": "basic_attack",
	"block": "block",
	"braced_draw": "block",   # the starting block that draws wears Block's art (designer, 2026-11-20)
	"slash": "starter_strike",   # the starting strikes (designer, 2026-11-20)
	"exposing_strike": "starter_strike",
	"berserkers_tithe": "berserkers_tithe",
	"momentous_slam": "momentous_slam",
	"fan_of_knives": "fan_of_knives",
	"down_town": "down_town",
	"premeditated": "premeditated",
	"exacerbate_wounds": "exacerbate_wounds",
	"blade_barrage": "blade_barrage",
	"exposed_artery": "exposed_artery",
	"heavy_swing": "heavy_swing",
	"oops": "oops",
	"poke": "poke",
	"savage_strike": "savage_strike",
	"savage_strike_copy": "savage_strike",   # the copy it makes wears its art
	"reckless_strike": "reckless_strike",
	"shield_slam": "shield_slam",
	"specific_strike": "specific_strike",
	"sweeping_disarm": "sweeping_disarm",
	"trip": "trip",
	"worst_that_could_happen": "worst_that_could_happen",
	"charge": "charge",
	"harvest": "harvest",
	"heroic_leap": "heroic_leap",
	"sky_fall": "sky_fall",
	"sky_attack": "sky_attack",
	"shuriken": "shuriken",
	"consecutive_snap": "consecutive_snap",
	"dagger_throw": "dagger_throw",
	"exhausted_assault": "exhausted_assault",
	"last_breath": "last_breath",
	"quick_arrow": "quick_arrow",
	"quick_shot": "quick_arrow",   # the same painting (designer, 2026-11-16)
	"thrown_stone": "thrown_stone",
	"trick_shot": "trick_shot",
	"multishot": "multishot",
	"spirit_arrow": "spirit_arrow",
	"if_pigs_could_fly": "if_pigs_could_fly",
	"peshtigos_kiss": "peshtigos_kiss",
	"approach": "approach",
	"armor_patch": "armor_patch",
	"living_armor": "living_armor",
	"fortify_alliance": "fortify_alliance",
	"parry": "parry",
	"hold_the_line": "hold_the_line",
	"roar": "roar",
	"best_offense": "best_offense",
	"bob_and_weave": "bob_and_weave",
	"defensive_awareness": "defensive_awareness",
	"down_but_not_out": "down_but_not_out",
	"energy_barrier": "energy_barrier",
	"harden": "harden",
	"hunker_down": "hunker_down",
	"repelled_block": "repelled_block",
	"shield_of_growth": "shield_of_growth",
	"shield_ready": "shield_ready",
	"smith_thy_soul": "smith_thy_soul",
	"tower_shield": "tower_shield",
	"turtle_up": "turtle_up",
	"summon_battle_turtle": "summon_battle_turtle",
	"turtle_power": "turtle_power",
	"taunt": "taunt",
	"grit": "grit",
	"cover": "cover",
	"spider_senses": "spider_senses",
	"not_so_fast": "not_so_fast",
	"spiteful_sting": "spiteful_sting",
	"pocket_shiv": "pocket_shiv",
	"vengeful_shield": "vengeful_shield",
	"soul_consumption": "soul_consumption",
	"magic_barrier": "magic_barrier",
	"healthy_bliss": "healthy_bliss",
	"gift_from_the_phoenix": "gift_from_the_phoenix",
	"ember_heart": "ember_heart",
	"cultish_wounds": "cultish_wounds",
	"armored_discipline": "armored_discipline",
	"fountain_of_life": "fountain_of_life",
	"the_wolfs_howl": "the_wolfs_howl",
	"spirit_armor": "spirit_armor",
	"the_ledger": "the_ledger",
	"barbed_exterior": "barbed_exterior",
	"forever_armor": "forever_armor",
	"halo": "halo",
	"wardens_hound": "wardens_hound",
	"lodestone_field": "lodestone_field",
	"grapple_chain": "grapple_chain",
	"summon_skeleton": "summon_skeleton",
	"skeleton_army": "skeleton_army",
	"summon_shadow_hound": "summon_shadow_hound",
	"deliberate_arch": "deliberate_arch",
	"bastion_battle": "bastion_battle",
	"internal_sickness": "internal_sickness",
	"static_sting": "static_sting",
	"lunge": "lunge",
	"vines": "vines",
	"mana_surge": "mana_surge",
	"spark": "spark",
	"harness_lightning": "harness_lightning",
	"spine_release": "spine_release",
	"flames_of_alexandria": "flames_of_alexandria",
	"arcane_tide": "arcane_tide",
	"ward_of_hallow_glass": "ward_of_hallow_glass",
	"surrounding_ice": "surrounding_ice",
	"internal_combustion": "internal_combustion",
	"absorb_essence": "absorb_essence",
	"choke": "choke",
	"god_of_thunder": "god_of_thunder",
	"fireball": "fireball",
	"energy_ball": "energy_ball",
	"worms_armageddon": "worms_armageddon",
	"snowballs_chance": "snowballs_chance",
	"petey_the_pet_rock": "petey_the_pet_rock",
	"lightly_dazed": "lightly_dazed",
	"minor_wounds": "minor_wounds",
	"bottomless_quiver": "bottomless_quiver",
	"collect_arrows": "collect_arrows",
	"discard": "discard",
	"elixir": "elixir",
	"enchanted_quiver": "enchanted_quiver",
	"self_admission": "self_admission",
	"reverse_reverse": "reverse_reverse",
	"clarity": "clarity",
	"succumb": "succumb",
	"pandora_panic": "pandora_panic",
	"swap": "swap",
	"adrenaline_shot": "adrenaline_shot",
	"heal": "heal",
	"stone_wheel": "stone_wheel",
	"gulped_potion": "gulped_potion",
	"gargle_and_spit": "gargle_and_spit",
	"raged_circulation": "raged_circulation",
	"both_sides_of_the_candle": "both_sides_of_the_candle",
	"hope_this_works": "hope_this_works",
	"lady_luck": "lady_luck",
	"try_this": "try_this",
	"push": "push",
	"release_tension": "release_tension",
	"round_em_up": "round_em_up",
	"roll": "roll",
	"surprise_pick_up": "surprise_pick_up",
	"thickened_nature": "thickened_nature",
	"barricade": "barricade",
	"rise": "rise",
	"blink": "blink",
	"volatile_mixture": "volatile_mixture",
	"stoked_pride": "stoked_pride",
	"mark": "mark",
	"anticipation": "anticipation",
	"armor_break": "armor_break",
	"bloodlust": "bloodlust",
	"composed_response": "composed_response",
	"deep_pockets": "deep_pockets",
	"empower": "empower",
	"gain_mana": "gain_mana",
	"give_in": "give_in",
	"healing_potion": "healing_potion",
	"healthy_habit": "healthy_habit",
	"item_mastery": "item_mastery",
	"lethal_recall": "lethal_recall",
	"life_steal": "life_steal",
	"meister_of_faustmesser": "meister_of_faustmesser",
	"life_swap": "life_swap",
	"morphine": "morphine",
	"poisoned_blood": "poisoned_blood",
	"preparation": "preparation",
	"prepare": "prepare",
	"reload": "reload",
	"reposition": "reposition",
	"risk_it": "risk_it",
	"self_infliction": "self_infliction",
	"shadows": "shadows",
	"shed_weight": "shed_weight",
	"tighten_string": "tighten_string",
	"understanding": "understanding",
	"wear_down": "wear_down",
	"cadence": "cadence",
	"foresight": "foresight",
	"back_pedal": "back_pedal",
	"inspiring_whistle": "inspiring_whistle",
	"war_shout": "war_shout",
	"biscuit": "biscuit",
	"loaded_die": "loaded_die",
	"house_money": "house_money",
	"deep_breaths": "deep_breaths",
	"demonic_rage": "demonic_rage",
	"cryonics": "cryonics",
	"friendship": "friendship",
	"meditate": "meditate",
	"communal_donation": "communal_donation",
	"shepherds_mark": "shepherds_mark",
	"mirror_mirror": "mirror_mirror",
	"misery_loves_company": "misery_loves_company",
	"shuriken_pouch": "shuriken_pouch",
	"acro_medic": "acro_medic",
	"feint": "feint",
	"provider": "heal",   # the Heal bag again (designer, 2026-11-18)
	# The Enchantment gems (designer, 2026-11-15), fitted whole.
	"enchantment_attack": "brawn_gem",
	"enchantment_defense": "stone_patch",
	"enchantment_mana_regen": "energy_gem",
	"enchantment_movement": "feather_foot",
	"life_from_resource": "life_from_resource",
	"lemon_drop": "lemon_drop",
	"fumbleitis": "fumbleitis",
	"twenty_twenty": "twenty_twenty",
	"adimantium_wall": "adimantium_wall",
	"balistic_arrow": "balistic_arrow",
	"balance_of_alnilam": "balance_of_alnilam",
	"bark_up": "bark_up",
	"bouncing_shield": "bouncing_shield",
	"chain_lightning": "chain_lightning",
	"cinquedea": "cinquedea",
	"clang_up": "block",   # Clang Up wears Block's art (designer, 2026-11-20)
	"clear_mind": "clear_mind",
	"close_is_favored": "close_is_favored",
	"crack_of_mintaka": "crack_of_mintaka",
	"crash_from_the_sea": "crash_from_the_sea",
	"crops": "crops",
	"curse_of_the_living": "curse_of_the_living",
	"death_vortex": "death_vortex",
	"defensive_sacrifice": "defensive_sacrifice",
	"detonova": "detonova",
	"donate_cleats": "donate_cleats",
	"earth_rattle": "earth_rattle",
	"escape_and_bewilder": "escape_and_bewilder",
	"element_pollination": "element_pollination",
	"fire_punch": "fire_punch",
	"feed_into_the_pain": "feed_into_the_pain",
	"from_the_ashes": "from_the_ashes",
	"gift_from_the_gods": "gift_from_the_gods",
	"cupids_golden_arrow": "cupids_golden_arrow",
	"grounding": "grounding",
	"hard_helmet": "hard_helmet",
	"healing_tonic": "healing_tonic",
	"hemotoxins": "hemotoxins",
	"huck": "huck",
	"ice_grenade": "ice_grenade",
	"improvised_ammo": "improvised_ammo",
	"cupids_lead_arrow": "cupids_lead_arrow",
	"its_alive": "its_alive",
	"m_for_mini": "m_for_mini",
	"mend": "mend",
	"mind_mend": "mind_mend",
	"monk_of_the_night": "monk_of_the_night",
	"negotiate": "negotiate",
	"neither_man_nor_beast": "neither_man_nor_beast",
	"out_of_guesses": "out_of_guesses",
	"mind_over_matter": "mind_over_matter",
	"poison_bomb": "poison_bomb",
	"pole_vault": "pole_vault",
	"polymorph": "polymorph",
	"poof_and_weave": "poof_and_weave",
	"preemptive_answer": "preemptive_answer",
	"protection_from_alnitak": "protection_from_alnitak",
	"psionic_flow": "psionic_flow",
	"purge_wrath": "purge_wrath",
	"ragnarok": "ragnarok",
	"rain_of_arrows": "rain_of_arrows",
	"reapers_taking": "reapers_taking",
	"redline": "redline",
	"resourceful_replenish": "resourceful_replenish",
	"reverberate_regrowth": "reverberate_regrowth",
	"slice": "slice",
	"sanguine_the_penguin": "sanguine_the_penguin",
	"shift": "shift",
	"serene_center": "serene_center",
	"shiv": "shiv",
	"smoke_bomb": "smoke_bomb",
	"return_cut": "return_cut",
	"soften": "soften",
	"song_of_a_swords_sing": "song_of_a_swords_sing",
	"spirit_bow": "spirit_bow",
	"splinter": "splinter",
}

# ---------------------------------------------------------------------------
# Cards (Card.card_id).
# ---------------------------------------------------------------------------
const CARDS := {
	# Melee / physical attacks
	"slash": "pack_82", "basic_attack": "pack_82", "exposing_strike": "pack_82", "slice": "pack_84", "heavy_swing": "rpg_92",
	"savage_strike": "pack_95", "savage_strike_copy": "pack_95",
	"reckless_strike": "rpg_69", "poke": "rpg_35",
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
	"energy_ball": "rpg_47", "energy_barrier": "rpg_41",
	"endured_tolerance": "passive_patience_is_a_virtue", "mage_shield": "game_12",
	"magic_barrier": "game_12", "ice_grenade": "rpg_2", "cryonics": "rpg_2",
	"surrounding_ice": "pack_65", "snowballs_chance": "pack_65",
	"stone_encase": "rpg_86", "earth_rattle": "game_57", "terrain_formation": "game_57",
	"grounding": "game_57", "vines": "rpg_63", "vined_encasing": "pack_49",
	"bark_up": "rpg_63", "crops": "rpg_63", "reverberate_regrowth": "rpg_63",
	"element_pollination": "rpg_88", "death_vortex": "game_77",
	"release_soul": "rpg_43", "infest": "rpg_43", "shadows": "game_78", "invisible": "rpg_43",
	"blink": "game_39", "polymorph": "game_10", "mirror_mirror": "game_39",
	"tricks_of_alberich": "game_39", "escape_and_bewilder": "game_39",
	"poof_and_weave": "game_39", "detonova": "rpg_55", "internal_combustion": "rpg_27",
	"ragnarok": "game_71", "from_the_ashes": "game_71", "gift_from_the_phoenix": "game_71",
	"wrath_of_the_sea": "rpg_11", "gargle_and_spit": "rpg_11", "psionic_flow": "game_3",
	"mind_over_matter": "game_63", "mind_mend": "game_63", "mana_surge": "game_6",
	"gain_mana": "game_6", "djinn_wish": "game_73", "heavy_greedy_cheese": "game_60", "hope_this_works": "game_73",
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
	"block": "game_52", "braced_draw": "game_52", "parry": "game_11", "cover": "pack_76", "hold_the_line": "game_57",
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
	"empower": "game_64", "keen": "game_18",
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


static func card_painting(c) -> Texture2D:
	## The designer's painting for a card's art window, or null when it has
	## none yet (the face then falls back to card()'s icon).
	if c == null:
		return null
	var cid: String = str(c.get("card_id"))
	if not CARD_PAINTINGS.has(cid):
		return null
	var key := "card_art:" + cid
	if _cache.has(key):
		return _cache[key]
	var path: String = CARD_ART_DIR + str(CARD_PAINTINGS[cid]) + ".png"
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_cache[key] = tex
	return tex


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
