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
	_add_keyword("Intelligence (INT)", "+1 spell damage per 2 points, +1 mana regen per 5 points")
	_add_keyword("Wisdom (WIS)", "+1 hand size per 5 points, -0.25 draw timer per point")
	_add_keyword("Agility (AGI)", "Determines movements per tempo. Every 5 AGI = 1 free movement. AGI 5 = 1, AGI 10 = 2, etc.")
	_add_keyword("Determination (DET)", "Modifies STR/DEX/INT/WIS/AGI at low health thresholds. DET 10 = no effect. Above 10 = bonus when hurt, below 10 = penalty when hurt")

	# Debuffs Section
	_add_section_header("DEBUFFS")
	_add_keyword("Bleed", "On movement: take X damage per tile moved", Color(0.8, 0.1, 0.1))
	_add_keyword("Stun", "Cannot take any actions", Color(1.0, 1.0, 0.0))
	_add_keyword("Disarm", "Cannot play attack cards", Color(0.6, 0.3, 0.1))
	_add_keyword("Silence", "Cannot play spell cards", Color(0.5, 0.0, 0.8))
	_add_keyword("Burn", "Burn damage doubles each cycle (1, 2, 4, 8...)", Color(1.0, 0.5, 0.0))
	_add_keyword("Poison", "Take X damage per cycle, lose 1 poison each cycle", Color(0.2, 0.8, 0.2))
	_add_keyword("Inebriate", "Movement direction is randomized", Color(0.8, 0.4, 0.8))
	_add_keyword("Cursed", "Deal 20% less damage and deal 20% damage to self", Color(0.3, 0.0, 0.3))
	_add_keyword("Frozen", "Cannot play cards", Color(0.5, 0.8, 1.0))
	_add_keyword("Cuffed", "Cannot draw cards", Color(0.5, 0.5, 0.5))
	_add_keyword("Shocked", "Deal X damage to nearby allies per cycle, lose 1 per cycle", Color(1.0, 1.0, 0.3))
	_add_keyword("Slowed", "Lose X movement per cycle", Color(0.3, 0.3, 0.6))
	_add_keyword("Staggered", "Attack cards cost X more mana", Color(0.6, 0.4, 0.2))
	_add_keyword("Drain", "Lose 1 mana per cycle, lose 1 drain per cycle", Color(0.4, 0.0, 0.6))
	_add_keyword("Weighted", "Cards cost X more tempo", Color(0.4, 0.4, 0.4))
	_add_keyword("Hexed", "One random card costs +X mana", Color(0.6, 0.0, 0.6))
	_add_keyword("Locked", "One random card cannot be played", Color(0.3, 0.3, 0.3))
	_add_keyword("Rooted", "Cannot move", Color(0.4, 0.25, 0.1))
	_add_keyword("Tethered", "Cannot move more than X tiles from origin", Color(0.7, 0.7, 0.2))
	_add_keyword("Magnetized", "Pulled X tiles toward nearest enemy each cycle", Color(0.2, 0.2, 0.8))
	_add_keyword("Linked", "Share X% damage taken with nearest ally", Color(0.8, 0.4, 0.4))
	_add_keyword("Clumsy", "X% chance to discard random card when playing", Color(0.9, 0.6, 0.2))
	_add_keyword("Vulnerable", "Take 30% more damage on next X attack(s), lose 1 stack per hit", Color(1.0, 0.3, 0.3))
	_add_keyword("Exposed", "Remove 30% more armor when hit, lose 1 stack per hit", Color(0.9, 0.7, 0.5))
	_add_keyword("Brittle", "Armor decays extra 2 per cycle, lose 1 stack per cycle", Color(0.7, 0.7, 0.6))

	# Buffs Section
	_add_section_header("BUFFS")
	_add_keyword("Thorns", "Deal X damage back to attackers, lose 1 thorn per hit", Color(0.8, 0.4, 0.8))
	_add_keyword("Focused", "Gain 1 extra mana per cycle", Color(0.4, 0.6, 1.0))
	_add_keyword("Regen", "Heal X HP per cycle, lose 1 regen per cycle", Color(0.4, 1.0, 0.4))
	_add_keyword("Blessed", "Draw X additional card(s) per cycle", Color(1.0, 0.9, 0.5))
	_add_keyword("Fortify", "Armor does not decay", Color(0.6, 0.6, 0.8))
	_add_keyword("Enlightened", "+X% crit chance for next Y attacks", Color(1.0, 1.0, 0.6))
	_add_keyword("Strengthen", "+X damage on next Y attacks", Color(1.0, 0.5, 0.3))
	_add_keyword("Bolster", "+X armor next Y times you gain armor", Color(0.5, 0.7, 1.0))
	_add_keyword("Haste", "+X movement per tempo spent", Color(0.5, 1.0, 1.0))
	_add_keyword("Cleanse", "Remove X negative effects (instant)", Color(1.0, 1.0, 1.0))
	_add_keyword("Smith", "Gain X armor per cycle", Color(0.7, 0.7, 0.7))
	_add_keyword("Steady", "Next action does not add tempo", Color(0.6, 0.8, 0.6))
	_add_keyword("Brace", "Reduce incoming attack damage by X% for Y attacks", Color(0.5, 0.5, 0.8))
	_add_keyword("Resilient", "Reduce all incoming damage by X% for Y tempo", Color(0.7, 0.6, 0.9))
	_add_keyword("Life Steal", "Next attack heals you for damage dealt", Color(0.9, 0.2, 0.4))
	_add_keyword("Morphine", "Gain temp armor. Lose it and take 2 damage when expired", Color(1.0, 0.6, 0.8))
	_add_keyword("Wear Down", "Each attack reduces target's attack by 1 (stacks) for X tempo", Color(0.9, 0.6, 0.3))

	# Overflow Section
	_add_section_header("OVERFLOW MODES")
	_add_keyword("Jailed", "Card goes to jail for 3 turns, cannot be played")
	_add_keyword("Manifest", "Card goes to manifest zone as a token. Click to activate the manifest effect, then card is discarded")
	_add_keyword("Enhance", "Attack cards gain +X bonus damage, then discarded")
	_add_keyword("Transferred", "Overflow card is sent to the discard pile")
	_add_keyword("Peak", "See the next card on draw pile (doesn't block other effects)")
	_add_keyword("Overcharge", "Triggers an effect when overflow occurs (doesn't block other effects)")

	# Range Section
	_add_section_header("RANGE")
	_add_keyword("Melee", "Card must be used at close range (default for all cards)", Color(0.9, 0.6, 0.3))
	_add_keyword("Ranged", "Card can be used at distance. Base range = 5 tiles. Ranged +X = 5+X, Ranged -X = 5-X", Color(0.3, 0.8, 0.9))

	# AOE Section
	_add_section_header("AOE (AREA OF EFFECT)")
	_add_keyword("Circle", "Hits all enemies within a radius around the target point", Color(0.9, 0.5, 0.2))
	_add_keyword("Cone", "Hits enemies in a cone in front of the caster", Color(0.9, 0.5, 0.2))
	_add_keyword("Line", "Hits enemies in a line from the caster", Color(0.9, 0.5, 0.2))

	# Card-Item Slot Section
	_add_section_header("CARD-ITEM SLOTS")
	_add_keyword("Enchant", "Places a card into an item's card slot. Card is removed from the deck. Picky cards must match item type", Color(0.8, 0.6, 1.0))
	_add_keyword("Extract", "Removes a card from an item. Must destroy either the item or the card to do so", Color(1.0, 0.4, 0.4))
	_add_keyword("Molded", "Card is locked into the item and cannot be removed (extracted)", Color(0.6, 0.6, 0.6))
	_add_keyword("Picky", "Card can only be re-equipped to an item of the same type it was extracted from", Color(1.0, 0.8, 0.3))
	_add_keyword("Pliable", "Card can be re-equipped to an item of any type", Color(0.3, 1.0, 0.7))
	_add_keyword("On-Self", "Bonus effects that apply to cards slotted in that specific item, on top of the item's base bonuses", Color(0.6, 0.9, 0.6))

	# Movement Section
	_add_section_header("MOVEMENT")
	_add_keyword("Pass-Through", "Moving through a tile occupied by another unit always costs 2 tempo, regardless of movement speed or free moves", Color(1.0, 0.5, 0.5))

	# Card Types Section
	_add_section_header("CARD TYPES")
	_add_keyword("Attack", "Offensive cards that deal damage", Color(1, 0.3, 0.3))
	_add_keyword("Defense", "Protective cards that grant armor or block", Color(0.3, 0.5, 1))
	_add_keyword("Utility", "Support cards for draw, healing, buffs, etc.", Color(0.3, 1, 0.3))
	_add_keyword("Reaction", "Triggers automatically from hand when a condition is met (e.g., on damage taken). Costs 0 mana and 0 tempo", Color(1, 0.8, 0.2))
	_add_keyword("Unplayable", "Cannot be played. Takes up a hand slot (e.g., Lightly Dazed)", Color(0.5, 0.5, 0.5))

	# Card Mechanics Section
	_add_section_header("CARD MECHANICS")
	_add_keyword("Empower", "Buffs the next X cards played: +3 damage for attacks, -3 mana cost for defense", Color(1, 0.85, 0.3))
	_add_keyword("On-Draw", "Card triggers an effect when drawn into hand (e.g., deal damage to a random enemy)", Color(0.5, 0.9, 0.5))
	_add_keyword("Sticky", "Card stays in hand for X uses before being discarded. Does not leave hand after playing", Color(0.8, 0.8, 0.3))
	_add_keyword("High Ground", "Ranged attacks from elevated positions deal +4 damage and gain +2 range. Some cards require high ground", Color(0.6, 0.4, 0.2))
	_add_keyword("Cycle", "1 cycle = every 5 tempo. Mana regen, card draws, buff/debuff ticks, and armor decay all happen per cycle", Color(0.7, 0.7, 0.9))

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
