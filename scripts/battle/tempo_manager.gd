class_name TempoManager
extends Node

## Manages the universal tempo counter - the global clock for all game systems.
## Everything (enemy actions, mana regen, card draw, buff durations) is driven by tempo.
##
## TICKED TEMPO SYSTEM:
## When a card is played, its tempo_cost ticks are added to a sequential queue.
## Cards resolve at their resolve_tick (relative to when that card starts ticking).
## If a second card is played while ticking, its ticks are APPENDED after the
## current card's ticks — they never overlap.
## The auto-ticker only runs while there are card ticks to process.

signal tempo_changed(current: int, threshold: int)
signal tempo_threshold_reached(times: int)  # Fires every 5 global tempo (for buff/draw/mana cycles)
signal turn_triggered  # Alias for tempo_threshold_reached, kept for compat
signal tempo_advanced(global_total: int, amount: int)  # Fires on every tempo addition

# Tick system signals
signal tick_started(tick_number: int, total_ticks: int)  # Each tick as it processes
signal card_resolved(card: Card)  # Fired when a card's resolve_tick is reached
signal ticking_finished()  # All pending ticks have been processed
signal player_can_queue()  # Kept for compat, not currently emitted

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
var _pending_ticks: int = 0         # Total ticks remaining in the queue

# Active card tracking — sequential queue with delays
# Each card waits for all previously queued ticks before it starts ticking.
var _active_cards: Array[Dictionary] = []  # [{card, resolve_tick, total_ticks, ticks_elapsed, delay, resolved, owner}]

func initialize(p_stats: PlayerStats) -> void:
	player_stats = p_stats
	current_tempo = 0
	global_tempo = 0
	movements_since_tempo = 0
	_ticking = false
	_pending_ticks = 0
	_active_cards.clear()
	print("[TEMPO] Initialized (ticked). Cycle every %d tempo, tick speed %.2fs" % [tempo_threshold, tick_speed])

func _process(delta: float) -> void:
	if not _ticking or _pending_ticks <= 0:
		return

	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = tick_speed
		_process_one_tick()

## Queue a card for ticked processing. New cards are APPENDED after all
## currently pending ticks — they never overlap.
func start_card_ticks(card: Card, tempo_cost: int, resolve_tick: int, owner_id: int = 0) -> void:
	var card_entry := {
		"card": card,
		"resolve_tick": resolve_tick,
		"total_ticks": tempo_cost,
		"ticks_elapsed": 0,
		"delay": _pending_ticks,  # Wait for all currently queued ticks first
		"resolved": false,
		"owner_id": owner_id,
	}
	_active_cards.append(card_entry)

	_pending_ticks += tempo_cost
	print("[TEMPO] Card '%s' queued: %d ticks (resolve at tick %d), delay %d. Total pending: %d" % [
		card.card_name, tempo_cost, resolve_tick, card_entry["delay"], _pending_ticks])

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
		# If this card still has delay, decrement delay instead of ticking
		if entry["delay"] > 0:
			entry["delay"] -= 1
			continue

		if entry["ticks_elapsed"] < entry["total_ticks"]:
			entry["ticks_elapsed"] += 1

			# Check if this card should resolve on this tick
			if entry["ticks_elapsed"] == entry["resolve_tick"] and not entry["resolved"]:
				entry["resolved"] = true
				print("[TEMPO] Card '%s' RESOLVES at tick %d/%d" % [
					entry["card"].card_name, entry["ticks_elapsed"], entry["total_ticks"]])
				card_resolved.emit(entry["card"])

	# Emit standard signals so all existing systems (enemies, mana, draw) work per-tick
	tempo_advanced.emit(global_tempo, 1)
	tick_started.emit(global_tempo, _pending_ticks)

	tempo_changed.emit(current_tempo, tempo_threshold)
	_check_threshold()

	# Clean up finished cards (all ticks elapsed and no delay remaining)
	_active_cards = _active_cards.filter(func(e): return e["ticks_elapsed"] < e["total_ticks"] or e["delay"] > 0)

	# Check if all ticks are done
	if _pending_ticks <= 0:
		_ticking = false
		_active_cards.clear()
		print("[TEMPO] All ticks complete. Global tempo: %d" % global_tempo)
		ticking_finished.emit()

## Check if ticks are currently being processed
func is_ticking() -> bool:
	return _ticking

## Get ticking progress for the currently active card (the one actually ticking, not delayed).
func get_active_card_progress(owner_id: int = 0) -> Dictionary:
	for entry in _active_cards:
		if entry["owner_id"] == owner_id and entry["delay"] <= 0 and entry["ticks_elapsed"] < entry["total_ticks"]:
			return {
				"ticks_elapsed": entry["ticks_elapsed"],
				"total_ticks": entry["total_ticks"],
				"resolve_tick": entry["resolve_tick"],
				"resolved": entry["resolved"],
			}
	return {}

## Get the total number of pending ticks in the queue (for UI display).
func get_total_pending_ticks() -> int:
	return _pending_ticks

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

## Instant tempo add for non-card sources (movement, pass-through, wait, basic attack/block).
## These resolve immediately and advance the global counter.
func add_tempo(amount: int) -> void:
	if amount <= 0:
		return

	global_tempo += amount
	current_tempo += amount
	print("[TEMPO] +%d tempo (instant) → %d in cycle | %d global" % [amount, current_tempo, global_tempo])

	# Notify all systems that tempo has advanced (enemies check their own counters here)
	tempo_advanced.emit(global_tempo, amount)

	tempo_changed.emit(current_tempo, tempo_threshold)
	_check_threshold()

## Start ticked processing for a card. Wraps start_card_ticks.
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
