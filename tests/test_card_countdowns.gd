extends SceneTree

## The designer's rule for negative card effects: "keep the countdown ticker
## going if the card is discarded unless otherwise specified. If the card is
## jailed, the ticker is frozen."
##  - a hex stays on its card in the discard and draw piles, its 25-tempo
##    clock keeps falling there, and it is still hexed back in the hand;
##  - a hex that runs out in the discard pile is gone;
##  - a jailed hexed card's clock freezes and resumes on release;
##  - playing the card still clears it ("until played");
##  - a Mind Slow hex (no clock) rides a discarded card back to the hand;
##  - a new hex only ever claims a card in hand;
##  - Lightly Dazed / Minor Wounds burn their Erase fuse in the discard and
##    draw piles and freeze in jail; a player's own Erase card still only
##    burns in the hand;
##  - Infest keeps its stated rule: discarded, it is erased and never hatches.
## Run: godot --headless --path . --script tests/test_card_countdowns.gd

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
	print("=== Negative card countdowns keep running (frozen in jail) ===")
	_test_hex_runs_in_discard()
	_test_hex_expires_in_discard()
	_test_hex_freezes_in_jail()
	_test_lock_rides_and_freezes()
	_test_playing_clears()
	_test_mind_slow_rides_back()
	_test_new_hex_claims_hand_only()
	_test_lightly_dazed_fuse()
	_test_minor_wounds_draw_pile()
	_test_positive_erase_hand_only()
	_test_infest_discard()
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

## The Necromancer's hex (+30 mana, 25 tempo), pinned onto `card`.
func _hex_on(dm: DebuffManager, card: Card, dur: int = 25) -> Debuff:
	var hex := Debuff.create(Debuff.DebuffType.HEXED, 30, dur)
	dm.apply_debuff(hex)
	hex.affected_card = card
	return hex

func _test_hex_runs_in_discard() -> void:
	print("-- a discarded hexed card keeps its hex and the clock keeps falling --")
	var p := _mk(4)
	var dm: DebuffManager = p[0]
	var deck: DeckManager = p[1]
	var card: Card = deck.hand[2]
	var hex := _hex_on(dm, card)
	deck.discard_card_from_hand(card)
	_check(deck.discard_pile.has(card) and dm.card_is_hexed(card), "the hex rides its card into the discard pile")
	dm.advance_time(10)
	_check(hex.duration == 15, "the 25-tempo clock kept falling in the discard pile (15 left, got %d)" % hex.duration)
	# Shuffled into the draw pile and drawn back before it runs out.
	deck.shuffle_discard_into_draw()
	_check(deck.draw_pile.has(card) and dm.card_is_hexed(card), "reshuffled into the draw pile: still hexed")
	dm.advance_time(5)
	_check(hex.duration == 10, "the clock keeps falling in the draw pile (10 left, got %d)" % hex.duration)
	deck.draw_pile.erase(card)
	deck.draw_pile.append(card)  # on top
	var drawn := deck.draw_card()
	_check(drawn == card, "the hexed card is drawn back")
	var i := deck.hand.find(card)
	_check(dm.is_card_hexed(i) and dm.get_hexed_mana_increase(i) == 30, "back in hand it is still hexed (+30) at slot %d" % i)
	_check(dm.get_hexed_debuffs().size() == 1, "no other card picked up a hex on the way")
	_free(p)

func _test_hex_expires_in_discard() -> void:
	print("-- a hex that runs out in the discard pile is gone --")
	var p := _mk(3)
	var dm: DebuffManager = p[0]
	var deck: DeckManager = p[1]
	var card: Card = deck.hand[0]
	_hex_on(dm, card)
	deck.discard_card_from_hand(card)
	dm.advance_time(25)
	_check(dm.get_hexed_debuffs().is_empty(), "expired in the discard pile")
	deck.add_card_to_hand(card)
	_check(not dm.card_is_hexed(card), "back in hand it is clean")
	_free(p)

func _test_hex_freezes_in_jail() -> void:
	print("-- a jailed hexed card's clock freezes, and resumes on release --")
	var p := _mk(3)
	var dm: DebuffManager = p[0]
	var deck: DeckManager = p[1]
	var card: Card = deck.hand[1]
	card.has_burden = true
	card.burden_plays = 1
	var hex := _hex_on(dm, card)
	dm.advance_time(5)
	_check(hex.duration == 20, "ticking in hand (20 left)")
	_check(deck.jail_burden_card(1), "jailed to shed its burden")
	_check(deck.jail_pile.has(card) and dm.card_is_hexed(card), "the hex stays on its card in jail")
	dm.advance_time(15)
	_check(hex.duration == 20, "frozen in jail (still 20, got %d)" % hex.duration)
	deck.release_jailed_to_hand()
	_check(deck.hand.has(card) and dm.is_card_hexed(deck.hand.find(card)), "released to the hand, still hexed")
	dm.advance_time(5)
	_check(hex.duration == 15, "the clock resumes on release (15 left, got %d)" % hex.duration)
	# Released the slow way — jail time out, into the discard pile — it ticks there too.
	card.burden_plays = 1
	_check(deck.jail_burden_card(deck.hand.find(card)), "jailed again")
	dm.advance_time(10)
	_check(hex.duration == 15, "frozen again (15)")
	card.jail_time_remaining = 5
	deck.process_turn()
	_check(deck.discard_pile.has(card) and dm.card_is_hexed(card), "jail time served: into the discard pile, still hexed")
	dm.advance_time(5)
	_check(hex.duration == 10, "ticking again in the discard pile (10 left, got %d)" % hex.duration)
	_free(p)

func _test_lock_rides_and_freezes() -> void:
	print("-- a timed lock rides its card the same way --")
	var p := _mk(3)
	var dm: DebuffManager = p[0]
	var deck: DeckManager = p[1]
	var lock := Debuff.create(Debuff.DebuffType.LOCKED, 0, 20)
	dm.apply_debuff(lock)
	var card: Card = lock.affected_card
	deck.discard_card_from_hand(card)
	_check(dm.card_is_locked(card), "a discarded locked card keeps its lock")
	dm.advance_time(5)
	_check(lock.duration == 15, "its clock runs in the discard pile (15 left)")
	deck.discard_pile.erase(card)
	card.jail_time_remaining = 30
	deck.jail_pile.append(card)
	dm.advance_time(10)
	_check(lock.duration == 15, "frozen in jail")
	deck.jail_pile.erase(card)
	deck.add_card_to_hand(card)
	_check(dm.is_card_locked(deck.hand.find(card)) and dm.get_locked_card_index() == deck.hand.find(card),
		"back in hand it is still locked")
	_free(p)

func _test_playing_clears() -> void:
	print("-- playing the card still clears it --")
	var p := _mk(3)
	var dm: DebuffManager = p[0]
	var deck: DeckManager = p[1]
	var player := FakePlayer.new()
	player.dm = dm
	var card: Card = deck.hand[0]
	_hex_on(dm, card)
	deck.discard_card_from_hand(card)
	deck.add_card_to_hand(card)
	_check(dm.card_is_hexed(card), "hexed after the round trip through the discard pile")
	var res: Dictionary = deck.play_card(deck.hand.find(card), null, player, true)
	_check(res.get("played", false), "the card plays")
	_check(dm.get_hexed_debuffs().is_empty(), "the hex is paid and gone ('until played')")
	player.free()
	_free(p)

func _test_mind_slow_rides_back() -> void:
	print("-- a Mind Slow hex stays on its discarded card until played --")
	var p := _mk(3)
	var dm: DebuffManager = p[0]
	var deck: DeckManager = p[1]
	for _i in range(deck.hand.size()):
		dm.apply_debuff(Debuff.create(Debuff.DebuffType.HEXED, 20, -1))
	deck.assign_hexed_locked_cards(dm)
	var card: Card = deck.hand[1]
	deck.discard_card_from_hand(card)
	dm.advance_time(200)
	_check(dm.card_is_hexed(card) and dm.get_hexed_debuffs().size() == 3, "no clock: still on the card after 200 tempo")
	deck.discard_pile.erase(card)
	deck.add_card_to_hand(card)
	_check(dm.get_hexed_mana_increase(deck.hand.find(card)) == 20, "back in hand it still costs +20")
	var all_twenty := true
	for i in range(deck.hand.size()):
		if dm.get_hexed_mana_increase(i) != 20:
			all_twenty = false
	_check(all_twenty and deck.hand.size() == 3, "every card still costs exactly +20 — nothing stacked twice")
	_free(p)

func _test_new_hex_claims_hand_only() -> void:
	print("-- a new hex claims only a card in hand --")
	var p := _mk(2)
	var dm: DebuffManager = p[0]
	var deck: DeckManager = p[1]
	var a: Card = deck.hand[0]
	var b: Card = deck.hand[1]
	deck.discard_card_from_hand(a)
	deck.discard_card_from_hand(b)
	var hex := Debuff.create(Debuff.DebuffType.HEXED, 30, 25)
	dm.apply_debuff(hex)
	_check(hex.affected_card == null, "the hand is empty: the hex waits rather than taking a discarded card")
	var fresh := Card.create_slash()
	deck.add_card_to_hand(fresh)
	_check(hex.affected_card == fresh, "the next card into the hand takes it")
	_free(p)

func _test_lightly_dazed_fuse() -> void:
	print("-- Lightly Dazed burns its Erase fuse in the discard pile, frozen in jail --")
	var p := _mk(1)
	var dm: DebuffManager = p[0]
	var deck: DeckManager = p[1]
	var dazed := Card.create_lightly_dazed()
	_check(dazed.is_negative_card(), "Lightly Dazed is a negative card")
	deck.add_card_to_hand(dazed)
	deck._process_erase_timers()
	_check(dazed.erase_tempo_remaining == 35, "ticks in hand (35)")
	deck.discard_card_from_hand(dazed)
	deck._process_erase_timers()
	_check(dazed.erase_tempo_remaining == 30, "keeps ticking in the discard pile (30, got %d)" % dazed.erase_tempo_remaining)
	deck.discard_pile.erase(dazed)
	dazed.jail_time_remaining = 50
	deck.jail_pile.append(dazed)
	for _i in range(5):
		deck._process_erase_timers()
	_check(dazed.erase_tempo_remaining == 30, "frozen in jail (still 30)")
	deck.jail_pile.erase(dazed)
	dazed.jail_time_remaining = 0
	deck.discard_pile.append(dazed)
	for _i in range(5):
		deck._process_erase_timers()
	_check(dazed.erase_tempo_remaining == 5 and deck.discard_pile.has(dazed), "resumes on release (5 left)")
	var erased: Array = []
	deck.card_erased.connect(func(c): erased.append(c))
	deck._process_erase_timers()
	_check(not deck.discard_pile.has(dazed) and erased.has(dazed), "the fuse runs out in the discard pile: erased from the deck")
	_check(not deck.holds_card(dazed), "gone from every pile")
	_free(p)

func _test_minor_wounds_draw_pile() -> void:
	print("-- Minor Wounds burns its fuse in the draw pile, and a scried one takes its reveal --")
	var p := _mk(0)
	var deck: DeckManager = p[1]
	var under := Card.create_slash()
	var wound := Card.create_minor_wounds()
	_check(wound.is_negative_card(), "Minor Wounds is a negative card")
	deck.draw_pile.append(under)
	deck.draw_pile.append(wound)  # on top
	deck.brain_peek_depth = 2
	for _i in range(7):
		deck._process_erase_timers()
	_check(wound.erase_tempo_remaining == 5 and deck.draw_pile.has(wound), "ticks in the draw pile (5 left)")
	deck._process_erase_timers()
	_check(not deck.draw_pile.has(wound), "erased from the draw pile")
	_check(deck.brain_peek_depth == 1 and deck.get_brain_peeked_cards() == [under],
		"the scried wound took its reveal; the card beneath stays revealed")
	_free(p)

func _test_positive_erase_hand_only() -> void:
	print("-- a player's own Erase card keeps the hand-only fuse --")
	var p := _mk(0)
	var deck: DeckManager = p[1]
	var copy := Card.create_by_id("savage_strike_copy")
	_check(copy != null and not copy.is_negative_card(), "the Savage Strike copy is not a negative card")
	deck.discard_pile.append(copy)
	deck.draw_pile.append(Card.create_by_id("prepare"))
	deck._process_erase_timers()
	_check(copy.erase_tempo_remaining == 20, "its fuse pauses in the discard pile (20)")
	_check(deck.draw_pile.size() == 1 and deck.draw_pile[0].erase_tempo_remaining == 1, "Prepare's fuse pauses in the draw pile")
	deck.discard_pile.erase(copy)
	deck.hand.append(copy)
	deck._process_erase_timers()
	_check(copy.erase_tempo_remaining == 15, "and burns in the hand (15)")
	_free(p)

func _test_infest_discard() -> void:
	print("-- Infest discarded is erased and never hatches (its stated rule) --")
	var p := _mk(1)
	var deck: DeckManager = p[1]
	var infest := Card.create_infest()
	var hatched := [false]
	infest.hatch_handler = func(): hatched[0] = true
	_check(infest.is_negative_card(), "Infest is a negative card")
	deck.add_card_to_hand(infest)
	deck._process_hatch_timers(2)
	_check(infest.hatch_tempo_left == 3, "the fuse runs in hand (3 left)")
	_check(deck.discard_card_from_hand(infest), "discarded")
	_check(not deck.holds_card(infest), "erased, not banked in the discard pile")
	deck._process_hatch_timers(10)
	deck._process_erase_timers()
	_check(not hatched[0], "it never hatches")
	_free(p)
