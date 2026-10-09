class_name FireTileSprite
extends Sprite3D
## One tile of burning ground: the fire-hazard visual shared by the Fire
## Goblin Shaman's wall, the Ifrit's lingering breath, the Inflamed
## Minotaur's wake, the player's fire spots and Peshtigo's flames.
##
## Art: the demons pack's fire overlay (`demons/Demon1/Parts/
## Demon1_Attack_fire.png`, 128-px cells, 10 frames x 4 facings). No pack
## ships a standalone ground-fire sheet, so this is the pack piece that IS
## a flame: the up-facing row's burning frames (4..7) looped, which read as
## a tongue of fire rising off the tile. The sheet's measured footprint
## (flame base ~42 px above the cell's bottom edge, centred ~78 px in)
## puts the base of the flame on the tile's origin.
const SHEET := "res://assets/sprites/craftpix/demons/Demon1/Parts/Demon1_Attack_fire.png"
const COLS := 10
const ROWS := 4
const FACING_ROW := 1            # the up-facing row: flames rise
const LOOP := [4, 5, 6, 7, 6, 5]  # the burning frames, rocked back and forth
const BASE_X := 78.0             # px: the flame's centre within the cell
const BASE_Y := 42.0             # px: the flame's base above the cell bottom

@export var fps: float = 9.0
var _acc: float = 0.0
var _i: int = 0

# This script's own path: the factory below builds instances by loading it,
# so callers (and the factory) never depend on the global class cache.
const SELF_PATH := "res://scripts/effects/fire_tile_sprite.gd"

static func make(world_pos: Vector3, scale_mul: float = 1.0, tint: Color = Color.WHITE) -> Sprite3D:
	var s: Sprite3D = load(SELF_PATH).new()
	s.texture = load(SHEET)
	s.hframes = COLS
	s.vframes = ROWS
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD  # writes depth: per-pixel sorting with units
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.pixel_size = 0.03125
	s.centered = false
	# Sprite3D offsets are in texels with +Y up: pull the cell DOWN by the
	# flame's base height so the fire stands on the tile, not above it.
	s.offset = Vector2(-BASE_X, -BASE_Y)
	var sc := 0.6 * scale_mul
	s.scale = Vector3(sc, sc, sc)
	s.modulate = tint
	# A hair under the figures' lift so a unit standing in the fire draws in
	# front of it; neighbouring tiles start on different frames so a sheet
	# of flame does not pulse in lockstep.
	s.position = Vector3(world_pos.x, world_pos.y + CameraView.SPRITE_LIFT - 0.02, world_pos.z)
	s._i = randi() % LOOP.size()
	s._acc = randf()
	s.frame = FACING_ROW * COLS + LOOP[s._i]
	return s

func _process(delta: float) -> void:
	_acc += delta * fps
	if _acc < 1.0:
		return
	_i = (_i + int(_acc)) % LOOP.size()
	_acc -= floorf(_acc)
	frame = FACING_ROW * COLS + LOOP[_i]
