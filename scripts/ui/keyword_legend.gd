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
	_add_keyword("Strength (STR)", "+10 carry capacity per point, +0.5 physical damage per point")
	_add_keyword("Dexterity (DEX)", "-0.5 attack speed counter per point (base 45). At 0 counter: next attack costs 20 less mana + half tempo. Also +3% crit damage per point (base 110%)")
	_add_keyword("Intelligence (INT)", "+0.5 spell damage per point, +1 mana regen per point")
	_add_keyword("Wisdom (WIS)", "Each WIS point grants 1 Brain point, refreshed every 5 cycles. Spent by choice via the Brain row: eye = Peek the next unseen draw-pile card (5, +2 per peek that window), card+ = Insight, draw a card (5, then 10/15/20/25 that window). Secondary: +1 hand size per 10 points")
	_add_keyword("Agility (AGI)", "Each AGI point grants 1 Flash point, refreshed every 3 cycles. Spent by choice via the Flash row: boots toggle = 3 Flash per tile moved (no tempo), sidestep = 3 Flash for 2 block, daggers = 5 Flash for 1 attack-speed tick. Otherwise each tile costs 1 tempo.")
	_add_keyword("Action Points", "The parent category over Flash points (AGI, the body) and Brain points (WIS, the mind). The pools are independent — separate counts, refresh timers, and spends — but effects can interact with Action Points broadly or either pool specifically.")
	_add_keyword("Determination (DET)", "Modifies STR/DEX/INT/WIS/AGI at low health thresholds. DET 15 = no effect. Above 15 = bonus when hurt, below 15 = penalty when hurt")

	# Debuffs Section
	_add_section_header("DEBUFFS")
	_add_keyword("Bleed", "Take X damage per tile moved.", Color(0.8, 0.1, 0.1))
	_add_keyword("Stun", "Can't act. Only Wait passes time.", Color(1.0, 1.0, 0.0))
	_add_keyword("Disarm", "Can't play attack cards or auto attack for X tempo.", Color(0.6, 0.3, 0.1))
	_add_keyword("Silence", "Can't play spell cards for X tempo.", Color(0.5, 0.0, 0.8))
	_add_keyword("Burn", "Damage doubles each cycle (1, 2, 4...). Attacking while burning also deals it.", Color(1.0, 0.5, 0.0))
	_add_keyword("Poison", "Take X damage per cycle. Loses 1 per cycle.", Color(0.2, 0.8, 0.2))
	_add_keyword("Cursed", "Deal 20% less damage, and take 20% of the damage you deal.", Color(0.3, 0.0, 0.3))
	_add_keyword("Frozen", "Can't play cards, auto attack or block.", Color(0.5, 0.8, 1.0))
	_add_keyword("Cuffed", "Can't draw cards.", Color(0.5, 0.5, 0.5))
	_add_keyword("Shocked", "Each cycle, deals X damage to nearby allies (a shocked enemy takes it). Loses 1 per cycle.", Color(1.0, 1.0, 0.3))
	_add_keyword("Slowed", "Moving costs 3 tempo per tile. Each stack lasts 5 tempo.", Color(0.3, 0.3, 0.6))
	_add_keyword("Staggered", "Attack cards cost +15 mana. Each stack lasts 5 tempo.", Color(0.6, 0.4, 0.2))
	_add_keyword("Drain", "Lose 10 mana per cycle. Loses 1 per cycle.", Color(0.4, 0.0, 0.6))
	_add_keyword("Weighted", "Cards cost +2 tempo. Each card played removes a stack.", Color(0.4, 0.4, 0.4))
	_add_keyword("Hexed", "A random card costs +X mana until played.", Color(0.6, 0.0, 0.6))
	_add_keyword("Locked", "A random card can't be played.", Color(0.3, 0.3, 0.3))
	_add_keyword("Rooted", "Can't move for X tempo.", Color(0.4, 0.25, 0.1))
	_add_keyword("Tripped", "Moves 4 fewer tiles per move (no step if that leaves none)", Color(0.5, 0.7, 1.0))
	_add_keyword("Clumsy", "30% chance to discard a random card when you play one. Each stack lasts 5 tempo.", Color(0.9, 0.6, 0.2))
	_add_keyword("Vulnerable", "Take 30% more damage. Each stack lasts 5 tempo.", Color(1.0, 0.3, 0.3))
	_add_keyword("Blind", "Attacks have an 80% chance to miss. Each stack lasts 5 tempo.", Color(0.85, 0.85, 0.4))
	_add_keyword("Exposed", "Armor broken. Can't be Exposed again for 10 tempo.", Color(0.9, 0.7, 0.5))
	_add_keyword("Brittle", "Armor decays 2 extra per cycle. Each stack lasts 5 tempo.", Color(0.7, 0.7, 0.6))
	_add_keyword("Weakened", "Deal 30% less damage. Each stack lasts 5 tempo.", Color(0.5, 0.5, 0.8))
	_add_keyword("Cold", "At 5 stacks, Frozen for 1 cycle. Each stack lasts 5 tempo.", Color(0.4, 0.7, 1.0))

	# Buffs Section
	_add_section_header("BUFFS")
	_add_keyword("Thorns", "Attackers take X damage. Loses 1 per hit.", Color(0.8, 0.4, 0.8))
	_add_keyword("Focused", "+10 mana per cycle.", Color(0.4, 0.6, 1.0))
	_add_keyword("Regen", "Heal X per cycle. Loses 1 per cycle.", Color(0.4, 1.0, 0.4))
	_add_keyword("Blessed", "Draw X extra card(s) per cycle for Y cycles.", Color(1.0, 0.9, 0.5))
	_add_keyword("Fortify", "Your armor doesn't decay.", Color(0.6, 0.6, 0.8))
	_add_keyword("Enlightened", "+X% crit chance on your next Y crit rolls.", Color(1.0, 1.0, 0.6))
	_add_keyword("Strengthen", "+X damage on your next Y attacks.", Color(1.0, 0.5, 0.3))
	_add_keyword("Bolster", "+X armor the next Y times you gain armor.", Color(0.5, 0.7, 1.0))
	_add_keyword("Haste", "+X free tiles on each of your next Y moves.", Color(0.5, 1.0, 1.0))
	_add_keyword("Engrave", "Only joins your deck while slotted in an item.", Color(0.75, 0.65, 0.4))
	_add_keyword("Cleanse", "Removes X debuffs.", Color(1.0, 1.0, 1.0))
	_add_keyword("Smith", "Gain X armor per cycle. Loses 1 per cycle.", Color(0.7, 0.7, 0.7))
	_add_keyword("Steady", "Your next action costs no tempo.", Color(0.6, 0.8, 0.6))
	_add_keyword("Brace", "Take X% less attack damage for Y attacks.", Color(0.5, 0.5, 0.8))
	_add_keyword("Resilient", "Take X% less damage for Y tempo.", Color(0.7, 0.6, 0.9))
	_add_keyword("Life Steal", "Your next attack heals you for the damage it deals.", Color(0.9, 0.2, 0.4))
	_add_keyword("Morphine", "Gain temporary health. When it ends, lose it and take 2 damage.", Color(1.0, 0.6, 0.8))
	_add_keyword("Wear Down", "Each of your attacks lowers the target's attack by 1 for X tempo.", Color(0.9, 0.6, 0.3))
	_add_keyword("Armor Break", "Your next attack deals double damage to armor.", Color(0.8, 0.6, 0.2))
	_add_keyword("Keen", "+X% crit chance for Y tempo", Color(1.0, 0.9, 0.3))
	_add_keyword("Might", "+X STR for Y tempo (damage, not carry weight)", Color(1.0, 0.4, 0.2))

	# Overflow Section
	_add_section_header("OVERFLOW MODES")
	_add_keyword("Jailed", "Can't be played for 15 tempo.")
	_add_keyword("Manifest", "Becomes a token in the manifest zone. Click it to use it.")
	_add_keyword("Enhance", "Your attack cards gain +X damage, then this is discarded.")
	_add_keyword("Skip", "Goes straight to the discard pile.")
	_add_keyword("Peak", "See the top card of your draw pile.")
	_add_keyword("Overcharge", "Triggers when you overflow.")
	_add_keyword("Overdraw", "Equipment riders that fire whenever a draw overflows a full hand — they pay out alongside whichever overflow mode is set")

	# Range Section
	_add_section_header("RANGE")
	_add_keyword("Melee", "Used at close range.", Color(0.9, 0.6, 0.3))
	_add_keyword("Ranged", "Used at a distance. Base range 5.", Color(0.3, 0.8, 0.9))
	_add_keyword("Conditional", "Ranged with a bow (+1 tempo), melee otherwise. Attack cards are also ranged with a magic weapon.", Color(0.6, 0.8, 0.7))

	# AOE Section
	_add_section_header("AOE (AREA OF EFFECT)")
	_add_keyword("Circle", "Hits all enemies within a radius around the target point", Color(0.9, 0.5, 0.2))
	_add_keyword("Cone", "Hits a cone in front of you.", Color(0.9, 0.5, 0.2))
	_add_keyword("Line", "Hits a line from you.", Color(0.9, 0.5, 0.2))

	# Card-Item Slot Section
	_add_section_header("CARD-ITEM SLOTS")
	_add_keyword("Enchant", "Slots a card into an item.", Color(0.8, 0.6, 1.0))
	_add_keyword("Extract", "Removes a card from an item.", Color(1.0, 0.4, 0.4))
	_add_keyword("On-Self", "Extra bonus for cards slotted in this item.", Color(0.6, 0.9, 0.6))

	# Movement Section
	_add_section_header("MOVEMENT")
	_add_keyword("Pass-Through", "Moving past an enemy costs 2 extra tempo for that tile.", Color(1.0, 0.5, 0.5))

	# Card Types Section
	_add_section_header("CARD TYPES")
	_add_keyword("Attack", "Deals damage.", Color(1, 0.3, 0.3))
	_add_keyword("Defense", "Gives armor or blocks.", Color(0.3, 0.5, 1))
	_add_keyword("Utility", "Draw, heal, move, buff and other support.", Color(0.3, 1, 0.3))
	_add_keyword("Power", "Stays in play while you pay its Maintain cost.", Color(0.8, 0.5, 1.0))
	_add_keyword("Unplayable", "Can't be played. Takes a hand slot.", Color(0.5, 0.5, 0.5))

	# Card Keywords Section
	_add_section_header("CARD KEYWORDS")
	_add_keyword("Arrow", "Bow attack. Slots into a bow or quiver.", Color(0.3, 0.8, 0.9))
	_add_keyword("Pocket", "Slots into belts.", Color(0.8, 0.6, 0.3))
	_add_keyword("Gem", "Slots into rings.", Color(0.6, 0.3, 0.9))
	_add_keyword("Crown", "Slots into helmets.", Color(1.0, 0.85, 0.2))
	_add_keyword("Buckler", "Slots into shields.", Color(0.5, 0.7, 0.9))
	_add_keyword("Fist", "Slots into gauntlets.", Color(0.9, 0.5, 0.4))
	_add_keyword("Swift", "Slots into boots.", Color(0.4, 0.9, 0.7))

	# Card Mechanics Section
	_add_section_header("CARD MECHANICS")
	_add_keyword("Erase", "Removed from your deck after X tempo in your hand. Curse and status cards also count down in the draw and discard piles.", Color(0.9, 0.2, 0.2))
	_add_keyword("On-Draw", "Triggers when drawn.", Color(0.5, 0.9, 0.5))
	_add_keyword("On-Discard", "Triggers when discarded.", Color(1.0, 0.5, 0.3))
	_add_keyword("In-Hand", "Has an effect while in your hand.", Color(0.7, 0.5, 0.9))
	_add_keyword("Sticky", "Stays in your hand for X plays.", Color(0.8, 0.8, 0.3))
	_add_keyword("High Ground", "Ranged offensive cards played from high ground: +4 damage, +2 range.", Color(0.6, 0.4, 0.2))
	_add_keyword("Maintain", "Reserves X of your max mana while active. At 0 mana, all maintained cards are discarded.", Color(0.8, 0.5, 1.0))
	_add_keyword("Cycle", "Every 5 tempo. Mana regen and status ticks happen each cycle. You draw a card every 5 cycles.", Color(0.7, 0.7, 0.9))
	_add_keyword("Glut", "You can't play cards for X tempo.", Color(0.9, 0.4, 0.4))
	_add_keyword("Delay", "Takes effect after X tempo.", Color(0.6, 0.6, 0.9))
	_add_keyword("Instant", "Plays itself from your hand when its condition is met. Costs 0 mana.", Color(1.0, 1.0, 0.5))
	_add_keyword("Linger", "Can go over your hand limit. While it lingers, each draw overflows.", Color(0.7, 0.3, 0.3))

	# Enemy action keywords — how a creature's tempo clocks behave.
	_add_section_header("ENEMY ACTIONS")
	_add_keyword("Sync", "Default. One clock: the enemy winds up one action at a time.", Color(1.0, 0.85, 0.0))
	_add_keyword("Async", "Has its own clock and fires every N tempo, whatever else the enemy is doing. Blue on the tempo bar.", Color(0.55, 0.8, 1.0))
	_add_keyword("Channel", "For its last N tempo the enemy can't move or act, and its other clocks pause. Orange on the tempo bar.", Color(1.0, 0.55, 0.2))
	_add_keyword("Disruptable", "Deal X damage while it winds up or channels and it starts over.", Color(0.9, 0.4, 0.4))
	_add_keyword("Non-interruptible", "Default. Damage doesn't stop it.", Color(0.6, 0.6, 0.65))
	_add_keyword("Immediate", "Default. Resolves the moment its tempo comes up.", Color(0.6, 0.6, 0.65))
	_add_keyword("Trigger", "No clock. Fires when something happens: hit, armor broken, an ally dies, under half health.", Color(0.8, 0.6, 1.0))

func _add_section_header(title: String) -> void:
	var header = Label.new()
	header.text = "\n" + title
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	content.add_child(header)
	
	var separator = HSeparator.new()
	content.add_child(separator)

func _add_keyword(keyword: String, description: String, color: Color = Color.WHITE) -> void:
	# One wording everywhere: a keyword the cards define reads the same here.
	var shared: String = str(Card.get_keyword_definitions().get(keyword.to_lower(), ""))
	if shared != "":
		description = shared
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size.y = 30
	
	var keyword_label = Label.new()
	keyword_label.text = keyword + ": "
	keyword_label.add_theme_color_override("font_color", color)
	keyword_label.add_theme_font_size_override("font_size", 16)
	keyword_label.custom_minimum_size.x = 150
	hbox.add_child(keyword_label)
	
	var desc_label = Label.new()
	desc_label.text = description
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(desc_label)
	
	content.add_child(hbox)
