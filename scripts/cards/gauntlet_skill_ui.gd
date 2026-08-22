class_name GauntletSkillUI
extends Button

## Circular button for an active gauntlet skill: the skill's starting letter
## inside a circle. While recharging the button fades out and a small
## "elapsed/total" tempo counter sits under the letter (0/5 right after use,
## 4/5 with one tempo to go), ticking up as tempo passes.

signal skill_activated(gauntlet: ItemData)

const DIAMETER := 44.0

var gauntlet: ItemData
var tempo_manager: TempoManager = null  # set by main before setup(); drives the counter
var _on_cooldown: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(DIAMETER, DIAMETER)
	# The circle is drawn by hand — blank out the Button's own rectangle chrome.
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())

func setup(item: ItemData) -> void:
	gauntlet = item
	tooltip_text = "%s\n%s\nCost: %d Mana | Recharge: %d tempo" % [
		item.gauntlet_skill_name,
		item.gauntlet_skill_description,
		item.gauntlet_skill_mana_cost,
		_total_recharge_tempo(),
	]
	update_display()

## Full recharge time in tempo. current_cooldown is stored in 5-tempo cycles
## (see Inventory.process_turn), so the tempo view is cycles * threshold.
func _total_recharge_tempo() -> int:
	var threshold: int = tempo_manager.tempo_threshold if tempo_manager else 5
	return gauntlet.gauntlet_skill_cooldown * threshold

## Tempo already recharged. The pending cycle completes when the in-cycle
## counter wraps, so tempo inside the current cycle counts toward progress.
func _elapsed_recharge_tempo() -> int:
	var threshold: int = tempo_manager.tempo_threshold if tempo_manager else 5
	var in_cycle: int = tempo_manager.current_tempo if tempo_manager else 0
	var remaining: int = maxi(0, gauntlet.current_cooldown * threshold - in_cycle)
	return clampi(_total_recharge_tempo() - remaining, 0, _total_recharge_tempo())

func update_display() -> void:
	if not gauntlet:
		return
	_on_cooldown = gauntlet.is_on_cooldown()
	if _on_cooldown:
		# Transparent/faded look so player knows it's unavailable
		modulate = Color(0.5, 0.5, 0.5, 0.35)
		disabled = true
	else:
		# Active and fully visible
		modulate = Color(1, 1, 1, 1)
		disabled = false
	queue_redraw()

func _draw() -> void:
	if not gauntlet:
		return
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 1.0
	draw_circle(center, radius, Color(0.16, 0.14, 0.2, 0.95))
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.85, 0.7, 0.35), 2.0, true)

	var font := get_theme_default_font()
	var letter: String = gauntlet.gauntlet_skill_name.left(1).to_upper()
	if _on_cooldown:
		# Letter rides higher to make room for the recharge counter below it.
		var letter_size := 18
		var lw := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, letter_size)
		draw_string(font, Vector2(center.x - lw.x / 2.0, center.y - 2.0), letter,
			HORIZONTAL_ALIGNMENT_CENTER, -1, letter_size, Color(0.95, 0.92, 0.85))
		var counter := "%d/%d" % [_elapsed_recharge_tempo(), _total_recharge_tempo()]
		var counter_size := 10
		var cw := font.get_string_size(counter, HORIZONTAL_ALIGNMENT_CENTER, -1, counter_size)
		draw_string(font, Vector2(center.x - cw.x / 2.0, center.y + counter_size), counter,
			HORIZONTAL_ALIGNMENT_CENTER, -1, counter_size, Color(1.0, 0.85, 0.4))
	else:
		var letter_size := 22
		var lw := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, letter_size)
		draw_string(font, Vector2(center.x - lw.x / 2.0, center.y + lw.y / 2.0 - 4.0), letter,
			HORIZONTAL_ALIGNMENT_CENTER, -1, letter_size, Color(0.95, 0.92, 0.85))

func _pressed() -> void:
	if not _on_cooldown and gauntlet:
		skill_activated.emit(gauntlet)
