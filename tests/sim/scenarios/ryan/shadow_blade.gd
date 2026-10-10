extends RefCounted

## Ryan — the designed "shadow_blade" build (tests/sim/builds/ryan_builds.gd).
## `build_with(parts)` swaps any component: items, deck, alloc, sphere,
## passives, slotted, level, enemy.

static func build() -> Dictionary:
	return CharacterBuilds.compose("ryan", {"build": "shadow_blade"})

static func build_with(parts: Dictionary) -> Dictionary:
	var p := parts.duplicate()
	p["build"] = "shadow_blade"
	if p.has("level"):
		p["level"] = int(p["level"])
	return CharacterBuilds.compose("ryan", p)
