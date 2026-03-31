class_name WereratAnimations
extends RefCounted

## Animation data for Wererat sprite sheet.
## Sprite sheet: res://assets/enemies/Rat_full.png (206x50)
## Layout: single row, 7 frames, no direction rows (always faces south)

const SPRITE_SHEET_PATH = "res://assets/enemies/Rat_full.png"

const FW = 29
const FH = 50
const PIXEL_SIZE = 0.022

static func get_animation_data() -> Dictionary:
	return {
		"stance": {
			"start_x": 0, "start_y": 0,
			"frame_width": FW, "frame_height": FH,
			"frames": 4, "fps": 4, "loop": true,
		},
		"walking": {
			"start_x": 0, "start_y": 0,
			"frame_width": FW, "frame_height": FH,
			"frames": 7, "fps": 10, "loop": true,
		},
		"attack": {
			"start_x": FW * 4, "start_y": 0,
			"frame_width": FW, "frame_height": FH,
			"frames": 3, "fps": 10, "loop": false,
		},
		"hit": {
			"start_x": FW * 5, "start_y": 0,
			"frame_width": FW, "frame_height": FH,
			"frames": 2, "fps": 8, "loop": false,
		},
	}

static func get_action_map() -> Dictionary:
	return {
		"idle": "stance",
		"walk": "walking",
		"bite": "attack",
		"scurry": "walking",
		"hit": "hit",
		"defeat": "hit",
	}
