extends SceneTree

## Verifies the buff/debuff charge-and-stack rework:
## Buffs — Blessed burns a charge per cycle; Smith decays like Regen; Haste is
## charge-based; Poisoned Blood burns a charge per converted heal; Elixir burns
## a stack per healed poison tick; Phoenix Grace is charge-based.
## Debuffs — Bleed 1 dmg/tile consuming stacks; Slowed/Weighted/Staggered/
## Clumsy burn stacks by use; Tethered fixed 5-tile leash; Linked fixed 20%
## without hit consumption; Blind defaults to 80%.
## Run: godot --headless --path . --script tests/test_status_rework.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Status effect rework test ===")

	var stats = load("res://scripts/character/player_stats.gd").new()
	stats.initialize(CharacterData.create_ryan())
	var bm = BuffManager.new()
	bm.initialize(stats)
	var dm = DebuffManager.new()
	dm.initialize(stats)
	bm.connect_debuff_manager(dm)

	# --- Blessed: draws per cycle, one charge per cycle ---
	bm.apply_buff(Buff.create_blessed(1, 2, "Test"))
	var r1 = bm.process_turn_start()
	_check(r1["extra_draws"] == 1, "Blessed grants an extra draw")
	var r2 = bm.process_turn_start()
	_check(r2["extra_draws"] == 1, "Blessed's second cycle still draws")
	var r3 = bm.process_turn_start()
	_check(r3["extra_draws"] == 0 and not bm.has_buff(Buff.BuffType.BLESSED),
		"Blessed gone after its 2 charges")

	# --- Smith: decays 1 per cycle like Regen ---
	bm.apply_buff(Buff.create_smith(2, 15, "Test"))
	bm.process_turn_end()
	var smith = bm.get_buff(Buff.BuffType.SMITH)
	_check(smith != null and smith.value == 1, "Smith decayed from 2 to 1")
	bm.process_turn_end()
	_check(not bm.has_buff(Buff.BuffType.SMITH), "Smith expired at 0")

	# --- Haste: charge per move ---
	bm.apply_buff(Buff.create_haste(1, 2, "Test"))
	_check(bm.get_haste_bonus() == 1, "Haste grants +1 movement")
	bm.consume_haste()
	bm.consume_haste()
	_check(not bm.has_buff(Buff.BuffType.HASTE), "Haste gone after 2 moves")

	# --- Poisoned Blood: charge per converted heal ---
	bm.apply_buff(Buff.create_poisoned_blood(2, "Test"))
	_check(bm.has_poisoned_blood(), "Poisoned Blood active")
	bm.consume_poisoned_blood()
	bm.consume_poisoned_blood()
	_check(not bm.has_poisoned_blood(), "Poisoned Blood gone after 2 heals")

	# --- Elixir: poison tick heals and burns a stack ---
	stats.elixir_stacks = 1
	stats.current_health = 5
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.POISON, 2, 15))
	dm.process_turn_start()
	_check(stats.current_health > 5, "Elixir healed the poison tick (heal bonuses may scale it)")
	_check(stats.elixir_stacks == 0, "Elixir stack burned")
	var hp_after_heal = stats.current_health
	dm.process_turn_start()
	_check(stats.current_health < hp_after_heal, "Poison hurts again once Elixir is spent")
	dm.clear_all_debuffs()

	# --- Bleed: 1 damage per tile, stacks fall with damage ---
	stats.current_health = stats.max_health
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.BLEED, 3, 15))
	var hp0 = stats.current_health
	var dealt = dm.on_movement(2)
	_check(dealt == 2 and stats.current_health == hp0 - 2, "Bleed dealt 1 per tile (2 tiles)")
	_check(dm.get_debuff(Debuff.DebuffType.BLEED).value == 1, "Bleed dropped to 1 stack")
	dealt = dm.on_movement(5)
	_check(dealt == 1 and not dm.has_debuff(Debuff.DebuffType.BLEED),
		"Bleed capped at remaining stacks and expired")

	# --- Slowed: stack per tile, never expires by clock ---
	dm.apply_debuff(Debuff.create_slowed(2, "Test"))
	_check(dm.is_slowed(), "Slowed active")
	dm.advance_time(50)
	_check(dm.is_slowed(), "Slowed survives the clock")
	dm.consume_slowed_stack()
	dm.consume_slowed_stack()
	_check(not dm.is_slowed(), "Slowed gone after 2 tiles")

	# --- Staggered / Weighted / Clumsy: fixed magnitudes, burn on plays ---
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.STAGGERED, 1, -1))
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.WEIGHTED, 2, -1))
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.CLUMSY, 1, -1))
	_check(dm.get_attack_mana_increase() == Debuff.STAGGERED_MANA, "Staggered charges +15 mana")
	_check(dm.get_tempo_increase() == Debuff.WEIGHTED_TEMPO, "Weighted charges +2 tempo")
	_check(dm.get_clumsy_chance() == Debuff.CLUMSY_CHANCE, "Clumsy rolls at 30%")
	dm.on_card_played(true)   # attack card: burns all three
	_check(not dm.has_debuff(Debuff.DebuffType.STAGGERED), "Staggered burned by the attack card")
	_check(not dm.has_debuff(Debuff.DebuffType.CLUMSY), "Clumsy burned by the card")
	_check(dm.has_debuff(Debuff.DebuffType.WEIGHTED), "Weighted has a stack left")
	dm.on_card_played(false)  # non-attack card
	_check(not dm.has_debuff(Debuff.DebuffType.WEIGHTED), "Weighted burned by the second card")

	# --- Tethered: fixed 5-tile leash ---
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.TETHERED, 0, 15))
	dm.set_tether_origin(Vector3.ZERO)
	_check(dm.get_tether_range() == Debuff.TETHER_RANGE, "Tether range is the fixed 5")
	_check(dm.is_within_tether_range(Vector3(4, 0, 0)), "4 tiles: inside the leash")
	_check(not dm.is_within_tether_range(Vector3(7, 0, 0)), "7 tiles: outside the leash")
	dm.clear_all_debuffs()

	# --- Linked: fixed 20%, no per-hit consumption ---
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.LINKED, 0, 15))
	_check(dm.calculate_linked_damage(10) == 2, "Linked shares 20% (2 of 10)")
	_check(dm.calculate_linked_damage(10) == 2, "Linked share unchanged by the hit")
	_check(dm.has_debuff(Debuff.DebuffType.LINKED), "Linked persists (tempo-driven)")
	dm.clear_all_debuffs()

	# --- Per-tempo ticking: a 3-tempo stun works at any granularity ---
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.STUN, 0, 3))
	dm.advance_time(2)
	_check(dm.has_debuff(Debuff.DebuffType.STUN), "Stun(3) survives 2 tempo")
	dm.advance_time(1)
	_check(not dm.has_debuff(Debuff.DebuffType.STUN), "Stun(3) expires on the 3rd tempo exactly")
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.FROZEN, 0, 7))
	dm.advance_time(7)
	_check(not dm.has_debuff(Debuff.DebuffType.FROZEN), "Frozen(7) handles a non-multiple-of-5 duration")

	# Buffs tick per tempo too (Fortify 4 outlasts 3 tempo, dies on the 4th).
	bm.apply_buff(Buff.create_fortify(4, "Test"))
	bm.advance_time(3)
	_check(bm.has_buff(Buff.BuffType.FORTIFY), "Fortify(4) survives 3 tempo")
	bm.advance_time(1)
	_check(not bm.has_buff(Buff.BuffType.FORTIFY), "Fortify(4) expires on the 4th tempo")

	# --- Blind default is 80% ---
	var blind = Debuff.create(Debuff.DebuffType.BLIND, 0, 10)
	_check("80%" in blind.description, "Blind description defaults to 80%")
	_check(absf(stats.blind_miss_chance - 0.8) < 0.001, "player blind miss chance is 80%")

	stats.free()
	bm.free()
	dm.free()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
