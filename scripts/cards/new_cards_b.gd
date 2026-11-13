class_name NewCardsB
extends RefCounted

## Sheet batch B (2026-11-11): the instants, the jail cards and the deck-order
## cards. Main, Card and DeckManager each carry a one-line hook into here; the
## behaviour lives in this file. See docs/new_cards/B.md.
##
##   Instants   Soul Consumption, Not So Fast, Spiteful Sting, Pocket Shiv
##   Jail       Slow and Steady Wins (slow_and_steady_wins), Self Admission
##   Deck order Reverse Reverse, Foresight
##
## `main` is the Main scene throughout. Like every other instant site in
## main.gd, these act for the active player (main.player / main.deck_manager);
## Not So Fast alone walks every player, the way Cover does.

const SOUL_TRIGGER := "on_enemy_killed"
const NOT_SO_FAST_TRIGGER := "on_ally_hit_within_6"
const STING_TRIGGER := "on_melee_hit_taken"
const SHIV_TRIGGER := "on_card_discarded"

const SOUL_RANGE := 3.0          # squares from where the enemy fell
const NOT_SO_FAST_RANGE := 6.0   # squares from you to the struck ally
const MELEE_RADIUS := 1.5        # "within 1 square" / "surrounding": the 8 neighbours
const STING_POISON := 4
const SHIV_MANA := 10

## The sheet gives Slow and Steady Wins no jail length; Self Admission's 20 is used.
const DEEP_BREATHS_JAIL := 20
const DEEP_BREATHS_TEMP_HP := 10
## ...and no length for the temp HP either: it lasts as long as the jail.
const DEEP_BREATHS_TEMP_HP_TEMPO := 20
const DEEP_BREATHS_ARMOR := 10
const DEEP_BREATHS_META := "deep_breaths_armor"

const SELF_ADMISSION_JAIL := 20
const SELF_ADMISSION_META := "self_admission_payoffs"

const FORESIGHT_BASE_MANA := 20
const FORESIGHT_PER_BRAIN := 2

const LOG_COLOR := Color(0.75, 0.8, 1.0)

# ------------------------------------------------------------------ wiring

## Called once from Main._ready, BEFORE main connects its own hand_updated
## handler: the hand listener below re-prices Foresight and lands Self
## Admission's tempo cut, and main's rebuild of the hand must read the result.
static func connect_main(main) -> void:
	# Co-op swaps main.deck_manager to the active player's deck; these
	# listeners sit on the first player's and stand down while it is not the
	# active one (the same reach the other instant sites in main have).
	var dm = main.deck_manager
	dm.hand_updated.connect(func(): if main.deck_manager == dm: _on_hand_updated(main))
	dm.non_play_discard.connect(func(c): if main.deck_manager == dm: _on_non_play_discard(main, c))
	dm.reaction_triggered.connect(func(c): if main.deck_manager == dm: _on_reaction_triggered(main, c))
	main.enemy_spawner.enemy_killed.connect(func(e): on_enemy_killed(main, e))

static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## The nearest living enemy within `radius` squares of `pos` (not `skip`).
static func _nearest_enemy(main, pos: Vector3, radius: float, skip = null):
	var best = null
	var best_d := INF
	if main.enemy_spawner == null:
		return null
	for e in main.enemy_spawner.get_living_enemies():
		if not is_instance_valid(e) or e == skip or e.is_dead:
			continue
		var d := _flat_dist(e.position, pos)
		if d <= radius and d < best_d:
			best_d = d
			best = e
	return best

# ------------------------------------------------------------------ instants

## Soul Consumption: an enemy died. Every copy in hand fires, one after the
## other: a kill made by one copy's 6 damage comes back through here, and the
## next copy answers THAT death (from where that enemy fell) — the chain.
## "When you kill": the enemy's kill credit decides (Enemy.kill_credit_player
## — the players' blow or their damage-over-time; not a self-destruct, a
## fallen master's minion or another enemy's blow).
static func on_enemy_killed(main, enemy) -> void:
	var dm = main.deck_manager
	if dm == null or main.player == null:
		return
	if is_instance_valid(enemy) and "kill_credit_player" in enemy and not enemy.kill_credit_player:
		return
	var origin: Vector3 = enemy.position if is_instance_valid(enemy) else main.player.position
	var fired := false
	for _i in range(20):
		var copy = null
		for c in dm.hand:
			if c.card_type == Card.CardType.REACTION and c.reaction_trigger == SOUL_TRIGGER:
				copy = c
				break
		if copy == null or not dm.fire_reaction(copy):
			break  # none left, or Silenced (it is a spell)
		fired = true
		main._fire_instant_site_effect(copy, {"origin": origin, "killed": enemy})
	if fired:
		main._refresh_unit_tracker()

## Spiteful Sting: an enemy's blow just landed on you (Main._on_enemy_attacked_player).
static func on_enemy_attacked_player(main, enemy) -> void:
	var dm = main.deck_manager
	if dm == null or main.player == null or not is_instance_valid(enemy):
		return
	if _flat_dist(enemy.position, main.player.position) > MELEE_RADIUS:
		return
	var fired: Array = dm.trigger_reactions(STING_TRIGGER)
	for c in fired:
		main._fire_instant_site_effect(c, {"target": enemy})
	if not fired.is_empty():
		main._refresh_unit_tracker()

## Not So Fast: an ally is about to take a hit (Main._cover_mitigation, the one
## place that sees heroes, dojo allies and summons alike). `victim` is the
## ally's node. Each player within 6 squares who is not the victim fires ONE
## copy — a second copy would only swap them straight back.
static func on_ally_hit(main, victim) -> void:
	if victim == null or not is_instance_valid(victim) or not (victim is Node3D):
		return
	if not ("target_position" in victim):
		return  # a summon with no walk target cannot trade places (Swap's rule)
	for holder in main._all_players():
		if not is_instance_valid(holder) or holder == victim:
			continue
		var dm = main._deck_for_player(holder)
		if dm == null or _flat_dist(holder.position, victim.position) > NOT_SO_FAST_RANGE:
			continue
		for c in dm.hand:
			if c.card_type == Card.CardType.REACTION and c.reaction_trigger == NOT_SO_FAST_TRIGGER:
				if dm.fire_reaction(c):
					main._fire_instant_site_effect(c, {"victim": victim, "owner": holder})
					main.call_deferred("_refresh_unit_tracker")
				break

## Pocket Shiv: a card was discarded from the hand without being played.
## Deferred to the end of the frame: discards are announced from inside loops
## over the hand, and firing takes the Shiv out of that same hand.
static func _on_non_play_discard(main, _card) -> void:
	var dm = main.deck_manager
	if dm == null or dm.non_play_discard_is_spend:
		return  # an instant firing or a jail release is not a discard
	var holds := false
	for c in dm.hand:
		if c.card_type == Card.CardType.REACTION and c.reaction_trigger == SHIV_TRIGGER:
			holds = true
			break
	if holds:
		(func(): _fire_pocket_shivs(main)).call_deferred()

static func _fire_pocket_shivs(main) -> void:
	if not is_instance_valid(main) or main.deck_manager == null or main.player == null:
		return
	var fired: Array = main.deck_manager.trigger_reactions(SHIV_TRIGGER)
	for c in fired:
		main._fire_instant_site_effect(c, {})
	if not fired.is_empty():
		main._refresh_unit_tracker()

## Slow and Steady Wins' rider: an instant it jailed grants 10 armor the next time it
## triggers, on top of its own effect.
static func _on_reaction_triggered(main, card) -> void:
	if card == null or not card.has_meta(DEEP_BREATHS_META):
		return
	card.remove_meta(DEEP_BREATHS_META)
	var stats = main.player.get_stats() if main.player else null
	if stats:
		stats.add_armor(DEEP_BREATHS_ARMOR)
		main.add_battle_log("Slow and Steady Wins: %s grants +%d armor" % [card.card_name, DEEP_BREATHS_ARMOR], LOG_COLOR)

## The trigger-site half of this batch's instants (Main._fire_instant_site_effect),
## so Lethal Recall replays them too. A replay has no trigger context and
## falls back to what is around the player.
static func instant_site_effect(main, card, ctx: Dictionary) -> void:
	var player = main.player
	var dm = main.deck_manager
	var stats = player.get_stats() if player else null
	match card.card_id:
		"soul_consumption":
			var origin: Vector3 = ctx.get("origin", player.position)
			var victim = _nearest_enemy(main, origin, SOUL_RANGE, ctx.get("killed"))
			if victim:
				# Flat, like every instant's damage (Death Vortex, Psionic Flow).
				victim.take_damage(card.damage, true)
				main.add_battle_log("Soul Consumption: %d damage to %s, draw a card" % [card.damage, victim.enemy_name], LOG_COLOR)
			else:
				main.add_battle_log("Soul Consumption: draw a card", LOG_COLOR)
			dm.draw_card()
		"spiteful_sting":
			var attacker = ctx.get("target")
			if not is_instance_valid(attacker) or not (attacker is Enemy):
				attacker = _nearest_enemy(main, player.position, MELEE_RADIUS)
			if attacker and not attacker.is_dead:
				attacker.apply_debuff("poison", STING_POISON)
				main.add_battle_log("Spiteful Sting: %d Poison on %s, draw a card" % [STING_POISON, attacker.enemy_name], LOG_COLOR)
			dm.draw_card()
		"pocket_shiv":
			if stats:
				stats.gain_mana(SHIV_MANA)
			var near = _nearest_enemy(main, player.position, MELEE_RADIUS)
			if near:
				near.take_damage(card.damage, true)
				main.add_battle_log("Pocket Shiv: +%d mana, %d damage to %s" % [SHIV_MANA, card.damage, near.enemy_name], LOG_COLOR)
			else:
				main.add_battle_log("Pocket Shiv: +%d mana" % SHIV_MANA, LOG_COLOR)
		"not_so_fast":
			var holder = ctx.get("owner", player)
			if not is_instance_valid(holder):
				holder = player
			var ally = ctx.get("victim")
			if not is_instance_valid(ally):
				ally = _nearest_swappable_ally(main, holder)
			if ally == null:
				return
			var took_off: Vector3 = holder.position
			var landing: Vector3 = ally.position
			swap_positions(main, holder, ally)
			# The 8 neighbours of each tile; an enemy beside both is hit once.
			var hit: Array = []
			for spot in [took_off, landing]:
				for e in main.enemy_spawner.get_enemies_in_radius(spot, MELEE_RADIUS):
					if not (e in hit):
						hit.append(e)
			for e in hit:
				if is_instance_valid(e) and not e.is_dead:
					e.take_damage(card.damage, true)
			main.add_battle_log("Not So Fast! Swapped places — %d damage to %d enem%s" % [
				card.damage, hit.size(), "y" if hit.size() == 1 else "ies"], LOG_COLOR)

## Lethal Recall replaying Not So Fast has no struck ally: the nearest one in range.
static func _nearest_swappable_ally(main, holder):
	var best = null
	var best_d := INF
	for a in main._all_allies() + main._all_summons():
		if not is_instance_valid(a) or a == holder or not ("target_position" in a):
			continue
		var d := _flat_dist(a.position, holder.position)
		if d <= NOT_SO_FAST_RANGE and d < best_d:
			best_d = d
			best = a
	return best

## Swap's position trade (the Swap card resolves through here too).
static func swap_positions(main, a, b) -> void:
	var a_pos: Vector3 = a.position
	var b_pos: Vector3 = b.position
	a.position = b_pos
	if "target_position" in a:
		a.target_position = b_pos
	b.position = a_pos
	if "target_position" in b:
		b.target_position = a_pos
	print("[MAIN] Swap: %s and %s traded places" % [a.name, b.name])
	main.progression_triggers._trigger_skill_tree_on_displacement()

# ------------------------------------------------------------------ jail

## Every jail in this batch: the card's own Card.jail arms the timer, and the
## card sits in the deck's jail pile until DeckManager.process_turn frees it
## (to the discard pile, like every jailed card).
static func jail_card(dm, card, tempo: int) -> void:
	card.clear_temp_mods()
	card.jail(tempo)
	dm.jail_pile.append(card)
	NewCardsA.on_card_jailed(dm, card)  # Warden's Hound

## Hand listener (runs ahead of main's own): Self Admission's payoff lands when
## the card it jailed is next in the hand, and Foresight's price follows the
## Brain pool.
static func _on_hand_updated(main) -> void:
	var dm = main.deck_manager
	if dm == null or main.player == null:
		return
	for c in dm.hand:
		if c.has_meta(SELF_ADMISSION_META) and not c.is_jailed():
			var n: int = int(c.get_meta(SELF_ADMISSION_META))
			c.remove_meta(SELF_ADMISSION_META)
			for _i in range(n):
				_self_admission_payoff(main, c)
	refresh_foresight(main, false)

static func _self_admission_payoff(main, card) -> void:
	var stats = main.player.get_stats()
	var bm = main.player.get_buff_manager()
	if bm:
		bm.apply_buff(Buff.create_strengthen(5, 3, "Self Admission"))
	if stats:
		stats.heal(20)
		stats.gain_mana(20)
	# "The card itself costs 1 less tempo": the in-hand tempo cut every other
	# card uses (Clean Exchange) — it holds until the card is played or leaves
	# the hand.
	card.apply_untimed_tempo_cut(1)
	main.add_battle_log("Self Admission: %s is back — Strengthen 5, heal 20, +20 mana, it costs 1 less tempo" % card.card_name, LOG_COLOR)

# ------------------------------------------------------------------ Foresight's price

static func foresight_cost(stats) -> int:
	var brain: int = stats.current_brain_points if stats else 0
	return maxi(0, FORESIGHT_BASE_MANA - FORESIGHT_PER_BRAIN * brain)

## DeckManager.compute_play_cost: keep the card's printed price at what the
## Brain pool makes it (the face reads mana_cost, like Summon Skeleton's).
static func price_foresight(card, stats) -> void:
	if card.card_id == "foresight":
		card.mana_cost = foresight_cost(stats)

## Re-price every Foresight in hand. `redraw`: the Brain pool moved while the
## hand stood still, so the faces need a rebuild if a price changed.
static func refresh_foresight(main, redraw: bool) -> void:
	var dm = main.deck_manager
	if dm == null or main.player == null:
		return
	var cost := foresight_cost(main.player.get_stats())
	var changed := false
	for c in dm.hand:
		if c.card_id == "foresight" and c.mana_cost != cost:
			c.mana_cost = cost
			changed = true
	if changed and redraw:
		main._on_hand_updated()

# ------------------------------------------------------------------ played cards

## Main._apply_card_world_effects_inner: the four hand-played cards.
static func world_effect(main, card, _target) -> void:
	match card.card_id:
		"slow_and_steady_wins":
			_deep_breaths(main)
		"self_admission":
			_self_admission(main, card)
		"reverse_reverse":
			_reverse_reverse(main)
		"foresight":
			_foresight(main)

static func _deep_breaths(main) -> void:
	var dm = main.deck_manager
	var stats = main.player.get_stats()
	var jailed := 0
	var from_draw := false
	for pile in [dm.hand, dm.draw_pile, dm.discard_pile]:
		for i in range(pile.size() - 1, -1, -1):
			var c = pile[i]
			if c.card_type != Card.CardType.REACTION:
				continue
			pile.remove_at(i)
			jail_card(dm, c, DEEP_BREATHS_JAIL)
			c.set_meta(DEEP_BREATHS_META, true)
			jailed += 1
			if pile == dm.draw_pile:
				from_draw = true
	if from_draw:
		dm.brain_peek_depth = 0  # the pile changed under any peeked cards
	if jailed > 0 and stats:
		stats.add_temp_health(DEEP_BREATHS_TEMP_HP * jailed, DEEP_BREATHS_TEMP_HP_TEMPO)
	dm.hand_updated.emit()
	main.add_battle_log("Slow and Steady Wins: %d instant%s jailed for %d tempo, +%d temp HP" % [
		jailed, "" if jailed == 1 else "s", DEEP_BREATHS_JAIL, DEEP_BREATHS_TEMP_HP * jailed], LOG_COLOR)

static func _self_admission(main, card) -> void:
	var dm = main.deck_manager
	var pick = card.picked_card
	card.picked_card = null
	if pick == null or not (pick in dm.hand):
		# No pick reached us (a replay, a scripted play): a random hand card,
		# as Reposition does.
		if dm.hand.is_empty():
			main.add_battle_log("Self Admission: no card to jail.", LOG_COLOR)
			return
		pick = dm.hand[randi() % dm.hand.size()]
	dm.hand.erase(pick)
	jail_card(dm, pick, SELF_ADMISSION_JAIL)
	pick.set_meta(SELF_ADMISSION_META, int(pick.get_meta(SELF_ADMISSION_META, 0)) + 1)
	dm.hand_updated.emit()
	main.add_battle_log("Self Admission: %s jailed for %d tempo" % [pick.card_name, SELF_ADMISSION_JAIL], LOG_COLOR)

## Reverse Reverse: draw 1, then the player puts a hand card on top of the
## draw pile. The pick is owed: Cancel re-opens the picker.
static func _reverse_reverse(main) -> void:
	main.deck_manager.draw_card()
	_reverse_reverse_pick(main)

static func _reverse_reverse_pick(main) -> void:
	if not is_instance_valid(main) or main.deck_manager == null:
		return
	var dm = main.deck_manager
	main.show_hand_card_picker("Reverse Reverse — put which card on top of your draw pile?",
		func(chosen):
			if chosen == null or not (chosen in dm.hand):
				return
			dm.hand.erase(chosen)
			chosen.clear_temp_mods()  # it left the hand
			dm.draw_pile.append(chosen)  # the back of the pile is its top
			dm.hand_updated.emit()
			main.update_deck_info()
			main.add_battle_log("Reverse Reverse: %s goes on top of the draw pile" % chosen.card_name, LOG_COLOR),
		null,
		func(): (func(): _reverse_reverse_pick(main)).call_deferred())

## Foresight: show the top 3 of the draw pile; one to the hand, one to the
## bottom, the third stays on top. With fewer than 3 there the hand comes
## first, then the bottom. An empty draw pile takes the discard back first,
## like any draw.
static func _foresight(main) -> void:
	var dm = main.deck_manager
	if dm.draw_pile.is_empty():
		dm.shuffle_discard_into_draw()
	var top: Array = []
	for i in range(mini(3, dm.draw_pile.size())):
		top.append(dm.draw_pile[dm.draw_pile.size() - 1 - i])
	if top.is_empty():
		main.add_battle_log("Foresight: the draw pile is empty.", LOG_COLOR)
		return
	# The three are known now, whatever was peeked before.
	dm.brain_peek_depth = maxi(0, dm.brain_peek_depth - top.size())
	_foresight_pick_hand(main, top)

static func _foresight_pick_hand(main, top: Array) -> void:
	if not is_instance_valid(main):
		return
	main.show_full_card_picker("Foresight — take which card into your hand?", top, 1,
		func(picks: Array):
			var dm = main.deck_manager
			var rest: Array = top.duplicate()
			if not picks.is_empty() and picks[0] in dm.draw_pile:
				var taken = picks[0]
				dm.draw_pile.erase(taken)
				if dm.add_card_as_drawn(taken):
					main.add_battle_log("Foresight: %s to your hand" % taken.card_name, LOG_COLOR)
				else:
					dm.draw_pile.append(taken)  # hand full: it stays on top
					main.add_battle_log("Foresight: hand full — %s stays on top" % taken.card_name, LOG_COLOR)
				rest.erase(taken)
			_foresight_pick_bottom(main, rest),
		func(): (func(): _foresight_pick_hand(main, top)).call_deferred())

static func _foresight_pick_bottom(main, rest: Array) -> void:
	if not is_instance_valid(main):
		return
	var dm = main.deck_manager
	rest = rest.filter(func(c): return c in dm.draw_pile)
	if rest.is_empty():
		main.update_deck_info()
		return
	main.show_full_card_picker("Foresight — put which card on the bottom?", rest, 1,
		func(picks: Array):
			if not picks.is_empty() and picks[0] in dm.draw_pile:
				var sunk = picks[0]
				dm.draw_pile.erase(sunk)
				dm.draw_pile.insert(0, sunk)  # the front of the pile is its bottom
				main.add_battle_log("Foresight: %s to the bottom of the draw pile" % sunk.card_name, LOG_COLOR)
				if rest.size() > 1:
					dm.brain_peek_depth += 1  # the one left on top is known
			main.update_deck_info(),
		func(): (func(): _foresight_pick_bottom(main, rest)).call_deferred())
