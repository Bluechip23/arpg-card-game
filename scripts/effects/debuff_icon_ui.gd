class_name DebuffIconUI
extends "res://scripts/shared/status_badge_ui.gd"

## Visual display for a single debuff

var debuff: Debuff

func setup(d: Debuff) -> void:
	debuff = d
	update_display()

func _on_hover_in() -> void:
	## The hover window: what the debuff does and how long is left (live).
	if debuff == null:
		return
	var d := debuff
	var extra := ""
	if d.stacks > 1:
		extra = "Stacks: %d" % d.stacks
	if d.source_name != "":
		extra += ("\n" if extra != "" else "") + "Source: %s" % d.source_name
	StatusHoverPopup.show_for(self, d.debuff_name, d.get_icon_color(), d.description,
		func() -> String:
			if not is_instance_valid(d):
				return ""
			if d.duration < 0:
				return "Remaining: no fixed timer (see above)"
			return "Remaining: %d tempo" % d.duration,
		extra, StatusIcons.get_icon(d.debuff_name))

## Debuffs that only run on the clock (or whose value is not a count, like
## Hexed's +X mana): they show no xN — the hover window has the clock.
const NO_COUNT_TYPES := [Debuff.DebuffType.STUN, Debuff.DebuffType.SILENCE, Debuff.DebuffType.DISARM,
	Debuff.DebuffType.FROZEN, Debuff.DebuffType.ROOTED, Debuff.DebuffType.CURSED, Debuff.DebuffType.CUFFED,
	Debuff.DebuffType.LOCKED, Debuff.DebuffType.HEXED]

func _badge_count() -> int:
	## xN — what is left of the debuff: stacks when >1, else its value (the
	## charges of Bleed 3, Poison 2, ...). Timed-only debuffs (Stun, Silence,
	## a clock-timed Slowed) show no count; the hover window has the clock.
	if debuff.stacks > 1:
		return debuff.stacks
	if debuff.clock_timed or debuff.debuff_type in NO_COUNT_TYPES:
		return -1
	if debuff.value > 0:
		return debuff.value
	return -1

func update_display() -> void:
	if not debuff:
		return
	var n := _badge_count()
	_paint(debuff.get_icon_color(), StatusIcons.get_icon(debuff.debuff_name), ("x%d" % n) if n > 0 else "")
