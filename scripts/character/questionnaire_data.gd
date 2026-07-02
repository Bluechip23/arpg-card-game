class_name QuestionnaireData
extends RefCounted

## Character questionnaire - 11 personality questions that build a unique custom character.
## Each answer contributes +1 stat bonus (10 total across 11 questions) and archetype affinity.
## The final character gets custom stats, a deck of 20 cards (7 slash, 6 block, 2 heal,
## 1 draw, 1 discard, 1 energy from base + 2 quiz cards), and an existing starting
## item/passive/slot specialty from one of the 5 characters.
## Nothing is invented - all cards, items, passives, and slots come from existing characters.

## Archetypes map directly to existing characters:
## WARRIOR = Brad, ROGUE = Ryan, MAGE = Jeremy, ARCHER = Stephen, MONK = Cory
enum Archetype { WARRIOR, ROGUE, MAGE, ARCHER, MONK }

static func get_questions() -> Array[Dictionary]:
	# Each answer has:
	#   "text" - display text
	#   "stats" - stat bonuses: { "strength": 1, "dexterity": 2, etc. }
	#   "archetypes" - archetype affinity: { Archetype.WARRIOR: 2, etc. }
	# Each answer gives +1 to exactly one stat. 10 of 11 questions give stats (10 total).
	# The last question only affects archetype affinity.
	return [
		{
			"question": "When facing a challenge, your first instinct is to...",
			"answers": [
				{"text": "Charge in head-first",
					"stats": {"strength": 1},
					"archetypes": {Archetype.WARRIOR: 2, Archetype.MONK: 1}},
				{"text": "Plan carefully before acting",
					"stats": {"intelligence": 1},
					"archetypes": {Archetype.ARCHER: 2, Archetype.MAGE: 1}},
				{"text": "Find a creative workaround",
					"stats": {"dexterity": 1},
					"archetypes": {Archetype.ROGUE: 2, Archetype.MAGE: 1}},
				{"text": "Seek allies to help",
					"stats": {"wisdom": 1},
					"archetypes": {Archetype.MONK: 1, Archetype.WARRIOR: 1, Archetype.ARCHER: 1}},
			],
		},
		{
			"question": "What matters most in a companion?",
			"answers": [
				{"text": "Loyalty",
					"stats": {"determination": 1},
					"archetypes": {Archetype.WARRIOR: 2, Archetype.MONK: 1}},
				{"text": "Intelligence",
					"stats": {"intelligence": 1},
					"archetypes": {Archetype.MAGE: 2, Archetype.ARCHER: 1}},
				{"text": "Strength",
					"stats": {"strength": 1},
					"archetypes": {Archetype.MONK: 2, Archetype.WARRIOR: 1}},
				{"text": "Independence",
					"stats": {"agility": 1},
					"archetypes": {Archetype.ROGUE: 2, Archetype.ARCHER: 1}},
			],
		},
		{
			"question": "What's your biggest fear?",
			"answers": [
				{"text": "Being powerless",
					"stats": {"strength": 1},
					"archetypes": {Archetype.WARRIOR: 2, Archetype.MONK: 1}},
				{"text": "Being alone",
					"stats": {"wisdom": 1},
					"archetypes": {Archetype.MAGE: 1, Archetype.WARRIOR: 1}},
				{"text": "Being forgotten",
					"stats": {"dexterity": 1},
					"archetypes": {Archetype.ARCHER: 2, Archetype.ROGUE: 1}},
				{"text": "Being wrong",
					"stats": {"intelligence": 1},
					"archetypes": {Archetype.MAGE: 2, Archetype.MONK: 1}},
			],
		},
		{
			"question": "How do you handle failure?",
			"answers": [
				{"text": "Get back up immediately",
					"stats": {"determination": 1},
					"archetypes": {Archetype.WARRIOR: 2, Archetype.MONK: 1}},
				{"text": "Analyze what went wrong",
					"stats": {"intelligence": 1},
					"archetypes": {Archetype.ARCHER: 2, Archetype.MAGE: 1}},
				{"text": "Change approach entirely",
					"stats": {"agility": 1},
					"archetypes": {Archetype.ROGUE: 2, Archetype.MAGE: 1}},
				{"text": "Seek help from others",
					"stats": {"wisdom": 1},
					"archetypes": {Archetype.MONK: 1, Archetype.WARRIOR: 1}},
			],
		},
		{
			"question": "What legacy do you want to leave?",
			"answers": [
				{"text": "Stories of bravery",
					"stats": {"determination": 1},
					"archetypes": {Archetype.WARRIOR: 2, Archetype.MONK: 1}},
				{"text": "Knowledge and wisdom",
					"stats": {"wisdom": 1},
					"archetypes": {Archetype.MAGE: 2, Archetype.ARCHER: 1}},
				{"text": "A better world for everyone",
					"stats": {"agility": 1},
					"archetypes": {Archetype.MONK: 2, Archetype.ARCHER: 1}},
				{"text": "Personal mastery of your craft",
					"stats": {"dexterity": 1},
					"archetypes": {Archetype.ROGUE: 2, Archetype.MONK: 1}},
			],
		},
		{
			"question": "If you were the dictator of a country, you would prioritize:",
			"answers": [
				{"text": "Equality",
					"stats": {"wisdom": 1},
					"archetypes": {Archetype.MONK: 2, Archetype.WARRIOR: 1}},
				{"text": "Individual agency",
					"stats": {"agility": 1},
					"archetypes": {Archetype.ARCHER: 2, Archetype.ROGUE: 1}},
				{"text": "Power",
					"stats": {"strength": 1},
					"archetypes": {Archetype.WARRIOR: 2, Archetype.MAGE: 1}},
				{"text": "I would give up the throne",
					"stats": {"dexterity": 1},
					"archetypes": {Archetype.ROGUE: 2, Archetype.MAGE: 1}},
			],
		},
		{
			"question": "What kind of puzzles are most exciting to you?",
			"answers": [
				{"text": "Competitive - Chess",
					"stats": {"intelligence": 1},
					"archetypes": {Archetype.MONK: 2, Archetype.ARCHER: 1}},
				{"text": "Repetitive, but complicated - Tetris",
					"stats": {"determination": 1},
					"archetypes": {Archetype.WARRIOR: 2, Archetype.ROGUE: 1}},
				{"text": "Clue and people oriented - Escape rooms",
					"stats": {"dexterity": 1},
					"archetypes": {Archetype.ROGUE: 2, Archetype.MONK: 1}},
				{"text": "Verbal - Poetry or philosophy",
					"stats": {"wisdom": 1},
					"archetypes": {Archetype.MAGE: 2, Archetype.ARCHER: 1}},
			],
		},
		{
			"question": "If you could have any pet, what would it be?",
			"answers": [
				{"text": "Lion",
					"stats": {"strength": 1},
					"archetypes": {Archetype.WARRIOR: 2, Archetype.MONK: 1}},
				{"text": "Rhinoceros",
					"stats": {"determination": 1},
					"archetypes": {Archetype.MONK: 2, Archetype.WARRIOR: 1}},
				{"text": "Falcon",
					"stats": {"dexterity": 1},
					"archetypes": {Archetype.ARCHER: 2, Archetype.ROGUE: 1}},
				{"text": "Monkey",
					"stats": {"agility": 1},
					"archetypes": {Archetype.MAGE: 2, Archetype.ROGUE: 1}},
			],
		},
		{
			"question": "Where would you most like to live?",
			"answers": [
				{"text": "Above ground, on land",
					"stats": {"strength": 1},
					"archetypes": {Archetype.WARRIOR: 2, Archetype.MONK: 1}},
				{"text": "In the air",
					"stats": {"agility": 1},
					"archetypes": {Archetype.ARCHER: 2, Archetype.MAGE: 1}},
				{"text": "Underground",
					"stats": {"dexterity": 1},
					"archetypes": {Archetype.ROGUE: 2, Archetype.MONK: 1}},
				{"text": "Underwater",
					"stats": {"intelligence": 1},
					"archetypes": {Archetype.MAGE: 2, Archetype.ARCHER: 1}},
			],
		},
		{
			"question": "If you were at a party, would you...",
			"answers": [
				{"text": "Be the life of it",
					"stats": {"determination": 1},
					"archetypes": {Archetype.WARRIOR: 2, Archetype.MAGE: 1}},
				{"text": "Find particular people you want to speak with",
					"stats": {"intelligence": 1},
					"archetypes": {Archetype.ARCHER: 2, Archetype.MONK: 1}},
				{"text": "Keep to yourself, wait for people to join you",
					"stats": {"agility": 1},
					"archetypes": {Archetype.ROGUE: 2, Archetype.ARCHER: 1}},
				{"text": "Ignore the people, be there for the goodies",
					"stats": {"dexterity": 1},
					"archetypes": {Archetype.MAGE: 2, Archetype.ROGUE: 1}},
			],
		},
		{   # Q11: archetype only, no stat bonus (keeps total at 10)
			"question": "What would be most offending to you?",
			"answers": [
				{"text": "Calling you stupid",
					"stats": {},
					"archetypes": {Archetype.MAGE: 2, Archetype.ARCHER: 1}},
				{"text": "Someone scolding a kid who is not yours",
					"stats": {},
					"archetypes": {Archetype.WARRIOR: 2, Archetype.MONK: 1}},
				{"text": "Challenging your individual commitment to something",
					"stats": {},
					"archetypes": {Archetype.MONK: 2, Archetype.ROGUE: 1}},
				{"text": "Breaking your trust",
					"stats": {},
					"archetypes": {Archetype.ROGUE: 2, Archetype.WARRIOR: 1}},
			],
		},
	]

# ---- Card pools by archetype ----
# Includes ALL playable cards from the game, categorized by archetype.
# Starting deck cards + all non-deck cards distributed by theme/mechanics.
# Excludes token/status cards generated by other cards (minor_wounds, lightly_dazed,
# quick_arrow, energy_ball, shuriken) and base deck cards (slash, block, heal, etc.).

static func _get_card_pool() -> Dictionary:
	return {
		Archetype.WARRIOR: [  # Tanky, protective, melee, armor, survival
			# Brad's starting cards
			"life_swap", "wear_down", "taunt", "life_steal", "roar",
			"poke", "armor_break", "charge", "heroic_leap", "morphine",
			"turtle_up", "parry", "approach", "hold_the_line",
			# Additional warrior cards
			"reckless_strike",       # 15 dmg, adds Minor Wounds (aggressive tank)
			"smith_thy_soul",        # Armor = half (HP + mana) (tanky)
			"armored_discipline",    # Maintain: dmg taken becomes armor (tank)
			"shield_ready",          # 5 armor now, 5 more in 5 tempo (defensive)
			"repelled_block",        # 5 armor, pushback if fully blocked (tank)
			"shield_of_growth",      # Damage taken becomes armor, disarms (tank)
			"down_but_not_out",      # Heal per debuff stack (survival)
			"armor_patch",           # On draw: 3 armor + cleanse (defensive)
			"cover",                 # Reduce ally damage by hand size (protective)
			"fortify_alliance",      # Heal ally 5, gain 5 armor (support tank)
			"gift_from_the_phoenix", # Below 50% HP: heal to 80%, burn enemy (survival)
		],
		Archetype.ROGUE: [  # Poison, stealth, tricks, self-damage, alchemy
			# Ryan's starting cards
			"raged_circulation", "poisoned_blood", "elixir",
			"shadows", "preparation", "exacerbate_wounds", "reposition",
			"dagger_throw", "volatile_mixture", "understanding",
			"shuriken_pouch", "premeditated",
			# Additional rogue cards
			"blade_barrage",     # X*10 dmg where X = attack cards in hand (burst)
			"cultish_wounds",    # Maintain: deal 1 self-dmg every 5 tempo (self-harm)
			"bloodlust",         # 3 Vulnerable + 3 mana + 3 Strengthen (risky buff)
			"demonic_rage",      # Next 5 mana uses cost HP instead (dark power)
			"self_infliction",   # 80% HP self-dmg, gain 5 DET + 5 STR (high risk)
			"gulped_potion",     # Heal 1 three times (alchemy)
			"healing_potion",    # Heal effect (alchemy)
		],
		Archetype.MAGE: [  # Chance, magic, risk-reward, delayed combos
			# Jeremy's starting cards
			"trick_shot", "surrounding_ice", "risk_it", "biscuit",
			"loaded_die", "worst_that_could_happen", "oops", "house_money",
			"hope_this_works", "lady_luck", "try_this", "if_pigs_could_fly",
			"snowballs_chance",
			# Additional mage cards
			"fountain_of_life",  # Maintain: 2 self-dmg + draw card per cycle (risk)
			"absorb_essence",    # 1 dmg to ALL, then get Energy Ball (AoE combo)
			"petey_the_pet_rock", # On draw: draw 3, on discard: discard 2 (chaotic)
			"lethal_recall",     # Trigger last instant effect 2x (combo/meta)
		],
		Archetype.ARCHER: [  # Ranged, precision, arrows, positioning
			# Stephen's starting cards
			"mark", "rise", "quick_shot", "reload", "enchanted_quiver",
			"tighten_string", "down_town", "barricade", "sky_fall",
			"sky_attack", "lead_arrow", "last_breath", "mixed_bag",
			"bottomless_quiver",
			# Additional archer cards
			"collect_arrows",  # Put 2 attack cards from discard to hand (recovery)
			"thrown_stone",    # On draw: 4 dmg to random enemy + 4 dmg (ranged)
		],
		Archetype.MONK: [  # Martial arts, discipline, balance, support
			# Cory's starting cards
			"round_em_up", "trip", "choke", "push", "defensive_awareness",
			"sweeping_disarm", "consecutive_snap", "swap", "meditate",
			# Additional monk cards
			"potion_of_continuance", # Draw 2 cards (focus/flow)
			"spider_senses",         # On take damage: gain 5 armor (reactive defense)
			"bob_and_weave",         # 5 armor + draw card (martial defense)
			"communal_donation",     # Self-dmg to heal allies (selfless)
			"healthy_habit",         # Draw 2, gain 2 mana, Burden (discipline)
			"halo",                  # Maintain: heal all allies in AOE for 3 (support)
		],
	}

# ---- Existing character properties mapped to archetypes ----
# All values below are taken directly from the 5 existing characters in character_data.gd.

static func _get_archetype_passive() -> Dictionary:
	return {
		Archetype.WARRIOR: "Chest items weigh 20% less",               # Brad
		Archetype.ROGUE: "Belt cards cost 1 less mana",                # Ryan
		Archetype.MAGE: "First ring trigger per turn triggers twice",  # Jeremy
		Archetype.ARCHER: "+10% off-hand enchantments (others get -10%)",  # Stephen
		Archetype.MONK: "Gain 1 mana when gauntlet skill comes off cooldown",  # Cory
	}

static func _get_archetype_item_name() -> Dictionary:
	return {
		Archetype.WARRIOR: "Bloodbound Plate",    # Brad
		Archetype.ROGUE: "Adventurer's Belt",      # Ryan
		Archetype.MAGE: "Scholar's Signet",        # Jeremy
		Archetype.ARCHER: "Flickerstep Boots",     # Stephen
		Archetype.MONK: "Grasping Gauntlets",      # Cory
	}

static func _get_archetype_item_description() -> Dictionary:
	return {
		Archetype.WARRIOR: "+2 DET. Overflow: Heal 2. +1 Armor on Armor Gain",  # Brad
		Archetype.ROGUE: "Grants: Healing Potion & Dagger Throw",                # Ryan
		Archetype.MAGE: "+3 INT. +3% chance. On Utility: +1 Mana",              # Jeremy
		Archetype.ARCHER: "+2 DEX. Grants 1 Blink card",                         # Stephen
		Archetype.MONK: "+2 Hand Size. Skill: Power Grip (8 dmg, CD 3, Cost 2)", # Cory
	}

static func _get_archetype_slot_specialty() -> Dictionary:
	return {
		Archetype.WARRIOR: "3 weapon slots",                   # Brad
		Archetype.ROGUE: "4 belt slots",                       # Ryan
		Archetype.MAGE: "4 ring slots",                        # Jeremy
		Archetype.ARCHER: "4 weapon slots, 3 ring slots",     # Stephen
		Archetype.MONK: "2 gauntlet slots",                    # Cory
	}

# ---- Archetype passive paths (skill tree archetypes from each character) ----

static func _get_archetype_paths() -> Dictionary:
	# Each archetype maps to the 4 skill tree paths of its corresponding character.
	# These are the exact archetypes defined in character_data.gd for each character.
	return {
		Archetype.WARRIOR: [  # Brad's 4 paths
			{"name": "Berserker", "description": "Health is simply an inconvenience. Pain is your greatest strength, causing you to get stronger as you edge near death."},
			{"name": "Warden", "description": "Specialize in the art of armor and tactic, finding your weakness is nearly impossible for enemies."},
			{"name": "The Ancient", "description": "Thorns, armor and healing. You have a deep understanding of nature, and you use its essence to your advantage."},
			{"name": "The Fallen", "description": "Once a child of god, your mistakes have left you deserted. You have devoted yourself to find a way back."},
		],
		Archetype.ROGUE: [  # Ryan's 4 paths
			{"name": "Relentless Blade", "description": "Constant pressure, and 1000 cuts is how you fight. Aggression, and lacerations are your north star."},
			{"name": "Light Foot", "description": "Always aware, constantly alert, enemies struggle hitting you, and when they do, your next move is planned."},
			{"name": "Apothecary", "description": "Manipulation of potions and ailments, enemies (and allies) never know what you are throwing at them."},
			{"name": "Shadow Blade", "description": "Hidden in the shadows, weaving in and out of combat, striking enemies when they least expect it, and where they are the weakest."},
		],
		Archetype.MAGE: [  # Jeremy's 4 paths
			{"name": "Evocation", "description": "Master of the elements. Blasting enemies with power is your cup of tea."},
			{"name": "Abjurer", "description": "Defense first is what you were taught. Outlasting, fast recovery, and small strikes is your way to victory."},
			{"name": "Shepherd", "description": "Summoner who focuses on the greater good. Your strength is your selflessness, sometimes sacrificing your own health for your friends."},
			{"name": "Poltergeist", "description": "Master of death and hatred, instilling sheer agony on your enemies is your main objective."},
		],
		Archetype.ARCHER: [  # Stephen's 4 paths
			{"name": "The Apex", "description": "The most efficient and dangerous killer. No tactic is out of question, master of all things offense."},
			{"name": "Sentinel", "description": "Melee engagements are your bread and butter. No one can out duel you, scratching your armor is a feat itself."},
			{"name": "Ranger", "description": "Striking from a distance, manipulating elements and situations to make your arrows and attacks stronger."},
			{"name": "Avenger", "description": "Large, potent, and devastating. Unfortunately you tire quick, making timing and execution vital."},
		],
		Archetype.MONK: [  # Cory's 4 paths
			{"name": "Lurker", "description": "You gain strength from your enemies wounds, becoming stronger as they become weaker, trapping them, or holding them in place, preparing for you to devour."},
			{"name": "Monk", "description": "Immersed in your surroundings, calm, collected. Always ready to help an ally, either directly or by hindering the enemy."},
			{"name": "Druid", "description": "One with the world, you use your surroundings (literally) to aid you in battle."},
			{"name": "Atrophist", "description": "Your touch withers the enemy, making them weaker and frail the longer you are engaged."},
		],
	}

# ---- Title generation ----

static func _get_title_matrix() -> Dictionary:
	# Key: [primary_archetype, secondary_archetype] -> title
	return {
		[Archetype.WARRIOR, Archetype.WARRIOR]: "The Unbreakable",
		[Archetype.WARRIOR, Archetype.ROGUE]: "The Iron Shadow",
		[Archetype.WARRIOR, Archetype.MAGE]: "The Arcane Bulwark",
		[Archetype.WARRIOR, Archetype.ARCHER]: "The Steel Sentinel",
		[Archetype.WARRIOR, Archetype.MONK]: "The Living Fortress",
		[Archetype.ROGUE, Archetype.ROGUE]: "The Phantom",
		[Archetype.ROGUE, Archetype.WARRIOR]: "The Blade Dancer",
		[Archetype.ROGUE, Archetype.MAGE]: "The Shadow Scholar",
		[Archetype.ROGUE, Archetype.ARCHER]: "The Silent Hunter",
		[Archetype.ROGUE, Archetype.MONK]: "The Ghost Hand",
		[Archetype.MAGE, Archetype.MAGE]: "The Archmind",
		[Archetype.MAGE, Archetype.WARRIOR]: "The Battle Sage",
		[Archetype.MAGE, Archetype.ROGUE]: "The Trickweaver",
		[Archetype.MAGE, Archetype.ARCHER]: "The Storm Caller",
		[Archetype.MAGE, Archetype.MONK]: "The Enlightened",
		[Archetype.ARCHER, Archetype.ARCHER]: "The Hawkeye",
		[Archetype.ARCHER, Archetype.WARRIOR]: "The Iron Marksman",
		[Archetype.ARCHER, Archetype.ROGUE]: "The Sharpshade",
		[Archetype.ARCHER, Archetype.MAGE]: "The Arcane Archer",
		[Archetype.ARCHER, Archetype.MONK]: "The Zen Sniper",
		[Archetype.MONK, Archetype.MONK]: "The Grandmaster",
		[Archetype.MONK, Archetype.WARRIOR]: "The Iron Fist",
		[Archetype.MONK, Archetype.ROGUE]: "The Wind Walker",
		[Archetype.MONK, Archetype.MAGE]: "The Spirit Sage",
		[Archetype.MONK, Archetype.ARCHER]: "The Keen Observer",
	}

# ---- Flavor text by primary archetype ----

static func _get_archetype_flavor() -> Dictionary:
	return {
		Archetype.WARRIOR: "You face the world with unshakable resolve. Where others hesitate, you charge forward, shield raised and spirit burning. Your strength protects those who cannot protect themselves.",
		Archetype.ROGUE: "You move through the world like a whisper. Resourceful and adaptable, you prefer cunning over brute force. Every problem has a hidden solution, and you always find it.",
		Archetype.MAGE: "Knowledge is your weapon, curiosity your compass. You see patterns where others see chaos, and you're not afraid to gamble on your intellect to turn the tide.",
		Archetype.ARCHER: "Precision defines you. Patient and calculated, you strike with purpose from a distance. Freedom and self-reliance guide every decision you make.",
		Archetype.MONK: "Discipline is your foundation. You believe mastery comes from within, and every challenge is a chance to grow. Your balanced approach makes you formidable in any situation.",
	}

# ---- Core computation ----

## Given answer indices, build a complete custom character result.
## The starting cards are mixed from two existing character card pools.
## The item, passive, and slot specialty come from one existing character.
static func compute_result(answer_indices: Array[int]) -> Dictionary:
	var questions = get_questions()

	# Accumulate stat bonuses and archetype scores
	var stat_bonuses: Dictionary = {
		"strength": 0, "dexterity": 0, "intelligence": 0,
		"wisdom": 0, "agility": 0, "determination": 0,
	}
	var archetype_scores: Dictionary = {
		Archetype.WARRIOR: 0, Archetype.ROGUE: 0,
		Archetype.MAGE: 0, Archetype.ARCHER: 0, Archetype.MONK: 0,
	}

	for i in range(mini(answer_indices.size(), questions.size())):
		var q = questions[i]
		var chosen = answer_indices[i]
		if chosen >= 0 and chosen < q["answers"].size():
			var answer = q["answers"][chosen]
			for stat_name in answer["stats"]:
				stat_bonuses[stat_name] += answer["stats"][stat_name]
			for arch in answer["archetypes"]:
				archetype_scores[arch] += answer["archetypes"][arch]

	# Find primary and secondary archetypes
	var sorted_archetypes: Array = archetype_scores.keys()
	sorted_archetypes.sort_custom(func(a, b): return archetype_scores[a] > archetype_scores[b])
	var primary: int = sorted_archetypes[0]
	var secondary: int = sorted_archetypes[1]

	# Generate title
	var title_matrix = _get_title_matrix()
	var title: String = title_matrix.get([primary, secondary], "The Adventurer")

	# Build starting_card_ids: 3 extra slash + 3 extra block + 2 quiz cards
	# (base deck already provides 4 slash, 3 block, 2 heal, 1 draw, 1 discard, 1 energy = 12)
	# This brings total to: 7 slash, 6 block, 2 heal, 1 draw, 1 discard, 1 energy, 2 quiz = 20
	var card_pool = _get_card_pool()
	var primary_cards: Array = card_pool[primary].duplicate()
	var secondary_cards: Array = card_pool[secondary].duplicate()
	primary_cards.shuffle()
	secondary_cards.shuffle()

	var starting_card_ids: Array = [
		"slash", "slash", "slash",   # 3 extra slash (base has 4, total = 7)
		"block", "block", "block",   # 3 extra block (base has 3, total = 6)
	]
	# 1 card from primary archetype's pool
	if primary_cards.size() > 0:
		starting_card_ids.append(primary_cards[0])
	# 1 card from secondary archetype's pool (avoid duplicate)
	for j in range(secondary_cards.size()):
		if secondary_cards[j] not in starting_card_ids:
			starting_card_ids.append(secondary_cards[j])
			break

	# Get existing item/passive/slot data from the primary archetype's character
	var item_names = _get_archetype_item_name()
	var item_descs = _get_archetype_item_description()
	var passives = _get_archetype_passive()
	var slot_specs = _get_archetype_slot_specialty()
	var flavors = _get_archetype_flavor()
	var all_paths = _get_archetype_paths()

	# Build 4 passive paths: 2 from primary archetype's character, 2 from secondary
	var primary_paths: Array = all_paths[primary]
	var secondary_paths: Array = all_paths[secondary]
	var chosen_paths: Array = []
	# Take first 2 from primary
	chosen_paths.append(primary_paths[0])
	chosen_paths.append(primary_paths[1])
	if primary == secondary:
		# Same archetype: take all 4 from the same character
		chosen_paths.append(primary_paths[2])
		chosen_paths.append(primary_paths[3])
	else:
		# Take first 2 from secondary
		chosen_paths.append(secondary_paths[0])
		chosen_paths.append(secondary_paths[1])

	return {
		"title": title,
		"primary_archetype": primary,
		"secondary_archetype": secondary,
		"stat_bonuses": stat_bonuses,
		"archetype_scores": archetype_scores,
		"starting_card_ids": starting_card_ids,
		"starting_item_name": item_names[primary],
		"starting_item_description": item_descs[primary],
		"passive_description": passives[primary],
		"slot_specialty": slot_specs[primary],
		"flavor_text": flavors[primary],
		"passive_paths": chosen_paths,
	}

## Build a CharacterData from questionnaire results.
static func build_character(result: Dictionary) -> CharacterData:
	var data = CharacterData.new()
	data.character_name = result["title"]

	# Base stats (5 each) + bonuses from answers
	var bonuses: Dictionary = result["stat_bonuses"]
	data.strength = 5 + bonuses["strength"]
	data.dexterity = 5 + bonuses["dexterity"]
	data.intelligence = 5 + bonuses["intelligence"]
	data.wisdom = 5 + bonuses["wisdom"]
	data.determination = 5 + bonuses["determination"]
	data.agility = 5 + bonuses["agility"]

	# Derived stats (same as all existing characters)
	data.base_health = 5
	data.base_mana = 5
	data.base_mana_regen = 1.0
	data.base_draw_timer = 5
	data.base_hand_size = 5

	# Mixed starting cards from two existing character card pools
	data.starting_card_ids = result["starting_card_ids"]

	# 4 passive paths (skill tree archetypes) based on answers
	data.archetypes = result["passive_paths"]

	# Display info (all from existing characters)
	data.passive_description = result["passive_description"]
	data.starting_item_name = result["starting_item_name"]
	data.starting_item_description = result["starting_item_description"]
	data.slot_specialty = result["slot_specialty"]
	data.sprite_path = ""  # Custom character has no preset sprite

	return data

## Get human-readable archetype name.
static func get_archetype_name(arch: int) -> String:
	match arch:
		Archetype.WARRIOR: return "Warrior"
		Archetype.ROGUE: return "Rogue"
		Archetype.MAGE: return "Mage"
		Archetype.ARCHER: return "Archer"
		Archetype.MONK: return "Monk"
		_: return "Unknown"

## Get the existing character name for an archetype.
static func get_character_for_archetype(arch: int) -> String:
	match arch:
		Archetype.WARRIOR: return "Brad"
		Archetype.ROGUE: return "Ryan"
		Archetype.MAGE: return "Jeremy"
		Archetype.ARCHER: return "Stephen"
		Archetype.MONK: return "Cory"
		_: return "Unknown"
