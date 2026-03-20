class_name CharacterAnimator
extends Node

## Handles sprite-sheet-based character animations in 3D space.
## Drives a Sprite3D node by setting texture regions per frame.

signal animation_finished(anim_name: String)
signal animation_started(anim_name: String)

enum Direction { SOUTH, NORTH, EAST, WEST }

# Animation definition: {name -> {row, frames, fps, loop, directions}}
# Populated by load_animation_data()
var animations: Dictionary = {}

var sprite: Sprite3D = null
var current_animation: String = "stance"
var current_direction: Direction = Direction.SOUTH
var current_frame: int = 0
var frame_timer: float = 0.0
var is_playing: bool = false
var sprite_sheet_loaded: bool = false

# Sprite sheet configuration
var frame_width: int = 48
var frame_height: int = 48
var sheet_columns: int = 0  # Auto-calculated from texture width
var sheet_texture: Texture2D = null


func initialize(sprite_node: Sprite3D, animation_data: Dictionary, sheet_path: String, fw: int = 48, fh: int = 48) -> void:
	sprite = sprite_node
	animations = animation_data
	frame_width = fw
	frame_height = fh

	if ResourceLoader.exists(sheet_path):
		sheet_texture = load(sheet_path)
		sprite.texture = sheet_texture
		sprite.region_enabled = true
		sheet_columns = int(sheet_texture.get_width() / frame_width)
		sprite_sheet_loaded = true
		play("stance")
	else:
		push_warning("[CharacterAnimator] Sprite sheet not found: %s — using fallback" % sheet_path)
		sprite_sheet_loaded = false


func _process(delta: float) -> void:
	if not is_playing or not sprite_sheet_loaded:
		return

	var anim = animations.get(current_animation)
	if not anim:
		return

	var fps: float = anim.get("fps", 8.0)
	frame_timer += delta
	if frame_timer >= 1.0 / fps:
		frame_timer -= 1.0 / fps
		current_frame += 1

		var total_frames: int = anim.get("frames", 1)
		if current_frame >= total_frames:
			if anim.get("loop", false):
				current_frame = 0
			else:
				current_frame = total_frames - 1
				is_playing = false
				animation_finished.emit(current_animation)
				return

		_update_region()


func play(anim_name: String, direction: Direction = current_direction, force_restart: bool = false) -> void:
	if not animations.has(anim_name):
		push_warning("[CharacterAnimator] Unknown animation: %s" % anim_name)
		return

	if anim_name == current_animation and direction == current_direction and not force_restart:
		if is_playing:
			return

	current_animation = anim_name
	current_direction = direction
	current_frame = 0
	frame_timer = 0.0
	is_playing = true

	# Flip sprite for WEST direction (mirror EAST)
	if sprite and sprite_sheet_loaded:
		sprite.flip_h = (direction == Direction.WEST)

	_update_region()
	animation_started.emit(anim_name)


func stop() -> void:
	is_playing = false


func set_direction_from_velocity(vel: Vector3) -> void:
	if vel.length_squared() < 0.01:
		return
	# Determine dominant direction
	if abs(vel.x) > abs(vel.z):
		current_direction = Direction.EAST if vel.x > 0 else Direction.WEST
	else:
		current_direction = Direction.SOUTH if vel.z > 0 else Direction.NORTH

	if sprite:
		sprite.flip_h = (current_direction == Direction.WEST)


func _update_region() -> void:
	if not sprite or not sprite_sheet_loaded:
		return

	var anim = animations.get(current_animation)
	if not anim:
		return

	# Each animation stores its starting pixel position and frame size
	var start_x: int = anim.get("start_x", 0)
	var start_y: int = anim.get("start_y", 0)
	var fw: int = anim.get("frame_width", frame_width)
	var fh: int = anim.get("frame_height", frame_height)

	# Direction offset: each direction is on a separate row within the animation block
	var dir_row: int = _get_direction_row()
	var dir_offset_y: int = dir_row * fh

	var region_x: int = start_x + current_frame * fw
	var region_y: int = start_y + dir_offset_y

	sprite.region_rect = Rect2(region_x, region_y, fw, fh)


func _get_direction_row() -> int:
	# Secret of Mana uses 3 directions: south(0), east/west(1), north(2)
	# West is just east flipped horizontally
	match current_direction:
		Direction.SOUTH:
			return 0
		Direction.EAST, Direction.WEST:
			return 1
		Direction.NORTH:
			return 2
	return 0


func is_animation_playing(anim_name: String = "") -> bool:
	if anim_name == "":
		return is_playing
	return is_playing and current_animation == anim_name


func get_current_animation() -> String:
	return current_animation
