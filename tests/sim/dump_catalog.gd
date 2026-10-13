extends SceneTree

## Dumps the roster, the card list and the item list the sweep generator
## needs (tools/sim_analysis/gen_sweeps.py) to sim_out/catalog.json.
## Run: godot --headless --path . --script tests/sim/dump_catalog.gd [-- --out=path]

const EnemyScene = preload("res://scenes/battle/enemy.tscn")

func _initialize() -> void:
	var out_path := "sim_out/catalog.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.substr(6)
	var holder := Node3D.new()
	get_root().add_child(holder)
	var dm := DeckManager.new()
	holder.add_child(dm)

	# Roster: one instantiated enemy per type, the way the game makes them.
	var roster: Array = []
	for type_name in Enemy.EnemyType.keys():
		var t: int = Enemy.EnemyType[type_name]
		var e: Enemy = EnemyScene.instantiate()
		holder.add_child(e)
		e.initialize(t)
		var actions: Array = []
		for a in Enemy.actions_for_type(t):
			actions.append({"name": str(a.get("name", "")), "tempo_cost": int(a.get("tempo_cost", 0))})
		roster.append({
			"type": type_name,
			"name": e.enemy_name,
			"max_health": e.max_health,
			"max_armor": e.max_armor,
			"attack_damage": e.attack_damage,
			"attack_range": e.attack_range,
			"aggro_range": e.aggro_range,
			"xp_reward": e.xp_reward,
			"intended_level": e.get_intended_level(),
			"is_structure": e.is_structure,
			"is_training_dummy": e.is_training_dummy,
			"has_actions": not actions.is_empty(),
			"actions": actions,
		})
		e.queue_free()

	# Cards: every factory the deck manager can rebuild from an id.
	var cards: Array = []
	dm._build_card_factory_map()
	var ids: Array = dm._card_factory_map.keys()
	ids.sort()
	for id in ids:
		var c: Card = dm._create_card_from_id(id)
		if c == null:
			continue
		cards.append({
			"id": c.card_id,
			"name": c.card_name,
			"type": Card.CardType.keys()[c.card_type],
			"school": Card.CardSchool.keys()[c.school],
			"rarity": c.get_rarity_name(),
			"mana": c.mana_cost,
			"tempo": c.tempo_cost,
			"damage": c.base_damage,
			"block": c.base_block if c.base_block > 0 else c.block,
			"heal": c.heal_amount,
			"is_ranged": c.is_ranged,
			"is_aoe": c.is_aoe,
			"target_types": c.target_types,
			"keywords": c.keywords,
			"requires_engraving": c.requires_engraving,
			"shop_excluded": c.shop_excluded,
			"reaction_trigger": c.reaction_trigger,
			"slot_labels": c.slot_labels.map(func(k): return Card.keyword_name(int(k))),
			"slottable": c.is_slottable(),
			"description": c.description,
		})

	# Items: every zero-argument factory, keyed by its create_<id> name.
	var items: Array = []
	var script: Script = ItemData
	var names: Array = []
	for method in script.get_script_method_list():
		var mn: String = method["name"]
		if mn.begins_with("create_") and method["args"].size() == 0:
			names.append(mn)
	names.sort()
	for mn in names:
		var it = script.call(mn)
		if not (it is ItemData):
			continue
		items.append({
			"id": mn.substr(7),
			"name": it.item_name,
			"type": ItemData.ItemType.keys()[it.item_type],
			"rarity": ItemData.Rarity.keys()[it.rarity],
			"weight": it.weight,
			"card_slots": it.card_slots,
			"granted_card_ids": it.granted_card_ids,
			"weapon_subtype": ItemData.WeaponSubtype.keys()[it.weapon_subtype] if it.item_type == ItemData.ItemType.WEAPON else "",
			"two_handed": Inventory.is_two_hand_only(it) if it.item_type in [ItemData.ItemType.WEAPON, ItemData.ItemType.QUIVER] else false,
		})

	# Sphere grid: every node with its gate, keystone and neighbours.
	var grid := SphereGrid.new()
	var nodes: Array = []
	for n in grid.get_all_nodes():
		nodes.append({"id": n.id, "type": SphereGrid.NodeType.keys()[n.node_type], "label": n.label,
			"description": n.description, "ring": n.ring, "requirements": n.requirements,
			"keystone": n.keystone_id, "connections": n.connections})
	var constellations: Array = []
	for c in grid.get_all_constellations():
		constellations.append({"id": c.id, "name": c.name, "nodes": c.node_ids, "bonus": c.bonus_name, "bonus_description": c.bonus_description})
	var catalog := {"roster": roster, "cards": cards, "items": items,
		"basic_deck": DeckManager.BASIC_DECK_IDS, "sphere_nodes": nodes, "constellations": constellations,
		"builds": CharacterBuilds.all_components()}
	var abs_path := out_path if out_path.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(out_path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(catalog, "\t"))
	f.close()
	printerr("[SIM] catalog: %d enemy types, %d cards, %d items -> %s" % [roster.size(), cards.size(), items.size(), abs_path])
	quit(0)
