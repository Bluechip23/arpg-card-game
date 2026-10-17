extends SceneTree

## The designer's six fixes, through the real Main scene: waypoints are
## the ring on a dirt mound and the town portal the purple torus again; the
## top-left minimap is gone (the Tab map stays); the debuff row's badges
## open their hover window (the stat-bar container used to swallow the
## hover); explored ground survives the progression bundle, the disk and a
## restore; a town portal opened in a cave leads back into that cave; and
## Olorin's speech panel never grows past the screen, so Continue stays
## reachable.
## Run: godot --headless --path . --script tests/test_ui_fixes.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: " + msg)
	else:
		print("  FAIL: " + msg)
		failures += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("=== UI fixes test ===")
	var runner := SimRunner.new(self)
	var sc := SimScenario.with_defaults(CharacterBuilds.compose("ryan", {"build": "bruiser", "enemy": "LARGE_BEAR"}))
	await runner.boot_only(sc, 1)
	var main = runner.main
	var ui = main.get_node("UI")
	var dm = main.dungeon_manager

	# --- 1. Waypoints: the pixel rune-ring on a visible mound; the portal a torus.
	# (The sim boots in the dojo, which has no waypoints: the pieces every
	# waypoint is built from are checked, then the portal in place.)
	var ring := DungeonManager.make_waypoint_ring(Color8(0x62, 0xa3, 0xb0))
	_check(ring is Sprite3D and ring.texture != null and ring.texture.resource_path.ends_with("waypoint_ring.png")
		and ring.rotation_degrees.x == -90.0, "a waypoint is the pixel rune-ring laid flat, not the totem")
	_check(ring.modulate.a < 1.0, "dim until discovered (alpha %.2f)" % ring.modulate.a)
	var mound := DungeonManager.make_waypoint_mound(StandardMaterial3D.new())
	_check(mound.visible and mound.mesh is CylinderMesh and is_equal_approx(mound.mesh.height, DungeonManager.WAYPOINT_MOUND_HEIGHT),
		"on a visible dirt mound")
	ring.free()
	mound.free()
	var dm_probe := DungeonManager.new()
	_check(not dm_probe.has_method("make_waypoint_totem"), "the totem builder is gone")
	dm_probe.free()
	main.spawn_town_portal()
	var portal = main._town_portal_node
	var tori: Array = portal.find_children("*", "MeshInstance3D", true, false).filter(func(c): return c.mesh is TorusMesh)
	_check(tori.size() == 1 and tori[0].material_override.albedo_color.is_equal_approx(Color(0.6, 0.25, 0.95)),
		"the town portal is the purple torus")
	_check(portal.find_children("*", "Sprite3D", true, false).is_empty(), "with no totem sprite")

	# --- 2. No minimap on screen; the Tab map still draws.
	_check(ui.get_node_or_null("MinimapPanel") == null and main._minimap_panel == null, "no minimap panel in the top-left")
	main.minimap_tab_ui._update_minimap()
	main.minimap_tab_ui._refresh_expanded_map()
	_check(main._tab_map_texture_rect != null and main._tab_map_texture_rect.texture != null, "the Tab menu's World Map still has its image")
	var stat = ui.get_node_or_null("StatBarsContainer")
	_check(stat != null and stat.offset_left == 8.0 and main.debuff_bar.offset_left == 8.0,
		"the stat bars and status rows sit at the left edge")

	# --- 3. The debuff row's badges get the mouse (and open the hover window).
	var dmgr = main.player.get_debuff_manager()
	dmgr.apply_debuff(Debuff.new(Debuff.DebuffType.BURN, 3))
	main.player.get_buff_manager().apply_buff(Buff.new(Buff.BuffType.THORNS, 2, 5))
	await process_frame
	await process_frame
	for row in [[main.debuff_bar, "debuff"], [main.buff_bar, "buff"]]:
		var icons: Array = row[0].get_children().filter(func(c): return c is DebuffIconUI or c is BuffIconUI)
		_check(icons.size() >= 1, "a %s badge is in its row" % row[1])
		if icons.is_empty():
			continue
		var icon = icons[0]
		var center: Vector2 = icon.get_global_rect().get_center()
		var ev := InputEventMouseMotion.new()
		ev.position = center
		ev.global_position = center
		main.get_viewport().push_input(ev)
		await process_frame
		var hovered = main.get_viewport().gui_get_hovered_control()
		_check(hovered == icon or (hovered != null and icon.is_ancestor_of(hovered)),
			"hovering the %s badge at %s reaches it (hovered: %s)" % [row[1], str(center), str(hovered)])
		var popup = StatusHoverPopup._inst
		_check(popup != null and popup.visible and popup._anchor == icon,
			"the %s's hover window opens (%s)" % [row[1], popup._title.text if popup else "none"])
		var away := InputEventMouseMotion.new()
		away.position = Vector2(640, 400)
		away.global_position = away.position
		main.get_viewport().push_input(away)
		await process_frame

	# --- 4. Explored ground survives the bundle, the disk and a restore.
	var here: Vector2i = main.grid_manager.world_to_grid(main.player.position)
	var far := Vector2i(dm.GRID_W - 3, dm.GRID_H - 3)
	dm.reveal_around(far)
	_check(dm.is_revealed(here) and dm.is_revealed(far), "two places revealed")
	var prog: Dictionary = main._save_player_progression()
	var key: String = main._explored_key()
	var bytes: PackedByteArray = prog.get("explored", {}).get(key, PackedByteArray())
	var want_key: String = ("w%d" % main.current_world_level) if main.current_interior_id == "" \
		else "w%d/%s" % [main.current_world_level, main.current_interior_id]
	_check(key == want_key and bytes.size() == dm.GRID_W * dm.GRID_H,
		"the bundle carries this place's explored tiles under '%s' (%d bytes)" % [key, bytes.size()])
	for x in range(dm.GRID_W):
		for z in range(dm.GRID_H):
			dm._revealed[x][z] = false
	_check(not dm.is_revealed(far), "(fog put back for the test)")
	dm.restore_revealed(bytes)
	_check(dm.is_revealed(here) and dm.is_revealed(far), "restoring the bytes reveals both places again")
	var disk: Dictionary = ProgressionIO.to_disk(prog)
	var back: Dictionary = ProgressionIO.to_live(disk)
	_check(back.get("explored", {}).get(key, PackedByteArray()) == bytes, "the explored tiles round-trip through the save format")
	# Other places' ground rides along untouched when this scene snapshots.
	main.player_progression = {"explored": {"w1/cave_1": PackedByteArray([1, 0, 1])}}
	var snap: Dictionary = main._explored_snapshot()
	_check(snap.has("w1/cave_1") and snap.has(key), "the snapshot keeps every place visited (%s)" % str(snap.keys()))

	# --- 5. A portal opened in a cave leads back into the cave.
	main.current_interior_id = "cave_1"
	main.parent_interior_id = ""
	var anchor: Dictionary = main._portal_return_anchor()
	_check(anchor["interior_id"] == "cave_1" and anchor["world_level"] == main.current_world_level
		and anchor["position"] == portal.position, "the portal remembers the cave it was opened in")
	var fresh = load("res://scenes/core/main.tscn").instantiate()
	load("res://scripts/menus/town.gd").apply_portal_return(fresh, anchor)
	_check(fresh.current_interior_id == "cave_1" and fresh.current_world_level == main.current_world_level
		and fresh.portal_return_position == portal.position, "town points the way back into the cave at the portal's tile")
	fresh.free()
	main.current_interior_id = ""

	# --- 6. Olorin's lesson fits a short, wide screen; Continue stays on it.
	var root := get_root()
	var old_size: Vector2i = root.size
	root.size = Vector2i(1280, 480)
	await process_frame
	main.olorin.show_mythic_lesson()
	await process_frame
	await process_frame
	await process_frame
	var layer = main.olorin._layer
	_check(layer != null, "the Bladed Doughnut lesson opened")
	if layer != null:
		var panel: Control = null
		for c in layer.get_children():
			if c is PanelContainer:
				panel = c
		var btn: Control = panel.find_child("ContinueButton", true, false) if panel else null
		var screen: Rect2 = panel.get_viewport_rect() if panel else Rect2()
		var body: ScrollContainer = panel.find_child("Body", true, false) if panel else null
		_check(panel != null and panel.size.y <= screen.size.y,
			"the panel is no taller than the screen (%.0f of %.0f)" % [panel.size.y if panel else -1.0, screen.size.y])
		_check(btn != null and btn.get_global_rect().end.y <= screen.size.y and btn.get_global_rect().position.y >= 0.0,
			"Continue is on screen (bottom at %.0f)" % (btn.get_global_rect().end.y if btn else -1.0))
		_check(body != null and body.get_v_scroll_bar().visible, "the text scrolls instead")
		main.olorin._close()
	root.size = old_size
	runner.teardown()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
