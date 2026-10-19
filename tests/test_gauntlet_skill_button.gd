extends SceneTree

## The gauntlet skill button must hand its gauntlet to main on a click:
## `_pressed` is BaseButton's engine virtual, and an "unreferenced function"
## sweep once deleted it, which left every active skill unclickable. Checks
## that a ready active skill emits skill_activated on press, and that a
## recharging or passive one does not.
## Run: godot --headless --path . --script tests/test_gauntlet_skill_button.gd

const Fixtures := preload("res://tests/item_fixtures.gd")
const Scene := preload("res://scenes/cards/gauntlet_skill_ui.tscn")

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	var fired: Array = []
	var ui = Scene.instantiate()
	root.add_child(ui)
	ui.skill_activated.connect(func(g): fired.append(g))
	var item = Fixtures.mythic_gauntlets()
	ui.setup(item)
	ui._pressed()
	_check(fired.size() == 1 and fired[0] == item, "a ready active skill emits skill_activated on press")

	fired.clear()
	item.current_cooldown = 2
	ui.update_display()
	ui._pressed()
	_check(fired.is_empty() and ui.disabled, "a recharging skill is disabled and does not emit")

	fired.clear()
	item.current_cooldown = 0
	item.gauntlet_skill_type = ItemData.GauntletSkillType.PASSIVE
	ui.setup(item)
	ui._pressed()
	_check(fired.is_empty() and ui.disabled, "a passive skill is disabled and does not emit")

	ui.queue_free()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
