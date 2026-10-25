class_name ArtStyle
extends RefCounted

## Which look the figures cut from the designer's own art wear (designer,
## 2026-10-25): SMOOTH — the art itself, soft-filtered at SMOOTH_DENSITY
## texels a tile (assets/sprites/generated/smooth/, tools/smooth_art.py) —
## or, with SMOOTH false, the pixelated sheets (assets/sprites/generated/
## sheets, bosses, heroes), which are kept on hand until the designer says
## to delete them. Pack art (tiles, props, the downloaded enemies) is pixel
## art at 32 a tile either way.

const SMOOTH := true
const SMOOTH_DENSITY := 128.0
const GENERATED := "res://assets/sprites/generated/"
const SMOOTH_ROOT := "res://assets/sprites/generated/smooth/"


## The smooth twin of a sheet folder (…/generated/sheets/<kind>,
## …/generated/bosses/<kind>) when the smooth look is on and it has been
## cut; "" otherwise.
static func smooth_folder(folder: String) -> String:
	if not SMOOTH or not folder.begins_with(GENERATED):
		return ""
	var s := SMOOTH_ROOT + folder.trim_prefix(GENERATED)
	return s if ResourceLoader.exists(s + "/Idle.png") else ""


## The smooth twin of a hero sheet (…/generated/heroes/<hero>.png), or "".
static func smooth_file(path: String) -> String:
	if not SMOOTH or not path.begins_with(GENERATED):
		return ""
	var s := SMOOTH_ROOT + path.trim_prefix(GENERATED)
	return s if ResourceLoader.exists(s) else ""
