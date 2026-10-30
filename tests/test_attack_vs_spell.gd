extends SceneTree

## Attack and spell are different tags (designer, 2026-10-30): both are
## offensive, but only attacks trigger attack procs, only spells spell procs,
## and both trigger offensive ones. Fireball is an offensive spell (stored as
## an Attack-type card), Slash an attack, Lady Luck a utility spell.
## Run: godot --headless --path . --script tests/test_attack_vs_spell.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Attack vs spell ===")
	var fireball: Card = load("res://data/cards/fireball.tres").duplicate()
	var slash: Card = load("res://data/cards/slash.tres").duplicate()

	# The tags.
	_check(slash.is_attack() and slash.is_offensive() and slash.school != Card.CardSchool.SPELL, "Slash is an attack, offensive, not a spell")
	_check(not fireball.is_attack() and fireball.is_offensive() and fireball.school == Card.CardSchool.SPELL, "Fireball is a spell, offensive, not an attack")

	# Riders worded "an Attack card" take attacks only; "offensive" takes both.
	_check(OnSelfRules.qualifies(slash, "attack") and not OnSelfRules.qualifies(fireball, "attack"), "an attack rider takes Slash, not Fireball")
	_check(OnSelfRules.qualifies(slash, "offensive") and OnSelfRules.qualifies(fireball, "offensive"), "an offensive rider takes both")

	# Staggered: "Attack cards cost more" — spells pay no surcharge.
	var dm := DeckManager.new()
	var deb := DebuffManager.new()
	get_root().add_child(dm)
	get_root().add_child(deb)
	deb.apply_debuff(Debuff.create(Debuff.DebuffType.STAGGERED, 1))
	var slash_plain: int = int(dm.compute_play_cost(slash, -1, null, null).get("mana", slash.mana_cost))
	var slash_stag: int = int(dm.compute_play_cost(slash, -1, null, deb).get("mana", slash.mana_cost))
	var fire_plain: int = int(dm.compute_play_cost(fireball, -1, null, null).get("mana", fireball.mana_cost))
	var fire_stag: int = int(dm.compute_play_cost(fireball, -1, null, deb).get("mana", fireball.mana_cost))
	_check(slash_stag > slash_plain, "Staggered makes Slash cost more (%d -> %d)" % [slash_plain, slash_stag])
	_check(fire_stag == fire_plain, "Staggered leaves Fireball's cost alone (%d -> %d)" % [fire_plain, fire_stag])

	# Strengthen is for attacks only; Circle of Life's reaches every offensive
	# card.
	var stats := PlayerStats.new()
	var bm := BuffManager.new()
	bm.owner_stats = stats
	get_root().add_child(bm)
	bm.apply_buff(Buff.create_strengthen(5, 3, "Belt"))
	stats.st_pre_attack_armed = true
	stats.st_pre_attack_is_offensive = true
	stats.st_pre_attack_is_attack = false   # a spell resolving
	_check(bm.consume_strengthen() == 0, "a spell neither gains nor spends Strengthen")
	var col := Buff.new(Buff.BuffType.STRENGTHEN, 7, -1, 3)
	col.offensive_reach = true
	bm.apply_buff(col)
	_check(bm.get_buffs(Buff.BuffType.STRENGTHEN).size() == 2, "Circle of Life's Strengthen stands beside the attack one")
	_check(bm.consume_strengthen() == 7, "a spell takes Circle of Life's bonus only")
	stats.st_pre_attack_is_attack = true    # an attack resolving
	_check(bm.consume_strengthen() == 12, "an attack takes both")

	# Disarm blocks every attack-tagged card, an attack-and-spell one included.
	var pigs: Card = load("res://data/cards/if_pigs_could_fly.tres")
	_check(pigs.school == Card.CardSchool.SPELL and pigs.is_attack(), "If Pigs Could Fly is a spell and an attack (Disarm blocks it)")

	# The Attack frame is for attacks; a spell wears the Spell frame.
	_check(CardUI.frame_for(slash) == CardUI.FRAMES["attack"], "Slash wears the Attack frame")
	_check(CardUI.frame_for(fireball) == CardUI.FRAMES["spell"], "Fireball wears the Spell frame")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
