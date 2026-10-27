extends SceneTree

## Dev helper: in the dojo, play the summon cards for real (hand → tempo →
## resolve), let tempo run so they walk to the dummies and fight, and save a
## PNG.  ... --script tests/_capture_summons.gd -- <out.png>

var _f := 0
var m
var out := "/tmp/summons.png"
var queue := ["skeleton_army", "turtle_power", "summon_shadow_hound"]

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	m = load("res://scenes/core/main.tscn").instantiate()
	m.set("starting_character", CharacterData.create_brad())
	m.set("current_interior_id", "dojo")
	get_root().add_child(m)

func _play(cid: String, cell: Vector2i) -> void:
	var gm = m.grid_manager
	Input.warp_mouse(m.world_to_screen(gm.grid_to_world(cell)))
	var c := Card.create_by_id(cid)
	m.deck_manager.add_card_to_hand(c, true)
	m.player.get_stats().current_mana = 999
	m.selected_card_index = m.deck_manager.hand.find(c)
	m._card_play_confirmed = true
	m.play_selected_card(null)

func _process(_d: float) -> bool:
	_f += 1
	if _f == 40 and m.olorin and m.olorin.is_busy(): m.olorin._close()
	var here: Vector2i = m.grid_manager.world_to_grid(m.player.position) if m.player else Vector2i.ZERO
	if _f == 45:
		m.player.get_stats().base_intelligence = 40
		_play("skeleton_army", here + Vector2i(3, -1))
	if _f == 75:
		_play("turtle_power", here + Vector2i(-1, -2))
	if _f == 110:
		_play("summon_shadow_hound", here + Vector2i(1, 1))
	if _f >= 115 and _f < 145 and _f % 3 == 0:
		m.tempo_manager.add_tempo(1)   # let time pass: the summons walk and fight
	if _f == 150:
		print("SUMMONS ", m._skeletons.map(func(s): return "%s %d/%d @%s" % [s.display_name, s.health, s.max_health, s.get_cell()]))
		for e in m.enemy_spawner.get_living_enemies(): print("ENEMY ", e.enemy_name, " ", e.current_health)
		get_root().get_texture().get_image().save_png(out)
		quit()
	return false
