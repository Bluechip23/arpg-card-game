class_name NewCardsA
extends RefCounted

## Sheet batch A: the aura / maintain / ally-buff cards.
##   The Wolf's Howl, Spirit Armor, Ember Heart, Lodestone Field,
##   Warden's Hound, War Shout, Stone Wheel, Arcane Tide, Clarity.
## The shared files only carry one-line hooks into here:
##   Card._execute_card            -> execute()        (the hand-resolved buffs)
##   main world effects            -> war_shout()
##   main._on_tempo_advanced       -> tick()           (auras follow positions every tempo)
##   main._sync_maintained_passives-> tick()           (a maintain entering / leaving the pile)
##   main._process_maintained_card_effects -> cycle()  (the per-cycle maintains)
##   DeckManager / OverflowManager jail sites -> on_card_jailed()
##   Enemy._tick_status_durations  -> holds_shock()
##
## "Allies" here are the heroes on the board (the party and the dojo's
## practice allies, main._all_allies()), the caster included — and the
## summons (designer, 2026-11-12: "the ally buffs and auras should reach
## summons"). A summon has no buff manager, so War Shout, The Wolf's Howl
## and Spirit Armor land on the few numbers Summon carries for them
## (gain_strengthen, aura_strengthen, gain_granted_armor).

const HOWL_RADIUS := 2
const HOWL_STRENGTHEN := 5
const HOWL_META := "wolfs_howl_aura"       # marks the aura's Strengthen instance
const HOWL_REFRESH_TEMPO := 5              # the aura buff's clock, re-set every tempo it stands
const SPIRIT_ARMOR_RADIUS := 5
const SPIRIT_ARMOR_PER_CYCLE := 2
const EMBER_HEART_RADIUS := 4
const EMBER_HEART_STACKS := 2
const EMBER_HEART_DAMAGE_PER_STACK := 3
const LODESTONE_RADIUS := 2
const LODESTONE_SLOW := 1
const WARDEN_KEEN_PCT := 20   # designer, 2026-11-12: "20 (20% crit) Keen"
const WARDEN_KEEN_TEMPO := 10
const WARDEN_THORNS := 5
const WAR_SHOUT_RADIUS := 3
const WAR_SHOUT_STRENGTHEN := 3
const WAR_SHOUT_ATTACKS := 3
const STONE_WHEEL_KEEN_PCT := 15
const STONE_WHEEL_TEMPO := 10
const ARCANE_TIDE_ATTUNE := 3
const CLARITY_ATTUNE := 2
## "Focused for 2 cycles": Focused pays its +10 mana at a cycle start, and a
## buff's clock ticks BEFORE that tempo's cycle start runs. 11 tempo is the
## one length that always meets exactly two cycle starts, wherever in the
## cycle Clarity resolves (10 would miss the second when it resolves on a
## cycle boundary).
const CLARITY_FOCUSED_TEMPO := 11

## The heroes maintaining Lodestone Field right now (refreshed every tempo
## by tick()); enemies read it while their Shock ticks (holds_shock).
static var lodestone_casters: Array = []
static var _grid = null

# ---------------------------------------------------------------- helpers

## Whether `b` stands within `squares` of `a`: a circle in grid cells, the
## way the flame and AoE circles are measured.
static func within(grid, a: Vector3, b: Vector3, squares: float) -> bool:
	if grid == null:
		return Vector2(a.x - b.x, a.z - b.z).length() <= squares + 0.001
	var ca: Vector2i = grid.world_to_grid(a)
	var cb: Vector2i = grid.world_to_grid(b)
	return Vector2(ca - cb).length() <= squares + 0.001

## The heroes within `squares` of `center_node`, itself included.
static func allies_within(main, center_node, squares: float) -> Array:
	var out: Array = []
	for ally in main._all_allies():
		if not is_instance_valid(ally) or not ally.has_method("get_stats") or ally.get_stats() == null:
			continue
		if ally == center_node or within(main.grid_manager, center_node.position, ally.position, squares):
			out.append(ally)
	return out

## The living summons within `squares` of `center_node`.
static func summons_within(main, center_node, squares: float) -> Array:
	var out: Array = []
	for s in main._all_summons():
		if is_instance_valid(s) and s is Summon and not s.is_dead \
				and within(main.grid_manager, center_node.position, s.position, squares):
			out.append(s)
	return out

static func enemies_within(main, center_node, squares: float) -> Array:
	var out: Array = []
	if main.enemy_spawner == null:
		return out
	for e in main.enemy_spawner.get_living_enemies():
		if is_instance_valid(e) and e.is_alive() \
				and within(main.grid_manager, center_node.position, e.position, squares):
			out.append(e)
	return out

## The players who hold `card_id` in their maintained pile (co-op aware).
static func maintainers(main, card_id: String) -> Array:
	var out: Array = []
	for p in main._all_players():
		if not is_instance_valid(p):
			continue
		var deck = main._deck_for_player(p)
		if deck == null:
			continue
		for c in deck.maintained_cards:
			if c and c.card_id == card_id:
				out.append(p)
				break
	return out

# ---------------------------------------------------------------- Card.execute

## The part of each card that resolves on stats and buffs alone. For an
## ally-targeted play DeckManager.execute_deferred_card hands in the TARGET's
## stats and buff manager, so Stone Wheel and Arcane Tide land on the ally
## picked (or on the caster for a self cast), the way Lady Luck does.
static func execute(card, _target, _player_stats, _deck_manager, buff_mgr) -> void:
	match card.card_id:
		"stone_wheel":
			if buff_mgr:
				buff_mgr.apply_buff(Buff.create_keen(STONE_WHEEL_KEEN_PCT, STONE_WHEEL_TEMPO, "Stone Wheel"))
			print("[CARD] Stone Wheel! Keen +%d%% for %d tempo" % [STONE_WHEEL_KEEN_PCT, STONE_WHEEL_TEMPO])
		"arcane_tide":
			if buff_mgr:
				buff_mgr.apply_buff(Buff.create_attune(ARCANE_TIDE_ATTUNE, Buff.ATTUNE_DEFAULT_SPELLS, "Arcane Tide"))
			print("[CARD] Arcane Tide! Attune %d" % ARCANE_TIDE_ATTUNE)
		"clarity":
			if buff_mgr:
				var focused := Buff.create(Buff.BuffType.FOCUSED, 0, CLARITY_FOCUSED_TEMPO)
				focused.source_name = "Clarity"
				buff_mgr.apply_buff(focused)
				buff_mgr.apply_buff(Buff.create_attune(CLARITY_ATTUNE, Buff.ATTUNE_DEFAULT_SPELLS, "Clarity"))
			print("[CARD] Clarity! Focused for 2 cycles, Attune %d" % CLARITY_ATTUNE)
		"war_shout":
			pass  # needs positions: main's world effects call war_shout()
		"the_wolfs_howl", "spirit_armor", "ember_heart", "lodestone_field", "wardens_hound":
			# Maintained: playing it only puts it in the maintained pile. The
			# effect is read off that pile (tick / cycle / on_card_jailed).
			print("[CARD] %s maintained" % card.card_name)

# ---------------------------------------------------------------- War Shout

## Strengthen 3 (the usual next-3-attacks count: Biscuit, Hope This Works) to
## the caster and every hero within 3 squares.
static func war_shout(main, _card) -> void:
	var caster = main.player
	if caster == null:
		return
	var n := 0
	for ally in allies_within(main, caster, WAR_SHOUT_RADIUS):
		var bm = ally.get_buff_manager() if ally.has_method("get_buff_manager") else null
		if bm:
			bm.apply_buff(Buff.create_strengthen(WAR_SHOUT_STRENGTHEN, WAR_SHOUT_ATTACKS, "War Shout"))
			n += 1
	for s in summons_within(main, caster, WAR_SHOUT_RADIUS):
		s.gain_strengthen(WAR_SHOUT_STRENGTHEN, WAR_SHOUT_ATTACKS)
		n += 1
	main.add_battle_log("War Shout! %d %s gain Strengthen %d for %d attacks" % [
		n, "ally" if n == 1 else "allies", WAR_SHOUT_STRENGTHEN, WAR_SHOUT_ATTACKS], Color(1.0, 0.7, 0.3))

# ---------------------------------------------------------------- every tempo

## Runs on every tempo advance and whenever a maintained pile changes: the
## auras follow where everyone stands now.
static func tick(main) -> void:
	if main == null or main.player == null or main.deck_manager == null:
		return
	_grid = main.grid_manager
	lodestone_casters = maintainers(main, "lodestone_field")
	_sync_wolfs_howl(main)

## The Wolf's Howl: an aura, not a grant. Every hero standing within 2
## squares of a howler (the howler too) carries one Strengthen 5 that no
## attack spends; it is taken away the tempo they step out, or the maintain
## drops. It is its own Strengthen instance (BuffManager.apply_buff never
## merges another Strengthen into it), so a carded Strengthen beside it
## still counts down its own attacks.
static func _sync_wolfs_howl(main) -> void:
	var howlers := maintainers(main, "the_wolfs_howl")
	for ally in main._all_allies():
		if not is_instance_valid(ally) or not ally.has_method("get_buff_manager"):
			continue
		var bm = ally.get_buff_manager()
		if bm == null:
			continue
		var inside := false
		for h in howlers:
			if ally == h or within(main.grid_manager, h.position, ally.position, HOWL_RADIUS):
				inside = true
				break
		var aura: Buff = howl_aura_of(bm)
		if inside and aura == null:
			aura = Buff.create_strengthen_timed(HOWL_STRENGTHEN, HOWL_REFRESH_TEMPO, "The Wolf's Howl")
			aura.set_meta(HOWL_META, true)
			aura.description = "+%d damage on every attack while within %d squares of The Wolf's Howl" % [HOWL_STRENGTHEN, HOWL_RADIUS]
			bm.buffs.append(aura)
			bm.buffs_changed.emit()
		elif inside:
			aura.duration = HOWL_REFRESH_TEMPO  # never runs out while they stand in it
		elif aura != null:
			bm.remove_buff_instance(aura)
	# Summons in the howl: +5 on every attack while they stand in it.
	for s in main._all_summons():
		if not (is_instance_valid(s) and s is Summon):
			continue
		var s_inside := false
		for h in howlers:
			if within(main.grid_manager, h.position, s.position, HOWL_RADIUS):
				s_inside = true
				break
		s.aura_strengthen = HOWL_STRENGTHEN if s_inside else 0

static func howl_aura_of(bm) -> Buff:
	for b in bm.buffs:
		if b.buff_type == Buff.BuffType.STRENGTHEN and b.has_meta(HOWL_META):
			return b
	return null

# ---------------------------------------------------------------- every cycle

## The per-cycle maintains, run at the cycle start with Halo's heal (before
## the cycle's own status ticks, so Ember Heart moves Burn off its bearer
## before that Burn bites).
static func cycle(main) -> void:
	if main == null or main.player == null or main.deck_manager == null:
		return
	tick(main)
	for p in main._all_players():
		if not is_instance_valid(p):
			continue
		var deck = main._deck_for_player(p)
		if deck == null:
			continue
		for c in deck.maintained_cards.duplicate():
			if c == null:
				continue
			match c.card_id:
				"spirit_armor":
					_spirit_armor(main, p)
				"ember_heart":
					_ember_heart(main, p)
				"lodestone_field":
					_lodestone_slow(main, p)

## Spirit Armor: every hero within 5 squares (the caster too) gains 2 armor
## — an ordinary armor gain, like Smith's per-cycle armor.
static func _spirit_armor(main, caster) -> void:
	for ally in allies_within(main, caster, SPIRIT_ARMOR_RADIUS):
		ally.get_stats().add_armor(SPIRIT_ARMOR_PER_CYCLE)
	# A summon holds it as granted armor (at most Summon.GRANTED_ARMOR_CAP);
	# a Battle Turtle takes it into its own armor first.
	for s in summons_within(main, caster, SPIRIT_ARMOR_RADIUS):
		var left: int = SPIRIT_ARMOR_PER_CYCLE
		if s.has_method("gain_armor"):
			left -= s.gain_armor(left)
		s.gain_granted_armor(left)
	print("[NEW-A] Spirit Armor: +%d armor to allies within %d" % [SPIRIT_ARMOR_PER_CYCLE, SPIRIT_ARMOR_RADIUS])

## Ember Heart: up to 2 stacks of the Burn the maintainer carries move onto
## one random enemy within 4 squares; each stack moved deals 3 damage to
## that enemy as it lands. With no enemy in reach (or no Burn) nothing moves.
static func _ember_heart(main, caster) -> void:
	var dm = caster.get_debuff_manager() if caster.has_method("get_debuff_manager") else null
	if dm == null:
		return
	var burn = dm.get_debuff(Debuff.DebuffType.BURN)
	if burn == null or burn.value <= 0:
		return
	var pool := enemies_within(main, caster, EMBER_HEART_RADIUS)
	if pool.is_empty():
		return
	var victim = pool[randi() % pool.size()]
	var moved: int = mini(EMBER_HEART_STACKS, burn.value)
	burn.value -= moved
	if burn.value <= 0:
		dm.remove_debuff(Debuff.DebuffType.BURN)
		dm.burn_damage_next = 1
	else:
		burn._set_name_and_description()
		dm.debuffs_changed.emit()
	victim.apply_debuff("burn", moved)
	for _i in range(moved):
		if is_instance_valid(victim) and victim.is_alive():
			victim._dot_hit("Ember Heart", EMBER_HEART_DAMAGE_PER_STACK)
	main.add_battle_log("Ember Heart: %d Burn leaps to %s for %d" % [
		moved, victim.enemy_name, moved * EMBER_HEART_DAMAGE_PER_STACK], Color(1.0, 0.5, 0.2))

## Lodestone Field: enemies within 2 squares of the maintainer take Slow 1
## (one stack, 5 tempo) at each cycle start. The field is centred on the
## caster and follows them.
static func _lodestone_slow(main, caster) -> void:
	for e in enemies_within(main, caster, LODESTONE_RADIUS):
		e.apply_debuff("slow", LODESTONE_SLOW)

## Lodestone Field's other half, read by Enemy._tick_status_durations: Shock
## on an enemy standing in a field still deals its damage and arcs, but does
## not lose its stack that cycle.
static func holds_shock(enemy) -> bool:
	for p in lodestone_casters:
		if is_instance_valid(p) and is_instance_valid(enemy) \
				and within(_grid if is_instance_valid(_grid) else null, p.position, enemy.position, LODESTONE_RADIUS):
			return true
	return false

# ---------------------------------------------------------------- jail

## Warden's Hound: called wherever a card of this deck is sent to jail
## (jail-on-play, a Rapid Recurve shot, a Burden jailed from hand, a reaction
## jailed on its cooldown, the Jailed overflow). While the Hound is maintained
## its owner gains Keen +20% on the clock (10 tempo, stacking) and 5 Thorns.
static func on_card_jailed(deck, _card) -> void:
	if deck == null:
		return
	var hounds := 0
	for c in deck.maintained_cards:
		if c and c.card_id == "wardens_hound":
			hounds += 1
	if hounds <= 0:
		return
	var stats = deck.player_stats
	var bm = stats.own_buff_manager if stats != null and "own_buff_manager" in stats else null
	if bm == null:
		return
	for _i in range(hounds):
		bm.apply_buff(Buff.create_keen(WARDEN_KEEN_PCT, WARDEN_KEEN_TEMPO, "Warden's Hound"))
		bm.apply_buff(Buff.create_thorns(WARDEN_THORNS, 15, "Warden's Hound"))
	print("[NEW-A] Warden's Hound: a card was jailed, +%d%% Keen and +%d Thorns" % [WARDEN_KEEN_PCT, WARDEN_THORNS])
