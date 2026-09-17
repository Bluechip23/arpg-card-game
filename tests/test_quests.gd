extends SceneTree

## The quest framework: multi-objective quests driven by world events,
## prerequisite/world gating, collect-and-consume turn-ins, shrine choices
## with permanent stat rewards, flags, and a save round-trip.
## Run: godot --headless --path . --script tests/test_quests.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _fresh() -> QuestManager:
	var qm := QuestManager.new()
	qm._ready()
	return qm

func _initialize() -> void:
	print("=== Quest framework test ===")
	var stats = load("res://scripts/character/player_stats.gd").new()
	get_root().add_child(stats)
	stats.initialize(CharacterData.create_brad())

	# --- Gating: only the first errand is on offer until it is turned in ---
	var qm := _fresh()
	var offers := qm.get_available_quests_from("Olorin")
	_check(offers.size() == 1 and offers[0].id == "olorin_kill_wererats", "fresh game offers only Rat Infestation")
	qm.accept_quest("olorin_kill_wererats")
	for _i in range(5):
		qm.on_enemy_killed("Wererat", "sewer")
	qm.turn_in_quest("olorin_kill_wererats", stats)
	var ids: Array = []
	for q in qm.get_available_quests_from("Olorin"):
		ids.append(q.id)
	_check("holy_water_well" in ids and "bear_traps" in ids and "the_faithless" in ids and "fire_wall_breach" in ids and "high_road" in ids,
		"turning it in unlocks the next errands (%s)" % [ids])
	_check("calamity_warning" not in ids, "Calamity Warning waits on the well")
	_check("ferryman_toll" not in ids, "Ferryman's Toll waits on Act 2 and The Faithless")
	_check("missing_woodcutter" in ids, "The Missing Woodcutter is on offer")
	_check("what_the_crows_saw" in ids, "What the Crows Saw is on offer")
	_check("sellswords_debt" not in ids and _ids(qm.get_available_quests_from("Sellsword")) == ["sellswords_debt"], "the Sellsword offers his own debt")

	# --- Collect: progress mirrors what is carried; turn-in consumes it ---
	qm.accept_quest("holy_water_well")
	stats.holy_water = 3
	qm.sync_held({"holy_water": 3})
	var well := qm.get_quest("holy_water_well")
	_check(well.objectives[0].current == 3 and not well.is_complete, "3 vials carried: 3/5")
	stats.holy_water = 5
	qm.sync_held({"holy_water": 5})
	_check(well.is_complete and qm.can_turn_in(well, stats), "5 vials: complete and turnable")
	stats.holy_water = 2
	qm.sync_held({"holy_water": 2})
	_check(not qm.can_turn_in(well, stats), "spent the vials: no longer turnable")
	stats.holy_water = 6
	qm.sync_held({"holy_water": 6})
	var gold_before: int = stats.gold
	qm.turn_in_quest("holy_water_well", stats)
	_check(stats.holy_water == 1, "turn-in consumes exactly 5 vials")
	_check(stats.gold == gold_before + 40, "…and pays the gold")
	_check(qm.has_flag("town_well_blessed"), "…and blesses the town well")
	_check("calamity_warning" in _ids(qm.get_available_quests_from("Olorin")), "the well unlocks Calamity Warning")

	# --- Sequential objectives with zone filters ---
	qm.accept_quest("bear_traps")
	qm.on_event("interact", {"object": "bear_trap", "zone": "cave"})
	var traps := qm.get_quest("bear_traps")
	_check(traps.objectives[0].current == 0, "a trap disarmed outside the Greenwood does not count")
	for _i in range(8):
		qm.on_event("interact", {"object": "bear_trap", "zone": "forest"})
	_check(traps.objectives[0].is_done() and not traps.is_complete, "8 forest traps done, hunter still to confront")
	qm.on_enemy_killed("Infected Hunter", "forest")
	_check(traps.is_complete, "the Infected Hunter completes the quest")

	# --- Choice quest with permanent stat rewards ---
	qm.accept_quest("the_faithless")
	_check(not qm.choose("the_faithless", "burn"), "the shrine cannot be decided before the cultists fall")
	for _i in range(6):
		qm.on_enemy_killed("Sludge", "sewer")
	_check(qm.is_objective_active("the_faithless", 1), "six sewer kills open the shrine choice")
	_check(qm.choose("the_faithless", "keep"), "choosing to keep the shrine")
	var faithless := qm.get_quest("the_faithless")
	_check(faithless.is_complete and faithless.chosen == "keep", "…completes the quest with the choice recorded")
	var rewards := qm.turn_in_quest("the_faithless", stats)
	_check(rewards.get("stats", {}).get("quest_life_steal_bonus", 0.0) == 3.0, "kept shrine rewards +3% life steal")
	_check(stats.quest_life_steal_bonus == 3.0 and stats.quest_crit_bonus == 0.0, "…applied permanently to the stats")
	_check(stats.save_progression().get("quest_life_steal_bonus", 0.0) == 3.0, "…and saved with the stats")

	# --- Channel breaks, high ground, calamity ---
	qm.accept_quest("fire_wall_breach")
	qm.on_event("channel_break", {"enemy_name": "Fire Goblin Shaman", "zone": "cave"})
	qm.on_event("channel_break", {"enemy_name": "Treant", "zone": "forest"})
	_check(qm.get_quest("fire_wall_breach").objectives[0].current == 1, "only Shaman channels in caves count")
	qm.accept_quest("high_road")
	qm.on_enemy_killed("Wolf", "forest", false)
	qm.on_enemy_killed("Wolf", "forest", true)
	_check(qm.get_quest("high_road").objectives[0].current == 1, "only high-ground kills count for The High Road")
	qm.accept_quest("calamity_warning")
	qm.on_event("calamity_answered")
	_check(qm.get_quest("calamity_warning").is_complete, "answering the flute completes Calamity Warning")

	# --- Act 2 gate ---
	qm.world_level = 1
	_check("ferryman_toll" not in _ids(qm.get_available_quests_from("Olorin")), "Ferryman's Toll is not offered in World 1")
	qm.world_level = 2
	_check("ferryman_toll" in _ids(qm.get_available_quests_from("Olorin")), "…but is in World 2 once The Faithless is done")
	qm.accept_quest("ferryman_toll")
	qm.on_enemy_killed("Djinn", "")
	qm.on_enemy_killed("Ifrit", "")
	var toll := qm.get_quest("ferryman_toll")
	_check(toll.objectives[2].is_done() and toll.objectives[0].is_done() and not toll.is_complete, "parallel objectives progress in any order")

	# --- Save round-trip through JSON ---
	var state = JSON.parse_string(JSON.stringify(qm.save_state()))
	var qm2 := _fresh()
	qm2.load_state(state)
	_check(qm2.is_quest_turned_in("the_faithless") and qm2.get_quest("the_faithless").chosen == "keep", "turned-in quests and choices reload")
	_check(qm2.get_quest("bear_traps").is_complete, "completed-but-not-turned-in quests reload complete")
	_check(qm2.get_quest("fire_wall_breach").objectives[0].current == 1, "partial progress reloads")
	_check(qm2.has_flag("town_well_blessed"), "flags reload")
	var toll2 := qm2.get_quest("ferryman_toll")
	_check(toll2.objectives[0].is_done() and not toll2.objectives[1].is_done(), "per-objective progress reloads")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _ids(quests: Array) -> Array:
	var out: Array = []
	for q in quests:
		out.append(q.id)
	return out
