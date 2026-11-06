class_name ChainHook
extends Node3D

## The Infected Hunter's Hook (designer 2026-11-06): a chain thrown from his
## hand to his prey and reeled back with them on it. Drawn from two pieces of
## the designer's hook board (tools/cut_pose_boards.py "infected_hunter_chain"
## and "_hookhead"): a stretch of two links, laid end to end as many times as
## the reach needs ("snip and paste the chain multiple times making the chain
## seem longer"), and the hook at its end. The chain lies in a plane that
## holds the line and faces the camera, as ArcBolt's does.
##
## It waits `delay` (the throw frame), runs out to the prey at `speed`, then
## reels them in: they are sent to `dest` (beside the hunter) and the hook
## rides on them until they get there (or REEL_MAX passes); then the chain
## pulls back into the hand and is gone.

const REEL_MAX := 1.0      # seconds the hook may ride its prey in
const RETRACT := 0.15      # seconds the empty chain takes to come home

var _owner_node: Node3D       # the hunter
var _victim: Node3D
var _dest := Vector3.ZERO     # where its prey is sent: in their parent's space, as their target_position
var _lift := Vector3.ZERO     # hand / chest height on the billboards, along screen-up
var _ahead := 0.4
var _speed := 16.0
var _delay := 0.0
var _clock := 0.0
var _phase := 0               # 0 wait, 1 out, 2 reel, 3 home
var _phase_clock := 0.0
var _out_from := Vector3.ZERO # where the prey stood when it was thrown
var _tip := Vector3.ZERO
var _home_from := Vector3.ZERO

var _chain_tex: Texture2D
var _chain_tex_m: Texture2D   # mirror images (the chain running toward the screen's left)
var _hook_tex: Texture2D
var _hook_tex_m: Texture2D
var _texel := 0.01
var _seg := 0.3               # world length of one stretch of links
var _hook_w := 0.3            # world length of the hook, its attachment to its tip
var _line_y := 0.0            # texels from a sprite's centre down to the chain's line
var _smooth := false
var _links: Array[Sprite3D] = []
var _hook: Sprite3D
var _reeled := false


## Seconds from its launch until it is back in the hand (the reel at most).
func total_time() -> float:
	var reach := Vector2(_out_from.x - _owner_node.global_position.x, _out_from.z - _owner_node.global_position.z).length()
	return _delay + reach / _speed + REEL_MAX * 0.6 + RETRACT


## `chain` / `hook`: the designer's two pieces, each centred on the chain's
## line in its square cell; `gutter`: empty rows under the smooth sheets' art.
func launch(chain: Texture2D, hook: Texture2D, texel: float, gutter: int, smooth: bool,
		owner_node: Node3D, victim: Node3D, dest: Vector3, delay: float, speed: float,
		lift: float, ahead: float) -> void:
	_owner_node = owner_node
	_victim = victim
	_dest = dest
	_delay = maxf(0.0, delay)
	_speed = maxf(1.0, speed)
	_ahead = ahead
	_texel = texel
	_smooth = smooth
	_lift = Vector3(0, CameraView.SPRITE_LIFT, 0) + CameraView.screen_up() * lift
	_chain_tex = chain
	_hook_tex = hook
	_chain_tex_m = ArcBolt._mirror_of(chain)
	_hook_tex_m = ArcBolt._mirror_of(hook)
	var cimg := chain.get_image()
	if cimg.is_compressed():
		cimg.decompress()
	var himg := hook.get_image()
	if himg.is_compressed():
		himg.decompress()
	# One stretch is its art's width, less a texel so the joints overlap.
	_seg = maxf(1.0, float(cimg.get_used_rect().size.x) - 1.0) * texel
	_hook_w = float(himg.get_used_rect().size.x) * texel
	# The pieces are centred on the line in squares that sit `gutter` rows up
	# from their cell's bottom, two rows down from its top.
	_line_y = float(gutter) * 0.5 - 1.0
	_out_from = victim.global_position
	_hook = _make_sprite(hook)
	add_child(_hook)
	visible = _delay <= 0.0


func _make_sprite(tex: Texture2D) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.shaded = false
	s.pixel_size = _texel
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if _smooth \
			else BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	# Over the figures it reaches across: the hook bites into its prey's
	# chest, in front of them (as the Harpy's vortex is drawn).
	s.no_depth_test = true
	s.render_priority = 10
	s.offset = Vector2(0, _line_y)
	return s


func _hand() -> Vector3:
	var h := _owner_node.global_position
	var d := Vector3(_tip.x - h.x, 0, _tip.z - h.z)
	if d.length() > 0.01:
		h += d.normalized() * _ahead
	return h + _lift


func _victim_at() -> Vector3:
	return _victim.global_position + _lift


func _process(delta: float) -> void:
	if not is_instance_valid(_owner_node):
		queue_free()
		return
	_clock += delta
	if _phase == 0:
		if _clock < _delay:
			return
		_phase = 1
		_phase_clock = 0.0
		_tip = _hand()
		visible = true
	_phase_clock += delta
	match _phase:
		1:
			# Out to where its prey stood.
			var to: Vector3 = _out_from + _lift
			var hand := _hand()
			var step := _speed * delta
			var left := _tip.distance_to(to)
			_tip = to if left <= step else _tip + (to - _tip) / left * step
			if _tip.distance_to(to) < 0.01:
				_phase = 2
				_phase_clock = 0.0
				_reel()
			_layout(hand, _tip)
		2:
			# The hook rides its prey in.
			if not is_instance_valid(_victim):
				_go_home()
			else:
				_tip = _victim_at()
				var there := Vector2(_victim.position.x - _dest.x, _victim.position.z - _dest.z).length() < 0.08
				if there or _phase_clock >= REEL_MAX:
					_go_home()
			_layout(_hand(), _tip)
		3:
			var t := clampf(_phase_clock / RETRACT, 0.0, 1.0)
			var hand := _hand()
			_tip = _home_from.lerp(hand, t)
			_layout(hand, _tip)
			if t >= 1.0:
				queue_free()


## The hook has its prey: they are pulled in beside the hunter.
func _reel() -> void:
	if _reeled or not is_instance_valid(_victim):
		return
	_reeled = true
	if "target_position" in _victim:
		_victim.target_position = _dest
	if "is_moving" in _victim:
		_victim.is_moving = true


func _go_home() -> void:
	_reel()   # (a hook that never caught still lets its prey go where the hunter meant)
	_phase = 3
	_phase_clock = 0.0
	_home_from = _tip


## The chain from `hand` to `tip`: the hook's far end on the tip, the links
## laid back from its attachment to the hand.
func _layout(hand: Vector3, tip: Vector3) -> void:
	var span := tip - hand
	var length := span.length()
	if length < 0.02:
		for l in _links:
			l.visible = false
		_hook.visible = false
		return
	var x := span / length
	var up := CameraView.screen_up()
	var y := up - x * up.dot(x)
	if y.length() < 0.2:
		var back := CameraView.toward_camera()
		var nn := (back - x * back.dot(x)).normalized()
		y = nn.cross(x)
	y = y.normalized()
	var n := x.cross(y).normalized()
	# Running toward the screen's left the plane would face away: turn it
	# round and draw the mirror images (see ArcBolt).
	var s := 1.0
	if n.dot(CameraView.toward_camera()) < 0.0:
		x = -x
		n = -n
		s = -1.0
	global_transform = Transform3D(Basis(x, y, n), (hand + tip) * 0.5)
	var half := length * 0.5
	var tip_x := s * half
	_hook.texture = _hook_tex if s > 0.0 else _hook_tex_m
	_hook.visible = true
	var hook_len := minf(_hook_w, length)
	_hook.position = Vector3(tip_x - s * hook_len * 0.5, 0, 0)
	var chain_len := maxf(0.0, length - hook_len)
	var count := int(ceil(chain_len / _seg))
	while _links.size() < count:
		var l := _make_sprite(_chain_tex)
		add_child(l)
		_links.append(l)
	var attach := tip_x - s * hook_len
	for i in range(_links.size()):
		var l := _links[i]
		l.visible = i < count
		if i < count:
			l.texture = _chain_tex if s > 0.0 else _chain_tex_m
			l.position = Vector3(attach - s * _seg * (float(i) + 0.5), 0, 0)
