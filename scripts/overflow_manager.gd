class_name OverflowManager
extends Node

## Manages overflow effects on the player

signal overflow_effect_added(effect: OverflowEffect)
signal overflow_effect_removed(effect: OverflowEffect)
signal overflow_effects_changed
signal manifest_card_added(manifest_name: String, card: Card)
signal overcharge_triggered(effect_id: String, value: int)
signal peak_triggered(card: Card)

# Active overflow effects
var overflow_effects: Array[OverflowEffect] = []

# Manifest zone - stores cards with their manifest effect info
var manifest_zone: Array[Dictionary] = []  # { "card": Card, "effect": OverflowEffect }

# For application order tracking
var _application_counter: int = 0

# References
var player_stats: PlayerStats
var deck_manager  # Forward declaration to avoid circular dependency

func initialize(p_stats: PlayerStats) -> void:
	player_stats = p_stats
	overflow_effects.clear()
	manifest_zone.clear()
	_application_counter = 0

func connect_deck_manager(dm) -> void:
	deck_manager = dm

# ============================================
# ADDING/REMOVING OVERFLOW EFFECTS
# ============================================

func add_overflow_effect(effect: OverflowEffect) -> void:
	effect.application_order = _application_counter
	_application_counter += 1
	
	overflow_effects.append(effect)
	overflow_effect_added.emit(effect)
	overflow_effects_changed.emit()
	
	print("[OVERFLOW] Added: %s (source: %s)" % [effect.get_display_text(), effect.source_name])

func remove_overflow_effect(effect: OverflowEffect) -> void:
	var index = overflow_effects.find(effect)
	if index >= 0:
		overflow_effects.remove_at(index)
		overflow_effect_removed.emit(effect)
		overflow_effects_changed.emit()
		print("[OVERFLOW] Removed: %s" % effect.get_display_text())

func remove_overflow_by_source(source_name: String) -> void:
	for i in range(overflow_effects.size() - 1, -1, -1):
		if overflow_effects[i].source_name == source_name:
			var effect = overflow_effects[i]
			overflow_effects.remove_at(i)
			overflow_effect_removed.emit(effect)
	overflow_effects_changed.emit()

func clear_temporary_effects() -> void:
	for i in range(overflow_effects.size() - 1, -1, -1):
		if not overflow_effects[i].is_permanent:
			var effect = overflow_effects[i]
			overflow_effects.remove_at(i)
			overflow_effect_removed.emit(effect)
	overflow_effects_changed.emit()

# ============================================
# GET ACTIVE EFFECTS BY TYPE
# ============================================

func get_effects_by_type(type: OverflowEffect.OverflowType) -> Array[OverflowEffect]:
	var results: Array[OverflowEffect] = []
	for effect in overflow_effects:
		if effect.overflow_type == type:
			results.append(effect)
	return results

func has_effect_type(type: OverflowEffect.OverflowType) -> bool:
	for effect in overflow_effects:
		if effect.overflow_type == type:
			return true
	return false

func get_first_effect_of_type(type: OverflowEffect.OverflowType) -> OverflowEffect:
	for effect in overflow_effects:
		if effect.overflow_type == type:
			return effect
	return null

# ============================================
# OVERFLOW PROCESSING
# ============================================

func process_overflow(card: Card) -> void:
	# Called when player tries to draw but hand is full
	# Process effects in priority order
	
	print("[OVERFLOW] Processing overflow for card: %s" % card.card_name)
	
	# Priority 1: Jailed
	var jailed_effect = get_first_effect_of_type(OverflowEffect.OverflowType.JAILED)
	if jailed_effect:
		_process_jailed(card, jailed_effect)
		# Jailed blocks other primary effects, but Peak/Overcharge still trigger
		_process_secondary_effects(card)
		return
	
	# Priority 2: Manifest or Enhance (whichever was applied first)
	var manifest_effect = get_first_effect_of_type(OverflowEffect.OverflowType.MANIFEST)
	var enhance_effect = get_first_effect_of_type(OverflowEffect.OverflowType.ENHANCE)
	
	if manifest_effect and enhance_effect:
		# Use application order
		if manifest_effect.application_order < enhance_effect.application_order:
			_process_manifest(card, manifest_effect)
		else:
			_process_enhance(card, enhance_effect)
		_process_secondary_effects(card)
		return
	elif manifest_effect:
		_process_manifest(card, manifest_effect)
		_process_secondary_effects(card)
		return
	elif enhance_effect:
		_process_enhance(card, enhance_effect)
		_process_secondary_effects(card)
		return
	
	# Priority 3: Transferred
	var transferred_effect = get_first_effect_of_type(OverflowEffect.OverflowType.TRANSFERRED)
	if transferred_effect:
		_process_transferred(card, transferred_effect)
		_process_secondary_effects(card)
		return
	
	# No primary effect - just process secondary effects
	_process_secondary_effects(card)
	
	# If no effects at all, discard the card
	if overflow_effects.size() == 0:
		if deck_manager:
			deck_manager.discard_pile.append(card)
		print("[OVERFLOW] No effects active, card discarded: %s" % card.card_name)

func _process_secondary_effects(card: Card) -> void:
	# Peak and Overcharge don't block other effects
	
	# Peak - always show next card if active
	var peak_effect = get_first_effect_of_type(OverflowEffect.OverflowType.PEAK)
	if peak_effect:
		_process_peak(peak_effect)
	
	# Overcharge - triggers its effect
	var overcharge_effects = get_effects_by_type(OverflowEffect.OverflowType.OVERCHARGE)
	for effect in overcharge_effects:
		_process_overcharge(effect)

func _process_jailed(card: Card, effect: OverflowEffect) -> void:
	card.jail_time_remaining = 3
	if deck_manager:
		deck_manager.jail_pile.append(card)
		deck_manager.card_jailed.emit(card)
	
	print("[OVERFLOW] Jailed: %s for 3 turns" % card.card_name)
	
	if effect.use_charge():
		remove_overflow_effect(effect)

func _process_manifest(card: Card, effect: OverflowEffect) -> void:
	# Add card to manifest zone with the manifest effect info
	var manifest_entry = {
		"card": card,
		"effect": effect,
		"manifest_name": effect.effect_name,
		"manifest_id": effect.manifest_effect_id,
		"manifest_description": effect.manifest_description,
		"manifest_value": effect.effect_value,
		"mana_cost": effect.manifest_mana_cost,
		"tempo_cost": effect.manifest_tempo_cost
	}
	
	manifest_zone.append(manifest_entry)
	manifest_card_added.emit(effect.effect_name, card)
	
	print("[OVERFLOW] Manifest: %s → %s" % [card.card_name, effect.effect_name])
	
	if effect.use_charge():
		remove_overflow_effect(effect)

func _process_enhance(card: Card, effect: OverflowEffect) -> void:
	if card.card_type == Card.CardType.ATTACK and not card.is_enhanced:
		card.bonus_damage += effect.effect_value
		card.is_enhanced = true
		card.description = "%s (+%d enhanced)" % [card.description, effect.effect_value]
		print("[OVERFLOW] Enhanced: %s (+%d damage)" % [card.card_name, effect.effect_value])
	else:
		print("[OVERFLOW] Cannot enhance %s (not attack or already enhanced)" % card.card_name)
	
	if deck_manager:
		deck_manager.discard_pile.append(card)
	
	if effect.use_charge():
		remove_overflow_effect(effect)

func _process_transferred(card: Card, effect: OverflowEffect) -> void:
	# TODO: Transfer to ally if ally system exists
	if deck_manager:
		deck_manager.discard_pile.append(card)
	
	print("[OVERFLOW] Transferred: %s (discarded - no ally)" % card.card_name)
	
	if effect.use_charge():
		remove_overflow_effect(effect)

func _process_peak(effect: OverflowEffect) -> void:
	if deck_manager and deck_manager.draw_pile.size() > 0:
		var next_card = deck_manager.draw_pile.back()
		deck_manager.peaked_card = next_card
		deck_manager.card_peaked.emit(next_card)
		peak_triggered.emit(next_card)
		print("[OVERFLOW] Peak: Next card is %s" % next_card.card_name)
	
	if effect.use_charge():
		remove_overflow_effect(effect)

func _process_overcharge(effect: OverflowEffect) -> void:
	match effect.overcharge_effect_id:
		"gain_health":
			if player_stats:
				player_stats.heal(effect.effect_value)
			print("[OVERFLOW] Overcharge: +%d Health" % effect.effect_value)
		"gain_mana":
			if player_stats:
				player_stats.gain_mana(effect.effect_value)
			print("[OVERFLOW] Overcharge: +%d Mana" % effect.effect_value)
		"gain_armor":
			if player_stats:
				player_stats.add_armor(effect.effect_value)
			print("[OVERFLOW] Overcharge: +%d Armor" % effect.effect_value)
		"damage_all":
			overcharge_triggered.emit("damage_all", effect.effect_value)
			print("[OVERFLOW] Overcharge: %d Damage to All" % effect.effect_value)
		_:
			print("[OVERFLOW] Unknown overcharge effect: %s" % effect.overcharge_effect_id)
	
	overcharge_triggered.emit(effect.overcharge_effect_id, effect.effect_value)
	
	if effect.use_charge():
		remove_overflow_effect(effect)

# ============================================
# MANIFEST ZONE FUNCTIONS
# ============================================

func get_manifest_zone() -> Array[Dictionary]:
	return manifest_zone

func get_manifest_count() -> int:
	return manifest_zone.size()

func has_manifest_cards() -> bool:
	return manifest_zone.size() > 0

func activate_manifest(index: int, target = null) -> Dictionary:
	if index < 0 or index >= manifest_zone.size():
		print("[OVERFLOW] Invalid manifest index: %d" % index)
		return {}
	
	var entry = manifest_zone[index]
	manifest_zone.remove_at(index)
	
	var result = {
		"card": entry["card"],
		"manifest_id": entry["manifest_id"],
		"manifest_value": entry["manifest_value"],
		"tempo_cost": entry["tempo_cost"]
	}
	
	# Discard the underlying card
	if deck_manager:
		deck_manager.discard_pile.append(entry["card"])
	
	print("[OVERFLOW] Activated manifest: %s (was %s)" % [entry["manifest_name"], entry["card"].card_name])
	
	overflow_effects_changed.emit()
	return result

func clear_manifest_zone() -> void:
	# Discard all cards in manifest zone
	if deck_manager:
		for entry in manifest_zone:
			deck_manager.discard_pile.append(entry["card"])
	manifest_zone.clear()
	overflow_effects_changed.emit()

# ============================================
# DISPLAY
# ============================================

func get_active_effects_display() -> Array[String]:
	var display: Array[String] = []
	for effect in overflow_effects:
		display.append(effect.get_display_text())
	return display

func get_overflow_summary() -> String:
	if overflow_effects.size() == 0:
		return "No overflow effects"
	
	var lines: Array[String] = []
	for effect in overflow_effects:
		lines.append(effect.get_display_text())
	return "\n".join(lines)
