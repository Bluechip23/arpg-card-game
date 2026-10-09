extends SimPolicy

## Plays the scenario's `script` list verbatim. Each entry is an action
## Dictionary ({"type": "play", "card": "slash", "target": "enemy:0"} …);
## a card may be named by id or hand index. An illegal entry ends the run
## with outcome "error" (the runner checks legality). When the list runs
## out the character idles (wait) until the fight resolves.

var _index := 0

func _init() -> void:
	name = "scripted"

func setup(sc: Dictionary) -> void:
	super.setup(sc)
	_index = 0

func choose_action(state: SimState) -> Variant:
	var script: Array = scenario.get("script", [])
	if _index >= script.size():
		return {"type": "wait", "script_exhausted": true}
	var a: Dictionary = (script[_index] as Dictionary).duplicate(true)
	_index += 1
	# Name a card by id: resolve it to the first matching hand index.
	if a.get("type", "") == "play" and a.get("card") is String:
		var idx := state.hand_index_of(str(a["card"]))
		if idx < 0:
			a["illegal"] = "no '%s' in hand" % str(a["card"])
		else:
			a["card_id"] = str(a["card"])
			a["card"] = idx
	return a
