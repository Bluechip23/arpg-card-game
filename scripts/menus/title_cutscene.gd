extends Control

## "Trials of Olorin" animated title cutscene.
##
## Olorin stands in the field puffing his pipe. A small boy runs up begging him
## to save the world; Olorin agrees, the boy runs off — and Olorin, spotting
## his dropped pipe, decides he'd really rather not. He snaps up a fresh lawn
## chair, telekinetically retrieves the pipe, and blows two great smoke rings
## that drift to the top of the screen and become the two O's of OLORIN.
## The remaining letters pop in, in Courgette, coloured by the title screen's
## palette (TitleMenu.STYLE). Click/ESC skips.
##
## The actors are the designer's art (2026-10-29): Olorin and his bear from
## his town sheet (sheets/olorin), the small boy, the pipe and the striped
## lounge chair (tools/cut_prop_boards.py cutscene_*) — drawn from a single
## clock (_t) alongside the procedural effects (smoke, sparkles, bubbles,
## title), so skipping is just jumping the clock to the end.

signal cutscene_finished

# ---- Timeline (seconds) ----
const T_BOY_IN := 3.0          # boy starts running in
const T_BOY_ARRIVE := 4.5      # boy reaches Olorin
const T_BUBBLE1_END := 9.2     # boy's plea
const T_STAND := 10.0          # Olorin stands, pipe drops
const T_BUBBLE2_END := 12.2    # "Of course, of course I will"
const T_GREAT_END := 13.4      # "Great!"
const T_BOY_GONE := 14.6       # boy off screen
const T_TURN := 15.4           # Olorin turns, sees the pipe
const T_BUBBLE3_END := 19.2    # "on second thought..."
const T_SNAP := 19.8           # finger snap → lawn chair
const T_LIE := 21.0            # lies down
const T_PIPE_ARRIVE := 22.4    # pipe floats to hand
const T_RING1 := 23.4          # first big ring puffed
const T_RING2 := 24.6          # second big ring puffed
const T_RINGS_PARKED := 26.2   # rings in place as the two O's
const END_T := 27.6            # letters done, menu may appear

# ---- Palette (props & effects; the actors are sprites) ----
const SMOKE := Color(0.82, 0.82, 0.88)

## The look to paint with (TitleMenu.STYLE), set before the node enters
## the tree. Missing keys fall back to a plain night forest.
var palette: Dictionary = {}

func _p(key: String, fallback):
	return palette.get(key, fallback)

# ---- Forest backdrop: ForestBackdrop (scripts/ui/forest_backdrop.gd) ----

# ---- Actors and props: the designer's art ----
## Olorin and his bear: his town sheet's four standing poses (rows front,
## back, left, right), the smooth cut. For lying back on the chair he is cut
## from his west-facing pose without the bear (x >= OLORIN_SPLIT), and the
## bear, his staff planted beside it, stands by the chair (x < OLORIN_SPLIT).
const OLORIN_SHEET := "res://assets/sprites/generated/smooth/sheets/olorin/Idle.png"
const ROW_W := 2
const ROW_E := 3
const OLORIN_SCALE := 0.8
const OLORIN_SPLIT := 130.0     # cell px: bear and staff to the left, Olorin to the right (west pose)
const OLORIN_MOUTH := Vector2(9.5, -176.0)   # west pose, cell px from the cell's bottom centre
const OLORIN_FEET_X := 185.0    # west pose: his own boots, cell px (the pivot he lies back on)
const BOY_LEFT := "res://assets/textures/props/boards/cutscene_boy_0.png"
const BOY_RIGHT := "res://assets/textures/props/boards/cutscene_boy_2.png"
const BOY_SCALE := 1.0
const BOY_MOUTH_H := 78.0       # px above the feet
const PIPE_TEX := "res://assets/textures/props/boards/cutscene_pipe_0.png"
const PIPE_TIP := Vector2(58.5, 3.0)    # the mouthpiece, image px
const PIPE_RIM := Vector2(8.5, 13.0)    # the bowl's rim, where the smoke rises
const CHAIR_TEX := "res://assets/textures/props/boards/cutscene_chair_0.png"
const RUN_FRAME_TIME := 0.11

const PIPE_SCALE := 1.0
# Radians. Held in the mouth the pipe hangs as drawn, bowl low and forward;
# lying back it is turned bowl-up to the sky; on the ground, level.
const PIPE_HOLD_ANGLE := 0.0
const PIPE_LOUNGE_ANGLE := 1.75
const PIPE_GROUND_ANGLE := 0.21
const LOUNGE_ROT := 1.15          # Olorin tipped back onto the chair (radians, clockwise)

var _olorin_tex: Texture2D = load(OLORIN_SHEET)
var _boy_left: Texture2D = load(BOY_LEFT)
var _boy_right: Texture2D = load(BOY_RIGHT)
var _pipe_tex: Texture2D = load(PIPE_TEX)
var _chair_tex: Texture2D = load(CHAIR_TEX)

func _cell() -> float:
	return float(_olorin_tex.get_height()) / 4.0

var _t: float = 0.0
var _finished_emitted: bool = false

# The full skit plays once per app run; returning to the title afterwards
# opens straight on the settled end-state (rings + title, Olorin puffing away).
static var _played_this_run: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	if _played_this_run:
		_t = END_T
	_played_this_run = true

func _process(delta: float) -> void:
	_t += delta
	if _t >= END_T and not _finished_emitted:
		_finished_emitted = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		cutscene_finished.emit()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_skip()

func _input(event: InputEvent) -> void:
	if _t < END_T and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_skip()

func _skip() -> void:
	if _t < END_T:
		_t = END_T

# =============================================================
# LAYOUT HELPERS
# =============================================================

func _ground_y() -> float:
	return size.y * 0.80

func _olorin_x() -> float:
	return size.x * 0.68

func _boy_arrive_x() -> float:
	# Short of the bear at Olorin's side.
	return _olorin_foot().x - _cell() * OLORIN_SCALE * 0.5 - 50.0

func _lounge_feet() -> Vector2:
	## Olorin's feet while lying back: on the chair's leg rest.
	var cw := float(_chair_tex.get_width())
	return Vector2(_olorin_x() - cw * 0.30, _ground_y() - 40.0)

func _mouth_pos() -> Vector2:
	## Olorin's mouth while lounging — the standing mouth turned with him
	## about his feet (_draw_olorin_lounging), so the pipe stays in it.
	var rel := OLORIN_MOUTH - Vector2(OLORIN_FEET_X - _cell() * 0.5, 0.0)
	return _lounge_feet() + (rel * OLORIN_SCALE).rotated(LOUNGE_ROT)

func _smoke_source() -> Vector2:
	## The lounging pipe's bowl — where puffs and the great rings come from.
	return _pipe_bowl(_mouth_pos(), PIPE_LOUNGE_ANGLE, PIPE_SCALE, true)

func _olorin_foot() -> Vector2:
	## Ground point under standing Olorin's sheet cell (bottom centre).
	return Vector2(_olorin_x() - 40.0, _ground_y())

func _standing_mouth(facing: float) -> Vector2:
	## Olorin's mouth while standing (pipe mouthpiece anchor).
	## facing: -1 left, +1 right (the east pose mirrors the west).
	return _olorin_foot() + Vector2(OLORIN_MOUTH.x * -facing, OLORIN_MOUTH.y) * OLORIN_SCALE

func _pipe_ground_pos() -> Vector2:
	return Vector2(_olorin_x() + 10.0, _ground_y() - 4.0)

func _title_font() -> Font:
	return GameFonts.courgette()

# ---- Title size (designer, 2026-10-25: larger, same proportions) ----
# "Trials of" and "Olorin" keep their 40 : 104 ratio. The top of "Trials
# of" stays where it always sat, and the title grows DOWN into the space
# above the menu — the menu buttons are laid out on their own and never move.
const TITLE_SCALE := 1.4
const TRIALS_SIZE := int(40 * TITLE_SCALE)
const OLORIN_SIZE := int(104 * TITLE_SCALE)
const CAP_HEIGHT := 0.7  # Courgette's capitals, as a fraction of the size

## Baseline of "Trials of": its capitals' top held at the original spot.
func _trials_baseline() -> float:
	var original_top := size.y * 0.205 - 92.0 - 40.0 * CAP_HEIGHT
	return original_top + TRIALS_SIZE * CAP_HEIGHT

## Baseline of "Olorin": the original spacing below "Trials of", scaled.
func _olorin_baseline() -> float:
	return _trials_baseline() + 92.0 * TITLE_SCALE

## Layout of the big "Olorin" letters. Returns an Array of dictionaries
## {ch, pos(baseline left), size, is_ring, center, radius}. The capital O and
## the small o are both smoke rings, each sized to its own letter.
func _olorin_layout() -> Array:
	var font := _title_font()
	var fsize := OLORIN_SIZE
	var word := "Olorin"
	var widths: Array[float] = []
	var total := 0.0
	var gap := 2.0 * TITLE_SCALE
	for i in range(word.length()):
		var w = font.get_string_size(word[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		widths.append(w)
		total += w
	total += gap * (word.length() - 1)
	var x := (size.x - total) * 0.5
	var baseline := _olorin_baseline()
	var out: Array = []
	for i in range(word.length()):
		var is_ring := (i == 0 or i == 2)  # the two O's are smoke rings
		# Ring height: the capital's cap height, or the small o's x-height.
		var glyph_h := fsize * (0.68 if i == 0 else 0.44)
		out.append({
			"ch": word[i],
			"pos": Vector2(x, baseline),
			"size": fsize,
			"is_ring": is_ring,
			"center": Vector2(x + widths[i] * 0.5, baseline - glyph_h * 0.5),
			"radius": minf(widths[i] * 0.40, glyph_h * 0.50),
			"width": widths[i],
		})
		x += widths[i] + gap
	return out

# =============================================================
# MAIN DRAW
# =============================================================

func _draw() -> void:
	_draw_backdrop()

	var g := _ground_y()
	var ox := _olorin_x()

	# ---------- Phase-dependent actors ----------
	if _t < T_STAND:
		# Standing in the field, pipe in hand, puffing away as the boy runs up.
		# He faces left toward the boy, so the pipe's bowl extends left too.
		_draw_olorin_standing(_olorin_foot(), -1.0, false)
		var smouth := _standing_mouth(-1.0)
		_draw_pipe(smouth, PIPE_HOLD_ANGLE, PIPE_SCALE, true)
		_draw_small_puffs(_pipe_bowl(smouth, PIPE_HOLD_ANGLE, PIPE_SCALE, true), _t)
	elif _t < T_SNAP:
		# Still standing; the pipe has dropped to the ground. Mirrored like the
		# standing pipe it fell from, and like the lounge pipe it will become.
		var facing := -1.0 if _t < T_TURN else 1.0  # turns around after the boy leaves
		_draw_pipe(_pipe_ground_pos(), PIPE_GROUND_ANGLE, PIPE_SCALE, true)
		var scratching := _t >= T_TURN and _t < T_BUBBLE3_END
		_draw_olorin_standing(_olorin_foot(), facing, scratching)
	else:
		# New lawn chair (snapped into existence) + lying back down.
		var chair_scale = clampf((_t - T_SNAP) / 0.35, 0.0, 1.0)
		_draw_lawn_chair(Vector2(ox, g), chair_scale)
		if _t < T_SNAP + 0.3:
			_draw_snap_flash(Vector2(ox - 60.0, g - 70.0), (_t - T_SNAP) / 0.3)
		if _t < T_LIE:
			_draw_olorin_standing(_olorin_foot(), 1.0, false)
		else:
			var pipe_in_hand := _t >= T_PIPE_ARRIVE
			_draw_olorin_lounging(Vector2(ox, g), pipe_in_hand)
			# Telekinesis: the pipe arcs to Olorin's mouth on a sparkle trail,
			# swinging upright so it lands mouthpiece-first.
			if _t >= T_LIE and _t < T_PIPE_ARRIVE:
				var u = smoothstep(0.0, 1.0, (_t - T_LIE) / (T_PIPE_ARRIVE - T_LIE))
				var from := _pipe_ground_pos()
				var to := _mouth_pos()
				var p := from.lerp(to, u)
				p.y -= sin(u * PI) * 40.0  # gentle arc
				_draw_pipe(p, lerpf(PIPE_GROUND_ANGLE, PIPE_LOUNGE_ANGLE, u), PIPE_SCALE, true)
				_draw_sparkle_trail(p, _t)
			elif _t < T_LIE:
				_draw_pipe(_pipe_ground_pos(), PIPE_GROUND_ANGLE, PIPE_SCALE, true)
			# Post-arrival idle puffs (after the big rings are out).
			if _t > T_RING2 + 0.8:
				_draw_small_puffs(_smoke_source(), _t)

	# ---------- The boy ----------
	if _t >= T_BOY_IN and _t < T_BOY_GONE:
		var bx: float
		if _t < T_BOY_ARRIVE:
			var u = (_t - T_BOY_IN) / (T_BOY_ARRIVE - T_BOY_IN)
			bx = lerpf(-40.0, _boy_arrive_x(), smoothstep(0.0, 1.0, u))
			_draw_boy(Vector2(bx, g), _t, true, 1.0)
		elif _t < T_GREAT_END:
			_draw_boy(Vector2(_boy_arrive_x(), g), _t, false, 1.0)
		else:
			var u2 = (_t - T_GREAT_END) / (T_BOY_GONE - T_GREAT_END)
			bx = lerpf(_boy_arrive_x(), -60.0, smoothstep(0.0, 1.0, u2))
			_draw_boy(Vector2(bx, g), _t, true, -1.0)

	# ---------- Framing trees (the boy runs in from behind them) ----------
	_draw_front_trees()

	# ---------- Speech bubbles ----------
	if _t >= T_BOY_ARRIVE and _t < T_BUBBLE1_END:
		_draw_bubble(Vector2(_boy_arrive_x() + 10.0, g - 235.0), [
			"Olorin! Olorin! The world! It has",
			"become ablaze of evil and distress!",
			"PLEASE HELP! Will you?!",
		], Vector2(_boy_arrive_x(), g - BOY_MOUTH_H))
	elif _t >= T_STAND and _t < T_BUBBLE2_END:
		_draw_bubble(Vector2(ox - 80.0, g - 265.0), [
			"Of course, of course I will.",
		], _standing_mouth(-1.0 if _t < T_TURN else 1.0) + Vector2(0, -14.0))
	elif _t >= T_BUBBLE2_END and _t < T_GREAT_END:
		_draw_bubble(Vector2(_boy_arrive_x() + 10.0, g - 185.0), [
			"Great!",
		], Vector2(_boy_arrive_x(), g - BOY_MOUTH_H))
	elif _t >= T_TURN + 0.6 and _t < T_BUBBLE3_END:
		_draw_bubble(Vector2(ox - 90.0, g - 265.0), [
			"On second thought, that sounds like",
			"something I care not much to do....",
		], _standing_mouth(-1.0 if _t < T_TURN else 1.0) + Vector2(0, -14.0))

	# ---------- The two great smoke rings → title O's ----------
	var layout := _olorin_layout()
	var ring_slots: Array = []
	for entry in layout:
		if entry["is_ring"]:
			ring_slots.append(entry)
	_draw_travelling_ring(T_RING1, ring_slots[0] if ring_slots.size() > 0 else null)
	_draw_travelling_ring(T_RING2, ring_slots[1] if ring_slots.size() > 1 else null)

	# ---------- Title letters ----------
	_draw_title(layout)

	# ---------- Skip hint ----------
	if _t < END_T:
		var font := _title_font()
		var hint := "click to skip"
		var hw = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, Vector2(size.x - hw - 14.0, size.y - 12.0), hint,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.35))

# =============================================================
# SCENE DRESSING
# =============================================================

func _draw_backdrop() -> void:
	ForestBackdrop.draw_backdrop(self, size, _ground_y(), _t, palette)

func _draw_front_trees() -> void:
	ForestBackdrop.draw_front_trees(self, size, palette)

# =============================================================
# ACTORS
# =============================================================

func _draw_lawn_chair(base: Vector2, scale_u: float) -> void:
	## The designer's striped lounge chair, snapped into existence: it grows
	## in with scale_u. `base` = ground point at the chair's centre.
	if scale_u <= 0.0:
		return
	var sc := smoothstep(0.0, 1.0, scale_u)
	var sz := _chair_tex.get_size()
	draw_set_transform(base, 0.0, Vector2(sc, sc))
	draw_texture_rect(_chair_tex, Rect2(Vector2(-sz.x * 0.5, -sz.y), sz), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_olorin_cell(row: int, x0: float, x1: float, foot: Vector2, rot: float = 0.0,
		pivot_x: float = -1.0) -> void:
	## Part of one cell of Olorin's sheet (cell px x0..x1), the bottom of the
	## cell at `foot` (at cell x `pivot_x`, the centre by default), tipped
	## `rot` radians about that point.
	var c := _cell()
	var s := OLORIN_SCALE
	var px := c * 0.5 if pivot_x < 0.0 else pivot_x
	draw_set_transform(foot, rot, Vector2(s, s))
	draw_texture_rect_region(_olorin_tex, Rect2(Vector2(x0 - px, -c), Vector2(x1 - x0, c)),
		Rect2(x0, row * c, x1 - x0, c))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_olorin_lounging(base: Vector2, pipe_in_hand: bool) -> void:
	## Olorin lying back on the chair: his west-facing pose without the bear,
	## tipped back about his feet on the leg rest, face to the sky. His bear
	## stands beside the chair with the staff he planted in the ground.
	var c := _cell()
	_draw_olorin_cell(ROW_W, 0.0, OLORIN_SPLIT, Vector2(base.x + float(_chair_tex.get_width()) * 0.78, base.y))
	_draw_olorin_cell(ROW_W, OLORIN_SPLIT, c, _lounge_feet(), LOUNGE_ROT, OLORIN_FEET_X)
	if pipe_in_hand:
		_draw_pipe(_mouth_pos(), PIPE_LOUNGE_ANGLE, PIPE_SCALE, true)

func _draw_olorin_standing(foot: Vector2, facing: float, scratching: bool) -> void:
	## Olorin and his bear. facing: -1 looks left, +1 looks right. While
	## pondering ("scratching"), a slow rock on the heels.
	var row := ROW_W if facing < 0.0 else ROW_E
	var rot := sin(_t * 3.0) * 0.035 if scratching else 0.0
	_draw_olorin_cell(row, 0.0, _cell(), foot, rot)

func _draw_boy(base: Vector2, t: float, running: bool, facing: float) -> void:
	## The small boy. facing +1 = to the right (toward Olorin), -1 = left.
	## Running, he bobs and leans into it (his art is one standing pose).
	var tex := _boy_right if facing > 0.0 else _boy_left
	var sz := tex.get_size() * BOY_SCALE
	var lift := 0.0
	var lean := 0.0
	if running:
		var ph := t / RUN_FRAME_TIME
		lift = absf(sin(ph * PI * 0.5)) * 7.0
		lean = 0.08 * facing
	draw_set_transform(base - Vector2(0, lift), lean, Vector2.ONE)
	draw_texture_rect(tex, Rect2(Vector2(-sz.x * 0.5, -sz.y), sz), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_pipe(pos: Vector2, angle: float, s: float, flip_h: bool = false) -> void:
	## The designer's pipe with its mouthpiece at `pos`. As drawn the bowl
	## hangs to the LEFT of the mouthpiece (flip_h = true keeps it so);
	## `angle` turns it about the mouthpiece.
	var sz := _pipe_tex.get_size()
	draw_set_transform(pos, angle, Vector2(s if flip_h else -s, s))
	draw_texture_rect(_pipe_tex, Rect2(-PIPE_TIP, sz), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _pipe_bowl(pos: Vector2, angle: float, s: float, flip_h: bool = false) -> Vector2:
	## World position of the bowl's rim for a pipe drawn with _draw_pipe —
	## the end the smoke actually comes from.
	var v := PIPE_RIM - PIPE_TIP
	if not flip_h:
		v.x = -v.x
	return pos + (v * s).rotated(angle)

# =============================================================
# SPEECH BUBBLES
# =============================================================

func _draw_bubble(top_left: Vector2, lines: Array, tail_target: Vector2) -> void:
	## Cartoon speech bubble: an off-white box holding the given text lines with
	## a little tail pointing back toward the speaker (tail_target).
	var font := _title_font()
	var fsize := 19
	var pad := 12.0
	var line_h := 26.0

	# Size the box to its widest line.
	var text_w := 0.0
	for line in lines:
		text_w = maxf(text_w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x)
	var box_w := text_w + pad * 2.0
	var box_h := line_h * lines.size() + pad * 2.0
	var rect := Rect2(top_left, Vector2(box_w, box_h))

	var fill := Color(0.96, 0.96, 0.92, 0.96)
	var border := Color(0.2, 0.16, 0.3, 0.96)
	var ink := Color(0.12, 0.1, 0.16)

	# Tail first, so the box border draws cleanly over its base.
	var base_x := clampf(tail_target.x, rect.position.x + 14.0, rect.end.x - 14.0)
	var base_l := Vector2(base_x - 9.0, rect.end.y - 1.0)
	var base_r := Vector2(base_x + 9.0, rect.end.y - 1.0)
	draw_colored_polygon(PackedVector2Array([base_l, base_r, tail_target]), fill)
	draw_line(base_l, tail_target, border, 2.0)
	draw_line(base_r, tail_target, border, 2.0)

	# Body + outline.
	draw_rect(rect, fill, true)
	draw_rect(rect, border, false, 2.0)

	# Centred text lines.
	var ty := rect.position.y + pad + float(fsize)
	for line in lines:
		var lw := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		draw_string(font, Vector2(rect.position.x + (box_w - lw) * 0.5, ty), line,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, ink)
		ty += line_h

# =============================================================
# SMOKE & EFFECTS
# =============================================================

func _draw_small_puffs(mouth: Vector2, t: float) -> void:
	## Loop of small smoke clouds drifting up from the pipe.
	for i in range(3):
		var cycle := 2.4
		var u := fposmod(t * 0.8 + i * (cycle / 3.0), cycle) / cycle
		var p := mouth + Vector2(10.0 + sin((u + i) * TAU) * 6.0, -8.0 - u * 55.0)
		var alpha := (1.0 - u) * 0.5
		var r := 4.0 + u * 8.0
		draw_circle(p, r, Color(SMOKE.r, SMOKE.g, SMOKE.b, alpha))
		draw_circle(p + Vector2(r * 0.5, -r * 0.3), r * 0.7, Color(SMOKE.r, SMOKE.g, SMOKE.b, alpha * 0.8))

func _draw_snap_flash(pos: Vector2, u: float) -> void:
	## Finger-snap star burst.
	var alpha := 1.0 - u
	for i in range(8):
		var a := i * TAU / 8.0 + u * 1.5
		var r1 := 6.0 + u * 20.0
		var r2 := 14.0 + u * 30.0
		draw_line(pos + Vector2(cos(a), sin(a)) * r1, pos + Vector2(cos(a), sin(a)) * r2,
			Color(1.0, 0.95, 0.6, alpha), 2.0)

func _draw_sparkle_trail(pos: Vector2, t: float) -> void:
	## Faint magic sparkles around the telekinetically-floating pipe.
	for i in range(4):
		var a := t * 4.0 + i * TAU / 4.0
		var p := pos + Vector2(cos(a), sin(a)) * (10.0 + 3.0 * sin(t * 7.0 + i))
		draw_circle(p, 1.6, Color(0.7, 0.5, 1.0, 0.7))

func _smoke_ring(center: Vector2, radius: float, thickness: float, alpha: float, wobble_seed: float) -> void:
	## A hand-drawn smoke ring: layered soft arcs with a slow wobble.
	var wob := 1.0 + 0.04 * sin(_t * 1.7 + wobble_seed)
	var r := radius * wob
	var col := Color(SMOKE.r, SMOKE.g, SMOKE.b, alpha)
	draw_arc(center, r, 0.0, TAU, 40, col, thickness)
	draw_arc(center, r + thickness * 0.45, 0.0, TAU, 40, Color(SMOKE.r, SMOKE.g, SMOKE.b, alpha * 0.35), thickness * 0.6)
	draw_arc(center, r - thickness * 0.45, 0.0, TAU, 40, Color(1, 1, 1, alpha * 0.3), thickness * 0.5)
	# A few drifting wisps around the ring
	for i in range(5):
		var a := _t * 0.6 + wobble_seed + i * TAU / 5.0
		var p := center + Vector2(cos(a), sin(a)) * (r + 4.0 + 2.0 * sin(_t * 2.0 + i))
		draw_circle(p, 2.0, Color(SMOKE.r, SMOKE.g, SMOKE.b, alpha * 0.35))

func _draw_travelling_ring(spawn_t: float, slot) -> void:
	## One of the two great rings: puffed at the mouth, floats to its O slot,
	## then wobbles in place forever as part of the title.
	if slot == null or _t < spawn_t:
		return
	var travel := T_RINGS_PARKED - spawn_t
	var u = clampf((_t - spawn_t) / travel, 0.0, 1.0)
	var eased := smoothstep(0.0, 1.0, u)
	var from := _smoke_source()
	var to: Vector2 = slot["center"]
	var pos := from.lerp(to, eased)
	pos.x += sin(u * PI * 2.0) * 18.0 * (1.0 - u)  # drifts as it rises
	var radius = lerpf(10.0, slot["radius"], eased)
	var thickness = lerpf(5.0, 9.0, eased)
	var alpha = lerpf(0.55, 0.9, eased)
	_smoke_ring(pos, radius, thickness, alpha, spawn_t)

# =============================================================
# TITLE
# =============================================================

func _draw_title(layout: Array) -> void:
	if _t < T_RINGS_PARKED:
		return
	var font := _title_font()
	var title_fill: Color = _p("title_fill", Color(0.98, 0.85, 0.48))
	var title_outline: Color = _p("title_outline", Color(0.05, 0.16, 0.07))
	# Stagger the letters in: "TRIALS OF" first, then the OLORIN consonants.
	var reveal := (_t - T_RINGS_PARKED) / (END_T - T_RINGS_PARKED)

	# --- "TRIALS OF" (small, above) ---
	var small := "Trials of"
	var ssize := TRIALS_SIZE
	var sw := font.get_string_size(small, HORIZONTAL_ALIGNMENT_LEFT, -1, ssize).x
	var sx := (size.x - sw) * 0.5
	var sy := _trials_baseline()
	for i in range(small.length()):
		var lu = clampf(reveal * (small.length() + 4) - i, 0.0, 1.0)
		if lu <= 0.0:
			continue
		var ch := small[i]
		var cw = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, ssize).x
		var cpos := Vector2(sx, sy - (1.0 - lu) * 10.0)
		var fill := Color(title_fill, lu)
		var outline := Color(title_outline, lu)
		draw_string_outline(font, cpos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, ssize, roundi(6 * TITLE_SCALE), outline)
		draw_string(font, cpos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, ssize, fill)
		sx += cw

	# --- "OLORIN" (big; the two O's stay as the smoke rings) ---
	var idx := 0
	for entry in layout:
		if entry["is_ring"]:
			idx += 1
			continue  # the smoke ring IS this letter
		var lu2 = clampf(reveal * (layout.size() + 5) - (idx + small.length() * 0.5), 0.0, 1.0)
		idx += 1
		if lu2 <= 0.0:
			continue
		var pos: Vector2 = entry["pos"]
		pos.y -= (1.0 - lu2) * 16.0
		var fill2 := Color(title_fill, lu2)
		var outline2 := Color(title_outline, lu2)
		draw_string_outline(font, pos, entry["ch"], HORIZONTAL_ALIGNMENT_LEFT, -1, entry["size"], roundi(8 * TITLE_SCALE), outline2)
		draw_string(font, pos, entry["ch"], HORIZONTAL_ALIGNMENT_LEFT, -1, entry["size"], fill2)
