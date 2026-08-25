class_name PassiveCooldowns
extends RefCounted

## Read-only view of skill-tree passive cooldown state for HUD display.
## Mirrors how progression_triggers tracks each passive at runtime: some record
## the global tempo of their last trigger, some count remaining cooldown tempo
## down in 5-tempo steps, and the two charge pools only go on cooldown while
## empty. Passives absent from every table here have no cooldown at all.

# Fixed cooldown totals (tempo) for passives whose cooldown doesn't scale with
# rank; everything else reads PassiveScaling's "cooldown" table.
const _FIXED_TOTAL := {
	"eye_scrape": 10,
	"skilled_momentum": 5,
	"dominate": 5,
	"in_the_trenches": 10,
	"expel_negativity": 10,
}

# passive_id -> PlayerStats property holding the global tempo of the last trigger
const _LAST_TEMPO := {
	"enraged_will": "st_enraged_will_last_tempo",
	"eye_scrape": "st_eye_scrape_last_tempo",
	"skilled_momentum": "st_skilled_momentum_last_tempo",
	"lethal_resourcefulness": "st_lethal_last_tempo",
	"pop_rocks": "st_pop_rocks_last_tempo",
	"nimble_assault": "st_nimble_last_tempo",
	"now_you_see_me": "st_nysm_last_tempo",
	"wither": "st_wither_last_tempo",
	"territorial_death": "st_territorial_last_tempo",
	"arcane_overflow": "st_arcane_overflow_last_tempo",
	"fresh_start": "st_fresh_start_last_tempo",
}

# passive_id -> PlayerStats property counting remaining cooldown tempo down
const _REMAINING := {
	"regrowth": "st_regrowth_cooldown",
	"stimulant": "st_stimulant_cooldown",
	"dominate": "st_dominate_cooldown",
	"haunted_rebuke": "st_haunted_rebuke_cooldown",
	"whispers_of_the_flock": "st_whispers_cooldown",
}

# passive_id -> [charges property, last-exhausted-tempo property]
const _CHARGES := {
	"in_the_trenches": ["st_itt_charges", "st_itt_last_used_tempo"],
	"expel_negativity": ["st_expel_charges", "st_expel_last_used_tempo"],
}

static func has_cooldown(passive_id: String) -> bool:
	return _LAST_TEMPO.has(passive_id) or _REMAINING.has(passive_id) or _CHARGES.has(passive_id)

## Full recharge time in tempo at the passive's current rank.
static func total(passive_id: String, stats) -> int:
	if _FIXED_TOTAL.has(passive_id):
		return _FIXED_TOTAL[passive_id]
	return int(PassiveScaling.value(passive_id, "cooldown", stats.get_passive_level(passive_id)))

## Cooldown snapshot for the HUD: {has_cooldown, on_cooldown, elapsed, total}.
static func status(passive_id: String, stats, tempo_manager) -> Dictionary:
	var out := {"has_cooldown": has_cooldown(passive_id), "on_cooldown": false, "elapsed": 0, "total": 0}
	if not out.has_cooldown or stats == null:
		return out
	var cd_total := total(passive_id, stats)
	out.total = cd_total
	var now: int = tempo_manager.get_global_tempo() if tempo_manager else 0
	if _CHARGES.has(passive_id):
		# On cooldown only while the charge pool sits empty. The refresh is
		# lazy in progression_triggers, so elapsed >= total counts as ready
		# even before the charges variable is refilled.
		var charges: int = int(stats.get(_CHARGES[passive_id][0]))
		var elapsed: int = now - int(stats.get(_CHARGES[passive_id][1]))
		out.on_cooldown = charges <= 0 and elapsed < cd_total
		out.elapsed = clampi(elapsed, 0, cd_total)
	elif _REMAINING.has(passive_id):
		var remaining: int = int(stats.get(_REMAINING[passive_id]))
		out.on_cooldown = remaining > 0
		out.elapsed = clampi(cd_total - remaining, 0, cd_total)
	else:
		var elapsed: int = now - int(stats.get(_LAST_TEMPO[passive_id]))
		out.on_cooldown = elapsed < cd_total
		out.elapsed = clampi(elapsed, 0, cd_total)
	return out
