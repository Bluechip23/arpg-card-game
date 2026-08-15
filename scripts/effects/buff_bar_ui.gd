class_name BuffBarUI
extends HBoxContainer

## Displays all active buffs on a character as a row of small badges.

const BuffIconScene = preload("res://scenes/effects/buff_icon_ui.tscn")

var buff_manager: BuffManager

# Controls that live in the bar but aren't buffs (e.g. the maintained-cards
# icon). They survive refreshes and stay pinned at the front of the row.
var _pinned: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

func pin_front(control: Control) -> void:
	## Add a persistent control that always renders before the buff icons.
	_pinned.append(control)
	add_child(control)
	move_child(control, 0)

func connect_manager(manager: BuffManager) -> void:
	buff_manager = manager
	buff_manager.buffs_changed.connect(_on_buffs_changed)
	_refresh_display()

func _on_buffs_changed() -> void:
	_refresh_display()

func _refresh_display() -> void:
	for child in get_children():
		if child in _pinned:
			continue
		child.queue_free()

	if not buff_manager:
		return

	for buff in buff_manager.buffs:
		var icon = BuffIconScene.instantiate() as BuffIconUI
		add_child(icon)
		icon.setup(buff)
		icon.buff_manager = buff_manager  # ring pass: shadow-form badge is clickable

	# Keep pinned controls at the front of the row.
	for i in range(_pinned.size() - 1, -1, -1):
		var c = _pinned[i]
		if is_instance_valid(c):
			move_child(c, 0)
