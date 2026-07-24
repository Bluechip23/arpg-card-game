extends SceneTree

## Verifies the two Wisdom keystones:
##   Quick Study     (wis_empty_draw) — auto-draw when the hand empties
##   Tactician's Eye (wis_hand_crit)  — crit chance scales with cards in hand
## Covers grid placement, the hand-size crit bonus and its flow into roll_crit,
## and the save/restore round trip. (The empty-hand auto-draw itself lives in
## Main._on_hand_updated and wants a live scene; here we verify the flag +
## that draw_card leaves the timed-draw countdown untouched.)
## Run: godot --headless --path . --script tests/test_wis_keystones.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Wisdom keystones test ===")
	_test_grid_placement()
	_test_hand_crit()
	_test_empty_draw_countdown()
	_test_persistence()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _setup():
	var stats = PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(CharacterData.create_ryan())
	var inv = Inventory.new()
	get_root().add_child(inv)
	inv.initialize("Ryan")
	inv.connect_player_stats(stats)   # sets stats.inventory
	var dm = DeckManager.new()
	get_root().add_child(dm)
	inv.connect_deck_manager(dm)      # sets inv.deck_manager
	dm.connect_player_stats(stats)
	return [stats, inv, dm]

func _test_grid_placement() -> void:
	print("-- Grid placement --")
	var grid = SphereGrid.new()
	var qs = grid.get_node_by_id(112)
	var te = grid.get_node_by_id(114)
	_check(qs.node_type == SphereGrid.NodeType.KEYSTONE and qs.keystone_id == "wis_empty_draw",
		"node 112 is the Quick Study keystone")
	_check(te.node_type == SphereGrid.NodeType.KEYSTONE and te.keystone_id == "wis_hand_crit",
		"node 114 is the Tactician's Eye keystone")
	_check(qs.requirements.get("stat", "") == "wisdom" and te.requirements.get("value", 0) == 15,
		"both gated behind WIS 15")

func _test_hand_crit() -> void:
	print("-- Tactician's Eye: crit from hand size --")
	var s = _setup()
	var stats: PlayerStats = s[0]
	var dm: DeckManager = s[2]
	for i in range(4):
		dm.hand.append(Card.create_slash())
	_check(stats.get_hand_size_crit_bonus() == 0, "no bonus while the keystone is off")
	stats.keystone_wis_hand_crit = true
	_check(stats.get_hand_size_crit_bonus() == 4 * PlayerStats.WIS_CRIT_PER_CARD,
		"4 cards -> +%d crit (got %d)" % [4 * PlayerStats.WIS_CRIT_PER_CARD, stats.get_hand_size_crit_bonus()])

	# The bonus must actually reach the crit roll. Stuff the hand so the bonus
	# alone guarantees a crit, and confirm roll_crit is always true.
	var buff = BuffManager.new()
	get_root().add_child(buff)
	buff.initialize(stats, null)
	for i in range(50):
		dm.hand.append(Card.create_slash())   # 54 cards -> +108% crit
	var always := true
	for i in range(20):
		if not buff.roll_crit():
			always = false
			break
	_check(always, "a hand-crit bonus over 100%% forces a crit through roll_crit")

func _test_empty_draw_countdown() -> void:
	print("-- Quick Study: draw doesn't disturb the timed-draw countdown --")
	var s = _setup()
	var stats: PlayerStats = s[0]
	var dm: DeckManager = s[2]
	var tm = TurnManager.new()
	get_root().add_child(tm)
	tm.initialize(stats, dm)
	# Give the deck something to draw.
	dm.draw_pile.append(Card.create_slash())
	var countdown_before = tm.tempo_until_draw
	# Simulate the Quick Study auto-draw (what Main._on_hand_updated does).
	dm.draw_card()
	_check(tm.tempo_until_draw == countdown_before,
		"draw_card() leaves tempo_until_draw unchanged (%.1f)" % tm.tempo_until_draw)
	_check(dm.hand.size() == 1, "the auto-draw actually drew a card")

func _test_persistence() -> void:
	print("-- Save / restore --")
	var stats = PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(CharacterData.create_ryan())
	stats.keystone_wis_empty_draw = true
	stats.keystone_wis_hand_crit = true
	var snap = stats.save_progression()
	var restored = PlayerStats.new()
	get_root().add_child(restored)
	restored.initialize(CharacterData.create_ryan())
	restored.restore_progression(snap)
	_check(restored.keystone_wis_empty_draw, "Quick Study flag survives save/restore")
	_check(restored.keystone_wis_hand_crit, "Tactician's Eye flag survives save/restore")
