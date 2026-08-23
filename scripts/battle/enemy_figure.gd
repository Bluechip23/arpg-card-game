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

# Foot/paw nodes stepped through a walk cycle while _walking. Each entry is
# {node, rest, phase}; phases alternate so the figure strides instead of gliding.
var _step_parts: Array = []
var _step_amp: float = 1.0             # per-kind amplitude scale (big trolls step wider)

const ENEMY_STEP_FREQ := 9.0          # radians/sec for the step cycle
const ENEMY_STEP_STRIDE := 0.06       # forward/back foot travel (Z), before _step_amp
const ENEMY_STEP_LIFT := 0.05         # swing-foot lift (Y), before _step_amp

# Archer-rat pose state
var _ar_torso: Node3D = null
var _ar_bow_front: Node3D = null
var _ar_bow_back: Node3D = null

# Hydra neck pivots (all three heads snap out on the attack) + their rest rotations
var _hydra_necks: Array = []
var _hydra_neck_rest: Array = []
const AR_STAND := -74.0
const AR_QUAD := -6.0

var _action_tween: Tween = null
var _pose_tween: Tween = null

var _bear_root: Node3D = null         # Large Bear: tipped forward on all fours when wounded
var _bear_arm_l: Node3D = null        # Large Bear: shoulders for the alternating maul
var _bear_arm_r: Node3D = null

var _troll_leg: Node3D = null         # Armored Troll: right hip pivot for the kick

var _beaver_pose: Node3D = null       # Giant Beaver: tips onto all fours while moving
var _beaver_tail: Node3D = null       # Giant Beaver: tail pivot for the tail-whip spank

var _treant_arm_l: Node3D = null      # Treant: both branch-arms for the overhead slam / root summon
var _treant_arm_r: Node3D = null

# Shared rig handles reused by several graveyard models.
var _arm_l: Node3D = null              # left/right limb pivots (zombie, werewolf, grave titan)
var _arm_r: Node3D = null
var _head_pivot: Node3D = null         # neck/head pivot (bone dragon bite/breath)
var _titan_boulder: Node3D = null      # Grave Titan: boulder (slammed down / rolled, not stuck on shoulder)


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
		# Forest act
		"giant_beaver": _build_beaver()
		"mini_bear": _build_mini_bear()
		"large_bear": _build_large_bear()
		"wolf": _build_wolf()
		"coyote": _build_coyote()
		"bugbear": _build_bugbear()
		"infected_hunter": _build_hunter()
		"giant_hawk": _build_hawk()
		"treant": _build_treant()
		"ice_mage": _build_ice_mage()
		"fire_mage": _build_fire_mage()
		"spark_mage": _build_spark_mage()
		"air_mage": _build_air_mage()
		"earth_mage": _build_earth_mage()
		# Graveyard act
		"zombie": _build_zombie()
		"werewolf": _build_werewolf()
		"wererabbit": _build_wererabbit()
		"vampire": _build_vampire()
		"necromancer": _build_necromancer()
		"bone_dragon": _build_bone_dragon()
		"spirit_collector": _build_spirit_collector()
		"grave_titan": _build_grave_titan()
		"crypt_crawler": _build_crypt_crawler()
		"screecher": _build_screecher()
		"consumed": _build_consumed()
		# Sewer act
		"sludge": _build_sludge()
		"pipe_crawler": _build_pipe_crawler()
		"sewer_croc": _build_sewer_croc()
		"rat_king": _build_rat_king()
		"swarm": _build_swarm()
		# Mountains act
		"weregoat": _build_weregoat()
		"wyvern": _build_wyvern()
		"roc": _build_roc()
		"ice_troll": _build_ice_troll()
		"snow_wraith": _build_snow_wraith()
		"granite_colossus": _build_granite_colossus()
		"white_manticore": _build_white_manticore()
		"sabertooth": _build_sabertooth()
		# Underworld act
		"cerberus": _build_cerberus()
		"succubus": _build_succubus()
		"demon": _build_demon()
		"ifrit": _build_ifrit()
		"mind_eater": _build_mind_eater()
		"specter": _build_specter()
		"magma_spider": _build_magma_spider()
		"pit_fiend": _build_pit_fiend()
		"ash_harpy": _build_ash_harpy()
		"inflamed_minotaur": _build_inflamed_minotaur()
		# Heavens act
		"cherub": _build_cherub()
		"djinn": _build_djinn()
		"corrupted_archangel": _build_corrupted_archangel()
		# Generic tiers / custom enemies (no bespoke art): a proper brute
		# figure instead of the old floating coloured box.
		"brute_minion": _build_brute(0)
		"brute_elite": _build_brute(1)
		"brute_boss": _build_brute(2)
		_: _build_rat()
	_collect_step_parts()
	_auto_ground()
	_attach_shadow()
	_built = true

# Kinds whose bodies deliberately ride above the ground (flyers, wraiths, the
# gale-borne air mage) — auto-grounding must not pull them down.
const HOVER_KINDS := {
	"giant_hawk": true, "screecher": true, "swarm": true, "roc": true,
	"wyvern": true, "snow_wraith": true, "specter": true, "ash_harpy": true,
	"djinn": true, "air_mage": true, "cherub": true,
}

## The built model's bounds in figure-local space (across every visual part).
func _visual_bounds() -> AABB:
	var out := AABB()
	var first := true
	if not is_inside_tree():
		return out
	var inv := global_transform.affine_inverse()
	for child in find_children("*", "VisualInstance3D", true, false):
		if child.name == "Shadow":
			continue  # the ground-plane shadow must not count as "feet"
		var aabb: AABB = child.get_aabb()
		var rel: Transform3D = inv * child.global_transform
		for i in range(8):
			var p: Vector3 = rel * aabb.get_endpoint(i)
			if first:
				out = AABB(p, Vector3.ZERO)
				first = false
			else:
				out = out.expand(p)
	return out

## Feet exactly on the floor: measure the built model's lowest point and shift
## the whole model so it neither hovers above y=0 nor sinks through it.
## (Interaction pass: several builders left a small gap — the "floating a tiny
## bit" — and a couple clipped under.) Hover kinds keep their deliberate gap.
func _auto_ground() -> void:
	if HOVER_KINDS.has(_kind) or not is_inside_tree():
		return
	var bounds := _visual_bounds()
	if bounds.size == Vector3.ZERO:
		return
	var min_y := bounds.position.y
	if absf(min_y) < 0.01:
		return
	for child in get_children():
		if child is Node3D and child.name != "Shadow":  # shadow stays on the floor
			child.position.y -= min_y
	# Keep the idle-bob baseline honest for bob roots that are direct children.
	if _bob_node and _bob_node.get_parent() == self:
		_bob_y = _bob_node.position.y

## Contact shadow (style guide §4) — the single strongest grounding cue. The
## sprite figures already carry one; the procedural models never did, which is
## most of why they read as floating. Sized from the model's real footprint.
func _attach_shadow() -> void:
	if not is_inside_tree() or has_node("Shadow"):
		return
	var bounds := _visual_bounds()
	var width: float = clampf(maxf(bounds.size.x, bounds.size.z) * 0.8, 0.35, 1.8)
	BlobShadow.attach(self, width)


## Gather the foot/paw meshes (children of the bob node) so the walk cycle can
## step them. Bipeds alternate left/right; the rat uses a diagonal quadruped gait.
func _collect_step_parts() -> void:
	_step_parts.clear()
	match _kind:
		"armored_troll": _step_amp = 1.7
		"rat": _step_amp = 0.85
		"hydra": _step_amp = 0.0  # serpent — slithers, no stepping feet
		_: _step_amp = 1.0
	if _step_amp <= 0.0 or _bob_node == null:
		return
	# Recurse so feet parented under pose/scale/hip pivots (beaver, troll) still step.
	_gather_step_parts(_bob_node)


func _gather_step_parts(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var n: String = child.name
			if n.begins_with("Foot") or n.begins_with("Paw"):
				_step_parts.append({"node": child, "rest": child.position, "phase": _step_phase(n)})
		if child is Node3D:
			_gather_step_parts(child)


func _step_phase(node_name: String) -> float:
	# Quadruped diagonal gait: front-left + back-right swing together, opposite pair
	# alternates. Bipeds: left foot leads, right foot trails by half a cycle.
	match node_name:
		"PawFL", "PawBR", "FootL":
			return 0.0
		"PawFR", "PawBL", "FootR":
			return PI
	return 0.0


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


func _pr(parent: Node3D, n: String, pos: Vector3, size: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var p := PrismMesh.new()
	p.size = size
	mi.mesh = p
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi


## A membrane/bat wing built in a node's local space, fanning along +X (mirror
## with sx). A leading-edge arm bone runs out to the wrist; three clawed finger
## bones splay down to the trailing edge; tapered prism panels fill the bays so
## the wing reads as a scalloped membrane instead of a flat slab.
func _bat_wing(w: Node3D, sx: int, span: float, drop: float, mem: Color, bone: Color) -> void:
	# leading-edge arm bone out to the wrist
	_cy(w, "Arm", Vector3(span * 0.5 * sx, 0.0, 0.0), 0.022, 0.032, span, bone, Vector3(0, 0, 90))
	_cy(w, "Claw", Vector3(span * sx, 0.04, 0.0), 0.0, 0.02, 0.1, bone, Vector3(0, 0, -50 * sx))
	# finger knuckles spaced along the leading edge, each drooping to a trailing tip
	var knuckle := [0.95, 0.6, 0.28, 0.0]
	var tipdrop := [0.55, 1.0, 0.92, 0.6]
	for i in range(knuckle.size()):
		var kx: float = span * knuckle[i] * sx
		var tx: float = span * (knuckle[i] * 0.82) * sx
		var ty: float = -drop * tipdrop[i]
		# finger bone running from the knuckle down to the trailing tip
		var midx := (kx + tx) * 0.5
		var midy := ty * 0.5
		var len := Vector2(tx - kx, ty).length()
		var ang := rad_to_deg(atan2(ty, tx - kx)) - 90.0
		_cy(w, "Finger%d" % i, Vector3(midx, midy, 0.0), 0.01, 0.016, len, bone, Vector3(0, 0, ang))
	# membrane bays between consecutive fingers (thin tapered prisms)
	for i in range(knuckle.size() - 1):
		var ax: float = span * (knuckle[i] * 0.82) * sx
		var ay: float = -drop * tipdrop[i]
		var bx: float = span * (knuckle[i + 1] * 0.82) * sx
		var by: float = -drop * tipdrop[i + 1]
		var kx2: float = span * knuckle[i] * sx
		var cx := (ax + bx + kx2) / 3.0
		var cy := (ay + by) / 3.0
		var wdt := Vector2(bx - ax, by - ay).length() + drop * 0.25
		var hgt: float = drop * 0.7
		_pr(w, "Mem%d" % i, Vector3(cx, cy, -0.01), Vector3(wdt, hgt, 0.02), mem, Vector3(0, 0, 180))


## A folded bird wing draping down the flank: layered flight feathers (long
## tapered prisms) hanging downward and raking back along the body, so the wing
## rests at the bird's side instead of sticking straight out.
func _bird_wing(w: Node3D, sx: int, feathers: int, length: float, col: Color, tip: Color) -> void:
	# a small rounded shoulder covert masking the feather roots
	_sp(w, "Covert", Vector3(0.0, 0.02, -0.02), length * 0.15, col, Vector3(0.7, 0.8, 1.3))
	for i in range(feathers):
		var t: float = float(i) / float(feathers - 1)
		var rake: float = lerp(10.0, 50.0, t)        # rear feathers sweep further back
		var fl: float = length * lerp(0.82, 1.08, t)  # and grow longer toward the tip
		var pivot := Node3D.new()
		pivot.name = "FP%d" % i
		pivot.position = Vector3(0.02 * sx, 0.06, lerp(0.13, -0.34, t))
		pivot.rotation_degrees = Vector3(rake, 0, 6.0 * sx)  # hang down + slight outward splay
		w.add_child(pivot)
		var c: Color = tip if i >= feathers - 2 else col
		# broad, overlapping flight feathers so the folded wing reads as one sheet
		_pr(pivot, "F%d" % i, Vector3(0.0, -fl * 0.5, 0.0), Vector3(0.17, fl, 0.02), c, Vector3(0, 0, 180))


## A translucent, faintly glowing material for ghosts/spirits so they read as
## apparitions instead of solid statues.
func _ghost_mat(c: Color, alpha: float, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.roughness = 0.7
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


## Re-skin every mesh under `node` with the ghost material (eyes and other
## emissive parts are skipped so they keep their glow).
func _ghostify(node: Node, alpha: float, glow := 0.35) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var sm := child.material_override as StandardMaterial3D
			if sm != null and not sm.emission_enabled:
				child.material_override = _ghost_mat(sm.albedo_color, alpha, glow)
		if child is Node3D:
			_ghostify(child, alpha, glow)


## A spread bird wing fanning out along +X (mirror with sx): a leading-edge arm
## bone with layered flight feathers raking back off it, longest at the tip, so
## a soaring bird reads as feathers instead of a flat slab.
func _spread_wing(w: Node3D, sx: int, span: float, chord: float, col: Color, tip: Color) -> void:
	_cy(w, "Arm", Vector3(span * 0.45 * sx, 0.02, 0.02), 0.022, 0.035, span * 0.9, col, Vector3(0, 0, 90))
	_sp(w, "Covert", Vector3(span * 0.16 * sx, 0.02, 0.0), chord * 0.3, col, Vector3(1.6, 0.5, 1.1))
	var feathers := 6
	for i in range(feathers):
		var t: float = float(i) / float(feathers - 1)
		var fx: float = span * lerp(0.18, 0.98, t)
		var rake: float = lerp(6.0, 34.0, t * t)          # tip feathers sweep back hardest
		var fl: float = chord * lerp(0.85, 1.25, t)        # and grow longest
		var pivot := Node3D.new()
		pivot.name = "SF%d" % i
		pivot.position = Vector3(fx * sx, 0.0, 0.0)
		pivot.rotation_degrees = Vector3(0, -rake * sx, 0)
		w.add_child(pivot)
		var c: Color = tip if i >= feathers - 2 else col
		_pr(pivot, "F%d" % i, Vector3(0.0, 0.0, -fl * 0.5), Vector3(0.16, fl, 0.018), c, Vector3(-90, 0, 0))


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

	# Grave-gear: a pitted, rust-eaten sword in the sword hand (swings with the
	# shoulder) and a split wooden buckler strapped to the left arm.
	var rust := Color.html("7a4a30")
	var rust2 := Color.html("55352a")
	var wood := Color.html("5a4530")
	var sword := Node3D.new(); sword.name = "Sword"; sword.position = Vector3(0, -0.44, 0.05); sword.rotation_degrees = Vector3(30, 0, 0); sh_r.add_child(sword)
	_bx(sword, "Blade", Vector3(0, 0.26, 0), Vector3(0.05, 0.42, 0.016), rust)
	_bx(sword, "Notch", Vector3(0.025, 0.32, 0), Vector3(0.02, 0.06, 0.02), dark)
	_bx(sword, "Guard", Vector3(0, 0.04, 0), Vector3(0.14, 0.03, 0.04), rust2)
	_cy(sword, "Grip", Vector3(0, -0.05, 0), 0.018, 0.018, 0.12, wood)
	var buckler := Node3D.new(); buckler.name = "Buckler"; buckler.position = Vector3(-0.06, -0.3, 0.03); buckler.rotation_degrees = Vector3(90, 0, 0); sh_l.add_child(buckler)
	_cy(buckler, "Face", Vector3(0, 0, 0), 0.14, 0.14, 0.03, wood)
	_sp(buckler, "Boss", Vector3(0, 0.025, 0), 0.04, rust2)
	_bx(buckler, "Split", Vector3(0.05, 0.02, 0), Vector3(0.02, 0.015, 0.2), dark)

	# Skull — cracked and missing teeth, jaw hanging slightly agape
	_sp(root, "Skull", Vector3(0, 1.18, 0.01), 0.145, bone, Vector3(1.0, 1.05, 1.0))
	var jaw := _bx(root, "Jaw", Vector3(0, 1.07, 0.04), Vector3(0.15, 0.05, 0.13), bone)
	jaw.rotation_degrees = Vector3(8, 0, 0)
	for tx in [-0.05, -0.01, 0.05]:
		_bx(root, "Tooth%d" % int(tx * 100), Vector3(tx, 1.11, 0.1), Vector3(0.018, 0.03, 0.015), bone)
	_sp(root, "SocketL", Vector3(-0.055, 1.19, 0.115), 0.038, dark)
	_sp(root, "SocketR", Vector3(0.055, 1.19, 0.115), 0.038, dark)
	_bx(root, "Nose", Vector3(0, 1.14, 0.13), Vector3(0.03, 0.04, 0.02), dark)
	_bx(root, "Crack", Vector3(0.07, 1.27, 0.09), Vector3(0.014, 0.1, 0.02), dark, Vector3(0, 0, -24))


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

	# Legs + feet. The right leg hangs from a hip pivot so it can kick.
	_bx(root, "LegL", Vector3(-0.17, 0.28, 0), Vector3(0.22, 0.56, 0.24), skin)
	_bx(root, "FootL", Vector3(-0.17, 0.06, 0.07), Vector3(0.24, 0.13, 0.32), dark)
	var hip_r := Node3D.new(); hip_r.name = "HipR"; hip_r.position = Vector3(0.17, 0.56, 0); root.add_child(hip_r)
	_bx(hip_r, "LegR", Vector3(0, -0.28, 0), Vector3(0.22, 0.56, 0.24), skin)
	_bx(hip_r, "FootR", Vector3(0, -0.50, 0.07), Vector3(0.24, 0.13, 0.32), dark)
	_troll_leg = hip_r

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

	# Serpentine trunk: a raised chest where the necks root, sloping back through
	# a thick barrel into coiled hindquarters — three blended masses instead of
	# one ball, so the boss reads as a great snake rearing up.
	_sp(root, "Chest", Vector3(0, 0.6, 0.18), 0.3, green, Vector3(1.1, 1.0, 1.05))
	_sp(root, "Barrel", Vector3(0, 0.48, -0.14), 0.32, green, Vector3(1.15, 0.85, 1.25))
	_sp(root, "Haunch", Vector3(0, 0.36, -0.46), 0.26, green, Vector3(1.0, 0.75, 1.0))
	_sp(root, "Belly", Vector3(0, 0.42, 0.22), 0.22, belly, Vector3(1.0, 0.8, 0.8))
	# Pale belly scutes plating the underside of the rearing chest
	for i in range(4):
		_bx(root, "Scute%d" % i, Vector3(0, 0.24 + i * 0.11, 0.36 - i * 0.015), Vector3(0.34 - i * 0.04, 0.055, 0.06), belly)
	# Dorsal fin ridge running down the spine and out along the tail
	for i in range(6):
		_pr(root, "Fin%d" % i, Vector3(0, 0.8 - i * 0.075, -0.02 - i * 0.14), Vector3(0.05, 0.16 - i * 0.012, 0.1), dark, Vector3(-24, 0, 0))

	# Stubby clawed forelegs bracing the rearing chest
	for sx in [-1, 1]:
		_cy(root, "Leg%d" % sx, Vector3(0.26 * sx, 0.18, 0.26), 0.06, 0.075, 0.32, green, Vector3(0, 0, 14 * sx))
		_sp(root, "Foot%d" % sx, Vector3(0.28 * sx, 0.04, 0.3), 0.07, dark, Vector3(1.1, 0.6, 1.3))
		for cz in [-0.05, 0.0, 0.05]:
			_cy(root, "Claw%d_%d" % [sx, int(cz * 100)], Vector3(0.28 * sx + cz, 0.03, 0.4), 0.0, 0.02, 0.09, belly, Vector3(80, 0, 0))

	# Long tail coiling back and away in tapering segments, tipped with a spade
	var tail := Node3D.new(); tail.name = "Tail"; tail.position = Vector3(0, 0.3, -0.62); root.add_child(tail)
	for i in range(5):
		var f := float(i) / 4.0
		_sp(tail, "TSeg%d" % i, Vector3(sin(f * 2.6) * 0.22, -f * 0.18, -f * 0.55), 0.17 - f * 0.11, green, Vector3(1.0, 0.85, 1.2))
	_pr(tail, "TSpade", Vector3(sin(2.6) * 0.24, -0.14, -0.66), Vector3(0.12, 0.2, 0.03), dark, Vector3(-70, 0, 0))

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
	_hydra_neck_rest.append(pivot.rotation_degrees)

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
# FOREST ACT MODELS
# =============================================================

## Generic four-legged critter. ears: "round" | "pointed"; tail: "bushy" | "stub".
## Pass with_head=false to get just the trunk/legs/tail (e.g. Cerberus, which
## supplies its own three heads).
func _build_quadruped(fur: Color, belly: Color, s: float, ears: String, tail: String, with_head := true) -> Node3D:
	_shadow(0.24 * s)
	var dark := Color.html("141019")
	var body := Node3D.new()
	body.name = "Body"
	body.position = Vector3(0, 0.30 * s, 0)
	add_child(body)
	_bob_node = body
	_bob_y = body.position.y

	# A low, long trunk rather than a single ball: distinct rear haunch, barrel,
	# and shoulder masses blended together so the silhouette reads as a body.
	_sp(body, "Torso", Vector3(0, 0, 0), 0.21 * s, fur, Vector3(0.92, 0.8, 1.7))
	_sp(body, "Haunch", Vector3(0, 0.02 * s, -0.22 * s), 0.2 * s, fur, Vector3(1.0, 1.0, 0.95))
	_sp(body, "Shoulder", Vector3(0, 0.03 * s, 0.2 * s), 0.19 * s, fur, Vector3(1.0, 0.98, 0.95))
	_sp(body, "Belly", Vector3(0, -0.08 * s, 0.04 * s), 0.17 * s, belly, Vector3(0.9, 0.66, 1.35))
	for leg in [["FL", 0.12, 0.24], ["FR", -0.12, 0.24], ["BL", 0.12, -0.22], ["BR", -0.12, -0.22]]:
		_cy(body, "Leg" + str(leg[0]), Vector3(leg[1] * s, -0.22 * s, leg[2] * s), 0.04 * s, 0.045 * s, 0.26 * s, fur)
		_sp(body, "Paw" + str(leg[0]), Vector3(leg[1] * s, -0.36 * s, (leg[2] + 0.02) * s), 0.05 * s, dark)
	if with_head:
		# Neck sloping up from the shoulders to a head set forward and clear of the body.
		_cy(body, "Neck", Vector3(0, 0.12 * s, 0.32 * s), 0.09 * s, 0.12 * s, 0.22 * s, fur, Vector3(58, 0, 0))
		_sp(body, "Head", Vector3(0, 0.2 * s, 0.42 * s), 0.145 * s, fur, Vector3(1.0, 1.0, 1.05))
		# Longer tapered muzzle so it has a face, not just a ball.
		_cy(body, "Muzzle", Vector3(0, 0.15 * s, 0.56 * s), 0.06 * s, 0.1 * s, 0.2 * s, fur, Vector3(80, 0, 0))
		_sp(body, "Nose", Vector3(0, 0.14 * s, 0.66 * s), 0.032 * s, dark)
		_sp(body, "EyeL", Vector3(-0.07 * s, 0.24 * s, 0.5 * s), 0.026 * s, dark)
		_sp(body, "EyeR", Vector3(0.07 * s, 0.24 * s, 0.5 * s), 0.026 * s, dark)
		if ears == "round":
			_sp(body, "EarL", Vector3(-0.1 * s, 0.32 * s, 0.4 * s), 0.06 * s, fur)
			_sp(body, "EarR", Vector3(0.1 * s, 0.32 * s, 0.4 * s), 0.06 * s, fur)
		else:  # pointed
			_cy(body, "EarL", Vector3(-0.08 * s, 0.34 * s, 0.4 * s), 0.0, 0.05 * s, 0.14 * s, fur, Vector3(-12, 0, 16))
			_cy(body, "EarR", Vector3(0.08 * s, 0.34 * s, 0.4 * s), 0.0, 0.05 * s, 0.14 * s, fur, Vector3(-12, 0, -16))
	if tail == "bushy":
		_sp(body, "Tail", Vector3(0, 0.08 * s, -0.42 * s), 0.1 * s, fur, Vector3(0.8, 0.8, 1.5))
	else:  # stub
		_sp(body, "Tail", Vector3(0, 0.06 * s, -0.38 * s), 0.06 * s, fur)
	return body

func _build_wolf() -> void:
	_build_quadruped(Color.html("73757b"), Color.html("9a9ca2"), 1.05, "pointed", "bushy")

func _build_coyote() -> void:
	_build_quadruped(Color.html("9e8350"), Color.html("d8c79a"), 0.82, "pointed", "bushy")

func _build_mini_bear() -> void:
	_build_quadruped(Color.html("5a3c25"), Color.html("7a5634"), 0.85, "round", "stub")

func _build_beaver() -> void:
	# Larger than the other critters (~2x the original); built sitting up on its
	# haunches; tips onto all fours while moving (see _set_beaver_pose).
	_shadow(0.5)
	var fur := Color.html("6b4423")
	var belly := Color.html("8a5a30")
	var dark := Color.html("241712")
	var teeth := Color.html("f3e6b0")
	var body := Node3D.new()
	body.name = "Body"
	add_child(body)
	_bob_node = body
	_bob_y = 0.0
	# Pose node tips the whole beaver forward onto all fours when it moves.
	var pose := Node3D.new()
	pose.name = "Pose"
	body.add_child(pose)
	_beaver_pose = pose
	# Scale node makes it big; geometry below uses the original chunky proportions.
	var g := Node3D.new()
	g.name = "Scale"
	g.position = Vector3(0, 0.57, 0)
	g.scale = Vector3(2.2, 1.55, 1.95)
	pose.add_child(g)
	# Plump upright torso (sits on haunches)
	_sp(g, "Torso", Vector3(0, 0, 0), 0.26, fur, Vector3(1.0, 1.15, 0.95))
	_sp(g, "Belly", Vector3(0, -0.04, 0.12), 0.20, belly, Vector3(0.95, 1.0, 0.8))
	# Hind legs/feet on the ground, little front paws
	_sp(g, "FootL", Vector3(-0.13, -0.30, 0.10), 0.07, dark, Vector3(1, 0.5, 1.3))
	_sp(g, "FootR", Vector3(0.13, -0.30, 0.10), 0.07, dark, Vector3(1, 0.5, 1.3))
	_cy(g, "ArmL", Vector3(-0.17, 0.02, 0.12), 0.04, 0.04, 0.18, fur, Vector3(20, 0, -10))
	_cy(g, "ArmR", Vector3(0.17, 0.02, 0.12), 0.04, 0.04, 0.18, fur, Vector3(20, 0, 10))
	# Head with buck teeth
	_sp(g, "Head", Vector3(0, 0.30, 0.06), 0.18, fur)
	_bx(g, "Muzzle", Vector3(0, 0.24, 0.20), Vector3(0.14, 0.10, 0.10), belly)
	_sp(g, "Nose", Vector3(0, 0.28, 0.26), 0.035, dark)
	_bx(g, "Teeth", Vector3(0, 0.20, 0.24), Vector3(0.07, 0.07, 0.02), teeth)
	_sp(g, "EyeL", Vector3(-0.07, 0.34, 0.18), 0.028, dark)
	_sp(g, "EyeR", Vector3(0.07, 0.34, 0.18), 0.028, dark)
	_sp(g, "EarL", Vector3(-0.13, 0.43, 0.0), 0.045, fur)
	_sp(g, "EarR", Vector3(0.13, 0.43, 0.0), 0.045, fur)
	# Big flat paddle tail on a pivot — swung overhead for the tail-whip spank.
	var tail := Node3D.new()
	tail.name = "TailPivot"
	tail.position = Vector3(0, -0.05, -0.22)
	g.add_child(tail)
	_beaver_tail = tail
	_bx(tail, "Tail", Vector3(0, -0.07, -0.08), Vector3(0.30, 0.06, 0.40), dark)

func _build_large_bear() -> void:
	_shadow(0.34)
	var fur := Color.html("4a3322")
	var dark := Color.html("1c130c")
	var snout := Color.html("6b4a2f")
	var root := Node3D.new()
	root.name = "Body"
	add_child(root)
	_bob_node = root
	_bob_y = 0.0
	_bear_root = root
	# Stands on hind legs
	_cy(root, "LegL", Vector3(-0.13, 0.26, 0), 0.10, 0.12, 0.52, fur)
	_cy(root, "LegR", Vector3(0.13, 0.26, 0), 0.10, 0.12, 0.52, fur)
	_sp(root, "FootL", Vector3(-0.13, 0.03, 0.06), 0.10, dark, Vector3(1, 0.6, 1.4))
	_sp(root, "FootR", Vector3(0.13, 0.03, 0.06), 0.10, dark, Vector3(1, 0.6, 1.4))
	_sp(root, "Torso", Vector3(0, 0.74, 0), 0.30, fur, Vector3(1.0, 1.2, 0.85))
	_sp(root, "Belly", Vector3(0, 0.66, 0.12), 0.22, snout, Vector3(0.9, 1.0, 0.7))
	# Arms (right one swings)
	var sh_l := Node3D.new(); sh_l.name = "ShoulderL"; sh_l.position = Vector3(-0.28, 0.92, 0); root.add_child(sh_l)
	_cy(sh_l, "ArmL", Vector3(0, -0.22, 0.04), 0.07, 0.08, 0.44, fur)
	_sp(sh_l, "ClawL", Vector3(0, -0.46, 0.06), 0.09, dark)
	var sh_r := Node3D.new(); sh_r.name = "ShoulderR"; sh_r.position = Vector3(0.28, 0.92, 0); root.add_child(sh_r)
	_cy(sh_r, "ArmR", Vector3(0, -0.22, 0.04), 0.07, 0.08, 0.44, fur)
	_sp(sh_r, "ClawR", Vector3(0, -0.46, 0.06), 0.09, dark)
	_atk_pivot = sh_r
	_atk_rest = Vector3.ZERO
	_bear_arm_l = sh_l
	_bear_arm_r = sh_r
	# Head
	_sp(root, "Head", Vector3(0, 1.12, 0.04), 0.20, fur)
	_bx(root, "Snout", Vector3(0, 1.06, 0.20), Vector3(0.16, 0.12, 0.14), snout)
	_sp(root, "Nose", Vector3(0, 1.09, 0.28), 0.04, dark)
	_sp(root, "EyeL", Vector3(-0.08, 1.18, 0.17), 0.03, dark)
	_sp(root, "EyeR", Vector3(0.08, 1.18, 0.17), 0.03, dark)
	_sp(root, "EarL", Vector3(-0.15, 1.28, 0.0), 0.07, fur)
	_sp(root, "EarR", Vector3(0.15, 1.28, 0.0), 0.07, fur)

## Large Bear: tip forward onto all fours when badly wounded.
func set_quadruped(on: bool) -> void:
	if _bear_root == null:
		return
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(_bear_root, "rotation_degrees:x", 62.0 if on else 0.0, 0.4)
	tw.parallel().tween_property(_bear_root, "position:y", -0.18 if on else 0.0, 0.4)

func _build_bugbear() -> void:
	_shadow(0.28)
	var fur := Color.html("5b4b34")
	var dark := Color.html("241c12")
	var skin := Color.html("8a7350")
	var eye := Color.html("d6452e")
	var root := Node3D.new()
	root.name = "Body"
	add_child(root)
	_bob_node = root
	_bob_y = 0.0
	_bx(root, "LegL", Vector3(-0.11, 0.18, 0), Vector3(0.13, 0.34, 0.13), fur)
	_bx(root, "LegR", Vector3(0.11, 0.18, 0), Vector3(0.13, 0.34, 0.13), fur)
	_bx(root, "FootL", Vector3(-0.11, 0.03, 0.05), Vector3(0.15, 0.07, 0.2), dark)
	_bx(root, "FootR", Vector3(0.11, 0.03, 0.05), Vector3(0.15, 0.07, 0.2), dark)
	var torso := _bx(root, "Torso", Vector3(0, 0.56, 0), Vector3(0.40, 0.38, 0.26), fur)
	torso.rotation_degrees = Vector3(6, 0, 0)
	_sp(root, "Hump", Vector3(0, 0.74, -0.06), 0.18, fur)
	var sh_l := Node3D.new(); sh_l.name = "ShoulderL"; sh_l.position = Vector3(-0.24, 0.70, 0); root.add_child(sh_l)
	_cy(sh_l, "ArmL", Vector3(0, -0.22, 0.02), 0.06, 0.07, 0.42, fur)
	_sp(sh_l, "FistL", Vector3(0, -0.46, 0.04), 0.08, skin)
	var sh_r := Node3D.new(); sh_r.name = "ShoulderR"; sh_r.position = Vector3(0.24, 0.70, 0); root.add_child(sh_r)
	_cy(sh_r, "ArmR", Vector3(0, -0.22, 0.02), 0.06, 0.07, 0.42, fur)
	_sp(sh_r, "FistR", Vector3(0, -0.46, 0.04), 0.08, skin)
	_atk_pivot = sh_r
	_atk_rest = Vector3.ZERO
	# Heavy spiked mace gripped in the right fist (swings with the arm on attack).
	var steel := Color.html("8a8f99")
	var spike := Color.html("c8ccd6")
	var mace := Node3D.new(); mace.name = "Mace"; mace.position = Vector3(0, -0.5, 0.06); sh_r.add_child(mace)
	_cy(mace, "Haft", Vector3(0, -0.18, 0), 0.03, 0.035, 0.4, Color.html("6b4a2a"))
	_sp(mace, "Head", Vector3(0, 0.06, 0), 0.12, steel)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_bx(mace, "Spike%d_%d" % [sx, sz], Vector3(0.1 * sx, 0.06, 0.1 * sz), Vector3(0.05, 0.05, 0.05), spike)
	_bx(mace, "SpikeTop", Vector3(0, 0.18, 0), Vector3(0.05, 0.06, 0.05), spike)
	# Bandolier strap across the chest (Chewbacca-style holster, no bullets).
	var strap := Color.html("3a2a1a")
	var pouch := Color.html("5a3a22")
	_bx(root, "Strap", Vector3(0, 0.56, 0.16), Vector3(0.1, 0.5, 0.06), strap, Vector3(0, 0, 32))
	for i in range(4):
		_bx(root, "Pouch%d" % i, Vector3(-0.16 + i * 0.11, 0.40 + i * 0.10, 0.18), Vector3(0.07, 0.06, 0.05), pouch, Vector3(0, 0, 32))
	_sp(root, "Head", Vector3(0, 0.92, 0.03), 0.17, skin)
	_cy(root, "EarL", Vector3(-0.17, 0.98, -0.02), 0.0, 0.06, 0.18, skin, Vector3(-8, 0, 55))
	_cy(root, "EarR", Vector3(0.17, 0.98, -0.02), 0.0, 0.06, 0.18, skin, Vector3(-8, 0, -55))
	_bx(root, "Brow", Vector3(0, 0.98, 0.12), Vector3(0.28, 0.05, 0.06), dark)
	_sp(root, "EyeL", Vector3(-0.06, 0.94, 0.14), 0.028, eye, Vector3.ONE, true)
	_sp(root, "EyeR", Vector3(0.06, 0.94, 0.14), 0.028, eye, Vector3.ONE, true)
	_bx(root, "FangL", Vector3(-0.04, 0.83, 0.15), Vector3(0.025, 0.05, 0.02), Color.html("e9e4d6"))
	_bx(root, "FangR", Vector3(0.04, 0.83, 0.15), Vector3(0.025, 0.05, 0.02), Color.html("e9e4d6"))

func _build_hunter() -> void:
	_shadow(0.22)
	var skin := Color.html("7e9166")  # sickly infected green
	var cloth := Color.html("3a3326")
	var steel := Color.html("9aa0a8")
	var dark := Color.html("20180f")
	var eye := Color.html("c9ff6a")
	var root := Node3D.new()
	root.name = "Body"
	add_child(root)
	_bob_node = root
	_bob_y = 0.0
	_bx(root, "LegL", Vector3(-0.08, 0.16, 0), Vector3(0.1, 0.32, 0.1), cloth)
	_bx(root, "LegR", Vector3(0.08, 0.16, 0), Vector3(0.1, 0.32, 0.1), cloth)
	_bx(root, "FootL", Vector3(-0.08, 0.03, 0.04), Vector3(0.12, 0.06, 0.16), dark)
	_bx(root, "FootR", Vector3(0.08, 0.03, 0.04), Vector3(0.12, 0.06, 0.16), dark)
	_bx(root, "Torso", Vector3(0, 0.52, 0), Vector3(0.30, 0.36, 0.20), cloth)
	_sp(root, "Chest", Vector3(0, 0.56, 0.04), 0.16, skin, Vector3(1.0, 1.0, 0.7))
	var sh_l := Node3D.new(); sh_l.name = "ShoulderL"; sh_l.position = Vector3(-0.18, 0.66, 0); root.add_child(sh_l)
	_cy(sh_l, "ArmL", Vector3(0, -0.18, 0.02), 0.045, 0.05, 0.36, skin)
	_sp(sh_l, "HandL", Vector3(0, -0.38, 0.04), 0.05, skin)
	# Right arm holds the hook
	var sh_r := Node3D.new(); sh_r.name = "ShoulderR"; sh_r.position = Vector3(0.18, 0.66, 0); root.add_child(sh_r)
	_cy(sh_r, "ArmR", Vector3(0, -0.18, 0.02), 0.045, 0.05, 0.36, skin)
	_sp(sh_r, "HandR", Vector3(0, -0.38, 0.04), 0.05, skin)
	_cy(sh_r, "HookShaft", Vector3(0, -0.40, 0.14), 0.015, 0.02, 0.26, steel)
	_cy(sh_r, "HookCurve", Vector3(0.05, -0.52, 0.18), 0.014, 0.018, 0.10, steel, Vector3(0, 0, 70))
	_atk_pivot = sh_r
	_atk_rest = Vector3.ZERO
	_sp(root, "Head", Vector3(0, 0.84, 0.02), 0.14, skin)
	_sp(root, "Hood", Vector3(0, 0.88, -0.03), 0.16, cloth, Vector3(1.05, 0.8, 1.05))
	_sp(root, "EyeL", Vector3(-0.05, 0.84, 0.12), 0.026, eye, Vector3.ONE, true)
	_sp(root, "EyeR", Vector3(0.05, 0.84, 0.12), 0.026, eye, Vector3.ONE, true)

func _build_hawk() -> void:
	_shadow(0.44)
	var feather := Color.html("6b4f2f")
	var light := Color.html("9c7c4e")
	var beak := Color.html("e0a32a")
	var dark := Color.html("1a120a")
	var body := Node3D.new()
	body.name = "Body"
	body.position = Vector3(0, 1.15, 0)  # large raptor, hovers high above the ground
	body.scale = Vector3(1.7, 1.7, 1.7)
	add_child(body)
	_bob_node = body
	_bob_y = body.position.y
	_sp(body, "Torso", Vector3(0, 0, 0), 0.20, feather, Vector3(0.85, 0.66, 1.35))
	_sp(body, "Chest", Vector3(0, -0.03, 0.14), 0.15, light, Vector3(0.9, 0.66, 0.9))
	# Spread wings: layered flight feathers fanning off a leading-edge arm,
	# angled up in a shallow soaring dihedral.
	for sx in [-1, 1]:
		var w := Node3D.new()
		w.name = "Wing%d" % sx
		w.position = Vector3(0.12 * sx, 0.05, 0.04)
		w.rotation_degrees = Vector3(0, 0, 14 * sx)
		body.add_child(w)
		_spread_wing(w, sx, 0.72, 0.24, feather, light)
	# Head + hooked beak
	_sp(body, "Head", Vector3(0, 0.08, 0.26), 0.12, feather)
	_cy(body, "Beak", Vector3(0, 0.05, 0.38), 0.0, 0.05, 0.12, beak, Vector3(80, 0, 0))
	_sp(body, "EyeL", Vector3(-0.06, 0.11, 0.32), 0.026, dark)
	_sp(body, "EyeR", Vector3(0.06, 0.11, 0.32), 0.026, dark)
	# Talons tucked beneath, tail feathers fanned out behind
	_cy(body, "TalonL", Vector3(-0.07, -0.18, 0.10), 0.02, 0.03, 0.16, beak)
	_cy(body, "TalonR", Vector3(0.07, -0.18, 0.10), 0.02, 0.03, 0.16, beak)
	for i in range(5):
		var spread := (i - 2) * 14.0
		var tf := Node3D.new()
		tf.name = "TailF%d" % i
		tf.position = Vector3(0, 0.02, -0.24)
		tf.rotation_degrees = Vector3(4, spread, 0)
		body.add_child(tf)
		var c: Color = light if i % 2 == 0 else feather
		_pr(tf, "F", Vector3(0, 0, -0.14), Vector3(0.09, 0.28, 0.016), c, Vector3(-90, 0, 0))

func _build_treant() -> void:
	# A towering tree-giant: long bark legs and a tall trunk.
	_shadow(0.4)
	var bark := Color.html("4a3a26")
	var dark := Color.html("281e12")
	var leaf := Color.html("4e7a2e")
	var leaf2 := Color.html("3c6322")
	var eye := Color.html("c9e06a")
	var root := Node3D.new()
	root.name = "Body"
	add_child(root)
	_bob_node = root
	_bob_y = 0.0
	# Long legs + root feet + thick trunk
	_cy(root, "LegL", Vector3(-0.16, 0.44, 0.02), 0.11, 0.15, 0.84, bark)
	_cy(root, "LegR", Vector3(0.16, 0.44, 0.02), 0.11, 0.15, 0.84, bark)
	_cy(root, "FootL", Vector3(-0.16, 0.05, 0.12), 0.16, 0.18, 0.12, bark)
	_cy(root, "FootR", Vector3(0.16, 0.05, 0.12), 0.16, 0.18, 0.12, bark)
	_cy(root, "Trunk", Vector3(0, 1.22, 0), 0.18, 0.28, 1.1, bark)
	_bx(root, "BarkRidge", Vector3(0, 1.22, 0.2), Vector3(0.08, 1.0, 0.06), dark)
	# Branch arms (both swing for the overhead slam / root summon)
	var sh_l := Node3D.new(); sh_l.name = "ShoulderL"; sh_l.position = Vector3(-0.24, 1.62, 0); root.add_child(sh_l)
	_cy(sh_l, "ArmL", Vector3(0, -0.18, 0.02), 0.05, 0.06, 0.46, bark, Vector3(0, 0, 20))
	_sp(sh_l, "LeafL", Vector3(-0.06, -0.40, 0.04), 0.14, leaf, Vector3(1, 0.8, 1))
	var sh_r := Node3D.new(); sh_r.name = "ShoulderR"; sh_r.position = Vector3(0.24, 1.62, 0); root.add_child(sh_r)
	_cy(sh_r, "ArmR", Vector3(0, -0.18, 0.02), 0.05, 0.06, 0.46, bark, Vector3(0, 0, -20))
	_sp(sh_r, "LeafR", Vector3(0.06, -0.40, 0.04), 0.14, leaf, Vector3(1, 0.8, 1))
	_atk_pivot = sh_r
	_atk_rest = Vector3.ZERO
	_treant_arm_l = sh_l
	_treant_arm_r = sh_r
	# Knothole face + leafy crown
	_sp(root, "EyeL", Vector3(-0.08, 1.64, 0.20), 0.035, eye, Vector3.ONE, true)
	_sp(root, "EyeR", Vector3(0.08, 1.64, 0.20), 0.035, eye, Vector3.ONE, true)
	_bx(root, "Mouth", Vector3(0, 1.50, 0.22), Vector3(0.12, 0.05, 0.04), dark)
	_sp(root, "Crown", Vector3(0, 1.98, 0), 0.34, leaf, Vector3(1.25, 0.95, 1.25))
	_sp(root, "Crown2", Vector3(-0.2, 1.88, 0.06), 0.18, leaf2)
	_sp(root, "Crown3", Vector3(0.2, 1.90, -0.04), 0.18, leaf2)

## Robed elemental caster with a glowing orb. Used by all five mages.
func _build_mage(robe: Color, trim: Color, orb_c: Color) -> void:
	_shadow(0.22)
	var dark := Color.html("20180f")
	var skin := Color.html("c9b79a")
	var root := Node3D.new()
	root.name = "Body"
	add_child(root)
	_bob_node = root
	_bob_y = 0.0
	# Conical robe
	_cy(root, "Robe", Vector3(0, 0.34, 0), 0.10, 0.30, 0.68, robe)
	_bx(root, "Hem", Vector3(0, 0.03, 0.0), Vector3(0.42, 0.06, 0.42), trim)
	_cy(root, "Sash", Vector3(0, 0.40, 0.0), 0.21, 0.21, 0.06, trim)
	# Arms: left holds the orb out front, right is the casting arm
	var sh_l := Node3D.new(); sh_l.name = "ShoulderL"; sh_l.position = Vector3(-0.16, 0.60, 0.04); root.add_child(sh_l)
	_cy(sh_l, "ArmL", Vector3(0, -0.14, 0.06), 0.035, 0.04, 0.30, robe, Vector3(40, 0, 0))
	var orb := _sp(sh_l, "Orb", Vector3(0, -0.26, 0.20), 0.09, orb_c, Vector3.ONE, true)
	(orb.material_override as StandardMaterial3D).emission_energy_multiplier = 2.2
	_sp(sh_l, "OrbCore", Vector3(0, -0.26, 0.20), 0.05, Color.html("ffffff"), Vector3.ONE, true)
	var sh_r := Node3D.new(); sh_r.name = "ShoulderR"; sh_r.position = Vector3(0.16, 0.60, 0); root.add_child(sh_r)
	_cy(sh_r, "ArmR", Vector3(0, -0.16, 0.02), 0.035, 0.04, 0.32, robe)
	_sp(sh_r, "HandR", Vector3(0, -0.34, 0.03), 0.045, skin)
	_atk_pivot = sh_r
	_atk_rest = Vector3.ZERO
	# Head under a pointed hood
	_sp(root, "Head", Vector3(0, 0.74, 0.02), 0.13, skin)
	_cy(root, "Hood", Vector3(0, 0.86, -0.02), 0.0, 0.18, 0.30, robe)
	_sp(root, "EyeL", Vector3(-0.05, 0.74, 0.11), 0.022, orb_c, Vector3.ONE, true)
	_sp(root, "EyeR", Vector3(0.05, 0.74, 0.11), 0.022, orb_c, Vector3.ONE, true)


## Ice Mage: frost-caller in a deep-blue robe trimmed with white fur, ice
## crystals jutting from the shoulders and a frozen orb.
func _build_ice_mage() -> void:
	_shadow(0.22)
	var robe := Color.html("2f5a96")
	var robe2 := Color.html("24466e")
	var fur := Color.html("eef4f8")
	var skin := Color.html("c9d6e0")  # frost-pale
	var ice := Color.html("8fd0ff")
	var crystal := Color.html("bfe6ff")
	var root := Node3D.new()
	root.name = "Body"
	add_child(root)
	_bob_node = root
	_bob_y = 0.0
	# Conical robe with a white-fur hem and belt
	_cy(root, "Robe", Vector3(0, 0.34, 0), 0.10, 0.30, 0.68, robe)
	_cy(root, "FurHem", Vector3(0, 0.05, 0), 0.29, 0.31, 0.08, fur)
	_cy(root, "FurBelt", Vector3(0, 0.42, 0.0), 0.2, 0.21, 0.06, fur)
	# Ice crystals growing out of the shoulders
	for sx in [-1, 1]:
		_cy(root, "CrystalA%d" % sx, Vector3(0.16 * sx, 0.72, -0.02), 0.0, 0.045, 0.2, crystal, Vector3(-14, 0, -34 * sx))
		_cy(root, "CrystalB%d" % sx, Vector3(0.2 * sx, 0.66, 0.02), 0.0, 0.03, 0.13, crystal, Vector3(8, 0, -52 * sx))
	# Arms: left cradles the frozen orb, right is the casting arm with a fur cuff
	var sh_l := Node3D.new(); sh_l.name = "ShoulderL"; sh_l.position = Vector3(-0.16, 0.60, 0.04); root.add_child(sh_l)
	_cy(sh_l, "ArmL", Vector3(0, -0.14, 0.06), 0.035, 0.04, 0.30, robe, Vector3(40, 0, 0))
	_cy(sh_l, "CuffL", Vector3(0, -0.24, 0.14), 0.045, 0.05, 0.07, fur, Vector3(40, 0, 0))
	var orb := _sp(sh_l, "Orb", Vector3(0, -0.26, 0.20), 0.09, ice, Vector3.ONE, true)
	(orb.material_override as StandardMaterial3D).emission_energy_multiplier = 2.2
	_sp(sh_l, "OrbCore", Vector3(0, -0.26, 0.20), 0.05, Color.html("ffffff"), Vector3.ONE, true)
	var sh_r := Node3D.new(); sh_r.name = "ShoulderR"; sh_r.position = Vector3(0.16, 0.60, 0); root.add_child(sh_r)
	_cy(sh_r, "ArmR", Vector3(0, -0.16, 0.02), 0.035, 0.04, 0.32, robe)
	_cy(sh_r, "CuffR", Vector3(0, -0.3, 0.03), 0.045, 0.05, 0.07, fur)
	_sp(sh_r, "HandR", Vector3(0, -0.36, 0.03), 0.045, skin)
	_atk_pivot = sh_r
	_atk_rest = Vector3.ZERO
	# Frost-pale head in a deep fur-rimmed hood, breath-glow eyes
	_sp(root, "Head", Vector3(0, 0.74, 0.02), 0.13, skin)
	_cy(root, "Hood", Vector3(0, 0.86, -0.02), 0.0, 0.18, 0.30, robe2)
	_cy(root, "HoodFur", Vector3(0, 0.76, 0.05), 0.15, 0.16, 0.06, fur, Vector3(12, 0, 0))
	_sp(root, "EyeL", Vector3(-0.05, 0.74, 0.11), 0.022, ice, Vector3.ONE, true)
	_sp(root, "EyeR", Vector3(0.05, 0.74, 0.11), 0.022, ice, Vector3.ONE, true)
	# Icicles hanging from the hem
	for a in range(3):
		_cy(root, "Icicle%d" % a, Vector3(-0.14 + a * 0.14, 0.02, 0.24), 0.0, 0.018, 0.09, crystal, Vector3(180, 0, 0))


## Air Mage: wind-caller in layered sage robes, a long scarf streaming out
## sideways as if in a constant gale, hovering on a swirl of air.
func _build_air_mage() -> void:
	_shadow(0.22)
	var robe := Color.html("6fa08c")
	var robe2 := Color.html("58836f")
	var trim := Color.html("cfeee0")
	var skin := Color.html("c9b79a")
	var wind := Color.html("d6fff0")
	var root := Node3D.new()
	root.name = "Body"
	root.position.y = 0.12  # hovers just off the ground
	add_child(root)
	_bob_node = root
	_bob_y = 0.12
	# Swirl of air where the feet would be
	_cy(root, "Swirl", Vector3(0, -0.06, 0), 0.24, 0.06, 0.12, wind)
	_cy(root, "Swirl2", Vector3(0, 0.02, 0), 0.18, 0.1, 0.08, trim)
	# Layered robes flaring wide, blown to one side
	var skirt := _cy(root, "Skirt", Vector3(0.02, 0.22, 0), 0.16, 0.3, 0.34, robe)
	skirt.rotation_degrees = Vector3(0, 0, -6)
	_cy(root, "SkirtTrim", Vector3(0.03, 0.08, 0), 0.28, 0.3, 0.06, trim, Vector3(0, 0, -6))
	_cy(root, "Robe", Vector3(0, 0.48, 0), 0.11, 0.18, 0.3, robe2)
	_bx(root, "Sash", Vector3(0, 0.4, 0.08), Vector3(0.26, 0.06, 0.1), trim, Vector3(0, 0, 14))
	# Long scarf streaming out to the left on the wind
	_bx(root, "ScarfNeck", Vector3(0, 0.68, 0.02), Vector3(0.18, 0.07, 0.16), trim)
	_bx(root, "Scarf1", Vector3(-0.24, 0.72, -0.02), Vector3(0.3, 0.05, 0.1), trim, Vector3(0, 0, 10))
	_bx(root, "Scarf2", Vector3(-0.52, 0.8, -0.04), Vector3(0.28, 0.04, 0.09), wind, Vector3(0, 0, 22))
	# Arms: left holds a swirling wind orb, right is the casting arm
	var sh_l := Node3D.new(); sh_l.name = "ShoulderL"; sh_l.position = Vector3(-0.15, 0.6, 0.04); root.add_child(sh_l)
	_cy(sh_l, "ArmL", Vector3(0, -0.14, 0.06), 0.033, 0.038, 0.28, robe2, Vector3(40, 0, 0))
	var orb := _sp(sh_l, "Orb", Vector3(0, -0.24, 0.19), 0.08, wind, Vector3.ONE, true)
	(orb.material_override as StandardMaterial3D).emission_energy_multiplier = 1.8
	_cy(sh_l, "OrbRing", Vector3(0, -0.24, 0.19), 0.1, 0.1, 0.014, trim, Vector3(24, 0, 12))
	var sh_r := Node3D.new(); sh_r.name = "ShoulderR"; sh_r.position = Vector3(0.15, 0.6, 0); root.add_child(sh_r)
	_cy(sh_r, "ArmR", Vector3(0, -0.15, 0.02), 0.033, 0.038, 0.3, robe2)
	_sp(sh_r, "HandR", Vector3(0, -0.33, 0.03), 0.042, skin)
	_atk_pivot = sh_r
	_atk_rest = Vector3.ZERO
	# Bare head with wind-tossed hair, cloth blindfold over the eyes
	_sp(root, "Head", Vector3(0, 0.82, 0.02), 0.125, skin)
	var hair := _sp(root, "Hair", Vector3(-0.03, 0.9, -0.02), 0.13, robe2, Vector3(1.15, 0.6, 1.05))
	hair.rotation_degrees = Vector3(0, 0, -18)
	_bx(root, "Blindfold", Vector3(0, 0.83, 0.1), Vector3(0.22, 0.045, 0.08), trim)
	_sp(root, "EyeL", Vector3(-0.05, 0.83, 0.135), 0.016, wind, Vector3.ONE, true)
	_sp(root, "EyeR", Vector3(0.05, 0.83, 0.135), 0.016, wind, Vector3.ONE, true)


## Earth Mage: broad-shouldered, stocky brute in animal-skin clothing with
## white-fur-topped boots.
func _build_earth_mage() -> void:
	_shadow(0.28)
	var skin := Color.html("c9b79a")
	var hide := Color.html("6b4a2a")
	var hide2 := Color.html("8a6b3f")
	var fur := Color.html("efe9da")  # white fur
	var boot := Color.html("3a2a1a")
	var dark := Color.html("20180f")
	var eye := Color.html("a0d06a")
	var root := Node3D.new()
	root.name = "Body"
	add_child(root)
	_bob_node = root
	_bob_y = 0.0
	# Stocky legs + fur-topped boots
	_bx(root, "LegL", Vector3(-0.13, 0.28, 0), Vector3(0.17, 0.34, 0.17), hide)
	_bx(root, "LegR", Vector3(0.13, 0.28, 0), Vector3(0.17, 0.34, 0.17), hide)
	_bx(root, "BootL", Vector3(-0.13, 0.09, 0.04), Vector3(0.21, 0.18, 0.28), boot)
	_bx(root, "BootR", Vector3(0.13, 0.09, 0.04), Vector3(0.21, 0.18, 0.28), boot)
	# White fur cuffs at the tops of the boots
	_cy(root, "FurL", Vector3(-0.13, 0.2, 0.02), 0.14, 0.14, 0.09, fur)
	_cy(root, "FurR", Vector3(0.13, 0.2, 0.02), 0.14, 0.14, 0.09, fur)
	# Broad, stocky torso (animal-skin tunic) + hide belt
	var torso := _bx(root, "Torso", Vector3(0, 0.64, 0), Vector3(0.52, 0.42, 0.32), hide)
	torso.rotation_degrees = Vector3(4, 0, 0)
	_bx(root, "Belt", Vector3(0, 0.46, 0.0), Vector3(0.54, 0.08, 0.34), boot)
	# Shaggy white-fur mantle over the broad shoulders
	_sp(root, "Mantle", Vector3(0, 0.86, -0.02), 0.3, fur, Vector3(1.5, 0.5, 1.05))
	# Thick arms
	var sh_l := Node3D.new(); sh_l.name = "ShoulderL"; sh_l.position = Vector3(-0.31, 0.82, 0); root.add_child(sh_l)
	_cy(sh_l, "ArmL", Vector3(0, -0.2, 0.02), 0.07, 0.08, 0.42, skin)
	_sp(sh_l, "HandL", Vector3(0, -0.42, 0.03), 0.08, skin)
	var sh_r := Node3D.new(); sh_r.name = "ShoulderR"; sh_r.position = Vector3(0.31, 0.82, 0); root.add_child(sh_r)
	_cy(sh_r, "ArmR", Vector3(0, -0.2, 0.02), 0.07, 0.08, 0.42, skin)
	_sp(sh_r, "HandR", Vector3(0, -0.42, 0.03), 0.08, skin)
	_atk_pivot = sh_r
	_atk_rest = Vector3.ZERO
	# Head + shaggy hair
	_sp(root, "Head", Vector3(0, 1.04, 0.02), 0.16, skin)
	_bx(root, "Brow", Vector3(0, 1.08, 0.12), Vector3(0.24, 0.04, 0.06), dark)
	_sp(root, "EyeL", Vector3(-0.06, 1.04, 0.13), 0.025, eye, Vector3.ONE, true)
	_sp(root, "EyeR", Vector3(0.06, 1.04, 0.13), 0.025, eye, Vector3.ONE, true)
	_sp(root, "Hair", Vector3(0, 1.13, -0.02), 0.17, hide2, Vector3(1.05, 0.7, 1.05))


## Fire Mage: ninja-styled, red outfit with baggy pants and tight calf-high socks.
func _build_fire_mage() -> void:
	_shadow(0.22)
	var red := Color.html("b23a2a")
	var red2 := Color.html("8a2a1e")
	var sock := Color.html("2b2b30")
	var skin := Color.html("c9b79a")
	var sash := Color.html("e6731f")
	var eye := Color.html("ffd23f")
	var root := Node3D.new()
	root.name = "Body"
	add_child(root)
	_bob_node = root
	_bob_y = 0.0
	# Tight calf-high socks + tabi feet
	_cy(root, "SockL", Vector3(-0.09, 0.16, 0), 0.05, 0.055, 0.3, sock)
	_cy(root, "SockR", Vector3(0.09, 0.16, 0), 0.05, 0.055, 0.3, sock)
	_bx(root, "TabiL", Vector3(-0.09, 0.03, 0.06), Vector3(0.11, 0.06, 0.2), sock)
	_bx(root, "TabiR", Vector3(0.09, 0.03, 0.06), Vector3(0.11, 0.06, 0.2), sock)
	# Baggy pants, gathered above the socks
	_sp(root, "PantL", Vector3(-0.1, 0.38, 0), 0.14, red, Vector3(1.0, 1.25, 1.0))
	_sp(root, "PantR", Vector3(0.1, 0.38, 0), 0.14, red, Vector3(1.0, 1.25, 1.0))
	# Red tunic top with a crossed sash + belt
	_bx(root, "Torso", Vector3(0, 0.62, 0), Vector3(0.32, 0.34, 0.22), red)
	_bx(root, "Sash", Vector3(0, 0.6, 0.12), Vector3(0.38, 0.08, 0.06), sash, Vector3(0, 0, 24))
	_bx(root, "Belt", Vector3(0, 0.46, 0), Vector3(0.34, 0.07, 0.24), red2)
	# Wrapped arms
	var sh_l := Node3D.new(); sh_l.name = "ShoulderL"; sh_l.position = Vector3(-0.18, 0.74, 0); root.add_child(sh_l)
	_cy(sh_l, "ArmL", Vector3(0, -0.16, 0.02), 0.04, 0.045, 0.34, red)
	_sp(sh_l, "HandL", Vector3(0, -0.34, 0.03), 0.05, skin)
	var sh_r := Node3D.new(); sh_r.name = "ShoulderR"; sh_r.position = Vector3(0.18, 0.74, 0); root.add_child(sh_r)
	_cy(sh_r, "ArmR", Vector3(0, -0.16, 0.02), 0.04, 0.045, 0.34, red)
	_sp(sh_r, "HandR", Vector3(0, -0.34, 0.03), 0.05, skin)
	_atk_pivot = sh_r
	_atk_rest = Vector3.ZERO
	# Masked head: a skin eye-strip across a red wrap, with trailing headband tails
	_sp(root, "Head", Vector3(0, 0.94, 0.02), 0.14, red)
	_bx(root, "EyeStrip", Vector3(0, 0.95, 0.12), Vector3(0.22, 0.05, 0.04), skin)
	_sp(root, "EyeL", Vector3(-0.05, 0.95, 0.14), 0.022, eye, Vector3.ONE, true)
	_sp(root, "EyeR", Vector3(0.05, 0.95, 0.14), 0.022, eye, Vector3.ONE, true)
	_bx(root, "BandL", Vector3(-0.1, 1.0, -0.13), Vector3(0.04, 0.04, 0.2), red2)
	_bx(root, "BandR", Vector3(0.1, 1.0, -0.13), Vector3(0.04, 0.04, 0.2), red2)


## Spark Mage: spiky-haired punk in a black sleeveless shirt and ripped pants.
func _build_spark_mage() -> void:
	_shadow(0.22)
	var black := Color.html("2c2c34")  # charcoal — reads as black but stays visible
	var skin := Color.html("c9b79a")
	var pants := Color.html("3b3f4a")
	var hair := Color.html("32323c")
	var spark := Color.html("fff07a")
	var root := Node3D.new()
	root.name = "Body"
	add_child(root)
	_bob_node = root
	_bob_y = 0.0
	# Ripped pants with skin showing at the knees
	_cy(root, "LegL", Vector3(-0.09, 0.22, 0), 0.05, 0.06, 0.42, pants)
	_cy(root, "LegR", Vector3(0.09, 0.22, 0), 0.05, 0.06, 0.42, pants)
	_sp(root, "KneeL", Vector3(-0.09, 0.24, 0.05), 0.05, skin)  # exposed knee (rip)
	_sp(root, "KneeR", Vector3(0.09, 0.17, 0.05), 0.05, skin)
	_bx(root, "ShoeL", Vector3(-0.09, 0.03, 0.04), Vector3(0.11, 0.06, 0.18), black)
	_bx(root, "ShoeR", Vector3(0.09, 0.03, 0.04), Vector3(0.11, 0.06, 0.18), black)
	# Black sleeveless shirt
	_bx(root, "Torso", Vector3(0, 0.6, 0), Vector3(0.3, 0.36, 0.2), black)
	# Bare shoulders + arms (sleeveless)
	var sh_l := Node3D.new(); sh_l.name = "ShoulderL"; sh_l.position = Vector3(-0.17, 0.72, 0); root.add_child(sh_l)
	_sp(sh_l, "DeltL", Vector3(0, 0, 0), 0.07, skin)
	_cy(sh_l, "ArmL", Vector3(0, -0.18, 0.02), 0.04, 0.045, 0.34, skin)
	_sp(sh_l, "HandL", Vector3(0, -0.36, 0.03), 0.05, skin)
	var sh_r := Node3D.new(); sh_r.name = "ShoulderR"; sh_r.position = Vector3(0.17, 0.72, 0); root.add_child(sh_r)
	_sp(sh_r, "DeltR", Vector3(0, 0, 0), 0.07, skin)
	_cy(sh_r, "ArmR", Vector3(0, -0.18, 0.02), 0.04, 0.045, 0.34, skin)
	_sp(sh_r, "HandR", Vector3(0, -0.36, 0.03), 0.05, skin)
	_atk_pivot = sh_r
	_atk_rest = Vector3.ZERO
	# Head with electric eyes
	_sp(root, "Head", Vector3(0, 0.92, 0.02), 0.14, skin)
	_sp(root, "EyeL", Vector3(-0.05, 0.92, 0.12), 0.022, spark, Vector3.ONE, true)
	_sp(root, "EyeR", Vector3(0.05, 0.92, 0.12), 0.022, spark, Vector3.ONE, true)
	# Spiky hair (cones fanning up and out, with crackling electric tips)
	var spikes := [[-0.08, 0.0, -34], [-0.04, 0.04, -16], [0.0, 0.06, 0], [0.04, 0.04, 16], [0.08, 0.0, 34]]
	for i in range(spikes.size()):
		var s = spikes[i]
		_cy(root, "Spike%d" % i, Vector3(s[0], 1.02 + s[1], 0.0), 0.0, 0.045, 0.2, hair, Vector3(0, 0, s[2]))
		_sp(root, "SpikeTip%d" % i, Vector3(s[0] * 1.7, 1.18 + s[1], 0.0), 0.025, spark, Vector3.ONE, true)


# =============================================================
# GRAVEYARD ACT MODELS
# =============================================================

## Zombie: shambling, hunched undead with arms outstretched.
func _build_zombie() -> void:
	_shadow(0.24)
	var skin := Color.html("7d9166")
	var skin2 := Color.html("8fa074")
	var cloth := Color.html("44402f")
	var dark := Color.html("201a10")
	var blood := Color.html("6e1f1f")
	var root := Node3D.new(); root.name = "Body"; add_child(root); _bob_node = root; _bob_y = 0.0
	_bx(root, "LegL", Vector3(-0.09, 0.2, 0), Vector3(0.12, 0.4, 0.12), cloth)
	_bx(root, "LegR", Vector3(0.09, 0.18, 0), Vector3(0.12, 0.36, 0.12), cloth)
	_bx(root, "FootL", Vector3(-0.09, 0.03, 0.05), Vector3(0.13, 0.06, 0.18), dark)
	_bx(root, "FootR", Vector3(0.09, 0.03, 0.05), Vector3(0.13, 0.06, 0.18), dark)
	var torso := _bx(root, "Torso", Vector3(0, 0.6, 0.02), Vector3(0.34, 0.4, 0.22), skin)
	torso.rotation_degrees = Vector3(14, 0, 0)
	_bx(root, "Shirt", Vector3(0, 0.56, 0.05), Vector3(0.36, 0.3, 0.22), cloth)
	_bx(root, "Wound", Vector3(0.07, 0.62, 0.16), Vector3(0.08, 0.1, 0.02), blood)
	# Arms outstretched forward (classic zombie reach)
	var sh_l := Node3D.new(); sh_l.name = "ShoulderL"; sh_l.position = Vector3(-0.2, 0.78, 0.02); root.add_child(sh_l); sh_l.rotation_degrees = Vector3(-80, 0, 0)
	_cy(sh_l, "ArmL", Vector3(0, -0.18, 0), 0.045, 0.05, 0.4, skin); _sp(sh_l, "HandL", Vector3(0, -0.38, 0), 0.05, skin2)
	var sh_r := Node3D.new(); sh_r.name = "ShoulderR"; sh_r.position = Vector3(0.2, 0.78, 0.02); root.add_child(sh_r); sh_r.rotation_degrees = Vector3(-80, 0, 0)
	_cy(sh_r, "ArmR", Vector3(0, -0.18, 0), 0.045, 0.05, 0.4, skin); _sp(sh_r, "HandR", Vector3(0, -0.38, 0), 0.05, skin2)
	_arm_l = sh_l; _arm_r = sh_r; _atk_pivot = sh_r; _atk_rest = Vector3(-80, 0, 0)
	_sp(root, "Head", Vector3(0, 0.92, 0.06), 0.15, skin)
	_sp(root, "EyeL", Vector3(-0.05, 0.93, 0.17), 0.02, dark); _sp(root, "EyeR", Vector3(0.05, 0.93, 0.17), 0.02, dark)
	_bx(root, "Jaw", Vector3(0, 0.85, 0.16), Vector3(0.1, 0.04, 0.08), skin2)


## Generic-tier brute (Minion / Elite / Boss and custom enemies): a stocky
## humanoid thug in the tier's old box colour, so sprite-less enemies read as
## creatures instead of crates. Elites add pauldrons; bosses grow and get horns.
func _build_brute(tier: int) -> void:
	_shadow(0.26 + tier * 0.05)
	var skin: Color = [Color(0.8, 0.25, 0.22), Color(0.58, 0.14, 0.14), Color(0.42, 0.08, 0.24)][tier]
	var skin2 := skin.lightened(0.18)
	var cloth := Color(0.22, 0.18, 0.15)
	var dark := Color(0.1, 0.08, 0.08)
	var root := Node3D.new(); root.name = "Body"; add_child(root); _bob_node = root; _bob_y = 0.0
	root.scale = Vector3.ONE * (1.0 + tier * 0.18)
	_bx(root, "LegL", Vector3(-0.1, 0.19, 0), Vector3(0.14, 0.38, 0.14), cloth)
	_bx(root, "LegR", Vector3(0.1, 0.19, 0), Vector3(0.14, 0.38, 0.14), cloth)
	_bx(root, "FootL", Vector3(-0.1, 0.03, 0.04), Vector3(0.15, 0.06, 0.2), dark)
	_bx(root, "FootR", Vector3(0.1, 0.03, 0.04), Vector3(0.15, 0.06, 0.2), dark)
	_bx(root, "Torso", Vector3(0, 0.58, 0), Vector3(0.42, 0.42, 0.26), skin)
	_bx(root, "Belt", Vector3(0, 0.4, 0), Vector3(0.44, 0.07, 0.28), dark)
	_bx(root, "Chest", Vector3(0, 0.68, 0.1), Vector3(0.34, 0.18, 0.1), skin2)
	# Arms on shoulder pivots so the attack swing works.
	var sh_l := Node3D.new(); sh_l.name = "ShoulderL"; sh_l.position = Vector3(-0.26, 0.74, 0); root.add_child(sh_l)
	_cy(sh_l, "ArmL", Vector3(0, -0.16, 0), 0.055, 0.065, 0.34, skin); _sp(sh_l, "FistL", Vector3(0, -0.34, 0), 0.07, skin2)
	var sh_r := Node3D.new(); sh_r.name = "ShoulderR"; sh_r.position = Vector3(0.26, 0.74, 0); root.add_child(sh_r)
	_cy(sh_r, "ArmR", Vector3(0, -0.16, 0), 0.055, 0.065, 0.34, skin); _sp(sh_r, "FistR", Vector3(0, -0.34, 0), 0.07, skin2)
	_arm_l = sh_l; _arm_r = sh_r; _atk_pivot = sh_r; _atk_rest = Vector3.ZERO
	# Head sunk into the shoulders, heavy brow.
	_sp(root, "Head", Vector3(0, 0.92, 0.02), 0.15, skin)
	_bx(root, "Brow", Vector3(0, 0.97, 0.11), Vector3(0.22, 0.05, 0.08), skin2)
	_sp(root, "EyeL", Vector3(-0.06, 0.92, 0.14), 0.022, dark)
	_sp(root, "EyeR", Vector3(0.06, 0.92, 0.14), 0.022, dark)
	if tier >= 1:
		# Elite: iron pauldrons.
		_sp(root, "PadL", Vector3(-0.27, 0.82, 0), 0.1, Color(0.35, 0.35, 0.4), Vector3(1.0, 0.7, 1.0))
		_sp(root, "PadR", Vector3(0.27, 0.82, 0), 0.1, Color(0.35, 0.35, 0.4), Vector3(1.0, 0.7, 1.0))
	if tier >= 2:
		# Boss: swept horns and burning eyes.
		_cy(root, "HornL", Vector3(-0.11, 1.06, 0), 0.01, 0.035, 0.16, Color(0.85, 0.8, 0.65), Vector3(0, 0, 24))
		_cy(root, "HornR", Vector3(0.11, 1.06, 0), 0.01, 0.035, 0.16, Color(0.85, 0.8, 0.65), Vector3(0, 0, -24))
		_sp(root, "EyeGlowL", Vector3(-0.06, 0.92, 0.14), 0.024, Color(1.0, 0.6, 0.2), Vector3.ONE, true)
		_sp(root, "EyeGlowR", Vector3(0.06, 0.92, 0.14), 0.024, Color(1.0, 0.6, 0.2), Vector3.ONE, true)


## Werewolf: bear-tall, grey, hunched, with long arms whose claws reach the ground.
func _build_werewolf() -> void:
	_shadow(0.34)
	var grey := Color.html("6f7378")
	var grey2 := Color.html("565a60")
	var dark := Color.html("17181b")
	var claw := Color.html("dfe2e6")
	var eye := Color.html("ffd23f")
	var root := Node3D.new(); root.name = "Body"; add_child(root); _bob_node = root; _bob_y = 0.0
	# --- Jointed digitigrade legs: hip -> knee -> ankle -> foot ---
	for sx in [-1, 1]:
		var hip := Node3D.new(); hip.name = "Hip%d" % sx; hip.position = Vector3(0.15 * sx, 0.82, -0.06); root.add_child(hip); hip.rotation_degrees = Vector3(-28, 0, 0)
		_cy(hip, "Thigh", Vector3(0, -0.2, 0), 0.085, 0.095, 0.42, grey)
		_sp(hip, "KneeBall", Vector3(0, -0.4, 0), 0.075, grey2)
		var knee := Node3D.new(); knee.name = "Knee%d" % sx; knee.position = Vector3(0, -0.42, 0); hip.add_child(knee); knee.rotation_degrees = Vector3(58, 0, 0)
		_cy(knee, "Shin", Vector3(0, -0.2, 0), 0.06, 0.07, 0.4, grey)
		var ankle := Node3D.new(); ankle.name = "Ankle%d" % sx; ankle.position = Vector3(0, -0.4, 0); knee.add_child(ankle); ankle.rotation_degrees = Vector3(-30, 0, 0)
		_bx(ankle, "Sole", Vector3(0, -0.03, 0.08), Vector3(0.14, 0.08, 0.26), grey2)
	# Hunched torso leaning forward over the legs
	var torso := _bx(root, "Torso", Vector3(0, 1.02, 0.12), Vector3(0.46, 0.54, 0.32), grey)
	torso.rotation_degrees = Vector3(34, 0, 0)
	_sp(root, "Chest", Vector3(0, 0.98, 0.28), 0.22, grey2, Vector3(1.1, 1.0, 0.7))
	_sp(root, "Hump", Vector3(0, 1.2, -0.04), 0.18, grey)
	# --- Jointed arms dangling in front: shoulder -> upper -> elbow -> forearm -> clawed hand ---
	for sx in [-1, 1]:
		var sh := Node3D.new(); sh.name = "Shoulder%d" % sx; sh.position = Vector3(0.26 * sx, 1.18, 0.2); root.add_child(sh); sh.rotation_degrees = Vector3(52, 0, 0)
		_cy(sh, "Upper", Vector3(0, -0.26, 0), 0.075, 0.08, 0.5, grey)
		_sp(sh, "ElbowBall", Vector3(0, -0.5, 0), 0.07, grey2)
		var el := Node3D.new(); el.name = "Elbow%d" % sx; el.position = Vector3(0, -0.52, 0); sh.add_child(el); el.rotation_degrees = Vector3(-40, 0, 0)
		_cy(el, "Forearm", Vector3(0, -0.24, 0), 0.06, 0.07, 0.46, grey)
		_sp(el, "Paw", Vector3(0, -0.48, 0.02), 0.1, grey2)
		for k in range(3): _cy(el, "Claw%d" % k, Vector3(-0.07 + k * 0.07, -0.56, 0.1), 0.0, 0.022, 0.14, claw, Vector3(45, 0, 0))
		if sx < 0: _arm_l = sh
		else: _arm_r = sh
	_atk_pivot = _arm_r; _atk_rest = Vector3(52, 0, 0)
	# Head juts forward low on a thick neck (snout pointing at the prey)
	_sp(root, "Neck", Vector3(0, 1.3, 0.26), 0.12, grey)
	_sp(root, "Head", Vector3(0, 1.34, 0.42), 0.16, grey)
	_bx(root, "Snout", Vector3(0, 1.3, 0.58), Vector3(0.13, 0.11, 0.18), grey2)
	_sp(root, "Nose", Vector3(0, 1.32, 0.68), 0.03, dark)
	_cy(root, "EarL", Vector3(-0.1, 1.48, 0.36), 0.0, 0.05, 0.15, grey, Vector3(0, 0, -18))
	_cy(root, "EarR", Vector3(0.1, 1.48, 0.36), 0.0, 0.05, 0.15, grey, Vector3(0, 0, 18))
	_sp(root, "EyeL", Vector3(-0.07, 1.38, 0.52), 0.025, eye, Vector3.ONE, true)
	_sp(root, "EyeR", Vector3(0.07, 1.38, 0.52), 0.025, eye, Vector3.ONE, true)


## Wererabbit: oversized loot-bunny that flees and vanishes — never fights.
func _build_wererabbit() -> void:
	_shadow(0.24)
	var fur := Color.html("b9b2a6")
	var belly := Color.html("e6e1d6")
	var pink := Color.html("d49a92")
	var dark := Color.html("201a16")
	var root := Node3D.new(); root.name = "Body"; root.position.y = 0.12; add_child(root); _bob_node = root; _bob_y = 0.12
	_bx(root, "FootL", Vector3(-0.12, -0.08, 0.12), Vector3(0.14, 0.08, 0.3), fur)
	_bx(root, "FootR", Vector3(0.12, -0.08, 0.12), Vector3(0.14, 0.08, 0.3), fur)
	_sp(root, "Torso", Vector3(0, 0.16, 0), 0.24, fur, Vector3(1.0, 1.15, 1.0))
	_sp(root, "Belly", Vector3(0, 0.12, 0.14), 0.18, belly, Vector3(0.9, 1.0, 0.7))
	_cy(root, "ArmL", Vector3(-0.18, 0.18, 0.1), 0.04, 0.04, 0.18, fur, Vector3(20, 0, -10))
	_cy(root, "ArmR", Vector3(0.18, 0.18, 0.1), 0.04, 0.04, 0.18, fur, Vector3(20, 0, 10))
	_sp(root, "Head", Vector3(0, 0.46, 0.08), 0.16, fur)
	_bx(root, "Muzzle", Vector3(0, 0.42, 0.2), Vector3(0.1, 0.08, 0.08), belly)
	_sp(root, "Nose", Vector3(0, 0.44, 0.25), 0.025, pink)
	_sp(root, "EyeL", Vector3(-0.07, 0.5, 0.17), 0.03, dark); _sp(root, "EyeR", Vector3(0.07, 0.5, 0.17), 0.03, dark)
	_cy(root, "EarL", Vector3(-0.08, 0.68, 0.0), 0.04, 0.06, 0.34, fur, Vector3(-12, 0, -8))
	_cy(root, "EarR", Vector3(0.08, 0.68, 0.0), 0.04, 0.06, 0.34, fur, Vector3(-12, 0, 8))
	_cy(root, "EarInL", Vector3(-0.08, 0.68, 0.03), 0.02, 0.035, 0.3, pink, Vector3(-12, 0, -8))
	_cy(root, "EarInR", Vector3(0.08, 0.68, 0.03), 0.02, 0.035, 0.3, pink, Vector3(-12, 0, 8))
	_sp(root, "Tail", Vector3(0, 0.08, -0.22), 0.08, belly)


## Vampire: pale aristocrat in a Victorian tailcoat with a high red-lined collar.
func _build_vampire() -> void:
	_shadow(0.22)
	var suit := Color.html("1c1a22")
	var suit2 := Color.html("2a2733")
	var cape := Color.html("6e1320")
	var skin := Color.html("d8cbb8")
	var hair := Color.html("141118")
	var red := Color.html("b0202a")
	var root := Node3D.new(); root.name = "Body"; add_child(root); _bob_node = root; _bob_y = 0.0
	_bx(root, "LegL", Vector3(-0.08, 0.22, 0), Vector3(0.11, 0.44, 0.11), suit)
	_bx(root, "LegR", Vector3(0.08, 0.22, 0), Vector3(0.11, 0.44, 0.11), suit)
	_bx(root, "ShoeL", Vector3(-0.08, 0.03, 0.05), Vector3(0.12, 0.06, 0.2), hair)
	_bx(root, "ShoeR", Vector3(0.08, 0.03, 0.05), Vector3(0.12, 0.06, 0.2), hair)
	_bx(root, "Torso", Vector3(0, 0.66, 0), Vector3(0.32, 0.42, 0.2), suit)
	_bx(root, "Vest", Vector3(0, 0.66, 0.09), Vector3(0.16, 0.4, 0.05), suit2)
	_bx(root, "Cravat", Vector3(0, 0.82, 0.1), Vector3(0.06, 0.1, 0.04), Color.html("e8e4dc"))
	# High-collared cape behind the shoulders (red lining)
	_bx(root, "Cape", Vector3(0, 0.74, -0.12), Vector3(0.5, 0.5, 0.06), cape, Vector3(10, 0, 0))
	_bx(root, "CollarL", Vector3(-0.12, 0.92, -0.04), Vector3(0.1, 0.18, 0.04), cape, Vector3(0, 0, -20))
	_bx(root, "CollarR", Vector3(0.12, 0.92, -0.04), Vector3(0.1, 0.18, 0.04), cape, Vector3(0, 0, 20))
	var sh_l := Node3D.new(); sh_l.name = "ShoulderL"; sh_l.position = Vector3(-0.18, 0.84, 0); root.add_child(sh_l)
	_cy(sh_l, "ArmL", Vector3(0, -0.18, 0.02), 0.04, 0.045, 0.36, suit); _sp(sh_l, "HandL", Vector3(0, -0.38, 0.03), 0.045, skin)
	var sh_r := Node3D.new(); sh_r.name = "ShoulderR"; sh_r.position = Vector3(0.18, 0.84, 0); root.add_child(sh_r)
	_cy(sh_r, "ArmR", Vector3(0, -0.18, 0.02), 0.04, 0.045, 0.36, suit); _sp(sh_r, "HandR", Vector3(0, -0.38, 0.03), 0.045, skin)
	_atk_pivot = sh_r; _atk_rest = Vector3.ZERO
	_sp(root, "Head", Vector3(0, 1.04, 0.02), 0.14, skin)
	_sp(root, "Hair", Vector3(0, 1.12, -0.01), 0.15, hair, Vector3(1.05, 0.7, 1.0))
	_bx(root, "Widow", Vector3(0, 1.04, 0.13), Vector3(0.04, 0.05, 0.02), hair)
	_sp(root, "EyeL", Vector3(-0.05, 1.04, 0.12), 0.022, red, Vector3.ONE, true)
	_sp(root, "EyeR", Vector3(0.05, 1.04, 0.12), 0.022, red, Vector3.ONE, true)


## Necromancer: tall hooded figure in a black cloak with a glowing-tipped staff.
func _build_necromancer() -> void:
	_shadow(0.24)
	var cloak := Color.html("1a1820")
	var cloak2 := Color.html("262332")
	var wood := Color.html("5a3f22")
	var skin := Color.html("9aa0a8")
	var eye := Color.html("8a5cff")
	var orb := Color.html("b48cff")
	var root := Node3D.new(); root.name = "Body"; add_child(root); _bob_node = root; _bob_y = 0.0
	_cy(root, "Cloak", Vector3(0, 0.5, 0), 0.1, 0.34, 1.0, cloak)
	_bx(root, "Hem", Vector3(0, 0.04, 0), Vector3(0.46, 0.06, 0.46), cloak2)
	var sh_l := Node3D.new(); sh_l.name = "ShoulderL"; sh_l.position = Vector3(-0.18, 0.82, 0.04); root.add_child(sh_l)
	_cy(sh_l, "ArmL", Vector3(0, -0.16, 0.04), 0.04, 0.05, 0.32, cloak, Vector3(30, 0, 0)); _sp(sh_l, "HandL", Vector3(0, -0.3, 0.12), 0.045, skin)
	var sh_r := Node3D.new(); sh_r.name = "ShoulderR"; sh_r.position = Vector3(0.2, 0.82, 0); root.add_child(sh_r)
	_cy(sh_r, "ArmR", Vector3(0, -0.16, 0.02), 0.04, 0.05, 0.32, cloak); _sp(sh_r, "HandR", Vector3(0, -0.32, 0.04), 0.045, skin)
	_atk_pivot = sh_r; _atk_rest = Vector3.ZERO
	var staff := Node3D.new(); staff.name = "Staff"; staff.position = Vector3(0.26, 0.55, 0.08); root.add_child(staff)
	_cy(staff, "Shaft", Vector3(0, 0, 0), 0.022, 0.026, 1.1, wood)
	_sp(staff, "Orb", Vector3(0, 0.6, 0), 0.07, orb, Vector3.ONE, true)
	_sp(staff, "OrbCore", Vector3(0, 0.6, 0), 0.04, Color.html("ffffff"), Vector3.ONE, true)
	_sp(root, "Head", Vector3(0, 0.96, 0.02), 0.12, Color.html("0c0a10"))
	_cy(root, "Hood", Vector3(0, 1.04, -0.02), 0.0, 0.2, 0.34, cloak)
	_sp(root, "EyeL", Vector3(-0.045, 0.96, 0.1), 0.02, eye, Vector3.ONE, true)
	_sp(root, "EyeR", Vector3(0.045, 0.96, 0.1), 0.02, eye, Vector3.ONE, true)


## Bone Dragon: white skeletal wyrm with bony wings and blood-stained fangs.
func _build_bone_dragon() -> void:
	# A long skeletal wyrm — visible spine, open ribcage, vertebral tail, bony
	# legs/wings, and a blood-fanged skull on a raised neck.
	_shadow(0.5)
	var bone := Color.html("e9e4d6")
	var bone2 := Color.html("d2ccba")
	var blood := Color.html("7a1414")
	var eye := Color.html("c34a2c")
	var root := Node3D.new(); root.name = "Body"; add_child(root); _bob_node = root; _bob_y = 0.0
	var spine_y := 0.92
	# Spine: vertebrae with neural spikes, shoulders (+Z) to hips (-Z)
	var verts := 9
	for i in range(verts):
		var tz := 0.45 - (float(i) / float(verts - 1)) * 1.0
		_sp(root, "Vert%d" % i, Vector3(0, spine_y, tz), 0.055, bone)
		_bx(root, "Neural%d" % i, Vector3(0, spine_y + 0.08, tz), Vector3(0.03, 0.1, 0.03), bone2)
	# Open ribcage: two-segment ribs curving down off the central vertebrae
	for i in range(1, 6):
		var tz := 0.45 - (float(i) / float(verts - 1)) * 1.0
		for sx in [-1, 1]:
			var rp := Node3D.new(); rp.position = Vector3(0, spine_y - 0.02, tz); root.add_child(rp); rp.rotation_degrees = Vector3(0, 0, 30 * sx)
			_cy(rp, "RibA", Vector3(0.16 * sx, -0.2, 0), 0.016, 0.02, 0.42, bone)
			var rc := Node3D.new(); rc.position = Vector3(0.3 * sx, -0.38, 0); rp.add_child(rc); rc.rotation_degrees = Vector3(0, 0, 55 * sx)
			_cy(rc, "RibB", Vector3(-0.06 * sx, -0.15, 0), 0.014, 0.018, 0.32, bone2)
	_cy(root, "Sternum", Vector3(0, spine_y - 0.52, 0.05), 0.02, 0.03, 0.5, bone2, Vector3(90, 0, 0))
	_sp(root, "Shoulders", Vector3(0, spine_y - 0.02, 0.42), 0.12, bone, Vector3(1.4, 0.8, 0.8))
	_sp(root, "Pelvis", Vector3(0, spine_y - 0.04, -0.55), 0.12, bone, Vector3(1.4, 0.8, 0.9))
	# Four bony legs
	_dragon_leg(root, -1, 0.4, true, bone, bone2)
	_dragon_leg(root, 1, 0.4, true, bone, bone2)
	_dragon_leg(root, -1, -0.52, false, bone, bone2)
	_dragon_leg(root, 1, -0.52, false, bone, bone2)
	# Long vertebral tail, curving back and down
	var tail := Node3D.new(); tail.name = "Tail"; tail.position = Vector3(0, spine_y - 0.04, -0.6); root.add_child(tail); tail.rotation_degrees = Vector3(30, 0, 0)
	var segs := 10
	for i in range(segs):
		var f := float(i) / float(segs - 1)
		_sp(tail, "TVert%d" % i, Vector3(0, 0, -i * 0.13), 0.05 - f * 0.035, bone)
		if i < segs - 1:
			_bx(tail, "TSpike%d" % i, Vector3(0, 0.045, -i * 0.13), Vector3(0.02, 0.05, 0.02), bone2)
	# Neck: vertebrae rising forward to the skull (drives bite / breath)
	var neck := Node3D.new(); neck.name = "Neck"; neck.position = Vector3(0, spine_y + 0.02, 0.46); root.add_child(neck); neck.rotation_degrees = Vector3(52, 0, 0)
	_head_pivot = neck; _atk_pivot = neck; _atk_rest = neck.rotation_degrees
	for i in range(5):
		_sp(neck, "NVert%d" % i, Vector3(0, i * 0.13, 0), 0.05, bone)
	var hy := Vector3(0, 0.66, 0.04)
	_sp(neck, "Skull", hy, 0.13, bone, Vector3(0.9, 0.85, 1.5))
	_bx(neck, "Snout", hy + Vector3(0, -0.02, 0.22), Vector3(0.12, 0.09, 0.24), bone)
	_bx(neck, "Jaw", hy + Vector3(0, -0.1, 0.18), Vector3(0.13, 0.04, 0.22), bone2)
	_bx(neck, "Brow", hy + Vector3(0, 0.07, 0.12), Vector3(0.16, 0.04, 0.06), bone2)
	_sp(neck, "EyeL", hy + Vector3(-0.07, 0.03, 0.12), 0.026, eye, Vector3.ONE, true)
	_sp(neck, "EyeR", hy + Vector3(0.07, 0.03, 0.12), 0.026, eye, Vector3.ONE, true)
	for fx in [-0.06, -0.02, 0.02, 0.06]:
		_cy(neck, "Fang", hy + Vector3(fx, -0.06, 0.3), 0.0, 0.014, 0.08, blood, Vector3(180, 0, 0))
	_cy(neck, "HornL", hy + Vector3(-0.07, 0.12, -0.04), 0.0, 0.03, 0.22, bone2, Vector3(-52, 0, -12))
	_cy(neck, "HornR", hy + Vector3(0.07, 0.12, -0.04), 0.0, 0.03, 0.22, bone2, Vector3(-52, 0, 12))
	# Bony wings, swept up and out from the shoulders
	for sx in [-1, 1]:
		var w := Node3D.new(); w.name = "Wing%d" % sx; w.position = Vector3(0.16 * sx, spine_y + 0.08, 0.3); root.add_child(w); w.rotation_degrees = Vector3(8, 0, -36 * sx)
		_cy(w, "WingArm", Vector3(0.3 * sx, 0.16, 0), 0.022, 0.035, 0.66, bone, Vector3(0, 0, 90))
		_bx(w, "Membrane", Vector3(0.38 * sx, 0.06, -0.06), Vector3(0.7, 0.52, 0.02), bone2)
		for r in range(3):
			_cy(w, "Finger%d" % r, Vector3((0.24 + r * 0.18) * sx, 0.2, -0.06), 0.0, 0.018, 0.34, bone, Vector3(0, 0, 90))


## One bony dragon leg (femur -> tibia -> clawed toes). front=true reaches forward.
func _dragon_leg(root: Node3D, sx: int, z: float, front: bool, bone: Color, bone2: Color) -> void:
	var hip := Node3D.new(); hip.position = Vector3(0.22 * sx, 0.86, z); root.add_child(hip)
	hip.rotation_degrees = Vector3(20.0 if front else -16.0, 0, 12 * sx)
	_cy(hip, "Femur", Vector3(0, -0.22, 0), 0.04, 0.055, 0.46, bone)
	_sp(hip, "Joint", Vector3(0, -0.44, 0), 0.05, bone2)
	var lower := Node3D.new(); lower.position = Vector3(0, -0.46, 0); hip.add_child(lower); lower.rotation_degrees = Vector3(-40.0 if front else 50.0, 0, 0)
	_cy(lower, "Tibia", Vector3(0, -0.2, 0), 0.03, 0.04, 0.42, bone)
	for f in range(3):
		_cy(lower, "Toe%d" % f, Vector3(-0.05 + f * 0.05, -0.42, 0.06), 0.0, 0.02, 0.12, bone2, Vector3(60, 0, 0))


## Spirit Collector: ragged figure with a birdcage backpack, scarecrow hat and lantern.
func _build_spirit_collector() -> void:
	_shadow(0.22)
	var burlap := Color.html("9a8453")
	var cloth := Color.html("6b5a38")
	var dark := Color.html("2a2014")
	var metal := Color.html("4a4a52")
	var patch := Color.html("7a3b2a")
	var flame := Color.html("ffd27a")
	var root := Node3D.new(); root.name = "Body"; add_child(root); _bob_node = root; _bob_y = 0.0
	_bx(root, "LegL", Vector3(-0.08, 0.2, 0), Vector3(0.1, 0.4, 0.1), cloth)
	_bx(root, "LegR", Vector3(0.08, 0.2, 0), Vector3(0.1, 0.4, 0.1), cloth)
	_bx(root, "FootL", Vector3(-0.08, 0.03, 0.05), Vector3(0.12, 0.06, 0.18), dark)
	_bx(root, "FootR", Vector3(0.08, 0.03, 0.05), Vector3(0.12, 0.06, 0.18), dark)
	_bx(root, "Torso", Vector3(0, 0.6, 0), Vector3(0.32, 0.4, 0.22), burlap)
	_bx(root, "Patch", Vector3(0.08, 0.58, 0.12), Vector3(0.1, 0.1, 0.02), patch)
	# Birdcage backpack with a trapped soul
	var cage := Node3D.new(); cage.name = "Cage"; cage.position = Vector3(0, 0.66, -0.22); root.add_child(cage)
	_cy(cage, "CageTop", Vector3(0, 0.18, 0), 0.0, 0.06, 0.06, metal)
	for a in range(6):
		var ang := deg_to_rad(a * 60.0)
		_cy(cage, "Bar%d" % a, Vector3(cos(ang) * 0.1, 0, sin(ang) * 0.1), 0.008, 0.008, 0.34, metal)
	_cy(cage, "Ring", Vector3(0, 0.16, 0), 0.1, 0.1, 0.02, metal)
	_cy(cage, "RingB", Vector3(0, -0.16, 0), 0.1, 0.1, 0.02, metal)
	_sp(cage, "Soul", Vector3(0, 0, 0), 0.06, Color.html("bfe6ff"), Vector3.ONE, true)
	var sh_l := Node3D.new(); sh_l.name = "ShoulderL"; sh_l.position = Vector3(-0.18, 0.72, 0); root.add_child(sh_l)
	_cy(sh_l, "ArmL", Vector3(0, -0.16, 0.02), 0.04, 0.045, 0.34, cloth); _sp(sh_l, "HandL", Vector3(0, -0.34, 0.03), 0.045, burlap)
	var sh_r := Node3D.new(); sh_r.name = "ShoulderR"; sh_r.position = Vector3(0.18, 0.72, 0); root.add_child(sh_r)
	_cy(sh_r, "ArmR", Vector3(0, -0.16, 0.02), 0.04, 0.045, 0.34, cloth); _sp(sh_r, "HandR", Vector3(0, -0.34, 0.03), 0.045, burlap)
	_atk_pivot = sh_r; _atk_rest = Vector3.ZERO
	# Lantern carried in the right hand
	var lant := Node3D.new(); lant.name = "Lantern"; lant.position = Vector3(0, -0.42, 0.06); sh_r.add_child(lant)
	_cy(lant, "LTop", Vector3(0, 0.08, 0), 0.0, 0.04, 0.05, metal)
	_bx(lant, "LGlass", Vector3(0, -0.02, 0), Vector3(0.08, 0.12, 0.08), flame)
	_sp(lant, "LFlame", Vector3(0, -0.02, 0), 0.03, Color.html("ffae3c"), Vector3.ONE, true)
	# Head + patched scarecrow hat
	_sp(root, "Head", Vector3(0, 0.92, 0.02), 0.13, Color.html("c9b79a"))
	_sp(root, "EyeL", Vector3(-0.05, 0.92, 0.11), 0.02, dark); _sp(root, "EyeR", Vector3(0.05, 0.92, 0.11), 0.02, dark)
	_cy(root, "HatBrim", Vector3(0, 1.0, 0), 0.22, 0.22, 0.02, cloth)
	_cy(root, "HatCone", Vector3(0, 1.12, 0), 0.0, 0.12, 0.26, burlap)
	_bx(root, "HatPatch", Vector3(0.06, 1.1, 0.1), Vector3(0.06, 0.06, 0.02), patch)


## Grave Titan: massive shaggy white yeti carrying a boulder on its shoulder.
func _build_grave_titan() -> void:
	_shadow(0.46)
	var fur := Color.html("d7d9dd")
	var fur2 := Color.html("b7bcc4")
	var skin := Color.html("8a8f99")
	var dark := Color.html("2a2c30")
	var rock := Color.html("6b6f74")
	var root := Node3D.new(); root.name = "Body"; add_child(root); _bob_node = root; _bob_y = 0.0
	_bx(root, "LegL", Vector3(-0.2, 0.34, 0), Vector3(0.26, 0.6, 0.28), fur)
	_bx(root, "LegR", Vector3(0.2, 0.34, 0), Vector3(0.26, 0.6, 0.28), fur)
	_bx(root, "FootL", Vector3(-0.2, 0.07, 0.08), Vector3(0.3, 0.14, 0.36), fur2)
	_bx(root, "FootR", Vector3(0.2, 0.07, 0.08), Vector3(0.3, 0.14, 0.36), fur2)
	_bx(root, "Torso", Vector3(0, 1.0, -0.02), Vector3(0.7, 0.7, 0.5), fur)
	_sp(root, "Belly", Vector3(0, 0.92, 0.2), 0.26, fur2, Vector3(1.2, 1.0, 0.6))
	_sp(root, "Head", Vector3(0, 1.56, 0.04), 0.24, fur)
	_bx(root, "Face", Vector3(0, 1.5, 0.2), Vector3(0.26, 0.2, 0.1), skin)
	_sp(root, "EyeL", Vector3(-0.08, 1.56, 0.24), 0.03, dark); _sp(root, "EyeR", Vector3(0.08, 1.56, 0.24), 0.03, dark)
	_bx(root, "Mouth", Vector3(0, 1.44, 0.24), Vector3(0.16, 0.04, 0.04), dark)
	var sh_l := Node3D.new(); sh_l.name = "ShoulderL"; sh_l.position = Vector3(-0.4, 1.3, 0); root.add_child(sh_l)
	_bx(sh_l, "ArmL", Vector3(0, -0.3, 0.02), Vector3(0.2, 0.6, 0.2), fur); _sp(sh_l, "FistL", Vector3(0, -0.62, 0.04), 0.13, fur2)
	var sh_r := Node3D.new(); sh_r.name = "ShoulderR"; sh_r.position = Vector3(0.4, 1.3, 0); root.add_child(sh_r)
	_bx(sh_r, "ArmR", Vector3(0, -0.3, 0.02), Vector3(0.2, 0.6, 0.2), fur); _sp(sh_r, "FistR", Vector3(0, -0.62, 0.04), 0.13, fur2)
	_arm_l = sh_l; _arm_r = sh_r; _atk_pivot = sh_r; _atk_rest = Vector3.ZERO
	# Boulder rests on the right shoulder but is parented to the body so it can be
	# lifted off and slammed down / rolled away (see _titan_smash / _titan_roll).
	_titan_boulder = _sp(root, "Boulder", Vector3(0.36, 1.66, -0.02), 0.26, rock)
	_sp(root, "PauldL", Vector3(-0.42, 1.42, 0), 0.18, fur2, Vector3(1.2, 0.8, 1.2))


## Crypt Crawler: a large eight-legged spider with clustered eyes and fangs.
func _build_crypt_crawler() -> void:
	_shadow(0.36)
	var marking := Color.html("7a2a3a")
	var eye := Color.html("d6452e")
	var skin := Color.html("8a8576")
	var skin2 := Color.html("6f6a5c")
	var body := Node3D.new(); body.name = "Body"; add_child(body); _bob_node = body; _bob_y = 0.0
	# Horizontal humanoid torso held parallel to the ground (crawling on all fours)
	_bx(body, "Torso", Vector3(0, 0.5, -0.04), Vector3(0.3, 0.26, 0.56), skin)
	_bx(body, "Spine", Vector3(0, 0.63, -0.04), Vector3(0.12, 0.06, 0.5), skin2)
	_sp(body, "Hips", Vector3(0, 0.48, -0.34), 0.16, skin)
	_sp(body, "Chest", Vector3(0, 0.5, 0.18), 0.16, skin)
	# Human-ish head thrust forward
	_cy(body, "Neck", Vector3(0, 0.52, 0.28), 0.05, 0.06, 0.14, skin2, Vector3(70, 0, 0))
	_sp(body, "Head", Vector3(0, 0.56, 0.4), 0.13, skin)
	_bx(body, "Jaw", Vector3(0, 0.5, 0.46), Vector3(0.11, 0.05, 0.1), skin2)
	_sp(body, "EyeL", Vector3(-0.05, 0.6, 0.48), 0.025, eye, Vector3.ONE, true)
	_sp(body, "EyeR", Vector3(0.05, 0.6, 0.48), 0.025, eye, Vector3.ONE, true)
	_bx(body, "Mouth", Vector3(0, 0.52, 0.5), Vector3(0.07, 0.02, 0.02), marking)
	# Six human arms (3 per side), splayed and planted on the ground, with fingered hands
	for sx in [-1, 1]:
		for zi in range(3):
			_crawler_arm(body, sx, 0.22 - zi * 0.24, skin, skin2)
	_atk_pivot = body; _atk_rest = Vector3.ZERO


## One human-like crawler arm: shoulder -> upper -> elbow -> forearm -> fingered hand.
func _crawler_arm(parent: Node3D, sx: int, z: float, skin: Color, skin2: Color) -> void:
	var sh := Node3D.new(); sh.name = "Shoulder"; sh.position = Vector3(0.14 * sx, 0.52, z); parent.add_child(sh); sh.rotation_degrees = Vector3(8, 0, 62 * sx)
	_cy(sh, "Upper", Vector3(0, -0.17, 0), 0.03, 0.035, 0.34, skin)
	_sp(sh, "ElbowBall", Vector3(0, -0.34, 0), 0.035, skin2)
	var el := Node3D.new(); el.name = "Elbow"; el.position = Vector3(0, -0.34, 0); sh.add_child(el); el.rotation_degrees = Vector3(20, 0, -62 * sx)
	_cy(el, "Fore", Vector3(0, -0.16, 0), 0.025, 0.03, 0.32, skin)
	# Hand: palm flat on the ground, fingers splayed forward
	var hand := Node3D.new(); hand.name = "Hand"; hand.position = Vector3(0, -0.33, 0); el.add_child(hand)
	_bx(hand, "Palm", Vector3(0, 0, 0.03), Vector3(0.08, 0.025, 0.08), skin)
	for f in range(4):
		_bx(hand, "Finger%d" % f, Vector3(-0.027 + f * 0.018, 0, 0.11), Vector3(0.014, 0.02, 0.08), skin2)
	_bx(hand, "Thumb", Vector3(0.05 * sx, 0, 0.03), Vector3(0.014, 0.02, 0.06), skin2)


## Screecher: a soul-creature "seen only from its noise" — a half-transparent
## void wraith, its screaming maw ringed by the sound it gives off.
func _build_screecher() -> void:
	_shadow(0.18)
	var void_c := Color.html("141222")
	var eye := Color.html("c9b6ff")
	var body := Node3D.new(); body.name = "Body"; body.position = Vector3(0, 0.6, 0); add_child(body); _bob_node = body; _bob_y = 0.6
	# Hooded ghost head/torso tapering to a wispy tail
	_sp(body, "Hood", Vector3(0, 0.12, 0), 0.22, void_c, Vector3(1.0, 1.1, 1.0))
	_sp(body, "Torso", Vector3(0, -0.1, 0), 0.2, void_c, Vector3(1.05, 1.0, 1.0))
	for i in range(3):
		_cy(body, "Wisp%d" % i, Vector3((i - 1) * 0.12, -0.34, 0), 0.0, 0.06, 0.3, void_c, Vector3(8 * (i - 1), 0, 0))
	# Wispy arms
	_cy(body, "ArmL", Vector3(-0.2, 0.0, 0.04), 0.0, 0.05, 0.32, void_c, Vector3(20, 0, -30))
	_cy(body, "ArmR", Vector3(0.2, 0.0, 0.04), 0.0, 0.05, 0.32, void_c, Vector3(20, 0, 30))
	# See-through: the body is barely there...
	_ghostify(body, 0.5, 0.25)
	# ...but the scream is not. A gaping dark maw with faint rings of sound
	# rippling out of it — the one thing that gives the creature away.
	_sp(body, "Maw", Vector3(0, 0.06, 0.19), 0.055, Color.html("050508"), Vector3(1.0, 1.3, 0.6))
	for r in range(3):
		var ring := _cy(body, "SoundRing%d" % r, Vector3(0, 0.06, 0.26 + r * 0.09), 0.06 + r * 0.045, 0.06 + r * 0.045, 0.012, eye, Vector3(90, 0, 0))
		ring.material_override = _ghost_mat(eye, 0.5 - r * 0.13, 1.4)
	# Glowing void-eyes
	_sp(body, "EyeL", Vector3(-0.07, 0.14, 0.21), 0.032, eye, Vector3.ONE, true)
	_sp(body, "EyeR", Vector3(0.07, 0.14, 0.21), 0.032, eye, Vector3.ONE, true)
	_atk_pivot = body; _atk_rest = Vector3.ZERO


## The Consumed: a hulking flesh-golem with red lacerations baring its muscle.
func _build_consumed() -> void:
	_shadow(0.32)
	var flesh := Color.html("5a4a48")
	var flesh2 := Color.html("6e5856")
	var muscle := Color.html("9a2a28")
	var dark := Color.html("1a1414")
	var eye := Color.html("ff5a3a")
	var root := Node3D.new(); root.name = "Body"; add_child(root); _bob_node = root; _bob_y = 0.0
	_bx(root, "LegL", Vector3(-0.16, 0.3, 0), Vector3(0.22, 0.5, 0.22), flesh)
	_bx(root, "LegR", Vector3(0.16, 0.3, 0), Vector3(0.22, 0.5, 0.22), flesh)
	_bx(root, "FootL", Vector3(-0.16, 0.06, 0.06), Vector3(0.24, 0.12, 0.3), dark)
	_bx(root, "FootR", Vector3(0.16, 0.06, 0.06), Vector3(0.24, 0.12, 0.3), dark)
	_bx(root, "GashLeg", Vector3(-0.16, 0.34, 0.12), Vector3(0.05, 0.2, 0.02), muscle)
	var torso := _bx(root, "Torso", Vector3(0, 0.86, -0.02), Vector3(0.56, 0.6, 0.4), flesh)
	torso.rotation_degrees = Vector3(6, 0, 0)
	_bx(root, "GashChest", Vector3(-0.06, 0.9, 0.2), Vector3(0.06, 0.34, 0.02), muscle, Vector3(0, 0, 12))
	_bx(root, "GashChest2", Vector3(0.12, 0.84, 0.2), Vector3(0.05, 0.24, 0.02), muscle, Vector3(0, 0, -16))
	_sp(root, "Head", Vector3(0, 1.22, 0.04), 0.18, flesh2)
	_bx(root, "Brow", Vector3(0, 1.26, 0.16), Vector3(0.3, 0.05, 0.06), dark)
	_sp(root, "EyeL", Vector3(-0.07, 1.2, 0.17), 0.028, eye, Vector3.ONE, true)
	_sp(root, "EyeR", Vector3(0.07, 1.2, 0.17), 0.028, eye, Vector3.ONE, true)
	_bx(root, "Maw", Vector3(0, 1.1, 0.17), Vector3(0.16, 0.06, 0.04), muscle)
	var sh_l := Node3D.new(); sh_l.name = "ShoulderL"; sh_l.position = Vector3(-0.34, 1.06, 0); root.add_child(sh_l)
	_bx(sh_l, "ArmL", Vector3(0, -0.3, 0.02), Vector3(0.18, 0.56, 0.2), flesh); _sp(sh_l, "FistL", Vector3(0, -0.6, 0.04), 0.12, flesh2)
	_bx(sh_l, "GashArmL", Vector3(0, -0.3, 0.12), Vector3(0.04, 0.3, 0.02), muscle)
	var sh_r := Node3D.new(); sh_r.name = "ShoulderR"; sh_r.position = Vector3(0.34, 1.06, 0); root.add_child(sh_r)
	_bx(sh_r, "ArmR", Vector3(0, -0.3, 0.02), Vector3(0.18, 0.56, 0.2), flesh); _sp(sh_r, "FistR", Vector3(0, -0.6, 0.04), 0.12, flesh2)
	_bx(sh_r, "GashArmR", Vector3(0, -0.3, 0.12), Vector3(0.04, 0.3, 0.02), muscle)
	_atk_pivot = sh_r; _atk_rest = Vector3.ZERO


# =============================================================
# SEWER ACT MODELS
# =============================================================

## Sludge Being: a low gelatinous ooze with eyes floating in the goo.
func _build_sludge() -> void:
	_shadow(0.3)
	var ooze := Color.html("3fa05a")
	var ooze2 := Color.html("57c074")
	var dark := Color.html("16301f")
	var eye := Color.html("eaffea")
	var body := Node3D.new(); body.name = "Body"; body.position = Vector3(0, 0.18, 0); add_child(body); _bob_node = body; _bob_y = 0.18
	_sp(body, "Blob", Vector3(0, 0, 0), 0.3, ooze, Vector3(1.2, 0.85, 1.2))
	_sp(body, "Blob2", Vector3(-0.14, -0.04, 0.08), 0.16, ooze2, Vector3(1.0, 0.8, 1.0))
	_sp(body, "Blob3", Vector3(0.16, -0.05, -0.06), 0.14, ooze2, Vector3(1.0, 0.7, 1.0))
	_sp(body, "Drip", Vector3(0.1, 0.16, 0.12), 0.06, ooze)
	_sp(body, "EyeL", Vector3(-0.08, 0.06, 0.25), 0.04, eye, Vector3.ONE, true)
	_sp(body, "EyeR", Vector3(0.09, 0.07, 0.23), 0.04, eye, Vector3.ONE, true)
	_sp(body, "PupilL", Vector3(-0.08, 0.06, 0.28), 0.018, dark)
	_sp(body, "PupilR", Vector3(0.09, 0.07, 0.26), 0.018, dark)
	_atk_pivot = body; _atk_rest = Vector3.ZERO


## Pipe Crawler: a humanoid that scuttles on all fours with extra back-limbs.
func _build_pipe_crawler() -> void:
	_shadow(0.26)
	var skin := Color.html("7a8a6e")
	var skin2 := Color.html("63725a")
	var dark := Color.html("1c1f18")
	var eye := Color.html("b7ff7a")
	var root := Node3D.new(); root.name = "Body"; add_child(root); _bob_node = root; _bob_y = 0.0
	_bx(root, "Torso", Vector3(0, 0.46, 0), Vector3(0.34, 0.26, 0.52), skin)
	for sx in [-1, 1]:
		_cy(root, "ArmF%d" % sx, Vector3(0.16 * sx, 0.24, 0.22), 0.04, 0.05, 0.46, skin, Vector3(10, 0, 0))
		_sp(root, "HandF%d" % sx, Vector3(0.16 * sx, 0.02, 0.26), 0.05, skin2)
		_cy(root, "LegB%d" % sx, Vector3(0.14 * sx, 0.24, -0.2), 0.045, 0.055, 0.46, skin, Vector3(-10, 0, 0))
		_sp(root, "FootB%d" % sx, Vector3(0.14 * sx, 0.02, -0.22), 0.05, skin2)
	# Extra limbs sprouting from the back (these swipe on attack)
	var extras := []
	for sx in [-1, 1]:
		var xl := Node3D.new(); xl.name = "Extra%d" % sx; xl.position = Vector3(0.1 * sx, 0.62, -0.02); root.add_child(xl); xl.rotation_degrees = Vector3(-40, 0, 30 * sx)
		_cy(xl, "XArm", Vector3(0, 0.2, 0), 0.03, 0.035, 0.4, skin2)
		_cy(xl, "XClawA", Vector3(-0.03, 0.42, 0), 0.0, 0.018, 0.1, dark, Vector3(20, 0, 0))
		_cy(xl, "XClawB", Vector3(0.03, 0.42, 0), 0.0, 0.018, 0.1, dark, Vector3(20, 0, 0))
		extras.append(xl)
	_arm_l = extras[0]; _arm_r = extras[1]
	_sp(root, "Head", Vector3(0, 0.46, 0.32), 0.13, skin)
	_bx(root, "Jaw", Vector3(0, 0.42, 0.42), Vector3(0.1, 0.05, 0.1), skin2)
	_sp(root, "EyeL", Vector3(-0.05, 0.5, 0.4), 0.025, eye, Vector3.ONE, true)
	_sp(root, "EyeR", Vector3(0.05, 0.5, 0.4), 0.025, eye, Vector3.ONE, true)
	_atk_pivot = root; _atk_rest = Vector3.ZERO


## Sewer Crocodile: a long armoured reptile with a snapping jaw.
func _build_sewer_croc() -> void:
	_shadow(0.4)
	var green := Color.html("46603a")
	var green2 := Color.html("5c7a4a")
	var belly := Color.html("9aa873")
	var dark := Color.html("141a10")
	var tooth := Color.html("e8e4d0")
	var eye := Color.html("d2b83a")
	var body := Node3D.new(); body.name = "Body"; body.position = Vector3(0, 0.16, 0); add_child(body); _bob_node = body; _bob_y = 0.16
	# Long, low body (croc silhouette)
	_sp(body, "Torso", Vector3(0, 0, -0.12), 0.26, green, Vector3(1.0, 0.55, 2.4))
	_sp(body, "Belly", Vector3(0, -0.1, -0.08), 0.2, belly, Vector3(0.95, 0.4, 2.1))
	# Armour: a central ridge of tall scutes flanked by two rows of smaller
	# osteoderms, so the back reads as plated hide (break it to expose him).
	for i in range(5):
		_cy(body, "Ridge%d" % i, Vector3(0, 0.1, 0.2 - i * 0.16), 0.0, 0.035, 0.09, green2, Vector3(-20, 0, 0))
		for sx in [-1, 1]:
			_cy(body, "Scute%d_%d" % [i, sx], Vector3(0.13 * sx, 0.06, 0.2 - i * 0.16), 0.0, 0.028, 0.06, green2, Vector3(-20, 0, 26 * sx))
	_cy(body, "Tail", Vector3(0, 0.0, -0.62), 0.02, 0.14, 0.74, green, Vector3(90, 0, 0))
	for i in range(3):
		_cy(body, "TailRidge%d" % i, Vector3(0, 0.08 - i * 0.02, -0.56 - i * 0.14), 0.0, 0.03 - i * 0.005, 0.07, green2, Vector3(-25, 0, 0))
	for sx in [-1, 1]:
		_cy(body, "LegF%d" % sx, Vector3(0.24 * sx, -0.08, 0.2), 0.04, 0.05, 0.18, green, Vector3(0, 0, 55 * sx))
		_cy(body, "LegB%d" % sx, Vector3(0.24 * sx, -0.08, -0.34), 0.04, 0.05, 0.18, green, Vector3(0, 0, 55 * sx))
		for f in range(3):
			_cy(body, "ClawF%d_%d" % [sx, f], Vector3(0.32 * sx, -0.16, 0.14 + f * 0.05), 0.0, 0.014, 0.06, tooth, Vector3(70, 0, 20 * sx))
	# Long flat head + a lower jaw on a pivot that snaps shut on the bite
	var head := Node3D.new(); head.name = "Head"; head.position = Vector3(0, -0.02, 0.34); body.add_child(head)
	_head_pivot = head
	_sp(head, "Skull", Vector3(0, 0.04, 0.06), 0.15, green, Vector3(1.0, 0.65, 1.2))
	_bx(head, "Snout", Vector3(0, 0.0, 0.36), Vector3(0.16, 0.09, 0.56), green)
	_sp(head, "EyeL", Vector3(-0.1, 0.12, 0.04), 0.035, eye, Vector3.ONE, true)
	_sp(head, "EyeR", Vector3(0.1, 0.12, 0.04), 0.035, eye, Vector3.ONE, true)
	_sp(head, "NostrilL", Vector3(-0.04, 0.06, 0.62), 0.02, dark)
	_sp(head, "NostrilR", Vector3(0.04, 0.06, 0.62), 0.02, dark)
	for tz in [0.22, 0.38, 0.54]:
		_bx(head, "ToothUL%d" % int(tz * 100), Vector3(-0.07, -0.05, tz), Vector3(0.02, 0.06, 0.02), tooth)
		_bx(head, "ToothUR%d" % int(tz * 100), Vector3(0.07, -0.05, tz), Vector3(0.02, 0.06, 0.02), tooth)
	var jaw := Node3D.new(); jaw.name = "Jaw"; jaw.position = Vector3(0, -0.06, 0.12); head.add_child(jaw)
	_atk_pivot = jaw; _atk_rest = Vector3.ZERO
	_bx(jaw, "JawBox", Vector3(0, -0.01, 0.24), Vector3(0.15, 0.05, 0.5), green2)


## Rat King: an oversized crowned rat (reuses the rat model at larger scale).
func _build_rat_king() -> void:
	var body := _build_rat_into(self, 1.5)
	_bob_node = body
	_bob_y = body.position.y
	_atk_pivot = body
	_atk_rest = Vector3.ZERO
	var gold := Color.html("e8c34a")
	var gem := Color.html("c0392b")
	var crown := Node3D.new(); crown.name = "Crown"; crown.position = Vector3(0, 0.2, 0.42); body.add_child(crown)
	_cy(crown, "Band", Vector3(0, 0, 0), 0.13, 0.13, 0.07, gold)
	for a in range(5):
		var ang := deg_to_rad(a * 72.0)
		_cy(crown, "Point%d" % a, Vector3(cos(ang) * 0.11, 0.08, sin(ang) * 0.11), 0.0, 0.022, 0.09, gold)
		_sp(crown, "Gem%d" % a, Vector3(cos(ang) * 0.11, 0.13, sin(ang) * 0.11), 0.02, gem, Vector3.ONE, true)
	# Stolen royal finery: a ragged crimson cape pinned at the shoulders with a
	# gold clasp, trailing off the back in torn strips.
	var cape := Color.html("6e1320")
	var cape2 := Color.html("531019")
	_bx(body, "CapeShoulders", Vector3(0, 0.2, 0.1), Vector3(0.4, 0.05, 0.2), cape)
	_sp(body, "Clasp", Vector3(0, 0.24, 0.2), 0.035, gold)
	_bx(body, "CapeBack", Vector3(0, 0.1, -0.16), Vector3(0.38, 0.05, 0.36), cape, Vector3(-12, 0, 0))
	for i in range(3):
		_bx(body, "CapeTail%d" % i, Vector3(-0.12 + i * 0.12, 0.02, -0.4), Vector3(0.09, 0.04, 0.22 + (i % 2) * 0.08), cape2, Vector3(-18, 0, 0))
	# The king's eyes burn red in the dark of the cistern
	for en in ["EyeL", "EyeR"]:
		var e := body.get_node_or_null(en)
		if e is MeshInstance3D:
			e.material_override = _mat(gem, true)


## Swarm: a single unit made of a cluster of small winged bugs.
func _build_swarm() -> void:
	_shadow(0.3)
	var bug := Color.html("2a2420")
	var bug2 := Color.html("3e352c")
	var wing := Color.html("8a8f99")
	var glow := Color.html("c9ff6a")
	var body := Node3D.new(); body.name = "Body"; body.position = Vector3(0, 0.4, 0); add_child(body); _bob_node = body; _bob_y = 0.4
	var positions := [Vector3(0, 0, 0), Vector3(0.16, 0.05, 0.04), Vector3(-0.14, 0.08, -0.05), Vector3(0.06, 0.16, -0.08), Vector3(-0.08, -0.06, 0.12), Vector3(0.12, -0.08, -0.1), Vector3(-0.16, -0.02, 0.06), Vector3(0.02, 0.1, 0.16), Vector3(-0.02, -0.14, -0.04), Vector3(0.1, 0.02, 0.14)]
	for i in range(positions.size()):
		var p: Vector3 = positions[i]
		var c: Color = bug if i % 2 == 0 else bug2
		_sp(body, "Bug%d" % i, p, 0.06, c)
		_bx(body, "Wing%dL" % i, p + Vector3(-0.05, 0.03, 0), Vector3(0.08, 0.01, 0.05), wing)
		_bx(body, "Wing%dR" % i, p + Vector3(0.05, 0.03, 0), Vector3(0.08, 0.01, 0.05), wing)
	_sp(body, "Glow0", Vector3(0.05, 0.05, 0.18), 0.02, glow, Vector3.ONE, true)
	_sp(body, "Glow1", Vector3(-0.1, 0.1, 0.1), 0.02, glow, Vector3.ONE, true)
	_atk_pivot = body; _atk_rest = Vector3.ZERO


# =============================================================
# MOUNTAINS ACT MODELS
# =============================================================

## Weregoat: minotaur-built — human torso/arms, goat head and digitigrade goat legs.
func _build_weregoat() -> void:
	_shadow(0.3)
	var fur := Color.html("c9c2b2"); var skin := Color.html("b9b0a0"); var dark := Color.html("2a241c"); var horn := Color.html("6b5a3a"); var hoof := Color.html("2a2420")
	var root := Node3D.new(); root.name = "Body"; add_child(root); _bob_node = root; _bob_y = 0.0
	for sx in [-1, 1]:
		var hip := Node3D.new(); hip.position = Vector3(0.13 * sx, 0.62, -0.04); hip.rotation_degrees = Vector3(-25, 0, 0); root.add_child(hip)
		_cy(hip, "Thigh", Vector3(0, -0.18, 0), 0.07, 0.08, 0.36, fur)
		var knee := Node3D.new(); knee.position = Vector3(0, -0.36, 0); knee.rotation_degrees = Vector3(52, 0, 0); hip.add_child(knee)
		_cy(knee, "Shin", Vector3(0, -0.16, 0), 0.05, 0.06, 0.34, fur)
		_bx(knee, "Hoof", Vector3(0, -0.34, 0.04), Vector3(0.09, 0.1, 0.14), hoof)
	_bx(root, "Torso", Vector3(0, 0.92, 0), Vector3(0.4, 0.44, 0.26), fur)
	_sp(root, "Belly", Vector3(0, 0.84, 0.12), 0.18, skin, Vector3(1.0, 1.0, 0.6))
	for sx in [-1, 1]:
		var sh := Node3D.new(); sh.name = "Shoulder%d" % sx; sh.position = Vector3(0.26 * sx, 1.1, 0); root.add_child(sh)
		_cy(sh, "Arm", Vector3(0, -0.2, 0.02), 0.05, 0.06, 0.42, fur); _sp(sh, "Hand", Vector3(0, -0.42, 0.04), 0.07, skin)
		if sx < 0: _arm_l = sh
		else: _arm_r = sh
	_atk_pivot = _arm_r; _atk_rest = Vector3.ZERO
	_sp(root, "Head", Vector3(0, 1.34, 0.06), 0.16, fur)
	_bx(root, "Snout", Vector3(0, 1.28, 0.2), Vector3(0.12, 0.1, 0.14), skin)
	_sp(root, "Nose", Vector3(0, 1.26, 0.28), 0.03, dark)
	_bx(root, "Beard", Vector3(0, 1.2, 0.16), Vector3(0.08, 0.1, 0.04), fur)
	_cy(root, "HornL", Vector3(-0.1, 1.46, 0.0), 0.0, 0.04, 0.26, horn, Vector3(40, 0, -22))
	_cy(root, "HornR", Vector3(0.1, 1.46, 0.0), 0.0, 0.04, 0.26, horn, Vector3(40, 0, 22))
	_cy(root, "EarL", Vector3(-0.17, 1.36, 0.04), 0.0, 0.04, 0.12, fur, Vector3(0, 0, 72))
	_cy(root, "EarR", Vector3(0.17, 1.36, 0.04), 0.0, 0.04, 0.12, fur, Vector3(0, 0, -72))
	_sp(root, "EyeL", Vector3(-0.06, 1.34, 0.18), 0.022, dark); _sp(root, "EyeR", Vector3(0.06, 1.34, 0.18), 0.022, dark)


## Wyvern: a long, lean, low-slung dragon — serpentine trunk on two taloned
## legs, a long neck and tail, and broad membrane wings. No arms.
func _build_wyvern() -> void:
	_shadow(0.4)
	var hide := Color.html("5a6b6e"); var hide2 := Color.html("44545a"); var membrane := Color.html("728890"); var dark := Color.html("16201f"); var eye := Color.html("e0c23a")
	var body := Node3D.new(); body.name = "Body"; add_child(body); _bob_node = body; _bob_y = 0.0
	# Two hind legs carrying the body low to the ground.
	for sx in [-1, 1]:
		_cy(body, "Leg%d" % sx, Vector3(0.15 * sx, 0.24, 0.02), 0.05, 0.07, 0.42, hide, Vector3(6, 0, 0))
		for f in range(3): _cy(body, "Talon%d_%d" % [sx, f], Vector3(0.15 * sx - 0.05 + f * 0.05, 0.02, 0.2), 0.0, 0.018, 0.12, dark, Vector3(60, 0, 0))
	# Long serpentine trunk: chest -> barrel -> hips, stretched front-to-back.
	_sp(body, "Chest", Vector3(0, 0.58, 0.22), 0.16, hide, Vector3(1.05, 1.05, 1.1))
	_sp(body, "Barrel", Vector3(0, 0.55, 0.0), 0.15, hide, Vector3(1.0, 0.95, 1.25))
	_sp(body, "Hips", Vector3(0, 0.52, -0.22), 0.13, hide, Vector3(0.95, 0.9, 1.1))
	_sp(body, "Belly", Vector3(0, 0.46, 0.06), 0.12, hide2, Vector3(0.82, 0.66, 1.7))
	# Long tapering tail sweeping back and down to a barbed tip.
	_cy(body, "Tail1", Vector3(0, 0.47, -0.48), 0.04, 0.11, 0.5, hide, Vector3(-72, 0, 0))
	_cy(body, "Tail2", Vector3(0, 0.34, -0.78), 0.018, 0.045, 0.44, hide, Vector3(-52, 0, 0))
	_pr(body, "Barb", Vector3(0, 0.24, -1.0), Vector3(0.12, 0.18, 0.02), hide2, Vector3(-52, 0, 0))
	# Long neck rising from the chest to a slender dragon head.
	_cy(body, "Neck1", Vector3(0, 0.74, 0.3), 0.07, 0.11, 0.36, hide, Vector3(42, 0, 0))
	_cy(body, "Neck2", Vector3(0, 0.94, 0.42), 0.05, 0.07, 0.26, hide, Vector3(14, 0, 0))
	_sp(body, "Head", Vector3(0, 1.02, 0.5), 0.1, hide, Vector3(1.0, 1.0, 1.35))
	_cy(body, "Snout", Vector3(0, 0.985, 0.66), 0.028, 0.07, 0.22, hide2, Vector3(80, 0, 0))
	_bx(body, "Jaw", Vector3(0, 0.95, 0.62), Vector3(0.08, 0.035, 0.18), dark)
	for sx in [-1, 1]: _cy(body, "Horn%d" % sx, Vector3(0.05 * sx, 1.12, 0.42), 0.0, 0.025, 0.2, dark, Vector3(-52, 0, 12 * sx))
	_sp(body, "EyeL", Vector3(-0.06, 1.05, 0.58), 0.022, eye, Vector3.ONE, true); _sp(body, "EyeR", Vector3(0.06, 1.05, 0.58), 0.022, eye, Vector3.ONE, true)
	# Broad membrane wings spreading up and out from the shoulders.
	for sx in [-1, 1]:
		var w := Node3D.new(); w.name = "Wing%d" % sx; w.position = Vector3(0.1 * sx, 0.68, 0.06); w.rotation_degrees = Vector3(6, 16 * sx, -44 * sx); body.add_child(w)
		_bat_wing(w, sx, 0.66, 0.52, membrane, hide)
	_atk_pivot = body; _atk_rest = Vector3.ZERO


## Roc: enormous bird, big talons, brown plumage with a white-checkered mane.
func _build_roc() -> void:
	_shadow(0.5)
	var brown := Color.html("6b4f2f"); var brown2 := Color.html("8a6a3f"); var white := Color.html("e8e2d4"); var beak := Color.html("e0a32a"); var dark := Color.html("1a120a")
	var body := Node3D.new(); body.name = "Body"; body.position = Vector3(0, 0.62, 0); add_child(body); _bob_node = body; _bob_y = 0.62
	_sp(body, "Torso", Vector3(0, 0, -0.05), 0.3, brown, Vector3(1.0, 1.1, 1.3))
	for i in range(4):
		var c: Color = white if i % 2 == 0 else brown2
		_sp(body, "Mane%d" % i, Vector3(0, 0.2 + i * 0.06, 0.12), 0.16 - i * 0.02, c, Vector3(1.1, 0.7, 1.0))
	_sp(body, "Head", Vector3(0, 0.5, 0.18), 0.15, brown)
	_cy(body, "Beak", Vector3(0, 0.46, 0.34), 0.0, 0.06, 0.16, beak, Vector3(80, 0, 0))
	_sp(body, "EyeL", Vector3(-0.07, 0.54, 0.26), 0.028, dark); _sp(body, "EyeR", Vector3(0.07, 0.54, 0.26), 0.028, dark)
	# Folded wings draped down the flanks (not spread out to the sides).
	for sx in [-1, 1]:
		var w := Node3D.new(); w.name = "Wing%d" % sx; w.position = Vector3(0.26 * sx, 0.14, -0.04); w.rotation_degrees = Vector3(0, 0, -8 * sx); body.add_child(w)
		_bird_wing(w, sx, 7, 0.62, brown, brown2)
	for sx in [-1, 1]:
		_cy(body, "Leg%d" % sx, Vector3(0.12 * sx, -0.32, 0.06), 0.04, 0.05, 0.3, beak)
		for f in range(3): _cy(body, "Talon%d_%d" % [sx, f], Vector3(0.12 * sx - 0.06 + f * 0.06, -0.48, 0.16), 0.0, 0.025, 0.16, dark, Vector3(62, 0, 0))
	_bx(body, "Tail", Vector3(0, 0.0, -0.4), Vector3(0.36, 0.04, 0.3), brown2)
	_atk_pivot = body; _atk_rest = Vector3.ZERO


## Ice Troll: bigger than the Armored Troll — taller, huge hands and feet, no weapon.
func _build_ice_troll() -> void:
	_shadow(0.44)
	var skin := Color.html("8fb6c6"); var belly := Color.html("b6d6e0"); var dark := Color.html("16242a"); var ice := Color.html("dff2f8")
	var root := Node3D.new(); root.name = "Body"; add_child(root); _bob_node = root; _bob_y = 0.0
	_bx(root, "LegL", Vector3(-0.2, 0.38, 0), Vector3(0.26, 0.72, 0.28), skin)
	_bx(root, "LegR", Vector3(0.2, 0.38, 0), Vector3(0.26, 0.72, 0.28), skin)
	_bx(root, "FootL", Vector3(-0.2, 0.08, 0.14), Vector3(0.34, 0.16, 0.5), dark)
	_bx(root, "FootR", Vector3(0.2, 0.08, 0.14), Vector3(0.34, 0.16, 0.5), dark)
	var torso := _bx(root, "Torso", Vector3(0, 1.2, -0.02), Vector3(0.7, 0.74, 0.5), skin)
	torso.rotation_degrees = Vector3(6, 0, 0)
	_sp(root, "Belly", Vector3(0, 1.1, 0.2), 0.24, belly, Vector3(1.2, 1.0, 0.6))
	_sp(root, "Head", Vector3(0, 1.74, 0.05), 0.24, skin)
	_bx(root, "Brow", Vector3(0, 1.82, 0.2), Vector3(0.42, 0.07, 0.1), dark)
	_sp(root, "EyeL", Vector3(-0.09, 1.74, 0.22), 0.03, ice, Vector3.ONE, true); _sp(root, "EyeR", Vector3(0.09, 1.74, 0.22), 0.03, ice, Vector3.ONE, true)
	_cy(root, "TuskL", Vector3(-0.08, 1.62, 0.22), 0.0, 0.03, 0.14, ice, Vector3(20, 0, 0)); _cy(root, "TuskR", Vector3(0.08, 1.62, 0.22), 0.0, 0.03, 0.14, ice, Vector3(20, 0, 0))
	for sx in [-1, 1]:
		var sh := Node3D.new(); sh.name = "Shoulder%d" % sx; sh.position = Vector3(0.42 * sx, 1.5, 0); root.add_child(sh)
		_bx(sh, "Arm", Vector3(0, -0.34, 0.02), Vector3(0.2, 0.66, 0.2), skin)
		_sp(sh, "Hand", Vector3(0, -0.74, 0.04), 0.2, belly)   # oversized hands
		if sx < 0: _arm_l = sh
		else: _arm_r = sh
	_atk_pivot = _arm_r; _atk_rest = Vector3.ZERO
	_sp(root, "PauldL", Vector3(-0.46, 1.62, 0), 0.17, ice, Vector3(1.2, 0.8, 1.2)); _sp(root, "PauldR", Vector3(0.46, 1.62, 0), 0.17, ice, Vector3(1.2, 0.8, 1.2))


## Snow Wraith: a pale spirit trailing tattered cloth.
func _build_snow_wraith() -> void:
	_shadow(0.2)
	var pale := Color.html("dfe8ee"); var pale2 := Color.html("aebfcc"); var eye := Color.html("8fd0ff")
	var body := Node3D.new(); body.name = "Body"; body.position = Vector3(0, 0.62, 0); add_child(body); _bob_node = body; _bob_y = 0.62
	_sp(body, "Hood", Vector3(0, 0.14, 0), 0.22, pale, Vector3(1.0, 1.1, 1.0))
	_sp(body, "Torso", Vector3(0, -0.08, 0), 0.2, pale, Vector3(1.05, 1.0, 1.0))
	for i in range(4):
		_cy(body, "Tatter%d" % i, Vector3((i - 1.5) * 0.12, -0.34, 0.02), 0.0, 0.06, 0.34 + (i % 2) * 0.1, pale2, Vector3(10 * (i - 1.5), 0, 0))
	_cy(body, "ArmL", Vector3(-0.22, -0.02, 0.04), 0.0, 0.05, 0.34, pale, Vector3(20, 0, -36))
	_cy(body, "ArmR", Vector3(0.22, -0.02, 0.04), 0.0, 0.05, 0.34, pale, Vector3(20, 0, 36))
	_bx(body, "Shawl", Vector3(0, 0.02, -0.04), Vector3(0.42, 0.16, 0.1), pale2, Vector3(8, 0, 0))
	# Translucent like blowing snow, with a cold inner glow
	_ghostify(body, 0.6, 0.3)
	_sp(body, "EyeL", Vector3(-0.07, 0.16, 0.18), 0.03, eye, Vector3.ONE, true); _sp(body, "EyeR", Vector3(0.07, 0.16, 0.18), 0.03, eye, Vector3.ONE, true)
	_atk_pivot = body; _atk_rest = Vector3.ZERO


## Granite Colossus: a huge, rigid figure of mountain stone.
func _build_granite_colossus() -> void:
	_shadow(0.5)
	var stone := Color.html("6f7378"); var stone2 := Color.html("585c61"); var dark := Color.html("2a2d30"); var glow := Color.html("c98a3a")
	var root := Node3D.new(); root.name = "Body"; add_child(root); _bob_node = root; _bob_y = 0.0
	_bx(root, "LegL", Vector3(-0.22, 0.42, 0), Vector3(0.3, 0.84, 0.3), stone)
	_bx(root, "LegR", Vector3(0.22, 0.42, 0), Vector3(0.3, 0.84, 0.3), stone2)
	_bx(root, "FootL", Vector3(-0.22, 0.08, 0.06), Vector3(0.34, 0.16, 0.4), stone2)
	_bx(root, "FootR", Vector3(0.22, 0.08, 0.06), Vector3(0.34, 0.16, 0.4), stone)
	_bx(root, "Torso", Vector3(0, 1.36, 0), Vector3(0.78, 0.86, 0.56), stone)
	_bx(root, "Slab", Vector3(0, 1.4, 0.26), Vector3(0.5, 0.6, 0.08), stone2)
	# craggy cracks glowing faintly
	_bx(root, "Crack0", Vector3(-0.1, 1.4, 0.31), Vector3(0.04, 0.4, 0.02), glow, Vector3(0, 0, 10))
	_bx(root, "Crack1", Vector3(0.12, 1.2, 0.31), Vector3(0.04, 0.3, 0.02), glow, Vector3(0, 0, -16))
	_bx(root, "Head", Vector3(0, 1.96, 0.04), Vector3(0.38, 0.36, 0.36), stone)
	_sp(root, "EyeL", Vector3(-0.09, 1.98, 0.2), 0.035, glow, Vector3.ONE, true); _sp(root, "EyeR", Vector3(0.09, 1.98, 0.2), 0.035, glow, Vector3.ONE, true)
	for sx in [-1, 1]:
		var sh := Node3D.new(); sh.name = "Shoulder%d" % sx; sh.position = Vector3(0.5 * sx, 1.66, 0); root.add_child(sh)
		_bx(sh, "Arm", Vector3(0, -0.36, 0.02), Vector3(0.24, 0.72, 0.24), stone2)
		_bx(sh, "Fist", Vector3(0, -0.8, 0.04), Vector3(0.3, 0.3, 0.3), stone)
		if sx < 0: _arm_l = sh
		else: _arm_r = sh
	_atk_pivot = _arm_r; _atk_rest = Vector3.ZERO


## White Manticore: snow-leopard body with bat wings and a spiked tail.
func _build_white_manticore() -> void:
	var body := _build_quadruped(Color.html("dfe4ea"), Color.html("f2f5f8"), 1.1, "round", "stub")
	_bob_node = body
	_bob_y = body.position.y
	_atk_pivot = body
	_atk_rest = Vector3.ZERO
	var grey := Color.html("9aa3ad"); var dark := Color.html("2a2f35"); var spike := Color.html("e8eef2")
	# leopard rosettes
	for p in [Vector3(0.12, 0.1, 0.0), Vector3(-0.1, 0.06, -0.12), Vector3(0.04, 0.14, 0.18), Vector3(-0.06, 0.08, 0.1)]:
		_sp(body, "Spot", p, 0.03, grey)
	# bat wings
	for sx in [-1, 1]:
		var w := Node3D.new(); w.name = "Wing%d" % sx; w.position = Vector3(0.14 * sx, 0.22, -0.04); w.rotation_degrees = Vector3(8, 14 * sx, -40 * sx); body.add_child(w)
		_bat_wing(w, sx, 0.54, 0.42, Color.html("c4ccd4"), grey)
	# spiked scorpion-ish tail arching over the back
	var tail := Node3D.new(); tail.name = "STail"; tail.position = Vector3(0, 0.06, -0.4); tail.rotation_degrees = Vector3(40, 0, 0); body.add_child(tail)
	_cy(tail, "Seg", Vector3(0, 0.22, 0), 0.03, 0.05, 0.5, Color.html("dfe4ea"))
	_sp(tail, "Barb", Vector3(0, 0.46, 0.04), 0.06, grey)
	for s in range(3): _cy(tail, "Sting%d" % s, Vector3(-0.04 + s * 0.04, 0.54, 0.06), 0.0, 0.018, 0.1, spike, Vector3(40, 0, 0))


## Sabertooth Tiger: standard big cat with long sabre fangs.
func _build_sabertooth() -> void:
	var body := _build_quadruped(Color.html("b88a4a"), Color.html("e6d2a8"), 1.05, "round", "stub")
	_bob_node = body
	_bob_y = body.position.y
	_atk_pivot = body
	_atk_rest = Vector3.ZERO
	var dark := Color.html("3a2c16"); var tooth := Color.html("efe9d6")
	# dark stripes running down the back and haunch
	for z in [0.18, 0.04, -0.12, -0.26]:
		_bx(body, "Stripe%d" % int(z * 100), Vector3(0, 0.17, z), Vector3(0.07, 0.05, 0.04), dark)
	# long sabre fangs hanging from the muzzle
	_cy(body, "FangL", Vector3(-0.05, 0.05, 0.62), 0.0, 0.022, 0.24, tooth, Vector3(172, 0, 0))
	_cy(body, "FangR", Vector3(0.05, 0.05, 0.62), 0.0, 0.022, 0.24, tooth, Vector3(172, 0, 0))


# =============================================================
# UNDERWORLD ACT MODELS
# =============================================================

## A Cerberus head on a short, thick (hydra-style) neck: a stout tapered neck
## plus throat, an elongated muzzled head with glowing eyes, dog ears, and a
## spiked collar at the base.
func _cerberus_head(parent: Node3D, base: Vector3, pitch: float, yaw: float, roll: float, fur: Color, belly: Color, dark: Color, eye: Color, steel: Color) -> Node3D:
	var hp := Node3D.new()
	hp.name = "Head%d" % parent.get_child_count()
	hp.position = base
	hp.rotation_degrees = Vector3(pitch, yaw, roll)
	parent.add_child(hp)
	var nl := 0.16   # short neck...
	_cy(hp, "Neck", Vector3(0, nl * 0.5, 0.0), 0.1, 0.13, nl, fur)   # ...and thick
	_cy(hp, "Throat", Vector3(0, nl * 0.5, 0.06), 0.07, 0.1, nl * 0.92, belly)
	var h := Vector3(0, nl + 0.04, 0.05)
	_sp(hp, "Head", h, 0.12, fur, Vector3(1.0, 0.95, 1.35))
	_bx(hp, "Snout", h + Vector3(0, -0.04, 0.17), Vector3(0.12, 0.09, 0.15), fur)
	_sp(hp, "Nose", h + Vector3(0, -0.04, 0.25), 0.03, dark)
	_sp(hp, "EyeL", h + Vector3(-0.06, 0.05, 0.08), 0.022, eye, Vector3.ONE, true)
	_sp(hp, "EyeR", h + Vector3(0.06, 0.05, 0.08), 0.022, eye, Vector3.ONE, true)
	_cy(hp, "EarL", h + Vector3(-0.09, 0.09, -0.04), 0.0, 0.045, 0.12, fur, Vector3(-14, 0, 18))
	_cy(hp, "EarR", h + Vector3(0.09, 0.09, -0.04), 0.0, 0.045, 0.12, fur, Vector3(-14, 0, -18))
	_cy(hp, "Collar", Vector3(0, 0.05, 0.03), 0.13, 0.13, 0.05, dark)
	for s in range(4): _cy(hp, "Spike%d" % s, Vector3(cos(s * PI / 2) * 0.13, 0.05, 0.03 + sin(s * PI / 2) * 0.13), 0.0, 0.02, 0.06, steel, Vector3(90 if s % 2 else 0, 0, 90 * s))
	return hp


## Cerberus: three-headed hound with spiked collars and a dangling chain. Builds
## the trunk via the quadruped (no head) and adds its own three short-necked heads.
func _build_cerberus() -> void:
	var fur := Color.html("3a3036"); var belly := Color.html("241d22"); var dark := Color.html("141016"); var eye := Color.html("ff6a2a"); var steel := Color.html("9aa0a8"); var chain := Color.html("6a6a72")
	var body := _build_quadruped(fur, belly, 1.15, "pointed", "stub", false)
	_bob_node = body
	_bob_y = body.position.y
	_atk_pivot = body
	_atk_rest = Vector3.ZERO
	# Three stout heads rearing up from the shoulders: one forward, two splayed out.
	_cerberus_head(body, Vector3(0, 0.18, 0.28), 30, 0, 0, fur, belly, dark, eye, steel)
	for hx in [-1, 1]:
		_cerberus_head(body, Vector3(0.24 * hx, 0.12, 0.2), 24, 36 * -hx, 14 * -hx, fur, belly, dark, eye, steel)
	# a chain dangling from the left head's collar
	var c := Node3D.new(); c.position = Vector3(-0.16, 0.06, 0.3); body.add_child(c)
	for i in range(4): _sp(c, "Link%d" % i, Vector3(0, -i * 0.07, 0), 0.03, chain)


## Succubus: winged fey in short shorts, sleeveless top, elbow gloves, small horns.
func _build_succubus() -> void:
	_shadow(0.22)
	var skin := Color.html("d98a9a"); var cloth := Color.html("3a1622"); var glove := Color.html("5a1020"); var boot := Color.html("4a0e1c"); var hair := Color.html("1a1016"); var wing := Color.html("7a2238"); var horn := Color.html("2a1016")
	var root := Node3D.new(); root.name = "Body"; add_child(root); _bob_node = root; _bob_y = 0.0
	# long boots
	for sx in [-1, 1]:
		_cy(root, "Boot%d" % sx, Vector3(0.09 * sx, 0.26, 0), 0.055, 0.065, 0.5, boot)
		_bx(root, "Heel%d" % sx, Vector3(0.09 * sx, 0.03, 0.05), Vector3(0.1, 0.06, 0.18), boot)
	_bx(root, "Shorts", Vector3(0, 0.54, 0), Vector3(0.26, 0.14, 0.18), cloth)
	_bx(root, "Top", Vector3(0, 0.74, 0), Vector3(0.26, 0.28, 0.18), cloth)
	_sp(root, "Bust", Vector3(0, 0.72, 0.1), 0.13, skin, Vector3(1.2, 0.7, 0.7))
	# bare shoulders + elbow-length gloves
	for sx in [-1, 1]:
		var sh := Node3D.new(); sh.name = "Shoulder%d" % sx; sh.position = Vector3(0.17 * sx, 0.86, 0); root.add_child(sh)
		_sp(sh, "Delt", Vector3(0, 0, 0), 0.06, skin)
		_cy(sh, "UpperArm", Vector3(0, -0.14, 0.02), 0.035, 0.04, 0.26, skin)
		_cy(sh, "Glove", Vector3(0, -0.34, 0.03), 0.035, 0.04, 0.22, glove); _sp(sh, "Hand", Vector3(0, -0.46, 0.03), 0.04, glove)
		if sx < 0: _arm_l = sh
		else: _arm_r = sh
	_atk_pivot = _arm_r; _atk_rest = Vector3.ZERO
	_sp(root, "Head", Vector3(0, 1.06, 0.02), 0.13, skin)
	_sp(root, "Hair", Vector3(0, 1.12, -0.04), 0.15, hair, Vector3(1.1, 1.0, 1.1))
	_cy(root, "HornL", Vector3(-0.07, 1.18, 0.0), 0.0, 0.022, 0.1, horn, Vector3(-20, 0, -16)); _cy(root, "HornR", Vector3(0.07, 1.18, 0.0), 0.0, 0.022, 0.1, horn, Vector3(-20, 0, 16))
	_sp(root, "EyeL", Vector3(-0.05, 1.07, 0.11), 0.02, Color.html("ff3a5a"), Vector3.ONE, true); _sp(root, "EyeR", Vector3(0.05, 1.07, 0.11), 0.02, Color.html("ff3a5a"), Vector3.ONE, true)
	for sx in [-1, 1]:
		var w := Node3D.new(); w.name = "Wing%d" % sx; w.position = Vector3(0.1 * sx, 0.86, -0.12); w.rotation_degrees = Vector3(6, 12 * sx, -34 * sx); root.add_child(w)
		_bat_wing(w, sx, 0.44, 0.36, wing, horn)


## Demon: red brute with spiral thorns; dagger in one hand, trident in the other.
func _build_demon() -> void:
	_shadow(0.28)
	var red := Color.html("9a2420"); var red2 := Color.html("b8362c"); var dark := Color.html("2a0e0c"); var horn := Color.html("3a1410"); var steel := Color.html("b9bdc6"); var wood := Color.html("4a3018")
	var root := Node3D.new(); root.name = "Body"; add_child(root); _bob_node = root; _bob_y = 0.0
	_bx(root, "LegL", Vector3(-0.12, 0.28, 0), Vector3(0.16, 0.5, 0.16), red)
	_bx(root, "LegR", Vector3(0.12, 0.28, 0), Vector3(0.16, 0.5, 0.16), red)
	_bx(root, "FootL", Vector3(-0.12, 0.04, 0.06), Vector3(0.16, 0.08, 0.22), dark)
	_bx(root, "FootR", Vector3(0.12, 0.04, 0.06), Vector3(0.16, 0.08, 0.22), dark)
	var torso := _bx(root, "Torso", Vector3(0, 0.84, 0), Vector3(0.46, 0.5, 0.3), red); torso.rotation_degrees = Vector3(4, 0, 0)
	# spiral thorns on shoulders/back: stacked segments, each curling further over
	for t in [Vector3(-0.26, 1.06, -0.04), Vector3(0.26, 1.06, -0.04), Vector3(0, 1.14, -0.12)]:
		var thorn := Node3D.new(); thorn.position = t; thorn.rotation_degrees = Vector3(-24, 0, 0); root.add_child(thorn)
		_cy(thorn, "ThornA", Vector3(0, 0.08, 0), 0.032, 0.05, 0.16, horn)
		var mid := Node3D.new(); mid.position = Vector3(0, 0.16, 0); mid.rotation_degrees = Vector3(-42, 0, 0); thorn.add_child(mid)
		_cy(mid, "ThornB", Vector3(0, 0.06, 0), 0.018, 0.032, 0.12, horn)
		var tip := Node3D.new(); tip.position = Vector3(0, 0.12, 0); tip.rotation_degrees = Vector3(-52, 0, 0); mid.add_child(tip)
		_cy(tip, "ThornC", Vector3(0, 0.045, 0), 0.0, 0.018, 0.09, horn)
	_sp(root, "Head", Vector3(0, 1.2, 0.04), 0.16, red2)
	_cy(root, "HornL", Vector3(-0.1, 1.32, 0.0), 0.0, 0.035, 0.24, horn, Vector3(-26, 0, -22)); _cy(root, "HornR", Vector3(0.1, 1.32, 0.0), 0.0, 0.035, 0.24, horn, Vector3(-26, 0, 22))
	_sp(root, "EyeL", Vector3(-0.06, 1.21, 0.16), 0.024, Color.html("ffd23f"), Vector3.ONE, true); _sp(root, "EyeR", Vector3(0.06, 1.21, 0.16), 0.024, Color.html("ffd23f"), Vector3.ONE, true)
	# left arm holds a dagger, right arm a trident
	var sh_l := Node3D.new(); sh_l.name = "ShoulderL"; sh_l.position = Vector3(-0.28, 1.04, 0); root.add_child(sh_l)
	_cy(sh_l, "Arm", Vector3(0, -0.22, 0.02), 0.055, 0.06, 0.44, red); _sp(sh_l, "Hand", Vector3(0, -0.46, 0.04), 0.07, red2)
	_bx(sh_l, "DaggerBlade", Vector3(0, -0.62, 0.08), Vector3(0.04, 0.22, 0.015), steel); _bx(sh_l, "DaggerGuard", Vector3(0, -0.5, 0.08), Vector3(0.12, 0.03, 0.04), dark)
	var sh_r := Node3D.new(); sh_r.name = "ShoulderR"; sh_r.position = Vector3(0.28, 1.04, 0); root.add_child(sh_r)
	_cy(sh_r, "Arm", Vector3(0, -0.22, 0.02), 0.055, 0.06, 0.44, red); _sp(sh_r, "Hand", Vector3(0, -0.46, 0.04), 0.07, red2)
	_cy(sh_r, "Shaft", Vector3(0, -0.3, 0.12), 0.02, 0.025, 1.0, wood)
	_bx(sh_r, "Prong0", Vector3(0, 0.16, 0.12), Vector3(0.02, 0.18, 0.02), steel); _bx(sh_r, "Prong1", Vector3(-0.07, 0.15, 0.12), Vector3(0.02, 0.16, 0.02), steel); _bx(sh_r, "Prong2", Vector3(0.07, 0.15, 0.12), Vector3(0.02, 0.16, 0.02), steel)
	_arm_l = sh_l; _arm_r = sh_r; _atk_pivot = sh_r; _atk_rest = Vector3.ZERO


## Ifrit: hulking bipedal fire-hound with huge, near-ground arms (monkey proportions).
func _build_ifrit() -> void:
	_shadow(0.32)
	var coal := Color.html("3a201a"); var ember := Color.html("c9421a"); var glow := Color.html("ff7a1a"); var dark := Color.html("180c08"); var claw := Color.html("e8c08a")
	var root := Node3D.new(); root.name = "Body"; add_child(root); _bob_node = root; _bob_y = 0.0
	# short bent legs
	for sx in [-1, 1]:
		_cy(root, "Leg%d" % sx, Vector3(0.14 * sx, 0.3, -0.02), 0.08, 0.1, 0.4, coal)
		_bx(root, "Foot%d" % sx, Vector3(0.14 * sx, 0.06, 0.1), Vector3(0.18, 0.1, 0.28), dark)
	var torso := _bx(root, "Torso", Vector3(0, 0.86, 0.06), Vector3(0.5, 0.5, 0.34), coal); torso.rotation_degrees = Vector3(20, 0, 0)
	_sp(root, "Chest", Vector3(0, 0.84, 0.24), 0.2, ember, Vector3(1.1, 1.0, 0.7))
	# ember cracks
	_bx(root, "Vent0", Vector3(-0.08, 0.9, 0.24), Vector3(0.04, 0.2, 0.02), glow); _bx(root, "Vent1", Vector3(0.1, 0.82, 0.24), Vector3(0.04, 0.16, 0.02), glow)
	# long muscular arms reaching near the ground
	for sx in [-1, 1]:
		var sh := Node3D.new(); sh.name = "Shoulder%d" % sx; sh.position = Vector3(0.3 * sx, 1.08, 0.1); sh.rotation_degrees = Vector3(34, 0, 0); root.add_child(sh)
		_cy(sh, "Upper", Vector3(0, -0.3, 0), 0.1, 0.11, 0.56, coal)
		var el := Node3D.new(); el.position = Vector3(0, -0.58, 0); el.rotation_degrees = Vector3(-30, 0, 0); sh.add_child(el)
		_cy(el, "Fore", Vector3(0, -0.26, 0), 0.09, 0.1, 0.5, coal); _sp(el, "Fist", Vector3(0, -0.52, 0.02), 0.13, ember)
		for k in range(3): _cy(el, "Claw%d" % k, Vector3(-0.07 + k * 0.07, -0.6, 0.1), 0.0, 0.022, 0.14, claw, Vector3(45, 0, 0))
		if sx < 0: _arm_l = sh
		else: _arm_r = sh
	_atk_pivot = _arm_r; _atk_rest = Vector3(34, 0, 0)
	# canine head
	_sp(root, "Head", Vector3(0, 1.22, 0.18), 0.16, coal)
	_bx(root, "Snout", Vector3(0, 1.16, 0.34), Vector3(0.14, 0.1, 0.18), coal)
	_sp(root, "EyeL", Vector3(-0.07, 1.24, 0.3), 0.026, glow, Vector3.ONE, true); _sp(root, "EyeR", Vector3(0.07, 1.24, 0.3), 0.026, glow, Vector3.ONE, true)
	_cy(root, "EarL", Vector3(-0.1, 1.34, 0.1), 0.0, 0.05, 0.14, coal, Vector3(-10, 0, -20)); _cy(root, "EarR", Vector3(0.1, 1.34, 0.1), 0.0, 0.05, 0.14, coal, Vector3(-10, 0, 20))


## Mind Eater: an original gaunt, hunched flesh-horror with raking claws.
func _build_mind_eater() -> void:
	_shadow(0.28)
	var flesh := Color.html("6a5f57"); var flesh2 := Color.html("7e7268"); var dark := Color.html("1a1512"); var maw := Color.html("7a1f22"); var eye := Color.html("c9ff6a")
	var root := Node3D.new(); root.name = "Body"; add_child(root); _bob_node = root; _bob_y = 0.0
	for sx in [-1, 1]:
		var hip := Node3D.new(); hip.position = Vector3(0.13 * sx, 0.66, -0.04); hip.rotation_degrees = Vector3(-22, 0, 0); root.add_child(hip)
		_cy(hip, "Thigh", Vector3(0, -0.2, 0), 0.08, 0.09, 0.4, flesh)
		var knee := Node3D.new(); knee.position = Vector3(0, -0.4, 0); knee.rotation_degrees = Vector3(46, 0, 0); hip.add_child(knee)
		_cy(knee, "Shin", Vector3(0, -0.18, 0), 0.06, 0.07, 0.38, flesh)
		_bx(knee, "Foot", Vector3(0, -0.36, 0.08), Vector3(0.14, 0.08, 0.26), dark)
	var torso := _bx(root, "Torso", Vector3(0, 0.92, 0.1), Vector3(0.42, 0.5, 0.3), flesh); torso.rotation_degrees = Vector3(30, 0, 0)
	_sp(root, "Ribs", Vector3(0, 0.9, 0.26), 0.2, flesh2, Vector3(1.1, 1.0, 0.7))
	for i in range(3): _bx(root, "Rib%d" % i, Vector3(0, 0.82 + i * 0.08, 0.38), Vector3(0.34, 0.02, 0.02), dark)
	# long clawed arms hanging forward
	for sx in [-1, 1]:
		var sh := Node3D.new(); sh.name = "Shoulder%d" % sx; sh.position = Vector3(0.26 * sx, 1.1, 0.16); sh.rotation_degrees = Vector3(46, 0, 0); root.add_child(sh)
		_cy(sh, "Upper", Vector3(0, -0.26, 0), 0.06, 0.07, 0.5, flesh)
		var el := Node3D.new(); el.position = Vector3(0, -0.5, 0); el.rotation_degrees = Vector3(-34, 0, 0); sh.add_child(el)
		_cy(el, "Fore", Vector3(0, -0.24, 0), 0.05, 0.06, 0.46, flesh)
		for k in range(3): _cy(el, "Claw%d" % k, Vector3(-0.06 + k * 0.06, -0.5, 0.06), 0.0, 0.02, 0.18, flesh2, Vector3(30, 0, 0))
		if sx < 0: _arm_l = sh
		else: _arm_r = sh
	_atk_pivot = _arm_r; _atk_rest = Vector3(46, 0, 0)
	# small head with a wide fanged maw
	_sp(root, "Head", Vector3(0, 1.28, 0.34), 0.14, flesh)
	_bx(root, "Maw", Vector3(0, 1.22, 0.46), Vector3(0.16, 0.08, 0.06), maw)
	for fx in [-0.06, 0.0, 0.06]: _cy(root, "Tooth%d" % int(fx * 100), Vector3(fx, 1.2, 0.48), 0.0, 0.012, 0.05, Color.html("e8e2d0"), Vector3(180, 0, 0))
	_sp(root, "EyeL", Vector3(-0.05, 1.32, 0.44), 0.022, eye, Vector3.ONE, true); _sp(root, "EyeR", Vector3(0.05, 1.32, 0.44), 0.022, eye, Vector3.ONE, true)


## Specter: a dark shadow-humanoid.
func _build_specter() -> void:
	_shadow(0.2)
	var shade := Color.html("16141c"); var shade2 := Color.html("241f2e"); var eye := Color.html("a98cff")
	var body := Node3D.new(); body.name = "Body"; body.position = Vector3(0, 0.5, 0); add_child(body); _bob_node = body; _bob_y = 0.5
	_sp(body, "Head", Vector3(0, 0.5, 0.02), 0.13, shade)
	_bx(body, "Torso", Vector3(0, 0.22, 0), Vector3(0.26, 0.4, 0.18), shade)
	_sp(body, "Shoulders", Vector3(0, 0.4, 0), 0.16, shade2, Vector3(1.5, 0.6, 0.9))
	for sx in [-1, 1]:
		var sh := Node3D.new(); sh.name = "Shoulder%d" % sx; sh.position = Vector3(0.16 * sx, 0.42, 0); sh.rotation_degrees = Vector3(0, 0, 10 * sx); body.add_child(sh)
		_cy(sh, "Arm", Vector3(0, -0.2, 0.02), 0.04, 0.05, 0.4, shade)
		_cy(sh, "Claw", Vector3(0, -0.42, 0.04), 0.0, 0.03, 0.1, shade2)
		if sx < 0: _arm_l = sh
		else: _arm_r = sh
	_atk_pivot = _arm_r; _atk_rest = Vector3.ZERO
	# wispy lower body instead of legs
	for i in range(3): _cy(body, "Wisp%d" % i, Vector3((i - 1) * 0.1, -0.18, 0), 0.0, 0.07, 0.42, shade2, Vector3(10 * (i - 1), 0, 0))
	# A shadow you can half see through
	_ghostify(body, 0.55, 0.2)
	_sp(body, "EyeL", Vector3(-0.05, 0.52, 0.11), 0.026, eye, Vector3.ONE, true); _sp(body, "EyeR", Vector3(0.05, 0.52, 0.11), 0.026, eye, Vector3.ONE, true)


## Magma Spider: a big tarantula in red/orange/black with glowing seams.
func _build_magma_spider() -> void:
	_shadow(0.36)
	var black := Color.html("241712"); var red := Color.html("8a2a14"); var glow := Color.html("ff7a1a"); var fang := Color.html("e0a060")
	var body := Node3D.new(); body.name = "Body"; body.position = Vector3(0, 0.26, 0); add_child(body); _bob_node = body; _bob_y = 0.26
	_sp(body, "Abdomen", Vector3(0, 0.04, -0.24), 0.26, black, Vector3(1.1, 0.95, 1.2))
	_sp(body, "AbGlow", Vector3(0, 0.16, -0.24), 0.12, glow, Vector3(0.7, 0.5, 0.9), true)
	# molten cracks veining down the abdomen from the glowing crest
	for c in range(4):
		var ca := deg_to_rad(-50.0 + c * 34.0)
		_bx(body, "Vein%d" % c, Vector3(sin(ca) * 0.2, 0.1, -0.24 + cos(ca) * 0.12), Vector3(0.025, 0.14, 0.025), glow, Vector3(20 * cos(ca), 0, -rad_to_deg(ca) * 0.5))
	_sp(body, "Cephalo", Vector3(0, 0.02, 0.12), 0.18, red)
	for ex in [-0.07, -0.025, 0.025, 0.07]: _sp(body, "Eye", Vector3(ex, 0.08, 0.26), 0.022, glow, Vector3.ONE, true)
	_cy(body, "FangL", Vector3(-0.05, -0.08, 0.26), 0.0, 0.025, 0.12, fang, Vector3(40, 0, 0)); _cy(body, "FangR", Vector3(0.05, -0.08, 0.26), 0.0, 0.025, 0.12, fang, Vector3(40, 0, 0))
	# 8 hairy legs angled out and down to the ground
	for sx in [-1, 1]:
		for i in range(4):
			var lz := 0.18 - i * 0.13
			var leg := Node3D.new(); leg.position = Vector3(0.14 * sx, 0.04, lz); leg.rotation_degrees = Vector3(0, 0, 64 * sx); body.add_child(leg)
			var col: Color = red if i % 2 == 0 else black
			_cy(leg, "Upper", Vector3(0, -0.18, 0), 0.02, 0.025, 0.36, col)
			_sp(leg, "Joint", Vector3(0, -0.34, 0), 0.026, glow, Vector3.ONE, true)  # magma seeping at the knee
			var lower := Node3D.new(); lower.position = Vector3(0, -0.34, 0); lower.rotation_degrees = Vector3(0, 0, -78 * sx); leg.add_child(lower)
			_cy(lower, "Lower", Vector3(0, -0.18, 0), 0.015, 0.02, 0.36, col)
	_atk_pivot = body; _atk_rest = Vector3.ZERO


## Pit Fiend: a larger, regal demon with a barbed tail and a coiled whip.
func _build_pit_fiend() -> void:
	_shadow(0.34)
	var red := Color.html("7a1c18"); var red2 := Color.html("9a2a22"); var dark := Color.html("220a08"); var horn := Color.html("301010"); var gold := Color.html("c9a23a"); var leather := Color.html("2a1810")
	var root := Node3D.new(); root.name = "Body"; add_child(root); _bob_node = root; _bob_y = 0.0
	_bx(root, "LegL", Vector3(-0.15, 0.34, 0), Vector3(0.2, 0.6, 0.2), red)
	_bx(root, "LegR", Vector3(0.15, 0.34, 0), Vector3(0.2, 0.6, 0.2), red)
	_bx(root, "FootL", Vector3(-0.15, 0.05, 0.07), Vector3(0.2, 0.1, 0.26), dark)
	_bx(root, "FootR", Vector3(0.15, 0.05, 0.07), Vector3(0.2, 0.1, 0.26), dark)
	var torso := _bx(root, "Torso", Vector3(0, 1.04, 0), Vector3(0.56, 0.6, 0.36), red); torso.rotation_degrees = Vector3(4, 0, 0)
	_bx(root, "Sash", Vector3(0, 1.02, 0.16), Vector3(0.5, 0.1, 0.06), gold, Vector3(0, 0, 22))
	_sp(root, "PauldL", Vector3(-0.34, 1.32, 0), 0.16, red2, Vector3(1.2, 0.9, 1.2)); _sp(root, "PauldR", Vector3(0.34, 1.32, 0), 0.16, red2, Vector3(1.2, 0.9, 1.2))
	_sp(root, "Head", Vector3(0, 1.46, 0.04), 0.18, red2)
	_cy(root, "HornL", Vector3(-0.12, 1.6, 0.0), 0.0, 0.04, 0.3, horn, Vector3(-20, 0, -26)); _cy(root, "HornR", Vector3(0.12, 1.6, 0.0), 0.0, 0.04, 0.3, horn, Vector3(-20, 0, 26))
	_sp(root, "EyeL", Vector3(-0.07, 1.47, 0.18), 0.026, gold, Vector3.ONE, true); _sp(root, "EyeR", Vector3(0.07, 1.47, 0.18), 0.026, gold, Vector3.ONE, true)
	# thin tail with an arrowhead barb
	var tail := Node3D.new(); tail.position = Vector3(0, 0.7, -0.2); tail.rotation_degrees = Vector3(40, 0, 0); root.add_child(tail)
	_cy(tail, "Tail", Vector3(0, -0.3, 0), 0.018, 0.03, 0.7, red)
	_bx(tail, "Barb", Vector3(0, -0.66, 0), Vector3(0.1, 0.14, 0.03), dark, Vector3(0, 0, 45))
	# left arm; right arm holds a coiled whip
	var sh_l := Node3D.new(); sh_l.name = "ShoulderL"; sh_l.position = Vector3(-0.32, 1.28, 0); root.add_child(sh_l)
	_cy(sh_l, "Arm", Vector3(0, -0.26, 0.02), 0.06, 0.07, 0.5, red); _sp(sh_l, "Hand", Vector3(0, -0.52, 0.04), 0.08, red2)
	var sh_r := Node3D.new(); sh_r.name = "ShoulderR"; sh_r.position = Vector3(0.32, 1.28, 0); root.add_child(sh_r)
	_cy(sh_r, "Arm", Vector3(0, -0.26, 0.02), 0.06, 0.07, 0.5, red); _sp(sh_r, "Hand", Vector3(0, -0.52, 0.04), 0.08, red2)
	for i in range(3): _cy(sh_r, "Whip%d" % i, Vector3(0.04 + i * 0.02, -0.52 - i * 0.04, 0.08 + i * 0.06), 0.012, 0.012, 0.16, leather, Vector3(70, 0, 0))
	_arm_l = sh_l; _arm_r = sh_r; _atk_pivot = sh_r; _atk_rest = Vector3.ZERO


## Ash Harpy: a winged harpy seemingly formed of ash and embers.
func _build_ash_harpy() -> void:
	_shadow(0.26)
	var ash := Color.html("4a4640"); var ash2 := Color.html("63605a"); var ember := Color.html("d9531f"); var dark := Color.html("1a1714")
	var body := Node3D.new(); body.name = "Body"; body.position = Vector3(0, 0.62, 0); add_child(body); _bob_node = body; _bob_y = 0.62
	_bx(body, "Torso", Vector3(0, 0.0, 0), Vector3(0.26, 0.4, 0.18), ash)
	_sp(body, "Bust", Vector3(0, 0.02, 0.1), 0.12, ash2, Vector3(1.2, 0.7, 0.7))
	_sp(body, "Head", Vector3(0, 0.34, 0.02), 0.13, ash2)
	_sp(body, "Hair", Vector3(0, 0.4, -0.04), 0.14, ash, Vector3(1.1, 1.0, 1.1))
	_sp(body, "EyeL", Vector3(-0.05, 0.35, 0.1), 0.022, ember, Vector3.ONE, true); _sp(body, "EyeR", Vector3(0.05, 0.35, 0.1), 0.022, ember, Vector3.ONE, true)
	# wing-arms: layered ash-grey flight feathers, still smouldering at the tips
	for sx in [-1, 1]:
		var w := Node3D.new(); w.name = "Wing%d" % sx; w.position = Vector3(0.14 * sx, 0.16, -0.02); w.rotation_degrees = Vector3(4, 0, 12 * sx); body.add_child(w)
		_spread_wing(w, sx, 0.6, 0.22, ash, ash2)
		for e in range(3):
			_sp(w, "Ember%d" % e, Vector3((0.24 + e * 0.16) * sx, -0.01, -0.1 - e * 0.04), 0.022, ember, Vector3.ONE, true)
		if sx < 0: _arm_l = w
		else: _arm_r = w
	_atk_pivot = _arm_r; _atk_rest = Vector3(4, 0, -30)
	# clawed bird legs
	for sx in [-1, 1]:
		_cy(body, "Leg%d" % sx, Vector3(0.08 * sx, -0.3, 0.02), 0.03, 0.04, 0.3, ash2)
		for f in range(3): _cy(body, "Talon%d_%d" % [sx, f], Vector3(0.08 * sx - 0.04 + f * 0.04, -0.46, 0.08), 0.0, 0.016, 0.1, dark, Vector3(60, 0, 0))


## Inflamed Minotaur: a smouldering minotaur hefting a fiery great-axe.
func _build_inflamed_minotaur() -> void:
	_shadow(0.36)
	var hide := Color.html("4a2e22"); var hide2 := Color.html("613c2a"); var dark := Color.html("180c08"); var horn := Color.html("d8cdb6"); var fire := Color.html("ff7a1a"); var steel := Color.html("8a8f99"); var wood := Color.html("3a2616")
	var root := Node3D.new(); root.name = "Body"; add_child(root); _bob_node = root; _bob_y = 0.0
	for sx in [-1, 1]:
		_cy(root, "Leg%d" % sx, Vector3(0.16 * sx, 0.4, 0), 0.1, 0.12, 0.5, hide)
		_bx(root, "Hoof%d" % sx, Vector3(0.16 * sx, 0.06, 0.04), Vector3(0.18, 0.12, 0.24), dark)
	var torso := _bx(root, "Torso", Vector3(0, 1.06, 0), Vector3(0.6, 0.62, 0.4), hide); torso.rotation_degrees = Vector3(6, 0, 0)
	_sp(root, "Belly", Vector3(0, 0.96, 0.2), 0.22, hide2, Vector3(1.2, 1.0, 0.6))
	# ember glow on the hide
	_bx(root, "Glow0", Vector3(-0.12, 1.06, 0.21), Vector3(0.04, 0.3, 0.02), fire); _bx(root, "Glow1", Vector3(0.14, 0.98, 0.21), Vector3(0.04, 0.22, 0.02), fire)
	_sp(root, "Head", Vector3(0, 1.52, 0.06), 0.2, hide2)
	_bx(root, "Snout", Vector3(0, 1.46, 0.22), Vector3(0.16, 0.12, 0.14), hide)
	_cy(root, "HornL", Vector3(-0.18, 1.58, 0.04), 0.0, 0.04, 0.26, horn, Vector3(20, 0, 64)); _cy(root, "HornR", Vector3(0.18, 1.58, 0.04), 0.0, 0.04, 0.26, horn, Vector3(20, 0, -64))
	_sp(root, "EyeL", Vector3(-0.08, 1.52, 0.2), 0.028, fire, Vector3.ONE, true); _sp(root, "EyeR", Vector3(0.08, 1.52, 0.2), 0.028, fire, Vector3.ONE, true)
	var sh_l := Node3D.new(); sh_l.name = "ShoulderL"; sh_l.position = Vector3(-0.36, 1.32, 0); root.add_child(sh_l)
	_bx(sh_l, "Arm", Vector3(0, -0.3, 0.02), Vector3(0.18, 0.58, 0.18), hide); _sp(sh_l, "Fist", Vector3(0, -0.62, 0.04), 0.12, hide2)
	var sh_r := Node3D.new(); sh_r.name = "ShoulderR"; sh_r.position = Vector3(0.36, 1.32, 0); root.add_child(sh_r)
	_bx(sh_r, "Arm", Vector3(0, -0.3, 0.02), Vector3(0.18, 0.58, 0.18), hide); _sp(sh_r, "Fist", Vector3(0, -0.62, 0.04), 0.12, hide2)
	# fiery great-axe in the right hand
	var axe := Node3D.new(); axe.position = Vector3(0, -0.66, 0.1); axe.rotation_degrees = Vector3(20, 0, 0); sh_r.add_child(axe)
	_cy(axe, "Haft", Vector3(0, 0.0, 0), 0.03, 0.035, 0.9, wood)
	_bx(axe, "Blade", Vector3(0.16, 0.34, 0), Vector3(0.3, 0.34, 0.04), steel, Vector3(0, 0, -12))
	_bx(axe, "BladeFire", Vector3(0.26, 0.34, 0), Vector3(0.14, 0.4, 0.03), fire, Vector3(0, 0, -12))
	_arm_l = sh_l; _arm_r = sh_r; _atk_pivot = sh_r; _atk_rest = Vector3.ZERO


# =============================================================
# HEAVENS ACT MODELS
# =============================================================

## Cherub: an adult winged archer in a toga, holding a bow.
func _build_cherub() -> void:
	_shadow(0.22)
	var skin := Color.html("e8c8a8"); var robe := Color.html("f0ece0"); var robe2 := Color.html("d8d2c2"); var hair := Color.html("c9a25a"); var wood := Color.html("8a6a3a"); var gold := Color.html("e8c34a")
	var root := Node3D.new(); root.name = "Body"; add_child(root); _bob_node = root; _bob_y = 0.0
	_cy(root, "Robe", Vector3(0, 0.34, 0), 0.12, 0.26, 0.66, robe)
	_bx(root, "Sash", Vector3(0, 0.5, 0.0), Vector3(0.34, 0.06, 0.3), gold, Vector3(0, 0, 18))
	for sx in [-1, 1]:
		var sh := Node3D.new(); sh.name = "Shoulder%d" % sx; sh.position = Vector3(0.17 * sx, 0.78, 0); root.add_child(sh)
		_cy(sh, "Arm", Vector3(0, -0.16, 0.02), 0.04, 0.045, 0.34, skin); _sp(sh, "Hand", Vector3(0, -0.34, 0.03), 0.05, skin)
		if sx < 0: _arm_l = sh
		else: _arm_r = sh
	_atk_pivot = _arm_r; _atk_rest = Vector3.ZERO
	# a bow held in the left hand
	_cy(_arm_l, "Bow", Vector3(0, -0.34, 0.1), 0.02, 0.02, 0.5, wood, Vector3(6, 0, 0))
	_bx(_arm_l, "String", Vector3(-0.05, -0.34, 0.1), Vector3(0.006, 0.46, 0.006), Color.html("dcdce0"))
	_sp(root, "Head", Vector3(0, 0.98, 0.02), 0.14, skin)
	_sp(root, "Hair", Vector3(0, 1.06, -0.02), 0.15, hair, Vector3(1.05, 0.8, 1.05))
	_sp(root, "EyeL", Vector3(-0.05, 0.99, 0.12), 0.02, Color.html("4a6a9a")); _sp(root, "EyeR", Vector3(0.05, 0.99, 0.12), 0.02, Color.html("4a6a9a"))
	# halo
	_cy(root, "Halo", Vector3(0, 1.2, -0.02), 0.1, 0.1, 0.015, gold)
	# small feathered wings swept up and back
	for sx in [-1, 1]:
		var w := Node3D.new(); w.name = "Wing%d" % sx; w.position = Vector3(0.12 * sx, 0.82, -0.12); w.rotation_degrees = Vector3(8, 24 * sx, 22 * sx); root.add_child(w)
		_spread_wing(w, sx, 0.42, 0.2, robe, robe2)


## Djinn: a blue genie with a wisp tail, bracelets, ponytail and a red necklace.
func _build_djinn() -> void:
	_shadow(0.26)
	var blue := Color.html("2f7fd0"); var blue2 := Color.html("4a9ae6"); var gold := Color.html("e8c34a"); var dark := Color.html("141018"); var red := Color.html("c0392b")
	var body := Node3D.new(); body.name = "Body"; body.position = Vector3(0, 0.2, 0); add_child(body); _bob_node = body; _bob_y = 0.2
	# muscular torso
	_bx(body, "Torso", Vector3(0, 0.62, 0), Vector3(0.46, 0.46, 0.28), blue)
	_sp(body, "Chest", Vector3(0, 0.66, 0.12), 0.2, blue2, Vector3(1.2, 0.9, 0.7))
	_bx(body, "Belt", Vector3(0, 0.42, 0), Vector3(0.4, 0.08, 0.26), gold)
	_cy(body, "Necklace", Vector3(0, 0.78, 0.12), 0.1, 0.1, 0.03, red)
	# wisp/smoke tail instead of legs
	_cy(body, "Wisp", Vector3(0, 0.1, 0), 0.22, 0.04, 0.5, blue2)
	for i in range(3): _sp(body, "Puff%d" % i, Vector3((i - 1) * 0.08, -0.14 - i * 0.04, 0), 0.08 - i * 0.015, blue)
	# big arms with bracelets
	for sx in [-1, 1]:
		var sh := Node3D.new(); sh.name = "Shoulder%d" % sx; sh.position = Vector3(0.26 * sx, 0.82, 0); body.add_child(sh)
		_cy(sh, "Arm", Vector3(0, -0.22, 0.02), 0.06, 0.07, 0.44, blue); _sp(sh, "Hand", Vector3(0, -0.46, 0.04), 0.08, blue2)
		_cy(sh, "Bracelet", Vector3(0, -0.4, 0.04), 0.08, 0.08, 0.05, gold)
		if sx < 0: _arm_l = sh
		else: _arm_r = sh
	_atk_pivot = _arm_r; _atk_rest = Vector3.ZERO
	_sp(body, "Head", Vector3(0, 1.04, 0.02), 0.15, blue2)
	_sp(body, "Topknot", Vector3(0, 1.18, -0.02), 0.05, dark)
	_cy(body, "Ponytail", Vector3(0, 1.12, -0.1), 0.0, 0.04, 0.18, dark, Vector3(40, 0, 0))
	_bx(body, "Beard", Vector3(0, 0.92, 0.12), Vector3(0.1, 0.1, 0.04), dark)
	_sp(body, "EyeL", Vector3(-0.05, 1.05, 0.12), 0.02, Color.html("ffffff"), Vector3.ONE, true); _sp(body, "EyeR", Vector3(0.05, 1.05, 0.12), 0.02, Color.html("ffffff"), Vector3.ONE, true)


## Corrupted Archangel: black-eyed, black-haired angel in white with a black greatsword.
func _build_corrupted_archangel() -> void:
	_shadow(0.3)
	var white := Color.html("eef0f2"); var white2 := Color.html("d6dade"); var skin := Color.html("d8c2ac"); var hair := Color.html("0e0c12"); var blade := Color.html("1a1820"); var gold := Color.html("c9a23a")
	var root := Node3D.new(); root.name = "Body"; add_child(root); _bob_node = root; _bob_y = 0.0
	_cy(root, "Robe", Vector3(0, 0.42, 0), 0.12, 0.3, 0.84, white)
	_bx(root, "Hem", Vector3(0, 0.04, 0), Vector3(0.46, 0.06, 0.46), white2)
	_bx(root, "Sash", Vector3(0, 0.62, 0.02), Vector3(0.4, 0.08, 0.3), gold, Vector3(0, 0, 20))
	for sx in [-1, 1]:
		var sh := Node3D.new(); sh.name = "Shoulder%d" % sx; sh.position = Vector3(0.2 * sx, 0.94, 0); root.add_child(sh)
		_cy(sh, "Arm", Vector3(0, -0.2, 0.02), 0.045, 0.05, 0.42, white); _sp(sh, "Hand", Vector3(0, -0.42, 0.03), 0.05, skin)
		if sx < 0: _arm_l = sh
		else: _arm_r = sh
	_atk_pivot = _arm_r; _atk_rest = Vector3.ZERO
	# huge black two-handed sword held down in front
	var sword := Node3D.new(); sword.position = Vector3(0.06, -0.4, 0.12); sword.rotation_degrees = Vector3(20, 0, 0); _arm_r.add_child(sword)
	_cy(sword, "Grip", Vector3(0, -0.1, 0), 0.022, 0.022, 0.22, Color.html("2a2620"))
	_bx(sword, "Guard", Vector3(0, 0.04, 0), Vector3(0.26, 0.04, 0.05), gold)
	_bx(sword, "Blade", Vector3(0, 0.6, 0), Vector3(0.1, 1.1, 0.03), blade)
	_sp(root, "Head", Vector3(0, 1.16, 0.02), 0.14, skin)
	_sp(root, "Hair", Vector3(0, 1.22, -0.03), 0.16, hair, Vector3(1.1, 1.1, 1.1))
	_bx(root, "HairL", Vector3(-0.13, 1.06, -0.02), Vector3(0.05, 0.34, 0.1), hair); _bx(root, "HairR", Vector3(0.13, 1.06, -0.02), Vector3(0.05, 0.34, 0.1), hair)
	_sp(root, "EyeL", Vector3(-0.05, 1.16, 0.12), 0.026, Color.html("050507"), Vector3.ONE, true); _sp(root, "EyeR", Vector3(0.05, 1.16, 0.12), 0.026, Color.html("050507"), Vector3.ONE, true)
	# Great feathered wings held wide — still angelic white, but the trailing
	# tip feathers have gone black where the corruption is creeping in.
	for sx in [-1, 1]:
		var w := Node3D.new(); w.name = "Wing%d" % sx; w.position = Vector3(0.14 * sx, 1.0, -0.14); w.rotation_degrees = Vector3(8, 10 * sx, 26 * sx); root.add_child(w)
		_spread_wing(w, sx, 0.78, 0.3, white, blade)
		_sp(w, "Covert2", Vector3(0.14 * sx, 0.03, -0.04), 0.09, white2, Vector3(1.4, 0.5, 1.1))


# =============================================================
# IDLE
# =============================================================

func _process(delta: float) -> void:
	if not _built or _busy or _bob_node == null:
		return
	_time += delta
	var freq := 5.0 if _walking else 2.0
	var amp := 0.02 if _walking else 0.012
	# Positive-only bob: the body breathes UP from its rest — a full sine dips
	# the feet through the floor half of every cycle.
	_bob_node.position.y = _bob_y + maxf(0.0, sin(_time * freq)) * amp
	# Step the feet while moving; ease them back to a planted stand otherwise.
	if _walking:
		_step_cycle()
	else:
		_settle_steps(delta)


## Advance every collected foot through one step of the walk cycle.
func _step_cycle() -> void:
	var phase := _time * ENEMY_STEP_FREQ
	for part in _step_parts:
		var node: Node3D = part["node"]
		if not is_instance_valid(node):
			continue
		var rest: Vector3 = part["rest"]
		var s := sin(phase + float(part["phase"]))
		node.position = Vector3(
			rest.x,
			rest.y + maxf(0.0, s) * ENEMY_STEP_LIFT * _step_amp,
			rest.z + s * ENEMY_STEP_STRIDE * _step_amp)


## Ease the feet back to their rest positions once the figure stops moving.
func _settle_steps(delta: float) -> void:
	if _step_parts.is_empty():
		return
	var t := clampf(delta * 12.0, 0.0, 1.0)
	for part in _step_parts:
		var node: Node3D = part["node"]
		if not is_instance_valid(node):
			continue
		node.position = node.position.lerp(part["rest"], t)


# =============================================================
# PUBLIC API (driven by enemy.gd)
# =============================================================

func play_action(action: String) -> void:
	if not _built:
		return
	var a := action.to_lower()
	# --- Locomotion / state (shared across every species) ---
	if a in ["move", "walk", "scurry", "hydra_move", "goblin_move", "scurry_away", "get_into_range", "flee", "hop"]:
		set_walking(true)
		return
	if a == "hit":
		play_hit()
		return
	if a in ["idle", "stance"]:
		set_walking(false)
		return
	# Heal actions (hydra_heal / treant_heal) have no bespoke animation — stay idle
	# rather than falling through to an attack. (sear_wounds is handled per-kind.)
	if a.contains("heal"):
		set_walking(false)
		return

	# --- Attacks: route to a species-specific animation. Kinds with more than one
	# attack disambiguate on the action name; the rest share play_attack(). ---
	match _kind:
		"armored_troll":
			if a == "kick": _troll_kick()
			else: _arm_swing()                       # smash / club
		"giant_beaver":
			if a == "tail_whip": _beaver_tail_whip()
			else: _beaver_chomp()
		"hydra":
			_hydra_attack()                          # all three heads
		"archer_rat":
			_archer_shoot()
		"fire_goblin_mage":
			_goblin_ember()
		"fire_goblin_shaman":
			if a == "sear_wounds": _shaman_sear()
			elif a == "fire_wall": _shaman_fire_wall()
			else: _arm_swing()
		"large_bear":
			_bear_maul()
		"wolf":
			_wolf_lunge()
		"infected_hunter":
			if a == "cleave": _hunter_cleave()
			else: _hunter_hook()
		"giant_hawk":
			_hawk_swoop()
		"treant":
			if a == "root": _treant_root()
			else: _treant_slam()
		"ice_mage": _cast_projectile("icicle")
		"fire_mage": _cast_projectile("fireball")
		"spark_mage": _cast_projectile("spark")
		"air_mage": _cast_projectile("tornado")
		"earth_mage": _cast_projectile("boulder")
		"fire_goblin_soldier":
			_arm_swing()
		# --- Graveyard act ---
		"zombie": _zombie_attack()
		"werewolf": _werewolf_attack()
		"wererabbit":
			if a == "vanish": _rabbit_vanish()
			else: _lurch()
		"vampire": _vampire_attack()
		"necromancer":
			if a.contains("summon"): _necro_summon()
			else: _necro_cast()
		"bone_dragon":
			if a.contains("breath"): _dragon_breath()
			else: _dragon_bite()
		"spirit_collector":
			if a.contains("collect"): _collector_collect()
			else: _collector_swing()
		"grave_titan":
			if a.contains("roll"): _titan_roll()
			else: _titan_smash()
		"crypt_crawler":
			if a == "web": _crawler_web()
			else: _crawler_bite()
		"screecher": _screech_attack()
		# --- Sewer act ---
		"sludge":
			if a.contains("spit"): _sludge_spit()
			else: _lurch()
		"pipe_crawler": _pipe_attack()
		"sewer_croc": _croc_bite()
		"rat_king": _lurch()
		"swarm": _lurch()
		# --- Mountains / Underworld / Heavens act ---
		"cherub": _cherub_shoot()      # an archer looses an arrow, never a punch
		"ash_harpy": _hawk_swoop()     # dives on its prey like the other raptors
		_:
			play_attack()


func set_walking(walking: bool) -> void:
	if walking == _walking:
		return
	_walking = walking
	if _kind == "archer_rat":
		_set_archer_pose(walking)
	elif _kind == "giant_beaver":
		_set_beaver_pose(walking)


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
		"rat", "archer_rat", "wolf", "coyote", "mini_bear", "giant_beaver", "giant_hawk", \
		"sabertooth", "white_manticore", "wyvern", "roc", "magma_spider", "cerberus", \
		"snow_wraith", "specter":  # spirits surge at you rather than shoulder-swing
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


## Hydra: lunge the body forward while ALL THREE heads snap out to bite together.
func _hydra_attack() -> void:
	if _bob_node == null:
		return
	_cancel_action()
	_busy = true
	var base := _bob_node.position
	_action_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_action_tween.tween_property(_bob_node, "position:z", base.z + 0.2, 0.1)
	for i in range(_hydra_necks.size()):
		var neck: Node3D = _hydra_necks[i]
		if not is_instance_valid(neck):
			continue
		var rest: Vector3 = _hydra_neck_rest[i]
		# Side heads pitch a touch harder so the strike fans out.
		var lunge := 30.0 if i == 0 else 38.0
		_action_tween.parallel().tween_property(neck, "rotation_degrees:x", rest.x + lunge, 0.1)
	_action_tween.tween_property(_bob_node, "position:z", base.z, 0.3)
	for i in range(_hydra_necks.size()):
		var neck: Node3D = _hydra_necks[i]
		if not is_instance_valid(neck):
			continue
		_action_tween.parallel().tween_property(neck, "rotation_degrees:x", _hydra_neck_rest[i].x, 0.3)
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


# =============================================================
# SPECIES-SPECIFIC ATTACKS
# =============================================================

## Spawn a small mesh that flies forward (local +Z is the way the figure faces),
## optionally dropping/spinning as it goes, then frees itself. `builder` fills the
## projectile node with meshes. Used for arrows, bolts, boulders, hooks, etc.
func _projectile(builder: Callable, start: Vector3, dist: float, dur: float, drop := 0.0, spin := Vector3.ZERO) -> void:
	var p := Node3D.new()
	add_child(p)
	p.position = start
	builder.call(p)
	var tw := create_tween()
	tw.tween_property(p, "position", start + Vector3(0, -drop, dist), dur).set_trans(Tween.TRANS_LINEAR)
	if spin != Vector3.ZERO:
		tw.parallel().tween_property(p, "rotation_degrees", spin, dur)
	tw.tween_callback(p.queue_free)


## Armored Troll: snap the right leg forward in a kick.
func _troll_kick() -> void:
	if _troll_leg == null:
		_arm_swing()
		return
	_cancel_action()
	_busy = true
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_action_tween.tween_property(_troll_leg, "rotation_degrees:x", -70.0, 0.12).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_troll_leg, "rotation_degrees:x", 0.0, 0.22).set_ease(Tween.EASE_IN)
	_action_tween.tween_callback(func(): _busy = false)


## Giant Beaver: quick forward chomp lunge.
func _beaver_chomp() -> void:
	_lurch()


## Giant Beaver: spin 180° so the tail faces the target, then slam it down to spank.
func _beaver_tail_whip() -> void:
	if _beaver_tail == null:
		_lurch()
		return
	_cancel_action()
	_busy = true
	var face := rotation_degrees.y
	var rest := _beaver_tail.rotation_degrees
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_action_tween.tween_property(self, "rotation_degrees:y", face + 180.0, 0.18)
	_action_tween.tween_property(_beaver_tail, "rotation_degrees:x", rest.x - 110.0, 0.12).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_beaver_tail, "rotation_degrees:x", rest.x, 0.1).set_ease(Tween.EASE_IN)
	_action_tween.tween_property(self, "rotation_degrees:y", face, 0.18)
	_action_tween.tween_callback(func(): _busy = false)


func _set_beaver_pose(walking: bool) -> void:
	if _beaver_pose == null:
		return
	if _pose_tween and _pose_tween.is_valid():
		_pose_tween.kill()
	_pose_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_pose_tween.tween_property(_beaver_pose, "rotation_degrees:x", 46.0 if walking else 0.0, 0.25)
	_pose_tween.parallel().tween_property(_beaver_pose, "position:y", -0.3 if walking else 0.0, 0.25)


## Archer Rat: blink + jab forward (the lurch) while loosing an arrow.
func _archer_shoot() -> void:
	_lurch()
	var wood := Color.html("6b4a2a")
	var tip := Color.html("c8ccd6")
	_projectile(func(p):
		_cy(p, "Shaft", Vector3.ZERO, 0.01, 0.012, 0.28, wood, Vector3(90, 0, 0))
		_cy(p, "Tip", Vector3(0, 0, 0.16), 0.0, 0.02, 0.06, tip, Vector3(90, 0, 0))
	, Vector3(0, 0.55, 0.45), 2.8, 0.42)


## Cherub: recoil with the bow arm while loosing a gold-fletched arrow.
func _cherub_shoot() -> void:
	if _arm_l != null:
		_cancel_action()
		_busy = true
		_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
		_action_tween.tween_property(_arm_l, "rotation_degrees:x", -78.0, 0.12).set_ease(Tween.EASE_OUT)
		_action_tween.tween_property(_arm_l, "rotation_degrees:x", 0.0, 0.24).set_ease(Tween.EASE_IN_OUT)
		_action_tween.tween_callback(func(): _busy = false)
	else:
		_lurch()
	var wood := Color.html("8a6a3a")
	var gold := Color.html("e8c34a")
	_projectile(func(p):
		_cy(p, "Shaft", Vector3.ZERO, 0.01, 0.012, 0.3, wood, Vector3(90, 0, 0))
		_cy(p, "Tip", Vector3(0, 0, 0.17), 0.0, 0.02, 0.06, gold, Vector3(90, 0, 0))
		_pr(p, "Fletch", Vector3(0, 0.02, -0.13), Vector3(0.04, 0.06, 0.01), gold)
	, Vector3(0, 0.75, 0.35), 2.8, 0.4)


## Fire Goblin Mage: cast gesture flinging a spray of small embers.
func _goblin_ember() -> void:
	_arm_swing()
	var c := Color.html("ff7a1a")
	for i in range(3):
		var off := Vector3((i - 1) * 0.09, 0.5 + (i % 2) * 0.06, 0.42)
		_projectile(func(p):
			_sp(p, "Ember", Vector3.ZERO, 0.04, c, Vector3.ONE, true)
		, off, 2.2, 0.5, -0.15)


## Fire Goblin Shaman: small fires bloom under the allies, then a heart rises over
## each survivor for the heal.
func _shaman_sear() -> void:
	_arm_swing()
	for x in [-0.3, 0.3]:
		_spawn_ground_fire(Vector3(x, 0.0, 0.6))
		_spawn_heart(Vector3(x, 0.55, 0.6))


## Fire Goblin Shaman: raise a wide wall of fire in front.
func _shaman_fire_wall() -> void:
	_arm_swing()
	var p := Node3D.new()
	add_child(p)
	p.position = Vector3(0, 0.0, 0.95)
	var orange := Color.html("ff7a1a")
	var yellow := Color.html("ffd23f")
	for i in range(7):
		var c: Color = orange if i % 2 == 0 else yellow
		var flame := _bx(p, "Flame%d" % i, Vector3((i - 3) * 0.2, 0.05, 0), Vector3(0.18, 0.06, 0.1), c)
		var sm := flame.material_override as StandardMaterial3D
		sm.emission_enabled = true
		sm.emission = c
		sm.emission_energy_multiplier = 1.4
	p.scale.y = 0.1
	var tw := create_tween().set_trans(Tween.TRANS_QUAD)
	tw.tween_property(p, "scale:y", 9.0, 0.25)
	tw.tween_interval(0.7)
	tw.tween_property(p, "scale:y", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


## Large Bear: rake with both claws, swinging the arms alternately.
func _bear_maul() -> void:
	if _bear_arm_l == null or _bear_arm_r == null:
		_arm_swing()
		return
	_cancel_action()
	_busy = true
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_action_tween.tween_property(_bear_arm_r, "rotation_degrees:x", -120.0, 0.12)
	_action_tween.parallel().tween_property(_bear_arm_l, "rotation_degrees:x", -20.0, 0.12)
	_action_tween.tween_property(_bear_arm_l, "rotation_degrees:x", -120.0, 0.12)
	_action_tween.parallel().tween_property(_bear_arm_r, "rotation_degrees:x", -25.0, 0.12)
	_action_tween.tween_property(_bear_arm_r, "rotation_degrees:x", -110.0, 0.1)
	_action_tween.parallel().tween_property(_bear_arm_l, "rotation_degrees:x", 0.0, 0.12)
	_action_tween.tween_property(_bear_arm_r, "rotation_degrees:x", 0.0, 0.16)
	_action_tween.tween_callback(func(): _busy = false)


## Wolf: rear up to ~45° on its hind legs and lunge forward at the target.
func _wolf_lunge() -> void:
	if _bob_node == null:
		return
	_cancel_action()
	_busy = true
	var base := _bob_node.position
	_action_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_action_tween.tween_property(_bob_node, "rotation_degrees:x", -45.0, 0.14)
	_action_tween.parallel().tween_property(_bob_node, "position:z", base.z + 0.3, 0.18)
	_action_tween.tween_property(_bob_node, "rotation_degrees:x", 0.0, 0.2)
	_action_tween.parallel().tween_property(_bob_node, "position:z", base.z, 0.2)
	_action_tween.tween_callback(func(): _busy = false)


## Infected Hunter: fling a grappling hook on a rope the hunter keeps hold of, then
## reel it (and the snagged target) back in. The rope stretches from his hand to the
## flying hook the whole time.
func _hunter_hook() -> void:
	_arm_swing()
	var steel := Color.html("9aa0a8")
	var rope_c := Color.html("6b5a3a")
	var anchor := Vector3(0, 0.5, 0.42)   # the hunter's hand
	var reach := 2.6

	var hook := Node3D.new()
	add_child(hook)
	hook.position = anchor
	_cy(hook, "Shaft", Vector3(0, 0, 0.05), 0.015, 0.02, 0.14, steel, Vector3(90, 0, 0))
	_cy(hook, "BarbR", Vector3(0.04, 0, 0.12), 0.0, 0.016, 0.09, steel, Vector3(0, 0, 60))
	_cy(hook, "BarbL", Vector3(-0.04, 0, 0.12), 0.0, 0.016, 0.09, steel, Vector3(0, 0, -60))

	# Rope: a unit-length cylinder we stretch/position between the hand and the hook.
	var rope := _cy(self, "Rope", anchor, 0.008, 0.008, 1.0, rope_c, Vector3(90, 0, 0))

	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_action_tween.tween_method(_update_hook.bind(hook, rope, anchor), 0.0, reach, 0.3).set_ease(Tween.EASE_OUT)
	_action_tween.tween_interval(0.1)  # hooked
	_action_tween.tween_method(_update_hook.bind(hook, rope, anchor), reach, 0.0, 0.3).set_ease(Tween.EASE_IN)
	_action_tween.tween_callback(hook.queue_free)
	_action_tween.tween_callback(rope.queue_free)


func _update_hook(d: float, hook: Node3D, rope: Node3D, anchor: Vector3) -> void:
	if is_instance_valid(hook):
		hook.position = anchor + Vector3(0, 0, d)
	if is_instance_valid(rope):
		rope.position = anchor + Vector3(0, 0, d * 0.5)
		rope.scale.y = maxf(d, 0.01)  # base height is 1.0, so scale.y == length


## Infected Hunter: a wide 180° horizontal cleave across its front.
func _hunter_cleave() -> void:
	if _atk_pivot == null:
		_arm_swing()
		return
	_cancel_action()
	_busy = true
	var rest := _atk_rest
	_atk_pivot.rotation_degrees = Vector3(rest.x - 80.0, rest.y + 90.0, rest.z)
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_action_tween.tween_property(_atk_pivot, "rotation_degrees:y", rest.y - 90.0, 0.2).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_atk_pivot, "rotation_degrees", rest, 0.18)
	_action_tween.tween_callback(func(): _busy = false)


## Giant Hawk: pull up, then dive down and forward onto the target before climbing back.
func _hawk_swoop() -> void:
	if _bob_node == null:
		return
	_cancel_action()
	_busy = true
	var base := _bob_node.position
	_action_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_action_tween.tween_property(_bob_node, "position", base + Vector3(0, 0.3, -0.15), 0.16)
	_action_tween.tween_property(_bob_node, "position", base + Vector3(0, -0.45, 0.55), 0.14).set_ease(Tween.EASE_IN)
	_action_tween.tween_property(_bob_node, "position", base, 0.32)
	_action_tween.tween_callback(func(): _busy = false)


## Treant: rear back with both arms overhead, then bend at the trunk and smash both
## arms down onto the ground in front.
func _treant_slam() -> void:
	if _treant_arm_l == null or _treant_arm_r == null or _bob_node == null:
		_arm_swing()
		return
	_cancel_action()
	_busy = true
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	# Rear back, leaning slightly while raising both arms overhead.
	_action_tween.tween_property(_treant_arm_r, "rotation_degrees:x", 165.0, 0.22)
	_action_tween.parallel().tween_property(_treant_arm_l, "rotation_degrees:x", 165.0, 0.22)
	_action_tween.parallel().tween_property(_bob_node, "rotation_degrees:x", -14.0, 0.22)
	# Bend forward hard at the trunk and slam both arms to the ground.
	_action_tween.tween_property(_bob_node, "rotation_degrees:x", 46.0, 0.13).set_ease(Tween.EASE_IN)
	_action_tween.parallel().tween_property(_treant_arm_r, "rotation_degrees:x", -10.0, 0.13)
	_action_tween.parallel().tween_property(_treant_arm_l, "rotation_degrees:x", -10.0, 0.13)
	# Straighten back upright.
	_action_tween.tween_property(_bob_node, "rotation_degrees:x", 0.0, 0.32)
	_action_tween.parallel().tween_property(_treant_arm_r, "rotation_degrees:x", 0.0, 0.32)
	_action_tween.parallel().tween_property(_treant_arm_l, "rotation_degrees:x", 0.0, 0.32)
	_action_tween.tween_callback(func(): _busy = false)


## Treant: raise both arms skyward to summon, while roots erupt from the ground.
func _treant_root() -> void:
	if _treant_arm_l == null or _treant_arm_r == null:
		_arm_swing()
		return
	_cancel_action()
	_busy = true
	_action_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_action_tween.tween_property(_treant_arm_r, "rotation_degrees:x", 150.0, 0.22)
	_action_tween.parallel().tween_property(_treant_arm_l, "rotation_degrees:x", 150.0, 0.22)
	_action_tween.tween_interval(0.4)
	_action_tween.tween_property(_treant_arm_r, "rotation_degrees:x", 0.0, 0.3)
	_action_tween.parallel().tween_property(_treant_arm_l, "rotation_degrees:x", 0.0, 0.3)
	_action_tween.tween_callback(func(): _busy = false)
	_spawn_roots()


## Elemental mages: cast gesture that hurls a themed projectile at the target.
func _cast_projectile(kind: String) -> void:
	_arm_swing()
	match kind:
		"icicle":
			var pale := Color.html("bfe6ff")
			_projectile(func(p):
				_cy(p, "Ice", Vector3.ZERO, 0.0, 0.05, 0.3, pale, Vector3(90, 0, 0))
			, Vector3(0, 0.5, 0.4), 2.6, 0.4)
		"fireball":
			var c := Color.html("ff7a1a")
			_projectile(func(p):
				_sp(p, "Fire", Vector3.ZERO, 0.09, c, Vector3.ONE, true)
				_sp(p, "Core", Vector3.ZERO, 0.05, Color.html("ffe08a"), Vector3.ONE, true)
			, Vector3(0, 0.5, 0.4), 2.6, 0.5)
		"spark":
			var y := Color.html("fff07a")
			_projectile(func(p):
				var b := _bx(p, "Bolt", Vector3.ZERO, Vector3(0.03, 0.03, 0.34), y)
				var sm := b.material_override as StandardMaterial3D
				sm.emission_enabled = true
				sm.emission = y
			, Vector3(0, 0.55, 0.4), 3.2, 0.28, 0.0, Vector3(0, 0, 720))
		"tornado":
			var w := Color.html("d6fff0")
			_projectile(func(p):
				_cy(p, "Funnel", Vector3.ZERO, 0.13, 0.03, 0.42, w)
			, Vector3(0, 0.4, 0.4), 2.4, 0.6, 0.0, Vector3(0, 1440, 0))
		"boulder":
			var rock := Color.html("8a6b3f")
			_projectile(func(p):
				_sp(p, "Rock", Vector3.ZERO, 0.13, rock)
			, Vector3(0, 0.7, 0.4), 2.6, 0.55, 0.3, Vector3(360, 0, 360))


func _spawn_ground_fire(pos: Vector3) -> void:
	var p := Node3D.new()
	add_child(p)
	p.position = pos
	var orange := Color.html("ff7a1a")
	var yellow := Color.html("ffd23f")
	for i in range(4):
		var c: Color = orange if i % 2 == 0 else yellow
		var f := _bx(p, "F%d" % i, Vector3((i - 1.5) * 0.05, 0.06, 0), Vector3(0.05, 0.14, 0.05), c)
		var sm := f.material_override as StandardMaterial3D
		sm.emission_enabled = true
		sm.emission = c
	p.scale.y = 0.2
	var tw := create_tween()
	tw.tween_property(p, "scale:y", 1.0, 0.2)
	tw.tween_interval(0.5)
	tw.tween_property(p, "scale:y", 0.0, 0.25)
	tw.tween_callback(p.queue_free)


func _spawn_heart(pos: Vector3) -> void:
	var p := Node3D.new()
	add_child(p)
	p.position = pos
	var red := Color.html("ff5a7a")
	_sp(p, "LobeL", Vector3(-0.04, 0.02, 0), 0.05, red, Vector3.ONE, true)
	_sp(p, "LobeR", Vector3(0.04, 0.02, 0), 0.05, red, Vector3.ONE, true)
	_bx(p, "Base", Vector3(0, -0.03, 0), Vector3(0.1, 0.1, 0.05), red).rotation_degrees = Vector3(0, 0, 45)
	# Delay so the heal reads as "after the sear", then float up.
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(p, "position:y", pos.y + 0.4, 0.5)
	tw.tween_callback(p.queue_free)


func _spawn_roots() -> void:
	var p := Node3D.new()
	add_child(p)
	p.position = Vector3(0, 0, 0.8)
	var bark := Color.html("4a3a26")
	for i in range(5):
		_cy(p, "Root%d" % i, Vector3((i - 2) * 0.16, 0, 0), 0.0, 0.04, 0.32, bark, Vector3(8.0 * (i - 2), 0, 0))
	p.scale.y = 0.05
	var tw := create_tween()
	tw.tween_property(p, "scale:y", 1.0, 0.3)
	tw.tween_interval(0.5)
	tw.tween_property(p, "scale:y", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


# ---- Graveyard act attacks ----

## Zombie: shamble forward, thrusting both outstretched arms.
func _zombie_attack() -> void:
	if _arm_l == null or _arm_r == null:
		_arm_swing()
		return
	_cancel_action()
	_busy = true
	var base := _bob_node.position
	var rl := _arm_l.rotation_degrees.x
	var rr := _arm_r.rotation_degrees.x
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_action_tween.tween_property(_bob_node, "position:z", base.z + 0.2, 0.12)
	_action_tween.parallel().tween_property(_arm_l, "rotation_degrees:x", rl - 28.0, 0.12)
	_action_tween.parallel().tween_property(_arm_r, "rotation_degrees:x", rr - 28.0, 0.12)
	_action_tween.tween_property(_bob_node, "position:z", base.z, 0.26)
	_action_tween.parallel().tween_property(_arm_l, "rotation_degrees:x", rl, 0.26)
	_action_tween.parallel().tween_property(_arm_r, "rotation_degrees:x", rr, 0.26)
	_action_tween.tween_callback(func(): _busy = false)


## Werewolf: raise both long arms and rake their claws down across the target.
func _werewolf_attack() -> void:
	if _arm_l == null or _arm_r == null:
		_arm_swing()
		return
	_cancel_action()
	_busy = true
	var rl := _arm_l.rotation_degrees.x
	var rr := _arm_r.rotation_degrees.x
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_action_tween.tween_property(_arm_r, "rotation_degrees:x", rr - 90.0, 0.12)
	_action_tween.parallel().tween_property(_arm_l, "rotation_degrees:x", rl - 90.0, 0.12)
	_action_tween.tween_property(_arm_r, "rotation_degrees:x", rr + 50.0, 0.1).set_ease(Tween.EASE_IN)
	_action_tween.parallel().tween_property(_arm_l, "rotation_degrees:x", rl + 50.0, 0.1)
	_action_tween.tween_property(_arm_r, "rotation_degrees:x", rr, 0.2)
	_action_tween.parallel().tween_property(_arm_l, "rotation_degrees:x", rl, 0.2)
	_action_tween.tween_callback(func(): _busy = false)


## Vampire: lunge into a bite, then a life-steal heart floats up.
func _vampire_attack() -> void:
	_lurch()
	_spawn_heart(Vector3(0, 1.2, 0.08))


## Necromancer: raise the staff and loose a dark bolt.
func _necro_cast() -> void:
	_arm_swing()
	var dark := Color.html("8a5cff")
	_projectile(func(p):
		_sp(p, "Bolt", Vector3.ZERO, 0.07, dark, Vector3.ONE, true)
		_sp(p, "Core", Vector3.ZERO, 0.035, Color.html("d8c2ff"), Vector3.ONE, true)
	, Vector3(0.26, 1.0, 0.2), 2.8, 0.45)


## Necromancer: raise the staff while summoning motes rise from the ground.
func _necro_summon() -> void:
	_arm_swing()
	_spawn_motes(Vector3(0, 0, 0.7), Color.html("8a5cff"), 6)


## Bone Dragon: snap the skull forward in a bite.
func _dragon_bite() -> void:
	if _head_pivot == null:
		_arm_swing()
		return
	_cancel_action()
	_busy = true
	var rest := _atk_rest
	var base := _bob_node.position
	_action_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_action_tween.tween_property(_bob_node, "position:z", base.z + 0.15, 0.1)
	_action_tween.parallel().tween_property(_head_pivot, "rotation_degrees:x", rest.x + 45.0, 0.1)
	_action_tween.tween_property(_bob_node, "position:z", base.z, 0.28)
	_action_tween.parallel().tween_property(_head_pivot, "rotation_degrees:x", rest.x, 0.28)
	_action_tween.tween_callback(func(): _busy = false)


## Bone Dragon: dip the head and exhale a widening cone of darkness forward.
func _dragon_breath() -> void:
	if _head_pivot:
		_cancel_action()
		_busy = true
		var rest := _atk_rest
		_action_tween = create_tween()
		_action_tween.tween_property(_head_pivot, "rotation_degrees:x", rest.x + 18.0, 0.15)
		_action_tween.tween_property(_head_pivot, "rotation_degrees:x", rest.x, 0.45)
		_action_tween.tween_callback(func(): _busy = false)
	# Cone widening away from the maw (narrow at the mouth, broad far out).
	var cone := Node3D.new()
	add_child(cone)
	cone.position = Vector3(0, 1.3, 0.85)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.5      # wide end (forward)
	cm.bottom_radius = 0.04  # narrow end (at the mouth)
	cm.height = 1.5
	cm.radial_segments = 14
	mi.mesh = cm
	mi.rotation_degrees = Vector3(90, 0, 0)  # axis -> +Z (the dragon faces +Z)
	mi.position = Vector3(0, 0, 0.75)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.05, 0.09, 0.82)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.16, 0.09, 0.26)
	mat.emission_energy_multiplier = 0.6
	mi.material_override = mat
	cone.add_child(mi)
	cone.scale = Vector3(0.3, 0.3, 0.3)
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(cone, "scale", Vector3(1, 1, 1), 0.22)
	tw.tween_interval(0.25)
	tw.tween_property(cone, "scale", Vector3(1.1, 1.1, 0.0), 0.3)
	tw.tween_callback(cone.queue_free)


## Spirit Collector: swing the lantern arm.
func _collector_swing() -> void:
	_arm_swing()


## Spirit Collector: raise the lantern as a soul wisp is drawn up.
func _collector_collect() -> void:
	_arm_swing()
	_spawn_motes(Vector3(0.3, 0.6, 0.4), Color.html("bfe6ff"), 4)


## Grave Titan: hoist the boulder overhead, then slam it down onto the enemy in
## front (it leaves the shoulder), and return it to the shoulder afterwards.
func _titan_smash() -> void:
	if _titan_boulder == null or _arm_l == null or _arm_r == null or _bob_node == null:
		_arm_swing()
		return
	_cancel_action()
	_busy = true
	var home := _titan_boulder.position
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	# Hoist the boulder overhead with both arms.
	_action_tween.tween_property(_arm_r, "rotation_degrees:x", 150.0, 0.2)
	_action_tween.parallel().tween_property(_arm_l, "rotation_degrees:x", 150.0, 0.2)
	_action_tween.parallel().tween_property(_titan_boulder, "position", Vector3(0, 2.05, 0.15), 0.2)
	# Slam it straight down onto the enemy in front (boulder leaves the shoulder).
	_action_tween.tween_property(_titan_boulder, "position", Vector3(0, 0.32, 1.0), 0.12).set_ease(Tween.EASE_IN)
	_action_tween.parallel().tween_property(_arm_r, "rotation_degrees:x", 35.0, 0.12)
	_action_tween.parallel().tween_property(_arm_l, "rotation_degrees:x", 35.0, 0.12)
	_action_tween.tween_interval(0.1)  # impact hold
	# Heave it back up onto the shoulder.
	_action_tween.tween_property(_titan_boulder, "position", home, 0.3)
	_action_tween.parallel().tween_property(_arm_r, "rotation_degrees:x", 0.0, 0.3)
	_action_tween.parallel().tween_property(_arm_l, "rotation_degrees:x", 0.0, 0.3)
	_action_tween.tween_callback(func(): _busy = false)


## Grave Titan: take the boulder off its shoulder and roll it at the target.
func _titan_roll() -> void:
	if _titan_boulder == null:
		_arm_swing()
		return
	_cancel_action()
	_busy = true
	var home := _titan_boulder.position
	_action_tween = create_tween().set_trans(Tween.TRANS_SINE)
	# Bring it down to the ground...
	_action_tween.tween_property(_titan_boulder, "position", Vector3(0, 0.25, 0.5), 0.18)
	if _arm_r: _action_tween.parallel().tween_property(_arm_r, "rotation_degrees:x", -40.0, 0.18)
	# ...roll it forward, spinning...
	_action_tween.tween_property(_titan_boulder, "position", Vector3(0, 0.22, 2.6), 0.4)
	_action_tween.parallel().tween_property(_titan_boulder, "rotation_degrees", Vector3(720, 0, 0), 0.4)
	# ...then a fresh boulder is back on the shoulder.
	_action_tween.tween_property(_titan_boulder, "position", home, 0.001)
	_action_tween.parallel().tween_property(_titan_boulder, "rotation_degrees", Vector3.ZERO, 0.001)
	if _arm_r: _action_tween.tween_property(_arm_r, "rotation_degrees:x", 0.0, 0.2)
	_action_tween.tween_callback(func(): _busy = false)


## Crypt Crawler: lunge forward to bite.
func _crawler_bite() -> void:
	_lurch()


## Crypt Crawler: spray a sticky web blob forward.
func _crawler_web() -> void:
	_lurch()
	var web := Color.html("e8e8ee")
	_projectile(func(p):
		_sp(p, "Web", Vector3.ZERO, 0.1, web)
		for a in range(4):
			_cy(p, "Strand%d" % a, Vector3.ZERO, 0.004, 0.004, 0.24, web, Vector3(0, 0, a * 45.0))
	, Vector3(0, 0.35, 0.3), 2.4, 0.45)


## Sludge Being: recoil and spit a globule of ooze forward.
func _sludge_spit() -> void:
	_lurch()
	var ooze := Color.html("57c074")
	_projectile(func(p):
		_sp(p, "Glob", Vector3.ZERO, 0.08, ooze, Vector3.ONE, true)
	, Vector3(0, 0.3, 0.35), 2.6, 0.5, -0.1)


## Pipe Crawler: lunge forward while swiping both back-limbs.
func _pipe_attack() -> void:
	if _bob_node == null:
		return
	_cancel_action()
	_busy = true
	var base := _bob_node.position
	var rl := _arm_l.rotation_degrees.x if _arm_l else 0.0
	var rr := _arm_r.rotation_degrees.x if _arm_r else 0.0
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_action_tween.tween_property(_bob_node, "position:z", base.z + 0.18, 0.1)
	if _arm_l: _action_tween.parallel().tween_property(_arm_l, "rotation_degrees:x", rl + 55.0, 0.1)
	if _arm_r: _action_tween.parallel().tween_property(_arm_r, "rotation_degrees:x", rr + 55.0, 0.1)
	_action_tween.tween_property(_bob_node, "position:z", base.z, 0.22)
	if _arm_l: _action_tween.parallel().tween_property(_arm_l, "rotation_degrees:x", rl, 0.22)
	if _arm_r: _action_tween.parallel().tween_property(_arm_r, "rotation_degrees:x", rr, 0.22)
	_action_tween.tween_callback(func(): _busy = false)


## Sewer Crocodile: lunge forward, gaping the jaw, then snap it shut.
func _croc_bite() -> void:
	if _atk_pivot == null or _bob_node == null:
		_lurch()
		return
	_cancel_action()
	_busy = true
	var base := _bob_node.position
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD)
	_action_tween.tween_property(_atk_pivot, "rotation_degrees:x", 35.0, 0.12)
	_action_tween.parallel().tween_property(_bob_node, "position:z", base.z + 0.2, 0.12)
	_action_tween.tween_property(_atk_pivot, "rotation_degrees:x", 0.0, 0.08).set_ease(Tween.EASE_IN)
	_action_tween.tween_property(_bob_node, "position:z", base.z, 0.2)
	_action_tween.tween_callback(func(): _busy = false)


## Screecher: surge forward with a swelling shriek (and briefly flash into view).
func _screech_attack() -> void:
	if _bob_node == null:
		return
	_cancel_action()
	_busy = true
	var base := _bob_node.position
	var s := _bob_node.scale
	_action_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_action_tween.tween_property(_bob_node, "position:z", base.z + 0.2, 0.1)
	_action_tween.parallel().tween_property(_bob_node, "scale", s * 1.15, 0.1)
	_action_tween.tween_property(_bob_node, "position:z", base.z, 0.3)
	_action_tween.parallel().tween_property(_bob_node, "scale", s, 0.3)
	_action_tween.tween_callback(func(): _busy = false)


## Wererabbit: vanish in a puff of smoke (then re-appear so it can be replayed).
func _rabbit_vanish() -> void:
	var p := Node3D.new()
	add_child(p)
	p.position = Vector3(0, 0.3, 0)
	for i in range(6):
		var ang := deg_to_rad(i * 60.0)
		_sp(p, "Smoke%d" % i, Vector3(cos(ang) * 0.1, 0.1, sin(ang) * 0.1), 0.1, Color.html("9a9aa2"))
	p.scale = Vector3(0.4, 0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(p, "scale", Vector3(1.6, 1.6, 1.6), 0.4)
	tw.tween_callback(p.queue_free)
	if _bob_node:
		var s := _bob_node.scale
		var tw2 := create_tween()
		tw2.tween_property(_bob_node, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
		tw2.tween_interval(0.3)
		tw2.tween_property(_bob_node, "scale", s, 0.2)


## Small ring of glowing motes that rise and fade (summons / soul collection).
func _spawn_motes(pos: Vector3, color: Color, count: int) -> void:
	var p := Node3D.new()
	add_child(p)
	p.position = pos
	for i in range(count):
		var ang := deg_to_rad(i * (360.0 / count))
		_sp(p, "Mote%d" % i, Vector3(cos(ang) * 0.14, 0, sin(ang) * 0.14), 0.035, color, Vector3.ONE, true)
	var tw := create_tween()
	tw.tween_property(p, "position", pos + Vector3(0, 0.6, 0), 0.6)
	tw.tween_callback(p.queue_free)


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
