class_name StorageItemCell
extends PanelContainer

## A cell in the inventory storage grid. Acts as a drag source for the item it
## holds (drag it onto a matching equipment slot to equip) and as a drop target
## for equipped items being dragged back into storage (to unequip them).

var _panel: CharacterPanel = null
var index: int = 0
var item: ItemData = null

func setup(char_panel: CharacterPanel, i: int, itm: ItemData) -> void:
	_panel = char_panel
	index = i
	item = itm
	mouse_filter = Control.MOUSE_FILTER_STOP

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not item:
		return null
	var preview := _panel._make_drag_preview(item.item_name, _panel._get_item_type_color(item.item_type))
	set_drag_preview(preview)
	return {
		"kind": "item",
		"source": "storage",
		"item": item,
		"storage_index": index,
	}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	# Only equipped items dropped back here get unequipped into storage.
	return data.get("kind") == "item" and data.get("source") == "equipped"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_panel._handle_item_drop_on_storage(data)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if item and _panel:
			_panel._on_stored_item_clicked(item, index)
