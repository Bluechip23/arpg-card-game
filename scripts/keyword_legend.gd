class_name KeywordLegend
extends ScrollContainer

## Displays all game keywords organized by category

@onready var content: VBoxContainer = $Content

func _ready() -> void:
	_build_legend()

func _build_legend() -> void:
	if not content:
		return
	
	# Clear existing
	for child in content.get_children():
		child.queue_free()
	
	# Stats Section
	_add_section_header("CORE STATS")
	_add_keyword("Strength (STR)", "+10 carry capacity per point, +1 physical damage per 2 points")
	_add_keyword("Dexterity (DEX)", "-1 attack speed counter per point. At 0 counter: next attack costs 2 less mana + no tempo")
	_add_keyword("Intelligence (INT)", "+1 spell damage per point, +1 mana regen per 5 points")
	_add_keyword("Wisdom (WIS)", "+1 hand size per 5 points, -0.25 draw timer per point")
	_add_keyword("Agility (AGI)", "Determines movements per tempo. Every 5 AGI = 1 free movement. AGI 5 = 1, AGI 10 = 2, etc.")
	_add_keyword("Determination (DET)", "Modifies STR/DEX/INT/WIS/AGI at low health thresholds")
	
	# Debuffs Section
	_add_section_header("DEBUFFS")
	_add_keyword("Bleed", "On movement: take X damage per tile moved", Color(0.8, 0.1, 0.1))
	_add_keyword("Stun", "Cannot take any actions", Color(1.0, 1.0, 0.0))
	_add_keyword("Disarm", "Cannot play attack cards", Color(0.6, 0.3, 0.1))
	_add_keyword("Silence", "Cannot play spell cards", Color(0.5, 0.0, 0.8))
	_add_keyword("Burn", "Take X damage per turn and on attack", Color(1.0, 0.5, 0.0))
	_add_keyword("Poison", "Take X damage per turn, deal X less damage", Color(0.2, 0.8, 0.2))
	_add_keyword("Inebriate", "Movement direction is randomized", Color(0.8, 0.4, 0.8))
	_add_keyword("Cursed", "Deal X less damage, deal X×10% damage to self", Color(0.3, 0.0, 0.3))
	_add_keyword("Frozen", "Cannot play cards", Color(0.5, 0.8, 1.0))
	_add_keyword("Cuffed", "Cannot draw cards", Color(0.5, 0.5, 0.5))
	_add_keyword("Shocked", "Deal X damage to nearby allies per turn", Color(1.0, 1.0, 0.3))
	_add_keyword("Slowed", "Lose X movement per turn", Color(0.3, 0.3, 0.6))
	_add_keyword("Staggered", "Attack cards cost X more mana", Color(0.6, 0.4, 0.2))
	_add_keyword("Drain", "Lose X mana per turn", Color(0.4, 0.0, 0.6))
	_add_keyword("Weighted", "Cards cost X more tempo", Color(0.4, 0.4, 0.4))
	_add_keyword("Hexed", "One random card costs +X mana", Color(0.6, 0.0, 0.6))
	_add_keyword("Locked", "One random card cannot be played", Color(0.3, 0.3, 0.3))
	_add_keyword("Rooted", "Cannot move", Color(0.4, 0.25, 0.1))
	_add_keyword("Tethered", "Cannot move more than X tiles from origin", Color(0.7, 0.7, 0.2))
	_add_keyword("Magnetized", "Pulled X tiles toward nearest enemy each turn", Color(0.2, 0.2, 0.8))
	_add_keyword("Linked", "Share X% damage taken with nearest ally", Color(0.8, 0.4, 0.4))
	_add_keyword("Clumsy", "X% chance to discard random card when playing", Color(0.9, 0.6, 0.2))
	_add_keyword("Vulnerable", "Take X% more damage from all sources", Color(1.0, 0.3, 0.3))
	_add_keyword("Exposed", "Armor effectiveness reduced by X%", Color(0.9, 0.7, 0.5))
	_add_keyword("Brittle", "Armor decays X additional per turn", Color(0.7, 0.7, 0.6))
	
	# Buffs Section
	_add_section_header("BUFFS")
	_add_keyword("Thorns", "Deal X damage back to attackers", Color(0.8, 0.4, 0.8))
	_add_keyword("Focused", "Gain 1 extra mana per turn", Color(0.4, 0.6, 1.0))
	_add_keyword("Regen", "Heal X HP per turn", Color(0.4, 1.0, 0.4))
	_add_keyword("Blessed", "Draw X additional cards per turn", Color(1.0, 0.9, 0.5))
	_add_keyword("Fortify", "Armor does not decay", Color(0.6, 0.6, 0.8))
	_add_keyword("Enlightened", "+X% crit chance for next Y attacks", Color(1.0, 1.0, 0.6))
	_add_keyword("Strengthen", "+X damage on next Y attacks", Color(1.0, 0.5, 0.3))
	_add_keyword("Bolster", "+X armor next Y times you gain armor", Color(0.5, 0.7, 1.0))
	_add_keyword("Haste", "+X movement per tempo spent", Color(0.5, 1.0, 1.0))
	_add_keyword("Cleanse", "Remove X negative effects (instant)", Color(1.0, 1.0, 1.0))
	_add_keyword("Smith", "Gain X armor per turn", Color(0.7, 0.7, 0.7))
	_add_keyword("Steady", "Next action does not add tempo", Color(0.6, 0.8, 0.6))
	_add_keyword("Brace", "Reduce next incoming attack by X", Color(0.5, 0.5, 0.8))
	_add_keyword("Resilient", "Reduce incoming damage by X% for Y attacks", Color(0.7, 0.6, 0.9))
	
	# Overflow Section
	_add_section_header("OVERFLOW MODES")
	_add_keyword("Jailed", "Card goes to jail for 3 turns, cannot be played")
	_add_keyword("Manifest", "Card goes to manifest zone as a token. Click to activate the manifest effect, then card is discarded")
	_add_keyword("Enhance", "Attack cards gain +X bonus damage, then discarded")
	_add_keyword("Transferred", "Card is given to an ally (or discarded if no ally)")
	_add_keyword("Peak", "See the next card on draw pile (doesn't block other effects)")
	_add_keyword("Overcharge", "Triggers an effect when overflow occurs (doesn't block other effects)")
	
	# Range Section
	_add_section_header("RANGE")
	_add_keyword("Melee", "Card must be used at close range (default for all cards)", Color(0.9, 0.6, 0.3))
	_add_keyword("Ranged", "Card can be used at distance. Base range = 5 tiles. Ranged +X = 5+X, Ranged -X = 5-X", Color(0.3, 0.8, 0.9))

	# Card Types Section
	_add_section_header("CARD TYPES")
	_add_keyword("Attack", "Offensive cards that deal damage", Color(1, 0.3, 0.3))
	_add_keyword("Defense", "Protective cards that grant armor or block", Color(0.3, 0.5, 1))
	_add_keyword("Utility", "Support cards for draw, healing, buffs, etc.", Color(0.3, 1, 0.3))

func _add_section_header(title: String) -> void:
	var header = Label.new()
	header.text = "\n" + title
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	content.add_child(header)
	
	var separator = HSeparator.new()
	content.add_child(separator)

func _add_keyword(keyword: String, description: String, color: Color = Color.WHITE) -> void:
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size.y = 30
	
	var keyword_label = Label.new()
	keyword_label.text = keyword + ": "
	keyword_label.add_theme_color_override("font_color", color)
	keyword_label.add_theme_font_size_override("font_size", 14)
	keyword_label.custom_minimum_size.x = 150
	hbox.add_child(keyword_label)
	
	var desc_label = Label.new()
	desc_label.text = description
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(desc_label)
	
	content.add_child(hbox)
