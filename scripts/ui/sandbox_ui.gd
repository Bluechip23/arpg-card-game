class_name SandboxUI
extends CanvasLayer

## Sandbox control panel: a collapsible right-side window that lets the player
## add any card to their hand (sorted by the character it belongs to) and spawn
## any enemy (sorted by the realm/habitat it lives in). All the normal battle
## UI — inventory, stats, buff/debuff bars, enemy inspect pop-ups — keeps
## working alongside it, since sandbox is just the regular battle scene.

signal add_card_requested(card_id: String)
signal spawn_enemy_requested(enemy_type: int)
signal clear_enemies_requested
signal refill_requested
signal add_ally_requested(character_name: String)
signal grant_passive_requested(option)  # SkillTreeData.SkillOption

# card_id lists grouped by the character whose kit they belong to, matching
# the canonical cards-and-passives spreadsheet (each character owns their full
# kit; Core / Shared holds only the neutral cards everyone can find).
const CARD_GROUPS := {
	"Brad": ["approach", "armor_break", "armor_patch", "armored_discipline", "charge", "cover", "down_but_not_out", "give_in", "harden", "heavy_swing", "heroic_leap", "hold_the_line", "hunker_down", "internal_combustion", "life_steal", "life_swap", "living_armor", "morphine", "parry", "poke", "roar", "roll", "savage_strike", "shed_weight", "shield_slam", "smith_thy_soul", "succumb", "taunt", "the_lights_favor", "tower_shield", "turtle_up", "wear_down"],
	"Ryan": ["adrenaline_shot", "anticipation", "blade_barrage", "bloodlust", "elixir", "exacerbate_wounds", "gargle_and_spit", "item_mastery", "lethal_recall", "patience", "poisoned_blood", "premeditated", "preparation", "raged_circulation", "reposition", "shadows", "shuriken", "shuriken_pouch", "understanding", "volatile_mixture"],
	"Stephen": ["barricade", "bottomless_quiver", "collect_arrows", "down_town", "enchanted_quiver", "exhausted_assault", "last_breath", "lead_arrow", "mark", "mixed_bag", "multishot", "quick_arrow", "quick_shot", "reload", "rise", "sky_attack", "sky_fall", "specific_strike", "spirit_arrow", "tighten_string"],
	"Cory": ["absorb_essence", "bob_and_weave", "choke", "consecutive_snap", "defensive_awareness", "energy_ball", "energy_barrier", "exposed_artery", "meditate", "misery_loves_company", "potion_of_continuance", "push", "release_tension", "round_em_up", "swap", "sweeping_disarm", "trip", "vines"],
	"Jeremy": ["best_offense", "biscuit", "communal_donation", "cryonics", "deep_pockets", "demonic_rage", "fireball", "friendship", "god_of_thunder", "harness_lightning", "healthy_bliss", "hope_this_works", "house_money", "if_pigs_could_fly", "lady_luck", "loaded_die", "magic_barrier", "mana_surge", "meister_of_faustmesser", "mirror_mirror", "oops", "prepare", "provider", "risk_it", "shepherds_mark", "snowballs_chance", "spark", "surrounding_ice", "trick_shot", "try_this", "vengeful_shield", "worms_armageddon", "worst_that_could_happen"],
	"Core / Shared": ["blink", "block", "cultish_wounds", "dagger_throw", "discard", "draw", "empower", "enchantment_attack", "enchantment_defense", "enchantment_mana_regen", "enchantment_movement", "fortify_alliance", "fountain_of_life", "gain_mana", "gift_from_the_phoenix", "growth_within_resilience", "gulped_potion", "halo", "heal", "healing_potion", "healthy_habit", "hydra_bite", "lightly_dazed", "minor_wounds", "petey_the_pet_rock", "reckless_strike", "repelled_block", "self_infliction", "shield_of_growth", "shield_ready", "slash", "spider_senses", "thrown_stone"],
}
const CARD_GROUP_ORDER := ["Brad", "Ryan", "Stephen", "Cory", "Jeremy", "Core / Shared"]

# Enemy types grouped by realm/habitat (per STORY.md section 5).
var _enemy_groups: Dictionary = {}
var _enemy_group_order: Array = ["Sewer", "Graveyard", "Cave", "Forest", "Mountains", "Underworld", "Heavens", "Generic"]

var _panel: PanelContainer = null
var _toggle: Button = null
# Add Card and Add Passive share one player/character dropdown and swap between
# two tabs in the same slot.
var _char_dd: OptionButton = null
var _tab_card_btn: Button = null
var _tab_passive_btn: Button = null
var _active_tab: int = 0  # 0 = Add Card, 1 = Add Passive
var _card_list: VBoxContainer = null
var _card_scroll: ScrollContainer = null
var _passive_list: VBoxContainer = null
var _passive_scroll: ScrollContainer = null
var _enemy_realm_dd: OptionButton = null
var _enemy_list: VBoxContainer = null
var _ally_dd: OptionButton = null
var _ally_btn: Button = null
var _open: bool = false

const CHARACTER_ORDER := ["Brad", "Ryan", "Stephen", "Cory", "Jeremy"]

# Cached skill trees per character (built lazily for the passive picker).
var _trees: Dictionary = {}


func _ready() -> void:
	layer = 90
	_build_enemy_groups()
	_build_ui()
	_refresh_enemy_list()
	_set_tab(0)  # start on the Add Card tab


func _tree_for(char_name: String) -> SkillTreeData:
	if _trees.has(char_name):
		return _trees[char_name]
	var tree: SkillTreeData = null
	match char_name:
		"Brad": tree = SkillTreeData.create_brad_tree()
		"Ryan": tree = SkillTreeData.create_ryan_tree()
		"Stephen": tree = SkillTreeData.create_stephen_tree()
		"Cory": tree = SkillTreeData.create_cory_tree()
		"Jeremy": tree = SkillTreeData.create_jeremy_tree()
	_trees[char_name] = tree
	return tree


func _build_enemy_groups() -> void:
	var E := Enemy.EnemyType
	_enemy_groups = {
		"Sewer": [E.WERERAT, E.ARCHER_RAT, E.SLUDGE, E.PIPE_CRAWLER, E.SEWER_CROC, E.RAT_KING, E.SWARM],
		"Graveyard": [E.SKELETON, E.ZOMBIE, E.WEREWOLF, E.WERERABBIT, E.VAMPIRE, E.NECROMANCER, E.BONE_DRAGON, E.SPIRIT_COLLECTOR, E.GRAVE_TITAN, E.CRYPT_CRAWLER, E.SCREECHER, E.CONSUMED],
		"Cave": [E.ARMORED_TROLL, E.FIRE_GOBLIN_SOLDIER, E.FIRE_GOBLIN_MAGE, E.FIRE_GOBLIN_SHAMAN],
		"Forest": [E.GIANT_BEAVER, E.MINI_BEAR, E.LARGE_BEAR, E.WOLF, E.COYOTE, E.BUGBEAR, E.INFECTED_HUNTER, E.GIANT_HAWK, E.TREANT, E.ICE_MAGE, E.FIRE_MAGE, E.SPARK_MAGE, E.AIR_MAGE, E.EARTH_MAGE, E.HYDRA],
		"Mountains": [E.WEREGOAT, E.WYVERN, E.ROC, E.ICE_TROLL, E.SNOW_WRAITH, E.GRANITE_COLOSSUS, E.WHITE_MANTICORE, E.SABERTOOTH],
		"Underworld": [E.CERBERUS, E.SUCCUBUS, E.DEMON, E.IFRIT, E.MIND_EATER, E.SPECTER, E.MAGMA_SPIDER, E.PIT_FIEND, E.ASH_HARPY, E.INFLAMED_MINOTAUR],
		"Heavens": [E.CHERUB, E.DJINN, E.CORRUPTED_ARCHANGEL],
		"Generic": [E.MINION, E.ELITE, E.BOSS],
	}


func _pretty(id_or_enum) -> String:
	var s := str(id_or_enum)
	s = s.replace("_", " ")
	var words := s.split(" ")
	var out := ""
	for w in words:
		if w.length() > 0:
			out += w[0].to_upper() + w.substr(1).to_lower() + " "
	return out.strip_edges()


func _enemy_name(t: int) -> String:
	return _pretty(Enemy.EnemyType.keys()[t])


# =============================================================
# UI CONSTRUCTION
# =============================================================

func _build_ui() -> void:
	_toggle = Button.new()
	_toggle.text = "≡ Sandbox"
	_toggle.add_theme_font_size_override("font_size", 14)
	add_child(_toggle)
	# Sits LEFT of the battle-log column (which spans x -200..-8 on $UI) so
	# the log toggle underneath this CanvasLayer stays clickable in sandbox.
	_toggle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toggle.offset_left = -328.0
	_toggle.offset_top = 44.0
	_toggle.offset_right = -208.0
	_toggle.offset_bottom = 76.0
	_toggle.pressed.connect(_on_toggle)

	_panel = PanelContainer.new()
	add_child(_panel)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.09, 0.13, 0.96)
	st.border_width_left = 2
	st.border_width_top = 2
	st.border_width_bottom = 2
	st.border_width_right = 2
	st.border_color = Color(0.4, 0.55, 0.7)
	st.corner_radius_top_left = 6
	st.corner_radius_bottom_left = 6
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", st)
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -300.0
	_panel.offset_top = 82.0
	_panel.offset_right = -8.0
	# Stretch to the bottom of the screen — the panel now holds four sections.
	_panel.anchor_bottom = 1.0
	_panel.offset_bottom = -8.0
	_panel.visible = false

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "SANDBOX"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vbox.add_child(title)

	# ---- Add Card / Add Passive (tabbed, one shared player dropdown) ----
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	vbox.add_child(tab_row)
	_tab_card_btn = Button.new()
	_tab_card_btn.text = "Add Card"
	_tab_card_btn.toggle_mode = true
	_tab_card_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_card_btn.pressed.connect(func(): _set_tab(0))
	tab_row.add_child(_tab_card_btn)
	_tab_passive_btn = Button.new()
	_tab_passive_btn.text = "Add Passive"
	_tab_passive_btn.toggle_mode = true
	_tab_passive_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_passive_btn.pressed.connect(func(): _set_tab(1))
	tab_row.add_child(_tab_passive_btn)

	# One shared player/character dropdown drives whichever tab is active.
	_char_dd = OptionButton.new()
	for g in CARD_GROUP_ORDER:
		_char_dd.add_item(g)
	_char_dd.item_selected.connect(func(_i): _refresh_active_tab())
	vbox.add_child(_char_dd)

	# Add Card list.
	_card_scroll = ScrollContainer.new()
	_card_scroll.custom_minimum_size = Vector2(0, 180)
	_card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_card_scroll)
	_card_list = VBoxContainer.new()
	_card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_list.add_theme_constant_override("separation", 2)
	_card_scroll.add_child(_card_list)

	# Add Passive list (same slot, shown when the Passive tab is active).
	_passive_scroll = ScrollContainer.new()
	_passive_scroll.custom_minimum_size = Vector2(0, 180)
	_passive_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_passive_scroll)
	_passive_list = VBoxContainer.new()
	_passive_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_passive_list.add_theme_constant_override("separation", 2)
	_passive_scroll.add_child(_passive_list)

	vbox.add_child(HSeparator.new())

	# ---- Spawn Enemy section ----
	vbox.add_child(_header("Spawn Enemy"))
	_enemy_realm_dd = OptionButton.new()
	for g in _enemy_group_order:
		_enemy_realm_dd.add_item(g)
	_enemy_realm_dd.item_selected.connect(func(_i): _refresh_enemy_list())
	vbox.add_child(_enemy_realm_dd)
	var enemy_scroll := ScrollContainer.new()
	enemy_scroll.custom_minimum_size = Vector2(0, 130)
	enemy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(enemy_scroll)
	_enemy_list = VBoxContainer.new()
	_enemy_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_list.add_theme_constant_override("separation", 2)
	enemy_scroll.add_child(_enemy_list)

	vbox.add_child(HSeparator.new())

	# ---- Add Ally section (for testing ally-targeting cards) ----
	vbox.add_child(_header("Add Ally"))
	var ally_row := HBoxContainer.new()
	ally_row.add_theme_constant_override("separation", 6)
	vbox.add_child(ally_row)
	_ally_dd = OptionButton.new()
	_ally_dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for n in CHARACTER_ORDER:
		_ally_dd.add_item(n)
	ally_row.add_child(_ally_dd)
	_ally_btn = Button.new()
	_ally_btn.text = "Spawn"
	_ally_btn.pressed.connect(func():
		add_ally_requested.emit(CHARACTER_ORDER[_ally_dd.selected]))
	ally_row.add_child(_ally_btn)

	vbox.add_child(HSeparator.new())

	# ---- Utility buttons ----
	var clear_btn := Button.new()
	clear_btn.text = "Clear All Enemies"
	clear_btn.pressed.connect(func(): clear_enemies_requested.emit())
	vbox.add_child(clear_btn)
	var refill_btn := Button.new()
	refill_btn.text = "Refill Health & Mana"
	refill_btn.pressed.connect(func(): refill_requested.emit())
	vbox.add_child(refill_btn)


func mark_ally_added() -> void:
	## Called by Main once an ally is on the field — only one ally is supported.
	if _ally_btn:
		_ally_btn.disabled = true
		_ally_btn.text = "Added"


func _set_tab(tab: int) -> void:
	## Switch between the Add Card and Add Passive tabs (they share the player
	## dropdown and the list slot).
	_active_tab = tab
	if _tab_card_btn:
		_tab_card_btn.button_pressed = (tab == 0)
		_tab_card_btn.add_theme_color_override("font_color",
			Color(1.0, 0.95, 0.7) if tab == 0 else Color(0.6, 0.6, 0.66))
	if _tab_passive_btn:
		_tab_passive_btn.button_pressed = (tab == 1)
		_tab_passive_btn.add_theme_color_override("font_color",
			Color(1.0, 0.95, 0.7) if tab == 1 else Color(0.6, 0.6, 0.66))
	if _card_scroll:
		_card_scroll.visible = (tab == 0)
	if _passive_scroll:
		_passive_scroll.visible = (tab == 1)
	_refresh_active_tab()


func _refresh_active_tab() -> void:
	if _active_tab == 0:
		_refresh_card_list()
	else:
		_refresh_passive_list()


func _refresh_passive_list() -> void:
	if not _passive_list:
		return
	for c in _passive_list.get_children():
		c.queue_free()
	var char_name: String = CARD_GROUP_ORDER[_char_dd.selected] if _char_dd else "Brad"
	var tree := _tree_for(char_name)
	if tree == null:
		# e.g. "Core / Shared" — not a character with a passive tree.
		var note := Label.new()
		note.text = "No passives for %s." % char_name
		note.add_theme_font_size_override("font_size", 12)
		note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66))
		_passive_list.add_child(note)
		return
	var seen := {}
	for row in tree.rows:
		for opt in row.options:
			if opt.option_type != SkillTreeData.OptionType.PASSIVE:
				continue
			if seen.has(opt.name):
				continue
			seen[opt.name] = true
			var btn := Button.new()
			btn.text = "L%d  %s" % [row.level, opt.name]
			btn.tooltip_text = opt.description
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_font_size_override("font_size", 12)
			btn.pressed.connect(func(): grant_passive_requested.emit(opt))
			_passive_list.add_child(btn)


func _header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.85, 0.82, 0.6))
	return l


func _refresh_card_list() -> void:
	if not _card_list:
		return
	for c in _card_list.get_children():
		c.queue_free()
	var group: String = CARD_GROUP_ORDER[_char_dd.selected]
	for card_id in CARD_GROUPS[group]:
		var btn := Button.new()
		btn.text = _pretty(card_id)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(func(): add_card_requested.emit(card_id))
		_card_list.add_child(btn)


func _refresh_enemy_list() -> void:
	if not _enemy_list:
		return
	for c in _enemy_list.get_children():
		c.queue_free()
	var realm: String = _enemy_group_order[_enemy_realm_dd.selected]
	for t in _enemy_groups[realm]:
		var btn := Button.new()
		btn.text = _enemy_name(t)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(func(): spawn_enemy_requested.emit(t))
		_enemy_list.add_child(btn)


func _on_toggle() -> void:
	_open = not _open
	_panel.visible = _open
	_toggle.text = "≡ Sandbox ▸" if _open else "≡ Sandbox"


func open() -> void:
	_open = true
	if _panel:
		_panel.visible = true
