extends SceneTree

## Olorin's field tour: the spotlight overlay lights the beat's Controls and
## dims the rest, the dialog keeps clear of the lit area, the beats advance
## in order, and the tour is remembered on the character.

var _fails := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: " + msg)
	else:
		_fails += 1
		print("  FAIL: " + msg)

class FakeMain extends Node:
	var current_character: CharacterData = null

var _ran := false

func _process(_delta: float) -> bool:
	# The nodes join the tree after _initialize; run once they are in it.
	if _ran:
		return false
	_ran = true
	_run()
	return true

func _run() -> void:
	var holder := Node.new()
	get_root().add_child(holder)
	var main := FakeMain.new()
	main.current_character = CharacterData.create_brad()
	holder.add_child(main)
	var olorin := OlorinTutorial.new()
	olorin.init(main)
	holder.add_child(olorin)

	# Two HUD stand-ins on a plain canvas layer: one top-left, one bottom-left.
	var ui := CanvasLayer.new()
	holder.add_child(ui)
	var top_left := ColorRect.new()
	top_left.position = Vector2(8, 8)
	top_left.size = Vector2(600, 120)  # reaches into the screen's middle column
	ui.add_child(top_left)
	var screen_h: float = get_root().get_visible_rect().size.y
	var bottom_left := ColorRect.new()
	bottom_left.position = Vector2(8, screen_h - 160)
	bottom_left.size = Vector2(200, 150)
	ui.add_child(bottom_left)
	var hidden := ColorRect.new()
	hidden.position = Vector2(900, 300)
	hidden.size = Vector2(100, 100)
	hidden.visible = false
	ui.add_child(hidden)

	var steps: Array = [
		{"title": "One", "focus": [], "paragraphs": ["first"]},
		{"title": "Two", "focus": [top_left, hidden], "paragraphs": ["second"]},
		{"title": "Three", "focus": [bottom_left], "paragraphs": ["third"]},
	]
	_check(olorin.show_tour("test_tour", steps), "the tour starts")
	_check(olorin.is_busy(), "Olorin is busy while it runs")
	_check(paused, "the action pauses while he speaks")
	_check(olorin.tour_step_index() == 0, "it opens on the first beat")
	_check(olorin.tour_hole() == Rect2(), "a beat with no focus dims the whole screen")
	_check(main.current_character.seen_tutorial_ids.has("test_tour"), "the tour is remembered on the character")

	olorin._tour_next()
	var hole := olorin.tour_hole()
	_check(hole.has_point(Vector2(100, 60)), "the second beat lights the top-left widget")
	_check(not hole.has_point(Vector2(950, 350)), "a hidden Control is not lit")
	_check(hole.position.x < 8.0 and hole.position.y < 8.0, "the lit area is padded around the widget")
	var screen: Vector2 = get_root().get_visible_rect().size
	_check(OlorinTutorial.placement_for(hole, screen) == "below", "the dialog goes below a top-of-screen widget")
	_check(olorin._tour_panel != null, "the beat has its dialog")

	olorin._tour_next()
	hole = olorin.tour_hole()
	_check(hole.has_point(Vector2(100, screen_h - 100)), "the third beat lights the bottom-left widget")
	_check(OlorinTutorial.placement_for(hole, screen) == "centre", "a bottom-left widget leaves the middle of the screen for the dialog")
	var wide := Rect2(200, screen_h - 200, screen.x - 400, 150)
	_check(OlorinTutorial.placement_for(wide, screen) == "above", "a wide widget along the bottom puts the dialog above it")
	_check(OlorinTutorial.placement_for(Rect2(), screen) == "centre", "no lit area centres the dialog")

	olorin._tour_next()
	_check(not olorin.is_busy(), "the tour closes after the last beat")
	_check(not paused, "the action resumes")
	_check(not olorin.show_tour("test_tour", steps), "a remembered tour does not replay on its own")
	_check(olorin.show_tour("test_tour", steps, true), "…but replays when asked")
	olorin._close()

	print("=== %d failure(s) ===" % _fails)
	quit(1 if _fails > 0 else 0)
