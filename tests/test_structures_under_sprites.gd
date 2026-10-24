extends SceneTree

## The player walking up to Olorin, a stall, the Town Hall or a zone's
## entrance draws over what is behind him (designer, 2026-10-24: he "folded
## underneath"). Under the near-vertical camera height decides depth, so
## every built structure stays under the sprites (CameraView.STRUCTURE_TOP)
## and the townsfolk stand on their feet at the sprite height.
## Run: godot --headless --path . --script tests/test_structures_under_sprites.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _tallest(root: Node3D) -> Array:
	var top := -INF
	var who := ""
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		if box.end.y > top:
			top = box.end.y
			who = str(mi.get_path()).get_file()
	return [top, who]

func _run() -> void:
	print("=== Structures under the sprites ===")
	var lim := CameraView.STRUCTURE_TOP + 0.005
	# Town
	var town = load("res://scenes/menus/town.tscn").instantiate()
	town.set("starting_character", CharacterData.create_stephen())
	get_root().add_child(town)
	for _i in range(4):
		await process_frame
	var roots: Array = []
	roots.append_array(town.get_node("Vendors").get_children())
	if town.get_node_or_null("TownDressing"):
		roots.append_array(town.get_node("TownDressing").get_children())
	if town._town_waypoint_node:
		roots.append(town._town_waypoint_node)
	for r in roots:
		if not (r is Node3D):
			continue
		var t: Array = _tallest(r)
		_check(t[0] <= lim or t[0] == -INF, "town %s stays under the sprites (top %.2f, %s)" % [r.name, t[0], t[1]])
	for n in ["Olorin", "Sellsword"]:
		var fig: Sprite3D = town.get_node("Vendors/%s/Figure" % n)
		_check(not fig.centered and is_equal_approx(fig.position.y, CameraView.SPRITE_LIFT),
			"%s stands on his feet at the sprite height" % n)
	town.queue_free()
	await process_frame
	# A zone's entrances
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_stephen())
	get_root().add_child(main)
	for _i in range(6):
		await process_frame
	var kinds := {}
	for site in main.dungeon_manager.site_nodes:
		var t: Array = _tallest(site["node"])
		kinds[site["kind"]] = true
		_check(t[0] <= lim, "%s entrance stays under the sprites (top %.2f, %s)" % [site["kind"], t[0], t[1]])
	_check(kinds.size() >= 3, "several kinds of entrance checked (%s)" % [kinds.keys()])
	main.queue_free()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
