extends SceneTree

## Dev helper: boot the Compendium and save a PNG of each tab (Cards, Items,
## Enemies), each with the first entry hovered so its detail popup shows.
## Run under xvfb + software GL:
##   LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
##     --rendering-method gl_compatibility --rendering-driver opengl3 \
##     --script tests/_capture_compendium.gd -- <out_dir>

const TABS := ["cards", "items", "enemies"]

var _page: Node = null
var _out := "/tmp/compendium"
var _frames := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_page = (load("res://scenes/ui/compendium_page.tscn") as PackedScene).instantiate()
	get_root().add_child(_page)

func _first_tile(tab: int) -> Control:
	var containers := [_page._cards_container, _page._items_container, _page._enemies_container]
	var box: Node = containers[tab]
	for child in box.get_children():
		if child is GridContainer and child.get_child_count() > 0:
			return child.get_child(0)
	return null

func _process(_delta: float) -> bool:
	_frames += 1
	# Each tab: switch at +0, hover the first tile at +10, shoot at +25.
	var local := _frames - 20
	if local < 0:
		return false
	var idx := local / 30
	var phase := local % 30
	if idx >= TABS.size():
		quit()
		return true
	if phase == 0:
		_page.tab_container.current_tab = idx
	elif phase == 10:
		var tile := _first_tile(idx)
		if tile:
			tile.mouse_entered.emit()
	elif phase == 25:
		get_root().get_texture().get_image().save_png("%s/compendium_%s.png" % [_out, TABS[idx]])
		print("[capture] saved compendium_%s.png" % TABS[idx])
	return false
