extends SceneTree

## The card and zone mechanics the simulated player now handles, each set up
## through the game's own calls and acted on through the runner: the
## Manifest zone, Burden jail, dismissing a maintained Power, point-aimed
## hits, armor in a card's hit, and the prompt answers (a "discard which
## card?" picker, Defensive Sacrifice, Crack of Mintaka's multi-pick).
## Run: godot --headless --path . --script tests/test_sim_mechanics.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: " + msg)
	else:
		print("  FAIL: " + msg)
		failures += 1

func _initialize() -> void:
	_run.call_deferred()

func _give(dm, id: String) -> int:
	var c = dm._create_card_from_id(id)
	dm.hand.append(c)
	return dm.hand.size() - 1

func _run() -> void:
	print("=== Sim mechanics test ===")
	var runner := SimRunner.new(self)
	var policy = load("res://tests/sim/policies/lookahead.gd").new()
	var sc := SimScenario.with_defaults(CharacterBuilds.compose("ryan", {"build": "bruiser", "enemy": "LARGE_BEAR"}))
	sc["enemies"] = [{"type": "LARGE_BEAR", "cell": [10, 7], "overrides": {}}]
	await runner.boot_only(sc, 1)
	var main = runner.main
	var dm = main.deck_manager
	var stats = main.player.get_stats()
	stats.current_mana = float(stats.get_available_max_mana())

	# --- Manifest zone: Shuriken Pouch turns an overdraw into a Shuriken.
	var sp := _give(dm, "shuriken_pouch")
	_check(runner._apply_action({"type": "play", "card": sp, "card_id": "shuriken_pouch", "target": "self"}, SimState.new(main)),
		"Shuriken Pouch plays (an overflow mode)")
	while dm.hand.size() < dm.get_hand_cap() and not dm.draw_pile.is_empty():
		dm.draw_card()
	dm.attempt_draw()
	var st := SimState.new(main)
	_check(not st.manifest.is_empty(), "an overdraw lands in the Manifest zone (%s)" % str(st.manifest.map(func(m): return m["id"])))
	var macts: Array = st.legal_actions().filter(func(a): return a["type"] == "manifest")
	_check(not macts.is_empty(), "the zone's entry is a legal action")
	var bear = main.enemy_spawner.get_living_enemies()[0]
	var hp0: int = bear.current_health
	var zone0: int = main.overflow_manager.manifest_zone.size()
	if not macts.is_empty():
		_check(runner._apply_action(macts[0], st) and main.overflow_manager.manifest_zone.size() < zone0 and bear.current_health < hp0,
			"clicking it through main fires the Shuriken (bear %d -> %d)" % [hp0, bear.current_health])

	# --- Burden jail: a Burden card that has grown is jailed and reset.
	var hh := _give(dm, "healthy_habit")
	dm.hand[hh].burden_plays = 3
	st = SimState.new(main)
	var jacts: Array = st.legal_actions().filter(func(a): return a["type"] == "jail")
	_check(jacts.size() == 1, "a grown Burden card can be jailed (%d option)" % jacts.size())
	var habit = dm.hand[hh]
	if jacts.size() == 1:
		_check(runner._apply_action(jacts[0], st) and dm.jail_pile.has(habit) and habit.burden_plays == 0,
			"jailing it goes through the J-key path: in jail, its growth reset")

	# --- Maintained Power: Halo stays in play holding its mana; dismissing frees it.
	stats.current_mana = float(stats.get_available_max_mana())
	var hi := _give(dm, "halo")
	var reserved0: int = stats.maintained_mana
	_check(runner._apply_action({"type": "play", "card": hi, "card_id": "halo", "target": "self"}, SimState.new(main)) and dm.maintained_cards.size() == 1,
		"Halo plays and is maintained")
	st = SimState.new(main)
	var dacts: Array = st.legal_actions().filter(func(a): return a["type"] == "dismiss")
	_check(dacts.size() == 1 and st.maintained[0]["id"] == "halo", "a maintained card can be dismissed")
	if dacts.size() == 1:
		_check(runner._apply_action(dacts[0], st) and dm.maintained_cards.is_empty() and stats.maintained_mana == reserved0,
			"dismissing it through the panel's handler frees the reserve")

	# --- Point-aimed hits: a circle catches every enemy in it, a line pierces.
	st = SimState.new(main)
	var fb = dm._create_card_from_id("fireball")
	var bear_cell: Vector2i = st.enemies[0]["cell"]
	_check(st.point_hits(fb, bear_cell) == [0], "Fireball aimed at the bear hits it")
	_check(st.point_hits(fb, bear_cell + Vector2i(6, 0)).is_empty(), "Fireball aimed far away hits nothing")
	var arrow = dm._create_card_from_id("balistic_arrow")
	_check(st.point_hits(arrow, st.player_cell + Vector2i(1, 0)) == [0], "Balistic Arrow aimed one tile toward the bear pierces it")
	# Armor: a card's hit counts what it strips, like the auto attack.
	bear.current_armor = 200
	var slash = dm._create_card_from_id("slash")
	_check(st.card_hit(slash, bear) > 0 and main.calculate_damage_preview(slash, bear) == 0,
		"into 200 armor the preview reads 0 but the hit still counts (%d)" % st.card_hit(slash, bear))
	bear.current_armor = 0

	# --- Prompt answers.
	dm.hand.clear()
	for id in ["enchantment_attack", "draw", "slash"]:
		_give(dm, id)
	st = SimState.new(main)
	var names: Array = st.hand.map(func(h): return h["name"])
	var di: int = policy.answer_prompt("discard", names, st)
	_check(st.hand[di]["id"] != "enchantment_attack", "a discard picker keeps the enchantment (gives up %s)" % st.hand[di]["id"])
	_give(dm, "defensive_sacrifice")
	st = SimState.new(main)
	_check(policy.answer_prompt("defensive_sacrifice:60", ["Sacrifice"], st) == 0, "Defensive Sacrifice is taken against a 60-damage blow")
	_check(policy.answer_prompt("defensive_sacrifice:2", ["Sacrifice"], st) == -1, "and declined against a 2-damage one")
	var labels: Array = st.hand.map(func(h): return "%s  (0m/1t)" % h["name"])
	var picks: Array = policy.answer_multi("crack_of_mintaka:2", labels, st)
	_check(picks.size() == 2, "Crack of Mintaka discards exactly what reaches a target 2 squares away (%s)" % str(picks))
	runner.teardown()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
