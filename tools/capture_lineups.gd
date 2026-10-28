extends SceneTree
## Run: MODE=heroes|enemies ROW_W=<width> OUT=<png> xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 2560x1846 --script tools/capture_lineups.gd
## (writes docs/lineups/*.png when pointed there; the margins are cropped by hand)
## Lineup sheets: every figure facing forward at its in-game size.
## MODE=heroes | enemies. OUT=<png>.

const SLOT_GAP := 0.7       # world units between figures
const ROW_GAP := 1.3        # extra space under each row for the names

func _initialize() -> void:
	_run()

func _entries() -> Array:
	var out: Array = []
	if OS.get_environment("MODE") == "heroes":
		for c in [CharacterData.create_jeremy(), CharacterData.create_cory(), CharacterData.create_ryan(), CharacterData.create_brad(), CharacterData.create_stephen()]:
			out.append({"name": c.character_name, "hero": SpriteFigure.preset_for(c), "group": "Heroes"})
		return out
	var seen := {}
	for key in Enemy.EnemyType.keys():
		var d: Dictionary = EnemyDefs.DEFS.get(key, {})
		var kind := str(d.get("figure_kind", ""))
		if kind == "" or not SpriteEnemyFigure.supports(kind):
			continue
		if key in ["MINION", "ELITE", "BOSS"] or kind == "chicken":
			continue   # the generic tiers and the dojo's chicken are not creatures of the world
		var tier := str(d.get("tier", ""))
		out.append({"name": str(d.get("name", key.capitalize())), "kind": kind,
			"group": "Bosses" if tier.to_lower().contains("boss") else "Enemies"})
	for s in [["Skeleton (summon)", "summon_skeleton"], ["Shadow Hound", "shadow_hound"], ["Battle Turtle", "battle_turtle"],
			["Seance Specter", "summon_specter"], ["Spirit", "specter"], ["Golem", "summon_golem"],
			["Frankensteins Monster", "frankenstein"], ["Wolf", "wolf"], ["Sanguine", "sanguine_penguin"], ["Bull Worm", "bull_worm"]]:
		out.append({"name": s[0], "kind": s[1], "group": "Summons"})
	var order := {"Enemies": 0, "Bosses": 1, "Summons": 2}
	var sorted_out: Array = []
	for g in ["Enemies", "Bosses", "Summons"]:
		for en in out:
			if en["group"] == g:
				sorted_out.append(en)
	return sorted_out

var _img_cache := {}

## The figure's visible width and left edge (world x), from the opaque pixels
## of the frame each sprite shows.
func _width(n: Node3D) -> Vector2:
	var lo := INF
	var hi := -INF
	for v in n.find_children("*", "Sprite3D", true, false):
		var sp := v as Sprite3D
		if not sp.is_visible_in_tree() or sp.texture == null:
			continue
		var key := sp.texture.get_rid()
		if not _img_cache.has(key):
			var img := sp.texture.get_image()
			if img and img.is_compressed():
				img.decompress()
			_img_cache[key] = img
		var img: Image = _img_cache[key]
		if img == null:
			continue
		var r: Rect2 = sp.region_rect if sp.region_enabled else Rect2(Vector2.ZERO, img.get_size())
		var sub := img.get_region(Rect2i(r))
		var used := sub.get_used_rect()
		if used.size.x <= 0:
			continue
		var item: Rect2 = sp.get_item_rect()
		var sc: float = sp.global_transform.basis.get_scale().x
		var c0: float = used.position.x
		var c1: float = used.position.x + used.size.x
		if sp.flip_h:
			var w0 := r.size.x - c1
			c1 = r.size.x - c0
			c0 = w0
		var gx: float = sp.global_position.x
		lo = minf(lo, gx + (item.position.x + c0) * sp.pixel_size * sc)
		hi = maxf(hi, gx + (item.position.x + c1) * sp.pixel_size * sc)
	if lo == INF:
		return Vector2(1.0, n.global_position.x - 0.5)
	return Vector2(hi - lo, lo)

func _run() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.09, 0.11, 0.10)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.9
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -30, 0)
	sun.light_energy = 0.6
	root.add_child(sun)
	var entries := _entries()
	var max_w: float = float(OS.get_environment("ROW_W")) if OS.get_environment("ROW_W") != "" else 40.0
	var x := 0.6
	var z := 0.0
	var row_h := 0.0
	var group := ""
	var placed := []
	for en in entries:
		var fig: Node3D
		if en.has("hero"):
			var sf := SpriteFigure.new()
			root.add_child(sf)
			sf.setup(en["hero"])
			sf.set_facing(CharacterAnimator.Direction.SOUTH)
			fig = sf
		else:
			var ef := SpriteEnemyFigure.new()
			root.add_child(ef)
			ef.setup(en["kind"])
			ef.set_facing(CharacterAnimator.Direction.SOUTH)
			fig = ef
		placed.append([fig, en])
	await process_frame
	await process_frame
	var heights := []
	for pe in placed:
		var fig: Node3D = pe[0]
		var en: Dictionary = pe[1]
		var wl: Vector2 = _width(fig)
		var w: float = maxf(wl.x, 0.32 * en["name"].length() * 0.55 + 0.4)
		if en["group"] != group or x + w > max_w:
			if x > 0.6:
				z += ROW_GAP + row_h
			x = 0.6
			row_h = 2.6
			if en["group"] != group:
				group = en["group"]
				var gl := Label3D.new()
				gl.text = group
				gl.font_size = 96
				gl.pixel_size = 0.004
				gl.modulate = Color(1.0, 0.86, 0.45)
				gl.outline_size = 0
				gl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				root.add_child(gl)
				gl.position = Vector3(0.6, 0.0, z + 0.3)
				z += 1.0
		fig.position = Vector3(x + (fig.global_position.x - wl.y), 0, z + row_h)
		var lbl := Label3D.new()
		lbl.text = en["name"]
		lbl.font_size = 64
		lbl.pixel_size = 0.004
		lbl.modulate = Color(0.86, 0.95, 0.89)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		root.add_child(lbl)
		lbl.position = Vector3(x + w * 0.5, 0.0, z + row_h + 0.35)
		x += w + SLOT_GAP
	var total_w := max_w
	var total_h := z + row_h + ROW_GAP + 1.0
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var vp := get_root().get_visible_rect().size
	var focus := Vector3(total_w * 0.5, 0, total_h * 0.5 - 0.6)
	cam.look_at_from_position(focus + CameraView.offset(), focus, Vector3(0, 0, -1))
	cam.size = maxf(total_h * CameraView.ground_foreshortening() + 1.0, total_w * vp.y / vp.x + 0.5)
	cam.far = 200
	cam.current = true
	for _i in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OS.get_environment("OUT"))
	print("LINEUP %d figures, %.1f x %.1f" % [placed.size(), total_w, total_h])
	quit()
