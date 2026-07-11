extends SceneTree

## End-to-end test of the city end-game play loop:
## expedition → resources → build → power grows → raid → loot → defend → persist.
## Run: godot --headless --path . --script tests/test_city_loop.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== City loop test ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# ---- Founding state ----
	var city := CityState.new()
	_check(city.get_building_level("town_hall") == 1, "new city starts with Town Hall 1")
	_check(city.get_power() > 0, "new city has a power score")

	# ---- Expedition: kills convert to resources, banked into the city ----
	var rewards := ExpeditionSystem.rewards_for_kills("Forest", 6, city)
	_check(rewards.get("lumber", 0) > 0 and rewards.get("gold", 0) > 0,
		"Forest kills yield lumber-heavy loot")
	var heavens := ExpeditionSystem.rewards_for_kills("Heavens", 6, city)
	_check(heavens.get("essence", 0) > rewards.get("gold", 0),
		"higher-tier habitat out-yields a tier-1 one")

	var quick := ExpeditionSystem.resolve_quick("Forest", 40, city, rng)
	_check(quick["kills"] > 0, "quick expedition clears monsters (hero power 40 vs tier 1)")
	_check(city.resources["lumber"] > 0, "expedition loot banked into the city")

	# ---- Building: spend resources, town-hall gating, power growth ----
	city.add_resources({"gold": 2000, "lumber": 2000, "stone": 2000, "essence": 200})
	var power_before := city.get_power()
	_check(city.upgrade("lumber_mill"), "can build the Lumber Mill")
	_check(not city.can_upgrade("lumber_mill"),
		"Town Hall 1 gates Lumber Mill at level 1 (must raise the hall first)")
	_check(city.upgrade("town_hall"), "Town Hall upgrades to 2")
	_check(city.upgrade("lumber_mill"), "Lumber Mill can now reach level 2")
	_check(city.get_power() > power_before, "building raises city power")

	# ---- Production accrues lazily over time, capped by storage ----
	var t0 := 1_000_000
	city.last_collect_time = t0
	var gained := city.collect_production(t0 + 3600)  # one hour later
	_check(gained.get("lumber", 0) > 0, "Lumber Mill produced lumber over an hour")
	var rates := city.get_production_per_hour()
	_check(rates["lumber"] == 40, "production scales with level (Lumber Mill 2 = 40/h)")

	# ---- Raids: generated rival, attack resolution, loot banked ----
	var rival := RaidSystem.generate_rival(200, rng)
	_check(rival.get_power() >= 200, "generated rival reaches the requested power")
	var rival_gold: int = rival.resources["gold"]
	_check(rival_gold > 0, "rival city holds lootable resources")

	# Overwhelming attack must win and steal loot.
	var win := RaidSystem.resolve_raid(rival.get_defense_power() * 3, rival, t0, "You")
	_check(win["won"], "overwhelming attack wins the raid")
	_check(win["loot"].get("gold", 0) > 0, "winning raid steals gold")
	_check(rival.resources["gold"] < rival_gold, "loot actually leaves the rival city")
	_check(rival.defense_log.size() == 1 and rival.defense_log[0]["won"],
		"rival's defense log records the breach")

	# Feeble attack must fail and steal nothing.
	var strong := RaidSystem.generate_rival(400, rng)
	var loss := RaidSystem.resolve_raid(1, strong, t0)
	_check(not loss["won"] and loss["loot"].is_empty(), "feeble attack loses and loots nothing")

	# Player-side raid banks winnings into the player's city.
	var before_gold: int = city.resources["gold"]
	var target := RaidSystem.generate_rival(150, rng)
	var my_raid := RaidSystem.raid_rival(city, 500, target, t0)
	if my_raid["won"] or my_raid["partial"]:
		_check(city.resources["gold"] >= before_gold, "raid winnings banked into my city")
	else:
		_check(false, "hero power 500 + city military should beat a 150-power rival")

	# ---- Vault protection ----
	var vaulted := CityState.new()
	vaulted.add_resources({"gold": 1000})
	vaulted.buildings["vault"] = 5  # 30% protected
	var raided := RaidSystem.resolve_raid(9999, vaulted, t0)
	var stolen: int = raided["loot"].get("gold", 0)
	_check(stolen <= int(1000 * 0.7 * RaidSystem.LOOT_FRACTION) + 1,
		"vault shields a share of resources from looting")

	# ---- Incoming raid (defense while away) ----
	var incoming := RaidSystem.simulate_incoming_raid(city, t0 + 100, rng)
	_check(city.defense_log.size() >= 1, "incoming raid lands in my defense log")
	_check(incoming.has("won"), "incoming raid resolves either way")

	# ---- Persistence round-trip ----
	var dict := city.to_dict()
	var restored := CityState.from_dict(dict)
	_check(restored.resources == city.resources, "resources survive save/load")
	_check(restored.buildings == city.buildings, "building levels survive save/load")
	_check(restored.defense_log.size() == city.defense_log.size(), "defense log survives save/load")

	# ---- Storage cap ----
	var capped := CityState.new()
	capped.add_resources({"gold": 99999})
	_check(capped.resources["gold"] == capped.get_storage_cap(), "storage cap clamps hoarding")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
