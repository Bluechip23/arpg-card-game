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
	p["opening_hand"] = p.get("opening_hand", [])
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

## Sweep-job overrides on top of a scenario file (tools/sim_analysis/gen_sweeps.py
## writes these): enemy=TYPE[,TYPE] (replaces the enemies; placed at a
## sensible range by the runner), add_cards=a,b, add_items=x[:slot],y,
## items=x[:slot],y|none (replaces the loadout), level=N,
## alloc=strength:10,dexterity:5 (replaces the allocation),
## passives=a,b, hand=a,b (those cards start in hand), character=name, name=suffix (output folder becomes
## <scenario>_<suffix>). Every key is optional.
static func apply_overrides(sc: Dictionary, job: Dictionary) -> Dictionary:
	var out := sc.duplicate(true)
	var p: Dictionary = out["player"]
	if job.has("enemy"):
		var es: Array = []
		var i := 0
		for t in str(job["enemy"]).split(",", false):
			var base := cell_of(p["cell"])
			es.append({"type": t.strip_edges(), "cell": [base.x + 3, base.y + i], "overrides": {}})
			i += 1
		out["enemies"] = es
		out["auto_range"] = true
	if job.has("add_cards"):
		for id in str(job["add_cards"]).split(",", false):
			p["deck"].append(id.strip_edges())
	if job.has("hand"):
		# Spotlight: these cards start in the opening hand (a one-card change
		# to an 11-card deck is otherwise invisible until it is drawn).
		var hs: Array = []
		for id in str(job["hand"]).split(",", false):
			hs.append(id.strip_edges())
		p["opening_hand"] = hs
	if job.has("items"):
		# Replace the loadout outright (a weapon sweep swaps the baseline sword).
		var its: Array = []
		for spec in str(job["items"]).split(",", false):
			var parts := spec.strip_edges().split(":")
			if parts[0] != "none":
				its.append([parts[0], int(parts[1]) if parts.size() > 1 else 0])
		p["items"] = its
	if job.has("add_items"):
		for spec in str(job["add_items"]).split(",", false):
			var parts := spec.strip_edges().split(":")
			p["items"].append([parts[0], int(parts[1]) if parts.size() > 1 else 0])
	if job.has("level"):
		p["level"] = int(job["level"])
	if job.has("alloc"):
		var alloc := {}
		for kv in str(job["alloc"]).split(",", false):
			var parts := kv.strip_edges().split(":")
			if parts.size() == 2:
				alloc[parts[0]] = int(parts[1])
		p["allocation"] = alloc
	if job.has("passives"):
		var ps: Array = []
		for id in str(job["passives"]).split(",", false):
			ps.append(id.strip_edges())
		p["passives"] = ps
	if job.has("character"):
		p["character"] = str(job["character"])
	if job.has("name"):
		out["name"] = "%s_%s" % [out["name"], str(job["name"])]
	out["player"] = p
	return out

static func cell_of(v) -> Vector2i:
	if v is Vector2i:
		return v
	return Vector2i(int(v[0]), int(v[1]))
