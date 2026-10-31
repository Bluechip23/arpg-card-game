class_name SpriteEnemyFigure
extends Node3D

## Billboard Sprite3D enemy visuals.
##
## Three sprite sources:
##  - Craftpix top-down packs (assets/sprites/craftpix/<pack>/<Variant>/
##    Without_shadow/): one sheet per animation (Idle, Walk, Run, Attack,
##    Hurt, Death), square cells (64 or 128), four direction rows. These get
##    REAL frames for everything — walk cycles, attack swings, hit reactions
##    and a death animation — drawn for the game's fixed top-down camera
##    (CameraView). Preferred wherever a pack matches a kind.
##  - MonsterKit battlers (assets/sprites/MonsterKit — 24 static 64x64
##    battlers). Static art, so all motion is procedural (bob, lunge, shake).
##    Kinds without a bespoke battler reuse one with a tint/scale variation
##    (e.g. werewolf = big dark wolf, bone dragon = big pale dragon whelp).
##  - NPC pack sheets (assets/sprites/NPCpackage1/2 — 32px, 4-direction
##    4-frame walk cycles) for humanoid enemies: mages, vampire, succubus,
##    cherub, archangel... Real directional walk frames plus the procedural
##    attack/hit motion.
##
## The one enemy figure: every EnemyDefs figure_kind maps to a KINDS entry
## (the player's summons stand on the same table, Summon._build_figure).

const SHEET := "res://assets/sprites/MonsterKit/monster battler set.png"
const NPC1 := "res://assets/sprites/NPCpackage1"
const CP := "res://assets/sprites/craftpix"
const SHEETS := "res://assets/sprites/generated/sheets"

## Direction row order of the Craftpix packs, top row first: F = front
## (SOUTH, faces the camera), B = back (NORTH), L = WEST, R = EAST. Every
## pack surveyed so far (idle frame 0 per row, docs/ASSET_PACKS.md) uses the
## same F,B,L,R order; the map stays per pack so an exception is one line.
const CP_ROWS := {
	"giant_rat": "FBLR",
	"demons": "FBLR",
	"ghost": "FBLR",
	"swordsman_lvl4_6": "FBLR",
}
## Frames per second per Craftpix animation. One-shots (Attack, Attack2,
## Hurt, Death) return to Idle/Walk when they finish; Death holds its last
## frame. Attack2 is a creature's double attack (the werewolf's claw and
## rake with the other arm); a kind's "fps" overrides these per animation.
const CP_FPS := {"Idle": 5.0, "Walk": 8.0, "Run": 10.0, "Draw": 8.0, "Attack": 12.0, "Attack2": 12.0, "Hurt": 12.0, "Death": 10.0}
const CP_ONESHOT := ["Attack", "Attack2", "Hurt", "Death"]
## Held poses: played once, then the last frame stays until another
## animation plays (the archer rat at full draw, from two tempo before its
## shot until the shot). A hit does not break them.
const CP_HOLD := ["Draw"]
## Every sheet an animation may come as (Craftpix packs and our own).
const CP_ANIMS := ["Idle", "Walk", "Run", "Draw", "Attack", "Attack2", "Hurt", "Death"]

# NPC sheets run S,W,N,E top to bottom (battle uses CharacterAnimator order S,N,E,W).
const NPC_ROW := [0, 2, 1, 3]  # NPC packs run S,E,N,W
const NPC_WALK_TIME := 0.18

## kind -> config.
## Craftpix animated:  {cp: "<pack>/<Variant>", tint?: Color, scale?: float}
## Craftpix frames:    {fr: "<pack>/<Monster>", prefix?: String, tint?, scale?}
##                     (side-view packs shipped as one PNG per frame; one
##                     facing, flipped for west — like the MonsterKit battlers)
## MonsterKit battler: {cell: Vector2i(col,row), tint?: Color, scale?: float}
## Generated battler:  {tex: "<name>", tint?: Color, scale?: float}
## Directional sheets: {sheets: "<folder>", scale?, fps?} — Idle.png / Walk.png in
##                     the Craftpix layout (rows front, back, left, right),
##                     cut from the designer's boards (tools/cut_pose_boards.py,
##                     tools/cut_creature_sheets.py). Played like a Craftpix pack.
##                     An action sheet (Attack.png, Attack2.png) may hold only
##                     the two side rows (left, right): the figure turns to
##                     the side it leans toward to play it facing front or back.
## Craftpix icon:      {icon: "<pack>/<file>", faces?: "left"|"right"|"front",
##                     tint?, scale?} (a single 32x32 monster icon used as a
##                     static battler; flipped for the far side like the
##                     MonsterKit battlers. 32 px tall at PIXEL_SIZE is a
##                     human, so these carry a scale.)
## NPC humanoid:       {npc: "<path>", tint?: Color, scale?: float}
const KINDS := {
	# --- direct battler matches ---
	"sludge": {"sheets": SHEETS + "/sludge", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py, 2026-10-25); was the slime pack's Slime1 tinted green
	"mind_eater": {"sheets": SHEETS + "/mind_eater", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py, 2026-10-28); was a MonsterKit battler
	"pipe_crawler": {"cell": Vector2i(2, 0)},
	"crypt_crawler": {"sheets": SHEETS + "/crypt_crawler", "scale": BOARD_SCALE},  # the designer's grave spider (tools/cut_pose_boards.py, 2026-10-28); was a MonsterKit battler
	"swarm": {"sheets": SHEETS + "/swarm", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py black_key, 2026-10-26); was MonsterKit cell (4, 0)
	"giant_hawk": {"sheets": SHEETS + "/giant_hawk", "scale": BOARD_SCALE},  # the designer's board (2026-10-25), perched; was the mountain-monster Bird
	"screecher": {"cp": "ghost/Ghost2", "scale": 1.2, "tint": Color(0.85, 0.95, 1.15)},  # back on the pale ghost for now (2026-10-27): the crawler board was meant for the Consumed
	"giant_beaver": {"sheets": SHEETS + "/giant_beaver", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py): stands on its hind legs, walks on all fours
	"mini_bear": {"sheets": SHEETS + "/mini_bear", "scale": BOARD_SCALE},  # the designer's board (2026-10-25); was the mountain-monster Bear
	"wolf": {"sheets": SHEETS + "/wolf", "scale": BOARD_SCALE, "fps": {"Attack": 10.0}},  # the designer's walk sheet (tools/cut_creature_sheets.py, 2026-10-22), and his bite board (tools/cut_pose_boards.py, 2026-10-31: Attack is the leap and bite)
	"coyote": {"sheets": SHEETS + "/coyote", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py, 2026-10-26); was the old MonsterKit wolf battler, tinted
	"djinn": {"sheets": SHEETS + "/djinn", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py, 2026-10-24); was the MonsterKit cell (4, 1)
	"specter": {"cp": "ghost/Ghost1", "scale": 1.2},
	"treasure_bunny": {"sheets": SHEETS + "/treasure_bunny", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py, 2026-10-26); was the Treasure Bunny on MonsterKit cell (7, 1)
	"skeleton": {"sheets": SHEETS + "/skeleton", "scale": BOARD_SCALE, "fps": {"Attack": 10.0}},  # the designer's board (tools/cut_pose_boards.py, 2026-10-25), and his slash board (2026-10-31: Attack is the scimitar slash); was the Craftpix Skeleton1
	"treant": {"sheets": SHEETS + "/treant", "scale": BOARD_SCALE},  # the designer's board (2026-10-25); was the Craftpix Ent pack's Ent3
	"consumed": {"sheets": SHEETS + "/consumed", "scale": BOARD_SCALE},  # the designer's crawler board (tools/cut_pose_boards.py; on the Screecher by mistake until 2026-10-27); was MonsterKit cell (6, 2)
	"sewer_croc": {"sheets": SHEETS + "/sewer_cobra", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py, 2026-10-25); was the mountain-monster Snake (the kind keeps its old croc name)
	# --- generated sprites (drawn/derived in our pipeline, palette-conformant) ---
	"rat": {"sheets": SHEETS + "/wererat", "scale": BOARD_SCALE, "fps": {"Attack": 10.0}},  # the Wererat: the designer's board (tools/cut_pose_boards.py, 2026-10-26), and his bite board (2026-10-31: Attack is the leap and bite); was the giant-rat pack's Rat1
	# The designer's Archer Rat: up on its hind legs, bow in hand.
	"archer_rat": {"sheets": SHEETS + "/archer_rat", "scale": BOARD_SCALE, "fps": {"Attack": 10.0}},  # the designer's redrawn board (tools/cut_pose_boards.py, 2026-10-26), and his shoot board (2026-10-31: Draw is the nock and the held draw, Attack the shot)
	# The designer's own boss boards (no pack has these bosses).
	"rat_king": {"sheets": SHEETS + "/rat_king", "scale": BOARD_SCALE},  # the designer's redrawn board (tools/cut_pose_boards.py, 2026-10-26), 2.1 tiles — bigger than the Wererat
	"fire_goblin_soldier": {"sheets": SHEETS + "/fire_goblin", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py, 2026-10-25); was the goblin pack's Goblin2
	"fire_goblin_mage": {"sheets": SHEETS + "/fire_goblin_mage", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py, 2026-10-25); was the goblin pack's Goblin1
	"fire_goblin_shaman": {"sheets": SHEETS + "/fire_goblin_shaman", "scale": BOARD_SCALE},  # his own board (tools/cut_pose_boards.py, 2026-10-28); wore the soldier's, and before that the goblin pack's Goblin3
	"armored_troll": {"sheets": SHEETS + "/armored_troll", "scale": BOARD_SCALE},  # the designer's board (2026-10-25); was the mountain-monster Orc
	"ice_troll": {"sheets": SHEETS + "/ice_troll", "scale": BOARD_SCALE},  # the designer's board (2026-10-25); was the mountain-monster Yeti
	"granite_colossus": {"sheets": SHEETS + "/granite_colossus", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py, 2026-10-25); was the golem pack's Golem1
	"grave_titan": {"sheets": SHEETS + "/grave_titan", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py, 2026-10-25); was the golem pack's Golem2
	"inflamed_minotaur": {"sheets": SHEETS + "/inflamed_minotaur", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py)
	"demon": {"cp": "demons/Demon1", "scale": 0.85},
	"pit_fiend": {"sheets": SHEETS + "/pit_fiend", "scale": BOARD_SCALE},  # the designer's new board, stills (tools/cut_pose_boards.py, 2026-10-28)
	"bugbear": {"sheets": SHEETS + "/bugbear", "scale": BOARD_SCALE},  # the designer's board (2026-10-25); was the gnoll pack's Gnoll2
	"ifrit": {"sheets": SHEETS + "/ifrit", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py)
	"snow_wraith": {"sheets": SHEETS + "/snow_wraith", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py, 2026-10-25); was the ghost pack's Ghost2
	# The designer's 4x4 walk sheets (tools/cut_creature_sheets.py).
	"hydra": {"sheets": SHEETS + "/hydra", "scale": BOARD_SCALE},
	"white_manticore": {"sheets": SHEETS + "/white_manticore", "scale": BOARD_SCALE},
	# --- battler variations where the species genuinely matches ---
	"large_bear": {"sheets": SHEETS + "/large_bear", "scale": BOARD_SCALE},  # the designer's board (2026-10-25); was the mountain-monster Bear
	"bone_dragon": {"sheets": SHEETS + "/bone_dragon", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py)
	"wyvern": {"sheets": SHEETS + "/wyvern", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py)
	"cerberus": {"sheets": SHEETS + "/cerberus", "scale": BOARD_SCALE},  # the designer's boss trio board (tools/cut_pose_boards.py, 2026-10-27); was the walk-sheet cut
	"hades": {"sheets": SHEETS + "/hades", "scale": BOARD_SCALE},  # the boss trio board (2026-10-27); art in place, no Hades enemy exists yet
	"werewolf": {"sheets": SHEETS + "/werewolf", "scale": BOARD_SCALE, "fps": {"Attack": 8.0, "Attack2": 8.0}},  # the designer's board, and his slash boards, side and front/back (tools/cut_pose_boards.py, 2026-10-30): Attack is the claw, Attack2 the claw and the rake with the other arm
	"sabertooth": {"sheets": SHEETS + "/sabertooth", "scale": BOARD_SCALE},
	"weregoat": {"sheets": SHEETS + "/weregoat", "scale": BOARD_SCALE},
	"roc": {"sheets": SHEETS + "/roc", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py, 2026-10-28); was the mountain-monster Bird, tinted
	"ash_harpy": {"sheets": SHEETS + "/ash_harpy", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py, 2026-10-25); was the chaos-monster Icon22
	"magma_spider": {"sheets": SHEETS + "/magma_spider", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py, 2026-10-26); was the Crypt Crawler's MonsterKit cell (3, 0), tinted
	# (Every roster kind now has a sprite; ART_TODO.md still tracks hand-drawn
	# replacements for the generated first-pass battlers above.)
	# --- NPC-pack humanoids (real 4-direction walk frames) ---
	"ice_mage": {"sheets": SHEETS + "/ice_mage", "scale": BOARD_SCALE},  # the designer's frost mage (tools/cut_pose_boards.py, 2026-10-24); was the NPC mystic tinted blue
	"fire_mage": {"sheets": SHEETS + "/fire_mage", "scale": BOARD_SCALE},  # the designer's fire ninja (tools/cut_pose_boards.py, 2026-10-24); was the NPC mystic tinted red
	"spark_mage": {"sheets": SHEETS + "/spark_mage", "scale": BOARD_SCALE},  # the designer's shock mage (tools/cut_pose_boards.py, 2026-10-25); was the NPC mystic tinted yellow
	"air_mage": {"sheets": SHEETS + "/air_mage", "scale": BOARD_SCALE},  # the designer's air mage (2026-10-25); was the NPC mystic
	"earth_mage": {"sheets": SHEETS + "/earth_mage", "scale": BOARD_SCALE},  # the designer's earth mage (2026-10-25); was the NPC mystic tinted green
	"necromancer": {"sheets": SHEETS + "/necromancer", "scale": BOARD_SCALE},  # the designer's board (2026-10-25); was the lich pack's Lich2
	"spirit_collector": {"sheets": SHEETS + "/spirit_collector", "scale": BOARD_SCALE},  # the designer's board (2026-10-25); was the lich pack's Lich1
	"vampire": {"sheets": SHEETS + "/vampire", "scale": BOARD_SCALE},  # the designer's board (2026-10-25); was the vampire pack's Vampires3
	"zombie": {"sheets": SHEETS + "/zombie", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py, 2026-10-26); was the zombie pack's Zombie1
	"infected_hunter": {"sheets": SHEETS + "/infected_hunter", "scale": BOARD_SCALE},  # the designer's board (2026-10-25); was the zombie pack's Zombie3
	"succubus": {"sheets": SHEETS + "/succubus", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py, 2026-10-26); was the chaos-monster Icon14
	"cherub": {"sheets": SHEETS + "/cherub", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py, 2026-10-26); was the NPC baby sheet, tinted
	"corrupted_archangel": {"sheets": SHEETS + "/corrupted_archangel", "scale": BOARD_SCALE},  # the boss trio board (tools/cut_pose_boards.py, 2026-10-27); was the walk-sheet cut
	# --- the generic Minion / Elite / Boss tiers (and custom enemies): the
	# Craftpix swordsman's three gear tiers, lvl4 → lvl6 increasingly heavy,
	# growing with the tier like the old procedural brute did ---
	"brute_minion": {"cp": "swordsman_lvl4_6/Swordsman_lvl4"},
	"brute_elite": {"cp": "swordsman_lvl4_6/Swordsman_lvl5", "scale": 1.15},
	"brute_boss": {"cp": "swordsman_lvl4_6/Swordsman_lvl6", "scale": 1.3},
	# --- the Precious's hunter: the Craftpix ghost pack's crowned wraith ---
	"ring_wraith": {"sheets": SHEETS + "/ring_wraith", "scale": BOARD_SCALE},  # the designer's mounted wraith (tools/cut_pose_boards.py)
	# --- the player's summons (Summon._build_figure): pack art, ally-sized ---
	"summon_golem": {"sheets": SHEETS + "/summon_golem", "scale": BOARD_SCALE},  # the Granite Colossus board in miniature (tools/cut_pose_boards.py, 2026-10-28); was the golem pack's Golem1
	"summon_specter": {"sheets": SHEETS + "/seance_specter", "scale": BOARD_SCALE},  # Jeremy's Seance spirit: the designer's board (tools/cut_pose_boards.py, 2026-10-28)
	"frankenstein": {"sheets": SHEETS + "/frankenstein", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py)
	"sanguine_penguin": {"sheets": SHEETS + "/sanguine_penguin", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py)
	"bull_worm": {"sheets": SHEETS + "/bull_worm", "scale": BOARD_SCALE},  # Worms Armageddon's summon, the designer's board
	# --- the dojo's enemy training dummies ---
	"chicken": {"tex": "chicken"},
	# --- the Rat King's nests: the designer's nest (no pack has one) ---
	"rat_nest": {"sheets": SHEETS + "/rat_nest", "scale": BOARD_SCALE},  # tools/cut_pose_boards.py, 2026-10-28
	# --- the Boneyard: the undead pack's headstones, and the designer's grave digger ---
	"gravestone": {"prop": "undead_grave", "scale": 1.6},
	# --- Hell's Door: the designer's horned skull gate ---
	"hell_door": {"sheets": SHEETS + "/hell_door", "scale": BOARD_SCALE},  # the designer's redraw of the cave pack's skull gate (tools/cut_pose_boards.py, 2026-10-28)
	# --- the summon cards' allies (summoned_skeleton.gd, 2026-10-27) ---
	"summon_skeleton": {"sheets": SHEETS + "/summon_skeleton", "scale": BOARD_SCALE},  # the designer's summon board (tools/cut_pose_boards.py)
	"shadow_hound": {"sheets": SHEETS + "/shadow_hound", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py, 2026-10-28)
	"battle_turtle": {"sheets": SHEETS + "/battle_turtle", "scale": BOARD_SCALE},  # the designer's board (tools/cut_pose_boards.py, 2026-10-28)
	# --- townsfolk (town.gd): the designer's NPC sheets, four standing poses ---
	"olorin": {"sheets": SHEETS + "/olorin", "scale": BOARD_SCALE},  # the designer's board, with his bear (tools/cut_pose_boards.py, 2026-10-28)
	"npc_armory": {"sheets": SHEETS + "/npc_armory", "scale": BOARD_SCALE},  # tools/cut_pose_boards.py, 2026-10-28
	"npc_dojo_master": {"sheets": SHEETS + "/npc_dojo_master", "scale": BOARD_SCALE},  # the designer's sensei (tools/cut_pose_boards.py, 2026-10-29); was the NPC pack's old man
	"npc_card_dealer": {"sheets": SHEETS + "/npc_card_dealer", "scale": BOARD_SCALE},  # tools/cut_pose_boards.py, 2026-10-28
	"npc_sellsword": {"sheets": SHEETS + "/npc_sellsword", "scale": BOARD_SCALE},  # tools/cut_pose_boards.py, 2026-10-27
	"npc_blacksmith": {"sheets": SHEETS + "/npc_blacksmith", "scale": BOARD_SCALE},  # tools/cut_pose_boards.py, 2026-10-27
	"grave_digger": {"sheets": SHEETS + "/grave_digger", "scale": BOARD_SCALE},  # the designer's board, lantern and spade (tools/cut_pose_boards.py, 2026-10-28)
}

# Uniform texel density across every billboard in the game (style guide §1).
const PIXEL_SIZE := 0.03125
## The designer's pose boards (tools/cut_pose_boards.py) are cut at 64 texels
## a tile, the heroes' fineness (2026-10-24: err on the side of
## under-pixelating what we make), so they draw at half the pack scale.
const BOARD_SCALE := 0.5

## Kinds whose battler art already contains a painted contact shadow
## (the flyers; the sludge's own puddle) — these must not get a second blob shadow.
const PAINTED_SHADOW_KINDS := ["swarm", "sludge",
		"screecher", "specter", "snow_wraith", "gravestone", "hell_door"]

var figure_kind := ""   # the KINDS entry this figure was set up as
var smooth := false     # wearing the smooth (non-pixelated) sheets (ArtStyle)
var _sprite: Sprite3D = null
var _rig: Node3D = null
var _tint := Color.WHITE
var _ghost_alpha := 1.0   # < 1 while the enemy is hidden (Enemy.set_hidden): it survives flashes and highlights
var _highlighted := false
var _target_state := 0          # 0 none, 1 will hit / succeed (green), 2 won't (red)
var _outline: Array[Sprite3D] = []
var _walking := false
var _time := 0.0
var _ground_offset := Vector2.ZERO   # the sprite's offset with its feet on the ground row

## A one-pose board's walk (the designer's four-direction stills: one frame a
## direction) has no stride in its art, so the figure steps instead — up
## STEP_LIFT texels and back down, STEP_HZ times a second. Lifted along the
## sprite's own up (its offset), which is screen-up under the plan camera.
const STEP_LIFT := 2.0


## The walking step in this figure's own texels: STEP_LIFT pixel-sheet
## texels, so the smooth sheets (twice as fine) step twice as many.
func step_lift() -> float:
	return STEP_LIFT * (2.0 if smooth else 1.0)
const STEP_HZ := 3.5
var _facing_x := -1.0    # battlers are drawn facing left; flip for east
var _icon_faces := "left"  # icon battlers: the side the art faces ("front" never flips)
var _npc_mode := false
var _npc_facing := 0     # CharacterAnimator.Direction
var _walk_clock := 0.0
var _walk_frame := 0
var _fx_tween: Tween = null
var _base_y := 26.0 * PIXEL_SIZE

# Craftpix animated mode
var _cp_mode := false
var _cp_cell := 64
var _cp_rows := "FBLR"
var _cp_sheets := {}        # anim name -> Texture2D
var _cp_anim := "Idle"
var _cp_frame := 0
var _cp_clock := 0.0
var _cp_dir: int = CharacterAnimator.Direction.SOUTH
var _cp_dead := false
var _fr_mode := false          # frame-per-file pack (side view, one facing)
var _cp_fps := CP_FPS          # CP_FPS, with the kind's own "fps" over it


static func supports(kind: String) -> bool:
	return KINDS.has(kind)


func setup(kind: String) -> void:
	figure_kind = kind
	var cfg: Dictionary = KINDS.get(kind, KINDS["wolf"])
	_tint = cfg.get("tint", Color.WHITE)
	if cfg.has("fps"):
		_cp_fps = CP_FPS.duplicate()
		_cp_fps.merge(cfg["fps"], true)
	position.y = CameraView.SPRITE_LIFT  # nearer the camera than any wall slab (plan view depth)
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	_sprite = Sprite3D.new()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD  # writes depth: per-pixel sorting vs props/characters
	_sprite.region_enabled = true
	_sprite.shaded = false
	if cfg.has("cp"):
		_setup_craftpix(cfg["cp"])
	elif cfg.has("sheets"):
		var soft := ArtStyle.smooth_folder(cfg["sheets"])
		if soft != "":
			# The smooth look (ArtStyle): the designer's art itself at
			# SMOOTH_DENSITY a tile, filtered, with soft edges.
			smooth = true
			_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
			_setup_sheets(soft)
		else:
			_setup_sheets(cfg["sheets"])
	elif cfg.has("fr"):
		_setup_frames(cfg["fr"], cfg.get("prefix", ""))
	elif cfg.has("npc"):
		_npc_mode = true
		_sprite.texture = load(cfg["npc"])
		_sprite.pixel_size = PIXEL_SIZE
		_sprite.region_rect = Rect2(0, 0, 32, 32)
	elif cfg.has("tex"):
		# Baked battler recolor / generated sprite / cut-out painting: one
		# still cell, whatever size the file is (64x64 for the generated set).
		var tex: Texture2D = load("res://assets/sprites/generated/monsters/%s.png" % cfg["tex"])
		_sprite.texture = tex
		_sprite.pixel_size = PIXEL_SIZE
		_sprite.region_rect = Rect2(0, 0, tex.get_width(), tex.get_height()) if tex else Rect2(0, 0, 64, 64)
	elif cfg.has("prop"):
		# A Craftpix prop (one of the cut variants, picked at random) as a
		# static structure: a headstone, a nest of the pack's own art.
		var pcfg: Dictionary = CraftpixProps.PROPS[cfg["prop"]]
		var pool: Array = cfg.get("variants", range(pcfg["variants"].size()))
		var v: Dictionary = pcfg["variants"][pool[randi() % pool.size()]]
		_sprite.texture = load(v["path"])
		_sprite.pixel_size = PIXEL_SIZE * float(pcfg["scale"])   # the designer's props are 64 texels a tile (scale 0.5)
		_sprite.region_rect = Rect2(0, 0, int(v["w"]), int(v["h"]))
	elif cfg.has("icon"):
		# A Craftpix monster icon as a static battler (single 32x32 PNG).
		_sprite.texture = load("%s/%s.png" % [CP, cfg["icon"]])
		_sprite.pixel_size = PIXEL_SIZE
		_sprite.region_rect = Rect2(0, 0, 32, 32)
		_icon_faces = cfg.get("faces", "left")
	else:
		_sprite.texture = load(SHEET)
		_sprite.pixel_size = PIXEL_SIZE
		var cell: Vector2i = cfg["cell"]
		_sprite.region_rect = Rect2(cell.x * 64, cell.y * 64, 64, 64)
	# Ground precisely: pivot the sprite at its FEET. A centred billboard
	# rotates about the middle of the art, so under the pitched battle camera
	# its bottom edge swings below the ground anchor and the creature reads as
	# sunk into the tile (or floating, from the other side). Anchoring the
	# quad at the art's lowest opaque row (feet / painted shadow line) keeps
	# that row glued to the tile whatever the camera angle — the enemy sits
	# on the ground and its blob shadow.
	# (An uncentered Sprite3D grows UP from its origin: offset.y is the height
	# of the art's bottom edge above the pivot, so the rows below the ground
	# line — the padding under the feet / painted shadow — hang below it.)
	_sprite.centered = false
	if _fr_mode:
		_fr_apply_offset()
	else:
		_sprite.offset = Vector2(-_sprite.region_rect.size.x * 0.5,
				-(_sprite.region_rect.size.y - _measure_ground_rows()))
	_ground_offset = _sprite.offset
	_base_y = 0.0
	_sprite.position = Vector3(0, _base_y, 0)
	var s: float = cfg.get("scale", 1.0)
	if smooth:
		s = 32.0 / ArtStyle.SMOOTH_DENSITY   # SMOOTH_DENSITY texels a tile
	_rig.scale = Vector3(s, s, s)
	_rig.add_child(_sprite)
	_sprite.modulate = _tint
	# Contact shadow (style guide §4). Inside the rig so it scales with the
	# creature and follows attack lunges; the rig never moves vertically.
	if not kind in PAINTED_SHADOW_KINDS:
		var body_w := 40.0 * _sprite.pixel_size  # typical drawn battler width
		if _cp_mode or _fr_mode:
			body_w = _measure_body_width() * _sprite.pixel_size
		BlobShadow.attach(_rig, body_w * 0.7)


## Load a Craftpix pack variant: every animation sheet it ships, cell size
## from the sheet height (4 direction rows), row order from CP_ROWS.
func _setup_craftpix(spec: String) -> void:
	_cp_mode = true
	var pack := spec.get_slice("/", 0)
	var variant := spec.get_slice("/", 1)
	_cp_rows = CP_ROWS.get(pack, "FBLR")
	var folder := "%s/%s/%s/Without_shadow" % [CP, pack, variant]
	for anim in CP_ANIMS:
		var tex := _cp_load_sheet(folder, variant, anim)
		if tex:
			_cp_sheets[anim] = tex
	var idle: Texture2D = _cp_sheets.get("Idle")
	assert(idle != null, "Craftpix pack %s has no Idle sheet" % spec)
	_cp_cell = int(idle.get_height() / 4)
	_sprite.texture = idle
	_sprite.pixel_size = PIXEL_SIZE
	_sprite.region_rect = Rect2(0, _cp_row(_cp_dir) * _cp_cell, _cp_cell, _cp_cell)


## Directional sheets of our own (the designer's bosses): Idle.png and
## Walk.png (and any of Run / Attack / Attack2 / Hurt / Death if drawn) in
## the Craftpix layout, four rows front/back/left/right, square cells — or,
## for an action, the two side rows only (the werewolf's slash).
func _setup_sheets(folder: String) -> void:
	_cp_mode = true
	_cp_rows = "FBLR"
	for anim in CP_ANIMS:
		var path := "%s/%s.png" % [folder, anim]
		if ResourceLoader.exists(path):
			_cp_sheets[anim] = load(path)
	var idle: Texture2D = _cp_sheets.get("Idle")
	assert(idle != null, "boss sheets %s have no Idle.png" % folder)
	_cp_cell = int(idle.get_height() / 4)
	_sprite.texture = idle
	_sprite.pixel_size = PIXEL_SIZE
	_sprite.region_rect = Rect2(0, _cp_row(_cp_dir) * _cp_cell, _cp_cell, _cp_cell)


## Load a frame-per-file pack (mountain monsters): every PNG in the folder,
## grouped by animation name (digits stripped; the pack's own slips —
## `tack3` for Attack3 — folded in). Birds have Flight instead of Idle/Walk.
## Runs on the same animation clock as the sheet packs: `_cp_sheets` holds
## an Array of textures per animation instead of one sheet.
func _setup_frames(spec: String, prefix: String) -> void:
	_fr_mode = true
	_cp_mode = true
	var folder := "%s/%s" % [CP, spec]
	var groups := {}
	var d := DirAccess.open(folder)
	if d:
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			if f.ends_with(".png"):
				var stem := f.get_basename()
				if prefix != "" and not stem.begins_with(prefix):
					f = d.get_next()
					continue
				if prefix == "" and stem.begins_with("Stone_"):
					f = d.get_next()
					continue
				var name := stem.trim_prefix(prefix).rstrip("0123456789")
				if name == "tack":
					name = "Attack"
				if name == "Flight":
					name = "Walk"
				groups.get_or_add(name, []).append(folder + "/" + f)
			f = d.get_next()
		d.list_dir_end()
	for name in groups.keys():
		var paths: Array = groups[name]
		paths.sort_custom(func(a: String, b: String) -> bool:
			return _frame_index(a) < _frame_index(b))
		var texs: Array = []
		for pth in paths:
			texs.append(load(pth))
		_cp_sheets[name] = texs
	if not _cp_sheets.has("Idle") and _cp_sheets.has("Walk"):
		_cp_sheets["Idle"] = _cp_sheets["Walk"]  # flyers hover on their flight cycle
	assert(_cp_sheets.has("Idle"), "frame pack %s has no Idle/Walk frames" % spec)
	_sprite.texture = _cp_sheets["Idle"][0]
	_sprite.pixel_size = PIXEL_SIZE
	_sprite.region_enabled = false
	_cp_cell = 0


static func _frame_index(path: String) -> int:
	var digits := ""
	for ch in path.get_file().get_basename():
		if ch >= "0" and ch <= "9":
			digits += ch
	return int(digits) if digits != "" else 0


## Feet pivot for the current frame texture (frames differ in size).
func _fr_apply_offset() -> void:
	var tex: Texture2D = _sprite.texture
	if tex == null:
		return
	_sprite.region_rect = Rect2(0, 0, tex.get_width(), tex.get_height())
	var rows := _measure_ground_rows()
	_sprite.offset = Vector2(-tex.get_width() * 0.5, -(tex.get_height() - rows))
	_sprite.region_enabled = false


## Sheet file for an animation, tolerating the packs' naming slips: the
## swordsman's lowercase `attack`, a variant-less `Gnoll_Death`, and the
## goblins' prefix-less `Idle0` / `Idle` / `Run_attack` names.
static func _cp_load_sheet(folder: String, variant: String, anim: String) -> Texture2D:
	var stem := variant.rstrip("0123456789")
	var lower := anim.to_lower()
	# The swordsman pack names its sheets by the variant's last segment
	# ("Swordsman_lvl4" -> "lvl4_Idle", with a lowercase "attack").
	var tail := variant.get_slice("_", variant.get_slice_count("_") - 1)
	for name in ["%s_%s" % [variant, anim], "%s_%s" % [variant, lower], "%s_%s" % [stem, anim],
			"%s_%s" % [tail, anim], "%s_%s" % [tail, lower],
			anim, anim + "0", lower, lower + "0", anim.capitalize().replace(" ", "_")]:
		var path := "%s/%s_without_shadow.png" % [folder, name]
		if ResourceLoader.exists(path):
			return load(path)
	return null


func _cp_row(direction: int) -> int:
	var letter := "F"
	match direction:
		CharacterAnimator.Direction.NORTH: letter = "B"
		CharacterAnimator.Direction.WEST: letter = "L"
		CharacterAnimator.Direction.EAST: letter = "R"
	return maxi(_cp_rows.find(letter), 0)


## A sheet with only the two side rows (left, then right): an action the
## designer drew in profile (the werewolf's slash board).
func _cp_side_only(anim: String) -> bool:
	var sheet = _cp_sheets.get(anim)
	return sheet is Texture2D and _cp_cell > 0 and sheet.get_height() < _cp_cell * 4


## The row of the current animation's sheet for the facing: on a side-only
## sheet a figure facing front or back turns to the side it leans toward
## (its last horizontal lean, _facing_x).
func _cp_row_now() -> int:
	if not _cp_side_only(_cp_anim):
		return _cp_row(_cp_dir)
	var east := _cp_dir == CharacterAnimator.Direction.EAST \
			or (_cp_dir != CharacterAnimator.Direction.WEST and _facing_x > 0.0)
	return 1 if east else 0


func _cp_frame_count(anim: String) -> int:
	var sheet = _cp_sheets.get(anim)
	if sheet == null:
		return 1
	if sheet is Array:
		return maxi(1, sheet.size())
	return maxi(1, int(sheet.get_width() / _cp_cell))


## Switch animation (no-op if already playing a looping one of that name).
func _cp_play(anim: String, restart: bool = false) -> void:
	if _cp_dead and anim != "Death":
		return
	if not _cp_sheets.has(anim):
		# Packs without a Run sheet walk; anything else falls back to Idle.
		anim = "Walk" if anim == "Run" and _cp_sheets.has("Walk") else "Idle"
	if anim == _cp_anim and not restart:
		return
	_cp_anim = anim
	_cp_frame = 0
	_cp_clock = 0.0
	if not _fr_mode:
		_sprite.texture = _cp_sheets[anim]
	_cp_apply_frame()


func _cp_apply_frame() -> void:
	if _fr_mode:
		var frames: Array = _cp_sheets[_cp_anim]
		_sprite.texture = frames[clampi(_cp_frame, 0, frames.size() - 1)]
		_fr_apply_offset()
		_update_flip()
		return
	_sprite.region_rect = Rect2(_cp_frame * _cp_cell, _cp_row_now() * _cp_cell, _cp_cell, _cp_cell)


## Drawn width of the idle front frame (texels) for the shadow ellipse.
func _measure_body_width() -> float:
	var img: Image = _sprite.texture.get_image()
	if img == null:
		return 40.0
	if img.is_compressed():
		img.decompress()
	var r := _sprite.region_rect
	var left := int(r.size.x)
	var right := -1
	for y in range(int(r.size.y)):
		for x in range(int(r.size.x)):
			if img.get_pixel(int(r.position.x) + x, int(r.position.y) + y).a > 0.05:
				left = mini(left, x)
				right = maxi(right, x)
	return float(right - left + 1) if right >= 0 else 40.0


# Per-(sheet, cell) cache of measured ground rows.
static var _ground_cache := {}


## Rows from the top of the cell down through the art's lowest opaque row —
## the pixel height of the sprite that stands above the ground line. Used as
## the feet pivot: the quad hangs this many texels above the sprite origin.
func _measure_ground_rows() -> float:
	var key := "%s|%s" % [_sprite.texture.resource_path, _sprite.region_rect]
	if _ground_cache.has(key):
		return _ground_cache[key]
	var rows := _sprite.region_rect.size.y - 6.0  # fallback
	var img: Image = _sprite.texture.get_image()
	if img:
		if img.is_compressed():
			img.decompress()
		var r := _sprite.region_rect
		var bottom := -1
		for y in range(int(r.size.y) - 1, -1, -1):
			for x in range(int(r.size.x)):
				if img.get_pixel(int(r.position.x) + x, int(r.position.y) + y).a > 0.05:
					bottom = y
					break
			if bottom >= 0:
				break
		if bottom >= 0:
			rows = float(bottom + 1)
	_ground_cache[key] = rows
	return rows


## Drawn size of the current frame in world units (width, height): the
## opaque bounds of the region, through the rig scale. For portrait cameras.
## A still of exactly what the battlefield shows right now (the current sheet
## cell, before tint/flip), for the tracker squares and the inspect portrait.
func portrait_texture() -> Texture2D:
	if _sprite == null or _sprite.texture == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = _sprite.texture
	at.region = _sprite.region_rect
	return at


static var _still_cache: Dictionary = {}

## The kind's picture for menus (the Compendium): the first idle frame,
## facing south (toward the camera), as a fresh figure stands; trimmed to
## the creature's opaque pixels. {"texture", "tint", "smooth"}, or {} for a
## kind with no sprite. Cached per kind.
static func south_still(kind: String) -> Dictionary:
	if _still_cache.has(kind):
		return _still_cache[kind]
	var out := {}
	if supports(kind):
		var fig := SpriteEnemyFigure.new()
		fig.setup(kind)  # a fresh figure faces SOUTH on Idle frame 0
		var spr := fig._sprite
		if spr and spr.texture:
			var img: Image = spr.texture.get_image()
			if img:
				if img.is_compressed():
					img.decompress()
				var r := Rect2i(spr.region_rect) if spr.region_enabled \
						else Rect2i(Vector2i.ZERO, img.get_size())
				var cell := img.get_region(r)
				var used := cell.get_used_rect()
				if used.size.x > 0 and used.size.y > 0:
					cell = cell.get_region(used)
				out = {"texture": ImageTexture.create_from_image(cell),
					"tint": fig._tint, "smooth": fig.smooth}
		fig.free()
	_still_cache[kind] = out
	return out


func portrait_tint() -> Color:
	return _tint


func portrait_flipped() -> bool:
	return _sprite != null and _sprite.flip_h


func portrait_extent() -> Vector2:
	if _sprite == null or _sprite.texture == null:
		return Vector2(1.0, 1.5)
	var img: Image = _sprite.texture.get_image()
	var r := _sprite.region_rect
	var used := Rect2i(Vector2i.ZERO, Vector2i(int(r.size.x), int(r.size.y)))
	if img:
		if img.is_compressed():
			img.decompress()
		used = img.get_region(Rect2i(int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y))).get_used_rect()
	var s := _rig.scale.y
	return Vector2(used.size.x, used.size.y) * _sprite.pixel_size * s


# =============================================================
# FACADE VERBS (called by Enemy)
# =============================================================

func play_action(action: String) -> void:
	var a := action.to_lower()
	for token in ["move", "walk", "advance", "reposition", "scurry", "crawl", "stalk", "prowl", "flee"]:
		if token in a:
			set_walking(true)
			if _cp_mode and "flee" in a:
				_cp_play("Run")
			return
	if a == "hit":
		play_hit()
		return
	if a == "idle" or a == "stance":
		set_walking(false)
		if _cp_mode and _cp_anim in CP_HOLD:
			_cp_play("Walk" if _walking else "Idle", true)   # let a held pose go
		return
	if "draw" in a:
		# The archer rat nocks and draws, then holds at full draw until its
		# shot (Enemy.DRAW_TEMPO before the shot fires). No Draw sheet: nothing.
		if _cp_mode and _cp_sheets.has("Draw"):
			_cp_play("Draw", true)
		return
	if "heal" in a:
		flash(Color(0.5, 1.0, 0.5))
		return
	# A double attack (the werewolf's claw and rake): the Attack2 sheet,
	# the second hit with the other arm, where a kind has one.
	play_attack("double" in a)


## Death animation (Craftpix packs only). Returns how long the caller should
## hold the body before removing it; 0 when there is no death sheet.
func play_death() -> float:
	if not _cp_mode or not _cp_sheets.has("Death"):
		return 0.0
	_cp_dead = true
	_walking = false
	_cp_play("Death", true)
	return float(_cp_frame_count("Death")) / CP_FPS["Death"]


func set_walking(on: bool) -> void:
	if _walking == on:
		return
	_walking = on
	_walk_frame = 0
	_walk_clock = 0.0
	if _npc_mode and not on:
		_apply_npc_frame(0)
	if _cp_mode and not _cp_anim in CP_ONESHOT:
		_cp_play("Walk" if on else "Idle")


func set_facing(direction: int) -> void:
	if _fr_mode:
		if direction == CharacterAnimator.Direction.EAST:
			_facing_x = 1.0
		elif direction == CharacterAnimator.Direction.WEST:
			_facing_x = -1.0
		_update_flip()
		return
	if _cp_mode:
		_cp_dir = direction
		_cp_apply_frame()
		return
	if _npc_mode:
		_npc_facing = direction
		_apply_npc_frame(_walk_frame if _walking else 0)
		return
	if direction == CharacterAnimator.Direction.EAST:
		_facing_x = 1.0
	elif direction == CharacterAnimator.Direction.WEST:
		_facing_x = -1.0
	_update_flip()


func set_facing_from_velocity(vel: Vector3) -> void:
	if _fr_mode:
		if absf(vel.x) > 0.05:
			_facing_x = 1.0 if vel.x > 0.0 else -1.0
			_update_flip()
		return
	if _cp_mode:
		if vel.length_squared() < 0.01:
			return
		if absf(vel.x) > absf(vel.z):
			_cp_dir = CharacterAnimator.Direction.EAST if vel.x > 0.0 else CharacterAnimator.Direction.WEST
		else:
			_cp_dir = CharacterAnimator.Direction.SOUTH if vel.z > 0.0 else CharacterAnimator.Direction.NORTH
		_facing_x = 1.0 if vel.x > 0.0 else -1.0
		_cp_apply_frame()
		return
	if _npc_mode:
		if vel.length_squared() < 0.01:
			return
		if absf(vel.x) > absf(vel.z):
			_npc_facing = CharacterAnimator.Direction.EAST if vel.x > 0.0 else CharacterAnimator.Direction.WEST
		else:
			_npc_facing = CharacterAnimator.Direction.SOUTH if vel.z > 0.0 else CharacterAnimator.Direction.NORTH
		_facing_x = 1.0 if vel.x > 0.0 else -1.0
		_apply_npc_frame(_walk_frame if _walking else 0)
		return
	if absf(vel.x) > 0.05:
		_facing_x = 1.0 if vel.x > 0.0 else -1.0
		_update_flip()


func _apply_npc_frame(col: int) -> void:
	if _sprite:
		_sprite.region_rect = Rect2(col * 32, NPC_ROW[_npc_facing] * 32, 32, 32)


func _update_flip() -> void:
	if _sprite:
		# Battlers are drawn facing left; the mountain frame packs and some
		# icons face right; a front-on icon never flips.
		if _icon_faces == "front":
			_sprite.flip_h = false
		elif _fr_mode or _icon_faces == "right":
			_sprite.flip_h = _facing_x < 0.0
		else:
			_sprite.flip_h = _facing_x > 0.0


func set_quadruped(_on: bool) -> void:
	pass  # Battler art doesn't change stance.


## The attack swing. `double`: a two-hit attack — the Attack2 sheet where
## the kind has one (the werewolf's claw, then the rake with the other arm),
## with a second, shorter lunge for the second hit; else the one swing.
func play_attack(double: bool = false) -> void:
	if not _rig:
		return
	if _fx_tween:
		_fx_tween.kill()
	var dir := Vector3(_facing_x * 0.28, 0, 0.1)
	var two := false
	if _cp_mode:
		# Real swing frames; the lunge is a smaller step along the true facing.
		two = double and _cp_sheets.has("Attack2")
		_cp_play("Attack2" if two else "Attack", true)
		dir = Vector3(_facing_x * 0.16, 0, 0) if _fr_mode else _cp_forward() * 0.16
	_fx_tween = create_tween()
	_fx_tween.tween_property(_rig, "position", -dir * 0.3, 0.12)
	_fx_tween.tween_property(_rig, "position", dir, 0.08).set_ease(Tween.EASE_OUT)
	if two:
		_fx_tween.tween_property(_rig, "position", dir * 0.4, 0.08).set_ease(Tween.EASE_IN_OUT)
		_fx_tween.tween_property(_rig, "position", dir * 1.1, 0.07).set_ease(Tween.EASE_OUT)
	_fx_tween.tween_property(_rig, "position", Vector3.ZERO, 0.18).set_ease(Tween.EASE_IN_OUT)


func _cp_forward() -> Vector3:
	match _cp_dir:
		CharacterAnimator.Direction.NORTH: return Vector3(0, 0, -1)
		CharacterAnimator.Direction.EAST: return Vector3(1, 0, 0)
		CharacterAnimator.Direction.WEST: return Vector3(-1, 0, 0)
	return Vector3(0, 0, 1)


func play_hit() -> void:
	# White palette-saturating flash on damage (SNES hit flash), plus shake.
	flash(Color(3.0, 3.0, 3.0))
	if _cp_mode and not _cp_anim.begins_with("Attack") and not _cp_anim in CP_HOLD:
		_cp_play("Hurt", true)
	if _rig:
		var t := create_tween()
		t.tween_property(_rig, "position:x", 0.08, 0.05)
		t.tween_property(_rig, "position:x", -0.08, 0.08)
		t.tween_property(_rig, "position:x", 0.0, 0.06)


## Hard two-frame flash (style guide §5): the tint snaps on, holds ~2 frames,
## snaps off. No tween curve, no fade.
func flash(color: Color) -> void:
	if not _sprite:
		return
	var hot := Color(color.r * 4.0, color.g * 4.0, color.b * 4.0) * _tint
	hot.a = _tint.a * _ghost_alpha
	_sprite.modulate = hot
	var t := create_tween()
	t.tween_interval(0.07)
	t.tween_callback(func():
		if _sprite:
			_sprite.modulate = _lit_tint())


func set_highlight(enabled: bool) -> void:
	_highlighted = enabled
	if _sprite:
		_sprite.modulate = _lit_tint()


## Outline colours while aiming: green = the armed card / attack will land
## (and any chance roll goes your way), red = it won't (out of range, or the
## pre-rolled chance fails) — the same green / red as the chance tiles.
const OUTLINE_GOOD := Color(0.35, 1.0, 0.4)
const OUTLINE_BAD := Color(1.0, 0.22, 0.18)
## The 8 one-texel offsets the silhouette is drawn at, behind the sprite.
const OUTLINE_DIRS := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
	Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]

## White silhouettes of the sprite sheets (alpha kept), tinted per outline.
static var _silhouette_cache := {}

static func _silhouette(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var key: String = tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id())
	if _silhouette_cache.has(key):
		return _silhouette_cache[key]
	var img: Image = tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	# The smooth sheets carry mipmaps: work on the full-size level only (the
	# data with them did not fit a no-mipmap image, and the outline vanished).
	if img.has_mipmaps():
		img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	var data := img.get_data()
	for i in range(0, data.size(), 4):
		var on := data[i + 3] > 12
		data[i] = 255
		data[i + 1] = 255
		data[i + 2] = 255
		data[i + 3] = 255 if on else 0
	var sil := Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data)
	var out := ImageTexture.create_from_image(sil)
	_silhouette_cache[key] = out
	return out

## Mark this enemy while a card or attack is aimed: 1 outlines it green
## (will hit / succeed), 2 red (won't), 0 clears it.
func set_target_mark(state: int) -> void:
	if state == _target_state:
		return
	_target_state = state
	if state != 0 and _outline.is_empty() and _rig and _sprite:
		for d in OUTLINE_DIRS:
			var o := Sprite3D.new()
			o.name = "Outline"
			o.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			o.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			o.shaded = false
			o.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			o.centered = false
			o.set_meta("dir", d)
			_rig.add_child(o)
			_outline.append(o)
	for o in _outline:
		o.visible = state != 0
	if state != 0:
		_sync_outline()

## The battle camera. The world renders through Main's SubViewport, so this
## node's own viewport has no camera: ask the nearest ancestor that knows it.
var _cam_cache: Camera3D = null

func _world_camera() -> Camera3D:
	if _cam_cache and is_instance_valid(_cam_cache):
		return _cam_cache
	var n: Node = get_parent()
	while n:
		if n.has_method("get_world_camera"):
			_cam_cache = n.get_world_camera()
			return _cam_cache
		n = n.get_parent()
	_cam_cache = get_viewport().get_camera_3d() if is_inside_tree() else null
	return _cam_cache

## Keep the outline on the sprite's current frame, a hair behind it.
func _sync_outline() -> void:
	if _outline.is_empty() or _sprite == null:
		return
	var col: Color = OUTLINE_GOOD if _target_state == 1 else OUTLINE_BAD
	col.a = 0.75 + 0.25 * absf(sin(_time * 4.0))
	var sil := _silhouette(_sprite.texture)
	var back := Vector3.ZERO
	var cam := _world_camera()
	if cam and _rig:
		# Away from the camera, in rig space, so the sprite always wins the depth test.
		back = (_rig.global_transform.basis.inverse() * cam.global_transform.basis.z).normalized() * -0.04
	for o in _outline:
		o.texture = sil
		o.pixel_size = _sprite.pixel_size
		o.region_enabled = _sprite.region_enabled
		o.region_rect = _sprite.region_rect
		o.flip_h = _sprite.flip_h
		var d: Vector2 = o.get_meta("dir")
		o.offset = _sprite.offset + d * (2.0 if smooth else 1.0)   # the same width on screen
		o.texture_filter = _sprite.texture_filter
		o.position = _sprite.position + back
		o.modulate = col


## Translucency for a hidden enemy (Specter, Cherub, Screecher): folded into
## every tint the sprite takes, so a hit flash or a hover does not undo it.
func set_ghost_alpha(a: float) -> void:
	_ghost_alpha = a
	if _sprite:
		_sprite.modulate = _lit_tint()


func _lit_tint() -> Color:
	var c := _tint
	if _highlighted:
		c = Color(_tint.r * 1.45, _tint.g * 1.45, _tint.b * 1.25, _tint.a)
	c.a *= _ghost_alpha
	return c


func _process(delta: float) -> void:
	if not _sprite:
		return
	_time += delta
	if _target_state != 0:
		_sync_outline()
	if _cp_mode:
		_cp_step(delta)
		return
	if _walking:
		if _npc_mode:
			# Real walk frames for humanoids.
			_walk_clock += delta
			if _walk_clock >= NPC_WALK_TIME:
				_walk_clock -= NPC_WALK_TIME
				_walk_frame = (_walk_frame + 1) % 4
				_apply_npc_frame(_walk_frame)
			_sprite.position.y = _base_y
		else:
			# Waddle: a whole-pixel hop, never below the ground line — pixel
			# art never rotates off-axis (§5), and sub-pixel vertical drift
			# reads as floating.
			_sprite.position.y = _base_y + floorf(absf(sin(_time * 9.0)) * 1.9) * PIXEL_SIZE
	else:
		# Idle breathe: a single-pixel lift on the slow cycle's crest. The old
		# ±0.02 sine dipped the feet under the floor half the time and hovered
		# them the other half.
		_sprite.position.y = _base_y + (PIXEL_SIZE if sin(_time * 2.2) > 0.55 else 0.0)


## Advance the Craftpix animation clock. Loops Idle/Walk/Run; one-shots run
## once, Death holding its last frame, the others handing back to Idle/Walk.
func _cp_step(delta: float) -> void:
	var fps: float = _cp_fps.get(_cp_anim, 8.0)
	_cp_clock += delta
	var count := _cp_frame_count(_cp_anim)
	while _cp_clock >= 1.0 / fps:
		_cp_clock -= 1.0 / fps
		if _cp_frame + 1 >= count:
			if _cp_anim == "Death" or _cp_anim in CP_HOLD:
				return  # hold the last frame
			if _cp_anim in CP_ONESHOT:
				_cp_play("Walk" if _walking else "Idle", true)
				return
			_cp_frame = 0
		else:
			_cp_frame += 1
		_cp_apply_frame()
	# The body never bobs off its ground row: the packs animate that in-art.
	_sprite.position.y = _base_y
	if _cp_cell > 0:
		var stepping := _cp_anim == "Walk" and count == 1 and fmod(_time * STEP_HZ, 1.0) < 0.5
		_sprite.offset = _ground_offset + (Vector2(0, step_lift()) if stepping else Vector2.ZERO)
