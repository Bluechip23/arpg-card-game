extends Node2D

## Sprite viewer demo: the five party members rendered with the itch.io
## Mana Seed sprites, side by side, with shared keyboard control.
##
##   Arrow keys — face & walk in that direction
##   Z — sword swing    X — axe swing
##
## Run directly:  godot res://scenes/demo/character_viewer.tscn

const SPACING := 56.0

## name -> builder config. Brad/Cory/Stephen use the NPC models the player
## picked; Jeremy/Ryan are paper-doll builds on the character base.
const ROSTER := [
	{"name": "Brad", "npc": "res://assets/sprites/NPCpackage2/npc knight v01.png"},
	{"name": "Cory", "npc": "res://assets/sprites/NPCpackage1/npc merchant A v01.png"},
	{"name": "Stephen", "npc": "res://assets/sprites/NPCpackage2/npc guard v01.png"},
	{"name": "Jeremy", "outfit": "fstr_v05", "hair": "bob1_v11"},
	{"name": "Ryan", "outfit": "fstr_v03", "hair": "dap1_v13"},
]

var characters: Array[SpriteCharacter] = []


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.19, 0.15)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	bg_layer.add_child(bg)
	add_child(bg_layer)

	for i in range(ROSTER.size()):
		var cfg: Dictionary = ROSTER[i]
		var c := SpriteCharacter.new()
		c.position = Vector2(i * SPACING, 0)
		if cfg.has("npc"):
			c.setup_npc(cfg["npc"])
		else:
			c.setup_doll(cfg["outfit"], cfg["hair"])
		add_child(c)
		characters.append(c)

		var label := Label.new()
		label.text = cfg["name"]
		label.add_theme_font_size_override("font_size", 8)
		label.position = Vector2(i * SPACING - 24, 26)
		label.size = Vector2(48, 10)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)

	var cam := Camera2D.new()
	cam.position = Vector2((ROSTER.size() - 1) * SPACING / 2.0, -4)
	cam.zoom = Vector2(4, 4)
	add_child(cam)
	cam.make_current()

	var hint := Label.new()
	hint.text = "Arrows: face/walk    Z: sword    X: axe"
	hint.position = Vector2(16, 12)
	var ui := CanvasLayer.new()
	ui.add_child(hint)
	add_child(ui)


func _process(_delta: float) -> void:
	var dir := -1
	if Input.is_action_pressed("ui_down"):
		dir = SpriteCharacter.Facing.SOUTH
	elif Input.is_action_pressed("ui_up"):
		dir = SpriteCharacter.Facing.NORTH
	elif Input.is_action_pressed("ui_right"):
		dir = SpriteCharacter.Facing.EAST
	elif Input.is_action_pressed("ui_left"):
		dir = SpriteCharacter.Facing.WEST

	for c in characters:
		if c.current_anim.begins_with("attack"):
			continue
		if dir >= 0:
			c.set_facing(dir)
			if c.current_anim != "walk":
				c.play("walk")
		elif c.current_anim == "walk":
			c.play("idle")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Z:
				for c in characters:
					c.play("attack_sword")
			KEY_X:
				for c in characters:
					c.play("attack_axe")
