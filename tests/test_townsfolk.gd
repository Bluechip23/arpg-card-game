extends SceneTree

## The town's Sellsword and Blacksmith wear the designer's NPC sheets (four
## standing poses, 2026-10-27): the Sellsword at her post, the Blacksmith
## behind his counter. They face the plaza until the player comes near, then
## turn to look at them. The town shows no big floating names (2026-10-27).
## Run: godot --headless --path . --script tests/test_townsfolk.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _row(f: SpriteEnemyFigure) -> int:
	return int(f._sprite.region_rect.position.y / f._cp_cell)

func _run() -> void:
	print("=== Townsfolk ===")
	var town = load("res://scenes/menus/town.tscn").instantiate()
	town.starting_character = CharacterData.create_ryan()
	get_root().add_child(town)
	for _i in range(4):
		await process_frame
	var ss = town.get_node_or_null("Vendors/Sellsword/Figure")
	var smith = town.get_node_or_null("Vendors/Blacksmith/Stall/Smith")
	_check(ss is SpriteEnemyFigure and ss.figure_kind == "npc_sellsword", "the Sellsword wears her NPC sheet")
	_check(smith is SpriteEnemyFigure and smith.figure_kind == "npc_blacksmith", "the Blacksmith stands at his stall in his NPC sheet")
	if not (ss is SpriteEnemyFigure and smith is SpriteEnemyFigure):
		_finish()
		return
	for f in [ss, smith]:
		_check(f._cp_sheets.has("Idle") and str(f._cp_sheets["Idle"].resource_path).contains(f.figure_kind), "%s plays its own sheet" % f.figure_kind)

	# No big floating names in town; the quest marker and prompts stay.
	var names := []
	for l in town.find_children("*", "Label3D", true, false):
		if l.visible and l.text.strip_edges() != "" and not (l.name in ["QuestIndicator", "InteractLabel"]) and l.get_parent().name != "MoveNumbers":
			names.append(l.text)
	_check(names.is_empty(), "no floating place names left (%s)" % str(names))
	var oq = town.get_node_or_null("Vendors/Olorin/QuestIndicator")
	_check(oq != null, "Olorin keeps his quest marker")

	# Far away: both face the plaza (front row).
	town.player.position = ss.global_position + Vector3(0, 0, 12)
	await process_frame
	var front := _row(ss)
	_check(front == _row(smith), "far from the player they face the plaza")
	# The player beside the Sellsword, to her east: she turns; the smith, far off, doesn't.
	town.player.position = ss.global_position + Vector3(2, 0, 0)
	await process_frame
	_check(_row(ss) != front, "the player close by: she turns to look (row %d)" % _row(ss))
	ss.set_facing(CharacterAnimator.Direction.EAST)
	var east := _row(ss)
	town._face_townsfolk()
	_check(_row(ss) == east, "...to the east, where the player stands")
	_check(_row(smith) == front, "the Blacksmith, far off, keeps facing the plaza")
	_finish()

func _finish() -> void:
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
