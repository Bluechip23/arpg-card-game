class_name CharacterFigure
extends Node3D

## A simple procedural 3D character built from primitive meshes.
##
## Gives a chunky, pre-rendered "SNES RPG" look (think Super Mario RPG): a
## big-headed chibi figure assembled from boxes and spheres, lit and shaded in 3D.
## The same figure is used on the character-selection cards (inside a SubViewport)
## and as the in-battle player.
##
## Appearance is grounded in each character's 2D sprite: the body colours are
## SAMPLED at runtime from the matching res://assets/characters/<name>_south.png,
## and a per-character "signature" feature is added on top (Cory's wizard hat,
## Brad's helmet, Jeremy's staff, Stephen's suit shirt, ...). So the 3D model
## actually resembles the pixel art instead of being generic.
##
## Animations are procedural (Tweens on the joint nodes) so the rig stays open for
## future spell / attack / defense moves: add a play_* method and route it through
## play_action().

# Joint nodes (populated in _build)
var _pivot: Node3D = null
var _body: Node3D = null
var _left_shoulder: Node3D = null
var _right_shoulder: Node3D = null
var _shield_anchor: Node3D = null

# Part references that features may hide/recolour
var _head: MeshInstance3D = null
var _hair: MeshInstance3D = null
var _eye_l: MeshInstance3D = null
var _eye_r: MeshInstance3D = null
var _feature_nodes: Array[Node3D] = []

var _char_name: String = "Default"
var _sprite_path: String = ""
var _built: bool = false
var _busy: bool = false
var _walking: bool = false
var _time: float = 0.0
var _action_tween: Tween = null

const REST := Vector3.ZERO


func _ready() -> void:
	_build()


func setup(character_name: String, sprite_path: String = "") -> void:
	## Sets the character whose palette/features to use. `sprite_path` is the 2D
	## sprite the colours are sampled from. Safe to call before or after _build.
	_char_name = character_name
	_sprite_path = sprite_path
	if _built:
		_apply_appearance()


# =============================================================
# BUILD (geometry only — appearance applied separately)
# =============================================================

func _build() -> void:
	if _built:
		return

	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)

	# Contact shadow (flat dark disc on the floor)
	var shadow := MeshInstance3D.new()
	shadow.name = "Shadow"
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = 0.32
	shadow_mesh.bottom_radius = 0.32
	shadow_mesh.height = 0.01
	shadow_mesh.radial_segments = 16
	shadow.mesh = shadow_mesh
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.28)
	shadow.material_override = shadow_mat
	shadow.position = Vector3(0, 0.006, 0)
	_pivot.add_child(shadow)

	# Body holds everything that bobs / leans
	_body = Node3D.new()
	_body.name = "Body"
	_pivot.add_child(_body)

	# Legs / feet
	_body.add_child(_make_box("LeftLeg", Vector3(-0.11, 0.21, 0), Vector3(0.15, 0.42, 0.15), "pants"))
	_body.add_child(_make_box("RightLeg", Vector3(0.11, 0.21, 0), Vector3(0.15, 0.42, 0.15), "pants"))
	_body.add_child(_make_box("LeftFoot", Vector3(-0.11, 0.05, 0.04), Vector3(0.17, 0.1, 0.22), "accent"))
	_body.add_child(_make_box("RightFoot", Vector3(0.11, 0.05, 0.04), Vector3(0.17, 0.1, 0.22), "accent"))

	# Torso
	_body.add_child(_make_box("Torso", Vector3(0, 0.66, 0), Vector3(0.42, 0.46, 0.26), "shirt"))

	# Head
	_head = MeshInstance3D.new()
	_head.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.2
	head_mesh.height = 0.4
	_head.mesh = head_mesh
	_head.position = Vector3(0, 1.05, 0)
	_head.set_meta("palette_role", "skin")
	_body.add_child(_head)

	# Hair
	_hair = MeshInstance3D.new()
	_hair.name = "Hair"
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.205
	hair_mesh.height = 0.41
	_hair.mesh = hair_mesh
	_hair.position = Vector3(0, 1.12, 0)
	_hair.scale = Vector3(1.02, 0.62, 1.02)
	_hair.set_meta("palette_role", "hair")
	_body.add_child(_hair)

	# Eyes
	_eye_l = _make_eye("EyeL", Vector3(-0.07, 1.06, 0.185))
	_eye_r = _make_eye("EyeR", Vector3(0.07, 1.06, 0.185))
	_body.add_child(_eye_l)
	_body.add_child(_eye_r)

	# Shoulders + arms (arm meshes hang below the shoulder joint so rotating the
	# joint swings the arm)
	_left_shoulder = Node3D.new()
	_left_shoulder.name = "LeftShoulder"
	_left_shoulder.position = Vector3(-0.27, 0.82, 0)
	_body.add_child(_left_shoulder)
	_left_shoulder.add_child(_make_box("LeftArm", Vector3(0, -0.2, 0), Vector3(0.13, 0.4, 0.13), "skin"))

	_right_shoulder = Node3D.new()
	_right_shoulder.name = "RightShoulder"
	_right_shoulder.position = Vector3(0.27, 0.82, 0)
	_body.add_child(_right_shoulder)
	_right_shoulder.add_child(_make_box("RightArm", Vector3(0, -0.2, 0), Vector3(0.13, 0.4, 0.13), "skin"))

	# Shield icon anchor (above the head)
	_shield_anchor = Node3D.new()
	_shield_anchor.name = "ShieldAnchor"
	_shield_anchor.position = Vector3(0, 1.5, 0)
	_pivot.add_child(_shield_anchor)

	_built = true
	_apply_appearance()


func _make_box(node_name: String, pos: Vector3, size: Vector3, role: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.set_meta("palette_role", role)
	return mi


func _make_eye(node_name: String, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var s := SphereMesh.new()
	s.radius = 0.032
	s.height = 0.064
	mi.mesh = s
	mi.position = pos
	mi.material_override = _solid(Color(0.08, 0.07, 0.1))
	return mi


# =============================================================
# APPEARANCE: palette (sampled from sprite) + signature features
# =============================================================

func _apply_appearance() -> void:
	var pal := _resolve_palette()
	_paint(_body, pal)
	_build_features(pal)


func _paint(node: Node, pal: Dictionary) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.has_meta("palette_role"):
			var role: String = child.get_meta("palette_role")
			if pal.has(role):
				child.material_override = _solid(pal[role])
		_paint(child, pal)


func _solid(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.0
	mat.roughness = 0.6
	return mat


## Returns {skin, hair, shirt, pants, accent}. Sampled from the sprite when
## available; otherwise a hand-picked palette derived from that sprite's art.
func _resolve_palette() -> Dictionary:
	var pal := _sample_palette(_sprite_path)
	var fallback := _fallback_palette(_char_name)
	# Merge: prefer sampled values, fill any gaps from the fallback.
	for k in fallback:
		if not pal.has(k):
			pal[k] = fallback[k]
	return pal


func _sample_palette(path: String) -> Dictionary:
	if path == "" or not ResourceLoader.exists(path):
		return {}
	var tex := load(path) as Texture2D
	if tex == null:
		return {}
	var img := tex.get_image()
	if img == null:
		return {}
	if img.is_compressed():
		img.decompress()
	var rect := img.get_used_rect()
	if rect.size.x <= 1 or rect.size.y <= 1:
		return {}
	var pal := {}
	var hair := _dominant_fill(img, rect, 0.0, 0.30)
	var shirt := _dominant_fill(img, rect, 0.40, 0.66)
	var pants := _dominant_fill(img, rect, 0.68, 1.0)
	if hair.a > 0.0:
		pal["hair"] = hair
	if shirt.a > 0.0:
		pal["shirt"] = shirt
		pal["accent"] = shirt.lightened(0.18)
	if pants.a > 0.0:
		pal["pants"] = pants
	var skin := _skin_tone(img, rect)
	if skin.a > 0.0:
		pal["skin"] = skin
	return pal


## Dominant non-outline fill colour within a vertical band [t0,t1] of the sprite.
func _dominant_fill(img: Image, rect: Rect2i, t0: float, t1: float) -> Color:
	var counts := {}
	var y0 := rect.position.y + int(rect.size.y * t0)
	var y1 := rect.position.y + int(rect.size.y * t1)
	for y in range(y0, y1):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var col := img.get_pixel(x, y)
			if col.a < 0.5:
				continue
			if maxf(col.r, maxf(col.g, col.b)) < 0.16:  # skip black outline / deep shadow
				continue
			var key := "%d,%d,%d" % [int(col.r * 7), int(col.g * 7), int(col.b * 7)]
			if not counts.has(key):
				counts[key] = {"sum": Color(0, 0, 0, 0), "n": 0}
			counts[key]["sum"] += col
			counts[key]["n"] += 1
	var best := Color(0, 0, 0, 0)
	var bestn := 0
	for k in counts:
		if counts[k]["n"] > bestn:
			bestn = counts[k]["n"]
			best = counts[k]["sum"] / float(counts[k]["n"])
	if bestn > 0:
		best.a = 1.0
	return best


## Most common warm mid-tone (skin-ish) pixel; transparent if none found.
func _skin_tone(img: Image, rect: Rect2i) -> Color:
	var counts := {}
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var col := img.get_pixel(x, y)
			if col.a < 0.5:
				continue
			# warm, bright-ish, not washed-out white
			if col.r > 0.55 and col.r >= col.g and col.g >= col.b and (col.r - col.b) > 0.12 and col.b < 0.8:
				var key := "%d,%d,%d" % [int(col.r * 7), int(col.g * 7), int(col.b * 7)]
				if not counts.has(key):
					counts[key] = {"sum": Color(0, 0, 0, 0), "n": 0}
				counts[key]["sum"] += col
				counts[key]["n"] += 1
	var best := Color(0, 0, 0, 0)
	var bestn := 0
	for k in counts:
		if counts[k]["n"] > bestn:
			bestn = counts[k]["n"]
			best = counts[k]["sum"] / float(counts[k]["n"])
	if bestn > 0:
		best.a = 1.0
	return best


func _fallback_palette(character_name: String) -> Dictionary:
	# Hand-picked from each sprite's sampled colours (used if sampling is
	# unavailable, and to fill in skin where the face is hidden by headgear).
	match character_name:
		"Ryan":
			return {"skin": Color.html("e8b89a"), "hair": Color.html("3e3b4a"),
					"shirt": Color.html("2c2935"), "pants": Color.html("232029"),
					"accent": Color.html("b9d4e8")}
		"Jeremy":
			return {"skin": Color.html("f0a98c"), "hair": Color.html("5b3433"),
					"shirt": Color.html("1f765c"), "pants": Color.html("195e49"),
					"accent": Color.html("2f8f70")}
		"Stephen":
			return {"skin": Color.html("f0a98c"), "hair": Color.html("412428"),
					"shirt": Color.html("06448a"), "pants": Color.html("06356d"),
					"accent": Color.html("c8742a")}
		"Cory":
			return {"skin": Color.html("e8b89a"), "hair": Color.html("2a1550"),
					"shirt": Color.html("331666"), "pants": Color.html("2a1255"),
					"accent": Color.html("4b298d")}
		"Brad":
			return {"skin": Color.html("c2c8da"), "hair": Color.html("2d2d60"),
					"shirt": Color.html("2d2d60"), "pants": Color.html("201e51"),
					"accent": Color.html("3d3f78")}
		_:
			return {"skin": Color.html("f0c8a0"), "hair": Color.html("59442d"),
					"shirt": Color.html("66728c"), "pants": Color.html("404659"),
					"accent": Color.html("9aa0ad")}


func _features_for(character_name: String) -> Dictionary:
	match character_name:
		"Cory":    return {"headgear": "wizard_hat", "staff": true}
		"Brad":    return {"headgear": "helmet"}
		"Jeremy":  return {"staff": true}
		"Stephen": return {"chest": true}
		_:         return {}


func _build_features(pal: Dictionary) -> void:
	# Clear previously-built feature geometry (re-setup safe)
	for n in _feature_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_feature_nodes.clear()

	# Default: hair + eyes visible
	_hair.visible = true
	_eye_l.visible = true
	_eye_r.visible = true

	var feats := _features_for(_char_name)
	var headgear: String = feats.get("headgear", "none")
	var hat_col: Color = pal.get("hair", Color.html("4b298d"))

	match headgear:
		"wizard_hat":
			_hair.visible = false
			# Brim
			_add_feature(_make_cyl("HatBrim", Vector3(0, 1.24, 0), 0.36, 0.36, 0.05, hat_col))
			# Pointed cone
			_add_feature(_make_cyl("HatCone", Vector3(0, 1.48, 0), 0.0, 0.2, 0.46, hat_col))
		"helmet":
			_hair.visible = false
			_eye_l.visible = false
			_eye_r.visible = false
			var helm := _make_sphere("Helmet", Vector3(0, 1.06, 0), 0.225, hat_col)
			helm.scale = Vector3(1.04, 1.08, 1.04)
			_add_feature(helm)
			# Dark visor slit across the front
			_add_feature(_make_box_solid("Visor", Vector3(0, 1.05, 0.2), Vector3(0.27, 0.04, 0.05), Color.html("0e0f16")))

	if feats.get("staff", false):
		var wood := Color.html("5a3d22")
		var staff := _make_cyl("Staff", Vector3(-0.36, 0.62, 0.06), 0.03, 0.03, 1.2, wood)
		staff.rotation_degrees = Vector3(0, 0, 7)
		_add_feature(staff)
		# A small orb/knob on top, tinted by the character's accent
		_add_feature(_make_sphere("StaffTop", Vector3(-0.43, 1.2, 0.06), 0.06, pal.get("accent", wood)))

	if feats.get("chest", false):
		# A vertical strip of the accent colour (e.g. Stephen's shirt under the jacket)
		_add_feature(_make_box_solid("Shirt", Vector3(0, 0.7, 0.125), Vector3(0.12, 0.34, 0.03), pal.get("accent", Color.html("c8742a"))))


func _add_feature(mi: MeshInstance3D) -> void:
	_body.add_child(mi)
	_feature_nodes.append(mi)


func _make_cyl(node_name: String, pos: Vector3, top_r: float, bot_r: float, height: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var m := CylinderMesh.new()
	m.top_radius = top_r
	m.bottom_radius = bot_r
	m.height = height
	m.radial_segments = 12
	mi.mesh = m
	mi.position = pos
	mi.material_override = _solid(col)
	return mi


func _make_sphere(node_name: String, pos: Vector3, radius: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	mi.mesh = s
	mi.position = pos
	mi.material_override = _solid(col)
	return mi


func _make_box_solid(node_name: String, pos: Vector3, size: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = _solid(col)
	return mi


# =============================================================
# IDLE (per-frame)
# =============================================================

func _process(delta: float) -> void:
	if not _built or _busy:
		return
	_time += delta
	var freq := 4.0 if _walking else 1.6
	var amp := 0.035 if _walking else 0.02
	_body.position.y = sin(_time * freq) * amp
	_body.rotation_degrees.z = sin(_time * 1.3) * (2.5 if _walking else 1.0)


# =============================================================
# PUBLIC ANIMATION API
# =============================================================

## Generic entry point. `direction` uses CharacterAnimator.Direction values.
func play_action(action: String, direction: int = CharacterAnimator.Direction.SOUTH) -> void:
	if not _built:
		return
	set_facing(direction)
	match action:
		"attack_slash", "attack_heavy", "attack_ranged", "attack_charged_1", "attack_circling", "attack":
			play_attack()
		"block", "defend":
			play_defend()
		"dodge":
			play_dodge()
		"hit", "hit_heavy", "stunned":
			play_hit()
		_:
			# Extension point for future spell / cast / channel actions.
			play_idle()


func play_idle() -> void:
	_cancel_action()
	_reset_pose()
	_busy = false


## Basic attack: wind the (right) arm up, then chop it straight down — a slash.
func play_attack() -> void:
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees:x", -150.0, 0.14).set_ease(Tween.EASE_OUT)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", -9.0, 0.14)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees:x", -40.0, 0.07).set_ease(Tween.EASE_IN)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 12.0, 0.07)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees:x", 0.0, 0.22).set_ease(Tween.EASE_OUT)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 0.0, 0.22)
	_action_tween.tween_callback(_on_action_done)


## Defend: pound a fist twice against the chest while a grey shield pops up
## over the head and slowly fades.
func play_defend() -> void:
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_spawn_shield()
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-95, 0, 38), 0.12).set_ease(Tween.EASE_OUT)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 6.0, 0.12)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees:x", -76.0, 0.08)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees:x", -95.0, 0.07)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees:x", -76.0, 0.08)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees:x", -95.0, 0.07)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", REST, 0.2).set_ease(Tween.EASE_OUT)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 0.0, 0.2)
	_action_tween.tween_callback(_on_action_done)


## Quick sidestep — handy later for evasion / reaction cards.
func play_dodge() -> void:
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_action_tween.tween_property(_body, "position:x", 0.16, 0.1)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:z", -14.0, 0.1)
	_action_tween.tween_property(_body, "position:x", 0.0, 0.2)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:z", 0.0, 0.2)
	_action_tween.tween_callback(_on_action_done)


## Flinch backward — used when the player is struck.
func play_hit() -> void:
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_action_tween.tween_property(_body, "rotation_degrees:x", -18.0, 0.08).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "rotation_degrees:x", 0.0, 0.25).set_ease(Tween.EASE_OUT)
	_action_tween.tween_callback(_on_action_done)


# =============================================================
# FACING / WALK
# =============================================================

func set_facing(direction: int) -> void:
	if not _built:
		return
	match direction:
		CharacterAnimator.Direction.SOUTH:
			_pivot.rotation_degrees.y = 0.0
		CharacterAnimator.Direction.NORTH:
			_pivot.rotation_degrees.y = 180.0
		CharacterAnimator.Direction.EAST:
			_pivot.rotation_degrees.y = -90.0
		CharacterAnimator.Direction.WEST:
			_pivot.rotation_degrees.y = 90.0


func set_facing_from_velocity(vel: Vector3) -> void:
	if vel.length_squared() < 0.01:
		return
	if abs(vel.x) > abs(vel.z):
		set_facing(CharacterAnimator.Direction.EAST if vel.x > 0 else CharacterAnimator.Direction.WEST)
	else:
		set_facing(CharacterAnimator.Direction.SOUTH if vel.z > 0 else CharacterAnimator.Direction.NORTH)


func set_walking(walking: bool) -> void:
	_walking = walking


# =============================================================
# SHIELD ICON
# =============================================================

func _spawn_shield() -> void:
	var shield := Sprite3D.new()
	shield.texture = _make_shield_texture()
	shield.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shield.shaded = false
	shield.no_depth_test = true
	shield.render_priority = 40
	shield.pixel_size = 0.006
	shield.scale = Vector3.ZERO
	_shield_anchor.add_child(shield)

	var tw := shield.create_tween()
	tw.tween_property(shield, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_property(shield, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(shield, "position:y", 0.25, 1.0)
	tw.tween_callback(shield.queue_free)


func _make_shield_texture() -> ImageTexture:
	# Classic heraldic shield: flat top, sides curving to a point. Grey with a
	# darker rim and a centre rib.
	var w := 48
	var h := 56
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var fill := Color(0.64, 0.66, 0.72)
	var rim := Color(0.30, 0.32, 0.38)
	var rib := Color(0.50, 0.52, 0.58)

	for y in range(h):
		var t := float(y) / float(h - 1)
		var hw := 1.0
		if t > 0.45:
			var k := (t - 0.45) / 0.55
			hw = 1.0 - k * k
		hw = clamp(hw, 0.0, 1.0)
		for x in range(w):
			var u := (float(x) / float(w - 1)) * 2.0 - 1.0
			var au := absf(u)
			if au > hw:
				continue
			var col := fill
			if au > hw - 0.16 or t > 0.9:
				col = rim
			elif au < 0.08:
				col = rib
			img.set_pixel(x, y, col)

	return ImageTexture.create_from_image(img)


# =============================================================
# INTERNAL
# =============================================================

func _on_action_done() -> void:
	_busy = false


func _cancel_action() -> void:
	if _action_tween and _action_tween.is_valid():
		_action_tween.kill()
	_action_tween = null


func _reset_pose() -> void:
	if not _built:
		return
	_left_shoulder.rotation_degrees = REST
	_right_shoulder.rotation_degrees = REST
	_body.rotation_degrees = Vector3.ZERO
	_body.position.x = 0.0
