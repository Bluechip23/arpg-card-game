class_name TempoManager
extends Node

## Manages the universal tempo counter - the global clock for all game systems.
## Everything (enemy actions, mana regen, card draw, buff durations) is driven by tempo.
##
## TICKED TEMPO SYSTEM:
## When a card is played, tempo ticks one at a time instead of resolving in bulk.
## Cards have a resolve_tick that determines when their effect fires.
## After resolution, the player can queue their next card during remaining recovery ticks.
## In multiplayer, the global tick counter uses a high-water mark so simultaneous
## cards overlap instead of stacking.

signal tempo_changed(current: int, threshold: int)
signal tempo_threshold_reached(times: int)  # Fires every 5 global tempo (for buff/draw/mana cycles)
signal turn_triggered  # Alias for tempo_threshold_reached, kept for compat
signal tempo_advanced(global_total: int, amount: int)  # Fires on every tempo addition

# Tick system signals
signal tick_started(tick_number: int, total_ticks: int)  # Each tick as it processes
signal card_resolved(card: Card)  # Fired when a card's resolve_tick is reached
signal ticking_finished()  # All pending ticks have been processed
signal player_can_queue()  # Player's active card has resolved, they can queue next

## How many global tempo = 1 cycle (used for mana regen, card draw, buff tick)
@export var tempo_threshold: int = 5

## How fast ticks process (seconds per tick). Lower = faster visual pacing.
@export var tick_speed: float = 1.5  # Default: 1.5s per tick. Adjustable in Settings (0.15s - 3.0s)

var current_tempo: int = 0   # Accumulator for the UI bar (resets at each cycle)
var global_tempo: int = 0    # Ever-increasing universal tempo clock
var movements_since_tempo: int = 0
var spaces_moved_this_cycle: int = 0  # Total tiles moved since last cycle (for passives like Let's Dance)
var last_tempo_source: String = ""  # Tracks what caused the last tempo addition ("movement", "card", etc.)

var player_stats: PlayerStats

# Tick system state
var _ticking: bool = false          # Whether we're currently processing ticks
var _tick_timer: float = 0.0        # Countdown to next tick
var _pending_ticks: int = 0         # How many ticks remain to process
var _tick_end_global: int = 0       # High-water mark: the global tempo the tick queue ends at

# Active card tracking (per-player in future, single player for now)
var _active_cards: Array[Dictionary] = []  # [{card, resolve_tick, ticks_remaining, resolved, owner}]
var _queued_card: Dictionary = {}   # Card queued during recovery, starts after current finishes

func initialize(p_stats: PlayerStats) -> void:
	player_stats = p_stats
	current_tempo = 0
	global_tempo = 0
	movements_since_tempo = 0
	_ticking = false
	_pending_ticks = 0
	_tick_end_global = 0
	_active_cards.clear()
	_queued_card = {}
	print("[TEMPO] Initialized (ticked). Cycle every %d tempo, tick speed %.2fs" % [tempo_threshold, tick_speed])

func _process(delta: float) -> void:
	if not _ticking or _pending_ticks <= 0:
		return

	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = tick_speed
		_process_one_tick()

## Start ticking tempo for a card play. Uses high-water mark for multiplayer overlap.
func start_card_ticks(card: Card, tempo_cost: int, resolve_tick: int, owner_id: int = 0) -> void:
	var card_entry := {
		"card": card,
		"resolve_tick": resolve_tick,
		"total_ticks": tempo_cost,
		"ticks_elapsed": 0,
		"resolved": false,
		"owner_id": owner_id,
	}
	_active_cards.append(card_entry)

	# High-water mark: extend tick queue if this card goes past current end
	var new_end = global_tempo + tempo_cost
	if new_end > _tick_end_global:
		var additional_ticks = new_end - _tick_end_global
		_pending_ticks += additional_ticks
		_tick_end_global = new_end
		print("[TEMPO] Card '%s' queued: %d ticks (resolve at tick %d). Global end → %d (+%d new ticks)" % [
			card.card_name, tempo_cost, resolve_tick, _tick_end_global, additional_ticks])
	else:
		# Card fits within existing tick window (multiplayer overlap)
		print("[TEMPO] Card '%s' overlaps existing ticks: %d ticks (resolve at tick %d). Global end stays %d" % [
			card.card_name, tempo_cost, resolve_tick, _tick_end_global])

	if not _ticking:
		_ticking = true
		_tick_timer = tick_speed
		print("[TEMPO] Tick processing started")

## Process a single tick of tempo
func _process_one_tick() -> void:
	# Advance global state by 1
	global_tempo += 1
	current_tempo += 1
	_pending_ticks -= 1

	var tick_num = global_tempo
	print("[TEMPO] Tick %d | %d in cycle | %d pending" % [tick_num, current_tempo, _pending_ticks])

	# Advance all active cards
	for entry in _active_cards:
		if entry["ticks_elapsed"] < entry["total_ticks"]:
			entry["ticks_elapsed"] += 1

			# Check if this card should resolve on this tick
			if entry["ticks_elapsed"] == entry["resolve_tick"] and not entry["resolved"]:
				entry["resolved"] = true
				print("[TEMPO] Card '%s' RESOLVES at tick %d/%d" % [
					entry["card"].card_name, entry["ticks_elapsed"], entry["total_ticks"]])
				card_resolved.emit(entry["card"])

			# Check if player can queue after their card resolves
			if entry["resolved"] and entry["ticks_elapsed"] == entry["resolve_tick"]:
				player_can_queue.emit()

	# Emit standard signals so all existing systems (enemies, mana, draw) work per-tick
	tempo_advanced.emit(global_tempo, 1)
	tick_started.emit(global_tempo, _pending_ticks)

	tempo_changed.emit(current_tempo, tempo_threshold)
	_check_threshold()

	# Clean up finished cards
	_active_cards = _active_cards.filter(func(e): return e["ticks_elapsed"] < e["total_ticks"])

	# Check if all ticks are done
	if _pending_ticks <= 0:
		_ticking = false
		_active_cards.clear()
		print("[TEMPO] All ticks complete. Global tempo: %d" % global_tempo)
		ticking_finished.emit()

		# If there's a queued card, it will be handled by main.gd via ticking_finished

## Check if the player's active card has resolved (they can queue next action)
func is_player_card_resolved(owner_id: int = 0) -> bool:
	for entry in _active_cards:
		if entry["owner_id"] == owner_id and not entry["resolved"]:
			return false
	return true

## Check if ticks are currently being processed
func is_ticking() -> bool:
	return _ticking

## Get ticking progress for UI (returns {ticks_elapsed, total_ticks, resolve_tick} for active card)
func get_active_card_progress(owner_id: int = 0) -> Dictionary:
	for entry in _active_cards:
		if entry["owner_id"] == owner_id:
			return {
				"ticks_elapsed": entry["ticks_elapsed"],
				"total_ticks": entry["total_ticks"],
				"resolve_tick": entry["resolve_tick"],
				"resolved": entry["resolved"],
			}
	return {}

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

## Legacy bulk add for non-card tempo (movement, pass-through).
## These still resolve instantly since they happen between card plays.
func add_tempo(amount: int) -> void:
	if amount <= 0:
		return

	global_tempo += amount
	current_tempo += amount
	# Update high-water mark if we're mid-tick
	if _ticking:
		_tick_end_global = maxi(_tick_end_global, global_tempo)
	print("[TEMPO] +%d tempo (instant) → %d in cycle | %d global" % [amount, current_tempo, global_tempo])

	# Notify all systems that tempo has advanced (enemies check their own counters here)
	tempo_advanced.emit(global_tempo, amount)

	tempo_changed.emit(current_tempo, tempo_threshold)
	_check_threshold()

## Legacy card tempo for backward compatibility. Now starts ticked processing.
func add_card_tempo(tempo_cost: int, card: Card = null, resolve_tick: int = 1, owner_id: int = 0) -> void:
	last_tempo_source = "card"
	if card:
		start_card_ticks(card, tempo_cost, resolve_tick, owner_id)
	else:
		# Fallback: no card reference, use instant bulk add (basic attacks, etc.)
		add_tempo(tempo_cost)

func add_movement_tempo() -> void:
	var free_moves = get_free_moves_from_agility()
	movements_since_tempo += 1
	spaces_moved_this_cycle += 1
	print("[TEMPO] Movement %d / %d free moves | %d tiles this cycle" % [movements_since_tempo, free_moves, spaces_moved_this_cycle])

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
