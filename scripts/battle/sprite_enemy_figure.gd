class_name SpriteEnemyFigure
extends Node3D

## Billboard Sprite3D enemy visuals.
##
## Two sprite sources:
##  - MonsterKit battlers (assets/sprites/MonsterKit — 24 static 64x64
##    battlers). Static art, so all motion is procedural (bob, lunge, shake).
##    Kinds without a bespoke battler reuse one with a tint/scale variation
##    (e.g. werewolf = big dark wolf, bone dragon = big pale dragon whelp).
##  - NPC pack sheets (assets/sprites/NPCpackage1/2 — 32px, 4-direction
##    4-frame walk cycles) for humanoid enemies: mages, necromancer, vampire,
##    zombie, succubus, cherub, archangel... These get real directional walk
##    frames plus the same procedural attack/hit motion.
##
## Drop-in visual replacement for EnemyFigure on mapped kinds; unmapped kinds
## (fire goblin warband bosses etc. that need bespoke art) keep the
## procedural mesh figure.

const SHEET := "res://assets/sprites/MonsterKit/monster battler set.png"
const NPC1 := "res://assets/sprites/NPCpackage1"
const NPC2 := "res://assets/sprites/NPCpackage2"

# NPC sheets run S,W,N,E top to bottom (battle uses CharacterAnimator order S,N,E,W).
const NPC_ROW := [0, 2, 3, 1]
const NPC_WALK_TIME := 0.18

## kind -> config.
## MonsterKit battler: {cell: Vector2i(col,row), tint?: Color, scale?: float}
## NPC humanoid:       {npc: "<path>", tint?: Color, scale?: float}
const KINDS := {
	# --- direct battler matches ---
	"sludge": {"cell": Vector2i(0, 0)},
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
	"specter": {"cell": Vector2i(6, 1)},
	"wererabbit": {"cell": Vector2i(7, 1)},
	"skeleton": {"cell": Vector2i(1, 2)},
	"treant": {"cell": Vector2i(5, 2), "scale": 1.25},
	"consumed": {"cell": Vector2i(6, 2)},
	"sewer_croc": {"cell": Vector2i(7, 2)},
	# --- battler variations (tint + scale reuse) ---
	"rat": {"cell": Vector2i(7, 1), "tint": Color(0.7, 0.7, 0.75)},
	"archer_rat": {"cell": Vector2i(7, 1), "tint": Color(0.85, 0.7, 0.55)},
	"rat_king": {"cell": Vector2i(7, 1), "tint": Color(1.05, 0.9, 0.55), "scale": 1.35},
	"large_bear": {"tex": "large_bear", "scale": 1.45},
	"bugbear": {"cell": Vector2i(0, 1), "tint": Color(0.7, 0.62, 0.55), "scale": 1.3},
	"hydra": {"cell": Vector2i(3, 2), "tint": Color(0.85, 1.05, 0.85), "scale": 1.5},
	"bone_dragon": {"tex": "bone_dragon", "scale": 1.6},
	"wyvern": {"cell": Vector2i(7, 2), "tint": Color(0.9, 0.75, 1.05), "scale": 1.35},
	"cerberus": {"cell": Vector2i(3, 1), "tint": Color(0.85, 0.5, 0.45), "scale": 1.5},
	"werewolf": {"cell": Vector2i(3, 1), "tint": Color(0.6, 0.6, 0.68), "scale": 1.25},
	"sabertooth": {"cell": Vector2i(3, 1), "tint": Color(1.05, 0.95, 0.75), "scale": 1.2},
	"white_manticore": {"tex": "white_manticore", "scale": 1.4},
	"weregoat": {"cell": Vector2i(2, 1), "tint": Color(0.8, 0.8, 0.8), "scale": 1.15},
	"roc": {"cell": Vector2i(6, 0), "scale": 1.6},
	"ash_harpy": {"cell": Vector2i(6, 0), "tint": Color(0.65, 0.6, 0.65)},
	"ice_troll": {"tex": "ice_troll", "scale": 1.5},
	"snow_wraith": {"cell": Vector2i(4, 1), "tint": Color(1.1, 1.15, 1.3)},
	"granite_colossus": {"tex": "granite_colossus", "scale": 1.7},
	"armored_troll": {"cell": Vector2i(4, 2), "tint": Color(0.85, 1.0, 0.8), "scale": 1.45},
	"grave_titan": {"cell": Vector2i(4, 2), "tint": Color(0.7, 0.6, 0.8), "scale": 1.75},
	"demon": {"cell": Vector2i(5, 0), "tint": Color(0.9, 0.5, 0.5), "scale": 1.3},
	"ifrit": {"cell": Vector2i(1, 0), "tint": Color(1.2, 0.7, 0.4)},
	"pit_fiend": {"cell": Vector2i(3, 0), "tint": Color(0.8, 0.45, 0.45), "scale": 1.5},
	"magma_spider": {"cell": Vector2i(3, 0), "tint": Color(1.35, 0.75, 0.6)},
	"inflamed_minotaur": {"cell": Vector2i(0, 1), "tint": Color(1.1, 0.6, 0.5), "scale": 1.5},
	"fire_goblin_soldier": {"tex": "fire_goblin_soldier"},
	"fire_goblin_mage": {"tex": "fire_goblin_mage"},
	"fire_goblin_shaman": {"tex": "fire_goblin_shaman", "scale": 1.15},
	# --- NPC-pack humanoids (real 4-direction walk frames) ---
	"ice_mage": {"npc": NPC1 + "/npc mystic A v01.png", "tint": Color(0.75, 0.9, 1.25)},
	"fire_mage": {"npc": NPC1 + "/npc mystic A v01.png", "tint": Color(1.25, 0.7, 0.55)},
	"spark_mage": {"npc": NPC1 + "/npc mystic A v01.png", "tint": Color(1.2, 1.15, 0.6)},
	"air_mage": {"npc": NPC1 + "/npc mystic A v01.png", "tint": Color(1.1, 1.1, 1.15)},
	"earth_mage": {"npc": NPC1 + "/npc mystic A v01.png", "tint": Color(0.9, 1.0, 0.7)},
	"necromancer": {"npc": NPC1 + "/npc mystic A v01.png", "tint": Color(0.6, 0.55, 0.75)},
	"spirit_collector": {"npc": NPC1 + "/npc mystic A v01.png", "tint": Color(0.7, 0.8, 1.1)},
	"vampire": {"npc": NPC2 + "/npc dandy v01.png", "tint": Color(0.85, 0.78, 0.88)},
	"zombie": {"npc": NPC1 + "/npc old man A v01.png", "tint": Color(0.72, 1.0, 0.7)},
	"infected_hunter": {"npc": NPC1 + "/npc bard A v01.png", "tint": Color(0.8, 1.0, 0.75)},
	"succubus": {"npc": NPC1 + "/npc dancer A v01.png", "tint": Color(1.15, 0.7, 0.9)},
	"cherub": {"npc": NPC1 + "/npc baby A v01.png", "tint": Color(1.15, 1.1, 0.9)},
	"corrupted_archangel": {"npc": NPC1 + "/npc king A v01.png", "tint": Color(0.75, 0.6, 0.9), "scale": 1.2},
}

const PIXEL_SIZE := 0.032

## Kinds whose battler art already contains a painted contact shadow
## (the flyers) — these must not get a second blob shadow.
const PAINTED_SHADOW_KINDS := ["swarm", "giant_hawk", "roc", "ash_harpy",
		"screecher", "djinn", "snow_wraith", "specter"]

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
	_sprite.region_enabled = true
	_sprite.shaded = false
	if cfg.has("npc"):
		_npc_mode = true
		_sprite.texture = load(cfg["npc"])
		_sprite.pixel_size = PIXEL_SIZE * 1.15  # 32px humanoids ~ battler height
		_sprite.region_rect = Rect2(0, 0, 32, 32)
		_base_y = 16.0 * _sprite.pixel_size
	elif cfg.has("tex"):
		# Baked hue-shifted battler recolor (single 64x64 cell).
		_sprite.texture = load("res://assets/sprites/generated/monsters/%s.png" % cfg["tex"])
		_sprite.pixel_size = PIXEL_SIZE
		_sprite.region_rect = Rect2(0, 0, 64, 64)
		_base_y = 26.0 * PIXEL_SIZE
	else:
		_sprite.texture = load(SHEET)
		_sprite.pixel_size = PIXEL_SIZE
		var cell: Vector2i = cfg["cell"]
		_sprite.region_rect = Rect2(cell.x * 64, cell.y * 64, 64, 64)
		# Battler art sits low in the cell with a painted shadow; lift so the
		# feet/shadow line rests on the ground plane.
		_base_y = 26.0 * PIXEL_SIZE
	_sprite.position = Vector3(0, _base_y, 0)
	var s: float = cfg.get("scale", 1.0)
	_rig.scale = Vector3(s, s, s)
	_rig.add_child(_sprite)
	_sprite.modulate = _tint
	# Contact shadow (style guide §4). Inside the rig so it scales with the
	# creature and follows attack lunges; the rig never moves vertically.
	if not kind in PAINTED_SHADOW_KINDS:
		var body_w := 40.0 * _sprite.pixel_size  # typical drawn battler width
		BlobShadow.attach(_rig, body_w * 0.7)


# =============================================================
# FACADE VERBS (called by Enemy)
# =============================================================

func play_action(action: String) -> void:
	var a := action.to_lower()
	for token in ["move", "walk", "advance", "reposition", "scurry", "crawl", "stalk", "prowl", "flee"]:
		if token in a:
			set_walking(true)
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


func set_walking(on: bool) -> void:
	if _walking == on:
		return
	_walking = on
	_walk_frame = 0
	_walk_clock = 0.0
	if _npc_mode and not on:
		_apply_npc_frame(0)


func set_facing(direction: int) -> void:
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
	_fx_tween = create_tween()
	_fx_tween.tween_property(_rig, "position", Vector3(-_facing_x * 0.08, 0, -0.04), 0.12)
	_fx_tween.tween_property(_rig, "position", dir, 0.08).set_ease(Tween.EASE_OUT)
	_fx_tween.tween_property(_rig, "position", Vector3.ZERO, 0.18).set_ease(Tween.EASE_IN_OUT)


func play_hit() -> void:
	flash(Color(1.0, 0.3, 0.3))
	if _rig:
		var t := create_tween()
		t.tween_property(_rig, "position:x", 0.08, 0.05)
		t.tween_property(_rig, "position:x", -0.08, 0.08)
		t.tween_property(_rig, "position:x", 0.0, 0.06)


func flash(color: Color) -> void:
	if not _sprite:
		return
	var t := create_tween()
	t.tween_property(_sprite, "modulate", color * _tint, 0.1)
	t.tween_property(_sprite, "modulate", _lit_tint(), 0.15)


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
			# Waddle: quick bob plus a slight rock.
			_sprite.position.y = _base_y + absf(sin(_time * 9.0)) * 0.06
			_rig.rotation.z = sin(_time * 9.0) * 0.05
	else:
		_sprite.position.y = _base_y + sin(_time * 2.2) * 0.02
		_rig.rotation.z = 0.0
