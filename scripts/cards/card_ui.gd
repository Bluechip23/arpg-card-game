class_name CardUI
extends PanelContainer

## Visual representation of a card in hand with tween animations


@onready var name_label: Label = $Panel/VBox/TitleBar/TitleHBox/NameLabel
@onready var type_label: Label = $Panel/VBox/TypeBar/TypeHBox/TypeLabel
@onready var range_label: Label = $Panel/VBox/TypeBar/TypeHBox/RangeLabel
@onready var desc_label: RichTextLabel = $Panel/VBox/DescPanel/DescLabel
@onready var cost_label: Label = $Panel/VBox/TitleBar/TitleHBox/CostLabel
@onready var title_bar: PanelContainer = $Panel/VBox/TitleBar
@onready var type_bar: PanelContainer = $Panel/VBox/TypeBar
@onready var art_box: PanelContainer = $Panel/VBox/ArtBox
@onready var desc_panel: PanelContainer = $Panel/VBox/DescPanel

var _art_rect: TextureRect = null

var _card: Card
var _index: int
var _selected: bool = false
var _is_hexed: bool = false
var _is_locked: bool = false
var _is_hovered: bool = false
var _base_y: float = 0.0
var _base_x: float = 0.0
var _base_z: int = 0
var _base_rotation: float = 0.0  # Fan rotation angle

# Animation
var _hover_tween: Tween = null
var _is_animating_out: bool = false  # True while play/discard animation runs

const CARD_W: float = 150.0

## Installed by the battle scene: Callable(card) -> {damage/block/heal:int}
## with the holder's stat-adjusted values, used to print effective numbers on
## the card face. Invalid (unset) = show authored base values.
static var value_provider: Callable = Callable()
const CARD_H: float = 210.0
const HOVER_LIFT: float = 68.0
const SELECT_LIFT: float = 96.0
const TWEEN_DURATION: float = 0.12

# MtG-style frame colour per card type (border, title/type bars, art tint).
var _type_color: Color = Color(0.45, 0.45, 0.55)

## The designer's painted frames (tools/cut_card_frames.py, 2026-10-30),
## picked by frame_for(). Each says where its texture sits over the 150x210
## card ("rect": the board's card rectangle maps onto the card, its drop,
## hourglass and ornaments hanging outside it) and where its painting puts
## things, in card pixels: the cost numbers' centres on the painted drop and
## hourglass, the tempo dots' row, the logo's ring, the rules text's box
## (clear of the corner picture) and its ink. A card no frame claims keeps
## the drawn frame.
const FRAMES := {
	# Instants: gilt and feathers, ink on parchment above a ducking hero.
	"instant": {
		"tex": "res://assets/textures/cards/frame_instant.png",
		"rect": Rect2(-5.7, -18.3, 161.8, 242.0),
		"mana_at": Vector2(14.1, 12.5),
		"tempo_at": Vector2(136.2, 12.3),
		"dots_y": 7.1,
		"logo_at": Vector2(74.7, 109.7),
		"desc_box": Vector2(116.1, 39.4),
		"desc_right": 3.9,
		"ink": Color(0.16, 0.1, 0.05),
		"ink_dark": true,
		"top": 13.1, "title_h": 22.8, "art_h": 66.4, "type_h": 18.7, "desc_top": 4.2,
		"title_left": 21.0, "title_right": 15.9, "name_w": 86,
		"art_margins": [2, 0.5, 1, 0.5],   # the painted window inside the art box (left, top, right, bottom)
	},
	# Every card with an upkeep: amethyst-shot stone, white text beside the
	# mind-mage in the corner.
	"maintain": {
		"tex": "res://assets/textures/cards/frame_maintain.png",
		"rect": Rect2(-5.2, -11.7, 160.8, 235.5),
		"mana_at": Vector2(14.8, 16.0),
		"tempo_at": Vector2(135.4, 15.8),
		"dots_y": 11.9,
		"logo_at": Vector2(74.3, 111.9),
		"desc_box": Vector2(81.9, 46.7),
		"desc_right": 37.1,
		"ink": Color(0.96, 0.94, 0.9),
		"ink_dark": false,
		"top": 18.9, "title_h": 22.4, "art_h": 65.0, "type_h": 18.3, "desc_top": 4.1,
		"title_left": 21.0, "title_right": 16.1, "name_w": 86,
		"art_margins": [0.5, 0.5, 1.5, 1.5],   # the painted window inside the art box (left, top, right, bottom)
	},
	# Defense cards: a stone wall veined with blue lightning, white text left
	# of the knight catching arrows on his shield.
	"defensive": {
		"tex": "res://assets/textures/cards/frame_defensive.png",
		"rect": Rect2(-3.6, -4.7, 157.2, 222.1),
		"mana_at": Vector2(18.2, 22.3),
		"tempo_at": Vector2(133.9, 21.3),   # on the Instant card's hourglass, set over the board's own
		"dots_y": 18.3,
		"dots_span": Vector2(56.2, 93.7),   # between the banners
		"logo_at": Vector2(74.6, 113.4),
		"desc_box": Vector2(69.1, 40.7),
		"desc_right": 50.2,
		"ink": Color(0.96, 0.94, 0.9),
		"ink_dark": false,
		"top": 24.0, "title_h": 21.3, "art_h": 62.0, "type_h": 17.4, "desc_top": 3.9,
		"title_left": 21.4, "title_right": 16.7, "name_w": 85,
		"art_margins": [3.5, 0.5, 5, 2],   # the painted window inside the art box (left, top, right, bottom)
	},
	# Utility cards: green scale-work wound with ivy. No type bar of its
	# own: a taller art window, the logo set where the window meets the
	# rules box with the type words either side of it at the box's top, and
	# white text left of the pack and potions. Standard drop and hourglass.
	"utility": {
		"tex": "res://assets/textures/cards/frame_utility.png",
		"rect": Rect2(-5.1, -7.8, 160.6, 228.8),
		"mana_at": Vector2(17.5, 24.3),
		"tempo_at": Vector2(133.2, 18.7),
		"dots_y": 16.4,
		"logo_at": Vector2(75.0, 128.6),
		"desc_box": Vector2(63.8, 43.4),
		"desc_right": 55.9,
		"desc_full": Vector2(115.6, 45.3),
		"ink": Color(0.96, 0.94, 0.9),
		"ink_dark": false,
		# The sections' heights down the card: name bar from top, art window,
		# type line; the rules box takes the rest.
		"top": 21.2, "title_h": 21.7, "art_h": 83.8, "type_h": 18.7, "desc_top": 3.9,
		"title_left": 21.2, "title_right": 16.1, "name_w": 86,
	},
	# Attack cards: blood-red iron and steel spikes, a bloodied great-axe down
	# the left, white text beside a roaring berserker. Its emblem painted out
	# for the game's logo, standard drop and hourglass. The board ran taller
	# than a card: its art window was squeezed (tools/cut_card_frames.py),
	# so the window is a little shorter here. The name starts right of the
	# axe head.
	"attack": {
		"tex": "res://assets/textures/cards/frame_attack.png",
		"rect": Rect2(-11.1, -16.6, 168.6, 257.4),
		"mana_at": Vector2(16.0, 24.9),
		"tempo_at": Vector2(133.2, 21.4),
		"dots_y": 18.7,
		"dots_span": Vector2(52.1, 117.9),  # right of the axe head
		"logo_at": Vector2(75.8, 111.2),
		"desc_box": Vector2(71.8, 40.1),
		"desc_right": 48.0,
		"desc_full": Vector2(115.7, 56.2),
		"ink": Color(0.96, 0.94, 0.9),
		"ink_dark": false,
		"top": 26.8, "title_h": 24.1, "art_h": 51.2, "type_h": 24.1, "desc_top": 9.0,
		"title_left": 37.1, "title_right": 20.1, "name_w": 67,
		"art_margins": [9.5, 0.5, 0.5, 0.5],   # the painted window inside the art box (left, top, right, bottom)
		# The frame with no drop or hourglass painted on (cut_card_frames.py
		# --bare attack), for face_layout: the badges drawn over it at any
		# size, its bands resized. drop / glass: each badge's art on the
		# painted frame; *_band: the plain insides of the tempo strip, the
		# name bar, the art window and the type bar (card y).
		"bare": {
			"tex": "res://assets/textures/cards/frame_attack_bare.png",
			"drop": Rect2(2.0, -3.6, 28.3, 44.7),
			"glass": Rect2(118.5, -0.7, 30.8, 45.1),
			"dots_band": Vector2(8.5, 23.5),
			"title_band": Vector2(28.0, 44.5),
			"art_band": Vector2(55.0, 99.0),
			"type_band": Vector2(109.5, 123.0),
		},
	},
	# Spell cards: blackened stone veined with molten red, a fire comet
	# round the top-left, a wizard calling down meteors in the rules box. The
	# standard drop (over the comet's tail) and hourglass, the logo in the
	# type bar's middle. Squeezed like the Attack board.
	"spell": {
		"tex": "res://assets/textures/cards/frame_spell.png",
		"rect": Rect2(-13.7, -15.8, 169.2, 256.5),
		"mana_at": Vector2(14.6, 25.1),
		"tempo_at": Vector2(131.2, 22.7),
		"dots_y": 19.6,
		"dots_span": Vector2(54.1, 116.1),   # right of the comet
		"logo_at": Vector2(75.1, 117.5),
		"desc_box": Vector2(78.1, 40.0),
		"desc_right": 41.9,
		"desc_full": Vector2(116.1, 56.0),
		"ink": Color(0.96, 0.94, 0.9),
		"ink_dark": false,
		"top": 27.5, "title_h": 24.0, "art_h": 51.0, "type_h": 24.0, "desc_top": 9.0,
		"title_left": 40.1, "title_right": 19.9, "name_w": 62,
		"art_margins": [8.5, 0.5, 1, 1],   # the painted window inside the art box (left, top, right, bottom)
	},
	# Offensive cards that are not only an attack or only a spell (designer,
	# 2026-11-11): cracked ruby crystal round dark leather, a knight, a fire
	# mage and an archer attacking together in the rules box. The standard
	# drop set over its blood drop, its own hourglass, the logo in the type
	# bar's middle. Squeezed like the Attack board.
	"offensive": {
		"tex": "res://assets/textures/cards/frame_offensive.png",
		"rect": Rect2(-4.0, -12.1, 158.4, 244.9),
		"mana_at": Vector2(18.7, 24.2),
		"tempo_at": Vector2(132.3, 24.2),
		"dots_y": 18.7,
		"dots_span": Vector2(38.0, 118.8),  # between the drop and the hourglass
		"logo_at": Vector2(75.1, 114.0),
		"desc_box": Vector2(60.0, 40.0),
		"desc_right": 60.0,
		"desc_full": Vector2(115.7, 56.2),
		"ink": Color(0.96, 0.94, 0.9),
		"ink_dark": false,
		"top": 28.3, "title_h": 22.9, "art_h": 52.9, "type_h": 21.5, "desc_top": 10.0,
		"title_left": 33.0, "title_right": 27.0, "name_w": 70,
	},
	# Enchantments: green cracked-emerald stone in gilt and gold thorns,
	# jewelled chains off the drop's ring, white text above a hooded figure
	# reaching for a ruby on an altar. Its own drop and hourglass; its type
	# bar's ruby painted out for the logo. The board ran taller than a card:
	# its art window was squeezed harder than the Attack one's, so the window
	# is shorter here and the rules box roomier. The dots sit between the
	# chains' pendants.
	"enchantment": {
		"tex": "res://assets/textures/cards/frame_enchantment.png",
		"rect": Rect2(-3.7, -6.8, 159.0, 228.9),
		"mana_at": Vector2(21.3, 28.2),
		"tempo_at": Vector2(133.3, 28.4),
		"dots_y": 24.2,
		"dots_span": Vector2(50.3, 104.4),  # between the chains' pendants
		"logo_at": Vector2(75.8, 103.9),
		"desc_box": Vector2(66.0, 40.0),
		"desc_right": 52.5,
		"desc_full": Vector2(115.6, 56.0),
		"ink": Color(0.96, 0.94, 0.9),
		"ink_dark": false,
		"top": 34.6, "title_h": 19.1, "art_h": 39.4, "type_h": 20.9, "desc_top": 8.0,
		"title_left": 30.4, "title_right": 21.0, "name_w": 72,
		"art_margins": [11.5, 2.5, 7, 0.5],   # the painted window inside the art box (left, top, right, bottom)
	},
}
## How strongly the rules box is washed over its corner picture (0 = the
## picture at full strength, 1 = hidden). See _style_painted_frame.
static var text_wash_alpha: float = 0.5
const TEXT_WASH_DARK := Color(0.03, 0.03, 0.04)
const TEXT_WASH_PARCHMENT := Color(0.93, 0.87, 0.72)
const TEXT_WASH_PAD := 2.5   # how far the wash reaches past the text, card pixels
const FRAMED_DOT := 8.0
const FRAMED_LOGO_SIZE := 48
const FRAMED_NAME := Color(0.97, 0.92, 0.8)    # the name's cream
const MAINTAIN_WORD := Color(0.88, 0.36, 0.95)  # the Maintain board's magenta
const UPKEEP_RIGHT := 124.0                     # the upkeep's right edge, short of the hourglass
## A rules text too long for its frame's box beside the corner picture
## takes the box's whole width (over the picture), this tall.
const FRAMED_DESC_FULL := Vector2(116, 78)
const FRAMED_DESC_FULL_MAX := 9   # ... no bigger than this, so it covers as little of the picture as it can

## The face's layout under test (designer, 2026-11-15). Empty = the frames
## as cut. On a frame with a "bare" cut it takes:
##   width     the card's width (150 as cut); the frame stretches across,
##             the drop and hourglass keep their shape
##   badge     the drop's and hourglass's size (1 = as painted)
##   dots_k    the tempo strip's inside, this much of its height (the rest
##             goes to the name bar)
##   type_k    the type bar's inside likewise (the rest to the art window)
##   title_left  the name's left margin (it may run onto the axe)
##   title_rows  2: a long name wraps onto a second row, centred, smaller
##             if it must, instead of ending in "..."
static var face_layout := {}

var _kx := 1.0
var _ysegs: Array = []   # [[y0, y1, new_height], ...] down the card, base card px

func _laid_out() -> bool:
	return not face_layout.is_empty() and _frame.has("bare")

## A base-card y on the laid-out face.
func _my(y: float) -> float:
	var shift := 0.0
	for seg in _ysegs:
		var y0: float = seg[0]
		var y1: float = seg[1]
		var n: float = seg[2]
		if y <= y0:
			break
		if y < y1:
			return y0 + shift + (y - y0) * n / (y1 - y0)
		shift += n - (y1 - y0)
	return y + shift

## A base-card point on the laid-out face (x stretches with the width).
func _mp(p: Vector2) -> Vector2:
	return Vector2(p.x * _kx, _my(p.y))

func _build_layout() -> void:
	_kx = 1.0
	_ysegs = []
	if not _laid_out():
		return
	var b: Dictionary = _frame["bare"]
	_kx = float(face_layout.get("width", CARD_W)) / CARD_W
	var dots: Vector2 = b["dots_band"]
	var title: Vector2 = b["title_band"]
	var art: Vector2 = b["art_band"]
	var typ: Vector2 = b["type_band"]
	var dots_h: float = (dots.y - dots.x) * float(face_layout.get("dots_k", 1.0))
	var type_h: float = (typ.y - typ.x) * float(face_layout.get("type_k", 1.0))
	_ysegs = [
		[dots.x, dots.y, dots_h],
		[title.x, title.y, (title.y - title.x) + (dots.y - dots.x) - dots_h],
		[art.x, art.y, (art.y - art.x) + (typ.y - typ.x) - type_h],
		[typ.x, typ.y, type_h],
	]

## The frame drawn in bands, each stretched to its laid-out height.
func _draw_frame_bands(host: Control) -> void:
	var holder: Control = host.get_node_or_null("FrameBands")
	if holder == null:
		holder = Control.new()
		holder.name = "FrameBands"
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(holder)
		host.move_child(holder, 0)
	for c in holder.get_children():
		c.queue_free()
	var tex: Texture2D = load(_frame["bare"]["tex"])
	var r: Rect2 = _frame["rect"]
	var ty := float(tex.get_height()) / r.size.y
	var cuts: Array = [r.position.y]
	for seg in _ysegs:
		cuts.append(seg[0])
		cuts.append(seg[1])
	cuts.append(r.end.y)
	for i in range(cuts.size() - 1):
		var a: float = cuts[i]
		var bb: float = cuts[i + 1]
		if bb <= a:
			continue
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(0, (a - r.position.y) * ty, tex.get_width(), (bb - a) * ty)
		var tr := TextureRect.new()
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.texture = at
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tr.position = Vector2(r.position.x * _kx, _my(a))
		tr.size = Vector2(r.size.x * _kx, _my(bb) - _my(a))
		holder.add_child(tr)

## A badge texture cropped to its art (the png's clear margin dropped).
static var _badge_art := {}
static func _badge_atlas(path: String) -> Texture2D:
	if _badge_art.has(path):
		return _badge_art[path]
	var tex: Texture2D = load(path)
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(tex.get_image().get_used_rect())
	_badge_art[path] = at
	return at

## The painted frame a card wears: Maintain for any card with an upkeep
## (whatever its type), Instant for the instants, Enchantment for the
## enchantments, Spell for every spell;
## then by type — Instant, Defense, Utility — and the Attack shape
## (is_attack(), never an offensive spell); {} for the drawn frame.
static func frame_for(card: Card) -> Dictionary:
	if card == null:
		return {}
	if card.maintain_cost > 0:
		return FRAMES["maintain"]
	# An instant is an instant first, spell or not (Healthy Bliss).
	if card.card_type == Card.CardType.REACTION:
		return FRAMES["instant"]
	# Enchantment is its own family on the card web (docs/CARD_TAXONOMY.md),
	# beside Playable and Instant: held, never played. Like an instant it
	# wears its own frame whatever tags it carries, spell included; only an
	# upkeep (the Maintain ruling, "whatever its type") outranks it.
	if card.card_type == Card.CardType.ENCHANTMENT:
		return FRAMES["enchantment"]
	# An offensive card that is not only an attack or only a spell wears the
	# Offensive frame (designer, 2026-11-11): the sheet's plain "Offensive"
	# rows, and the cards tagged attack and spell at once.
	if card.is_mixed_offensive():
		return FRAMES["offensive"]
	# Spells are their own family (designer, 2026-10-30): an offensive spell
	# is stored as an Attack-type card, but it wears the Spell frame, never
	# the Attack one — and so does a utility spell.
	if card.school == Card.CardSchool.SPELL:
		return FRAMES["spell"]
	match card.card_type:
		Card.CardType.DEFENSE:
			return FRAMES["defensive"]
		Card.CardType.UTILITY:
			return FRAMES["utility"]
	if card.is_attack():
		return FRAMES["attack"]
	return {}

var _frame: Dictionary = {}
var _frame_art: TextureRect = null

func setup(card: Card, index: int, debuff_mgr: DebuffManager = null, dex_proc_active: bool = false, pocket_knife: bool = false, greedy_tax: Dictionary = {}) -> void:
	_card = card
	_index = index

	if name_label:
		name_label.text = card.card_name
		_fit_name()

	if type_label:
		type_label.text = card.card_type_name
		# Not only an attack or only a spell: the type line says so.
		if card.is_mixed_offensive():
			type_label.text = "Offensive"
		match card.card_type:
			Card.CardType.ATTACK:
				type_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
				_type_color = Color(0.72, 0.25, 0.22)
			Card.CardType.DEFENSE:
				type_label.add_theme_color_override("font_color", Color(0.3, 0.5, 1))
				_type_color = Color(0.25, 0.4, 0.72)
			Card.CardType.UTILITY:
				type_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
				_type_color = Color(0.25, 0.6, 0.32)
			Card.CardType.REACTION:
				type_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
				_type_color = Color(0.75, 0.6, 0.15)
			Card.CardType.UNPLAYABLE:
				type_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
				_type_color = Color(0.4, 0.4, 0.44)
			Card.CardType.POWER:
				type_label.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
				_type_color = Color(0.5, 0.3, 0.68)
			Card.CardType.ENCHANTMENT:
				type_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.8))
				_type_color = Color(0.18, 0.58, 0.55)
		_frame = frame_for(card)
		_style_frame()

	if range_label:
		# Stays visible (empty when melee) so the TO seal between the type and
		# range labels remains centred on the bar.
		range_label.visible = true
		range_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if card.is_ranged or card.conditional_range:
			# Conditional cards show the keyword alone (the legend explains the reach).
			range_label.text = card.get_range_display()
			range_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.9))
		else:
			range_label.text = ""

	_update_description()

	# Calculate displayed mana cost with debuff modifiers
	var display_mana = maxi(0, card.mana_cost - card.temp_mana_discount)  # timed passive discount
	# In-hand tempo cuts (Boots of Speed, Spark, Keep Them Guessing, Clean
	# Exchange) show on the card while they last.
	var display_tempo = maxi(0, card.tempo_cost + card.get_conditional_tempo_penalty() - card.temp_hand_tempo_reduction)
	# Heavy Greedy Cheese in the hand: its surcharge shows on every other card.
	display_mana += int(greedy_tax.get("mana", 0))
	display_tempo += int(greedy_tax.get("tempo", 0))
	var is_hexed = false
	var is_locked = false
	var is_dex_proc = false

	# Dex proc preview: show reduced mana and half tempo for attack cards
	if dex_proc_active and card.is_attack():  # the DEX proc is for attacks, not spells
		display_mana = max(0, display_mana - 20)  # the proc's real discount (x10 mana scale)
		display_tempo = display_tempo / 2
		# Pocket Knife: additional -2 tempo and resolve on first tick
		if pocket_knife:
			display_tempo = maxi(0, display_tempo - 2)
		is_dex_proc = true

	if debuff_mgr:
		is_hexed = debuff_mgr.is_card_hexed(index)
		if is_hexed:
			display_mana += debuff_mgr.get_hexed_mana_increase(index)
		is_locked = debuff_mgr.is_card_locked(index)

	# Engrave: unusable until slotted into an equipped item — greyed like Locked.
	var needs_engraving := (card.requires_engraving and card.slotted_in_item == null) \
			or card.world_block_reason() != ""

	# Costs live in the corner badges (mana drop / sand timer); the old title-bar
	# cost text only surfaces the maintain cost now.
	if cost_label:
		if card.maintain_cost > 0:
			cost_label.text = "Maint %dM" % card.maintain_cost
			cost_label.add_theme_font_size_override("font_size", 10)
			cost_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
			cost_label.visible = true
		else:
			cost_label.visible = false
		if card.maintain_cost > 0 and _frame == FRAMES["maintain"]:
			# The Maintain frame says "Maintain" on its type line in the
			# board's magenta (as the board does), puts the upkeep on the top
			# strip beside the dots, and leaves the name bar to the name.
			cost_label.visible = false
			if type_label:
				type_label.text = "Maintain"
				type_label.add_theme_color_override("font_color", MAINTAIN_WORD)
			_place_upkeep(card.maintain_cost)

	_pending_mana = str(display_mana)
	_pending_tempo = str(display_tempo)
	_pending_mana_col = Color.WHITE
	_pending_tempo_col = Color.WHITE
	if is_locked or needs_engraving:
		_pending_mana_col = Color(0.45, 0.45, 0.45)
		_pending_tempo_col = Color(0.45, 0.45, 0.45)
	else:
		if is_hexed:
			_pending_mana_col = Color(0.9, 0.5, 1.0)
		if is_dex_proc:
			_pending_tempo_col = Color(1.0, 0.35, 0.35)
	_refresh_cost_badges()

	_is_hexed = is_hexed
	_is_locked = is_locked

	# Card-affecting debuffs tint the whole card face (matches the status badge
	# designs): Locked = golden, Hexed = purple, Weighted = grey,
	# Staggered = grey on attack cards, Clumsy = brown.
	var tint := Color.WHITE
	if is_locked:
		tint = Color(1.0, 0.85, 0.45)
	elif needs_engraving:
		tint = Color(0.65, 0.65, 0.68)
	elif is_hexed:
		tint = Color(0.82, 0.6, 1.0)
	elif debuff_mgr and debuff_mgr.get_tempo_increase() > 0:
		tint = Color(0.72, 0.72, 0.76)
	elif debuff_mgr and card.is_attack() and debuff_mgr.get_attack_mana_increase() > 0:
		tint = Color(0.78, 0.78, 0.8)
	elif debuff_mgr and debuff_mgr.has_debuff(Debuff.DebuffType.CLUMSY):
		tint = Color(0.85, 0.7, 0.55)
	modulate = Color(tint.r, tint.g, tint.b, modulate.a)

	# Build tempo tick bars (thin vertical cylinders showing resolve tick)
	if is_dex_proc:
		var halved_resolve: int
		if pocket_knife and display_tempo > 0:
			halved_resolve = 1  # Pocket Knife: always resolve on first tick
		else:
			halved_resolve = card.resolve_tick / 2
			halved_resolve = maxi(halved_resolve, mini(1, display_tempo))  # At least tick 1 if there's any tempo
		_build_tempo_bars(card, display_tempo, halved_resolve)
	else:
		_build_tempo_bars(card)

	NewCardsD.place_face_ticker(self, card)  # Berserker's Tithe: tempo-effect countdown
	_update_visual_instant()

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_default_style()
	pivot_offset = Vector2(CARD_W * 0.5, CARD_H)  # Bottom-center pivot for fan rotation
	_ensure_badge()
	_ensure_cost_badges()
	_ensure_to_logo()
	_refresh_cost_badges()


# ============================================
# COST BADGES (mana drop + sand timer) & TO LOGO
# ============================================

var _mana_badge: Control = null
var _mana_num: Label = null
var _tempo_badge: Control = null
var _tempo_num: Label = null
var _pending_mana := ""      # setup() may run before _ready builds the badges
var _pending_tempo := ""
var _pending_mana_col := Color.WHITE
var _pending_tempo_col := Color.WHITE


## Corner cost badges: a mana drop on the card's top-left and a sand timer on
## the right, each with its number inside (replaces the "XM XT" text).
func _ensure_cost_badges() -> void:
	if _mana_badge and is_instance_valid(_mana_badge):
		return
	var host: Node = get_node_or_null("Panel")
	if host == null:
		return
	var made := _make_cost_badge(host, "res://assets/ui/mana_drop.png", Vector2(-11, -13), 4.0)
	_mana_badge = made[0]
	_mana_num = made[1]
	made = _make_cost_badge(host, "res://assets/ui/sand_timer.png", Vector2(CARD_W - 32.0, -13), 2.0)
	_tempo_badge = made[0]
	_tempo_num = made[1]


func _make_cost_badge(host: Node, icon_path: String, pos: Vector2, num_y_bias: float) -> Array:
	# No z_index boost: within its own card the badge draws above the frame
	# (added after the VBox), while neighbouring cards fanned over this one
	# still cover it instead of the badge bleeding through them.
	var badge := Control.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = pos
	badge.size = Vector2(32, 40)
	host.add_child(badge)
	# The designer's painted drop and hourglass (tools/cut_card_badges.py,
	# 2026-10-30), cut at 3x the box and shrunk smoothly into it.
	var icon := TextureRect.new()
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.texture = load(icon_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(icon)
	var num := Label.new()
	num.set_anchors_preset(Control.PRESET_FULL_RECT)
	num.offset_top = num_y_bias
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	num.add_theme_font_size_override("font_size", 13)
	num.add_theme_color_override("font_color", Color.WHITE)
	num.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
	num.add_theme_constant_override("outline_size", 6)
	badge.add_child(num)
	return [badge, num]


var _slot_badge: Control = null

## Slotted-card chip: the red dot plus a small glyph of the item TYPE holding
## this card (kite shield for shields, bow for bows, sword for swords, ring
## for rings, …). Hangs off the card's left edge below the mana badge. Pass
## null to remove it.
func set_slotted_item(item) -> void:
	if _slot_badge and is_instance_valid(_slot_badge):
		_slot_badge.queue_free()
		_slot_badge = null
	if item == null:
		return
	var host: Node = get_node_or_null("Panel")
	if host == null:
		return
	var key: String = UIGlyphs.item_glyph_key(item)
	var tex: Texture2D = UIGlyphs.get_glyph(key)
	if tex == null:
		return
	var chip := PanelContainer.new()
	chip.name = "SlotBadge"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.position = Vector2(-10, 30)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.1, 0.09, 0.12, 0.92)
	st.set_border_width_all(1)
	st.border_color = Color(0.45, 0.4, 0.55)
	st.set_corner_radius_all(6)
	st.content_margin_left = 4
	st.content_margin_right = 4
	st.content_margin_top = 2
	st.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", st)
	host.add_child(chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(7, 7)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dst := StyleBoxFlat.new()
	dst.bg_color = Color(0.92, 0.2, 0.2)
	dst.set_corner_radius_all(4)
	dot.add_theme_stylebox_override("panel", dst)
	row.add_child(dot)
	var icon := TextureRect.new()
	icon.texture = tex
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(UIGlyphs.SZ, UIGlyphs.SZ)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	_slot_badge = chip


## Small "TO" (Trials of Olorin) monogram seal in the middle of the card,
## riding the type bar like a trading-card set emblem.
func _ensure_to_logo() -> void:
	var type_hbox: Node = get_node_or_null("Panel/VBox/TypeBar/TypeHBox")
	if type_hbox == null or type_hbox.get_node_or_null("TOLogo"):
		return
	# The game's logo — the designer's emerald sword through the silver ring
	# (2026-10-30) — shared with the tooltip/tutorial crests via UIGlyphs. The holder
	# claims almost no layout height so the type bar stays thin; the sigil
	# itself draws larger than the bar with a drop shadow, so it reads as a
	# seal risen off the card face.
	var holder := Control.new()
	holder.name = "TOLogo"
	holder.custom_minimum_size = Vector2(14, 0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow := TextureRect.new()
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art stays crisp under the linear canvas default
	# Centred on the bar's middle (7, 0 in the holder), whatever its size.
	var ls: float = UIGlyphs.card_logo_size
	shadow.texture = UIGlyphs.to_logo(int(ls))
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.position = Vector2(8.5 - ls * 0.5, 1.5 - ls * 0.5)
	shadow.size = Vector2(ls, ls)
	shadow.modulate = Color(0, 0, 0, 0.5)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(shadow)
	var seal := TextureRect.new()
	seal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art stays crisp under the linear canvas default
	seal.texture = UIGlyphs.to_logo(int(ls))
	seal.stretch_mode = TextureRect.STRETCH_SCALE
	seal.position = Vector2(7.0 - ls * 0.5, -ls * 0.5)
	seal.size = Vector2(ls, ls)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(seal)
	# Sit between the type text (left, expanding) and the range text (right,
	# expanding) so the seal stays centred on the bar.
	type_hbox.add_child(holder)
	type_hbox.move_child(holder, 1)


func _refresh_cost_badges() -> void:
	if _mana_num:
		_mana_num.text = _pending_mana
		_mana_num.add_theme_color_override("font_color", _pending_mana_col)
	if _tempo_num:
		_tempo_num.text = _pending_tempo
		_tempo_num.add_theme_color_override("font_color", _pending_tempo_col)

# ============================================
# FLOATING PLAY BADGE + STACK DEPTH
# ============================================

var _keybind_badge: PanelContainer = null
var _badge_label: Label = null
var _stack_shadows: Array = []

func _ensure_badge() -> void:
	## The play button floats just above the card (rather than inside it) so the
	## card face has more room and the key is readable without hovering.
	if _keybind_badge and is_instance_valid(_keybind_badge):
		return
	var host: Node = get_node_or_null("Panel")
	if host == null:
		return
	_keybind_badge = PanelContainer.new()
	_keybind_badge.name = "KeybindBadge"
	_keybind_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.12, 0.96)
	style.set_border_width_all(2)
	style.border_color = _type_color.lightened(0.15)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	_keybind_badge.add_theme_stylebox_override("panel", style)
	host.add_child(_keybind_badge)

	_badge_label = Label.new()
	_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_label.add_theme_font_size_override("font_size", 15)
	_badge_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	_keybind_badge.add_child(_badge_label)
	_keybind_badge.resized.connect(_reposition_badge)

func set_keybind_badge(letter: String, count: int = 1, slotted: bool = false) -> void:
	## Set the floating play button's key letter and stack count (xN).
	## An empty letter means the stack has no play key (instant cards trigger
	## on their own) — the badge reads AUTO instead.
	_ensure_badge()
	if not _badge_label:
		return
	var txt := "AUTO" if letter == "" else "[%s]" % letter
	if count > 1:
		txt += " x%d" % count
	if slotted:
		txt += " ∴"  # slotted-card marker (∴)
		_badge_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	else:
		_badge_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	_badge_label.text = txt
	# Border picks up the card's type colour.
	var style: StyleBoxFlat = _keybind_badge.get_theme_stylebox("panel")
	if style:
		style.border_color = _type_color.lightened(0.2)
	_reposition_badge()

func _reposition_badge() -> void:
	if not _keybind_badge or not is_instance_valid(_keybind_badge):
		return
	# Centred just above the card's top edge (re-centres whenever the badge
	# resizes to fit longer text like "[A] x3").
	var w: float = _keybind_badge.size.x
	_keybind_badge.position = Vector2(CARD_W * 0.5 - w * 0.5, -30.0)

func set_stack_depth(count: int) -> void:
	## Show a small "pile" of offset card backs behind this card when it
	## represents a stack of identical cards.
	for s in _stack_shadows:
		if is_instance_valid(s):
			s.queue_free()
	_stack_shadows.clear()
	var host: Node = get_node_or_null("Panel")
	if host == null:
		return
	var extra: int = clampi(count - 1, 0, 3)
	for k in range(extra, 0, -1):
		var shadow := Panel.new()
		shadow.show_behind_parent = true  # draw behind the card face
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shadow.size = Vector2(CARD_W, CARD_H)
		# Peek out to the top-right so the pile reads as several stacked cards.
		shadow.position = Vector2(k * 4.0, -k * 4.0)
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.11, 0.1, 0.09, 1.0)
		st.set_border_width_all(2)
		st.border_color = _type_color.darkened(0.3)
		st.set_corner_radius_all(9)
		shadow.add_theme_stylebox_override("panel", st)
		host.add_child(shadow)
		host.move_child(shadow, 0)  # keep shadows beneath the VBox contents
		_stack_shadows.append(shadow)

func store_base_position() -> void:
	_base_y = position.y
	_base_x = position.x
	_base_z = z_index

func set_fan_rotation(angle_deg: float) -> void:
	_base_rotation = angle_deg
	rotation_degrees = angle_deg

func _on_mouse_entered() -> void:
	_is_hovered = true
	_update_visual()

func _on_mouse_exited() -> void:
	_is_hovered = false
	_update_visual()

func _update_description() -> void:
	if not desc_label or not _card:
		return
	# Numbers on the face reflect the holder's stats/buffs in a vacuum: the
	# battle scene installs value_provider (main.get_card_vacuum_values);
	# without one (deck viewers outside battle) base values show unchanged.
	var effective := {}
	if value_provider.is_valid():
		effective = value_provider.call(_card)
	var text: String = _card.get_display_description(effective)
	if _frame.get("ink_dark", false):
		# The light greens and reds read on the dark box, not the parchment.
		text = text.replace("#8be98b", "#1d6b1d").replace("#ff9c9c", "#9a1d16") \
			.replace("[color=green]", "[color=#1d6b1d]").replace("[color=red]", "[color=#9a1d16]")
	desc_label.text = text
	_fit_description()

## Long card text shrinks to fit the face instead of spilling off it: the
## description steps down from its normal 11 to as small as 7, the name from
## 13 to 9, until the text fits its box.
const DESC_FONT_MAX := 11
const DESC_FONT_MIN := 7
const DESC_BOX := Vector2(122, 76)   # the description area inside a 150x210 face
const NAME_FONT_MAX := 13
const NAME_FONT_MIN := 9
const NAME_WIDTH := 86               # the name's share of the title bar beside the cost

func _fit_description() -> void:
	if not desc_label:
		return
	var font: Font = desc_label.get_theme_font("normal_font")
	if font == null:
		return
	var plain: String = desc_label.get_parsed_text()
	var fs := DESC_FONT_MAX
	if _frame.is_empty():
		var width: float = desc_label.size.x if desc_label.size.x > 40.0 else DESC_BOX.x
		while fs > DESC_FONT_MIN and font.get_multiline_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, width, fs).y > DESC_BOX.y:
			fs -= 1
	else:
		# The frame's box beside its corner picture; a text that cannot fit
		# there even at the smallest size spreads over the box's whole width.
		var box: Vector2 = _frame["desc_box"]
		box.x *= _kx
		fs = _fit_size(font, plain, box)
		var right: float = _frame["desc_right"] * _kx
		if font.get_multiline_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, box.x, fs).y > box.y:
			var full: Vector2 = _frame.get("desc_full", FRAMED_DESC_FULL)
			full.x *= _kx
			fs = _fit_size(font, plain, full, FRAMED_DESC_FULL_MAX)
			right = 4.0
		if desc_panel:
			var st := desc_panel.get_theme_stylebox("panel")
			if st:
				st.content_margin_right = right
	desc_label.add_theme_font_size_override("normal_font_size", fs)
	desc_label.add_theme_font_size_override("bold_font_size", fs)
	if not _frame.is_empty():
		if not desc_label.resized.is_connected(_place_text_wash):
			desc_label.resized.connect(_place_text_wash)
		_place_text_wash.call_deferred()

## A translucent wash behind the rules text only, fading the frame's corner
## picture where the text sits so the text reads first (designer,
## 2026-11-08): dark on the stone frames, parchment on the Instant frame. It
## hugs the lines of text, so the rest of the rules box and the frame's
## bottom keep their full colour.
func _place_text_wash() -> void:
	var host: Control = get_node_or_null("Panel")
	if host == null or desc_label == null or not is_instance_valid(desc_label):
		return
	var w: Panel = host.get_node_or_null("TextWash")
	if _frame.is_empty() or text_wash_alpha <= 0.0 or desc_label.get_parsed_text().strip_edges() == "":
		if w:
			w.visible = false
		return
	if w == null:
		w = Panel.new()
		w.name = "TextWash"
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(w)
		host.move_child(w, 1 if host.get_node_or_null("FrameArt") else 0)   # over the frame, under the text
	var wash: Color = TEXT_WASH_PARCHMENT if _frame["ink_dark"] else TEXT_WASH_DARK
	wash.a = text_wash_alpha
	var sb := StyleBoxFlat.new()
	sb.bg_color = wash
	sb.set_corner_radius_all(4)
	w.add_theme_stylebox_override("panel", sb)
	# The label's place in the host's own units (cards are scaled as a whole).
	var xf: Transform2D = host.get_global_transform().affine_inverse() * desc_label.get_global_transform()
	var text_h: float = minf(float(desc_label.get_content_height()), desc_label.size.y)
	var pad := TEXT_WASH_PAD
	w.position = xf.origin - Vector2(pad, pad)
	w.size = Vector2(desc_label.size.x, text_h) + Vector2(pad, pad) * 2.0
	w.visible = true

func _fit_size(font: Font, plain: String, box: Vector2, top: int = DESC_FONT_MAX) -> int:
	var fs := top
	while fs > DESC_FONT_MIN and font.get_multiline_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, box.x, fs).y > box.y:
		fs -= 1
	return fs

func _fit_name() -> void:
	if not name_label:
		return
	var font: Font = name_label.get_theme_font("font")
	if font == null:
		return
	var fs := NAME_FONT_MAX
	if _laid_out() and int(face_layout.get("title_rows", 1)) >= 2:
		_fit_name_rows(font)
		return
	while fs > NAME_FONT_MIN and font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > _frame.get("name_w", NAME_WIDTH):
		fs -= 1
	name_label.add_theme_font_size_override("font_size", fs)

## The name centred in its bar, on one row if it fits at a readable size,
## else wrapped onto two, as large as both rows allow.
const NAME_ROWS_MIN := 8
func _fit_name_rows(font: Font) -> void:
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	name_label.max_lines_visible = 2
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var tb := title_bar.get_theme_stylebox("panel")
	var w: float = CARD_W * _kx - 26.0 * _kx - tb.content_margin_left - tb.content_margin_right
	var h: float = title_bar.custom_minimum_size.y - tb.content_margin_bottom
	var fs := NAME_FONT_MAX
	# One row, down to 11; then two rows, down to the floor.
	while fs > 11 and font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		fs -= 1
	if font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		fs = NAME_FONT_MAX
		while fs > NAME_ROWS_MIN and _rows_h(font, w, fs) > h + 1.0:
			fs -= 1
	name_label.add_theme_constant_override("line_spacing", NAME_ROWS_TIGHT)
	name_label.add_theme_font_size_override("font_size", fs)

const NAME_ROWS_TIGHT := -3   # the two rows drawn this much closer
func _rows_h(font: Font, w: float, fs: int) -> float:
	var full: float = font.get_multiline_string_size(name_label.text, HORIZONTAL_ALIGNMENT_CENTER, w, fs).y
	var rows := roundi(full / font.get_height(fs))
	return full + (rows - 1) * NAME_ROWS_TIGHT

func update_chance_display() -> void:
	# Called when RNG re-rolls happen - update the description colors
	_update_description()

func _update_visual() -> void:
	## Tweened version of visual update for hover/select transitions.
	if _is_animating_out:
		return

	_kill_hover_tween()

	var target_y: float = _base_y
	var target_mod: Color = Color(1, 1, 1)
	var target_rot: float = _base_rotation

	if _is_locked:
		target_mod = Color(0.4, 0.4, 0.4, 0.7)
		z_index = _base_z
		_clear_gold_trim()
	elif _selected:
		target_y = _base_y - SELECT_LIFT
		target_rot = 0.0  # Straighten selected card
		z_index = 100
		_apply_gold_trim()
	elif _is_hovered:
		target_y = _base_y - HOVER_LIFT
		target_rot = _base_rotation * 0.3  # Reduce rotation on hover
		z_index = 99
		_clear_gold_trim()
	elif _is_hexed:
		target_mod = Color(0.8, 0.5, 0.8)
		z_index = _base_z
		_clear_gold_trim()
	elif _card and _card.is_enhanced:
		target_mod = Color(0.5, 1, 0.5)
		z_index = _base_z
		_clear_gold_trim()
	else:
		z_index = _base_z
		_clear_gold_trim()

	_hover_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_hover_tween.set_parallel(true)
	_hover_tween.tween_property(self, "position:y", target_y, TWEEN_DURATION)
	_hover_tween.tween_property(self, "modulate", target_mod, TWEEN_DURATION)
	_hover_tween.tween_property(self, "rotation_degrees", target_rot, TWEEN_DURATION)

func _update_visual_instant() -> void:
	## Non-tweened version for initial setup.
	if _is_locked:
		modulate = Color(0.4, 0.4, 0.4, 0.7)
		position.y = _base_y
		z_index = _base_z
		_clear_gold_trim()
	elif _selected:
		modulate = Color(1, 1, 1)
		position.y = _base_y - SELECT_LIFT
		z_index = 100
		_apply_gold_trim()
	elif _is_hovered:
		modulate = Color(1, 1, 1)
		position.y = _base_y - HOVER_LIFT
		z_index = 99
		_clear_gold_trim()
	elif _is_hexed:
		modulate = Color(0.8, 0.5, 0.8)
		position.y = _base_y
		z_index = _base_z
		_clear_gold_trim()
	elif _card and _card.is_enhanced:
		modulate = Color(0.5, 1, 0.5)
		position.y = _base_y
		z_index = _base_z
		_clear_gold_trim()
	else:
		modulate = Color(1, 1, 1)
		position.y = _base_y
		z_index = _base_z
		_clear_gold_trim()

func _kill_hover_tween() -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
		_hover_tween = null

# ============================================
# ANIMATION HELPERS (called by main.gd)
# ============================================

func animate_draw_in(from_pos: Vector2, final_pos: Vector2, delay: float = 0.0) -> void:
	## Drawn card squeezes OUT of the draw pile — the tube-suck discard in
	## reverse, a touch faster: it emerges thin and stretched at the pile,
	## un-squashes mid-flight, and settles into its hand slot.
	pivot_offset = Vector2(size.x * 0.5, size.y)
	position = from_pos
	modulate.a = 0.0
	scale = Vector2(0.06, 1.4)
	rotation_degrees = -12.0
	var final_z := z_index  # the fan's stacking index, restored after the flight
	z_index = 150

	var tween = create_tween()
	if delay > 0:
		tween.tween_interval(delay)
	# Pop out of the tube: fly toward the hand while the card re-inflates.
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.08)
	tween.tween_property(self, "position", final_pos, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(0.5, 1.08), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# ...then the last un-squash snaps it back to a real card in the fan.
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation_degrees", _base_rotation, 0.12)
	tween.chain()
	tween.tween_callback(func(): z_index = final_z)

func get_card() -> Card:
	return _card


## The shared "sucked into the discard pile" finish: the card is pulled toward
## the pile as if squeezing into a too-small tube — the bottom edge narrows
## first (pivot sits at the bottom-centre so the base converges before the
## rest), then the whole card stretches thin and vanishes into the pile.
func _tube_suck_to(tween: Tween, discard_pos: Vector2, on_complete: Callable = Callable()) -> void:
	pivot_offset = Vector2(size.x * 0.5, size.y)
	# Bottom narrows first...
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.5, 1.08), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# ...then the rest funnels in after it.
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(self, "position", discard_pos, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.06, 1.4), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "rotation_degrees", -12.0, 0.28)
	tween.tween_property(self, "modulate:a", 0.0, 0.12).set_delay(0.18)
	tween.chain()
	tween.tween_callback(func():
		if on_complete.is_valid():
			on_complete.call()
		queue_free()
	)


func animate_played_to_discard(discard_pos: Vector2, on_complete: Callable = Callable()) -> void:
	## Played/discarded card: pops up, pauses a beat, then is sucked into the
	## discard pile bottom-first.
	_is_animating_out = true
	_kill_hover_tween()
	z_index = 200

	var tween = create_tween()
	# Pop up and hold.
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 46, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation_degrees", 0.0, 0.14)
	tween.chain()
	tween.tween_interval(0.22)
	_tube_suck_to(tween, discard_pos, on_complete)


func animate_instant(discard_pos: Vector2, on_complete: Callable = Callable()) -> void:
	## Instant (reaction) trigger: the card pops up, spins twice on the spot,
	## then is sucked into the discard pile like any other discard.
	_is_animating_out = true
	_kill_hover_tween()
	z_index = 200
	pivot_offset = size * 0.5

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 56, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain()
	# Two full spins.
	tween.tween_property(self, "rotation_degrees", rotation_degrees + 720.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(0.08)
	_tube_suck_to(tween, discard_pos, on_complete)


func animate_disintegrate(on_complete: Callable = Callable()) -> void:
	## Erase expiring: the card crumbles into drifting particles right in the
	## hand — no discard pile, it is simply gone.
	_is_animating_out = true
	_kill_hover_tween()
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Scatter fragments sampled across the card's face.
	var frag_colors := [Color(0.75, 0.75, 0.8), Color(0.55, 0.55, 0.62), Color(0.9, 0.9, 0.95)]
	for i in range(26):
		var frag := ColorRect.new()
		frag.color = frag_colors[i % frag_colors.size()]
		frag.size = Vector2(randf_range(4, 9), randf_range(4, 9))
		frag.position = Vector2(randf_range(0, size.x), randf_range(0, size.y))
		frag.z_index = 210
		add_child(frag)
		var drift := Vector2(randf_range(-50, 50), randf_range(-90, -30))
		var ftw := frag.create_tween().set_parallel(true)
		var dur := randf_range(0.45, 0.8)
		ftw.tween_property(frag, "position", frag.position + drift, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ftw.tween_property(frag, "modulate:a", 0.0, dur)
		ftw.tween_property(frag, "rotation_degrees", randf_range(-180, 180), dur)

	# The card body flashes pale, shudders, and dissolves under the fragments.
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(1.4, 1.4, 1.5, 1.0), 0.1)
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", position.y + 14, 0.4)
	tween.chain()
	tween.tween_interval(0.5)  # let the fragments finish drifting
	tween.tween_callback(func():
		if on_complete.is_valid():
			on_complete.call()
		queue_free()
	)


func show_sticky_counter(uses: int, max_uses: int) -> void:
	## Sticky card staying in hand: a use counter pops up over the card, holds,
	## and fades as the card settles back into the hand.
	var counter := Label.new()
	counter.text = "%d/%d" % [uses, max_uses]
	counter.add_theme_font_size_override("font_size", 26)
	counter.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	counter.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.0))
	counter.add_theme_constant_override("outline_size", 6)
	counter.z_index = 220
	add_child(counter)
	counter.position = Vector2(size.x * 0.5 - 22, -34)
	counter.pivot_offset = Vector2(22, 16)
	counter.scale = Vector2.ZERO
	var tw := counter.create_tween()
	tw.tween_property(counter, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.7)
	tw.tween_property(counter, "modulate:a", 0.0, 0.35)
	tw.parallel().tween_property(counter, "position:y", -58.0, 0.35)
	tw.tween_callback(counter.queue_free)


func animate_play(target_screen_pos: Vector2, on_complete: Callable = Callable()) -> void:
	## Card lifts, scales up briefly, flies to target, fades out.
	_is_animating_out = true
	_kill_hover_tween()
	z_index = 200

	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	# Phase 1: Lift and scale up
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 30, 0.1)
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.1)
	tween.tween_property(self, "rotation_degrees", 0.0, 0.1)

	# Phase 2: Fly to target and fade
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(self, "position", target_screen_pos, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.4, 0.4), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.2).set_delay(0.05)

	tween.chain()
	tween.tween_callback(func():
		if on_complete.is_valid():
			on_complete.call()
		queue_free()
	)

func _apply_gold_trim() -> void:
	if not _frame.is_empty():
		# The painted frame keeps its look; a gold line rings it when chosen.
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.set_border_width_all(2)
		ring.border_color = Color(1.0, 0.84, 0.0)
		ring.set_corner_radius_all(8)
		ring.set_expand_margin_all(2)
		add_theme_stylebox_override("panel", ring)
		return
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.1, 0.09, 1.0)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(1.0, 0.84, 0.0)  # Gold
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	add_theme_stylebox_override("panel", style)

func _apply_default_style() -> void:
	if not _frame.is_empty():
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		return
	# MtG-style outer frame: a thick dark "card back" edge with the type's
	# colour glowing through the inner border.
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.1, 0.09, 1.0)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = _type_color.darkened(0.25)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	add_theme_stylebox_override("panel", style)


func _bar_style(bg: Color, radius: int = 4) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.border_color = Color(0.05, 0.05, 0.05, 0.9)
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	return s


func _style_frame() -> void:
	## Dress the inner frame like a trading card: coloured title bar, framed
	## art window (placeholder until real artwork lands), type line, and a
	## parchment-dark rules box.
	_apply_default_style()
	if not _frame.is_empty():
		_style_painted_frame()
		return
	if title_bar:
		# Extra side margins keep the title clear of the corner cost badges.
		var tb := _bar_style(_type_color.darkened(0.45))
		tb.content_margin_left = 16
		tb.content_margin_right = 14
		title_bar.add_theme_stylebox_override("panel", tb)
	if type_bar:
		# Thin band: the type line is secondary info; the risen TO seal
		# deliberately overhangs it above and below.
		var tp := _bar_style(_type_color.darkened(0.55), 3)
		tp.content_margin_top = 0
		tp.content_margin_bottom = 0
		type_bar.add_theme_stylebox_override("panel", tp)
	if art_box:
		var art = _bar_style(_type_color.darkened(0.72), 3)
		art.border_color = _type_color.lightened(0.05)
		art.content_margin_top = 0
		art.content_margin_bottom = 0
		art_box.add_theme_stylebox_override("panel", art)
		_set_card_art()
	if desc_panel:
		var box = _bar_style(Color(0.17, 0.16, 0.14), 3)
		box.content_margin_top = 4
		box.content_margin_bottom = 4
		desc_panel.add_theme_stylebox_override("panel", box)

## Dress the card in its type's painted frame: the frame drawn behind
## everything, the bars bare so the painting shows, each line laid on the
## painted bar it belongs to; the costs written on the painted drop and
## hourglass, the logo on the type bar's ring spot.
func _style_painted_frame() -> void:
	var host: Control = get_node_or_null("Panel")
	if host == null:
		return
	host.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	if _frame_art == null:
		_frame_art = TextureRect.new()
		_frame_art.name = "FrameArt"
		_frame_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_frame_art.stretch_mode = TextureRect.STRETCH_SCALE
		_frame_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		host.add_child(_frame_art)
		host.move_child(_frame_art, 0)
	_frame_art.texture = load(_frame["tex"])
	var r: Rect2 = _frame["rect"]
	_frame_art.position = r.position
	_frame_art.size = r.size
	_build_layout()
	var bands: Node = host.get_node_or_null("FrameBands")
	if _laid_out():
		_frame_art.visible = false
		_draw_frame_bands(host)
		custom_minimum_size = Vector2(CARD_W * _kx, CARD_H)
		size = custom_minimum_size
		pivot_offset = Vector2(CARD_W * _kx * 0.5, CARD_H)
	else:
		_frame_art.visible = true
		if bands:
			bands.queue_free()
	# The sections stacked onto the painted bars (card pixels): name bar
	# 14-36, art window 36-100, type bar 100-118, parchment from 118.
	var vbox: VBoxContainer = host.get_node_or_null("VBox")
	if vbox:
		vbox.offset_left = 14.0 * _kx
		vbox.offset_right = -12.0 * _kx
		vbox.offset_top = _my(_frame.get("top", 14.0))
		vbox.offset_bottom = -8.0
		vbox.add_theme_constant_override("separation", 0)
	if title_bar:
		var tb := StyleBoxEmpty.new()
		tb.content_margin_left = _frame.get("title_left", 21.0)
		tb.content_margin_right = _frame.get("title_right", 16.0)
		tb.content_margin_bottom = 3
		if _laid_out():
			tb.content_margin_left = float(face_layout.get("title_left", tb.content_margin_left)) * _kx
			tb.content_margin_right = _frame.get("title_right", 16.0) * _kx
			tb.content_margin_bottom = 1
		title_bar.add_theme_stylebox_override("panel", tb)
		var t0: float = _frame.get("top", 14.0)
		title_bar.custom_minimum_size = Vector2(0, _my(t0 + _frame.get("title_h", 22.0)) - _my(t0))
	if name_label:
		name_label.add_theme_color_override("font_color", FRAMED_NAME)
		name_label.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.02))
		name_label.add_theme_constant_override("outline_size", 4)
	if art_box:
		# Inset to the painted window's inner rim (measured off each board),
		# so a painting in the window stops at the rim instead of over it.
		var ab := StyleBoxEmpty.new()
		var am: Array = _frame.get("art_margins", [0, 0, 0, 0])
		ab.content_margin_left = am[0] * _kx
		ab.content_margin_top = am[1]
		ab.content_margin_right = am[2] * _kx
		ab.content_margin_bottom = am[3]
		art_box.add_theme_stylebox_override("panel", ab)
		var a0: float = _frame.get("top", 14.0) + _frame.get("title_h", 22.0)
		art_box.custom_minimum_size = Vector2(0, _my(a0 + _frame.get("art_h", 64.0)) - _my(a0))
		_set_card_art()
	if type_bar:
		var tp := StyleBoxEmpty.new()
		tp.content_margin_left = 2
		tp.content_margin_right = 3
		type_bar.add_theme_stylebox_override("panel", tp)
		var y0: float = _frame.get("top", 14.0) + _frame.get("title_h", 22.0) + _frame.get("art_h", 64.0)
		type_bar.custom_minimum_size = Vector2(0, _my(y0 + _frame.get("type_h", 18.0)) - _my(y0))
	if desc_panel:
		var box := StyleBoxEmpty.new()
		box.content_margin_left = 3.5
		box.content_margin_right = _frame["desc_right"] * _kx
		box.content_margin_top = _frame.get("desc_top", 4.0)
		desc_panel.add_theme_stylebox_override("panel", box)
	if desc_panel:
		desc_panel.clip_contents = true   # a long text never shoves the bars above it
	if desc_label:
		desc_label.fit_content = false
		desc_label.custom_minimum_size = Vector2(0.1, 10)
		desc_label.add_theme_color_override("default_color", _frame["ink"])
		if not _frame["ink_dark"]:
			# Light text on the dark stone: a dark rim keeps it off the texture.
			desc_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.06))
			desc_label.add_theme_constant_override("outline_size", 3)
	_place_framed_costs()
	_place_framed_logo()
	_fit_name()   # this frame's name bar may be narrower
	_fit_type_word()


## The logo's ring, half its width (card pixels): a type word stays left of it.
const FRAMED_LOGO_RING := 13.0
const TYPE_FONT_MAX := 9
const TYPE_FONT_MIN := 7

## A long type word ("Enchantment") steps its size down until it ends short
## of the logo set in the type bar's middle, instead of running under it.
func _fit_type_word() -> void:
	if type_label == null or _frame.is_empty():
		return
	var font: Font = type_label.get_theme_font("font")
	if font == null:
		return
	# The bar's text starts at the VBox's left edge (14) plus its margin (2).
	var room: float = float(_frame["logo_at"].x) * _kx - FRAMED_LOGO_RING - 14.0 * _kx - 2.0
	var fs := TYPE_FONT_MAX
	while fs > TYPE_FONT_MIN and font.get_string_size(type_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	type_label.add_theme_font_size_override("font_size", fs)


## The upkeep on the Maintain frame's top strip, right of the tempo dots.
func _place_upkeep(upkeep: int) -> void:
	var host: Control = get_node_or_null("Panel")
	if host == null:
		return
	var l: Label = host.get_node_or_null("Upkeep")
	if l == null:
		l = Label.new()
		l.name = "Upkeep"
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 9)
		l.add_theme_color_override("font_color", MAINTAIN_WORD)
		l.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.08))
		l.add_theme_constant_override("outline_size", 3)
		host.add_child(l)
	l.text = "%dM" % upkeep
	l.tooltip_text = "Upkeep: %d mana to maintain" % upkeep
	l.size = Vector2(30, 12)
	l.position = Vector2(UPKEEP_RIGHT - 30.0, float(_frame["dots_y"]) - 6.0)


## The costs written straight onto the painted drop and hourglass.
func _place_framed_costs() -> void:
	_ensure_cost_badges()
	if _laid_out():
		_place_laid_out_badges()
		return
	for pair in [[_mana_badge, _mana_num, _frame["mana_at"]], [_tempo_badge, _tempo_num, _frame["tempo_at"]]]:
		var badge: Control = pair[0]
		var num: Label = pair[1]
		if badge == null:
			continue
		for c in badge.get_children():
			if c is TextureRect:
				c.visible = false
		var at: Vector2 = pair[2]
		badge.position = at - badge.size * 0.5
		num.offset_top = 0.0


## face_layout: the drop and hourglass drawn over the bare frame at
## face_layout.badge their painted size, about the painted one's middle, the
## numbers where the painting puts them on each.
func _place_laid_out_badges() -> void:
	var k: float = float(face_layout.get("badge", 1.0))
	var b: Dictionary = _frame["bare"]
	for spec in [[_mana_badge, _mana_num, b["drop"], _frame["mana_at"], "res://assets/ui/mana_drop.png"],
			[_tempo_badge, _tempo_num, b["glass"], _frame["tempo_at"], "res://assets/ui/sand_timer.png"]]:
		var badge: Control = spec[0]
		var num: Label = spec[1]
		if badge == null:
			continue
		var art: Rect2 = spec[2]
		var c: Vector2 = art.get_center()
		var c2: Vector2 = _mp(c)
		badge.size = art.size * k
		badge.position = c2 - badge.size * 0.5
		for ch in badge.get_children():
			if ch is TextureRect:
				ch.visible = true
				ch.texture = _badge_atlas(spec[4])
				ch.stretch_mode = TextureRect.STRETCH_SCALE
		var d: Vector2 = (Vector2(spec[3]) - c) * k
		num.offset_left = d.x
		num.offset_right = d.x
		num.offset_top = d.y
		num.offset_bottom = d.y
		num.add_theme_font_size_override("font_size", maxi(9, roundi(13.0 * k)))


## The logo on the painted frame's ring spot (the frame's own was painted
## out), in place of the seal riding the type line.
func _place_framed_logo() -> void:
	var held: Node = get_node_or_null("Panel/VBox/TypeBar/TypeHBox/TOLogo")
	if held:
		for c in held.get_children():
			c.visible = false
	var host: Control = get_node_or_null("Panel")
	if host == null or host.get_node_or_null("FrameLogo"):
		return
	var ls := float(FRAMED_LOGO_SIZE)
	var seal := TextureRect.new()
	seal.name = "FrameLogo"
	seal.texture = UIGlyphs.to_logo(FRAMED_LOGO_SIZE)
	seal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	seal.stretch_mode = TextureRect.STRETCH_SCALE
	seal.size = Vector2(ls, ls)
	seal.position = (_mp(Vector2(_frame["logo_at"])) - Vector2(ls, ls) * 0.5).round()
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(seal)


func _set_card_art() -> void:
	## Craftpix skill icon in the art window (SkillIconArt picks per card_id,
	## themed pool otherwise). The "~ artwork ~" placeholder hides once art
	## resolves.
	if art_box == null:
		return
	## A designer painting (SkillIconArt.CARD_PAINTINGS) fills the window,
	## cropped top and bottom; an icon sits centred at its own shape.
	var painting: Texture2D = SkillIconArt.card_painting(_card) if _card else null
	var tex: Texture2D = painting if painting else (SkillIconArt.card(_card) if _card else null)
	var label := art_box.get_node_or_null("ArtLabel")
	if tex == null:
		if _art_rect:
			_art_rect.visible = false
		if label:
			label.visible = true
		return
	if _art_rect == null:
		_art_rect = TextureRect.new()
		_art_rect.name = "ArtRect"
		_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_art_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_box.add_child(_art_rect)
	_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if painting else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art_rect.texture = tex
	_art_rect.visible = true
	if label:
		label.visible = false

func _clear_gold_trim() -> void:
	_apply_default_style()

func _build_tempo_bars(card: Card, tempo_override: int = -1, resolve_override: int = -1) -> void:
	## A centred row of small circles nestled against the card's top edge,
	## above the name — one per tempo tick. The tick the card resolves on is
	## filled gold. Drawn as an overlay (like the corner cost badges) so it
	## takes no layout height and the frame spacing stays untouched.
	var effective_tempo = tempo_override if tempo_override >= 0 else card.tempo_cost
	var host = $Panel
	if not host:
		return

	# Remove existing tempo bar container if re-setup
	var existing = host.get_node_or_null("TempoBarContainer")
	if existing:
		existing.queue_free()
	if effective_tempo <= 0:
		return

	var bar_container = HBoxContainer.new()
	bar_container.name = "TempoBarContainer"
	bar_container.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_container.add_theme_constant_override("separation", 4)
	bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Panel is inset by the 3px frame border; offset by it so the row centres
	# on the card, not the inner panel.
	bar_container.position = Vector2(-3, -3)
	bar_container.size = Vector2(CARD_W, 9)
	var dot_px := FRAMED_DOT
	if not _frame.is_empty():
		# On the painted frame's dot strip (the Panel sits at the card's
		# corner), between its ends: a long row shrinks its dots to fit.
		var span: Vector2 = _frame.get("dots_span", Vector2(34, 118)) * _kx
		var sep := 3.0
		if effective_tempo * dot_px + (effective_tempo - 1) * sep > span.y - span.x:
			sep = 2.0
			dot_px = floorf((span.y - span.x - (effective_tempo - 1) * sep) / maxf(1.0, effective_tempo))
		bar_container.position = Vector2(span.x, _my(float(_frame["dots_y"])) - dot_px * 0.5)
		bar_container.size = Vector2(span.y - span.x, dot_px)
		bar_container.add_theme_constant_override("separation", int(sep))
	host.add_child(bar_container)

	var resolve_tick = resolve_override if resolve_override >= 0 else mini(card.resolve_tick, effective_tempo)

	for i in range(effective_tempo):
		if not _frame.is_empty():
			# The designer's glossy dots: gold on the tick it resolves on.
			var pd := TextureRect.new()
			pd.texture = load("res://assets/textures/cards/dot_gold.png" if i + 1 == resolve_tick else "res://assets/textures/cards/dot_dark.png")
			pd.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pd.stretch_mode = TextureRect.STRETCH_SCALE
			pd.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			pd.custom_minimum_size = Vector2(dot_px, dot_px)
			pd.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pd.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar_container.add_child(pd)
			continue
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(9, 9)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var st := StyleBoxFlat.new()
		st.set_corner_radius_all(5)
		if i + 1 == resolve_tick:
			st.bg_color = Color(1.0, 0.84, 0.0)  # gold: the tick this card triggers on
			st.set_border_width_all(1)
			st.border_color = Color(0.55, 0.42, 0.05)
		else:
			st.bg_color = Color(0.2, 0.2, 0.28)
			st.set_border_width_all(1)
			st.border_color = Color(0.09, 0.09, 0.13)
		dot.add_theme_stylebox_override("panel", st)
		bar_container.add_child(dot)

func set_hovered_external(hovered: bool) -> void:
	_is_hovered = hovered
	_update_visual()

func set_selected(selected: bool) -> void:
	_selected = selected
	_update_visual()
