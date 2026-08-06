extends SceneTree

## Verifies weapon mastery breakpoints:
##   * A breakpoint is a reward, not a requirement — anyone can equip the weapon.
##   * Mastery cards enter the deck only when the wielder's BASE stat meets the
##     threshold, ride the owned-cards plumbing (removed on unequip), and are
##     released retroactively when a stat allocation crosses the breakpoint.
##   * Effective-stat swings (Determination) do NOT flicker mastery.
## Run: godot --headless --path . --script tests/test_weapon_mastery.gd

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

func _card_in_deck(card_name: String) -> bool:
	for pile in [deck.draw_pile, deck.hand, deck.discard_pile, deck.jail_pile]:
		for card in pile:
			if card.card_name == card_name:
				return true
	return false

func _initialize() -> void:
	print("=== Weapon mastery breakpoint test ===")
	var data = CharacterData.create_brad()
	stats = PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(data)
	stats.base_strength = 12  # below the sledge's STR 15 breakpoint, capacity 170

	inv = Inventory.new()
	get_root().add_child(inv)
	inv.initialize(data.character_name)
	inv.connect_player_stats(stats)
	deck = DeckManager.new()
	get_root().add_child(deck)
	inv.connect_deck_manager(deck)

	var sledge = ItemData.create_earthsplitter_sledge()
	_check(sledge.has_mastery(), "sledge carries a mastery breakpoint")
	_check(sledge.get_mastery_stat_label() == "STR 15", "breakpoint label reads STR 15")
	_check(not sledge.is_mastered_by(stats), "STR 12 does not master the sledge")

	# --- Breakpoint is not a requirement: the weapon equips fine unmastered ---
	_check(inv.equip_item(sledge, 0), "unmastered wielder still equips the sledge")
	_check(not _card_in_deck("Heavy Swing"), "mastery card held back below the breakpoint")

	# --- Crossing the breakpoint releases the card (allocation-style growth) ---
	stats.base_strength = 15
	stats.stats_updated.emit()
	_check(sledge.is_mastered_by(stats), "STR 15 masters the sledge")
	_check(_card_in_deck("Heavy Swing"), "mastery card released when the breakpoint is crossed")

	# --- Unequip pulls the mastery card out of every zone ---
	_check(inv.unequip_item(ItemData.ItemType.WEAPON, 0) != null, "sledge unequips")
	_check(not _card_in_deck("Heavy Swing"), "mastery card leaves the deck with the weapon")

	# --- Re-equip while mastered: card comes straight in ---
	_check(inv.equip_item(sledge, 0), "sledge re-equips")
	_check(_card_in_deck("Heavy Swing"), "mastery card returns with the mastered weapon")
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)

	# --- Determination swings do NOT flicker mastery (base stat only) ---
	var fang = ItemData.create_serpent_fang()
	stats.base_dexterity = 14  # one short of DEX 15
	stats.determination = 65
	stats.current_health = maxi(1, int(stats.max_health * 0.1))  # effective DEX x1.5
	_check(stats.dexterity >= 15, "effective DEX is over the threshold (sanity)")
	_check(not fang.is_mastered_by(stats), "mastery ignores the Determination swing — base DEX 14 stays locked")
	stats.current_health = stats.max_health

	# --- Tooltip text ---
	_check(fang.get_mastery_text().begins_with("Mastery (DEX 15)"), "mastery tooltip line renders")
	_check(fang.get_mastery_text(stats).ends_with("locked"), "tooltip shows locked below the breakpoint")
	stats.base_dexterity = 15
	_check(fang.get_mastery_text(stats).ends_with("UNLOCKED"), "tooltip shows UNLOCKED at the breakpoint")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
