extends SceneTree

## Point-target ("Pick a point") cards, played the way a player plays them:
## the card's number key, the mouse moved onto a tile, a left click — the
## events go through Main._input, not straight to play_selected_card.
##  - Fireball plays and burns what stands in its circle: on the dojo's near
##    dummy (under the empty Buff/Debuff bar strips, which used to swallow
##    the click), on the far one (inside the range ring, 11 steps away, which
##    the old step-counted check refused), on an empty tile, and on a world
##    map; past the ring it is refused "Out of range".
##  - An unslotted Engrave card says why it will not play; the sandbox's
##    copy comes engraved.
##  - A point burst's indicator wears a green dot on its centre tile (lines
##    and cones do not), and that tile is the play's target point.
##  - Seance judges "an empty tile" at the centre tile when the card is
##    played, not after it has killed what stood there.
##  - Co-op: the aim is locked at the aiming click; moving the mouse to
##    Play Now / Lock In leaves it there.
## Run: godot --headless --path . --script tests/test_point_card_targeting.gd

var failures: int = 0
var main = null
var dm = null
var tm = null
var stats = null
var _spawned: Array = []
var _home := Vector2i.ZERO

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	TempoManager.preferred_swing_hold = 0
	await _boot("dojo")
	await _t_dojo_dummies()
	await _t_circle_and_range()
	_t_hud_bars()
	await _t_engrave()
	await _t_center_dot()
	await _t_seance()
	await _t_coop_lock()
	main.queue_free()
	await process_frame
	await _boot("")
	await _t_world_map()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

# ------------------------------------------------------------------ helpers

func _boot(interior: String) -> void:
	main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	if interior != "":
		main.set("current_interior_id", interior)
	get_root().add_child(main)
	for _i in range(6):
		await process_frame
	await _close_olorin()
	dm = main.deck_manager
	tm = main.tempo_manager
	stats = main.player.get_stats()
	main.draw_timer.tempo_until_draw = 100000.0
	_home = main.grid_manager.world_to_grid(main.player.position)

func _close_olorin() -> void:
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 20:
		main.olorin._close()
		guard += 1
		await process_frame

func _reset() -> void:
	_drain()
	for e in _spawned:
		if is_instance_valid(e):
			main.enemy_spawner.despawn_enemy(e)
	_spawned.clear()
	stats.max_mana = 2000
	stats.current_mana = 2000
	stats.equipment_crit_bonus = -100.0
	main.player.get_debuff_manager().clear_all_debuffs()
	dm.hand.clear()
	main.select_card(-1)
	main._last_aim_world = null
	main.mouse_override = Vector2(-1, -1)
	tm.current_tempo = 0
	_teleport(_home)

## Put the hero on `cell` with the camera already over them (it glides
## otherwise, and the mouse's pixel would land on another tile).
func _teleport(cell: Vector2i) -> void:
	main.player.position = main._ground_pos(cell)
	main.player.target_position = main.player.position
	main._camera_focus = main.player.position
	main._update_camera()

func _drain() -> void:
	var n := 0
	while tm._pending_ticks > 0 and n < 200:
		tm._process_one_tick()
		n += 1

func _queued(card: Card) -> bool:
	for en in main._pending_resolve_queue:
		if en["card"] == card:
			return true
	return false

func _spawn_at(cell: Vector2i, hp: int = 1000, kind: int = Enemy.EnemyType.DUMMY) -> Enemy:
	var e: Enemy = main.enemy_spawner.spawn_enemy(kind, main._ground_pos(cell))
	e.chosen_action = {}
	e.max_health = hp
	e.current_health = hp
	e.current_armor = 0
	_spawned.append(e)
	return e

## Fireball engraved in a plain staff slot.
func _staff_fireball() -> Card:
	var staff := ItemData.new()
	staff.item_name = "Test Staff"
	staff.card_slots = 1
	var c := Card.create_by_id("fireball")
	if not staff.slot_card(c):
		c.slotted_in_item = staff
	return c

## Put `card` alone in the hand and press its number key.
func _select_by_key(card: Card) -> void:
	dm.hand.clear()
	dm.hand.append(card)
	main._on_hand_updated()
	await process_frame
	var key := KEY_1
	for g in main._hand_groups:
		if card in g["cards"]:
			key = main.CARD_KEYS[int(g["slot"])]
	var k := InputEventKey.new()
	k.keycode = key
	k.pressed = true
	main._input(k)

## Move the mouse onto a tile (the world viewport's pixel for it). The
## camera glides after a teleported hero, so the pixel is taken again just
## before the click (_click) — the hand stays on the tile.
var _hover_cell := Vector2i.ZERO
func _hover(cell: Vector2i) -> void:
	_hover_cell = cell
	main.mouse_override = main.get_world_camera().unproject_position(main._ground_pos(cell))
	var mm := InputEventMouseMotion.new()
	mm.position = main.mouse_override
	main._input(mm)
	await process_frame
	await process_frame

func _click() -> void:
	main.mouse_override = main.get_world_camera().unproject_position(main._ground_pos(_hover_cell))
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = main.mouse_override
	main._input(ev)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = main.mouse_override
	main._input(up)

## Key, aim, click, then tick until the card has resolved. True if it played.
func _play_by_input(card: Card, cell: Vector2i) -> bool:
	await _select_by_key(card)
	await _hover(cell)
	_click()
	var played: bool = not dm.hand.has(card) or _queued(card)
	var n := 0
	while _queued(card) and n < 60:
		tm._process_one_tick()
		n += 1
	return played

var _log: Array = []
func _on_log(msg: String) -> void:
	_log.append(msg)

func _logged(part: String) -> bool:
	for m in _log:
		if part in m:
			return true
	return false

# -------------------------------------------------------------------- tests

func _t_dojo_dummies() -> void:
	print("-- Fireball by key, mouse and click on the dojo's chicken dummies --")
	main.battle_logged.connect(_on_log)
	var dummies: Array = []
	for e in main.enemy_spawner.get_living_enemies():
		if is_instance_valid(e):
			dummies.append(e)
	_check(dummies.size() >= 2, "the dojo stands its enemy dummies (%d)" % dummies.size())
	for d in dummies:
		_reset()
		d.max_health = 1000
		d.current_health = 1000
		d.current_armor = 0
		d.burn_stacks = 0
		var cell: Vector2i = main.grid_manager.world_to_grid(d.position)
		var off: Vector2i = cell - _home
		var fb := _staff_fireball()
		var played := await _play_by_input(fb, cell)
		_check(played, "Fireball plays on the dummy at %s (%d steps, %.1f tiles away)" % [cell, absi(off.x) + absi(off.y), Vector2(off).length()])
		_check(d.current_health < 1000 and d.burn_stacks > 0,
			"...and burns it (%d HP, %d burn)" % [d.current_health, d.burn_stacks])
	_reset()

func _t_circle_and_range() -> void:
	print("-- The circle around the clicked tile; the range ring as the cap --")
	for e in main.enemy_spawner.get_living_enemies().duplicate():
		main.enemy_spawner.despawn_enemy(e)
	_reset()
	var aim := _home + Vector2i(-4, -3)   # 5 tiles off, empty
	var a := _spawn_at(aim + Vector2i(1, 0))
	var b := _spawn_at(aim + Vector2i(0, -1))
	var out := _spawn_at(aim + Vector2i(-3, 0))
	var fb := _staff_fireball()
	var played := await _play_by_input(fb, aim)
	_check(played, "Fireball aimed at an empty tile plays")
	_check(a.current_health < a.max_health and b.current_health < b.max_health and a.burn_stacks > 0 and b.burn_stacks > 0,
		"both enemies inside the circle are hit and burnt (%d, %d)" % [a.current_health, b.current_health])
	_check(out.current_health == out.max_health and out.burn_stacks == 0, "the enemy outside the circle is untouched")
	_reset()
	# Past the ring (10 tiles): refused, nothing spent. (From the hall's
	# west wall, 11 tiles straight east.)
	_log.clear()
	var west_wall := Vector2i(1, 10)
	var far := Vector2i(12, 10)
	_teleport(west_wall)
	var fb2 := _staff_fireball()
	var mana: int = stats.current_mana
	var played2 := await _play_by_input(fb2, far)
	_check(not played2 and dm.hand.has(fb2) and stats.current_mana == mana, "a tile 11 tiles off is past the 10-tile ring: no play")
	_check(_logged("Out of range"), "...and the log says Out of range")
	var pcell: Vector2i = main.grid_manager.world_to_grid(main.player.position)
	_check(main._point_in_card_reach(main.grid_manager.grid_to_world(pcell + Vector2i(-6, -7)), 10),
		"a diagonal tile 9.2 tiles off (13 steps) is inside the ring")
	# Sphere-grid Range counts, as the ring shows it.
	_reset()
	_teleport(west_wall)
	stats.sphere_bonus_range = 2
	var e11 := _spawn_at(far)
	var fb3 := _staff_fireball()
	var played3 := await _play_by_input(fb3, far)
	_check(played3 and e11.current_health < e11.max_health, "with +2 sphere Range the ring reaches 12: the 11-tile shot plays (%s, %d HP)" % [played3, e11.current_health])
	stats.sphere_bonus_range = 0
	_reset()

func _t_hud_bars() -> void:
	print("-- The empty Buff / Debuff bar strips are battlefield, not HUD --")
	_check(main.buff_bar.mouse_filter == Control.MOUSE_FILTER_IGNORE, "BuffBar takes no mouse itself")
	_check(main.debuff_bar.mouse_filter == Control.MOUSE_FILTER_IGNORE, "DebuffBar takes no mouse itself")

func _t_engrave() -> void:
	print("-- An Engrave card outside an item --")
	_reset()
	_log.clear()
	var bare := Card.create_by_id("fireball")
	_check(bare.requires_engraving and bare.slotted_in_item == null, "a bare Fireball is unslotted Engrave")
	dm.hand.append(bare)
	main.selected_card_index = 0
	main._last_aim_world = main._ground_pos(_home + Vector2i(-3, 0))
	main.play_selected_card(main.player)
	_check(dm.hand.has(bare) and _logged("must be engraved"), "it does not play, and the log says it must be engraved")
	_reset()
	main._on_sandbox_add_card("fireball")
	var sb: Card = dm.hand.back() if not dm.hand.is_empty() else null
	_check(sb != null and sb.card_id == "fireball" and sb.slotted_in_item != null, "the sandbox's Fireball comes engraved")
	if sb:
		var e := _spawn_at(_home + Vector2i(-3, 0))
		dm.hand.erase(sb)
		var played := await _play_by_input(sb, _home + Vector2i(-3, 0))
		_check(played and e.current_health < e.max_health, "...and plays")
	_reset()

func _t_center_dot() -> void:
	print("-- The green centre dot on a point burst --")
	_reset()
	var fb := _staff_fireball()
	await _select_by_key(fb)
	var aim := _home + Vector2i(-3, -2)
	await _hover(aim)
	var ind = main.aoe_indicator
	_check(ind.visible and ind.has_center_dot(), "aiming Fireball shows the area with its centre dot")
	var dot: MeshInstance3D = ind._center_dot
	var dot_cell: Vector2i = main.grid_manager.world_to_grid(dot.global_position)
	_check(dot_cell == aim, "the dot sits on the aimed tile %s (at %s)" % [aim, dot_cell])
	var col: Color = (dot.material_override as StandardMaterial3D).albedo_color
	_check(col.g > 0.8 and col.r < 0.4 and col.b < 0.5, "the dot is green (%s)" % col)
	await _hover(aim + Vector2i(1, 1))
	_check(main.grid_manager.world_to_grid(dot.global_position) == aim + Vector2i(1, 1), "the dot follows the aim to the next tile")
	_click()
	var entry: Dictionary = {}
	for en in main._pending_resolve_queue:
		if en["card"] == fb:
			entry = en
	_check(not entry.is_empty() and entry["data"].get("aim_world") is Vector3 \
			and main.grid_manager.world_to_grid(entry["data"]["aim_world"]) == aim + Vector2i(1, 1),
		"the play's target point is the dot's tile")
	_reset()
	for id in ["poison_bomb", "sprinkle_bomb", "ice_grenade", "peshtigos_kiss"]:
		var c := Card.create_by_id(id)
		if c == null:
			continue
		await _select_by_key(c)
		await _hover(_home + Vector2i(-2, -1))
		_check(ind.visible and ind.has_center_dot(), "%s (a point circle) shows the centre dot" % c.card_name)
		_reset()
	for id in ["spirit_arrow", "snowballs_chance", "charge"]:
		var c := Card.create_by_id(id)
		if c == null or not c.is_aoe:
			continue
		await _select_by_key(c)
		await _hover(_home + Vector2i(-3, 0))
		_check(not ind.has_center_dot(), "%s (%s from the hero) has no centre dot" % [c.card_name, c.aoe_shape])
		_reset()

func _t_seance() -> void:
	print("-- Seance judges the centre tile as the card is played --")
	stats.add_skill_tree_passive("seance")
	stats.passive_levels["seance"] = 1
	for e in main.enemy_spawner.get_living_enemies().duplicate():
		main.enemy_spawner.despawn_enemy(e)
	_reset()
	# An enemy on the centre tile that the blast kills: the tile was not
	# empty when the card was played, so no Specter.
	var aim := _home + Vector2i(-4, -2)
	var victim := _spawn_at(aim, 1, Enemy.EnemyType.MINION)
	var before: int = main._specters.size()
	var played := await _play_by_input(_staff_fireball(), aim)
	_check(played and (victim.is_dead or not is_instance_valid(victim)), "Fireball on the enemy's tile kills it")
	_check(main._specters.size() == before, "...and raises no Specter: the tile held an enemy at the play")
	_reset()
	# An empty centre tile (an enemy beside it in the blast): a Specter on it.
	var side := _spawn_at(aim + Vector2i(1, 0))
	before = main._specters.size()
	played = await _play_by_input(_staff_fireball(), aim)
	_check(played and side.current_health < side.max_health, "Fireball on an empty tile next to an enemy hits it")
	var raised: bool = main._specters.size() == before + 1
	_check(raised, "...and Seance raises a Specter")
	if raised:
		_check(main.grid_manager.world_to_grid(main._specters.back().position) == aim, "...on the centre tile %s" % aim)
	for s in main._specters.duplicate():
		if is_instance_valid(s):
			s.queue_free()
	main._specters.clear()
	stats.skill_tree_passives.erase("seance")
	stats.passive_levels.erase("seance")
	_reset()

func _t_coop_lock() -> void:
	print("-- Co-op: the aim is locked at the click --")
	main._on_sandbox_add_ally("Jeremy")
	await process_frame
	_check(main.is_multiplayer and main._p2_player != null, "a partner joins")
	main.draw_timer.tempo_until_draw = 100000.0
	for e in main.enemy_spawner.get_living_enemies().duplicate():
		main.enemy_spawner.despawn_enemy(e)
	_reset()
	var aim := _home + Vector2i(-4, -3)
	var elsewhere := _home + Vector2i(3, -5)
	var at_aim := _spawn_at(aim)
	var at_else := _spawn_at(elsewhere)
	var fb := _staff_fireball()
	await _select_by_key(fb)
	await _hover(aim)
	_click()
	_check(main._card_confirm_panel != null and main._card_confirm_panel.visible, "the click asks Play Now / Lock In")
	_check(dm.hand.has(fb), "...and nothing is spent yet")
	# The mouse goes off to the button (over the battlefield on its way).
	await _hover(elsewhere)
	_check(main.grid_manager.world_to_grid(main.aoe_indicator.position) == aim,
		"moving the mouse leaves the burst on the clicked tile (%s)" % main.grid_manager.world_to_grid(main.aoe_indicator.position))
	main._on_card_play_now()   # the Play Now button
	var n := 0
	while _queued(fb) and n < 60:
		tm._process_one_tick()
		n += 1
	_check(not dm.hand.has(fb), "Play Now plays the card")
	_check(at_aim.current_health < at_aim.max_health, "...at the clicked tile: the enemy there is hit")
	_check(at_else.current_health == at_else.max_health, "...not where the mouse went")
	_reset()
	# Lock In, then Play Cards with the mouse somewhere else.
	at_aim = _spawn_at(aim)
	at_else = _spawn_at(elsewhere)
	var fb2 := _staff_fireball()
	await _select_by_key(fb2)
	await _hover(aim)
	_click()
	await _hover(elsewhere)
	main._on_card_lock_in()
	_check(main._locked_cards.size() == 1, "Lock In queues the card")
	await _hover(elsewhere + Vector2i(1, 0))
	main._last_aim_world = main._ground_pos(elsewhere)   # say a later click aimed elsewhere
	main._on_play_cards_pressed()
	n = 0
	while _queued(fb2) and n < 60:
		tm._process_one_tick()
		n += 1
	_check(at_aim.current_health < at_aim.max_health and at_else.current_health == at_else.max_health,
		"the locked card fires at its own clicked tile")
	_reset()
	# Cancel drops the locked aim.
	var fb3 := _staff_fireball()
	await _select_by_key(fb3)
	await _hover(aim)
	_click()
	main._on_card_confirm_cancel()
	_check(main._pending_card_aim == null and not main._card_confirm_panel.visible, "Cancel clears the locked aim")
	await _hover(elsewhere)
	_check(main.grid_manager.world_to_grid(main.aoe_indicator.position) == elsewhere, "...and the burst follows the mouse again")
	_reset()

func _t_world_map() -> void:
	print("-- Fireball on a world map --")
	main.battle_logged.connect(_on_log)
	for e in main.enemy_spawner.get_living_enemies().duplicate():
		main.enemy_spawner.despawn_enemy(e)
	_reset()
	await _close_olorin()
	var aim := _home + Vector2i(4, 2)
	var e := _spawn_at(aim)
	var played := await _play_by_input(_staff_fireball(), aim)
	_check(played and e.current_health < e.max_health and e.burn_stacks > 0,
		"Fireball plays on a world map and burns the enemy (%d HP)" % e.current_health)
	_reset()
