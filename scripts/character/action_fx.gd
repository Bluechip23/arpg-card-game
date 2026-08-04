class_name ActionFX
extends Node3D

## Bespoke per-card effect layer for SpriteFigure.
##
## The sprite sheets can only express walk/idle/attack, so every distinctive
## card animation lives here as a procedural 3D effect timeline (ported from
## the old CharacterFigure's effect spawners): icicles, fireballs, flying
## pigs, arrow volleys, lightning, potions, and so on. SpriteFigure plays a
## suitable body motion (swing / hop / crouch / lunge…) and calls play() on
## this node for the matching effect.
##
## The node sits at the figure's ground centre and is yawed by SpriteFigure
## so local +Z always points where the figure is facing — all effects are
## authored in that space ("forward" = toward the target).

## Body-motion hint SpriteFigure should play alongside each effect. This is
## also the authoritative list of actions ActionFX handles.
const BODY := {
	# --- Brad ---
	"approach_stance": "guard", "charge": "lunge", "harden": "guard",
	"heavy_swing": "axe", "heroic_leap": "high_hop", "hold_the_line": "guard",
	"hunker_down": "guard", "life_steal": "none", "life_swap": "bounce",
	"morphine": "bounce", "parry": "sword", "roar": "bounce", "roll": "hop",
	"shed_weight": "bounce", "shield_slam": "lunge", "succumb": "crouch",
	"taunt": "bounce", "down_but_not_out": "heal", "cover": "guard",
	# --- Stephen (archer) ---
	"bow_shot": "bounce", "lead_arrow": "bounce", "multishot": "bounce",
	"down_town": "bounce", "sky_attack": "bounce", "sky_fall": "high_hop",
	"tighten_string": "none", "reload": "none", "mark": "none",
	"collect_arrows": "bounce", "enchanted_quiver": "none",
	"exhausted_assault": "bounce", "bottomless_quiver": "none",
	"rise": "high_hop", "barricade": "guard",
	# --- Jeremy (gambler / chaos mage) ---
	"communal_donation": "bounce", "snowballs_chance": "bounce",
	"biscuit": "bounce", "cryonics": "none", "demonic_rage": "bounce",
	"fireball": "lunge", "god_of_thunder": "none", "harness_lightning": "none",
	"if_pigs_could_fly": "kick", "lady_luck": "crouch", "magic_barrier": "none",
	"mana_surge": "bounce", "mirror_mirror": "none", "risk_it": "bounce",
	"shepherds_mark": "none", "spark": "bounce", "surrounding_ice": "none",
	"trick_shot": "bounce", "vengeful_shield": "bounce",
	"worms_armageddon": "bounce", "deep_pockets": "none",
	"friendship": "bounce", "prepare": "none", "dice_roll": "bounce",
	"shrug": "bounce", "disco": "bounce",
	# --- Ryan / Cory (rogue & apothecary) ---
	"absorb_essence": "none", "vines": "none", "bob_and_weave": "weave",
	"choke": "lunge", "energy_ball": "bounce", "exposed_artery": "sword",
	"meditate": "crouch", "misery_loves_company": "none",
	"potion_of_continuance": "heal", "push": "lunge",
	"release_tension": "bounce", "sweeping_disarm": "sword",
	"anticipation": "none", "item_mastery": "bounce", "blade_barrage": "bounce",
	"adrenaline_shot": "bounce", "bloodlust": "bounce", "elixir": "heal",
	"poisoned_blood": "none", "exacerbate_wounds": "lunge",
	"gargle_and_spit": "bounce", "lethal_recall": "none", "patience": "none",
	"raged_circulation": "bounce", "shadows": "bounce", "shuriken": "lunge",
	"dagger_throw": "lunge", "thrown_stone": "lunge", "shuriken_pouch": "bounce",
	"volatile_mixture": "bounce",
	# --- Systemic ---
	"level_up": "bounce",
}

static var _tex_cache := {}


static func handles(action: String) -> bool:
	return BODY.has(action)


static func body_for(action: String) -> String:
	return BODY.get(action, "")


func play(action: String) -> void:
	match action:
		# Brad
		"approach_stance": _fx_guard_flash(Color(0.5, 0.7, 1.0))
		"charge": _fx_charge()
		"harden": _fx_harden()
		"heavy_swing": _fx_heavy_swing()
		"heroic_leap": _fx_heroic_leap()
		"hold_the_line": _fx_hold_the_line()
		"hunker_down": _fx_dome(Color(0.6, 0.7, 0.9))
		"life_steal": _fx_life_steal()
		"life_swap": _fx_life_swap()
		"morphine": _fx_morphine()
		"parry": _fx_parry()
		"roar": _fx_roar()
		"roll": _fx_roll_dust()
		"shed_weight": _fx_shed_weight()
		"shield_slam": _fx_shield_slam()
		"succumb": _fx_succumb()
		"taunt": _fx_taunt()
		"down_but_not_out": _fx_second_wind()
		"cover": _fx_dome(Color(0.75, 0.75, 0.85))
		# Stephen
		"bow_shot": _fx_bow_shot()
		"lead_arrow": _fx_lead_arrow()
		"multishot": _fx_multishot()
		"down_town": _fx_down_town()
		"sky_attack": _fx_sky_attack()
		"sky_fall": _fx_sky_fall()
		"tighten_string": _fx_tighten_string()
		"reload": _fx_reload()
		"mark": _fx_mark()
		"collect_arrows": _fx_collect_arrows()
		"enchanted_quiver": _fx_enchanted_quiver()
		"exhausted_assault": _fx_exhausted_assault()
		"bottomless_quiver": _fx_bottomless_quiver()
		"rise": _fx_rise()
		"barricade": _fx_barricade()
		# Jeremy
		"communal_donation": _fx_communal_donation()
		"snowballs_chance": _fx_snowballs_chance()
		"biscuit": _fx_biscuit()
		"cryonics": _fx_cryonics()
		"demonic_rage": _fx_aura(Color(0.85, 0.12, 0.12))
		"fireball": _fx_fireball()
		"god_of_thunder": _fx_god_of_thunder()
		"harness_lightning": _fx_orbiting_orb(Color(0.5, 0.72, 1.0))
		"if_pigs_could_fly": _fx_punt_pig()
		"lady_luck": _sparks(Vector3(0, 1.0, 0.3), Color(1.0, 0.9, 0.4), 6, 0.4)
		"magic_barrier": _fx_ring_sweep(Color(0.3, 0.85, 0.85))
		"mana_surge": _fx_mana_surge()
		"mirror_mirror": _fx_mirror()
		"risk_it": _fx_risk_it()
		"shepherds_mark": _fx_sheep()
		"spark": _fx_spark()
		"surrounding_ice": _fx_surrounding_ice()
		"trick_shot": _fx_trick_shot()
		"vengeful_shield": _fx_vengeful_shield()
		"worms_armageddon": _fx_worms_armageddon()
		"deep_pockets": _fx_deep_pockets()
		"friendship": _fx_hearts()
		"prepare": _sparks(Vector3(0, 0.6, 0.0), Color(0.9, 0.85, 0.5), 6, 0.3)
		"dice_roll": _fx_dice()
		"shrug": _voice("...?", Color(0.85, 0.85, 0.9))
		"disco": _fx_disco()
		# Ryan / Cory
		"absorb_essence": _fx_essence_motes(Color(0.7, 0.45, 0.95), true)
		"vines": _fx_vines()
		"bob_and_weave": _sparks(Vector3(0, 0.8, 0.1), Color(0.8, 0.85, 0.95), 4, 0.35)
		"choke": _fx_choke()
		"energy_ball": _fx_energy_ball()
		"exposed_artery": _fx_exposed_artery()
		"meditate": _fx_meditate()
		"misery_loves_company": _fx_misery()
		"potion_of_continuance": _fx_potion(Color(0.4, 0.9, 0.5))
		"push": _fx_push()
		"release_tension": _fx_release_tension()
		"sweeping_disarm": _fx_sweep_arc()
		"anticipation": _fx_anticipation()
		"item_mastery": _fx_item_mastery()
		"blade_barrage": _fx_blade_barrage()
		"adrenaline_shot": _fx_adrenaline()
		"bloodlust": _fx_aura(Color(0.75, 0.1, 0.15))
		"elixir": _fx_potion(Color(0.95, 0.75, 0.3))
		"poisoned_blood": _fx_poisoned_blood()
		"exacerbate_wounds": _fx_exacerbate()
		"gargle_and_spit": _fx_spit()
		"lethal_recall": _fx_lethal_recall()
		"patience": _fx_patience()
		"raged_circulation": _fx_orbiting_orb(Color(0.95, 0.3, 0.25))
		"shadows": _fx_shadows()
		"shuriken": _fx_shuriken()
		"dagger_throw": _fx_dagger_throw()
		"thrown_stone": _fx_thrown_stone()
		"shuriken_pouch": _fx_shuriken_pouch()
		"volatile_mixture": _fx_volatile_mixture()
		# Systemic
		"level_up": _fx_level_up()


# =============================================================
# EFFECTS — Brad
# =============================================================

func _fx_guard_flash(col: Color) -> void:
	_burst(Vector3(0, 0.7, 0.2), col, 0.9)


func _fx_charge() -> void:
	# Dust kicked up behind as he barrels forward.
	_puffs(Vector3(0, 0.15, -0.3), Color(0.62, 0.55, 0.45), 8, 0.5)
	_burst(Vector3(0, 0.6, 0.9), Color(1, 1, 1), 0.8)


func _fx_harden() -> void:
	# Stone-grey chips flying off as the skin sets.
	_sparks(Vector3(0, 0.7, 0.1), Color(0.65, 0.65, 0.68), 8, 0.45)
	_burst(Vector3(0, 0.7, 0.1), Color(0.7, 0.7, 0.72), 1.0)


func _fx_heavy_swing() -> void:
	var tw := create_tween()
	tw.tween_interval(0.22)  # land with the swing's active frames
	tw.tween_callback(_burst.bind(Vector3(0, 0.6, 1.2), Color(1, 1, 1), 1.4))
	tw.tween_callback(_sparks.bind(Vector3(0, 0.5, 1.2), Color(1.0, 0.9, 0.6), 6, 0.5))


func _fx_heroic_leap() -> void:
	var tw := create_tween()
	tw.tween_interval(0.42)  # land after the high hop
	tw.tween_callback(_burst.bind(Vector3(0, 0.2, 0.6), Color(1, 1, 1), 1.6))
	tw.tween_callback(_dirt.bind(Vector3(0, 0.1, 0.6)))


func _fx_hold_the_line() -> void:
	_burst(Vector3(0, 0.5, 0.2), Color(1.0, 0.85, 0.35), 1.2)
	_sparks(Vector3(0, 0.2, 0.1), Color(1.0, 0.85, 0.35), 6, 0.5)


func _fx_dome(col: Color) -> void:
	# A shield dome ring that settles low around the figure.
	var ring := _torus(Vector3(0, 1.2, 0), 0.4, 0.55, col)
	ring.material_override = _emissive(col, 1.2)
	add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "position:y", 0.25, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.4)
	tw.tween_property(ring, "scale", Vector3(1.4, 0.02, 1.4), 0.18)
	tw.tween_callback(ring.queue_free)


func _fx_life_steal() -> void:
	_fx_essence_motes(Color(0.9, 0.2, 0.25), true)


func _fx_life_swap() -> void:
	# Red essence out, green essence in — a trade of vitality.
	_fly_orb(Vector3(0.1, 0.8, 0.3), Vector3(0, 0.2, 1.8), Color(0.9, 0.25, 0.3), 0.09, 0.35)
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_callback(_fly_orb.bind(Vector3(-0.1, 1.0, 2.0), Vector3(0, -0.2, -1.8), Color(0.35, 0.9, 0.4), 0.09, 0.35))


func _fx_morphine() -> void:
	_syringe_jab(Color(0.75, 0.95, 0.8))


func _fx_parry() -> void:
	# Metallic clash sparks in front.
	var tw := create_tween()
	tw.tween_interval(0.16)
	tw.tween_callback(_burst.bind(Vector3(0.1, 0.8, 0.7), Color(1, 1, 0.9), 0.9))
	tw.tween_callback(_sparks.bind(Vector3(0.1, 0.8, 0.7), Color(1.0, 0.95, 0.6), 8, 0.5))


func _fx_roar() -> void:
	_voice("RAAAGH!", Color(1.0, 0.6, 0.3))
	# Expanding shout rings from the head.
	for i in range(3):
		var ring := _torus(Vector3(0, 1.0, 0.3), 0.1, 0.16, Color(1.0, 0.7, 0.4))
		ring.material_override = _emissive(Color(1.0, 0.7, 0.4), 1.2)
		ring.rotation_degrees = Vector3(90, 0, 0)
		add_child(ring)
		var tw := ring.create_tween()
		tw.tween_interval(i * 0.09)
		tw.tween_property(ring, "position:z", 1.4, 0.4).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(ring, "scale", Vector3.ONE * 2.6, 0.4)
		tw.tween_property(ring, "scale", Vector3.ZERO, 0.08)
		tw.tween_callback(ring.queue_free)


func _fx_roll_dust() -> void:
	_puffs(Vector3(0, 0.12, 0), Color(0.62, 0.55, 0.45), 6, 0.4)


func _fx_shed_weight() -> void:
	# Armour plates tumbling off.
	for i in range(4):
		var plate := _box(Vector3(randf_range(-0.2, 0.2), 0.8, 0.1), Vector3(0.16, 0.12, 0.05), Color(0.6, 0.62, 0.68))
		add_child(plate)
		var dest := plate.position + Vector3(randf_range(-0.6, 0.6), -0.7, randf_range(-0.4, 0.4))
		var tw := plate.create_tween()
		tw.tween_interval(i * 0.06)
		tw.tween_property(plate, "position", dest, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(plate, "rotation_degrees", Vector3(randf_range(-240, 240), 0, randf_range(-240, 240)), 0.35)
		tw.tween_property(plate, "scale", Vector3.ZERO, 0.12)
		tw.tween_callback(plate.queue_free)


func _fx_shield_slam() -> void:
	var tw := create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(_burst.bind(Vector3(0, 0.7, 1.1), Color(1, 1, 1), 1.5))
	tw.tween_callback(_dirt.bind(Vector3(0, 0.15, 1.1)))


func _fx_succumb() -> void:
	_puffs(Vector3(0, 0.5, 0.1), Color(0.35, 0.3, 0.42), 10, 0.5)


func _fx_taunt() -> void:
	_voice("COME ON!", Color(1.0, 0.8, 0.3))


func _fx_second_wind() -> void:
	_burst(Vector3(0, 0.6, 0.1), Color(0.4, 0.95, 0.5), 1.3)
	_rising_sparks(Color(0.5, 1.0, 0.55), 8)


# =============================================================
# EFFECTS — Stephen (archer)
# =============================================================

func _fx_bow_shot() -> void:
	_arrow(Vector3(0.05, 0.8, 0.3), Vector3(0, 0.05, 2.4))


func _fx_lead_arrow() -> void:
	# A fat, heavy arrow that drops as it flies.
	_arrow(Vector3(0.05, 0.8, 0.3), Vector3(0, -0.25, 2.2), Color(0.5, 0.5, 0.58), 0.6, 0.055, 0.42)


func _fx_multishot() -> void:
	_arrow(Vector3(0.0, 0.8, 0.3), Vector3(-0.7, 0.05, 2.2))
	_arrow(Vector3(0.0, 0.8, 0.3), Vector3(0, 0.08, 2.4))
	_arrow(Vector3(0.0, 0.8, 0.3), Vector3(0.7, 0.05, 2.2))


func _fx_down_town() -> void:
	# Fire skyward, then the volley rains on the target.
	_arrow(Vector3(0.05, 0.9, 0.2), Vector3(0.1, 2.6, 0.7), Color(0.85, 0.72, 0.42), 0.5, 0.03, 0.3)
	var tw := create_tween()
	tw.tween_interval(0.45)
	tw.tween_callback(_rain_arrows.bind(4, 1.7))


func _fx_sky_attack() -> void:
	_arrow(Vector3(0.05, 0.9, 0.2), Vector3(0.05, 3.0, 0.5), Color(0.9, 0.8, 0.5), 0.55, 0.035, 0.35)
	_sparks(Vector3(0.05, 1.0, 0.3), Color(1.0, 0.9, 0.5), 4, 0.3)


func _fx_sky_fall() -> void:
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(_rain_arrows.bind(5, 1.4))
	tw.tween_interval(0.2)
	tw.tween_callback(_burst.bind(Vector3(0, 0.2, 1.4), Color(1, 1, 1), 1.2))


func _fx_tighten_string() -> void:
	_sparks(Vector3(0.15, 0.8, 0.2), Color(0.95, 0.95, 1.0), 4, 0.25)


func _fx_reload() -> void:
	_puffs(Vector3(-0.1, 0.9, -0.15), Color(0.7, 0.62, 0.45), 5, 0.3)


func _fx_mark() -> void:
	# Concentric target rings appear out where the enemy stands.
	for i in range(2):
		var ring := _torus(Vector3(0, 0.7, 1.8), 0.12 + i * 0.16, 0.16 + i * 0.16, Color(1.0, 0.3, 0.25))
		ring.material_override = _emissive(Color(1.0, 0.3, 0.25), 1.5)
		ring.rotation_degrees = Vector3(90, 0, 0)
		ring.scale = Vector3.ZERO
		add_child(ring)
		var tw := ring.create_tween()
		tw.tween_interval(i * 0.08)
		tw.tween_property(ring, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.5)
		tw.tween_property(ring, "scale", Vector3.ZERO, 0.12)
		tw.tween_callback(ring.queue_free)


func _fx_collect_arrows() -> void:
	# Spent arrows fly back in from the field.
	for i in range(3):
		var start := Vector3(randf_range(-0.8, 0.8), 0.2, randf_range(1.2, 2.0))
		_arrow(start, Vector3(0, 0.6, 0) - start + Vector3(0, 0, 0.1), Color(0.85, 0.72, 0.42), 0.45, 0.025, 0.3)


func _fx_enchanted_quiver() -> void:
	_rising_sparks(Color(0.75, 0.5, 1.0), 8)
	_burst(Vector3(-0.1, 0.9, -0.1), Color(0.75, 0.5, 1.0), 0.9)


func _fx_exhausted_assault() -> void:
	for i in range(5):
		var tw := create_tween()
		tw.tween_interval(i * 0.09)
		tw.tween_callback(_arrow.bind(Vector3(0.05, 0.8, 0.3),
				Vector3(randf_range(-0.3, 0.3), randf_range(-0.1, 0.15), 2.3),
				Color(0.85, 0.72, 0.42), 0.5, 0.03, 0.28))


func _fx_bottomless_quiver() -> void:
	_burst(Vector3(-0.1, 0.9, -0.1), Color(1.0, 0.85, 0.35), 1.2)
	_sparks(Vector3(-0.1, 0.9, -0.1), Color(1.0, 0.85, 0.35), 8, 0.4)


func _fx_rise() -> void:
	_rising_sparks(Color(0.5, 1.0, 0.6), 10)


func _fx_barricade() -> void:
	# Timber planks slam up into a wall out front.
	var wall := Node3D.new()
	wall.position = Vector3(0, 0, 0.9)
	add_child(wall)
	for i in range(3):
		var plank := _box(Vector3((i - 1) * 0.34, 0.45, 0), Vector3(0.3, 0.9, 0.08), Color(0.52, 0.36, 0.2))
		wall.add_child(plank)
	wall.scale = Vector3(1, 0.04, 1)
	var tw := wall.create_tween()
	tw.tween_property(wall, "scale:y", 1.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_dirt.bind(Vector3(0, 0.1, 0.9)))
	tw.tween_interval(0.6)
	tw.tween_property(wall, "scale:y", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(wall.queue_free)


# =============================================================
# EFFECTS — Jeremy (gambler / chaos mage)
# =============================================================

func _fx_communal_donation() -> void:
	# A handful of gold coins tossed out to the crowd.
	for i in range(5):
		var coin := _cyl(Vector3(0.1, 0.8, 0.2), 0.06, 0.06, 0.02, Color(0.95, 0.82, 0.3))
		coin.material_override = _emissive(Color(0.95, 0.82, 0.3), 0.6)
		coin.rotation_degrees = Vector3(90, 0, 0)
		add_child(coin)
		var dest := coin.position + Vector3(randf_range(-0.8, 0.8), randf_range(0.1, 0.5), randf_range(0.8, 1.6))
		var tw := coin.create_tween()
		tw.tween_interval(i * 0.05)
		tw.tween_property(coin, "position", dest, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(coin, "rotation_degrees:x", 90 + 540, 0.4)
		tw.tween_property(coin, "scale", Vector3.ZERO, 0.1)
		tw.tween_callback(coin.queue_free)


func _fx_snowballs_chance() -> void:
	# Breathe fire, then the flurry of snowballs (the chance effect).
	_fire_breath()
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_callback(_fire_breath)
	tw.tween_interval(0.2)
	tw.tween_callback(_snowballs)


func _fx_biscuit() -> void:
	# Toss a biscuit up and catch it in the mouth.
	var b := _box(Vector3(0.28, 0.7, 0.2), Vector3(0.12, 0.05, 0.12), Color(0.82, 0.62, 0.34))
	add_child(b)
	var tw := b.create_tween()
	tw.tween_property(b, "position", Vector3(0.1, 1.55, 0.15), 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(b, "rotation_degrees:y", 360.0, 0.34)
	tw.tween_property(b, "position", Vector3(0.0, 1.05, 0.15), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(b, "scale", Vector3.ZERO, 0.06)
	tw.tween_callback(b.queue_free)


func _fx_cryonics() -> void:
	_sparks(Vector3(0, 0.7, 0.35), Color(0.7, 0.9, 1.0), 6, 0.35)
	var tw := create_tween()
	tw.tween_interval(0.18)
	tw.tween_callback(_icicle.bind(Vector3(0, 0.0, 1.6), 1.4))
	tw.tween_callback(_burst.bind(Vector3(0, 0.7, 1.6), Color(0.7, 0.9, 1.0), 1.4))


func _fx_aura(col: Color) -> void:
	_burst(Vector3(0, 0.7, 0), col, 1.6)
	_sparks(Vector3(0, 0.7, 0), col, 10, 0.6)


func _fx_fireball() -> void:
	# Gather a swelling fireball, then hurl it.
	var orb := _orb(Vector3(0.3, 0.7, 0.25), Color(1.0, 0.5, 0.1), 0.05)
	add_child(orb)
	var tw := orb.create_tween()
	tw.tween_property(orb, "scale", Vector3.ONE * 3.2, 0.25).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(orb.queue_free)
	tw.tween_callback(_fly_orb.bind(Vector3(0.3, 0.7, 0.3), Vector3(-0.3, 0, 2.2), Color(1.0, 0.45, 0.1), 0.17, 0.4))


func _fx_god_of_thunder() -> void:
	# Sparks drawn in, then a massive bolt on the target.
	for i in range(8):
		var sp := _icon(_sparkle_tex(), Color(0.7, 0.85, 1.0), 0.004)
		var start := Vector3(randf_range(-0.4, 0.4), randf_range(0.4, 1.0), randf_range(1.4, 2.0))
		sp.position = start
		add_child(sp)
		var tw := sp.create_tween()
		tw.tween_interval(i * 0.02)
		tw.tween_property(sp, "scale", Vector3.ONE * 0.7, 0.05)
		tw.tween_property(sp, "position", Vector3(0, 0.8, 0.1), 0.22).set_ease(Tween.EASE_IN)
		tw.tween_property(sp, "scale", Vector3.ZERO, 0.06)
		tw.tween_callback(sp.queue_free)
	var tw2 := create_tween()
	tw2.tween_interval(0.45)
	tw2.tween_callback(_bolt.bind(Vector3(0.1, 2.6, 1.7), Vector3(-0.1, 0.1, 1.7), Color(0.8, 0.9, 1.0)))
	tw2.tween_callback(_burst.bind(Vector3(0, 0.2, 1.7), Color(0.8, 0.9, 1.0), 1.6))


func _fx_orbiting_orb(col: Color) -> void:
	# An orb that circles the figure on a spinning pivot, rising, then fades.
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 0.55, 0)
	add_child(pivot)
	var orb := _orb(Vector3(0.55, 0, 0), col, 0.09)
	pivot.add_child(orb)
	var tw := pivot.create_tween()
	tw.tween_property(pivot, "rotation_degrees:y", 720.0, 1.0).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(pivot, "position:y", 0.85, 1.0)
	tw.tween_property(orb, "scale", Vector3.ZERO, 0.12)
	tw.tween_callback(pivot.queue_free)


func _fx_punt_pig() -> void:
	# A pink winged pig sails forward and bursts.
	var pig := Node3D.new()
	pig.position = Vector3(0.1, 0.45, 0.4)
	add_child(pig)
	var body := _sphere(Vector3.ZERO, 0.12, Color(0.95, 0.65, 0.72))
	body.scale = Vector3(1.2, 0.9, 1.0)
	pig.add_child(body)
	pig.add_child(_sphere(Vector3(0, 0.02, 0.13), 0.05, Color(0.98, 0.72, 0.78)))  # snout
	pig.add_child(_box(Vector3(-0.12, 0.06, 0), Vector3(0.02, 0.14, 0.16), Color(0.98, 0.98, 1.0)))
	pig.add_child(_box(Vector3(0.12, 0.06, 0), Vector3(0.02, 0.14, 0.16), Color(0.98, 0.98, 1.0)))
	var dest := pig.position + Vector3(0, 0.2, 2.2)
	var tw := pig.create_tween()
	tw.tween_interval(0.16)  # kick wind-up
	tw.tween_property(pig, "position", dest, 0.4).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(pig, "rotation_degrees:y", 540.0, 0.4)
	tw.tween_callback(_burst.bind(dest, Color(1.0, 0.6, 0.3), 1.4))
	tw.tween_property(pig, "scale", Vector3.ZERO, 0.08)
	tw.tween_callback(pig.queue_free)


func _fx_ring_sweep(col: Color) -> void:
	# A ring sweeps up around the figure as the barrier forms, then pops.
	var ring := _torus(Vector3(0, 0.1, 0), 0.34, 0.46, col)
	ring.material_override = _emissive(col, 1.5)
	add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "position:y", 1.4, 0.5).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(ring, "scale", Vector3(0.6, 1, 0.6), 0.5)
	tw.tween_property(ring, "scale", Vector3.ZERO, 0.1)
	tw.tween_callback(ring.queue_free)


func _fx_mana_surge() -> void:
	_sparks(Vector3(0, 0.08, 0.05), Color(0.3, 0.6, 1.0), 8, 0.3)
	var orb := _orb(Vector3(0, 0.1, 0.1), Color(0.4, 0.7, 1.0), 0.07)
	add_child(orb)
	var tw := orb.create_tween()
	tw.tween_property(orb, "position:y", 0.95, 0.25).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(orb.queue_free)
	tw.tween_callback(_fly_orb.bind(Vector3(0.0, 0.8, 0.3), Vector3(0, 0, 2.0), Color(0.4, 0.7, 1.0), 0.12, 0.34))


func _fx_mirror() -> void:
	# A small hand mirror held up, glinting.
	var mirror := Node3D.new()
	mirror.position = Vector3(0.3, 1.05, 0.25)
	add_child(mirror)
	mirror.add_child(_box(Vector3.ZERO, Vector3(0.18, 0.24, 0.03), Color(0.85, 0.7, 0.2)))
	var glass := _box(Vector3(0, 0, 0.02), Vector3(0.13, 0.18, 0.02), Color(0.7, 0.85, 0.95))
	glass.material_override = _emissive(Color(0.7, 0.85, 0.95), 0.6)
	mirror.add_child(glass)
	mirror.add_child(_box(Vector3(0, -0.2, 0), Vector3(0.04, 0.16, 0.03), Color(0.85, 0.7, 0.2)))
	mirror.scale = Vector3.ZERO
	var tw := mirror.create_tween()
	tw.tween_property(mirror, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_sparks.bind(Vector3(0.3, 1.15, 0.3), Color(1, 1, 1), 3, 0.2))
	tw.tween_interval(0.55)
	tw.tween_property(mirror, "scale", Vector3.ZERO, 0.12)
	tw.tween_callback(mirror.queue_free)


func _fx_risk_it() -> void:
	# A gold coin flicked up, spinning.
	var coin := _cyl(Vector3(0.28, 0.7, 0.2), 0.08, 0.08, 0.02, Color(0.95, 0.82, 0.3))
	coin.material_override = _emissive(Color(0.95, 0.82, 0.3), 0.5)
	coin.rotation_degrees = Vector3(90, 0, 0)
	add_child(coin)
	var top := coin.position + Vector3(0, 1.0, 0)
	var tw := coin.create_tween()
	tw.tween_property(coin, "position:y", top.y, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(coin, "rotation_degrees:x", 90 + 720, 0.4)
	tw.tween_callback(_burst.bind(top, Color(1.0, 0.9, 0.4), 0.8))
	tw.tween_property(coin, "scale", Vector3.ZERO, 0.1)
	tw.tween_callback(coin.queue_free)


func _fx_sheep() -> void:
	# A little sheep pops in over the head and drifts away.
	var sheep := Node3D.new()
	sheep.position = Vector3(0, 1.5, 0)
	add_child(sheep)
	var wool := _sphere(Vector3.ZERO, 0.12, Color(0.95, 0.95, 0.92))
	wool.scale = Vector3(1.3, 1.0, 1.0)
	sheep.add_child(wool)
	sheep.add_child(_sphere(Vector3(0.15, 0.0, 0), 0.06, Color(0.25, 0.22, 0.24)))  # head
	for leg_x in [-0.07, 0.07]:
		sheep.add_child(_box(Vector3(leg_x, -0.13, 0), Vector3(0.03, 0.08, 0.03), Color(0.25, 0.22, 0.24)))
	sheep.scale = Vector3.ZERO
	var tw := sheep.create_tween()
	tw.tween_property(sheep, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.4)
	tw.tween_property(sheep, "position:y", 1.85, 0.6)
	tw.parallel().tween_property(sheep, "scale", Vector3.ZERO, 0.6)
	tw.tween_callback(sheep.queue_free)


func _fx_spark() -> void:
	_bolt(Vector3(0.1, 0.9, 0.3), Vector3(0.0, 0.6, 1.6), Color(0.7, 0.9, 1.0))
	_sparks(Vector3(0.1, 0.7, 0.4), Color(0.7, 0.9, 1.0), 8, 0.6)
	_burst(Vector3(0.1, 0.7, 0.4), Color(0.7, 0.9, 1.0), 0.7)


func _fx_surrounding_ice() -> void:
	# A ring of ice spikes erupts around the figure (gaps = the miss chance).
	var ring := [Vector3(0.9, 0, 0.5), Vector3(-0.9, 0, 0.5), Vector3(0.7, 0, 1.2), Vector3(-0.7, 0, 1.2), Vector3(0, 0, 1.5)]
	for pos in ring:
		if randf() < 0.2:
			continue
		_icicle(pos, randf_range(0.6, 0.95))
	_burst(Vector3(0, 0.1, 0.0), Color(0.7, 0.9, 1.0), 1.0)


func _fx_trick_shot() -> void:
	# An orb that swerves on its way to the target.
	var orb := _orb(Vector3(0.2, 0.7, 0.3), Color(0.95, 0.6, 1.0), 0.1)
	add_child(orb)
	var tw := orb.create_tween()
	tw.tween_property(orb, "position", Vector3(0.9, 1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(orb, "position", Vector3(-0.2, 0.6, 2.2), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_burst.bind(Vector3(-0.2, 0.6, 2.2), Color(0.95, 0.6, 1.0), 1.1))
	tw.tween_property(orb, "scale", Vector3.ZERO, 0.08)
	tw.tween_callback(orb.queue_free)


func _fx_vengeful_shield() -> void:
	# A grey skull bursts from the chest and flies at the enemy.
	var skull := Node3D.new()
	skull.position = Vector3(0, 0.7, 0.2)
	add_child(skull)
	var cranium := _sphere(Vector3.ZERO, 0.09, Color(0.82, 0.82, 0.86))
	skull.add_child(cranium)
	skull.add_child(_box(Vector3(0, -0.08, 0.02), Vector3(0.1, 0.06, 0.08), Color(0.82, 0.82, 0.86)))  # jaw
	for eye_x in [-0.035, 0.035]:
		skull.add_child(_box(Vector3(eye_x, 0.01, 0.08), Vector3(0.03, 0.035, 0.03), Color(0.1, 0.1, 0.12)))
	skull.scale = Vector3.ZERO
	var dest := skull.position + Vector3(0, 0.1, 2.0)
	var tw := skull.create_tween()
	tw.tween_property(skull, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(skull, "position", dest, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_burst.bind(dest, Color(0.85, 0.85, 0.9), 1.0))
	tw.tween_property(skull, "scale", Vector3.ZERO, 0.08)
	tw.tween_callback(skull.queue_free)


func _fx_worms_armageddon() -> void:
	# A flaming meteor falls on the target; the worm bursts from the crater.
	var meteor := _orb(Vector3(0.4, 3.2, 1.8), Color(1.0, 0.45, 0.12), 0.3)
	add_child(meteor)
	var impact := Vector3(0.0, 0.2, 1.7)
	var tw := meteor.create_tween()
	tw.tween_property(meteor, "position", impact, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_burst.bind(impact, Color(1.0, 0.5, 0.15), 2.4))
	tw.tween_callback(_dirt.bind(Vector3(0, 0.15, 1.7)))
	tw.tween_property(meteor, "scale", Vector3.ZERO, 0.1)
	tw.tween_callback(meteor.queue_free)
	# The Alaskan Bull Worm rears out of the crater.
	var anchor := Node3D.new()
	anchor.position = Vector3(0.0, 0.0, 1.6)
	add_child(anchor)
	var worm := _cyl(Vector3(0, 0.35, 0), 0.12, 0.16, 0.7, Color(0.7, 0.4, 0.45))
	worm.rotation_degrees = Vector3(16, 0, 0)
	anchor.add_child(worm)
	anchor.scale = Vector3(1, 0.05, 1)
	var tw2 := anchor.create_tween()
	tw2.tween_interval(0.6)
	tw2.tween_property(anchor, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.tween_interval(0.4)
	tw2.tween_property(anchor, "scale", Vector3(0.6, 0.05, 0.6), 0.2)
	tw2.tween_callback(anchor.queue_free)


func _fx_deep_pockets() -> void:
	_sparks(Vector3(0, 0.6, 0.3), Color(1.0, 0.85, 0.3), 6, 0.35)


func _fx_hearts() -> void:
	# A few hearts drift up between open arms.
	for i in range(3):
		var heart := Node3D.new()
		heart.position = Vector3(randf_range(-0.3, 0.3), 0.9, 0.2)
		add_child(heart)
		for lobe_x in [-0.035, 0.035]:
			heart.add_child(_sphere(Vector3(lobe_x, 0.02, 0), 0.05, Color(1.0, 0.4, 0.5)))
		var point := _box(Vector3(0, -0.045, 0), Vector3(0.1, 0.08, 0.06), Color(1.0, 0.4, 0.5))
		point.rotation_degrees = Vector3(0, 0, 45)
		heart.add_child(point)
		heart.scale = Vector3.ZERO
		var tw := heart.create_tween()
		tw.tween_interval(i * 0.08)
		tw.tween_property(heart, "scale", Vector3.ONE * 0.8, 0.14).set_trans(Tween.TRANS_BACK)
		tw.parallel().tween_property(heart, "position:y", 1.5, 0.6)
		tw.tween_property(heart, "scale", Vector3.ZERO, 0.12)
		tw.tween_callback(heart.queue_free)


func _fx_dice() -> void:
	# A pair of dice tumbling out ahead.
	for i in range(2):
		var die := _box(Vector3(0.1 - i * 0.2, 0.7, 0.2), Vector3(0.11, 0.11, 0.11), Color(0.95, 0.95, 0.98))
		add_child(die)
		var dest := Vector3(randf_range(-0.3, 0.3), 0.08, randf_range(1.0, 1.5))
		var tw := die.create_tween()
		tw.tween_interval(i * 0.06)
		tw.tween_property(die, "position", dest, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(die, "rotation_degrees", Vector3(randf_range(360, 720), randf_range(180, 540), 0), 0.4)
		tw.tween_interval(0.35)
		tw.tween_property(die, "scale", Vector3.ZERO, 0.1)
		tw.tween_callback(die.queue_free)


func _fx_disco() -> void:
	# Party lights orbiting the figure.
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 0.9, 0)
	add_child(pivot)
	var cols := [Color(1, 0.3, 0.4), Color(0.3, 0.8, 1.0), Color(1.0, 0.9, 0.3), Color(0.5, 1.0, 0.5)]
	for i in range(cols.size()):
		var ang := TAU * i / cols.size()
		pivot.add_child(_orb(Vector3(cos(ang) * 0.5, 0, sin(ang) * 0.5), cols[i], 0.06))
	var tw := pivot.create_tween()
	tw.tween_property(pivot, "rotation_degrees:y", 900.0, 1.2).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(pivot, "scale", Vector3.ONE * 0.2, 1.2).set_delay(0.0)
	tw.tween_callback(pivot.queue_free)


# =============================================================
# EFFECTS — Ryan / Cory (rogue & apothecary)
# =============================================================

func _fx_essence_motes(col: Color, inward: bool) -> void:
	# Motes streaming in from the target (or out, if inward is false).
	for i in range(8):
		var sp := _icon(_sparkle_tex(), col, 0.005)
		var far := Vector3(randf_range(-0.5, 0.5), randf_range(0.3, 1.1), randf_range(1.3, 2.1))
		var near := Vector3(0, 0.8, 0.15)
		sp.position = far if inward else near
		add_child(sp)
		var tw := sp.create_tween()
		tw.tween_interval(i * 0.04)
		tw.tween_property(sp, "scale", Vector3.ONE * 0.7, 0.08)
		tw.tween_property(sp, "position", near if inward else far, 0.32).set_ease(Tween.EASE_IN)
		tw.tween_property(sp, "scale", Vector3.ZERO, 0.08)
		tw.tween_callback(sp.queue_free)


func _fx_vines() -> void:
	# A ring of green vines erupting from the ground ahead.
	var p := Node3D.new()
	p.position = Vector3(0, 0, 1.0)
	add_child(p)
	var vine := Color(0.32, 0.62, 0.28)
	var vine2 := Color(0.45, 0.8, 0.38)
	for i in range(6):
		var ang := deg_to_rad(i * 60.0)
		var c: Color = vine if i % 2 == 0 else vine2
		var stalk := _cyl(Vector3(cos(ang) * 0.3, 0.2, sin(ang) * 0.3), 0.015, 0.035, 0.44, c)
		stalk.rotation_degrees = Vector3(14.0 * sin(ang), 0, -14.0 * cos(ang))
		p.add_child(stalk)
		var tip := _sphere(Vector3(cos(ang) * 0.24, 0.44, sin(ang) * 0.24), 0.045, vine2)
		tip.scale = Vector3(1.4, 0.7, 1.4)
		p.add_child(tip)
	p.scale = Vector3(1, 0.05, 1)
	var tw := p.create_tween()
	tw.tween_property(p, "scale:y", 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_property(p, "scale:y", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(p.queue_free)


func _fx_choke() -> void:
	# A dark grip closing on the target's throat.
	var grip := _orb(Vector3(0, 0.9, 1.6), Color(0.4, 0.25, 0.5), 0.14)
	grip.scale = Vector3.ZERO
	add_child(grip)
	var tw := grip.create_tween()
	tw.tween_property(grip, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(grip, "scale", Vector3(1.3, 0.5, 1.3), 0.3).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_sparks.bind(Vector3(0, 0.9, 1.6), Color(0.6, 0.4, 0.75), 5, 0.3))
	tw.tween_property(grip, "scale", Vector3.ZERO, 0.12)
	tw.tween_callback(grip.queue_free)


func _fx_energy_ball() -> void:
	var orb := _orb(Vector3(0.15, 0.75, 0.3), Color(0.4, 0.75, 1.0), 0.06)
	add_child(orb)
	var tw := orb.create_tween()
	tw.tween_property(orb, "scale", Vector3.ONE * 2.6, 0.22).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(orb.queue_free)
	tw.tween_callback(_fly_orb.bind(Vector3(0.15, 0.75, 0.35), Vector3(-0.15, 0, 2.1), Color(0.4, 0.75, 1.0), 0.14, 0.36))


func _fx_exposed_artery() -> void:
	# A precise cut and a spray of red at the target.
	var tw := create_tween()
	tw.tween_interval(0.2)
	tw.tween_callback(_burst.bind(Vector3(0, 0.8, 1.5), Color(0.9, 0.15, 0.2), 1.0))
	tw.tween_callback(_sparks.bind(Vector3(0, 0.8, 1.5), Color(0.85, 0.1, 0.15), 7, 0.45))


func _fx_meditate() -> void:
	_rising_sparks(Color(0.7, 0.9, 1.0), 6)
	_fx_ring_sweep(Color(0.6, 0.8, 1.0))


func _fx_misery() -> void:
	# A dark link arcing between self and the target — shared suffering.
	_bolt(Vector3(0, 0.8, 0.2), Vector3(0, 0.8, 1.8), Color(0.6, 0.35, 0.75))
	_burst(Vector3(0, 0.8, 1.8), Color(0.6, 0.35, 0.75), 0.9)
	_burst(Vector3(0, 0.8, 0.2), Color(0.6, 0.35, 0.75), 0.9)


func _fx_potion(col: Color) -> void:
	# Tip back a beaker; droplets and a fizz of the brew's colour.
	var beaker := Node3D.new()
	beaker.position = Vector3(0.22, 0.95, 0.2)
	add_child(beaker)
	var glass := _cyl(Vector3.ZERO, 0.05, 0.07, 0.16, Color(0.85, 0.92, 0.95, 0.8))
	beaker.add_child(glass)
	var brew := _cyl(Vector3(0, -0.03, 0), 0.045, 0.06, 0.08, col)
	brew.material_override = _emissive(col, 0.8)
	beaker.add_child(brew)
	var tw := beaker.create_tween()
	tw.tween_property(beaker, "rotation_degrees:x", -60.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_sparks.bind(Vector3(0.2, 1.15, 0.25), col, 5, 0.25))
	tw.tween_interval(0.3)
	tw.tween_property(beaker, "scale", Vector3.ZERO, 0.12)
	tw.tween_callback(beaker.queue_free)


func _fx_push() -> void:
	var tw := create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(_burst.bind(Vector3(0, 0.7, 1.0), Color(1, 1, 1), 1.3))
	tw.tween_callback(_sparks.bind(Vector3(0, 0.7, 1.2), Color(0.9, 0.9, 1.0), 6, 0.5))


func _fx_release_tension() -> void:
	# A long exhale drifting away.
	_puffs(Vector3(0, 0.95, 0.25), Color(0.8, 0.85, 0.9), 6, 0.4)


func _fx_sweep_arc() -> void:
	# A wide low arc — the disarming sweep.
	var tw := create_tween()
	tw.tween_interval(0.18)
	tw.tween_callback(_burst.bind(Vector3(-0.5, 0.35, 1.0), Color(1, 1, 1), 0.8))
	tw.tween_callback(_burst.bind(Vector3(0.0, 0.35, 1.2), Color(1, 1, 1), 0.9))
	tw.tween_callback(_burst.bind(Vector3(0.5, 0.35, 1.0), Color(1, 1, 1), 0.8))


func _fx_anticipation() -> void:
	_voice("!", Color(1.0, 0.9, 0.4))
	_sparks(Vector3(0, 0.6, 0.0), Color(0.9, 0.85, 0.5), 6, 0.3)


func _fx_item_mastery() -> void:
	# The toolkit orbits overhead: bottle, blade, pouch.
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 1.45, 0)
	add_child(pivot)
	pivot.add_child(_cyl(Vector3(0.4, 0, 0), 0.04, 0.05, 0.12, Color(0.5, 0.85, 0.6)))
	pivot.add_child(_box(Vector3(-0.2, 0, 0.35), Vector3(0.04, 0.16, 0.02), Color(0.8, 0.85, 0.92)))
	pivot.add_child(_sphere(Vector3(-0.2, 0, -0.35), 0.06, Color(0.6, 0.45, 0.3)))
	pivot.scale = Vector3.ZERO
	var tw := pivot.create_tween()
	tw.tween_property(pivot, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pivot, "rotation_degrees:y", 540.0, 0.9)
	tw.tween_property(pivot, "scale", Vector3.ZERO, 0.14)
	tw.tween_callback(pivot.queue_free)


func _fx_blade_barrage() -> void:
	for i in range(4):
		var tw := create_tween()
		tw.tween_interval(i * 0.08)
		tw.tween_callback(_throw_dagger.bind(Vector3(randf_range(-0.15, 0.15), 0.85, 0.2),
				Vector3(randf_range(-0.4, 0.4), randf_range(-0.15, 0.1), 2.4)))


func _fx_adrenaline() -> void:
	_syringe_jab(Color(0.95, 0.4, 0.35))
	_rising_sparks(Color(1.0, 0.5, 0.4), 6)


func _fx_poisoned_blood() -> void:
	# Sickly green drips falling from the forearm.
	for i in range(4):
		var drop := _sphere(Vector3(0.25, 0.75, 0.2), 0.035, Color(0.45, 0.85, 0.3))
		drop.material_override = _emissive(Color(0.45, 0.85, 0.3), 0.8)
		add_child(drop)
		var tw := drop.create_tween()
		tw.tween_interval(i * 0.12)
		tw.tween_property(drop, "position:y", 0.05, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(drop, "scale", Vector3(1.6, 0.2, 1.6), 0.08)
		tw.tween_property(drop, "scale", Vector3.ZERO, 0.08)
		tw.tween_callback(drop.queue_free)
	_burst(Vector3(0.25, 0.7, 0.2), Color(0.45, 0.85, 0.3), 0.7)


func _fx_exacerbate() -> void:
	var tw := create_tween()
	tw.tween_interval(0.14)
	tw.tween_callback(_burst.bind(Vector3(0, 0.75, 1.4), Color(0.9, 0.2, 0.25), 1.2))
	tw.tween_callback(_sparks.bind(Vector3(0, 0.75, 1.4), Color(0.9, 0.2, 0.25), 8, 0.5))


func _fx_spit() -> void:
	# An arcing glob of spit at the target.
	for i in range(3):
		var glob := _sphere(Vector3(0.0, 0.95, 0.25), 0.03, Color(0.7, 0.85, 0.6))
		add_child(glob)
		var dest := Vector3(randf_range(-0.2, 0.2), 0.4, randf_range(1.4, 1.9))
		var tw := glob.create_tween()
		tw.tween_interval(0.2 + i * 0.05)
		tw.tween_property(glob, "position", glob.position + Vector3(0, 0.3, 0.5), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(glob, "position", dest, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(glob, "scale", Vector3.ZERO, 0.08)
		tw.tween_callback(glob.queue_free)


func _fx_lethal_recall() -> void:
	# The thrown dagger flies back INTO the hand.
	var dagger := _dagger_node()
	dagger.position = Vector3(0, 0.7, 2.4)
	add_child(dagger)
	var tw := dagger.create_tween()
	tw.tween_property(dagger, "position", Vector3(0.2, 0.85, 0.2), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(dagger, "rotation_degrees:x", -900.0, 0.3)
	tw.tween_callback(_sparks.bind(Vector3(0.2, 0.85, 0.2), Color(0.8, 0.88, 0.95), 4, 0.25))
	tw.tween_property(dagger, "scale", Vector3.ZERO, 0.08)
	tw.tween_callback(dagger.queue_free)


func _fx_patience() -> void:
	# A slow, steady pulse — waiting for the moment.
	var ring := _torus(Vector3(0, 0.7, 0), 0.3, 0.4, Color(0.85, 0.8, 0.6))
	ring.material_override = _emissive(Color(0.85, 0.8, 0.6), 0.8)
	add_child(ring)
	var tw := ring.create_tween()
	for i in range(2):
		tw.tween_property(ring, "scale", Vector3.ONE * 1.25, 0.4).set_trans(Tween.TRANS_SINE)
		tw.tween_property(ring, "scale", Vector3.ONE * 0.9, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ring, "scale", Vector3.ZERO, 0.15)
	tw.tween_callback(ring.queue_free)


func _fx_shadows() -> void:
	_voice("Toodles!", Color(0.7, 0.7, 0.85))
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_callback(_puffs.bind(Vector3(0.0, 0.6, 0.05), Color(0.32, 0.3, 0.4), 12, 0.45))


func _fx_shuriken() -> void:
	# A spinning star loosed at the target.
	var star := _icon(_shuriken_tex(), Color.WHITE, 0.01)
	star.scale = Vector3.ONE
	star.position = Vector3(0.2, 0.85, 0.25)
	add_child(star)
	var tw := star.create_tween()
	tw.tween_property(star, "position", Vector3(0, 0.75, 2.6), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(star, "rotation_degrees:y", 1080.0, 0.3)
	tw.tween_callback(star.queue_free)


func _fx_dagger_throw() -> void:
	_throw_dagger(Vector3(0.2, 0.85, 0.2), Vector3(0, 0.7, 2.6) - Vector3(0.2, 0.85, 0.2))


func _fx_thrown_stone() -> void:
	# A rock lobbed in a shallow arc.
	var stone := _sphere(Vector3(0.2, 0.85, 0.2), 0.07, Color(0.5, 0.47, 0.42))
	stone.scale = Vector3(1.0, 0.85, 1.1)
	add_child(stone)
	var tw := stone.create_tween()
	tw.tween_property(stone, "position", Vector3(0.1, 1.1, 1.2), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(stone, "position", Vector3(0, 0.5, 2.6), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(stone, "rotation_degrees:x", 540.0, 0.2)
	tw.tween_callback(stone.queue_free)


func _fx_shuriken_pouch() -> void:
	# Toss a pouch up, catch it at the waist.
	var pouch := _sphere(Vector3(0.2, 0.8, 0.2), 0.08, Color(0.5, 0.38, 0.25))
	pouch.scale = Vector3(1.0, 1.15, 1.0)
	add_child(pouch)
	var tw := pouch.create_tween()
	tw.tween_property(pouch, "position:y", 1.5, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(pouch, "position:y", 0.55, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_sparks.bind(Vector3(0.2, 0.55, 0.2), Color(0.85, 0.75, 0.5), 4, 0.2))
	tw.tween_property(pouch, "scale", Vector3.ZERO, 0.1)
	tw.tween_callback(pouch.queue_free)


func _fx_volatile_mixture() -> void:
	# Shake a beaker, hurl it, and it detonates in a riot of colour.
	var flask := _cyl(Vector3(0.22, 0.8, 0.2), 0.04, 0.08, 0.14, Color(0.75, 0.9, 0.75, 0.85))
	add_child(flask)
	var dest := Vector3(0, 0.4, 1.8)
	var tw := flask.create_tween()
	tw.tween_property(flask, "rotation_degrees:z", 25.0, 0.08)
	tw.tween_property(flask, "rotation_degrees:z", -25.0, 0.08)
	tw.tween_property(flask, "rotation_degrees:z", 0.0, 0.08)
	tw.tween_property(flask, "position", dest, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_burst.bind(dest, Color(0.5, 1.0, 0.5), 1.6))
	tw.tween_callback(_burst.bind(dest + Vector3(0.2, 0.15, 0), Color(1.0, 0.6, 0.9), 1.2))
	tw.tween_callback(_sparks.bind(dest, Color(0.8, 1.0, 0.5), 10, 0.7))
	tw.tween_property(flask, "scale", Vector3.ZERO, 0.08)
	tw.tween_callback(flask.queue_free)


# =============================================================
# EFFECTS — systemic
# =============================================================

func _fx_level_up() -> void:
	_burst(Vector3(0, 0.7, 0), Color(1.0, 0.9, 0.4), 1.5)
	_rising_sparks(Color(1.0, 0.9, 0.4), 10)


# =============================================================
# SHARED EFFECT PIECES
# =============================================================

func _fire_breath() -> void:
	for i in range(6):
		var sp := _icon(_puff_tex(), Color(1.0, randf_range(0.4, 0.7), 0.1), 0.006)
		sp.position = Vector3(0, 0.95, 0.25)
		sp.scale = Vector3.ONE * randf_range(0.3, 0.6)
		add_child(sp)
		var dest := sp.position + Vector3(randf_range(-0.2, 0.2), randf_range(-0.15, 0.1), randf_range(0.6, 1.2))
		var tw := sp.create_tween()
		tw.tween_property(sp, "position", dest, 0.35).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sp, "scale", Vector3.ONE * randf_range(0.8, 1.3), 0.35)
		tw.parallel().tween_property(sp, "modulate:a", 0.0, 0.35)
		tw.tween_callback(sp.queue_free)


func _snowballs() -> void:
	for i in range(4):
		_fly_orb(Vector3(randf_range(-0.2, 0.2), 0.7, 0.3),
				Vector3(randf_range(-0.4, 0.4), randf_range(-0.1, 0.2), randf_range(1.4, 2.0)),
				Color(0.92, 0.96, 1.0), 0.08, 0.35)


func _syringe_jab(fluid: Color) -> void:
	# A quick syringe to the arm.
	var syringe := Node3D.new()
	syringe.position = Vector3(0.4, 1.0, 0.15)
	syringe.rotation_degrees = Vector3(0, 0, -50)
	add_child(syringe)
	syringe.add_child(_cyl(Vector3.ZERO, 0.035, 0.035, 0.14, Color(0.9, 0.95, 1.0, 0.85)))
	var plunger := _cyl(Vector3(0, 0.09, 0), 0.02, 0.02, 0.06, Color(0.7, 0.7, 0.78))
	syringe.add_child(plunger)
	var fluid_core := _cyl(Vector3(0, -0.01, 0), 0.025, 0.025, 0.09, fluid)
	fluid_core.material_override = _emissive(fluid, 0.8)
	syringe.add_child(fluid_core)
	syringe.add_child(_cyl(Vector3(0, -0.11, 0), 0.004, 0.004, 0.08, Color(0.8, 0.85, 0.9)))
	var tw := syringe.create_tween()
	tw.tween_property(syringe, "position", Vector3(0.26, 0.85, 0.15), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_sparks.bind(Vector3(0.25, 0.85, 0.2), fluid, 4, 0.2))
	tw.tween_interval(0.25)
	tw.tween_property(syringe, "scale", Vector3.ZERO, 0.1)
	tw.tween_callback(syringe.queue_free)


func _rain_arrows(count: int, at_z: float) -> void:
	for i in range(count):
		var x := randf_range(-0.5, 0.5)
		var z := at_z + randf_range(-0.4, 0.4)
		_arrow(Vector3(x, 2.6, z + 0.3), Vector3(0, -2.4, -0.3), Color(0.85, 0.72, 0.42), 0.5, 0.03, 0.28)


func _throw_dagger(start: Vector3, travel: Vector3) -> void:
	var dagger := _dagger_node()
	dagger.position = start
	add_child(dagger)
	var tw := dagger.create_tween()
	tw.tween_property(dagger, "position", start + travel, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(dagger, "rotation_degrees:x", 1080.0, 0.32)
	tw.tween_callback(dagger.queue_free)


func _dagger_node() -> Node3D:
	var dagger := Node3D.new()
	dagger.add_child(_box(Vector3(0, 0.09, 0), Vector3(0.04, 0.16, 0.015), Color(0.8, 0.88, 0.95)))
	dagger.add_child(_box(Vector3(0, 0.0, 0), Vector3(0.09, 0.02, 0.03), Color(0.2, 0.18, 0.24)))
	dagger.add_child(_box(Vector3(0, -0.05, 0), Vector3(0.03, 0.08, 0.03), Color(0.14, 0.12, 0.17)))
	return dagger


func _rising_sparks(col: Color, count: int) -> void:
	for i in range(count):
		var sp := _icon(_sparkle_tex(), col, 0.004)
		sp.position = Vector3(randf_range(-0.35, 0.35), randf_range(0.1, 0.5), randf_range(-0.15, 0.25))
		add_child(sp)
		var tw := sp.create_tween()
		tw.tween_interval(i * 0.05)
		tw.tween_property(sp, "scale", Vector3.ONE * 0.7, 0.1).set_trans(Tween.TRANS_BACK)
		tw.parallel().tween_property(sp, "position:y", sp.position.y + 1.0, 0.55).set_ease(Tween.EASE_OUT)
		tw.tween_property(sp, "scale", Vector3.ZERO, 0.1)
		tw.tween_callback(sp.queue_free)


# =============================================================
# PRIMITIVES (ported from CharacterFigure's effect kit)
# =============================================================

func _burst(pos: Vector3, color: Color, burst_scale: float = 1.0) -> void:
	var sp := _icon(_burst_tex(), color, 0.011)
	sp.position = pos
	add_child(sp)
	var tw := sp.create_tween()
	tw.tween_property(sp, "scale", Vector3.ONE * burst_scale, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sp, "modulate:a", 0.0, 0.28)
	tw.tween_callback(sp.queue_free)


func _sparks(pos: Vector3, color: Color, count: int = 6, reach: float = 0.4) -> void:
	for i in range(count):
		var sp := _icon(_sparkle_tex(), color, 0.004)
		sp.position = pos
		add_child(sp)
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-0.2, 1)).normalized() * reach
		var tw := sp.create_tween()
		tw.tween_property(sp, "scale", Vector3.ONE * randf_range(0.5, 0.9), 0.08).set_trans(Tween.TRANS_BACK)
		tw.parallel().tween_property(sp, "position", pos + dir, 0.3).set_ease(Tween.EASE_OUT)
		tw.tween_property(sp, "scale", Vector3.ZERO, 0.1)
		tw.tween_callback(sp.queue_free)


func _bolt(from_local: Vector3, to_local: Vector3, color: Color = Color(0.7, 0.85, 1.0)) -> void:
	var bolt := Node3D.new()
	add_child(bolt)
	var segs := 5
	var prev := from_local
	for i in range(1, segs + 1):
		var t := float(i) / float(segs)
		var point := from_local.lerp(to_local, t)
		if i < segs:
			point += Vector3(randf_range(-0.12, 0.12), randf_range(-0.12, 0.12), randf_range(-0.08, 0.08))
		var seg := _box(Vector3.ZERO, Vector3(0.05, 0.05, prev.distance_to(point)), color)
		seg.material_override = _emissive(color, 3.0)
		_orient_along(seg, point - prev)
		seg.position = (prev + point) * 0.5
		bolt.add_child(seg)
		prev = point
	var tw := bolt.create_tween()
	tw.tween_interval(0.14)
	tw.tween_property(bolt, "scale", Vector3(1, 1, 0.01), 0.1)
	tw.tween_callback(bolt.queue_free)


func _icicle(base_pos: Vector3, height: float = 0.7) -> void:
	var anchor := Node3D.new()
	anchor.position = base_pos
	add_child(anchor)
	var ice := _cyl(Vector3(0, height * 0.5, 0), 0.0, 0.12, height, Color(0.72, 0.9, 1.0))
	ice.material_override = _emissive(Color(0.6, 0.85, 1.0), 0.5)
	anchor.add_child(ice)
	anchor.scale = Vector3(1, 0.04, 1)
	var tw := anchor.create_tween()
	tw.tween_property(anchor, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(anchor, "scale", Vector3(0.5, 0.02, 0.5), 0.2)
	tw.tween_callback(anchor.queue_free)


func _fly_orb(start: Vector3, travel: Vector3, color: Color, radius: float, dur: float = 0.4) -> void:
	var orb := _orb(start, color, radius)
	add_child(orb)
	var dest := start + travel
	var tw := orb.create_tween()
	tw.tween_property(orb, "position", dest, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_burst.bind(dest, color, radius * 3.0))
	tw.tween_property(orb, "scale", Vector3.ZERO, 0.08)
	tw.tween_callback(orb.queue_free)


func _arrow(start: Vector3, travel: Vector3, color: Color = Color(0.85, 0.72, 0.42),
		length: float = 0.5, thick: float = 0.03, dur: float = 0.3) -> void:
	var shaft := _box(Vector3.ZERO, Vector3(thick, thick, length), color)
	var head := _box(Vector3(0, 0, length * 0.5 + 0.03), Vector3(thick * 1.6, thick * 1.6, 0.06), Color(0.75, 0.78, 0.85))
	shaft.add_child(head)
	shaft.position = start
	_orient_along(shaft, travel)
	add_child(shaft)
	var tw := shaft.create_tween()
	tw.tween_property(shaft, "position", start + travel, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(shaft, "scale", Vector3.ZERO, 0.06)
	tw.tween_callback(shaft.queue_free)


func _puffs(pos: Vector3, color: Color, count: int = 8, spread: float = 0.4) -> void:
	for i in range(count):
		var sp := _icon(_puff_tex(), color, 0.008)
		sp.position = pos + Vector3(randf_range(-spread, spread) * 0.5, randf_range(-0.1, 0.1), randf_range(-spread, spread) * 0.5)
		sp.scale = Vector3.ONE * randf_range(0.4, 0.8)
		add_child(sp)
		var tw := sp.create_tween()
		tw.tween_property(sp, "position", sp.position + Vector3(randf_range(-spread, spread), randf_range(0.2, 0.55), randf_range(-spread, spread)), 0.4).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sp, "scale", Vector3.ONE * randf_range(0.9, 1.3), 0.4)
		tw.parallel().tween_property(sp, "modulate:a", 0.0, 0.4)
		tw.tween_callback(sp.queue_free)


func _dirt(pos: Vector3) -> void:
	_sparks(pos, Color(0.55, 0.42, 0.28), 8, 0.45)


func _voice(text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = color
	label.outline_size = 8
	label.pixel_size = 0.006
	label.position = Vector3(0, 1.4, 0)
	add_child(label)
	var tw := label.create_tween()
	tw.tween_property(label, "position:y", 1.9, 0.7).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.tween_callback(label.queue_free)


func _orb(pos: Vector3, color: Color, radius: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	mi.mesh = s
	mi.material_override = _emissive(color)
	mi.position = pos
	return mi


func _icon(tex: Texture2D, color: Color, pixel: float) -> Sprite3D:
	var sp := Sprite3D.new()
	sp.texture = tex
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.shaded = false
	sp.no_depth_test = true
	sp.render_priority = 40
	sp.modulate = color
	sp.pixel_size = pixel
	sp.scale = Vector3.ZERO
	return sp


func _box(pos: Vector3, size: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = _solid(col)
	return mi


func _sphere(pos: Vector3, radius: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	mi.mesh = s
	mi.position = pos
	mi.material_override = _solid(col)
	return mi


func _cyl(pos: Vector3, top_r: float, bot_r: float, height: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = top_r
	m.bottom_radius = bot_r
	m.height = height
	m.radial_segments = 12
	mi.mesh = m
	mi.position = pos
	mi.material_override = _solid(col)
	return mi


func _torus(pos: Vector3, inner_r: float, outer_r: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := TorusMesh.new()
	m.inner_radius = inner_r
	m.outer_radius = outer_r
	m.rings = 14
	m.ring_segments = 8
	mi.mesh = m
	mi.position = pos
	mi.material_override = _solid(col)
	return mi


static func _solid(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	if col.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


static func _emissive(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


static func _orient_along(node: Node3D, dir: Vector3) -> void:
	## Rotates a node so its local +Z axis points along dir.
	var d := dir.normalized()
	if d.length_squared() < 0.0001:
		return
	var up := Vector3.UP
	if absf(d.dot(up)) > 0.99:
		up = Vector3.RIGHT
	var x_axis := up.cross(d).normalized()
	var y_axis := d.cross(x_axis).normalized()
	node.transform = Transform3D(Basis(x_axis, y_axis, d), node.transform.origin)


# ---- Procedural textures (ported; drawn once, cached) ----

static func _sparkle_tex() -> ImageTexture:
	if _tex_cache.has("sparkle"):
		return _tex_cache["sparkle"]
	var s := 16
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col := Color(1.0, 0.97, 0.7)
	var c := (s - 1) / 2.0
	for py in range(s):
		for px in range(s):
			var dx := absf(px - c)
			var dy := absf(py - c)
			if (dx < 1.4 and dy < 7.0) or (dy < 1.4 and dx < 7.0) or (dx + dy < 3.0):
				img.set_pixel(px, py, col)
	_tex_cache["sparkle"] = ImageTexture.create_from_image(img)
	return _tex_cache["sparkle"]


static func _burst_tex() -> ImageTexture:
	if _tex_cache.has("burst"):
		return _tex_cache["burst"]
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (s - 1) / 2.0
	for py in range(s):
		for px in range(s):
			var dx := px - c
			var dy := py - c
			var r := sqrt(dx * dx + dy * dy) / c
			if r > 1.0:
				continue
			var ang := atan2(dy, dx)
			var spokes := pow(absf(cos(ang * 4.0)), 6.0)
			var reach := 0.35 + 0.65 * spokes
			if r <= reach:
				var a: float = clamp((1.0 - r / reach) * 1.3, 0.0, 1.0)
				img.set_pixel(px, py, Color(1.0, 1.0, 1.0, a))
	_tex_cache["burst"] = ImageTexture.create_from_image(img)
	return _tex_cache["burst"]


static func _puff_tex() -> ImageTexture:
	if _tex_cache.has("puff"):
		return _tex_cache["puff"]
	var s := 16
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (s - 1) / 2.0
	for py in range(s):
		for px in range(s):
			var dx := px - c
			var dy := py - c
			var r := sqrt(dx * dx + dy * dy) / c
			if r <= 1.0:
				img.set_pixel(px, py, Color(1, 1, 1, 1.0 - r * r))
	_tex_cache["puff"] = ImageTexture.create_from_image(img)
	return _tex_cache["puff"]


static func _shuriken_tex() -> ImageTexture:
	if _tex_cache.has("shuriken"):
		return _tex_cache["shuriken"]
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (s - 1) / 2.0
	var metal := Color(0.78, 0.81, 0.88)
	var edge := Color(0.42, 0.45, 0.54)
	for py in range(s):
		for px in range(s):
			var dx := px - c
			var dy := py - c
			var r := sqrt(dx * dx + dy * dy) / c
			if r > 1.0:
				continue
			var ang := atan2(dy, dx)
			var reach := 0.34 + 0.66 * pow(absf(cos(ang * 2.0)), 2.2)
			if r <= reach and r > 0.14:
				img.set_pixel(px, py, edge if r > reach - 0.12 else metal)
	_tex_cache["shuriken"] = ImageTexture.create_from_image(img)
	return _tex_cache["shuriken"]
