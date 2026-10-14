extends SceneTree

## Every stored designed build of every character assembles through the
## real rules without a refusal at level 18 (mythic cap one, carry weight,
## slot labels, sphere gates, passive points), Ryan's also at level 50
## (cap three), and compose() swaps components and scales points.
## Run: godot --headless --path . --script tests/test_sim_builds.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	print("=== Stored builds test ===")
	var runner := SimRunner.new(self)
	for character in CharacterBuilds.CHARACTERS:
		var comp := CharacterBuilds.components(character)
		_check(not comp.is_empty(), "%s has a build library" % character)
		for build in comp.get("designed", []):
			var sc := SimScenario.with_defaults(CharacterBuilds.compose(character, {"build": build, "enemy": "WERERAT"}))
			_check(SimScenario.validate(sc) == "", "%s/%s validates" % [character, build])
			var policy = load("res://tests/sim/policies/lookahead.gd").new()
			var summary: Dictionary = await runner.run(sc, policy, 1)
			_check(runner.warnings.is_empty(), "%s/%s builds with no refusals: %s" % [character, build, str(runner.warnings)])
			_check(summary["outcome"] in ["win", "loss", "timeout"], "%s/%s ran to %s" % [character, build, summary["outcome"]])
	# Level 50: three mythics fit, points scale, nothing is refused.
	for build in ["shadow_blade", "bruiser"]:
		var sc := SimScenario.with_defaults(CharacterBuilds.compose("ryan", {"build": build, "level": 50, "enemy": "WERERAT"}))
		var alloc_total := 0
		for k in sc["player"]["allocation"]:
			alloc_total += int(sc["player"]["allocation"][k])
		_check(alloc_total == 49 * 3, "ryan/%s at 50 spends all %d stat points (%d)" % [build, 49 * 3, alloc_total])
		var mythics := 0
		for it in sc["player"]["items"]:
			if CharacterBuilds.is_mythic(str(it[0])):
				mythics += 1
		_check(mythics == 3, "ryan/%s at 50 wears three mythics (%d)" % [build, mythics])
		var policy = load("res://tests/sim/policies/lookahead.gd").new()
		var summary: Dictionary = await runner.run(sc, policy, 1)
		_check(runner.warnings.is_empty(), "ryan/%s at 50 builds with no refusals: %s" % [build, str(runner.warnings)])
	# focus= maxes one passive first and spreads the rest over the build's set.
	var tree: Array = CharacterBuilds.tree_passives("ryan")
	_check(tree.size() == 12 and tree.has("let's_dance") and tree.has("eye_scrape"), "ryan's tree offers 12 upgradeable passives (%s)" % str(tree))
	var focused := SimScenario.with_defaults(CharacterBuilds.compose("ryan", {"build": "shadow_blade", "level": 50, "focus": "let's_dance", "enemy": "WERERAT"}))
	var ranks: Dictionary = focused["player"]["passives"]
	var rank_total := 0
	for k in ranks:
		rank_total += int(ranks[k])
	_check(int(ranks.get("let's_dance", 0)) == 15 and rank_total == 49, "focus at 50: let's_dance 15, all 49 points spent (%s)" % str(ranks))
	var focused18 := SimScenario.with_defaults(CharacterBuilds.compose("ryan", {"build": "bruiser", "focus": "quick_step", "enemy": "WERERAT"}))
	ranks = focused18["player"]["passives"]
	rank_total = 0
	for k in ranks:
		rank_total += int(ranks[k])
	_check(int(ranks.get("quick_step", 0)) == 15 and rank_total == 17, "focus at 18: quick_step 15 + 2 spread (%s)" % str(ranks))
	var focused_none := SimScenario.with_defaults(CharacterBuilds.compose("ryan", {"build": "bruiser", "passives": "none", "level": 50, "focus": "pop_rocks", "enemy": "WERERAT"}))
	ranks = focused_none["player"]["passives"]
	rank_total = 0
	for k in ranks:
		rank_total += int(ranks[k])
	_check(int(ranks.get("pop_rocks", 0)) == 15 and rank_total == 49 and ranks.size() == 12, "focus on an empty set spreads the rest over the other tree passives (%s)" % str(ranks))
	# The card pool and the deck recipes.
	var pool: Array = SimDeckBuilder.legal_ids()
	var leaks: Array = []
	for id in pool:
		if id.ends_with("_copy") or id in ["fireball", "improvised_ammo", "polymorph"]:
			leaks.append(id)
	_check(pool.size() >= 150 and leaks.is_empty(), "card pool holds every base-deck-legal card (%d) and no tokens, engraving-only or item-granted cards (%s)" % [pool.size(), str(leaks)])
	var r1 := CharacterBuilds.compose("ryan", {"build": "shadow_blade", "recipe": "poisoner", "enemy": "WERERAT"})
	var r2 := CharacterBuilds.compose("ryan", {"build": "shadow_blade", "recipe": "poisoner", "enemy": "WERERAT"})
	_check(r1["player"]["deck"].size() == 12 and r1["player"]["deck"] == r2["player"]["deck"], "a recipe deck has 12 cards and is deterministic (%s)" % str(r1["player"]["deck"]))
	var poison_cards := 0
	for id in r1["player"]["deck"]:
		if "poison" in id or "potion" in id or "toxin" in id:
			poison_cards += 1
	_check(poison_cards >= 5, "the poisoner recipe is on theme (%d poison/potion cards)" % poison_cards)
	for rname in CharacterBuilds.recipes("ryan"):
		var rs := SimScenario.with_defaults(CharacterBuilds.compose("ryan", {"build": "bruiser", "recipe": rname, "enemy": "WERERAT"}))
		var rsum: Dictionary = await runner.run(rs, load("res://tests/sim/policies/greedy_dpt.gd").new(), 1)
		_check(rsum["outcome"] != "error" and runner.warnings.is_empty(), "recipe %s builds and runs with no refusals: %s" % [rname, str(runner.warnings)])
	var sw := SimScenario.with_defaults(CharacterBuilds.compose("ryan", {"build": "bruiser", "swap": "poison_bomb", "enemy": "WERERAT"}))
	_check(sw["player"]["deck"].back() == "poison_bomb" and sw["player"]["opening_hand"] == ["poison_bomb"] and sw["player"]["deck"].size() == 12, "swap= replaces the last deck card and spotlights it (%s)" % str(sw["player"]["deck"]))
	# Tactics overlay any build.
	var tac := SimScenario.with_defaults(CharacterBuilds.compose("ryan", {"build": "bruiser", "tactic": "invisibility", "enemy": "WERERAT"}))
	var tac_items: Array = []
	for it in tac["player"]["items"]:
		tac_items.append(str(it[0]))
	_check(tac["player"]["deck"].slice(-3) == ["shadows", "shadows", "blink"] and tac["player"]["deck"].size() == 12, "a tactic's cards replace the deck's tail (%s)" % str(tac["player"]["deck"]))
	_check("shadow_obi" in tac_items and not "belt_of_wumbology" in tac_items and tac_items.size() == 10, "a tactic's item takes the same-type, same-slot entry (%s)" % str(tac_items))
	_check(int(tac["player"]["passives"].get("now_you_see_me", 0)) > 0, "a tactic's passive weights join the spread (%s)" % str(tac["player"]["passives"]))
	for tname in CharacterBuilds.tactics("ryan"):
		var ts := SimScenario.with_defaults(CharacterBuilds.compose("ryan", {"build": "spellslinger", "tactic": tname, "enemy": "WERERAT"}))
		var tsum: Dictionary = await runner.run(ts, load("res://tests/sim/policies/greedy_dpt.gd").new(), 1)
		_check(tsum["outcome"] != "error" and runner.warnings.is_empty(), "tactic %s builds and runs with no refusals: %s" % [tname, str(runner.warnings)])
	# Item swaps: the tested item is worn, in its natural slot, and changes nothing else.
	var item_ids := func(sc: Dictionary) -> Array:
		var out: Array = []
		for e in sc["player"]["items"]:
			out.append(str(e[0]))
		return out
	var missing: Array = []
	for b in RyanBuilds.DESIGNED:
		for iid in CharacterBuilds.item_pool():
			var isc := CharacterBuilds.compose("ryan", {"build": b, "item": iid})
			if not iid in item_ids.call(isc):
				missing.append("%s+%s" % [b, iid])
	_check(missing.is_empty(), "every pool item is worn when swapped into every Ryan build (%d missing: %s)" % [missing.size(), str(missing.slice(0, 6))])
	var base_apo: Array = item_ids.call(CharacterBuilds.compose("ryan", {"build": "apothecary"}))
	var apo: Array = item_ids.call(CharacterBuilds.compose("ryan", {"build": "apothecary", "item": "monocle"}))
	var changed: Array = []
	for iid in apo:
		if not iid in base_apo:
			changed.append(iid)
	_check(changed == ["monocle"] and apo.size() == base_apo.size(), "a legendary in the headline mythic's slot changes only that slot (%s)" % str(changed))
	var bow: Array = CharacterBuilds.compose("ryan", {"build": "bruiser", "item": "bow_of_arash"})["player"]["items"]
	var off_hand := false
	for e in bow:
		if int(e[1]) == 1 and CharacterBuilds._item_type(str(e[0])) == ItemData.ItemType.WEAPON:
			off_hand = true
	_check(not off_hand and bow[0][0] == "bow_of_arash", "a two-handed bow clears the off hand (%s)" % str(bow))
	var ring: Array = item_ids.call(CharacterBuilds.compose("ryan", {"build": "bruiser", "item": "cyclops_ring"}))
	_check(ring.count("cyclops_ring") == 1 and ring.has("marvolo_gaunt") and not ring.has("ring_of_stone_hide"), "a ring takes ring slot 0 and keeps slot 1 (%s)" % str(ring))
	# compose swaps components and keeps the rest.
	var mixed := SimScenario.with_defaults(CharacterBuilds.compose("ryan", {"build": "bruiser", "deck": "potions", "alloc": "int_wis", "sphere": "none", "passives": "apothecary", "enemy": "WERERAT"}))
	_check(mixed["player"]["deck"] == SimDecks.DECKS["potions"], "compose swaps the deck")
	# Engravings: the options follow the game's slot rules; engrave: fills a
	# free slot or replaces the last card, spotlights it; ~none strips.
	var eo := CharacterBuilds.engrave_options("stephen", "heavy_swing")
	_check(eo.has("fallens_wrath") and "savage_strike" in eo["fallens_wrath"] and not "slash" in eo["fallens_wrath"] and not eo.has("hide_of_garmr"),
		"engrave options: Fallen's Wrath takes Sword cards, never an unlabeled one, and slotless items are absent (%s)" % str(eo.keys()))
	var base_sl: Dictionary = CharacterBuilds.compose("stephen", {"build": "heavy_swing"})["player"]["slotted"]
	var eg := CharacterBuilds.compose("stephen", {"build": "heavy_swing", "engrave": "fallens_wrath~parry"})
	var fw: Array = eg["player"]["slotted"]["fallens_wrath"]
	_check(fw.size() == (base_sl["fallens_wrath"] as Array).size() and fw.back() == "parry" and eg["player"]["opening_hand"] == ["parry"],
		"engrave: replaces the full item's last card and spotlights it (%s -> %s)" % [str(base_sl["fallens_wrath"]), str(fw)])
	var eg2 := CharacterBuilds.compose("stephen", {"build": "heavy_swing", "engrave": "equator~approach"})
	_check(eg2["player"]["slotted"].get("equator", []) == (base_sl.get("equator", []) as Array) + ["approach"],
		"engrave: fills a free slot (%s)" % str(eg2["player"]["slotted"].get("equator", [])))
	_check(not CharacterBuilds.compose("stephen", {"build": "heavy_swing", "engrave": "fallens_wrath~none"})["player"]["slotted"].has("fallens_wrath"),
		"engrave ~none strips the item")
	var egsum: Dictionary = await runner.run(SimScenario.with_defaults(eg), load("res://tests/sim/policies/lookahead.gd").new(), 1)
	_check(runner.warnings.is_empty() and egsum["outcome"] != "error", "an engraving variant builds and runs clean (%s)" % str(runner.warnings))
	# Hands: a two-handed grip empties the off hand and is taken through the
	# game; a weapon can be tried in the off hand (dual wield); the grip can
	# be taken or released mid-fight at a weapon swap's price.
	var th := SimScenario.with_defaults(CharacterBuilds.compose("stephen", {"build": "heavy_swing", "two_hand": "yes", "enemy": "LARGE_BEAR"}))
	var th_items: Array = th["player"]["items"].map(func(e): return str(e[0]))
	_check(th["player"]["two_hand"] == 0 and "fallens_wrath" in th_items and not "sword_breaker" in th_items,
		"two_hand:yes keeps the main weapon and empties the off hand (%s)" % str(th_items))
	await runner.boot_only(th, 1)
	var th_inv = runner.main.player.get_inventory()
	var th_stats = runner.main.player.get_stats()
	_check(runner.warnings.is_empty() and th_inv.two_handed_slot == 0 and th_stats.two_hand_damage_bonus == 2,
		"the grip is the game's: Fallen's Wrath held two-handed, +2 damage (%s)" % str(runner.warnings))
	var gstate := SimState.new(runner.main)
	gstate.refresh()
	var rel: Array = gstate.grips.filter(func(g): return not g["enable"])
	_check(rel.size() == 1 and int(rel[0]["bonus"]) == 2, "the policy is offered the release, worth the +2 it gives up (%s)" % str(gstate.grips))
	var t_before: int = runner.main.tempo_manager.global_tempo
	var released := runner._apply_action({"type": "grip", "grip": gstate.grips.find(rel[0]), "slot": 0, "enable": false}, gstate)
	_check(released and th_inv.two_handed_slot == -1 and th_stats.two_hand_damage_bonus == 0 and runner.main.tempo_manager.global_tempo - t_before >= 2,
		"releasing the grip mid-fight goes through the game and costs a weapon swap's tempo (%d)" % (runner.main.tempo_manager.global_tempo - t_before))
	runner.teardown()
	var bow_grip := CharacterBuilds.compose("ryan", {"build": "ranged_ambusher", "two_hand": "yes"})
	_check(bow_grip["player"]["two_hand"] == -1 and str(bow_grip["notes"]).contains("two-handed by nature"),
		"a bow takes no grip: flagged, not faked (%s)" % str(bow_grip["notes"]))
	var oh := SimScenario.with_defaults(CharacterBuilds.compose("stephen", {"build": "heavy_swing", "item": "rusty_dagger@offhand", "enemy": "LARGE_BEAR"}))
	var oh_items: Array = oh["player"]["items"]
	_check(oh_items.has(["rusty_dagger", 1]) and oh_items.any(func(e): return str(e[0]) == "fallens_wrath" and int(e[1]) == 0) and not oh_items.any(func(e): return str(e[0]) == "sword_breaker"),
		"item:<id>@offhand puts the weapon in the off hand beside the main one (%s)" % str(oh_items))
	await runner.boot_only(oh, 1)
	_check(runner.warnings.is_empty() and runner.main.player.get_inventory().is_dual_wielding(), "and the game reads it as dual wielding (%s)" % str(runner.warnings))
	runner.teardown()
	var cross := CharacterBuilds.compose("brad", {"build": "immovable_warden", "deck": "spells"})
	_check(cross["player"]["deck"] == SimDecks.DECKS["spells"] and CharacterBuilds.components("cory")["deck"] == SimDecks.DECKS.keys(),
		"decks are shared: Brad loads the spell deck, every character lists every deck")
	_check(mixed["player"]["allocation"] == CharacterBuilds.spread(RyanBuilds.ALLOCS["int_wis"], 51), "compose swaps the allocation")
	_check(mixed["player"]["sphere_targets"].is_empty() and mixed["player"]["passives"] == CharacterBuilds.spread(RyanBuilds.PASSIVES["apothecary"], 17, 15), "compose swaps sphere path and passives")
	var own_ids: Array = []
	for e in RyanBuilds.ITEM_SETS["bruiser"]:
		own_ids.append(str(e[0]))
		if e.size() > 2:
			own_ids.append(str(e[2]))
	var all_own := true
	for it in mixed["player"]["items"]:
		all_own = all_own and (str(it[0]) in own_ids)
	_check(all_own and mixed["player"]["items"].size() == RyanBuilds.ITEM_SETS["bruiser"].size(), "the build's own gear (or its fallbacks) stays")
	# Gauntlet skills are actions the policy takes: Cuffs of Current's Zeet fires on a bear.
	var zs := SimScenario.with_defaults(CharacterBuilds.compose("ryan", {"build": "spellslinger", "item": "cuffs_of_current", "enemy": "LARGE_BEAR"}))
	var zsum: Dictionary = await runner.run(zs, load("res://tests/sim/policies/lookahead.gd").new(), 1)
	_check(str(zsum.get("skills_used", "")).contains("zeet:"), "the policy fires an equipped gauntlet skill (%s)" % str(zsum.get("skills_used", "")))
	# Weapon swaps: a second weapon set as build II (Stephen) or on the War Rack (Brad).
	var st := CharacterBuilds.compose("stephen", {"build": "heavy_swing", "enemy": "WYVERN"})
	_check(st["player"]["alt_weapons"] == [["long_bow", 0], ["standard_quiver", 1]] and st["player"]["alt_slotted"].has("long_bow"),
		"a designed build carries its second weapon set (%s)" % str(st["player"]["alt_weapons"]))
	_check(CharacterBuilds.compose("stephen", {"build": "heavy_swing", "alt": "none"})["player"]["alt_weapons"].is_empty(), "alt:none fights with one set")
	var st_swaps: Array = []
	var st_warn: Array = []
	for sd in range(1, 5):
		var stsum: Dictionary = await runner.run(SimScenario.with_defaults(st), load("res://tests/sim/policies/lookahead.gd").new(), sd)
		st_swaps.append(str(stsum.get("weapon_swaps", "")))
		st_warn.append_array(runner.warnings)
	_check(st_warn.is_empty() and st_swaps.any(func(v): return v.contains("build2:")),
		"Stephen switches to his bow build against the Wyvern on some of seeds 1-4 (%s, %s)" % [str(st_swaps), str(st_warn)])
	var br := SimScenario.with_defaults(CharacterBuilds.compose("brad", {"build": "immovable_warden", "enemy": "LARGE_BEAR"}))
	var brsum: Dictionary = await runner.run(br, load("res://tests/sim/policies/lookahead.gd").new(), 1)
	_check(runner.warnings.is_empty() and str(brsum.get("weapon_swaps", "")).contains("rack_free:"),
		"Brad takes the War Rack's free exchange (%s, %s)" % [str(brsum.get("weapon_swaps", "")), str(runner.warnings)])
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
