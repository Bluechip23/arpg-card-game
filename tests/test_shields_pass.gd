extends SceneTree

## Shields pass 1: the 15 shields — factories, the slot rule (shields take any
## card now), the always-on channels (flat reduction, flash points, low-health
## lifesteal), the on-self riders (Fortify, mana-scaled block, lifesteal, roll
## boost), Overdraw (heal, Regen, charges, conjured blades), temporary mana,
## the Mind over Matter ward, Curse of the Living's halved healing, Bark Up's
## conversion, Song of a Swords Sing's debuff-KIND count, and the enemy-side
## Sword Breaker tempo tax.
## Run: godot --headless --path . --script tests/test_shields_pass.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _mk_stats() -> PlayerStats:
	var stats = PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(CharacterData.create_ryan())
	stats.max_health = 200
	stats.current_health = 200
	stats.max_mana = 100
	stats.current_mana = 100.0
	stats.base_strength = 60
	stats.strength = 60
	return stats

func _mk_inv(stats: PlayerStats) -> Inventory:
	var inv = Inventory.new()
	get_root().add_child(inv)
	inv.initialize("Ryan")
	inv.connect_player_stats(stats)
	inv.enforce_mythic_limit = false
	return inv

const SHIELDS := ["Buckler", "Wooden Shield", "Vengeful Shield", "Vanguard", "Spiked Shield",
	"Castle wall", "Sword Breaker", "Coffin Lid", "Treebeards Branch",
	"Slotted Rope Half Sleeve", "Elemental emblem",
	"Delfins Deterministic Round Shield", "Steve Rodgers Bastion of Reverberation",
	"Presence of Mind", "Crooked Dueling Shield"]

func _initialize() -> void:
	print("=== Shields pass test ===")
	_test_roster()
	_test_slots_take_any_card()
	_test_passive_channels()
	_test_on_self_riders()
	_test_granted_cards()
	_test_overdraw_charges()
	_test_temp_mana()
	_test_mana_ward()
	_test_curse_of_the_living()
	_test_bark_up()
	_test_debuff_kinds()
	_test_tempo_tax()
	_test_duelist_crit_rider()
	_test_mythic_upgrades()
	print("=== %d failure(s) ===" % failures)

func _test_mythic_upgrades() -> void:
	## Every mythic's forged (Lv.2) numbers, straight off the design sheet.
	print("-- Mythic upgrades --")
	var delfin = ItemData.create_delfins_deterministic_round_shield()
	delfin.level_up()
	_check(delfin.intelligence_bonus == 6 and delfin.wisdom_bonus == 7 and delfin.strength_bonus == 5,
		"Delfins Lv.2: 6 INT / 7 WIS / 5 STR")
	_check(is_equal_approx(delfin.on_self_chance_boost, 13.0), "Delfins Lv.2: +13% to rolls")
	_check(delfin.overdraw_peak == 5, "Delfins Lv.2: Peak 5")
	# Mage Shield's block reads the shield's level live, so the same card
	# instance is worth 10 unforged and 15 forged.
	var stats = _mk_stats()
	var mage = Card.create_by_id("mage_shield")
	mage.granted_by_item = ItemData.create_delfins_deterministic_round_shield()
	stats.current_armor = 0
	mage.execute(null, stats, null, 0.0, 0.0, null)
	var unforged: int = stats.current_armor
	mage.granted_by_item = delfin
	stats.current_armor = 0
	mage.execute(null, stats, null, 0.0, 0.0, null)
	_check(stats.current_armor == unforged + 5,
		"Mage Shield: 10 block unforged -> 15 forged (%d -> %d)" % [unforged, stats.current_armor])
	_check(mage.block == 10, "and the +5 never sticks to the card")

	var bastion = ItemData.create_steve_rodgers_bastion()
	bastion.level_up()
	_check(bastion.strength_bonus == 6 and bastion.dexterity_bonus == 3
		and bastion.agility_bonus == 5 and bastion.determination_bonus == 5
		and bastion.mana_bonus == 30, "Bastion Lv.2: 6 STR / 3 DEX / 5 AGI / 5 DET / +30 mana")
	_check(bastion.damage_taken_mana_gain == 7, "Bastion Lv.2: 7 mana per hit taken")

	var pom = ItemData.create_presence_of_mind()
	pom.level_up()
	_check(pom.intelligence_bonus == 7 and pom.strength_bonus == 9 and pom.wisdom_bonus == 2
		and pom.mana_bonus == 45 and pom.health_bonus == -10,
		"Presence of Mind Lv.2: 7 INT / 9 STR / 2 WIS / +45 mana / -10 health")
	_check(is_equal_approx(pom.on_self_block_max_mana_percent, 15.0),
		"Presence of Mind Lv.2: block worth 15% of max mana")

	var crooked = ItemData.create_crooked_dueling_shield()
	crooked.level_up()
	_check(crooked.dexterity_bonus == 10 and crooked.agility_bonus == 10 and crooked.strength_bonus == 5,
		"Crooked Lv.2: 10 DEX / 10 AGI / 5 STR")
	_check(int(crooked.slot_effects[0].get("combo_armor", 0)) == 20
		and int(crooked.slot_effects[1].get("combo_armor", 0)) == 20,
		"Crooked Lv.2: the combo pays 20 armor")
	_check(int(crooked.slot_effects[0].get("weaken", 0)) == 1
		and int(crooked.slot_effects[1].get("vulnerable", 0)) == 1,
		"and the slots keep their Weaken and Vulnerable")
	stats.free()

func _test_duelist_crit_rider() -> void:
	## The rider lives in crit_multiply — the one funnel EVERY crit in the game
	## passes through — so it fires for every executor, not just the standard
	## attack path.
	print("-- Crooked Dueling Shield: every crit --")
	var stats = _mk_stats()
	var inv = _mk_inv(stats)
	var crooked = ItemData.create_crooked_dueling_shield()
	var stub = _DebuffStub.new()

	# No shield: crits leave nothing behind.
	Card.crit_multiply(10, stats, stub)
	_check(stub.weaken_stacks == 0 and stub.vulnerable_stacks == 0,
		"without the shield a crit applies nothing")

	inv.equip_item(crooked, 0)
	Card.crit_multiply(10, stats, stub)
	_check(stub.weaken_stacks == 1 and stub.vulnerable_stacks == 0,
		"first crit on a clean target: 1 Weaken, no Vulnerable (W%d V%d)" % [stub.weaken_stacks, stub.vulnerable_stacks])
	Card.crit_multiply(10, stats, stub)
	_check(stub.vulnerable_stacks == 2 and stub.weaken_stacks == 2,
		"crit into an already-Weakened target: 2 Vulnerable first, then its own Weaken (W%d V%d)" % [stub.weaken_stacks, stub.vulnerable_stacks])

	# The victim falls back to the card resolution's own target, so executors
	# that never pass one still fire the rider.
	var parked = _DebuffStub.new()
	stats.resolving_attack_target = parked
	Card.crit_multiply(10, stats)
	_check(parked.weaken_stacks == 1, "a crit with no explicit target uses the resolving card's victim")
	stats.resolving_attack_target = null
	stats.free()
	inv.free()
	quit(1 if failures > 0 else 0)

func _test_roster() -> void:
	print("-- Roster --")
	for nm in SHIELDS:
		var item = ItemData.create_by_name(nm)
		_check(item != null and item.item_type == ItemData.ItemType.WEAPON
			and item.weapon_subtype == ItemData.WeaponSubtype.SHIELD, "%s exists as a shield" % nm)
	var rarities := {}
	for nm in SHIELDS:
		var r: int = ItemData.create_by_name(nm).rarity
		rarities[r] = int(rarities.get(r, 0)) + 1
	_check(rarities.get(ItemData.Rarity.COMMON, 0) == 2, "2 commons")
	_check(rarities.get(ItemData.Rarity.RARE, 0) == 3, "3 rares")
	_check(rarities.get(ItemData.Rarity.LEGENDARY, 0) == 6, "6 legendaries")
	_check(rarities.get(ItemData.Rarity.MYTHIC, 0) == 4, "4 mythics")
	for nm in ["Delfins Deterministic Round Shield", "Steve Rodgers Bastion of Reverberation",
			"Presence of Mind", "Crooked Dueling Shield"]:
		var m = ItemData.create_by_name(nm)
		_check(m.appearance != "" and m.appearance_icon != "",
			"%s is a mythic with appearance + icon" % nm)
	var sb = ItemData.create_sword_breaker()
	_check(sb.dexterity_bonus == 3 and sb.determination_bonus == 3
		and sb.health_bonus == 25 and sb.mana_bonus == 25,
		"Sword Breaker: +3 DEX, +3 DET, +25 health, +25 mana")
	# Per the design sheet this one carries exactly what was specified, no more.
	var ee = ItemData.create_elemental_emblem()
	_check(ee.intelligence_bonus == 10 and ee.strength_bonus == -5 and ee.agility_bonus == -3
		and ee.card_slots == 0 and ee.granted_card_ids.is_empty(),
		"Elemental emblem is the stat line and nothing else, as specified")

func _test_slots_take_any_card() -> void:
	print("-- Shield slots take any card --")
	var wall = ItemData.create_castle_wall()
	_check(wall.card_slots == 2, "Castle wall has 2 slots")
	var plain = Card.create_slice()
	_check(wall.can_slot_card(plain) and wall.slot_card(plain),
		"an ordinary attack card slots into a shield")
	var arrow = Card.create_by_id("improvised_ammo")
	if arrow:
		_check(wall.can_slot_card(arrow), "a keyworded card slots into a shield too")
	# An item-granted card can never be slotted, shields included.
	var granted = Card.create_by_id("huck")
	granted.granted_by_item = wall
	_check(not wall.can_slot_card(granted), "a shield's own granted card cannot be slotted back in")

func _test_passive_channels() -> void:
	print("-- Always-on channels --")
	var stats = _mk_stats()
	var inv = _mk_inv(stats)
	inv.equip_item(ItemData.create_buckler(), 0)
	_check(stats.equipment_flat_damage_reduction == 3, "Buckler sets 3 flat reduction")
	stats.current_health = 200
	stats.take_damage(10)
	_check(stats.current_health == 193, "a 10 hit lands as 7 (took %d)" % (200 - stats.current_health))
	stats.take_damage(2)
	_check(stats.current_health == 193, "a 2 hit is shrugged off entirely")
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	_check(stats.equipment_flat_damage_reduction == 0, "reduction clears on unequip")

	# Slotted Rope Half Sleeve: flash points up, block cards down.
	var sleeve = ItemData.create_slotted_rope_half_sleeve()
	var flash_before: int = stats.get_max_flash_points()
	var block_before: int = stats.equipment_defense_card_block
	inv.equip_item(sleeve, 0)
	_check(stats.equipment_flash_bonus == 4, "the sleeve banks 4 flash points")
	# The pool is AGI-driven, so the sleeve's +4 AGI lifts it as well.
	_check(stats.get_max_flash_points() == flash_before + 4 + sleeve.agility_bonus,
		"the flash pool grows by the bonus and the AGI behind it (%d -> %d)" % [flash_before, stats.get_max_flash_points()])
	_check(stats.equipment_defense_card_block == block_before - 3, "and takes 3 off block cards")
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	_check(stats.get_max_flash_points() == flash_before and stats.equipment_defense_card_block == block_before
		and stats.equipment_flash_bonus == 0, "both channels clear on unequip")

	# Coffin Lid: lifesteal only swells once you are actually hurt.
	inv.equip_item(ItemData.create_coffin_lid(), 0)
	stats.current_health = stats.max_health
	_check(is_equal_approx(stats.get_equipment_lifesteal(), 0.0), "healthy: no bonus lifesteal")
	stats.current_health = int(stats.max_health * 0.4)
	_check(is_equal_approx(stats.get_equipment_lifesteal(), 8.0), "below half: +8% lifesteal")
	stats.free()
	inv.free()

func _test_on_self_riders() -> void:
	print("-- On-self riders --")
	var stats = _mk_stats()
	var inv = _mk_inv(stats)

	# Presence of Mind: block scaled off the mana pool, and it never sticks.
	var pom = ItemData.create_presence_of_mind()
	inv.equip_item(pom, 0)
	var guard = Card.create_by_id("clang_up")
	pom.slot_card(guard)
	var base_block: int = guard.block
	stats.current_armor = 0
	guard.execute(null, stats, null, 0.0, 0.0, null)
	_check(stats.current_armor >= base_block + 10,
		"10%% of a 100 mana pool rides the block card (armor %d)" % stats.current_armor)
	_check(guard.block == base_block, "the mana block does not stick to the card")
	# Forging it to Lv.2 raises the cut to 15%.
	var pom2 = ItemData.create_presence_of_mind()
	pom2.level_up()
	_check(is_equal_approx(pom2.on_self_block_max_mana_percent, 15.0), "Lv.2 Presence of Mind scales at 15%")

	# Delfins: slotted cards roll better.
	var delfin = ItemData.create_delfins_deterministic_round_shield()
	_check(is_equal_approx(delfin.get_on_self_bonus().get("chance_boost", 0.0), 10.0),
		"Delfins offers +10% to a slotted card's rolls")

	# Sword Breaker: 4 armor and Fortify on any slotted play.
	var breaker = ItemData.create_sword_breaker()
	_check(int(breaker.get_on_self_bonus().get("armor_any", 0)) == 4
		and int(breaker.get_on_self_bonus().get("fortify", 0)) == 1,
		"Sword Breaker: 4 armor + 1 Fortify on-self")

	# Vengeful Shield shoves; the Sleeve discards.
	_check(int(ItemData.create_vengeful_shield().get_on_self_bonus().get("knockback", 0)) == 1,
		"Vengeful Shield shoves the target 1")
	var sleeve_fx = ItemData.create_slotted_rope_half_sleeve().get_on_self_bonus()
	_check(int(sleeve_fx.get("discard", 0)) == 1 and int(sleeve_fx.get("block", 0)) == 3,
		"the Sleeve discards 1 for 3 block")

	# Crooked Dueling Shield: colored slots, and the combo pays armor either way.
	var crooked = ItemData.create_crooked_dueling_shield()
	_check(crooked.slot_colors == ["blue", "red"], "a blue slot and a red slot")
	_check(int(crooked.slot_effects[0].get("weaken", 0)) == 1
		and int(crooked.slot_effects[1].get("vulnerable", 0)) == 1,
		"blue Weakens, red makes Vulnerable")
	_check(int(crooked.slot_effects[0].get("combo_armor", 0)) == 10
		and int(crooked.slot_effects[1].get("combo_armor", 0)) == 10,
		"either order pays 10 armor")
	var crooked2 = ItemData.create_crooked_dueling_shield()
	crooked2.level_up()
	_check(crooked2.dexterity_bonus == 10 and crooked2.agility_bonus == 10 and crooked2.strength_bonus == 5,
		"Lv.2 Crooked: 10 DEX / 10 AGI / 5 STR")
	stats.free()
	inv.free()

func _test_granted_cards() -> void:
	print("-- Granted cards --")
	for pair in [["Castle wall", "huck"], ["Sword Breaker", "song_of_a_swords_sing"],
			["Coffin Lid", "curse_of_the_living"], ["Treebeards Branch", "bark_up"],
			["Delfins Deterministic Round Shield", "mage_shield"],
			["Presence of Mind", "mind_over_matter"]]:
		var item = ItemData.create_by_name(pair[0])
		_check(item.granted_card_ids.has(pair[1]), "%s grants %s" % [pair[0], pair[1]])
	var bastion = ItemData.create_steve_rodgers_bastion()
	_check(bastion.granted_card_ids.has("reverberate_regrowth")
		and bastion.granted_card_ids.has("bouncing_shield"),
		"the Bastion grants both of its cards")

	var huck = Card.create_by_id("huck")
	_check(huck.mana_cost == 100 and huck.tempo_cost == 5, "Huck: 100m/5t")
	var song = Card.create_by_id("song_of_a_swords_sing")
	_check(song != null and song.card_type == Card.CardType.UTILITY, "Song of a Swords Sing is a utility")
	var curse = Card.create_by_id("curse_of_the_living")
	_check(curse.card_type == Card.CardType.POWER and curse.maintain_cost == 65,
		"Curse of the Living maintains at 65")
	var rr = Card.create_by_id("reverberate_regrowth")
	_check(rr.card_type == Card.CardType.POWER and rr.maintain_cost == 55,
		"Reverberate Regrowth maintains at 55")
	var mage = Card.create_by_id("mage_shield")
	_check(mage.card_type == Card.CardType.REACTION and mage.reaction_trigger == "on_damage_taken"
		and mage.block == 10 and mage.mana_cost == 0,
		"Mage Shield is a free instant off damage taken for 10 block")
	var blade = Card.create_by_id("cinquedea")
	_check(blade.mana_cost == 10 and blade.tempo_cost == 0 and blade.base_damage == 6,
		"Cinquedea: 10m/0t, 6 damage")
	var rain = Card.create_by_id("rain_of_arrows")
	_check(rain.mana_cost == 45 and rain.base_damage == 10, "Rain of Arrows: 45 mana, 10 damage")
	for cid in ["huck", "rain_of_arrows", "song_of_a_swords_sing", "curse_of_the_living",
			"bark_up", "cinquedea", "mage_shield", "reverberate_regrowth",
			"bouncing_shield", "mind_over_matter"]:
		_check(Card.DROP_EXCLUDED_CARD_IDS.has(cid), "%s never drops randomly" % cid)

func _test_overdraw_charges() -> void:
	print("-- Overdraw --")
	var stats = _mk_stats()
	var inv = _mk_inv(stats)
	var wall = ItemData.create_castle_wall()
	inv.equip_item(wall, 0)
	_check(wall.overdraw_heal == 5 and wall.overdraw_spell_id == "rain_of_arrows"
		and wall.overdraw_spell_mana == 45, "Castle wall: heal 5 + a 45-mana Rain of Arrows")
	_check(wall.overdraw_charges_left == 3, "it comes to hand with a full magazine")
	# Charges come back on their own clock, even part-full, and stop at the cap.
	wall.overdraw_charges_left = 1
	for i in range(3):
		inv.process_turn()
	_check(wall.overdraw_charges_left == 2, "15 tempo returns one charge (have %d)" % wall.overdraw_charges_left)
	for i in range(6):
		inv.process_turn()
	_check(wall.overdraw_charges_left == 3, "the magazine fills and stops at 3")
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	_check(wall.overdraw_charges_left == 0, "an unequipped shield holds no charges")

	var sleeve = ItemData.create_slotted_rope_half_sleeve()
	_check(sleeve.overdraw_card_id == "cinquedea" and sleeve.overdraw_card_max == 5
		and sleeve.overdraw_card_block == 1, "the Sleeve conjures up to 5 Cinquedeas at +1 block each")
	_check(ItemData.create_treebeards_branch().overdraw_regen == 3, "Treebeards: 3 Regen on Overdraw")
	_check(ItemData.create_delfins_deterministic_round_shield().overdraw_peak == 4, "Delfins: Peak 4")
	stats.free()
	inv.free()

func _test_temp_mana() -> void:
	print("-- Temporary mana --")
	var stats = _mk_stats()
	stats.current_mana = 100.0
	stats.add_temp_mana(50, 15)
	_check(stats.current_mana == 150.0, "temp mana pushes the pool past its maximum")
	_check(stats.get_available_max_mana() == 150, "the ceiling rises with it")
	# Costs eat the volatile half first.
	stats.spend_mana(20)
	_check(stats.current_temp_mana == 30 and stats.current_mana == 130.0,
		"spending drains temp mana first (%d temp, %d total)" % [stats.current_temp_mana, int(stats.current_mana)])
	stats.process_tempo(15)
	_check(stats.current_temp_mana == 0 and stats.current_mana == 100.0,
		"after 15 tempo the temp mana evaporates and the pool falls back to its cap")
	# A maintained card's reservation is offset while the temp mana lasts —
	# that is the whole point of throwing the shield into a crowd.
	stats.reserve_mana(50)
	_check(stats.get_available_max_mana() == 50, "a 50-mana maintain halves a 100 pool")
	stats.add_temp_mana(50, 15)
	_check(stats.get_available_max_mana() == 100, "50 temp mana buys the reservation back")
	stats.free()

func _test_mana_ward() -> void:
	print("-- Mind over Matter --")
	var stats = _mk_stats()
	stats.current_mana = 100.0
	stats.current_health = 200
	var ward = Card.create_by_id("mind_over_matter")
	ward.execute(null, stats, null, 0.0, 0.0, null)
	_check(stats.pending_mana_ward, "the ward is armed")
	stats.take_damage(40)
	_check(stats.current_health == 200, "the warded hit never reaches health")
	_check(stats.current_mana == 80.0, "half of it (20) is paid in mana (mana %d)" % int(stats.current_mana))
	_check(not stats.pending_mana_ward, "the ward is spent")
	# Mana that cannot cover the halved hit lets the remainder through.
	stats.pending_mana_ward = true
	stats.current_mana = 5.0
	stats.current_health = 200
	stats.take_damage(40)
	_check(stats.current_mana == 0.0 and stats.current_health == 185,
		"5 mana absorbs 5, the last 15 lands on health (health %d)" % stats.current_health)
	stats.free()

func _test_curse_of_the_living() -> void:
	print("-- Curse of the Living --")
	var stats = _mk_stats()
	var inv = _mk_inv(stats)
	var dm = DeckManager.new()
	get_root().add_child(dm)
	inv.connect_deck_manager(dm)
	stats.inventory = inv
	stats.current_health = 100
	stats.max_health = 200
	var shared := []
	stats.curse_of_the_living_shared.connect(func(amount): shared.append(amount))
	# Compare against the character's own effective heal so healing bonuses
	# don't muddy the halving.
	var full: int = stats.get_effective_heal_amount(10)
	var halved: int = stats.get_effective_heal_amount(5)
	stats.heal(10)
	_check(stats.current_health == 100 + full and shared.is_empty(),
		"unmaintained: a 10 heal lands in full (%d)" % (stats.current_health - 100))
	dm.maintained_cards.append(Card.create_by_id("curse_of_the_living"))
	stats.current_health = 100
	stats.heal(10)
	_check(stats.current_health == 100 + halved,
		"maintained: the heal is halved to 5 (healed %d, expected %d)" % [stats.current_health - 100, halved])
	_check(shared.size() == 1 and shared[0] == 3, "and each ally is offered 3 (2.5 rounded up)")
	stats.free()
	inv.free()
	dm.free()

func _test_bark_up() -> void:
	print("-- Bark Up --")
	var stats = _mk_stats()
	var bm = BuffManager.new()
	get_root().add_child(bm)
	bm.apply_buff(Buff.create_regen(3, 15, "test"))
	bm.apply_buff(Buff.create_thorns(4, 15, "test"))
	stats.current_armor = 0
	Card.create_by_id("bark_up").execute(null, stats, null, 0.0, 0.0, bm)
	_check(stats.current_armor == 7, "3 Regen + 4 Thorns harden into 7 armor (got %d)" % stats.current_armor)
	_check(not bm.has_buff(Buff.BuffType.REGEN) and not bm.has_buff(Buff.BuffType.THORNS),
		"both buffs are spent doing it")
	stats.free()
	bm.free()

func _test_debuff_kinds() -> void:
	print("-- Song of a Swords Sing counts KINDS --")
	var dummy = Node.new()
	dummy.set_script(GDScript.new())
	# A stand-in with the same debuff fields the enemy carries.
	var stub = _DebuffStub.new()
	stub.burn_stacks = 1
	stub.cold_stacks = 1
	stub.disarmed_attacks = 1
	_check(Card.count_debuff_kinds(stub) == 3, "1 burn + 1 frost + 1 disarm = 3 kinds")
	stub.burn_stacks = 0
	stub.cold_stacks = 0
	stub.disarmed_attacks = 3
	_check(Card.count_debuff_kinds(stub) == 1, "3 disarm = 1 kind")
	stub.disarmed_attacks = 0
	_check(Card.count_debuff_kinds(stub) == 0, "a clean enemy is 0 kinds")
	dummy.free()

class _DebuffStub:
	## Stands in for an enemy: the same debuff fields, and apply_debuff so crit
	## riders can write to it.
	func apply_debuff(debuff_name: String, value: int) -> void:
		var field := "%s_stacks" % debuff_name
		if field in self:
			set(field, int(get(field)) + value)

	var burn_stacks: int = 0
	var cold_stacks: int = 0
	var poison_stacks: int = 0
	var shock_stacks: int = 0
	var bleed_stacks: int = 0
	var vulnerable_stacks: int = 0
	var weaken_stacks: int = 0
	var slow_stacks: int = 0
	var choke_dot_stacks: int = 0
	var disarmed_attacks: int = 0

func _test_tempo_tax() -> void:
	print("-- Sword Breaker's tempo tax --")
	_check(ItemData.create_sword_breaker().blocked_melee_tempo_tax == 2,
		"the shield taxes a blocked melee swing 2 tempo")
	_check(not Enemy.NON_MELEE_ACTIONS.has("attack") and not Enemy.NON_MELEE_ACTIONS.has("maul"),
		"melee swings are taxable")
	for nm in ["move", "shoot", "flee", "get_into_range"]:
		_check(Enemy.NON_MELEE_ACTIONS.has(nm), "%s is never taxed" % nm)
