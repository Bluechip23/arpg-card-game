class_name SpriteEnemyFigure
extends Node3D

## Billboard Sprite3D enemy visuals.
##
## Three sprite sources:
##  - Craftpix top-down packs (assets/sprites/craftpix/<pack>/<Variant>/
##    Without_shadow/): one sheet per animation (Idle, Walk, Run, Attack,
##    Hurt, Death), square cells (64 or 128), four direction rows. These get
##    REAL frames for everything — walk cycles, attack swings, hit reactions
##    and a death animation — drawn for the game's fixed top-down camera
##    (CameraView). Preferred wherever a pack matches a kind.
##  - MonsterKit battlers (assets/sprites/MonsterKit — 24 static 64x64
##    battlers). Static art, so all motion is procedural (bob, lunge, shake).
##    Kinds without a bespoke battler reuse one with a tint/scale variation
##    (e.g. werewolf = big dark wolf, bone dragon = big pale dragon whelp).
##  - NPC pack sheets (assets/sprites/NPCpackage1/2 — 32px, 4-direction
##    4-frame walk cycles) for humanoid enemies: mages, vampire, succubus,
##    cherub, archangel... Real directional walk frames plus the procedural
##    attack/hit motion.
##
## Drop-in visual replacement for EnemyFigure on mapped kinds; unmapped kinds
## (fire goblin warband bosses etc. that need bespoke art) keep the
## procedural mesh figure.

const SHEET := "res://assets/sprites/MonsterKit/monster battler set.png"
const NPC1 := "res://assets/sprites/NPCpackage1"
const NPC2 := "res://assets/sprites/NPCpackage2"
const GEN := "res://assets/sprites/generated/monsters"
const CP := "res://assets/sprites/craftpix"

## Direction row order of the Craftpix packs, top row first: F = front
## (SOUTH, faces the camera), B = back (NORTH), L = WEST, R = EAST. Every
## pack surveyed so far (idle frame 0 per row, docs/ASSET_PACKS.md) uses the
## same F,B,L,R order; the map stays per pack so an exception is one line.
const CP_ROWS := {
	"giant_rat": "FBLR",
	"lich": "FBLR",
	"demons": "FBLR",
	"golem": "FBLR",
	"ghost": "FBLR",
	"gnolls": "FBLR",
	"zombie": "FBLR",
	"lizardmen": "FBLR",
	"slime": "FBLR",
	"swordsman_lvl4_6": "FBLR",
	"skeletons": "FBLR",
	"goblins": "FBLR",
}
## Frames per second per Craftpix animation. One-shots (Attack, Hurt, Death)
## return to Idle/Walk when they finish; Death holds its last frame.
const CP_FPS := {"Idle": 5.0, "Walk": 8.0, "Run": 10.0, "Attack": 12.0, "Hurt": 12.0, "Death": 10.0}
const CP_ONESHOT := ["Attack", "Hurt", "Death"]

# NPC sheets run S,W,N,E top to bottom (battle uses CharacterAnimator order S,N,E,W).
const NPC_ROW := [0, 2, 1, 3]  # NPC packs run S,E,N,W
const NPC_WALK_TIME := 0.18

## kind -> config.
## Craftpix animated:  {cp: "<pack>/<Variant>", tint?: Color, scale?: float}
## MonsterKit battler: {cell: Vector2i(col,row), tint?: Color, scale?: float}
## Generated battler:  {tex: "<name>", tint?: Color, scale?: float}
## NPC humanoid:       {npc: "<path>", tint?: Color, scale?: float}
const KINDS := {
	# --- direct battler matches ---
	"sludge": {"cp": "slime/Slime1", "scale": 1.6, "tint": Color(0.6, 1.0, 0.5)},  # ice slime recoloured to sewer ooze
	"mind_eater": {"cell": Vector2i(1, 0)},
	"pipe_crawler": {"cell": Vector2i(2, 0)},
	"crypt_crawler": {"cell": Vector2i(3, 0)},
	"swarm": {"cell": Vector2i(4, 0)},
	"giant_hawk": {"cell": Vector2i(6, 0)},
	"screecher": {"cell": Vector2i(7, 0)},
	"giant_beaver": {"cell": Vector2i(0, 1), "tint": Color(0.95, 0.85, 0.75)},
	"mini_bear": {"cell": Vector2i(1, 1)},
	"wolf": {"cell": Vector2i(3, 1)},
	"coyote": {"cell": Vector2i(3, 1), "tint": Color(1.1, 1.0, 0.8)},
	"djinn": {"cell": Vector2i(4, 1)},
	"specter": {"cp": "ghost/Ghost1", "scale": 1.2},
	"wererabbit": {"cell": Vector2i(7, 1)},
	"skeleton": {"cp": "skeletons/Skeleton1", "scale": 1.15},
	"treant": {"cell": Vector2i(5, 2), "scale": 1.25},
	"consumed": {"cell": Vector2i(6, 2)},
	"sewer_croc": {"cell": Vector2i(7, 2)},
	# --- generated sprites (drawn/derived in our pipeline, palette-conformant) ---
	"rat": {"cp": "giant_rat/Rat1"},
	"archer_rat": {"cp": "giant_rat/Rat1", "tint": Color(0.85, 0.78, 0.7)},
	"rat_king": {"cp": "giant_rat/Rat3", "scale": 1.7, "tint": Color(1.05, 0.95, 0.85)},
	"fire_goblin_soldier": {"cp": "goblins/Goblin2", "scale": 1.1, "tint": Color(1.1, 0.9, 0.8)},
	"fire_goblin_mage": {"cp": "goblins/Goblin1", "scale": 1.1, "tint": Color(1.15, 0.85, 0.7)},
	"fire_goblin_shaman": {"cp": "goblins/Goblin3", "scale": 1.2, "tint": Color(1.1, 0.9, 0.8)},
	"armored_troll": {"tex": "armored_troll", "scale": 1.2},
	"ice_troll": {"tex": "ice_troll", "scale": 1.2},
	"granite_colossus": {"cp": "golem/Golem1", "scale": 1.6},
	"grave_titan": {"cp": "golem/Golem2", "scale": 1.35, "tint": Color(0.9, 0.92, 0.88)},
	"inflamed_minotaur": {"tex": "inflamed_minotaur", "scale": 1.25},
	"demon": {"cp": "demons/Demon1", "scale": 0.85},
	"pit_fiend": {"cp": "demons/Demon3"},
	"bugbear": {"cp": "gnolls/Gnoll2", "scale": 1.2},
	"ifrit": {"cp": "demons/Demon2", "scale": 0.9, "tint": Color(1.2, 0.8, 0.55)},
	"snow_wraith": {"cp": "ghost/Ghost2", "scale": 1.2, "tint": Color(0.85, 0.95, 1.15)},
	"hydra": {"tex": "hydra", "scale": 1.4},
	"white_manticore": {"tex": "white_manticore", "scale": 1.3},
	# --- battler variations where the species genuinely matches ---
	"large_bear": {"tex": "large_bear", "scale": 1.45},
	"bone_dragon": {"tex": "bone_dragon", "scale": 1.6},
	"wyvern": {"cell": Vector2i(7, 2), "tint": Color(0.9, 0.75, 1.05), "scale": 1.35},
	"cerberus": {"cell": Vector2i(3, 1), "tint": Color(0.85, 0.5, 0.45), "scale": 1.5},
	"werewolf": {"cell": Vector2i(3, 1), "tint": Color(0.6, 0.6, 0.68), "scale": 1.25},
	"sabertooth": {"cell": Vector2i(3, 1), "tint": Color(1.05, 0.95, 0.75), "scale": 1.2},
	"weregoat": {"cp": "gnolls/Gnoll3", "scale": 1.1, "tint": Color(0.85, 0.85, 0.9)},
	"roc": {"cell": Vector2i(6, 0), "scale": 1.6},
	"ash_harpy": {"cell": Vector2i(6, 0), "tint": Color(0.65, 0.6, 0.65)},
	"magma_spider": {"cell": Vector2i(3, 0), "tint": Color(1.35, 0.75, 0.6)},
	# (Every roster kind now has a sprite; ART_TODO.md still tracks hand-drawn
	# replacements for the generated first-pass battlers above.)
	# --- NPC-pack humanoids (real 4-direction walk frames) ---
	"ice_mage": {"npc": NPC1 + "/npc mystic A v01.png", "tint": Color(0.75, 0.9, 1.25)},
	"fire_mage": {"npc": NPC1 + "/npc mystic A v01.png", "tint": Color(1.25, 0.7, 0.55)},
	"spark_mage": {"npc": NPC1 + "/npc mystic A v01.png", "tint": Color(1.2, 1.15, 0.6)},
	"air_mage": {"npc": NPC1 + "/npc mystic A v01.png", "tint": Color(1.1, 1.1, 1.15)},
	"earth_mage": {"npc": NPC1 + "/npc mystic A v01.png", "tint": Color(0.9, 1.0, 0.7)},
	"necromancer": {"cp": "lich/Lich2", "scale": 1.1},
	"spirit_collector": {"cp": "lich/Lich1", "tint": Color(0.8, 0.9, 1.15)},
	"vampire": {"npc": NPC2 + "/npc dandy v01.png", "tint": Color(0.85, 0.78, 0.88)},
	"zombie": {"cp": "zombie/Zombie1", "scale": 1.25},
	"infected_hunter": {"cp": "zombie/Zombie3", "scale": 1.3, "tint": Color(0.9, 1.0, 0.85)},
	"succubus": {"npc": NPC1 + "/npc dancer A v01.png", "tint": Color(1.15, 0.7, 0.9)},
	"cherub": {"npc": NPC1 + "/npc baby A v01.png", "tint": Color(1.15, 1.1, 0.9)},
	"corrupted_archangel": {"npc": NPC1 + "/npc king A v01.png", "tint": Color(0.75, 0.6, 0.9), "scale": 1.2},
}

# Uniform texel density across every billboard in the game (style guide §1).
const PIXEL_SIZE := 0.034

## Kinds whose battler art already contains a painted contact shadow
## (the flyers) — these must not get a second blob shadow.
const PAINTED_SHADOW_KINDS := ["swarm", "giant_hawk", "roc", "ash_harpy",
		"screecher", "djinn", "specter", "snow_wraith"]

var _sprite: Sprite3D = null
var _rig: Node3D = null
var _tint := Color.WHITE
var _highlighted := false
var _walking := false
var _time := 0.0
var _facing_x := -1.0    # battlers are drawn facing left; flip for east
var _npc_mode := false
var _npc_facing := 0     # CharacterAnimator.Direction
var _walk_clock := 0.0
var _walk_frame := 0
var _fx_tween: Tween = null
var _base_y := 26.0 * PIXEL_SIZE

# Craftpix animated mode
var _cp_mode := false
var _cp_cell := 64
var _cp_rows := "FBLR"
var _cp_sheets := {}        # anim name -> Texture2D
var _cp_anim := "Idle"
var _cp_frame := 0
var _cp_clock := 0.0
var _cp_dir: int = CharacterAnimator.Direction.SOUTH
var _cp_dead := false


static func supports(kind: String) -> bool:
	return KINDS.has(kind)


func setup(kind: String) -> void:
	var cfg: Dictionary = KINDS.get(kind, KINDS["wolf"])
	_tint = cfg.get("tint", Color.WHITE)
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	_sprite = Sprite3D.new()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD  # writes depth: per-pixel sorting vs props/characters
	_sprite.region_enabled = true
	_sprite.shaded = false
	if cfg.has("cp"):
		_setup_craftpix(cfg["cp"])
	elif cfg.has("npc"):
		_npc_mode = true
		_sprite.texture = load(cfg["npc"])
		_sprite.pixel_size = PIXEL_SIZE
		_sprite.region_rect = Rect2(0, 0, 32, 32)
	elif cfg.has("tex"):
		# Baked battler recolor / generated sprite (single 64x64 cell).
		_sprite.texture = load("res://assets/sprites/generated/monsters/%s.png" % cfg["tex"])
		_sprite.pixel_size = PIXEL_SIZE
		_sprite.region_rect = Rect2(0, 0, 64, 64)
	else:
		_sprite.texture = load(SHEET)
		_sprite.pixel_size = PIXEL_SIZE
		var cell: Vector2i = cfg["cell"]
		_sprite.region_rect = Rect2(cell.x * 64, cell.y * 64, 64, 64)
	# Ground precisely: pivot the sprite at its FEET. A centred billboard
	# rotates about the middle of the art, so under the pitched battle camera
	# its bottom edge swings below the ground anchor and the creature reads as
	# sunk into the tile (or floating, from the other side). Anchoring the
	# quad at the art's lowest opaque row (feet / painted shadow line) keeps
	# that row glued to the tile whatever the camera angle — the enemy sits
	# on the ground and its blob shadow.
	# (An uncentered Sprite3D grows UP from its origin: offset.y is the height
	# of the art's bottom edge above the pivot, so the rows below the ground
	# line — the padding under the feet / painted shadow — hang below it.)
	_sprite.centered = false
	_sprite.offset = Vector2(-_sprite.region_rect.size.x * 0.5,
			-(_sprite.region_rect.size.y - _measure_ground_rows()))
	_base_y = 0.0
	_sprite.position = Vector3(0, _base_y, 0)
	var s: float = cfg.get("scale", 1.0)
	_rig.scale = Vector3(s, s, s)
	_rig.add_child(_sprite)
	_sprite.modulate = _tint
	# Contact shadow (style guide §4). Inside the rig so it scales with the
	# creature and follows attack lunges; the rig never moves vertically.
	if not kind in PAINTED_SHADOW_KINDS:
		var body_w := 40.0 * _sprite.pixel_size  # typical drawn battler width
		if _cp_mode:
			body_w = _measure_body_width() * _sprite.pixel_size
		BlobShadow.attach(_rig, body_w * 0.7)


## Load a Craftpix pack variant: every animation sheet it ships, cell size
## from the sheet height (4 direction rows), row order from CP_ROWS.
func _setup_craftpix(spec: String) -> void:
	_cp_mode = true
	var pack := spec.get_slice("/", 0)
	var variant := spec.get_slice("/", 1)
	_cp_rows = CP_ROWS.get(pack, "FBLR")
	var folder := "%s/%s/%s/Without_shadow" % [CP, pack, variant]
	for anim in ["Idle", "Walk", "Run", "Attack", "Hurt", "Death"]:
		var tex := _cp_load_sheet(folder, variant, anim)
		if tex:
			_cp_sheets[anim] = tex
	var idle: Texture2D = _cp_sheets.get("Idle")
	assert(idle != null, "Craftpix pack %s has no Idle sheet" % spec)
	_cp_cell = int(idle.get_height() / 4)
	_sprite.texture = idle
	_sprite.pixel_size = PIXEL_SIZE
	_sprite.region_rect = Rect2(0, _cp_row(_cp_dir) * _cp_cell, _cp_cell, _cp_cell)


## Sheet file for an animation, tolerating the packs' naming slips: the
## swordsman's lowercase `attack`, a variant-less `Gnoll_Death`, and the
## goblins' prefix-less `Idle0` / `Idle` / `Run_attack` names.
static func _cp_load_sheet(folder: String, variant: String, anim: String) -> Texture2D:
	var stem := variant.rstrip("0123456789")
	var lower := anim.to_lower()
	for name in ["%s_%s" % [variant, anim], "%s_%s" % [variant, lower], "%s_%s" % [stem, anim],
			anim, anim + "0", lower, lower + "0", anim.capitalize().replace(" ", "_")]:
		var path := "%s/%s_without_shadow.png" % [folder, name]
		if ResourceLoader.exists(path):
			return load(path)
	return null


func _cp_row(direction: int) -> int:
	var letter := "F"
	match direction:
		CharacterAnimator.Direction.NORTH: letter = "B"
		CharacterAnimator.Direction.WEST: letter = "L"
		CharacterAnimator.Direction.EAST: letter = "R"
	return maxi(_cp_rows.find(letter), 0)


func _cp_frame_count(anim: String) -> int:
	var tex: Texture2D = _cp_sheets.get(anim)
	if tex == null:
		return 1
	return maxi(1, int(tex.get_width() / _cp_cell))


## Switch animation (no-op if already playing a looping one of that name).
func _cp_play(anim: String, restart: bool = false) -> void:
	if _cp_dead and anim != "Death":
		return
	if not _cp_sheets.has(anim):
		# Packs without a Run sheet walk; anything else falls back to Idle.
		anim = "Walk" if anim == "Run" and _cp_sheets.has("Walk") else "Idle"
	if anim == _cp_anim and not restart:
		return
	_cp_anim = anim
	_cp_frame = 0
	_cp_clock = 0.0
	_sprite.texture = _cp_sheets[anim]
	_cp_apply_frame()


func _cp_apply_frame() -> void:
	_sprite.region_rect = Rect2(_cp_frame * _cp_cell, _cp_row(_cp_dir) * _cp_cell, _cp_cell, _cp_cell)


## Drawn width of the idle front frame (texels) for the shadow ellipse.
func _measure_body_width() -> float:
	var img: Image = _sprite.texture.get_image()
	if img == null:
		return 40.0
	if img.is_compressed():
		img.decompress()
	var r := _sprite.region_rect
	var left := int(r.size.x)
	var right := -1
	for y in range(int(r.size.y)):
		for x in range(int(r.size.x)):
			if img.get_pixel(int(r.position.x) + x, int(r.position.y) + y).a > 0.05:
				left = mini(left, x)
				right = maxi(right, x)
	return float(right - left + 1) if right >= 0 else 40.0


# Per-(sheet, cell) cache of measured ground rows.
static var _ground_cache := {}


## Rows from the top of the cell down through the art's lowest opaque row —
## the pixel height of the sprite that stands above the ground line. Used as
## the feet pivot: the quad hangs this many texels above the sprite origin.
func _measure_ground_rows() -> float:
	var key := "%s|%s" % [_sprite.texture.resource_path, _sprite.region_rect]
	if _ground_cache.has(key):
		return _ground_cache[key]
	var rows := _sprite.region_rect.size.y - 6.0  # fallback
	var img: Image = _sprite.texture.get_image()
	if img:
		if img.is_compressed():
			img.decompress()
		var r := _sprite.region_rect
		var bottom := -1
		for y in range(int(r.size.y) - 1, -1, -1):
			for x in range(int(r.size.x)):
				if img.get_pixel(int(r.position.x) + x, int(r.position.y) + y).a > 0.05:
					bottom = y
					break
			if bottom >= 0:
				break
		if bottom >= 0:
			rows = float(bottom + 1)
	_ground_cache[key] = rows
	return rows


# =============================================================
# FACADE VERBS (called by Enemy)
# =============================================================

func play_action(action: String) -> void:
	var a := action.to_lower()
	for token in ["move", "walk", "advance", "reposition", "scurry", "crawl", "stalk", "prowl", "flee"]:
		if token in a:
			set_walking(true)
			if _cp_mode and "flee" in a:
				_cp_play("Run")
			return
	if a == "hit":
		play_hit()
		return
	if a == "idle" or a == "stance":
		set_walking(false)
		return
	if "heal" in a:
		flash(Color(0.5, 1.0, 0.5))
		return
	play_attack()


## Death animation (Craftpix packs only). Returns how long the caller should
## hold the body before removing it; 0 when there is no death sheet.
func play_death() -> float:
	if not _cp_mode or not _cp_sheets.has("Death"):
		return 0.0
	_cp_dead = true
	_walking = false
	_cp_play("Death", true)
	return float(_cp_frame_count("Death")) / CP_FPS["Death"]


func set_walking(on: bool) -> void:
	if _walking == on:
		return
	_walking = on
	_walk_frame = 0
	_walk_clock = 0.0
	if _npc_mode and not on:
		_apply_npc_frame(0)
	if _cp_mode and not _cp_anim in CP_ONESHOT:
		_cp_play("Walk" if on else "Idle")


func set_facing(direction: int) -> void:
	if _cp_mode:
		_cp_dir = direction
		_cp_apply_frame()
		return
	if _npc_mode:
		_npc_facing = direction
		_apply_npc_frame(_walk_frame if _walking else 0)
		return
	if direction == CharacterAnimator.Direction.EAST:
		_facing_x = 1.0
	elif direction == CharacterAnimator.Direction.WEST:
		_facing_x = -1.0
	_update_flip()


func set_facing_from_velocity(vel: Vector3) -> void:
	if _cp_mode:
		if vel.length_squared() < 0.01:
			return
		if absf(vel.x) > absf(vel.z):
			_cp_dir = CharacterAnimator.Direction.EAST if vel.x > 0.0 else CharacterAnimator.Direction.WEST
		else:
			_cp_dir = CharacterAnimator.Direction.SOUTH if vel.z > 0.0 else CharacterAnimator.Direction.NORTH
		_facing_x = 1.0 if vel.x > 0.0 else -1.0
		_cp_apply_frame()
		return
	if _npc_mode:
		if vel.length_squared() < 0.01:
			return
		if absf(vel.x) > absf(vel.z):
			_npc_facing = CharacterAnimator.Direction.EAST if vel.x > 0.0 else CharacterAnimator.Direction.WEST
		else:
			_npc_facing = CharacterAnimator.Direction.SOUTH if vel.z > 0.0 else CharacterAnimator.Direction.NORTH
		_facing_x = 1.0 if vel.x > 0.0 else -1.0
		_apply_npc_frame(_walk_frame if _walking else 0)
		return
	if absf(vel.x) > 0.05:
		_facing_x = 1.0 if vel.x > 0.0 else -1.0
		_update_flip()


func _apply_npc_frame(col: int) -> void:
	if _sprite:
		_sprite.region_rect = Rect2(col * 32, NPC_ROW[_npc_facing] * 32, 32, 32)


func _update_flip() -> void:
	if _sprite:
		_sprite.flip_h = _facing_x > 0.0


func set_quadruped(_on: bool) -> void:
	pass  # Battler art doesn't change stance.


func play_attack() -> void:
	if not _rig:
		return
	if _fx_tween:
		_fx_tween.kill()
	var dir := Vector3(_facing_x * 0.28, 0, 0.1)
	if _cp_mode:
		# Real swing frames; the lunge is a smaller step along the true facing.
		_cp_play("Attack", true)
		dir = _cp_forward() * 0.16
	_fx_tween = create_tween()
	_fx_tween.tween_property(_rig, "position", -dir * 0.3, 0.12)
	_fx_tween.tween_property(_rig, "position", dir, 0.08).set_ease(Tween.EASE_OUT)
	_fx_tween.tween_property(_rig, "position", Vector3.ZERO, 0.18).set_ease(Tween.EASE_IN_OUT)


func _cp_forward() -> Vector3:
	match _cp_dir:
		CharacterAnimator.Direction.NORTH: return Vector3(0, 0, -1)
		CharacterAnimator.Direction.EAST: return Vector3(1, 0, 0)
		CharacterAnimator.Direction.WEST: return Vector3(-1, 0, 0)
	return Vector3(0, 0, 1)


func play_hit() -> void:
	# White palette-saturating flash on damage (SNES hit flash), plus shake.
	flash(Color(3.0, 3.0, 3.0))
	if _cp_mode and _cp_anim != "Attack":
		_cp_play("Hurt", true)
	if _rig:
		var t := create_tween()
		t.tween_property(_rig, "position:x", 0.08, 0.05)
		t.tween_property(_rig, "position:x", -0.08, 0.08)
		t.tween_property(_rig, "position:x", 0.0, 0.06)


## Hard two-frame flash (style guide §5): the tint snaps on, holds ~2 frames,
## snaps off. No tween curve, no fade.
func flash(color: Color) -> void:
	if not _sprite:
		return
	_sprite.modulate = Color(color.r * 4.0, color.g * 4.0, color.b * 4.0) * _tint
	var t := create_tween()
	t.tween_interval(0.07)
	t.tween_callback(func():
		if _sprite:
			_sprite.modulate = _lit_tint())


func set_highlight(enabled: bool) -> void:
	_highlighted = enabled
	if _sprite:
		_sprite.modulate = _lit_tint()


func _lit_tint() -> Color:
	if _highlighted:
		return Color(_tint.r * 1.45, _tint.g * 1.45, _tint.b * 1.25, _tint.a)
	return _tint


func _process(delta: float) -> void:
	if not _sprite:
		return
	_time += delta
	if _cp_mode:
		_cp_step(delta)
		return
	if _walking:
		if _npc_mode:
			# Real walk frames for humanoids.
			_walk_clock += delta
			if _walk_clock >= NPC_WALK_TIME:
				_walk_clock -= NPC_WALK_TIME
				_walk_frame = (_walk_frame + 1) % 4
				_apply_npc_frame(_walk_frame)
			_sprite.position.y = _base_y
		else:
			# Waddle: a whole-pixel hop, never below the ground line — pixel
			# art never rotates off-axis (§5), and sub-pixel vertical drift
			# reads as floating.
			_sprite.position.y = _base_y + floorf(absf(sin(_time * 9.0)) * 1.9) * PIXEL_SIZE
	else:
		# Idle breathe: a single-pixel lift on the slow cycle's crest. The old
		# ±0.02 sine dipped the feet under the floor half the time and hovered
		# them the other half.
		_sprite.position.y = _base_y + (PIXEL_SIZE if sin(_time * 2.2) > 0.55 else 0.0)


## Advance the Craftpix animation clock. Loops Idle/Walk/Run; one-shots run
## once, Death holding its last frame, the others handing back to Idle/Walk.
func _cp_step(delta: float) -> void:
	var fps: float = CP_FPS.get(_cp_anim, 8.0)
	_cp_clock += delta
	var count := _cp_frame_count(_cp_anim)
	while _cp_clock >= 1.0 / fps:
		_cp_clock -= 1.0 / fps
		if _cp_frame + 1 >= count:
			if _cp_anim == "Death":
				return  # hold the last frame
			if _cp_anim in CP_ONESHOT:
				_cp_play("Walk" if _walking else "Idle", true)
				return
			_cp_frame = 0
		else:
			_cp_frame += 1
		_cp_apply_frame()
	# The body never bobs off its ground row: the packs animate that in-art.
	_sprite.position.y = _base_y
