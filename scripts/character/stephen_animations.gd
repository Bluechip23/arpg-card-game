class_name StephenAnimations
extends RefCounted

## Animation data for Stephen's character, mapped from Randi's Secret of Mana sprite sheet.
## Each animation defines: start_x, start_y (top-left pixel of first frame),
## frame_width, frame_height, frames (count), fps, loop (bool).
##
## IMPORTANT: These pixel coordinates are estimates based on the reference sprite sheet.
## You MUST adjust start_x/start_y values to match your actual sprite sheet file.
## The sprite sheet should be placed at: res://assets/characters/stephen_spritesheet.png

const SPRITE_SHEET_PATH = "res://assets/characters/stephen_spritesheet.png"

# Default frame size for most animations (Secret of Mana standard)
const DEFAULT_FW = 48
const DEFAULT_FH = 48

static func get_animation_data() -> Dictionary:
	return {
		# =============================================
		# MOVEMENT ANIMATIONS
		# =============================================
		"stance": {
			"start_x": 0, "start_y": 0,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 3, "fps": 4, "loop": true,
		},
		"walking": {
			"start_x": 48, "start_y": 0,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 8, "fps": 10, "loop": true,
		},
		"running": {
			"start_x": 384, "start_y": 0,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 8, "fps": 12, "loop": true,
		},
		"pushing": {
			"start_x": 0, "start_y": 48,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 4, "fps": 8, "loop": true,
		},

		# =============================================
		# STATUS / REACTION ANIMATIONS
		# =============================================
		"tongue_snare": {
			"start_x": 96, "start_y": 48,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 4, "fps": 6, "loop": true,
		},
		"spell_snare": {
			"start_x": 192, "start_y": 48,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 4, "fps": 6, "loop": true,
		},
		"sleeping": {
			"start_x": 288, "start_y": 48,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 4, "fps": 3, "loop": true,
		},
		"losing_balance": {
			"start_x": 384, "start_y": 48,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 4, "fps": 8, "loop": false,
		},
		"hanging": {
			"start_x": 864, "start_y": 48,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 4, "fps": 4, "loop": true,
		},

		# =============================================
		# SOCIAL / INTERACTION ANIMATIONS
		# =============================================
		"bowing": {
			"start_x": 480, "start_y": 48,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 4, "fps": 6, "loop": false,
		},
		"expressions": {
			"start_x": 576, "start_y": 48,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 4, "fps": 6, "loop": false,
		},
		"grab_shake_throw": {
			"start_x": 672, "start_y": 48,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 8, "fps": 8, "loop": false,
		},
		"looking_around": {
			"start_x": 0, "start_y": 96,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 6, "fps": 6, "loop": false,
		},

		# =============================================
		# WEAPON HANDLING ANIMATIONS
		# =============================================
		"pull_mana_sword": {
			"start_x": 96, "start_y": 96,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 6, "fps": 8, "loop": false,
		},
		"put_back_mana_sword": {
			"start_x": 288, "start_y": 96,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 4, "fps": 8, "loop": false,
		},
		"battle_stance": {
			"start_x": 864, "start_y": 96,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 3, "fps": 4, "loop": true,
		},
		"high_stepper": {
			"start_x": 480, "start_y": 96,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 6, "fps": 8, "loop": false,
		},
		"travel_cannon_somersault": {
			"start_x": 576, "start_y": 96,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 10, "fps": 10, "loop": false,
		},

		# =============================================
		# CHARGED WEAPON ANIMATIONS
		# =============================================
		"charged_weapon_1": {
			"start_x": 0, "start_y": 144,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 6, "fps": 10, "loop": false,
		},
		"charged_weapon_2": {
			"start_x": 192, "start_y": 144,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 6, "fps": 10, "loop": false,
		},
		"charged_weapon_3": {
			"start_x": 384, "start_y": 144,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 6, "fps": 10, "loop": false,
		},

		# =============================================
		# GENERIC WEAPON ATTACK ANIMATIONS
		# =============================================
		"bow_arrow_attack": {
			"start_x": 576, "start_y": 144,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 8, "fps": 10, "loop": false,
		},
		"weapon_attack_1": {
			"start_x": 768, "start_y": 144,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 6, "fps": 10, "loop": false,
		},
		"weapon_attack_2": {
			"start_x": 0, "start_y": 192,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 6, "fps": 10, "loop": false,
		},
		"weapon_attack_3": {
			"start_x": 192, "start_y": 192,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 6, "fps": 10, "loop": false,
		},
		"weapon_attack_4": {
			"start_x": 384, "start_y": 192,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 6, "fps": 10, "loop": false,
		},
		"weapon_attack_5": {
			"start_x": 576, "start_y": 192,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 6, "fps": 10, "loop": false,
		},

		# =============================================
		# SPECIAL ATTACK ANIMATIONS
		# =============================================
		"flying_sword_attack": {
			"start_x": 0, "start_y": 240,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 8, "fps": 10, "loop": false,
		},
		"circling_weapon": {
			"start_x": 288, "start_y": 240,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 6, "fps": 8, "loop": true,
		},
		"elbow_check": {
			"start_x": 0, "start_y": 288,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 5, "fps": 10, "loop": false,
		},
		"double_punch": {
			"start_x": 96, "start_y": 288,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 6, "fps": 10, "loop": false,
		},

		# =============================================
		# DODGE / DEFENSE ANIMATIONS
		# =============================================
		"dodge": {
			"start_x": 480, "start_y": 240,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 4, "fps": 10, "loop": false,
		},
		"backflip": {
			"start_x": 576, "start_y": 240,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 6, "fps": 10, "loop": false,
		},
		"defend_with_weapon": {
			"start_x": 672, "start_y": 240,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 4, "fps": 8, "loop": false,
		},

		# =============================================
		# KICK ANIMATIONS
		# =============================================
		"high_kick_1": {
			"start_x": 288, "start_y": 288,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 5, "fps": 10, "loop": false,
		},
		"high_kick_2": {
			"start_x": 432, "start_y": 288,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 5, "fps": 10, "loop": false,
		},
		"knee_kick": {
			"start_x": 576, "start_y": 288,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 5, "fps": 10, "loop": false,
		},
		"flying_kick": {
			"start_x": 720, "start_y": 288,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 6, "fps": 10, "loop": false,
		},

		# =============================================
		# HIT / DEFEAT ANIMATIONS
		# =============================================
		"hit_knockdown_unconscious_getup": {
			"start_x": 0, "start_y": 336,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 12, "fps": 8, "loop": false,
		},
		"hit_knockdown_getup": {
			"start_x": 288, "start_y": 336,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 8, "fps": 8, "loop": false,
		},
		"boss_defeat": {
			"start_x": 768, "start_y": 240,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 6, "fps": 6, "loop": false,
		},

		# =============================================
		# SPECIAL ANIMATIONS
		# =============================================
		"summoning_mana_spirit": {
			"start_x": 0, "start_y": 384,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 8, "fps": 6, "loop": false,
		},
		"glitchy_run": {
			"start_x": 864, "start_y": 0,
			"frame_width": DEFAULT_FW, "frame_height": DEFAULT_FH,
			"frames": 4, "fps": 10, "loop": true,
		},
	}


## Maps game actions to animation names for the state machine
static func get_action_map() -> Dictionary:
	return {
		# Movement
		"idle": "stance",
		"walk": "walking",
		"run": "running",
		"push": "pushing",
		"blink": "travel_cannon_somersault",

		# Combat - Attacks (mapped to card types)
		"attack_slash": "weapon_attack_1",
		"attack_heavy": "weapon_attack_3",
		"attack_ranged": "bow_arrow_attack",
		"attack_charged_1": "charged_weapon_1",
		"attack_charged_2": "charged_weapon_2",
		"attack_charged_3": "charged_weapon_3",
		"attack_flying": "flying_sword_attack",
		"attack_elbow": "elbow_check",
		"attack_double_punch": "double_punch",
		"attack_circling": "circling_weapon",

		# Combat - Kicks
		"kick_high": "high_kick_1",
		"kick_high_alt": "high_kick_2",
		"kick_knee": "knee_kick",
		"kick_flying": "flying_kick",

		# Combat - Defense
		"block": "defend_with_weapon",
		"dodge": "dodge",
		"dodge_backflip": "backflip",

		# Combat - Reactions
		"hit": "hit_knockdown_getup",
		"hit_heavy": "hit_knockdown_unconscious_getup",
		"defeat": "boss_defeat",

		# Status effects
		"stunned": "losing_balance",
		"snared": "tongue_snare",
		"spell_bound": "spell_snare",
		"sleeping": "sleeping",

		# Utility
		"empower": "summoning_mana_spirit",
		"draw_weapon": "pull_mana_sword",
		"sheathe_weapon": "put_back_mana_sword",
		"battle_ready": "battle_stance",
		"look_around": "looking_around",
		"bow": "bowing",
		"interact": "grab_shake_throw",
	}
