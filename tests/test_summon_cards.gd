extends SceneTree

## The summon cards (designer, 2026-10-27): Summon Skeleton, Summon Battle
## Turtle, Skeleton Army, Turtle Power and Summon Shadow Hound — their sheet
## rows (type, slots, rarity, mana, tempo, range), Summon Skeleton's 45 - INT
## mana with the refund above 45 INT, what each summons and how it behaves,
## the turtle's armor regained up to its unerring cap and shared with allies, and that card summons
## stand outside the item / manifest 3-summon cap.
## Run: godot --headless --path . --script tests/test_summon_cards.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _settle(n := 6) -> void:
	for _i in range(n):
		await process_frame

func _summons_of(main, kind: String) -> Array:
	return main._skeletons.filter(func(s): return is_instance_valid(s) and not s.is_dead and s.kind == kind)

func _run() -> void:
	print("=== Summon cards ===")
	var K := Card.CardKeyword
	# --- The sheet rows ---
	var rows := {
		"summon_skeleton": [true, [K.WAND, K.STAFF, K.GEM], Card.Rarity.COMMON, 3, 3],
		"summon_battle_turtle": [false, [K.BUCKLER, K.GEM, K.STAFF, K.WAND], Card.Rarity.RARE, 3, 1],
		"skeleton_army": [true, [K.STAFF, K.GEM, K.CROWN], Card.Rarity.LEGENDARY, 7, 5],
		"turtle_power": [false, [K.STAFF, K.GEM, K.CROWN], Card.Rarity.LEGENDARY, 6, 3],
		"summon_shadow_hound": [true, [K.WAND, K.GEM, K.STAFF, K.DAGGER, K.SWORD], Card.Rarity.RARE, 3, 1],
	}
	var mana := {"summon_battle_turtle": 65, "skeleton_army": 130, "turtle_power": 160, "summon_shadow_hound": 20}
	for cid in rows:
		var c := Card.create_by_id(cid)
		var r: Array = rows[cid]
		_check(c != null and c.card_id == cid, "%s exists" % cid)
		if c == null:
			continue
		_check(c.is_offensive() == r[0] and (r[0] or c.card_type == Card.CardType.DEFENSE), "%s is %s" % [cid, "Offensive" if r[0] else "Defensive"])
		_check(c.school == Card.CardSchool.SPELL, "%s is a spell (Silence stops it)" % cid)
		_check(c.slot_labels == r[1], "%s slots: %s" % [cid, c.slot_label_names()])
		_check(c.get_rarity() == r[2], "%s rarity" % cid)
		_check(c.tempo_cost == r[3], "%s costs %d tempo" % [cid, r[3]])
		var reach: int = (5 + c.range_modifier) if c.is_ranged else 1
		_check(reach == r[4], "%s reaches %d (got %d)" % [cid, r[4], reach])
		if mana.has(cid):
			_check(c.mana_cost == mana[cid], "%s costs %d mana" % [cid, mana[cid]])

	# --- In the dojo ---
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	await _settle()
	if main.olorin and main.olorin.is_busy():
		main.olorin._close()
	var stats: PlayerStats = main.player.get_stats()
	var dm: DeckManager = main.deck_manager
	var gm = main.grid_manager
	var here: Vector2i = gm.world_to_grid(main.player.position)
	var aim: Vector3 = gm.grid_to_world(here + Vector2i(0, -3))

	# Summon Skeleton's mana: 45 - INT, never below 0; the excess refunded.
	stats.base_intelligence = 20
	var ss := Card.create_by_id("summon_skeleton")
	dm.hand.append(ss)
	var cost := int(dm.compute_play_cost(ss, dm.hand.find(ss))["mana"])
	_check(cost == 45 - stats.intelligence, "Summon Skeleton costs 45 - INT (%d at INT %d)" % [cost, stats.intelligence])
	stats.base_intelligence = 60
	cost = int(dm.compute_play_cost(ss, dm.hand.find(ss))["mana"])
	_check(cost == 0, "at INT %d it costs nothing" % stats.intelligence)
	dm.hand.erase(ss)
	stats.current_mana = 0
	main._summon_from_card("summon_skeleton", aim)
	_check(int(stats.current_mana) == stats.intelligence - 45, "...and refunds INT - 45 (%d) when it lands" % int(stats.current_mana))
	var skels := _summons_of(main, "card_skeleton")
	_check(skels.size() == 1, "Summon Skeleton raises one skeleton")
	if skels.size() == 1:
		var s = skels[0]
		_check(s.max_health == 10 and s.base_attack == 6 and s.attack_interval == 5 and s.move_steps == 1 and s.move_interval == 1,
			"10 HP, 1 space every tempo, 6 damage every 5 tempo")
		_check(s._figure.figure_kind == "summon_skeleton", "wearing the summon skeleton board")
		_check(gm.world_to_grid(s.position) == here + Vector2i(0, -3), "on the aimed tile")

	# Skeleton Army: 4 more, past the 3-summon cap.
	main._summon_from_card("skeleton_army", aim)
	_check(_summons_of(main, "card_skeleton").size() == 5, "Skeleton Army raises 4 more (5 standing)")
	main._spawn_summon(10, main.player.position, "skeleton")
	_check(main._skeletons.filter(func(s): return not s.from_card).size() == 1, "card summons don't use up the item / manifest cap")
	for s in main._skeletons.duplicate():
		s.die()
	await process_frame

	# Shadow Hound: 2 spaces every tempo, bites every 8 - INT/10 tempo.
	stats.base_intelligence = 30
	main._summon_from_card("summon_shadow_hound", aim)
	var hounds := _summons_of(main, "shadow_hound")
	_check(hounds.size() == 1 and hounds[0].max_health == 10 and hounds[0].move_steps == 2 and hounds[0].base_attack == 4,
		"Shadow Hound: 10 HP, 2 spaces every tempo, 4 damage")
	if hounds.size() == 1:
		_check(hounds[0].attack_interval == 8 - int(stats.intelligence / 10), "bites every 8 - INT/10 tempo (%d at INT %d)" % [hounds[0].attack_interval, stats.intelligence])
		hounds[0].die()
	await process_frame

	# Battle Turtle: 25 HP, armor capped by its unerring armor (INT/2); it
	# starts full and regains a fifth of the cap every 5 tempo, never past it;
	# whatever it actually gains, the player and the other turtles gain too.
	stats.base_intelligence = 40
	main._summon_from_card("turtle_power", aim)
	var turtles := _summons_of(main, "battle_turtle")
	_check(turtles.size() == 3, "Turtle Power raises 3 Battle Turtles")
	if turtles.size() == 3:
		var t = turtles[0]
		var cap: int = int(stats.intelligence / 2)
		_check(t.max_health == 25 and t.unerring_cap == cap and t.unerring_armor == cap and t.base_attack == 0 and t.move_steps == 1,
			"25 HP, starts with its full %d unerring armor (INT / 2), no attack, 1 space every tempo" % cap)
		var p_armor: int = stats.current_armor
		main._regain_turtle_armor(t, 5)
		_check(t.unerring_armor == cap and stats.current_armor == p_armor, "full: 5 tempo later it gains nothing, so neither do its allies")
		t.take_damage(10)
		_check(t.health == 25 and t.unerring_armor == cap - 10, "its armor soaks a hit before its health")
		turtles[1].take_damage(10)
		var other_before: int = turtles[1].unerring_armor
		main._regain_turtle_armor(t, 5)
		var y: int = int(cap / 5)
		_check(t.unerring_armor == cap - 10 + y, "after 5 tempo it regains a fifth of the cap (%d)" % y)
		_check(stats.current_armor == p_armor + y, "the player gains that armor too")
		_check(turtles[1].unerring_armor == other_before + y, "and so does each other turtle")
		main._regain_turtle_armor(t, 5)
		main._regain_turtle_armor(t, 5)
		_check(t.unerring_armor == cap, "it never climbs past its unerring armor (%d)" % t.unerring_armor)
		var before_full: int = stats.current_armor
		t.unerring_armor = cap - 1
		main._regain_turtle_armor(t, 5)
		_check(t.unerring_armor == cap and stats.current_armor == before_full + 1, "one short of full: it gains 1, and its allies gain 1")
	# The Compendium's allies section matches what the summons really are.
	var sd: Array = load("res://scripts/ui/compendium_page.gd").summon_data()
	var by_name := {}
	for d in sd:
		by_name[d["name"]] = d
	_check(by_name.has("Skeleton") and by_name.has("Shadow Hound") and by_name.has("Battle Turtle"), "the Compendium lists the three summons")
	_check(by_name.get("Skeleton", {}).get("health") == 10 and by_name.get("Skeleton", {}).get("damage") == 6, "its Skeleton: 10 HP, 6 damage")
	_check(by_name.get("Shadow Hound", {}).get("health") == 10 and by_name.get("Shadow Hound", {}).get("damage") == 4, "its Shadow Hound: 10 HP, 4 damage")
	_check(by_name.get("Battle Turtle", {}).get("health") == 25 and by_name.get("Battle Turtle", {}).get("damage") == 0, "its Battle Turtle: 25 HP, no attack")
	for d in sd:
		_check(SpriteEnemyFigure.supports(str(d["figure_kind"])), "%s has its picture" % d["name"])
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
