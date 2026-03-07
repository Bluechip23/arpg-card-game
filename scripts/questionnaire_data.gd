class_name QuestionnaireData
extends RefCounted

## Character questionnaire - 11 personality questions that build a unique custom character.
## Each answer contributes stat bonuses and archetype affinity points.
## The final character gets custom stats, starting cards, a starting item with passive,
## and an auto-generated title based on the dominant archetype combination.

## Archetypes determine card pool and starting item selection.
enum Archetype { WARRIOR, ROGUE, MAGE, ARCHER, MONK }

static func get_questions() -> Array[Dictionary]:
	# Each answer has:
	#   "text" - display text
	#   "stats" - stat bonuses: { "strength": 1, "dexterity": 2, etc. }
	#   "archetypes" - archetype affinity: { Archetype.WARRIOR: 2, etc. }
	return [
		{
			"question": "When facing a challenge, your first instinct is to...",
			"answers": [
				{"text": "Charge in head-first",
					"stats": {"strength": 1, "determination": 1},
					"archetypes": {Archetype.WARRIOR: 2, Archetype.MONK: 1}},
				{"text": "Plan carefully before acting",
					"stats": {"intelligence": 1, "wisdom": 1},
					"archetypes": {Archetype.ARCHER: 2, Archetype.MAGE: 1}},
				{"text": "Find a creative workaround",
					"stats": {"dexterity": 1, "agility": 1},
					"archetypes": {Archetype.ROGUE: 2, Archetype.MAGE: 1}},
				{"text": "Seek allies to help",
					"stats": {"wisdom": 1, "determination": 1},
					"archetypes": {Archetype.MONK: 1, Archetype.WARRIOR: 1, Archetype.ARCHER: 1}},
			],
		},
		{
			"question": "What matters most in a companion?",
			"answers": [
				{"text": "Loyalty",
					"stats": {"determination": 1, "strength": 1},
					"archetypes": {Archetype.WARRIOR: 2, Archetype.MONK: 1}},
				{"text": "Intelligence",
					"stats": {"intelligence": 2},
					"archetypes": {Archetype.MAGE: 2, Archetype.ARCHER: 1}},
				{"text": "Strength",
					"stats": {"strength": 2},
					"archetypes": {Archetype.MONK: 2, Archetype.WARRIOR: 1}},
				{"text": "Independence",
					"stats": {"agility": 1, "dexterity": 1},
					"archetypes": {Archetype.ROGUE: 2, Archetype.ARCHER: 1}},
			],
		},
		{
			"question": "What's your biggest fear?",
			"answers": [
				{"text": "Being powerless",
					"stats": {"strength": 1, "determination": 1},
					"archetypes": {Archetype.WARRIOR: 2, Archetype.MONK: 1}},
				{"text": "Being alone",
					"stats": {"wisdom": 1, "intelligence": 1},
					"archetypes": {Archetype.MAGE: 1, Archetype.WARRIOR: 1}},
				{"text": "Being forgotten",
					"stats": {"dexterity": 1, "agility": 1},
					"archetypes": {Archetype.ARCHER: 2, Archetype.ROGUE: 1}},
				{"text": "Being wrong",
					"stats": {"intelligence": 1, "wisdom": 1},
					"archetypes": {Archetype.MAGE: 2, Archetype.MONK: 1}},
			],
		},
		{
			"question": "How do you handle failure?",
			"answers": [
				{"text": "Get back up immediately",
					"stats": {"determination": 2},
					"archetypes": {Archetype.WARRIOR: 2, Archetype.MONK: 1}},
				{"text": "Analyze what went wrong",
					"stats": {"intelligence": 1, "dexterity": 1},
					"archetypes": {Archetype.ARCHER: 2, Archetype.MAGE: 1}},
				{"text": "Change approach entirely",
					"stats": {"agility": 1, "dexterity": 1},
					"archetypes": {Archetype.ROGUE: 2, Archetype.MAGE: 1}},
				{"text": "Seek help from others",
					"stats": {"wisdom": 2},
					"archetypes": {Archetype.MONK: 1, Archetype.WARRIOR: 1}},
			],
		},
		{
			"question": "What legacy do you want to leave?",
			"answers": [
				{"text": "Stories of bravery",
					"stats": {"strength": 1, "determination": 1},
					"archetypes": {Archetype.WARRIOR: 2, Archetype.MONK: 1}},
				{"text": "Knowledge and wisdom",
					"stats": {"intelligence": 1, "wisdom": 1},
					"archetypes": {Archetype.MAGE: 2, Archetype.ARCHER: 1}},
				{"text": "A better world for everyone",
					"stats": {"wisdom": 1, "agility": 1},
					"archetypes": {Archetype.MONK: 2, Archetype.ARCHER: 1}},
				{"text": "Personal mastery of your craft",
					"stats": {"dexterity": 1, "determination": 1},
					"archetypes": {Archetype.ROGUE: 2, Archetype.MONK: 1}},
			],
		},
		{
			"question": "If you were the dictator of a country, you would prioritize:",
			"answers": [
				{"text": "Equality",
					"stats": {"wisdom": 1, "strength": 1},
					"archetypes": {Archetype.MONK: 2, Archetype.WARRIOR: 1}},
				{"text": "Individual agency",
					"stats": {"agility": 1, "dexterity": 1},
					"archetypes": {Archetype.ARCHER: 2, Archetype.ROGUE: 1}},
				{"text": "Power",
					"stats": {"strength": 1, "intelligence": 1},
					"archetypes": {Archetype.WARRIOR: 2, Archetype.MAGE: 1}},
				{"text": "I would give up the throne",
					"stats": {"agility": 1, "wisdom": 1},
					"archetypes": {Archetype.ROGUE: 2, Archetype.MAGE: 1}},
			],
		},
		{
			"question": "What kind of puzzles are most exciting to you?",
			"answers": [
				{"text": "Competitive - Chess",
					"stats": {"intelligence": 1, "determination": 1},
					"archetypes": {Archetype.MONK: 2, Archetype.ARCHER: 1}},
				{"text": "Repetitive, but complicated - Tetris",
					"stats": {"determination": 1, "strength": 1},
					"archetypes": {Archetype.WARRIOR: 2, Archetype.ROGUE: 1}},
				{"text": "Clue and people oriented - Escape rooms",
					"stats": {"dexterity": 1, "wisdom": 1},
					"archetypes": {Archetype.ROGUE: 2, Archetype.MONK: 1}},
				{"text": "Verbal - Poetry or philosophy",
					"stats": {"intelligence": 1, "wisdom": 1},
					"archetypes": {Archetype.MAGE: 2, Archetype.ARCHER: 1}},
			],
		},
		{
			"question": "If you could have any pet, what would it be?",
			"answers": [
				{"text": "Lion",
					"stats": {"strength": 2},
					"archetypes": {Archetype.WARRIOR: 2, Archetype.MONK: 1}},
				{"text": "Rhinoceros",
					"stats": {"determination": 1, "strength": 1},
					"archetypes": {Archetype.MONK: 2, Archetype.WARRIOR: 1}},
				{"text": "Falcon",
					"stats": {"dexterity": 2},
					"archetypes": {Archetype.ARCHER: 2, Archetype.ROGUE: 1}},
				{"text": "Monkey",
					"stats": {"agility": 1, "intelligence": 1},
					"archetypes": {Archetype.MAGE: 2, Archetype.ROGUE: 1}},
			],
		},
		{
			"question": "Where would you most like to live?",
			"answers": [
				{"text": "Above ground, on land",
					"stats": {"strength": 1, "determination": 1},
					"archetypes": {Archetype.WARRIOR: 2, Archetype.MONK: 1}},
				{"text": "In the air",
					"stats": {"dexterity": 1, "agility": 1},
					"archetypes": {Archetype.ARCHER: 2, Archetype.MAGE: 1}},
				{"text": "Underground",
					"stats": {"agility": 1, "dexterity": 1},
					"archetypes": {Archetype.ROGUE: 2, Archetype.MONK: 1}},
				{"text": "Underwater",
					"stats": {"intelligence": 1, "wisdom": 1},
					"archetypes": {Archetype.MAGE: 2, Archetype.ARCHER: 1}},
			],
		},
		{
			"question": "If you were at a party, would you...",
			"answers": [
				{"text": "Be the life of it",
					"stats": {"strength": 1, "wisdom": 1},
					"archetypes": {Archetype.WARRIOR: 2, Archetype.MAGE: 1}},
				{"text": "Find particular people you want to speak with",
					"stats": {"dexterity": 1, "intelligence": 1},
					"archetypes": {Archetype.ARCHER: 2, Archetype.MONK: 1}},
				{"text": "Keep to yourself, wait for people to join you",
					"stats": {"agility": 1, "determination": 1},
					"archetypes": {Archetype.ROGUE: 2, Archetype.ARCHER: 1}},
				{"text": "Ignore the people, be there for the goodies",
					"stats": {"intelligence": 1, "agility": 1},
					"archetypes": {Archetype.MAGE: 2, Archetype.ROGUE: 1}},
			],
		},
		{
			"question": "What would be most offending to you?",
			"answers": [
				{"text": "Calling you stupid",
					"stats": {"intelligence": 2},
					"archetypes": {Archetype.MAGE: 2, Archetype.ARCHER: 1}},
				{"text": "Someone scolding a kid who is not yours",
					"stats": {"determination": 1, "wisdom": 1},
					"archetypes": {Archetype.WARRIOR: 2, Archetype.MONK: 1}},
				{"text": "Challenging your individual commitment to something",
					"stats": {"determination": 2},
					"archetypes": {Archetype.MONK: 2, Archetype.ROGUE: 1}},
				{"text": "Breaking your trust",
					"stats": {"wisdom": 1, "agility": 1},
					"archetypes": {Archetype.ROGUE: 2, Archetype.WARRIOR: 1}},
			],
		},
	]

# ---- Card pools by archetype ----

static func _get_card_pool() -> Dictionary:
	return {
		Archetype.WARRIOR: [
			"taunt", "life_steal", "roar", "turtle_up", "parry",
			"charge", "heroic_leap", "morphine", "armor_break",
			"hold_the_line", "approach", "wear_down", "life_swap", "poke",
		],
		Archetype.ROGUE: [
			"shadows", "preparation", "exacerbate_wounds", "reposition",
			"dagger_throw", "volatile_mixture", "poisoned_blood",
			"raged_circulation", "shuriken_pouch", "premeditated", "elixir",
		],
		Archetype.MAGE: [
			"trick_shot", "surrounding_ice", "risk_it", "loaded_die",
			"energy_ball", "hope_this_works", "lady_luck",
			"snowballs_chance", "worst_that_could_happen", "biscuit",
		],
		Archetype.ARCHER: [
			"mark", "quick_shot", "reload", "enchanted_quiver",
			"tighten_string", "sky_fall", "sky_attack", "lead_arrow",
			"last_breath", "bottomless_quiver", "rise", "down_town", "mixed_bag",
		],
		Archetype.MONK: [
			"round_em_up", "trip", "choke", "push", "defensive_awareness",
			"sweeping_disarm", "consecutive_snap", "swap", "meditate", "blink",
		],
	}

# ---- Starting items by archetype ----
# Each archetype has a unique starting item defined inline.
# The item is created using ItemData's factory methods or constructed manually.

static func _get_archetype_item_id() -> Dictionary:
	return {
		Archetype.WARRIOR: "questionnaire_warrior_item",
		Archetype.ROGUE: "questionnaire_rogue_item",
		Archetype.MAGE: "questionnaire_mage_item",
		Archetype.ARCHER: "questionnaire_archer_item",
		Archetype.MONK: "questionnaire_monk_item",
	}

static func _get_archetype_item_name() -> Dictionary:
	return {
		Archetype.WARRIOR: "Ironclad Crest",
		Archetype.ROGUE: "Shadowstep Sash",
		Archetype.MAGE: "Arcane Focus Ring",
		Archetype.ARCHER: "Windrunner Boots",
		Archetype.MONK: "Discipline Wraps",
	}

static func _get_archetype_passive_description() -> Dictionary:
	return {
		Archetype.WARRIOR: "Gain 2 armor at the start of each cycle",
		Archetype.ROGUE: "First attack each turn deals 20% bonus damage",
		Archetype.MAGE: "Gain 1 mana when you play a utility card",
		Archetype.ARCHER: "Ranged attacks have +1 range",
		Archetype.MONK: "Draw 1 extra card every other cycle",
	}

static func _get_archetype_slot_specialty() -> Dictionary:
	return {
		Archetype.WARRIOR: "Versatile: 4 weapon slots, 2 chest slots",
		Archetype.ROGUE: "Versatile: 4 belt slots, 2 ring slots",
		Archetype.MAGE: "Versatile: 4 ring slots, 2 belt slots",
		Archetype.ARCHER: "Versatile: 3 weapon slots, 3 ring slots",
		Archetype.MONK: "Versatile: 3 gauntlet slots, 3 boot slots",
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
			# Add stat bonuses
			for stat_name in answer["stats"]:
				stat_bonuses[stat_name] += answer["stats"][stat_name]
			# Add archetype affinity
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

	# Select starting cards: 5 from primary pool, 3 from secondary pool
	var card_pool = _get_card_pool()
	var primary_cards: Array = card_pool[primary].duplicate()
	var secondary_cards: Array = card_pool[secondary].duplicate()
	primary_cards.shuffle()
	secondary_cards.shuffle()

	var starting_card_ids: Array = []
	# Take up to 5 from primary
	for j in range(mini(5, primary_cards.size())):
		starting_card_ids.append(primary_cards[j])
	# Take up to 3 from secondary (avoid duplicates)
	var added: int = 0
	for j in range(secondary_cards.size()):
		if added >= 3:
			break
		if secondary_cards[j] not in starting_card_ids:
			starting_card_ids.append(secondary_cards[j])
			added += 1

	# Get item and passive info
	var item_names = _get_archetype_item_name()
	var passive_descs = _get_archetype_passive_description()
	var slot_specs = _get_archetype_slot_specialty()
	var flavors = _get_archetype_flavor()

	return {
		"title": title,
		"primary_archetype": primary,
		"secondary_archetype": secondary,
		"stat_bonuses": stat_bonuses,
		"archetype_scores": archetype_scores,
		"starting_card_ids": starting_card_ids,
		"starting_item_name": item_names[primary],
		"passive_description": passive_descs[primary],
		"slot_specialty": slot_specs[primary],
		"flavor_text": flavors[primary],
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

	# Derived stats
	data.base_health = 5
	data.base_mana = 5
	data.base_mana_regen = 1.0
	data.base_draw_timer = 5
	data.base_hand_size = 5

	# Starting cards from questionnaire
	data.starting_card_ids = result["starting_card_ids"]

	# Display info
	data.passive_description = result["passive_description"]
	data.starting_item_name = result["starting_item_name"]
	data.starting_item_description = result["passive_description"]
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
