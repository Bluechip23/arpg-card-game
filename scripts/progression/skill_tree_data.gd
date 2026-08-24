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
	var option_type: OptionType = OptionType.PASSIVE
	var name: String = ""
	var description: String = ""
	var icon_color: Color = Color.WHITE  # For UI display

	# Type-specific data
	var card_id: String = ""              # For CARD type
	var passive_id: String = ""           # For PASSIVE
	var passive_data: Dictionary = {}     # trigger, effect, value, chance, etc.
	var stat_type: String = ""            # For STAT_BONUS: "strength", "dexterity", etc.
	var stat_amount: int = 0              # For STAT_BONUS
	var archetype: String = ""            # For PASSIVE: which archetype lane it belongs to

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

# ============================================
# PASSIVE ALLOCATION MODEL (lane view)
# ============================================
# Passives are no longer one-cost picks: each is LEVELED with passive points
# (up to PASSIVE_MAX_LEVEL). The UI shows one horizontal lane per archetype;
# a lane's later stages unlock as points are invested in that lane.

const PASSIVE_MAX_LEVEL: int = 15

## Points invested in a lane required to unlock its stage at `index`
## (0-based): stage 0 is free, then 5, 15, 25, 35...
static func stage_unlock_cost(stage: int) -> int:
	if stage <= 0:
		return 0
	return 5 + 10 * (stage - 1)

## Lanes for the passive-allocation UI: one entry per archetype, its passives
## in row order (left to right = the lane's stages).
## Returns [{ "name": String, "color": Color, "passives": Array[SkillOption] }]
func get_archetype_lanes() -> Array:
	var lanes: Array = []
	var by_name := {}
	for row in rows:
		for opt in row.options:
			if opt.option_type != OptionType.PASSIVE or opt.archetype == "" or opt.passive_id == "":
				continue
			if not by_name.has(opt.archetype):
				var lane := {"name": opt.archetype, "color": opt.icon_color, "passives": []}
				by_name[opt.archetype] = lane
				lanes.append(lane)
			by_name[opt.archetype]["passives"].append(opt)
	return lanes

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
			opt.option_type = OptionType.PASSIVE
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
			description = "When you drop below 10%→25% HP (scales with rank), perform a Reach AOE swing hitting all nearby enemies. Gain 10 mana per kill. Cooldown: 25→10 tempo",
			color = Color(0.9, 0.3, 0.3)},
		{level = 3, slot = 1, archetype = "Warden", name = "In the Trenches",
			description = "When an enemy enters an adjacent square, perform a free attack at 93%→107% damage (scales with rank). When an enemy attacks you from adjacent, knock them back. 2 charges, 10 tempo cooldown",
			color = Color(0.3, 0.7, 1.0)},
		{level = 4, slot = 2, archetype = "The Ancient", name = "Stone Skin",
			description = "Gain 1%→11.5% Fire, Physical and Lightning resistance (scales with rank)",
			color = Color(0.4, 0.9, 0.4)},
		{level = 5, slot = 3, archetype = "The Fallen", name = "Point to Prove",
			description = "When stunned or disarmed, choose to sacrifice 20%→6% of max HP (scales with rank) to ignore the ailment",
			color = Color(0.8, 0.4, 0.9)},
		{level = 7, slot = 1, archetype = "Berserker", name = "Directed Strength",
			description = "Gain 1→15 strength (scales with rank) when below 50% health, lose it when going above",
			color = Color(0.9, 0.3, 0.3)},
		{level = 8, slot = 0, archetype = "Warden", name = "The Way of the Plate",
			description = "Every 9th→2nd Defense card played (scales with rank) refunds 10 mana and 1 tempo",
			color = Color(0.3, 0.7, 1.0)},
		{level = 9, slot = 3, archetype = "The Ancient", name = "Ancestral Aid",
			description = "Every 5 cycles: more attacks in hand → discount a random attack by 50m→190m. More defense → heal 3→17 HP (scales with rank)",
			color = Color(0.4, 0.9, 0.4)},
		{level = 11, slot = 2, archetype = "The Fallen", name = "Redemption",
			description = "When healing (self or ally), gain 1%→15% crit chance (scales with rank) on your next attack",
			color = Color(0.8, 0.4, 0.9)},
		{level = 13, slot = 0, archetype = "Berserker", name = "Life Steal",
			description = "All attacks life steal by 1%→8% (scales with rank)",
			color = Color(0.9, 0.3, 0.3)},
		{level = 14, slot = 2, archetype = "Warden", name = "Pristine Armor",
			description = "Defense cards grant +1→5 armor. Playing 3 defense cards in a row grants an additional +3→14 armor (scales with rank)",
			color = Color(0.3, 0.7, 1.0)},
		{level = 16, slot = 1, archetype = "The Ancient", name = "Vines Codependence",
			description = "Whenever you heal (direct heals only — regen and life steal don't count), gain 1→8 thorns and 0→7 regen (scales with rank)",
			color = Color(0.4, 0.9, 0.4)},
		{level = 18, slot = 3, archetype = "The Fallen", name = "Solemn Independence",
			description = "When 3+ enemies are within 2 tiles: +5%→12% damage on all attacks and +1→8 armor per tempo cycle (scales with rank), but cannot be healed by allies",
			color = Color(0.8, 0.4, 0.9)},
	]

	# Cards no longer come from leveling — they are bought at the Card
	# Dealer or found on drops. The tree offers passives and stat bonuses.

	# Index placements by level for quick lookup
	var placements_by_level := {}  # level -> {slot -> placement}
	for p in ability_placements:
		if p.level not in placements_by_level:
			placements_by_level[p.level] = {}
		placements_by_level[p.level][p.slot] = p


	for lvl in range(2, max_level + 1):
		var row = SkillRow.new()
		row.level = lvl

		var level_placements = placements_by_level.get(lvl, {})

		for i in range(4):
			var opt = SkillOption.new()
			if i in level_placements:
				var p = level_placements[i]
				opt.name = p.name
				opt.description = "%s (%s): %s" % [p.name, p.archetype, p.description]
				opt.option_type = OptionType.PASSIVE
				opt.passive_id = p.name.to_lower().replace(" ", "_")
				opt.icon_color = p.color
				opt.archetype = p.archetype
			else:
				opt.name = "Brad Lv%d Option %d" % [lvl, i + 1]
				opt.description = "Placeholder - to be defined"
				opt.option_type = OptionType.PASSIVE
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

	# Cards no longer come from leveling — they are bought at the Card
	# Dealer or found on drops. The tree offers passives and stat bonuses.

	# Index placements by level for quick lookup
	var placements_by_level := {}
	for p in ability_placements:
		if p.level not in placements_by_level:
			placements_by_level[p.level] = {}
		placements_by_level[p.level][p.slot] = p


	for lvl in range(2, max_level + 1):
		var row = SkillRow.new()
		row.level = lvl

		var level_placements = placements_by_level.get(lvl, {})

		for i in range(4):
			var opt = SkillOption.new()
			if i in level_placements:
				var p = level_placements[i]
				opt.name = p.name
				opt.description = "%s (%s): %s" % [p.name, p.archetype, p.description]
				opt.option_type = OptionType.PASSIVE
				opt.passive_id = p.name.to_lower().replace(" ", "_")
				opt.icon_color = p.color
				opt.archetype = p.archetype
			else:
				opt.name = "Stephen Lv%d Option %d" % [lvl, i + 1]
				opt.description = "Placeholder - to be defined"
				opt.option_type = OptionType.PASSIVE
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
			description = "If an attack, your most recently drawn card has -10 mana cost. The discount is lost when any card is played",
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

	# Cards no longer come from leveling — they are bought at the Card
	# Dealer or found on drops. The tree offers passives and stat bonuses.

	# Index placements by level for quick lookup
	var placements_by_level := {}
	for p in ability_placements:
		if p.level not in placements_by_level:
			placements_by_level[p.level] = {}
		placements_by_level[p.level][p.slot] = p


	for lvl in range(2, max_level + 1):
		var row = SkillRow.new()
		row.level = lvl

		var level_placements = placements_by_level.get(lvl, {})

		for i in range(4):
			var opt = SkillOption.new()
			if i in level_placements:
				var p = level_placements[i]
				opt.name = p.name
				opt.description = "%s (%s): %s" % [p.name, p.archetype, p.description]
				opt.option_type = OptionType.PASSIVE
				opt.passive_id = p.name.to_lower().replace(" ", "_")
				opt.icon_color = p.color
				opt.archetype = p.archetype
			else:
				opt.name = "Ryan Lv%d Option %d" % [lvl, i + 1]
				opt.description = "Placeholder - to be defined"
				opt.option_type = OptionType.PASSIVE
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
			description = "Every 3rd time you gain mana from a source other than mana regen, put an Energy Barrier in your hand (0m/0t, gain 3→17 armor (scales with rank), erase 1)",
			color = Color(0.9, 0.3, 0.3)},
		{level = 3, slot = 1, archetype = "Lurker", name = "Prey on the Weak",
			description = "When applying a debuff to an enemy below 50% health, deal 3→17 damage to them (scales with rank; unique debuffs only — re-stacking a debuff they already have doesn't count)",
			color = Color(0.3, 0.7, 1.0)},
		{level = 4, slot = 2, archetype = "Atrophist", name = "Wither",
			description = "Add +1 charge to the debuff applied to an enemy. Cooldown 15→1 tempo (scales with rank; tempo gated, not per-debuff gated)",
			color = Color(0.4, 0.9, 0.4)},
		{level = 5, slot = 3, archetype = "Druid", name = "Budding",
			description = "When playing an attack, a utility, and a defense in any order (none back to back), heal 5→19 and gain the same temp HP for 15 tempo (scales with rank)",
			color = Color(0.8, 0.4, 0.9)},
		{level = 7, slot = 1, archetype = "Lurker", name = "Eat",
			description = "Killing enemies heals you 1%→15% of your max health. You gain 1% damage for each percentage point of health the enemy is below 11%→39% (scales with rank)",
			color = Color(0.3, 0.7, 1.0)},
		{level = 8, slot = 0, archetype = "Monk", name = "Expel Negativity",
			description = "Transfer a debuff to an enemy when you drop below 35%→63% health (scales with rank). 2 charges, 10 tempo cooldown; only one charge can trigger at once",
			color = Color(0.9, 0.3, 0.3)},
		{level = 9, slot = 3, archetype = "Druid", name = "Circle of Life",
			description = "When you shuffle your deck, gain 10→24 armor and the same bonus attack damage for 3 attacks (scales with rank)",
			color = Color(0.8, 0.4, 0.9)},
		{level = 11, slot = 2, archetype = "Atrophist", name = "Territorial Death",
			description = "When enemies enter or leave melee range, re-apply 1 random debuff they already have. Cooldown 15→1 tempo (scales with rank)",
			color = Color(0.4, 0.9, 0.4)},
		{level = 13, slot = 0, archetype = "Monk", name = "Self Reliance",
			description = "When you play 3 cards in a single tempo cycle, your next card costs -10m→-80m (scales with rank)",
			color = Color(0.9, 0.3, 0.3)},
		{level = 14, slot = 2, archetype = "Atrophist", name = "Death as Lifeblood",
			description = "Every cycle, regenerate 1→5 HP for each enemy within 2 squares of you, counting up to 3→12 enemies (scales with rank)",
			color = Color(0.4, 0.9, 0.4)},
		{level = 16, slot = 1, archetype = "Lurker", name = "Serial Killer",
			description = "The first time an enemy drops below 11%→25% health (scales with rank), you become invisible to them. If you attack that enemy out of your invisibility, it is an auto-crit",
			color = Color(0.3, 0.7, 1.0)},
		{level = 18, slot = 3, archetype = "Druid", name = "Regrowth",
			description = "When emptying your hand, draw 4 cards. Cooldown 25→11 tempo (scales with rank)",
			color = Color(0.8, 0.4, 0.9)},
	]

	# Cards no longer come from leveling — they are bought at the Card
	# Dealer or found on drops. The tree offers passives and stat bonuses.

	# Index placements by level for quick lookup
	var placements_by_level := {}
	for p in ability_placements:
		if p.level not in placements_by_level:
			placements_by_level[p.level] = {}
		placements_by_level[p.level][p.slot] = p


	for lvl in range(2, max_level + 1):
		var row = SkillRow.new()
		row.level = lvl

		var level_placements = placements_by_level.get(lvl, {})

		for i in range(4):
			var opt = SkillOption.new()
			if i in level_placements:
				var p = level_placements[i]
				opt.name = p.name
				opt.description = "%s (%s): %s" % [p.name, p.archetype, p.description]
				opt.option_type = OptionType.PASSIVE
				opt.passive_id = p.name.to_lower().replace(" ", "_")
				opt.icon_color = p.color
				opt.archetype = p.archetype
			else:
				opt.name = "Cory Lv%d Option %d" % [lvl, i + 1]
				opt.description = "Placeholder - to be defined"
				opt.option_type = OptionType.PASSIVE
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
			description = "Increase all % chances on your CARDS by 10 (item procs like the Stringless Sender's bounce are unaffected)",
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
			description = "When spending 100 mana within 5 tempo, add a Mana Surge to your hand. Mana Surge: Attack, 0m/2t, deal 5 damage, gain 10 mana.",
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

	# Cards no longer come from leveling — they are bought at the Card
	# Dealer or found on drops. The tree offers passives and stat bonuses.

	# Index placements by level for quick lookup
	var placements_by_level := {}
	for p in ability_placements:
		if p.level not in placements_by_level:
			placements_by_level[p.level] = {}
		placements_by_level[p.level][p.slot] = p


	for lvl in range(2, max_level + 1):
		var row = SkillRow.new()
		row.level = lvl

		var level_placements = placements_by_level.get(lvl, {})

		for i in range(4):
			var opt = SkillOption.new()
			if i in level_placements:
				var p = level_placements[i]
				opt.name = p.name
				opt.description = "%s (%s): %s" % [p.name, p.archetype, p.description]
				opt.option_type = OptionType.PASSIVE
				opt.passive_id = p.name.to_lower().replace(" ", "_")
				opt.icon_color = p.color
				opt.archetype = p.archetype
			else:
				opt.name = "Jeremy Lv%d Option %d" % [lvl, i + 1]
				opt.description = "Placeholder - to be defined"
				opt.option_type = OptionType.PASSIVE
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
