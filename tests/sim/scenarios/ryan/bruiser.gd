extends RefCounted

## Ryan — the designed "bruiser" build (tests/sim/scenarios/ryan/ryan_builds.gd).
## `build_with(parts)` swaps any component: items, deck, alloc, sphere,
## passives, slotted, enemy.

static func build() -> Dictionary:
	return RyanBuilds.compose({"build": "bruiser"})

static func build_with(parts: Dictionary) -> Dictionary:
	var p := parts.duplicate()
	p["build"] = "bruiser"
	return RyanBuilds.compose(p)
