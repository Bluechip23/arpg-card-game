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
const UIGlyphsScript = preload("res://scripts/ui/ui_glyphs.gd")

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

	# An item that carries its own art (the mythics — see ItemData.appearance)
	# shows that art here while it is equipped. Everything else falls back to
	# the shadowed silhouette of its slot type (the equipped item's own type
	# when filled, e.g. a quiver sitting in a weapon slot shows a quiver
	# shadow). An equipped weapon shows its specific shape — an axe reads as an
	# axe, a dagger as a dagger — instead of the generic any-weapon composite.
	var art: Control = _make_item_art() if item else null
	if art == null:
		var sil = ItemSilhouetteScript.new()
		var sil_subtype: int = -1
		if item and item.item_type == ItemData.ItemType.WEAPON:
			sil_subtype = item.weapon_subtype
		sil.setup(item.item_type if item else item_type, item == null, sil_subtype)
		art = sil
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.offset_top = 4
	art.offset_bottom = -16
	art.offset_left = 6
	art.offset_right = -6
	add_child(art)

	# Bottom label: item title when equipped, slot type name when empty.
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_bottom = -2
	label.offset_top = -16
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inv = _panel.inventory if _panel else null
	if item:
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
		label.text = item.item_name
		# Mark the item held with both hands
		if inv and item_type == ItemData.ItemType.WEAPON and inv.two_handed_slot == slot_index:
			label.text += " (2H)"
			label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
		tooltip_text = _build_item_tooltip()
	else:
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
		if inv and item_type == ItemData.ItemType.WEAPON and inv.is_two_hand_locked_slot(slot_index):
			# This empty hand is committed to two-handing.
			label.text = "Both Hands"
			label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.35))
			tooltip_text = "Occupied — two-handing the other hand's weapon"
		else:
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

	_add_passive_badge()

## The equipped item's own sprite, drawn from its appearance description, blown
## up by whole texels to fill the slot. Null for items without art (everything
## but the mythics today).
func _make_item_art() -> Control:
	var tex: Texture2D = item.get_appearance_texture()
	if tex == null:
		return null
	var box := custom_minimum_size - Vector2(12, 20)  # the offsets applied below
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(make_pixel_art_rect(tex, box))
	return holder

## A nearest-filtered TextureRect scaled by a WHOLE number of texels so it fits
## inside `box` (style guide §1: pixel art is never scaled fractionally).
static func make_pixel_art_rect(tex: Texture2D, box: Vector2) -> TextureRect:
	var src := tex.get_size()
	var steps: float = 1.0
	if src.x > 0 and src.y > 0:
		steps = maxf(1.0, floorf(minf(box.x / src.x, box.y / src.y)))
	var rect := TextureRect.new()
	rect.texture = tex
	rect.custom_minimum_size = src * steps
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

## Top-left corner badge advertising a character passive that affects this
## slot type: Ryan's belt mana discount, Cory's gauntlet mana refund, Jeremy's
## ring double-trigger cycle, Brad's chest weight reduction, and the universal
## off-hand bonus/penalty. Hovering the badge explains the passive.
func _add_passive_badge() -> void:
	var inv = _panel.inventory if _panel else null
	if not inv:
		return
	var icon: Texture2D = null
	var text := ""
	var text_color := Color(0.85, 0.88, 0.95)
	var tip := ""
	match item_type:
		ItemData.ItemType.BELT:
			if inv.belt_card_mana_reduction > 0:
				text = "-%d" % inv.belt_card_mana_reduction
				text_color = Color(0.55, 0.75, 1.0)
				tip = "Cards granted by belt items cost %d less mana." % inv.belt_card_mana_reduction
		ItemData.ItemType.GAUNTLETS:
			if inv.gauntlet_cooldown_mana:
				icon = UIGlyphsScript.get_glyph("mana_plus")
				tip = "Gain 1 mana whenever a gauntlet skill comes off cooldown."
		ItemData.ItemType.RING:
			if inv.ring_double_trigger:
				icon = UIGlyphsScript.get_glyph("recycle")
				tip = "Every %d cycles, the first ring trigger of the cycle triggers twice." % inv.RING_DOUBLE_TRIGGER_CYCLES
		ItemData.ItemType.CHEST:
			if inv.chest_weight_reduction > 0.0:
				var cut := int(round(inv.chest_weight_reduction * 100))
				icon = UIGlyphsScript.get_glyph("feather")
				text = "%d%%" % cut
				text_color = Color(0.8, 0.85, 0.95)
				tip = "Chest items weigh %d%% less." % cut
		ItemData.ItemType.WEAPON:
			# Off-hand slots only (index 0 is the main hand). Two-handing
			# sheds the off-hand modifier, so skip two-handed/locked slots.
			if slot_index > 0 and inv.two_handed_slot != slot_index \
					and not inv.is_two_hand_locked_slot(slot_index):
				var pct := int(round((inv.get_off_hand_modifier() - 1.0) * 100))
				if pct > 0:
					text = "+%d%%" % pct
					text_color = Color(0.5, 0.9, 0.55)
					tip = "Off-hand items get a %d%% bonus." % pct
				elif pct < 0:
					text = "%d%%" % pct
					text_color = Color(0.95, 0.55, 0.5)
					tip = "Off-hand items take a %d%% penalty." % -pct
	if icon == null and text == "":
		return

	var badge := HBoxContainer.new()
	badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	badge.offset_left = 3
	badge.offset_top = 2
	badge.add_theme_constant_override("separation", 1)
	badge.mouse_filter = Control.MOUSE_FILTER_PASS
	badge.tooltip_text = tip
	if icon:
		var rect := TextureRect.new()
		rect.texture = icon
		rect.custom_minimum_size = Vector2(14, 14)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.mouse_filter = Control.MOUSE_FILTER_PASS
		rect.tooltip_text = tip
		badge.add_child(rect)
	if text != "":
		var lbl := Label.new()
		lbl.text = text
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", text_color)
		# Black outline so the badge reads over the silhouette.
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		lbl.tooltip_text = tip
		badge.add_child(lbl)
	add_child(badge)

func _build_item_tooltip() -> String:
	var type_line := item.get_type_name()
	if item.item_type == ItemData.ItemType.WEAPON:
		type_line = ItemData.get_weapon_subtype_name(item.weapon_subtype)
	var lines: Array[String] = [item.item_name, type_line]
	if item.appearance != "":
		lines.append(item.appearance)
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
	# A hand slot consumed by two-handing accepts nothing.
	if item_type == ItemData.ItemType.WEAPON and _panel and _panel.inventory \
			and _panel.inventory.is_two_hand_locked_slot(slot_index):
		return false
	# Bow rule: a bow can't join other hand items (and vice versa) — only a
	# quiver shares the hands with a bow.
	if item_type == ItemData.ItemType.WEAPON and dragged.item_type == ItemData.ItemType.WEAPON \
			and _panel and _panel.inventory \
			and _panel.inventory.hand_conflict_reason(dragged, slot_index) != "":
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
