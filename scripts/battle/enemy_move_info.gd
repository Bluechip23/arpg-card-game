extends RefCounted

## What every enemy move does, in plain words, for the hover tooltip on the
## move rows of the enemy inspect box (designer, 2026-11-08: "hovering over
## their moves should give an explanation of what the move does … cards it
## puts in the player's hand, tool tips for debuffs it causes etc. You can
## leave async and sync out of the explanation").
##
## Written from each enemy's compendium text (Enemy.get_all_enemy_data's
## "special") and checked against the move's executor (Enemy._try_*), so the
## numbers are the ones the move really deals. Keyed by the EnemyType's name,
## then by the action's internal name (Enemy.actions_for_type).
##
## Each entry: {"text": String, "kw": [keyword keys of
## Card.get_keyword_definitions — the debuffs (and buffs) it lays],
## "cards": [card ids it puts in the player's hand]}.
##
## Number tokens in "text", resolved per enemy so the tooltip shows the
## numbers it actually fights with (the level-band rebalance, see
## Enemy.passive_power_scale):
##   {a}     the enemy's attack damage (Enemy.attack_damage, band-scaled)
##   {s:N}   a fixed number the code band-scales (maxi(1, roundi(N * _pps_dmg)))
##   {m}     its move distance in squares (EnemyDefs "move")
## Plain digits are numbers the code deals flat (not band-scaled).

## The fallback for a plain walk (every "move", "goblin_move", "hydra_move"
## with no entry of its own).
const WALK := {"text": "Walks up to {m} squares toward its target."}

const INFO := {
	"MINION": {
		"attack": {"text": "Melee: hits for {a} damage."},
	},
	"ELITE": {
		"attack": {"text": "Melee: hits for {a} damage."},
	},
	"BOSS": {
		"attack": {"text": "Melee: hits for {a} damage."},
	},
	"RING_WRAITH": {
		"attack": {"text": "Melee: hits for {a} damage. It hunts the ring-bearer — shadow form does not hide you from it."},
	},
	"WERERAT": {
		"bite": {"text": "Melee: bites for {a} damage."},
		"scurry": {"text": "When you are 6 or more squares away: dashes 5 squares toward you."},
	},
	"SKELETON": {
		"attack": {"text": "Melee: hits for {a} damage."},
	},
	"ARMORED_TROLL": {
		"kick": {"text": "Melee: kicks for {s:6} damage. Picked 40% of the time it is beside you."},
		"smash": {"text": "Melee: smashes for {s:14} damage and puts a Lightly Dazed card in your hand. Picked 60% of the time it is beside you.",
				"cards": ["lightly_dazed"]},
	},
	"ARCHER_RAT": {
		"shoot": {"text": "Ranged, 3 to 6 squares: shoots an arrow for {a} damage."},
		"scurry_away": {"text": "When you are within 2 squares: runs 5 squares away from you."},
		"get_into_range": {"text": "When you are more than 6 squares away: moves 2 squares closer. A nest's archer first climbs to its high ground."},
	},
	"HYDRA": {
		"hydra_attack": {"text": "Melee: strikes for {a} damage plus her strength — she gains +2 strength for every hit she takes, whoever lands it."},
		"hydra_heal": {"text": "Unlocked by her 4th hit; used once she is at half health or less: heals to full and regrows her heads."},
	},
	"FIRE_GOBLIN_SOLDIER": {
		"goblin_attack": {"text": "Melee: hits for {a} damage."},
	},
	"FIRE_GOBLIN_MAGE": {
		"ember": {"text": "Ranged, up to 4 squares: {a} damage + 1 Burn.", "kw": ["burn"]},
	},
	"FIRE_GOBLIN_SHAMAN": {
		"fire_wall": {"text": "Ranged, up to 5 squares: raises a 3-square wall of fire one step in front of you, toward the shaman. Walk into it and you take {a} damage + 3 Burn. It stands for your next 6 moves.",
				"kw": ["burn"]},
		"sear_wounds": {"text": "When one of its allies is hurt: sears every ally (itself included) for 2 damage — it can kill them — then heals the survivors 6."},
	},
	"GIANT_BEAVER": {
		"chomp": {"text": "Melee: {a} damage and Stuns you for 3 tempo. Tail Whip follows 2 tempo later.", "kw": ["stun"]},
		"tail_whip": {"text": "Follows every Chomp: {s:6} damage + 5 Vulnerable.", "kw": ["vulnerable"]},
	},
	"MINI_BEAR": {
		"mini_bear_attack": {"text": "Melee: {a} damage, +2 for every time a packmate in sight was hurt (pack fury)."},
	},
	"LARGE_BEAR": {
		"maul": {"text": "Melee: {a} damage + 4 Bleed. Below half health it rages: 1.5x damage and double Bleed. With Mini Bears about it gains 1 Strengthen every time it is hurt.",
				"kw": ["bleed", "strengthen"]},
		"roar": {"text": "When you are within 4 squares, once every 15 tempo: leaves everyone of yours within 4 squares Vulnerable.", "kw": ["vulnerable"]},
	},
	"WOLF": {
		"wolf_bite": {"text": "Melee: {a} damage, +2 while another wolf is within 4 squares of it."},
	},
	"COYOTE": {
		"coyote_nip": {"text": "Melee: {a} damage."},
	},
	"BUGBEAR": {
		"bugbear_strike": {"text": "Melee: {a} damage. First Strike: +8 if it hits you before you have hit it."},
	},
	"INFECTED_HUNTER": {
		"hook": {"text": "From 2 to 7 squares away: hooks you and reels you in beside it. The first hook is ready at once; after each one it takes 8 tempo to recharge."},
		"cleave": {"text": "Melee: {a} damage to everything on the three squares in front of it."},
		"net_throw": {"text": "Within 3 squares, once every 8 tempo: one Weighted for every card in your hand — each card costs +2 tempo until that many have been played.",
				"kw": ["weighted"]},
	},
	"GIANT_HAWK": {
		"swoop": {"text": "Reach 2: {a} damage, with a 20% chance to Blind you (1 stack). Flying — your high ground gives you no bonus against it.", "kw": ["blind"]},
	},
	"TREANT": {
		"treant_slam": {"text": "Melee: {a} earth damage. Picked 60% of the time it is beside you."},
		"root": {"text": "Within 4 squares: Roots you for 8 tempo — you can still attack, but cannot move.", "kw": ["rooted"]},
		"treant_heal": {"text": "When below half health and out of melee: stops to mend — heals 5, +2 for every 10% of health it is below 60%."},
	},
	"ICE_MAGE": {
		"frost_bolt": {"text": "Ranged, up to 3 squares: {a} ice damage + 1 Slowed.", "kw": ["slowed"]},
		"raise_totem": {"text": "Once you are within 8 squares: raises its Ice Totem beside it. When the totem dies it explodes on everyone within 3 squares for 1 ice damage + 1 per tempo it stood (up to 10), and at 10 tempo it goes off by itself. One stands at a time; another comes 30 tempo after it is broken, and it crumbles if the mage falls."},
	},
	"FIRE_MAGE": {
		"fire_bolt": {"text": "Ranged, up to 2 squares: {a} fire damage + 2 Burn.", "kw": ["burn"]},
		"raise_totem": {"text": "Once you are within 8 squares: raises its Fire Totem beside it — every 5 tempo it sears everyone within 3 squares for 3 Burn. One stands at a time; another comes 30 tempo after it is broken, and it crumbles if the mage falls.",
				"kw": ["burn"]},
	},
	"SPARK_MAGE": {
		"spark_bolt": {"text": "Ranged, up to 6 squares: {a} lightning damage + 1 Shocked.", "kw": ["shocked"]},
		"raise_totem": {"text": "Once you are within 8 squares: raises its Lightning Totem beside it — every 5 tempo it Shocks everyone within 4 squares and strikes the nearest for {s:4} lightning damage. One stands at a time; another comes 30 tempo after it is broken, and it crumbles if the mage falls.",
				"kw": ["shocked"]},
	},
	"AIR_MAGE": {
		"gust": {"text": "Ranged, up to 8 squares: {a} wind damage."},
		"raise_totem": {"text": "Once you are within 8 squares: raises its Air Totem beside it — its vortex makes every square you move within 3 squares of it cost extra tempo (3 beside it, 2 at two squares, 1 at three). One stands at a time; another comes 30 tempo after it is broken, and it crumbles if the mage falls."},
	},
	"EARTH_MAGE": {
		"boulder": {"text": "Melee: {a} earth damage. It also gains 4 armor every time it is hit."},
		"raise_totem": {"text": "Once you are within 8 squares: raises its Earth Totem beside it — every 5 tempo it heals each of its allies within 3 squares 4 health, and every direct hit on it costs the attacker 5 (Thorns). One stands at a time; another comes 30 tempo after it is broken, and it crumbles if the mage falls.",
				"kw": ["thorns"]},
	},
	"ZOMBIE": {
		"attack": {"text": "Melee: hits for {a} damage."},
	},
	"WEREWOLF": {
		"werewolf_claw": {"text": "Melee: {a} damage, +3 if you have armor. If you carry any debuff it rakes you a second time for half. Every claw in a row on the same target winds up 1 tempo faster (5, 4, 3…); a new target resets it."},
	},
	"TREASURE_BUNNY": {
		"flee": {"text": "Never attacks: runs 2 squares away from you."},
		"vanish": {"text": "After fleeing for 3 cycles (15 tempo) it vanishes in a puff of smoke — no loot, no XP. Catch it first."},
	},
	"VAMPIRE": {
		"vampire_bite": {"text": "Melee: {a} damage; heals it for all the health it takes (not armor)."},
		"absorb": {"text": "Right after each Bat Form escape (below half health it flits 6 squares away, twice at most): drains the healthiest unit on the map — you included — for {s:20} the first time, {s:10} the second, and heals for the health taken."},
	},
	"NECROMANCER": {
		"dark_bolt": {"text": "Ranged, up to 10 squares: {a} damage and Hexes 2 cards in your hand — each costs +30 mana until played (for up to 25 tempo).", "kw": ["hexed"]},
		"summon_skeleton": {"text": "Raises a skeleton or a zombie beside him. Each of his summons that dies rises again as a Skeleton and costs him 10 health; any other ally that dies within 8 squares of him rises too."},
	},
	"THANATOS": {
		"thanatos_reap": {"text": "Melee: his scythe, {a} damage + 6 Bleed.", "kw": ["bleed"]},
		"death_bolt": {"text": "Up to 6 squares: 15 damage and Hexes a card in your hand — +30 mana until played (for up to 25 tempo).", "kw": ["hexed"]},
		"summon_skeleton": {"text": "A skeleton or a zombie rises beside him, two at most. Each of his servants that falls rises again as a Skeleton and costs him 10 health."},
	},
	"BONE_DRAGON": {
		"dragon_bite": {"text": "Melee: {a} damage."},
		"breath_swarm": {"text": "Down a 6-square line toward you: {a} damage to everyone in it, and a Swarm hatches beside each one hit."},
	},
	"SPIRIT_COLLECTOR": {
		"collector_swing": {"text": "Melee: {a} damage + its Strengthen (which never fades).", "kw": ["strengthen"]},
		"collect_soul": {"text": "Up to 4 squares while you hold fewer than 2 of his souls (otherwise from beside you): {a} damage + its Strengthen, and puts a Release Soul card in your hand. While you hold it you are Drained and it saps you 1 damage a tempo; playing it gives every living Spirit Collector 5 Strengthen.",
				"kw": ["drain", "strengthen"], "cards": ["release_soul"]},
	},
	"GRAVE_TITAN": {
		"titan_smash": {"text": "Melee: {a} damage."},
		"boulder_roll": {"text": "Up to 3 squares: rolls its boulder at you for {a} damage."},
	},
	"CRYPT_CRAWLER": {
		"crawler_bite": {"text": "Melee: {a} damage. After 3 bites in a row it webs you."},
		"web": {"text": "Up to 4 squares (or after 3 bites in a row): puts a Paralysis card in your hand — you cannot move until you play it. It is aimed at your square as it winds up: step off it and the web is strung on the floor there instead, catching whoever walks in (up to 3 floor webs).",
				"cards": ["paralysis"]},
	},
	"SCREECHER": {
		"screech": {"text": "Melee: {a} damage, and it is seen for 3 tempo after. While unseen you cannot attack it directly (poison, burn and area damage still land)."},
		"move": {"text": "Unseen it drifts 4 squares every 2 tempo; seen, 2 squares and the move costs 5 tempo."},
	},
	"CONSUMED": {
		"attack": {"text": "Melee: hits for {a} damage. When it dies it explodes for {s:8} damage to everything beside it."},
	},
	"SLUDGE": {
		"sludge_melee": {"text": "Melee: {a} damage."},
		"sludge_spit": {"text": "Ranged, up to 6 squares: hurls a ball of slime for {a} damage."},
	},
	"PIPE_CRAWLER": {
		"pipe_attack": {"text": "Melee: {a} damage, with a 25% chance to Disarm you for 5 tempo.", "kw": ["disarm"]},
	},
	"SEWER_CROC": {
		"croc_bite": {"text": "Melee: {a} damage."},
		"venom_spray": {"text": "A cone 5 squares long in front of it — one square wide, five at the far end. Everyone in it takes 8 Poison; anyone with armor also takes 10 damage. No armor, no damage.",
				"kw": ["poison"]},
	},
	"RAT_KING": {
		"bite": {"text": "Melee: {a} damage."},
		"infest": {"text": "When you are out of his reach and hold no Infest: puts an Infest card in your hand for every rat within 10 squares of him, himself included. Held for 5 tempo, each hatches 2 Wererats beside you — play it (50 mana) or discard it and nothing hatches.",
				"cards": ["infest"]},
		"seek_nest": {"text": "At 50%, 30% and 30% health he bolts for an untouched rat nest."},
		"nest_heal": {"text": "Beside the nest: heals 20% / 30% / 50% of his health (left / middle / right nest). A nest feeds him once — tear them down and he has nowhere to run."},
	},
	"SWARM": {
		"attack": {"text": "Melee: hits for {a} damage."},
	},
	"GRAVE_DIGGER": {
		"dig_walk": {"text": "Walks up to {m} squares toward the broken gravestone."},
		"repair": {"text": "Beside the broken stone: after 8 tempo of work it stands again at full health, and he is gone. Cut him down before he finishes."},
	},
	"CERBERUS": {
		"cerberus_bite": {"text": "Melee: {a} damage (+ his Strengthen). Below 66% health the second head bites too ({a} + 5 Bleed); below 33% the third as well ({a}, and he heals for the wound). A bite that comes up out of reach is spent.",
				"kw": ["bleed", "strengthen"]},
		"swipe": {"text": "Melee: no damage of its own, but 8 Bleed.", "kw": ["bleed"]},
		"venom_tail": {"text": "Melee: you discard 3 random cards and are Stunned for 15 tempo; the moment the stun is gone, 2 Vulnerable and Cuffed for 10 tempo.",
				"kw": ["stun", "vulnerable", "cuffed"]},
		"cerberus_roar": {"text": "Used when his thorns are spent: he gains 25 armor and 25 Thorns.", "kw": ["thorns"]},
	},
	"ICE_TROLL": {
		"ice_club": {"text": "Melee: {a} damage + 1 Cold and 1 Brittle. If the blow Freezes you, Clobber fires at once.",
				"kw": ["cold", "brittle", "frozen"]},
		"clobber": {"text": "Melee: {s:50} damage + 1 Cold and 1 Brittle. It also fires instantly whenever an Ice Troll blow Freezes you.",
				"kw": ["cold", "brittle", "frozen"]},
	},
	"WHITE_MANTICORE": {
		"manticore_bite": {"text": "Melee: {a} damage."},
		"stinger": {"text": "Melee, then 5 tempo before the next: {s:25} damage + 3 Clumsy + 8 Poison.", "kw": ["clumsy", "poison"]},
	},
	"WYVERN": {
		"wyvern_bite": {"text": "Melee: {a} damage."},
		"talon_grab": {"text": "Up to 3 squares, then 2 cycles before the next: flies above you, {s:25} damage, and drags you to an open square 8 squares away."},
	},
	"WEREGOAT": {
		"hoof_punch": {"text": "Melee: {a} damage."},
		"goat_charge": {"text": "Runs up to 8 squares along the line that crosses the most of your units: 8 damage to everything in its path, and everything within 1 square of where it lands is Stunned for 3 tempo.",
				"kw": ["stun"]},
	},
	"ROC": {
		"dive_bomb": {"text": "From up to 6 squares: lands beside you and hits for {a} damage. It then keeps its distance until the dive is ready again (5 tempo)."},
		"eye_scrape": {"text": "If you have stayed in its melee reach for more than 3 tempo: claws your eyes — 2 Weakened.", "kw": ["weakened"]},
		"roc_retreat": {"text": "It always moves away from you: 1 square."},
	},
	"SABERTOOTH": {
		"track": {"text": "Marks the nearest of your units: +15 Strengthen against it, and the tiger must hunt it.", "kw": ["strengthen"]},
		"bite_and_claw": {"text": "Melee: bites for 6, then claws for 3 — two separate attacks, each rolling its own 35% crit (1.5x damage and 6 Bleed) and spending its own Strengthen.",
				"kw": ["bleed", "strengthen"]},
		"sunken_bite": {"text": "Melee: 10 damage + 8 Bleed; it can crit too (1.5x and 6 more Bleed).", "kw": ["bleed"]},
	},
	"SNOW_WRAITH": {
		"snowball": {"text": "Ranged, up to 5 squares: no damage — Slowed for 3 tempo + 2 Cold. Thrown first; Ice Blast once you are slowed.", "kw": ["slowed", "cold"]},
		"ice_blast": {"text": "Ranged, up to 5 squares: {a} ice damage, +3 if you have armor; Slowed for 3 tempo.", "kw": ["slowed"]},
	},
	"DEMON": {
		"mimic": {"text": "Conjures a duplicate of itself: it looks identical (health, buffs and debuffs all copied) and hits as hard as the real one, but has 1 health. At most 2 mimics per demon."},
		"demon_cuff": {"text": "Melee: Cuffed — you cannot draw for 15 tempo.", "kw": ["cuffed"]},
		"demon_attack": {"text": "Melee: {a} damage."},
	},
	"ASH_HARPY": {
		"peck": {"text": "Spots you from 4 squares, flies in beside you and pecks for {a} damage."},
		"card_steal": {"text": "Once per harpy, up to 5 squares: her vortex sweeps a random card from your hand back to her. Kill the harpy and the card comes back."},
	},
	"MAGMA_SPIDER": {
		"fire_web": {"text": "Up to 3 squares: a web of fire on the ground around you (3x3), aimed at your square as it winds up. While you stand in it you are Slowed and take 1 fire damage every 3 tempo. It lasts until the spider dies; a new web replaces the old.",
				"kw": ["slowed"]},
		"fire_bounce": {"text": "When you close in beside it: it jumps 4 squares away, and every square from where it jumped to where it landed burns for 3 tempo — stepping in costs {a} damage + 1 Burn.",
				"kw": ["burn"]},
	},
	"MIND_EATER": {
		"mind_slow": {"text": "Up to 6 squares: every card in your hand is Hexed — each costs 20 more mana until it is played.", "kw": ["hexed"]},
		"mind_cuff": {"text": "Up to 6 squares: Cuffed — you cannot draw for 15 tempo.", "kw": ["cuffed"]},
	},
	"SPECTER": {
		"spirit_spit": {"text": "Ranged, up to 2 squares: {a} damage."},
		"specter_vanish": {"text": "Fades out for 3 tempo — it cannot be targeted."},
	},
	"SUCCUBUS": {
		"mana_drain": {"text": "Ranged, up to 4 squares: drains 10 mana from your pool."},
		"damaging_snap": {"text": "Ranged, up to 4 squares: 4 damage, +1 for every 20 mana you are missing."},
	},
	"IFRIT": {
		"ifrit_attack": {"text": "Melee: {a} damage."},
		"fire_breath": {"text": "From up to 4 squares: a 5x5 sheet of flame in front of him — {s:20} fire damage + 5 Burn to everyone in it. He then keeps breathing for 6 more tempo: the 5x5 burns all that while (walking into it costs {s:20} + 5 Burn), and for 3 tempo after the breath is over.",
				"kw": ["burn"]},
		"breathe_on": {"text": "Follows every Fire Breath that lands: he keeps breathing for 6 tempo and the 5x5 keeps burning (walking into it costs {s:20} + 5 Burn), then 3 tempo more once it is over. A stun or freeze cuts the breath short.",
				"kw": ["burn"]},
	},
	"INFLAMED_MINOTAUR": {
		"minotaur_attack": {"text": "Melee: {a} damage + 2 Burn (+ his Strengthen).", "kw": ["burn"]},
		"bull_rush": {"text": "A random 5 to 15 tempo after each Labyrinth Leap: charges you — damage equals the squares covered by leap and rush together, with that many x4% chance to Stun you (5 tempo) and Weaken you. You and everything trampled on the way are left Vulnerable, and the lane burns behind him.",
				"kw": ["stun", "weakened", "vulnerable", "burn"]},
	},
	"CHERUB": {
		"loves_arrow": {"text": "Ranged, up to 4 squares: {a} damage, and for 5 tempo you cannot attack the Cherub directly (poison, burn and area damage still land). The first arrow flies the moment you come within reach; after that it is a 10-tempo attack."},
	},
	"DJINN": {
		"chain_lightning": {"text": "{a} lightning damage to everyone it hits: the cast reaches 5 squares, and each bound arcs up to 4 squares from the last one struck."},
	},
}

## Plain words for the wind-up keywords that matter to the player (Async and
## Sync are left out — designer, 2026-11-08).
const TRIGGER_WORDS := {
	"damaged": "it takes damage",
	"exposed": "its armor breaks",
	"ally_died": "one of its allies dies",
	"half_health": "it drops to half health",
}

## The entry for one move of `type` (an Enemy.EnemyType), or the plain walk
## for an un-tabled move action; {} when there is none.
static func entry(type: int, action_name: String) -> Dictionary:
	var key: String = Enemy.EnemyType.keys()[type] if type >= 0 and type < Enemy.EnemyType.size() else ""
	var per: Dictionary = INFO.get(key, {})
	if per.has(action_name):
		return per[action_name]
	if action_name in ["move", "goblin_move", "hydra_move"]:
		return WALK
	return {}

## The explanation of `action` (an entry of Enemy.actions) for an enemy of
## `type`: {"title", "tempo", "text", "windup": [[keyword, plain words]],
## "keywords": [keyword keys], "cards": [card ids]}. `attack_damage` and
## `dmg_scale` are the enemy's band-scaled numbers; left at -1 they are
## worked out from EnemyDefs the way Enemy.initialize does.
static func explain(type: int, action: Dictionary, attack_damage: int = -1, dmg_scale: float = -1.0, move_squares: int = -1) -> Dictionary:
	var key: String = Enemy.EnemyType.keys()[type]
	var def: Dictionary = EnemyDefs.DEFS.get(key, {})
	if dmg_scale < 0.0:
		dmg_scale = float(Enemy.passive_power_scale(int(def.get("intended_level", 0)))["dmg"])
	if attack_damage < 0:
		var base := int(def.get("damage", 0))
		attack_damage = maxi(1, roundi(base * dmg_scale)) if base > 0 else 0
	if move_squares < 0:
		move_squares = int(def.get("move", 1))
	var e := entry(type, str(action.get("name", "")))
	var out := {
		"title": Enemy.action_label(action),
		"tempo": int(action.get("tempo_cost", 0)),
		"text": resolve(str(e.get("text", "")), attack_damage, dmg_scale, move_squares),
		"windup": windup_lines(action),
		"keywords": (e.get("kw", []) as Array).duplicate(),
		"cards": (e.get("cards", []) as Array).duplicate(),
	}
	return out

## The same for a live enemy: its own band-scaled damage and move.
static func explain_for(enemy: Enemy, action: Dictionary) -> Dictionary:
	return explain(enemy.enemy_type, action, enemy.attack_damage, enemy._pps_dmg, int(enemy.move_distance))

## Swaps the number tokens for the enemy's real numbers.
static func resolve(text: String, attack_damage: int, dmg_scale: float, move_squares: int) -> String:
	var out := text.replace("{a}", str(attack_damage)).replace("{m}", str(move_squares))
	var re := RegEx.new()
	re.compile("\\{s:(\\d+)\\}")
	for m in re.search_all(out):
		out = out.replace(m.get_string(0), str(maxi(1, roundi(int(m.get_string(1)) * dmg_scale))))
	return out

## The wind-up keywords an action carries, each with what it means for the
## player: Channel, Disruptable, Trigger. Never Async / Sync.
static func windup_lines(action: Dictionary) -> Array:
	var out: Array = []
	if Enemy.is_trigger_action(action):
		var evt := str(action["trigger"])
		out.append(["Trigger", "Fires the moment %s, not on a clock." % TRIGGER_WORDS.get(evt, evt.capitalize().to_lower())])
		return out
	var ch := Enemy.channel_of(action)
	var cost := int(action.get("tempo_cost", 0))
	if ch > 0:
		if ch >= cost:
			out.append(["Channel %d" % ch, "It channels for all %d tempo: it can't move or act while channelling." % ch])
		else:
			out.append(["Channel %d" % ch, "The last %d of its %d tempo are spent channelling: it can't move or act while channelling." % [ch, cost]])
	var dis := Enemy.disrupt_threshold(action)
	if dis > 0:
		out.append(["Disruptable %d" % dis, "Taking %d damage while it winds up or channels restarts it." % dis])
	return out
