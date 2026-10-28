extends SceneTree

## Dev helper: the town with the player walked up near the Sellsword (or the
## Blacksmith), the camera at a given zoom, saved as a PNG.
##   ... --script tests/_capture_town_zoom.gd -- <out.png> <sellsword|blacksmith|olorin> [zoom]

var _frames := 0
var town
var out := "/tmp/town_zoom.png"
var who := "sellsword"
var zoom := 2.0

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: who = a[1]
	if a.size() > 2: zoom = float(a[2])
	town = load("res://scenes/menus/town.tscn").instantiate()
	town.starting_character = CharacterData.create_brad()
	get_root().add_child(town)

func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 10:
		var target: Node3D = town.get_node("Vendors/Sellsword") if who == "sellsword" else (town.get_node("Vendors/Olorin") if who == "olorin" else town.get_node("Vendors/Blacksmith"))
		var off := Vector3(-2, 0, 1.5) if who == "sellsword" else Vector3(2.2, 0, 1.2)
		town.player.position = target.global_position + off
		town.player.target_position = town.player.position
		town._camera_focus = target.global_position + Vector3(0.5, 0, 0.2)
		town._camera_distance = zoom
		town._update_camera()
	if _frames == 40:
		get_root().get_texture().get_image().save_png(out)
		quit()
	return false
