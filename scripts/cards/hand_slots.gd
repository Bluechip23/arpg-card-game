class_name HandSlots
extends RefCounted

## Persistent hand → play-button (lettered slot) mapping.
##
## Identical cards (same stack signature) collapse under one lettered slot, and
## a slot keeps its letter until the last copy of its card leaves the hand.
## Playing a card therefore never re-letters the others; a genuinely new card
## fills the lowest free slot (A, then S, …). This keeps play buttons stable so
## the player can spam / combo a card without the key moving underneath them.
##
## Pure instant (reaction) cards trigger on their own and can't be played
## manually, so they never occupy a lettered slot: they all share one signature
## (Card.INSTANT_STACK_SIG_PREFIX) and render as a single key-less stack
## (slot = INSTANT_SLOT) at the right end of the hand.

const LETTERS = ["A", "S", "D", "F", "G", "Q", "W", "E", "R", "T", "Z", "X", "C", "V", "B"]
const INSTANT_SLOT := -1  # Pseudo-slot for the instant stack: no play key.

# Per-slot stack signature; "" means the slot is free.
var slot_sig: Array = []

static func letter(slot: int) -> String:
	if slot >= 0 and slot < LETTERS.size():
		return LETTERS[slot]
	return "?"

static func is_instant_sig(sig: String) -> bool:
	return sig.begins_with(Card.INSTANT_STACK_SIG_PREFIX)

func num_slots() -> int:
	return LETTERS.size()

func reset() -> void:
	slot_sig.clear()

func _ensure_size() -> void:
	var n := num_slots()
	if slot_sig.size() != n:
		slot_sig.resize(n)
		for i in range(n):
			if slot_sig[i] == null:
				slot_sig[i] = ""

func reconcile(hand: Array) -> void:
	## Free slots whose card left the hand; assign new signatures to the lowest
	## free slot in draw order. Existing signatures keep their slot.
	_ensure_size()
	var n := num_slots()

	# Signatures currently in hand, in first-appearance (draw) order. Instant
	# stacks never get a letter, so they stay out of the slot map entirely.
	var present := {}
	var order: Array = []
	for card in hand:
		var sig: String = card.get_stack_signature()
		if is_instant_sig(sig):
			continue
		if not present.has(sig):
			present[sig] = true
			order.append(sig)

	# Free any slot whose signature is no longer present.
	for i in range(n):
		if slot_sig[i] != "" and not present.has(slot_sig[i]):
			slot_sig[i] = ""

	# Which signatures already hold a slot.
	var assigned := {}
	for i in range(n):
		if slot_sig[i] != "":
			assigned[slot_sig[i]] = true

	# New signatures take the lowest free slot, in draw order.
	for sig in order:
		if assigned.has(sig):
			continue
		for i in range(n):
			if slot_sig[i] == "":
				slot_sig[i] = sig
				assigned[sig] = true
				break

func build_groups(hand: Array, locked_index: int = -1) -> Array:
	## One entry per occupied slot, ordered by slot index, with any instant
	## stacks (slot = INSTANT_SLOT, no play key) appended at the end:
	##   {slot:int, cards:Array[Card], rep:Card}
	_ensure_size()
	var by_sig := {}
	for card in hand:
		var sig: String = card.get_stack_signature()
		if not by_sig.has(sig):
			by_sig[sig] = []
		by_sig[sig].append(card)

	var groups: Array = []
	for i in range(slot_sig.size()):
		var sig: String = slot_sig[i]
		if sig == "" or not by_sig.has(sig):
			continue
		var cards: Array = by_sig[sig]
		groups.append({
			"slot": i,
			"cards": cards,
			"rep": _pick_rep(cards, hand, locked_index),
		})

	# Instant stacks render last (right end of the fan), in draw order.
	for sig in by_sig:
		if not is_instant_sig(sig):
			continue
		var cards: Array = by_sig[sig]
		groups.append({
			"slot": INSTANT_SLOT,
			"cards": cards,
			"rep": _pick_rep(cards, hand, locked_index),
		})
	return groups

func _pick_rep(cards: Array, hand: Array, locked_index: int) -> Card:
	## The card a stack's button plays: prefer a copy that can actually be
	## played (not jailed, not the Locked card).
	for c in cards:
		if c.is_jailed():
			continue
		if locked_index >= 0 and hand.find(c) == locked_index:
			continue
		return c
	return cards[0]
