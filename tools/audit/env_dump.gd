extends SceneTree

## Environment audit, step 1 (Phase 3): boot every map the player can walk —
## the overworld of each world and every site or boss door found on it,
## following doors inside interiors too — and dump, per map, what blocks
## movement and what is drawn where, as JSON for tools/audit/env_audit.py.
## Caves, ice caves and buildings are skipped (known to be old, designer
## 2026-11-07).
##
## Run: godot --headless --path . --script tools/audit/env_dump.gd -- <out_dir> [world_levels=1,2,3,4]

## (and "breach_down": Heaven's way back down is a door to World 2's Breach,
## not an interior of World 3 — the Breach is dumped with World 2; likewise
## "rent_up", the Earth's way back up to World 3's Rent.)
const SKIP_PREFIXES := ["cave", "icecave", "building", "breach_down", "rent_up"]
const CRITTER_PREFIXES := ["Butterfly", "Crow", "TrailCrow", "Squirrel", "Mouse", "LeafFall", "CloudShadows", "Feather"]

var _out := ""

func _initialize() -> void:
	_run()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://env_dump"
	DirAccess.make_dir_recursive_absolute(_out)
	var levels := [1, 2, 3, 4]
	if args.size() > 1:
		levels = []
		for s in args[1].split(","):
			levels.append(int(s))
	var queue: Array = []
	for lv in levels:
		queue.append({"level": lv, "interior": ""})
	var seen := {}
	while not queue.is_empty():
		var job: Dictionary = queue.pop_front()
		var key := "%d/%s" % [job["level"], job["interior"]]
		if seen.has(key):
			continue
		seen[key] = true
		var found: Array = await _dump_map(int(job["level"]), str(job["interior"]))
		for iid in found:
			var skip := false
			for p in SKIP_PREFIXES:
				if str(iid).begins_with(p):
					skip = true
			if not skip:
				queue.append({"level": job["level"], "interior": str(iid)})
	print("[ENV] dumped %d maps" % seen.size())
	quit()

func _settle(n: int) -> void:
	for _i in range(n):
		await process_frame

## Boot one map, write its JSON, return the interior ids its sites lead to.
func _dump_map(level: int, interior: String) -> Array:
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_world_level", level)
	main.set("current_interior_id", interior)
	get_root().add_child(main)
	await _settle(4)
	if main.olorin:
		var guard := 0
		while main.olorin.is_busy() and guard < 10:
			main.olorin._close()
			guard += 1
	await _settle(2)
	var dm = main.dungeon_manager
	var gm = main.grid_manager
	var found: Array = []
	if dm == null or gm == null:
		main.queue_free()
		await _settle(2)
		return found
	var w: int = dm.GRID_W
	var h: int = dm.GRID_H
	var blocked := {}
	for c in main._player_blocked_tiles():
		blocked[c] = true
	var cells: Array = []
	for z in range(h):
		var row := ""
		for x in range(w):
			var c := Vector2i(x, z)
			var ch := "."
			if dm.is_wall(c) and dm.is_water(c):
				ch = "L"   # an impassable pool (lava): drawn as water by the ground autotile
			elif dm.is_wall(c):
				ch = "#"
			elif dm.pit_tiles.has(c):
				ch = "P"
			elif dm.obstacle_tiles.has(c):
				ch = "O"
			elif blocked.has(c):
				ch = "B"
			elif dm.is_water(c):
				ch = "~"
			row += ch
		cells.append(row)
	var elev: Array = []
	for z in range(h):
		var r: Array = []
		for x in range(w):
			r.append(dm.get_elevation(Vector2i(x, z)))
		elev.append(r)
	var sites: Array = []
	for s in dm.site_nodes:
		var gp: Vector2i = s.get("grid_pos", Vector2i(-1, -1))
		sites.append({"id": str(s.get("id", "")), "kind": str(s.get("kind", "")), "cell": [gp.x, gp.y],
			"footprint": _cells_json(s.get("footprint", []))})
		found.append(str(s.get("id", "")))
	var poi: Array = []
	for c in dm.chest_nodes:
		poi.append({"kind": "chest", "cell": _cell_json(c.get("grid_pos", Vector2i(-1, -1)))})
	for wp in dm.waypoint_nodes:
		poi.append({"kind": "waypoint", "cell": _cell_json(wp.get("grid_pos", Vector2i(-1, -1)))})
	for f in dm.fountain_nodes:
		poi.append({"kind": "fountain", "cell": _cell_json(f.get("grid_pos", Vector2i(-1, -1)))})
	for t in dm.tree_nodes:
		poi.append({"kind": "climb_tree", "cell": _cell_json(t.get("grid_pos", Vector2i(-1, -1)))})
	var spawns: Array = []   # every enemy spawn point the map's zones hold
	for zone in dm.spawn_zones:
		if zone is Dictionary:
			for sp in zone.get("spawn_points", []):
				if sp is Vector2i:
					spawns.append([sp.x, sp.y])
				elif sp is Dictionary and sp.has("pos"):
					spawns.append(_cell_json(sp["pos"]))
	var enemies: Array = []
	for e in main.enemy_spawner.get_living_enemies():
		enemies.append({"name": e.enemy_name, "cell": _cell_json(gm.world_to_grid(e.position)), "flier": e.immune_to_high_ground})
	var visuals: Array = []
	_collect(main, gm, visuals)
	var data := {
		"level": level, "interior": interior, "kind": dm.interior_kind, "w": w, "h": h,
		"start": _cell_json(gm.world_to_grid(main.player.position)),
		"cells": cells, "elevation": elev, "cliff_faces": _cells_json(dm.cliff_face_tiles.keys()),
		"steps": _cells_json(dm.step_tiles.keys()), "sites": sites, "poi": poi, "spawn_points": spawns,
		"enemies": enemies, "visuals": visuals,
	}
	var name := "w%d_%s.json" % [level, interior if interior != "" else "overworld"]
	var f := FileAccess.open(_out.path_join(name), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	print("[ENV] %s: %dx%d, %d visuals, %d sites" % [name, w, h, visuals.size(), sites.size()])
	main.queue_free()
	await _settle(3)
	return found

func _cell_json(c) -> Array:
	return [int(c.x), int(c.y)] if c is Vector2i else [-1, -1]

func _cells_json(arr) -> Array:
	var out: Array = []
	for c in arr:
		if c is Vector2i:
			out.append([c.x, c.y])
	return out

## Every drawn thing in the world: what it is (node path, class, texture or
## mesh), how tall it stands, and the cells it covers.
func _collect(main: Node, gm, out: Array) -> void:
	var skip_roots := []
	for n in [main.get("player"), main.get_node_or_null("UI")]:
		if n:
			skip_roots.append(n)
	var stack: Array = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var skip := false
		for r in skip_roots:
			if n == r:
				skip = true
		if n is Enemy or n is CanvasLayer or n is Control:
			skip = true
		if skip:
			continue
		for c in n.get_children():
			stack.append(c)
		# Hidden nodes count too: unexplored ground hides its props under the
		# fog of war until the player comes near.
		if not (n is GeometryInstance3D):
			continue
		if n is Label3D:
			continue
		var crit := false
		for p in CRITTER_PREFIXES:
			if str(n.name).begins_with(p) or str(n.get_parent().name).begins_with(p):
				crit = true
		if crit:
			continue
		var gi: GeometryInstance3D = n
		var path := str(main.get_path_to(n))
		var res := ""
		if n is Sprite3D and n.texture:
			res = n.texture.resource_path
		elif n is MeshInstance3D and n.mesh:
			res = n.mesh.get_class()
			var mat = n.material_override
			if mat is StandardMaterial3D and mat.albedo_texture:
				res += " " + mat.albedo_texture.resource_path
		if n is MultiMeshInstance3D and n.multimesh:
			var mm: MultiMesh = n.multimesh
			var tex := ""
			var mat2 = n.material_override
			if mat2 is StandardMaterial3D and mat2.albedo_texture:
				tex = mat2.albedo_texture.resource_path
			var maabb: AABB = mm.mesh.get_aabb() if mm.mesh else AABB()
			var cells: Array = []
			for i in range(mm.instance_count):
				var t: Transform3D = n.global_transform * mm.get_instance_transform(i)
				cells.append(_cell_json(gm.world_to_grid(t.origin)))
			out.append({"path": path, "cls": "MultiMesh", "res": (mm.mesh.get_class() if mm.mesh else "") + " " + tex,
				"height": maabb.size.y, "cells": cells, "multi": true})
			continue
		var aabb: AABB = gi.get_aabb()
		var g: AABB = gi.global_transform * aabb
		var covered: Array = []
		if n is Sprite3D:
			covered.append(_cell_json(gm.world_to_grid(gi.global_position)))
		else:
			var a: Vector2i = gm.world_to_grid(Vector3(g.position.x + 0.05, 0, g.position.z + 0.05))
			var b: Vector2i = gm.world_to_grid(Vector3(g.end.x - 0.05, 0, g.end.z - 0.05))
			for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
				for z in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
					covered.append([x, z])
					if covered.size() > 400:
						break
		# A big mesh (wall atlas, cliff faces, ledges) covers the whole map
		# with its box: list instead the cells holding its raised vertices
		# (anything standing more than 0.2 above the ground under it).
		var raised: Array = []
		var painted: Array = []   # cells holding a triangle's centre (what a flat mesh paints)
		if covered.size() > 9 and n is MeshInstance3D and n.mesh is ArrayMesh:
			var seen := {}
			var seen_p := {}
			var am: ArrayMesh = n.mesh
			for si in range(am.get_surface_count()):
				var arrs: Array = am.surface_get_arrays(si)
				var verts: PackedVector3Array = arrs[Mesh.ARRAY_VERTEX]
				var idx: PackedInt32Array = arrs[Mesh.ARRAY_INDEX] if arrs[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var tri_count: int = (idx.size() if idx.size() > 0 else verts.size()) / 3
				for t in range(tri_count):
					var a: Vector3
					var b: Vector3
					var c3: Vector3
					if idx.size() > 0:
						a = verts[idx[t * 3]]; b = verts[idx[t * 3 + 1]]; c3 = verts[idx[t * 3 + 2]]
					else:
						a = verts[t * 3]; b = verts[t * 3 + 1]; c3 = verts[t * 3 + 2]
					var wv: Vector3 = gi.global_transform * ((a + b + c3) / 3.0)
					var cc: Vector2i = gm.world_to_grid(Vector3(wv.x, 0, wv.z))
					if not seen_p.has(cc):
						seen_p[cc] = true
						painted.append([cc.x, cc.y])
					if wv.y > 0.2 and not seen.has(cc):
						seen[cc] = true
						raised.append([cc.x, cc.y])
		out.append({"path": path, "cls": n.get_class(), "res": res, "height": g.size.y,
			"cells": covered, "raised": raised, "painted": painted, "multi": false})
