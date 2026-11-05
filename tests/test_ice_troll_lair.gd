extends SceneTree

## The Mountain Pass's caves (designer, 2026-11-05):
##  - The Mountain Pass opens on an Ice Cave and the Ice Troll Lair, each a
##    cave mouth in a cliff; Frostreach's (World 3's) caves are Ice Caves too.
##  - The Ice Troll Lair: one den with five ice trolls and a few trash
##    enemies (snow wraiths); in its corner a vault walled by rock and ice
##    spikes with a single one-tile way in, holding a legendary chest and
##    gold lying about: the loot is taken only by walking in.
##  - Gold piles: walked onto, the gold is the hero's, and it stays taken.
## Run: godot --headless --path . --script tests/test_ice_troll_lair.gd

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
	_test_mountain_doors()
	_test_ice_cave()
	_test_frostreach_caves()
	_test_lair_layout()
	_test_gold_piles()
	await _test_in_game()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _build(interior: String, level: int = 1, state: Dictionary = {}) -> DungeonManager:
	var holder = Node3D.new()
	get_root().add_child(holder)
	var gm = GridManager.new()
	holder.add_child(gm)
	var parent = Node3D.new()
	holder.add_child(parent)
	var dm = DungeonManager.new()
	holder.add_child(dm)
	dm._opened_chests_ref = state
	dm.initialize(gm, parent, level, interior)
	return dm

func _test_mountain_doors() -> void:
	print("-- the Mountain Pass's caves --")
	var dm := _build("mountains_0")
	for id in ["icecave_0", "trolllair_0"]:
		var i := dm.get_site_by_id(id)
		_check(i >= 0, "the Mountain Pass has %s" % id)
		if i < 0:
			continue
		var c: Vector2i = dm.site_nodes[i]["grid_pos"]
		_check(dm.is_floor(c) and not dm.is_floor(c + Vector2i(0, -1)), "%s opens out of the rock behind it" % id)
		_check(dm._mountain_reach(dm.player_start).has(c), "%s can be walked to" % id)
	var lair: Vector2i = dm.site_nodes[dm.get_site_by_id("trolllair_0")]["grid_pos"]
	_check(dm.elevation[lair.x][lair.y] >= DungeonManager.MOUNTAIN_TIER_STEP * 2, "the lair is high up the mountain")

func _test_ice_cave() -> void:
	print("-- an Ice Cave --")
	var dm := _build("icecave_0")
	_check(dm.interior_kind == "icecave" and dm.get_location_name() == "Ice Cave 1", "its own kind and name")
	_check(dm.get_site_by_id("exit") >= 0, "a way back out")
	var roster := [Enemy.EnemyType.WEREGOAT, Enemy.EnemyType.SABERTOOTH, Enemy.EnemyType.SNOW_WRAITH, Enemy.EnemyType.ICE_TROLL]
	var ok := true
	var n := 0
	for z in dm.spawn_zones:
		for t in z["enemy_types"]:
			ok = ok and t in roster
			n += 1
	_check(n > 0 and ok, "the mountain's creatures live in it (%d)" % n)

func _test_frostreach_caves() -> void:
	print("-- Frostreach's caves --")
	var dm := _build("", 3)
	var caves := 0
	var icy := true
	for s in dm.site_nodes:
		if s["kind"] == "cave":
			caves += 1
			icy = icy and String(s["id"]).begins_with("icecave")
	_check(caves > 0 and icy, "World 3's caves are Ice Caves (%d)" % caves)

func _test_lair_layout() -> void:
	print("-- the Ice Troll Lair --")
	var dm := _build("trolllair_0")
	_check(dm.interior_kind == "trolllair" and dm.get_location_name() == "Ice Troll Lair", "its own kind and name")
	var vault: Rect2i = DungeonManager.TL_VAULT
	var ring := vault.grow(1)
	var gaps: Array = []
	for x in range(ring.position.x, ring.end.x):
		for z in range(ring.position.y, ring.end.y):
			var c := Vector2i(x, z)
			if vault.has_point(c):
				continue
			if dm.is_floor(c):
				gaps.append(c)
	_check(gaps.size() == 1 and gaps[0] == dm.troll_vault_entrance, "the vault's ring has one way in, one tile wide (%s)" % [gaps])
	var spikes_on_ring := true
	for c in dm.ice_wall_tiles:
		spikes_on_ring = spikes_on_ring and ring.has_point(c) and not vault.has_point(c) and not dm.is_floor(c)
	_check(dm.ice_wall_tiles.size() >= 10 and spikes_on_ring, "ice spikes wall it off (%d)" % dm.ice_wall_tiles.size())
	# In the corner of the den: the room's rock behind it, the gap opening
	# straight into the room where the trolls are.
	var room: Rect2i = DungeonManager.TL_ROOM
	_check(room.encloses(vault) and vault.end.x == room.end.x and vault.position.y == room.position.y,
		"the vault is the den's north-east corner")
	var outside: Vector2i = dm.troll_vault_entrance + Vector2i(0, 1)
	_check(room.has_point(outside) and dm.is_floor(outside), "its gap opens into the den")
	# Every vault tile is reached only through the gap.
	var seen := {dm.player_start: true}
	var q: Array = [dm.player_start]
	var through_gap := true
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if seen.has(n) or not dm.is_floor(n):
				continue
			if vault.has_point(n) and not vault.has_point(cur) and cur != dm.troll_vault_entrance:
				through_gap = false
			seen[n] = true
			q.append(n)
	_check(seen.has(dm.troll_vault_chest_cell) and through_gap, "the vault is reached, and only through its gap")
	var legendary := false
	for c in dm.chest_nodes:
		if c["grid_pos"] == dm.troll_vault_chest_cell:
			var item = c["contents"].get("item")
			legendary = c["design"] == "legendary" and item is ItemData and int(item.rarity) == ItemData.Rarity.LEGENDARY
	_check(legendary, "a legendary chest at the vault's back")
	var inside := true
	for g in dm.gold_piles:
		inside = inside and vault.has_point(g["cell"]) and int(g["amount"]) > 0
	_check(dm.gold_piles.size() >= 8 and inside, "gold lying about the vault (%d piles)" % dm.gold_piles.size())
	var trolls := 0
	var trash := 0
	for z in dm.spawn_zones:
		for t in z["enemy_types"]:
			if t == Enemy.EnemyType.ICE_TROLL:
				trolls += 1
			elif t == Enemy.EnemyType.SNOW_WRAITH:
				trash += 1
	_check(trolls == 5 and trash >= 3, "five ice trolls and a few snow wraiths (%d, %d)" % [trolls, trash])
	_check(dm.get_site_by_id("exit") >= 0, "a way back out")

func _test_gold_piles() -> void:
	print("-- gold piles --")
	var state := {}
	var dm := _build("trolllair_0", 1, state)
	var n := dm.gold_piles.size()
	var c: Vector2i = dm.gold_piles[0]["cell"]
	var amount := dm.take_gold_pile(c)
	_check(amount > 0 and dm.take_gold_pile(c) == 0 and dm.gold_piles.size() == n - 1, "taken once (%d gold), then gone" % amount)
	var again := _build("trolllair_0", 1, state)
	var still := false
	for g in again.gold_piles:
		still = still or g["cell"] == c
	_check(again.gold_piles.size() == n - 1 and not still, "and it stays taken next visit")

func _settle(frames: int = 8) -> void:
	for _i in range(frames):
		await process_frame

func _test_in_game() -> void:
	print("-- in the lair --")
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "trolllair_0")
	get_root().add_child(main)
	await _settle(20)
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	var dm: DungeonManager = main.dungeon_manager
	var stats = main.player.get_stats()
	var g: Dictionary = dm.gold_piles[0]
	var before: int = stats.gold
	main.player.position = main._ground_pos(g["cell"])
	main.player.target_position = main.player.position
	main._check_gold_pile_pickup()
	_check(stats.gold == before + int(g["amount"]), "stepping onto a gold pile picks it up (+%d)" % int(g["amount"]))
	main.player.position = main._ground_pos(Vector2i(12, DungeonManager.TL_SIZE.y / 2))
	main.player.target_position = main.player.position
	main._check_dungeon_zones()
	await _settle(4)
	var trolls := 0
	for e in main.enemy_spawner.get_living_enemies():
		if e.enemy_type == Enemy.EnemyType.ICE_TROLL:
			trolls += 1
	_check(trolls == 5, "stepping into the cavern wakes the five trolls (%d)" % trolls)
	main.queue_free()
	await _settle(2)
