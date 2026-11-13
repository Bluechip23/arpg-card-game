class_name FeverfangCards
extends RefCounted

## Feverfang (designer's row, 2026-11-12): its Overdraw rider and its granted
## card, Redline. The shared files only call in:
##   main._on_overdraw_processed   -> on_overdraw()
##   main._resolve_queued_card     -> after_card()    (Redline's charges)
##   main world effects            -> play_redline()
##   BuffManager.sync_flag_buffs   -> sync_badge()

const REDLINE_META := "redline_charges"
const REDLINE_CARDS := 5
const REDLINE_DRAW := 2
const MELEE_REACH := 1.5   # tiles: the 8 neighbours

## A draw overflowed a full hand: each equipped weapon with the rider deals
## its damage to one random enemy in melee range. The number is flat (no
## STR, no Strengthen: it is not an attack and spends no Strengthen charge),
## but it can crit (designer, 2026-11-13): it rolls the hero's crit chance —
## Keen included, a by-the-roll Keen spending a charge as on any crit roll —
## and a crit multiplies it by the hero's crit damage.
static func on_overdraw(main) -> void:
	var player = main.player
	if player == null or player.get_inventory() == null or main.enemy_spawner == null:
		return
	var inv = player.get_inventory()
	if not ("equipped_weapons" in inv):
		return
	for w in inv.equipped_weapons:
		if w == null or w.overdraw_melee_damage <= 0:
			continue
		var near: Array = main.enemy_spawner.get_enemies_in_radius(player.position, MELEE_REACH * main.grid_manager.grid_size)
		near = near.filter(func(e): return is_instance_valid(e) and not e.is_dead)
		if near.is_empty():
			continue
		var victim = near[randi() % near.size()]
		var dmg: int = w.overdraw_melee_damage
		var stats = player.get_stats()
		var bm = player.get_buff_manager() if player.has_method("get_buff_manager") else null
		var crit: bool = bm != null and bm.roll_crit()
		if crit:
			dmg = Card.crit_multiply(dmg, stats, victim)
		victim.take_damage(dmg, true)
		main.add_battle_log("%s: overdraw — %d damage to %s%s" % [w.item_name, dmg, victim.enemy_name, " (crit!)" if crit else ""], Color(1.0, 0.5, 0.4))

## Redline: the next 5 cards played each spend a charge; an offensive one
## draws 2 as it resolves.
static func play_redline(main) -> void:
	var stats = main.player.get_stats() if main.player else null
	if stats == null:
		return
	stats.set_meta(REDLINE_META, REDLINE_CARDS)
	_sync(main)
	main.add_battle_log("Redline: your next %d cards draw %d each if they are offensive." % [REDLINE_CARDS, REDLINE_DRAW], Color(1.0, 0.5, 0.4))

## After a card of the active player resolves.
static func after_card(main, card: Card) -> void:
	if main.player == null or card == null or card.card_id == "redline":
		return
	var stats = main.player.get_stats()
	if stats == null or not stats.has_meta(REDLINE_META):
		return
	var left: int = int(stats.get_meta(REDLINE_META)) - 1
	if left <= 0:
		stats.remove_meta(REDLINE_META)
	else:
		stats.set_meta(REDLINE_META, left)
	if card.is_offensive() and main.deck_manager:
		for _i in range(REDLINE_DRAW):
			main.deck_manager.draw_card()
		main.add_battle_log("Redline: %s draws %d (%d left)" % [card.card_name, REDLINE_DRAW, maxi(left, 0)], Color(1.0, 0.5, 0.4))
	_sync(main)

static func sync_badge(bm) -> void:
	var st = bm.owner_stats
	var left: int = int(st.get_meta(REDLINE_META)) if st != null and st.has_meta(REDLINE_META) else 0
	bm._sync_generic("redline", left > 0, "Redline",
		"Your next %d cards: an offensive one draws %d" % [left, REDLINE_DRAW], Color(1.0, 0.45, 0.35), -1, left)

static func _sync(main) -> void:
	var bm = main.player.get_buff_manager() if main.player else null
	if bm:
		bm.sync_flag_buffs()
