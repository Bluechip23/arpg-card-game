extends SceneTree

## Enemy sheet, Act 1a slice (docs/ENEMY_SHEET.tsv):
##  - Tier vocabulary: the compendium's tier words and the loot tiers follow
##    the sheet's Tier column (Trash / Mid-tier / Elite / Boss / Special).
##  - Rat King — Infest (5 tempo): an Infest card per rat within 10 squares,
##    himself included; held 5 tempo it hatches into 2 Wererats beside the
##    holder; discarded, nothing hatches.
##  - Sewer Cobra — Venom Spray (15 tempo, Async): 8 Poison to everyone in a
##    5-long cone, 10 damage only to the armored; 3 Poison back for a hit
##    that costs it health; 5 Thorns while armored; stunned 3 tempo and every
##    clock reset when its armor breaks.
## Run: godot --headless --path . --script tests/test_sheet_act1a.gd

var failures: int = 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	_test_tiers()
	await _test_lair()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _settle(frames: int = 8) -> void:
	for _i in range(frames):
		await process_frame

func _dismiss(main) -> void:
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame

func _count(main, type: int) -> int:
	var n := 0
	for e in main.enemy_spawner.get_living_enemies():
		if e.enemy_type == type:
			n += 1
	return n

func _first(main, type: int) -> Enemy:
	for e in main.enemy_spawner.get_living_enemies():
		if e.enemy_type == type:
			return e
	return null

func _infests(deck) -> Array:
	var out: Array = []
	for c in deck.hand:
		if c.card_id == "infest":
			out.append(c)
	return out

func _has_effect(e: Enemy, nm: String, stacks: int) -> bool:
	for eff in e.get_active_effects():
		if eff["name"] == nm and int(eff["stacks"]) == stacks:
			return true
	return false

func _test_tiers() -> void:
	print("-- Tier vocabulary --")
	var by_name := {}
	for d in Enemy.get_all_enemy_data():
		by_name[d["name"]] = d
	var words := ["Trash", "Mid-tier", "Elite", "Boss", "Special"]
	var off := []
	for nm in by_name:
		if not (by_name[nm]["type"] in words):
			off.append("%s=%s" % [nm, by_name[nm]["type"]])
	_check(off.is_empty(), "every compendium tier is one of the sheet's five words %s" % str(off))
	var sample := {
		"Bugbear": "Mid-tier", "Rat King": "Boss", "Coyote": "Trash", "Ring Wraith": "Special",
		"Sewer Cobra": "Mid-tier", "Bone Dragon": "Boss", "Hydra": "Elite", "Grave Titan": "Elite",
		"Skeleton": "Mid-tier", "Cherub": "Trash", "Training Dummy": "Special", "Minion": "Trash",
	}
	for nm in sample:
		if not by_name.has(nm):
			# The dummy's compendium name is whatever _stats calls it; skip gently.
			if nm == "Training Dummy":
				continue
			_check(false, "%s is in the compendium" % nm)
			continue
		_check(by_name[nm]["type"] == sample[nm], "%s reads %s (got %s)" % [nm, sample[nm], by_name[nm]["type"]])
	var dummy_ok := false
	for nm in by_name:
		if "Dummy" in nm or "dummy" in nm:
			dummy_ok = by_name[nm]["type"] == "Special"
	_check(dummy_ok, "the dojo dummy reads Special")
	# Loot tiers follow the same column.
	var sp := EnemySpawner.new()
	var loot := {
		Enemy.EnemyType.BUGBEAR: DropRates.TIER_MID, Enemy.EnemyType.RAT_KING: DropRates.TIER_BOSS,
		Enemy.EnemyType.COYOTE: DropRates.TIER_TRASH, Enemy.EnemyType.HYDRA: DropRates.TIER_ELITE,
		Enemy.EnemyType.BONE_DRAGON: DropRates.TIER_BOSS, Enemy.EnemyType.SEWER_CROC: DropRates.TIER_MID,
		Enemy.EnemyType.SKELETON: DropRates.TIER_MID, Enemy.EnemyType.GRAVE_TITAN: DropRates.TIER_ELITE,
		Enemy.EnemyType.WEREGOAT: DropRates.TIER_MID, Enemy.EnemyType.ROC: DropRates.TIER_MID,
		Enemy.EnemyType.SABERTOOTH: DropRates.TIER_MID, Enemy.EnemyType.SNOW_WRAITH: DropRates.TIER_TRASH,
		Enemy.EnemyType.DEMON: DropRates.TIER_MID, Enemy.EnemyType.ASH_HARPY: DropRates.TIER_TRASH,
		Enemy.EnemyType.MAGMA_SPIDER: DropRates.TIER_TRASH, Enemy.EnemyType.MIND_EATER: DropRates.TIER_TRASH,
		Enemy.EnemyType.SPECTER: DropRates.TIER_TRASH, Enemy.EnemyType.SUCCUBUS: DropRates.TIER_TRASH,
		Enemy.EnemyType.CHERUB: DropRates.TIER_TRASH, Enemy.EnemyType.GRANITE_COLOSSUS: DropRates.TIER_BOSS,
		Enemy.EnemyType.CERBERUS: DropRates.TIER_BOSS, Enemy.EnemyType.DJINN: DropRates.TIER_ELITE,
	}
	var wrong := []
	for t in loot:
		if sp.get_loot_tier(t) != loot[t]:
			wrong.append("%s=%s" % [Enemy.EnemyType.keys()[t], sp.get_loot_tier(t)])
	_check(wrong.is_empty(), "loot tiers match the sheet %s" % str(wrong))
	sp.free()
	# The new actions sit in the compendium with their keywords.
	var cobra: Dictionary = by_name["Sewer Cobra"]
	var spray_async := false
	for a in cobra["actions"]:
		if a["name"] == "Venom Spray" and int(a["tempo"]) == 15 and "Async" in a["keywords"]:
			spray_async = true
	_check(spray_async, "the compendium lists Venom Spray · 15 tempo · Async")
	_check("Venom Spray" in str(cobra["special"]) and not ("ambush" in str(cobra["special"])), "the cobra's text is the sheet's kit")
	var king: Dictionary = by_name["Rat King"]
	var infest_listed := false
	for a in king["actions"]:
		if a["name"] == "Infest" and int(a["tempo"]) == 5:
			infest_listed = true
	_check(infest_listed and "Infest" in str(king["special"]), "the compendium lists the Rat King's Infest (5 tempo)")

func _test_lair() -> void:
	print("-- Booting main.tscn as the lair --")
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "ratking_lair")
	get_root().add_child(main)
	await _settle()
	await _dismiss(main)
	var king: Enemy = _first(main, Enemy.EnemyType.RAT_KING)
	if king == null:
		_check(false, "the Rat King is up; skipping the fight")
		main.queue_free()
		await _settle()
		return
	var stats = main.player.get_stats()
	stats.max_health = 500
	stats.current_health = 500
	var deck = main.deck_manager
	var gm = main.grid_manager

	# --- Infest ---
	print("-- Rat King: Infest --")
	var names: Array = []
	for a in king.actions:
		names.append(str(a["name"]))
	_check(names == ["bite", "infest", "move", "seek_nest", "nest_heal"], "the king's table: %s" % str(names))
	_check(gm.get_distance_in_cells(king.position, main.player.position) > 1, "the player starts out of the king's reach")
	king._choose_action(main.player)
	_check(str(king.chosen_action.get("name", "")) == "infest", "out of reach with no brood in the hand, he picks Infest")
	var expected := 0
	for e in main.enemy_spawner.get_living_enemies():
		if e.enemy_type in [Enemy.EnemyType.WERERAT, Enemy.EnemyType.ARCHER_RAT, Enemy.EnemyType.RAT_KING] \
				and gm.get_distance_in_cells(king.position, e.position) <= 10:
			expected += 1
	_check(expected >= 2, "rats within 10 squares of the king, himself included: %d" % expected)
	var hand_before: int = deck.hand.size()
	king._try_infest(main.player)
	var brood: Array = _infests(deck)
	_check(brood.size() == expected and deck.hand.size() == hand_before + expected, "Infest put %d Infest card(s) in the hand (one per rat)" % brood.size())
	if brood.is_empty():
		main.queue_free()
		await _settle()
		return
	var one: Card = brood[0]
	_check(one.mana_cost == 50 and one.tempo_cost == 0 and one.erase_on_play and one.linger and one.hatch_tempo == 5, "an Infest is 50 mana / 0 tempo, erases on play, lingers, fuse 5")
	king._choose_action(main.player)
	_check(str(king.chosen_action.get("name", "")) == "move", "with a brood in the hand he closes in instead")
	# Keep one; discard the rest — a discarded brood is erased, not banked.
	for i in range(1, brood.size()):
		deck.discard_card_from_hand(brood[i])
	var banked := false
	for c in deck.discard_pile:
		if c.card_id == "infest":
			banked = true
	_check(_infests(deck).size() == 1 and not banked, "discarded Infests leave the hand and never reach the discard pile")
	# The clock runs with the king held still (so only the fuse acts).
	king.apply_debuff("stun", 60)
	var rats_before: int = _count(main, Enemy.EnemyType.WERERAT)
	for _t in range(4):
		main.tempo_manager.add_tempo(1)
		await _settle(1)
	_check(one in deck.hand and one.hatch_tempo_left == 1, "4 tempo on: still in the hand, 1 tempo on the fuse")
	_check(_count(main, Enemy.EnemyType.WERERAT) == rats_before, "nothing has hatched yet")
	main.tempo_manager.add_tempo(1)
	await _settle(1)
	_check(not (one in deck.hand), "at 5 tempo the Infest leaves the hand")
	_check(_count(main, Enemy.EnemyType.WERERAT) == rats_before + 2, "and hatches into 2 Wererats (%d -> %d)" % [rats_before, _count(main, Enemy.EnemyType.WERERAT)])
	var pcell: Vector2i = gm.world_to_grid(main.player.position)
	var near := 0
	for e in main.enemy_spawner.get_living_enemies():
		if e.enemy_type == Enemy.EnemyType.WERERAT:
			var c: Vector2i = gm.world_to_grid(e.position)
			if maxi(absi(c.x - pcell.x), absi(c.y - pcell.y)) <= 3 and c != pcell:
				near += 1
	_check(near >= 2, "the hatchlings stand beside the player (%d within 3)" % near)
	# Discarded: the production does not carry out.
	king._try_infest(main.player)
	var second: Array = _infests(deck)
	_check(second.size() >= 1, "a second Infest lays a brood again (%d)" % second.size())
	for c in second:
		deck.discard_card_from_hand(c)
	_check(_infests(deck).is_empty(), "every one discarded")
	rats_before = _count(main, Enemy.EnemyType.WERERAT)
	for _t in range(6):
		main.tempo_manager.add_tempo(1)
		await _settle(1)
	_check(_count(main, Enemy.EnemyType.WERERAT) == rats_before, "6 tempo later nothing hatched from the discarded brood")

	# --- Sewer Cobra ---
	print("-- Sewer Cobra --")
	var center: Vector2i = main.dungeon_manager.RK_CENTER
	main.player.position = main._ground_pos(center)
	main.player.target_position = main.player.position
	var croc: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.SEWER_CROC, main._ground_pos(center + Vector2i(-3, 0)))
	croc.target_position = croc.position
	var cnames: Array = []
	for a in croc.actions:
		cnames.append(str(a["name"]))
	_check(cnames == ["croc_bite", "venom_spray", "move"], "the cobra's table: %s" % str(cnames))
	_check(Enemy.is_async_action(croc.actions[1]) and int(croc.actions[1]["tempo_cost"]) == 15, "Venom Spray is 15 tempo, Async")
	_check(croc.current_armor > 0, "it starts armored (%d)" % croc.current_armor)
	var dm = main.player.get_debuff_manager()
	dm.remove_debuff(Debuff.DebuffType.POISON)
	stats.current_armor = 20
	var hp0: int = stats.current_health
	croc._try_venom_spray(main.player)
	var poison = dm.get_debuff(Debuff.DebuffType.POISON)
	_check(poison != null and poison.value == 8, "Venom Spray: 8 Poison on the player in the cone")
	_check(stats.current_armor == 10 and stats.current_health == hp0, "armored: 10 damage, eaten by the armor (20 -> %d, health untouched)" % stats.current_armor)
	dm.remove_debuff(Debuff.DebuffType.POISON)
	stats.current_armor = 0
	hp0 = stats.current_health
	croc._try_venom_spray(main.player)
	poison = dm.get_debuff(Debuff.DebuffType.POISON)
	_check(poison != null and poison.value == 8 and stats.current_health == hp0, "unarmored: 8 Poison and no damage at all")
	# The cone's shape: 2 forward / 2 aside is outside (half-width 1 there);
	# 5 forward / 2 aside is inside (half-width 2 at the far end).
	dm.remove_debuff(Debuff.DebuffType.POISON)
	main.player.position = main._ground_pos(center + Vector2i(-1, 2))
	main.player.target_position = main.player.position
	croc._try_venom_spray(main.player)
	_check(dm.get_debuff(Debuff.DebuffType.POISON) == null, "2 forward and 2 aside is outside the cone")
	main.player.position = main._ground_pos(center + Vector2i(2, 2))
	main.player.target_position = main.player.position
	croc._try_venom_spray(main.player)
	_check(dm.get_debuff(Debuff.DebuffType.POISON) != null, "5 forward and 2 aside is inside it")
	var cells: Array = croc._venom_cone_cells(main.player)
	_check(cells.size() == 1 + 3 + 3 + 3 + 5, "the cone is %d squares: widths 1, 3, 3, 3, 5" % cells.size())

	# --- Passives ---
	print("-- Sewer Cobra: passives --")
	main.player.position = main._ground_pos(center)
	main.player.target_position = main.player.position
	dm.remove_debuff(Debuff.DebuffType.POISON)
	stats.current_armor = 0
	_check(_has_effect(croc, "Thorns", 5), "while armored it shows Thorns 5")
	croc._async_counters["venom_spray"] = 7
	croc.action_tempo_counter = 2
	PlayerStats.hit_source_direct = true
	var hp1: int = stats.current_health
	croc.take_damage(3, true)
	_check(stats.current_health == hp1 - 5, "a direct hit on its armor costs the attacker 5 (thorns)")
	_check(dm.get_debuff(Debuff.DebuffType.POISON) == null, "armor only: no poison back")
	_check(not croc.is_stunned, "not exposed yet, not stunned")
	var rem: int = croc.current_armor
	hp1 = stats.current_health
	var exposed: bool = croc.take_damage(rem + 4, true)
	_check(exposed and croc.current_armor == 0 and croc.current_health < croc.max_health, "a blow through the last of the armor exposes it")
	_check(stats.current_health == hp1 - 5, "that blow still pays the thorns (armored before it landed)")
	poison = dm.get_debuff(Debuff.DebuffType.POISON)
	_check(poison != null and poison.value == 3, "and, costing it health, poisons the attacker 3")
	_check(croc.is_stunned and croc.stun_tempo == 3, "exposed: stunned for 3 tempo")
	_check(croc.action_tempo_counter == 0 and croc._async_counters.is_empty() and croc.chosen_action.is_empty(), "and every clock is reset (Bite's and Venom Spray's)")
	_check(not _has_effect(croc, "Thorns", 5), "no armor, no Thorns badge")
	hp1 = stats.current_health
	croc.take_damage(2, true)
	poison = dm.get_debuff(Debuff.DebuffType.POISON)
	_check(stats.current_health == hp1 and poison != null and poison.value == 6, "unarmored: a direct health hit poisons 3 more, no thorns")
	PlayerStats.hit_source_direct = false
	hp1 = stats.current_health
	croc.take_damage(1, false)
	poison = dm.get_debuff(Debuff.DebuffType.POISON)
	_check(stats.current_health == hp1 and poison.value == 6, "a DoT tick (not the player's hit) answers nothing")

	main.queue_free()
	await _settle()
