class_name NewCardsE
extends RefCounted

## New sheet cards, batch E — the big spells, zones and summon cards:
## Ward of Hallow Glass, The Ledger, Both Sides of the Candle, Thickened
## Nature, Flames of Alexandria, Surprise Pick Up, Inspiring Whistle and
## Stoked Pride. The shared files only carry one-line hooks into here
## (Card._execute_card, DeckManager.greedy_tax, BuffManager.sync_flag_buffs,
## Summon.take_damage, Enemy._deal_damage_to_player and main's play /
## resolve / tempo / world-effect steps). docs/new_cards/E.md is the
## reference entry for each card, with the open questions.
##
## State: a hero's standing effects ride as metadata on their PlayerStats
## (they end with the character object, nothing to reset between scenes);
## the zones and crates on the field ride on Main.

const CARD_IDS := ["ward_of_hallow_glass", "the_ledger", "both_sides_of_the_candle",
	"thickened_nature", "flames_of_alexandria", "surprise_pick_up", "inspiring_whistle",
	"stoked_pride"]

# ---- PlayerStats metadata keys ----
const WARD_TEMPO := "nce_ward_tempo"        # int: tempo left on the Ward's window
const LEDGER_ON := "nce_ledger_on"          # bool: The Ledger stands
const LEDGER_BANK := "nce_ledger_bank"      # float: banked damage (fractions kept)
const CANDLE := "nce_candle_charges"        # int: attacks left on the Candle
const PRIDE_MARK := "nce_pride_mark"        # the caster (Player) of a waiting Stoked Pride mark
const PRIDE_LION := "nce_pride_lion"        # the lion guarding this hero

# ---- Main metadata keys ----
const FOGS := "nce_fogs"                    # [{cells, tempo, nodes}]
const CRATES := "nce_crates"                # [{cell, node, standing, overlay, taken}]

# ---- Numbers off the sheet ----
const WARD_BASE_ARMOR := 6
const WARD_WINDOW := 10
const WARD_TEMPO_CUT := 1
const LEDGER_SHARE := 0.10
const CANDLE_ATTACKS := 5
const CANDLE_TEMPO_CUT := 2
const CANDLE_BURN := 8
const CANDLE_SELF_SHARE := 0.10
const FOG_TEMPO := 15
const FOG_ROOT := 5
const FLAMES_DRAW := 10
const FLAMES_DAMAGE := 3
const FLAMES_HALF_ANGLE := 30.0             # the cone the AoE indicator draws (60 degrees)
const CRATE_STAND_TEMPO := 5
const CRATE_AMOUNT := 20
const CRATE_BUFF_TEMPO := 10                # Keen's clock; the sheet gives none (flagged)
const CRATE_TEMP_HP_TEMPO := 15             # the sheet gives none (flagged)
const WHISTLE_STEPS := 3
const WHISTLE_BRACE := 30
const WHISTLE_HITS := 2
const LION_HP := 30                         # the sheet gives the lion no stats (flagged)
const LION_GUARD_RANGE := 2


static func _meta(obj, key: String, default = null):
	if obj == null or not obj.has_meta(key):
		return default
	return obj.get_meta(key)


static func _list(main, key: String) -> Array:
	if not main.has_meta(key):
		main.set_meta(key, [])
	return main.get_meta(key)


static func _sync(p) -> void:
	if p and is_instance_valid(p) and p.has_method("get_buff_manager"):
		var bm = p.get_buff_manager()
		if bm:
			bm.sync_flag_buffs()


## Drop every batch E effect a hero carries (tests; a fresh start).
static func clear_stats(stats) -> void:
	if stats == null:
		return
	for k in [WARD_TEMPO, LEDGER_ON, LEDGER_BANK, CANDLE, PRIDE_MARK, PRIDE_LION]:
		if stats.has_meta(k):
			stats.remove_meta(k)


# =====================================================================
# Hooks
# =====================================================================

## DeckManager.greedy_tax: the tempo these effects take off `card` right now
## (the hand face and the play both read the tax, so the cut shows on the
## card and is what the play pays). Never more than the card costs.
static func tempo_cut(card: Card, stats) -> int:
	if card == null or stats == null:
		return 0
	var cut := 0
	# Ward of Hallow Glass: while its window runs AND armor is up.
	if int(_meta(stats, WARD_TEMPO, 0)) > 0 and stats.get_total_armor() > 0 \
			and card.school == Card.CardSchool.SPELL and card.is_offensive():
		cut += WARD_TEMPO_CUT
	# Both Sides of the Candle: the next attacks (the Attack shape).
	if int(_meta(stats, CANDLE, 0)) > 0 and card.is_attack():
		cut += CANDLE_TEMPO_CUT
	return mini(cut, card.get_burden_tempo_cost())


## BuffManager.sync_flag_buffs: the badges.
static func sync_badges(bm) -> void:
	var st = bm.owner_stats
	var ward: int = int(_meta(st, WARD_TEMPO, 0))
	bm._sync_generic("ward_of_hallow_glass", ward > 0, "Ward of Hallow Glass",
		"While you have armor, your offensive spells cost 1 less tempo (%d tempo left)" % ward,
		Color(0.55, 0.8, 0.95), ward, 1)
	var bank: int = floori(float(_meta(st, LEDGER_BANK, 0.0)))
	bm._sync_generic("the_ledger", bool(_meta(st, LEDGER_ON, false)), "The Ledger",
		"Banked: %d. Direct hits of your offensive cards bank 10%% of their damage; playing a Defense card heals you for the bank." % bank,
		Color(0.85, 0.7, 0.3), -1, bank)
	var candle: int = int(_meta(st, CANDLE, 0))
	bm._sync_generic("both_sides_of_the_candle", candle > 0, "Both Sides of the Candle",
		"Next %d attacks: -2 tempo, 8 Burn on the enemy hit, and you take 10%% of your max health" % candle,
		Color(0.95, 0.5, 0.2), -1, candle)
	var marked: bool = st != null and st.has_meta(PRIDE_MARK)
	var lion = _meta(st, PRIDE_LION)
	var guarded: bool = lion != null and is_instance_valid(lion) and not lion.is_dead
	bm._sync_generic("stoked_pride", marked or guarded, "Stoked Pride",
		"A lion stands guard: within 2 squares it takes enemy attacks aimed at you" if guarded
			else "The next enemy attack on you summons a lion that takes it instead",
		Color(0.9, 0.75, 0.35), -1, 1)


## Card._execute_card: Ward of Hallow Glass. The armor is a Defense card's
## block (6 + INT / 2), granted through Card._execute_block so every defense
## rider reads it (on-self block, Thick Steel, Empower's cut...).
static func execute_ward(card: Card, stats, buff_mgr, is_empowered: bool) -> void:
	if stats == null:
		return
	var int_half: int = floori(stats.intelligence / 2.0)
	card.block += int_half
	card._execute_block(stats, is_empowered, buff_mgr)
	card.block -= int_half
	stats.set_meta(WARD_TEMPO, WARD_WINDOW)
	if buff_mgr:
		buff_mgr.sync_flag_buffs()


## main.play_selected_card, once the play went through: a Candle charge is
## spent as the attack is PLAYED (like Tighten String: attacks queued before
## the first resolves each take their own charge), and the play remembers it.
static func on_card_played(main, card: Card, data: Dictionary) -> void:
	if main.player == null:
		return
	var stats = main.player.get_stats()
	var left: int = int(_meta(stats, CANDLE, 0))
	if left > 0 and card.is_attack():
		stats.set_meta(CANDLE, left - 1)
		data["nce_candle"] = true
		_sync(main.player)


## main._resolve_queued_card, before the card executes: what every living
## enemy has (health + armor), so post_card can tell what the card dealt.
static func pre_card(main, card: Card, data: Dictionary) -> Dictionary:
	var snap := {}
	if main.player == null or main.enemy_spawner == null or not card.is_offensive():
		return snap
	var stats = main.player.get_stats()
	if not bool(_meta(stats, LEDGER_ON, false)) and not data.get("nce_candle", false):
		return snap
	for e in main.enemy_spawner.get_living_enemies():
		if is_instance_valid(e):
			snap[e] = maxi(0, int(e.current_health)) + maxi(0, int(e.current_armor))
	return snap


## main._resolve_queued_card, after the card's executor and world effects.
static func post_card(main, card: Card, data: Dictionary, snap: Dictionary) -> void:
	if main.player == null:
		return
	var caster = main.player
	var stats = caster.get_stats()
	if stats == null:
		return
	var total := 0
	var hit: Array = []
	for e in snap:
		if not is_instance_valid(e):
			total += int(snap[e])
			continue
		var lost: int = int(snap[e]) - (maxi(0, int(e.current_health)) + maxi(0, int(e.current_armor)))
		if lost > 0:
			total += lost
			hit.append(e)
	# The Ledger: a direct hit of an offensive card banks 10% of the health
	# and armor damage it actually dealt (fractions kept, so small hits add up).
	if bool(_meta(stats, LEDGER_ON, false)):
		if card.is_offensive() and total > 0:
			stats.set_meta(LEDGER_BANK, float(_meta(stats, LEDGER_BANK, 0.0)) + total * LEDGER_SHARE)
		# ...and playing a Defense card (the type or the tag) spends it as healing.
		if card.card_type == Card.CardType.DEFENSE or card.has_keyword("defense"):
			var bank: int = floori(float(_meta(stats, LEDGER_BANK, 0.0)))
			if bank > 0:
				stats.set_meta(LEDGER_BANK, 0.0)
				stats.heal(bank)
				main.add_battle_log("The Ledger: the bank pays out — %d healing." % bank, Color(0.85, 0.7, 0.3))
		_sync(caster)
	# Both Sides of the Candle: the enemy hit burns, the attacker pays.
	if data.get("nce_candle", false):
		for e in hit:
			if not e.is_dead:
				e.apply_debuff("burn", CANDLE_BURN)
		# Straight off health: armor does not take it and nothing reduces it.
		var pay: int = maxi(1, floori(stats.max_health * CANDLE_SELF_SHARE))
		stats.take_direct_damage(pay)
		main.add_battle_log("Both Sides of the Candle: %d Burn, and %d of your own health." % [CANDLE_BURN, pay], Color(0.95, 0.5, 0.2))
		_sync(caster)


## main._process_tempo_tick: the clocks.
static func on_tempo(main, amount: int) -> void:
	if amount <= 0:
		return
	for p in main._all_allies():
		if not is_instance_valid(p) or not p.has_method("get_stats"):
			continue
		var st = p.get_stats()
		var ward: int = int(_meta(st, WARD_TEMPO, 0))
		if ward > 0:
			st.set_meta(WARD_TEMPO, maxi(0, ward - amount))
			_sync(p)
	_tick_fogs(main, amount)
	_tick_crates(main, amount)
	_lead_lions(main)


## main._on_all_enemies_defeated: the fight is over. The Ledger lasts "the
## rest of the fight"; the fog lifts with the other zones. Crates, marks
## and lions stay (one continuous journey).
static func on_battle_end(main) -> void:
	for p in main._all_allies():
		if is_instance_valid(p) and p.has_method("get_stats") and p.get_stats():
			var st = p.get_stats()
			for k in [LEDGER_ON, LEDGER_BANK]:
				if st.has_meta(k):
					st.remove_meta(k)
			_sync(p)
	clear_fogs(main)


## main._apply_card_world_effects_inner: true when the card was one of ours.
static func world_effects(main, card: Card, target, mouse_pos: Vector3) -> bool:
	match card.card_id:
		"the_ledger":
			_play_ledger(main)
		"both_sides_of_the_candle":
			_play_candle(main, target)
		"thickened_nature":
			_play_fog(main, mouse_pos)
		"flames_of_alexandria":
			_play_flames(main, card, mouse_pos)
		"surprise_pick_up":
			_play_crate(main, mouse_pos)
		"inspiring_whistle":
			_play_whistle(main, target)
		"stoked_pride":
			_play_pride(main, target)
		"ward_of_hallow_glass":
			pass  # all card-side (execute_ward)
		_:
			return false
	return true


# =====================================================================
# The Ledger
# =====================================================================

static func _play_ledger(main) -> void:
	var stats = main.player.get_stats()
	if stats == null:
		return
	stats.set_meta(LEDGER_ON, true)
	if not stats.has_meta(LEDGER_BANK):
		stats.set_meta(LEDGER_BANK, 0.0)
	_sync(main.player)
	main.add_battle_log("The Ledger opens: your offensive cards' hits bank 10% of their damage.", Color(0.85, 0.7, 0.3))


# =====================================================================
# Both Sides of the Candle
# =====================================================================

static func _play_candle(main, target) -> void:
	var who = target if (target is Player and is_instance_valid(target)) else main.player
	var stats = who.get_stats()
	if stats == null:
		return
	stats.set_meta(CANDLE, CANDLE_ATTACKS)  # a recast refreshes the count, it does not add
	_sync(who)
	main.add_battle_log("Both Sides of the Candle: %s's next %d attacks burn at both ends." % [main._ally_display_name(who), CANDLE_ATTACKS], Color(0.95, 0.5, 0.2))


# =====================================================================
# Thickened Nature (fog zone)
# =====================================================================

static func _play_fog(main, mouse_pos: Vector3) -> void:
	var gm = main.grid_manager
	var center: Vector2i = gm.world_to_grid(gm.snap_to_grid(mouse_pos))
	var cells: Array = []
	var nodes: Array = []
	# "A diameter of 3 squares": the aimed tile and the eight around it.
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var c := center + Vector2i(dx, dz)
			cells.append(c)
			# No fog art in the packs: the Territorial Mark's ground smoke,
			# paled to grey (docs/new_cards/E.md).
			var n: Node3D = main._make_mark_smoke_visual(gm.grid_to_world(c))
			var mat := n.material_override as StandardMaterial3D
			if mat:
				mat.albedo_color = Color(0.82, 0.86, 0.84, 0.5)
				mat.emission = Color(0.7, 0.75, 0.72)
				mat.emission_energy_multiplier = 0.3
			main.add_child(n)
			nodes.append(n)
	_list(main, FOGS).append({"cells": cells, "tempo": FOG_TEMPO, "nodes": nodes})
	main.add_battle_log("A dense fog settles (%d tempo)." % FOG_TEMPO, Color(0.8, 0.85, 0.82))
	_slow_enemies_in_fog(main)


static func in_fog(main, cell: Vector2i) -> bool:
	for z in _list(main, FOGS):
		if cell in z["cells"]:
			return true
	return false


## "Enemies inside are Slowed 1": held at one stack while they stand in it,
## never piled up tick after tick.
static func _slow_enemies_in_fog(main) -> void:
	if main.enemy_spawner == null or _list(main, FOGS).is_empty():
		return
	for e in main.enemy_spawner.get_living_enemies():
		if is_instance_valid(e) and e.slow_stacks < 1 and in_fog(main, main.grid_manager.world_to_grid(e.position)):
			e.apply_debuff("slow", 1)


static func _tick_fogs(main, amount: int) -> void:
	var fogs: Array = _list(main, FOGS)
	if fogs.is_empty():
		return
	var survivors: Array = []
	for z in fogs:
		z["tempo"] -= amount
		if z["tempo"] > 0:
			survivors.append(z)
		else:
			for n in z["nodes"]:
				if is_instance_valid(n):
					n.queue_free()
	main.set_meta(FOGS, survivors)
	_slow_enemies_in_fog(main)


static func clear_fogs(main) -> void:
	for z in _list(main, FOGS):
		for n in z["nodes"]:
			if is_instance_valid(n):
				n.queue_free()
	main.set_meta(FOGS, [])


## main._on_enemy_movement_completed: an enemy that ends a move in the fog
## is Rooted 5.
static func on_enemy_move_end(main, enemy) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.is_dead or not main.has_meta(FOGS):
		return
	if in_fog(main, main.grid_manager.world_to_grid(enemy.position)):
		enemy.apply_debuff("root", FOG_ROOT)
		if enemy.slow_stacks < 1:
			enemy.apply_debuff("slow", 1)


# =====================================================================
# Flames of Alexandria
# =====================================================================

static func _play_flames(main, card: Card, mouse_pos: Vector3) -> void:
	var caster = main.player
	var dm = main.deck_manager
	if caster == null or dm == null:
		return
	# The cone faces where the caster aimed as the spell resolved (their
	# heading when the aim sits on their own tile).
	var diff: Vector3 = mouse_pos - caster.position
	var dir := Vector3(diff.x, 0, diff.z)
	if dir.length() < 0.05:
		var h: Vector2i = caster.get_heading()
		dir = Vector3(h.x, 0, h.y)
	dir = dir.normalized()
	# 1. The whole hand is discarded (true discards: on-discard effects fire).
	for c in dm.hand.duplicate():
		dm.discard_card_from_hand(c)
	# 2. The discard pile is shuffled into the draw pile — all but this card,
	# which is still being played: it stays out until the draws are done, so
	# a draw that empties the pile cannot reshuffle and draw the spell itself.
	var own: int = dm.discard_pile.find(card)
	if own >= 0:
		dm.discard_pile.remove_at(own)
	dm.shuffle_discard_into_draw()
	# 3. Draw 10, as Balance of Alnilam draws its 10: ordinary draws, so the
	# hand cap holds and the draws past it are overdraws.
	var drawn: Array = []
	for _i in range(FLAMES_DRAW):
		var d = dm.draw_card()
		if d != null and d in dm.hand:
			drawn.append(d)
	if own >= 0:
		dm.discard_pile.append(card)
	dm.hand_updated.emit()
	# 4. Choose any number of them to burn.
	var finish := func(picks: Array): flames_finish(main, caster, dm, card, picks, dir)
	if drawn.is_empty():
		finish.call([])
		return
	main.show_full_card_picker("Flames of Alexandria — discard any number (3 fire damage in the cone and 1 Burn on you for each)",
		drawn, -drawn.size(), finish, func(): finish.call([]))


## The chosen cards burn: for each, 3 fire damage (INT-scaled, a hit of its
## own) to every enemy in the cone and 1 Burn on the caster.
static func flames_finish(main, caster, dm, card: Card, picks: Array, dir: Vector3) -> void:
	if not is_instance_valid(main) or not is_instance_valid(caster):
		return
	var n := 0
	for p in picks:
		if p in dm.hand and dm.discard_card_from_hand(p):
			n += 1
	if n <= 0:
		main.add_battle_log("Flames of Alexandria: nothing is fed to the fire.", Color(1.0, 0.6, 0.3))
		return
	var stats = caster.get_stats()
	var length: float = card.aoe_range * main.grid_manager.grid_size
	SearingFireFX.play(main, caster.position + main.CAST_MIDSECTION, dir, card.aoe_range)
	var per_hit: int = stats.get_effective_spell_damage(FLAMES_DAMAGE) if stats else FLAMES_DAMAGE
	var burned: Array = []
	if main.enemy_spawner:
		burned = main.enemy_spawner.get_enemies_in_cone(caster.position, dir, length, FLAMES_HALF_ANGLE)
	for e in burned:
		for _i in range(n):
			if is_instance_valid(e) and not e.is_dead:
				e.take_damage(per_hit, true, DamageTypes.Type.FIRE)
	var cdm = caster.get_debuff_manager()
	if cdm:
		for _i in range(n):
			cdm.apply_debuff(Debuff.new(Debuff.DebuffType.BURN, 1))
	main.add_battle_log("Flames of Alexandria: %d card%s burned — %d x %d fire to %d enem%s, %d Burn on you." % [
		n, "" if n == 1 else "s", n, per_hit, burned.size(), "y" if burned.size() == 1 else "ies", n], Color(1.0, 0.5, 0.2))
	main._on_hand_updated()
	main.update_deck_info()


# =====================================================================
# Surprise Pick Up (crate)
# =====================================================================

const CRATE_LABELS := ["20 temp HP, mana, armor, Thorns and Keen",
	"Draw 3, Blessed 2 for 3 cycles, restore Brain and Flash points"]

static func _play_crate(main, mouse_pos: Vector3) -> void:
	var gm = main.grid_manager
	var cell: Vector2i = gm.world_to_grid(gm.snap_to_grid(mouse_pos))
	var holder := Node3D.new()
	holder.name = "SurprisePickUp"
	holder.position = main._ground_pos(cell)
	# The treasure pack's wooden chest (docs/ASSET_PACKS.md): the packs have
	# no crate, and their chest is the thing a hero opens.
	var sprite := CraftpixProps.make_sprite("chest_wood_closed")
	if sprite:
		holder.add_child(sprite)
	main.add_child(holder)
	_list(main, CRATES).append({"cell": cell, "node": holder, "standing": {}, "overlay": null, "taken": false})
	main.add_battle_log("A crate lands. Stand on it for %d tempo to open it." % CRATE_STAND_TEMPO, Color(0.85, 0.75, 0.5))


static func _tick_crates(main, amount: int) -> void:
	var crates: Array = _list(main, CRATES)
	if crates.is_empty():
		return
	for crate in crates.duplicate():
		if crate["taken"]:
			continue
		# A choice prompt is up: wait for it. Closed without a pick, the
		# count starts again.
		if crate["overlay"] != null:
			if is_instance_valid(crate["overlay"]):
				continue
			crate["overlay"] = null
			crate["standing"].clear()
		var standing: Dictionary = crate["standing"]
		for p in main._all_allies():   # heroes and NPC allies, never summons
			if not is_instance_valid(p):
				continue
			var id: int = p.get_instance_id()
			if main.grid_manager.world_to_grid(p.position) != crate["cell"]:
				standing.erase(id)
				continue
			standing[id] = int(standing.get(id, 0)) + amount
			if int(standing[id]) >= CRATE_STAND_TEMPO:
				_open_crate(main, crate, p)
				break


## The sheet says "this OR that" and names no chooser: a hero the players
## control picks (the game's own choice prompt); an NPC ally takes one at
## random.
static func _open_crate(main, crate: Dictionary, opener) -> void:
	if opener in main._all_players():
		main._show_choice_picker("Surprise Pick Up — %s opens the crate" % main._ally_display_name(opener), CRATE_LABELS,
			func(idx: int): grant_crate(main, crate, opener, idx))
		var ui = main.get_node_or_null("UI")
		crate["overlay"] = ui.get_node_or_null("ChoicePicker") if ui else null
	else:
		grant_crate(main, crate, opener, randi() % 2)


static func grant_crate(main, crate: Dictionary, opener, bundle: int) -> void:
	if crate["taken"] or not is_instance_valid(opener):
		return
	crate["taken"] = true
	_list(main, CRATES).erase(crate)
	if is_instance_valid(crate["node"]):
		crate["node"].queue_free()
	var stats = opener.get_stats()
	var bm = opener.get_buff_manager()
	if stats == null:
		return
	var who: String = main._ally_display_name(opener)
	if bundle == 0:
		stats.add_temp_health(CRATE_AMOUNT, CRATE_TEMP_HP_TEMPO)
		stats.gain_mana(CRATE_AMOUNT)
		stats.add_armor(CRATE_AMOUNT)
		if bm:
			bm.apply_buff(Buff.create_thorns(CRATE_AMOUNT, 15, "Surprise Pick Up"))
			bm.apply_buff(Buff.create_keen(CRATE_AMOUNT, CRATE_BUFF_TEMPO, "Surprise Pick Up"))
		main.add_battle_log("Surprise Pick Up: %s gains 20 temp HP, mana, armor, Thorns and Keen." % who, Color(0.85, 0.75, 0.5))
	else:
		var dm = main._deck_for_player(opener) if opener in main._all_players() else null
		if dm:
			for _i in range(3):
				dm.draw_card()
		if bm:
			bm.apply_buff(Buff.create_blessed(2, 3, "Surprise Pick Up"))
		stats.refresh_brain_points()
		stats.refresh_flash_points()
		main.add_battle_log("Surprise Pick Up: %s draws 3, is Blessed 2 and has every Brain and Flash point back." % who, Color(0.85, 0.75, 0.5))
	main._on_hand_updated()
	main.update_deck_info()


# =====================================================================
# Inspiring Whistle
# =====================================================================

## A summon's attack reach in squares (the spirit bows shoot; the rest bite).
static func summon_reach(s) -> int:
	var consts: Dictionary = s.get_script().get_script_constant_map() if s.get_script() else {}
	return int(consts.get("ATTACK_RANGE", 1))


static func _summon_in_reach(main, s, cell: Vector2i, enemy) -> bool:
	var ec: Vector2i = main.grid_manager.world_to_grid(enemy.position)
	var reach: int = summon_reach(s)
	if reach <= 1:
		return main._manhattan(cell, ec) <= 1   # beside it, as the summons' brains judge a bite
	return maxi(absi(cell.x - ec.x), absi(cell.y - ec.y)) <= reach


static func _play_whistle(main, target) -> void:
	var caster = main.player
	var mine: Array = []
	for s in main._all_summons():
		if s is Summon and (s.summoner == null or s.summoner == caster):
			mine.append(s)
	if mine.is_empty():
		main.deck_manager.draw_card()
		main.add_battle_log("Inspiring Whistle: no summons — you draw a card.", Color(0.7, 0.85, 0.95))
		return
	# The enemy clicked; a click anywhere else sends them at the nearest one.
	var enemy = target if (target is Enemy and is_instance_valid(target) and not target.is_dead) else null
	if enemy == null:
		enemy = main._nearest_living_enemy_to(caster.position)
	for s in mine:
		var cur: Vector2i = s.get_destination_cell()
		if enemy != null and s.can_move_now():
			var ec: Vector2i = main.grid_manager.world_to_grid(enemy.position)
			for _step in range(WHISTLE_STEPS):
				if main._manhattan(cur, ec) <= 1:
					break
				var best: Vector2i = cur
				var best_d: int = main._manhattan(cur, ec)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var cand: Vector2i = cur + d
					if main._manhattan(cand, ec) < best_d and main._summon_can_step(cand, s, cur):
						best = cand
						best_d = main._manhattan(cand, ec)
				if best == cur:
					break
				cur = best
			if cur != s.get_destination_cell():
				s.move_to_cell(cur)
		# Brace 30% for 2 hits, doubled for a summon that now has the enemy
		# within its own reach.
		var doubled: bool = enemy != null and not s.is_dead and _summon_in_reach(main, s, cur, enemy)
		s.brace_percent = WHISTLE_BRACE * (2 if doubled else 1)
		s.brace_hits = WHISTLE_HITS
	main.add_battle_log("Inspiring Whistle: %d summon%s rall%s%s." % [mine.size(), "" if mine.size() == 1 else "s",
		"ies" if mine.size() == 1 else "y", (" on %s" % enemy.enemy_name) if enemy != null else ""], Color(0.7, 0.85, 0.95))


## Summon.take_damage: Brace cuts a hit and spends one of its hits.
static func summon_brace(s, amount: int) -> int:
	if s.brace_hits <= 0 or amount <= 0:
		return amount
	s.brace_hits -= 1
	var cut: int = floori(amount * s.brace_percent / 100.0)
	if s.brace_hits <= 0:
		s.brace_percent = 0
	return maxi(0, amount - cut)


## Summon.get_status_effects: the Brace badge on the Allies tab.
static func summon_badges(s) -> Array:
	if s.brace_hits <= 0:
		return []
	return [{"name": "Brace", "color": Color(0.6, 0.75, 0.9), "stacks": s.brace_hits,
		"desc": "Takes %d%% less damage from its next %d hit%s." % [s.brace_percent, s.brace_hits, "" if s.brace_hits == 1 else "s"]}]


# =====================================================================
# Stoked Pride
# =====================================================================

static func _play_pride(main, target) -> void:
	var who = target if (target is Player and is_instance_valid(target)) else main.player
	var stats = who.get_stats()
	if stats == null:
		return
	stats.set_meta(PRIDE_MARK, main.player)
	_sync(who)
	main.add_battle_log("Stoked Pride: %s is marked — a lion waits on the next attack." % main._ally_display_name(who), Color(0.9, 0.75, 0.35))


static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## The living lion guarding this hero, or null.
static func lion_of(stats):
	var lion = _meta(stats, PRIDE_LION)
	if lion != null and is_instance_valid(lion) and not lion.is_dead:
		return lion
	if stats != null and stats.has_meta(PRIDE_LION):
		stats.remove_meta(PRIDE_LION)
	return null


## Enemy._deal_damage_to_player, as an enemy attack is about to damage a
## hero: true when a lion took it (the hero takes none).
static func stoked_pride_intercept(main, attacker, victim, damage: int) -> bool:
	if main == null or damage <= 0 or not ("grid_manager" in main) or not is_instance_valid(victim) \
			or not victim.has_method("get_stats"):
		return false
	var stats = victim.get_stats()
	if stats == null or not (stats.has_meta(PRIDE_MARK) or stats.has_meta(PRIDE_LION)):
		return false
	var gm = main.grid_manager
	var lion = lion_of(stats)
	if lion == null and stats.has_meta(PRIDE_MARK):
		# The mark triggers: the lion appears on a free tile beside them.
		var caster = stats.get_meta(PRIDE_MARK)
		var cells: Array = main._free_cells_near(gm.world_to_grid(victim.position), 1)
		if cells.is_empty():
			return false  # no room: the mark waits
		stats.remove_meta(PRIDE_MARK)
		lion = main.SkeletonScript.new()
		main.add_child(lion)
		lion.setup(gm, gm.grid_to_world(cells[0]), LION_HP, "pride_lion")
		lion.summoner = caster if (caster != null and is_instance_valid(caster)) else main.player
		lion.set_meta("nce_ward", victim)
		lion.died.connect(func(dead): main._skeletons.erase(dead))
		main._skeletons.append(lion)
		stats.set_meta(PRIDE_LION, lion)
		main.add_battle_log("A lion leaps to %s's defense!" % main._ally_display_name(victim), Color(0.9, 0.75, 0.35))
	if lion == null:
		return false
	# It guards while it stands within 2 squares.
	if _chebyshev(lion.get_destination_cell(), gm.world_to_grid(victim.position)) > LION_GUARD_RANGE:
		return false
	if "last_attacker" in lion:
		lion.last_attacker = attacker
	lion.take_damage(damage)
	main.add_battle_log("The lion takes the blow (%d)." % damage, Color(0.9, 0.75, 0.35))
	_sync(victim)
	return true


## Each tempo a lion more than a square from its ward steps back toward
## them (its only movement: main's summon brain leaves it where it stands).
static func _lead_lions(main) -> void:
	for s in main._skeletons:
		if not is_instance_valid(s) or s.is_dead or s.kind != "pride_lion" or not s.has_meta("nce_ward"):
			continue
		var ward = s.get_meta("nce_ward")
		if ward == null or not is_instance_valid(ward) or not s.can_move_now():
			continue
		var cur: Vector2i = s.get_destination_cell()
		var wc: Vector2i = main.grid_manager.world_to_grid(ward.position)
		if _chebyshev(cur, wc) <= 1:
			continue
		var best: Vector2i = cur
		var best_d: int = main._manhattan(cur, wc)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var cand: Vector2i = cur + d
			if main._manhattan(cand, wc) < best_d and main._summon_can_step(cand, s, cur):
				best = cand
				best_d = main._manhattan(cand, wc)
		if best != cur:
			s.move_to_cell(best)
