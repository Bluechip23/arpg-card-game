extends RefCounted

## Ryan — the designed "ranged_ambusher" build (tests/sim/scenarios/ryan/ryan_builds.gd).
## `build_with(parts)` swaps any component: items, deck, alloc, sphere,
## passives, slotted, enemy.

static func build() -> Dictionary:
	return RyanBuilds.compose({"build": "ranged_ambusher"})

static func build_with(parts: Dictionary) -> Dictionary:
	var p := parts.duplicate()
	p["build"] = "ranged_ambusher"
	return RyanBuilds.compose(p)
