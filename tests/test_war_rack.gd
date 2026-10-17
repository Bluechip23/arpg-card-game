extends SceneTree
## Brad's War Rack — a slot of its own holding ONE weapon, always held
## two-handed:
##   * Brad-only; one weapon; no shields; the racked weapon counts its full
##     weight.
##   * rack_deploy (free): hand gear set aside, the weapon in hand two-handed,
##     its cards rushed to HAND, a 20-tempo return clock and a 60-tempo
##     cooldown (both on raw tempo).
##   * The grip cannot be released while it is out; build switches wait.
##   * After 20 tempo (or early, by choice) the weapon goes back up and the
##     usual gear returns — its cards to the DISCARD pile, not the hand.
## Run: godot --headless --path . --script tests/test_war_rack.gd
const Fixtures = preload("res://tests/item_fixtures.gd")

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

var stats: PlayerStats
var inv: Inventory
var deck: DeckManager

func _in_hand(card_name: String) -> bool:
	for card in deck.hand:
		if card.card_name == card_name:
			return true
	return false

func _in_discard(card_name: String) -> bool:
	for card in deck.discard_pile:
		if card.card_name == card_name:
			return true
	return false

func _initialize() -> void:
	print("=== War Rack test ===")
	var data = CharacterData.create_brad()
	stats = PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(data)
	stats.base_strength = 20  # capacity 250 — room for the whole arsenal

	inv = Inventory.new()
	get_root().add_child(inv)
	inv.initialize(data.character_name)
	inv.connect_player_stats(stats)
	deck = DeckManager.new()
	get_root().add_child(deck)
	inv.connect_deck_manager(deck)

	_check(inv.has_back_rack, "Brad has the war rack")
	var other = Inventory.new()
	get_root().add_child(other)
	other.initialize("Ryan")
	_check(not other.has_back_rack, "Ryan does not")
	_check(Inventory.RACK_COOLDOWN == 60 and Inventory.RACK_DEPLOY_TEMPO == 20, "60 tempo between draws, 20 tempo out")

	# --- The slot: one weapon, no shields ---
	var hammer = Fixtures.mastery_sledge()  # weight 90, grants Heavy Swing
	var sword = Fixtures.sword()
	var shield = Fixtures.shield()
	_check(not inv.rack_store_item(shield) and inv.last_refusal.find("shield") >= 0, "a shield is refused: %s" % inv.last_refusal)
	_check(inv.rack_store_item(hammer) and inv.rack_weapon() == hammer, "the hammer straps on")
	_check(inv.is_war_rack_item(hammer), "and belongs to the rack's slot")
	_check(not inv.rack_store_item(Fixtures.sword()) and inv.last_refusal.find("one weapon") >= 0, "a second weapon is refused: %s" % inv.last_refusal)
	_check(inv.get_total_weight() == 90, "racked hammer weighs its full 90")
	_check(inv.equip_item(sword, 0) and inv.equip_item(shield, 1), "sword + shield in the hands as usual")
	var weight_before: int = inv.get_total_weight()

	# --- Draw: free, two-handed, cards to hand, clocks started ---
	_check(inv.can_rack_deploy()["ok"], "the rack can be drawn")
	var r1: Dictionary = inv.rack_deploy()
	_check(r1["success"] and r1["tempo_cost"] == 0, "drawing it costs nothing")
	_check(inv.get_equipped_item(ItemData.ItemType.WEAPON, 0) == hammer and inv.two_handed_slot == 0, "the hammer is in hand, two-handed")
	_check(inv.get_rack_hand_items() == [hammer], "nothing else is in the hands")
	_check(inv.rack_items.is_empty() and inv.rack_is_deployed() and inv.rack_deploy_tempo == 20, "the rack is out for 20 tempo")
	_check(inv.rack_cooldown_tempo == 60, "the 60-tempo cooldown started")
	_check(inv.rack_parked.has(sword) and inv.rack_parked.has(shield), "the sword and shield are set aside")
	_check(_in_hand("Heavy Swing"), "the hammer's granted card rushed to HAND")
	_check(inv.get_total_weight() >= sword.weight + shield.weight + floori(hammer.weight * Inventory.TWO_HAND_WEIGHT_MULT),
		"the set-aside gear still weighs on him (%d, was %d)" % [inv.get_total_weight(), weight_before])
	_check(not inv.set_two_handed(0, false) and inv.two_handed_slot == 0, "the grip cannot be released: %s" % inv.last_refusal)
	_check(not inv.can_rack_deploy()["ok"], "it cannot be drawn again while out")
	var sw: Dictionary = inv.switch_build(1)
	_check(not sw["success"] and sw["reason"].find("War Rack") >= 0, "a build switch waits for it: %s" % sw["reason"])

	# --- The clock: 19 tempo later still out; the 20th brings the gear back ---
	inv.advance_rack_tempo(19)
	_check(inv.rack_is_deployed() and inv.rack_deploy_tempo == 1 and inv.rack_cooldown_tempo == 41, "19 tempo in: 1 left out, 41 to recharge")
	inv.advance_rack_tempo(1)
	_check(not inv.rack_is_deployed() and inv.rack_weapon() == hammer, "at 20 the hammer is back on the rack")
	_check(inv.get_equipped_item(ItemData.ItemType.WEAPON, 0) == sword and inv.get_equipped_item(ItemData.ItemType.WEAPON, 1) == shield
		and inv.two_handed_slot == -1, "the sword and shield are back in hand, held as before")
	_check(not _in_hand("Heavy Swing") and not _in_discard("Heavy Swing"), "the hammer's card left with it")
	_check(inv.rack_parked.is_empty() and inv.rack_cooldown_tempo == 40, "nothing set aside; 40 tempo to recharge")
	_check(not inv.can_rack_deploy()["ok"] and inv.can_rack_deploy()["reason"].find("recharging") >= 0, "cannot be drawn while recharging")
	inv.advance_rack_tempo(40)
	_check(inv.rack_cooldown_tempo == 0 and inv.can_rack_deploy()["ok"], "60 tempo after the draw it is ready again")

	# --- Returning gear's cards go to the deck, not the hand ---
	var bow = Fixtures.bow(50)
	bow.card_slots = 1
	var shot = deck._create_card_from_id("quick_shot")
	_check(bow.slot_card(shot), "Quick Shot engraved into a bow")
	inv.unequip_item(ItemData.ItemType.WEAPON, 1)
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	_check(inv.equip_item(bow, 0), "the bow is now his usual weapon")
	deck.hand.clear()
	deck.discard_pile.clear()
	deck.draw_pile.clear()
	_check(inv.rack_deploy()["success"] and inv.rack_parked.has(bow), "drawn again: the bow is set aside")
	_check(not deck.hand.has(shot) and not deck.discard_pile.has(shot), "the bow's card left play with it")
	var early: Dictionary = inv.rack_return()
	_check(early["success"] and inv.get_equipped_item(ItemData.ItemType.WEAPON, 0) == bow and inv.rack_weapon() == hammer,
		"an early return brings the bow back and racks the hammer")
	_check(deck.discard_pile.has(shot) and not deck.hand.has(shot), "the bow's card rejoined the DECK (discard), not the hand")
	_check(inv.rack_cooldown_tempo == 60, "an early return does not shorten the cooldown")

	# --- A bow on the rack: two-handed by nature, no grip stance ---
	inv.rack_take_item(0)
	_check(not inv.is_war_rack_item(hammer), "taken down, the hammer is an ordinary weapon again")
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	var bow2 = Fixtures.bow(50)
	_check(inv.rack_store_item(bow2), "a bow straps on")
	_check(inv.equip_item(sword, 0), "sword in hand")
	inv.rack_cooldown_tempo = 0
	_check(inv.rack_deploy()["success"] and inv.get_equipped_item(ItemData.ItemType.WEAPON, 0) == bow2 and inv.two_handed_slot == -1,
		"the bow comes down (two-handed by nature, no bonus stance)")
	inv.advance_rack_tempo(20)
	_check(inv.get_equipped_item(ItemData.ItemType.WEAPON, 0) == sword and inv.rack_weapon() == bow2, "and goes back up after 20")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
