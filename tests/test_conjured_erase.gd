extends SceneTree

## Conjured copies start their Erase fuse full.
##  - Captain Planets Circlet adds a Fireball and a Rise with Erase 10.
##  - Fire Punch adds a copy of itself with Erase 5.
## Both used to set erase_tempo without erase_tempo_remaining, so the copies
## vanished at the very next cycle. Each must now survive its stated tempo in
## the hand and be erased once the fuse runs out.
## Run: godot --headless --path . --script tests/test_conjured_erase.gd

var failures: int = 0
var main = null

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	await _boot()
	if main == null:
		print("=== %d failure(s) ===" % failures)
		quit(1)
		return
	_test_captain_planet()
	_test_fire_punch()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

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
	_check(main.player != null and main.deck_manager != null, "the dojo is up")
	if main.player == null:
		main = null

func _cycle() -> void:
	## One 5-tempo cycle of erase fuses (what process_turn runs each cycle).
	main.deck_manager._process_erase_timers()

func _in_hand(card: Card) -> bool:
	return card in main.deck_manager.hand

func _test_captain_planet() -> void:
	print("-- Captain Planets Circlet: Fireball and Rise arrive with Erase 10 --")
	var dm = main.deck_manager
	dm.hand.clear()
	# Its "draw 3" would fill the hand to the cap and turn the second copy
	# away (cards added to a full hand are lost) — keep the piles empty so
	# the test sees both copies.
	dm.draw_pile.clear()
	dm.discard_pile.clear()
	var ring := ItemData.create("captain_planets_circlet")
	main._on_custom_ring_fired(ring, "captain_planet", 0)
	var copies: Array = []
	for c in dm.hand:
		if c.erase_tempo == 10:
			copies.append(c)
	_check(copies.size() == 2, "two conjured copies in hand (%d)" % copies.size())
	for c in copies:
		_check(c.erase_tempo_remaining == 10, "%s starts its fuse at 10 (%d)" % [c.card_name, c.erase_tempo_remaining])
	_cycle()
	var alive := 0
	for c in copies:
		if _in_hand(c):
			alive += 1
	_check(alive == copies.size(), "both copies survive the first cycle (5 of 10 tempo)")
	_cycle()
	var gone := 0
	for c in copies:
		if not _in_hand(c):
			gone += 1
	_check(gone == copies.size(), "both copies are erased once 10 tempo have run")

func _test_fire_punch() -> void:
	print("-- Fire Punch: its copy arrives with Erase 5 --")
	var dm = main.deck_manager
	dm.hand.clear()
	var enemy: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.ZOMBIE,
		main._ground_pos(main.grid_manager.world_to_grid(main.player.position) + Vector2i(1, 0)))
	var fp := Card.create_by_id("fire_punch")
	main._apply_card_world_effects(fp, enemy)
	var copy: Card = null
	for c in dm.hand:
		if c.card_id == "fire_punch" and c.has_meta("fire_punch_copy"):
			copy = c
	_check(copy != null, "the Erase-5 copy is in hand")
	if copy == null:
		return
	_check(copy.erase_tempo_remaining == 5, "the copy starts its fuse at 5 (%d)" % copy.erase_tempo_remaining)
	_check(_in_hand(copy), "it is still in hand before any cycle")
	_cycle()
	_check(not _in_hand(copy), "it is erased once its 5 tempo have run")
	if is_instance_valid(enemy):
		main.enemy_spawner.despawn_enemy(enemy)
