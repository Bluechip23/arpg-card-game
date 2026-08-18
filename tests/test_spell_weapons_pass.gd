extends SceneTree

## Spell weapons pass 1: the 13 spell weapons — factories, two-hand staffs,
## global on-hit debuff riders, Blast Stick's mana economy, the granted cards
## (Element Pollination / From the Ashes / Polymorph / Reaper's Taking), and
## Feral Evocation's colored elemental slots.
## Run: godot --headless --path . --script tests/test_spell_weapons_pass.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Spell weapons pass test ===")
	_test_roster()
	_test_two_handers()
	_test_on_hit_riders()
	_test_blast_stick()
	_test_granted_cards()
	_test_circes_copies()
	_test_reaper()
	_test_feral_slots()
	_test_phoenix()
	_test_round2()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_round2() -> void:
	print("-- Round 2: Clarity, Reaction Rod, Cane instants, Crops --")
	var clarity = ItemData.create_wand_of_clarity()
	_check(clarity.on_self_brain_regen == 2 and clarity.on_self_flash_regen == 2,
		"Wand of Clarity on-self: 2 brain + 2 flash points")
	_check(clarity.no_debuff_mana_discount_percent == 15.0, "Wand of Clarity: 15% off with no debuffs")
	_check(clarity.granted_card_ids.size() == 1 and clarity.granted_card_ids[0] == "clear_mind",
		"Wand of Clarity grants Clear Mind")
	var cm = Card.create_by_id("clear_mind")
	_check(cm != null and cm.mana_cost == 50 and cm.tempo_cost == 4 and cm.card_type == Card.CardType.UTILITY,
		"Clear Mind is a 50m/4t utility")
	var rod = ItemData.create_reaction_rod()
	_check(rod.melee_retaliate_shock == 4 and rod.card_slots == 0, "Reaction Rod: 4 Shock retaliation, no slots")
	var gr = Card.create_by_id("grounding")
	_check(gr != null and gr.mana_cost == 200 and gr.tempo_cost == 10 and gr.school == Card.CardSchool.SPELL,
		"Grounding is a 200m/10t spell")
	var cane = ItemData.create_abjurers_cane()
	_check(cane.wisdom_bonus == 5 and cane.intelligence_bonus == 4 and cane.agility_bonus == 4,
		"Abjurers Cane: +5 WIS, +4 INT, +4 AGI")
	_check(cane.granted_card_ids.size() == 2 and cane.granted_card_ids[0] == "defensive_sacrifice",
		"Abjurers Cane grants TWO Defensive Sacrifices")
	var ds = Card.create_by_id("defensive_sacrifice")
	_check(ds != null and ds.card_type == Card.CardType.REACTION
		and ds.reaction_trigger == "on_player_attacked_choice",
		"Defensive Sacrifice is a choice instant")
	var crook = ItemData.create_shepherds_crook()
	_check(crook.card_slots == 4 and crook.card_pull_target == 1,
		"Shepherds Crook: 4 slots, pulls targets 1 square")
	_check(crook.granted_card_ids.size() == 1 and crook.granted_card_ids[0] == "crops",
		"Shepherds Crook grants Crops")
	var cr = Card.create_by_id("crops")
	_check(cr != null and cr.mana_cost == 70 and cr.tempo_cost == 7, "Crops is a 70m/7t utility")
	for cid in ["clear_mind", "grounding", "defensive_sacrifice", "crops"]:
		_check(Card.DROP_EXCLUDED_CARD_IDS.has(cid), "%s never drops randomly" % cid)

const ROSTER := {
	"Frost Book": ItemData.Rarity.COMMON,
	"Fire Book": ItemData.Rarity.COMMON,
	"Earth Book": ItemData.Rarity.COMMON,
	"Magic Staff": ItemData.Rarity.COMMON,
	"Wand of Deliverance": ItemData.Rarity.RARE,
	"Ice Orb": ItemData.Rarity.RARE,
	"Car Battery": ItemData.Rarity.RARE,
	"Abjurers Cane": ItemData.Rarity.LEGENDARY,
	"Shepherds Crook": ItemData.Rarity.LEGENDARY,
	"Wand of Clarity": ItemData.Rarity.LEGENDARY,
	"Reaction Rod": ItemData.Rarity.LEGENDARY,
	"Blast Stick": ItemData.Rarity.LEGENDARY,
	"Elemental Weaver": ItemData.Rarity.LEGENDARY,
	"Wand of the Phoenix Feather": ItemData.Rarity.MYTHIC,
	"Circe's Wand of Cauldron Stirring": ItemData.Rarity.MYTHIC,
	"Reaper Scythe": ItemData.Rarity.MYTHIC,
	"Feral Evocation": ItemData.Rarity.MYTHIC,
}

func _test_roster() -> void:
	print("-- Roster: every spell weapon exists at its rarity --")
	for nm in ROSTER:
		var item = ItemData.create_by_name(nm)
		_check(item != null, "%s exists" % nm)
		if item == null:
			continue
		_check(item.rarity == ROSTER[nm], "%s rarity" % nm)
		_check(item.item_type == ItemData.ItemType.WEAPON, "%s is a weapon" % nm)
	# Mythics carry their appearance art.
	for nm in ["Wand of the Phoenix Feather", "Circe's Wand of Cauldron Stirring", "Reaper Scythe", "Feral Evocation"]:
		var myth = ItemData.create_by_name(nm)
		_check(myth != null and myth.appearance != "" and myth.appearance_icon != "", "%s has an appearance" % nm)

func _test_two_handers() -> void:
	print("-- Staffs demand both hands; wands, tomes and orbs share --")
	for nm in ["Magic Staff", "Car Battery", "Abjurers Cane", "Shepherds Crook", "Blast Stick", "Elemental Weaver", "Reaper Scythe", "Feral Evocation"]:
		var staff = ItemData.create_by_name(nm)
		_check(staff.weapon_subtype == ItemData.WeaponSubtype.STAFF and Inventory.is_two_hand_only(staff),
			"%s is two-hand-only" % nm)
	for nm in ["Frost Book", "Fire Book", "Earth Book", "Wand of Deliverance", "Ice Orb", "Wand of the Phoenix Feather", "Circe's Wand of Cauldron Stirring", "Wand of Clarity", "Reaction Rod"]:
		_check(not Inventory.is_two_hand_only(ItemData.create_by_name(nm)), "%s shares a hand" % nm)

func _test_on_hit_riders() -> void:
	print("-- Global on-hit debuff riders --")
	_check(ItemData.create_frost_book().attack_apply_cold == 1, "Frost Book: 1 Cold on hit")
	_check(ItemData.create_fire_book().attack_apply_burn == 1, "Fire Book: 1 Burn on hit")
	_check(ItemData.create_ice_orb().attack_apply_cold == 2, "Ice Orb: 2 Cold on hit")
	_check(ItemData.create_car_battery().attack_apply_shock == 3, "Car Battery: 3 Shock on hit")
	_check(ItemData.create_circes_wand_of_cauldron_stirring().attack_apply_silence == 1, "Circe's: 1 Silence on hit")
	_check(ItemData.create_reaper_scythe().attack_apply_vulnerable == 1, "Reaper Scythe: 1 Vulnerable on hit")
	_check(ItemData.create_earth_book().block_bonus_to_defense_cards == 1
		and ItemData.create_earth_book().on_self_armor_any == 3, "Earth Book: +1 block cards, 3 armor on-self")
	_check(ItemData.create_magic_staff().damage_bonus_to_attack_cards == 4, "Magic Staff: +4 attack damage")
	_check(ItemData.create_wand_of_deliverance().range_bonus_all_cards == 2, "Deliverance: +2 range all cards")
	_check(ItemData.create_shepherds_crook().healing_bonus == 5, "Shepherds Crook: +5 healing")
	_check(ItemData.create_abjurers_cane().discard_gain_block == 3, "Abjurers Cane: 3 block per discard")

func _test_blast_stick() -> void:
	print("-- Blast Stick: the mana economy --")
	var stick = ItemData.create_blast_stick()
	_check(stick.spell_mana_surcharge_percent == 10.0, "offensive spells cost 10% more")
	_check(stick.spell_damage_per_mana_percent == 20.0, "and deal 20% of that cost as damage")
	_check(stick.intelligence_bonus == 18 and stick.agility_bonus == -8 and stick.strength_bonus == 1,
		"+18 INT, -8 AGI, +1 STR")

func _test_granted_cards() -> void:
	print("-- Granted cards build from their ids --")
	var pol = Card.create_by_id("element_pollination")
	_check(pol != null and pol.card_type == Card.CardType.POWER and pol.maintain_cost == 60 and pol.tempo_cost == 3,
		"Element Pollination is a 60m/3t Maintain")
	var ash = Card.create_by_id("from_the_ashes")
	_check(ash != null and ash.mana_cost == 80 and ash.tempo_cost == 2 and ash.school == Card.CardSchool.SPELL,
		"From the Ashes is an 80m/2t spell")
	var pig = Card.create_by_id("polymorph")
	_check(pig != null and pig.card_type == Card.CardType.REACTION
		and pig.reaction_trigger == "on_enemy_fifth_debuff" and pig.jail_on_play == 25,
		"Polymorph is an instant, jailed 25 tempo")
	var take = Card.create_by_id("reapers_taking")
	_check(take != null and take.card_type == Card.CardType.REACTION
		and take.reaction_trigger == "on_enemy_low_health_nearby",
		"Reaper's Taking is an instant watching for low enemies")
	for cid in ["element_pollination", "from_the_ashes", "polymorph", "reapers_taking"]:
		_check(Card.DROP_EXCLUDED_CARD_IDS.has(cid), "%s never drops randomly" % cid)

func _test_circes_copies() -> void:
	print("-- Circe's Wand: two Polymorphs, three at Lv.3 --")
	var wand = ItemData.create_circes_wand_of_cauldron_stirring()
	_check(wand.granted_card_ids.size() == 2, "grants two copies")
	wand.item_level = 2
	wand.level_up()
	_check(wand.item_level == 3 and wand.granted_card_ids.size() == 3, "three copies at Lv.3")

func _test_reaper() -> void:
	print("-- Reaper Scythe: the reaping engine --")
	var scythe = ItemData.create_reaper_scythe()
	_check(scythe.reaper_weapon, "carries the reaper engine")
	_check(scythe.wisdom_bonus == 8 and scythe.strength_bonus == 8 and scythe.dexterity_bonus == 3
		and scythe.agility_bonus == -5, "+8 WIS, +8 STR, +3 DEX, -5 AGI")
	scythe.item_level = 2
	scythe.level_up()
	_check(scythe.wisdom_bonus == 10 and scythe.dexterity_bonus == 4, "Lv.3: +10 WIS, +4 DEX")

func _test_feral_slots() -> void:
	print("-- Feral Evocation: colored elemental slots --")
	var staff = ItemData.create_feral_evocation()
	_check(staff.feral_weapon and staff.feral_change_damage == 4, "feral engine, 4 damage per conversion")
	_check(staff.card_slots == 4 and staff.slot_colors == ["red", "blue", "yellow", "green"],
		"four slots: red, blue, yellow, green")
	# The red slot takes only a red (Burn) card.
	var ice = Card.create_by_id("ice_grenade")
	var fire = Card.create_by_id("fireball")
	_check(ice != null and ice.element == "blue" and fire != null and fire.element == "red",
		"elemental cards carry their color")
	_check(not staff.can_slot_card(ice), "a blue card cannot take the red slot")
	_check(staff.can_slot_card(fire) and staff.slot_card(fire), "a red card can")
	_check(staff.get_slot_color(fire) == "red", "and it sits in the red slot")
	_check(staff.can_slot_card(ice) and staff.slot_card(ice), "now the blue slot is next, the blue card fits")
	# A plain card never fits an elemental slot.
	var plain = Card.create_slash()
	_check(not staff.can_slot_card(plain), "an elementless card is refused")
	# Lv.3: a fifth slot, red again, and a harder lash.
	staff.item_level = 2
	staff.level_up()
	_check(staff.card_slots == 5 and staff.slot_colors.size() == 5 and str(staff.slot_colors[4]) == "red"
		and staff.feral_change_damage == 6, "Lv.3: five slots (extra red), 6 damage per conversion")
	# The element table behind the engine.
	_check(str(Card.ELEMENT_DEBUFFS.get("red", "")) == "burn" and str(Card.ELEMENT_DEBUFFS.get("green", "")) == "poison",
		"red is Burn, green is Poison")

func _test_phoenix() -> void:
	print("-- Wand of the Phoenix Feather: the self-singe --")
	var wand = ItemData.create_wand_of_the_phoenix_feather()
	_check(wand.burn_backlash_self == 1, "applying Burn singes the wielder for 1")
	_check(wand.health_bonus == 25 and wand.wisdom_bonus == 4, "+25 health, +4 WIS")
	wand.item_level = 2
	wand.level_up()
	_check(wand.health_bonus == 45, "Lv.3: +45 health")
	var weaver = ItemData.create_elemental_weaver()
	_check(weaver.elemental_charge_damage == 1 and weaver.card_slots == 0,
		"Elemental Weaver: +1 per charge woven, no card slots")
