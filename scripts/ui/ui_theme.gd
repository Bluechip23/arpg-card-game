extends Node
## Autoload (UiTheme). Makes every engine tooltip match the game's popup
## styling — dark panel, gold border, rounded corners, the T&O sigil in the
## top-left corner — and re-wraps long one-line tooltip strings into readable
## blocks instead of letting them run the full width of the screen.
## Explicit per-control theme overrides (existing popups) are unaffected.

const WRAP_WIDTH := 52  # characters per tooltip line

func _ready() -> void:
	# Style tooltips via the engine DEFAULT theme: tooltip popups are separate
	# embedded Windows that don't inherit the root window's theme, but every
	# control and window falls back to ThemeDB's default theme.
	var theme := ThemeDB.get_default_theme()
	theme.set_stylebox("panel", "TooltipPanel", _build_tooltip_stylebox())
	theme.set_color("font_color", "TooltipLabel", Color(0.85, 0.85, 0.9))
	theme.set_font_size("font_size", "TooltipLabel", 13)
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
	# Hand-formatted tooltips (already multi-line) are left alone.
	if text.length() > WRAP_WIDTH and "\n" not in text:
		node.tooltip_text = wrap_text(text)

static func wrap_text(text: String, width: int = WRAP_WIDTH) -> String:
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

# ---- Theme construction -----------------------------------------------------

func _build_tooltip_stylebox() -> StyleBoxTexture:
	## A 9-patch panel drawn to match the game's popups (skill tree / stat
	## allocation style), with the T&O sigil baked into the top-left corner.
	## The corner regions never stretch, so the sigil stays crisp.
	const SIZE := 72
	const RADIUS := 8.0
	const BORDER := 2.0
	var bg := Color(0.08, 0.08, 0.14, 0.98)
	var border_col := Color(0.5, 0.4, 0.2)

	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var half := SIZE * 0.5
	for py in range(SIZE):
		for px in range(SIZE):
			# Rounded-rect signed distance: inside when d <= 0.
			var q := Vector2(absf(px + 0.5 - half), absf(py + 0.5 - half)) - Vector2(half - RADIUS, half - RADIUS)
			var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - RADIUS
			if d <= 0.0:
				img.set_pixel(px, py, border_col if d > -BORDER else bg)

	# Stamp the sigil into the top-left corner.
	var sigil: Texture2D = UIGlyphs.get_glyph("to_sigil")
	if sigil:
		img.blend_rect(sigil.get_image(), Rect2i(0, 0, 24, 24), Vector2i(4, 4))

	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.texture_margin_left = 30
	sb.texture_margin_top = 30
	sb.texture_margin_right = 10
	sb.texture_margin_bottom = 10
	sb.content_margin_left = 34   # keep text clear of the sigil column
	sb.content_margin_top = 8
	sb.content_margin_right = 12
	sb.content_margin_bottom = 8
	return sb
