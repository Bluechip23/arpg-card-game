extends SceneTree

## Verifies the battle-HUD passive tray pieces: PassiveCooldowns reads each of
## the three runtime tracking styles (last-trigger tempo, remaining-tempo
## countdown, charge pools) correctly, cooldown-less passives report solid,
## and PassiveBoxUI reflects that state (gauntlet-style fade + lvl label).
## Run: godot --headless --path . --script tests/test_passive_display.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Passive display test ===")

	var stats := PlayerStats.new()
	var tm := TempoManager.new()
	tm.global_tempo = 20

	# --- No-cooldown passive: always solid ---
	_check(not PassiveCooldowns.has_cooldown("stone_skin"), "stone_skin has no cooldown")
	var st: Dictionary = PassiveCooldowns.status("stone_skin", stats, tm)
	_check(not st.on_cooldown, "stone_skin never reads as on cooldown")

	# --- Last-trigger-tempo style (wither, rank-scaled total) ---
	stats.passive_levels["wither"] = 5  # cooldown table rank 5 = 11 tempo
	stats.st_wither_last_tempo = 15
	st = PassiveCooldowns.status("wither", stats, tm)
	_check(st.has_cooldown and st.on_cooldown, "wither on cooldown 5 tempo after trigger")
	_check(st.total == 11, "wither rank 5 total is 11 tempo (got %d)" % st.total)
	_check(st.elapsed == 5, "wither elapsed is 5 tempo (got %d)" % st.elapsed)
	stats.st_wither_last_tempo = -100
	st = PassiveCooldowns.status("wither", stats, tm)
	_check(not st.on_cooldown, "wither ready when last trigger is long past")

	# --- Remaining-countdown style (regrowth) ---
	stats.passive_levels["regrowth"] = 1  # cooldown table rank 1 = 25 tempo
	stats.st_regrowth_cooldown = 10
	st = PassiveCooldowns.status("regrowth", stats, tm)
	_check(st.on_cooldown, "regrowth on cooldown while countdown remains")
	_check(st.total == 25 and st.elapsed == 15, "regrowth elapsed = total - remaining (got %d/%d)" % [st.elapsed, st.total])
	stats.st_regrowth_cooldown = 0
	st = PassiveCooldowns.status("regrowth", stats, tm)
	_check(not st.on_cooldown, "regrowth ready when countdown hits 0")

	# --- Charge-pool style (in_the_trenches: 2 charges, 10 tempo refill) ---
	stats.passive_levels["in_the_trenches"] = 1
	stats.st_itt_charges = 1
	st = PassiveCooldowns.status("in_the_trenches", stats, tm)
	_check(not st.on_cooldown, "in_the_trenches solid while charges remain")
	stats.st_itt_charges = 0
	stats.st_itt_last_used_tempo = 15
	st = PassiveCooldowns.status("in_the_trenches", stats, tm)
	_check(st.on_cooldown and st.total == 10 and st.elapsed == 5, "in_the_trenches recharging when pool empty (got %d/%d)" % [st.elapsed, st.total])
	stats.st_itt_last_used_tempo = 5  # 15 tempo ago >= 10: lazy refill counts as ready
	st = PassiveCooldowns.status("in_the_trenches", stats, tm)
	_check(not st.on_cooldown, "in_the_trenches ready once refill window has passed")

	# --- PassiveBoxUI reflects the cooldown state ---
	var box := PassiveBoxUI.new()
	root.add_child(box)
	stats.st_wither_last_tempo = 15
	box.setup("wither", "Wither", "Add +1 charge to the debuff applied to an enemy.", stats, tm)
	_check(box.modulate.a < 1.0, "box fades out while its passive recharges")
	_check("lvl 5" in box.tooltip_text, "tooltip names the passive's level")
	_check("Cooldown: 11 tempo" in box.tooltip_text, "tooltip names the rank-scaled cooldown")
	stats.st_wither_last_tempo = -100
	box.update_display()
	_check(box.modulate == Color(1, 1, 1, 1), "box goes solid when the passive is ready")

	var solid := PassiveBoxUI.new()
	root.add_child(solid)
	solid.setup("stone_skin", "Stone Skin", "Gain resistance.", stats, tm)
	_check(solid.modulate == Color(1, 1, 1, 1), "cooldown-less passive stays solid")
	_check("Cooldown" not in solid.tooltip_text, "cooldown-less tooltip has no cooldown line")

	box.free()
	solid.free()
	stats.free()
	tm.free()

	if failures == 0:
		print("=== 0 failure(s) ===")
	else:
		printerr("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
