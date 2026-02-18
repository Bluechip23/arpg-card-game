class_name TurnManager
extends Node

## Manages the turn-based game loop

signal turn_started(turn_number: int)
signal turn_ended(turn_number: int)
signal player_turn_started
signal enemy_turn_started

var current_turn: int = 0
var turns_until_draw: float = 0.0
var draw_every_x_turns: float = 5.0

var player_stats: PlayerStats
var deck_manager: DeckManager

func initialize(p_stats: PlayerStats, p_deck: DeckManager) -> void:
	player_stats = p_stats
	deck_manager = p_deck
	draw_every_x_turns = p_stats.get_effective_draw_timer()  # Use the getter
	turns_until_draw = draw_every_x_turns
	print("[TURN] Initialized. Draw every %.2f turns" % draw_every_x_turns)

func take_turn() -> void:
	current_turn += 1
	turn_started.emit(current_turn)
	print("[TURN] === Turn %d ===" % current_turn)
	
	player_turn_started.emit()
	_process_player_turn()
	
	enemy_turn_started.emit()
	
	turn_ended.emit(current_turn)

func _process_player_turn() -> void:
	if deck_manager and deck_manager.inventory:
		deck_manager.inventory.process_turn()
	
	if player_stats:
		draw_every_x_turns = player_stats.get_effective_draw_timer()
	
	turns_until_draw -= 1.0
	print("[TURN] Turns until draw: %.2f" % turns_until_draw)
	
	if turns_until_draw <= 0:
		turns_until_draw = draw_every_x_turns
		if deck_manager:
			deck_manager.attempt_draw()

func get_turns_until_draw() -> float:
	return turns_until_draw

func reset() -> void:
	current_turn = 0
	turns_until_draw = draw_every_x_turns
