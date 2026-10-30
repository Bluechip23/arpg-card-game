extends SceneTree

## The designer's painted card frames (2026-10-30): an Instant wears the
## painted Instant frame — the frame behind the face, the bars bare, the costs
## written on its painted drop and hourglass, the logo on its ring spot, the
## rules text in ink on the parchment. Types without a frame of their own
## keep the drawn one.
## Every card with an upkeep wears the Maintain frame instead (white text on
## its stone); a Defense card the Defensive frame; a Utility card the Utility
## frame (the logo where its art meets its rules box); an Attack the Attack
## frame.
## Run: godot --headless --path . --script tests/test_card_frames.gd

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

func _run() -> void:
	print("=== Painted card frames ===")
	var inst := _face("mage_shield")
	await process_frame
	var art: TextureRect = inst.get_node_or_null("Panel/FrameArt")
	_check(art != null and art.texture != null and art.texture.resource_path.ends_with("frame_instant.png"),
		"an Instant wears the painted Instant frame")
	_check(art != null and art.get_index() == 0, "the frame is drawn behind the face")
	_check(inst.get_theme_stylebox("panel") is StyleBoxEmpty, "no drawn border round it")
	_check(inst.title_bar.get_theme_stylebox("panel") is StyleBoxEmpty and inst.desc_panel.get_theme_stylebox("panel") is StyleBoxEmpty,
		"its bars are bare, the painting shows")
	var icons_hidden := true
	for c in inst._mana_badge.get_children() + inst._tempo_badge.get_children():
		if c is TextureRect and c.visible:
			icons_hidden = false
	_check(icons_hidden, "the costs are written on the painted drop and hourglass")
	_check(absf(inst._mana_badge.position.x + inst._mana_badge.size.x * 0.5 - CardUI.FRAMES["instant"]["mana_at"].x) < 0.5,
		"the mana sits on the drop")
	_check(inst.get_node_or_null("Panel/FrameLogo") != null, "the logo sits on the frame's ring spot")
	_check(inst.desc_label.get_theme_color("default_color").v < 0.3, "the rules text is ink on the parchment")
	inst.set_selected(true)
	var sel := inst.get_theme_stylebox("panel") as StyleBoxFlat
	_check(sel != null and not sel.draw_center, "chosen, a gold ring goes round the painting (not over it)")
	inst.set_selected(false)
	_check(inst.get_theme_stylebox("panel") is StyleBoxEmpty, "and comes off again")

	# Every card with an upkeep wears the Maintain frame, whatever its type.
	for id in ["armored_discipline", "forever_armor", "peshtigos_kiss"]:
		var m := _face(id)
		await process_frame
		var ma: TextureRect = m.get_node_or_null("Panel/FrameArt")
		_check(ma != null and ma.texture.resource_path.ends_with("frame_maintain.png"),
			"%s (upkeep %d) wears the Maintain frame" % [id, m.get_card().maintain_cost])
		_check(m.desc_label.get_theme_color("default_color").v > 0.8, "%s's rules text is white on the stone" % id)
		_check(m.type_label.text == "Maintain", "%s's type line says Maintain" % id)
		var up: Label = m.get_node_or_null("Panel/Upkeep")
		_check(up != null and up.text == "%dM" % m.get_card().maintain_cost, "%s's upkeep sits beside the dots" % id)
		m.queue_free()

	# Defense cards wear the Defensive frame.
	var d := _face("block")
	await process_frame
	var da: TextureRect = d.get_node_or_null("Panel/FrameArt")
	_check(da != null and da.texture.resource_path.ends_with("frame_defensive.png"), "a Defense card wears the Defensive frame")
	_check(d.desc_label.get_theme_color("default_color").v > 0.8, "its rules text is white on the stone")
	d.queue_free()

	# Utility cards wear the Utility frame, the logo where its art meets its
	# rules box.
	var u := _face("blink")
	await process_frame
	var ua: TextureRect = u.get_node_or_null("Panel/FrameArt")
	_check(ua != null and ua.texture.resource_path.ends_with("frame_utility.png"), "a Utility card wears the Utility frame")
	var ul: Control = u.get_node_or_null("Panel/FrameLogo")
	_check(ul != null and absf(ul.position.y + ul.size.y * 0.5 - CardUI.FRAMES["utility"]["logo_at"].y) <= 1.0, "its logo sits where the art window meets the rules box")
	u.queue_free()

	# Attack cards wear the Attack frame, the name clear of its axe head.
	var atk := _face("slash")
	await process_frame
	var aa: TextureRect = atk.get_node_or_null("Panel/FrameArt")
	_check(aa != null and aa.texture.resource_path.ends_with("frame_attack.png"), "an Attack wears the Attack frame")
	_check(atk.title_bar.get_theme_stylebox("panel").content_margin_left >= 37.0, "its name starts right of the axe head")
	atk.queue_free()

	# A spell is not an attack: Fireball (an offensive spell, stored as an
	# Attack-type card) wears the Spell frame.
	var sp := _face("fireball")
	await process_frame
	var spa: TextureRect = sp.get_node_or_null("Panel/FrameArt")
	_check(spa != null and spa.texture.resource_path.ends_with("frame_spell.png"),
		"an offensive spell wears the Spell frame, not the Attack one")
	sp.queue_free()

	# A type the designer has not framed yet keeps the drawn frame.
	for f in DirAccess.get_files_at("res://data/cards"):
		if not f.ends_with(".tres"):
			continue
		var c: Card = load("res://data/cards/" + f)
		if c.card_type == Card.CardType.ENCHANTMENT and c.maintain_cost == 0:
			var e := _face(f.get_basename())
			await process_frame
			_check(e.get_node_or_null("Panel/FrameArt") == null and e.get_theme_stylebox("panel") is StyleBoxFlat,
				"an Enchantment keeps the drawn frame until its own lands")
			e.queue_free()
			break

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
