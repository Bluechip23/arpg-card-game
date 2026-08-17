class_name CharacterPanel
extends CanvasLayer

## Character stats and equipment panel (toggle with I key)

signal closed
signal card_slotted(card: Card, item: ItemData)
signal card_unslotted(card: Card, item: ItemData)
## Emitted after any gear change with its tempo price (equip/unequip/two-hand/
## build switch). main.gd charges it on the tempo clock — but only in combat.
signal swap_tempo_spent(cost: int, action: String)

# Preloaded so this panel doesn't depend on the newer cell class_names being in
# Godot's global class cache on first run (matches the pattern in main.gd).
const EquipmentSlotCellScript = preload("res://scripts/character/equipment_slot_cell.gd")
const StorageItemCellScript = preload("res://scripts/character/storage_item_cell.gd")

@onready var panel: PanelContainer = $Panel
@onready var name_label: Label = $Panel/MarginContainer/VBox/NameLabel
@onready var stats_label: Label = $Panel/MarginContainer/VBox/StatsContainer/StatsLabel
@onready var derived_label: Label = $Panel/MarginContainer/VBox/StatsContainer/DerivedLabel
@onready var equipment_container: VBoxContainer = $Panel/MarginContainer/VBox/ScrollContainer/EquipmentContainer
@onready var close_button: Button = $Panel/MarginContainer/VBox/CloseButton

var player_stats: PlayerStats
var inventory: Inventory
var deck_manager = null  # DeckManager - untyped to avoid circular dependency
var item_tooltip: ItemTooltip
var _original_tooltip_parent: Node = null

# Detail side panel state
var _detail_panel: PanelContainer = null
var _detail_item: ItemData = null
var _detail_item_type: ItemData.ItemType = ItemData.ItemType.HELM
var _detail_slot_index: int = -1
var _detail_storage_index: int = -1  # >= 0 means stored item, -1 means equipped

# Card slot management panel state
var _card_slot_panel: PanelContainer = null
var _card_slot_item: ItemData = null

# Card confirm modal state
var _pending_card: Card = null
var _pending_card_index: int = -1
var _card_confirm_popup: PanelContainer = null

# Live 3D portrait + combat stats section (built on first open)
# SpriteFigure (Mana Seed sprites) or CharacterFigure (procedural 3D) —
# untyped; both expose setup(name, sprite_path).
var _portrait_fig = null
var _combat_label: Label = null
var buff_manager = null              # BuffManager (untyped to avoid class-cache dependency)
var debuff_manager = null            # DebuffManager
var _combat_rows: VBoxContainer = null      # addressable stat rows (for colour + hover highlight)
var _stat_rows: Dictionary = {}             # stat key -> {"row": HBoxContainer, "value": Label}
var _effects_box: VBoxContainer = null      # the ACTIVE EFFECTS list
var _core_stat_rows: VBoxContainer = null   # per-core-stat rows (hover shows what each stat does)
var _core_stat_value_labels: Dictionary = {}  # stat key -> value Label

# Sandbox: core stat rows grow -/+ buttons so builds can be tweaked freely.
var sandbox_stat_edit: bool = false

func set_sandbox_stat_edit(on: bool) -> void:
	sandbox_stat_edit = on
	# Rebuild the stat rows if they already exist so the -/+ buttons appear.
	if _core_stat_rows and is_instance_valid(_core_stat_rows):
		_core_stat_rows.queue_free()
		_core_stat_rows = null
		_core_stat_value_labels = {}

# Which combat stat each buff/debuff influences (for colouring + hover highlight).
# A buff contributes a "good" mark, a debuff a "bad" mark; net decides the colour.
const BUFF_AFFECTS := {
	"Strengthen": ["attack"], "Enlightened": ["crit"], "Haste": ["movement"],
	"Smith": ["armor"], "Bolster": ["armor"], "Shield Ready": ["armor"],
	"Shield of Growth": ["armor"], "Fortify": ["armor"], "Regen": ["hp_regen"],
	"Focused": ["mana_regen"], "Blessed": ["draw"], "Brace": ["damage_taken"],
	"Resilient": ["damage_taken"],
}
const DEBUFF_AFFECTS := {
	"Slowed": ["movement"], "Rooted": ["movement"], "Cursed": ["attack"],
	"Staggered": ["attack"], "Weighted": ["attack"], "Blind": ["attack"],
	"Wear Down": ["attack"], "Exposed": ["armor"], "Brittle": ["armor"],
	"Cuffed": ["draw"], "Drain": ["mana_regen"], "Vulnerable": ["damage_taken"],
}

# Ally paging: Main provides a callable returning the Player nodes currently in
# play; arrows above the portrait page the whole panel (stats + inventory +
# effects) between them. Hidden unless a partner is in play.
var _page_provider: Callable = Callable()
var _ally_nav: HBoxContainer = null
var _nav_label: Label = null

# Level / XP progress row under the portrait (level-up progress for whichever
# party member is being viewed).
var _level_label: Label = null
var _xp_bar: ProgressBar = null
var _xp_bar_text: Label = null

# The inventory half of the panel, split into its own window (see
# _split_windows): stats/portrait live in `panel`, equipment lives here.
var _inv_panel: PanelContainer = null

# Equipment build (loadout) buttons I / II / III in the inventory header.
const BUILD_NUMERALS := ["I", "II", "III"]
var _build_buttons: Array = []
var _rack_row: HBoxContainer = null      # War Rack row (Brad only)
var _rack_label: Label = null
var _rack_exchange_btn: Button = null
var _inv_message_label: Label = null  # transient feedback under the header

func _ready() -> void:
	layer = 100
	_apply_panel_style()
	_apply_label_styles()
	_apply_button_styles()
	_split_windows()
	hide_panel()
	close_button.pressed.connect(_on_close_pressed)


## Split the single condensed panel into two side-by-side windows: STATS
## (name, portrait, core/derived/combat stats) stays in `panel`, and the
## equipment list moves into its own INVENTORY window on the far right, so
## neither squeezes the other.
func _split_windows() -> void:
	var stats_vbox = $Panel/MarginContainer/VBox

	_inv_panel = PanelContainer.new()
	_inv_panel.name = "InventoryPanel"
	_inv_panel.add_theme_stylebox_override("panel", panel.get_theme_stylebox("panel"))
	add_child(_inv_panel)
	var inv_margin = MarginContainer.new()
	inv_margin.add_theme_constant_override("margin_left", 10)
	inv_margin.add_theme_constant_override("margin_right", 10)
	inv_margin.add_theme_constant_override("margin_top", 10)
	inv_margin.add_theme_constant_override("margin_bottom", 10)
	_inv_panel.add_child(inv_margin)
	var inv_vbox = VBoxContainer.new()
	inv_margin.add_child(inv_vbox)

	# Header row: title on the left, the three build buttons top-right.
	var inv_header = HBoxContainer.new()
	inv_vbox.add_child(inv_header)

	var inv_title = Label.new()
	inv_title.text = "INVENTORY"
	inv_title.add_theme_font_size_override("font_size", 18)
	inv_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	inv_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_header.add_child(inv_title)

	_build_buttons.clear()
	for i in range(BUILD_NUMERALS.size()):
		var bbtn = Button.new()
		bbtn.text = BUILD_NUMERALS[i]
		bbtn.custom_minimum_size = Vector2(30, 26)
		bbtn.focus_mode = Control.FOCUS_NONE
		bbtn.add_theme_font_size_override("font_size", 13)
		bbtn.tooltip_text = "Switch to equipment build %s\n(swaps cost tempo in combat)" % BUILD_NUMERALS[i]
		bbtn.pressed.connect(_on_build_pressed.bind(i))
		inv_header.add_child(bbtn)
		_build_buttons.append(bbtn)

	# Transient feedback line ("Too heavy", "Missing: ...", ...).
	_inv_message_label = Label.new()
	_inv_message_label.text = ""
	_inv_message_label.add_theme_font_size_override("font_size", 10)
	_inv_message_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
	_inv_message_label.visible = false
	inv_vbox.add_child(_inv_message_label)
	_refresh_build_buttons()

	# War Rack row (Brad only): what's strapped to his back + an exchange button.
	_rack_row = HBoxContainer.new()
	_rack_row.name = "WarRackRow"
	_rack_row.visible = false
	_rack_row.add_theme_constant_override("separation", 6)
	_rack_label = Label.new()
	_rack_label.text = "War Rack: (empty)"
	_rack_label.add_theme_font_size_override("font_size", 12)
	_rack_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
	_rack_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rack_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_rack_row.add_child(_rack_label)
	_rack_exchange_btn = Button.new()
	_rack_exchange_btn.text = "Exchange"
	_rack_exchange_btn.custom_minimum_size = Vector2(80, 26)
	_rack_exchange_btn.focus_mode = Control.FOCUS_NONE
	_rack_exchange_btn.add_theme_font_size_override("font_size", 12)
	_rack_exchange_btn.tooltip_text = "Swap everything in your hands with the gear on your back.\nFree out of combat; costs swap tempo in combat.\nIn battle, the Rack button offers the FREE cooldown swap."
	_rack_exchange_btn.pressed.connect(_on_rack_exchange_pressed)
	_rack_row.add_child(_rack_exchange_btn)
	inv_vbox.add_child(_rack_row)
	_refresh_rack_row()

	# Move the equipment half of the old panel into the new window.
	stats_vbox.get_node("HSeparator2").reparent(inv_vbox)
	stats_vbox.get_node("EquipmentLabel").reparent(inv_vbox)
	stats_vbox.get_node("ScrollContainer").reparent(inv_vbox)

	# The STATS content grows as active effects accrue — wrap it in a scroll so
	# it never overflows the window.
	var stats_margin = $Panel/MarginContainer
	var stats_scroll = ScrollContainer.new()
	stats_scroll.name = "StatsScroll"
	stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stats_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_margin.add_child(stats_scroll)
	stats_vbox.reparent(stats_scroll)
	stats_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# INVENTORY hugs the right edge; STATS sits beside it with a small gap. Both
	# span (nearly) the full screen height so the scroll has room to work.
	_inv_panel.anchor_left = 1.0
	_inv_panel.anchor_right = 1.0
	_inv_panel.anchor_top = 0.0
	_inv_panel.anchor_bottom = 1.0
	_inv_panel.offset_top = 40.0
	_inv_panel.offset_bottom = -40.0
	_inv_panel.offset_left = -348.0
	_inv_panel.offset_right = -4.0
	_inv_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_top = 40.0
	panel.offset_bottom = -40.0
	panel.offset_left = -664.0
	panel.offset_right = -356.0

func _apply_panel_style() -> void:
	if not panel:
		return
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.13, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.35, 0.35, 0.5)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)

func _apply_label_styles() -> void:
	if name_label:
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var stats_sep = $Panel/MarginContainer/VBox/HSeparator
	if stats_sep:
		stats_sep.add_theme_color_override("color", Color(0.3, 0.3, 0.45))

	if stats_label:
		stats_label.add_theme_font_size_override("font_size", 13)
		stats_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		stats_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	if derived_label:
		derived_label.add_theme_font_size_override("font_size", 13)
		derived_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		derived_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	var eq_label = $Panel/MarginContainer/VBox/EquipmentLabel
	if eq_label:
		eq_label.add_theme_font_size_override("font_size", 10)
		eq_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.7))

func _apply_button_styles() -> void:
	if not close_button:
		return
	close_button.add_theme_font_size_override("font_size", 13)

	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.15, 0.15, 0.2)
	btn_normal.border_width_left = 1
	btn_normal.border_width_right = 1
	btn_normal.border_width_top = 1
	btn_normal.border_width_bottom = 1
	btn_normal.border_color = Color(0.35, 0.35, 0.5)
	btn_normal.corner_radius_top_left = 4
	btn_normal.corner_radius_top_right = 4
	btn_normal.corner_radius_bottom_left = 4
	btn_normal.corner_radius_bottom_right = 4
	close_button.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.25, 0.25, 0.35)
	btn_hover.border_width_left = 1
	btn_hover.border_width_right = 1
	btn_hover.border_width_top = 1
	btn_hover.border_width_bottom = 1
	btn_hover.border_color = Color(0.5, 0.5, 0.7)
	btn_hover.corner_radius_top_left = 4
	btn_hover.corner_radius_top_right = 4
	btn_hover.corner_radius_bottom_left = 4
	btn_hover.corner_radius_bottom_right = 4
	close_button.add_theme_stylebox_override("hover", btn_hover)

func connect_stats(stats: PlayerStats, inv: Inventory, dm = null, bm = null, ddm = null) -> void:
	_disconnect_stats()
	player_stats = stats
	inventory = inv
	deck_manager = dm
	buff_manager = bm
	debuff_manager = ddm

	if player_stats:
		player_stats.health_changed.connect(_on_stats_changed)
		player_stats.mana_changed.connect(_on_mana_changed)
		player_stats.armor_changed.connect(_on_armor_changed)
		player_stats.stats_updated.connect(_on_stats_changed)
		player_stats.xp_changed.connect(_on_stats_changed)
		player_stats.leveled_up.connect(_on_stats_changed)
	if buff_manager and buff_manager.has_signal("buffs_changed"):
		buff_manager.buffs_changed.connect(_on_stats_changed)
	if debuff_manager and debuff_manager.has_signal("debuffs_changed"):
		debuff_manager.debuffs_changed.connect(_on_stats_changed)

	if inventory:
		inventory.equipment_changed.connect(_on_equipment_changed)
		inventory.storage_changed.connect(_on_storage_changed)
	item_tooltip = get_node_or_null("/root/Main/UI/ItemTooltip")

func _disconnect_stats() -> void:
	## Drop every change-signal connection to the currently bound character so
	## the panel can rebind to another party member without duplicate signals.
	if player_stats:
		_drop(player_stats.health_changed, _on_stats_changed)
		_drop(player_stats.mana_changed, _on_mana_changed)
		_drop(player_stats.armor_changed, _on_armor_changed)
		_drop(player_stats.stats_updated, _on_stats_changed)
		_drop(player_stats.xp_changed, _on_stats_changed)
		_drop(player_stats.leveled_up, _on_stats_changed)
	if buff_manager and buff_manager.has_signal("buffs_changed"):
		_drop(buff_manager.buffs_changed, _on_stats_changed)
	if debuff_manager and debuff_manager.has_signal("debuffs_changed"):
		_drop(debuff_manager.debuffs_changed, _on_stats_changed)
	if inventory:
		_drop(inventory.equipment_changed, _on_equipment_changed)
		_drop(inventory.storage_changed, _on_storage_changed)

static func _drop(sig: Signal, cb: Callable) -> void:
	if sig.is_connected(cb):
		sig.disconnect(cb)

# ---------------------------------------------------------------------------
# Ally paging (view party members' sheets/inventories)
# ---------------------------------------------------------------------------

func set_page_provider(provider: Callable) -> void:
	## Main hands us a callable returning the Player nodes currently in play.
	_page_provider = provider

func view_player(p) -> void:
	## Rebind the whole panel (stats, inventory, deck, effects) to a party member.
	if p == null or not is_instance_valid(p):
		return
	var inv: Inventory = p.get_inventory()
	var dm = inv.deck_manager if inv else null
	connect_stats(p.get_stats(), inv, dm, p.get_buff_manager(), p.get_debuff_manager())
	_close_detail_panel()
	_close_card_slot_panel()
	_refresh_build_buttons()
	update_display()

func _get_pages() -> Array:
	var pages: Array = []
	if _page_provider.is_valid():
		for p in _page_provider.call():
			if p != null and is_instance_valid(p) and p.get_stats() != null:
				pages.append(p)
	return pages

func _current_page_index(pages: Array) -> int:
	for i in range(pages.size()):
		if pages[i].get_stats() == player_stats:
			return i
	return 0

func _page_ally(dir: int) -> void:
	var pages := _get_pages()
	if pages.size() < 2:
		return
	view_player(pages[(_current_page_index(pages) + dir + pages.size()) % pages.size()])

func _make_nav_arrow(glyph: String, dir: int, tip: String) -> Button:
	var btn := Button.new()
	btn.text = glyph
	btn.custom_minimum_size = Vector2(30, 22)
	btn.focus_mode = Control.FOCUS_NONE
	btn.tooltip_text = tip
	btn.pressed.connect(_page_ally.bind(dir))
	return btn

func show_panel() -> void:
	_refresh_build_buttons()
	update_display()
	panel.visible = true
	if _inv_panel:
		_inv_panel.visible = true

func hide_panel() -> void:
	_close_detail_panel()
	_close_card_slot_panel()
	panel.visible = false
	if _inv_panel:
		_inv_panel.visible = false

func toggle_panel() -> void:
	if panel.visible:
		hide_panel()
	else:
		show_panel()

func is_open() -> bool:
	## True when the stats or inventory window is showing. Used by Main to keep
	## mouse-wheel scrolling inside the window from also zooming the battlefield.
	if panel and panel.visible:
		return true
	if _inv_panel and _inv_panel.visible:
		return true
	return false

func update_display() -> void:
	if not player_stats:
		return

	if name_label and player_stats.character_data:
		name_label.text = player_stats.character_data.character_name

	_ensure_portrait_and_combat()
	if _portrait_fig and player_stats.character_data:
		_portrait_fig.setup(player_stats.character_data.get_base_character(), player_stats.character_data.sprite_path)

	_update_ally_nav()
	_update_level_row()
	_refresh_rack_row()
	_update_core_stat_rows()

	if derived_label:
		derived_label.text = _build_derived_stats_text()

	_rebuild_combat_rows()
	if _combat_label:
		_combat_label.text = _build_combat_info_text()
	_rebuild_effects_list()

	_update_equipment_display()


## Build the live 3D portrait (like the enemy inspect panel's) and the combat
## stats section, inserted once under the character's name.
func _ensure_portrait_and_combat() -> void:
	if _portrait_fig and is_instance_valid(_portrait_fig):
		return
	var vbox = name_label.get_parent()

	# Ally paging arrows at the top of the stats window, above the portrait.
	# Shown only when more than one party member is in play (see update_display).
	_ally_nav = HBoxContainer.new()
	_ally_nav.name = "AllyNav"
	_ally_nav.alignment = BoxContainer.ALIGNMENT_CENTER
	_ally_nav.add_theme_constant_override("separation", 10)
	vbox.add_child(_ally_nav)
	vbox.move_child(_ally_nav, name_label.get_index() + 1)
	_ally_nav.add_child(_make_nav_arrow("◀", -1, "View previous party member"))
	_nav_label = Label.new()
	_nav_label.add_theme_font_size_override("font_size", 11)
	_nav_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
	_ally_nav.add_child(_nav_label)
	_ally_nav.add_child(_make_nav_arrow("▶", 1, "View next party member"))
	_ally_nav.visible = false

	var center = CenterContainer.new()
	center.name = "PortraitCenter"
	vbox.add_child(center)
	vbox.move_child(center, _ally_nav.get_index() + 1)

	var container = SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(150, 132)
	center.add_child(container)

	var vp = SubViewport.new()
	vp.size = Vector2i(150, 132)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(vp)

	var key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45, -30, 0)  # global upper-left light (style guide §3)
	key.light_energy = 1.2
	vp.add_child(key)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-12, -40, 0)
	fill.light_energy = 0.5
	vp.add_child(fill)

	# Portrait matches the in-battle look: sprite figure when the character
	# has one, procedural 3D otherwise. (The figure class is picked once here
	# from the current character; every playable character has sprite art.)
	var portrait_name := ""
	if player_stats and player_stats.character_data:
		portrait_name = player_stats.character_data.get_base_character()
	if SpriteFigure.supports(portrait_name):
		_portrait_fig = SpriteFigure.new()
	else:
		_portrait_fig = CharacterFigure.new()
	vp.add_child(_portrait_fig)

	var cam = Camera3D.new()
	vp.add_child(cam)
	if _portrait_fig is SpriteFigure:
		# Sprite figures are ~1.1 units tall billboards — frame them close-up.
		cam.position = Vector3(0.0, 0.55, 1.05)
		cam.look_at_from_position(cam.position, Vector3(0, 0.52, 0), Vector3.UP)
	else:
		cam.position = Vector3(0.25, 1.35, 2.7)
		cam.look_at_from_position(cam.position, Vector3(0, 0.8, 0), Vector3.UP)

	# Level / XP progress row under the portrait: the viewed party member's
	# level-up progress at a glance.
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 6)
	level_row.tooltip_text = "Level-up progress: XP toward the next level"
	vbox.add_child(level_row)
	vbox.move_child(level_row, center.get_index() + 1)
	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 13)
	_level_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.4))
	level_row.add_child(_level_label)
	var bar_wrap := Control.new()
	bar_wrap.custom_minimum_size = Vector2(0, 16)
	bar_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_row.add_child(bar_wrap)
	_xp_bar = ProgressBar.new()
	_xp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_xp_bar.show_percentage = false
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.55, 0.4, 0.85)
	xp_fill.set_corner_radius_all(3)
	_xp_bar.add_theme_stylebox_override("fill", xp_fill)
	bar_wrap.add_child(_xp_bar)
	_xp_bar_text = Label.new()
	_xp_bar_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_xp_bar_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_bar_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_xp_bar_text.add_theme_font_size_override("font_size", 10)
	_xp_bar_text.add_theme_color_override("font_color", Color(1, 1, 1))
	_xp_bar_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_wrap.add_child(_xp_bar_text)

	# Combat section: addressable stat rows (so buffs/debuffs can tint and the
	# effects list can highlight individual stats).
	var stats_container = stats_label.get_parent()
	var combat_header = _make_section_header("COMBAT")
	vbox.add_child(combat_header)
	vbox.move_child(combat_header, stats_container.get_index() + 1)
	_combat_rows = VBoxContainer.new()
	_combat_rows.add_theme_constant_override("separation", 1)
	vbox.add_child(_combat_rows)
	vbox.move_child(_combat_rows, combat_header.get_index() + 1)
	# A trailing combat label for the non-highlightable info lines.
	_combat_label = Label.new()
	_combat_label.add_theme_font_size_override("font_size", 12)
	_combat_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	vbox.add_child(_combat_label)
	vbox.move_child(_combat_label, _combat_rows.get_index() + 1)

	# ACTIVE EFFECTS list (buffs green, debuffs red; hover highlights the stat).
	var eff_header = _make_section_header("ACTIVE EFFECTS")
	vbox.add_child(eff_header)
	vbox.move_child(eff_header, _combat_label.get_index() + 1)
	_effects_box = VBoxContainer.new()
	_effects_box.add_theme_constant_override("separation", 2)
	vbox.add_child(_effects_box)
	vbox.move_child(_effects_box, eff_header.get_index() + 1)


func _update_ally_nav() -> void:
	if not _ally_nav:
		return
	var pages := _get_pages()
	_ally_nav.visible = pages.size() > 1
	if _nav_label and pages.size() > 1:
		_nav_label.text = "Party %d / %d" % [_current_page_index(pages) + 1, pages.size()]

func _update_level_row() -> void:
	if not _xp_bar or not player_stats:
		return
	var to_next: int = player_stats.get_xp_to_next_level()
	_level_label.text = "Lv %d" % player_stats.current_level
	_xp_bar.max_value = to_next
	_xp_bar.value = player_stats.current_xp
	_xp_bar_text.text = "%d / %d XP" % [player_stats.current_xp, to_next]

func _make_stat_row(key: String, label_text: String) -> void:
	var row := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.78))
	name_lbl.custom_minimum_size = Vector2(96, 0)
	row.add_child(name_lbl)
	var val_lbl := Label.new()
	val_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(val_lbl)
	_combat_rows.add_child(row)
	_stat_rows[key] = {"row": row, "value": val_lbl}


func _set_stat(key: String, value_text: String) -> void:
	if _stat_rows.has(key):
		_stat_rows[key]["value"].text = value_text


func _effect_scores() -> Dictionary:
	## Sum buff (+1) and debuff (-1) influence per stat key from active effects.
	var scores := {}
	if buff_manager:
		for b in buff_manager.buffs:
			for k in BUFF_AFFECTS.get(b.buff_name, []):
				scores[k] = scores.get(k, 0) + 1
	if debuff_manager:
		for d in debuff_manager.debuffs:
			for k in DEBUFF_AFFECTS.get(d.debuff_name, []):
				scores[k] = scores.get(k, 0) - 1
	return scores


func _colour_stat_rows() -> void:
	## Green when a buff is boosting the stat, red when a debuff hinders it.
	var scores := _effect_scores()
	for key in _stat_rows:
		var val: Label = _stat_rows[key]["value"]
		var s: int = scores.get(key, 0)
		if s > 0:
			val.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		elif s < 0:
			val.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		else:
			val.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))


func _rebuild_combat_rows() -> void:
	if _stat_rows.is_empty():
		_make_stat_row("attack", "Base Attack")
		_make_stat_row("crit", "Crit Chance")
		_make_stat_row("crit_dmg", "Crit Damage")
		_make_stat_row("movement", "Flash Points")
		_make_stat_row("draw", "Card Draw")
		_make_stat_row("mana_regen", "Mana Regen")
		_make_stat_row("hp_regen", "HP Regen")
		_make_stat_row("armor", "Armor Gain")
		_make_stat_row("damage_taken", "Dmg Taken")
	_set_stat("attack", "%d" % player_stats.get_effective_physical_damage(0))
	_set_stat("crit", "%d%%" % (player_stats.base_crit_chance + int(player_stats.sphere_bonus_crit) + player_stats.get_hand_size_crit_bonus()))
	_set_stat("crit_dmg", "%d%%" % roundi(player_stats.get_crit_damage_multiplier() * 100))
	_set_stat("movement", "%d / %d" % [player_stats.current_flash_points, player_stats.get_max_flash_points()])
	_set_stat("draw", "every %.0f tempo" % player_stats.get_effective_draw_timer())
	_set_stat("mana_regen", "+%.1f / tempo" % player_stats.get_effective_mana_regen())
	_set_stat("hp_regen", "+%d / cycle" % player_stats.sphere_bonus_regen)
	_set_stat("armor", "+%d / cycle" % player_stats.sphere_bonus_armor_per_cycle)
	_set_stat("damage_taken", _damage_taken_text())
	_colour_stat_rows()


func _damage_taken_text() -> String:
	var s: int = _effect_scores().get("damage_taken", 0)
	if s > 0:
		return "reduced"
	elif s < 0:
		return "increased"
	return "normal"


func _rebuild_effects_list() -> void:
	if not _effects_box:
		return
	for c in _effects_box.get_children():
		c.queue_free()
	var any := false
	if buff_manager:
		for b in buff_manager.buffs:
			var ikey: String = b.get_icon_key() if b.has_method("get_icon_key") else b.buff_name
			_add_effect_row(b.buff_name, b.description, Color(0.5, 1.0, 0.6), BUFF_AFFECTS.get(b.buff_name, []), ikey)
			any = true
	if debuff_manager:
		for d in debuff_manager.debuffs:
			_add_effect_row(d.debuff_name, d.description, Color(1.0, 0.5, 0.5), DEBUFF_AFFECTS.get(d.debuff_name, []))
			any = true
	if not any:
		var none := Label.new()
		none.text = "None"
		none.add_theme_font_size_override("font_size", 12)
		none.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		_effects_box.add_child(none)


func _add_effect_row(eff_name: String, desc: String, colour: Color, affected: Array, icon_key: String = "") -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.tooltip_text = desc
	var tex := StatusIcons.get_icon(icon_key if icon_key != "" else eff_name)
	if tex:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.custom_minimum_size = Vector2(18, 18)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
	var lbl := Label.new()
	lbl.text = "  " + eff_name
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", colour)
	row.add_child(lbl)
	_effects_box.add_child(row)
	# Hovering the effect highlights the stat rows it impacts.
	row.mouse_entered.connect(_highlight_stats.bind(affected, true))
	row.mouse_exited.connect(_highlight_stats.bind(affected, false))


func _highlight_stats(keys: Array, on: bool) -> void:
	for key in keys:
		if _stat_rows.has(key):
			var row: HBoxContainer = _stat_rows[key]["row"]
			row.modulate = Color(1.5, 1.5, 0.8) if on else Color(1, 1, 1)


func _build_combat_info_text() -> String:
	## The non-highlightable combat notes: resistances + Determination scaling.
	## (The numeric stat rows above carry the buff/debuff colouring.)
	var lines: Array[String] = []

	# Resistance changes, per damage type + blanket reductions
	var res_parts: Array[String] = []
	if player_stats.has_skill_tree_passive("stone_skin"):
		res_parts.append("Phys/Fire/Lightning 10% (Stone Skin)")
	for t in range(7):
		var v := player_stats.get_damage_resistance(t)
		if v > 0.0:
			res_parts.append("%s %d%%" % [DamageTypes.type_name(t), int(v)])
	if player_stats.sphere_bonus_resistance > 0.0:
		res_parts.append("All damage %.0f%%" % player_stats.sphere_bonus_resistance)
	lines.append("Resists      " + (", ".join(res_parts) if res_parts.size() > 0 else "none"))

	# Determination: stats scale with missing health. Show where the hero
	# stands now and exactly what their stats become at 50% health.
	var hp_pct := 0
	if player_stats.max_health > 0:
		hp_pct = int(round(100.0 * player_stats.current_health / player_stats.max_health))
	var now_mult := player_stats.get_determination_modifier()
	# 50% health falls in the <=60% Determination bracket: 0.25% per DET point.
	var mult_50: float = maxf(0.0, 1.0 + (player_stats.determination - PlayerStats.DET_NEUTRAL) * 0.0025)
	lines.append("HP now       %d%%  (stats x%.2f)" % [hp_pct, now_mult])
	lines.append("At 50%% HP    stats x%.2f  (%s%d%% via DET %d)" % [
		mult_50,
		"+" if mult_50 >= 1.0 else "",
		int(round((mult_50 - 1.0) * 100)),
		player_stats.determination,
	])
	return "\n".join(lines)

## Build one row per core stat, each carrying a hover tooltip explaining what
## the stat does (shared with the character-select allocation screen).
func _ensure_core_stat_rows() -> void:
	if _core_stat_rows and is_instance_valid(_core_stat_rows):
		return
	if not stats_label:
		return
	stats_label.visible = false  # replaced by the hoverable rows
	_core_stat_rows = VBoxContainer.new()
	_core_stat_rows.add_theme_constant_override("separation", 1)
	_core_stat_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var parent = stats_label.get_parent()
	parent.add_child(_core_stat_rows)
	parent.move_child(_core_stat_rows, stats_label.get_index() + 1)
	for key in CharacterData.STAT_KEYS:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.tooltip_text = "%s\n%s" % [CharacterData.stat_full_name(key), CharacterData.stat_description(key)]
		var name_lbl := Label.new()
		name_lbl.text = key
		name_lbl.custom_minimum_size = Vector2(38, 0)
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.78))
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_lbl)
		var val_lbl := Label.new()
		val_lbl.add_theme_font_size_override("font_size", 13)
		val_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
		val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(val_lbl)
		if sandbox_stat_edit:
			row.add_child(_make_sandbox_stat_button(key, -1))
			row.add_child(_make_sandbox_stat_button(key, 1))
		_core_stat_rows.add_child(row)
		_core_stat_value_labels[key] = val_lbl

func _update_core_stat_rows() -> void:
	_ensure_core_stat_rows()
	if not player_stats:
		return
	var vals := {
		"STR": player_stats.strength, "DEX": player_stats.dexterity,
		"INT": player_stats.intelligence, "WIS": player_stats.wisdom,
		"DET": player_stats.determination, "AGI": player_stats.agility,
	}
	for key in _core_stat_value_labels:
		_core_stat_value_labels[key].text = str(vals[key])

func _make_sandbox_stat_button(key: String, delta: int) -> Button:
	var btn := Button.new()
	btn.text = "−" if delta < 0 else "+"
	btn.custom_minimum_size = Vector2(22, 20)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 12)
	btn.tooltip_text = "Sandbox: adjust %s" % CharacterData.stat_full_name(key)
	btn.pressed.connect(_on_sandbox_stat_adjust.bind(key, delta))
	return btn

func _on_sandbox_stat_adjust(key: String, delta: int) -> void:
	## Sandbox-only: bump the underlying base stat up/down (min 1).
	if not player_stats:
		return
	match key:
		"STR": player_stats.base_strength = maxi(1, player_stats.base_strength + delta)
		"DEX": player_stats.base_dexterity = maxi(1, player_stats.base_dexterity + delta)
		"INT": player_stats.base_intelligence = maxi(1, player_stats.base_intelligence + delta)
		"WIS": player_stats.base_wisdom = maxi(1, player_stats.base_wisdom + delta)
		"DET": player_stats.determination = maxi(1, player_stats.determination + delta)
		"AGI": player_stats.base_agility = maxi(1, player_stats.base_agility + delta)
	update_display()

func _build_derived_stats_text() -> String:
	var total_crit = player_stats.base_crit_chance + int(player_stats.sphere_bonus_crit) + player_stats.get_hand_size_crit_bonus()
	var carry_flag = " OVER!" if player_stats.is_overburdened() else ""
	return """HP   %d/%d
Mana %.0f/%d
Armor  %d
Decay  -%d/t
Crit   %d%%
Carry  %d/%d%s
Regen  %.1f/t""" % [
		player_stats.current_health,
		player_stats.max_health,
		player_stats.current_mana,
		player_stats.max_mana,
		player_stats.current_armor,
		player_stats.armor_decay_per_cycle,
		total_crit,
		player_stats.current_carry_load,
		player_stats.get_carry_capacity(),
		carry_flag,
		player_stats.get_effective_mana_regen()
	]

func _update_equipment_display() -> void:
	if not equipment_container or not inventory:
		return

	for child in equipment_container.get_children():
		child.queue_free()

	# Passive section
	var passive_text = _get_character_passive()
	if passive_text != "":
		var passive_header = _make_section_header("UNIQUE PASSIVE")
		equipment_container.add_child(passive_header)

		var passive_label = Label.new()
		passive_label.text = passive_text
		passive_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		passive_label.add_theme_font_size_override("font_size", 12)
		passive_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		equipment_container.add_child(passive_label)

		equipment_container.add_child(_make_separator())

	# Equipment section header
	var eq_section = _make_section_header("EQUIPMENT")
	equipment_container.add_child(eq_section)

	var hint = Label.new()
	hint.text = "Drag items into matching slots"
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.62))
	equipment_container.add_child(hint)

	_build_equipment_slot_grid()

	# Total weight
	equipment_container.add_child(_make_separator())
	var weight_label = Label.new()
	weight_label.text = "Total Weight: %d" % inventory.get_total_weight()
	weight_label.add_theme_font_size_override("font_size", 12)
	weight_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	equipment_container.add_child(weight_label)

	# Inventory storage grid (items + cards)
	_update_storage_grid()

func _get_character_passive() -> String:
	if not inventory:
		return ""
	match inventory.character_name:
		"Ryan":
			return "Belt cards cost 1 less mana"
		"Brad":
			return "Chest items weigh 20% less"
		"Jeremy":
			return "Every 3rd cycle, the first ring trigger triggers twice"
		"Stephen":
			return "+10% off-hand enchantments (others get -10%)"
		"Cory":
			return "Gain 1 mana when gauntlet skill comes off cooldown"
	return ""

## Slot types shown in the equipment grid, in display order.
const SLOT_BIG := Vector2(84, 84)
const SLOT_SMALL := Vector2(58, 58)

## Build the equipment slots as a paper-doll: pieces sit where they'd be worn —
## helm on top, rings small beside it, chest below, main/off-hand flanking the
## belts, and gauntlets beside boots at the bottom. (Quivers share the weapon
## slots, so there is no separate quiver slot.)
func _build_equipment_slot_grid() -> void:
	var slot_info = inventory.get_slot_info()

	var doll := VBoxContainer.new()
	doll.add_theme_constant_override("separation", 6)
	doll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_container.add_child(doll)

	# --- Head row: rings (small) flank the helm ---
	var ring_data: Dictionary = slot_info["ring"]
	var ring_n: int = ring_data["max"]
	var left_rings: int = int(ceil(ring_n / 2.0))
	var head := _paperdoll_row()
	head.add_child(_ring_column(ring_data, 0, left_rings))
	head.add_child(_type_column("helm", ItemData.ItemType.HELM, SLOT_BIG))
	head.add_child(_ring_column(ring_data, left_rings, ring_n))
	doll.add_child(head)

	# --- Chest ---
	var chest_row := _paperdoll_row()
	chest_row.add_child(_type_column("chest", ItemData.ItemType.CHEST, SLOT_BIG))
	doll.add_child(chest_row)

	# --- Waist: main hand | belts | off hand(s) ---
	var weapon_data: Dictionary = slot_info["weapon"]
	var waist := _paperdoll_row()
	waist.add_child(_weapon_column(weapon_data, 0, 1, "Main Hand"))
	waist.add_child(_type_column("belt", ItemData.ItemType.BELT, SLOT_BIG))
	waist.add_child(_weapon_column(weapon_data, 1, weapon_data["max"], "Off Hand"))
	doll.add_child(waist)

	# --- Feet: gauntlets beside boots ---
	var feet := _paperdoll_row()
	feet.add_child(_type_column("gauntlets", ItemData.ItemType.GAUNTLETS, SLOT_BIG))
	feet.add_child(_type_column("boots", ItemData.ItemType.BOOTS, SLOT_BIG))
	doll.add_child(feet)

## A horizontal band that centres its slot columns within the inventory window.
func _paperdoll_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	return row

## A vertical stack of every slot of one type (e.g. all 4 of Ryan's belts).
func _type_column(key: String, item_type: ItemData.ItemType, cell_size: Vector2) -> VBoxContainer:
	var data: Dictionary = inventory.get_slot_info()[key]
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	var equipped: Array = data["equipped"]
	for i in range(data["max"]):
		var item = equipped[i] if i < equipped.size() else null
		col.add_child(_make_slot_cell(item_type, i, item, cell_size))
	return col

## Ring cells for slot indices [start, end), rendered small beside the helm.
func _ring_column(ring_data: Dictionary, start: int, end: int) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	var equipped: Array = ring_data["equipped"]
	for i in range(start, end):
		var item = equipped[i] if i < equipped.size() else null
		col.add_child(_make_slot_cell(ItemData.ItemType.RING, i, item, SLOT_SMALL))
	return col

## Weapon cells for slot indices [start, end) labelled Main Hand / Off Hand.
func _weapon_column(weapon_data: Dictionary, start: int, end: int, label: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	var equipped: Array = weapon_data["equipped"]
	for i in range(start, end):
		var item = equipped[i] if i < equipped.size() else null
		col.add_child(_make_slot_cell(ItemData.ItemType.WEAPON, i, item, SLOT_BIG, label))
	return col

func _make_slot_cell(item_type: int, slot_index: int, item, cell_size: Vector2, label_override: String = ""):
	var cell = EquipmentSlotCellScript.new()
	cell.setup(self, item_type, slot_index, item, cell_size, label_override)
	return cell

## The display name for an (empty) equipment slot type.
func _slot_type_name(item_type: int) -> String:
	match item_type:
		ItemData.ItemType.HELM: return "Helm"
		ItemData.ItemType.CHEST: return "Chest"
		ItemData.ItemType.RING: return "Ring"
		ItemData.ItemType.BELT: return "Belt"
		ItemData.ItemType.BOOTS: return "Boots"
		ItemData.ItemType.GAUNTLETS: return "Gauntlets"
		ItemData.ItemType.WEAPON: return "Weapon"
		ItemData.ItemType.QUIVER: return "Quiver"
	return "Slot"

## A small floating label used as the drag preview while dragging an item.
func _make_drag_preview(text: String, color: Color) -> Control:
	var wrap := Control.new()
	var pc := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16, 0.95)
	style.set_border_width_all(2)
	style.border_color = color
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	pc.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", color)
	pc.add_child(lbl)
	wrap.add_child(pc)
	pc.position = Vector2(-40, -14)
	return wrap

# ---------------------------------------------------------------------------
# Equipment builds (loadouts I / II / III)
# ---------------------------------------------------------------------------

func _on_build_pressed(index: int) -> void:
	if not inventory:
		return
	var result: Dictionary = inventory.switch_build(index)
	if result.get("success", false):
		var cost: int = result.get("tempo_cost", 0)
		if cost > 0:
			swap_tempo_spent.emit(cost, "Swapped to build %s" % BUILD_NUMERALS[index])
		var missing: Array = result.get("missing", [])
		if missing.size() > 0:
			_flash_inventory_message("Build %s missing: %s" % [BUILD_NUMERALS[index], ", ".join(missing)])
	else:
		_flash_inventory_message(result.get("reason", "Can't switch build"))
	_refresh_build_buttons()
	update_display()

func _refresh_build_buttons() -> void:
	for i in range(_build_buttons.size()):
		var btn: Button = _build_buttons[i]
		if not is_instance_valid(btn):
			continue
		var active = inventory != null and inventory.active_build == i
		btn.add_theme_color_override("font_color",
			Color(1.0, 0.85, 0.4) if active else Color(0.55, 0.55, 0.7))

func _refresh_rack_row() -> void:
	if not _rack_row or not is_instance_valid(_rack_row):
		return
	if not inventory or not inventory.has_back_rack:
		_rack_row.visible = false
		return
	_rack_row.visible = true
	var names := "(empty)"
	if inventory.rack_items.size() > 0:
		var parts: Array[String] = []
		for it in inventory.rack_items:
			parts.append(it.item_name)
		names = ", ".join(parts)
	var cd := ""
	if inventory.rack_cooldown_tempo > 0:
		cd = "  [free swap in %d tempo]" % inventory.rack_cooldown_tempo
	_rack_label.text = "War Rack: %s%s" % [names, cd]

func _on_rack_exchange_pressed() -> void:
	## Panel exchanges use the PAID path: free out of combat (main ignores the
	## cost), normal swap tempo in combat. The battle HUD button owns the
	## cooldown-gated free swap.
	if not inventory:
		return
	var result: Dictionary = inventory.rack_exchange(false)
	if result.get("success", false):
		var cost: int = result.get("tempo_cost", 0)
		if cost > 0:
			swap_tempo_spent.emit(cost, "War Rack exchange")
	else:
		_flash_inventory_message(result.get("reason", "Can't exchange"))
	_refresh_rack_row()
	update_display()

func _flash_inventory_message(text: String) -> void:
	if not _inv_message_label or not is_instance_valid(_inv_message_label):
		return
	_inv_message_label.text = text
	_inv_message_label.visible = true
	var tmr = get_tree().create_timer(3.0)
	tmr.timeout.connect(func():
		if _inv_message_label and is_instance_valid(_inv_message_label) and _inv_message_label.text == text:
			_inv_message_label.visible = false)

# ---------------------------------------------------------------------------
# Drag & drop handlers (called by the slot / storage cells)
# ---------------------------------------------------------------------------

## An item was dropped onto an equipment slot of matching type.
func _handle_item_drop_on_slot(data: Dictionary, target_type: int, target_slot: int) -> void:
	if not inventory:
		return
	var src = data.get("source")
	if src == "storage":
		var item: ItemData = data.get("item")
		if inventory.equip_from_storage(data.get("storage_index"), target_slot):
			swap_tempo_spent.emit(inventory.get_swap_tempo_cost(item.item_type), "Equipped %s" % item.item_name)
		else:
			_flash_inventory_message("Can't equip %s — too heavy or slot blocked" % item.item_name)
	elif src == "equipped":
		var from_slot: int = data.get("slot_index")
		if from_slot == target_slot:
			return
		if _move_equipped(target_type, from_slot, target_slot):
			var moved: ItemData = data.get("item")
			swap_tempo_spent.emit(inventory.get_swap_tempo_cost(moved.item_type), "Moved %s" % moved.item_name)
	update_display()

## Move (or swap) an equipped item between two slots of the same type.
## Returns true if anything actually moved.
func _move_equipped(item_type: int, from_slot: int, to_slot: int) -> bool:
	var moving = inventory.get_equipped_item(item_type, from_slot)
	if moving == null:
		return false
	var target = inventory.get_equipped_item(item_type, to_slot)
	inventory.unequip_item(item_type, from_slot)
	if target != null:
		inventory.unequip_item(item_type, to_slot)
		inventory.equip_item(target, from_slot)
	if not inventory.equip_item(moving, to_slot):
		# Target slot refused (e.g. locked by two-handing) — put it back.
		inventory.equip_item(moving, from_slot)
		return false
	return true

## An equipped item was dropped back onto the storage grid -> unequip it.
func _handle_item_drop_on_storage(data: Dictionary) -> void:
	if not inventory:
		return
	if data.get("source") == "equipped":
		var item: ItemData = data.get("item")
		if inventory.unequip_to_storage(data.get("item_type"), data.get("slot_index")):
			swap_tempo_spent.emit(inventory.get_swap_tempo_cost(item.item_type, true), "Unequipped %s" % item.item_name)
		update_display()

func _make_separator() -> HSeparator:
	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color(0.3, 0.3, 0.45))
	return sep

func _make_section_header(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.7))
	return lbl

# ============================================
# ITEM DETAIL SIDE PANEL
# ============================================

func _on_equipped_item_clicked(item: ItemData, item_type: ItemData.ItemType, slot_index: int) -> void:
	_show_detail_panel(item, item_type, slot_index, -1)

func _on_stored_item_right_clicked(item: ItemData, _storage_index: int) -> void:
	## Right-click uses utility items. The Return Scroll opens a town portal
	## beside the player (interact with [Shift] to travel home).
	if item.special_id == "return_scroll":
		var main_node = get_node_or_null("/root/Main")
		if main_node and main_node.has_method("spawn_town_portal"):
			main_node.spawn_town_portal()
			toggle_panel()  # close the inventory so the portal is visible

func _on_stored_item_clicked(item: ItemData, storage_index: int) -> void:
	_show_detail_panel(item, item.item_type, -1, storage_index)

func _show_detail_panel(item: ItemData, item_type: ItemData.ItemType, slot_index: int, storage_index: int) -> void:
	_close_detail_panel()

	_detail_item = item
	_detail_item_type = item_type
	_detail_slot_index = slot_index
	_detail_storage_index = storage_index

	# Build the detail panel
	_detail_panel = PanelContainer.new()
	_detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Fully opaque style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = _get_item_type_color(item.item_type)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_detail_panel.add_theme_stylebox_override("panel", style)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(240, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# An equipped mythic shows its own art here, blown up from the same sprite
	# the equipment slot displays.
	var equipped := storage_index < 0
	if equipped and item.has_appearance_art():
		var art_holder = CenterContainer.new()
		art_holder.add_child(EquipmentSlotCellScript.make_pixel_art_rect(
			item.get_appearance_texture(), Vector2(96, 96)))
		vbox.add_child(art_holder)

	# Item name (colored by type)
	var item_name_lbl = Label.new()
	item_name_lbl.text = item.item_name
	item_name_lbl.add_theme_font_size_override("font_size", 16)
	item_name_lbl.add_theme_color_override("font_color", _get_item_type_color(item.item_type))
	vbox.add_child(item_name_lbl)

	# Item type
	var type_lbl = Label.new()
	type_lbl.text = item.get_type_name()
	type_lbl.add_theme_font_size_override("font_size", 12)
	type_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(type_lbl)

	vbox.add_child(_make_separator())

	# Stats
	var stats_text = _build_item_stats_text(item)
	if stats_text != "":
		var stats_lbl = Label.new()
		stats_lbl.text = stats_text
		stats_lbl.add_theme_font_size_override("font_size", 13)
		stats_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(stats_lbl)

	# Effects
	var effect_text = _build_item_effect_text(item)
	if effect_text != "":
		var effect_lbl = Label.new()
		effect_lbl.text = effect_text
		effect_lbl.add_theme_font_size_override("font_size", 12)
		effect_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(effect_lbl)

	# What the thing actually looks like (mythics carry this).
	if item.appearance != "":
		vbox.add_child(_make_separator())
		var look_lbl = Label.new()
		look_lbl.text = item.appearance
		look_lbl.add_theme_font_size_override("font_size", 12)
		look_lbl.add_theme_color_override("font_color", item.get_rarity_color())
		look_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(look_lbl)

	# Description
	if item.description != "":
		vbox.add_child(_make_separator())
		var desc_lbl = Label.new()
		desc_lbl.text = item.description
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_lbl)

	vbox.add_child(_make_separator())

	# Two-handing status (equipped weapons/shields only)
	if storage_index < 0 and inventory and item.item_type == ItemData.ItemType.WEAPON \
			and inventory.two_handed_slot == slot_index:
		var th_info = Label.new()
		var carried = floori(item.weight * Inventory.TWO_HAND_WEIGHT_MULT)
		var bonus = floori(item.weight / Inventory.TWO_HAND_WEIGHT_DAMAGE_DIVISOR)
		var bonus_word = "block" if item.weapon_subtype == ItemData.WeaponSubtype.SHIELD else "damage"
		th_info.text = "Two-handing: carried weight %d (of %d), +%d %s" % [carried, item.weight, bonus, bonus_word]
		th_info.add_theme_font_size_override("font_size", 12)
		th_info.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
		th_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(th_info)

	# Action buttons
	if storage_index >= 0:
		# Stored item - show Equip button
		var equip_btn = _make_action_button("Equip", Color(0.15, 0.35, 0.2), Color(0.3, 0.7, 0.4))
		equip_btn.pressed.connect(_on_equip_stored_item)
		vbox.add_child(equip_btn)
		# Destroy (drop) — permanent, so the button itself asks twice.
		if item.special_id == "":
			var destroy_btn = _make_action_button("Destroy", Color(0.3, 0.1, 0.1), Color(0.85, 0.3, 0.3))
			destroy_btn.tooltip_text = "Permanently remove this item from your inventory."
			destroy_btn.pressed.connect(_on_destroy_stored_item.bind(destroy_btn))
			vbox.add_child(destroy_btn)
	else:
		# Equipped item - show Unequip button
		var unequip_btn = _make_action_button("Unequip", Color(0.35, 0.15, 0.15), Color(0.7, 0.35, 0.35))
		unequip_btn.pressed.connect(_on_unequip_item)
		vbox.add_child(unequip_btn)

	# Two-handing toggle for anything held in a hand slot (not quivers, and
	# not bows/staffs — those are two-handed by nature and gain no bonuses).
	if storage_index < 0 and inventory and item.item_type == ItemData.ItemType.WEAPON \
			and not Inventory.is_two_hand_only(item):
		var two_handed = inventory.two_handed_slot == slot_index
		var th_text: String
		if two_handed:
			th_text = "Release to One Hand"
		else:
			var th_bonus = floori(item.weight / Inventory.TWO_HAND_WEIGHT_DAMAGE_DIVISOR)
			if item.weapon_subtype == ItemData.WeaponSubtype.SHIELD:
				th_text = "Brace Two-Handed (+%d block)" % th_bonus
			else:
				th_text = "Wield Two-Handed (+%d damage)" % th_bonus
		var th_btn = _make_action_button(th_text, Color(0.3, 0.24, 0.1), Color(0.85, 0.7, 0.3))
		th_btn.tooltip_text = "Two-handing halves this item's carried weight but cuts total\ncarry capacity to 70%% and occupies a second hand slot.\nCosts %d tempo in combat." % inventory.get_swap_tempo_cost(ItemData.ItemType.WEAPON)
		th_btn.pressed.connect(_on_toggle_two_handed)
		vbox.add_child(th_btn)

	# Card slot management button (for equipped items with card slots)
	if item.has_card_slots() and storage_index < 0:
		var card_btn = _make_action_button("Manage Cards (%d/%d)" % [item.slotted_cards.size(), item.card_slots], Color(0.2, 0.15, 0.3), Color(0.6, 0.4, 0.9))
		card_btn.pressed.connect(_open_card_slot_panel.bind(item))
		vbox.add_child(card_btn)

	# Close button
	var close_btn = _make_action_button("Close", Color(0.15, 0.15, 0.2), Color(0.35, 0.35, 0.5))
	close_btn.pressed.connect(_close_detail_panel)
	vbox.add_child(close_btn)

	# Add the panel as a sibling of the inventory panel, positioned to its left
	panel.add_sibling(_detail_panel)

	# Position to the left of the inventory panel
	_detail_panel.anchors_preset = Control.PRESET_TOP_RIGHT
	_detail_panel.anchor_left = 1.0
	_detail_panel.anchor_right = 1.0
	_detail_panel.anchor_top = 0.0
	_detail_panel.anchor_bottom = 1.0
	# Stats + inventory windows occupy the right ~620px; open to their left.
	_detail_panel.offset_left = -890.0
	_detail_panel.offset_right = -632.0
	_detail_panel.offset_top = 20.0
	_detail_panel.offset_bottom = -20.0

func _make_action_button(text: String, bg_color: Color, border_color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 13)
	btn.custom_minimum_size = Vector2(200, 32)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = bg_color
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	btn_style.border_color = border_color
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", btn_hover)

	return btn

func _on_unequip_item() -> void:
	if not inventory or not _detail_item:
		return
	if _detail_slot_index < 0:
		return

	if inventory.is_storage_full():
		print("[PANEL] Cannot unequip - inventory storage is full!")
		_flash_inventory_message("Inventory storage is full")
		return

	var item = _detail_item
	if inventory.unequip_to_storage(_detail_item_type, _detail_slot_index):
		swap_tempo_spent.emit(inventory.get_swap_tempo_cost(item.item_type, true), "Unequipped %s" % item.item_name)
	_close_detail_panel()
	update_display()

func _on_toggle_two_handed() -> void:
	if not inventory or not _detail_item or _detail_slot_index < 0:
		return
	var item = _detail_item
	var enable = inventory.two_handed_slot != _detail_slot_index
	if inventory.set_two_handed(_detail_slot_index, enable):
		var action: String
		if enable:
			action = "Gripped %s two-handed" % item.item_name
		else:
			action = "Released %s to one hand" % item.item_name
		swap_tempo_spent.emit(inventory.get_swap_tempo_cost(ItemData.ItemType.WEAPON), action)
	else:
		if enable:
			_flash_inventory_message("Can't two-hand %s — needs a free hand slot and enough capacity" % item.item_name)
		else:
			_flash_inventory_message("Too heavy to hold %s one-handed right now" % item.item_name)
	_close_detail_panel()
	update_display()

func _on_equip_stored_item() -> void:
	if not inventory or not _detail_item:
		return
	if _detail_storage_index < 0:
		return

	# Find first empty slot for this item type
	var slot_array = inventory._get_slot_array(_detail_item.item_type)
	var max_slots = inventory._get_max_slots(_detail_item.item_type)
	var target_slot = -1
	for i in range(max_slots):
		if slot_array[i] == null and not inventory.is_two_hand_locked_slot(i if slot_array == inventory.equipped_weapons else -1):
			target_slot = i
			break

	if target_slot < 0:
		print("[PANEL] Cannot equip - no empty %s slot!" % _detail_item.get_type_name())
		_flash_inventory_message("No free %s slot" % _detail_item.get_type_name())
		return

	var item = _detail_item
	if inventory.equip_from_storage(_detail_storage_index, target_slot):
		swap_tempo_spent.emit(inventory.get_swap_tempo_cost(item.item_type), "Equipped %s" % item.item_name)
	else:
		_flash_inventory_message("Can't equip %s — too heavy" % item.item_name)
	_close_detail_panel()
	update_display()

func _on_destroy_stored_item(btn: Button) -> void:
	## Permanent, so it takes two clicks: the first arms the button.
	if not is_instance_valid(btn):
		return
	if btn.text != "Really destroy?":
		btn.text = "Really destroy?"
		return
	if not inventory or _detail_storage_index < 0:
		return
	var doomed = _detail_item.item_name if _detail_item else "item"
	if inventory.destroy_stored_item(_detail_storage_index):
		var main_node = get_node_or_null("/root/Main")
		if main_node and main_node.has_method("add_battle_log"):
			main_node.add_battle_log("Destroyed %s." % doomed, Color(1.0, 0.5, 0.4))
	_close_detail_panel()
	update_display()

func _close_detail_panel() -> void:
	if _detail_panel and is_instance_valid(_detail_panel):
		_detail_panel.queue_free()
	_detail_panel = null
	_detail_item = null
	_detail_slot_index = -1
	_detail_storage_index = -1

# ============================================
# CARD SLOT MANAGEMENT PANEL
# ============================================

func _open_card_slot_panel(item: ItemData) -> void:
	_close_card_slot_panel()
	_close_detail_panel()
	_card_slot_item = item

	_card_slot_panel = PanelContainer.new()
	_card_slot_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.14, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.6, 0.4, 0.9)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_card_slot_panel.add_theme_stylebox_override("panel", style)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card_slot_panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Header
	var title = Label.new()
	title.text = "%s - Card Slots (%d/%d)" % [item.item_name, item.slotted_cards.size(), item.card_slots]
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
	vbox.add_child(title)

	# Keyword restriction info
	if item.allowed_card_keywords.size() > 0:
		var restrict_label = Label.new()
		var keyword_names: Array[String] = []
		for kw in item.allowed_card_keywords:
			match kw:
				1: keyword_names.append("Arrow")
				2: keyword_names.append("Pocket")
				3: keyword_names.append("Gem")
				4: keyword_names.append("Chisel")
				5: keyword_names.append("Swift")
				6: keyword_names.append("Buckler")
				7: keyword_names.append("Crown")
				8: keyword_names.append("Fist")
		restrict_label.text = "Accepts: %s cards only" % ", ".join(keyword_names)
		restrict_label.add_theme_font_size_override("font_size", 11)
		restrict_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
		vbox.add_child(restrict_label)

	vbox.add_child(_make_separator())

	# === SLOTTED CARDS SECTION ===
	var slotted_header = Label.new()
	slotted_header.text = "SLOTTED CARDS"
	slotted_header.add_theme_font_size_override("font_size", 11)
	slotted_header.add_theme_color_override("font_color", Color(0.55, 0.55, 0.7))
	vbox.add_child(slotted_header)

	if item.slotted_cards.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "  (No cards slotted)"
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		vbox.add_child(empty_label)
	else:
		for i in range(item.slotted_cards.size()):
			var card = item.slotted_cards[i]
			var row_hbox = HBoxContainer.new()
			row_hbox.add_theme_constant_override("separation", 6)

			var card_label = Label.new()
			var tag = " [Molded]" if card.is_molded else " [%s]" % card.get_slot_keyword()
			# Colored slots (Mauls Sabre): name and tint the slot's color.
			var color_prefix := ""
			var label_color := Color(0.7, 0.55, 0.9)
			if i < item.slot_colors.size():
				color_prefix = "[%s] " % str(item.slot_colors[i]).capitalize()
				match str(item.slot_colors[i]):
					"blue": label_color = Color(0.5, 0.7, 1.0)
					"red": label_color = Color(1.0, 0.5, 0.5)
			card_label.text = "%s%s%s" % [color_prefix, card.card_name, tag]
			card_label.add_theme_font_size_override("font_size", 12)
			card_label.add_theme_color_override("font_color", label_color)
			card_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row_hbox.add_child(card_label)

			if not card.is_molded:
				var remove_btn = Button.new()
				remove_btn.text = "Remove"
				remove_btn.add_theme_font_size_override("font_size", 11)
				remove_btn.custom_minimum_size = Vector2(70, 24)
				var btn_style = StyleBoxFlat.new()
				btn_style.bg_color = Color(0.35, 0.15, 0.15)
				btn_style.border_color = Color(0.7, 0.35, 0.35)
				btn_style.border_width_left = 1
				btn_style.border_width_right = 1
				btn_style.border_width_top = 1
				btn_style.border_width_bottom = 1
				btn_style.corner_radius_top_left = 3
				btn_style.corner_radius_top_right = 3
				btn_style.corner_radius_bottom_left = 3
				btn_style.corner_radius_bottom_right = 3
				remove_btn.add_theme_stylebox_override("normal", btn_style)
				var btn_hover = btn_style.duplicate()
				btn_hover.bg_color = Color(0.45, 0.2, 0.2)
				remove_btn.add_theme_stylebox_override("hover", btn_hover)
				remove_btn.pressed.connect(_on_unslot_card.bind(item, i))
				row_hbox.add_child(remove_btn)

			vbox.add_child(row_hbox)

	# Colored slots (Mauls Sabre): show which colored slots are still open —
	# slot order decides the color, so the player should see what's next.
	for i in range(item.slotted_cards.size(), mini(item.card_slots, item.slot_colors.size())):
		var open_label = Label.new()
		open_label.text = "  (open [%s] slot)" % str(item.slot_colors[i]).capitalize()
		open_label.add_theme_font_size_override("font_size", 12)
		match str(item.slot_colors[i]):
			"blue": open_label.add_theme_color_override("font_color", Color(0.4, 0.55, 0.8))
			"red": open_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
			_: open_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		vbox.add_child(open_label)

	vbox.add_child(_make_separator())

	# === AVAILABLE CARDS SECTION ===
	var avail_header = Label.new()
	avail_header.text = "AVAILABLE CARDS FROM DECK"
	avail_header.add_theme_font_size_override("font_size", 11)
	avail_header.add_theme_color_override("font_color", Color(0.55, 0.55, 0.7))
	vbox.add_child(avail_header)

	var free_slots = item.get_free_card_slots()
	if free_slots <= 0:
		var full_label = Label.new()
		full_label.text = "  (All slots filled)"
		full_label.add_theme_font_size_override("font_size", 12)
		full_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		vbox.add_child(full_label)
	elif deck_manager:
		# Gather all cards from all piles that can be slotted
		var available_cards: Array = []
		for card in deck_manager.draw_pile:
			if item.can_slot_card(card) and not card.is_slotted():
				available_cards.append(card)
		for card in deck_manager.hand:
			if item.can_slot_card(card) and not card.is_slotted():
				available_cards.append(card)
		for card in deck_manager.discard_pile:
			if item.can_slot_card(card) and not card.is_slotted():
				available_cards.append(card)

		if available_cards.size() == 0:
			var none_label = Label.new()
			none_label.text = "  (No compatible cards in deck)"
			none_label.add_theme_font_size_override("font_size", 12)
			none_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
			vbox.add_child(none_label)
		else:
			for card in available_cards:
				var row_hbox = HBoxContainer.new()
				row_hbox.add_theme_constant_override("separation", 6)

				var card_label = Label.new()
				var info = card.card_name
				if card.card_keyword != 0:  # Not NONE
					var kw_name = ""
					match card.card_keyword:
						1: kw_name = "Arrow"
						2: kw_name = "Pocket"
						3: kw_name = "Gem"
						4: kw_name = "Chisel"
						5: kw_name = "Swift"
						6: kw_name = "Buckler"
						7: kw_name = "Crown"
						8: kw_name = "Fist"
					info += " [%s]" % kw_name
				card_label.text = info
				card_label.add_theme_font_size_override("font_size", 12)
				card_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
				card_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row_hbox.add_child(card_label)

				var slot_btn = Button.new()
				slot_btn.text = "Slot"
				slot_btn.add_theme_font_size_override("font_size", 11)
				slot_btn.custom_minimum_size = Vector2(60, 24)
				var btn_style2 = StyleBoxFlat.new()
				btn_style2.bg_color = Color(0.15, 0.2, 0.35)
				btn_style2.border_color = Color(0.4, 0.5, 0.9)
				btn_style2.border_width_left = 1
				btn_style2.border_width_right = 1
				btn_style2.border_width_top = 1
				btn_style2.border_width_bottom = 1
				btn_style2.corner_radius_top_left = 3
				btn_style2.corner_radius_top_right = 3
				btn_style2.corner_radius_bottom_left = 3
				btn_style2.corner_radius_bottom_right = 3
				slot_btn.add_theme_stylebox_override("normal", btn_style2)
				var btn_hover2 = btn_style2.duplicate()
				btn_hover2.bg_color = Color(0.2, 0.25, 0.45)
				slot_btn.add_theme_stylebox_override("hover", btn_hover2)
				slot_btn.pressed.connect(_on_slot_card.bind(card, item))
				row_hbox.add_child(slot_btn)

				vbox.add_child(row_hbox)

	vbox.add_child(_make_separator())

	# Close button
	var close_btn = _make_action_button("Close", Color(0.15, 0.15, 0.2), Color(0.35, 0.35, 0.5))
	close_btn.pressed.connect(_close_card_slot_panel)
	vbox.add_child(close_btn)

	# Position to left of character panel
	panel.add_sibling(_card_slot_panel)
	_card_slot_panel.anchors_preset = Control.PRESET_TOP_RIGHT
	_card_slot_panel.anchor_left = 1.0
	_card_slot_panel.anchor_right = 1.0
	_card_slot_panel.anchor_top = 0.0
	_card_slot_panel.anchor_bottom = 1.0
	_card_slot_panel.offset_left = -950.0
	_card_slot_panel.offset_right = -632.0
	_card_slot_panel.offset_top = 20.0
	_card_slot_panel.offset_bottom = -20.0

func _on_slot_card(card: Card, item: ItemData) -> void:
	if not inventory:
		return
	if inventory.enchant_card(card, item):
		card_slotted.emit(card, item)
		_open_card_slot_panel(item)  # Refresh the panel
		update_display()

func _on_unslot_card(item: ItemData, card_index: int) -> void:
	if not inventory:
		return
	var card = inventory.extract_card(item, card_index)
	if card:
		card_unslotted.emit(card, item)
		_open_card_slot_panel(item)  # Refresh the panel
		update_display()

func _close_card_slot_panel() -> void:
	if _card_slot_panel and is_instance_valid(_card_slot_panel):
		_card_slot_panel.queue_free()
	_card_slot_panel = null
	_card_slot_item = null

func _build_item_stats_text(item: ItemData) -> String:
	var lines: Array[String] = []
	if item.strength_bonus != 0:
		lines.append("+%d Strength" % item.strength_bonus if item.strength_bonus > 0 else "%d Strength" % item.strength_bonus)
	if item.dexterity_bonus != 0:
		lines.append("+%d Dexterity" % item.dexterity_bonus if item.dexterity_bonus > 0 else "%d Dexterity" % item.dexterity_bonus)
	if item.intelligence_bonus != 0:
		lines.append("+%d Intelligence" % item.intelligence_bonus if item.intelligence_bonus > 0 else "%d Intelligence" % item.intelligence_bonus)
	if item.wisdom_bonus != 0:
		lines.append("+%d Wisdom" % item.wisdom_bonus if item.wisdom_bonus > 0 else "%d Wisdom" % item.wisdom_bonus)
	if item.determination_bonus != 0:
		lines.append("+%d Determination" % item.determination_bonus if item.determination_bonus > 0 else "%d Determination" % item.determination_bonus)
	if item.agility_bonus != 0:
		lines.append("+%d Agility" % item.agility_bonus if item.agility_bonus > 0 else "%d Agility" % item.agility_bonus)
	if item.health_bonus != 0:
		lines.append("+%d Health" % item.health_bonus if item.health_bonus > 0 else "%d Health" % item.health_bonus)
	if item.mana_bonus != 0:
		lines.append("+%d Mana" % item.mana_bonus if item.mana_bonus > 0 else "%d Mana" % item.mana_bonus)
	if item.armor_bonus != 0:
		lines.append("+%d Armor" % item.armor_bonus if item.armor_bonus > 0 else "%d Armor" % item.armor_bonus)
	if item.hand_size_bonus != 0:
		lines.append("+%d Hand Size" % item.hand_size_bonus)
	if item.weapon_damage > 0:
		lines.append("%d Weapon Damage" % item.weapon_damage)
	if item.weight > 0:
		lines.append("Weight: %d" % item.weight)
	return "\n".join(lines)

func _build_item_effect_text(item: ItemData) -> String:
	var lines: Array[String] = []
	if item.ring_trigger != ItemData.RingTrigger.NONE:
		lines.append("[Ring] %s → %s" % [item.get_ring_trigger_name(), item.get_ring_effect_name()])
	if item.gauntlet_skill_type == ItemData.GauntletSkillType.ACTIVE:
		lines.append("[Active] %s: %s" % [item.gauntlet_skill_name, item.gauntlet_skill_description])
		lines.append("  Cost: %d Mana | CD: %d turns" % [item.gauntlet_skill_mana_cost, item.gauntlet_skill_cooldown])
	elif item.gauntlet_skill_type == ItemData.GauntletSkillType.PASSIVE:
		lines.append("[Passive] %s: %s" % [item.gauntlet_skill_name, item.gauntlet_skill_description])
	match item.special_effect:
		ItemData.SpecialEffect.OVERFLOW_HEAL_ARMOR:
			lines.append("[Overflow] Heal %d, +%d Armor" % [item.special_effect_value, item.special_effect_value_2])
		ItemData.SpecialEffect.GRANT_BLINK_CARD:
			lines.append("[Equip] Grants %d Blink card(s)" % item.special_effect_value)
		ItemData.SpecialEffect.CHANCE_BOOST:
			lines.append("[Passive] +%d%% chance effects" % item.special_effect_value)
		ItemData.SpecialEffect.GRANT_CARDS:
			lines.append("[Equip] Grants cards: %s" % ", ".join(item.granted_card_ids))
	# Shields pass: Overdraw charges are live state worth showing.
	if item.overdraw_spell_charges > 0:
		lines.append("[Overdraw] %s: %d/%d charge(s), one back every %d tempo" % [
			item.overdraw_spell_id.capitalize().replace("_", " "),
			item.overdraw_charges_left, item.overdraw_spell_charges, item.overdraw_spell_recharge])
	if item.overdraw_card_max > 0:
		lines.append("[Overdraw] %d/%d %s waiting" % [item.conjured_in_manifest,
			item.overdraw_card_max, item.overdraw_card_id.capitalize()])
	if item.has_mastery():
		lines.append("[%s]" % item.get_mastery_text(player_stats))
	if item.has_card_slots():
		lines.append("[Card Slots] %d/%d" % [item.slotted_cards.size(), item.card_slots])
		for card in item.slotted_cards:
			var tags = ""
			if card.is_molded:
				tags = " (Molded)"
			else:
				tags = " (%s)" % card.get_slot_keyword()
			lines.append("  > %s%s" % [card.card_name, tags])
	return "\n".join(lines)

# ============================================
# OLD TOOLTIP COMPAT (no longer follows mouse)
# ============================================

func _on_item_hover(_item: ItemData) -> void:
	pass

func _on_item_hover_end() -> void:
	pass

func _on_close_pressed() -> void:
	hide_panel()
	closed.emit()

func _on_stats_changed(_a = null, _b = null) -> void:
	if panel.visible:
		update_display()

func _on_mana_changed(_a = null, _b = null) -> void:
	if panel.visible:
		update_display()

func _on_armor_changed(_a = null) -> void:
	if panel.visible:
		update_display()

func _on_equipment_changed() -> void:
	if panel.visible:
		_close_detail_panel()
		update_display()

func _on_storage_changed() -> void:
	if panel.visible:
		update_display()

func _update_storage_grid() -> void:
	if not equipment_container or not inventory:
		return

	equipment_container.add_child(_make_separator())

	# Inventory header row: "INVENTORY (X/20)" on left, "Gold: X" and "Culling Stones: X" on right
	var inv_header_hbox = HBoxContainer.new()

	var storage_header = _make_section_header("INVENTORY (%d/%d)" % [inventory.used_storage_slots(), inventory.max_storage_slots])
	inv_header_hbox.add_child(storage_header)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_header_hbox.add_child(spacer)

	var gold_label = Label.new()
	gold_label.text = "Gold: %d" % player_stats.gold
	gold_label.add_theme_font_size_override("font_size", 10)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	inv_header_hbox.add_child(gold_label)

	equipment_container.add_child(inv_header_hbox)

	# Culling stones row
	var stones_hbox = HBoxContainer.new()
	var stones_spacer = Control.new()
	stones_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stones_hbox.add_child(stones_spacer)

	var stones_label = Label.new()
	stones_label.text = "Culling Stones: %d" % inventory.get_culling_stone_count()
	stones_label.add_theme_font_size_override("font_size", 10)
	stones_label.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
	stones_hbox.add_child(stones_label)

	equipment_container.add_child(stones_hbox)

	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	equipment_container.add_child(grid)

	# Cards share the slot pool, so the grid draws max_storage_slots cells:
	# item cells (filled or empty) for whatever the cards don't occupy. A save
	# holding more than fits (from before the pool was shared) still shows
	# every item — caps only gate NEW pickups.
	var item_cells: int = maxi(inventory.get_stored_item_count(),
			inventory.max_storage_slots - inventory.get_stored_card_count())
	for i in range(item_cells):
		var cell = _create_storage_cell(i)
		grid.add_child(cell)

	# Show stored cards in the same grid
	for i in range(inventory.get_stored_card_count()):
		var card = inventory.get_stored_card(i)
		if card:
			var cell = _create_card_storage_cell(card, i)
			grid.add_child(cell)

func _create_storage_cell(index: int) -> PanelContainer:
	var cell = StorageItemCellScript.new()
	cell.custom_minimum_size = Vector2(62, 48)

	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3

	var item: ItemData = null
	if index < inventory.stored_items.size():
		item = inventory.stored_items[index]

	if item:
		style.bg_color = Color(0.18, 0.18, 0.25, 1.0)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.border_color = _get_item_type_color(item.item_type)
	else:
		style.bg_color = Color(0.1, 0.1, 0.12, 1.0)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.2, 0.2, 0.25)

	cell.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	cell.add_child(vbox)

	var type_label = Label.new()
	type_label.add_theme_font_size_override("font_size", 9)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var cell_name_label = Label.new()
	cell_name_label.add_theme_font_size_override("font_size", 10)
	cell_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	if item:
		type_label.text = item.get_type_name()
		type_label.add_theme_color_override("font_color", _get_item_type_color(item.item_type))
		cell_name_label.text = item.item_name
		cell_name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	else:
		type_label.text = ""
		cell_name_label.text = ""

	vbox.add_child(type_label)
	vbox.add_child(cell_name_label)

	# Enable drag (equip) from this cell and drop (unequip) onto it.
	cell.setup(self, index, item)

	return cell

func _create_card_storage_cell(card: Card, card_index: int) -> PanelContainer:
	var cell = PanelContainer.new()
	cell.custom_minimum_size = Vector2(62, 48)

	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.bg_color = Color(0.15, 0.12, 0.22, 1.0)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 0.84, 0.0)
	cell.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	cell.add_child(vbox)

	var type_label = Label.new()
	type_label.add_theme_font_size_override("font_size", 9)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.text = "Card"
	type_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))

	var cell_name_label = Label.new()
	cell_name_label.add_theme_font_size_override("font_size", 10)
	cell_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cell_name_label.text = card.card_name
	cell_name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

	cell.gui_input.connect(_on_card_cell_input.bind(card, card_index))
	cell.mouse_filter = Control.MOUSE_FILTER_STOP

	vbox.add_child(type_label)
	vbox.add_child(cell_name_label)

	return cell

func _on_card_cell_input(event: InputEvent, card: Card, card_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_card_cell_clicked(card, card_index)

func _on_card_cell_clicked(card: Card, card_index: int) -> void:
	if not inventory or not deck_manager:
		return
	_pending_card = card
	_pending_card_index = card_index
	_show_card_confirm_modal(card)

func _show_card_confirm_modal(card: Card) -> void:
	_dismiss_card_confirm_modal()

	_card_confirm_popup = PanelContainer.new()
	_card_confirm_popup.z_index = 200

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.95)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.84, 0.0)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_card_confirm_popup.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_card_confirm_popup.add_child(vbox)

	# Card name header
	var title = Label.new()
	title.text = "Add \"%s\" to deck?" % card.card_name
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Card info section
	var info_panel = PanelContainer.new()
	var info_style = StyleBoxFlat.new()
	info_style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	info_style.corner_radius_top_left = 4
	info_style.corner_radius_top_right = 4
	info_style.corner_radius_bottom_left = 4
	info_style.corner_radius_bottom_right = 4
	info_style.content_margin_left = 10
	info_style.content_margin_right = 10
	info_style.content_margin_top = 8
	info_style.content_margin_bottom = 8
	info_panel.add_theme_stylebox_override("panel", info_style)
	vbox.add_child(info_panel)

	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 4)
	info_panel.add_child(info_vbox)

	# Card type
	var type_label = Label.new()
	type_label.text = card.card_type_name
	type_label.add_theme_font_size_override("font_size", 11)
	type_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_vbox.add_child(type_label)

	# Mana / Tempo cost
	var cost_label = Label.new()
	cost_label.text = "%d Mana / %d Tempo" % [card.mana_cost, card.tempo_cost]
	cost_label.add_theme_font_size_override("font_size", 11)
	cost_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_vbox.add_child(cost_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = card.description
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size.x = 260
	info_vbox.add_child(desc_label)

	# Keywords / special properties
	var keywords := []
	if card.is_ranged:
		keywords.append(card.get_range_display())
	if card.is_aoe:
		keywords.append("AOE (%s)" % card.aoe_shape if card.aoe_shape != "" else "AOE")
	if card.has_burden:
		keywords.append("Burden")
	if card.sticky > 0:
		keywords.append("Sticky %d" % card.sticky)
	if card.glut_tempo > 0:
		keywords.append("Glut %d" % card.glut_tempo)
	if card.erase_tempo > 0:
		keywords.append("Erase %d" % card.erase_tempo)
	if card.delay_tempo > 0:
		keywords.append("Delay %d" % card.delay_tempo)
	if card.maintain_cost > 0:
		keywords.append("Maintain %d" % card.maintain_cost)
	if card.has_reach:
		keywords.append("Reach")
	if card.card_keyword != Card.CardKeyword.NONE:
		keywords.append(Card.CardKeyword.keys()[card.card_keyword].capitalize())

	if keywords.size() > 0:
		var kw_label = Label.new()
		kw_label.text = " | ".join(keywords)
		kw_label.add_theme_font_size_override("font_size", 10)
		kw_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
		kw_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kw_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		kw_label.custom_minimum_size.x = 260
		info_vbox.add_child(kw_label)

	# Warning text
	var warning = Label.new()
	warning.text = "Are you sure you want add this card?\nIt can not be removed until you use a culling stone."
	warning.add_theme_font_size_override("font_size", 11)
	warning.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.custom_minimum_size.x = 260
	vbox.add_child(warning)

	# Buttons
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var confirm_btn = Button.new()
	confirm_btn.text = "Add to Deck"
	confirm_btn.custom_minimum_size = Vector2(100, 30)
	confirm_btn.add_theme_font_size_override("font_size", 11)
	confirm_btn.pressed.connect(_on_card_confirm_yes)
	btn_row.add_child(confirm_btn)

	# Destroy — permanent, so the button itself asks twice.
	var destroy_btn = Button.new()
	destroy_btn.text = "Destroy"
	destroy_btn.custom_minimum_size = Vector2(90, 30)
	destroy_btn.add_theme_font_size_override("font_size", 11)
	destroy_btn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	destroy_btn.tooltip_text = "Permanently destroy this card."
	destroy_btn.pressed.connect(_on_card_destroy_pressed.bind(destroy_btn))
	btn_row.add_child(destroy_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 30)
	cancel_btn.add_theme_font_size_override("font_size", 11)
	cancel_btn.pressed.connect(_dismiss_card_confirm_modal)
	btn_row.add_child(cancel_btn)

	panel.add_child(_card_confirm_popup)

	# Center on panel
	await get_tree().process_frame
	if is_instance_valid(_card_confirm_popup) and is_instance_valid(panel):
		_card_confirm_popup.position = (panel.size - _card_confirm_popup.size) / 2

func _on_card_destroy_pressed(btn: Button) -> void:
	## Permanent, so it takes two clicks: the first arms the button.
	if not is_instance_valid(btn):
		return
	if btn.text != "Really destroy?":
		btn.text = "Really destroy?"
		return
	if _pending_card and _pending_card_index >= 0 and inventory:
		var card_name = _pending_card.card_name
		if inventory.remove_stored_card(_pending_card_index) != null:
			var main_node = get_node_or_null("/root/Main")
			if main_node and main_node.has_method("add_battle_log"):
				main_node.add_battle_log("Destroyed card: %s" % card_name, Color(1.0, 0.5, 0.4))
	_pending_card = null
	_pending_card_index = -1
	_dismiss_card_confirm_modal()
	update_display()

func _on_card_confirm_yes() -> void:
	if _pending_card and _pending_card_index >= 0 and inventory and deck_manager:
		var card_name = _pending_card.card_name
		if inventory.add_card_to_deck(_pending_card_index, deck_manager):
			var main_node = get_node_or_null("/root/Main")
			if main_node and main_node.has_method("add_battle_log"):
				main_node.add_battle_log("Added %s to deck!" % card_name, Color(0.4, 1.0, 0.5))
	_pending_card = null
	_pending_card_index = -1
	_dismiss_card_confirm_modal()
	update_display()

func _dismiss_card_confirm_modal() -> void:
	if is_instance_valid(_card_confirm_popup):
		_card_confirm_popup.queue_free()
	_card_confirm_popup = null

func _get_item_type_color(item_type: ItemData.ItemType) -> Color:
	match item_type:
		ItemData.ItemType.WEAPON:
			return Color(1.0, 0.4, 0.4)
		ItemData.ItemType.HELM, ItemData.ItemType.CHEST, ItemData.ItemType.BOOTS:
			return Color(0.4, 0.6, 1.0)
		ItemData.ItemType.RING:
			return Color(1.0, 0.85, 0.3)
		ItemData.ItemType.BELT:
			return Color(0.6, 0.45, 0.3)
		ItemData.ItemType.GAUNTLETS:
			return Color(0.9, 0.6, 0.2)
	return Color(0.5, 0.5, 0.5)
