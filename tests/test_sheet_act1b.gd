extends SceneTree

## Enemy sheet pass, Act 1 slice B (docs/ENEMY_SHEET.tsv): Infected Hunter,
## Spirit Collector, Hydra, Crypt Crawler, Werewolf, Cerberus — the sheet-vs-
## code differences the audit found, checked in a booted main.tscn (the dojo).
##  - Hunter: Cleave hits every player-side unit on the three squares in
##    front; Net Throw applies Weighted = hand size and cools down 8 tempo;
##    Hook starts charged and recharges 8 tempo after each use.
##  - Spirit Collector: Release Soul costs 15 mana / 2 tempo, strengthens
##    every living collector by 5, and the player holds Drain while it is in
##    hand; Strike adds the Strengthen.
##  - Hydra: base 190 HP, 25/25/25 resists, +2 strength on a non-player hit.
##  - Crypt Crawler: Paralysis costs 10 mana / 5 tempo.
##  - Werewolf: the first claw on a NEW target costs the full 5 tempo.
##  - Cerberus: Bite and Venom Tail are Async; the venom aftermath lands when
##    the stun is actually gone.
## Run: godot --headless --path . --script tests/test_sheet_act1b.gd

var failures: int = 0
var main = null

## A summon-like player-side unit (no stats pipeline): counts the hits it takes.
class Bystander extends Node3D:
	var is_dead: bool = false
	var hits: int = 0
	var last_damage: int = 0
	func take_damage(amount: int) -> void:
		hits += 1
		last_damage = amount

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	await _boot()
	if main == null:
		print("=== %d failure(s) ===" % failures)
		quit(1)
		return
	_test_hunter()
	_test_collector()
	_test_hydra()
	_test_crawler()
	_test_werewolf()
	_test_cerberus()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _settle(frames: int = 6) -> void:
	for _i in range(frames):
		await process_frame

func _boot() -> void:
	print("-- Booting main.tscn as the dojo --")
	main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	await _settle()
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	_check(main.player != null and main.enemy_spawner != null, "the dojo is up")
	if main.player == null:
		main = null
		return
	var stats = main.player.get_stats()
	stats.max_health = 500
	stats.current_health = 500
	stats.current_armor = 0

func _player_cell() -> Vector2i:
	return main.grid_manager.world_to_grid(main.player.position)

func _place_player(cell: Vector2i) -> void:
	main.player.position = main._ground_pos(cell)
	main.player.target_position = main.player.position
	if "is_moving" in main.player:
		main.player.is_moving = false

func _spawn(type: int, offset: Vector2i) -> Enemy:
	## An enemy `offset` cells from the player, still and ready.
	var e: Enemy = main.enemy_spawner.spawn_enemy(type, main._ground_pos(_player_cell() + offset))
	e.chosen_action = {}
	return e

func _despawn(e: Enemy) -> void:
	if e and is_instance_valid(e):
		main.enemy_spawner.despawn_enemy(e)

func _hp() -> int:
	return int(main.player.get_stats().current_health)

func _reset_hp() -> void:
	main.player.get_stats().current_health = 500
	main.player.get_stats().current_armor = 0

# ---------------------------------------------------------------- Hunter

func _test_hunter() -> void:
	print("-- Infected Hunter --")
	var dm = main.player.get_debuff_manager()
	dm.clear_all_debuffs()
	var start: Vector2i = _player_cell()
	# The hunter stands one cell east of the player, facing west: its three
	# front squares are the player's cell and the two beside it (north/south).
	var hunter := _spawn(Enemy.EnemyType.INFECTED_HUNTER, Vector2i(1, 0))
	var hcell: Vector2i = main.grid_manager.world_to_grid(hunter.position)
	var names: Array = []
	for a in hunter.actions:
		names.append(str(a["name"]))
	_check(names == ["hook", "cleave", "net_throw", "move"], "action table: hook, cleave, net_throw, move (%s)" % str(names))
	var beside := Bystander.new()
	beside.position = main._ground_pos(hcell + Vector2i(-1, 1))
	var behind := Bystander.new()
	behind.position = main._ground_pos(hcell + Vector2i(1, 0))
	main.add_child(beside)
	main.add_child(behind)
	main.enemy_spawner.summons = [beside, behind]
	_reset_hp()
	hunter._try_cleave(main.player)
	_check(_hp() < 500, "Cleave hits the player in front (%d damage)" % (500 - _hp()))
	_check(beside.hits == 1 and beside.last_damage == hunter.attack_damage, "and the unit beside them on the front row (%d)" % beside.last_damage)
	_check(behind.hits == 0, "but not the unit behind the hunter")
	main.enemy_spawner.summons = []
	beside.queue_free()
	behind.queue_free()

	# Net Throw: Weighted = hand size, then an 8-tempo cooldown.
	var deck = main.deck_manager
	if deck.hand.is_empty():
		deck.draw_card()
	var hand_n: int = deck.hand.size()
	_check(hunter._net_cooldown == 0, "Net Throw starts ready")
	hunter._choose_hunter_action(1)
	_check(str(hunter.chosen_action.get("name", "")) == "net_throw", "in reach and off cooldown the hunter picks Net Throw")
	hunter._try_net_throw(main.player)
	var weighted = dm.get_debuff(Debuff.DebuffType.WEIGHTED)
	_check(hand_n > 0 and weighted != null and weighted.value == hand_n, "Net Throw: Weighted = hand size (%d)" % hand_n)
	_check(dm.get_tempo_increase() == Debuff.WEIGHTED_TEMPO, "every card costs +%d tempo while it holds" % Debuff.WEIGHTED_TEMPO)
	dm.on_card_played(false)
	weighted = dm.get_debuff(Debuff.DebuffType.WEIGHTED)
	_check((hand_n == 1 and weighted == null) or (weighted != null and weighted.value == hand_n - 1), "a card played burns one stack")
	_check(hunter._net_cooldown == 8, "and Net Throw goes on an 8-tempo cooldown")
	hunter._choose_hunter_action(1)
	_check(str(hunter.chosen_action.get("name", "")) == "cleave", "on cooldown, in melee, it cleaves instead")
	hunter._net_cooldown = 3
	hunter.on_tempo_advanced(3, main.player)
	_check(hunter._net_cooldown == 0, "the cooldown runs down on raw tempo")
	dm.clear_all_debuffs()

	# Hook: ready at once, then 8 tempo to recharge.
	_check(hunter._hook_recharge == 0, "Hook starts charged")
	hunter._choose_hunter_action(5)
	_check(str(hunter.chosen_action.get("name", "")) == "hook", "at range 5 a charged hunter hooks")
	_place_player(hcell + Vector2i(-5, 0))
	hunter._try_hook(main.player)
	_check(hunter._hook_recharge == 8, "after a hook it needs 8 tempo to recharge")
	hunter._net_cooldown = 8
	hunter._choose_hunter_action(5)
	_check(str(hunter.chosen_action.get("name", "")) == "move", "uncharged, out of melee, it walks instead")
	_place_player(start)
	_reset_hp()
	_despawn(hunter)

# ------------------------------------------------------------- Collector

func _test_collector() -> void:
	print("-- Spirit Collector --")
	var dm = main.player.get_debuff_manager()
	var stats = main.player.get_stats()
	var deck = main.deck_manager
	dm.clear_all_debuffs()
	var a := _spawn(Enemy.EnemyType.SPIRIT_COLLECTOR, Vector2i(1, 0))
	var b := _spawn(Enemy.EnemyType.SPIRIT_COLLECTOR, Vector2i(0, 2))
	var card: Card = Card.create_release_soul()
	_check(card.mana_cost == 15 and card.tempo_cost == 2, "Release Soul costs 15 mana / 2 tempo")
	_check(card.held_damage_per_cycle == 5 and "1 damage per tempo" in card.description and "15 mana, 2 tempo" in card.description, "its text says what it does")
	deck.add_card_to_hand(card)
	var drain = dm.get_debuff(Debuff.DebuffType.DRAIN)
	_check(drain != null and drain.value == 1, "the player holds Drain (1) while it is in hand")
	main._apply_in_hand_debuffs()
	drain = dm.get_debuff(Debuff.DebuffType.DRAIN)
	_check(drain != null and drain.value == 1, "the cycle pass keeps it at 1, never stacks it")
	# Strike adds the Strengthen it has.
	_reset_hp()
	a._execute_action("collector_swing", main.player)
	var plain: int = 500 - _hp()
	_check(plain == a.attack_damage, "Strike: %d before any soul is released" % plain)
	# Play it: 15 mana, every living collector +5, the Drain lifts.
	stats.max_mana = 100
	stats.current_mana = 100.0
	b.current_health = 0
	b.is_dead = true  # a dead collector drinks nothing
	var idx: int = deck.hand.find(card)
	var res: Dictionary = deck.play_card(idx, main.player, main.player)
	_check(bool(res.get("played", false)) and int(stats.current_mana) == 85, "playing it spends 15 mana")
	_check(a.strengthen_stacks == Card.RELEASE_SOUL_STRENGTHEN, "every living Spirit Collector gains %d Strengthen" % Card.RELEASE_SOUL_STRENGTHEN)
	_check(b.strengthen_stacks == 0, "a dead one does not")
	_check(deck.hand.find(card) < 0 and not (card in deck.discard_pile), "the card is erased")
	_check(dm.get_debuff(Debuff.DebuffType.DRAIN) == null, "and the Drain lifts when it leaves the hand")
	_reset_hp()
	a._execute_action("collector_swing", main.player)
	_check(500 - _hp() == plain + Card.RELEASE_SOUL_STRENGTHEN, "Strike now adds the Strengthen (%d)" % (500 - _hp()))
	_reset_hp()
	a._try_collect_soul(main.player)
	_check(500 - _hp() == plain + Card.RELEASE_SOUL_STRENGTHEN, "so does Collect Soul (%d)" % (500 - _hp()))
	# Collect Soul put a new Release Soul in hand: Drain is back; clear it.
	_check(dm.get_debuff(Debuff.DebuffType.DRAIN) != null, "Collect Soul's new card brings the Drain back")
	for i in range(deck.hand.size() - 1, -1, -1):
		if deck.hand[i].card_id == "release_soul":
			deck.hand.remove_at(i)
	deck.hand_updated.emit()
	_check(dm.get_debuff(Debuff.DebuffType.DRAIN) == null, "gone again once no Release Soul is held")
	# A Drain from elsewhere is not ours to lift.
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.DRAIN, 3, 15))
	deck.hand_updated.emit()
	_check(dm.get_debuff(Debuff.DebuffType.DRAIN) != null, "a Drain from another source is left alone")
	dm.clear_all_debuffs()
	_reset_hp()
	_despawn(a)
	_despawn(b)

# ----------------------------------------------------------------- Hydra

func _test_hydra() -> void:
	print("-- Hydra --")
	var h := _spawn(Enemy.EnemyType.HYDRA, Vector2i(2, 0))
	var pps: Dictionary = Enemy.passive_power_scale(h.get_intended_level())
	_check(h.max_health == roundi(190 * pps["hp"]), "base 190 HP (sheet; x%.2f band = %d)" % [pps["hp"], h.max_health])
	_check(h.damage_resistances.get(DamageTypes.Type.PHYSICAL, 0) == 25 and h.damage_resistances.get(DamageTypes.Type.FIRE, 0) == 25 and h.damage_resistances.get(DamageTypes.Type.LIGHTNING, 0) == 25, "resists 25 / 25 / 25")
	var comp: Dictionary = Enemy.get_all_enemy_data()[Enemy.EnemyType.HYDRA]
	_check(int(comp["health"]) == roundi(190 * pps["hp"]), "the compendium agrees (%d)" % int(comp["health"]))
	var s0: int = h.strength
	h.take_damage(5, false)
	_check(h.strength == s0 + 2 and h.hits_taken == 1, "+2 strength on a hit that is not the player's")
	h.take_damage(0, false)
	_check(h.strength == s0 + 2, "a hit for nothing does not count")
	h.take_damage(5, true)
	_check(h.strength == s0 + 4 and h.hits_taken == 2, "and on the player's")
	_despawn(h)

# --------------------------------------------------------------- Crawler

func _test_crawler() -> void:
	print("-- Crypt Crawler --")
	var p: Card = Card.create_paralysis()
	_check(p.mana_cost == 10 and p.tempo_cost == 5, "Paralysis costs 10 mana / 5 tempo")
	_check("10 mana, 5 tempo" in p.description, "and says so")

# -------------------------------------------------------------- Werewolf

func _test_werewolf() -> void:
	print("-- Werewolf --")
	_reset_hp()
	var w := _spawn(Enemy.EnemyType.WEREWOLF, Vector2i(1, 0))
	w._choose_werewolf_action(1, main.player)
	_check(int(w.chosen_action.get("tempo_cost", 0)) == 5, "first claw on the player: 5 tempo")
	w._try_werewolf_claw(main.player)
	w._try_werewolf_claw(main.player)
	w._choose_werewolf_action(1, main.player)
	_check(int(w.chosen_action.get("tempo_cost", 0)) == 3, "third claw on the same target: 3 tempo")
	var other := Node3D.new()
	main.add_child(other)
	other.position = w.position + Vector3(1, 0, 0)
	w._choose_werewolf_action(1, other)
	_check(int(w.chosen_action.get("tempo_cost", 0)) == 5 and w._ww_streak == 0, "the first claw on a NEW target takes the full 5 again")
	other.queue_free()
	_reset_hp()
	_despawn(w)

# -------------------------------------------------------------- Cerberus

func _test_cerberus() -> void:
	print("-- Cerberus --")
	var kinds := {}
	for a in Enemy.actions_for_type(Enemy.EnemyType.CERBERUS):
		kinds[str(a["name"])] = Enemy.is_async_action(a)
	_check(kinds.get("cerberus_bite", false) and kinds.get("venom_tail", false), "Bite and Venom Tail are Async")
	_check(not kinds.get("swipe", true) and not kinds.get("cerberus_roar", true) and not kinds.get("move", true), "Swipe, Roar and Move stay Sync")
	var dm = main.player.get_debuff_manager()
	dm.clear_all_debuffs()
	_reset_hp()
	var dog := _spawn(Enemy.EnemyType.CERBERUS, Vector2i(1, 0))
	var picked := {}
	for _i in range(40):
		dog._choose_cerberus_action(1)
		picked[str(dog.chosen_action.get("name", ""))] = true
	for _i in range(40):
		dog._choose_cerberus_action(4)
		picked[str(dog.chosen_action.get("name", ""))] = true
	_check(not picked.has("cerberus_bite") and not picked.has("venom_tail"), "the Sync clock never carries Bite or Venom Tail (%s)" % str(picked.keys()))
	# An Async bite that comes up out of reach is spent: no walking.
	var far: Vector2i = _player_cell() + Vector2i(4, 0)
	dog.position = main._ground_pos(far)
	var before: Vector3 = dog.position
	var landed: bool = dog._try_cerberus_bite(main.player)
	_check(not landed and dog.position == before and not dog.is_moving, "a bite out of reach is spent, not turned into a move")
	dog.position = main._ground_pos(_player_cell() + Vector2i(1, 0))
	# Venom aftermath: lands the moment the stun is gone, not on a fixed clock.
	var hand0: int = main.deck_manager.hand.size()
	dog._try_venom_tail(main.player)
	_check(main.deck_manager.hand.size() == maxi(0, hand0 - 3), "Venom Tail knocks 3 cards from the hand")
	_check(dm.has_debuff(Debuff.DebuffType.STUN) and dog._venom_countdown == 15, "and stuns for 15 tempo")
	dog._tick_venom(1)
	_check(dog._venom_countdown == 14 and not dm.has_debuff(Debuff.DebuffType.VULNERABLE), "while the stun holds nothing follows")
	dm.remove_debuff(Debuff.DebuffType.STUN)  # cleansed early
	dog._tick_venom(1)
	var vuln = dm.get_debuff(Debuff.DebuffType.VULNERABLE)
	_check(vuln != null and vuln.value == 2 and dm.has_debuff(Debuff.DebuffType.CUFFED) and dog._venom_countdown == 0, "the moment the stun is gone: 2 Vulnerable and Cuffed")
	dm.clear_all_debuffs()
	# The 15-tempo countdown is still the upper bound (a stun that never landed).
	dog._venom_countdown = 15
	dog._venom_victim = main.player
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.STUN, 0, 60))
	dog._tick_venom(15)
	_check(dm.has_debuff(Debuff.DebuffType.VULNERABLE) and dog._venom_countdown == 0, "after 15 tempo it lands regardless")
	dm.clear_all_debuffs()
	_reset_hp()
	_despawn(dog)
