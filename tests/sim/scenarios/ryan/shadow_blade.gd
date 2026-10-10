extends RefCounted

## Ryan — the designed "shadow_blade" build (tests/sim/scenarios/ryan/ryan_builds.gd).
## `build_with(parts)` swaps any component: items, deck, alloc, sphere,
## passives, slotted, enemy.

static func build() -> Dictionary:
	return RyanBuilds.compose({"build": "shadow_blade"})

static func build_with(parts: Dictionary) -> Dictionary:
	var p := parts.duplicate()
	p["build"] = "shadow_blade"
	return RyanBuilds.compose(p)
