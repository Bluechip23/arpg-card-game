class_name OverflowUI
extends PanelContainer

## Displays active overflow effects

@onready var effects_label: Label = $VBox/EffectsLabel

var overflow_manager: OverflowManager

func connect_overflow_manager(om: OverflowManager) -> void:
	overflow_manager = om
	overflow_manager.overflow_effects_changed.connect(_on_effects_changed)
	_refresh_display()

func _on_effects_changed() -> void:
	_refresh_display()

func _refresh_display() -> void:
	if not overflow_manager:
		visible = false
		return
	
	var effects = overflow_manager.get_active_effects_display()
	
	if effects.size() == 0:
		visible = false
		return
	
	visible = true
	
	if effects_label:
		effects_label.text = "Overflow Effects:\n" + "\n".join(effects)
