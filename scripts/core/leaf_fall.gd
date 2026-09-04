class_name LeafFall
extends Node3D

## A slow shower of leaves shed from the canopy near a treeline tree. A few
## pixel-leaf billboards (two flutter frames) drift down on a sine sway,
## rest on the ground a moment, then respawn up in the canopy. Discrete
## frame flips at SNES cadence — no particles, no alpha fades.

const TEX_PATH := "res://assets/textures/props/leaf.png"
const PIXEL_SIZE := 0.034
const CANOPY_Y := 2.1
const FALL_SPEED := 0.45
const FLUTTER_FPS := 5.0

var _rng := RandomNumberGenerator.new()
var _leaves: Array = []  # [{node: Sprite3D, sway_t, sway_amp, rest: float}]
var _frame_t: float = 0.0

func setup(home: Vector3, seed_val: int) -> void:
	position = home
	_rng.seed = seed_val
	var count := _rng.randi_range(2, 4)
	for i in range(count):
		var s := Sprite3D.new()
		s.texture = load(TEX_PATH)
		s.hframes = 2
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.shaded = false
		s.pixel_size = PIXEL_SIZE
		add_child(s)
		var leaf := {
			"node": s,
			"sway_t": _rng.randf() * TAU,
			"sway_amp": _rng.randf_range(0.15, 0.35),
			"rest": 0.0,
			"base_x": _rng.randf_range(-0.8, 0.8),
			"base_z": _rng.randf_range(-0.8, 0.8),
		}
		_respawn(leaf, true)
		_leaves.append(leaf)

func _respawn(leaf: Dictionary, initial: bool = false) -> void:
	var s: Sprite3D = leaf["node"]
	# Start anywhere along the fall on the very first frame so the shower is
	# already mid-air when the player walks up.
	var y := _rng.randf_range(0.3, CANOPY_Y) if initial else CANOPY_Y
	s.position = Vector3(leaf["base_x"], y, leaf["base_z"])
	leaf["rest"] = 0.0

func _process(delta: float) -> void:
	_frame_t += delta
	var frame := int(_frame_t * FLUTTER_FPS)
	for leaf in _leaves:
		var s: Sprite3D = leaf["node"]
		if leaf["rest"] > 0.0:
			leaf["rest"] -= delta
			if leaf["rest"] <= 0.0:
				_respawn(leaf)
			continue
		leaf["sway_t"] += delta * 2.2
		s.position.y -= FALL_SPEED * delta
		s.position.x = leaf["base_x"] + sin(leaf["sway_t"]) * leaf["sway_amp"]
		s.frame = (frame + int(leaf["sway_t"])) % 2
		if s.position.y <= 0.05:
			s.position.y = 0.05
			leaf["rest"] = _rng.randf_range(1.2, 3.0)
