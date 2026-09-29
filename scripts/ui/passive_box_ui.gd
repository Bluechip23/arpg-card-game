class_name PassiveBoxUI
extends Control

## Compact square HUD box for one active skill-tree passive: the passive's
## Craftpix skill icon (first letter when no art resolves) inside a gold-trimmed box. At this size
## the level and recharge counter live in the tooltip; passives with a
## cooldown fade out while recharging (like the gauntlet skill circles) and
## solidify when ready. Cooldown-less passives stay solid.

const BOX_W := 30.0   # 2/3 of the original 44x54 tray boxes (doubled from 15x18)
const BOX_H := 36.0
const TRIM := Color(0.85, 0.7, 0.35)  # gold, same as the gauntlet skill rim
# Preloaded (not the UiTheme autoload identifier) so headless test runs
# without autoloads can still compile this script.
const UiThemeScript = preload("res://scripts/ui/ui_theme.gd")

var passive_id: String = ""
var display_name: String = ""
var stats: PlayerStats = null
var tempo_manager: TempoManager = null

var _wrapped_desc: String = ""
var _raw_desc: String = ""
var _icon: Texture2D = null  # Craftpix skill icon (letter fallback when null)
var _on_cooldown := false
var _elapsed := 0
var _total := 0
# Counter mode (item passives that build toward a proc, e.g. the Heal
# Stone's "every 5 healing"): the provider returns {"count", "total"} and the
# box shows the tally in its corner instead of a cooldown fade.
var _counter_provider: Callable = Callable()
var _count := 0
var _count_total := 0

func _ready() -> void:
	custom_minimum_size = Vector2(BOX_W, BOX_H)

func setup(id: String, p_name: String, description: String, p_stats: PlayerStats, p_tempo: TempoManager) -> void:
	passive_id = id
	display_name = p_name if p_name != "" else id.capitalize()
	_raw_desc = description
	_wrapped_desc = UiThemeScript.wrap_text(description) if description != "" else ""
	stats = p_stats
	tempo_manager = p_tempo
	_icon = SkillIconArt.passive(passive_id)
	update_display()

## An item passive with a running tally: `provider` -> {"count": int, "total": int}.
func setup_counter(id: String, p_name: String, description: String, provider: Callable, icon: Texture2D = null) -> void:
	passive_id = id
	display_name = p_name
	_raw_desc = description
	_wrapped_desc = UiThemeScript.wrap_text(description) if description != "" else ""
	_counter_provider = provider
	_icon = icon if icon != null else SkillIconArt.passive(passive_id)
	update_display()

func update_display() -> void:
	if _counter_provider.is_valid():
		var c: Dictionary = _counter_provider.call()
		_count = int(c.get("count", 0))
		_count_total = int(c.get("total", 0))
		modulate = Color(1, 1, 1, 1)
		tooltip_text = "%s\n%s\nProgress: %d / %d" % [display_name, _wrapped_desc, _count, _count_total]
		queue_redraw()
		return
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
	if _raw_desc != "":
		# What the passive does at THIS rank — the 1→15 ranges stay in the tree.
		var at_rank: String = PassiveScaling.describe_at_rank(passive_id, _raw_desc, maxi(1, lvl))
		tip += "\n" + UiThemeScript.wrap_text(at_rank)
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
	if _icon != null:
		# Pack icon fills the box inside the trim.
		draw_texture_rect(_icon, Rect2(Vector2(1.5, 1.5), size - Vector2(3, 3)), false)
		_draw_counter(font)
		return

	# First letter stands in for the icon. Level and recharge progress moved
	# to the tooltip — nothing else fits legibly at 1/3 scale; the fade alone
	# signals "recharging".
	var letter := display_name.left(1).to_upper()
	var letter_size := 18
	var sw := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, letter_size)
	draw_string(font, Vector2(size.x / 2.0 - sw.x / 2.0, size.y / 2.0 + 7.0), letter,
		HORIZONTAL_ALIGNMENT_CENTER, -1, letter_size, Color(0.95, 0.92, 0.85))
	_draw_counter(font)

## The tally, bottom-right on a dark pill, plus a thin fill bar along the
## bottom edge so the build-up reads at a glance.
func _draw_counter(font: Font) -> void:
	if not _counter_provider.is_valid() or _count_total <= 0:
		return
	var frac := clampf(float(_count) / float(_count_total), 0.0, 1.0)
	draw_rect(Rect2(Vector2(1.5, size.y - 3.5), Vector2((size.x - 3.0) * frac, 2.0)), TRIM, true)
	var txt := "%d/%d" % [_count, _count_total]
	var fs := 9
	var sw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_RIGHT, -1, fs)
	var pill := Rect2(Vector2(size.x - sw.x - 4.0, size.y - 15.0), Vector2(sw.x + 3.0, 11.0))
	draw_rect(pill, Color(0.05, 0.05, 0.08, 0.85), true)
	draw_string(font, Vector2(pill.position.x + 1.5, pill.position.y + 9.0), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.92, 0.7))
