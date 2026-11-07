extends SceneTree

## Phase 2 wiring audit, card slice A (absorb_essence … demonic_rage): each
## card's description checked against what the real play path does, in a
## booted main.tscn (the dojo). A card is played the way a click plays it —
## main.play_selected_card, which charges mana through DeckManager.play_card
## and queues the tempo on the TempoManager — and the ticks are then run one
## by one until it resolves. Every card's printed mana and tempo are checked
## against what that path actually charged.
## Report: docs/audit/wiring/cards_a.md
## Run: godot --headless --path . --script tests/test_wiring_cards_a.gd

var failures := 0
var main = null
var stats: PlayerStats
var dm
var bm: BuffManager
var dbm: DebuffManager
var tm
var gm
var d1: Enemy
var d2: Enemy
var d3: Enemy

const HOME := Vector2i(8, 6)
var _phase := 0  # where in the 5-tempo cycle the next _play starts

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Wiring audit: cards A ===")
	_run()

func _run() -> void:
	# The rules, not the timing: blows land at once (test_hit_wait covers it).
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
	tm = main.tempo_manager
	gm = main.grid_manager
	var dummies: Array = main.enemy_spawner.get_living_enemies()
	_check(dummies.size() >= 2, "the dojo has its two dummies (%d)" % dummies.size())
	d1 = dummies[0]
	d2 = dummies[1]
	d3 = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.DUMMY, main._ground_pos(Vector2i(2, 2)))
	stats.equipment_crit_bonus = -100.0  # exact numbers: no random crits
	_home()

	_test_absorb_essence()
	_test_adimantium_wall()
	_test_adrenaline_shot()
	_test_anticipation()
	_test_approach()
	_test_armor_break()
	_test_armor_patch()
	_test_armored_discipline()
	_test_balance_of_alnilam()
	_test_balistic_arrow()
	_test_barbed_exterior()
	_test_bark_up()
	_test_barricade()
	_test_basic_attack()
	_test_best_offense()
	_test_biscuit()
	_test_blade_barrage()
	_test_blink()
	_test_block()
	_test_bloodlust()
	_test_bob_and_weave()
	_test_bottomless_quiver()
	_test_bouncing_shield()
	_test_braced_draw()
	_test_chain_lightning()
	_test_charge()
	_test_choke()
	_test_cinquedea()
	_test_clang_up()
	_test_clear_mind()
	_test_close_is_favored()
	_test_collect_arrows()
	_test_communal_donation()
	_test_composed_response()
	_test_consecutive_snap()
	await _test_cover()
	_test_crack_of_mintaka()
	_test_crops()
	_test_cryonics()
	_test_cultish_wounds()
	_test_cupids_arrows()
	_test_curse_of_the_living()
	_test_dagger_throw()
	_test_death_vortex()
	_test_deep_breaths()
	_test_deep_pockets()
	_test_defensive_awareness()
	_test_defensive_sacrifice()
	_test_demonic_rage()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

# ------------------------------------------------------------------ helpers

func _cell() -> Vector2i:
	return gm.world_to_grid(main.player.position)

func _home() -> void:
	main.player.position = main._ground_pos(HOME)
	main.player.target_position = main.player.position
	main._player_last_grid_cell = HOME
	# Park the dummies out of every radius until a test calls them in.
	_put(d1, Vector2i(-6, -4))
	_put(d2, Vector2i(-6, 4))
	_put(d3, Vector2i(-7, 0))

func _put(e: Enemy, off: Vector2i) -> void:
	e.position = main._ground_pos(HOME + off)
	e.target_position = e.position

func _reset_dummy(d: Enemy) -> void:
	d.max_health = 1000
	d.current_health = 1000
	d.current_armor = 0
	d.damage_resistances = {}
	d.vulnerable_stacks = 0
	d.weaken_stacks = 0
	d.silenced_tempo = 0
	d.is_silenced = false
	d.choke_dot_stacks = 0
	d.taunt_tempo = 0
	d.taunt_target = null
	d.fear_tempo = 0
	d.fear_source = null
	d.cupid_golden = false
	d.cupid_lead = false
	d.armor_break_incoming = false

## A clean slate before each card: full pools, nothing queued, empty hand.
func _fresh() -> void:
	_drain()
	stats.max_health = 500
	stats.current_health = 500
	stats.current_armor = 0
	stats.max_mana = 1000
	stats.current_mana = 800
	stats.current_temp_mana = 0
	stats.current_attack_counter = 99  # no DEX half-tempo proc mid-test
	dm.next_attack_half_tempo = false
	dbm.clear_all_debuffs()
	main.glut_tempo_remaining = 0
	main.mouse_override = Vector2(-1, -1)
	dm.hand.clear()
	dm.draw_pile.clear()
	for _i in range(12):
		dm.draw_pile.append(Card.create_by_id("heal"))
	_unmaintain_all()
	for d in [d1, d2, d3]:
		_reset_dummy(d)
	_home()

func _unmaintain_all() -> void:
	while dm.maintained_cards.size() > 0:
		dm.dismiss_maintained_card(0)
	main._sync_maintained_passives()

func _drain() -> void:
	var guard := 0
	while tm.is_ticking() and guard < 200:
		tm._process_one_tick()
		guard += 1

func _queued(card: Card) -> bool:
	for e in main._pending_resolve_queue:
		if e["card"] == card:
			return true
	return false

## Play `card` the way a click does. Returns what the play path charged
## (mana, tempo queued) and whether it was played; the card has resolved
## when this returns (its wind-up ticks run), the rest of its tempo has not.
func _play(card: Card, target, extra: Array = []) -> Dictionary:
	dm.hand.clear()
	dm.hand.append(card)
	for c in extra:
		dm.hand.append(c)
	tm.current_tempo = _phase  # by default the next cycle is a full 5 tempo away
	_phase = 0
	var mana0: float = stats.current_mana
	var hp0: int = stats.current_health
	var g0: int = tm.global_tempo
	main.selected_card_index = 0
	main.play_selected_card(target)
	var res := {
		"mana": int(round(mana0 - stats.current_mana)),
		"hp_paid": hp0 - stats.current_health,
		"tempo": tm._pending_ticks if tm.is_ticking() else tm.global_tempo - g0,
		"played": main.selected_card_index == -1 and not (card in dm.hand and card.sticky == 0),
	}
	var guard := 0
	while _queued(card) and guard < 40:
		tm._process_one_tick()
		guard += 1
	return res

func _costs(card_id: String, res: Dictionary, mana: int, tempo: int) -> void:
	_check(res["played"] and res["mana"] == mana and res["tempo"] == tempo,
		"%s: the play path charges %d mana / %d tempo (charged %d / %d)" % [card_id, mana, tempo, res["mana"], res["tempo"]])

func _aim(world: Vector3) -> void:
	main.mouse_override = main.get_world_camera().unproject_position(world)

func _engraved(id: String) -> Card:
	var c := Card.create_by_id(id)
	c.slotted_in_item = ItemData.new()  # a plain slot: engraved, no riders
	return c

func _press(node_name: String, text: String) -> bool:
	var ui = main.get_node_or_null("UI")
	var node = ui.find_child(node_name, true, false) if ui else null
	if node == null:
		return false
	for b in node.find_children("*", "Button", true, false):
		if str(b.text) == text or (text == "" and str(b.text) != "Cancel"):
			node.name = "AnsweredPicker"
			b.pressed.emit()
			return true
	return false

func _phys(base: int) -> int:
	return stats.get_effective_physical_damage(base)

func _spell(base: int) -> int:
	return stats.get_effective_spell_damage(base)

# -------------------------------------------------------------------- cards

func _test_absorb_essence() -> void:
	print("-- Absorb Essence --")
	_fresh()
	var ae := _engraved("absorb_essence")
	var unengraved := Card.create_by_id("absorb_essence")
	dm.hand.append(unengraved)
	main.selected_card_index = 0
	main.play_selected_card(main.player)
	_check(unengraved in dm.hand, "absorb_essence: refused unless engraved into an item")
	_put(d1, Vector2i(3, 0))
	_put(d2, Vector2i(-3, 2))
	var hp1: int = d1.current_health
	var hp2: int = d2.current_health
	var allies: int = main._all_allies().size()
	var summons: int = main._all_summons().size()
	var enemies: int = main.enemy_spawner.get_living_enemies().size()
	_phase = 3  # cast late in a cycle: a cycle-rounded delay would land early
	var res := _play(ae, main.player)
	_costs("absorb_essence", res, 50, 5)
	_check(d1.current_health == hp1 - 1 and d2.current_health == hp2 - 1, "absorb_essence: a flat 1 to every enemy, however far")
	_check(stats.current_health == 499, "absorb_essence: the caster (a thing with health) takes 1 too")
	var pending: Array = main.pending_absorb_essences
	var want: int = enemies + allies + summons + main.barricade_obstacles.size()
	_check(pending.size() == 1 and int(pending[0]["total_damage"]) == want,
		"absorb_essence: the Energy Ball banks every point dealt (%s, want %d)" % [str(pending), want])
	# Delay: 10 tempo on the clock — not rounded to whole 5-tempo cycles.
	for _i in range(8):
		tm.add_tempo(1)
	_check(not dm.hand.any(func(c): return c.card_id == "energy_ball"), "absorb_essence: no Energy Ball before the delay runs out")
	tm.add_tempo(1)
	var ball = null
	for c in dm.hand:
		if c.card_id == "energy_ball":
			ball = c
	_check(ball != null and ball.base_damage == want, "absorb_essence: Delay 10 tempo, then the Energy Ball (damage %d)" % want)
	main.pending_absorb_essences.clear()

func _test_adimantium_wall() -> void:
	print("-- Adimantium Wall --")
	_fresh()
	var aw := Card.create_by_id("adimantium_wall")
	var res := _play(aw, main.player)
	_costs("adimantium_wall", res, 35, 4)
	_check(stats.current_armor == 40, "adimantium_wall: gain 40 block (%d)" % stats.current_armor)
	_check(dm.jail_pile.has(aw) and aw.jail_time_remaining == 40 and not dm.discard_pile.has(aw),
		"adimantium_wall: jailed for 40 tempo after play")
	dm.jail_pile.erase(aw)

func _test_adrenaline_shot() -> void:
	print("-- Adrenaline Shot --")
	_fresh()
	var a := Card.create_by_id("slash")
	var b := Card.create_by_id("block")
	var c := Card.create_by_id("dagger_throw")
	var shot := Card.create_by_id("adrenaline_shot")
	var res := _play(shot, main.player, [a, b, c])
	_costs("adrenaline_shot", res, 30, 0)
	var cuts: Array = [a.temp_hand_tempo_reduction, b.temp_hand_tempo_reduction, c.temp_hand_tempo_reduction]
	_check(cuts.count(3) == 2 and cuts.count(0) == 1, "adrenaline_shot: two cards in the target's hand cost 3 less tempo (%s)" % str(cuts))
	for _i in range(5):
		tm.add_tempo(1)
	var total: int = a.temp_hand_tempo_reduction + b.temp_hand_tempo_reduction + c.temp_hand_tempo_reduction
	_check(total == 6 - 5, "adrenaline_shot: 5 tempo later one card +3 and another +2 (net cut %d)" % total)

func _test_anticipation() -> void:
	print("-- Anticipation --")
	_fresh()
	stats.current_mana = 500
	var pile0: int = dm.draw_pile.filter(func(c): return c.card_id == "prepare").size()
	var res := _play(Card.create_by_id("anticipation"), main.player)
	# 0 tempo: it resolves on the spot, so the pool moved only by the gain.
	_check(res["played"] and res["mana"] == -10 and res["tempo"] == 0, "anticipation: the play path charges 0 mana / 0 tempo (net %d)" % res["mana"])
	_check(int(stats.current_mana) == 510, "anticipation: gain 1 mana (10 on the x10 scale) (%d)" % int(stats.current_mana))
	_check(dm.draw_pile.filter(func(c): return c.card_id == "prepare").size() == pile0 + 1,
		"anticipation: a Prepare is shuffled into the draw pile")

func _test_approach() -> void:
	print("-- Approach --")
	_fresh()
	var res := _play(Card.create_by_id("approach"), main.player)
	_costs("approach", res, 10, 3)
	var slow = dbm.get_debuff(Debuff.DebuffType.SLOWED)
	_check(slow != null and slow.clock_timed and slow.duration == 10 - 1, "approach: Slowed for 10 tempo (the play's own tick spent 1)")
	_drain()
	var armor0: int = stats.current_armor
	# One step east, as the movement pipeline reports it (no cycle crossed,
	# so no armor decay muddies the count).
	tm.current_tempo = 0
	main.player.position = main._ground_pos(HOME + Vector2i(1, 0))
	main._on_player_tile_reached(main.player)
	_check(stats.current_armor == armor0 + 5, "approach: each movement taken grants 5 armor (%d -> %d)" % [armor0, stats.current_armor])
	tm.current_tempo = 0
	main.player.position = main._ground_pos(HOME + Vector2i(2, 0))
	main._on_player_tile_reached(main.player)
	_check(stats.current_armor == armor0 + 10, "approach: a second step, 5 more")
	_drain()
	bm.advance_time(20)
	var armor1: int = stats.current_armor
	tm.current_tempo = 0
	main.player.position = main._ground_pos(HOME + Vector2i(3, 0))
	main._on_player_tile_reached(main.player)
	_drain()
	_check(stats.current_armor == armor1, "approach: once its 10 tempo are over, steps grant nothing")

func _test_armor_break() -> void:
	print("-- Armor Break --")
	_fresh()
	_put(d1, Vector2i(1, 0))
	var res := _play(Card.create_by_id("armor_break"), main.player)
	_costs("armor_break", res, 30, 4)
	_check(bm.has_armor_break(), "armor_break: the next attack is primed")
	_drain()
	d1.current_armor = 100
	var hp0: int = d1.current_health
	var slash := Card.create_by_id("slash")
	var hit: int = _phys(slash.base_damage)
	_play(slash, d1)
	_check(d1.current_armor == 100 - 2 * hit and d1.current_health == hp0,
		"armor_break: the next attack deals double damage to armor only (armor %d, hp %d)" % [d1.current_armor, d1.current_health])
	_check(not bm.has_armor_break(), "armor_break: spent by that attack")
	_drain()
	_reset_dummy(d1)
	_play(Card.create_by_id("armor_break"), main.player)
	_drain()
	_play(Card.create_by_id("slash"), d1)
	_check(d1.current_health == 1000, "armor_break: does nothing to an unarmored enemy")
	_drain()

func _test_armor_patch() -> void:
	print("-- Armor Patch --")
	_fresh()
	dbm.apply_debuff(Debuff.create(Debuff.DebuffType.WEAKENED, 2, -1))
	var patch := Card.create_by_id("armor_patch")
	dm.draw_pile.append(patch)
	dm.draw_card()
	_check(stats.current_armor == 3, "armor_patch: on draw, gain 3 armor (%d)" % stats.current_armor)
	_check(not dbm.has_debuff(Debuff.DebuffType.WEAKENED), "armor_patch: on draw, Cleanse 1")
	_check(not dm.hand.has(patch) and dm.discard_pile.has(patch), "armor_patch: immediately discarded")

func _test_armored_discipline() -> void:
	print("-- Armored Discipline --")
	_fresh()
	var ad := Card.create_by_id("armored_discipline")
	var res := _play(ad, main.player)
	_costs("armored_discipline", res, 30, 3)
	_check(dm.maintained_cards.has(ad) and stats.get_available_max_mana() == 1000 - 50, "armored_discipline: Maintain 5M (50 reserved)")
	stats.current_armor = 0
	var hp0: int = stats.current_health
	stats.take_damage(12, dbm, bm)
	var lost: int = hp0 - stats.current_health
	_check(lost > 0 and stats.current_armor == lost, "armored_discipline: health damage taken becomes that much armor (%d -> %d)" % [lost, stats.current_armor])
	stats.current_armor = 30
	stats.take_damage(10, dbm, bm)
	_check(stats.current_armor == 20, "armored_discipline: a hit armor fully eats grants nothing")
	_unmaintain_all()

func _test_balance_of_alnilam() -> void:
	print("-- Balance of Alnilam --")
	_fresh()
	var cap0: int = dm.get_hand_cap()
	var res := _play(Card.create_by_id("balance_of_alnilam"), main.player)
	_costs("balance_of_alnilam", res, 10, 0)
	_check(dm.hand.size() == mini(6, cap0), "balance_of_alnilam: the only card in hand -> draw 6, up to the hand cap %d (%d)" % [cap0, dm.hand.size()])
	_fresh()
	var other := Card.create_by_id("block")
	_play(Card.create_by_id("balance_of_alnilam"), main.player, [other])
	_check(dm.hand.size() == 1, "balance_of_alnilam: with another card in hand, nothing is drawn")

func _test_balistic_arrow() -> void:
	print("-- Balistic Arrow --")
	_fresh()
	_put(d1, Vector2i(2, 0))
	_put(d2, Vector2i(4, 0))
	_put(d3, Vector2i(2, 2))
	var arrow := Card.create_by_id("balistic_arrow")
	_aim(main._ground_pos(HOME + Vector2i(3, 0)))
	var res := _play(arrow, main.player)
	_costs("balistic_arrow", res, 75, 5)
	var hit: int = _phys(30)
	_check(1000 - d1.current_health == hit and 1000 - d2.current_health == hit,
		"balistic_arrow: 30 damage to the first enemy and through it to the next in line (%d, %d)" % [1000 - d1.current_health, 1000 - d2.current_health])
	_check(d3.current_health == 1000, "balistic_arrow: nothing off the line is hit")

func _test_barbed_exterior() -> void:
	print("-- Barbed Exterior --")
	_fresh()
	var be := Card.create_by_id("barbed_exterior")
	var res := _play(be, main.player)
	_costs("barbed_exterior", res, 20, 4)
	_check(dm.maintained_cards.has(be) and stats.maintained_thorns == 5, "barbed_exterior: maintained, 5 thorns")
	_put(d1, Vector2i(1, 0))
	var hp0: int = d1.current_health
	bm.on_attacked(d1)
	_check(d1.current_health < hp0, "barbed_exterior: an attacker is pricked")
	bm.on_attacked(d1)
	_check(stats.maintained_thorns == 5, "barbed_exterior: non-deteriorating (still 5 after two hits)")
	dbm.clear_all_debuffs()
	bm.remove_buff(Buff.BuffType.THORNS)
	_check(stats.maintained_thorns == 5, "barbed_exterior: non-removable (a buff purge leaves them)")
	_unmaintain_all()
	_check(stats.maintained_thorns == 0, "barbed_exterior: gone when no longer maintained")

func _test_bark_up() -> void:
	print("-- Bark Up --")
	_fresh()
	bm.apply_buff(Buff.create_regen(4, 15, "Test"))
	bm.apply_buff(Buff.create_thorns(6, 15, "Test"))
	var res := _play(Card.create_by_id("bark_up"), main.player)
	_costs("bark_up", res, 45, 3)
	_check(stats.current_armor == 10, "bark_up: every point of Regen (4) and Thorns (6) becomes armor (%d)" % stats.current_armor)
	_check(bm.get_buff(Buff.BuffType.REGEN) == null and bm.get_buff(Buff.BuffType.THORNS) == null, "bark_up: the Regen and Thorns are converted (spent)")

func _test_barricade() -> void:
	print("-- Barricade --")
	_fresh()
	for o in main.barricade_obstacles:
		o["node"].queue_free()
	main.barricade_obstacles.clear()
	_aim(main._ground_pos(HOME + Vector2i(0, -3)))
	var res := _play(Card.create_by_id("barricade"), main.player)
	_costs("barricade", res, 30, 2)
	var cells: Array = []
	for o in main.barricade_obstacles:
		cells.append(gm.world_to_grid(o["position"]))
	cells.sort()
	_check(cells == [HOME + Vector2i(-1, -1), HOME + Vector2i(0, -1), HOME + Vector2i(1, -1)],
		"barricade: a wall 3 tiles wide directly in front of you (%s)" % str(cells))
	_check(cells.size() == 3 and main.player.blocked_tiles.has(HOME + Vector2i(0, -1)), "barricade: the wall blocks movement")
	for o in main.barricade_obstacles:
		o["node"].queue_free()
	main.barricade_obstacles.clear()
	main._sync_blocked_tiles()

func _test_basic_attack() -> void:
	print("-- Basic Attack --")
	_fresh()
	_put(d1, Vector2i(1, 0))
	var ba := Card.create_by_id("basic_attack")
	var res := _play(ba, d1)
	_costs("basic_attack", res, 0, 5)
	_check(1000 - d1.current_health == _phys(10), "basic_attack: 10 damage with your weapon (%d)" % (1000 - d1.current_health))

func _test_best_offense() -> void:
	print("-- Best Offense is a Good Defense --")
	_fresh()
	var res := _play(Card.create_by_id("best_offense"), main.player, [Card.create_by_id("slash")])
	_costs("best_offense", res, 40, 4)
	var smith = bm.get_buff(Buff.BuffType.SMITH)
	_check(smith != null and smith.value == 3, "best_offense: 3 Smith while holding an attack card")
	_check(smith != null and smith.duration >= 24 and smith.duration <= 25, "best_offense: for 25 tempo (%d left)" % (smith.duration if smith else -1))
	bm.remove_buff(Buff.BuffType.SMITH)
	_fresh()
	_play(Card.create_by_id("best_offense"), main.player, [Card.create_by_id("block")])
	smith = bm.get_buff(Buff.BuffType.SMITH)
	_check(smith != null and smith.value == 6, "best_offense: 6 Smith instead when holding no attack card")
	bm.remove_buff(Buff.BuffType.SMITH)

func _test_biscuit() -> void:
	print("-- Biscuit --")
	_fresh()
	stats.current_health = 100
	bm.remove_buff(Buff.BuffType.STRENGTHEN)
	var res := _play(Card.create_by_id("biscuit"), main.player)
	_costs("biscuit", res, 20, 0)
	_check(stats.current_health == stats.max_health, "biscuit: fully heals yourself")
	_check(bm.consume_strengthen() == 3 and bm.consume_strengthen() == 3 and bm.consume_strengthen() == 3 and bm.consume_strengthen() == 0,
		"biscuit: +3 damage for 3 attacks")

func _test_blade_barrage() -> void:
	print("-- Blade Barrage --")
	_fresh()
	_put(d1, Vector2i(1, 0))
	var others := [Card.create_by_id("slash"), Card.create_by_id("dagger_throw"), Card.create_by_id("block"), Card.create_by_id("fireball")]
	var res := _play(Card.create_by_id("blade_barrage"), d1, others)
	_costs("blade_barrage", res, 40, 5)
	_check(1000 - d1.current_health == _phys(20), "blade_barrage: X*10 with X = the attack cards in hand (2; a spell is not one) (%d)" % (1000 - d1.current_health))
	_check(main.glut_tempo_remaining == 15, "blade_barrage: Glut 15 tempo")
	_drain()
	var blocked := Card.create_by_id("block")
	dm.hand.clear()
	dm.hand.append(blocked)
	main.selected_card_index = 0
	main.play_selected_card(main.player)
	_check(dm.hand.has(blocked), "blade_barrage: while glutted no card can be played")
	main.glut_tempo_remaining = 0

func _test_blink() -> void:
	print("-- Blink --")
	_fresh()
	var bl := Card.create_by_id("blink")
	_check(bl.get_effective_range() == 7, "blink: reaches up to 7 spaces (%d)" % bl.get_effective_range())
	var dest: Vector2i = HOME + Vector2i(4, -3)
	_aim(main._ground_pos(dest))
	var res := _play(bl, main.player)
	_costs("blink", res, 20, 1)
	_check(_cell() == dest, "blink: teleports to the chosen point (%s)" % str(_cell()))
	_home()

func _test_block() -> void:
	print("-- Block --")
	_fresh()
	var res := _play(Card.create_by_id("block"), main.player)
	_costs("block", res, 20, 2)
	_check(stats.current_armor == 8, "block: 8 armor (%d)" % stats.current_armor)

func _test_bloodlust() -> void:
	print("-- Bloodlust --")
	_fresh()
	stats.current_mana = 500
	bm.remove_buff(Buff.BuffType.STRENGTHEN)
	var res := _play(Card.create_by_id("bloodlust"), main.player)
	_costs("bloodlust", res, 0, 5)
	var vul = dbm.get_debuff(Debuff.DebuffType.VULNERABLE)
	_check(vul != null and vul.value == 3, "bloodlust: 3 Vulnerable on yourself")
	_check(int(stats.current_mana) == 530, "bloodlust: gain 3 mana (30 on the x10 scale) (%d)" % int(stats.current_mana))
	var st = bm.get_buff(Buff.BuffType.STRENGTHEN)
	_check(st != null and st.value == 3 and st.duration > 0, "bloodlust: 3 Strengthen on a tempo clock")
	bm.advance_time(20)
	_check(bm.get_buff(Buff.BuffType.STRENGTHEN) == null, "bloodlust: the Strengthen ends after 20 tempo")

func _test_bob_and_weave() -> void:
	print("-- Bob and Weave --")
	_fresh()
	var res := _play(Card.create_by_id("bob_and_weave"), main.player)
	_costs("bob_and_weave", res, 20, 1)
	_check(stats.current_armor == 5 and dm.hand.size() == 1, "bob_and_weave: gain 5 armor and draw a card")

func _test_bottomless_quiver() -> void:
	print("-- Bottomless Quiver --")
	_fresh()
	var om = main.overflow_manager
	for e in om.overflow_effects.duplicate():
		om.remove_overflow_effect(e)
	om.manifest_zone.clear()
	var res := _play(Card.create_by_id("bottomless_quiver"), main.player)
	_costs("bottomless_quiver", res, 40, 4)
	var q = om.get_first_effect_of_type(OverflowEffect.OverflowType.QUIVER)
	_check(q != null and q.charges == 5, "bottomless_quiver: Manifest 5 armed")
	# Overflow for real: a full hand, an attack then a non-attack on top.
	dm.hand.clear()
	for _i in range(dm.get_hand_cap()):
		dm.hand.append(Card.create_by_id("block"))
	var spell := Card.create_by_id("fireball")
	var atk := Card.create_by_id("slash")
	dm.draw_pile.append(spell)
	dm.draw_pile.append(atk)
	dm.draw_card()
	dm.draw_card()
	_check(om.manifest_zone.size() == 1 and om.manifest_zone[0]["card"] == atk and int(om.manifest_zone[0]["mana_cost"]) == atk.mana_cost,
		"bottomless_quiver: an overflowing attack is manifested, playable at full cost")
	_check(dm.discard_pile.has(spell), "bottomless_quiver: a non-attack overflow is discarded")
	_check(q.charges == 3, "bottomless_quiver: every overflowed card spends a charge")
	om.remove_overflow_effect(q)
	om.manifest_zone.clear()
	dm.hand.clear()

func _test_bouncing_shield() -> void:
	print("-- Bouncing Shield --")
	_fresh()
	stats.bastion_armor_out = 0
	stats.bastion_flight_tempo = 0
	Card.bastion_shield_in_flight = false
	_put(d1, Vector2i(2, 0))
	_put(d2, Vector2i(5, 0))   # 3 from d1
	_put(d3, Vector2i(5, 6))   # 6 from d2 — out of the 5-square bounce
	stats.current_armor = 20
	var res := _play(Card.create_by_id("bouncing_shield"), d1)
	_costs("bouncing_shield", res, 55, 4)
	_check(1000 - d1.current_health == 5 and 1000 - d2.current_health == 5 and d3.current_health == 1000,
		"bouncing_shield: 5 to each enemy it bounces through, each within 5 of the last")
	_check(stats.current_armor == 10 + 2 * 5, "bouncing_shield: half the armor goes with it; each target returns 5 block (%d)" % stats.current_armor)
	_check(stats.current_temp_mana == 20, "bouncing_shield: 10 temporary mana per target (%d)" % stats.current_temp_mana)
	_check(Card.bastion_shield_in_flight, "bouncing_shield: it is in the air and cannot be thrown again")
	main._update_bastion_return(10)
	_check(not Card.bastion_shield_in_flight and stats.current_armor == 30, "bouncing_shield: after 10 tempo it returns with the armor")
	stats.current_temp_mana = 0

func _test_braced_draw() -> void:
	print("-- Braced Draw --")
	_fresh()
	var res := _play(Card.create_by_id("braced_draw"), main.player)
	_costs("braced_draw", res, 30, 2)
	_check(stats.current_armor == 8 and dm.hand.size() == 1, "braced_draw: 8 armor and draw a card")

func _test_chain_lightning() -> void:
	print("-- Chain Lightning --")
	_fresh()
	_put(d1, Vector2i(3, 0))
	_put(d2, Vector2i(5, 0))
	_put(d3, Vector2i(7, 0))
	var res := _play(Card.create_by_id("chain_lightning"), d1)
	_costs("chain_lightning", res, 50, 8)
	var first: int = _spell(10)
	var hits := [1000 - d1.current_health, 1000 - d2.current_health, 1000 - d3.current_health]
	_check(hits == [first, first - 2, first - 4], "chain_lightning: 10, then -2 per bounce to nearby enemies (%s)" % str(hits))

func _test_charge() -> void:
	print("-- Charge --")
	_fresh()
	_put(d1, Vector2i(2, 0))
	var ch := Card.create_by_id("charge")
	_aim(main._ground_pos(HOME + Vector2i(5, 0)))
	var res := _play(ch, main.player)
	_costs("charge", res, 20, 4)
	_check(1000 - d1.current_health == _phys(8), "charge: 8 damage to the enemy hit, once (%d)" % (1000 - d1.current_health))
	_check(gm.world_to_grid(d1.position).x > HOME.x + 2, "charge: the enemy is knocked back")
	_check(_cell().x > HOME.x, "charge: you charge forward with no target needed")
	_home()

func _test_choke() -> void:
	print("-- Choke --")
	_fresh()
	_put(d1, Vector2i(3, 0))
	var ck := Card.create_by_id("choke")
	var res := _play(ck, d1)
	_costs("choke", res, 30, 4)
	_check(d1.silenced_tempo >= 4 and d1.silenced_tempo <= 5, "choke: Silence for 5 tempo (%d left)" % d1.silenced_tempo)
	_check(d1.choke_dot_stacks == 1 and d1.choke_dot_damage == 2, "choke: 2 damage queued for the next cycle")
	_check(dm.hand.has(ck) and ck.consecutive_uses == 1, "choke: Sticky 3 — back in hand after a use")
	var hp0: int = d1.current_health
	_drain()
	for _i in range(5):
		tm.add_tempo(1)
	_check(hp0 - d1.current_health == 2 and d1.choke_dot_stacks == 0, "choke: the 2 damage lands at the next cycle, once (%d)" % (hp0 - d1.current_health))

func _test_cinquedea() -> void:
	print("-- Cinquedea --")
	_fresh()
	var cq := Card.create_by_id("cinquedea")
	_check(cq.get_effective_range() == 4, "cinquedea: range 4")
	_put(d1, Vector2i(4, 0))
	var res := _play(cq, d1)
	_costs("cinquedea", res, 10, 0)
	_check(1000 - d1.current_health == _phys(6) and d1.weaken_stacks == 1, "cinquedea: 6 damage and 1 Weaken")

func _test_clang_up() -> void:
	print("-- Clang Up --")
	_fresh()
	var res := _play(Card.create_by_id("clang_up"), main.player)
	_costs("clang_up", res, 20, 5)
	_check(stats.current_armor == 10, "clang_up: gain 10 block (%d)" % stats.current_armor)

func _test_clear_mind() -> void:
	print("-- Clear Mind --")
	_fresh()
	dbm.apply_debuff(Debuff.create(Debuff.DebuffType.WEAKENED, 3, -1))
	dbm.apply_debuff(Debuff.create(Debuff.DebuffType.VULNERABLE, 2, -1))
	var res := _play(Card.create_by_id("clear_mind"), main.player)
	_costs("clear_mind", res, 50, 4)
	_check(dbm.debuffs.is_empty(), "clear_mind: purges the debuffs — whole stacks")
	_check(dm.hand.size() == 2, "clear_mind: draws 1 card for each debuff purged (2)")
	_fresh()
	for t in [Debuff.DebuffType.WEAKENED, Debuff.DebuffType.VULNERABLE, Debuff.DebuffType.BURN, Debuff.DebuffType.POISON]:
		dbm.apply_debuff(Debuff.create(t, 2, -1))
	_play(Card.create_by_id("clear_mind"), main.player)
	_check(dbm.debuffs.size() == 1 and dm.hand.size() == 3, "clear_mind: at most 3 are purged")

func _test_close_is_favored() -> void:
	print("-- Close is Favored --")
	_fresh()
	var cf := Card.create_by_id("close_is_favored")
	_check(cf.mana_cost == 0 and cf.tempo_cost == 0 and cf.card_type == Card.CardType.REACTION, "close_is_favored: a free instant")
	dm.hand.append(cf)
	_put(d1, Vector2i(1, 0))
	main._fire_melee_range_reactions(d1)
	_check(1000 - d1.current_health == _phys(13), "close_is_favored: 13 damage to the enemy that came into melee range (%d)" % (1000 - d1.current_health))
	_check(not dm.hand.has(cf) and not dm.discard_pile.has(cf), "close_is_favored: the card is erased")

func _test_collect_arrows() -> void:
	print("-- Collect Arrows --")
	_fresh()
	dm.discard_pile.clear()
	var a1 := Card.create_by_id("slash")
	var a2 := Card.create_by_id("dagger_throw")
	var a3 := Card.create_by_id("exposing_strike")
	var sp := Card.create_by_id("fireball")
	dm.discard_pile.append_array([a1, a2, a3, sp])
	var ca := Card.create_by_id("collect_arrows")
	ca.picked_cards = [a1, a3]
	var res := _play(ca, main.player)
	_costs("collect_arrows", res, 30, 4)
	_check(dm.hand.has(a1) and dm.hand.has(a3) and not dm.hand.has(a2), "collect_arrows: the two chosen attack cards come back to hand")
	_check(main.glut_tempo_remaining == 15, "collect_arrows: Glut 15 tempo")
	_drain()
	main.glut_tempo_remaining = 0
	# Unpicked (the fallback): the two most recent ATTACK cards — a spell is not one.
	_fresh()
	dm.discard_pile.clear()
	var b1 := Card.create_by_id("slash")
	dm.discard_pile.append_array([b1, sp])
	_play(Card.create_by_id("collect_arrows"), main.player)
	_check(dm.hand.has(b1) and not dm.hand.has(sp), "collect_arrows: attack cards only (an offensive spell stays)")
	main.glut_tempo_remaining = 0

func _test_communal_donation() -> void:
	print("-- Communal Donation --")
	_fresh()
	var res := _play(Card.create_by_id("communal_donation"), main.player)
	_costs("communal_donation", res, 30, 3)
	_check(main._donation_active and main._donation_panel.visible, "communal_donation: asks for the amount and its allocation")
	var ally = null
	for entry in main._donation_ally_sliders:
		if entry.get("node") != main.player and is_instance_valid(entry.get("node")):
			ally = entry
	_check(ally != null, "communal_donation: an ally can receive the heal")
	if ally:
		var ally_stats = ally["node"].get_stats()
		ally_stats.current_health = 10
		main._donation_slider.value = 8
		for entry in main._donation_ally_sliders:
			entry["slider"].value = 0
		ally["slider"].value = 8
		stats.current_armor = 50
		main._on_donation_confirmed()
		_check(stats.current_health == 492 and stats.current_armor == 50, "communal_donation: you take the chosen damage, past armor")
		_check(ally_stats.current_health > 10, "communal_donation: the ally is healed from it (%d)" % ally_stats.current_health)
	main._donation_active = false
	main._donation_panel.visible = false

func _test_composed_response() -> void:
	print("-- Composed Response / Whirling Weapon --")
	_fresh()
	var om = main.overflow_manager
	for e in om.overflow_effects.duplicate():
		om.remove_overflow_effect(e)
	var res := _play(Card.create_by_id("composed_response"), main.player)
	_costs("composed_response", res, 30, 2)
	var oc = om.get_first_effect_of_type(OverflowEffect.OverflowType.OVERCHARGE)
	_check(oc != null and oc.charges == 5 and oc.overcharge_effect_id == "composed_reaction", "composed_response: Overflow 5 armed")
	dm.hand.clear()
	for _i in range(dm.get_hand_cap()):
		dm.hand.append(Card.create_by_id("block"))
	var over := Card.create_by_id("slash")
	dm.draw_pile.append(over)
	dm.draw_card()
	var ww = null
	for c in dm.hand:
		if c.card_id == "composed_reaction":
			ww = c
	_check(ww != null and ww.card_name == "Whirling Weapon", "composed_response: an overflow creates a Whirling Weapon in hand")
	_check(oc.charges == 4, "composed_response: each overflow spends one of the five")
	_check(dm.discard_pile.has(over) and not dm.draw_pile.has(over), "composed_response: the overflowed card itself is discarded, not lost from the deck")
	om.remove_overflow_effect(oc)
	# The Whirling Weapon: attacked -> 5 armor and 5 to an enemy in melee range.
	_fresh()
	var w := Card.create_by_id("composed_reaction")
	dm.hand.append(w)
	_put(d1, Vector2i(1, 0))
	stats.take_damage(4, dbm, bm)
	_check(stats.current_armor == 5, "composed_reaction: when you are attacked, gain 5 armor (%d)" % stats.current_armor)
	_check(1000 - d1.current_health == 5, "composed_reaction: and deal 5 to an enemy in melee range")
	_check(not dm.hand.has(w), "composed_reaction: it fires from the hand")
	_fresh()
	var w2 := Card.create_by_id("composed_reaction")
	dm.hand.append(w2)
	stats.take_damage(4, dbm, bm)
	_check(stats.current_armor == 5 and d1.current_health == 1000 and d2.current_health == 1000, "composed_reaction: nothing is dealt when no enemy is in melee range")

func _test_consecutive_snap() -> void:
	print("-- Consecutive Snap --")
	_fresh()
	_put(d1, Vector2i(2, 0))
	var cs := Card.create_by_id("consecutive_snap")
	_check(cs.get_effective_range() == 3, "consecutive_snap: ranged 3")
	var r1 := _play(cs, d1)
	_costs("consecutive_snap", r1, 30, 3)
	_check(1000 - d1.current_health == _phys(3), "consecutive_snap: 3 damage on the first use")
	_check(dm.hand.has(cs), "consecutive_snap: Sticky 3 — it stays in hand")
	_drain()
	_reset_dummy(d1)
	stats.current_mana = 1000
	dm.hand.clear()
	dm.hand.append(cs)
	main.selected_card_index = 0
	var m0: float = stats.current_mana
	main.play_selected_card(d1)
	var t2: int = tm._pending_ticks
	_check(int(m0 - stats.current_mana) == 20 and t2 == 2, "consecutive_snap: each reuse costs -1m/-1t (2nd: %d mana, %d tempo)" % [int(m0 - stats.current_mana), t2])
	while _queued(cs):
		tm._process_one_tick()
	_check(1000 - d1.current_health == _phys(12), "consecutive_snap: each reuse +9 damage (2nd: %d)" % (1000 - d1.current_health))
	_drain()

func _test_cover() -> void:
	print("-- Cover --")
	_fresh()
	var cv := _engraved("cover")
	_check(cv.card_type == Card.CardType.REACTION and cv.requires_engraving, "cover: an engraved instant")
	dm.hand.append(cv)
	dm.hand.append(Card.create_by_id("block"))
	dm.hand.append(Card.create_by_id("block"))
	var g0: int = tm.global_tempo
	stats.take_damage(10, dbm, bm)
	_check(stats.current_health == 500 - 7, "cover: the hit is reduced by the hand size, Cover included (3)")
	await process_frame  # its tempo is charged deferred, once the hit has resolved
	_check(tm.global_tempo - g0 == 2, "cover: costs its 2 tempo (%d)" % (tm.global_tempo - g0))
	_check(dm.discard_pile.has(cv), "cover: fires and is discarded")

func _test_crack_of_mintaka() -> void:
	print("-- Crack of Mintaka --")
	_fresh()
	_put(d1, Vector2i(2, 1))  # 3 squares
	var cm := Card.create_by_id("crack_of_mintaka")
	var fodder := [Card.create_by_id("block"), Card.create_by_id("block"), Card.create_by_id("block"), Card.create_by_id("block")]
	var res := _play(cm, d1, fodder)
	_costs("crack_of_mintaka", res, 30, 4)
	var ui = main.get_node("UI")
	var picker = ui.find_child("HandMultiPicker", true, false)
	_check(picker != null, "crack_of_mintaka: you choose any number of cards to discard")
	if picker:
		var toggles: Array = picker.find_children("*", "Button", true, false).filter(func(b): return b.toggle_mode)
		for i in range(3):
			toggles[i].button_pressed = true
		picker.name = "AnsweredPicker"
		for b in picker.find_children("*", "Button", true, false):
			if b.text == "Done":
				b.pressed.emit()
		_check(dm.discard_pile.filter(func(c): return c in fodder).size() == 3, "crack_of_mintaka: the chosen cards are discarded")
		_check(1000 - d1.current_health == _phys(10), "crack_of_mintaka: 10 damage to an enemy within that many squares (%d)" % (1000 - d1.current_health))
	_fresh()
	_put(d1, Vector2i(2, 1))
	var cm2 := Card.create_by_id("crack_of_mintaka")
	_play(cm2, d1, [Card.create_by_id("block"), Card.create_by_id("block")])
	picker = ui.find_child("HandMultiPicker", true, false)
	if picker:
		var toggles2: Array = picker.find_children("*", "Button", true, false).filter(func(b): return b.toggle_mode)
		toggles2[0].button_pressed = true
		toggles2[1].button_pressed = true
		picker.name = "AnsweredPicker"
		for b in picker.find_children("*", "Button", true, false):
			if b.text == "Done":
				b.pressed.emit()
	_check(d1.current_health == 1000, "crack_of_mintaka: 2 discards do not reach an enemy 3 squares away")
	# The crit bonus: +3% crit damage per card discarded (a sure crit here).
	_fresh()
	_put(d1, Vector2i(2, 1))
	stats.equipment_crit_bonus = 1000.0
	stats.temp_crit_damage_bonus = 0.0
	var plain_crit: int = Card.crit_multiply(_phys(10), stats, d1)
	stats.temp_crit_damage_bonus = 0.12
	var boosted_crit: int = Card.crit_multiply(_phys(10), stats, d1)
	stats.temp_crit_damage_bonus = 0.0
	var cm3 := Card.create_by_id("crack_of_mintaka")
	_play(cm3, d1, [Card.create_by_id("block"), Card.create_by_id("block"), Card.create_by_id("block"), Card.create_by_id("block")])
	picker = ui.find_child("HandMultiPicker", true, false)
	if picker:
		var toggles3: Array = picker.find_children("*", "Button", true, false).filter(func(b): return b.toggle_mode)
		for t in toggles3:
			t.button_pressed = true
		picker.name = "AnsweredPicker"
		for b in picker.find_children("*", "Button", true, false):
			if b.text == "Done":
				b.pressed.emit()
	stats.equipment_crit_bonus = -100.0
	_check(boosted_crit > plain_crit and 1000 - d1.current_health == boosted_crit,
		"crack_of_mintaka: +3%% crit damage per card discarded (4 -> %d, a plain crit %d)" % [1000 - d1.current_health, plain_crit])
	_check(is_equal_approx(stats.temp_crit_damage_bonus, 0.0), "crack_of_mintaka: its crit bonus is only lent for the hit")

func _test_crops() -> void:
	print("-- Crops --")
	_fresh()
	main._clear_berry_bushels()
	var res := _play(Card.create_by_id("crops"), main.player)
	_costs("crops", res, 70, 7)
	var bushels: Array = main._berry_bushels
	var near := bushels.all(func(b): return absi(b["cell"].x - HOME.x) + absi(b["cell"].y - HOME.y) <= 8)
	_check(bushels.size() == 5 and near, "crops: 5 berry bushels within 8 squares (%d)" % bushels.size())
	_drain()
	var cell: Vector2i = bushels[0]["cell"]
	stats.current_health = 100
	stats.current_mana = 100
	main.player.position = main._ground_pos(cell)
	main._check_berry_bushels()
	_check(stats.current_health >= 120 and int(stats.current_mana) == 120, "crops: walking over one eats it for 20 life and 20 mana")
	_check(main._berry_bushels.size() == 4, "crops: that bushel is gone; the rest stay until eaten")
	_drain()
	_check(main._berry_bushels.size() == 4, "crops: bushels do not expire on their own")
	main._clear_berry_bushels()
	_home()
	# Random placement, many times over: always 5, never under a standing ally.
	var ally_cells: Array = main._all_allies().map(func(a): return gm.world_to_grid(a.position))
	var all_ok := true
	for _i in range(12):
		main._clear_berry_bushels()
		main._apply_card_world_effects(Card.create_by_id("crops"), main.player)
		tm.add_tempo(1)  # the per-tempo bushel check runs
		if main._berry_bushels.size() != 5:
			all_ok = false
		for bb in main._berry_bushels:
			if bb["cell"] in ally_cells:
				all_ok = false
	_check(all_ok, "crops: every cast grows 5 bushels, none under an ally standing there")
	main._clear_berry_bushels()

func _test_cryonics() -> void:
	print("-- Cryonics --")
	_fresh()
	stats.current_health = 100
	var res := _play(Card.create_by_id("cryonics"), main.player)
	_costs("cryonics", res, 10, 6)
	_check(main.player.untargetable, "cryonics: the encased ally is untargetable")
	_check(not dbm.can_play_cards(), "cryonics: they cannot act")
	var hp0: int = stats.current_health
	_drain()
	for _i in range(15):
		tm.add_tempo(1)
	_check(stats.current_health >= hp0 + 9, "cryonics: heals 3 health per 5 tempo (%d -> %d)" % [hp0, stats.current_health])
	_check(not main.player.untargetable and dbm.can_play_cards(), "cryonics: after 15 tempo the ice melts")

func _test_cultish_wounds() -> void:
	print("-- Cultish Wounds --")
	_fresh()
	stats.current_armor = 30
	var cw := Card.create_by_id("cultish_wounds")
	var res := _play(cw, main.player)
	_costs("cultish_wounds", res, 20, 2)
	_check(dm.maintained_cards.has(cw) and stats.get_available_max_mana() == 1000 - 20, "cultish_wounds: Maintain 2M (20 reserved)")
	_check(stats.current_health == 499 and stats.current_armor == 30, "cultish_wounds: 1 damage to self, ignoring armor")
	_drain()
	var hp0: int = stats.current_health
	tm.current_tempo = 0
	tm.add_tempo(5)
	_check(stats.current_health == hp0 - 1, "cultish_wounds: repeats every 5 tempo (the cycle)")
	_unmaintain_all()

func _test_cupids_arrows() -> void:
	print("-- Cupid's Golden / Lead arrows --")
	_fresh()
	_put(d1, Vector2i(3, 0))
	var g := Card.create_by_id("cupids_golden_arrow")
	g.rng_selected_index = 0
	g.rng_roll_tempo = tm.global_tempo
	var res := _play(g, d1)
	_costs("cupids_golden_arrow", res, 45, 3)
	_check(1000 - d1.current_health == _phys(10) and d1.vulnerable_stacks == 2, "cupids_golden_arrow: 10 damage and 2 Vulnerable")
	# The resolving tick is the first of the 5.
	_check(d1.taunt_tempo == 4 and d1.taunt_target == main.player, "cupids_golden_arrow: on its 50%, taunted toward you for 5 tempo (%d left)" % d1.taunt_tempo)
	_drain()
	var l := Card.create_by_id("cupids_lead_arrow")
	l.rng_selected_index = -2
	l.rng_roll_tempo = tm.global_tempo
	var w0: int = d1.weaken_stacks
	res = _play(l, d1)
	_costs("cupids_lead_arrow", res, 45, 3)
	_check(d1.weaken_stacks == w0 + 2 and d1.fear_tempo == 0, "cupids_lead_arrow: 2 Weaken; the fear only on its 50%")
	# The resolving tick is the tree's first tempo (one regrowth already in).
	_check(d1.tree_tempo == 3 and d1.tree_regen_ticks == 2, "cupids arrows: carrying both marks turns it into a tree for 4 tempo")
	var hp0: int = d1.current_health
	_drain()
	for _i in range(3):
		tm.add_tempo(1)
	_check(d1.current_health == hp0 + 6 and d1.tree_tempo == 0 and d1.tree_regen_ticks == 0,
		"cupids arrows: the tree regrows 3 health on each of its first 3 tempo, and ends after 4 (+%d after the first)" % (d1.current_health - hp0))
	_reset_dummy(d1)
	var l2 := Card.create_by_id("cupids_lead_arrow")
	l2.rng_selected_index = 0
	l2.rng_roll_tempo = tm.global_tempo
	_play(l2, d1)
	_check(d1.fear_tempo == 4 and d1.fear_source == main.player, "cupids_lead_arrow: on its 50%, fleeing from you for 5 tempo (%d left)" % d1.fear_tempo)
	_drain()

func _test_curse_of_the_living() -> void:
	print("-- Curse of the Living --")
	_fresh()
	var cl := Card.create_by_id("curse_of_the_living")
	var res := _play(cl, main.player)
	_costs("curse_of_the_living", res, 65, 7)
	_check(dm.maintained_cards.has(cl), "curse_of_the_living: maintained")
	_drain()
	var ally = null
	for a in main._all_allies():
		if a != main.player and a.has_method("get_stats"):
			ally = a
	stats.current_health = 100
	if ally:
		ally.get_stats().current_health = 10
	stats.heal(21)
	_check(stats.current_health == 100 + stats.get_effective_heal_amount(11), "curse_of_the_living: every heal you take is halved (21 -> 11)")
	_check(ally != null and ally.get_stats().current_health == 10 + ally.get_stats().get_effective_heal_amount(6),
		"curse_of_the_living: each ally is healed half of what remains, rounded up (6)")
	_unmaintain_all()

func _test_dagger_throw() -> void:
	print("-- Dagger Throw --")
	_fresh()
	var dt := Card.create_by_id("dagger_throw")
	_check(dt.is_ranged and dt.get_effective_range() == 4, "dagger_throw: a ranged throw (4)")
	_put(d1, Vector2i(4, 0))
	var res := _play(dt, d1)
	_costs("dagger_throw", res, 10, 1)
	_check(1000 - d1.current_health == _phys(5), "dagger_throw: 5 damage (%d)" % (1000 - d1.current_health))

func _test_death_vortex() -> void:
	print("-- Death Vortex --")
	_fresh()
	var dv := Card.create_by_id("death_vortex")
	dm.hand.append(dv)
	_put(d1, Vector2i(1, 0))
	_put(d2, Vector2i(0, 1))
	_put(d3, Vector2i(3, 0))
	stats.hit_streak = 0
	for i in range(4):
		stats.take_damage(1, dbm, bm)
	_check(dm.hand.has(dv) and d1.current_health == 1000, "death_vortex: nothing before the 5th hit")
	stats.take_damage(1, dbm, bm)
	_check(1000 - d1.current_health == 15 and 1000 - d2.current_health == 15 and d3.current_health == 1000,
		"death_vortex: after 5 hits, 15 to every adjacent enemy")
	_check(not dm.hand.has(dv) and dm.discard_pile.has(dv), "death_vortex: spent when it spins")
	# A spin that kills climbs back into the hand.
	_fresh()
	var rat: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.MINION, main._ground_pos(HOME + Vector2i(1, 0)))
	rat.chosen_action = {}
	rat.current_armor = 0
	rat.current_health = 10
	var dv2 := Card.create_by_id("death_vortex")
	dm.hand.append(dv2)
	stats.hit_streak = 4
	stats.take_damage(1, dbm, bm)
	_check(rat.is_dead and dm.hand.has(dv2), "death_vortex: if the Vortex kills, it returns to your hand")

func _test_deep_breaths() -> void:
	print("-- Deep Breaths --")
	_fresh()
	stats.current_health = 100
	var res := _play(Card.create_by_id("deep_breaths"), main.player)
	_costs("deep_breaths", res, 30, 4)
	_check(stats.current_health == 100 + stats.get_effective_heal_amount(20), "deep_breaths: heal 20 (through the heal pipeline) (%d)" % stats.current_health)

func _test_deep_pockets() -> void:
	print("-- Deep Pockets --")
	_fresh()
	dm.draw_pile.clear()
	var free1 := Card.create_by_id("anticipation")   # 0 mana
	var free2 := Card.create_by_id("adrenaline_shot")
	free2.mana_cost = 0
	var paid := Card.create_by_id("block")          # 20 mana
	var under := Card.create_by_id("slash")
	dm.draw_pile.append_array([under, paid, free2, free1])  # draws from the back
	var res := _play(Card.create_by_id("deep_pockets"), main.player)
	_costs("deep_pockets", res, 40, 0)
	_check(dm.hand.has(free1) and dm.hand.has(free2) and dm.hand.has(paid) and not dm.hand.has(under),
		"deep_pockets: draws until a card costs more than 0 mana, then stops")

func _test_defensive_awareness() -> void:
	print("-- Defensive Awareness --")
	_fresh()
	_put(d1, Vector2i(1, 0))
	_put(d2, Vector2i(0, 2))
	_put(d3, Vector2i(3, 0))
	var res := _play(Card.create_by_id("defensive_awareness"), main.player)
	_costs("defensive_awareness", res, 30, 2)
	_check(stats.current_armor == 6, "defensive_awareness: 3 armor for each enemy within 2 spaces (2 -> %d)" % stats.current_armor)

func _test_defensive_sacrifice() -> void:
	print("-- Defensive Sacrifice --")
	_fresh()
	_put(d1, Vector2i(1, 0))
	var ds := Card.create_by_id("defensive_sacrifice")
	var fodder := Card.create_by_id("block")
	dm.hand.append(ds)
	dm.hand.append(fodder)
	stats.current_mana = 100
	var took: bool = main.offer_defensive_sacrifice(d1, main.player, 20, dbm, bm, DamageTypes.Type.PHYSICAL)
	_check(took and paused, "defensive_sacrifice: an attack about to land offers the choice")
	_check(_press("DefensiveSacrificePrompt", "") , "defensive_sacrifice: accept")
	# One other card in hand: the picker resolves it at once.
	_check(not paused, "defensive_sacrifice: the battle resumes")
	_check(dm.discard_pile.has(fodder) and stats.current_health == 490, "defensive_sacrifice: discard a card, the damage is halved (20 -> 10)")
	_check(int(stats.current_mana) == 110, "defensive_sacrifice: gain 10 mana")
	_check(not dm.hand.has(ds), "defensive_sacrifice: the instant is spent")
	_fresh()
	var ds2 := Card.create_by_id("defensive_sacrifice")
	dm.hand.append(ds2)
	dm.hand.append(Card.create_by_id("block"))
	main.offer_defensive_sacrifice(d1, main.player, 20, dbm, bm, DamageTypes.Type.PHYSICAL)
	var ui = main.get_node("UI")
	var prompt = ui.find_child("DefensiveSacrificePrompt", true, false)
	var declined := false
	if prompt:
		var btns: Array = prompt.find_children("*", "Button", true, false)
		prompt.name = "AnsweredPicker"
		btns.back().pressed.emit()
		declined = true
	_check(declined and stats.current_health == 480 and dm.hand.has(ds2), "defensive_sacrifice: decline — the full hit lands and the card stays in hand")
	paused = false

func _test_demonic_rage() -> void:
	print("-- Demonic Rage --")
	_fresh()
	bm.remove_buff(Buff.BuffType.DEMONIC_RAGE)
	var res := _play(Card.create_by_id("demonic_rage"), main.player)
	_costs("demonic_rage", res, 50, 5)
	_check(bm.has_demonic_rage() and bm.get_buff(Buff.BuffType.DEMONIC_RAGE).charges == 5, "demonic_rage: 5 uses armed")
	_drain()
	stats.current_armor = 40
	var mana0: float = stats.current_mana
	var r2 := _play(Card.create_by_id("block"), main.player)   # 20 mana
	_check(r2["mana"] == 0 and r2["hp_paid"] == 2, "demonic_rage: the next mana use is paid in health, 1 per mana (2 for 20) (%d hp, %d mana)" % [r2["hp_paid"], r2["mana"]])
	_check(stats.current_armor == 40 + 8, "demonic_rage: armor does not soak the health price")
	_check(bm.get_buff(Buff.BuffType.DEMONIC_RAGE).charges == 4, "demonic_rage: one of the five uses spent")
	_drain()
	_play(Card.create_by_id("anticipation"), main.player)   # 0 mana: no use
	_check(bm.get_buff(Buff.BuffType.DEMONIC_RAGE).charges == 4, "demonic_rage: a free card spends no use")
	bm.remove_buff(Buff.BuffType.DEMONIC_RAGE)
