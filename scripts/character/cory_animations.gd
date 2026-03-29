class_name CoryAnimations
extends RefCounted

## Animation data for Cory's character sprite sheet.
## Sprite sheet: res://assets/characters/cory_spritesheet.png (222x727)
## Layout: 3 direction rows per animation group (SOUTH, EAST/WEST, NORTH)
## Direction row spacing ~41px, sprite spacing ~43px

const SPRITE_SHEET_PATH = "res://assets/characters/cory_spritesheet.png"

const FW = 44
const FH = 42

static func get_animation_data() -> Dictionary:
	return {
		# =============================================
		# MOVEMENT (Group 0: south=3, east=44, north=86)
		# =============================================
		"stance": {
			"start_x": 7, "start_y": 0,
			"frame_width": FW, "frame_height": FH,
			"frames": 3, "fps": 4, "loop": true,
		},
		"walking": {
			"start_x": 7, "start_y": 0,
			"frame_width": FW, "frame_height": FH,
			"frames": 4, "fps": 8, "loop": true,
		},

		# =============================================
		# COMBAT (Group 1: south=126, east=168, north=207)
		# =============================================
		"weapon_attack_1": {
			"start_x": 5, "start_y": 124,
			"frame_width": FW, "frame_height": FH,
			"frames": 4, "fps": 10, "loop": false,
		},
		"battle_stance": {
			"start_x": 5, "start_y": 124,
			"frame_width": FW, "frame_height": FH,
			"frames": 3, "fps": 4, "loop": true,
		},

		# =============================================
		# SPECIAL (Group 2: south=245, east=283, north=319)
		# =============================================
		"dodge": {
			"start_x": 5, "start_y": 242,
			"frame_width": FW, "frame_height": FH,
			"frames": 3, "fps": 10, "loop": false,
		},
		"weapon_attack_2": {
			"start_x": 5, "start_y": 242,
			"frame_width": FW, "frame_height": FH,
			"frames": 3, "fps": 10, "loop": false,
		},

		# =============================================
		# REACTIONS (Group 3: south=360, east=401, north=441)
		# =============================================
		"hit_knockdown_getup": {
			"start_x": 5, "start_y": 357,
			"frame_width": FW, "frame_height": FH,
			"frames": 4, "fps": 8, "loop": false,
		},
		"losing_balance": {
			"start_x": 5, "start_y": 357,
			"frame_width": FW, "frame_height": FH,
			"frames": 3, "fps": 6, "loop": false,
		},

		# =============================================
		# ADVANCED (Group 4: south=484, east=526, north=565)
		# =============================================
		"weapon_attack_3": {
			"start_x": 5, "start_y": 480,
			"frame_width": FW, "frame_height": FH,
			"frames": 4, "fps": 10, "loop": false,
		},
		"boss_defeat": {
			"start_x": 3, "start_y": 604,
			"frame_width": 46, "frame_height": 45,
			"frames": 4, "fps": 6, "loop": false,
		},
	}


static func get_action_map() -> Dictionary:
	return {
		"idle": "stance",
		"walk": "walking",
		"run": "walking",
		"battle_ready": "battle_stance",
		"attack_slash": "weapon_attack_1",
		"attack_heavy": "weapon_attack_2",
		"attack_charged_1": "weapon_attack_3",
		"attack_ranged": "weapon_attack_1",
		"dodge": "dodge",
		"block": "dodge",
		"hit": "hit_knockdown_getup",
		"hit_heavy": "hit_knockdown_getup",
		"stunned": "losing_balance",
		"defeat": "boss_defeat",
	}
