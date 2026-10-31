class_name SpriteFigure
extends Node3D

## Billboard Sprite3D character for battle, drawing the Mana Seed sprite packs
##
## The one battle figure for playable characters: exposes the verbs the
## Player facade calls (play_action, set_walking, set_facing_from_velocity,
## face_toward, set_translucent, set_highlight, pop_*). Card actions the sprite
## sheets can't express fall back to a small set of readable motions
## (attack swing, guard flash, hop, cast flash) rather than bespoke animation.
##
## All five heroes wear the designer's hero sprites (2026-10-23,
## tools/cut_hero_sprites.py): one detailed pose per direction, drawn finer
## than the 32-texel tiles so the art keeps its nuance; walking steps the body
## up and down (or strides through a drawn walk cycle where the hero's sheet
## has one: every hero's from 2026-10-31), and attacks lunge the body toward the target (the pack's
## weapon swing was deleted on 2026-10-30 for the designer's own attacks). The NPC mode (an NPC
## pack sheet with walk frames, the same overlay) draws the dojo's dogs. (The
## Mana Seed paper-doll mode went with its art on 2026-10-30.)

const SEED := "res://assets/sprites/SeedcharacterBase"

## Which sprites each playable character uses: a hero board, or the raw NPC
## sheet.
const ROSTER := {
	# Every hero strides (their walk boards, 2026-10-31): "walk_rows" are
	# the sheet rows whose columns 1.. hold a walk cycle (Stephen's east
	# row from its own corrected board, tools/cut_hero_sprites.py WALK_EXTRA).
	# "actions": the designer's drawn actions (tools/cut_hero_actions.py),
	# played in place of the fallback motion: the sheet, its frames, the
	# rows it draws (S, N, E, W = 0-3), seconds a frame, and optionally a
	# hold on the last frame, a quicker play back to the first, and the
	# frame (from 1, as the board numbers them) on which the blow lands: the
	# damage waits for it (hit_delay; Main holds the tick clock meanwhile).
	# The basic Attack (card and auto attack) and Block (card and shield
	# button).
	"Brad": {"board": "res://assets/sprites/generated/heroes/brad.png", "walk_rows": [0, 1, 2, 3],  # the warrior, the War Rack over his shoulder
		"actions": {
			# The jumping overhead smash; it slams down on frame 7.
			"basic_attack": {"sheet": "res://assets/sprites/generated/heroes/brad_attack.png",
				"frames": 8, "rows": [0, 1, 2, 3], "t": 0.06, "hit": 7},
			# Stone encases him, holds, and crumbles back off (no back view).
			"basic_block": {"sheet": "res://assets/sprites/generated/heroes/brad_block.png",
				"frames": 12, "rows": [0, 2, 3], "t": 0.06, "hold": 0.5, "reverse": 0.035},
		}},
	"Cory": {"board": "res://assets/sprites/generated/heroes/cory.png", "walk_rows": [0, 1, 2, 3],      # the hooded monk
		"actions": {
			# The aerial shadow kick combo: a leap, kicks trailing violet
			# shadow, a spinning kick, and he lands.
			"basic_attack": {"sheet": "res://assets/sprites/generated/heroes/cory_attack.png", "frames": 10, "rows": [0, 1, 2, 3], "t": 0.055, "hit": 5},
			# The energy field: a palm raised, a ring of blue force flares.
			"basic_block": {"sheet": "res://assets/sprites/generated/heroes/cory_block.png", "frames": 8, "rows": [0, 1, 2, 3], "t": 0.065},
		}},
	"Stephen": {"board": "res://assets/sprites/generated/heroes/stephen.png", "walk_rows": [0, 1, 2, 3],  # the apex hunter, bow and axe on his back
		"actions": {
			# The bear transformation swipe: his head turns bear and the bear
			# arm rakes; the bear lingers a beat before he is himself again.
			"basic_attack": {"sheet": "res://assets/sprites/generated/heroes/stephen_attack.png", "frames": 8, "rows": [0, 1, 2, 3], "t": 0.06, "hold": 0.15, "hit": 7},
			# The parry: two knives drawn and crossed with a flash, sheathed.
			"basic_block": {"sheet": "res://assets/sprites/generated/heroes/stephen_block.png", "frames": 7, "rows": [0, 1, 2, 3], "t": 0.065},
		}},
	"Jeremy": {"board": "res://assets/sprites/generated/heroes/jeremy.png", "walk_rows": [0, 1, 2, 3],  # the cloaked skeleton
		"actions": {
			# The backwind bone blade: a bone blade sweeps out in a glowing arc.
			"basic_attack": {"sheet": "res://assets/sprites/generated/heroes/jeremy_attack.png", "frames": 8, "rows": [0, 1, 2, 3], "t": 0.06, "hit": 7},
			# The bone wall rises, holds, and sinks back into the ground.
			"basic_block": {"sheet": "res://assets/sprites/generated/heroes/jeremy_block.png", "frames": 8, "rows": [0, 1, 2, 3], "t": 0.06, "hold": 0.5, "reverse": 0.035},
		}},
	"Ryan": {"board": "res://assets/sprites/generated/heroes/ryan.png", "walk_rows": [0, 1, 2, 3],      # the rogue outlaw
		"actions": {
			# The dual blade flurry: four alternating stabs.
			"basic_attack": {"sheet": "res://assets/sprites/generated/heroes/ryan_attack.png", "frames": 14, "rows": [0, 1, 2, 3], "t": 0.045, "hit": 7},
			# His block is a backflip, a full 360 out of harm's way.
			"basic_block": {"sheet": "res://assets/sprites/generated/heroes/ryan_block.png", "frames": 15, "rows": [0, 1, 2, 3], "t": 0.045},
		}},
	# The dojo's ally training dummies wear the NPC-pack dog sheet (same
	# 32px cell and S,E,N,W row order as the humanoid NPC sheets).
	"Dog": {"npc": "res://assets/sprites/NPCpackage2/npc dog v01.png"},
}

# Sheet rows per facing (CharacterAnimator.Direction order: S, N, E, W).
const DOLL_ROW := [0, 1, 2, 3]   # hero boards and the shield sheet run S,N,E,W
const NPC_ROW := [0, 2, 1, 3]    # NPC packs run S,E,N,W

const ATTACK_TIMES := [0.16, 0.065, 0.065, 0.2]
const NPC_WALK_TIME := 0.18
## Each frame of a hero's drawn walk cycle (eight frames: a 0.8 s stride).
const BOARD_WALK_TIME := 0.1
const PIXEL_SIZE := 0.03125
## The designer's hero sprites stand this tall (world units = tiles), drawn
## at whatever pixel size makes their front pose this height, so their detail
## is kept: well clear of the human-sized enemies (0.85-1.2) so the heroes
## read on screen (designer, 2026-10-24: 1.3 looked small).
const BOARD_HEIGHT := 1.6
## ...and drawn this much wider than tall, for a stockier, heavier build
## (designer, 2026-10-24: "a little bigger and thicker").
const BOARD_WIDEN := 1.12
## An action sheet's ground sits this fraction of its cell up from the cell's
## bottom, with the hero's standing anchor at the cell's middle
## (tools/cut_hero_actions.py ACTION_FLOOR): room below for dust.
const ACTION_FLOOR := 8
## Texels a tile the hero sheets are cut at.
const BOARD_DENSITY := 64.0
## Wearing the smooth (non-pixelated) hero sheet (ArtStyle).
var smooth := false
## The pack's weapon layers are drawn for its ~29px character base: on a hero
## sprite they are scaled by the hero's height over that body's.
const PACK_BODY_HEIGHT := 29.0 * 0.03125
## A hero sprite's walk has no stride in its art (one pose a direction), so
## the body steps instead: up STEP_LIFT (world units) and back, STEP_HZ a second.
const STEP_LIFT := 2.0 * 0.03125
const STEP_HZ := 3.5



const GUARD_ACTIONS := ["block", "basic_block", "defend", "parry", "cover", "barricade", "harden",
		"hold_the_line", "hunker_down", "approach_stance", "magic_barrier", "vengeful_shield"]
const HOP_ACTIONS := ["roll", "dodge", "bob_and_weave", "heroic_leap", "rise"]

var facing: int = CharacterAnimator.Direction.SOUTH

var _mode := "board"
# The body sheet of the NPC and hero-sprite ("board") modes: cell size, the
# row each facing reads (S, N, E, W order), and walk frames per row.
var _body_cell := 32
var _body_rows: Array = NPC_ROW
var _body_walk_frames := 4
var _walk_rows: Array = []         # board rows with a drawn walk cycle (the rest step their pose)
var _actions: Dictionary = {}      # drawn actions: name -> {tex, cell, frames, rows, t, hold, reverse}
var _action_sprite: Sprite3D = null  # draws them, the body hidden meanwhile
var _body_offset := Vector2.ZERO   # the board body's offset with its feet on the ground
var _hand_scale := 1.0             # held items ride this much higher on a taller hero
var _shadow_scale := 1.0           # the contact shadow grows with a bigger hero
var _step_clock := 0.0
var _sprites: Array[Sprite3D] = []       # every sprite (for modulate passes)
var _npc_sprite: Sprite3D = null
# The held weapon's category (see Inventory.held_weapon_kind); a shield adds
# the shield layer (raised on guard).
var _weapon_kind := "none"
var _has_shield := false
var _shield_back: Sprite3D = null
var _shield_front: Sprite3D = null
var _shield_texture: Texture2D = null
var _show_shield := false
var _shield_in_front := false   # guard: the shield raised before the body

var _frames: Array = []
var _frame_i := 0
var _clock := 0.0
var _looping := true
var _attacking := false
var _walking := false
var _base_modulate := Color.WHITE
var _fx_tween: Tween = null
var _rig: Node3D = null   # sprites parent; effect tweens move/scale this
var _shadow: BlobShadow = null
var _fx: ActionFX = null  # bespoke per-card effect layer (icicles, fireballs, …)


func setup(character_name: String) -> void:
	# Re-entrant: callers like the character sheet re-setup the same figure
	# when paging between party members, so tear down any previous build.
	if _rig and is_instance_valid(_rig):
		_rig.queue_free()
	_sprites.clear()
	_npc_sprite = null
	_shield_back = null
	_shield_front = null
	_frames = []
	_walk_rows = []
	_actions = {}
	_action_sprite = null
	var cfg: Dictionary = ROSTER.get(character_name, ROSTER["Brad"])
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	if cfg.has("board"):
		_setup_board(cfg["board"], cfg.get("walk_rows", []), cfg.get("actions", {}))
	else:
		_setup_npc(cfg["npc"])
	# Contact shadow lives OUTSIDE the rig: hops/knockback move the rig, the
	# shadow stays on the ground and shrinks with height (see _process).
	position.y = CameraView.SPRITE_LIFT  # nearer the camera than any wall slab (plan view depth)
	var old_shadow := get_node_or_null("Shadow")
	if old_shadow:
		old_shadow.queue_free()
	_shadow = BlobShadow.attach(self, 0.62 * _shadow_scale)
	# Effect layer for bespoke card animations. Outside the rig so hops and
	# knockback don't drag mid-flight projectiles along with the body.
	if _fx and is_instance_valid(_fx):
		_fx.queue_free()
	_fx = ActionFX.new()
	_fx.name = "ActionFX"
	add_child(_fx)
	_apply_fx_facing()
	_play("idle")


static func supports(character_name: String) -> bool:
	return ROSTER.has(character_name)


## The roster preset whose sheets a character wears. Presets resolve by their
## base name; quiz-built characters and pre-`base_character` saves carry a
## preset's passive, so they resolve through that; anything else wears Brad's
## sheet (setup()'s own default).
const LEGACY_PASSIVE_TEXT := {
	"Belt cards cost 1 less mana": "Belt cards cost 10 less mana",
	"Gain 1 mana when gauntlet skill comes off cooldown": "Gain 10 mana when gauntlet skill comes off cooldown",
}

## A small pre-rendered 3D view of a roster figure idling (orthographic,
## slightly raised 3/4 angle, the style guide's upper-left key light) for 2D
## screens: the character-select cards and the load screen.
static func make_preview(preset: String) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var figure := SpriteFigure.new()
	figure.setup(preset)
	viewport.add_child(figure)
	# Framed by the figure's height: the hero sprites stand BOARD_HEIGHT tall,
	# the pack's people about a tile.
	var tall: float = BOARD_HEIGHT if ROSTER.get(preset, {}).has("board") else 1.0
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.6 * tall
	viewport.add_child(cam)
	var eye := Vector3(0.5, 1.05, 2.6) * tall
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, 0.58 * tall, 0) - eye, Vector3.UP), eye)
	cam.current = true
	var key := DirectionalLight3D.new()
	key.light_energy = 1.15
	key.rotation_degrees = Vector3(-45, -30, 0)
	viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.45
	fill.rotation_degrees = Vector3(-12, -42, 0)
	viewport.add_child(fill)
	return container


static func preset_for(data: CharacterData) -> String:
	var base := data.get_base_character()
	if ROSTER.has(base):
		return base
	if data.passive_description != "":
		# Saves made before 2026-10-22 carry the old "1 mana" wording of
		# Ryan's and Cory's passives (the code always gave 10).
		var desc: String = LEGACY_PASSIVE_TEXT.get(data.passive_description, data.passive_description)
		for preset in CharacterData.get_all_characters():
			if preset.passive_description == desc:
				return preset.character_name
	return "Brad"


func _setup_npc(sheet_path: String) -> void:
	_mode = "npc"
	_body_cell = 32
	_shadow_scale = 1.0
	_body_rows = NPC_ROW
	_body_walk_frames = 4
	_hand_scale = 1.0
	# NPC bodies fill their 32px cell to the bottom edge.
	var y := 16.0 * PIXEL_SIZE
	_shield_back = _make_sprite(64, y - 4.0 * PIXEL_SIZE, -0.03)
	_npc_sprite = _make_sprite(32, y, 0.0)
	_npc_sprite.texture = load(sheet_path)
	_shield_front = _make_sprite(64, y - 4.0 * PIXEL_SIZE, 0.06)
	_load_weapons()


## A hero sprite sheet (tools/cut_hero_sprites.py): square cells, one column,
## rows south, north, east, west, the figure standing on each cell's bottom
## edge. Drawn finer than the tiles (BOARD_HEIGHT tall); the NPC path does the
## rest — the same body sprite, weapon overlay and attack lunge — with one
## frame a direction, and walking steps it instead (_process).
func _setup_board(sheet_path: String, walk_rows: Array = [], actions: Dictionary = {}) -> void:
	_mode = "board"
	# The smooth look (ArtStyle): the hero's art itself at SMOOTH_DENSITY a
	# tile, filtered, soft-edged; the pixel sheet otherwise.
	var soft := ArtStyle.smooth_file(sheet_path)
	smooth = soft != ""
	var tex: Texture2D = load(soft if smooth else sheet_path)
	_body_cell = int(tex.get_height() / 4)
	_body_rows = DOLL_ROW
	# Columns past the first hold the walk cycle, on the rows that have one.
	_body_walk_frames = maxi(1, int(tex.get_width() / _body_cell) - 1)
	_walk_rows = walk_rows if _body_walk_frames > 1 else []
	# One art texel a 64th of a tile (tools/cut_hero_sprites.py cuts every
	# hero at that fineness, BOARD_HEIGHT tall): one screen pixel at zoom 2,
	# two at zoom 4 — never a fraction, so no row or column is skipped.
	var px := 1.0 / (ArtStyle.SMOOTH_DENSITY if smooth else BOARD_DENSITY)
	var grow := BOARD_HEIGHT / PACK_BODY_HEIGHT
	_hand_scale = grow
	# The shield layer sits as on the pack's people, scaled about the feet to
	# the hero's height.
	var wy := 12.0 * PIXEL_SIZE
	_shield_back = _make_sprite(64, wy, -0.03)
	_npc_sprite = _make_sprite(_body_cell, _body_cell * 0.5 * PIXEL_SIZE, 0.0)
	_npc_sprite.texture = tex
	if smooth:
		_npc_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_npc_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	_npc_sprite.pixel_size = px   # (the stockier BOARD_WIDEN build is baked into the art)
	_body_offset = _npc_sprite.offset
	# The pack's people (about a tile tall) cast a 0.62-wide shadow; a hero
	# casts one as much wider as the hero is broader than them.
	_shadow_scale = BOARD_WIDEN * BOARD_HEIGHT / 1.25
	_shield_front = _make_sprite(64, wy, 0.06)
	for s in [_shield_back, _shield_front]:
		s.pixel_size = PIXEL_SIZE * grow
	_load_weapons()
	_load_actions(actions)


## The hero's drawn actions: each sheet (its smooth twin under the smooth
## look) at the body's fineness, drawn by one more sprite.
func _load_actions(actions: Dictionary) -> void:
	for action_name in actions:
		var a: Dictionary = actions[action_name]
		var path: String = a["sheet"]
		var soft := ArtStyle.smooth_file(path) if smooth else ""
		var tex: Texture2D = load(soft if soft != "" else path)
		if tex == null:
			continue
		var entry := a.duplicate()
		entry["tex"] = tex
		entry["cell"] = int(tex.get_height() / 4)
		_actions[action_name] = entry
	if _actions.is_empty():
		return
	_action_sprite = _make_sprite(64, 0.0, 0.0)
	_action_sprite.pixel_size = _npc_sprite.pixel_size
	_action_sprite.texture_filter = _npc_sprite.texture_filter
	_action_sprite.alpha_cut = _npc_sprite.alpha_cut
	_action_sprite.visible = false


## The standard poses many cards share (Card.get_animation_action: an
## Attack card's default "attack_slash", a defensive card's "block") are the
## hero's drawn basic attack and block wherever he has them (designer,
## 2026-10-31: every card attack plays it, every block card too).
const DRAWN_ALIAS := {"attack_slash": "basic_attack", "block": "basic_block"}


## The drawn action `action` plays as ("" when none).
func _drawn_name(action: String) -> String:
	var a: String = DRAWN_ALIAS.get(action, action)
	return a if _actions.has(a) else ""


## The hero has `action` drawn for the way he faces (or for `direction`).
func has_drawn_action(action: String, direction: int = -1) -> bool:
	var d := facing if direction < 0 else direction
	var a := _drawn_name(action)
	return a != "" and _body_rows[d] in _actions[a]["rows"]


## Seconds from the start of `action` (facing `direction`) to the frame its
## blow lands on; 0 when it is not drawn that way or marks no hit.
func hit_delay(action: String, direction: int) -> float:
	if not has_drawn_action(action, direction):
		return 0.0
	var a: Dictionary = _actions[_drawn_name(action)]
	return maxf(0.0, float(a.get("hit", 1)) - 1.0) * float(a["t"])


func _load_weapons() -> void:
	## The pack's shield layer, raised on guard. (The weapon swing layers —
	## sword, axe, mace — and the held icon-pack items were deleted on
	## 2026-10-30: the designer is drawing each hero's own attack animations.)
	_shield_texture = load("%s/char_a_pONE3/7tlb/char_a_pONE3_7tlb_sh01_v01.png" % SEED)
	_shield_back.texture = _shield_texture
	_shield_front.texture = _shield_texture
	_shield_back.visible = false
	_shield_front.visible = false


## Tell the figure what it is holding (called whenever equipment changes).
## `art` is the item's own picture when it has one; it replaces the category
## icon for the categories drawn from the icon packs.
func set_weapon_kind(kind: String, has_shield: bool, art: Texture2D = null) -> void:
	_weapon_kind = kind if kind != "" else "none"
	_has_shield = has_shield


func _make_sprite(cell: int, y: float, sort: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Hard alpha cut: the sprite writes depth, so props, walls and other
	# figures sort against it per pixel instead of by node origin.
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.pixel_size = PIXEL_SIZE
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, cell, cell)
	# Feet pivot: the cell is drawn exactly where a centred sprite at height
	# `y` would sit, but the quad's origin (the point the billboard rotates
	# about) is the feet anchor on the ground. Under the pitched camera a
	# centre pivot swings the feet below the tile; this keeps them planted.
	# (An uncentered Sprite3D grows UP from its origin, so offset.y is the
	# bottom edge's height: where the centred cell's bottom used to sit.)
	s.centered = false
	s.offset = Vector2(-cell * 0.5, y / PIXEL_SIZE - cell * 0.5)
	s.position = Vector3.ZERO
	s.sorting_offset = sort
	s.shaded = false
	_rig.add_child(s)
	_sprites.append(s)
	return s


# =============================================================
# FACADE VERBS (called by Player)
# =============================================================

func play_action(action: String, direction: int = CharacterAnimator.Direction.SOUTH) -> void:
	# Taking a blow is not a turn: the hero keeps the way he faces (and any
	# swing he is in the middle of), only flashing and shaking.
	if action.begins_with("hit") or action == "stunned":
		play_hit()
		return
	set_facing(direction)
	# Bespoke per-card effects first: ActionFX supplies the signature visual
	# (icicle, fireball, flying pig, …) and we play a matching body motion.
	# The designer's drawn actions (Brad's basic attack and block, …).
	if has_drawn_action(action):
		_play(_drawn_name(action))
		return
	if _fx and ActionFX.handles(action):
		_play_body(ActionFX.body_for(action))
		_fx.play(action)
		return
	if _is_attack(action):
		# No weapon swing (deleted 2026-10-30; the designer is drawing each
		# hero's basic and card attacks): the body lunges toward the target.
		_play("attack_unarmed")
	elif action in GUARD_ACTIONS:
		_guard_fx()
		if _has_shield:
			_play("guard_shield")  # Block & co. raise the shield
	elif action in HOP_ACTIONS:
		_hop_fx()
	elif action.begins_with("hit") or action == "stunned":
		play_hit()
	elif action == "heal" or "potion" in action or "elixir" in action:
		flash(Color(0.55, 1.0, 0.55))
		_hop_fx()
	else:
		# Casts, buffs, taunts, item use, … — a readable generic "do something".
		flash(Color(1.0, 1.0, 0.8))
		_bounce_fx()


func _is_attack(action: String) -> bool:
	for token in ["attack", "swing", "slash", "slam", "shot", "barrage", "strike",
			"charge", "artery", "disarm", "assault", "choke", "steal", "trick"]:
		if token in action:
			return true
	return false


func set_walking(on: bool) -> void:
	if on == _walking:
		return
	_walking = on
	if _attacking:
		return
	_play("walk" if on else "idle")


func set_facing(direction: int) -> void:
	if direction == facing:
		return
	facing = direction
	_apply_fx_facing()
	if not _attacking:
		_play("walk" if _walking else "idle", true)
	else:
		_apply_frame()


func _apply_fx_facing() -> void:
	# Yaw the effect layer so its local +Z matches the sprite's facing.
	if not _fx:
		return
	match facing:
		CharacterAnimator.Direction.NORTH: _fx.rotation.y = PI
		CharacterAnimator.Direction.EAST: _fx.rotation.y = PI / 2.0
		CharacterAnimator.Direction.WEST: _fx.rotation.y = -PI / 2.0
		_: _fx.rotation.y = 0.0


func _forward_vec() -> Vector3:
	match facing:
		CharacterAnimator.Direction.NORTH: return Vector3(0, 0, -1)
		CharacterAnimator.Direction.EAST: return Vector3(1, 0, 0)
		CharacterAnimator.Direction.WEST: return Vector3(-1, 0, 0)
		_: return Vector3(0, 0, 1)


## Body motion played alongside an ActionFX effect (hint from ActionFX.BODY).
func _play_body(hint: String) -> void:
	match hint:
		"sword", "axe": _play("attack_unarmed")  # the weapon swing is gone (designer, 2026-10-30): a body lunge
		"guard": _guard_fx()
		"crouch": _crouch_fx()
		"hop": _hop_fx()
		"high_hop": _high_hop_fx()
		"bounce": _bounce_fx()
		"lunge", "kick": _lunge_fx()
		"weave": _weave_fx()
		"heal":
			flash(Color(0.55, 1.0, 0.55))
			_hop_fx()
		_: pass


func set_facing_from_velocity(vel: Vector3) -> void:
	if vel.length_squared() < 0.01:
		return
	if absf(vel.x) > absf(vel.z):
		set_facing(CharacterAnimator.Direction.EAST if vel.x > 0.0 else CharacterAnimator.Direction.WEST)
	else:
		set_facing(CharacterAnimator.Direction.SOUTH if vel.z > 0.0 else CharacterAnimator.Direction.NORTH)


func face_toward(world_pos: Vector3) -> void:
	set_facing_from_velocity(world_pos - global_position)


## Recolour the whole figure (multiplied in; alpha below 1 is see-through):
## Draupnir's gold echo of its bearer.
func set_tint(c: Color) -> void:
	_base_modulate = c
	_apply_modulate(_base_modulate)


func set_translucent(on: bool) -> void:
	_base_modulate.a = 0.45 if on else 1.0
	_apply_modulate(_base_modulate)


func set_highlight(enabled: bool) -> void:
	var c := _base_modulate
	if enabled:
		c = Color(c.r * 1.4, c.g * 1.4, c.b * 1.2, c.a)
	_apply_modulate(c)


## Hard two-frame flash (style guide §5): snaps on, holds ~2 frames, snaps
## off. No tween curve, no fade.
func flash(color: Color) -> void:
	if _fx_tween:
		_fx_tween.kill()
	_apply_modulate(Color(color.r * 4.0, color.g * 4.0, color.b * 4.0, _base_modulate.a))
	_fx_tween = create_tween()
	_fx_tween.tween_interval(0.07)
	_fx_tween.tween_callback(func(): _apply_modulate(_base_modulate))


func play_hit() -> void:
	# White palette-saturating flash on damage (SNES hit flash), plus shake.
	flash(Color(3.0, 3.0, 3.0))
	if _rig:
		var t := create_tween()
		t.tween_property(_rig, "position:x", 0.07, 0.05)
		t.tween_property(_rig, "position:x", -0.07, 0.08)
		t.tween_property(_rig, "position:x", 0.0, 0.06)


# Overhead feedback popups (armour gained, ring procs, heals, level-ups…).
func pop_armor_icon() -> void: _pop_text("+ARMOR", Color(0.75, 0.8, 0.95))
func pop_ring_icon() -> void: _pop_text("RING!", Color(0.55, 0.85, 1.0))
func pop_gauntlet_icon() -> void: _pop_text("GAUNTLET!", Color(0.9, 0.75, 0.4))
func pop_heart() -> void: _pop_text("+HP", Color(0.5, 1.0, 0.55))
func pop_level_up() -> void: _pop_text("LEVEL UP!", Color(1.0, 0.9, 0.4))
func pop_worm() -> void: _pop_text("WORM!", Color(0.8, 0.5, 0.8))


func _pop_text(text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = color
	label.outline_size = 8
	label.pixel_size = 0.006
	label.position = Vector3(0, 1.55, 0)
	add_child(label)
	var t := create_tween()
	t.tween_property(label, "position:y", 2.15, 0.7).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.25)
	t.tween_callback(label.queue_free)


# =============================================================
# EFFECT MOTIONS (actions the sheets have no frames for)
# =============================================================

func _guard_fx() -> void:
	# Hard one-step crouch (no scale tween on pixel art — style guide §5):
	# the whole sprite drops a couple of pixels, holds, snaps back.
	flash(Color(0.6, 0.75, 1.0))
	if _rig:
		_rig.position.y = -2.0 * PIXEL_SIZE
		var t := create_tween()
		t.tween_interval(0.35)
		t.tween_callback(func():
			if _rig:
				_rig.position.y = 0.0)


func _hop_fx() -> void:
	if _rig:
		var t := create_tween()
		t.tween_property(_rig, "position:y", 0.28, 0.14).set_ease(Tween.EASE_OUT)
		t.tween_property(_rig, "position:y", 0.0, 0.16).set_ease(Tween.EASE_IN)


func _high_hop_fx() -> void:
	# The big leap (Heroic Leap, Sky Fall, Rise…).
	if _rig:
		var t := create_tween()
		t.tween_property(_rig, "position:y", 0.6, 0.2).set_ease(Tween.EASE_OUT)
		t.tween_property(_rig, "position:y", 0.0, 0.2).set_ease(Tween.EASE_IN)


func _crouch_fx() -> void:
	# The silent version of the guard drop (channels, bows, meditation).
	if _rig:
		_rig.position.y = -2.0 * PIXEL_SIZE
		var t := create_tween()
		t.tween_interval(0.5)
		t.tween_callback(func():
			if _rig:
				_rig.position.y = 0.0)


func _lunge_fx() -> void:
	# A quick step into the facing direction and back (slams, throws, kicks).
	if _rig:
		var t := create_tween()
		t.tween_property(_rig, "position", _forward_vec() * 0.22, 0.12) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(_rig, "position", Vector3.ZERO, 0.18)


func _weave_fx() -> void:
	# Side-to-side slip (Bob and Weave).
	if _rig:
		var side := _forward_vec().cross(Vector3.UP) * 0.16
		var t := create_tween()
		t.tween_property(_rig, "position", side, 0.1)
		t.tween_property(_rig, "position", -side, 0.14)
		t.tween_property(_rig, "position", Vector3.ZERO, 0.1)


func _bounce_fx() -> void:
	if _rig:
		var t := create_tween()
		t.tween_property(_rig, "scale", Vector3(1.08, 1.08, 1.0), 0.1)
		t.tween_property(_rig, "scale", Vector3.ONE, 0.14)


# =============================================================
# FRAME ANIMATION
# =============================================================

func _play(anim: String, _force: bool = false) -> void:
	_frame_i = 0
	_clock = 0.0
	_attacking = false
	match anim:
		"idle":
			_looping = true
			_frames = [{"col": 0, "row": _body_rows[facing], "t": 1.0}]
			_hide_weapon()
		"walk":
			_looping = true
			_frames = []
			if _mode == "board":
				if _strides():
					for c in range(_body_walk_frames):
						_frames.append({"col": c + 1, "row": _body_rows[facing], "t": BOARD_WALK_TIME})
				else:
					_frames.append({"col": 0, "row": _body_rows[facing], "t": 1.0})
			else:
				for c in range(_body_walk_frames):
					_frames.append({"col": c, "row": _body_rows[facing], "t": NPC_WALK_TIME})
			_hide_weapon()
		"attack_unarmed":
			_start_attack(0)
		"guard_shield":
			_start_guard()
		_:
			if has_drawn_action(anim):
				_start_drawn_action(anim)
	_apply_frame()


## The pack's block frame (shield-bash column 1) held for a beat with the
## shield in front: what Block and the other guard cards show while a
## shield is in hand. Weapons and shields stay sheathed at every other time.
func _start_guard() -> void:
	_looping = false
	_attacking = true
	_frames = [{"col": 4, "row": DOLL_ROW[facing] + 4, "t": 0.45}]
	_show_shield = _has_shield and _shield_texture != null and _shield_back != null
	_shield_in_front = true


## A drawn action's frames, then its hold and its play back, if any.
func _start_drawn_action(action: String) -> void:
	var a: Dictionary = _actions[action]
	var row: int = _body_rows[facing]
	var n: int = a["frames"]
	_looping = false
	_attacking = true
	_show_shield = false
	_frames = []
	for c in range(n):
		_frames.append({"col": c, "row": row, "t": a["t"], "act": action})
	_frames[n - 1]["t"] = a["t"] + a.get("hold", 0.0)
	if a.has("reverse"):
		for c in range(n - 2, -1, -1):
			_frames.append({"col": c, "row": row, "t": a["reverse"], "act": action})


## An attack's four timed frames (the body lunges on the middle two); no
## weapon is drawn and the shield, if any, stays behind the body.
func _start_attack(col0: int, row_off: int = 0) -> void:
	_looping = false
	_attacking = true
	_frames = []
	for i in range(4):
		_frames.append({"col": col0 + i, "row": DOLL_ROW[facing] + row_off, "t": ATTACK_TIMES[i]})
	_show_shield = _has_shield and _shield_texture != null and _shield_back != null
	_shield_in_front = false


## A board hero walking this way has a drawn walk cycle to stride through.
func _strides() -> bool:
	return _mode == "board" and _body_rows[facing] in _walk_rows


func _hide_weapon() -> void:
	if _shield_back:
		_shield_back.visible = false
		_shield_front.visible = false
	if _npc_sprite:
		_npc_sprite.position.x = 0.0
		_npc_sprite.position.z = 0.0


func _apply_modulate(c: Color) -> void:
	for s in _sprites:
		s.modulate = c


func _process(delta: float) -> void:
	if _shadow and _rig:
		_shadow.set_airborne_height(_rig.position.y)
	if _mode == "board" and _npc_sprite:
		# Lifted along the sprite's own up (its offset, in its texels):
		# screen-up under the plan camera; the feet return to the ground row
		# every step.
		# (A drawn walk cycle carries its own stride: no step.)
		var stepping := _walking and not _attacking and not _strides()
		_step_clock = _step_clock + delta if stepping else 0.0
		var up := stepping and fmod(_step_clock * STEP_HZ, 1.0) >= 0.5
		var lift := roundf(STEP_LIFT / _npc_sprite.pixel_size) if up else 0.0
		_npc_sprite.offset = _body_offset + Vector2(0, lift)
	if _frames.is_empty():
		return
	_clock += delta
	var t: float = _frames[_frame_i]["t"]
	if _clock < t:
		return
	_clock -= t
	_frame_i += 1
	if _frame_i >= _frames.size():
		if _looping:
			_frame_i = 0
		else:
			_play("walk" if _walking else "idle")
			return
	_apply_frame()


func _apply_frame() -> void:
	if _frames.is_empty():
		return
	_frame_i = clampi(_frame_i, 0, _frames.size() - 1)
	var f: Dictionary = _frames[_frame_i]
	if _apply_drawn_action(f):
		return
	if _attacking:
		var row: int = f["row"]
		var rect := Rect2(f["col"] * 64, row * 64, 64, 64)
		if _shield_back:
			# The shield rides behind the body except when it is raised (guard).
			_shield_front.visible = _show_shield and _shield_in_front
			_shield_back.visible = _show_shield and not _shield_in_front
			_shield_front.region_rect = rect
			_shield_back.region_rect = rect
		# The bodies have no attack pose: hold the stand frame and lunge a
		# couple of pixels on the active swing frames to sell the swing.
		_npc_sprite.region_rect = Rect2(0, _body_rows[facing] * _body_cell, _body_cell, _body_cell)
		var lunge := Vector3.ZERO
		if f["col"] % 4 in [1, 2]:
			match facing:
				CharacterAnimator.Direction.NORTH: lunge = Vector3(0, 0, -0.1)
				CharacterAnimator.Direction.SOUTH: lunge = Vector3(0, 0, 0.1)
				CharacterAnimator.Direction.EAST: lunge = Vector3(0.1, 0, 0)
				CharacterAnimator.Direction.WEST: lunge = Vector3(-0.1, 0, 0)
		_npc_sprite.position.x = lunge.x
		_npc_sprite.position.z = lunge.z
		return
	_npc_sprite.region_rect = Rect2(f["col"] * _body_cell, f["row"] * _body_cell, _body_cell, _body_cell)


## Show a drawn action's frame (and hide the body), or put the body back.
## True when `f` is a drawn action's frame.
func _apply_drawn_action(f: Dictionary) -> bool:
	if not f.has("act"):
		if _action_sprite and _action_sprite.visible:
			_action_sprite.visible = false
			_npc_sprite.visible = true
		return false
	var a: Dictionary = _actions[f["act"]]
	var cell: int = a["cell"]
	_action_sprite.texture = a["tex"]
	_action_sprite.region_rect = Rect2(f["col"] * cell, f["row"] * cell, cell, cell)
	# Uncentred: offset.y is the cell's bottom edge, ACTION_FLOOR below the feet.
	_action_sprite.offset = Vector2(-cell * 0.5, -float(cell) / ACTION_FLOOR)
	_action_sprite.visible = true
	_npc_sprite.visible = false
	if _shield_back:
		_shield_back.visible = false
		_shield_front.visible = false
	return true
