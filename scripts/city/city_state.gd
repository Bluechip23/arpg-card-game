class_name CityState
extends RefCounted

## The player's city — the data heart of the city end-game loop.
##
## Loop: heroes go on EXPEDITIONS (kill monsters, gather resources) → spend
## resources UPGRADING buildings → city power & production grow → RAID rival
## cities for loot (and defend your own) → repeat. See docs/STORY.md §6.5.
##
## This class is pure data + rules (no UI, no nodes): resources, building
## levels, lazily-accrued production, storage caps, power score, and
## save/load. Building *placement* is a later, purely-visual pass.

# ---- Resources ----
const RESOURCES := ["gold", "lumber", "stone", "essence"]

var resources := {"gold": 0, "lumber": 0, "stone": 0, "essence": 0}

# ---- Buildings ----
## Data-only registry. Each entry:
##  cost: base upgrade cost (scales by level)
##  production: resources generated per hour at level 1 (scales linearly)
##  defense / storage / attack: flat contribution per level
const BUILDING_DEFS := {
	"town_hall": {
		"name": "Town Hall",
		"desc": "The heart of the city. Its level caps every other building's level.",
		"max_level": 10,
		"cost": {"gold": 100, "lumber": 50, "stone": 50},
	},
	"lumber_mill": {
		"name": "Lumber Mill",
		"desc": "Produces lumber over time.",
		"max_level": 10,
		"cost": {"gold": 40, "stone": 20},
		"production": {"lumber": 20},
	},
	"quarry": {
		"name": "Quarry",
		"desc": "Produces stone over time.",
		"max_level": 10,
		"cost": {"gold": 40, "lumber": 20},
		"production": {"stone": 20},
	},
	"essence_extractor": {
		"name": "Essence Extractor",
		"desc": "Distills arcane essence over time. Essence fuels hero-side upgrades.",
		"max_level": 10,
		"cost": {"gold": 80, "lumber": 30, "stone": 30},
		"production": {"essence": 5},
	},
	"warehouse": {
		"name": "Warehouse",
		"desc": "Raises how much of each resource the city can store.",
		"max_level": 10,
		"cost": {"lumber": 60, "stone": 60},
		"storage": 500,
	},
	"vault": {
		"name": "Vault",
		"desc": "Protects a share of your resources from being looted in raids.",
		"max_level": 10,
		"cost": {"gold": 120, "stone": 80},
		"protection": 0.06,  # +6% of stored resources protected per level
	},
	"barracks": {
		"name": "Barracks",
		"desc": "Houses the garrison. Adds defense, and strengthens your raids.",
		"max_level": 10,
		"cost": {"gold": 60, "lumber": 40},
		"defense": 12,
		"attack": 8,
	},
	"walls": {
		"name": "Walls",
		"desc": "The city's shell. Pure defense.",
		"max_level": 10,
		"cost": {"stone": 100},
		"defense": 20,
	},
	"hero_hall": {
		"name": "Hero Hall",
		"desc": "Honors your heroes. Boosts expedition yields and raid attack.",
		"max_level": 10,
		"cost": {"gold": 100, "essence": 10},
		"attack": 12,
		"expedition_bonus": 0.10,  # +10% expedition yield per level
	},
}

## building id -> level (0 = not built)
var buildings := {}

# ---- Storage / production ----
const BASE_STORAGE := 1000
const PRODUCTION_CAP_HOURS := 8.0  # offline accrual stops after this long

## Unix time of the last production accrual (injectable for tests).
var last_collect_time: int = 0

# ---- Raid defense log ----
## Most recent first: {time, attacker, won, loot: {res: amt}}
var defense_log: Array = []
const DEFENSE_LOG_MAX := 20

func _init() -> void:
	buildings = {"town_hall": 1}
	for id in BUILDING_DEFS:
		if not buildings.has(id):
			buildings[id] = 0

# ============================================
# RESOURCES
# ============================================

func get_storage_cap() -> int:
	return BASE_STORAGE + buildings.get("warehouse", 0) * int(BUILDING_DEFS["warehouse"]["storage"])

func add_resources(amounts: Dictionary) -> Dictionary:
	## Adds resources, clamped to the storage cap. Returns what was actually added.
	var cap := get_storage_cap()
	var added := {}
	for res in amounts:
		if res not in RESOURCES:
			continue
		var before: int = resources.get(res, 0)
		var after: int = clampi(before + int(amounts[res]), 0, cap)
		resources[res] = after
		added[res] = after - before
	return added

func can_afford(cost: Dictionary) -> bool:
	for res in cost:
		if resources.get(res, 0) < int(cost[res]):
			return false
	return true

func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for res in cost:
		resources[res] -= int(cost[res])
	return true

# ============================================
# PRODUCTION (lazy accrual — no timers needed)
# ============================================

func get_production_per_hour() -> Dictionary:
	## Total production across buildings; scales linearly with level.
	var out := {}
	for id in buildings:
		var lvl: int = buildings[id]
		if lvl <= 0:
			continue
		var prod: Dictionary = BUILDING_DEFS[id].get("production", {})
		for res in prod:
			out[res] = out.get(res, 0) + int(prod[res]) * lvl
	return out

func collect_production(now: int) -> Dictionary:
	## Accrue production since last_collect_time (capped at PRODUCTION_CAP_HOURS)
	## into storage. Returns what was gained. Call on city open / save load.
	if last_collect_time <= 0:
		last_collect_time = now
		return {}
	var hours: float = minf((now - last_collect_time) / 3600.0, PRODUCTION_CAP_HOURS)
	last_collect_time = now
	if hours <= 0.0:
		return {}
	var rates := get_production_per_hour()
	var gain := {}
	for res in rates:
		gain[res] = int(rates[res] * hours)
	return add_resources(gain)

# ============================================
# BUILDINGS
# ============================================

func get_building_level(id: String) -> int:
	return buildings.get(id, 0)

func get_upgrade_cost(id: String) -> Dictionary:
	## Cost to go from the current level to the next: base cost × (level + 1).
	if not BUILDING_DEFS.has(id):
		return {}
	var next_mult: int = buildings.get(id, 0) + 1
	var out := {}
	for res in BUILDING_DEFS[id]["cost"]:
		out[res] = int(BUILDING_DEFS[id]["cost"][res]) * next_mult
	return out

func can_upgrade(id: String) -> bool:
	if not BUILDING_DEFS.has(id):
		return false
	var lvl: int = buildings.get(id, 0)
	if lvl >= int(BUILDING_DEFS[id]["max_level"]):
		return false
	# Town Hall gates everything else (classic city-builder pacing).
	if id != "town_hall" and lvl >= buildings.get("town_hall", 1):
		return false
	return can_afford(get_upgrade_cost(id))

func upgrade(id: String) -> bool:
	if not can_upgrade(id):
		return false
	spend(get_upgrade_cost(id))
	buildings[id] = buildings.get(id, 0) + 1
	return true

# ============================================
# DERIVED SCORES
# ============================================

func get_defense_power() -> int:
	var total := 0
	for id in buildings:
		total += buildings[id] * int(BUILDING_DEFS[id].get("defense", 0))
	return total

func get_attack_power() -> int:
	var total := 0
	for id in buildings:
		total += buildings[id] * int(BUILDING_DEFS[id].get("attack", 0))
	return total

func get_expedition_bonus() -> float:
	## Multiplier applied to expedition yields (1.0 = no bonus).
	var bonus := 0.0
	for id in buildings:
		bonus += buildings[id] * float(BUILDING_DEFS[id].get("expedition_bonus", 0.0))
	return 1.0 + bonus

func get_protected_fraction() -> float:
	## Fraction of each resource a raider can never touch.
	return clampf(buildings.get("vault", 0) * float(BUILDING_DEFS["vault"]["protection"]), 0.0, 0.9)

func get_power() -> int:
	## One number that summarizes the city — used for raid matchmaking.
	var total := 0
	for id in buildings:
		total += buildings[id] * 10
	return total + get_defense_power() + get_attack_power()

# ============================================
# DEFENSE LOG
# ============================================

func record_defense(entry: Dictionary) -> void:
	defense_log.push_front(entry)
	if defense_log.size() > DEFENSE_LOG_MAX:
		defense_log.resize(DEFENSE_LOG_MAX)

# ============================================
# PERSISTENCE
# ============================================

func to_dict() -> Dictionary:
	return {
		"resources": resources.duplicate(),
		"buildings": buildings.duplicate(),
		"last_collect_time": last_collect_time,
		"defense_log": defense_log.duplicate(true),
	}

static func from_dict(data: Dictionary) -> CityState:
	var city := CityState.new()
	if data.is_empty():
		return city
	for res in city.resources:
		city.resources[res] = int(data.get("resources", {}).get(res, 0))
	var b: Dictionary = data.get("buildings", {})
	for id in city.buildings:
		city.buildings[id] = int(b.get(id, city.buildings[id]))
	city.last_collect_time = int(data.get("last_collect_time", 0))
	city.defense_log = data.get("defense_log", []).duplicate(true)
	return city
