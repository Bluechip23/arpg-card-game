class_name TorchFlicker
extends OmniLight3D

## A wall-torch light that flickers organically. Purely cosmetic: layered sines
## wander the light energy around its base value so sewer torches feel alive and
## throw a restless glow on the wet brick and water.

var _base_energy: float = 2.2
var _t: float = 0.0
var _phase: float = 0.0

func _ready() -> void:
	_base_energy = light_energy
	_phase = randf() * TAU

func _process(delta: float) -> void:
	_t += delta
	var f = sin(_t * 11.0 + _phase) * 0.11 + sin(_t * 23.0 + _phase * 1.7) * 0.06
	light_energy = max(0.0, _base_energy * (1.0 + f))
