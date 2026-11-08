extends SceneTree

## The designer's painted card frames (2026-10-30): an Instant wears the
## painted Instant frame — the frame behind the face, the bars bare, the costs
## written on its painted drop and hourglass, the logo on its ring spot, the
## rules text in ink on the parchment. Types without a frame of their own
## keep the drawn one.
## Every card with an upkeep wears the Maintain frame instead (white text on
## its stone); a Defense card the Defensive frame; a Utility card the Utility
## frame (the logo where its art meets its rules box); an Attack the Attack
## frame; an Enchantment the Enchantment frame.
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
	_check(inst.title_bar.get_theme_stylebox("panel") is StyleBoxEmpty, "its title bar is bare, the painting shows")
	_check(inst.desc_panel.get_theme_stylebox("panel") is StyleBoxEmpty, "its rules box is bare")
	# A translucent wash sits behind the rules text only (designer,
	# 2026-11-08): the picture fades where the text is, the rest of the box
	# and the frame's foot keep their colour.
	await process_frame
	await process_frame
	var wash_node: Panel = inst.get_node_or_null("Panel/TextWash")
	var wash_sb = wash_node.get_theme_stylebox("panel") if wash_node else null
	_check(wash_node != null and wash_node.visible and wash_sb is StyleBoxFlat and wash_sb.bg_color.a > 0.0 and wash_sb.bg_color.a < 1.0,
		"a translucent wash sits behind the text")
	if wash_node:
		var host: Control = inst.get_node("Panel")
		var xf: Transform2D = host.get_global_transform().affine_inverse() * inst.desc_label.get_global_transform()
		var text_bottom: float = xf.origin.y + inst.desc_label.get_content_height()
		var box_bottom: float = (host.get_global_transform().affine_inverse() * inst.desc_panel.get_global_transform()).origin.y + inst.desc_panel.size.y
		_check(wash_node.position.y + wash_node.size.y <= text_bottom + 4.0 and wash_node.position.y + wash_node.size.y < box_bottom,
			"it ends with the text, short of the box's foot (%.0f vs box %.0f)" % [wash_node.position.y + wash_node.size.y, box_bottom])
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

	# Enchantments wear the Enchantment frame (2026-11-08): every one in the
	# data, with white text on the green stone and the logo in the type
	# bar's middle (the board's ruby painted out under it), the long type
	# word stepped down short of the logo.
	var enchantments := 0
	for f in DirAccess.get_files_at("res://data/cards"):
		if not f.ends_with(".tres"):
			continue
		var c: Card = load("res://data/cards/" + f)
		if c.card_type != Card.CardType.ENCHANTMENT:
			continue
		enchantments += 1
		_check(CardUI.frame_for(c) == CardUI.FRAMES["maintain" if c.maintain_cost > 0 else "enchantment"],
			"%s wears the Enchantment frame" % f.get_basename())
		if enchantments > 1:
			continue
		var e := _face(f.get_basename())
		await process_frame
		var ea: TextureRect = e.get_node_or_null("Panel/FrameArt")
		_check(ea != null and ea.texture.resource_path.ends_with("frame_enchantment.png"), "an Enchantment's face shows the Enchantment frame")
		_check(e.desc_label.get_theme_color("default_color").v > 0.8, "its rules text is white on the stone")
		var el: Control = e.get_node_or_null("Panel/FrameLogo")
		_check(el != null and absf(el.position.y + el.size.y * 0.5 - CardUI.FRAMES["enchantment"]["logo_at"].y) <= 1.0, "its logo sits in the type bar's middle")
		var tf: Font = e.type_label.get_theme_font("font")
		var tw: float = tf.get_string_size(e.type_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, e.type_label.get_theme_font_size("font_size")).x
		_check(e.type_label.text == "Enchantment" and 16.0 + tw <= CardUI.FRAMES["enchantment"]["logo_at"].x - CardUI.FRAMED_LOGO_RING,
			"its type word ends short of the logo")
		e.queue_free()
	_check(enchantments >= 4, "the Enchantment cards were all looked at (%d)" % enchantments)
	# An enchantment is its own family: a spell tag does not move it to the
	# Spell frame.
	var tagged: Card = load("res://data/cards/enchantment_attack.tres").duplicate()
	tagged.school = Card.CardSchool.SPELL
	_check(CardUI.frame_for(tagged) == CardUI.FRAMES["enchantment"], "an enchantment tagged spell still wears the Enchantment frame")

	# Short type words keep their size on every other frame.
	var sl := _face("slash")
	await process_frame
	_check(sl.type_label.get_theme_font_size("font_size") == 9, "a short type word keeps its size")
	sl.queue_free()

	print("=== %d failure(s) ===" % failures)
	# A rules text too long for the box beside the corner picture spreads over
	# the whole box (the washed box carries the margin, 2026-11-08).
	var long_face := _face("enchantment_defense")
	await process_frame
	await process_frame
	var lst = long_face.desc_panel.get_theme_stylebox("panel")
	_check(lst != null and lst.content_margin_right <= 4.0,
		"a long rules text takes the whole box (right margin %.1f)" % (lst.content_margin_right if lst else -1.0))
	long_face.queue_free()
	quit(1 if failures > 0 else 0)
