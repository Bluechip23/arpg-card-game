class_name TempoManager
extends Node

## Manages the universal tempo counter - the global clock for all game systems.
## Everything (enemy actions, mana regen, card draw, buff durations) is driven by tempo.
##
## TICKED TEMPO SYSTEM (per-owner slotted):
## When a card is played, its tempo_cost ticks are scheduled on the shared global
## ticker. Scheduling is SEQUENTIAL PER OWNER but CONCURRENT ACROSS OWNERS:
##   * A new card waits only for that same owner's still-pending ticks, so one
##     character playing two cards back-to-back stacks them just like solo play.
##   * It does NOT wait for a teammate's ticks — it drops into the first global
##     slots its own cards aren't already using, freely sharing slots with the
##     partner. So two characters can act at the same time on one tempo bar.
## With a single owner (solo play) this reduces exactly to the old sequential
## queue, since every card shares owner 0.
## Cards resolve at their resolve_tick (relative to when that card starts ticking).
## The auto-ticker only runs while there are card ticks to process.

signal tempo_changed(current: int, threshold: int)
signal tempo_threshold_reached(times: int)  # Fires every 5 global tempo (for buff/draw/mana cycles)
signal turn_triggered  # Alias for tempo_threshold_reached, kept for compat
signal tempo_advanced(global_total: int, amount: int)  # Fires on every tempo addition

# Tick system signals
signal tick_started(tick_number: int, total_ticks: int)  # Each tick as it processes
signal card_resolved(card: Card)  # Fired when a card's resolve_tick is reached
signal ticking_finished()  # All pending ticks have been processed

## How many global tempo = 1 cycle (used for mana regen, card draw, buff tick)
@export var tempo_threshold: int = 5

## How fast ticks process (seconds per tick). Lower = faster visual pacing.
@export var tick_speed: float = 1.5  # Default: 1.5s per tick. Adjustable in Settings (0.15s - 3.0s)

var current_tempo: int = 0   # Accumulator for the UI bar (resets at each cycle)
var global_tempo: int = 0    # Ever-increasing universal tempo clock
var _cycles_since_flash_refresh: int = 0  # Counts cycles toward the flash-point refresh
var _cycles_since_brain_refresh: int = 0  # Counts cycles toward the brain-point refresh
var spaces_moved_this_cycle: int = 0  # Total tiles moved since last cycle (for passives like Let's Dance)
var last_tempo_source: String = ""  # Tracks what caused the last tempo addition ("movement", "card", etc.)

var player_stats: PlayerStats

# Tick system state
var _ticking: bool = false          # Whether we're currently processing ticks
var _tick_timer: float = 0.0        # Countdown to next tick
var _pending_ticks: int = 0         # Global ticks remaining until ALL cards finish (max, not sum)

# Active card tracking — per-owner sequential, cross-owner concurrent.
# Each card's delay counts only that same owner's still-pending ticks, so a
# teammate's in-flight card shares global slots rather than pushing this one back.
var _active_cards: Array[Dictionary] = []  # [{card, resolve_tick, total_ticks, ticks_elapsed, delay, resolved, owner_id}]

func initialize(p_stats: PlayerStats) -> void:
	player_stats = p_stats
	current_tempo = 0
	global_tempo = 0
	_cycles_since_flash_refresh = 0
	_cycles_since_brain_refresh = 0
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

## Queue a card for ticked processing. The new card waits only for THIS OWNER's
## still-pending ticks (so one character's cards stack sequentially), but shares
## global slots with other owners' cards (so teammates can act simultaneously).
func start_card_ticks(card: Card, tempo_cost: int, resolve_tick: int, owner_id: int = 0) -> void:
	var card_entry := {
		"card": card,
		"resolve_tick": resolve_tick,
		"total_ticks": tempo_cost,
		"ticks_elapsed": 0,
		"delay": _owner_busy_ticks(owner_id),  # Wait only for our own queued ticks
		"resolved": false,
		"owner_id": owner_id,
	}
	_active_cards.append(card_entry)

	_recompute_pending()
	print("[TEMPO] Card '%s' (owner %d) queued: %d ticks (resolve at tick %d), delay %d. Global pending: %d" % [
		card.card_name, owner_id, tempo_cost, resolve_tick, card_entry["delay"], _pending_ticks])

	if not _ticking:
		_ticking = true
		_tick_timer = tick_speed
		print("[TEMPO] Tick processing started")

## How many ticks from now until this owner's currently-queued cards all finish.
## A new card from this owner starts ticking after this many global ticks.
func _owner_busy_ticks(owner_id: int) -> int:
	var busy := 0
	for e in _active_cards:
		if e["owner_id"] == owner_id:
			var remaining: int = e["delay"] + (e["total_ticks"] - e["ticks_elapsed"])
			busy = max(busy, remaining)
	return busy

## Global ticks remaining until every active card has fully resolved. Because
## owners overlap, this is the MAX finish time across cards, not the sum.
func _recompute_pending() -> void:
	var m := 0
	for e in _active_cards:
		var remaining: int = e["delay"] + (e["total_ticks"] - e["ticks_elapsed"])
		m = max(m, remaining)
	_pending_ticks = m

## Process a single tick of tempo
func _process_one_tick() -> void:
	# Advance global state by 1
	global_tempo += 1
	current_tempo += 1

	# Advance all active cards. Owners tick concurrently: every card whose own
	# delay has elapsed advances on this same global tick.
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

	# Clean up finished cards (all ticks elapsed and no delay remaining)
	_active_cards = _active_cards.filter(func(e): return e["ticks_elapsed"] < e["total_ticks"] or e["delay"] > 0)
	_recompute_pending()

	print("[TEMPO] Tick %d | %d in cycle | %d pending" % [global_tempo, current_tempo, _pending_ticks])

	# Emit standard signals so all existing systems (enemies, mana, draw) work per-tick
	tempo_advanced.emit(global_tempo, 1)
	tick_started.emit(global_tempo, _pending_ticks)

	tempo_changed.emit(current_tempo, tempo_threshold)
	_check_threshold()

	# Check if all ticks are done
	if _pending_ticks <= 0:
		_ticking = false
		_active_cards.clear()
		print("[TEMPO] All ticks complete. Global tempo: %d" % global_tempo)
		ticking_finished.emit()

## Cancel all pending ticks for a specific card. Returns the number of ticks removed.
## Used when an enemy dies mid-queue and remaining cards targeting it need to be returned.
func cancel_card_ticks(card: Card) -> int:
	var cancelled_ticks := 0
	for i in range(_active_cards.size() - 1, -1, -1):
		var entry = _active_cards[i]
		if entry["card"] == card:
			# Refund only the card's OWN unelapsed ticks — its queue delay is
			# just waiting on earlier actions, not tempo this card would spend.
			var remaining = entry["total_ticks"] - entry["ticks_elapsed"]
			cancelled_ticks += remaining
			_active_cards.remove_at(i)
			print("[TEMPO] Cancelled card '%s': removed %d ticks" % [card.card_name, remaining])

	# Recalculate delays for remaining cards after removal, then recompute the
	# global remaining-tick count from the survivors.
	_recalculate_delays()
	_recompute_pending()
	if _pending_ticks <= 0:
		_ticking = false
		_active_cards.clear()
		print("[TEMPO] All ticks cancelled. Stopping tick processing.")
		ticking_finished.emit()

	return cancelled_ticks

## Recalculate delay values for active cards after a cancellation. Delays chain
## sequentially WITHIN each owner but are independent ACROSS owners (so removing
## one player's card never reshuffles the teammate's timeline).
func _recalculate_delays() -> void:
	var cumulative_by_owner := {}  # owner_id -> ticks consumed so far by that owner
	for entry in _active_cards:
		var owner_id: int = entry["owner_id"]
		var cumulative: int = cumulative_by_owner.get(owner_id, 0)
		if entry["ticks_elapsed"] > 0:
			# Already ticking — it keeps its current slot (delay 0)
			entry["delay"] = 0
			cumulative = max(cumulative, entry["total_ticks"] - entry["ticks_elapsed"])
		else:
			# Not yet started — wait for this owner's prior remaining ticks
			entry["delay"] = cumulative
			cumulative += entry["total_ticks"]
		cumulative_by_owner[owner_id] = cumulative

## Check if ticks are currently being processed
func is_ticking() -> bool:
	return _ticking

## True once this card's own ticks have begun (its queue delay elapsed) —
## the point of no return: a started action can no longer be cancelled.
func is_card_started(card: Card) -> bool:
	for e in _active_cards:
		if e["card"] == card:
			return e["delay"] <= 0
	return false

## True while this owner has ANY action ticking or queued — the "glued to
## your position" state: no movement until the ticks run out.
func owner_is_busy(owner_id: int = 0) -> bool:
	return _owner_busy_ticks(owner_id) > 0

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
		# Flash points (Agility) refresh every FLASH_REFRESH_CYCLES cycles
		_cycles_since_flash_refresh += times_triggered
		if player_stats and _cycles_since_flash_refresh >= PlayerStats.FLASH_REFRESH_CYCLES:
			_cycles_since_flash_refresh = 0
			player_stats.refresh_flash_points()
			print("[TEMPO] Flash points refreshed: %d" % player_stats.current_flash_points)
		# Brain points (Wisdom) refresh every BRAIN_REFRESH_CYCLES cycles —
		# deliberately slower than flash: the mind plans, the body reacts.
		_cycles_since_brain_refresh += times_triggered
		if player_stats and _cycles_since_brain_refresh >= PlayerStats.BRAIN_REFRESH_CYCLES:
			_cycles_since_brain_refresh = 0
			player_stats.refresh_brain_points()
			print("[TEMPO] Brain points refreshed: %d" % player_stats.current_brain_points)
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
	spaces_moved_this_cycle += 1
	# Flash points (Agility) make the move tempo-free — but only when the player
	# has toggled flash movement on (the HUD lightning-bolt button). Spending
	# the pool is a choice, not automatic.
	if player_stats and player_stats.flash_movement_enabled:
		# Rollerblades discount the movement flash cost (min 1).
		var move_cost: int = max(1, PlayerStats.FLASH_COST_MOVE - player_stats.equipment_movement_flash_discount)
		if player_stats.spend_flash_points(move_cost):
			print("[TEMPO] Flash move (%d left) | %d tiles this cycle" % [
				player_stats.current_flash_points, spaces_moved_this_cycle])
			# Boots of Speed: bank movement flash; at the threshold, fire the bonus.
			if player_stats.movement_flash_tempo_threshold > 0:
				player_stats.movement_flash_accum += move_cost
				if player_stats.movement_flash_accum >= player_stats.movement_flash_tempo_threshold:
					player_stats.movement_flash_accum -= player_stats.movement_flash_tempo_threshold
					player_stats.movement_flash_threshold_reached.emit()
			return
	last_tempo_source = "movement"
	add_tempo(1)

func add_pass_through_tempo() -> void:
	## Moving through an occupied tile always costs 2 tempo regardless of flash points.
	print("[TEMPO] Pass-through occupied tile — forced 2 tempo")
	add_tempo(2)

func get_tempo() -> int:
	return current_tempo

func get_global_tempo() -> int:
	return global_tempo

func get_threshold() -> int:
	return tempo_threshold

func get_tempo_percent() -> float:
	return float(current_tempo) / float(tempo_threshold)

func get_tempo_until_flash_refresh() -> int:
	## Whole tempo remaining before the next flash-point refill.
	return maxi(1, (PlayerStats.FLASH_REFRESH_CYCLES - _cycles_since_flash_refresh) * tempo_threshold - current_tempo)

func get_tempo_until_brain_refresh() -> int:
	## Whole tempo remaining before the next brain-point refill.
	return maxi(1, (PlayerStats.BRAIN_REFRESH_CYCLES - _cycles_since_brain_refresh) * tempo_threshold - current_tempo)
