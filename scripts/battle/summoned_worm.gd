extends Summon

## An Alaskan Bull Worm summoned by Worm's Armageddon (10% proc).
##
## Stat block (per the card): 12 HP, 6 damage, burrowed until it attacks,
## untargetable while burrowed, 1 movement per tempo.
##
## This node owns only visuals/health/movement animation;
## main.gd drives the per-tempo decisions (_update_summoned_worms).

const MAX_HEALTH := 12
const CONTACT_DAMAGE := 6

var burrowed: bool = true  # Untargetable until it surfaces to attack

var _mound: Sprite3D = null
var _surfaced_label_pos := Vector3.ZERO

func setup(gm: GridManager, spawn_pos: Vector3) -> void:
	_place(gm, spawn_pos)
	display_name = "Worm"
	glide_speed = 3.0
	max_health = MAX_HEALTH
	health = MAX_HEALTH
	_finish_setup()

func _build_visuals() -> void:
	# Surfaced: the designer's coiled, horned bull worm (bull_worm_board.jpg,
	# cut by tools/cut_pose_boards.py), hidden while it is burrowed.
	_build_figure("bull_worm")
	_figure.visible = false
	# Burrowed: a heap of churned earth with the burrow's mouth on top, cut
	# from the pack's own field dirt (tools/generate_scenery_props.py — no
	# pack draws a mound).
	_mound = Sprite3D.new()
	_mound.texture = load("res://assets/textures/props/worm_mound.png")
	_mound.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mound.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_mound.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mound.shaded = false
	_mound.pixel_size = CameraView.PIXEL_SIZE
	CameraView.stand_on_ground(_mound, CameraView.GROUND_COVER_LIFT)
	_mound.offset.y = -float(_mound.texture.get_height()) * 0.5   # the heap's middle on the tile's
	add_child(_mound)
	_build_health_label(1.1, Color(0.9, 0.85, 0.95), 28)
	# Over the low mound while burrowed; over the worm's head once it surfaces.
	_surfaced_label_pos = _health_label.position
	_health_label.position = Vector3(0, 0.5, -0.75)

func surface() -> void:
	## The worm erupts from the ground to attack — from now on it is targetable.
	if not burrowed:
		return
	burrowed = false
	if _mound:
		_mound.visible = false
	if _figure:
		_figure.visible = true
	if _health_label:
		_health_label.position = _surfaced_label_pos
	_update_health_label()

func _health_label_text() -> String:
	if burrowed:
		return "Worm (burrowed)"
	return "Worm %d/%d" % [max(health, 0), MAX_HEALTH]

func _can_be_hit() -> bool:
	return not burrowed  # Untargetable while burrowed
