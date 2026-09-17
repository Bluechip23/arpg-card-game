class_name QuestManager
extends Node

## Quests: data-driven objectives, world events, rewards, persistence.
##
## A quest is a list of objectives. Objectives progress off events the game
## reports through on_event(kind, data):
##   kill             {enemy_name, zone, high_ground}   target = enemy name or "*"
##   kill_high_ground {enemy_name, zone, high_ground}   same, only counts from high ground
##   collect          {currency, held}                  target = currency; current = held (turn-in consumes)
##   interact         {object}                          target = object id (e.g. "bear_trap")
##   channel_break    {enemy_name}                      target = enemy name or "*"
##   reach            {object}                          target = npc/site id, once
##   escort           {npc}                             target = npc id delivered, once
##   choice           (via choose())                    target = shrine id; the player picks an option
##   calamity_answered {}                               once
## Objectives with a zone filter only count inside that interior kind
## ("sewer", "forest", "cave", "" = overworld); no filter = anywhere.
## Sequential quests advance one objective at a time; parallel ones track all.
##
## Rewards on turn-in: gold, xp, consume {currency: n}, flags [..] (stored
## here, saved, queried by the town/world), stats {quest_crit_bonus: 3.0, …}
## applied to PlayerStats by apply_rewards. A choice quest's option carries
## its own rewards, merged in when chosen.

signal quest_accepted(quest_id: String)
signal quest_updated(quest_id: String, current: int, required: int)
signal quest_completed(quest_id: String)

class Objective:
	var type: String
	var target: String
	var count: int
	var current: int = 0
	var zone: String = ""      # "" = any; "overworld" = surface only; else interior kind
	var label: String = ""     # shown in the log; "%d/%d" appended for counted objectives

	func _init(p_type: String, p_target: String, p_count: int, p_label: String, p_zone: String = "") -> void:
		type = p_type
		target = p_target
		count = maxi(1, p_count)
		label = p_label
		zone = p_zone

	func is_done() -> bool:
		return current >= count

	func text() -> String:
		if type in ["reach", "escort", "choice", "calamity_answered"]:
			return label + (" ✓" if is_done() else "")
		return "%s (%d/%d)" % [label, mini(current, count), count]

	func zone_matches(zone_kind: String) -> bool:
		if zone == "":
			return true
		if zone == "overworld":
			return zone_kind == ""
		return zone == zone_kind

class Quest:
	var id: String
	var name: String
	var description: String
	var giver: String
	var objectives: Array[Objective] = []
	var sequential: bool = true
	var rewards: Dictionary = {}
	var prerequisites: Array[String] = []   # quest ids that must be turned in first
	var min_world: int = 1
	var choice: Dictionary = {}             # {"prompt": String, "options": {id: {"label", "rewards"}}}
	var chosen: String = ""
	var is_complete: bool = false
	var is_turned_in: bool = false
	var teaches: String = ""                # one-line mechanic lesson shown in the log
	var hidden: bool = false                # defined but not offered yet (its world objects are unbuilt)

	func _init(p_id: String, p_name: String, p_desc: String, p_giver: String, p_rewards: Dictionary) -> void:
		id = p_id
		name = p_name
		description = p_desc
		giver = p_giver
		rewards = p_rewards

	# Legacy single-objective accessors (older UI and tests read these).
	var objective_type: String:
		get: return objectives[0].type if not objectives.is_empty() else ""
	var objective_target: String:
		get: return objectives[0].target if not objectives.is_empty() else ""
	var objective_count: int:
		get: return objectives[0].count if not objectives.is_empty() else 0
	var current_count: int:
		get: return objectives[0].current if not objectives.is_empty() else 0

	func active_objectives() -> Array[Objective]:
		## The objectives that can progress right now.
		var out: Array[Objective] = []
		for o in objectives:
			if o.is_done():
				continue
			out.append(o)
			if sequential:
				break
		return out

	func refresh_complete() -> bool:
		for o in objectives:
			if not o.is_done():
				is_complete = false
				return false
		is_complete = true
		return true

	func get_progress_text() -> String:
		if is_turned_in:
			return "[Complete]"
		var done := 0
		for o in objectives:
			if o.is_done():
				done += 1
		return "%d / %d" % [done, objectives.size()]

	func get_objective_text() -> String:
		var lines: Array[String] = []
		var reached_active := false
		for o in objectives:
			var line := o.text()
			if sequential and not o.is_done():
				if reached_active:
					line = "…then: " + o.label
				reached_active = true
			lines.append(line)
		return "\n".join(lines)

var active_quests: Array[Quest] = []
var completed_quests: Array[Quest] = []
var available_quests: Dictionary = {}  # quest_id -> Quest (defined, not yet accepted)
var flags: Dictionary = {}             # story flags set by turned-in quests (saved)
var world_level: int = 1               # gates min_world offers; set by the scene that owns us

func _ready() -> void:
	_define_quests()

# ============================================
# QUEST DEFINITIONS
# ============================================
func _define_quests() -> void:
	var q: Quest

	# --- Olorin's first errand: opens the world ---
	q = Quest.new("olorin_kill_wererats", "Rat Infestation",
		"Olorin says the sewers below are crawling with wererats. Clear out 5 of them.",
		"Olorin", {"gold": 50, "xp": 25})
	q.objectives.append(Objective.new("kill", "Wererat", 5, "Kill 5 Wererats"))
	_add(q)

	# --- Holy Water for the Well ---
	q = Quest.new("holy_water_well", "Holy Water for the Well",
		"The town's own well has run dry of grace. Bring Olorin five vials of Holy Water — the fallen drop them — and he will bless the well for good.",
		"Olorin", {"gold": 40, "xp": 30, "consume": {"holy_water": 5}, "flags": ["town_well_blessed"]})
	q.prerequisites = ["olorin_kill_wererats"]
	q.objectives.append(Objective.new("collect", "holy_water", 5, "Carry 5 vials of Holy Water"))
	q.teaches = "Holy Water blesses dry fountains. Enemies drop it; bosses always carry one."
	_add(q)

	# --- Bear Traps for Bear Traps ---
	q = Quest.new("bear_traps", "Bear Traps for Bear Traps",
		"The hunters' iron traps in the Greenwood are catching townsfolk. Disarm eight of them, then find the Infected Hunter who set them.",
		"Olorin", {"gold": 80, "xp": 60})
	q.prerequisites = ["olorin_kill_wererats"]
	q.objectives.append(Objective.new("interact", "bear_trap", 8, "Disarm 8 bear traps in the Greenwood", "forest"))
	q.objectives.append(Objective.new("kill", "Infected Hunter", 1, "Confront the Infected Hunter", "forest"))
	q.teaches = "Stand beside a trap and press Shift to disarm it instead of stepping on it."
	_add(q)

	# --- The Faithless ---
	q = Quest.new("the_faithless", "The Faithless",
		"Cultists drown prisoners in the deepest sewer chamber. Cut them down, then decide what becomes of their shrine.",
		"Olorin", {"gold": 60, "xp": 50})
	q.prerequisites = ["olorin_kill_wererats"]
	q.objectives.append(Objective.new("kill", "*", 6, "Slay 6 of the Faithless in the Sewers", "sewer"))
	q.objectives.append(Objective.new("choice", "sewer_shrine", 1, "Decide the fate of the drowned shrine"))
	q.choice = {
		"prompt": "The shrine hums with stolen prayers. Burn it, or keep it?",
		"options": {
			"burn": {"label": "Burn the shrine — +3% critical chance, forever", "rewards": {"stats": {"quest_crit_bonus": 3.0}}},
			"keep": {"label": "Keep the shrine — +3% life steal, forever", "rewards": {"stats": {"quest_life_steal_bonus": 3.0}}},
		},
	}
	_add(q)

	# --- Fire Wall Breach (teaches Channel / Disruptable) ---
	q = Quest.new("fire_wall_breach", "Fire Wall Breach",
		"Fire Goblin Shamans in the caves raise walls of flame with a long channel. Break five of those channels before they finish.",
		"Olorin", {"gold": 90, "xp": 70})
	q.prerequisites = ["olorin_kill_wererats"]
	q.objectives.append(Objective.new("channel_break", "Fire Goblin Shaman", 5, "Break 5 Fire Wall channels", "cave"))
	q.teaches = "A channeling enemy shows an orange bar. Deal enough damage while it channels (Disruptable) and the action collapses."
	_add(q)

	# --- The High Road (teaches High Ground) ---
	q = Quest.new("high_road", "The High Road",
		"Olorin wants the hawks and wolves of the Greenwood taught a lesson from above. Kill three enemies while holding the high ground.",
		"Olorin", {"gold": 50, "xp": 40})
	q.prerequisites = ["olorin_kill_wererats"]
	q.objectives.append(Objective.new("kill_high_ground", "*", 3, "Kill 3 enemies from high ground"))
	q.teaches = "Climb a sturdy tree or stand on a pillar: ranged attacks gain damage and reach from high ground."
	_add(q)

	# --- Calamity Warning ---
	q = Quest.new("calamity_warning", "Calamity Warning",
		"When the flute sounds, a calamity has struck the city. Get home before it is over and stand with the garrison.",
		"Olorin", {"gold": 100, "xp": 80, "flags": ["garrison_veteran"]})
	q.prerequisites = ["holy_water_well"]
	q.objectives.append(Objective.new("calamity_answered", "", 1, "Answer the flute in time and defend the city"))
	q.teaches = "Kills tick the calamity countdown. When the flute sounds, head home within a few kills."
	_add(q)

	# --- Ferryman's Toll (Act 2) ---
	q = Quest.new("ferryman_toll", "Ferryman's Toll",
		"Passage below costs three coins, and only the lords of the deep carry them: an Ifrit, an Inflamed Minotaur, and a Djinn.",
		"Olorin", {"gold": 200, "xp": 150, "flags": ["ferryman_paid"]})
	q.prerequisites = ["the_faithless"]
	q.min_world = 2
	q.sequential = false
	q.objectives.append(Objective.new("kill", "Ifrit", 1, "Take the Ifrit's coin"))
	q.objectives.append(Objective.new("kill", "Inflamed Minotaur", 1, "Take the Minotaur's coin"))
	q.objectives.append(Objective.new("kill", "Djinn", 1, "Take the Djinn's coin"))
	_add(q)

	# --- The Missing Woodcutter ---
	q = Quest.new("missing_woodcutter", "The Missing Woodcutter",
		"The lumber camp's foreman went into the Greenwood and never came back. Find him and walk him out — the sawmill stands idle without him.",
		"Olorin", {"gold": 70, "xp": 60, "flags": ["woodcutter_rescued"]})
	q.prerequisites = ["olorin_kill_wererats"]
	q.objectives.append(Objective.new("reach", "npc_woodcutter", 1, "Find the foreman in the Greenwood", "forest"))
	q.objectives.append(Objective.new("escort", "npc_woodcutter", 1, "Walk him to the forest exit", "forest"))
	q.teaches = "Press Shift beside a rescued NPC and they follow you. Get them to the exit alive."
	_add(q)

	# --- A Debt to the Sellsword ---
	q = Quest.new("sellswords_debt", "A Debt to the Sellsword",
		"The Sellsword's partner is trapped in a cave. Bring her out alive and the first recruit is on the house.",
		"Sellsword", {"gold": 30, "xp": 60, "flags": ["sellsword_first_free"]})
	q.prerequisites = ["olorin_kill_wererats"]
	q.objectives.append(Objective.new("reach", "npc_partner", 1, "Find the Sellsword's partner in a cave", "cave"))
	q.objectives.append(Objective.new("escort", "npc_partner", 1, "Walk her to the cave exit", "cave"))
	_add(q)

	# --- What the Crows Saw ---
	q = Quest.new("what_the_crows_saw", "What the Crows Saw",
		"Crows have been circling something east of town. Follow the feathers they drop — each points the way — to a place that is on no map.",
		"Olorin", {"gold": 60, "xp": 80, "flags": ["graveyard_found"]})
	q.prerequisites = ["olorin_kill_wererats"]
	q.objectives.append(Objective.new("reach", "site_graveyard", 1, "Follow the feather trail to the hidden graveyard", "overworld"))
	q.teaches = "Secret passages are marked by trails. A feather's tip points where to go next."
	q.hidden = true  # until the feather trail and graveyard are built
	_add(q)

func _add(q: Quest) -> void:
	available_quests[q.id] = q

# ============================================
# OFFERS / ACCEPT / TURN-IN
# ============================================
func is_offerable(quest: Quest) -> bool:
	if quest.hidden or quest.min_world > world_level:
		return false
	for pre in quest.prerequisites:
		if not is_quest_turned_in(pre):
			return false
	return true

func get_available_quests_from(giver_name: String) -> Array[Quest]:
	var result: Array[Quest] = []
	for quest in available_quests.values():
		if quest.giver == giver_name and is_offerable(quest):
			result.append(quest)
	return result

func get_active_quests() -> Array[Quest]:
	return active_quests

func get_completed_quests() -> Array[Quest]:
	return completed_quests

func get_quest(quest_id: String) -> Quest:
	for q in active_quests:
		if q.id == quest_id:
			return q
	for q in completed_quests:
		if q.id == quest_id:
			return q
	return available_quests.get(quest_id)

func accept_quest(quest_id: String) -> bool:
	if quest_id not in available_quests:
		return false
	var quest = available_quests[quest_id]
	available_quests.erase(quest_id)
	active_quests.append(quest)
	quest_accepted.emit(quest_id)
	print("[QUEST] Accepted: %s" % quest.name)
	return true

func turn_in_quest(quest_id: String, stats = null) -> Dictionary:
	## Hand in a completed quest. Returns the reward bundle (already merged
	## with the chosen option's rewards); flags are recorded here, and if
	## `stats` is given, gold/xp/stat bonuses/consumption are applied too.
	for i in range(active_quests.size()):
		var quest = active_quests[i]
		if quest.id == quest_id and quest.is_complete and not quest.is_turned_in:
			var rewards: Dictionary = quest.rewards.duplicate(true)
			if quest.chosen != "" and quest.choice.get("options", {}).has(quest.chosen):
				_merge_rewards(rewards, quest.choice["options"][quest.chosen].get("rewards", {}))
			for f in rewards.get("flags", []):
				flags[str(f)] = true
			quest.is_turned_in = true
			active_quests.remove_at(i)
			completed_quests.append(quest)
			if stats:
				apply_rewards(rewards, stats)
			print("[QUEST] Turned in: %s" % quest.name)
			return rewards
	return {}

static func _merge_rewards(into: Dictionary, extra: Dictionary) -> void:
	for k in extra:
		if k == "stats" or k == "consume":
			var d: Dictionary = into.get(k, {})
			for sk in extra[k]:
				d[sk] = float(d.get(sk, 0)) + float(extra[k][sk])
			into[k] = d
		elif k == "flags":
			into["flags"] = into.get("flags", []) + extra[k]
		else:
			into[k] = int(into.get(k, 0)) + int(extra[k])

static func apply_rewards(rewards: Dictionary, stats) -> void:
	## Pay gold/xp, take consumed currency, add permanent stat bonuses.
	if stats == null:
		return
	if rewards.has("gold"):
		stats.gain_gold(int(rewards["gold"]))
	if rewards.has("xp"):
		stats.gain_xp(int(rewards["xp"]))
	for cur in rewards.get("consume", {}):
		var n := int(rewards["consume"][cur])
		match cur:
			"holy_water": stats.holy_water = maxi(0, stats.holy_water - n)
			"gold": stats.gold = maxi(0, stats.gold - n)
	for stat_name in rewards.get("stats", {}):
		if stat_name in stats:
			stats.set(stat_name, float(stats.get(stat_name)) + float(rewards["stats"][stat_name]))

func has_flag(flag: String) -> bool:
	return flags.get(flag, false)

func choose(quest_id: String, option: String) -> bool:
	## Resolve a "choice" objective (a shrine, an altar) with the picked option.
	var quest := get_quest(quest_id)
	if quest == null or quest.is_turned_in or not quest.choice.get("options", {}).has(option):
		return false
	for o in quest.active_objectives():
		if o.type == "choice":
			o.current = o.count
			quest.chosen = option
			_after_progress(quest, o)
			return true
	return false

func can_turn_in(quest: Quest, stats = null) -> bool:
	## Complete, and any "collect" objective still has the goods in hand.
	if not quest.is_complete or quest.is_turned_in:
		return false
	if stats:
		for cur in quest.rewards.get("consume", {}):
			if cur == "holy_water" and stats.holy_water < int(quest.rewards["consume"][cur]):
				return false
	return true

# ============================================
# EVENTS
# ============================================
func on_enemy_killed(enemy_name: String, zone: String = "", high_ground: bool = false) -> void:
	on_event("kill", {"enemy_name": enemy_name, "zone": zone, "high_ground": high_ground})

func sync_held(held: Dictionary) -> void:
	## Refresh "collect" objectives from what the player actually carries.
	for cur in held:
		on_event("collect", {"currency": cur, "held": int(held[cur])})

func on_event(kind: String, data: Dictionary = {}) -> void:
	for quest in active_quests:
		if quest.is_complete:
			continue
		for o in quest.active_objectives():
			if not _objective_takes(o, kind, data):
				continue
			var before := o.current
			match kind:
				"collect":
					o.current = clampi(int(data.get("held", 0)), 0, o.count)
				_:
					o.current = mini(o.count, o.current + 1)
			if o.current != before:
				_after_progress(quest, o)

func _objective_takes(o: Objective, kind: String, data: Dictionary) -> bool:
	var zone_kind: String = str(data.get("zone", ""))
	match o.type:
		"kill":
			if kind != "kill":
				return false
			if not o.zone_matches(zone_kind):
				return false
			return o.target == "*" or o.target == str(data.get("enemy_name", ""))
		"kill_high_ground":
			if kind != "kill" or not bool(data.get("high_ground", false)):
				return false
			if not o.zone_matches(zone_kind):
				return false
			return o.target == "*" or o.target == str(data.get("enemy_name", ""))
		"collect":
			return kind == "collect" and str(data.get("currency", "")) == o.target
		"interact":
			return kind == "interact" and str(data.get("object", "")) == o.target and o.zone_matches(zone_kind)
		"channel_break":
			if kind != "channel_break" or not o.zone_matches(zone_kind):
				return false
			return o.target == "*" or o.target == str(data.get("enemy_name", ""))
		"reach":
			return kind == "reach" and str(data.get("object", "")) == o.target
		"escort":
			return kind == "escort" and str(data.get("npc", "")) == o.target
		"calamity_answered":
			return kind == "calamity_answered"
	return false

func _after_progress(quest: Quest, o: Objective) -> void:
	quest_updated.emit(quest.id, o.current, o.count)
	print("[QUEST] %s — %s" % [quest.name, o.text()])
	if quest.refresh_complete():
		quest_completed.emit(quest.id)
		print("[QUEST] %s COMPLETE! Return to %s." % [quest.name, quest.giver])

# ============================================
# QUERIES
# ============================================
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

func is_quest_started(quest_id: String) -> bool:
	## True once the quest has been accepted (in progress or already turned in).
	return get_quest(quest_id) != null and quest_id not in available_quests

func is_quest_turned_in(quest_id: String) -> bool:
	for quest in completed_quests:
		if quest.id == quest_id:
			return true
	return false

func is_objective_active(quest_id: String, index: int) -> bool:
	## True while the quest is accepted and its index-th objective can progress.
	var quest := get_quest(quest_id)
	if quest == null or quest_id in available_quests or quest.is_turned_in:
		return false
	if index < 0 or index >= quest.objectives.size():
		return false
	return quest.objectives[index] in quest.active_objectives()

func marker_state_for(giver_name: String) -> String:
	## What the marker above a quest giver's head should show:
	##   "complete"  — a quest is finished and waiting to be turned in (gold ?)
	##   "active"    — a quest was accepted and is still in progress (gray ?)
	##   "available" — a quest is on offer, not yet accepted (gold !)
	##   ""          — nothing to show
	if has_complete_quest_for(giver_name):
		return "complete"
	if not get_available_quests_from(giver_name).is_empty():
		return "available"
	if has_active_quest_from(giver_name):
		return "active"
	return ""

func get_turnable_quest_for(giver_name: String) -> Quest:
	for quest in active_quests:
		if quest.giver == giver_name and quest.is_complete and not quest.is_turned_in:
			return quest
	return null

func get_turnable_quests_for(giver_name: String) -> Array[Quest]:
	var out: Array[Quest] = []
	for quest in active_quests:
		if quest.giver == giver_name and quest.is_complete and not quest.is_turned_in:
			out.append(quest)
	return out

# ============================================
# PERSISTENCE
# ============================================
func save_state() -> Dictionary:
	var state: Dictionary = {"accepted_ids": [], "completed_ids": [], "progress": {}, "chosen": {}, "flags": flags.duplicate()}
	for quest in active_quests:
		state["accepted_ids"].append(quest.id)
		var counts: Array = []
		for o in quest.objectives:
			counts.append(o.current)
		state["progress"][quest.id] = counts
		if quest.chosen != "":
			state["chosen"][quest.id] = quest.chosen
	for quest in completed_quests:
		state["completed_ids"].append(quest.id)
		if quest.chosen != "":
			state["chosen"][quest.id] = quest.chosen
	return state

func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	var accepted_ids: Array = state.get("accepted_ids", [])
	var completed_ids: Array = state.get("completed_ids", [])
	var progress: Dictionary = state.get("progress", {})
	var chosen: Dictionary = state.get("chosen", {})
	for f in state.get("flags", {}):
		flags[str(f)] = bool(state["flags"][f])

	# Accept everything that was accepted or finished so nothing resurfaces
	# as a fresh "!" on its giver.
	for quest_id in accepted_ids + completed_ids:
		if quest_id in available_quests:
			var q: Quest = available_quests[quest_id]
			available_quests.erase(quest_id)
			active_quests.append(q)

	for quest in active_quests:
		if progress.has(quest.id):
			var counts: Array = progress[quest.id]
			for i in range(mini(counts.size(), quest.objectives.size())):
				quest.objectives[i].current = int(counts[i])
		elif state.has("kill_counts") and not quest.objectives.is_empty():
			# Legacy single-kill saves.
			var kc: Dictionary = state["kill_counts"]
			if kc.has(quest.objectives[0].target):
				quest.objectives[0].current = int(kc[quest.objectives[0].target])
		if chosen.has(quest.id):
			quest.chosen = str(chosen[quest.id])
		quest.refresh_complete()

	for quest_id in completed_ids:
		for i in range(active_quests.size() - 1, -1, -1):
			if active_quests[i].id == quest_id:
				var q := active_quests[i]
				for o in q.objectives:
					o.current = o.count
				q.is_complete = true
				q.is_turned_in = true
				completed_quests.append(q)
				active_quests.remove_at(i)
				break
