extends SceneTree

## Designer's Compendium pass, 2026-11-24:
##  - the Cards tab shows the cards themselves (their real faces, built as
##    they scroll into view);
##  - a hovered tile's details box always lands wholly on screen, however
##    low the tile sits;
##  - every mythic item shows its painting, on its tile and in its details.
## Run: godot --headless --path . --script tests/test_compendium_cards_1124.gd

var failures := 0
var page = null

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _settle(frames: int = 8) -> void:
	for _i in range(frames):
		await process_frame

func _tiles(box: Node) -> Array:
	var out: Array = []
	for child in box.get_children():
		if child is GridContainer or child is FlowContainer:
			out.append_array(child.get_children())
	return out

func _popup_on_screen() -> bool:
	var pop: Control = page._hover_popup
	var screen := Rect2(Vector2.ZERO, get_root().get_visible_rect().size)
	return pop.visible and screen.grow(0.5).encloses(Rect2(pop.global_position, pop.size * pop.scale))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("=== Compendium pass 2026-11-24 ===")
	page = (load("res://scenes/ui/compendium_page.tscn") as PackedScene).instantiate()
	get_root().add_child(page)
	await _settle(30)
	var screen: Vector2 = get_root().get_visible_rect().size

	print("--- cards ---")
	var tiles := _tiles(page._cards_container)
	_check(tiles.size() == page._all_cards.size() and tiles.size() > 0, "one tile per card")
	var first: Control = tiles[0]
	var faces: Array = first.find_children("*", "CardUI", true, false)
	_check(faces.size() == 1 and faces[0]._card == first.get_meta("card"), "a tile in view is the card's own face")
	var last: Control = tiles[tiles.size() - 1]
	_check(last.find_children("*", "CardUI", true, false).is_empty(), "a tile far down the list waits for its face")
	page._cards_scroll.scroll_vertical = 1000000
	await _settle(40)
	_check(last.find_children("*", "CardUI", true, false).size() == 1, "and gets it once scrolled into view")

	# The lowest tile on screen: its details box must not run off the bottom.
	var low: Control = null
	for t in tiles:
		var r: Rect2 = t.get_global_rect()
		if r.position.y < screen.y - 40.0 and (low == null or r.position.y > low.get_global_rect().position.y):
			low = t
	_check(low != null and low.get_global_rect().position.y > screen.y * 0.5, "a tile below the middle of the screen is hovered")
	# (2026-11-25) The box waits a second on the card before it shows.
	_check(is_equal_approx(page.card_hover_delay, 1.0), "the card details box waits 1 second")
	page.card_hover_delay = 0.4
	low.mouse_entered.emit()
	await _settle(6)
	_check(not page._hover_popup.visible, "hovering a card does not show the box at once")
	low.mouse_exited.emit()
	await create_timer(0.6).timeout
	_check(not page._hover_popup.visible, "leaving before the wait is up shows nothing")
	low.mouse_entered.emit()
	await create_timer(0.6).timeout
	await _settle(6)
	_check(_popup_on_screen(), "resting on it brings the box up, wholly on screen")
	page.card_hover_delay = 0.0
	var zoomed: Array = page._hover_popup.find_children("*", "CardUI", true, false)
	_check(zoomed.size() == 1 and zoomed[0]._card == low.get_meta("card") and zoomed[0].scale.x > page.CARD_TILE_SCALE,
		"the box holds the hovered card itself, zoomed in")
	low.mouse_exited.emit()

	# Every card, hovered at the bottom edge: the box still fits.
	var worst := ""
	for card in page._all_cards:
		page._on_card_entry_hovered(card, low)
		await _settle(4)
		if not _popup_on_screen():
			worst = card.card_name
			break
	_check(worst == "", "every card's details box fits on screen from a bottom tile%s" % ("" if worst == "" else " (not: %s)" % worst))
	page._on_hover_exited()
	await _settle(3)
	_check(not page._hover_popup.visible, "leaving the tile hides the box")

	print("--- mythic items ---")
	page.tab_container.current_tab = 1
	await _settle(6)
	var heads: Array = []
	for child in page._items_container.get_children():
		if child is Label:
			heads.append(child.text.get_slice(" (", 0))
	_check(heads.slice(0, 4) == ["Melee Weapons", "Ranged Weapons", "Magic Weapons", "Shields"] and not ("Weapons" in heads),
		"weapons are listed as melee, ranged, magic and shields")
	var groups := {}
	for it in page._all_items:
		groups[it.item_name] = page._item_group(it)
	_check(groups.get("Long Bow") == page.WEAPON_RANGED and groups.get("Magic Staff") == page.WEAPON_MAGIC
		and groups.get("Fire Book") == page.WEAPON_MAGIC and groups.get("Buckler") == page.WEAPON_SHIELD
		and groups.get("Wooden Sword") == page.WEAPON_MELEE, "a bow, a staff, a book, a shield and a sword each land in their section")
	var mythics := 0
	var bare: Array = []
	var plain_with_art := 0
	var item_tiles := _tiles(page._items_container)
	var a_mythic_tile: Control = null
	var a_mythic: ItemData = null
	# Tiles are built in the list's own order per type; match by name label.
	var by_name := {}
	for it in page._all_items:
		by_name[it.item_name] = it
	for t in item_tiles:
		var item: ItemData = null
		for l in t.find_children("*", "Label", true, false):
			if by_name.has(l.text):
				item = by_name[l.text]
				break
		if item == null:
			continue
		var art: TextureRect = t.find_child("Art", true, false)
		if item.rarity == ItemData.Rarity.MYTHIC:
			mythics += 1
			if art == null or art.texture == null:
				bare.append(item.item_name)
			elif a_mythic_tile == null:
				a_mythic_tile = t
				a_mythic = item
		elif art != null:
			plain_with_art += 1
	_check(mythics > 0 and bare.is_empty(), "all %d mythics show their picture on their tile%s" % [mythics, "" if bare.is_empty() else " (missing: %s)" % ", ".join(bare)])
	_check(plain_with_art == 0, "items without art keep their letter")
	if a_mythic_tile:
		page._on_item_entry_hovered(a_mythic, a_mythic_tile)
		await _settle(8)
		var big: TextureRect = page._hover_popup.find_child("Art", true, false)
		_check(big != null and big.texture != null, "a mythic's details box is headed by its painting")
		_check(_popup_on_screen(), "and sits wholly on screen")

	print("--- buffs & debuffs ---")
	var tab: Control = page.tab_container.get_node_or_null(page.STATUS_TAB_NAME)
	_check(tab != null, "the Compendium has a Buffs & Debuffs tab")
	page.tab_container.current_tab = tab.get_index()
	await _settle(6)
	var names: Array = []
	var blank: Array = []
	for t in _tiles(page._statuses_container):
		names.append(t.get_meta("status"))
		var d: Label = t.find_child("Desc", true, false)
		if d == null or d.text.strip_edges() == "":
			blank.append(t.get_meta("status"))
	_check(names.size() == KeywordLegend.BUFFS.size() + KeywordLegend.DEBUFFS.size() and names.size() > 30,
		"it lists the %d standard buffs and debuffs" % names.size())
	var want_all := true
	for n in ["Strengthen", "Attune", "Regen", "Keen", "Cold", "Frozen", "Burn", "Vulnerable"]:
		want_all = want_all and n in names
	_check(want_all, "Strengthen, Attune, Regen, Keen, Cold, Frozen, Burn and Vulnerable are there")
	_check(blank.is_empty(), "each says what it does")
	var one_offs := false
	for n in names:
		if "narashimha" in n.to_lower() or n in ["Polymorph", "Shield Ready", "Demonic Rage", "Lost", "Engrave"]:
			one_offs = true
	_check(not one_offs, "one-off item effects (Narashimha's and the like) are not listed")
	page._statuses_search.text = "stre"
	page._populate_statuses("stre")
	await _settle(4)
	var hits: Array = []
	for t in _tiles(page._statuses_container):
		if not t.is_queued_for_deletion():
			hits.append(t.get_meta("status"))
	_check(hits == ["Strengthen"], "the search narrows the list")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
