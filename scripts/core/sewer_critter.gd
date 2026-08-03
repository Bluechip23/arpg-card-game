class_name SewerCritter
extends Node3D

## A tiny background critter — a sewer mouse or a forest squirrel — that scuttles
## between random points near its spawn. Purely atmospheric: no collision, no
## health, the player never interacts with it. It just makes a level feel alive.

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
	_speed = _rng.randf_range(1.3, 2.2)
	_roam = _rng.randf_range(2.5, 4.5)

func _build() -> void:
	# Tiny pixel billboard (contact shadow painted into the sprite).
	var is_squirrel = _kind == "squirrel"
	var tex_path = "res://assets/textures/props/critter_squirrel.png" if is_squirrel \
			else "res://assets/textures/props/critter_mouse.png"
	_body = Sprite3D.new()
	_body.texture = load(tex_path)
	_body.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_body.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_body.shaded = false
	_body.pixel_size = 0.034
	_body.position.y = _body.texture.get_height() * 0.034 * 0.5
	add_child(_body)

func _pick_target() -> void:
	var a = _rng.randf() * TAU
	var r = _rng.randf() * _roam
	_target = _home + Vector3(cos(a) * r, 0.0, sin(a) * r)
	_pause = _rng.randf_range(0.2, 1.5)

func _process(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		return
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
	# Subtle scurry bob.
	_bob_t += delta * 18.0
	if _body:
		var rest_y = _body.texture.get_height() * 0.034 * 0.5
		_body.position.y = rest_y + absf(sin(_bob_t)) * 0.02
