extends SceneTree

## Stephen's man of arms, through the real Main scene and the character
## panel's build button, mid-fight: a weapons-only build switch is free (no
## tempo, no mana) and everything the weapons carry flips with them — the
## items in hand and in the backpack, their stat bonuses, their engraved
## cards, the auto attack's reach and tempo, the shield, the figure's weapon,
## and the saved builds — and it keeps flipping cleanly back and forth.
## Ryan, same steps, pays tempo and mana. The bug this guards: a 0-cost
## switch returned success without moving the weapons.
## Run: godot --headless --path . --script tests/test_stephen_build_switch.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: " + msg)
	else:
		print("  FAIL: " + msg)
		failures += 1

func _initialize() -> void:
	_run.call_deferred()

## How many deck zones hold this card (0 = out of play, 1 = in play once).
func _zones(dm, card) -> int:
	var n := 0
	for pile in [dm.draw_pile, dm.hand, dm.discard_pile, dm.jail_pile]:
		n += pile.count(card)
	return n

func _snapshot(main) -> Dictionary:
	var stats = main.player.get_stats()
	var inv = main.player.get_inventory()
	return {"str": stats.strength, "dex": stats.dexterity, "int": stats.intelligence, "wis": stats.wisdom,
		"max_hp": stats.max_health, "carry": stats.current_carry_load, "weight": inv.get_total_weight()}

func _run() -> void:
	print("=== Stephen build switch test ===")
	var runner := SimRunner.new(self)
	for who in ["stephen", "ryan"]:
		var parts := {"build": "heavy_swing", "alt": "none", "enemy": "LARGE_BEAR"} if who == "stephen" \
			else {"build": "bruiser", "enemy": "LARGE_BEAR"}
		var sc := SimScenario.with_defaults(CharacterBuilds.compose(who, parts))
		await runner.boot_only(sc, 1)
		var main = runner.main
		var inv = main.player.get_inventory()
		var stats = main.player.get_stats()
		var dm = main.deck_manager
		var panel = main.character_panel
		_check(main._is_in_combat(), "%s: the bear is in aggro range (swaps are charged)" % who)

		# Build II, set up the way a player does: a bow and quiver in hand,
		# Quick Shot engraved in the bow.
		var sword = inv.equipped_weapons[0]
		var off = inv.equipped_weapons[1]
		var bow := ItemData.create_long_bow()
		var quiver := ItemData.create_standard_quiver()
		var shot = dm._create_card_from_id("quick_shot")
		_check(bow.slot_card(shot), "%s: Quick Shot engraves into the bow" % who)
		inv.switch_build(1)
		for i in range(inv.equipped_weapons.size()):
			if inv.equipped_weapons[i] != null:
				inv.stored_items.append(inv.unequip_item(ItemData.ItemType.WEAPON, i))
		_check(inv.equip_item(bow, 0) and inv.equip_item(quiver, 1), "%s: build II holds the bow and quiver" % who)
		inv.switch_build(0)
		_check(inv.equipped_weapons[0] == sword and inv.equipped_weapons[1] == off and inv.active_build == 0,
			"%s: back on build I with the blade in hand" % who)
		var blade_cards: Array = inv._get_item_owned_cards(sword) + (inv._get_item_owned_cards(off) if off else [])
		var melee := _snapshot(main)
		stats.current_mana = float(stats.get_available_max_mana())
		var mana0: float = stats.current_mana

		if who == "ryan":
			var t0: int = main.tempo_manager.global_tempo
			panel._on_build_pressed(1)
			_check(inv.equipped_weapons[0] == bow, "ryan: the switch puts the bow in hand")
			_check(main.tempo_manager.global_tempo > t0 and stats.current_mana < mana0,
				"ryan: the same switch costs tempo and mana (%d tempo, %.0f -> %.0f mana)" % [main.tempo_manager.global_tempo - t0, mana0, stats.current_mana])
			runner.teardown()
			continue

		for trip in range(1, 4):
			var t0: int = main.tempo_manager.global_tempo
			var m0: float = stats.current_mana
			panel._on_build_pressed(1)
			await process_frame
			var ranged := _snapshot(main)
			_check(inv.equipped_weapons[0] == bow and inv.equipped_weapons[1] == quiver and inv.active_build == 1,
				"trip %d: build II puts the bow and quiver in hand" % trip)
			_check(inv.stored_items.has(sword) and inv.stored_items.has(off) and not inv.stored_items.has(bow),
				"trip %d: the blade and shield go to the backpack" % trip)
			# Free: no tempo and no mana charge. Fallen's Wrath's +5 INT leaves
			# with it, so max mana drops and full mana is clipped to the new cap
			# (not refunded when the blade comes back) — a weapon's stats, not
			# the switch's price.
			_check(main.tempo_manager.global_tempo == t0 and stats.current_mana == minf(m0, float(stats.get_available_max_mana())),
				"trip %d: free — no tempo, no mana charged (%.0f -> %.0f, cap %d)" % [trip, m0, stats.current_mana, stats.get_available_max_mana()])
			_check(ranged["str"] == melee["str"] - sword.strength_bonus - off.strength_bonus + bow.strength_bonus + quiver.strength_bonus
				and ranged["dex"] == melee["dex"] - sword.dexterity_bonus - off.dexterity_bonus + bow.dexterity_bonus + quiver.dexterity_bonus
				and ranged["int"] == melee["int"] - sword.intelligence_bonus - off.intelligence_bonus
				and ranged["max_hp"] < melee["max_hp"],
				"trip %d: the blade's stat bonuses come off and the bow's go on (STR %d->%d, DEX %d->%d, INT %d->%d, HP %d->%d)" % [trip,
					melee["str"], ranged["str"], melee["dex"], ranged["dex"], melee["int"], ranged["int"], melee["max_hp"], ranged["max_hp"]])
			_check(ranged["carry"] == ranged["weight"] and ranged["weight"] != melee["weight"],
				"trip %d: carry load re-read (%d -> %d)" % [trip, melee["weight"], ranged["weight"]])
			_check(_zones(dm, shot) == 1 and blade_cards.all(func(c): return _zones(dm, c) == 0),
				"trip %d: Quick Shot enters play once; the blade's engraved cards leave play" % trip)
			_check(inv.holds_ranged_weapon() and main._basic_attack_reach() == 5 and main._basic_attack_tempo() == 6,
				"trip %d: the auto attack reaches 5 for 6 tempo" % trip)
			_check(not inv.has_shield_equipped() and inv.held_weapon_kind() == "bow",
				"trip %d: no shield; the figure holds a bow (%s)" % [trip, inv.held_weapon_kind()])

			var m1: float = stats.current_mana
			panel._on_build_pressed(0)
			await process_frame
			var back := _snapshot(main)
			_check(inv.equipped_weapons[0] == sword and inv.equipped_weapons[1] == off and inv.active_build == 0
				and inv.stored_items.has(bow) and inv.stored_items.has(quiver),
				"trip %d: build I puts the blade and shield back; the bow goes to the backpack" % trip)
			_check(main.tempo_manager.global_tempo == t0 and stats.current_mana == minf(m1, float(stats.get_available_max_mana())),
				"trip %d: back is free too (%.0f -> %.0f)" % [trip, m1, stats.current_mana])
			_check(back == melee, "trip %d: every stat, the carry load and the weight are as before (%s)" % [trip, str(back)])
			_check(_zones(dm, shot) == 0 and blade_cards.all(func(c): return _zones(dm, c) == 1),
				"trip %d: the blade's cards are back in play once each; Quick Shot left" % trip)
			_check(main._basic_attack_reach() == 1 and inv.has_shield_equipped(), "trip %d: melee reach and the shield again" % trip)
			_check(inv.builds[1]["weapons"][0] == bow and inv.builds[0]["weapons"][0] == sword,
				"trip %d: both saved builds still hold their own weapons" % trip)
		# A single weapon swap from the backpack (the panel's drag-and-drop):
		# man of arms makes it 1 + 1 tempo and no mana.
		var dagger := ItemData.create_rusty_dagger()
		inv.stored_items.append(dagger)
		var t1: int = main.tempo_manager.global_tempo
		var m2: float = stats.current_mana
		panel._handle_item_drop_on_slot({"source": "storage", "item": dagger, "storage_index": inv.stored_items.find(dagger)},
			ItemData.ItemType.WEAPON, 0)
		await process_frame
		_check(inv.equipped_weapons[0] == dagger and inv.stored_items.has(sword) and blade_cards.slice(0, inv._get_item_owned_cards(sword).size()).all(func(c): return _zones(dm, c) == 0),
			"a single swap puts the dagger in hand and the blade (and its cards) away")
		_check(main.tempo_manager.global_tempo - t1 == 2 and stats.current_mana == minf(m2, float(stats.get_available_max_mana())),
			"a single weapon swap costs Stephen 2 tempo and no mana (%d tempo, %.0f -> %.0f)" % [main.tempo_manager.global_tempo - t1, m2, stats.current_mana])
		runner.teardown()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
