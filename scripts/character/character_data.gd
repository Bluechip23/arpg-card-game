class_name CharacterData
extends Resource

## Defines a character's base stats

@export var character_name: String = "Default"

# The preset this character was built from ("Brad", "Ryan", …). Everything
# identity-based (starting kit, figure appearance, skill tree, character
# passive) keys off this, so the player is free to rename character_name.
# Empty on old saves and quiz characters — get_base_character() falls back
# to character_name.
@export var base_character: String = ""

func get_base_character() -> String:
	return base_character if base_character != "" else character_name

# Core Stats
@export var strength: int = 10
@export var dexterity: int = 10
@export var intelligence: int = 10
@export var wisdom: int = 10
@export var determination: int = 10
@export var agility: int = 10

# Derived/Direct Stats
@export var base_health: int = 10
@export var base_mana: int = 10
@export var base_mana_regen: float = 1.0  # Energy regen per turn
@export var base_draw_timer: int = 5  # Turns between draws
# Uniform for all characters — hand size only grows via WIS (+1 per 5) and gear.
@export var base_hand_size: int = 4

# Build state is @export so it persists when the character is saved to disk
# (ResourceSaver only serializes exported properties). This is what lets a
# story character carry its deck/upgrades into the roguelike.
@export var starting_card_ids: Array = []  # Character-specific cards added to starting deck
@export var purchased_card_ids: Array = []  # Cards bought from the card shop
@export var removed_card_ids: Array = []    # Cards culled from the deck (base or starting cards)

# Bestiary: monsters this character has defeated in story mode. Per-character
# (not shared at the world level). Used to gate monster-intent reveals in the
# roguelike end-game; the telegraph UI itself is a later pass.
@export var defeated_monster_ids: Array = []

# Roguelike relics this character has discovered in the story (e.g. a Hydra
# dropping the Hydra Heart). Gates which non-base relics can appear in runs.
@export var unlocked_relic_ids: Array = []

# Tutorial beats Olorin has already shown this character (e.g. "infestation_pickup").
# Stored per-character so each playthrough learns the ropes once.
@export var seen_tutorial_ids: Array = []

# Act-mythic pity state (see DropRates): acts whose near-guaranteed mythic has
# already dropped for this character, and story kills accumulated toward the
# "mythic creep" in acts still waiting on theirs. Per-character forever —
# revisiting or re-running an act never restarts the creep.
@export var act_mythic_found: Array = []      # act numbers (int)
@export var act_mythic_kills: Dictionary = {} # act (int) -> kills so far

# Every mythic item this character has EVER owned (by item_name). Mythic Molds
# can only be redeemed for mythics on this list — melding duplicates forges
# copies of what you've found, never unlocks what you haven't.
@export var owned_mythic_names: Array = []

# Archetypes - categorize card and passive options
@export var archetypes: Array = []  # [{name: String, description: String}, ...]

# Selection screen display info
@export var passive_description: String = ""
@export var starting_item_name: String = ""
@export var starting_item_description: String = ""
@export var slot_specialty: String = ""
@export var sprite_path: String = ""
@export var sprite_sheet_path: String = ""  # Path to full animation sprite sheet

# Calculate derived stats from core stats
func get_max_hand_size() -> int:
	# Wisdom adds to hand size: every 5 wisdom = +1 hand size
	return base_hand_size + floori(wisdom / 5.0)

func get_mana_regen() -> float:
	# Base mana regen
	return base_mana_regen

# ============================================
# CORE STAT REFERENCE
# ============================================
# Shared by the character-select allocation screen and the character panel so
# both explain each stat the same way.

const STAT_KEYS := ["STR", "DEX", "INT", "WIS", "DET", "AGI"]
const STAT_NAMES := {
	"STR": "Strength", "DEX": "Dexterity", "INT": "Intelligence",
	"WIS": "Wisdom", "DET": "Determination", "AGI": "Agility",
}
const STAT_INFO := {
	"STR": "Strength — +1 melee damage for every 2 points, and +10 carry capacity per point. Spare carry capacity also speeds up your attack-speed proc a little (capped — see Dexterity).",
	"DEX": "Dexterity — your attack-speed stat. Every (30 − Dexterity) attack cards played, your next attack costs half tempo and 2 less mana (minimum every 5). Each point means one fewer attack needed to proc. Traveling light shaves off up to 8 more; being loaded down adds up to 10.",
	"INT": "Intelligence — +1 spell & heal power for every 2 points, and +1 mana regen for every 5 points.",
	"WIS": "Wisdom — +1 hand size for every 5 points, and draws cards faster: each point draws your next card 1 tempo sooner (base: every 25 tempo, fastest: every 5).",
	"DET": "Determination — directly impacts how low health affects your attributes. At 10 it does nothing; above 10 your stats climb as health drops, below 10 they fall. The lower your health, the bigger the swing — about ±1% per point at 80% HP, ±5% at 60%, ±7% at 40%, and ±10% at 10% HP or below.",
	"AGI": "Agility — 1 Flash point per point, refreshed every 2 tempo cycles. Spend them by choice in battle: 1 point per tile moved (boots toggle), 3 points for 2 block (sidestep), 5 points to advance the attack-speed counter (daggers). Without Flash, each tile costs 1 tempo.",
}

static func stat_full_name(key: String) -> String:
	return STAT_NAMES.get(key, key)

static func stat_description(key: String) -> String:
	return STAT_INFO.get(key, "")

static func create_ryan() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Ryan"
	data.base_character = "Ryan"
	data.strength = 3
	data.dexterity = 3
	data.intelligence = 3
	data.wisdom = 3
	data.determination = 3
	data.agility = 3
	data.base_health = 10
	data.base_mana = 5
	data.base_mana_regen = 1.0
	data.base_draw_timer = 5
	data.starting_card_ids = [
		"slash", "slash", "slash",
		"block", "block", "block",
		"discard", "discard",
	]
	data.archetypes = [
		{"name": "Relentless Blade", "description": "Constant pressure, and 1000 cuts is how you fight. Aggression, and lacerations are your north star."},
		{"name": "Light Foot", "description": "Always aware, constantly alert, enemies struggle hitting you, and when they do, your next move is planned."},
		{"name": "Apothecary", "description": "Manipulation of potions and ailments, enemies (and allies) never know what you are throwing at them."},
		{"name": "Shadow Blade", "description": "Hidden in the shadows, weaving in and out of combat, striking enemies when they least expect it, and where they are the weakest."},
	]
	data.passive_description = "Belt cards cost 1 less mana"
	data.starting_item_name = "Adventurer's Belt"
	data.starting_item_description = "Grants: Healing Potion & Dagger Throw"
	data.slot_specialty = "3 belt slots"
	data.sprite_path = "res://assets/characters/ryan_south.png"
	return data

static func create_jeremy() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Jeremy"
	data.base_character = "Jeremy"
	data.strength = 3
	data.dexterity = 3
	data.intelligence = 3
	data.wisdom = 3
	data.determination = 3
	data.agility = 3
	data.base_health = 10
	data.base_mana = 5
	data.base_mana_regen = 1.0
	data.base_draw_timer = 5
	data.starting_card_ids = [
		"slash", "slash", "slash",
		"block", "block", "block",
		"draw", "draw",
	]
	data.archetypes = [
		{"name": "Evocation", "description": "Master of the elements. Blasting enemies with power is your cup of tea."},
		{"name": "Abjurer", "description": "Defense first is what you were taught. Outlasting, fast recovery, and small strikes is your way to victory."},
		{"name": "Shepherd", "description": "Summoner who focuses on the greater good. Your strength is your selflessness, sometimes sacrificing your own health for your friends."},
		{"name": "Poltergeist", "description": "Master of death and hatred, instilling sheer agony on your enemies is your main objective."},
	]
	data.passive_description = "Every 3rd cycle, the first ring trigger triggers twice"
	data.starting_item_name = "Scholar's Signet"
	data.starting_item_description = "+3 INT. +3% chance. On Utility: +1 Mana"
	data.slot_specialty = "4 ring slots"
	data.sprite_path = "res://assets/characters/jeremy_south.png"
	return data

static func create_stephen() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Stephen"
	data.base_character = "Stephen"
	data.strength = 3
	data.dexterity = 3
	data.intelligence = 3
	data.wisdom = 3
	data.determination = 3
	data.agility = 3
	data.base_health = 10
	data.base_mana = 5
	data.base_mana_regen = 1.0
	data.base_draw_timer = 5
	data.starting_card_ids = [
		"slash", "slash", "slash",
		"block", "block", "block",
		"empower", "empower",
	]
	data.archetypes = [
		{"name": "The Apex", "description": "The most efficient and dangerous killer. No tactic is out of question, master of all things offense.", "abilities": [
			{"name": "Deadly", "description": "+3 damage"},
			{"name": "Easy Target", "description": "When exposing your enemy, deal your damage again"},
			{"name": "Skilled Momentum", "description": "If you have played 4 attacks in a row, your 5th will be played twice"},
		]},
		{"name": "Sentinel", "description": "Melee engagements are your bread and butter. No one can out duel you, scratching your armor is a feat itself.", "abilities": [
			{"name": "Clean Exchange", "description": "Anytime you draw a Defense card and the last card you played was an offensive card, or vice versa, give the drawn card -1 tempo"},
			{"name": "Exposed Blind Spot", "description": "When struck with a melee attack, gain crit chance on your next attack equal to the number of non-attack cards in your hand"},
			{"name": "Lethal Resourcefulness", "description": "If you have 3 or less cards in your hand, playing a non-attack card triggers a free basic attack"},
		]},
		{"name": "Ranger", "description": "Striking from a distance, manipulating elements and situations to make your arrows and attacks stronger.", "abilities": [
			{"name": "Eagle Eye", "description": "+2 range on ranged attacks"},
			{"name": "Scouted", "description": "Hitting the same enemy 3 times in a row grants +6 range on your next attack and it auto-crits, as long as you target the same enemy"},
			{"name": "Laced Arrow", "description": "When applying burn, cold, or shock, apply 1 additional instance"},
		]},
		{"name": "Avenger", "description": "Large, potent, and devastating. Unfortunately you tire quick, making timing and execution vital.", "abilities": [
			{"name": "Patience is a Virtue", "description": "When receiving Glut, deal that much damage to an enemy in melee range and halve the Glut"},
			{"name": "Swing for the Fences", "description": "Cards that have >4 tempo cost deal their tempo cost as additional damage"},
			{"name": "Dominate", "description": "When triggering an attack speed proc, gain a 0m/0t basic attack card"},
		]},
	]
	data.passive_description = "+10% off-hand enchantments (others get -10%)"
	data.starting_item_name = "Flickerstep Boots"
	data.starting_item_description = "+2 DEX. Grants 1 Blink card"
	data.slot_specialty = "Standard slots"
	data.sprite_path = "res://assets/characters/stephen_south.png"
	return data

static func create_cory() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Cory"
	data.base_character = "Cory"
	data.strength = 3
	data.dexterity = 3
	data.intelligence = 3
	data.wisdom = 3
	data.determination = 3
	data.agility = 3
	data.base_health = 10
	data.base_mana = 5
	data.base_mana_regen = 1.0
	data.base_draw_timer = 5
	data.starting_card_ids = [
		"slash", "slash", "slash",
		"block", "block", "block",
		"blink", "blink",
	]
	data.archetypes = [
		{"name": "Lurker", "description": "You gain strength from your enemies wounds, becoming stronger as they become weaker, trapping them, or holding them in place, preparing for you to devour."},
		{"name": "Monk", "description": "Immersed in your surroundings, calm, collected. Always ready to help an ally, either directly or by hindering the enemy."},
		{"name": "Druid", "description": "One with the world, you use your surroundings (literally) to aid you in battle."},
		{"name": "Atrophist", "description": "Your touch withers the enemy, making them weaker and frail the longer you are engaged."},
	]
	data.passive_description = "Gain 1 mana when gauntlet skill comes off cooldown"
	data.starting_item_name = "Grasping Gauntlets"
	data.starting_item_description = "+2 Hand Size. Skill: Power Grip (8 dmg, CD 3, Cost 2)"
	data.slot_specialty = "2 gauntlet slots"
	data.sprite_path = "res://assets/characters/cory_south.png"
	return data

static func create_brad() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Brad"
	data.base_character = "Brad"
	data.strength = 3
	data.dexterity = 3
	data.intelligence = 3
	data.wisdom = 3
	data.determination = 3
	data.agility = 3
	data.base_health = 10
	data.base_mana = 5
	data.base_mana_regen = 1.0
	data.base_draw_timer = 5
	data.starting_card_ids = [
		"slash", "slash", "slash",
		"block", "block", "block",
		"heal", "heal",
	]
	data.archetypes = [
		{"name": "Berserker", "description": "Health is simply an inconvenience. Pain is your greatest strength, causing you to get stronger as you edge near death.", "abilities": [
			{"name": "Enraged Will", "description": "When you drop below 10% health, perform a Reach AOE swing hitting all nearby enemies. Gain 1 mana per kill"},
			{"name": "Directed Strength", "description": "Lose 5 strength when above 50% health, gain 5 when below"},
			{"name": "Life Steal", "description": "All attacks life steal by 5%"},
		]},
		{"name": "Warden", "description": "Specialize in the art of armor and tactic, finding your weakness is nearly impossible for enemies.", "abilities": [
			{"name": "In the Trenches", "description": "When an enemy enters an adjacent square, perform a free attack. When an enemy attacks you from adjacent, knock them back. 2 charges, 10 tempo cooldown"},
			{"name": "The Way of the Plate", "description": "Every third Defense card costs -1m/-1t"},
			{"name": "Pristine Armor", "description": "Cards provide +2 armor"},
		]},
		{"name": "The Ancient", "description": "Thorns, armor and healing. You have a deep understanding of nature, and you use its essence to your advantage.", "abilities": [
			{"name": "Stone Skin", "description": "Gain 10% Fire, Physical and Lightning resistance"},
			{"name": "Ancestral Aid", "description": "Gain 3 HP regen per 5 tempo"},
			{"name": "Wrapped in Thorny Vine", "description": "Whenever you heal, gain 3 thorns"},
		]},
		{"name": "The Fallen", "description": "Once a child of god, your mistakes have left you deserted. You have devoted yourself to find a way back.", "abilities": [
			{"name": "Point to Prove", "description": "When being stunned or disarmed, you have the option to sacrifice health to ignore the ailment"},
			{"name": "Redemption", "description": "When healing an ally, 10% crit chance"},
			{"name": "Corrupted Strength", "description": "When 3+ enemies are within 2 tiles: +5 damage on all attacks, +5 armor per tempo cycle, but cannot be healed by allies"},
		]},
	]
	data.passive_description = "Chest items weigh 20% less"
	data.starting_item_name = "Bloodbound Plate"
	data.starting_item_description = "+2 DET. Overflow: Heal 2. +1 Armor on Armor Gain"
	data.slot_specialty = "Standard slots"  # TODO: give Brad (and Stephen) a slot identity later
	data.sprite_path = "res://assets/characters/brad_south.png"
	return data

static func get_all_characters() -> Array[CharacterData]:
	return [
		create_ryan(),
		create_jeremy(),
		create_stephen(),
		create_cory(),
		create_brad()
	]
