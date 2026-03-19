class_name ManifestCardUI
extends Button

## Single manifest card button in the manifest zone

signal clicked(index: int)

var card_index: int
var manifest_entry: Dictionary

func _ready() -> void:
	pressed.connect(_on_pressed)

func setup_from_entry(entry: Dictionary, index: int) -> void:
	manifest_entry = entry
	card_index = index
	
	# Display manifest name, not original card name
	text = entry["manifest_name"]
	
	tooltip_text = "%s\n%s\n\nOriginal card: %s\nCost: %dM %dT" % [
		entry["manifest_name"],
		entry["manifest_description"],
		entry["card"].card_name,
		entry["mana_cost"],
		entry["tempo_cost"]
	]
	
	# Color based on effect type
	var effect_id = entry["manifest_id"]
	if effect_id.begins_with("summon_"):
		add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))  # Purple for summons
	elif effect_id.begins_with("use_"):
		add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))  # Green for consumables
	elif effect_id == "deal_damage":
		add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))  # Red for damage
	else:
		add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))

func _on_pressed() -> void:
	clicked.emit(card_index)
