extends SceneTree

## The designer's third play report, through the real Main scene: the
## damage preview shows the armor share in grey before the hit; the town
## portal lies on its back; the character cards state the real slot counts
## and the War Rack's rule; a weapon from the War Rack is held two-handed
## and never one-handed; the figure returns when Invisible ends (or the
## player falls); timed buffs count down on their badge; and a refused
## equip says why (a mythic before level 15 is not "too heavy").
## Run: godot --headless --path . --script tests/test_report_fixes.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: " + msg)
	else:
		print("  FAIL: " + msg)
		failures += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("=== Play report fixes test ===")
	var runner := SimRunner.new(self)
	var sc := SimScenario.with_defaults(CharacterBuilds.compose("ryan", {"build": "bruiser", "level": 1, "enemy": "LARGE_BEAR"}))
	await runner.boot_only(sc, 1)
	var main = runner.main
	var stats = main.player.get_stats()
	var inv = main.player.get_inventory()
	var dm = main.deck_manager
	var bear = main.enemy_spawner.get_living_enemies()[0]

	# --- 1. Preview: armor share before the hit.
	var slash = dm._create_card_from_id("slash")
	bear.current_armor = 0
	var plain: Dictionary = main.calculate_damage_preview_split(slash, bear)
	_check(plain["health"] > 0 and plain["armor"] == 0, "no armor: the preview is all health (%d)" % plain["health"])
	bear.current_armor = 3
	var split: Dictionary = main.calculate_damage_preview_split(slash, bear)
	_check(split["armor"] == 3 and split["health"] == plain["health"] - 3, "3 armor: '3/%d' (%s)" % [split["health"], str(split)])
	_check(main.calculate_damage_preview(slash, bear) == split["health"], "the old health-only call still agrees")
	bear.current_armor = 200
	var walled: Dictionary = main.calculate_damage_preview_split(slash, bear)
	_check(walled["armor"] == plain["health"] and walled["health"] == 0, "a wall of armor: all of it grey (%d)" % walled["armor"])
	bear.show_damage_preview(walled["health"], walled["armor"])
	_check(bear._damage_preview_label.visible and bear._damage_preview_label.text == str(walled["armor"])
		and bear._damage_preview_label.modulate.is_equal_approx(Color(bear.ARMOR_NUMBER_COLOR, 0.9)),
		"the armor-only preview reads grey above its head")
	bear.show_damage_preview(split["health"], split["armor"])
	_check(bear._armor_preview_label.visible and bear._armor_preview_label.text == "3/" and bear._damage_preview_label.text == str(split["health"])
		and bear._armor_preview_label.offset.x < 0.0 and bear._damage_preview_label.offset.x > 0.0,
		"the split preview reads '3/%d', grey then red, side by side" % split["health"])
	bear.hide_damage_preview()
	_check(not bear._armor_preview_label.visible and not bear._damage_preview_label.visible, "and both halves hide together")
	bear.current_armor = 0

	# --- 2. The portal lies on its back.
	var portal := DungeonManager.make_town_portal_visual()
	var torus: MeshInstance3D = portal.get_child(0)
	var film: MeshInstance3D = portal.get_child(1)
	_check(torus.mesh is TorusMesh and torus.rotation_degrees == Vector3.ZERO and torus.position.y < 0.3,
		"the torus is flat on the ground (hole up), y %.2f" % torus.position.y)
	_check(film.mesh is CylinderMesh and film.rotation_degrees == Vector3.ZERO and film.position.y < torus.position.y,
		"the film disc lies inside it")
	portal.free()

	# --- 3. Character cards: real slot counts and the War Rack's rule.
	var by_name := {}
	for c in CharacterData.get_all_characters():
		by_name[c.character_name] = c
	_check(by_name["Ryan"].slot_specialty == "2 belt slots", "Ryan: 2 belt slots (%s)" % by_name["Ryan"].slot_specialty)
	_check(by_name["Jeremy"].slot_specialty == "3 ring slots", "Jeremy: 3 ring slots (%s)" % by_name["Jeremy"].slot_specialty)
	var rack_text: String = by_name["Brad"].slot_specialty
	_check(rack_text.find("two-handed for free") >= 0 and rack_text.find("cards to your hand") >= 0 and rack_text.find("never be held 1-handed") >= 0,
		"Brad's card explains the War Rack (%s)" % rack_text)
	var r_inv := Inventory.new()
	r_inv.initialize("Ryan")
	var j_inv := Inventory.new()
	j_inv.initialize("Jeremy")
	_check(r_inv.belt_slots == 2 and j_inv.ring_slots == 3, "and the inventories agree (Ryan %d belts, Jeremy %d rings)" % [r_inv.belt_slots, j_inv.ring_slots])

	# --- 7. A refused equip says why.
	var doughnut := ItemData.create("bladed_doughnut")
	_check(doughnut != null and doughnut.rarity == ItemData.Rarity.MYTHIC, "the Bladed Doughnut is a mythic")
	var slot_arr = inv._get_slot_array(doughnut.item_type)
	var free_slot: int = slot_arr.find(null)
	if free_slot < 0:
		inv.stored_items.append(inv.unequip_item(doughnut.item_type, 0))
		free_slot = 0
	_check(stats.current_level < 15 and not inv.equip_item(doughnut, free_slot), "at level %d it cannot be equipped" % stats.current_level)
	_check(inv.last_refusal.find("seasoned hand") >= 0 and inv.last_refusal.find("level 15") >= 0 and inv.last_refusal.find("heavy") < 0,
		"and the reason is the mythic level, not weight: '%s'" % inv.last_refusal)
	runner.teardown()

	# --- 4. War Rack (Brad): a racked weapon is two-handed and stays so.
	sc = SimScenario.with_defaults(CharacterBuilds.compose("brad", {"build": "castle_wall", "alt": "none", "enemy": "LARGE_BEAR"}))
	await runner.boot_only(sc, 1)
	main = runner.main
	inv = main.player.get_inventory()
	_check(inv.has_back_rack, "Brad has the War Rack")
	var hammer := ItemData.create("rusty_dagger")
	_check(inv.rack_store_item(hammer) and inv.is_war_rack_item(hammer), "a dagger straps to the rack and belongs to its slot")
	var before_hand: Array = inv.get_rack_hand_items().duplicate()
	inv.rack_cooldown_tempo = 0
	var res: Dictionary = inv.rack_deploy()
	_check(res["success"] and inv.equipped_weapons[0] == hammer and inv.two_handed_slot == 0,
		"drawing the rack brings it to hand held two-handed (%s)" % str(res))
	_check(not inv.set_two_handed(0, false) and inv.two_handed_slot == 0 and inv.last_refusal.find("War Rack") >= 0,
		"it refuses to be held one-handed while in the rack's slot: '%s'" % inv.last_refusal)
	_check(before_hand.all(func(it): return inv.rack_parked.has(it) and not inv.is_war_rack_item(it)), "the usual weapons are set aside, untouched by the rule")
	var back: Dictionary = inv.rack_return()
	_check(back["success"] and inv.rack_items.has(hammer) and not inv.equipped_weapons.has(hammer)
		and before_hand.all(func(it): return inv.equipped_weapons.has(it)), "returning sends it back up and the usual weapons come back")
	var taken = inv.rack_take_item(inv.rack_items.find(hammer))
	_check(taken == hammer and not inv.is_war_rack_item(hammer), "taken off the rack, it is an ordinary weapon again")
	# Through the battle HUD: the Rack button draws it, the tempo clock brings the gear back.
	_check(inv.rack_store_item(hammer), "strapped on again")
	inv.rack_cooldown_tempo = 0
	main._on_rack_button_pressed()
	_check(inv.rack_is_deployed() and inv.equipped_weapons[0] == hammer and main._rack_button.text.begins_with("Rack ↩"),
		"the HUD button draws the rack (%s)" % main._rack_button.text)
	main._on_tempo_advanced(0, 19)
	_check(inv.rack_is_deployed() and inv.rack_deploy_tempo == 1, "19 tempo on the clock: still out")
	main._on_tempo_advanced(0, 1)
	_check(not inv.rack_is_deployed() and inv.rack_weapon() == hammer and before_hand.all(func(it): return inv.equipped_weapons.has(it)),
		"the 20th tempo brings the usual gear back on its own")
	_check(main._rack_button.text == "Rack 40T", "the button shows the recharge (%s)" % main._rack_button.text)

	# --- 5. Invisible: the figure returns when the buff ends, or on death.
	var bm = main.player.get_buff_manager()
	var fig = main.player._figure
	bm.apply_buff(Buff.create_invisible(3, "test"))
	main._set_player_invisible(true)
	_check(fig._base_modulate.a < 1.0 and main._player_translucent, "invisible: the figure is faded (a %.2f)" % fig._base_modulate.a)
	bm.remove_buff(Buff.BuffType.INVISIBLE)
	_check(fig._base_modulate.a == 1.0 and not main._player_translucent, "the buff gone (an attack broke it): the figure is solid again")
	bm.apply_buff(Buff.create_invisible(2, "test"))
	main._set_player_invisible(true)
	bm.advance_time(2)
	_check(fig._base_modulate.a == 1.0, "the buff expired by the clock: solid again")
	bm.apply_buff(Buff.create_invisible(9, "test"))
	main._set_player_invisible(true)
	main._on_solo_player_died()
	_check(fig._base_modulate.a == 1.0, "down while invisible: the figure is seen")
	bm.remove_buff(Buff.BuffType.INVISIBLE)

	# --- 6. Timed buffs count down on the badge (Understanding).
	bm.understanding_tempo = 4
	bm.sync_flag_buffs()
	await process_frame
	var icons: Array = main.buff_bar.get_children().filter(func(c): return c is BuffIconUI and c.buff.buff_name == "Understanding")
	_check(icons.size() == 1 and icons[0]._count_label.text == "4", "Understanding's badge reads its countdown (%s)" % (icons[0]._count_label.text if not icons.is_empty() else "none"))
	bm.advance_time(1)
	bm.sync_flag_buffs()
	await process_frame
	icons = main.buff_bar.get_children().filter(func(c): return c is BuffIconUI and c.buff.buff_name == "Understanding")
	_check(icons.size() == 1 and icons[0]._count_label.text == "3", "a tempo later it reads 3 (%s)" % (icons[0]._count_label.text if not icons.is_empty() else "none"))
	bm.apply_buff(Buff.create_invisible(7, "test"))
	await process_frame
	var inv_icons: Array = main.buff_bar.get_children().filter(func(c): return c is BuffIconUI and c.buff.buff_type == Buff.BuffType.INVISIBLE)
	_check(inv_icons.size() == 1 and inv_icons[0]._count_label.text == "7", "a plain timed buff shows its tempo left (%s)" % (inv_icons[0]._count_label.text if not inv_icons.is_empty() else "none"))
	bm.advance_time(2)
	_check(inv_icons.size() == 1 and inv_icons[0]._count_label.text == "5", "and ticks down in place (%s)" % (inv_icons[0]._count_label.text if not inv_icons.is_empty() else "none"))
	runner.teardown()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
