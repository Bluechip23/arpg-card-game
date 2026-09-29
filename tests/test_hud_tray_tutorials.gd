extends SceneTree

## Live HUD checks in the dojo: an equipped Heal Stone puts a tally box in
## the passive tray that counts healing toward its proc, and the Tab menu's
## Tutorials tab lists every one of Olorin's lessons beat by beat.
## Run: godot --headless --path . --script tests/test_hud_tray_tutorials.gd

var _main: Node = null
var _frames := 0
var failures := 0

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
	if _frames < 12:
		return false
	_run()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
	return true

func _tray_box(id_prefix: String) -> Node:
	for child in _main.passive_display_container.get_children():
		if str(child.passive_id).begins_with(id_prefix):
			return child
	return null

func _run() -> void:
	print("=== HUD tray + Tutorials tab test ===")
	var stats = _main.player.get_stats()
	var inv = _main.player.get_inventory()
	_check(_tray_box("ring_") == null, "no ring box before a ring is worn")
	var stone := ItemData.create_heal_stone()
	inv.stored_items.append(stone)
	_check(inv.equip_item(stone), "the Heal Stone equips")
	_main._update_passive_display_ui()
	var box = _tray_box("ring_")
	_check(box != null, "the tray gains a Heal Stone box")
	if box:
		_check(box._count == 0 and box._count_total == 5, "it reads 0 of 5")
	# Heals are boosted by the character's healing bonus, so read the real
	# amount off the health bar and expect the tally to follow it.
	stats.take_damage(10)
	var before: int = stats.current_health
	stats.heal(3)
	var healed: int = stats.current_health - before
	_main._update_passive_display_ui()
	if box:
		_check(box._count == healed % 5, "healing %d shows %d of 5 (got %d)" % [healed, healed % 5, box._count])
	before = stats.current_health
	stats.heal(3)
	healed += stats.current_health - before
	_main._update_passive_display_ui()
	if box:
		_check(box._count == healed % 5 and healed >= 5, "the tally wraps at 5 when the proc fires (got %d of %d healed)" % [box._count, healed])
	inv.unequip_item(ItemData.ItemType.RING, 0)
	_main._update_passive_display_ui()
	_check(_tray_box("ring_") == null, "taking the ring off removes its box")

	# Tutorials tab.
	_main.minimap_tab_ui._on_tab_tutorials_pressed()
	var box_ct: VBoxContainer = _main._tab_tutorials_container
	_check(box_ct != null and box_ct.get_parent().visible, "the Tutorials tab shows its pane")
	var titles: Array = []
	for child in box_ct.get_children():
		if child is Label and child.text.begins_with("The Road Out"):
			titles.append(child.text)
	_check(titles.size() >= 1, "the field tour is listed")
	var labels := 0
	for child in box_ct.get_children():
		if child is Label:
			labels += 1
	var expected := 0
	for lesson in OlorinTutorial.LESSONS:
		for beat in lesson["beats"]:
			expected += beat["paragraphs"].size()
	_check(labels > expected, "every lesson's paragraphs are laid out (%d labels for %d paragraphs)" % [labels, expected])
	_check(OlorinTutorial.LESSONS.size() == 6, "six lessons are listed")
