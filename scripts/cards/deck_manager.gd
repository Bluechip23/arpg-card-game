class_name DeckManager
extends Node

## Manages the player's deck, hand, and card piles

signal hand_updated
signal card_drawn(card: Card)
signal card_discarded(card: Card)
signal card_jailed(card: Card)
signal deck_shuffled
signal card_peaked(card: Card)
signal overflow_triggered(mode: String, card: Card)
signal on_draw_triggered(card: Card)
signal reaction_triggered(card: Card)
signal maintained_card_activated(card: Card)
signal maintained_cards_cleared
signal card_erased(card: Card)
# A card reached the discard pile by some means other than being played —
# forced discards, on-draw dumps, triggered instants, jail releases, expiring
# enchantments. Ryan's Ladder Work counts these toward his opening strike.
signal non_play_discard(card: Card)

enum OverflowMode { JAILED, ENHANCE, PEAK, SKIP, OVERCHARGE, MANIFEST, NONE }

var draw_pile: Array[Card] = []
var hand: Array[Card] = []
var discard_pile: Array[Card] = []
var jail_pile: Array[Card] = []
var maintained_cards: Array[Card] = []  # Active Power cards reserving mana

var player_stats = null  # PlayerStats - untyped to avoid circular dependency
var inventory = null  # Inventory - untyped to avoid circular dependency
var overflow_manager = null  # OverflowManager - untyped to avoid circular dependency
var debuff_manager = null  # DebuffManager - for checking Cuffed on draw

var peaked_card: Card = null

var next_attack_half_tempo: bool = false
var next_attack_mana_discount: int = 0
var prep_utility_discount: int = 0  # Preparation: reduces next utility card cost
var prep_utility_charges: int = 0   # How many more utility cards get the discount
var discards_this_cycle: int = 0  # Cards discarded since last tempo cycle
var skip_next_tempo_draw: bool = false  # Give In: suppress the next tempo-triggered draw
# Brain-point peeks (Wisdom): how many cards from the top of the draw pile are
# currently revealed. Drawing consumes one revealed card; shuffling the pile
# invalidates all of them.
var brain_peek_depth: int = 0
# Hand slots held for queued cards whose effects draw (Draw, Reload, …).
# While such a card ticks toward its resolve, the slot it freed on play must
# not be stolen by a tempo draw — otherwise the effect resolves into a full
# hand and silently does nothing.
var reserved_draw_slots: int = 0
var fire_spells_this_turn: int = 0  # Fireball synergy: fire spells cast since the cycle started

func connect_player_stats(stats) -> void:
	player_stats = stats

func connect_inventory(inv) -> void:
	inventory = inv

func connect_overflow_manager(om) -> void:
	overflow_manager = om
	overflow_manager.connect_deck_manager(self)

func connect_debuff_manager(dm) -> void:
	debuff_manager = dm

func get_hand_cap() -> int:
	if player_stats:
		return player_stats.hand_size
	return 6

## Save the full deck state across all piles (for world transitions).
func save_deck_state() -> Dictionary:
	var state := {}
	state["hand"] = []
	for card in hand:
		state["hand"].append(card.card_id)
	state["draw_pile"] = []
	for card in draw_pile:
		state["draw_pile"].append(card.card_id)
	state["discard_pile"] = []
	for card in discard_pile:
		state["discard_pile"].append(card.card_id)
	state["jail_pile"] = []
	for card in jail_pile:
		state["jail_pile"].append(card.card_id)
	state["maintained"] = []
	for card in maintained_cards:
		state["maintained"].append(card.card_id)
	return state

## Restore deck state from saved piles (preserves hand, draw, discard, jail exactly).
func restore_deck_state(state: Dictionary) -> void:
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	jail_pile.clear()
	maintained_cards.clear()
	peaked_card = null
	for card_id in state.get("draw_pile", []):
		var card = _create_card_from_id(card_id)
		if card:
			draw_pile.append(card)
	for card_id in state.get("hand", []):
		var card = _create_card_from_id(card_id)
		if card:
			hand.append(card)
	for card_id in state.get("discard_pile", []):
		var card = _create_card_from_id(card_id)
		if card:
			discard_pile.append(card)
	for card_id in state.get("jail_pile", []):
		var card = _create_card_from_id(card_id)
		if card:
			jail_pile.append(card)
	for card_id in state.get("maintained", []):
		var card = _create_card_from_id(card_id)
		if card:
			maintained_cards.append(card)
			# A maintained Power stays maintained across world transitions —
			# effect intact AND its mana still reserved, exactly as it was.
			# (Without this, every active Power became free after a zone change.)
			if player_stats and card.maintain_cost > 0:
				player_stats.reserve_mana(card.maintain_cost)
			maintained_card_activated.emit(card)
	hand_updated.emit()
	print("[DECK] Restored deck state: hand=%d, draw=%d, discard=%d, jail=%d" % [hand.size(), draw_pile.size(), discard_pile.size(), jail_pile.size()])

func initialize_deck(character: CharacterData) -> void:
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	jail_pile.clear()
	maintained_cards.clear()
	peaked_card = null
	reserved_draw_slots = 0
	
	# Create default starter deck based on character
	_create_default_deck(character)
	
	shuffle_draw_pile()
	
	for i in range(min(get_hand_cap(), draw_pile.size())):
		draw_card()
	
	print("[DECK] Initialized with %d cards. Hand: %d" % [draw_pile.size() + hand.size(), hand.size()])

func _create_default_deck(character: CharacterData) -> void:
	# Build full card id list: base + starting + purchased
	var all_card_ids: Array = []

	# Every character starts with the same basic deck.
	for i in range(4):
		all_card_ids.append("slash")
	for i in range(4):
		all_card_ids.append("block")
	all_card_ids.append("draw")
	all_card_ids.append("gain_mana")  # "energy"
	all_card_ids.append("heal")

	# Character-specific starting cards are intentionally NOT added — every
	# character shares the identical basic deck above.

	# Purchased cards
	all_card_ids.append_array(character.purchased_card_ids)

	# Remove culled cards (each entry in removed_card_ids removes one matching card)
	var removals = character.removed_card_ids.duplicate()
	for removal_id in removals:
		var idx = all_card_ids.find(removal_id)
		if idx >= 0:
			all_card_ids.remove_at(idx)
			print("[DECK] Culled card skipped: %s" % removal_id)
		else:
			print("[DECK] WARNING: Culled card not found in deck: %s" % removal_id)

	# Create actual Card objects from the remaining ids
	for i in range(all_card_ids.size()):
		var card_id = all_card_ids[i]
		var card = _create_card_from_id(card_id)
		if card:
			draw_pile.append(card)
		else:
			print("[DECK] WARNING: Unknown card_id: %s" % card_id)
## Default overflow behavior is NONE: when the hand is full a draw simply does
## nothing (the card is left on the draw pile). An overflow mode has to be set
## by a card or item for overflow to do anything.
var current_overflow_mode: OverflowMode = OverflowMode.NONE

func set_overflow_mode(mode: OverflowMode) -> void:
	current_overflow_mode = mode
	
	# Also update overflow_manager if connected
	if overflow_manager:
		overflow_manager.clear_temporary_effects()
		
		var effect: OverflowEffect = null
		match mode:
			OverflowMode.JAILED:
				effect = OverflowEffect.create_jailed(-1, "Default")
			OverflowMode.ENHANCE:
				effect = OverflowEffect.create_enhance(3, -1, "Default")
			OverflowMode.PEAK:
				effect = OverflowEffect.create_peak(-1, "Default")
			OverflowMode.SKIP:
				effect = OverflowEffect.create_skip(-1, "Default")
			OverflowMode.MANIFEST:
				effect = OverflowEffect.create_manifest_skeleton(-1, "Default")
			OverflowMode.OVERCHARGE:
				effect = OverflowEffect.create_overcharge_health(2, -1, "Default")
		
		if effect:
			effect.is_permanent = true
			overflow_manager.add_overflow_effect(effect)
	
	print("[DECK] Overflow mode set to: %s" % OverflowMode.keys()[mode])
## card_id -> factory method name, built once via reflection
var _card_factory_map: Dictionary = {}

func _build_card_factory_map() -> void:
	if _card_factory_map.size() > 0:
		return
	var card_script: Script = Card
	for method in card_script.get_script_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("create_") and method["args"].size() == 0:
			var card = card_script.call(method_name)
			if card is Card:
				_card_factory_map[card.card_id] = method_name

func _create_card_from_id(card_id: String) -> Card:
	_build_card_factory_map()
	if card_id in _card_factory_map:
		var card_script: Script = Card
		return card_script.call(_card_factory_map[card_id])
	print("[DECK] Unknown card_id: %s" % card_id)
	return null

func _create_card_from_data(card_data: Dictionary) -> Card:
	var card_id = card_data.get("id", "slash")
	return _create_card_from_id(card_id)

func shuffle_draw_pile() -> void:
	draw_pile.shuffle()
	brain_peek_depth = 0  # Shuffling scrambles everything the player had scried
	deck_shuffled.emit()

func shuffle_discard_into_draw() -> void:
	if discard_pile.size() == 0:
		return
	
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	shuffle_draw_pile()

func draw_card() -> Card:
	# The hand cap applies to every draw — tempo draws and card effects alike
	# (only Linger cards may exceed it, via add_card_to_hand). At capacity the
	# draw routes through the overflow system instead, same as a tempo draw.
	if hand.size() >= get_hand_cap():
		handle_overflow()
		return null
	if draw_pile.size() == 0:
		shuffle_discard_into_draw()
		if draw_pile.size() == 0:
			print("[DECK] No cards to draw!")
			return null

	var card = draw_pile.pop_back()

	# In-hand tempo reduction (Boots of Speed) lasts until played or discarded —
	# a card can only re-enter the hand through a draw, so a fresh draw is clean.
	card.temp_hand_tempo_reduction = 0

	# Feral Evocation: conversion only holds while the card stays in hand — a
	# card re-entering through a draw is back to its printed element.
	if card.has_meta("feral_color"):
		card.remove_meta("feral_color")

	# Reset enchantment cycle counter when drawn into hand
	if card.card_type == Card.CardType.ENCHANTMENT:
		card.cycles_in_hand = 0

	# Reset sticky card state when drawn into hand
	if card.sticky > 0:
		card.consecutive_uses = 0
		# Restore original mana/tempo costs for cards that modify them during use
		if card.card_id == "consecutive_snap":
			card.mana_cost = 3
			card.tempo_cost = 3

	hand.append(card)
	peaked_card = null
	# The drawn card was the top of the pile — one revealed card is consumed.
	if brain_peek_depth > 0:
		brain_peek_depth -= 1
	card_drawn.emit(card)
	hand_updated.emit()

	if inventory:
		inventory.on_card_drawn()

	# Trigger on-draw effects (card stays in hand unless stated otherwise)
	if card.has_on_draw:
		on_draw_triggered.emit(card)
		print("[DECK] On Draw triggered: %s" % card.card_name)
		# Some cards discard immediately after their on-draw effect
		if card.discard_on_draw:
			var idx = hand.find(card)
			if idx >= 0:
				hand.remove_at(idx)
				discard_pile.append(card)
				discards_this_cycle += 1
				card_discarded.emit(card)
				non_play_discard.emit(card)
				hand_updated.emit()
				print("[DECK] %s discarded after on-draw effect" % card.card_name)

	print("[DECK] Drew: %s | Hand: %d/%d" % [card.card_name, hand.size(), get_hand_cap()])
	return card

func attempt_draw() -> void:
	peaked_card = null

	# Cuffed: cannot draw cards
	if debuff_manager and debuff_manager.has_method("can_draw_cards") and not debuff_manager.can_draw_cards():
		print("[DECK] Cannot draw - Cuffed!")
		return

	# Tempo draws respect reserved slots (queued draw-effect cards); the
	# resolving effects themselves draw through draw_card() unaffected.
	if hand.size() + reserved_draw_slots >= get_hand_cap():
		handle_overflow()
	else:
		draw_card()

func release_draw_reservation(card: Card) -> void:
	## Frees the hand slots held for a queued card (on resolve or cancel).
	reserved_draw_slots = maxi(0, reserved_draw_slots - card.get_effect_draw_count())

func handle_overflow() -> void:
	# Default overflow does NOTHING: with no active overflow effect the player
	# simply doesn't draw — the extra card stays on the draw pile. Only an
	# active overflow effect (Jailed, Skip, Enhance, Manifest, Peak, Overcharge,
	# Quiver…) pulls the card off the pile and processes it.
	if not overflow_manager or overflow_manager.overflow_effects.size() == 0:
		print("[DECK] Hand full — overflow does nothing (no overflow mode active)")
		return

	if draw_pile.size() == 0:
		shuffle_discard_into_draw()
		if draw_pile.size() == 0:
			print("[DECK] No cards to overflow!")
			return

	var card = draw_pile.pop_back()
	overflow_manager.process_overflow(card)
	overflow_triggered.emit("Processed", card)

func play_card(index: int, target, player_node = null, defer_execution: bool = false) -> Dictionary:
	if index < 0 or index >= hand.size():
		print("[DECK] Invalid card index: %d" % index)
		return { "played": false, "half_tempo": false }
	
	var card = hand[index]
	# Timing-safe snapshot for Consecutive Snap: how many uses were complete
	# BEFORE this play (the sticky counter increments later this function).
	card.snap_uses_at_play = card.consecutive_uses

	if card.is_jailed():
		print("[DECK] Cannot play jailed card!")
		return { "played": false, "half_tempo": false }

	if card.card_type == Card.CardType.UNPLAYABLE:
		print("[DECK] Cannot play unplayable card: %s" % card.card_name)
		return { "played": false, "half_tempo": false }

	if card.card_type == Card.CardType.ENCHANTMENT:
		print("[DECK] Enchantment cards cannot be played — they provide passive buffs while in hand: %s" % card.card_name)
		return { "played": false, "half_tempo": false }

	if card.card_type == Card.CardType.REACTION:
		print("[DECK] Reaction cards trigger automatically, cannot be played manually: %s" % card.card_name)
		return { "played": false, "half_tempo": false }
	
	var debuff_mgr = null
	if player_node and player_node.has_method("get_debuff_manager"):
		debuff_mgr = player_node.get_debuff_manager()
	
	if debuff_mgr:
		if debuff_mgr.is_card_locked(index):
			print("[DECK] Cannot play card - Locked!")
			return { "played": false, "half_tempo": false }
		
		if not debuff_mgr.can_play_cards():
			print("[DECK] Cannot play cards - Stunned or Frozen!")
			return { "played": false, "half_tempo": false }
		
		# Disarm blocks PHYSICAL offensive cards (offensive → attack school).
		# A disarmed caster can still hurl spells; Silence is their counter.
		if card.card_type == Card.CardType.ATTACK and card.school == Card.CardSchool.PHYSICAL \
				and not debuff_mgr.can_play_attack_cards():
			print("[DECK] Cannot play attack cards - Disarmed!")
			return { "played": false, "half_tempo": false }

		# Silence blocks the SPELL school in ANY role — offense (Fireball),
		# defense (Magic Barrier), or support (Lady Luck). What matters is the
		# casting, not what the spell does.
		if card.school == Card.CardSchool.SPELL and not debuff_mgr.can_play_spell_cards():
			print("[DECK] Cannot play spell cards - Silenced!")
			return { "played": false, "half_tempo": false }
	
	# Heavy Swing: only playable when the hand holds nothing but attack cards.
	if card.card_id == "heavy_swing":
		for hc in hand:
			if hc != card and hc.card_type != Card.CardType.ATTACK:
				print("[DECK] Heavy Swing needs an all-attack hand")
				return { "played": false, "half_tempo": false }

	var mana_cost = card.get_burden_mana_cost()  # Burden: +1m per prior play
	if card.card_type == Card.CardType.ATTACK:
		mana_cost -= next_attack_mana_discount

	# Specific Strike: +10 mana per OTHER card in hand.
	if card.card_id == "specific_strike":
		mana_cost += max(0, hand.size() - 1) * 10
	# Exhausted Assault: free to play while you have no mana.
	if card.card_id == "exhausted_assault" and player_stats and player_stats.current_mana <= 0:
		mana_cost = 0

	# Ryan's belt passive covers BOTH kinds of belt card: the ones a belt
	# grants (discounted at creation in Inventory) and the ones slotted into a
	# belt, handled here so the two paths behave the same.
	if card.is_slotted() and inventory and inventory.belt_card_mana_reduction > 0 \
			and card.slotted_in_item and card.slotted_in_item.item_type == ItemData.ItemType.BELT:
		mana_cost = max(0, mana_cost - inventory.belt_card_mana_reduction)
		print("[DECK] Belt passive: -%d mana on slotted %s" % [inventory.belt_card_mana_reduction, card.card_name])

	# On-Self mana reduction from item card slot
	if card.is_slotted():
		var on_self = card.get_on_self_bonus()
		if on_self["mana_reduction"] != 0:
			# Positive = discount; negative = surcharge (Stringless Sender -10).
			mana_cost -= on_self["mana_reduction"]
			print("[DECK] On-Self mana adjustment: %+d from %s" % [-on_self["mana_reduction"], card.slotted_in_item.item_name])
		# The Headbandz: percentage mana-cost cut for slotted cards.
		var pct = on_self.get("mana_reduction_percent", 0.0)
		if pct > 0.0:
			mana_cost = floori(mana_cost * (1.0 - pct / 100.0))
			print("[DECK] On-Self mana reduction: -%.0f%% from %s" % [pct, card.slotted_in_item.item_name])
		# Megingjord: slotted cards cost double mana (and deal double damage).
		var mana_mult = float(on_self.get("mana_multiplier", 1.0))
		if mana_mult > 1.0:
			mana_cost = ceili(mana_cost * mana_mult)
			print("[DECK] On-Self mana multiplier: x%.1f from %s" % [mana_mult, card.slotted_in_item.item_name])

	# Preparation: utility cards cost less (limited charges)
	if prep_utility_discount > 0 and prep_utility_charges > 0 and card.card_type == Card.CardType.UTILITY:
		mana_cost -= prep_utility_discount
		print("[DECK] Preparation discount: -%d mana (%d charges left)" % [prep_utility_discount, prep_utility_charges])

	# Fireball synergy: -10 mana for each OTHER fire spell already cast this turn.
	if card.is_fire_spell and fire_spells_this_turn > 0:
		mana_cost -= fire_spells_this_turn * 10
		print("[DECK] Fire synergy: -%d mana (%d fire spell(s) this turn)" % [fire_spells_this_turn * 10, fire_spells_this_turn])

	if debuff_mgr:
		if card.card_type == Card.CardType.ATTACK:
			mana_cost += debuff_mgr.get_attack_mana_increase()

		if debuff_mgr.is_card_hexed(index):
			mana_cost += debuff_mgr.get_hexed_mana_increase()

	# Spell weapons: global percentage adjustments from the wielder's weapons.
	if inventory and "equipped_weapons" in inventory:
		for sw_w in inventory.equipped_weapons:
			if sw_w == null:
				continue
			# Blast Stick: offensive spells cost more — and its damage rider
			# reads this same surcharged price.
			if sw_w.spell_mana_surcharge_percent > 0.0 and card.is_offensive() \
					and card.school == Card.CardSchool.SPELL:
				mana_cost = ceili(mana_cost * (1.0 + sw_w.spell_mana_surcharge_percent / 100.0))
				print("[DECK] %s: +%.0f%% mana on offensive spell" % [sw_w.item_name, sw_w.spell_mana_surcharge_percent])
			# Reaper Scythe: a card aimed at a target below half health costs
			# 10% less — the reaping is easier once the soul is loose.
			if sw_w.reaper_weapon and target != null and is_instance_valid(target) \
					and "current_health" in target and "max_health" in target \
					and int(target.current_health) * 2 < int(target.max_health):
				mana_cost = floori(mana_cost * 0.9)
				print("[DECK] %s: -10%% mana against a target below half health" % sw_w.item_name)

	# Percent-mana cards (Wrath of the Sea): the price is a fraction of CURRENT
	# mana — discounts don't touch it, and the actual spend is recorded on the
	# card so its damage can read what the sea drank.
	if card.percent_mana_cost > 0.0 and player_stats:
		mana_cost = maxi(0, floori(player_stats.current_mana * card.percent_mana_cost))
		card.last_percent_mana_paid = mana_cost

	mana_cost = max(0, mana_cost)

	# Bow of Arash: half a slotted card's mana cost is converted to LIFE. The
	# life half is a true cost like health_cost — armor-ignoring, refundable.
	var arash_life_cost := 0
	if mana_cost > 0 and card.is_slotted() \
			and bool(card.get_on_self_bonus().get("mana_to_life", false)):
		arash_life_cost = floori(mana_cost / 2.0)
		mana_cost -= arash_life_cost
		if arash_life_cost > 0:
			print("[DECK] Bow of Arash: %d of %s's cost is paid in life" % [arash_life_cost, card.card_name])

	# Demonic Rage: mana costs use health instead, at the standing
	# 10-mana-per-1-HP exchange rate (mana runs on a x10 scale; HP does not).
	var demonic_rage_active = false
	var demonic_rage_hp_cost = maxi(1, ceili(mana_cost / 10.0)) if mana_cost > 0 else 0
	if mana_cost > 0 and player_node and player_node.has_method("get_buff_manager"):
		var dr_buff_mgr = player_node.get_buff_manager()
		if dr_buff_mgr and dr_buff_mgr.has_demonic_rage():
			demonic_rage_active = true
			# Check if player has enough health (must survive)
			if player_stats and player_stats.current_health <= demonic_rage_hp_cost:
				print("[DECK] Demonic Rage: not enough health to pay %d!" % demonic_rage_hp_cost)
				return { "played": false, "half_tempo": false }

	if not demonic_rage_active:
		if player_stats and not player_stats.has_mana(mana_cost):
			print("[DECK] Not enough mana! Need %d, have %d" % [mana_cost, int(player_stats.current_mana)])
			return { "played": false, "half_tempo": false }

	# Health-cost cards (Mind Mend): paid in HP on top of any mana, and the
	# play is refused rather than letting the cost kill you.
	if card.health_cost > 0 and player_stats and player_stats.current_health <= card.health_cost:
		print("[DECK] Not enough health! %s costs %d health" % [card.card_name, card.health_cost])
		return { "played": false, "half_tempo": false }
	# The Arash life half obeys the same rule: refuse rather than let it kill.
	if arash_life_cost > 0 and player_stats \
			and player_stats.current_health <= arash_life_cost + card.health_cost:
		print("[DECK] Not enough health! %s needs %d life for the Bow of Arash" % [card.card_name, arash_life_cost])
		return { "played": false, "half_tempo": false }

	# Remember what this play actually cost so a voluntary cancel can give it
	# back exactly (mana normally; health when Demonic Rage footed the bill).
	var mana_paid := 0
	var health_paid := 0
	if player_stats and mana_cost > 0:
		if demonic_rage_active:
			# Spend health instead of mana (10 mana = 1 HP)
			var dr_buff_mgr = player_node.get_buff_manager()
			player_stats.take_damage(demonic_rage_hp_cost)
			dr_buff_mgr.consume_demonic_rage()
			health_paid = demonic_rage_hp_cost
			print("[DECK] Demonic Rage: paid %d health instead of %d mana (%d charges left)" % [demonic_rage_hp_cost, mana_cost, dr_buff_mgr.get_buff(Buff.BuffType.DEMONIC_RAGE).charges if dr_buff_mgr.has_demonic_rage() else 0])
		else:
			player_stats.spend_mana(mana_cost)
			mana_paid = mana_cost
	# The health price is a true cost: it ignores armor, and a cancel refunds it.
	if card.health_cost > 0 and player_stats:
		player_stats.take_direct_damage(card.health_cost)
		health_paid += card.health_cost
		print("[DECK] %s: paid %d health" % [card.card_name, card.health_cost])
	# The Bow of Arash's converted half is paid the same way.
	if arash_life_cost > 0 and player_stats:
		player_stats.take_direct_damage(arash_life_cost)
		health_paid += arash_life_cost
		print("[DECK] %s: paid %d life (Bow of Arash)" % [card.card_name, arash_life_cost])

	# Count this fire spell so the next one this turn is cheaper.
	if card.is_fire_spell:
		fire_spells_this_turn += 1

	# Colored slots (Mauls Sabre): capture what preceded this play for the
	# card's combo checks, then record this play. Any unrelated play breaks
	# the chain — "immediately after" means immediately.
	if inventory:
		for cw in inventory.equipped_weapons:
			if cw != null and cw.slot_colors.size() > 0:
				if card.slotted_in_item == cw:
					card.set_meta("combo_prev_color", cw.last_color_played)
					cw.last_color_played = cw.get_slot_color(card)
				else:
					cw.last_color_played = ""

	var was_half_tempo = next_attack_half_tempo and card.card_type == Card.CardType.ATTACK

	# Only consume proc bonus when an attack card is played
	if card.card_type == Card.CardType.ATTACK:
		next_attack_half_tempo = false
		next_attack_mana_discount = 0

	# Preparation chain: consume a charge when utility played, clear if non-utility or depleted
	if prep_utility_discount > 0:
		if card.card_type == Card.CardType.UTILITY:
			prep_utility_charges -= 1
			if prep_utility_charges <= 0:
				prep_utility_discount = 0
				prep_utility_charges = 0
				print("[DECK] Preparation charges depleted")
		else:
			prep_utility_discount = 0
			prep_utility_charges = 0
			print("[DECK] Preparation chain broken (non-utility played)")
	
	var clumsy_triggered = false
	if debuff_mgr and debuff_mgr.roll_clumsy():
		clumsy_triggered = true
	
	hand.remove_at(index)

	if debuff_mgr:
		if debuff_mgr.get_hexed_card_index() == index:
			debuff_mgr.remove_debuff(Debuff.DebuffType.HEXED)
		if debuff_mgr.get_locked_card_index() == index:
			debuff_mgr.remove_debuff(Debuff.DebuffType.LOCKED)
		_update_debuff_card_indices(debuff_mgr, index)

	var damage_reduction_pct = 0.0
	var self_damage_percent = 0.0
	var buff_mgr = null

	if debuff_mgr:
		damage_reduction_pct = debuff_mgr.get_damage_reduction_percent()
		self_damage_percent = debuff_mgr.get_self_damage_percent()

	if player_node and player_node.has_method("get_buff_manager"):
		buff_mgr = player_node.get_buff_manager()

	if not defer_execution:
		# Killing Rhythm (DEX keystone): fold the armed bonus into this attack, then
		# strip it back off so the card's own bonus_damage isn't permanently changed.
		var dex_flat_bonus = 0
		if card.card_type == Card.CardType.ATTACK and player_stats:
			dex_flat_bonus = player_stats.consume_pending_dex_bonus_damage()
			if dex_flat_bonus > 0:
				card.bonus_damage += dex_flat_bonus

		card.execute(target, player_stats, self, damage_reduction_pct, self_damage_percent, buff_mgr)

		# Flurry Form (DEX keystone): a proc-empowered attack strikes a second time.
		if was_half_tempo and card.card_type == Card.CardType.ATTACK \
				and player_stats and player_stats.keystone_dex_twin_strike:
			card.execute(target, player_stats, self, damage_reduction_pct, self_damage_percent, buff_mgr)
			print("[DECK] Flurry Form: second strike!")

		if dex_flat_bonus > 0:
			card.bonus_damage -= dex_flat_bonus

		# Register attack for attack speed counter (DEX proc) - all attack cards count
		# Proc-bonus attacks don't count towards the next cycle
		if card.card_type == Card.CardType.ATTACK and player_stats and not was_half_tempo:
			player_stats.register_attack()
			# Free hand: the 12th attack echoes — the card runs again, free.
			if player_stats.consume_free_hand_echo():
				card.execute(target, player_stats, self, damage_reduction_pct, self_damage_percent, buff_mgr)
				print("[DECK] Free hand echo: %s strikes twice!" % card.card_name)

		if debuff_mgr and card.card_type == Card.CardType.ATTACK:
			debuff_mgr.on_attack()

		if inventory:
			inventory.on_card_played(card)

	# Power cards with maintain go to the maintained pile instead of discard
	if card.card_type == Card.CardType.POWER and card.maintain_cost > 0:
		maintained_cards.append(card)
		if player_stats:
			player_stats.reserve_mana(card.maintain_cost)
		maintained_card_activated.emit(card)
		print("[DECK] %s maintained! Reserving %dM. Active maintains: %d" % [card.card_name, card.maintain_cost, maintained_cards.size()])
	# Sticky cards stay in hand until played enough times
	elif card.sticky > 0:
		card.consecutive_uses += 1
		if card.consecutive_uses >= card.sticky:
			# Fully used up - discard
			discard_pile.append(card)
			discards_this_cycle += 1
			card_discarded.emit(card)
			print("[DECK] %s sticky exhausted (%d/%d uses) - discarded" % [card.card_name, card.consecutive_uses, card.sticky])
		else:
			# Put back in hand
			hand.insert(min(index, hand.size()), card)
			print("[DECK] %s sticky (%d/%d uses) - stays in hand" % [card.card_name, card.consecutive_uses, card.sticky])
	elif card.erase_on_play:
		# Erased — removed from the deck entirely the moment it's played (not discarded).
		card_discarded.emit(card)
		print("[DECK] %s erased after play." % card.card_name)
	elif card.jail_on_play > 0:
		# Jail-on-play (e.g. Meister of Faustmesser): the card sits in jail for
		# its stated tempo before returning to the discard pile.
		card.jail_time_remaining = card.jail_on_play
		jail_pile.append(card)
		card_jailed.emit(card)
		print("[DECK] %s jailed for %d tempo after play." % [card.card_name, card.jail_on_play])
	elif card.is_slotted() and int(card.get_on_self_bonus().get("jail_tempo", 0)) > 0:
		# The Rapid Recurve: cards fired from it are jailed after every play.
		card.jail_time_remaining = int(card.get_on_self_bonus().get("jail_tempo", 0))
		jail_pile.append(card)
		card_jailed.emit(card)
		print("[DECK] %s jailed for %d tempo by %s." % [card.card_name, card.jail_time_remaining, card.slotted_in_item.item_name])
	else:
		discard_pile.append(card)
		discards_this_cycle += 1
		card_discarded.emit(card)

	if clumsy_triggered and hand.size() > 0:
		var random_index = randi() % hand.size()
		var discarded_card = hand[random_index]
		hand.remove_at(random_index)
		discard_pile.append(discarded_card)
		discards_this_cycle += 1
		non_play_discard.emit(discarded_card)
		print("[DECK] Clumsy discarded: %s" % discarded_card.card_name)
		
		if debuff_mgr:
			_update_debuff_card_indices(debuff_mgr, random_index)
	
	hand_updated.emit()

	# Queued play: hold the freed slot for this card's own draw effect until
	# it resolves (released in execute_deferred_card / on cancel).
	if defer_execution:
		reserved_draw_slots += card.get_effect_draw_count()

	print("[DECK] Played: %s (cost %d mana) | Hand: %d/%d" % [card.card_name, mana_cost, hand.size(), get_hand_cap()])

	card.apply_burden()  # Burden cards get heavier with every play

	return { "played": true, "half_tempo": was_half_tempo, "mana_spent": mana_paid, "health_spent": health_paid }

## Execute a deferred card (called when the resolve tick fires in the ticked tempo system)
func execute_deferred_card(card: Card, target, player_node = null) -> void:
	# The card is resolving: its held hand slots become real again so its own
	# draw effect can use them.
	release_draw_reservation(card)
	var damage_reduction_pct = 0.0
	var self_damage_percent = 0.0
	var buff_mgr = null
	var debuff_mgr = null

	# Co-op ally targeting: when the card targets a (different) player character —
	# e.g. a heal or buff aimed at the partner — the stat/buff/debuff effects must
	# land on that targeted ally, not the caster. Attacks (Enemy target) and self
	# casts (target is the caster) keep the caster's own stats.
	var effect_stats: PlayerStats = player_stats
	var effect_player = player_node
	if target is Player:
		effect_player = target
		if target.has_method("get_stats") and target.get_stats():
			effect_stats = target.get_stats()

	if effect_player and effect_player.has_method("get_debuff_manager"):
		debuff_mgr = effect_player.get_debuff_manager()
	if effect_player and effect_player.has_method("get_buff_manager"):
		buff_mgr = effect_player.get_buff_manager()

	if debuff_mgr:
		damage_reduction_pct = debuff_mgr.get_damage_reduction_percent()
		self_damage_percent = debuff_mgr.get_self_damage_percent()

	# Killing Rhythm (DEX keystone): spend any armed bonus on this attack.
	var dex_flat_bonus = 0
	if card.card_type == Card.CardType.ATTACK and player_stats:
		dex_flat_bonus = player_stats.consume_pending_dex_bonus_damage()
		if dex_flat_bonus > 0:
			card.bonus_damage += dex_flat_bonus

	card.execute(target, effect_stats, self, damage_reduction_pct, self_damage_percent, buff_mgr)

	if dex_flat_bonus > 0:
		card.bonus_damage -= dex_flat_bonus

	# Register attack for attack speed counter (DEX proc)
	if card.card_type == Card.CardType.ATTACK and player_stats:
		player_stats.register_attack()
		# Free hand: the 12th attack echoes — the card runs again, free.
		if player_stats.consume_free_hand_echo():
			card.execute(target, effect_stats, self, damage_reduction_pct, self_damage_percent, buff_mgr)
			print("[DECK] Free hand echo: %s strikes twice!" % card.card_name)

	if debuff_mgr and card.card_type == Card.CardType.ATTACK:
		debuff_mgr.on_attack()

	if inventory:
		inventory.on_card_played(card)

	print("[DECK] Deferred card executed: %s" % card.card_name)

func _update_debuff_card_indices(debuff_mgr, removed_index: int) -> void:
	var hexed_index = debuff_mgr.get_hexed_card_index()
	if hexed_index > removed_index:
		debuff_mgr.set_hexed_card_index(hexed_index - 1)
	
	var locked_index = debuff_mgr.get_locked_card_index()
	if locked_index > removed_index:
		debuff_mgr.set_locked_card_index(locked_index - 1)

func assign_hexed_locked_cards(debuff_mgr) -> void:
	if hand.size() == 0:
		return
	
	if debuff_mgr.has_debuff(Debuff.DebuffType.HEXED) and debuff_mgr.get_hexed_card_index() == -1:
		var index = randi() % hand.size()
		debuff_mgr.set_hexed_card_index(index)
		print("[DECK] Hexed assigned to card %d: %s" % [index, hand[index].card_name])
	
	if debuff_mgr.has_debuff(Debuff.DebuffType.LOCKED) and debuff_mgr.get_locked_card_index() == -1:
		var index = randi() % hand.size()
		var hexed_index = debuff_mgr.get_hexed_card_index()
		if hand.size() > 1 and index == hexed_index:
			index = (index + 1) % hand.size()
		debuff_mgr.set_locked_card_index(index)
		print("[DECK] Locked assigned to card %d: %s" % [index, hand[index].card_name])

func apply_dex_proc_bonus() -> void:
	next_attack_half_tempo = true
	next_attack_mana_discount = 20
	print("[DECK] Next attack: HALF TEMPO + 20 mana discount!")

func process_turn() -> void:
	discards_this_cycle = 0
	fire_spells_this_turn = 0
	for i in range(jail_pile.size() - 1, -1, -1):
		var card = jail_pile[i]
		card.jail_time_remaining -= 5
		if card.jail_time_remaining <= 0:
			jail_pile.remove_at(i)
			discard_pile.append(card)
			non_play_discard.emit(card)
			print("[DECK] Released from jail: %s" % card.card_name)

	# Process Erase: tick down erase timers on all cards and delete expired ones
	_process_erase_timers()

func jail_burden_card(index: int) -> bool:
	## Burden relief: jail the card FROM HAND to reset its accumulated burden
	## (keyword: 30 tempo in jail, costs 1m — the 1t is charged by the caller).
	if index < 0 or index >= hand.size():
		return false
	var card = hand[index]
	if not card.has_burden or card.burden_plays <= 0:
		return false
	if player_stats and not player_stats.spend_mana(card.burden_jail_cost_mana):
		return false
	hand.remove_at(index)
	card.jail_burden()  # resets plays + arms the 30-tempo jail timer
	jail_pile.append(card)
	card_jailed.emit(card)
	hand_updated.emit()
	print("[DECK] %s jailed to shed its burden" % card.card_name)
	return true

func _process_erase_timers() -> void:
	## Tick down erase_tempo_remaining on cards with erase_tempo > 0.
	## Erase timers only tick while the card sits in the player's HAND —
	## a token resting in the draw/discard piles keeps its fuse intact.
	## When a card's timer hits 0, permanently remove it from the deck.
	var piles = [
		{"pile": hand, "name": "hand"},
	]
	var hand_changed = false
	for pile_info in piles:
		var pile = pile_info["pile"]
		for i in range(pile.size() - 1, -1, -1):
			var card = pile[i]
			if card.erase_tempo > 0:
				card.erase_tempo_remaining -= 5
				if card.erase_tempo_remaining <= 0:
					pile.remove_at(i)
					card_erased.emit(card)
					if pile_info["name"] == "hand":
						hand_changed = true
					print("[DECK] Erased '%s' from %s (Erase: %d tempo expired)" % [card.card_name, pile_info["name"], card.erase_tempo])
	if hand_changed:
		hand_updated.emit()

func get_peaked_card() -> Card:
	return peaked_card

func get_brain_peeked_cards() -> Array[Card]:
	## The revealed top of the draw pile (brain-point peeks), in draw order —
	## element 0 is the very next card. Top of the pile is the array's BACK.
	var out: Array[Card] = []
	var depth = mini(brain_peek_depth, draw_pile.size())
	for i in range(depth):
		out.append(draw_pile[draw_pile.size() - 1 - i])
	return out

func get_draw_pile_size() -> int:
	return draw_pile.size()

func get_discard_pile_size() -> int:
	return discard_pile.size()

func get_jail_pile_size() -> int:
	return jail_pile.size()

func add_card_to_deck_from_id(card_id: String) -> bool:
	## Creates a card from its ID and adds it to the discard pile (available next shuffle).
	## Used by the sphere grid when unlocking card nodes.
	var card = _create_card_from_id(card_id)
	if card:
		discard_pile.append(card)
		print("[DECK] Sphere grid unlocked card: %s (added to discard pile)" % card.card_name)
		return true
	print("[DECK] WARNING: Sphere grid tried to unlock unknown card: %s" % card_id)
	return false

## Ragnarok (Hide of Garmr): free every jailed card at once. Cards go to the
## hand while it has room; overflow lands in the discard pile (still counts as
## released). `exclude` skips the card doing the releasing — a jail-on-play card
## is already sitting in the jail pile by the time a deferred execute runs.
func release_jailed_to_hand(exclude: Card = null) -> int:
	var released := 0
	for i in range(jail_pile.size() - 1, -1, -1):
		var card = jail_pile[i]
		if card == exclude:
			continue
		jail_pile.remove_at(i)
		card.jail_time_remaining = 0
		released += 1
		if card.linger or hand.size() < get_hand_cap():
			hand.append(card)
			print("[DECK] Ragnarok releases %s to hand" % card.card_name)
		else:
			discard_pile.append(card)
			non_play_discard.emit(card)
			print("[DECK] Ragnarok releases %s — hand full, discarded" % card.card_name)
	if released > 0:
		hand_updated.emit()
	return released

func add_card_to_hand(card: Card) -> void:
	# Linger cards can exceed hand size; non-linger cards are blocked at capacity
	if not card.linger and hand.size() >= get_hand_cap():
		print("[DECK] Hand full, cannot add %s (no Linger)" % card.card_name)
		return
	hand.append(card)
	hand_updated.emit()
	print("[DECK] Card added to hand: %s | Hand: %d/%d" % [card.card_name, hand.size(), get_hand_cap()])

func discard_card_from_hand(card: Card) -> bool:
	## Move a specific card from hand to the discard pile (e.g. Shed Weight).
	var idx = hand.find(card)
	if idx < 0:
		return false
	hand.remove_at(idx)
	card.temp_hand_tempo_reduction = 0  # in-hand reduction ends on discard
	discard_pile.append(card)
	discards_this_cycle += 1
	card_discarded.emit(card)
	non_play_discard.emit(card)
	hand_updated.emit()
	return true

func trigger_reactions(trigger_type: String) -> Array[Card]:
	var triggered: Array[Card] = []
	for i in range(hand.size() - 1, -1, -1):
		var card = hand[i]
		if card.card_type == Card.CardType.REACTION and card.reaction_trigger == trigger_type:
			# Silence stops spell-school instants (Magic Barrier, Gift from the
			# Phoenix) from firing — the reflex is still a cast.
			if card.school == Card.CardSchool.SPELL and debuff_manager \
					and debuff_manager.has_method("can_play_spell_cards") \
					and not debuff_manager.can_play_spell_cards():
				print("[DECK] Silenced — spell reaction %s cannot fire" % card.card_name)
				continue
			hand.remove_at(i)
			triggered.append(card)
			discard_pile.append(card)
			reaction_triggered.emit(card)
			non_play_discard.emit(card)
			print("[DECK] Reaction triggered: %s" % card.card_name)
	if triggered.size() > 0:
		hand_updated.emit()
	return triggered

## Fire exactly ONE reaction card of the given trigger from hand, jailing it
## for jail_tempo instead of discarding — Polymorph's 25-tempo cooldown, so a
## second copy in hand survives for the next transformation. Returns the fired
## card, or null when none was in hand (or Silence stopped every copy).
func trigger_one_reaction_jailed(trigger_type: String, jail_tempo: int) -> Card:
	for i in range(hand.size()):
		var card = hand[i]
		if card.card_type == Card.CardType.REACTION and card.reaction_trigger == trigger_type:
			if card.school == Card.CardSchool.SPELL and debuff_manager \
					and debuff_manager.has_method("can_play_spell_cards") \
					and not debuff_manager.can_play_spell_cards():
				print("[DECK] Silenced — spell reaction %s cannot fire" % card.card_name)
				continue
			hand.remove_at(i)
			card.jail_time_remaining = jail_tempo
			jail_pile.append(card)
			card_jailed.emit(card)
			reaction_triggered.emit(card)
			hand_updated.emit()
			print("[DECK] Reaction triggered: %s (jailed %d tempo)" % [card.card_name, jail_tempo])
			return card
	return null

func remove_card_from_all_piles(card: Card) -> bool:
	## Removes a specific card instance from draw pile, hand, discard pile, or jail.
	## Used when enchanting a card into an item.
	for i in range(hand.size() - 1, -1, -1):
		if hand[i] == card:
			hand.remove_at(i)
			hand_updated.emit()
			print("[DECK] Removed '%s' from hand for enchanting" % card.card_name)
			return true

	for i in range(draw_pile.size() - 1, -1, -1):
		if draw_pile[i] == card:
			draw_pile.remove_at(i)
			print("[DECK] Removed '%s' from draw pile for enchanting" % card.card_name)
			return true

	for i in range(discard_pile.size() - 1, -1, -1):
		if discard_pile[i] == card:
			discard_pile.remove_at(i)
			print("[DECK] Removed '%s' from discard pile for enchanting" % card.card_name)
			return true

	for i in range(jail_pile.size() - 1, -1, -1):
		if jail_pile[i] == card:
			jail_pile.remove_at(i)
			print("[DECK] Removed '%s' from jail for enchanting" % card.card_name)
			return true

	for i in range(maintained_cards.size() - 1, -1, -1):
		if maintained_cards[i] == card:
			maintained_cards.remove_at(i)
			if player_stats:
				player_stats.release_mana(card.maintain_cost)
			print("[DECK] Removed '%s' from maintained cards for enchanting" % card.card_name)
			return true

	return false

# ============================================
# MAINTAINED CARDS (Power / Maintain keyword)
# ============================================

func get_maintained_cards() -> Array[Card]:
	return maintained_cards

func get_maintained_card_count() -> int:
	return maintained_cards.size()

func process_maintained_cards() -> Dictionary:
	## Called each tempo cycle. Processes ongoing effects from maintained Power cards.
	## Returns a summary of effects applied.
	var result = {"heals": 0, "total_heal": 0, "fountain_self_damage": 0, "fountain_draws": 0, "self_damage": 0}
	for card in maintained_cards:
		match card.card_id:
			"halo":
				result["heals"] += 1
				result["total_heal"] += card.heal_amount
			"fountain_of_life":
				result["fountain_self_damage"] += card.damage
				result["fountain_draws"] += 1
			"cultish_wounds":
				result["self_damage"] += 1
	return result

func break_all_maintained_cards() -> void:
	## Discard all maintained cards and release all reserved mana.
	## Called when player's mana drops to 0.
	if maintained_cards.size() == 0:
		return
	print("[DECK] === ALL MAINTAINED CARDS BROKEN ===")
	for card in maintained_cards:
		discard_pile.append(card)
		card_discarded.emit(card)
		print("[DECK] Maintained card discarded: %s (released %dM)" % [card.card_name, card.maintain_cost])
	maintained_cards.clear()
	# Note: PlayerStats already reset maintained_mana to 0 when it emitted the signal
	maintained_cards_cleared.emit()

func dismiss_maintained_card(index: int) -> void:
	## Player voluntarily dismisses a maintained card to free up mana.
	if index < 0 or index >= maintained_cards.size():
		return
	var card = maintained_cards[index]
	maintained_cards.remove_at(index)
	discard_pile.append(card)
	card_discarded.emit(card)
	if player_stats:
		player_stats.release_mana(card.maintain_cost)
	print("[DECK] Dismissed maintained card: %s (freed %dM)" % [card.card_name, card.maintain_cost])
