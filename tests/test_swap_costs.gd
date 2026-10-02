extends SceneTree

## Gear changes in combat are meant to sting: every swap or removal costs its
## slot's tempo plus one and half the character's mana, that tempo never
## moves the mana regen countdown, and only Stephen's hands (tempo only) and
## Brad's free War Rack exchange get off lightly.
## Run: godot --headless --path . --script tests/test_swap_costs.gd

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
	print("=== Swap costs test ===")
	var stats = _main.player.get_stats()
	var inv = _main.player.get_inventory()
	var tm = _main.tempo_manager
	var dummies: Array = _main.enemy_spawner.get_living_enemies()
	# Dojo dummies never aggro; give them a range so they count as combat.
	for d in dummies:
		d.aggro_range = 12.0
		d.position = _main.player.position + Vector3(2, 0, 0)
	_check(dummies.size() > 0 and _main._is_in_combat(), "an enemy in aggro range counts as combat")

	# --- Price list ---
	_check(inv.get_swap_tempo_cost(ItemData.ItemType.HELM) == 3 and inv.get_swap_tempo_cost(ItemData.ItemType.CHEST) == 9,
		"swaps cost the slot's base tempo plus one (helm 3, chest 9)")
	_check(inv.get_swap_tempo_cost(ItemData.ItemType.HELM, true) == 2, "removing a helm costs 1 + 1")
	stats.max_mana = 100
	stats.current_mana = 70
	_check(inv.get_swap_mana_cost() == 35, "the mana price is half of what is held (35 of 70)")
	_check(inv.swap_costs_mana(ItemData.ItemType.WEAPON) and inv.swap_costs_mana(-1), "Brad pays mana on every slot and on build switches")

	# --- A paid swap: tempo, mana, and the regen countdown stands still ---
	stats._tempo_until_mana_regen = 4.0
	var g0: int = tm.global_tempo
	_main._on_swap_tempo_spent(3, "Equipped Test Helm", ItemData.ItemType.HELM)
	_check(tm.global_tempo == g0 + 3, "the swap advanced the clock 3 tempo")
	_check(stats.current_mana == 35, "…and took half the mana (70 → %d)" % int(stats.current_mana))
	_check(is_equal_approx(stats._tempo_until_mana_regen, 4.0), "…without moving the mana regen countdown (%.1f)" % stats._tempo_until_mana_regen)
	_check(stats.regen_frozen_tempo == 0, "the frozen tempo was fully consumed by the advance")
	tm.add_tempo(1)
	_check(is_equal_approx(stats._tempo_until_mana_regen, 3.0), "ordinary tempo still counts the regen down")

	# --- Out of combat: free ---
	for d in dummies:
		d.position = _main.player.position + Vector3(60, 0, 60)
	_check(not _main._is_in_combat(), "with the dummies far away there is no combat")
	g0 = tm.global_tempo
	var m0: int = int(stats.current_mana)
	_main._on_swap_tempo_spent(3, "Equipped Test Helm", ItemData.ItemType.HELM)
	_check(tm.global_tempo == g0 and int(stats.current_mana) == m0, "out of combat a swap costs nothing")

	# --- Stephen: hands are cheap and mana-free, armor is not ---
	var s_inv = load("res://scripts/progression/inventory.gd").new()
	get_root().add_child(s_inv)
	s_inv.initialize("Stephen")
	_check(s_inv.get_swap_tempo_cost(ItemData.ItemType.WEAPON) == 2, "Stephen's weapon swap is 1 + 1")
	_check(not s_inv.swap_costs_mana(ItemData.ItemType.WEAPON), "…and costs him no mana")
	_check(s_inv.swap_costs_mana(ItemData.ItemType.CHEST) and s_inv.get_swap_tempo_cost(ItemData.ItemType.CHEST) == 9, "his armor pays full price")

	# --- Brad's free War Rack exchange stays free ---
	_check(inv.has_back_rack, "Brad carries the War Rack")
