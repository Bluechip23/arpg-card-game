extends SceneTree

## Aiming outlines what will be hit: green (1) when it lands and any chance
## roll goes the player's way, red (2) when it won't (out of range, or the
## pre-rolled chance fails). The auto attack or a single-target card marks
## the enemy under the cursor, an area card every enemy inside its shape —
## a chance area card (Surrounding Ice) matches its green / red tiles — and
## pointing at a tall enemy's body (not its feet) picks it, as a click does.
## Run: godot --headless --path . --script tests/test_target_marks.gd

var failures := 0
var main = null

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _settle(n: int = 3) -> void:
	for _i in range(n):
		await process_frame

func _aim(at: Vector3) -> void:
	main.mouse_override = main.get_world_camera().unproject_position(at)

func _initialize() -> void:
	_run()

func _run() -> void:
	print("=== Target marks test ===")
	main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	await _settle(8)
	while main.olorin and main.olorin.is_busy():
		main.olorin._close()
		await process_frame
	var p: Vector3 = main.player.position
	var gs: float = main.grid_manager.grid_size
	for e in main.enemy_spawner.get_living_enemies():
		e.position += Vector3(0, 0, 60)  # the dojo's chickens, out of the way
	var near: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.RAT_KING, p + Vector3(gs, 0, 0))
	var far: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.CERBERUS, p + Vector3(gs * 4, 0, 0))
	var r1: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.WERERAT, p + Vector3(gs * 3, 0, gs * 3))
	var r2: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.WERERAT, p + Vector3(gs * 4, 0, gs * 3))
	for e in [near, far, r1, r2]:
		e.set_physics_process(false)
	await _settle()

	# Nothing armed: no marks.
	_aim(near.global_position)
	await _settle()
	_check(near.get_target_mark() == 0, "nothing armed: hovering marks nothing")

	# Auto attack: the body of a tall boss, well above its feet, picks it.
	main._set_basic_attack_pending(true)
	_aim(far.global_position + Vector3(0, 1.3, 0))
	await _settle()
	_check(main.enemy_under_mouse() == far, "pointing at Cerberus's body picks Cerberus")
	_check(far.get_target_mark() == 2, "auto attack on a far enemy: red (out of reach)")
	_aim(near.global_position + Vector3(0, 0.7, 0))
	await _settle()
	_check(near.get_target_mark() == 1 and far.get_target_mark() == 0, "auto attack on the adjacent Rat King: green, Cerberus cleared")
	main._set_basic_attack_pending(false)
	await _settle()
	_check(near.get_target_mark() == 0, "disarmed: the mark clears")

	# Single-target card.
	var slash := Card.create_by_id("slash")
	main.deck_manager.hand.append(slash)
	main.select_card(main.deck_manager.hand.size() - 1)
	_aim(near.global_position + Vector3(0, 0.7, 0))
	await _settle()
	_check(near.get_target_mark() == 1, "Slash on the adjacent enemy: green")
	_aim(far.global_position + Vector3(0, 1.0, 0))
	await _settle()
	_check(far.get_target_mark() == 2 and near.get_target_mark() == 0, "Slash aimed at a far enemy: red")
	main.select_card(main.selected_card_index)  # toggle off
	main.selected_card_index = -1
	main.aoe_indicator.hide_indicator()

	# Area card: everyone inside the circle.
	var fb := Card.create_by_id("fireball")
	main.deck_manager.hand.append(fb)
	main.select_card(main.deck_manager.hand.size() - 1)
	var mid: Vector3 = (r1.global_position + r2.global_position) * 0.5
	_aim(mid)
	await _settle(4)
	_check(main.aoe_indicator.visible, "Fireball shows its circle")
	_check(r1.get_target_mark() == 1 and r2.get_target_mark() == 1, "both wererats inside the circle are marked")
	_check(near.get_target_mark() == 0, "the Rat King outside it is not")
	var fig = r1._enemy_figure
	_check(fig._outline.size() == 8 and fig._outline[0].visible, "a sprite enemy draws its outline")
	_check(fig._outline[0].modulate.g > 0.9 and fig._outline[0].modulate.r < 0.5, "green")
	main.selected_card_index = -1
	main.aoe_indicator.hide_indicator()

	# A chance area card: each enemy's outline matches its pre-rolled tile.
	var ice := Card.create_by_id("surrounding_ice")
	main.deck_manager.hand.append(ice)
	main.select_card(main.deck_manager.hand.size() - 1)
	await _settle(4)
	var checked := 0
	var all_match := true
	for e in [near, r1, r2, far]:
		if main.aoe_indicator.visible and main.aoe_indicator._is_enemy_in_aoe(e):
			checked += 1
			var want := 1 if ice.get_rng_outcome(e) else 2
			all_match = all_match and e.get_target_mark() == want
	_check(checked >= 1, "Surrounding Ice covers %d enemies" % checked)
	_check(all_match, "each outline matches its chance tile (green = hit, red = miss)")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
