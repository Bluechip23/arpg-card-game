extends SceneTree

## Enemy status fixes from the status-effects audit (docs/STATUS_EFFECTS_AUDIT.md §1):
##  - A lone Trip runs out on its own timer (it once waited for some other
##    timed status to land before it ever ticked).
##  - Exposed ends when the enemy gains armor again (Roar, the Earth Mage's
##    hardening, any armor set directly), and returns on the next break.
##  - Mark keeps the longer timer: a "+1" rider never cuts it to 1.
##  - Misery Loves Company spreads the top value — never current + top on the
##    additive timers, never the Stun amp twice.
##  - Expel Negativity moves a timed player debuff as the tempo it had left.
## Boots the dojo so Misery and Expel run through the real Main.
## Run: godot --headless --path . --script tests/test_enemy_status_fixes.gd

var failures := 0
var main = null

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Enemy status fixes ===")
	_run()

func _run() -> void:
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	main = packed.instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(6):
		await process_frame
	_clear_player_debuffs()

	_test_trip()
	_test_exposed()
	_test_mark()
	_test_misery()
	_test_expel()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

# ---------------------------------------------------------------------------

## A fresh enemy a few tiles off the player, with a deep pool so hits read
## straight off armor and health.
func _spawn(type: Enemy.EnemyType, offset: Vector2i) -> Enemy:
	var gm = main.grid_manager
	var cell: Vector2i = gm.world_to_grid(main.player.position) + offset
	var e: Enemy = main.enemy_spawner.spawn_enemy(type, gm.grid_to_world(cell))
	e.max_health = 10000
	e.current_health = 10000
	e.current_armor = 0
	return e

## Out of the spawner's list and off the board, so later nearest-enemy scans
## never see it.
func _drop(e: Enemy) -> void:
	main.enemy_spawner.despawn_enemy(e)

func _clear_player_debuffs() -> void:
	var dm = main.player.get_debuff_manager()
	for d in dm.debuffs.duplicate():
		dm.remove_debuff(d.debuff_type)

func _test_trip() -> void:
	print("--- Tripped wears off on its own ---")
	var e := _spawn(Enemy.EnemyType.DUMMY, Vector2i(6, 0))
	e.apply_debuff("trip", 5)
	_check(e.tripped_tempo == 5 and e.has_debuff_type("trip"), "a lone Trip lands for 5 tempo")
	e._tick_timed_statuses(4)
	_check(e.tripped_tempo == 1, "4 tempo later 1 is left (%d)" % e.tripped_tempo)
	e._tick_timed_statuses(1)
	_check(e.tripped_tempo == 0 and not e.has_debuff_type("trip"), "at 5 tempo the Trip is gone")
	e.apply_debuff("trip", 3)
	var tip: Dictionary = e.get_effect_tooltip("Tripped")
	_check(str(tip["desc"]) == "Its moves cover 4 fewer tiles.", "the badge explains itself (%s)" % tip["desc"])
	_check(str(tip["remaining"]) == "Remaining: 3 tempo", "…and shows the tempo left (%s)" % tip["remaining"])
	_drop(e)

func _test_exposed() -> void:
	print("--- Exposed clears when armor comes back ---")
	var e := _spawn(Enemy.EnemyType.DUMMY, Vector2i(6, 1))
	e.current_armor = 10
	e.take_damage(20, true)
	_check(e.is_exposed and e.current_armor == 0, "breaking the armor exposes it")
	e._try_cerberus_roar()
	e.enemy_thorns = 0
	_check(not e.is_exposed and e.current_armor == 25, "Roar's 25 armor ends Exposed")
	e.take_damage(30, true)
	_check(e.is_exposed, "breaking the new armor exposes it again")
	# A path that sets armor directly is caught on the next tempo.
	e.current_armor = 3
	e._tick_timed_statuses(1)
	_check(not e.is_exposed, "armor set directly: the per-tempo check lifts Exposed")
	_drop(e)

	var mage := _spawn(Enemy.EnemyType.EARTH_MAGE, Vector2i(6, 2))
	mage.current_armor = 5
	mage.take_damage(10, true)
	_check(mage.current_armor == mage.armor_per_hit and mage.armor_per_hit == 4, "the Earth Mage hardens by 4 after the blow (%d)" % mage.current_armor)
	_check(not mage.is_exposed, "…so the hit that broke its armor leaves it armored, not Exposed")
	mage.is_exposed = true  # as if broken by a hit that killed the hardening
	mage._gain_armor(4)
	_check(not mage.is_exposed, "any armor gain lifts Exposed")
	_drop(mage)

func _test_mark() -> void:
	print("--- Mark keeps the longer timer ---")
	var e := _spawn(Enemy.EnemyType.DUMMY, Vector2i(6, 3))
	e.apply_debuff("marked", 25)
	e.apply_debuff("marked", 1)  # Wither / Territorial Death: "+1"
	_check(e.marked_tempo == 25, "a 25-tempo Mark stays 25 after a +1 rider (%d)" % e.marked_tempo)
	e._tick_timed_statuses(20)
	e.apply_debuff("marked", 10)
	_check(e.marked_tempo == 10, "a longer re-apply still lengthens it (%d)" % e.marked_tempo)
	_drop(e)

func _test_misery() -> void:
	print("--- Misery Loves Company spreads the top, never more ---")
	_clear_player_debuffs()
	var stats = main.player.get_stats()
	var a := _spawn(Enemy.EnemyType.DUMMY, Vector2i(-6, 0))
	var b := _spawn(Enemy.EnemyType.DUMMY, Vector2i(-6, 1))
	a.apply_debuff("disarmed", 5)
	b.apply_debuff("disarmed", 4)
	a.apply_debuff("root", 6)
	b.apply_debuff("cursed", 2)
	a.apply_debuff("cursed", 7)
	stats.sphere_stun_amp = 3
	a.apply_debuff("stun", 5)
	_check(a.stun_tempo == 8, "the amp lands once on the source's Stun (%d)" % a.stun_tempo)
	main._misery_active = true
	main._apply_misery_spread([a, b])
	stats.sphere_stun_amp = 0
	_check(b.disarmed_tempo == 5, "Disarm 4 under a top of 5 ends at 5, not 9 (%d)" % b.disarmed_tempo)
	_check(a.disarmed_tempo == 5, "the source keeps its 5 (%d)" % a.disarmed_tempo)
	_check(b.rooted_tempo == 6, "Root spreads as the top (%d)" % b.rooted_tempo)
	_check(b.cursed_tempo == 7, "Curse 2 under a top of 7 ends at 7 (%d)" % b.cursed_tempo)
	_check(b.stun_tempo == 8, "Stun spreads as 8 — the amp is not added twice (%d)" % b.stun_tempo)
	_check(not main._misery_active, "the spread spends the arm")
	_drop(a)
	_drop(b)

func _test_expel() -> void:
	print("--- Expel Negativity moves a timed debuff whole ---")
	_clear_player_debuffs()
	var stats = main.player.get_stats()
	var pt = main.progression_triggers
	var e := _spawn(Enemy.EnemyType.DUMMY, Vector2i(1, 0))
	var target: Enemy = main._get_nearest_enemy()
	_check(target == e, "the expel target is the dummy next to the player")
	stats.add_skill_tree_passive("expel_negativity")
	stats.passive_levels["expel_negativity"] = 15
	stats.st_expel_charges = 2
	stats.current_health = 1
	var dm = main.player.get_debuff_manager()
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.STUN, 0, 15))
	_check(dm.has_debuff(Debuff.DebuffType.STUN), "the player carries a 15-tempo Stun")
	pt._trigger_skill_tree_cory_on_damage_taken(1)
	_check(not dm.has_debuff(Debuff.DebuffType.STUN), "Expel takes the Stun off the player")
	_check(target.stun_tempo == 15, "…and the enemy is stunned for 15, not 1 (%d)" % target.stun_tempo)
	# Stack debuffs still move as their stacks.
	var poison := Debuff.create(Debuff.DebuffType.POISON, 6, 15)
	_check(ProgressionTriggers.expel_transfer_amount(poison, "poison") == 6, "Poison 6 moves as 6 stacks")
	var slowed := Debuff.create_slowed(3)
	_check(ProgressionTriggers.expel_transfer_amount(slowed, "slow") == 3, "Slowed 3 moves as 3 stacks")
	stats.skill_tree_passives.erase("expel_negativity")
	stats.current_health = stats.max_health
	_clear_player_debuffs()
	_drop(e)
