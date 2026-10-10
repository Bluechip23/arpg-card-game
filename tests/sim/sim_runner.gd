class_name SimRunner
extends RefCounted

## Runs one combat through the real game (main.tscn booted headlessly, the
## way the live tests do) under a seeded RNG with a SimPolicy choosing the
## player's actions, and records one CSV row per decision point. See
## docs/sim/README.md and docs/sim/audit.md for the design.
##
## Time is driven from here, never from the wall clock: card ticks come from
## TempoManager._process_one_tick(), unit movement is snap-stepped through the
## real per-tile arrival code, and the only frames pumped are one per
## decision (to flush call_deferred) and a few around boot / teardown.

const MAIN_SCENE := "res://scenes/core/main.tscn"
const INTERIOR_DEFAULT := "dojo"

const ROW_COLUMNS := ["bar_index", "tempo_before", "tempo_after", "actor", "action_id", "target",
	"player_hp", "player_armor", "player_temp_hp", "player_mana", "hand_size",
	"enemy_id", "enemy_hp", "enemy_pos", "player_pos", "distance",
	"damage_dealt", "damage_taken", "buffs_applied", "debuffs_applied", "rng_outcome_used"]
const SUMMARY_COLUMNS := ["seed", "outcome", "bars_elapsed", "total_damage_dealt", "total_damage_taken",
	"damage_per_tempo", "cards_played", "distinct_cards_played", "card_entropy", "mana_wasted",
	"overflow_bars", "end_hp_pct", "enemy_actions_by_type", "global_tempo", "decisions", "error", "warnings"]
const AGGREGATE_STATS := ["mean", "std", "min", "max"]

var tree: SceneTree
var verbose := false
var main: Node = null
var scenario: Dictionary = {}
var policy: SimPolicy = null
var seed_value: int = 0
var rows: Array = []
var outcome := ""
var error_msg := ""
var warnings: Array = []

var _packed: PackedScene
var _row: Dictionary = {}          # the row damage / status events attribute to
var _player_row: Dictionary = {}
var _open_enemy_rows: Array = []
var _settling := false
var _total_dealt := 0
var _total_taken := 0
var _card_counts := {}
var _enemy_action_counts := {}
var _mana_seen := 0.0
var _mana_delta := 0.0
var _mana_wasted := 0
var _overflow_bars := 0
var _decisions := 0
var _refusals := 0
var _aims := {}                    # Card instance id -> aim world position

func _init(p_tree: SceneTree) -> void:
	tree = p_tree
	_packed = load(MAIN_SCENE)

# ---------------------------------------------------------------- run ----

## Boot, play, tear down. Returns the summary row (see SUMMARY_COLUMNS).
func run(sc: Dictionary, pol: SimPolicy, p_seed: int) -> Dictionary:
	scenario = sc
	policy = pol
	seed_value = p_seed
	rows.clear()
	warnings.clear()
	outcome = ""
	error_msg = ""
	_reset_counters()
	policy.setup(sc)

	seed(seed_value)
	await _boot()
	_build_player()
	_spawn_enemies()
	_hook_signals()
	seed(seed_value)  # the combat stream starts here, whatever the boot consumed

	_log("run start: %s / %s / seed %d" % [sc["name"], policy.name, seed_value])
	var max_tempo: int = int(sc["max_bars"]) * main.tempo_manager.tempo_threshold
	while outcome == "":
		_check_end()
		if outcome != "":
			break
		if main.tempo_manager.global_tempo >= max_tempo:
			outcome = "timeout"
			break
		if _decisions >= 10000:
			outcome = "timeout"
			error_msg = "decision cap"
			break
		var state := SimState.new(main)
		var action = policy.choose_action(state)
		if action == null or not (action is Dictionary):
			outcome = "error"
			error_msg = "policy returned no action"
			break
		if action.has("illegal"):
			outcome = "error"
			error_msg = str(action["illegal"])
			break
		var ok := _apply_action(action, state)
		_decisions += 1
		if not ok:
			if policy.name == "scripted":
				outcome = "error"
				error_msg = "illegal action %s: %s" % [SimPolicy.action_label(action), str(_player_row.get("refused", ""))]
				break
			_refusals += 1
			if _refusals >= 3:
				# A policy that keeps picking refused actions idles a tempo
				# so the run cannot spin forever.
				_refusals = 0
				_apply_action({"type": "wait", "forced": true}, state)
		else:
			_refusals = 0
		# One frame: flushes call_deferred (Cover's tempo) and queued frees.
		await tree.process_frame
		_settle_all()
		_answer_prompts()
	_check_end()
	var summary := _summary()
	_log("run end: %s after %d tempo (%d rows)" % [outcome, main.tempo_manager.global_tempo, rows.size()])
	await _teardown()
	return summary

# --------------------------------------------------------------- boot ----

func _boot() -> void:
	var p: Dictionary = scenario["player"]
	var cd: CharacterData = (CharacterData as Script).call("create_%s" % p["character"])
	for tid in SimScenario.TUTORIAL_IDS_SEEN:
		if not cd.seen_tutorial_ids.has(tid):
			cd.seen_tutorial_ids.append(tid)
	main = _packed.instantiate()
	main.set("starting_character", cd)
	main.set("current_interior_id", str(scenario["map"].get("interior", INTERIOR_DEFAULT)))
	tree.get_root().add_child(main)
	await tree.process_frame
	await tree.process_frame
	# Nothing below runs on the wall clock any more.
	main.set_process(false)
	main.tempo_manager.set_process(false)
	main.player.set_physics_process(false)
	if main.olorin:
		while main.olorin.is_busy():
			main.olorin._close()
	tree.paused = false
	# The dojo's practice targets make way for the scenario's enemies.
	var sp = main.enemy_spawner
	for e in sp.enemies.duplicate():
		sp.enemies.erase(e)
		if is_instance_valid(e):
			e.queue_free()
	if "_dojo_allies" in main:
		for a in main._dojo_allies:
			if is_instance_valid(a):
				a.queue_free()
		main._dojo_allies.clear()
	await tree.process_frame

func _build_player() -> void:
	var p: Dictionary = scenario["player"]
	var player = main.player
	var stats = player.get_stats()
	for i in range(int(p["level"]) - 1):
		stats._level_up()
	var alloc: Dictionary = p["allocation"]
	if not alloc.is_empty() and not stats.apply_stat_allocation(alloc):
		warnings.append("stat allocation refused: %s (banked %d)" % [str(alloc), stats.unspent_stat_points])
	# Passives: a list means rank 1 each (the effect turns on at rank 1); a
	# Dictionary {id: rank} spends banked passive points through the real
	# allocator, so a build cannot carry more ranks than its level banks.
	var passives = p["passives"]
	if passives is Dictionary:
		for pid in passives:
			for i in range(int(passives[pid])):
				if not stats.allocate_passive_point(str(pid)):
					warnings.append("passive rank refused: %s rank %d (%d point(s) banked)" % [str(pid), i + 1, stats.unspent_passive_points])
					break
	else:
		for pid in passives:
			stats.add_skill_tree_passive(str(pid))
	_unlock_sphere_targets(p.get("sphere_targets", []))
	var inv = player.get_inventory()
	var equipped := {}
	for entry in p["items"]:
		var id: String = str(entry[0] if entry is Array else entry)
		var slot: int = int(entry[1]) if (entry is Array and entry.size() > 1) else 0
		var item: ItemData = (ItemData as Script).call("create_%s" % id)
		if inv.equip_item(item, slot):
			equipped[id] = item
		else:
			warnings.append("equip refused: %s (slot %d, carry %d/%d)" % [id, slot, stats.current_carry_load, stats.get_carry_capacity()])
	# Cards engraved into the items' slots: {item id: [card ids]}. Real slot
	# rules (count, label, feral colour) apply; a slotted card rides the item
	# and does not count toward the deck cap.
	var slotted: Dictionary = p.get("slotted", {})
	for item_id in slotted:
		if not equipped.has(item_id):
			warnings.append("slotted: %s is not equipped" % str(item_id))
			continue
		for cid in slotted[item_id]:
			var card = main.deck_manager._create_card_from_id(str(cid))
			if card == null:
				warnings.append("slotted: unknown card '%s'" % str(cid))
			elif equipped[item_id].slot_card(card):
				main.deck_manager.draw_pile.append(card)
			else:
				warnings.append("slotted: %s refused %s (%d/%d slots, needs %s)" % [str(item_id), str(cid),
					equipped[item_id].slotted_cards.size(), equipped[item_id].card_slots, str(equipped[item_id].allowed_card_keywords)])
	for k in p["stat_overrides"]:
		stats.set(k, p["stat_overrides"][k])
	_build_deck(p["deck"])
	stats.current_health = stats.max_health
	stats.current_mana = float(stats.get_available_max_mana())
	stats.health_changed.emit(stats.current_health, stats.max_health)
	stats.mana_changed.emit(stats.current_mana, stats.max_mana)
	main.draw_timer.initialize(stats, main.deck_manager)
	main.tempo_manager.initialize(stats)
	main.tempo_manager.tempo_threshold = int(scenario["tempo_threshold"])
	var cell := SimScenario.cell_of(p["cell"])
	_place(player, cell)
	main._player_last_grid_cell = cell
	for ob in scenario["map"]["obstacles"]:
		player.blocked_tiles.append(SimScenario.cell_of(ob))

## Sphere grid: walk the shortest unlockable path from what is already lit
## to each target node (in order), lighting every node on the way through
## the real unlock + effect code. Stat gates and the keystone cap are
## honoured; a target that cannot be reached is a warning.
func _unlock_sphere_targets(targets: Array) -> void:
	if targets.is_empty():
		return
	var grid = main.sphere_grid_ui.sphere_grid
	var stats = main.player.get_stats()
	var lit := 0
	for target in targets:
		var tid := int(target)
		var goal = grid.get_node_by_id(tid)
		if goal == null:
			warnings.append("sphere: no node %d" % tid)
			continue
		if goal.unlocked:
			continue
		# BFS from every unlocked node over nodes whose gate the character meets.
		var came_from := {}
		var frontier: Array = []
		for n in grid.get_all_nodes():
			if n.unlocked:
				frontier.append(n.id)
				came_from[n.id] = -1
		var found := false
		while not frontier.is_empty() and not found:
			var cur: int = frontier.pop_front()
			for nb in grid.get_connections_for(cur):
				if came_from.has(nb):
					continue
				var node = grid.get_node_by_id(nb)
				if node == null or not SphereGrid.requirements_met(node, stats):
					continue
				if node.node_type == SphereGrid.NodeType.KEYSTONE and nb != tid:
					continue  # never spend a keystone slot on the way to another
				came_from[nb] = cur
				if nb == tid:
					found = true
					break
				frontier.append(nb)
		if not found:
			warnings.append("sphere: no unlockable path to %d (%s) — gate %s" % [tid, goal.label, str(goal.requirements)])
			continue
		var path: Array = []
		var at := tid
		while at != -1 and came_from.get(at, -1) != -1:
			path.push_front(at)
			at = came_from[at]
		for nid in path:
			if not grid.unlock_node(nid):
				warnings.append("sphere: unlock refused at %d (%s)" % [nid, grid.get_node_by_id(nid).label])
				break
			main.progression_triggers._on_sphere_grid_node_unlocked(nid)
			lit += 1
	grid.check_constellation_completion()
	_log("sphere grid: %d node(s) lit for targets %s" % [lit, str(targets)])

## The scenario's deck replaces the character's own; cards an equipped item
## owns (granted or slotted) ride along, exactly as in play.
func _build_deck(ids: Array) -> void:
	var dm = main.deck_manager
	var item_cards: Array = []
	for pile in [dm.hand, dm.draw_pile, dm.discard_pile, dm.jail_pile, dm.maintained_cards]:
		for c in pile:
			if c.granted_by_item != null or c.slotted_in_item != null:
				item_cards.append(c)
	dm.hand.clear()
	dm.draw_pile.clear()
	dm.discard_pile.clear()
	dm.jail_pile.clear()
	dm.maintained_cards.clear()
	dm.peaked_card = null
	dm.reserved_draw_slots = 0
	for id in ids:
		if not dm.can_add_copy(str(id)):
			warnings.append("deck: copy cap reached for '%s'" % str(id))
			continue
		var c = dm._create_card_from_id(str(id))
		if c:
			dm.draw_pile.append(c)
		else:
			warnings.append("unknown card '%s'" % str(id))
	if dm.get_deck_size() > DeckManager.MAX_DECK_SIZE:
		warnings.append("deck: %d base cards over the cap of %d" % [dm.get_deck_size(), DeckManager.MAX_DECK_SIZE])
	for c in item_cards:
		dm.draw_pile.append(c)
	dm.shuffle_draw_pile()
	# Spotlight cards go on top of the shuffled pile so the opening hand
	# holds them (draw_card pops from the back).
	var spot: Array = scenario["player"].get("opening_hand", [])
	for id in spot:
		for i in range(dm.draw_pile.size()):
			if dm.draw_pile[i].card_id == str(id):
				var c = dm.draw_pile[i]
				dm.draw_pile.remove_at(i)
				dm.draw_pile.append(c)
				break
	for i in range(mini(dm.get_hand_cap(), dm.draw_pile.size())):
		dm.draw_card()
	dm.hand_updated.emit()

func _place(unit: Node3D, cell: Vector2i) -> void:
	var world: Vector3 = main.grid_manager.grid_to_world(cell)
	if main.dungeon_manager:
		world.y = main.dungeon_manager.get_elevation_world_y(cell)
	unit.position = world
	unit.target_position = world

func _spawn_enemies() -> void:
	for e in scenario["enemies"]:
		var type: int = Enemy.EnemyType[str(e["type"])]
		var cell := SimScenario.cell_of(e["cell"])
		var world: Vector3 = main.grid_manager.grid_to_world(cell)
		if main.dungeon_manager:
			world.y = main.dungeon_manager.get_elevation_world_y(cell)
		var en = main.enemy_spawner.spawn_enemy(type, world)
		var ov: Dictionary = e["overrides"]
		for k in ov:
			en.set(k, ov[k])
		if ov.has("max_health") and not ov.has("current_health"):
			en.current_health = en.max_health
		en.update_health_display()
		if bool(scenario.get("auto_range", false)):
			# A sweep-spawned enemy: three tiles off for melee, its own reach
			# for ranged (capped at 6 so it stays inside the hall).
			var reach: int = int(en.attack_range)
			var dist: int = 3 if reach <= 1 else clampi(reach, 3, 6)
			var pc := SimScenario.cell_of(scenario["player"]["cell"])
			_place(en, Vector2i(pc.x + dist, cell.y))
		_adopt_enemy(en)
	main._sync_dungeon_blocked_tiles()
	for ob in scenario["map"]["obstacles"]:
		for en in main.enemy_spawner.get_living_enemies():
			en.blocked_tiles.append(SimScenario.cell_of(ob))
	main._sync_occupied_tiles()
	main._update_enemy_count()
	main._refresh_unit_tracker()

func _adopt_enemy(en) -> void:
	en.set_physics_process(false)
	en.action_fired.connect(_on_enemy_action_fired)
	en.damaged.connect(_on_enemy_damaged.bind(en))
	en.debuff_applied.connect(_on_enemy_debuff_applied)

func _hook_signals() -> void:
	var stats = main.player.get_stats()
	stats.damage_taken.connect(_on_player_damage_taken)
	stats.mana_changed.connect(_on_player_mana_changed)
	stats.mana_gained.connect(_on_player_mana_gained)
	_mana_seen = stats.current_mana
	main.player.get_buff_manager().buff_applied.connect(_on_player_buff_applied)
	main.player.get_debuff_manager().debuff_applied.connect(_on_player_debuff_applied)
	main.tempo_manager.tempo_advanced.connect(_on_tempo_advanced)
	main.tempo_manager.tempo_threshold_reached.connect(_on_threshold_reached)
	main.enemy_spawner.enemy_spawned.connect(_adopt_enemy)

func _teardown() -> void:
	if main and is_instance_valid(main):
		main.queue_free()
	main = null
	# Statics the scene sets; a fresh Main sets them again on boot.
	Card.active_element_remap = ""
	Card.element_pollination_active = false
	Card.play_scope_open = false
	PlayerStats.harnessed_mult = 1.0
	PlayerStats.hit_source_offensive = false
	PlayerStats.hit_source_direct = false
	PlayerStats.ally_heal_caster = null
	await tree.process_frame
	await tree.process_frame

# ------------------------------------------------------------ actions ----

func _apply_action(a: Dictionary, state: SimState) -> bool:
	var label := SimPolicy.action_label(a)
	var row := _new_row("player", label, str(a.get("target", "")))
	rows.append(row)
	_player_row = row
	_row = row
	var ok := false
	match str(a.get("type", "")):
		"play":
			ok = _do_play(a, state, row)
		"attack":
			ok = _do_attack(a, state, row)
		"block":
			ok = _do_block(row)
		"wait":
			main._on_wait_pressed()
			ok = true
		"move":
			ok = _do_move(a, row)
		_:
			row["refused"] = "unknown action type"
	if ok:
		_tick_until_free()
	else:
		rows.erase(row)
	_settle_all()
	_answer_prompts()
	_finish_row(row)
	if verbose:
		print("[SIM] %s -> %s (tempo %d->%d, dealt %d, taken %d)" % [label, "ok" if ok else "refused: " + str(row.get("refused", "")),
			row["tempo_before"], row["tempo_after"], row["damage_dealt"], row["damage_taken"]])
	return ok

func _resolve_target(spec: String, state: SimState):
	if spec.begins_with("enemy:"):
		return state.enemy_node(int(spec.substr(6)))
	if spec == "self" or spec.begins_with("point:"):
		return main.player
	return null

func _do_play(a: Dictionary, state: SimState, row: Dictionary) -> bool:
	var dm = main.deck_manager
	var idx: int = int(a.get("card", -1))
	if idx < 0 or idx >= dm.hand.size():
		row["refused"] = "no such hand index %d" % idx
		return false
	var card: Card = dm.hand[idx]
	var spec := str(a.get("target", ""))
	var target = _resolve_target(spec, state)
	if spec.begins_with("enemy:") and target == null:
		row["refused"] = "no such enemy"
		return false
	if spec.begins_with("point:"):
		var xy := spec.substr(6).split(",")
		var cell := Vector2i(int(xy[0]), int(xy[1]))
		var world: Vector3 = main.grid_manager.snap_to_grid(main.grid_manager.grid_to_world(cell))
		main._last_aim_world = world
		_aims[card.get_instance_id()] = world
		_park_mouse(world)
	# Picks a card needs (Sky Attack's discard, Friendship's second ally…):
	# {"picked_card": <hand index>, "picked_cards": [i, …], "picked_ally": "self"}.
	if a.has("picks"):
		var picks: Dictionary = a["picks"]
		if picks.has("picked_card"):
			card.picked_card = dm.hand[int(picks["picked_card"])]
		if picks.has("picked_cards"):
			var arr: Array = []
			for i in picks["picked_cards"]:
				arr.append(dm.hand[int(i)])
			card.picked_cards = arr
		if picks.has("picked_ally"):
			card.picked_ally = main.player
	main.select_card(idx)
	if main.selected_card_index != idx:
		row["refused"] = "select_card refused (%s)" % card.world_block_reason()
		return false
	# The click handler's own gates (range, line of sight, high ground).
	if target is Enemy:
		if card.requires_high_ground and not main._has_high_ground(main.player.position, target):
			main.select_card(-1)
			row["refused"] = "needs high ground"
			return false
		if not main._is_target_in_card_range(card, target):
			main.select_card(-1)
			row["refused"] = "out of range (%d tiles)" % main._get_distance_to_target(target)
			return false
	row["action_id"] = "play:%s" % card.card_id
	row["rng_outcome_used"] = str(card.rng_selected_index) if card.has_chance_effect() else ""
	main.play_selected_card(target)
	if main.selected_card_index != -1:
		main.select_card(-1)
		row["refused"] = "play_card refused (mana %d, cost %d)" % [int(main.player.get_stats().current_mana), SimState.estimate_mana_cost(card)]
		return false
	_card_counts[card.card_id] = int(_card_counts.get(card.card_id, 0)) + 1
	return true

func _do_attack(a: Dictionary, state: SimState, row: Dictionary) -> bool:
	var target = _resolve_target(str(a.get("target", "")), state)
	if not (target is Enemy):
		row["refused"] = "no such enemy"
		return false
	if main._get_distance_to_target(target) > main._basic_attack_reach():
		row["refused"] = "out of reach"
		return false
	var queued_before: int = main._pending_resolve_queue.size()
	var tempo_before: int = main.tempo_manager.global_tempo
	row["action_id"] = "attack"
	main._execute_basic_attack(target)
	var swung: bool = main._pending_resolve_queue.size() > queued_before \
		or main.tempo_manager.global_tempo != tempo_before or row["damage_dealt"] > 0
	if not swung:
		row["refused"] = "attack refused (stunned, disarmed or out of reach)"
	return swung

func _do_block(row: Dictionary) -> bool:
	var inv = main.player.get_inventory()
	if inv == null or inv.get_equipped_shield() == null:
		row["refused"] = "no shield"
		return false
	var tempo_before: int = main.tempo_manager.global_tempo
	main._on_block_pressed()
	if main.tempo_manager.global_tempo == tempo_before:
		row["refused"] = "block refused"
		return false
	return true

func _do_move(a: Dictionary, row: Dictionary) -> bool:
	var cell := SimScenario.cell_of(a.get("cell", [0, 0]))
	if main._movement_locked():
		row["refused"] = "committed to a ticking action"
		return false
	var gm = main.grid_manager
	var world: Vector3 = gm.grid_to_world(cell)
	if main.dungeon_manager:
		world.y = main.dungeon_manager.get_elevation_world_y(cell)
	var spaces: int = main._route_length(world)
	if spaces <= 0:
		row["refused"] = "no route to %s" % str(cell)
		return false
	if not main.player.move_to_grid(world, spaces):
		row["refused"] = "move refused (stunned, rooted, webbed)"
		return false
	row["action_id"] = "move:%d" % spaces
	return true

# --------------------------------------------------------------- time ----

## Run the tick pump until the player's queue is empty, snap-stepping units
## and answering prompts after every tick. A win does not cut it short: the
## character is committed to the action's remaining ticks either way, so
## bars_elapsed counts them. A loss does.
func _tick_until_free() -> void:
	var guard := 0
	while main.tempo_manager.is_ticking() and outcome != "loss" and guard < 1000:
		_park_mouse_for_next_resolve()
		main.tempo_manager._process_one_tick()
		_settle_all()
		_answer_prompts()
		_check_end()
		guard += 1

## Walk every moving unit to the end of its route through the real
## per-tile arrival code (bleed, traps, tempo per tile, melee-entry reactions).
func _settle_all() -> void:
	if _settling or main == null:
		return
	_settling = true
	var guard := 0
	while guard < 2000:
		guard += 1
		var moved := false
		for e in main.enemy_spawner.get_living_enemies():
			if e.is_moving:
				e.position.x = e.target_position.x
				e.position.z = e.target_position.z
				e._physics_process(1.0 / 60.0)
				moved = true
		var p = main.player
		if p.is_moving and not p.movement_paused:
			p.position.x = p.target_position.x
			p.position.z = p.target_position.z
			p._physics_process(1.0 / 60.0)
			moved = true
		if not moved:
			break
	_settling = false

func _check_end() -> void:
	if outcome != "" or main == null:
		return
	if main.player.get_stats().current_health <= 0:
		outcome = "loss"
		return
	var foes := 0
	for e in main.enemy_spawner.get_living_enemies():
		if not e.is_structure:
			foes += 1
	if foes == 0:
		outcome = "win"

# ------------------------------------------------------------- prompts ----

const PICKER_NAMES := ["HandCardPicker", "HandMultiPicker", "FullCardPicker", "ChoicePicker",
	"ReleaseTensionPicker", "DefensiveSacrificePrompt"]

func _answer_prompts() -> void:
	if main == null:
		return
	# Peshtigo's Kiss (and kin): keep the power burning?
	var mp = main.get("_maintain_prompt")
	if mp != null and is_instance_valid(mp):
		var btns: Array = mp.find_children("*", "Button", true, false)
		var labels: Array = []
		for b in btns:
			labels.append(b.text)
		var maintain_idx := -1
		for i in range(btns.size()):
			if btns[i].text == "Maintain":
				maintain_idx = i
		var choice := policy.answer_prompt("maintain", labels)
		var pick: int = maintain_idx if choice == 0 else (1 - maintain_idx if btns.size() == 2 else -1)
		if pick < 0:
			for i in range(btns.size()):
				if i != maintain_idx:
					pick = i
		if pick >= 0 and pick < btns.size():
			btns[pick].pressed.emit()
	# Pickers raised while a card resolves.
	var ui = main.get_node_or_null("UI")
	if ui:
		for pname in PICKER_NAMES:
			var node = ui.find_child(pname, true, false)
			if node == null or not is_instance_valid(node):
				continue
			var btns: Array = node.find_children("*", "Button", true, false)
			if btns.is_empty():
				continue
			var done: Button = null
			var cancel: Button = null
			var options: Array = []
			var option_btns: Array = []
			for b in btns:
				var t: String = str(b.text)
				if t == "Done":
					done = b
				elif t.to_lower() in ["cancel", "take the hit", "let it go out", "no"]:
					cancel = b
				else:
					options.append(t)
					option_btns.append(b)
			var kind := "defensive_sacrifice" if pname == "DefensiveSacrificePrompt" else "picker"
			var choice := policy.answer_prompt(kind, options)
			if choice >= 0 and choice < option_btns.size():
				option_btns[choice].pressed.emit()
			elif cancel:
				cancel.pressed.emit()
			if done and is_instance_valid(done):
				done.pressed.emit()
	# Life Swap: pick which adjacent enemy to strike.
	var pick_pending = main.get("_pending_enemy_pick")
	if pick_pending is Dictionary and not pick_pending.is_empty():
		var allowed: Array = pick_pending.get("allowed", [])
		var labels: Array = []
		for en in allowed:
			labels.append(en.enemy_name)
		var choice := policy.answer_prompt("life_swap", labels)
		main._pending_enemy_pick = {}
		if choice >= 0 and choice < allowed.size():
			main._life_swap_strike(allowed[choice], int(pick_pending.get("damage", 0)))
	# Communal Donation.
	if bool(main.get("_donation_active")):
		if policy.answer_prompt("donation", []) >= 0:
			main._on_donation_confirmed()
		else:
			main._on_donation_cancelled()
	# Point to Prove (non-blocking, but the dialog waits for an answer).
	var ptp = main.get("point_to_prove_dialog")
	if ptp != null and is_instance_valid(ptp) and ptp.get("panel") != null and ptp.panel.visible:
		if policy.answer_prompt("point_to_prove", ["Yes", "No"]) == 0:
			ptp._on_yes_pressed()
		else:
			ptp._on_no_pressed()
	tree.paused = false

# --------------------------------------------------------------- mouse ----

## Point-aimed cards read the live mouse when they resolve: park it there.
func _park_mouse(world: Vector3) -> void:
	var scr: Vector2 = main.world_to_screen(world)
	var ev := InputEventMouseMotion.new()
	ev.position = scr
	ev.global_position = scr
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _park_mouse_for_next_resolve() -> void:
	for entry in main._pending_resolve_queue:
		var card = entry["card"]
		if card and _aims.has(card.get_instance_id()):
			_park_mouse(_aims[card.get_instance_id()])
			return

# ------------------------------------------------------------- signals ----

func _on_tempo_advanced(_global_total: int, _amount: int) -> void:
	# Every enemy that acted on this tempo has acted: settle their moves and
	# hand attribution back to the player's row.
	_settle_all()
	for r in _open_enemy_rows:
		_finish_row(r)
	_open_enemy_rows.clear()
	_row = _player_row

func _on_threshold_reached(_times: int) -> void:
	if main.tempo_manager.current_tempo > 0:
		_overflow_bars += 1

func _on_enemy_action_fired(enemy, action_name: String) -> void:
	_enemy_action_counts[action_name] = int(_enemy_action_counts.get(action_name, 0)) + 1
	var row := _new_row(_enemy_label(enemy), action_name, "player")
	row["enemy_id"] = _enemy_label(enemy)
	row["enemy_hp"] = enemy.current_health
	row["enemy_pos"] = _cell_str(enemy.position)
	row["distance"] = main.grid_manager.get_distance_in_cells(main.player.position, enemy.position)
	row["_enemy"] = enemy
	rows.append(row)
	_open_enemy_rows.append(row)
	_row = row

func _on_enemy_damaged(amount: int, enemy) -> void:
	if amount <= 0:
		return
	_total_dealt += amount
	if _row.is_empty():
		return
	if _row["actor"] == "player":
		_row["damage_dealt"] += amount
	elif _row.get("_enemy") == enemy:
		_row["damage_taken"] += amount
	else:
		# Another enemy was hurt during this enemy's action (thorns, splash):
		# that is the player's doing.
		_player_row["damage_dealt"] += amount

func _on_player_damage_taken(amount: int) -> void:
	if amount <= 0:
		return
	_total_taken += amount
	if _row.is_empty():
		return
	if _row["actor"] == "player":
		_row["damage_taken"] += amount
	else:
		_row["damage_dealt"] += amount

func _on_player_mana_changed(current: float, _max_val: int) -> void:
	_mana_delta = current - _mana_seen
	_mana_seen = current

func _on_player_mana_gained(amount: int, is_regen: bool) -> void:
	if is_regen:
		_mana_wasted += maxi(0, amount - int(round(_mana_delta)))

func _on_player_buff_applied(buff) -> void:
	if not _row.is_empty():
		_row["buffs_applied"] = _join(_row["buffs_applied"], str(buff.buff_name))

func _on_player_debuff_applied(debuff) -> void:
	if not _row.is_empty():
		_row["debuffs_applied"] = _join(_row["debuffs_applied"], "player:" + _debuff_name(debuff))

func _on_enemy_debuff_applied(enemy, debuff_name: String, _value: int) -> void:
	if not _row.is_empty():
		_row["debuffs_applied"] = _join(_row["debuffs_applied"], "%s:%s" % [_enemy_label(enemy), debuff_name])

# ---------------------------------------------------------------- rows ----

func _new_row(actor: String, action_id: String, target: String) -> Dictionary:
	var stats = main.player.get_stats()
	var tm = main.tempo_manager
	var row := {
		"bar_index": tm.global_tempo / maxi(1, tm.tempo_threshold),
		"tempo_before": tm.global_tempo,
		"tempo_after": tm.global_tempo,
		"actor": actor,
		"action_id": action_id,
		"target": target,
		"player_hp": stats.current_health,
		"player_armor": stats.get_total_armor(),
		"player_temp_hp": stats.current_temp_health,
		"player_mana": int(stats.current_mana),
		"hand_size": main.deck_manager.hand.size(),
		"enemy_id": "",
		"enemy_hp": "",
		"enemy_pos": "",
		"player_pos": _cell_str(main.player.position),
		"distance": "",
		"damage_dealt": 0,
		"damage_taken": 0,
		"buffs_applied": "",
		"debuffs_applied": "",
		"rng_outcome_used": "",
	}
	var armor := {}
	for en in main.enemy_spawner.get_living_enemies():
		armor[en.get_instance_id()] = en.current_armor
	row["_armor"] = armor
	if actor == "player" and target.begins_with("enemy:"):
		var idx := int(target.substr(6))
		var living: Array = main.enemy_spawner.get_living_enemies()
		if idx >= 0 and idx < living.size():
			var en = living[idx]
			row["enemy_id"] = _enemy_label(en)
			row["enemy_hp"] = en.current_health
			row["enemy_pos"] = _cell_str(en.position)
			row["distance"] = main.grid_manager.get_distance_in_cells(main.player.position, en.position)
	elif actor == "player":
		var living: Array = main.enemy_spawner.get_living_enemies()
		if not living.is_empty():
			var en = living[0]
			row["enemy_id"] = _enemy_label(en)
			row["enemy_hp"] = en.current_health
			row["enemy_pos"] = _cell_str(en.position)
			row["distance"] = main.grid_manager.get_distance_in_cells(main.player.position, en.position)
	return row

## Close a row: the clock and the enemy's state after the action.
func _finish_row(row: Dictionary) -> void:
	if row.is_empty() or main == null:
		return
	row["tempo_after"] = main.tempo_manager.global_tempo
	# Armor an enemy lost while this row was open counts as damage dealt
	# (Enemy.damaged only reports what reached health): to the player when
	# the player acted, to the enemy itself when it was the one hit back.
	var armor: Dictionary = row.get("_armor", {})
	var stripped := 0
	for e in main.enemy_spawner.enemies:
		if is_instance_valid(e) and armor.has(e.get_instance_id()):
			stripped += maxi(0, int(armor[e.get_instance_id()]) - e.current_armor)
	if stripped > 0:
		if row["actor"] == "player":
			row["damage_dealt"] += stripped
		else:
			row["damage_taken"] += stripped
		_total_dealt += stripped
	row.erase("_armor")
	var en = row.get("_enemy", null)
	if en == null and row["enemy_id"] != "":
		for e in main.enemy_spawner.enemies:
			if is_instance_valid(e) and _enemy_label(e) == row["enemy_id"]:
				en = e
	if en != null and is_instance_valid(en):
		row["enemy_hp"] = en.current_health
		row["enemy_pos"] = _cell_str(en.position)
		row["distance"] = main.grid_manager.get_distance_in_cells(main.player.position, en.position)
	row.erase("_enemy")

func _enemy_label(enemy) -> String:
	var idx: int = main.enemy_spawner.enemies.find(enemy)
	return "%s#%d" % [enemy.enemy_name.replace(" ", "_"), idx]

func _cell_str(world: Vector3) -> String:
	var c: Vector2i = main.grid_manager.world_to_grid(world)
	return "%d:%d" % [c.x, c.y]

func _debuff_name(debuff) -> String:
	return str(debuff.debuff_name)

static func _join(a: String, b: String) -> String:
	return b if a == "" else a + "|" + b

func _reset_counters() -> void:
	_row = {}
	_player_row = {}
	_open_enemy_rows.clear()
	_total_dealt = 0
	_total_taken = 0
	_card_counts.clear()
	_enemy_action_counts.clear()
	_mana_wasted = 0
	_mana_delta = 0.0
	_overflow_bars = 0
	_decisions = 0
	_refusals = 0
	_aims.clear()

# ------------------------------------------------------------- summary ----

func _summary() -> Dictionary:
	var stats = main.player.get_stats()
	var tm = main.tempo_manager
	var played := 0
	for k in _card_counts:
		played += int(_card_counts[k])
	var entropy := 0.0
	for k in _card_counts:
		var p := float(_card_counts[k]) / float(maxi(1, played))
		if p > 0.0:
			entropy -= p * (log(p) / log(2.0))
	var actions: Array = []
	var keys := _enemy_action_counts.keys()
	keys.sort()
	for k in keys:
		actions.append("%s:%d" % [k, _enemy_action_counts[k]])
	return {
		"seed": seed_value,
		"outcome": outcome,
		"bars_elapsed": float(tm.global_tempo) / float(maxi(1, tm.tempo_threshold)),
		"total_damage_dealt": _total_dealt,
		"total_damage_taken": _total_taken,
		"damage_per_tempo": float(_total_dealt) / float(maxi(1, tm.global_tempo)),
		"cards_played": played,
		"distinct_cards_played": _card_counts.size(),
		"card_entropy": entropy,
		"mana_wasted": _mana_wasted,
		"overflow_bars": _overflow_bars,
		"end_hp_pct": float(stats.current_health) / float(maxi(1, stats.max_health)),
		"enemy_actions_by_type": "|".join(actions),
		"global_tempo": tm.global_tempo,
		"decisions": _decisions,
		"error": error_msg,
		"warnings": "|".join(warnings),
	}

# ----------------------------------------------------------------- CSV ----

static func csv_cell(v) -> String:
	if v is float:
		return "%.4f" % v
	var s := str(v)
	if s.find(",") >= 0 or s.find("\"") >= 0 or s.find("\n") >= 0:
		return "\"" + s.replace("\"", "\"\"") + "\""
	return s

static func csv_line(columns: Array, row: Dictionary) -> String:
	var cells: Array = []
	for c in columns:
		cells.append(csv_cell(row.get(c, "")))
	return ",".join(cells)

func run_csv_text() -> String:
	var lines: Array = [",".join(ROW_COLUMNS)]
	for r in rows:
		lines.append(csv_line(ROW_COLUMNS, r))
	return "\n".join(lines) + "\n"

static func summary_csv_line(summary: Dictionary) -> String:
	return csv_line(SUMMARY_COLUMNS, summary)

static func aggregate_text(summaries: Array) -> String:
	## mean/std/min/max of every numeric summary column, plus win_rate and n.
	var numeric: Array = []
	for c in SUMMARY_COLUMNS:
		if c in ["seed", "outcome", "enemy_actions_by_type", "error", "warnings"]:
			continue
		numeric.append(c)
	var header: Array = ["n", "win_rate", "loss_rate", "timeout_rate", "error_rate"]
	for c in numeric:
		for s in AGGREGATE_STATS:
			header.append("%s_%s" % [c, s])
	var n := summaries.size()
	var out := {"n": n}
	for o in ["win", "loss", "timeout", "error"]:
		var k := 0
		for s in summaries:
			if s["outcome"] == o:
				k += 1
		out["%s_rate" % o] = float(k) / float(maxi(1, n))
	for c in numeric:
		var vals: Array = []
		for s in summaries:
			vals.append(float(s[c]))
		var mean := 0.0
		for v in vals:
			mean += v
		mean /= float(maxi(1, n))
		var var_sum := 0.0
		for v in vals:
			var_sum += (v - mean) * (v - mean)
		out["%s_mean" % c] = mean
		out["%s_std" % c] = sqrt(var_sum / float(maxi(1, n)))
		out["%s_min" % c] = vals.min() if n > 0 else 0.0
		out["%s_max" % c] = vals.max() if n > 0 else 0.0
	return ",".join(header) + "\n" + csv_line(header, out) + "\n"

static func write_text(path: String, text: String) -> bool:
	var dir := path.get_base_dir()
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[SIM] cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(text)
	f.close()
	return true

static func append_summary(path: String, summary: Dictionary) -> void:
	var dir := path.get_base_dir()
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	var fresh := not FileAccess.file_exists(path)
	var f := FileAccess.open(path, FileAccess.READ_WRITE if not fresh else FileAccess.WRITE)
	if f == null:
		push_error("[SIM] cannot append %s" % path)
		return
	f.seek_end()
	if fresh:
		f.store_line(",".join(SUMMARY_COLUMNS))
	f.store_line(summary_csv_line(summary))
	f.close()

func _log(msg: String) -> void:
	if verbose:
		print("[SIM] " + msg)
