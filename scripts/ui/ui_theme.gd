extends Node
## Autoload (UiTheme). Makes every engine tooltip match the game's popup
## styling — Emerald Sanctum glass, gold border, Courgette, rounded corners,
## the T&O sigil in the top-left corner — and re-wraps any overlong tooltip line into readable
## blocks instead of letting it run the full width of the screen.
## Explicit per-control theme overrides (existing popups) are unaffected.

const WRAP_WIDTH := 52  # characters per tooltip line

func _ready() -> void:
	# Style tooltips via the engine DEFAULT theme: tooltip popups are separate
	# embedded Windows that don't inherit the root window's theme, but every
	# control and window falls back to ThemeDB's default theme.
	var theme := ThemeDB.get_default_theme()
	# Emerald Sanctum, like the menus: dark emerald glass, gold frame, Courgette.
	theme.set_stylebox("panel", "TooltipPanel",
		CrestStyleBox.new(EmeraldTheme.PANEL_BG_SOLID, EmeraldTheme.GOLD_DIM))
	theme.set_color("font_color", "TooltipLabel", EmeraldTheme.TEXT)
	theme.set_font("font", "TooltipLabel", EmeraldTheme.font())
	theme.set_font_size("font_size", "TooltipLabel", 14)
	get_tree().node_added.connect(_on_node_added)

# ---- Tooltip block-wrapping -------------------------------------------------

func _on_node_added(node: Node) -> void:
	if node is Control:
		# Deferred: tooltip_text is usually assigned right after add_child.
		_wrap_tooltip.call_deferred(node)

func _wrap_tooltip(node) -> void:
	if not is_instance_valid(node):
		return
	var text: String = node.tooltip_text
	var wrapped := wrap_text(text)
	if wrapped != text:
		node.tooltip_text = wrapped

## Re-wraps overlong lines into WRAP_WIDTH-character blocks. Hand-placed line
## breaks are kept, so multi-line tooltips only have their long lines re-cut —
## a single long description line no longer stretches across the screen.
static func wrap_text(text: String, width: int = WRAP_WIDTH) -> String:
	if text.length() <= width:
		return text
	var out: Array[String] = []
	for line in text.split("\n"):
		out.append(_wrap_line(line, width) if line.length() > width else line)
	return "\n".join(out)

static func _wrap_line(text: String, width: int) -> String:
	var lines: Array[String] = []
	var line := ""
	for word in text.split(" "):
		if line == "":
			line = word
		elif line.length() + 1 + word.length() <= width:
			line += " " + word
		else:
			lines.append(line)
			line = word
	if line != "":
		lines.append(line)
	return "\n".join(lines)

