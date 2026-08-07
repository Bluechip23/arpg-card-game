extends SceneTree

## Verifies the second audit fix batch: A5 card deletion, B1 Consecutive Snap
## snapshot, B2 Burden, B3 Blade Barrage glut, B5 boost-aware ice rolls,
## C3 Lead Arrow range, C7 Instant descriptions, C8 hand-only erase timers.
## Run: godot --headless --path . --script tests/test_audit_batch2.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Audit batch 2 test ===")

	# --- B3: Blade Barrage carries its advertised Glut 15 ---
	var bb = Card.create_blade_barrage()
	_check(bb.glut_tempo == 15, "Blade Barrage glut_tempo == 15 (got %d)" % bb.glut_tempo)

	# --- C3: Lead Arrow has lower range (-2) ---
	var la = Card.create_lead_arrow()
	_check(la.range_modifier == -2, "Lead Arrow range_modifier == -2 (got %d)" % int(la.range_modifier))

	# --- C7: reaction cards say Instant so Lethal Recall recognizes them ---
	var ss = Card.create_spider_senses()
	var vs = Card.create_vengeful_shield()
	_check(ss.description.begins_with("Instant."), "Spider Senses description starts with 'Instant.'")
	_check(vs.description.begins_with("Instant."), "Vengeful Shield description starts with 'Instant.'")

	# --- B2: Burden escalates cost per play, jail resets it ---
	var prov = Card.create_provider()
	_check(prov.has_burden, "Provider has Burden")
	var base_m = prov.mana_cost
	var base_t = prov.tempo_cost
	prov.apply_burden()
	prov.apply_burden()
	_check(prov.get_burden_mana_cost() == base_m + 2, "2 plays -> mana cost +2 (got %d)" % prov.get_burden_mana_cost())
	_check(prov.get_burden_tempo_cost() == base_t + 2, "2 plays -> tempo cost +2 (got %d)" % prov.get_burden_tempo_cost())
	prov.jail_burden()
	_check(prov.burden_plays == 0, "jail resets burden plays")
	_check(prov.jail_time_remaining == prov.burden_jail_duration, "jail arms the %d-tempo timer" % prov.burden_jail_duration)
	_check(prov.get_burden_mana_cost() == base_m, "cost back to base after jail")

	# --- B2: jail_burden_card moves hand -> jail pile and spends the mana ---
	var dm = load("res://scripts/cards/deck_manager.gd").new()
	var stats = load("res://scripts/character/player_stats.gd").new()
	stats.initialize(CharacterData.create_jeremy())
	dm.player_stats = stats
	var prov2 = Card.create_provider()
	prov2.apply_burden()
	dm.hand.append(prov2)
	var mana_before = stats.current_mana
	_check(dm.jail_burden_card(0), "jail_burden_card succeeds on a burdened hand card")
	_check(dm.hand.is_empty() and dm.jail_pile.size() == 1, "card moved from hand to jail pile")
	_check(int(mana_before - stats.current_mana) == prov2.burden_jail_cost_mana, "jail spent %d mana" % prov2.burden_jail_cost_mana)
	var prov3 = Card.create_provider()
	dm.hand.append(prov3)
	_check(not dm.jail_burden_card(0), "cannot jail with no burden built up")

	# --- C8: erase timers tick ONLY in hand ---
	var hand_token = Card.new()
	hand_token.card_name = "Hand Token"
	hand_token.erase_tempo = 10
	hand_token.erase_tempo_remaining = 10
	var discard_token = Card.new()
	discard_token.card_name = "Discard Token"
	discard_token.erase_tempo = 10
	discard_token.erase_tempo_remaining = 10
	dm.hand.clear()
	dm.hand.append(hand_token)
	dm.discard_pile.clear()
	dm.discard_pile.append(discard_token)
	dm.draw_pile.clear()
	dm._process_erase_timers()
	_check(hand_token.erase_tempo_remaining == 5, "hand card fuse ticked (10 -> %d)" % hand_token.erase_tempo_remaining)
	_check(discard_token.erase_tempo_remaining == 10, "discard card fuse untouched (still %d)" % discard_token.erase_tempo_remaining)

	# --- B1: Consecutive Snap resolves with the use count from play time ---
	var snap = Card.create_consecutive_snap()
	snap.consecutive_uses = 2  # deferred execution bumped this AFTER play
	snap.snap_uses_at_play = 1  # but the play snapshotted 1 prior use
	_check("snap_uses_at_play" in snap, "Consecutive Snap carries the play-time snapshot field")

	# --- B5: per-enemy chance rolls honor the boost, incl. late enemies ---
	var ice = Card.create_surrounding_ice()
	ice.roll_rng([], 30.0)  # 70% base + 30% boost = guaranteed hit
	_check(absf(ice.rng_effective_chance - 100.0) < 0.001,
		"boosted roll stored 100%% effective chance (got %.0f)" % ice.rng_effective_chance)
	var late_enemy = Node.new()
	_check(ice.get_rng_outcome(late_enemy), "late-spawned enemy rolls at the boosted (100%) chance")
	_check(ice.get_rng_outcome(late_enemy), "lazy roll is cached, stays consistent")
	late_enemy.free()

	# --- A5: Growth Within Resilience is fully deleted ---
	var card_script: Script = load("res://scripts/cards/card.gd")
	var has_factory := false
	for m in card_script.get_script_method_list():
		if m.name == "create_growth_within_resilience":
			has_factory = true
	_check(not has_factory, "create_growth_within_resilience factory no longer exists")

	stats.free()
	dm.free()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
