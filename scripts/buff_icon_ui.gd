class_name BuffIconUI
extends PanelContainer

## Visual display for a single buff

@onready var icon_rect: ColorRect = $IconRect
@onready var name_label: Label = $VBox/NameLabel
@onready var duration_label: Label = $VBox/DurationLabel

var buff: Buff

func setup(b: Buff) -> void:
	buff = b
	update_display()

func update_display() -> void:
	if not buff:
		return
	
	if icon_rect:
		icon_rect.color = buff.get_icon_color()
	
	if name_label:
		name_label.text = buff.buff_name
		name_label.tooltip_text = buff.description
	
	if duration_label:
		duration_label.text = buff.get_duration_display()	
