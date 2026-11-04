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
const ZOOM_LARGE := 1.6

## How big the box draws: 1.0, or ZOOM_LARGE once enlarged. It stays
## enlarged for the next enemy or ally until shrunk again.
var zoom: float = 1.0
var _ally = null            # a hero or Summon shown instead of an enemy
var _zoom_btn: Button = null

var _enemy: Enemy = null
var _viewport: SubViewport = null
var _portrait_holder: Control = null
var _fig: Node3D = null
var _name_label: Label = null
var _rows: VBoxContainer = null
var _timer: Timer = null

func _ready() -> void:
	custom_minimum_size = Vector2(_px(280), 0)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

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

	# Live 3D portrait of the monster
	_portrait_holder = CenterContainer.new()
	_portrait_holder.custom_minimum_size = Vector2(0, _px(150))
	vbox.add_child(_portrait_holder)

	# Stat / effect rows (rebuilt on every refresh)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 3)
	vbox.add_child(_rows)

	_timer = Timer.new()
	_timer.wait_time = REFRESH_INTERVAL
	_timer.timeout.connect(_refresh)
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
	_build_portrait()
	_refresh()
	visible = true
	_timer.start()
	_refit.call_deferred()

## Show an ally (a hero or a summon) — clicking the same one again closes.
func show_ally(u) -> void:
	if _ally == u and visible:
		hide_panel()
		return
	_enemy = null
	_ally = u
	_build_portrait()
	_refresh()
	visible = true
	_timer.start()
	_refit.call_deferred()

func hide_panel() -> void:
	visible = false
	_enemy = null
	_ally = null
	_timer.stop()
	_clear_portrait()

## Enlarge / shrink everything in the box.
func toggle_zoom() -> void:
	zoom = 1.0 if zoom > 1.0 else ZOOM_LARGE
	_zoom_btn.text = "⤡" if zoom > 1.0 else "⤢"
	_zoom_btn.tooltip_text = "Shrink" if zoom > 1.0 else "Enlarge"
	custom_minimum_size = Vector2(_px(280), 0)
	_name_label.add_theme_font_size_override("font_size", _px(18))
	_portrait_holder.custom_minimum_size = Vector2(0, _px(150))
	size = Vector2.ZERO   # shrink-wrap again when going back down
	_build_portrait()
	_refresh()
	_refit.call_deferred()

## Shrink-wrap to what the box now holds (the old rows are freed a frame
## late), then keep it on screen.
func _refit() -> void:
	if not is_inside_tree():
		return
	reset_size()
	_keep_on_screen()

## The bigger box must not run off the bottom (or top) of the screen.
func _keep_on_screen() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport_rect().size
	var r := get_global_rect()
	var y := clampf(r.position.y, 8.0, maxf(8.0, vp.y - r.size.y - 8.0))
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

	for child in _rows.get_children():
		_rows.remove_child(child)   # out of the layout now, not at frame end
		child.queue_free()

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
	for line in _enemy.get_action_lines():
		_add_sub_row(line)

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
			_rows.add_child(row)
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
	_rows.add_child(row)
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
	_rows.add_child(lbl)

## An ally or summon: health, armor, and each effect on it with what it does.
func _refresh_ally() -> void:
	if not is_instance_valid(_ally) or _ally.get("is_dead") == true:
		hide_panel()
		return
	var d: Dictionary = UnitTrackerUI.ally_info(_ally)
	_name_label.text = str(d["name"])
	for child in _rows.get_children():
		_rows.remove_child(child)   # out of the layout now, not at frame end
		child.queue_free()
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
		_rows.add_child(row)
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
