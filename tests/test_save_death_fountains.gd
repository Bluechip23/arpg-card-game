extends SceneTree

## Three loop fixes:
##  - saves round-trip equipment (with levels + slotted cards), storage, stash,
##    currencies, and the skill tree's choices — through a JSON re-encode, which
##    is stricter than the .tres the game writes
##  - Holy Water is a stats currency that saves
##  - falling in solo play puts the character back at the level's start tile,
##    and Healing Fountains heal / bless / grant XP with persistent state
## Run: godot --headless --path . --script tests/test_save_death_fountains.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _settle(frames: int = 8) -> void:
	for _i in range(frames):
		await process_frame

func _initialize() -> void:
	print("=== Save round-trip / death / fountains test ===")
	_test_progression_io()
	_test_holy_water_stats()
	await _test_in_battle()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_progression_io() -> void:
	var bow := ItemData.create_short_bow()
	bow.level_up()  # Lv 2
	var slotted := Card.create_slash()
	bow.slotted_cards.append(slotted)
	var helm_slot: Array[ItemData] = [null]
	var weapons: Array[ItemData] = [bow, null]
	var stash: Array[ItemData] = [ItemData.create_wooden_sword()]
	var tree := SkillTreeData.create_tree_for("Brad")
	tree.rows[0].chosen_index = 2
	tree.rows[1].chosen_index = 1
	var live := {
		"stats": {"current_level": 3, "gold": 12, "holy_water": 2},
		"deck_state": {"draw_pile": ["slash"], "live": {"x": 1}},
		"skill_tree": tree,
		"inventory": {
			"equipped_helms": helm_slot, "equipped_weapons": weapons,
			"stored_items": [] as Array[ItemData], "stash_items": stash, "rack_items": [],
			"stored_cards": [Card.create_block()], "culling_stones": 7, "mythic_molds": 1, "rack_cooldown_tempo": 3,
		},
	}
	var disk := ProgressionIO.to_disk(live)
	_check(not disk.has("skill_tree") or disk["skill_tree"] is Dictionary, "skill tree goes to disk as plain data")
	_check(disk["inventory"]["equipped_weapons"][0]["level"] == 2, "item level is written")
	_check(disk["inventory"]["equipped_weapons"][0]["slotted"] == ["slash"], "slotted card ids are written")
	# Round-trip through JSON: strips types, turns int keys into strings.
	var reparsed = JSON.parse_string(JSON.stringify(disk))
	_check(reparsed is Dictionary, "snapshot survives JSON")
	var back := ProgressionIO.to_live(reparsed)
	var inv: Dictionary = back.get("inventory", {})
	_check(inv.has("equipped_weapons") and inv["equipped_weapons"].size() == 2, "weapon slots come back with the same count")
	var w0 = inv["equipped_weapons"][0]
	_check(w0 is ItemData and w0.item_name == "Short Bow", "equipped bow is rebuilt by name")
	_check(w0 is ItemData and w0.item_level == 2, "…at its forged level")
	_check(w0 is ItemData and w0.has_meta("pending_slotted_ids") and w0.get_meta("pending_slotted_ids") == ["slash"], "…remembering its slotted card ids for relinking")
	_check(inv["equipped_weapons"][1] == null and inv["equipped_helms"][0] == null, "empty slots stay empty")
	_check(inv["stash_items"].size() == 1 and inv["stash_items"][0].item_name == "Wooden Sword", "stash items come back")
	_check(inv["stored_cards"].size() == 1 and inv["stored_cards"][0].card_id == "block", "stored cards come back as cards")
	_check(inv["culling_stones"] == 7 and inv["mythic_molds"] == 1 and inv["rack_cooldown_tempo"] == 3, "currencies come back")
	_check(back.has("skill_tree_choices"), "skill tree choices come back for Main to apply")
	var rebuilt := SkillTreeData.create_tree_for("Brad")
	rebuilt.apply_choices(back["skill_tree_choices"])
	_check(rebuilt.rows[0].chosen_index == 2 and rebuilt.rows[1].chosen_index == 1 and rebuilt.rows[2].chosen_index == -1,
		"choices re-apply onto a fresh tree (even with JSON string keys)")

	# Relinking: a rebuilt deck card with the same id gets pointed at by the item.
	var inventory = load("res://scripts/progression/inventory.gd").new()
	get_root().add_child(inventory)
	inventory.equipped_weapons = inv["equipped_weapons"]
	var dm = load("res://scripts/cards/deck_manager.gd").new()
	get_root().add_child(dm)
	var deck_slash := Card.create_slash()
	dm.draw_pile.append(deck_slash)
	inventory.relink_slotted_cards(dm)
	_check(w0.slotted_cards.size() == 1 and w0.slotted_cards[0] == deck_slash and deck_slash.slotted_in_item == w0,
		"slotted card relinks to the deck's card instance")
	_check(not w0.has_meta("pending_slotted_ids"), "relink clears the pending ids")

func _test_holy_water_stats() -> void:
	var stats = load("res://scripts/character/player_stats.gd").new()
	get_root().add_child(stats)
	stats.initialize(CharacterData.create_brad())
	stats.gain_holy_water(2)
	_check(stats.holy_water == 2, "holy water accrues")
	_check(stats.spend_holy_water(1) and stats.holy_water == 1, "a vial can be spent")
	_check(not stats.spend_holy_water(5) and stats.holy_water == 1, "cannot overspend")
	var snap: Dictionary = stats.save_progression()
	_check(snap.get("holy_water", -1) == 1, "holy water is in the stats snapshot")
	stats.holy_water = 0
	stats.restore_progression(snap)
	_check(stats.holy_water == 1, "holy water restores from the snapshot")

func _test_in_battle() -> void:
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	get_root().add_child(main)
	await _settle()
	var dm = main.dungeon_manager
	if dm == null:
		_check(false, "battle scene booted")
		return
	_check(dm.fountain_nodes.size() == 2, "world 1 has two healing fountains (got %d)" % dm.fountain_nodes.size())
	if dm.fountain_nodes.is_empty():
		return
	var stats = main.player.get_stats()
	_check(dm.fountain_nodes[0]["blessed"] and not dm.fountain_nodes[0]["xp_used"], "a fresh fountain is blessed and unbathed")

	# Bathe: +20% of the XP to next level, once.
	var before_xp: int = stats.current_xp
	var expect: int = maxi(1, int(ceil(stats.get_xp_to_next_level() * main.FOUNTAIN_XP_FRACTION)))
	_check(main._fountain_bathe(0), "bathing grants XP")
	_check(stats.current_xp == before_xp + expect, "…20%% of the XP to next level (+%d)" % expect)
	_check(not main._fountain_bathe(0), "bathing a second time is refused")
	_check(main.opened_chests.get(dm._fountain_key(0), {}).get("xp_used", false), "the bathe is persisted in world state")

	# Drink: full heal, then dry.
	stats.take_direct_damage(4)
	_check(stats.current_health < stats.max_health, "took damage")
	_check(main._fountain_drink(0), "drinking heals")
	_check(stats.current_health == stats.max_health, "…to full health")
	_check(not dm.fountain_nodes[0]["blessed"], "the fountain runs dry")
	_check(not main._fountain_drink(0), "a dry fountain does not heal")

	# Pour: needs a vial, then blesses again.
	stats.holy_water = 0
	_check(not main._fountain_pour(0), "pouring with no Holy Water fails")
	stats.holy_water = 1
	_check(main._fountain_pour(0) and stats.holy_water == 0, "pouring a vial spends it")
	_check(dm.fountain_nodes[0]["blessed"], "…and blesses the fountain again")
	_check(main.opened_chests[dm._fountain_key(0)]["blessed"] == true, "the blessing is persisted in world state")

	# Persistence on re-entry: a fresh dungeon manager restores the state.
	main.opened_chests[dm._fountain_key(0)] = {"blessed": false, "xp_used": true}
	dm._restore_fountain_state()
	_check(not dm.fountain_nodes[0]["blessed"] and dm.fountain_nodes[0]["xp_used"], "fountain state restores from world state")

	# Death (solo): fall, then rise at the level's start tile with full health.
	var start: Vector3 = dm.get_player_start_world()
	main.player.position = start + Vector3(4, 0, 2)
	main.player.target_position = main.player.position
	stats.take_direct_damage(stats.current_health + 50)
	await _settle(2)
	_check(stats.current_health <= 0, "lethal damage drops health to 0")
	_check(main._solo_fallen, "solo death is caught")
	_check(main.get_node("UI").get_node_or_null("FallenOverlay") != null, "the Fallen overlay is shown")
	main._respawn_at_level_start()
	var pg: Vector2i = main.grid_manager.world_to_grid(main.player.position)
	_check(pg == dm.player_start, "the player rises at the level's start tile (%s)" % [pg])
	_check(stats.current_health == stats.max_health, "…at full health")
	_check(not main._solo_fallen, "…ready to fall again")
