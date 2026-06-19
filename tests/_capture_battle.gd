extends SceneTree

## Dev helper: boot the battle scene with a given character and capture the player
## figure idling, mid-attack, and mid-defend. Runs in slow-motion (Engine.time_scale)
## so the procedural Tween animations can actually be caught by the (slow, software)
## renderer. Run under xvfb + software GL (see _capture_select).
##   ... --script tests/_capture_battle.gd -- <prefix> <Character>

var _main: Node = null
var _frames := 0
var _prefix := "/tmp/battle"
var _trig := -999

func _initialize() -> void:
	Engine.time_scale = 0.12
	var args := OS.get_cmdline_user_args()
	var who := "Brad"
	if args.size() > 0:
		_prefix = args[0]
	if args.size() > 1:
		who = args[1]
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	_main = packed.instantiate()
	_main.set("starting_character", _make_char(who))
	get_root().add_child(_main)

func _make_char(who: String) -> CharacterData:
	match who:
		"Ryan": return CharacterData.create_ryan()
		"Jeremy": return CharacterData.create_jeremy()
		"Stephen": return CharacterData.create_stephen()
		"Cory": return CharacterData.create_cory()
		_: return CharacterData.create_brad()

func _process(_delta: float) -> bool:
	_frames += 1
	var player := _main.get_node_or_null("Player")
	match _frames:
		8:
			_add_closeup(player)
		40:
			_save("_idle.png")
		50:
			if player: player.play_animation("attack_slash")
			_trig = _frames
		200:
			if player: player.play_animation("block")
			_trig = _frames
		360:
			quit()
	# Burst-capture across each triggered animation (slow-mo spreads it over frames).
	var dt := _frames - _trig
	if _trig == 50 and dt in [10, 22, 36]:
		_save("_attack_%d.png" % dt)
	if _trig == 200 and dt in [12, 28, 50]:
		_save("_defend_%d.png" % dt)
	return false

func _add_closeup(player: Node) -> void:
	if player == null:
		return
	var cam := Camera3D.new()
	_main.add_child(cam)
	var p: Vector3 = player.global_position
	cam.global_position = p + Vector3(0.8, 1.35, 2.7)
	cam.look_at(p + Vector3(0, 0.6, 0), Vector3.UP)
	cam.current = true

func _save(suffix: String) -> void:
	var img := get_root().get_texture().get_image()
	img.save_png(_prefix + suffix)
	print("[capture] " + _prefix + suffix)
