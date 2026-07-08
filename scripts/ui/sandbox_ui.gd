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

# card_id lists grouped by the character whose kit they belong to.
const CARD_GROUPS := {
	"Brad": ["life_swap", "wear_down", "taunt", "life_steal", "roar", "poke", "armor_break", "charge", "heroic_leap", "morphine", "turtle_up", "parry", "approach", "hold_the_line"],
	"Ryan": ["raged_circulation", "poisoned_blood", "elixir", "shadows", "preparation", "exacerbate_wounds", "reposition", "volatile_mixture", "understanding", "shuriken_pouch", "shuriken", "premeditated"],
	"Stephen": ["mark", "rise", "quick_shot", "reload", "enchanted_quiver", "tighten_string", "down_town", "barricade", "sky_fall", "sky_attack", "lead_arrow", "last_breath", "mixed_bag", "quick_arrow", "bottomless_quiver"],
	"Cory": ["round_em_up", "trip", "choke", "push", "defensive_awareness", "sweeping_disarm", "consecutive_snap", "swap", "meditate"],
	"Jeremy": ["trick_shot", "surrounding_ice", "risk_it", "biscuit", "loaded_die", "worst_that_could_happen", "oops", "house_money", "hope_this_works", "lady_luck", "try_this", "if_pigs_could_fly", "snowballs_chance", "mana_surge", "magic_barrier", "shepherds_mark"],
	"Core / Shared": ["slash", "block", "heal", "draw", "discard", "gain_mana", "empower", "blink", "healing_potion", "dagger_throw", "thrown_stone", "spider_senses", "gulped_potion", "reckless_strike", "halo", "armored_discipline", "fountain_of_life", "blade_barrage", "cultish_wounds", "self_infliction", "bob_and_weave", "absorb_essence", "energy_ball", "cover", "fortify_alliance", "communal_donation", "shield_ready", "repelled_block", "shield_of_growth", "gift_from_the_phoenix", "bloodlust", "lethal_recall", "demonic_rage", "smith_thy_soul", "down_but_not_out", "anticipation", "prepare", "meister_of_faustmesser", "item_mastery", "mirror_mirror", "harness_lightning", "deep_pockets", "best_offense", "vengeful_shield", "heavy_swing", "specific_strike", "hydra_bite", "spark", "savage_strike", "shield_slam", "exposed_artery", "tower_shield", "harden", "hunker_down", "energy_barrier", "the_lights_favor", "healthy_habit", "gargle_and_spit", "living_armor", "multishot", "exhausted_assault", "provider", "give_in", "shed_weight", "fireball", "spirit_arrow", "internal_combustion", "god_of_thunder", "patience", "succumb", "adrenaline_shot", "vines", "release_tension", "roll", "misery_loves_company", "cryonics", "friendship", "worms_armageddon"],
}
const CARD_GROUP_ORDER := ["Brad", "Ryan", "Stephen", "Cory", "Jeremy", "Core / Shared"]

# Enemy types grouped by realm/habitat (per STORY.md section 5).
var _enemy_groups: Dictionary = {}
var _enemy_group_order: Array = ["Sewer", "Graveyard", "Cave", "Forest", "Mountains", "Underworld", "Heavens", "Generic"]

var _panel: PanelContainer = null
var _toggle: Button = null
var _card_player_dd: OptionButton = null
var _card_list: VBoxContainer = null
var _enemy_realm_dd: OptionButton = null
var _enemy_list: VBoxContainer = null
var _ally_dd: OptionButton = null
var _ally_btn: Button = null
var _passive_char_dd: OptionButton = null
var _passive_list: VBoxContainer = null
var _open: bool = false

const CHARACTER_ORDER := ["Brad", "Ryan", "Stephen", "Cory", "Jeremy"]

# Cached skill trees per character (built lazily for the passive picker).
var _trees: Dictionary = {}


func _ready() -> void:
	layer = 90
	_build_enemy_groups()
	_build_ui()
	_refresh_card_list()
	_refresh_enemy_list()
	_refresh_passive_list()


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
	_toggle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toggle.offset_left = -128.0
	_toggle.offset_top = 44.0
	_toggle.offset_right = -8.0
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

	# ---- Add Card section ----
	vbox.add_child(_header("Add Card to Hand"))
	_card_player_dd = OptionButton.new()
	for g in CARD_GROUP_ORDER:
		_card_player_dd.add_item(g)
	_card_player_dd.item_selected.connect(func(_i): _refresh_card_list())
	vbox.add_child(_card_player_dd)
	var card_scroll := ScrollContainer.new()
	card_scroll.custom_minimum_size = Vector2(0, 150)
	card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(card_scroll)
	_card_list = VBoxContainer.new()
	_card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_list.add_theme_constant_override("separation", 2)
	card_scroll.add_child(_card_list)

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

	# ---- Grant Passive section ----
	vbox.add_child(_header("Grant Passive"))
	_passive_char_dd = OptionButton.new()
	for n in CHARACTER_ORDER:
		_passive_char_dd.add_item(n)
	_passive_char_dd.item_selected.connect(func(_i): _refresh_passive_list())
	vbox.add_child(_passive_char_dd)
	var passive_scroll := ScrollContainer.new()
	passive_scroll.custom_minimum_size = Vector2(0, 150)
	passive_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(passive_scroll)
	_passive_list = VBoxContainer.new()
	_passive_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_passive_list.add_theme_constant_override("separation", 2)
	passive_scroll.add_child(_passive_list)

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


func _refresh_passive_list() -> void:
	if not _passive_list:
		return
	for c in _passive_list.get_children():
		c.queue_free()
	var char_name: String = CHARACTER_ORDER[_passive_char_dd.selected] if _passive_char_dd else "Brad"
	var tree := _tree_for(char_name)
	if tree == null:
		return
	var seen := {}
	for row in tree.rows:
		for opt in row.options:
			if opt.option_type != SkillTreeData.OptionType.PASSIVE and opt.option_type != SkillTreeData.OptionType.PASSIVE_MUTATION:
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
	var group: String = CARD_GROUP_ORDER[_card_player_dd.selected]
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
