extends SceneTree

## The animation pauses and their setting (designer, 2026-11-08: "Remove the
## 'tick speed' explanation in settings... add a setting for character pause
## animations to be removed as well. Add a pause for the character
## animations so they are cleaner"):
##  - the Settings tab no longer carries the tick-speed paragraph (the speed
##    is set on the tempo bar's arrows), and its one switch is "Pause for
##    animations" — the enemies' swing hold and now the heroes' pause too;
##  - on, a hero's drawn action (the Attack card's smash, the Block card's
##    block, a Spell card's cast) holds the tick clock for its whole drawn
##    length plus a beat, and no tick lands meanwhile; the co-op partner's
##    actions hold it too;
##  - off, nothing holds; the choice persists in the settings file.
## Run: godot --headless --path . --script tests/test_animation_pause_setting.gd

var failures := 0
var main = null

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _settle(frames: int = 6) -> void:
	for _i in range(frames):
		await process_frame

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _run() -> void:
	print("=== Animation pause setting test ===")
	await _test_settings_screen()
	_test_persists()
	await _test_battle()
	TempoManager.preferred_swing_hold = -1
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)


func _labels(n: Node, out: Array) -> void:
	if n is Label or n is Button:
		out.append(n.text)
	for c in n.get_children():
		_labels(c, out)


func _test_settings_screen() -> void:
	print("-- The Settings tab --")
	TempoManager.preferred_swing_hold = 1
	var panel: HelpPanel = load("res://scenes/ui/help_panel.tscn").instantiate()
	get_root().add_child(panel)
	await _settle(2)
	var tab: SettingsTab = panel.settings_tab
	var texts: Array = []
	_labels(tab, texts)
	var joined := "\n".join(texts)
	_check(not joined.containsn("tick speed is now controlled") and not joined.contains("TICK SPEED"),
		"the tick-speed explanation is gone")
	_check(not joined.containsn("arrows slow the action down"), "...and its arrow-button paragraph too")
	var sw := tab.find_child("SwingHold", true, false) as CheckButton
	_check(sw != null and sw.text == "Pause for animations", "the switch reads \"Pause for animations\"")
	_check(sw != null and sw.button_pressed, "on by default (the hold is on)")
	var desc := tab.find_child("SwingHoldDesc", true, false) as Label
	_check(desc != null and desc.text.containsn("heroes") and desc.text.containsn("enemies"),
		"its line says it covers the heroes and the enemies")
	panel.queue_free()
	await _settle(1)


## The switch is kept in user://settings.cfg like the tick speed. The file
## is restored afterwards (it is the player's real settings file).
func _test_persists() -> void:
	print("-- Persistence --")
	var path := TempoManager.SETTINGS_PATH
	var had := FileAccess.file_exists(path)
	var before := FileAccess.get_file_as_string(path) if had else ""
	TempoManager.remember_swing_hold(false)
	TempoManager.preferred_swing_hold = -1          # a fresh session reads the file
	_check(not TempoManager.swing_hold_enabled(), "turned off, it stays off in the next session")
	TempoManager.remember_swing_hold(true)
	TempoManager.preferred_swing_hold = -1
	_check(TempoManager.swing_hold_enabled(), "turned on again, it stays on")
	if had:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(before)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	TempoManager.preferred_swing_hold = 1


## Resolve `card` from the queue as a tick does, at `target`.
func _resolve(card: Card, target) -> void:
	main._pending_resolve_queue.append({"card": card, "target": target, "owner_index": main._active_index, "data": {}})
	main._on_card_tick_resolved(card)


## Ticks for a dummy card, so the clock has something to run.
func _queue_ticks(tm) -> void:
	var dummy := Card.new()
	dummy.card_name = "Pause Test Ticks"
	tm.start_card_ticks(dummy, 50, 50, 7)


func _expect_hold(tm, action_time: float, what: String) -> void:
	_check(action_time > 0.0, "%s is drawn (%.2f s)" % [what, action_time])
	_check(tm.is_holding_for_swing() and absf(tm._hold_timer - (action_time + TempoManager.SWING_HOLD_BEAT)) < 0.05,
		"%s holds the clock for its drawn length and a beat (%.2f s held)" % [what, tm._hold_timer])


func _test_battle() -> void:
	print("-- In battle --")
	TempoManager.preferred_swing_hold = 1
	main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	await _settle()
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	_check(main.player != null and main.enemy_spawner != null and main.tempo_manager != null, "the dojo is up")
	if main.player == null:
		return
	var tm = main.tempo_manager
	main.draw_timer.tempo_until_draw = 100000.0
	main.player.get_stats().current_health = 500
	var cell: Vector2i = main.grid_manager.world_to_grid(main.player.position)
	var w: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.WOLF, main._ground_pos(cell + Vector2i(1, 0)))
	await _settle(2)
	w.max_health = 9999
	w.current_health = 9999
	var D := CharacterAnimator.Direction
	var fig: SpriteFigure = main.player._figure

	# The Attack card: the clock waits out the whole smash, and no tick lands.
	tm.tick_speed = 0.05
	_queue_ticks(tm)
	await _settle(2)
	tm._hold_timer = 0.0
	var smash: float = fig.action_time("basic_attack", D.EAST)
	var t0: int = tm.get_global_tempo()
	_resolve(Card.create_by_id("slash"), w)
	_expect_hold(tm, smash, "the Attack card's smash")
	await _wait(smash * 0.6)
	_check(tm.get_global_tempo() == t0, "no tick lands while the smash plays (%d -> %d)" % [t0, tm.get_global_tempo()])
	await _wait(smash * 0.4 + TempoManager.SWING_HOLD_BEAT + 0.2)
	_check(not tm.is_holding_for_swing() and tm.get_global_tempo() > t0,
		"the smash done, the clock runs on (%d -> %d)" % [t0, tm.get_global_tempo()])

	# The Block card: a drawn action with no blow frame (no hit wait), held
	# all the same — new with the hero pause.
	await _settle(2)
	tm._hold_timer = 0.0
	var block_card := Card.create_by_id("block")
	var block_time: float = fig.action_time("basic_block", fig.facing)
	t0 = tm.get_global_tempo()
	_resolve(block_card, main.player)
	_expect_hold(tm, block_time, "the Block card's block")
	await _wait(block_time * 0.6)
	_check(tm.get_global_tempo() == t0, "no tick lands while the block plays (%d -> %d)" % [t0, tm.get_global_tempo()])
	await _wait(block_time * 0.4 + TempoManager.SWING_HOLD_BEAT + 0.2)
	_check(tm.get_global_tempo() > t0, "the block done, the clock runs on (%d -> %d)" % [t0, tm.get_global_tempo()])

	# A Spell card: the hero's drawn cast.
	var spell: Card = null
	for id in ["mana_surge", "fireball", "spark", "frost_bolt", "icicle"]:
		var c := Card.create_by_id(id)
		if c and c.school == Card.CardSchool.SPELL:
			spell = c
			break
	_check(spell != null, "a Spell card to cast (%s)" % (spell.card_id if spell else "none"))
	if spell:
		await _settle(2)
		tm._hold_timer = 0.0
		var cast: float = fig.action_time(SpriteFigure.DRAWN_SPELL, D.EAST)
		main.player.get_stats().current_mana = 999
		t0 = tm.get_global_tempo()
		_resolve(spell, w)
		_expect_hold(tm, cast, "the Spell card's cast")
		await _wait(cast * 0.6)
		_check(tm.get_global_tempo() == t0, "no tick lands while the cast plays (%d -> %d)" % [t0, tm.get_global_tempo()])
		await _wait(cast * 0.4 + TempoManager.SWING_HOLD_BEAT + 0.2)

	# The Block button (the shield): no tempo queued of its own here, but
	# its drawn block holds all the same via the figure.
	tm._hold_timer = 0.0
	main.player.play_animation("basic_block", D.SOUTH)
	_expect_hold(tm, fig.action_time("basic_block", D.SOUTH), "the shield's block")

	# Taking a blow is not an action: no hold.
	tm._hold_timer = 0.0
	main.player.play_animation("hit")
	_check(not tm.is_holding_for_swing(), "taking a hit never holds the clock")

	# A hold left with nothing queued runs down in real time: it never
	# delays a card played after the animation has ended.
	tm._active_cards.clear()
	tm._recompute_pending()
	main.player.play_animation("basic_attack", D.EAST)
	_check(tm.is_holding_for_swing(), "a swing with nothing queued still holds")
	await _wait(smash + TempoManager.SWING_HOLD_BEAT + 0.2)
	_check(not tm.is_holding_for_swing(), "...and the hold has run out with the swing")

	# Off: nothing holds.
	TempoManager.preferred_swing_hold = 0
	tm._hold_timer = 0.0
	_queue_ticks(tm)
	_resolve(Card.create_by_id("block"), main.player)
	_check(not tm.is_holding_for_swing(), "with \"Pause for animations\" off, the block leaves the clock alone")
	main.player.play_animation("basic_attack", D.EAST)
	_check(not tm.is_holding_for_swing(), "...and so does a swing")
	t0 = tm.get_global_tempo()
	await _wait(0.3)
	_check(tm.get_global_tempo() > t0, "ticks run at the tick speed (%d -> %d)" % [t0, tm.get_global_tempo()])
	TempoManager.preferred_swing_hold = 1

	# The co-op partner's actions hold the clock too.
	main._on_sandbox_add_ally("Jeremy")
	await _settle(2)
	var p2: Player = main._p2_player
	_check(p2 != null and p2.action_started.is_connected(main._on_hero_action_started), "the partner's figure is wired to the clock")
	if p2:
		tm._hold_timer = 0.0
		p2.play_animation("basic_attack", D.EAST)
		_expect_hold(tm, p2._figure.action_time("basic_attack", D.EAST), "the partner's attack")
	tm._hold_timer = 0.0
	main.enemy_spawner.despawn_enemy(w)
