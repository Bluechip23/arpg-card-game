extends SceneTree

## The four Hell enemies drawn from the chaos-monster icon pack: each spawns
## with the icon rig, a portrait, and the facing rule its art needs.
## Run: godot --headless --path . --script tests/test_chaos_icons.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Chaos-monster icon battlers ===")
	_run()

func _run() -> void:
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	var main = packed.instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(6):
		await process_frame
	var want := {
		Enemy.EnemyType.SUCCUBUS: ["chaos_monsters/Icon14", "front"],
		Enemy.EnemyType.IFRIT: ["chaos_monsters/Icon27", "right"],
		Enemy.EnemyType.INFLAMED_MINOTAUR: ["chaos_monsters/Icon37", "right"],
		Enemy.EnemyType.ASH_HARPY: ["chaos_monsters/Icon42", "front"],
	}
	var x := 2.0
	for t in want:
		var en: Enemy = main.enemy_spawner.spawn_enemy(t, main.player.position + Vector3(x, 0, 0))
		x += 1.0
		await process_frame
		var fig = en._enemy_figure
		_check(fig is SpriteEnemyFigure, "%s uses the sprite rig" % en.enemy_name)
		if not (fig is SpriteEnemyFigure):
			continue
		var cfg: Dictionary = SpriteEnemyFigure.KINDS[en.figure_kind]
		_check(cfg.get("icon", "") == want[t][0], "%s is %s" % [en.enemy_name, want[t][0]])
		var tex: Texture2D = fig._sprite.texture
		_check(tex != null and tex.get_width() == 32 and tex.get_height() == 32, "%s loads its 32x32 still" % en.enemy_name)
		_check(en.get_portrait_texture() != null, "%s has a portrait" % en.enemy_name)
		fig.set_facing(CharacterAnimator.Direction.WEST)
		var west_flip: bool = fig._sprite.flip_h
		fig.set_facing(CharacterAnimator.Direction.EAST)
		var east_flip: bool = fig._sprite.flip_h
		if want[t][1] == "front":
			_check(not west_flip and not east_flip, "%s (front-on) never flips" % en.enemy_name)
		else:
			_check(west_flip and not east_flip, "%s (drawn facing right) flips to face west" % en.enemy_name)
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
