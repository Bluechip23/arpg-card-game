class_name SimState
extends RefCounted

## A snapshot of what the player can see at a decision point, plus the list
## of legal actions, built from the live Main. Policies read this and never
## touch Main directly. Hidden information (draw-pile order, crit rolls,
## the enemy's un-telegraphed choices) is deliberately absent.

var main: Node
var player_hp: int
var player_max_hp: int
var player_armor: int
var player_temp_hp: int
var player_mana: int
var player_max_mana: int
var flash_points: int
var brain_points: int
var player_cell: Vector2i
var hand: Array = []        # [{index, id, name, type, mana, tempo, resolve_tick, damage, block, heal, is_attack, is_offensive, is_ranged, range, target_types, rng_index, rng_chance, keywords, playable, why_not}]
var enemies: Array = []     # [{index, node, id, type, hp, max_hp, armor, exposed, cell, distance, intent, effects, structure}]
var buffs: Array = []       # names
var debuffs: Array = []     # names
var tempo: int
var global_tempo: int
var threshold: int
var bar_index: int
var movement_locked: bool
var can_move: bool
var can_play_cards: bool
var basic_attack_reach: int
var basic_attack_tempo: int
var basic_attack_damage: int
var has_shield: bool
var hand_cap: int
var draw_pile_size: int
var discard_size: int
var tempo_until_draw: float
# Ryan's tools (and everyone's): point pools, the attack-speed proc, the
# discard counters passives read, invisibility, the character's passives.
var flash_block_cost: int
var flash_proc_cost: int
var brain_draw_cost: int
var brain_peek_cost: int
var attacks_until_proc: int
var next_attack_half_tempo: bool
var invisible_tempo: int          # tempo of invisibility left (0 = visible)
var discards_this_cycle: int
var true_discards_this_cycle: int
var ladder_banked: int
var passives: Dictionary = {}      # passive id -> rank
var flash_strike: bool             # Flash Cut keystone: sidestep is a strike

func _init(p_main: Node) -> void:
	main = p_main
	refresh()

func refresh() -> void:
	var player = main.player
	var stats = player.get_stats()
	var gm = main.grid_manager
	player_hp = stats.current_health
	player_max_hp = stats.max_health
	player_armor = stats.get_total_armor()
	player_temp_hp = stats.current_temp_health
	player_mana = int(stats.current_mana)
	player_max_mana = stats.get_available_max_mana()
	flash_points = stats.current_flash_points
	brain_points = stats.current_brain_points
	player_cell = gm.world_to_grid(player.position)
	tempo = main.tempo_manager.current_tempo
	global_tempo = main.tempo_manager.global_tempo
	threshold = main.tempo_manager.tempo_threshold
	bar_index = global_tempo / maxi(1, threshold)
	movement_locked = main._movement_locked()
	var dmgr = player.get_debuff_manager()
	can_move = dmgr.can_move() and not player._is_webbed()
	can_play_cards = dmgr.can_play_cards() and main.glut_tempo_remaining <= 0
	basic_attack_reach = main._basic_attack_reach()
	basic_attack_tempo = main._basic_attack_tempo()
	basic_attack_damage = stats.get_basic_attack_damage()
	var inv = player.get_inventory()
	has_shield = inv != null and inv.get_equipped_shield() != null
	var dm = main.deck_manager
	hand_cap = dm.get_hand_cap()
	draw_pile_size = dm.draw_pile.size()
	discard_size = dm.discard_pile.size()
	tempo_until_draw = main.draw_timer.tempo_until_draw
	flash_block_cost = stats.get_flash_block_cost()
	flash_proc_cost = PlayerStats.FLASH_COST_PROC_TICK
	brain_draw_cost = stats.get_next_brain_draw_cost()
	brain_peek_cost = stats.get_next_brain_peek_cost()
	attacks_until_proc = stats.get_attacks_until_proc()
	next_attack_half_tempo = dm.next_attack_half_tempo
	var bm = player.get_buff_manager()
	invisible_tempo = 0
	if bm.is_invisible():
		var inv_buff = bm.get_buff(Buff.BuffType.INVISIBLE)
		invisible_tempo = maxi(1, int(inv_buff.duration)) if inv_buff else 1
	discards_this_cycle = dm.discards_this_cycle
	true_discards_this_cycle = dm.true_discards_this_cycle
	ladder_banked = int(stats.get("st_ladder_banked")) if stats.get("st_ladder_banked") != null else 0
	passives.clear()
	for pid in stats.skill_tree_passives:
		passives[pid] = maxi(1, stats.get_passive_level(pid))
	flash_strike = bool(stats.keystone_flash_strike)

	buffs.clear()
	for b in player.get_buff_manager().buffs:
		buffs.append(str(b.buff_name))
	debuffs.clear()
	for d in dmgr.debuffs:
		debuffs.append(str(d.debuff_name))

	enemies.clear()
	var living: Array = main.enemy_spawner.get_living_enemies()
	for i in range(living.size()):
		var e = living[i]
		var cell: Vector2i = gm.world_to_grid(e.position)
		enemies.append({
			"index": i,
			"node": e,
			"id": "%s#%d" % [e.enemy_name, e.get_instance_id() % 100000],
			"type": Enemy.EnemyType.keys()[e.enemy_type],
			"hp": e.current_health,
			"max_hp": e.max_health,
			"armor": e.current_armor,
			"exposed": e.is_exposed,
			"cell": cell,
			"distance": gm.get_distance_in_cells(player.position, e.position),
			"intent": e.get_display_action(),
			"effects": e.get_active_effects(),
			"poison": e.poison_stacks,
			"structure": e.is_structure,
			# What the inspect panel prints: the moveset and the base hit.
			"actions": e.actions,
			"attack_damage": e.attack_damage,
			"attack_range": int(e.attack_range),
		})

	hand.clear()
	for i in range(dm.hand.size()):
		var c: Card = dm.hand[i]
		var why := _why_unplayable(c, i, dmgr)
		hand.append({
			"index": i,
			"id": c.card_id,
			"name": c.card_name,
			"type": Card.CardType.keys()[c.card_type],
			"mana": estimate_mana_cost(c),
			"tempo": estimate_tempo_cost(c),
			"resolve_tick": mini(c.resolve_tick, maxi(1, estimate_tempo_cost(c))),
			"damage": main._card_player_damage(c) if (c.card_type == Card.CardType.ATTACK and c.base_damage > 0) else 0,
			"block": c.block if c.block > 0 else c.base_block,
			"heal": c.heal_amount,
			"is_attack": c.is_attack(),
			"is_offensive": c.is_offensive(),
			"is_ranged": c.is_ranged,
			"range": c.get_effective_range(),
			"target_types": c.target_types.duplicate(),
			"rng_index": c.rng_selected_index if c.has_chance_effect() else null,
			"rng_chance": c.rng_effective_chance if c.has_chance_effect() else null,
			"keywords": c.keywords.duplicate(),
			"description": c.description,   # the card text, the only statement of its effects a player gets
			"playable": why == "",
			"why_not": why,
		})

## The mana the card will cost, as the card face shows it. deck_manager
## .play_card is the authority; this mirrors its common terms.
static func estimate_mana_cost(c: Card) -> int:
	return maxi(0, c.get_burden_mana_cost() - c.temp_mana_discount)

static func estimate_tempo_cost(c: Card) -> int:
	return maxi(0, c.get_burden_tempo_cost() + c.get_conditional_tempo_penalty() - c.temp_hand_tempo_reduction)

## Cards the UI itself would not let through, with the reason. Empty = fine.
func _why_unplayable(c: Card, index: int, dmgr) -> String:
	if c.card_type in [Card.CardType.UNPLAYABLE, Card.CardType.ENCHANTMENT, Card.CardType.REACTION]:
		return "not a playable type"
	if c.is_jailed():
		return "jailed"
	if c.requires_engraving and c.slotted_in_item == null:
		return "needs engraving"
	var block := c.world_block_reason()
	if block != "":
		return block
	if not can_play_cards:
		return "stunned, frozen or glutted"
	if dmgr.is_card_locked(index):
		return "locked"
	if c.card_type == Card.CardType.ATTACK and c.school == Card.CardSchool.PHYSICAL and not dmgr.can_play_attack_cards():
		return "disarmed"
	if c.school == Card.CardSchool.SPELL and not dmgr.can_play_spell_cards():
		return "silenced"
	if estimate_mana_cost(c) > player_mana and not (c.card_id == "exhausted_assault" and player_mana <= 0):
		return "not enough mana"
	if c.card_id in NEEDS_PICK:
		return "needs a pick (policy must supply picks)"
	return ""

## Cards whose play opens a picker the policy would have to answer; the
## generic policies skip them until they carry picks (docs/sim/README.md).
const NEEDS_PICK := ["sky_attack", "mirror_mirror", "collect_arrows",
	"friendship", "release_tension", "crack_of_mintaka", "life_swap", "communal_donation"]

func hand_index_of(card_id: String) -> int:
	for h in hand:
		if h["id"] == card_id and h["playable"]:
			return h["index"]
	for h in hand:
		if h["id"] == card_id:
			return h["index"]
	return -1

func nearest_enemy_index() -> int:
	var best := -1
	var best_d := 1 << 30
	for e in enemies:
		if e["structure"]:
			continue
		if e["distance"] < best_d:
			best_d = e["distance"]
			best = e["index"]
	return best

func enemy_node(index: int):
	return enemies[index]["node"] if index >= 0 and index < enemies.size() else null

## Every action the runner will accept right now.
func legal_actions() -> Array:
	var out: Array = []
	var player = main.player
	var dm = main.deck_manager
	for h in hand:
		if not h["playable"]:
			continue
		var c: Card = dm.hand[h["index"]]
		var tt: Array = h["target_types"]
		var buff_mgr = player.get_buff_manager()
		if buff_mgr and buff_mgr.has_poisoned_blood() and c.heal_amount > 0 and "enemy" not in tt:
			tt = tt.duplicate()
			tt.append("enemy")
		if "enemy" in tt:
			for e in enemies:
				var en = e["node"]
				if c.requires_high_ground and not main._has_high_ground(player.position, en):
					continue
				if not main._is_target_in_card_range(c, en):
					continue
				out.append({"type": "play", "card": h["index"], "card_id": h["id"],
					"target": "enemy:%d" % e["index"],
					"expected_damage": main.calculate_damage_preview(c, en) if h["damage"] > 0 else 0})
		if "self" in tt or "ally" in tt or "all_nearby" in tt:
			out.append({"type": "play", "card": h["index"], "card_id": h["id"], "target": "self"})
		if "point" in tt:
			var gm = main.grid_manager
			var capped: bool = c.card_id == "blink" or (c.is_ranged and c.range_modifier < Card.INFINITE_RANGE and (not c.is_aoe or main._aoe_follows_cursor(c)))
			var aims: Array = []
			for e in enemies:
				aims.append(e["cell"])
			aims.append(player_cell)
			for cell in aims:
				if capped and gm.get_distance_in_cells(player.position, gm.grid_to_world(cell)) > c.get_effective_range():
					continue
				var a := {"type": "play", "card": h["index"], "card_id": h["id"], "target": "point:%d,%d" % [cell.x, cell.y]}
				if a not in out:
					out.append(a)
		if tt.is_empty():
			out.append({"type": "play", "card": h["index"], "card_id": h["id"], "target": "none"})
	# Auto attack
	var dmgr = player.get_debuff_manager()
	if can_play_cards and dmgr.can_play_attack_cards():
		for e in enemies:
			if main._get_distance_to_target(e["node"]) <= basic_attack_reach:
				out.append({"type": "attack", "target": "enemy:%d" % e["index"],
					"expected_damage": basic_attack_damage, "tempo": basic_attack_tempo})
	if has_shield and can_play_cards:
		out.append({"type": "block"})
	# Point spends: all instant (no tempo passes).
	var stats = player.get_stats()
	# Sidestep — or, with Flash Cut, a strike that needs an enemy within 2.5.
	var strike_target := false
	for e in enemies:
		if e["distance"] <= 2:
			strike_target = true
	if flash_points >= flash_block_cost and (not flash_strike or strike_target):
		out.append({"type": "flash_block"})
	if flash_points >= flash_proc_cost and attacks_until_proc > 1 and not next_attack_half_tempo:
		out.append({"type": "flash_proc"})
	if brain_points >= brain_draw_cost and dmgr.can_draw_cards() and hand.size() < hand_cap \
			and (draw_pile_size > 0 or discard_size > 0):
		out.append({"type": "brain_draw"})
	if brain_points >= brain_peek_cost and dm.brain_peek_depth < draw_pile_size:
		out.append({"type": "brain_peek"})
	out.append({"type": "wait"})
	if can_move and not movement_locked and not player.is_moving:
		var free_tiles: int = int(stats.free_move_tiles)
		for cell in walkable_neighbours(player_cell):
			out.append({"type": "move", "cell": [cell.x, cell.y]})
			# The same step on flash points: no tempo passes, nobody acts.
			if flash_points >= PlayerStats.FLASH_COST_MOVE or free_tiles > 0:
				out.append({"type": "move", "cell": [cell.x, cell.y], "flash": true})
	return out

func walkable_neighbours(from: Vector2i) -> Array:
	var gm = main.grid_manager
	var player = main.player
	var taken := {}
	for e in enemies:
		taken[e["cell"]] = true
	var cells: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = from + d
		if c.x < 0 or c.x >= gm.grid_width or c.y < 0 or c.y >= gm.grid_height:
			continue
		if c in player.blocked_tiles or taken.has(c):
			continue
		cells.append(c)
	return cells

## One tile along the BFS route toward an enemy, or {} when no step helps.
func step_toward(enemy_index: int) -> Dictionary:
	if not can_move or movement_locked or main.player.is_moving:
		return {}
	var e = enemies[enemy_index]
	var gm = main.grid_manager
	var path: Array = main.player.calculate_path_to(gm.grid_to_world(e["cell"]))
	if path.is_empty():
		return {}
	var first: Vector2i = gm.world_to_grid(path[0])
	if first == e["cell"]:
		return {}
	var a := {"type": "move", "cell": [first.x, first.y]}
	if flash_points >= PlayerStats.FLASH_COST_MOVE:
		a["flash"] = true
	return a
