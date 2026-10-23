extends SceneTree

## Self-made figures are gone (designer, 2026-10-23): the player's summons,
## the Ring Wraith, the dojo master and the character screens wear pack art.
##  - every summon that a pack can dress stands a pack sprite in for its body
##    and builds no shape meshes (Sanguine the penguin and the bull worm keep
##    theirs: no pack has a penguin or a worm);
##  - every enemy type has a sprite (the Ring Wraith was the prototype box);
##  - the Dojo master in town is an NPC-pack sheet, not the drawn ninja;
##  - the character-select card and the load screen show the character's
##    pack figure, and the old hand-drawn portraits are not in the game.
## Run: godot --headless --path . --script tests/test_pack_art_only.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _meshes(n: Node) -> int:
	return n.find_children("*", "MeshInstance3D", true, false).size()

func _run() -> void:
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(6):
		await process_frame
	var gm = main.grid_manager
	var at: Vector3 = main.player.position
	var specs := {
		"Wolf": ["res://scripts/battle/summoned_wolf.gd", [], "wolf"],
		"Specter": ["res://scripts/battle/summoned_specter.gd", [12], "summon_specter"],
		"Skeleton": ["res://scripts/battle/summoned_skeleton.gd", [10, "skeleton"], "skeleton"],
		"Spirit": ["res://scripts/battle/summoned_skeleton.gd", [10, "spirit"], "specter"],
		"Golem": ["res://scripts/battle/summoned_skeleton.gd", [10, "golem"], "summon_golem"],
		"Frankensteins Monster": ["res://scripts/battle/frankensteins_monster.gd", [20], "frankenstein"],
	}
	for name in specs:
		var sp: Array = specs[name]
		var n = load(sp[0]).new()
		main.add_child(n)
		var args: Array = [gm, at]
		args.append_array(sp[1])
		n.callv("setup", args)
		await process_frame
		_check(n._figure is SpriteEnemyFigure and n._figure.figure_kind == sp[2], "%s wears the '%s' pack sprite" % [name, sp[2]])
		_check(_meshes(n) == 0, "%s builds no shape meshes (%d)" % [name, _meshes(n)])
		_check(SpriteEnemyFigure.KINDS.has(sp[2]), "%s's kind '%s' is on the sprite table" % [name, sp[2]])
		n.queue_free()
	# Draupnir's duplicate wears its bearer's own figure.
	var clone = load("res://scripts/battle/summoned_clone.gd").new()
	main.add_child(clone)
	clone.setup(gm, at, 20, "Ryan")
	await process_frame
	_check(clone._figure is SpriteFigure, "the Duplicate wears its bearer's figure")
	_check(_meshes(clone) == 0, "the Duplicate builds no shape meshes")
	clone.queue_free()
	# The spirit bow is the weapon pack's bow.
	for bud in [false, true]:
		var bow = load("res://scripts/battle/spirit_bow_summon.gd").new()
		main.add_child(bow)
		bow.setup(gm, at, bud)
		await process_frame
		var spr: Array = bow.find_children("*", "Sprite3D", true, false)
		_check(spr.size() == 1 and spr[0].texture.resource_path.begins_with("res://assets/sprites/craftpix/weapon_icons/"),
			"the %s is the weapon pack's bow" % ("bud" if bud else "Spirit Bow"))
		_check(_meshes(bow) == 0, "the %s builds no shape meshes" % ("bud" if bud else "Spirit Bow"))
		bow.queue_free()

	# Every enemy type has a sprite (no prototype boxes left).
	var boxed := []
	for k in Enemy.EnemyType.keys():
		var kind := str(EnemyDefs.DEFS.get(k, {}).get("figure_kind", ""))
		if not SpriteEnemyFigure.supports(kind):
			boxed.append(k)
	_check(boxed.is_empty(), "every enemy type has a sprite %s" % [boxed])
	var rw: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.RING_WRAITH, at + Vector3(2, 0, 0))
	await process_frame
	_check(rw._enemy_figure != null and rw._enemy_figure.visible, "the Ring Wraith spawns as its ghost sprite")
	_check(not (rw.mesh and rw.mesh.visible), "the Ring Wraith's prototype box is hidden")

	# The character screens show pack figures; the old portraits are gone.
	for p in ["brad", "cory", "jeremy", "ryan", "stephen"]:
		_check(not ResourceLoader.exists("res://assets/characters/%s_south.png" % p), "the hand-drawn %s portrait is gone" % p)
	for c in CharacterData.get_all_characters():
		_check(c.sprite_path == "", "%s carries no portrait path" % c.character_name)
	var card = load("res://scenes/character/character_card.tscn").instantiate()
	get_root().add_child(card)
	await process_frame
	card.setup(CharacterData.create_jeremy())
	await process_frame
	_check(card.find_children("*", "SpriteFigure", true, false).size() == 1, "the character-select card shows Jeremy's pack figure")
	_check(card.find_children("*", "TextureRect", true, false).is_empty(), "the card has no flat portrait picture")
	card.queue_free()
	var preview := SpriteFigure.make_preview("Cory")
	get_root().add_child(preview)
	await process_frame
	_check(preview.find_children("*", "SpriteFigure", true, false).size() == 1, "the load screen's preview holds the pack figure")
	preview.queue_free()

	# The Dojo master is an NPC-pack sheet.
	main.queue_free()
	await process_frame
	var town = load("res://scenes/menus/town.tscn").instantiate()
	town.set("starting_character", CharacterData.create_brad())
	get_root().add_child(town)
	for _i in range(6):
		await process_frame
	var dojo = town.find_child("Dojo", true, false)
	var fig = dojo.get_node_or_null("Figure") if dojo else null
	_check(fig is Sprite3D and fig.texture.resource_path.begins_with("res://assets/sprites/NPCpackage"), "the Dojo master is an NPC-pack sheet")
	_check(not ResourceLoader.exists("res://assets/sprites/generated/npcs/ninja.png"), "the drawn ninja is gone")
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures else 0)
