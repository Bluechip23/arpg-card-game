extends SceneTree

## Boots the real game scene, stages a battle, and captures README screenshots.
## Run: xvfb-run godot --path . --rendering-driver opengl3 --script tests/capture_screenshots.gd

const OUT := "/tmp/shots/"

var main = null

func _dismiss() -> void:
	# Olorin's tutorial dialogs pause the tree; close any that popped up.
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame

func _shoot(name: String) -> void:
	await _dismiss()
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	img.save_png(OUT + name)
	print("SHOT ", name)

func _cam(yaw: float, pitch: float, dist: float) -> void:
	main._camera_yaw = yaw
	main._camera_pitch = pitch
	main._camera_distance = dist
	main._update_camera()

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await process_frame

	main = load("res://scenes/core/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.select_character(CharacterData.create_stephen())
	await process_frame

	# Clean shots: hide the dev/test panel if visible
	if main.test_ui:
		main.test_ui.visible = false

	# Stage a battle
	main._on_spawn_wave()
	await _dismiss()
	await create_timer(1.5).timeout
	await _dismiss()

	# --- Camera views ---
	_cam(0.0, -0.785, 17.0)
	await _shoot("view_default.png")

	_cam(1.9, -0.6, 17.0)
	await _shoot("view_rotated.png")

	_cam(0.6, -0.5, 8.0)
	await _shoot("view_zoom_in.png")

	_cam(0.3, -0.9, 32.0)
	await _shoot("view_zoom_out.png")

	# --- Attack animation (facing the nearest enemy) ---
	_cam(0.5, -0.55, 10.0)
	var enemies = main.enemy_spawner.get_living_enemies()
	if enemies.size() > 0:
		main.player.face_toward(enemies[0].position)
	main.player.play_animation("attack_slash")
	await create_timer(0.12).timeout
	await _shoot("anim_attack_a.png")
	await create_timer(0.10).timeout
	await _shoot("anim_attack_b.png")
	await create_timer(1.0).timeout

	# --- Spell cast (fireball FX) ---
	if enemies.size() > 0:
		main.player.face_toward(enemies[0].position)
	main.player.play_animation("fireball")
	await create_timer(0.30).timeout
	await _shoot("anim_spell_a.png")
	await create_timer(0.25).timeout
	await _shoot("anim_spell_b.png")
	await create_timer(1.2).timeout

	# --- Level up (mist swirl + full restore) ---
	var stats = main.player.get_stats()
	stats.gain_xp(stats.get_xp_to_next_level())
	await create_timer(0.35).timeout
	await _shoot("anim_level_up_a.png")
	await create_timer(0.30).timeout
	await _shoot("anim_level_up_b.png")

	print("ALL SHOTS DONE")
	quit(0)
