class_name OverflowEffect
extends RefCounted

## Represents an overflow effect applied to the player

enum OverflowType {
	JAILED,
	MANIFEST,
	ENHANCE,
	SKIP,
	PEAK,
	OVERCHARGE,
	QUIVER
}

var overflow_type: OverflowType
var effect_name: String = ""          # e.g., "Skeleton", "Mushroom", "+2 Mana"
var effect_value: int = 0             # Value for the effect
var charges: int = -1                 # -1 = permanent, >0 = temporary
var source_name: String = ""          # What applied this (item, card, enemy)
var is_permanent: bool = false        # From equipment
var application_order: int = 0        # For priority between Manifest/Enhance

# For manifest - defines what clicking does
var manifest_effect_id: String = ""   # "summon_skeleton", "use_mushroom", etc.
var manifest_description: String = ""
var manifest_mana_cost: int = 0
var manifest_tempo_cost: int = 1

# For overcharge - defines what triggers
var overcharge_effect_id: String = "" # "gain_health", "gain_mana", etc.

func _init(type: OverflowType, name: String = "", val: int = 0, dur: int = -1) -> void:
	overflow_type = type
	effect_name = name
	effect_value = val
	charges = dur
	is_permanent = (dur == -1)

func use_charge() -> bool:
	# Returns true if effect should be removed (charges depleted)
	if is_permanent:
		return false
	
	charges -= 1
	print("[OVERFLOW] %s charges remaining: %d" % [effect_name, charges])
	return charges <= 0

func get_type_name() -> String:
	match overflow_type:
		OverflowType.JAILED: return "Jailed"
		OverflowType.MANIFEST: return "Manifest"
		OverflowType.ENHANCE: return "Enhance"
		OverflowType.SKIP: return "Skip"
		OverflowType.PEAK: return "Peak"
		OverflowType.OVERCHARGE: return "Overcharge"
		OverflowType.QUIVER: return "Quiver"
	return "Unknown"

func get_display_text() -> String:
	var charge_text = "∞" if is_permanent else str(charges)
	
	match overflow_type:
		OverflowType.JAILED:
			return "Jailed (%s)" % charge_text
		OverflowType.MANIFEST:
			return "Manifest: %s (%s)" % [effect_name, charge_text]
		OverflowType.ENHANCE:
			return "Enhance +%d (%s)" % [effect_value, charge_text]
		OverflowType.SKIP:
			return "Skip (%s)" % charge_text
		OverflowType.PEAK:
			return "Peak (%s)" % charge_text
		OverflowType.OVERCHARGE:
			return "Overcharge: %s (%s)" % [effect_name, charge_text]
		OverflowType.QUIVER:
			return "Bottomless Quiver (%s)" % charge_text

	return "Unknown"

# ============================================
# FACTORY METHODS
# ============================================

static func create_manifest(manifest_name: String, manifest_id: String, charges: int = -1, source: String = "") -> OverflowEffect:
	var effect = OverflowEffect.new(OverflowType.MANIFEST, manifest_name, 0, charges)
	effect.manifest_effect_id = manifest_id
	effect.manifest_description = manifest_name
	effect.source_name = source
	return effect

static func create_manifest_shuriken(charges: int = 3, source: String = "") -> OverflowEffect:
	var effect = create_manifest("Shuriken", "shuriken", charges, source)
	effect.manifest_description = "Deal 3 damage to a random enemy (free, ranged, counts as attack)"
	effect.manifest_mana_cost = 0
	effect.manifest_tempo_cost = 0
	effect.effect_value = 3
	return effect

static func create_overcharge(effect_name: String, effect_id: String, value: int, charges: int = -1, source: String = "") -> OverflowEffect:
	var effect = OverflowEffect.new(OverflowType.OVERCHARGE, effect_name, value, charges)
	effect.overcharge_effect_id = effect_id
	effect.source_name = source
	return effect

static func create_quiver(charges: int = 5, source: String = "") -> OverflowEffect:
	var effect = OverflowEffect.new(OverflowType.QUIVER, "Bottomless Quiver", 0, charges)
	effect.source_name = source
	return effect
