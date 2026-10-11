extends SceneTree

## The sheet's player-side debuff rework:
##  - "a stack is 5 tempo": Vulnerable / Blind / Slowed / Weakened / Staggered /
##    Clumsy / Brittle keep their own clock, shed one stack per 5 tempo of it,
##    add stacks on re-application, and are never burned by hits, attacks,
##    tiles or card plays;
##  - clock-timed Slowed / Staggered (Approach, Tower Shield) still run on the
##    card's timer;
##  - Disarm / Rooted / Silence timers ADD on re-application, and Disarm
##    blocks the basic attack button;
##  - Locked holds several cards, one per instance, shifting with the hand.
## Run: godot --headless --path . --script tests/test_debuff_stack_clocks.gd

var failures := 0
var main = null

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _mk() -> Array:
	var stats = load("res://scripts/character/player_stats.gd").new()
	stats.initialize(CharacterData.create_ryan())
	var dm = DebuffManager.new()
	dm.initialize(stats)
	return [stats, dm]

func _initialize() -> void:
	print("=== Debuff stack clocks ===")
	_run()

func _run() -> void:
	_test_own_clock()
	_test_additive_stacks()
	_test_no_burn_on_use()
	_test_clock_timed_unchanged()
	_test_additive_timers()
	_test_cold_default()
	_test_locked_multi()
	await _test_in_scene()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

## A stack applied at tempo 3 is gone at tempo 8 — on the debuff's own clock,
## not at the next global cycle boundary (5, 10, 15...).
func _test_own_clock() -> void:
	print("-- Own clock exactness --")
	var pair := _mk()
	var stats = pair[0]
	var dm: DebuffManager = pair[1]
	var tm := TempoManager.new()
	get_root().add_child(tm)
	tm.initialize(stats)
	tm.debuff_manager = dm
	# main.gd routes every raw tempo advance into advance_time; mirror that.
	tm.tempo_advanced.connect(func(_total: int, amount: int): dm.advance_time(amount))

	tm.add_tempo(3)
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.VULNERABLE, 1))
	var vuln = dm.get_debuff(Debuff.DebuffType.VULNERABLE)
	_check(vuln != null and vuln.duration == -1 and vuln.stack_clock == 0,
		"Vulnerable applied at tempo 3 starts its own clock at 0 (shared timer off)")
	tm.add_tempo(2)  # global 5: the cycle boundary — nothing happens to it
	_check(dm.has_debuff(Debuff.DebuffType.VULNERABLE), "the cycle boundary at tempo 5 does not touch it")
	tm.add_tempo(2)  # global 7
	_check(dm.has_debuff(Debuff.DebuffType.VULNERABLE), "still there at tempo 7")
	tm.add_tempo(1)  # global 8
	_check(not dm.has_debuff(Debuff.DebuffType.VULNERABLE), "gone at tempo 8 exactly (3 + 5)")

	# A big tempo jump sheds as many stacks as it covers, and keeps the rest.
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.BLIND, 3))
	dm.advance_time(12)
	var blind = dm.get_debuff(Debuff.DebuffType.BLIND)
	_check(blind != null and blind.value == 1 and blind.stack_clock == 2,
		"Blind(3) after 12 tempo: 1 stack left, 2 tempo into the next (got %s)" % (str(blind.value) if blind else "gone"))
	dm.advance_time(3)
	_check(not dm.has_debuff(Debuff.DebuffType.BLIND), "and the last stack falls at 15")

	# Every stack-clocked type runs on the same rule.
	for t in [Debuff.DebuffType.SLOWED, Debuff.DebuffType.WEAKENED, Debuff.DebuffType.STAGGERED,
			Debuff.DebuffType.CLUMSY, Debuff.DebuffType.BRITTLE]:
		dm.apply_debuff(Debuff.create(t, 1, 15))
		var d = dm.get_debuff(t)
		_check(d != null and d.duration == -1, "%s: the manager forces duration -1 whatever the caller passed" % d.debuff_name)
		dm.advance_time(4)
		_check(dm.has_debuff(t), "%s(1) survives 4 tempo" % d.debuff_name)
		dm.advance_time(1)
		_check(not dm.has_debuff(t), "%s(1) gone on the 5th" % d.debuff_name)

	# Natural expiry fires debuff_expired (Marvolo's Misunderstanding listens).
	var expired_names: Array = []
	dm.debuff_expired.connect(func(d: Debuff): expired_names.append(d.debuff_name))
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.BRITTLE, 1))
	dm.advance_time(5)
	_check(expired_names == ["Brittle"], "a stack-clock expiry is a natural expiry")

	tm.free()
	dm.free()
	stats.free()

## Re-applying ADDS stacks; the running clock is not reset.
func _test_additive_stacks() -> void:
	print("-- Additive stacks, clock keeps running --")
	var pair := _mk()
	var dm: DebuffManager = pair[1]
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.WEAKENED, 2))
	dm.advance_time(3)
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.WEAKENED, 2))
	var weak = dm.get_debuff(Debuff.DebuffType.WEAKENED)
	_check(weak.value == 4 and weak.stack_clock == 3, "Weakened 2 + 2 = 4 stacks, clock still at 3")
	_check("4 stack(s)" in weak.description and "5 tempo each" in weak.description,
		"description names the stacks and the 5-tempo rule (%s)" % weak.description)
	dm.advance_time(2)
	_check(weak.value == 3, "the next stack still falls when it was going to (tempo 5 of the clock)")
	dm.advance_time(15)
	_check(not dm.has_debuff(Debuff.DebuffType.WEAKENED), "4 stacks = 20 tempo in all")
	dm.free()
	pair[0].free()

## Hits, attacks, tiles and card plays burn nothing any more — only Weighted.
func _test_no_burn_on_use() -> void:
	print("-- No burn on use --")
	var pair := _mk()
	var stats = pair[0]
	var dm: DebuffManager = pair[1]

	# Vulnerable: +30% on every hit, no decrement.
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.VULNERABLE, 1))
	_check(dm.modify_incoming_damage(10) == 13, "Vulnerable adds 30%")
	_check(dm.modify_incoming_damage(10) == 13, "...and again on the second hit")
	_check(dm.get_debuff(Debuff.DebuffType.VULNERABLE).value == 1, "hits do not burn Vulnerable")

	# Weakened: -30% dealt, on_attack burns nothing.
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.WEAKENED, 1))
	_check(absf(dm.get_damage_reduction_percent() - 0.3) < 0.001, "Weakened reduces dealt damage 30%")
	dm.on_attack()
	dm.on_attack()
	_check(dm.get_debuff(Debuff.DebuffType.WEAKENED).value == 1, "attacks do not burn Weakened")

	# Slowed: 3 tempo per tile, moving burns nothing.
	var tm := TempoManager.new()
	get_root().add_child(tm)
	tm.initialize(stats)
	tm.debuff_manager = dm
	dm.apply_debuff(Debuff.create_slowed(1, "Test"))
	var before: int = tm.global_tempo
	tm.add_movement_tempo()
	_check(tm.global_tempo == before + Debuff.SLOWED_TEMPO_PER_TILE, "a slowed tile costs %d tempo" % Debuff.SLOWED_TEMPO_PER_TILE)
	_check(dm.has_debuff(Debuff.DebuffType.SLOWED) and dm.get_debuff(Debuff.DebuffType.SLOWED).value == 1,
		"the tile does not burn the Slowed stack")
	tm.free()

	# Staggered / Clumsy: hold through card plays; Weighted still burns.
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.STAGGERED, 1))
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.CLUMSY, 1))
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.WEIGHTED, 1))
	dm.on_card_played(true)
	_check(dm.get_attack_mana_increase() == Debuff.STAGGERED_MANA, "Staggered still taxes after an attack card")
	_check(dm.get_clumsy_chance() == Debuff.CLUMSY_CHANCE, "Clumsy still rolls after a card")
	_check(not dm.has_debuff(Debuff.DebuffType.WEIGHTED), "Weighted alone burns per card")

	# Brittle: +2 decay per cycle, the cycle end burns nothing.
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.BRITTLE, 1))
	_check(dm.process_armor_decay(1) == 3, "Brittle adds 2 armor decay")
	dm.process_turn_end()
	_check(dm.get_debuff(Debuff.DebuffType.BRITTLE).value == 1, "the cycle end does not burn Brittle")

	# Blind: constant 80% while any stack remains.
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.BLIND, 1))
	_check(absf(dm.get_blind_miss_chance() - Debuff.BLIND_MISS / 100.0) < 0.001, "Blind misses at the constant 80%")

	dm.free()
	stats.free()

## Approach's Slowed and Tower Shield's Staggered keep their fixed timers.
func _test_clock_timed_unchanged() -> void:
	print("-- Clock-timed Slowed / Staggered --")
	var pair := _mk()
	var dm: DebuffManager = pair[1]
	dm.apply_debuff(Debuff.create_timed(Debuff.DebuffType.STAGGERED, 40, "Tower Shield"))
	var stag = dm.get_debuff(Debuff.DebuffType.STAGGERED)
	_check(stag.clock_timed and stag.duration == 40 and not stag.uses_stack_clock(), "Tower Shield: 40-tempo timer, no stack clock")
	dm.advance_time(20)
	_check(dm.has_debuff(Debuff.DebuffType.STAGGERED) and stag.duration == 20 and stag.value == 1,
		"20 tempo in: still there with its single stack (the clock, not the stacks, ends it)")
	dm.on_card_played(true)
	_check(dm.has_debuff(Debuff.DebuffType.STAGGERED), "attack plays do not burn it")
	dm.advance_time(20)
	_check(not dm.has_debuff(Debuff.DebuffType.STAGGERED), "the clock ends it at 40")

	# Timer over stacks: become timed for at least that long (existing rule).
	dm.apply_debuff(Debuff.create_slowed(2, "Spiked Web"))
	dm.apply_debuff(Debuff.create_timed(Debuff.DebuffType.SLOWED, 10, "Approach"))
	var slow = dm.get_debuff(Debuff.DebuffType.SLOWED)
	_check(slow.clock_timed and slow.duration == 10, "a timer over stacks takes the timer")
	dm.advance_time(10)
	_check(not dm.has_debuff(Debuff.DebuffType.SLOWED), "and the timer ends it")
	# Stacks over a timer: the timer already covers it (existing rule).
	dm.apply_debuff(Debuff.create_timed(Debuff.DebuffType.SLOWED, 10, "Approach"))
	dm.apply_debuff(Debuff.create_slowed(2, "Spiked Web"))
	slow = dm.get_debuff(Debuff.DebuffType.SLOWED)
	_check(slow.clock_timed and slow.duration == 10 and dm.debuffs.size() == 1, "stacks over a timer ride the timer")
	dm.free()
	pair[0].free()

## Disarm / Rooted / Silence: a re-application adds its tempo onto what is left.
func _test_additive_timers() -> void:
	print("-- Additive Disarm / Rooted / Silence --")
	var pair := _mk()
	var dm: DebuffManager = pair[1]
	for t in [Debuff.DebuffType.DISARM, Debuff.DebuffType.ROOTED, Debuff.DebuffType.SILENCE]:
		dm.apply_debuff(Debuff.create(t, 0, 5))
		dm.advance_time(2)
		dm.apply_debuff(Debuff.create(t, 0, 5))
		var d = dm.get_debuff(t)
		_check(d != null and d.duration == 8 and d.stacks == 2, "%s: 3 left + 5 = 8 tempo, 2 stacks" % d.debuff_name)
		_check("8 tempo left" in d.description, "%s description shows the tempo left (%s)" % [d.debuff_name, d.description])
		dm.advance_time(7)
		_check(dm.has_debuff(t), "%s holds past where the longer-of-the-two rule would end it" % d.debuff_name)
		dm.advance_time(1)
		_check(not dm.has_debuff(t), "%s ends at 8" % d.debuff_name)
	# The locks still do their jobs.
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.DISARM, 0, 5))
	_check(not dm.can_play_attack_cards() and dm.can_play_spell_cards(), "Disarm blocks attacks, not spells")
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.ROOTED, 0, 5))
	_check(not dm.can_move(), "Rooted blocks movement")
	dm.free()
	pair[0].free()

## Cold's default timer is 5 tempo; stacking keeps the longer timer, Frozen at 5.
func _test_cold_default() -> void:
	print("-- Cold --")
	var pair := _mk()
	var dm: DebuffManager = pair[1]
	var cold = Debuff.create(Debuff.DebuffType.COLD, 2)
	_check(cold.duration == Debuff.COLD_TEMPO and "5 tempo left" in cold.description, "Cold defaults to a 5-tempo timer")
	_check(Debuff.create(Debuff.DebuffType.COLD, 2, 30).duration == 30, "an explicit Cold timer stands")
	dm.apply_debuff(cold)
	dm.advance_time(2)
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.COLD, 2, 5))
	var c = dm.get_debuff(Debuff.DebuffType.COLD)
	_check(c.value == 4 and c.duration == 5, "Cold stacks add (4) and keep the longer timer (5)")
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.COLD, 1, 5))
	_check(not dm.has_debuff(Debuff.DebuffType.COLD) and dm.has_debuff(Debuff.DebuffType.FROZEN), "5 Cold becomes Frozen")
	dm.free()
	pair[0].free()

## Two Locked instances hold two different cards and follow them as the hand shifts.
func _test_locked_multi() -> void:
	print("-- Locked holds several cards --")
	var pair := _mk()
	var dm: DebuffManager = pair[1]
	var deck := DeckManager.new()
	get_root().add_child(deck)
	deck.connect_debuff_manager(dm)
	for _i in range(4):
		deck.hand.append(Card.create_slash())

	dm.apply_debuff(Debuff.create(Debuff.DebuffType.LOCKED, 0, -1))
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.LOCKED, 0, -1))
	var locks := dm.get_locked_debuffs()
	_check(locks.size() == 2, "two Locked applications are two instances")
	deck.assign_hexed_locked_cards(dm)
	var a: int = locks[0].affected_card_index
	var b: int = locks[1].affected_card_index
	_check(a != -1 and b != -1 and a != b, "each lock claims its own card (%d, %d)" % [a, b])
	_check(dm.is_card_locked(a) and dm.is_card_locked(b), "both cards read as locked")
	var locked_count := 0
	for i in range(deck.hand.size()):
		if dm.is_card_locked(i):
			locked_count += 1
	_check(locked_count == 2, "exactly two cards are locked")
	_check(dm.get_locked_card_index() == a, "get_locked_card_index still names the first instance's card")

	# Pin the locks to cards 1 and 3 of 4 so every shift path is exercised
	# whatever the random assignment chose.
	locks[0].affected_card_index = 1
	locks[1].affected_card_index = 3
	# A card BELOW both locks leaves the hand: both shift down one.
	deck.hand.remove_at(0)
	deck._update_debuff_card_indices(dm, 0)
	_check(dm.is_card_locked(0) and dm.is_card_locked(2) and not dm.is_card_locked(1) and not dm.is_card_locked(3),
		"both locks follow their cards down one (0, 2)")
	# A card BETWEEN them leaves: only the higher lock shifts.
	deck.hand.remove_at(1)
	deck._update_debuff_card_indices(dm, 1)
	_check(dm.is_card_locked(0) and dm.is_card_locked(1) and not dm.is_card_locked(2),
		"only the lock above the gap shifts (0, 1)")
	# A card ABOVE both leaves: neither moves.
	deck.hand.append(Card.create_slash())
	deck.hand.remove_at(2)
	deck._update_debuff_card_indices(dm, 2)
	_check(dm.is_card_locked(0) and dm.is_card_locked(1), "a card above both locks leaving moves neither")
	# The lower locked card itself leaves (a Clumsy discard): its lock goes with it.
	deck.hand.remove_at(0)
	dm.remove_locks_on_card(0)
	deck._update_debuff_card_indices(dm, 0)
	_check(dm.get_locked_debuffs().size() == 1 and dm.is_card_locked(0) and not dm.is_card_locked(1),
		"its lock is lifted; the other follows its card to 0")

	# Hexed and Locked prefer different cards.
	dm.clear_all_debuffs()
	deck.hand.clear()
	deck.hand.append(Card.create_slash())
	deck.hand.append(Card.create_slash())
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.HEXED, 10, -1))
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.LOCKED, 0, -1))
	deck.assign_hexed_locked_cards(dm)
	var hx: int = dm.get_hexed_debuffs()[0].affected_card_index
	_check(hx != -1 and dm.get_locked_card_index() != -1 and dm.get_locked_card_index() != hx,
		"a lock lands on a card no hex holds when it can")

	deck.free()
	dm.free()
	pair[0].free()

## In the real scene: Disarm stops the attack button arming, and a Blind
## attack card misses through the debuff manager (no PlayerStats flag set).
func _test_in_scene() -> void:
	print("-- In the scene: Disarm vs the attack button, Blind vs an attack card --")
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	main = packed.instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(6):
		await process_frame
	var stats: PlayerStats = main.player.get_stats()
	var dm = main.deck_manager
	var bm: BuffManager = main.player.get_buff_manager()
	var dbm: DebuffManager = main.player.get_debuff_manager()
	var enemies: Array = main.enemy_spawner.get_living_enemies()
	var dummy: Enemy = enemies[0] if enemies.size() > 0 else null
	dbm.clear_all_debuffs()

	_check(dm.debuff_manager == dbm, "the deck manager is wired to the player's debuff manager")

	# Disarm: the button refuses to arm; lifted, it arms.
	dbm.apply_debuff(Debuff.create(Debuff.DebuffType.DISARM, 0, 10))
	main._on_attack_pressed()
	_check(not main._basic_attack_pending, "Disarmed: the attack button does not arm")
	dbm.remove_debuff(Debuff.DebuffType.DISARM)
	main._on_attack_pressed()
	_check(main._basic_attack_pending, "undisarmed: the attack button arms")
	main._set_basic_attack_pending(false)

	# Blind: attack cards miss ~80% through the debuff manager alone.
	if dummy:
		_check(not stats.is_blinded, "nothing sets the legacy PlayerStats flag")
		dbm.apply_debuff(Debuff.create(Debuff.DebuffType.BLIND, 1))
		dummy.max_health = 100000
		dummy.current_health = 100000
		if "current_armor" in dummy:
			dummy.current_armor = 0
		var misses := 0
		var hits := 0
		for _i in range(50):
			var hp: int = dummy.current_health
			dummy.current_health = 100000
			if "current_armor" in dummy:
				dummy.current_armor = 0
			Card.create_slash().execute(dummy, stats, dm, 0.0, 0.0, bm)
			if dummy.current_health < 100000:
				hits += 1
			else:
				misses += 1
			dbm.get_debuff(Debuff.DebuffType.BLIND).stack_clock = 0  # keep it blind for the whole sample
		_check(misses >= 20 and hits >= 1, "Blind through the debuff manager: %d misses / %d hits of 50" % [misses, hits])
		dbm.remove_debuff(Debuff.DebuffType.BLIND)
		dummy.current_health = 100000
		Card.create_slash().execute(dummy, stats, dm, 0.0, 0.0, bm)
		_check(dummy.current_health < 100000, "unblinded, the attack lands")
	else:
		print("  (no dummy in the dojo — Blind sample skipped)")
	dbm.clear_all_debuffs()
