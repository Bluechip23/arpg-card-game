class_name BradAnimations
extends RefCounted

## Animation data for Brad's character, mapped from Secret of Mana sprite sheet.
## Each animation defines: start_x, start_y (top-left pixel of first frame),
## frame_width, frame_height, frames (count), fps, loop (bool).
##
## The sprite sheet layout uses 3 direction rows per animation block:
## Row 0 = SOUTH, Row 1 = EAST/WEST, Row 2 = NORTH
## WEST is rendered by flipping EAST horizontally.
##
## Sprite sheet: res://assets/characters/brad_spritesheet.png (465x537)

const SPRITE_SHEET_PATH = "res://assets/characters/brad_spritesheet.png"

# Frame sizes vary by animation section
const MOVEMENT_FW = 28
const MOVEMENT_FH = 40
const COMBAT_FW = 28
const COMBAT_FH = 40
const WIDE_FW = 34
const WIDE_FH = 40

static func get_animation_data() -> Dictionary:
	return {
		# =============================================
		# MOVEMENT ANIMATIONS (Bands 1-3, y=0-119)
		# =============================================
		"stance": {
			"start_x": 5, "start_y": 0,
			"frame_width": MOVEMENT_FW, "frame_height": MOVEMENT_FH,
			"frames": 3, "fps": 4, "loop": true,
		},
		"walking": {
			"start_x": 155, "start_y": 0,
			"frame_width": MOVEMENT_FW, "frame_height": MOVEMENT_FH,
			"frames": 5, "fps": 8, "loop": true,
		},
		"running": {
			"start_x": 295, "start_y": 0,
			"frame_width": WIDE_FW, "frame_height": MOVEMENT_FH,
			"frames": 2, "fps": 10, "loop": true,
		},
		"battle_stance": {
			"start_x": 363, "start_y": 0,
			"frame_width": 30, "frame_height": MOVEMENT_FH,
			"frames": 3, "fps": 4, "loop": true,
		},

		# =============================================
		# COMBAT ANIMATIONS (Bands 4-6, y=120-239)
		# =============================================
		"weapon_attack_1": {
			"start_x": 5, "start_y": 120,
			"frame_width": COMBAT_FW, "frame_height": COMBAT_FH,
			"frames": 4, "fps": 10, "loop": false,
		},
		"weapon_attack_2": {
			"start_x": 153, "start_y": 120,
			"frame_width": COMBAT_FW, "frame_height": COMBAT_FH,
			"frames": 5, "fps": 10, "loop": false,
		},
		"weapon_attack_3": {
			"start_x": 298, "start_y": 120,
			"frame_width": 33, "frame_height": COMBAT_FH,
			"frames": 2, "fps": 8, "loop": false,
		},
		"weapon_attack_4": {
			"start_x": 363, "start_y": 120,
			"frame_width": 32, "frame_height": COMBAT_FH,
			"frames": 3, "fps": 10, "loop": false,
		},

		# =============================================
		# SPECIAL / DODGE ANIMATIONS (Bands 7-9, y=240-359)
		# =============================================
		"dodge": {
			"start_x": 5, "start_y": 240,
			"frame_width": MOVEMENT_FW, "frame_height": MOVEMENT_FH,
			"frames": 3, "fps": 10, "loop": false,
		},
		"circling_weapon": {
			"start_x": 155, "start_y": 240,
			"frame_width": COMBAT_FW, "frame_height": COMBAT_FH,
			"frames": 5, "fps": 8, "loop": true,
		},
		"charged_weapon_1": {
			"start_x": 295, "start_y": 240,
			"frame_width": 30, "frame_height": COMBAT_FH,
			"frames": 4, "fps": 10, "loop": false,
		},

		# =============================================
		# HIT / DEFEAT ANIMATIONS (Bands 10-12, y=360-536)
		# =============================================
		"hit_knockdown_getup": {
			"start_x": 5, "start_y": 365,
			"frame_width": COMBAT_FW, "frame_height": 45,
			"frames": 5, "fps": 8, "loop": false,
		},
		"losing_balance": {
			"start_x": 155, "start_y": 365,
			"frame_width": 30, "frame_height": 45,
			"frames": 3, "fps": 6, "loop": false,
		},
		"boss_defeat": {
			"start_x": 240, "start_y": 365,
			"frame_width": 35, "frame_height": 50,
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
		"attack_circling": "circling_weapon",

		# Combat - Defense
		"dodge": "dodge",
		"block": "dodge",

		# Combat - Reactions
		"hit": "hit_knockdown_getup",
		"hit_heavy": "hit_knockdown_getup",
		"stunned": "losing_balance",
		"defeat": "boss_defeat",
	}
