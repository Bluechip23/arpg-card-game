class_name SimScenario
extends RefCounted

## Scenario helpers for the combat simulation harness (docs/sim/README.md).
## A scenario is a .gd file under tests/sim/scenarios/ exposing
## `static func build() -> Dictionary`; this class loads, fills in defaults
## and validates one.

const TUTORIAL_IDS_SEEN := ["combat_intro", "field_tour", "item_levels_intro",
	"doughnut_keep", "first_climbable_tree", "trial_strike"]

static func starter_deck() -> Array:
	## The deck every character starts with (single source: DeckManager).
	return DeckManager.BASIC_DECK_IDS.duplicate()

static func load_file(path: String) -> Dictionary:
	var script = load(path)
	if script == null:
		push_error("[SIM] cannot load scenario %s" % path)
		return {}
	var sc: Dictionary = script.build()
	if not sc.has("name"):
		sc["name"] = path.get_file().get_basename()
	return with_defaults(sc)

static func with_defaults(sc: Dictionary) -> Dictionary:
	var out := sc.duplicate(true)
	out["seed"] = int(out.get("seed", 1))
	out["max_bars"] = int(out.get("max_bars", 40))
	out["tempo_threshold"] = int(out.get("tempo_threshold", 5))
	out["policy"] = str(out.get("policy", "greedy_dpt"))
	out["script"] = out.get("script", [])
	var p: Dictionary = out.get("player", {})
	p["character"] = str(p.get("character", "brad"))
	p["level"] = int(p.get("level", 1))
	p["allocation"] = p.get("allocation", {})
	p["passives"] = p.get("passives", [])
	p["items"] = p.get("items", [])
	p["deck"] = p.get("deck", starter_deck())
	p["cell"] = p.get("cell", [6, 7])
	p["stat_overrides"] = p.get("stat_overrides", {})
	out["player"] = p
	var m: Dictionary = out.get("map", {})
	m["interior"] = str(m.get("interior", "dojo"))
	m["obstacles"] = m.get("obstacles", [])
	out["map"] = m
	var es: Array = out.get("enemies", [])
	for i in range(es.size()):
		var e: Dictionary = es[i]
		e["overrides"] = e.get("overrides", {})
		es[i] = e
	out["enemies"] = es
	return out

static func validate(sc: Dictionary) -> String:
	## "" when the scenario is sound, else the first problem found.
	var p: Dictionary = sc["player"]
	if not script_has(CharacterData, "create_%s" % p["character"]):
		return "unknown character '%s'" % p["character"]
	for entry in p["items"]:
		var id: String = str(entry[0] if entry is Array else entry)
		if not script_has(ItemData, "create_%s" % id):
			return "unknown item '%s'" % id
	for e in sc["enemies"]:
		if not Enemy.EnemyType.has(str(e.get("type", ""))):
			return "unknown enemy type '%s'" % str(e.get("type", ""))
		if not (e.has("cell") and e["cell"] is Array and e["cell"].size() == 2):
			return "enemy '%s' needs a [x, y] cell" % str(e.get("type", ""))
	if sc["max_bars"] <= 0:
		return "max_bars must be positive"
	return ""

## Does the script define a (static) function of that name? Object.has_method
## on a Script resource looks at the resource class, not the script's own code.
static func script_has(script: Script, method: String) -> bool:
	for m in script.get_script_method_list():
		if m["name"] == method:
			return true
	return false

static func cell_of(v) -> Vector2i:
	if v is Vector2i:
		return v
	return Vector2i(int(v[0]), int(v[1]))
