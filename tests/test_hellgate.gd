extends SceneTree

## Hell's Gate — Cerberus guarding Hell's Door.
##  - Layout: a cavern hall off the first world's deepest cave, entered from
##    the west; the door set in the east wall with the hound before it; lava
##    in the corners; sealed until the door is broken.
##  - The door: 150 HP; at 75%, 50% and 33% it seals itself against all
##    damage for 10 tempo. It is Cerberus's ally.
##  - Cerberus (sheet): 250 HP / 50 armor / 25 bites, three heads below 66%
##    and 33%, Swipe (8 Bleed), Venom Tail (discard 3, 15-tempo stun, then 2
##    Vulnerable + 10 tempo Cuffed), Roar (+25 armor, +25 thorns), Guardian
##    of Death (Brace 30% x5 per drop below half within 8 squares — himself
##    once, anyone else every time), Deathyard Dog (+15 Strengthen per foe
##    heal within 5 squares).
##  - Breaking the door clears the room and opens the way down and back;
##    Cerberus need not die.
## Run: godot --headless --path . --script tests/test_hellgate.gd

var failures: int = 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	_test_layout()
	await _test_fight()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _build(interior: String, level: int = 1, cleared: Array = []) -> DungeonManager:
	var holder = Node3D.new()
	get_root().add_child(holder)
	var gm = GridManager.new()
	holder.add_child(gm)
	var parent = Node3D.new()
	holder.add_child(parent)
	var dm = DungeonManager.new()
	holder.add_child(dm)
	dm._opened_chests_ref = {}
	dm.cleared_bosses = cleared
	dm.initialize(gm, parent, level, interior)
	return dm

func _test_layout() -> void:
	print("-- Hell's Gate layout --")
	var dm := _build("hellgate")
	_check(dm.interior_kind == "hellgate" and dm.get_location_name() == "Hell's Gate", "Hell's Gate is its own interior kind")
	_check(dm.is_floor(dm.player_start) and dm.player_start.x < dm.HG_FLOOR.position.x + 2, "entered from the west")
	_check(dm.get_site_by_id("exit") < 0 and dm.get_site_by_id("descend") < 0, "sealed: no way out or down while the door stands")
	_check(dm.is_floor(dm.hellgate_door_cell) and dm.hellgate_door_cell.x == dm.HG_FLOOR.end.x - 1, "the door is set in the east wall")
	_check(dm.is_floor(dm.hellgate_cerberus_cell) and dm.hellgate_cerberus_cell.x < dm.hellgate_door_cell.x, "Cerberus stands before it")
	var lava := 0
	for x in range(dm.GRID_W):
		for z in range(dm.GRID_H):
			if dm.is_water(Vector2i(x, z)):
				lava += 1
	_check(lava > 0 and dm.water_texture_path().ends_with("water_lava.png"), "lava pools (%d tiles)" % lava)
	_check(dm.floor_texture_path().ends_with("floor_cave.png"), "dressed as the caves' threshold")
	var opened := _build("hellgate", 1, ["hellgate"])
	_check(opened.get_site_by_id("exit") >= 0 and opened.get_site_by_id("descend") >= 0, "a broken gate opens both ways from the start")
	var cave := _build("cave_0", 1)
	var idx := cave.get_site_by_id("hellgate")
	_check(idx >= 0, "the first world's cave has the door to Hell's Gate")
	if idx >= 0:
		var in_deep := false
		for room in cave.rooms:
			if room["kind"] == "deep" and (room["rect"] as Rect2i).has_point(cave.site_nodes[idx]["grid_pos"]):
				in_deep = true
		_check(in_deep, "in its deepest chamber")
	var cave3 := _build("cave_0", 3)
	_check(cave3.get_site_by_id("hellgate") < 0, "later worlds' caves do not")

func _settle(frames: int = 8) -> void:
	for _i in range(frames):
		await process_frame

func _dismiss(main) -> void:
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame

func _find_main() -> Node:
	for child in get_root().get_children():
		if child.get_script() and "current_interior_id" in child and not child.is_queued_for_deletion():
			return child
	return null

func _first(main, type: int) -> Enemy:
	for e in main.enemy_spawner.get_living_enemies():
		if e.enemy_type == type:
			return e
	return null

func _test_fight() -> void:
	print("-- Booting main.tscn as Hell's Gate --")
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "hellgate")
	get_root().add_child(main)
	await _settle()
	await _dismiss(main)
	_check(main.boss_room_mode, "the scene knows it is a boss room")
	var dog: Enemy = _first(main, Enemy.EnemyType.CERBERUS)
	var door: Enemy = _first(main, Enemy.EnemyType.HELL_DOOR)
	_check(dog != null and door != null, "Cerberus and the door are up")
	if dog == null or door == null:
		main.queue_free()
		return
	var pps: Dictionary = Enemy.passive_power_scale(10)
	_check(dog.max_health == roundi(250 * pps["hp"]) and dog.max_armor == roundi(50 * pps["hp"]) and dog.attack_damage == roundi(25 * pps["dmg"]),
		"Cerberus carries the sheet's numbers (%d HP, %d armor, %d bite)" % [dog.max_health, dog.max_armor, dog.attack_damage])
	_check(dog.damage_resistances.get(DamageTypes.Type.PHYSICAL, 0) == 30 and dog.damage_resistances.get(DamageTypes.Type.FIRE, 0) == 40 and dog.damage_resistances.get(DamageTypes.Type.LIGHTNING, 0) == 15,
		"resists 30 / 40 / 15")
	_check(door.is_structure and door.max_health == 150 and door.xp_reward == 0, "the door is a 150-HP structure worth no XP")

	var gm = main.grid_manager
	var stats = main.player.get_stats()
	stats.max_health = 500
	stats.current_health = 500
	# Stand the player beside the hound, with a hand to lose.
	var dcell: Vector2i = gm.world_to_grid(dog.position)
	main.player.position = main._ground_pos(dcell + Vector2i(-1, 0))
	main.player.target_position = main.player.position
	main.tempo_manager.add_tempo(1)  # Cerberus takes stock of everyone (Guardian watch, Deathyard ears)
	await _settle(1)
	_check(dog._brace_charges == 0, "no Brace yet")

	# --- The door seals itself ---
	door.take_damage(38, true, DamageTypes.Type.PHYSICAL, true)
	_check(door.current_health == 112 and door.door_sealed_tempo == 10, "at 75%% the door seals for 10 tempo (%d HP)" % door.current_health)
	door.take_damage(50, true, DamageTypes.Type.PHYSICAL, true)
	_check(door.current_health == 112, "sealed: the blow glances off")
	for _t in range(10):
		main.tempo_manager.add_tempo(1)
	await _settle(1)
	_check(door.door_sealed_tempo == 0, "10 tempo later the seal fades")
	door.take_damage(40, true, DamageTypes.Type.PHYSICAL, true)
	_check(door.current_health == 72 and door.door_sealed_tempo == 10, "at 50%% it seals again (%d HP)" % door.current_health)
	# The door is his ally: its drop below half feeds Guardian of Death.
	main.tempo_manager.add_tempo(1)
	await _settle(1)
	_check(dog._brace_charges == 5, "the door below half gives Cerberus Brace x5 (Guardian of Death)")
	for _t in range(10):
		main.tempo_manager.add_tempo(1)
	await _settle(1)
	door.take_damage(30, true, DamageTypes.Type.PHYSICAL, true)
	_check(door.current_health == 42 and door.door_sealed_tempo == 10, "at 33%% it seals a third time (%d HP)" % door.current_health)
	for _t in range(10):
		main.tempo_manager.add_tempo(1)
	await _settle(1)

	# --- Guardian of Death on his foes: every drop below half, if within 8 ---
	stats.current_health = 200
	main.tempo_manager.add_tempo(1)
	await _settle(1)
	_check(dog._brace_charges == 10, "the player dropping below half: Brace x10")
	stats.current_health = 260
	main.tempo_manager.add_tempo(1)
	await _settle(1)
	stats.current_health = 200
	main.tempo_manager.add_tempo(1)
	await _settle(1)
	_check(dog._brace_charges == 15, "healed above half and dropped again: Brace x15 — it counts every time")
	stats.current_health = 500
	# Out of reach it does not count.
	main.player.position = main._ground_pos(main.dungeon_manager.player_start)
	main.player.target_position = main.player.position
	main.tempo_manager.add_tempo(1)
	await _settle(1)
	stats.current_health = 200
	main.tempo_manager.add_tempo(1)
	await _settle(1)
	_check(dog._brace_charges == 15, "a drop farther than 8 squares away does not")
	stats.current_health = 500
	main.player.position = main._ground_pos(dcell + Vector2i(-1, 0))
	main.player.target_position = main.player.position
	main.tempo_manager.add_tempo(1)
	await _settle(1)
	# Brace takes 30% off a hit and spends a charge.
	var hp0: int = dog.current_health
	dog.take_damage(100, true, DamageTypes.Type.PHYSICAL, true)
	_check(hp0 - dog.current_health == 70 and dog._brace_charges == 14, "Brace: a 100 hit lands for 70 and spends a charge")
	# Himself below half: once only.
	dog.current_health = dog.max_health / 2
	dog.take_damage(1, true, DamageTypes.Type.PHYSICAL, true)
	_check(dog._brace_charges == 13 + 5, "Cerberus below half: Brace +5, once")
	var before: int = dog._brace_charges
	dog.take_damage(1, true, DamageTypes.Type.PHYSICAL, true)
	_check(dog._brace_charges == before - 1, "a second drop of his own adds nothing")
	dog._brace_charges = 0

	# --- Deathyard Dog: a foe heals within 5 squares ---
	stats.current_health = 400
	var str0: int = dog.strengthen_stacks
	stats.heal(10)
	_check(dog.strengthen_stacks == str0 + 15, "a heal within 5 squares: +15 Strengthen")
	main.player.position = main._ground_pos(main.dungeon_manager.player_start)
	main.player.target_position = main.player.position
	stats.heal(10)
	_check(dog.strengthen_stacks == str0 + 15, "a heal from across the hall does not")
	dog.strengthen_stacks = 0
	main.player.position = main._ground_pos(dcell + Vector2i(-1, 0))
	main.player.target_position = main.player.position

	# --- Roar: armor and thorns; thorns bite back at direct hits ---
	var armor0: int = dog.current_armor
	var thorns0: int = dog.enemy_thorns
	dog._try_cerberus_roar()
	_check(dog.current_armor == armor0 + 25 and dog.enemy_thorns == thorns0 + 25, "Roar: +25 armor, +25 thorns")
	stats.current_health = 500
	var thorns1: int = dog.enemy_thorns
	PlayerStats.hit_source_direct = true
	dog.take_damage(5, true, DamageTypes.Type.PHYSICAL, true)
	PlayerStats.hit_source_direct = false
	_check(stats.current_health == 500 - thorns1 and dog.enemy_thorns == thorns1 - 1, "a direct hit costs the player the thorn damage (%d) and spends a thorn" % thorns1)

	# --- Three heads ---
	stats.current_health = 500
	main.player.get_debuff_manager().clear_all_debuffs()
	dog.current_health = dog.max_health / 4  # below 33%
	var dog_hp: int = dog.current_health
	dog._try_cerberus_bite(main.player)
	var bleed = main.player.get_debuff_manager().get_debuff(Debuff.DebuffType.BLEED)
	_check(stats.current_health < 500 and bleed != null and bleed.value == 5, "below 66%% the second head bites and bleeds (5)")
	_check(dog.current_health == dog_hp + dog.attack_damage, "below 33%% the third head bites and feeds him (+%d)" % dog.attack_damage)

	# --- Venom Tail ---
	main.player.get_debuff_manager().clear_all_debuffs()
	var hand0: int = main.deck_manager.hand.size()
	dog._try_venom_tail(main.player)
	_check(main.deck_manager.hand.size() == maxi(0, hand0 - 3), "Venom Tail knocks 3 cards from the hand (%d -> %d)" % [hand0, main.deck_manager.hand.size()])
	var stun = main.player.get_debuff_manager().get_debuff(Debuff.DebuffType.STUN)
	_check(stun != null and stun.duration == 15 and dog._venom_countdown == 15, "and stuns for 15 tempo")
	# Keep the hound off the stunned player while the venom runs (his bites
	# would spend the Vulnerable before we could read it).
	dog.chosen_action = {}
	dog.rooted_tempo = 60
	main.player.position = main._ground_pos(main.dungeon_manager.player_start)
	main.player.target_position = main.player.position
	for _t in range(15):
		main.tempo_manager.add_tempo(1)
	await _settle(1)
	var vuln = main.player.get_debuff_manager().get_debuff(Debuff.DebuffType.VULNERABLE)
	var cuffed = main.player.get_debuff_manager().get_debuff(Debuff.DebuffType.CUFFED)
	_check(vuln != null and vuln.value == 2 and cuffed != null, "when it lifts: 2 Vulnerable and Cuffed")
	dog.rooted_tempo = 0

	# --- The door breaks: the way down (and back) opens; Cerberus lives on ---
	stats.current_health = 500
	door.take_damage(10000, true, DamageTypes.Type.PHYSICAL, true)
	await _settle(2)
	_check(main.dungeon_manager.get_site_by_id("descend") >= 0 and main.dungeon_manager.get_site_by_id("exit") >= 0, "breaking the door opens the way down and the way back")
	_check(main.current_character.has_defeated_boss("hellgate"), "the gate is remembered as broken")
	_check(dog.is_alive(), "Cerberus need not die")
	# Through the door: the next world.
	main.player.position = main._ground_pos(main.dungeon_manager.hellgate_door_cell)
	main.player.target_position = main.player.position
	var went: bool = main._try_interact_site()
	await _settle()
	var next = _find_main()
	_check(went and next != null and next.current_world_level == 2 and next.current_interior_id == "", "Shift at the broken door descends to the next world")
	if next:
		next.queue_free()
	await _settle()
