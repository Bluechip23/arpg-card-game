class_name BuffIconUI
extends "res://scripts/shared/status_badge_ui.gd"

## Visual display for a single buff

var buff: Buff
var buff_manager: BuffManager = null  # set by the bar; enables click behavior

func setup(b: Buff) -> void:
	buff = b
	update_display()

func _on_hover_in() -> void:
	## The hover window: what the buff does and how long is left (live).
	if buff == null:
		return
	var b := buff
	StatusHoverPopup.show_for(self, b.buff_name, b.get_icon_color(), b.description,
		func() -> String:
			if not is_instance_valid(b):
				return ""
			return "Remaining: %s" % b.get_duration_display(),
		("Source: %s" % b.source_name) if b.source_name != "" else "",
		StatusIcons.get_icon(b.get_icon_key()))

func _gui_input(event: InputEvent) -> void:
	## The Precious: while in shadow form, clicking the Invisible badge steps
	## back out — allowed only after at least 1 tempo spent inside.
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if buff == null or buff.buff_type != Buff.BuffType.INVISIBLE:
		return
	if buff_manager == null or buff_manager.owner_stats == null:
		return
	var stats = buff_manager.owner_stats
	if stats.shadow_form_tempo <= 0:
		return
	# The counter starts at 10 and ticks per tempo — still at 10 means not a
	# single tempo has passed inside yet.
	if stats.shadow_form_tempo >= 10:
		print("[BUFF UI] Shadow form holds — spend at least 1 tempo inside first")
		return
	accept_event()
	stats.exit_shadow_form()

func _badge_text() -> String:
	## What is left of the effect: "xN" charges for charge-based buffs, else
	## stacks, else the count of a buff that burns its value down per use
	## (Thorns lose 1 per hit, Regen 1 per cycle); a timed buff shows its
	## remaining tempo as a plain countdown (Understanding's "4", "3", "2"…),
	## so the player sees when to make use of it. "" shows nothing.
	if buff.is_charge_based() and buff.charges > 0:
		return "x%d" % buff.charges
	if buff.stacks > 1:
		return "x%d" % buff.stacks
	if buff.value > 0 and buff.buff_type in [Buff.BuffType.THORNS, Buff.BuffType.REGEN]:
		return "x%d" % buff.value
	if buff.duration > 0:
		return "%d" % buff.duration
	return ""

func update_display() -> void:
	if not buff:
		return
	_paint(buff.get_icon_color(), StatusIcons.get_icon(buff.get_icon_key()), _badge_text())
