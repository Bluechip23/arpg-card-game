class_name CloudShadows
extends Node3D

## Slow cloud shadows drifting across outdoor ground — the SNES-era daylight
## cue (FF6 / Secret of Mana overworlds). Each shadow is a flat quad lying on
## the ground carrying a hard-edged, checker-dithered blob texture (two alpha
## steps, no gradient — style guide §7). Purely cosmetic; quads wrap around
## the map bounds so a fixed handful covers any world size.

const TEX_PATH := "res://assets/textures/props/cloud_shadow.png"
const PIXEL_SIZE := 0.034
const DRIFT_SPEED := 0.55  # world units / second — slow, stately drift

var _bounds_w: float = 70.0
var _bounds_h: float = 46.0
var _margin: float = 12.0
var _clouds: Array = []  # [{node, vel: Vector3}]

func setup(grid_w: int, grid_h: int, seed_val: int) -> void:
	_bounds_w = float(grid_w)
	_bounds_h = float(grid_h)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var tex: Texture2D = load(TEX_PATH)
	var count := clampi(int(_bounds_w * _bounds_h) / 700, 3, 8)
	# One shared wind direction (south-easterly, like the painted upper-left
	# light casting clouds away), with per-cloud speed variation.
	var wind := Vector3(0.78, 0.0, 0.52).normalized()
	for i in range(count):
		var quad := QuadMesh.new()
		var s := rng.randf_range(2.6, 4.4)
		quad.size = Vector2(tex.get_width() * PIXEL_SIZE * s, tex.get_height() * PIXEL_SIZE * s)
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = false
		mi.material_override = mat
		mi.rotation_degrees = Vector3(-90, rng.randf_range(0, 360), 0)
		mi.position = Vector3(
			rng.randf_range(-_margin, _bounds_w + _margin),
			0.035,  # above the floor slab tops, below every prop and shadow blob
			rng.randf_range(-_margin, _bounds_h + _margin)
		)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_clouds.append({"node": mi, "vel": wind * DRIFT_SPEED * rng.randf_range(0.7, 1.3)})

func _process(delta: float) -> void:
	for c in _clouds:
		var mi: MeshInstance3D = c["node"]
		mi.position += c["vel"] * delta
		# Wrap around the map (with margin) so the sky never runs out of clouds.
		if mi.position.x > _bounds_w + _margin:
			mi.position.x = -_margin
			mi.position.z = fposmod(mi.position.z * 1.7 + 11.0, _bounds_h + _margin)
		if mi.position.z > _bounds_h + _margin:
			mi.position.z = -_margin
			mi.position.x = fposmod(mi.position.x * 1.3 + 7.0, _bounds_w + _margin)
