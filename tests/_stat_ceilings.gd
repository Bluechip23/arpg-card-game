extends SceneTree

## Scratch stat-ceiling probe for the item balance review — not a test.
##
## For each core stat it builds the most extreme character the rules allow:
## level 18, every allocatable point dumped into that one stat, and then the
## highest-bonus item the inventory will accept in every slot — real carry
## gate, real slot counts, real mythic cap, real off-hand penalty. Every
## character is tried and the best ceiling wins, because slot counts differ
## (Jeremy's third ring, Cory's second gauntlet, Ryan's second belt).
##
## The point is the SECOND half of each report: what the pile costs. A stat
## ceiling only means something next to the mana, health and other stats the
## build had to give up to reach it — which is where gaps in mana on items
## show up as a flat 50-mana pool under a 90-point stat.
##
## Greedy, one pass per slot: the best item that fits wins the slot, so a very
## heavy top pick can crowd out two lighter ones. Good enough to read ceilings
## off; not an optimizer.
##
## Run: godot --headless --path . --script tests/_stat_ceilings.gd

const LEVEL := 18
const STATS := ["strength", "intelligence", "dexterity", "agility", "wisdom", "determination"]
const CHARACTERS := ["Ryan", "Jeremy", "Stephen", "Cory", "Brad"]

func _char_data(cname: String) -> CharacterData:
	match cname:
		"Ryan": return CharacterData.create_ryan()
		"Jeremy": return CharacterData.create_jeremy()
		"Stephen": return CharacterData.create_stephen()
		"Cory": return CharacterData.create_cory()
		"Brad": return CharacterData.create_brad()
	return null

func _bonus_for(item: ItemData, stat: String) -> int:
	match stat:
		"strength": return item.strength_bonus
		"dexterity": return item.dexterity_bonus
		"intelligence": return item.intelligence_bonus
		"wisdom": return item.wisdom_bonus
		"agility": return item.agility_bonus
		"determination": return item.determination_bonus
		"health": return item.health_bonus
		"mana": return item.mana_bonus
	return 0

## Every item of `types`, richest in `stat` first; ties go to the lighter one
## so the carry budget stretches further.
func _candidates(stat: String, types: Array) -> Array:
	var out: Array = []
	for it in ItemData.get_all_items():
		if it.item_type in types and it.special_id == "" and _bonus_for(it, stat) > 0:
			out.append(it)
	out.sort_custom(func(a, b):
		var ba := _bonus_for(a, stat)
		var bb := _bonus_for(b, stat)
		if ba != bb:
			return ba > bb
		return a.weight < b.weight)
	return out

## `stat` is what the greedy chases in every slot. `alloc` is where the 51
## level-up points go (defaults to the same stat; health and mana aren't
## allocatable, so those runs point it somewhere useful). `bulwark` turns on
## the Bulwark Soul keystone, the only thing besides levels and gear that
## moves max health: +2 HP per point of Determination, retroactive.
func _build(cname: String, stat: String, alloc: String = "", bulwark: bool = false) -> Dictionary:
	if alloc == "":
		alloc = stat
	var stats = PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(_char_data(cname))
	for _i in range(LEVEL - 1):
		stats._level_up()
	stats.keystone_det_vitality = bulwark
	stats.apply_stat_allocation({alloc: stats.unspent_stat_points})
	stats.refresh_det_vitality()
	var inv = Inventory.new()
	get_root().add_child(inv)
	inv.initialize(cname)
	inv.connect_player_stats(stats)

	# Hands last: they are the heaviest slots, and a hand item's off-hand
	# penalty makes it the least efficient place to chase a stat anyway.
	var plan := [
		[[ItemData.ItemType.HELM], 1],
		[[ItemData.ItemType.CHEST], 1],
		[[ItemData.ItemType.BELT], inv.belt_slots],
		[[ItemData.ItemType.BOOTS], 1],
		[[ItemData.ItemType.GAUNTLETS], inv.gauntlets_slots],
		[[ItemData.ItemType.RING], inv.ring_slots],
		[[ItemData.ItemType.WEAPON, ItemData.ItemType.QUIVER], inv.weapon_slots],
	]
	var worn: Array = []
	for entry in plan:
		var pool := _candidates(stat, entry[0])
		var slot := 0
		for cand in pool:
			if slot >= int(entry[1]):
				break
			# Fresh instance: get_all_items hands out one shared copy per item.
			var fresh = ItemData.create_by_name(cand.item_name)
			if fresh and inv.equip_item(fresh, slot):
				worn.append(fresh)
				slot += 1

	var gear_mana := 0
	var gear_health := 0
	var mana_sources: Array[String] = []
	for it in worn:
		gear_mana += it.mana_bonus
		gear_health += it.health_bonus
		if it.mana_bonus != 0:
			mana_sources.append("%s %+d" % [it.item_name, it.mana_bonus])
	# Bulwark Soul is retroactive, so re-sync after the gear moved Determination.
	stats.refresh_det_vitality()
	var headline: int = stats.max_health if stat == "health" \
		else (stats.max_mana if stat == "mana" else stats.get_base_stat(stat))
	var result := {
		"who": cname, "stat": stat, "worn": worn,
		"value": headline,
		# health and mana are pools, not stats — nothing to read a modified
		# value off, so the headline is the whole story for those runs.
		"effective": headline if stat in ["health", "mana", "determination"] else int(stats.get(stat)),
		"max_mana": stats.max_mana, "gear_mana": gear_mana,
		"max_health": stats.max_health, "gear_health": gear_health,
		"mana_sources": mana_sources,
		"regen": stats.get_effective_mana_regen(),
		"carry": stats.current_carry_load, "cap": stats.get_carry_capacity(),
		"all": "STR %d DEX %d INT %d WIS %d DET %d AGI %d" % [stats.strength, stats.dexterity,
			stats.intelligence, stats.wisdom, stats.determination, stats.agility],
	}
	stats.free()
	inv.free()
	return result

func _initialize() -> void:
	var summary: Array[String] = []
	for stat in STATS:
		var runs: Array = []
		for cname in CHARACTERS:
			runs.append(_build(cname, stat))
		runs.sort_custom(func(a, b): return a["value"] > b["value"])
		var best: Dictionary = runs[0]

		print("\n================ MAX %s ================" % stat.to_upper())
		var ladder: Array[String] = []
		for r in runs:
			ladder.append("%s %d" % [r["who"], r["value"]])
		print("  Ceiling by character: %s" % "  |  ".join(ladder))
		print("  BEST: %s at %s %d" % [best["who"], stat.to_upper(), best["value"]])
		var names: Array[String] = []
		for it in best["worn"]:
			names.append("%s (%s %+d, w%d)" % [it.item_name, stat.substr(0, 3).to_upper(),
				_bonus_for(it, stat), it.weight])
		print("  GEAR: %s" % ", ".join(names))
		print("  ALL STATS: %s" % best["all"])
		print("  MANA: %d total (%d of it from gear) | regen %.0f" % [
			best["max_mana"], best["gear_mana"], best["regen"]])
		print("  MANA FROM: %s" % (", ".join(best["mana_sources"]) if not best["mana_sources"].is_empty() else "NOTHING — the whole pile carries no mana"))
		print("  HEALTH: %d (%+d from gear) | Carry %d/%d" % [
			best["max_health"], best["gear_health"], best["carry"], best["cap"]])
		summary.append("%-14s %3d   mana %3d (%+3d gear)   hp %3d   %s" % [
			stat, best["value"], best["max_mana"], best["gear_mana"], best["max_health"], best["who"]])

	print("\n================ SUMMARY ================")
	print("  %-14s %3s   %-18s %6s" % ["stat", "max", "mana pool", "health"])
	for line in summary:
		print("  %s" % line)
	_resource_ceiling("health")
	_resource_ceiling("mana")
	_resource_census("mana")
	_resource_census("health")
	quit(0)

## The pool ceilings: the most health, and the most mana, a level-18 character
## can actually reach. Health is chased two ways — with and without Bulwark
## Soul (+2 HP per Determination point), which is the only non-gear, non-level
## source in the game, and which pulls the allocation onto Determination.
func _resource_ceiling(which: String) -> void:
	print("\n================ MAX %s ================" % which.to_upper())
	var runs: Array = []
	for cname in CHARACTERS:
		if which == "health":
			runs.append(_build(cname, "health", "determination", false))
			var bw := _build(cname, "health", "determination", true)
			bw["who"] = "%s + Bulwark Soul" % cname
			runs.append(bw)
		else:
			# Nothing allocatable raises the mana POOL, so the points go to INT
			# for regen — the number that says whether the pool is worth having.
			runs.append(_build(cname, "mana", "intelligence", false))
	runs.sort_custom(func(a, b): return a["value"] > b["value"])
	var ladder: Array[String] = []
	for r in runs:
		ladder.append("%s %d" % [r["who"], r["value"]])
	print("  Ceiling by character: %s" % "  |  ".join(ladder))
	var best: Dictionary = runs[0]
	print("  BEST: %s at %d %s" % [best["who"], best["value"], which])
	var names: Array[String] = []
	for it in best["worn"]:
		var amt := _bonus_for(it, which)
		if amt != 0:
			names.append("%s %+d" % [it.item_name, amt])
	print("  FROM: %s" % ", ".join(names))
	print("  (base pool without gear: %d)" % [best["value"] - (best["gear_health"] if which == "health" else best["gear_mana"])])
	print("  ALL STATS: %s" % best["all"])
	print("  The other pool: %s | Carry %d/%d" % [
		("mana %d" % best["max_mana"]) if which == "health" else ("health %d" % best["max_health"]),
		best["carry"], best["cap"]])
	if which == "mana":
		print("  Regen %.0f per tick — the pool is %.1f ticks deep." % [
			best["regen"], float(best["value"]) / maxf(1.0, best["regen"])])

## Which slots can carry a resource at all, and how much the best item in each
## is worth. This is the other half of the picture: a stat ceiling only strands
## a build at the base pool because most slots have nothing to offer.
func _resource_census(which: String) -> void:
	print("\n================ %s CENSUS ================" % which.to_upper())
	var type_names := {
		ItemData.ItemType.HELM: "Helm", ItemData.ItemType.CHEST: "Chest",
		ItemData.ItemType.BELT: "Belt", ItemData.ItemType.BOOTS: "Boots",
		ItemData.ItemType.GAUNTLETS: "Gauntlets", ItemData.ItemType.WEAPON: "Weapon/Shield",
		ItemData.ItemType.QUIVER: "Quiver", ItemData.ItemType.RING: "Ring",
	}
	var all := ItemData.get_all_items()
	var with_it := 0
	var grand := 0
	for t in type_names:
		var total := 0
		var carriers := 0
		var sum := 0
		var best := 0
		var best_name := "-"
		for it in all:
			if it.item_type != t or it.special_id != "":
				continue
			total += 1
			var amount: int = it.mana_bonus if which == "mana" else it.health_bonus
			if amount > 0:
				with_it += 1
				carriers += 1
				sum += amount
				grand += amount
				if amount > best:
					best = amount
					best_name = it.item_name
		print("  %-14s %2d/%2d items carry %s | best %+d (%s) | avg over the whole slot %+.1f" % [
			type_names[t], carriers, total, which, best, best_name,
			float(sum) / float(maxi(1, total))])
	print("  ---")
	print("  %d of %d items carry any %s at all — %d points across the catalog." % [
		with_it, all.size(), which, grand])
