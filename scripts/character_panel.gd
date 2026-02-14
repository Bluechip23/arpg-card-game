class_name CharacterPanel
extends CanvasLayer

## Character stats and equipment panel (toggle with C key)

signal closed

@onready var panel: PanelContainer = $Panel
@onready var name_label: Label = $Panel/MarginContainer/VBox/NameLabel
@onready var stats_label: Label = $Panel/MarginContainer/VBox/StatsContainer/StatsLabel
@onready var derived_label: Label = $Panel/MarginContainer/VBox/StatsContainer/DerivedLabel
@onready var equipment_container: VBoxContainer = $Panel/MarginContainer/VBox/EquipmentContainer
@onready var close_button: Button = $Panel/MarginContainer/VBox/CloseButton

var player_stats: PlayerStats
var inventory: Inventory
var item_tooltip: ItemTooltip

func _ready() -> void:
	hide_panel()
	close_button.pressed.connect(_on_close_pressed)

func connect_stats(stats: PlayerStats, inv: Inventory) -> void:
	player_stats = stats
	inventory = inv
	
	if inventory:
		inventory.equipment_changed.connect(_on_equipment_changed)
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
		stats_label.text = player_stats.get_stats_summary()
	
	if derived_label:
		derived_label.text = """HP: %d / %d
Mana: %.0f / %d
Armor: %d (-%d/turn)
Carry: %d / %d
Mana Regen: %.2f/turn""" % [
			player_stats.current_health,
			player_stats.max_health,
			player_stats.current_mana,
			player_stats.max_mana,
			player_stats.current_armor,
			player_stats.armor_decay_per_turn,
			player_stats.current_carry_load,
			player_stats.get_carry_capacity(),
			player_stats.get_effective_mana_regen()
		]
	
	_update_equipment_display()

func _update_equipment_display() -> void:
	if not equipment_container or not inventory:
		return
	
	# Clear existing equipment labels
	for child in equipment_container.get_children():
		child.queue_free()
		
	var passive_text = _get_character_passive()
	if passive_text != "":
		var passive_header = Label.new()
		passive_header.text = "Passive:"
		passive_header.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
		equipment_container.add_child(passive_header)
		
		var passive_label = Label.new()
		passive_label.text = "  " + passive_text
		passive_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		equipment_container.add_child(passive_label)
		
		var spacer = HSeparator.new()
		equipment_container.add_child(spacer)
	var slot_info = inventory.get_slot_info()
	
	# Add section for each equipment type
	_add_equipment_section("Helm", slot_info["helm"])
	_add_equipment_section("Chest", slot_info["chest"])
	_add_equipment_section("Ring", slot_info["ring"])
	_add_equipment_section("Belt", slot_info["belt"])
	_add_equipment_section("Boots", slot_info["boots"])
	_add_equipment_section("Gauntlets", slot_info["gauntlets"])
	_add_equipment_section("Weapon", slot_info["weapon"])
	
	# Total weight
	var weight_label = Label.new()
	weight_label.text = "\nTotal Weight: %d" % inventory.get_total_weight()
	equipment_container.add_child(weight_label)
	
func _get_character_passive() -> String:
	if not inventory:
		return ""
	var passives: Array[String] = []
	match inventory.character_name:
		"Ryan":
			passives.append("Belt cards cost 1 less mana")
		"Brad":
			passives.append("Chest items weigh 15% less")
		"Jeremy":
			passives.append("First ring trigger per turn triggers twice")
		"Stephen":
			passives.append("+10% off-hand enchantments (others get -10%)")
		"Cory":
			passives.append("Gain 1 mana when gauntlet skill comes off cooldown")
	
	return "\n".join(passives)
	
func _add_equipment_section(section_name: String, slot_data: Dictionary) -> void:
	var max_slots: int = slot_data["max"]
	var equipped: Array = slot_data["equipped"]
	
	# Section header
	var section_label := Label.new()
	section_label.text = "%s (%d slots):" % [section_name, max_slots]
	section_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
	equipment_container.add_child(section_label)
	
	for i in range(max_slots):
		var item = equipped[i] if i < equipped.size() else null
		
		var item_button := Button.new()
		item_button.flat = true
		item_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		if item:
			item_button.text = "  %d: %s" % [i + 1, item.item_name]
			item_button.mouse_entered.connect(_on_item_hover.bind(item))
			item_button.mouse_exited.connect(_on_item_hover_end)
		else:
			item_button.text = "  %d: [Empty]" % [i + 1]
			item_button.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		
		equipment_container.add_child(item_button)
		
		if not item:
			continue
		
		# Ring trigger info
		if item.ring_trigger != ItemData.RingTrigger.NONE:
			var trigger_label := Label.new()
			trigger_label.text = "      → %s: %s" % [item.get_ring_trigger_name(), item.get_ring_effect_name()]
			trigger_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
			equipment_container.add_child(trigger_label)
		
		# Gauntlet skill info
		if item.gauntlet_skill_type != ItemData.GauntletSkillType.NONE:
			var skill_text := "      → %s: %s" % [item.gauntlet_skill_name, item.gauntlet_skill_description]
			if item.gauntlet_skill_type == ItemData.GauntletSkillType.ACTIVE:
				skill_text += " (CD: %d, Cost: %d)" % [item.gauntlet_skill_cooldown, item.gauntlet_skill_mana_cost]
				if item.current_cooldown > 0:
					skill_text += " [%d turns]" % item.current_cooldown
			else:
				skill_text += " (Passive)"
			var skill_label := Label.new()
			skill_label.text = skill_text
			skill_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.6))
			equipment_container.add_child(skill_label)
			
func _on_item_hover(item: ItemData) -> void:
	if item_tooltip:
		var mouse_pos = get_viewport().get_mouse_position()
		item_tooltip.show_item(item, mouse_pos)
		
func _on_item_hover_end() -> void:
	if item_tooltip:
		item_tooltip.hide_tooltip()
		
func _on_close_pressed() -> void:
	hide_panel()
	closed.emit()

func _on_equipment_changed() -> void:
	if panel.visible:
		update_display()
