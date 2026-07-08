class_name InventoryCardSlot
extends Panel

## The small square in the bottom-right corner of an equipment slot square.
## Appears only when the equipped item has one or more card slots.
##  - Draws a red "+" when the item carries an on-self effect.
##  - Shows a small badge with the number of slotted cards.
##  - Hovering shows a popup: the slotted card's info (above) then the
##    item's on-self effect (below).
##  - Clicking opens the full card-slot management panel.

var _panel: CharacterPanel = null
var item: ItemData = null

func setup(char_panel: CharacterPanel, itm: ItemData) -> void:
	_panel = char_panel
	item = itm
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(24, 24)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.1, 0.95)
	style.set_border_width_all(1)
	style.border_color = Color(0.55, 0.4, 0.85) if item.slotted_cards.size() > 0 else Color(0.4, 0.35, 0.5)
	style.set_corner_radius_all(3)
	add_theme_stylebox_override("panel", style)

	tooltip_text = _build_tooltip()
	queue_redraw()

func _build_tooltip() -> String:
	var sections: Array[String] = []

	# Card info first (appears ABOVE the on-self effect).
	if item.slotted_cards.size() > 0:
		for card in item.slotted_cards:
			var lines: Array[String] = []
			var tag := " (Molded)" if card.is_molded else " (%s)" % card.get_slot_keyword()
			lines.append("%s%s" % [card.card_name, tag])
			lines.append("%s  •  %d Mana / %d Tempo" % [card.card_type_name, card.mana_cost, card.tempo_cost])
			if card.description != "":
				lines.append(card.description)
			sections.append("\n".join(lines))
	else:
		sections.append("Card slots: %d/%d (empty)" % [item.slotted_cards.size(), item.card_slots])

	# On-self effect below the card info.
	var on_self := _on_self_description()
	if on_self != "":
		sections.append("On-Self effect:\n%s" % on_self)

	sections.append("Click to manage cards")
	return "\n\n".join(sections)

func has_on_self() -> bool:
	return (item.on_self_damage > 0 or item.on_self_block > 0 or item.on_self_heal > 0
		or item.on_self_mana_reduction > 0 or item.on_self_apply_burn > 0
		or item.on_self_apply_cold > 0 or item.on_self_thorns > 0 or item.on_self_upgrade)

func _on_self_description() -> String:
	var parts: Array[String] = []
	if item.on_self_damage > 0:
		parts.append("+%d damage to slotted card" % item.on_self_damage)
	if item.on_self_block > 0:
		parts.append("+%d block to slotted card" % item.on_self_block)
	if item.on_self_heal > 0:
		parts.append("+%d heal to slotted card" % item.on_self_heal)
	if item.on_self_mana_reduction > 0:
		parts.append("-%d mana cost to slotted card" % item.on_self_mana_reduction)
	if item.on_self_apply_burn > 0:
		parts.append("Applies %d Burn on hit" % item.on_self_apply_burn)
	if item.on_self_apply_cold > 0:
		parts.append("Applies %d Cold on hit" % item.on_self_apply_cold)
	if item.on_self_thorns > 0:
		parts.append("Grants %d Thorns on play" % item.on_self_thorns)
	if item.on_self_upgrade:
		parts.append("Upgrades the slotted card on play")
	return "\n".join(parts)

func _draw() -> void:
	var c: Vector2 = size * 0.5
	if has_on_self():
		# Red plus in the centre of the slot.
		var arm: float = size.x * 0.3
		var th: float = maxf(2.0, size.x * 0.12)
		var red := Color(0.95, 0.25, 0.25)
		draw_line(c - Vector2(arm, 0), c + Vector2(arm, 0), red, th)
		draw_line(c - Vector2(0, arm), c + Vector2(0, arm), red, th)

	# Slotted-card badge (top-left corner dot with count).
	var n: int = item.slotted_cards.size()
	if n > 0:
		draw_circle(Vector2(size.x * 0.28, size.y * 0.28), size.x * 0.2, Color(0.75, 0.55, 1.0))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _panel and item:
			accept_event()
			_panel._open_card_slot_panel(item)
