class_name EquipmentSlotCell
extends Panel

## A single equipment slot rendered as a square. Shows a shadowed silhouette of
## its slot type; when an item is equipped it also shows the item's title and,
## if the item has card slots, a small card sub-slot in the bottom-right corner.
##
## Drag & drop:
##  - Drag an item from storage onto a matching-type slot to equip it.
##  - Drag an equipped item onto another slot of the same type to move/swap it.
##  - Drag an equipped item onto the storage grid to unequip it.
## Only items whose type matches the slot are accepted (belts to belt slots, etc.).

const SLOT_SIZE := Vector2(84, 84)

# Preloaded (not referenced by class_name) so this script compiles without those
# classes being in Godot's global class cache. _panel is left untyped to avoid a
# compile cycle back to CharacterPanel, which preloads this script.
const ItemSilhouetteScript = preload("res://scripts/character/item_silhouette.gd")
const InventoryCardSlotScript = preload("res://scripts/character/inventory_card_slot.gd")

var _panel = null  # CharacterPanel
var item_type: int = 0
var slot_index: int = 0
var item: ItemData = null
var _label_override: String = ""

func setup(char_panel, i_type: int, i_index: int, itm: ItemData, cell_size: Vector2 = SLOT_SIZE, label_override: String = "") -> void:
	_panel = char_panel
	item_type = i_type
	slot_index = i_index
	item = itm
	_label_override = label_override
	custom_minimum_size = cell_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_style()
	_build_children()

func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.set_border_width_all(2)
	if item:
		style.bg_color = Color(0.16, 0.16, 0.22, 1.0)
		style.border_color = _panel._get_item_type_color(item.item_type)
	else:
		style.bg_color = Color(0.09, 0.09, 0.12, 1.0)
		style.border_color = Color(0.22, 0.22, 0.28)
	add_theme_stylebox_override("panel", style)

func _build_children() -> void:
	for c in get_children():
		c.queue_free()

	# Shadowed silhouette fills the square (the equipped item's own type when
	# filled, e.g. a quiver sitting in a weapon slot shows a quiver shadow).
	var sil = ItemSilhouetteScript.new()
	sil.setup(item.item_type if item else item_type, item == null)
	sil.set_anchors_preset(Control.PRESET_FULL_RECT)
	sil.offset_top = 4
	sil.offset_bottom = -16
	sil.offset_left = 6
	sil.offset_right = -6
	add_child(sil)

	# Bottom label: item title when equipped, slot type name when empty.
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_bottom = -2
	label.offset_top = -16
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if item:
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
		label.text = item.item_name
		tooltip_text = _build_item_tooltip()
	else:
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
		label.text = _label_override if _label_override != "" else _panel._slot_type_name(item_type)
	add_child(label)

	# Card sub-slot in the bottom-right corner (only if the item has card slots).
	if item and item.has_card_slots():
		var card_slot = InventoryCardSlotScript.new()
		card_slot.setup(_panel, item)
		card_slot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		card_slot.offset_left = -26
		card_slot.offset_top = -26
		card_slot.offset_right = -3
		card_slot.offset_bottom = -3
		add_child(card_slot)

func _build_item_tooltip() -> String:
	var lines: Array[String] = [item.item_name, item.get_type_name()]
	if item.description != "":
		lines.append(item.description)
	lines.append("Drag to move • Click for details")
	return "\n".join(lines)

# ---------------------------------------------------------------------------
# Drag & drop
# ---------------------------------------------------------------------------

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not item:
		return null
	var preview = _panel._make_drag_preview(item.item_name, _panel._get_item_type_color(item.item_type))
	set_drag_preview(preview)
	return {
		"kind": "item",
		"source": "equipped",
		"item": item,
		"item_type": item_type,
		"slot_index": slot_index,
	}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if data.get("kind") != "item":
		return false
	var dragged: ItemData = data.get("item")
	if dragged == null:
		return false
	if dragged.item_type == item_type:
		return true
	# Quivers occupy a weapon (main/off-hand) slot — accept them there too.
	return item_type == ItemData.ItemType.WEAPON and dragged.item_type == ItemData.ItemType.QUIVER

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_panel._handle_item_drop_on_slot(data, item_type, slot_index)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if item and _panel:
			_panel._on_equipped_item_clicked(item, item_type, slot_index)
