extends SceneTree

## Menus pause the clock (designer, 2026-10-30): while a window is open,
## pending card ticks wait; closing it lets them run on. With nothing
## pending the clock is still either way.
## Run: godot --headless --path . --script tests/test_menu_tempo_hold.gd

var _main: Node = null
var _frames := 0
var failures := 0
var _stage := 0
var _t0 := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	_main = packed.instantiate()
	_main.set("starting_character", CharacterData.create_brad())
	_main.set("current_interior_id", "dojo")
	get_root().add_child(_main)

func _process(_delta: float) -> bool:
	_frames += 1
	var tm = _main.tempo_manager
	match _stage:
		0:
			if _frames < 12:
				return false
			print("=== Menu tempo hold test ===")
			if _main.olorin and _main.olorin.is_busy():
				_main.olorin._close()
			tm.tick_speed = 0.02
			var card := Card.new()
			card.card_name = "Test Ticks"
			tm.start_card_ticks(card, 20, 20)
			_main.character_panel.toggle_panel()
			_t0 = tm.get_global_tempo()
			_frames = 0
			_stage = 1
		1:
			if _frames < 40:
				return false
			_check(_main._is_ui_window_open(), "the character sheet is open")
			_check(tm.menu_hold, "the clock is held")
			_check(tm.get_global_tempo() == _t0, "no tick passed behind the open menu (%d -> %d)" % [_t0, tm.get_global_tempo()])
			_check(_main._tick_bar_label.text.ends_with("Paused while a menu is open"), "the tempo bar says why")
			_main.character_panel.toggle_panel()
			_frames = 0
			_stage = 2
		2:
			if _frames < 40:
				return false
			_check(not tm.menu_hold, "closing the menu releases the clock")
			_check(tm.get_global_tempo() > _t0, "the pending ticks run on (%d -> %d)" % [_t0, tm.get_global_tempo()])
			print("=== %d failure(s) ===" % failures)
			quit(1 if failures > 0 else 0)
			return true
	return false
