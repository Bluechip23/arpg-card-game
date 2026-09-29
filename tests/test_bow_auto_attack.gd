extends SceneTree

## The auto attack follows the held weapon: with a bow it reaches 5 tiles
## and costs 6 tempo (the Attack card's Conditional ranged surcharge); with
## empty hands or a blade it reaches the next tile for 5. The button's
## readout says which. Damage is the same either way.
## Run: godot --headless --path . --script tests/test_bow_auto_attack.gd

var _main: Node = null
var _frames := 0
var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	_main = packed.instantiate()
	_main.set("starting_character", CharacterData.create_stephen())
	_main.set("current_interior_id", "dojo")
	get_root().add_child(_main)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 12:
		return false
	_run()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
	return true

func _queued_attack_tempo() -> int:
	if _main._pending_resolve_queue.is_empty():
		return -1
	var entry: Dictionary = _main._pending_resolve_queue.back()
	return entry["card"].tempo_cost

func _run() -> void:
	print("=== Bow auto attack test ===")
	var inv = _main.player.get_inventory()
	var enemies: Array = _main.enemy_spawner.get_living_enemies()
	_check(enemies.size() >= 1, "the dojo has a dummy to shoot")
	if enemies.is_empty():
		return
	var dummy = enemies[0]
	var gm = _main.grid_manager
	var pcell: Vector2i = gm.world_to_grid(_main.player.position)

	# Empty hands: melee reach, 5 tempo.
	_check(_main._basic_attack_reach() == 1 and _main._basic_attack_tempo() == 5, "empty hands: reach 1, 5 tempo")
	_main._update_attack_button_text()
	_check(_main._attack_tempo_label.text.begins_with("5T"), "button reads 5T (%s)" % _main._attack_tempo_label.text)
	var melee_damage: int = _main._get_basic_attack_display_damage()

	dummy.position = gm.grid_to_world(pcell + Vector2i(4, 0))
	dummy.target_position = dummy.position
	var queued_before: int = _main._pending_resolve_queue.size()
	_main._execute_basic_attack(dummy)
	_check(_main._pending_resolve_queue.size() == queued_before, "a dummy 4 tiles off is out of melee reach: no swing")

	# A bow: 5 tiles of reach, 6 tempo, same damage.
	_check(inv.equip_item(ItemData.create_short_bow(), 0), "short bow equips")
	_check(_main._basic_attack_reach() == 5 and _main._basic_attack_tempo() == 6, "bow: reach 5, 6 tempo")
	_main._update_attack_button_text()
	_check(_main._attack_tempo_label.text.begins_with("6T"), "button reads 6T (%s)" % _main._attack_tempo_label.text)
	_check(_main._attack_button.tooltip_text.contains("5 tiles"), "tooltip names the bow's reach")

	_main._execute_basic_attack(dummy)
	_check(_main._pending_resolve_queue.size() == queued_before + 1, "the same dummy is inside the bow's reach: the shot queues")
	_check(_queued_attack_tempo() == 6, "…for 6 tempo (%d)" % _queued_attack_tempo())
	var entry: Dictionary = _main._pending_resolve_queue.back()
	var bow_damage: int = entry["data"]["basic_attack_damage"]
	var display: int = _main._get_basic_attack_display_damage()
	_check(bow_damage == display, "the shot's damage is the button's number (%d)" % bow_damage)
	_check(display >= melee_damage, "a bow does not lower the auto attack's damage (%d vs %d bare)" % [display, melee_damage])

	dummy.position = gm.grid_to_world(pcell + Vector2i(6, 0))
	dummy.target_position = dummy.position
	_main._execute_basic_attack(dummy)
	_check(_main._pending_resolve_queue.size() == queued_before + 1, "6 tiles off is beyond the bow: no shot")

	# Back to a blade: the next tile again, 5 tempo.
	inv.unequip_item(ItemData.ItemType.WEAPON, 0)
	_check(inv.equip_item(ItemData.create_short_sword(), 0), "a blade equips")
	_check(_main._basic_attack_reach() == 1 and _main._basic_attack_tempo() == 5, "blade: reach 1, 5 tempo")
	_main._update_attack_button_text()
	_check(_main._attack_tempo_label.text.begins_with("5T"), "button back to 5T")
