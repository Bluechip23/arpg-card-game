extends SceneTree

## Verifies the Draw-pile clock icon (PilePassiveIcon): which inventories
## show it, how Cory's gauntlet recharge and Jeremy's ring cycle count map
## onto its three bands, the faded / ready looks, and the "spent this cycle"
## case for the ring double.
## Run: godot --headless --path . --script tests/test_pile_passive_icon.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _inventory(character: String) -> Inventory:
	var inv := Inventory.new()
	inv.player_stats = PlayerStats.new()
	inv.initialize(character)
	return inv

func _initialize() -> void:
	print("=== Pile passive icon test ===")
	var tm := TempoManager.new()
	tm.tempo_threshold = 5
	tm.current_tempo = 0

	# --- Who shows the icon ---
	var brad := _inventory("Brad")
	_check(PilePassiveIcon.kind_for(brad) == "", "Brad shows no clock icon")
	_check(PilePassiveIcon.kind_for(null) == "", "no inventory shows no clock icon")

	# --- Cory: gauntlet recharge ---
	var cory := _inventory("Cory")
	_check(PilePassiveIcon.kind_for(cory) == "gauntlet", "Cory shows the gauntlet icon")
	var st: Dictionary = PilePassiveIcon.gauntlet_state(cory, tm)
	_check(not st.equipped and st.lit == 0, "no gauntlet equipped: faded, nothing lit")

	var gloves := ItemData.create("chain_gloves")  # Guard: active, 4-cycle recharge
	_check(cory.equip_item(gloves, 0), "chain gloves equip into Cory's first gauntlet slot")
	st = PilePassiveIcon.gauntlet_state(cory, tm)
	_check(st.equipped and st.ready and st.lit == 3, "skill ready, nothing cooling: solid, all three lit")

	gloves.activate_skill()  # 4 cycles = 20 tempo
	st = PilePassiveIcon.gauntlet_state(cory, tm)
	_check(st.on_cooldown and st.lit == 0 and not st.ready, "just used: on cooldown, 0/3 lit (got %d)" % st.lit)
	cory.process_turn()  # 3 cycles left -> 5/20 elapsed
	st = PilePassiveIcon.gauntlet_state(cory, tm)
	_check(st.lit == 0, "5/20 recharged: still 0 bands (got %d)" % st.lit)
	cory.process_turn()  # 10/20
	st = PilePassiveIcon.gauntlet_state(cory, tm)
	_check(st.lit == 1, "10/20 recharged: 1 band (got %d)" % st.lit)
	tm.current_tempo = 4  # inside the cycle counts toward the pending cycle: 14/20
	st = PilePassiveIcon.gauntlet_state(cory, tm)
	_check(st.lit == 2 and "14/20" in st.tip, "14/20 recharged: 2 bands, tooltip shows 14/20 (got %d, '%s')" % [st.lit, st.tip])
	tm.current_tempo = 0
	cory.process_turn()  # 15/20
	st = PilePassiveIcon.gauntlet_state(cory, tm)
	_check(st.lit == 2 and st.on_cooldown, "15/20 recharged: 2 bands, still cooling")
	cory.process_turn()  # comes off cooldown: the passive pays out
	st = PilePassiveIcon.gauntlet_state(cory, tm)
	_check(st.ready and st.lit == 3 and gloves.current_cooldown == 0, "recharged: ready again, all three lit")

	# Two gauntlets: the soonest recharge drives the bands.
	var second := ItemData.create("chain_gloves")
	_check(cory.equip_item(second, 1), "a second pair equips into Cory's second gauntlet slot")
	gloves.activate_skill()
	second.activate_skill()
	cory.process_turn()
	cory.process_turn()
	cory.process_turn()  # both at 15/20 -> 2 bands
	gloves.activate_skill()  # the first restarts at 0/20; the second still leads at 15/20
	st = PilePassiveIcon.gauntlet_state(cory, tm)
	_check(st.lit == 2, "two gauntlets: the soonest recharge sets the bands (got %d)" % st.lit)

	# --- Jeremy: ring cycle count ---
	var jeremy := _inventory("Jeremy")
	_check(PilePassiveIcon.kind_for(jeremy) == "ring", "Jeremy shows the ring icon")
	st = PilePassiveIcon.ring_state(jeremy)
	_check(not st.equipped and st.lit == 0, "no ring equipped: faded, nothing lit")
	_check(jeremy.equip_item(ItemData.create("gold_band"), 0), "a Gold Band equips on Jeremy")
	st = PilePassiveIcon.ring_state(jeremy)
	_check(st.equipped and st.on_cooldown and st.lit == 0, "before the first cycle: 0 bands")
	jeremy.process_turn()
	st = PilePassiveIcon.ring_state(jeremy)
	_check(st.lit == 1 and not st.ready, "cycle 1: 1 band (got %d)" % st.lit)
	jeremy.process_turn()
	st = PilePassiveIcon.ring_state(jeremy)
	_check(st.lit == 2 and not st.ready, "cycle 2: 2 bands (got %d)" % st.lit)
	jeremy.process_turn()
	st = PilePassiveIcon.ring_state(jeremy)
	_check(st.ready and st.lit == 3 and not st.on_cooldown, "cycle 3: armed — solid, all three lit")
	jeremy.ring_triggered_this_turn = true  # the first ring trigger of the cycle fired twice
	st = PilePassiveIcon.ring_state(jeremy)
	_check(st.on_cooldown and st.lit == 0 and not st.ready, "spent this cycle: faded, nothing lit")
	jeremy.process_turn()  # cycle 4 -> 1 band again
	st = PilePassiveIcon.ring_state(jeremy)
	_check(st.lit == 1 and not st.ready, "cycle 4: the count restarts at 1 band (got %d)" % st.lit)

	# --- The control reflects the state ---
	var icon := PilePassiveIcon.new()
	root.add_child(icon)
	icon.refresh(brad, tm)
	_check(not icon.visible, "icon hides for a character without either passive")
	icon.refresh(cory, tm)
	_check(icon.visible and icon.kind == "gauntlet" and icon.modulate.a == 1.0, "icon shows solid for Cory with gauntlets")
	_check(icon.lit_bands() == 2, "icon reports the gauntlet bands (got %d)" % icon.lit_bands())
	cory.unequip_item(ItemData.ItemType.GAUNTLETS, 0)
	cory.unequip_item(ItemData.ItemType.GAUNTLETS, 1)
	icon.refresh(cory, tm)
	_check(icon.visible and icon.modulate.a < 0.5 and icon.lit_bands() == 0, "icon fades out with no gauntlet equipped")
	jeremy.ring_triggered_this_turn = false
	jeremy.process_turn()
	jeremy.process_turn()  # cycle 6: armed
	icon.refresh(jeremy, tm)
	_check(icon.kind == "ring" and icon.is_ready() and icon.lit_bands() == 3, "icon reads ready on Jeremy's armed cycle")
	_check("fires twice" in icon.tooltip_text, "tooltip explains the ring double")

	icon.free()
	brad.free()
	cory.free()
	jeremy.free()
	tm.free()

	if failures == 0:
		print("=== 0 failure(s) ===")
	else:
		printerr("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
