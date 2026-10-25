extends SceneTree

## The designer's four-direction pose boards (tools/cut_pose_boards.py,
## 2026-10-23/24): Frankensteins Monster, the Giant Beaver, the Wyvern, the
## mounted Ring Wraith, Sanguine the blood penguin, the Djinn and the Ice,
## Fire, Earth, Spark (shock) and Air Mages wear their own sheets — one pose a direction. The
## beaver stands on its hind legs and walks on all fours; the others step a
## whole texel up and down while they walk (their art has no stride). The
## mounted wraith stands on the ground, so it casts a blob shadow.
## Run: godot --headless --path . --script tests/test_pose_boards.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

const KINDS := {"frankenstein": 1.75, "giant_beaver": 1.3, "wyvern": 1.9, "ring_wraith": 1.95,
		"sanguine_penguin": 1.15, "djinn": 1.8, "ice_mage": 1.6, "fire_mage": 1.6,
		"earth_mage": 1.6, "spark_mage": 1.6, "air_mage": 1.6}

func _initialize() -> void:
	print("=== Pose boards ===")
	var D := CharacterAnimator.Direction
	for kind in KINDS:
		var folder: String = SpriteEnemyFigure.KINDS[kind].get("sheets", "")
		_check(folder.ends_with("/" + kind), "%s wears its board's sheets (%s)" % [kind, folder])
		var f := SpriteEnemyFigure.new()
		get_root().add_child(f)
		f.setup(kind)
		_check(f._cp_mode and f._cp_sheets.has("Idle") and f._cp_sheets.has("Walk"), "%s has Idle and Walk" % kind)
		var h: float = f.portrait_extent().y
		_check(absf(h - KINDS[kind]) < 0.15, "%s stands %.2f tiles tall (want ~%.2f)" % [kind, h, KINDS[kind]])
		# Every direction shows art.
		for d in [D.SOUTH, D.NORTH, D.WEST, D.EAST]:
			f.set_facing(d)
			_check(f.portrait_extent().y > 0.5, "%s shows a pose facing %d" % [kind, d])
		# A one-pose walk steps: the sprite lifts and comes back down.
		f.set_facing(D.EAST)
		f.set_walking(true)
		var lifts := {}
		for _i in range(12):
			f._process(0.05)
			lifts[f._sprite.offset.y - f._ground_offset.y] = true
		_check(lifts.has(0.0) and lifts.has(SpriteEnemyFigure.STEP_LIFT), "%s steps while walking (%s)" % [kind, lifts.keys()])
		f.set_walking(false)
		f._process(0.05)
		_check(f._sprite.offset == f._ground_offset, "%s stands on its ground row when still" % kind)
		_check(not kind in SpriteEnemyFigure.PAINTED_SHADOW_KINDS, "%s casts a blob shadow" % kind)
		# Cut at the heroes' fineness: 64 texels a tile (2026-10-24).
		var density: float = 1.0 / (f._sprite.pixel_size * f._rig.scale.y)
		_check(absf(density - 64.0) < 0.5, "%s is drawn at 64 texels a tile (%.1f)" % [kind, density])
		f.free()

	# The beaver drops to all fours to move: its walk is a different, lower pose.
	var b := SpriteEnemyFigure.new()
	get_root().add_child(b)
	b.setup("giant_beaver")
	b.set_facing(D.SOUTH)
	var standing: float = b.portrait_extent().y
	b.set_walking(true)
	b._process(0.01)
	var on_fours: float = b.portrait_extent().y
	_check(b._cp_anim == "Walk" and on_fours < standing * 0.8,
		"the beaver walks on all fours (%.2f tall, standing %.2f)" % [on_fours, standing])
	b.free()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
