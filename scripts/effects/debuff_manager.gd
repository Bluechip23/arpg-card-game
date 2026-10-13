class_name DebuffManager
extends Node

## Manages debuffs on a character (player or enemy)

signal debuff_applied(debuff: Debuff)
signal debuff_removed(debuff: Debuff)
signal debuff_expired(debuff: Debuff)  # NATURAL expiry only, never purges (mirrors the enemy-side signal)
signal debuffs_changed
signal point_to_prove_triggered(debuff: Debuff)  # Emitted when stun/disarm hits with Point to Prove active

var debuffs: Array[Debuff] = []
var owner_stats = null  # PlayerStats - untyped to avoid circular dependency
var owner_node: Node3D

# For Burn - damage doubles each cycle
var burn_damage_next: int = 1

func initialize(stats = null, owner: Node3D = null) -> void:
	owner_stats = stats
	owner_node = owner
	debuffs.clear()

func apply_debuff(debuff: Debuff) -> void:
	# Elixir: poison from a card played under Elixir heals instead.
	if debuff.debuff_type == Debuff.DebuffType.POISON and Card.elixir_poison_heals and owner_stats:
		var ex_heal: int = maxi(1, debuff.value)
		owner_stats.heal(ex_heal)
		print("[DEBUFF] Elixir: %d poison became %d healing" % [debuff.value, ex_heal])
		return
	# Stack-driven debuffs never expire by the shared timer. Burn, Bleed and
	# Weighted burn their stacks by what they react to (cycles, movement, card
	# plays); the stack-clocked types (Debuff.is_stack_clocked) shed one stack
	# per 5 tempo of their own clock — whatever duration the caller passed.
	# A clock-timed Slowed/Staggered (Approach, Tower Shield) keeps its duration.
	match debuff.debuff_type:
		Debuff.DebuffType.BURN, Debuff.DebuffType.BLEED, Debuff.DebuffType.WEIGHTED:
			debuff.duration = -1
		_:
			if debuff.uses_stack_clock():
				debuff.duration = -1
				debuff.stack_clock = 0

	var existing = get_debuff(debuff.debuff_type)
	# Timed and stack-driven copies of the same debuff never merge: the timed
	# one lives on the clock, the stack one on its stacks — keep the longer
	# clock, or let the stacks ride on top of an existing timer.
	if existing and existing.clock_timed != debuff.clock_timed:
		if debuff.clock_timed:
			# A timer over stacks: become timed for at least that long.
			existing.clock_timed = true
			existing.duration = debuff.duration
			existing.value = maxi(existing.value, 1)
			existing._set_name_and_description()
			debuffs_changed.emit()
			return
		# Stacks over a timer: the timer already covers it.
		return
	# Hexed and Locked never merge: each is its own instance claiming its own
	# card in hand, so several cards can be hexed (Necromancer Bolt hexes 2)
	# or locked at once.
	if debuff.debuff_type == Debuff.DebuffType.HEXED or debuff.debuff_type == Debuff.DebuffType.LOCKED:
		existing = null

	if existing:
		# -1 means "until depleted/cleansed" — it always wins the merge.
		if existing.duration < 0 or debuff.duration < 0:
			existing.duration = -1
		elif Debuff.is_additive_timer(debuff.debuff_type):
			# Disarm / Rooted / Silence: the new timer lands ON TOP of what is
			# left (3 left + 5 = 8), not the longer of the two.
			existing.duration += debuff.duration
		else:
			existing.duration = max(existing.duration, debuff.duration)
		existing.stacks += 1
		# Accumulate — recomputing from the newest instance's value corrupted
		# heterogeneous stacks (Bleed 3 + Bleed 1 used to become 2, not 4).
		# A stack-clocked debuff keeps its own clock running: the new stacks
		# join the queue, the next one still falls when it was going to.
		existing.value += debuff.value
		existing._set_name_and_description()
		print("[DEBUFF] %s stacked to %d (value: %d)" % [debuff.debuff_name, existing.stacks, existing.value])
	else:
		debuffs.append(debuff)

		# Hexed and Locked claim their card the moment they land when a hand
		# is known — never sitting unassigned until the next hand change.
		if debuff.debuff_type == Debuff.DebuffType.HEXED or debuff.debuff_type == Debuff.DebuffType.LOCKED:
			debuff.affected_card = null
			var claim_deck = _claim_deck()
			if claim_deck:
				claim_deck.assign_hexed_locked_cards(self)

		# Reset burn damage tracker when burn is first applied
		if debuff.debuff_type == Debuff.DebuffType.BURN:
			burn_damage_next = 1

		print("[DEBUFF] Applied: %s for %d tempo" % [debuff.debuff_name, debuff.duration])
	
	# Cold -> Frozen conversion: at 5 stacks, become Frozen for 1 cycle.
	# Stacks are the summed VALUE (a Cold-3 application counts 3), matching
	# the displayed count and the enemy-side conversion.
	if debuff.debuff_type == Debuff.DebuffType.COLD:
		var cold = get_debuff(Debuff.DebuffType.COLD)
		if cold and cold.value >= 5:
			remove_debuff(Debuff.DebuffType.COLD)
			var frozen = Debuff.create(Debuff.DebuffType.FROZEN, 0, 5)
			frozen.source_name = "Cold"
			apply_debuff(frozen)
			print("[DEBUFF] Cold reached 5 stacks! Enemy is now Frozen!")
			return

	debuff_applied.emit(debuff)
	debuffs_changed.emit()

	# Point to Prove: signal that player can choose to sacrifice HP to remove
	# stun/disarm. Only offer it when surviving the rank-scaled cost (20%..6%
	# of max HP) is possible.
	if owner_stats and owner_stats.has_method("has_skill_tree_passive"):
		if owner_stats.has_skill_tree_passive("point_to_prove"):
			if debuff.debuff_type in [Debuff.DebuffType.STUN, Debuff.DebuffType.DISARM, Debuff.DebuffType.SILENCE]:
				var ptp_pct: int = PassiveScaling.value("point_to_prove", "hp_percent", owner_stats.get_passive_level("point_to_prove"))
				var ptp_cost: int = maxi(1, ceili(owner_stats.max_health * ptp_pct / 100.0))
				if owner_stats.current_health > ptp_cost:
					point_to_prove_triggered.emit(debuff)

func remove_debuff(type: Debuff.DebuffType) -> void:
	for i in range(debuffs.size() - 1, -1, -1):
		if debuffs[i].debuff_type == type:
			var removed = debuffs[i]
			debuffs.remove_at(i)
			debuff_removed.emit(removed)
			debuffs_changed.emit()
			print("[DEBUFF] Removed: %s" % removed.debuff_name)
			return

func get_debuff(type: Debuff.DebuffType) -> Debuff:
	for debuff in debuffs:
		if debuff.debuff_type == type:
			return debuff
	return null

func has_debuff(type: Debuff.DebuffType) -> bool:
	return get_debuff(type) != null

func clear_all_debuffs() -> void:
	debuffs.clear()
	debuffs_changed.emit()
	print("[DEBUFF] All debuffs cleared")

# ============================================
# TURN PROCESSING
# ============================================

func process_turn_start() -> Dictionary:
	var result = {
		"damage_taken": 0,
		"mana_lost": 0,
		"ally_damage": 0,
		"pull_direction": Vector3.ZERO,
		"pull_tiles": 0
	}

	# Burn: damage doubles each cycle (1, 2, 4, 8...); each stack is one cycle
	# of burning, so "apply 5 burn" actually burns longer than "apply 1 burn"
	# (previously stacks were cosmetic and only the doubling counter mattered).
	var burn = get_debuff(Debuff.DebuffType.BURN)
	if burn:
		result["damage_taken"] += burn_damage_next
		print("[DEBUFF] Burn deals %d damage (doubles next cycle)" % burn_damage_next)
		burn_damage_next *= 2
		burn.value -= 1
		burn._set_name_and_description()
		if burn.value <= 0:
			remove_debuff(Debuff.DebuffType.BURN)
			burn_damage_next = 1
			print("[DEBUFF] Burn expired (0 stacks)")

	# Poison: deal value damage, then lose 1 poison. Elixir flips a tick to
	# healing and burns one Elixir stack per converted tick.
	var poison = get_debuff(Debuff.DebuffType.POISON)
	if poison:
		if owner_stats and "elixir_stacks" in owner_stats and owner_stats.elixir_stacks > 0:
			owner_stats.heal(poison.value)
			owner_stats.elixir_stacks -= 1
			print("[DEBUFF] Elixir: Poison healed %d instead! (%d stack(s) left)" % [poison.value, owner_stats.elixir_stacks])
		else:
			result["damage_taken"] += poison.value
			print("[DEBUFF] Poison deals %d damage" % poison.value)
		poison.value -= 1
		poison._set_name_and_description()
		if poison.value <= 0:
			remove_debuff(Debuff.DebuffType.POISON)
			print("[DEBUFF] Poison expired (0 stacks)")

	# Drain: lose 10 mana, then lose 1 drain stack
	var drain = get_debuff(Debuff.DebuffType.DRAIN)
	if drain:
		result["mana_lost"] += 10
		print("[DEBUFF] Drain steals 10 mana")
		drain.value -= 1
		drain._set_name_and_description()
		if drain.value <= 0:
			remove_debuff(Debuff.DebuffType.DRAIN)
			print("[DEBUFF] Drain expired (0 stacks)")

	# Shocked: deal value damage to nearby allies, then lose 1 shocked
	var shocked = get_debuff(Debuff.DebuffType.SHOCKED)
	if shocked:
		result["ally_damage"] += shocked.value
		print("[DEBUFF] Shocked deals %d to nearby allies" % shocked.value)
		shocked.value -= 1
		shocked._set_name_and_description()
		if shocked.value <= 0:
			remove_debuff(Debuff.DebuffType.SHOCKED)
			print("[DEBUFF] Shocked expired (0 stacks)")

	# Apply DOT damage (no Vulnerable modifier - that only applies to attacks)
	var damage = result["damage_taken"]
	if damage > 0 and owner_stats:
		owner_stats.take_damage(damage)

	if owner_stats and result["mana_lost"] > 0:
		owner_stats.current_mana = max(0, owner_stats.current_mana - result["mana_lost"])
		owner_stats.mana_changed.emit(owner_stats.current_mana, owner_stats.max_mana)
		if owner_stats.current_mana <= 0 and owner_stats.maintained_mana > 0:
			owner_stats._break_maintained_cards()

	return result

func process_turn_end() -> void:
	# Nothing ticks on the cycle boundary any more: Brittle's stacks fall on
	# its own 5-tempo clock like every stack-clocked debuff, and timed
	# durations tick in advance_time (below) on every raw tempo advance so
	# durations like "3 tempo" work. Kept so main.gd's cycle hook stays wired.
	pass

## Advance timed debuff durations — and the stack-clocked debuffs' own
## clocks — by raw tempo. Called on every tempo advance (any amount), so
## stun/frozen/etc handle durations not divisible by 5 and a stack applied at
## tempo 3 falls at tempo 8.
func advance_time(amount: int) -> void:
	if amount <= 0 or debuffs.is_empty():
		return
	var expired: Array[Debuff] = []
	for debuff in debuffs:
		if debuff.advance_time(amount):
			expired.append(debuff)

	for debuff in expired:
		# Reset burn damage tracker when burn expires
		if debuff.debuff_type == Debuff.DebuffType.BURN:
			burn_damage_next = 1
		debuffs.erase(debuff)
		# Natural expiry only — a purge goes through remove_debuff and never
		# fires this. Marvolo's Misunderstanding detonates off it.
		debuff_expired.emit(debuff)
		debuff_removed.emit(debuff)
		print("[DEBUFF] Expired: %s" % debuff.debuff_name)

	# A stack-clocked debuff that shed a stack but lives on changed its shown
	# count; the HUD re-reads descriptions off this signal.
	var shed_any := expired.size() > 0
	if not shed_any:
		for debuff in debuffs:
			if debuff.uses_stack_clock():
				shed_any = true
				break
	if shed_any:
		debuffs_changed.emit()

func process_armor_decay(base_decay: int) -> int:
	# Returns total armor decay including Brittle (a flat extra 2 while any stacks remain)
	var total_decay = base_decay
	var brittle = get_debuff(Debuff.DebuffType.BRITTLE)
	if brittle:
		total_decay += 2
		print("[DEBUFF] Brittle adds 2 armor decay")
	return total_decay

# ============================================
# DAMAGE MODIFIERS
# ============================================

func _apply_vulnerable_modifier(damage: int) -> int:
	# Vulnerable: 30% more damage on EVERY hit while any stack remains. Hits
	# no longer eat stacks — they fall on the debuff's own 5-tempo clock.
	var vulnerable = get_debuff(Debuff.DebuffType.VULNERABLE)
	if vulnerable:
		var increase = floori(damage * 30.0 / 100.0)
		damage += increase
		print("[DEBUFF] Vulnerable increases damage by 30%% (%d)" % increase)
	return damage

func modify_incoming_damage(damage: int) -> int:
	# Apply Vulnerable
	return _apply_vulnerable_modifier(damage)

# ============================================
# MOVEMENT QUERIES
# ============================================

func can_move() -> bool:
	if has_debuff(Debuff.DebuffType.STUN):
		return false
	if has_debuff(Debuff.DebuffType.ROOTED):
		return false
	return true

## Slowed: the tempo charger prices each tile at Debuff.SLOWED_TEMPO_PER_TILE
## while this holds. Moving burns nothing — the stacks fall on the clock.
func is_slowed() -> bool:
	return has_debuff(Debuff.DebuffType.SLOWED)

## Blind: the debuff manager is the source of truth (PlayerStats.is_blinded
## is a legacy flag nothing sets any more). Attacks miss at Debuff.BLIND_MISS
## while any stack remains.
func is_blinded() -> bool:
	return has_debuff(Debuff.DebuffType.BLIND)

func get_blind_miss_chance() -> float:
	return Debuff.BLIND_MISS / 100.0 if is_blinded() else 0.0

# ============================================
# CARD QUERIES
# ============================================

func can_play_cards() -> bool:
	if has_debuff(Debuff.DebuffType.STUN):
		return false
	if has_debuff(Debuff.DebuffType.FROZEN):
		return false
	return true

func can_play_attack_cards() -> bool:
	if not can_play_cards():
		return false
	return not has_debuff(Debuff.DebuffType.DISARM)

func can_play_spell_cards() -> bool:
	if not can_play_cards():
		return false
	return not has_debuff(Debuff.DebuffType.SILENCE)

func can_draw_cards() -> bool:
	# Cuffed, or Lost in the Labyrinth (the Minotaur's curse: no draws at all).
	return not has_debuff(Debuff.DebuffType.CUFFED) and not is_lost()

## Lost in the Labyrinth (Inflamed Minotaur's room): the hand was scrambled
## and must be played left to right; no card may be drawn by any means.
func is_lost() -> bool:
	return has_debuff(Debuff.DebuffType.LOST)

func get_attack_mana_increase() -> int:
	# Fixed surcharge while any stacks remain; the stacks fall on the clock.
	return Debuff.STAGGERED_MANA if has_debuff(Debuff.DebuffType.STAGGERED) else 0

func get_tempo_increase() -> int:
	# Fixed surcharge while any stacks remain; stacks burn per card played.
	return Debuff.WEIGHTED_TEMPO if has_debuff(Debuff.DebuffType.WEIGHTED) else 0

## Stack bookkeeping when a card is successfully played: only Weighted still
## burns per card. Staggered and Clumsy hold for their stacks' 5-tempo clocks
## no matter how many cards are played (the sheet's stack model).
func on_card_played(_is_attack_card: bool) -> void:
	var weighted = get_debuff(Debuff.DebuffType.WEIGHTED)
	if weighted == null or weighted.clock_timed:
		return
	weighted.value -= 1
	weighted._set_name_and_description()
	if weighted.value <= 0:
		remove_debuff(Debuff.DebuffType.WEIGHTED)
	else:
		debuffs_changed.emit()

## Every Hexed instance — each one claims its own card in hand.
func get_hexed_debuffs() -> Array[Debuff]:
	var out: Array[Debuff] = []
	for d in debuffs:
		if d.debuff_type == Debuff.DebuffType.HEXED:
			out.append(d)
	return out

## The deck whose hand Hexed / Locked claim cards from (a DeckManager —
## untyped to dodge the cycle). The owning player's own deck is the truth; a
## bare manager (tests, a co-op deck before its first render) falls back to
## whichever deck last bound itself (DeckManager.assign_hexed_locked_cards).
var hand_owner = null

func _claim_deck():
	if owner_node and is_instance_valid(owner_node) and owner_node.has_method("get_deck_manager"):
		var own_deck = owner_node.get_deck_manager()
		if own_deck:
			return own_deck
	if hand_owner and is_instance_valid(hand_owner):
		return hand_owner
	return null

## The card at a hand index. A claim belongs to a card, not a slot: the
## index-based queries below only translate the slot the UI or a play asks
## about into the card sitting there now.
func _hand_card(index: int) -> Card:
	var deck = _claim_deck()
	if deck == null or index < 0 or index >= deck.hand.size():
		return null
	return deck.hand[index]

## Callers name a card either by its object or by its current hand index.
func _as_card(which) -> Card:
	if which is Card:
		return which
	if which is int:
		return _hand_card(which)
	return null

## Total hex surcharge on this card. Hexes usually spread across different
## cards, but stack onto one when there are more hexes than cards.
func card_hex_surcharge(card: Card) -> int:
	if card == null:
		return 0
	var total := 0
	for d in get_hexed_debuffs():
		if d.affected_card == card:
			total += d.value
	return total

func card_is_hexed(card: Card) -> bool:
	return _card_claimed(card, Debuff.DebuffType.HEXED)

func card_is_locked(card: Card) -> bool:
	return _card_claimed(card, Debuff.DebuffType.LOCKED)

func _card_claimed(card: Card, type: Debuff.DebuffType) -> bool:
	# A null card never matches: an unassigned claim holds no card at all.
	if card == null:
		return false
	for d in debuffs:
		if d.debuff_type == type and d.affected_card == card:
			return true
	return false

func get_hexed_mana_increase(index: int) -> int:
	return card_hex_surcharge(_hand_card(index))

func is_card_hexed(index: int) -> bool:
	return card_is_hexed(_hand_card(index))

## Playing a hexed card (paying its surcharge) clears every hex riding it.
## Takes the Card or its current hand index.
func remove_hexes_on_card(which) -> void:
	var card := _as_card(which)
	if card == null:
		return
	_drop_claims_where(func(d): return d.debuff_type == Debuff.DebuffType.HEXED \
			and d.affected_card == card, "hex broken")

## Every Locked instance — like Hexed, each one claims its own card in hand.
func get_locked_debuffs() -> Array[Debuff]:
	var out: Array[Debuff] = []
	for d in debuffs:
		if d.debuff_type == Debuff.DebuffType.LOCKED:
			out.append(d)
	return out

## The hand index of the FIRST Locked instance's card (-1 when none, or when
## it holds no card yet). Single-lock callers (the hand-slot grouping) read
## this; anything that must see every lock walks is_card_locked.
func get_locked_card_index() -> int:
	var locked = get_debuff(Debuff.DebuffType.LOCKED)
	var deck = _claim_deck()
	if locked == null or locked.affected_card == null or deck == null:
		return -1
	return deck.hand.find(locked.affected_card)

func is_card_locked(index: int) -> bool:
	return card_is_locked(_hand_card(index))

## The card a lock held left the hand (discarded, erased) or was played
## through a bypass: the lock had nothing left to hold and goes with it.
## Takes the Card or its current hand index.
func remove_locks_on_card(which) -> void:
	var card := _as_card(which)
	if card == null:
		return
	_drop_claims_where(func(d): return d.debuff_type == Debuff.DebuffType.LOCKED \
			and d.affected_card == card, "lock lifted")

## A card left the hand by being played — the sheet's "until played" — so
## every hex and lock riding it ends.
func release_card_claims(card: Card) -> void:
	if card == null:
		return
	_drop_claims_where(func(d): return (d.debuff_type == Debuff.DebuffType.HEXED \
			or d.debuff_type == Debuff.DebuffType.LOCKED) and d.affected_card == card, "card played")

## The one rule for every other way out of the hand (discard, jail, steal,
## reaction, hatch, erase…): a hex or lock whose card is no longer in `hand`
## ends with it — no other card inherits it. Unassigned claims wait.
func drop_claims_not_in(hand: Array) -> void:
	_drop_claims_where(func(d): return (d.debuff_type == Debuff.DebuffType.HEXED \
			or d.debuff_type == Debuff.DebuffType.LOCKED) and d.affected_card != null \
			and not hand.has(d.affected_card), "card left the hand")

## Removes every claim matching `pred`, then announces them. The signals go
## out only once the list is settled: a listener (a belt conjuring a tonic on
## debuff_removed) can change the hand, which sweeps claims again.
func _drop_claims_where(pred: Callable, why: String) -> void:
	var dropped: Array[Debuff] = []
	for i in range(debuffs.size() - 1, -1, -1):
		if pred.call(debuffs[i]):
			dropped.append(debuffs[i])
			debuffs.remove_at(i)
	if dropped.is_empty():
		return
	for d in dropped:
		print("[DEBUFF] %s on %s ends (%s)" % [d.debuff_name, d.affected_card.card_name if d.affected_card else "?", why])
		debuff_removed.emit(d)
	debuffs_changed.emit()

func get_clumsy_chance() -> int:
	# Fixed chance while any stacks remain; the stacks fall on the clock.
	return Debuff.CLUMSY_CHANCE if has_debuff(Debuff.DebuffType.CLUMSY) else 0

func roll_clumsy() -> bool:
	# Returns true if clumsy triggers (should discard a card)
	var chance = get_clumsy_chance()
	if chance > 0:
		var roll = randi() % 100
		if roll < chance:
			print("[DEBUFF] Clumsy triggered! (%d < %d)" % [roll, chance])
			return true
	return false

func get_damage_reduction_percent() -> float:
	var reduction := 0.0
	# Cursed: always 20% less damage dealt
	if has_debuff(Debuff.DebuffType.CURSED):
		reduction += 0.2
	# Weakened (mirrors the enemy-side Weaken): -30% damage dealt while any
	# stacks remain; attacking burns nothing, the stacks fall on the clock.
	var weakened = get_debuff(Debuff.DebuffType.WEAKENED)
	if weakened and weakened.value > 0:
		reduction += Debuff.WEAKENED_REDUCTION / 100.0
	return minf(reduction, 0.9)

func get_self_damage_percent() -> float:
	# Cursed: always 20% damage to self
	var cursed = get_debuff(Debuff.DebuffType.CURSED)
	if cursed:
		return 0.2
	return 0.0

# ============================================
# MOVEMENT EFFECTS
# ============================================

func on_movement(tiles_moved: int) -> int:
	# Bleed: 1 damage per tile moved, and each point of damage removes a stack.
	var bleed = get_debuff(Debuff.DebuffType.BLEED)
	if bleed:
		var damage = mini(bleed.value, tiles_moved)
		if damage <= 0:
			return 0
		bleed.value -= damage
		bleed._set_name_and_description()
		if owner_stats:
			owner_stats.take_damage(damage)
		print("[DEBUFF] Bleed triggered: %d damage from %d tiles (%d stack(s) left)" % [damage, tiles_moved, bleed.value])
		if bleed.value <= 0:
			remove_debuff(Debuff.DebuffType.BLEED)
			print("[DEBUFF] Bleed expired (0 stacks)")
		else:
			debuffs_changed.emit()
		return damage
	return 0

func on_attack() -> int:
	# Weakened no longer burns here: the attack was reduced and the stacks
	# fall on their own clock. Only Burn reacts to an attack.
	var burn = get_debuff(Debuff.DebuffType.BURN)
	if burn:
		# Burn on-attack uses the current burn_damage_next value
		if owner_stats:
			owner_stats.take_damage(burn_damage_next)
		print("[DEBUFF] Burn triggered on attack: %d damage" % burn_damage_next)
		return burn_damage_next
	return 0

# ============================================
# DISPLAY
# ============================================

# ============================================
# ACTION QUERIES
# ============================================

## Stun stops everything: no card, attack, block, move, skill, Flash/Brain
## spend or gear swap while it holds. Only Wait (passing time) stays open —
## otherwise a stun could never tick off. Frozen is NOT here: it only stops
## card plays (can_play_cards).
func can_act() -> bool:
	return not has_debuff(Debuff.DebuffType.STUN)

## Blind's miss roll for an attack that is not a card (the auto attack, Flash
## Cut): the same constant chance an Attack card rolls in Card._execute_card.
func roll_blind_miss() -> bool:
	var chance := get_blind_miss_chance()
	return chance > 0.0 and randf() < chance
