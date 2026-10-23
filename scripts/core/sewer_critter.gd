class_name SewerCritter
extends Node3D

## A tiny background critter — a sewer mouse, a forest squirrel, a meadow
## butterfly, or a crow — that moves between random points near its spawn.
## Purely atmospheric: no collision, no health, the player never interacts
## with it. It just makes a level feel alive. The mouse is the giant-rat
## pack's Rat1 shrunk to mouse size (its four-way run cycle); the crow is the
## mountain-monster pack's black Bird, flitting low on its flight cycle.
## Butterflies flutter at flower height; the squirrel scuttles. (No pack
## draws a squirrel or a butterfly: those two keep their own small sprites.)

var _home: Vector3
var _target: Vector3
var _speed: float = 1.7
var _roam: float = 3.5
var _pause: float = 0.0
var _rng := RandomNumberGenerator.new()
var _bob_t: float = 0.0
var _body: Sprite3D
var _kind: String = "mouse"

func setup(home: Vector3, seed_val: int, kind: String = "mouse") -> void:
	_home = home
	position = home
	_target = home
	_kind = kind
	_rng.seed = seed_val
	_phase_offset()
	_build()
	_pick_target()

func _phase_offset() -> void:
	# Stagger critters so they don't all move in lockstep.
	_bob_t = _rng.randf() * TAU
	if _kind == "butterfly":
		_speed = _rng.randf_range(0.7, 1.2)
		_roam = _rng.randf_range(2.0, 3.5)
	elif _kind == "crow":
		_speed = _rng.randf_range(1.0, 1.6)
		_roam = _rng.randf_range(1.5, 3.0)
	else:
		_speed = _rng.randf_range(1.3, 2.2)
		_roam = _rng.randf_range(2.5, 4.5)

const RAT_RUN := "res://assets/sprites/craftpix/giant_rat/Rat1/With_shadow/Rat1_Run_with_shadow.png"
const RAT_IDLE := "res://assets/sprites/craftpix/giant_rat/Rat1/With_shadow/Rat1_Idle_with_shadow.png"
const RAT_CELL := 128     # sheet cell; rows front/back/left/right, 6 frames each
const RAT_GROUND := 76    # texel row (from the cell top) of the rat's shadow foot
const RAT_SCALE := 0.28   # a giant rat shrunk to a mouse
const BIRD_DIR := "res://assets/sprites/craftpix/mountain_monsters/Bird/Flight%d.png"
const BIRD_FRAMES := 6
const BIRD_GROUND := 80   # texel row of the bird's feet in its 128px frame
const BIRD_SCALE := 0.42  # the pack's hawk-sized bird down to a crow
const SQUIRREL_TEX := "res://assets/textures/props/critter_squirrel.png"
const BUTTERFLY_TEX := "res://assets/textures/props/butterfly.png"

var _rat_run: Texture2D
var _rat_idle: Texture2D
var _rat_row: int = 3
var _bird_frames: Array = []
var _anim_t: float = 0.0

func _build() -> void:
	_body = Sprite3D.new()
	_body.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_body.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD  # writes depth: per-pixel sorting
	_body.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_body.shaded = false
	_body.pixel_size = 0.03125
	# Feet pivot (billboards rotate about their origin — keep it on the
	# ground line so the critter never sinks under the pitched camera).
	_body.centered = false
	match _kind:
		"mouse":
			_rat_run = load(RAT_RUN)
			_rat_idle = load(RAT_IDLE)
			_body.texture = _rat_idle
			_body.region_enabled = true
			_body.region_rect = Rect2(0, _rat_row * RAT_CELL, RAT_CELL, RAT_CELL)
			_body.offset = Vector2(-RAT_CELL * 0.5, -(RAT_CELL - RAT_GROUND))
			_body.scale = Vector3.ONE * RAT_SCALE
		"crow":
			for f in range(1, BIRD_FRAMES + 1):
				_bird_frames.append(load(BIRD_DIR % f))
			_body.texture = _bird_frames[0]
			var bw := float(_body.texture.get_width())
			_body.offset = Vector2(-bw * 0.5, -(float(_body.texture.get_height()) - BIRD_GROUND))
			_body.scale = Vector3.ONE * BIRD_SCALE
		_:
			# Squirrel / butterfly: small sprites of our own (no pack piece).
			_body.texture = load(SQUIRREL_TEX if _kind == "squirrel" else BUTTERFLY_TEX)
			if _kind == "butterfly":
				_body.hframes = 2
			var fw := float(_body.texture.get_width()) / maxf(1.0, float(_body.hframes))
			_body.offset = Vector2(-fw * 0.5, 0.0)  # bottom edge on the origin
	_body.position.y = _rest_y()
	add_child(_body)

func _rest_y() -> float:
	if _kind == "butterfly":
		return 0.55  # flower height, not the ground
	if _kind == "crow":
		return 0.3  # flitting just above the ground
	return CameraView.SPRITE_LIFT  # above wall slabs (plan view depth)

func _pick_target() -> void:
	var a = _rng.randf() * TAU
	var r = _rng.randf() * _roam
	_target = _home + Vector3(cos(a) * r, 0.0, sin(a) * r)
	# Crows hang about a spot between short flights.
	_pause = _rng.randf_range(0.8, 2.0) if _kind == "crow" else _rng.randf_range(0.2, 1.5)

## The mouse's run cycle (moving) or idle cycle (paused), on the sheet row
## for its heading: 0 front (toward the camera), 1 back, 2 left, 3 right.
func _animate_rat(delta: float, moving: bool) -> void:
	_anim_t += delta * (12.0 if moving else 6.0)
	_body.texture = _rat_run if moving else _rat_idle
	var col := int(_anim_t) % 6
	_body.region_rect = Rect2(col * RAT_CELL, _rat_row * RAT_CELL, RAT_CELL, RAT_CELL)

func _process(delta: float) -> void:
	if _body == null:
		return
	if _kind == "butterfly":
		# Butterflies flap even while hovering on a flower.
		_bob_t += delta
		_body.frame = int(_bob_t * 8.0) % 2
	elif _kind == "crow":
		# Wings beat the whole time: it never lands.
		_anim_t += delta * 10.0
		_body.texture = _bird_frames[int(_anim_t) % _bird_frames.size()]
	if _pause > 0.0:
		_pause -= delta
		if _kind == "mouse":
			_animate_rat(delta, false)
		elif _kind == "crow":
			_bob_t += delta * 3.0
			_body.position.y = _rest_y() + sin(_bob_t) * 0.06
		return
	var to = _target - position
	to.y = 0.0
	var d = to.length()
	if d < 0.12:
		_pick_target()
		return
	var dir = to / d
	position += dir * _speed * delta
	if _kind == "mouse":
		if absf(dir.x) >= absf(dir.z):
			_rat_row = 3 if dir.x > 0.0 else 2
		else:
			_rat_row = 0 if dir.z > 0.0 else 1
		_animate_rat(delta, true)
	elif absf(dir.x) > 0.05:
		# Billboard sprite: face the walk direction by mirroring, not rotating
		# (the pack bird and our squirrel/butterfly face right).
		_body.flip_h = dir.x < 0.0
	if _kind == "butterfly":
		# Wandering flight height instead of a ground bob.
		_body.position.y = _rest_y() + sin(_bob_t * 2.6) * 0.14
	elif _kind == "crow":
		_bob_t += delta * 3.0
		_body.position.y = _rest_y() + sin(_bob_t) * 0.06
	elif _kind == "squirrel":
		# Subtle scurry bob (only advances while moving).
		_bob_t += delta * 18.0
		_body.position.y = _rest_y() + absf(sin(_bob_t)) * 0.02
