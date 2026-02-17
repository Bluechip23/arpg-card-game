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
func _create_card_from_id(card_id: String) -> Card:
	match card_id:
		# Base cards
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
		# Brad cards
		"life_swap": return Card.create_life_swap()
		"wear_down": return Card.create_wear_down()
		"taunt": return Card.create_taunt()
		"life_steal": return Card.create_life_steal()
		"roar": return Card.create_roar()
		"poke": return Card.create_poke()
		"armor_break": return Card.create_armor_break()
		"charge": return Card.create_charge()
		"heroic_leap": return Card.create_heroic_leap()
		"morphine": return Card.create_morphine()
		"turtle_up": return Card.create_turtle_up()
		"parry": return Card.create_parry()
		"approach": return Card.create_approach()
		"hold_the_line": return Card.create_hold_the_line()
		# Jeremy cards
		"trick_shot": return Card.create_trick_shot()
		"surrounding_ice": return Card.create_surrounding_ice()
		"risk_it": return Card.create_risk_it()
		"biscuit": return Card.create_biscuit()
		"loaded_die": return Card.create_loaded_die()
		"worst_that_could_happen": return Card.create_worst_that_could_happen()
		"oops": return Card.create_oops()
		"house_money": return Card.create_house_money()
		"hope_this_works": return Card.create_hope_this_works()
		"lady_luck": return Card.create_lady_luck()
		"try_this": return Card.create_try_this()
		"if_pigs_could_fly": return Card.create_if_pigs_could_fly()
		"snowballs_chance": return Card.create_snowballs_chance()
		# Ryan cards
		"raged_circulation": return Card.create_raged_circulation()
		"poisoned_blood": return Card.create_poisoned_blood()
		"elixir": return Card.create_elixir()
		"ryan_heal": return Card.create_ryan_heal()
		"shadows": return Card.create_shadows()
		"preparation": return Card.create_preparation()
		"exacerbate_wounds": return Card.create_exacerbate_wounds()
		"reposition": return Card.create_reposition()
		"ryan_dagger_throw": return Card.create_ryan_dagger_throw()
		"volatile_mixture": return Card.create_volatile_mixture()
		"understanding": return Card.create_understanding()
		# Stephen cards
		"mark": return Card.create_mark()
		"rise": return Card.create_rise()
		"quick_shot": return Card.create_quick_shot()
		"reload": return Card.create_reload()
		"enchanted_quiver": return Card.create_enchanted_quiver()
		"tighten_string": return Card.create_tighten_string()
		"down_town": return Card.create_down_town()
		"barricade": return Card.create_barricade()
		"sky_fall": return Card.create_sky_fall()
		"sky_attack": return Card.create_sky_attack()
		"lead_arrow": return Card.create_lead_arrow()
		"last_breath": return Card.create_last_breath()
		"mixed_bag": return Card.create_mixed_bag()
		# Cory cards
		"round_em_up": return Card.create_round_em_up()
		"trip": return Card.create_trip()
		"choke": return Card.create_choke()
		"push": return Card.create_push()
		"defensive_awareness": return Card.create_defensive_awareness()
		"sweeping_disarm": return Card.create_sweeping_disarm()
		"cory_blink": return Card.create_cory_blink()
		"consecutive_snap": return Card.create_consecutive_snap()
		"swap": return Card.create_swap()
		"meditate": return Card.create_meditate()
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

	# Sticky cards stay in hand until played enough times
	if card.sticky > 0:
		card.consecutive_uses += 1
		if card.consecutive_uses >= card.sticky:
			# Fully used up - discard
			discard_pile.append(card)
			card_discarded.emit(card)
			print("[DECK] %s sticky exhausted (%d/%d uses) - discarded" % [card.card_name, card.consecutive_uses, card.sticky])
		else:
			# Put back in hand
			hand.insert(min(index, hand.size()), card)
			print("[DECK] %s sticky (%d/%d uses) - stays in hand" % [card.card_name, card.consecutive_uses, card.sticky])
	else:
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
