class_name SpriteCharacter
extends Node2D

## A Mana Seed–style 2D sprite character for the sprite viewer demo.
##
## Two modes:
##  - "doll": the Mana Seed character base paper doll — body, outfit and hair
##    layers driven in lockstep across pages (p1 for stand/walk, pONE3 for the
##    one-handed attacks), with a weapon layer (sword/axe) on top during attacks.
##  - "npc": a single 32x32 NPC sheet (knight/merchant/guard) for stand/walk.
##    NPC sheets have no attack frames, so attacks are mimicked by overlaying
##    the base pack's weapon layer (which carries the swing + swoosh) anchored
##    to the NPC's hands, plus a small body lunge.

signal attack_finished

enum Facing { SOUTH, NORTH, EAST, WEST }

const SEED := "res://assets/sprites/SeedcharacterBase"

# Sheet rows per facing. The character base runs S,N,E,W; NPC packs run S,E,N,W.
const DOLL_ROW := {Facing.SOUTH: 0, Facing.NORTH: 1, Facing.EAST: 2, Facing.WEST: 3}
const NPC_ROW := {Facing.SOUTH: 0, Facing.EAST: 1, Facing.NORTH: 2, Facing.WEST: 3}

# Attack frame timings from the pack's guide ("attacks look good at 160/65/65/200ms").
const ATTACK_TIMES := [0.16, 0.065, 0.065, 0.2]
const WALK_TIME := 0.135
const NPC_WALK_TIME := 0.18

# pONE3 cells where the weapon draws IN FRONT of the body, from the pack's
# layer-order guide (row, col). Everything else on the slash rows goes behind.
const WEAPON_FRONT_CELLS := [Vector2i(2, 1), Vector2i(3, 1)]

var facing: int = Facing.SOUTH
var current_anim: String = "idle"

var _mode := "doll"
var _doll_layers: Array[Sprite2D] = []   # body, outfit, hair (z ascending)
var _npc_sprite: Sprite2D = null
var _weapon_back: Sprite2D = null   # weapon drawn behind the body
var _weapon_front: Sprite2D = null  # weapon drawn in front of the body
var _weapon_textures := {}          # "sword"/"axe" -> Texture2D (pONE3 6tla sheet)
var _doll_page_textures := {}       # "p1"/"pONE3" -> Array[Texture2D] per layer

var _frames: Array = []      # current animation: Array of {col:int, row:int, t:float}
var _frame_i := 0
var _clock := 0.0
var _looping := true
var _attack_weapon := ""     # "" when not attacking
var _npc_lunge := Vector2.ZERO


## Build a paper-doll character. outfit like "fstr_v05" (or "gen:<name>" for a
## sheet baked into assets/sprites/generated/), hair like "dap1_v13", optional
## hat like "gen:pfht_ryan".
func setup_doll(outfit: String, hair: String, hat: String = "", base_variant: String = "v01") -> void:
	_mode = "doll"
	for page in ["p1", "pONE3"]:
		var paths := [
			"%s/char_a_%s/char_a_%s_0bas_humn_%s.png" % [SEED, page, page, base_variant],
			SpriteFigure._layer_path(page, "1out", "1out", outfit),
			SpriteFigure._layer_path(page, "4har", "4har", hair),
		]
		if hat != "":
			paths.append(SpriteFigure._layer_path(page, "5hat", "5hat", hat))
		var texs: Array = []
		for p in paths:
			texs.append(load(p))
		_doll_page_textures[page] = texs

	_weapon_back = _make_sprite(8, 8, -1)
	add_child(_weapon_back)
	for i in range(_doll_page_textures["p1"].size()):
		var s := _make_sprite(8, 8, i)
		add_child(s)
		_doll_layers.append(s)
	_weapon_front = _make_sprite(8, 8, 10)
	add_child(_weapon_front)

	_load_weapons()
	play("idle")


## Build an NPC-sheet character (knight/merchant/guard). sheet_path is the
## 128x256 NPC png; the weapon overlay mimics attacks the sheet doesn't have.
func setup_npc(sheet_path: String) -> void:
	_mode = "npc"
	_weapon_back = _make_sprite(8, 8, -1)
	add_child(_weapon_back)
	_npc_sprite = _make_sprite(4, 8, 0)
	_npc_sprite.texture = load(sheet_path)
	add_child(_npc_sprite)
	_weapon_front = _make_sprite(8, 8, 10)
	add_child(_weapon_front)
	# Anchor the 64px weapon grid so the base body's feet line (y=44 in its
	# cell) sits on the NPC's feet line (y=32 in its cell): 4px down from center.
	_weapon_back.position = Vector2(0, 4)
	_weapon_front.position = Vector2(0, 4)

	_load_weapons()
	play("idle")


func _load_weapons() -> void:
	_weapon_textures["sword"] = load("%s/char_a_pONE3/6tla/char_a_pONE3_6tla_sw01_v01.png" % SEED)
	_weapon_textures["axe"] = load("%s/char_a_pONE3/6tla/char_a_pONE3_6tla_ax01_v01.png" % SEED)
	_weapon_back.visible = false
	_weapon_front.visible = false


func _make_sprite(hframes: int, vframes: int, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.hframes = hframes
	s.vframes = vframes
	s.z_index = z
	s.z_as_relative = true
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s


func set_facing(dir: int) -> void:
	if facing == dir:
		return
	facing = dir
	# Re-enter the current animation so rows update; attacks keep playing.
	if _attack_weapon == "":
		play(current_anim)
	else:
		_apply_frame()


## anim: "idle", "walk", "attack_sword", "attack_axe".
func play(anim: String) -> void:
	current_anim = anim
	_frame_i = 0
	_clock = 0.0
	_attack_weapon = ""
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


## Sword uses slash 1 (cols 0-3), axe uses slash 2 (cols 4-7) of page pONE3.
func _start_attack(weapon: String, col0: int) -> void:
	_looping = false
	_attack_weapon = weapon
	if _mode == "doll":
		_set_doll_page("pONE3")
	_frames = []
	for i in range(4):
		_frames.append({"col": col0 + i, "row": DOLL_ROW[facing], "t": ATTACK_TIMES[i]})
	_weapon_back.texture = _weapon_textures[weapon]
	_weapon_front.texture = _weapon_textures[weapon]
	if _mode == "npc":
		_npc_lunge = _facing_vector() * 3.0


func _facing_vector() -> Vector2:
	match facing:
		Facing.NORTH: return Vector2.UP
		Facing.EAST: return Vector2.RIGHT
		Facing.WEST: return Vector2.LEFT
	return Vector2.DOWN


func _set_doll_page(page: String) -> void:
	var texs: Array = _doll_page_textures[page]
	for i in range(_doll_layers.size()):
		_doll_layers[i].texture = texs[i]


func _hide_weapon() -> void:
	_weapon_back.visible = false
	_weapon_front.visible = false
	_npc_lunge = Vector2.ZERO
	if _npc_sprite:
		_npc_sprite.position = Vector2.ZERO


func _process(delta: float) -> void:
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
			var was_attack := _attack_weapon != ""
			play("idle")
			if was_attack:
				attack_finished.emit()
			return
	_apply_frame()


func _apply_frame() -> void:
	if _frames.is_empty():
		return
	_frame_i = clampi(_frame_i, 0, _frames.size() - 1)
	var f: Dictionary = _frames[_frame_i]
	# Attacks always index the 64px pONE3 grid; row follows the doll order
	# even in NPC mode (the weapon sheets belong to the base pack).
	if _attack_weapon != "":
		var row: int = DOLL_ROW[facing]
		var cell := Vector2i(row, f["col"])
		var in_front := cell in WEAPON_FRONT_CELLS
		_weapon_front.visible = in_front
		_weapon_back.visible = not in_front
		var wframe: int = row * 8 + f["col"]
		_weapon_front.frame = wframe
		_weapon_back.frame = wframe
		if _mode == "doll":
			for s in _doll_layers:
				s.frame = wframe
		else:
			# The NPC sheet has no attack pose: hold the stand frame, add a
			# small lunge on the active swing frames so the body sells it.
			_npc_sprite.frame = NPC_ROW[facing] * 4
			var lunging: bool = f["col"] % 4 in [1, 2]
			_npc_sprite.position = _npc_lunge if lunging else Vector2.ZERO
		return
	# Movement/idle frames come from each mode's own sheet grid.
	if _mode == "doll":
		for s in _doll_layers:
			s.frame = f["row"] * 8 + f["col"]
	else:
		_npc_sprite.frame = f["row"] * 4 + f["col"]
