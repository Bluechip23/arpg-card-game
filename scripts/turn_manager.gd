class_name TurnManager
extends Node

## Manages tempo-driven game cycles: card draws and turn counting.
## All timers are now in global tempo units rather than discrete "turns".

signal turn_started(turn_number: int)
signal turn_ended(turn_number: int)
signal player_turn_started
signal enemy_turn_started  # Kept for compat (no longer used for enemy actions)

var current_turn: int = 0

## How many global tempo until the next card draw.
var tempo_until_draw: float = 0.0

## Card draw interval in global tempo. Default 25 = 5 old turns × 5 tempo/turn.
## Reduced by Wisdom: each WIS point = -1.25 tempo (equivalent to old -0.25 turns).
var draw_every_x_tempo: float = 25.0

var player_stats: PlayerStats
var deck_manager: DeckManager

func initialize(p_stats: PlayerStats, p_deck: DeckManager) -> void:
	player_stats = p_stats
	deck_manager = p_deck
	draw_every_x_tempo = _get_effective_draw_tempo()
	tempo_until_draw = draw_every_x_tempo
	print("[TURN] Initialized. Draw every %.1f tempo" % draw_every_x_tempo)

## Call this on every global tempo advance (from main.gd via tempo_advanced signal).
func process_tempo(amount: int) -> void:
	# Update draw interval from stats (Wisdom can change)
	if player_stats:
		draw_every_x_tempo = _get_effective_draw_tempo()

	tempo_until_draw -= float(amount)

	if tempo_until_draw <= 0.0:
		tempo_until_draw += draw_every_x_tempo  # Carry over remainder
		if deck_manager:
			deck_manager.attempt_draw()

## Called each tempo cycle (every 5 global tempo) to advance the turn counter
## and process inventory effects that are still cycle-based.
func take_turn() -> void:
	current_turn += 1
	turn_started.emit(current_turn)
	print("[TURN] === Cycle %d ===" % current_turn)

	player_turn_started.emit()

	if deck_manager and deck_manager.inventory:
		deck_manager.inventory.process_turn()

	enemy_turn_started.emit()
	turn_ended.emit(current_turn)

func _get_effective_draw_tempo() -> float:
	if not player_stats:
		return 25.0
	# Convert from the old "turns" formula to global tempo units (×5)
	var turns = max(1.0, player_stats.base_draw_timer - player_stats.get_wisdom_draw_bonus())
	return turns * 5.0

func get_tempo_until_draw() -> float:
	return tempo_until_draw

func reset() -> void:
	current_turn = 0
	tempo_until_draw = draw_every_x_tempo
