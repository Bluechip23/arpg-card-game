extends SceneTree

const Fixtures = preload("res://tests/item_fixtures.gd")

## Verifies Brad's War Rack:
##   * Brad-only; rack items count carried weight at full (no grip discount).
##   * rack_exchange swaps hands <-> back wholesale.
##   * FREE swap: needs cooldown ready + one side a single two-handed item;
##     auto-grips the single incoming item; rushes its cards to hand; starts
##     the 25-tempo cooldown (ticking 5 per cycle via process_turn).
##   * Paid swap: works during cooldown, charges swap tempo, cards go to
##     discard per the normal equip rule.
## Run: godot --headless --path . --script tests/test_war_rack.gd

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

	# --- Setup via exchange: hammer to hands, exchange to back, then sword+shield ---
	var hammer = Fixtures.mastery_sledge()  # weight 90, grants Heavy Swing at STR 15
	var sword = Fixtures.sword()
	var shield = Fixtures.shield()
	_check(inv.equip_item(hammer, 0), "hammer equips in hand")
	var r0: Dictionary = inv.rack_exchange(false)
	_check(r0["success"], "paid exchange stows the hammer on the back")
	_check(inv.rack_items.size() == 1 and inv.get_rack_hand_items().is_empty(), "hammer on back, hands empty")
	_check(inv.get_total_weight() == 90, "racked hammer still weighs 90 (full weight)")
	_check(inv.equip_item(sword, 0) and inv.equip_item(shield, 1), "sword + shield equip in hands")

	# --- FREE swap: single incoming item -> arrives gripped two-handed ---
	var check: Dictionary = inv.can_rack_exchange(true)
	_check(check["ok"], "free swap is legal (single incoming item)")
	var r1: Dictionary = inv.rack_exchange(true)
	_check(r1["success"] and r1["tempo_cost"] == 0, "free swap costs 0 tempo")
	_check(inv.get_equipped_item(ItemData.ItemType.WEAPON, 0) == hammer, "hammer is in hand")
	_check(inv.two_handed_slot == 0, "hammer arrived gripped two-handed")
	_check(inv.rack_items.size() == 2, "sword and shield are on the back")
	_check(_in_hand("Heavy Swing"), "mastered hammer's card rushed to HAND (not discard)")
	_check(inv.rack_cooldown_tempo == Inventory.RACK_FREE_SWAP_COOLDOWN, "25-tempo cooldown started")

	# --- Free swap refused while recharging; paid swap still works ---
	_check(not inv.can_rack_exchange(true)["ok"], "second free swap refused on cooldown")
	var r2: Dictionary = inv.rack_exchange(false)
	_check(r2["success"] and r2["tempo_cost"] > 0, "paid swap works during cooldown (cost %d)" % r2["tempo_cost"])
	_check(inv.get_equipped_item(ItemData.ItemType.WEAPON, 0) == sword, "sword back in hand")
	_check(not _in_hand("Heavy Swing"), "hammer's card left the deck with the hammer")

	# --- Cooldown ticks 5 per cycle ---
	inv.process_turn()
	_check(inv.rack_cooldown_tempo == 20, "cooldown ticked to 20 after one cycle")
	for i in range(4):
		inv.process_turn()
	_check(inv.rack_cooldown_tempo == 0, "cooldown fully recharged after 5 cycles")

	# --- Free swap back: outgoing side won't qualify (2 items in hands, 1H) ---
	# hands: sword+shield (no grip), rack: hammer (single) -> incoming single, legal.
	var r3: Dictionary = inv.rack_exchange(true)
	_check(r3["success"], "free swap ready again after recharge")
	_check(inv.two_handed_slot == 0 and inv.get_equipped_item(ItemData.ItemType.WEAPON, 0) == hammer,
		"hammer two-handed again")

	# --- Outgoing-2H rule: hammer (single, gripped) in hands, 2 items on rack ---
	inv.rack_cooldown_tempo = 0
	var check2: Dictionary = inv.can_rack_exchange(true)
	_check(check2["ok"], "free swap legal via the OUTGOING two-handed side")
	var r4: Dictionary = inv.rack_exchange(true)
	_check(r4["success"] and inv.get_rack_hand_items().size() == 2, "sword+shield came down together")

	# --- Neither side qualifies: two 1H items in hands, two on rack... ---
	inv.rack_cooldown_tempo = 0
	# hands: sword+shield, rack: hammer only (1 item) -> incoming single always qualifies.
	# Stow the shield alongside the hammer to force a 2-vs-2 shape.
	var taken = inv.unequip_item(ItemData.ItemType.WEAPON, 1)
	inv.rack_store_item(taken)
	_check(inv.rack_items.size() == 2, "rack holds hammer + shield (2 items)")
	var check3: Dictionary = inv.can_rack_exchange(true)
	_check(not check3["ok"], "free swap refused: no single two-handed side")
	_check(inv.rack_exchange(false)["success"], "paid swap still allowed for that shape")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
