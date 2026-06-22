class_name CharacterFigure
extends Node3D

## A procedural 3D character built from primitive meshes — a chunky, pre-rendered
## "SNES RPG" look (think Super Mario RPG). Used on the character-selection cards
## (inside a SubViewport) and as the in-battle player.
##
## Appearance is grounded in each character's 2D sprite: body colours are SAMPLED
## at runtime from res://assets/characters/<name>_south.png, and a per-character
## "detail spec" adds the things that make each sprite recognisable — long hair,
## bare/white sleeves, belts, boots, a wizard hat, a helmet, and a held weapon
## (Ryan's daggers, Stephen's mace, Jeremy/Cory's staff, Brad's shield).
##
## Animations are procedural (Tweens on the joint nodes), so the rig stays open
## for future moves: add a play_* method and route it through play_action().

# Joint nodes
var _pivot: Node3D = null
var _body: Node3D = null
var _left_shoulder: Node3D = null
var _right_shoulder: Node3D = null
var _left_hand: Node3D = null   # Anchor at the end of the left arm for held props
var _right_hand: Node3D = null  # Anchor at the end of the right arm for held props
var _shield_anchor: Node3D = null
var _shield_grip: Node3D = null  # Holds the shield meshes (Brad); rest pose at REST

# Part references the detail pass recolours / toggles
var _head: MeshInstance3D = null
var _hair: MeshInstance3D = null
var _eye_l: MeshInstance3D = null
var _eye_r: MeshInstance3D = null
var _left_arm: MeshInstance3D = null
var _right_arm: MeshInstance3D = null
var _left_foot: MeshInstance3D = null
var _right_foot: MeshInstance3D = null
var _feature_nodes: Array[Node3D] = []

var _char_name: String = "Default"
var _sprite_path: String = ""
var _built: bool = false
var _busy: bool = false
var _walking: bool = false
var _time: float = 0.0
var _action_tween: Tween = null
var _temp_props: Array[Node3D] = []  # Held props (beakers, pouches) freed on the next action
var _stance: String = "none"  # "approach" holds a guard stance until another action plays
var _has_shield: bool = false

const REST := Vector3.ZERO
const STANCE_APPROACH_Y := -0.12  # Body drop while holding the Approach guard crouch


func _ready() -> void:
	_build()


func setup(character_name: String, sprite_path: String = "") -> void:
	_char_name = character_name
	_sprite_path = sprite_path
	if _built:
		_apply_appearance()


# =============================================================
# BUILD (geometry only)
# =============================================================

func _build() -> void:
	if _built:
		return

	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)

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

	_body = Node3D.new()
	_body.name = "Body"
	_pivot.add_child(_body)

	# Legs
	_body.add_child(_make_box("LeftLeg", Vector3(-0.11, 0.21, 0), Vector3(0.15, 0.42, 0.15), "pants"))
	_body.add_child(_make_box("RightLeg", Vector3(0.11, 0.21, 0), Vector3(0.15, 0.42, 0.15), "pants"))
	# Feet / boots (recoloured in the detail pass)
	_left_foot = _make_box("LeftFoot", Vector3(-0.11, 0.05, 0.04), Vector3(0.17, 0.12, 0.22), "")
	_right_foot = _make_box("RightFoot", Vector3(0.11, 0.05, 0.04), Vector3(0.17, 0.12, 0.22), "")
	_body.add_child(_left_foot)
	_body.add_child(_right_foot)

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

	# Hair (short cap by default; long hair added in the detail pass)
	_hair = MeshInstance3D.new()
	_hair.name = "Hair"
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.207
	hair_mesh.height = 0.41
	_hair.mesh = hair_mesh
	_hair.position = Vector3(0, 1.12, 0)
	_hair.scale = Vector3(1.02, 0.66, 1.02)
	_hair.set_meta("palette_role", "hair")
	_body.add_child(_hair)

	# Eyes
	_eye_l = _make_eye("EyeL", Vector3(-0.075, 1.05, 0.185))
	_eye_r = _make_eye("EyeR", Vector3(0.075, 1.05, 0.185))
	_body.add_child(_eye_l)
	_body.add_child(_eye_r)

	# Shoulders + arms
	_left_shoulder = Node3D.new()
	_left_shoulder.name = "LeftShoulder"
	_left_shoulder.position = Vector3(-0.27, 0.82, 0)
	_body.add_child(_left_shoulder)
	_left_arm = _make_box("LeftArm", Vector3(0, -0.2, 0), Vector3(0.13, 0.4, 0.13), "")
	_left_shoulder.add_child(_left_arm)
	# Hand anchor at the end of the arm — props (beakers, syringes, pouches) parent
	# here so they sit in the hand and follow the arm during animations.
	_left_hand = Node3D.new()
	_left_hand.name = "LeftHand"
	_left_hand.position = Vector3(0, -0.22, 0)
	_left_arm.add_child(_left_hand)

	_right_shoulder = Node3D.new()
	_right_shoulder.name = "RightShoulder"
	_right_shoulder.position = Vector3(0.27, 0.82, 0)
	_body.add_child(_right_shoulder)
	_right_arm = _make_box("RightArm", Vector3(0, -0.2, 0), Vector3(0.13, 0.4, 0.13), "")
	_right_shoulder.add_child(_right_arm)
	_right_hand = Node3D.new()
	_right_hand.name = "RightHand"
	_right_hand.position = Vector3(0, -0.22, 0)
	_right_arm.add_child(_right_hand)

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
	if role != "":
		mi.set_meta("palette_role", role)
	return mi


func _make_eye(node_name: String, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var s := SphereMesh.new()
	s.radius = 0.034
	s.height = 0.068
	mi.mesh = s
	mi.position = pos
	mi.material_override = _solid(Color(0.08, 0.07, 0.1))
	return mi


# =============================================================
# APPEARANCE
# =============================================================

func _apply_appearance() -> void:
	var pal := _resolve_palette()
	var spec := _spec_for(_char_name)
	if spec.has("hair_color"):
		pal["hair"] = spec["hair_color"]
	_paint(_body, pal)
	_build_details(pal, spec)


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


# ---- palette sampled from the sprite -------------------------------------

func _resolve_palette() -> Dictionary:
	var pal := _sample_palette(_sprite_path)
	var fallback := _fallback_palette(_char_name)
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
	var hair := _dominant_fill(img, rect, 0.0, 0.28)
	var shirt := _dominant_fill(img, rect, 0.40, 0.60)
	var pants := _dominant_fill(img, rect, 0.70, 0.90)
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


func _dominant_fill(img: Image, rect: Rect2i, t0: float, t1: float) -> Color:
	var counts := {}
	var y0 := rect.position.y + int(rect.size.y * t0)
	var y1 := rect.position.y + int(rect.size.y * t1)
	for y in range(y0, y1):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var col := img.get_pixel(x, y)
			if col.a < 0.5:
				continue
			if maxf(col.r, maxf(col.g, col.b)) < 0.16:
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


func _skin_tone(img: Image, rect: Rect2i) -> Color:
	var counts := {}
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var col := img.get_pixel(x, y)
			if col.a < 0.5:
				continue
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
	match character_name:
		"Ryan":
			return {"skin": Color.html("f0b29e"), "hair": Color.html("141019"),
					"shirt": Color.html("2c2935"), "pants": Color.html("242129"), "accent": Color.html("3e3b4a")}
		"Jeremy":
			return {"skin": Color.html("faae92"), "hair": Color.html("5b3433"),
					"shirt": Color.html("1f775d"), "pants": Color.html("1f775d"), "accent": Color.html("2f8f70")}
		"Stephen":
			return {"skin": Color.html("fab19c"), "hair": Color.html("412428"),
					"shirt": Color.html("06448a"), "pants": Color.html("06356d"), "accent": Color.html("3a6fbf")}
		"Cory":
			return {"skin": Color.html("f0c4b4"), "hair": Color.html("4b298d"),
					"shirt": Color.html("3a1d70"), "pants": Color.html("321665"), "accent": Color.html("5a2fa0")}
		"Brad":
			return {"skin": Color.html("c2c8da"), "hair": Color.html("303061"),
					"shirt": Color.html("262450"), "pants": Color.html("201e51"), "accent": Color.html("3c3d76")}
		_:
			return {"skin": Color.html("f0c8a0"), "hair": Color.html("59442d"),
					"shirt": Color.html("66728c"), "pants": Color.html("404659"), "accent": Color.html("9aa0ad")}


# ---- per-character structural detail --------------------------------------

func _spec_for(character_name: String) -> Dictionary:
	match character_name:
		"Ryan":
			return {"hair": "long", "hair_color": Color.html("0b0a10"), "eyes": Color.html("5a9bd8"),
					"sleeves": "shirt", "belt": Color.html("aacce6"), "boots": Color.html("242129"),
					"weapon": "daggers", "weapon_col": Color.html("cbe0f1")}
		"Jeremy":
			return {"hair": "short", "sleeves": "skin",
					"belt": Color.html("5b3433"), "boots": "skin",
					"weapon": "staff", "weapon_col": Color.html("6b4a2a")}
		"Stephen":
			return {"hair": "short", "sleeves": Color.html("e6e6ea"),
					"belt": Color.html("d8a838"), "boots": Color.html("3a2420"),
					"straps": Color.html("6b4a2a"), "quiver": true,
					"weapon": "bow", "weapon_col": Color.html("6b4a2a")}
		"Cory":
			return {"headgear": "wizard_hat", "hatband": Color.html("5a3d22"), "sleeves": "shirt",
					"belt": Color.html("5a3d22"), "boots": Color.html("141018"),
					"straps": Color.html("6b4a2a"), "weapon": "whip", "weapon_col": Color.html("3a2a1c")}
		"Brad":
			return {"headgear": "helmet", "sleeves": "shirt", "pauldrons": true,
					"boots": Color.html("1a173a"), "weapon": "shield"}
		_:
			return {"hair": "short", "sleeves": "shirt", "belt": Color.html("4a4f5e"), "boots": Color.html("3a3f4a")}


func _build_details(pal: Dictionary, spec: Dictionary) -> void:
	for n in _feature_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_feature_nodes.clear()
	_shield_grip = null
	_has_shield = false

	# Reset visibility
	_hair.visible = true
	_eye_l.visible = true
	_eye_r.visible = true

	# Sleeves (arms) + boots/bare feet + eyes
	var sleeve_col := _resolve_role(spec.get("sleeves", "shirt"), pal)
	_left_arm.material_override = _solid(sleeve_col)
	_right_arm.material_override = _solid(sleeve_col)
	var boots_col := _resolve_role(spec.get("boots", "accent"), pal)
	_left_foot.material_override = _solid(boots_col)
	_right_foot.material_override = _solid(boots_col)
	if spec.has("eyes"):
		_eye_l.material_override = _solid(spec["eyes"])
		_eye_r.material_override = _solid(spec["eyes"])

	# Belt
	if spec.has("belt"):
		_add_feature(_make_box_solid("Belt", Vector3(0, 0.48, 0), Vector3(0.45, 0.08, 0.29), spec["belt"]))

	# Bandolier strap (diagonal across the chest)
	if spec.has("straps"):
		var strap := _make_box_solid("Strap", Vector3(0.0, 0.66, 0.14), Vector3(0.07, 0.52, 0.03), spec["straps"])
		strap.rotation_degrees = Vector3(0, 0, 26)
		_add_feature(strap)

	# Long hair framing the face + down the back
	if spec.get("hair", "short") == "long":
		var hc: Color = pal.get("hair", Color.html("141019"))
		_add_feature(_make_box_solid("HairBack", Vector3(0, 0.84, -0.12), Vector3(0.40, 0.58, 0.13), hc))
		_add_feature(_make_box_solid("HairSideL", Vector3(-0.19, 0.88, 0.02), Vector3(0.10, 0.46, 0.22), hc))
		_add_feature(_make_box_solid("HairSideR", Vector3(0.19, 0.88, 0.02), Vector3(0.10, 0.46, 0.22), hc))
		# A fuller fringe so the head doesn't read as bald
		var fringe := _make_sphere("HairFringe", Vector3(0, 1.15, 0.02), 0.215, hc)
		fringe.scale = Vector3(1.04, 0.7, 1.04)
		_add_feature(fringe)

	# Pauldrons (shoulder armour)
	if spec.get("pauldrons", false):
		var pc: Color = pal.get("accent", pal.get("shirt", Color(0.3, 0.3, 0.4)))
		_add_feature(_make_sphere("PauldronL", Vector3(-0.28, 0.85, 0), 0.135, pc))
		_add_feature(_make_sphere("PauldronR", Vector3(0.28, 0.85, 0), 0.135, pc))

	# Headgear
	match spec.get("headgear", "none"):
		"wizard_hat":
			_hair.visible = false
			var hat_col: Color = pal.get("hair", Color.html("4b298d"))
			_add_feature(_make_cyl("HatBrim", Vector3(0, 1.25, 0), 0.37, 0.37, 0.05, hat_col))
			if spec.has("hatband"):
				_add_feature(_make_cyl("HatBand", Vector3(0, 1.29, 0), 0.205, 0.225, 0.06, spec["hatband"]))
			_add_feature(_make_cyl("HatCone", Vector3(0, 1.5, 0), 0.0, 0.2, 0.46, hat_col))
		"helmet":
			_hair.visible = false
			_eye_l.visible = false
			_eye_r.visible = false
			var helm_col: Color = pal.get("hair", Color.html("303061"))
			var helm := _make_sphere("Helmet", Vector3(0, 1.06, 0), 0.225, helm_col)
			helm.scale = Vector3(1.05, 1.1, 1.05)
			_add_feature(helm)
			# Dark visor band + glowing eyes, pushed forward so they clear the helmet
			_add_feature(_make_box_solid("VisorSlit", Vector3(0, 1.04, 0.25), Vector3(0.30, 0.06, 0.04), Color.html("0c0d14")))
			_add_glow("EyeGlowL", Vector3(-0.075, 1.04, 0.275), Color(0.75, 0.85, 1.0))
			_add_glow("EyeGlowR", Vector3(0.075, 1.04, 0.275), Color(0.75, 0.85, 1.0))

	# Quiver on the back (archers)
	if spec.get("quiver", false):
		var tube := _make_cyl("Quiver", Vector3(-0.16, 0.74, -0.17), 0.07, 0.06, 0.42, Color.html("5a3d22"))
		tube.rotation_degrees = Vector3(12, 0, 10)
		_add_feature(tube)
		_add_feature(_make_cyl("QuiverRim", Vector3(-0.205, 0.95, -0.14), 0.075, 0.075, 0.05, Color.html("d8a838")))
		for i in range(3):
			var arrow := _make_cyl("Arrow%d" % i, Vector3(-0.25 + i * 0.045, 1.06, -0.13), 0.012, 0.012, 0.26, Color.html("caa05a"))
			arrow.rotation_degrees = Vector3(14, 0, 8 - i * 8)
			_add_feature(arrow)

	# Weapon
	_build_weapon(spec, pal)


func _build_weapon(spec: Dictionary, pal: Dictionary) -> void:
	match spec.get("weapon", "none"):
		"daggers":
			var blade: Color = spec.get("weapon_col", Color.html("cbe0f1"))
			_add_dagger(_right_shoulder, blade)
			_add_dagger(_left_shoulder, blade)
		"staff":
			# Held upright beside the left side of the body.
			var wood: Color = spec.get("weapon_col", Color.html("6b4a2a"))
			var staff := _make_cyl("Staff", Vector3(-0.37, 0.6, 0.08), 0.03, 0.03, 1.25, wood)
			staff.rotation_degrees = Vector3(0, 0, 7)
			_add_feature(staff)
			_add_feature(_make_sphere("StaffKnob", Vector3(-0.44, 1.22, 0.08), 0.055, wood.lightened(0.15)))
		"whip":
			# A coiled whip hanging at the left hip.
			var leather: Color = spec.get("weapon_col", Color.html("3a2a1c"))
			var coil := _make_torus("WhipCoil", Vector3(-0.32, 0.47, 0.16), 0.045, 0.12, leather)
			coil.rotation_degrees = Vector3(90, 0, 0)
			_add_feature(coil)
			var coil2 := _make_torus("WhipCoil2", Vector3(-0.32, 0.40, 0.16), 0.038, 0.09, leather.darkened(0.12))
			coil2.rotation_degrees = Vector3(90, 0, 0)
			_add_feature(coil2)
		"bow":
			# A wooden recurve bow held at the right side, with a bowstring.
			var wood2: Color = spec.get("weapon_col", Color.html("6b4a2a"))
			_add_feature(_make_box_solid("BowGrip", Vector3(0.40, 0.5, 0.14), Vector3(0.045, 0.26, 0.06), wood2))
			var top := _make_box_solid("BowTop", Vector3(0.425, 0.74, 0.14), Vector3(0.04, 0.24, 0.06), wood2)
			top.rotation_degrees = Vector3(0, 0, 24)
			_add_feature(top)
			var bot := _make_box_solid("BowBot", Vector3(0.425, 0.26, 0.14), Vector3(0.04, 0.24, 0.06), wood2)
			bot.rotation_degrees = Vector3(0, 0, -24)
			_add_feature(bot)
			_add_feature(_make_box_solid("BowString", Vector3(0.33, 0.5, 0.15), Vector3(0.012, 0.66, 0.012), Color.html("dcdce0")))
		"shield":
			# Kite shield held at the (character's-left) side, with a blue T/cross.
			# Parented to a movable grip pivot so animations can raise/thrust the shield.
			var cx := 0.37
			_shield_grip = Node3D.new()
			_shield_grip.name = "ShieldGrip"
			_shield_grip.position = Vector3(cx, 0.45, 0.0)
			_body.add_child(_shield_grip)
			_feature_nodes.append(_shield_grip)
			_has_shield = true
			# Positions are relative to the grip origin (cx, 0.45, 0).
			_shield_part("ShieldBack", Vector3(0, 0.0, 0.11), Vector3(0.32, 0.44, 0.04), Color.html("3a3f5c"))
			_shield_part("ShieldFace", Vector3(0, 0.0, 0.135), Vector3(0.25, 0.36, 0.03), Color.html("c2c8d6"))
			_shield_part("ShieldBarV", Vector3(0, 0.0, 0.15), Vector3(0.05, 0.32, 0.02), Color.html("3a5fa8"))
			_shield_part("ShieldBarH", Vector3(0, 0.10, 0.15), Vector3(0.19, 0.05, 0.02), Color.html("3a5fa8"))


func _shield_part(node_name: String, pos: Vector3, size: Vector3, col: Color) -> void:
	# A shield mesh parented to the movable grip pivot.
	var mi := _make_box_solid(node_name, pos, size, col)
	_shield_grip.add_child(mi)


func _add_dagger(shoulder: Node3D, blade_col: Color) -> void:
	# Held point-down at the hand, angled slightly outward and forward so it reads.
	var hilt := _make_box_solid("DaggerHilt", Vector3(0, -0.44, 0.16), Vector3(0.055, 0.09, 0.055), Color.html("1a1620"))
	hilt.rotation_degrees = Vector3(18, 0, 0)
	shoulder.add_child(hilt)
	_feature_nodes.append(hilt)
	var blade := _make_box_solid("DaggerBlade", Vector3(0, -0.62, 0.22), Vector3(0.06, 0.30, 0.03), blade_col)
	blade.rotation_degrees = Vector3(18, 0, 0)
	shoulder.add_child(blade)
	_feature_nodes.append(blade)


func _add_glow(node_name: String, pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var s := SphereMesh.new()
	s.radius = 0.028
	s.height = 0.056
	mi.mesh = s
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.5
	mi.material_override = mat
	_body.add_child(mi)
	_feature_nodes.append(mi)


func _resolve_role(val, pal: Dictionary) -> Color:
	if val is Color:
		return val
	if typeof(val) == TYPE_STRING and pal.has(val):
		return pal[val]
	return pal.get("shirt", Color(0.5, 0.5, 0.6))


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


func _make_torus(node_name: String, pos: Vector3, inner_r: float, outer_r: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var m := TorusMesh.new()
	m.inner_radius = inner_r
	m.outer_radius = outer_r
	m.rings = 14
	m.ring_segments = 8
	mi.mesh = m
	mi.position = pos
	mi.material_override = _solid(col)
	return mi


# =============================================================
# IDLE
# =============================================================

func _process(delta: float) -> void:
	if not _built or _busy:
		return
	_time += delta
	if _stance == "approach":
		# Hold the guard crouch; only a faint, low breathing sway on top of it.
		_body.position.y = STANCE_APPROACH_Y + sin(_time * 1.4) * 0.008
		return
	var freq := 4.0 if _walking else 1.6
	var amp := 0.035 if _walking else 0.02
	_body.position.y = sin(_time * freq) * amp
	_body.rotation_degrees.z = sin(_time * 1.3) * (2.5 if _walking else 1.0)


# =============================================================
# PUBLIC ANIMATION API
# =============================================================

func play_action(action: String, direction: int = CharacterAnimator.Direction.SOUTH) -> void:
	if not _built:
		return
	set_facing(direction)
	# Any action other than entering the Approach guard clears the held stance.
	if action != "approach_stance":
		_stance = "none"
	match action:
		"attack_slash", "attack_heavy", "attack_ranged", "attack_charged_1", "attack_circling", "attack":
			play_attack()
		"block", "defend":
			play_defend()
		"dodge":
			play_dodge()
		"hit", "hit_heavy", "stunned":
			play_hit()
		"heal":
			play_heal()
		# --- Brad card animations ---
		"approach_stance":
			play_approach_stance()
		"charge":
			play_charge()
		"harden":
			play_harden()
		"heavy_swing":
			play_heavy_swing()
		"heroic_leap":
			play_heroic_leap()
		"hold_the_line":
			play_hold_the_line()
		"hunker_down":
			play_hunker_down()
		"life_steal":
			play_life_steal()
		"life_swap":
			play_life_swap()
		"morphine":
			play_morphine()
		"parry":
			play_parry()
		"roar":
			play_roar()
		"roll":
			play_roll()
		"shed_weight":
			play_shed_weight()
		"shield_slam":
			play_shield_slam()
		"succumb":
			play_succumb()
		"taunt":
			play_taunt()
		"down_but_not_out":
			play_down_but_not_out()
		"cover":
			play_cover()
		# --- Generic card animations ---
		"absorb_essence":
			play_absorb_essence()
		"vines":
			play_vines()
		"bob_and_weave":
			play_bob_and_weave()
		"choke":
			play_choke()
		"energy_ball":
			play_energy_ball()
		"exposed_artery":
			play_exposed_artery()
		"meditate":
			play_meditate()
		"misery_loves_company":
			play_misery_loves_company()
		"potion_of_continuance":
			play_potion_of_continuance()
		"push":
			play_push()
		"release_tension":
			play_release_tension()
		"sweeping_disarm":
			play_sweeping_disarm()
		"anticipation":
			play_anticipation()
		"item_mastery":
			play_item_mastery()
		"blade_barrage":
			play_blade_barrage()
		"adrenaline_shot":
			play_adrenaline_shot()
		"bloodlust":
			play_bloodlust()
		"elixir":
			play_elixir()
		"poisoned_blood":
			play_poisoned_blood()
		"exacerbate_wounds":
			play_exacerbate_wounds()
		"gargle_and_spit":
			play_gargle_and_spit()
		"lethal_recall":
			play_lethal_recall()
		"patience":
			play_patience()
		"raged_circulation":
			play_raged_circulation()
		"shadows":
			play_shadows()
		"shuriken":
			play_shuriken()
		"shuriken_pouch":
			play_shuriken_pouch()
		"volatile_mixture":
			play_volatile_mixture()
		_:
			play_idle()


func play_idle() -> void:
	_cancel_action()
	_stance = "none"
	_reset_pose()
	_busy = false


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


func play_defend() -> void:
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	# The overhead armour icon is driven systemically (see pop_armor_icon) so it
	# only appears when armour is actually gained — not on every defensive pose.
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


func play_heal() -> void:
	# Standard heal: a heart pops above the head with a gentle, relieved bob.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	# The overhead heart is driven systemically (see pop_heart) so it appears
	# whenever HP is actually healed — not on every heal pose.
	_action_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_action_tween.tween_property(_body, "position:y", 0.05, 0.18).set_ease(Tween.EASE_OUT)
	_action_tween.parallel().tween_property(_head, "rotation_degrees:x", -8.0, 0.18)
	_action_tween.tween_property(_body, "position:y", 0.0, 0.3).set_ease(Tween.EASE_IN)
	_action_tween.parallel().tween_property(_head, "rotation_degrees:x", 0.0, 0.3)
	_action_tween.tween_callback(_on_action_done)


# =============================================================
# BRAD CARD ANIMATIONS
# =============================================================

func play_approach_stance() -> void:
	# Persistent guard: shield pushed out front, knees bent into a mild lunge.
	# Held until another action plays (see _process / _stance).
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_stance = "approach"
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "position:y", STANCE_APPROACH_Y, 0.22)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 9.0, 0.22)
	# Lead foot steps forward into the lunge.
	_action_tween.parallel().tween_property(_right_foot, "position:z", 0.22, 0.22)
	_action_tween.parallel().tween_property(_left_foot, "position:z", -0.06, 0.22)
	if _has_shield:
		# Shield raised and thrust forward, guarding.
		_action_tween.parallel().tween_property(_shield_grip, "position", Vector3(0.18, 0.55, 0.22), 0.22)
		_action_tween.parallel().tween_property(_shield_grip, "rotation_degrees:y", -22.0, 0.22)
	_action_tween.tween_callback(_on_action_done)


func play_charge() -> void:
	# Paw the dirt like a bull, wind up, then charge forward; an impact bursts ahead.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_spawn_dirt()
	_action_tween = create_tween()
	# Paw/scuff the ground with the lead foot.
	_action_tween.set_trans(Tween.TRANS_QUAD)
	_action_tween.tween_property(_right_foot, "position:z", -0.18, 0.12).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_right_foot, "position:z", 0.0, 0.1).set_ease(Tween.EASE_IN)
	# Lower the head/lean back to wind up.
	_action_tween.tween_property(_body, "rotation_degrees:x", -14.0, 0.12)
	# Explosive charge forward.
	_action_tween.tween_property(_body, "position:z", 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 16.0, 0.16)
	_action_tween.tween_callback(_spawn_white_impact.bind(1.3))
	# Recover.
	_action_tween.tween_property(_body, "position:z", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 0.0, 0.35)
	_action_tween.tween_callback(_on_action_done)


func play_harden() -> void:
	# Standard defense, but the shoulder armour sparkles.
	play_defend()
	_spawn_sparkles(Vector3(-0.28, 0.95, 0.0))
	_spawn_sparkles(Vector3(0.28, 0.95, 0.0))


func play_heavy_swing() -> void:
	# Step in with the left foot, torque back over the right shoulder, then a huge slice.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween()
	# Step forward (left foot) and torque the body to the right, hands going up-and-back.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_left_foot, "position:z", 0.24, 0.18)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:y", -38.0, 0.18)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", Vector3(-150, -20, 0), 0.18)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", Vector3(-150, 20, 0), 0.18)
	# The slice: whip the body and arms down-and-across.
	_action_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_action_tween.tween_property(_body, "rotation_degrees:y", 30.0, 0.12)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 16.0, 0.12)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", Vector3(-30, 10, 0), 0.12)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", Vector3(-30, -10, 0), 0.12)
	_action_tween.tween_callback(_spawn_white_impact.bind(0.9))
	# Recover to rest.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "rotation_degrees", Vector3.ZERO, 0.3)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", REST, 0.3)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", REST, 0.3)
	_action_tween.parallel().tween_property(_left_foot, "position:z", 0.04, 0.3)
	_action_tween.tween_callback(_on_action_done)


func play_heroic_leap() -> void:
	# Look to the sky, arms overhead, scream, then leap through the air; ground cracks on landing.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_spawn_voice("AAAAGH!!", Color(1.0, 0.85, 0.5))
	_action_tween = create_tween()
	# Wind up: look up, raise both arms overhead, dip the knees.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "rotation_degrees:x", -16.0, 0.22)
	_action_tween.parallel().tween_property(_head, "rotation_degrees:x", -22.0, 0.22)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", Vector3(-168, 0, -18), 0.22)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", Vector3(-168, 0, 18), 0.22)
	_action_tween.parallel().tween_property(_body, "position:y", -0.1, 0.22)
	# Leap: arc up and forward (figure does not disappear — it travels visually).
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "position:y", 1.1, 0.3)
	_action_tween.parallel().tween_property(_body, "position:z", 0.6, 0.3)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 6.0, 0.3)
	# Fall and land.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_action_tween.tween_property(_body, "position:y", 0.0, 0.22)
	_action_tween.parallel().tween_property(_body, "position:z", 1.0, 0.22)
	_action_tween.tween_callback(_on_leap_land)
	# Settle from the landing crouch.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "position:y", -0.14, 0.08)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", REST, 0.18)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", REST, 0.18)
	_action_tween.parallel().tween_property(_head, "rotation_degrees:x", 0.0, 0.18)
	_action_tween.tween_property(_body, "position:y", 0.0, 0.22)
	_action_tween.parallel().tween_property(_body, "position:z", 0.0, 0.3)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 0.0, 0.2)
	_action_tween.tween_callback(_on_action_done)


func _on_leap_land() -> void:
	_spawn_ground_crack()
	_spawn_white_impact(0.0, 0.18)


func play_hold_the_line() -> void:
	# Standard defense, a shout, and an armour icon (ally gains armour).
	play_defend()
	_spawn_voice("Hold the line!")


func play_hunker_down() -> void:
	# Wide sumo step, slam the feet, twist them into the ground, then pop back.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween()
	# Wide stance + drop low.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_left_foot, "position:x", -0.3, 0.16)
	_action_tween.parallel().tween_property(_right_foot, "position:x", 0.3, 0.16)
	_action_tween.parallel().tween_property(_body, "position:y", -0.18, 0.16)
	# Slam + twist the feet.
	_action_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_action_tween.tween_property(_body, "position:y", -0.24, 0.08)
	_action_tween.tween_callback(_spawn_dirt)
	_action_tween.set_trans(Tween.TRANS_QUAD)
	_action_tween.tween_property(_left_foot, "rotation_degrees:y", -28.0, 0.14)
	_action_tween.parallel().tween_property(_right_foot, "rotation_degrees:y", 28.0, 0.14)
	# Pop back to normal stance.
	_action_tween.set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "position:y", 0.0, 0.2)
	_action_tween.parallel().tween_property(_left_foot, "position:x", -0.11, 0.2)
	_action_tween.parallel().tween_property(_right_foot, "position:x", 0.11, 0.2)
	_action_tween.parallel().tween_property(_left_foot, "rotation_degrees:y", 0.0, 0.2)
	_action_tween.parallel().tween_property(_right_foot, "rotation_degrees:y", 0.0, 0.2)
	_action_tween.tween_callback(_on_action_done)


func play_life_steal() -> void:
	# A pair of fangs floats above the head and fades, like the shield/heart icons.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_spawn_fangs()
	_action_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_action_tween.tween_property(_head, "rotation_degrees:z", 6.0, 0.18)
	_action_tween.tween_property(_head, "rotation_degrees:z", 0.0, 0.3)
	_action_tween.tween_callback(_on_action_done)


func play_life_swap() -> void:
	# A line, a self-inflicted slash across the chest, blood squirts, head tilts back to drink.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_spawn_voice("You mistook my blood as valuable to me.")
	_action_tween = create_tween()
	# Raise the weapon arm.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-120, 0, -30), 0.22)
	# Slash across the chest (arm sweeps over).
	_action_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-40, 0, 60), 0.14)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:z", 6.0, 0.14)
	_action_tween.tween_callback(_on_lifeswap_cut)
	# Tilt the head back and let blood drip down into the face.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "rotation_degrees", Vector3.ZERO, 0.2)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", REST, 0.2)
	_action_tween.tween_property(_head, "rotation_degrees:x", 24.0, 0.18)
	_action_tween.tween_callback(_spawn_blood_drop)
	_action_tween.tween_interval(0.35)
	_action_tween.tween_property(_head, "rotation_degrees:x", 0.0, 0.22)
	_action_tween.tween_callback(_on_action_done)


func _on_lifeswap_cut() -> void:
	_spawn_blood(Vector3(0.0, 0.66, 0.18))


func play_morphine() -> void:
	# Taps the opposite wrist three times.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	# Bring the right hand across to the left wrist.
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-70, 0, 70), 0.16).set_ease(Tween.EASE_OUT)
	# Three taps.
	for i in range(3):
		_action_tween.tween_property(_right_shoulder, "rotation_degrees:z", 55.0, 0.07)
		_action_tween.tween_property(_right_shoulder, "rotation_degrees:z", 70.0, 0.07)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", REST, 0.2).set_ease(Tween.EASE_OUT)
	_action_tween.tween_callback(_on_action_done)


func play_parry() -> void:
	# Slight hop back, then a fast forward lunge with the weapon.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween()
	# Hop back.
	_action_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "position:z", -0.25, 0.12)
	_action_tween.parallel().tween_property(_body, "position:y", 0.08, 0.12)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", -8.0, 0.12)
	# Quick lunge forward with a thrust.
	_action_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_action_tween.tween_property(_body, "position:z", 0.45, 0.12)
	_action_tween.parallel().tween_property(_body, "position:y", 0.0, 0.12)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 14.0, 0.12)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees:x", -95.0, 0.12)
	_action_tween.tween_callback(_spawn_white_impact.bind(0.7))
	# Recover.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "position:z", 0.0, 0.28)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 0.0, 0.28)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", REST, 0.28)
	_action_tween.tween_callback(_on_action_done)


func play_roar() -> void:
	# Step forward, swing the arms down to the sides, lean in, and bellow.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_spawn_voice("ROAR!!!!!", Color(1.0, 0.5, 0.35))
	_action_tween = create_tween()
	_action_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_left_foot, "position:z", 0.24, 0.16)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 14.0, 0.16)
	# Arms thrown back and down to the sides.
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", Vector3(28, 0, 26), 0.16)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", Vector3(28, 0, -26), 0.16)
	# A couple of bellowing shakes.
	for i in range(2):
		_action_tween.tween_property(_body, "rotation_degrees:x", 18.0, 0.07)
		_action_tween.tween_property(_body, "rotation_degrees:x", 12.0, 0.07)
	# Recover.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "rotation_degrees:x", 0.0, 0.25)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", REST, 0.25)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", REST, 0.25)
	_action_tween.parallel().tween_property(_left_foot, "position:z", 0.04, 0.25)
	_action_tween.tween_callback(_on_action_done)


func play_roll() -> void:
	# Tuck into a ball and roll forward.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween()
	# Tuck.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_action_tween.tween_property(_body, "scale", Vector3(0.9, 0.6, 0.9), 0.1)
	_action_tween.parallel().tween_property(_body, "position:y", -0.18, 0.1)
	# Roll: spin forward while travelling.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_action_tween.tween_property(_body, "rotation_degrees:x", 720.0, 0.5)
	_action_tween.parallel().tween_property(_body, "position:z", 1.0, 0.5)
	# Unfurl back to standing.
	_action_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "scale", Vector3.ONE, 0.18)
	_action_tween.parallel().tween_property(_body, "position:y", 0.0, 0.18)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 0.0, 0.18)
	_action_tween.parallel().tween_property(_body, "position:z", 0.0, 0.3)
	_action_tween.tween_callback(_on_action_done)


func play_shed_weight() -> void:
	# A defiant shrug as the load is thrown off.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_spawn_voice("Caution to the wind!")
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	# Shrug up...
	_action_tween.tween_property(_left_shoulder, "rotation_degrees:z", -24.0, 0.16).set_ease(Tween.EASE_OUT)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees:z", 24.0, 0.16)
	_action_tween.parallel().tween_property(_body, "position:y", 0.06, 0.16)
	# ...and cast it off.
	_action_tween.tween_property(_left_shoulder, "rotation_degrees:z", 0.0, 0.24).set_ease(Tween.EASE_IN)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees:z", 0.0, 0.24)
	_action_tween.parallel().tween_property(_body, "position:y", 0.0, 0.24)
	_action_tween.tween_callback(_on_action_done)


func play_shield_slam() -> void:
	# Bring the shield up onto the shoulder, set an athletic base, then bash forward.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween()
	# Set up: shield up by the shoulder, crouch into an athletic stance.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "position:y", -0.12, 0.2)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", -10.0, 0.2)
	if _has_shield:
		_action_tween.parallel().tween_property(_shield_grip, "position", Vector3(0.05, 0.7, 0.18), 0.2)
		_action_tween.parallel().tween_property(_shield_grip, "rotation_degrees:y", -30.0, 0.2)
	# Bash: drive the shoulder (and shield) forward.
	_action_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_action_tween.tween_property(_body, "position:z", 0.5, 0.12)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 14.0, 0.12)
	_action_tween.tween_callback(_spawn_white_impact.bind(0.85))
	# Recover.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "position:z", 0.0, 0.3)
	_action_tween.parallel().tween_property(_body, "position:y", 0.0, 0.3)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 0.0, 0.3)
	if _has_shield:
		_action_tween.parallel().tween_property(_shield_grip, "position", Vector3(0.0, 0.0, 0.0), 0.3)
		_action_tween.parallel().tween_property(_shield_grip, "rotation_degrees:y", 0.0, 0.3)
	_action_tween.tween_callback(_on_action_done)


func play_succumb() -> void:
	# A penitent bow.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_spawn_voice("Father, forgive my sins.")
	_action_tween = create_tween().set_trans(Tween.TRANS_SINE)
	# Bow the head and lean forward, arms drawn in.
	_action_tween.tween_property(_body, "rotation_degrees:x", 20.0, 0.3).set_ease(Tween.EASE_OUT)
	_action_tween.parallel().tween_property(_body, "position:y", -0.1, 0.3)
	_action_tween.parallel().tween_property(_head, "rotation_degrees:x", 18.0, 0.3)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", Vector3(-30, 0, 24), 0.3)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", Vector3(-30, 0, -24), 0.3)
	_action_tween.tween_interval(0.4)
	_action_tween.tween_property(_body, "rotation_degrees:x", 0.0, 0.3).set_ease(Tween.EASE_OUT)
	_action_tween.parallel().tween_property(_body, "position:y", 0.0, 0.3)
	_action_tween.parallel().tween_property(_head, "rotation_degrees:x", 0.0, 0.3)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", REST, 0.3)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", REST, 0.3)
	_action_tween.tween_callback(_on_action_done)


func play_taunt() -> void:
	# Standard defense with a shout.
	play_defend()
	_spawn_voice("All eyes on me!")


func play_down_but_not_out() -> void:
	# Standard heal with a defiant line.
	play_heal()
	_spawn_voice("You picked on the wrong guy.")


func play_cover() -> void:
	# Blink in front of the threatened ally and raise the shield to guard.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_spawn_shield()
	_action_tween = create_tween()
	# Quick blink-step forward, planting in front.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "position:z", 0.6, 0.08)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 6.0, 0.08)
	if _has_shield:
		_action_tween.parallel().tween_property(_shield_grip, "position", Vector3(0.1, 0.55, 0.24), 0.08)
		_action_tween.parallel().tween_property(_shield_grip, "rotation_degrees:y", -26.0, 0.08)
	# Hold the guard briefly.
	_action_tween.tween_interval(0.4)
	# Return.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "position:z", 0.0, 0.3)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 0.0, 0.3)
	if _has_shield:
		_action_tween.parallel().tween_property(_shield_grip, "position", Vector3.ZERO, 0.3)
		_action_tween.parallel().tween_property(_shield_grip, "rotation_degrees:y", 0.0, 0.3)
	_action_tween.tween_callback(_on_action_done)


# =============================================================
# GENERIC CARD ANIMATIONS (character-agnostic)
# =============================================================

func play_absorb_essence() -> void:
	# Raise both arms up from the sides and hold them overhead for ~1 second,
	# drawing motes of essence inward.
	_play_arms_raise(Color(0.7, 0.9, 1.0))


func play_vines() -> void:
	# Same overhead arm-raise as Absorb Essence, with a green, growing flavour.
	_play_arms_raise(Color(0.4, 0.85, 0.35))


func _play_arms_raise(mote_col: Color) -> void:
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween()
	# Sweep the arms out to the sides, then up overhead.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(0, 0, 95), 0.16)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", Vector3(0, 0, -95), 0.16)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-172, 0, -16), 0.22)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", Vector3(-172, 0, 16), 0.22)
	_action_tween.parallel().tween_property(_head, "rotation_degrees:x", -16.0, 0.22)
	_action_tween.tween_callback(_spawn_essence_motes.bind(mote_col))
	# Hold overhead for ~1 second.
	_action_tween.tween_interval(1.0)
	# Lower the arms back to rest.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", REST, 0.28)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", REST, 0.28)
	_action_tween.parallel().tween_property(_head, "rotation_degrees:x", 0.0, 0.28)
	_action_tween.tween_callback(_on_action_done)


func play_bob_and_weave() -> void:
	# Drop into an athletic stance, then duck-and-weave twice as if slipping hooks.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween()
	# Athletic base: knees bent, hands up, weight low.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "position:y", -0.12, 0.16)
	_action_tween.parallel().tween_property(_left_foot, "position:z", 0.16, 0.16)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", Vector3(-58, 0, 42), 0.16)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", Vector3(-58, 0, -42), 0.16)
	# Weave: dip-and-lean one way, then the other (slipping a hook each time).
	_action_tween.set_trans(Tween.TRANS_SINE)
	for sign_dir in [-1.0, 1.0]:
		_action_tween.tween_property(_body, "position:y", -0.24, 0.12)
		_action_tween.parallel().tween_property(_body, "rotation_degrees:z", 16.0 * sign_dir, 0.12)
		_action_tween.parallel().tween_property(_body, "position:x", 0.12 * sign_dir, 0.12)
		_action_tween.tween_property(_body, "position:y", -0.12, 0.12)
		_action_tween.parallel().tween_property(_body, "rotation_degrees:z", 0.0, 0.12)
		_action_tween.parallel().tween_property(_body, "position:x", 0.0, 0.12)
	# Recover to standing.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "position:y", 0.0, 0.2)
	_action_tween.parallel().tween_property(_left_foot, "position:z", 0.04, 0.2)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", REST, 0.2)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", REST, 0.2)
	_action_tween.tween_callback(_on_action_done)


func play_choke() -> void:
	# Reach a hand out (Vader-style), clench, then yank the arm back as if
	# crushing something at a distance.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween()
	# Reach the right hand forward toward the target.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-92, 0, 0), 0.2)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 6.0, 0.2)
	# Hold the grip, with a small tightening tremor.
	_action_tween.tween_interval(0.18)
	for i in range(2):
		_action_tween.tween_property(_right_shoulder, "rotation_degrees:x", -98.0, 0.06)
		_action_tween.tween_property(_right_shoulder, "rotation_degrees:x", -92.0, 0.06)
	# Yank the arm back — caught something — leaning back with the pull.
	_action_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-30, 0, 18), 0.14)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", -8.0, 0.14)
	_action_tween.parallel().tween_property(_body, "position:z", -0.12, 0.14)
	# Recover.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", REST, 0.26)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 0.0, 0.26)
	_action_tween.parallel().tween_property(_body, "position:z", 0.0, 0.26)
	_action_tween.tween_callback(_on_action_done)


func play_energy_ball(size: float = 1.0) -> void:
	# Gather an orb between the hands, then thrust it forward at the enemy.
	# The orb's size scales with the damage being dealt (caller passes `size`).
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween()
	# Bring both hands forward to cradle the forming orb.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-80, 0, -12), 0.2)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", Vector3(-80, 0, 12), 0.2)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", -6.0, 0.2)
	_action_tween.tween_callback(_spawn_energy_ball.bind(size))
	# Thrust forward to launch it.
	_action_tween.tween_interval(0.28)
	_action_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_action_tween.tween_property(_body, "rotation_degrees:x", 12.0, 0.12)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees:x", -100.0, 0.12)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees:x", -100.0, 0.12)
	# Recover.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "rotation_degrees:x", 0.0, 0.26)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", REST, 0.26)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", REST, 0.26)
	_action_tween.tween_callback(_on_action_done)


func play_exposed_artery() -> void:
	# A large slashing swipe at the enemy; blood squirts after the blade lands.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween()
	# Wind the arm up high and across.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-160, 0, -42), 0.2)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:y", -26.0, 0.2)
	# The slash: whip the arm down-and-across.
	_action_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-36, 0, 56), 0.12)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:y", 24.0, 0.12)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 10.0, 0.12)
	_action_tween.tween_callback(_on_artery_cut)
	# Recover.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "rotation_degrees", Vector3.ZERO, 0.3)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", REST, 0.3)
	_action_tween.tween_callback(_on_action_done)


func _on_artery_cut() -> void:
	# Blood squirts forward where the slash landed, with a sharp white flash.
	_spawn_white_impact(0.7, 0.7)
	_spawn_blood(Vector3(0.0, 0.7, 0.55))


func play_meditate() -> void:
	# Float up, fold the legs, bring the hands beside the head and trace small
	# circles with the fingers before settling back down.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween()
	# Rise into a cross-legged float: feet tuck in and up, hands come up by the head.
	_action_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "position:y", 0.32, 0.4)
	_action_tween.parallel().tween_property(_left_foot, "position", Vector3(0.06, 0.2, 0.1), 0.4)
	_action_tween.parallel().tween_property(_right_foot, "position", Vector3(-0.06, 0.2, 0.1), 0.4)
	_action_tween.parallel().tween_property(_left_foot, "rotation_degrees:y", -40.0, 0.4)
	_action_tween.parallel().tween_property(_right_foot, "rotation_degrees:y", 40.0, 0.4)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", Vector3(-126, 0, -52), 0.4)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", Vector3(-126, 0, 52), 0.4)
	_action_tween.parallel().tween_property(_head, "rotation_degrees:x", 8.0, 0.4)
	# Hover serenely, tracing little finger circles (small wrist rolls) while bobbing.
	_action_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in range(3):
		_action_tween.tween_property(_body, "position:y", 0.38, 0.35)
		_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees:z", -64.0, 0.35)
		_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees:z", 64.0, 0.35)
		_action_tween.tween_property(_body, "position:y", 0.30, 0.35)
		_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees:z", -52.0, 0.35)
		_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees:z", 52.0, 0.35)
	# Settle back to the ground and rest.
	_action_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_action_tween.tween_property(_body, "position:y", 0.0, 0.35)
	_action_tween.parallel().tween_property(_left_foot, "position", Vector3(-0.11, 0.05, 0.04), 0.35)
	_action_tween.parallel().tween_property(_right_foot, "position", Vector3(0.11, 0.05, 0.04), 0.35)
	_action_tween.parallel().tween_property(_left_foot, "rotation_degrees:y", 0.0, 0.35)
	_action_tween.parallel().tween_property(_right_foot, "rotation_degrees:y", 0.0, 0.35)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", REST, 0.35)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", REST, 0.35)
	_action_tween.parallel().tween_property(_head, "rotation_degrees:x", 0.0, 0.35)
	_action_tween.tween_callback(_on_action_done)


func play_misery_loves_company() -> void:
	# A taunting line, with a beckoning "come here" wave of the hand.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_spawn_voice("I have a friend named misery, and she needs some company", Color(0.8, 0.6, 0.9))
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	# Raise the hand and beckon a couple of times.
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-100, 0, -10), 0.18).set_ease(Tween.EASE_OUT)
	for i in range(2):
		_action_tween.tween_property(_right_shoulder, "rotation_degrees:x", -76.0, 0.14)
		_action_tween.tween_property(_right_shoulder, "rotation_degrees:x", -100.0, 0.14)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", REST, 0.24).set_ease(Tween.EASE_OUT)
	_action_tween.tween_callback(_on_action_done)


func play_potion_of_continuance() -> void:
	# Bring a hand up to the mouth and tilt the head back to drink.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	# Lift the hand to the mouth.
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-150, 0, 28), 0.2).set_ease(Tween.EASE_OUT)
	# Tilt the head back and gulp a couple of times.
	_action_tween.tween_property(_head, "rotation_degrees:x", 22.0, 0.16)
	for i in range(2):
		_action_tween.tween_property(_body, "position:y", 0.03, 0.12)
		_action_tween.tween_property(_body, "position:y", 0.0, 0.12)
	# Lower the head and hand.
	_action_tween.tween_property(_head, "rotation_degrees:x", 0.0, 0.18).set_ease(Tween.EASE_OUT)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", REST, 0.24)
	_action_tween.tween_callback(_on_action_done)


func play_push() -> void:
	# Step forward with one foot and shove the air with one palm.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween()
	# Wind back slightly, hand drawn in.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-55, 0, 0), 0.14)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", -6.0, 0.14)
	# Step forward and shove the palm out hard.
	_action_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_action_tween.tween_property(_right_foot, "position:z", 0.26, 0.12)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees:x", -96.0, 0.12)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 12.0, 0.12)
	_action_tween.parallel().tween_property(_body, "position:z", 0.18, 0.12)
	_action_tween.tween_callback(_spawn_white_impact.bind(0.8, 0.8))
	# Recover.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", REST, 0.28)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 0.0, 0.28)
	_action_tween.parallel().tween_property(_body, "position:z", 0.0, 0.28)
	_action_tween.parallel().tween_property(_right_foot, "position:z", 0.04, 0.28)
	_action_tween.tween_callback(_on_action_done)


func play_release_tension() -> void:
	# Reach toward the enemy; a blue spark appears there and travels back into
	# the player, who pulls the arm in as it returns.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween()
	# Reach out toward the target.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-90, 0, -8), 0.2)
	_action_tween.tween_callback(_spawn_return_spark)
	# Draw the spark back in (the arm reels it home).
	_action_tween.tween_interval(0.42)
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-40, 0, 14), 0.18)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", -6.0, 0.18)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", REST, 0.24)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 0.0, 0.24)
	_action_tween.tween_callback(_on_action_done)


func play_sweeping_disarm() -> void:
	# A large ~180° horizontal swipe across the front, extended arm leading.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween()
	# Load the arm out to one side, extended at shoulder height.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-90, 70, 0), 0.18)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:y", 34.0, 0.18)
	# Sweep across the front to the far side.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-90, -70, 0), 0.22)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:y", -34.0, 0.22)
	_action_tween.tween_callback(_spawn_white_impact.bind(0.65, 1.1))
	# Recover.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", REST, 0.28)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:y", 0.0, 0.28)
	_action_tween.tween_callback(_on_action_done)


func play_anticipation() -> void:
	# A quick, snappy drop into a ready athletic stance, then settle.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween()
	# Snap low with hands up.
	_action_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "position:y", -0.14, 0.12)
	_action_tween.parallel().tween_property(_left_foot, "position:z", 0.16, 0.12)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", Vector3(-60, 0, 40), 0.12)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", Vector3(-60, 0, -40), 0.12)
	# Hold the coiled stance a beat.
	_action_tween.tween_interval(0.3)
	# Settle back up.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "position:y", 0.0, 0.22)
	_action_tween.parallel().tween_property(_left_foot, "position:z", 0.04, 0.22)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", REST, 0.22)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", REST, 0.22)
	_action_tween.tween_callback(_on_action_done)


func play_item_mastery() -> void:
	# Spin the blades (a fast double arm-roll), then set into a kung-fu stance.
	# Held daggers (Ryan) follow the arms; otherwise the flourish reads on its own.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween()
	# Two quick arm-spins (the "spinning blades" flourish).
	_action_tween.set_trans(Tween.TRANS_LINEAR)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees:x", -360.0, 0.22)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees:x", -360.0, 0.22)
	_action_tween.tween_callback(_zero_arm_spin)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees:x", -360.0, 0.22)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees:x", -360.0, 0.22)
	_action_tween.tween_callback(_zero_arm_spin)
	# Snap into a bladed kung-fu stance: body turned, lead hand forward, rear hand cocked.
	_action_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "rotation_degrees:y", -32.0, 0.18)
	_action_tween.parallel().tween_property(_body, "position:y", -0.1, 0.18)
	_action_tween.parallel().tween_property(_left_foot, "position:z", 0.2, 0.18)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", Vector3(-78, 0, -16), 0.18)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", Vector3(-40, 0, 48), 0.18)
	# Hold the stance.
	_action_tween.tween_interval(0.4)
	# Recover.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "rotation_degrees:y", 0.0, 0.24)
	_action_tween.parallel().tween_property(_body, "position:y", 0.0, 0.24)
	_action_tween.parallel().tween_property(_left_foot, "position:z", 0.04, 0.24)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", REST, 0.24)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", REST, 0.24)
	_action_tween.tween_callback(_on_action_done)


func _zero_arm_spin() -> void:
	# Reset the spin axis to 0 between revolutions so the next 360 reads cleanly.
	if _built:
		_right_shoulder.rotation_degrees.x = 0.0
		_left_shoulder.rotation_degrees.x = 0.0


func play_blade_barrage() -> void:
	# A flurry of rapid alternating thrusts — three stabs with each hand.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween()
	# Lean into the barrage.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "rotation_degrees:x", 8.0, 0.1)
	_action_tween.parallel().tween_property(_left_foot, "position:z", 0.18, 0.1)
	# Alternate quick stabs, left/right, three each.
	_action_tween.set_trans(Tween.TRANS_QUAD)
	for i in range(3):
		_action_tween.tween_property(_right_shoulder, "rotation_degrees:x", -102.0, 0.06).set_ease(Tween.EASE_OUT)
		_action_tween.tween_callback(_spawn_white_impact.bind(0.7, 0.45))
		_action_tween.tween_property(_right_shoulder, "rotation_degrees:x", -40.0, 0.06).set_ease(Tween.EASE_IN)
		_action_tween.tween_property(_left_shoulder, "rotation_degrees:x", -102.0, 0.06).set_ease(Tween.EASE_OUT)
		_action_tween.tween_callback(_spawn_white_impact.bind(0.7, 0.45))
		_action_tween.tween_property(_left_shoulder, "rotation_degrees:x", -40.0, 0.06).set_ease(Tween.EASE_IN)
	# Recover.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", REST, 0.24)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", REST, 0.24)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 0.0, 0.24)
	_action_tween.parallel().tween_property(_left_foot, "position:z", 0.04, 0.24)
	_action_tween.tween_callback(_on_action_done)


func play_adrenaline_shot() -> void:
	# Bring a hand to the opposite upper arm and plunge an (invisible) syringe,
	# then jolt as the adrenaline hits.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween()
	# Hand crosses to the left upper arm.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-62, 0, 82), 0.2)
	# Plunge.
	_action_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees:z", 74.0, 0.1)
	_action_tween.tween_callback(_on_adrenaline_inject)
	# Jolt / rush: snap upright with a quick shudder.
	_action_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "position:y", 0.06, 0.12)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", -10.0, 0.12)
	for i in range(2):
		_action_tween.tween_property(_body, "rotation_degrees:z", 4.0, 0.05)
		_action_tween.tween_property(_body, "rotation_degrees:z", -4.0, 0.05)
	# Recover.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "position:y", 0.0, 0.2)
	_action_tween.parallel().tween_property(_body, "rotation_degrees", Vector3.ZERO, 0.2)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", REST, 0.2)
	_action_tween.tween_callback(_on_action_done)


func _on_adrenaline_inject() -> void:
	# A small red flash at the injection site (left upper arm).
	_spawn_colored_smoke(Vector3(-0.27, 0.7, 0.08), Color(0.85, 0.2, 0.25), 4, 0.004, 0.12)


func play_bloodlust() -> void:
	# Shake the head violently, like a rabid dog, with a fleck or two of spit.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween()
	# Hunch forward.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "rotation_degrees:x", 14.0, 0.1)
	# Rapid head shakes side to side.
	_action_tween.set_trans(Tween.TRANS_SINE)
	for i in range(5):
		_action_tween.tween_property(_head, "rotation_degrees:y", 30.0, 0.05)
		_action_tween.tween_property(_head, "rotation_degrees:y", -30.0, 0.05)
	_action_tween.tween_callback(_spawn_spit_flecks)
	# Settle.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_head, "rotation_degrees:y", 0.0, 0.14)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 0.0, 0.18)
	_action_tween.tween_callback(_on_action_done)


func _spawn_spit_flecks() -> void:
	_spawn_colored_smoke(Vector3(0.0, 1.0, 0.22), Color(0.95, 0.95, 0.92), 4, 0.004, 0.3)


func play_elixir() -> void:
	# Hold a beaker of green liquid; drip into it until it turns red.
	_play_beaker_brew(Color(0.3, 0.78, 0.3), Color(0.82, 0.12, 0.12))


func play_poisoned_blood() -> void:
	# Hold a beaker of red liquid; drip into it until it turns green.
	_play_beaker_brew(Color(0.82, 0.12, 0.12), Color(0.3, 0.78, 0.3))


func _play_beaker_brew(from_col: Color, to_col: Color) -> void:
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	var beaker := _build_beaker(_left_hand, from_col)
	var liquid: MeshInstance3D = beaker["liquid"]
	var root: Node3D = beaker["root"]
	_action_tween = create_tween()
	# Raise the beaker out front; the other hand hovers above to drip.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_left_shoulder, "rotation_degrees", Vector3(-82, 0, 16), 0.24)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", Vector3(-104, 0, -26), 0.24)
	_action_tween.parallel().tween_property(_head, "rotation_degrees:x", 10.0, 0.24)
	# Drip three times; the liquid shifts colour as the drops land.
	for i in range(3):
		_action_tween.tween_property(_right_shoulder, "rotation_degrees:x", -94.0, 0.1)
		_action_tween.tween_callback(_spawn_droplet.bind(root, to_col))
		_action_tween.tween_property(_right_shoulder, "rotation_degrees:x", -104.0, 0.1)
	# The transformation: green<->red over a beat, with a small fizz.
	_action_tween.tween_property(liquid.material_override, "albedo_color", to_col, 0.4)
	_action_tween.parallel().tween_callback(_spawn_beaker_fizz.bind(root, to_col))
	_action_tween.tween_interval(0.25)
	# Lower the arms and dismiss the beaker.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_left_shoulder, "rotation_degrees", REST, 0.26)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", REST, 0.26)
	_action_tween.parallel().tween_property(_head, "rotation_degrees:x", 0.0, 0.26)
	_action_tween.tween_callback(_on_action_done)


func play_exacerbate_wounds() -> void:
	# A quick lunge in and a sharp poke.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween()
	# Lunge forward.
	_action_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_action_tween.tween_property(_body, "position:z", 0.4, 0.12)
	_action_tween.parallel().tween_property(_right_foot, "position:z", 0.26, 0.12)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 10.0, 0.12)
	# Sharp poke.
	_action_tween.tween_property(_right_shoulder, "rotation_degrees:x", -100.0, 0.08).set_ease(Tween.EASE_OUT)
	_action_tween.tween_callback(_spawn_white_impact.bind(0.75, 0.6))
	# Recover.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "position:z", 0.0, 0.26)
	_action_tween.parallel().tween_property(_right_foot, "position:z", 0.04, 0.26)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 0.0, 0.26)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", REST, 0.26)
	_action_tween.tween_callback(_on_action_done)


func play_gargle_and_spit() -> void:
	# Drink (the standard potion motion), swish it around, then spit it back out.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	# Drink: hand to mouth, head tilts back.
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-150, 0, 28), 0.2).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_head, "rotation_degrees:x", 24.0, 0.16)
	# Gargle: head wobbles, cheeks working.
	_action_tween.set_trans(Tween.TRANS_SINE)
	for i in range(3):
		_action_tween.tween_property(_head, "rotation_degrees:z", 8.0, 0.08)
		_action_tween.tween_property(_head, "rotation_degrees:z", -8.0, 0.08)
	_action_tween.tween_property(_head, "rotation_degrees:z", 0.0, 0.06)
	# Spit: lurch forward and let it fly.
	_action_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_action_tween.tween_property(_head, "rotation_degrees:x", -18.0, 0.1)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 14.0, 0.1)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", REST, 0.1)
	_action_tween.tween_callback(_spawn_spit)
	# Recover.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_head, "rotation_degrees:x", 0.0, 0.22)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 0.0, 0.22)
	_action_tween.tween_callback(_on_action_done)


func _spawn_spit() -> void:
	# A spray of liquid flung forward from the mouth.
	for i in range(7):
		var sp := _make_icon_sprite(_tex_puff(Color(0.55, 0.7, 0.35)))
		sp.pixel_size = 0.005
		sp.position = Vector3(0, 1.02, 0.24)
		sp.scale = Vector3.ONE * randf_range(0.3, 0.7)
		_body.add_child(sp)
		var tw := sp.create_tween()
		var dest := sp.position + Vector3(randf_range(-0.18, 0.18), randf_range(-0.3, -0.05), randf_range(0.4, 0.8))
		tw.tween_property(sp, "position", dest, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sp, "modulate:a", 0.0, 0.4)
		tw.tween_callback(sp.queue_free)


func play_lethal_recall() -> void:
	# A puzzled line with a hand-to-chin "now how did that go?" gesture.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_spawn_voice("How does that go again??", Color(0.8, 0.85, 1.0))
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	# Hand to chin, head cocked to the side, thinking.
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-128, 0, 64), 0.2).set_ease(Tween.EASE_OUT)
	_action_tween.parallel().tween_property(_head, "rotation_degrees:z", 12.0, 0.2)
	# Tap the chin a couple of times.
	for i in range(2):
		_action_tween.tween_property(_head, "rotation_degrees:x", 6.0, 0.12)
		_action_tween.tween_property(_head, "rotation_degrees:x", 0.0, 0.12)
	# Recover.
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", REST, 0.24).set_ease(Tween.EASE_OUT)
	_action_tween.parallel().tween_property(_head, "rotation_degrees:z", 0.0, 0.24)
	_action_tween.tween_callback(_on_action_done)


func play_patience() -> void:
	# A calming gather: feet together, arms swoop up overhead, then down to form a
	# circle at the chest, finishing with a bowed head.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween()
	# Bring the feet together and sweep the arms up overhead.
	_action_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_action_tween.tween_property(_left_foot, "position:x", -0.04, 0.3)
	_action_tween.parallel().tween_property(_right_foot, "position:x", 0.04, 0.3)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", Vector3(-172, 0, -12), 0.3)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", Vector3(-172, 0, 12), 0.3)
	# Bring the hands down together, forming a circle at the chest.
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-72, 0, -58), 0.3)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", Vector3(-72, 0, 58), 0.3)
	# Bow the head.
	_action_tween.tween_property(_head, "rotation_degrees:x", 22.0, 0.22)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 8.0, 0.22)
	# Hold the centred pose.
	_action_tween.tween_interval(0.5)
	# Release.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_head, "rotation_degrees:x", 0.0, 0.3)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 0.0, 0.3)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", REST, 0.3)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", REST, 0.3)
	_action_tween.parallel().tween_property(_left_foot, "position:x", -0.11, 0.3)
	_action_tween.parallel().tween_property(_right_foot, "position:x", 0.11, 0.3)
	_action_tween.tween_callback(_on_action_done)


func play_raged_circulation() -> void:
	# A psyched-up double-fist pump with a shout.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_spawn_voice("Feel the rush", Color(1.0, 0.45, 0.3))
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	# Both fists pulled up and in, body coiled low.
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-96, 0, 64), 0.16).set_ease(Tween.EASE_OUT)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", Vector3(-96, 0, -64), 0.16)
	_action_tween.parallel().tween_property(_body, "position:y", -0.1, 0.16)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 10.0, 0.16)
	# A couple of sharp pumps.
	_action_tween.set_trans(Tween.TRANS_BACK)
	for i in range(2):
		_action_tween.tween_property(_body, "position:y", -0.16, 0.08).set_ease(Tween.EASE_IN)
		_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees:z", 74.0, 0.08)
		_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees:z", -74.0, 0.08)
		_action_tween.tween_property(_body, "position:y", -0.08, 0.08).set_ease(Tween.EASE_OUT)
		_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees:z", 64.0, 0.08)
		_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees:z", -64.0, 0.08)
	# Recover.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "position:y", 0.0, 0.22)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 0.0, 0.22)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", REST, 0.22)
	_action_tween.parallel().tween_property(_left_shoulder, "rotation_degrees", REST, 0.22)
	_action_tween.tween_callback(_on_action_done)


func play_shadows() -> void:
	# A cheeky wave goodbye and a puff of smoke as they slip into the shadows.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_spawn_voice("Toodles!", Color(0.7, 0.7, 0.85))
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	# Raise a hand and waggle it.
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-150, 0, 20), 0.18).set_ease(Tween.EASE_OUT)
	for i in range(3):
		_action_tween.tween_property(_right_shoulder, "rotation_degrees:z", 40.0, 0.08)
		_action_tween.tween_property(_right_shoulder, "rotation_degrees:z", 8.0, 0.08)
	# Drop and vanish in a puff of smoke.
	_action_tween.tween_callback(_on_shadows_vanish)
	_action_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_action_tween.tween_property(_body, "scale", Vector3(0.9, 0.5, 0.9), 0.12)
	_action_tween.parallel().tween_property(_body, "position:y", -0.1, 0.12)
	# Reappear (the systemic invisibility is handled elsewhere; the figure stays visible).
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_interval(0.15)
	_action_tween.tween_property(_body, "scale", Vector3.ONE, 0.2)
	_action_tween.parallel().tween_property(_body, "position:y", 0.0, 0.2)
	_action_tween.parallel().tween_property(_right_shoulder, "rotation_degrees", REST, 0.2)
	_action_tween.tween_callback(_on_action_done)


func _on_shadows_vanish() -> void:
	_spawn_colored_smoke(Vector3(0.0, 0.6, 0.05), Color(0.32, 0.3, 0.4), 12, 0.008, 0.45)


func play_shuriken() -> void:
	# Cock the throwing arm back, then snap it forward, releasing a spinning star.
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween()
	# Cock back over the shoulder.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-150, 0, -28), 0.16)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:y", 24.0, 0.16)
	# Snap forward and release.
	_action_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-96, 0, 8), 0.1)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:y", -16.0, 0.1)
	_action_tween.tween_callback(_spawn_shuriken)
	# Recover.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", REST, 0.24)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:y", 0.0, 0.24)
	_action_tween.tween_callback(_on_action_done)


func play_shuriken_pouch() -> void:
	# Toss a pouch up, then catch it down at the waist (where it vanishes).
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_spawn_pouch_toss()
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	# Flick the hand up on the toss...
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-60, 0, -20), 0.16).set_ease(Tween.EASE_OUT)
	# ...then bring it down to the waist to "catch".
	_action_tween.tween_interval(0.34)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-20, 0, 18), 0.16).set_ease(Tween.EASE_IN)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", REST, 0.2).set_ease(Tween.EASE_OUT)
	_action_tween.tween_callback(_on_action_done)


func play_volatile_mixture() -> void:
	# The unstable brew goes off — a green burst of smoke and a flinch back.
	# (Whether it bursts on the player or an enemy is decided by the card; here the
	# player performs the reaction.)
	if not _built:
		return
	_cancel_action()
	_reset_pose()
	_busy = true
	_action_tween = create_tween()
	# Flinch back from the blast.
	_action_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_action_tween.tween_callback(_on_volatile_burst)
	_action_tween.tween_property(_body, "rotation_degrees:x", -18.0, 0.12)
	_action_tween.parallel().tween_property(_body, "position:z", -0.14, 0.12)
	for i in range(2):
		_action_tween.tween_property(_body, "rotation_degrees:z", 5.0, 0.06)
		_action_tween.tween_property(_body, "rotation_degrees:z", -5.0, 0.06)
	# Recover.
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_body, "rotation_degrees", Vector3.ZERO, 0.24)
	_action_tween.parallel().tween_property(_body, "position:z", 0.0, 0.24)
	_action_tween.tween_callback(_on_action_done)


func _on_volatile_burst() -> void:
	_spawn_colored_smoke(Vector3(0.0, 0.7, 0.12), Color(0.35, 0.85, 0.25), 12, 0.009, 0.5)


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
			_pivot.rotation_degrees.y = 90.0
		CharacterAnimator.Direction.WEST:
			_pivot.rotation_degrees.y = -90.0


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
# SHIELD ICON (defend)
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
# OVERHEAD ICONS / FX (heart, fangs, sparkles, voice, impacts)
# =============================================================

## Public hooks for systemic feedback (armour gained / healed from any source).
func pop_armor_icon() -> void:
	if _built:
		_spawn_armor_icon()


func pop_heart() -> void:
	if _built:
		_spawn_heart()


func _make_icon_sprite(tex: Texture2D) -> Sprite3D:
	var sp := Sprite3D.new()
	sp.texture = tex
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.shaded = false
	sp.no_depth_test = true
	sp.render_priority = 40
	sp.pixel_size = 0.006
	sp.scale = Vector3.ZERO
	return sp


func _pop_rise_fade(sp: Sprite3D) -> void:
	# Shared "icon over the head" feel: pop in, hold, then drift up and fade.
	var tw := sp.create_tween()
	tw.tween_property(sp, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_property(sp, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(sp, "position:y", 0.25, 1.0)
	tw.tween_callback(sp.queue_free)


func _spawn_heart() -> void:
	## A heart floats above the head — the universal "healed" icon.
	var sp := _make_icon_sprite(_tex_heart())
	_shield_anchor.add_child(sp)
	_pop_rise_fade(sp)


func _spawn_armor_icon() -> void:
	## An armour/shield symbol over the head — shown whenever armour is gained.
	_spawn_shield()


func _spawn_fangs() -> void:
	## A pair of fangs floats above the head (Life Steal).
	var sp := _make_icon_sprite(_tex_fangs())
	_shield_anchor.add_child(sp)
	_pop_rise_fade(sp)


func _spawn_voice(text: String, color: Color = Color(1.0, 1.0, 1.0)) -> void:
	## A shouted line that pops above the head and fades.
	var lbl := Label3D.new()
	lbl.text = text
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.render_priority = 50
	lbl.modulate = color
	lbl.outline_size = 10
	lbl.outline_modulate = Color(0.05, 0.04, 0.06, 0.95)
	lbl.font_size = 64
	lbl.pixel_size = 0.0017
	lbl.position = Vector3(0, 0.4, 0)
	lbl.scale = Vector3.ZERO
	_shield_anchor.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(lbl, "position:y", 0.6, 0.4)
	tw.tween_callback(lbl.queue_free)


func _spawn_sparkles(local_pos: Vector3) -> void:
	## A small twinkle of sparkles at a body-local position (Harden's pauldrons).
	for i in range(5):
		var sp := _make_icon_sprite(_tex_sparkle())
		sp.pixel_size = 0.004
		sp.position = local_pos + Vector3(randf_range(-0.1, 0.1), randf_range(-0.08, 0.08), randf_range(0.0, 0.12))
		_body.add_child(sp)
		var peak := randf_range(0.5, 1.0)
		var tw := sp.create_tween()
		tw.tween_interval(i * 0.07)
		tw.tween_property(sp, "scale", Vector3.ONE * peak, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(sp, "scale", Vector3.ZERO, 0.22)
		tw.tween_callback(sp.queue_free)


func _spawn_dirt() -> void:
	## Brown puffs kicked up at the feet.
	for i in range(7):
		var sp := _make_icon_sprite(_tex_puff(Color(0.45, 0.34, 0.22)))
		sp.pixel_size = 0.005
		sp.position = Vector3(randf_range(-0.22, 0.22), 0.06, randf_range(0.1, 0.3))
		sp.scale = Vector3.ONE * randf_range(0.4, 0.9)
		_body.add_child(sp)
		var tw := sp.create_tween()
		var dest := sp.position + Vector3(randf_range(-0.2, 0.2), randf_range(0.25, 0.45), randf_range(0.0, 0.2))
		tw.tween_property(sp, "position", dest, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sp, "modulate:a", 0.0, 0.4)
		tw.tween_callback(sp.queue_free)


func _spawn_white_impact(z_forward: float, scale_mult: float = 1.0) -> void:
	## A bright white burst — a hit landing / knockback flash.
	var sp := _make_icon_sprite(_tex_burst())
	sp.pixel_size = 0.011
	sp.position = Vector3(0, 0.6, z_forward)
	_body.add_child(sp)
	var tw := sp.create_tween()
	tw.tween_property(sp, "scale", Vector3.ONE * (1.7 * scale_mult), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sp, "modulate:a", 0.0, 0.28)
	tw.tween_callback(sp.queue_free)


func _spawn_ground_crack() -> void:
	## A cracked-earth decal that splits the ground at the feet.
	var sp := _make_icon_sprite(_tex_crack())
	sp.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sp.pixel_size = 0.013
	sp.rotation_degrees = Vector3(-90, 0, 0)
	sp.position = Vector3(0, 0.02, 0.25)
	_body.add_child(sp)
	var tw := sp.create_tween()
	tw.tween_property(sp, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_property(sp, "modulate:a", 0.0, 0.6)
	tw.tween_callback(sp.queue_free)


func _spawn_blood(local_pos: Vector3) -> void:
	## Blood squirting from a wound.
	for i in range(6):
		var sp := _make_icon_sprite(_tex_puff(Color(0.62, 0.05, 0.07)))
		sp.pixel_size = 0.005
		sp.position = local_pos
		sp.scale = Vector3.ONE * randf_range(0.3, 0.7)
		_body.add_child(sp)
		var tw := sp.create_tween()
		var dest := local_pos + Vector3(randf_range(-0.25, 0.25), randf_range(-0.1, 0.2), randf_range(0.1, 0.35))
		tw.tween_property(sp, "position", dest, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sp, "modulate:a", 0.0, 0.35)
		tw.tween_callback(sp.queue_free)


func _spawn_blood_drop() -> void:
	## A single drop falling from the raised dagger down onto the face.
	var sp := _make_icon_sprite(_tex_puff(Color(0.62, 0.05, 0.07)))
	sp.pixel_size = 0.004
	sp.position = Vector3(0, 1.55, 0.2)
	sp.scale = Vector3.ONE * 0.55
	_body.add_child(sp)
	var tw := sp.create_tween()
	tw.tween_property(sp, "position:y", 1.05, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(sp, "modulate:a", 0.0, 0.12)
	tw.tween_callback(sp.queue_free)


func _spawn_essence_motes(color: Color) -> void:
	## Glowing motes drawn inward toward the raised hands (Absorb Essence / Vines).
	for i in range(8):
		var sp := _make_icon_sprite(_tex_puff(color))
		sp.pixel_size = 0.004
		# Start scattered around the body, drift up into the overhead hands.
		var ang := randf() * TAU
		var rad := randf_range(0.35, 0.7)
		sp.position = Vector3(cos(ang) * rad, randf_range(0.2, 0.9), sin(ang) * rad)
		sp.scale = Vector3.ONE * randf_range(0.4, 0.9)
		_body.add_child(sp)
		var tw := sp.create_tween()
		tw.tween_interval(i * 0.05)
		tw.tween_property(sp, "position", Vector3(0, 1.4, 0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(sp, "modulate:a", 0.0, 0.5)
		tw.tween_callback(sp.queue_free)


func _spawn_energy_ball(size: float = 1.0) -> void:
	## A glowing orb that forms in the hands and launches forward at the enemy.
	## `size` scales the orb (driven by the damage being dealt).
	var sp := _make_icon_sprite(_tex_puff(Color(0.5, 0.8, 1.0)))
	sp.render_priority = 45
	sp.pixel_size = 0.012
	var s: float = clampf(size, 0.5, 2.5)
	sp.position = Vector3(0, 0.7, 0.28)
	_body.add_child(sp)
	var tw := sp.create_tween()
	# Form in the hands.
	tw.tween_property(sp, "scale", Vector3.ONE * s, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Launch forward.
	tw.tween_property(sp, "position:z", 2.4, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(sp, "modulate:a", 0.0, 0.26)
	tw.tween_callback(sp.queue_free)


func _spawn_return_spark() -> void:
	## A blue spark born at the enemy that streaks back into the player.
	var sp := _make_icon_sprite(_tex_burst())
	sp.modulate = Color(0.45, 0.7, 1.0)
	sp.render_priority = 45
	sp.pixel_size = 0.008
	sp.position = Vector3(0, 0.7, 2.2)
	_body.add_child(sp)
	var tw := sp.create_tween()
	tw.tween_property(sp, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Streak back toward the player's chest.
	tw.tween_property(sp, "position", Vector3(0, 0.66, 0.12), 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(sp, "scale", Vector3.ZERO, 0.14)
	tw.tween_callback(sp.queue_free)


func _spawn_colored_smoke(local_pos: Vector3, color: Color, count: int = 8, pixel: float = 0.007, spread: float = 0.4) -> void:
	## A puff of coloured smoke bursting outward from a body-local point.
	for i in range(count):
		var sp := _make_icon_sprite(_tex_puff(color))
		sp.pixel_size = pixel
		sp.position = local_pos
		sp.scale = Vector3.ONE * randf_range(0.4, 1.0)
		_body.add_child(sp)
		var tw := sp.create_tween()
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.4, 1.0), randf_range(-1, 1)).normalized()
		var dest := local_pos + dir * randf_range(spread * 0.5, spread)
		tw.tween_property(sp, "position", dest, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sp, "scale", Vector3.ONE * randf_range(1.0, 1.6), 0.45)
		tw.parallel().tween_property(sp, "modulate:a", 0.0, 0.45)
		tw.tween_callback(sp.queue_free)


# =============================================================
# HELD PROPS (beaker, droplets, shuriken, pouch)
# =============================================================

func _build_beaker(parent: Node3D, liquid_col: Color) -> Dictionary:
	## A small glass beaker with coloured liquid, parented into a hand anchor.
	## Tracked in _temp_props so it is cleaned up on the next action.
	var root := Node3D.new()
	root.name = "Beaker"
	root.position = Vector3(0, -0.05, 0.05)
	parent.add_child(root)
	_temp_props.append(root)
	var glass := _make_cyl("BeakerGlass", Vector3(0, 0, 0), 0.05, 0.05, 0.16, Color(0.82, 0.86, 0.92))
	var gm := glass.material_override as StandardMaterial3D
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(0.82, 0.86, 0.92, 0.32)
	root.add_child(glass)
	var liquid := _make_cyl("BeakerLiquid", Vector3(0, -0.03, 0), 0.043, 0.043, 0.09, liquid_col)
	root.add_child(liquid)
	return {"root": root, "liquid": liquid}


func _spawn_droplet(beaker_root: Node3D, color: Color) -> void:
	## A single drop that falls from above into the beaker.
	if not is_instance_valid(beaker_root):
		return
	var sp := _make_icon_sprite(_tex_puff(color))
	sp.pixel_size = 0.004
	sp.position = Vector3(0, 0.16, 0)
	sp.scale = Vector3.ONE * 0.5
	beaker_root.add_child(sp)
	var tw := sp.create_tween()
	tw.tween_property(sp, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(sp, "modulate:a", 0.0, 0.1)
	tw.tween_callback(sp.queue_free)


func _spawn_beaker_fizz(beaker_root: Node3D, color: Color) -> void:
	## A little fizz of bubbles rising from the beaker as the liquid transforms.
	if not is_instance_valid(beaker_root):
		return
	for i in range(6):
		var sp := _make_icon_sprite(_tex_puff(color.lightened(0.2)))
		sp.pixel_size = 0.003
		sp.position = Vector3(randf_range(-0.03, 0.03), 0.02, randf_range(-0.03, 0.03))
		sp.scale = Vector3.ONE * randf_range(0.3, 0.6)
		beaker_root.add_child(sp)
		var tw := sp.create_tween()
		tw.tween_interval(i * 0.04)
		tw.tween_property(sp, "position:y", 0.16, 0.3).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(sp, "modulate:a", 0.0, 0.3)
		tw.tween_callback(sp.queue_free)


func _spawn_shuriken() -> void:
	## A spinning throwing star that streaks forward at the enemy.
	var sp := _make_icon_sprite(_tex_shuriken())
	sp.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sp.render_priority = 45
	sp.pixel_size = 0.006
	sp.scale = Vector3.ONE
	sp.position = Vector3(0.2, 0.85, 0.2)
	_body.add_child(sp)
	var tw := sp.create_tween()
	tw.tween_property(sp, "position", Vector3(0, 0.7, 2.6), 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sp, "rotation_degrees:z", 1440.0, 0.34)
	tw.parallel().tween_property(sp, "modulate:a", 0.0, 0.34).set_delay(0.2)
	tw.tween_callback(sp.queue_free)


func _spawn_pouch_toss() -> void:
	## A small pouch tossed up, arcing back down to the waist, then vanishing.
	var pouch := _make_box_solid("Pouch", Vector3.ZERO, Vector3(0.11, 0.13, 0.08), Color(0.4, 0.29, 0.18))
	pouch.position = Vector3(0.25, 0.5, 0.12)
	_body.add_child(pouch)
	# A drawstring tie on top.
	var tie := _make_box_solid("PouchTie", Vector3(0, 0.08, 0), Vector3(0.04, 0.04, 0.04), Color(0.55, 0.45, 0.3))
	pouch.add_child(tie)
	var tw := pouch.create_tween()
	# Up...
	tw.tween_property(pouch, "position", Vector3(0.12, 1.25, 0.12), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pouch, "rotation_degrees:x", 180.0, 0.4)
	# ...and back down to the waist (the "catch").
	tw.tween_property(pouch, "position", Vector3(0.0, 0.5, 0.14), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Vanish.
	tw.tween_property(pouch, "scale", Vector3.ZERO, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(pouch.queue_free)


# ---- procedural icon textures ---------------------------------------------

func _tex_heart() -> ImageTexture:
	var w := 32
	var h := 30
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col := Color(0.92, 0.16, 0.24)
	var edge := Color(0.6, 0.05, 0.12)
	for py in range(h):
		for px in range(w):
			var x := (float(px) / float(w - 1)) * 2.0 - 1.0
			var y := 1.0 - (float(py) / float(h - 1)) * 2.0
			x *= 1.15
			y = y * 1.15 + 0.32
			var f := pow(x * x + y * y - 1.0, 3.0) - x * x * pow(y, 3.0)
			if f <= 0.0:
				img.set_pixel(px, py, edge if f > -0.25 else col)
	return ImageTexture.create_from_image(img)


func _tex_fangs() -> ImageTexture:
	var w := 32
	var h := 24
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col := Color(0.96, 0.96, 1.0)
	for py in range(h):
		var v := float(py) / float(h - 1)  # 0 top .. 1 tip
		for center in [0.32, 0.68]:
			var cx: float = center * w
			var halfw := (1.0 - v) * 0.11 * w
			for px in range(int(cx - halfw), int(cx + halfw) + 1):
				if px >= 0 and px < w and v < 0.96:
					img.set_pixel(px, py, col)
	return ImageTexture.create_from_image(img)


func _tex_sparkle() -> ImageTexture:
	var s := 16
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col := Color(1.0, 0.97, 0.7)
	var c := (s - 1) / 2.0
	for py in range(s):
		for px in range(s):
			var dx := absf(px - c)
			var dy := absf(py - c)
			if (dx < 1.4 and dy < 7.0) or (dy < 1.4 and dx < 7.0) or (dx + dy < 3.0):
				img.set_pixel(px, py, col)
	return ImageTexture.create_from_image(img)


func _tex_burst() -> ImageTexture:
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (s - 1) / 2.0
	for py in range(s):
		for px in range(s):
			var dx := px - c
			var dy := py - c
			var r := sqrt(dx * dx + dy * dy) / c
			if r > 1.0:
				continue
			var ang := atan2(dy, dx)
			var spokes := pow(absf(cos(ang * 4.0)), 6.0)
			var reach := 0.35 + 0.65 * spokes
			if r <= reach:
				var a: float = clamp((1.0 - r / reach) * 1.3, 0.0, 1.0)
				img.set_pixel(px, py, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


func _tex_crack() -> ImageTexture:
	var s := 48
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (s - 1) / 2.0
	for py in range(s):
		for px in range(s):
			var dx := px - c
			var dy := py - c
			var r := sqrt(dx * dx + dy * dy) / c
			if r < 0.08 or r > 0.96:
				continue
			var ang := atan2(dy, dx)
			var line := absf(sin(ang * 3.0 + sin(r * 7.0) * 0.7))
			if line < 0.13:
				var a := (1.0 - r) * 0.85
				img.set_pixel(px, py, Color(0.06, 0.05, 0.04, a))
	return ImageTexture.create_from_image(img)


func _tex_shuriken() -> ImageTexture:
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (s - 1) / 2.0
	var metal := Color(0.78, 0.81, 0.88)
	var edge := Color(0.42, 0.45, 0.54)
	for py in range(s):
		for px in range(s):
			var dx := px - c
			var dy := py - c
			var r := sqrt(dx * dx + dy * dy) / c
			if r > 1.0:
				continue
			var ang := atan2(dy, dx)
			# Four sharp points along the axes (abs(cos(2a)) has four lobes).
			var reach := 0.34 + 0.66 * pow(absf(cos(ang * 2.0)), 2.2)
			if r <= reach and r > 0.14:  # centre hole
				img.set_pixel(px, py, edge if r > reach - 0.12 else metal)
	return ImageTexture.create_from_image(img)


func _tex_puff(color: Color) -> ImageTexture:
	var s := 16
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (s - 1) / 2.0
	for py in range(s):
		for px in range(s):
			var dx := px - c
			var dy := py - c
			var r := sqrt(dx * dx + dy * dy) / c
			if r <= 1.0:
				img.set_pixel(px, py, Color(color.r, color.g, color.b, (1.0 - r * r) * color.a))
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
	_body.position = Vector3.ZERO
	_body.scale = Vector3.ONE
	_head.rotation_degrees = Vector3.ZERO
	# Feet back to their built rest positions (see _build).
	_left_foot.position = Vector3(-0.11, 0.05, 0.04)
	_right_foot.position = Vector3(0.11, 0.05, 0.04)
	_left_foot.rotation_degrees = Vector3.ZERO
	_right_foot.rotation_degrees = Vector3.ZERO
	if _has_shield and is_instance_valid(_shield_grip):
		_shield_grip.position = Vector3.ZERO
		_shield_grip.rotation_degrees = Vector3.ZERO
	# Clear any held props left over from a previous (possibly interrupted) action.
	for p in _temp_props:
		if is_instance_valid(p):
			p.queue_free()
	_temp_props.clear()
