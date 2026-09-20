class_name SheetAnimSprite
extends Sprite3D

## A Sprite3D that loops through its hframes × vframes sheet at `fps`.
## Used for the pack's animated set pieces (the glowing-cave totem that
## marks waypoints). Set hframes/vframes/texture as usual, then fps.

@export var fps: float = 8.0
var _acc: float = 0.0


func _process(delta: float) -> void:
	if fps <= 0.0 or texture == null:
		return
	var total := hframes * vframes
	if total <= 1:
		return
	_acc += delta * fps
	if _acc >= 1.0:
		frame = (frame + int(_acc)) % total
		_acc -= floorf(_acc)
