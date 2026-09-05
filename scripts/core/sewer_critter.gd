class_name SewerCritter
extends Node3D

## A tiny background critter — a sewer mouse, a forest squirrel, a meadow
## butterfly, or a crow — that moves between random points near its spawn.
## Purely atmospheric: no collision, no health, the player never interacts
## with it. It just makes a level feel alive. Butterflies fly (they bob at
## flower height and flap between two frames); ground kinds scuttle; crows
## hop a short way, then stand and peck at the ground (two frames).

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

func _build() -> void:
	# Tiny pixel billboard (contact shadow painted into the sprite).
	var tex_path := "res://assets/textures/props/critter_mouse.png"
	match _kind:
		"squirrel":
			tex_path = "res://assets/textures/props/critter_squirrel.png"
		"butterfly":
			tex_path = "res://assets/textures/props/butterfly.png"
		"crow":
			tex_path = "res://assets/textures/props/critter_crow.png"
	_body = Sprite3D.new()
	_body.texture = load(tex_path)
	if _kind == "butterfly" or _kind == "crow":
		_body.hframes = 2
	_body.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_body.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_body.shaded = false
	_body.pixel_size = 0.034
	# Feet pivot (billboards rotate about their origin — keep it on the
	# ground line so the critter never sinks under the pitched camera).
	_body.centered = false
	var fw := float(_body.texture.get_width()) / maxf(1.0, float(_body.hframes))
	_body.offset = Vector2(-fw * 0.5, 0.0)  # bottom edge on the origin
	_body.position.y = _rest_y()
	add_child(_body)

func _rest_y() -> float:
	if _kind == "butterfly":
		return 0.55  # flower height, not the ground
	return 0.0

func _pick_target() -> void:
	var a = _rng.randf() * TAU
	var r = _rng.randf() * _roam
	_target = _home + Vector3(cos(a) * r, 0.0, sin(a) * r)
	# Crows spend most of their time standing and pecking between hops.
	_pause = _rng.randf_range(1.5, 4.0) if _kind == "crow" else _rng.randf_range(0.2, 1.5)

func _process(delta: float) -> void:
	if _kind == "butterfly" and _body:
		# Butterflies flap even while hovering on a flower.
		_bob_t += delta
		_body.frame = int(_bob_t * 8.0) % 2
	if _pause > 0.0:
		_pause -= delta
		if _kind == "crow" and _body:
			# Peck: head down for a beat every second or so while paused.
			_bob_t += delta
			_body.frame = 1 if fmod(_bob_t, 1.1) < 0.35 else 0
			_body.position.y = _rest_y()
		return
	if _kind == "crow" and _body:
		_body.frame = 0
	var to = _target - position
	to.y = 0.0
	var d = to.length()
	if d < 0.12:
		_pick_target()
		return
	var dir = to / d
	position += dir * _speed * delta
	# Billboard sprite: face the walk direction by mirroring, not rotating.
	if _body and absf(dir.x) > 0.05:
		_body.flip_h = dir.x < 0.0
	if _body:
		if _kind == "butterfly":
			# Wandering flight height instead of a ground bob.
			_body.position.y = _rest_y() + sin(_bob_t * 2.6) * 0.14
		elif _kind == "crow":
			# Hop: a whole-pixel bounce, never below the ground line.
			_bob_t += delta * 11.0
			_body.position.y = _rest_y() + floorf(absf(sin(_bob_t)) * 2.0) * 0.034
		else:
			# Subtle scurry bob (only advances while moving).
			_bob_t += delta * 18.0
			_body.position.y = _rest_y() + absf(sin(_bob_t)) * 0.02
