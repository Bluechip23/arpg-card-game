class_name ArmoredTrollAnimations
extends RefCounted

## Animation data for Armored Troll sprite sheet.
## Sprite sheet: res://assets/enemies/armored_troll_full.png (252x57)
## Layout: single row, 7 frames, no direction rows (always faces south)

const SPRITE_SHEET_PATH = "res://assets/enemies/armored_troll_full.png"

const FW = 36
const FH = 57
const PIXEL_SIZE = 0.024

static func get_animation_data() -> Dictionary:
	return {
		"stance": {
			"start_x": 0, "start_y": 0,
			"frame_width": FW, "frame_height": FH,
			"frames": 4, "fps": 3, "loop": true,
		},
		"walking": {
			"start_x": 0, "start_y": 0,
			"frame_width": FW, "frame_height": FH,
			"frames": 7, "fps": 8, "loop": true,
		},
		"attack": {
			"start_x": FW * 4, "start_y": 0,
			"frame_width": FW, "frame_height": FH,
			"frames": 3, "fps": 8, "loop": false,
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
		"kick": "attack",
		"smash": "attack",
		"hit": "hit",
		"defeat": "hit",
	}
