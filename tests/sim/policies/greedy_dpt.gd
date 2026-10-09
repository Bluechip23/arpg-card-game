extends SimPolicy

## The meat-bag detector: if an attack is legal, play the one with the
## highest expected damage per tempo against the nearest enemy; otherwise
## move toward the nearest enemy; otherwise wait. Never buffs, debuffs,
## stuns or positions on purpose. The auto attack counts as an attack.

func _init() -> void:
	name = "greedy_dpt"

func choose_action(state: SimState) -> Variant:
	var legal := state.legal_actions()
	var nearest := state.nearest_enemy_index()
	var best: Dictionary = {}
	var best_dpt := -1.0
	for a in legal:
		var target: String = str(a.get("target", ""))
		if nearest >= 0 and target != "enemy:%d" % nearest:
			continue
		var dmg := 0
		var tempo := 1
		if a["type"] == "play":
			var c: Dictionary = state.hand[a["card"]]
			if not c["is_attack"] and not (c["is_offensive"] and c["damage"] > 0):
				continue
			dmg = int(a.get("expected_damage", c["damage"]))
			tempo = maxi(1, int(c["tempo"]))
		elif a["type"] == "attack":
			dmg = int(a.get("expected_damage", 0))
			tempo = maxi(1, int(a.get("tempo", 5)))
		else:
			continue
		if dmg <= 0:
			continue
		var dpt := float(dmg) / float(tempo)
		if dpt > best_dpt:
			best_dpt = dpt
			best = a
	if not best.is_empty():
		return best
	# No attack reaches: close the distance.
	if nearest >= 0:
		var step := state.step_toward(nearest)
		if not step.is_empty():
			return step
	return {"type": "wait"}
