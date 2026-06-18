class_name CharacterFigure
extends Node3D

## A simple procedural 3D character built from primitive meshes.
##
## Replaces the old Secret-of-Mana sprite-sheet system with a chunky, pre-rendered
## "SNES RPG" look (think Super Mario RPG): a big-headed chibi figure assembled from
## boxes and spheres, lit and shaded in 3D. The same figure is used both on the
## character-selection cards (inside a SubViewport) and as the in-battle player.
##
## Animations are procedural (driven by Tweens on the joint nodes) rather than
## frame-based, which keeps the rig open for future spell / attack / defense moves:
## just add a new `play_*` method and route it through `play_action()`.
##
## Node layout (built in _build):
##   CharacterFigure (self)
##     Pivot              - yaw rotation for facing a target
##       Shadow           - flat contact shadow on the ground (does not bob)
##       Body             - idle bob + combat lean live here
##         Legs / Feet / Torso / Head / Hair / Eyes
##         LeftShoulder  -> LeftArm    (pivots at the shoulder joint)
##         RightShoulder -> RightArm   (the "attacking" arm)
##       ShieldAnchor     - where the defend shield icon pops up (above the head)

# Joint nodes (populated in _build)
var _pivot: Node3D = null
var _body: Node3D = null
var _left_shoulder: Node3D = null
var _right_shoulder: Node3D = null
var _left_leg: Node3D = null
var _right_leg: Node3D = null
var _shield_anchor: Node3D = null

var _char_name: String = "Default"
var _built: bool = false
var _busy: bool = false          # True while a one-shot action animation is playing
var _walking: bool = false
var _time: float = 0.0
var _action_tween: Tween = null

# Resting (idle) shoulder pose, so actions always return cleanly to neutral
const REST := Vector3.ZERO


func _ready() -> void:
	_build()


func setup(character_name: String) -> void:
	## Sets which colour palette to use. Safe to call before or after the figure
	## has been built (it re-applies once geometry exists).
	_char_name = character_name
	if _built:
		_apply_palette()


# =============================================================
# BUILD
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

	# Legs (named so a future walk cycle can swing them from the hip)
	_left_leg = _make_limb("LeftLeg", Vector3(-0.11, 0.42, 0), Vector3(0.15, 0.42, 0.15), "pants")
	_right_leg = _make_limb("RightLeg", Vector3(0.11, 0.42, 0), Vector3(0.15, 0.42, 0.15), "pants")
	_body.add_child(_left_leg)
	_body.add_child(_right_leg)

	# Feet
	_body.add_child(_make_box("LeftFoot", Vector3(-0.11, 0.05, 0.04), Vector3(0.17, 0.1, 0.22), "accent"))
	_body.add_child(_make_box("RightFoot", Vector3(0.11, 0.05, 0.04), Vector3(0.17, 0.1, 0.22), "accent"))

	# Torso
	_body.add_child(_make_box("Torso", Vector3(0, 0.66, 0), Vector3(0.42, 0.46, 0.26), "shirt"))

	# Head
	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.2
	head_mesh.height = 0.4
	head.mesh = head_mesh
	head.position = Vector3(0, 1.06, 0)
	head.set_meta("palette_role", "skin")
	_body.add_child(head)

	# Hair / cap (a flattened sphere over the top of the head)
	var hair := MeshInstance3D.new()
	hair.name = "Hair"
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.205
	hair_mesh.height = 0.41
	hair.mesh = hair_mesh
	hair.position = Vector3(0, 1.12, 0)
	hair.scale = Vector3(1.02, 0.62, 1.02)
	hair.set_meta("palette_role", "hair")
	_body.add_child(hair)

	# Eyes (small dark dots on the front of the face, +Z)
	_body.add_child(_make_eye("EyeL", Vector3(-0.07, 1.07, 0.185)))
	_body.add_child(_make_eye("EyeR", Vector3(0.07, 1.07, 0.185)))

	# Shoulders + arms. Arm meshes hang 0.2 below the shoulder joint so the
	# joint sits at the shoulder and rotating it swings the whole arm.
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

	# Anchor for the defend shield icon (above the head)
	_shield_anchor = Node3D.new()
	_shield_anchor.name = "ShieldAnchor"
	_shield_anchor.position = Vector3(0, 1.5, 0)
	_pivot.add_child(_shield_anchor)

	_built = true
	_apply_palette()


func _make_limb(node_name: String, pos: Vector3, size: Vector3, role: String) -> MeshInstance3D:
	# A limb is just a box; kept as its own helper so legs/arms read clearly.
	return _make_box(node_name, pos, size, role)


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
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.07, 0.1)
	mi.material_override = mat
	return mi


# =============================================================
# PALETTE
# =============================================================

func _apply_palette() -> void:
	var pal := _palette_for(_char_name)
	_paint(_body, pal)


func _paint(node: Node, pal: Dictionary) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.has_meta("palette_role"):
			var role: String = child.get_meta("palette_role")
			if pal.has(role):
				var mat := StandardMaterial3D.new()
				mat.albedo_color = pal[role]
				# A touch of specular gives the plastic / pre-rendered RPG sheen
				mat.metallic = 0.0
				mat.roughness = 0.6
				child.material_override = mat
		_paint(child, pal)


func _palette_for(character_name: String) -> Dictionary:
	match character_name:
		"Ryan":  # Shadow blade — dark leathers, crimson accent
			return {"skin": Color(0.90, 0.74, 0.60), "hair": Color(0.12, 0.12, 0.14),
					"shirt": Color(0.16, 0.17, 0.20), "pants": Color(0.10, 0.10, 0.12),
					"accent": Color(0.70, 0.20, 0.20)}
		"Jeremy":  # Mage — blue robe, violet accent
			return {"skin": Color(0.95, 0.80, 0.65), "hair": Color(0.30, 0.22, 0.40),
					"shirt": Color(0.24, 0.30, 0.62), "pants": Color(0.18, 0.20, 0.42),
					"accent": Color(0.62, 0.50, 0.92)}
		"Stephen":  # Warrior — crimson, gold accent
			return {"skin": Color(0.95, 0.76, 0.60), "hair": Color(0.50, 0.30, 0.15),
					"shirt": Color(0.62, 0.18, 0.18), "pants": Color(0.32, 0.12, 0.12),
					"accent": Color(0.90, 0.72, 0.32)}
		"Cory":  # Druid — greens
			return {"skin": Color(0.90, 0.78, 0.62), "hair": Color(0.30, 0.35, 0.20),
					"shirt": Color(0.22, 0.46, 0.26), "pants": Color(0.18, 0.30, 0.18),
					"accent": Color(0.52, 0.70, 0.36)}
		"Brad":  # Tank — steel blue
			return {"skin": Color(0.92, 0.76, 0.60), "hair": Color(0.40, 0.35, 0.30),
					"shirt": Color(0.30, 0.40, 0.55), "pants": Color(0.25, 0.30, 0.40),
					"accent": Color(0.62, 0.66, 0.76)}
		_:
			return {"skin": Color(0.95, 0.78, 0.62), "hair": Color(0.35, 0.25, 0.18),
					"shirt": Color(0.40, 0.45, 0.55), "pants": Color(0.25, 0.28, 0.35),
					"accent": Color(0.60, 0.60, 0.65)}


# =============================================================
# IDLE (per-frame)
# =============================================================

func _process(delta: float) -> void:
	if not _built or _busy:
		return
	_time += delta
	# Gentle breathing bob + a hint of sway so the figure feels alive.
	var freq := 4.0 if _walking else 1.6
	var amp := 0.035 if _walking else 0.02
	_body.position.y = sin(_time * freq) * amp
	_body.rotation_degrees.z = sin(_time * 1.3) * (2.5 if _walking else 1.0)


# =============================================================
# PUBLIC ANIMATION API
# =============================================================

## Generic entry point. `direction` uses CharacterAnimator.Direction values so the
## battle code (main.gd) can keep passing the same enum it always has.
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
			# Extension point: future spell / cast / channel actions land here.
			# Until they have their own animation they simply settle into idle.
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
	# Wind-up: arm raises up-and-forward, body leans back
	_action_tween.tween_property(_right_shoulder, "rotation_degrees:x", -150.0, 0.14).set_ease(Tween.EASE_OUT)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", -9.0, 0.14)
	# Strike: arm whips down-and-forward (fast), body snaps forward
	_action_tween.tween_property(_right_shoulder, "rotation_degrees:x", -40.0, 0.07).set_ease(Tween.EASE_IN)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 12.0, 0.07)
	# Recover to neutral
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
	# Bring the fist across to the chest
	_action_tween.tween_property(_right_shoulder, "rotation_degrees", Vector3(-95, 0, 38), 0.12).set_ease(Tween.EASE_OUT)
	_action_tween.parallel().tween_property(_body, "rotation_degrees:x", 6.0, 0.12)
	# Two chest pounds (pull back a little, drive back in)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees:x", -76.0, 0.08)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees:x", -95.0, 0.07)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees:x", -76.0, 0.08)
	_action_tween.tween_property(_right_shoulder, "rotation_degrees:x", -95.0, 0.07)
	# Drop the arm back to neutral
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
	# Pop in with a little overshoot
	tw.tween_property(shield, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Hold briefly
	tw.tween_interval(0.35)
	# Drift up and slowly fade away
	tw.tween_property(shield, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(shield, "position:y", 0.25, 1.0)
	tw.tween_callback(shield.queue_free)


func _make_shield_texture() -> ImageTexture:
	# Draws a classic "heater" shield silhouette: flat top, straight sides that
	# taper to a point at the bottom. Grey fill with a darker rim and a centre rib.
	var w := 48
	var h := 56
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var fill := Color(0.64, 0.66, 0.72)
	var rim := Color(0.30, 0.32, 0.38)
	var rib := Color(0.50, 0.52, 0.58)

	for y in range(h):
		var t := float(y) / float(h - 1)          # 0 = top, 1 = bottom point
		# Half-width of the shield at this height, in [0,1]: flat top, then the
		# sides curve in to a point at the bottom (a classic heraldic escutcheon).
		var hw := 1.0
		if t > 0.45:
			var k := (t - 0.45) / 0.55
			hw = 1.0 - k * k
		hw = clamp(hw, 0.0, 1.0)
		for x in range(w):
			var u := (float(x) / float(w - 1)) * 2.0 - 1.0   # -1 .. 1
			var au := absf(u)
			if au > hw:
				continue
			var col := fill
			# Rim near the outer edge
			if au > hw - 0.16 or t > 0.9:
				col = rim
			# Centre rib
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
