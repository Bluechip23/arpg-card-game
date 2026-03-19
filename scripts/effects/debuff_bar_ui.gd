class_name DebuffBarUI
extends HBoxContainer

## Displays all active debuffs on a character

const DebuffIconScene = preload("res://scenes/effects/debuff_icon_ui.tscn")

var debuff_manager: DebuffManager

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

func connect_manager(manager: DebuffManager) -> void:
	debuff_manager = manager
	debuff_manager.debuffs_changed.connect(_on_debuffs_changed)
	_refresh_display()

func _on_debuffs_changed() -> void:
	_refresh_display()

func _refresh_display() -> void:
	# Clear existing icons
	for child in get_children():
		child.queue_free()
	
	if not debuff_manager:
		return
	
	# Create icon for each debuff
	for debuff in debuff_manager.debuffs:
		var icon = DebuffIconScene.instantiate() as DebuffIconUI
		add_child(icon)
		icon.setup(debuff)
