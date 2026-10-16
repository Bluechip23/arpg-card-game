class_name EnemyDefs
extends RefCounted

## The enemy roster's base numbers, one entry per Enemy.EnemyType (keyed by
## the enum's name). Enemy.initialize() copies the entry onto the node and
## then applies passive_power_scale; the compendium (Enemy.get_all_enemy_data),
## EnemySpawner.get_loot_tier and Enemy._setup_sprite read it too. Keys:
##   name, health, damage, move, xp, color      always present
##   armor, range, aggro                        when the type overrides the
##                                              Enemy export defaults (0 / 1.5 / 8.0)
##   resists: [physical, fire, lightning]       the design sheet's resist columns (%; negative = vulnerable)
##   damage_type                                DamageTypes.Type of its attacks (default PHYSICAL)
##   ignores_invisibility, immune_to_high_ground, is_training_dummy, is_structure,
##   bleed_on_attack, attack_blind_chance, attack_burn, attack_shock, armor_per_hit
##   tier                                       the design sheet's Tier column (docs/ENEMY_SHEET.tsv):
##                                              Trash / Mid-tier / Elite / Boss, "Special" for the
##                                              Ring Wraith, the structures and the dojo dummy (not
##                                              creatures, no tier). MINION/ELITE/BOSS keep the tiers
##                                              they stood for. The compendium shows it and
##                                              EnemySpawner.get_loot_tier derives the loot table from it.
##   loot_tier                                  only where the loot table differs from the sheet tier
##   intended_level                             the level band for XP falloff and passive_power_scale
##                                              (0 / absent = unbanded). Sewers 1-5, Graveyard 6-12,
##                                              Cave 8-15, Forest 12-20, Mountains 20-25, Underworld
##                                              ~Act 2, Heavens ~Act 3; Cerberus and the Inflamed
##                                              Minotaur carry their boss sheet's level column.
##   figure_kind                                the SpriteEnemyFigure / EnemyFigure kind ("" or
##                                              absent = the coloured box)
##   mockup: true                               a design mock-up (stats & moves TBD): Enemy only
##                                              names it and warns; the compendium lists it.
## The numbers are the hand-tuned stats the designer's sheet settled on — a
## balance change is an edit here, nothing else.

const DEFS := {
	"MINION": {
		"name": "Minion",
		"tier": "Trash",
		"intended_level": 1,
		"figure_kind": "brute_minion",
		"health": 25,
		"damage": 3,
		"move": 1.0,
		"xp": 5,
		"color": Color(0.8, 0.2, 0.2),
	},
	"ELITE": {
		"name": "Elite",
		"tier": "Elite",
		"intended_level": 5,
		"figure_kind": "brute_elite",
		"health": 80,
		"damage": 6,
		"move": 0.8,
		"xp": 10,
		"color": Color(0.6, 0.1, 0.1),
	},
	"BOSS": {
		"name": "Boss",
		"tier": "Boss",
		"intended_level": 10,
		"figure_kind": "brute_boss",
		"health": 200,
		"damage": 10,
		"move": 0.5,
		"xp": 25,
		"color": Color(0.4, 0.0, 0.2),
	},
	"RING_WRAITH": {
		# The Precious: hunts the ring-bearer through the shadow world.
		# Shadow form does not hide the player from these.
		"name": "Ring Wraith",
		"tier": "Special",
		"health": 100,
		"damage": 15,
		"move": 5.0,
		"xp": 0,  # they resummon — no farming the shadow
		"ignores_invisibility": true,
		"color": Color(0.12, 0.1, 0.18),
	},
	"WERERAT": {
		"name": "Wererat",
		"tier": "Trash",
		"intended_level": 2,
		"figure_kind": "rat",
		"health": 8,
		"damage": 3,
		"move": 1.0,
		"xp": 3,
		"color": Color(0.5, 0.35, 0.2),  # Brown
	},
	"SKELETON": {
		"name": "Skeleton",
		"tier": "Mid-tier",
		"intended_level": 7,
		"figure_kind": "skeleton",
		"health": 20,
		"armor": 12,
		"damage": 6,
		"move": 1.0,
		"xp": 7,
		"color": Color(0.85, 0.85, 0.75),  # Bone white
	},
	"ARMORED_TROLL": {
		"name": "Armored Troll",
		"tier": "Elite",
		"intended_level": 12,
		"figure_kind": "armored_troll",
		"health": 60,
		"armor": 40,
		"damage": 7,
		"move": 2.0,       # 2 spaces / 4 tempo
		"xp": 30,
		"resists": [30, 15, 15],
		"color": Color(0.2, 0.4, 0.15),  # Dark green
	},
	"ARCHER_RAT": {
		"name": "Archer Rat",
		"tier": "Trash",
		"intended_level": 2,
		"figure_kind": "archer_rat",
		"health": 6,
		"armor": 0,
		"damage": 2,
		"range": 4.0,  # Ranged attacker
		"move": 2.0,  # Moves 2 tiles when repositioning
		"xp": 4,
		"color": Color(0.6, 0.4, 0.25),  # Light brown
	},
	"HYDRA": {
		"name": "Hydra",
		"tier": "Elite",
		"intended_level": 14,
		"figure_kind": "hydra",
		"health": 190,          # sheet: 190
		"damage": 7,         # +accumulated strength
		"range": 1.5,        # Melee
		"move": 3.0,       # Moves 3 spaces
		"aggro": 12.0,
		"xp": 60,
		"resists": [25, 25, 25],  # sheet: 25% physical / fire / lightning
		"color": Color(0.2, 0.55, 0.35),  # Scaled green
	},
	"FIRE_GOBLIN_SOLDIER": {
		"name": "Fire Goblin Soldier",
		"tier": "Trash",
		"intended_level": 9,
		"figure_kind": "fire_goblin_soldier",
		"health": 6,
		"damage": 2,
		"range": 1.5,        # Range 0 — must be adjacent
		"move": 4.0,       # Moves 4 spaces
		"xp": 3,
		"color": Color(0.85, 0.35, 0.15),  # Ember orange
	},
	"FIRE_GOBLIN_MAGE": {
		"name": "Fire Goblin Mage",
		"tier": "Mid-tier",
		"intended_level": 9,
		"figure_kind": "fire_goblin_mage",
		"health": 10,
		"damage": 7,         # Ember damage
		"range": 4.0,
		"move": 2.0,
		"xp": 8,
		"color": Color(0.9, 0.45, 0.2),
	},
	"FIRE_GOBLIN_SHAMAN": {
		"name": "Fire Goblin Shaman",
		"tier": "Mid-tier",
		"intended_level": 10,
		"figure_kind": "fire_goblin_shaman",
		"health": 16,
		"damage": 6,         # Fire wall damage
		"range": 5.0,
		"move": 2.0,
		"xp": 12,
		"color": Color(0.95, 0.55, 0.25),
	},
	# ===================== FOREST ACT =====================
	"GIANT_BEAVER": {
		"name": "Giant Beaver",
		"tier": "Elite",
		"intended_level": 16,
		"figure_kind": "giant_beaver",
		"health": 60,
		"damage": 9,         # Chomp damage; Tail Whip deals 6
		"range": 1.5,
		"move": 3.0,       # 3 spaces / 6 tempo
		"xp": 20,
		"resists": [25, 0, 0],
		"color": Color(0.45, 0.30, 0.18),
	},
	"MINI_BEAR": {
		"name": "Mini Bear",
		"tier": "Trash",
		"intended_level": 13,
		"figure_kind": "mini_bear",
		"health": 14,
		"damage": 4,
		"range": 1.5,
		"move": 5.0,       # 5 spaces / 5 tempo
		"xp": 6,
		"color": Color(0.40, 0.26, 0.16),
	},
	"LARGE_BEAR": {
		"name": "Large Bear",
		"tier": "Elite",
		"intended_level": 18,
		"figure_kind": "large_bear",
		"health": 90,
		"damage": 12,
		"range": 1.5,
		"move": 6.0,       # 6 spaces / 7 tempo
		"xp": 35,
		"bleed_on_attack": 4,
		# No base resists — 30% physical arrives (permanently) below 50% HP.
		"color": Color(0.32, 0.20, 0.12),
	},
	"WOLF": {
		"name": "Wolf",
		"tier": "Mid-tier",
		"intended_level": 14,
		"figure_kind": "wolf",
		"health": 30,
		"damage": 7,
		"range": 1.5,
		"move": 4.0,       # 4 spaces / 3 tempo
		"xp": 12,
		"color": Color(0.45, 0.45, 0.48),
	},
	"COYOTE": {
		"name": "Coyote",
		"tier": "Trash",
		"intended_level": 12,
		"figure_kind": "coyote",
		"health": 6,
		"damage": 2,
		"range": 1.5,
		"move": 4.0,       # 4 spaces / 3 tempo
		"xp": 3,
		"color": Color(0.62, 0.52, 0.36),
	},
	"BUGBEAR": {
		"name": "Bugbear",
		"tier": "Mid-tier",
		"intended_level": 17,
		"figure_kind": "bugbear",
		"health": 50,
		"damage": 6,
		"range": 1.5,
		"move": 6.0,       # 6 spaces / 4 tempo
		"xp": 20,
		"color": Color(0.36, 0.30, 0.22),
	},
	"INFECTED_HUNTER": {
		"name": "Infected Hunter",
		"tier": "Mid-tier",
		"intended_level": 16,
		"figure_kind": "infected_hunter",
		"health": 40,
		"damage": 8,         # AOE swipe in front
		"range": 1.5,
		"move": 2.0,       # 2 spaces / 3 tempo
		"aggro": 12.0,        # so it can hook from range 7
		"xp": 18,
		"color": Color(0.40, 0.50, 0.30),
	},
	"GIANT_HAWK": {
		"name": "Giant Hawk",
		"tier": "Mid-tier",
		"intended_level": 15,
		"figure_kind": "giant_hawk",
		"health": 28,
		"damage": 9,
		"range": 2.0,
		"move": 8.0,       # 8 spaces / 3 tempo
		"xp": 14,
		"immune_to_high_ground": true,
		"attack_blind_chance": 0.2,
		"color": Color(0.50, 0.38, 0.24),
	},
	"TREANT": {
		"name": "Treant",
		"tier": "Elite",
		"intended_level": 19,
		"figure_kind": "treant",
		"health": 110,
		"damage": 14,
		"range": 1.5,
		"move": 9.0,       # 9 spaces / 10 tempo
		"aggro": 12.0,
		"xp": 35,
		"damage_type": DamageTypes.Type.EARTH,
		"resists": [25, -10, 55],  # burns easily; grounded against lightning
		"color": Color(0.32, 0.42, 0.20),
	},
	"ICE_MAGE": {
		"name": "Ice Mage",
		"tier": "Mid-tier",
		"intended_level": 15,
		"figure_kind": "ice_mage",
		"health": 40,
		"damage": 6,
		"range": 3.0,
		"move": 3.0,       # 3 spaces / 5 tempo
		"xp": 14,
		"damage_type": DamageTypes.Type.ICE,
		# (Frost Bolt hardcodes its 1 Slow in _execute_action.)
		"color": Color(0.55, 0.75, 0.95),
	},
	"FIRE_MAGE": {
		"name": "Fire Mage",
		"tier": "Mid-tier",
		"intended_level": 15,
		"figure_kind": "fire_mage",
		"health": 32,
		"damage": 7,
		"range": 2.0,
		"move": 2.0,       # 2 spaces / 3 tempo
		"xp": 14,
		"damage_type": DamageTypes.Type.FIRE,
		"attack_burn": 2,
		"color": Color(0.90, 0.35, 0.20),
	},
	"SPARK_MAGE": {
		"name": "Spark Mage",
		"tier": "Mid-tier",
		"intended_level": 13,
		"figure_kind": "spark_mage",
		"health": 16,
		"damage": 3,
		"range": 6.0,
		"move": 2.0,       # 2 spaces / 3 tempo
		"xp": 8,
		"damage_type": DamageTypes.Type.LIGHTNING,
		"attack_shock": 1,
		"color": Color(0.85, 0.85, 0.40),
	},
	"AIR_MAGE": {
		"name": "Air Mage",
		"tier": "Mid-tier",
		"intended_level": 14,
		"figure_kind": "air_mage",
		"health": 30,
		"damage": 5,
		"range": 8.0,
		"move": 6.0,       # 6 spaces / 3 tempo
		"xp": 12,
		"damage_type": DamageTypes.Type.WIND,
		"color": Color(0.70, 0.85, 0.80),
	},
	"EARTH_MAGE": {
		"name": "Earth Mage",
		"tier": "Mid-tier",
		"intended_level": 17,
		"figure_kind": "earth_mage",
		"health": 65,
		"damage": 9,
		"range": 1.5,
		"move": 5.0,       # 5 spaces / 5 tempo
		"xp": 18,
		"damage_type": DamageTypes.Type.EARTH,
		"armor_per_hit": 4,
		"color": Color(0.45, 0.35, 0.25),
	},
	# ===================== GRAVEYARD ACT =====================
	"ZOMBIE": {
		"name": "Zombie",
		"tier": "Trash",
		"intended_level": 7,
		"figure_kind": "zombie",
		"health": 12,
		"damage": 5,
		"range": 1.5,
		"move": 3.0,
		"xp": 5,
		"color": Color(0.49, 0.57, 0.40),
	},
	"WEREWOLF": {
		"name": "Werewolf",
		"tier": "Elite",
		"intended_level": 10,
		"figure_kind": "werewolf",
		"health": 55,
		"damage": 10,        # +3 vs armor (armour-piercing)
		"range": 1.5,
		"move": 3.0,
		"aggro": 12.0,
		"xp": 22,
		"resists": [25, 25, 25],
		"color": Color(0.44, 0.45, 0.47),
	},
	"WERERABBIT": {
		"name": "Wererabbit",
		"tier": "Trash",
		"intended_level": 8,
		"figure_kind": "wererabbit",
		"health": 25,
		"damage": 0,         # Loot monster — never attacks
		"range": 0.0,
		"move": 2.0,
		"xp": 8,
		"color": Color(0.72, 0.70, 0.65),
	},
	"VAMPIRE": {
		"name": "Vampire",
		"tier": "Elite",
		"intended_level": 10,
		"figure_kind": "vampire",
		"health": 95,
		"damage": 10,        # Life steal on health damage
		"range": 1.5,
		"move": 5.0,
		"xp": 24,
		"resists": [10, 10, 10],
		"color": Color(0.16, 0.15, 0.20),
	},
	"NECROMANCER": {
		"name": "Necromancer",
		"tier": "Elite",
		"intended_level": 11,
		"figure_kind": "necromancer",
		"health": 60,
		"damage": 4,
		"range": 10.0,
		"move": 8.0,
		"aggro": 14.0,
		"xp": 30,
		"resists": [0, 15, 15],
		"color": Color(0.12, 0.11, 0.16),
	},
	"BONE_DRAGON": {
		"name": "Bone Dragon",
		"tier": "Boss",
		"intended_level": 12,
		"figure_kind": "bone_dragon",
		"health": 150,
		"damage": 12,
		"range": 1.5,
		"move": 5.0,
		"aggro": 14.0,
		"xp": 80,
		"resists": [45, 45, 0],
		"color": Color(0.91, 0.89, 0.84),
	},
	"SPIRIT_COLLECTOR": {
		"name": "Spirit Collector",
		"tier": "Mid-tier",
		"intended_level": 10,
		"figure_kind": "spirit_collector",
		"health": 50,
		"damage": 8,
		"range": 1.5,
		"move": 3.0,
		"xp": 20,
		"color": Color(0.60, 0.52, 0.33),
	},
	"GRAVE_TITAN": {
		"name": "Grave Titan",
		"tier": "Elite",
		"intended_level": 12,
		"figure_kind": "grave_titan",
		"health": 130,
		"armor": 30,
		"damage": 15,
		"range": 1.5,
		"move": 4.0,
		"aggro": 12.0,
		"xp": 80,
		"color": Color(0.84, 0.85, 0.87),
	},
	"CRYPT_CRAWLER": {
		"name": "Crypt Crawler",
		"tier": "Mid-tier",
		"intended_level": 8,
		"figure_kind": "crypt_crawler",
		"health": 28,
		"damage": 6,
		"range": 1.5,
		"move": 3.0,
		"xp": 12,
		"color": Color(0.20, 0.17, 0.22),
	},
	"SCREECHER": {
		"name": "Screecher",
		"tier": "Trash",
		"intended_level": 8,
		"figure_kind": "screecher",
		"health": 14,
		"damage": 5,
		"range": 1.5,
		"move": 4.0,       # 4 spaces / 2 tempo while invisible
		"xp": 8,
		"color": Color(0.07, 0.07, 0.10),
	},
	"CONSUMED": {
		"name": "The Consumed",
		"tier": "Mid-tier",
		"intended_level": 9,
		"figure_kind": "consumed",
		"health": 35,
		"damage": 8,
		"range": 1.5,
		"move": 5.0,       # 5 spaces / 3 tempo
		"xp": 14,
		"color": Color(0.35, 0.29, 0.28),
	},
	# ===================== SEWER ACT =====================
	"SLUDGE": {
		"name": "Sludge Being",
		"tier": "Trash",
		"intended_level": 2,
		"figure_kind": "sludge",
		"health": 10,
		"damage": 3,
		"range": 6.0,        # Can spit at range
		"move": 3.0,
		"xp": 4,
		"color": Color(0.25, 0.63, 0.36),
	},
	"PIPE_CRAWLER": {
		"name": "Pipe Crawler",
		"tier": "Trash",
		"intended_level": 3,
		"figure_kind": "pipe_crawler",
		"health": 20,
		"damage": 5,
		"range": 1.5,
		"move": 2.0,
		"xp": 8,
		"color": Color(0.48, 0.54, 0.43),
	},
	"SEWER_CROC": {
		"name": "Sewer Cobra",
		"tier": "Mid-tier",
		"intended_level": 5,
		"figure_kind": "sewer_croc",
		"health": 40,
		"armor": 20,
		"damage": 12,
		"range": 1.5,
		"move": 2.0,
		"aggro": 12.0,
		"xp": 25,
		"color": Color(0.27, 0.38, 0.23),
	},
	"RAT_KING": {
		"name": "Rat King",
		"tier": "Boss",
		"intended_level": 5,
		"figure_kind": "rat_king",
		"health": 90,
		"armor": 10,
		"damage": 6,
		"range": 1.5,
		"move": 2.0,
		"xp": 60,
		"color": Color(0.5, 0.35, 0.2),
	},
	"SWARM": {
		"name": "Swarm",
		"tier": "Trash",
		"intended_level": 3,
		"figure_kind": "swarm",
		"health": 10,
		"damage": 3,
		"range": 1.5,
		"move": 8.0,       # 8 spaces / 3 tempo — very fast
		"xp": 4,
		"color": Color(0.18, 0.16, 0.13),
	},
	# ===================== MOUNTAINS ACT (elite first pass) =====================
	"ICE_TROLL": {
		"name": "Ice Troll",
		"tier": "Elite",
		"intended_level": 22,
		"figure_kind": "ice_troll",
		"health": 150,
		"armor": 55,
		"damage": 13,        # Club; Clobber (auto on freeze) deals 50
		"range": 1.5,
		"move": 3.0,       # 3 spaces / 3 tempo
		"aggro": 12.0,
		"xp": 45,
		"resists": [35, 15, 15],
		"color": Color(0.62, 0.78, 0.88),
	},
	"WHITE_MANTICORE": {
		"name": "White Manticore",
		"tier": "Elite",
		"intended_level": 23,
		"figure_kind": "white_manticore",
		"health": 75,
		"armor": 15,
		"damage": 15,        # Bite; Stinger deals 25
		"range": 1.5,
		"move": 3.0,       # 3 spaces / 2 tempo
		"aggro": 12.0,
		"xp": 40,
		"immune_to_high_ground": true,  # bat wings
		"resists": [10, 35, 10],
		"color": Color(0.88, 0.88, 0.92),
	},
	"WYVERN": {
		"name": "Wyvern",
		"tier": "Elite",
		"intended_level": 21,
		"figure_kind": "wyvern",
		"health": 125,
		"damage": 25,        # Bite; Talon Grab also deals 25
		"range": 1.5,
		"move": 6.0,       # 6 spaces / 4 tempo
		"aggro": 14.0,
		"xp": 40,
		"immune_to_high_ground": true,  # flier
		"resists": [25, 35, 25],
		"color": Color(0.35, 0.45, 0.30),
	},
	# ===================== MOUNTAINS ACT (second pass — the enemy sheet) =====================
	"WEREGOAT": {
		"name": "Weregoat",
		"tier": "Mid-tier",
		"intended_level": 22,
		"figure_kind": "weregoat",
		"health": 80,
		"damage": 6,         # Hoof Punch; Charge deals 8 along its path
		"range": 1.5,
		"move": 2.0,       # 2 spaces / 5 tempo
		"aggro": 12.0,
		"xp": 20,
		"color": Color(0.55, 0.5, 0.45),
	},
	"ROC": {
		"name": "Roc",
		"tier": "Mid-tier",
		"intended_level": 22,
		"figure_kind": "roc",
		"health": 25,
		"armor": 15,
		"damage": 8,         # Dive Bomb (the sheet gives no number — first-pass 8)
		"range": 1.5,
		"move": 1.0,       # 1 space / 1 tempo, always AWAY from the player
		"aggro": 12.0,
		"xp": 16,
		"immune_to_high_ground": true,  # flier
		"color": Color(0.85, 0.75, 0.6),
	},
	"SABERTOOTH": {
		"name": "Sabertooth Tiger",
		"tier": "Mid-tier",
		"intended_level": 21,
		"figure_kind": "sabertooth",
		"health": 45,
		"damage": 6,         # Bite 6 then Claw 3; Sunken Bite 10 + 8 Bleed
		"range": 1.5,
		"move": 2.0,       # 2 spaces / 2 tempo
		"aggro": 12.0,
		"xp": 18,
		"color": Color(0.8, 0.65, 0.4),
	},
	"SNOW_WRAITH": {
		"name": "Snow Wraith",
		"tier": "Trash",
		"intended_level": 20,
		"figure_kind": "snow_wraith",
		"health": 10,
		"damage": 5,         # Ice Blast; Snowball deals no damage
		"range": 5.0,        # the sheet gives no range — thrown, so ranged 5
		"move": 3.0,       # 3 spaces / 5 tempo
		"aggro": 12.0,
		"xp": 8,
		"damage_type": DamageTypes.Type.ICE,
		"color": Color(0.8, 0.9, 1.0),
	},
	"GRANITE_COLOSSUS": {
		# Stats from the sheet; its moves are still TBD, so it stands.
		"name": "Granite Colossus",
		"tier": "Boss",
		"intended_level": 25,
		"figure_kind": "granite_colossus",
		"health": 350,
		"armor": 250,
		"damage": 0,
		"range": 1.5,
		"move": 3.0,       # 3 spaces / 5 tempo
		"aggro": 12.0,
		"xp": 120,
		"resists": [65, 50, 50],
		"color": Color(0.5, 0.5, 0.52),
	},
	# ===================== UNDERWORLD ACT (elite first pass) =====================
	"IFRIT": {
		"name": "Ifrit",
		"tier": "Elite",
		"intended_level": 28,
		"figure_kind": "ifrit",
		"health": 225,
		"damage": 45,        # Fire Breath deals 20 + 5 burn in a 5x5
		"range": 1.5,
		"move": 5.0,       # 5 spaces / 4 tempo
		"aggro": 14.0,
		"xp": 70,
		"resists": [20, 15, 15],
		"color": Color(0.85, 0.30, 0.10),
	},
	"INFLAMED_MINOTAUR": {
		"name": "Inflamed Minotaur",
		"tier": "Boss",
		"intended_level": 9,
		"figure_kind": "inflamed_minotaur",
		"health": 350,
		"armor": 100,
		"damage": 35,        # + 2 burn per hit
		"range": 1.5,
		"move": 6.0,       # 6 spaces / 5 tempo
		"aggro": 16.0,
		"xp": 90,
		"attack_burn": 2,
		"resists": [15, 50, 25],
		"color": Color(0.55, 0.18, 0.08),
	},
	# ===================== HEAVENS ACT (elite first pass) =====================
	"DJINN": {
		"name": "Djinn",
		"tier": "Elite",
		"intended_level": 35,
		"figure_kind": "djinn",
		"health": 180,
		"damage": 35,        # Chain lightning, per unit hit
		"range": 5.0,        # initial cast range 5; bounces reach 4
		"move": 8.0,       # 8 spaces / 3 tempo
		"aggro": 14.0,
		"xp": 80,
		"damage_type": DamageTypes.Type.LIGHTNING,
		"resists": [15, 15, 15],
		"color": Color(0.25, 0.45, 0.85),
	},
	"CHERUB": {
		"name": "Cherub",
		"tier": "Trash",
		"intended_level": 33,
		"figure_kind": "cherub",
		"health": 14,
		"armor": 5,
		"damage": 2,         # Love's Arrow
		"range": 4.0,
		"move": 2.0,       # 2 spaces / 3 tempo
		"aggro": 12.0,
		"xp": 10,
		"immune_to_high_ground": true,  # winged
		"color": Color(1.0, 0.9, 0.8),
	},
	# ===================== UNDERWORLD ACT (second pass — the enemy sheet) =====================
	"DEMON": {
		"name": "Demon",
		"tier": "Mid-tier",
		"intended_level": 28,
		"figure_kind": "demon",
		"health": 65,
		"damage": 8,
		"range": 1.5,
		"move": 2.0,       # 2 spaces / 2 tempo
		"aggro": 12.0,
		"xp": 24,
		"color": Color(0.7, 0.15, 0.1),
	},
	"ASH_HARPY": {
		"name": "Ash Harpy",
		"tier": "Trash",
		"intended_level": 26,
		"figure_kind": "ash_harpy",
		"health": 6,
		"damage": 3,         # Peck
		"range": 1.5,
		"move": 1.0,       # 1 space / 1 tempo
		"aggro": 12.0,
		"xp": 4,
		"immune_to_high_ground": true,  # flier
		"color": Color(0.4, 0.38, 0.36),
	},
	"MAGMA_SPIDER": {
		"name": "Magma Spider",
		"tier": "Trash",
		"intended_level": 26,
		"figure_kind": "magma_spider",
		"health": 4,
		"damage": 1,         # its Fire Web ticks 1 every 3 tempo
		"range": 1.5,
		"move": 0.0,       # never moves
		"aggro": 8.0,
		"xp": 3,
		"damage_type": DamageTypes.Type.FIRE,
		"color": Color(0.8, 0.3, 0.1),
	},
	"MIND_EATER": {
		"name": "Mind Eater",
		"tier": "Trash",
		"intended_level": 27,
		"figure_kind": "mind_eater",
		"health": 20,
		"damage": 0,         # it never strikes — it taxes and cuffs
		"range": 6.0,        # the sheet gives no range — a caster's 6
		"move": 0.0,       # never moves
		"aggro": 12.0,
		"xp": 12,
		"color": Color(0.6, 0.5, 0.55),
	},
	"SPECTER": {
		"name": "Specter",
		"tier": "Trash",
		"intended_level": 26,
		"figure_kind": "specter",
		"health": 10,
		"damage": 2,         # Spirit Spit
		"range": 2.0,
		"move": 1.0,       # 1 space / 1 tempo
		"aggro": 10.0,
		"xp": 4,
		"color": Color(0.2, 0.2, 0.3),
	},
	"SUCCUBUS": {
		"name": "Succubus",
		"tier": "Trash",
		"intended_level": 27,
		"figure_kind": "succubus",
		"health": 25,
		"armor": 5,
		"damage": 4,         # Damaging Snap: missing mana / 20 + 4
		"range": 4.0,        # the sheet gives no range — a caster's 4
		"move": 1.0,       # 1 space / 2 tempo
		"aggro": 12.0,
		"xp": 14,
		"color": Color(0.6, 0.2, 0.5),
	},
	"DUMMY": {
		# Dojo training dummy: a fat health pool so big hits read as
		# numbers instead of kills; a lethal blow refills it (take_damage).
		"name": "Training Dummy",
		"tier": "Special",
		"figure_kind": "chicken",
		"health": 500,
		"damage": 0,
		"range": 0.0,
		"move": 0.0,
		"aggro": 0.0,
		"xp": 0,
		"is_training_dummy": true,
		"color": Color(0.9, 0.9, 0.85),
	},
	"RAT_NEST": {
		# Rat King's Lair: a heap of straw and bones. A structure, not a
		# creature — it holds its tile, never acts, and counts for nothing
		# (no XP, no loot, and the wave does not wait on it).
		"name": "Rat Nest",
		"tier": "Special",
		"figure_kind": "rat_nest",
		"loot_tier": DropRates.TIER_TRASH,  # the one type whose loot tier is not its sheet tier
		"health": 15,
		"armor": 0,
		"damage": 0,
		"range": 0.0,
		"move": 0.0,
		"aggro": 0.0,
		"xp": 0,
		"is_structure": true,
		"color": Color(0.55, 0.42, 0.25),
	},
	"GRAVESTONE": {
		# The Boneyard: a headstone. A structure — it holds its tile and
		# counts for nothing — but every one left standing regenerates
		# the Bone Dragon 1 health a cycle.
		"name": "Gravestone",
		"tier": "Special",
		"figure_kind": "gravestone",
		"health": 10,
		"armor": 0,
		"damage": 0,
		"range": 0.0,
		"move": 0.0,
		"aggro": 0.0,
		"xp": 0,
		"is_structure": true,
		"color": Color(0.55, 0.58, 0.55),
	},
	"CERBERUS": {
		# The guardian of Hell's Door (design sheet): 250 HP, 50 armor,
		# 25-damage bites, 6 spaces a move, resists 30% physical / 40%
		# fire / 15% lightning. Three heads wake as he weakens; Guardian
		# of Death and Deathyard Dog below.
		"name": "Cerberus",
		"tier": "Boss",
		"intended_level": 10,
		"figure_kind": "cerberus",
		"health": 250,
		"armor": 50,
		"damage": 25,
		"range": 1.5,
		"move": 6.0,       # 6 spaces / 3 tempo
		"aggro": 16.0,
		"xp": 150,
		"resists": [30, 40, 15],
		"color": Color(0.3, 0.1, 0.12),
	},
	"HELL_DOOR": {
		# Hell's Door: the objective, not a creature. A structure the
		# player breaks through; at 75%, 50% and 33% it seals itself
		# against all damage for 10 tempo. Counts as Cerberus's ally.
		"name": "Hell's Door",
		"tier": "Special",
		"figure_kind": "hell_door",
		"health": 150,
		"armor": 0,
		"damage": 0,
		"range": 0.0,
		"move": 0.0,
		"aggro": 0.0,
		"xp": 0,
		"is_structure": true,
		"color": Color(0.2, 0.08, 0.08),
	},
	"GRAVE_DIGGER": {
		# The Boneyard: walks out of the crypt to a broken gravestone,
		# takes 8 tempo to set it right (back to full), and is gone.
		# Never fights; can be cut down on the way (20 HP).
		"name": "Grave Digger",
		"tier": "Special",
		"intended_level": 8,
		"figure_kind": "grave_digger",
		"health": 20,
		"armor": 0,
		"damage": 0,
		"range": 0.0,
		"move": 6.0,       # 6 spaces / 2 tempo: he hurries to the stone
		"aggro": 0.0,
		"xp": 6,
		"color": Color(0.5, 0.55, 0.45),
	},
	# Design mock-ups (stats & moves TBD): named, tiered and given a figure for
	# the compendium and the lab; initialize() only names them and warns.
	"PIT_FIEND": {
		"mockup": true,
		"name": "Pit Fiend",
		"tier": "Boss",
		"figure_kind": "pit_fiend",
	},
	"CORRUPTED_ARCHANGEL": {
		"mockup": true,
		"name": "Corrupted Archangel",
		"tier": "Boss",
		"figure_kind": "corrupted_archangel",
	},
}
