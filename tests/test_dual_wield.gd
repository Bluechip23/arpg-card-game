extends SceneTree

## Verifies dual wielding: auto-detected matched pair (two weapons or two
## shields) in the hand slots. Both items weigh 1.35x; the attack-speed
## counter drops by 4. Weapon+shield stays neutral, the carry gate prices the
## surcharge on BOTH hands, and releasing the pair restores the weights.
## Run: godot --headless --path . --script tests/test_dual_wield.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _sword(weight: int, name: String) -> ItemData:
	var s = ItemData.new()
	s.item_name = name
	s.item_type = ItemData.ItemType.WEAPON
	s.weight = weight
	s.weapon_damage = 5
	return s

func _shield(weight: int, name: String) -> ItemData:
	var s = _sword(weight, name)
	s.weapon_subtype = ItemData.WeaponSubtype.SHIELD
	return s

func _initialize() -> void:
	print("=== Dual wielding test ===")

	var stats = PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(CharacterData.create_ryan())  # all stats 3
	var inv = Inventory.new()
	get_root().add_child(inv)
	inv.initialize("Ryan")
	inv.connect_player_stats(stats)

	# --- Carry gate prices the 1.35x surcharge on BOTH hands ---
	stats.base_strength = 10  # capacity 150
	var a := _sword(60, "Left Fang")
	var b := _sword(60, "Right Fang")
	_check(inv.equip_item(a, 0), "first sword equips alone (weight 60)")
	_check(not inv.is_dual_wielding(), "one weapon is not dual wielding")
	_check(inv.get_total_weight() == 60, "single sword carries at full weight")
	# Pair would weigh floori(60*1.35) x2 = 162 > 150 capacity.
	_check(not inv.equip_item(b, 1), "second sword refused: the pair would overload (162 > 150)")

	stats.base_strength = 20  # capacity 250 — now the pair fits
	_check(inv.equip_item(b, 1), "second sword equips with capacity for the pair")
	_check(inv.is_dual_wielding(), "two weapons = dual wielding")
	_check(inv.get_total_weight() == 162, "both swords weigh 1.35x (81 + 81)")

	# --- Counter bonus: -4, on top of DEX and encumbrance ---
	var expected: int = stats.base_attack_speed_counter \
			- floori(stats.dexterity * PlayerStats.DEX_COUNTER_PER_POINT) \
			+ stats.get_capacity_speed_modifier() - PlayerStats.DUAL_WIELD_COUNTER_BONUS
	_check(stats.get_attack_speed_threshold() == max(PlayerStats.ATTACK_COUNTER_MIN, expected),
		"dual wielding shaves %d off the counter (got %d)" % [
			PlayerStats.DUAL_WIELD_COUNTER_BONUS, stats.get_attack_speed_threshold()])

	# --- Unequipping one hand ends the pair and restores weights ---
	inv.unequip_item(ItemData.ItemType.WEAPON, 1)
	_check(not inv.is_dual_wielding(), "losing the off-hand ends dual wielding")
	_check(inv.get_total_weight() == 60, "remaining sword drops back to full weight")

	# --- Weapon + shield is the neutral classic, not a pair ---
	var board := _shield(40, "Oak Board")
	_check(inv.equip_item(board, 1), "shield equips beside the sword")
	_check(not inv.is_dual_wielding(), "sword-and-board is NOT dual wielding")
	_check(inv.get_total_weight() == 100, "sword + shield carry at full weight (60 + 40)")

	# --- Two shields ARE a pair ---
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	var board2 := _shield(40, "Pine Board")
	_check(inv.equip_item(board2, 0), "second shield equips")
	_check(inv.is_dual_wielding(), "two shields = dual wielding")
	_check(inv.get_total_weight() == 108, "both shields weigh 1.35x (54 + 54)")

	# --- A two-handed grip can never coexist with a pair ---
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	_check(inv.set_two_handed(1, true), "lone shield braces two-handed")
	_check(not inv.is_dual_wielding(), "a two-handed grip is not dual wielding")
	_check(not inv.equip_item(board2, 0), "the grip-locked hand refuses a second shield")

	stats.free()
	inv.free()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
