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

var starting_card_ids: Array = []  # Character-specific cards added to starting deck

# Selection screen display info
var passive_description: String = ""
var starting_item_name: String = ""
var starting_item_description: String = ""
var slot_specialty: String = ""
var sprite_path: String = ""

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
	data.dexterity = 5
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
		"discard", "discard",
		"raged_circulation", "poisoned_blood", "elixir", "heal",
		"shadows", "preparation", "exacerbate_wounds", "reposition",
		"dagger_throw", "volatile_mixture", "understanding",
		"shuriken_pouch"
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
		"draw", "draw",
		"trick_shot", "surrounding_ice", "risk_it", "biscuit",
		"loaded_die", "worst_that_could_happen", "oops", "house_money",
		"hope_this_works", "lady_luck", "try_this", "if_pigs_could_fly",
		"snowballs_chance"
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
	data.strength = 5
	data.dexterity = 5
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
		"empower", "empower",
		"mark", "rise", "quick_shot", "reload", "enchanted_quiver",
		"tighten_string", "down_town", "barricade", "sky_fall",
		"sky_attack", "lead_arrow", "last_breath", "mixed_bag",
		"bottomless_quiver"
	]
	data.passive_description = "+10% off-hand enchantments (others get -10%)"
	data.starting_item_name = "Flickerstep Boots"
	data.starting_item_description = "+2 DEX. Grants 1 Blink card"
	data.slot_specialty = "4 weapon slots, 3 ring slots"
	data.sprite_path = "res://assets/characters/stephen_south.png"
	return data

static func create_cory() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Cory"
	data.strength = 5
	data.dexterity = 5
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
		"blink", "blink",
		"round_em_up", "trip", "choke", "push", "defensive_awareness",
		"sweeping_disarm", "consecutive_snap", "swap", "meditate"
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
	data.strength = 5
	data.dexterity = 5
	data.intelligence = 5
	data.wisdom = 5
	data.determination = 5
	data.agility = 5
	data.base_health = 5
	data.base_mana = 4
	data.base_mana_regen = 1.0
	data.base_draw_timer = 5
	data.base_hand_size = 5
	data.starting_card_ids = [
		"heal", "heal",
		"life_swap", "wear_down", "taunt", "life_steal", "roar",
		"poke", "armor_break", "charge", "heroic_leap", "morphine",
		"turtle_up", "parry", "approach", "hold_the_line"
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
