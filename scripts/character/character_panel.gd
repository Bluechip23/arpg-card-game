class_name CharacterPanel
extends CanvasLayer

## Character stats and equipment panel (toggle with I key)

signal closed
signal card_slotted(card: Card, item: ItemData)
signal card_unslotted(card: Card, item: ItemData)

@onready var panel: PanelContainer = $Panel
@onready var name_label: Label = $Panel/MarginContainer/VBox/NameLabel
@onready var stats_label: Label = $Panel/MarginContainer/VBox/StatsContainer/StatsLabel
@onready var derived_label: Label = $Panel/MarginContainer/VBox/StatsContainer/DerivedLabel
@onready var equipment_container: VBoxContainer = $Panel/MarginContainer/VBox/ScrollContainer/EquipmentContainer
@onready var close_button: Button = $Panel/MarginContainer/VBox/CloseButton

var player_stats: PlayerStats
var inventory: Inventory
var deck_manager = null  # DeckManager - untyped to avoid circular dependency
var item_tooltip: ItemTooltip
var _original_tooltip_parent: Node = null

# Detail side panel state
var _detail_panel: PanelContainer = null
var _detail_item: ItemData = null
var _detail_item_type: ItemData.ItemType = ItemData.ItemType.HELM
var _detail_slot_index: int = -1
var _detail_storage_index: int = -1  # >= 0 means stored item, -1 means equipped

# Card slot management panel state
var _card_slot_panel: PanelContainer = null
var _card_slot_item: ItemData = null

func _ready() -> void:
	layer = 100
	_apply_panel_style()
	_apply_label_styles()
	_apply_button_styles()
	hide_panel()
	close_button.pressed.connect(_on_close_pressed)

func _apply_panel_style() -> void:
	if not panel:
		return
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.13, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.35, 0.35, 0.5)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)

func _apply_label_styles() -> void:
	if name_label:
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var stats_sep = $Panel/MarginContainer/VBox/HSeparator
	if stats_sep:
		stats_sep.add_theme_color_override("color", Color(0.3, 0.3, 0.45))

	if stats_label:
		stats_label.add_theme_font_size_override("font_size", 13)
		stats_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		stats_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	if derived_label:
		derived_label.add_theme_font_size_override("font_size", 13)
		derived_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		derived_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	var eq_label = $Panel/MarginContainer/VBox/EquipmentLabel
	if eq_label:
		eq_label.add_theme_font_size_override("font_size", 10)
		eq_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.7))

func _apply_button_styles() -> void:
	if not close_button:
		return
	close_button.add_theme_font_size_override("font_size", 13)

	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.15, 0.15, 0.2)
	btn_normal.border_width_left = 1
	btn_normal.border_width_right = 1
	btn_normal.border_width_top = 1
	btn_normal.border_width_bottom = 1
	btn_normal.border_color = Color(0.35, 0.35, 0.5)
	btn_normal.corner_radius_top_left = 4
	btn_normal.corner_radius_top_right = 4
	btn_normal.corner_radius_bottom_left = 4
	btn_normal.corner_radius_bottom_right = 4
	close_button.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.25, 0.25, 0.35)
	btn_hover.border_width_left = 1
	btn_hover.border_width_right = 1
	btn_hover.border_width_top = 1
	btn_hover.border_width_bottom = 1
	btn_hover.border_color = Color(0.5, 0.5, 0.7)
	btn_hover.corner_radius_top_left = 4
	btn_hover.corner_radius_top_right = 4
	btn_hover.corner_radius_bottom_left = 4
	btn_hover.corner_radius_bottom_right = 4
	close_button.add_theme_stylebox_override("hover", btn_hover)

func connect_stats(stats: PlayerStats, inv: Inventory, dm = null) -> void:
	player_stats = stats
	inventory = inv
	deck_manager = dm

	if player_stats:
		player_stats.health_changed.connect(_on_stats_changed)
		player_stats.mana_changed.connect(_on_mana_changed)
		player_stats.armor_changed.connect(_on_armor_changed)
		player_stats.stats_updated.connect(_on_stats_changed)

	if inventory:
		inventory.equipment_changed.connect(_on_equipment_changed)
		inventory.storage_changed.connect(_on_storage_changed)
	item_tooltip = get_node_or_null("/root/Main/UI/ItemTooltip")

func show_panel() -> void:
	update_display()
	panel.visible = true

func hide_panel() -> void:
	_close_detail_panel()
	_close_card_slot_panel()
	panel.visible = false

func toggle_panel() -> void:
	if panel.visible:
		hide_panel()
	else:
		show_panel()

func update_display() -> void:
	if not player_stats:
		return

	if name_label and player_stats.character_data:
		name_label.text = player_stats.character_data.character_name

	if stats_label:
		stats_label.text = _build_core_stats_text()

	if derived_label:
		derived_label.text = _build_derived_stats_text()

	_update_equipment_display()

func _build_core_stats_text() -> String:
	return """STR  %d
DEX  %d
INT  %d
WIS  %d
DET  %d
AGI  %d""" % [
		player_stats.strength,
		player_stats.dexterity,
		player_stats.intelligence,
		player_stats.wisdom,
		player_stats.determination,
		player_stats.agility
	]

func _build_derived_stats_text() -> String:
	return """HP   %d/%d
Mana %.0f/%d
Armor  %d
Decay  -%d/t
Carry  %d/%d
Regen  %.1f/t""" % [
		player_stats.current_health,
		player_stats.max_health,
		player_stats.current_mana,
		player_stats.max_mana,
		player_stats.current_armor,
		player_stats.armor_decay_per_cycle,
		player_stats.current_carry_load,
		player_stats.get_carry_capacity(),
		player_stats.get_effective_mana_regen()
	]

func _update_equipment_display() -> void:
	if not equipment_container or not inventory:
		return

	for child in equipment_container.get_children():
		child.queue_free()

	# Passive section
	var passive_text = _get_character_passive()
	if passive_text != "":
		var passive_header = _make_section_header("UNIQUE PASSIVE")
		equipment_container.add_child(passive_header)

		var passive_label = Label.new()
		passive_label.text = passive_text
		passive_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		passive_label.add_theme_font_size_override("font_size", 12)
		passive_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		equipment_container.add_child(passive_label)

		equipment_container.add_child(_make_separator())

	# Equipment section header
	var eq_section = _make_section_header("EQUIPMENT")
	equipment_container.add_child(eq_section)

	var slot_info = inventory.get_slot_info()
	_add_equipment_section("Helm", slot_info["helm"], ItemData.ItemType.HELM)
	_add_equipment_section("Chest", slot_info["chest"], ItemData.ItemType.CHEST)
	_add_equipment_section("Ring", slot_info["ring"], ItemData.ItemType.RING)
	_add_equipment_section("Belt", slot_info["belt"], ItemData.ItemType.BELT)
	_add_equipment_section("Boots", slot_info["boots"], ItemData.ItemType.BOOTS)
	_add_equipment_section("Gauntlets", slot_info["gauntlets"], ItemData.ItemType.GAUNTLETS)
	_add_equipment_section("Weapon", slot_info["weapon"], ItemData.ItemType.WEAPON)

	# Total weight
	equipment_container.add_child(_make_separator())
	var weight_label = Label.new()
	weight_label.text = "Total Weight: %d" % inventory.get_total_weight()
	weight_label.add_theme_font_size_override("font_size", 12)
	weight_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	equipment_container.add_child(weight_label)

	# Inventory storage grid
	_update_storage_grid()

func _get_character_passive() -> String:
	if not inventory:
		return ""
	match inventory.character_name:
		"Ryan":
			return "Belt cards cost 1 less mana"
		"Brad":
			return "Chest items weigh 15% less"
		"Jeremy":
			return "First ring trigger per turn triggers twice"
		"Stephen":
			return "+10% off-hand enchantments (others get -10%)"
		"Cory":
			return "Gain 1 mana when gauntlet skill comes off cooldown"
	return ""

func _add_equipment_section(section_name: String, slot_data: Dictionary, item_type: ItemData.ItemType) -> void:
	var max_slots: int = slot_data["max"]
	var equipped: Array = slot_data["equipped"]

	var section_label := Label.new()
	section_label.text = "%s (%d)" % [section_name, max_slots]
	section_label.add_theme_font_size_override("font_size", 11)
	section_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	equipment_container.add_child(section_label)

	for i in range(max_slots):
		var item = equipped[i] if i < equipped.size() else null

		var item_button := Button.new()
		item_button.flat = true
		item_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item_button.add_theme_font_size_override("font_size", 12)

		if item:
			item_button.text = "  %d: %s" % [i + 1, item.item_name]
			item_button.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
			item_button.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.4))
			item_button.pressed.connect(_on_equipped_item_clicked.bind(item, item_type, i))
		else:
			item_button.text = "  %d: [Empty]" % [i + 1]
			item_button.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))

		equipment_container.add_child(item_button)

		if not item:
			continue

		# Ring trigger info
		if item.ring_trigger != ItemData.RingTrigger.NONE:
			var trigger_label := Label.new()
			trigger_label.text = "    → %s: %s" % [item.get_ring_trigger_name(), item.get_ring_effect_name()]
			trigger_label.add_theme_font_size_override("font_size", 11)
			trigger_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
			trigger_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			equipment_container.add_child(trigger_label)

		# Gauntlet skill info
		if item.gauntlet_skill_type != ItemData.GauntletSkillType.NONE:
			var skill_text := "    → %s: %s" % [item.gauntlet_skill_name, item.gauntlet_skill_description]
			if item.gauntlet_skill_type == ItemData.GauntletSkillType.ACTIVE:
				skill_text += " (CD: %d)" % item.gauntlet_skill_cooldown
				if item.current_cooldown > 0:
					skill_text += " [%dt]" % item.current_cooldown
			else:
				skill_text += " (Passive)"
			var skill_label := Label.new()
			skill_label.text = skill_text
			skill_label.add_theme_font_size_override("font_size", 11)
			skill_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
			skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			equipment_container.add_child(skill_label)

		# Card slot info (clickable to open card slot manager)
		if item.has_card_slots():
			var slot_btn := Button.new()
			slot_btn.text = "    Cards: %d/%d" % [item.slotted_cards.size(), item.card_slots]
			slot_btn.flat = true
			slot_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			slot_btn.add_theme_font_size_override("font_size", 11)
			slot_btn.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
			slot_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.8, 1.0))
			slot_btn.pressed.connect(_open_card_slot_panel.bind(item))
			equipment_container.add_child(slot_btn)

			for card in item.slotted_cards:
				var card_label := Label.new()
				var tag = " [Molded]" if card.is_molded else " [%s]" % card.get_slot_keyword()
				card_label.text = "      > %s%s" % [card.card_name, tag]
				card_label.add_theme_font_size_override("font_size", 10)
				card_label.add_theme_color_override("font_color", Color(0.7, 0.55, 0.9))
				equipment_container.add_child(card_label)

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
				var on_self_label := Label.new()
				on_self_label.text = "    On-Self: %s" % ", ".join(on_self_parts)
				on_self_label.add_theme_font_size_override("font_size", 10)
				on_self_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
				equipment_container.add_child(on_self_label)

func _make_separator() -> HSeparator:
	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color(0.3, 0.3, 0.45))
	return sep

func _make_section_header(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.7))
	return lbl

# ============================================
# ITEM DETAIL SIDE PANEL
# ============================================

func _on_equipped_item_clicked(item: ItemData, item_type: ItemData.ItemType, slot_index: int) -> void:
	_show_detail_panel(item, item_type, slot_index, -1)

func _on_stored_item_clicked(item: ItemData, storage_index: int) -> void:
	_show_detail_panel(item, item.item_type, -1, storage_index)

func _show_detail_panel(item: ItemData, item_type: ItemData.ItemType, slot_index: int, storage_index: int) -> void:
	_close_detail_panel()

	_detail_item = item
	_detail_item_type = item_type
	_detail_slot_index = slot_index
	_detail_storage_index = storage_index

	# Build the detail panel
	_detail_panel = PanelContainer.new()
	_detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Fully opaque style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = _get_item_type_color(item.item_type)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_detail_panel.add_theme_stylebox_override("panel", style)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(240, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Item name (colored by type)
	var item_name_lbl = Label.new()
	item_name_lbl.text = item.item_name
	item_name_lbl.add_theme_font_size_override("font_size", 16)
	item_name_lbl.add_theme_color_override("font_color", _get_item_type_color(item.item_type))
	vbox.add_child(item_name_lbl)

	# Item type
	var type_lbl = Label.new()
	type_lbl.text = item.get_type_name()
	type_lbl.add_theme_font_size_override("font_size", 12)
	type_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(type_lbl)

	vbox.add_child(_make_separator())

	# Stats
	var stats_text = _build_item_stats_text(item)
	if stats_text != "":
		var stats_lbl = Label.new()
		stats_lbl.text = stats_text
		stats_lbl.add_theme_font_size_override("font_size", 13)
		stats_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(stats_lbl)

	# Effects
	var effect_text = _build_item_effect_text(item)
	if effect_text != "":
		var effect_lbl = Label.new()
		effect_lbl.text = effect_text
		effect_lbl.add_theme_font_size_override("font_size", 12)
		effect_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(effect_lbl)

	# Description
	if item.description != "":
		vbox.add_child(_make_separator())
		var desc_lbl = Label.new()
		desc_lbl.text = item.description
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_lbl)

	vbox.add_child(_make_separator())

	# Action buttons
	if storage_index >= 0:
		# Stored item - show Equip button
		var equip_btn = _make_action_button("Equip", Color(0.15, 0.35, 0.2), Color(0.3, 0.7, 0.4))
		equip_btn.pressed.connect(_on_equip_stored_item)
		vbox.add_child(equip_btn)
	else:
		# Equipped item - show Unequip button
		var unequip_btn = _make_action_button("Unequip", Color(0.35, 0.15, 0.15), Color(0.7, 0.35, 0.35))
		unequip_btn.pressed.connect(_on_unequip_item)
		vbox.add_child(unequip_btn)

	# Card slot management button (for equipped items with card slots)
	if item.has_card_slots() and storage_index < 0:
		var card_btn = _make_action_button("Manage Cards (%d/%d)" % [item.slotted_cards.size(), item.card_slots], Color(0.2, 0.15, 0.3), Color(0.6, 0.4, 0.9))
		card_btn.pressed.connect(_open_card_slot_panel.bind(item))
		vbox.add_child(card_btn)

	# Close button
	var close_btn = _make_action_button("Close", Color(0.15, 0.15, 0.2), Color(0.35, 0.35, 0.5))
	close_btn.pressed.connect(_close_detail_panel)
	vbox.add_child(close_btn)

	# Add the panel as a sibling of the inventory panel, positioned to its left
	panel.add_sibling(_detail_panel)

	# Position to the left of the inventory panel
	_detail_panel.anchors_preset = Control.PRESET_TOP_RIGHT
	_detail_panel.anchor_left = 1.0
	_detail_panel.anchor_right = 1.0
	_detail_panel.anchor_top = 0.0
	_detail_panel.anchor_bottom = 1.0
	# Panel is 300px from right edge; place detail panel to its left
	_detail_panel.offset_left = -560.0
	_detail_panel.offset_right = -305.0
	_detail_panel.offset_top = 20.0
	_detail_panel.offset_bottom = -20.0

func _make_action_button(text: String, bg_color: Color, border_color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 13)
	btn.custom_minimum_size = Vector2(200, 32)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = bg_color
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	btn_style.border_color = border_color
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", btn_hover)

	return btn

func _on_unequip_item() -> void:
	if not inventory or not _detail_item:
		return
	if _detail_slot_index < 0:
		return

	if inventory.is_storage_full():
		print("[PANEL] Cannot unequip - inventory storage is full!")
		return

	inventory.unequip_to_storage(_detail_item_type, _detail_slot_index)
	_close_detail_panel()
	update_display()

func _on_equip_stored_item() -> void:
	if not inventory or not _detail_item:
		return
	if _detail_storage_index < 0:
		return

	# Find first empty slot for this item type
	var slot_array = inventory._get_slot_array(_detail_item.item_type)
	var max_slots = inventory._get_max_slots(_detail_item.item_type)
	var target_slot = -1
	for i in range(max_slots):
		if slot_array[i] == null:
			target_slot = i
			break

	if target_slot < 0:
		print("[PANEL] Cannot equip - no empty %s slot!" % _detail_item.get_type_name())
		return

	inventory.equip_from_storage(_detail_storage_index, target_slot)
	_close_detail_panel()
	update_display()

func _close_detail_panel() -> void:
	if _detail_panel and is_instance_valid(_detail_panel):
		_detail_panel.queue_free()
	_detail_panel = null
	_detail_item = null
	_detail_slot_index = -1
	_detail_storage_index = -1

# ============================================
# CARD SLOT MANAGEMENT PANEL
# ============================================

func _open_card_slot_panel(item: ItemData) -> void:
	_close_card_slot_panel()
	_close_detail_panel()
	_card_slot_item = item

	_card_slot_panel = PanelContainer.new()
	_card_slot_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.14, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.6, 0.4, 0.9)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_card_slot_panel.add_theme_stylebox_override("panel", style)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card_slot_panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Header
	var title = Label.new()
	title.text = "%s - Card Slots (%d/%d)" % [item.item_name, item.slotted_cards.size(), item.card_slots]
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
	vbox.add_child(title)

	# Keyword restriction info
	if item.allowed_card_keywords.size() > 0:
		var restrict_label = Label.new()
		var keyword_names: Array[String] = []
		for kw in item.allowed_card_keywords:
			match kw:
				1: keyword_names.append("Arrow")
				2: keyword_names.append("Pocket")
				3: keyword_names.append("Gem")
				4: keyword_names.append("Chisel")
				5: keyword_names.append("Swift")
				6: keyword_names.append("Buckler")
				7: keyword_names.append("Crown")
				8: keyword_names.append("Fist")
		restrict_label.text = "Accepts: %s cards only" % ", ".join(keyword_names)
		restrict_label.add_theme_font_size_override("font_size", 11)
		restrict_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
		vbox.add_child(restrict_label)

	vbox.add_child(_make_separator())

	# === SLOTTED CARDS SECTION ===
	var slotted_header = Label.new()
	slotted_header.text = "SLOTTED CARDS"
	slotted_header.add_theme_font_size_override("font_size", 11)
	slotted_header.add_theme_color_override("font_color", Color(0.55, 0.55, 0.7))
	vbox.add_child(slotted_header)

	if item.slotted_cards.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "  (No cards slotted)"
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		vbox.add_child(empty_label)
	else:
		for i in range(item.slotted_cards.size()):
			var card = item.slotted_cards[i]
			var row_hbox = HBoxContainer.new()
			row_hbox.add_theme_constant_override("separation", 6)

			var card_label = Label.new()
			var tag = " [Molded]" if card.is_molded else " [%s]" % card.get_slot_keyword()
			card_label.text = "%s%s" % [card.card_name, tag]
			card_label.add_theme_font_size_override("font_size", 12)
			card_label.add_theme_color_override("font_color", Color(0.7, 0.55, 0.9))
			card_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row_hbox.add_child(card_label)

			if not card.is_molded:
				var remove_btn = Button.new()
				remove_btn.text = "Remove"
				remove_btn.add_theme_font_size_override("font_size", 11)
				remove_btn.custom_minimum_size = Vector2(70, 24)
				var btn_style = StyleBoxFlat.new()
				btn_style.bg_color = Color(0.35, 0.15, 0.15)
				btn_style.border_color = Color(0.7, 0.35, 0.35)
				btn_style.border_width_left = 1
				btn_style.border_width_right = 1
				btn_style.border_width_top = 1
				btn_style.border_width_bottom = 1
				btn_style.corner_radius_top_left = 3
				btn_style.corner_radius_top_right = 3
				btn_style.corner_radius_bottom_left = 3
				btn_style.corner_radius_bottom_right = 3
				remove_btn.add_theme_stylebox_override("normal", btn_style)
				var btn_hover = btn_style.duplicate()
				btn_hover.bg_color = Color(0.45, 0.2, 0.2)
				remove_btn.add_theme_stylebox_override("hover", btn_hover)
				remove_btn.pressed.connect(_on_unslot_card.bind(item, i))
				row_hbox.add_child(remove_btn)

			vbox.add_child(row_hbox)

	vbox.add_child(_make_separator())

	# === AVAILABLE CARDS SECTION ===
	var avail_header = Label.new()
	avail_header.text = "AVAILABLE CARDS FROM DECK"
	avail_header.add_theme_font_size_override("font_size", 11)
	avail_header.add_theme_color_override("font_color", Color(0.55, 0.55, 0.7))
	vbox.add_child(avail_header)

	var free_slots = item.get_free_card_slots()
	if free_slots <= 0:
		var full_label = Label.new()
		full_label.text = "  (All slots filled)"
		full_label.add_theme_font_size_override("font_size", 12)
		full_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		vbox.add_child(full_label)
	elif deck_manager:
		# Gather all cards from all piles that can be slotted
		var available_cards: Array = []
		for card in deck_manager.draw_pile:
			if item.can_slot_card(card) and not card.is_slotted():
				available_cards.append(card)
		for card in deck_manager.hand:
			if item.can_slot_card(card) and not card.is_slotted():
				available_cards.append(card)
		for card in deck_manager.discard_pile:
			if item.can_slot_card(card) and not card.is_slotted():
				available_cards.append(card)

		if available_cards.size() == 0:
			var none_label = Label.new()
			none_label.text = "  (No compatible cards in deck)"
			none_label.add_theme_font_size_override("font_size", 12)
			none_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
			vbox.add_child(none_label)
		else:
			for card in available_cards:
				var row_hbox = HBoxContainer.new()
				row_hbox.add_theme_constant_override("separation", 6)

				var card_label = Label.new()
				var info = card.card_name
				if card.card_keyword != 0:  # Not NONE
					var kw_name = ""
					match card.card_keyword:
						1: kw_name = "Arrow"
						2: kw_name = "Pocket"
						3: kw_name = "Gem"
						4: kw_name = "Chisel"
						5: kw_name = "Swift"
						6: kw_name = "Buckler"
						7: kw_name = "Crown"
						8: kw_name = "Fist"
					info += " [%s]" % kw_name
				card_label.text = info
				card_label.add_theme_font_size_override("font_size", 12)
				card_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
				card_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row_hbox.add_child(card_label)

				var slot_btn = Button.new()
				slot_btn.text = "Slot"
				slot_btn.add_theme_font_size_override("font_size", 11)
				slot_btn.custom_minimum_size = Vector2(60, 24)
				var btn_style2 = StyleBoxFlat.new()
				btn_style2.bg_color = Color(0.15, 0.2, 0.35)
				btn_style2.border_color = Color(0.4, 0.5, 0.9)
				btn_style2.border_width_left = 1
				btn_style2.border_width_right = 1
				btn_style2.border_width_top = 1
				btn_style2.border_width_bottom = 1
				btn_style2.corner_radius_top_left = 3
				btn_style2.corner_radius_top_right = 3
				btn_style2.corner_radius_bottom_left = 3
				btn_style2.corner_radius_bottom_right = 3
				slot_btn.add_theme_stylebox_override("normal", btn_style2)
				var btn_hover2 = btn_style2.duplicate()
				btn_hover2.bg_color = Color(0.2, 0.25, 0.45)
				slot_btn.add_theme_stylebox_override("hover", btn_hover2)
				slot_btn.pressed.connect(_on_slot_card.bind(card, item))
				row_hbox.add_child(slot_btn)

				vbox.add_child(row_hbox)

	vbox.add_child(_make_separator())

	# Close button
	var close_btn = _make_action_button("Close", Color(0.15, 0.15, 0.2), Color(0.35, 0.35, 0.5))
	close_btn.pressed.connect(_close_card_slot_panel)
	vbox.add_child(close_btn)

	# Position to left of character panel
	panel.add_sibling(_card_slot_panel)
	_card_slot_panel.anchors_preset = Control.PRESET_TOP_RIGHT
	_card_slot_panel.anchor_left = 1.0
	_card_slot_panel.anchor_right = 1.0
	_card_slot_panel.anchor_top = 0.0
	_card_slot_panel.anchor_bottom = 1.0
	_card_slot_panel.offset_left = -620.0
	_card_slot_panel.offset_right = -305.0
	_card_slot_panel.offset_top = 20.0
	_card_slot_panel.offset_bottom = -20.0

func _on_slot_card(card: Card, item: ItemData) -> void:
	if not inventory:
		return
	if inventory.enchant_card(card, item):
		card_slotted.emit(card, item)
		_open_card_slot_panel(item)  # Refresh the panel
		update_display()

func _on_unslot_card(item: ItemData, card_index: int) -> void:
	if not inventory:
		return
	var card = inventory.extract_card(item, card_index)
	if card:
		card_unslotted.emit(card, item)
		_open_card_slot_panel(item)  # Refresh the panel
		update_display()

func _close_card_slot_panel() -> void:
	if _card_slot_panel and is_instance_valid(_card_slot_panel):
		_card_slot_panel.queue_free()
	_card_slot_panel = null
	_card_slot_item = null

func _build_item_stats_text(item: ItemData) -> String:
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

func _build_item_effect_text(item: ItemData) -> String:
	var lines: Array[String] = []
	if item.ring_trigger != ItemData.RingTrigger.NONE:
		lines.append("[Ring] %s → %s" % [item.get_ring_trigger_name(), item.get_ring_effect_name()])
	if item.gauntlet_skill_type == ItemData.GauntletSkillType.ACTIVE:
		lines.append("[Active] %s: %s" % [item.gauntlet_skill_name, item.gauntlet_skill_description])
		lines.append("  Cost: %d Mana | CD: %d turns" % [item.gauntlet_skill_mana_cost, item.gauntlet_skill_cooldown])
	elif item.gauntlet_skill_type == ItemData.GauntletSkillType.PASSIVE:
		lines.append("[Passive] %s: %s" % [item.gauntlet_skill_name, item.gauntlet_skill_description])
	match item.special_effect:
		ItemData.SpecialEffect.OVERFLOW_HEAL_ARMOR:
			lines.append("[Overflow] Heal %d, +%d Armor" % [item.special_effect_value, item.special_effect_value_2])
		ItemData.SpecialEffect.GRANT_BLINK_CARD:
			lines.append("[Equip] Grants %d Blink card(s)" % item.special_effect_value)
		ItemData.SpecialEffect.CHANCE_BOOST:
			lines.append("[Passive] +%d%% chance effects" % item.special_effect_value)
		ItemData.SpecialEffect.GRANT_CARDS:
			lines.append("[Equip] Grants cards: %s" % ", ".join(item.granted_card_ids))
	if item.has_card_slots():
		lines.append("[Card Slots] %d/%d" % [item.slotted_cards.size(), item.card_slots])
		for card in item.slotted_cards:
			var tags = ""
			if card.is_molded:
				tags = " (Molded)"
			else:
				tags = " (%s)" % card.get_slot_keyword()
			lines.append("  > %s%s" % [card.card_name, tags])
	return "\n".join(lines)

# ============================================
# OLD TOOLTIP COMPAT (no longer follows mouse)
# ============================================

func _on_item_hover(_item: ItemData) -> void:
	pass

func _on_item_hover_end() -> void:
	pass

func _on_close_pressed() -> void:
	hide_panel()
	closed.emit()

func _on_stats_changed(_a = null, _b = null) -> void:
	if panel.visible:
		update_display()

func _on_mana_changed(_a = null, _b = null) -> void:
	if panel.visible:
		update_display()

func _on_armor_changed(_a = null) -> void:
	if panel.visible:
		update_display()

func _on_equipment_changed() -> void:
	if panel.visible:
		_close_detail_panel()
		update_display()

func _on_storage_changed() -> void:
	if panel.visible:
		update_display()

func _update_storage_grid() -> void:
	if not equipment_container or not inventory:
		return

	equipment_container.add_child(_make_separator())

	# Inventory header row: "INVENTORY (X/20)" on left, "Gold: X" and "Culling Stones: X" on right
	var inv_header_hbox = HBoxContainer.new()

	var storage_header = _make_section_header("INVENTORY (%d/%d)" % [inventory.get_stored_item_count(), inventory.max_storage_slots])
	inv_header_hbox.add_child(storage_header)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_header_hbox.add_child(spacer)

	var gold_label = Label.new()
	gold_label.text = "Gold: %d" % player_stats.gold
	gold_label.add_theme_font_size_override("font_size", 10)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	inv_header_hbox.add_child(gold_label)

	equipment_container.add_child(inv_header_hbox)

	# Culling stones row
	var stones_hbox = HBoxContainer.new()
	var stones_spacer = Control.new()
	stones_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stones_hbox.add_child(stones_spacer)

	var stones_label = Label.new()
	stones_label.text = "Culling Stones: %d" % inventory.get_culling_stone_count()
	stones_label.add_theme_font_size_override("font_size", 10)
	stones_label.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
	stones_hbox.add_child(stones_label)

	equipment_container.add_child(stones_hbox)

	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	equipment_container.add_child(grid)

	for i in range(inventory.max_storage_slots):
		var cell = _create_storage_cell(i)
		grid.add_child(cell)

func _create_storage_cell(index: int) -> PanelContainer:
	var cell = PanelContainer.new()
	cell.custom_minimum_size = Vector2(62, 48)

	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3

	var item: ItemData = null
	if index < inventory.stored_items.size():
		item = inventory.stored_items[index]

	if item:
		style.bg_color = Color(0.18, 0.18, 0.25, 1.0)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.border_color = _get_item_type_color(item.item_type)
	else:
		style.bg_color = Color(0.1, 0.1, 0.12, 1.0)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.2, 0.2, 0.25)

	cell.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	cell.add_child(vbox)

	var type_label = Label.new()
	type_label.add_theme_font_size_override("font_size", 9)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var cell_name_label = Label.new()
	cell_name_label.add_theme_font_size_override("font_size", 10)
	cell_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	if item:
		type_label.text = item.get_type_name()
		type_label.add_theme_color_override("font_color", _get_item_type_color(item.item_type))
		cell_name_label.text = item.item_name
		cell_name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

		cell.gui_input.connect(_on_storage_cell_input.bind(item, index))
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		type_label.text = ""
		cell_name_label.text = ""

	vbox.add_child(type_label)
	vbox.add_child(cell_name_label)

	return cell

func _on_storage_cell_input(event: InputEvent, item: ItemData, storage_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_stored_item_clicked(item, storage_index)

func _get_item_type_color(item_type: ItemData.ItemType) -> Color:
	match item_type:
		ItemData.ItemType.WEAPON:
			return Color(1.0, 0.4, 0.4)
		ItemData.ItemType.HELM, ItemData.ItemType.CHEST, ItemData.ItemType.BOOTS:
			return Color(0.4, 0.6, 1.0)
		ItemData.ItemType.RING:
			return Color(1.0, 0.85, 0.3)
		ItemData.ItemType.BELT:
			return Color(0.6, 0.45, 0.3)
		ItemData.ItemType.GAUNTLETS:
			return Color(0.9, 0.6, 0.2)
	return Color(0.5, 0.5, 0.5)
