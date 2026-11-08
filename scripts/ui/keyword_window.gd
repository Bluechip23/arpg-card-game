class_name KeywordWindow
extends PanelContainer

## A companion column that sits beside a card view — the chest loot modal,
## the card-inventory confirm popup — with a box per keyword the card
## carries (Burden, Sticky, Glut, Maintain, Arrow...) and what it does. The card face only has room for the word; this is where the player
## learns what the word means without opening the help compendium.
##
## Usage (both call sites are synchronous builders, so placement is deferred
## inside this node):
##     var kw := KeywordWindow.for_card(card)
##     if kw:
##         parent.add_child(kw)
##         kw.place_beside(modal)

const WIDTH := 280.0
const KeywordBoxes = preload("res://scripts/ui/keyword_boxes.gd")
const GAP := 10.0

## Builds the window for `card`, or returns null when the card has no
## keywords (so callers never show an empty box).
static func for_card(card: Card) -> KeywordWindow:
	if card == null:
		return null
	var keywords: Array = card.get_matching_keywords()
	if keywords.is_empty():
		return null
	var win := KeywordWindow.new()
	win._build(keywords)
	return win

func _build(keywords: Array) -> void:
	name = "KeywordWindow"
	custom_minimum_size = Vector2(WIDTH, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP  # clicks here don't fall through to the dim overlay
	z_index = 210  # above the card popup it accompanies
	# No frame of its own: each keyword is its own box (KeywordBoxes).
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	EmeraldTheme.apply_in_game(self)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)
	for kw in keywords:
		vbox.add_child(KeywordBoxes.make_box(str(kw["keyword"]), str(kw["definition"]), WIDTH))

## Park this window just right of `host` (same parent, top edges aligned),
## or on its left when the right side would leave the screen. Waits for the
## layout pass so both rects are final — callers that centre their popup a
## frame later are covered too.
func place_beside(host: Control) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(host) or not is_instance_valid(self):
		return
	var screen_w := get_viewport_rect().size.x
	var x := host.position.x + host.size.x + GAP
	if x + size.x > screen_w - 4.0:
		x = host.position.x - size.x - GAP
	x = maxf(4.0, x)
	position = Vector2(x, host.position.y)
