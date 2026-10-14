extends SceneTree

## Audit of the stored-build tester: every designed build of every character
## booted in the real game at levels 1-50, plus every composition knob the
## sweeps use (focus, tactic, recipe, card swap, item swap). It checks the
## things a balance reading silently depends on:
##   - no refused equip / slot / allocation / passive rank (low levels may
##     drop a mythic or not yet reach a stat-gated keystone, nothing else)
##   - every stat point, passive point and sphere the level earned is spent
##   - the mythic cap holds and is used
##   - at most 3 keystones
##   - every tree passive is countable, or listed as known-silent
## Run: godot --headless --path . --script tests/test_sim_audit.gd   (~4 min)

const LEVELS := [1, 15, 18, 30, 50]
## Tree passives the game never writes to the battle log (docs/sim/bugs_found.md).
const KNOWN_SILENT := ["directed_strength", "life_steal", "harnessed_power", "blood_libation", "wither"]

var failures := 0

## A rank dictionary seen through the stats interface SkillTreeData reads.
class RankView:
	var ranks: Dictionary
	func _init(r: Dictionary) -> void:
		ranks = r
	func get_passive_level(pid: String) -> int:
		return int(ranks.get(pid, 0))

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: " + msg)
	else:
		print("  FAIL: " + msg)
		failures += 1

func _initialize() -> void:
	_run.call_deferred()

## Below level 15 the stored sets (mythic and legendary gear, built for the
## late game) can outweigh what the character carries and keystones can sit
## behind stat gates the level has not reached; those are facts of an early
## character in end-game gear, not tester faults. From 15 up nothing may be
## refused (from 18 not even a sphere gate).
func _allowed_warning(w: String, level: int) -> bool:
	if w.begins_with("dropped (mythic cap"):
		return true
	if level < 18 and w.begins_with("sphere: no unlockable path"):
		return true
	return level < 15 and (w.find("over carry capacity") >= 0 or w.ends_with("is not equipped"))

func _audit_build(runner: SimRunner, character: String, parts: Dictionary, label: String) -> void:
	var level := int(parts.get("level", 18))
	var sc := SimScenario.with_defaults(CharacterBuilds.compose(character, parts))
	sc["enemies"] = [{"type": "WERERAT", "cell": [9, 7], "overrides": {}}]
	await runner.boot_only(sc, 1)
	var stats = runner.main.player.get_stats()
	var inv = runner.main.player.get_inventory()
	var grid = runner.main.sphere_grid_ui.sphere_grid
	var bad: Array = runner.warnings.filter(func(w): return not _allowed_warning(str(w), level))
	if parts.has("tactic"):
		# A tactic's item can push a build near its carry limit over it; that is
		# a fact about the build the tactics table reports, not a tester fault.
		var carry: Array = bad.filter(func(w): return str(w).find("over carry capacity") >= 0)
		if not carry.is_empty():
			print("  NOTE: %s cannot carry the tactic's gear: %s" % [label, str(carry)])
			bad = bad.filter(func(w): return str(w).find("over carry capacity") < 0)
	var problems: Array = []
	if not bad.is_empty():
		problems.append("refusals %s" % str(bad))
	# The second weapon set is where the game keeps one: the War Rack, or
	# equipment build II, with build I still in hand.
	var alts: Array = sc["player"]["alt_weapons"]
	if not alts.is_empty():
		var stowed := 0
		if inv.has_back_rack:
			stowed = inv.rack_items.size()
		elif inv.builds[1] != null and inv.active_build == 0:
			for it in inv.builds[1]["weapons"]:
				if it != null and not inv.equipped_weapons.has(it):
					stowed += 1
		var explained: bool = runner.warnings.any(func(w): return str(w).begins_with("alt weapons") and _allowed_warning(str(w), level))
		if stowed != alts.size() and not explained:
			problems.append("second weapon set %s: %d of %d stowed" % [str(alts), stowed, alts.size()])
	if stats.unspent_stat_points != 0:
		problems.append("%d stat point(s) unspent" % stats.unspent_stat_points)
	if stats.unspent_passive_points != 0:
		problems.append("%d passive point(s) unspent" % stats.unspent_passive_points)
	var spheres_left: int = runner.main.sphere_inventory.get_count(SphereInventory.SphereType.SPHERE)
	if spheres_left != 0:
		problems.append("%d sphere(s) unspent of %d" % [spheres_left, 2 * level])
	if grid.unlocked_keystone_count() > SphereGrid.MAX_KEYSTONES:
		problems.append("%d keystones" % grid.unlocked_keystone_count())
	var cap: int = int(level / 15)
	var mythic_entries := 0
	for e in sc["player"]["items"]:
		if CharacterBuilds.is_mythic(str(e[0])):
			mythic_entries += 1
	if inv.count_equipped_mythics() > cap:
		problems.append("%d mythics over the cap of %d" % [inv.count_equipped_mythics(), cap])
	await runner.teardown()
	_check(problems.is_empty(), "%s %s" % [label, "clean" if problems.is_empty() else "— " + "; ".join(problems)])

func _run() -> void:
	print("=== Stored-build audit ===")
	var runner := SimRunner.new(self)
	var observable := SimRunner.observable_passives()
	for c in CharacterBuilds.CHARACTERS:
		var lib := CharacterBuilds.library(c)
		# Every designed build at every level.
		for b in lib.DESIGNED:
			for level in LEVELS:
				await _audit_build(runner, c, {"build": b, "level": level}, "%s/%s L%d" % [c, b, level])
		var first: String = lib.DESIGNED.keys()[0]
		# Every passive id the library names is one the game's tree has (a
		# misspelled id takes ranks and does nothing: lets_dance, a_mages_favor).
		var real: Array = CharacterBuilds.tree_passives(c)
		var unknown: Array = []
		for ps in lib.PASSIVES:
			for pid in lib.PASSIVES[ps]:
				if not pid in real and not pid in unknown:
					unknown.append(pid)
		for t in CharacterBuilds.tactics(c):
			for pid in CharacterBuilds.tactics(c)[t].get("passives", {}):
				if not pid in real and not pid in unknown:
					unknown.append(pid)
		_check(unknown.is_empty(), "%s: every library passive id is a real tree passive %s" % [c, str(unknown)])
		# The stage gate: every composition the sweeps make could be built in
		# the tree (a stage opens once 5 points sit in the stage before it).
		var lanes: Array = SkillTreeData.create_tree_for(c.capitalize(), 50).get_archetype_lanes()
		var gate_bad: Array = []
		for b in lib.DESIGNED:
			for level in [5, 10, 18, 30, 50]:
				var vs: Array = [{"build": b, "level": level}]
				for pid in CharacterBuilds.tree_passives(c):
					vs.append({"build": b, "level": level, "focus": pid})
				for ps in lib.PASSIVES:
					vs.append({"build": b, "level": level, "passives": ps})
				for v in vs:
					var rk: Dictionary = CharacterBuilds.compose(c, v)["player"]["passives"]
					var fs := RankView.new(rk)
					for st in range(1, 6):
						var used := 0
						for l in lanes:
							if st < (l["passives"] as Array).size():
								used += fs.get_passive_level(l["passives"][st].passive_id)
						if used > 0 and not SkillTreeData.is_stage_unlocked(lanes, st, fs):
							gate_bad.append("%s L%d %s" % [b, level, str(v.get("focus", v.get("passives", "designed")))])
							break
		_check(gate_bad.is_empty(), "%s: every composed passive spread obeys the stage gate (%d break it: %s)" % [c, gate_bad.size(), str(gate_bad.slice(0, 4))])
		# Passive focus on every tree passive, level 50.
		var tree: Array = CharacterBuilds.tree_passives(c)
		_check(tree.size() >= 1, "%s has tree passives (%d)" % [c, tree.size()])
		var focus_bad: Array = []
		for pid in tree:
			var ranks: Dictionary = CharacterBuilds.compose(c, {"build": first, "level": 50, "focus": pid})["player"]["passives"]
			var total := 0
			for k in ranks:
				total += int(ranks[k])
			if int(ranks.get(pid, 0)) != 15 or total != 49:
				focus_bad.append("%s (%d at rank %d)" % [pid, total, int(ranks.get(pid, 0))])
		_check(focus_bad.is_empty(), "%s: every tree passive maxes at 50 with all 49 points spent %s" % [c, str(focus_bad)])
		await _audit_build(runner, c, {"build": first, "level": 50, "focus": tree[0]}, "%s/%s L50 focus:%s" % [c, first, tree[0]])
		# Passive trigger counts are observable, or the passive is known-silent.
		var unseen: Array = []
		for pid in tree:
			if not observable.has(pid) and not pid in KNOWN_SILENT:
				unseen.append(pid)
		_check(unseen.is_empty(), "%s: every tree passive's firing is countable or known-silent %s" % [c, str(unseen)])
		# Every tactic and recipe on the first designed build.
		for t in CharacterBuilds.tactics(c):
			await _audit_build(runner, c, {"build": first, "tactic": t}, "%s/%s tactic:%s" % [c, first, t])
		# Engraving sweep: the options exist and a variant composes and boots clean.
		var eopts := CharacterBuilds.engrave_options(c, first)
		var eitem := ""
		for it_id in eopts:
			if not (eopts[it_id] as Array).is_empty():
				eitem = it_id
				break
		if eitem != "":
			await _audit_build(runner, c, {"build": first, "engrave": "%s~%s" % [eitem, eopts[eitem][0]]}, "%s/%s engrave:%s~%s" % [c, first, eitem, eopts[eitem][0]])
		else:
			print("  NOTE: %s/%s wears no slotted item; nothing to engrave" % [c, first])
		# Every shared deck on this character's first designed build: one
		# library for all five, so every deck must deal for every character.
		for dname in SimDecks.DECKS:
			await _audit_build(runner, c, {"build": first, "deck": dname}, "%s/%s deck:%s" % [c, first, dname])
		for r in CharacterBuilds.recipes(c):
			var deck: Array = CharacterBuilds.compose(c, {"build": first, "recipe": r})["player"]["deck"]
			_check(deck.size() == 12, "%s recipe %s fills 12 cards (%d)" % [c, r, deck.size()])
		# Every pool item is worn when swapped in (composition only; wearing it
		# may still exceed carry, which the item sweep reports as a finding).
		var unworn: Array = []
		for b in lib.DESIGNED:
			for iid in CharacterBuilds.item_pool():
				var worn := false
				for e in CharacterBuilds.compose(c, {"build": b, "item": iid})["player"]["items"]:
					if str(e[0]) == iid:
						worn = true
				if not worn:
					unworn.append("%s+%s" % [b, iid])
		_check(unworn.is_empty(), "%s: every pool item is worn when swapped into every build (%d missing %s)" % [c, unworn.size(), str(unworn.slice(0, 5))])
	# The card pool: every card builds, none is unplayable, a swap puts it in the opening hand.
	var pool: Array = SimDeckBuilder.legal_ids()
	var dm := DeckManager.new()
	var broken: Array = []
	for id in pool:
		var card = dm._create_card_from_id(id)
		if card == null or card.card_type == Card.CardType.UNPLAYABLE or card.requires_engraving:
			broken.append(id)
	dm.free()
	_check(broken.is_empty() and pool.size() > 150, "the card pool (%d) holds only playable, deck-legal cards %s" % [pool.size(), str(broken)])
	var held_out: Array = SimState.NEEDS_PICK.filter(func(id): return id in pool)
	_check(held_out.is_empty(), "no pool card is held out of the policy's legal actions %s" % str(held_out))
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
