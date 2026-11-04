class_name VortexPath
extends Node3D

## The Ash Harpy's Card Steal vortex over any distance up to her range 5
## (designer, 2026-11-04): the designer's vortex frames (Vortex.png beside
## her sheets, tools/cut_pose_boards.py "ash_harpy_vortex") laid as a chain
## of segments from her victim to her, each near the strip's own length
## (ArcBolt, driven), not one copy stretched — that smeared the swirl and
## drew the card a tile long. Their frames are scheduled so the vortex reads
## as one:
##   growth   — each segment grows in turn from the victim's end, reaching
##              out toward her;
##   the card — one card, carried by one segment at a time from the victim
##              toward her, ducking into the smoke as it leaves a segment
##              (the strip's own frames), so the hand-off between segments
##              is hidden;
##   the take — the segment beside her ends its pass in the red flash of the
##              card vanishing into her;
##   sustain  — a segment without the card swirls on (card-free frames);
##   blow-out — the whole vortex blows away together at the end.
## All of it fits `total` seconds (her three wing flaps).

## The strip's frames, as packed (the board's first five empty frames are
## left out: packed index = board index - 5).
const GROW := [0, 15]       # the swirl growing from the frame's right end
const CARD := [16, 42]      # the card carried right to left, hiding at the left
const CARD_LAST := [16, 46] # the same, on to the frame's left end (beside her)
const SUSTAIN := [47, 54]   # the full band, no card
const FLASH := [55, 56]     # the red flash: the card gone into her
const BLOW := [57, 76]      # blowing away

## Seconds: one segment's growth, between segments starting to grow, the
## flash, the blow-out.
const GROW_TIME := 0.5
const GROW_STEP := 0.15
const FLASH_TIME := 0.15
const BLOW_TIME := 0.6
const SUSTAIN_FPS := 14.0

var _bolts: Array = []      # ArcBolt per segment, index 0 at the victim's end
var _total := 3.0
var _clock := 0.0
var _card_from := 0.0       # when the card starts (segment 0 grown)
var _per_frame := 0.05      # seconds a card frame lasts
var _blow_at := 0.0


func total_time() -> float:
	return _total


## `bolts`: one ArcBolt a segment, index 0 at the victim's end, each already
## laid from her side to the victim's (SpriteEnemyFigure.sweep_vortex);
## `total`: the seconds it all fits in.
func setup(bolts: Array, total: float) -> void:
	_bolts = bolts
	for b in _bolts:
		b.manual = true
		b.show_frame(-1)
	_total = maxf(total, GROW_TIME + FLASH_TIME + BLOW_TIME + 0.5)
	var n := _bolts.size()
	_card_from = GROW_TIME
	_blow_at = _total - BLOW_TIME
	var card_frames := (CARD[1] - CARD[0] + 1) * (n - 1) + (CARD_LAST[1] - CARD_LAST[0] + 1)
	_per_frame = maxf(0.005, (_blow_at - FLASH_TIME - _card_from) / float(card_frames))


## Which segment carries the card at `t`, and its frame there (or -1, -1).
func _card_at(t: float) -> Vector2i:
	if t < _card_from:
		return Vector2i(-1, -1)
	var f := int((t - _card_from) / _per_frame)
	var n := _bolts.size()
	var span := CARD[1] - CARD[0] + 1
	for i in range(n):
		var last := i == n - 1
		var this_span := (CARD_LAST[1] - CARD_LAST[0] + 1) if last else span
		if f < this_span:
			return Vector2i(i, (CARD_LAST[0] if last else CARD[0]) + f)
		f -= this_span
	return Vector2i(-1, -1)


func frame_of(i: int, t: float) -> int:
	if t >= _total:
		return -1
	if t >= _blow_at:
		var k := int((t - _blow_at) / BLOW_TIME * float(BLOW[1] - BLOW[0] + 1))
		return mini(BLOW[0] + k, BLOW[1])
	var start := GROW_STEP * float(i)
	if t < start:
		return -1
	if t < start + GROW_TIME:
		return GROW[0] + mini(int((t - start) / GROW_TIME * float(GROW[1] - GROW[0] + 1)), GROW[1] - GROW[0])
	var card := _card_at(t)
	if card.x == i:
		return card.y
	if i == _bolts.size() - 1 and card.x < 0 and t >= _blow_at - FLASH_TIME:
		return FLASH[0] if t < _blow_at - FLASH_TIME * 0.5 else FLASH[1]
	# Card-free swirling, back and forth, each segment out of step.
	var n := SUSTAIN[1] - SUSTAIN[0]
	var k := int((t * SUSTAIN_FPS) + float(i) * 3.0) % (2 * n)
	return SUSTAIN[0] + (k if k <= n else 2 * n - k)


func _process(delta: float) -> void:
	_clock += delta
	if _clock >= _total:
		queue_free()
		return
	for i in range(_bolts.size()):
		var b = _bolts[i]
		if is_instance_valid(b):
			b.show_frame(frame_of(i, _clock))
