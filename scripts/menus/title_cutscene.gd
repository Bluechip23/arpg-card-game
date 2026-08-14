extends Control

## "Trials of Olorin" animated title cutscene.
##
## Olorin stands in the field puffing his pipe. A small boy runs up begging him
## to save the world; Olorin agrees, the boy runs off — and Olorin, spotting
## his dropped pipe, decides he'd really rather not. He snaps up a fresh lawn
## chair, telekinetically retrieves the pipe, and blows two great smoke rings
## that drift to the top of the screen and become the two O's of OLORIN.
## The remaining letters pop in green with a purple outline. Click/ESC skips.
##
## The actors are Mana Seed NPC sprites — Olorin is the old-man sheet (his
## town NPC sprite) and the boy is the NPC-pack boy — drawn frame-by-frame from a
## single clock (_t) alongside the procedural props (pipe, chair, smoke,
## bubbles, title), so skipping is just jumping the clock to the end.

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
const WOOD := Color(0.5, 0.34, 0.18)
const CHAIR_CLOTH := Color(0.3, 0.55, 0.4)
const SMOKE := Color(0.82, 0.82, 0.88)
const TITLE_GREEN := Color(0.3, 0.85, 0.38)
const TITLE_PURPLE := Color(0.55, 0.2, 0.8)

# ---- Actor sprites (Mana Seed NPC packs, 32px cells, rows S/E/N/W) ----
const OLORIN_SHEET := "res://assets/sprites/NPCpackage1/npc old man A v01.png"
const BOY_SHEET := "res://assets/sprites/NPCpackage2/npc boy v01.png"
const CELL := 32
const ROW_S := 0
const ROW_E := 1
const ROW_N := 2
const ROW_W := 3
const OLORIN_SCALE := 4.5  # a touch taller than the boy — presence
const BOY_SCALE := 4.0
const RUN_FRAME_TIME := 0.11

# Pipe: sized to read against the 4.5x sprite. While lounging the pipe stands
# nearly upright in Olorin's mouth, bowl to the sky.
const PIPE_SCALE := 1.8
# Radians; stem rises from the mouth with the bowl end up and its opening to
# the sky. The lounge pipe is drawn MIRRORED (flip_h) so the bowl's ember
# faces right — toward beyond Olorin's head — instead of back over his face;
# with the flip, positive angle tips the opening right of vertical.
const PIPE_LOUNGE_ANGLE := 1.15

# Sheets pre-scaled with nearest-neighbour at load, so the chunky pixels
# survive the project's linear canvas filtering (which keeps text smooth).
var _olorin_tex: Texture2D = _baked_sheet(OLORIN_SHEET, OLORIN_SCALE)
var _boy_tex: Texture2D = _baked_sheet(BOY_SHEET, BOY_SCALE)

static func _baked_sheet(path: String, factor: float) -> ImageTexture:
	var img: Image = (load(path) as Texture2D).get_image()
	img.resize(int(img.get_width() * factor), int(img.get_height() * factor), Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

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
	# The sprites are ~130px wide, so stop the boy well short of Olorin.
	return _olorin_x() - 215.0

func _mouth_pos() -> Vector2:
	## Olorin's mouth while lounging — where the pipe's mouthpiece sits.
	## Derived from the standing mouth anchor (foot + (-16, -84), west-facing)
	## rotated 58° about the lounging feet pivot — the same transform
	## _draw_olorin_lounging applies to the sprite, so the mouthpiece tracks
	## the mouth instead of drifting up the tipped head onto the forehead.
	return Vector2(_olorin_x() + 13.0, _ground_y() - 94.0)

func _smoke_source() -> Vector2:
	## The lounging pipe's bowl — where puffs and the great rings come from.
	return _pipe_bowl(_mouth_pos(), PIPE_LOUNGE_ANGLE, PIPE_SCALE, true)

func _olorin_foot() -> Vector2:
	## Ground point under standing Olorin's feet.
	return Vector2(_olorin_x() - 70.0, _ground_y())

func _standing_mouth(facing: float) -> Vector2:
	## Olorin's mouth while standing (pipe mouthpiece anchor).
	## facing: -1 left, +1 right.
	return _olorin_foot() + Vector2(16.0 * facing, -84.0)

func _pipe_ground_pos() -> Vector2:
	return Vector2(_olorin_x() - 46.0, _ground_y() - 10.0)

func _title_font() -> Font:
	return ThemeDB.fallback_font

## Layout of the big OLORIN letters. Returns an Array of dictionaries
## {ch, pos(baseline left), size, is_ring, center}.
func _olorin_layout() -> Array:
	var font := _title_font()
	var fsize := 84
	var word := "OLORIN"
	var widths: Array[float] = []
	var total := 0.0
	var gap := 6.0
	for i in range(word.length()):
		var w = font.get_string_size(word[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		widths.append(w)
		total += w
	total += gap * (word.length() - 1)
	var x := (size.x - total) * 0.5
	var baseline := size.y * 0.185
	var out: Array = []
	for i in range(word.length()):
		var is_ring := (i == 0 or i == 2)  # the two O's are smoke rings
		out.append({
			"ch": word[i],
			"pos": Vector2(x, baseline),
			"size": fsize,
			"is_ring": is_ring,
			"center": Vector2(x + widths[i] * 0.5, baseline - fsize * 0.36),
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
		_draw_pipe(smouth, -0.3, PIPE_SCALE, true)
		_draw_small_puffs(_pipe_bowl(smouth, -0.3, PIPE_SCALE, true), _t)
	elif _t < T_SNAP:
		# Still standing; the pipe has dropped to the ground. Mirrored like the
		# standing pipe it fell from, and like the lounge pipe it will become.
		var facing := -1.0 if _t < T_TURN else 1.0  # turns around after the boy leaves
		_draw_pipe(_pipe_ground_pos(), 0.12, PIPE_SCALE, true)
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
				_draw_pipe(p, lerpf(0.12, PIPE_LOUNGE_ANGLE, u), PIPE_SCALE, true)
				_draw_sparkle_trail(p, _t)
			elif _t < T_LIE:
				_draw_pipe(_pipe_ground_pos(), 0.12, PIPE_SCALE, true)
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

	# ---------- Speech bubbles ----------
	if _t >= T_BOY_ARRIVE and _t < T_BUBBLE1_END:
		_draw_bubble(Vector2(_boy_arrive_x() + 10.0, g - 200.0), [
			"Olorin! Olorin! The world! It has",
			"become ablaze of evil and distress!",
			"PLEASE HELP! Will you?!",
		], Vector2(_boy_arrive_x(), g - 84.0))
	elif _t >= T_STAND and _t < T_BUBBLE2_END:
		_draw_bubble(Vector2(ox - 80.0, g - 195.0), [
			"Of course, of course I will.",
		], Vector2(ox - 70.0, g - 110.0))
	elif _t >= T_BUBBLE2_END and _t < T_GREAT_END:
		_draw_bubble(Vector2(_boy_arrive_x() + 10.0, g - 155.0), [
			"Great!",
		], Vector2(_boy_arrive_x(), g - 84.0))
	elif _t >= T_TURN + 0.6 and _t < T_BUBBLE3_END:
		_draw_bubble(Vector2(ox - 90.0, g - 195.0), [
			"On second thought, that sounds like",
			"something I care not much to do....",
		], Vector2(ox - 70.0, g - 110.0))

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
	# Dusk sky gradient (drawn as horizontal bands) over dark grass.
	var g := _ground_y()
	var bands := 24
	for i in range(bands):
		var u := float(i) / float(bands - 1)
		var col := Color(0.05, 0.05, 0.10).lerp(Color(0.13, 0.09, 0.20), 1.0 - u)
		draw_rect(Rect2(0, g * u, size.x, g / bands + 1.0), col)
	# Stars
	for i in range(26):
		var sx := fposmod(float(i) * 197.31, size.x)
		var sy := fposmod(float(i) * 83.7, g * 0.7)
		var tw := 0.35 + 0.3 * sin(_t * 1.5 + i * 1.7)
		draw_circle(Vector2(sx, sy), 1.3, Color(1, 1, 0.9, tw))
	# Moon
	draw_circle(Vector2(size.x * 0.12, size.y * 0.14), 26.0, Color(0.9, 0.9, 0.8, 0.9))
	draw_circle(Vector2(size.x * 0.12 + 9.0, size.y * 0.14 - 4.0), 22.0, Color(0.07, 0.06, 0.13))
	# Ground
	draw_rect(Rect2(0, g, size.x, size.y - g), Color(0.10, 0.16, 0.10))
	draw_rect(Rect2(0, g, size.x, 3.0), Color(0.16, 0.26, 0.15))

# =============================================================
# ACTORS
# =============================================================

func _draw_lounge_chair(base: Vector2, cloth: Color = Color(0.55, 0.3, 0.25)) -> void:
	## Original reclined lounge chair. `base` = ground point at chair center.
	var x := base.x
	var y := base.y
	# Legs
	draw_line(Vector2(x - 60, y), Vector2(x - 48, y - 26), WOOD, 4.0)
	draw_line(Vector2(x + 60, y), Vector2(x + 48, y - 26), WOOD, 4.0)
	# Flat seat section
	draw_line(Vector2(x - 55, y - 28), Vector2(x + 30, y - 28), WOOD, 6.0)
	# Reclined back section
	draw_line(Vector2(x + 30, y - 28), Vector2(x + 66, y - 78), WOOD, 6.0)
	# Cloth
	var pts := PackedVector2Array([
		Vector2(x - 52, y - 31), Vector2(x + 28, y - 31),
		Vector2(x + 62, y - 76), Vector2(x + 52, y - 80),
		Vector2(x + 22, y - 39), Vector2(x - 52, y - 39),
	])
	draw_colored_polygon(pts, cloth)

func _draw_lawn_chair(base: Vector2, scale_u: float) -> void:
	## The snapped-into-existence lawn chair (green cloth), grows in with scale_u.
	if scale_u <= 0.0:
		return
	var s := smoothstep(0.0, 1.0, scale_u)
	draw_set_transform(base, 0.0, Vector2(s, s))
	_draw_lounge_chair(Vector2.ZERO, CHAIR_CLOTH)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_npc_frame(tex: Texture2D, col: int, row: int, foot: Vector2,
		s: float, rot: float = 0.0) -> void:
	## Draw one NPC-sheet cell for an actor whose sheet was baked at scale `s`
	## (see _baked_sheet), anchored so the cell's bottom-centre (the feet)
	## sits at `foot`. `rot` tips the whole sprite around the foot anchor
	## (radians, clockwise-positive).
	var cs := CELL * s
	draw_set_transform(foot, rot, Vector2.ONE)
	draw_texture_rect_region(tex,
		Rect2(Vector2(-cs / 2.0, -cs), Vector2(cs, cs)),
		Rect2(col * cs, row * cs, cs, cs))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_olorin_lounging(base: Vector2, pipe_in_hand: bool) -> void:
	## Olorin reclined on the chair: feet left, head up on the incline (right).
	## The west-facing profile sprite tipped backward along the chair's angle —
	## his back on the cloth, face to the sky.
	var feet := Vector2(base.x - 50.0, base.y - 36.0)
	_draw_npc_frame(_olorin_tex, 0, ROW_W, feet, OLORIN_SCALE, deg_to_rad(58.0))
	if pipe_in_hand:
		_draw_pipe(_mouth_pos(), PIPE_LOUNGE_ANGLE, PIPE_SCALE, true)

func _draw_olorin_standing(foot: Vector2, facing: float, scratching: bool) -> void:
	## Standing wizard. facing: -1 looks left, +1 looks right. While pondering
	## ("scratching"), a slow rock on the heels.
	var row := ROW_W if facing < 0.0 else ROW_E
	var rot := sin(_t * 3.0) * 0.035 if scratching else 0.0
	_draw_npc_frame(_olorin_tex, 0, row, foot, OLORIN_SCALE, rot)

func _draw_boy(base: Vector2, t: float, running: bool, facing: float) -> void:
	## The small boy. facing +1 = running right, -1 = running left. Standing
	## still he faces east, toward Olorin.
	var row := ROW_E if facing > 0.0 else ROW_W
	var col := int(t / RUN_FRAME_TIME) % 4 if running else 0
	_draw_npc_frame(_boy_tex, col, row, base, BOY_SCALE)

func _draw_pipe(pos: Vector2, angle: float, s: float, flip_h: bool = false) -> void:
	## Smoking pipe drawn with the mouthpiece (stem tip) at `pos`; the stem
	## runs +x out to the bowl, so `angle`/`flip_h` aim the bowl end.
	draw_set_transform(pos, angle, Vector2(-s if flip_h else s, s))
	draw_line(Vector2(0, 0), Vector2(24, -4), WOOD, 4.0)          # stem
	draw_rect(Rect2(21, -14, 11, 12), WOOD)                       # bowl
	draw_rect(Rect2(23, -13, 7, 4), Color(0.9, 0.4, 0.15))        # ember
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _pipe_bowl(pos: Vector2, angle: float, s: float, flip_h: bool = false) -> Vector2:
	## World position of the bowl's ember for a pipe drawn with _draw_pipe —
	## the end the smoke actually comes from.
	var v := Vector2(26.5, -15.0)
	if flip_h:
		v.x = -v.x
	return pos + (v * s).rotated(angle)

# =============================================================
# SPEECH BUBBLES
# =============================================================

func _draw_bubble(top_left: Vector2, lines: Array, tail_target: Vector2) -> void:
	## Cartoon speech bubble: an off-white box holding the given text lines with
	## a little tail pointing back toward the speaker (tail_target).
	var font := _title_font()
	var fsize := 18
	var pad := 12.0
	var line_h := 24.0

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
	var radius = lerpf(10.0, slot["size"] * 0.30, eased)
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
	# Stagger the letters in: "TRIALS OF" first, then the OLORIN consonants.
	var reveal := (_t - T_RINGS_PARKED) / (END_T - T_RINGS_PARKED)

	# --- "TRIALS OF" (small, above) ---
	var small := "TRIALS OF"
	var ssize := 30
	var sw := font.get_string_size(small, HORIZONTAL_ALIGNMENT_LEFT, -1, ssize).x
	var sx := (size.x - sw) * 0.5
	var sy := size.y * 0.185 - 84.0
	for i in range(small.length()):
		var lu = clampf(reveal * (small.length() + 4) - i, 0.0, 1.0)
		if lu <= 0.0:
			continue
		var ch := small[i]
		var cw = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, ssize).x
		var cpos := Vector2(sx, sy - (1.0 - lu) * 10.0)
		var fill := Color(TITLE_GREEN.r, TITLE_GREEN.g, TITLE_GREEN.b, lu)
		var outline := Color(TITLE_PURPLE.r, TITLE_PURPLE.g, TITLE_PURPLE.b, lu)
		draw_string_outline(font, cpos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, ssize, 6, outline)
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
		var fill2 := Color(TITLE_GREEN.r, TITLE_GREEN.g, TITLE_GREEN.b, lu2)
		var outline2 := Color(TITLE_PURPLE.r, TITLE_PURPLE.g, TITLE_PURPLE.b, lu2)
		draw_string_outline(font, pos, entry["ch"], HORIZONTAL_ALIGNMENT_LEFT, -1, entry["size"], 8, outline2)
		draw_string(font, pos, entry["ch"], HORIZONTAL_ALIGNMENT_LEFT, -1, entry["size"], fill2)
