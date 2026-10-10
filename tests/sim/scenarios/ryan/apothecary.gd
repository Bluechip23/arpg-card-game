extends RefCounted

## Ryan — the designed "apothecary" build (tests/sim/scenarios/ryan/ryan_builds.gd).
## `build_with(parts)` swaps any component: items, deck, alloc, sphere,
## passives, slotted, enemy.

static func build() -> Dictionary:
	return RyanBuilds.compose({"build": "apothecary"})

static func build_with(parts: Dictionary) -> Dictionary:
	var p := parts.duplicate()
	p["build"] = "apothecary"
	return RyanBuilds.compose(p)
