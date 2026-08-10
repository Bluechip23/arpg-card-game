class_name Inventory
extends Node

## Manages character equipment slots and inventory

signal equipment_changed
signal item_equipped(item: ItemData, slot_type: String, slot_index: int)
signal item_unequipped(item: ItemData, slot_type: String, slot_index: int)
signal overflow_heal_armor_triggered(heal: int, armor: int)
signal ring_triggered(item: ItemData, effect: String)
signal gauntlet_skill_ready(item: ItemData)
signal storage_changed
signal card_enchanted(card: Card, item: ItemData)
signal card_extracted(card: Card, item: ItemData, destroyed_item: bool)
signal rack_changed

# Slot configuration
var helm_slots: int = 1
var chest_slots: int = 1
var ring_slots: int = 2
var belt_slots: int = 1
var boots_slots: int = 1
var gauntlets_slots: int = 1
var weapon_slots: int = 2

# Special modifiers
var chest_weight_reduction: float = 0.0  # Brad
var belt_card_mana_reduction: int = 0     # Ryan
var ring_double_trigger: bool = false     # Jeremy
var off_hand_bonus: float = 0.0           # Stephen (+10%), others get -10% penalty
var gauntlet_cooldown_mana: bool = false  # Cory

# Jeremy's double trigger only arms every Nth cycle (every cycle proved busted).
const RING_DOUBLE_TRIGGER_CYCLES: int = 3

# Default off-hand penalty
const DEFAULT_OFF_HAND_PENALTY: float = 0.9  # -10%

# ============================================
# TWO-HANDED & DUAL WIELDING
# ============================================
# Any weapon or shield can be two-handed — a per-slot player choice, never
# an item property. Two-handing halves the item's carried weight (letting
# weaker characters wield huge gear) but drops TOTAL carry capacity to 70%
# (PlayerStats.TWO_HAND_CAPACITY_MULT) and consumes a second hand slot.
# Weapons gain damage from their ORIGINAL weight; shields gain Basic Block
# armor the same way.
const TWO_HAND_WEIGHT_MULT: float = 0.5
# +1 damage/block per 25 weight (4% of weight). At 10% a heavy mid-tier weapon
# effectively doubled its damage; 4% reserves the doubling for true monsters.
const TWO_HAND_WEIGHT_DAMAGE_DIVISOR: float = 25.0

# Dual wielding (a pair of weapons — or a pair of shields — in hand slots):
# EVERY item in the pair carries 15% extra weight, so a heavy main hand can't
# hide from the penalty behind a feather off-hand. Two small blades barely
# notice; pairing real weapons (or walking in behind twin shields) is a
# strength commitment. Sword-and-board mixes classes and pays nothing.
const DUAL_WIELD_WEIGHT_MULT: float = 1.15

var two_handed_slot: int = -1       # weapon slot currently held with both hands
var two_handed_lock_slot: int = -1  # the empty hand slot two-handing occupies

# ============================================
# WAR RACK (Brad's slot identity)
# ============================================
# Gear strapped across his back. rack_exchange() swaps EVERYTHING in the hand
# slots with everything on the rack, wholesale. The FREE exchange costs no
# tempo but sits on a cooldown, requires one side of the exchange to be a
# single item held two-handed (the fantasy is hauling the huge thing off
# his back), and rushes the incoming items' cards straight to hand. Paid
# exchanges work anytime under the normal swap-tempo rules.
var has_back_rack: bool = false
var rack_items: Array = []           # items on the back (up to weapon_slots)
var rack_cooldown_tempo: int = 0     # tempo until the next FREE exchange
const RACK_FREE_SWAP_COOLDOWN: int = 25

# ============================================
# EQUIPMENT BUILDS (loadouts I / II / III)
# ============================================
const BUILD_COUNT: int = 3
var builds: Array = [null, null, null]  # saved equipment snapshots (null = never used)
var active_build: int = 0
# Set while switch_build() rearranges gear: per-item carry gates are skipped
# because the switch validates the END state as a whole before starting.
var _bulk_build_switch: bool = false

var character_name: String = ""

# Equipped items
var equipped_helms: Array[ItemData] = []
var equipped_chests: Array[ItemData] = []
var equipped_rings: Array[ItemData] = []
var equipped_belts: Array[ItemData] = []
var equipped_boots: Array[ItemData] = []
var equipped_gauntlets: Array[ItemData] = []
var equipped_weapons: Array[ItemData] = []

# Non-equipped storage (grid inventory). Items and looted cards share the ONE
# pool of max_storage_slots — there is no separate card inventory; the two
# arrays only keep the types apart.
var stored_items: Array[ItemData] = []
var max_storage_slots: int = 20

# Stash storage (town stash - persistent, separate from inventory)
var stash_items: Array[ItemData] = []
var max_stash_slots: int = 30

# Cards picked up from loot (they occupy regular inventory slots)
var stored_cards: Array = []  # Array of Card objects

# Consumables
var culling_stones: int = 99  # Used to permanently remove cards from deck
var paper_feathers: int = 3  # Card-crafting consumable (role being redesigned)
var origami_swans: int = 0  # 20 origami swans = 1 Paper Feather (crafted by Olorin)
var mythic_molds: int = 0  # 2 molded-down mythics = 1 Mold; redeem for any mythic at the Blacksmith

# Ring trigger tracking
var ring_triggered_this_turn: bool = false
var armor_gained_this_turn: int = 0
var ring_cycle_count: int = 0  # cycles elapsed, for Jeremy's every-3rd-cycle double trigger

# Prevents infinite loop when granting armor-on-armor-gain bonuses
var _applying_armor_instance_bonus: bool = false

# References
var player_stats = null  # PlayerStats - untyped to avoid circular dependency
var deck_manager = null  # DeckManager - untyped to avoid circular dependency

func initialize(char_name: String) -> void:
	character_name = char_name
	
	# Universal baseline every character starts from:
	# 1 helm, 2 rings, 1 belt, 1 chest, 1 main hand, 1 off hand,
	# 1 pair of boots, 1 gauntlet.
	helm_slots = 1
	chest_slots = 1
	ring_slots = 2
	belt_slots = 1
	boots_slots = 1
	gauntlets_slots = 1
	weapon_slots = 2  # main hand (index 0) + off hand (index 1)
	chest_weight_reduction = 0.0
	belt_card_mana_reduction = 0
	ring_double_trigger = false
	off_hand_bonus = 0.0
	gauntlet_cooldown_mana = false

	# Per-character deviations from the baseline.
	match character_name:
		"Ryan":
			belt_slots = 3
			belt_card_mana_reduction = 10
		"Brad":
			chest_weight_reduction = 0.20
			has_back_rack = true  # War Rack: hands <-> back exchange (see rack_exchange)
		"Jeremy":
			ring_slots = 4
			ring_double_trigger = true  # doubles every RING_DOUBLE_TRIGGER_CYCLES cycles
		"Stephen":
			off_hand_bonus = 0.2  # +10% instead of -10% = +20% total swing
		"Cory":
			gauntlets_slots = 2
			gauntlet_cooldown_mana = true
	
	_init_slot_arrays()
	
	print("[INVENTORY] Initialized for %s" % character_name)
	_print_passives()

func _print_passives() -> void:
	if belt_card_mana_reduction > 0:
		print("[INVENTORY] Passive: Belt cards cost %d less mana" % belt_card_mana_reduction)
	if chest_weight_reduction > 0:
		print("[INVENTORY] Passive: Chest items weigh %.0f%% less" % (chest_weight_reduction * 100))
	if ring_double_trigger:
		print("[INVENTORY] Passive: Every %d cycles, the first ring trigger triggers twice" % RING_DOUBLE_TRIGGER_CYCLES)
	if off_hand_bonus > 0:
		print("[INVENTORY] Passive: +%.0f%% off-hand bonuses" % (off_hand_bonus * 100))
	if gauntlet_cooldown_mana:
		print("[INVENTORY] Passive: Gain 10 mana when gauntlet skill comes off cooldown")

func _init_slot_arrays() -> void:
	equipped_helms.clear()
	equipped_chests.clear()
	equipped_rings.clear()
	equipped_belts.clear()
	equipped_boots.clear()
	equipped_gauntlets.clear()
	equipped_weapons.clear()

	equipped_helms.resize(helm_slots)
	equipped_chests.resize(chest_slots)
	equipped_rings.resize(ring_slots)
	equipped_belts.resize(belt_slots)
	equipped_boots.resize(boots_slots)
	equipped_gauntlets.resize(gauntlets_slots)
	equipped_weapons.resize(weapon_slots)

func connect_player_stats(stats) -> void:
	player_stats = stats
	stats.inventory = self
	# Weapon mastery breakpoints check base stats — re-test them whenever stats
	# change so a fresh allocation immediately releases newly-mastered cards.
	if not stats.stats_updated.is_connected(refresh_mastery_cards):
		stats.stats_updated.connect(refresh_mastery_cards)

func connect_deck_manager(deck) -> void:
	deck_manager = deck

func refresh_mastery_cards() -> void:
	## Base stats only ever grow, so this only ever RELEASES held-back mastery
	## cards (via the normal add path, which skips cards already in a zone).
	if not deck_manager or not player_stats:
		return
	for item in equipped_weapons:
		if item and item.has_mastery() and item.is_mastered_by(player_stats):
			_add_item_cards_to_deck(item)

func get_off_hand_modifier() -> float:
	# Stephen gets bonus, others get penalty
	return DEFAULT_OFF_HAND_PENALTY + off_hand_bonus

# Story rule: a character can wear one mythic per 10 character levels
# (level 0-9 none, 10-19 one, 20-29 two, ...). Sandbox turns this off —
# that's where testing happens (see main._setup_sandbox).
var enforce_mythic_limit: bool = true
signal equip_blocked(item: ItemData, reason: String)

func get_mythic_capacity() -> int:
	if not player_stats:
		return 0
	return int(player_stats.current_level / 10.0)

func count_equipped_mythics() -> int:
	var n := 0
	# (Quiver items live in the weapon slots — there is no separate quiver array.)
	for arr in [equipped_helms, equipped_chests, equipped_rings, equipped_belts,
			equipped_boots, equipped_gauntlets, equipped_weapons]:
		for it in arr:
			if it and it.rarity == ItemData.Rarity.MYTHIC:
				n += 1
	return n

func equip_item(item: ItemData, slot_index: int = 0) -> bool:
	var slot_array = _get_slot_array(item.item_type)
	var max_slots = _get_max_slots(item.item_type)

	if slot_index < 0 or slot_index >= max_slots:
		print("[INVENTORY] Invalid slot index %d for %s" % [slot_index, item.item_name])
		return false

	if enforce_mythic_limit and item.rarity == ItemData.Rarity.MYTHIC \
			and count_equipped_mythics() >= get_mythic_capacity():
		var reason = "Mythic limit: level %d allows %d mythic(s) equipped" % [
			player_stats.current_level if player_stats else 0, get_mythic_capacity()]
		print("[INVENTORY] %s — cannot equip %s" % [reason, item.item_name])
		equip_blocked.emit(item, reason)
		return false
	
	if slot_array[slot_index] != null:
		print("[INVENTORY] Slot %d already occupied" % slot_index)
		return false

	# Two-handing occupies a second hand slot — nothing else fits there.
	if slot_array == equipped_weapons and two_handed_slot >= 0 and slot_index == two_handed_lock_slot:
		print("[INVENTORY] Slot %d is locked by two-handing" % slot_index)
		return false

	# Bows and magic staffs demand both hands: they never share the hand slots
	# with other gear — only a quiver (its own slot) rides along with a bow.
	if slot_array == equipped_weapons:
		var conflict = hand_conflict_reason(item, slot_index)
		if conflict != "":
			print("[INVENTORY] %s: %s" % [item.item_name, conflict])
			return false

	# Hard carry gate: refuse an equip that would push the character (further)
	# past capacity. Uses the PROSPECTIVE delta so two-handing discounts and the
	# dual-wield surcharge (which re-weighs the OTHER hand too) are counted.
	if not _bulk_build_switch and not _carry_change_allowed(_prospective_weight_delta(item, slot_array, slot_index), two_handed_slot >= 0):
		print("[INVENTORY] %s is too heavy! Carry: %d/%d, item weight %d" % [
			item.item_name, get_total_weight(),
			player_stats.get_carry_capacity() if player_stats else 0, item.weight])
		return false

	slot_array[slot_index] = item
	item.armor_per_tempo_accum = 0  # periodic-armor counter restarts on equip

	# Slot index > 0 means off-hand. (Later two-handing re-applies the
	# item's bonuses at full strength — see set_two_handed.)
	var is_off_hand = (item.item_type == ItemData.ItemType.WEAPON and slot_index > 0)

	_apply_item_bonuses(item, true, is_off_hand)
	_apply_special_effect(item, true)
	# Bring the item's owned cards (granted + slotted) into play — to discard,
	# or to jail if a card was jailed when the item was last removed.
	_add_item_cards_to_deck(item)

	item_equipped.emit(item, item.get_type_name(), slot_index)
	equipment_changed.emit()

	print("[INVENTORY] Equipped %s in slot %d" % [item.item_name, slot_index])
	return true

func unequip_item(item_type: ItemData.ItemType, slot_index: int) -> ItemData:
	var slot_array = _get_slot_array(item_type)
	var max_slots = _get_max_slots(item_type)
	
	if slot_index < 0 or slot_index >= max_slots:
		return null
	
	var item = slot_array[slot_index]
	if item == null:
		return null
	
	var is_off_hand = (item.item_type == ItemData.ItemType.WEAPON and
					   slot_index > 0 and slot_index != two_handed_slot)

	slot_array[slot_index] = null
	item.armor_per_tempo_accum = 0  # counter resets when unequipped (per spec)
	# Losing the item releases two-handing with it
	if slot_array == equipped_weapons and slot_index == two_handed_slot:
		_clear_two_handed_state()
	_apply_item_bonuses(item, false, is_off_hand)
	_apply_special_effect(item, false)
	# Pull the item's owned cards out of every zone. The instances stay attached
	# to the item (preserving jail time, enhancement, etc.) for when it returns.
	_remove_item_cards_from_deck(item)

	item_unequipped.emit(item, item.get_type_name(), slot_index)
	equipment_changed.emit()
	
	print("[INVENTORY] Unequipped %s from slot %d" % [item.item_name, slot_index])
	return item

## Bows and magic staffs are two-hand-only: never sharable with another hand
## item. (A quiver may ride along with a bow; a staff shares with nothing.)
static func is_two_hand_only(item: ItemData) -> bool:
	return item != null and item.item_type == ItemData.ItemType.WEAPON \
		and (item.weapon_subtype == ItemData.WeaponSubtype.BOW \
		or item.weapon_subtype == ItemData.WeaponSubtype.STAFF)

func hand_conflict_reason(item: ItemData, slot_index: int) -> String:
	## Two-hand-only rule: bows and magic staffs are two-handed weapons. While
	## one is in the hands, the only other hand item allowed is a quiver
	## alongside a BOW (quivers live in their own slots); a staff shares the
	## hands with nothing. Returns "" when placing `item` into weapon slot
	## `slot_index` is legal. The check ignores the item itself so moving it
	## between hand slots works.
	if item.item_type == ItemData.ItemType.QUIVER:
		for i in range(weapon_slots):
			var other = equipped_weapons[i]
			if i != slot_index and other != null and other != item \
					and other.item_type == ItemData.ItemType.WEAPON \
					and other.weapon_subtype == ItemData.WeaponSubtype.STAFF:
				return "Both hands are channeling the staff — nothing fits alongside"
		return ""
	if item.item_type != ItemData.ItemType.WEAPON:
		return ""
	if item.weapon_subtype == ItemData.WeaponSubtype.BOW:
		for i in range(weapon_slots):
			var other = equipped_weapons[i]
			if i != slot_index and other != null and other != item \
					and other.item_type != ItemData.ItemType.QUIVER:
				return "A bow needs both hands — only a quiver can accompany it"
	elif item.weapon_subtype == ItemData.WeaponSubtype.STAFF:
		for i in range(weapon_slots):
			var other = equipped_weapons[i]
			if i != slot_index and other != null and other != item:
				return "A magic staff needs both hands — nothing can accompany it"
	else:
		for i in range(weapon_slots):
			var other = equipped_weapons[i]
			if i != slot_index and other != null and other != item \
					and other.item_type == ItemData.ItemType.WEAPON:
				if other.weapon_subtype == ItemData.WeaponSubtype.BOW:
					return "Both hands are on the bow — only a quiver fits alongside"
				if other.weapon_subtype == ItemData.WeaponSubtype.STAFF:
					return "Both hands are channeling the staff — nothing fits alongside"
	return ""

func get_equipped_item(item_type: ItemData.ItemType, slot_index: int) -> ItemData:
	var slot_array = _get_slot_array(item_type)
	var max_slots = _get_max_slots(item_type)
	
	if slot_index < 0 or slot_index >= max_slots:
		return null
	
	return slot_array[slot_index]

func _get_slot_array(item_type: ItemData.ItemType) -> Array:
	match item_type:
		ItemData.ItemType.HELM: return equipped_helms
		ItemData.ItemType.CHEST: return equipped_chests
		ItemData.ItemType.RING: return equipped_rings
		ItemData.ItemType.BELT: return equipped_belts
		ItemData.ItemType.BOOTS: return equipped_boots
		ItemData.ItemType.GAUNTLETS: return equipped_gauntlets
		# Quivers share the weapon (main/off-hand) slots — they occupy a hand.
		ItemData.ItemType.WEAPON: return equipped_weapons
		ItemData.ItemType.QUIVER: return equipped_weapons
	return []

func _get_max_slots(item_type: ItemData.ItemType) -> int:
	match item_type:
		ItemData.ItemType.HELM: return helm_slots
		ItemData.ItemType.CHEST: return chest_slots
		ItemData.ItemType.RING: return ring_slots
		ItemData.ItemType.BELT: return belt_slots
		ItemData.ItemType.BOOTS: return boots_slots
		ItemData.ItemType.GAUNTLETS: return gauntlets_slots
		ItemData.ItemType.WEAPON: return weapon_slots
		ItemData.ItemType.QUIVER: return weapon_slots
	return 0

func _apply_item_bonuses(item: ItemData, equipping: bool, is_off_hand: bool = false) -> void:
	if not player_stats:
		return
	
	var multiplier = 1 if equipping else -1
	var stats: Dictionary
	
	if is_off_hand:
		stats = item.get_effective_stats(true, get_off_hand_modifier())
		print("[INVENTORY] Applying off-hand modifier: %.0f%%" % (get_off_hand_modifier() * 100))
	else:
		stats = item.get_effective_stats(false, 1.0)
	
	# Modify base stats (determination will apply automatically)
	player_stats.base_strength += stats["strength_bonus"] * multiplier
	player_stats.base_dexterity += stats["dexterity_bonus"] * multiplier
	player_stats.base_intelligence += stats["intelligence_bonus"] * multiplier
	player_stats.base_wisdom += stats["wisdom_bonus"] * multiplier
	player_stats.base_agility += stats["agility_bonus"] * multiplier
	player_stats.determination += item.determination_bonus * multiplier
	
	# Direct resource modifications (not affected by determination)
	player_stats.max_health += stats["health_bonus"] * multiplier
	player_stats.current_health = min(player_stats.current_health, player_stats.max_health)
	
	player_stats.max_mana += stats["mana_bonus"] * multiplier
	player_stats.current_mana = min(player_stats.current_mana, player_stats.max_mana)
	
	# Hand size from item (survives recalculation via the tracked bonus)
	player_stats.equipment_hand_bonus += item.hand_size_bonus * multiplier

	# Ranged damage bonus (from quivers)
	if item.ranged_damage_bonus > 0:
		player_stats.ranged_damage_bonus += item.ranged_damage_bonus * multiplier
		print("[INVENTORY] Ranged damage bonus now: +%d" % player_stats.ranged_damage_bonus)

	# Healing bonus (from belts)
	if item.healing_bonus > 0:
		player_stats.healing_bonus += item.healing_bonus * multiplier
		print("[INVENTORY] Healing bonus now: +%d" % player_stats.healing_bonus)

	# Equipment crit / lifesteal / all-resistance (helms and beyond). Float
	# fields, so applied directly with the ±1 multiplier like the base stats.
	if item.crit_chance_percent != 0.0:
		player_stats.equipment_crit_bonus += item.crit_chance_percent * multiplier
	if item.lifesteal_percent != 0.0:
		player_stats.equipment_lifesteal_bonus += item.lifesteal_percent * multiplier
	if item.all_resistance_percent != 0.0:
		player_stats.equipment_resistance_bonus += item.all_resistance_percent * multiplier
	if item.block_bonus_to_defense_cards != 0:
		player_stats.equipment_defense_card_block += item.block_bonus_to_defense_cards * multiplier
	if item.block_to_armorless_defense_cards != 0:
		player_stats.equipment_armorless_defense_block += item.block_to_armorless_defense_cards * multiplier
	if item.brain_points_bonus != 0:
		player_stats.equipment_brain_points_bonus += item.brain_points_bonus * multiplier
	if item.peek_brain_discount != 0:
		player_stats.equipment_peek_discount += item.peek_brain_discount * multiplier
	if item.spell_power_per_attacks != 0:
		player_stats.equipment_spell_power_every_n += item.spell_power_per_attacks * multiplier
	if item.spell_power_bonus != 0:
		player_stats.equipment_spell_power_amount += item.spell_power_bonus * multiplier
	# Boots pass-2 riders
	if item.sidestep_bonus_armor != 0:
		player_stats.equipment_sidestep_bonus_armor += item.sidestep_bonus_armor * multiplier
	if item.movement_flash_discount != 0:
		player_stats.equipment_movement_flash_discount += item.movement_flash_discount * multiplier
	if item.highground_damage_percent != 0.0:
		player_stats.equipment_highground_damage_percent += item.highground_damage_percent * multiplier
	if item.melee_crit_flat_bonus != 0:
		player_stats.equipment_melee_crit_bonus += item.melee_crit_flat_bonus * multiplier
	if item.trap_damage_percent != 0.0:
		player_stats.equipment_trap_damage_percent += item.trap_damage_percent * multiplier
	if item.movement_flash_tempo_threshold != 0:
		# Last equipped boot with a threshold wins (only one boots slot in practice).
		player_stats.movement_flash_tempo_threshold = item.movement_flash_tempo_threshold if multiplier > 0 else 0
	if item.consecutive_attack_draw != 0:
		player_stats.consecutive_attacks_draw_at = item.consecutive_attack_draw if multiplier > 0 else 0

	# Recalculate derived stats
	player_stats.recalculate_derived_stats()
	
	# Update carry load
	_recalculate_carry_load()
	
	player_stats.health_changed.emit(player_stats.current_health, player_stats.max_health)
	player_stats.mana_changed.emit(player_stats.current_mana, player_stats.max_mana)
func _recalculate_carry_load() -> void:
	if not player_stats:
		return

	var total_weight = get_total_weight()
	player_stats.set_carry_load(total_weight)
	# Equipment changed — re-read the free-hand stance while we're here.
	player_stats.free_hand_stance = is_free_handing()
	
func _apply_special_effect(item: ItemData, equipping: bool) -> void:
	if not player_stats:
		return
	
	# NOTE: GRANT_BLINK_CARD / GRANT_CARDS no longer add/remove cards here. Item
	# card ownership (both granted and slotted cards) is handled uniformly by
	# _add_item_cards_to_deck / _remove_item_cards_from_deck, called from
	# equip_item / unequip_item, so cards travel with the item on every swap.
	match item.special_effect:
		ItemData.SpecialEffect.CHANCE_BOOST:
			var mult = 1 if equipping else -1
			player_stats.chance_boost += item.special_effect_value * mult
			print("[INVENTORY] Chance boost now: %.0f%%" % player_stats.chance_boost)

func _create_card_by_id(card_id: String) -> Card:
	match card_id:
		"healing_potion": return Card.create_healing_potion()
		"dagger_throw": return Card.create_dagger_throw()
		"blink": return Card.create_blink()
		"slash": return Card.create_slash()
		"block": return Card.create_block()
		"potion_of_continuance": return Card.create_potion_of_continuance()
		"gulped_potion": return Card.create_gulped_potion()
		"splinter": return Card.create_splinter()
	return null

func apply_equipped_item_card_effects() -> void:
	## Bring card-granting equipment's cards into the deck after initialization.
	## Save-restored gear is equipped BEFORE the deck manager exists, so
	## equip_item's card hook was a no-op then; this runs once the deck is
	## ready. The cards are shuffled into the DRAW pile (not discarded) so the
	## opening hand can contain them.
	if not deck_manager:
		return

	var cards_added = false
	for item_array in [equipped_belts, equipped_boots, equipped_helms, equipped_chests, equipped_rings, equipped_gauntlets, equipped_weapons]:
		for item in item_array:
			if not item:
				continue
			_ensure_granted_card_instances(item)
			for card in _get_item_owned_cards(item):
				if _card_in_any_zone(card):
					continue
				if _is_locked_mastery_card(item, card):
					continue
				deck_manager.draw_pile.append(card)
				print("[INVENTORY] Equipped item added %s to deck" % card.card_name)
				cards_added = true

	if cards_added:
		deck_manager.shuffle_draw_pile()
		print("[INVENTORY] Shuffled deck after adding equipped item cards")

# ============================================
# ITEM-OWNED CARDS (swap in / swap out)
# ============================================
# An equipped item "owns" two kinds of cards:
#   * granted cards  — added to the deck by GRANT_CARDS / GRANT_BLINK_CARD
#   * slotted cards  — enchanted into the item's card slots
# Both travel WITH the item: they enter the deck when it is equipped and are
# pulled from every zone when it is unequipped. The card INSTANCES persist on
# the item across swaps, so a jailed card comes back still jailed with the same
# time left. Cards a slotted card merely PRODUCES during play own themselves
# (neither granted_by_item nor slotted_in_item points here) and are left alone —
# they have detached from the item.

func _get_item_owned_cards(item: ItemData) -> Array:
	## Every card instance that belongs to this item (granted + slotted +
	## mastery), no dupes. Mastery cards are OWNED regardless of the wielder's
	## stats — the remove path must always be able to clean them up — but the
	## add paths skip them until the breakpoint is met (_is_locked_mastery_card).
	var cards: Array = []
	for card in item.granted_card_instances:
		if card and not cards.has(card):
			cards.append(card)
	for card in item.mastery_card_instances:
		if card and not cards.has(card):
			cards.append(card)
	for card in item.slotted_cards:
		if card and not cards.has(card):
			cards.append(card)
	return cards

func _is_locked_mastery_card(item: ItemData, card) -> bool:
	## True for a mastery card whose breakpoint the wielder hasn't reached yet.
	if not item.mastery_card_instances.has(card):
		return false
	return not item.is_mastered_by(player_stats)

func _ensure_granted_card_instances(item: ItemData) -> void:
	## Build the item's granted-card instances exactly once, then reuse forever.
	if item.granted_cards_built:
		return
	item.granted_cards_built = true

	for card_id in item.granted_card_ids:
		var card = _create_granted_card(card_id)
		if card:
			if item.item_type == ItemData.ItemType.BELT and belt_card_mana_reduction > 0:
				card.mana_cost = max(0, card.mana_cost - belt_card_mana_reduction)
				print("[INVENTORY] %s mana cost reduced to %d (belt bonus)" % [card.card_name, card.mana_cost])
			card.granted_by_item = item
			item.granted_card_instances.append(card)

	if item.special_effect == ItemData.SpecialEffect.GRANT_BLINK_CARD:
		for i in range(item.special_effect_value):
			var blink_card = Card.create_blink()
			blink_card.granted_by_item = item
			item.granted_card_instances.append(blink_card)

	# Mastery cards get instances up front too (same lifetime rules as granted
	# cards) — the add paths simply hold them back until the breakpoint is met.
	for card_id in item.mastery_card_ids:
		var card = _create_granted_card(card_id)
		if card:
			card.granted_by_item = item
			item.mastery_card_instances.append(card)

func _create_granted_card(card_id: String) -> Card:
	## Prefer the deck manager's comprehensive factory; fall back to the local map.
	if deck_manager and deck_manager.has_method("_create_card_from_id"):
		var card = deck_manager._create_card_from_id(card_id)
		if card:
			return card
	return _create_card_by_id(card_id)

func _add_item_cards_to_deck(item: ItemData) -> void:
	## Bring an item's owned cards into play. Called when the item is equipped.
	## Jailed cards return to jail (with their remaining time); everything else
	## goes to the discard pile.
	if not deck_manager:
		return
	_ensure_granted_card_instances(item)
	var owned = _get_item_owned_cards(item)
	if owned.is_empty():
		return
	var changed = false
	for card in owned:
		if _card_in_any_zone(card):
			continue  # already live — don't duplicate it into another pile
		if _is_locked_mastery_card(item, card):
			continue  # breakpoint not met yet — the card waits on the item
		if card.is_jailed():
			deck_manager.jail_pile.append(card)
			print("[INVENTORY] %s: returned jailed card '%s' (%d tempo left)" % [item.item_name, card.card_name, card.jail_time_remaining])
		else:
			deck_manager.discard_pile.append(card)
			print("[INVENTORY] %s: added card '%s' to discard" % [item.item_name, card.card_name])
		changed = true
	if changed:
		deck_manager.hand_updated.emit()

func _remove_item_cards_from_deck(item: ItemData) -> void:
	## Pull an item's owned cards out of every zone. Called when the item is
	## unequipped. Instances are kept on the item (state preserved) for re-equip.
	if not deck_manager:
		return
	var owned = _get_item_owned_cards(item)
	if owned.is_empty():
		return
	var hand_changed = false
	for card in owned:
		if _remove_card_from_all_zones(card):
			hand_changed = true
	if hand_changed:
		deck_manager.hand_updated.emit()

func _card_in_any_zone(card: Card) -> bool:
	if deck_manager.draw_pile.has(card): return true
	if deck_manager.hand.has(card): return true
	if deck_manager.discard_pile.has(card): return true
	if deck_manager.jail_pile.has(card): return true
	if deck_manager.maintained_cards.has(card): return true
	var om = deck_manager.overflow_manager
	if om:
		for entry in om.manifest_zone:
			if entry.get("card") == card:
				return true
		if om.quiver_zone.has(card):
			return true
	return false

func _remove_card_from_all_zones(card: Card) -> bool:
	## Remove a card instance from draw/hand/discard/jail/maintained/manifest/
	## quiver. Returns true if the hand changed (so the caller can refresh UI).
	## The card object itself is left intact — it stays attached to its item.
	var hand_changed = false
	var idx = deck_manager.hand.find(card)
	if idx >= 0:
		deck_manager.hand.remove_at(idx)
		hand_changed = true
	deck_manager.draw_pile.erase(card)
	deck_manager.discard_pile.erase(card)
	deck_manager.jail_pile.erase(card)
	# Maintained Power cards reserve mana — release it when pulled out.
	var m_idx = deck_manager.maintained_cards.find(card)
	if m_idx >= 0:
		deck_manager.maintained_cards.remove_at(m_idx)
		if player_stats and card.maintain_cost > 0:
			player_stats.release_mana(card.maintain_cost)
	var om = deck_manager.overflow_manager
	if om:
		for i in range(om.manifest_zone.size() - 1, -1, -1):
			if om.manifest_zone[i].get("card") == card:
				om.manifest_zone.remove_at(i)
				om.overflow_effects_changed.emit()
		if om.quiver_zone.has(card):
			om.quiver_zone.erase(card)
			om.quiver_changed.emit()
	return hand_changed

func _recalculate_total_weapon_weight() -> void:
	# This now just triggers carry load recalculation
	_recalculate_carry_load()

# ============================================
# TURN PROCESSING
# ============================================

func process_turn() -> void:
	# Reset per-turn tracking
	ring_triggered_this_turn = false
	armor_gained_this_turn = 0
	ring_cycle_count += 1

	# War Rack free-swap cooldown ticks with the cycle clock (5 tempo per cycle).
	if rack_cooldown_tempo > 0:
		rack_cooldown_tempo = maxi(0, rack_cooldown_tempo - 5)
		if rack_cooldown_tempo == 0:
			print("[INVENTORY] War Rack free swap ready!")
		rack_changed.emit()  # keeps the HUD countdown live
	
	# Process gauntlet cooldowns
	for gauntlet in equipped_gauntlets:
		if gauntlet and gauntlet.gauntlet_skill_type == ItemData.GauntletSkillType.ACTIVE:
			var came_off_cooldown = gauntlet.reduce_cooldown()
			if came_off_cooldown:
				print("[INVENTORY] %s skill ready!" % gauntlet.gauntlet_skill_name)
				gauntlet_skill_ready.emit(gauntlet)
				
				# Cory's passive: gain mana when skill comes off cooldown
				if gauntlet_cooldown_mana and player_stats:
					player_stats.gain_mana(10)
					print("[INVENTORY] Cory passive: Gained 10 mana from cooldown")

	# Grant periodic armor (ARMOR_PER_TURN) from any equipped chest or helm.
	# process_turn() fires once per 5-tempo cycle; each item banks 5 tempo and
	# grants its armor once its own interval (default 5, e.g. 15 for Mail Coif)
	# is reached. The accumulator resets on equip/unequip.
	if player_stats:
		for item in equipped_chests + equipped_helms + equipped_boots:
			if item and item.special_effect == ItemData.SpecialEffect.ARMOR_PER_TURN:
				item.armor_per_tempo_accum += 5  # one cycle = 5 tempo
				var interval: int = maxi(5, item.armor_per_tempo_interval)
				while item.armor_per_tempo_accum >= interval:
					item.armor_per_tempo_accum -= interval
					player_stats.add_armor(item.special_effect_value)
					print("[INVENTORY] %s: +%d armor (every %d tempo)" % [item.item_name, item.special_effect_value, interval])

# ============================================
# RING TRIGGER SYSTEM
# ============================================

func trigger_rings(trigger_type: ItemData.RingTrigger, value: int = 0) -> void:
	for ring in equipped_rings:
		if ring and ring.ring_trigger == trigger_type:
			# Check threshold if applicable
			if trigger_type == ItemData.RingTrigger.ON_GAIN_ARMOR_THRESHOLD:
				if value < ring.ring_trigger_threshold:
					continue
			
			_execute_ring_effect(ring)

			# Jeremy's passive: every 3rd cycle, the first ring trigger happens twice
			if is_ring_double_trigger_armed() and not ring_triggered_this_turn:
				print("[INVENTORY] Jeremy passive: Double trigger!")
				_execute_ring_effect(ring)

			ring_triggered_this_turn = true

func is_ring_double_trigger_armed() -> bool:
	## Jeremy's passive only doubles the first ring trigger on every
	## RING_DOUBLE_TRIGGER_CYCLES-th cycle (a per-cycle double proved busted).
	return ring_double_trigger and ring_cycle_count > 0 \
			and ring_cycle_count % RING_DOUBLE_TRIGGER_CYCLES == 0

func _execute_ring_effect(ring: ItemData) -> void:
	if not player_stats:
		return
	
	match ring.ring_effect:
		ItemData.RingEffect.HEAL_TO_FULL:
			player_stats.current_health = player_stats.max_health
			player_stats.health_changed.emit(player_stats.current_health, player_stats.max_health)
			print("[INVENTORY] Ring effect: Healed to full!")
		
		ItemData.RingEffect.GAIN_ARMOR:
			player_stats.add_armor(ring.ring_effect_value)
			print("[INVENTORY] Ring effect: Gained %d armor" % ring.ring_effect_value)
		
		ItemData.RingEffect.GAIN_MANA:
			player_stats.gain_mana(ring.ring_effect_value)
			print("[INVENTORY] Ring effect: Gained %d mana" % ring.ring_effect_value)
		
		ItemData.RingEffect.DRAW_CARD:
			if deck_manager:
				for i in range(ring.ring_effect_value):
					deck_manager.draw_card()
			print("[INVENTORY] Ring effect: Drew %d card(s)" % ring.ring_effect_value)
		
		ItemData.RingEffect.REDUCE_COOLDOWNS:
			for gauntlet in equipped_gauntlets:
				if gauntlet and gauntlet.current_cooldown > 0:
					gauntlet.current_cooldown = max(0, gauntlet.current_cooldown - ring.ring_effect_value)
			print("[INVENTORY] Ring effect: Reduced cooldowns by %d" % ring.ring_effect_value)
	
	ring_triggered.emit(ring, ring.get_ring_effect_name())

func on_armor_gained(amount: int) -> void:
	armor_gained_this_turn += amount
	trigger_rings(ItemData.RingTrigger.ON_GAIN_ARMOR_THRESHOLD, armor_gained_this_turn)

	# Apply armor-on-armor-gain passives across all equipment slots
	if not _applying_armor_instance_bonus and player_stats:
		_applying_armor_instance_bonus = true
		var all_slots = [equipped_helms, equipped_chests, equipped_rings, equipped_belts, equipped_boots, equipped_gauntlets, equipped_weapons]
		for slot in all_slots:
			for item in slot:
				if not item:
					continue
				# Bloodbound Plate uses OVERFLOW_HEAL_ARMOR with special_effect_value_2
				if item.special_effect == ItemData.SpecialEffect.OVERFLOW_HEAL_ARMOR and item.special_effect_value_2 > 0:
					player_stats.add_armor(item.special_effect_value_2)
					print("[INVENTORY] %s: +%d armor from armor instance" % [item.item_name, item.special_effect_value_2])
				# General armor-on-armor-gain items (helm, shield, gauntlets, etc.)
				elif item.special_effect == ItemData.SpecialEffect.ARMOR_ON_ARMOR_GAIN:
					player_stats.add_armor(item.special_effect_value)
					print("[INVENTORY] %s: +%d armor from armor instance" % [item.item_name, item.special_effect_value])
		_applying_armor_instance_bonus = false

func on_enemy_killed() -> void:
	trigger_rings(ItemData.RingTrigger.ON_ENEMY_KILL)
	_conjure_on_kill_cards()

## Items with on_kill_card_id (Bladed Doughnut) conjure a fresh copy of their
## card straight into the hand on every kill.
func _conjure_on_kill_cards() -> void:
	if not deck_manager:
		return
	var conjured = false
	var all_slots = [equipped_helms, equipped_chests, equipped_rings, equipped_belts, equipped_boots, equipped_gauntlets, equipped_weapons]
	for slot in all_slots:
		for item in slot:
			if item == null or item.on_kill_card_id == "":
				continue
			var card = deck_manager._create_card_from_id(item.on_kill_card_id)
			if card:
				deck_manager.hand.append(card)
				conjured = true
				print("[INVENTORY] %s: conjured '%s' into hand on kill" % [item.item_name, card.card_name])
	if conjured:
		deck_manager.hand_updated.emit()

func on_card_played(card: Card) -> void:
	if card.card_type == Card.CardType.ATTACK:
		trigger_rings(ItemData.RingTrigger.ON_PLAY_ATTACK_CARD)
	elif card.card_type == Card.CardType.UTILITY:
		trigger_rings(ItemData.RingTrigger.ON_PLAY_UTILITY_CARD)

func on_card_drawn() -> void:
	trigger_rings(ItemData.RingTrigger.ON_DRAW_CARD)

func on_damage_taken() -> void:
	trigger_rings(ItemData.RingTrigger.ON_TAKE_DAMAGE)

func on_healed() -> void:
	trigger_rings(ItemData.RingTrigger.ON_HEAL)

# ============================================
# GAUNTLET SKILL SYSTEM
# ============================================

func get_available_gauntlet_skills() -> Array[ItemData]:
	var skills: Array[ItemData] = []
	for gauntlet in equipped_gauntlets:
		if gauntlet and gauntlet.gauntlet_skill_type != ItemData.GauntletSkillType.NONE:
			skills.append(gauntlet)
	return skills

func can_use_gauntlet_skill(gauntlet: ItemData) -> bool:
	if gauntlet.gauntlet_skill_type != ItemData.GauntletSkillType.ACTIVE:
		return false
	if gauntlet.is_on_cooldown():
		return false
	if player_stats and not player_stats.has_mana(gauntlet.gauntlet_skill_mana_cost):
		return false
	return true

func use_gauntlet_skill(gauntlet: ItemData, target = null) -> bool:
	if not can_use_gauntlet_skill(gauntlet):
		return false
	
	# Spend mana
	if player_stats:
		player_stats.spend_mana(gauntlet.gauntlet_skill_mana_cost)
	
	# Execute skill effect
	_execute_gauntlet_skill(gauntlet, target)
	
	# Start cooldown
	gauntlet.activate_skill()
	
	print("[INVENTORY] Used skill: %s (CD: %d turns)" % [gauntlet.gauntlet_skill_name, gauntlet.gauntlet_skill_cooldown])
	return true

func _execute_gauntlet_skill(gauntlet: ItemData, target) -> void:
	match gauntlet.gauntlet_skill_effect_id:
		"power_grip":
			if target and target.has_method("take_damage"):
				target.take_damage(8, true)
				print("[SKILL] Power Grip deals 8 damage!")

		"rage_strike":
			if target and target.has_method("take_damage"):
				target.take_damage(15, true)
			if player_stats:
				player_stats.take_damage(3)
			print("[SKILL] Rage Strike deals 15 damage, costs 3 HP!")

		"worldsplitter":
			if target and target.has_method("take_damage"):
				target.take_damage(20, true)
				print("[SKILL] Worldsplitter deals 20 damage!")

		"worldsplitter_awakened":
			if target and target.has_method("take_damage"):
				target.take_damage(30, true)
			if player_stats:
				player_stats.add_armor(5)
			print("[SKILL] Worldsplitter Awakened deals 30 damage, +5 Armor!")

func get_passive_effects() -> Array[String]:
	var effects: Array[String] = []
	for gauntlet in equipped_gauntlets:
		if gauntlet and gauntlet.gauntlet_skill_type == ItemData.GauntletSkillType.PASSIVE:
			effects.append(gauntlet.gauntlet_skill_effect_id)
	return effects

func has_passive_effect(effect_id: String) -> bool:
	return effect_id in get_passive_effects()

# ============================================
# OVERFLOW EFFECTS
# ============================================

func check_overflow_effects() -> void:
	for item in equipped_chests:
		if item and item.special_effect == ItemData.SpecialEffect.OVERFLOW_HEAL_ARMOR:
			var heal_amount = item.special_effect_value

			if player_stats:
				player_stats.heal(heal_amount)
				overflow_heal_armor_triggered.emit(heal_amount, 0)
				print("[INVENTORY] Overflow effect: Healed %d" % heal_amount)

# ============================================
# UTILITY
# ============================================

func get_equipped_shield() -> ItemData:
	for weapon in equipped_weapons:
		if weapon and "Shield" in weapon.item_name:
			return weapon
	return null

func has_shield_equipped() -> bool:
	return get_equipped_shield() != null

func has_pocket_knife_equipped() -> bool:
	for weapon in equipped_weapons:
		if weapon and weapon.special_effect == ItemData.SpecialEffect.POCKET_KNIFE_PROC:
			return true
	return false

func has_only_swords_equipped() -> bool:
	## Returns true if all equipped weapons are swords (or no weapons equipped).
	var has_weapon = false
	for weapon in equipped_weapons:
		if weapon:
			has_weapon = true
			if "Sword" not in weapon.item_name and "sword" not in weapon.item_name:
				return false
	return has_weapon

func get_total_weight() -> int:
	# Every slot routes through _effective_item_weight so chest reduction, the
	# Balanced Load keystone, and two-handing all apply uniformly.
	var total = 0
	for item in equipped_helms:
		if item: total += _effective_item_weight(item)
	for item in equipped_chests:
		if item: total += _effective_item_weight(item)
	for item in equipped_rings:
		if item: total += _effective_item_weight(item)
	for item in equipped_belts:
		if item: total += _effective_item_weight(item)
	for item in equipped_boots:
		if item: total += _effective_item_weight(item)
	for item in equipped_gauntlets:
		if item: total += _effective_item_weight(item)
	for i in range(equipped_weapons.size()):
		var item = equipped_weapons[i]
		if item: total += _effective_item_weight(item, i)
	# War Rack gear rides on the back at full weight (no two-hand discount there).
	for item in rack_items:
		if item: total += _effective_item_weight(item)
	return total

## Carried weight of one item: chest reduction (Brad), the Balanced Load keystone,
## and two-handing lighten the load; the dual-wield surcharge raises it.
## All stack multiplicatively. Pass the weapon-slot index (or -1 when not
## equipped in a hand) so the hand modifiers apply to the right slot.
func _effective_item_weight(item: ItemData, weapon_slot_index: int = -1) -> int:
	var w = item.weight
	if item.item_type == ItemData.ItemType.CHEST:
		w = floori(w * (1.0 - chest_weight_reduction))
	# Balanced Load keystone: the chosen slot's items weigh 10% less.
	if player_stats and player_stats.keystone_str_light_slot \
			and item.item_type == player_stats.str_light_slot_type:
		w = floori(w * (1.0 - PlayerStats.STR_LIGHT_SLOT_REDUCTION))
	if weapon_slot_index >= 0 and weapon_slot_index == two_handed_slot:
		w = floori(w * TWO_HAND_WEIGHT_MULT)
	# Dual wielding taxes every item of the wielded pair — the big one included.
	if weapon_slot_index >= 0 and item.item_type == ItemData.ItemType.WEAPON \
			and _wielded_class_count(_is_shield(item)) >= 2:
		w = floori(w * DUAL_WIELD_WEIGHT_MULT)
	return w

func _is_shield(item: ItemData) -> bool:
	return item != null and item.weapon_subtype == ItemData.WeaponSubtype.SHIELD

## Hand items of one wielding class: weapons, or shields (dual-wielding
## shields is a legitimate stance and pays the same pair tax).
func _wielded_class_count(shields: bool) -> int:
	var count = 0
	for w in equipped_weapons:
		if w != null and w.item_type == ItemData.ItemType.WEAPON and _is_shield(w) == shields:
			count += 1
	return count

func is_dual_wielding() -> bool:
	## True while a MATCHED pair fills the hands: two weapons, or two shields.
	## Weapon-and-shield is the neutral classic and doesn't count. No toggle —
	## the state is read straight off the loadout. (A bow never shares hands
	## with another weapon, and two-handing locks its second slot, so
	## those states never count by construction.)
	return _wielded_class_count(false) >= 2 or _wielded_class_count(true) >= 2

func is_free_handing() -> bool:
	## The free-hand stance: exactly ONE hand item — weapon OR shield — with a
	## genuinely empty hand. Two-handing fills both hands, and a quiver
	## occupies a hand too, so neither qualifies.
	if two_handed_slot >= 0:
		return false
	var held = 0
	for w in equipped_weapons:
		if w != null:
			# A bow inherently fills both hands — never a free-hand stance.
			if w.weapon_subtype == ItemData.WeaponSubtype.BOW:
				return false
			held += 1
	return held == 1 and weapon_slots >= 2

## Weight change from placing item into slot_index, computed by trial
## placement (get_total_weight is side-effect free). Catches the dual-wield
## surcharge a new hand item imposes on the item ALREADY in the other hand.
func _prospective_weight_delta(item: ItemData, slot_array: Array, slot_index: int) -> int:
	var before = get_total_weight()
	slot_array[slot_index] = item
	var after = get_total_weight()
	slot_array[slot_index] = null
	return after - before

## Weighted Strikes keystone: the weight-to-damage bonus that two-handing grants,
## extended to one-handed weapons so a heavy single-hander feeds basic attacks.
## Sums every equipped weapon held in one hand (skips shields and the weapon
## already two-handed, whose heft is counted via two_hand_damage_bonus).
func get_single_hand_weight_damage_bonus() -> int:
	var total = 0
	for i in range(equipped_weapons.size()):
		var w = equipped_weapons[i]
		if w == null or w.item_type != ItemData.ItemType.WEAPON:
			continue
		if w.weapon_subtype == ItemData.WeaponSubtype.SHIELD:
			continue
		if i == two_handed_slot:
			continue
		total += floori(w.weight / TWO_HAND_WEIGHT_DAMAGE_DIVISOR)
	return total

func get_total_weapon_damage() -> int:
	var total = 0
	for i in range(equipped_weapons.size()):
		var weapon = equipped_weapons[i]
		if weapon:
			var is_off_hand = (i > 0 and i != two_handed_slot)
			if is_off_hand:
				total += floori(weapon.weapon_damage * get_off_hand_modifier())
			else:
				total += weapon.weapon_damage
	return total

func get_slot_info() -> Dictionary:
	return {
		"helm": {"max": helm_slots, "equipped": equipped_helms},
		"chest": {"max": chest_slots, "equipped": equipped_chests},
		"ring": {"max": ring_slots, "equipped": equipped_rings},
		"belt": {"max": belt_slots, "equipped": equipped_belts},
		"boots": {"max": boots_slots, "equipped": equipped_boots},
		"gauntlets": {"max": gauntlets_slots, "equipped": equipped_gauntlets},
		"weapon": {"max": weapon_slots, "equipped": equipped_weapons}
	}

# ============================================
# TWO-HANDED WIELDING
# ============================================

func is_two_handing() -> bool:
	return two_handed_slot >= 0

func get_two_handed_item() -> ItemData:
	if two_handed_slot < 0 or two_handed_slot >= equipped_weapons.size():
		return null
	return equipped_weapons[two_handed_slot]

func is_two_hand_locked_slot(slot_index: int) -> bool:
	## True for the empty hand slot consumed by two-handing.
	return two_handed_slot >= 0 and slot_index == two_handed_lock_slot

func get_two_hand_block_bonus(shield: ItemData) -> int:
	## Extra Basic Block armor when THIS shield is the item braced two-handed.
	if shield == null or get_two_handed_item() != shield:
		return 0
	return floori(shield.weight / TWO_HAND_WEIGHT_DAMAGE_DIVISOR)

func set_two_handed(slot_index: int, enabled: bool) -> bool:
	## Two-hand (or release) the weapon/shield in a hand slot.
	if enabled:
		return _enable_two_handed(slot_index)
	if two_handed_slot != slot_index:
		return false
	return _disable_two_handed()

func _enable_two_handed(slot_index: int) -> bool:
	if two_handed_slot == slot_index:
		return true
	if two_handed_slot >= 0:
		print("[INVENTORY] Already two-handing slot %d — only two hands!" % two_handed_slot)
		return false
	if slot_index < 0 or slot_index >= weapon_slots:
		return false
	var item = equipped_weapons[slot_index]
	if item == null or item.item_type != ItemData.ItemType.WEAPON:
		print("[INVENTORY] Nothing in slot %d that can be two-handed" % slot_index)
		return false
	# Bows and staffs are two-handed by NATURE, not by choice — the stance is
	# the rule itself and deliberately grants none of the two-handing bonuses.
	if is_two_hand_only(item):
		print("[INVENTORY] %s is inherently two-handed — no bonus stance to take" % item.item_name)
		return false

	# Two-handing needs a free hand: claim the lowest empty weapon slot.
	var lock = -1
	for i in range(weapon_slots):
		if i != slot_index and equipped_weapons[i] == null:
			lock = i
			break
	if lock < 0:
		print("[INVENTORY] No free hand to two-hand %s" % item.item_name)
		return false

	# Carry gate on the resulting state: item weight halves, but capacity drops.
	var weight_delta = floori(item.weight * TWO_HAND_WEIGHT_MULT) - _effective_item_weight(item, slot_index)
	if not _carry_change_allowed(weight_delta, true):
		print("[INVENTORY] Two-handing %s would leave you overburdened" % item.item_name)
		return false

	# An off-hand item held with both hands sheds the off-hand penalty:
	# strip the penalized bonuses now, re-apply at full strength below.
	if slot_index > 0:
		_apply_item_bonuses(item, false, true)

	two_handed_slot = slot_index
	two_handed_lock_slot = lock
	if player_stats:
		var dmg = 0
		if item.weapon_subtype != ItemData.WeaponSubtype.SHIELD:
			dmg = floori(item.weight / TWO_HAND_WEIGHT_DAMAGE_DIVISOR)
		player_stats.set_two_hand_state(true, dmg)

	if slot_index > 0:
		_apply_item_bonuses(item, true, false)
	else:
		_recalculate_carry_load()
		if player_stats:
			player_stats.recalculate_derived_stats()

	equipment_changed.emit()
	print("[INVENTORY] Two-handing %s (weight %d→%d, hand slot %d locked)" % [
		item.item_name, item.weight, floori(item.weight * TWO_HAND_WEIGHT_MULT), lock])
	return true

func _disable_two_handed() -> bool:
	var slot_index = two_handed_slot
	var item = equipped_weapons[slot_index] if slot_index < equipped_weapons.size() else null
	if item:
		# Carry gate on reverting: the item's full weight comes back (and the
	# freed hand may re-form a dual-wield pair, which _effective_item_weight
	# already prices in via the released slot's index).
		var weight_delta = _effective_item_weight(item, -1) - _effective_item_weight(item, slot_index)
		if not _carry_change_allowed(weight_delta, false):
			print("[INVENTORY] Too heavy to hold %s in one hand right now" % item.item_name)
			return false

	if item and slot_index > 0:
		_apply_item_bonuses(item, false, false)
	_clear_two_handed_state()
	if item and slot_index > 0:
		_apply_item_bonuses(item, true, true)
	else:
		_recalculate_carry_load()
		if player_stats:
			player_stats.recalculate_derived_stats()

	equipment_changed.emit()
	if item:
		print("[INVENTORY] Released %s to one hand" % item.item_name)
	return true

func _clear_two_handed_state() -> void:
	two_handed_slot = -1
	two_handed_lock_slot = -1
	if player_stats:
		player_stats.set_two_hand_state(false, 0)

## True if a change in carried weight / two-handing leaves the character no MORE
## overburdened than they already are. (Being overburdened can still happen
## passively — e.g. a DET berserker's capacity spike fading as they heal —
## but no deliberate action may make it worse.)
func _carry_change_allowed(load_delta: int, two_handing_after: bool) -> bool:
	if _bulk_build_switch or not player_stats:
		return true
	var load_now = get_total_weight()
	var cap_now = player_stats.get_carry_capacity()
	var load_after = load_now + load_delta
	var cap_after = player_stats.get_carry_capacity_two_handing(two_handing_after)
	if load_after <= cap_after:
		return true
	return (load_after - cap_after) <= maxi(0, load_now - cap_now)

# ============================================
# EQUIPMENT SWAP TEMPO COSTS
# ============================================

## In-combat tempo price for changing what's worn in a slot. Removing an item
## without replacing it is half price (rounded down). Out of combat swaps are
## free — main.gd only charges these while enemies are in aggro range.
func get_swap_tempo_cost(item_type: ItemData.ItemType, unequip_only: bool = false) -> int:
	var cost = 2
	match item_type:
		ItemData.ItemType.HELM, ItemData.ItemType.RING, ItemData.ItemType.WEAPON, ItemData.ItemType.QUIVER:
			cost = 2
		ItemData.ItemType.GAUNTLETS, ItemData.ItemType.BELT, ItemData.ItemType.BOOTS:
			cost = 3
		ItemData.ItemType.CHEST:
			cost = 8
	return floori(cost / 2.0) if unequip_only else cost

# ============================================
# EQUIPMENT BUILDS (loadouts I / II / III)
# ============================================

func _snapshot_equipment() -> Dictionary:
	return {
		"helms": equipped_helms.duplicate(),
		"chests": equipped_chests.duplicate(),
		"rings": equipped_rings.duplicate(),
		"belts": equipped_belts.duplicate(),
		"boots": equipped_boots.duplicate(),
		"gauntlets": equipped_gauntlets.duplicate(),
		"weapons": equipped_weapons.duplicate(),
		"two_handed_slot": two_handed_slot,
	}

## The seven live slot arrays with their snapshot keys and equip types.
## (Quiver items live in the weapon slots — there is no quiver slot.)
func _build_slot_sets() -> Array:
	return [
		["helms", equipped_helms, ItemData.ItemType.HELM],
		["chests", equipped_chests, ItemData.ItemType.CHEST],
		["rings", equipped_rings, ItemData.ItemType.RING],
		["belts", equipped_belts, ItemData.ItemType.BELT],
		["boots", equipped_boots, ItemData.ItemType.BOOTS],
		["gauntlets", equipped_gauntlets, ItemData.ItemType.GAUNTLETS],
		["weapons", equipped_weapons, ItemData.ItemType.WEAPON],
	]

func _item_available(item: ItemData) -> bool:
	## An item can be worn by a build if it's still in the backpack or equipped.
	if stored_items.has(item):
		return true
	for set_info in _build_slot_sets():
		if set_info[1].has(item):
			return true
	return false

## Switch to equipment build `target` (0-2). The current gear is snapshotted
## into the outgoing build; the target build's gear is put on. Returns
## {success, tempo_cost, reason, missing} — tempo_cost is the sum of per-slot
## swap costs for everything that actually changed (main.gd charges it only
## in combat). Items a build remembers but the player no longer owns are
## skipped and reported in `missing`.
func switch_build(target: int) -> Dictionary:
	var result = {"success": false, "tempo_cost": 0, "reason": "", "missing": []}
	if target < 0 or target >= BUILD_COUNT:
		result["reason"] = "Invalid build"
		return result

	builds[active_build] = _snapshot_equipment()
	if target == active_build:
		result["success"] = true
		return result
	if builds[target] == null:
		# First use: the new build starts as a copy of what's worn right now.
		builds[target] = _snapshot_equipment()
		active_build = target
		result["success"] = true
		equipment_changed.emit()
		print("[INVENTORY] Build %d initialized from current gear" % (target + 1))
		return result

	var snap: Dictionary = builds[target]
	var sets = _build_slot_sets()

	# --- Plan: what should end up in each slot (dropping lost items) ---
	var planned := {}
	for set_info in sets:
		var live: Array = set_info[1]
		var want: Array = snap.get(set_info[0], [])
		var plan := []
		for i in range(live.size()):
			var target_item: ItemData = want[i] if i < want.size() else null
			if target_item != null and not _item_available(target_item):
				result["missing"].append(target_item.item_name)
				target_item = null
			plan.append(target_item)
		planned[set_info[0]] = plan

	# Where does two-handing land? Only valid on a weapon that's actually coming.
	var target_two_hand: int = snap.get("two_handed_slot", -1)
	if target_two_hand >= 0:
		var pw: Array = planned["weapons"]
		var two_hand_item: ItemData = pw[target_two_hand] if target_two_hand < pw.size() else null
		if two_hand_item == null or two_hand_item.item_type != ItemData.ItemType.WEAPON:
			target_two_hand = -1

	# --- Cost + storage-space + carry validation before touching anything ---
	var cost = 0
	var removed: Array = []
	var incoming: Array = []
	var hands_changed = false
	for set_info in sets:
		var live: Array = set_info[1]
		var plan: Array = planned[set_info[0]]
		for i in range(live.size()):
			if live[i] == plan[i]:
				continue
			if set_info[0] == "weapons":
				hands_changed = true
			if plan[i] == null:
				cost += get_swap_tempo_cost(live[i].item_type, true)
			else:
				cost += get_swap_tempo_cost(plan[i].item_type, false)
			if live[i] != null:
				removed.append(live[i])
			if plan[i] != null:
				incoming.append(plan[i])
	# Changing only the two-handed slot (same items) is a hand action.
	if target_two_hand != two_handed_slot and not hands_changed:
		cost += get_swap_tempo_cost(ItemData.ItemType.WEAPON)

	if cost == 0 and target_two_hand == two_handed_slot:
		active_build = target
		result["success"] = true
		return result

	var to_storage = 0
	for it in removed:
		if not incoming.has(it):
			to_storage += 1
	var from_storage = 0
	for it in incoming:
		if stored_items.has(it):
			from_storage += 1
	if used_storage_slots() + to_storage - from_storage > max_storage_slots:
		result["reason"] = "Not enough inventory space"
		return result

	# Carry gate on the END state as a whole (per-item gates are bypassed).
	if player_stats:
		var final_load = 0
		for set_info in sets:
			var plan: Array = planned[set_info[0]]
			for i in range(plan.size()):
				if plan[i] == null:
					continue
				var w: int = plan[i].weight
				if plan[i].item_type == ItemData.ItemType.CHEST:
					w = floori(w * (1.0 - chest_weight_reduction))
				if set_info[0] == "weapons" and i == target_two_hand:
					w = floori(w * TWO_HAND_WEIGHT_MULT)
				final_load += w
		var cap_after = player_stats.get_carry_capacity_two_handing(target_two_hand >= 0)
		var over_now = maxi(0, get_total_weight() - player_stats.get_carry_capacity())
		if final_load > cap_after and (final_load - cap_after) > over_now:
			result["reason"] = "Too heavy — over carry capacity"
			return result

	# --- Execute ---
	_bulk_build_switch = true
	if two_handed_slot >= 0:
		set_two_handed(two_handed_slot, false)

	var freed: Array = []
	for set_info in sets:
		var live: Array = set_info[1]
		var plan: Array = planned[set_info[0]]
		for i in range(live.size()):
			if live[i] != plan[i] and live[i] != null:
				var it = unequip_item(set_info[2], i)
				if it:
					freed.append(it)
	for set_info in sets:
		var live: Array = set_info[1]
		var plan: Array = planned[set_info[0]]
		for i in range(live.size()):
			if live[i] != plan[i] and plan[i] != null:
				var it: ItemData = plan[i]
				if freed.has(it):
					freed.erase(it)
				else:
					var si = stored_items.find(it)
					if si >= 0:
						stored_items.remove_at(si)
				if not equip_item(it, i):
					# Refused (e.g. the bow needs-both-hands rule on an old
					# snapshot) — keep the item safe in storage, never orphaned.
					freed.append(it)
	for it in freed:
		stored_items.append(it)

	if target_two_hand >= 0:
		set_two_handed(target_two_hand, true)
	_bulk_build_switch = false

	active_build = target
	result["success"] = true
	result["tempo_cost"] = cost
	storage_changed.emit()
	equipment_changed.emit()
	print("[INVENTORY] Switched to build %d (%d tempo worth of swaps)" % [target + 1, cost])
	return result

# ============================================
# WAR RACK EXCHANGE
# ============================================

func get_rack_hand_items() -> Array:
	## Non-null items currently in the hand slots.
	var hands: Array = []
	for it in equipped_weapons:
		if it:
			hands.append(it)
	return hands

func can_rack_exchange(free: bool) -> Dictionary:
	## Whether a rack exchange is currently legal. {"ok": bool, "reason": String}
	var res = {"ok": false, "reason": ""}
	if not has_back_rack:
		res["reason"] = "No war rack"
		return res
	var hands = get_rack_hand_items()
	if hands.is_empty() and rack_items.is_empty():
		res["reason"] = "Nothing to exchange"
		return res
	# The two-hand-only rule holds for the incoming set too: a bow or staff
	# can't come down alongside gear it couldn't be equipped with (the equip
	# would be refused and strand the item). A quiver riding along is fine for
	# a bow; a staff shares with nothing, quivers included.
	if rack_items.size() > 1:
		var rack_has_staff = false
		var rack_two_hand_only = false
		var rack_non_quiver = 0
		for it in rack_items:
			if it.item_type == ItemData.ItemType.WEAPON and it.weapon_subtype == ItemData.WeaponSubtype.STAFF:
				rack_has_staff = true
			if it.item_type == ItemData.ItemType.QUIVER:
				continue
			rack_non_quiver += 1
			if is_two_hand_only(it):
				rack_two_hand_only = true
		if rack_has_staff:
			res["reason"] = "A magic staff needs both hands — it can't come down with other gear"
			return res
		if rack_two_hand_only and rack_non_quiver > 1:
			res["reason"] = "A bow needs both hands — it can't come down with other gear"
			return res
	if free:
		if rack_cooldown_tempo > 0:
			res["reason"] = "Rack swap recharging (%d tempo)" % rack_cooldown_tempo
			return res
		# One side of the free exchange must be a single two-handed item:
		# the incoming rack item (auto-two-handed on arrival), the outgoing
		# weapon already being two-handed, or a bow/staff on either side —
		# those are inherently two-handed (a quiver may ride along with a bow).
		if not _rack_free_side_ok(rack_items, true) and not _rack_free_side_ok(hands, false):
			res["reason"] = "Free swap needs a single two-handed item on one side"
			return res
	# Carry gate on the end state as a whole. The item set is unchanged (hands
	# and back trade places) but the two-handing weight discount and the 70%
	# capacity move with the exchange.
	if player_stats:
		var will_two_hand = free and _incoming_gets_auto_two_hand(rack_items)
		var load = 0
		for arr in [equipped_helms, equipped_chests, equipped_rings, equipped_belts, equipped_boots, equipped_gauntlets]:
			for it in arr:
				if it:
					load += _effective_item_weight(it)
		for i in range(rack_items.size()):  # future hands
			var w = _effective_item_weight(rack_items[i])
			if will_two_hand and i == 0:
				w = floori(rack_items[i].weight * TWO_HAND_WEIGHT_MULT)
			load += w
		for it in hands:  # future rack (full weight)
			load += _effective_item_weight(it, -1)
		var cap_after = player_stats.get_carry_capacity_two_handing(will_two_hand)
		var over_now = maxi(0, get_total_weight() - player_stats.get_carry_capacity())
		if load > cap_after and (load - cap_after) > over_now:
			res["reason"] = "Too heavy — over carry capacity"
			return res
	res["ok"] = true
	return res

func _rack_free_side_ok(items: Array, is_incoming: bool) -> bool:
	## Whether one side of a FREE rack exchange counts as "a single two-handed
	## item": exactly one non-quiver item that is a bow or staff (inherently
	## two-handed), will be auto-two-handed on arrival (lone incoming item),
	## or is already being two-handed (outgoing side).
	var main: ItemData = null
	var total = 0
	for it in items:
		if it == null:
			continue
		total += 1
		if it.item_type == ItemData.ItemType.QUIVER:
			continue
		if main != null:
			return false
		main = it
	if main == null:
		return false
	if is_two_hand_only(main):
		return true
	if is_incoming:
		return total == 1  # two-handing needs the other hand free to lock
	return two_handed_slot >= 0

func _incoming_gets_auto_two_hand(items: Array) -> bool:
	## The free swap auto-two-hands a lone incoming item — but not bows or
	## staffs (their two-handedness is the rule itself, and the lock would
	## claim the hand a bow's quiver needs) and not quivers.
	if items.size() != 1 or items[0] == null:
		return false
	var it: ItemData = items[0]
	if it.item_type != ItemData.ItemType.WEAPON:
		return false
	return not is_two_hand_only(it)

func rack_exchange(free: bool) -> Dictionary:
	## Swaps everything in the hand slots with everything on the rack.
	## free=true: 0 tempo, starts the cooldown, auto-two-hands a single
	## incoming item, and rushes the incoming items' cards to hand.
	## free=false: normal swap-tempo cost per changed hand slot, no cooldown.
	var result = {"success": false, "tempo_cost": 0, "reason": ""}
	var check = can_rack_exchange(free)
	if not check["ok"]:
		result["reason"] = check["reason"]
		return result

	var incoming: Array = rack_items.duplicate()
	var outgoing: Array = []

	_bulk_build_switch = true
	if two_handed_slot >= 0:
		set_two_handed(two_handed_slot, false)
	for i in range(weapon_slots):
		if equipped_weapons[i] != null:
			var it = unequip_item(ItemData.ItemType.WEAPON, i)
			if it:
				outgoing.append(it)
	var next_slot = 0
	var first_slot = -1
	for it in incoming:
		while next_slot < weapon_slots and equipped_weapons[next_slot] != null:
			next_slot += 1
		if next_slot >= weapon_slots:
			break
		equip_item(it, next_slot)
		if first_slot < 0:
			first_slot = next_slot
	# The free swap's single incoming item arrives held with both hands (bows
	# and staffs excepted — they are inherently two-handed already).
	if free and first_slot >= 0 and _incoming_gets_auto_two_hand(incoming):
		set_two_handed(first_slot, true)
	_bulk_build_switch = false

	rack_items = outgoing
	# The rack contents just changed hands — recompute the live carry load
	# (and stance flags) NOW, not on the next unrelated equip.
	_recalculate_carry_load()

	if free:
		rack_cooldown_tempo = RACK_FREE_SWAP_COOLDOWN
		for it in incoming:
			_rush_item_cards_to_hand(it)
		print("[INVENTORY] War Rack FREE exchange: %s down, %s up (cooldown %d tempo)" % [
			_rack_names(incoming), _rack_names(outgoing), RACK_FREE_SWAP_COOLDOWN])
	else:
		var changed = maxi(incoming.size(), outgoing.size())
		result["tempo_cost"] = changed * get_swap_tempo_cost(ItemData.ItemType.WEAPON)
		print("[INVENTORY] War Rack exchange: %s down, %s up (%d tempo)" % [
			_rack_names(incoming), _rack_names(outgoing), result["tempo_cost"]])

	rack_changed.emit()
	equipment_changed.emit()
	result["success"] = true
	return result

func _rack_names(items: Array) -> String:
	if items.is_empty():
		return "(nothing)"
	var names: Array[String] = []
	for it in items:
		names.append(it.item_name)
	return ", ".join(names)

func _rush_item_cards_to_hand(item: ItemData) -> void:
	## Free-swap payoff: the incoming item's cards (just added to the discard
	## pile by equip_item) go straight to hand, up to hand size. Extras land on
	## top of the draw pile. Jailed cards stay jailed — the rack launders nothing.
	if not deck_manager or not player_stats:
		return
	var moved = false
	for card in _get_item_owned_cards(item):
		if _is_locked_mastery_card(item, card):
			continue
		var di = deck_manager.discard_pile.find(card)
		if di < 0:
			continue
		deck_manager.discard_pile.remove_at(di)
		if deck_manager.hand.size() < player_stats.hand_size:
			deck_manager.hand.append(card)
			print("[INVENTORY] War Rack: %s rushed to hand" % card.card_name)
		else:
			deck_manager.draw_pile.append(card)  # top of the draw pile (drawn next)
			print("[INVENTORY] War Rack: hand full — %s waits on top of the draw pile" % card.card_name)
		moved = true
	if moved:
		deck_manager.hand_updated.emit()

func rack_store_item(item: ItemData) -> bool:
	## Out-of-combat setup path: strap an unequipped item onto the rack directly.
	if not has_back_rack or rack_items.size() >= weapon_slots:
		return false
	rack_items.append(item)
	rack_changed.emit()
	print("[INVENTORY] Strapped %s to the war rack" % item.item_name)
	return true

func rack_take_item(index: int) -> ItemData:
	## Remove an item from the rack (to storage/hands via normal flows).
	if index < 0 or index >= rack_items.size():
		return null
	var item = rack_items[index]
	rack_items.remove_at(index)
	rack_changed.emit()
	return item

# ============================================
# ITEM STORAGE (NON-EQUIPPED INVENTORY)
# ============================================

func store_item(item: ItemData) -> bool:
	if is_storage_full():
		print("[INVENTORY] Storage full! (%d/%d)" % [used_storage_slots(), max_storage_slots])
		return false
	stored_items.append(item)
	storage_changed.emit()
	print("[INVENTORY] Stored %s (%d/%d)" % [item.item_name, used_storage_slots(), max_storage_slots])
	return true

func remove_stored_item(index: int) -> ItemData:
	if index < 0 or index >= stored_items.size():
		return null
	var item = stored_items[index]
	stored_items.remove_at(index)
	storage_changed.emit()
	print("[INVENTORY] Removed %s from storage (%d/%d)" % [item.item_name, stored_items.size(), max_storage_slots])
	return item

func get_stored_item(index: int) -> ItemData:
	if index < 0 or index >= stored_items.size():
		return null
	return stored_items[index]

func get_stored_item_count() -> int:
	return stored_items.size()

func used_storage_slots() -> int:
	## Items and looted cards share the one slot pool.
	return stored_items.size() + stored_cards.size()

func is_storage_full() -> bool:
	return used_storage_slots() >= max_storage_slots

# ============================================
# STASH STORAGE
# ============================================

func stash_item(item: ItemData) -> bool:
	if stash_items.size() >= max_stash_slots:
		print("[INVENTORY] Stash full! (%d/%d)" % [stash_items.size(), max_stash_slots])
		return false
	stash_items.append(item)
	storage_changed.emit()
	print("[INVENTORY] Stashed %s (%d/%d)" % [item.item_name, stash_items.size(), max_stash_slots])
	return true

func remove_stash_item(index: int) -> ItemData:
	if index < 0 or index >= stash_items.size():
		return null
	var item = stash_items[index]
	stash_items.remove_at(index)
	storage_changed.emit()
	print("[INVENTORY] Removed %s from stash (%d/%d)" % [item.item_name, stash_items.size(), max_stash_slots])
	return item

func get_stash_item(index: int) -> ItemData:
	if index < 0 or index >= stash_items.size():
		return null
	return stash_items[index]

func get_stash_item_count() -> int:
	return stash_items.size()

func is_stash_full() -> bool:
	return stash_items.size() >= max_stash_slots

func move_inventory_to_stash(storage_index: int) -> bool:
	## Move an item from player inventory (stored_items) to stash. Returns false if stash is full.
	if is_stash_full():
		return false
	var item = remove_stored_item(storage_index)
	if item == null:
		return false
	stash_items.append(item)
	storage_changed.emit()
	print("[INVENTORY] Moved %s from inventory to stash" % item.item_name)
	return true

func move_stash_to_inventory(stash_index: int) -> bool:
	## Move an item from stash to player inventory (stored_items). Returns false if inventory is full.
	if is_storage_full():
		return false
	var item = remove_stash_item(stash_index)
	if item == null:
		return false
	stored_items.append(item)
	storage_changed.emit()
	print("[INVENTORY] Moved %s from stash to inventory" % item.item_name)
	return true

func destroy_stored_item(index: int) -> bool:
	## Permanently deletes an item from storage (player chose to drop it).
	## The Return Scroll is indestructible — it would just come back anyway.
	if index < 0 or index >= stored_items.size():
		return false
	var item = stored_items[index]
	if item and item.special_id != "":
		return false
	stored_items.remove_at(index)
	storage_changed.emit()
	print("[INVENTORY] Destroyed stored item: %s" % (item.item_name if item else "(empty)"))
	return true

func ensure_return_scroll() -> void:
	## Every adventurer carries exactly one Return Scroll. Called after any
	## inventory restore so old saves (and fresh characters) always have it.
	for item in stored_items:
		if item and item.special_id == "return_scroll":
			return
	stored_items.append(ItemData.create_return_scroll())
	storage_changed.emit()
	print("[INVENTORY] Return Scroll added to storage")

func equip_from_storage(storage_index: int, slot_index: int) -> bool:
	var item = get_stored_item(storage_index)
	if item == null:
		return false
	if item.special_id != "":
		return false  # utility items (Return Scroll) never equip
	var slot_array = _get_slot_array(item.item_type)
	var max_slots = _get_max_slots(item.item_type)
	if slot_index < 0 or slot_index >= max_slots:
		return false
	if slot_array[slot_index] != null:
		# Swap: unequip current item into the storage slot, then equip the new
		# one. equip_item can refuse (carry gate) — undo instead of losing gear.
		var old_item = unequip_item(item.item_type, slot_index)
		if not equip_item(item, slot_index):
			if old_item and not equip_item(old_item, slot_index):
				stored_items.append(old_item)  # last resort: never drop an item
				storage_changed.emit()
			return false
		if old_item:
			stored_items[storage_index] = old_item
		else:
			stored_items.remove_at(storage_index)
		storage_changed.emit()
	else:
		if not equip_item(item, slot_index):
			return false
		remove_stored_item(storage_index)
	return true

func unequip_to_storage(item_type: ItemData.ItemType, slot_index: int) -> bool:
	if is_storage_full():
		print("[INVENTORY] Cannot unequip - storage full!")
		return false
	var item = unequip_item(item_type, slot_index)
	if item == null:
		return false
	store_item(item)
	return true

# ============================================
# STORED CARDS (share the inventory slot pool)
# ============================================

func store_card(card) -> bool:
	if is_storage_full():
		print("[INVENTORY] Storage full! (%d/%d)" % [used_storage_slots(), max_storage_slots])
		return false
	stored_cards.append(card)
	storage_changed.emit()
	print("[INVENTORY] Stored card: %s (%d/%d)" % [card.card_name, used_storage_slots(), max_storage_slots])
	return true

func remove_stored_card(index: int):
	if index < 0 or index >= stored_cards.size():
		return null
	var card = stored_cards[index]
	stored_cards.remove_at(index)
	storage_changed.emit()
	print("[INVENTORY] Removed card from storage: %s (%d/%d)" % [card.card_name, used_storage_slots(), max_storage_slots])
	return card

func get_stored_card(index: int):
	if index < 0 or index >= stored_cards.size():
		return null
	return stored_cards[index]

func get_stored_card_count() -> int:
	return stored_cards.size()

func add_card_to_deck(card_index: int, dm) -> bool:
	## Moves a card from inventory to the player's discard pile.
	var card = remove_stored_card(card_index)
	if card == null:
		return false
	if dm:
		dm.discard_pile.append(card)
		print("[INVENTORY] Card '%s' added to discard pile from inventory" % card.card_name)
		return true
	# If no deck manager, put card back
	stored_cards.insert(card_index, card)
	return false

# ============================================
# CULLING STONES (CONSUMABLE)
# ============================================

func get_culling_stone_count() -> int:
	return culling_stones

func use_culling_stone() -> bool:
	if culling_stones <= 0:
		print("[INVENTORY] No culling stones remaining!")
		return false
	culling_stones -= 1
	print("[INVENTORY] Used culling stone (%d remaining)" % culling_stones)
	return true

# ============================================
# PAPER FEATHERS & ORIGAMI SWANS
# ============================================

func get_paper_feather_count() -> int:
	return paper_feathers

func use_paper_feather() -> bool:
	if paper_feathers <= 0:
		print("[INVENTORY] No Paper Feathers remaining!")
		return false
	paper_feathers -= 1
	print("[INVENTORY] Used Paper Feather (%d remaining)" % paper_feathers)
	return true

func add_paper_feather(amount: int = 1) -> void:
	paper_feathers += amount
	print("[INVENTORY] Gained %d Paper Feather(s) (%d total)" % [amount, paper_feathers])

func get_origami_swan_count() -> int:
	return origami_swans

func add_origami_swans(amount: int) -> void:
	origami_swans += amount
	print("[INVENTORY] Gained %d Origami Swan(s) (%d total)" % [amount, origami_swans])
	# Auto-convert: 20 swans = 1 Paper Feather
	while origami_swans >= 20:
		origami_swans -= 20
		paper_feathers += 1
		print("[INVENTORY] Converted 20 Origami Swans into 1 Paper Feather! (%d feathers, %d swans remaining)" % [paper_feathers, origami_swans])

# ============================================
# MYTHIC MOLDS
# ============================================

func get_mythic_mold_count() -> int:
	return mythic_molds

func add_mythic_mold(amount: int = 1) -> void:
	mythic_molds += amount
	print("[INVENTORY] Gained %d Mythic Mold(s) (%d total)" % [amount, mythic_molds])

func use_mythic_mold() -> bool:
	if mythic_molds <= 0:
		print("[INVENTORY] No Mythic Molds remaining!")
		return false
	mythic_molds -= 1
	print("[INVENTORY] Used Mythic Mold (%d remaining)" % mythic_molds)
	return true

func destroy_cards_for_swans(card_count: int) -> int:
	## Destroys cards and returns the number of origami swans created (1 per card).
	## The actual card removal is handled by the caller.
	var swans_created = card_count
	add_origami_swans(swans_created)
	print("[INVENTORY] Destroyed %d cards → %d Origami Swans" % [card_count, swans_created])
	return swans_created

# ============================================
# CARD ENCHANT / EXTRACT SYSTEM
# ============================================

func enchant_card(card: Card, item: ItemData) -> bool:
	## Puts a card into an item's card slot (Enchant).
	## Validates Picky/Pliable compatibility and slot availability.
	## The card remains in the deck and can still be played normally.
	if not item.has_card_slots():
		print("[INVENTORY] %s has no card slots!" % item.item_name)
		return false

	if not item.can_slot_card(card):
		if item.get_free_card_slots() <= 0:
			print("[INVENTORY] %s has no free card slots! (%d/%d)" % [item.item_name, item.slotted_cards.size(), item.card_slots])
		else:
			print("[INVENTORY] Card '%s' is Picky and cannot be slotted into %s (requires %s)" % [card.card_name, item.get_type_name(), ItemData.ItemType.keys()[card.source_item_type] if card.source_item_type >= 0 else "any"])
		return false

	# Slot the card into the item (card stays in the deck)
	item.slot_card(card)

	card_enchanted.emit(card, item)
	equipment_changed.emit()
	print("[INVENTORY] Enchanted '%s' into %s" % [card.card_name, item.item_name])
	return true

func extract_card(item: ItemData, card_index: int, _destroy_item: bool = false) -> Card:
	## Extracts a card from an item (Extract).
	## Removes the card from the item's slot. Card remains in the deck as before.
	## Returns the extracted card, or null if card is Molded (cannot be extracted).
	if card_index < 0 or card_index >= item.slotted_cards.size():
		print("[INVENTORY] Invalid card slot index %d for %s" % [card_index, item.item_name])
		return null

	var card = item.slotted_cards[card_index]
	if card.is_molded:
		print("[INVENTORY] Cannot extract '%s' from %s - card is Molded!" % [card.card_name, item.item_name])
		return null

	# Track source item type for Picky re-enchanting
	if card.source_item_type < 0:
		card.source_item_type = item.item_type
	card.slotted_in_item = null
	item.slotted_cards.remove_at(card_index)

	card_extracted.emit(card, item, false)
	equipment_changed.emit()
	print("[INVENTORY] Extracted '%s' from %s" % [card.card_name, item.item_name])
	return card

func _destroy_equipped_item(item: ItemData) -> void:
	## Finds and removes an equipped item from all slot arrays, reversing its bonuses.
	var all_slots = [
		[equipped_helms, ItemData.ItemType.HELM],
		[equipped_chests, ItemData.ItemType.CHEST],
		[equipped_rings, ItemData.ItemType.RING],
		[equipped_belts, ItemData.ItemType.BELT],
		[equipped_boots, ItemData.ItemType.BOOTS],
		[equipped_gauntlets, ItemData.ItemType.GAUNTLETS],
		[equipped_weapons, ItemData.ItemType.WEAPON]
	]

	for slot_info in all_slots:
		var slot_array = slot_info[0]
		for i in range(slot_array.size()):
			if slot_array[i] == item:
				unequip_item(slot_info[1], i)
				print("[INVENTORY] Destroyed item: %s" % item.item_name)
				return

	# Check storage too
	for i in range(stored_items.size()):
		if stored_items[i] == item:
			stored_items.remove_at(i)
			storage_changed.emit()
			print("[INVENTORY] Destroyed stored item: %s" % item.item_name)
			return

func get_all_items_with_card_slots() -> Array[ItemData]:
	## Returns all equipped items that have card slots.
	var result: Array[ItemData] = []
	var all_arrays = [equipped_helms, equipped_chests, equipped_rings, equipped_belts, equipped_boots, equipped_gauntlets, equipped_weapons]
	for slot_array in all_arrays:
		for item in slot_array:
			if item and item.has_card_slots():
				result.append(item)
	return result

func get_all_slotted_cards() -> Array:
	## Returns all cards currently slotted in any equipped item.
	var result: Array = []
	var all_arrays = [equipped_helms, equipped_chests, equipped_rings, equipped_belts, equipped_boots, equipped_gauntlets, equipped_weapons]
	for slot_array in all_arrays:
		for item in slot_array:
			if item:
				for card in item.slotted_cards:
					result.append(card)
	return result
