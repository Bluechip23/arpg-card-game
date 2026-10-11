extends SceneTree

## Enemy sheet second pass (docs/ENEMY_SHEET.tsv): every enemy the sheet
## specifies initialises with the sheet's numbers, has its action table, and
## reports a non-placeholder compendium entry.
## Run: godot --headless --path . --script tests/test_enemy_sheet_pass.gd

const EnemyScene = preload("res://scenes/battle/enemy.tscn")
var failures: int = 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _base(e: Enemy) -> Dictionary:
	# Undo the level-band scaling so the sheet's base numbers can be compared.
	var pps := Enemy.passive_power_scale(e.get_intended_level())
	return {
		"hp": roundi(e.max_health / pps["hp"]),
		"armor": roundi(e.max_armor / pps["hp"]),
	}

func _run() -> void:
	var script := load("res://scripts/battle/enemy.gd")
	# name: [type, hp, armor, move spaces, action names...]
	var sheet := {
		"Weregoat": [Enemy.EnemyType.WEREGOAT, 80, 0, 2, ["hoof_punch", "goat_charge", "move"]],
		"Roc": [Enemy.EnemyType.ROC, 25, 15, 1, ["dive_bomb", "eye_scrape", "roc_retreat"]],
		"Sabertooth Tiger": [Enemy.EnemyType.SABERTOOTH, 45, 0, 2, ["track", "bite_and_claw", "sunken_bite", "move"]],
		"Snow Wraith": [Enemy.EnemyType.SNOW_WRAITH, 10, 0, 3, ["snowball", "ice_blast", "move"]],
		"Granite Colossus": [Enemy.EnemyType.GRANITE_COLOSSUS, 350, 250, 3, []],
		"Demon": [Enemy.EnemyType.DEMON, 65, 0, 2, ["mimic", "demon_cuff", "demon_attack", "move"]],
		"Ash Harpy": [Enemy.EnemyType.ASH_HARPY, 6, 0, 1, ["peck", "card_steal", "move"]],
		"Magma Spider": [Enemy.EnemyType.MAGMA_SPIDER, 4, 0, 0, ["fire_web"]],
		"Mind Eater": [Enemy.EnemyType.MIND_EATER, 20, 0, 0, ["mind_slow", "mind_cuff"]],
		"Specter": [Enemy.EnemyType.SPECTER, 10, 0, 1, ["spirit_spit", "specter_vanish", "move"]],
		"Succubus": [Enemy.EnemyType.SUCCUBUS, 25, 5, 1, ["mana_drain", "damaging_snap", "move"]],
		"Cherub": [Enemy.EnemyType.CHERUB, 14, 5, 2, ["loves_arrow", "move"]],
	}
	for nm in sheet:
		var row: Array = sheet[nm]
		var e: Enemy = EnemyScene.instantiate()
		root.add_child(e)
		e.initialize(row[0])
		var b := _base(e)
		_check(e.enemy_name == nm, "%s: name" % nm)
		_check(b["hp"] == row[1], "%s: HP %d (sheet %d)" % [nm, b["hp"], row[1]])
		_check(b["armor"] == row[2], "%s: armor %d (sheet %d)" % [nm, b["armor"], row[2]])
		_check(int(e.move_distance) == row[3], "%s: move %d spaces (sheet %d)" % [nm, int(e.move_distance), row[3]])
		var names: Array = []
		for a in e.actions:
			names.append(str(a["name"]))
		_check(names == row[4], "%s: actions %s" % [nm, str(names)])
		e.queue_free()
	# Every action in every table must be dispatched (no "Unknown action").
	var probe: Enemy = EnemyScene.instantiate()
	root.add_child(probe)
	probe.initialize(Enemy.EnemyType.MINION)
	var src: String = script.source_code
	var bad: Array = []
	for t in Enemy.EnemyType.values():
		for a in Enemy.actions_for_type(t):
			if not ('"%s":' % str(a["name"])) in src:
				bad.append(str(a["name"]))
	probe.queue_free()
	_check(bad.is_empty(), "every action name is dispatched %s" % str(bad))
	# Compendium: no sheet-specified enemy still says it is a mock-up.
	var mock := 0
	for d in Enemy.get_all_enemy_data():
		if "Design mock-up" in str(d["special"]) and d["name"] in sheet:
			mock += 1
			print("    still a mock-up: %s" % d["name"])
	_check(mock == 0, "no sheet enemy is still a mock-up")
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
