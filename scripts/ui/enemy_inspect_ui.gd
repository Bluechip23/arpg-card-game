class_name EnemyInspectUI
extends PanelContainer

## Enemy inspection panel, opened by clicking an enemy's square in the unit
## tracker. Shows a live 3D portrait of the monster, its name, current health
## and armor, its attack with every active amplification/reduction spelled
## out, resistance changes, and all buffs/debuffs currently on it.
## Refreshes while open; closes itself if the enemy dies or despawns.

const REFRESH_INTERVAL := 0.3

var _enemy: Enemy = null
var _viewport: SubViewport = null
var _portrait_holder: Control = null
var _fig: Node3D = null
var _name_label: Label = null
var _rows: VBoxContainer = null
var _timer: Timer = null

func _ready() -> void:
	custom_minimum_size = Vector2(280, 0)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.96)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.45, 0.3)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# Header: name + close button
	var header = HBoxContainer.new()
	vbox.add_child(header)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_name_label)
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(hide_panel)
	header.add_child(close_btn)

	# Live 3D portrait of the monster
	_portrait_holder = CenterContainer.new()
	_portrait_holder.custom_minimum_size = Vector2(0, 150)
	vbox.add_child(_portrait_holder)

	# Stat / effect rows (rebuilt on every refresh)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 3)
	vbox.add_child(_rows)

	_timer = Timer.new()
	_timer.wait_time = REFRESH_INTERVAL
	_timer.timeout.connect(_refresh)
	add_child(_timer)

func show_enemy(enemy: Enemy) -> void:
	if _enemy == enemy and visible:
		hide_panel()  # clicking the same enemy again toggles the panel closed
		return
	_enemy = enemy
	_build_portrait()
	_refresh()
	visible = true
	_timer.start()

func hide_panel() -> void:
	visible = false
	_enemy = null
	_timer.stop()
	_clear_portrait()

# ============================================
# PORTRAIT (own-world SubViewport with an EnemyFigure)
# ============================================

func _clear_portrait() -> void:
	for child in _portrait_holder.get_children():
		child.queue_free()
	_viewport = null
	_fig = null

func _build_portrait() -> void:
	_clear_portrait()
	if _enemy == null or not is_instance_valid(_enemy):
		return

	if _enemy.figure_kind == "":
		# Generic tiers have no 3D model — show their coloured square instead.
		var block = PanelContainer.new()
		block.custom_minimum_size = Vector2(120, 120)
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
		lbl.add_theme_font_size_override("font_size", 30)
		block.add_child(lbl)
		_portrait_holder.add_child(block)
		return

	var container = SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(180, 150)
	_portrait_holder.add_child(container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(180, 150)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_viewport)

	var key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, 28, 0)
	key.light_energy = 1.2
	_viewport.add_child(key)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-12, -40, 0)
	fill.light_energy = 0.5
	_viewport.add_child(fill)

	_fig = EnemyFigure.new()
	_viewport.add_child(_fig)
	_fig.setup(_enemy.figure_kind)

	var cam = Camera3D.new()
	_viewport.add_child(cam)
	cam.position = Vector3(0.3, 1.1, 2.9)
	cam.look_at_from_position(cam.position, Vector3(0, 0.75, 0), Vector3.UP)

# ============================================
# STATS / EFFECTS REFRESH
# ============================================

func _refresh() -> void:
	if _enemy == null or not is_instance_valid(_enemy) or _enemy.is_dead:
		hide_panel()
		return

	_name_label.text = _enemy.enemy_name

	for child in _rows.get_children():
		child.queue_free()

	# Health + armor
	_add_row("Health", "%d / %d" % [_enemy.current_health, _enemy.max_health], Color(0.4, 1.0, 0.4))
	if _enemy.current_armor > 0 or _enemy.max_armor > 0:
		var armor_txt := "%d / %d" % [_enemy.current_armor, _enemy.max_armor]
		if _enemy.is_exposed:
			armor_txt += "  (EXPOSED)"
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

	# Resistance changes (per-type resistances aren't in the game yet; the row
	# reports the states that change how much damage the enemy takes).
	var resists: Array[String] = []
	if _enemy.is_exposed:
		resists.append("Exposed — armor broken, takes full hits")
	if _enemy.enemy_type == Enemy.EnemyType.EARTH_MAGE:
		resists.append("Stoneskin — gains 3 armor whenever hit")
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
			var dot = ColorRect.new()
			dot.color = eff["color"]
			dot.custom_minimum_size = Vector2(12, 12)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(dot)
			var lbl = Label.new()
			lbl.text = "%s x%d" % [eff["name"], eff["stacks"]]
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
			row.add_child(lbl)
	else:
		_add_row("Effects", "none", Color(0.6, 0.6, 0.65))

func _add_row(label_text: String, value_text: String, value_color: Color) -> void:
	var row = HBoxContainer.new()
	_rows.add_child(row)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.62))
	lbl.custom_minimum_size = Vector2(92, 0)
	row.add_child(lbl)
	if value_text != "":
		var val = Label.new()
		val.text = value_text
		val.add_theme_font_size_override("font_size", 14)
		val.add_theme_color_override("font_color", value_color)
		row.add_child(val)

func _add_sub_row(text: String) -> void:
	var lbl = Label.new()
	lbl.text = "    • " + text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.82))
	_rows.add_child(lbl)
