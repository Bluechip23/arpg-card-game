class_name PilePassiveIcon
extends Control

## A small item icon beside the Draw pile for the two character passives
## that run on a clock the player could not otherwise see:
##   Cory  — gauntlet mana: +10 mana when an active gauntlet skill comes off
##           cooldown (Inventory.gauntlet_cooldown_mana).
##   Jeremy — ring double: every RING_DOUBLE_TRIGGER_CYCLES-th cycle the first
##           ring trigger fires twice (Inventory.ring_double_trigger).
## The icon is the pack's slot icon (gauntlets / ring) cut into three bands
## that light up bottom-first as the clock runs. While the clock runs the
## unlit bands are faded; when the passive is ready every band is solid and a
## gold rim marks it; with no gauntlet / ring equipped the whole icon is
## nearly invisible. The state readers are static so tests can drive them
## without a scene.

# As tall as the Draw pile button (HUD_FACES["draw"] is 71x55) so the clock
# reads at a glance (designer, 2026-11-03).
const SIZE := 55.0
const BANDS := 3
const GAP := 1.0
const TEX_GAUNTLET := preload("res://assets/textures/ui_icons/slot_gauntlets.png")
const TEX_RING := preload("res://assets/textures/ui_icons/slot_ring.png")
const COL_LIT := Color(1, 1, 1, 1)
# Unlit bands and the unequipped icon stay clearly visible, only dimmed —
# the faded stage must never read as missing (designer, 2026-11-03).
const COL_UNLIT := Color(0.62, 0.62, 0.68, 0.8)
const ALPHA_UNEQUIPPED := 0.8
const TRIM := Color(0.85, 0.7, 0.35)  # gold, same as the passive tray boxes

var kind: String = ""          # "gauntlet", "ring" or "" (nothing to show)
var _state: Dictionary = {}    # last computed state (see gauntlet_state / ring_state)

func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_PASS

## Which clock an inventory carries. Questionnaire characters borrow one of
## the five characters' passives, so the flags decide, never the name.
static func kind_for(inv) -> String:
	if inv == null:
		return ""
	if inv.gauntlet_cooldown_mana:
		return "gauntlet"
	if inv.ring_double_trigger:
		return "ring"
	return ""

## Cory: the clock is the soonest active gauntlet skill's recharge, read the
## same way the skill circles read it (cycles x threshold, with the tempo
## already spent inside the current cycle counting toward it).
## Returns {equipped, on_cooldown, lit, ready, tip}.
static func gauntlet_state(inv, tm) -> Dictionary:
	var threshold: int = tm.tempo_threshold if tm else 5
	var in_cycle: int = tm.current_tempo if tm else 0
	var any_active := false
	var best = null
	var best_remaining := 0
	var best_total := 0
	for g in inv.equipped_gauntlets:
		if g == null or g.gauntlet_skill_type != ItemData.GauntletSkillType.ACTIVE:
			continue
		any_active = true
		if g.current_cooldown <= 0:
			continue
		var total: int = g.gauntlet_skill_cooldown * threshold
		var remaining: int = maxi(0, g.current_cooldown * threshold - in_cycle)
		if best == null or remaining < best_remaining:
			best = g
			best_remaining = remaining
			best_total = total
	if not any_active:
		return {"equipped": false, "on_cooldown": false, "lit": 0, "ready": false,
			"tip": "No gauntlet with an active skill is equipped — nothing to count down."}
	if best == null:
		return {"equipped": true, "on_cooldown": false, "lit": BANDS, "ready": true,
			"tip": "Skill ready. Use a gauntlet skill to start the next count."}
	var elapsed: int = best_total - best_remaining
	var lit: int = clampi(int(floor(float(elapsed) * BANDS / float(maxi(1, best_total)))), 0, BANDS - 1)
	return {"equipped": true, "on_cooldown": true, "lit": lit, "ready": false,
		"tip": "%s comes off cooldown in %d tempo (%d/%d) — +10 mana then." % [
			best.gauntlet_skill_name, best_remaining, elapsed, best_total]}

## Jeremy: the clock is the cycle count toward the next armed cycle. Armed
## and unspent is ready; armed but already spent this cycle is on cooldown
## with nothing lit (the count restarts next cycle).
static func ring_state(inv) -> Dictionary:
	var any_ring := false
	for r in inv.equipped_rings:
		if r != null:
			any_ring = true
			break
	if not any_ring:
		return {"equipped": false, "on_cooldown": false, "lit": 0, "ready": false,
			"tip": "No ring is equipped — nothing to double."}
	var period: int = inv.RING_DOUBLE_TRIGGER_CYCLES
	if inv.is_ring_double_trigger_armed():
		if inv.ring_triggered_this_turn:
			return {"equipped": true, "on_cooldown": true, "lit": 0, "ready": false,
				"tip": "Doubled a ring this cycle. The count starts again next cycle (%d cycles)." % period}
		return {"equipped": true, "on_cooldown": false, "lit": BANDS, "ready": true,
			"tip": "Armed: the first ring trigger this cycle fires twice."}
	var into: int = inv.ring_cycle_count % period
	var lit: int = clampi(int(floor(float(into) * BANDS / float(maxi(1, period)))), 0, BANDS - 1)
	var to_go: int = period - into
	return {"equipped": true, "on_cooldown": true, "lit": lit, "ready": false,
		"tip": "%d cycle%s until the first ring trigger fires twice." % [to_go, "" if to_go == 1 else "s"]}

## Recompute from the inventory and show/hide accordingly.
func refresh(inv, tm) -> void:
	kind = kind_for(inv)
	visible = kind != ""
	if not visible:
		_state = {}
		return
	match kind:
		"gauntlet":
			_state = gauntlet_state(inv, tm)
			tooltip_text = "Gauntlet mana: +10 mana whenever an active gauntlet skill comes off cooldown.\n" + _state.tip
		"ring":
			_state = ring_state(inv)
			tooltip_text = "Ring double: every %d cycles, the first ring trigger of the cycle fires twice.\n%s" % [
				inv.RING_DOUBLE_TRIGGER_CYCLES, _state.tip]
	modulate = Color(1, 1, 1, ALPHA_UNEQUIPPED if not _state.equipped else 1.0)
	queue_redraw()

func lit_bands() -> int:
	return int(_state.get("lit", 0))

func is_ready() -> bool:
	return bool(_state.get("ready", false))

func _draw() -> void:
	if kind == "":
		return
	var tex: Texture2D = TEX_GAUNTLET if kind == "gauntlet" else TEX_RING
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var lit: int = lit_bands()
	var equipped: bool = bool(_state.get("equipped", false))
	var band_h := (SIZE - GAP * (BANDS - 1)) / BANDS
	var src_h := th / BANDS
	# Bands are numbered from the bottom: band 0 lights first.
	for i in range(BANDS):
		var row := BANDS - 1 - i  # 0 = top row of the texture
		var dst := Rect2(0.0, row * (band_h + GAP), SIZE, band_h)
		var src := Rect2(0.0, row * src_h, tw, src_h)
		var col := COL_LIT if (equipped and i < lit) else COL_UNLIT
		draw_texture_rect_region(tex, dst, src, col)
	if is_ready():
		draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), TRIM, false, 2.0)
