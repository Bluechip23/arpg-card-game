extends RefCounted

## The one scenario every stored build runs through:
##   parts=character:ryan,build:bruiser[,level:50,deck:potions,alloc:str_det,sphere:none,passives:shadow,enemy:WYVERN]
## (tests/sim/builds/<character>_builds.gd holds the components; see
## docs/sim/README.md "Stored builds"). build() alone is Ryan's first
## designed build at level 18.

static func build() -> Dictionary:
	return CharacterBuilds.compose("ryan", {})

static func build_with(parts: Dictionary) -> Dictionary:
	var p := parts.duplicate()
	var character := str(p.get("character", "ryan"))
	p.erase("character")
	if p.has("level"):
		p["level"] = int(p["level"])
	return CharacterBuilds.compose(character, p)
