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
	# compose swaps components and keeps the rest.
	var mixed := SimScenario.with_defaults(CharacterBuilds.compose("ryan", {"build": "bruiser", "deck": "potions", "alloc": "int_wis", "sphere": "none", "passives": "apothecary", "enemy": "WERERAT"}))
	_check(mixed["player"]["deck"] == RyanBuilds.DECKS["potions"], "compose swaps the deck")
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
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
