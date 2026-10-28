class_name RescueNpc
extends Node3D

## A townsperson found in the wild (The Missing Woodcutter, A Debt to the
## Sellsword). Waits where they were placed until the player presses Shift
## beside them, then follows one tile behind (Main moves them onto the tile
## the player just left). Delivered when the player leaves the interior with
## them in tow. First pass: enemies ignore them.
##
## With `depot` set, the same figure is a standing post instead (the rescued
## foreman at the Greenwood trailhead): Shift sends the satchel home.

const SHEET_FRAME := Rect2(0, 0, 32, 32)  # south-facing idle on the NPC pack sheets

var npc_id: String = ""
var display_name: String = ""
var following: bool = false
var depot: bool = false
var grid_cell: Vector2i = Vector2i(-1, -1)

var _sprite: Sprite3D
var _figure: SpriteEnemyFigure = null   # a figure rig instead, for "kind:<figure>" setups
var _prompt: Label3D

## `sheet_path` is an NPC-pack sheet, or "kind:<figure>" for a SpriteEnemyFigure.
func setup(id: String, p_name: String, sheet_path: String, prompt_text: String = "[Shift] Talk", tint: Color = Color.WHITE) -> void:
	npc_id = id
	display_name = p_name
	name = "RescueNpc_%s" % id

	if sheet_path.begins_with("kind:"):
		# A figure rig (the designer's boards: Olorin), not an NPC-pack sheet.
		_figure = SpriteEnemyFigure.new()
		_figure.name = "Figure"
		add_child(_figure)
		_figure.setup(sheet_path.trim_prefix("kind:"))
		var head: float = maxf(1.0, float(_figure.portrait_extent().y)) if _figure.has_method("portrait_extent") else 2.0
		_add_labels(p_name, prompt_text, Vector3(0, 1.45, -(head + 0.25)), Vector3(0, 1.95, -(head + 0.6)))
		return
	_sprite = Sprite3D.new()
	_sprite.name = "Figure"
	_sprite.texture = load(sheet_path)
	_sprite.region_enabled = true
	_sprite.region_rect = SHEET_FRAME
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD  # writes depth: per-pixel sorting
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.shaded = false
	_sprite.pixel_size = 0.03125
	_sprite.modulate = tint
	var s := 1.1
	_sprite.scale = Vector3(s, s, s)
	_sprite.position = Vector3(0, 32.0 * 0.03125 * 0.5 * s, 0)
	add_child(_sprite)
	BlobShadow.attach(self, 0.5)
	_add_labels(p_name, prompt_text, Vector3(0, 1.45, 0), Vector3(0, 1.95, 0))

func _add_labels(p_name: String, prompt_text: String, name_pos: Vector3, prompt_pos: Vector3) -> void:
	var label := Label3D.new()
	label.name = "NameLabel"
	label.text = p_name
	label.font_size = 18
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.95, 0.75)
	label.position = name_pos
	WorldText.crisp(label)
	add_child(label)

	_prompt = Label3D.new()
	_prompt.name = "InteractLabel"
	_prompt.text = prompt_text
	_prompt.font_size = 16
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.modulate = Color(1.0, 0.9, 0.4)
	_prompt.position = prompt_pos
	_prompt.visible = false
	WorldText.crisp(_prompt)
	add_child(_prompt)

func set_prompt_visible(v: bool) -> void:
	if _prompt:
		_prompt.visible = v

func step_to(world_pos: Vector3, cell: Vector2i) -> void:
	## Glide onto a tile (the one the player just vacated).
	if _sprite:
		var dx := world_pos.x - position.x
		if absf(dx) > 0.05:
			_sprite.flip_h = dx < 0.0
	elif _figure:
		_figure.set_facing_from_velocity(world_pos - position)
	grid_cell = cell
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", world_pos, 0.2)

func place_at(world_pos: Vector3, cell: Vector2i) -> void:
	position = world_pos
	grid_cell = cell
