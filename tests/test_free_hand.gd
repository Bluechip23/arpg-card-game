extends SceneTree

const Fixtures = preload("res://tests/item_fixtures.gd")

## The free-hand stance: exactly one hand item (weapon OR shield) with an
## empty hand. Benefits: the flash parry costs 2 instead of 3, and every 12th
## attack echoes (triggers twice). The echo never advances the attack-speed
## counter and can't itself echo; bought proc ticks don't count as attacks.
## Run: godot --headless --path . --script tests/test_free_hand.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Free-hand stance test ===")

	var data := CharacterData.create_ryan()
	var stats := PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(data)

	var inv := Inventory.new()
	get_root().add_child(inv)
	inv.initialize(data.character_name)
	inv.connect_player_stats(stats)
	stats.base_strength = 30

	# --- Stance detection ---
	_check(not inv.is_free_handing(), "empty hands are not the stance (nothing wielded)")
	inv.equip_item(Fixtures.sword(), 0)
	_check(inv.is_free_handing(), "one weapon + empty hand = free-hand stance")
	_check(stats.free_hand_stance, "inventory pushes the stance onto stats")

	inv.equip_item(Fixtures.shield(), 1)
	_check(not inv.is_free_handing(), "sword + shield fills both hands — no stance")
	_check(not stats.free_hand_stance, "stats updated when the hand fills")

	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	_check(inv.is_free_handing(), "a LONE SHIELD with a free hand is the stance too")

	# --- Parry discount ---
	_check(stats.get_flash_block_cost() == 2, "stance parry costs 2 flash (down from 3)")
	stats.refresh_flash_points()  # Ryan AGI 3
	_check(stats.spend_flash_for_block(), "parry affordable at 2")
	_check(stats.current_flash_points == 1, "3-point pool has 1 left after a 2-cost parry")

	# --- Every 12th attack echoes ---
	var echoes := 0
	for i in range(24):
		stats.register_attack()
		if stats.consume_free_hand_echo():
			echoes += 1
	_check(echoes == 2, "24 attacks in stance fire exactly 2 echoes (every 12th)")
	_check(not stats.consume_free_hand_echo(), "consuming clears the pending echo")

	# --- Echo repeats and bought ticks never feed the counter ---
	for i in range(11):
		stats.register_attack()
	stats.register_attack(false)  # an echo/bought tick registers as not-real
	_check(not stats.consume_free_hand_echo(), "non-real attacks add no echo credit")
	stats.register_attack()  # the genuine 12th
	_check(stats.consume_free_hand_echo(), "the genuine 12th attack echoes")

	# --- No stance, no echo ---
	inv.equip_item(Fixtures.sword(), 0)  # shield + sword again
	_check(not stats.free_hand_stance, "stance off with both hands full")
	_check(stats.get_flash_block_cost() == 3, "parry back to 3 without the stance")
	var stray := 0
	for i in range(24):
		stats.register_attack()
		if stats.consume_free_hand_echo():
			stray += 1
	_check(stray == 0, "no echoes without the stance")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
