extends SceneTree

## Buff instances (docs/STATUS_EFFECTS_AUDIT.md, player buffs 18, 19, 21):
##  - Keen: every application is its own instance; the highest % pays
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
	_test_keen()
	_test_resilient()
	_test_attune()
	await _test_haste()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _fresh_manager() -> BuffManager:
	var stats = load("res://scripts/character/player_stats.gd").new()
	stats.initialize(CharacterData.create_ryan())
	var bm = BuffManager.new()
	bm.initialize(stats)
	return bm

func _test_keen() -> void:
	print("-- Keen: separate instances, highest % first --")
	var bm := _fresh_manager()
	bm.apply_buff(Buff.create_keen_rolls(30, 5, "Lady Luck"))
	bm.apply_buff(Buff.create_keen_rolls(100, 1, "Understanding"))
	var inst := bm.get_buffs(Buff.BuffType.KEEN)
	_check(inst.size() == 2, "a 100%%x1 on a 30%%x5 stays a separate instance (%d)" % inst.size())
	_check(inst.size() == 2 and inst[0].value == 30 and inst[0].charges == 5
		and inst[1].value == 100 and inst[1].charges == 1,
		"each keeps its own % and charges")
	_check(bm.get_keen_crit_chance() == 100, "the 100% instance applies first")
	_check(bm.get_buff(Buff.BuffType.KEEN).value == 100, "get_buff names the instance in charge")

	# Two instances, two badges, each showing its own numbers.
	var bar := BuffBarUI.new()
	get_root().add_child(bar)
	bar.connect_manager(bm)
	var icons := 0
	var shown := {}
	for c in bar.get_children():
		if c is BuffIconUI and c.buff.buff_type == Buff.BuffType.KEEN:
			icons += 1
			shown[c.buff.value] = c._count_label.text
	_check(icons == 2, "two Keen instances show two badges (%d)" % icons)
	_check(shown.get(30, "") == "x5" and shown.get(100, "") == "x1",
		"each badge counts its own charges (%s)" % [shown])
	bar.queue_free()

	bm.roll_crit()
	_check(bm.get_buffs(Buff.BuffType.KEEN).size() == 1, "the first roll spends the 100% instance and removes it")
	_check(bm.get_keen_crit_chance() == 30, "…and the 30% takes over")
	_check(bm.get_buff(Buff.BuffType.KEEN).charges == 5, "the 30% kept all five charges")
	for i in range(5):
		_check(bm.get_keen_crit_chance() == 30, "roll %d after: 30%%" % (i + 2))
		bm.roll_crit()
	_check(not bm.has_buff(Buff.BuffType.KEEN), "after five more rolls no Keen is left")

	print("-- Keen: a tie spends the shorter instance --")
	bm.apply_buff(Buff.create_keen_rolls(20, 3, "A"))
	bm.apply_buff(Buff.create_keen_rolls(20, 1, "B"))
	bm.roll_crit()
	var left := bm.get_buffs(Buff.BuffType.KEEN)
	_check(left.size() == 1 and left[0].source_name == "A" and left[0].charges == 3,
		"the 20%x1 went first; the 20%x3 is untouched")

	print("-- Keen: the amp rides on the top instance, 100 stays 100 --")
	bm.remove_buff(Buff.BuffType.KEEN)
	_check(bm.get_buffs(Buff.BuffType.KEEN).is_empty(), "remove_buff clears every instance")
	bm.owner_stats.sphere_keen_amp = 10.0
	bm.apply_buff(Buff.create_keen_rolls(10, 2, "Low"))
	bm.apply_buff(Buff.create_keen_rolls(25, 2, "High"))
	_check(bm.get_keen_crit_chance() == 35, "25% + 10 amp = 35 (never 10 + 25)")
	bm.apply_buff(Buff.create_keen_rolls(100, 1, "Scouted"))
	_check(bm.get_keen_crit_chance() == 100, "a 100% instance stays exactly 100")

	print("-- Keen: on the clock and by the roll are one buff --")
	bm = _fresh_manager()
	bm.apply_buff(Buff.create_keen(15, 10, "Stone Wheel"))
	bm.apply_buff(Buff.create_keen(10, 20, "Ragnarok"))
	_check(bm.get_buffs(Buff.BuffType.KEEN).size() == 1 and bm.get_keen_crit_chance() == 25,
		"timed Keen stacks its value into one badge (%d%%)" % bm.get_keen_crit_chance())
	bm.apply_buff(Buff.create_keen_rolls(30, 2, "Lady Luck"))
	_check(bm.get_buffs(Buff.BuffType.KEEN).size() == 2 and bm.get_keen_crit_chance() == 55,
		"a by-the-roll Keen sits beside it and adds (%d%%)" % bm.get_keen_crit_chance())
	_check(bm.get_buffs(Buff.BuffType.KEEN).all(func(k): return k.buff_name == "Keen"), "both read Keen")
	bm.roll_crit(0)
	bm.roll_crit(0)
	_check(bm.get_keen_crit_chance() == 25, "two rolls spend the by-the-roll Keen; the timed one spends nothing")
	bm.advance_time(20)
	_check(not bm.has_buff(Buff.BuffType.KEEN), "the timed Keen runs out on its clock (longer timer kept)")
	bm.apply_buff(Buff.create_keen_rolls(30, 2, "Lady Luck"))
	bm.advance_time(50)
	_check(bm.get_keen_crit_chance() == 30, "a by-the-roll Keen never runs out by the clock")

func _test_attune() -> void:
	print("-- Attune: +X on the next offensive spells, attacks leave it alone --")
	var bm := _fresh_manager()
	var stats = bm.owner_stats
	bm.apply_buff(Buff.create_attune(3, 3, "Arcane Tide"))
	var at: Buff = bm.get_buff(Buff.BuffType.ATTUNE)
	_check(at != null and at.buff_name == "Attune" and at.value == 3 and at.charges == 3, "Attune 3 for 3 spells")
	bm.apply_buff(Buff.create_attune(2, 2, "Clarity"))
	_check(bm.get_buffs(Buff.BuffType.ATTUNE).size() == 1 and at.value == 5 and at.charges == 3,
		"a second Attune adds its value and keeps the higher count (%d x%d)" % [at.value, at.charges])
	var plain: int = stats.get_effective_spell_damage(10)
	# An attack card: no Attune, no charge.
	var atk := Card.create_by_id("slash")
	atk.execute(null, stats, null, 0.0, 0.0, bm)
	_check(at.charges == 3 and stats.active_spell_power_bonus == 0, "an attack neither gains nor spends Attune")
	# A non-offensive spell: untouched too.
	var util := Card.create_by_id("lady_luck")
	util.execute(null, stats, null, 0.0, 0.0, bm)
	_check(bm.get_buff(Buff.BuffType.ATTUNE).charges == 3, "a utility spell does not spend it")
	# An offensive spell takes +5 for its play and spends one charge.
	var spell := Card.create_by_id("mana_surge")
	_check(spell.school == Card.CardSchool.SPELL and spell.is_offensive(), "Mana Surge is an offensive spell")
	Card.play_scope_open = true
	spell.execute(null, stats, null, 0.0, 0.0, bm)
	_check(stats.get_effective_spell_damage(10) == plain + 5, "the spell's damage is +5 while it resolves (%d vs %d)" % [stats.get_effective_spell_damage(10), plain])
	Card.close_play_scope(stats)
	_check(stats.get_effective_spell_damage(10) == plain, "…and the bonus ends with the play")
	_check(bm.get_buff(Buff.BuffType.ATTUNE).charges == 2, "one charge spent")
	for i in 2:
		Card.create_by_id("mana_surge").execute(null, stats, null, 0.0, 0.0, bm)
	_check(not bm.has_buff(Buff.BuffType.ATTUNE), "after three offensive spells Attune is gone")
	_check(stats.active_spell_power_bonus == 0, "nothing lingers on the stats")

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

	print("-- Resilient: Endured Tolerance stands apart from other all-damage Resilient --")
	var endured := func() -> Buff:
		var et := Buff.create_resilient(5, 5, "Endured Tolerance", DamageTypes.ALL)
		et.extends_on_reapply = true
		return et
	bm.apply_buff(endured.call())
	bm.apply_buff(endured.call())
	_check(bm.get_buffs(Buff.BuffType.RESILIENT).size() == 1 and bm.get_buffs(Buff.BuffType.RESILIENT)[0].duration == 10,
		"two copies: one instance, 5 + 5 tempo")
	bm.apply_buff(Buff.create_resilient(20, 20, "Succumb"))
	var res := bm.get_buffs(Buff.BuffType.RESILIENT)
	_check(res.size() == 2 and res[0].value == 5 and res[0].duration == 10 and res[1].value == 20 and res[1].duration == 20,
		"Succumb's 20% does not merge into it (5%/10t beside 20%/20t)")
	_check(bm.get_resilient_percent(fire) == 20, "the stronger one applies; they never add up")
	bm.apply_buff(endured.call())
	res = bm.get_buffs(Buff.BuffType.RESILIENT)
	_check(res[0].value == 5 and res[0].duration == 15 and res[1].value == 20 and res[1].duration == 20,
		"a third copy extends only its own clock, never Succumb's 20%% (%d%%/%dt, %d%%/%dt)" % [res[0].value, res[0].duration, res[1].value, res[1].duration])
	bm.advance_time(15)
	_check(bm.get_resilient_percent(fire) == 20 and bm.get_buffs(Buff.BuffType.RESILIENT).size() == 1,
		"Endured Tolerance ends on its own clock; Succumb goes on")
	bm.advance_time(5)
	bm.apply_buff(Buff.create_resilient(20, 20, "Succumb"))
	bm.apply_buff(endured.call())
	bm.advance_time(5)
	_check(bm.get_resilient_percent(fire) == 20 and bm.get_buffs(Buff.BuffType.RESILIENT).size() == 1,
		"applied second, it still keeps its own 5 tempo and leaves Succumb at 20%")
	bm.advance_time(15)
	_check(bm.get_buffs(Buff.BuffType.RESILIENT).is_empty(), "everything ran out")

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
