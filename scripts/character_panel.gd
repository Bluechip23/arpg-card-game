class_name CharacterPanel
extends CanvasLayer

## Character stats and equipment panel (toggle with I key)

signal closed

@onready var panel: PanelContainer = $Panel
@onready var name_label: Label = $Panel/MarginContainer/VBox/NameLabel
@onready var stats_label: Label = $Panel/MarginContainer/VBox/StatsContainer/StatsLabel
@onready var derived_label: Label = $Panel/MarginContainer/VBox/StatsContainer/DerivedLabel
@onready var equipment_container: VBoxContainer = $Panel/MarginContainer/VBox/ScrollContainer/EquipmentContainer
@onready var close_button: Button = $Panel/MarginContainer/VBox/CloseButton

var player_stats: PlayerStats
var inventory: Inventory
var item_tooltip: ItemTooltip
var _original_tooltip_parent: Node = null

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

func connect_stats(stats: PlayerStats, inv: Inventory) -> void:
	player_stats = stats
	inventory = inv

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
	_add_equipment_section("Helm", slot_info["helm"])
	_add_equipment_section("Chest", slot_info["chest"])
	_add_equipment_section("Ring", slot_info["ring"])
	_add_equipment_section("Belt", slot_info["belt"])
	_add_equipment_section("Boots", slot_info["boots"])
	_add_equipment_section("Gauntlets", slot_info["gauntlets"])
	_add_equipment_section("Weapon", slot_info["weapon"])

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

func _add_equipment_section(section_name: String, slot_data: Dictionary) -> void:
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
			item_button.mouse_entered.connect(_on_item_hover.bind(item))
			item_button.mouse_exited.connect(_on_item_hover_end)
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

func _on_item_hover(item: ItemData) -> void:
	if item_tooltip:
		var mouse_pos = get_viewport().get_mouse_position()
		if item_tooltip.get_parent() != panel:
			_original_tooltip_parent = item_tooltip.get_parent()
			item_tooltip.reparent(panel)
		item_tooltip.show_item(item, mouse_pos)

func _on_item_hover_end() -> void:
	if item_tooltip:
		item_tooltip.hide_tooltip()
		if _original_tooltip_parent and item_tooltip.get_parent() != _original_tooltip_parent:
			item_tooltip.reparent(_original_tooltip_parent)

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
		update_display()

func _on_storage_changed() -> void:
	if panel.visible:
		update_display()

func _update_storage_grid() -> void:
	if not equipment_container or not inventory:
		return

	equipment_container.add_child(_make_separator())

	var storage_header = _make_section_header("INVENTORY (%d/%d)" % [inventory.get_stored_item_count(), inventory.max_storage_slots])
	equipment_container.add_child(storage_header)

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

	var name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	if item:
		type_label.text = item.get_type_name()
		type_label.add_theme_color_override("font_color", _get_item_type_color(item.item_type))
		name_label.text = item.item_name
		name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

		cell.mouse_entered.connect(_on_item_hover.bind(item))
		cell.mouse_exited.connect(_on_item_hover_end)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		type_label.text = ""
		name_label.text = ""

	vbox.add_child(type_label)
	vbox.add_child(name_label)

	return cell

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
