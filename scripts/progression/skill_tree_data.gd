class_name SkillTreeData
extends RefCounted

## Defines a character's skill tree progression.
## Each level adds a row with 4 chooseable options + 1 auto-granted reward.
## The player picks ONE of the 4 options; the other 3 are blacked out.

# Option types for the 4 chooseable columns
enum OptionType {
	CARD,           # Grants a new card to the deck
	PASSIVE,        # Grants a passive ability
	STAT_BONUS,     # Flat stat increase
}

# Auto-grant types for the 5th column
enum AutoGrantType {
	STAT_ALLOCATION,  # Legacy — stat points now come from every level-up (PlayerStats)
	CARD_REMOVAL,     # Remove a card from deck
	HEALTH_BOOST,     # Flat max health increase
	MANA_BOOST,       # Flat max mana increase
	PASSIVE,          # Auto-granted passive
}

## A single chooseable option within a skill tree row (columns 1-4)
class SkillOption:
	var option_type: OptionType = OptionType.CARD
	var name: String = ""
	var description: String = ""
	var icon_color: Color = Color.WHITE  # For UI display

	# Type-specific data
	var card_id: String = ""              # For CARD type
	var passive_id: String = ""           # For PASSIVE
	var passive_data: Dictionary = {}     # trigger, effect, value, chance, etc.
	var stat_type: String = ""            # For STAT_BONUS: "strength", "dexterity", etc.
	var stat_amount: int = 0              # For STAT_BONUS

	func get_type_label() -> String:
		match option_type:
			OptionType.CARD: return "Card"
			OptionType.PASSIVE: return "Passive"
			OptionType.STAT_BONUS: return "Stat Bonus"
		return "Unknown"

## The auto-granted 5th column reward for a row
class AutoGrant:
	var grant_type: AutoGrantType = AutoGrantType.CARD_REMOVAL
	var name: String = ""
	var description: String = ""
	var stat_points: int = 5             # For STAT_ALLOCATION
	var card_id: String = ""             # For CARD_REMOVAL target
	var health_amount: int = 0           # For HEALTH_BOOST
	var mana_amount: int = 0             # For MANA_BOOST
	var passive_data: Dictionary = {}    # For PASSIVE auto-grants

	func get_type_label() -> String:
		match grant_type:
			AutoGrantType.STAT_ALLOCATION: return "+%d Stats" % stat_points
			AutoGrantType.CARD_REMOVAL: return "Remove Card"
			AutoGrantType.HEALTH_BOOST: return "+%d Health" % health_amount
			AutoGrantType.MANA_BOOST: return "+%d Mana" % mana_amount
			AutoGrantType.PASSIVE: return "Passive"
		return "Unknown"

## One row of the skill tree (one per level)
class SkillRow:
	var level: int = 1
	var options: Array[SkillOption] = []  # Exactly 4 chooseable options
	var auto_grant: AutoGrant = null      # The 5th auto-granted reward
	var chosen_index: int = -1            # Which option was chosen (-1 = not yet chosen)

	func is_chosen() -> bool:
		return chosen_index >= 0 or chosen_index == -2  # -2 = chose from a previous level

	func get_chosen_option() -> SkillOption:
		if chosen_index >= 0 and chosen_index < options.size():
			return options[chosen_index]
		return null

## The full skill tree for a character
var character_name: String = ""
var rows: Array[SkillRow] = []

## Get the row for a specific level (returns null if not defined)
func get_row_for_level(level: int) -> SkillRow:
	for row in rows:
		if row.level == level:
			return row
	return null

## Get all rows up to and including a given level
func get_rows_up_to_level(level: int) -> Array[SkillRow]:
	var result: Array[SkillRow] = []
	for row in rows:
		if row.level <= level:
			result.append(row)
	return result

## Get the highest level that has a row defined
func get_max_defined_level() -> int:
	var max_level: int = 0
	for row in rows:
		if row.level > max_level:
			max_level = row.level
	return max_level

## Choose an option for a specific level's row. Returns true if successful.
func choose_option(level: int, option_index: int) -> bool:
	var row = get_row_for_level(level)
	if not row:
		return false
	if row.is_chosen():
		return false  # Already chosen
	if option_index < 0 or option_index >= row.options.size():
		return false
	row.chosen_index = option_index
	return true

## Use a retrospective token (from sphere grid) to pick an ADDITIONAL option
## from an already-chosen row. This is a bonus on top of the normal choice.
## The chosen_index stays the same, but the extra pick is tracked in retrospective_picks.
var retrospective_picks: Dictionary = {}  # level -> Array[int] of additional option indices

## Tracks which retro level was used when a player chose a previous option instead
## of their current level's options. Maps retro_level -> {source_level, option_index}.
var retro_level_choices: Dictionary = {}  # retro_level -> {source_level: int, option_index: int}

## Check if a level is a retrospective level (every 3rd level starting at 3).
## On these levels, the player can choose a previously skipped option instead of
## one of their current 4 options. This counts as their choice for the level.
static func is_retrospective_level(level: int) -> bool:
	return level >= 3 and level % 3 == 0

## Check if a retro level's choice has been used (player picked a previous option).
func is_retro_level_used(retro_level: int) -> bool:
	return retro_level in retro_level_choices

## Get the current retro level that hasn't been chosen yet (if the player is on one).
## Returns the retro level if the player is on one and hasn't chosen yet, else -1.
func get_pending_retro_level(current_level: int) -> int:
	if not is_retrospective_level(current_level):
		return -1
	var row = get_row_for_level(current_level)
	if not row:
		return -1
	# If the current row already has a normal choice, retro option is gone
	if row.is_chosen():
		return -1
	# If already used the retro choice for this level, it's gone too
	if is_retro_level_used(current_level):
		return -1
	return current_level

## Use the retro level's free pick — choose a previous skipped option instead of
## the current level's options. This also marks the current retro level row as chosen
## (with chosen_index = -2 to indicate "chose retrospectively").
func retro_level_choose_previous(retro_level: int, source_level: int, option_index: int) -> bool:
	if not is_retrospective_level(retro_level):
		return false
	if is_retro_level_used(retro_level):
		return false
	var retro_row = get_row_for_level(retro_level)
	if not retro_row or retro_row.is_chosen():
		return false
	if not can_retrospective_pick(source_level, option_index):
		return false
	# Mark the retro level as used with a retrospective choice
	retro_level_choices[retro_level] = {"source_level": source_level, "option_index": option_index}
	retro_row.chosen_index = -2  # Special value: "chose from a previous level"
	# Track the actual pick on the source row
	if source_level not in retrospective_picks:
		retrospective_picks[source_level] = []
	retrospective_picks[source_level].append(option_index)
	return true

func can_retrospective_pick(level: int, option_index: int) -> bool:
	var row = get_row_for_level(level)
	if not row or not row.is_chosen():
		return false
	if option_index == row.chosen_index:
		return false  # Already the chosen option
	if option_index < 0 or option_index >= row.options.size():
		return false
	# Check if already retrospective-picked this option
	if level in retrospective_picks:
		if option_index in retrospective_picks[level]:
			return false
	return true

func retrospective_pick(level: int, option_index: int) -> bool:
	if not can_retrospective_pick(level, option_index):
		return false
	if level not in retrospective_picks:
		retrospective_picks[level] = []
	retrospective_picks[level].append(option_index)
	return true

func is_retrospective_picked(level: int, option_index: int) -> bool:
	if level not in retrospective_picks:
		return false
	return option_index in retrospective_picks[level]

func get_rows_with_skipped_options(max_level: int) -> Array[SkillRow]:
	## Returns rows that have been chosen but still have unpicked options available.
	var result: Array[SkillRow] = []
	for row in rows:
		if row.level > max_level:
			continue
		if not row.is_chosen():
			continue
		# Check if there are any unchosen, non-retrospective-picked options
		for i in range(row.options.size()):
			if i != row.chosen_index and not is_retrospective_picked(row.level, i):
				result.append(row)
				break
	return result

## The auto-granted 5th-column reward for a level, or null when the level
## carries none. Schedule: levels 2, 5, 10, 15, 20 ... grant a Culling Stone;
## every other level's reward is its 4 chooseable options alone.
## (Stat points are no longer a scheduled grant — every level-up banks
## +3 points directly on PlayerStats, allocated from the skill tree screen.)
static func create_auto_grant_for_level(level: int) -> AutoGrant:
	var removal_levels := [2, 5, 10, 15, 20, 25, 30]
	if level not in removal_levels:
		return null
	var auto = AutoGrant.new()
	auto.grant_type = AutoGrantType.CARD_REMOVAL
	auto.name = "Culling Stone"
	auto.description = "Remove 1 card from your deck"
	return auto

# ============================================
# PLACEHOLDER TREE BUILDERS (one per character)
# ============================================
# These create empty/placeholder skill trees with proper structure.
# The actual options will be filled in later.

static func create_placeholder_tree(char_name: String, max_level: int = 20, archetypes: Array = []) -> SkillTreeData:
	var tree = SkillTreeData.new()
	tree.character_name = char_name

	for lvl in range(2, max_level + 1):  # Start at level 2 (level 1 is starting state)
		var row = SkillRow.new()
		row.level = lvl

		# Create 4 placeholder options, named by archetype if available
		for i in range(4):
			var opt = SkillOption.new()
			if i < archetypes.size():
				var arch = archetypes[i]
				opt.name = "%s Lv%d" % [arch["name"], lvl]
				opt.description = arch["description"]
			else:
				opt.name = "%s Lv%d Option %d" % [char_name, lvl, i + 1]
				opt.description = "Placeholder - to be defined"
			opt.option_type = OptionType.CARD if i < 2 else OptionType.PASSIVE
			opt.icon_color = _get_option_color(i)
			row.options.append(opt)

		# Auto-grant column: only Culling Stone levels carry one now
		row.auto_grant = create_auto_grant_for_level(lvl)

		tree.rows.append(row)

	return tree

## Brad-specific skill tree with archetype abilities spread across levels.
## Each archetype ability appears as one of the 4 options on its row,
## mixed in alongside other option types at various levels.
static func create_brad_tree(max_level: int = 20) -> SkillTreeData:
	var tree = SkillTreeData.new()
	tree.character_name = "Brad"

	# Archetype ability pool — each entry: {level, slot, archetype, name, description, color}
	# Spread across levels so passives can appear at any level
	var ability_placements := [
		{level = 2, slot = 0, archetype = "Berserker", name = "Enraged Will",
			description = "When you drop below 25% HP, perform a Reach AOE swing hitting all nearby enemies. Gain 1 mana per kill. Cooldown: 10 tempo",
			color = Color(0.9, 0.3, 0.3)},
		{level = 3, slot = 1, archetype = "Warden", name = "In the Trenches",
			description = "When an enemy enters an adjacent square, perform a free attack. When an enemy attacks you from adjacent, knock them back. 2 charges, 10 tempo cooldown",
			color = Color(0.3, 0.7, 1.0)},
		{level = 4, slot = 2, archetype = "The Ancient", name = "Stone Skin",
			description = "Gain 10% Fire, Physical and Lightning resistance",
			color = Color(0.4, 0.9, 0.4)},
		{level = 5, slot = 3, archetype = "The Fallen", name = "Point to Prove",
			description = "When stunned or disarmed, choose to sacrifice 5 HP to ignore the ailment",
			color = Color(0.8, 0.4, 0.9)},
		{level = 6, slot = 2, archetype = "The Fallen", name = "Corrupted Strength",
			description = "While 3+ enemies are within 3 tiles: +5 damage on attacks and +5 armor per cycle, but lose 2 HP per cycle and allies cannot heal you",
			color = Color(0.8, 0.4, 0.9)},
		{level = 7, slot = 1, archetype = "Berserker", name = "Directed Strength",
			description = "Gain 5 strength when below 50% health, lose it when going above",
			color = Color(0.9, 0.3, 0.3)},
		{level = 10, slot = 2, archetype = "Warden", name = "Phalanx",
			description = "When struck by a melee attack, deal damage back equal to the number of Defense cards in your hand",
			color = Color(0.3, 0.7, 1.0)},
		{level = 12, slot = 2, archetype = "Warden", name = "Sword Specialist",
			description = "+25% block from all sources while only wielding swords",
			color = Color(0.3, 0.7, 1.0)},
		{level = 8, slot = 0, archetype = "Warden", name = "The Way of the Plate",
			description = "Every other Defense card refunds 1 mana and 1 tempo",
			color = Color(0.3, 0.7, 1.0)},
		{level = 9, slot = 3, archetype = "The Ancient", name = "Ancestral Aid",
			description = "Each cycle: more attacks in hand → discount a random attack by 2m. More defense → heal 3 HP",
			color = Color(0.4, 0.9, 0.4)},
		{level = 11, slot = 2, archetype = "The Fallen", name = "Redemption",
			description = "When healing (self or ally), gain crit chance on your next attack",
			color = Color(0.8, 0.4, 0.9)},
		{level = 13, slot = 0, archetype = "Berserker", name = "Life Steal",
			description = "All attacks life steal by 5%",
			color = Color(0.9, 0.3, 0.3)},
		{level = 14, slot = 2, archetype = "Warden", name = "Pristine Armor",
			description = "Defense cards grant +2 armor. Playing 3 defense cards in a row grants an additional +5 armor",
			color = Color(0.3, 0.7, 1.0)},
		{level = 16, slot = 1, archetype = "The Ancient", name = "Vines Codependence",
			description = "Whenever you heal, gain 3 thorns",
			color = Color(0.4, 0.9, 0.4)},
		{level = 18, slot = 3, archetype = "The Fallen", name = "Solemn Independence",
			description = "When 3+ enemies are within 2 tiles: +5 damage on all attacks, +5 armor per tempo cycle, but cannot be healed by allies",
			color = Color(0.8, 0.4, 0.9)},
	]

	# Card reward placements — character-specific cards offered as chooseable options
	var card_placements := [
		{level = 2, slot = 1, card_id = "poke", name = "Poke", description = "Deal 2 damage. (0 mana, 0 tempo)"},
		{level = 3, slot = 0, card_id = "wear_down", name = "Wear Down", description = "Decrease enemy attack by 1 per consecutive hit. Lasts 15 tempo. (0 mana, 1 tempo)"},
		{level = 4, slot = 1, card_id = "roar", name = "Roar", description = "Knock enemies back 1 space. (1 mana, 2 tempo)"},
		{level = 5, slot = 0, card_id = "life_steal", name = "Life Steal", description = "Heal for the amount of damage done on next hit. (1 mana, 2 tempo)"},
		{level = 6, slot = 0, card_id = "parry", name = "Parry", description = "Gain 5 armor, deal 5 damage. Next damage to you is reduced. (1 mana, 5 tempo)"},
		{level = 7, slot = 0, card_id = "morphine", name = "Morphine", description = "Gain 4 temp HP. After 3 turns, lose it and take 2 damage. (3 mana, 0 tempo)"},
		{level = 8, slot = 1, card_id = "approach", name = "Approach", description = "Slowed for 10 tempo. For each movement taken, gain 5 armor. (1 mana, 3 tempo)"},
		{level = 9, slot = 0, card_id = "taunt", name = "Taunt", description = "Taunt enemies around you. They must target you. (4 mana, 0 tempo)"},
		{level = 10, slot = 0, card_id = "charge", name = "Charge", description = "Charge forward, deal 8 damage to all enemies hit and knock them back. (2 mana, 4 tempo)"},
		{level = 11, slot = 0, card_id = "turtle_up", name = "Turtle Up", description = "Armor does not decay for 20 tempo. (3 mana, 0 tempo)"},
		{level = 12, slot = 0, card_id = "armor_break", name = "Armor Break", description = "Next attack deals double damage to armor only. (3 mana, 4 tempo)"},
		{level = 14, slot = 0, card_id = "life_swap", name = "Life Swap", description = "Exchange HP and mana pools. Deal damage equal to HP lost. (4 mana, 4 tempo)"},
		{level = 16, slot = 0, card_id = "heroic_leap", name = "Heroic Leap", description = "Jump based on STR. Deal 12 damage based on distance leaped. AOE circle. (4 mana, 5 tempo)"},
		{level = 18, slot = 0, card_id = "hold_the_line", name = "Hold the Line", description = "All allies gain 5 armor, +2 DET, and +2 STR. (4 mana, 5 tempo)"},
		{level = 2, slot = 2, card_id = "internal_combustion", name = "Internal Combustion", description = "Remove half your armor and deal damage around you based on the amount. (4 mana, 5 tempo)"},
		{level = 3, slot = 2, card_id = "savage_strike", name = "Savage Strike", description = "Deal 6 damage. Add a copy with Erase 20 to your discard pile. (2 mana, 2 tempo)"},
		{level = 4, slot = 0, card_id = "heavy_swing", name = "Heavy Swing", description = "Can only be played if only attack cards are in your hand. Deal 20 damage. (3 mana, 3 tempo)"},
		{level = 5, slot = 1, card_id = "shed_weight", name = "Shed Weight", description = "Discard all defensive cards. For each discarded, subtract 1 tempo from a non-defensive card. (4 mana, 2 tempo)"},
		{level = 6, slot = 1, card_id = "give_in", name = "Give In", description = "Gain 3 mana. Next tempo-triggered draw is skipped. (0 mana, 2 tempo)"},
		{level = 9, slot = 1, card_id = "shield_slam", name = "Shield Slam", description = "Deal damage based on your current armor. Lose half your armor. (5 mana, 10 tempo)"},
		{level = 10, slot = 1, card_id = "tower_shield", name = "Tower Shield", description = "Gain 40 armor. Become staggered for 40 tempo. (5 mana, 5 tempo)"},
		{level = 11, slot = 1, card_id = "living_armor", name = "Living Armor", description = "Gain regen until it is equal to your fortify. (3 mana, 5 tempo)"},
		{level = 12, slot = 1, card_id = "the_lights_favor", name = "The Light's Favor", description = "Heal 5 and draw a card. (2 mana, 0 tempo)"},
		{level = 13, slot = 1, card_id = "hunker_down", name = "Hunker Down", description = "Gain Fortify for 30 tempo. (4 mana, 2 tempo)"},
		{level = 15, slot = 0, card_id = "succumb", name = "Succumb", description = "For 20 tempo: fortify, blessed 2, strengthen 5, resilient 20%. After 10 tempo: 10 damage. After 20: 10 more damage, cuffed, drained, disarmed for 10 tempo. (0 mana, 0 tempo)"},
		{level = 17, slot = 0, card_id = "harden", name = "Harden", description = "Gain 10% physical resistance for 15 tempo and 10 armor. (3 mana, 4 tempo)"},
		{level = 19, slot = 0, card_id = "roll", name = "Roll", description = "Roll X squares (max 5). On hitting an enemy, deal 10 damage and disarm for 5 tempo. (1 mana, 5 tempo)"},
	]

	# Index placements by level for quick lookup
	var placements_by_level := {}  # level -> {slot -> placement}
	for p in ability_placements:
		if p.level not in placements_by_level:
			placements_by_level[p.level] = {}
		placements_by_level[p.level][p.slot] = p

	var cards_by_level := {}  # level -> {slot -> card_placement}
	for c in card_placements:
		if c.level not in cards_by_level:
			cards_by_level[c.level] = {}
		cards_by_level[c.level][c.slot] = c

	for lvl in range(2, max_level + 1):
		var row = SkillRow.new()
		row.level = lvl

		var level_placements = placements_by_level.get(lvl, {})
		var level_card_placements = cards_by_level.get(lvl, {})

		for i in range(4):
			var opt = SkillOption.new()
			if i in level_placements:
				var p = level_placements[i]
				opt.name = p.name
				opt.description = "%s (%s): %s" % [p.name, p.archetype, p.description]
				opt.option_type = OptionType.PASSIVE
				opt.passive_id = p.name.to_lower().replace(" ", "_")
				opt.icon_color = p.color
			elif i in level_card_placements:
				var c = level_card_placements[i]
				opt.name = c.name
				opt.description = "%s: %s" % [c.name, c.description]
				opt.option_type = OptionType.CARD
				opt.card_id = c.card_id
				opt.icon_color = Color(1.0, 0.85, 0.3)
			else:
				opt.name = "Brad Lv%d Option %d" % [lvl, i + 1]
				opt.description = "Placeholder - to be defined"
				opt.option_type = OptionType.CARD if i < 2 else OptionType.PASSIVE
				opt.icon_color = _get_option_color(i)
			row.options.append(opt)

		# Auto-grant column: only Culling Stone levels carry one now
		row.auto_grant = create_auto_grant_for_level(lvl)

		tree.rows.append(row)

	return tree

static func create_stephen_tree(max_level: int = 20) -> SkillTreeData:
	var tree = SkillTreeData.new()
	tree.character_name = "Stephen"

	# Archetype ability pool — spread across levels so passives appear at various points
	# Colors: The Apex = red, Sentinel = blue, Ranger = green, Avenger = purple
	var ability_placements := [
		{level = 2, slot = 0, archetype = "The Apex", name = "Deadly",
			description = "+3 damage and +50% crit damage when the target has no allies within 2 spaces",
			color = Color(0.9, 0.3, 0.3)},
		{level = 3, slot = 1, archetype = "Sentinel", name = "Clean Exchange",
			description = "Anytime you draw a Defense card and the last card you played was an offensive card, or vice versa, give the drawn card -1 tempo",
			color = Color(0.3, 0.7, 1.0)},
		{level = 4, slot = 2, archetype = "Ranger", name = "Eagle Eye",
			description = "+2 range on ranged attacks",
			color = Color(0.4, 0.9, 0.4)},
		{level = 5, slot = 3, archetype = "Avenger", name = "Patience is a Virtue",
			description = "When receiving Glut, deal that much damage to an enemy in melee range and halve the Glut",
			color = Color(0.8, 0.4, 0.9)},
		{level = 7, slot = 1, archetype = "The Apex", name = "Easy Target",
			description = "When exposing your enemy, deal your damage again",
			color = Color(0.9, 0.3, 0.3)},
		{level = 8, slot = 0, archetype = "Sentinel", name = "Exposed Blind Spot",
			description = "When struck with a melee attack, gain crit chance on your next attack equal to the number of non-attack cards in your hand",
			color = Color(0.3, 0.7, 1.0)},
		{level = 9, slot = 3, archetype = "Ranger", name = "Scouted",
			description = "Hitting the same enemy 3 times in a row grants +6 range on your next attack and it auto-crits — usable against any enemy",
			color = Color(0.4, 0.9, 0.4)},
		{level = 11, slot = 2, archetype = "Avenger", name = "Swing for the Fences",
			description = "Cards that have >4 tempo cost deal their tempo cost as additional damage",
			color = Color(0.8, 0.4, 0.9)},
		{level = 13, slot = 0, archetype = "The Apex", name = "Skilled Momentum",
			description = "If you have played 4 attacks in a row, your 5th will be played twice",
			color = Color(0.9, 0.3, 0.3)},
		{level = 14, slot = 2, archetype = "Sentinel", name = "Lethal Resourcefulness",
			description = "If you have 3 or less cards in your hand, playing a non-attack card triggers a free basic attack",
			color = Color(0.3, 0.7, 1.0)},
		{level = 16, slot = 1, archetype = "Ranger", name = "Laced Arrow",
			description = "When applying burn, cold, or shock, apply 1 additional instance",
			color = Color(0.4, 0.9, 0.4)},
		{level = 18, slot = 3, archetype = "Avenger", name = "Dominate",
			description = "When triggering an attack speed proc, the proc resolves normally and you also gain a 0m/0t basic attack card (5 tempo cooldown)",
			color = Color(0.8, 0.4, 0.9)},
	]

	# Card reward placements — Stephen's archer/ranger cards
	var card_placements := [
		{level = 2, slot = 1, card_id = "quick_shot", name = "Quick Shot", description = "Deal 6 damage, draw a card. Ranged, Arrow. (1 mana, 1 tempo)"},
		{level = 3, slot = 0, card_id = "mixed_bag", name = "Mixed Bag", description = "Shoot a standard arrow, 7 damage. Ranged, Arrow. (1 mana, 1 tempo)"},
		{level = 4, slot = 0, card_id = "rise", name = "Rise", description = "Lift the earth creating a structure on the map. (1 mana, 4 tempo)"},
		{level = 5, slot = 0, card_id = "reload", name = "Reload", description = "Draw 3 cards. (3 mana, 3 tempo)"},
		{level = 6, slot = 0, card_id = "mark", name = "Mark", description = "Target receives extra damage from your attacks. Ranged +7. (3 mana, 0 tempo)"},
		{level = 7, slot = 0, card_id = "barricade", name = "Barricade", description = "Create a barricade of land in front of you. (3 mana, 2 tempo)"},
		{level = 8, slot = 1, card_id = "tighten_string", name = "Tighten String", description = "Next 3 ranged attacks: +3 tempo, +6 damage, +6 range, +20% crit. (3 mana, 3 tempo)"},
		{level = 9, slot = 0, card_id = "down_town", name = "Down Town", description = "Very long range (+7) shot, 12 damage. Arrow. (3 mana, 5 tempo)"},
		{level = 10, slot = 0, card_id = "sky_attack", name = "Sky Attack", description = "Leap and shoot arrow down, 10 damage. High Ground bonus. Arrow. (1 mana, 4 tempo)"},
		{level = 11, slot = 0, card_id = "enchanted_quiver", name = "Enchanted Quiver", description = "Next 3 ranged attacks create a free Quick Arrow in hand. (4 mana, 5 tempo)"},
		{level = 12, slot = 0, card_id = "last_breath", name = "Last Breath", description = "Consume all remaining mana. Deal 3 damage per mana spent. Arrow. (0 mana, 5 tempo)"},
		{level = 14, slot = 0, card_id = "sky_fall", name = "Sky Fall", description = "Shoot arrow upward. In 10 tempo, lands for 18 damage. Arrow. (3 mana, 5 tempo)"},
		{level = 15, slot = 0, card_id = "lead_arrow", name = "Lead Arrow", description = "1.8x damage (10 base). Requires high ground, lower range. Arrow. (3 mana, 5 tempo)"},
		{level = 16, slot = 0, card_id = "bottomless_quiver", name = "Bottomless Quiver", description = "Manifest 5: Overflow attack cards stored in quiver. (4 mana, 4 tempo)"},
		{level = 18, slot = 0, card_id = "collect_arrows", name = "Collect Arrows", description = "Place 2 attack cards from discard pile into hand. Glut: 15 tempo. (3 mana)"},
		{level = 13, slot = 1, card_id = "exhausted_assault", name = "Exhausted Assault", description = "While you have zero mana, costs 0 mana. Deal 4 damage 3 times. Glut 10. (4 mana, 3 tempo)"},
		{level = 17, slot = 0, card_id = "multishot", name = "Multishot", description = "Attack 3 times, each gaining 10% crit chance. Glut 5. (3 mana, 6 tempo)"},
		{level = 19, slot = 0, card_id = "specific_strike", name = "Specific Strike", description = "Costs +1m/+1t for each other card in your hand. (2 mana, 2 tempo)"},
		{level = 20, slot = 0, card_id = "spirit_arrow", name = "Spirit Arrow", description = "Arrow that shoots through all enemies and obstructions in a direct line. Arrow. (3 mana, 5 tempo)"},
	]

	# Index placements by level for quick lookup
	var placements_by_level := {}
	for p in ability_placements:
		if p.level not in placements_by_level:
			placements_by_level[p.level] = {}
		placements_by_level[p.level][p.slot] = p

	var cards_by_level := {}
	for c in card_placements:
		if c.level not in cards_by_level:
			cards_by_level[c.level] = {}
		cards_by_level[c.level][c.slot] = c

	for lvl in range(2, max_level + 1):
		var row = SkillRow.new()
		row.level = lvl

		var level_placements = placements_by_level.get(lvl, {})
		var level_card_placements = cards_by_level.get(lvl, {})

		for i in range(4):
			var opt = SkillOption.new()
			if i in level_placements:
				var p = level_placements[i]
				opt.name = p.name
				opt.description = "%s (%s): %s" % [p.name, p.archetype, p.description]
				opt.option_type = OptionType.PASSIVE
				opt.passive_id = p.name.to_lower().replace(" ", "_")
				opt.icon_color = p.color
			elif i in level_card_placements:
				var c = level_card_placements[i]
				opt.name = c.name
				opt.description = "%s: %s" % [c.name, c.description]
				opt.option_type = OptionType.CARD
				opt.card_id = c.card_id
				opt.icon_color = Color(1.0, 0.85, 0.3)
			else:
				opt.name = "Stephen Lv%d Option %d" % [lvl, i + 1]
				opt.description = "Placeholder - to be defined"
				opt.option_type = OptionType.CARD if i < 2 else OptionType.PASSIVE
				opt.icon_color = _get_option_color(i)
			row.options.append(opt)

		# Auto-grant column: only Culling Stone levels carry one now
		row.auto_grant = create_auto_grant_for_level(lvl)

		tree.rows.append(row)

	return tree

static func create_ryan_tree(max_level: int = 20) -> SkillTreeData:
	var tree = SkillTreeData.new()
	tree.character_name = "Ryan"

	# Archetype ability pool — spread across levels
	# Colors: Relentless Blade = red, Light Foot = blue, Apothecary = green, Shadow Blade = purple
	var ability_placements := [
		{level = 2, slot = 0, archetype = "Relentless Blade", name = "Keep Them Guessing",
			description = "When discarding a card, -1t from a random card in your hand",
			color = Color(0.9, 0.3, 0.3)},
		{level = 3, slot = 1, archetype = "Light Foot", name = "Quick Step",
			description = "Anytime an instant is played from your hand, gain 5 armor",
			color = Color(0.3, 0.7, 1.0)},
		{level = 4, slot = 2, archetype = "Apothecary", name = "Stimulant",
			description = "When healing yourself or an ally with a Pocket card, the healed character draws a card. 5 tempo cooldown.",
			color = Color(0.4, 0.9, 0.4)},
		{level = 5, slot = 3, archetype = "Shadow Blade", name = "Now You See Me",
			description = "Displacing yourself (blinking, being swapped, or other non-standard movement) grants you invisibility",
			color = Color(0.8, 0.4, 0.9)},
		{level = 7, slot = 1, archetype = "Relentless Blade", name = "From the Hip",
			description = "If an attack, your most recently drawn card has -1 mana cost. The discount is lost when any card is played",
			color = Color(0.9, 0.3, 0.3)},
		{level = 8, slot = 0, archetype = "Light Foot", name = "Ladder Work",
			description = "+3 dexterity and +3 agility. Your first attack each cycle deals +2 damage for each card that hit your discard pile last cycle by means other than playing it",
			color = Color(0.3, 0.7, 1.0)},
		{level = 9, slot = 3, archetype = "Apothecary", name = "Pop Rocks",
			description = "When applying poison to an already poisoned enemy, deal immediate damage equal to 1/3 their current poison stacks",
			color = Color(0.4, 0.9, 0.4)},
		{level = 11, slot = 2, archetype = "Shadow Blade", name = "Surprise Opener",
			description = "Your first strike on an enemy deals +3 damage. An additional +4 if they have no armor, and an additional +5 if you are their first source of damage",
			color = Color(0.8, 0.4, 0.9)},
		{level = 13, slot = 0, archetype = "Relentless Blade", name = "Nimble Assault",
			description = "If you have cards in your hand, but no Defense cards, draw a card when you play an attack",
			color = Color(0.9, 0.3, 0.3)},
		{level = 14, slot = 2, archetype = "Light Foot", name = "Let's Dance",
			description = "At the end of every cycle, gain armor equal to spaces moved/2 and deal damage to the nearest enemy within 3 range equal to spaces moved",
			color = Color(0.3, 0.7, 1.0)},
		{level = 16, slot = 1, archetype = "Apothecary", name = "Mad Scientist",
			description = "The last card you played changes the outcome of your potion cards. Utility→Heal: +3 regen. Attack→Heal: +3 strengthen. Utility→Poison: +3 poison stacks. Defense→Poison: -10% enemy physical defense.",
			color = Color(0.4, 0.9, 0.4)},
		{level = 18, slot = 3, archetype = "Shadow Blade", name = "Eye Scrape",
			description = "Every third critical strike provides invisibility",
			color = Color(0.8, 0.4, 0.9)},
	]

	# Card reward placements — Ryan's rogue/alchemist cards
	var card_placements := [
		{level = 2, slot = 1, card_id = "reposition", name = "Reposition", description = "Discard a card and draw a new one. (1 mana, 2 tempo)"},
		{level = 3, slot = 0, card_id = "elixir", name = "Elixir", description = "Poison cards now heal instead. (1 mana, 2 tempo)"},
		{level = 4, slot = 0, card_id = "poisoned_blood", name = "Poisoned Blood", description = "Heal cards now apply damage instead. (1 mana, 2 tempo)"},
		{level = 5, slot = 0, card_id = "volatile_mixture", name = "Volatile Mixture", description = "Discard: deal 8 damage to enemy. End of turn in hand: 8 self-damage. (0 mana, 0 tempo)"},
		{level = 6, slot = 0, card_id = "shadows", name = "Shadows", description = "Go invisible for 10 tempo. (1 mana, 4 tempo)"},
		{level = 7, slot = 0, card_id = "preparation", name = "Preparation", description = "Next 2 utility cards cost 2 less. (3 mana, 3 tempo)"},
		{level = 8, slot = 1, card_id = "raged_circulation", name = "Raged Circulation", description = "Target receives 30% more from healing and regen for 15 tempo. Ranged. (2 mana, 2 tempo)"},
		{level = 9, slot = 0, card_id = "exacerbate_wounds", name = "Exacerbate Wounds", description = "Deal damage for each card discarded this turn. (0 mana, 7 tempo)"},
		{level = 10, slot = 0, card_id = "premeditated", name = "Premeditated", description = "Deal 8 damage. If this Exposes the enemy, next attack deals +15 damage. (2 mana, 4 tempo)"},
		{level = 11, slot = 0, card_id = "shuriken_pouch", name = "Shuriken Pouch", description = "Manifest 3: Overflow cards become Shuriken (3 dmg, free, ranged). (3 mana, 2 tempo)"},
		{level = 12, slot = 0, card_id = "bloodlust", name = "Bloodlust", description = "Apply 3 Vulnerable to self. Gain 3 mana. Gain 3 Strengthen for 20 tempo. (0 mana, 5 tempo)"},
		{level = 14, slot = 0, card_id = "understanding", name = "Understanding", description = "After 10 tempo delay, next card auto-crits. (5 mana, 1 tempo)"},
		{level = 16, slot = 0, card_id = "lethal_recall", name = "Lethal Recall", description = "Trigger your last instant card's effect 2 times. (2 mana, 4 tempo)"},
		{level = 15, slot = 0, card_id = "adrenaline_shot", name = "Adrenaline Shot", description = "Decrease tempo of two cards in target's hand by 3. In 5 tempo, increase a random card by 3 and another by 2. (3 mana, 0 tempo)"},
		{level = 17, slot = 0, card_id = "patience", name = "Patience", description = "In 15 tempo, draw 3 cards. (2 mana, 3 tempo)"},
		{level = 19, slot = 0, card_id = "gargle_and_spit", name = "Gargle and Spit", description = "Heal 3 and provide +1 strength. Sticky 4. (1 mana, 1 tempo)"},
	]

	# Index placements by level for quick lookup
	var placements_by_level := {}
	for p in ability_placements:
		if p.level not in placements_by_level:
			placements_by_level[p.level] = {}
		placements_by_level[p.level][p.slot] = p

	var cards_by_level := {}
	for c in card_placements:
		if c.level not in cards_by_level:
			cards_by_level[c.level] = {}
		cards_by_level[c.level][c.slot] = c

	for lvl in range(2, max_level + 1):
		var row = SkillRow.new()
		row.level = lvl

		var level_placements = placements_by_level.get(lvl, {})
		var level_card_placements = cards_by_level.get(lvl, {})

		for i in range(4):
			var opt = SkillOption.new()
			if i in level_placements:
				var p = level_placements[i]
				opt.name = p.name
				opt.description = "%s (%s): %s" % [p.name, p.archetype, p.description]
				opt.option_type = OptionType.PASSIVE
				opt.passive_id = p.name.to_lower().replace(" ", "_")
				opt.icon_color = p.color
			elif i in level_card_placements:
				var c = level_card_placements[i]
				opt.name = c.name
				opt.description = "%s: %s" % [c.name, c.description]
				opt.option_type = OptionType.CARD
				opt.card_id = c.card_id
				opt.icon_color = Color(1.0, 0.85, 0.3)
			else:
				opt.name = "Ryan Lv%d Option %d" % [lvl, i + 1]
				opt.description = "Placeholder - to be defined"
				opt.option_type = OptionType.CARD if i < 2 else OptionType.PASSIVE
				opt.icon_color = _get_option_color(i)
			row.options.append(opt)

		# Auto-grant column: only Culling Stone levels carry one now
		row.auto_grant = create_auto_grant_for_level(lvl)

		tree.rows.append(row)

	return tree

static func create_cory_tree(max_level: int = 20) -> SkillTreeData:
	var tree = SkillTreeData.new()
	tree.character_name = "Cory"

	# Archetype ability pool — spread across levels
	# Colors: Monk = red, Lurker = blue, Atrophist = green, Druid = purple
	var ability_placements := [
		{level = 2, slot = 0, archetype = "Monk", name = "Energy Barrier",
			description = "Every 3rd time you gain mana from a source other than mana regen, put an Energy Barrier in your hand (0m/0t, gain 5 armor, erase 1)",
			color = Color(0.9, 0.3, 0.3)},
		{level = 3, slot = 1, archetype = "Lurker", name = "Prey on the Weak",
			description = "When applying a debuff to an enemy below 50% health, deal 3 damage to them",
			color = Color(0.3, 0.7, 1.0)},
		{level = 4, slot = 2, archetype = "Atrophist", name = "Wither",
			description = "Add +1 charge to all debuffs applied to enemies",
			color = Color(0.4, 0.9, 0.4)},
		{level = 5, slot = 3, archetype = "Druid", name = "Budding",
			description = "When playing an attack, a utility, and a defense in any order (none back to back), heal 3 and gain 5 temp HP for 15 tempo",
			color = Color(0.8, 0.4, 0.9)},
		{level = 7, slot = 1, archetype = "Lurker", name = "Eat",
			description = "Killing enemies heals you 5% of your max health. You gain 1% damage for each percentage point of health the enemy is below 35%",
			color = Color(0.3, 0.7, 1.0)},
		{level = 8, slot = 0, archetype = "Monk", name = "Expel Negativity",
			description = "Transfer a debuff to an enemy when you drop below 50% health. 2 charges, 10 tempo cooldown; only one charge can trigger at once",
			color = Color(0.9, 0.3, 0.3)},
		{level = 9, slot = 3, archetype = "Druid", name = "Circle of Life",
			description = "When you shuffle your deck, gain 15 armor and +3 damage for 3 attacks",
			color = Color(0.8, 0.4, 0.9)},
		{level = 10, slot = 1, archetype = "Monk", name = "Disarm Mastery",
			description = "Whenever you apply Disarm to an enemy, apply 1 additional Disarm",
			color = Color(0.9, 0.3, 0.3)},
		{level = 11, slot = 2, archetype = "Atrophist", name = "Territorial Death",
			description = "When enemies enter or leave melee range, re-apply 1 random debuff they already have",
			color = Color(0.4, 0.9, 0.4)},
		{level = 13, slot = 0, archetype = "Monk", name = "Self Reliance",
			description = "When you play 3 cards in a single tempo cycle, your next card costs -1m",
			color = Color(0.9, 0.3, 0.3)},
		{level = 14, slot = 2, archetype = "Atrophist", name = "Death as Lifeblood",
			description = "Regenerate health for each enemy with a debuff near you",
			color = Color(0.4, 0.9, 0.4)},
		{level = 16, slot = 1, archetype = "Lurker", name = "Serial Killer",
			description = "The first time an enemy drops below 25% health, you become invisible to them. If you attack that enemy out of your invisibility, it is an auto-crit",
			color = Color(0.3, 0.7, 1.0)},
		{level = 18, slot = 3, archetype = "Druid", name = "Regrowth",
			description = "When emptying your hand, draw 4 cards. Cooldown 25 tempo",
			color = Color(0.8, 0.4, 0.9)},
	]

	# Card reward placements — Cory's brawler/monk cards
	var card_placements := [
		{level = 2, slot = 1, card_id = "push", name = "Push", description = "Move a unit away from you X squares. Fist. (1 mana, 1 tempo)"},
		{level = 3, slot = 0, card_id = "trip", name = "Trip", description = "Deal 5 damage. Decrease enemy movement by 4. Fist. (2 mana, 4 tempo)"},
		{level = 4, slot = 0, card_id = "bob_and_weave", name = "Bob and Weave", description = "Gain 5 armor and draw a card. Fist. (2 mana, 1 tempo)"},
		{level = 5, slot = 0, card_id = "swap", name = "Swap", description = "Switch positions with an enemy or ally. Ranged +4. (2 mana, 3 tempo)"},
		{level = 6, slot = 0, card_id = "defensive_awareness", name = "Defensive Awareness", description = "Gain 3 armor for every enemy within 2 spaces. (3 mana, 2 tempo)"},
		{level = 7, slot = 0, card_id = "consecutive_snap", name = "Consecutive Snap", description = "3 damage. Each reuse: +9 damage, -1m/-1t cost. Sticky 3. Fist. (3 mana, 3 tempo)"},
		{level = 8, slot = 1, card_id = "round_em_up", name = "Round 'Em Up", description = "Pick a point. Enemies near it are displaced towards it. AOE circle, Ranged. (2 mana, 3 tempo)"},
		{level = 9, slot = 0, card_id = "sweeping_disarm", name = "Sweeping Disarm", description = "Surrounding enemies disarmed, deal 3 damage. AOE circle, Fist. (2 mana, 5 tempo)"},
		{level = 10, slot = 0, card_id = "choke", name = "Choke", description = "Silence enemy and deal damage per round. Sticky 3. Fist. (3 mana, 4 tempo)"},
		{level = 12, slot = 0, card_id = "meditate", name = "Meditate", description = "Discard hand, draw to full -2, heal to 80%. Skip next turn. (0 mana, 6 tempo)"},
		{level = 14, slot = 0, card_id = "absorb_essence", name = "Absorb Essence", description = "Deal 1 damage to ALL things. Delay 10 tempo: obtain Energy Ball. AOE. (5 mana, 5 tempo)"},
		{level = 15, slot = 0, card_id = "misery_loves_company", name = "Misery Loves Company", description = "Your next AOE attack spreads the debuffs on yourself and all enemies hit, to all the enemies that are hit. (5 mana, 1 tempo)"},
		{level = 17, slot = 0, card_id = "release_tension", name = "Release Tension", description = "Remove a stack of debuffs from the enemy and heal for the amount of debuffs removed x3. Choose which debuff. (3 mana, 5 tempo)"},
		{level = 19, slot = 0, card_id = "vines", name = "Vines", description = "Summon vines holding an enemy in place for 3 turns. Deal 4 damage per turn the enemy is held still. (2 mana, 3 tempo)"},
		{level = 20, slot = 0, card_id = "exposed_artery", name = "Exposed Artery", description = "Deal damage equal to 0.5x the enemy's missing health %. (5 mana, 2 tempo)"},
	]

	# Index placements by level for quick lookup
	var placements_by_level := {}
	for p in ability_placements:
		if p.level not in placements_by_level:
			placements_by_level[p.level] = {}
		placements_by_level[p.level][p.slot] = p

	var cards_by_level := {}
	for c in card_placements:
		if c.level not in cards_by_level:
			cards_by_level[c.level] = {}
		cards_by_level[c.level][c.slot] = c

	for lvl in range(2, max_level + 1):
		var row = SkillRow.new()
		row.level = lvl

		var level_placements = placements_by_level.get(lvl, {})
		var level_card_placements = cards_by_level.get(lvl, {})

		for i in range(4):
			var opt = SkillOption.new()
			if i in level_placements:
				var p = level_placements[i]
				opt.name = p.name
				opt.description = "%s (%s): %s" % [p.name, p.archetype, p.description]
				opt.option_type = OptionType.PASSIVE
				opt.passive_id = p.name.to_lower().replace(" ", "_")
				opt.icon_color = p.color
			elif i in level_card_placements:
				var c = level_card_placements[i]
				opt.name = c.name
				opt.description = "%s: %s" % [c.name, c.description]
				opt.option_type = OptionType.CARD
				opt.card_id = c.card_id
				opt.icon_color = Color(1.0, 0.85, 0.3)
			else:
				opt.name = "Cory Lv%d Option %d" % [lvl, i + 1]
				opt.description = "Placeholder - to be defined"
				opt.option_type = OptionType.CARD if i < 2 else OptionType.PASSIVE
				opt.icon_color = _get_option_color(i)
			row.options.append(opt)

		# Auto-grant column: only Culling Stone levels carry one now
		row.auto_grant = create_auto_grant_for_level(lvl)

		tree.rows.append(row)

	return tree

static func create_jeremy_tree(max_level: int = 20) -> SkillTreeData:
	var tree = SkillTreeData.new()
	tree.character_name = "Jeremy"

	# Archetype ability pool — spread across levels
	# Colors: Evocation = red, Shepherd = blue, Poltergeist = green, Abjurer = purple
	var ability_placements := [
		{level = 2, slot = 0, archetype = "Evocation", name = "Arcane Overflow",
			description = "When you have 0 mana remaining after casting a spell, your next spell costs -1 tempo",
			color = Color(0.9, 0.3, 0.3)},
		{level = 3, slot = 1, archetype = "Shepherd", name = "I Heal You",
			description = "Allies near you are healed 3 health every 5 tempo",
			color = Color(0.3, 0.7, 1.0)},
		{level = 4, slot = 2, archetype = "Poltergeist", name = "Tricks of Death",
			description = "Increase all % chances by 10",
			color = Color(0.4, 0.9, 0.4)},
		{level = 5, slot = 3, archetype = "Abjurer", name = "A Mage's Favor",
			description = "When a card rerolls to a different outcome in your hand, put a Magic Barrier in your hand. 0m/0t Instant: when targeted by an enemy attack, gain 8 armor. Only triggers once per reroll batch.",
			color = Color(0.8, 0.4, 0.9)},
		{level = 7, slot = 1, archetype = "Evocation", name = "Harnessed Power",
			description = "Cards gain 30% effectiveness when you have 2 or less cards in your hand",
			color = Color(0.9, 0.3, 0.3)},
		{level = 8, slot = 0, archetype = "Shepherd", name = "Whispers of the Flock",
			description = "When you heal an ally, add a Shepherd's Mark card to your hand (Erase 10). Play it on the healed ally to mark them for 10 tempo. If the marked ally would take lethal damage, they survive at 1 HP and gain 10 armor instead, but Jeremy takes 8 damage. Cooldown: 20 tempo.",
			color = Color(0.3, 0.7, 1.0)},
		{level = 9, slot = 3, archetype = "Poltergeist", name = "Seance",
			description = "When you cast a spell that targets an empty tile, summon a Specter on that tile for 15 tempo. 5 HP, cannot act. Enemies may target it based on proximity. When destroyed, deals 4 damage to its killer.",
			color = Color(0.4, 0.9, 0.4)},
		{level = 11, slot = 2, archetype = "Abjurer", name = "Kinetic Armor",
			description = "While retaining armor for more than 25 tempo, apply shock to the nearest enemy equal to the number of defensive cards in your deck",
			color = Color(0.8, 0.4, 0.9)},
		{level = 13, slot = 0, archetype = "Evocation", name = "Mana Surge",
			description = "When spending 10 mana within 5 tempo, add a Mana Surge to your hand. Mana Surge: Attack, 0m/2t, deal 5 damage, gain 1 mana.",
			color = Color(0.9, 0.3, 0.3)},
		{level = 14, slot = 2, archetype = "Poltergeist", name = "Haunted Rebuke",
			description = "When an enemy attacks you and you have 3 or more defensive cards in your hand, the enemy's next action takes +3 tempo. Cooldown: 10 tempo.",
			color = Color(0.4, 0.9, 0.4)},
		{level = 16, slot = 1, archetype = "Shepherd", name = "Blood Libation",
			description = "Every time Jeremy takes damage (excluding Blood Libation's own self-damage), gain a stack of Sanguine (max 5). Each stack grants +1 to all healing Jeremy performs. At 5 stacks, Jeremy's next heal is doubled, all Sanguine stacks are consumed, and Jeremy takes 10 non-lethal damage. The damage resolves FIRST, then the heal",
			color = Color(0.3, 0.7, 1.0)},
		{level = 18, slot = 3, archetype = "Abjurer", name = "Fresh Start",
			description = "When playing a card that leaves your hand empty, cleanse a debuff from yourself",
			color = Color(0.8, 0.4, 0.9)},
	]

	# Card reward placements — Jeremy's gambler/chaos mage cards
	var card_placements := [
		{level = 2, slot = 1, card_id = "risk_it", name = "Risk It", description = "30% chance to receive the Biscuit. (1 mana, 0 tempo)"},
		{level = 3, slot = 0, card_id = "loaded_die", name = "Loaded Die", description = "Next card with a probability has +10% higher chance. Gem. (1 mana, 1 tempo)"},
		{level = 4, slot = 0, card_id = "trick_shot", name = "Trick Shot", description = "Deal 8 damage. 80% chance to bounce, -20% per bounce. Ranged. (2 mana, 4 tempo)"},
		{level = 5, slot = 0, card_id = "oops", name = "Oops", description = "4 damage per hit. 30% for 5 hits, 40% for 3 hits, 30% for 2 hits. (3 mana, 4 tempo)"},
		{level = 6, slot = 0, card_id = "hope_this_works", name = "Hope This Works", description = "50% to heal ally and provide STR for 3 attacks. (2 mana, 3 tempo)"},
		{level = 7, slot = 0, card_id = "surrounding_ice", name = "Surrounding Ice", description = "Ice stalagmites deal 15 damage around you. 30% miss chance per enemy. AOE. (3 mana, 4 tempo)"},
		{level = 8, slot = 1, card_id = "worst_that_could_happen", name = "What's the Worst?", description = "5 damage. 50% for +15 damage, 50% to stun target. (3 mana, 7 tempo)"},
		{level = 10, slot = 0, card_id = "try_this", name = "Try This!", description = "Ally +3 mana pool, +2 hand size for 10 tempo. 10% chance reverse. (3 mana, 4 tempo)"},
		{level = 11, slot = 0, card_id = "snowballs_chance", name = "A Snowball's Chance", description = "Searing fire 3 spaces forward. 50% to also spread snowballs in a cone. AOE line. (2 mana, 3 tempo)"},
		{level = 12, slot = 0, card_id = "lady_luck", name = "Lady Luck", description = "Bless an ally. Crit chance +30% for 5 attacks. (4 mana, 1 tempo)"},
		{level = 14, slot = 0, card_id = "if_pigs_could_fly", name = "If Pigs Could Fly", description = "Summon a flying pig that explodes for 15 damage. Ranged. (3 mana, 0 tempo)"},
		{level = 16, slot = 0, card_id = "house_money", name = "House Money", description = "Your next odds will automatically trigger. (4 mana, 5 tempo)"},
		{level = 3, slot = 2, card_id = "cryonics", name = "Cryonics", description = "Encase an ally in ice for 15 tempo. Untargetable, cannot act, heals 3 per 5 tempo. (1 mana, 6 tempo)"},
		{level = 6, slot = 1, card_id = "friendship", name = "Friendship", description = "Choose two allies. When one heals, both heal. When one takes damage, they split it. (3 mana, 0 tempo)"},
		{level = 9, slot = 0, card_id = "provider", name = "Provider", description = "Heal an ally 6 health and give them one mana. Burden. (1 mana, 1 tempo)"},
		{level = 13, slot = 1, card_id = "fireball", name = "Fireball", description = "Massive fireball. Range +5, 12 damage, 3 burn. Costs 1 less mana per fire spell this turn. AOE circle 4 sq. (8 mana, 8 tempo)"},
		{level = 15, slot = 0, card_id = "spark", name = "Spark", description = "3 damage. Ranged -2. Subtract 2 tempo from 2 random cards. In 15 tempo, add 2 tempo to 2 random cards. (1 mana, 3 tempo)"},
		{level = 17, slot = 0, card_id = "god_of_thunder", name = "God of Thunder", description = "Absorb all shock on enemies and cast a massive bolt dealing damage based on shock absorbed. (5 mana, 10 tempo)"},
		{level = 19, slot = 0, card_id = "worms_armageddon", name = "Worms Armageddon", description = "Rain meteors dealing significant damage. 10% to summon two Alaskan Bull Worms (12 HP, 6 dmg, burrowed). (5 mana, 10 tempo)"},
		{level = 20, slot = 0, card_id = "healthy_bliss", name = "Healthy Bliss", description = "Instant: Once in hand for 20 tempo, automatically heal all allies for 10 health. (0 mana, 0 tempo)"},
	]

	# Index placements by level for quick lookup
	var placements_by_level := {}
	for p in ability_placements:
		if p.level not in placements_by_level:
			placements_by_level[p.level] = {}
		placements_by_level[p.level][p.slot] = p

	var cards_by_level := {}
	for c in card_placements:
		if c.level not in cards_by_level:
			cards_by_level[c.level] = {}
		cards_by_level[c.level][c.slot] = c

	for lvl in range(2, max_level + 1):
		var row = SkillRow.new()
		row.level = lvl

		var level_placements = placements_by_level.get(lvl, {})
		var level_card_placements = cards_by_level.get(lvl, {})

		for i in range(4):
			var opt = SkillOption.new()
			if i in level_placements:
				var p = level_placements[i]
				opt.name = p.name
				opt.description = "%s (%s): %s" % [p.name, p.archetype, p.description]
				opt.option_type = OptionType.PASSIVE
				opt.passive_id = p.name.to_lower().replace(" ", "_")
				opt.icon_color = p.color
			elif i in level_card_placements:
				var c = level_card_placements[i]
				opt.name = c.name
				opt.description = "%s: %s" % [c.name, c.description]
				opt.option_type = OptionType.CARD
				opt.card_id = c.card_id
				opt.icon_color = Color(1.0, 0.85, 0.3)
			else:
				opt.name = "Jeremy Lv%d Option %d" % [lvl, i + 1]
				opt.description = "Placeholder - to be defined"
				opt.option_type = OptionType.CARD if i < 2 else OptionType.PASSIVE
				opt.icon_color = _get_option_color(i)
			row.options.append(opt)

		# Auto-grant column: only Culling Stone levels carry one now
		row.auto_grant = create_auto_grant_for_level(lvl)

		tree.rows.append(row)

	return tree

static func _get_option_color(index: int) -> Color:
	match index:
		0: return Color(0.3, 0.7, 1.0)    # Blue
		1: return Color(1.0, 0.5, 0.3)    # Orange
		2: return Color(0.4, 0.9, 0.4)    # Green
		3: return Color(0.8, 0.4, 0.9)    # Purple
	return Color.WHITE
