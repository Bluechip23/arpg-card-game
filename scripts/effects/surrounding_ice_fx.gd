class_name SurroundingIceFX
extends Node3D

## Surrounding Ice: the designer's ice spike (tools/cut_ice_spike.py) erupts
## in a ring of stalagmites at the edge of the card's radius around the
## caster, and under every enemy the ice actually hits; each spike plays the
## same life: a thin shard breaks the ground, rises, stands as a full
## stalagmite, cracks and shatters into chips. The spikes ripple outward
## from the caster. An enemy the 30% miss roll spared gets no spike under it
## (even on the ring), so the gaps read as the misses. Drawn at SCALE (full
## size a spike stands nearly three tiles tall and a ring of them walls the
## caster in). Lives in the world; frees itself.

const STRIP := "res://assets/sprites/generated/fx/ice_spike_strip.png"
const FRAMES := 5
const CELL := 128
const BASE := Vector2(62, 98)     # where the spike meets the ground (see the tool)
const SCALE := 0.6                # ~1.6 tiles tall at its full height
const RING_INNER := 0.6           # ring = cells farther out than this share of the radius
const RIPPLE := 0.05              # extra delay per tile of distance from the caster
const RISE_TIME := 0.06           # per rising frame (shard, spike)
const STAND_TIME := 0.25          # the full stalagmite
const CRACK_TIME := 0.1
const SHATTER_TIME := 0.14

var spikes: Array[Sprite3D] = []


## Raise spikes around `center` on `world` (the node the field lives in): a
## ring of cells at the edge of `radius` (world units), plus the cells in
## `struck` (Vector2i cells of the enemies the ice hit), minus the cells in
## `spared` (the enemies the roll missed).
static func play(world: Node, grid: GridManager, center: Vector3, radius: float, struck: Array = [], spared: Array = []) -> SurroundingIceFX:
	if world == null or not world.is_inside_tree() or grid == null:
		return null
	var fx := SurroundingIceFX.new()
	world.add_child(fx)
	fx._start(grid, center, radius, struck, spared)
	return fx


func _start(grid: GridManager, center: Vector3, radius: float, struck: Array, spared: Array) -> void:
	name = "SurroundingIceFX"
	process_mode = Node.PROCESS_MODE_ALWAYS  # plays out even if the game pauses
	var tex: Texture2D = load(STRIP)
	var c0 := grid.world_to_grid(center)
	var reach := int(ceil(radius / grid.grid_size))
	var cells: Array[Vector2i] = []
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			var cell := c0 + Vector2i(dx, dz)
			var at: Vector3 = grid.grid_to_world(cell)
			var d := Vector2(at.x - center.x, at.z - center.z).length()
			if d <= radius and d > radius * RING_INNER:
				cells.append(cell)
	for cell in struck:
		if not cell in cells:
			cells.append(cell)
	var longest := 0.0
	for cell in cells:
		if cell in spared or cell == c0:
			continue
		var at: Vector3 = grid.grid_to_world(cell)
		var delay := Vector2(at.x - center.x, at.z - center.z).length() / grid.grid_size * RIPPLE
		longest = maxf(longest, delay)
		_spike(tex, Vector3(at.x, CameraView.SPRITE_LIFT, at.z), delay)
	var total := longest + RISE_TIME * 2 + STAND_TIME + CRACK_TIME + SHATTER_TIME
	var tw := create_tween()
	tw.tween_interval(total + 0.05)
	tw.tween_callback(queue_free)


func _spike(tex: Texture2D, at: Vector3, delay: float) -> void:
	var s := Sprite3D.new()
	s.texture = tex
	s.hframes = FRAMES
	s.frame = 0
	s.visible = false
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED          # stalagmites stand up off the floor
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD            # per-pixel sorting with the figures around it
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.pixel_size = CameraView.PIXEL_SIZE
	s.scale = Vector3.ONE * SCALE
	s.offset = Vector2(CELL * 0.5 - BASE.x, BASE.y - CELL * 0.5)  # the base on the tile (y-up offset)
	s.position = at - position
	add_child(s)
	spikes.append(s)
	var tw := s.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func(): s.visible = true)
	tw.tween_interval(RISE_TIME)
	tw.tween_callback(func(): s.frame = 1)
	tw.tween_interval(RISE_TIME)
	tw.tween_callback(func(): s.frame = 2)
	tw.tween_interval(STAND_TIME)
	tw.tween_callback(func(): s.frame = 3)
	tw.tween_interval(CRACK_TIME)
	tw.tween_callback(func(): s.frame = 4)
	tw.tween_interval(SHATTER_TIME)
	tw.tween_callback(func(): s.visible = false)
