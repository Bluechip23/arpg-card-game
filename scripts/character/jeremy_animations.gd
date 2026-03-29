class_name JeremyAnimations
extends RefCounted

## Animation data for Jeremy's character sprite sheet.
## Sprite sheet: res://assets/characters/jeremy_spritesheet.png (255x892)
## Layout: 3 direction rows per animation group (SOUTH, EAST/WEST, NORTH)
## Direction row spacing ~56px, sprite spacing ~40px

const SPRITE_SHEET_PATH = "res://assets/characters/jeremy_spritesheet.png"

const FW = 40
const FH = 57

static func get_animation_data() -> Dictionary:
	return {
		# =============================================
		# MOVEMENT (Group 0: south=7, east=63, north=118)
		# =============================================
		"stance": {
			"start_x": 3, "start_y": 3,
			"frame_width": FW, "frame_height": FH,
			"frames": 3, "fps": 4, "loop": true,
		},
		"walking": {
			"start_x": 3, "start_y": 3,
			"frame_width": FW, "frame_height": FH,
			"frames": 4, "fps": 8, "loop": true,
		},

		# =============================================
		# COMBAT (Group 1: south=178, east=235, north=292)
		# =============================================
		"weapon_attack_1": {
			"start_x": 3, "start_y": 174,
			"frame_width": FW, "frame_height": FH,
			"frames": 4, "fps": 10, "loop": false,
		},
		"battle_stance": {
			"start_x": 3, "start_y": 174,
			"frame_width": FW, "frame_height": FH,
			"frames": 3, "fps": 4, "loop": true,
		},

		# =============================================
		# SPECIAL (Group 2: south=351, east=407, north=461)
		# =============================================
		"dodge": {
			"start_x": 3, "start_y": 348,
			"frame_width": FW, "frame_height": FH,
			"frames": 3, "fps": 10, "loop": false,
		},
		"weapon_attack_2": {
			"start_x": 3, "start_y": 348,
			"frame_width": FW, "frame_height": FH,
			"frames": 3, "fps": 10, "loop": false,
		},

		# =============================================
		# HIT / REACTIONS (Group 3: south=461, east=522, north=578)
		# =============================================
		"hit_knockdown_getup": {
			"start_x": 0, "start_y": 458,
			"frame_width": 44, "frame_height": FH,
			"frames": 5, "fps": 8, "loop": false,
		},
		"losing_balance": {
			"start_x": 0, "start_y": 458,
			"frame_width": 44, "frame_height": FH,
			"frames": 3, "fps": 6, "loop": false,
		},

		# =============================================
		# ADVANCED COMBAT (Group 4: south=636, east=692, north=752)
		# =============================================
		"weapon_attack_3": {
			"start_x": 3, "start_y": 632,
			"frame_width": 42, "frame_height": FH,
			"frames": 5, "fps": 10, "loop": false,
		},
		"boss_defeat": {
			"start_x": 3, "start_y": 812,
			"frame_width": 40, "frame_height": 57,
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
