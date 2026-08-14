extends SceneTree

## Traps pass 1: cave spiked spiderwebs and building wall dart shooters ride
## the same trap_defs pipeline as the forest hazards; Hermes Boots' trap
## damage rider is finally consumed.
## Run: godot --headless --path . --script tests/test_interior_traps.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _make_dungeon(holder: Node3D, level: int, interior: String) -> DungeonManager:
	var gm = GridManager.new()
	holder.add_child(gm)
	var parent = Node3D.new()
	holder.add_child(parent)
	var dm = DungeonManager.new()
	holder.add_child(dm)
	dm._opened_chests_ref = {}
	dm.initialize(gm, parent, level, interior)
	return dm

func _kinds(dm: DungeonManager) -> Dictionary:
	var counts := {}
	for trap in dm.trap_defs:
		counts[trap["kind"]] = counts.get(trap["kind"], 0) + 1
	return counts

func _initialize() -> void:
	print("=== Interior traps test ===")
	var holder = Node3D.new()
	get_root().add_child(holder)

	print("-- Cave: spiked spiderwebs --")
	var cave = _make_dungeon(holder, 1, "cave_0")
	var cave_kinds = _kinds(cave)
	_check(cave_kinds.get("web", 0) >= 3, "cave lays 3+ spiked webs (found %d)" % cave_kinds.get("web", 0))
	_check(cave_kinds.size() == 1, "caves hold only webs (kinds: %s)" % str(cave_kinds.keys()))
	for trap in cave.trap_defs:
		_check(not trap["sprung"], "%s starts armed" % trap["node"].name)
		for t in trap["tiles"]:
			_check(cave.is_floor(t), "web tile %s is walkable floor" % str(t))
		break  # spot-check the first; per-tile spam not needed

	print("-- Building: wall dart shooters --")
	var house = _make_dungeon(holder, 1, "building_0")
	var house_kinds = _kinds(house)
	_check(house_kinds.get("wall_dart", 0) >= 2, "building mounts 2+ wall dart shooters (found %d)" % house_kinds.get("wall_dart", 0))
	_check(house_kinds.size() == 1, "buildings hold only wall darts (kinds: %s)" % str(house_kinds.keys()))
	for trap in house.trap_defs:
		_check(trap["tiles"].size() >= 1 and trap["tiles"].size() <= 3,
			"%s covers a 1-3 tile firing line (%d)" % [trap["node"].name, trap["tiles"].size()])
		for t in trap["tiles"]:
			_check(house.is_floor(t), "firing-line tile %s is walkable floor" % str(t))
		break

	print("-- Forest still lays its own traps --")
	var forest = _make_dungeon(holder, 1, "forest_0")
	var forest_kinds = _kinds(forest)
	_check(forest_kinds.get("bear", 0) >= 3, "forest keeps its bear traps (found %d)" % forest_kinds.get("bear", 0))
	_check(forest_kinds.get("dart", 0) >= 2, "forest keeps its dart tripwires (found %d)" % forest_kinds.get("dart", 0))
	_check(not forest_kinds.has("web") and not forest_kinds.has("wall_dart"),
		"no interior hazards leak into the forest")

	print("-- Determinism --")
	var cave2 = _make_dungeon(holder, 1, "cave_0")
	var sig_a: Array = []
	var sig_b: Array = []
	for trap in cave.trap_defs:
		sig_a.append(trap["grid_pos"])
	for trap in cave2.trap_defs:
		sig_b.append(trap["grid_pos"])
	_check(sig_a == sig_b, "web placement is deterministic per seed")

	print("-- Hermes Boots rider --")
	var hermes = ItemData.create_hermes_boots()
	_check(hermes.trap_damage_percent == 25.0, "Hermes Boots carry the +25%% trap rider")
	hermes.item_level = 2
	hermes.level_up()
	_check(hermes.trap_damage_percent == 50.0, "Lv.3 raises it to 50%%")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
