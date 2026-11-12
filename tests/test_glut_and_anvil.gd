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
	# With the Anvil in hand: +1 per 50 weight carried and +1 per 10 mana above 40, on every wave.
	inv.equipped_weapons.append(anvil)
	stats.current_carry_load = 230
	dummy.current_health = 5000
	var held := Card.create_by_id("crash_from_the_sea")
	held.execute(dummy, stats, main.deck_manager, 0.0, 0.0, null)
	var per_wave: int = stats.get_effective_physical_damage(3 + 4 + 12)
	_check(5000 - dummy.current_health == 4 * per_wave,
		"with the Anvil at 230 weight: +4 for the weight and +12 for 160 mana, on each of the 4 waves (%d, want %d)" % [5000 - dummy.current_health, 4 * per_wave])
	_check(held.bonus_damage == 0, "the bonus does not stick to the card")
	dummy.current_health = 5000
	var cheap := Card.create_by_id("slash")
	cheap.execute(dummy, stats, main.deck_manager, 0.0, 0.0, null)
	_check(5000 - dummy.current_health == stats.get_effective_physical_damage(10 + 4),
		"a 20-mana offensive card gets the weight's +4 and nothing for mana (%d)" % (5000 - dummy.current_health))
	inv.equipped_weapons.erase(anvil)
	_done()

func _done() -> void:
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
