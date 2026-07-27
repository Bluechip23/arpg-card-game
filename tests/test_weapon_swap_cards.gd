extends SceneTree

## Smoke test for weapon/equipment-swap card mechanics:
##   * an item's cards (granted + slotted) enter the DISCARD pile when equipped
##   * they are pulled from EVERY zone (draw/hand/discard/jail/manifest) when
##     the item is unequipped
##   * a jailed card keeps its jail time across a swap-out/swap-in round trip
##   * cards merely PRODUCED during play detach and are never removed by a swap
## Run: godot --headless --path . --script tests/test_weapon_swap_cards.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _make_weapon(name: String, card_slots: int = 0) -> ItemData:
	var w := ItemData.new()
	w.item_name = name
	w.item_type = ItemData.ItemType.WEAPON
	w.weapon_subtype = ItemData.WeaponSubtype.SWORD
	w.weight = 5
	w.card_slots = card_slots
	return w

func _initialize() -> void:
	print("=== Weapon-swap card mechanics smoke test ===")

	var data := CharacterData.create_brad()
	var stats := PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(data)

	var inv := Inventory.new()
	get_root().add_child(inv)
	inv.initialize(data.character_name)
	inv.connect_player_stats(stats)

	var deck := DeckManager.new()
	get_root().add_child(deck)
	deck.connect_player_stats(stats)
	deck.connect_inventory(inv)
	inv.connect_deck_manager(deck)

	# --- 1) Granted cards land in DISCARD when the item is equipped ---
	var blade := _make_weapon("Test Blade")
	blade.special_effect = ItemData.SpecialEffect.GRANT_CARDS
	blade.granted_card_ids.assign(["dagger_throw"])

	_check(inv.equip_item(blade, 0), "granted-card blade equips in slot 0")
	_check(deck.discard_pile.size() == 1, "granted card went to the discard pile (not draw)")
	_check(deck.draw_pile.size() == 0, "nothing was shuffled into the draw pile")
	var granted_card: Card = blade.granted_card_instances[0]
	_check(deck.discard_pile.has(granted_card), "the discarded card is the item's granted instance")

	# --- 2) Removed item pulls its cards from EVERY zone (here: hand) ---
	# Move the granted card into hand to prove removal isn't discard-only.
	deck.discard_pile.erase(granted_card)
	deck.hand.append(granted_card)
	_check(inv.unequip_item(ItemData.ItemType.WEAPON, 0) == blade, "blade unequips")
	_check(not deck.hand.has(granted_card), "granted card pulled from hand on unequip")
	_check(not deck.discard_pile.has(granted_card), "granted card gone from discard on unequip")
	_check(blade.granted_card_instances.has(granted_card), "instance is kept on the item for re-equip")

	# --- Re-equip: the SAME instance comes back to discard ---
	_check(inv.equip_item(blade, 0), "blade re-equips")
	_check(deck.discard_pile.has(granted_card), "same granted instance returns to discard")
	_check(deck.discard_pile.size() == 1, "no duplicate granted card was created")

	# --- 3) A jailed slotted card survives a swap round trip ---
	var sword := _make_weapon("Test Sword", 1)
	var jailed_card := Card.create_slash()
	_check(sword.slot_card(jailed_card), "slash slots into the sword")
	_check(inv.equip_item(sword, 1), "sword equips in slot 1")
	_check(deck.discard_pile.has(jailed_card), "slotted card entered discard on equip")

	# Simulate the card being jailed during play.
	deck.discard_pile.erase(jailed_card)
	jailed_card.jail(15)
	deck.jail_pile.append(jailed_card)
	_check(deck.jail_pile.has(jailed_card) and jailed_card.jail_time_remaining == 15,
		"card is jailed for 15 tempo")

	# Swap the sword out (e.g. switching to another build)...
	inv.unequip_item(ItemData.ItemType.WEAPON, 1)
	_check(not deck.jail_pile.has(jailed_card), "jailed card leaves the jail pile on swap-out")
	_check(jailed_card.jail_time_remaining == 15, "jail time is frozen on the detached instance")

	# ...and swap it back in.
	_check(inv.equip_item(sword, 1), "sword swaps back in")
	_check(deck.jail_pile.has(jailed_card), "jailed card returns to the JAIL pile, not discard")
	_check(not deck.discard_pile.has(jailed_card), "jailed card did not slip into discard")
	_check(jailed_card.jail_time_remaining == 15, "same jail time remains after swapping back")

	# --- 4) A produced card detaches: an unrelated swap never removes it ---
	var produced := Card.create_heal()  # neither granted nor slotted -> owns itself
	deck.discard_pile.append(produced)
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)  # remove the blade
	_check(deck.discard_pile.has(produced), "produced card stays put when another item is removed")

	print("=== Done: %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
