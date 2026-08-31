class_name PassiveBoxUI
extends Control

## Compact square HUD box for one active skill-tree passive: the passive's
## first letter (icon placeholder) inside a gold-trimmed box. At this size
## the level and recharge counter live in the tooltip; passives with a
## cooldown fade out while recharging (like the gauntlet skill circles) and
## solidify when ready. Cooldown-less passives stay solid.

const BOX_W := 15.0   # 1/3 of the original 44x54 tray boxes
const BOX_H := 18.0
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
		if _on_cooldown:
			# The box is too small for the on-box counter now — it lives here.
			tip += "\nRecharging: %d/%d" % [_elapsed, _total]
	tooltip_text = tip

func _draw() -> void:
	# Box body + gold trim (squares read as passives; circles are actives).
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.14, 0.2, 0.95), true)
	draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2(1, 1)), TRIM, false, 1.0)
	var font := get_theme_default_font()

	# First letter stands in for the icon. Level and recharge progress moved
	# to the tooltip — nothing else fits legibly at 1/3 scale; the fade alone
	# signals "recharging".
	var letter := display_name.left(1).to_upper()
	var letter_size := 9
	var sw := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, letter_size)
	draw_string(font, Vector2(size.x / 2.0 - sw.x / 2.0, size.y / 2.0 + 3.5), letter,
		HORIZONTAL_ALIGNMENT_CENTER, -1, letter_size, Color(0.95, 0.92, 0.85))
