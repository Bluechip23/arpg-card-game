extends SceneTree

## Pass-2 open fixes, ITEMS: Axe's Axe, Belthronding, Cupid's Bow, Cyclops
## Ring, Wand of the Phoenix Feather, Wizard Hat — each proved against the
## words of its description, in a booted dojo.
## Run: godot --headless --path . --script tests/test_open_fixes_items.gd

var failures := 0
var main = null
var stats: PlayerStats
var dm
var bm: BuffManager
var dbm: DebuffManager
var inv
var tm
var gm
var d1: Enemy

const HOME := Vector2i(8, 6)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Open fixes: items ===")
	_run()

func _run() -> void:
	TempoManager.preferred_swing_hold = 0
	main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(6):
		await process_frame
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	stats = main.player.get_stats()
	dm = main.deck_manager
	bm = main.player.get_buff_manager()
	dbm = main.player.get_debuff_manager()
	inv = main.player.get_inventory()
	tm = main.tempo_manager
	gm = main.grid_manager
	d1 = main.enemy_spawner.get_living_enemies()[0]
	inv.enforce_mythic_limit = false
	stats.base_strength += 300  # carry room for every weapon below
	stats.base_intelligence += 100
	stats.recalculate_derived_stats()
	stats.equipment_crit_bonus = -100.0  # exact comparisons: no random crits
	_strip()
	_home()

	await _test_axes_axe_kills()
	_test_axes_axe_hits()
	_test_belthronding_specter()
	_test_cupids_bow_blind()
	_test_cyclops_ring()
	_test_phoenix_feather()
	_test_wizard_hat()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

# ------------------------------------------------------------------ helpers

func _home() -> void:
	main.player.position = main._ground_pos(HOME)
	main.player.target_position = main.player.position
	main._player_last_grid_cell = HOME
	_put(d1, Vector2i(-6, -4))

func _put(e: Node3D, off: Vector2i) -> void:
	e.position = main._ground_pos(HOME + off)
	if "target_position" in e:
		e.target_position = e.position

func _drain() -> void:
	var guard := 0
	while tm.is_ticking() and guard < 200:
		tm._process_one_tick()
		guard += 1

func _fresh() -> void:
	_drain()
	stats.max_health = 500
	stats.current_health = 500
	stats.current_armor = 0
	stats.max_mana = 1000
	stats.current_mana = 800
	stats.current_attack_counter = 99
	dbm.clear_all_debuffs()
	bm.remove_buff(Buff.BuffType.STRENGTHEN)
	bm.remove_buff(Buff.BuffType.THORNS)
	main.mouse_override = Vector2(-1, -1)
	dm.hand.clear()
	_reset(d1)
	_home()

func _reset(e: Enemy) -> void:
	e.max_health = 1000
	e.current_health = 1000
	e.current_armor = 0
	e.damage_resistances = {}
	e.vulnerable_stacks = 0
	e.weaken_stacks = 0
	e.cupid_golden = false
	e.cupid_lead = false

func _strip() -> void:
	for arr_name in ["equipped_helms", "equipped_chests", "equipped_rings", "equipped_belts",
			"equipped_boots", "equipped_gauntlets", "equipped_weapons"]:
		var arr: Array = inv.get(arr_name)
		for i in range(arr.size()):
			if arr[i] != null:
				inv.unequip_item(arr[i].item_type, i)

func _equip(id: String, slot: int = 0) -> ItemData:
	var item := ItemData.create(id)
	_check(inv.equip_item(item, slot), "%s equips (%s)" % [id, inv.last_refusal])
	return item

## Play `card` the way a click does and run the ticks until it resolves.
func _play(card: Card, target) -> void:
	dm.hand.clear()
	dm.hand.append(card)
	stats.current_mana = 800
	tm.current_tempo = 0
	main.selected_card_index = 0
	main.play_selected_card(target)
	var guard := 0
	while guard < 40:
		var queued := false
		for e in main._pending_resolve_queue:
			queued = queued or e["card"] == card
		if not queued:
			break
		tm._process_one_tick()
		guard += 1

func _minion(off: Vector2i) -> Enemy:
	var e: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.MINION, main._ground_pos(HOME + off))
	e.chosen_action = {}
	e.current_armor = 0
	e.current_health = 10
	return e

# -------------------------------------------------------------------- tests

func _test_axes_axe_kills() -> void:
	print("-- Axe's Axe: 'Killing an enemy banks 5 flash points' --")
	_fresh()
	var axe := _equip("axes_axe")
	var fp0: int = stats.current_flash_points
	var mine := _minion(Vector2i(4, 4))
	mine.take_damage(50, true)
	_check(mine.is_dead and stats.current_flash_points == fp0 + 5,
		"your kill banks 5 (%d -> %d)" % [fp0, stats.current_flash_points])
	fp0 = stats.current_flash_points
	# Sear Wounds / any enemy's own blow felling its kind: not your kill.
	var theirs := _minion(Vector2i(4, 5))
	theirs.take_damage(50, false)
	_check(theirs.is_dead and stats.current_flash_points == fp0,
		"an enemy felled by another enemy's blow banks nothing (%d)" % stats.current_flash_points)
	# A totem going off by itself (or crumbling with its mage) is no kill either.
	var gone := _minion(Vector2i(5, 4))
	gone.die()
	_check(stats.current_flash_points == fp0, "an enemy that dies by itself banks nothing (%d)" % stats.current_flash_points)
	var totem: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.ICE_TOTEM, main._ground_pos(HOME + Vector2i(-6, 5)))
	totem._totem_ice_tick(999)
	_check(totem.is_dead and stats.current_flash_points == fp0,
		"an Ice Totem fusing itself banks nothing (%d)" % stats.current_flash_points)
	inv.unequip_item(axe.item_type, 0)
	await process_frame

func _test_axes_axe_hits() -> void:
	print("-- Axe's Axe: 'after you are hit 5 times' every Death Vortex fires --")
	_fresh()
	var dv := Card.create_by_id("death_vortex")
	dm.hand.append(dv)
	_put(d1, Vector2i(1, 0))
	stats.hit_streak = 0
	for i in range(5):
		stats.take_damage(1)          # a damage-over-time tick: no attacker
		stats.take_direct_damage(1)   # a cost you pay yourself
	_check(stats.hit_streak == 0 and dm.hand.has(dv),
		"ticks and self-paid costs are not hits (streak %d)" % stats.hit_streak)
	for i in range(4):
		d1._deal_damage_to_player(main.player, 1, "Bite")
	_check(stats.hit_streak == 4 and dm.hand.has(dv), "four enemy blows wind it to 4")
	d1._deal_damage_to_player(main.player, 1, "Bite")
	_check(not dm.hand.has(dv) and d1.current_health == 1000 - 15,
		"the 5th enemy blow spins the Vortex: 15 to the adjacent enemy (%d)" % (1000 - d1.current_health))
	dm.discard_pile.erase(dv)

func _test_belthronding_specter() -> void:
	print("-- Belthronding: an ally's damage within 3 squares — the Seance Specter's death burst too --")
	_fresh()
	var bow := _equip("belthronding")
	_put(d1, Vector2i(2, 1))
	var sp = main._spawn_specter(HOME + Vector2i(1, 1), 20)
	_check(sp != null, "a Specter stands 1 square away")
	var hp0: int = stats.current_health
	sp.last_attacker = d1
	sp.take_damage(999)
	_check(1000 - d1.current_health == 20, "the destroyed Specter deals 20 to its killer (%d)" % (1000 - d1.current_health))
	_check(hp0 - stats.current_health == 2, "you take 10%% of it as well (%d)" % (hp0 - stats.current_health))
	inv.unequip_item(bow.item_type, 0)

func _test_cupids_bow_blind() -> void:
	print("-- Cupid's Bow: 'An enemy struck by both arrows' — a Blind miss strikes nothing --")
	_fresh()
	_put(d1, Vector2i(3, 0))
	seed(4242)
	var missed := false
	for _i in range(20):
		_fresh()
		_put(d1, Vector2i(3, 0))
		d1.cupid_lead = true  # the Lead arrow already struck it
		dbm.apply_debuff(Debuff.create(Debuff.DebuffType.BLIND, 3))
		var golden := Card.create_by_id("cupids_golden_arrow")
		_play(golden, d1)
		if golden.get("blind_missed") == true:
			missed = true
			_check(d1.current_health == 1000, "the blinded arrow misses: no damage")
			_check(d1.vulnerable_stacks == 0, "...no Vulnerable (%d)" % d1.vulnerable_stacks)
			_check(not d1.cupid_golden and d1.tree_tempo <= 0, "...no Golden mark, and no tree")
			_check(Card._exec_depth == 0, "...and the miss leaves no card execution open (%d)" % Card._exec_depth)
			break
	_check(missed, "Blind made the arrow miss within 20 tries")
	# A real strike still lands its riders and completes the pair.
	_fresh()
	_put(d1, Vector2i(3, 0))
	d1.cupid_lead = true
	var hit := Card.create_by_id("cupids_golden_arrow")
	_play(hit, d1)
	_check(hit.get("blind_missed") != true and d1.current_health < 1000, "unblinded, the arrow strikes")
	_check(d1.tree_tempo > 0, "struck by both arrows, it turns into a tree")
	if d1.has_method("_exit_tree_form") and d1.tree_tempo > 0:
		d1._exit_tree_form()
	d1.vulnerable_stacks = 0

func _test_cyclops_ring() -> void:
	print("-- Cyclops Ring: 'the strengthened hits don't feed the counter' --")
	_fresh()
	var ring := _equip("cyclops_ring", 0)
	ring.ring_counters["big_hits"] = 0
	for _i in range(3):
		main._ring_note_big_hit(30)
	var st: Buff = bm.get_buff(Buff.BuffType.STRENGTHEN)
	_check(st != null and st.value == 15 and st.charges == 2, "three 25+ hits: Strengthen 15 for 2 hits")
	# A spell neither spends nor gains Strengthen: its 25+ hit feeds the counter.
	var spell := Card.create_by_id("fireball")
	spell.base_damage = 40
	main.progression_triggers.arm_pre_attack_passives(spell, d1)
	spell.execute(d1, stats, dm, 0.0, 0.0, bm)
	main.progression_triggers.clear_pre_attack_passives()
	main._ring_note_big_hit(spell.last_damage_dealt)
	_check(bm.get_strengthen_bonus() == 15, "the spell left the Strengthen untouched")
	_check(int(ring.ring_counters.get("big_hits", 0)) == 1,
		"the unstrengthened spell hit feeds the counter (%d)" % int(ring.ring_counters.get("big_hits", 0)))
	# The two strengthened attacks sit out.
	for _i in range(2):
		var slash := Card.create_by_id("slash")
		slash.base_damage = 30
		main.progression_triggers.arm_pre_attack_passives(slash, d1)
		slash.execute(d1, stats, dm, 0.0, 0.0, bm)
		main.progression_triggers.clear_pre_attack_passives()
		main._ring_note_big_hit(slash.last_damage_dealt)
	_check(bm.get_strengthen_bonus() == 0, "the two attacks spent the Strengthen")
	_check(int(ring.ring_counters.get("big_hits", 0)) == 1,
		"both strengthened hits stayed out of the counter (%d)" % int(ring.ring_counters.get("big_hits", 0)))
	var after := Card.create_by_id("slash")
	after.base_damage = 30
	main.progression_triggers.arm_pre_attack_passives(after, d1)
	after.execute(d1, stats, dm, 0.0, 0.0, bm)
	main.progression_triggers.clear_pre_attack_passives()
	main._ring_note_big_hit(after.last_damage_dealt)
	_check(int(ring.ring_counters.get("big_hits", 0)) == 2, "the next plain hit counts again")
	inv.unequip_item(ring.item_type, 0)
	bm.remove_buff(Buff.BuffType.STRENGTHEN)

func _player_burn() -> int:
	var b = dbm.get_debuff(Debuff.DebuffType.BURN)
	return b.value if b else 0

func _test_phoenix_feather() -> void:
	print("-- Wand of the Phoenix Feather: 'Applying Burn burns you 1 — once per play' --")
	_fresh()
	var wand := _equip("wand_of_the_phoenix_feather")
	_put(d1, Vector2i(2, 0))
	# An earlier play singed you; the flag is still up.
	main._phoenix_singed_this_play = true
	# Gift from the Phoenix: an instant — its 5 Burn is a play of its own.
	dm.hand.append(Card.create_by_id("gift_from_the_phoenix"))
	stats.current_health = 400
	main._last_hp_ratio = 0.8
	stats.take_direct_damage(200)
	_check(d1.burn_stacks >= 5, "Gift from the Phoenix burned the enemy (%d)" % d1.burn_stacks)
	_check(_player_burn() == 1, "...and the feather singes you 1 (%d)" % _player_burn())
	# A Quiver / Manifest play is a play too: it starts a fresh one.
	_fresh()
	main._phoenix_singed_this_play = true
	var q := Card.create_by_id("slash")
	_put(d1, Vector2i(1, 0))
	main.play_quiver_card(q, -1, d1)
	_check(not main._phoenix_singed_this_play, "a Quiver play opens a fresh play (no stale singe)")
	_drain()
	inv.unequip_item(wand.item_type, 0)

func _test_wizard_hat() -> void:
	print("-- Wizard Hat: 'your next spell card gains +5 spell power' --")
	_fresh()
	_equip("wizard_hat", 0)
	var base: int = stats.get_effective_spell_damage(10)
	for _i in range(3):
		stats.register_attack()
	_check(stats.pending_spell_power_bonus == 5, "the 3rd attack arms +5")
	_check(stats.get_effective_spell_damage(10) == base and stats.get_effective_spell_damage(10) == base,
		"non-card spell damage (zone ticks, Harness Lightning) gets none of it (%d vs %d)" % [stats.get_effective_spell_damage(10), base])
	_check(stats.pending_spell_power_bonus == 5, "...and leaves it armed for the spell card")
	var f0 := Card.create_by_id("fireball")
	stats.pending_spell_power_bonus = 0
	f0.execute(d1, stats, dm, 0.0, 0.0, bm)
	var fb_base: int = f0.last_damage_dealt
	stats.pending_spell_power_bonus = 5
	var f1 := Card.create_by_id("fireball")
	f1.execute(d1, stats, dm, 0.0, 0.0, bm)
	_check(f1.last_damage_dealt == fb_base + 5, "the next spell card deals +5 (%d vs %d)" % [f1.last_damage_dealt, fb_base])
	_check(stats.pending_spell_power_bonus == 0 and stats.get_effective_spell_damage(10) == base,
		"once: spent, and gone from later spell damage (%d)" % stats.get_effective_spell_damage(10))
	var f2 := Card.create_by_id("fireball")
	f2.execute(d1, stats, dm, 0.0, 0.0, bm)
	_check(f2.last_damage_dealt == fb_base, "the spell after it is back to normal (%d)" % f2.last_damage_dealt)
	_strip()
