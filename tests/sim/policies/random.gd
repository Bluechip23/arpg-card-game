extends SimPolicy

## Uniform over the legal actions. The floor of the distribution.

func _init() -> void:
	name = "random"

func choose_action(state: SimState) -> Variant:
	var legal := state.legal_actions()
	if legal.is_empty():
		return {"type": "wait"}
	return legal[randi() % legal.size()]
