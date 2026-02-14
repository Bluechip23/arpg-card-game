class_name BuffBarUI
extends HBoxContainer

## Displays all active buffs on a character

const BuffIconScene = preload("res://scenes/buff_icon_ui.tscn")

var buff_manager: BuffManager

func connect_manager(manager: BuffManager) -> void:
	buff_manager = manager
	buff_manager.buffs_changed.connect(_on_buffs_changed)
	_refresh_display()

func _on_buffs_changed() -> void:
	_refresh_display()

func _refresh_display() -> void:
	for child in get_children():
		child.queue_free()
	
	if not buff_manager:
		return
	
	for buff in buff_manager.buffs:
		var icon = BuffIconScene.instantiate() as BuffIconUI
		add_child(icon)
		icon.setup(buff)
