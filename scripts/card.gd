class_name Card
extends Resource

## Card resource that holds card data

enum CardType { ATTACK, DEFENSE, UTILITY }

@export var card_id: String = "slash"
@export var card_name: String = "Slash"
@export var description: String = "10 damage"
@export var card_type: CardType = CardType.ATTACK
@export var card_type_name: String = "Attack"
@export var mana_cost: int = 1
@export var damage: int = 10
@export var block: int = 0
@export var heal_amount: int = 0
@export var tempo_cost: int = 1
var is_enhanced: bool = false  
var base_damage: int = 10
var base_block: int = 0
var bonus_damage: int = 0
var jail_time_remaining: int = 0
var chance_effect_percent: float = 0.0  # e.g., 30 for 30%
var chance_effect_description: String = ""
var is_aoe: bool = false
var aoe_shape: String = ""  # "cone", "circle", "line"
var aoe_range: float = 100.0
var rng_outcomes: Dictionary = {}  # enemy_id -> bool (will effect trigger?)
var rng_roll_turn: int = 0  # Turn when RNG was last rolled
var turns_in_hand: int = 0  # How long card has been in hand
func roll_rng(enemies: Array, chance_boost: float = 0.0) -> void:
	rng_outcomes.clear()
	var effective_chance = chance_effect_percent + chance_boost
	
	for enemy in enemies:
		if is_instance_valid(enemy):
			var roll = randf() * 100.0
			var success = roll < effective_chance
			rng_outcomes[enemy.get_instance_id()] = success
			print("[CARD] %s RNG for %s: %.1f%% → %s" % [card_name, enemy.enemy_name, effective_chance, "SUCCESS" if success else "FAIL"])

func get_rng_outcome(enemy) -> bool:
	if not enemy:
		return false
	var id = enemy.get_instance_id()
	return rng_outcomes.get(id, false)

func has_chance_effect() -> bool:
	return chance_effect_percent > 0.0

func should_reroll_rng(current_turn: int) -> bool:
	# Reroll every 3 turns in hand
	return current_turn - rng_roll_turn >= 3

func increment_turns_in_hand() -> void:
	turns_in_hand += 1

func reset_hand_tracking() -> void:
	turns_in_hand = 0
	rng_outcomes.clear()
func execute(target, player_stats: PlayerStats = null, deck_manager = null, damage_reduction: int = 0, self_damage_percent: float = 0.0, buff_mgr: BuffManager = null) -> void:
	var is_empowered = false
	if player_stats and player_stats.is_empowered():
		is_empowered = player_stats.consume_empower()
	match card_id:
		"slash":
			_execute_slash(target, is_empowered, player_stats, damage_reduction, self_damage_percent, buff_mgr)
		"block":
			_execute_block(player_stats, is_empowered, buff_mgr)
		"discard":
			_execute_discard(deck_manager)
		"draw":
			_execute_draw(deck_manager)
		"empower":
			_execute_empower(player_stats)
		"blink":
			_execute_blink(target)
		"heal":
			_execute_heal(player_stats)
		"gain_mana":
			_execute_gain_mana(player_stats)
		"healing_potion":
			_execute_healing_potion(player_stats)
		"dagger_throw":
			_execute_dagger_throw(target, is_empowered, player_stats, damage_reduction, self_damage_percent)
		_:
			print("[CARD] Unknown card: %s" % card_id)
			
func _execute_gain_mana(player_stats: PlayerStats) -> void:
	if player_stats:
		var amount = 2
		# Intelligence boosts mana gain via spell multiplier
		amount = player_stats.get_effective_heal_amount(amount)
		player_stats.gain_mana(amount)
		print("[CARD] Gained %d mana!" % amount)
		
func _execute_slash(target, is_empowered: bool, player_stats: PlayerStats, damage_reduction: int = 0, self_damage_percent: float = 0.0, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage
	
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
		player_stats.register_attack()
	
	if is_empowered and player_stats:
		total_damage += player_stats.empower_damage_bonus
	
	# Strengthen bonus
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		
		# Crit check with Enlightened
		if buff_mgr.roll_crit():
			total_damage = floori(total_damage * 2.0)
			print("[CARD] CRITICAL HIT! Damage doubled!")
			buff_mgr.consume_enlightened()
	
	total_damage = max(1, total_damage - damage_reduction)
	
	print("[CARD] %s deals %d damage!" % [card_name, total_damage])
	
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage)
		
		# Thorns check - if target has buff_manager
		if target.has_method("get_buff_manager"):
			var target_buff = target.get_buff_manager()
			if target_buff:
				target_buff.on_attacked(player_stats.owner_node if player_stats else null)
	
	if self_damage_percent > 0.0 and player_stats:
		var self_dmg = floori(total_damage * self_damage_percent)
		if self_dmg > 0:
			player_stats.take_damage(self_dmg)
			print("[CARD] Cursed: took %d self-damage!" % self_dmg)
func _execute_dagger_throw(target, is_empowered: bool, player_stats: PlayerStats, damage_reduction: int = 0, self_damage_percent: float = 0.0) -> void:
	var total_damage = base_damage + bonus_damage
	
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	
	if is_empowered and player_stats:
		total_damage += player_stats.empower_damage_bonus
	
	total_damage = max(1, total_damage - damage_reduction)
	
	print("[CARD] Dagger Throw deals %d damage!" % total_damage)
	
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage)
	
	if self_damage_percent > 0.0 and player_stats:
		var self_dmg = floori(total_damage * self_damage_percent)
		if self_dmg > 0:
			player_stats.take_damage(self_dmg)
func _execute_block(player_stats: PlayerStats, is_empowered: bool = false, buff_mgr: BuffManager = null) -> void:
	var armor_amount = block
	
	if is_empowered and player_stats:
		armor_amount = max(1, armor_amount - player_stats.empower_block_reduction)
	
	# Bolster bonus
	if buff_mgr:
		armor_amount += buff_mgr.consume_bolster()
	
	if player_stats:
		player_stats.add_armor(armor_amount)
	
	print("[CARD] %s grants %d armor!" % [card_name, armor_amount])

func _execute_discard(deck_manager) -> void:
	if deck_manager and deck_manager.hand.size() > 0:
		var random_index = randi() % deck_manager.hand.size()
		var discarded = deck_manager.hand[random_index]
		deck_manager.hand.remove_at(random_index)
		deck_manager.discard_pile.append(discarded)
		deck_manager.hand_updated.emit()
		print("[CARD] Discarded: %s" % discarded.card_name)
	else:
		print("[CARD] No cards to discard!")

func _execute_draw(deck_manager) -> void:
	if deck_manager:
		deck_manager.draw_card()
		print("[CARD] Drew a card!")

func _execute_empower(player_stats: PlayerStats) -> void:
	if player_stats:
		player_stats.apply_empower(2)
		print("[CARD] Next 2 cards empowered!")

func _execute_blink(player_node) -> void:
	if player_node and player_node.has_method("blink_to_mouse"):
		player_node.blink_to_mouse()
		print("[CARD] Blinked!")

func _execute_heal(player_stats: PlayerStats) -> void:
	if player_stats:
		player_stats.heal(heal_amount)
		print("[CARD] Heal restored health!")
		
func _execute_healing_potion(player_stats: PlayerStats) -> void:
	if player_stats:
		player_stats.heal(heal_amount)
		print("[CARD] Healing Potion restored health!")

func enhance(amount: int) -> bool:
	# Only enhance attack cards, and only once
	if card_type != CardType.ATTACK:
		print("[CARD] %s is not an attack card, cannot enhance" % card_name)
		return false
	
	if is_enhanced:
		print("[CARD] %s already enhanced, skipping" % card_name)
		return false
	
	bonus_damage += amount
	is_enhanced = true
	print("[CARD] %s enhanced! Bonus damage now: %d" % [card_name, bonus_damage])
	return true

func get_total_damage() -> int:
	return base_damage + bonus_damage

func is_jailed() -> bool:
	return jail_time_remaining > 0

# This is now handled by deck_manager.process_turn()
# Can remove update_jail or keep for compatibility
func update_jail_turn() -> void:
	if jail_time_remaining > 0:
		jail_time_remaining -= 1
		if jail_time_remaining <= 0:
			print("[CARD] %s released from jail!" % card_name)

func jail(duration: int) -> void:
	jail_time_remaining = duration
	print("[CARD] %s jailed for %d turns" % [card_name, duration])

# Factory methods
static func create_slash() -> Card:
	var card = Card.new()
	card.card_id = "slash"
	card.card_name = "Slash"
	card.description = "10 damage"
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 1
	card.tempo_cost = 1  # Standard attack
	card.damage = 10
	card.base_damage = 10
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	return card

static func create_block() -> Card:
	var card = Card.new()
	card.card_id = "block"
	card.card_name = "Block"
	card.description = "5 armor"
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 1
	card.tempo_cost = 1  # Standard defense
	card.damage = 0
	card.base_damage = 0
	card.block = 5
	card.base_block = 5
	card.heal_amount = 0
	return card

static func create_discard() -> Card:
	var card = Card.new()
	card.card_id = "discard"
	card.card_name = "Discard"
	card.description = "Discard a random card"
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 0
	card.tempo_cost = 0  # Quick action
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	return card

static func create_draw() -> Card:
	var card = Card.new()
	card.card_id = "draw"
	card.card_name = "Draw"
	card.description = "Draw a card"
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 0
	card.tempo_cost = 0  # Quick action
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	return card

static func create_empower() -> Card:
	var card = Card.new()
	card.card_id = "empower"
	card.card_name = "Empower"
	card.description = "Next 2 cards: +3 dmg or -3 block"
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 1
	card.tempo_cost = 1  # Setup action
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	return card

static func create_blink() -> Card:
	var card = Card.new()
	card.card_id = "blink"
	card.card_name = "Blink"
	card.description = "Teleport to cursor"
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 2
	card.tempo_cost = 0  # Instant teleport
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	return card

static func create_heal() -> Card:
	var card = Card.new()
	card.card_id = "heal"
	card.card_name = "Heal"
	card.description = "Restore 4 HP"
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 1
	card.tempo_cost = 1  # Takes effort to heal
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 4
	return card

static func create_gain_mana() -> Card:
	var card = Card.new()
	card.card_id = "gain_mana"
	card.card_name = "Energy"
	card.description = "Gain 2 mana"
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 0
	card.tempo_cost = 0  # Free energy burst
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	return card

static func create_healing_potion() -> Card:
	var card = Card.new()
	card.card_id = "healing_potion"
	card.card_name = "Healing Potion"
	card.description = "Heal 5"
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 1
	card.tempo_cost = 0  # Quick drink
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 5
	return card

static func create_dagger_throw() -> Card:
	var card = Card.new()
	card.card_id = "dagger_throw"
	card.card_name = "Dagger Throw"
	card.description = "5 damage"
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 1
	card.tempo_cost = 0  # Quick throw
	card.damage = 5
	card.base_damage = 5
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	return card
