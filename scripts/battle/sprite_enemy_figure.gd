class_name SpriteEnemyFigure
extends Node3D

## Billboard Sprite3D enemy drawn from the MonsterKit battler set
## (assets/sprites/MonsterKit/monster battler set.png — 24 static 64x64
## battlers). Drop-in visual replacement for EnemyFigure on the enemy kinds
## that have a matching battler; unmatched kinds keep the procedural figure.
##
## The battlers are single static images, so all motion is procedural:
## idle bob, walk waddle, attack lunge, hit shake, and modulate flashes.

const SHEET := "res://assets/sprites/MonsterKit/monster battler set.png"

## kind -> {cell: Vector2i(col,row) on the 8x3 battler grid,
##          tint: optional Color multiplier to differentiate shared cells,
##          scale: optional visual scale}
const KINDS := {
	"sludge": {"cell": Vector2i(0, 0)},
	"mind_eater": {"cell": Vector2i(1, 0)},
	"pipe_crawler": {"cell": Vector2i(2, 0)},
	"crypt_crawler": {"cell": Vector2i(3, 0)},
	"magma_spider": {"cell": Vector2i(3, 0), "tint": Color(1.35, 0.75, 0.6)},
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
}

const PIXEL_SIZE := 0.032

var _sprite: Sprite3D = null
var _rig: Node3D = null
var _tint := Color.WHITE
var _highlighted := false
var _walking := false
var _time := 0.0
var _facing_x := -1.0  # battlers are drawn facing left; flip for east
var _fx_tween: Tween = null


static func supports(kind: String) -> bool:
	return KINDS.has(kind)


func setup(kind: String) -> void:
	var cfg: Dictionary = KINDS.get(kind, KINDS["wolf"])
	_tint = cfg.get("tint", Color.WHITE)
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	_sprite = Sprite3D.new()
	_sprite.texture = load(SHEET)
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.pixel_size = PIXEL_SIZE
	_sprite.region_enabled = true
	var cell: Vector2i = cfg["cell"]
	_sprite.region_rect = Rect2(cell.x * 64, cell.y * 64, 64, 64)
	_sprite.shaded = false
	# Battler art sits low in the cell with a painted shadow; lift so the
	# feet/shadow line rests on the ground plane.
	_sprite.position = Vector3(0, 26.0 * PIXEL_SIZE, 0)
	var s: float = cfg.get("scale", 1.0)
	_rig.scale = Vector3(s, s, s)
	_rig.add_child(_sprite)
	_sprite.modulate = _tint


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
	_walking = on


func set_facing(direction: int) -> void:
	# CharacterAnimator.Direction: flip the battler when it should face east.
	if direction == CharacterAnimator.Direction.EAST:
		_facing_x = 1.0
	elif direction == CharacterAnimator.Direction.WEST:
		_facing_x = -1.0
	_update_flip()


func set_facing_from_velocity(vel: Vector3) -> void:
	if absf(vel.x) > 0.05:
		_facing_x = 1.0 if vel.x > 0.0 else -1.0
		_update_flip()


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
		# Waddle: quick bob plus a slight rock.
		_sprite.position.y = 26.0 * PIXEL_SIZE + absf(sin(_time * 9.0)) * 0.06
		_rig.rotation.z = sin(_time * 9.0) * 0.05
	else:
		_sprite.position.y = 26.0 * PIXEL_SIZE + sin(_time * 2.2) * 0.02
		_rig.rotation.z = 0.0
