class_name QuestManager
extends Node

## Manages quests - tracking objectives, completion, and rewards

signal quest_accepted(quest_id: String)
signal quest_updated(quest_id: String, current: int, required: int)
signal quest_completed(quest_id: String)

class Quest:
	var id: String
	var name: String
	var description: String
	var giver: String
	var objective_type: String  # "kill"
	var objective_target: String  # e.g. "wererat"
	var objective_count: int
	var current_count: int = 0
	var is_complete: bool = false
	var is_turned_in: bool = false
	var rewards: Dictionary = {}  # {"gold": int, "xp": int, "item": String, "card": String}

	func _init(p_id: String, p_name: String, p_desc: String, p_giver: String,
			   p_obj_type: String, p_obj_target: String, p_obj_count: int, p_rewards: Dictionary) -> void:
		id = p_id
		name = p_name
		description = p_desc
		giver = p_giver
		objective_type = p_obj_type
		objective_target = p_obj_target
		objective_count = p_obj_count
		rewards = p_rewards

	func get_progress_text() -> String:
		if is_turned_in:
			return "[Complete]"
		return "%d / %d" % [current_count, objective_count]

	func get_objective_text() -> String:
		match objective_type:
			"kill":
				return "Kill %d %s (%d/%d)" % [objective_count, objective_target, current_count, objective_count]
		return description

var active_quests: Array[Quest] = []
var completed_quests: Array[Quest] = []
var available_quests: Dictionary = {}  # quest_id -> Quest (not yet accepted)

func _ready() -> void:
	_define_quests()

func _define_quests() -> void:
	# Olorin's quests
	var q1 = Quest.new(
		"olorin_kill_wererats",
		"Rat Infestation",
		"Olorin says the sewers below are crawling with wererats. Clear out 5 of them.",
		"Olorin",
		"kill", "Wererat", 5,
		{"gold": 50, "xp": 25}
	)
	available_quests[q1.id] = q1

func get_available_quests_from(giver_name: String) -> Array[Quest]:
	var result: Array[Quest] = []
	for quest in available_quests.values():
		if quest.giver == giver_name:
			result.append(quest)
	return result

func get_active_quests() -> Array[Quest]:
	return active_quests

func get_completed_quests() -> Array[Quest]:
	return completed_quests

func accept_quest(quest_id: String) -> bool:
	if quest_id not in available_quests:
		return false
	var quest = available_quests[quest_id]
	available_quests.erase(quest_id)
	active_quests.append(quest)
	quest_accepted.emit(quest_id)
	print("[QUEST] Accepted: %s" % quest.name)
	return true

func on_enemy_killed(enemy_name: String) -> void:
	for quest in active_quests:
		if quest.is_complete:
			continue
		if quest.objective_type == "kill" and quest.objective_target == enemy_name:
			quest.current_count += 1
			quest_updated.emit(quest.id, quest.current_count, quest.objective_count)
			print("[QUEST] %s progress: %d/%d" % [quest.name, quest.current_count, quest.objective_count])
			if quest.current_count >= quest.objective_count:
				quest.is_complete = true
				quest_completed.emit(quest.id)
				print("[QUEST] %s COMPLETE! Return to %s." % [quest.name, quest.giver])

func turn_in_quest(quest_id: String) -> Dictionary:
	for i in range(active_quests.size()):
		var quest = active_quests[i]
		if quest.id == quest_id and quest.is_complete and not quest.is_turned_in:
			quest.is_turned_in = true
			active_quests.remove_at(i)
			completed_quests.append(quest)
			print("[QUEST] Turned in: %s" % quest.name)
			return quest.rewards
	return {}

func has_complete_quest_for(giver_name: String) -> bool:
	for quest in active_quests:
		if quest.giver == giver_name and quest.is_complete and not quest.is_turned_in:
			return true
	return false

func has_active_quest_from(giver_name: String) -> bool:
	for quest in active_quests:
		if quest.giver == giver_name and not quest.is_turned_in:
			return true
	return false

func save_state() -> Dictionary:
	## Serialize quest state for passing between scenes.
	var state: Dictionary = {"accepted_ids": [], "completed_ids": [], "kill_counts": {}}
	for quest in active_quests:
		state["accepted_ids"].append(quest.id)
		if quest.objective_type == "kill":
			state["kill_counts"][quest.objective_target] = quest.current_count
	for quest in completed_quests:
		state["completed_ids"].append(quest.id)
	return state

func load_state(state: Dictionary) -> void:
	## Restore quest state from a saved dictionary.
	if state.is_empty():
		return
	var accepted_ids: Array = state.get("accepted_ids", [])
	var completed_ids: Array = state.get("completed_ids", [])
	var kill_counts: Dictionary = state.get("kill_counts", {})

	# Accept quests that were previously accepted
	for quest_id in accepted_ids:
		if quest_id in available_quests:
			accept_quest(quest_id)

	# Restore kill counts
	for quest in active_quests:
		if quest.objective_type == "kill" and quest.objective_target in kill_counts:
			quest.current_count = kill_counts[quest.objective_target]
			if quest.current_count >= quest.objective_count:
				quest.is_complete = true

	# Mark completed quests
	for quest_id in completed_ids:
		# Move from active to completed if still there
		for i in range(active_quests.size() - 1, -1, -1):
			if active_quests[i].id == quest_id:
				active_quests[i].is_complete = true
				active_quests[i].is_turned_in = true
				completed_quests.append(active_quests[i])
				active_quests.remove_at(i)
				break

func get_turnable_quest_for(giver_name: String) -> Quest:
	for quest in active_quests:
		if quest.giver == giver_name and quest.is_complete and not quest.is_turned_in:
			return quest
	return null
