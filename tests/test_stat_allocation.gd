extends SceneTree

## Verifies the character-select stat allocation: 8 points, guards, and that
## confirming applies the points on top of the base-3 stats.
## Run: godot --headless --path . --script tests/test_stat_allocation.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Stat allocation test ===")

	var cs = load("res://scripts/character/character_select.gd").new()
	var c = CharacterData.create_ryan()  # base 3 everywhere

	# Set up allocation state the way _show_stat_allocation does (without the UI).
	var fired := [false]
	cs._alloc_char = c
	cs._alloc_on_confirm = func(): fired[0] = true
	cs._alloc_points = cs.ALLOC_TOTAL
	cs._alloc = {}
	for key in CharacterData.STAT_KEYS:
		cs._alloc[key] = 0
	cs._alloc_base = {
		"STR": c.strength, "DEX": c.dexterity, "INT": c.intelligence,
		"WIS": c.wisdom, "DET": c.determination, "AGI": c.agility,
	}
	cs._alloc_value_labels = {}

	_check(cs._alloc_points == 8, "starts with 8 points to allocate")

	# Under-allocate guard: can't drop a stat below its base allocation of 0.
	cs._alloc_add("STR", -1)
	_check(cs._alloc["STR"] == 0 and cs._alloc_points == 8, "cannot allocate below 0")

	# Spend 3 into STR and 5 into DEX = 8.
	for i in range(3):
		cs._alloc_add("STR", 1)
	for i in range(5):
		cs._alloc_add("DEX", 1)
	_check(cs._alloc_points == 0, "all 8 points spent")

	# Over-allocate guard: no points left, further adds are ignored.
	cs._alloc_add("INT", 1)
	_check(cs._alloc["INT"] == 0 and cs._alloc_points == 0, "cannot allocate past the point budget")

	# Confirm applies the points on top of the base-3 stats and fires callback.
	cs._alloc_confirm()
	_check(c.strength == 6, "STR = 3 base + 3 allocated")
	_check(c.dexterity == 8, "DEX = 3 base + 5 allocated")
	_check(c.intelligence == 3 and c.wisdom == 3, "untouched stats stay at base 3")
	_check(fired[0], "confirm fires the proceed callback")

	cs.free()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
