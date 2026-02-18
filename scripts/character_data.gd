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

# Calculate derived stats from core stats
func get_max_hand_size() -> int:
	# Wisdom adds to hand size: every 5 wisdom = +1 hand size
	return base_hand_size + floori(wisdom / 5.0)

func get_movement_per_turn() -> int:
	# Agility determines movement: base 1, +1 per 8 agility
	return 1 + floori(agility / 8.0)

func get_mana_regen() -> float:
	# Base mana regen
	return base_mana_regen

static func create_ryan() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Ryan"
	data.strength = 8
	data.dexterity = 15
	data.intelligence = 8
	data.wisdom = 10
	data.determination = 10
	data.agility = 10
	data.base_health = 6
	data.base_mana = 10
	data.base_mana_regen = 1.0
	data.base_draw_timer = 4
	data.base_hand_size = 8
	data.starting_card_ids = [
		"discard", "discard",
		"raged_circulation", "poisoned_blood", "elixir", "heal",
		"shadows", "preparation", "exacerbate_wounds", "reposition",
		"ryan_dagger_throw", "volatile_mixture", "understanding"
	]
	return data

static func create_jeremy() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Jeremy"
	data.strength = 8
	data.dexterity = 10
	data.intelligence = 12
	data.wisdom = 14
	data.determination = 8
	data.agility = 8
	data.base_health = 8
	data.base_mana = 12
	data.base_mana_regen = 1.0
	data.base_draw_timer = 5
	data.base_hand_size = 10
	data.starting_card_ids = [
		"draw", "draw",
		"trick_shot", "surrounding_ice", "risk_it", "biscuit",
		"loaded_die", "worst_that_could_happen", "oops", "house_money",
		"hope_this_works", "lady_luck", "try_this", "if_pigs_could_fly",
		"snowballs_chance"
	]
	return data

static func create_stephen() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Stephen"
	data.strength = 14
	data.dexterity = 8
	data.intelligence = 10
	data.wisdom = 10
	data.determination = 4
	data.agility = 12
	data.base_health = 5
	data.base_mana = 8
	data.base_mana_regen = 1.0
	data.base_draw_timer = 6
	data.base_hand_size = 6
	data.starting_card_ids = [
		"empower", "empower",
		"mark", "rise", "quick_shot", "reload", "enchanted_quiver",
		"tighten_string", "down_town", "barricade", "sky_fall",
		"sky_attack", "lead_arrow", "last_breath", "mixed_bag"
	]
	return data

static func create_cory() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Cory"
	data.strength = 10
	data.dexterity = 12
	data.intelligence = 6
	data.wisdom = 12
	data.determination = 12
	data.agility = 10
	data.base_health = 12
	data.base_mana = 14
	data.base_mana_regen = 1.0
	data.base_draw_timer = 3
	data.base_hand_size = 14
	data.starting_card_ids = [
		"blink", "blink",
		"round_em_up", "trip", "choke", "push", "defensive_awareness",
		"sweeping_disarm", "cory_blink", "consecutive_snap", "swap", "meditate"
	]
	return data

static func create_brad() -> CharacterData:
	var data = CharacterData.new()
	data.character_name = "Brad"
	data.strength = 12
	data.dexterity = 6
	data.intelligence = 8
	data.wisdom = 6
	data.determination = 16
	data.agility = 10
	data.base_health = 16
	data.base_mana = 8
	data.base_mana_regen = 1.0
	data.base_draw_timer = 5
	data.base_hand_size = 5
	data.starting_card_ids = [
		"heal", "heal",
		"life_swap", "wear_down", "taunt", "life_steal", "roar",
		"poke", "armor_break", "charge", "heroic_leap", "morphine",
		"turtle_up", "parry", "approach", "hold_the_line"
	]
	return data

static func get_all_characters() -> Array[CharacterData]:
	return [
		create_ryan(),
		create_jeremy(),
		create_stephen(),
		create_cory(),
		create_brad()
	]
