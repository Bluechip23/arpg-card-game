class_name DebuffIconUI
extends PanelContainer

## Visual display for a single debuff

@onready var icon_rect: ColorRect = $IconRect
@onready var name_label: Label = $VBox/NameLabel
@onready var duration_label: Label = $VBox/DurationLabel

var debuff: Debuff

func setup(d: Debuff) -> void:
	debuff = d
	update_display()

func update_display() -> void:
	if not debuff:
		return
	
	if icon_rect:
		icon_rect.color = debuff.get_icon_color()
	
	if name_label:
		name_label.text = debuff.debuff_name
		name_label.tooltip_text = debuff.description
	
	if duration_label:
		if debuff.duration < 0:
			duration_label.text = "∞"
		else:
			duration_label.text = str(debuff.duration) 
