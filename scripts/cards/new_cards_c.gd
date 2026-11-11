class_name NewCardsC
extends RefCounted

## Batch C of the sheet's 2026-11-11 rows: the melee and movement cards.
## Lunge, Grapple Chain, Back Pedal, Deliberate Arch, Harvest, Momentous
## Slam, Bastion Battle, Acro-medic. The shared files only call in here:
##   Card._execute_card            -> execute()          (the card's own numbers)
##   main._resolve_queued_card     -> before_execute()   (moves that come before the hit / heal)
##   main._apply_card_world_effects_inner -> world_effects()  (pulls, steps, the area hit)
##   main._is_target_in_card_range -> melee_reach_bonus() / lunge_in_reach()
##   main.play_selected_card       -> back_pedal_tempo_cut() / back_pedal_spent()
##   main._input (ally click) -> acro_medic_can_play()
## docs/new_cards/C.md has the per-card reading of the sheet.

const IDS := ["lunge", "grapple_chain", "back_pedal", "deliberate_arch", "harvest",
	"momentous_slam", "bastion_battle", "acro_medic"]

const LUNGE_TILES := 3            # "Move up to 3 tiles"
const GRAPPLE_REACH_BONUS := 1.0  # "Reach 2": one square past ordinary melee
const GRAPPLE_SLOW_STACKS := 1    # "Trip it for 5 tempo": Tripped is Slow now, a stack is 5 tempo
const BACK_PEDAL_TILES := 2
const BACK_PEDAL_TEMPO_CUT := 2
const BASTION_ARMOR_BONUS := 10
const BASTION_DISARM_STACKS := 2  # "Disarm 2": two stacks, 5 tempo each
const CARRY_WEIGHT_PER_DAMAGE := 10

## Set on the card by before_execute when its move could not be made, so the
## executor skips the hit (Lunge) or the heal (Acro-medic).
const META_NO_LANDING := "new_c_no_landing"
## Set on the Player node by Back Pedal: its Steady action, if a ranged
## offensive card, costs 2 less tempo.
const META_BACK_PEDAL := "new_c_back_pedal"

const NEIGHBOURS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

# ------------------------------------------------------------------ card side

## The card's own numbers, from Card._execute_card. The plain Offensive rows
## (Lunge, Grapple Chain, Deliberate Arch, Bastion Battle) go through the
## shared hit roll: BuffManager.consume_strengthen reads the armed card's
## shape, so an attack-only Strengthen passes them by, and Card's Blind /
## Empower / life steal gates are all is_attack().
static func execute(card: Card, target, player_stats: PlayerStats, deck_manager, damage_reduction_pct: float,
		self_damage_percent: float, buff_mgr: BuffManager) -> void:
	match card.card_id:
		"lunge":
			# The move happened in before_execute; no landing, no hit.
			if card.has_meta(META_NO_LANDING):
				print("[CARD] Lunge: no free tile beside the enemy within %d — the damage is lost" % LUNGE_TILES)
				return
			card._execute_slash(target, false, player_stats, damage_reduction_pct, self_damage_percent, buff_mgr)
		"grapple_chain":
			# The pull and the Slow follow in world_effects.
			card._execute_slash(target, false, player_stats, damage_reduction_pct, self_damage_percent, buff_mgr)
		"back_pedal":
			# Steady here; the step and the tempo rider in world_effects.
			if buff_mgr:
				buff_mgr.apply_buff(Buff.create_steady(card.card_name))
			print("[CARD] Back Pedal: Steady")
		"deliberate_arch":
			# One roll for the whole swing; main lands it on every adjacent enemy.
			card.last_damage_dealt = card._roll_hit_damage(card.base_damage, player_stats, buff_mgr)
			print("[CARD] Deliberate Arch: %d damage to every adjacent enemy" % card.last_damage_dealt)
		"harvest":
			card._execute_slash(target, false, player_stats, damage_reduction_pct, self_damage_percent, buff_mgr)
			_harvest_reshuffle(card, deck_manager)
		"momentous_slam":
			# "3 damage + your carry weight / 10": the weight carried right now,
			# whole tens only, added to the base before the attack scaling.
			var weight_bonus: int = carry_weight_bonus(player_stats)
			card.bonus_damage += weight_bonus
			card._execute_slash(target, false, player_stats, damage_reduction_pct, self_damage_percent, buff_mgr)
			card.bonus_damage -= weight_bonus
			print("[CARD] Momentous Slam: +%d from carry weight" % weight_bonus)
		"bastion_battle":
			_bastion_battle(card, target, player_stats, damage_reduction_pct, self_damage_percent, buff_mgr)
		"acro_medic":
			# "Upon landing next to them": no landing, no heal.
			if card.has_meta(META_NO_LANDING):
				print("[CARD] Acro-medic: nowhere to land — no heal")
				return
			card._execute_heal_with_poison_check(target, player_stats, buff_mgr)

static func carry_weight_bonus(player_stats: PlayerStats) -> int:
	if player_stats == null:
		return 0
	return maxi(0, int(player_stats.current_carry_load)) / CARRY_WEIGHT_PER_DAMAGE

## Harvest: the discard pile goes back into the draw pile, shuffled, then one
## draw. The Harvest being played already sits in the discard pile (play_card
## put it there) and stays there: it is not part of the pile it shuffles.
## A plain shuffle, not DeckManager.shuffle_discard_into_draw: that one is
## the natural reshuffle and taxes a thin discard pile with a Heavy Greedy
## Cheese, which a card's own effect should not earn.
static func _harvest_reshuffle(card: Card, deck_manager) -> void:
	if deck_manager == null:
		return
	var own: bool = card in deck_manager.discard_pile
	if own:
		deck_manager.discard_pile.erase(card)
	var moved: int = deck_manager.discard_pile.size()
	if moved > 0:
		deck_manager.draw_pile.append_array(deck_manager.discard_pile)
		deck_manager.discard_pile.clear()
		deck_manager.shuffle_draw_pile()
	if own:
		deck_manager.discard_pile.append(card)
	deck_manager.draw_card()
	print("[CARD] Harvest: %d card(s) shuffled back into the draw pile, drew 1" % moved)

## Bastion Battle: both armor checks read the board BEFORE the hit lands
## (the 5 damage would otherwise strip a thin armor and Disarm as well).
static func _bastion_battle(card: Card, target, player_stats: PlayerStats, damage_reduction_pct: float,
		self_damage_percent: float, buff_mgr: BuffManager) -> void:
	var foe_armor: int = int(target.current_armor) if target and is_instance_valid(target) and "current_armor" in target else 0
	var own_armor: int = int(player_stats.current_armor) if player_stats else 0
	var more_armor: bool = own_armor > foe_armor
	var bare: bool = foe_armor <= 0
	if more_armor:
		card.bonus_damage += BASTION_ARMOR_BONUS
	card._execute_slash(target, false, player_stats, damage_reduction_pct, self_damage_percent, buff_mgr)
	if more_armor:
		card.bonus_damage -= BASTION_ARMOR_BONUS
	if bare and target and is_instance_valid(target) and target.has_method("apply_debuff"):
		# The stack form of Disarm: each stack is 5 tempo (Enemy.DISARM_TEMPO_PER_STACK).
		target.apply_debuff("disarm_attacks", BASTION_DISARM_STACKS)
	print("[CARD] Bastion Battle: armor %d vs %d%s%s" % [own_armor, foe_armor,
		", +%d" % BASTION_ARMOR_BONUS if more_armor else "", ", Disarm %d" % BASTION_DISARM_STACKS if bare else ""])

# ------------------------------------------------------------------ main side

static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

## A step the hero can take on foot: no cliff face between the two tiles.
static func _can_step(p, from: Vector2i, to: Vector2i) -> bool:
	if not p.step_check.is_valid():
		return true
	var st = p.get_stats()
	if st != null and st.climbs_cliffs:
		return true
	return bool(p.step_check.call(from, to))

## Put the hero on a tile at once (no walk, no tempo), as Charge and Roll do,
## and tell the world a move finished (fog, zones, melee edges).
static func _place(main, p, cell: Vector2i) -> void:
	var pos: Vector3 = main._ground_pos(cell)
	p.position = pos
	p.target_position = pos
	p.is_moving = false
	p.move_path.clear()
	p.move_completed.emit()

## Lunge: the tile the hero would land on — the nearest tile beside the enemy
## (its 8 neighbours) that a free walk of at most 3 tiles reaches. The walk
## steps as the hero walks (4 directions), through no wall, cliff face or
## unit. The hero's own tile when already beside the enemy. null when none.
static func lunge_landing_cell(main, p, enemy):
	if main == null or p == null or enemy == null or not is_instance_valid(enemy) or main.grid_manager == null:
		return null
	var gm = main.grid_manager
	var start: Vector2i = gm.world_to_grid(p.position)
	var foe: Vector2i = gm.world_to_grid(enemy.position)
	var steps := {start: 0}
	var frontier: Array[Vector2i] = [start]
	var head := 0
	var best = null
	var best_steps := 99
	var best_gap := INF
	while head < frontier.size():
		var cur: Vector2i = frontier[head]
		head += 1
		var n: int = steps[cur]
		if cur != foe and _cheb(cur, foe) <= 1:
			# Fewest steps first; then the squarest tile on the enemy.
			var gap: float = Vector2(cur - foe).length()
			if n < best_steps or (n == best_steps and gap < best_gap):
				best = cur
				best_steps = n
				best_gap = gap
		if n >= LUNGE_TILES:
			continue
		for d in NEIGHBOURS4:
			var nxt: Vector2i = cur + d
			if steps.has(nxt) or not main._cell_is_empty_for_summon(nxt) or not _can_step(p, cur, nxt):
				continue
			steps[nxt] = n + 1
			frontier.append(nxt)
	return best

## Lunge's targeting: the enemy may be clicked when a landing tile exists.
static func lunge_in_reach(main, enemy) -> bool:
	return lunge_landing_cell(main, main.player, enemy) != null

## Melee reach a batch C card adds on top of the ordinary adjacent square.
static func melee_reach_bonus(card: Card) -> float:
	return GRAPPLE_REACH_BONUS if card.card_id == "grapple_chain" else 0.0

## Acro-medic: the free tile beside the ally nearest the caster (the
## caster's own tile when already beside them). null when the ally is the
## caster, or no neighbour is free or blink-reachable.
static func acro_medic_landing_cell(main, p, ally):
	if main == null or p == null or ally == null or not is_instance_valid(ally) or ally == p \
			or not (ally is Node3D) or main.grid_manager == null:
		return null
	var gm = main.grid_manager
	var here: Vector2i = gm.world_to_grid(p.position)
	var at: Vector2i = gm.world_to_grid(ally.position)
	if here != at and _cheb(here, at) <= 1:
		return here
	var best = null
	var best_d := INF
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var cell := at + Vector2i(dx, dz)
			if cell == at or not main._cell_is_empty_for_summon(cell):
				continue
			if p.blink_check.is_valid() and not p.blink_check.call(here, cell):
				continue  # the mountains are too high to blink across
			var d: float = Vector2(cell - here).length()
			if d < best_d:
				best_d = d
				best = cell
	return best

## The click on an ally: refused, with the reason, when the card could not land.
static func acro_medic_can_play(main, tgt) -> bool:
	if tgt == null or tgt == main.player:
		main.add_battle_log("Acro-medic needs an ally to land beside, not yourself.", Color(1.0, 0.6, 0.4))
		return false
	if acro_medic_landing_cell(main, main.player, tgt) == null:
		main.add_battle_log("Acro-medic: no free spot beside that ally.", Color(1.0, 0.6, 0.4))
		return false
	return true

## Moves that come before the card's own effect (main._resolve_queued_card,
## just ahead of the executor): Lunge's walk and Acro-medic's blink. The
## board is read as the card RESOLVES, after its wind-up.
static func before_execute(main, card: Card, target) -> void:
	if not (card.card_id in ["lunge", "acro_medic"]):
		return
	if card.has_meta(META_NO_LANDING):
		card.remove_meta(META_NO_LANDING)
	var p = main.player
	var gm = main.grid_manager
	var landing = lunge_landing_cell(main, p, target) if card.card_id == "lunge" \
		else acro_medic_landing_cell(main, p, target)
	if landing == null:
		card.set_meta(META_NO_LANDING, true)
		if card.card_id == "lunge":
			main.add_battle_log("Lunge: no free tile beside the enemy within %d — the lunge falls short." % LUNGE_TILES, Color(1.0, 0.6, 0.4))
		else:
			main.add_battle_log("Acro-medic: nowhere to land beside that ally.", Color(1.0, 0.6, 0.4))
		return
	if landing == gm.world_to_grid(p.position):
		return  # already beside them: nothing to move, nothing displaced
	if card.card_id == "lunge":
		_place(main, p, landing)
	else:
		p.blink_to(main._ground_pos(landing))
	# "Counts as a displacement" (Lunge); a blink is one already (Blink, Swap).
	main.progression_triggers._trigger_skill_tree_on_displacement()
	print("[MAIN] %s: moved to %s" % [card.card_name, landing])

## The parts that need the board, after the executor (main's world effects).
static func world_effects(main, card: Card, target) -> void:
	match card.card_id:
		"grapple_chain":
			_grapple_pull(main, target)
		"back_pedal":
			_back_pedal_step(main)
			main.player.set_meta(META_BACK_PEDAL, true)
		"deliberate_arch":
			# "Every adjacent enemy": the 8 squares around the hero, the same
			# sweep Sweeping Disarm makes.
			var hit: Array = main.enemy_spawner.get_enemies_in_radius(main.player.position, 1.5 * main.grid_manager.grid_size)
			for enemy in hit:
				enemy.take_damage(card.last_damage_dealt, true, card.damage_type)
			main._apply_misery_spread(hit)
			print("[MAIN] Deliberate Arch: %d adjacent enemies for %d" % [hit.size(), card.last_damage_dealt])

## Grapple Chain: one tile toward the hero (Enemy.knock_dir, the shove every
## push uses; a wall or a unit in the way stops it), then Slow if the enemy
## ends on one of the hero's 8 neighbours. An enemy hooked while already
## adjacent has nowhere to be pulled and is Slowed all the same.
static func _grapple_pull(main, target) -> void:
	if target == null or not is_instance_valid(target) or not (target is Enemy) or target.is_dead:
		return
	var gm = main.grid_manager
	var here: Vector2i = gm.world_to_grid(main.player.position)
	var at: Vector2i = gm.world_to_grid(target.position)
	if _cheb(here, at) > 1:
		var dir := Vector2i(signi(here.x - at.x), signi(here.y - at.y))
		# The tile is read off the live board first: an enemy's own list of
		# taken tiles is only as fresh as the last tempo.
		if main._cell_is_empty_for_summon(at + dir):
			target.knock_dir(dir, 1)
		at = gm.world_to_grid(target.position)
	if _cheb(here, at) <= 1:
		target.apply_debuff("slow", GRAPPLE_SLOW_STACKS)
		main.add_battle_log("Grapple Chain: %s is dragged in and Slowed" % target.enemy_name, Color(0.9, 0.8, 0.4))

## Back Pedal: up to 2 tiles straight away from the nearest enemy (the
## nearest of the 8 grid directions), stopping short of a wall, a cliff face
## or a unit. No enemy on the field: no step. Returns the tiles stepped.
static func _back_pedal_step(main) -> int:
	var p = main.player
	var enemy = main._get_nearest_enemy()
	if enemy == null:
		return 0
	var away := Vector2(p.position.x - enemy.position.x, p.position.z - enemy.position.z)
	if away.length() < 0.01:
		return 0
	away = away.normalized()
	var dir := Vector2i(roundi(away.x), roundi(away.y))
	var gm = main.grid_manager
	var start: Vector2i = gm.world_to_grid(p.position)
	var cur := start
	var stepped := 0
	for _i in range(BACK_PEDAL_TILES):
		var nxt := cur + dir
		if not main._cell_is_empty_for_summon(nxt) or not _can_step(p, cur, nxt):
			break
		cur = nxt
		stepped += 1
	if stepped > 0:
		_place(main, p, cur)
	print("[MAIN] Back Pedal: stepped %d tile(s) away from %s" % [stepped, enemy.enemy_name])
	return stepped

## Back Pedal's rider, read as a card is played (main.play_selected_card):
## "if the action is a ranged offensive card, it gets a reduction of 2
## tempo". The action is the one Back Pedal's Steady waits for, so the cut
## stands only while that Steady does (a basic attack that spends it ends
## the rider). It comes off BEFORE Steady is asked: a ranged offensive card
## of 2 tempo or less becomes free on its own and leaves Steady standing
## for the action after it; a dearer one is made free by Steady as usual.
static func back_pedal_tempo_cut(p, card: Card) -> int:
	if p == null or not p.has_meta(META_BACK_PEDAL):
		return 0
	var bm = p.get_buff_manager()
	if bm == null or not bm.has_buff(Buff.BuffType.STEADY):
		return 0
	return BACK_PEDAL_TEMPO_CUT if (card.is_ranged and card.is_offensive()) else 0

## A card was played: whatever it was, it was the action the rider waited for.
static func back_pedal_spent(p) -> void:
	if p != null and p.has_meta(META_BACK_PEDAL):
		p.remove_meta(META_BACK_PEDAL)
