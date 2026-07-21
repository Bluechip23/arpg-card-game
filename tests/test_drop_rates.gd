extends SceneTree

## Verifies the drop-rate system: the per-act mythic pity ("mythic creep"),
## the act-1 one-mythic cap, baseline chest/enemy rarity weights, and the
## card rarity tiers.
## Run: godot --headless --path . --script tests/test_drop_rates.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Drop rates test ===")

	_test_creep_math()
	_test_act_gating()
	_test_pity_rolls()
	_test_weights()
	_test_card_rarities()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_creep_math() -> void:
	print("-- Mythic creep math --")
	_check(DropRates.creep_chance(1) == DropRates.MYTHIC_CREEP_BASE,
		"first kill of an act rolls the base creep chance")
	_check(DropRates.creep_chance(50) > DropRates.creep_chance(10),
		"creep chance grows with every kill")

	# The act mythic must be near-certain within a reasonable kill count.
	var p_none := 1.0
	var kills_to_99 := 0
	for k in range(1, 500):
		p_none *= 1.0 - minf(1.0, DropRates.creep_chance(k))
		if kills_to_99 == 0 and p_none < 0.01:
			kills_to_99 = k
	_check(p_none < 0.000001, "an act mythic is effectively guaranteed within 500 kills")
	_check(kills_to_99 > 0 and kills_to_99 < 200,
		"99%% of players see the act mythic within %d kills (target < 200)" % kills_to_99)

func _test_act_gating() -> void:
	print("-- Act gating --")
	_check(DropRates.mythic_chance(2, false, 30, DropRates.TIER_TRASH) == DropRates.creep_chance(30),
		"before the act mythic: creep chance applies (even to trash kills)")
	_check(DropRates.mythic_chance(2, true, 0, DropRates.TIER_TRASH) == 0.0,
		"after the act mythic: trash returns to zero mythic chance")
	_check(DropRates.mythic_chance(2, true, 0, DropRates.TIER_BOSS) ==
		DropRates.MYTHIC_BASELINE_BY_TIER[DropRates.TIER_BOSS],
		"after the act mythic: bosses keep their baseline chance")
	_check(DropRates.mythic_chance(1, true, 0, DropRates.TIER_BOSS) == 0.0,
		"act 1 is capped at one mythic — even bosses drop none afterward")

	var c = CharacterData.new()
	_check(not DropRates.act1_mythic_locked(c), "fresh character: act-1 chests unlocked")
	c.act_mythic_found.append(1)
	_check(DropRates.act1_mythic_locked(c), "act-1 mythic found: act-1 chests locked")

func _test_pity_rolls() -> void:
	print("-- Pity roll state machine --")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var c = CharacterData.new()

	# Grind act 2 until the creep pops.
	var kills := 0
	var dropped := false
	while not dropped and kills < 500:
		kills += 1
		dropped = DropRates.roll_act_mythic_kill(c, 2, DropRates.TIER_TRASH, rng)
	_check(dropped, "the creep produced the act-2 mythic (after %d kills)" % kills)
	_check(c.act_mythic_found.has(2), "act 2 marked as served")
	_check(not c.act_mythic_kills.has(2), "act-2 kill counter cleared after the drop")

	# After the drop, trash never rolls mythics and the counter stays frozen.
	var again := false
	for i in range(300):
		if DropRates.roll_act_mythic_kill(c, 2, DropRates.TIER_TRASH, rng):
			again = true
	_check(not again, "act 2 trash drops no further mythics (baseline 0)")
	_check(not c.act_mythic_kills.has(2), "no creep counter regrows after the act is served")

	# Act 1 cap: once served, even bosses roll nothing.
	c.act_mythic_found.append(1)
	var act1 := false
	for i in range(300):
		if DropRates.roll_act_mythic_kill(c, 1, DropRates.TIER_BOSS, rng):
			act1 = true
	_check(not act1, "act 1 stays mythic-free once its one mythic dropped")

	# Other acts are independent: act 3's creep starts fresh.
	DropRates.roll_act_mythic_kill(c, 3, DropRates.TIER_TRASH, rng)
	_check(int(c.act_mythic_kills.get(3, 0)) == 1, "act 3 creep counts kills independently")

func _test_weights() -> void:
	print("-- Rarity weight tables --")
	# Chests: mythic/legendary sit at the 1%/3% baseline.
	var total := 0
	for r in DropRates.CHEST_ITEM_WEIGHTS:
		total += int(DropRates.CHEST_ITEM_WEIGHTS[r])
	_check(total == 100, "chest weights sum to 100 (read as percentages)")
	_check(int(DropRates.CHEST_ITEM_WEIGHTS[ItemData.Rarity.MYTHIC]) == 1,
		"chest mythic chance is the 1%% baseline")
	_check(int(DropRates.CHEST_ITEM_WEIGHTS[ItemData.Rarity.LEGENDARY]) == 3,
		"chest legendary chance is the 3%% baseline")

	# Enemy tables never contain mythics (the pity layer owns those).
	for tier in DropRates.ENEMY_ITEM_WEIGHTS:
		_check(not DropRates.ENEMY_ITEM_WEIGHTS[tier].has(ItemData.Rarity.MYTHIC),
			"enemy tier '%s' rolls no mythics of its own" % tier)
	_check(not DropRates.ENEMY_ITEM_WEIGHTS[DropRates.TIER_TRASH].has(ItemData.Rarity.LEGENDARY),
		"trash enemies roll no legendaries")

	# Weighted roll respects the table and rough proportions.
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var mythics := 0
	for i in range(20000):
		if DropRates.roll_weighted(DropRates.CHEST_ITEM_WEIGHTS, rng) == ItemData.Rarity.MYTHIC:
			mythics += 1
	_check(mythics > 100 and mythics < 320,
		"20k chest rolls yield ~1%% mythics (%d)" % mythics)

func _test_card_rarities() -> void:
	print("-- Card rarity tiers --")
	# Every card the game can create is labeled, and every label maps to a card.
	var script: Script = Card
	var discovered := {}
	for method in script.get_script_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("create_") and method["args"].size() == 0:
			var card = script.call(method_name)
			if card is Card:
				discovered[card.card_id] = true
	var unlabeled: Array = []
	for cid in discovered:
		if not Card.CARD_RARITIES.has(cid):
			unlabeled.append(cid)
	_check(unlabeled.is_empty(), "every created card has a rarity label %s" % str(unlabeled))
	var orphaned: Array = []
	for cid in Card.CARD_RARITIES:
		if not discovered.has(cid):
			orphaned.append(cid)
	_check(orphaned.is_empty(), "every rarity label maps to a real card %s" % str(orphaned))

	# Droppable pools exist for each tier and exclude the token/status cards.
	for r in [Card.Rarity.BASIC, Card.Rarity.COMMON, Card.Rarity.RARE,
			Card.Rarity.LEGENDARY, Card.Rarity.MYTHIC]:
		var pool = Card.get_droppable_ids_of_rarity(r)
		_check(pool.size() > 0, "card rarity tier %d has %d droppable card(s)" % [r, pool.size()])
		for excluded in Card.DROP_EXCLUDED_CARD_IDS:
			_check(not pool.has(excluded), "%s stays out of drop pools" % excluded)

	# Spot checks.
	_check(Card.create_slash().get_rarity() == Card.Rarity.BASIC, "Slash is Basic")
	_check(Card.create_fireball().get_rarity() == Card.Rarity.LEGENDARY, "Fireball is Legendary")
	_check(Card.create_worms_armageddon().get_rarity() == Card.Rarity.MYTHIC, "Worm's Armageddon is Mythic")
	_check(Card.create_by_id("fireball") != null and Card.create_by_id("fireball").card_id == "fireball",
		"create_by_id resolves cards")
	_check(Card.create_by_id("nonexistent") == null, "create_by_id returns null for unknowns")