class_name CompendiumPage
extends Control

## Compendium page with Cards, Items, and Enemies tabs.
## Cards sorted by type, Items sorted by type, Enemies alphabetical.
## Each tab has a search bar. Cards show the card itself on hover.
## Items and Enemies show placeholder portrait + hover modal with details.

@onready var tab_container: TabContainer = $Panel/MarginContainer/VBox/TabContainer
@onready var back_button: Button = $Panel/MarginContainer/VBox/BackButton

# Cards tab
var _cards_search: LineEdit
var _cards_container: VBoxContainer
var _cards_scroll: ScrollContainer

# Items tab
var _items_search: LineEdit
var _items_container: VBoxContainer
var _items_scroll: ScrollContainer

# Enemies tab
var _enemies_search: LineEdit
var _enemies_container: VBoxContainer
var _enemies_scroll: ScrollContainer

# Hover popup
var _hover_popup: PanelContainer = null
var _hover_entry: Control = null   # the tile the popup is about (null: none hovered)

# Card tiles still waiting for their face (built as they scroll into view).
const CardUIScene = preload("res://scenes/cards/card_ui.tscn")
const CARD_TILE_SCALE := 1.2       # the card in the Cards tab, over its hand size
const CARD_TILE_PAD := Vector2(0, 12)   # some frames' foot ornaments hang below the card's box
const CARD_FACES_PER_FRAME := 3    # a face costs tens of ms: a few a frame keeps scrolling smooth
const CARD_FACE_REACH := 320.0     # build this far past the scroll's edges, ahead of the eye
var _card_tiles_pending: Array = []

# Data
var _all_cards: Array = []
var _all_items: Array = []
var _all_enemies: Array = []

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_apply_styles()
	_build_data()
	_build_cards_tab()
	_build_items_tab()
	_build_enemies_tab()
	_build_hover_popup()

func _apply_styles() -> void:
	EmeraldTheme.apply(self)
	# The full-screen panel stays clear so the forest shows round the tabs.
	var panel = $Panel as PanelContainer
	if panel:
		var clear := StyleBoxEmpty.new()
		clear.set_content_margin_all(10.0)
		panel.add_theme_stylebox_override("panel", clear)
	if back_button:
		EmeraldTheme.style_button(back_button, 16)
		# Header row: Back on the left, the screen title centred.
		var vbox := back_button.get_parent()
		var header := HBoxContainer.new()
		header.name = "Header"
		vbox.add_child(header)
		vbox.move_child(header, 0)
		back_button.reparent(header)
		back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var title := Label.new()
		title.name = "Title"
		title.text = "Compendium"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		EmeraldTheme.style_title(title, 36)
		header.add_child(title)
		# Balances the Back button so the title sits in the true centre.
		var balance := Control.new()
		balance.custom_minimum_size = back_button.custom_minimum_size
		header.add_child(balance)

## An entry tile: emerald glass with a gold-dim edge, brighter on hover.
static func _tile_box(hover: bool = false) -> StyleBoxFlat:
	var sb := EmeraldTheme.panel_box(
		EmeraldTheme.CARD_HOVER_BG if hover else EmeraldTheme.CARD_BG,
		EmeraldTheme.PALETTE["btn_hover_border"] if hover else EmeraldTheme.GOLD_DIM,
		2 if hover else 1, 4, 8.0)
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 7.0
	sb.shadow_size = 4
	return sb

## Give a tile (_style_tile(panel)) its glass faces, swapped as the mouse
## comes and goes.
func _style_tile(panel: PanelContainer) -> void:
	var normal := _tile_box(false)
	var lit := _tile_box(true)
	panel.add_theme_stylebox_override("panel", normal)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_entered.connect(func(): panel.add_theme_stylebox_override("panel", lit))
	panel.mouse_exited.connect(func(): panel.add_theme_stylebox_override("panel", normal))

func _on_back_pressed() -> void:
	var title_scene = load("res://scenes/menus/title_menu.tscn").instantiate()
	get_tree().root.add_child(title_scene)
	queue_free()

# ============================================
# DATA BUILDING
# ============================================

func _build_data() -> void:
	_build_all_cards()
	_build_all_items()
	_build_all_enemies()

func _build_all_cards() -> void:
	# Every catalogue card except the rank-scaled generated ones.
	_all_cards = []
	for card in Card.get_all_cards(false):
		_all_cards.append(card)

func _build_all_items() -> void:
	_all_items = []
	for item in ItemData.get_all_items():
		_all_items.append(item)

func _build_all_enemies() -> void:
	_all_enemies = Enemy.get_all_enemy_data()

# ============================================
# CARDS TAB
# ============================================

func _build_cards_tab() -> void:
	var cards_tab = tab_container.get_child(0)  # "Cards" tab

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_tab.add_child(vbox)

	_cards_search = LineEdit.new()
	_cards_search.placeholder_text = "Search cards by name..."
	_cards_search.clear_button_enabled = true
	_cards_search.add_theme_font_size_override("font_size", 16)
	_cards_search.text_changed.connect(_on_cards_search_changed)
	vbox.add_child(_cards_search)

	_cards_scroll = ScrollContainer.new()
	_cards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_cards_scroll)

	_cards_container = VBoxContainer.new()
	_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_scroll.add_child(_cards_container)

	_populate_cards("")

func _on_cards_search_changed(new_text: String) -> void:
	_populate_cards(new_text)

func _populate_cards(filter: String) -> void:
	_card_tiles_pending.clear()
	for child in _cards_container.get_children():
		child.queue_free()

	# Group cards by type
	var type_groups: Dictionary = {}
	var type_order = [Card.CardType.ATTACK, Card.CardType.DEFENSE, Card.CardType.UTILITY, Card.CardType.POWER, Card.CardType.REACTION, Card.CardType.ENCHANTMENT, Card.CardType.UNPLAYABLE]
	var type_names = {
		Card.CardType.ATTACK: "Attack",
		Card.CardType.DEFENSE: "Defense",
		Card.CardType.UTILITY: "Utility",
		Card.CardType.POWER: "Power",
		Card.CardType.REACTION: "Instant",
		Card.CardType.ENCHANTMENT: "Enchantment",
		Card.CardType.UNPLAYABLE: "Unplayable",
	}
	var type_colors = {
		Card.CardType.ATTACK: Color(1, 0.3, 0.3),
		Card.CardType.DEFENSE: Color(0.3, 0.5, 1),
		Card.CardType.UTILITY: Color(0.3, 1, 0.3),
		Card.CardType.POWER: Color(0.8, 0.5, 1.0),
		Card.CardType.REACTION: Color(1, 0.8, 0.2),
		Card.CardType.ENCHANTMENT: Color(0.2, 0.9, 0.8),
		Card.CardType.UNPLAYABLE: Color(0.5, 0.5, 0.5),
	}

	for card_type in type_order:
		type_groups[card_type] = []

	for card in _all_cards:
		if filter.length() > 0 and filter.to_lower() not in card.card_name.to_lower():
			continue
		if card.card_type in type_groups:
			type_groups[card.card_type].append(card)

	for card_type in type_order:
		var cards = type_groups[card_type]
		if cards.size() == 0:
			continue

		# Sort cards alphabetically within type
		cards.sort_custom(func(a, b): return a.card_name.to_lower() < b.card_name.to_lower())

		# Type header
		var header = Label.new()
		header.text = type_names[card_type] + " (%d)" % cards.size()
		header.add_theme_font_size_override("font_size", 22)
		header.add_theme_constant_override("outline_size", 4)
		header.add_theme_color_override("font_color", type_colors[card_type])
		_cards_container.add_child(header)

		var sep = HSeparator.new()
		_cards_container.add_child(sep)

		# The cards themselves, as many across as the window holds.
		var grid = HFlowContainer.new()
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		_cards_container.add_child(grid)

		for card in cards:
			var card_panel = _create_card_entry(card, type_colors.get(card.card_type, Color.WHITE))
			grid.add_child(card_panel)

		# Spacer
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 12)
		_cards_container.add_child(spacer)

## A card's tile: the card itself (designer, 2026-11-24; was a box with its
## name, type and cost typed out). The face is built when the tile scrolls
## into view (_build_visible_card_faces) — 300 at once would stall the page —
## and until then the tile shows the card's name on a plain plate.
func _create_card_entry(card: Card, type_color: Color) -> Control:
	var tile := Control.new()
	tile.custom_minimum_size = Vector2(CardUI.CARD_W, CardUI.CARD_H) * CARD_TILE_SCALE + CARD_TILE_PAD
	tile.set_meta("card", card)

	var plate := PanelContainer.new()
	plate.name = "Plate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.position = Vector2.ZERO
	plate.size = Vector2(CardUI.CARD_W, CardUI.CARD_H) * CARD_TILE_SCALE
	_style_tile(plate)
	var name_lbl := Label.new()
	name_lbl.text = card.card_name
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", type_color)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(name_lbl)
	tile.add_child(plate)

	# Hover: the details box. PASS, so the wheel still scrolls the list.
	tile.mouse_filter = Control.MOUSE_FILTER_PASS
	tile.mouse_entered.connect(_on_card_entry_hovered.bind(card, tile))
	tile.mouse_exited.connect(_on_hover_exited)
	_card_tiles_pending.append(tile)
	return tile

## Give a tile its card face (the tile must be in the tree: the face lays
## itself out on setup).
func _build_card_face(tile: Control) -> void:
	_add_card_face(tile, tile.get_meta("card"), CARD_TILE_SCALE)
	var plate = tile.get_node_or_null("Plate")
	if plate:
		plate.queue_free()

## The card's real face at `sc` times its hand size, filling `holder` from
## its top-left corner (the holder must be in the tree: the face lays itself
## out on setup).
func _add_card_face(holder: Control, card: Card, sc: float) -> CardUI:
	var face: CardUI = CardUIScene.instantiate()
	face.scale = Vector2.ONE * sc
	holder.add_child(face)
	face.setup(card, 0)
	# A hand card scales about its bottom centre (the fan); this one grows
	# from its corner to fill the tile, and takes no clicks or hover lift.
	face.pivot_offset = Vector2.ZERO
	face.position = Vector2.ZERO
	for n in face.find_children("*", "Control", true, false):
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kb = face.get_node_or_null("Panel/KeybindBadge")
	if kb:
		kb.visible = false
	return face

## Faces for the tiles in (or about to scroll into) view, a few a frame.
func _build_visible_card_faces() -> void:
	if _card_tiles_pending.is_empty() or _cards_scroll == null or not _cards_scroll.is_visible_in_tree():
		return
	var view: Rect2 = _cards_scroll.get_global_rect().grow(CARD_FACE_REACH)
	var built := 0
	var i := 0
	while i < _card_tiles_pending.size() and built < CARD_FACES_PER_FRAME:
		var tile = _card_tiles_pending[i]
		if not is_instance_valid(tile) or tile.is_queued_for_deletion():
			_card_tiles_pending.remove_at(i)
			continue
		if tile.is_inside_tree() and view.intersects(tile.get_global_rect()):
			_card_tiles_pending.remove_at(i)
			_build_card_face(tile)
			built += 1
			continue
		i += 1

func _process(_delta: float) -> void:
	_build_visible_card_faces()
	# The details box keeps to the screen as its text settles (wrapped rules
	# and keyword lines find their height over a few frames).
	if _hover_popup and _hover_popup.visible:
		_place_hover_popup()

const CARD_ZOOM_SCALE := 1.9   # the hovered card, zoomed in inside its details box
const CARD_ZOOM_INSET := Vector2(14, 14)

func _on_card_entry_hovered(card: Card, entry: Control) -> void:
	_clear_hover_popup()

	# The card itself, zoomed in, on the left of the box (designer,
	# 2026-11-24); its details and keyword rules on the right.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_hover_popup.add_child(row)
	var zoom := Control.new()
	zoom.name = "CardZoom"
	zoom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# (Room all round: frames' ornaments and the cost badges overhang the card's box.)
	zoom.custom_minimum_size = Vector2(CardUI.CARD_W, CardUI.CARD_H) * CARD_ZOOM_SCALE \
		+ CARD_ZOOM_INSET * 2.0 + CARD_TILE_PAD * CARD_ZOOM_SCALE
	zoom.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(zoom)
	_add_card_face(zoom, card, CARD_ZOOM_SCALE).position = CARD_ZOOM_INSET

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	row.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = card.card_name
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", EmeraldTheme.GOLD)
	vbox.add_child(name_lbl)

	var type_lbl = Label.new()
	type_lbl.text = card.card_type_name
	type_lbl.add_theme_font_size_override("font_size", 13)
	match card.card_type:
		Card.CardType.ATTACK:
			type_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		Card.CardType.DEFENSE:
			type_lbl.add_theme_color_override("font_color", Color(0.3, 0.5, 1))
		Card.CardType.UTILITY:
			type_lbl.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
		Card.CardType.POWER:
			type_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
		Card.CardType.REACTION:
			type_lbl.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
		Card.CardType.ENCHANTMENT:
			type_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.8))
		Card.CardType.UNPLAYABLE:
			type_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(type_lbl)

	var cost_lbl = Label.new()
	if card.maintain_cost > 0:
		cost_lbl.text = "Cost: %dM / %dT | Maintain: %dM" % [card.mana_cost, card.tempo_cost, card.maintain_cost]
	else:
		cost_lbl.text = "Cost: %dM / %dT" % [card.mana_cost, card.tempo_cost]
	cost_lbl.add_theme_font_size_override("font_size", 13)
	cost_lbl.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
	vbox.add_child(cost_lbl)

	var rarity_lbl = Label.new()
	rarity_lbl.text = "Rarity: %s" % card.get_rarity_name()
	rarity_lbl.add_theme_font_size_override("font_size", 13)
	rarity_lbl.add_theme_color_override("font_color", card.get_rarity_color())
	vbox.add_child(rarity_lbl)

	if card.damage > 0:
		var dmg_lbl = Label.new()
		dmg_lbl.text = "Damage: %d" % card.damage
		dmg_lbl.add_theme_font_size_override("font_size", 13)
		dmg_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
		vbox.add_child(dmg_lbl)

	if card.block > 0:
		var blk_lbl = Label.new()
		blk_lbl.text = "Block: %d" % card.block
		blk_lbl.add_theme_font_size_override("font_size", 13)
		blk_lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
		vbox.add_child(blk_lbl)

	if card.heal_amount > 0:
		var heal_lbl = Label.new()
		heal_lbl.text = "Heal: %d" % card.heal_amount
		heal_lbl.add_theme_font_size_override("font_size", 13)
		heal_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		vbox.add_child(heal_lbl)

	if card.is_ranged:
		var range_lbl = Label.new()
		range_lbl.text = card.get_range_display()
		range_lbl.add_theme_font_size_override("font_size", 13)
		range_lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 0.9))
		vbox.add_child(range_lbl)

	if card.is_aoe:
		var aoe_lbl = Label.new()
		aoe_lbl.text = "AOE: %s" % card.aoe_shape.capitalize()
		aoe_lbl.add_theme_font_size_override("font_size", 13)
		aoe_lbl.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
		vbox.add_child(aoe_lbl)

	if card.sticky > 0:
		var sticky_lbl = Label.new()
		sticky_lbl.text = "Sticky %d" % card.sticky
		sticky_lbl.add_theme_font_size_override("font_size", 13)
		sticky_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
		vbox.add_child(sticky_lbl)

	if card.has_on_draw:
		var od_lbl = Label.new()
		od_lbl.text = "On-Draw effect"
		od_lbl.add_theme_font_size_override("font_size", 13)
		od_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
		vbox.add_child(od_lbl)

	if card.maintain_cost > 0:
		var maintain_lbl = Label.new()
		maintain_lbl.text = "Maintain: %dM" % card.maintain_cost
		maintain_lbl.add_theme_font_size_override("font_size", 13)
		maintain_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
		vbox.add_child(maintain_lbl)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var desc_lbl = RichTextLabel.new()
	desc_lbl.bbcode_enabled = true
	desc_lbl.text = card.description
	desc_lbl.fit_content = true
	desc_lbl.scroll_active = false
	desc_lbl.custom_minimum_size = Vector2(290, 0)
	desc_lbl.add_theme_font_size_override("normal_font_size", 14)
	vbox.add_child(desc_lbl)

	# Keyword tooltips
	var keywords = card.get_matching_keywords()
	if keywords.size() > 0:
		var kw_sep = HSeparator.new()
		vbox.add_child(kw_sep)

		var kw_header = Label.new()
		kw_header.text = "Keywords:"
		kw_header.add_theme_font_size_override("font_size", 13)
		kw_header.add_theme_color_override("font_color", EmeraldTheme.GOLD)
		vbox.add_child(kw_header)

		for kw in keywords:
			var kw_label = RichTextLabel.new()
			kw_label.bbcode_enabled = true
			kw_label.text = "[color=#cc88ff]%s[/color]: %s" % [kw["keyword"], kw["definition"]]
			kw_label.fit_content = true
			kw_label.scroll_active = false
			kw_label.custom_minimum_size = Vector2(290, 0)
			kw_label.add_theme_font_size_override("normal_font_size", 13)
			kw_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(kw_label)

	_show_hover_popup(entry)

# ============================================
# ITEMS TAB
# ============================================

func _build_items_tab() -> void:
	var items_tab = tab_container.get_child(1)  # "Items" tab

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_tab.add_child(vbox)

	_items_search = LineEdit.new()
	_items_search.placeholder_text = "Search items by name..."
	_items_search.clear_button_enabled = true
	_items_search.add_theme_font_size_override("font_size", 16)
	_items_search.text_changed.connect(_on_items_search_changed)
	vbox.add_child(_items_search)

	_items_scroll = ScrollContainer.new()
	_items_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_items_scroll)

	_items_container = VBoxContainer.new()
	_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_scroll.add_child(_items_container)

	_populate_items("")

func _on_items_search_changed(new_text: String) -> void:
	_populate_items(new_text)

# The Items tab's weapon sections (keys beside the ItemType ones).
const WEAPON_MELEE := "weapon_melee"
const WEAPON_RANGED := "weapon_ranged"
const WEAPON_MAGIC := "weapon_magic"
const WEAPON_SHIELD := "weapon_shield"

## Which Items-tab section an item is listed under.
static func _item_group(item: ItemData):
	if item.item_type != ItemData.ItemType.WEAPON:
		return item.item_type
	match item.weapon_subtype:
		ItemData.WeaponSubtype.BOW:
			return WEAPON_RANGED
		ItemData.WeaponSubtype.WAND, ItemData.WeaponSubtype.TOME, ItemData.WeaponSubtype.STAFF:
			return WEAPON_MAGIC
		ItemData.WeaponSubtype.SHIELD:
			return WEAPON_SHIELD
	return WEAPON_MELEE

func _populate_items(filter: String) -> void:
	for child in _items_container.get_children():
		child.queue_free()

	# Group items by type; weapons by how they fight (designer, 2026-11-24:
	# they were one category) — the game's own lines: a bow is ranged; wand,
	# book and staff are magic; shields; everything else is melee.
	var type_order = [
		WEAPON_MELEE, WEAPON_RANGED, WEAPON_MAGIC, WEAPON_SHIELD, ItemData.ItemType.HELM, ItemData.ItemType.CHEST,
		ItemData.ItemType.BOOTS, ItemData.ItemType.RING, ItemData.ItemType.BELT,
		ItemData.ItemType.GAUNTLETS, ItemData.ItemType.QUIVER
	]
	var type_names = {
		WEAPON_MELEE: "Melee Weapons",
		WEAPON_RANGED: "Ranged Weapons",
		WEAPON_MAGIC: "Magic Weapons",
		WEAPON_SHIELD: "Shields",
		ItemData.ItemType.HELM: "Helms",
		ItemData.ItemType.CHEST: "Chest Armor",
		ItemData.ItemType.BOOTS: "Boots",
		ItemData.ItemType.RING: "Rings",
		ItemData.ItemType.BELT: "Belts",
		ItemData.ItemType.GAUNTLETS: "Gauntlets",
		ItemData.ItemType.QUIVER: "Quivers",
	}
	var type_colors = {
		WEAPON_MELEE: Color(0.9, 0.4, 0.3),
		WEAPON_RANGED: Color(0.45, 0.8, 0.45),
		WEAPON_MAGIC: Color(0.7, 0.5, 1.0),
		WEAPON_SHIELD: Color(0.5, 0.65, 0.9),
		ItemData.ItemType.HELM: Color(0.6, 0.6, 0.8),
		ItemData.ItemType.CHEST: Color(0.5, 0.7, 0.5),
		ItemData.ItemType.BOOTS: Color(0.6, 0.5, 0.3),
		ItemData.ItemType.RING: Color(1.0, 0.85, 0.3),
		ItemData.ItemType.BELT: Color(0.7, 0.5, 0.3),
		ItemData.ItemType.GAUNTLETS: Color(0.7, 0.55, 0.5),
		ItemData.ItemType.QUIVER: Color(0.3, 0.7, 0.8),
	}

	var type_groups: Dictionary = {}
	for item_type in type_order:
		type_groups[item_type] = []

	for item in _all_items:
		if filter.length() > 0 and filter.to_lower() not in item.item_name.to_lower():
			continue
		var group = _item_group(item)
		if group in type_groups:
			type_groups[group].append(item)

	for item_type in type_order:
		var items = type_groups[item_type]
		if items.size() == 0:
			continue

		items.sort_custom(func(a, b): return a.item_name.to_lower() < b.item_name.to_lower())

		# Type header
		var header = Label.new()
		header.text = type_names[item_type] + " (%d)" % items.size()
		header.add_theme_font_size_override("font_size", 22)
		header.add_theme_constant_override("outline_size", 4)
		header.add_theme_color_override("font_color", type_colors[item_type])
		_items_container.add_child(header)

		var sep = HSeparator.new()
		_items_container.add_child(sep)

		var grid = GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		_items_container.add_child(grid)

		for item in items:
			var item_panel = _create_item_entry(item, type_colors.get(item_type, Color.WHITE))
			grid.add_child(item_panel)

		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 12)
		_items_container.add_child(spacer)

func _create_item_entry(item: ItemData, type_color: Color) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 64)

	_style_tile(panel)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	# Placeholder portrait
	var portrait = ColorRect.new()
	portrait.custom_minimum_size = Vector2(48, 48)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.color = type_color * 0.4
	hbox.add_child(portrait)

	# Portrait icon letter
	var portrait_container = Control.new()
	portrait_container.custom_minimum_size = Vector2(0, 0)
	var icon_label = Label.new()
	icon_label.text = item.item_name[0].to_upper()
	icon_label.add_theme_font_size_override("font_size", 24)
	icon_label.add_theme_color_override("font_color", Color(EmeraldTheme.TEXT, 0.8))
	_centre_in(icon_label)
	portrait.add_child(icon_label)
	# A mythic shows its own picture (designer, 2026-11-24): the painting its
	# inventory cell wears, in place of the letter.
	if item.has_appearance_art():
		icon_label.visible = false
		portrait.color = Color(0, 0, 0, 0.35)
		portrait.add_child(_item_picture(item.get_appearance_texture()))

	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 1)
	hbox.add_child(info_vbox)

	var name_lbl = Label.new()
	name_lbl.text = item.item_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", EmeraldTheme.GOLD)
	info_vbox.add_child(name_lbl)

	var type_lbl = Label.new()
	type_lbl.text = item.get_type_name()
	type_lbl.add_theme_font_size_override("font_size", 13)
	type_lbl.add_theme_color_override("font_color", type_color)
	info_vbox.add_child(type_lbl)

	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_entered.connect(_on_item_entry_hovered.bind(item, panel))
	panel.mouse_exited.connect(_on_hover_exited)

	return panel

## An item's art filling its parent box, aspect kept.
static func _item_picture(tex: Texture2D) -> TextureRect:
	var pic := TextureRect.new()
	pic.name = "Art"
	pic.texture = tex
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return pic

const ITEM_POPUP_ART := Vector2(192, 192)   # a mythic's close-up atop its details

func _on_item_entry_hovered(item: ItemData, entry: PanelContainer) -> void:
	_clear_hover_popup()

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	_hover_popup.add_child(vbox)

	# A mythic's close-up painting heads its details.
	if item.has_appearance_art():
		var art_box := Control.new()
		art_box.name = "ArtBox"
		art_box.custom_minimum_size = ITEM_POPUP_ART
		art_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		art_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_box.add_child(_item_picture(item.get_appearance_large_texture()))
		vbox.add_child(art_box)

	var name_lbl = Label.new()
	name_lbl.text = item.item_name
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", EmeraldTheme.GOLD)
	vbox.add_child(name_lbl)

	var type_lbl = Label.new()
	type_lbl.text = item.get_type_name()
	type_lbl.add_theme_font_size_override("font_size", 13)
	type_lbl.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
	vbox.add_child(type_lbl)

	if item.weight > 0:
		_add_detail_line(vbox, "Weight: %d" % item.weight, EmeraldTheme.TEXT_DIM)

	# Stat bonuses
	if item.strength_bonus != 0:
		_add_detail_line(vbox, "+%d Strength" % item.strength_bonus, Color(0.9, 0.4, 0.3))
	if item.dexterity_bonus != 0:
		_add_detail_line(vbox, "+%d Dexterity" % item.dexterity_bonus, Color(0.4, 0.8, 0.4))
	if item.intelligence_bonus != 0:
		_add_detail_line(vbox, "+%d Intelligence" % item.intelligence_bonus, Color(0.4, 0.5, 1.0))
	if item.wisdom_bonus != 0:
		_add_detail_line(vbox, "+%d Wisdom" % item.wisdom_bonus, Color(0.7, 0.4, 1.0))
	if item.determination_bonus != 0:
		_add_detail_line(vbox, "+%d Determination" % item.determination_bonus, Color(1.0, 0.6, 0.2))
	if item.agility_bonus != 0:
		_add_detail_line(vbox, "+%d Agility" % item.agility_bonus, Color(0.3, 0.9, 0.9))
	if item.health_bonus != 0:
		_add_detail_line(vbox, "+%d Health" % item.health_bonus, Color(0.9, 0.3, 0.3))
	if item.mana_bonus != 0:
		_add_detail_line(vbox, "+%d Mana" % item.mana_bonus, Color(0.3, 0.5, 1.0))
	if item.armor_bonus != 0:
		_add_detail_line(vbox, "+%d Armor" % item.armor_bonus, Color(0.7, 0.7, 0.7))
	if item.unerring_cap_bonus != 0:
		_add_detail_line(vbox, "%+d Unerring cap" % item.unerring_cap_bonus, Color(0.7, 0.7, 0.7))
	if item.hand_size_bonus != 0:
		_add_detail_line(vbox, "+%d Hand Size" % item.hand_size_bonus, Color(0.8, 0.7, 0.4))

	if item.weapon_damage > 0:
		_add_detail_line(vbox, "Weapon Damage: %d" % item.weapon_damage, Color(1.0, 0.5, 0.3))

	if item.fire_damage_percent > 0:
		_add_detail_line(vbox, "+%.0f%% Fire Damage" % item.fire_damage_percent, Color(1.0, 0.5, 0.2))
	if item.ice_damage_percent > 0:
		_add_detail_line(vbox, "+%.0f%% Ice Damage" % item.ice_damage_percent, Color(0.4, 0.7, 1.0))
	if item.ranged_damage_bonus > 0:
		_add_detail_line(vbox, "+%d Ranged Damage" % item.ranged_damage_bonus, Color(0.3, 0.8, 0.9))
	if item.healing_bonus > 0:
		_add_detail_line(vbox, "+%d Healing Bonus" % item.healing_bonus, Color(0.4, 0.9, 0.4))

	# Gauntlet skill
	if item.gauntlet_skill_type != ItemData.GauntletSkillType.NONE:
		var sep = HSeparator.new()
		vbox.add_child(sep)
		var skill_type_str = "Active" if item.gauntlet_skill_type == ItemData.GauntletSkillType.ACTIVE else "Passive"
		_add_detail_line(vbox, "%s Skill: %s" % [skill_type_str, item.gauntlet_skill_name], Color(0.9, 0.6, 0.3))
		_add_detail_line(vbox, item.gauntlet_skill_description, EmeraldTheme.TEXT_DIM)
		if item.gauntlet_skill_type == ItemData.GauntletSkillType.ACTIVE:
			_add_detail_line(vbox, "CD: %d cycles, Cost: %dM" % [item.gauntlet_skill_cooldown, item.gauntlet_skill_mana_cost], EmeraldTheme.TEXT_DIM)

	# Card slots
	if item.total_card_slots() > 0:
		var sep = HSeparator.new()
		vbox.add_child(sep)
		_add_detail_line(vbox, "Card Slots: %s" % ItemData.slot_words(item), Color(0.7, 0.6, 1.0))
		if item.vanilla_slots > 0:
			_add_detail_line(vbox, "Plain slots hold a card without the on-self bonus", EmeraldTheme.TEXT_DIM)
		if item.on_self_damage > 0:
			_add_detail_line(vbox, "On-Self: +%d damage" % item.on_self_damage, Color(0.6, 0.9, 0.6))
		if item.on_self_block > 0:
			_add_detail_line(vbox, "On-Self: +%d block" % item.on_self_block, Color(0.6, 0.9, 0.6))
		if item.on_self_heal > 0:
			_add_detail_line(vbox, "On-Self: +%d heal" % item.on_self_heal, Color(0.6, 0.9, 0.6))
		if item.on_self_self_heal > 0:
			_add_detail_line(vbox, "On-Self: heals you %d on play" % item.on_self_self_heal, Color(0.6, 0.9, 0.6))
		if item.on_self_mana_reduction > 0:
			_add_detail_line(vbox, "On-Self: -%d mana cost" % item.on_self_mana_reduction, Color(0.6, 0.9, 0.6))
		if item.on_self_apply_burn > 0:
			_add_detail_line(vbox, "On-Self: Apply %d Burn" % item.on_self_apply_burn, Color(1.0, 0.5, 0.2))
		if item.on_self_apply_cold > 0:
			_add_detail_line(vbox, "On-Self: Apply %d Cold" % item.on_self_apply_cold, Color(0.4, 0.7, 1.0))

	# Description
	if item.description.length() > 0:
		var sep = HSeparator.new()
		vbox.add_child(sep)
		var desc_lbl = Label.new()
		desc_lbl.text = item.description
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(290, 0)
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
		vbox.add_child(desc_lbl)

	_show_hover_popup(entry)

# ============================================
# ENEMIES TAB
# ============================================

func _build_enemies_tab() -> void:
	var enemies_tab = tab_container.get_child(2)  # "Enemies" tab

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemies_tab.add_child(vbox)

	_enemies_search = LineEdit.new()
	_enemies_search.placeholder_text = "Search enemies by name..."
	_enemies_search.clear_button_enabled = true
	_enemies_search.add_theme_font_size_override("font_size", 16)
	_enemies_search.text_changed.connect(_on_enemies_search_changed)
	vbox.add_child(_enemies_search)

	_enemies_scroll = ScrollContainer.new()
	_enemies_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_enemies_scroll)

	_enemies_container = VBoxContainer.new()
	_enemies_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemies_scroll.add_child(_enemies_container)

	# Each tile's picture is cut from the enemy's battle sprite (about a
	# second for the whole bestiary), so fill the grid the first time the
	# tab is opened rather than when the Compendium loads.
	var enemies_index := enemies_tab.get_index()
	var fill := func(tab: int) -> void:
		if tab == enemies_index and _enemies_container.get_child_count() == 0:
			_populate_enemies(_enemies_search.text)
	tab_container.tab_changed.connect(fill)
	fill.call(tab_container.current_tab)

func _on_enemies_search_changed(new_text: String) -> void:
	_populate_enemies(new_text)

func _populate_enemies(filter: String) -> void:
	for child in _enemies_container.get_children():
		child.queue_free()

	# Already sorted alphabetically in _build_all_enemies
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_enemies_container.add_child(grid)

	for enemy_data in _all_enemies:
		if filter.length() > 0 and filter.to_lower() not in enemy_data["name"].to_lower():
			continue
		var enemy_panel = _create_enemy_entry(enemy_data)
		grid.add_child(enemy_panel)

	# The allies the summon cards raise, after the bestiary (same search).
	var allies: Array = []
	for d in summon_data():
		if filter.length() == 0 or filter.to_lower() in str(d["name"]).to_lower():
			allies.append(d)
	if allies.is_empty():
		return
	var header := Label.new()
	header.text = "Summons — your allies"
	EmeraldTheme.style_heading(header, 22)
	_enemies_container.add_child(header)
	var agrid := GridContainer.new()
	agrid.columns = 3
	agrid.add_theme_constant_override("h_separation", 10)
	agrid.add_theme_constant_override("v_separation", 10)
	_enemies_container.add_child(agrid)
	for d in allies:
		agrid.add_child(_create_enemy_entry(d))

## The summon cards' allies (designer, 2026-10-27), in the bestiary's entry
## shape: stats as summoned, the cards that raise them, what they do.
## Kept beside summoned_skeleton.gd's kinds; test_summon_cards guards those.
static func summon_data() -> Array:
	return [
		{"name": "Skeleton", "type": "Summon", "health": 10, "armor": 0, "damage": 6, "figure_kind": "summon_skeleton",
			"summoned_by": "Summon Skeleton, Skeleton Army (also the Sack of Bone Arrows and Manifest)",
			"actions": [{"name": "Move 1 space", "tempo": 1}, {"name": "Attack", "tempo": 5}],
			"special": "Walks to the nearest enemy and strikes it for 6 every 5 tempo."},
		{"name": "Shadow Hound", "type": "Summon", "health": 10, "armor": 0, "damage": 4, "figure_kind": "shadow_hound",
			"summoned_by": "Summon Shadow Hound",
			"actions": [{"name": "Move 2 spaces", "tempo": 1}, {"name": "Bite", "tempo": 8}],
			"special": "Fast. Bites for 4 every (8 - INT/10) tempo — the smarter its summoner, the quicker (at least every tempo)."},
		{"name": "Battle Turtle", "type": "Summon", "health": 25, "armor": 0, "damage": 0, "figure_kind": "battle_turtle",
			"summoned_by": "Summon Battle Turtle, Turtle Power",
			"actions": [{"name": "Move 1 space", "tempo": 1}],
			"special": "Does not attack. Its armor is capped by its unerring armor (summoner INT / 2); it starts full and regains a fifth of it every 5 tempo. Whatever armor it gains, its allies gain too."},
	]

func _create_enemy_entry(enemy_data: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 72)

	# One colour per sheet tier (Enemy.get_all_enemy_data "type"): Trash
	# grey, Mid-tier the old red, Elite gold, Boss purple, Special teal.
	var type_color = Color(0.8, 0.3, 0.3)
	if enemy_data["type"] == "Trash":
		type_color = Color(0.6, 0.6, 0.6)
	elif enemy_data["type"] == "Mid-tier":
		type_color = Color(0.8, 0.3, 0.3)
	elif enemy_data["type"] == "Elite":
		type_color = Color(0.8, 0.6, 0.2)
	elif enemy_data["type"] == "Boss":
		type_color = Color(0.7, 0.2, 0.5)
	elif enemy_data["type"] == "Special":
		type_color = Color(0.3, 0.7, 0.8)
	elif enemy_data["type"] == "Summon":
		type_color = Color(0.45, 0.85, 0.55)

	_style_tile(panel)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	# The monster as it stands on the field, facing south; its initial
	# on a tier-coloured square when it has no sprite.
	var portrait = ColorRect.new()
	portrait.custom_minimum_size = Vector2(60, 60)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.color = type_color * 0.35
	hbox.add_child(portrait)
	var picture := _enemy_picture(str(enemy_data.get("figure_kind", "")))
	if picture:
		portrait.color = Color(0.01, 0.06, 0.05, 0.7)
		portrait.add_child(picture)
	else:
		var icon_label = Label.new()
		icon_label.text = enemy_data["name"][0].to_upper()
		icon_label.add_theme_font_size_override("font_size", 28)
		icon_label.add_theme_color_override("font_color", Color(EmeraldTheme.TEXT, 0.8))
		_centre_in(icon_label)
		portrait.add_child(icon_label)

	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var name_lbl = Label.new()
	name_lbl.text = enemy_data["name"]
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", EmeraldTheme.GOLD)
	info_vbox.add_child(name_lbl)

	var type_lbl = Label.new()
	type_lbl.text = enemy_data["type"]
	type_lbl.add_theme_font_size_override("font_size", 13)
	type_lbl.add_theme_color_override("font_color", type_color)
	info_vbox.add_child(type_lbl)

	var hp_text = "HP: %d" % enemy_data["health"]
	if enemy_data["armor"] > 0:
		hp_text += "  Armor: %d" % enemy_data["armor"]
	var hp_lbl = Label.new()
	hp_lbl.text = hp_text
	hp_lbl.add_theme_font_size_override("font_size", 13)
	hp_lbl.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
	info_vbox.add_child(hp_lbl)

	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_entered.connect(_on_enemy_entry_hovered.bind(enemy_data, panel))
	panel.mouse_exited.connect(_on_hover_exited)

	return panel

func _on_enemy_entry_hovered(enemy_data: Dictionary, entry: PanelContainer) -> void:
	_clear_hover_popup()

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	_hover_popup.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = enemy_data["name"]
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", EmeraldTheme.GOLD)
	vbox.add_child(name_lbl)

	# A larger look at the monster, south face.
	var big := _enemy_picture(str(enemy_data.get("figure_kind", "")))
	if big:
		var frame := ColorRect.new()
		frame.color = Color(0.01, 0.06, 0.05, 0.7)
		frame.custom_minimum_size = Vector2(0, 150)
		frame.add_child(big)
		vbox.add_child(frame)

	_add_detail_line(vbox, "Type: %s" % enemy_data["type"], EmeraldTheme.TEXT_DIM)
	_add_detail_line(vbox, "Health: %d" % enemy_data["health"], Color(0.9, 0.3, 0.3))
	if enemy_data["armor"] > 0:
		_add_detail_line(vbox, "Armor: %d" % enemy_data["armor"], Color(0.7, 0.7, 0.7))
	_add_detail_line(vbox, "Attack: %d" % enemy_data["damage"], Color(1.0, 0.5, 0.3))
	if enemy_data.has("xp"):
		_add_detail_line(vbox, "XP Reward: %d" % enemy_data["xp"], Color(0.5, 0.9, 0.5))
	if enemy_data.has("summoned_by"):
		var by := Label.new()
		by.text = "Summoned by: %s" % enemy_data["summoned_by"]
		by.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		by.custom_minimum_size = Vector2(290, 0)
		by.add_theme_font_size_override("font_size", 13)
		by.add_theme_color_override("font_color", Color(0.45, 0.85, 0.55))
		vbox.add_child(by)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Actions
	var actions_header = Label.new()
	actions_header.text = "Actions:"
	actions_header.add_theme_font_size_override("font_size", 14)
	actions_header.add_theme_color_override("font_color", EmeraldTheme.GOLD)
	vbox.add_child(actions_header)

	for action in enemy_data["actions"]:
		var line: String = "  %s (Tempo: %d)" % [action["name"], action["tempo"]]
		var kws: Array = action.get("keywords", [])
		if not kws.is_empty():
			line += "  ·  " + " · ".join(PackedStringArray(kws))
		_add_detail_line(vbox, line, EmeraldTheme.TEXT_DIM)

	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# Special / AI
	var special_lbl = Label.new()
	special_lbl.text = enemy_data["special"]
	special_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	special_lbl.custom_minimum_size = Vector2(290, 0)
	special_lbl.add_theme_font_size_override("font_size", 13)
	special_lbl.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
	vbox.add_child(special_lbl)

	_show_hover_popup(entry)

# ============================================
# HOVER POPUP SYSTEM
# ============================================

func _build_hover_popup() -> void:
	_hover_popup = PanelContainer.new()
	_hover_popup.name = "HoverPopup"
	_hover_popup.custom_minimum_size = Vector2(300, 0)
	_hover_popup.visible = false
	_hover_popup.z_index = 200
	_hover_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := EmeraldTheme.panel_box(EmeraldTheme.PANEL_BG_SOLID, EmeraldTheme.GOLD, 2, 6, 12.0)
	_hover_popup.add_theme_stylebox_override("panel", style)

	add_child(_hover_popup)

## The monster's south-facing idle frame (SpriteEnemyFigure.south_still),
## filling its parent box with the aspect kept; null when it has no sprite.
static func _enemy_picture(kind: String) -> TextureRect:
	if kind == "":
		return null
	var still: Dictionary = SpriteEnemyFigure.south_still(kind)
	if still.is_empty():
		return null
	var pic := TextureRect.new()
	pic.texture = still["texture"]
	pic.modulate = still["tint"]
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Pixel art stays crisp; the designer's painted boards stay smooth.
	if not still["smooth"]:
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = 3
	pic.offset_top = 3
	pic.offset_right = -3
	pic.offset_bottom = -3
	return pic

## A placeholder portrait's initial, centred in its box.
static func _centre_in(label: Label) -> void:
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _clear_hover_popup() -> void:
	# Detach the old details now (not at frame end) and drop the old size,
	# so the popup grows to fit only the new entry's details.
	for child in _hover_popup.get_children():
		_hover_popup.remove_child(child)
		child.queue_free()
	_hover_popup.size = Vector2.ZERO

const POPUP_GAP := 10.0      # between the tile and its details box
const SCREEN_MARGIN := 6.0

func _show_hover_popup(entry: Control) -> void:
	_hover_entry = entry
	await get_tree().process_frame  # Wait for layout
	if _hover_entry != entry or not is_instance_valid(entry):
		return   # the mouse moved on meanwhile
	_place_hover_popup()
	_hover_popup.visible = true

## Beside the hovered tile (right if there is room, else left, else against
## the right edge), level with its top, and always wholly on screen: pushed
## up from the bottom edge, and shrunk if it is taller than the screen.
## Called every frame the box shows, so it follows its text's final height.
func _place_hover_popup() -> void:
	if _hover_entry == null or not is_instance_valid(_hover_entry):
		return
	var vp: Vector2 = get_viewport_rect().size
	var entry_rect: Rect2 = _hover_entry.get_global_rect()
	_hover_popup.scale = Vector2.ONE
	_hover_popup.reset_size()
	var sz: Vector2 = _hover_popup.size
	var fit: float = minf(1.0, (vp.y - 2.0 * SCREEN_MARGIN) / maxf(1.0, sz.y))
	_hover_popup.scale = Vector2(fit, fit)
	var w: float = sz.x * fit
	var h: float = sz.y * fit
	var x: float
	if vp.x - entry_rect.end.x - POPUP_GAP - SCREEN_MARGIN >= w:
		x = entry_rect.end.x + POPUP_GAP
	elif entry_rect.position.x - POPUP_GAP - SCREEN_MARGIN >= w:
		x = entry_rect.position.x - POPUP_GAP - w
	else:
		x = vp.x - SCREEN_MARGIN - w
	x = clampf(x, SCREEN_MARGIN, maxf(SCREEN_MARGIN, vp.x - SCREEN_MARGIN - w))
	var y: float = clampf(entry_rect.position.y, SCREEN_MARGIN, maxf(SCREEN_MARGIN, vp.y - SCREEN_MARGIN - h))
	_hover_popup.global_position = Vector2(x, y)

func _on_hover_exited() -> void:
	_hover_entry = null
	_hover_popup.visible = false

func _add_detail_line(parent: VBoxContainer, text: String, color: Color) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)
