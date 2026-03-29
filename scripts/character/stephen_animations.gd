class_name StephenAnimations
extends RefCounted

## Animation data for Stephen's character sprite sheet.
## Sprite sheet: res://assets/characters/stephen_spritesheet.png (321x745)
## Layout: 3 direction rows per animation group (SOUTH, EAST/WEST, NORTH)
## Direction row spacing ~46px, sprite spacing ~30px

const SPRITE_SHEET_PATH = "res://assets/characters/stephen_spritesheet.png"

const FW = 30
const FH = 46

static func get_animation_data() -> Dictionary:
	return {
		# =============================================
		# MOVEMENT (Group 0: south=7, east=52, north=99)
		# =============================================
		"stance": {
			"start_x": 12, "start_y": 2,
			"frame_width": FW, "frame_height": FH,
			"frames": 3, "fps": 4, "loop": true,
		},
		"walking": {
			"start_x": 12, "start_y": 2,
			"frame_width": FW, "frame_height": FH,
			"frames": 5, "fps": 8, "loop": true,
		},
		"running": {
			"start_x": 135, "start_y": 2,
			"frame_width": FW, "frame_height": FH,
			"frames": 3, "fps": 12, "loop": true,
		},

		# =============================================
		# COMBAT (Group 1: south=143, east=185, north=232)
		# =============================================
		"weapon_attack_1": {
			"start_x": 10, "start_y": 139,
			"frame_width": FW, "frame_height": FH,
			"frames": 5, "fps": 10, "loop": false,
		},
		"weapon_attack_2": {
			"start_x": 133, "start_y": 139,
			"frame_width": FW, "frame_height": FH,
			"frames": 3, "fps": 10, "loop": false,
		},
		"battle_stance": {
			"start_x": 12, "start_y": 139,
			"frame_width": FW, "frame_height": FH,
			"frames": 3, "fps": 4, "loop": true,
		},

		# =============================================
		# SPECIAL (Group 2: south=283, east=299, north=327)
		# =============================================
		"dodge": {
			"start_x": 12, "start_y": 278,
			"frame_width": FW, "frame_height": 25,
			"frames": 3, "fps": 10, "loop": false,
		},
		"charged_weapon_1": {
			"start_x": 5, "start_y": 323,
			"frame_width": 33, "frame_height": FH,
			"frames": 5, "fps": 10, "loop": false,
		},

		# =============================================
		# COMBAT EXTENDED (Group 3: south=328, east=374, north=420)
		# =============================================
		"weapon_attack_3": {
			"start_x": 5, "start_y": 323,
			"frame_width": 33, "frame_height": FH,
			"frames": 8, "fps": 10, "loop": false,
		},

		# =============================================
		# REACTIONS (Group 4: south=490, east=546, north=582)
		# =============================================
		"hit_knockdown_getup": {
			"start_x": 5, "start_y": 486,
			"frame_width": 35, "frame_height": FH,
			"frames": 5, "fps": 8, "loop": false,
		},
		"losing_balance": {
			"start_x": 5, "start_y": 486,
			"frame_width": 35, "frame_height": FH,
			"frames": 3, "fps": 6, "loop": false,
		},

		# =============================================
		# DEFEAT (Group 5: south=629, east=670, north=713)
		# =============================================
		"boss_defeat": {
			"start_x": 5, "start_y": 625,
			"frame_width": 35, "frame_height": FH,
			"frames": 5, "fps": 6, "loop": false,
		},
	}


## Maps game actions to animation names for the state machine
static func get_action_map() -> Dictionary:
	return {
		# Movement
		"idle": "stance",
		"walk": "walking",
		"run": "running",
		"battle_ready": "battle_stance",

		# Combat - Attacks
		"attack_slash": "weapon_attack_1",
		"attack_heavy": "weapon_attack_2",
		"attack_charged_1": "charged_weapon_1",
		"attack_ranged": "weapon_attack_3",

		# Combat - Defense
		"dodge": "dodge",
		"block": "dodge",

		# Combat - Reactions
		"hit": "hit_knockdown_getup",
		"hit_heavy": "hit_knockdown_getup",
		"stunned": "losing_balance",
		"defeat": "boss_defeat",
	}
