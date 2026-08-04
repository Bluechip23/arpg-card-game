class_name SpriteFigure
extends Node3D

## Billboard Sprite3D character for battle, drawing the Mana Seed sprite packs
## (see scripts/demo/sprite_character.gd for the 2D demo equivalent).
##
## Drop-in visual replacement for CharacterFigure: exposes the same verbs the
## Player facade calls (play_action, set_walking, set_facing_from_velocity,
## face_toward, set_translucent, set_highlight, pop_*). Card actions the sprite
## sheets can't express fall back to a small set of readable motions
## (attack swing, guard flash, hop, cast flash) rather than bespoke animation.
##
## Brad/Cory/Stephen render their picked NPC models (knight/merchant/guard) —
## those sheets only have walk frames, so attacks overlay the base pack's
## weapon layer (swing + swoosh) with a small body lunge. Jeremy/Ryan render
## as character-base paper dolls (body + outfit + hair) with real attack poses.

const SEED := "res://assets/sprites/SeedcharacterBase"

## Which sprites each playable character uses. NPC entries use the raw NPC
## sheet; doll entries are outfit/hair (and optional hat) layered on the
## character base. A "gen:" prefix resolves to assets/sprites/generated/
## (recolored / edited sheets baked from the pack sources).
const ROSTER := {
	"Brad": {"npc": "res://assets/sprites/NPCpackage2/npc knight v01.png"},
	"Cory": {"npc": "res://assets/sprites/NPCpackage1/npc merchant A v01.png"},
	"Stephen": {"npc": "res://assets/sprites/NPCpackage2/npc guard v01.png"},
	"Jeremy": {"outfit": "gen:fstr_jeremy", "hair": "bob1_v11"},  # barefoot wanderer
	"Ryan": {"outfit": "gen:fstr_ryan", "hair": "dap1_v13", "hat": "gen:pfht_ryan"},  # black leathers + hood
}

const GENERATED := "res://assets/sprites/generated"


## Resolve a paper-doll layer sheet path: "gen:<name>" comes from the baked
## generated sheets, anything else from the pack's standard folders.
static func _layer_path(page: String, folder: String, code: String, spec: String) -> String:
	if spec.begins_with("gen:"):
		return "%s/char_a_%s_%s_%s.png" % [GENERATED, page, code, spec.substr(4)]
	return "%s/char_a_%s/%s/char_a_%s_%s_%s.png" % [SEED, page, folder, page, code, spec]

# Sheet rows per facing (CharacterAnimator.Direction order: S, N, E, W).
const DOLL_ROW := [0, 1, 2, 3]   # base pack runs S,N,E,W
const NPC_ROW := [0, 2, 1, 3]    # NPC packs run S,E,N,W

const ATTACK_TIMES := [0.16, 0.065, 0.065, 0.2]
const WALK_TIME := 0.135
const NPC_WALK_TIME := 0.18
const PIXEL_SIZE := 0.034

# pONE3 cells (row, col) where the weapon draws in front of the body,
# from the pack's layer-order guide.
const WEAPON_FRONT_CELLS := [Vector2i(2, 1), Vector2i(3, 1)]

## Card actions that read as heavy chops — these swing the axe; every other
## attack-flavoured action swings the sword.
const AXE_ACTIONS := ["heavy_swing", "attack_heavy", "shed_weight", "wear_down"]
const GUARD_ACTIONS := ["block", "defend", "parry", "cover", "barricade", "harden",
		"hold_the_line", "hunker_down", "approach_stance", "magic_barrier", "vengeful_shield"]
const HOP_ACTIONS := ["roll", "dodge", "bob_and_weave", "heroic_leap", "rise"]

var facing: int = CharacterAnimator.Direction.SOUTH

var _mode := "doll"
var _sprites: Array[Sprite3D] = []       # every sprite (for modulate passes)
var _doll_layers: Array[Sprite3D] = []   # body, outfit, hair
var _npc_sprite: Sprite3D = null
var _weapon_back: Sprite3D = null
var _weapon_front: Sprite3D = null
var _weapon_textures := {}
var _doll_page_textures := {}

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


func setup(character_name: String, _sprite_path: String = "") -> void:
	# Re-entrant: callers like the character sheet re-setup the same figure
	# when paging between party members, so tear down any previous build.
	if _rig and is_instance_valid(_rig):
		_rig.queue_free()
	_sprites.clear()
	_doll_layers.clear()
	_npc_sprite = null
	_weapon_back = null
	_weapon_front = null
	_weapon_textures.clear()
	_doll_page_textures.clear()
	_frames = []
	var cfg: Dictionary = ROSTER.get(character_name, ROSTER["Brad"])
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	if cfg.has("npc"):
		_setup_npc(cfg["npc"])
	else:
		_setup_doll(cfg["outfit"], cfg["hair"], cfg.get("hat", ""))
	# Contact shadow lives OUTSIDE the rig: hops/knockback move the rig, the
	# shadow stays on the ground and shrinks with height (see _process).
	var old_shadow := get_node_or_null("Shadow")
	if old_shadow:
		old_shadow.queue_free()
	_shadow = BlobShadow.attach(self, 0.62)
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


func _setup_doll(outfit: String, hair: String, hat: String = "") -> void:
	_mode = "doll"
	for page in ["p1", "pONE3"]:
		var paths := [
			"%s/char_a_%s/char_a_%s_0bas_humn_v01.png" % [SEED, page, page],
			_layer_path(page, "1out", "1out", outfit),
			_layer_path(page, "4har", "4har", hair),
		]
		if hat != "":
			paths.append(_layer_path(page, "5hat", "5hat", hat))
		var texs: Array = []
		for p in paths:
			texs.append(load(p))
		_doll_page_textures[page] = texs
	# Doll body pixels sit with feet at y=44 of the 64px cell — 12px below the
	# cell centre — so the centred sprite lifts 12px for feet to touch ground.
	var y := 12.0 * PIXEL_SIZE
	var layer_count: int = _doll_page_textures["p1"].size()
	_weapon_back = _make_sprite(64, y, -0.02)
	for i in range(layer_count):
		_doll_layers.append(_make_sprite(64, y, 0.01 * i))
	_weapon_front = _make_sprite(64, y, 0.05)
	_load_weapons()


func _setup_npc(sheet_path: String) -> void:
	_mode = "npc"
	# NPC bodies fill their 32px cell to the bottom edge.
	var y := 16.0 * PIXEL_SIZE
	_weapon_back = _make_sprite(64, y - 4.0 * PIXEL_SIZE, -0.02)
	_npc_sprite = _make_sprite(32, y, 0.0)
	_npc_sprite.texture = load(sheet_path)
	_weapon_front = _make_sprite(64, y - 4.0 * PIXEL_SIZE, 0.05)
	_load_weapons()


func _load_weapons() -> void:
	_weapon_textures["sword"] = load("%s/char_a_pONE3/6tla/char_a_pONE3_6tla_sw01_v01.png" % SEED)
	_weapon_textures["axe"] = load("%s/char_a_pONE3/6tla/char_a_pONE3_6tla_ax01_v01.png" % SEED)
	_weapon_back.visible = false
	_weapon_front.visible = false


func _make_sprite(cell: int, y: float, sort: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.pixel_size = PIXEL_SIZE
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, cell, cell)
	s.position = Vector3(0, y, 0)
	s.sorting_offset = sort
	s.shaded = false
	_rig.add_child(s)
	_sprites.append(s)
	return s


# =============================================================
# FACADE VERBS (called by Player)
# =============================================================

func play_action(action: String, direction: int = CharacterAnimator.Direction.SOUTH) -> void:
	set_facing(direction)
	# Bespoke per-card effects first: ActionFX supplies the signature visual
	# (icicle, fireball, flying pig, …) and we play a matching body motion.
	if _fx and ActionFX.handles(action):
		_play_body(ActionFX.body_for(action))
		_fx.play(action)
		return
	if action in AXE_ACTIONS:
		_play("attack_axe")
	elif _is_attack(action):
		_play("attack_sword")
	elif action in GUARD_ACTIONS:
		_guard_fx()
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
		"sword": _play("attack_sword")
		"axe": _play("attack_axe")
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
			if _mode == "doll":
				_set_doll_page("p1")
				_frames = [{"col": 0, "row": DOLL_ROW[facing], "t": 1.0}]
			else:
				_frames = [{"col": 0, "row": NPC_ROW[facing], "t": 1.0}]
			_hide_weapon()
		"walk":
			_looping = true
			_frames = []
			if _mode == "doll":
				_set_doll_page("p1")
				for c in range(6):
					_frames.append({"col": c, "row": 4 + DOLL_ROW[facing], "t": WALK_TIME})
			else:
				for c in range(4):
					_frames.append({"col": c, "row": NPC_ROW[facing], "t": NPC_WALK_TIME})
			_hide_weapon()
		"attack_sword":
			_start_attack("sword", 0)
		"attack_axe":
			_start_attack("axe", 4)
	_apply_frame()


func _start_attack(weapon: String, col0: int) -> void:
	_looping = false
	_attacking = true
	if _mode == "doll":
		_set_doll_page("pONE3")
	_frames = []
	for i in range(4):
		_frames.append({"col": col0 + i, "row": DOLL_ROW[facing], "t": ATTACK_TIMES[i]})
	_weapon_back.texture = _weapon_textures[weapon]
	_weapon_front.texture = _weapon_textures[weapon]


func _set_doll_page(page: String) -> void:
	var texs: Array = _doll_page_textures[page]
	for i in range(_doll_layers.size()):
		_doll_layers[i].texture = texs[i]


func _hide_weapon() -> void:
	if _weapon_back:
		_weapon_back.visible = false
		_weapon_front.visible = false
	if _npc_sprite:
		_npc_sprite.position.x = 0.0
		_npc_sprite.position.z = 0.0


func _apply_modulate(c: Color) -> void:
	for s in _sprites:
		s.modulate = c


func _process(delta: float) -> void:
	if _shadow and _rig:
		_shadow.set_airborne_height(_rig.position.y)
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
	if _attacking:
		var row: int = DOLL_ROW[facing]
		var in_front := Vector2i(row, f["col"]) in WEAPON_FRONT_CELLS
		_weapon_front.visible = in_front
		_weapon_back.visible = not in_front
		var rect := Rect2(f["col"] * 64, row * 64, 64, 64)
		_weapon_front.region_rect = rect
		_weapon_back.region_rect = rect
		if _mode == "doll":
			for s in _doll_layers:
				s.region_rect = rect
		else:
			# NPC sheets have no attack pose: hold the stand frame and lunge a
			# couple of pixels on the active swing frames to sell the swing.
			_npc_sprite.region_rect = Rect2(0, NPC_ROW[facing] * 32, 32, 32)
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
	if _mode == "doll":
		var rect := Rect2(f["col"] * 64, f["row"] * 64, 64, 64)
		for s in _doll_layers:
			s.region_rect = rect
	else:
		_npc_sprite.region_rect = Rect2(f["col"] * 32, f["row"] * 32, 32, 32)
