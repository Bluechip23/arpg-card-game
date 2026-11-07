extends Node3D

## The level-up pillar (the designer's board, 2026-11-07,
## assets/sprites/paintings/level_up_board.png cut to a 9-frame strip): a
## column of golden light rises round the hero who levelled, a spiral of
## light winds up it, and it sinks again. A child of that hero, so it rides
## along if they move; drawn just behind the hero's own sprite so the light
## wraps them without hiding them. Plays once and frees itself.

const STRIP := "res://assets/sprites/generated/fx/level_up_strip.png"
const FRAMES := 9
const FRAME_H := 236        # px, the strip's height (see the cut)
const PIXEL := 0.0085       # world units a pixel: the pillar stands ~2 tiles tall, its ring ~2 wide
const FPS := 10.0

var _sprite: Sprite3D = null
var _t: float = 0.0

## Raise the pillar round `hero` (any Node3D standing in the world).
static func play(hero: Node3D) -> Node3D:
	if hero == null or not is_instance_valid(hero) or not hero.is_inside_tree():
		return null
	var fx: Node3D = (load("res://scripts/effects/level_up_fx.gd") as GDScript).new()
	fx.name = "LevelUpFX"
	hero.add_child(fx)
	return fx

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # plays out under a pause (Olorin's lesson opens on top)
	_sprite = Sprite3D.new()
	_sprite.texture = load(STRIP)
	_sprite.hframes = FRAMES
	_sprite.frame = 0
	_sprite.pixel_size = PIXEL
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED   # blended light
	_sprite.shaded = false
	# Its ring at the hero's feet: the strip's bottom edge on the ground.
	_sprite.offset = Vector2(0, FRAME_H * 0.5)
	_sprite.position = Vector3(0, CameraView.SPRITE_LIFT - 0.05, 0)
	# Sorted as if a little further from the camera than the hero, so the
	# hero's sprite draws over the light.
	_sprite.sorting_offset = -0.6
	_sprite.modulate = Color(1, 1, 1, 0.92)
	add_child(_sprite)

func _process(delta: float) -> void:
	_t += delta
	var f := int(_t * FPS)
	if f >= FRAMES:
		queue_free()
		return
	_sprite.frame = f
