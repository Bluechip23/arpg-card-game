extends SimPolicy

## The strategic player. True state cloning is not feasible here (Main is a
## 17k-line scene; a faithful snapshot would be a second rulebook, and
## replaying the seed to clone costs seconds per candidate), so this is the
## audit's fallback: a one-step evaluation over the real legal actions that
## values what the greedy player ignores — enemy intent, control effects,
## block and healing, kiting, overkill — using only what a human sees: the
## hover damage preview, the card text, the overhead intent bar, the inspect
## panel's base hit and reach.
##
## score(action) = (enemy HP removed + control value + mitigation value
##                  - player HP lost while committed) / tempo
## with a kill bonus (the threat that enemy would have dealt afterwards) and
## a lethal-exposure penalty. With no enemy threat the score reduces to
## damage per tempo, so it never does worse than greedy_dpt there.
##
## Beyond raw damage it prices: invisibility (every hit the enemies would
## have landed, also for a displacement while Now You See Me is ready),
## have landed while they cannot see you), poison stacks (the damage they
## tick for over the next cycles, plus Pop Rocks), discard engines
## (Volatile Mixture, Exacerbate Wounds, Ladder Work, Keep Them Guessing),
## and the point pools — flash moves that spend no tempo (so nothing acts
## while you reposition), the sidestep block, proc ticks that bring the DEX
## proc forward, and Insight draws when the hand runs thin.

const HORIZON := 10          # tempo of future threat a kill removes
const LOW_HP := 0.4          # below this fraction, HP preserved counts double
const MANA_WEIGHT := 0.02    # tiny tie-breaker: cheaper of two equal plays
const COMMIT_WEIGHT := 0.5   # share of the answerable damage a long action forfeits that we count against it
const FLASH_POINT_VALUE := 0.5   # a flash point held is a future dodge or sidestep; spending one costs this
const BRAIN_POINT_VALUE := 0.3   # likewise a brain point is a future draw
const CONTROL_WORDS := {     # card text -> (what it does, how long by default)
	"stun": 5, "stuns": 5, "stunned": 5, "freeze": 5, "frozen": 5, "root": 5, "rooted": 5,
	"trip": 3, "tripped": 3, "disarm": 5, "disarmed": 5, "silence": 5, "silenced": 5,
}
const AMP_WORDS := ["vulnerable", "weaken", "weakened", "expose", "exposed"]
const MOVE_ACTION_WORDS := ["move", "scurry", "range", "retreat", "heal", "regen", "flee", "wander"]

var debug := false   # print the top-scored actions and the threat model per decision

## Stalemate breaker. When nothing scores above waiting (an enemy hovering
## out of reach, a hand with no play worth its tempo) both sides can wait
## out the clock, and the fight reads as a timeout the build never had to
## take. After IDLE_LIMIT consecutive waits with no health changing, the
## policy commits: its best non-wait action, or a step toward the nearest
## enemy.
const IDLE_LIMIT := 6
var _idle_streak := 0
var _idle_sig := ""

func _init() -> void:
	name = "lookahead"

func setup(scenario: Dictionary) -> void:
	super.setup(scenario)
	_idle_streak = 0
	_idle_sig = ""

func choose_action(state: SimState) -> Variant:
	var picked: Variant = _choose(state)
	var sig := "%d" % state.player_hp
	for e in state.enemies:
		sig += ":%d" % int(e["hp"])
	if picked is Dictionary and str(picked.get("type", "")) == "wait" and sig == _idle_sig:
		_idle_streak += 1
	else:
		_idle_streak = 0
	_idle_sig = sig
	if _idle_streak >= IDLE_LIMIT and picked is Dictionary and str(picked.get("type", "")) == "wait":
		var commit := _break_stalemate(state)
		if not commit.is_empty():
			if debug:
				print("[LOOKAHEAD] stalemate after %d waits: %s" % [_idle_streak, SimPolicy.action_label(commit)])
			_idle_streak = 0
			return commit
	return picked

func _break_stalemate(state: SimState) -> Dictionary:
	var threats := _threats(state)
	var best: Dictionary = {}
	var best_score := -INF
	for a in state.legal_actions():
		var t := str(a.get("type", ""))
		if t == "wait" or t == "brain_peek":
			continue
		var sc := _score(a, state, threats)
		if t == "attack" or (t == "play" and str(a.get("target", "")).begins_with("enemy:")):
			sc += 2.0
		if sc > best_score:
			best_score = sc
			best = a
	if best_score > -1.0:
		return best
	var near := state.nearest_enemy_index()
	return state.step_toward(near) if near >= 0 else best

func _choose(state: SimState) -> Variant:
	var legal := state.legal_actions()
	if legal.is_empty():
		return {"type": "wait"}
	var threats := _threats(state)
	var best: Dictionary = {}
	var best_score := -INF
	var scored: Array = []
	for a in legal:
		var s := _score(a, state, threats)
		if debug:
			scored.append([s, SimPolicy.action_label(a)])
		if s > best_score:
			best_score = s
			best = a
	if debug:
		scored.sort_custom(func(x, y): return x[0] > y[0])
		var top: Array = []
		for i in range(mini(5, scored.size())):
			top.append("%s=%.1f" % [scored[i][1], scored[i][0]])
		var th: Array = []
		for t in threats:
			th.append("%s:%s in %d (%s, reach %d, d %d, dmg %d)" % [state.enemies[t["index"]]["type"], str(state.enemies[t["index"]]["intent"].get("name", "")), t["fires_in"], "hit" if t["is_hit"] else "move", t["reach"], t["distance"], t["damage"]])
		print("[LOOKAHEAD] t%d hp %d/%d armor %d flash %d brain %d hand %d move=%s/%s/%s | %s | %s" % [state.global_tempo, state.player_hp, state.player_max_hp, state.player_armor, state.flash_points, state.brain_points, state.hand.size(),
			str(state.can_move), "locked" if state.movement_locked else "free", "walking" if state.main.player.is_moving else "still", " ".join(th), "  ".join(top)])
	if best.get("type", "") == "play":
		var c: Dictionary = state.hand[best["card"]]
		var own_pick := _own_pick(c, state, int(best["card"]))
		if own_pick >= 0 and not best.has("picks"):
			best = best.duplicate()
			best["picks"] = {"picked_card": own_pick}
		elif str(c["description"]).to_lower().find("discard a card") >= 0 and not best.has("picks"):
			var pick := _worst_card_index(state, int(best["card"]))
			if pick >= 0:
				best = best.duplicate()
				best["picks"] = {"picked_card": pick}
	return best

## The card we would rather lose: Volatile Mixture wants to be discarded;
## otherwise the lowest expected value in hand.
## Invisibility's draw: the rule shows the top card, so draw it only when it
## is worth more than the hand's weakest card (or the hand is short), and
## discard by the same measure. The measure counts what a card does beyond
## damage, block and heal (poison, invisibility, draw, the potion and
## discard engines), so an engine card is not thrown away as "zero".
func answer_prompt(kind: String, options: Array, state: SimState = null) -> int:
	if kind == "invisibility_draw":
		if state == null:
			return 0
		if state.hand.size() < 3:
			return 0
		var weakest := INF
		for h in state.hand:
			weakest = minf(weakest, _card_worth(h, state))
		if state.top_card.is_empty():
			return 1
		return 0 if _card_worth(state.top_card, state) > weakest + 0.5 else 1
	if kind == "house_rule":
		# Take back the card worth most (options are the discard pile's names).
		if state == null or options.is_empty():
			return 0
		var best := 0
		var best_v := -INF
		var dm = state.main.deck_manager
		for i in range(options.size()):
			for c in dm.discard_pile:
				if c.card_name == str(options[i]):
					var v := float(c.base_damage) + float(c.block if c.block > 0 else c.base_block) + float(c.heal_amount)
					if v > best_v:
						best_v = v
						best = i
					break
		return best
	if kind == "invisibility_discard":
		if state == null or options.is_empty():
			return 0
		var worst := -1
		var worst_v := INF
		for i in range(options.size()):
			for h in state.hand:
				if h["name"] == str(options[i]):
					var v := _card_worth(h, state)
					if v < worst_v:
						worst_v = v
						worst = i
					break
		return maxi(0, worst)
	return super.answer_prompt(kind, options, state)

## What keeping a card is worth, beyond its raw numbers.
static func _card_worth(h: Dictionary, state: SimState) -> float:
	var text := str(h.get("description", "")).to_lower()
	var v := float(h.get("damage", 0)) + float(h.get("block", 0)) + float(h.get("heal", 0))
	var near := state.nearest_enemy_index()
	if near >= 0:
		v += _poison_value(text, state, near)
	for w in ["poison", "potion", "regen", "strengthen", "invisib", "draw", "discard", "armor", "heal"]:
		if text.find(w) >= 0:
			v += 2.0
	if str(h.get("type", "")) in ["POWER", "UTILITY"] and v <= 0.0:
		v += 1.5
	if not bool(h.get("playable", true)):
		v -= 2.0
	return v

static func _worst_card_index(state: SimState, exclude: int) -> int:
	var worst := -1
	var worst_v := INF
	for h in state.hand:
		if h["index"] == exclude:
			continue
		if h["id"] == "volatile_mixture":
			return h["index"]
		var v := float(h["damage"]) + float(h["block"]) + float(h["heal"])
		if not h["playable"]:
			v -= 5.0
		if v < worst_v:
			worst_v = v
			worst = h["index"]
	return worst

## Per enemy: when its telegraphed action lands, whether it is a hit, how
## hard, and whether it reaches the player from where it stands.
func _threats(state: SimState) -> Array:
	var out: Array = []
	for e in state.enemies:
		if e["structure"]:
			continue
		var intent: Dictionary = e["intent"]
		var nm := str(intent.get("name", ""))
		var cost := maxi(1, int(intent.get("cost", 1)))
		var counter := int(intent.get("counter", 0))
		var is_hit := nm != "" and not _is_move_name(nm)
		var reach := maxi(1, int(e["attack_range"]))
		var in_reach: bool = e["distance"] <= reach
		# The cheapest swing in its moveset: what it reaches for once it arrives.
		var hit_cost := cost
		for act in e["actions"]:
			if not _is_move_name(str(act.get("name", ""))):
				hit_cost = mini(hit_cost, maxi(1, int(act.get("tempo_cost", cost))))
		# Out of reach and walking: its first hit lands after the move fires
		# and a swing winds up; after that it hits on its swing's cadence.
		var fires_in := maxi(1, cost - counter)
		var effective_hit := is_hit
		if not in_reach and not is_hit:
			var tiles_short: int = maxi(0, e["distance"] - reach)
			# One move action closes move_distance tiles (1 for most); until
			# the inspect panel says otherwise assume one tile per move.
			fires_in = fires_in + (tiles_short - 1) * cost + hit_cost
			effective_hit = true
		out.append({
			"index": e["index"],
			"fires_in": fires_in,
			"cost": hit_cost if effective_hit else cost,
			"is_hit": effective_hit,
			"damage": int(e["attack_damage"]),
			"in_reach": in_reach or (effective_hit and not is_hit),
			"arriving": not in_reach,
			"distance": e["distance"],
			"reach": reach,
			"hp": int(e["hp"]) + int(e["armor"]),
		})
	return out

static func _is_move_name(nm: String) -> bool:
	var low := nm.to_lower()
	for w in MOVE_ACTION_WORDS:
		if low.find(w) >= 0:
			return true
	return false

## Damage the player expects to take over the next `window` tempo if they
## stand still, from one threat.
static func _incoming_from(t: Dictionary, window: int) -> int:
	if not t["is_hit"] or not t["in_reach"]:
		return 0
	if t["fires_in"] > window:
		return 0
	var hits: int = 1 + int(floor(float(window - t["fires_in"]) / float(t["cost"])))
	return hits * int(t["damage"])

static func _incoming(threats: Array, window: int, skip_index: int = -1) -> int:
	var total := 0
	for t in threats:
		if t["index"] == skip_index:
			continue
		total += _incoming_from(t, window)
	return total

func _score(a: Dictionary, state: SimState, threats: Array) -> float:
	var kind := str(a["type"])
	var tempo := 1
	var gain := 0.0
	var mana := 0
	var hp_ratio := float(state.player_hp) / float(maxi(1, state.player_max_hp))
	var hp_weight := 2.0 if hp_ratio < LOW_HP else 1.0
	var killed_index := -1
	match kind:
		"play":
			var c: Dictionary = state.hand[a["card"]]
			tempo = maxi(1, int(c["tempo"]))
			mana = int(c["mana"])
			var target := str(a.get("target", ""))
			var text: String = str(c["description"]).to_lower()
			if target.begins_with("enemy:"):
				var idx := int(target.substr(6))
				var t := _threat_for(threats, idx)
				var dmg := int(a.get("expected_damage", 0))
				if t.is_empty():
					gain += dmg
				else:
					var effective: int = mini(dmg, int(t["hp"]))
					gain += effective
					if dmg >= int(t["hp"]):
						killed_index = idx
						# The hits this enemy would have landed over the horizon.
						gain += _incoming_from(t, HORIZON) * hp_weight * 0.5
					gain += _control_value(text, t, tempo) * hp_weight
					if _mentions_any(text, AMP_WORDS):
						gain += 0.25 * maxf(1.0, float(dmg))
					# Armor Break and kin: stripping plate is damage the next hits
					# no longer have to chew through.
					if dmg <= 0 and text.find("armor") >= 0:
						gain += minf(float(state.enemies[idx]["armor"]), 12.0)
				gain += _poison_value(text, state, idx)
			elif target.begins_with("point:"):
				# An aimed cloud: price its poison on the nearest enemy to the aim.
				var near := state.nearest_enemy_index()
				if near >= 0:
					gain += _poison_value(text, state, near)
				gain += _self_value(c, text, state, threats, tempo, hp_weight)
			else:
				gain += _self_value(c, text, state, threats, tempo, hp_weight)
			gain += _discard_value(c, text, state)
			gain += _pick_card_value(c, state, target, hp_weight)
		"attack":
			tempo = maxi(1, int(a.get("tempo", state.basic_attack_tempo)))
			var idx := int(str(a.get("target", "enemy:-1")).substr(6))
			var t := _threat_for(threats, idx)
			var dmg := int(a.get("expected_damage", 0))
			if t.is_empty():
				gain += dmg
			else:
				gain += mini(dmg, int(t["hp"]))
				if dmg >= int(t["hp"]):
					killed_index = idx
					gain += _incoming_from(t, HORIZON) * hp_weight * 0.5
		"block":
			tempo = 5
			var block := 3   # Basic Block's floor; the shield's real value is unseen here
			gain += minf(block, _incoming(threats, tempo + 5)) * hp_weight
		"wait":
			tempo = 1
		"move":
			tempo = 1
			gain += _move_value(a, state, threats, hp_weight)
		"item_skill":
			var sk: Dictionary = state.skills[int(a["skill"])]
			mana = int(sk["mana"])
			tempo = 2 if str(sk["fx"]) == "slice" else 1
			var sv := _skill_value(sk, str(a.get("target", "self")), state, threats, hp_weight)
			gain += float(sv["gain"])
			if int(sv["kill"]) >= 0:
				killed_index = int(sv["kill"])
		"weapon_swap":
			var sw: Dictionary = state.weapon_swaps[int(a["swap"])]
			mana = int(sw["mana"])
			tempo = maxi(1, int(sw["tempo"]))
			gain += _swap_value(sw, state)
		"flash_block":
			# Sidestep: 2 block (or a Flash Cut strike) for points that refill
			# on their own; only worth it when something is about to land.
			if state.flash_strike:
				gain += float(PlayerStats.FLASH_STRIKE_DAMAGE)
			else:
				gain += minf(float(PlayerStats.FLASH_BLOCK_ARMOR), float(_incoming(threats, 3))) * hp_weight
		"flash_proc":
			# A tick toward the DEX proc: the next attack at half tempo and
			# 20 mana off. Worth most when one tick is all it takes.
			var best := _best_attack(state)
			gain += (0.4 if state.attacks_until_proc <= 2 else 0.1) * float(best)
		"brain_draw":
			gain += _draw_value(state) * (1.0 - float(state.brain_draw_cost) / 40.0)
		"brain_peek":
			gain += 0.0   # information we cannot price; never ahead of waiting
	# What committing here costs. A hit that lands in the next tempo lands
	# whatever we do, so it is no reason to prefer waiting over swinging;
	# what a longer action costs is the hits beyond that first tempo we can
	# no longer answer (block, sidestep, step away) — weighted, since often
	# there is nothing to answer them with anyway. A lethal exposure is the
	# exception: never commit into it. Point spends and flash moves pass no
	# tempo: nothing acts meanwhile.
	var instant: bool = kind in ["flash_block", "flash_proc", "brain_draw", "brain_peek"] \
		or (kind == "move" and bool(a.get("flash", false))) \
		or (kind == "weapon_swap" and int(state.weapon_swaps[int(a["swap"])]["tempo"]) == 0)
	# Points spent are points not held for the dodge or draw that matters.
	match kind:
		"flash_block": gain -= FLASH_POINT_VALUE * float(state.flash_block_cost)
		"flash_proc": gain -= FLASH_POINT_VALUE * float(state.flash_proc_cost)
		"brain_draw": gain -= BRAIN_POINT_VALUE * float(state.brain_draw_cost)
		"brain_peek": gain -= BRAIN_POINT_VALUE * float(state.brain_peek_cost)
		"move":
			if bool(a.get("flash", false)) and int(state.main.player.get_stats().free_move_tiles) <= 0:
				gain -= FLASH_POINT_VALUE * float(PlayerStats.FLASH_COST_MOVE)
	var incoming := 0 if instant else _incoming(threats, tempo, killed_index)
	var unavoidable := 0 if instant else _incoming(threats, 1, killed_index)
	# Committing costs at most what we could otherwise have answered with:
	# the best block in hand, a sidestep, or a step out of a melee reach.
	var answerable := minf(float(maxi(0, incoming - unavoidable)), _mitigation_capacity(state, threats))
	var loss := answerable * COMMIT_WEIGHT * hp_weight
	if instant and kind != "brain_peek":
		gain += 0.05   # a free action beats waiting
	if incoming >= state.player_hp + state.player_armor:
		loss += 1000.0   # lethal: anything else first
	var score := (gain - loss) / float(tempo) - mana * MANA_WEIGHT
	# A free action (0 tempo, 0 mana) costs nothing to take first.
	if kind == "play" and int(state.hand[a["card"]]["tempo"]) == 0 and mana == 0 and gain >= 0.0:
		score += 0.5
	return score

## A weapon swap, from what the player sees: the auto attack's reach against
## the nearest enemy (a bow reaches 5, anything else 1, and a bow swing costs
## 1 tempo more; reach is worth the tiles of walking it saves, at the
## auto attack's damage per tempo, less the last step a melee enemy closes
## itself),
## Conditional cards in hand turning ranged or melee with the bow, the cards
## the incoming weapons bring (only Brad's free rack exchange puts them in
## hand; elsewhere they land in the discard pile and count for nothing) and
## the cards in hand the outgoing weapons take with them, less a whole swing when it would undo a swap made within the last
## swing. Nothing gained is a strong no: a free swap must never be taken for
## its own sake.
static func _swap_value(sw: Dictionary, state: SimState) -> float:
	var near := state.nearest_enemy_index()
	if near < 0:
		return -5.0
	var d := int(state.enemies[near]["distance"])
	var reach_now := state.basic_attack_reach
	var reach_alt := 5 if bool(sw["ranged"]) else 1
	var swing := float(state.basic_attack_damage)
	var g := 0.0
	# Reach is tempo: every tile the longer reach saves walking is a tempo
	# the auto attack spends swinging instead (at its damage per tempo).
	# A melee enemy closes the last step itself to hit us, so that step is
	# never ours to walk: a sidestep to 2 tiles beside a troll saves nothing.
	var per_tempo := swing / float(maxi(1, state.basic_attack_tempo))
	var closes := 1 if int(state.enemies[near].get("attack_range", 1)) <= 1 else 0
	if d > reach_now and reach_alt > reach_now:
		g += per_tempo * float(maxi(0, mini(d, reach_alt) - reach_now - closes))
	elif d > reach_alt and reach_now > reach_alt:
		g -= per_tempo * float(maxi(0, mini(d, reach_now) - reach_alt - closes))   # the walk it adds
	elif d <= 1 and reach_now > reach_alt:
		g += swing / 6.0          # in melee the bow's extra tempo per swing is waste
	if bool(sw["ranged"]) != state.weapons_ranged and d - closes > 1:
		for h in state.hand:
			if bool(h.get("conditional", false)) and int(h["damage"]) > 0:
				g += (0.5 if bool(sw["ranged"]) else -0.5) * float(h["damage"])
	# Only Brad's free rack puts the incoming cards in hand. Anywhere else they
	# land in the discard pile, unplayable until the next reshuffle and gone
	# again on the swap back: no reason to swap.
	if bool(sw["free"]):
		for c in sw["incoming"]:
			g += _card_worth(c, state) * 0.8
	for hi in sw["leaving"]:
		if hi >= 0 and hi < state.hand.size():
			g -= _card_worth(state.hand[hi], state)
	# Commitment: swapping back within one swing of the last swap throws away
	# both, so it must beat a whole swing (a sidestep to 2 tiles beside a
	# melee enemy is not a reason to string the bow).
	if SimState.last_swap_tempo >= 0 and state.global_tempo - SimState.last_swap_tempo < state.basic_attack_tempo:
		g -= swing
	if g <= 0.0:
		return -5.0
	return g

## How much of a coming hit we could have blunted had we stayed free:
## the best block in hand, the sidestep, or stepping out of melee reach.
static func _mitigation_capacity(state: SimState, threats: Array) -> float:
	var cap := 0.0
	for h in state.hand:
		if h["playable"] and int(h["block"]) > 0:
			cap = maxf(cap, float(h["block"]))
	if state.flash_points >= state.flash_block_cost:
		cap = maxf(cap, float(PlayerStats.FLASH_BLOCK_ARMOR))
	if state.can_move and not state.movement_locked:
		for t in threats:
			if t["is_hit"] and t["in_reach"] and not t.get("arriving", false) and int(t["reach"]) <= 1 and not state.walkable_neighbours(state.player_cell).is_empty():
				cap = maxf(cap, float(t["damage"]))
	return cap

static func _threat_for(threats: Array, index: int) -> Dictionary:
	for t in threats:
		if t["index"] == index:
			return t
	return {}

static func _mentions_any(text: String, words: Array) -> bool:
	for w in words:
		if text.find(w) >= 0:
			return true
	return false

## Stun / root / disarm on an enemy about to hit: the damage it will not deal.
static func _control_value(text: String, t: Dictionary, tempo: int) -> float:
	var duration := 0
	for w in CONTROL_WORDS:
		if text.find(w) >= 0:
			duration = maxi(duration, int(CONTROL_WORDS[w]))
	if duration <= 0:
		return 0.0
	var m := RegEx.new()
	m.compile("(\\d+) tempo")
	var found := m.search(text)
	if found:
		duration = maxi(1, int(found.get_string(1)))
	# Control lands when the card resolves (tick 1 of its tempo); hits that
	# would have landed inside the control window are prevented.
	return float(_incoming_from(t, tempo + duration))

## "Apply N Poison": the damage those stacks tick for over the next cycles
## (one tick a cycle, losing a stack each), plus Pop Rocks on a target that
## already carries some.
static func _poison_value(text: String, state: SimState, enemy_index: int) -> float:
	var m := RegEx.new()
	m.compile("(\\d+) poison")
	var found := m.search(text)
	if found == null:
		return 0.0
	var n := int(found.get_string(1))
	if text.find("below 50%") >= 0:
		var e: Dictionary = state.enemies[enemy_index]
		if float(e["hp"]) < 0.5 * float(e["max_hp"]):
			n = maxi(n, 2 * n)
	var existing := int(state.enemies[enemy_index]["poison"])
	var stacks := existing + n
	var dmg := 0.0
	for k in range(3):   # three cycles of the horizon
		dmg += maxf(0.0, float(stacks - k))
	if existing > 0:
		dmg -= maxf(0.0, float(existing)) * 2.0   # the part that would have ticked anyway
	if existing > 0 and state.passives.has("pop_rocks"):
		dmg += float(stacks) / 3.0
	var hp_left := float(state.enemies[enemy_index]["hp"])
	return minf(dmg, hp_left)

## Discard engines: what one more card in the discard pile is worth with
## this character's passives and hand.
static func _discard_value(c: Dictionary, text: String, state: SimState) -> float:
	var v := 0.0
	var discards := 0
	if text.find("discard a card") >= 0 or text.find("discard a random card") >= 0:
		discards = 1
	elif text.find("discard your whole hand") >= 0 or text.find("discard hand") >= 0:
		discards = maxi(0, state.hand.size() - 1)
	elif text.find("discard all defensive") >= 0:
		for h in state.hand:
			if h["type"] == "DEFENSE":
				discards += 1
	if c["id"] == "exacerbate_wounds":
		v += 3.0 * float(state.true_discards_this_cycle)
	if discards <= 0:
		return v
	# Volatile Mixture detonates when discarded: certain when we choose, a
	# share of the hand when the discard is random.
	for h in state.hand:
		if h["id"] == "volatile_mixture" and h["index"] != int(c["index"]):
			v += 8.0 if text.find("discard a card") >= 0 else 8.0 * float(discards) / float(maxi(1, state.hand.size() - 1))
			break
	if state.passives.has("ladder_work"):
		v += float(discards) * float(PassiveScaling.value("ladder_work", "damage_per_discard", int(state.passives["ladder_work"])))
	if state.passives.has("keep_them_guessing"):
		v += 0.3 * float(discards)
	for h in state.hand:
		if h["id"] == "exacerbate_wounds" and h["index"] != int(c["index"]):
			v += 3.0 * float(discards)
			break
	if text.find("draw") >= 0:
		v += _draw_value(state) * 0.5   # the card comes back as a fresh one
	return v

## What a gauntlet skill is worth now, in the same terms as a card: block
## and heal against what is coming, damage against the target's health,
## draws by hand size, control by the hits it prevents.
static func _skill_value(sk: Dictionary, target: String, state: SimState, threats: Array, hp_weight: float) -> Dictionary:
	var out := {"gain": 0.0, "kill": -1}
	var fx := str(sk["fx"])
	var block := 0
	var heal := 0
	var dmg := 0
	match fx:
		"chain_guard": block = 2
		"band_aid": heal = 5
		"clang": block = 8
		"slurp_and_pad":
			heal = 5
			block = 3
		"defense_one":
			block = 5
			out["gain"] += 5.0 if state.basic_attack_reach <= 1 else 0.0
		"well_placed_guard", "imbue_tree":
			# Thorns return damage for every hit taken while they last.
			var thorns := 5 if fx == "well_placed_guard" else 10
			var hits := 0
			for t in threats:
				if t["is_hit"] and int(t["fires_in"]) <= HORIZON:
					hits += 1
			out["gain"] += float(mini(hits, 2) * thorns) * 0.5
			if fx == "imbue_tree":
				heal = mini(5, state.player_max_hp - state.player_hp)
		"future_is_bright":
			out["gain"] += 1.0 if state.main.deck_manager.draw_pile.size() <= 2 else 0.2
		"continue_to_move":
			out["gain"] += _draw_value(state)
		"house_rule":
			out["gain"] += _draw_value(state) + 1.0
		"zeet":
			dmg = int(state.intelligence / 2)
		"lethal_poke", "slice":
			dmg = state.basic_attack_damage
		"fan_save":
			if target.begins_with("enemy:"):
				var t := _threat_for(threats, int(target.substr(6)))
				if not t.is_empty() and t["is_hit"]:
					out["gain"] += float(int(t["damage"])) * 0.3 * hp_weight
		"coming_in":
			# Closing the gap: the basic attack it puts in reach, plus Now You
			# See Me's invisibility when that is ready (it is a displacement).
			out["gain"] += float(state.basic_attack_damage) * 0.5
			if state.nysm_ready:
				out["gain"] += float(_incoming(threats, 6)) * hp_weight + 1.0
		"suck":
			out["gain"] += 0.5 * float(maxi(0, state.enemies.size() - 1))
	if block > 0:
		out["gain"] += minf(float(block), float(_incoming(threats, 6))) * hp_weight
	if heal > 0:
		var missing := state.player_max_hp - state.player_hp
		var w := 1.5 if float(state.player_hp) / float(maxi(1, state.player_max_hp)) < LOW_HP else 0.3
		out["gain"] += minf(float(heal), float(missing)) * w
	if dmg > 0 and target.begins_with("enemy:"):
		var idx := int(target.substr(6))
		var t := _threat_for(threats, idx)
		if t.is_empty():
			out["gain"] += dmg
		else:
			out["gain"] += mini(dmg, int(t["hp"]))
			if dmg >= int(t["hp"]):
				out["kill"] = idx
				out["gain"] += _incoming_from(t, HORIZON) * hp_weight * 0.5
	return out

## The card a picking card should take: Sky Attack discards the hardest
## hitter (its damage becomes the shot), Mirror Mirror copies the best card.
static func _own_pick(c: Dictionary, state: SimState, exclude: int) -> int:
	match str(c["id"]):
		"sky_attack":
			return _best_index(state, exclude, true)
		"mirror_mirror":
			return _best_index(state, exclude, false)
	return -1

static func _best_index(state: SimState, exclude: int, damage_only: bool) -> int:
	var best := -1
	var best_v := -1.0
	for h in state.hand:
		if h["index"] == exclude:
			continue
		var v := float(h["damage"]) if damage_only else float(h["damage"]) + float(h["block"]) + float(h["heal"])
		if v > best_v:
			best_v = v
			best = h["index"]
	return best

## Cards whose worth is another card: what the pick or the fetch is worth.
static func _pick_card_value(c: Dictionary, state: SimState, target: String, hp_weight: float) -> float:
	match str(c["id"]):
		"sky_attack":
			var i := _best_index(state, int(c["index"]), true)
			for h in state.hand:
				if h["index"] == i:
					return float(h["damage"]) + 1.0   # the shot, plus the high ground it leaves
		"mirror_mirror":
			var j := _best_index(state, int(c["index"]), false)
			for h in state.hand:
				if h["index"] == j:
					return 0.8 * (float(h["damage"]) + float(h["block"]) + float(h["heal"]))
		"collect_arrows":
			return _draw_value(state) * float(mini(2, state.discard_size))
		"release_tension":
			if target.begins_with("enemy:"):
				var e: Dictionary = state.enemies[int(target.substr(6))]
				if not (e.get("effects", []) as Array).is_empty() or int(e.get("poison", 0)) > 0:
					return minf(3.0, float(state.player_max_hp - state.player_hp)) * hp_weight + 1.0
	return 0.0

static func _draw_value(state: SimState) -> float:
	if state.hand.size() <= 2:
		return 3.0
	if state.hand.size() <= 4:
		return 1.5
	return 0.5

static func _best_attack(state: SimState) -> int:
	var best := 0
	for h in state.hand:
		if h["playable"] and int(h["damage"]) > best:
			best = int(h["damage"])
	return maxi(best, state.basic_attack_damage)

## Block, heal, buffs: what a self-targeted card is worth right now.
static func _self_value(c: Dictionary, text: String, state: SimState, threats: Array, tempo: int, hp_weight: float) -> float:
	var v := 0.0
	# Invisibility: every enemy skips its actions while it lasts — every hit
	# they would have landed over the card's tempo plus the duration.
	if text.find("invisib") >= 0:
		var dur := 5
		var m := RegEx.new()
		m.compile("(\\d+) tempo")
		var found := m.search(text)
		if found:
			dur = maxi(1, int(found.get_string(1)))
		v += float(_incoming(threats, tempo + dur)) * hp_weight + 1.0
	# A displacement with Now You See Me ready is five tempo of invisibility
	# (Blink, Swap, Shift, Smoke Bomb...), priced the same way.
	if state.nysm_ready and str(c.get("id", "")) in SimState.DISPLACEMENT_CARDS:
		v += float(_incoming(threats, tempo + 5)) * hp_weight + 1.0
	var block := int(c["block"])
	if block > 0:
		# Armor persists (it decays per cycle), so it covers the next cycle too.
		v += minf(float(block), float(_incoming(threats, tempo + 5))) * hp_weight
	var heal := int(c["heal"])
	if heal > 0:
		var missing := state.player_max_hp - state.player_hp
		var w := 1.5 if float(state.player_hp) / float(maxi(1, state.player_max_hp)) < LOW_HP else 0.3
		v += minf(float(heal), float(missing)) * w
	# A buff that feeds the next attack (Strengthen, Empower, "+N damage")
	# is worth a share of the best attack in hand, when there is one to feed.
	if int(c["damage"]) <= 0 and block <= 0 and heal <= 0 \
			and (text.find("next attack") >= 0 or text.find("damage") >= 0 or text.find("strength") >= 0 or text.find("empower") >= 0):
		var best_attack := 0
		for h in state.hand:
			if h["playable"] and int(h["damage"]) > best_attack and h["index"] != int(c["index"]):
				best_attack = int(h["damage"])
		if best_attack > 0 and state.nearest_enemy_index() >= 0:
			v += 0.3 * float(best_attack)
	if text.find("draw") >= 0:
		v += _draw_value(state)
	if text.find("mana") >= 0 and state.player_mana < 20:
		v += 2.0
	return v

## Closing in when nothing reaches; stepping out of a melee hit that is
## about to land (its swing is measured in tiles when it fires).
func _move_value(a: Dictionary, state: SimState, threats: Array, hp_weight: float) -> float:
	var cell := SimScenario.cell_of(a["cell"])
	var nearest := state.nearest_enemy_index()
	if nearest < 0:
		return 0.0
	var e: Dictionary = state.enemies[nearest]
	var d_now: int = e["distance"]
	var d_after: int = absi(cell.x - e["cell"].x) + absi(cell.y - e["cell"].y)
	var t := _threat_for(threats, nearest)
	# Dodging: a melee hit landing next tempo misses if we step out of reach.
	# On flash points the step passes no tempo, so even a hit two tempo out
	# is worth stepping away from.
	var window: int = 2 if bool(a.get("flash", false)) else 1
	if not t.is_empty() and t["is_hit"] and t["in_reach"] and not t.get("arriving", false) and t["fires_in"] <= window and d_after > int(t["reach"]):
		return float(t["damage"]) * hp_weight + 0.5
	var card_hits_now := false
	var best_out := 0      # the best playable hit in hand that only lands from nearer
	var best_out_range := 1
	for h in state.hand:
		if h["playable"] and h["damage"] > 0:
			if state.main._is_target_in_card_range(state.main.deck_manager.hand[h["index"]], e["node"]):
				card_hits_now = true
			elif int(h["damage"]) > best_out:
				best_out = int(h["damage"])
				best_out_range = maxi(1, int(h["range"]))
	var can_hit_now := card_hits_now or d_now <= state.basic_attack_reach
	if not can_hit_now and d_after < d_now:
		return 1.0   # closing in is progress
	# A bow plinking from range while blades wait in hand: walking in is
	# progress when the card beats the auto attack, worth half its hit
	# spread over the tiles still to close.
	if not card_hits_now and d_after < d_now and best_out > state.basic_attack_damage:
		return maxf(1.0, 0.5 * float(best_out) / float(maxi(1, d_now - best_out_range)))
	return -0.5      # otherwise a move is a tempo spent on nothing
