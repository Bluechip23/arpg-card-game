class_name TempoManager
extends Node

## Manages the universal tempo counter that triggers enemy turns

signal tempo_changed(current: int, threshold: int)
signal tempo_threshold_reached(times: int)  # How many times threshold was crossed
signal turn_triggered  # A "turn" now means tempo threshold reached

@export var tempo_threshold: int = 5

var current_tempo: int = 0
var movements_since_tempo: int = 0  # Track movements for AGI-based free moves

var player_stats: PlayerStats

func initialize(p_stats: PlayerStats) -> void:
	player_stats = p_stats
	current_tempo = 0
	movements_since_tempo = 0
	print("[TEMPO] Initialized. Threshold: %d" % tempo_threshold)

func add_tempo(amount: int) -> void:
	if amount <= 0:
		return
	
	current_tempo += amount
	print("[TEMPO] +%d tempo → %d / %d" % [amount, current_tempo, tempo_threshold])
	tempo_changed.emit(current_tempo, tempo_threshold)
	
	_check_threshold()

func _check_threshold() -> void:
	var times_triggered = 0
	
	while current_tempo >= tempo_threshold:
		current_tempo -= tempo_threshold
		times_triggered += 1
		print("[TEMPO] Threshold reached! Enemies act. Overflow: %d" % current_tempo)
	
	if times_triggered > 0:
		tempo_threshold_reached.emit(times_triggered)
		turn_triggered.emit()
		tempo_changed.emit(current_tempo, tempo_threshold)

func add_card_tempo(tempo_cost: int) -> void:
	# Cards directly add their tempo cost
	add_tempo(tempo_cost)

func add_movement_tempo() -> void:
	# Movement tempo is gated by agility
	# AGI determines how many free moves before 1 tempo is added
	var free_moves = get_free_moves_from_agility()
	
	movements_since_tempo += 1
	print("[TEMPO] Movement %d / %d free moves" % [movements_since_tempo, free_moves])
	
	if movements_since_tempo > free_moves:
		movements_since_tempo = 1  # Reset, this move costs tempo
		add_tempo(1)

func get_free_moves_from_agility() -> int:
	if not player_stats:
		return 1
	# Every 5 AGI grants 1 movement per tempo
	# AGI 5 = 1 free move, AGI 10 = 2 free moves, etc.
	return max(1, floori(player_stats.agility / 5.0))

func reset_movement_counter() -> void:
	# Call this at start of player action phase if needed
	movements_since_tempo = 0

func get_tempo() -> int:
	return current_tempo

func get_threshold() -> int:
	return tempo_threshold

func get_tempo_percent() -> float:
	return float(current_tempo) / float(tempo_threshold)
