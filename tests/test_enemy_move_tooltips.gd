extends SceneTree

## Enemy inspect box, move tooltips (designer, 2026-11-08): hovering a move
## in the box's move list explains it — what it does (with the enemy's real,
## band-scaled numbers), the cards it puts in your hand (drawn as cards),
## a keyword box for each debuff it lays, and the wind-up keywords that
## matter (Channel / Disruptable) — never Async or Sync. Every move of every
## enemy has an explanation. The tip stays on screen at both box sizes,
## ignores the mouse, closes on mouse-out, and the rows survive refreshes.
## Run: godot --headless --path . --script tests/test_enemy_move_tooltips.gd

const EnemyMoveInfo = preload("res://scripts/battle/enemy_move_info.gd")

var failures := 0
var _main: Node = null
var _box = null

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	_t_every_move_explained()
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate()
	_main.set("starting_character", CharacterData.create_brad())
	_main.set("current_interior_id", "dojo")
	get_root().add_child(_main)
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	print("=== Enemy move tooltips ===")
	await _frames(60)
	if _main.olorin and _main.olorin.is_busy():
		_main.olorin._close()
	_box = _main.enemy_inspect_ui
	await _t_card_move()
	await _t_debuff_move()
	await _t_channel_moves()
	await _t_async_move_has_no_async()
	await _t_rows_survive_refresh_and_mouse()
	await _t_on_screen_both_sizes()
	await _t_totem_keeps_about()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

# ------------------------------------------------------------------ helpers

func _spawn(t: int, dx: int = 3) -> Enemy:
	var gm = _main.grid_manager
	return _main.enemy_spawner.spawn_enemy(t, gm.grid_to_world(gm.world_to_grid(_main.player.position) + Vector2i(dx, 0)))

func _open(e: Enemy) -> void:
	if _box.visible:
		_box.hide_panel()
	_box.show_enemy(e)
	await _frames(3)

func _row(name: String) -> Control:
	return _box._moves_box.get_node_or_null("Move_" + name)

func _hover(name: String) -> Control:
	var r := _row(name)
	if r:
		_box._scroll.ensure_control_visible(r)   # as a player scrolls to it
		await _frames(2)
		r.mouse_entered.emit()
	await _frames(3)
	return r

## Every Label's text in the tip, joined.
func _tip_text() -> String:
	var parts: Array[String] = []
	for n in _box._move_tip.find_children("*", "Label", true, false):
		parts.append((n as Label).text)
	return "\n".join(parts)

func _tip_keywords() -> Array:
	var out: Array = []
	var kb = _box._move_tip.find_child("Keywords", true, false)
	if kb:
		for c in kb.get_children():
			out.append(str(c.name).trim_prefix("Keyword_").to_lower())
	return out

func _tip_cards() -> Array:
	var out: Array = []
	var hb = _box._move_tip.find_child("Cards", true, false)
	if hb:
		for c in hb.get_children():
			out.append(str(c.name).trim_prefix("Card_"))
	return out

func _no_sync_words(text: String) -> bool:
	var re := RegEx.new()
	re.compile("(?i)\\b(a?sync)\\b")
	return re.search(text) == null

func _tip_on_screen() -> bool:
	var vp: Vector2 = _box.get_viewport_rect().size
	var t: PanelContainer = _box._move_tip
	var r := Rect2(t.global_position, t.size * t.scale)
	return r.position.x >= 0.0 and r.position.y >= 0.0 and r.end.x <= vp.x + 0.5 and r.end.y <= vp.y + 0.5

# ------------------------------------------------------------------ tests

func _t_every_move_explained() -> void:
	print("-- every enemy's every move has an explanation --")
	var defs := Card.get_keyword_definitions()
	var missing: Array[String] = []
	var bad_kw: Array[String] = []
	var bad_card: Array[String] = []
	var bad_text: Array[String] = []
	var n := 0
	for t in Enemy.EnemyType.values():
		for a in Enemy.actions_for_type(t):
			n += 1
			var who := "%s/%s" % [Enemy.EnemyType.keys()[t], a["name"]]
			var info := EnemyMoveInfo.explain(t, a)
			var txt := str(info["text"])
			if txt.strip_edges() == "":
				missing.append(who)
			if "{" in txt or not _no_sync_words(txt):
				bad_text.append(who)
			for wl in info["windup"]:
				if not _no_sync_words(str(wl[0]) + str(wl[1])):
					bad_text.append(who)
			for k in info["keywords"]:
				if not defs.has(k):
					bad_kw.append("%s:%s" % [who, k])
			for cid in info["cards"]:
				if Card.create_by_id(cid) == null:
					bad_card.append("%s:%s" % [who, cid])
	_check(missing.is_empty(), "all %d listed moves explain themselves%s" % [n, "" if missing.is_empty() else " — missing " + ", ".join(missing)])
	_check(bad_text.is_empty(), "no unresolved number token and no Async/Sync in any explanation%s" % ("" if bad_text.is_empty() else ": " + ", ".join(bad_text)))
	_check(bad_kw.is_empty(), "every debuff named is a game keyword%s" % ("" if bad_kw.is_empty() else ": " + ", ".join(bad_kw)))
	_check(bad_card.is_empty(), "every card named exists%s" % ("" if bad_card.is_empty() else ": " + ", ".join(bad_card)))
	# Numbers follow the level band the way the moves deal them.
	var smash := EnemyMoveInfo.explain(Enemy.EnemyType.ARMORED_TROLL, {"name": "smash", "tempo_cost": 5})
	var pps: float = Enemy.passive_power_scale(12)["dmg"]
	_check(("%d damage" % maxi(1, roundi(14 * pps))) in str(smash["text"]), "Smash quotes its band-scaled damage (%s)" % smash["text"])

func _t_card_move() -> void:
	print("-- a move that puts a card in your hand: the Armored Troll's Smash --")
	var troll := _spawn(Enemy.EnemyType.ARMORED_TROLL)
	await _open(troll)
	var r := await _hover("smash")
	_check(r != null and r.mouse_filter == Control.MOUSE_FILTER_PASS, "the Smash row is hoverable (and passes clicks/scroll on)")
	_check(_box._move_tip.visible, "hovering it opens the tip")
	var txt := _tip_text()
	_check("Smash" in txt and "5 tempo" in txt, "the tip names the move and its tempo")
	_check(("%d damage" % maxi(1, roundi(14 * troll._pps_dmg))) in txt, "it gives the real damage")
	_check(_tip_cards() == ["lightly_dazed"], "and shows the Lightly Dazed card it hands you (%s)" % [_tip_cards()])
	var face = _box._move_tip.find_child("Card_lightly_dazed", true, false)
	_check(face != null and face.find_children("*", "CardUI", true, false).size() == 1, "drawn as a real card face")
	var hl: StyleBoxFlat = r.get_theme_stylebox("panel")
	_check(hl.bg_color.a > 0.0, "the hovered row lights up")
	r.mouse_exited.emit()
	await _frames(2)
	_check(not _box._move_tip.visible and hl.bg_color.a == 0.0, "mouse-out closes the tip and unlights the row")
	var sc := _spawn(Enemy.EnemyType.SPIRIT_COLLECTOR, -3)
	await _open(sc)
	await _hover("collect_soul")
	_check(_tip_cards() == ["release_soul"], "Collect Soul shows the Release Soul card")
	_check("drain" in _tip_keywords(), "and explains Drain")
	await _shot("collect_soul")
	troll.queue_free()
	sc.queue_free()

func _t_debuff_move() -> void:
	print("-- a move that lays debuffs: Cerberus's Venom Tail, the Pipe Crawler's Claw --")
	var pc := _spawn(Enemy.EnemyType.PIPE_CRAWLER)
	await _open(pc)
	await _hover("pipe_attack")
	_check("disarm" in _tip_keywords(), "Claw explains Disarm in a keyword box")
	var defs := Card.get_keyword_definitions()
	_check(defs["disarm"] in _tip_text(), "with the game's own Disarm wording")
	pc.queue_free()
	var cer := _spawn(Enemy.EnemyType.CERBERUS)
	await _open(cer)
	await _hover("venom_tail")
	var kws := _tip_keywords()
	_check("stun" in kws and "vulnerable" in kws and "cuffed" in kws, "Venom Tail explains Stun, Vulnerable and Cuffed (%s)" % [kws])
	await _shot("venom_tail")
	cer.queue_free()

func _t_channel_moves() -> void:
	print("-- wind-up keywords in plain words: the Ifrit's breath, the Shaman's wall --")
	var ifrit := _spawn(Enemy.EnemyType.IFRIT)
	await _open(ifrit)
	await _hover("fire_breath")
	var txt := _tip_text()
	_check("5x5" in txt and ("%d fire damage + 5 Burn" % maxi(1, roundi(20 * ifrit._pps_dmg))) in txt, "Fire Breath: the 5x5, its real damage and Burn")
	_check("burn" in _tip_keywords(), "and a Burn box")
	await _shot("fire_breath")
	await _hover("breathe_on")
	txt = _tip_text()
	_check("can't move or act while channelling" in txt, "the continued breath says he can't move or act while channelling")
	_check(_no_sync_words(txt), "no Async/Sync in it")
	ifrit.queue_free()
	var sh := _spawn(Enemy.EnemyType.FIRE_GOBLIN_SHAMAN)
	await _open(sh)
	await _hover("fire_wall")
	txt = _tip_text()
	_check("can't move or act while channelling" in txt and "Taking 8 damage" in txt and "restarts it" in txt,
		"Fire Wall: Channel and Disruptable in plain words")
	await _shot("fire_wall")
	sh.queue_free()

func _t_async_move_has_no_async() -> void:
	print("-- an Async move's tip says nothing of Async --")
	var croc := _spawn(Enemy.EnemyType.SEWER_CROC)
	await _open(croc)
	var row := _row("venom_spray")
	var row_lbl: Label = row.get_child(0) if row else null
	_check(row_lbl != null and "Async" in row_lbl.text, "the row itself still lists its keywords (%s)" % (row_lbl.text if row_lbl else "?"))
	await _hover("venom_spray")
	_check(_box._move_tip.visible and _no_sync_words(_tip_text()), "but the tip leaves Async out")
	_check("poison" in _tip_keywords(), "and explains Poison")
	croc.queue_free()

func _t_rows_survive_refresh_and_mouse() -> void:
	print("-- the tip doesn't flicker or block clicks --")
	var wolf := _spawn(Enemy.EnemyType.WOLF)
	await _open(wolf)
	var r := await _hover("wolf_bite")
	await create_timer(0.8).timeout   # a couple of the box's refreshes
	_check(is_instance_valid(r) and _row("wolf_bite") == r, "the move rows are not rebuilt by the refresh")
	_check(_box._move_tip.visible, "so the tip stays up while hovered")
	var blocking := []
	if _box._move_tip.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		blocking.append(_box._move_tip.name)
	for n in _box._move_tip.find_children("*", "Control", true, false):
		if (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			blocking.append(n.name)
	_check(blocking.is_empty(), "nothing in the tip takes the mouse%s" % ("" if blocking.is_empty() else ": " + str(blocking)))
	# A real mouse: moving off the rows closes it.
	var vp := get_root()
	var off := InputEventMouseMotion.new()
	off.position = Vector2(4, 4)
	off.global_position = off.position
	vp.push_input(off)
	await _frames(3)
	var on := InputEventMouseMotion.new()
	on.position = r.get_global_rect().get_center()
	on.global_position = on.position
	vp.push_input(on)
	await _frames(3)
	var opened_by_mouse: bool = _box._move_tip.visible and _box._tip_row == r
	vp.push_input(off)
	await _frames(3)
	_check(opened_by_mouse, "a real mouse over the row opens it")
	_check(not _box._move_tip.visible, "and moving the mouse away closes it")
	_box.hide_panel()
	_check(not _box._move_tip.visible, "closing the box closes the tip")
	wolf.queue_free()

func _t_on_screen_both_sizes() -> void:
	print("-- on screen at both sizes --")
	var cer := _spawn(Enemy.EnemyType.CERBERUS)
	await _open(cer)
	for zoomed in [false, true]:
		if zoomed != _box.is_enlarged():
			_box.toggle_zoom()
			await _frames(4)
		for mv in ["cerberus_bite", "venom_tail", "move"]:
			await _hover(mv)
			await _frames(2)
			_check(_box._move_tip.visible and _tip_on_screen(), "%s tip on screen (%s box)" % [mv, "enlarged" if zoomed else "normal"])
		if zoomed:
			await _shot("venom_tail_enlarged", "venom_tail")
	if _box.is_enlarged():
		_box.toggle_zoom()
		await _frames(3)
	var sc := _spawn(Enemy.EnemyType.SPIRIT_COLLECTOR, -3)
	await _open(sc)
	_box.toggle_zoom()
	await _frames(4)
	await _hover("collect_soul")
	await _frames(2)
	_check(_tip_on_screen(), "the card tip fits on screen in the enlarged box too")
	_box.toggle_zoom()
	await _frames(3)
	_box.hide_panel()
	cer.queue_free()
	sc.queue_free()

func _t_totem_keeps_about() -> void:
	print("-- a totem keeps its 'What it does' --")
	var tot := _spawn(Enemy.EnemyType.FIRE_TOTEM)
	await _open(tot)
	var found := false
	for n in _box._rows.find_children("*", "Label", true, false):
		if (n as Label).text == "What it does":
			found = true
	_check(found and _box._moves_box.get_child_count() == 0, "What it does is shown and there are no move rows")
	_box.hide_panel()
	tot.queue_free()

## Screenshots (only under a real display): the hovered tip.
func _shot(tag: String, mv: String = "") -> void:
	if DisplayServer.get_name() == "headless":
		return
	var dir := OS.get_environment("MOVE_TIP_SHOTS")
	if dir == "":
		return
	if mv != "":
		await _hover(mv)
	await _frames(4)
	var img := get_root().get_texture().get_image()
	img.save_png("%s/%s.png" % [dir, tag])
