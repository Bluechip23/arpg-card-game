class_name ItemTooltip
extends PanelContainer

## Popup tooltip for item details

@onready var name_label: Label = $MarginContainer/VBox/NameLabel
@onready var type_label: Label = $MarginContainer/VBox/TypeLabel
@onready var stats_label: Label = $MarginContainer/VBox/StatsLabel
@onready var effect_label: Label = $MarginContainer/VBox/EffectLabel
@onready var description_label: Label = $MarginContainer/VBox/DescriptionLabel

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_item(item: ItemData, pos: Vector2) -> void:
	if not item:
		hide()
		return
	
	# Name
	if name_label:
		name_label.text = item.item_name
		match item.item_type:
			ItemData.ItemType.WEAPON:
				name_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
			ItemData.ItemType.RING:
				name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 1))
			_:
				name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	
	# Type
	if type_label:
		type_label.text = item.get_type_name()
	
	# Stats
	if stats_label:
		var stats_text = _build_stats_text(item)
		stats_label.text = stats_text
		stats_label.visible = stats_text != ""
	
	# Special effects
	if effect_label:
		var effect_text = _build_effect_text(item)
		effect_label.text = effect_text
		effect_label.visible = effect_text != ""
	
	# Description
	if description_label:
		description_label.text = item.description
	
	# Position tooltip near mouse but keep on screen
	position = pos + Vector2(15, 15)
	var screen_size = get_viewport_rect().size
	if position.x + size.x > screen_size.x:
		position.x = pos.x - size.x - 15
	if position.y + size.y > screen_size.y:
		position.y = pos.y - size.y - 15
	
	visible = true

func _build_stats_text(item: ItemData) -> String:
	var lines: Array[String] = []
	
	if item.strength_bonus != 0:
		lines.append("+%d Strength" % item.strength_bonus if item.strength_bonus > 0 else "%d Strength" % item.strength_bonus)
	if item.dexterity_bonus != 0:
		lines.append("+%d Dexterity" % item.dexterity_bonus if item.dexterity_bonus > 0 else "%d Dexterity" % item.dexterity_bonus)
	if item.intelligence_bonus != 0:
		lines.append("+%d Intelligence" % item.intelligence_bonus if item.intelligence_bonus > 0 else "%d Intelligence" % item.intelligence_bonus)
	if item.wisdom_bonus != 0:
		lines.append("+%d Wisdom" % item.wisdom_bonus if item.wisdom_bonus > 0 else "%d Wisdom" % item.wisdom_bonus)
	if item.determination_bonus != 0:
		lines.append("+%d Determination" % item.determination_bonus if item.determination_bonus > 0 else "%d Determination" % item.determination_bonus)
	if item.agility_bonus != 0:
		lines.append("+%d Agility" % item.agility_bonus if item.agility_bonus > 0 else "%d Agility" % item.agility_bonus)
	if item.health_bonus != 0:
		lines.append("+%d Health" % item.health_bonus if item.health_bonus > 0 else "%d Health" % item.health_bonus)
	if item.mana_bonus != 0:
		lines.append("+%d Mana" % item.mana_bonus if item.mana_bonus > 0 else "%d Mana" % item.mana_bonus)
	if item.armor_bonus != 0:
		lines.append("+%d Armor" % item.armor_bonus if item.armor_bonus > 0 else "%d Armor" % item.armor_bonus)
	if item.hand_size_bonus != 0:
		lines.append("+%d Hand Size" % item.hand_size_bonus)
	if item.weapon_damage > 0:
		lines.append("%d Weapon Damage" % item.weapon_damage)
	if item.weight > 0:
		lines.append("Weight: %d" % item.weight)
	
	return "\n".join(lines)

func _build_effect_text(item: ItemData) -> String:
	var lines: Array[String] = []
	
	# Ring triggers
	if item.ring_trigger != ItemData.RingTrigger.NONE:
		lines.append("[Ring] %s → %s" % [item.get_ring_trigger_name(), item.get_ring_effect_name()])
	
	# Gauntlet skills
	if item.gauntlet_skill_type == ItemData.GauntletSkillType.ACTIVE:
		lines.append("[Active] %s: %s" % [item.gauntlet_skill_name, item.gauntlet_skill_description])
		lines.append("  Cost: %d Mana | CD: %d turns" % [item.gauntlet_skill_mana_cost, item.gauntlet_skill_cooldown])
	elif item.gauntlet_skill_type == ItemData.GauntletSkillType.PASSIVE:
		lines.append("[Passive] %s: %s" % [item.gauntlet_skill_name, item.gauntlet_skill_description])
	
	# Special effects
	match item.special_effect:
		ItemData.SpecialEffect.OVERFLOW_HEAL_ARMOR:
			lines.append("[Overflow] Heal %d, +%d Armor" % [item.special_effect_value, item.special_effect_value_2])
		ItemData.SpecialEffect.GRANT_BLINK_CARD:
			lines.append("[Equip] Grants %d Blink card(s)" % item.special_effect_value)
		ItemData.SpecialEffect.CHANCE_BOOST:
			lines.append("[Passive] +%d%% chance effects" % item.special_effect_value)
		ItemData.SpecialEffect.GRANT_CARDS:
			lines.append("[Equip] Grants cards: %s" % ", ".join(item.granted_card_ids))

	# Card slot info
	if item.has_card_slots():
		lines.append("[Card Slots] %d/%d" % [item.slotted_cards.size(), item.card_slots])
		for card in item.slotted_cards:
			var tags = ""
			if card.is_molded:
				tags = " (Molded)"
			else:
				tags = " (%s)" % card.get_slot_keyword()
			lines.append("  > %s%s" % [card.card_name, tags])
		# On-self bonuses
		var on_self_parts: Array[String] = []
		if item.on_self_damage > 0:
			on_self_parts.append("+%d dmg" % item.on_self_damage)
		if item.on_self_block > 0:
			on_self_parts.append("+%d block" % item.on_self_block)
		if item.on_self_heal > 0:
			on_self_parts.append("+%d heal" % item.on_self_heal)
		if item.on_self_mana_reduction > 0:
			on_self_parts.append("-%d mana" % item.on_self_mana_reduction)
		if on_self_parts.size() > 0:
			lines.append("[On-Self] %s" % ", ".join(on_self_parts))

	return "\n".join(lines)

func hide_tooltip() -> void:
	visible = false
