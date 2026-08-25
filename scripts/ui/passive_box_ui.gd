class_name PassiveBoxUI
extends Control

## Square HUD box for one active skill-tree passive: the passive's first
## letter (icon placeholder) inside a gold-trimmed box, with "lvl N" along the
## bottom. Passives with a cooldown behave like the gauntlet skill circles —
## the box fades out while recharging and a small "elapsed/total" tempo
## counter ticks up inside it. Cooldown-less passives stay solid.

const BOX_W := 44.0
const BOX_H := 54.0
const TRIM := Color(0.85, 0.7, 0.35)  # gold, same as the gauntlet skill rim
# Preloaded (not the UiTheme autoload identifier) so headless test runs
# without autoloads can still compile this script.
const UiThemeScript = preload("res://scripts/ui/ui_theme.gd")

var passive_id: String = ""
var display_name: String = ""
var stats: PlayerStats = null
var tempo_manager: TempoManager = null

var _wrapped_desc: String = ""
var _on_cooldown := false
var _elapsed := 0
var _total := 0

func _ready() -> void:
	custom_minimum_size = Vector2(BOX_W, BOX_H)

func setup(id: String, p_name: String, description: String, p_stats: PlayerStats, p_tempo: TempoManager) -> void:
	passive_id = id
	display_name = p_name if p_name != "" else id.capitalize()
	_wrapped_desc = UiThemeScript.wrap_text(description) if description != "" else ""
	stats = p_stats
	tempo_manager = p_tempo
	update_display()

func update_display() -> void:
	var st: Dictionary = PassiveCooldowns.status(passive_id, stats, tempo_manager)
	_on_cooldown = st.on_cooldown
	_elapsed = st.elapsed
	_total = st.total
	# Same recharge look as GauntletSkillUI: faded while unavailable.
	modulate = Color(0.5, 0.5, 0.5, 0.35) if _on_cooldown else Color(1, 1, 1, 1)
	_refresh_tooltip(st)
	queue_redraw()

func _refresh_tooltip(st: Dictionary) -> void:
	var lvl: int = stats.get_passive_level(passive_id) if stats else 0
	var tip := "%s — lvl %d" % [display_name, lvl]
	if _wrapped_desc != "":
		tip += "\n" + _wrapped_desc
	if st.has_cooldown:
		tip += "\nCooldown: %d tempo" % st.total
	tooltip_text = tip

func _draw() -> void:
	# Box body + gold trim (squares read as passives; circles are actives).
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.14, 0.2, 0.95), true)
	draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), TRIM, false, 2.0)
	var font := get_theme_default_font()
	var cx := size.x / 2.0

	# "lvl N" along the bottom of the box
	var lvl: int = stats.get_passive_level(passive_id) if stats else 0
	var lvl_txt := "lvl %d" % lvl
	var lvl_size := 10
	var lw := font.get_string_size(lvl_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, lvl_size)
	draw_string(font, Vector2(cx - lw.x / 2.0, size.y - 5.0), lvl_txt,
		HORIZONTAL_ALIGNMENT_CENTER, -1, lvl_size, TRIM)

	# First letter stands in for the icon; it rides up while recharging so the
	# tempo counter fits beneath it (mirrors GauntletSkillUI).
	var letter := display_name.left(1).to_upper()
	var letter_size := 16 if _on_cooldown else 20
	var sw := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, letter_size)
	var letter_y := 20.0 if _on_cooldown else 27.0
	draw_string(font, Vector2(cx - sw.x / 2.0, letter_y), letter,
		HORIZONTAL_ALIGNMENT_CENTER, -1, letter_size, Color(0.95, 0.92, 0.85))

	if _on_cooldown:
		var counter := "%d/%d" % [_elapsed, _total]
		var counter_size := 9
		var cw := font.get_string_size(counter, HORIZONTAL_ALIGNMENT_CENTER, -1, counter_size)
		draw_string(font, Vector2(cx - cw.x / 2.0, 33.0), counter,
			HORIZONTAL_ALIGNMENT_CENTER, -1, counter_size, Color(1.0, 0.85, 0.4))
