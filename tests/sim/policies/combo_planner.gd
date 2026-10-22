extends SimPolicy

## The combo-aware player (Milestone 5). Lookahead scores one action at a
## time; this planner enumerates every legal play SEQUENCE that fits the
## rest of the current tempo bar (its tempo and mana), evaluates the state
## at the bar's end, commits to the sequence's first action, and re-plans
## at the next decision. Lookahead stays untouched as the control: the
## planner carries a Lookahead instance and prices every step with its
## own _score, over a shadow of the state the earlier steps have changed
## (an enemy's health and armor, the Vulnerable / Weaken stacks and the
## control a setup card put on it, the mana and the cards spent), so a
## setup card is worth what the hits after it gain, not the flat 0.25 the
## one-step view gives it.
##
## Evaluation = the sum of lookahead's per-step terms + the CHANGE in the
## weighted potential terms between now and bar end (WEIGHTS): combo
## partners held / in the deck, mana banked toward a registered payoff,
## amp / control left on enemies for the next bar, and a registered payoff
## the setup this bar enables next bar (a macro-action spanning two bars);
## a step whose card rolled a failed outcome counts for less. Plans are
## compared per tempo they use, so a one-step plan scores exactly what
## lookahead gives that action and the planner is lookahead with depth: on
## a deck with nothing to set up it makes the same choices. The empty
## sequence — hold / pass — is a legal plan (lookahead's wait); single
## instants and moves are one-step plans.
##
## Symmetric orderings are pruned: two steps that do not change each
## other's value are explored in one order only (by their place in the
## action list); a setup followed by a hit, or a hit followed by a setup,
## are different plans and both are kept.

const LookaheadScript := preload("res://tests/sim/policies/lookahead.gd")
const SimCombos := preload("res://tests/sim/combos.gd")

## Every tunable in one place.
const WEIGHTS := {
	"vulnerable_amp": 0.30,     # the game's +30 % on every player hit while a Vulnerable stack remains
	"weaken_amp": 0.30,         # Weaken on us: -30 % on our hits (a setup can also remove it — not modelled)
	"debuff_remaining": 0.5,    # amp / control still on an enemy at bar end: share of what the next bar's best hit gains from it
	"partners_held": 0.15,      # per registered combo: payoff × (partners held, unplayed) / cards
	"partners_in_deck": 0.05,   # … and partners still in the draw pile
	"mana_banked": 0.10,        # payoff × mana left toward a registered payoff card in hand (capped at 1)
	"roll_fail": 0.5,           # a step whose card has pre-rolled its failed outcome counts for this share
	"next_bar_payoff": 0.60,    # a registered payoff the setup this bar enables next bar
	"max_nodes": 4000,          # enumeration budget per decision
	"max_depth": 6,             # steps per plan
}

const AMP_WORDS := ["vulnerable", "weaken", "weakened", "expose", "exposed"]
const CONTROL_WORDS := {"stun": 5, "stuns": 5, "stunned": 5, "freeze": 5, "frozen": 5, "root": 5, "rooted": 5,
	"trip": 3, "tripped": 3, "disarm": 5, "disarmed": 5, "silence": 5, "silenced": 5}
const SETUP_WORDS := ["next attack", "strengthen", "empower", "mark", "remove", "armor", "poison"]
const PLAN_TYPES := ["play", "attack", "block", "item_skill", "manifest"]
const IDLE_LIMIT := 6

var debug := false
var _la = null
var _nodes := 0
var _idle_streak := 0
var _idle_sig := ""
var _re_vuln := RegEx.new()
var _re_tempo := RegEx.new()
var _re_armor := RegEx.new()
var last_plan: Array = []   # labels of the last committed plan (for the summary / debugging)

func _init() -> void:
	name = "combo_planner"
	_la = LookaheadScript.new()
	_re_vuln.compile("apply (\\d+) vulnerable")
	_re_tempo.compile("(\\d+) tempo")
	_re_armor.compile("remove (\\d+) armor")

func setup(sc: Dictionary) -> void:
	super.setup(sc)
	_la.setup(sc)
	_la.debug = false
	_idle_streak = 0
	_idle_sig = ""

func answer_prompt(kind: String, options: Array, state: SimState = null) -> int:
	return _la.answer_prompt(kind, options, state)

func answer_multi(kind: String, options: Array, state: SimState = null) -> Array:
	return _la.answer_multi(kind, options, state)

# ----- the decision ------------------------------------------------------------

func choose_action(state: SimState) -> Variant:
	var picked: Variant = _plan(state)
	# Lookahead's stalemate breaker, so a fight never reads as a timeout the
	# build never had to take.
	var sig := "%d" % state.player_hp
	for e in state.enemies:
		sig += ":%d" % int(e["hp"])
	if picked is Dictionary and str(picked.get("type", "")) == "wait" and sig == _idle_sig:
		_idle_streak += 1
	else:
		_idle_streak = 0
	_idle_sig = sig
	if _idle_streak >= IDLE_LIMIT and picked is Dictionary and str(picked.get("type", "")) == "wait":
		var commit: Dictionary = _la._break_stalemate(state)
		if not commit.is_empty():
			_idle_streak = 0
			return commit
	return picked

func _plan(state: SimState) -> Variant:
	var legal := state.legal_actions()
	if legal.is_empty():
		return {"type": "wait"}
	var threats: Array = _la._threats(state)
	var budget := maxi(1, state.threshold - state.tempo)
	var wait_score: float = _la._score({"type": "wait"}, state, threats)
	var registry: Array = SimCombos.registry().filter(func(e): return SimCombos.preconditions_ok(e, state))

	# Plan steps: what a sequence is made of. Everything else is a one-step plan.
	var steps: Array = []
	var singles: Array = []
	for a in legal:
		if str(a["type"]) in PLAN_TYPES:
			steps.append(a)
		else:
			singles.append(a)

	var shadow0 := _shadow(state, threats)
	var pot_now := _potential(shadow0, state, threats, registry, budget)
	# The empty plan: hold — lookahead's wait, per tempo.
	var best := {"value": wait_score, "seq": [], "first": {"type": "wait"}}
	_nodes = 0
	_dfs([], shadow0, 0.0, steps, state, threats, registry, budget, pot_now, best)
	# One-step plans for moves, point spends, swaps, grips, jail, dismiss:
	# lookahead's own score (they change no potential).
	for a in singles:
		var t := str(a["type"])
		if t == "wait":
			continue
		var v: float = _la._score(a, state, threats)
		if v > best["value"]:
			best = {"value": v, "seq": [a], "first": a}
	if debug:
		print("[PLANNER] t%d budget %d: %s = %.2f (%d nodes)" % [state.global_tempo, budget,
			" > ".join(_labels(best["seq"])) if not best["seq"].is_empty() else "hold", best["value"], _nodes])
	last_plan = _labels(best["seq"])
	var first = best["first"]
	if first == null:
		return {"type": "wait"}
	if str(first.get("type", "")) == "play":
		var c: Dictionary = state.hand[int(first["card"])]
		var own_pick: int = LookaheadScript._own_pick(c, state, int(first["card"]))
		if own_pick >= 0 and not first.has("picks"):
			first = first.duplicate()
			first["picks"] = {"picked_card": own_pick}
		elif str(c["description"]).to_lower().find("discard a card") >= 0 and not first.has("picks"):
			var pick: int = LookaheadScript._worst_card_index(state, int(first["card"]))
			if pick >= 0:
				first = first.duplicate()
				first["picks"] = {"picked_card": pick}
	return first

static func _labels(seq: Array) -> Array:
	return seq.map(func(x): return SimPolicy.action_label(x["action"] if x is Dictionary and x.has("action") else x))

# ----- enumeration ------------------------------------------------------------

func _dfs(seq: Array, shadow: Dictionary, value: float, steps: Array, state: SimState, threats: Array,
		registry: Array, budget: int, pot_now: float, best: Dictionary) -> void:
	# Score this sequence as a finished plan, per tempo it uses: its steps'
	# worth plus what it changed in the bar-end potential.
	if not seq.is_empty():
		var total: float = (value + _potential(shadow, state, threats, registry, budget) - pot_now) / maxf(1.0, float(shadow["tempo"]))
		if total > best["value"]:
			best["value"] = total
			best["seq"] = seq.duplicate()
			best["first"] = seq[0]["action"]
	if seq.size() >= int(WEIGHTS["max_depth"]) or _nodes >= int(WEIGHTS["max_nodes"]) or bool(shadow.get("closed", false)):
		return
	var last: Dictionary = seq.back() if not seq.is_empty() else {}
	for k in range(steps.size()):
		var a: Dictionary = steps[k]
		if not last.is_empty() and not _order_ok(last, k, a, state):
			continue
		var step := _apply_step(a, k, shadow, state, threats, budget)
		if step.is_empty():
			continue
		_nodes += 1
		seq.append({"action": a, "ordinal": k, "setup": _is_setup(a, state), "hit": _is_hit(a)})
		_dfs(seq, step["shadow"], value + float(step["value"]), steps, state, threats, registry, budget, pot_now, best)
		seq.pop_back()
		if _nodes >= int(WEIGHTS["max_nodes"]):
			return

## Symmetric orderings pruned: after step `last`, step k is explored only if
## it comes later in the action list, repeats the auto attack, or the two
## change each other's value (a setup and a hit, in either order).
func _order_ok(last: Dictionary, k: int, a: Dictionary, state: SimState) -> bool:
	if k > int(last["ordinal"]):
		return true
	if str(a["type"]) == "attack" and k == int(last["ordinal"]):
		return true   # another swing
	var setup := _is_setup(a, state)
	var hit := _is_hit(a)
	return (bool(last["setup"]) and hit) or (bool(last["hit"]) and setup)

func _is_hit(a: Dictionary) -> bool:
	return int(a.get("expected_damage", 0)) > 0 or (str(a["type"]) == "item_skill" and str(a.get("fx", "")) in ["zeet", "lethal_poke", "slice"])

func _is_setup(a: Dictionary, state: SimState) -> bool:
	if str(a["type"]) != "play":
		return false
	var text: String = str(state.hand[int(a["card"])]["description"]).to_lower()
	for w in AMP_WORDS + CONTROL_WORDS.keys() + SETUP_WORDS:
		if text.find(w) >= 0:
			return true
	return false

# ----- the shadow state -------------------------------------------------------

## What the earlier steps of a plan have changed, as far as the player can
## see it: per enemy its effective HP (health + armor, lookahead's measure)
## and plate, amp stacks with their clock, control time; our mana; the hand
## indices spent; the tempo used.
func _shadow(state: SimState, threats: Array) -> Dictionary:
	var en := {}
	for e in state.enemies:
		en[int(e["index"])] = {
			"hp": int(e["hp"]) + int(e["armor"]), "armor": int(e["armor"]), "dead": false,
			"vuln": int(e.get("vulnerable", 0)), "vuln_tempo": int(e.get("vulnerable_tempo", 0)), "vuln_at": 0,
			"control": 0, "control_at": 0,
		}
	return {"tempo": 0, "mana": state.player_mana, "used": {}, "enemies": en, "setups": {}, "weakened": "Weaken" in state.debuffs}

func _step_tempo(a: Dictionary, state: SimState) -> int:
	match str(a["type"]):
		"play": return maxi(0, int(state.hand[int(a["card"])]["tempo"]))
		"attack": return maxi(1, int(a.get("tempo", state.basic_attack_tempo)))
		"block": return 4  # main.BASIC_BLOCK_TEMPO
		"item_skill": return 2 if str(a.get("fx", "")) == "slice" else 1
		"manifest": return maxi(0, int(state.manifest[int(a["manifest"])]["tempo"]))
		"move": return 0 if bool(a.get("flash", false)) else 1
		"flash_block", "flash_proc", "brain_draw", "brain_peek", "dismiss": return 0
		"weapon_swap": return int(state.weapon_swaps[int(a["swap"])]["tempo"])
		"grip": return int(state.grips[int(a["grip"])]["tempo"])
		"jail": return 1
	return 1

func _step_mana(a: Dictionary, state: SimState) -> int:
	match str(a["type"]):
		"play": return int(state.hand[int(a["card"])]["mana"])
		"item_skill": return int(state.skills[int(a["skill"])]["mana"])
		"manifest": return int(state.manifest[int(a["manifest"])]["mana"])
		"jail": return 10
	return 0

func _target_index(a: Dictionary) -> int:
	var t := str(a.get("target", ""))
	return int(t.substr(6)) if t.begins_with("enemy:") else -1

## One step on a shadow: {} when it does not fit (tempo, mana, a spent card,
## a dead target); else {"value": lookahead's score × tempo, "shadow": next}.
func _apply_step(a: Dictionary, ordinal: int, shadow: Dictionary, state: SimState, threats: Array, budget: int) -> Dictionary:
	var tempo := _step_tempo(a, state)
	var mana := _step_mana(a, state)
	# A step may run past the bar's end only as the plan's last step (a
	# 3-tempo card with 1 tempo left in the bar is still a play, as it is
	# for lookahead); the plan then ends there.
	var overrun: bool = int(shadow["tempo"]) + tempo > budget and tempo > 0
	if mana > int(shadow["mana"]):
		return {}
	if str(a["type"]) == "play" and shadow["used"].has(int(a["card"])):
		return {}
	if str(a["type"]) == "manifest" and shadow["used"].has("m%d" % int(a["manifest"])):
		return {}
	if str(a["type"]) == "item_skill" and shadow["used"].has("s%d" % int(a["skill"])):
		return {}
	var tidx := _target_index(a)
	if tidx >= 0 and bool(shadow["enemies"][tidx]["dead"]):
		return {}
	if str(a["type"]) == "block" and shadow["used"].has("block"):
		return {}

	# The action as the shadow sees it: hits amplified by the Vulnerable the
	# plan has put on the target, weakened by Weaken on us.
	var mod: Dictionary = a.duplicate(true)
	var mult := 1.0
	if bool(shadow["weakened"]):
		mult -= float(WEIGHTS["weaken_amp"])
	if tidx >= 0:
		if int(shadow["enemies"][tidx]["vuln"]) > 0:
			mult += float(WEIGHTS["vulnerable_amp"])
		mod["expected_damage"] = int(round(float(a.get("expected_damage", 0)) * mult))
	if mod.has("hits"):
		var hits: Array = []
		for hd in mod["hits"]:
			var m := mult
			if int(shadow["enemies"][int(hd[0])]["vuln"]) > 0:
				m += float(WEIGHTS["vulnerable_amp"])
			hits.append([int(hd[0]), int(round(float(hd[1]) * m))])
		mod["hits"] = hits.filter(func(hd): return not bool(shadow["enemies"][int(hd[0])]["dead"]))
		mod["expected_damage"] = 0
		for hd in mod["hits"]:
			mod["expected_damage"] += int(hd[1])
	# Threats as the shadow sees them: health left, control pushing the hit out.
	var mod_threats: Array = []
	for t in threats:
		var sh: Dictionary = shadow["enemies"].get(int(t["index"]), {})
		if sh.is_empty() or bool(sh["dead"]):
			continue
		var mt: Dictionary = t.duplicate()
		mt["hp"] = int(sh["hp"])
		# The clock has moved on by the earlier steps' tempo.
		mt["fires_in"] = maxi(1, int(mt["fires_in"]) - int(shadow["tempo"]))
		var ctrl_left: int = maxi(0, int(sh["control"]) - (int(shadow["tempo"]) - int(sh["control_at"])))
		if ctrl_left > 0:
			mt["fires_in"] = int(mt["fires_in"]) + ctrl_left
		mod_threats.append(mt)
	var score: float = _la._score(mod, state, mod_threats)
	# A card that has pre-rolled its failed outcome does less than its face.
	if str(a["type"]) == "play" and state.hand[int(a["card"])]["rng_index"] != null \
			and int(state.hand[int(a["card"])]["rng_index"]) == -2 and score > 0.0:
		score *= float(WEIGHTS["roll_fail"])
	var value: float = score * maxf(1.0, float(tempo))

	# The next shadow.
	var next: Dictionary = shadow.duplicate(true)
	next["tempo"] = int(shadow["tempo"]) + tempo
	next["mana"] = int(shadow["mana"]) - mana
	match str(a["type"]):
		"play": next["used"][int(a["card"])] = true
		"manifest": next["used"]["m%d" % int(a["manifest"])] = true
		"item_skill": next["used"]["s%d" % int(a["skill"])] = true
		"block": next["used"]["block"] = true
	var text := ""
	if str(a["type"]) == "play":
		text = str(state.hand[int(a["card"])]["description"]).to_lower()
	var landed: Array = []   # [enemy index, damage]
	if tidx >= 0:
		landed.append([tidx, int(mod.get("expected_damage", 0))])
	for hd in mod.get("hits", []):
		landed.append([int(hd[0]), int(hd[1])])
	for ld in landed:
		var sh: Dictionary = next["enemies"][int(ld[0])]
		var dmg := int(ld[1])
		sh["armor"] = maxi(0, int(sh["armor"]) - dmg)
		sh["hp"] = int(sh["hp"]) - dmg
		if int(sh["hp"]) <= 0:
			sh["dead"] = true
	if text != "" and tidx >= 0:
		var sh: Dictionary = next["enemies"][tidx]
		var fv := _re_vuln.search(text)
		if fv:
			sh["vuln"] = int(sh["vuln"]) + int(fv.get_string(1))
			sh["vuln_tempo"] = int(sh["vuln"]) * Enemy.STACK_TEMPO
			sh["vuln_at"] = int(next["tempo"])
			next["setups"][tidx] = true
		var fa := _re_armor.search(text)
		if fa:
			var stripped: int = mini(int(sh["armor"]), int(fa.get_string(1)))
			sh["armor"] = int(sh["armor"]) - stripped
			sh["hp"] = int(sh["hp"]) - stripped
		var dur := 0
		for w in CONTROL_WORDS:
			if text.find(w) >= 0:
				dur = maxi(dur, int(CONTROL_WORDS[w]))
		if dur > 0:
			var ft := _re_tempo.search(text)
			if ft:
				dur = maxi(1, int(ft.get_string(1)))
			sh["control"] = dur
			sh["control_at"] = int(next["tempo"])
			next["setups"][tidx] = true
	next["closed"] = overrun   # the plan ends on an overrunning step
	return {"value": value, "shadow": next}

# ----- bar-end potential --------------------------------------------------------

## What the state at the bar's end is worth beyond what the steps scored.
func _potential(shadow: Dictionary, state: SimState, threats: Array, registry: Array, budget: int) -> float:
	var v := 0.0
	var used: Dictionary = shadow["used"]
	# The best hit we would still hold for the next bar.
	var best_attack := 0
	var best_attack_tempo := maxi(1, state.basic_attack_tempo)
	for h in state.hand:
		if bool(h["playable"]) and int(h["damage"]) > best_attack and not used.has(int(h["index"])):
			best_attack = int(h["damage"])
			best_attack_tempo = maxi(1, int(h["tempo"]))
	var auto_dpt := float(state.basic_attack_damage) / float(maxi(1, state.basic_attack_tempo))
	if state.nearest_enemy_index() >= 0:
		best_attack = maxi(best_attack, state.basic_attack_damage)
	# Amp and control still on an enemy at bar end: a share of what the next
	# bar's hits gain from it, for as long as it lasts.
	for idx in shadow["enemies"]:
		var sh: Dictionary = shadow["enemies"][idx]
		if bool(sh["dead"]):
			continue
		var vuln_left: int = maxi(0, int(sh["vuln_tempo"]) - (budget - int(sh["vuln_at"])))
		if int(sh["vuln"]) > 0 and vuln_left > 0 and best_attack > 0:
			var hits := minf(2.0, float(vuln_left) / float(best_attack_tempo))
			v += float(WEIGHTS["debuff_remaining"]) * float(WEIGHTS["vulnerable_amp"]) * float(best_attack) * maxf(hits, 0.5)
		var ctrl_left: int = maxi(0, int(sh["control"]) - (budget - int(sh["control_at"])))
		if ctrl_left > 0:
			var t: Dictionary = LookaheadScript._threat_for(threats, int(idx))
			if not t.is_empty():
				v += float(WEIGHTS["debuff_remaining"]) * float(LookaheadScript._incoming_from(t, ctrl_left))
	# Registered combos: partners held and in the deck, mana banked toward
	# the payoff, and a payoff next bar that this bar's setup enables.
	for entry in registry:
		var cards: Array = entry["cards"]
		var held: Array = SimCombos.held_indices(entry, state, used)
		var n_held := 0
		for i in held:
			if i >= 0:
				n_held += 1
		var played := 0
		for cid in cards:
			for i in used:
				if i is int and str(state.hand[i]["id"]) == str(cid):
					played += 1
					break
		if played == cards.size():
			continue   # realised inside the plan: its steps carry the value
		var payoff := float(entry.get("payoff", 0.0))
		if n_held > 0:
			v += payoff * float(WEIGHTS["partners_held"]) * float(n_held) / float(cards.size())
			v += payoff * float(WEIGHTS["partners_in_deck"]) * float(SimCombos.in_deck_count(entry, state, held)) / float(cards.size())
		var last_i: int = held[held.size() - 1]
		if last_i >= 0:
			var pay: Dictionary = state.hand[last_i]
			var need := int(pay["mana"])
			if need > 0:
				v += payoff * float(WEIGHTS["mana_banked"]) * minf(1.0, float(shadow["mana"]) / float(need))
			# The macro-action across two bars: every setup card played (or
			# its amp already on the target) and the payoff held for the next
			# bar, within the amp's clock and the mana we will have.
			var setups_done := played == cards.size() - 1
			var target_set: bool = not shadow["setups"].is_empty() or (cards.size() == 1)
			if setups_done and target_set:
				var regen: float = state.main.player.get_stats().get_effective_mana_regen()
				var amp_ok := false
				for idx in shadow["enemies"]:
					var sh: Dictionary = shadow["enemies"][idx]
					if bool(sh["dead"]):
						continue
					var left: int = maxi(0, int(sh["vuln_tempo"]) - (budget - int(sh["vuln_at"])))
					var cl: int = maxi(0, int(sh["control"]) - (budget - int(sh["control_at"])))
					if maxi(left, cl) >= int(pay["tempo"]):
						amp_ok = true
				if amp_ok and float(shadow["mana"]) + regen >= float(need):
					var gain: float = maxf(payoff, float(WEIGHTS["vulnerable_amp"]) * float(pay["damage"]))
					v += float(WEIGHTS["next_bar_payoff"]) * gain
	return v
