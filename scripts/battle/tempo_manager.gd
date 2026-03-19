class_name TempoManager
extends Node

## Manages the universal tempo counter - the global clock for all game systems.
## Everything (enemy actions, mana regen, card draw, buff durations) is driven by tempo.

signal tempo_changed(current: int, threshold: int)
signal tempo_threshold_reached(times: int)  # Fires every 5 global tempo (for buff/draw/mana cycles)
signal turn_triggered  # Alias for tempo_threshold_reached, kept for compat
signal tempo_advanced(global_total: int, amount: int)  # Fires on every tempo addition

## How many global tempo = 1 cycle (used for mana regen, card draw, buff tick)
@export var tempo_threshold: int = 5

var current_tempo: int = 0   # Accumulator for the UI bar (resets at each cycle)
var global_tempo: int = 0    # Ever-increasing universal tempo clock
var movements_since_tempo: int = 0
var last_tempo_source: String = ""  # Tracks what caused the last tempo addition ("movement", "card", etc.)

var player_stats: PlayerStats

func initialize(p_stats: PlayerStats) -> void:
	player_stats = p_stats
	current_tempo = 0
	global_tempo = 0
	movements_since_tempo = 0
	print("[TEMPO] Initialized. Cycle every %d tempo" % tempo_threshold)

func add_tempo(amount: int) -> void:
	if amount <= 0:
		return

	global_tempo += amount
	current_tempo += amount
	print("[TEMPO] +%d tempo → %d in cycle | %d global" % [amount, current_tempo, global_tempo])

	# Notify all systems that tempo has advanced (enemies check their own counters here)
	tempo_advanced.emit(global_tempo, amount)

	tempo_changed.emit(current_tempo, tempo_threshold)
	_check_threshold()

func _check_threshold() -> void:
	var times_triggered = 0

	while current_tempo >= tempo_threshold:
		current_tempo -= tempo_threshold
		times_triggered += 1
		print("[TEMPO] Cycle complete! Overflow: %d" % current_tempo)

	if times_triggered > 0:
		tempo_threshold_reached.emit(times_triggered)
		turn_triggered.emit()
		tempo_changed.emit(current_tempo, tempo_threshold)

func add_card_tempo(tempo_cost: int) -> void:
	last_tempo_source = "card"
	add_tempo(tempo_cost)

func add_movement_tempo() -> void:
	var free_moves = get_free_moves_from_agility()
	movements_since_tempo += 1
	print("[TEMPO] Movement %d / %d free moves" % [movements_since_tempo, free_moves])

	if movements_since_tempo > free_moves:
		movements_since_tempo = 1
		last_tempo_source = "movement"
		add_tempo(1)

func add_pass_through_tempo() -> void:
	## Moving through an occupied tile always costs 2 tempo regardless of movement speed.
	print("[TEMPO] Pass-through occupied tile — forced 2 tempo")
	add_tempo(2)

func get_free_moves_from_agility() -> int:
	if not player_stats:
		return 1
	return max(1, floori(player_stats.agility / 5.0) + player_stats.enchantment_movement_bonus)

func reset_movement_counter() -> void:
	movements_since_tempo = 0

func get_tempo() -> int:
	return current_tempo

func get_global_tempo() -> int:
	return global_tempo

func get_threshold() -> int:
	return tempo_threshold

func get_tempo_percent() -> float:
	return float(current_tempo) / float(tempo_threshold)
