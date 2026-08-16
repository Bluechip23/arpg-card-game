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
	_print_shield_lines(stats, inv)
	stats.free()
	inv.free()

## Shields pass: the defensive channels a shield build lives or dies on. Only
## printed when a shield is actually in hand, so the older builds read as before.
func _print_shield_lines(stats: PlayerStats, inv: Inventory) -> void:
	var shields := inv.get_equipped_shields()
	if shields.is_empty():
		return
	var names: Array[String] = []
	var brace_block := 0
	for s in shields:
		names.append("%s (w%d)" % [s.item_name, s.weight])
		# What bracing THIS shield two-handed would be worth (it isn't braced
		# in the sim, so ask the weight formula directly).
		brace_block = maxi(brace_block, floori(s.weight / Inventory.TWO_HAND_WEIGHT_DAMAGE_DIVISOR))
	print("  SHIELDS: %s" % ", ".join(names))
	# What a hit actually costs after the shield's flat bite. 12 is a typical
	# mid-act enemy swing; the burn line matters because damage-over-time ticks
	# run through the same take_damage path the flat reduction sits on.
	var flat: int = stats.equipment_flat_damage_reduction
	print("  Mitigation: flat -%d/hit  (a 12 lands as %d, a 4 lands as %d)" % [
		flat, maxi(0, 12 - flat), maxi(0, 4 - flat)])
	print("  vs a doubling burn 1/2/4/8/16 -> %d/%d/%d/%d/%d" % [
		maxi(0, 1 - flat), maxi(0, 2 - flat), maxi(0, 4 - flat),
		maxi(0, 8 - flat), maxi(0, 16 - flat)])
	print("  Block cards: %+d armor each | Bracing two-handed would add %+d" % [
		stats.equipment_defense_card_block, brace_block])
	var full_hp_ls: float = stats.get_equipment_lifesteal()
	var hurt_hp: int = stats.current_health
	stats.current_health = int(stats.max_health * 0.3)
	var hurt_ls: float = stats.get_equipment_lifesteal()
	stats.current_health = hurt_hp
	print("  Lifesteal: %.0f%% healthy -> %.0f%% below half | Flash %d (+%d from gear)" % [
		full_hp_ls, hurt_ls, stats.get_max_flash_points(), stats.equipment_flash_bonus])
	for s in shields:
		if s.overdraw_spell_charges > 0:
			print("  Overdraw: %s, %d charges, 1 back per %d tempo, %d mana a shot" % [
				s.overdraw_spell_id, s.overdraw_spell_charges, s.overdraw_spell_recharge, s.overdraw_spell_mana])
		if s.overdraw_card_max > 0:
			print("  Overdraw: up to %d %s held, %+d block each (%+d at full)" % [
				s.overdraw_card_max, s.overdraw_card_id, s.overdraw_card_block,
				s.overdraw_card_block * s.overdraw_card_max])
		if s.on_self_block_max_mana_percent > 0.0:
			print("  On-self block: %.0f%% of %d max mana = %+d per slotted card" % [
				s.on_self_block_max_mana_percent, stats.max_mana,
				floori(stats.max_mana * s.on_self_block_max_mana_percent / 100.0)])

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
		# ---- Shields pass 1: one build per shield archetype. Slot 1 is the off
		# hand, so every one of these is a real weapon-and-board loadout. ----
		{"who": "Brad", "name": "SHIELD/TANK — Castle Wall (the -3 hand size test)",
			"alloc": {"strength": 34, "determination": 9, "wisdom": 8},
			"passives": ["in_the_trenches", "the_way_of_the_plate", "pristine_armor",
				"stone_skin", "ancestral_aid", "vines_codependence", "solemn_independence"],
			"gear": [["short_sword", 0], ["castle_wall", 1], ["steel_plate"],
				["thick_steel_helm"], ["steel_boots"]]},
		{"who": "Brad", "name": "SHIELD/TANK — Buckler + Vanguard (double flat reduction)",
			"alloc": {"strength": 30, "determination": 15, "agility": 6},
			"passives": ["in_the_trenches", "the_way_of_the_plate", "pristine_armor",
				"stone_skin", "ancestral_aid", "redemption", "point_to_prove"],
			"gear": [["buckler", 0], ["vanguard", 1], ["steel_plate"],
				["thick_steel_helm"], ["steel_boots"]]},
		{"who": "Stephen", "name": "SHIELD/BRUISER — Sword Breaker duelist (tempo tax + Fortify)",
			"alloc": {"strength": 20, "dexterity": 16, "wisdom": 15},
			"passives": ["clean_exchange", "exposed_blind_spot", "lethal_resourcefulness",
				"deadly", "patience_is_a_virtue", "swing_for_the_fences", "scouted"],
			"gear": [["short_sword", 0], ["sword_breaker", 1], ["smithed_excellence"],
				["burgonet"], ["chain_crocs"]]},
		{"who": "Stephen", "name": "SHIELD/DUELIST — Crooked Dueling Shield (crit->Weaken->Vulnerable)",
			"alloc": {"dexterity": 27, "agility": 18, "strength": 6},
			"passives": ["deadly", "scouted", "skilled_momentum", "clean_exchange",
				"dominate", "patience_is_a_virtue", "lethal_resourcefulness"],
			"gear": [["rusty_dagger", 0], ["crooked_dueling_shield", 1], ["shadow_cowl"],
				["feathered_hat"], ["knife_toed_boots"]]},
		{"who": "Jeremy", "name": "SHIELD/MAGE — Presence of Mind (mana as armor)",
			"alloc": {"intelligence": 30, "wisdom": 21},
			"passives": ["arcane_overflow", "harnessed_power", "mana_surge",
				"tricks_of_death", "seance", "a_mages_favor", "fresh_start"],
			"gear": [["presence_of_mind", 1], ["blue_robe"], ["wizard_hat"],
				["caster_boots"], ["techno_wraps"]]},
		{"who": "Jeremy", "name": "SHIELD/SUPPORT — Coffin Lid (halved heals, shared out)",
			"alloc": {"wisdom": 24, "intelligence": 15, "determination": 12},
			"passives": ["i_heal_you", "whispers_of_the_flock", "blood_libation",
				"fresh_start", "a_mages_favor", "kinetic_armor", "tricks_of_death"],
			"gear": [["coffin_lid", 1], ["trench_of_tranquility"], ["shamans_mask"],
				["corset_of_cure"], ["medic_wraps"]]},
		{"who": "Cory", "name": "SHIELD/ATTRITION — Treebeards Branch (the 75-weight test)",
			"alloc": {"strength": 43, "determination": 8},
			"passives": ["wither", "territorial_death", "death_as_lifeblood",
				"expel_negativity", "budding", "circle_of_life", "eat"],
			"gear": [["treebeards_branch", 1], ["briarhide_plate"], ["hallowed_trunk"],
				["strap_of_stone"], ["thick_steel_helm"], ["steel_boots"]]},
		{"who": "Ryan", "name": "SHIELD/COMBO — Slotted Rope Half Sleeve (Cinquedea engine)",
			"alloc": {"dexterity": 21, "agility": 15, "wisdom": 15},
			"passives": ["keep_them_guessing", "from_the_hip", "nimble_assault",
				"ladder_work", "quick_step", "stimulant", "surprise_opener"],
			"gear": [["rusty_dagger", 0], ["slotted_rope_half_sleeve", 1],
				["the_slotted_sash"], ["shadow_cowl"], ["boot_holsters"]]},
		{"who": "Ryan", "name": "SHIELD/MYTHIC — Steve Rodgers Bastion (mana off every hit)",
			"alloc": {"agility": 20, "dexterity": 25, "strength": 6},
			"passives": ["now_you_see_me", "surprise_opener", "eye_scrape",
				"ladder_work", "lets_dance", "quick_step", "keep_them_guessing"],
			"gear": [["short_sword", 0], ["steve_rodgers_bastion", 1], ["shadow_cowl"],
				["feathered_hat"], ["houdinis_slippers"]]},
		{"who": "Cory", "name": "SHIELD/EARLY — Wooden Shield + Spiked Shield (commons/rares)",
			"alloc": {"strength": 20, "wisdom": 16, "intelligence": 15},
			"passives": ["wither", "territorial_death", "death_as_lifeblood",
				"expel_negativity", "budding", "circle_of_life", "eat"],
			"gear": [["wooden_shield", 0], ["spiked_shield", 1], ["buffed_leather"],
				["leather_cap"], ["leather_boots"]]},
	]
	for b in builds:
		_simulate(b)
	quit(0)
