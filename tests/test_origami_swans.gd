extends SceneTree
## Destroying a card folds it into an Origami Swan; 20 swans = 1 Culling Stone.
var failures := 0
func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)
func _initialize() -> void:
	var inv = load("res://scripts/progression/inventory.gd").new()
	get_root().add_child(inv)
	inv.initialize("Brad")
	inv.culling_stones = 0
	_check(inv.get_origami_swan_count() == 0, "starts with no swans")
	var made := 0
	for _i in range(19):
		made += inv.add_origami_swans(1)
	_check(made == 0 and inv.get_origami_swan_count() == 19 and inv.culling_stones == 0, "19 swans make nothing yet")
	made = inv.add_origami_swans(1)
	_check(made == 1 and inv.get_origami_swan_count() == 0 and inv.culling_stones == 1, "the 20th swan becomes a Culling Stone")
	made = inv.add_origami_swans(45)
	_check(made == 2 and inv.get_origami_swan_count() == 5 and inv.culling_stones == 3, "a batch folds every full twenty (45 → 2 stones, 5 left)")
	_check(not ("paper_feathers" in inv), "Paper Feathers are gone")
	print("=== %d failure(s) ===" % failures)
	quit()
