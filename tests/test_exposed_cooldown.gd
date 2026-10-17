extends SceneTree

## Exposed has a 10-tempo cooldown before it can trigger again (designer's
## rule). Each unit — every enemy, every player — keeps its own clock: a break
## inside the window is just armor lost (no flag, no "exposed" signal, no
## Cobra stun, no on_exposed reactions, no Reverberate Regrowth); once the
## window has run, the next break Exposes as before.
## Boots the dojo so the enemies and the player run through the real Main.
## Run: godot --headless --path . --script tests/test_exposed_cooldown.gd

var failures := 0
var main = null

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Exposed cooldown ===")
	_run()

func _run() -> void:
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	main = packed.instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(6):
		await process_frame

	_test_enemy()
	_test_cobra()
	_test_earth_mage()
	_test_independent_enemies()
	_test_player()
	_test_texts()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

# ---------------------------------------------------------------------------

func _spawn(type: Enemy.EnemyType, offset: Vector2i) -> Enemy:
	var gm = main.grid_manager
	var cell: Vector2i = gm.world_to_grid(main.player.position) + offset
	var e: Enemy = main.enemy_spawner.spawn_enemy(type, gm.grid_to_world(cell))
	e.max_health = 10000
	e.current_health = 10000
	e.current_armor = 0
	return e

func _drop(e: Enemy) -> void:
	main.enemy_spawner.despawn_enemy(e)

## Counts every `exposed` emission from an enemy (Main's Easy Target hangs off
## the same signal).
func _count_exposed(e: Enemy) -> Array:
	var n := [0]
	e.exposed.connect(func(_en): n[0] += 1)
	return n

func _test_enemy() -> void:
	print("--- An enemy exposes once per 10 tempo ---")
	var e := _spawn(Enemy.EnemyType.DUMMY, Vector2i(6, 0))
	var n := _count_exposed(e)
	e.current_armor = 10
	var first: bool = e.take_damage(20, true)
	_check(first and e.is_exposed and n[0] == 1, "breaking the armor exposes it and fires its listeners")
	_check(e.exposed_cooldown_tempo == 10, "…and starts a 10-tempo cooldown (%d)" % e.exposed_cooldown_tempo)
	e._gain_armor(10)
	_check(not e.is_exposed, "armor back on ends Exposed")
	e._tick_timed_statuses(5)
	var second: bool = e.take_damage(20, true)
	_check(not second and not e.is_exposed and e.current_armor == 0,
		"a break 5 tempo later loses the armor but is not an Exposed")
	_check(n[0] == 1, "…and fires no listeners (%d emissions)" % n[0])
	var tip: Dictionary = e.get_effect_tooltip("Exposed")
	_check(str(tip["desc"]).contains("10 tempo"), "the Exposed tooltip names the cooldown")
	# Armor Break (double to armor) takes the same gate.
	e._gain_armor(10)
	e.armor_break_incoming = true
	var ab: bool = e.take_damage(10, true)
	e.armor_break_incoming = false
	_check(not ab and not e.is_exposed and n[0] == 1, "an Armor Break inside the cooldown does not Expose either")
	# Only 9 tempo in: one short.
	e._tick_timed_statuses(4)
	_check(e.exposed_cooldown_tempo == 1, "the cooldown counts down on raw tempo (%d left)" % e.exposed_cooldown_tempo)
	e._tick_timed_statuses(1)
	_check(e.exposed_cooldown_tempo == 0, "…and runs out on its own after 10 tempo")
	e._gain_armor(10)
	var third: bool = e.take_damage(20, true)
	_check(third and e.is_exposed and n[0] == 2, "after 10 tempo the next break exposes again")
	_drop(e)

func _test_cobra() -> void:
	print("--- The Sewer Cobra is stunned only by a real Exposed ---")
	var c := _spawn(Enemy.EnemyType.SEWER_CROC, Vector2i(6, 1))
	var n := _count_exposed(c)
	c.current_armor = 10
	c.take_damage(20, true)
	_check(n[0] == 1 and c.stun_tempo == Enemy.COBRA_EXPOSED_STUN, "the first break exposes and stuns it (%d)" % c.stun_tempo)
	c._tick_timed_statuses(Enemy.COBRA_EXPOSED_STUN)
	_check(c.stun_tempo == 0, "the stun wears off")
	c._gain_armor(10)
	c.take_damage(20, true)
	_check(n[0] == 1 and c.stun_tempo == 0 and not c.is_exposed, "a break inside the cooldown: no Exposed, no stun")
	c._tick_timed_statuses(10 - Enemy.COBRA_EXPOSED_STUN)
	c._gain_armor(10)
	c.take_damage(20, true)
	_check(n[0] == 2 and c.stun_tempo == Enemy.COBRA_EXPOSED_STUN, "after 10 tempo the break stuns it again")
	_drop(c)

func _test_earth_mage() -> void:
	print("--- The Earth Mage (re-arms 4 a hit) exposes at most once per 10 tempo ---")
	var m := _spawn(Enemy.EnemyType.EARTH_MAGE, Vector2i(6, 2))
	var n := _count_exposed(m)
	m.current_armor = 5
	for _i in range(5):
		m.take_damage(10, true)
		m._tick_timed_statuses(1)
	_check(n[0] == 1, "five breaking hits over 5 tempo: one Exposed (%d)" % n[0])
	m._tick_timed_statuses(4)
	m.take_damage(10, true)
	_check(n[0] == 1, "still none at 9 tempo (%d)" % n[0])
	m._tick_timed_statuses(1)
	m.take_damage(10, true)
	_check(n[0] == 2, "the first break at 10 tempo exposes again (%d)" % n[0])
	_drop(m)

func _test_independent_enemies() -> void:
	print("--- Every enemy keeps its own cooldown ---")
	var a := _spawn(Enemy.EnemyType.DUMMY, Vector2i(6, 3))
	var b := _spawn(Enemy.EnemyType.DUMMY, Vector2i(6, 4))
	var na := _count_exposed(a)
	var nb := _count_exposed(b)
	a.current_armor = 10
	a.take_damage(20, true)
	_check(na[0] == 1 and a.exposed_cooldown_tempo == 10, "A is exposed and cooling")
	_check(b.exposed_cooldown_tempo == 0, "B's cooldown is untouched")
	b.current_armor = 10
	b.take_damage(20, true)
	_check(nb[0] == 1 and b.is_exposed, "B still exposes while A is cooling")
	_drop(a)
	_drop(b)

func _test_player() -> void:
	print("--- The player: on-expose effects once per 10 tempo ---")
	var stats: PlayerStats = main.player.get_stats()
	var dm = main.deck_manager
	stats.max_health = 10000
	stats.current_health = 10000
	stats.exposed_cooldown_tempo = 0
	var broke := [0]
	stats.armor_broken.connect(func(): broke[0] += 1)
	# Reverberate Regrowth (maintained) and a Vengeful Shield (on_exposed
	# reaction) — both should fire on a real Exposed only.
	var rr: Card = Card.create_by_id("reverberate_regrowth")
	dm.maintained_cards.append(rr)
	var vs: Card = Card.create_by_id("vengeful_shield")
	dm.hand.append(vs)

	stats.current_armor = 10
	stats.take_damage(30)
	_check(broke[0] == 1, "an armor break Exposes the player")
	_check(not dm.hand.has(vs), "…the on_exposed reaction fires")
	_check(stats.pending_armor_return == 10, "…and Reverberate Regrowth banks the 10 armor (%d)" % stats.pending_armor_return)
	_check(stats.exposed_cooldown_tempo == 10, "…and a 10-tempo cooldown starts")

	stats.pending_armor_return = 0
	stats.pending_armor_return_tempo = 0
	var vs2: Card = Card.create_by_id("vengeful_shield")
	dm.hand.append(vs2)
	stats.current_armor = 10
	stats.process_tempo(5)
	stats.take_damage(30)
	_check(broke[0] == 1, "a second break 5 tempo later is not an Exposed")
	_check(dm.hand.has(vs2), "…the reaction stays in hand")
	_check(stats.pending_armor_return == 0, "…and Reverberate Regrowth banks nothing")
	_check(stats.current_armor == 0, "…though the armor is still gone")

	stats.process_tempo(5)
	_check(stats.exposed_cooldown_tempo == 0, "the cooldown runs out after 10 tempo")
	stats.current_armor = 10
	stats.take_damage(30)
	_check(broke[0] == 2 and not dm.hand.has(vs2), "the next break Exposes again and the reaction fires")
	_check(stats.pending_armor_return == 10, "…and Reverberate Regrowth banks again")

	# Health lost with no armor up is not an Exposed.
	stats.exposed_cooldown_tempo = 0
	var vs3: Card = Card.create_by_id("vengeful_shield")
	dm.hand.append(vs3)
	stats.current_armor = 0
	stats.take_damage(10)
	_check(broke[0] == 2 and dm.hand.has(vs3), "an armorless hit does not Expose")
	dm.hand.erase(vs3)
	dm.maintained_cards.erase(rr)
	stats.pending_armor_return = 0

	# Each player keeps their own clock.
	var other := PlayerStats.new()
	get_root().add_child(other)
	other.initialize(CharacterData.create_ryan())
	other.max_health = 200
	other.current_health = 200
	stats.exposed_cooldown_tempo = 10
	var other_broke := [0]
	other.armor_broken.connect(func(): other_broke[0] += 1)
	other.current_armor = 10
	other.take_damage(30)
	_check(other_broke[0] == 1, "a second player Exposes while the first is cooling")
	_check(stats.exposed_cooldown_tempo == 10, "…without touching the first player's clock")
	other.queue_free()
	stats.exposed_cooldown_tempo = 0

func _test_texts() -> void:
	print("--- The keyword says so ---")
	_check(str(Card.get_keyword_definitions().get("exposed", "")).contains("10 tempo"),
		"card keyword text names the cooldown")
