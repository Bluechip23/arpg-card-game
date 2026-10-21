class_name CardSlotCell
extends PanelContainer

## One square of the manage-cards window. Three kinds:
##   "slot" — an item's card slot: rounded square whose trim says what the
##            slot is (gold = on-self, the slot's own colour on a coloured-slot
##            item, cream = vanilla, which also reads "vanilla" inside). Drop
##            a card on it to slot the card THERE; drag its card away or
##            right-click to unslot.
##   "chip" — a card from the deck that can go into the item: drag it onto a
##            slot, or click it to take the first free slot.
##   "zone" — the pool area: dropping a slotted card here unslots it.

const SIZE := Vector2(76, 100)
const CHIP_SIZE := Vector2(76, 44)
const TRIM := {
	"on_self": Color(0.85, 0.7, 0.35),
	"vanilla": Color(0.93, 0.88, 0.75),
	"red": Color(1.0, 0.45, 0.45), "blue": Color(0.45, 0.6, 1.0),
	"yellow": Color(0.95, 0.85, 0.35), "green": Color(0.45, 0.85, 0.5),
}

var kind: String = "slot"
var item: ItemData = null
var slot_index: int = -1
var card: Card = null
var _panel = null
var _trim: Color = TRIM["on_self"]

static func trim_for(it: ItemData, index: int) -> Color:
	if index >= it.card_slots:
		return TRIM["vanilla"]
	if index < it.slot_colors.size():
		return TRIM.get(str(it.slot_colors[index]), TRIM["on_self"])
	return TRIM["on_self"]

static func kind_label(it: ItemData, index: int) -> String:
	if index >= it.card_slots:
		return "Vanilla"
	if index < it.slot_colors.size():
		return str(it.slot_colors[index]).capitalize()
	return "On-self"

func setup_slot(panel, it: ItemData, index: int, c: Card) -> void:
	kind = "slot"
	_panel = panel
	item = it
	slot_index = index
	card = c
	_trim = trim_for(it, index)
	custom_minimum_size = SIZE
	_style(_trim, card != null)
	_fill_slot()
	tooltip_text = _slot_tip()

func setup_chip(panel, it: ItemData, c: Card) -> void:
	kind = "chip"
	_panel = panel
	item = it
	card = c
	_trim = Color(0.5, 0.55, 0.75)
	custom_minimum_size = CHIP_SIZE
	_style(_trim, true)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(v)
	var name_l := _label(c.card_name, 10, Color(0.85, 0.85, 0.95))
	v.add_child(name_l)
	if c.is_slottable():
		v.add_child(_label(c.slot_label_names(), 8, Color(0.6, 0.6, 0.75)))
	tooltip_text = "%s\n%s\nDrag onto a slot, or click for the first free one." % [c.card_name, c.description]

func setup_zone(panel, it: ItemData) -> void:
	kind = "zone"
	_panel = panel
	item = it
	mouse_filter = Control.MOUSE_FILTER_PASS
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.05, 0.1, 0.6)
	st.set_border_width_all(1)
	st.border_color = Color(0.3, 0.3, 0.45)
	st.set_corner_radius_all(8)
	st.content_margin_left = 6
	st.content_margin_right = 6
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	add_theme_stylebox_override("panel", st)

func _style(trim: Color, filled: bool) -> void:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.13, 0.11, 0.2, 1.0) if filled else Color(0.09, 0.08, 0.14, 1.0)
	st.set_border_width_all(2)
	st.border_color = trim
	st.set_corner_radius_all(10)
	st.content_margin_left = 4
	st.content_margin_right = 4
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	add_theme_stylebox_override("panel", st)

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _fill_slot() -> void:
	for ch in get_children():
		ch.queue_free()
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	add_child(v)
	# The slot's kind, in its trim colour, along the top.
	v.add_child(_label(kind_label(item, slot_index), 9, _trim))
	if card == null:
		var mid := _label("vanilla" if slot_index >= item.card_slots else "empty", 11,
			_trim if slot_index >= item.card_slots else Color(0.4, 0.4, 0.5))
		mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		mid.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		v.add_child(mid)
		return
	var tex := SkillIconArt.card(card)
	if tex:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(icon)
	var nm := _label(card.card_name, 10, Color(0.9, 0.9, 1.0))
	nm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(nm)

func _slot_tip() -> String:
	var what: String
	if slot_index >= item.card_slots:
		what = "Vanilla slot: holds a card, grants no on-self bonus."
	elif slot_index < item.slot_colors.size():
		what = "%s slot: this slot's own effect rides the card here." % str(item.slot_colors[slot_index]).capitalize()
	else:
		what = "On-self slot: the item's on-self bonus rides the card here."
	if card:
		return "%s\n%s\nDrag away or right-click to remove." % [card.card_name, what]
	return "%s\nDrop a card here." % what

# ---------------------------------------------------------------------------
# Drag & drop
# ---------------------------------------------------------------------------

func _get_drag_data(_at_position: Vector2) -> Variant:
	if card == null or kind == "zone":
		return null
	if _panel and _panel.has_method("_make_drag_preview"):
		set_drag_preview(_panel._make_drag_preview(card.card_name, _trim))
	return {"kind": "card", "source": "slot" if kind == "slot" else "pool",
		"card": card, "item": item, "slot_index": slot_index}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or data.get("kind") != "card":
		return false
	var dragged: Card = data.get("card")
	if dragged == null:
		return false
	match kind:
		"zone":
			return data.get("source") == "slot" and data.get("item") == item
		"slot":
			if card != null:
				return false
			if data.get("source") == "slot":
				# Moving between two squares of the same item.
				return data.get("item") == item and item.can_move_slotted_card_to(dragged, slot_index)
			return item.can_slot_card_at(dragged, slot_index)
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _panel == null:
		return
	if kind == "zone":
		_panel._handle_card_drop_on_pool(data)
	elif kind == "slot":
		_panel._handle_card_drop_on_slot(data, item, slot_index)

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed) or _panel == null:
		return
	if kind == "chip" and event.button_index == MOUSE_BUTTON_LEFT and card:
		_panel._on_slot_card(card, item)
	elif kind == "slot" and event.button_index == MOUSE_BUTTON_RIGHT and card:
		_panel._on_unslot_card_object(item, card)
