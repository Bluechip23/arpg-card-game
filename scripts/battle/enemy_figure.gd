class_name EnemyFigure
extends Node3D

## Procedural 3D enemy models in the same chunky "SNES RPG" style as
## CharacterFigure, replacing the old sprite-sheet placeholders.
##
## Kinds: "skeleton", "rat", "archer_rat", "armored_troll".
##
## The archer rat is special: it stands on its hind legs holding a bow while idle
## / attacking, and drops to all fours with the bow slung on its back while moving
## (set_walking toggles between the two poses).
##
## Animations are procedural (Tweens). enemy.gd drives them via play_action(),
## set_walking() and flash().

var _kind: String = ""
var _built: bool = false
var _busy: bool = false
var _walking: bool = false
var _time: float = 0.0

var _bob_node: Node3D = null          # node that bobs while idle
var _bob_y: float = 0.0
var _atk_pivot: Node3D = null         # node swung/lurched on attack
var _atk_rest: Vector3 = Vector3.ZERO

# Archer-rat pose state
var _ar_torso: Node3D = null
var _ar_bow_front: Node3D = null
var _ar_bow_back: Node3D = null

# Hydra neck pivots (centre neck drives the attack lunge)
var _hydra_necks: Array = []
const AR_STAND := -74.0
const AR_QUAD := -6.0

var _action_tween: Tween = null
var _pose_tween: Tween = null


func _ready() -> void:
	if _kind != "" and not _built:
		_build()


func setup(kind: String) -> void:
	_kind = kind
	if is_inside_tree() and not _built:
		_build()


# =============================================================
# BUILD
# =============================================================

func _build() -> void:
	if _built:
		return
	match _kind:
		"skeleton": _build_skeleton()
		"rat": _build_rat()
		"archer_rat": _build_archer_rat()
		"armored_troll": _build_troll()
		"hydra": _build_hydra()
		"fire_goblin_soldier": _build_goblin("soldier", Color.html("d95a26"))
		"fire_goblin_mage": _build_goblin("mage", Color.html("e6731f"))
		"fire_goblin_shaman": _build_goblin("shaman", Color.html("f28c40"))
		_: _build_rat()
	_built = true


func _mat(c: Color, emissive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.65
	m.metallic = 0.0
	if emissive:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.2
	return m


func _bx(parent: Node3D, n: String, pos: Vector3, size: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi


func _sp(parent: Node3D, n: String, pos: Vector3, r: float, c: Color, scl := Vector3.ONE, emissive := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	mi.mesh = s
	mi.position = pos
	mi.scale = scl
	mi.material_override = _mat(c, emissive)
	parent.add_child(mi)
	return mi


func _cy(parent: Node3D, n: String, pos: Vector3, top_r: float, bot_r: float, h: float, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var m := CylinderMesh.new()
	m.top_radius = top_r
	m.bottom_radius = bot_r
	m.height = h
	m.radial_segments = 10
	mi.mesh = m
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi


func _shadow(radius: float) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Shadow"
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.01
	cyl.radial_segments = 16
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0, 0, 0, 0.26)
	mi.material_override = mat
	mi.position = Vector3(0, 0.006, 0)
	add_child(mi)


# ---- Skeleton ------------------------------------------------

func _build_skeleton() -> void:
	_shadow(0.26)
	var bone := Color.html("e9e4d6")
	var dark := Color.html("17150f")
	var root := Node3D.new()
	root.name = "Body"
	add_child(root)
	_bob_node = root
	_bob_y = 0.0

	# Legs
	_cy(root, "LegL", Vector3(-0.08, 0.27, 0), 0.035, 0.04, 0.54, bone)
	_cy(root, "LegR", Vector3(0.08, 0.27, 0), 0.035, 0.04, 0.54, bone)
	_bx(root, "FootL", Vector3(-0.08, 0.03, 0.04), Vector3(0.09, 0.06, 0.16), bone)
	_bx(root, "FootR", Vector3(0.08, 0.03, 0.04), Vector3(0.09, 0.06, 0.16), bone)

	# Pelvis + spine
	_bx(root, "Pelvis", Vector3(0, 0.58, 0), Vector3(0.24, 0.12, 0.14), bone)
	_bx(root, "Spine", Vector3(0, 0.78, 0), Vector3(0.06, 0.30, 0.06), bone)

	# Ribcage (bone block + dark rib gaps on the front)
	_sp(root, "Ribcage", Vector3(0, 0.86, 0), 0.16, bone, Vector3(1.05, 1.15, 0.8))
	for i in range(3):
		_bx(root, "Rib%d" % i, Vector3(0, 0.80 + i * 0.07, 0.125), Vector3(0.24, 0.018, 0.02), dark)

	# Shoulders + arm bones (right arm swings on attack)
	var sh_l := Node3D.new(); sh_l.name = "ShoulderL"; sh_l.position = Vector3(-0.17, 1.0, 0); root.add_child(sh_l)
	_cy(sh_l, "ArmL", Vector3(0, -0.21, 0), 0.028, 0.03, 0.42, bone)
	_sp(sh_l, "HandL", Vector3(0, -0.44, 0), 0.04, bone)
	var sh_r := Node3D.new(); sh_r.name = "ShoulderR"; sh_r.position = Vector3(0.17, 1.0, 0); root.add_child(sh_r)
	_cy(sh_r, "ArmR", Vector3(0, -0.21, 0), 0.028, 0.03, 0.42, bone)
	_sp(sh_r, "HandR", Vector3(0, -0.44, 0), 0.04, bone)
	_atk_pivot = sh_r
	_atk_rest = Vector3.ZERO

	# Skull
	_sp(root, "Skull", Vector3(0, 1.18, 0.01), 0.145, bone, Vector3(1.0, 1.05, 1.0))
	_bx(root, "Jaw", Vector3(0, 1.08, 0.03), Vector3(0.15, 0.05, 0.13), bone)
	_sp(root, "SocketL", Vector3(-0.055, 1.19, 0.115), 0.038, dark)
	_sp(root, "SocketR", Vector3(0.055, 1.19, 0.115), 0.038, dark)
	_bx(root, "Nose", Vector3(0, 1.14, 0.13), Vector3(0.03, 0.04, 0.02), dark)


# ---- Rat -----------------------------------------------------

func _build_rat() -> void:
	_build_rat_into(self, 1.0)
	_bob_node = get_node("RatBody")
	_bob_y = _bob_node.position.y
	_atk_pivot = _bob_node
	_atk_rest = Vector3.ZERO


## Builds a quadruped rat under `parent` at the given scale. Returns the body node.
func _build_rat_into(parent: Node3D, s: float) -> Node3D:
	if parent == self:
		_shadow(0.22 * s)
	var fur := Color.html("6b6056")
	var pink := Color.html("d49a92")
	var dark := Color.html("141019")
	var body := Node3D.new()
	body.name = "RatBody"
	body.position = Vector3(0, 0.22 * s, 0)
	parent.add_child(body)

	# Torso (elongated along Z)
	_sp(body, "Torso", Vector3(0, 0, 0), 0.18 * s, fur, Vector3(0.92, 0.82, 1.45))
	# Legs
	for leg in [["FL", 0.10, 0.20], ["FR", -0.10, 0.20], ["BL", 0.10, -0.18], ["BR", -0.10, -0.18]]:
		_cy(body, "Leg" + str(leg[0]), Vector3(leg[1] * s, -0.20 * s, leg[2] * s), 0.028 * s, 0.03 * s, 0.20 * s, fur)
		_sp(body, "Paw" + str(leg[0]), Vector3(leg[1] * s, -0.30 * s, (leg[2] + 0.02) * s), 0.035 * s, pink)
	# Head + snout
	_sp(body, "Head", Vector3(0, 0.03 * s, 0.27 * s), 0.13 * s, fur)
	_bx(body, "Snout", Vector3(0, -0.01 * s, 0.38 * s), Vector3(0.09 * s, 0.08 * s, 0.10 * s), fur)
	_sp(body, "Nose", Vector3(0, -0.01 * s, 0.44 * s), 0.025 * s, pink)
	# Ears
	_sp(body, "EarL", Vector3(-0.08 * s, 0.14 * s, 0.24 * s), 0.06 * s, pink, Vector3(1, 1, 0.4))
	_sp(body, "EarR", Vector3(0.08 * s, 0.14 * s, 0.24 * s), 0.06 * s, pink, Vector3(1, 1, 0.4))
	# Eyes
	_sp(body, "EyeL", Vector3(-0.075 * s, 0.05 * s, 0.34 * s), 0.025 * s, dark)
	_sp(body, "EyeR", Vector3(0.075 * s, 0.05 * s, 0.34 * s), 0.025 * s, dark)
	# Tail (sweeps back and up)
	_cy(body, "Tail", Vector3(0, 0.05 * s, -0.34 * s), 0.008 * s, 0.035 * s, 0.5 * s, pink, Vector3(55, 0, 0))
	return body


# ---- Archer Rat ----------------------------------------------

func _build_archer_rat() -> void:
	_shadow(0.2)
	var fur := Color.html("7a5a48")
	var pink := Color.html("d49a92")
	var dark := Color.html("141019")
	var wood := Color.html("6b4a2a")
	var string_c := Color.html("dcdce0")

	var root := Node3D.new()
	root.name = "Body"
	add_child(root)
	_bob_node = root

	# Hind legs (always on the ground, support standing)
	_cy(root, "HindL", Vector3(-0.09, 0.13, -0.04), 0.035, 0.04, 0.26, fur)
	_cy(root, "HindR", Vector3(0.09, 0.13, -0.04), 0.035, 0.04, 0.26, fur)
	_sp(root, "FootL", Vector3(-0.09, 0.02, 0.04), 0.05, pink, Vector3(1, 0.6, 1.4))
	_sp(root, "FootR", Vector3(0.09, 0.02, 0.04), 0.05, pink, Vector3(1, 0.6, 1.4))

	# Torso pivots at the hips between upright (standing) and horizontal (all-fours)
	_ar_torso = Node3D.new()
	_ar_torso.name = "Torso"
	_ar_torso.position = Vector3(0, 0.24, -0.03)
	_ar_torso.rotation_degrees = Vector3(AR_STAND, 0, 0)
	root.add_child(_ar_torso)

	# Body extends along +Z (becomes "up" when standing)
	_sp(_ar_torso, "Chest", Vector3(0, 0, 0.16), 0.15, fur, Vector3(0.95, 0.85, 1.3))
	_sp(_ar_torso, "Head", Vector3(0, 0.0, 0.40), 0.12, fur)
	_bx(_ar_torso, "Snout", Vector3(0, -0.03, 0.50), Vector3(0.08, 0.07, 0.09), fur)
	_sp(_ar_torso, "Nose", Vector3(0, -0.03, 0.55), 0.022, pink)
	_sp(_ar_torso, "EarL", Vector3(-0.08, 0.10, 0.40), 0.055, pink, Vector3(1, 1, 0.4))
	_sp(_ar_torso, "EarR", Vector3(0.08, 0.10, 0.40), 0.055, pink, Vector3(1, 1, 0.4))
	_sp(_ar_torso, "EyeL", Vector3(-0.07, 0.02, 0.46), 0.022, dark)
	_sp(_ar_torso, "EyeR", Vector3(0.07, 0.02, 0.46), 0.022, dark)
	# Tail off the lower back
	_cy(_ar_torso, "Tail", Vector3(0, 0.02, -0.12), 0.008, 0.03, 0.34, pink, Vector3(-40, 0, 0))

	# Front limbs (point -Y in torso space: down to ground when on all fours,
	# forward holding the bow when standing).
	_cy(_ar_torso, "ArmL", Vector3(-0.09, -0.12, 0.30), 0.026, 0.03, 0.22, fur)
	_cy(_ar_torso, "ArmR", Vector3(0.09, -0.12, 0.30), 0.026, 0.03, 0.22, fur)

	# Bow held in front of the paws (visible while standing)
	_ar_bow_front = Node3D.new()
	_ar_bow_front.name = "BowFront"
	_ar_bow_front.position = Vector3(0, -0.22, 0.32)
	_ar_torso.add_child(_ar_bow_front)
	_build_bow(_ar_bow_front, wood, string_c)

	# Bow slung on the back (visible while on all fours)
	_ar_bow_back = Node3D.new()
	_ar_bow_back.name = "BowBack"
	_ar_bow_back.position = Vector3(0, 0.14, 0.08)
	_ar_bow_back.rotation_degrees = Vector3(0, 0, 90)
	_ar_torso.add_child(_ar_bow_back)
	_build_bow(_ar_bow_back, wood, string_c)
	_ar_bow_back.visible = false


func _build_bow(parent: Node3D, wood: Color, string_c: Color) -> void:
	# A small vertical recurve bow centred on the parent.
	_bx(parent, "Grip", Vector3(0, 0, 0), Vector3(0.03, 0.16, 0.04), wood)
	_bx(parent, "LimbT", Vector3(0.02, 0.15, 0), Vector3(0.028, 0.16, 0.04), wood, Vector3(0, 0, 22))
	_bx(parent, "LimbB", Vector3(0.02, -0.15, 0), Vector3(0.028, 0.16, 0.04), wood, Vector3(0, 0, -22))
	_bx(parent, "String", Vector3(-0.05, 0, 0.01), Vector3(0.008, 0.42, 0.008), string_c)


# ---- Armored Troll -------------------------------------------

func _build_troll() -> void:
	_shadow(0.36)
	var skin := Color.html("6f7a52")
	var belly := Color.html("9aa86a")
	var dark := Color.html("141019")
	var silver := Color.html("c8ccd6")
	var wood := Color.html("6b4a2a")
	var tusk := Color.html("eee8d5")

	var root := Node3D.new()
	root.name = "Body"
	add_child(root)
	_bob_node = root

	# Legs + feet
	_bx(root, "LegL", Vector3(-0.17, 0.28, 0), Vector3(0.22, 0.56, 0.24), skin)
	_bx(root, "LegR", Vector3(0.17, 0.28, 0), Vector3(0.22, 0.56, 0.24), skin)
	_bx(root, "FootL", Vector3(-0.17, 0.06, 0.07), Vector3(0.24, 0.13, 0.32), dark)
	_bx(root, "FootR", Vector3(0.17, 0.06, 0.07), Vector3(0.24, 0.13, 0.32), dark)

	# Torso (broad, hunched) + lighter belly
	var torso := _bx(root, "Torso", Vector3(0, 0.92, -0.02), Vector3(0.62, 0.6, 0.44), skin)
	torso.rotation_degrees = Vector3(8, 0, 0)
	_sp(root, "Belly", Vector3(0, 0.84, 0.16), 0.2, belly, Vector3(1.2, 1.0, 0.6))

	# Head
	_sp(root, "Head", Vector3(0, 1.38, 0.05), 0.22, skin)
	_bx(root, "Brow", Vector3(0, 1.46, 0.19), Vector3(0.4, 0.07, 0.1), dark)
	_sp(root, "EyeL", Vector3(-0.09, 1.4, 0.21), 0.03, dark)
	_sp(root, "EyeR", Vector3(0.09, 1.4, 0.21), 0.03, dark)
	_cy(root, "TuskL", Vector3(-0.08, 1.28, 0.21), 0.0, 0.03, 0.12, tusk, Vector3(20, 0, 0))
	_cy(root, "TuskR", Vector3(0.08, 1.28, 0.21), 0.0, 0.03, 0.12, tusk, Vector3(20, 0, 0))

	# Arms (boxes). Right arm holds the club and swings on attack.
	var sh_l := Node3D.new(); sh_l.name = "ShoulderL"; sh_l.position = Vector3(-0.34, 1.16, 0); root.add_child(sh_l)
	_bx(sh_l, "ArmL", Vector3(0, -0.26, 0.02), Vector3(0.18, 0.52, 0.18), skin)
	_sp(sh_l, "FistL", Vector3(0, -0.54, 0.04), 0.11, skin)
	var sh_r := Node3D.new(); sh_r.name = "ShoulderR"; sh_r.position = Vector3(0.34, 1.16, 0); root.add_child(sh_r)
	_bx(sh_r, "ArmR", Vector3(0, -0.26, 0.02), Vector3(0.18, 0.52, 0.18), skin)
	_sp(sh_r, "FistR", Vector3(0, -0.54, 0.04), 0.11, skin)
	_atk_pivot = sh_r
	_atk_rest = Vector3.ZERO

	# Silver pauldrons, set on top of the shoulders (clear of the head)
	_sp(root, "PauldronL", Vector3(-0.37, 1.26, 0), 0.15, silver, Vector3(1.2, 0.8, 1.2))
	_sp(root, "PauldronR", Vector3(0.37, 1.26, 0), 0.15, silver, Vector3(1.2, 0.8, 1.2))

	# Club, gripped in the right fist and carried up over the shoulder.
	var club := Node3D.new()
	club.name = "Club"
	club.position = Vector3(0.08, -0.5, 0.14)
	club.rotation_degrees = Vector3(150, 0, 8)
	sh_r.add_child(club)
	_cy(club, "Haft", Vector3(0, 0.2, 0), 0.055, 0.045, 0.5, wood)
	_cy(club, "Head", Vector3(0, 0.52, 0), 0.14, 0.10, 0.28, wood)
	_sp(club, "Knob0", Vector3(0.1, 0.56, 0.02), 0.055, wood)
	_sp(club, "Knob1", Vector3(-0.09, 0.5, -0.04), 0.055, wood)
	_sp(club, "Knob2", Vector3(0.03, 0.64, 0.08), 0.05, wood)


# ---- Hydra (three-headed serpent boss) -----------------------

func _build_hydra() -> void:
	_shadow(0.42)
	var green := Color.html("2f8c57")
	var dark := Color.html("1c5638")
	var belly := Color.html("6cbf8a")
	var eye := Color.html("ffd23f")

	var root := Node3D.new()
	root.name = "Body"
	add_child(root)
	_bob_node = root

	_sp(root, "Body", Vector3(0, 0.52, -0.02), 0.36, green, Vector3(1.5, 0.95, 1.75))
	_sp(root, "Belly", Vector3(0, 0.36, 0.26), 0.24, belly, Vector3(1.25, 0.85, 0.7))

	for i in range(4):
		_cy(root, "Spine%d" % i, Vector3(0, 0.78 - i * 0.02, -0.1 - i * 0.12), 0.0, 0.04, 0.14, dark, Vector3(-30, 0, 0))

	for sx in [-1, 1]:
		_bx(root, "Leg%d" % sx, Vector3(0.24 * sx, 0.16, 0.26), Vector3(0.16, 0.32, 0.18), green)
		for cz in [-0.05, 0.0, 0.05]:
			_cy(root, "Claw%d_%d" % [sx, int(cz * 100)], Vector3(0.24 * sx + cz, 0.03, 0.38), 0.0, 0.02, 0.08, dark, Vector3(80, 0, 0))

	_cy(root, "Tail", Vector3(0, 0.5, -0.42), 0.02, 0.12, 0.6, green, Vector3(-55, 0, 0))

	_hydra_neck(root, Vector3(0, 0.84, 0.16), 12, 0, 0.68, green, dark, belly, eye)
	_hydra_neck(root, Vector3(-0.22, 0.78, 0.12), 8, 24, 0.6, green, dark, belly, eye)
	_hydra_neck(root, Vector3(0.22, 0.78, 0.12), 8, -24, 0.6, green, dark, belly, eye)
	_atk_pivot = _hydra_necks[0]
	_atk_rest = _atk_pivot.rotation_degrees


func _hydra_neck(parent: Node3D, base: Vector3, pitch: float, roll: float, length: float, green: Color, dark: Color, belly: Color, eye: Color) -> void:
	var pivot := Node3D.new()
	pivot.name = "Neck%d" % _hydra_necks.size()
	pivot.position = base
	pivot.rotation_degrees = Vector3(pitch, 0, roll)
	parent.add_child(pivot)
	_hydra_necks.append(pivot)

	_cy(pivot, "Neck", Vector3(0, length * 0.5, 0), 0.05, 0.08, length, green)
	_cy(pivot, "Throat", Vector3(0, length * 0.5, 0.04), 0.035, 0.06, length * 0.9, belly)
	var h := Vector3(0, length, 0.0)
	_sp(pivot, "Head", h + Vector3(0, 0.02, 0.02), 0.1, green, Vector3(1.0, 0.95, 1.4))
	_bx(pivot, "Snout", h + Vector3(0, -0.02, 0.16), Vector3(0.1, 0.07, 0.12), green)
	_sp(pivot, "EyeL", h + Vector3(-0.06, 0.06, 0.08), 0.026, eye, Vector3.ONE, true)
	_sp(pivot, "EyeR", h + Vector3(0.06, 0.06, 0.08), 0.026, eye, Vector3.ONE, true)
	_cy(pivot, "HornL", h + Vector3(-0.05, 0.12, -0.02), 0.0, 0.022, 0.1, dark, Vector3(-25, 0, -12))
	_cy(pivot, "HornR", h + Vector3(0.05, 0.12, -0.02), 0.0, 0.022, 0.1, dark, Vector3(-25, 0, 12))


# ---- Fire Goblins (soldier / mage / shaman) ------------------

func _build_goblin(role: String, skin: Color) -> void:
	_shadow(0.2)
	var dark := Color.html("3a2418")
	var cloth := Color.html("5a3a22")
	var eye := Color.html("ffe04a")
	var steel := Color.html("b9bdc6")
	var wood := Color.html("6b4a2a")
	var bone := Color.html("e9e4d6")

	var root := Node3D.new()
	root.name = "Body"
	add_child(root)
	_bob_node = root

	_bx(root, "LegL", Vector3(-0.08, 0.14, 0), Vector3(0.1, 0.28, 0.1), skin)
	_bx(root, "LegR", Vector3(0.08, 0.14, 0), Vector3(0.1, 0.28, 0.1), skin)
	_bx(root, "FootL", Vector3(-0.08, 0.03, 0.04), Vector3(0.12, 0.06, 0.16), dark)
	_bx(root, "FootR", Vector3(0.08, 0.03, 0.04), Vector3(0.12, 0.06, 0.16), dark)
	_bx(root, "Cloth", Vector3(0, 0.32, 0.01), Vector3(0.3, 0.13, 0.22), cloth)
	var torso := _bx(root, "Torso", Vector3(0, 0.5, 0), Vector3(0.28, 0.3, 0.2), skin)
	torso.rotation_degrees = Vector3(6, 0, 0)

	var sh_l := Node3D.new(); sh_l.name = "ShoulderL"; sh_l.position = Vector3(-0.16, 0.62, 0); root.add_child(sh_l)
	_cy(sh_l, "ArmL", Vector3(0, -0.16, 0.02), 0.04, 0.045, 0.32, skin)
	_sp(sh_l, "HandL", Vector3(0, -0.34, 0.04), 0.05, skin)
	var sh_r := Node3D.new(); sh_r.name = "ShoulderR"; sh_r.position = Vector3(0.16, 0.62, 0); root.add_child(sh_r)
	_cy(sh_r, "ArmR", Vector3(0, -0.16, 0.02), 0.04, 0.045, 0.32, skin)
	_sp(sh_r, "HandR", Vector3(0, -0.34, 0.04), 0.05, skin)
	_atk_pivot = sh_r
	_atk_rest = Vector3.ZERO

	_sp(root, "Head", Vector3(0, 0.8, 0.02), 0.16, skin)
	_cy(root, "EarL", Vector3(-0.17, 0.84, -0.02), 0.0, 0.06, 0.22, skin, Vector3(-8, 0, 62))
	_cy(root, "EarR", Vector3(0.17, 0.84, -0.02), 0.0, 0.06, 0.22, skin, Vector3(-8, 0, -62))
	_cy(root, "Nose", Vector3(0, 0.79, 0.16), 0.0, 0.045, 0.14, skin, Vector3(70, 0, 0))
	_bx(root, "Brow", Vector3(0, 0.87, 0.13), Vector3(0.26, 0.04, 0.06), dark)
	_sp(root, "EyeL", Vector3(-0.06, 0.83, 0.14), 0.026, eye, Vector3.ONE, true)
	_sp(root, "EyeR", Vector3(0.06, 0.83, 0.14), 0.026, eye, Vector3.ONE, true)
	_bx(root, "Fang", Vector3(-0.03, 0.71, 0.14), Vector3(0.02, 0.04, 0.02), bone)

	match role:
		"soldier":
			_bx(sh_r, "Guard", Vector3(0, -0.34, 0.12), Vector3(0.12, 0.03, 0.04), dark)
			_bx(sh_r, "Blade", Vector3(0, -0.16, 0.12), Vector3(0.045, 0.36, 0.018), steel)
			_bx(sh_r, "Hilt", Vector3(0, -0.42, 0.12), Vector3(0.03, 0.1, 0.03), wood)
		"mage":
			var orb := _sp(sh_r, "Orb", Vector3(0.02, -0.42, 0.16), 0.09, Color.html("ff7a1a"), Vector3.ONE, true)
			(orb.material_override as StandardMaterial3D).emission_energy_multiplier = 2.0
			_sp(sh_r, "OrbCore", Vector3(0.02, -0.42, 0.16), 0.05, Color.html("ffe08a"), Vector3.ONE, true)
			_sp(root, "Hood", Vector3(0, 0.88, -0.03), 0.17, cloth, Vector3(1.05, 0.7, 1.05))
		"shaman":
			_cy(root, "Staff", Vector3(0.26, 0.5, 0.06), 0.022, 0.026, 0.82, wood)
			_sp(root, "Skull", Vector3(0.26, 0.93, 0.06), 0.06, bone)
			_cy(root, "Feather0", Vector3(0.22, 0.98, 0.04), 0.0, 0.03, 0.12, Color.html("c0392b"), Vector3(0, 0, 35))
			_cy(root, "Feather1", Vector3(0.3, 0.98, 0.04), 0.0, 0.03, 0.12, Color.html("e67e22"), Vector3(0, 0, -35))
			_sp(root, "Charm", Vector3(-0.14, 0.62, 0.1), 0.03, bone)


# =============================================================
# IDLE
# =============================================================

func _process(delta: float) -> void:
	if not _built or _busy or _bob_node == null:
		return
	_time += delta
	var freq := 5.0 if _walking else 2.0
	var amp := 0.02 if _walking else 0.012
	_bob_node.position.y = _bob_y + sin(_time * freq) * amp


# =============================================================
# PUBLIC API (driven by enemy.gd)
# =============================================================

func play_action(action: String) -> void:
	if not _built:
		return
	match action:
		"attack", "bite", "slam", "club", "shoot":
			play_attack()
		"move", "walk", "scurry":
			set_walking(true)
		"hit":
			play_hit()
		"idle", "stance":
			set_walking(false)
		_:
			pass


func set_walking(walking: bool) -> void:
	if walking == _walking:
		return
	_walking = walking
	if _kind == "archer_rat":
		_set_archer_pose(walking)


## Rotate the whole figure to face a cardinal direction. The models are built
## facing +Z (south / toward the camera), matching CharacterFigure.
func set_facing(direction: int) -> void:
	if not _built:
		return
	match direction:
		CharacterAnimator.Direction.SOUTH:
			rotation_degrees.y = 0.0
		CharacterAnimator.Direction.NORTH:
			rotation_degrees.y = 180.0
		CharacterAnimator.Direction.EAST:
			rotation_degrees.y = 90.0
		CharacterAnimator.Direction.WEST:
			rotation_degrees.y = -90.0


func set_facing_from_velocity(vel: Vector3) -> void:
	if vel.length_squared() < 0.01:
		return
	if abs(vel.x) > abs(vel.z):
		set_facing(CharacterAnimator.Direction.EAST if vel.x > 0 else CharacterAnimator.Direction.WEST)
	else:
		set_facing(CharacterAnimator.Direction.SOUTH if vel.z > 0 else CharacterAnimator.Direction.NORTH)


func play_attack() -> void:
	if not _built:
		return
	match _kind:
		"rat", "archer_rat":
			_lurch()
		"hydra":
			_hydra_attack()
		_:
			_arm_swing()


## Skeleton / troll / goblin: overhead swing of the right arm (+ weapon).
func _arm_swing() -> void:
	if _atk_pivot == null:
		return
	_cancel_action()
	_busy = true
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_action_tween.tween_property(_atk_pivot, "rotation_degrees:x", -140.0, 0.16).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_atk_pivot, "rotation_degrees:x", -25.0, 0.08).set_ease(Tween.EASE_IN)
	_action_tween.tween_property(_atk_pivot, "rotation_degrees:x", _atk_rest.x, 0.24).set_ease(Tween.EASE_OUT)
	_action_tween.tween_callback(func(): _busy = false)


## Hydra: lunge the body forward while the centre head snaps out to bite.
func _hydra_attack() -> void:
	if _bob_node == null:
		return
	_cancel_action()
	_busy = true
	var base := _bob_node.position
	_action_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_action_tween.tween_property(_bob_node, "position:z", base.z + 0.2, 0.1)
	if _atk_pivot:
		_action_tween.parallel().tween_property(_atk_pivot, "rotation_degrees:x", _atk_rest.x + 32.0, 0.1)
	_action_tween.tween_property(_bob_node, "position:z", base.z, 0.3)
	if _atk_pivot:
		_action_tween.parallel().tween_property(_atk_pivot, "rotation_degrees:x", _atk_rest.x, 0.3)
	_action_tween.tween_callback(func(): _busy = false)


func _lurch() -> void:
	# Quick forward lunge (rat bite / archer shot recoil).
	_cancel_action()
	_busy = true
	var base := _bob_node.position
	_action_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_action_tween.tween_property(_bob_node, "position:z", base.z + 0.18, 0.09)
	_action_tween.tween_property(_bob_node, "position:z", base.z, 0.2)
	_action_tween.tween_callback(func(): _busy = false)


func play_hit() -> void:
	if not _built or _bob_node == null:
		return
	_cancel_action()
	_busy = true
	var base := _bob_node.position
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_action_tween.tween_property(_bob_node, "position:z", base.z - 0.12, 0.07).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_bob_node, "position:z", base.z, 0.22)
	_action_tween.tween_callback(func(): _busy = false)


## Brief emission flash on every mesh (hit / heal feedback).
func flash(color: Color) -> void:
	for mi in _all_meshes(self):
		var sm := mi.material_override as StandardMaterial3D
		if sm == null:
			continue
		sm.emission_enabled = true
		sm.emission = color
		sm.emission_energy_multiplier = 1.1
		var tw := create_tween()
		tw.tween_property(sm, "emission_energy_multiplier", 0.0, 0.32)


func set_highlight(enabled: bool) -> void:
	## Hover feedback for figure-based enemies: a soft glow on the model itself
	## (so we never need the placeholder box outline around them).
	for mi in _all_meshes(self):
		var sm := mi.material_override as StandardMaterial3D
		if sm == null:
			continue
		if enabled:
			sm.emission_enabled = true
			sm.emission = Color(1.0, 1.0, 1.0)
			sm.emission_energy_multiplier = 0.35
		else:
			sm.emission_energy_multiplier = 0.0


# =============================================================
# INTERNAL
# =============================================================

func _set_archer_pose(walking: bool) -> void:
	if _ar_torso == null:
		return
	if _pose_tween and _pose_tween.is_valid():
		_pose_tween.kill()
	var target := AR_QUAD if walking else AR_STAND
	_pose_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_pose_tween.tween_property(_ar_torso, "rotation_degrees:x", target, 0.25)
	# Swap which bow is shown (front when standing, on the back when running).
	if _ar_bow_front:
		_ar_bow_front.visible = not walking
	if _ar_bow_back:
		_ar_bow_back.visible = walking


func _all_meshes(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c is MeshInstance3D:
			out.append(c)
		out.append_array(_all_meshes(c))
	return out


func _cancel_action() -> void:
	if _action_tween and _action_tween.is_valid():
		_action_tween.kill()
	_action_tween = null
	if _bob_node:
		_bob_node.position.z = 0.0
