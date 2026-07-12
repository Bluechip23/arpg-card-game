class_name DebuffBarUI
extends HBoxContainer

## Displays all active debuffs on a character

const DebuffIconScene = preload("res://scenes/effects/debuff_icon_ui.tscn")

var debuff_manager: DebuffManager

# Controls that live in the bar but aren't debuffs (e.g. the jailed-cards
# cage icon). They survive refreshes and stay pinned at the front of the row.
var _pinned: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

func pin_front(control: Control) -> void:
	## Add a persistent control that always renders before the debuff icons.
	_pinned.append(control)
	add_child(control)
	move_child(control, 0)

func connect_manager(manager: DebuffManager) -> void:
	debuff_manager = manager
	debuff_manager.debuffs_changed.connect(_on_debuffs_changed)
	_refresh_display()

func _on_debuffs_changed() -> void:
	_refresh_display()

func _refresh_display() -> void:
	# Clear existing icons
	for child in get_children():
		if child in _pinned:
			continue
		child.queue_free()

	if not debuff_manager:
		return

	# Create icon for each debuff
	for debuff in debuff_manager.debuffs:
		var icon = DebuffIconScene.instantiate() as DebuffIconUI
		add_child(icon)
		icon.setup(debuff)

	# Keep pinned controls at the front of the row.
	for i in range(_pinned.size() - 1, -1, -1):
		var c = _pinned[i]
		if is_instance_valid(c):
			move_child(c, 0)
