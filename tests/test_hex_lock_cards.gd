extends SceneTree

## Hexed and Locked belong to a CARD, not a hand slot (STATUS_EFFECTS_AUDIT
## items 30-31, designer ruled "please fix"):
##  - a hex follows its card when cards before it leave the hand by any path
##    (discard, jail, reaction, erase, hatch, a Harpy-style lift);
##  - a hexed card that leaves the hand takes its hex with it — no other card
##    inherits it;
##  - a Sticky card's re-insert does not pick up a neighbour's hex;
##  - a new hex claims a card the moment it lands when a hand exists;
##  - two locks ride a Labyrinth scramble on the same two cards;
##  - Mind Slow's hexes cover every card; the Necromancer's two hexes land on
##    two different cards (through the player's own deck, no binding needed).
## Run: godot --headless --path . --script tests/test_hex_lock_cards.gd

var failures := 0

## Stands in for the Player: the two getters the deck and debuff manager use.
class FakePlayer extends Node3D:
	var dm = null
	var deck = null
	func get_debuff_manager():
		return dm
	func get_deck_manager():
		return deck

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Hexed / Locked belong to cards ===")
	_test_assigned_at_once()
	_test_follows_its_card()
	_test_leaving_takes_the_hex()
	_test_sticky_reinsert()
	_test_labyrinth_two_locks()
	_test_mind_slow()
	_test_necromancer_two_cards()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

## A bare debuff manager bound to a fresh deck holding `n` slashes.
func _mk(n: int) -> Array:
	var dm := DebuffManager.new()
	dm.initialize()
	var deck := DeckManager.new()
	deck.connect_debuff_manager(dm)
	for _i in range(n):
		deck.hand.append(Card.create_slash())
	return [dm, deck]

func _free(pair: Array) -> void:
	pair[1].free()
	pair[0].free()

## Hexed cards in the hand, by index.
func _hexed_slots(dm: DebuffManager, deck: DeckManager) -> Array:
	var out: Array = []
	for i in range(deck.hand.size()):
		if dm.is_card_hexed(i):
			out.append(i)
	return out

## Pin the only hex onto `card`, whatever the random claim picked.
func _hex_on(dm: DebuffManager, card: Card) -> void:
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.HEXED, 30, -1))
	dm.get_hexed_debuffs()[0].affected_card = card

func _test_assigned_at_once() -> void:
	print("-- a hex claims a card the moment it lands --")
	var p := _mk(3)
	var dm: DebuffManager = p[0]
	var deck: DeckManager = p[1]
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.HEXED, 30, -1))
	var h: Debuff = dm.get_hexed_debuffs()[0]
	_check(h.affected_card != null and deck.hand.has(h.affected_card), "assigned on apply, no hand change needed")
	_check(_hexed_slots(dm, deck).size() == 1, "exactly one card reads as hexed")
	# No hand yet: the hex waits, then claims the first card that arrives.
	dm.clear_all_debuffs()
	deck.hand.clear()
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.HEXED, 30, -1))
	_check(dm.get_hexed_debuffs()[0].affected_card == null, "an empty hand leaves it waiting")
	var drawn := Card.create_slash()
	deck.add_card_to_hand(drawn)
	_check(dm.card_is_hexed(drawn), "the next card into the hand takes it")
	_free(p)

func _test_follows_its_card() -> void:
	print("-- a hex follows its card when earlier cards leave --")
	var p := _mk(8)
	var dm: DebuffManager = p[0]
	var deck: DeckManager = p[1]
	var target: Card = deck.hand[7]
	_hex_on(dm, target)

	# Discarded (Shed Weight, Venom Tail's knock-out).
	deck.discard_card_from_hand(deck.hand[0])
	_check(dm.is_card_hexed(deck.hand.find(target)) and _hexed_slots(dm, deck).size() == 1,
		"discard: the hex stays on its card (now slot %d)" % deck.hand.find(target))

	# Jailed to shed its burden.
	var heavy: Card = deck.hand[0]
	heavy.has_burden = true
	heavy.burden_plays = 1
	_check(deck.jail_burden_card(0), "a burden card jails out of slot 0")
	_check(dm.is_card_hexed(deck.hand.find(target)) and _hexed_slots(dm, deck).size() == 1,
		"jail: the hex stays on its card (slot %d)" % deck.hand.find(target))

	# A reaction fired from the hand.
	var reflex: Card = deck.hand[0]
	reflex.card_type = Card.CardType.REACTION
	_check(deck.fire_reaction(reflex), "a reaction fires out of slot 0")
	_check(dm.is_card_hexed(deck.hand.find(target)) and _hexed_slots(dm, deck).size() == 1,
		"reaction: the hex stays on its card (slot %d)" % deck.hand.find(target))

	# Erased when its in-hand fuse runs out.
	var fuse: Card = deck.hand[0]
	fuse.erase_tempo = 5
	fuse.erase_tempo_remaining = 5
	deck._process_erase_timers()
	_check(not deck.hand.has(fuse), "the erase token is gone")
	_check(dm.is_card_hexed(deck.hand.find(target)) and _hexed_slots(dm, deck).size() == 1,
		"erase: the hex stays on its card (slot %d)" % deck.hand.find(target))

	# An Infest brood hatching out of the hand.
	var brood: Card = deck.hand[0]
	brood.hatch_tempo = 5
	brood.hatch_tempo_left = 5
	deck._process_hatch_timers(5)
	_check(not deck.hand.has(brood), "the brood hatched out of the hand")
	_check(dm.is_card_hexed(deck.hand.find(target)) and _hexed_slots(dm, deck).size() == 1,
		"hatch: the hex stays on its card (slot %d)" % deck.hand.find(target))

	# Lifted straight out of the hand (the Ash Harpy's steal does exactly this).
	deck.hand.remove_at(0)
	deck.hand_updated.emit()
	_check(dm.is_card_hexed(deck.hand.find(target)) and _hexed_slots(dm, deck).size() == 1,
		"steal: the hex stays on its card (slot %d)" % deck.hand.find(target))
	_check(deck.hand.find(target) == 1, "six cards left in front of it went; it sits at slot 1")
	_check(dm.get_hexed_mana_increase(deck.hand.find(target)) == 30 and dm.get_hexed_mana_increase(0) == 0,
		"the surcharge reads on the card, not the slot it started in")
	_free(p)

func _test_leaving_takes_the_hex() -> void:
	print("-- a hexed card leaving takes its hex --")
	var p := _mk(4)
	var dm: DebuffManager = p[0]
	var deck: DeckManager = p[1]
	var hexed: Card = deck.hand[1]
	_hex_on(dm, hexed)
	deck.discard_card_from_hand(hexed)
	_check(dm.get_hexed_debuffs().is_empty(), "discarded: the hex ends with the card")
	_check(_hexed_slots(dm, deck).is_empty(), "no other card inherits it")
	# A lock goes the same way.
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.LOCKED, 0, -1))
	var locked: Card = dm.get_locked_debuffs()[0].affected_card
	deck.discard_card_from_hand(locked)
	_check(dm.get_locked_debuffs().is_empty(), "a discarded locked card takes its lock")
	for i in range(deck.hand.size()):
		_check(not dm.is_card_locked(i), "slot %d is not locked" % i)
	# Coming back later (a Harpy's death returns the stolen card) it is clean.
	deck.add_card_to_hand(hexed)
	_check(not dm.card_is_hexed(hexed), "a card that left and came back is no longer hexed")
	_free(p)

func _test_sticky_reinsert() -> void:
	print("-- a Sticky card's re-insert keeps the right card hexed --")
	var p := _mk(4)
	var dm: DebuffManager = p[0]
	var deck: DeckManager = p[1]
	var player := FakePlayer.new()
	player.dm = dm
	var sticky: Card = deck.hand[1]
	sticky.sticky = 3
	var neighbour: Card = deck.hand[2]
	_hex_on(dm, neighbour)
	var res: Dictionary = deck.play_card(1, null, player, true)
	_check(res.get("played", false), "the Sticky card plays")
	_check(deck.hand[1] == sticky, "it goes back into its slot")
	_check(dm.card_is_hexed(neighbour) and not dm.card_is_hexed(sticky),
		"the neighbour keeps its hex; the Sticky card did not pick it up")
	_check(_hexed_slots(dm, deck) == [2], "slot 2 (the neighbour) is the hexed one")
	# The Sticky card itself hexed: playing it pays the hex off even though
	# it stays in the hand.
	dm.clear_all_debuffs()
	_hex_on(dm, sticky)
	deck.play_card(1, null, player, true)
	_check(deck.hand.has(sticky) and dm.get_hexed_debuffs().is_empty(),
		"a played Sticky card's own hex is spent ('until played')")
	_check(_hexed_slots(dm, deck).is_empty(), "and no other card took it")
	player.free()
	_free(p)

func _test_labyrinth_two_locks() -> void:
	print("-- two locks ride a Labyrinth scramble --")
	var p := _mk(6)
	var dm: DebuffManager = p[0]
	var deck: DeckManager = p[1]
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.LOCKED, 0, -1))
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.LOCKED, 0, -1))
	var a: Card = dm.get_locked_debuffs()[0].affected_card
	var b: Card = dm.get_locked_debuffs()[1].affected_card
	_check(a != null and b != null and a != b, "the two locks hold two different cards")
	var ok := true
	for _i in range(10):
		deck.scramble_hand()
		var slots: Array = []
		for i in range(deck.hand.size()):
			if dm.is_card_locked(i):
				slots.append(i)
		var want: Array = [deck.hand.find(a), deck.hand.find(b)]
		want.sort()
		if slots != want:
			ok = false
	_check(ok, "after every scramble the locked slots are exactly where those two cards landed")
	_check(dm.get_locked_debuffs().size() == 2, "both locks survive")
	_free(p)

func _test_mind_slow() -> void:
	print("-- Mind Slow hexes every card --")
	var p := _mk(5)
	var dm: DebuffManager = p[0]
	var deck: DeckManager = p[1]
	# What Enemy._try_mind_slow does: one hex per card, no clock.
	for _i in range(deck.hand.size()):
		dm.apply_debuff(Debuff.create(Debuff.DebuffType.HEXED, 20, -1))
	deck.assign_hexed_locked_cards(dm)
	var all_twenty := true
	for i in range(deck.hand.size()):
		if dm.get_hexed_mana_increase(i) != 20:
			all_twenty = false
	_check(all_twenty, "every card costs exactly +20")
	_free(p)

func _test_necromancer_two_cards() -> void:
	print("-- the Necromancer's two hexes land on two cards --")
	# Through a player-shaped owner, as in the game: the debuff manager finds
	# the hand through its owner's deck, with nothing bound by hand.
	var player := FakePlayer.new()
	var dm := DebuffManager.new()
	dm.initialize(null, player)
	var deck := DeckManager.new()
	player.dm = dm
	player.deck = deck
	for _i in range(4):
		deck.hand.append(Card.create_slash())
	var distinct := true
	for _trial in range(20):
		dm.clear_all_debuffs()
		dm.apply_debuff(Debuff.create(Debuff.DebuffType.HEXED, 30, 25))
		dm.apply_debuff(Debuff.create(Debuff.DebuffType.HEXED, 30, 25))
		var hexes := dm.get_hexed_debuffs()
		if hexes[0].affected_card == null or hexes[1].affected_card == null \
				or hexes[0].affected_card == hexes[1].affected_card:
			distinct = false
	_check(distinct, "20 bolts: both hexes claimed at once, always on two different cards")
	deck.free()
	dm.free()
	player.free()
