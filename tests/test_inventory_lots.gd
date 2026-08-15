extends SceneTree

const Fixtures = preload("res://tests/item_fixtures.gd")

## Smoke test for the universal inventory-lot baseline and its per-character
## deviations, plus Jeremy's every-3rd-cycle ring double trigger.
## Baseline: 1 helm, 2 rings, 1 belt, 1 chest, 1 main hand, 1 off hand,
## 1 pair of boots, 1 gauntlet.
## Run: godot --headless --path . --script tests/test_inventory_lots.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Inventory lots smoke test ===")

	# Expected slot counts: baseline everywhere, one deviation per character.
	var expected := {
		"Ryan":    {"helm": 1, "ring": 2, "belt": 2, "chest": 1, "weapon": 2, "boots": 1, "gauntlets": 1},
		"Brad":    {"helm": 1, "ring": 2, "belt": 1, "chest": 1, "weapon": 2, "boots": 1, "gauntlets": 1},
		"Jeremy":  {"helm": 1, "ring": 3, "belt": 1, "chest": 1, "weapon": 2, "boots": 1, "gauntlets": 1},
		"Stephen": {"helm": 1, "ring": 2, "belt": 1, "chest": 1, "weapon": 2, "boots": 1, "gauntlets": 1},
		"Cory":    {"helm": 1, "ring": 2, "belt": 1, "chest": 1, "weapon": 2, "boots": 1, "gauntlets": 2},
	}

	var inv := Inventory.new()
	get_root().add_child(inv)

	for who in expected:
		inv.initialize(who)
		var e: Dictionary = expected[who]
		_check(inv.helm_slots == e["helm"], "%s: %d helm slot(s)" % [who, e["helm"]])
		_check(inv.ring_slots == e["ring"], "%s: %d ring slot(s)" % [who, e["ring"]])
		_check(inv.belt_slots == e["belt"], "%s: %d belt slot(s)" % [who, e["belt"]])
		_check(inv.chest_slots == e["chest"], "%s: %d chest slot(s)" % [who, e["chest"]])
		_check(inv.weapon_slots == e["weapon"], "%s: %d hand slot(s)" % [who, e["weapon"]])
		_check(inv.boots_slots == e["boots"], "%s: %d boots slot(s)" % [who, e["boots"]])
		_check(inv.gauntlets_slots == e["gauntlets"], "%s: %d gauntlet slot(s)" % [who, e["gauntlets"]])

	# --- Passive modifiers land on the right characters ---
	inv.initialize("Ryan")
	_check(inv.belt_card_mana_reduction == 10, "Ryan: belt cards cost 10 less mana (post mana rescale)")
	inv.initialize("Brad")
	_check(inv.has_back_rack, "Brad: carries the War Rack (baseline hand slots)")
	inv.initialize("Brad")
	_check(is_equal_approx(inv.chest_weight_reduction, 0.20), "Brad: chest items weigh 20% less")
	_check(is_equal_approx(inv.get_off_hand_modifier(), 0.9), "Brad: off-hand items take the -10% penalty")
	inv.initialize("Cory")
	_check(inv.gauntlet_cooldown_mana, "Cory: mana refund on gauntlet cooldown")
	inv.initialize("Stephen")
	_check(is_equal_approx(inv.get_off_hand_modifier(), 1.1), "Stephen: off-hand items get a +10% bonus")

	# --- Jeremy: first ring trigger doubles only every 3rd cycle ---
	var data := CharacterData.create_jeremy()
	var stats := PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(data)

	inv.initialize("Jeremy")
	inv.connect_player_stats(stats)
	_check(inv.ring_double_trigger, "Jeremy: double-trigger passive is on")

	var ring := Fixtures.trigger_ring()
	_check(inv.equip_item(ring, 0), "trigger ring equips in ring slot 0")

	var fires := [0]
	inv.ring_triggered.connect(func(_item, _effect): fires[0] += 1)

	for cycle in range(1, 7):
		inv.process_turn()
		fires[0] = 0
		inv.trigger_rings(ring.ring_trigger)
		var want := 2 if cycle % Inventory.RING_DOUBLE_TRIGGER_CYCLES == 0 else 1
		_check(fires[0] == want, "cycle %d: first ring trigger fires %d time(s)" % [cycle, want])
		# Later triggers in the same cycle never double.
		fires[0] = 0
		inv.trigger_rings(ring.ring_trigger)
		_check(fires[0] == 1, "cycle %d: second ring trigger fires once" % cycle)

	# --- Passive badges appear on the right slot cells per character ---
	var panel_scene: PackedScene = load("res://scenes/character/character_panel.tscn")
	var panel = panel_scene.instantiate()
	get_root().add_child(panel)
	await process_frame  # let @onready nodes resolve
	panel.player_stats = stats
	panel.inventory = inv

	inv.initialize("Ryan")
	_check(_badge_tip(panel, ItemData.ItemType.BELT, 0).contains("10 less mana"),
		"Ryan: belt slots carry the -10 mana badge (post mana rescale)")
	_check(_badge_tip(panel, ItemData.ItemType.GAUNTLETS, 0) == "",
		"Ryan: gauntlet slots carry no badge")
	_check(_badge_tip(panel, ItemData.ItemType.WEAPON, 0) == "",
		"Ryan: main hand carries no badge")
	_check(_badge_tip(panel, ItemData.ItemType.WEAPON, 1).contains("10% penalty"),
		"Ryan: off hand carries the -10% penalty badge")

	inv.initialize("Cory")
	_check(_badge_tip(panel, ItemData.ItemType.GAUNTLETS, 1).contains("gauntlet skill comes off cooldown"),
		"Cory: gauntlet slots carry the mana-drop badge")

	inv.initialize("Jeremy")
	_check(_badge_tip(panel, ItemData.ItemType.RING, 0).contains("triggers twice"),
		"Jeremy: ring slots carry the recycle badge")

	inv.initialize("Brad")
	_check(_badge_tip(panel, ItemData.ItemType.CHEST, 0).contains("weigh 20% less"),
		"Brad: chest slot carries the feather 20% badge")
	_check(_badge_tip(panel, ItemData.ItemType.BELT, 0) == "",
		"Brad: belt slot carries no badge")

	inv.initialize("Stephen")
	_check(_badge_tip(panel, ItemData.ItemType.WEAPON, 1).contains("10% bonus"),
		"Stephen: off hand carries the +10% bonus badge")

	_test_shared_storage_pool()

	print("=== Done: %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_shared_storage_pool() -> void:
	## Items and looted cards share the ONE inventory pool — no separate card cap.
	print("-- Shared storage pool --")
	var inv := Inventory.new()
	inv.initialize("Ryan")

	for i in range(inv.max_storage_slots - 1):
		_check(inv.store_item(Fixtures.sword()), "item %d fits" % (i + 1))
	_check(inv.store_card(Card.create_slash()), "a card takes the last shared slot")
	_check(inv.used_storage_slots() == inv.max_storage_slots, "pool reads full")
	_check(inv.is_storage_full(), "is_storage_full counts items AND cards")
	_check(not inv.store_item(Fixtures.sword()), "no item slot left — cards count")
	_check(not inv.store_card(Card.create_slash()), "no card slot left either")

	inv.remove_stored_card(0)
	_check(inv.store_item(Fixtures.sword()), "freeing a card frees a slot for an item")
	inv.free()

## Build a bare slot cell and return its passive badge's tooltip ("" if none).
func _badge_tip(panel, item_type: int, slot_index: int) -> String:
	var cell := EquipmentSlotCell.new()
	cell.setup(panel, item_type, slot_index, null)
	for child in cell.get_children():
		if child is HBoxContainer and child.tooltip_text != "":
			return child.tooltip_text
	return ""
