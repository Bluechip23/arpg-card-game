class_name SkillTreeData
extends RefCounted

## Defines a character's skill tree progression.
## Each level adds a row with 4 chooseable options + 1 auto-granted reward.
## The player picks ONE of the 4 options; the other 3 are blacked out.

# Option types for the 4 chooseable columns
enum OptionType {
	CARD,           # Grants a new card to the deck
	PASSIVE,        # Grants a passive ability
	PASSIVE_MUTATION, # Modifies an existing passive
	STAT_BONUS,     # Flat stat increase
	CARD_UPGRADE,   # Upgrades an existing card
	CARD_MUTATION,  # Mutates/transforms an existing card
}

# Auto-grant types for the 5th column
enum AutoGrantType {
	STAT_ALLOCATION,  # 5 stat points to distribute
	CARD_REMOVAL,     # Remove a card from deck
	UPGRADE_CARD,     # Upgrade an existing card
	MUTATE_CARD,      # Mutate/transform an existing card
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
	var passive_id: String = ""           # For PASSIVE / PASSIVE_MUTATION
	var passive_data: Dictionary = {}     # trigger, effect, value, chance, etc.
	var stat_type: String = ""            # For STAT_BONUS: "strength", "dexterity", etc.
	var stat_amount: int = 0              # For STAT_BONUS
	var upgrade_card_id: String = ""      # For CARD_UPGRADE / CARD_MUTATION
	var upgrade_result_id: String = ""    # The card it becomes after upgrade/mutation

	func get_type_label() -> String:
		match option_type:
			OptionType.CARD: return "Card"
			OptionType.PASSIVE: return "Passive"
			OptionType.PASSIVE_MUTATION: return "Mutation"
			OptionType.STAT_BONUS: return "Stat Bonus"
			OptionType.CARD_UPGRADE: return "Upgrade"
			OptionType.CARD_MUTATION: return "Card Mutation"
		return "Unknown"

## The auto-granted 5th column reward for a row
class AutoGrant:
	var grant_type: AutoGrantType = AutoGrantType.STAT_ALLOCATION
	var name: String = ""
	var description: String = ""
	var stat_points: int = 5             # For STAT_ALLOCATION
	var card_id: String = ""             # For CARD_REMOVAL / UPGRADE / MUTATE target
	var health_amount: int = 0           # For HEALTH_BOOST
	var mana_amount: int = 0             # For MANA_BOOST
	var passive_data: Dictionary = {}    # For PASSIVE auto-grants

	func get_type_label() -> String:
		match grant_type:
			AutoGrantType.STAT_ALLOCATION: return "+%d Stats" % stat_points
			AutoGrantType.CARD_REMOVAL: return "Remove Card"
			AutoGrantType.UPGRADE_CARD: return "Upgrade Card"
			AutoGrantType.MUTATE_CARD: return "Mutate Card"
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
		return chosen_index >= 0

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

## Get the auto-grant type for a given level based on the schedule:
## Levels 1, 4, 8, 12, 16, 20 ... → Stat Allocation (5 points)
## Levels 2, 5, 10, 15, 20 ...    → Card Removal
## Other levels                    → Varies (upgrade, mutate, health, mana, etc.)
static func get_default_auto_grant_type_for_level(level: int) -> AutoGrantType:
	# Stat allocation levels: 1, 4, 8, 12, 16, 20...
	var stat_levels := [1, 4, 8, 12, 16, 20, 24, 28, 32]
	if level in stat_levels:
		return AutoGrantType.STAT_ALLOCATION

	# Card removal levels: 2, 5, 10, 15, 20, 25...
	var removal_levels := [2, 5, 10, 15, 20, 25, 30]
	if level in removal_levels:
		return AutoGrantType.CARD_REMOVAL

	# Fallback: alternate between upgrade and mutate for other levels
	if level % 2 == 1:
		return AutoGrantType.UPGRADE_CARD
	else:
		return AutoGrantType.MUTATE_CARD

# ============================================
# PLACEHOLDER TREE BUILDERS (one per character)
# ============================================
# These create empty/placeholder skill trees with proper structure.
# The actual options will be filled in later.

static func create_placeholder_tree(char_name: String, max_level: int = 20) -> SkillTreeData:
	var tree = SkillTreeData.new()
	tree.character_name = char_name

	for lvl in range(2, max_level + 1):  # Start at level 2 (level 1 is starting state)
		var row = SkillRow.new()
		row.level = lvl

		# Create 4 placeholder options
		for i in range(4):
			var opt = SkillOption.new()
			opt.name = "%s Lv%d Option %d" % [char_name, lvl, i + 1]
			opt.description = "Placeholder - to be defined"
			opt.option_type = OptionType.CARD if i < 2 else OptionType.PASSIVE
			opt.icon_color = _get_option_color(i)
			row.options.append(opt)

		# Create auto-grant based on level schedule
		var auto = AutoGrant.new()
		auto.grant_type = get_default_auto_grant_type_for_level(lvl)
		match auto.grant_type:
			AutoGrantType.STAT_ALLOCATION:
				auto.name = "Stat Points"
				auto.description = "Allocate 5 stat points"
				auto.stat_points = 5
			AutoGrantType.CARD_REMOVAL:
				auto.name = "Culling Stone"
				auto.description = "Remove 1 card from your deck"
			AutoGrantType.UPGRADE_CARD:
				auto.name = "Card Upgrade"
				auto.description = "Upgrade an existing card"
			AutoGrantType.MUTATE_CARD:
				auto.name = "Card Mutation"
				auto.description = "Mutate an existing card"
			_:
				auto.name = "Bonus"
				auto.description = "Level bonus"
		row.auto_grant = auto

		tree.rows.append(row)

	return tree

static func _get_option_color(index: int) -> Color:
	match index:
		0: return Color(0.3, 0.7, 1.0)    # Blue
		1: return Color(1.0, 0.5, 0.3)    # Orange
		2: return Color(0.4, 0.9, 0.4)    # Green
		3: return Color(0.8, 0.4, 0.9)    # Purple
	return Color.WHITE
