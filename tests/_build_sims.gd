extends SceneTree

## Scratch build simulator for the cross-item balance review — not a test.
## Levels each character to 18 (7 tree passives, 51 allocatable stat points),
## allocates stats per build, equips a full loadout through the REAL inventory
## rules (carry gate, mythic limit, slot counts), and prints the outcome.
## Run: godot --headless --path . --script tests/_build_sims.gd

const LEVEL := 18

func _char_data(cname: String) -> CharacterData:
	match cname:
		"Ryan": return CharacterData.create_ryan()
		"Jeremy": return CharacterData.create_jeremy()
		"Stephen": return CharacterData.create_stephen()
		"Cory": return CharacterData.create_cory()
		"Brad": return CharacterData.create_brad()
	return null

func _simulate(build: Dictionary) -> void:
	print("\n================ %s — %s ================" % [build["who"], build["name"]])
	var stats = PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(_char_data(build["who"]))
	# Level to 18 the honest way (XP loop would need the curve; set directly).
	for _i in range(LEVEL - 1):
		stats._level_up()
	if not stats.apply_stat_allocation(build["alloc"]):
		print("  !! stat allocation refused: %s" % str(build["alloc"]))
	for pid in build["passives"]:
		stats.add_skill_tree_passive(pid)
	var inv = Inventory.new()
	get_root().add_child(inv)
	inv.initialize(build["who"])
	inv.connect_player_stats(stats)
	var equipped: Array[String] = []
	var failed: Array[String] = []
	var item_script: Script = ItemData
	for entry in build["gear"]:
		var item: ItemData = item_script.call("create_%s" % entry[0])
		var ok: bool = inv.equip_item(item, entry[1] if entry.size() > 1 else 0)
		if ok:
			equipped.append(item.item_name)
		else:
			failed.append("%s (w%d)" % [item.item_name, item.weight])
	print("  EQUIPPED: %s" % ", ".join(equipped))
	if not failed.is_empty():
		print("  REFUSED:  %s" % ", ".join(failed))
	var slots_total := 0
	var granted: Array[String] = []
	for arrs in [inv.equipped_helms, inv.equipped_chests, inv.equipped_belts,
			inv.equipped_boots, inv.equipped_gauntlets, inv.equipped_weapons]:
		for it in arrs:
			if it:
				slots_total += it.card_slots
				for cid in it.granted_card_ids:
					granted.append(cid)
	print("  STATS: STR %d DEX %d INT %d WIS %d DET %d AGI %d" % [stats.strength,
		stats.dexterity, stats.intelligence, stats.wisdom, stats.determination, stats.agility])
	print("  HP %d | Mana %d (+%.0f regen) | Hand %d | Crit dmg x%.2f | Carry %d/%d" % [
		stats.max_health, stats.max_mana, stats.get_effective_mana_regen() if stats.has_method("get_effective_mana_regen") else 0.0,
		stats.hand_size, stats.get_crit_damage_multiplier(), stats.current_carry_load, stats.get_carry_capacity()])
	print("  Card slots on gear: %d | Granted cards: %s" % [slots_total, ", ".join(granted) if granted.size() > 0 else "none"])
	print("  Passives: %s" % ", ".join(build["passives"]))
	stats.free()
	inv.free()

func _initialize() -> void:
	var builds: Array = [
		{"who": "Brad", "name": "TANK — Immovable Warden (Adimantium fortress)",
			"alloc": {"strength": 34, "determination": 9, "wisdom": 8},
			"passives": ["in_the_trenches", "the_way_of_the_plate", "pristine_armor",
				"stone_skin", "ancestral_aid", "vines_codependence", "solemn_independence"],
			"gear": [["adimantium"], ["thick_steel_helm"], ["strap_of_stone"],
				["steel_boots"], ["copper_bracers"]]},
		{"who": "Brad", "name": "DPS — Deathwish Berserker (Mind Mend fuels Directed Strength)",
			"alloc": {"strength": 30, "determination": 15, "agility": 6},
			"passives": ["enraged_will", "directed_strength", "life_steal",
				"point_to_prove", "redemption", "stone_skin", "vines_codependence"],
			"gear": [["hallowed_trunk"], ["trench_of_tranquility"], ["dragon_skull"],
				["equator"], ["knife_toed_boots"]]},
		{"who": "Ryan", "name": "ASSASSIN — Three-Veil Shadow (stacked invisibility)",
			"alloc": {"agility": 20, "dexterity": 25, "strength": 6},
			"passives": ["now_you_see_me", "surprise_opener", "eye_scrape",
				"ladder_work", "lets_dance", "quick_step", "keep_them_guessing"],
			"gear": [["concealed_carry"], ["shadow_cowl"], ["shadow_obi"],
				["houdinis_slippers"], ["feathered_hat"], ["assasian_belt", 1]]},
		{"who": "Ryan", "name": "SUPPORT — Double-Belt Apothecary (potions + cleanse)",
			"alloc": {"wisdom": 20, "intelligence": 15, "dexterity": 16},
			"passives": ["stimulant", "pop_rocks", "mad_scientist",
				"keep_them_guessing", "from_the_hip", "quick_step", "nimble_assault"],
			"gear": [["potion_belt"], ["corset_of_cure", 1], ["shamans_mask"],
				["trench_of_tranquility"], ["caster_boots"], ["medic_wraps"]]},
		{"who": "Ryan", "name": "COMBO — Card Shark (Headbandz mass-discard engine)",
			"alloc": {"dexterity": 21, "agility": 15, "wisdom": 15},
			"passives": ["keep_them_guessing", "from_the_hip", "nimble_assault",
				"ladder_work", "quick_step", "stimulant", "surprise_opener"],
			"gear": [["the_headbandz"], ["the_slotted_sash"], ["shadow_cowl"],
				["boot_holsters"], ["spidey_web_shooters"]]},
		{"who": "Jeremy", "name": "MAGE — Scroll Evoker (Belt of Scrolls battery)",
			"alloc": {"intelligence": 30, "wisdom": 21},
			"passives": ["arcane_overflow", "harnessed_power", "mana_surge",
				"tricks_of_death", "seance", "a_mages_favor", "fresh_start"],
			"gear": [["belt_of_scrolls"], ["blue_robe"], ["wizard_hat"],
				["caster_boots"], ["techno_wraps"]]},
		{"who": "Jeremy", "name": "SUPPORT — Shepherd of the Flock (aura + Sanguine loop)",
			"alloc": {"wisdom": 24, "intelligence": 15, "determination": 12},
			"passives": ["i_heal_you", "whispers_of_the_flock", "blood_libation",
				"fresh_start", "a_mages_favor", "kinetic_armor", "tricks_of_death"],
			"gear": [["guardian_greaves"], ["trench_of_tranquility"], ["shamans_mask"],
				["corset_of_cure"], ["medic_wraps"]]},
		{"who": "Stephen", "name": "DPS — Longshot Ranger (range stacking + casings)",
			"alloc": {"dexterity": 30, "agility": 15, "strength": 6},
			"passives": ["eagle_eye", "scouted", "laced_arrow", "deadly",
				"clean_exchange", "skilled_momentum", "dominate"],
			"gear": [["jordan_1s"], ["chewbaccas_bandolier"], ["monocle"],
				["holster"], ["fanned_bracers"]]},
		{"who": "Stephen", "name": "COMBO — Heavy Swing Avenger (big-tempo payoffs)",
			"alloc": {"strength": 27, "dexterity": 12, "determination": 12},
			"passives": ["swing_for_the_fences", "patience_is_a_virtue", "dominate",
				"skilled_momentum", "deadly", "clean_exchange", "lethal_resourcefulness"],
			"gear": [["hide_of_garmr"], ["dragon_skull"], ["equator"],
				["mountain_boots"], ["sleeved_katar"]]},
		{"who": "Stephen", "name": "BRUISER — Sentinel Duelist (counter-attack shell)",
			"alloc": {"strength": 20, "dexterity": 16, "wisdom": 15},
			"passives": ["clean_exchange", "exposed_blind_spot", "lethal_resourcefulness",
				"deadly", "patience_is_a_virtue", "swing_for_the_fences", "scouted"],
			"gear": [["hallowed_trunk"], ["smithed_excellence"], ["burgonet"],
				["strap_of_stone"], ["chain_crocs"]]},
		{"who": "Cory", "name": "ROGUE/DEBUFFER — Withering Lurker (double-gauntlet debuffs)",
			"alloc": {"dexterity": 18, "intelligence": 18, "agility": 15},
			"passives": ["wither", "territorial_death", "death_as_lifeblood",
				"prey_on_the_weak", "eat", "serial_killer", "budding"],
			"gear": [["hannibals_mask"], ["gravity_gauntlets"], ["spidey_web_shooters", 1],
				["blue_robe"], ["belt_of_wumbology"], ["knife_toed_boots"]]},
		{"who": "Cory", "name": "SUPPORT/ECON — Overcharged Monk (skill-cooldown mana engine)",
			"alloc": {"wisdom": 18, "intelligence": 21, "agility": 12},
			"passives": ["energy_barrier", "self_reliance", "expel_negativity",
				"budding", "circle_of_life", "regrowth", "death_as_lifeblood"],
			"gear": [["cuffs_of_current"], ["copper_bracers", 1], ["suit_and_tie"],
				["wizard_hat"], ["potion_belt"], ["cloth_slippers"]]},
		{"who": "Cory", "name": "TANK — Attrition Grove (armor-loop sustain tank)",
			"alloc": {"strength": 43, "determination": 8},
			"passives": ["wither", "territorial_death", "death_as_lifeblood",
				"expel_negativity", "budding", "circle_of_life", "eat"],
			"gear": [["briarhide_plate"], ["hallowed_trunk"], ["spiked_mitts", 1],
				["strap_of_stone"], ["thick_steel_helm"], ["steel_boots"]]},
	]
	for b in builds:
		_simulate(b)
	quit(0)
