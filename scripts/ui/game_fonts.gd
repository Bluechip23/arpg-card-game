class_name GameFonts
extends RefCounted

## The game's display fonts, loaded once and shared.
##
## Courgette (Karolina Lach, SIL Open Font License 1.1 — see
## assets/fonts/OFL.txt) is the title and menu face: the "Trials of Olorin"
## title, menu options, and speaker names in dialogue.

const COURGETTE_PATH := "res://assets/fonts/Courgette-Regular.ttf"

static var _courgette: Font = null

static func courgette() -> Font:
	if _courgette == null:
		_courgette = load(COURGETTE_PATH) as Font
		if _courgette == null:
			_courgette = ThemeDB.fallback_font
	return _courgette
