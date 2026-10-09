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

const HORIZON := 10          # tempo of future threat a kill removes
const LOW_HP := 0.4          # below this fraction, HP preserved counts double
const MANA_WEIGHT := 0.02    # tiny tie-breaker: cheaper of two equal plays
const CONTROL_WORDS := {     # card text -> (what it does, how long by default)
	"stun": 5, "stuns": 5, "stunned": 5, "freeze": 5, "frozen": 5, "root": 5, "rooted": 5,
	"trip": 3, "tripped": 3, "disarm": 5, "disarmed": 5, "silence": 5, "silenced": 5,
}
const AMP_WORDS := ["vulnerable", "weaken", "weakened", "expose", "exposed"]
const MOVE_ACTION_WORDS := ["move", "scurry", "range", "retreat", "heal", "regen", "flee", "wander"]

func _init() -> void:
	name = "lookahead"

func choose_action(state: SimState) -> Variant:
	var legal := state.legal_actions()
	if legal.is_empty():
		return {"type": "wait"}
	var threats := _threats(state)
	var best: Dictionary = {}
	var best_score := -INF
	for a in legal:
		var s := _score(a, state, threats)
		if s > best_score:
			best_score = s
			best = a
	return best

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
		out.append({
			"index": e["index"],
			"fires_in": maxi(1, cost - counter),
			"cost": cost,
			"is_hit": is_hit,
			"damage": int(e["attack_damage"]),
			"in_reach": e["distance"] <= maxi(1, int(e["attack_range"])),
			"distance": e["distance"],
			"reach": maxi(1, int(e["attack_range"])),
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
			else:
				gain += _self_value(c, text, state, threats, tempo, hp_weight)
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
	# What standing (or acting) here costs: the hits that land while committed.
	var incoming := _incoming(threats, tempo, killed_index)
	var loss := float(incoming) * hp_weight
	if incoming >= state.player_hp + state.player_armor:
		loss += 1000.0   # lethal: anything else first
	var score := (gain - loss) / float(tempo) - mana * MANA_WEIGHT
	# A free action (0 tempo, 0 mana) costs nothing to take first.
	if kind == "play" and int(state.hand[a["card"]]["tempo"]) == 0 and mana == 0 and gain >= 0.0:
		score += 0.5
	return score

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

## Block, heal, buffs: what a self-targeted card is worth right now.
static func _self_value(c: Dictionary, text: String, state: SimState, threats: Array, tempo: int, hp_weight: float) -> float:
	var v := 0.0
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
	if text.find("draw") >= 0 and state.hand.size() <= 2:
		v += 2.0   # a card in hand is worth a little when the hand is thin
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
	if not t.is_empty() and t["is_hit"] and t["in_reach"] and t["fires_in"] <= 1 and d_after > int(t["reach"]):
		return float(t["damage"]) * hp_weight + 0.5
	var can_hit_now := false
	for h in state.hand:
		if h["playable"] and h["damage"] > 0:
			can_hit_now = can_hit_now or state.main._is_target_in_card_range(state.main.deck_manager.hand[h["index"]], e["node"])
	if d_now <= state.basic_attack_reach:
		can_hit_now = true
	if not can_hit_now and d_after < d_now:
		return 1.0   # closing in is progress
	return -0.5      # otherwise a move is a tempo spent on nothing
