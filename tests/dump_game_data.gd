extends SceneTree

## Dumps all card data, skill trees, and character info to /tmp/game_data.json
## for spreadsheet export. Run:
##   godot --headless --path . --script tests/dump_game_data.gd

func _initialize() -> void:
	var data := {
		"cards": _dump_cards(),
		"skill_trees": _dump_skill_trees(),
		"characters": _dump_characters(),
	}
	var f = FileAccess.open("/tmp/game_data.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	print("DUMP COMPLETE: %d cards, %d trees" % [data["cards"].size(), data["skill_trees"].size()])
	quit(0)

func _dump_cards() -> Array:
	var type_names = ["Attack", "Defense", "Utility", "Reaction", "Unplayable", "Power", "Enchantment"]
	var cards: Array = []
	var card_script: Script = Card
	for method in card_script.get_script_method_list():
		var method_name: String = method["name"]
		if not method_name.begins_with("create_") or method["args"].size() != 0:
			continue
		var card = card_script.call(method_name)
		if not (card is Card):
			continue
		var type_idx = card.card_type as int
		cards.append({
			"factory": method_name,
			"card_id": card.card_id,
			"card_name": card.card_name,
			"description": card.description,
			"type": type_names[type_idx] if type_idx < type_names.size() else "Unknown",
			"mana_cost": card.mana_cost,
			"tempo_cost": card.tempo_cost,
			"damage": card.damage,
			"block": card.block,
			"heal_amount": card.heal_amount,
			"is_aoe": card.is_aoe,
			"is_ranged": card.is_ranged,
			"target_types": card.target_types,
			"has_on_draw": card.has_on_draw,
			"on_draw_effect": card.on_draw_effect,
			"maintain_cost": card.maintain_cost,
			"sticky": card.sticky,
			"erase_tempo": card.erase_tempo,
			"in_hand_buff": card.in_hand_buff,
			"requires_high_ground": card.requires_high_ground,
		})
	return cards

func _dump_skill_trees() -> Dictionary:
	var trees := {
		"Brad": SkillTreeData.create_brad_tree(),
		"Stephen": SkillTreeData.create_stephen_tree(),
		"Ryan": SkillTreeData.create_ryan_tree(),
		"Cory": SkillTreeData.create_cory_tree(),
		"Jeremy": SkillTreeData.create_jeremy_tree(),
	}
	var out := {}
	for char_name in trees:
		var tree: SkillTreeData = trees[char_name]
		var rows: Array = []
		for row in tree.rows:
			for opt in row.options:
				# Skip unfilled placeholder slots
				if opt.description.begins_with("Placeholder"):
					continue
				rows.append({
					"level": row.level,
					"type": opt.get_type_label(),
					"name": opt.name,
					"description": opt.description,
					"card_id": opt.card_id,
					"passive_id": opt.passive_id,
				})
		out[char_name] = rows
	return out

func _dump_characters() -> Array:
	var chars: Array = []
	for data in CharacterData.get_all_characters():
		var archetypes: Array = []
		for arch in data.archetypes:
			archetypes.append({"name": arch.get("name", ""), "description": arch.get("description", "")})
		chars.append({
			"name": data.character_name,
			"starting_card_ids": data.starting_card_ids,
			"passive_description": data.passive_description,
			"starting_item_name": data.starting_item_name,
			"starting_item_description": data.starting_item_description,
			"archetypes": archetypes,
		})
	return chars
