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
## The face as laid out (designer, 2026-11-15): each frame drawn from its bare
## cut in bands, the drop and hourglass drawn over it, the name centred, and
## no box behind the rules text (the corner picture fades instead).
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
	var bands: Control = inst.get_node_or_null("Panel/FrameBands")
	_check(bands != null and bands.get_index() == 0 and bands.get_child_count() > 1,
		"the frame is drawn behind the face, in bands from its bare cut")
	_check(inst.get_theme_stylebox("panel") is StyleBoxEmpty, "no drawn border round it")
	_check(inst.title_bar.get_theme_stylebox("panel") is StyleBoxEmpty, "its title bar is bare, the painting shows")
	_check(inst.desc_panel.get_theme_stylebox("panel") is StyleBoxEmpty, "its rules box is bare")
	# No box behind the rules text (designer, 2026-11-15): the corner picture
	# fades where a long text runs over it; a short one leaves it be.
	await process_frame
	await process_frame
	var wash_node: Panel = inst.get_node_or_null("Panel/TextWash")
	_check(wash_node == null or not wash_node.visible, "no box behind the text")
	var fade_node: Control = inst.get_node_or_null("Panel/TextFade")
	_check(fade_node == null or not fade_node.visible, "a short text leaves the corner picture at full strength")
	var long_inst := _face("composed_reaction")
	await process_frame
	await process_frame
	var lf: Control = long_inst.get_node_or_null("Panel/TextFade")
	_check(lf != null and lf.visible, "a text over the corner picture fades it")
	long_inst.queue_free()
	var icons_shown := true
	for c in inst._mana_badge.get_children() + inst._tempo_badge.get_children():
		if c is TextureRect and not c.visible:
			icons_shown = false
	_check(icons_shown, "the drop and hourglass are drawn over the bare frame")
	var drop: Rect2 = CardUI.FRAMES["instant"]["bare"]["drop"]
	_check((inst._mana_badge.position + inst._mana_badge.size * 0.5).distance_to(inst._mp(drop.get_center())) < 0.5,
		"the drop sits where the painting had it")
	_check(inst._mana_badge.size.x < drop.size.x, "smaller than the painted one")
	_check(inst.get_node_or_null("Panel/FrameLogo") != null, "the logo sits on the frame's ring spot")
	_check(inst.desc_label.get_theme_color("default_color").v < 0.3, "the rules text is ink on the parchment")
	inst.set_selected(true)
	var sel := inst.get_theme_stylebox("panel") as StyleBoxFlat
	_check(sel != null and not sel.draw_center, "chosen, a gold ring goes round the painting (not over it)")
	inst.set_selected(false)
	_check(inst.get_theme_stylebox("panel") is StyleBoxEmpty, "and comes off again")

	# Every card with an upkeep wears the Maintain frame, whatever its type.
	for id in ["armored_discipline", "forever_armor"]:
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
	_check(atk.name_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "its name is centred in the bar (it may run onto the axe)")
	atk.queue_free()

	# A spell is not an attack: Fireball (an offensive spell, stored as an
	# Attack-type card) wears the Spell frame.
	var sp := _face("fireball")
	await process_frame
	var spa: TextureRect = sp.get_node_or_null("Panel/FrameArt")
	_check(spa != null and spa.texture.resource_path.ends_with("frame_spell.png"),
		"an offensive spell wears the Spell frame, not the Attack one")
	sp.queue_free()

	# An offensive card that is not only an attack or only a spell wears the
	# Offensive frame (2026-11-11): attack-and-spell cards, and the sheet's
	# plain "Offensive" rows. One-shape cards keep their own frame.
	var pig := _face("if_pigs_could_fly")
	await process_frame
	var pa: TextureRect = pig.get_node_or_null("Panel/FrameArt")
	_check(pig.get_card().is_attack() and pig.get_card().school == Card.CardSchool.SPELL and pig.get_card().is_mixed_offensive(),
		"If Pigs Could Fly is an attack and a spell at once")
	_check(pa != null and pa.texture != null and pa.texture.resource_path.ends_with("frame_offensive.png"),
		"an attack-and-spell card wears the Offensive frame")
	_check(pig.type_label.text == "Offensive", "its type line says Offensive (%s)" % pig.type_label.text)
	_check((pig._mana_badge.position + pig._mana_badge.size * 0.5).distance_to(pig._mp(CardUI.FRAMES["offensive"]["bare"]["drop"].get_center())) < 0.5,
		"its drop sits where the painting had it")
	pig.queue_free()
	var plain := Card.new()
	plain.card_id = "test_plain_offensive"
	plain.card_type = Card.CardType.ATTACK
	plain.keywords = ["offensive", "melee"]
	_check(plain.is_offensive() and not plain.is_attack() and plain.school != Card.CardSchool.SPELL and plain.is_mixed_offensive(),
		"a plain Offensive row is offensive, and neither an attack nor a spell")
	_check(CardUI.frame_for(plain) == CardUI.FRAMES["offensive"], "…and wears the Offensive frame")
	_check(CardUI.frame_for(Card.create_by_id("slash")) == CardUI.FRAMES["attack"]
		and not Card.create_by_id("slash").is_mixed_offensive(), "an Attack keeps the Attack frame")
	_check(CardUI.frame_for(Card.create_by_id("fireball")) == CardUI.FRAMES["spell"]
		and not Card.create_by_id("fireball").is_mixed_offensive(), "an offensive spell keeps the Spell frame")
	_check(CardUI.frame_for(Card.create_by_id("armored_discipline")) == CardUI.FRAMES["maintain"],
		"an upkeep still outranks it (Armored Discipline)")
	var pk := Card.create_by_id("peshtigos_kiss")
	_check(CardUI.frame_for(pk) == CardUI.FRAMES["spell"] and pk.maintain_cost > 0 and not pk.is_attack(),
		"Peshtigo's Kiss is a spell in the Spell frame, its upkeep kept (designer, 2026-11-16)")
	var petey := Card.create_by_id("petey_the_pet_rock")
	_check(CardUI.frame_for(petey) == CardUI.FRAMES["utility"] and petey.card_type == Card.CardType.UNPLAYABLE,
		"Petey the Pet Rock wears the Utility frame, still Unplayable (designer, 2026-11-18)")
	var sa := Card.create_by_id("spirit_arrow")
	_check(CardUI.frame_for(sa) == CardUI.FRAMES["offensive"] and not sa.is_attack(),
		"Spirit Arrow is plain Offensive (designer, 2026-11-16)")

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
		_check(el != null and absf(el.position.y + el.size.y * 0.5 - e._my(CardUI.FRAMES["enchantment"]["logo_at"].y)) <= 1.0, "its logo sits in the type bar's middle")
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

	# The type words are sized to the thin type strip (designer, 2026-11-16):
	# their capitals fit inside it, centred on it.
	var sl := _face("slash")
	await process_frame
	await process_frame
	var sfs: int = sl.type_label.get_theme_font_size("font_size")
	_check(sfs * CardUI.CAP_HEIGHT_EM <= sl._type_band_h(), "the type word's capitals fit the type strip (size %d, strip %.1f)" % [sfs, sl._type_band_h()])
	_check(sl.range_label.get_theme_font_size("font_size") <= sfs, "the range word is no bigger")
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
