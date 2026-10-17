class_name HealableSummon
extends Summon

## A summon that heal effects can reach. The bull worm is the one summon
## without this: callers test has_method("heal") to decide who a heal may
## land on, so the method lives here rather than on Summon.

func heal(amount: int) -> void:
	if PlayerStats.heal_to_damage and amount > 0:
		take_damage(amount)  # Poisoned Blood: the heal lands as damage
		return
	if is_dead or amount <= 0:
		return
	health = min(max_health, health + amount)
	_update_health_label()
