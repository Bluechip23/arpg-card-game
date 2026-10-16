extends SceneTree

## Buff instances (docs/STATUS_EFFECTS_AUDIT.md, player buffs 18, 19, 21):
##  - Enlightened: every application is its own instance; the highest % pays
##    out and spends one charge per crit roll (ties: fewer charges first).
##  - Resilient: instances of different damage types never merge; the best
##    instance covering a hit applies, and each expires on its own clock.
##  - Haste: every move spends a charge, Flash moves included.
## Run: godot --headless --path . --script tests/test_buff_instances.gd

var failures := 0
var main = null

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Buff instances test ===")
	_test_enlightened()
	_test_resilient()
	await _test_haste()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _fresh_manager() -> BuffManager:
	var stats = load("res://scripts/character/player_stats.gd").new()
	stats.initialize(CharacterData.create_ryan())
	var bm = BuffManager.new()
	bm.initialize(stats)
	return bm

func _test_enlightened() -> void:
	print("-- Enlightened: separate instances, highest % first --")
	var bm := _fresh_manager()
	bm.apply_buff(Buff.create_enlightened(30, 5, "Lady Luck"))
	bm.apply_buff(Buff.create_enlightened(100, 1, "Understanding"))
	var inst := bm.get_buffs(Buff.BuffType.ENLIGHTENED)
	_check(inst.size() == 2, "a 100%%x1 on a 30%%x5 stays a separate instance (%d)" % inst.size())
	_check(inst.size() == 2 and inst[0].value == 30 and inst[0].charges == 5
		and inst[1].value == 100 and inst[1].charges == 1,
		"each keeps its own % and charges")
	_check(bm.get_enlightened_crit_chance() == 100, "the 100% instance applies first")
	_check(bm.get_buff(Buff.BuffType.ENLIGHTENED).value == 100, "get_buff names the instance in charge")

	# Two instances, two badges, each showing its own numbers.
	var bar := BuffBarUI.new()
	get_root().add_child(bar)
	bar.connect_manager(bm)
	var icons := 0
	var shown := {}
	for c in bar.get_children():
		if c is BuffIconUI and c.buff.buff_type == Buff.BuffType.ENLIGHTENED:
			icons += 1
			shown[c.buff.value] = c._count_label.text
	_check(icons == 2, "two Enlightened instances show two badges (%d)" % icons)
	_check(shown.get(30, "") == "x5" and shown.get(100, "") == "x1",
		"each badge counts its own charges (%s)" % [shown])
	bar.queue_free()

	bm.roll_crit()
	_check(bm.get_buffs(Buff.BuffType.ENLIGHTENED).size() == 1, "the first roll spends the 100% instance and removes it")
	_check(bm.get_enlightened_crit_chance() == 30, "…and the 30% takes over")
	_check(bm.get_buff(Buff.BuffType.ENLIGHTENED).charges == 5, "the 30% kept all five charges")
	for i in range(5):
		_check(bm.get_enlightened_crit_chance() == 30, "roll %d after: 30%%" % (i + 2))
		bm.roll_crit()
	_check(not bm.has_buff(Buff.BuffType.ENLIGHTENED), "after five more rolls no Enlightened is left")

	print("-- Enlightened: a tie spends the shorter instance --")
	bm.apply_buff(Buff.create_enlightened(20, 3, "A"))
	bm.apply_buff(Buff.create_enlightened(20, 1, "B"))
	bm.roll_crit()
	var left := bm.get_buffs(Buff.BuffType.ENLIGHTENED)
	_check(left.size() == 1 and left[0].source_name == "A" and left[0].charges == 3,
		"the 20%x1 went first; the 20%x3 is untouched")

	print("-- Enlightened: the amp rides on the top instance, 100 stays 100 --")
	bm.remove_buff(Buff.BuffType.ENLIGHTENED)
	_check(bm.get_buffs(Buff.BuffType.ENLIGHTENED).is_empty(), "remove_buff clears every instance")
	bm.owner_stats.sphere_enlightened_amp = 10.0
	bm.apply_buff(Buff.create_enlightened(10, 2, "Low"))
	bm.apply_buff(Buff.create_enlightened(25, 2, "High"))
	_check(bm.get_enlightened_crit_chance() == 35, "25% + 10 amp = 35 (never 10 + 25)")
	bm.apply_buff(Buff.create_enlightened(100, 1, "Scouted"))
	_check(bm.get_enlightened_crit_chance() == 100, "a 100% instance stays exactly 100")

func _test_resilient() -> void:
	var physical: int = DamageTypes.Type.PHYSICAL
	var fire: int = DamageTypes.Type.FIRE

	print("-- Resilient: Harden then Succumb --")
	var bm := _fresh_manager()
	bm.apply_buff(Buff.create_resilient(10, 15, "Harden", physical))
	bm.apply_buff(Buff.create_resilient(20, 20, "Succumb"))
	_check(bm.get_buffs(Buff.BuffType.RESILIENT).size() == 2, "typed and untyped stay separate")
	_check(bm.get_resilient_percent(physical) == 20, "physical: 20%% (%d)" % bm.get_resilient_percent(physical))
	_check(bm.get_resilient_percent(fire) == 20, "fire: 20%% (%d)" % bm.get_resilient_percent(fire))
	bm.advance_time(15)
	_check(bm.get_buffs(Buff.BuffType.RESILIENT).size() == 1, "Harden runs out on its own clock (15)")
	_check(bm.get_resilient_percent(physical) == 20, "Succumb still covers physical")
	bm.advance_time(5)
	_check(bm.get_buffs(Buff.BuffType.RESILIENT).is_empty(), "Succumb runs out on its own clock (20)")

	print("-- Resilient: Succumb runs out first --")
	bm.apply_buff(Buff.create_resilient(10, 30, "Harden", physical))
	bm.apply_buff(Buff.create_resilient(20, 20, "Succumb"))
	bm.advance_time(20)
	_check(bm.get_resilient_percent(physical) == 10, "after Succumb ends, Harden's 10%% physical remains (%d)" % bm.get_resilient_percent(physical))
	_check(bm.get_resilient_percent(fire) == 0, "…and fire is unguarded again")
	bm.advance_time(10)
	_check(bm.get_buffs(Buff.BuffType.RESILIENT).is_empty(), "then Harden ends too")

	print("-- Resilient: Smithed Excellence then Harden --")
	bm.apply_buff(Buff.create_resilient(2, 3, "Smithed Excellence"))
	bm.apply_buff(Buff.create_resilient(10, 15, "Harden", physical))
	_check(bm.get_resilient_percent(physical) == 10, "physical: 10%% (%d)" % bm.get_resilient_percent(physical))
	_check(bm.get_resilient_percent(fire) == 2, "fire: 2%% (%d)" % bm.get_resilient_percent(fire))
	_check(bm.calculate_damage_reduction(100, fire) == 98, "a 100 fire hit lands as 98")
	bm.advance_time(3)
	_check(bm.get_resilient_percent(fire) == 0 and bm.get_resilient_percent(physical) == 10,
		"the 2% all-damage instance expires on its own; Harden stays")
	bm.remove_buff(Buff.BuffType.RESILIENT)

	print("-- Resilient: same type still merges --")
	bm.apply_buff(Buff.create_resilient(2, 3, "Smithed"))
	bm.apply_buff(Buff.create_resilient(10, 15, "Stone Hide"))
	var same := bm.get_buffs(Buff.BuffType.RESILIENT)
	_check(same.size() == 1 and same[0].value == 10 and same[0].duration == 15,
		"two untyped: the stronger % replaces, the longer clock is kept")
	bm.apply_buff(Buff.create_resilient(5, 30, "Weaker"))
	_check(same[0].value == 10 and same[0].duration == 30, "a weaker one only extends the clock")

func _settle(frames: int = 6) -> void:
	for _i in range(frames):
		await process_frame

func _boot() -> void:
	print("-- Booting main.tscn as the dojo --")
	main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	await _settle()
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	_check(main.player != null, "the dojo is up")

## A target two tiles away in a straight open line, so a 1-tile order plus
## Haste's +1 walks two tiles.
func _two_tile_target(player: Player) -> Vector3:
	var gm = player.grid_manager
	var here: Vector2i = gm.world_to_grid(player.global_position)
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var target: Vector3 = gm.grid_to_world(here + dir * 2)
		if player.preview_path_cells(target, 1).size() == 2:
			return target
	return Vector3.INF

func _walk(player: Player, spaces: int) -> bool:
	var target := _two_tile_target(player)
	if target == Vector3.INF:
		return false
	if not player.move_to_grid(target, spaces):
		return false
	var guard := 0
	while player.is_moving and guard < 600:
		await process_frame
		guard += 1
	return not player.is_moving

func _test_haste() -> void:
	await _boot()
	if main == null or main.player == null:
		return
	var player: Player = main.player
	var stats = player.get_stats()
	var bm = player.get_buff_manager()
	for b in bm.buffs.duplicate():
		bm.remove_buff(b.buff_type)
	stats.sphere_haste_amp = 0
	stats.free_move_tiles = 0

	print("-- Haste: a Flash move spends a charge --")
	bm.apply_buff(Buff.create_haste(1, 3, "Test"))
	stats.flash_movement_enabled = true
	stats.current_flash_points = stats.get_max_flash_points()
	var flash_before: int = stats.current_flash_points
	var walked: bool = await _walk(player, 1)
	_check(walked, "the flash move ran")
	var haste = bm.get_buff(Buff.BuffType.HASTE)
	_check(haste != null and haste.charges == 2, "Haste 3 → 2 after a Flash move (%s)" % [haste.charges if haste else "gone"])
	_check(stats.free_move_tiles == 0, "the bonus tile was spent free on that move (%d left)" % stats.free_move_tiles)
	_check(stats.current_flash_points < flash_before, "the ordered tile still cost flash (%d → %d)" % [flash_before, stats.current_flash_points])

	print("-- Haste: a normal move spends a charge --")
	stats.flash_movement_enabled = false
	walked = await _walk(player, 1)
	_check(walked, "the normal move ran")
	haste = bm.get_buff(Buff.BuffType.HASTE)
	_check(haste != null and haste.charges == 1, "Haste 2 → 1 after a normal move (%s)" % [haste.charges if haste else "gone"])

	print("-- Haste: the last charge goes on a Flash move --")
	stats.flash_movement_enabled = true
	stats.current_flash_points = stats.get_max_flash_points()
	walked = await _walk(player, 1)
	_check(walked, "the second flash move ran")
	_check(not bm.has_buff(Buff.BuffType.HASTE), "Haste is used up")
	stats.flash_movement_enabled = false
