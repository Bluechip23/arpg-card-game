class_name ProgressionTriggers
extends Node

## Handles all sphere grid node unlocks, skill tree passive triggers,
## and constellation/sphere passive effects.
## Extracted from main.gd to reduce god-object complexity.

var main  # Reference to the Main scene node

func init(main_ref) -> void:
	main = main_ref

func _on_sphere_grid_node_unlocked(node_id: int) -> void:
	## Called when the player unlocks a node on the sphere grid.
	## Applies the node's effect to the character immediately.
	var grid = main.sphere_grid_ui.sphere_grid
	var node = grid.get_node_by_id(node_id)
	if not node:
		return
	_apply_sphere_grid_node(node)

func _apply_sphere_grid_node(node) -> void:
	## Applies a single sphere grid node's effect to the character.
	var stats = main.player.get_stats()
	if not stats:
		return

	match node.node_type:
		SphereGrid.NodeType.NULL_NODE:
			pass  # Connective tissue: the path itself is the purchase.

		SphereGrid.NodeType.KEYSTONE:
			match node.keystone_id:
				"det_vitality":
					stats.keystone_det_vitality = true
					stats.refresh_det_vitality()
					main.add_battle_log("Keystone: Bulwark Soul — +2 max HP per DET", Color(1.0, 0.85, 0.4))
				"flash_draw":
					stats.keystone_flash_draw = true
					main._update_flash_button()
					main.add_battle_log("Keystone: Flash Reserves — flash points can draw cards", Color(1.0, 0.85, 0.4))
				"dex_ranged":
					stats.keystone_dex_ranged = true
					main.add_battle_log("Keystone: Deadeye Form — ranged damage scales with DEX", Color(1.0, 0.85, 0.4))
				"det_floor":
					stats.keystone_det_floor = true
					stats.recalculate_derived_stats()
					main.add_battle_log("Keystone: Unbroken Will — low health can't drop your stats below half", Color(1.0, 0.85, 0.4))
				"det_amplify":
					stats.keystone_det_amplify = true
					stats.recalculate_derived_stats()
					main.add_battle_log("Keystone: Wild Abandon — Determination's swings are amplified", Color(1.0, 0.85, 0.4))
				"dex_twin_strike":
					stats.keystone_dex_twin_strike = true
					main.add_battle_log("Keystone: Flurry Form — Dexterity procs strike twice, attacks hit lighter", Color(1.0, 0.85, 0.4))
				"dex_flat_damage":
					stats.keystone_dex_flat_damage = true
					main.add_battle_log("Keystone: Killing Rhythm — Dexterity procs become bonus attack damage", Color(1.0, 0.85, 0.4))
				"flash_strike":
					stats.keystone_flash_strike = true
					main._update_flash_button()
					main.add_battle_log("Keystone: Flash Cut — Sidestep now strikes instead of blocks", Color(1.0, 0.85, 0.4))
				"str_weight_basic":
					stats.keystone_str_weight_basic = true
					main.add_battle_log("Keystone: Weighted Strikes — one-handed weapon heft feeds basic attacks", Color(1.0, 0.85, 0.4))
				"str_light_slot":
					stats.keystone_str_light_slot = true
					if stats.str_light_slot_type < 0:
						stats.set_str_light_slot(ItemData.ItemType.CHEST)
					main.add_battle_log("Keystone: Balanced Load — a chosen slot weighs 10% less", Color(1.0, 0.85, 0.4))
				"wis_empty_draw":
					stats.keystone_wis_empty_draw = true
					main.add_battle_log("Keystone: Quick Study — auto-draw a card when your hand empties", Color(1.0, 0.85, 0.4))
				"wis_hand_crit":
					stats.keystone_wis_hand_crit = true
					main.add_battle_log("Keystone: Tactician's Eye — crit chance rises with cards in hand", Color(1.0, 0.85, 0.4))
				"int_regen_armor":
					stats.keystone_int_regen_armor = true
					main.add_battle_log("Keystone: Arcane Ward — mana regen grants armor equal to half your INT", Color(1.0, 0.85, 0.4))
				"int_spell_proc":
					stats.keystone_int_spell_proc = true
					main.add_battle_log("Keystone: Arcane Echo — spells may echo bonus damage to a random enemy", Color(1.0, 0.85, 0.4))
				"lifesteal_temp_hp":
					stats.keystone_lifesteal_temp_hp = true
					main.add_battle_log("Keystone: Sanguine Barrier — life steal grants temp HP instead of healing", Color(1.0, 0.85, 0.4))
				"armor_temp_hp":
					stats.keystone_armor_temp_hp = true
					main.add_battle_log("Keystone: Living Bulwark — armor gains become temp HP", Color(1.0, 0.85, 0.4))
				"mana_blood":
					stats.keystone_mana_blood = true
					main.add_battle_log("Keystone: Arcane Blood — damage is shared between health and mana", Color(1.0, 0.85, 0.4))
				"det_mana":
					stats.keystone_det_mana = true
					stats.recalculate_derived_stats()
					main.add_battle_log("Keystone: Willspring — Determination now swings with your mana, not your health", Color(1.0, 0.85, 0.4))
				_:
					print("[SPHERE] Unknown keystone id: %s" % node.keystone_id)

		SphereGrid.NodeType.STAT_BONUS:
			var parsed = _parse_stat_label(node.label)
			if parsed.size() > 0:
				stats.apply_sphere_grid_stat(parsed["stat"], parsed["value"])
				main.add_battle_log("Sphere Grid: %s" % node.label, Color(0.4, 0.6, 1.0))

		SphereGrid.NodeType.HEALTH:
			var amount = _parse_numeric_value(node.label)
			if amount > 0:
				stats.apply_sphere_grid_health(amount)
				main.add_battle_log("Sphere Grid: Max HP +%d" % amount, Color(0.9, 0.2, 0.2))

		SphereGrid.NodeType.MANA:
			var amount = _parse_numeric_value(node.label)
			if amount > 0:
				stats.apply_sphere_grid_mana(amount)
				main.add_battle_log("Sphere Grid: Max Mana +%d" % amount, Color(0.2, 0.5, 1.0))

		SphereGrid.NodeType.FREE_STAT:
			# Banks freely-allocatable stat points, exactly like a level-up. The
			# player spends them on the stat screen. Amount is read from the label
			# ("+4 Stats"), defaulting to 4.
			var amount = _parse_numeric_value(node.label)
			if amount <= 0:
				amount = 4
			stats.grant_stat_points(amount)
			main.add_battle_log("Sphere Grid: +%d stat points to allocate" % amount, Color(0.75, 0.6, 1.0))
			if main.has_method("_refresh_hud_notifications"):
				main._refresh_hud_notifications()

		SphereGrid.NodeType.COMBAT_BONUS:
			stats.apply_sphere_grid_combat_bonus(node.label, node.description)
			main.add_battle_log("Sphere Grid: %s" % node.label, Color(0.9, 0.7, 0.2))

		SphereGrid.NodeType.PASSIVE:
			var passive = _parse_passive_description(node.description, node.id)
			if passive.size() > 0:
				stats.add_sphere_grid_passive(passive)
				main.add_battle_log("Sphere Grid: %s" % node.description, Color(0.9, 0.5, 0.2))

		SphereGrid.NodeType.CULLING_STONE:
			var inventory = main.player.get_inventory()
			if inventory:
				inventory.culling_stones += 1
				main.add_battle_log("Sphere Grid: Obtained Culling Stone!", Color(0.8, 0.5, 1.0))

		SphereGrid.NodeType.FEATHER:
			var inventory = main.player.get_inventory()
			if inventory:
				inventory.paper_feathers += 1
				main.add_battle_log("Sphere Grid: Obtained Paper Feather!", Color(0.95, 0.85, 0.5))

	print("[MAIN] Sphere grid node %d applied: [%s] %s" % [node.id, SphereGrid.NodeType.keys()[node.node_type], node.label])

func _apply_all_unlocked_sphere_nodes() -> void:
	## Applies all already-unlocked sphere grid nodes to the character.
	## Called after character selection to sync grid state.
	var grid = main.sphere_grid_ui.sphere_grid
	if not grid:
		return
	for node in grid.get_all_nodes():
		if node.unlocked and node.node_type != SphereGrid.NodeType.START:
			_apply_sphere_grid_node(node)

func _parse_stat_label(label: String) -> Dictionary:
	## Parses labels like "STR +3" → { "stat": "strength", "value": 3 }
	var stat_map = {
		"STR": "strength",
		"DEX": "dexterity",
		"INT": "intelligence",
		"WIS": "wisdom",
		"AGI": "agility",
		"DET": "determination",
	}
	for abbr in stat_map:
		if label.begins_with(abbr):
			var value = _parse_numeric_value(label)
			if value > 0:
				return { "stat": stat_map[abbr], "value": value }
	return {}

func _parse_numeric_value(label: String) -> int:
	## Extracts the first integer from a label like "HP +10" or "Mana +5"
	var regex = RegEx.new()
	regex.compile("\\+(\\d+)")
	var result = regex.search(label)
	if result:
		return int(result.get_string(1))
	# Try without + sign
	regex.compile("(\\d+)")
	result = regex.search(label)
	if result:
		return int(result.get_string(1))
	return 0

func _parse_passive_description(desc: String, node_id: int) -> Dictionary:
	## Parses passive descriptions like "On kill: heal 1 HP" into structured data.
	## Returns { "node_id": int, "trigger": String, "effect": String, "value": float, "chance": float }
	var passive: Dictionary = { "node_id": node_id, "trigger": "", "effect": "", "value": 0, "chance": 1.0 }

	# Extract trigger (everything before the colon)
	var colon_idx = desc.find(":")
	if colon_idx < 0:
		return {}

	var trigger_part = desc.substr(0, colon_idx).strip_edges().to_lower()
	var effect_part = desc.substr(colon_idx + 1).strip_edges().to_lower()

	# Map trigger text to trigger ID
	var trigger_map = {
		"on kill": "on_kill",
		"on card play": "on_card_play",
		"on move": "on_move",
		"on cycle": "on_cycle",
		"on tempo cycle": "on_tempo_cycle",
		"on attack": "on_attack",
		"on dodge": "on_dodge",
		"on heal": "on_heal",
		"on block": "on_block",
		"on crit": "on_crit",
		"on spell cast": "on_spell_cast",
		"on discard": "on_discard",
		"on draw": "on_draw",
	}

	for text in trigger_map:
		if trigger_part == text:
			passive["trigger"] = trigger_map[text]
			break

	if passive["trigger"] == "":
		return {}

	# Check for percentage chance (e.g., "5% draw extra" or "10% apply bleed").
	# NOT for magnitude percentages: "deal 50% bonus" and "overheal becomes
	# 200% armor" use % as an amount — stripping it would eat the effect.
	var chance_regex = RegEx.new()
	chance_regex.compile("(\\d+)%\\s*(.*)")
	var chance_match = chance_regex.search(effect_part)
	if chance_match and "bonus" not in effect_part and "overheal" not in effect_part:
		passive["chance"] = float(chance_match.get_string(1)) / 100.0
		effect_part = chance_match.get_string(2)

	# Parse the effect and value
	var value_regex = RegEx.new()
	value_regex.compile("(\\d+)")
	var value_match = value_regex.search(effect_part)
	if value_match:
		passive["value"] = int(value_match.get_string(1))

	# Categorize the effect.
	# Enemy-targeted and "costs 0" checks must come BEFORE the generic
	# armor/draw/damage checks (otherwise "all enemies -1 armor" reads as player
	# armor, and "draw costs 0" reads as a draw).
	if "enem" in effect_part and "armor" in effect_part:
		passive["effect"] = "enemy_armor_reduce"
	elif "enem" in effect_part and "damage" in effect_part:
		passive["effect"] = "aoe_damage"
	elif "costs 0" in effect_part or "cost 0" in effect_part:
		passive["effect"] = "free_draw"
	elif "overheal" in effect_part:
		# Must beat the generic "heal" checks — "overheal" contains "heal".
		passive["effect"] = "overheal_armor"
	elif "bonus" in effect_part:
		passive["effect"] = "bonus_damage"
	elif "heal" in effect_part and "hp" in effect_part:
		passive["effect"] = "heal"
	elif "heal" in effect_part:
		passive["effect"] = "heal"
	elif "draw" in effect_part:
		passive["effect"] = "draw_card"
	elif "armor" in effect_part:
		passive["effect"] = "gain_armor"
	elif "mana" in effect_part and "regen" in effect_part:
		passive["effect"] = "regen_mana"
	elif "mana" in effect_part and "gain" in effect_part:
		passive["effect"] = "gain_mana"
	elif "mana" in effect_part:
		passive["effect"] = "gain_mana"
	elif "bleed" in effect_part:
		passive["effect"] = "apply_bleed"
	elif "tempo" in effect_part:
		passive["effect"] = "gain_tempo"
	elif "cleanse" in effect_part:
		passive["effect"] = "cleanse_debuff"
	elif "reflect" in effect_part:
		passive["effect"] = "reflect_damage"
	elif "bonus" in effect_part and "damage" in effect_part:
		passive["effect"] = "bonus_damage"
	elif "deal" in effect_part and "damage" in effect_part:
		passive["effect"] = "deal_damage"
	elif "stun" in effect_part:
		passive["effect"] = "stun_enemy"
	elif "counterattack" in effect_part:
		passive["effect"] = "counterattack"
	elif "haste" in effect_part:
		passive["effect"] = "gain_haste"
	elif "empower" in effect_part:
		passive["effect"] = "gain_empower"
	elif "double cast" in effect_part:
		passive["effect"] = "double_cast"
	elif "refund" in effect_part:
		passive["effect"] = "refund_mana"
	elif "return" in effect_part:
		passive["effect"] = "return_to_hand"
	elif "cost" in effect_part and "less" in effect_part:
		passive["effect"] = "reduce_cost"
	elif "freeze" in effect_part:
		passive["effect"] = "freeze_enemy"
	elif "overheal" in effect_part:
		passive["effect"] = "overheal_armor"
	elif "costs 0" in effect_part:
		passive["effect"] = "free_draw"
	else:
		passive["effect"] = effect_part  # Store raw text as fallback

	# Secondary "... and N mana" rider when the primary effect isn't itself mana
	# (e.g. "draw 2 cards and gain 2 mana", "gain 2 armor and 1 mana").
	if passive["effect"] not in ["gain_mana", "regen_mana"] and "mana" in effect_part:
		var mana_regex = RegEx.new()
		mana_regex.compile("(\\d+)\\s*mana")
		var mm = mana_regex.search(effect_part)
		if mm:
			passive["mana_bonus"] = int(mm.get_string(1))

	passive["description"] = desc
	return passive

# ============================================
# CONSTELLATION COMPLETION
# ============================================

var _active_constellations: Array[String] = []  # IDs of completed constellations

func _on_constellation_completed(constellation_id: String) -> void:
	## Called when the player completes a constellation on the sphere grid.
	var grid = main.sphere_grid_ui.sphere_grid
	var c = grid.get_constellation(constellation_id)
	if not c:
		return

	if constellation_id not in _active_constellations:
		_active_constellations.append(constellation_id)
	_apply_constellation_bonus(constellation_id)
	main.add_battle_log("CONSTELLATION COMPLETE: %s" % c.name, c.color)
	main.add_battle_log("Bonus: %s" % c.bonus_description, Color(0.9, 0.85, 0.5))
	print("[MAIN] Constellation completed: %s — %s" % [c.name, c.bonus_description])

func _on_constellation_replaced(old_id: String, _new_id: String) -> void:
	## Called when a constellation is replaced by a new one. Removes old bonuses.
	var stats = main.player.get_stats()
	if not stats:
		return

	# Remove the old constellation from active list
	_active_constellations.erase(old_id)

	# Remove sphere grid passives associated with this constellation
	var passives_to_remove: Array[int] = []
	for i in range(stats.sphere_grid_passives.size() - 1, -1, -1):
		var passive = stats.sphere_grid_passives[i]
		var desc: String = passive.get("description", "")
		var grid = main.sphere_grid_ui.sphere_grid
		var old_c = grid.get_constellation(old_id)
		if old_c and old_c.name in desc:
			stats.sphere_grid_passives.remove_at(i)

	# Reverse stat bonuses for constellations that granted direct stats
	match old_id:
		"mind_weaver":
			stats.sphere_bonus_mana -= 3
			stats.max_mana -= 3
			stats.current_mana = min(stats.current_mana, stats.get_available_max_mana())
			stats.mana_changed.emit(stats.current_mana, stats.max_mana)
		"windwalker":
			stats.sphere_bonus_agility -= 5
			stats.base_agility -= 5
			stats.recalculate_derived_stats()
		"storm_runner":
			stats.sphere_bonus_agility -= 5
			stats.base_agility -= 5
			stats.recalculate_derived_stats()
		"unyielding":
			stats.sphere_bonus_determination -= 2
			stats.determination -= 2
			stats.recalculate_derived_stats()
		"iron_bastion":
			stats.sphere_bonus_armor -= 5
		"natures_grace":
			stats.sphere_bonus_regen -= 2
			stats.sphere_bonus_heal_power -= 5

	stats.stats_updated.emit()
	var grid = main.sphere_grid_ui.sphere_grid
	var old_c = grid.get_constellation(old_id)
	if old_c:
		main.add_battle_log("Constellation replaced: %s" % old_c.name, Color(0.7, 0.5, 0.3))
		print("[MAIN] Constellation removed: %s" % old_c.name)

func _apply_constellation_bonus(constellation_id: String) -> void:
	## Applies the permanent bonus from a completed constellation.
	var stats = main.player.get_stats()
	if not stats:
		return

	match constellation_id:
		"iron_will":
			# On kill: gain 3 armor and heal 2 HP — register as a sphere passive
			stats.add_sphere_grid_passive({
				"node_id": -1, "trigger": "on_kill", "effect": "iron_will",
				"value": 0, "chance": 1.0,
				"description": "Iron Will: On kill: gain 3 armor and heal 2 HP"
			})
		"blood_hunter":
			# +15% bleed on attacks, bleed +2/tick — register as a sphere passive
			stats.add_sphere_grid_passive({
				"node_id": -1, "trigger": "on_attack", "effect": "blood_hunter",
				"value": 0, "chance": 0.15,
				"description": "Blood Hunter: 15% bleed on attacks, bleed +2/tick"
			})
		"arcane_current":
			# Spell cards deal +5 bonus damage — register as a sphere passive
			stats.add_sphere_grid_passive({
				"node_id": -1, "trigger": "on_spell_cast", "effect": "arcane_current",
				"value": 5, "chance": 1.0,
				"description": "Arcane Current: Spell cards deal +5 bonus damage"
			})
		"mind_weaver":
			# On spell cast: 20% draw a card. +3 max mana
			stats.apply_sphere_grid_mana(3)
			stats.add_sphere_grid_passive({
				"node_id": -1, "trigger": "on_spell_cast", "effect": "draw_card",
				"value": 1, "chance": 0.20,
				"description": "Mind Weaver: 20% chance to draw a card on spell cast"
			})
		"windwalker":
			# +1 movement, first card after moving costs 1 less
			stats.add_sphere_grid_passive({
				"node_id": -1, "trigger": "on_move", "effect": "reduce_cost",
				"value": 1, "chance": 1.0,
				"description": "Windwalker: First card after moving costs 1 less"
			})
			# +1 movement via agility
			stats.apply_sphere_grid_stat("agility", 5)  # +5 AGI = +1 move/cycle
		"storm_runner":
			# +1 movement, gain 2 mana on move
			stats.add_sphere_grid_passive({
				"node_id": -1, "trigger": "on_move", "effect": "gain_mana",
				"value": 2, "chance": 1.0,
				"description": "Storm Runner: Gain 2 mana on each move"
			})
			stats.apply_sphere_grid_stat("agility", 5)  # +5 AGI = +1 move/cycle
		"sages_insight":
			# Draw 1 extra card per tempo cycle
			stats.add_sphere_grid_passive({
				"node_id": -1, "trigger": "on_cycle", "effect": "draw_card",
				"value": 1, "chance": 1.0,
				"description": "Sage's Insight: Draw 1 extra card per tempo cycle"
			})
		"unyielding":
			# Below 50% HP: gain 3 armor each cycle, +20% determination
			stats.add_sphere_grid_passive({
				"node_id": -1, "trigger": "on_cycle", "effect": "unyielding",
				"value": 3, "chance": 1.0,
				"description": "Unyielding: Below 50% HP: gain 3 armor each cycle"
			})
			stats.apply_sphere_grid_stat("determination", 2)

		# --- Ring 3-4 Constellations ---
		"crimson_edge":
			# Attacks heal for 8% of damage dealt
			stats.add_sphere_grid_passive({
				"node_id": -1, "trigger": "on_attack", "effect": "crimson_edge",
				"value": 8, "chance": 1.0,
				"description": "Crimson Edge: Attacks heal for 8% of damage dealt"
			})
		"shadow_strike":
			# Critical hits deal 2.5x damage instead of 2x — tracked as a flag
			stats.add_sphere_grid_passive({
				"node_id": -1, "trigger": "on_crit", "effect": "shadow_strike",
				"value": 0, "chance": 1.0,
				"description": "Shadow Strike: Critical hits deal 2x damage instead of 1.5x"
			})
		"iron_bastion":
			# +5 starting armor, and when hit: 15% chance the damage is halved
			# (applied inside PlayerStats.take_damage).
			stats.sphere_bonus_armor += 5
			stats.current_armor += 5
			stats.armor_changed.emit(stats.current_armor)
			stats.damage_proc_reduction_chance = 0.15
			stats.damage_proc_reduction_percent = 50.0
		"natures_grace":
			# Regen 2 HP per cycle, heal cards +5
			stats.sphere_bonus_regen += 2
			stats.sphere_bonus_heal_power += 5
			stats.stats_updated.emit()

# ============================================
# SKILL TREE → CHARACTER SYNC
# ============================================

func _on_skill_tree_option_chosen(level: int, option_index: int) -> void:
	## Called when the player chooses one of the 4 options in a skill tree row.
	var tree = main.skill_tree_ui.skill_tree
	if not tree:
		return
	var row = tree.get_row_for_level(level)
	if not row:
		return
	var option = row.get_chosen_option()
	if not option:
		return

	print("[MAIN] Skill tree choice at level %d: %s (%s)" % [level, option.name, option.get_type_label()])
	_apply_skill_tree_option(option)

func _on_skill_tree_stats_allocated(allocations: Dictionary) -> void:
	## Spend banked level-up stat points on the player's base stats.
	var stats = main.player.get_stats()
	if not stats:
		return
	if not stats.apply_stat_allocation(allocations):
		return
	var parts := []
	for stat_name in allocations:
		if allocations[stat_name] > 0:
			parts.append("+%d %s" % [allocations[stat_name], stat_name.substr(0, 3).to_upper()])
	main.add_battle_log("Stats allocated: %s" % ", ".join(parts), Color(0.4, 1.0, 0.5))

func _on_skill_tree_retrospective_chosen(level: int, option_index: int) -> void:
	## Called when the player uses a retrospective token to reclaim a skipped option.
	var tree = main.skill_tree_ui.skill_tree
	if not tree:
		return
	var row = tree.get_row_for_level(level)
	if not row or option_index < 0 or option_index >= row.options.size():
		return
	var option = row.options[option_index]
	print("[MAIN] Retrospective pick at level %d: %s (%s)" % [level, option.name, option.get_type_label()])
	_apply_skill_tree_option(option)

func _apply_skill_tree_option(option) -> void:
	## Applies a chosen skill tree option's effect to the main.player.
	var stats = main.player.get_stats()
	if not stats:
		return

	if option.option_type == SkillTreeData.OptionType.PASSIVE or option.option_type == SkillTreeData.OptionType.PASSIVE_MUTATION:
		var pid = option.passive_id
		if pid == "":
			pid = option.name.to_lower().replace(" ", "_")

		# Special handling for stat-granting passives (apply immediately + register)
		match pid:
			"ladder_work":
				# Ryan: +3 dexterity and +3 agility
				stats.base_dexterity += 3
				stats.base_agility += 3
				stats.stats_updated.emit()
				main.add_battle_log("Ladder Work: +3 DEX, +3 AGI", Color(0.3, 0.7, 1.0))
			"stone_skin":
				# Brad: +10% Fire, Physical, Lightning resistance
				stats.add_skill_tree_passive(pid)
				main.add_battle_log("Stone Skin: +10%% Fire/Physical/Lightning resistance", Color(0.4, 0.9, 0.4))
			"deadly":
				# Stephen: +3 damage and +50% crit damage vs targets with no allies within 2 tiles
				stats.add_skill_tree_passive(pid)
				main.add_battle_log("Deadly: +3 damage & +50%% crit damage vs isolated targets", Color(0.9, 0.3, 0.3))
			"eagle_eye":
				# Stephen: +2 range on ranged attacks (tracked via passive)
				stats.add_skill_tree_passive(pid)
				main.add_battle_log("Eagle Eye: +2 range on ranged attacks", Color(0.4, 0.9, 0.4))
			"sword_specialist":
				# Stephen: +25% block when only wielding swords (tracked via passive)
				stats.add_skill_tree_passive(pid)
				main.add_battle_log("Sword Specialist: +25%% block with swords only", Color(0.3, 0.7, 1.0))
			"tricks_of_death":
				# Jeremy: +10% to all % chances (permanent chance_boost)
				stats.chance_boost += 10.0
				stats.add_skill_tree_passive(pid)
				main.add_battle_log("Tricks of Death: +10%% to all chances", Color(0.4, 0.9, 0.4))
			_:
				stats.add_skill_tree_passive(pid)
				main.add_battle_log("Passive unlocked: %s" % option.name, Color(0.9, 0.7, 0.2))

	elif option.option_type == SkillTreeData.OptionType.STAT_BONUS:
		if option.stat_type != "" and option.stat_amount > 0:
			match option.stat_type:
				"strength": stats.base_strength += option.stat_amount
				"dexterity": stats.base_dexterity += option.stat_amount
				"intelligence": stats.base_intelligence += option.stat_amount
				"wisdom": stats.base_wisdom += option.stat_amount
				"agility": stats.base_agility += option.stat_amount
				"determination": stats.determination += option.stat_amount
			stats.stats_updated.emit()
			main.add_battle_log("+%d %s" % [option.stat_amount, option.stat_type.capitalize()], Color(0.3, 0.8, 1.0))

	elif option.option_type == SkillTreeData.OptionType.CARD:
		if option.card_id != "":
			if main.deck_manager.add_card_to_deck_from_id(option.card_id):
				main.add_battle_log("Card added: %s" % option.name, Color(0.5, 1.0, 0.5))

# ============================================
# SKILL TREE PASSIVE TRIGGERS
# ============================================

func _trigger_skill_tree_on_discard(card: Card) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Keep Them Guessing: -1t from a random card in hand
	if stats.has_skill_tree_passive("keep_them_guessing"):
		if main.deck_manager and main.deck_manager.hand.size() > 0:
			var random_idx = randi() % main.deck_manager.hand.size()
			var target_card = main.deck_manager.hand[random_idx]
			if target_card.tempo_cost > 0:
				target_card.tempo_cost -= 1
				main.add_battle_log("Keep Them Guessing: %s -1t" % target_card.card_name, Color(0.9, 0.3, 0.3))

func _trigger_skill_tree_on_card_play(card: Card, target) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# From the Hip: clear the discount when any card is played
	if stats.has_skill_tree_passive("from_the_hip") and stats.st_from_hip_card != null:
		var discounted = stats.st_from_hip_card
		if is_instance_valid(discounted):
			discounted.mana_cost = stats.st_from_hip_original_cost
		stats.st_from_hip_card = null
		stats.st_from_hip_original_cost = 0

	# Nimble Assault: no Defense cards in hand → draw on attack
	if stats.has_skill_tree_passive("nimble_assault") and card.card_type == Card.CardType.ATTACK:
		var has_defense = false
		for c in main.deck_manager.hand:
			if c.card_type == Card.CardType.DEFENSE:
				has_defense = true
				break
		if not has_defense:
			main.deck_manager.attempt_draw()
			main.add_battle_log("Nimble Assault: drew a card!", Color(0.9, 0.3, 0.3))

	# Quick Step: instant played from hand → +5 armor
	if stats.has_skill_tree_passive("quick_step"):
		if card.card_type == Card.CardType.REACTION or card.tempo_cost == 0:
			stats.add_armor(5)
			main.add_battle_log("Quick Step: +5 armor", Color(0.3, 0.7, 1.0))

	# Stimulant: healing with a Pocket card → healed target draws a card (5 tempo cooldown)
	if stats.has_skill_tree_passive("stimulant") and card.card_keyword == Card.CardKeyword.POCKET and card.heal_amount > 0 and stats.st_stimulant_cooldown <= 0:
		stats.st_stimulant_cooldown = 5
		main.deck_manager.attempt_draw()
		main.add_battle_log("Stimulant: healed target drew a card!", Color(0.4, 0.9, 0.4))

	# Mad Scientist: last card played changes outcome of potion (POCKET) cards
	if stats.has_skill_tree_passive("mad_scientist") and card.card_keyword == Card.CardKeyword.POCKET and main._last_played_card:
		var last_type = main._last_played_card.card_type
		var buff_mgr = main.player.get_buff_manager()
		var is_heal_outcome = card.heal_amount > 0
		var is_poison_outcome = false

		# Poisoned Blood flips heal → poison outcome (regen = poison)
		if buff_mgr and buff_mgr.poisoned_blood_active and card.heal_amount > 0:
			is_heal_outcome = false
			is_poison_outcome = true

		if is_heal_outcome:
			if last_type == Card.CardType.UTILITY:
				# Utility → Heal: add 3 stacks of regen to the healed target
				if buff_mgr:
					buff_mgr.apply_buff(Buff.create_regen(3, 15, "Mad Scientist"))
					main.add_battle_log("Mad Scientist: +3 regen!", Color(0.4, 0.9, 0.4))
			elif last_type == Card.CardType.ATTACK:
				# Attack → Heal: give healed target 3 strengthen
				if buff_mgr:
					buff_mgr.apply_buff(Buff.create_strengthen(3, 3, "Mad Scientist"))
					main.add_battle_log("Mad Scientist: +3 strengthen!", Color(0.4, 0.9, 0.4))

		elif is_poison_outcome:
			if last_type == Card.CardType.UTILITY:
				# Utility → Poison: add 3 additional stacks of poison
				if target and target.has_method("apply_debuff"):
					target.apply_debuff("poison", 3)
					main.add_battle_log("Mad Scientist: +3 poison stacks!", Color(0.4, 0.9, 0.4))
			elif last_type == Card.CardType.DEFENSE:
				# Defense → Poison: lower enemy physical defense by 10%
				if target and target is Enemy and target.current_armor > 0:
					var armor_loss = max(1, target.current_armor / 10)
					target.reduce_armor(armor_loss)
					main.add_battle_log("Mad Scientist: -%d armor! (-10%%)" % armor_loss, Color(0.4, 0.9, 0.4))

func _trigger_skill_tree_on_draw(card: Card) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Clean Exchange: draw Defense after playing Attack (or vice versa) → drawn card gets -1t
	if stats.has_skill_tree_passive("clean_exchange") and main._last_played_card:
		var drawn_is_defense = card.card_type == Card.CardType.DEFENSE
		var drawn_is_attack = card.card_type == Card.CardType.ATTACK
		var last_was_attack = main._last_played_card.card_type == Card.CardType.ATTACK
		var last_was_defense = main._last_played_card.card_type == Card.CardType.DEFENSE
		if (drawn_is_defense and last_was_attack) or (drawn_is_attack and last_was_defense):
			if card.tempo_cost > 0:
				card.tempo_cost -= 1
				main.add_battle_log("Clean Exchange: %s -1t" % card.card_name, Color(0.3, 0.7, 1.0))

	# From the Hip: if an attack card, discount the most recently drawn card by -1m
	if stats.has_skill_tree_passive("from_the_hip") and card.card_type == Card.CardType.ATTACK:
		# Clear previous discount if any
		if stats.st_from_hip_card != null and is_instance_valid(stats.st_from_hip_card):
			stats.st_from_hip_card.mana_cost = stats.st_from_hip_original_cost
		# Apply new discount
		if card.mana_cost > 0:
			stats.st_from_hip_original_cost = card.mana_cost
			card.mana_cost -= 1
			stats.st_from_hip_card = card
			main.add_battle_log("From the Hip: %s -1m" % card.card_name, Color(0.9, 0.3, 0.3))

func _trigger_skill_tree_on_attack(card: Card, target) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Surprise Opener: bonus damage on first strike per enemy
	if stats.has_skill_tree_passive("surprise_opener") and target and target is Enemy:
		var enemy_id = target.get_instance_id()
		if enemy_id not in stats.st_enemy_first_strikes:
			stats.st_enemy_first_strikes[enemy_id] = true
			var bonus = 2
			if target.current_armor <= 0:
				bonus += 2
			# Check if this is the enemy's first source of damage (full HP = no prior damage)
			if target.current_health >= target.max_health:
				bonus += 2
			target.take_damage(bonus, true)
			main.add_battle_log("Surprise Opener: +%d bonus damage!" % bonus, Color(0.8, 0.4, 0.9))

	# Solemn Independence: +5 damage on attacks while surrounded (3+ enemies w/in 2)
	if stats.has_skill_tree_passive("solemn_independence") and target and target is Enemy and _solemn_surrounded():
		target.take_damage(5, true)
		main.add_battle_log("Solemn Independence: +5 damage!", Color(0.8, 0.4, 0.9))

func _solemn_surrounded() -> bool:
	## True when 3 or more living enemies are within 2 tiles of the player.
	if not main.enemy_spawner:
		return false
	var count := 0
	for enemy in main.enemy_spawner.get_living_enemies():
		if main.player.position.distance_to(enemy.position) <= 2.0:
			count += 1
			if count >= 3:
				return true
	return false

func _trigger_skill_tree_on_crit(target) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Sphere-grid on-crit passives (heal on crit, bleed on crit, Shadow Strike).
	_trigger_sphere_passives("on_crit", {"target": target})

	# Eye Scrape: every 3rd crit → invisibility
	if stats.has_skill_tree_passive("eye_scrape"):
		stats.st_crit_counter += 1
		if stats.st_crit_counter >= 3:
			stats.st_crit_counter = 0
			var buff_mgr = main.player.get_buff_manager()
			if buff_mgr:
				buff_mgr.apply_buff(Buff.create_invisible(10, "Eye Scrape"))
				main._set_player_invisible(true)
				main.add_battle_log("Eye Scrape: Invisibility!", Color(0.8, 0.4, 0.9))

func _trigger_skill_tree_on_cycle() -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Stimulant: tick cooldown
	if stats.st_stimulant_cooldown > 0:
		stats.st_stimulant_cooldown -= 5

	# Solemn Independence: while surrounded (3+ enemies w/in 2), +5 armor/cycle and
	# block ally healing (the flag is read in PlayerStats.heal). Refresh it each
	# cycle so the "cannot be healed by allies" clause tracks positioning.
	if stats.has_skill_tree_passive("solemn_independence"):
		stats.solemn_active = _solemn_surrounded()
		if stats.solemn_active:
			stats.add_armor(5)
			main.add_battle_log("Solemn Independence: +5 armor (surrounded)", Color(0.4, 0.9, 0.4))
	elif stats.solemn_active:
		stats.solemn_active = false

	# Let's Dance: gain armor = spaces moved/2, deal damage = spaces moved to nearest enemy within 3
	if stats.has_skill_tree_passive("let's_dance"):
		var spaces = main.tempo_manager.spaces_moved_this_cycle
		if spaces > 0:
			var armor = floori(spaces / 2.0)
			if armor > 0:
				stats.add_armor(armor)
				main.add_battle_log("Let's Dance: +%d armor (%d spaces)" % [armor, spaces], Color(0.3, 0.7, 1.0))
			# Deal damage to nearest enemy within 3 range
			var nearest: Enemy = null
			var nearest_dist: float = INF
			if main.enemy_spawner:
				for enemy in main.enemy_spawner.get_living_enemies():
					var dist = main.player.position.distance_to(enemy.position)
					if dist <= 3.0 and dist < nearest_dist:
						nearest_dist = dist
						nearest = enemy
			if nearest:
				nearest.take_damage(spaces, true)
				main.add_battle_log("Let's Dance: %d damage to %s!" % [spaces, nearest.enemy_name], Color(0.3, 0.7, 1.0))

func _trigger_skill_tree_on_heal_ally(ally_name: String) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Brad: Redemption — heal ally → +10% crit on next attack
	_trigger_skill_tree_brad_on_heal_ally(ally_name)

	# Jeremy: Whispers of the Flock — mark healed ally
	_trigger_skill_tree_jeremy_on_heal_ally()

func _trigger_skill_tree_on_displacement() -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Now You See Me: displacement → invisibility
	if stats.has_skill_tree_passive("now_you_see_me"):
		var buff_mgr = main.player.get_buff_manager()
		if buff_mgr:
			buff_mgr.apply_buff(Buff.create_invisible(10, "Now You See Me"))
			main._set_player_invisible(true)
			main.add_battle_log("Now You See Me: Invisibility!", Color(0.8, 0.4, 0.9))

func _trigger_skill_tree_on_debuff_applied(target, debuff_name: String, value: int) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Pop Rocks: applying poison to already-poisoned enemy deals 1/3 current stacks as immediate damage
	if stats.has_skill_tree_passive("pop_rocks") and debuff_name == "poison" and target and target.has_method("take_damage"):
		var prev_stacks = target.poison_stacks - value
		if prev_stacks > 0:
			var pop_damage = max(1, target.poison_stacks / 3)
			target.take_damage(pop_damage, true)
			main.add_battle_log("Pop Rocks: %d damage! (%d poison stacks)" % [pop_damage, target.poison_stacks], Color(0.4, 0.9, 0.4))

func _trigger_skill_tree_on_debuff_expired(target) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	pass

func _trigger_skill_tree_on_movement_cycle() -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Let's Dance moved to _trigger_skill_tree_on_cycle (triggers every cycle, not just movement)
	pass

# ============================================
# BRAD SKILL TREE PASSIVE TRIGGERS
# ============================================

func _trigger_skill_tree_brad_on_damage_taken(damage: int) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Enraged Will: dropping below 25% HP → one Reach AOE swing (1 base + 1 Reach
	# = 2 range) + gain 1 mana per kill. 10 tempo cooldown — staying low can
	# re-trigger it once the cooldown elapses.
	if stats.has_skill_tree_passive("enraged_will"):
		var ew_elapsed = main.tempo_manager.get_global_tempo() - stats.st_enraged_will_last_tempo
		if stats.get_health_percent() <= 0.25 and stats.current_health > 0 and ew_elapsed >= 10:
			stats.st_enraged_will_last_tempo = main.tempo_manager.get_global_tempo()
			var enemies = main.enemy_spawner.get_enemies_in_radius(main.player.position, 2.0) if main.enemy_spawner else []
			if enemies.size() > 0:
				var dmg = stats.get_effective_physical_damage(0)
				var kills = 0
				for enemy in enemies:
					enemy.take_damage(dmg, true)
					if not enemy.is_alive():
						kills += 1
				if kills > 0:
					stats.gain_mana(kills)
				main.add_battle_log("Enraged Will: AOE swing for %d! (+%d mana)" % [dmg, kills], Color(0.9, 0.3, 0.3))

	# Corrupted Strength: state is updated per cycle, no action needed on damage taken

func _trigger_skill_tree_brad_on_attacked(attacker) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# In the Trenches: when attacked from adjacent, knock attacker back (consumes 1 charge)
	if stats.has_skill_tree_passive("in_the_trenches"):
		_itt_try_refresh_charges(stats)
		if stats.st_itt_charges > 0:
			if attacker and attacker.has_method("knockback"):
				stats.st_itt_charges -= 1
				attacker.knockback(main.player.position)
				main.add_battle_log("In the Trenches: knocked back %s! (%d charge(s) left)" % [attacker.enemy_name, stats.st_itt_charges], Color(0.3, 0.7, 1.0))
				if stats.st_itt_charges <= 0:
					stats.st_itt_last_used_tempo = main.tempo_manager.get_global_tempo()

func _trigger_skill_tree_brad_itt_on_enter(enemy: Enemy) -> void:
	## In the Trenches: free attack when an enemy enters an adjacent square (consumes 1 charge)
	var stats = main.player.get_stats()
	if not stats:
		return
	if not stats.has_skill_tree_passive("in_the_trenches"):
		return
	_itt_try_refresh_charges(stats)
	if stats.st_itt_charges <= 0:
		return
	stats.st_itt_charges -= 1
	var dmg = stats.get_effective_physical_damage(0)
	enemy.take_damage(dmg, true)
	main.add_battle_log("In the Trenches: free attack on %s for %d! (%d charge(s) left)" % [enemy.enemy_name, dmg, stats.st_itt_charges], Color(0.3, 0.7, 1.0))
	if stats.st_itt_charges <= 0:
		stats.st_itt_last_used_tempo = main.tempo_manager.get_global_tempo()

func _itt_try_refresh_charges(stats: PlayerStats) -> void:
	## Refresh In the Trenches charges if 10 tempo has passed since last exhaustion.
	if stats.st_itt_charges <= 0:
		var elapsed = main.tempo_manager.get_global_tempo() - stats.st_itt_last_used_tempo
		if elapsed >= 10:
			stats.st_itt_charges = 2

func _trigger_skill_tree_brad_on_defense_card_play(card: Card) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# The Way of the Plate: every other Defense card costs -1m/-1t
	if stats.has_skill_tree_passive("the_way_of_the_plate"):
		stats.st_defense_cards_played += 1
		if stats.st_defense_cards_played >= 2:
			stats.st_defense_cards_played = 0
			# Refund 1 mana and 1 tempo
			stats.gain_mana(1)
			main.tempo_manager.add_tempo(-1)
			main.add_battle_log("Way of the Plate: -1m/-1t refund!", Color(0.3, 0.7, 1.0))

	# Pristine Armor: +2 armor on defense cards, +5 bonus for 3 in a row
	if stats.has_skill_tree_passive("pristine_armor"):
		stats.add_armor(2)
		stats.st_consecutive_defense += 1
		if stats.st_consecutive_defense >= 3:
			stats.st_consecutive_defense = 0
			stats.add_armor(5)
			main.add_battle_log("Pristine Armor: +2 armor, +5 bonus (3 in a row)!", Color(0.3, 0.7, 1.0))
		else:
			main.add_battle_log("Pristine Armor: +2 armor", Color(0.3, 0.7, 1.0))

func _trigger_skill_tree_brad_on_heal() -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Vines Codependence: whenever you heal, gain 3 thorns
	if stats.has_skill_tree_passive("vines_codependence"):
		var buff_mgr = main.player.get_buff_manager()
		if buff_mgr:
			buff_mgr.apply_buff(Buff.new(Buff.BuffType.THORNS, 3, 30))
			main.add_battle_log("Vines Codependence: +3 thorns", Color(0.4, 0.9, 0.4))

	# Redemption: gain crit on next attack when healing (self or ally)
	if stats.has_skill_tree_passive("redemption"):
		var buff_mgr = main.player.get_buff_manager()
		if buff_mgr:
			buff_mgr.apply_buff(Buff.create_enlightened(100, 1, "Redemption"))
			main.add_battle_log("Redemption: crit on next attack!", Color(0.8, 0.4, 0.9))

func _trigger_skill_tree_brad_on_heal_ally(ally_name: String) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return
	# Redemption for ally heals is now handled in _trigger_skill_tree_brad_on_heal
	# which fires on all heals (self and ally). This function remains for
	# ally-specific effects from other characters (e.g. Field Medic).
	pass

func _trigger_skill_tree_brad_on_cycle() -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Ancestral Aid: depends on hand composition — more attacks = -2m to attack, more defense = +3 HP regen
	if stats.has_skill_tree_passive("ancestral_aid"):
		var attack_count = 0
		var defense_count = 0
		for c in main.deck_manager.hand:
			if c.card_type == Card.CardType.ATTACK:
				attack_count += 1
			elif c.card_type == Card.CardType.DEFENSE:
				defense_count += 1
		if attack_count > defense_count:
			# Discount a random attack card by 2 mana
			var attacks: Array[Card] = []
			for c in main.deck_manager.hand:
				if c.card_type == Card.CardType.ATTACK and c.mana_cost >= 2:
					attacks.append(c)
			if attacks.size() > 0:
				var target_card = attacks[randi() % attacks.size()]
				target_card.mana_cost -= 2
				main.add_battle_log("Ancestral Aid: %s -2m (offense)" % target_card.card_name, Color(0.4, 0.9, 0.4))
		elif defense_count > attack_count:
			stats.heal(3)
			main.add_battle_log("Ancestral Aid: +3 HP regen (defense)", Color(0.4, 0.9, 0.4))
		else:
			# Tied — small heal
			stats.heal(1)
			main.add_battle_log("Ancestral Aid: +1 HP (balanced)", Color(0.4, 0.9, 0.4))

	# Directed Strength is checked at attack time, not per-cycle

	# Corrupted Strength: check nearby enemies, toggle active state, apply armor + HP drain
	if stats.has_skill_tree_passive("corrupted_strength"):
		var nearby_enemies = main.enemy_spawner.get_enemies_in_radius(main.player.position, 3.0) if main.enemy_spawner else []
		var was_active = stats.st_corrupted_strength_active
		stats.st_corrupted_strength_active = nearby_enemies.size() >= 3
		stats.st_corrupted_strength_no_ally_heal = stats.st_corrupted_strength_active
		if stats.st_corrupted_strength_active:
			stats.add_armor(5)
			stats.current_health = max(1, stats.current_health - 2)
			stats.health_changed.emit(stats.current_health, stats.max_health)
			if not was_active:
				main.add_battle_log("Corrupted Strength: darkness surges! +5 dmg, +5 armor/cycle, no ally healing", Color(0.8, 0.4, 0.9))
			else:
				main.add_battle_log("Corrupted Strength: +5 armor, -2 HP", Color(0.8, 0.4, 0.9))
		elif was_active:
			main.add_battle_log("Corrupted Strength: darkness recedes", Color(0.6, 0.4, 0.6))

func _trigger_skill_tree_brad_on_attack(card: Card, target) -> int:
	## Returns bonus damage from Brad passives.
	var stats = main.player.get_stats()
	if not stats:
		return 0
	var bonus = 0

	# Directed Strength (-5 STR above 50% HP, +5 below) is applied as a real
	# strength modifier in PlayerStats._directed_strength_mod(), so every
	# strength-scaled formula picks it up — not as flat bonus damage here.

	# Life Steal: all attacks life steal by 5% — applied directly in Card.execute()
	# (the generic LIFE_STEAL buff heals 100%, so it must NOT be used here).

	# Corrupted Strength: +5 damage while active (3+ enemies within 2 tiles)
	if stats.has_skill_tree_passive("corrupted_strength") and stats.st_corrupted_strength_active:
		bonus += 5
		main.add_battle_log("Corrupted Strength: +5 damage!", Color(0.8, 0.4, 0.9))

	return bonus

var _ptp_confirmed_callable: Callable
var _ptp_declined_callable: Callable

func _on_point_to_prove_triggered(debuff: Debuff) -> void:
	## Show dialog asking the player if they want to sacrifice HP to ignore the debuff.
	# Disconnect any previous one-shot connections
	if _ptp_confirmed_callable.is_valid() and main.point_to_prove_dialog.confirmed.is_connected(_ptp_confirmed_callable):
		main.point_to_prove_dialog.confirmed.disconnect(_ptp_confirmed_callable)
	if _ptp_declined_callable.is_valid() and main.point_to_prove_dialog.declined.is_connected(_ptp_declined_callable):
		main.point_to_prove_dialog.declined.disconnect(_ptp_declined_callable)

	var debuff_name = Debuff.DebuffType.keys()[debuff.debuff_type].capitalize()
	var cost = 5
	main.point_to_prove_dialog.show_dialog(debuff_name, debuff.debuff_type, cost)
	_ptp_confirmed_callable = _on_point_to_prove_confirmed.bind(debuff)
	_ptp_declined_callable = _on_point_to_prove_declined
	main.point_to_prove_dialog.confirmed.connect(_ptp_confirmed_callable, CONNECT_ONE_SHOT)
	main.point_to_prove_dialog.declined.connect(_ptp_declined_callable, CONNECT_ONE_SHOT)

func _on_point_to_prove_confirmed(debuff_type: int, debuff: Debuff) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return
	# Sacrifice HP to remove the debuff
	stats.take_direct_damage(5)
	var debuff_mgr = main.player.get_debuff_manager()
	if debuff_mgr:
		debuff_mgr.remove_debuff(debuff.debuff_type)
	var debuff_name = Debuff.DebuffType.keys()[debuff_type].capitalize()
	main.add_battle_log("Point to Prove: Sacrificed 5 HP to ignore %s!" % debuff_name, Color(0.9, 0.7, 0.3))

func _on_point_to_prove_declined(debuff_type: int) -> void:
	var debuff_name = Debuff.DebuffType.keys()[debuff_type].capitalize()
	main.add_battle_log("Point to Prove: Accepted %s." % debuff_name, Color(0.6, 0.6, 0.6))

# ============================================
# STEPHEN SKILL TREE PASSIVE TRIGGERS
# ============================================

func _trigger_skill_tree_stephen_on_attack(card: Card, target) -> int:
	## Returns bonus damage from Stephen passives.
	var stats = main.player.get_stats()
	if not stats:
		return 0
	var bonus = 0

	# Deadly: +3 damage (and +50% crit damage, applied via st_deadly_crit_active)
	# when the target has no allies within 2 tiles
	if stats.has_skill_tree_passive("deadly") and _deadly_isolated(target):
		bonus += 3
		main.add_battle_log("Deadly: +3 damage (isolated target)", Color(0.9, 0.3, 0.3))

	# Scouted: hitting the same enemy 3 times in a row → +6 range and auto-crit
	# on the next attack, usable against ANY enemy
	if stats.has_skill_tree_passive("scouted") and target and target is Enemy:
		var enemy_id = target.get_instance_id()
		if stats.st_scouted_bonus_active:
			# Consume on any target: auto-crit handled via Enlightened buff applied when bonus activated
			stats.st_scouted_bonus_active = false
			stats.st_scouted_target_id = enemy_id
			stats.st_scouted_hits = 1  # This hit counts as the first of a new streak
			main.add_battle_log("Scouted: bonus consumed!", Color(0.4, 0.9, 0.4))
		elif enemy_id == stats.st_scouted_target_id:
			stats.st_scouted_hits += 1
			if stats.st_scouted_hits >= 3:
				stats.st_scouted_bonus_active = true
				stats.st_scouted_hits = 0
				# Grant auto-crit on next attack
				var buff_mgr = main.player.get_buff_manager()
				if buff_mgr:
					buff_mgr.apply_buff(Buff.create_enlightened(100, 1, "Scouted"))
				main.add_battle_log("Scouted: 3 hits! +6 range and auto-crit on your next attack — any target!", Color(0.4, 0.9, 0.4))
		else:
			# Switched targets — reset streak
			stats.st_scouted_target_id = enemy_id
			stats.st_scouted_hits = 1

	# Skilled Momentum: 4 attacks in a row → 5th plays twice
	if stats.has_skill_tree_passive("skilled_momentum") and card.card_type == Card.CardType.ATTACK:
		stats.st_consecutive_attacks += 1
		if stats.st_consecutive_attacks >= 5:
			stats.st_consecutive_attacks = 0
			# Deal the card's damage again
			if target and target.has_method("take_damage"):
				var extra_dmg = card.last_damage_dealt if card.last_damage_dealt > 0 else stats.get_effective_physical_damage(card.base_damage)
				target.take_damage(extra_dmg, true)
				main.add_battle_log("Skilled Momentum: double strike for %d!" % extra_dmg, Color(0.9, 0.3, 0.3))

	# Swing for the Fences: cards with >4 tempo cost deal tempo cost as additional damage
	if stats.has_skill_tree_passive("swing_for_the_fences") and card.tempo_cost > 4:
		bonus += card.tempo_cost
		main.add_battle_log("Swing for the Fences: +%d damage!" % card.tempo_cost, Color(0.8, 0.4, 0.9))

	return bonus

func _deadly_isolated(target) -> bool:
	## Deadly: true when the target has no living allies within 2 tiles of it.
	if not (target is Enemy) or not is_instance_valid(target):
		return false
	if not main.enemy_spawner:
		return true
	for enemy in main.enemy_spawner.get_living_enemies():
		if enemy != target and target.position.distance_to(enemy.position) <= 2.0:
			return false
	return true

func update_deadly_crit_flag(card: Card, target) -> void:
	## Arm Deadly's +50% crit damage for the attack about to resolve on an
	## isolated target. Cleared by clear_deadly_crit_flag() after execution.
	var stats = main.player.get_stats()
	if not stats:
		return
	stats.st_deadly_crit_active = card != null and card.card_type == Card.CardType.ATTACK \
		and stats.has_skill_tree_passive("deadly") and _deadly_isolated(target)

func clear_deadly_crit_flag() -> void:
	var stats = main.player.get_stats()
	if stats:
		stats.st_deadly_crit_active = false

func _trigger_skill_tree_stephen_on_ranged_attack(_card: Card, _target) -> void:
	# Laced Arrow is now handled via _on_enemy_debuff_applied to add +1 when applying burn/cold/shock
	pass

func _trigger_skill_tree_stephen_on_expose(target) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Easy Target: when exposing an enemy, deal your damage again — repeat the
	# damage of the hit that broke the armor, not a generic strength swing.
	if stats.has_skill_tree_passive("easy_target") and target and target.has_method("take_damage"):
		var dmg: int = target.last_player_hit_damage if ("last_player_hit_damage" in target and target.last_player_hit_damage > 0) else stats.get_effective_physical_damage(0)
		target.take_damage(dmg, true)
		main.add_battle_log("Easy Target: repeated %d damage on expose!" % dmg, Color(0.9, 0.3, 0.3))

func _trigger_skill_tree_stephen_on_attacked(attacker) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Exposed Blind Spot: when struck with melee attack, gain crit chance = number of non-attack cards in hand
	if stats.has_skill_tree_passive("exposed_blind_spot"):
		var non_attack_count = 0
		for c in main.deck_manager.hand:
			if c.card_type != Card.CardType.ATTACK:
				non_attack_count += 1
		if non_attack_count > 0:
			stats.st_exposed_blind_spot_crit = non_attack_count
			main.add_battle_log("Exposed Blind Spot: +%d%% crit on next attack!" % non_attack_count, Color(0.3, 0.7, 1.0))

	# Phalanx: melee attack → deal damage = number of Defense cards in hand
	if stats.has_skill_tree_passive("phalanx") and attacker and attacker.has_method("take_damage"):
		var defense_count = 0
		for c in main.deck_manager.hand:
			if c.card_type == Card.CardType.DEFENSE:
				defense_count += 1
		if defense_count > 0:
			attacker.take_damage(defense_count, true)
			main.add_battle_log("Phalanx: %d damage back!" % defense_count, Color(0.3, 0.7, 1.0))

func _trigger_skill_tree_stephen_on_card_play(card: Card) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Skilled Momentum: reset counter if non-attack card is played
	if stats.has_skill_tree_passive("skilled_momentum") and card.card_type != Card.CardType.ATTACK:
		stats.st_consecutive_attacks = 0

	# Lethal Resourcefulness: 3 or less cards in hand + non-attack → free basic attack
	if stats.has_skill_tree_passive("lethal_resourcefulness") and not stats.st_lethal_resource_attacking:
		if card.card_type != Card.CardType.ATTACK and main.deck_manager.hand.size() <= 3:
			var target = main._get_nearest_enemy()
			if target and target.has_method("take_damage"):
				var dist = main.player.position.distance_to(target.position)
				if dist <= 2.0:  # Melee range
					stats.st_lethal_resource_attacking = true
					var dmg = stats.get_effective_physical_damage(0)
					target.take_damage(dmg, true)
					main.add_battle_log("Lethal Resourcefulness: free attack for %d!" % dmg, Color(0.3, 0.7, 1.0))
					stats.st_lethal_resource_attacking = false

func _trigger_skill_tree_stephen_on_disarm_applied(target, value: int) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Disarm Mastery: when applying disarm, apply 1 more
	if stats.has_skill_tree_passive("disarm_mastery") and target and target.has_method("apply_debuff"):
		target.apply_debuff("disarmed", 1)
		main.add_battle_log("Disarm Mastery: +1 disarm", Color(0.3, 0.7, 1.0))

func _trigger_skill_tree_stephen_on_glut(glut_amount: int) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Patience is a Virtue: on receiving Glut, deal that much damage to melee enemy and halve Glut
	if stats.has_skill_tree_passive("patience_is_a_virtue") and glut_amount > 0:
		var target = main._get_nearest_enemy()
		if target and target.has_method("take_damage"):
			var dist = main.player.position.distance_to(target.position)
			if dist <= 2.0:  # Melee range
				target.take_damage(glut_amount, true)
				main.glut_tempo_remaining = max(0, main.glut_tempo_remaining / 2)
				main.add_battle_log("Patience is a Virtue: %d damage, Glut halved!" % glut_amount, Color(0.8, 0.4, 0.9))

func _trigger_skill_tree_stephen_on_dex_proc() -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Dominate: on attack speed proc, gain a 0m/0t basic attack card
	if stats.has_skill_tree_passive("dominate"):
		var free_attack = Card.create_slash()
		free_attack.mana_cost = 0
		free_attack.tempo_cost = 0
		free_attack.card_name = "Dominate Strike"
		free_attack.description = "Free basic attack from Dominate"
		main.deck_manager.hand.append(free_attack)
		main.deck_manager.hand_updated.emit()
		main.add_battle_log("Dominate: free 0m/0t attack card!", Color(0.8, 0.4, 0.9))

# ============================================
# CORY SKILL TREE PASSIVE TRIGGERS
# ============================================

func _trigger_skill_tree_cory_on_mana_gain(amount: int, is_regen: bool) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Energy Barrier: every 3rd non-regen mana gain → put Energy Barrier in hand
	if stats.has_skill_tree_passive("energy_barrier") and not is_regen and amount > 0:
		stats.st_mana_gain_counter += 1
		if stats.st_mana_gain_counter >= 3:
			stats.st_mana_gain_counter = 0
			var barrier = Card.create_energy_barrier()
			main.deck_manager.hand.append(barrier)
			main.deck_manager.hand_updated.emit()
			main.add_battle_log("Energy Barrier: defense card added to hand!", Color(0.9, 0.3, 0.3))

func _trigger_skill_tree_cory_on_card_play(card: Card) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Self Reliance: 3 cards in one tempo cycle → the NEXT card costs -1m.
	# Consume BEFORE tracking this play so the discount earned by the 3rd card
	# never applies to that same 3rd card.
	if stats.st_self_reliance_discount and card.mana_cost > 0:
		stats.gain_mana(1)  # Refund 1 mana as discount
		stats.st_self_reliance_discount = false
		main.add_battle_log("Self Reliance: -1m applied!", Color(0.9, 0.3, 0.3))

	if stats.has_skill_tree_passive("self_reliance"):
		stats.st_cards_this_cycle.append(card.card_type_name)
		if stats.st_cards_this_cycle.size() >= 3 and not stats.st_self_reliance_discount:
			stats.st_self_reliance_discount = true
			main.add_battle_log("Self Reliance: next card costs -1m!", Color(0.9, 0.3, 0.3))

	# Budding: track card types (no back-to-back same type)
	if stats.has_skill_tree_passive("budding"):
		var ctype = ""
		match card.card_type:
			Card.CardType.ATTACK: ctype = "attack"
			Card.CardType.DEFENSE: ctype = "defense"
			Card.CardType.UTILITY: ctype = "utility"

		if ctype != "":
			if ctype == stats.st_budding_last_type:
				# Back-to-back same type — reset tracking
				stats.st_budding_types.clear()
				stats.st_budding_types.append(ctype)
			else:
				if ctype not in stats.st_budding_types:
					stats.st_budding_types.append(ctype)
			stats.st_budding_last_type = ctype

			# Check if all 3 types played
			if stats.st_budding_types.has("attack") and stats.st_budding_types.has("defense") and stats.st_budding_types.has("utility"):
				stats.heal(3)
				stats.add_temp_health(5, 15)
				stats.st_budding_types.clear()
				stats.st_budding_last_type = ""
				main.add_battle_log("Budding: healed 3, +5 temp HP!", Color(0.8, 0.4, 0.9))

func _trigger_skill_tree_cory_on_damage_taken(damage: int) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Expel Negativity: transfer a debuff to an enemy when below 50% HP.
	# 2 charges, refreshed 10 tempo after both are spent; only one charge can
	# trigger per damage event.
	if stats.has_skill_tree_passive("expel_negativity"):
		_expel_try_refresh_charges(stats)
		if stats.st_expel_charges > 0 and stats.get_health_percent() <= 0.5:
			var debuff_mgr = main.player.get_debuff_manager()
			if debuff_mgr and debuff_mgr.debuffs.size() > 0:
				var debuff = debuff_mgr.debuffs[randi() % debuff_mgr.debuffs.size()]
				var target = main._get_nearest_enemy()
				if target and target.has_method("apply_debuff"):
					stats.st_expel_charges -= 1
					target.apply_debuff(debuff.debuff_name.to_lower(), debuff.value)
					debuff_mgr.remove_debuff(debuff.debuff_type)
					main.add_battle_log("Expel Negativity: transferred %s to %s! (%d charge(s) left)" % [debuff.debuff_name, target.enemy_name, stats.st_expel_charges], Color(0.9, 0.3, 0.3))
					if stats.st_expel_charges <= 0:
						stats.st_expel_last_used_tempo = main.tempo_manager.get_global_tempo()

func _expel_try_refresh_charges(stats: PlayerStats) -> void:
	## Refresh Expel Negativity charges if 10 tempo has passed since exhaustion.
	if stats.st_expel_charges <= 0:
		var elapsed = main.tempo_manager.get_global_tempo() - stats.st_expel_last_used_tempo
		if elapsed >= 10:
			stats.st_expel_charges = 2

func _trigger_skill_tree_cory_on_heal() -> void:
	pass  # (Expel Negativity no longer resets on heal — it runs on charges.)

func _trigger_skill_tree_cory_on_attack(card: Card, target) -> int:
	## Returns bonus damage from Cory passives (dealt after the card resolves).
	var stats = main.player.get_stats()
	if not stats:
		return 0
	var bonus = 0

	# Eat: +1% damage for each percentage point the enemy is below 25% health.
	# Judged against the enemy's health BEFORE this hit landed.
	if stats.has_skill_tree_passive("eat") and target is Enemy and is_instance_valid(target) \
			and target.is_alive() and card.last_damage_dealt > 0:
		var pre_health = mini(target.max_health, target.current_health + card.last_damage_dealt)
		var pre_pct = 100.0 * float(pre_health) / float(target.max_health)
		if pre_pct < 25.0:
			var bonus_pct = 25.0 - pre_pct
			bonus += maxi(1, floori(card.last_damage_dealt * bonus_pct / 100.0))
			main.add_battle_log("Eat: +%d%% damage (+%d) on weakened prey!" % [roundi(bonus_pct), bonus], Color(0.3, 0.7, 1.0))

	return bonus

func _trigger_skill_tree_cory_on_kill(enemy: Enemy) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Eat: killing enemies heals 5% of YOUR max HP
	if stats.has_skill_tree_passive("eat"):
		var heal_amount = max(1, floori(stats.max_health * 0.05))
		stats.heal(heal_amount)
		main.add_battle_log("Eat: healed %d HP!" % heal_amount, Color(0.3, 0.7, 1.0))

func _trigger_skill_tree_cory_on_enemy_damaged(enemy: Enemy, damage: int) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Serial Killer: first time enemy drops below 25% HP → player permanently invisible to them
	if stats.has_skill_tree_passive("serial_killer") and enemy.is_alive():
		var enemy_id = enemy.get_instance_id()
		if enemy_id not in stats.st_serial_killer_enemies:
			var hp_pct = float(enemy.current_health) / float(enemy.max_health)
			if hp_pct <= 0.25:
				stats.st_serial_killer_enemies[enemy_id] = true
				# Add player to enemy's ignore list so it never targets them again
				enemy.target = null
				if main.player not in enemy.invisible_to_players:
					enemy.invisible_to_players.append(main.player)
				main.add_battle_log("Serial Killer: invisible to %s!" % enemy.enemy_name, Color(0.3, 0.7, 1.0))

func _trigger_skill_tree_cory_on_debuff_applied(target, debuff_name: String, value: int) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Prey on the Weak: debuff on enemy below 50% HP → deal 3 damage
	if stats.has_skill_tree_passive("prey_on_the_weak") and target and target is Enemy:
		var hp_pct = float(target.current_health) / float(target.max_health)
		if hp_pct < 0.5 and target.has_method("take_damage"):
			target.take_damage(3, true)
			main.add_battle_log("Prey on the Weak: 3 damage to %s!" % target.enemy_name, Color(0.3, 0.7, 1.0))

func _trigger_skill_tree_cory_on_cycle() -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Self Reliance: reset cards-this-cycle counter
	stats.st_cards_this_cycle.clear()

	# Regrowth: tick cooldown
	if stats.st_regrowth_cooldown > 0:
		stats.st_regrowth_cooldown -= 5

	# Death as Lifeblood: heal for each nearby debuffed enemy
	if stats.has_skill_tree_passive("death_as_lifeblood"):
		var nearby = main.enemy_spawner.get_enemies_in_radius(main.player.position, 5.0) if main.enemy_spawner else []
		var debuffed_count = 0
		for enemy in nearby:
			if enemy.has_method("get_active_effects"):
				var effects = enemy.get_active_effects()
				if effects.size() > 0:
					debuffed_count += 1
		if debuffed_count > 0:
			stats.heal(debuffed_count)
			main.add_battle_log("Death as Lifeblood: healed %d HP" % debuffed_count, Color(0.4, 0.9, 0.4))

func _trigger_skill_tree_cory_on_hand_empty() -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Regrowth: draw 4 cards when hand is empty (cooldown 25 tempo)
	if stats.has_skill_tree_passive("regrowth") and stats.st_regrowth_cooldown <= 0:
		stats.st_regrowth_cooldown = 25
		for i in range(4):
			main.deck_manager.attempt_draw()
		main.add_battle_log("Regrowth: drew 4 cards!", Color(0.8, 0.4, 0.9))

func _trigger_skill_tree_cory_on_shuffle() -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Circle of Life: gain 15 armor and +3 damage for 3 attacks
	if stats.has_skill_tree_passive("circle_of_life"):
		stats.add_armor(15)
		var buff_mgr = main.player.get_buff_manager()
		if buff_mgr:
			buff_mgr.apply_buff(Buff.new(Buff.BuffType.STRENGTHEN, 3, -1, 3))
		main.add_battle_log("Circle of Life: +15 armor, +3 damage (3 attacks)!", Color(0.8, 0.4, 0.9))

func _trigger_skill_tree_cory_on_enemy_enter_melee(enemy: Enemy) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Territorial Death: re-apply 1 random existing debuff
	if stats.has_skill_tree_passive("territorial_death") and enemy.has_method("get_active_effects"):
		var effects = enemy.get_active_effects()
		if effects.size() > 0:
			var random_effect = effects[randi() % effects.size()]
			var debuff_name = random_effect.get("name", "").to_lower()
			if debuff_name != "" and enemy.has_method("apply_debuff"):
				enemy.apply_debuff(debuff_name, random_effect.get("stacks", 1))
				main.add_battle_log("Territorial Death: re-applied %s to %s!" % [random_effect.get("name", "?"), enemy.enemy_name], Color(0.4, 0.9, 0.4))

func _trigger_skill_tree_cory_on_enemy_leave_melee(enemy: Enemy) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Territorial Death: re-apply 1 random existing debuff when enemy leaves melee range
	if stats.has_skill_tree_passive("territorial_death") and enemy.has_method("get_active_effects"):
		var effects = enemy.get_active_effects()
		if effects.size() > 0:
			var random_effect = effects[randi() % effects.size()]
			var debuff_name = random_effect.get("name", "").to_lower()
			if debuff_name != "" and enemy.has_method("apply_debuff"):
				enemy.apply_debuff(debuff_name, random_effect.get("stacks", 1))
				main.add_battle_log("Territorial Death: re-applied %s to %s (leaving)!" % [random_effect.get("name", "?"), enemy.enemy_name], Color(0.4, 0.9, 0.4))

# ============================================
# JEREMY SKILL TREE PASSIVE TRIGGERS
# ============================================

func _trigger_skill_tree_jeremy_on_card_play(card: Card, target) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Arcane Overflow: consume discount if active, then check if we hit 0 mana for next spell
	if stats.has_skill_tree_passive("arcane_overflow"):
		# Apply stored discount from previous spell
		if stats.st_arcane_overflow_discount and card.card_type == Card.CardType.UTILITY and card.mana_cost > 0:
			# Discount was already applied at card play time via _get_arcane_overflow_discount()
			stats.st_arcane_overflow_discount = false
			main.add_battle_log("Arcane Overflow: -1 tempo!", Color(0.9, 0.3, 0.3))
		# Check if casting this spell left us at 0 mana → prime next spell
		if card.card_type == Card.CardType.UTILITY and card.mana_cost > 0 and stats.current_mana == 0:
			stats.st_arcane_overflow_discount = true
			main.add_battle_log("Arcane Overflow: 0 mana! Next spell -1 tempo", Color(0.9, 0.3, 0.3))

	# Mana Surge: track mana spending, 10 mana in 5 tempo → add Mana Surge card
	if stats.has_skill_tree_passive("mana_surge") and card.mana_cost > 0:
		var current_tempo = main.tempo_manager.global_tempo
		stats.st_mana_spent_window.append({"amount": card.mana_cost, "tempo": current_tempo})
		# Purge entries older than 5 tempo
		var fresh: Array = []
		for entry in stats.st_mana_spent_window:
			if current_tempo - entry["tempo"] <= 5:
				fresh.append(entry)
		stats.st_mana_spent_window = fresh
		# Check total
		var total_spent = 0
		for entry in stats.st_mana_spent_window:
			total_spent += entry["amount"]
		if total_spent >= 10:
			stats.st_mana_spent_window.clear()
			var surge = Card.create_mana_surge()
			main.deck_manager.add_card_to_hand(surge)
			main.add_battle_log("Mana Surge: card added to hand!", Color(0.9, 0.3, 0.3))

	# Fresh Start: playing a card that empties hand → cleanse a debuff
	if stats.has_skill_tree_passive("fresh_start") and main.deck_manager.hand.is_empty():
		var debuff_mgr = main.player.get_debuff_manager()
		if debuff_mgr and debuff_mgr.debuffs.size() > 0:
			var removed = debuff_mgr.debuffs[0]
			debuff_mgr.remove_debuff(removed.debuff_type)
			main.add_battle_log("Fresh Start: cleansed %s!" % removed.debuff_name, Color(0.8, 0.4, 0.9))

	# Seance: casting a spell that targets an empty tile → summon a Specter
	if stats.has_skill_tree_passive("seance") and card.card_type == Card.CardType.UTILITY and card.mana_cost > 0:
		# Check if the spell targeted an empty tile (no enemy target)
		if target == null or not (target is Enemy):
			var spawn_pos = main.player.position + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
			if main.grid_manager:
				spawn_pos = main.grid_manager.snap_to_grid(spawn_pos)
			_spawn_seance_specter(stats, spawn_pos)

func _spawn_seance_specter(stats: PlayerStats, pos: Vector3) -> void:
	## Spawns a Specter for Seance passive: 5 HP, 15 tempo, deals 4 damage to killer on death.
	var marker = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.4, 0.8, 0.4)
	marker.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.3, 0.7, 0.7)  # Ghostly purple
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker.material_override = mat
	marker.position = Vector3(pos.x, 0.4, pos.z)
	add_child(marker)

	var label = Label3D.new()
	label.text = "Specter (5 HP)"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 12
	label.modulate = Color(0.7, 0.5, 1.0)
	label.position = Vector3(0, 0.7, 0)
	marker.add_child(label)

	stats.st_seance_specters.append({
		"node": marker,
		"label": label,
		"hp": 5,
		"max_hp": 5,
		"tempo_remaining": 15,
		"position": pos,
	})
	main.add_battle_log("Seance: Specter summoned! (5 HP, 15 tempo)", Color(0.7, 0.5, 1.0))

func _tick_seance_specters(stats: PlayerStats) -> void:
	## Tick Seance specters: decrement tempo, remove expired ones.
	var to_remove: Array = []
	for specter in stats.st_seance_specters:
		specter["tempo_remaining"] -= 5
		if specter["tempo_remaining"] <= 0 or specter["hp"] <= 0:
			to_remove.append(specter)
		else:
			# Update label
			var label = specter.get("label")
			if label and is_instance_valid(label):
				label.text = "Specter (%d HP)" % specter["hp"]

	for specter in to_remove:
		# On death/expiry: deal 4 damage to nearest enemy
		if specter["hp"] <= 0:
			var enemies = main.enemy_spawner.get_living_enemies() if main.enemy_spawner else []
			if enemies.size() > 0:
				var nearest: Enemy = null
				var nearest_dist = 999.0
				for e in enemies:
					var d = (e.position - specter["position"]).length()
					if d < nearest_dist:
						nearest_dist = d
						nearest = e
				if nearest:
					nearest.take_damage(4, true)
					main.add_battle_log("Seance: Specter destroyed! 4 damage to %s!" % nearest.enemy_name, Color(0.7, 0.5, 1.0))
		# Remove the visual marker
		var node = specter.get("node")
		if node and is_instance_valid(node):
			node.queue_free()
		stats.st_seance_specters.erase(specter)

func _trigger_skill_tree_jeremy_on_cycle() -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Whispers of the Flock: tick mark duration and cooldown
	if stats.st_whispers_active:
		stats.st_whispers_tempo -= 5
		if stats.st_whispers_tempo <= 0:
			stats.st_whispers_active = false
			# Mark expired without triggering — no penalty
			main.add_battle_log("Whispers of the Flock: mark expired.", Color(0.3, 0.7, 1.0))
			stats.st_whispers_cooldown = 20
	if stats.st_whispers_cooldown > 0:
		stats.st_whispers_cooldown -= 5

	# Haunted Rebuke: tick cooldown
	if stats.st_haunted_rebuke_cooldown > 0:
		stats.st_haunted_rebuke_cooldown -= 5

	# I Heal You: heal nearby allies 3 HP every 5 tempo — covers both summoned
	# specters (Seance) and a co-op partner standing within 3 tiles.
	if stats.has_skill_tree_passive("i_heal_you"):
		stats.st_i_heal_you_tempo += 5
		if stats.st_i_heal_you_tempo >= 5:
			stats.st_i_heal_you_tempo = 0
			var healed_any = false
			for specter in stats.st_seance_specters:
				if specter.get("hp", 0) > 0:
					var max_hp = specter.get("max_hp", 5)
					specter["hp"] = min(max_hp, specter["hp"] + 3)
					healed_any = true
			# Co-op partner: whichever player node isn't the passive's owner.
			var partner = main._p2_player if main.player == main._p1_player else main._p1_player
			if partner == main.player:
				partner = null
			if partner and is_instance_valid(partner) and partner.has_method("get_stats"):
				var p_stats = partner.get_stats()
				var diff = partner.position - main.player.position
				if p_stats and p_stats.current_health > 0 and Vector3(diff.x, 0, diff.z).length() <= 3.0:
					p_stats.heal(3)
					healed_any = true
			if healed_any:
				main.add_battle_log("I Heal You: healed allies 3 HP", Color(0.3, 0.7, 1.0))

	# Kinetic Armor: track armor retention, apply shock after 25 tempo
	if stats.has_skill_tree_passive("kinetic_armor"):
		if stats.current_armor > 0:
			stats.st_kinetic_armor_tempo += 5
			if stats.st_kinetic_armor_tempo >= 25 and not stats.st_kinetic_armor_triggered:
				stats.st_kinetic_armor_triggered = true
				# Count defense cards across entire deck
				var defense_count = 0
				for c in main.deck_manager.hand:
					if c.card_type == Card.CardType.DEFENSE:
						defense_count += 1
				for c in main.deck_manager.draw_pile:
					if c.card_type == Card.CardType.DEFENSE:
						defense_count += 1
				for c in main.deck_manager.discard_pile:
					if c.card_type == Card.CardType.DEFENSE:
						defense_count += 1
				if defense_count > 0:
					var enemies = main.enemy_spawner.get_living_enemies()
					if enemies.size() > 0:
						var nearest_enemy: Enemy = null
						var nearest_dist = 999.0
						for e in enemies:
							var d = (e.position - main.player.position).length()
							if d < nearest_dist:
								nearest_dist = d
								nearest_enemy = e
						if nearest_enemy and nearest_enemy.has_method("apply_debuff"):
							nearest_enemy.apply_debuff("shock", defense_count)
							main.add_battle_log("Kinetic Armor: %d shock to %s!" % [defense_count, nearest_enemy.enemy_name], Color(0.8, 0.4, 0.9))
		else:
			# Armor gone — reset tracking
			stats.st_kinetic_armor_tempo = 0
			stats.st_kinetic_armor_triggered = false

	# Seance: tick specter durations
	if stats.st_seance_specters.size() > 0:
		_tick_seance_specters(stats)

func _trigger_skill_tree_jeremy_on_enemy_attacked(enemy: Enemy) -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Haunted Rebuke: when an enemy attacks you, 3+ defense cards in hand → slow enemy's next action by +3 tempo
	if stats.has_skill_tree_passive("haunted_rebuke") and stats.st_haunted_rebuke_cooldown <= 0:
		var defense_in_hand = 0
		for card in main.deck_manager.hand:
			if card.card_type == Card.CardType.DEFENSE:
				defense_in_hand += 1
		if defense_in_hand >= 3:
			stats.st_haunted_rebuke_cooldown = 10
			# Slow the enemy's next action by adding to their action tempo counter
			if enemy.has_method("apply_debuff"):
				enemy.apply_debuff("slow", 3)
			main.add_battle_log("Haunted Rebuke: %s slowed by 3 tempo!" % enemy.enemy_name, Color(0.4, 0.9, 0.4))

func _trigger_skill_tree_jeremy_on_rng_reroll() -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# A Mage's Favor: RNG reroll changed outcome → Magic Barrier to hand (once per batch)
	if stats.has_skill_tree_passive("a_mage's_favor"):
		var barrier = Card.create_magic_barrier()
		main.deck_manager.add_card_to_hand(barrier)
		main.add_battle_log("A Mage's Favor: Magic Barrier added!", Color(0.8, 0.4, 0.9))

func _trigger_skill_tree_jeremy_on_heal_ally() -> void:
	var stats = main.player.get_stats()
	if not stats:
		return

	# Whispers of the Flock: add Shepherd's Mark card to hand when healing an ally
	if stats.has_skill_tree_passive("whispers_of_the_flock") and not stats.st_whispers_active and stats.st_whispers_cooldown <= 0:
		# Don't generate if already holding one
		var already_holding = false
		for c in main.deck_manager.hand:
			if c.card_id == "shepherds_mark":
				already_holding = true
				break
		if not already_holding:
			var mark_card = Card.create_shepherds_mark()
			main.deck_manager.add_card_to_hand(mark_card)
			main.add_battle_log("Whispers of the Flock: Shepherd's Mark added to hand!", Color(0.3, 0.7, 1.0))

func _get_jeremy_harnessed_power_multiplier() -> float:
	## Returns the Harnessed Power effectiveness multiplier (1.0 = no bonus)
	var stats = main.player.get_stats()
	if not stats:
		return 1.0
	if stats.has_skill_tree_passive("harnessed_power") and main.deck_manager.hand.size() <= 2:
		return 1.3
	return 1.0

func _apply_all_constellation_bonuses() -> void:
	## Re-applies all completed constellation bonuses (called after character select).
	var grid = main.sphere_grid_ui.sphere_grid
	if not grid:
		return
	for c in grid.get_all_constellations():
		if c.completed and c.id not in _active_constellations:
			_active_constellations.append(c.id)
			_apply_constellation_bonus(c.id)

func _trigger_sphere_passives(trigger: String, context: Dictionary = {}) -> void:
	## Fires all sphere grid passives matching the trigger.
	## context may contain: "target" (enemy), "card" (Card), "damage" (int), etc.
	var stats = main.player.get_stats()
	if not stats:
		return

	var passives = stats.get_sphere_grid_passives_for_trigger(trigger)
	for passive in passives:
		# Roll chance
		var chance = passive.get("chance", 1.0)
		if chance < 1.0 and randf() > chance:
			continue

		var value = passive.get("value", 0)
		var effect = passive.get("effect", "")

		match effect:
			"heal":
				if value > 0:
					stats.heal(value)
					main.add_battle_log("Passive: Healed %d HP" % value, Color(0.5, 1.0, 0.5))
			"draw_card":
				if value <= 0:
					value = 1
				for i in range(value):
					main.deck_manager.attempt_draw()
				main.add_battle_log("Passive: Drew %d card(s)" % value, Color(0.3, 0.8, 1.0))
			"gain_armor":
				if value > 0:
					stats.add_armor(value)
					main.add_battle_log("Passive: Gained %d armor" % value, Color(0.6, 0.6, 0.8))
			"regen_mana", "gain_mana":
				if value > 0:
					stats.gain_mana(value)
					main.add_battle_log("Passive: Gained %d mana" % value, Color(0.2, 0.5, 1.0))
			"apply_bleed":
				# Enemies have no bleed track; use poison as the equivalent DoT.
				var target = context.get("target", null)
				if target and target.has_method("apply_debuff"):
					target.apply_debuff("poison", value if value > 0 else 2)
					main.add_battle_log("Passive: Applied bleed (poison)", Color(0.9, 0.3, 0.3))
			"gain_tempo":
				if value > 0:
					main.tempo_manager.add_tempo(-value)  # Negative tempo = gain turns
					main.add_battle_log("Passive: Gained %d tempo" % value, Color(0.9, 0.85, 0.2))
			"cleanse_debuff":
				if main.player.has_method("get_debuff_manager"):
					var dbm = main.player.get_debuff_manager()
					if dbm and dbm.debuffs.size() > 0:
						dbm.remove_debuff(dbm.debuffs[randi() % dbm.debuffs.size()].debuff_type)
						main.add_battle_log("Passive: Cleansed a debuff", Color(0.5, 1.0, 0.8))
			"reflect_damage":
				var target = context.get("target", null)
				if target and value > 0 and target.has_method("take_damage"):
					target.take_damage(value)
					main.add_battle_log("Passive: Reflected %d damage" % value, Color(1.0, 0.5, 0.2))
			"deal_damage":
				# Deal damage to a random enemy or specified target
				var target = context.get("target", null)
				if not target:
					var enemies = main.enemy_spawner.get_living_enemies() if main.enemy_spawner else []
					if enemies.size() > 0:
						target = enemies[randi() % enemies.size()]
				if target and value > 0 and target.has_method("take_damage"):
					target.take_damage(value)
					main.add_battle_log("Passive: Dealt %d damage" % value, Color(1.0, 0.4, 0.4))
			"stun_enemy":
				var target = context.get("target", null)
				if target and target.has_method("apply_stun"):
					target.apply_stun()
					main.add_battle_log("Passive: Stunned enemy", Color(1.0, 1.0, 0.3))
			"gain_haste":
				if main.player.has_method("get_buff_manager"):
					var bm = main.player.get_buff_manager()
					if bm and bm.has_method("apply_buff"):
						bm.apply_buff(Buff.create_haste(5))
						main.add_battle_log("Passive: Gained haste", Color(0.3, 1.0, 0.5))
			"gain_empower":
				stats.apply_empower(1)
				main.add_battle_log("Passive: Gained empower", Color(1.0, 0.8, 0.3))
			"refund_mana":
				var card = context.get("card", null)
				if card:
					stats.gain_mana(card.mana_cost)
					main.add_battle_log("Passive: Refunded %d mana" % card.mana_cost, Color(0.2, 0.5, 1.0))
			"return_to_hand":
				var card = context.get("card", null)
				if card:
					# Move from discard back to hand
					var idx = main.deck_manager.discard_pile.find(card)
					if idx >= 0:
						main.deck_manager.discard_pile.remove_at(idx)
						main.deck_manager.add_card_to_hand(card)
						main.add_battle_log("Passive: %s returned to hand" % card.card_name, Color(0.7, 0.7, 1.0))
			"reduce_cost":
				# Reduce next card cost by value
				if value > 0:
					main.deck_manager.prep_utility_discount = value
					main.deck_manager.prep_utility_charges = 1
					main.add_battle_log("Passive: Next card costs %d less" % value, Color(0.8, 0.8, 0.3))
			"bonus_damage":
				# "Deal X% bonus" (on-crit nodes): follow up with X% of the hit
				# as extra damage, same shape as Shadow Strike.
				var bd_card = context.get("card", null)
				var bd_t = context.get("target", null)
				if bd_t and is_instance_valid(bd_t) and bd_t.has_method("take_damage"):
					var bd_base = bd_card.last_damage_dealt if bd_card and bd_card.last_damage_dealt > 0 else stats.get_effective_physical_damage(0)
					var bd_bonus = max(1, floori(bd_base * value / 100.0))
					bd_t.take_damage(bd_bonus, true)
					main.add_battle_log("Passive: +%d bonus damage" % bd_bonus, Color(1.0, 0.6, 0.2))
			"counterattack":
				var target = context.get("target", null)
				if target and target.has_method("take_damage"):
					var dmg = stats.get_effective_physical_damage(5)
					target.take_damage(dmg)
					main.add_battle_log("Passive: Counterattack for %d" % dmg, Color(1.0, 0.5, 0.2))
			"overheal_armor":
				# Convert overheal to armor. value is the conversion percent
				# (0 = unspecified = 100%; the upgraded node says 200%).
				var overheal = context.get("overheal", 0)
				if overheal > 0:
					var oh_pct = value if value > 0 else 100
					var oh_armor = max(1, floori(overheal * oh_pct / 100.0))
					stats.add_armor(oh_armor)
					main.add_battle_log("Passive: Overheal → %d armor" % oh_armor, Color(0.6, 0.8, 1.0))
			"free_draw":
				# Next drawn card costs 0 — apply via prep system
				main.deck_manager.prep_utility_discount = 99
				main.deck_manager.prep_utility_charges = 1
				main.add_battle_log("Passive: Next card costs 0", Color(0.8, 0.8, 0.3))
			"iron_will":
				# Constellation: On kill: gain 3 armor and heal 2 HP
				stats.add_armor(3)
				stats.heal(2)
				main.add_battle_log("Iron Will: +3 armor, healed 2 HP", Color(0.9, 0.45, 0.25))
			"blood_hunter":
				# Constellation: 15% chance to apply bleed on attack
				var target = context.get("target", null)
				if target and target.has_method("apply_debuff"):
					target.apply_debuff("poison", 4)  # Bleed equivalent (enemies use poison)
					main.add_battle_log("Blood Hunter: Applied enhanced bleed!", Color(0.75, 0.15, 0.15))
			"arcane_current":
				# Constellation: +5 spell damage — applied as bonus damage on the card
				var card = context.get("card", null)
				if card:
					card.bonus_damage += 5
					main.add_battle_log("Arcane Current: +5 spell damage", Color(0.5, 0.2, 0.85))
			"unyielding":
				# Constellation: Below 50% HP: gain 3 armor each cycle
				if stats.get_health_percent() <= 0.5:
					stats.add_armor(value)
					main.add_battle_log("Unyielding: +%d armor (low HP)" % value, Color(0.85, 0.7, 0.2))
			"crimson_edge":
				# Attacks heal for value% of the damage just dealt.
				var ce_card = context.get("card", null)
				if ce_card and ce_card.last_damage_dealt > 0:
					var ce_heal = max(1, floori(ce_card.last_damage_dealt * value / 100.0))
					stats.apply_life_steal(ce_heal)
					main.add_battle_log("Crimson Edge: lifesteal %d" % ce_heal, Color(0.8, 0.1, 0.2))
			"freeze_enemy":
				# Deep chill: 5 cold stacks freeze the struck enemy outright.
				var fz = context.get("target", null)
				if fz and is_instance_valid(fz) and fz.has_method("apply_debuff"):
					fz.apply_debuff("cold", 5)
					main.add_battle_log("Deep chill: enemy frozen!", Color(0.5, 0.8, 1.0))
			"shadow_strike":
				# Crits hit harder — add 50% of the crit damage to the target.
				var ss_card = context.get("card", null)
				var ss_t = context.get("target", null)
				if ss_t and ss_t.has_method("take_damage"):
					var ss_bonus = floori(ss_card.last_damage_dealt / 3.0) if ss_card and ss_card.last_damage_dealt > 0 else 5
					ss_t.take_damage(max(1, ss_bonus), true)
					main.add_battle_log("Shadow Strike: +%d crit damage" % max(1, ss_bonus), Color(0.4, 0.2, 0.6))
			"double_cast":
				# Re-deal the spell's damage to its target (chance already rolled).
				var dc_card = context.get("card", null)
				var dc_t = context.get("target", null)
				if dc_card and dc_t and dc_card.last_damage_dealt > 0 and dc_t.has_method("take_damage"):
					dc_t.take_damage(dc_card.last_damage_dealt, true)
					main.add_battle_log("Double Cast!", Color(0.6, 0.3, 0.9))
			"enemy_armor_reduce":
				if main.enemy_spawner:
					for en in main.enemy_spawner.get_living_enemies():
						en.current_armor = max(0, en.current_armor - value)
					main.add_battle_log("Passive: all enemies -%d armor" % value, Color(0.7, 0.7, 0.8))
			"aoe_damage":
				if main.enemy_spawner:
					for en in main.enemy_spawner.get_living_enemies():
						en.take_damage(value, true)
					main.add_battle_log("Passive: %d damage to all enemies" % value, Color(1.0, 0.4, 0.4))
			_:
				print("[MAIN] Unhandled sphere passive effect: %s" % effect)
		# Secondary "and N mana" rider parsed alongside the primary effect.
		var mana_bonus = passive.get("mana_bonus", 0)
		if mana_bonus > 0:
			stats.gain_mana(mana_bonus)

