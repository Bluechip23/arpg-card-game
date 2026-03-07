class_name QuestionnaireData
extends RefCounted

## Character questionnaire - 11 personality questions that recommend a character.
## Each answer awards affinity points to one or more characters.
## The character with the highest total score is recommended.

# Answer affinity: { "character_name": points }
# Characters: Ryan (Rogue), Jeremy (Gambler/Mage), Stephen (Archer), Cory (Martial Artist), Brad (Warrior)

static func get_questions() -> Array[Dictionary]:
	return [
		{
			"question": "When facing a challenge, your first instinct is to...",
			"answers": [
				{"text": "Charge in head-first", "scores": {"Brad": 2, "Cory": 1}},
				{"text": "Plan carefully before acting", "scores": {"Stephen": 2, "Jeremy": 1}},
				{"text": "Find a creative workaround", "scores": {"Ryan": 2, "Jeremy": 1}},
				{"text": "Seek allies to help", "scores": {"Brad": 1, "Cory": 1, "Stephen": 1}},
			],
		},
		{
			"question": "What matters most in a companion?",
			"answers": [
				{"text": "Loyalty", "scores": {"Brad": 2, "Cory": 1}},
				{"text": "Intelligence", "scores": {"Jeremy": 2, "Stephen": 1}},
				{"text": "Strength", "scores": {"Cory": 2, "Brad": 1}},
				{"text": "Independence", "scores": {"Ryan": 2, "Stephen": 1}},
			],
		},
		{
			"question": "What's your biggest fear?",
			"answers": [
				{"text": "Being powerless", "scores": {"Brad": 2, "Cory": 1}},
				{"text": "Being alone", "scores": {"Jeremy": 1, "Brad": 1}},
				{"text": "Being forgotten", "scores": {"Stephen": 2, "Ryan": 1}},
				{"text": "Being wrong", "scores": {"Jeremy": 2, "Cory": 1}},
			],
		},
		{
			"question": "How do you handle failure?",
			"answers": [
				{"text": "Get back up immediately", "scores": {"Brad": 2, "Cory": 1}},
				{"text": "Analyze what went wrong", "scores": {"Stephen": 2, "Jeremy": 1}},
				{"text": "Change approach entirely", "scores": {"Ryan": 2, "Jeremy": 1}},
				{"text": "Seek help from others", "scores": {"Brad": 1, "Cory": 1}},
			],
		},
		{
			"question": "What legacy do you want to leave?",
			"answers": [
				{"text": "Stories of bravery", "scores": {"Brad": 2, "Cory": 1}},
				{"text": "Knowledge and wisdom", "scores": {"Jeremy": 2, "Stephen": 1}},
				{"text": "A better world for everyone", "scores": {"Cory": 2, "Stephen": 1}},
				{"text": "Personal mastery of your craft", "scores": {"Ryan": 2, "Cory": 1}},
			],
		},
		{
			"question": "If you were the dictator of a country, you would prioritize:",
			"answers": [
				{"text": "Equality", "scores": {"Cory": 2, "Brad": 1}},
				{"text": "Individual agency", "scores": {"Stephen": 2, "Ryan": 1}},
				{"text": "Power", "scores": {"Brad": 2, "Jeremy": 1}},
				{"text": "I would give up the throne", "scores": {"Ryan": 2, "Jeremy": 1}},
			],
		},
		{
			"question": "What kind of puzzles are most exciting to you?",
			"answers": [
				{"text": "Competitive - Chess", "scores": {"Cory": 2, "Stephen": 1}},
				{"text": "Repetitive, but complicated - Tetris", "scores": {"Brad": 2, "Ryan": 1}},
				{"text": "Clue and people oriented - Escape rooms", "scores": {"Ryan": 2, "Cory": 1}},
				{"text": "Verbal - Poetry or philosophy", "scores": {"Jeremy": 2, "Stephen": 1}},
			],
		},
		{
			"question": "If you could have any pet, what would it be?",
			"answers": [
				{"text": "Lion", "scores": {"Brad": 2, "Cory": 1}},
				{"text": "Rhinoceros", "scores": {"Cory": 2, "Brad": 1}},
				{"text": "Falcon", "scores": {"Stephen": 2, "Ryan": 1}},
				{"text": "Monkey", "scores": {"Jeremy": 2, "Ryan": 1}},
			],
		},
		{
			"question": "Where would you most like to live?",
			"answers": [
				{"text": "Above ground, on land", "scores": {"Brad": 2, "Cory": 1}},
				{"text": "In the air", "scores": {"Stephen": 2, "Jeremy": 1}},
				{"text": "Underground", "scores": {"Ryan": 2, "Cory": 1}},
				{"text": "Underwater", "scores": {"Jeremy": 2, "Stephen": 1}},
			],
		},
		{
			"question": "If you were at a party, would you...",
			"answers": [
				{"text": "Be the life of it", "scores": {"Brad": 2, "Jeremy": 1}},
				{"text": "Find particular people you want to speak with", "scores": {"Stephen": 2, "Cory": 1}},
				{"text": "Keep to yourself, wait for people to join you", "scores": {"Ryan": 2, "Stephen": 1}},
				{"text": "Ignore the people, be there for the goodies", "scores": {"Jeremy": 2, "Ryan": 1}},
			],
		},
		{
			"question": "What would be most offending to you?",
			"answers": [
				{"text": "Calling you stupid", "scores": {"Jeremy": 2, "Stephen": 1}},
				{"text": "Someone scolding a kid who is not yours", "scores": {"Brad": 2, "Cory": 1}},
				{"text": "Challenging your individual commitment to something", "scores": {"Cory": 2, "Ryan": 1}},
				{"text": "Breaking your trust", "scores": {"Ryan": 2, "Brad": 1}},
			],
		},
	]

static func get_character_names() -> Array[String]:
	return ["Ryan", "Jeremy", "Stephen", "Cory", "Brad"]

## Given an array of answer indices (one per question), compute character scores
## and return the recommended character name.
static func compute_result(answer_indices: Array[int]) -> Dictionary:
	var questions = get_questions()
	var scores: Dictionary = {}
	for name in get_character_names():
		scores[name] = 0

	for i in range(mini(answer_indices.size(), questions.size())):
		var q = questions[i]
		var chosen = answer_indices[i]
		if chosen >= 0 and chosen < q["answers"].size():
			var answer_scores: Dictionary = q["answers"][chosen]["scores"]
			for char_name in answer_scores:
				scores[char_name] += answer_scores[char_name]

	# Find the character with the highest score
	var best_name: String = "Ryan"
	var best_score: int = -1
	for char_name in scores:
		if scores[char_name] > best_score:
			best_score = scores[char_name]
			best_name = char_name

	return {"recommended": best_name, "scores": scores}

## Get the CharacterData for the recommended character by name.
static func get_character_by_name(char_name: String) -> CharacterData:
	match char_name:
		"Ryan":
			return CharacterData.create_ryan()
		"Jeremy":
			return CharacterData.create_jeremy()
		"Stephen":
			return CharacterData.create_stephen()
		"Cory":
			return CharacterData.create_cory()
		"Brad":
			return CharacterData.create_brad()
		_:
			return CharacterData.create_ryan()

## Get a flavor description for each character recommendation.
static func get_character_description(char_name: String) -> String:
	match char_name:
		"Ryan":
			return "The Rogue - You're resourceful, independent, and always have a trick up your sleeve. You prefer to outsmart your enemies rather than overpower them."
		"Jeremy":
			return "The Gambler - You thrive on risk and reward. Your intellect and love of chance make you unpredictable and dangerous in equal measure."
		"Stephen":
			return "The Archer - Precise, calculated, and self-reliant. You prefer to strike from a distance and value your freedom above all else."
		"Cory":
			return "The Martial Artist - Disciplined and competitive, you believe in fairness and earned strength. Your hands are your greatest weapons."
		"Brad":
			return "The Warrior - Bold and protective, you face danger head-on and shield those around you. Your courage inspires others to follow."
		_:
			return ""
