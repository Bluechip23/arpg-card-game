class_name GauntletSkillUI
extends Button

## Visual button for gauntlet skills

signal skill_activated(gauntlet: ItemData)

var gauntlet: ItemData
var _on_cooldown: bool = false

@onready var cooldown_label: Label = $CooldownLabel

func setup(item: ItemData) -> void:
	gauntlet = item
	
	text = item.gauntlet_skill_name
	tooltip_text = "%s\n%s\nCost: %d Mana | CD: %d turns" % [
		item.gauntlet_skill_name,
		item.gauntlet_skill_description,
		item.gauntlet_skill_mana_cost,
		item.gauntlet_skill_cooldown
	]
	
	update_display()

func update_display() -> void:
	if not gauntlet:
		return
	
	_on_cooldown = gauntlet.is_on_cooldown()
	
	if _on_cooldown:
		# Transparent/faded look so player knows it's unavailable
		modulate = Color(0.5, 0.5, 0.5, 0.35)
		disabled = true
		if cooldown_label:
			cooldown_label.visible = true
			cooldown_label.text = str(gauntlet.current_cooldown)
	else:
		# Active and fully visible
		modulate = Color(1, 1, 1, 1)
		disabled = false
		if cooldown_label:
			cooldown_label.visible = false

func _pressed() -> void:
	if not _on_cooldown and gauntlet:
		skill_activated.emit(gauntlet)
