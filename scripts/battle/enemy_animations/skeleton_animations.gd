class_name SkeletonAnimations
extends RefCounted

## Animation data for Skeleton sprite sheet.
## Sprite sheet: res://assets/enemies/skeleton_full.png (280x202)
## Layout: single row, 2 frames, no direction rows (always faces south)

const SPRITE_SHEET_PATH = "res://assets/enemies/skeleton_full.png"

const FW = 140
const FH = 202
const PIXEL_SIZE = 0.006

static func get_animation_data() -> Dictionary:
	return {
		"stance": {
			"start_x": 0, "start_y": 0,
			"frame_width": FW, "frame_height": FH,
			"frames": 2, "fps": 2, "loop": true,
		},
		"walking": {
			"start_x": 0, "start_y": 0,
			"frame_width": FW, "frame_height": FH,
			"frames": 2, "fps": 4, "loop": true,
		},
		"attack": {
			"start_x": 0, "start_y": 0,
			"frame_width": FW, "frame_height": FH,
			"frames": 2, "fps": 6, "loop": false,
		},
		"hit": {
			"start_x": FW, "start_y": 0,
			"frame_width": FW, "frame_height": FH,
			"frames": 1, "fps": 4, "loop": false,
		},
	}

static func get_action_map() -> Dictionary:
	return {
		"idle": "stance",
		"walk": "walking",
		"attack": "attack",
		"hit": "hit",
		"defeat": "hit",
	}
