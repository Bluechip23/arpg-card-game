extends SceneTree

## Tests the city loop's wiring into the game (STORY.md §6):
## kills fill the satchel → banked on reaching town → buildings raised at the
## Town Hall → calamities strike on a kill countdown and resolve at home →
## everything round-trips through ProgressionIO / SaveData.
## Run: godot --headless --path . --script tests/test_city_wiring.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== City wiring test ===")

	_test_scripts_parse()
	_test_zone_mapping()
	_test_satchel_and_banking()
	_test_progression_roundtrip()
	_test_calamity_flow()
	_test_disaster_resolution()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_scripts_parse() -> void:
	# Surface parse errors in the big scene scripts this wiring touches.
	_check(load("res://scripts/menus/town.gd") != null, "town.gd parses")
	_check(load("res://scripts/core/main.gd") != null, "main.gd parses")
	_check(load("res://scripts/menus/load_character.gd") != null, "load_character.gd parses")

func _test_zone_mapping() -> void:
	_check(CityBridge.zone_for_area("sewer", 1) == "Sewer", "sewer interior maps to Sewer")
	_check(CityBridge.zone_for_area("forest", 3) == "Forest", "forest interior wins over world level")
	_check(CityBridge.zone_for_area("cave", 1) == "Cave", "cave interior maps to Cave")
	_check(CityBridge.zone_for_area("", 1) == "Forest", "world 1 overworld maps to Forest")
	_check(CityBridge.zone_for_area("", 4) == "Underworld", "world 4 overworld maps to Underworld")
	for zone in [CityBridge.zone_for_area("building", 2), CityBridge.zone_for_area("", 5)]:
		_check(ExpeditionSystem.ZONES.has(zone), "mapped zone '%s' exists in ExpeditionSystem" % zone)

func _test_satchel_and_banking() -> void:
	var progression := {}
	_check(not CityBridge.city_started(progression), "fresh character has no city")

	# Kills out in the world fill the satchel.
	var gained := CityBridge.add_kill_to_satchel(progression, "Forest", false)
	_check(not gained.is_empty(), "a kill yields satchel resources")
	var elite_gain := CityBridge.add_kill_to_satchel(progression, "Forest", true)
	var trash_total := 0
	var elite_total := 0
	for res in gained:
		trash_total += int(gained[res])
	for res in elite_gain:
		elite_total += int(elite_gain[res])
	_check(elite_total >= trash_total * 2, "elite kills yield roughly triple")
	_check(not CityBridge.satchel(progression).is_empty(), "satchel accumulates")
	_check(not CityBridge.city_started(progression), "gathering alone does not found the city")

	# Reaching town banks the satchel — founding the city.
	var result := CityBridge.bank_satchel(progression, 1_000_000)
	_check(not result["banked"].is_empty(), "banking moves the satchel into the city")
	_check(CityBridge.satchel(progression).is_empty(), "satchel empties after banking")
	_check(CityBridge.city_started(progression), "first banking founds the city")

	# Resources are really in the city and spendable.
	var city := CityBridge.get_city(progression)
	var total := 0
	for res in CityState.RESOURCES:
		total += int(city.resources.get(res, 0))
	_check(total > 0, "city stores hold the banked haul")

	# Grind enough for an upgrade, then raise a building through the bridge.
	# (The Cave yields the stone a Lumber Mill needs; the Heavens never would.)
	for i in range(200):
		CityBridge.add_kill_to_satchel(progression, "Cave", true)
	CityBridge.bank_satchel(progression, 1_000_100)
	city = CityBridge.get_city(progression)
	var could := city.can_upgrade("lumber_mill")
	_check(could, "a grind session affords a Lumber Mill")
	if could:
		city.upgrade("lumber_mill")
		CityBridge.store_city(progression, city)
		_check(CityBridge.get_city(progression).get_building_level("lumber_mill") == 1,
			"upgrade persists through store/get")

func _test_progression_roundtrip() -> void:
	var progression := {}
	CityBridge.add_kill_to_satchel(progression, "Cave", false)
	CityBridge.bank_satchel(progression, 2_000_000)
	CityBridge.add_kill_to_satchel(progression, "Cave", true)  # left in satchel
	CalamitySystem.schedule(progression, _seeded_rng(7))

	var disk := ProgressionIO.to_disk(progression)
	var live := ProgressionIO.to_live(disk)
	_check(live.get("city", {}) == progression["city"], "city round-trips through ProgressionIO")
	_check(live.get("city_satchel", {}) == progression["city_satchel"], "satchel round-trips")
	_check(live.get("city_calamity", {}) == progression["city_calamity"], "calamity round-trips")

	# SaveData carries the city in its dedicated field too.
	var data := SaveData.new()
	data.city = progression["city"]
	_check(not data.city.is_empty(), "SaveData.city accepts the city dict")

func _test_calamity_flow() -> void:
	var progression := {}
	_check(CalamitySystem.schedule(progression, _seeded_rng(1)).is_empty(),
		"no calamity before the city exists")

	CityBridge.add_kill_to_satchel(progression, "Forest", false)
	CityBridge.bank_satchel(progression, 3_000_000)
	# Stock the city so there is something to lose.
	var city := CityBridge.get_city(progression)
	city.add_resources({"gold": 400, "lumber": 400, "stone": 400, "essence": 100})
	CityBridge.store_city(progression, city)

	var calamity := CalamitySystem.schedule(progression, _seeded_rng(2))
	_check(not calamity.is_empty(), "calamity arms once the city stands")
	_check(CalamitySystem.schedule(progression, _seeded_rng(3)) == CalamitySystem.pending(progression),
		"scheduling twice keeps the same calamity")
	_check(int(calamity["kills_left"]) >= CalamitySystem.KILLS_TO_STRIKE_MIN,
		"countdown starts inside the configured window")

	# Kill until it strikes — exactly once.
	var strikes := 0
	for i in range(CalamitySystem.KILLS_TO_STRIKE_MAX + 5):
		if CalamitySystem.on_kill(progression):
			strikes += 1
	_check(strikes == 1, "the calamity strikes exactly once")
	_check(CalamitySystem.has_struck(progression), "struck state persists")
	_check(CalamitySystem.warning_text(progression) != "", "a struck calamity has warning text")

	# The hero came back fast (few kills since strike) with heroic power.
	var outcome := CalamitySystem.resolve(progression, 999, 3_000_100, _seeded_rng(4))
	_check(not outcome.is_empty(), "a struck calamity resolves in town")
	_check(outcome["hero_joined"], "prompt return puts the hero on the walls")
	_check(CalamitySystem.pending(progression).is_empty(), "resolution clears the calamity")
	city = CityBridge.get_city(progression)
	_check(city.defense_log.size() > 0, "the defense log records the calamity")
	_check(CalamitySystem.resolve(progression, 999, 3_000_200).is_empty(),
		"nothing further to resolve")

	# Dawdling: strike, then many more kills before coming home.
	CalamitySystem.schedule(progression, _seeded_rng(5))
	for i in range(CalamitySystem.KILLS_TO_STRIKE_MAX + CalamitySystem.PROMPT_RESPONSE_KILLS + 10):
		CalamitySystem.on_kill(progression)
	var late := CalamitySystem.resolve(progression, 999, 3_000_300, _seeded_rng(6))
	_check(not late.is_empty() and not late["hero_joined"], "a slow return leaves the city alone")

func _test_disaster_resolution() -> void:
	# Force the storm branch and confirm walls-blunted destruction applies.
	var progression := {}
	CityBridge.add_kill_to_satchel(progression, "Forest", false)
	CityBridge.bank_satchel(progression, 4_000_000)
	var city := CityBridge.get_city(progression)
	city.add_resources({"gold": 1000, "lumber": 1000, "stone": 1000, "essence": 200})
	CityBridge.store_city(progression, city)
	var before_gold := int(CityBridge.get_city(progression).resources["gold"])

	progression["city_calamity"] = {
		"type": "great_storm", "kills_left": 0, "struck": true, "kills_since_strike": 99,
	}
	var outcome := CalamitySystem.resolve(progression, 0, 4_000_100, _seeded_rng(8))
	_check(outcome["kind"] == "disaster", "storm resolves as a disaster")
	var after_gold := int(CityBridge.get_city(progression).resources["gold"])
	_check(after_gold < before_gold, "an unattended storm destroys resources")

func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
