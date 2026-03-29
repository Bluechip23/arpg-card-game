class_name RyanAnimations
extends RefCounted

## Animation data for Ryan's character sprite sheet.
## Sprite sheet: res://assets/characters/ryan_spritesheet.png (267x891)
## Layout: 3 direction rows per animation group (SOUTH, EAST/WEST, NORTH)
## Direction row spacing ~55px, sprite spacing ~35px

const SPRITE_SHEET_PATH = "res://assets/characters/ryan_spritesheet.png"

const FW = 35
const FH = 55

static func get_animation_data() -> Dictionary:
	return {
		# =============================================
		# MOVEMENT (Group 0: south=5, east=60, north=111)
		# =============================================
		"stance": {
			"start_x": 12, "start_y": 0,
			"frame_width": FW, "frame_height": FH,
			"frames": 3, "fps": 4, "loop": true,
		},
		"walking": {
			"start_x": 12, "start_y": 0,
			"frame_width": FW, "frame_height": FH,
			"frames": 4, "fps": 8, "loop": true,
		},

		# =============================================
		# COMBAT (Group 1: south=162, east=219, north=270)
		# =============================================
		"weapon_attack_1": {
			"start_x": 12, "start_y": 157,
			"frame_width": FW, "frame_height": FH,
			"frames": 4, "fps": 10, "loop": false,
		},
		"battle_stance": {
			"start_x": 12, "start_y": 157,
			"frame_width": FW, "frame_height": FH,
			"frames": 3, "fps": 4, "loop": true,
		},

		# =============================================
		# SPECIAL (Group 2: south=320, east=373, north=429)
		# =============================================
		"dodge": {
			"start_x": 10, "start_y": 315,
			"frame_width": FW, "frame_height": FH,
			"frames": 3, "fps": 10, "loop": false,
		},
		"weapon_attack_2": {
			"start_x": 10, "start_y": 315,
			"frame_width": FW, "frame_height": FH,
			"frames": 4, "fps": 10, "loop": false,
		},

		# =============================================
		# HIT / REACTIONS (Group 3: south=480, east=528, north=576)
		# =============================================
		"hit_knockdown_getup": {
			"start_x": 5, "start_y": 475,
			"frame_width": 38, "frame_height": FH,
			"frames": 5, "fps": 8, "loop": false,
		},
		"losing_balance": {
			"start_x": 5, "start_y": 475,
			"frame_width": 38, "frame_height": FH,
			"frames": 3, "fps": 6, "loop": false,
		},

		# =============================================
		# ADVANCED COMBAT (Group 4: south=622, east=673, north=728)
		# =============================================
		"weapon_attack_3": {
			"start_x": 5, "start_y": 618,
			"frame_width": 35, "frame_height": FH,
			"frames": 5, "fps": 10, "loop": false,
		},
		"boss_defeat": {
			"start_x": 5, "start_y": 773,
			"frame_width": 40, "frame_height": 55,
			"frames": 5, "fps": 6, "loop": false,
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
