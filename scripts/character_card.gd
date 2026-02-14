class_name CharacterCard
extends PanelContainer

## Displays a single character's info for selection

signal selected(character: CharacterData)

@onready var name_label: Label = $VBox/NameLabel
@onready var stats_label: Label = $VBox/StatsBox/StatsLabel
@onready var derived_label: Label = $VBox/StatsBox/DerivedLabel
@onready var unique_card_label: Label = $VBox/UniqueCardLabel
@onready var select_button: Button = $VBox/SelectButton

var character_data: CharacterData

func setup(character: CharacterData) -> void:
	character_data = character
	
	if name_label:
		name_label.text = character.character_name
	
	if stats_label:
		stats_label.text = "STR:%d DEX:%d INT:%d\nWIS:%d DET:%d AGI:%d" % [
			character.strength,
			character.dexterity,
			character.intelligence,
			character.wisdom,
			character.determination,
			character.agility
		]
	
	if derived_label:
		derived_label.text = "HP:%d Mana:%d\nHand:%d Draw:%d" % [
			character.base_health,
			character.base_mana,
			character.get_max_hand_size(),
			character.base_draw_timer
		]
	
	if unique_card_label:
		unique_card_label.text = "Card: %s" % _get_unique_card_name(character.unique_card_id)
	
	if select_button:
		select_button.pressed.connect(_on_select_pressed)

func _get_unique_card_name(card_id: String) -> String:
	match card_id:
		"discard": return "Discard"
		"draw": return "Draw"
		"empower": return "Empower"
		"blink": return "Blink"
		"heal": return "Heal"
	return "Unknown"

func _on_select_pressed() -> void:
	selected.emit(character_data)
