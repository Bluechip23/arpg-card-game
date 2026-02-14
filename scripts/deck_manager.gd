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

enum OverflowMode { JAILED, ENHANCE, PEAK, TRANSFERRED, OVERCHARGE, MANIFEST }

var draw_pile: Array[Card] = []
var hand: Array[Card] = []
var discard_pile: Array[Card] = []
var jail_pile: Array[Card] = []

var player_stats: PlayerStats
var inventory: Inventory
var overflow_manager: OverflowManager

var peaked_card: Card = null

var next_attack_free: bool = false
var next_attack_mana_discount: int = 0

func connect_player_stats(stats: PlayerStats) -> void:
	player_stats = stats

func connect_inventory(inv: Inventory) -> void:
	inventory = inv

func connect_overflow_manager(om: OverflowManager) -> void:
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
	
	# Add character's unique card (2 copies)
	if character.unique_card_id != "":
		for i in range(2):
			var unique_card = _create_card_from_id(character.unique_card_id)
			if unique_card:
				draw_pile.append(unique_card)
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
func _create_card_from_id(card_id: String) -> Card:
	match card_id:
		"slash": return Card.create_slash()
		"block": return Card.create_block()
		"discard": return Card.create_discard()
		"draw": return Card.create_draw()
		"empower": return Card.create_empower()
		"blink": return Card.create_blink()
		"heal": return Card.create_heal()
		"gain_mana": return Card.create_gain_mana()
		"healing_potion": return Card.create_healing_potion()
		"dagger_throw": return Card.create_dagger_throw()
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
	hand.append(card)
	peaked_card = null
	card_drawn.emit(card)
	hand_updated.emit()
	
	if inventory:
		inventory.on_card_drawn()
	
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
		
		if card.card_type == Card.CardType.UTILITY and card.mana_cost > 0:
			if not debuff_mgr.can_play_spell_cards():
				print("[DECK] Cannot play spell cards - Silenced!")
				return { "played": false, "free_turn": false }
	
	var mana_cost = card.mana_cost - next_attack_mana_discount
	
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
	
	var damage_reduction = 0
	var self_damage_percent = 0.0
	var buff_mgr = null
	
	if debuff_mgr:
		damage_reduction = debuff_mgr.get_damage_reduction()
		self_damage_percent = debuff_mgr.get_self_damage_percent()
	
	if player_node and player_node.has_method("get_buff_manager"):
		buff_mgr = player_node.get_buff_manager()
	
	card.execute(target, player_stats, self, damage_reduction, self_damage_percent, buff_mgr)
	
	if debuff_mgr and card.card_type == Card.CardType.ATTACK:
		debuff_mgr.on_attack()
	
	if card.card_id == "blink" and player_node:
		player_node.blink_to_mouse()
	
	if inventory:
		inventory.on_card_played(card)
	
	discard_pile.append(card)
	card_discarded.emit(card)
	
	if clumsy_triggered and hand.size() > 0:
		var random_index = randi() % hand.size()
		var discarded_card = hand[random_index]
		hand.remove_at(random_index)
		discard_pile.append(discarded_card)
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
	for i in range(jail_pile.size() - 1, -1, -1):
		var card = jail_pile[i]
		card.jail_time_remaining -= 1
		if card.jail_time_remaining <= 0:
			jail_pile.remove_at(i)
			discard_pile.append(card)
			print("[DECK] Released from jail: %s" % card.card_name)

func get_peaked_card() -> Card:
	return peaked_card

func get_draw_pile_size() -> int:
	return draw_pile.size()

func get_discard_pile_size() -> int:
	return discard_pile.size()

func get_jail_pile_size() -> int:
	return jail_pile.size()
