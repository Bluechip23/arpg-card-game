extends SceneTree
## Dev helper: boot a battle and save the whole screen once the hand is dealt
## (checks the hand fan and the card faces at their in-game size).
## Run: xvfb-run -a godot --path . --resolution 1920x1080 --script tests/_capture_hand.gd -- /tmp/hand.png [Character]
var _main: Node = null
var _frames := 0
var _out := "/tmp/hand.png"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var who := "Brad"
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		who = args[1]
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate()
	var cd: CharacterData
	match who:
		"Ryan": cd = CharacterData.create_ryan()
		"Jeremy": cd = CharacterData.create_jeremy()
		"Stephen": cd = CharacterData.create_stephen()
		"Cory": cd = CharacterData.create_cory()
		_: cd = CharacterData.create_brad()
	_main.set("starting_character", cd)
	get_root().add_child(_main)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 20 and _frames < 200 and _main.olorin and _main.olorin.is_busy():
		_main.olorin._close()   # past the tutorial's talk
	if _frames == 240:
		get_root().get_texture().get_image().save_png(_out)
		print("[capture] saved %s" % _out)
		quit()
		return true
	return false
