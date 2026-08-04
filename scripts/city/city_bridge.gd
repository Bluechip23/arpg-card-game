class_name CityBridge
extends RefCounted

## Bridges the city loop (CityState / ExpeditionSystem / CalamitySystem) into
## the running game. All city state rides inside the player_progression
## dictionary that main.gd and town.gd already hand between scenes and that
## ProgressionIO embeds in saves:
##   "city"          — CityState.to_dict(): banked resources, buildings, log
##   "city_satchel"  — resources gathered on the adventure, not yet sent home
##   "city_calamity" — the brewing calamity, if any (see CalamitySystem)
##
## The satchel is the "send resources home" half of the design: kills fill it
## out in the world, and arriving in town banks it into the city.

const CITY_KEYS := ["city", "city_satchel", "city_calamity"]

# ============================================
# CITY ACCESS
# ============================================

static func get_city(progression: Dictionary) -> CityState:
	return CityState.from_dict(progression.get("city", {}))

static func store_city(progression: Dictionary, city: CityState) -> void:
	progression["city"] = city.to_dict()

static func city_started(progression: Dictionary) -> bool:
	## The city "starts" the first time resources are banked in town.
	return not progression.get("city", {}).is_empty()

# ============================================
# THE SATCHEL (resources gathered on the adventure)
# ============================================

static func satchel(progression: Dictionary) -> Dictionary:
	return progression.get("city_satchel", {})

static func add_kill_to_satchel(progression: Dictionary, zone: String, elite: bool) -> Dictionary:
	## One kill's worth of habitat resources into the satchel. Elites/bosses
	## count triple (ExpeditionSystem). Returns what was gained, for logging.
	var city: CityState = null
	if city_started(progression):
		city = get_city(progression)  # Hero Hall bonus applies once the city stands
	var gained := ExpeditionSystem.rewards_for_kills(zone, 1, city, 1 if elite else 0)
	if gained.is_empty():
		return gained
	var pouch: Dictionary = progression.get("city_satchel", {})
	for res in gained:
		pouch[res] = int(pouch.get(res, 0)) + int(gained[res])
	progression["city_satchel"] = pouch
	return gained

static func bank_satchel(progression: Dictionary, now: int) -> Dictionary:
	## Arriving home: accrue building production, then empty the satchel into
	## the city stores (storage cap applies). Returns
	## {produced: {..}, banked: {..}, lost: {..}} for the town notice.
	var city := get_city(progression)
	var produced := city.collect_production(now)
	var pouch: Dictionary = progression.get("city_satchel", {})
	var banked := city.add_resources(pouch)
	var lost := {}
	for res in pouch:
		var missed: int = int(pouch[res]) - int(banked.get(res, 0))
		if missed > 0:
			lost[res] = missed  # storage was full
	progression["city_satchel"] = {}
	store_city(progression, city)
	return {"produced": produced, "banked": banked, "lost": lost}

# ============================================
# ZONES
# ============================================

static func zone_for_area(interior_kind: String, world_level: int) -> String:
	## Map where the player is fighting onto an ExpeditionSystem habitat.
	## Interiors have exact habitats; the overworld falls back to the act's
	## dominant habitat.
	match interior_kind:
		"sewer":
			return "Sewer"
		"forest":
			return "Forest"
		"cave":
			return "Cave"
	match world_level:
		1:
			return "Forest"
		2:
			return "Graveyard"
		3:
			return "Mountains"
		4:
			return "Underworld"
		_:
			return "Heavens"

# ============================================
# HELPERS
# ============================================

static func format_resources(amounts: Dictionary) -> String:
	## "+9 lumber  +3 gold" — for battle-log lines and town notices.
	var parts: Array[String] = []
	for res in CityState.RESOURCES:
		if amounts.has(res) and int(amounts[res]) != 0:
			parts.append("%+d %s" % [int(amounts[res]), res])
	return "  ".join(parts)

static func carry_keys(from: Dictionary, to: Dictionary) -> void:
	## Copy the city keys between progression dicts (used when a scene builds
	## a fresh progression snapshot).
	for key in CITY_KEYS:
		if from.has(key):
			to[key] = from[key]
