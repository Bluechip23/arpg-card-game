extends SceneTree

## The Enemy Lab previews the same art battle plays: every enemy wearing the
## designer's art (boss boards, 4x4 walk sheets and four-direction pose
## boards) shows that sheet in the
## lab, the Screecher its crawler board. The werewolf's side
## walk is the upright one (on its hind legs), not the all-fours row.
## Run: godot --headless --path . --script tests/test_enemy_lab_art.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	var lab = load("res://scenes/menus/enemy_lab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	var listed := {}
	for section in EnemyLab.SECTIONS:
		for t in section["types"]:
			listed[t] = true
	var designer := {
		Enemy.EnemyType.WOLF: "wolf", Enemy.EnemyType.WEREWOLF: "werewolf",
		Enemy.EnemyType.HYDRA: "hydra", Enemy.EnemyType.SABERTOOTH: "sabertooth",
		Enemy.EnemyType.WHITE_MANTICORE: "white_manticore", Enemy.EnemyType.WEREGOAT: "weregoat",
		Enemy.EnemyType.ARCHER_RAT: "archer_rat", Enemy.EnemyType.RAT_KING: "rat_king",
		Enemy.EnemyType.CERBERUS: "cerberus", Enemy.EnemyType.CORRUPTED_ARCHANGEL: "corrupted_archangel",
		Enemy.EnemyType.PIT_FIEND: "pit_fiend",
		Enemy.EnemyType.GIANT_BEAVER: "giant_beaver", Enemy.EnemyType.WYVERN: "wyvern",
		Enemy.EnemyType.RING_WRAITH: "ring_wraith",
	}
	for t in designer:
		var name: String = Enemy.EnemyType.keys()[t]
		_check(listed.has(t), "%s is listed in the lab" % name)
		lab._select_type(t)
		await process_frame
		var fig = lab._figure
		var folder: String = SpriteEnemyFigure.KINDS[designer[t]].get("sheets", "")
		_check(folder != "", "%s has designer sheets" % name)
		_check(fig != null and fig._cp_mode and fig._cp_sheets.has("Walk"), "%s previews its sheet in the lab" % name)
		if fig != null and fig._cp_sheets.has("Idle"):
			var want := ArtStyle.smooth_folder(folder) if fig.smooth else folder   # the smooth look's twin (ArtStyle)
			_check(fig._cp_sheets["Idle"].resource_path.begins_with(want), "%s lab sheet is %s" % [name, want])
	# The Consumed wears the crawler board in the lab too (2026-10-27).
	lab._select_type(Enemy.EnemyType.CONSUMED)
	await process_frame
	var sfig = lab._figure
	_check(sfig != null and sfig._cp_mode and sfig._cp_sheets.has("Idle")
		and sfig._cp_sheets["Idle"].resource_path.get_base_dir().ends_with("/consumed"),
		"the Consumed previews the crawler board")
	# Werewolf side view: upright, not stretched out on all fours.
	lab._select_type(Enemy.EnemyType.WEREWOLF)
	await process_frame
	lab._on_set_direction(CharacterAnimator.Direction.EAST)
	var ext: Vector2 = lab._figure.portrait_extent()
	# Upright with its tail out it is about as wide as tall (~1.0); the
	# all-fours row is nearly twice as wide as tall (~1.9).
	_check(ext.x < ext.y * 1.4, "the werewolf's side view stands on its hind legs (%.2f wide x %.2f tall)" % [ext.x, ext.y])
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures else 0)
