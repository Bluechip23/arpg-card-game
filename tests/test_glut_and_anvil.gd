extends SceneTree

## Glut counts down with every tempo and lasts its full printed length after
## the play that caused it (designer, 2026-11-12); and the Anvil of the
## Burdened (designer's row, same day).
## Run: godot --headless --path . --script tests/test_glut_and_anvil.gd

var failures := 0
var main = null

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	main = packed.instantiate()
	main.set("dojo_mode", true)
	main.set("starting_character", CharacterData.create_brad())
	get_root().add_child(main)
	for _i in range(8):
		await process_frame
	print("=== Glut per tempo / Anvil of the Burdened ===")
	var tm = main.tempo_manager

	print("-- Glut --")
	main.glut_tempo_remaining = 10
	tm._process_one_tick()
	_check(main.glut_tempo_remaining == 9, "one tempo takes one off the Glut (%d)" % main.glut_tempo_remaining)
	for _i in range(8):
		tm._process_one_tick()
	_check(main.glut_tempo_remaining == 1, "9 tempo in, 1 is left whatever the cycle did (%d)" % main.glut_tempo_remaining)
	tm._process_one_tick()
	_check(main.glut_tempo_remaining == 0, "it ends on the 10th tempo exactly")

	print("-- Anvil of the Burdened --")
	var anvil: ItemData = ItemData.create("anvil_of_the_burdened")
	_check(anvil != null and anvil.item_name == "Anvil of the Burdened" and anvil.rarity == ItemData.Rarity.LEGENDARY
		and anvil.weapon_subtype == ItemData.WeaponSubtype.HAMMER and anvil.weight == 150, "a Legendary hammer, weight 150")
	_check(anvil.card_slots == 2 and anvil.vanilla_slots == 1, "2 bonus slots and 1 plain")
	_check(anvil.strength_bonus == 6 and anvil.intelligence_bonus == 5 and anvil.dexterity_bonus == -10 and anvil.agility_bonus == -10,
		"+6 STR, +5 INT, -10 DEX, -10 AGI")
	_check(anvil.on_self_tempo_penalty == 3 and anvil.on_self_armor_any == 5, "on-self: +3 tempo, 5 armor")
	_check(anvil.granted_card_ids.has("crash_from_the_sea"), "grants Crash from the Sea")
	var crash := Card.create_by_id("crash_from_the_sea")
	_check(crash.mana_cost == 160 and crash.tempo_cost == 10 and crash.damage == 3, "Crash from the Sea: 160 mana, 10 tempo, 3 damage")
	_check(crash.is_offensive() and not crash.is_attack() and crash.school != Card.CardSchool.SPELL and crash.is_mixed_offensive(),
		"it is a plain Offensive card")
	_check(Card.DROP_EXCLUDED_CARD_IDS.has("crash_from_the_sea"), "it never drops on its own")

	var stats: PlayerStats = main.player.get_stats()
	var inv = main.player.get_inventory()
	var dummy = main.enemy_spawner.get_living_enemies()[0] if not main.enemy_spawner.get_living_enemies().is_empty() else null
	_check(dummy != null, "a dojo dummy stands")
	if dummy == null:
		_done()
		return
	dummy.max_health = 5000
	dummy.current_health = 5000
	dummy.current_armor = 0
	# Bare: 4 waves of the plain number.
	var bare := Card.create_by_id("crash_from_the_sea")
	bare.execute(dummy, stats, main.deck_manager, 0.0, 0.0, null)
	var bare_total: int = 5000 - dummy.current_health
	_check(bare_total == 4 * stats.get_effective_physical_damage(3), "bare, it deals 3 (scaled) four times: %d" % bare_total)
	# With the Anvil in hand: +1 per 50 weight carried and +1 per tempo above 4, on every wave.
	inv.equipped_weapons.append(anvil)
	stats.current_carry_load = 230
	dummy.current_health = 5000
	var held := Card.create_by_id("crash_from_the_sea")
	held.execute(dummy, stats, main.deck_manager, 0.0, 0.0, null)
	var per_wave: int = stats.get_effective_physical_damage(3 + 4 + 6)
	_check(5000 - dummy.current_health == 4 * per_wave,
		"with the Anvil at 230 weight: +4 for the weight and +6 for its 10 tempo, on each of the 4 waves (%d, want %d)" % [5000 - dummy.current_health, 4 * per_wave])
	_check(held.bonus_damage == 0, "the bonus does not stick to the card")
	# Slotted in the Anvil's bonus slot, its own +3 tempo counts: Heavy Swing's 3 tempo becomes 6 -> +2.
	dummy.current_health = 5000
	var slotted := Card.create_by_id("heavy_swing")
	_check(slotted.tempo_cost == 3 and anvil.slot_card(slotted), "Heavy Swing (3 tempo) slots into the Anvil")
	if slotted.slotted_in_item == anvil:
		slotted.execute(dummy, stats, main.deck_manager, 0.0, 0.0, null)
		var want_slotted: int = stats.get_effective_physical_damage(20 + 4 + 2)
		_check(5000 - dummy.current_health == want_slotted,
			"slotted in the Anvil, the on-self +3 tempo counts: 6 tempo gives +2 (%d, want %d)" % [5000 - dummy.current_health, want_slotted])
		_check(stats.current_armor >= 5, "and the play gains 5 armor")
		anvil.unslot_card(0)
	dummy.current_health = 5000
	var cheap := Card.create_by_id("slash")
	cheap.execute(dummy, stats, main.deck_manager, 0.0, 0.0, null)
	_check(5000 - dummy.current_health == stats.get_effective_physical_damage(10 + 4),
		"a 3-tempo offensive card gets the weight's +4 and nothing for tempo (%d)" % (5000 - dummy.current_health))
	inv.equipped_weapons.erase(anvil)
	stats.current_carry_load = 0
	_test_yari(stats, inv, dummy)
	_done()

func _cell_pos(off: Vector2i) -> Vector3:
	var gm = main.grid_manager
	return gm.grid_to_world(gm.world_to_grid(main.player.position) + off)

func _put(e, off: Vector2i) -> void:
	e.position = _cell_pos(off)
	if "target_position" in e:
		e.target_position = e.position

func _test_yari(stats: PlayerStats, inv, dummy) -> void:
	print("-- Yari of the Spider Monkey --")
	var yari: ItemData = ItemData.create("yari_of_the_spider_monkey")
	_check(yari != null and yari.rarity == ItemData.Rarity.LEGENDARY and yari.weapon_subtype == ItemData.WeaponSubtype.POLEARM
		and yari.weight == 35, "a Legendary spear, weight 35")
	_check(yari.card_slots == 0 and yari.vanilla_slots == 3, "no bonus slots, 3 plain")
	_check(yari.agility_bonus == 5 and yari.determination_bonus == 7, "+5 AGI, +7 DET")
	_check(yari.sidestep_bonus_armor == 3, "flash-point block grants 3 more armor")
	_check(yari.granted_card_ids == ["pole_vault", "whirling_dash"], "grants Pole Vault and Whirling Dash")
	var vault := Card.create_by_id("pole_vault")
	var dash := Card.create_by_id("whirling_dash")
	_check(vault.card_type == Card.CardType.DEFENSE and vault.mana_cost == 10 and vault.tempo_cost == 1 and vault.block == 10,
		"Pole Vault: Defense, 10 mana, 1 tempo, 10 armor")
	_check(dash.is_attack() and dash.mana_cost == 95 and dash.tempo_cost == 2 and dash.resolve_tick == 1 and dash.damage == 6,
		"Whirling Dash: Attack, 95 mana, 2 tempo (resolves on the first), 6 damage")
	_check(YariCards.point_reach(vault) == 3 and YariCards.point_reach(dash) == 3, "both reach 3 spaces")
	inv.equipped_weapons.append(yari)
	var others: Array = main.enemy_spawner.get_living_enemies()
	for i in range(others.size()):
		_put(others[i], Vector2i(-9 - i, 6))
		others[i].max_health = 5000
		others[i].current_health = 5000
		others[i].current_armor = 0

	# Pole Vault: armor, the blink, and the displacement arms the +50%.
	stats.current_armor = 0
	stats.remove_meta(YariCards.ARMED_META) if stats.has_meta(YariCards.ARMED_META) else null
	var start: Vector3 = main.player.position
	vault.execute(main.player, stats, main.deck_manager, 0.0, 0.0, main.player.get_buff_manager())
	_check(stats.current_armor >= 10, "Pole Vault grants 10 armor (%d)" % stats.current_armor)
	_check(not YariCards.world_effects(main, Card.create_by_id("slash"), start), "other cards are not the Yari's")
	YariCards.world_effects(main, vault, _cell_pos(Vector2i(5, 0)))
	_check(main.player.position.is_equal_approx(start), "a tile 5 away is out of reach: no blink")
	YariCards.world_effects(main, vault, _cell_pos(Vector2i(3, 0)))
	_check(not main.player.position.is_equal_approx(start), "it blinks 3 spaces")
	_check(stats.has_meta(YariCards.ARMED_META) and float(stats.get_meta(YariCards.ARMED_META)) == 50.0,
		"the displacement arms +50% on the next offensive card")
	# A Defense card does not spend it; the next offensive card does, for the whole hit.
	Card.create_by_id("block").execute(main.player, stats, main.deck_manager, 0.0, 0.0, null)
	_check(stats.has_meta(YariCards.ARMED_META), "a Defense card leaves it armed")
	_put(dummy, Vector2i(1, 0))
	dummy.current_health = 5000
	var plain: int = stats.get_effective_physical_damage(10)
	Card.play_scope_open = true
	Card.create_by_id("slash").execute(dummy, stats, main.deck_manager, 0.0, 0.0, null)
	Card.close_play_scope(stats)
	_check(5000 - dummy.current_health == floori(plain * 1.5) or 5000 - dummy.current_health == roundi(plain * 1.5),
		"the next offensive card deals 50%% more (%d vs %d plain)" % [5000 - dummy.current_health, plain])
	_check(not stats.has_meta(YariCards.ARMED_META), "and spends it")
	dummy.current_health = 5000
	Card.create_by_id("slash").execute(dummy, stats, main.deck_manager, 0.0, 0.0, null)
	_check(5000 - dummy.current_health == plain, "the one after is back to normal (%d)" % (5000 - dummy.current_health))

	# Whirling Dash through one enemy: 6 to it, no copy.
	var dm = main.deck_manager
	dm.hand.clear()
	dummy.current_health = 5000
	_put(dummy, Vector2i(1, 0))
	dash.execute(main.player, stats, dm, 0.0, 0.0, null)
	var per: int = dash.last_damage_dealt
	_check(per == stats.get_effective_physical_damage(6), "Whirling Dash rolls 6 (scaled %d)" % per)
	var before: Vector3 = main.player.position
	YariCards.world_effects(main, dash, _cell_pos(Vector2i(2, 0)))
	_check(not main.player.position.is_equal_approx(before), "it blinks past the enemy")
	_check(5000 - dummy.current_health == per, "the enemy passed through takes the 6 (%d)" % (5000 - dummy.current_health))
	_check(dm.hand.filter(func(c): return c.card_id == "whirling_dash").is_empty(), "one enemy: no copy")
	# Through two: both are hit and a copy with Erase 1 comes to hand.
	if others.size() >= 2:
		var second = others[0] if others[0] != dummy else others[1]
		dummy.current_health = 5000
		second.current_health = 5000
		_put(dummy, Vector2i(1, 0))
		_put(second, Vector2i(2, 0))
		YariCards.world_effects(main, dash, _cell_pos(Vector2i(3, 0)))
		_check(5000 - dummy.current_health == per and 5000 - second.current_health == per, "two enemies passed through take 6 each")
		var copies: Array = dm.hand.filter(func(c): return c.card_id == "whirling_dash")
		_check(copies.size() == 1 and copies[0].erase_tempo == 1, "more than one: a copy with Erase 1 is added to the hand")
		# Landing on a taken tile is refused.
		var here: Vector3 = main.player.position
		_put(second, Vector2i(2, 0))
		YariCards.world_effects(main, dash, _cell_pos(Vector2i(2, 0)))
		_check(main.player.position.is_equal_approx(here), "it cannot land on an enemy's tile")
	else:
		_check(false, "the dojo has a second dummy for the two-enemy dash")
	inv.equipped_weapons.erase(yari)
	if stats.has_meta(YariCards.ARMED_META):
		stats.remove_meta(YariCards.ARMED_META)

func _done() -> void:
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
