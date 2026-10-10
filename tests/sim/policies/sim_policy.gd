class_name SimPolicy
extends RefCounted

## Base class for player policies (docs/sim/README.md, "Adding a policy").
## A policy sees a SimState — exactly what a human sees, rolled card outcomes
## included — and returns one action Dictionary from state.legal_actions(),
## or null to stop the run ("error" outcome). It may also answer the prompts
## the game raises while a card resolves.

var name := "base"
var scenario: Dictionary = {}

func setup(sc: Dictionary) -> void:
	scenario = sc

func choose_action(_state: SimState) -> Variant:
	return null

## Resolve-time prompts. `kind` is one of: "maintain" (Peshtigo-style keep
## the power up?), "picker" (a card / choice picker with `options` labels),
## "defensive_sacrifice", "life_swap" (options are enemy labels),
## "point_to_prove", "donation". Return the index of the option to take;
## -1 declines / cancels.
## "invisibility_draw" (options: draw the named top card / leave it) and
## "invisibility_discard" (options: the hand cards' names) come with the
## current state so a policy can weigh the hand; the base policy draws and
## discards the first card offered.
func answer_prompt(kind: String, options: Array, state: SimState = null) -> int:
	match kind:
		"maintain": return 0
		"donation": return -1
		_: return 0 if options.size() > 0 else -1

static func action_label(a: Dictionary) -> String:
	match str(a.get("type", "")):
		"play": return "play:%s" % str(a.get("card_id", a.get("card", "")))
		"attack": return "attack"
		"block": return "block"
		"wait": return "wait"
		"move": return ("flash_move:%s" if a.get("flash", false) else "move:%s") % str(a.get("cell", ""))
	return str(a.get("type", "?"))
