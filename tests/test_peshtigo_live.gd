extends SceneTree

## Peshtigo's Kiss in the live battle scene (the dojo): the flames hit every
## dummy in the INT-sized circle for 10 + 5 per enemy, the player is asked
## whether to maintain, keeping the flames reserves the mana and burns the
## dummies for half every cycle, and dismissing the card puts them out.
## Run: godot --headless --path . --script tests/test_peshtigo_live.gd

var _main: Node = null
var _frames := 0
var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	_main = packed.instantiate()
	_main.set("starting_character", CharacterData.create_brad())
	_main.set("current_interior_id", "dojo")
	get_root().add_child(_main)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 12:
		return false
	_run()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
	return true

func _run() -> void:
	print("=== Peshtigo's Kiss live test ===")
	var stats = _main.player.get_stats()
	var dm = _main.deck_manager
	var enemies: Array = _main.enemy_spawner.get_living_enemies()
	_check(enemies.size() >= 2, "the dojo has dummies to burn (%d)" % enemies.size())
	if enemies.size() < 2:
		return
	stats.base_intelligence = 24  # diameter 3: the target tile and its ring
	stats.max_mana = 200
	stats.current_mana = 200
	_check(is_equal_approx(_main._peshtigo_radius(), 1.5), "INT 24 makes a 3-wide circle")
	_check(_main._flame_cells(Vector2i(10, 10)).size() == 9, "…nine tiles of flame")
	stats.base_intelligence = 4
	_check(_main._flame_cells(Vector2i(10, 10)).size() == 1, "INT below 8 still lights the target tile")
	stats.base_intelligence = 24

	# Two dummies side by side: the circle around the first holds both.
	var a = enemies[0]
	var b = enemies[1]
	var cell_a: Vector2i = _main.grid_manager.world_to_grid(a.position)
	b.position = _main.grid_manager.grid_to_world(cell_a + Vector2i(1, 0))
	b.target_position = b.position
	var hp_a: int = a.current_health
	var hp_b: int = b.current_health

	var card := Card.create_peshtigos_kiss()
	card.execute(a, stats, dm, 0.0, 0.0, _main.player.get_buff_manager())
	dm.discard_pile.append(card)
	_main._apply_card_world_effects(card, a)
	var expected: int = stats.get_effective_spell_damage(10) + 5 * 2
	_check(a.current_health == hp_a - expected and b.current_health == hp_b - expected,
		"both dummies took 10 + 5 per enemy in the flames (%d each)" % expected)
	_check(_main._maintain_prompt != null, "the player is asked whether to maintain the flames")
	_check(_main._flame_zones.is_empty(), "nothing burns until they answer")

	# Say yes: the card is maintained, its mana reserved, the flames stay.
	var yes: Button = null
	for btn in _main._maintain_prompt.find_children("*", "Button", true, false):
		if btn.text == "Maintain":
			yes = btn
	_check(yes != null, "the prompt offers Maintain")
	if yes:
		yes.pressed.emit()
	_check(dm.maintained_cards.has(card) and not dm.discard_pile.has(card), "the card moved to the maintained pile")
	_check(stats.maintained_mana == 60, "…reserving 60 mana")
	_check(_main._flame_zones.size() == 1 and _main._flame_zones[0]["cells"].size() == 9, "nine tiles burn")
	hp_a = a.current_health
	hp_b = b.current_health
	_main._burn_flame_zones()
	var half: int = maxi(1, (stats.get_effective_spell_damage(10) + 10) / 2)
	_check(a.current_health == hp_a - half and b.current_health == hp_b - half, "each cycle the flames burn for half (%d)" % half)

	# Dismiss the card: the flames go out and the mana comes back.
	dm.dismiss_maintained_card(dm.maintained_cards.find(card))
	_check(_main._flame_zones.is_empty(), "dismissing the card puts the flames out")
	_check(stats.maintained_mana == 0, "…and frees the mana")

	# Saying no leaves nothing burning and nothing reserved.
	var card2 := Card.create_peshtigos_kiss()
	card2.execute(a, stats, dm, 0.0, 0.0, _main.player.get_buff_manager())
	dm.discard_pile.append(card2)
	_main._apply_card_world_effects(card2, a)
	var no: Button = null
	for btn in _main._maintain_prompt.find_children("*", "Button", true, false):
		if btn.text != "Maintain":
			no = btn
	if no:
		no.pressed.emit()
	_check(_main._maintain_prompt == null and _main._flame_zones.is_empty() and dm.discard_pile.has(card2),
		"letting the flames go out keeps the card in the discard pile")
