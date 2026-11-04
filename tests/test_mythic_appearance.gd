extends SceneTree

## Verifies every mythic describes what it LOOKS like and ships the matching
## art the inventory shows — in its storage cell, in its equipment slot and
## in its detail panel, stored or equipped — and the hand holds: the
## appearance text, the icon path, the file behind that path, and that the
## texture loads at the size it is drawn at (the designer's painted art at
## 128px, the generated icons at 32px).
## Run: godot --headless --path . --script tests/test_mythic_appearance.gd

const EquipmentSlotCellScript = preload("res://scripts/character/equipment_slot_cell.gd")

## Every mythic wears the designer's painting (tools/cut_mythic_art.py,
## 2026-10-23; the Bladed Doughnut, the last, 2026-10-31) — none keeps a
## generated 32px icon any more.
const GENERATED := []
const PAINTED_SIZE := Vector2(128, 128)

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
	_test_painted_art_shrinks()
	_test_non_mythics_fall_back()
	await _test_inventory_shows_art()
	# (The held-in-hand check went with the weapon swing, deleted 2026-10-30.)

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _mythics() -> Array[ItemData]:
	return ItemData.get_items_of_rarity(ItemData.Rarity.MYTHIC)

func _test_every_mythic_has_an_appearance() -> void:
	print("-- Appearance text --")
	var mythics = _mythics()
	_check(mythics.size() >= 36, "found %d mythics" % mythics.size())
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
			var slug := item.appearance_icon.get_file().get_basename()
			var want := Vector2(32, 32) if slug in GENERATED else PAINTED_SIZE
			_check(tex.get_size() == want,
				"%s texture is %s (got %s)" % [item.item_name, want, tex.get_size()])

func _test_pixel_art_scaling() -> void:
	## The slot blows a small sprite up by whole texels only — never a
	## fractional enlargement (style guide §1); a box too small for it shrinks it.
	print("-- Whole-texel scaling --")
	# No mythic is a 32px sprite any more; the slot still scales one by whole
	# texels (other small icons go through it).
	var tex: Texture2D = ImageTexture.create_from_image(Image.create(32, 32, false, Image.FORMAT_RGBA8))
	_check(tex != null and tex.get_size() == Vector2(32, 32), "a 32px sprite to scale")
	for box in [Vector2(72, 64), Vector2(40, 40), Vector2(20, 20), Vector2(200, 200)]:
		var rect: TextureRect = EquipmentSlotCellScript.make_pixel_art_rect(tex, box)
		var steps: float = rect.custom_minimum_size.x / 32.0
		if box.x >= 32.0:
			_check(steps == floorf(steps) and steps >= 1.0,
				"box %s scales by a whole %d texels" % [box, int(steps)])
		else:
			_check(rect.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
				"box %s: a box smaller than the icon shrinks it smoothly" % box)
		_check(rect.custom_minimum_size.x <= box.x and rect.custom_minimum_size.y <= box.y,
			"box %s: art fits inside the slot" % box)
		rect.free()

func _test_painted_art_shrinks() -> void:
	## The painted art is bigger than any box it sits in: it shrinks to fit,
	## smoothly filtered through its mipmaps.
	print("-- Painted art shrinks to fit --")
	for item in _mythics():
		var slug := item.appearance_icon.get_file().get_basename()
		if slug in GENERATED:
			continue
		var tex: Texture2D = item.get_appearance_texture()
		if tex == null:
			_check(false, "%s loads" % slug)
			continue
		var img := tex.get_image()
		_check(img != null and img.has_mipmaps(), "%s is imported with mipmaps" % slug)
		var solid := 0
		if img:
			img = img.duplicate()
			img.clear_mipmaps()
			img.decompress()
			for y in range(0, img.get_height(), 2):
				for x in range(0, img.get_width(), 2):
					if img.get_pixel(x, y).a > 0.5:
						solid += 1
		var share := float(solid) / (64.0 * 64.0)
		_check(img != null and img.get_pixel(0, 0).a < 0.05 and share > 0.08 and share < 0.9,
			"%s: panel cut away, piece kept (%d%% solid)" % [slug, int(share * 100)])
	# The Bow of Arash's arrow is flipped (designer, 2026-10-23): its cyan
	# fletching sits by the string at the upper left, the head at the lower right.
	var bow_img := ItemData.create("bow_of_arash").get_appearance_texture().get_image()
	bow_img.clear_mipmaps()
	bow_img.decompress()
	var cyan := Vector2.ZERO
	var n := 0
	for y in range(bow_img.get_height()):
		for x in range(bow_img.get_width()):
			var c := bow_img.get_pixel(x, y)
			if c.a > 0.5 and c.b > 0.75 and c.g > 0.75 and c.r < 0.69:
				cyan += Vector2(x, y)
				n += 1
	if n > 0:
		cyan /= n
	_check(n > 50 and cyan.x + cyan.y < 128.0,
		"Bow of Arash: the arrow is flipped, fletching at the upper left (%d px at %s)" % [n, cyan])
	var tex2: Texture2D = ItemData.create("poseidons_trident").get_appearance_texture()
	for box in [Vector2(72, 64), Vector2(34, 34), Vector2(96, 96)]:
		var rect: TextureRect = EquipmentSlotCellScript.make_pixel_art_rect(tex2, box)
		var sz := rect.custom_minimum_size
		_check(sz.x <= box.x and sz.y <= box.y and maxf(sz.x / box.x, sz.y / box.y) > 0.95,
			"box %s: painted art fills it (%s)" % [box, sz])
		_check(rect.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
			"box %s: shrunk art is smoothly filtered" % box)
		rect.free()

func _find_texture_rect(node: Node, tex: Texture2D) -> TextureRect:
	for c in node.find_children("*", "TextureRect", true, false):
		if c.texture == tex:
			return c
	return null

func _test_inventory_shows_art() -> void:
	## The designer: a mythic's picture shows in the inventory, not only once
	## it is equipped — the storage cell, and its detail panel either way.
	print("-- Inventory shows the art --")
	var data := CharacterData.create_brad()
	var stats := PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(data)
	stats.current_level = 60
	var inv := Inventory.new()
	get_root().add_child(inv)
	inv.initialize(data.character_name)
	inv.connect_player_stats(stats)
	var panel = load("res://scenes/character/character_panel.tscn").instantiate()
	get_root().add_child(panel)
	await process_frame
	panel.inventory = inv
	panel.player_stats = stats

	var mythic := ItemData.create("hermes_boots")
	var plain := ItemData.create("leather_cap")
	inv.store_item(mythic)
	inv.store_item(plain)
	var mi := inv.stored_items.find(mythic)
	var pi := inv.stored_items.find(plain)
	var tex := mythic.get_appearance_texture()

	var cell = panel._create_storage_cell(mi)
	_check(_find_texture_rect(cell, tex) != null, "stored Hermes Boots show their art in the inventory cell")
	cell.free()
	var plain_cell = panel._create_storage_cell(pi)
	_check(plain_cell.find_children("ItemArt", "", true, false).is_empty(),
		"a stored non-mythic keeps its text cell")
	plain_cell.free()

	panel._show_detail_panel(mythic, mythic.item_type, -1, mi)
	_check(panel._detail_panel != null and _find_texture_rect(panel._detail_panel, tex) != null,
		"a stored mythic's detail panel shows its art")
	panel._close_detail_panel()

	_check(inv.equip_from_storage(inv.stored_items.find(mythic), 0), "Hermes Boots equip")
	var slot = EquipmentSlotCellScript.new()
	slot.setup(panel, ItemData.ItemType.BOOTS, 0, mythic)
	_check(_find_texture_rect(slot, tex) != null, "equipped Hermes Boots show their art in the slot")
	slot.free()
	panel._show_detail_panel(mythic, mythic.item_type, 0, -1)
	_check(panel._detail_panel != null and _find_texture_rect(panel._detail_panel, tex) != null,
		"an equipped mythic's detail panel shows its art")
	panel._close_detail_panel()
	panel.queue_free()
	inv.queue_free()
	stats.queue_free()

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
