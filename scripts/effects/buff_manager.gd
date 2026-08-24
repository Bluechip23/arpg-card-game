class_name BuffManager
extends Node

## Manages buffs on a character (player or enemy)

signal buff_applied(buff: Buff)
signal buff_removed(buff: Buff)
signal buff_ticked(buff: Buff)
signal buffs_changed
signal thorns_triggered(damage: int)
signal cleanse_triggered(count: int)

var buffs: Array[Buff] = []
var owner_stats = null  # PlayerStats - untyped to avoid circular dependency
var owner_node: Node3D
var debuff_manager = null  # DebuffManager - untyped to avoid circular dependency
var approach_armor_per_move: int = 0
var approach_tempo_remaining: int = 0
var understanding_tempo: int = 0  # Delayed crit: when reaches 0, apply ENLIGHTENED
var enchanted_quiver_charges: int = 0  # Next N ranged attacks create a free arrow card
var tighten_string_charges: int = 0  # Next N ranged attacks: +3 tempo, +6 dmg, +6 range, +20% crit
var last_crit_hit: bool = false      # Set true when roll_crit succeeds, cleared after checking

func initialize(stats = null, owner: Node3D = null) -> void:
	owner_stats = stats
	owner_node = owner
	buffs.clear()

func connect_debuff_manager(dm) -> void:
	debuff_manager = dm

# ============================================
# ADDING/REMOVING BUFFS
# ============================================

func apply_buff(buff: Buff) -> void:
	# Sphere-grid buff amps: buffs YOU gain arrive stronger (playstyle
	# amplification nodes). Runs before Cleanse so its amp counts too.
	_amp_incoming_buff(buff)

	# Handle Cleanse immediately
	if buff.buff_type == Buff.BuffType.CLEANSE:
		_execute_cleanse(buff.value)
		return

	# Check if buff already exists (refresh or stack)
	var existing = get_buff(buff.buff_type)
	
	if existing:
		# Refresh duration/charges to higher value
		if buff.is_charge_based():
			existing.charges = max(existing.charges, buff.charges)
		else:
			existing.duration = max(existing.duration, buff.duration)
		
		# Stack value for stackable buffs
		if _is_stackable(buff.buff_type):
			existing.stacks += 1
			existing.value += buff.value
			existing._set_name_and_description()
		
		print("[BUFF] %s refreshed/stacked (value: %d)" % [buff.buff_name, existing.value])
	else:
		buffs.append(buff)
		print("[BUFF] Applied: %s for %s" % [buff.buff_name, buff.get_duration_display()])
	
	_recompute_might()
	buff_applied.emit(buff)
	buffs_changed.emit()

## Sphere-grid amp nodes strengthen matching buffs at application time, so the
## badge, description, and mechanics all agree. Enlightened's crit amp lives in
## get_enlightened_crit_chance instead (its value field is the auto-crit flag).
func _amp_incoming_buff(buff: Buff) -> void:
	if owner_stats == null:
		return
	match buff.buff_type:
		Buff.BuffType.HASTE:
			if "sphere_haste_amp" in owner_stats and owner_stats.sphere_haste_amp > 0:
				buff.charges += owner_stats.sphere_haste_amp
				buff._set_name_and_description()
		Buff.BuffType.BLESSED:
			var changed := false
			if "sphere_blessed_draw_amp" in owner_stats and owner_stats.sphere_blessed_draw_amp > 0:
				buff.value += owner_stats.sphere_blessed_draw_amp
				changed = true
			if "sphere_blessed_amp" in owner_stats and owner_stats.sphere_blessed_amp > 0:
				buff.charges += owner_stats.sphere_blessed_amp
				changed = true
			if changed:
				buff._set_name_and_description()
		Buff.BuffType.BRACE:
			if "sphere_brace_amp" in owner_stats and owner_stats.sphere_brace_amp > 0:
				buff.value += owner_stats.sphere_brace_amp
				buff._set_name_and_description()
		Buff.BuffType.STRENGTHEN:
			if "sphere_strengthen_amp" in owner_stats and owner_stats.sphere_strengthen_amp > 0:
				buff.value += owner_stats.sphere_strengthen_amp
				buff._set_name_and_description()
		Buff.BuffType.BOLSTER:
			if "sphere_bolster_amp" in owner_stats and owner_stats.sphere_bolster_amp > 0:
				buff.value += owner_stats.sphere_bolster_amp
				buff._set_name_and_description()
		Buff.BuffType.CLEANSE:
			if "sphere_cleanse_amp" in owner_stats and owner_stats.sphere_cleanse_amp > 0:
				buff.value += owner_stats.sphere_cleanse_amp
		Buff.BuffType.RESILIENT:
			if "sphere_resilient_amp" in owner_stats and owner_stats.sphere_resilient_amp > 0:
				buff.value += owner_stats.sphere_resilient_amp
				buff._set_name_and_description()

func _is_stackable(type: Buff.BuffType) -> bool:
	match type:
		Buff.BuffType.THORNS, Buff.BuffType.REGEN, Buff.BuffType.STRENGTHEN, Buff.BuffType.BOLSTER, \
		Buff.BuffType.KEEN, Buff.BuffType.MIGHT:
			return true
	return false

## Might (Ragnarok): mirror the summed MIGHT value onto the owner's
## temp_strength_bonus so STR-derived damage picks it up. Called whenever the
## buff list changes.
func _recompute_might() -> void:
	if not owner_stats or not "temp_strength_bonus" in owner_stats:
		return
	var total := 0
	for buff in buffs:
		if buff.buff_type == Buff.BuffType.MIGHT:
			total += buff.value
	owner_stats.temp_strength_bonus = total

func remove_buff(type: Buff.BuffType) -> void:
	for i in range(buffs.size() - 1, -1, -1):
		if buffs[i].buff_type == type:
			var removed = buffs[i]
			buffs.remove_at(i)
			_recompute_might()
			buff_removed.emit(removed)
			buffs_changed.emit()
			print("[BUFF] Removed: %s" % removed.buff_name)
			return

func get_buff(type: Buff.BuffType) -> Buff:
	for buff in buffs:
		if buff.buff_type == type:
			return buff
	return null

func has_buff(type: Buff.BuffType) -> bool:
	return get_buff(type) != null

func clear_all_buffs() -> void:
	buffs.clear()
	_recompute_might()
	buffs_changed.emit()
	print("[BUFF] All buffs cleared")

# ============================================
# TURN PROCESSING
# ============================================

func process_turn_start() -> Dictionary:
	var result = {
		"health_gained": 0,
		"mana_gained": 0,
		"armor_gained": 0,
		"extra_draws": 0
	}
	
	var depleted: Array[Buff] = []
	for buff in buffs:
		match buff.buff_type:
			Buff.BuffType.REGEN:
				result["health_gained"] += buff.value
				print("[BUFF] Regen heals %d" % buff.value)

			Buff.BuffType.FOCUSED:
				result["mana_gained"] += 10
				print("[BUFF] Focused grants +10 mana")

			Buff.BuffType.BLESSED:
				# Charge-based: the cycle's extra draws burn one charge.
				result["extra_draws"] += buff.value
				print("[BUFF] Blessed grants %d extra draw(s)" % buff.value)
				if buff.use_charge():
					depleted.append(buff)

			Buff.BuffType.SMITH:
				result["armor_gained"] += buff.value
				print("[BUFF] Smith grants %d armor" % buff.value)
	for buff in depleted:
		remove_buff(buff.buff_type)
	
	# Apply effects
	if owner_stats:
		if result["health_gained"] > 0:
			# Regen ticks are not "actual heals" — ring heal counters skip them.
			owner_stats._passive_heal = true
			owner_stats.heal(result["health_gained"])
			owner_stats._passive_heal = false
		if result["mana_gained"] > 0:
			owner_stats.gain_mana(result["mana_gained"])
		if result["armor_gained"] > 0:
			owner_stats.add_armor(result["armor_gained"])
	
	return result

## Advance timed buff durations by raw tempo. Called on every tempo advance
## (any amount), so durations not divisible by 5 work.
func advance_time(amount: int) -> void:
	if amount <= 0:
		return
	# Tick approach armor-on-move
	if approach_tempo_remaining > 0:
		approach_tempo_remaining -= amount
		if approach_tempo_remaining <= 0:
			approach_tempo_remaining = 0
			approach_armor_per_move = 0
			print("[BUFF] Approach expired")

	# Tick understanding delayed crit
	if understanding_tempo > 0:
		understanding_tempo -= amount
		if understanding_tempo <= 0:
			understanding_tempo = 0
			apply_buff(Buff.create_enlightened(100, 1, "Understanding"))
			print("[BUFF] Understanding ready! Next attack will auto-crit")

	var expired: Array[Buff] = []
	for buff in buffs:
		if not buff.is_charge_based():
			# Flag-driven display wrappers (Elixir / GENERIC) have their
			# lifecycle driven by sync_flag_buffs(), not the duration tick.
			if buff.buff_type == Buff.BuffType.ELIXIR or buff.buff_type == Buff.BuffType.GENERIC:
				continue
			buff_ticked.emit(buff)
			if buff.advance_time(amount):
				expired.append(buff)

	for buff in expired:
		# Morphine penalty on expiry: take 2 damage. The temp HP itself lives in
		# the PlayerStats temp-health pool and expires on its own matching timer.
		if buff.buff_type == Buff.BuffType.MORPHINE and owner_stats:
			owner_stats.take_damage(2)
			print("[BUFF] Morphine expired! Took 2 damage")

		# Shield Ready's delayed payload: the promised armor lands when the
		# countdown runs out.
		if buff.buff_type == Buff.BuffType.SHIELD_READY and owner_stats:
			owner_stats.add_armor(buff.value)
			print("[BUFF] Shield Ready! +%d armor lands" % buff.value)

		buffs.erase(buff)
		buff_removed.emit(buff)
		print("[BUFF] Expired: %s" % buff.buff_name)

	if expired.size() > 0:
		_recompute_might()
		buffs_changed.emit()

func process_turn_end() -> void:
	# Regen and Smith: lose 1 value at end of turn (Smith is "Regen for armor").
	for decay_type in [Buff.BuffType.REGEN, Buff.BuffType.SMITH]:
		var decaying = get_buff(decay_type)
		if decaying:
			decaying.value -= 1
			decaying._set_name_and_description()
			if decaying.value <= 0:
				remove_buff(decay_type)
				print("[BUFF] %s expired (0 stacks remaining)" % decaying.buff_name)
			else:
				print("[BUFF] %s decayed to %d" % [decaying.buff_name, decaying.value])
				buffs_changed.emit()

	# Timed durations no longer tick here — advance_time (above) runs on every
	# raw tempo advance so durations like "3 tempo" work.

	# Keep the flag-driven display buffs in sync with their source state and
	# refresh their shown duration/count.
	sync_flag_buffs()

func sync_flag_buffs() -> void:
	## Surfaces effects that are tracked as raw flags (not real Buffs) as visible
	## badges. Safe to call any time — it adds/updates/removes to match state.
	# Elixir — stack state lives on owner_stats (one stack per poison tick healed).
	var elixir_on: bool = owner_stats != null and "elixir_stacks" in owner_stats and owner_stats.elixir_stacks > 0
	if elixir_on:
		var ex = get_buff(Buff.BuffType.ELIXIR)
		if ex == null:
			ex = Buff.create_elixir(owner_stats.elixir_stacks, "Elixir")
			apply_buff(ex)
		ex.stacks = owner_stats.elixir_stacks
		ex.description = "Your next %d poison ticks heal you instead of dealing damage" % ex.stacks
	elif has_buff(Buff.BuffType.ELIXIR):
		remove_buff(Buff.BuffType.ELIXIR)

	# --- Generic flag effects (raw flags elsewhere, surfaced as display badges) ---
	var has_stats: bool = owner_stats != null

	# Raged Circulation — +30% healing (owner_stats).
	var raged_on: bool = has_stats and "healing_boost_percent" in owner_stats and owner_stats.healing_boost_percent > 0.0
	_sync_generic("raged_circulation", raged_on, "Raged Circulation",
		"Healing and regen are +%d%% effective" % (int(owner_stats.healing_boost_percent * 100) if has_stats else 30),
		Color(0.75, 0.18, 0.20), (owner_stats.healing_boost_tempo if has_stats else 0), 1)

	# Understanding — pending auto-crit countdown (this manager).
	_sync_generic("understanding", understanding_tempo > 0, "Understanding",
		"Your next attack will critically strike", Color(0.25, 0.66, 0.96), understanding_tempo, 1)

	# Approach — armor gained per tile moved (this manager).
	var approach_on: bool = approach_armor_per_move > 0 and approach_tempo_remaining > 0
	_sync_generic("approach", approach_on, "Approach",
		"+%d armor for every tile you move" % approach_armor_per_move,
		Color(0.5, 0.55, 0.6), approach_tempo_remaining, 1)

	# Enchanted Quiver — next N ranged attacks spawn a free arrow (charge-based).
	_sync_generic("enchanted_quiver", enchanted_quiver_charges > 0, "Enchanted Quiver",
		"Next %d ranged attacks create a free arrow card" % enchanted_quiver_charges,
		Color(0.15, 0.68, 0.38), -1, enchanted_quiver_charges)

	# Tighten String — next N ranged attacks buffed (charge-based).
	_sync_generic("tighten_string", tighten_string_charges > 0, "Tighten String",
		"Next %d ranged attacks: +6 dmg, +6 range, +20%% crit" % tighten_string_charges,
		Color(0.95, 0.77, 0.09), -1, tighten_string_charges)

	# Loaded Die / House Money — next RNG roll boosted (owner_stats).
	var odds_on: bool = has_stats and "next_odds_boost" in owner_stats and owner_stats.next_odds_boost > 0.0
	_sync_generic("loaded_die", odds_on, "Loaded Die",
		"Your next chance roll is +%d%%" % (int(owner_stats.next_odds_boost) if has_stats else 0),
		Color(0.61, 0.35, 0.71), -1, 1)

func _get_generic(key: String) -> Buff:
	for b in buffs:
		if b.buff_type == Buff.BuffType.GENERIC and b.custom_icon_key == key:
			return b
	return null

func _sync_generic(key: String, present: bool, display_name: String, desc: String, color: Color, tempo: int, count: int) -> void:
	var existing = _get_generic(key)
	if present:
		if existing:
			existing.duration = tempo
			existing.description = desc
			existing.stacks = max(count, 1)
		else:
			# Append directly — apply_buff() matches by buff_type only and would
			# wrongly merge distinct GENERIC badges.
			var buff = Buff.create_generic(key, display_name, desc, color, tempo, count)
			buffs.append(buff)
			buff_applied.emit(buff)
			buffs_changed.emit()
	elif existing:
		buffs.erase(existing)
		buff_removed.emit(existing)
		buffs_changed.emit()

# ============================================
# COMBAT QUERIES
# ============================================

func get_thorns_damage() -> int:
	var thorns = get_buff(Buff.BuffType.THORNS)
	return thorns.value if thorns else 0

func on_attacked(attacker) -> void:
	# Sphere grid passive thorns (permanent, doesn't decay)
	var sphere_thorns = 0
	if owner_stats and "sphere_bonus_thorns" in owner_stats:
		sphere_thorns = owner_stats.sphere_bonus_thorns
	if sphere_thorns > 0 and attacker and attacker.has_method("take_damage"):
		attacker.take_damage(sphere_thorns)
		thorns_triggered.emit(sphere_thorns)
		print("[BUFF] Sphere Grid thorns deals %d damage to attacker!" % sphere_thorns)

	# Buff-based thorns (temporary, decays per hit)
	var thorns = get_buff(Buff.BuffType.THORNS)
	if thorns and thorns.value > 0 and attacker and attacker.has_method("take_damage"):
		attacker.take_damage(thorns.value)
		thorns_triggered.emit(thorns.value)
		print("[BUFF] Thorns deals %d damage to attacker!" % thorns.value)
		# Lose 1 thorn after each hit. Vined Encasing thorns skip this — they
		# shed via decay_thorns_by_damage instead.
		if not thorns.decay_by_damage:
			thorns.value -= 1
			thorns._set_name_and_description()
			if thorns.value <= 0:
				remove_buff(Buff.BuffType.THORNS)
				print("[BUFF] Thorns expired (0 stacks remaining)")
			else:
				buffs_changed.emit()

## Vined Encasing (Briarhide Plate): "lose X thorns when you receive X damage".
## Called from PlayerStats.take_damage with the post-mitigation damage amount.
func decay_thorns_by_damage(amount: int) -> void:
	if amount <= 0:
		return
	var thorns = get_buff(Buff.BuffType.THORNS)
	if thorns == null or not thorns.decay_by_damage:
		return
	thorns.value -= amount
	thorns._set_name_and_description()
	if thorns.value <= 0:
		remove_buff(Buff.BuffType.THORNS)
		print("[BUFF] Vined Encasing thorns shredded away")
	else:
		buffs_changed.emit()
		print("[BUFF] Vined Encasing: -%d thorns (%d left)" % [amount, thorns.value])

func has_wear_down() -> bool:
	return has_buff(Buff.BuffType.WEAR_DOWN)

func has_armor_break() -> bool:
	return has_buff(Buff.BuffType.ARMOR_BREAK)

func consume_armor_break() -> bool:
	var ab = get_buff(Buff.BuffType.ARMOR_BREAK)
	if ab:
		if ab.use_charge():
			remove_buff(Buff.BuffType.ARMOR_BREAK)
		return true
	return false

func is_invisible() -> bool:
	return has_buff(Buff.BuffType.INVISIBLE)

func has_life_steal() -> bool:
	return has_buff(Buff.BuffType.LIFE_STEAL)

func consume_life_steal(damage_dealt: int) -> int:
	var life_steal = get_buff(Buff.BuffType.LIFE_STEAL)
	if life_steal:
		# value 0 = legacy full-damage heal; value > 0 = percentage of damage
		# (Resourceful Replenish's 5% / 8%).
		var stolen = damage_dealt
		if life_steal.value > 0:
			stolen = max(1, floori(damage_dealt * life_steal.value / 100.0))
		if life_steal.use_charge():
			remove_buff(Buff.BuffType.LIFE_STEAL)
		if owner_stats:
			# Player stats funnel life steal through apply_life_steal (Sanguine
			# Barrier keystone may convert it to temp HP); enemies just heal.
			if owner_stats.has_method("apply_life_steal"):
				owner_stats.apply_life_steal(stolen)
			else:
				owner_stats.heal(stolen)
			print("[BUFF] Life Steal recovered %d!" % stolen)
		return stolen
	return 0

func get_strengthen_bonus() -> int:
	var strengthen = get_buff(Buff.BuffType.STRENGTHEN)
	return strengthen.value if strengthen else 0

func consume_strengthen() -> int:
	# Returns bonus and uses a charge
	var strengthen = get_buff(Buff.BuffType.STRENGTHEN)
	if strengthen:
		var bonus = strengthen.value
		if strengthen.use_charge():
			remove_buff(Buff.BuffType.STRENGTHEN)
		return bonus
	return 0

func get_enlightened_crit_chance() -> int:
	# Enlightened grants the buff's own crit % while any stacks remain (most
	# sources grant 10; rank-scaled sources like Brad's Redemption pass 1..15).
	# Multiple stacks never raise the percentage — they only extend how many
	# attacks it lasts.
	var enlightened = get_buff(Buff.BuffType.ENLIGHTENED)
	if enlightened == null:
		return 0
	# Understanding's delayed auto-crit stores value 100 — a guaranteed crit
	# source stays guaranteed; everything else is the buff's % plus the
	# sphere-grid Enlight Amp.
	if enlightened.value >= 100:
		return 100
	var amp := 0
	if owner_stats and "sphere_enlightened_amp" in owner_stats:
		amp = int(owner_stats.sphere_enlightened_amp)
	return maxi(1, enlightened.value) + amp

func roll_crit(base_crit_chance: int = 0) -> bool:
	# Include the character's innate base crit chance (default 5%)
	var innate_crit = 0
	if owner_stats and "base_crit_chance" in owner_stats:
		innate_crit = owner_stats.base_crit_chance
	var sphere_crit = 0.0
	if owner_stats and "sphere_bonus_crit" in owner_stats:
		sphere_crit = owner_stats.sphere_bonus_crit
	if owner_stats and "equipment_crit_bonus" in owner_stats:
		sphere_crit += owner_stats.equipment_crit_bonus
	# One-shot on-self crit (Monocle: offensive ranged slotted card)
	if owner_stats and "temp_on_self_crit_bonus" in owner_stats:
		sphere_crit += owner_stats.temp_on_self_crit_bonus
	# Smoke bomb zone: crit while standing in the cloud
	if owner_stats and "aura_crit_bonus" in owner_stats:
		sphere_crit += owner_stats.aura_crit_bonus
	# Exposed Blind Spot: one-time crit bonus from being attacked
	var ebs_crit = 0
	if owner_stats and "st_exposed_blind_spot_crit" in owner_stats:
		ebs_crit = owner_stats.st_exposed_blind_spot_crit
	# Tactician's Eye (WIS keystone): crit chance scaling with cards in hand.
	var hand_crit = 0
	if owner_stats and owner_stats.has_method("get_hand_size_crit_bonus"):
		hand_crit = owner_stats.get_hand_size_crit_bonus()
	# Keen (Ragnarok): timed flat crit chance.
	var keen_crit = 0
	var keen_buff = get_buff(Buff.BuffType.KEEN)
	if keen_buff:
		keen_crit = keen_buff.value
	var total_chance = innate_crit + base_crit_chance + get_enlightened_crit_chance() + int(sphere_crit) + ebs_crit + hand_crit + keen_crit
	if total_chance <= 0:
		return false

	var roll = randi() % 100
	var is_crit = roll < total_chance

	# Consume Exposed Blind Spot bonus after rolling (win or lose)
	if ebs_crit > 0 and owner_stats:
		owner_stats.st_exposed_blind_spot_crit = 0

	# Enlightened is "+X% crit for the next Y ATTACKS": every attack roll spends
	# a charge, crit or not. (Consuming only on successful crits let the buff
	# outlast its stated attack count ~3x.)
	var enlightened = get_buff(Buff.BuffType.ENLIGHTENED)
	if enlightened:
		if enlightened.use_charge():
			remove_buff(Buff.BuffType.ENLIGHTENED)

	if is_crit:
		print("[BUFF] CRITICAL HIT! (rolled %d < %d)" % [roll, total_chance])
		last_crit_hit = true

	return is_crit

func get_bolster_bonus() -> int:
	var bolster = get_buff(Buff.BuffType.BOLSTER)
	return bolster.value if bolster else 0

func consume_bolster() -> int:
	# Called when gaining armor - returns bonus and uses a charge
	var bolster = get_buff(Buff.BuffType.BOLSTER)
	if bolster:
		var bonus = bolster.value
		if bolster.use_charge():
			remove_buff(Buff.BuffType.BOLSTER)
		return bonus
	return 0

# ============================================
# MOVEMENT QUERIES
# ============================================

func get_haste_bonus() -> int:
	var haste = get_buff(Buff.BuffType.HASTE)
	return haste.value if haste else 0

func get_extra_movement_per_tempo() -> int:
	return get_haste_bonus()

func consume_haste() -> void:
	# One charge per (non-flash) move action.
	var haste = get_buff(Buff.BuffType.HASTE)
	if haste and haste.use_charge():
		remove_buff(Buff.BuffType.HASTE)

# ============================================
# POISONED BLOOD (heal cards deal damage; one charge per converted heal)
# ============================================

func has_poisoned_blood() -> bool:
	return has_buff(Buff.BuffType.POISONED_BLOOD)

func consume_poisoned_blood() -> void:
	var pb = get_buff(Buff.BuffType.POISONED_BLOOD)
	if pb and pb.use_charge():
		remove_buff(Buff.BuffType.POISONED_BLOOD)

func on_movement(tiles: int) -> int:
	var armor_gained = 0
	if approach_armor_per_move > 0 and approach_tempo_remaining > 0:
		armor_gained = approach_armor_per_move * tiles
		if owner_stats:
			owner_stats.add_armor(armor_gained)
			print("[BUFF] Approach grants %d armor from movement" % armor_gained)
	return armor_gained

# ============================================
# ARMOR QUERIES
# ============================================

func should_ignore_armor_decay() -> bool:
	return has_buff(Buff.BuffType.FORTIFY)

# ============================================
# DRAW QUERIES
# ============================================

func get_extra_draws() -> int:
	var blessed = get_buff(Buff.BuffType.BLESSED)
	return blessed.value if blessed else 0

# ============================================
# CLEANSE
# ============================================

func _execute_cleanse(count: int) -> void:
	if not debuff_manager:
		print("[BUFF] Cleanse failed - no debuff manager connected")
		return
	
	var removed = 0
	var debuffs_to_remove = debuff_manager.debuffs.duplicate()
	debuffs_to_remove.shuffle()  # Random order
	
	for i in range(min(count, debuffs_to_remove.size())):
		var debuff = debuffs_to_remove[i]
		debuff_manager.remove_debuff(debuff.debuff_type)
		removed += 1
	
	cleanse_triggered.emit(removed)
	print("[BUFF] Cleanse removed %d debuff(s)" % removed)

# ============================================
# DISPLAY
# ============================================

func get_buff_display_list() -> Array[String]:
	var list: Array[String] = []
	for buff in buffs:
		list.append("%s (%s)" % [buff.get_short_display(), buff.get_duration_display()])
	return list
	
# ============================================
# DAMAGE REDUCTION QUERIES (Brace, Resilient)
# ============================================

func get_brace_reduction() -> int:
	var brace = get_buff(Buff.BuffType.BRACE)
	return brace.value if brace else 0

func consume_brace() -> int:
	# Returns percent damage reduction and uses charge
	var brace = get_buff(Buff.BuffType.BRACE)
	if brace:
		var percent = brace.value
		if brace.use_charge():
			remove_buff(Buff.BuffType.BRACE)
		return percent
	return 0

func get_resilient_percent(damage_type: int = -1) -> int:
	var resilient = get_buff(Buff.BuffType.RESILIENT)
	if not resilient:
		return 0
	# A typed Resilient (e.g. Harden = Physical) only reduces matching damage.
	if resilient.damage_type != -1 and damage_type != -1 and resilient.damage_type != damage_type:
		return 0
	return resilient.value

func consume_resilient() -> int:
	# Returns percent reduction and uses charge
	var resilient = get_buff(Buff.BuffType.RESILIENT)
	if resilient:
		var percent = resilient.value
		if resilient.use_charge():
			remove_buff(Buff.BuffType.RESILIENT)
		return percent
	return 0

func calculate_damage_reduction(incoming_damage: int, damage_type: int = -1) -> int:
	# Calculate total damage after Resilient and Brace
	var damage = incoming_damage

	# Resilient: percentage reduction first (turn-based, always active while buff exists)
	var resilient_percent = get_resilient_percent(damage_type)
	if resilient_percent > 0:
		var reduction = floori(damage * resilient_percent / 100.0)
		damage -= reduction
		print("[BUFF] Resilient reduces damage by %d%% (%d)" % [resilient_percent, reduction])

	# Brace: percentage reduction second (charge-based, consumes a charge)
	var brace_percent = consume_brace()
	if brace_percent > 0:
		var reduction = floori(damage * brace_percent / 100.0)
		damage -= reduction
		print("[BUFF] Brace reduces damage by %d%% (%d)" % [brace_percent, reduction])

	return max(0, damage)
	
# ============================================
# TEMPO QUERIES (Steady)
# ============================================

func should_skip_tempo() -> bool:
	return has_buff(Buff.BuffType.STEADY)

func consume_steady() -> bool:
	# Returns true if Steady was active and consumed
	var steady = get_buff(Buff.BuffType.STEADY)
	if steady:
		if steady.use_charge():
			remove_buff(Buff.BuffType.STEADY)
		return true
	return false

# ============================================
# DEMONIC RAGE (mana costs use health instead)
# ============================================

func has_demonic_rage() -> bool:
	return has_buff(Buff.BuffType.DEMONIC_RAGE)

func consume_demonic_rage() -> bool:
	# Consume one charge. Returns true if buff was active.
	var dr = get_buff(Buff.BuffType.DEMONIC_RAGE)
	if dr:
		if dr.use_charge():
			remove_buff(Buff.BuffType.DEMONIC_RAGE)
		return true
	return false
