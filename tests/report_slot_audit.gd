extends SceneTree

## Item slot audit: which card slots can no card use, and which on-self
## riders no eligible card can ever trigger. For every item with a slot it
## lists the cards its label (or allow-list) admits, then checks each active
## rider against the kind of card it wants (from the rider's definition:
## offensive, ranged offensive, melee offensive, attack, defense, utility,
## reaction, heal, self-target, any). Writes docs/ITEM_SLOT_AUDIT.md.
## Run: godot --headless --path . --script tests/report_slot_audit.gd

const OUT := "res://docs/ITEM_SLOT_AUDIT.md"

## rider field -> the card it fires on
const RIDER_WANTS := {
	"on_self_damage": "offensive", "on_self_offensive_damage": "offensive", "on_self_apply_burn": "offensive",
	"on_self_apply_cold": "offensive", "on_self_apply_bleed": "offensive", "on_self_apply_shock": "offensive",
	"on_self_apply_weaken": "offensive", "on_self_apply_vulnerable": "offensive", "on_self_armor_shred": "offensive",
	"on_self_range_offensive": "offensive", "on_self_taunt_cycles": "offensive", "on_self_root_offensive": "offensive",
	"on_self_disarm_offensive": "offensive", "on_self_offensive_shift": "offensive", "on_self_offensive_heal_percent": "offensive",
	"on_self_overdrive_multiplier": "offensive", "on_self_damage_multiplier": "offensive", "on_self_weakened_damage_percent": "offensive",
	"on_self_max_hp_damage_percent": "offensive", "on_self_double_shot": "offensive", "on_self_bounce_percent": "offensive",
	"on_self_knockback": "offensive", "on_self_kill_summon_skeleton": "offensive", "on_self_crit_bud_bow": "offensive",
	"on_self_slow_damage_per_stack": "offensive", "on_self_int_damage_percent": "offensive", "on_self_adaptive_damage_type": "offensive",
	"on_self_damage_while_invisible": "offensive", "on_self_lifesteal_percent": "offensive", "on_self_crit_damage_percent": "offensive",
	"on_self_crit_percent": "offensive", "on_self_target_aoe_damage": "offensive",
	"on_self_ranged_damage": "ranged offensive", "on_self_ranged_tempo_reduction": "ranged offensive",
	"on_self_crit_ranged_percent": "ranged offensive",
	"on_self_melee_damage": "melee offensive",
	"on_self_attack_tempo_reduction": "attack", "on_self_apply_slow": "attack",
	"on_self_block": "any", "on_self_defense_armor": "defense", "on_self_block_max_mana_percent": "any",
	"on_self_utility_heal": "utility", "on_self_utility_spell_damage": "utility", "on_self_utility_weaken": "utility",
	"on_self_utility_tempo_refund": "utility", "on_self_support_heal": "utility or defense",
	"on_self_reaction_armor": "reaction", "on_self_instant_damage_nearest": "reaction",
	"on_self_heal": "any", "on_self_self_heal": "any", "on_self_self_targets_allies": "self-target", "on_self_cleanse_stacks": "targeted",
	"on_self_mana_reduction": "any", "on_self_mana_reduction_percent": "any", "on_self_brain_regen": "any",
	"on_self_armor_any": "any", "on_self_flash_regen": "any", "on_self_armor_per_missing_health10": "any",
	"on_self_invisible_tempo": "any", "on_self_flash_counter_drain": "any", "on_self_physical_resilient": "any",
	"on_self_strengthen_value": "any", "on_self_mana_multiplier": "any", "on_self_draw_card": "any",
	"on_self_summon_wolf": "any", "on_self_fortify": "any", "on_self_discard": "any", "on_self_chance_boost": "any",
	"on_self_resist_all_percent": "any", "on_self_tempo_penalty": "any", "on_self_jail_tempo": "any",
	"on_self_mana_to_life": "any", "on_self_conjure_on_play_id": "any", "on_self_thorns": "any",
}
## riders that are only a parameter of another rider (never alone)
const RIDER_PARAMS := ["on_self_range_requires_ranged", "on_self_strengthen_attacks", "on_self_missing_health_step", "on_self_resist_all_tempo"]

var _blank: ItemData

func _wants(card: Card, kind: String) -> bool:
	match kind:
		"offensive": return card.is_offensive()
		"ranged offensive": return card.is_offensive() and card.is_ranged
		"melee offensive": return card.is_offensive() and not card.is_ranged
		"attack": return card.is_attack()
		"defense": return card.card_type == Card.CardType.DEFENSE or card.base_block > 0
		"utility": return card.card_type == Card.CardType.UTILITY
		"utility or defense": return card.card_type == Card.CardType.UTILITY or card.card_type == Card.CardType.DEFENSE
		"reaction": return card.card_type == Card.CardType.REACTION or card.reaction_trigger != ""
		"heal": return card.heal_amount > 0
		"self-target": return card.target_types.has("self")
		"targeted": return card.target_types.has("enemy") or card.target_types.has("ally")
	return true

## The item's label gate alone (no capacity, no colour): what can_slot_card
## would say of an empty, uncoloured copy of the item.
func _label_ok(item: ItemData, card: Card) -> bool:
	if not card.is_slottable():
		return false
	if item.allowed_card_keywords.size() > 0:
		for kw in card.slot_labels:
			if kw in item.allowed_card_keywords:
				return true
		return false
	var required: int = item._get_default_keyword_for_item_type()
	return required < 0 or card.has_slot_label(required)

func _active(item: ItemData, field: String) -> bool:
	var v = item.get(field)
	var d = _blank.get(field)
	return v != d

func _initialize() -> void:
	_blank = ItemData.new()
	# Every on_self_* export must be mapped, or the audit silently skips it.
	var unmapped: Array[String] = []
	for prop in _blank.get_property_list():
		var pn: String = str(prop["name"])
		if pn.begins_with("on_self_") and not RIDER_WANTS.has(pn) and not RIDER_PARAMS.has(pn):
			unmapped.append(pn)
	if not unmapped.is_empty():
		push_error("report_slot_audit: unmapped riders: %s" % ", ".join(unmapped))
		print("UNMAPPED RIDERS: " + ", ".join(unmapped))
	var cards: Array[Card] = Card.get_all_cards(false)
	var lines: Array[String] = []
	lines.append("# Item slot audit")
	lines.append("")
	lines.append("Generated by `tests/report_slot_audit.gd` (%s). For every item with a card slot: the cards its label admits, and whether each on-self rider has any eligible card that can trigger it. A rider's card kind comes from its definition in `item_data.gd` (offensive, ranged offensive, melee offensive, attack, defense, utility, reaction, heal, self-target, any). Feral Evocation's coloured slots are checked by label only." % Time.get_date_string_from_system())
	lines.append("")
	var dead_slots: Array[String] = []
	var dead_riders: Array[String] = []
	var thin: Array[String] = []
	var rows: Array[String] = []
	var ids: Array = ItemData.ITEM_IDS.duplicate()
	ids.sort()
	for id in ids:
		var item = ItemData.create(id)
		if not (item is ItemData) or item.total_card_slots() <= 0:
			continue
		var fits: Array[Card] = []
		for c in cards:
			if _label_ok(item, c):
				fits.append(c)
		var by_r := {}
		for c in fits:
			var r: String = Card.Rarity.keys()[Card.CARD_RARITIES.get(c.card_id, Card.Rarity.COMMON)].capitalize()
			by_r[r] = int(by_r.get(r, 0)) + 1
		var label: String = ""
		if item.allowed_card_keywords.size() > 0:
			var ns: Array[String] = []
			for kw in item.allowed_card_keywords:
				ns.append(Card.keyword_name(kw))
			label = "/".join(ns)
		else:
			var req: int = item._get_default_keyword_for_item_type()
			label = Card.keyword_name(req) if req >= 0 else "any label"
		var riders: Array[String] = []
		var all_dead := true
		var n_riders := 0
		var fields: Array = RIDER_WANTS.keys()
		if item.attack_debuffs_on_self_only:
			# Car Battery: the attack_apply_* debuffs ride only its own slotted cards.
			for f in ["attack_apply_shock", "attack_apply_burn", "attack_apply_cold", "attack_apply_silence", "attack_apply_vulnerable"]:
				if _active(item, f):
					fields.append(f)
		for field in fields:
			if not _active(item, field):
				continue
			var kind_of: String = RIDER_WANTS.get(field, "offensive")
			n_riders += 1
			var kind: String = kind_of
			var n := 0
			for c in fits:
				if _wants(c, kind):
					n += 1
			var short: String = field.trim_prefix("on_self_").trim_prefix("attack_")
			if n == 0:
				riders.append("**%s wants %s: 0 cards — DEAD**" % [short, kind])
				dead_riders.append("%s (%s): %s wants a %s card, none fits the %s slot" % [item.item_name, id, short, kind, label])
			else:
				riders.append("%s wants %s: %d" % [short, kind, n])
				all_dead = false
		if fits.is_empty():
			dead_slots.append("%s (%s): %d slot(s), label %s, no card carries it" % [item.item_name, id, item.total_card_slots(), label])
		elif fits.size() <= 2:
			thin.append("%s (%s): only %d card(s) fit the %s slot" % [item.item_name, id, fits.size(), label])
		if n_riders > 0 and all_dead and item.card_slots > 0:
			dead_riders.append("%s (%s): every rider is dead, so its %d bonus slot(s) are plain slots in practice" % [item.item_name, id, item.card_slots])
		var rl: Array[String] = []
		for r in ["Common", "Rare", "Legendary", "Mythic"]:
			if by_r.has(r):
				rl.append("%s %d" % [r, by_r[r]])
		rows.append("| %s | %s | %d + %d | %s | %d (%s) | %s |" % [item.item_name, ItemData.ItemType.keys()[item.item_type].capitalize()
			+ (" / " + ItemData.get_weapon_subtype_name(item.weapon_subtype) if item.item_type == ItemData.ItemType.WEAPON else ""),
			item.card_slots, item.vanilla_slots, label, fits.size(), "; ".join(rl), "<br>".join(riders) if not riders.is_empty() else "—"])
	lines.append("## Slots no card can use (%d)" % dead_slots.size())
	lines.append("")
	for d in dead_slots:
		lines.append("- " + d)
	if dead_slots.is_empty():
		lines.append("- none")
	lines.append("")
	lines.append("## Riders no eligible card can trigger (%d)" % dead_riders.size())
	lines.append("")
	for d in dead_riders:
		lines.append("- " + d)
	if dead_riders.is_empty():
		lines.append("- none")
	lines.append("")
	lines.append("## Thin slots: two cards or fewer fit (%d)" % thin.size())
	lines.append("")
	for d in thin:
		lines.append("- " + d)
	if thin.is_empty():
		lines.append("- none")
	lines.append("")
	lines.append("## Every slotted item")
	lines.append("")
	lines.append("| item | type | bonus + plain | label | cards that fit | riders (eligible cards each) |")
	lines.append("|---|---|---|---|---|---|")
	lines.append_array(rows)
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("wrote %s: %d items, %d dead slots, %d dead riders, %d thin" % [OUT, rows.size(), dead_slots.size(), dead_riders.size(), thin.size()])
	for d in dead_slots:
		print("  DEAD SLOT: " + d)
	for d in dead_riders:
		print("  DEAD RIDER: " + d)
	quit(0)
