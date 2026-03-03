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

enum OverflowMode { JAILED, ENHANCE, PEAK, TRANSFERRED, OVERCHARGE, MANIFEST }

var draw_pile: Array[Card] = []
var hand: Array[Card] = []
var discard_pile: Array[Card] = []
var jail_pile: Array[Card] = []
var maintained_cards: Array[Card] = []  # Active Power cards reserving mana

var player_stats = null  # PlayerStats - untyped to avoid circular dependency
var inventory = null  # Inventory - untyped to avoid circular dependency
var overflow_manager = null  # OverflowManager - untyped to avoid circular dependency

var peaked_card: Card = null

var next_attack_free: bool = false
var next_attack_mana_discount: int = 0
var prep_utility_discount: int = 0  # Preparation: reduces next utility card cost
var discards_this_cycle: int = 0  # Cards discarded since last tempo cycle

func connect_player_stats(stats) -> void:
	player_stats = stats

func connect_inventory(inv) -> void:
	inventory = inv

func connect_overflow_manager(om) -> void:
	overflow_manager = om
	overflow_manager.connect_deck_manager(self)

func get_hand_cap() -> int:
	if player_stats:
		return player_stats.hand_size
	return 6

func initialize_deck(character: CharacterData) -> void:
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	jail_pile.clear()
	maintained_cards.clear()
	peaked_card = null
	
	# Create default starter deck based on character
	_create_default_deck(character)
	
	shuffle_draw_pile()
	
	for i in range(min(get_hand_cap(), draw_pile.size())):
		draw_card()
	
	print("[DECK] Initialized with %d cards. Hand: %d" % [draw_pile.size() + hand.size(), hand.size()])

func _create_default_deck(character: CharacterData) -> void:
	# Base cards for everyone
	for i in range(4):
		draw_pile.append(Card.create_slash())
	for i in range(3):
		draw_pile.append(Card.create_block())
	for i in range(2):
		draw_pile.append(Card.create_heal())

	draw_pile.append(Card.create_draw())
	draw_pile.append(Card.create_discard())
	draw_pile.append(Card.create_gain_mana())

	# Add character-specific cards
	for card_id in character.starting_card_ids:
		var card = _create_card_from_id(card_id)
		if card:
			draw_pile.append(card)
		else:
			print("[DECK] WARNING: Unknown card_id in starting deck: %s" % card_id)
var current_overflow_mode: OverflowMode = OverflowMode.JAILED

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
			OverflowMode.TRANSFERRED:
				effect = OverflowEffect.create_transferred(-1, "Default")
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
		return Card.call(_card_factory_map[card_id])
	print("[DECK] Unknown card_id: %s" % card_id)
	return null

func _create_card_from_data(card_data: Dictionary) -> Card:
	var card_id = card_data.get("id", "slash")
	return _create_card_from_id(card_id)

func shuffle_draw_pile() -> void:
	draw_pile.shuffle()
	deck_shuffled.emit()

func shuffle_discard_into_draw() -> void:
	if discard_pile.size() == 0:
		return
	
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	shuffle_draw_pile()

func draw_card() -> Card:
	if draw_pile.size() == 0:
		shuffle_discard_into_draw()
		if draw_pile.size() == 0:
			print("[DECK] No cards to draw!")
			return null

	var card = draw_pile.pop_back()

	# Reset sticky card state when drawn into hand
	if card.sticky > 0:
		card.consecutive_uses = 0
		# Restore original mana/tempo costs for cards that modify them during use
		if card.card_id == "consecutive_snap":
			card.mana_cost = 3
			card.tempo_cost = 3

	hand.append(card)
	peaked_card = null
	card_drawn.emit(card)
	hand_updated.emit()

	if inventory:
		inventory.on_card_drawn()

	# Trigger on-draw effects (card stays in hand unless stated otherwise)
	if card.has_on_draw:
		on_draw_triggered.emit(card)
		print("[DECK] On Draw triggered: %s" % card.card_name)

	print("[DECK] Drew: %s | Hand: %d/%d" % [card.card_name, hand.size(), get_hand_cap()])
	return card

func attempt_draw() -> void:
	peaked_card = null
	
	if hand.size() >= get_hand_cap():
		handle_overflow()
	else:
		draw_card()

func handle_overflow() -> void:
	if draw_pile.size() == 0:
		shuffle_discard_into_draw()
		if draw_pile.size() == 0:
			print("[DECK] No cards to overflow!")
			return
	
	var card = draw_pile.pop_back()
	
	if overflow_manager:
		overflow_manager.process_overflow(card)
		overflow_triggered.emit("Processed", card)
	else:
		# Fallback: just discard
		discard_pile.append(card)
		print("[DECK] No overflow manager, discarded: %s" % card.card_name)

func play_card(index: int, target, player_node = null) -> Dictionary:
	if index < 0 or index >= hand.size():
		print("[DECK] Invalid card index: %d" % index)
		return { "played": false, "free_turn": false }
	
	var card = hand[index]
	
	if card.is_jailed():
		print("[DECK] Cannot play jailed card!")
		return { "played": false, "free_turn": false }

	if card.card_type == Card.CardType.UNPLAYABLE:
		print("[DECK] Cannot play unplayable card: %s" % card.card_name)
		return { "played": false, "free_turn": false }

	if card.card_type == Card.CardType.REACTION:
		print("[DECK] Reaction cards trigger automatically, cannot be played manually: %s" % card.card_name)
		return { "played": false, "free_turn": false }
	
	var debuff_mgr = null
	if player_node and player_node.has_method("get_debuff_manager"):
		debuff_mgr = player_node.get_debuff_manager()
	
	if debuff_mgr:
		if debuff_mgr.is_card_locked(index):
			print("[DECK] Cannot play card - Locked!")
			return { "played": false, "free_turn": false }
		
		if not debuff_mgr.can_play_cards():
			print("[DECK] Cannot play cards - Stunned or Frozen!")
			return { "played": false, "free_turn": false }
		
		if card.card_type == Card.CardType.ATTACK and not debuff_mgr.can_play_attack_cards():
			print("[DECK] Cannot play attack cards - Disarmed!")
			return { "played": false, "free_turn": false }
		
		if (card.card_type == Card.CardType.UTILITY or card.card_type == Card.CardType.POWER) and card.mana_cost > 0:
			if not debuff_mgr.can_play_spell_cards():
				print("[DECK] Cannot play spell cards - Silenced!")
				return { "played": false, "free_turn": false }
	
	var mana_cost = card.mana_cost - next_attack_mana_discount

	# On-Self mana reduction from item card slot
	if card.is_slotted():
		var on_self = card.get_on_self_bonus()
		if on_self["mana_reduction"] > 0:
			mana_cost -= on_self["mana_reduction"]
			print("[DECK] On-Self mana reduction: -%d from %s" % [on_self["mana_reduction"], card.slotted_in_item.item_name])

	# Preparation: utility cards cost less
	if prep_utility_discount > 0 and card.card_type == Card.CardType.UTILITY:
		mana_cost -= prep_utility_discount
		print("[DECK] Preparation discount: -%d mana" % prep_utility_discount)

	if debuff_mgr:
		if card.card_type == Card.CardType.ATTACK:
			mana_cost += debuff_mgr.get_attack_mana_increase()

		if debuff_mgr.is_card_hexed(index):
			mana_cost += debuff_mgr.get_hexed_mana_increase()

	mana_cost = max(0, mana_cost)

	if player_stats and not player_stats.has_mana(mana_cost):
		print("[DECK] Not enough mana! Need %d, have %d" % [mana_cost, int(player_stats.current_mana)])
		return { "played": false, "free_turn": false }

	if player_stats and mana_cost > 0:
		player_stats.spend_mana(mana_cost)

	var was_free_turn = next_attack_free and card.card_type == Card.CardType.ATTACK

	next_attack_free = false
	next_attack_mana_discount = 0

	# Preparation chain: if utility was played, keep discount for next card; otherwise clear
	if prep_utility_discount > 0:
		if card.card_type == Card.CardType.UTILITY:
			pass  # Keep prep_utility_discount for next card (chain continues)
		else:
			prep_utility_discount = 0
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

	card.execute(target, player_stats, self, damage_reduction_pct, self_damage_percent, buff_mgr)

	# Register attack for attack speed counter (DEX proc) - all attack cards count
	if card.card_type == Card.CardType.ATTACK and player_stats:
		player_stats.register_attack()

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
		print("[DECK] Clumsy discarded: %s" % discarded_card.card_name)
		
		if debuff_mgr:
			_update_debuff_card_indices(debuff_mgr, random_index)
	
	hand_updated.emit()
	
	print("[DECK] Played: %s (cost %d mana) | Hand: %d/%d" % [card.card_name, mana_cost, hand.size(), get_hand_cap()])
	
	return { "played": true, "free_turn": was_free_turn }

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
	next_attack_free = true
	next_attack_mana_discount = 2
	print("[DECK] Next attack: FREE TURN + 2 mana discount!")

func process_turn() -> void:
	discards_this_cycle = 0
	for i in range(jail_pile.size() - 1, -1, -1):
		var card = jail_pile[i]
		card.jail_time_remaining -= 5
		if card.jail_time_remaining <= 0:
			jail_pile.remove_at(i)
			discard_pile.append(card)
			print("[DECK] Released from jail: %s" % card.card_name)

	# Process Erase: tick down erase timers on all cards and delete expired ones
	_process_erase_timers()

func _process_erase_timers() -> void:
	## Tick down erase_tempo_remaining on all cards with erase_tempo > 0.
	## When a card's erase timer hits 0, permanently remove it from the deck.
	var piles = [
		{"pile": draw_pile, "name": "draw pile"},
		{"pile": hand, "name": "hand"},
		{"pile": discard_pile, "name": "discard pile"},
		{"pile": jail_pile, "name": "jail"},
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

func get_draw_pile_size() -> int:
	return draw_pile.size()

func get_discard_pile_size() -> int:
	return discard_pile.size()

func get_jail_pile_size() -> int:
	return jail_pile.size()

func add_card_to_hand(card: Card) -> void:
	hand.append(card)
	hand_updated.emit()
	print("[DECK] Card added to hand: %s | Hand: %d/%d" % [card.card_name, hand.size(), get_hand_cap()])

func trigger_reactions(trigger_type: String) -> Array[Card]:
	var triggered: Array[Card] = []
	for i in range(hand.size() - 1, -1, -1):
		var card = hand[i]
		if card.card_type == Card.CardType.REACTION and card.reaction_trigger == trigger_type:
			hand.remove_at(i)
			triggered.append(card)
			discard_pile.append(card)
			reaction_triggered.emit(card)
			print("[DECK] Reaction triggered: %s" % card.card_name)
	if triggered.size() > 0:
		hand_updated.emit()
	return triggered

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
