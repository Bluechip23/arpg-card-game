class_name YariCards
extends RefCounted

## Yari of the Spider Monkey (designer's row, 2026-11-12): its two granted
## cards and its displacement rider. The shared files only call in:
##   Card._execute_card                    -> the two cards' numbers
##   main._apply_card_world_effects_inner  -> world_effects()
##   main point-card click                 -> point_reach()
##   progression_triggers displacement     -> on_displacement()
##   Card._execute_card (damage riders)    -> take_displacement_bonus()

const VAULT_REACH := 3
const DASH_REACH := 3
const DASH_COPY_ERASE := 1
## Armed on the hero's stats by a displacement while the Yari is held: the
## percent the next damaging offensive card gains.
const ARMED_META := "displacement_bonus_percent"

## The hard cap on where these two land, or 0 for any other card.
static func point_reach(card: Card) -> int:
	match card.card_id:
		"pole_vault": return VAULT_REACH
		"whirling_dash": return DASH_REACH
	return 0

## A displacement of the hero (a blink, a leap, a roll, a dash…): a weapon
## that says so arms +X% on the next damaging offensive card.
static func on_displacement(main) -> void:
	if main == null or main.player == null:
		return
	var stats = main.player.get_stats()
	var inv = main.player.get_inventory() if main.player.has_method("get_inventory") else null
	if stats == null or inv == null or not ("equipped_weapons" in inv):
		return
	var pct := 0.0
	for w in inv.equipped_weapons:
		if w != null and w.displacement_next_offensive_percent > 0.0:
			pct = maxf(pct, w.displacement_next_offensive_percent)
	if pct > 0.0:
		stats.set_meta(ARMED_META, pct)
		print("[YARI] Displaced: the next offensive card deals +%.0f%%" % pct)

## Spent by the next damaging offensive card: the multiplier for its whole
## play (1.0 when nothing is armed).
static func take_displacement_bonus(card: Card, stats) -> float:
	if stats == null or not stats.has_meta(ARMED_META):
		return 1.0
	if not card.is_offensive() or (card.base_damage <= 0 and card.damage <= 0):
		return 1.0
	var pct: float = float(stats.get_meta(ARMED_META))
	stats.remove_meta(ARMED_META)
	return 1.0 + pct / 100.0

## True when the card was one of the Yari's.
static func world_effects(main, card: Card, mouse_pos: Vector3) -> bool:
	match card.card_id:
		"pole_vault":
			_blink(main, card, mouse_pos)
		"whirling_dash":
			_whirling_dash(main, card, mouse_pos)
		_:
			return false
	return true

## Where the play lands: the aimed tile, or null (with a log line) when it
## is a wall, an obstacle, across high mountains or stood on.
static func _landing(main, card: Card, mouse_pos: Vector3):
	var gm = main.grid_manager
	var player = main.player
	var pos: Vector3 = gm.snap_to_grid(mouse_pos)
	var cell: Vector2i = gm.world_to_grid(pos)
	var here: Vector2i = gm.world_to_grid(player.position)
	if cell == here:
		return null
	if not main._point_in_card_reach(pos, point_reach(card)):
		main.add_battle_log("Out of range! %s reaches %d spaces." % [card.card_name, point_reach(card)], Color(1.0, 0.4, 0.4))
		return null
	if cell in player.blocked_tiles:
		main.add_battle_log("%s: cannot land on a wall or obstacle!" % card.card_name, Color(1.0, 0.4, 0.4))
		return null
	if main.dungeon_manager and not main.dungeon_manager.blink_clear(here, cell):
		main.add_battle_log("The mountains are too high to cross!", Color(1.0, 0.4, 0.4))
		return null
	for e in main.enemy_spawner.get_living_enemies():
		if is_instance_valid(e) and gm.world_to_grid(e.position) == cell:
			main.add_battle_log("%s: that tile is taken!" % card.card_name, Color(1.0, 0.4, 0.4))
			return null
	return pos

static func _blink(main, card: Card, mouse_pos: Vector3) -> bool:
	var pos = _landing(main, card, mouse_pos)
	if pos == null:
		return false
	main.player.blink_to(pos)
	main.progression_triggers._trigger_skill_tree_on_displacement()
	return true

## Whirling Dash: every enemy on the tiles between where the hero stood and
## where they land takes the card's damage once; passing through more than
## one leaves a copy of the card (Erase 1) in the hand.
static func _whirling_dash(main, card: Card, mouse_pos: Vector3) -> void:
	var gm = main.grid_manager
	var from: Vector2i = gm.world_to_grid(main.player.position)
	var pos = _landing(main, card, mouse_pos)
	if pos == null:
		return
	var to: Vector2i = gm.world_to_grid(pos)
	var steps: int = maxi(absi(to.x - from.x), absi(to.y - from.y))
	var passed: Array = []
	for i in range(1, steps):
		var t: float = float(i) / float(steps)
		var cell := Vector2i(roundi(lerpf(from.x, to.x, t)), roundi(lerpf(from.y, to.y, t)))
		for e in main.enemy_spawner.get_living_enemies():
			if is_instance_valid(e) and not e.is_dead and not (e in passed) and gm.world_to_grid(e.position) == cell:
				passed.append(e)
	main.player.blink_to(pos)
	for e in passed:
		if is_instance_valid(e) and not e.is_dead:
			e.take_damage(card.last_damage_dealt, true, card.damage_type)
	main.progression_triggers._trigger_skill_tree_on_displacement()
	main.add_battle_log("Whirling Dash: %d damage to %d enem%s passed through" % [
		card.last_damage_dealt, passed.size(), "y" if passed.size() == 1 else "ies"], Color(0.6, 0.9, 1.0))
	if passed.size() > 1 and main.deck_manager:
		var copy := Card.create_by_id("whirling_dash")
		copy.erase_tempo = DASH_COPY_ERASE
		copy.erase_tempo_remaining = DASH_COPY_ERASE
		copy.description += " Erase %d." % DASH_COPY_ERASE
		main.deck_manager.add_card_to_hand(copy)
		main.add_battle_log("Whirling Dash: more than one — a copy returns to your hand (Erase 1).", Color(0.6, 0.9, 1.0))
