class_name TradeUI
extends Control

## Two-pane trade window between co-op partners. Opened by right-clicking your
## ally and choosing "Trade". Click any item on either side to hand it to the
## other character — equipped items are unequipped first and land in the
## receiver's storage — and the gold buttons pass coins across the same way.

## get_slot_info() key -> ItemType for the equipped sections. Quivers share the
## weapon slots, so the "weapon" entry covers them too; no separate key needed.
const SLOT_TYPES := {
	"helm": ItemData.ItemType.HELM,
	"chest": ItemData.ItemType.CHEST,
	"ring": ItemData.ItemType.RING,
	"belt": ItemData.ItemType.BELT,
	"boots": ItemData.ItemType.BOOTS,
	"gauntlets": ItemData.ItemType.GAUNTLETS,
	"weapon": ItemData.ItemType.WEAPON,
}

var _players: Array = [null, null]  # [side 0, side 1] — Player nodes
var _window: PanelContainer = null
var _title_label: Label = null
var _status_label: Label = null
var _side_headers: Array = [null, null]
var _side_gold_labels: Array = [null, null]
var _side_lists: Array = [null, null]

func _ready() -> void:
	name = "TradeUI"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_window = PanelContainer.new()
	_window.custom_minimum_size = Vector2(860, 540)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.98)
	style.set_border_width_all(2)
	style.border_color = Color(0.45, 0.4, 0.6)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_window.add_theme_stylebox_override("panel", style)
	center.add_child(_window)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_window.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.4))
	vbox.add_child(_title_label)

	var hint := Label.new()
	hint.text = "Click an item to hand it to your partner • Gold buttons share coins • Esc closes"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(hint)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_status_label)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 10)
	vbox.add_child(columns)

	for side in range(2):
		if side == 1:
			columns.add_child(VSeparator.new())
		columns.add_child(_build_side(side))

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(120, 30)
	close_btn.pressed.connect(close)
	var close_wrap := CenterContainer.new()
	close_wrap.add_child(close_btn)
	vbox.add_child(close_wrap)

func _build_side(side: int) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)

	var header := Label.new()
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color",
		Color(0.95, 0.9, 0.7) if side == 0 else Color(1.0, 0.6, 0.35))
	col.add_child(header)
	_side_headers[side] = header

	var gold_row := HBoxContainer.new()
	gold_row.alignment = BoxContainer.ALIGNMENT_CENTER
	gold_row.add_theme_constant_override("separation", 6)
	col.add_child(gold_row)
	var gold_label := Label.new()
	gold_label.add_theme_font_size_override("font_size", 13)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	gold_row.add_child(gold_label)
	_side_gold_labels[side] = gold_label
	for amount in [10, 100, -1]:
		var btn := Button.new()
		btn.text = "Give All" if amount < 0 else "Give %d" % amount
		btn.add_theme_font_size_override("font_size", 11)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_give_gold.bind(side, amount))
		gold_row.add_child(btn)

	col.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_side_lists[side] = list
	return col

func open_trade(a, b) -> void:
	_players[0] = a
	_players[1] = b
	_status_label.text = ""
	_refresh()
	visible = true

func close() -> void:
	visible = false

func is_open() -> bool:
	return visible

func _refresh() -> void:
	if not (_valid(0) and _valid(1)):
		close()
		return
	_title_label.text = "TRADE — %s ⇄ %s" % [_char_name(0), _char_name(1)]
	for side in range(2):
		_side_headers[side].text = _char_name(side)
		_side_gold_labels[side].text = "Gold: %d" % _players[side].get_stats().gold
		_rebuild_list(side)

func _valid(side: int) -> bool:
	var p = _players[side]
	return p != null and is_instance_valid(p) \
			and p.get_stats() != null and p.get_inventory() != null

func _char_name(side: int) -> String:
	var stats = _players[side].get_stats()
	if stats.character_data:
		return stats.character_data.character_name
	return "Player %d" % (side + 1)

func _rebuild_list(side: int) -> void:
	var list: VBoxContainer = _side_lists[side]
	for c in list.get_children():
		c.queue_free()
	var inv: Inventory = _players[side].get_inventory()

	list.add_child(_section_label("EQUIPPED"))
	var slot_info: Dictionary = inv.get_slot_info()
	var any_equipped := false
	for key in SLOT_TYPES:
		if not slot_info.has(key):
			continue
		var equipped: Array = slot_info[key]["equipped"]
		for i in range(equipped.size()):
			if equipped[i] == null:
				continue
			any_equipped = true
			list.add_child(_item_row(equipped[i], true, side, SLOT_TYPES[key], i))
	if not any_equipped:
		list.add_child(_empty_label("(nothing equipped)"))

	list.add_child(_section_label("STORAGE (%d/%d)" % [inv.get_stored_item_count(), inv.max_storage_slots]))
	if inv.stored_items.is_empty():
		list.add_child(_empty_label("(empty)"))
	for i in range(inv.stored_items.size()):
		list.add_child(_item_row(inv.stored_items[i], false, side, 0, i))

func _item_row(item: ItemData, equipped: bool, side: int, item_type: int, index: int) -> Button:
	var btn := Button.new()
	btn.text = "%s — %s" % [item.item_name, item.get_type_name()]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(0.88, 0.88, 0.92))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.4))
	var tip := "Click to give to %s" % _char_name(1 - side)
	if item.description != "":
		tip = item.description + "\n" + tip
	btn.tooltip_text = tip
	if equipped:
		btn.pressed.connect(_on_give_equipped.bind(side, item_type, index))
	else:
		btn.pressed.connect(_on_give_stored.bind(side, index))
	return btn

func _on_give_stored(side: int, index: int) -> void:
	if not (_valid(0) and _valid(1)):
		return
	var receiver: Inventory = _players[1 - side].get_inventory()
	if receiver.is_storage_full():
		_flash("%s's storage is full!" % _char_name(1 - side))
		return
	var item: ItemData = _players[side].get_inventory().remove_stored_item(index)
	if item:
		receiver.store_item(item)
		_flash("%s → %s" % [item.item_name, _char_name(1 - side)], false)
	_refresh()

func _on_give_equipped(side: int, item_type: int, slot_index: int) -> void:
	if not (_valid(0) and _valid(1)):
		return
	var receiver: Inventory = _players[1 - side].get_inventory()
	if receiver.is_storage_full():
		_flash("%s's storage is full!" % _char_name(1 - side))
		return
	var item: ItemData = _players[side].get_inventory().unequip_item(item_type, slot_index)
	if item:
		receiver.store_item(item)
		_flash("%s → %s" % [item.item_name, _char_name(1 - side)], false)
	_refresh()

func _on_give_gold(side: int, amount: int) -> void:
	if not (_valid(0) and _valid(1)):
		return
	var giver: PlayerStats = _players[side].get_stats()
	var to_give: int = giver.gold if amount < 0 else mini(amount, giver.gold)
	if to_give <= 0:
		_flash("%s has no gold to give!" % _char_name(side))
		return
	if giver.spend_gold(to_give):
		_players[1 - side].get_stats().gain_gold(to_give)
		_flash("%d gold → %s" % [to_give, _char_name(1 - side)], false)
	_refresh()

func _flash(msg: String, warn: bool = true) -> void:
	_status_label.add_theme_color_override("font_color",
		Color(1.0, 0.55, 0.4) if warn else Color(0.55, 0.9, 0.55))
	_status_label.text = msg

func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(0.55, 0.55, 0.68))
	return l

func _empty_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.4, 0.4, 0.48))
	return l
