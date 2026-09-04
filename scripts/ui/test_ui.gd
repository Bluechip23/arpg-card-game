class_name TestUI
extends CanvasLayer

## Test UI for spawning waves and testing features

signal spawn_wave_requested
signal spawn_elite_requested
signal spawn_fire_goblins_requested
signal give_item_requested(item_name: String)
signal give_card_requested(card_name: String)
signal apply_buff_requested(buff_name: String)
signal apply_overflow_requested(overflow_name: String)

@onready var panel: PanelContainer = $Panel
@onready var enemy_count_label: Label = $Panel/VBox/EnemyCountLabel
@onready var wave_button: Button = $Panel/VBox/WaveButton
@onready var elite_button: Button = $Panel/VBox/EliteButton
@onready var item_dropdown: OptionButton = $Panel/VBox/ItemDropdown
@onready var give_item_button: Button = $Panel/VBox/GiveItemButton
@onready var card_dropdown: OptionButton = $Panel/VBox/CardDropdown
@onready var give_card_button: Button = $Panel/VBox/GiveCardButton
@onready var toggle_button: Button = $ToggleButton

var is_visible: bool = false

func _ready() -> void:
	_setup_buttons()
	_setup_dropdowns()
	# Start collapsed
	panel.visible = false
	if toggle_button:
		toggle_button.text = ">>"

func _setup_buttons() -> void:
	if wave_button:
		wave_button.pressed.connect(_on_wave_pressed)
	if elite_button:
		elite_button.pressed.connect(_on_elite_pressed)
	if give_item_button:
		give_item_button.pressed.connect(_on_give_item_pressed)
	if give_card_button:
		give_card_button.pressed.connect(_on_give_card_pressed)
	if toggle_button:
		toggle_button.pressed.connect(_on_toggle_pressed)
	if has_node("Panel/VBox/ApplyOverflowButton"):
		$Panel/VBox/ApplyOverflowButton.pressed.connect(_on_apply_overflow_pressed)
	if has_node("Panel/VBox/ApplyBuffButton"):
		$Panel/VBox/ApplyBuffButton.pressed.connect(_on_apply_buff_pressed)
	# Dynamically add a button to spawn the new fire-goblin warband + hydra.
	if has_node("Panel/VBox") and elite_button:
		var fg_btn := Button.new()
		fg_btn.text = "Spawn Fire Goblins"
		fg_btn.pressed.connect(_on_fire_goblins_pressed)
		$Panel/VBox.add_child(fg_btn)
		$Panel/VBox.move_child(fg_btn, elite_button.get_index() + 1)

func _on_fire_goblins_pressed() -> void:
	spawn_fire_goblins_requested.emit()

func _setup_dropdowns() -> void:
	if item_dropdown:
		item_dropdown.clear()
		item_dropdown.add_item("Wooden Sword")
		item_dropdown.add_item("Bladed Doughnut")
	if has_node("Panel/VBox/OverflowDropdown"):
		var overflow_dropdown = $Panel/VBox/OverflowDropdown as OptionButton
		overflow_dropdown.clear()
		overflow_dropdown.add_item("Jailed (3)")
		overflow_dropdown.add_item("Manifest: Skeleton (3)")
		overflow_dropdown.add_item("Manifest: Mushroom (∞)")
		overflow_dropdown.add_item("Manifest: Spirit (3)")
		overflow_dropdown.add_item("Enhance +3 (3)")
		overflow_dropdown.add_item("Skip (3)")
		overflow_dropdown.add_item("Peak (∞)")
		overflow_dropdown.add_item("Overcharge: +2 Health (∞)")
		overflow_dropdown.add_item("Overcharge: +2 Mana (∞)")
		overflow_dropdown.add_item("Overcharge: +2 Armor (3)")
		overflow_dropdown.add_item("Overcharge: 3 Dmg All (3)")
	if card_dropdown:
		card_dropdown.clear()
		card_dropdown.add_item("Slash")
		card_dropdown.add_item("Block")
		card_dropdown.add_item("Blink")
		card_dropdown.add_item("Heal")
		card_dropdown.add_item("Draw")
		card_dropdown.add_item("Discard")
		card_dropdown.add_item("Empower")
		card_dropdown.add_item("Healing Potion")
		card_dropdown.add_item("Dagger Throw")
		card_dropdown.add_item("Gain Mana")
		card_dropdown.add_item("Halo")
		card_dropdown.add_item("Armored Discipline")
	if has_node("Panel/VBox/BuffDropdown"):
		var buff_dropdown = $Panel/VBox/BuffDropdown as OptionButton
		buff_dropdown.clear()
		buff_dropdown.add_item("Thorns (3 dmg)")
		buff_dropdown.add_item("Focused")
		buff_dropdown.add_item("Regen (2)")
		buff_dropdown.add_item("Blessed (1)")
		buff_dropdown.add_item("Fortify")
		buff_dropdown.add_item("Enlightened (25%, 3)")
		buff_dropdown.add_item("Strengthen (+3, 3)")
		buff_dropdown.add_item("Bolster (+2, 3)")
		buff_dropdown.add_item("Haste (+1)")
		buff_dropdown.add_item("Cleanse (1)")
		buff_dropdown.add_item("Smith (2)")
		buff_dropdown.add_item("Steady")
	

func update_enemy_count(count: int) -> void:
	if enemy_count_label:
		enemy_count_label.text = "Enemies: %d" % count

func _on_wave_pressed() -> void:
	spawn_wave_requested.emit()

func _on_elite_pressed() -> void:
	spawn_elite_requested.emit()

func _on_give_item_pressed() -> void:
	if item_dropdown:
		var item_name = item_dropdown.get_item_text(item_dropdown.selected)
		give_item_requested.emit(item_name)

func _on_give_card_pressed() -> void:
	if card_dropdown:
		var card_name = card_dropdown.get_item_text(card_dropdown.selected)
		give_card_requested.emit(card_name)

func _on_toggle_pressed() -> void:
	is_visible = not is_visible
	panel.visible = is_visible
	toggle_button.text = "<<" if is_visible else ">>"
	
func _on_apply_overflow_pressed() -> void:
	if has_node("Panel/VBox/OverflowDropdown"):
		var dropdown = $Panel/VBox/OverflowDropdown as OptionButton
		var name = dropdown.get_item_text(dropdown.selected)
		apply_overflow_requested.emit(name)
func _on_apply_buff_pressed() -> void:
	if has_node("Panel/VBox/BuffDropdown"):
		var dropdown = $Panel/VBox/BuffDropdown as OptionButton
		var name = dropdown.get_item_text(dropdown.selected)
		apply_buff_requested.emit(name)
