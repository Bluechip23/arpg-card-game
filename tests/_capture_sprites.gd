extends SceneTree

## Dev helper: render the sprite viewer demo performing one animation to a PNG.
##   ... --script tests/_capture_sprites.gd -- <out.png> <anim> <dir> <seconds>
## anim: idle | walk | attack_sword | attack_axe
## dir:  south | north | east | west

const DIRS := {"south": 0, "north": 1, "east": 2, "west": 3}

var _out := "/tmp/sprites.png"
var _anim := "idle"
var _dir := "south"
var _grab := 0.2
var _viewer: Node2D = null
var _settle := 0.0
var _t := -1.0
var _done := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_anim = args[1]
	if args.size() > 2:
		_dir = args[2]
	if args.size() > 3:
		_grab = float(args[3])
	_viewer = (load("res://scenes/demo/character_viewer.tscn") as PackedScene).instantiate()
	get_root().add_child(_viewer)


func _process(d: float) -> bool:
	if _done:
		return true
	_settle += d
	if _settle >= 0.1 and _t < 0.0:
		_t = 0.0
		for c in _viewer.characters:
			c.set_facing(DIRS[_dir])
			c.play(_anim)
		return false
	if _t >= 0.0:
		_t += d
		if _t >= _grab:
			get_root().get_texture().get_image().save_png(_out)
			print("[capture] %s  (%s %s @ %.2fs)" % [_out, _anim, _dir, _grab])
			_done = true
			quit()
	return false
