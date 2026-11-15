extends SceneTree

## The designer's painted card art (2026-11-15): a card listed in
## SkillIconArt.CARD_PAINTINGS shows its painting in the art window, filling
## it (cropped top and bottom) inside the frame's painted rim; a card without
## one keeps its centred icon, and the icon elsewhere (card slots, the
## maintained list) is unchanged.
## Run: godot --headless --path . --script tests/test_card_paintings.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	_run.call_deferred()

func _face(card_id: String) -> CardUI:
	var card: Card = load("res://data/cards/%s.tres" % card_id).duplicate()
	var ui: CardUI = (load("res://scenes/cards/card_ui.tscn") as PackedScene).instantiate()
	get_root().add_child(ui)
	ui.setup(card, 0)
	return ui

func _art(ui: CardUI) -> TextureRect:
	return ui.art_box.get_node_or_null("ArtRect") as TextureRect

func _run() -> void:
	print("=== Painted card art ===")
	for id in ["basic_attack", "block"]:
		var ui := _face(id)
		await process_frame
		var art := _art(ui)
		_check(art != null and art.visible and art.texture != null
			and art.texture.resource_path.ends_with("cards/art/%s.png" % id),
			"%s shows its painting" % id)
		_check(art != null and art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED,
			"%s's painting fills the window" % id)
		var card: Card = load("res://data/cards/%s.tres" % id)
		var icon := SkillIconArt.card(card)
		_check(icon != null and not icon.resource_path.contains("cards/art/"),
			"%s keeps its icon for the small slots" % id)

	# The Attack frame's window starts right of the axe handle: the art box
	# is inset so the painting stops at the rim.
	var atk := _face("basic_attack")
	await process_frame
	var sb := atk.art_box.get_theme_stylebox("panel")
	_check(sb != null and sb.content_margin_left >= 9.0, "the Attack window is inset past the axe handle")

	var slash := _face("slash")
	await process_frame
	var sart := _art(slash)
	_check(sart != null and sart.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
		"a card with no painting keeps its centred icon")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
