class_name NewCardsD
extends RefCounted

## Sheet batch D: Berserker's Tithe, Internal Sickness, Fan of Knives, Static
## Sting, Feint, Cadence, Grit, Spine Release. The shared files only carry
## one-line hooks into here:
##   Card._execute_card            -> execute()        (the card-side effect)
##   main._apply_card_world_effects_inner -> world_effects() (needs the board)
##   main (end of the world effects) and Card.clear_temp_mods -> end_feint()
##   DeckManager.tick_temp_mods    -> tick_tithe()     (Tithe's 40-tempo clock)
##   CardUI.setup                  -> place_face_ticker() (Tithe's countdown)
## docs/new_cards/D.md says what each card does and where the sheet was vague.

const IDS := ["berserkers_tithe", "internal_sickness", "fan_of_knives", "static_sting",
	"feint", "cadence", "grit", "spine_release"]

# --- Berserker's Tithe -------------------------------------------------------
const TITHE_EFFECT_TEMPO := 40
const TITHE_LEFT := "tithe_tempo_left"   # meta: tempo the halving / doubling still lasts
const TITHE_BASE := "tithe_base_tempo"   # meta: the card's own tempo, to go back to
const TITHE_MODE := "tithe_mode"         # meta: "halved" | "doubled"
# --- Internal Sickness -------------------------------------------------------
const SICKNESS_DRAW := 2
const SICKNESS_JAIL := 15
# --- Fan of Knives -----------------------------------------------------------
const FAN_MAX_DISCARDS := 5
const FAN_BONUS := "fan_bonus_damage"    # meta: the play's bonus damage, kept for the picker
# --- Static Sting ------------------------------------------------------------
const STING_SHOCK := 2
const STING_ARC_SHOCK := 1
const STING_ARC_RANGE := 2
# --- Feint -------------------------------------------------------------------
const FEINT_VULNERABLE := 2
const FEINT_TEMPO := 2
const FEINT_DAMAGE := 5
const FEINT_META := "feint_damage"       # meta on the buffed attack: the damage it carries
# --- Cadence -----------------------------------------------------------------
const CADENCE_TICKS := 5
# --- Grit --------------------------------------------------------------------
const GRIT_ARMOR_PER_STEP := 2
const GRIT_BOLSTER := 2

# =============================================================================
# CARD SIDE (Card._execute_card)
# =============================================================================

static func execute(card: Card, target, stats: PlayerStats, deck, buff_mgr: BuffManager,
		damage_reduction_pct: float, self_damage_percent: float) -> void:
	match card.card_id:
		"berserkers_tithe":
			_tithe(card, target, stats, deck, buff_mgr, damage_reduction_pct, self_damage_percent)
		"internal_sickness":
			_internal_sickness(card, target, stats, deck, buff_mgr, damage_reduction_pct, self_damage_percent)
		"static_sting":
			_static_sting(card, target, stats, buff_mgr, damage_reduction_pct, self_damage_percent)
		"feint":
			_feint(card, target, deck)
		"cadence":
			_cadence(stats, buff_mgr)
		"grit":
			_grit(stats, buff_mgr)
		"fan_of_knives":
			# The knives fly from main once the discards are chosen
			# (world_effects). The play's riders (passives folded into
			# bonus_damage, the slotted item's +damage) only live while the
			# executor runs, so they are noted here for the picker to use.
			card.set_meta(FAN_BONUS, card.bonus_damage)
		"spine_release":
			pass  # the eight tiles around the caster: world_effects

static func _alive(target) -> bool:
	return target != null and is_instance_valid(target) and target.has_method("take_damage") \
		and target.get("is_dead") != true

## One single-target hit through the shared roll (Card._execute_slash).
## A plain Offensive card is not an attack: Strengthen is for attacks, and
## BuffManager.consume_strengthen only knows the card's shape while main has
## the play armed (stats.st_pre_attack_*). On a bare execute nothing is armed
## and it would spend Strengthen on any card — so the shape is armed here for
## the roll and put back after.
static func _hit(card: Card, target, stats: PlayerStats, buff_mgr: BuffManager,
		damage_reduction_pct: float, self_damage_percent: float) -> void:
	var was_armed := false
	var was_attack := false
	var was_offensive := false
	if stats:
		was_armed = stats.st_pre_attack_armed
		was_attack = stats.st_pre_attack_is_attack
		was_offensive = stats.st_pre_attack_is_offensive
		stats.st_pre_attack_armed = true
		stats.st_pre_attack_is_attack = card.is_attack()
		stats.st_pre_attack_is_offensive = card.is_offensive()
	card._execute_slash(target, false, stats, damage_reduction_pct, self_damage_percent, buff_mgr)
	if stats:
		stats.st_pre_attack_armed = was_armed
		stats.st_pre_attack_is_attack = was_attack
		stats.st_pre_attack_is_offensive = was_offensive

# --- Berserker's Tithe -------------------------------------------------------

static func _tithe(card: Card, target, stats: PlayerStats, deck, buff_mgr: BuffManager,
		damage_reduction_pct: float, self_damage_percent: float) -> void:
	# A second run of the same play (free-hand echo, Flurry Form, Skilled
	# Momentum) on an enemy the first run already killed changes nothing.
	if not _alive(target):
		return
	_hit(card, target, stats, buff_mgr, damage_reduction_pct, self_damage_percent)
	tithe_settle(card, deck, target.get("is_dead") == true)

## The tithe: a kill sends the card to the draw pile with its tempo halved,
## anything else leaves it in the discard pile with its tempo doubled.
## Either way the change is to the card's OWN tempo (6 -> 3 or 12): a new
## play replaces the running effect and restarts its 40 tempo, it never
## compounds.
static func tithe_settle(card: Card, deck, killed: bool) -> void:
	var base: int = int(card.get_meta(TITHE_BASE)) if card.has_meta(TITHE_BASE) else card.tempo_cost
	card.set_meta(TITHE_BASE, base)
	card.set_meta(TITHE_LEFT, TITHE_EFFECT_TEMPO)
	if killed:
		card.set_meta(TITHE_MODE, "halved")
		card.tempo_cost = maxi(1, base / 2)  # rounded down, never below 1
		# "Add it to your draw pile": shuffled in, not placed on top. The play
		# already put the card in the discard pile; it only moves from there
		# (a copy jailed by the Rapid Recurve stays jailed).
		if deck and deck.discard_pile.has(card):
			deck.discard_pile.erase(card)
			deck.shuffle_card_into_draw_pile(card)
		print("[CARD] Berserker's Tithe: a kill — into the draw pile, tempo %d for %d" % [card.tempo_cost, TITHE_EFFECT_TEMPO])
	else:
		card.set_meta(TITHE_MODE, "doubled")
		card.tempo_cost = base * 2
		print("[CARD] Berserker's Tithe: no kill — discarded, tempo %d for %d" % [card.tempo_cost, TITHE_EFFECT_TEMPO])
	if deck:
		deck.hand_updated.emit()

static func tithe_left(card: Card) -> int:
	if card == null or not card.has_meta(TITHE_LEFT):
		return 0
	return int(card.get_meta(TITHE_LEFT))

static func tithe_mode(card: Card) -> String:
	return str(card.get_meta(TITHE_MODE)) if card and card.has_meta(TITHE_MODE) else ""

static func _tithe_end(card: Card) -> void:
	if card.has_meta(TITHE_BASE):
		card.tempo_cost = int(card.get_meta(TITHE_BASE))
	for key in [TITHE_BASE, TITHE_LEFT, TITHE_MODE]:
		if card.has_meta(key):
			card.remove_meta(key)

## DeckManager.tick_temp_mods (every tempo step): the 40 runs down wherever
## the card is — hand, draw pile, discard pile, jail — and at zero the card
## is back to its own tempo.
static func tick_tithe(deck, amount: int) -> void:
	if deck == null or amount <= 0:
		return
	var redraw := false
	for pile in [deck.hand, deck.draw_pile, deck.discard_pile, deck.jail_pile]:
		for card in pile:
			if card == null or not card.has_meta(TITHE_LEFT):
				continue
			var left: int = int(card.get_meta(TITHE_LEFT)) - amount
			if left > 0:
				card.set_meta(TITHE_LEFT, left)
				continue
			_tithe_end(card)
			print("[CARD] Berserker's Tithe: the tempo change wears off (tempo %d)" % card.tempo_cost)
			if pile == deck.hand:
				redraw = true
	if redraw:
		deck.hand_updated.emit()  # the hourglass number on the face

# --- Internal Sickness -------------------------------------------------------

static func _internal_sickness(card: Card, target, stats: PlayerStats, deck, buff_mgr: BuffManager,
		damage_reduction_pct: float, self_damage_percent: float) -> void:
	if not _alive(target):
		return
	_hit(card, target, stats, buff_mgr, damage_reduction_pct, self_damage_percent)
	if target.get("is_dead") != true or deck == null:
		return
	# Jailed before the draws: an empty draw pile would shuffle the discard
	# pile (this card with it) back in.
	if deck.discard_pile.has(card):
		deck.discard_pile.erase(card)
		card.jail(SICKNESS_JAIL)
		deck.jail_pile.append(card)
	for _i in range(SICKNESS_DRAW):
		deck.draw_card()
	deck.hand_updated.emit()
	print("[CARD] Internal Sickness: a kill — drew %d, jailed for %d tempo" % [SICKNESS_DRAW, SICKNESS_JAIL])

# --- Static Sting ------------------------------------------------------------

static func _static_sting(card: Card, target, stats: PlayerStats, buff_mgr: BuffManager,
		damage_reduction_pct: float, self_damage_percent: float) -> void:
	if not _alive(target):
		return
	# "Already had Shock": read before this card's own 2 land.
	var had_shock: bool = int(target.get("shock_stacks")) > 0 if "shock_stacks" in target else false
	_hit(card, target, stats, buff_mgr, damage_reduction_pct, self_damage_percent)
	if not is_instance_valid(target):
		return
	if target.get("is_dead") != true and target.has_method("apply_debuff"):
		target.apply_debuff("shock", STING_SHOCK)
	if not had_shock:
		return
	var other = _arc_target(target)
	if other == null:
		return
	other.apply_debuff("shock", STING_ARC_SHOCK)
	if target.is_inside_tree() and target.get_parent():
		LightningFX.arc(target.get_parent(), target.position, other.position)
	print("[CARD] Static Sting: the charge arcs — %d Shock to %s" % [STING_ARC_SHOCK, other.enemy_name])

## The arc: the nearest other living enemy within 2 squares of the TARGET,
## in grid cells — the measure the Shock debuff's own arc uses
## (Enemy._nearest_other_enemy), read off the spawner's roster.
static func _arc_target(target):
	var scene = target.get_parent() if target is Node else null
	if scene == null or not ("enemy_spawner" in scene) or scene.enemy_spawner == null:
		return target._nearest_other_enemy(STING_ARC_RANGE) if target.has_method("_nearest_other_enemy") else null
	var best = null
	var best_d: int = STING_ARC_RANGE + 1
	for e in scene.enemy_spawner.get_living_enemies():
		if e == target or not is_instance_valid(e):
			continue
		var d: int = target._get_cell_distance(e)
		if d < best_d:
			best_d = d
			best = e
	return best

# --- Feint -------------------------------------------------------------------

static func _feint(card: Card, target, deck) -> void:
	if target and is_instance_valid(target) and target.has_method("apply_debuff"):
		target.apply_debuff("vulnerable", FEINT_VULNERABLE)
	if deck == null:
		return
	var attacks: Array = []
	for c in deck.hand:
		if c != card and c.is_attack():
			attacks.append(c)
	if attacks.is_empty():
		print("[CARD] Feint: no attack card in hand to set up")
		return
	var pick: Card = attacks[randi() % attacks.size()]
	# Both ride the card until it is played or leaves the hand: the tempo as
	# an untimed in-hand change (a negative cut — it survives the timed
	# tweaks' clock), the damage in bonus_damage so every damage path and the
	# number on the face read it. end_feint takes them off again.
	pick.apply_untimed_tempo_cut(-FEINT_TEMPO)
	pick.bonus_damage += FEINT_DAMAGE
	pick.set_meta(FEINT_META, int(pick.get_meta(FEINT_META, 0)) + FEINT_DAMAGE)
	deck.hand_updated.emit()
	print("[CARD] Feint: %s gains +%d tempo and +%d damage" % [pick.card_name, FEINT_TEMPO, FEINT_DAMAGE])

## The Feint-buffed attack was played (main, once its damage has resolved) or
## left the hand (Card.clear_temp_mods): the +5 damage and +2 tempo end.
static func end_feint(card: Card) -> void:
	if card == null or not card.has_meta(FEINT_META):
		return
	var dmg: int = int(card.get_meta(FEINT_META))
	card.remove_meta(FEINT_META)
	card.bonus_damage -= dmg
	var tempo: int = (dmg / FEINT_DAMAGE) * FEINT_TEMPO
	card.temp_hand_tempo_reduction += tempo
	card.untimed_tempo_reduction += tempo

# --- Cadence -----------------------------------------------------------------

static func _cadence(stats: PlayerStats, buff_mgr: BuffManager) -> void:
	if stats == null:
		return
	# Five ticks of the DEX attack-speed counter — counter ticks only, not
	# "real attacks" (no Wizard Hat, sneakers or free-hand count), the way
	# Sabre Tooth buys its extra tick. A tick that empties the counter fires
	# the proc as an attack would; the ticks left over start the next count.
	var procced := false
	for _i in range(CADENCE_TICKS):
		var res: Dictionary = stats.register_attack(false)
		# Killing Rhythm swaps the proc for a damage burst: that is the proc too.
		if bool(res.get("proc", false)) or int(res.get("flat_damage", 0)) > 0:
			procced = true
	if procced and buff_mgr:
		buff_mgr.apply_buff(Buff.create_haste(1, 1, "Cadence"))
		print("[CARD] Cadence: the proc fires — Haste 1 for the next move")

# --- Grit --------------------------------------------------------------------

## Whole 10% steps of health missing (0..10).
static func grit_steps(stats: PlayerStats) -> int:
	if stats == null or stats.max_health <= 0:
		return 0
	var missing: int = maxi(0, stats.max_health - stats.current_health)
	return (missing * 10) / stats.max_health

static func _grit(stats: PlayerStats, buff_mgr: BuffManager) -> void:
	if stats == null:
		return
	var armor: int = GRIT_ARMOR_PER_STEP * grit_steps(stats)
	if armor > 0:
		# An armor gain: a Bolster already up adds to it and spends a charge.
		if buff_mgr:
			armor += buff_mgr.consume_bolster()
		stats.add_armor(armor)
	# "2 Bolster" is Bolster 2 (as "3 Strengthen" is Strengthen 3), for the
	# buff's standard three armor gains. Granted after this card's own armor.
	if buff_mgr and stats.current_health * 100 < stats.max_health * 30:
		buff_mgr.apply_buff(Buff.create_bolster(GRIT_BOLSTER, 3, "Grit"))
		print("[CARD] Grit: below 30%% health — Bolster %d" % GRIT_BOLSTER)

# =============================================================================
# WORLD SIDE (main._apply_card_world_effects_inner)
# =============================================================================

static func world_effects(main, card: Card, target) -> void:
	match card.card_id:
		"berserkers_tithe":
			# A Blind miss never reaches the executor, and it is not a kill.
			if card.blind_missed:
				tithe_settle(card, main.deck_manager, false)
		"fan_of_knives":
			_fan_of_knives(main, card)
		"spine_release":
			_spine_release(main, card)

# --- Fan of Knives -----------------------------------------------------------

static func _fan_of_knives(main, card: Card) -> void:
	var bonus: int = int(card.get_meta(FAN_BONUS, card.bonus_damage))
	if card.has_meta(FAN_BONUS):
		card.remove_meta(FAN_BONUS)
	# Crack of Mintaka's picker: toggle any cards in hand, then Done. It has
	# no ceiling of its own, so only the first five chosen are discarded.
	main.show_hand_multi_picker("Fan of Knives — discard up to %d cards" % FAN_MAX_DISCARDS, func(picked: Array):
		var chosen: Array = picked.slice(0, FAN_MAX_DISCARDS)
		if picked.size() > FAN_MAX_DISCARDS:
			main.add_battle_log("Fan of Knives: only the first %d cards are discarded." % FAN_MAX_DISCARDS, Color(1.0, 0.7, 0.4))
		var thrown := 0
		for pc in chosen:
			# A real discard: the card's on-discard effects fire as usual.
			if main.deck_manager.discard_card_from_hand(pc):
				thrown += 1
		_throw_knives(main, card, thrown, bonus))

## One knife per discarded card: its own roll (attack scaling, its own crit)
## on a random enemy inside the card's reach (2, as its range ring draws it),
## picked afresh for every knife.
static func _throw_knives(main, card: Card, knives: int, bonus: int) -> void:
	if knives <= 0:
		main.add_battle_log("Fan of Knives: nothing discarded, nothing thrown.", Color(0.7, 0.7, 0.8))
		return
	var stats: PlayerStats = main.player.get_stats()
	var buff_mgr: BuffManager = main.player.get_buff_manager()
	var debuff_mgr = main.player.get_debuff_manager()
	var cut: float = debuff_mgr.get_damage_reduction_percent() if debuff_mgr else 0.0
	var total := 0
	var hits := 0
	# The picker answers after the play's scope has closed: the knives are
	# still this attack card's hits, so its riders are put back for them.
	var held_bonus: int = card.bonus_damage
	card.bonus_damage = bonus
	PlayerStats.hit_source_offensive = true
	PlayerStats.hit_source_direct = true
	for _i in range(knives):
		var pool: Array = []
		for e in main.enemy_spawner.get_living_enemies():
			if is_instance_valid(e) and main._is_target_in_card_range(card, e):
				pool.append(e)
		if pool.is_empty():
			break
		var victim = pool[randi() % pool.size()]
		main.progression_triggers.arm_pre_attack_passives(card, victim)
		var dmg: int = card._roll_hit_damage(card.base_damage, stats, buff_mgr, false, victim, false, cut)
		main.progression_triggers.clear_pre_attack_passives()
		var before: int = int(victim.current_health) + int(victim.current_armor)
		victim.take_damage(dmg, true, card.damage_type)
		var lost: int = before - (int(victim.current_health) + int(victim.current_armor)) if is_instance_valid(victim) else dmg
		if lost > 0 and is_instance_valid(victim) and not victim.is_dead:
			card.apply_on_hit_debuffs(victim, stats)
		total += dmg
		hits += 1
	card.bonus_damage = held_bonus
	PlayerStats.hit_source_offensive = false
	PlayerStats.hit_source_direct = false
	card.last_damage_dealt = total
	if total > 0:
		card.apply_life_steal_for(total, stats, buff_mgr, main.deck_manager)  # an attack's life steal
	if hits < knives:
		main.add_battle_log("Fan of Knives: %d knife(s) found no enemy within %d." % [knives - hits, card.get_effective_range()], Color(1.0, 0.6, 0.3))
	if hits > 0:
		main.add_battle_log("Fan of Knives: %d knives, %d damage" % [hits, total], Color(0.4, 1.0, 0.5))
	main._on_hand_updated()
	main.update_deck_info()

# --- Spine Release -----------------------------------------------------------

## The Thorns that can be spent: the Thorns BUFF (the stacks that wear down a
## point per hit). Barbed Exterior's maintained thorns and the sphere grid's
## never wear down — they are standing effects, not a stock — and stay.
static func spendable_thorns(buff_mgr: BuffManager) -> int:
	var total := 0
	if buff_mgr:
		for t in buff_mgr.get_buffs(Buff.BuffType.THORNS):
			total += maxi(0, t.value)
	return total

static func _spine_release(main, card: Card) -> void:
	var buff_mgr: BuffManager = main.player.get_buff_manager()
	var thorns: int = spendable_thorns(buff_mgr)
	if thorns <= 0:
		main.add_battle_log("Spine Release: no Thorns to spend.", Color(0.7, 0.7, 0.8))
		return
	# "The full circle around you": the eight tiles touching the caster.
	var gm = main.grid_manager
	var here: Vector2i = gm.world_to_grid(main.player.position)
	var ring: Array = []
	for e in main.enemy_spawner.get_living_enemies():
		if not is_instance_valid(e):
			continue
		var c: Vector2i = gm.world_to_grid(e.position)
		if maxi(absi(c.x - here.x), absi(c.y - here.y)) == 1:
			ring.append(e)
	if ring.is_empty():
		# Nobody to hit: the Thorns are kept (the card's mana and tempo are not).
		main.add_battle_log("Spine Release: no enemy beside you — your Thorns stay.", Color(1.0, 0.6, 0.3))
		return
	buff_mgr.remove_buff(Buff.BuffType.THORNS)
	# Split evenly; what does not divide goes one point each to the nearest
	# (the four straight neighbours before the corners).
	ring.sort_custom(func(a, b): return main.player.position.distance_squared_to(a.position) < main.player.position.distance_squared_to(b.position))
	var share: int = thorns / ring.size()
	var spare: int = thorns % ring.size()
	for i in range(ring.size()):
		var dmg: int = share + (1 if i < spare else 0)
		# Flat: the Thorns' own number, no stat scaling and no crit — what
		# they would have dealt an attacker.
		if dmg > 0 and is_instance_valid(ring[i]):
			ring[i].take_damage(dmg, true)
	card.last_damage_dealt = thorns
	main.add_battle_log("Spine Release: %d Thorns spent across %d enemies" % [thorns, ring.size()], Color(0.6, 0.9, 0.5))

# =============================================================================
# CARD FACE (CardUI.setup)
# =============================================================================

## Berserker's Tithe: "a tempo ticker on the bottom of the card showing how
## long the effect has remaining". Card faces had no countdown readout to
## reuse, so this is a plain outlined label in the faces' own style (the
## Maintain frame's upkeep label), on the bottom edge. It reads the card every
## frame, so it counts down without the hand being rebuilt.
class TempoTicker extends Label:
	var card: Card = null

	func _init() -> void:
		name = "TempoTicker"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_theme_font_size_override("font_size", 10)
		add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.06))
		add_theme_constant_override("outline_size", 4)
		z_index = 5

	func _process(_delta: float) -> void:
		refresh()

	func refresh() -> void:
		var left: int = NewCardsD.tithe_left(card)
		visible = left > 0
		if not visible:
			return
		var halved: bool = NewCardsD.tithe_mode(card) == "halved"
		text = "Tempo %s: %d" % ["halved" if halved else "doubled", left]
		add_theme_color_override("font_color", Color(0.55, 1.0, 0.6) if halved else Color(1.0, 0.5, 0.45))

static func place_face_ticker(face: Control, card: Card) -> void:
	var host: Control = face.get_node_or_null("Panel")
	if host == null:
		return
	var ticker = host.get_node_or_null("TempoTicker")
	if card == null or card.card_id != "berserkers_tithe":
		if ticker:
			ticker.card = null
			ticker.visible = false
		return
	if ticker == null:
		ticker = TempoTicker.new()
		host.add_child(ticker)
	ticker.card = card
	ticker.size = Vector2(CardUI.CARD_W, 14)
	ticker.position = Vector2(0, CardUI.CARD_H - 17.0)
	ticker.refresh()
