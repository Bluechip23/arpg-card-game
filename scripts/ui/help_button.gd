class_name HelpButtons
extends HBoxContainer

## Buttons to open help panel

signal keywords_pressed
signal walkthrough_pressed

@onready var keywords_button: Button = $KeywordsButton
@onready var walkthrough_button: Button = $WalkthroughButton

func _ready() -> void:
	if keywords_button:
		keywords_button.pressed.connect(_on_keywords_pressed)
	if walkthrough_button:
		walkthrough_button.pressed.connect(_on_walkthrough_pressed)

func _on_keywords_pressed() -> void:
	keywords_pressed.emit()

func _on_walkthrough_pressed() -> void:
	walkthrough_pressed.emit()
