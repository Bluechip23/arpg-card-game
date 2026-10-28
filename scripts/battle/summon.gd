class_name Summon
extends Node3D

## Base class for the player's summoned units: wolves, skeletons, specters,
## bull worms, Draupnir's duplicates, Frankensteins Monster, Sanguine the
## penguin and the spirit bows. It owns what every summon shares — a grid
## position with a glide between cells, a health pool behind the Cover
## mitigation hook, the head-up health label and death. main.gd drives the
## per-tempo decisions (its _update_* drivers bank tempo into the cadence
## accumulators); each subclass sets its stat constants, stands its body up in
## _build_visuals() — a pack sprite through _build_figure() (a
## SpriteEnemyFigure kind, the same art the enemies wear) — and overrides the
## hooks it needs:
##   _can_be_hit()               false while untargetable (a burrowed worm)
##   _absorb(amount) -> int      armor or resistance taken before health
##   _survive_lethal() -> bool   true to stand at 1 HP (Shepherd's Mark)
##   _after_hit(dealt, before)   e.g. Sanguine's heal-on-hurt signal
##   _health_label_text()        the label's wording

signal died(summon)

var display_name := "Summon"
var max_health: int = 10
var health: int = 10
var grid_manager: GridManager = null
var is_dead: bool = false
var move_accum: int = 0    # tempo banked toward the next move (main drives it)
var attack_accum: int = 0  # tempo banked toward the next attack
var glide_speed: float = 4.0  # world units per second between cells
var summoner: Node3D = null   # the player who called it up: summons walk their way

var _target_position: Vector3 = Vector3.ZERO
var _is_moving: bool = false
var _health_label: Label3D = null
var _figure: Node3D = null  # the pack sprite body: a SpriteEnemyFigure or SpriteFigure

## First half of every setup(): take the grid and stand on the spawn tile.
func _place(gm: GridManager, spawn_pos: Vector3) -> void:
	grid_manager = gm
	position = Vector3(spawn_pos.x, 0.0, spawn_pos.z)
	_target_position = position

## Second half of every setup(): body, then label.
func _finish_setup() -> void:
	_build_visuals()
	_update_health_label()

func _build_visuals() -> void:
	pass

## Stand a pack sprite in for the body: a SpriteEnemyFigure kind (see its
## KINDS table). It walks while the summon glides between cells and turns
## to its heading.
func _build_figure(kind: String) -> SpriteEnemyFigure:
	var fig := SpriteEnemyFigure.new()
	add_child(fig)
	fig.setup(kind)
	_figure = fig
	return fig

## Stand a player-character figure in (Draupnir's duplicate of its bearer),
## recoloured by `tint`.
func _build_player_figure(preset: String, tint: Color = Color.WHITE) -> SpriteFigure:
	var fig := SpriteFigure.new()
	add_child(fig)
	fig.setup(preset)
	fig.set_tint(tint)
	_figure = fig
	return fig

## The head-up health label, appended after the body. Over a pack sprite it
## sits just above the drawn head the way the enemies' bars do (north of the
## feet reads as "above" under the plan-view camera); `height` places it
## for a body without a measured sprite.
func _build_health_label(height: float, color: Color, font_size: int = 24) -> void:
	_health_label = Label3D.new()
	_health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_label.font_size = font_size
	_health_label.pixel_size = 0.005
	_health_label.position = Vector3(0, height, 0)
	if _figure:
		# A player figure stands one tile tall; a pack battler measures itself.
		var head := 1.0
		if _figure.has_method("portrait_extent"):
			head = maxf(0.5, float(_figure.portrait_extent().y))
		_health_label.position = Vector3(0, 0.5, -(head + 0.2))
	_health_label.modulate = color
	WorldText.crisp(_health_label)
	add_child(_health_label)

func _health_label_text() -> String:
	return "%s %d/%d" % [display_name, max(health, 0), max_health]

func _update_health_label() -> void:
	if _health_label:
		_health_label.text = _health_label_text()

func _process(delta: float) -> void:
	if _figure:
		_figure.set_walking(_is_moving)
	if not _is_moving:
		return
	if _figure:
		_figure.set_facing_from_velocity(_target_position - position)
	position.x = move_toward(position.x, _target_position.x, glide_speed * delta)
	position.z = move_toward(position.z, _target_position.z, glide_speed * delta)
	if abs(position.x - _target_position.x) < 0.01 and abs(position.z - _target_position.z) < 0.01:
		position.x = _target_position.x
		position.z = _target_position.z
		_is_moving = false

func get_cell() -> Vector2i:
	if grid_manager:
		return grid_manager.world_to_grid(position)
	return Vector2i.ZERO

## The cell it stands on or is gliding to (where it will be).
func get_destination_cell() -> Vector2i:
	if grid_manager:
		return grid_manager.world_to_grid(_target_position if _is_moving else position)
	return Vector2i.ZERO

func move_to_cell(cell: Vector2i) -> void:
	if not grid_manager or is_dead:
		return
	var world = grid_manager.grid_to_world(cell)
	_target_position = Vector3(world.x, 0.0, world.z)
	_is_moving = true

func get_health_percent() -> float:
	return float(health) / float(max_health) if max_health > 0 else 0.0

func _can_be_hit() -> bool:
	return true

func _absorb(amount: int) -> int:
	return amount

func _survive_lethal() -> bool:
	return false

func _after_hit(_dealt: int, _health_before: int) -> void:
	pass

func take_damage(amount: int) -> void:
	if is_dead or not _can_be_hit():
		return
	# Cover: a defender within 2 squares soaks the hit by their hand size.
	amount = PlayerStats.apply_cover(self, amount)
	if amount <= 0:
		return
	amount = _absorb(amount)
	var before: int = health
	health -= amount
	if health <= 0:
		_survive_lethal()
	_update_health_label()
	_after_hit(amount, before)
	if health <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit(self)
	queue_free()

# ---- What the Allies & Summons tab shows (UnitTrackerUI) ----

## Its own states, as badges under its health: [{name, color, stacks, desc}].
## Summons don't carry the players' buff / debuff managers; each kind lists
## what it does have (a specter's time left, Shepherd's Mark, a burrow...).
func get_status_effects() -> Array:
	return []

## Its armor for the tab: [now, cap] (cap 0 when it has no cap).
func get_armor_display() -> Array:
	return [0, 0]

## Its picture for the tab (the current pose of its sprite), or null.
func get_portrait_texture() -> Texture2D:
	if _figure and _figure.has_method("portrait_texture"):
		return _figure.portrait_texture()
	return null

func is_portrait_flipped() -> bool:
	return _figure != null and _figure.has_method("portrait_flipped") and _figure.portrait_flipped()
