class_name CharacterData
extends Resource

## Defines a character's base stats

@export var character_name: String = "Default"

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
@export var base_hand_size: int = 6

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

# Card upgrades: Array of {card_index: int, upgrade_path: int}
# card_index refers to the position in the final deck list (after removals)
# upgrade_path: 0 = path 1, 1 = path 2
@export var card_upgrades: Array = []

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

func get_movement_per_cycle() -> int:
	# Agility determines movement: base 1, +1 per 8 agility
	return 1 + floori(agility / 8.0)

func get_mana_regen() -> float:
	# Base mana regen
	return base_mana_regen

static func create_ryan() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Ryan"
	data.strength = 5
	data.dexterity = 12
	data.intelligence = 5
	data.wisdom = 5
	data.determination = 5
	data.agility = 8
	data.base_health = 5
	data.base_mana = 5
	data.base_mana_regen = 1.0
	data.base_draw_timer = 5
	data.base_hand_size = 5
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
	data.slot_specialty = "4 belt slots"
	data.sprite_path = "res://assets/characters/ryan_south.png"
	return data

static func create_jeremy() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Jeremy"
	data.strength = 5
	data.dexterity = 5
	data.intelligence = 12
	data.wisdom = 8
	data.determination = 5
	data.agility = 5
	data.base_health = 5
	data.base_mana = 5
	data.base_mana_regen = 1.0
	data.base_draw_timer = 5
	data.base_hand_size = 5
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
	data.passive_description = "First ring trigger per turn triggers twice"
	data.starting_item_name = "Scholar's Signet"
	data.starting_item_description = "+3 INT. +3% chance. On Utility: +1 Mana"
	data.slot_specialty = "4 ring slots"
	data.sprite_path = "res://assets/characters/jeremy_south.png"
	return data

static func create_stephen() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Stephen"
	data.strength = 12
	data.dexterity = 8
	data.intelligence = 5
	data.wisdom = 5
	data.determination = 5
	data.agility = 5
	data.base_health = 5
	data.base_mana = 5
	data.base_mana_regen = 1.0
	data.base_draw_timer = 5
	data.base_hand_size = 5
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
	data.slot_specialty = "4 weapon slots, 3 ring slots"
	data.sprite_path = "res://assets/characters/stephen_south.png"
	data.sprite_sheet_path = "res://assets/characters/stephen_spritesheet.png"
	return data

static func create_cory() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Cory"
	data.strength = 5
	data.dexterity = 5
	data.intelligence = 5
	data.wisdom = 12
	data.determination = 5
	data.agility = 8
	data.base_health = 5
	data.base_mana = 5
	data.base_mana_regen = 1.0
	data.base_draw_timer = 5
	data.base_hand_size = 5
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
	data.strength = 8
	data.dexterity = 5
	data.intelligence = 5
	data.wisdom = 5
	data.determination = 12
	data.agility = 5
	data.base_health = 5
	data.base_mana = 5
	data.base_mana_regen = 1.0
	data.base_draw_timer = 5
	data.base_hand_size = 5
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
	data.passive_description = "Chest items weigh 15% less"
	data.starting_item_name = "Bloodbound Plate"
	data.starting_item_description = "+2 DET. Overflow: Heal 2. +1 Armor on Armor Gain"
	data.slot_specialty = "8 weapon slots"
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
