extends SceneTree

## Enemy debuffs land on summons too (designer, 2026-10-28), and do to them
## what they do to a hero: Stun / Root / Frozen hold them in place, Stun /
## Disarm / Frozen stop their attacks, Slowed makes moves cost more, Poison /
## Burn tick each cycle, Bleed hurts per tile walked, Vulnerable sharpens hits
## on them, Weakened / Cursed blunt their blows, Blind makes them miss. The
## card-only debuffs (Hexed, Locked, Drain...) never land on a summon. The
## Allies tab shows them as badges.
## Run: godot --headless --path . --script tests/test_summon_debuffs.gd

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

func _fresh(main, cell: Vector2i):
	for s in main._skeletons.duplicate():
		s.die()
	main._summon_from_card("summon_skeleton", main.grid_manager.grid_to_world(cell))
	return main._skeletons.back()

func _run() -> void:
	print("=== Enemy debuffs on summons ===")
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_jeremy())
	main.set("sandbox_mode", true)
	get_root().add_child(main)
	await _settle()
	if main.olorin and main.olorin.is_busy():
		main.olorin._close()
	for e in main.enemy_spawner.get_living_enemies():
		e.queue_free()
	await process_frame
	var gm = main.grid_manager
	var p = main.player
	var at: Vector2i = gm.world_to_grid(p.position) + Vector2i(-3, -3)
	p.heading = Vector2i(1, 0)
	var D := Debuff.DebuffType

	# An enemy's debuff reaches a summon through the same call that hits heroes.
	var rat: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.WERERAT, gm.grid_to_world(at + Vector2i(0, 8)))
	await process_frame
	var sk = _fresh(main, at)
	at = sk.get_destination_cell()
	rat._apply_player_debuff(sk, Debuff.create(D.STUN, 0, 5))
	_check(sk.get_debuff_manager().has_debuff(D.STUN), "an enemy's Stun lands on a summon")
	main._update_skeletons(3)
	_check(sk.get_destination_cell() == at, "stunned, it doesn't march")
	main._on_tempo_advanced(0, 5)
	_check(not sk.debuff_manager.has_debuff(D.STUN), "the Stun wears off on the tempo clock")
	var after_stun: Vector2i = sk.get_destination_cell()
	main._update_skeletons(1)
	_check(sk.get_destination_cell() == after_stun + Vector2i(1, 0), "and it marches again")

	# Card-only debuffs never land.
	rat._apply_player_debuff(sk, Debuff.create(D.HEXED, 30, 25))
	rat._apply_player_debuff(sk, Debuff.create(D.DRAIN, 2, 15))
	_check(not sk.debuff_manager.has_debuff(D.HEXED) and not sk.debuff_manager.has_debuff(D.DRAIN), "Hexed and Drain (card / mana debuffs) don't land on a summon")

	# Rooted: no moving.
	sk = _fresh(main, at)
	var c0: Vector2i = sk.get_destination_cell()
	sk.get_debuff_manager().apply_debuff(Debuff.create(D.ROOTED, 0, 5))
	main._update_skeletons(2)
	_check(sk.get_destination_cell() == c0, "Rooted: it stays put")

	# Slowed: a move costs 3 tempo.
	sk = _fresh(main, at)
	c0 = sk.get_destination_cell()
	sk.get_debuff_manager().apply_debuff(Debuff.create(D.SLOWED, 0, 10))
	main._update_skeletons(2)
	_check(sk.get_destination_cell() == c0, "Slowed: no step after 2 tempo")
	main._update_skeletons(1)
	_check(sk.get_destination_cell() == c0 + Vector2i(1, 0), "a step after 3")

	# Poison ticks on the cycle; Bleed per tile walked.
	sk = _fresh(main, at)
	sk.get_debuff_manager().apply_debuff(Debuff.create(D.POISON, 3, 15))
	main._cycle_summon_debuffs()
	_check(sk.health == 7, "Poison 3: 3 damage at the cycle (%d HP)" % sk.health)
	_check(sk.debuff_manager.get_debuff(D.POISON).value == 2, "and it drops to 2")
	sk.get_debuff_manager().apply_debuff(Debuff.create(D.BLEED, 5, -1))
	var hp_b: int = sk.health
	main._update_skeletons(2)
	_check(sk.health == hp_b - 2, "Bleed: 2 tiles walked, 2 damage (%d -> %d)" % [hp_b, sk.health])

	# Vulnerable sharpens hits on it; the DOT is not sharpened.
	sk = _fresh(main, at)
	sk.get_debuff_manager().apply_debuff(Debuff.create(D.VULNERABLE, 1, 15))
	sk.take_damage(5)
	_check(sk.health == 10 - 6, "Vulnerable: a 5 hit lands for 6 (%d HP)" % sk.health)

	# Weakened blunts its blows; Disarm stops them; Blind makes them miss.
	sk = _fresh(main, at)
	sk.get_debuff_manager().apply_debuff(Debuff.create(D.WEAKENED, 1, -1))
	_check(sk.outgoing_damage(10) == 7, "Weakened: its 10 lands as 7")
	sk = _fresh(main, at)
	rat.position = gm.grid_to_world(sk.get_destination_cell() + Vector2i(0, 1))
	await process_frame
	var rhp: int = rat.current_health
	sk.get_debuff_manager().apply_debuff(Debuff.create(D.DISARM, 0, 20))
	main._update_skeletons(5)
	_check(rat.current_health == rhp, "Disarmed: beside an enemy, it doesn't hit")
	sk.debuff_manager.clear_all_debuffs()
	sk.get_debuff_manager().apply_debuff(Debuff.create(D.BLIND, 3))
	var misses := 0
	for _i in range(60):
		if sk.outgoing_damage(6) == 0:
			misses += 1
	_check(misses > 30, "Blind: most of its blows miss (%d of 60)" % misses)

	# The Allies tab shows its debuffs.
	sk.get_debuff_manager().apply_debuff(Debuff.create(D.POISON, 2, 15))
	var names: Array = sk.get_status_effects().map(func(e): return e["name"])
	_check(names.any(func(n): return str(n).contains("Poison")) and names.any(func(n): return str(n).contains("Blind")), "its badges list its debuffs (%s)" % [names])
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
