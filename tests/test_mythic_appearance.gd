extends SceneTree

## Verifies every mythic describes what it LOOKS like and ships the matching
## art the inventory shows while it is equipped: the appearance text, the
## icon path, the file behind that path, and that the texture actually loads
## at the size the equipment slot expects.
## Run: godot --headless --path . --script tests/test_mythic_appearance.gd

const EquipmentSlotCellScript = preload("res://scripts/character/equipment_slot_cell.gd")

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Mythic appearance test ===")

	_test_every_mythic_has_an_appearance()
	_test_art_loads()
	_test_pixel_art_scaling()
	_test_non_mythics_fall_back()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _mythics() -> Array[ItemData]:
	return ItemData.get_items_of_rarity(ItemData.Rarity.MYTHIC)

func _test_every_mythic_has_an_appearance() -> void:
	print("-- Appearance text --")
	var mythics = _mythics()
	_check(mythics.size() >= 25, "found %d mythics" % mythics.size())
	for item in mythics:
		_check(item.appearance.strip_edges() != "",
			"%s describes its appearance" % item.item_name)
		_check(item.appearance_icon.begins_with(ItemData.APPEARANCE_ICON_DIR),
			"%s points at an icon (%s)" % [item.item_name, item.appearance_icon])
		_check(FileAccess.file_exists(item.appearance_icon),
			"%s icon file exists" % item.item_name)

func _test_art_loads() -> void:
	print("-- Art loads --")
	for item in _mythics():
		_check(item.has_appearance_art(), "%s reports art" % item.item_name)
		var tex: Texture2D = item.get_appearance_texture()
		_check(tex != null, "%s texture loads" % item.item_name)
		if tex:
			_check(tex.get_size() == Vector2(32, 32),
				"%s texture is 32x32 (got %s)" % [item.item_name, tex.get_size()])

func _test_pixel_art_scaling() -> void:
	## The slot blows the sprite up by whole texels only — never a fractional
	## scale (style guide §1).
	print("-- Whole-texel scaling --")
	var tex: Texture2D = _mythics()[0].get_appearance_texture()
	for box in [Vector2(72, 64), Vector2(40, 40), Vector2(20, 20), Vector2(200, 200)]:
		var rect: TextureRect = EquipmentSlotCellScript.make_pixel_art_rect(tex, box)
		var steps: float = rect.custom_minimum_size.x / 32.0
		_check(steps == floorf(steps) and steps >= 1.0,
			"box %s scales by a whole %d texels" % [box, int(steps)])
		_check(steps == 1.0 or rect.custom_minimum_size.x <= box.x,
			"box %s: art fits inside the slot" % box)
		rect.free()

func _test_non_mythics_fall_back() -> void:
	## Only mythics carry art today; everything else keeps the slot silhouette.
	print("-- Non-mythics --")
	var without := 0
	for item in ItemData.get_all_items():
		if item.rarity == ItemData.Rarity.MYTHIC:
			continue
		if item.appearance == "" and not item.has_appearance_art():
			without += 1
		else:
			_check(item.has_appearance_art(),
				"%s describes an appearance, so it must ship art" % item.item_name)
	_check(without > 0, "%d non-mythic items fall back to the silhouette" % without)
