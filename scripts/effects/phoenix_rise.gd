class_name PhoenixRise
extends Sprite3D

## Gift from the Phoenix: the designer's phoenix (tools/cut_phoenix.py) rises
## over the player's head when the card fires. An ember kindles above the
## head and climbs, the bird bursts out of it and beats its wings through
## its four poses (twice), then fades. Parented to the player so it follows
## them; frees itself when done.
##
## Under the plan-view camera "above the head" on screen is north of the
## feet (-Z), the way the enemies' head-up bars are placed.

const STRIP := "res://assets/sprites/generated/fx/phoenix_strip.png"
const FRAMES := 5
const HEAD := 1.0            # the player figure stands about one tile tall
const EMBER_TIME := 0.35     # the ember kindles and climbs
const WING_TIME := 0.11      # per wing pose
const WING_LOOPS := 2
const FADE_TIME := 0.35

var _frame_h_units := 0.0


## Play the rise over `who` (a Node3D standing on the field).
static func play(who: Node3D) -> PhoenixRise:
	if who == null or not who.is_inside_tree():
		return null
	var fx := PhoenixRise.new()
	who.add_child(fx)
	fx._start()
	return fx


func _start() -> void:
	name = "PhoenixRise"
	process_mode = Node.PROCESS_MODE_ALWAYS  # plays out even if the game pauses as it fires
	texture = load(STRIP)
	hframes = FRAMES
	frame = 0
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED  # alpha blend, so it can fade
	shaded = false
	no_depth_test = true                         # always over the scene it rises from
	render_priority = 10
	pixel_size = CameraView.PIXEL_SIZE
	_frame_h_units = float(texture.get_height()) * pixel_size
	# The bird's bottom edge sits just above the head; the ember starts at the head.
	var top := -(HEAD + 0.15 + _frame_h_units * 0.5)
	position = Vector3(0, CameraView.SPRITE_LIFT + 0.2, -HEAD * 0.6)
	modulate = Color(1.3, 1.1, 0.8, 1.0)
	var tw := create_tween()
	# Ember: climbs from the head to where the bird will be.
	tw.tween_property(self, "position:z", top, EMBER_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# The phoenix: four wing poses, beaten WING_LOOPS times.
	for _loop in range(WING_LOOPS):
		for f in range(1, FRAMES):
			tw.tween_callback(func(): frame = f)
			tw.tween_interval(WING_TIME)
	tw.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(queue_free)
