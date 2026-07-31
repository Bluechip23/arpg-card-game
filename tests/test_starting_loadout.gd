extends SceneTree

## Verifies every character shares the same basic starting deck, starts at 3 in
## every core stat, and that each stat has a description.
## Run: godot --headless --path . --script tests/test_starting_loadout.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _deck_counts(character) -> Dictionary:
	var dm = DeckManager.new()
	dm.initialize_deck(character)
	var counts := {}
	# The deck is split across piles (initialize draws a starting hand), so
	# tally every pile to see the whole deck.
	for pile in [dm.draw_pile, dm.hand, dm.discard_pile, dm.jail_pile]:
		for card in pile:
			counts[card.card_id] = counts.get(card.card_id, 0) + 1
	dm.free()
	return counts

func _initialize() -> void:
	print("=== Starting loadout test ===")

	var expected := {"slash": 4, "block": 4, "draw": 1, "gain_mana": 1, "heal": 1}
	var chars := {
		"Ryan": CharacterData.create_ryan(),
		"Jeremy": CharacterData.create_jeremy(),
		"Stephen": CharacterData.create_stephen(),
		"Cory": CharacterData.create_cory(),
		"Brad": CharacterData.create_brad(),
	}

	for name in chars:
		var c = chars[name]
		var counts := _deck_counts(c)
		_check(counts == expected, "%s has the exact basic deck (4 slash / 4 block / 1 draw / 1 energy / 1 heal)" % name)
		var total := 0
		for k in counts:
			total += counts[k]
		_check(total == 11, "%s deck totals 11 cards (no character-specific extras)" % name)

		_check(c.strength == 3 and c.dexterity == 3 and c.intelligence == 3
			and c.wisdom == 3 and c.determination == 3 and c.agility == 3,
			"%s starts at 3 in every core stat" % name)

	# Every stat key has a name and description.
	for key in CharacterData.STAT_KEYS:
		_check(CharacterData.stat_description(key) != "" and CharacterData.stat_full_name(key) != "",
			"stat %s has a name and description" % key)

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
