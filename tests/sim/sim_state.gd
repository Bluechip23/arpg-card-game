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
var nysm_ready: bool = false       # Now You See Me would fire on a displacement right now
var top_card: Dictionary = {}      # the draw pile's top card, only while a rule has revealed it (invisibility draw)
## Active gauntlet skills: [{index (gauntlet slot), item_id, name, fx, mana,
## description, ready, target ("enemy" / "point" / "self"), melee}]. A skill
## costs 1 tempo (Slice 2) and its mana, then cools down.
var skills: Array = []
var intelligence: int = 0
## Weapon swaps on offer: [{kind ("build" / "rack"), build, tempo, mana,
## free (Brad's free rack exchange), ranged (the incoming set holds a bow),
## incoming (card views of the cards the incoming weapons carry), leaving
## (hand indices of cards the outgoing weapons take with them)}]. One swap
## per tempo (last_swap_tempo, set by the runner), so a free swap never loops.
var weapon_swaps: Array = []
var weapons_ranged: bool = false
static var last_swap_tempo: int = -1

## What a card offers at a glance (the revealed top card, a weapon's cards).
func card_view(c: Card) -> Dictionary:
	return {"id": c.card_id, "name": c.card_name, "type": Card.CardType.keys()[c.card_type],
		"damage": main._card_player_damage(c) if (c.card_type == Card.CardType.ATTACK and c.base_damage > 0) else 0,
		"block": c.block if c.block > 0 else c.base_block, "heal": c.heal_amount,
		"description": c.description, "playable": true, "mana": estimate_mana_cost(c)}

## The swaps the game's buttons would make right now: Brad's War Rack, or a
## saved equipment build whose hands differ. Cost as the game charges it in
## combat (tempo per changed hand slot plus half the mana; Stephen's weapon
## portion of a build switch free; a ready rack exchange free).
func _collect_weapon_swaps(inv) -> void:
	var fighting: bool = main._is_in_combat()
	if inv.has_back_rack:
		if inv.rack_items.is_empty():
			return
		var free: bool = inv.can_rack_exchange(true)["ok"]
		if not free and not inv.can_rack_exchange(false)["ok"]:
			return
		var held: Array = inv.get_rack_hand_items()
		var tempo := 0
		if not free and fighting:
			tempo = maxi(inv.rack_items.size(), held.size()) * inv.get_swap_tempo_cost(ItemData.ItemType.WEAPON)
		weapon_swaps.append(_swap_view(inv, "rack", -1, inv.rack_items, held, tempo,
			inv.get_swap_mana_cost() if tempo > 0 else 0, free))
		return
	for b in range(inv.builds.size()):
		var snap = inv.builds[b]
		if b == inv.active_build or snap == null:
			continue
		var want: Array = snap.get("weapons", [])
		var incoming: Array = []
		var outgoing: Array = []
		var tempo := 0
		for i in range(inv.equipped_weapons.size()):
			var w = want[i] if i < want.size() else null
			var live = inv.equipped_weapons[i]
			if w == live:
				continue
			if w != null:
				incoming.append(w)
			if live != null:
				outgoing.append(live)
			if fighting and not inv.weapon_swap_discount:
				tempo += inv.get_swap_tempo_cost(w.item_type if w else live.item_type, w == null)
		if incoming.is_empty() and outgoing.is_empty():
			continue
		weapon_swaps.append(_swap_view(inv, "build", b, incoming, outgoing, tempo,
			inv.get_swap_mana_cost() if tempo > 0 else 0, false))

func _swap_view(inv, kind: String, b: int, incoming: Array, outgoing: Array, tempo: int, mana: int, free: bool) -> Dictionary:
	var ranged := false
	var cards: Array = []
	for it in incoming:
		if it.item_type == ItemData.ItemType.WEAPON and it.weapon_subtype == ItemData.WeaponSubtype.BOW:
			ranged = true
		for c in inv._get_item_owned_cards(it):
			cards.append(card_view(c))
	var leaving: Array = []
	for it in outgoing:
		for c in inv._get_item_owned_cards(it):
			var hi: int = main.deck_manager.hand.find(c)
			if hi >= 0:
				leaving.append(hi)
	return {"kind": kind, "build": b, "tempo": tempo, "mana": mana, "free": free, "ranged": ranged,
		"incoming": cards, "leaving": leaving}

## Cards whose play is a displacement in main's world cases (they call
## _trigger_skill_tree_on_displacement): Now You See Me keys off these.
const DISPLACEMENT_CARDS := ["blink", "swap", "shift", "escape_and_bewilder", "heroic_leap", "wrath_of_the_sea", "smoke_bomb", "roll"]
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
	nysm_ready = false
	if stats.has_skill_tree_passive("now_you_see_me"):
		var cd: int = PassiveScaling.value("now_you_see_me", "cooldown", stats.get_passive_level("now_you_see_me"))
		nysm_ready = global_tempo - int(stats.st_nysm_last_tempo) >= cd
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

	intelligence = stats.intelligence
	skills.clear()
	inv = player.get_inventory()
	if inv:
		var consts: Dictionary = main.get_script().get_script_constant_map()
		var enemy_fx: Array = consts.get("ENEMY_TARGET_GAUNTLET_SKILLS", [])
		var point_fx: Array = consts.get("POINT_TARGET_GAUNTLET_SKILLS", [])
		var melee_fx: Array = consts.get("MELEE_GAUNTLET_SKILLS", [])
		for gi in range(inv.equipped_gauntlets.size()):
			var g = inv.equipped_gauntlets[gi]
			if g == null or g.gauntlet_skill_type != ItemData.GauntletSkillType.ACTIVE:
				continue
			var fx: String = g.gauntlet_skill_effect_id
			skills.append({"index": gi, "item_id": g.item_name, "name": g.gauntlet_skill_name, "fx": fx,
				"mana": g.gauntlet_skill_mana_cost, "description": g.gauntlet_skill_description,
				"ready": inv.can_use_gauntlet_skill(g),
				"target": "enemy" if fx in enemy_fx else ("point" if fx in point_fx else "self"),
				"melee": fx in melee_fx})
	weapon_swaps.clear()
	weapons_ranged = inv != null and inv.holds_ranged_weapon()
	if inv and global_tempo != last_swap_tempo:
		_collect_weapon_swaps(inv)
	top_card = {}
	if not dm.draw_pile.is_empty() and main.get_node_or_null("UI") and main.get_node("UI").find_child("ChoicePicker", true, false):
		top_card = card_view(dm.draw_pile.back())
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
			"conditional": c.conditional_range,
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
## Plays the game refused this tempo (card_id -> global tempo), set by the
## runner and cleared per run: a gate the mirror below does not know about
## stays out of the legal actions instead of being picked again until the
## tempo idles. Static because the runner rebuilds the state every decision.
static var refused_plays: Dictionary = {}

func _why_unplayable(c: Card, index: int, dmgr) -> String:
	if c.card_type in [Card.CardType.UNPLAYABLE, Card.CardType.ENCHANTMENT, Card.CardType.REACTION]:
		return "not a playable type"
	if int(refused_plays.get(c.card_id, -1)) == main.tempo_manager.global_tempo:
		return "refused this tempo"
	# Heavy Swing: the deck manager's gate — nothing but offensive cards in hand.
	if c.card_id == "heavy_swing":
		for hc in main.deck_manager.hand:
			if hc != c and not hc.is_offensive():
				return "hand is not all offensive"
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

## Cards the policies cannot play yet. Empty: the eight that open a picker
## (Sky Attack, Mirror Mirror, Collect Arrows, Friendship, Release Tension,
## Crack of Mintaka, Life Swap, Communal Donation) are answered by the
## runner's prompt handling or carry picks from the lookahead. A card added
## here never gets played, so its single-card sweep reads as a dead card.
const NEEDS_PICK := []

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
	# Gauntlet skills, each target the game would accept.
	for k in range(skills.size()):
		var sk: Dictionary = skills[k]
		if not sk["ready"]:   # the game gates skills on cooldown and mana only
			continue
		match str(sk["target"]):
			"enemy":
				for ei in range(enemies.size()):
					if enemies[ei]["structure"]:
						continue
					var d := int(enemies[ei]["distance"])
					if (sk["melee"] and d > 1) or (sk["fx"] == "coming_in" and (d > 5 or d <= 1)):
						continue
					out.append({"type": "item_skill", "skill": k, "fx": sk["fx"], "target": "enemy:%d" % ei})
			"point":
				var ni := nearest_enemy_index()
				if ni >= 0:
					var cell: Vector2i = enemies[ni]["cell"]
					out.append({"type": "item_skill", "skill": k, "fx": sk["fx"], "target": "point:%d,%d" % [cell.x, cell.y]})
			_:
				if sk["fx"] == "house_rule" and discard_size == 0:
					continue
				out.append({"type": "item_skill", "skill": k, "fx": sk["fx"], "target": "self"})
	for k in range(weapon_swaps.size()):
		out.append({"type": "weapon_swap", "swap": k, "kind": weapon_swaps[k]["kind"], "build": weapon_swaps[k]["build"]})
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
