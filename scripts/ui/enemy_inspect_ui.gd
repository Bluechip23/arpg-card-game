class_name EnemyInspectUI
extends PanelContainer

## Enemy inspection panel, opened by clicking an enemy's square in the unit
## tracker. Shows a live 3D portrait of the monster, its name, current health
## and armor, its attack with every active amplification/reduction spelled
## out, resistance changes, and all buffs/debuffs currently on it.
## Refreshes while open; closes itself if the enemy dies or despawns.
##
## The same box shows an ally or summon clicked in the Allies & Summons tab
## (show_ally: its portrait, health, armor and every effect on it with what
## the effect does), and its ⤢ button enlarges everything — text, portrait,
## the box — for easier reading (designer, 2026-10-31).

const REFRESH_INTERVAL := 0.3
## Designer, 2026-11-07: the box was too small — it now opens at the size
## the old enlarge gave (1.6), and enlarging takes it 50% further.
const ZOOM_NORMAL := 1.6
const ZOOM_LARGE := ZOOM_NORMAL * 1.5

## How big the box draws: ZOOM_NORMAL, or ZOOM_LARGE once enlarged. It stays
## enlarged for the next enemy or ally until shrunk again.
var zoom: float = ZOOM_NORMAL
var _ally = null            # a hero or Summon shown instead of an enemy
var _zoom_btn: Button = null

var _enemy: Enemy = null
var _viewport: SubViewport = null
var _portrait_holder: Control = null
var _fig: Node3D = null
var _name_label: Label = null
var _rows: VBoxContainer = null
var _timer: Timer = null
var _scroll: ScrollContainer = null
var _body: VBoxContainer = null
## The box keeps this far from the screen's edges, and its top below the
## top-right menu row, so the close button is never under it.
const SCREEN_MARGIN := 8.0
const TOP_CLEAR := 72.0
const AuraOverlayScript = preload("res://scripts/battle/aura_overlay.gd")
var _aura = null                # AuraOverlay: the enemy's effect areas, laid on the floor
var _about: String = ""         # what a totem does (its compendium text)

## The move list (designer, 2026-11-08): each move is a row of its own that
## explains itself on hover — what it does, the cards it puts in your hand
## and the debuffs it lays (EnemyMoveInfo). The rows are built once per
## enemy (and zoom), not on every refresh, so a hover is never torn down
## under the mouse; the stat rows above and below them still refresh.
const EnemyMoveInfo = preload("res://scripts/battle/enemy_move_info.gd")
const KeywordBoxes = preload("res://scripts/ui/keyword_boxes.gd")
const CardUIScene = preload("res://scenes/cards/card_ui.tscn")
var _rows_after: VBoxContainer = null   # resistances + effects, below the moves
var _moves_box: VBoxContainer = null    # one hoverable row per move
var _moves_sig: String = ""             # what the move rows were built for
var _into: VBoxContainer = null         # where _add_row / _add_sub_row put a row
var _move_tip: PanelContainer = null    # the hovered move's explanation
var _tip_row: Control = null            # the row the tip is showing for
const TIP_GAP := 8.0
const TIP_WIDTH := 230.0                # at zoom 1 (scaled like the box)
const TIP_MIN_WIDTH := 300.0            # narrower than this it sits over the box instead
const ROW_HOVER := Color(0.32, 0.27, 0.12, 0.85)

func _ready() -> void:
	custom_minimum_size = Vector2(_px(280), 0)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 110   # over the hand's cards (they rise to 100 when hovered)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.96)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = EmeraldTheme.GOLD_DIM
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)
	EmeraldTheme.apply_in_game(self)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# Header: name + close button
	var header = HBoxContainer.new()
	vbox.add_child(header)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", _px(18))
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_name_label)
	_zoom_btn = Button.new()
	_zoom_btn.name = "ZoomButton"
	_zoom_btn.text = "⤢"
	_zoom_btn.tooltip_text = "Enlarge"
	_zoom_btn.custom_minimum_size = Vector2(28, 28)
	_zoom_btn.pressed.connect(toggle_zoom)
	header.add_child(_zoom_btn)
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(hide_panel)
	header.add_child(close_btn)

	# Below the header everything scrolls once the box is taller than the
	# screen (the enlarged box often is on the 1280x720 canvas).
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(body)
	_body = body

	# Live 3D portrait of the monster
	_portrait_holder = CenterContainer.new()
	_portrait_holder.custom_minimum_size = Vector2(0, _px(150))
	body.add_child(_portrait_holder)

	# Stat / effect rows (rebuilt on every refresh)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 3)
	body.add_child(_rows)
	_into = _rows
	_moves_box = VBoxContainer.new()
	_moves_box.name = "Moves"
	_moves_box.add_theme_constant_override("separation", 1)
	body.add_child(_moves_box)
	_rows_after = VBoxContainer.new()
	_rows_after.add_theme_constant_override("separation", 3)
	body.add_child(_rows_after)
	# A scroll moves the rows out from under the tip: drop it (the next
	# mouse motion over a row raises it again).
	_scroll.get_v_scroll_bar().value_changed.connect(func(_v): _hide_move_tip())

	_move_tip = PanelContainer.new()
	_move_tip.name = "MoveTip"
	_move_tip.top_level = true      # free of the box's layout; placed by hand
	_move_tip.visible = false
	_move_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_move_tip.z_index = 10          # over the box (relative to its 110)
	var tst := StyleBoxFlat.new()
	tst.bg_color = Color(0.06, 0.06, 0.1, 0.97)
	tst.set_border_width_all(2)
	tst.border_color = EmeraldTheme.GOLD_DIM
	tst.set_corner_radius_all(6)
	tst.content_margin_left = 10
	tst.content_margin_right = 10
	tst.content_margin_top = 8
	tst.content_margin_bottom = 10
	_move_tip.add_theme_stylebox_override("panel", tst)
	add_child(_move_tip)

	_timer = Timer.new()
	_timer.wait_time = REFRESH_INTERVAL
	_timer.timeout.connect(_refresh)
	_timer.timeout.connect(func(): _refit.call_deferred())   # rows come and go: the scroll area follows
	add_child(_timer)

## A size scaled by the box's zoom.
func _px(n: float) -> int:
	return int(round(n * zoom))

func show_enemy(enemy: Enemy) -> void:
	if _enemy == enemy and visible:
		hide_panel()  # clicking the same enemy again toggles the panel closed
		return
	_ally = null
	_enemy = enemy
	_about = Enemy.description_for(enemy.enemy_type).split("\n(Level-band")[0] if enemy.is_totem() else ""
	_show_aura(enemy)
	_build_portrait()
	_refresh()
	visible = true
	move_to_front()   # over the hand of cards, which shares the UI layer
	_timer.start()
	_refit.call_deferred()

## Show an ally (a hero or a summon) — clicking the same one again closes.
func show_ally(u) -> void:
	if _ally == u and visible:
		hide_panel()
		return
	_enemy = null
	_ally = u
	_show_aura(null)
	_build_portrait()
	_refresh()
	visible = true
	move_to_front()   # over the hand of cards, which shares the UI layer
	_timer.start()
	_refit.call_deferred()

func hide_panel() -> void:
	visible = false
	_hide_move_tip()
	_enemy = null
	_ally = null
	_timer.stop()
	_clear_portrait()
	_show_aura(null)

## Lay the enemy's effect areas on the floor beside it (null clears them).
func _show_aura(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.aura_zones().is_empty():
		if _aura and is_instance_valid(_aura):
			_aura.clear()
		return
	var world := enemy.get_parent()
	if world == null:
		return
	if _aura == null or not is_instance_valid(_aura) or _aura.get_parent() != world:
		if _aura and is_instance_valid(_aura):
			_aura.queue_free()
		_aura = AuraOverlayScript.new()
		_aura.name = "InspectAura"
		world.add_child(_aura)
	_aura.show_for(enemy)

## Enlarge / shrink everything in the box.
func toggle_zoom() -> void:
	zoom = ZOOM_NORMAL if is_enlarged() else ZOOM_LARGE
	_zoom_btn.text = "⤡" if is_enlarged() else "⤢"
	_zoom_btn.tooltip_text = "Shrink" if is_enlarged() else "Enlarge"
	custom_minimum_size = Vector2(_px(280), 0)
	_name_label.add_theme_font_size_override("font_size", _px(18))
	_portrait_holder.custom_minimum_size = Vector2(0, _px(150))
	size = Vector2.ZERO   # shrink-wrap again when going back down
	_build_portrait()
	_moves_sig = ""   # rebuild the move rows at the new size
	_refresh()
	_refit.call_deferred()

func is_enlarged() -> bool:
	return zoom > ZOOM_NORMAL + 0.01

## Shrink-wrap to what the box now holds (the old rows are freed a frame
## late), then keep it on screen.
func _refit() -> void:
	if not is_inside_tree():
		return
	# The scroll area takes what the body needs, up to what the screen has
	# room for under the header.
	var vp := get_viewport_rect().size
	var room: float = vp.y - TOP_CLEAR - SCREEN_MARGIN - (size.y - _scroll.size.y if _scroll.size.y > 0.0 else _px(60))
	var want: float = _body.get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = clampf(want, 0.0, maxf(120.0, room))
	reset_size()
	_keep_on_screen()

## The bigger box must not run off the bottom (or top) of the screen.
func _keep_on_screen() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport_rect().size
	var r := get_global_rect()
	var y := clampf(r.position.y, TOP_CLEAR, maxf(TOP_CLEAR, vp.y - r.size.y - SCREEN_MARGIN))
	if not is_equal_approx(y, r.position.y):
		global_position.y = y

# ============================================
# PORTRAIT (own-world SubViewport with a SpriteEnemyFigure)
# ============================================

func _clear_portrait() -> void:
	for child in _portrait_holder.get_children():
		_portrait_holder.remove_child(child)
		child.queue_free()
	_viewport = null
	_fig = null

func _build_portrait() -> void:
	_clear_portrait()
	if _ally != null:
		if not is_instance_valid(_ally):
			return
		var d: Dictionary = UnitTrackerUI.ally_info(_ally)
		var ptex: Texture2D = d.get("portrait")
		if ptex:
			var prect := TextureRect.new()
			prect.texture = ptex
			prect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			prect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			prect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			prect.custom_minimum_size = Vector2(_px(180), _px(150))
			prect.flip_h = bool(d.get("flip", false))
			_portrait_holder.add_child(prect)
		return
	if _enemy == null or not is_instance_valid(_enemy):
		return

	if _enemy.figure_kind == "":
		# Generic tiers have no 3D model — show their coloured square instead.
		var block = PanelContainer.new()
		block.custom_minimum_size = Vector2(_px(120), _px(120))
		var st = StyleBoxFlat.new()
		st.bg_color = Color(0.3, 0.3, 0.38)
		st.corner_radius_top_left = 8
		st.corner_radius_top_right = 8
		st.corner_radius_bottom_left = 8
		st.corner_radius_bottom_right = 8
		block.add_theme_stylebox_override("panel", st)
		var lbl = Label.new()
		lbl.text = _enemy.enemy_name.left(3).to_upper()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", _px(30))
		block.add_child(lbl)
		_portrait_holder.add_child(block)
		return

	# The enemy's own field sprite, blown up crisp — the same picture the
	# tracker square shows and the battlefield draws.
	var tex: Texture2D = _enemy.get_portrait_texture() if _enemy.has_method("get_portrait_texture") else null
	if tex != null:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.custom_minimum_size = Vector2(_px(180), _px(150))
		rect.modulate = _enemy.get_portrait_tint()
		rect.flip_h = _enemy.is_portrait_flipped()
		_portrait_holder.add_child(rect)
		return

	var container = SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(_px(180), _px(150))
	_portrait_holder.add_child(container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(_px(180), _px(150))
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_viewport)

	var key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45, -30, 0)  # global upper-left light (style guide §3)
	key.light_energy = 1.2
	_viewport.add_child(key)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-12, -40, 0)
	fill.light_energy = 0.5
	_viewport.add_child(fill)

	if not SpriteEnemyFigure.supports(_enemy.figure_kind):
		return  # box enemies (no figure_kind) have no portrait
	# The same Craftpix sprite rig the battlefield uses, idling toward
	# the viewer under a flat orthographic camera.
	var sf := SpriteEnemyFigure.new()
	_viewport.add_child(sf)
	sf.setup(_enemy.figure_kind)
	_fig = sf
	var cam = Camera3D.new()
	_viewport.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	# Frame the drawn body: the sprite's feet sit at its lift height.
	var ext: Vector2 = sf.portrait_extent()
	var h: float = maxf(ext.y, 0.6)
	var mid: float = CameraView.SPRITE_LIFT + h * 0.5
	cam.size = maxf(h * 1.25, ext.x * 1.25 * 150.0 / 180.0)
	cam.look_at_from_position(Vector3(0, mid, 6), Vector3(0, mid, 0), Vector3.UP)

# ============================================
# STATS / EFFECTS REFRESH
# ============================================

func _refresh() -> void:
	if _ally != null:
		_refresh_ally()
		return
	if _enemy == null or not is_instance_valid(_enemy) or _enemy.is_dead:
		hide_panel()
		return

	_name_label.text = _enemy.enemy_name
	if _aura and is_instance_valid(_aura):
		_aura.refresh()

	_clear_rows()
	_into = _rows

	# A totem says what it does (designer, 2026-11-07), and any effect area
	# is named with its reach — the squares are lit on the floor.
	if _about != "":
		_add_row("What it does", "", Color(0.9, 0.85, 0.6))
		for para in _about.split("\n"):
			if para.strip_edges() != "":
				_add_sub_row(para.strip_edges())
	for z in _enemy.aura_zones():
		_add_row("Reach", "%s: %d squares (lit on the floor)" % [z["label"], int(z["reach"])], z["color"])

	# Health + armor
	_add_row("Health", "%d / %d" % [_enemy.current_health, _enemy.max_health], Color(0.4, 1.0, 0.4))
	if _enemy.current_armor > 0 or _enemy.max_armor > 0:
		var armor_txt := "%d / %d" % [_enemy.current_armor, _enemy.max_armor]
		if _enemy.is_exposed:
			armor_txt += "  (EXPOSED)"
		elif _enemy.exposed_cooldown_tempo > 0:
			# The flag is gone but the 10-tempo wait isn't: say so, or a break
			# that doesn't Expose looks like a bug.
			armor_txt += "  (Exposed again in %d tempo)" % _enemy.exposed_cooldown_tempo
		_add_row("Armor", armor_txt, Color(0.65, 0.65, 0.85))

	# Attack: base plus every live amplification / reduction
	var base: int = _enemy.attack_damage
	var mods: Array[String] = []
	var total: int = base
	if _enemy.strength > 0:
		mods.append("+%d enraged strength" % _enemy.strength)
		total += _enemy.strength
	if _enemy.pack_attack_bonus > 0:
		mods.append("+%d pack fury" % _enemy.pack_attack_bonus)
		total += _enemy.pack_attack_bonus
	if _enemy.enemy_type == Enemy.EnemyType.WOLF and _enemy._wolf_aura_active():
		mods.append("+2 pack aura")
		total += 2
	if _enemy.enemy_type == Enemy.EnemyType.BUGBEAR and _enemy.hits_taken == 0:
		mods.append("+5 first strike (ready)")
		total += 5
	if _enemy.attack_reduction > 0:
		mods.append("-%d worn down" % _enemy.attack_reduction)
		total -= _enemy.attack_reduction
	total = max(0, total)
	var atk_color := Color(0.9, 0.9, 0.9)
	if total > base:
		atk_color = Color(1.0, 0.5, 0.4)   # amplified — warn the player
	elif total < base:
		atk_color = Color(0.5, 0.9, 1.0)   # reduced
	_add_row("Attack", "%d" % total if mods.is_empty() else "%d (base %d)" % [total, base], atk_color)
	for m in mods:
		_add_sub_row(m)

	# Actions: every move with its tempo and keywords (Async / Channel /
	# Disruptable / Trigger — Sync, Immediate, Non-interruptible are implied),
	# and what the enemy is doing right now.
	var shown: Dictionary = _enemy.get_display_action()
	if shown.is_empty():
		_add_row("Actions", "idle", Color(0.85, 0.8, 0.6))
	elif str(shown["kind"]) == "channel":
		_add_row("Actions", "Channeling %s (%d/%d)" % [shown["label"], shown["counter"], shown["cost"]], Enemy.ACTION_COLOR_CHANNEL)
	else:
		var kind_txt: String = "Async" if str(shown["kind"]) == "async" else "next"
		_add_row("Actions", "%s %d/%d (%s)" % [shown["label"], shown["counter"], shown["cost"], kind_txt], Enemy.action_kind_color(str(shown["kind"])))
	_build_moves()
	_into = _rows_after
	if _move_tip.visible:
		_place_move_tip.call_deferred()   # the box may have shifted under it

	# Resistance changes (per-type resistances aren't in the game yet; the row
	# reports the states that change how much damage the enemy takes).
	var resists: Array[String] = []
	if _enemy.is_exposed:
		resists.append("Exposed — armor broken, takes full hits")
	if _enemy.enemy_type == Enemy.EnemyType.EARTH_MAGE:
		resists.append("Stoneskin — gains %d armor whenever hit" % _enemy.armor_per_hit)
	if resists.is_empty():
		_add_row("Resistances", "none", Color(0.6, 0.6, 0.65))
	else:
		_add_row("Resistances", "", Color(0.8, 0.8, 0.85))
		for r in resists:
			_add_sub_row(r)

	# Active effects: everything on the enemy — debuffs and buffs alike —
	# with the same colour dots the tracker uses, plus stack counts.
	var effects = _enemy.get_active_effects()
	if effects.size() > 0:
		_add_row("Effects", "", Color(0.9, 0.85, 0.6))
		for eff in effects:
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			_into.add_child(row)
			var tex := StatusIcons.get_icon(eff["name"])
			if tex:
				var icon = TextureRect.new()
				icon.texture = tex
				icon.custom_minimum_size = Vector2(_px(18), _px(18))
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				row.add_child(icon)
			else:
				var dot = ColorRect.new()
				dot.color = eff["color"]
				dot.custom_minimum_size = Vector2(_px(12), _px(12))
				dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				row.add_child(dot)
			var lbl = Label.new()
			lbl.text = "%s x%d" % [eff["name"], eff["stacks"]]
			lbl.add_theme_font_size_override("font_size", _px(13))
			lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
			row.add_child(lbl)
	else:
		_add_row("Effects", "none", Color(0.6, 0.6, 0.65))

func _add_row(label_text: String, value_text: String, value_color: Color) -> void:
	var row = HBoxContainer.new()
	_into.add_child(row)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", _px(14))
	lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.62))
	lbl.custom_minimum_size = Vector2(_px(92), 0)
	row.add_child(lbl)
	if value_text != "":
		var val = Label.new()
		val.text = value_text
		val.add_theme_font_size_override("font_size", _px(14))
		val.add_theme_color_override("font_color", value_color)
		row.add_child(val)

func _add_sub_row(text: String) -> void:
	var lbl = Label.new()
	lbl.text = "    • " + text
	lbl.add_theme_font_size_override("font_size", _px(12))
	lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.82))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(_px(250), 0)
	_into.add_child(lbl)

## An ally or summon: health, armor, and each effect on it with what it does.
func _refresh_ally() -> void:
	if not is_instance_valid(_ally) or _ally.get("is_dead") == true:
		hide_panel()
		return
	var d: Dictionary = UnitTrackerUI.ally_info(_ally)
	_name_label.text = str(d["name"])
	_clear_rows()
	_clear_moves()
	_into = _rows
	_add_row("Health", "%d / %d" % [d["hp"], d["max_hp"]], Color(0.4, 1.0, 0.4))
	var arm: Array = d["armor"]
	if int(arm[1]) > 0:
		_add_row("Armor", "%d / %d" % [arm[0], arm[1]], Color(0.65, 0.65, 0.85))
	elif int(arm[0]) > 0:
		_add_row("Armor", "%d" % arm[0], Color(0.65, 0.65, 0.85))
	if _ally is Summon:
		_add_row("Kind", "Summon", Color(0.85, 0.8, 0.6))
	else:
		_add_row("Kind", "Ally", Color(0.85, 0.8, 0.6))
	var effects: Array = d["effects"]
	if effects.is_empty():
		_add_row("Effects", "none", Color(0.6, 0.6, 0.65))
		return
	_add_row("Effects", "", Color(0.9, 0.85, 0.6))
	for eff in effects:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_into.add_child(row)
		var tex := StatusIcons.get_icon(str(eff.get("name", "")))
		if tex:
			var icon = TextureRect.new()
			icon.texture = tex
			icon.custom_minimum_size = Vector2(_px(18), _px(18))
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(icon)
		else:
			var dot = ColorRect.new()
			dot.color = eff.get("color", Color.WHITE)
			dot.custom_minimum_size = Vector2(_px(12), _px(12))
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(dot)
		var lbl = Label.new()
		var st := int(eff.get("stacks", 0))
		lbl.text = str(eff.get("name", "")) + (" x%d" % st if st > 0 else "")
		lbl.add_theme_font_size_override("font_size", _px(13))
		lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		row.add_child(lbl)
		var desc := str(eff.get("desc", ""))
		if desc != "":
			_add_sub_row(desc)

# ============================================
# MOVE ROWS + THEIR HOVER EXPLANATION (designer, 2026-11-08)
# ============================================

## Empties the refreshed stat rows (above and below the moves).
func _clear_rows() -> void:
	for box in [_rows, _rows_after]:
		for child in box.get_children():
			box.remove_child(child)   # out of the layout now, not at frame end
			child.queue_free()

func _clear_moves() -> void:
	_hide_move_tip()
	for child in _moves_box.get_children():
		_moves_box.remove_child(child)
		child.queue_free()
	_moves_sig = ""

## One row per move of the shown enemy, each explaining itself on hover.
## Rebuilt only when the enemy, its move list or the zoom changes.
func _build_moves() -> void:
	var lines: Array[String] = _enemy.get_action_lines()
	var sig := "%d|%.2f|%s" % [_enemy.get_instance_id(), zoom, "\n".join(lines)]
	if sig == _moves_sig:
		return
	_clear_moves()
	_moves_sig = sig
	for i in _enemy.actions.size():
		_moves_box.add_child(_make_move_row(lines[i], _enemy.actions[i]))

func _make_move_row(text: String, action: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	row.name = "Move_" + str(action.get("name", ""))
	# PASS: the hover is ours, but the wheel still scrolls the box and a
	# click goes on through to whatever would have had it.
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.mouse_default_cursor_shape = Control.CURSOR_HELP
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, 0)
	st.set_corner_radius_all(4)
	st.content_margin_left = 2
	st.content_margin_right = 2
	st.content_margin_top = 1
	st.content_margin_bottom = 1
	row.add_theme_stylebox_override("panel", st)
	row.set_meta("action", action)
	var lbl := Label.new()
	lbl.text = "    • " + text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", _px(12))
	lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.82))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(_px(250), 0)
	row.add_child(lbl)
	row.mouse_entered.connect(_on_move_hovered.bind(row))
	row.mouse_exited.connect(_on_move_unhovered.bind(row))
	return row

func _on_move_hovered(row: Control) -> void:
	if not is_instance_valid(row) or _enemy == null or not is_instance_valid(_enemy):
		return
	if _tip_row != null and is_instance_valid(_tip_row) and _tip_row != row:
		_set_row_lit(_tip_row, false)
	_tip_row = row
	_set_row_lit(row, true)
	_fill_move_tip(EnemyMoveInfo.explain_for(_enemy, row.get_meta("action")))
	_move_tip.visible = true
	_place_move_tip()
	# Card faces and wrapped labels settle a frame late: place it again then.
	_place_move_tip.call_deferred()

func _on_move_unhovered(row: Control) -> void:
	if row == _tip_row:
		_hide_move_tip()

func _hide_move_tip() -> void:
	if _tip_row != null and is_instance_valid(_tip_row):
		_set_row_lit(_tip_row, false)
	_tip_row = null
	if _move_tip:
		_move_tip.visible = false

func _set_row_lit(row: Control, lit: bool) -> void:
	var st := row.get_theme_stylebox("panel") as StyleBoxFlat
	if st:
		st.bg_color = ROW_HOVER if lit else Color(0, 0, 0, 0)

## The tip's width and font scale: as wide as the box's zoom asks, but no
## wider than the room beside the box; the text shrinks with it.
func _tip_width() -> float:
	var vp := get_viewport_rect().size
	var r := get_global_rect()
	var want := TIP_WIDTH * zoom
	var room := maxf(vp.x - r.end.x, r.position.x) - TIP_GAP - SCREEN_MARGIN
	if room >= TIP_MIN_WIDTH:
		return minf(want, room)
	return minf(want, vp.x - 2.0 * SCREEN_MARGIN)

## Rebuilds the tip for one move: name and tempo, what it does, the wind-up
## words that matter (never Async/Sync), the cards it puts in your hand,
## and a keyword box for each debuff it lays.
func _fill_move_tip(info: Dictionary) -> void:
	for child in _move_tip.get_children():
		_move_tip.remove_child(child)
		child.queue_free()
	var w := _tip_width()
	var f := minf(zoom, w / TIP_WIDTH)   # the text's scale
	var inner := w - 20.0
	_move_tip.custom_minimum_size = Vector2(w, 0)
	_move_tip.size = Vector2.ZERO
	var vb := VBoxContainer.new()
	vb.name = "Body"
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", int(round(5 * f)))
	_move_tip.add_child(vb)

	var title := Label.new()
	title.name = "Title"
	title.text = "%s  ·  %d tempo" % [info["title"], info["tempo"]]
	title.add_theme_font_size_override("font_size", int(round(14 * f)))
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(inner, 0)
	vb.add_child(title)

	var text := str(info["text"])
	if text != "":
		vb.add_child(_tip_label("What it does", text, inner, f, Color(0.92, 0.92, 0.95)))
	for wl in info["windup"]:
		vb.add_child(_tip_label(str(wl[0]), "%s: %s" % [wl[0], wl[1]], inner, f, Color(0.75, 0.85, 1.0)))

	var cards: Array = info["cards"]
	if not cards.is_empty():
		var cap := Label.new()
		cap.text = "Puts in your hand:"
		cap.add_theme_font_size_override("font_size", int(round(12 * f)))
		cap.add_theme_color_override("font_color", Color(0.75, 0.72, 0.62))
		vb.add_child(cap)
		var hb := HBoxContainer.new()
		hb.name = "Cards"
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_child(hb)
		for cid in cards:
			_card_face(hb, str(cid), clampf(0.65 * f, 0.7, 1.1))

	var defs := Card.get_keyword_definitions()
	var kws: Array = info["keywords"]
	if not kws.is_empty():
		var kb := VBoxContainer.new()
		kb.name = "Keywords"
		kb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		kb.add_theme_constant_override("separation", 4)
		vb.add_child(kb)
		for k in kws:
			if defs.has(k):
				kb.add_child(KeywordBoxes.make_box(str(k), str(defs[k]), inner))

func _tip_label(node_name: String, text: String, width: float, f: float, color: Color) -> Label:
	var lbl := Label.new()
	lbl.name = node_name.replace(" ", "")
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(width, 0)
	lbl.add_theme_font_size_override("font_size", int(round(12 * f)))
	lbl.add_theme_color_override("font_color", color)
	return lbl

## A card the move hands you, drawn as its real face (scaled down), added
## to `parent` (in the tree first: the face lays itself out on setup).
func _card_face(parent: Control, card_id: String, sc: float) -> Control:
	var card := Card.create_by_id(card_id)
	if card == null:
		return null
	var holder := Control.new()
	holder.name = "Card_" + card_id
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2(CardUI.CARD_W * sc, CardUI.CARD_H * sc)
	holder.set_meta("card_name", card.card_name)
	parent.add_child(holder)
	var face: CardUI = CardUIScene.instantiate()
	face.scale = Vector2(sc, sc)
	holder.add_child(face)
	face.setup(card, 0)
	face.pivot_offset = Vector2.ZERO
	face.position = Vector2.ZERO
	for n in face.find_children("*", "Control", true, false):
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kb = face.get_node_or_null("Panel/KeybindBadge")
	if kb:
		kb.visible = false
	return holder

## Beside the box (right if there is room, else left, else over it), level
## with the hovered row, and always wholly on screen.
func _place_move_tip() -> void:
	if not _move_tip.visible or _tip_row == null or not is_instance_valid(_tip_row) or not is_inside_tree():
		return
	var vp := get_viewport_rect().size
	var box := get_global_rect()
	_move_tip.reset_size()
	_move_tip.scale = Vector2.ONE
	var sz := _move_tip.get_combined_minimum_size()
	# Taller than the screen (a big card and many keywords at the largest
	# zoom): shrink it to fit rather than run off the edge.
	var fit := minf(1.0, (vp.y - 2.0 * SCREEN_MARGIN) / maxf(1.0, sz.y))
	_move_tip.scale = Vector2(fit, fit)
	var w := sz.x * fit
	var h := sz.y * fit
	var x: float
	if vp.x - box.end.x - TIP_GAP - SCREEN_MARGIN >= w:
		x = box.end.x + TIP_GAP
	elif box.position.x - TIP_GAP - SCREEN_MARGIN >= w:
		x = box.position.x - TIP_GAP - w
	else:
		x = vp.x - SCREEN_MARGIN - w
	var y := _tip_row.get_global_rect().position.y - 6.0
	x = clampf(x, SCREEN_MARGIN, maxf(SCREEN_MARGIN, vp.x - SCREEN_MARGIN - w))
	y = clampf(y, SCREEN_MARGIN, maxf(SCREEN_MARGIN, vp.y - SCREEN_MARGIN - h))
	_move_tip.global_position = Vector2(x, y)
