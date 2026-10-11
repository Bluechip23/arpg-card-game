class_name Enemy
extends CharacterBody3D

## Enemy with per-species skills, tempo-driven action selection, and visual tempo bar.
## Each enemy chooses ONE action at the start of its turn. Global tempo accumulates on
## the enemy's personal counter. When it reaches the chosen action's tempo cost, the
## action fires, the counter resets, and a new action is chosen.

signal damaged(amount: int)
signal died(enemy: Enemy)
signal turn_completed  # Kept for compat
signal debuff_applied(enemy: Enemy, debuff_name: String, value: int)
signal debuff_expired(enemy: Enemy, debuff_name: String)
signal exposed(enemy: Enemy)
signal attacked_player(enemy: Enemy, victim)
signal attacking_player(enemy: Enemy, victim)  # about to hit `victim`: reactions that mitigate the blow fire here
signal barricade_attacked(enemy, cell: Vector2i)  # blocked: swings at a barricade toward its target
signal movement_completed(enemy: Enemy)

enum EnemyType { MINION, ELITE, BOSS, WERERAT, SKELETON, ARMORED_TROLL, ARCHER_RAT, HYDRA, FIRE_GOBLIN_SOLDIER, FIRE_GOBLIN_MAGE, FIRE_GOBLIN_SHAMAN,
	# Forest act
	GIANT_BEAVER, MINI_BEAR, LARGE_BEAR, WOLF, COYOTE, BUGBEAR, INFECTED_HUNTER, GIANT_HAWK, TREANT, ICE_MAGE, FIRE_MAGE, SPARK_MAGE, AIR_MAGE, EARTH_MAGE,
	# Graveyard act
	ZOMBIE, WEREWOLF, WERERABBIT, VAMPIRE, NECROMANCER, BONE_DRAGON, SPIRIT_COLLECTOR, GRAVE_TITAN, CRYPT_CRAWLER, SCREECHER, CONSUMED,
	# Sewer act
	SLUDGE, PIPE_CRAWLER, SEWER_CROC, RAT_KING, SWARM,
	# Mountains act (design mock-ups — stats & moves TBD)
	WEREGOAT, WYVERN, ROC, ICE_TROLL, SNOW_WRAITH, GRANITE_COLOSSUS, WHITE_MANTICORE, SABERTOOTH,
	# Underworld act (design mock-ups — stats & moves TBD)
	CERBERUS, SUCCUBUS, DEMON, IFRIT, MIND_EATER, SPECTER, MAGMA_SPIDER, PIT_FIEND, ASH_HARPY, INFLAMED_MINOTAUR,
	# Heavens act (design mock-ups — stats & moves TBD)
	CHERUB, DJINN, CORRUPTED_ARCHANGEL,
	# The Precious (ring pass 1): hostile hunters that appear in shadow form.
	# Appended at the tail — enum order is save-compat-sensitive.
	RING_WRAITH,
	# The dojo's training dummy: never acts, never wanders, never dies (a
	# lethal hit refills it). Appended at the tail for the same reason.
	DUMMY,
	# The Rat King's nests: a destructible structure (15 HP) that heals the
	# king when he reaches it and releases an Archer Rat when the player
	# steps on it. Never acts or moves. Tail-appended (save-compat).
	RAT_NEST,
	# The Boneyard: a gravestone (10 HP structure; every standing one feeds
	# the Bone Dragon's regen) and the grave digger who walks out to repair
	# a broken one (20 HP, 8 tempo of work, then gone). Tail-appended.
	GRAVESTONE, GRAVE_DIGGER,
	# Hell's Door: the gate Cerberus guards (a structure the player breaks
	# through; seals itself for 10 tempo at 75/50/33%). Tail-appended.
	HELL_DOOR }

## Intended player level per enemy type — the anchor for the level-gap XP
## falloff (PlayerStats.get_xp_multiplier): kills more than a few levels below
## the player pay reduced (eventually zero) XP, so low zones can't be farmed.
## 0 = no band (mock-ups, XP-less enemies) -> no falloff applied.
## Bands follow the Act 1 pacing: Sewers 1-5, Graveyard 6-12, Cave 8-15,
## Forest 12-20 (player hits 25 by end of Act 1).
const INTENDED_LEVELS := {
	EnemyType.MINION: 1, EnemyType.ELITE: 5, EnemyType.BOSS: 10,
	# Sewer
	EnemyType.WERERAT: 2, EnemyType.ARCHER_RAT: 2, EnemyType.SLUDGE: 2,
	EnemyType.SWARM: 3, EnemyType.PIPE_CRAWLER: 3,
	EnemyType.SEWER_CROC: 5, EnemyType.RAT_KING: 5,
	# Graveyard
	EnemyType.ZOMBIE: 7, EnemyType.SKELETON: 7, EnemyType.SCREECHER: 8,
	EnemyType.CRYPT_CRAWLER: 8, EnemyType.WERERABBIT: 8, EnemyType.CONSUMED: 9,
	EnemyType.WEREWOLF: 10, EnemyType.VAMPIRE: 10, EnemyType.SPIRIT_COLLECTOR: 10,
	EnemyType.NECROMANCER: 11, EnemyType.BONE_DRAGON: 12, EnemyType.GRAVE_TITAN: 12,
	EnemyType.GRAVE_DIGGER: 8,  # the Boneyard's digger: band 8, so his 20 HP are his 20 HP
	# Cave
	EnemyType.FIRE_GOBLIN_SOLDIER: 9, EnemyType.FIRE_GOBLIN_MAGE: 9,
	EnemyType.FIRE_GOBLIN_SHAMAN: 10, EnemyType.ARMORED_TROLL: 12, EnemyType.HYDRA: 14,
	# Forest
	EnemyType.COYOTE: 12, EnemyType.MINI_BEAR: 13, EnemyType.SPARK_MAGE: 13,
	EnemyType.WOLF: 14, EnemyType.AIR_MAGE: 14, EnemyType.GIANT_HAWK: 15,
	EnemyType.ICE_MAGE: 15, EnemyType.FIRE_MAGE: 15, EnemyType.INFECTED_HUNTER: 16,
	EnemyType.GIANT_BEAVER: 16, EnemyType.EARTH_MAGE: 17, EnemyType.BUGBEAR: 17,
	EnemyType.LARGE_BEAR: 18, EnemyType.TREANT: 19,
	# Mountains 20-25 (late Act 1), Underworld ~Act 2, Heavens ~Act 3. All are
	# past the passive_power_scale clamp, so bands here only gate XP falloff.
	EnemyType.WYVERN: 21, EnemyType.ICE_TROLL: 22, EnemyType.WHITE_MANTICORE: 23,
	EnemyType.SNOW_WRAITH: 20, EnemyType.SABERTOOTH: 21, EnemyType.ROC: 22,
	EnemyType.WEREGOAT: 22, EnemyType.GRANITE_COLOSSUS: 25,
	EnemyType.IFRIT: 28,
	EnemyType.MAGMA_SPIDER: 26, EnemyType.SPECTER: 26, EnemyType.ASH_HARPY: 26,
	EnemyType.SUCCUBUS: 27, EnemyType.MIND_EATER: 27, EnemyType.DEMON: 28,
	EnemyType.DJINN: 35,
	EnemyType.CHERUB: 33,
	EnemyType.CERBERUS: 10,  # the sheet's level column; scaling stays near the sheet's own numbers
	EnemyType.INFLAMED_MINOTAUR: 9,  # likewise: the boss sheet's level column (350 HP / 100 armor / 35)
}

func get_intended_level() -> int:
	return int(INTENDED_LEVELS.get(enemy_type, 0))

## Rebalance multipliers for the 15-point passive rework. The hand-tuned base
## stats were set against the old FLAT passives, whose values sat around the
## middle of the new rank tables. Under the rework a player near an enemy's
## intended level is WEAKER than that old baseline early (few passive points,
## low ranks) and considerably STRONGER late (a maxed lane tops the old flat
## values across the board: 8% lifesteal vs 5%, 11.5% resists vs 10%, 800%
## Swing vs 100%, ...). Level ~8 is the crossover where old flat power roughly
## equals the expected new rank, so enemies scale off their intended level:
## early enemies ease off slightly, later enemies grow into the player's
## compounding ranks. Band 0 (unbanded, e.g. Ring Wraith) is untouched.
static func passive_power_scale(band: int) -> Dictionary:
	if band <= 0:
		return {"hp": 1.0, "dmg": 1.0}
	return {
		"hp": clampf(1.0 + (band - 8) * 0.05, 0.9, 1.45),
		"dmg": clampf(1.0 + (band - 8) * 0.035, 0.9, 1.3),
	}

@export var enemy_name: String = "Enemy"
@export var enemy_type: EnemyType = EnemyType.MINION
@export var max_health: int = 30
@export var move_speed: float = 2.5   # Units per second
@export var attack_damage: int = 2
@export var attack_range: float = 1.5  # In world units (grid cells)
@export var aggro_range: float = 8.0   # In world units
@export var move_distance: float = 1.0 # Units per action (1 grid cell)
var xp_reward: int = 5                 # XP granted to player on kill

var current_health: int = 30
var _pps_dmg: float = 1.0  # Cached passive_power_scale damage multiplier (for hardcoded attack numbers)
var max_armor: int = 0
var current_armor: int = 0
var is_exposed: bool = false          # True once armor has been broken to 0
var last_player_hit_damage: int = 0   # Raw damage of the player's most recent hit (for on-expose passives)
var player_hit_modifier: Callable       # (enemy, amount) -> amount: skill-tree % mods on the player's direct hits (set by main)
var has_been_damaged: bool = false      # any damage from any source has landed (Surprise Opener's first-source check)
var last_hit_from_player: bool = false  # the most recent hit was the player's own (card, gauntlet skill, auto attack), not a tick or summon
var last_hit_direct: bool = false  # ...and from the player's own action (card, skill, auto attack), not a summon or zone tick
var next_action_tempo_tax: int = 0      # Haunted Rebuke: the next action (sync or async) winds up this much longer
var bonus_damage_next_hit: int = 0    # Applied on the next take_damage call, then cleared
var premeditated_card_bonus: int = 0  # Premeditated: +15 onto the next card that targets this enemy
var target: Node3D = null
var is_moving: bool = false
var target_position: Vector3
var _move_path: Array[Vector3] = []  # Remaining tile-center waypoints for the current move
var is_dead: bool = false

# Ambient idling. An enemy with nobody in aggro range doesn't stand frozen at
# its spawn point: every few seconds it shuffles one tile within a short
# leash of home (a camp reads as alive from across the map). Once someone
# IS in range it stops pacing and turns to face them while it waits for its
# tempo action. Wander steps are cosmetic — no tempo, no turn bookkeeping —
# but they walk the real grid (walls, other enemies, pits all respected).
const WANDER_LEASH: int = 2               # max tiles from home, per axis
var _wandering: bool = false              # current glide is an idle shuffle
var _wander_timer: float = 2.0            # seconds until the next shuffle
var _home_cell: Vector2i = Vector2i(-9999, -9999)
var _last_seen_target: Node3D = null      # whoever the spawner last pointed us at

var grid_manager: GridManager
var dungeon_manager = null  # Set by main.gd for elevation lookups
var ground_y_provider: Callable = Callable()  # Set by main.gd: world_pos -> desired ground Y
var blocked_tiles: Array[Vector2i] = []  # Set by main.gd for barricade obstacles
var pillar_tiles: Array[Vector2i] = []   # Set by main.gd for rise pillars (traps enemy on top)
var occupied_tiles: Array[Vector2i] = [] # Set by main.gd: tiles occupied by other enemies
# Set by main.gd: () -> Array of Vector2i tiles held by players/summons right
# now (current tile + where their move ends). Queried live, so a route never
# finishes on a unit that stepped in after the route was planned.
var unit_cells_provider: Callable = Callable()

# Armor Break: set by card.execute() before attack, cleared after
var armor_break_incoming: bool = false

# Status effects applied by player cards (duration in tempo cycles, 1 cycle = 5 global tempo)
var taunt_target: Node3D = null
var taunt_tempo: int = 0       # Remaining tempo cycles for taunt
# Mad Scientist (Defense→Poison): physical defense lowered by this % for a
# few tempo — physical hits land that much harder while it lasts.
var phys_defense_debuff_percent: float = 0.0
var phys_defense_debuff_tempo: int = 0
var attack_reduction: int = 0
var wear_down_tempo: int = 0   # Remaining tempo cycles for wear down
# Slowed (enemy version): each MOVEMENT ACTION costs extra tempo
# (+Debuff.SLOWED_TEMPO_PER_TILE - 1) and burns one stack, regardless of how
# many tiles the action covers — unlike the player, who pays per tile.
# Stacks accumulate freely (Sword of Theseus ramps them) — no timed expiry.
var slow_stacks: int = 0
# Cursed (matches the player's): deals 20% less damage and takes 20% of the
# damage it deals as self-damage — both boosted by the player's Curse Amp /
# Curse Pain sphere nodes. Counts in raw tempo.
var cursed_tempo: int = 0
var is_disarmed: bool = false   # Cannot attack when disarmed
var disarmed_tempo: int = 0    # Remaining tempo cycles for disarm
var is_marked: bool = false    # Takes extra damage from player attacks
var marked_tempo: int = 0      # Remaining tempo for mark
const MARKED_BONUS_PERCENT := 15  # Mark: the player's attacks deal +15% to a marked target
var is_silenced: bool = false  # Cannot cast spells/ranged special attacks when silenced
var silenced_tempo: int = 0    # Remaining tempo cycles for silence
var choke_dot_stacks: int = 0  # Choke: take choke_dot_damage per cycle, lose 1 stack per cycle
var choke_dot_damage: int = 3  # Set at cast: half the caster's auto-attack damage
var cold_stacks: int = 0       # Cold stacks - at 5, becomes frozen
var is_frozen: bool = false    # Cannot act when frozen
var frozen_tempo: int = 0      # Remaining tempo for frozen
var is_stunned: bool = false   # Cannot act when stunned
var stun_tempo: int = 0        # Remaining tempo cycles for stun
var burn_stacks: int = 0       # Burn damage tracker (doubles each cycle)
var burn_damage_next: int = 1  # Burn damage doubles each cycle (1, 2, 4, 8...)
var cold_damage_next: int = 1  # Element Pollination: Cold's doubling tick while the Weaver maintain is up
var polymorph_tempo: int = 0   # Polymorph (Circe's Wand): cycles left as a pig — walk and basic melee only
var poison_stacks: int = 0     # Poison: take X damage per cycle, lose 1 per cycle
var shock_stacks: int = 0      # Shock: take X damage per cycle, lose 1 per cycle
var bleed_stacks: int = 0      # Bleed: 1 damage per tile moved; each damage removes a stack
var vulnerable_stacks: int = 0   # Vulnerable: next hit from the player deals +30%; 1 stack consumed per hit
var weaken_stacks: int = 0       # Weaken: this enemy deals -30% damage; 1 stack consumed per attack
var rooted_tempo: int = 0        # Rooted (Gravity Gauntlets): cannot move, can still attack/cast
var tripped_tempo: int = 0       # Tripped (Trip): move actions cover TRIP_MOVE_PENALTY fewer tiles
const TRIP_MOVE_PENALTY := 4
var disarmed_attacks: int = 0    # Disarm-for-N-attacks (Switch Kick): skip that many attack actions
var narashimha_tempo: int = 0    # Narashimha (Mane of Narashimha): cycles the heal cap holds for
var narashimha_heal_cap: int = -1  # health ceiling while active — the NMnB damage cannot be healed back (-1 = unset)
# Ranged pass (Cupids Bow / Bow of Arash)
var ignores_invisibility: bool = false  # Ring wraiths: act even when the player is invisible/shadow-formed
var fear_source: Node3D = null   # Feared (Lead arrow): run AWAY from this node while it lasts
var fear_tempo: int = 0          # Remaining tempo cycles for fear
var cupid_golden: bool = false   # Struck by Cupids golden arrow — half the tree condition
var cupid_lead: bool = false     # Struck by Cupids lead arrow — the other half
var tree_tempo: int = 0          # Tree form (Cupids Bow): raw TEMPO remaining; cannot act, keeps all buffs/debuffs
var tree_regen_ticks: int = 0    # Tree form: heals 3 on each of its first 3 tempo
var zone_weakened: bool = false  # Standing in a Territorial Mark: -30% damage, no stack consumed; refreshed per tick by main
var void_resistance_percent: float = 0.0  # Mane aura: take this % extra player damage (refreshed each cycle)
# Per-type damage resistances: DamageTypes.Type -> percent reduction. Empty by
# default (no enemy resists anything yet); Blue Robe's adaptive damage type
# reads this table via get_lowest_resistance_type().
var damage_resistances: Dictionary = {}

## The damage type this enemy resists LEAST. Fire is checked first, so ties
## break toward fire (Blue Robe's ruling: "fire is always the first check").
func get_lowest_resistance_type() -> int:
	var order: Array = [DamageTypes.Type.FIRE, DamageTypes.Type.PHYSICAL,
		DamageTypes.Type.LIGHTNING, DamageTypes.Type.POISON, DamageTypes.Type.ICE,
		DamageTypes.Type.WIND, DamageTypes.Type.EARTH]
	var best: int = DamageTypes.Type.FIRE
	var best_val: float = INF
	for t in order:
		var v: float = float(damage_resistances.get(t, 0.0))
		if v < best_val:
			best_val = v
			best = t
	return best
var missing_life_damage_rate: float = 0.0  # Jordan 1s: +rate × missing-health% bonus player damage
var missing_life_threshold: int = 0        # Jordan 1s: only while at/below this health %
var invisible_to_players: Array = []  # Serial Killer: player nodes this enemy ignores

# Hydra: grows stronger with every hit it takes. After the 4th hit it gains bulk
# and unlocks its full-heal move.
var strength: int = 0
var hits_taken: int = 0

# --- Forest-act trait state ---
var damage_type: int = DamageTypes.Type.PHYSICAL  # Element this enemy's attacks deal
var immune_to_high_ground: bool = false           # Giant Hawk: ignores the player's high-ground bonus
var pack_attack_bonus: int = 0                     # Mini Bear: +damage gained when a packmate is hurt
var bleed_on_attack: int = 0                       # Large Bear: bleed stacks applied on hit
var armor_per_hit: int = 0                         # Earth Mage: armor gained whenever it is hit
var attack_burn: int = 0                           # Fire Mage: burn stacks applied on hit
var attack_shock: int = 0                          # Spark Mage: shock stacks applied on hit
var attack_blind_chance: float = 0.0               # Giant Hawk: chance to Blind on hit
var _beaver_followup: bool = false                 # Giant Beaver: chomp queues a Tail Whip
var _hook_recharge: int = 0                        # Infected Hunter: raw tempo until Hook is ready again (sheet: "starts charged" — 0 at spawn)
var _net_cooldown: int = 0                         # Infected Hunter: raw tempo until Net Throw is ready again (sheet: cooldown 8)
var _drops_to_all_fours: bool = false              # Large Bear: posture change below 20% HP (visual)
var hydra_heal_unlocked: bool = false

# --- Elite first-pass trait state ---
var strengthen_stacks: int = 0        # Large Bear: +1 attack damage per stack (gained while Mini Bears watch)
var _bear_hide_toughened: bool = false  # Large Bear: 30% phys resist below 50% HP — never lost, even if healed
var _roar_cooldown: int = 0           # Large Bear: raw tempo until Roar is ready again
var _ww_last_target: Node3D = null    # Werewolf: ramping rhythm — same target speeds the next claw
var _ww_streak: int = 0
var _bat_form_charges: int = 2        # Vampire: bat-form escapes remaining (no way to recharge)
var _vamp_absorb_pending: bool = false  # Vampire: Absorb always casts right after bat form
var _necro_summon_deaths: int = 0     # Necromancer: after 5 of its summons die, raises a Bone Dragon
var _necro_dragon_raised: bool = false
var _necro_summons_alive: int = 0
var _treant_thorn_accumulator: int = 0  # Treant: every 10 tempo, strips enemy thorns and heals
var _stinger_cooldown: int = 0        # White Manticore: raw tempo until Stinger is ready
var _talon_cooldown: int = 0          # Wyvern: raw tempo until Talon Grab is ready
var _minotaur_rush_pending: bool = false  # Inflamed Minotaur: Bull Rush queued 5-15 tempo after the leap
var _minotaur_leap_spaces: int = 0
var _minotaur_damage_taken: int = 0  # Inflamed Minotaur: damage from the player since his last leap (over 20 -> Labyrinth Leap)
var _wake_prev_cell: Vector2i = Vector2i(-9999, -9999)  # Inflamed Minotaur: fire-trail bookkeeping
var _wererabbit_tempo: int = 0            # Wererabbit: flees 3 cycles (15 tempo), then vanishes
var _crawler_attack_streak: int = 0       # Crypt Crawler: webs after 3 consecutive bites

#region TEMPO ACTION SYSTEM
# ============================================
# TEMPO ACTION SYSTEM
# ============================================

## Independent per-enemy tempo counter. Increments with global tempo.
var action_tempo_counter: int = 0

## Accumulator for tracking tempo cycles (used for status effect durations).
var _cycle_accumulator: int = 0

## All available actions for this enemy species.
## Each entry: { "name": String, "tempo_cost": int }
var actions: Array[Dictionary] = []

## Currently chosen action on the SYNC clock. The enemy commits to it and
## waits for tempo (see the keyword notes below).
var chosen_action: Dictionary = {}

## ---- Action keywords (full write-up: docs/ENEMY_ACTION_KEYWORDS.md) ----
## Optional keys on an action entry:
##   "async": true      Async — the action runs on its own clock. Firing it
##                      never resets any other clock. Sync (the default) is
##                      one shared clock, one action at a time; a Sync action
##                      may only START ticking on a tempo where no Async clock
##                      is mid-count (right after every Async action fired).
##   "channel": N       Channel — the last N tempo of the action are spent
##                      channeling: the enemy cannot move or act, and every
##                      other clock pauses. N >= tempo_cost is a stand-alone
##                      channel with no wind-up. Default: Immediate.
##   "disrupt": N       Disruptable — taking N damage while the action counts
##                      (or channels) restarts its clock from 0. Default:
##                      Non-interruptible.
##   "trigger": "evt"   Trigger — fires on the event instead of a clock. Events:
##                      "damaged", "exposed", "ally_died", "half_health".
##   "label": "Name"    Display name (defaults to name.capitalize()).
const TRIGGER_EVENTS := ["damaged", "exposed", "ally_died", "half_health"]
signal action_fired(enemy: Enemy, action_name: String)
signal channel_broken(enemy: Enemy, action_name: String)  # a Channel collapsed (disrupted)
var _async_counters: Dictionary = {}     # action name -> tempo counted on its own clock
var _async_gap: bool = true              # true when no Async clock was mid-count at the end of the last tempo
var _channel_action: Dictionary = {}     # the action being channeled ({} = none)
var _channel_remaining: int = 0          # channel tempo left before it resolves
var _channel_kind: String = ""           # "sync" / "async" / "trigger": whose clock the channel came from
var _action_damage: Dictionary = {}      # action name -> damage taken since its clock started (Disruptable)

## Sword Breaker: tempo added to this enemy's NEXT melee attack, spent when that
## attack finally lands. Everything an enemy does from arm's length counts as a
## melee attack except the actions named here — repositioning, fleeing, healing,
## and the ranged/utility casts.
const NON_MELEE_ACTIONS := {
	"move": true, "hydra_move": true, "goblin_move": true, "scurry": true,
	"seek_nest": true, "nest_heal": true, "dig_walk": true, "repair": true, "cerberus_roar": true,
	"scurry_away": true, "get_into_range": true, "flee": true, "vanish": true,
	"hydra_heal": true, "treant_heal": true, "sear_wounds": true,
	"collect_soul": true, "summon_skeleton": true, "fire_wall": true,
	"shoot": true, "ember": true, "dark_bolt": true, "frost_bolt": true,
	"fire_bolt": true, "spark_bolt": true, "sludge_spit": true, "web": true,
	"hook": true, "net_throw": true, "breath_swarm": true, "screech": true, "gust": true,
	"roar": true, "absorb": true, "chain_lightning": true, "fire_breath": true,
	"boulder_roll": true,
	# second pass (the enemy sheet)
	"goat_charge": true, "dive_bomb": true, "roc_retreat": true, "track": true,
	"snowball": true, "ice_blast": true, "mimic": true, "demon_cuff": true,
	"card_steal": true, "fire_web": true, "mind_slow": true, "mind_cuff": true,
	"spirit_spit": true, "specter_vanish": true, "mana_drain": true,
	"damaging_snap": true, "loves_arrow": true,
	# Act 1a (the enemy sheet): the Rat King's brood, the cobra's spray
	"infest": true, "venom_spray": true,
}
var next_melee_tempo_tax: int = 0

# Movement actions, for the debuffs that tax or scramble movement (Slowed,
# Inebriate) — mirrors how the same debuffs treat the player's moves.
const MOVEMENT_ACTIONS := {
	"move": true, "hydra_move": true, "goblin_move": true, "scurry": true,
	"scurry_away": true, "get_into_range": true, "flee": true, "roc_retreat": true,
}

## Armored Troll passive: accumulator for regeneration (heals 3 HP every 6 global tempo).
var regen_accumulator: int = 0

#endregion
#region TEMPO BAR VISUALS
# ============================================
# TEMPO BAR VISUALS
# ============================================

var _tempo_bar_bg: MeshInstance3D
var _tempo_bar_fg: MeshInstance3D
var _action_label: Label3D
var _tempo_bar_width: float = 0.85
var _health_bar_bg: MeshInstance3D
var _health_bar_fg: MeshInstance3D
var _health_bar_width: float = 0.85
var _status_z: float = HOVER_STATUS.z  # where the status badge row sits (set by _layout_head_up)
## Where the head-up bits sit under the plan camera (CameraView): "above
## the head" is north of the feet on screen, and 0.5 of height puts them
## nearer the camera than the body sprite so they draw over it.
# Head-up stack, bottom to top on screen: armor bar, health bar, tempo bar,
# then (hover only) the action word and the name; status badges on top.
const HOVER_ARMOR := Vector3(0, 0.5, -0.75 * CameraView.HEIGHT_ON_SCREEN)
const HOVER_HEALTH := Vector3(0, 0.5, -1.05 * CameraView.HEIGHT_ON_SCREEN)
const HOVER_TEMPO := Vector3(0, 0.5, -1.4 * CameraView.HEIGHT_ON_SCREEN)
const HOVER_ACTION := Vector3(0, 0.5, -1.75 * CameraView.HEIGHT_ON_SCREEN)
const HOVER_NAME := Vector3(0, 0.5, -2.05 * CameraView.HEIGHT_ON_SCREEN)
const HOVER_STATUS := Vector3(0, 0.5, -2.45 * CameraView.HEIGHT_ON_SCREEN)

# Armor bar visuals (gray bar below health, only for armored enemies)
var _armor_bar_sprite: Sprite3D
var _armor_label: Label3D
var _armor_bar_width: float = 0.6

# Damage preview label (shown when hovering with a card selected)
var _damage_preview_label: Label3D = null

# Sprite animation (replaces BoxMesh for enemies with sprite sheets)
var _enemy_sprite: Sprite3D = null
var _enemy_animator: CharacterAnimator = null
# EnemyFigure (procedural 3D) or SpriteEnemyFigure (MonsterKit billboard) —
# untyped, both expose the same verbs (play_action, flash, set_walking, …).
var _enemy_figure = null
var _action_map: Dictionary = {}

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var health_label: Label3D = $HealthLabel
@onready var name_label: Label3D = $NameLabel
@onready var outline: MeshInstance3D = $Outline

func _ready() -> void:
	current_health = max_health
	target_position = position
	update_health_display()
	update_name_display()
	update_outline()

func initialize(type: EnemyType, gm: GridManager = null) -> void:
	enemy_type = type
	grid_manager = gm

	match enemy_type:
		EnemyType.MINION:
			enemy_name = "Minion"
			max_health = 25
			attack_damage = 3
			move_distance = 1.0
			xp_reward = 5
			_set_mesh_color(Color(0.8, 0.2, 0.2))

		EnemyType.ELITE:
			enemy_name = "Elite"
			max_health = 80
			attack_damage = 6
			move_distance = 0.8
			xp_reward = 10
			_set_mesh_color(Color(0.6, 0.1, 0.1))

		EnemyType.BOSS:
			enemy_name = "Boss"
			max_health = 200
			attack_damage = 10
			move_distance = 0.5
			xp_reward = 25
			_set_mesh_color(Color(0.4, 0.0, 0.2))

		EnemyType.RING_WRAITH:
			# The Precious: hunts the ring-bearer through the shadow world.
			# Shadow form does not hide the player from these.
			enemy_name = "Ring Wraith"
			max_health = 100
			attack_damage = 15
			move_distance = 5.0
			xp_reward = 0  # they resummon — no farming the shadow
			ignores_invisibility = true
			_set_mesh_color(Color(0.12, 0.1, 0.18))

		EnemyType.WERERAT:
			enemy_name = "Wererat"
			max_health = 8
			attack_damage = 3
			move_distance = 1.0
			xp_reward = 3
			_set_mesh_color(Color(0.5, 0.35, 0.2))  # Brown

		EnemyType.SKELETON:
			enemy_name = "Skeleton"
			max_health = 20
			max_armor = 12
			attack_damage = 6
			move_distance = 1.0
			xp_reward = 7
			_set_mesh_color(Color(0.85, 0.85, 0.75))  # Bone white

		EnemyType.ARMORED_TROLL:
			enemy_name = "Armored Troll"
			max_health = 60
			max_armor = 40
			attack_damage = 7
			move_distance = 2.0       # 2 spaces / 4 tempo
			xp_reward = 30
			_set_first_pass_resists(30, 15, 15)
			_set_mesh_color(Color(0.2, 0.4, 0.15))  # Dark green

		EnemyType.ARCHER_RAT:
			enemy_name = "Archer Rat"
			max_health = 6
			max_armor = 0
			attack_damage = 2
			attack_range = 4.0  # Ranged attacker
			move_distance = 2.0  # Moves 2 tiles when repositioning
			xp_reward = 4
			_set_mesh_color(Color(0.6, 0.4, 0.25))  # Light brown

		EnemyType.HYDRA:
			enemy_name = "Hydra"
			max_health = 190          # sheet: 190
			attack_damage = 7         # +accumulated strength
			attack_range = 1.5        # Melee
			move_distance = 3.0       # Moves 3 spaces
			aggro_range = 12.0
			xp_reward = 60
			_set_first_pass_resists(25, 25, 25)  # sheet: 25% physical / fire / lightning
			_set_mesh_color(Color(0.2, 0.55, 0.35))  # Scaled green

		EnemyType.FIRE_GOBLIN_SOLDIER:
			enemy_name = "Fire Goblin Soldier"
			max_health = 6
			attack_damage = 2
			attack_range = 1.5        # Range 0 — must be adjacent
			move_distance = 4.0       # Moves 4 spaces
			xp_reward = 3
			_set_mesh_color(Color(0.85, 0.35, 0.15))  # Ember orange

		EnemyType.FIRE_GOBLIN_MAGE:
			enemy_name = "Fire Goblin Mage"
			max_health = 10
			attack_damage = 7         # Ember damage
			attack_range = 4.0
			move_distance = 2.0
			xp_reward = 8
			_set_mesh_color(Color(0.9, 0.45, 0.2))

		EnemyType.FIRE_GOBLIN_SHAMAN:
			enemy_name = "Fire Goblin Shaman"
			max_health = 16
			attack_damage = 6         # Fire wall damage
			attack_range = 5.0
			move_distance = 2.0
			xp_reward = 12
			_set_mesh_color(Color(0.95, 0.55, 0.25))

		# ===================== FOREST ACT =====================
		EnemyType.GIANT_BEAVER:
			enemy_name = "Giant Beaver"
			max_health = 60
			attack_damage = 9         # Chomp damage; Tail Whip deals 6
			attack_range = 1.5
			move_distance = 3.0       # 3 spaces / 6 tempo
			xp_reward = 20
			_set_first_pass_resists(25, 0, 0)
			_set_mesh_color(Color(0.45, 0.30, 0.18))

		EnemyType.MINI_BEAR:
			enemy_name = "Mini Bear"
			max_health = 14
			attack_damage = 4
			attack_range = 1.5
			move_distance = 5.0       # 5 spaces / 5 tempo
			xp_reward = 6
			_set_mesh_color(Color(0.40, 0.26, 0.16))

		EnemyType.LARGE_BEAR:
			enemy_name = "Large Bear"
			max_health = 90
			attack_damage = 12
			attack_range = 1.5
			move_distance = 6.0       # 6 spaces / 7 tempo
			xp_reward = 35
			bleed_on_attack = 4
			# No base resists — 30% physical arrives (permanently) below 50% HP.
			_set_mesh_color(Color(0.32, 0.20, 0.12))

		EnemyType.WOLF:
			enemy_name = "Wolf"
			max_health = 30
			attack_damage = 7
			attack_range = 1.5
			move_distance = 4.0       # 4 spaces / 3 tempo
			xp_reward = 12
			_set_mesh_color(Color(0.45, 0.45, 0.48))

		EnemyType.COYOTE:
			enemy_name = "Coyote"
			max_health = 6
			attack_damage = 2
			attack_range = 1.5
			move_distance = 4.0       # 4 spaces / 3 tempo
			xp_reward = 3
			_set_mesh_color(Color(0.62, 0.52, 0.36))

		EnemyType.BUGBEAR:
			enemy_name = "Bugbear"
			max_health = 50
			attack_damage = 6
			attack_range = 1.5
			move_distance = 6.0       # 6 spaces / 4 tempo
			xp_reward = 20
			_set_mesh_color(Color(0.36, 0.30, 0.22))

		EnemyType.INFECTED_HUNTER:
			enemy_name = "Infected Hunter"
			max_health = 40
			attack_damage = 8         # AOE swipe in front
			attack_range = 1.5
			move_distance = 2.0       # 2 spaces / 3 tempo
			aggro_range = 12.0        # so it can hook from range 7
			xp_reward = 18
			_set_mesh_color(Color(0.40, 0.50, 0.30))

		EnemyType.GIANT_HAWK:
			enemy_name = "Giant Hawk"
			max_health = 28
			attack_damage = 9
			attack_range = 2.0
			move_distance = 8.0       # 8 spaces / 3 tempo
			xp_reward = 14
			immune_to_high_ground = true
			attack_blind_chance = 0.2
			_set_mesh_color(Color(0.50, 0.38, 0.24))

		EnemyType.TREANT:
			enemy_name = "Treant"
			max_health = 110
			attack_damage = 14
			attack_range = 1.5
			move_distance = 9.0       # 9 spaces / 10 tempo
			aggro_range = 12.0
			xp_reward = 35
			damage_type = DamageTypes.Type.EARTH
			_set_first_pass_resists(25, -10, 55)  # burns easily; grounded against lightning
			_set_mesh_color(Color(0.32, 0.42, 0.20))

		EnemyType.ICE_MAGE:
			enemy_name = "Ice Mage"
			max_health = 40
			attack_damage = 6
			attack_range = 3.0
			move_distance = 3.0       # 3 spaces / 5 tempo
			xp_reward = 14
			damage_type = DamageTypes.Type.ICE
			# (Frost Bolt hardcodes its 1 Slow in _execute_action.)
			_set_mesh_color(Color(0.55, 0.75, 0.95))

		EnemyType.FIRE_MAGE:
			enemy_name = "Fire Mage"
			max_health = 32
			attack_damage = 7
			attack_range = 2.0
			move_distance = 2.0       # 2 spaces / 3 tempo
			xp_reward = 14
			damage_type = DamageTypes.Type.FIRE
			attack_burn = 2
			_set_mesh_color(Color(0.90, 0.35, 0.20))

		EnemyType.SPARK_MAGE:
			enemy_name = "Spark Mage"
			max_health = 16
			attack_damage = 3
			attack_range = 6.0
			move_distance = 2.0       # 2 spaces / 3 tempo
			xp_reward = 8
			damage_type = DamageTypes.Type.LIGHTNING
			attack_shock = 1
			_set_mesh_color(Color(0.85, 0.85, 0.40))

		EnemyType.AIR_MAGE:
			enemy_name = "Air Mage"
			max_health = 30
			attack_damage = 5
			attack_range = 8.0
			move_distance = 6.0       # 6 spaces / 3 tempo
			xp_reward = 12
			damage_type = DamageTypes.Type.WIND
			_set_mesh_color(Color(0.70, 0.85, 0.80))

		EnemyType.EARTH_MAGE:
			enemy_name = "Earth Mage"
			max_health = 65
			attack_damage = 9
			attack_range = 1.5
			move_distance = 5.0       # 5 spaces / 5 tempo
			xp_reward = 18
			damage_type = DamageTypes.Type.EARTH
			armor_per_hit = 4
			_set_mesh_color(Color(0.45, 0.35, 0.25))

		# ===================== GRAVEYARD ACT =====================
		EnemyType.ZOMBIE:
			enemy_name = "Zombie"
			max_health = 12
			attack_damage = 5
			attack_range = 1.5
			move_distance = 3.0
			xp_reward = 5
			_set_mesh_color(Color(0.49, 0.57, 0.40))

		EnemyType.WEREWOLF:
			enemy_name = "Werewolf"
			max_health = 55
			attack_damage = 10        # +3 vs armor (armour-piercing)
			attack_range = 1.5
			move_distance = 3.0
			aggro_range = 12.0
			xp_reward = 22
			_set_first_pass_resists(25, 25, 25)
			_set_mesh_color(Color(0.44, 0.45, 0.47))

		EnemyType.WERERABBIT:
			enemy_name = "Wererabbit"
			max_health = 25
			attack_damage = 0         # Loot monster — never attacks
			attack_range = 0.0
			move_distance = 2.0
			xp_reward = 8
			_set_mesh_color(Color(0.72, 0.70, 0.65))

		EnemyType.VAMPIRE:
			enemy_name = "Vampire"
			max_health = 95
			attack_damage = 10        # Life steal on health damage
			attack_range = 1.5
			move_distance = 5.0
			xp_reward = 24
			_set_first_pass_resists(10, 10, 10)
			_set_mesh_color(Color(0.16, 0.15, 0.20))

		EnemyType.NECROMANCER:
			enemy_name = "Necromancer"
			max_health = 60
			attack_damage = 4
			attack_range = 10.0
			move_distance = 8.0
			aggro_range = 14.0
			xp_reward = 30
			_set_first_pass_resists(0, 15, 15)
			_set_mesh_color(Color(0.12, 0.11, 0.16))

		EnemyType.BONE_DRAGON:
			enemy_name = "Bone Dragon"
			max_health = 150
			attack_damage = 12
			attack_range = 1.5
			move_distance = 5.0
			aggro_range = 14.0
			xp_reward = 80
			_set_first_pass_resists(45, 45, 0)
			_set_mesh_color(Color(0.91, 0.89, 0.84))

		EnemyType.SPIRIT_COLLECTOR:
			enemy_name = "Spirit Collector"
			max_health = 50
			attack_damage = 8
			attack_range = 1.5
			move_distance = 3.0
			xp_reward = 20
			_set_mesh_color(Color(0.60, 0.52, 0.33))

		EnemyType.GRAVE_TITAN:
			enemy_name = "Grave Titan"
			max_health = 130
			max_armor = 30
			attack_damage = 15
			attack_range = 1.5
			move_distance = 4.0
			aggro_range = 12.0
			xp_reward = 80
			_set_mesh_color(Color(0.84, 0.85, 0.87))

		EnemyType.CRYPT_CRAWLER:
			enemy_name = "Crypt Crawler"
			max_health = 28
			attack_damage = 6
			attack_range = 1.5
			move_distance = 3.0
			xp_reward = 12
			_set_mesh_color(Color(0.20, 0.17, 0.22))

		EnemyType.SCREECHER:
			enemy_name = "Screecher"
			max_health = 14
			attack_damage = 5
			attack_range = 1.5
			move_distance = 4.0       # 4 spaces / 2 tempo while invisible
			xp_reward = 8
			_set_mesh_color(Color(0.07, 0.07, 0.10))

		EnemyType.CONSUMED:
			enemy_name = "The Consumed"
			max_health = 35
			attack_damage = 8
			attack_range = 1.5
			move_distance = 5.0       # 5 spaces / 3 tempo
			xp_reward = 14
			_set_mesh_color(Color(0.35, 0.29, 0.28))

		# ===================== SEWER ACT =====================
		EnemyType.SLUDGE:
			enemy_name = "Sludge Being"
			max_health = 10
			attack_damage = 3
			attack_range = 6.0        # Can spit at range
			move_distance = 3.0
			xp_reward = 4
			_set_mesh_color(Color(0.25, 0.63, 0.36))

		EnemyType.PIPE_CRAWLER:
			enemy_name = "Pipe Crawler"
			max_health = 20
			attack_damage = 5
			attack_range = 1.5
			move_distance = 2.0
			xp_reward = 8
			_set_mesh_color(Color(0.48, 0.54, 0.43))

		EnemyType.SEWER_CROC:
			enemy_name = "Sewer Cobra"
			max_health = 40
			max_armor = 20
			attack_damage = 12
			attack_range = 1.5
			move_distance = 2.0
			aggro_range = 12.0
			xp_reward = 25
			_set_mesh_color(Color(0.27, 0.38, 0.23))

		EnemyType.RAT_KING:
			enemy_name = "Rat King"
			max_health = 90
			max_armor = 10
			attack_damage = 6
			attack_range = 1.5
			move_distance = 2.0
			xp_reward = 60
			_set_mesh_color(Color(0.5, 0.35, 0.2))

		EnemyType.SWARM:
			enemy_name = "Swarm"
			max_health = 10
			attack_damage = 3
			attack_range = 1.5
			move_distance = 8.0       # 8 spaces / 3 tempo — very fast
			xp_reward = 4
			_set_mesh_color(Color(0.18, 0.16, 0.13))

		# ===================== MOUNTAINS ACT (elite first pass) =====================
		EnemyType.ICE_TROLL:
			enemy_name = "Ice Troll"
			max_health = 150
			max_armor = 55
			attack_damage = 13        # Club; Clobber (auto on freeze) deals 50
			attack_range = 1.5
			move_distance = 3.0       # 3 spaces / 3 tempo
			aggro_range = 12.0
			xp_reward = 45
			_set_first_pass_resists(35, 15, 15)
			_set_mesh_color(Color(0.62, 0.78, 0.88))

		EnemyType.WHITE_MANTICORE:
			enemy_name = "White Manticore"
			max_health = 75
			max_armor = 15
			attack_damage = 15        # Bite; Stinger deals 25
			attack_range = 1.5
			move_distance = 3.0       # 3 spaces / 2 tempo
			aggro_range = 12.0
			xp_reward = 40
			immune_to_high_ground = true  # bat wings
			_set_first_pass_resists(10, 35, 10)
			_set_mesh_color(Color(0.88, 0.88, 0.92))

		EnemyType.WYVERN:
			enemy_name = "Wyvern"
			max_health = 125
			attack_damage = 25        # Bite; Talon Grab also deals 25
			attack_range = 1.5
			move_distance = 6.0       # 6 spaces / 4 tempo
			aggro_range = 14.0
			xp_reward = 40
			immune_to_high_ground = true  # flier
			_set_first_pass_resists(25, 35, 25)
			_set_mesh_color(Color(0.35, 0.45, 0.30))

		# ===================== MOUNTAINS ACT (second pass — the enemy sheet) =====================
		EnemyType.WEREGOAT:
			enemy_name = "Weregoat"
			max_health = 80
			attack_damage = 6         # Hoof Punch; Charge deals 8 along its path
			attack_range = 1.5
			move_distance = 2.0       # 2 spaces / 5 tempo
			aggro_range = 12.0
			xp_reward = 20
			_set_mesh_color(Color(0.55, 0.5, 0.45))

		EnemyType.ROC:
			enemy_name = "Roc"
			max_health = 25
			max_armor = 15
			attack_damage = 8         # Dive Bomb (the sheet gives no number — first-pass 8)
			attack_range = 1.5
			move_distance = 1.0       # 1 space / 1 tempo, always AWAY from the player
			aggro_range = 12.0
			xp_reward = 16
			immune_to_high_ground = true  # flier
			_set_mesh_color(Color(0.85, 0.75, 0.6))

		EnemyType.SABERTOOTH:
			enemy_name = "Sabertooth Tiger"
			max_health = 45
			attack_damage = 6         # Bite 6 then Claw 3; Sunken Bite 10 + 8 Bleed
			attack_range = 1.5
			move_distance = 2.0       # 2 spaces / 2 tempo
			aggro_range = 12.0
			xp_reward = 18
			_set_mesh_color(Color(0.8, 0.65, 0.4))

		EnemyType.SNOW_WRAITH:
			enemy_name = "Snow Wraith"
			max_health = 10
			attack_damage = 5         # Ice Blast; Snowball deals no damage
			attack_range = 5.0        # the sheet gives no range — thrown, so ranged 5
			move_distance = 3.0       # 3 spaces / 5 tempo
			aggro_range = 12.0
			xp_reward = 8
			damage_type = DamageTypes.Type.ICE
			_set_mesh_color(Color(0.8, 0.9, 1.0))

		EnemyType.GRANITE_COLOSSUS:
			# Stats from the sheet; its moves are still TBD, so it stands.
			enemy_name = "Granite Colossus"
			max_health = 350
			max_armor = 250
			attack_damage = 0
			attack_range = 1.5
			move_distance = 3.0       # 3 spaces / 5 tempo
			aggro_range = 12.0
			xp_reward = 120
			_set_first_pass_resists(65, 50, 50)
			_set_mesh_color(Color(0.5, 0.5, 0.52))

		# ===================== UNDERWORLD ACT (elite first pass) =====================
		EnemyType.IFRIT:
			enemy_name = "Ifrit"
			max_health = 225
			attack_damage = 45        # Fire Breath deals 20 + 5 burn in a 5x5
			attack_range = 1.5
			move_distance = 5.0       # 5 spaces / 4 tempo
			aggro_range = 14.0
			xp_reward = 70
			_set_first_pass_resists(20, 15, 15)
			_set_mesh_color(Color(0.85, 0.30, 0.10))

		EnemyType.INFLAMED_MINOTAUR:
			enemy_name = "Inflamed Minotaur"
			max_health = 350
			max_armor = 100
			attack_damage = 35        # + 2 burn per hit
			attack_range = 1.5
			move_distance = 6.0       # 6 spaces / 5 tempo
			aggro_range = 16.0
			xp_reward = 90
			attack_burn = 2
			_set_first_pass_resists(15, 50, 25)
			_set_mesh_color(Color(0.55, 0.18, 0.08))

		# ===================== HEAVENS ACT (elite first pass) =====================
		EnemyType.DJINN:
			enemy_name = "Djinn"
			max_health = 180
			attack_damage = 35        # Chain lightning, per unit hit
			attack_range = 5.0        # initial cast range 5; bounces reach 4
			move_distance = 8.0       # 8 spaces / 3 tempo
			aggro_range = 14.0
			xp_reward = 80
			damage_type = DamageTypes.Type.LIGHTNING
			_set_first_pass_resists(15, 15, 15)
			_set_mesh_color(Color(0.25, 0.45, 0.85))

		EnemyType.CHERUB:
			enemy_name = "Cherub"
			max_health = 14
			max_armor = 5
			attack_damage = 2         # Love's Arrow
			attack_range = 4.0
			move_distance = 2.0       # 2 spaces / 3 tempo
			aggro_range = 12.0
			xp_reward = 10
			immune_to_high_ground = true  # winged
			_set_mesh_color(Color(1.0, 0.9, 0.8))

		# ===================== UNDERWORLD ACT (second pass — the enemy sheet) =====================
		EnemyType.DEMON:
			enemy_name = "Demon"
			max_health = 65
			attack_damage = 8
			attack_range = 1.5
			move_distance = 2.0       # 2 spaces / 2 tempo
			aggro_range = 12.0
			xp_reward = 24
			_set_mesh_color(Color(0.7, 0.15, 0.1))

		EnemyType.ASH_HARPY:
			enemy_name = "Ash Harpy"
			max_health = 6
			attack_damage = 3         # Peck
			attack_range = 1.5
			move_distance = 1.0       # 1 space / 1 tempo
			aggro_range = 12.0
			xp_reward = 4
			immune_to_high_ground = true  # flier
			_set_mesh_color(Color(0.4, 0.38, 0.36))

		EnemyType.MAGMA_SPIDER:
			enemy_name = "Magma Spider"
			max_health = 4
			attack_damage = 1         # its Fire Web ticks 1 every 3 tempo
			attack_range = 1.5
			move_distance = 0.0       # never moves
			aggro_range = 8.0
			xp_reward = 3
			damage_type = DamageTypes.Type.FIRE
			_set_mesh_color(Color(0.8, 0.3, 0.1))

		EnemyType.MIND_EATER:
			enemy_name = "Mind Eater"
			max_health = 20
			attack_damage = 0         # it never strikes — it taxes and cuffs
			attack_range = 6.0        # the sheet gives no range — a caster's 6
			move_distance = 0.0       # never moves
			aggro_range = 12.0
			xp_reward = 12
			_set_mesh_color(Color(0.6, 0.5, 0.55))

		EnemyType.SPECTER:
			enemy_name = "Specter"
			max_health = 10
			attack_damage = 2         # Spirit Spit
			attack_range = 2.0
			move_distance = 1.0       # 1 space / 1 tempo
			aggro_range = 10.0
			xp_reward = 4
			_set_mesh_color(Color(0.2, 0.2, 0.3))

		EnemyType.SUCCUBUS:
			enemy_name = "Succubus"
			max_health = 25
			max_armor = 5
			attack_damage = 4         # Damaging Snap: missing mana / 20 + 4
			attack_range = 4.0        # the sheet gives no range — a caster's 4
			move_distance = 1.0       # 1 space / 2 tempo
			aggro_range = 12.0
			xp_reward = 14
			_set_mesh_color(Color(0.6, 0.2, 0.5))

		EnemyType.DUMMY:
			# Dojo training dummy: a fat health pool so big hits read as
			# numbers instead of kills; a lethal blow refills it (take_damage).
			enemy_name = "Training Dummy"
			max_health = 500
			attack_damage = 0
			attack_range = 0.0
			move_distance = 0.0
			aggro_range = 0.0
			xp_reward = 0
			is_training_dummy = true
			_set_mesh_color(Color(0.9, 0.9, 0.85))

		EnemyType.RAT_NEST:
			# Rat King's Lair: a heap of straw and bones. A structure, not a
			# creature — it holds its tile, never acts, and counts for nothing
			# (no XP, no loot, and the wave does not wait on it).
			enemy_name = "Rat Nest"
			max_health = 15
			max_armor = 0
			attack_damage = 0
			attack_range = 0.0
			move_distance = 0.0
			aggro_range = 0.0
			xp_reward = 0
			is_structure = true
			_set_mesh_color(Color(0.55, 0.42, 0.25))

		EnemyType.GRAVESTONE:
			# The Boneyard: a headstone. A structure — it holds its tile and
			# counts for nothing — but every one left standing regenerates
			# the Bone Dragon 1 health a cycle.
			enemy_name = "Gravestone"
			max_health = 10
			max_armor = 0
			attack_damage = 0
			attack_range = 0.0
			move_distance = 0.0
			aggro_range = 0.0
			xp_reward = 0
			is_structure = true
			_set_mesh_color(Color(0.55, 0.58, 0.55))

		EnemyType.CERBERUS:
			# The guardian of Hell's Door (design sheet): 250 HP, 50 armor,
			# 25-damage bites, 6 spaces a move, resists 30% physical / 40%
			# fire / 15% lightning. Three heads wake as he weakens; Guardian
			# of Death and Deathyard Dog below.
			enemy_name = "Cerberus"
			max_health = 250
			max_armor = 50
			attack_damage = 25
			attack_range = 1.5
			move_distance = 6.0       # 6 spaces / 3 tempo
			aggro_range = 16.0
			xp_reward = 150
			_set_first_pass_resists(30, 40, 15)
			_set_mesh_color(Color(0.3, 0.1, 0.12))

		EnemyType.HELL_DOOR:
			# Hell's Door: the objective, not a creature. A structure the
			# player breaks through; at 75%, 50% and 33% it seals itself
			# against all damage for 10 tempo. Counts as Cerberus's ally.
			enemy_name = "Hell's Door"
			max_health = 150
			max_armor = 0
			attack_damage = 0
			attack_range = 0.0
			move_distance = 0.0
			aggro_range = 0.0
			xp_reward = 0
			is_structure = true
			_set_mesh_color(Color(0.2, 0.08, 0.08))

		EnemyType.GRAVE_DIGGER:
			# The Boneyard: walks out of the crypt to a broken gravestone,
			# takes 8 tempo to set it right (back to full), and is gone.
			# Never fights; can be cut down on the way (20 HP).
			enemy_name = "Grave Digger"
			max_health = 20
			max_armor = 0
			attack_damage = 0
			attack_range = 0.0
			move_distance = 6.0       # 6 spaces / 2 tempo: he hurries to the stone
			aggro_range = 0.0
			xp_reward = 6
			_set_mesh_color(Color(0.5, 0.55, 0.45))

		_:
			# Design mock-ups (stats & moves TBD) have no arm yet. Name them so
			# a stray spawn is identifiable instead of an anonymous default box;
			# with no actions defined it will simply stand idle.
			enemy_name = EnemyType.keys()[enemy_type].capitalize()
			push_warning("[ENEMY] %s is a design mock-up — stats & moves TBD" % enemy_name)

	# Passive-rework rebalance: scale the hand-tuned stats by the enemy's
	# intended level (see passive_power_scale). XP is deliberately untouched —
	# progression pacing is its own dial. The damage multiplier is cached for
	# the attacks that hardcode their numbers (Kick/Smash/Tail Whip/Death Burst).
	var pps := passive_power_scale(get_intended_level())
	_pps_dmg = pps["dmg"]
	if max_health > 0:
		max_health = maxi(1, roundi(max_health * pps["hp"]))
		max_armor = roundi(max_armor * pps["hp"])
		if attack_damage > 0:
			attack_damage = maxi(1, roundi(attack_damage * pps["dmg"]))

	current_health = max_health
	current_armor = max_armor
	update_health_display()
	update_name_display()
	update_outline()
	_setup_actions()
	_setup_tempo_bar()
	_setup_health_bar()
	_setup_armor_bar()
	_setup_sprite()
	_layout_head_up()

	# Custom/generic-tier enemies keep the coloured box, which never had a
	# contact shadow — the strongest grounding cue — so they read as floating.
	# Figure kinds attach their own inside SpriteEnemyFigure / EnemyFigure.
	if _enemy_figure == null and not has_node("Shadow"):
		BlobShadow.attach(self, 0.62)

	if grid_manager:
		position = grid_manager.snap_to_grid(position)
		target_position = position

## Elite first-pass resist columns from the design sheet: Physical / Fire /
## Lightning. The other damage types (ice, poison, wind, earth) stay at 0
## until the sheet grows columns for them. Negative values are
## vulnerabilities (the hit lands harder — e.g. Treant vs fire).
func _set_first_pass_resists(phys: float, fire: float, lightning: float) -> void:
	if phys != 0.0:
		damage_resistances[DamageTypes.Type.PHYSICAL] = phys
	if fire != 0.0:
		damage_resistances[DamageTypes.Type.FIRE] = fire
	if lightning != 0.0:
		damage_resistances[DamageTypes.Type.LIGHTNING] = lightning

func _set_mesh_color(color: Color) -> void:
	if mesh:
		var mat = mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			mat.albedo_color = color

var figure_kind: String = ""  # EnemyFigure kind this enemy renders as ("" = coloured box)
var is_training_dummy: bool = false  # dojo dummy: absorbs hits and statuses, never acts or dies
var is_structure: bool = false       # a hittable object on the grid (rat nest): never acts, never wanders, the wave does not wait on it

# --- Rat King's Lair: nests and the king's flight to them ---
# On a RAT_NEST: how much of the king's max health it restores (left 20%,
# middle 30%, right 50%), whether it has been drained, and its perch — the
# cliff-top cell the nest's Archer Rat climbs to when the player disturbs it.
var nest_heal_pct: float = 0.0
var nest_used: bool = false
var nest_label: String = ""
var nest_perch: Vector2i = Vector2i(-1, -1)
var nest_perch_approach: Vector2i = Vector2i(-1, -1)
var nest_archer_released: bool = false
# On an ARCHER_RAT released from a nest: the cliff top it walks up to and
# then holds (shooting from the high ground instead of kiting). The cliff
# face is a wall, so it first rounds the cliff's side (perch_approach) and
# climbs on from there.
var perch_cell: Vector2i = Vector2i(-1, -1)
var perch_approach: Vector2i = Vector2i(-1, -1)
var _perch_approach_done: bool = false
# On the RAT_KING: main hands over the live nests; the king flees to a
# random untouched one at 50%, then 30%, then 30% again (after healing).
var nest_provider: Callable = Callable()
const NEST_FLIGHT_THRESHOLDS := [0.5, 0.3, 0.3]
var _nest_flights_done: int = 0
var _nest_target: Enemy = null
var _nest_stuck: int = 0

# --- The Boneyard: gravestones, grave diggers and the dragon's regen ---
# On a GRAVE_DIGGER: the broken gravestone's cell it walks to, and main's
# handler that rebuilds the stone (and sends the digger away) when its
# 8-tempo repair fires.
var repair_cell: Vector2i = Vector2i(-1, -1)
var repair_handler: Callable = Callable()
# On the BONE_DRAGON in its yard: main's count of standing gravestones —
# each one is 1 health of regen a cycle, and it never fades.
var gravestone_provider: Callable = Callable()

# --- Hell's Gate: Cerberus and the door ---
# Cerberus: Guardian of Death (Brace 30% for the next N hits, +5 each time
# he first drops below half, or any unit — foe or ally, the door included —
# within 8 squares drops below half); Deathyard Dog (a foe healing within 5
# squares gives him 15 Strengthen); Roar's thorns (damage back to the
# player's direct hits, one thorn spent per hit); Venom Tail's aftermath
# (when the 15-tempo stun ends the victim gains 2 Vulnerable and 10 tempo
# of Cuffed).
var _brace_charges: int = 0
var _guardian_self_used: bool = false
var _guardian_watch: Dictionary = {}     # unit instance id -> was below half
var _deathyard_hooked: bool = false
var enemy_thorns: int = 0
var _venom_countdown: int = 0
var _venom_victim: Node3D = null
const GUARDIAN_RADIUS := 8.0
const DEATHYARD_RADIUS := 5.0
# Hell's Door: tempo left on its seal, and which thresholds have fired.
var door_sealed_tempo: int = 0
var _door_thresholds_hit: Array = []
const DOOR_SEAL_THRESHOLDS := [0.75, 0.5, 0.33]
const DOOR_SEAL_TEMPO := 10

func _setup_sprite() -> void:
	## Builds a procedural 3D model (EnemyFigure) for enemy types that have one,
	## replacing the box mesh. Generic types keep their coloured box.
	var kind := ""
	match enemy_type:
		EnemyType.WERERAT: kind = "rat"
		EnemyType.ARCHER_RAT: kind = "archer_rat"
		EnemyType.ARMORED_TROLL: kind = "armored_troll"
		EnemyType.SKELETON: kind = "skeleton"
		EnemyType.HYDRA: kind = "hydra"
		EnemyType.FIRE_GOBLIN_SOLDIER: kind = "fire_goblin_soldier"
		EnemyType.FIRE_GOBLIN_MAGE: kind = "fire_goblin_mage"
		EnemyType.FIRE_GOBLIN_SHAMAN: kind = "fire_goblin_shaman"
		EnemyType.GIANT_BEAVER: kind = "giant_beaver"
		EnemyType.MINI_BEAR: kind = "mini_bear"
		EnemyType.LARGE_BEAR: kind = "large_bear"
		EnemyType.WOLF: kind = "wolf"
		EnemyType.COYOTE: kind = "coyote"
		EnemyType.BUGBEAR: kind = "bugbear"
		EnemyType.INFECTED_HUNTER: kind = "infected_hunter"
		EnemyType.GIANT_HAWK: kind = "giant_hawk"
		EnemyType.TREANT: kind = "treant"
		EnemyType.ICE_MAGE: kind = "ice_mage"
		EnemyType.FIRE_MAGE: kind = "fire_mage"
		EnemyType.SPARK_MAGE: kind = "spark_mage"
		EnemyType.AIR_MAGE: kind = "air_mage"
		EnemyType.EARTH_MAGE: kind = "earth_mage"
		EnemyType.ZOMBIE: kind = "zombie"
		EnemyType.WEREWOLF: kind = "werewolf"
		EnemyType.WERERABBIT: kind = "wererabbit"
		EnemyType.VAMPIRE: kind = "vampire"
		EnemyType.NECROMANCER: kind = "necromancer"
		EnemyType.BONE_DRAGON: kind = "bone_dragon"
		EnemyType.SPIRIT_COLLECTOR: kind = "spirit_collector"
		EnemyType.GRAVE_TITAN: kind = "grave_titan"
		EnemyType.CRYPT_CRAWLER: kind = "crypt_crawler"
		EnemyType.SCREECHER: kind = "screecher"
		EnemyType.CONSUMED: kind = "consumed"
		EnemyType.SLUDGE: kind = "sludge"
		EnemyType.PIPE_CRAWLER: kind = "pipe_crawler"
		EnemyType.SEWER_CROC: kind = "sewer_croc"
		EnemyType.RAT_KING: kind = "rat_king"
		EnemyType.SWARM: kind = "swarm"
		EnemyType.WEREGOAT: kind = "weregoat"
		EnemyType.WYVERN: kind = "wyvern"
		EnemyType.ROC: kind = "roc"
		EnemyType.ICE_TROLL: kind = "ice_troll"
		EnemyType.SNOW_WRAITH: kind = "snow_wraith"
		EnemyType.GRANITE_COLOSSUS: kind = "granite_colossus"
		EnemyType.WHITE_MANTICORE: kind = "white_manticore"
		EnemyType.SABERTOOTH: kind = "sabertooth"
		EnemyType.CERBERUS: kind = "cerberus"
		EnemyType.SUCCUBUS: kind = "succubus"
		EnemyType.DEMON: kind = "demon"
		EnemyType.IFRIT: kind = "ifrit"
		EnemyType.MIND_EATER: kind = "mind_eater"
		EnemyType.SPECTER: kind = "specter"
		EnemyType.MAGMA_SPIDER: kind = "magma_spider"
		EnemyType.PIT_FIEND: kind = "pit_fiend"
		EnemyType.ASH_HARPY: kind = "ash_harpy"
		EnemyType.INFLAMED_MINOTAUR: kind = "inflamed_minotaur"
		EnemyType.CHERUB: kind = "cherub"
		EnemyType.DJINN: kind = "djinn"
		EnemyType.CORRUPTED_ARCHANGEL: kind = "corrupted_archangel"
		# Generic tiers / custom enemies without bespoke art: a procedural
		# brute figure in the tier's colour (the old floating coloured box
		# never read as a creature).
		EnemyType.MINION: kind = "brute_minion"
		EnemyType.ELITE: kind = "brute_elite"
		EnemyType.BOSS: kind = "brute_boss"
		EnemyType.DUMMY: kind = "chicken"
		EnemyType.RAT_NEST: kind = "rat_nest"
		EnemyType.GRAVESTONE: kind = "gravestone"
		EnemyType.GRAVE_DIGGER: kind = "grave_digger"
		EnemyType.HELL_DOOR: kind = "hell_door"
		_:
			return  # Unknown types keep their coloured box

	figure_kind = kind
	# Prefer the MonsterKit battler sprite when this kind has one; the
	# procedural mesh figure remains the fallback for everything else.
	if SpriteEnemyFigure.supports(kind):
		_enemy_figure = SpriteEnemyFigure.new()
	else:
		_enemy_figure = EnemyFigure.new()
	add_child(_enemy_figure)
	_enemy_figure.setup(kind)

	# The figure replaces the prototype box + outline
	if mesh:
		mesh.visible = false
	if outline:
		outline.visible = false

## The enemy's picture as it stands on the field (null for the generic brute
## tiers, which have no sprite).
func get_portrait_texture() -> Texture2D:
	if _enemy_figure and _enemy_figure.has_method("portrait_texture"):
		return _enemy_figure.portrait_texture()
	return null

func get_portrait_tint() -> Color:
	if _enemy_figure and _enemy_figure.has_method("portrait_tint"):
		return _enemy_figure.portrait_tint()
	return Color.WHITE

func is_portrait_flipped() -> bool:
	return _enemy_figure != null and _enemy_figure.has_method("portrait_flipped") and _enemy_figure.portrait_flipped()

func _on_enemy_animation_finished(anim_name: String) -> void:
	if _enemy_animator and anim_name != "stance" and anim_name != "walking":
		_enemy_animator.play("stance", CharacterAnimator.Direction.SOUTH)

func _play_enemy_animation(action: String) -> void:
	## Play an animation by action name (procedural figure, or legacy sprite sheet).
	if _enemy_figure:
		_enemy_figure.play_action(action)
		return
	if not _enemy_animator or not _enemy_animator.sprite_sheet_loaded:
		return
	var anim_name = _action_map.get(action, action)
	if _enemy_animator.animations.has(anim_name):
		_enemy_animator.play(anim_name, CharacterAnimator.Direction.SOUTH, true)

func _setup_actions() -> void:
	actions = actions_for_type(enemy_type)
	_reset_action_clocks()

static func actions_for_type(type: EnemyType) -> Array[Dictionary]:
	## The action table per enemy species (also read by the compendium).
	var actions: Array[Dictionary] = []
	match type:
		EnemyType.MINION:
			actions = [
				{"name": "attack", "tempo_cost": 3},
				{"name": "move",   "tempo_cost": 5},
			]
		EnemyType.RING_WRAITH:
			actions = [
				{"name": "attack", "tempo_cost": 2},
				{"name": "move",   "tempo_cost": 4},
			]
		EnemyType.ELITE:
			actions = [
				{"name": "attack", "tempo_cost": 4},
				{"name": "move",   "tempo_cost": 6},
			]
		EnemyType.BOSS:
			actions = [
				{"name": "attack", "tempo_cost": 5},
				{"name": "move",   "tempo_cost": 8},
			]
		EnemyType.WERERAT:
			actions = [
				{"name": "move",   "tempo_cost": 2},
				{"name": "bite",   "tempo_cost": 2},
				{"name": "scurry", "tempo_cost": 4},
			]
		EnemyType.SKELETON:
			actions = [
				{"name": "move",   "tempo_cost": 5},
				{"name": "attack", "tempo_cost": 4},
			]
		EnemyType.ARMORED_TROLL:
			actions = [
				{"name": "move",  "tempo_cost": 4},
				{"name": "kick",  "tempo_cost": 3},
				{"name": "smash", "tempo_cost": 5},
			]
		EnemyType.ARCHER_RAT:
			actions = [
				{"name": "shoot",          "tempo_cost": 5},
				{"name": "scurry_away",    "tempo_cost": 2},
				{"name": "get_into_range", "tempo_cost": 2},
			]
		EnemyType.HYDRA:
			actions = [
				{"name": "hydra_attack", "tempo_cost": 8},
				{"name": "hydra_move",   "tempo_cost": 6},
				{"name": "hydra_heal",   "tempo_cost": 5},
			]
		EnemyType.FIRE_GOBLIN_SOLDIER:
			actions = [
				{"name": "goblin_attack", "tempo_cost": 3},
				{"name": "goblin_move",   "tempo_cost": 2},
			]
		EnemyType.FIRE_GOBLIN_MAGE:
			actions = [
				{"name": "ember",       "tempo_cost": 4},
				{"name": "goblin_move", "tempo_cost": 3},
			]
		EnemyType.FIRE_GOBLIN_SHAMAN:
			actions = [
				# Fire Wall is the game's teaching Channel: the last 4 of its 8
				# tempo are spent channeling, and 8 damage in that window breaks it.
				{"name": "fire_wall",   "tempo_cost": 8, "channel": 4, "disrupt": 8},
				{"name": "sear_wounds", "tempo_cost": 6},
				{"name": "goblin_move", "tempo_cost": 3},
			]

		# ===================== FOREST ACT =====================
		EnemyType.GIANT_BEAVER:
			actions = [
				{"name": "chomp",     "tempo_cost": 4},
				{"name": "tail_whip", "tempo_cost": 2},
				{"name": "move",      "tempo_cost": 6},
			]
		EnemyType.MINI_BEAR:
			actions = [
				{"name": "mini_bear_attack", "tempo_cost": 3},
				{"name": "move",             "tempo_cost": 5},
			]
		EnemyType.LARGE_BEAR:
			actions = [
				{"name": "maul", "tempo_cost": 4},
				{"name": "roar", "tempo_cost": 3},
				{"name": "move", "tempo_cost": 7},
			]
		EnemyType.WOLF:
			actions = [
				{"name": "wolf_bite", "tempo_cost": 5},
				{"name": "move",      "tempo_cost": 3},
			]
		EnemyType.COYOTE:
			actions = [
				{"name": "coyote_nip", "tempo_cost": 4},
				{"name": "move",       "tempo_cost": 3},
			]
		EnemyType.BUGBEAR:
			actions = [
				{"name": "bugbear_strike", "tempo_cost": 5},
				{"name": "move",           "tempo_cost": 4},
			]
		EnemyType.INFECTED_HUNTER:
			actions = [
				{"name": "hook",      "tempo_cost": 8},
				{"name": "cleave",    "tempo_cost": 3},
				{"name": "net_throw", "tempo_cost": 2},  # sheet: 2 tempo, cooldown 8 (_net_cooldown)
				{"name": "move",      "tempo_cost": 3},
			]
		EnemyType.GIANT_HAWK:
			actions = [
				{"name": "swoop", "tempo_cost": 4},
				{"name": "move",  "tempo_cost": 3},
			]
		EnemyType.TREANT:
			actions = [
				{"name": "treant_slam", "tempo_cost": 10},
				{"name": "root",        "tempo_cost": 8},
				{"name": "treant_heal", "tempo_cost": 5},
				{"name": "move",        "tempo_cost": 10},
			]
		EnemyType.ICE_MAGE:
			actions = [
				{"name": "frost_bolt", "tempo_cost": 3},
				{"name": "move",       "tempo_cost": 5},
			]
		EnemyType.FIRE_MAGE:
			actions = [
				{"name": "fire_bolt", "tempo_cost": 3},
				{"name": "move",      "tempo_cost": 3},
			]
		EnemyType.SPARK_MAGE:
			actions = [
				{"name": "spark_bolt", "tempo_cost": 2},
				{"name": "move",       "tempo_cost": 3},
			]
		EnemyType.AIR_MAGE:
			actions = [
				{"name": "gust", "tempo_cost": 5},
				{"name": "move", "tempo_cost": 3},
			]
		EnemyType.EARTH_MAGE:
			actions = [
				{"name": "boulder", "tempo_cost": 6},
				{"name": "move",    "tempo_cost": 5},
			]

		# ===================== GRAVEYARD ACT =====================
		EnemyType.ZOMBIE:
			actions = [
				{"name": "attack", "tempo_cost": 6},
				{"name": "move",   "tempo_cost": 8},
			]
		EnemyType.WEREWOLF:
			actions = [
				{"name": "werewolf_claw", "tempo_cost": 5},
				{"name": "move",          "tempo_cost": 3},
			]
		EnemyType.WERERABBIT:
			actions = [
				{"name": "flee",   "tempo_cost": 1},
				{"name": "vanish", "tempo_cost": 1},
			]
		EnemyType.VAMPIRE:
			actions = [
				{"name": "vampire_bite", "tempo_cost": 5},
				{"name": "absorb",       "tempo_cost": 3},
				{"name": "move",         "tempo_cost": 5},
			]
		EnemyType.NECROMANCER:
			actions = [
				{"name": "dark_bolt",        "tempo_cost": 5},
				{"name": "summon_skeleton",  "tempo_cost": 8},
				{"name": "move",             "tempo_cost": 6},
			]
		EnemyType.BONE_DRAGON:
			actions = [
				{"name": "dragon_bite",  "tempo_cost": 5},
				{"name": "breath_swarm", "tempo_cost": 6},
				{"name": "move",         "tempo_cost": 5},
			]
		EnemyType.SPIRIT_COLLECTOR:
			actions = [
				{"name": "collector_swing", "tempo_cost": 3},
				{"name": "collect_soul",    "tempo_cost": 8},
				{"name": "move",            "tempo_cost": 4},
			]
		EnemyType.GRAVE_TITAN:
			actions = [
				{"name": "titan_smash", "tempo_cost": 8},
				{"name": "boulder_roll","tempo_cost": 5},
				{"name": "move",        "tempo_cost": 8},
			]
		EnemyType.CRYPT_CRAWLER:
			actions = [
				{"name": "crawler_bite", "tempo_cost": 3},
				{"name": "web",          "tempo_cost": 3},
				{"name": "move",         "tempo_cost": 4},
			]
		EnemyType.SCREECHER:
			actions = [
				{"name": "screech", "tempo_cost": 5},
				{"name": "move",    "tempo_cost": 2},
			]
		EnemyType.CONSUMED:
			actions = [
				{"name": "attack", "tempo_cost": 5},
				{"name": "move",   "tempo_cost": 3},
			]

		# ===================== SEWER ACT =====================
		EnemyType.SLUDGE:
			actions = [
				{"name": "sludge_melee", "tempo_cost": 5},
				{"name": "sludge_spit",  "tempo_cost": 6},
				{"name": "move",         "tempo_cost": 5},
			]
		EnemyType.PIPE_CRAWLER:
			actions = [
				{"name": "pipe_attack", "tempo_cost": 5},
				{"name": "move",        "tempo_cost": 2},
			]
		EnemyType.SEWER_CROC:
			actions = [
				{"name": "croc_bite",   "tempo_cost": 6},
				# sheet: Venom Spray, 15 tempo, Async — it runs on its own
				# clock from the first tempo; Bite (Sync) may only START
				# counting on a tempo where this clock is back at 0
				# (docs/ENEMY_ACTION_KEYWORDS.md).
				{"name": "venom_spray", "tempo_cost": 15, "async": true, "label": "Venom Spray"},
				{"name": "move",        "tempo_cost": 5},
			]
		EnemyType.RAT_KING:
			actions = [
				{"name": "bite",   "tempo_cost": 3},
				# sheet: Infest, 5 tempo — an Infest card per rat within 10
				# squares (see _try_infest; the hand-side fuse is in
				# DeckManager._process_hatch_timers).
				{"name": "infest", "tempo_cost": 5},
				{"name": "move",   "tempo_cost": 2},
				# The lair: run for a nest, then feed on it (see _choose_rat_king_action).
				{"name": "seek_nest", "tempo_cost": 2, "label": "Flees to a nest"},
				{"name": "nest_heal", "tempo_cost": 2, "label": "Feeds on the nest"},
			]
		EnemyType.SWARM:
			actions = [
				{"name": "attack", "tempo_cost": 2},
				{"name": "move",   "tempo_cost": 3},
			]
		EnemyType.GRAVE_DIGGER:
			actions = [
				{"name": "dig_walk", "tempo_cost": 2, "label": "Walks to the broken stone"},
				{"name": "repair",   "tempo_cost": 8, "label": "Repairing the gravestone"},
			]
		EnemyType.CERBERUS:
			actions = [
				# sheet: Bite and Venom Tail are Async — their own clocks; the
				# Sync clock carries only Swipe / Roar / Move.
				{"name": "cerberus_bite", "tempo_cost": 5, "label": "Bite", "async": true},
				{"name": "swipe",         "tempo_cost": 8, "label": "Swipe"},
				{"name": "venom_tail",    "tempo_cost": 15, "label": "Venom Tail", "async": true},
				{"name": "cerberus_roar", "tempo_cost": 12, "label": "Roar"},
				{"name": "move",          "tempo_cost": 3},
			]

		# ===================== MOUNTAINS ACT =====================
		EnemyType.ICE_TROLL:
			actions = [
				{"name": "ice_club", "tempo_cost": 4},
				# Clobber (50 dmg) is never chosen — it auto-triggers when an
				# Ice Troll attack freezes its target (see _try_ice_club).
				{"name": "move",     "tempo_cost": 3},
			]
		EnemyType.WHITE_MANTICORE:
			actions = [
				{"name": "manticore_bite", "tempo_cost": 3},
				{"name": "stinger",        "tempo_cost": 5},
				{"name": "move",           "tempo_cost": 2},
			]
		EnemyType.WYVERN:
			actions = [
				{"name": "wyvern_bite", "tempo_cost": 5},
				{"name": "talon_grab",  "tempo_cost": 8},
				{"name": "move",        "tempo_cost": 4},
			]
		# ----- second pass (the enemy sheet) -----
		EnemyType.WEREGOAT:
			actions = [
				{"name": "hoof_punch",  "tempo_cost": 4},
				{"name": "goat_charge", "tempo_cost": 8},
				{"name": "move",        "tempo_cost": 5},
			]
		EnemyType.ROC:
			actions = [
				{"name": "dive_bomb",   "tempo_cost": 5},
				{"name": "eye_scrape",  "tempo_cost": 3, "async": true},
				{"name": "roc_retreat", "tempo_cost": 1, "label": "Move away"},
			]
		EnemyType.SABERTOOTH:
			actions = [
				{"name": "track",          "tempo_cost": 10, "async": true},
				{"name": "bite_and_claw",  "tempo_cost": 5},
				{"name": "sunken_bite",    "tempo_cost": 15, "async": true},
				{"name": "move",           "tempo_cost": 2},
			]
		EnemyType.SNOW_WRAITH:
			actions = [
				{"name": "snowball",  "tempo_cost": 8},
				{"name": "ice_blast", "tempo_cost": 5},  # the sheet gives Ice Blast no tempo — first-pass 5
				{"name": "move",      "tempo_cost": 5},
			]
		EnemyType.GRANITE_COLOSSUS:
			actions = []  # moves TBD on the sheet

		# ===================== UNDERWORLD ACT =====================
		EnemyType.DEMON:
			actions = [
				{"name": "mimic",        "tempo_cost": 8, "async": true},
				{"name": "demon_cuff",   "tempo_cost": 8, "async": true, "label": "Cuff"},
				{"name": "demon_attack", "tempo_cost": 5, "label": "Attack"},
				{"name": "move",         "tempo_cost": 2},
			]
		EnemyType.ASH_HARPY:
			actions = [
				{"name": "peck",       "tempo_cost": 5},
				{"name": "card_steal", "tempo_cost": 8},
				{"name": "move",       "tempo_cost": 1},
			]
		EnemyType.MAGMA_SPIDER:
			actions = [
				{"name": "fire_web", "tempo_cost": 8},  # the sheet gives no tempo — first-pass 8
			]
		EnemyType.MIND_EATER:
			actions = [
				{"name": "mind_slow", "tempo_cost": 10},
				{"name": "mind_cuff", "tempo_cost": 8, "label": "Manipulate Mind Space"},
			]
		EnemyType.SPECTER:
			actions = [
				{"name": "spirit_spit",    "tempo_cost": 5},
				{"name": "specter_vanish", "tempo_cost": 8, "async": true, "label": "Invisible"},
				{"name": "move",           "tempo_cost": 1},
			]
		EnemyType.SUCCUBUS:
			actions = [
				{"name": "mana_drain",    "tempo_cost": 10},
				{"name": "damaging_snap", "tempo_cost": 6},
				{"name": "move",          "tempo_cost": 2},
			]
		EnemyType.IFRIT:
			actions = [
				{"name": "ifrit_attack", "tempo_cost": 3},
				{"name": "fire_breath",  "tempo_cost": 8},
				{"name": "move",         "tempo_cost": 4},
			]
		EnemyType.INFLAMED_MINOTAUR:
			actions = [
				{"name": "minotaur_attack", "tempo_cost": 5},
				{"name": "bull_rush",       "tempo_cost": 5},
				{"name": "move",            "tempo_cost": 5},
			]

		# ===================== HEAVENS ACT =====================
		EnemyType.DJINN:
			actions = [
				{"name": "chain_lightning", "tempo_cost": 5},
				{"name": "move",            "tempo_cost": 3},
			]
		EnemyType.CHERUB:
			actions = [
				# The first arrow flies the moment the player enters its reach
				# (see _choose_cherub_action); every one after is on this clock.
				{"name": "loves_arrow", "tempo_cost": 10, "label": "Love's Arrow"},
				{"name": "move",        "tempo_cost": 3},
			]
	return actions

#endregion
#region ACTION KEYWORDS
# ============================================
# ACTION KEYWORDS — helpers shared by the AI, the overhead bar, the unit
# tracker, the inspect panel and the compendium.
# ============================================

static func is_async_action(action: Dictionary) -> bool:
	return bool(action.get("async", false))

static func is_trigger_action(action: Dictionary) -> bool:
	return str(action.get("trigger", "")) != ""

static func channel_of(action: Dictionary) -> int:
	return maxi(0, int(action.get("channel", 0)))

static func disrupt_threshold(action: Dictionary) -> int:
	return maxi(0, int(action.get("disrupt", 0)))

static func windup_of(action: Dictionary) -> int:
	## Tempo counted on the clock before the action resolves (or before its
	## channel begins). A stand-alone channel has no wind-up at all.
	return maxi(0, int(action.get("tempo_cost", 0)) - channel_of(action))

static func action_label(action: Dictionary) -> String:
	var lbl := str(action.get("label", ""))
	if lbl != "":
		return lbl
	return str(action.get("name", "")).capitalize()

static func action_keywords(action: Dictionary) -> Array[String]:
	## The NON-default keywords an action carries, in display order. Sync,
	## Immediate and Non-interruptible are the defaults and stay implicit.
	var out: Array[String] = []
	if is_trigger_action(action):
		out.append("Trigger: %s" % str(action["trigger"]).capitalize())
		return out
	if is_async_action(action):
		out.append("Async")
	if channel_of(action) > 0:
		out.append("Channel %d" % channel_of(action))
	if disrupt_threshold(action) > 0:
		out.append("Disruptable %d" % disrupt_threshold(action))
	return out

static func describe_action(action: Dictionary) -> String:
	## "Kick · 5 tempo · Async · Disruptable 10" — one line per action for
	## the inspect panel and compendium.
	var parts: Array[String] = [action_label(action)]
	if is_trigger_action(action):
		parts.append("Trigger: %s" % str(action["trigger"]).capitalize())
		return " · ".join(parts)
	parts.append("%d tempo" % int(action.get("tempo_cost", 0)))
	for kw in action_keywords(action):
		parts.append(kw)
	return " · ".join(parts)

func get_action_lines() -> Array[String]:
	## Every action this enemy has, described (inspect panel).
	var lines: Array[String] = []
	for a in actions:
		lines.append(describe_action(a))
	return lines

#endregion
#region COMPENDIUM DATA
# ============================================
# COMPENDIUM DATA
# ============================================

static func get_all_enemy_data() -> Array:
	## Returns compendium-friendly data for every enemy type.
	## Single source of truth — compendium reads from here.
	# Tier vocabulary = the designer's sheet (docs/ENEMY_SHEET.tsv, Tier
	# column): Trash / Mid-tier / Elite / Boss, "Special" for the Ring Wraith.
	# "Mid Tier" / "Mid-Tier" on the sheet are the one word "Mid-tier" here.
	# Structures and the dojo dummy are not on the sheet: they read "Special"
	# too (not creatures, no tier). The legacy MINION/ELITE/BOSS boxes keep
	# the three tiers they stood for. The loot tiers in
	# EnemySpawner.get_loot_tier follow the same column.
	var _type_display := {
		EnemyType.MINION: "Trash",
		EnemyType.ELITE: "Elite",
		EnemyType.BOSS: "Boss",
		# --- Sewer ---
		EnemyType.WERERAT: "Trash",
		EnemyType.ARCHER_RAT: "Trash",
		EnemyType.SLUDGE: "Trash",
		EnemyType.PIPE_CRAWLER: "Trash",
		EnemyType.SWARM: "Trash",
		EnemyType.SEWER_CROC: "Mid-tier",
		EnemyType.RAT_KING: "Boss",
		# --- Graveyard ---
		EnemyType.ZOMBIE: "Trash",
		EnemyType.WERERABBIT: "Trash",
		EnemyType.SCREECHER: "Trash",
		EnemyType.SKELETON: "Mid-tier",
		EnemyType.CRYPT_CRAWLER: "Mid-tier",
		EnemyType.CONSUMED: "Mid-tier",
		EnemyType.SPIRIT_COLLECTOR: "Mid-tier",
		EnemyType.WEREWOLF: "Elite",
		EnemyType.VAMPIRE: "Elite",
		EnemyType.NECROMANCER: "Elite",
		EnemyType.GRAVE_TITAN: "Elite",
		EnemyType.BONE_DRAGON: "Boss",
		# --- Cave ---
		EnemyType.FIRE_GOBLIN_SOLDIER: "Trash",
		EnemyType.FIRE_GOBLIN_MAGE: "Mid-tier",
		EnemyType.FIRE_GOBLIN_SHAMAN: "Mid-tier",
		EnemyType.ARMORED_TROLL: "Elite",
		EnemyType.HYDRA: "Elite",
		# --- Forest ---
		EnemyType.COYOTE: "Trash",
		EnemyType.MINI_BEAR: "Trash",
		EnemyType.WOLF: "Mid-tier",
		EnemyType.BUGBEAR: "Mid-tier",
		EnemyType.INFECTED_HUNTER: "Mid-tier",
		EnemyType.GIANT_HAWK: "Mid-tier",
		EnemyType.ICE_MAGE: "Mid-tier",
		EnemyType.FIRE_MAGE: "Mid-tier",
		EnemyType.SPARK_MAGE: "Mid-tier",
		EnemyType.AIR_MAGE: "Mid-tier",
		EnemyType.EARTH_MAGE: "Mid-tier",
		EnemyType.GIANT_BEAVER: "Elite",
		EnemyType.LARGE_BEAR: "Elite",
		EnemyType.TREANT: "Elite",
		# --- Mountains ---
		EnemyType.SNOW_WRAITH: "Trash",
		EnemyType.WEREGOAT: "Mid-tier",
		EnemyType.ROC: "Mid-tier",
		EnemyType.SABERTOOTH: "Mid-tier",
		EnemyType.WYVERN: "Elite",
		EnemyType.ICE_TROLL: "Elite",
		EnemyType.WHITE_MANTICORE: "Elite",
		EnemyType.GRANITE_COLOSSUS: "Boss",
		# --- Underworld ---
		EnemyType.ASH_HARPY: "Trash",
		EnemyType.MAGMA_SPIDER: "Trash",
		EnemyType.MIND_EATER: "Trash",
		EnemyType.SPECTER: "Trash",
		EnemyType.SUCCUBUS: "Trash",
		EnemyType.DEMON: "Mid-tier",
		EnemyType.IFRIT: "Elite",
		EnemyType.CERBERUS: "Boss",
		EnemyType.PIT_FIEND: "Boss",
		EnemyType.INFLAMED_MINOTAUR: "Boss",
		# --- Heavens ---
		EnemyType.CHERUB: "Trash",
		EnemyType.DJINN: "Elite",
		EnemyType.CORRUPTED_ARCHANGEL: "Boss",
		# --- Off the tier ladder ---
		EnemyType.RING_WRAITH: "Special",
		EnemyType.DUMMY: "Special",
		EnemyType.RAT_NEST: "Special",
		EnemyType.GRAVESTONE: "Special",
		EnemyType.GRAVE_DIGGER: "Special",
		EnemyType.HELL_DOOR: "Special",
	}
	var _stats := {
		EnemyType.MINION: {"name": "Minion", "health": 25, "armor": 0, "damage": 3, "xp": 5},
		EnemyType.ELITE: {"name": "Elite", "health": 80, "armor": 0, "damage": 6, "xp": 10},
		EnemyType.BOSS: {"name": "Boss", "health": 200, "armor": 0, "damage": 10, "xp": 25},
		EnemyType.WERERAT: {"name": "Wererat", "health": 8, "armor": 0, "damage": 3, "xp": 3},
		EnemyType.SKELETON: {"name": "Skeleton", "health": 20, "armor": 12, "damage": 6, "xp": 7},
		EnemyType.ARMORED_TROLL: {"name": "Armored Troll", "health": 60, "armor": 40, "damage": 7, "xp": 30},
		EnemyType.ARCHER_RAT: {"name": "Archer Rat", "health": 6, "armor": 0, "damage": 2, "xp": 4},
		EnemyType.HYDRA: {"name": "Hydra", "health": 190, "armor": 0, "damage": 7, "xp": 60},
		EnemyType.FIRE_GOBLIN_SOLDIER: {"name": "Fire Goblin Soldier", "health": 6, "armor": 0, "damage": 2, "xp": 3},
		EnemyType.FIRE_GOBLIN_MAGE: {"name": "Fire Goblin Mage", "health": 10, "armor": 0, "damage": 7, "xp": 8},
		EnemyType.FIRE_GOBLIN_SHAMAN: {"name": "Fire Goblin Shaman", "health": 16, "armor": 0, "damage": 6, "xp": 12},
		EnemyType.GIANT_BEAVER: {"name": "Giant Beaver", "health": 60, "armor": 0, "damage": 9, "xp": 20},
		EnemyType.MINI_BEAR: {"name": "Mini Bear", "health": 14, "armor": 0, "damage": 4, "xp": 6},
		EnemyType.LARGE_BEAR: {"name": "Large Bear", "health": 90, "armor": 0, "damage": 12, "xp": 35},
		EnemyType.WOLF: {"name": "Wolf", "health": 30, "armor": 0, "damage": 7, "xp": 12},
		EnemyType.COYOTE: {"name": "Coyote", "health": 6, "armor": 0, "damage": 2, "xp": 3},
		EnemyType.BUGBEAR: {"name": "Bugbear", "health": 50, "armor": 0, "damage": 6, "xp": 20},
		EnemyType.INFECTED_HUNTER: {"name": "Infected Hunter", "health": 40, "armor": 0, "damage": 8, "xp": 18},
		EnemyType.GIANT_HAWK: {"name": "Giant Hawk", "health": 28, "armor": 0, "damage": 9, "xp": 14},
		EnemyType.TREANT: {"name": "Treant", "health": 110, "armor": 0, "damage": 14, "xp": 35},
		EnemyType.ICE_MAGE: {"name": "Ice Mage", "health": 40, "armor": 0, "damage": 6, "xp": 14},
		EnemyType.FIRE_MAGE: {"name": "Fire Mage", "health": 32, "armor": 0, "damage": 7, "xp": 14},
		EnemyType.SPARK_MAGE: {"name": "Spark Mage", "health": 16, "armor": 0, "damage": 3, "xp": 8},
		EnemyType.AIR_MAGE: {"name": "Air Mage", "health": 30, "armor": 0, "damage": 5, "xp": 12},
		EnemyType.EARTH_MAGE: {"name": "Earth Mage", "health": 65, "armor": 0, "damage": 9, "xp": 18},
		EnemyType.ZOMBIE: {"name": "Zombie", "health": 12, "armor": 0, "damage": 5, "xp": 5},
		EnemyType.WEREWOLF: {"name": "Werewolf", "health": 55, "armor": 0, "damage": 10, "xp": 22},
		EnemyType.WERERABBIT: {"name": "Wererabbit", "health": 25, "armor": 0, "damage": 0, "xp": 8},
		EnemyType.VAMPIRE: {"name": "Vampire", "health": 95, "armor": 0, "damage": 10, "xp": 24},
		EnemyType.NECROMANCER: {"name": "Necromancer", "health": 60, "armor": 0, "damage": 4, "xp": 30},
		EnemyType.BONE_DRAGON: {"name": "Bone Dragon", "health": 150, "armor": 0, "damage": 12, "xp": 80},
		EnemyType.SPIRIT_COLLECTOR: {"name": "Spirit Collector", "health": 50, "armor": 0, "damage": 8, "xp": 20},
		EnemyType.GRAVE_TITAN: {"name": "Grave Titan", "health": 130, "armor": 30, "damage": 15, "xp": 80},
		EnemyType.CRYPT_CRAWLER: {"name": "Crypt Crawler", "health": 28, "armor": 0, "damage": 6, "xp": 12},
		EnemyType.SCREECHER: {"name": "Screecher", "health": 14, "armor": 0, "damage": 5, "xp": 8},
		EnemyType.CONSUMED: {"name": "The Consumed", "health": 35, "armor": 0, "damage": 8, "xp": 14},
		EnemyType.SLUDGE: {"name": "Sludge Being", "health": 10, "armor": 0, "damage": 3, "xp": 4},
		EnemyType.PIPE_CRAWLER: {"name": "Pipe Crawler", "health": 20, "armor": 0, "damage": 5, "xp": 8},
		EnemyType.SEWER_CROC: {"name": "Sewer Cobra", "health": 40, "armor": 20, "damage": 12, "xp": 25},
		EnemyType.RAT_KING: {"name": "Rat King", "health": 90, "armor": 10, "damage": 6, "xp": 60},
		EnemyType.SWARM: {"name": "Swarm", "health": 10, "armor": 0, "damage": 3, "xp": 4},
		EnemyType.WEREGOAT: {"name": "Weregoat", "health": 80, "armor": 0, "damage": 6, "xp": 20},
		EnemyType.WYVERN: {"name": "Wyvern", "health": 125, "armor": 0, "damage": 25, "xp": 40},
		EnemyType.ROC: {"name": "Roc", "health": 25, "armor": 15, "damage": 8, "xp": 16},
		EnemyType.ICE_TROLL: {"name": "Ice Troll", "health": 150, "armor": 55, "damage": 13, "xp": 45},
		EnemyType.SNOW_WRAITH: {"name": "Snow Wraith", "health": 10, "armor": 0, "damage": 5, "xp": 8},
		EnemyType.GRANITE_COLOSSUS: {"name": "Granite Colossus", "health": 350, "armor": 250, "damage": 0, "xp": 120},
		EnemyType.WHITE_MANTICORE: {"name": "White Manticore", "health": 75, "armor": 15, "damage": 15, "xp": 40},
		EnemyType.SABERTOOTH: {"name": "Sabertooth Tiger", "health": 45, "armor": 0, "damage": 6, "xp": 18},
		EnemyType.CERBERUS: {"name": "Cerberus", "health": 250, "armor": 50, "damage": 25, "xp": 150},
		EnemyType.SUCCUBUS: {"name": "Succubus", "health": 25, "armor": 5, "damage": 4, "xp": 14},
		EnemyType.DEMON: {"name": "Demon", "health": 65, "armor": 0, "damage": 8, "xp": 24},
		EnemyType.IFRIT: {"name": "Ifrit", "health": 225, "armor": 0, "damage": 45, "xp": 70},
		EnemyType.MIND_EATER: {"name": "Mind Eater", "health": 20, "armor": 0, "damage": 0, "xp": 12},
		EnemyType.SPECTER: {"name": "Specter", "health": 10, "armor": 0, "damage": 2, "xp": 4},
		EnemyType.MAGMA_SPIDER: {"name": "Magma Spider", "health": 4, "armor": 0, "damage": 1, "xp": 3},
		EnemyType.PIT_FIEND: {"name": "Pit Fiend", "health": 0, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.ASH_HARPY: {"name": "Ash Harpy", "health": 6, "armor": 0, "damage": 3, "xp": 4},
		EnemyType.INFLAMED_MINOTAUR: {"name": "Inflamed Minotaur", "health": 350, "armor": 100, "damage": 35, "xp": 90},
		EnemyType.CHERUB: {"name": "Cherub", "health": 14, "armor": 5, "damage": 2, "xp": 10},
		EnemyType.DJINN: {"name": "Djinn", "health": 180, "armor": 0, "damage": 35, "xp": 80},
		EnemyType.CORRUPTED_ARCHANGEL: {"name": "Corrupted Archangel", "health": 0, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.RING_WRAITH: {"name": "Ring Wraith", "health": 100, "armor": 0, "damage": 15, "xp": 0},
		EnemyType.DUMMY: {"name": "Training Dummy", "health": 500, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.RAT_NEST: {"name": "Rat Nest", "health": 15, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.GRAVESTONE: {"name": "Gravestone", "health": 10, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.GRAVE_DIGGER: {"name": "Grave Digger", "health": 20, "armor": 0, "damage": 0, "xp": 6},
		EnemyType.HELL_DOOR: {"name": "Hell's Door", "health": 150, "armor": 0, "damage": 0, "xp": 0},
	}
	var _actions := {
		EnemyType.MINION: [{"name": "Attack", "tempo": 3}, {"name": "Move", "tempo": 5}],
		EnemyType.ELITE: [{"name": "Attack", "tempo": 4}, {"name": "Move", "tempo": 6}],
		EnemyType.BOSS: [{"name": "Attack", "tempo": 5}, {"name": "Move", "tempo": 8}],
		EnemyType.WERERAT: [{"name": "Move", "tempo": 2}, {"name": "Bite", "tempo": 2}, {"name": "Scurry", "tempo": 4}],
		EnemyType.SKELETON: [{"name": "Move", "tempo": 5}, {"name": "Attack", "tempo": 4}],
		EnemyType.ARMORED_TROLL: [{"name": "Move", "tempo": 4}, {"name": "Kick", "tempo": 3}, {"name": "Smash", "tempo": 5}],
		EnemyType.ARCHER_RAT: [{"name": "Shoot", "tempo": 5}, {"name": "Scurry Away", "tempo": 2}, {"name": "Get Into Range", "tempo": 2}],
		EnemyType.HYDRA: [{"name": "Strike", "tempo": 8}, {"name": "Move", "tempo": 6}, {"name": "Heal", "tempo": 5}],
		EnemyType.FIRE_GOBLIN_SOLDIER: [{"name": "Attack", "tempo": 3}, {"name": "Move", "tempo": 2}],
		EnemyType.FIRE_GOBLIN_MAGE: [{"name": "Ember", "tempo": 4}, {"name": "Move", "tempo": 3}],
		EnemyType.FIRE_GOBLIN_SHAMAN: [{"name": "Fire Wall", "tempo": 8}, {"name": "Sear Wounds", "tempo": 6}, {"name": "Move", "tempo": 3}],
		EnemyType.GIANT_BEAVER: [{"name": "Chomp", "tempo": 4}, {"name": "Tail Whip", "tempo": 2}, {"name": "Move", "tempo": 6}],
		EnemyType.MINI_BEAR: [{"name": "Attack", "tempo": 3}, {"name": "Move", "tempo": 5}],
		EnemyType.LARGE_BEAR: [{"name": "Maul", "tempo": 4}, {"name": "Roar", "tempo": 3}, {"name": "Move", "tempo": 7}],
		EnemyType.WOLF: [{"name": "Bite", "tempo": 5}, {"name": "Move", "tempo": 3}],
		EnemyType.COYOTE: [{"name": "Nip", "tempo": 4}, {"name": "Move", "tempo": 3}],
		EnemyType.BUGBEAR: [{"name": "Strike", "tempo": 5}, {"name": "Move", "tempo": 4}],
		EnemyType.INFECTED_HUNTER: [{"name": "Hook", "tempo": 8}, {"name": "Cleave", "tempo": 3}, {"name": "Net Throw", "tempo": 2}, {"name": "Move", "tempo": 3}],
		EnemyType.GIANT_HAWK: [{"name": "Swoop", "tempo": 4}, {"name": "Move", "tempo": 3}],
		EnemyType.TREANT: [{"name": "Slam", "tempo": 10}, {"name": "Root", "tempo": 8}, {"name": "Heal", "tempo": 5}, {"name": "Move", "tempo": 10}],
		EnemyType.ICE_MAGE: [{"name": "Frost Bolt", "tempo": 3}, {"name": "Move", "tempo": 5}],
		EnemyType.FIRE_MAGE: [{"name": "Fire Bolt", "tempo": 3}, {"name": "Move", "tempo": 3}],
		EnemyType.SPARK_MAGE: [{"name": "Spark", "tempo": 2}, {"name": "Move", "tempo": 3}],
		EnemyType.AIR_MAGE: [{"name": "Gust", "tempo": 5}, {"name": "Move", "tempo": 3}],
		EnemyType.EARTH_MAGE: [{"name": "Boulder", "tempo": 6}, {"name": "Move", "tempo": 5}],
		EnemyType.ZOMBIE: [{"name": "Attack", "tempo": 6}, {"name": "Move", "tempo": 8}],
		EnemyType.WEREWOLF: [{"name": "Claw", "tempo": 5}, {"name": "Move", "tempo": 3}],
		EnemyType.WERERABBIT: [{"name": "Flee", "tempo": 1}, {"name": "Vanish", "tempo": 1}],
		EnemyType.VAMPIRE: [{"name": "Bite", "tempo": 5}, {"name": "Absorb", "tempo": 3}, {"name": "Move", "tempo": 5}],
		EnemyType.NECROMANCER: [{"name": "Bolt", "tempo": 5}, {"name": "Summon", "tempo": 8}, {"name": "Move", "tempo": 6}],
		EnemyType.BONE_DRAGON: [{"name": "Bite", "tempo": 5}, {"name": "Breath", "tempo": 6}, {"name": "Move", "tempo": 5}],
		EnemyType.SPIRIT_COLLECTOR: [{"name": "Strike", "tempo": 3}, {"name": "Collect Soul", "tempo": 8}, {"name": "Move", "tempo": 4}],
		EnemyType.GRAVE_TITAN: [{"name": "Smash", "tempo": 8}, {"name": "Boulder Roll", "tempo": 5}, {"name": "Move", "tempo": 8}],
		EnemyType.CRYPT_CRAWLER: [{"name": "Bite", "tempo": 3}, {"name": "Web", "tempo": 3}, {"name": "Move", "tempo": 4}],
		EnemyType.SCREECHER: [{"name": "Screech", "tempo": 5}, {"name": "Drift", "tempo": 2}],
		EnemyType.CONSUMED: [{"name": "Attack", "tempo": 5}, {"name": "Move", "tempo": 3}],
		EnemyType.SLUDGE: [{"name": "Melee", "tempo": 5}, {"name": "Spit", "tempo": 6}, {"name": "Move", "tempo": 5}],
		EnemyType.PIPE_CRAWLER: [{"name": "Claw", "tempo": 5}, {"name": "Move", "tempo": 2}],
		EnemyType.SEWER_CROC: [{"name": "Bite", "tempo": 6}, {"name": "Venom Spray", "tempo": 15}, {"name": "Move", "tempo": 5}],
		EnemyType.RAT_KING: [{"name": "Bite", "tempo": 3}, {"name": "Infest", "tempo": 5}, {"name": "Move", "tempo": 2}, {"name": "Flee to a nest", "tempo": 2}, {"name": "Feed on the nest", "tempo": 2}],
		EnemyType.SWARM: [{"name": "Attack", "tempo": 2}, {"name": "Move", "tempo": 3}],
		EnemyType.WEREGOAT: [{"name": "Hoof Punch", "tempo": 4}, {"name": "Charge", "tempo": 8}, {"name": "Move", "tempo": 5}],
		EnemyType.ROC: [{"name": "Dive Bomb", "tempo": 5}, {"name": "Eye Scrape", "tempo": 3}, {"name": "Move away", "tempo": 1}],
		EnemyType.WYVERN: [{"name": "Bite", "tempo": 5}, {"name": "Talon Grab", "tempo": 8}, {"name": "Move", "tempo": 4}],
		EnemyType.ICE_TROLL: [{"name": "Club", "tempo": 4}, {"name": "Move", "tempo": 3}],
		EnemyType.SNOW_WRAITH: [{"name": "Snowball", "tempo": 8}, {"name": "Ice Blast", "tempo": 5}, {"name": "Move", "tempo": 5}],
		EnemyType.GRANITE_COLOSSUS: [],
		EnemyType.WHITE_MANTICORE: [{"name": "Bite", "tempo": 3}, {"name": "Stinger", "tempo": 5}, {"name": "Move", "tempo": 2}],
		EnemyType.SABERTOOTH: [{"name": "Track", "tempo": 10}, {"name": "Bite and Claw", "tempo": 5}, {"name": "Sunken Bite", "tempo": 15}, {"name": "Move", "tempo": 2}],
		EnemyType.CERBERUS: [{"name": "Bite", "tempo": 5}, {"name": "Swipe", "tempo": 8}, {"name": "Venom Tail", "tempo": 15}, {"name": "Roar", "tempo": 12}, {"name": "Move", "tempo": 3}],
		EnemyType.SUCCUBUS: [{"name": "Mana Drain", "tempo": 10}, {"name": "Damaging Snap", "tempo": 6}, {"name": "Move", "tempo": 2}],
		EnemyType.DEMON: [{"name": "Mimic", "tempo": 8}, {"name": "Cuff", "tempo": 8}, {"name": "Attack", "tempo": 5}, {"name": "Move", "tempo": 2}],
		EnemyType.IFRIT: [{"name": "Attack", "tempo": 3}, {"name": "Fire Breath", "tempo": 8}, {"name": "Move", "tempo": 4}],
		EnemyType.MIND_EATER: [{"name": "Mind Slow", "tempo": 10}, {"name": "Manipulate Mind Space", "tempo": 8}],
		EnemyType.SPECTER: [{"name": "Spirit Spit", "tempo": 5}, {"name": "Invisible", "tempo": 8}, {"name": "Move", "tempo": 1}],
		EnemyType.MAGMA_SPIDER: [{"name": "Fire Web", "tempo": 8}],
		EnemyType.PIT_FIEND: [],
		EnemyType.ASH_HARPY: [{"name": "Peck", "tempo": 5}, {"name": "Card Steal", "tempo": 8}, {"name": "Move", "tempo": 1}],
		EnemyType.INFLAMED_MINOTAUR: [{"name": "Attack", "tempo": 5}, {"name": "Bull Rush", "tempo": 5}, {"name": "Move", "tempo": 5}],
		EnemyType.CHERUB: [{"name": "Love's Arrow", "tempo": 10}, {"name": "Move", "tempo": 3}],
		EnemyType.DJINN: [{"name": "Chain Lightning", "tempo": 5}, {"name": "Move", "tempo": 3}],
		EnemyType.CORRUPTED_ARCHANGEL: [],
		EnemyType.RING_WRAITH: [{"name": "Attack", "tempo": 2}, {"name": "Move", "tempo": 4}],
		EnemyType.DUMMY: [],
		EnemyType.RAT_NEST: [],
		EnemyType.GRAVESTONE: [],
		EnemyType.GRAVE_DIGGER: [{"name": "Walk", "tempo": 2}, {"name": "Repair", "tempo": 8}],
		EnemyType.HELL_DOOR: [],
	}
	var _specials := {
		EnemyType.MINION: "Basic enemy.\nAt range ≤1: Attacks.\nOtherwise: Moves toward player.",
		EnemyType.ELITE: "Stronger than minions.\nAt range ≤1: Attacks.\nOtherwise: Moves toward player.",
		EnemyType.BOSS: "High health and damage.\nAt range ≤1: Attacks.\nOtherwise: Moves toward player.",
		EnemyType.WERERAT: "Fast and evasive (8 HP, 3 dmg).\nAt range ≤1: Bites.\nAt range ≥6: Scurries 5 tiles toward you.\nOtherwise: Moves toward player.",
		EnemyType.SKELETON: "Has armor that must be broken.\nAt range ≤1: Attacks.\nOtherwise: Moves toward player.",
		EnemyType.ARMORED_TROLL: "Regenerates 3 HP every 6 global tempo. Resists 30% physical / 15% fire / 15% lightning.\nAt range ≤1: 60% Smash (5 tempo, 14 dmg + Lightly Dazed card) / 40% Kick (3 tempo, 6 dmg).\nMove (4 tempo): 2 spaces.",
		EnemyType.ARCHER_RAT: "Ranged attacker (range 4).\nAt range ≤2: Scurries 5 tiles away.\nAt range 3-4: Shoots for 2 damage.\nAt range >4: Moves 2 tiles closer.",
		EnemyType.HYDRA: "Resists 25% physical / fire / lightning. Grows stronger with every hit she takes, whoever or whatever lands it: +2 strength per hit. On the 4th hit she also gains +40 max HP and unlocks Heal.\nStrike (8 tempo): 7 + strength damage.\nMove (6 tempo): 3 spaces.\nHeal (5 tempo): heals to full (after the 4th hit).",
		EnemyType.FIRE_GOBLIN_SOLDIER: "Melee rusher (range 0).\nAttack (3 tempo): 2 damage.\nMove (2 tempo): 4 spaces.",
		EnemyType.FIRE_GOBLIN_MAGE: "Ranged caster (range 4).\nEmber (4 tempo): 7 damage + 1 burn.\nMove (3 tempo): 2 spaces.",
		EnemyType.FIRE_GOBLIN_SHAMAN: "Support caster (range 5).\nFire Wall (8 tempo): raises a wall; if the player walks into it they take 6 damage + 3 burn.\nSear Wounds (6 tempo): 2 damage to all allies (can kill), then heals survivors 6.\nMove (3 tempo): 2 spaces.",
		EnemyType.GIANT_BEAVER: "Resists 25% physical.\nChomp (4 tempo): 9 damage, stuns 3 tempo. Then Tail Whip (2 tempo later): 6 damage + 5 Vulnerable (15 tempo).\nMove (6 tempo): 3 spaces.",
		EnemyType.MINI_BEAR: "Travels in packs. When a packmate in sight is hurt, gains +2 attack damage.\nAttack (3 tempo): 4 damage.\nMove (5 tempo): 5 spaces.",
		EnemyType.LARGE_BEAR: "Below 50% HP: gains 30% physical resistance FOREVER, and rages — attacks deal 1.5x, apply double Bleed, and the bear heals from your bleed damage. With Mini Bears present, gains 1 Strengthen (+1 damage) every time it is hurt. Drops to all fours below 20% HP.\nMaul (4 tempo): 12 damage + 4 Bleed.\nRoar (3 tempo, every 15 tempo): Vulnerable to everything within 4 squares.\nMove (7 tempo): 6 spaces.",
		EnemyType.WOLF: "Within 4 tiles of another wolf: +2 HP regen/cycle and +2 attack damage.\nBite (5 tempo): 7 damage.\nMove (3 tempo): 4 spaces.",
		EnemyType.COYOTE: "Fragile nuisance.\nNip (4 tempo): 2 damage.\nMove (3 tempo): 4 spaces.",
		EnemyType.BUGBEAR: "First Strike: if it hits you before you have hit it, +8 damage.\nStrike (5 tempo): 6 damage.\nMove (4 tempo): 6 spaces.",
		EnemyType.INFECTED_HUNTER: "Hook (range 2-7, 8 tempo): reels you in beside it. The first hook is ready at once; after each one it takes 8 tempo to recharge.\nCleave (3 tempo): 8 damage to everything on the three squares in front of it.\nNet Throw (2 tempo, within 3 squares, 8-tempo cooldown): Weighted for every card in your hand — each card costs +2 tempo until that many have been played.\nMove (3 tempo): 2 spaces.",
		EnemyType.GIANT_HAWK: "Flying — ignores your high-ground bonus.\nSwoop (4 tempo, reach 2): 9 damage, 20% to Blind for 5 tempo.\nMove (3 tempo): 8 spaces.",
		EnemyType.TREANT: "Heals 5 HP every 5 tempo, +2 per 10% HP below 60%. Every 10 tempo, strips all thorns from its enemies and heals for the total. Resists 25% physical / 55% lightning, but takes 10% EXTRA fire damage.\nSlam (10 tempo): 14 earth damage.\nRoot (8 tempo): pins you for 8 tempo (can attack, cannot move).\nHeal (5 tempo): when badly hurt and out of melee, it stops to mend.\nMove (10 tempo): 9 spaces.",
		EnemyType.ICE_MAGE: "Attacks Slow your movement.\nFrost Bolt (range 3, 3 tempo): 6 ice damage + Slow.\nMove (5 tempo): 3 spaces.",
		EnemyType.FIRE_MAGE: "Attacks apply 2 Burn.\nFire Bolt (range 2, 3 tempo): 7 fire damage + 2 Burn.\nMove (3 tempo): 2 spaces.",
		EnemyType.SPARK_MAGE: "Attacks apply 1 Shock.\nSpark (range 6, 2 tempo): 3 lightning damage + 1 Shock.\nMove (3 tempo): 2 spaces.",
		EnemyType.AIR_MAGE: "Long-range caster.\nGust (range 8, 5 tempo): 5 wind damage.\nMove (3 tempo): 6 spaces.",
		EnemyType.EARTH_MAGE: "Gains 4 armor every time it is hit.\nBoulder (melee, 6 tempo): 9 earth damage.\nMove (5 tempo): 5 spaces.",
		EnemyType.ZOMBIE: "Slow, beefy undead.\nAt range ≤1: Attacks (5 dmg, 6 tempo).\nOtherwise: shambles toward player (3 spaces / 8 tempo).",
		EnemyType.WEREWOLF: "Bear-sized grey beast with armor-piercing claws. Resists 25% physical/fire/lightning.\nClaw (5 tempo): 10 damage, +3 vs armor; a debuffed target is raked a SECOND time for half. Each consecutive claw on the same target arms 1 tempo faster (5, 4, 3...); switching targets resets it.\nMove (3 tempo): 3 spaces.",
		EnemyType.WERERABBIT: "Loot monster — does not attack.\nFlees for 3 cycles, then Vanishes in a puff of smoke.\nMove (1 tempo): 2 spaces.",
		EnemyType.VAMPIRE: "Victorian aristocrat with life steal. Resists 10% physical/fire/lightning.\nBite (5 tempo): 10 damage; heals 100% of damage dealt to HEALTH (not armor).\nBat Form (below 50% HP, 2 charges, never recharges): flits 6 squares away...\nAbsorb (3 tempo, always right after Bat Form): drains the healthiest ally on the map (you included) — 20 the first time, then 10.\nMove (5 tempo): 5 spaces.",
		EnemyType.NECROMANCER: "Hooded caster (range 10) who raises the dead. Resists 15% fire/lightning.\nBolt (5 tempo): 4 damage + Hexes 2 cards in your hand (each +30 mana until played).\nSummon (8 tempo): raises undead (skeletons and zombies, first pass). After 5 of its summons die, it raises a BONE DRAGON.\nMove (6 tempo): 8 spaces.",
		EnemyType.BONE_DRAGON: "Skeletal wyrm. Summoned by the Necromancer, but also roams freely; fought as a boss in the Boneyard, where every standing gravestone regenerates it 1 health a cycle (Gravebound — break the stones, and kill the diggers who repair them). Resists 45% physical / 45% fire.\nBite (5 tempo): 12 damage.\nBreath Swarm (6 tempo): 12 damage down a 6-tile line; a Swarm hatches beside everyone it hits.\nMove (5 tempo): 5 spaces.",
		EnemyType.SPIRIT_COLLECTOR: "Lantern-bearer with a soul cage on its back. Strengthen it gains adds to every Strike and Collect Soul and never fades.\nStrike (3 tempo): 8 damage.\nCollect Soul (8 tempo): 8 damage; adds a 'Release Soul' card to your hand. While it is in your hand you are Drained (10 mana a cycle) and it saps 1 damage per tempo (charged 5 at each cycle). Play it (15 mana, 2 tempo) to be rid of it — but releasing the soul gives every living Spirit Collector 5 Strengthen.",
		EnemyType.GRAVE_TITAN: "Yeti-like brute (30 armor) hauling a boulder.\nSmash (8 tempo): 15 damage in front.\nBoulder Roll (range 3, 5 tempo): rolls the boulder for 15 damage.\nMove (8 tempo): 4 spaces.",
		EnemyType.CRYPT_CRAWLER: "Large spider. After 3 consecutive attacks it webs you.\nBite (3 tempo): 6 damage.\nWeb: adds a 'Paralysis' card to your hand — you cannot move until it is played (10 mana, 5 tempo; other actions are fine), then it is erased.\nMove (4 tempo): 3 spaces.",
		EnemyType.SCREECHER: "Soul-creature — a barely-there black void ghost, easiest to spot when it strikes.\nScreech (5 tempo): 5 damage.\nDrift (2 tempo): 4 spaces.",
		EnemyType.CONSUMED: "Flesh-and-hatred golem; muscle shows through its lacerations.\nAttack (5 tempo): 8 damage.\nMove (3 tempo): 5 spaces.\nOn death: explodes for 8 damage to everything nearby.",
		# --- Mountains ---
		EnemyType.WEREGOAT: "Minotaur-built: human torso and arms, goat head and goat hind legs.\nHoof Punch (4 tempo): 6 damage.\nCharge (8 tempo): runs up to 8 squares along the line that crosses the most of your units — 8 damage to everything in its path, and everything within 1 square of where it lands is Stunned for 3 tempo.\nMove (5 tempo): 2 spaces.",
		EnemyType.WYVERN: "A large serpentine flier with talons and wings — no arms. Flying: ignores your high-ground bonus. Resists 25% physical / 35% fire / 25% lightning.\nBite (5 tempo): 25 damage.\nTalon Grab (8 tempo, then 2-cycle cooldown): flies above its target (reach 3), 25 damage, and drags them to an unoccupied space 8 squares away.\nMove (4 tempo): 6 spaces.",
		EnemyType.ROC: "An enormous bird with huge talons and a white-checkered mane (15 armor). Flying: ignores your high-ground bonus. It always moves AWAY from you: it dives, then keeps its distance until the dive is ready again.\nDive Bomb (5 tempo, from up to 6 squares): 8 damage; the Roc lands beside you.\nEye Scrape (3 tempo, Async): if you have stayed in melee reach for more than 3 tempo it claws your eyes — 2 Weakened.\nMove away (1 tempo): 1 space.",
		EnemyType.ICE_TROLL: "Bigger than the Armored Troll — taller, with massive hands and feet; no weapon. Every attack adds a stack of frost (Cold) AND Brittle. Resists 35% physical / 15% fire / 15% lightning.\nClub (4 tempo): 13 damage.\nClobber (auto): 50 damage — triggers instantly whenever an Ice Troll attack FREEZES its target.\nMove (3 tempo): 3 spaces.",
		EnemyType.SNOW_WRAITH: "A pale mountain spirit trailing tattered cloth (range 5).\nSnowball (8 tempo): Slowed for 3 tempo + 2 Cold.\nIce Blast (5 tempo): 5 ice damage, +3 if you have armor; Slowed for 3 tempo.\nMove (5 tempo): 3 spaces.",
		EnemyType.GRANITE_COLOSSUS: "A huge rigid figure of mountain stone that emerges from the rock face — hard to spot before it moves. 350 health under 250 armor; resists 65% physical / 50% fire / 50% lightning.\nMove (5 tempo): 3 spaces.\n[Its attacks are still TBD on the design sheet — it only stands.]",
		EnemyType.WHITE_MANTICORE: "A manticore with a snow-leopard body, bat wings and a spiked tail. Flying: ignores your high-ground bonus. Resists 10% physical / 35% fire / 10% lightning.\nBite (3 tempo): 15 damage.\nStinger (5 tempo, then 5-tempo cooldown): 25 damage + Clumsy for 3 cycles (15 tempo) + 8 Poison.\nMove (2 tempo): 3 spaces.",
		EnemyType.SABERTOOTH: "A sabertooth tiger. 35% to crit: a crit deals 1.5x and inflicts 6 Bleed.\nTrack (10 tempo, Async): marks the nearest of your units — +15 Strengthen against it, and the tiger must hunt it.\nBite and Claw (5 tempo): bites for 6, then claws for 3 — two separate attacks (each rolls its own crit and spends its own Strengthen).\nSunken Bite (15 tempo, Async): 10 damage + 8 Bleed.\nMove (2 tempo): 2 spaces.",
		# --- Underworld ---
		EnemyType.CERBERUS: "Three-headed hound with spiked collars and a chain on the left head: the guardian of Hell's Door. Resists 30% physical / 40% fire / 15% lightning. You need not kill him — only break the door he guards — but it is far easier with him dead.\nBite (5 tempo, Async): 25 damage. Below 66% health the second head bites too (25 + 5 Bleed); below 33% the third head as well (25, and he feeds on the wound). A bite that comes up out of reach is spent.\nSwipe (8 tempo): 8 Bleed.\nVenom Tail (15 tempo, Async): you discard 3 random cards and are stunned for 15 tempo; the moment the stun is gone, 2 Vulnerable and Cuffed for 10 tempo.\nRoar (12 tempo): +25 armor and 25 thorns.\nMove (3 tempo): 6 spaces.\nGuardian of Death: Brace 30% for 5 hits the first time he drops below half, and again EVERY time any unit within 8 squares — foe or ally, the door included — drops below half.\nDeathyard Dog: a foe healing within 5 squares gives him 15 Strengthen.",
		EnemyType.SUCCUBUS: "A winged fey: short shorts, sleeveless top, elbow gloves, long boots and small horns (5 armor, range 4).\nMana Drain (10 tempo): drains 10 mana from your pool.\nDamaging Snap (6 tempo): damage equal to your missing mana / 20, + 4.\nMove (2 tempo): 1 space.",
		EnemyType.DEMON: "A red, thorned demon wielding a dagger and a trident.\nMimic (8 tempo, Async): conjures a duplicate of itself — it looks identical (health, buffs and debuffs all copied) but has 1 health, and hits as hard as the real one. At most 2 mimics per demon.\nCuff (8 tempo, Async): you cannot draw for 15 tempo.\nAttack (5 tempo): 8 damage.\nMove (2 tempo): 2 spaces.",
		EnemyType.IFRIT: "A muscular bipedal fire-hound, hunched, with long near-ground arms. Resists 20% physical / 15% fire / 15% lightning.\nAttack (3 tempo): 45 damage.\nFire Breath (8 tempo, used from up to 4 tiles out): a 5x5 sheet of flame in front — 20 fire damage + 5 Burn; the tiles keep burning for 3 tempo.\nBackflip (auto): a single blow over 40 damage sends it leaping 3 squares backwards.\nMove (4 tempo): 5 spaces.",
		EnemyType.MIND_EATER: "A gaunt, hunched flesh-horror with long raking claws. It never moves (range 6).\nMind Slow (10 tempo): every card in your hand costs 20 more mana.\nManipulate Mind Space (8 tempo): you cannot draw for 15 tempo.",
		EnemyType.SPECTER: "A dark shadow-form of a humanoid.\nSpirit Spit (5 tempo, range 2): 2 damage.\nInvisible (8 tempo, Async): fades out for 3 tempo — it cannot be targeted.\nMove (1 tempo): 1 space.",
		EnemyType.MAGMA_SPIDER: "A large tarantula in red, orange and black with glowing seams. It never moves.\nFire Web (8 tempo): spins a web of fire on the ground around it — while you stand in it you are Slowed and take 1 fire damage every 3 tempo.",
		EnemyType.PIT_FIEND: "A larger, regal demon with a barbed tail and a great whip.\n[Design mock-up — stats & moves TBD.]",
		EnemyType.ASH_HARPY: "A harpy seemingly risen from and made of ash. Flying: ignores your high-ground bonus.\nPeck (5 tempo): 3 damage.\nCard Steal (8 tempo, once per harpy): spots a card from 4 squares, flies in to melee and snatches it from your hand; kill the harpy and the card comes back.\nMove (1 tempo): 1 space.",
		EnemyType.INFLAMED_MINOTAUR: "The boss of the Labyrinth, off the Underworld's deepest cave: a smouldering minotaur with a fiery axe. Leaves fire in its wake (a trap on every tile it walks off — and along every charge: 10 damage + 2 Burn, lingers 15 tempo) and heals 10 whenever that fire burns a player. Resists 15% physical / 50% fire / 25% lightning. Slow is his weakness: every Slow stack shortens the leap (Sword of Theseus).\nAttack (5 tempo): 35 damage + 2 Burn.\nLabyrinth Leap (auto, once he has taken over 20 damage since his last leap — a running total, not one blow): springs away 14 spaces (minus 1 per Slow) to a random open tile.\nBull Rush (a random 5 to 15 tempo after landing): charges the player — damage equals the spaces covered by leap + rush, with a spaces x4% chance to stun (5 tempo) AND weaken; the target and everything trampled en route are left Vulnerable.\nMove (5 tempo): 6 spaces.\nThe room: every 25 tempo you are Lost in the Labyrinth for 15 — your hand is scrambled, must be played left to right, and you cannot draw.",
		# --- Heavens ---
		EnemyType.CHERUB: "An adult cupid — winged archer with a bow (5 armor, range 4).\nLove's Arrow: 2 damage, and for 5 tempo you cannot attack the Cherub directly (poison, burn and area damage still land). The first arrow flies the moment you enter its reach; after that it is a 10-tempo attack.\nMove (3 tempo): 2 spaces.",
		EnemyType.DJINN: "A blue genie with bracelets, a black ponytail and a red necklace. Every attack against the Djinn puts 3 WISHES in your hand — each sears you for 1/3 of that attack's damage every cycle it is held, and costs 60 mana (0 tempo) to be rid of. Resists 15% physical/fire/lightning.\nChain Lightning (5 tempo): 35 lightning to everyone it hits — cast reaches 5 squares, each bound arcs 4 from the last one struck.\nMove (3 tempo): 8 spaces.",
		EnemyType.CORRUPTED_ARCHANGEL: "Black eyes and long black hair, white wings and robes, wielding a black two-handed sword.\n[Design mock-up — stats & moves TBD.]",
		EnemyType.SLUDGE: "Gelatinous ooze that strikes up close or at range.\nMelee (5 tempo): 3 damage.\nSpit (range 6, 6 tempo): 3 damage.\nMove (5 tempo): 3 spaces.",
		EnemyType.PIPE_CRAWLER: "Many-limbed crawler scuttling on all fours.\nClaw (5 tempo): 5 damage; 25% chance to disarm you (5 tempo).\nMove (2 tempo): 2 spaces.",
		EnemyType.SEWER_CROC: "Armoured sewer serpent (20 armor).\nBite (6 tempo): 12 damage.\nVenom Spray (15 tempo, Async): a cone 5 squares long — one square wide in front of it, five at the far end. Everyone in it takes 8 Poison; anyone with armor also takes 10 damage. No armor, no damage.\nMove (5 tempo): 2 spaces.\nVenomous hide: a hit that costs it health poisons the attacker 3; while it still has armor it has 5 Thorns.\nExposed: when its armor breaks it is stunned for 3 tempo and every clock it was counting resets.",
		EnemyType.RAT_KING: "A giant crowned rat that leads the swarm (10 armor), fought in his own lair off the sewer's central cistern.\nBite (3 tempo): 6 damage.\nInfest (5 tempo): puts an Infest card in your hand for every rat within 10 squares of him, himself included. Held for 5 tempo, an Infest hatches into 2 Wererats beside you; play it (50 mana, 0 tempo) to erase it, or discard it, and nothing hatches.\nMove (2 tempo): 2 spaces.\nFlee to a nest (2 tempo): at 50%, 30% and 30% health he bolts for an untouched rat nest.\nFeed on the nest (2 tempo): heals 20% / 30% / 50% of his health (left / middle / right nest); a nest feeds him once.",
		EnemyType.SWARM: "A single creature made of countless biting bugs.\nAttack (2 tempo): 3 damage.\nMove (3 tempo): 8 spaces — very fast.",
		EnemyType.RING_WRAITH: "The Precious: hunts the ring-bearer through the shadow world. Shadow form does not hide you from these.\nAttack (2 tempo): 15 damage.\nMove (4 tempo): 5 spaces.\nResummons on death — grants no XP.",
		EnemyType.DUMMY: "The Dojo's training dummy (a chicken, for morale). Stands still, never strikes, and a killing blow only refills it — grants no XP, drops nothing.",
		EnemyType.HELL_DOOR: "The gate Cerberus guards: the way down to Hell. Break it to get through — you need not kill the hound. At 75%, 50% and 33% health it seals itself against all damage for 10 tempo. It counts as Cerberus's ally (its drop below half feeds his Guardian of Death). Grants no XP, drops nothing.",
		EnemyType.GRAVESTONE: "A headstone in the Boneyard. Every one left standing regenerates the Bone Dragon 1 health a cycle, and that regen never fades — break the stones to starve him of it. Grants no XP, drops nothing.",
		EnemyType.GRAVE_DIGGER: "Walks out of the Boneyard's crypt to a broken gravestone and sets it back to full in 8 tempo, then is gone. Three come in all, one at a time. Cut him down before he finishes.\nWalk (2 tempo): 6 spaces.\nRepair (8 tempo): the stone stands again.",
		EnemyType.RAT_NEST: "A heap of straw and bones at the foot of a cliff in the Rat King's Lair. Tread on it and its Archer Rat scrambles up to the high ground. The wounded king feeds on an untouched nest (left 20%, middle 30%, right 50% of his health) — tear the nests down and he has nowhere to run. Grants no XP, drops nothing.",
	}

	var result: Array = []
	for enemy_type in EnemyType.values():
		var s = _stats[enemy_type]
		# Apply the same passive-rework scaling initialize() uses, so the
		# compendium shows the numbers the player actually fights.
		var pps := passive_power_scale(int(INTENDED_LEVELS.get(enemy_type, 0)))
		var hp: int = int(s["health"])
		var armor: int = int(s["armor"])
		var dmg: int = int(s["damage"])
		var special_text: String = _specials[enemy_type]
		if hp > 0:
			hp = maxi(1, roundi(hp * pps["hp"]))
			armor = roundi(armor * pps["hp"])
			if dmg > 0:
				dmg = maxi(1, roundi(dmg * pps["dmg"]))
			# The prose above quotes base action numbers — flag the band scaling
			# instead of hand-editing every blurb.
			if not is_equal_approx(pps["hp"], 1.0) or not is_equal_approx(pps["dmg"], 1.0):
				special_text += "\n(Level-band rebalance: action numbers above are base — actual HP x%.2f, damage x%.2f.)" % [pps["hp"], pps["dmg"]]
		# Keywords come from the live action table; the display list above
		# only carries friendlier names in the same order.
		var shown: Array = []
		var real: Array = actions_for_type(enemy_type)
		var idx := 0
		for a in _actions[enemy_type]:
			var entry: Dictionary = a.duplicate()
			var kws: Array[String] = []
			if real.size() == _actions[enemy_type].size() and idx < real.size():
				kws = action_keywords(real[idx])
			entry["keywords"] = kws
			shown.append(entry)
			idx += 1
		result.append({
			"name": s["name"],
			"type": _type_display[enemy_type],
			"health": hp,
			"armor": armor,
			"damage": dmg,
			"xp": s["xp"],
			"actions": shown,
			"special": special_text,
		})
	return result

#endregion
#region TEMPO BAR SETUP
# ============================================
# TEMPO BAR SETUP
# ============================================

func _setup_tempo_bar() -> void:
	# Background bar (dark)
	_tempo_bar_bg = MeshInstance3D.new()
	var bg_quad = QuadMesh.new()
	bg_quad.size = Vector2(_tempo_bar_width, 0.09)
	_tempo_bar_bg.mesh = bg_quad
	var bg_mat = StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.15, 0.15, 0.1, 0.7)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.no_depth_test = true
	_tempo_bar_bg.material_override = bg_mat
	_tempo_bar_bg.position = HOVER_TEMPO  # above the head: north of the feet, lifted to sort in front
	_tempo_bar_bg.visible = false
	add_child(_tempo_bar_bg)

	# Foreground bar (yellow fill)
	_tempo_bar_fg = MeshInstance3D.new()
	var fg_quad = QuadMesh.new()
	fg_quad.size = Vector2(0.01, 0.09)
	_tempo_bar_fg.mesh = fg_quad
	var fg_mat = StandardMaterial3D.new()
	fg_mat.albedo_color = Color(1.0, 0.85, 0.0, 0.9)  # Yellow
	fg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fg_mat.no_depth_test = true
	_tempo_bar_fg.material_override = fg_mat
	_tempo_bar_fg.position = HOVER_TEMPO + Vector3(0, 0.01, 0)  # Slightly in front
	_tempo_bar_fg.visible = false
	add_child(_tempo_bar_fg)

	# Action label (above tempo bar) — sized and outlined to stay readable
	# from a zoomed-out camera, like the name label.
	_action_label = Label3D.new()
	_action_label.position = HOVER_ACTION
	_action_label.visible = false  # the action word only shows while hovered (the bar stays)
	_action_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_action_label.outline_size = 6
	_action_label.outline_modulate = Color(0, 0, 0, 1.0)
	_world_text(_action_label, 0.26)
	_action_label.no_depth_test = true
	_action_label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR  # no mip smear
	_action_label.render_priority = 20
	_action_label.modulate = Color(1.0, 0.85, 0.0)  # Yellow text
	_action_label.text = ""
	add_child(_action_label)

	# Name on top of the stack; the exact numbers sit on their bars. All of
	# it is sized in world units so it zooms with the sprite.
	if name_label:
		name_label.position = HOVER_NAME
		_world_text(name_label, 0.30)
	if health_label:
		health_label.position = HOVER_HEALTH + Vector3(0, 0.03, 0)
		_world_text(health_label, 0.22)

const _ARMOR_BAR_PIXEL_WIDTH: int = 200
const _ARMOR_BAR_PIXEL_HEIGHT: int = 24

func _world_text(l: Label3D, height_units: float) -> void:
	## Size a head-up label in world units (tiles) so it keeps its ratio to
	## the sprite at every zoom; WorldLabelOverlay mirrors it at that scale.
	l.fixed_size = false
	l.font_size = 20
	l.pixel_size = height_units / 20.0
	l.set_meta("world_scaled", true)

func _head_offset() -> float:
	## Screen distance (tiles) from the feet to just above the drawn head:
	## the sprite rig measures its frame; procedural figures use a default.
	var h := 1.2
	if _enemy_figure and _enemy_figure.has_method("portrait_extent"):
		h = maxf(0.5, float(_enemy_figure.portrait_extent().y))
	return h + 0.12

func _layout_head_up() -> void:
	## Stack the head-up elements upward from the top of the sprite: tempo
	## bar nearest the head, armor bar above it (armored kinds only), health
	## bar on top; then the hover-only action word (only while there is one)
	## and name, then the status badges. Billboards sit at the sprite lift;
	## an offset north of the feet reads as "above" on screen. Gaps are in
	## tiles, so the whole stack zooms with the sprite.
	const Y := 0.5
	var z := -_head_offset()
	if _tempo_bar_bg:
		_tempo_bar_bg.position = Vector3(0, Y, z)
	if _tempo_bar_fg:
		_tempo_bar_fg.position = Vector3(_tempo_bar_fg.position.x, Y + 0.01, z)
	if max_armor > 0:
		z -= 0.13
		if _armor_bar_sprite:
			_armor_bar_sprite.position = Vector3(0, Y, z)
		if _armor_label:
			_armor_label.position = Vector3(0, Y + 0.03, z)
	z -= 0.13
	if _health_bar_bg:
		_health_bar_bg.position = Vector3(0, Y, z)
	if _health_bar_fg:
		_health_bar_fg.position = Vector3(_health_bar_fg.position.x, Y + 0.01, z)
	if health_label:
		health_label.position = Vector3(0, Y + 0.03, z)
	if _action_label and _action_label.text != "":
		z -= 0.22
		_action_label.position = Vector3(0, Y, z)
	z -= 0.24
	if name_label:
		name_label.position = Vector3(0, Y, z)
	z -= 0.28
	_status_z = z
	if _status_container:
		_status_container.position = Vector3(0, Y, z)

func _setup_health_bar() -> void:
	## Always-on health bar (dark red track, green fill); the exact numbers
	## only appear on hover, on top of it.
	_health_bar_bg = MeshInstance3D.new()
	var bg_quad = QuadMesh.new()
	bg_quad.size = Vector2(_health_bar_width, 0.09)
	_health_bar_bg.mesh = bg_quad
	var bg_mat = StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.16, 0.05, 0.05, 0.9)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.no_depth_test = true
	_health_bar_bg.material_override = bg_mat
	_health_bar_bg.position = HOVER_HEALTH
	add_child(_health_bar_bg)

	_health_bar_fg = MeshInstance3D.new()
	var fg_quad = QuadMesh.new()
	fg_quad.size = Vector2(_health_bar_width, 0.09)
	_health_bar_fg.mesh = fg_quad
	var fg_mat = StandardMaterial3D.new()
	fg_mat.albedo_color = Color(0.88, 0.18, 0.16, 0.95)  # red
	fg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fg_mat.no_depth_test = true
	_health_bar_fg.material_override = fg_mat
	_health_bar_fg.position = HOVER_HEALTH + Vector3(0, 0.01, 0)
	add_child(_health_bar_fg)
	_update_health_bar()

func _update_health_bar() -> void:
	if not _health_bar_bg or not _health_bar_fg:
		return
	var ratio := clampf(float(current_health) / float(maxi(1, max_health)), 0.0, 1.0)
	var w := _health_bar_width * ratio
	var fg_mesh = _health_bar_fg.mesh as QuadMesh
	if fg_mesh:
		fg_mesh.size.x = maxf(0.001, w)
	_health_bar_fg.visible = w > 0.001
	_health_bar_fg.position.x = -(_health_bar_width - w) / 2.0  # fills from the left

func _setup_armor_bar() -> void:
	if max_armor <= 0:
		return

	# Single Sprite3D with everything (background + fill + dividers) baked into the texture.
	# This eliminates billboard alignment issues that plagued the multi-mesh approach.
	_armor_bar_sprite = Sprite3D.new()
	_armor_bar_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_armor_bar_sprite.shaded = false
	_armor_bar_sprite.no_depth_test = true
	_armor_bar_sprite.transparent = true
	_armor_bar_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_armor_bar_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_armor_bar_sprite.pixel_size = _armor_bar_width / float(_ARMOR_BAR_PIXEL_WIDTH)
	_armor_bar_sprite.position = HOVER_ARMOR
	add_child(_armor_bar_sprite)

	# Armor value label rendered on top of the sprite
	_armor_label = Label3D.new()
	_armor_label.position = HOVER_ARMOR + Vector3(0, 0.03, 0)
	_armor_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_armor_label.outline_size = 4
	_armor_label.outline_modulate = Color(0, 0, 0, 1)
	_world_text(_armor_label, 0.22)
	_armor_label.modulate = Color(0.95, 0.95, 0.95)
	_armor_label.no_depth_test = true
	_armor_label.render_priority = 20
	_armor_label.visible = false  # exact number only while hovered (bar stays)
	add_child(_armor_label)

	_update_armor_bar()

func _update_armor_bar() -> void:
	if not _armor_bar_sprite:
		return

	if max_armor <= 0:
		_armor_bar_sprite.visible = false
		if _armor_label:
			_armor_label.text = ""
		return

	# Always show the bar (even when empty) so the player sees the segments.
	_armor_bar_sprite.visible = true
	_refresh_armor_bar_image()

	if _armor_label:
		_armor_label.text = str(current_armor)

func _refresh_armor_bar_image() -> void:
	## Draws a single gray bar that is full when the enemy has any armor, empty when they don't.
	var w = _ARMOR_BAR_PIXEL_WIDTH
	var h = _ARMOR_BAR_PIXEL_HEIGHT
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)

	var bg_color = Color(0.18, 0.18, 0.22, 0.95)
	var fill_color = Color(0.72, 0.72, 0.72, 1.0)
	var border_color = Color(0.0, 0.0, 0.0, 1.0)

	# Background (dark)
	img.fill(bg_color)

	# Full gray fill if the enemy currently has any armor
	if current_armor > 0:
		img.fill_rect(Rect2i(0, 0, w, h), fill_color)

	# Black border around the whole bar
	img.fill_rect(Rect2i(0, 0, w, 1), border_color)            # top
	img.fill_rect(Rect2i(0, h - 1, w, 1), border_color)        # bottom
	img.fill_rect(Rect2i(0, 0, 1, h), border_color)            # left
	img.fill_rect(Rect2i(w - 1, 0, 1, h), border_color)        # right

	_armor_bar_sprite.texture = ImageTexture.create_from_image(img)

#endregion
#region TEMPO-DRIVEN ACTION HANDLING
# ============================================
# TEMPO-DRIVEN ACTION HANDLING
# ============================================

## Called by EnemySpawner whenever global tempo advances.
func on_tempo_advanced(amount: int, player_node: Node3D) -> void:
	if is_dead:
		return
	_last_seen_target = player_node

	_cycle_accumulator += amount

	# Tree form (Cupids Bow): counted in raw tempo, not cycles. The tree keeps
	# every buff and debuff it had, cannot act, and regenerates 3 health on
	# each of its first 3 tempo.
	if tree_tempo > 0:
		for _t in range(amount):
			if tree_tempo <= 0:
				break
			tree_tempo -= 1
			if tree_regen_ticks > 0:
				tree_regen_ticks -= 1
				_regenerate(3)
		if tree_tempo <= 0:
			_exit_tree_form()

	# Armored Troll passive: regenerate 3 HP every 6 global tempo
	if enemy_type == EnemyType.ARMORED_TROLL:
		regen_accumulator += amount
		while regen_accumulator >= 6:
			regen_accumulator -= 6
			_regenerate(3)

	# Treant passive: heals 5 HP every 5 tempo, +2 per 10% HP below 60%.
	# And every 10 tempo it strips its enemies' thorns, healing for the total.
	if enemy_type == EnemyType.TREANT:
		regen_accumulator += amount
		while regen_accumulator >= 5:
			regen_accumulator -= 5
			_regenerate(_treant_heal_amount())
		_treant_thorn_accumulator += amount
		while _treant_thorn_accumulator >= 10:
			_treant_thorn_accumulator -= 10
			_treant_strip_thorns()

	# Wererabbit: the escape clock — flees 3 cycles (15 tempo), then vanishes.
	if enemy_type == EnemyType.WERERABBIT:
		_wererabbit_tempo += amount

	# Elite first-pass ability cooldowns run on raw tempo.
	if _roar_cooldown > 0:
		_roar_cooldown = maxi(0, _roar_cooldown - amount)
	if _net_cooldown > 0:
		_net_cooldown = maxi(0, _net_cooldown - amount)
	if _hook_recharge > 0:
		_hook_recharge = maxi(0, _hook_recharge - amount)
	if _stinger_cooldown > 0:
		_stinger_cooldown = maxi(0, _stinger_cooldown - amount)
	if _talon_cooldown > 0:
		_talon_cooldown = maxi(0, _talon_cooldown - amount)
	if _dive_cooldown > 0:
		_dive_cooldown = maxi(0, _dive_cooldown - amount)
	# Roc: how long a player unit has stood in melee reach (Eye Scrape wants > 3).
	if enemy_type == EnemyType.ROC:
		var roc_adjacent := false
		for ru in _player_units():
			if _cells_between(self, ru) <= 1:
				roc_adjacent = true
				break
		_roc_melee_tempo = (_roc_melee_tempo + amount) if roc_adjacent else 0

	# Hell's Gate: the door's seal runs down; Cerberus watches for drops below
	# half, listens for heals, and the venom runs its course.
	if enemy_type == EnemyType.HELL_DOOR and door_sealed_tempo > 0:
		door_sealed_tempo = maxi(0, door_sealed_tempo - amount)
		if door_sealed_tempo == 0:
			print("[%s] The seal fades" % enemy_name)
		_update_status_indicators()
	if enemy_type == EnemyType.CERBERUS:
		_hook_deathyard_dog()
		_guardian_scan()
		_tick_venom(amount)

	# Bone Dragon in the Boneyard: 1 health a cycle for every gravestone
	# still standing — regen that never decays; only breaking stones lowers it.
	if enemy_type == EnemyType.BONE_DRAGON and gravestone_provider.is_valid():
		regen_accumulator += amount
		while regen_accumulator >= 5:
			regen_accumulator -= 5
			var standing: int = int(gravestone_provider.call())
			if standing > 0:
				_regenerate(standing)

	# Wolf pack: within 4 tiles of another wolf, regen 2 HP every 5 tempo.
	if enemy_type == EnemyType.WOLF and _wolf_aura_active():
		regen_accumulator += amount
		while regen_accumulator >= 5:
			regen_accumulator -= 5
			_regenerate(2)

	# Timed statuses (stun, frozen, disarm...) run on RAW tempo so durations
	# like "3 tempo" work; only the per-cycle DOT/stack ticks wait for the
	# 5-tempo accumulator below.
	_tick_timed_statuses(amount)

	# Tick per-cycle DOTs/stacks once per tempo cycle (every 5 global tempo)
	while _cycle_accumulator >= 5:
		_cycle_accumulator -= 5
		_tick_status_durations()

	_advance_action_clocks(amount, player_node)
	_update_tempo_bar()

## Timed statuses count in RAW TEMPO (any granularity), decremented by every
## tempo advance. All apply_* entry points take tempo, not cycles.
func _tick_timed_statuses(amount: int) -> void:
	if amount <= 0:
		return
	var any := taunt_tempo > 0 or fear_tempo > 0 or wear_down_tempo > 0 \
		or disarmed_tempo > 0 or marked_tempo > 0 or silenced_tempo > 0 \
		or frozen_tempo > 0 or stun_tempo > 0 \
		or rooted_tempo > 0 or narashimha_tempo > 0 or cursed_tempo > 0 \
		or phys_defense_debuff_tempo > 0
	if not any:
		return

	if phys_defense_debuff_tempo > 0:
		phys_defense_debuff_tempo -= amount
		if phys_defense_debuff_tempo <= 0:
			phys_defense_debuff_tempo = 0
			phys_defense_debuff_percent = 0.0
			print("[%s] Lowered physical defense expired" % enemy_name)

	if taunt_tempo > 0:
		taunt_tempo -= amount
		if taunt_tempo <= 0:
			taunt_tempo = 0
			taunt_target = null
			print("[%s] Taunt expired" % enemy_name)

	if fear_tempo > 0:
		fear_tempo -= amount
		if fear_tempo <= 0:
			fear_tempo = 0
			fear_source = null
			print("[%s] Fear expired" % enemy_name)

	if wear_down_tempo > 0:
		wear_down_tempo -= amount
		if wear_down_tempo <= 0:
			wear_down_tempo = 0
			attack_reduction = 0
			print("[%s] Wear Down expired, attack restored" % enemy_name)

	if disarmed_tempo > 0:
		disarmed_tempo -= amount
		if disarmed_tempo <= 0:
			disarmed_tempo = 0
			is_disarmed = false
			print("[%s] Disarm expired, can attack again" % enemy_name)
			debuff_expired.emit(self, "disarmed")

	if marked_tempo > 0:
		marked_tempo -= amount
		if marked_tempo <= 0:
			marked_tempo = 0
			is_marked = false
			print("[%s] Mark expired" % enemy_name)
			debuff_expired.emit(self, "marked")

	if silenced_tempo > 0:
		silenced_tempo -= amount
		if silenced_tempo <= 0:
			silenced_tempo = 0
			is_silenced = false
			print("[%s] Silence expired, can cast again" % enemy_name)
			debuff_expired.emit(self, "silenced")

	if frozen_tempo > 0:
		frozen_tempo -= amount
		if frozen_tempo <= 0:
			frozen_tempo = 0
			is_frozen = false
			print("[%s] Frozen expired, can act again" % enemy_name)
			debuff_expired.emit(self, "frozen")
			# Shatter (sphere node): the thaw itself hurts.
			var shatter := int(_player_sphere_amp("sphere_shatter_amp"))
			if shatter > 0 and not is_dead:
				take_damage(shatter, false)
				print("[%s] Shatter! Took %d damage coming out of Frozen" % [enemy_name, shatter])

	if stun_tempo > 0:
		stun_tempo -= amount
		if stun_tempo <= 0:
			stun_tempo = 0
			is_stunned = false
			print("[%s] Stun expired, can act again" % enemy_name)
			debuff_expired.emit(self, "stun")

	if cursed_tempo > 0:
		cursed_tempo -= amount
		if cursed_tempo <= 0:
			cursed_tempo = 0
			print("[%s] Curse lifted" % enemy_name)
			debuff_expired.emit(self, "cursed")

	if rooted_tempo > 0:
		rooted_tempo -= amount
		if rooted_tempo <= 0:
			rooted_tempo = 0
			print("[%s] Root released" % enemy_name)
			debuff_expired.emit(self, "root")

	if tripped_tempo > 0:
		tripped_tempo -= amount
		if tripped_tempo <= 0:
			tripped_tempo = 0
			print("[%s] Back on its feet" % enemy_name)
			debuff_expired.emit(self, "trip")

	if narashimha_tempo > 0:
		narashimha_tempo -= amount
		if narashimha_tempo <= 0:
			narashimha_tempo = 0
			narashimha_heal_cap = -1
			print("[%s] Narashimha wound closes" % enemy_name)
			debuff_expired.emit(self, "narashimha")

	_update_status_indicators()

func _tick_status_durations() -> void:
	# Choke: deal the caster's half-auto-attack damage per cycle, lose 1 stack
	if choke_dot_stacks > 0:
		take_damage(choke_dot_damage, false)
		print("[%s] Choke deals %d damage (%d stacks left)" % [enemy_name, choke_dot_damage, choke_dot_stacks - 1])
		choke_dot_stacks -= 1
		if choke_dot_stacks <= 0:
			print("[%s] Choke expired" % enemy_name)
			debuff_expired.emit(self, "choke")

	# Burn: deal doubling damage each cycle (1, 2, 4, 8...)
	if burn_stacks > 0:
		take_damage(burn_damage_next, false)
		print("[%s] Burn deals %d damage (doubles next cycle)" % [enemy_name, burn_damage_next])
		# Element Pollination: the flames jump — burn splashes nearby enemies
		# like Shock while the Elemental Weaver's maintain is up.
		if Card.element_pollination_active:
			for pol_e in _sibling_enemies():
				if pol_e != self and position.distance_to(pol_e.position) <= 2.5:
					pol_e.take_damage(burn_damage_next, false)
					print("[%s] Element Pollination: burn splashes %d to %s" % [enemy_name, burn_damage_next, pol_e.enemy_name])
		# Burn Amp (sphere node): a flat extra hit lands after the normal tick,
		# outside the doubling.
		var burn_extra := int(_player_sphere_amp("sphere_burn_amp"))
		if burn_extra > 0 and not is_dead:
			take_damage(burn_extra, false)
			print("[%s] Burn Amp adds %d damage" % [enemy_name, burn_extra])
		burn_damage_next *= 2
		burn_stacks -= 1
		if burn_stacks <= 0:
			burn_damage_next = 1
			print("[%s] Burn expired" % enemy_name)
			debuff_expired.emit(self, "burn")

	# Polymorph: the pig wears off one cycle at a time
	if polymorph_tempo > 0:
		polymorph_tempo -= 1
		if polymorph_tempo <= 0:
			print("[%s] Polymorph wears off" % enemy_name)
			debuff_expired.emit(self, "polymorph")

	# Poison: deal current stacks damage, then lose 1 stack per cycle
	if poison_stacks > 0:
		take_damage(poison_stacks, false)
		print("[%s] Poison deals %d damage" % [enemy_name, poison_stacks])
		# Poison Amp (sphere node): each tick has a stacks% chance of a bonus
		# damage instance — more stacks, more likely the venom spikes.
		var poison_bonus := int(_player_sphere_amp("sphere_poison_amp"))
		if poison_bonus > 0 and not is_dead and randf() * 100.0 < float(poison_stacks):
			take_damage(poison_bonus, false)
			print("[%s] Poison Amp spikes for %d bonus damage (%d%% chance hit)" % [enemy_name, poison_bonus, poison_stacks])
		poison_stacks -= 1
		if poison_stacks <= 0:
			print("[%s] Poison expired" % enemy_name)
			debuff_expired.emit(self, "poison")

	# Bleed no longer clots by time — stacks fall as the wound bleeds (1 damage
	# per tile moved, 1 stack per damage; see the tile-step in _physics_process).
	# Timed statuses (stun, frozen, root, curse...) tick per raw tempo in
	# _tick_timed_statuses, not here.

	# Cold: thaws 1 stack per cycle so it's a combo window, not a permanent
	# ratchet toward Frozen (mirrors the player-side Cold expiring over time)
	if cold_stacks > 0:
		# Element Pollination: the frost bites — Cold ticks doubling damage
		# like Burn while the Elemental Weaver's maintain is up.
		if Card.element_pollination_active:
			take_damage(cold_damage_next, false)
			print("[%s] Element Pollination: cold bites for %d (doubles next cycle)" % [enemy_name, cold_damage_next])
			cold_damage_next *= 2
		cold_stacks -= 1
		if cold_stacks <= 0:
			cold_damage_next = 1
			print("[%s] Cold thawed" % enemy_name)
			debuff_expired.emit(self, "cold")

	# Shock: deal current stacks damage, then lose 1 stack per cycle
	if shock_stacks > 0:
		take_damage(shock_stacks, false)
		print("[%s] Shock deals %d damage" % [enemy_name, shock_stacks])
		shock_stacks -= 1
		if shock_stacks <= 0:
			print("[%s] Shock expired" % enemy_name)
			debuff_expired.emit(self, "shock")

	_update_status_indicators()

func _can_act_now(player_node: Node3D) -> bool:
	## Whether this enemy may fire actions right now (stun, freeze, tree
	## form, an unseen target). Clocks keep counting regardless — a stun
	## reset them when it landed, so the delay is already paid.
	if not player_node:
		return false
	if is_stunned or is_frozen or tree_tempo > 0:
		return false
	# Skip actions if player is invisible (ring wraiths see through everything)
	if not ignores_invisibility and player_node.has_method("get_buff_manager"):
		var p_buff_mgr = player_node.get_buff_manager()
		if p_buff_mgr and p_buff_mgr.is_invisible():
			return false
	# Skip actions if this enemy is blind to this player (Serial Killer)
	if player_node in invisible_to_players:
		return false
	return true

func _advance_action_clocks(amount: int, player_node: Node3D) -> void:
	## Tempo arrives in lumps; the keyword rules are defined per single tempo,
	## so each unit is processed on its own.
	for _t in range(maxi(0, amount)):
		if is_dead:
			return
		_tick_action_clocks(player_node)

func _async_actions() -> Array:
	var out: Array = []
	for a in actions:
		if is_async_action(a) and not is_trigger_action(a):
			out.append(a)
	return out

func _all_async_idle() -> bool:
	for a in _async_actions():
		if int(_async_counters.get(str(a["name"]), 0)) > 0:
			return false
	return true

func is_channeling() -> bool:
	return not _channel_action.is_empty()

## Push the next action back by `tempo` on the action clock (Haunted Rebuke).
## The counter climbs 1 per tempo toward the action's cost, so debiting it
## delays whatever fires next — attacks included, unlike the Slow debuff.
func delay_next_action(tempo: int) -> void:
	action_tempo_counter -= maxi(0, tempo)

## The apply_debuff key behind a get_active_effects() name ("" when the
## effect has no re-applicable key: Taunt, Fear, Exposed, Tree…).
static func debuff_key_for_effect(effect_name: String) -> String:
	const KEYS := {
		"Slow": "slow", "Cursed": "cursed", "Disarm": "disarmed", "Marked": "marked",
		"Silenced": "silenced", "Choke": "choke_dot", "Stun": "stun", "Polymorph": "polymorph",
		"Frozen": "cold", "Burn": "burn", "Cold": "cold", "Poison": "poison", "Shock": "shock",
		"Bleed": "bleed", "Vulnerable": "vulnerable", "Weaken": "weaken", "Rooted": "root", "Tripped": "trip",
		"Disarmed": "disarm_attacks", "Narashimha": "narashimha",
	}
	return str(KEYS.get(effect_name, ""))

func _reset_action_clocks() -> void:
	## Every clock back to zero: the sync action is dropped, Async counters
	## restart, a channel breaks. Used by stun/freeze, death, and setup.
	action_tempo_counter = 0
	chosen_action = {}
	_async_counters.clear()
	_action_damage.clear()
	_channel_action = {}
	_channel_remaining = 0
	_channel_kind = ""
	# Async clocks always go first: a Sync clock waits for their first gap.
	_async_gap = _async_actions().is_empty()

func _tick_action_clocks(player_node: Node3D) -> void:
	## One tempo of the action clocks, keyword by keyword:
	##  Channel  — nothing else moves; the channel runs down and resolves.
	##  Async    — every Async clock counts, and fires on its own.
	##  Sync     — the chosen action counts only once it has started, and it
	##             may start only when no Async clock is mid-count.
	var can_act := _can_act_now(player_node)

	if is_channeling():
		if can_act:
			_channel_remaining -= 1
			if _channel_remaining <= 0:
				_resolve_channel(player_node)
		return

	var gap := _async_gap

	for a in _async_actions():
		var nm := str(a["name"])
		_async_counters[nm] = int(_async_counters.get(nm, 0)) + 1

	if chosen_action.is_empty() and can_act:
		_choose_action(player_node)
	if not chosen_action.is_empty() and (action_tempo_counter > 0 or gap):
		action_tempo_counter += 1

	if can_act:
		_fire_ready_async(player_node)
		if not is_channeling():
			_fire_ready_sync(player_node)

	_async_gap = _all_async_idle()

func _move_target_for(player_node: Node3D) -> Node3D:
	if taunt_target and is_instance_valid(taunt_target):
		return taunt_target
	# Sabertooth: Track's quarry overrides whoever the spawner points it at
	# (a Taunt still wins — it is the player's own forced-target tool).
	if enemy_type == EnemyType.SABERTOOTH:
		var quarry := _track_quarry()
		if quarry != null:
			return quarry
	return player_node

func _effective_cost(action: Dictionary) -> int:
	## Wind-up tempo for an action, plus the debuff taxes that delay it: Sword
	## Breaker on the next melee swing, Slowed on a movement action.
	var cost: int = windup_of(action) + next_action_tempo_tax
	if next_melee_tempo_tax > 0 and not NON_MELEE_ACTIONS.has(str(action["name"])):
		cost += next_melee_tempo_tax
	if slow_stacks > 0 and MOVEMENT_ACTIONS.has(str(action["name"])):
		cost += Debuff.SLOWED_TEMPO_PER_TILE + int(_player_sphere_amp("sphere_slow_amp")) - 1
	return cost

func _consume_fire_taxes(action: Dictionary) -> void:
	## The taxes above are paid when the action actually fires.
	if next_action_tempo_tax > 0:
		print("[%s] Haunted Rebuke: action delayed %d tempo" % [enemy_name, next_action_tempo_tax])
		next_action_tempo_tax = 0
	if next_melee_tempo_tax > 0 and not NON_MELEE_ACTIONS.has(str(action["name"])):
		print("[%s] Sword Breaker: swing delayed %d tempo" % [enemy_name, next_melee_tempo_tax])
		next_melee_tempo_tax = 0
	if slow_stacks > 0 and MOVEMENT_ACTIONS.has(str(action["name"])):
		print("[%s] Slowed: move delayed %d extra tempo" % [enemy_name,
			Debuff.SLOWED_TEMPO_PER_TILE + int(_player_sphere_amp("sphere_slow_amp")) - 1])
		_consume_slow_stack()

func _fire_ready_sync(player_node: Node3D) -> void:
	if chosen_action.is_empty():
		return
	if action_tempo_counter < _effective_cost(chosen_action):
		return
	_consume_fire_taxes(chosen_action)
	var action: Dictionary = chosen_action
	if channel_of(action) > 0:
		_begin_channel(action, "sync")
		return
	_execute_now(action, player_node)
	action_tempo_counter = 0
	_action_damage.erase(str(action["name"]))
	chosen_action = {}
	# Immediately choose next action so the bar shows what's coming
	_choose_action(player_node)

func _fire_ready_async(player_node: Node3D) -> void:
	for a in _async_actions():
		var nm := str(a["name"])
		if int(_async_counters.get(nm, 0)) < _effective_cost(a):
			continue
		_consume_fire_taxes(a)
		# The clock restarts whether or not the swing lands: an Async action
		# that cannot reach its target when its tempo comes up is spent.
		_async_counters[nm] = 0
		_action_damage.erase(nm)
		if channel_of(a) > 0:
			_begin_channel(a, "async")
			return  # the channel freezes every other clock this tempo
		_execute_now(a, player_node)

func _execute_now(action: Dictionary, player_node: Node3D) -> bool:
	var nm := str(action["name"])
	action_fired.emit(self, nm)
	return _execute_action(nm, _move_target_for(player_node))

func _begin_channel(action: Dictionary, kind: String) -> void:
	_channel_action = action
	_channel_kind = kind
	_channel_remaining = channel_of(action)
	if is_moving and not _wandering:
		# Planted: a channel roots the enemy where it stands.
		_move_path.clear()
	print("[%s] Channeling %s (%d tempo)" % [enemy_name, action_label(action), _channel_remaining])
	if windup_of(action) == 0:
		# A stand-alone channel starts counting on the tempo it is chosen.
		_channel_remaining -= 1
		if _channel_remaining <= 0:
			_resolve_channel(_last_seen_target)

func _resolve_channel(player_node: Node3D) -> void:
	var action: Dictionary = _channel_action
	var kind := _channel_kind
	_channel_action = {}
	_channel_remaining = 0
	_channel_kind = ""
	_action_damage.erase(str(action["name"]))
	_execute_now(action, player_node)
	if kind == "sync":
		action_tempo_counter = 0
		chosen_action = {}
		_choose_action(player_node)
	elif kind == "async":
		_async_counters[str(action["name"])] = 0

func _break_channel(reason: String) -> void:
	## Disrupted: the channel collapses and its clock restarts from 0.
	if not is_channeling():
		return
	var action: Dictionary = _channel_action
	var kind := _channel_kind
	_channel_action = {}
	_channel_remaining = 0
	_channel_kind = ""
	_action_damage.erase(str(action["name"]))
	if kind == "sync":
		action_tempo_counter = 0
	elif kind == "async":
		_async_counters[str(action["name"])] = 0
	print("[%s] %s disrupted (%s) — clock restarts" % [enemy_name, action_label(action), reason])
	channel_broken.emit(self, str(action["name"]))

func _on_damage_for_disrupt(hit: int) -> void:
	## Disruptable: damage taken while an action counts (or channels) piles up
	## against its threshold; reaching it restarts that action's clock.
	if hit <= 0:
		return
	if is_channeling():
		var ch := _channel_action
		if disrupt_threshold(ch) > 0:
			var nm := str(ch["name"])
			_action_damage[nm] = int(_action_damage.get(nm, 0)) + hit
			if int(_action_damage[nm]) >= disrupt_threshold(ch):
				_break_channel("%d damage" % int(_action_damage[nm]))
		return
	if not chosen_action.is_empty() and disrupt_threshold(chosen_action) > 0 and action_tempo_counter > 0:
		var snm := str(chosen_action["name"])
		_action_damage[snm] = int(_action_damage.get(snm, 0)) + hit
		if int(_action_damage[snm]) >= disrupt_threshold(chosen_action):
			print("[%s] %s disrupted (%d damage) — clock restarts" % [enemy_name, action_label(chosen_action), int(_action_damage[snm])])
			action_tempo_counter = 0
			_action_damage.erase(snm)
	for a in _async_actions():
		if disrupt_threshold(a) <= 0:
			continue
		var anm := str(a["name"])
		if int(_async_counters.get(anm, 0)) <= 0:
			continue
		_action_damage[anm] = int(_action_damage.get(anm, 0)) + hit
		if int(_action_damage[anm]) >= disrupt_threshold(a):
			print("[%s] %s disrupted (%d damage) — clock restarts" % [enemy_name, action_label(a), int(_action_damage[anm])])
			_async_counters[anm] = 0
			_action_damage.erase(anm)

func fire_trigger(event: String) -> void:
	## Trigger: every action keyed to `event` fires now, clock or no clock.
	## A channeling enemy is busy; a stunned/frozen one cannot react.
	if is_dead or actions.is_empty():
		return
	var target: Node3D = _last_seen_target
	if target == null or not is_instance_valid(target):
		return
	if not _can_act_now(target) or is_channeling():
		return
	for a in actions:
		if str(a.get("trigger", "")) != event:
			continue
		if channel_of(a) > 0:
			_begin_channel(a, "trigger")
			return
		_execute_now(a, target)

func get_display_action() -> Dictionary:
	## What the bar above the head (and the tracker) should show: the channel
	## if one is running, else whichever clock fires soonest. Keys: name,
	## label, counter, cost, kind ("channel" / "async" / "sync"), or {} if idle.
	if is_channeling():
		var total := channel_of(_channel_action)
		return {"name": _channel_action["name"], "label": action_label(_channel_action),
			"counter": total - _channel_remaining, "cost": total, "kind": "channel"}
	var best: Dictionary = {}
	var best_left := 1 << 30
	if not chosen_action.is_empty():
		var cost := maxi(1, _effective_cost(chosen_action))
		best = {"name": chosen_action["name"], "label": action_label(chosen_action),
			"counter": action_tempo_counter, "cost": cost, "kind": "sync"}
		best_left = cost - action_tempo_counter
	for a in _async_actions():
		var acost := maxi(1, _effective_cost(a))
		var acount := int(_async_counters.get(str(a["name"]), 0))
		if acost - acount < best_left:
			best_left = acost - acount
			best = {"name": a["name"], "label": action_label(a), "counter": acount, "cost": acost, "kind": "async"}
	return best

#endregion
#region AI - ACTION SELECTION
# ============================================
# AI - ACTION SELECTION
# ============================================

func _choose_action(player_node: Node3D) -> void:
	if actions.is_empty() or not player_node:
		chosen_action = {}
		return

	var distance = _get_cell_distance(player_node)

	# Polymorph (Circe's Wand): a pig only walks and bites — no spells,
	# no abilities, whatever the species would normally reach for. The first
	# action not in NON_MELEE_ACTIONS is the type's basic melee attack.
	if polymorph_tempo > 0:
		chosen_action = {}
		if distance <= 1:
			for pig_a in actions:
				if not NON_MELEE_ACTIONS.has(str(pig_a["name"])):
					chosen_action = pig_a
					break
		if chosen_action.is_empty():
			chosen_action = _get_action("move")
		if chosen_action.is_empty() and actions.size() > 0:
			chosen_action = actions[0]
		return

	match enemy_type:
		EnemyType.WERERAT:
			_choose_wererat_action(distance)
		EnemyType.SKELETON:
			_choose_skeleton_action(distance)
		EnemyType.ARMORED_TROLL:
			_choose_troll_action(distance)
		EnemyType.ARCHER_RAT:
			_choose_archer_rat_action(distance)
		EnemyType.HYDRA:
			_choose_hydra_action(distance)
		EnemyType.FIRE_GOBLIN_SOLDIER:
			_choose_soldier_action(distance)
		EnemyType.FIRE_GOBLIN_MAGE:
			_choose_mage_action(distance)
		EnemyType.FIRE_GOBLIN_SHAMAN:
			_choose_shaman_action(distance)
		EnemyType.GIANT_BEAVER:
			_choose_beaver_action(distance)
		EnemyType.MINI_BEAR:
			_choose_melee_action(distance, "mini_bear_attack")
		EnemyType.LARGE_BEAR:
			_choose_large_bear_action(distance)
		EnemyType.WOLF:
			_choose_melee_action(distance, "wolf_bite")
		EnemyType.COYOTE:
			_choose_melee_action(distance, "coyote_nip")
		EnemyType.BUGBEAR:
			_choose_melee_action(distance, "bugbear_strike")
		EnemyType.INFECTED_HUNTER:
			_choose_hunter_action(distance)
		EnemyType.GIANT_HAWK:
			_choose_ranged_action(distance, "swoop")
		EnemyType.TREANT:
			_choose_treant_action(distance)
		EnemyType.ICE_MAGE:
			_choose_ranged_action(distance, "frost_bolt")
		EnemyType.FIRE_MAGE:
			_choose_ranged_action(distance, "fire_bolt")
		EnemyType.SPARK_MAGE:
			_choose_ranged_action(distance, "spark_bolt")
		EnemyType.AIR_MAGE:
			_choose_ranged_action(distance, "gust")
		EnemyType.EARTH_MAGE:
			_choose_melee_action(distance, "boulder")
		# ----- Graveyard act -----
		EnemyType.ZOMBIE:
			_choose_melee_action(distance, "attack")
		EnemyType.WEREWOLF:
			_choose_werewolf_action(distance, _move_target_for(player_node))
		EnemyType.WERERABBIT:
			# Loot monster: flees for 3 cycles (15 tempo), then vanishes in a
			# puff of smoke — kill it before the clock runs out.
			if _wererabbit_tempo >= 15:
				chosen_action = _get_action("vanish")
			else:
				chosen_action = _get_action("flee")
		EnemyType.VAMPIRE:
			_choose_vampire_action(distance)
		EnemyType.NECROMANCER:
			_choose_necromancer_action(distance)
		EnemyType.BONE_DRAGON:
			_choose_bone_dragon_action(distance)
		EnemyType.SPIRIT_COLLECTOR:
			_choose_collector_action(distance)
		EnemyType.GRAVE_TITAN:
			_choose_titan_action(distance)
		EnemyType.CRYPT_CRAWLER:
			_choose_crawler_action(distance)
		EnemyType.SCREECHER:
			_choose_melee_action(distance, "screech")
		EnemyType.CONSUMED:
			_choose_melee_action(distance, "attack")
		# ----- Sewer act -----
		EnemyType.SLUDGE:
			_choose_sludge_action(distance)
		EnemyType.PIPE_CRAWLER:
			_choose_melee_action(distance, "pipe_attack")
		EnemyType.SEWER_CROC:
			_choose_melee_action(distance, "croc_bite")
		EnemyType.RAT_KING:
			_choose_rat_king_action(distance, player_node)
		EnemyType.GRAVE_DIGGER:
			_choose_grave_digger_action()
		EnemyType.CERBERUS:
			_choose_cerberus_action(distance)
		EnemyType.SWARM:
			_choose_melee_action(distance, "attack")
		# ----- Mountains act -----
		EnemyType.ICE_TROLL:
			_choose_melee_action(distance, "ice_club")
		EnemyType.WHITE_MANTICORE:
			_choose_manticore_action(distance)
		EnemyType.WYVERN:
			_choose_wyvern_action(distance)
		EnemyType.WEREGOAT:
			_choose_weregoat_action(distance)
		EnemyType.ROC:
			_choose_roc_action(distance)
		EnemyType.SABERTOOTH:
			_choose_sabertooth_action(distance)
		EnemyType.SNOW_WRAITH:
			_choose_snow_wraith_action(distance)
		EnemyType.GRANITE_COLOSSUS:
			chosen_action = {}  # moves TBD on the sheet: it stands
		# ----- Underworld act -----
		EnemyType.IFRIT:
			_choose_ifrit_action(distance)
		EnemyType.INFLAMED_MINOTAUR:
			_choose_minotaur_action(distance)
		EnemyType.DEMON:
			_choose_demon_action(distance)
		EnemyType.ASH_HARPY:
			_choose_harpy_action(distance)
		EnemyType.MAGMA_SPIDER:
			_choose_magma_spider_action(distance)
		EnemyType.MIND_EATER:
			_choose_mind_eater_action(distance)
		EnemyType.SPECTER:
			_choose_specter_action(distance)
		EnemyType.SUCCUBUS:
			_choose_succubus_action(distance)
		# ----- Heavens act -----
		EnemyType.DJINN:
			_choose_ranged_action(distance, "chain_lightning")
		EnemyType.CHERUB:
			_choose_cherub_action(distance)
		_:
			_choose_legacy_action(distance)

	if not chosen_action.is_empty():
		print("[%s] Chose action: %s (cost: %d tempo)" % [enemy_name, chosen_action["name"], chosen_action["tempo_cost"]])
	_ensure_sync_choice(distance)

func _ensure_sync_choice(distance: int) -> void:
	## The per-species choosers pick by name; an action tagged Async or
	## Trigger runs off its own clock (or event), so the sync clock falls
	## back to the species' movement when out of reach, else its first Sync
	## action — or idles if there is none.
	if chosen_action.is_empty():
		return
	if not (is_async_action(chosen_action) or is_trigger_action(chosen_action)):
		return
	var fallback: Dictionary = {}
	for a in actions:
		if is_async_action(a) or is_trigger_action(a):
			continue
		var is_move := MOVEMENT_ACTIONS.has(str(a["name"]))
		if distance > attack_range and is_move:
			fallback = a
			break
		if distance <= attack_range and not is_move:
			fallback = a
			break
		if fallback.is_empty():
			fallback = a
	chosen_action = fallback

func _get_cell_distance(target_node: Node3D) -> int:
	if grid_manager:
		return grid_manager.get_distance_in_cells(position, target_node.position)
	var diff = target_node.position - position
	return int(Vector3(diff.x, 0, diff.z).length())

func _choose_wererat_action(distance: int) -> void:
	if distance <= 1:
		chosen_action = _get_action("bite")
	elif distance >= 6:
		chosen_action = _get_action("scurry")
	else:
		chosen_action = _get_action("move")

func _choose_skeleton_action(distance: int) -> void:
	if distance <= 1:
		chosen_action = _get_action("attack")
	else:
		chosen_action = _get_action("move")

func _choose_troll_action(distance: int) -> void:
	if distance <= 1:
		# 60% smash (heavy), 40% kick (fast)
		if randf() < 0.6:
			chosen_action = _get_action("smash")
		else:
			chosen_action = _get_action("kick")
	else:
		chosen_action = _get_action("move")

func _choose_archer_rat_action(distance: int) -> void:
	# A nest's archer climbs to its cliff top and holds it: it walks up first,
	# then shoots whoever is in range from the high ground and otherwise
	# waits — no kiting, no chasing.
	if perch_cell.x >= 0:
		if _at_perch():
			_home_cell = perch_cell  # idle pacing stays on the cliff top
			chosen_action = _get_action("shoot") if distance <= int(attack_range) else {}
		else:
			chosen_action = _get_action("get_into_range")
		return
	if distance <= 2:
		# Too close! Scurry away to get distance
		chosen_action = _get_action("scurry_away")
	elif distance > 4:
		# Out of range - move closer
		chosen_action = _get_action("get_into_range")
	else:
		# In range (3-4 tiles) - shoot!
		chosen_action = _get_action("shoot")

func _at_perch() -> bool:
	return grid_manager != null and perch_cell.x >= 0 \
			and grid_manager.world_to_grid(position) == perch_cell

## --- Rat King ---

func _choose_rat_king_action(distance: int, player_node: Node3D = null) -> void:
	## Wounded past a threshold, the king makes for a nest and feeds on it;
	## otherwise he bites, lays a brood, and repositions like any brute.
	if _nest_target != null and not _nest_available(_nest_target):
		# The nest he was running for is gone (destroyed, or drained): pick
		# another untouched one if any remain, else fight on.
		_nest_target = _pick_nest()
		_nest_stuck = 0
	if _nest_target != null:
		if _cell_adjacent_to(_nest_target):
			chosen_action = _get_action("nest_heal")
		else:
			chosen_action = _get_action("seek_nest")
		return
	# sheet: Infest (5 tempo) comes with no selection rule. Ours: he lays the
	# brood when the player is out of arm's reach and holds no Infest yet;
	# in reach he bites, and while a brood still squirms in the hand he
	# closes in like any brute.
	if distance > 1 and player_node != null and not _hand_has_card_id(player_node, "infest"):
		chosen_action = _get_action("infest")
		return
	_choose_melee_action(distance, "bite")

func _nest_available(nest: Enemy) -> bool:
	return nest != null and is_instance_valid(nest) and nest.is_alive() and not nest.nest_used

func _pick_nest() -> Enemy:
	## A random untouched, still-standing nest from main's list (null if none).
	if not nest_provider.is_valid():
		return null
	var pool: Array = []
	for n in nest_provider.call():
		if n is Enemy and _nest_available(n):
			pool.append(n)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]

func _cell_adjacent_to(node: Node3D) -> bool:
	if grid_manager == null:
		return position.distance_to(node.position) <= 1.5
	var a := grid_manager.world_to_grid(position)
	var b := grid_manager.world_to_grid(node.position)
	return maxi(absi(a.x - b.x), absi(a.y - b.y)) <= 1

func _rat_king_consider_nest() -> void:
	## Called on every hit: at 50%, then 30%, then 30% again (he heals in
	## between) the king drops what he is doing and bolts for a nest. A
	## threshold is spent whether or not a nest is left to run to.
	if enemy_type != EnemyType.RAT_KING or is_dead or _nest_target != null:
		return
	if _nest_flights_done >= NEST_FLIGHT_THRESHOLDS.size():
		return
	var threshold: float = NEST_FLIGHT_THRESHOLDS[_nest_flights_done]
	if current_health > max_health * threshold:
		return
	_nest_flights_done += 1
	_nest_target = _pick_nest()
	_nest_stuck = 0
	if _nest_target == null:
		print("[%s] Wounded, but every nest is spent — he fights on!" % enemy_name)
		return
	chosen_action = {}
	action_tempo_counter = 0
	print("[%s] Bolts for the %s nest! (flight %d of %d)" % [enemy_name, _nest_target.nest_label, _nest_flights_done, NEST_FLIGHT_THRESHOLDS.size()])
	_dash_towards_target(_nest_target.position, 6)

func _try_seek_nest() -> bool:
	if _nest_target == null or not _nest_available(_nest_target):
		return false
	var before := position
	_dash_towards_target(_nest_target.position, 5)
	if not is_moving and before.distance_to(position) < 0.01:
		# Hemmed in: give the nest up after a few fruitless tries so the king
		# never idles at a wall while the player stands on the approach.
		_nest_stuck += 1
		if _nest_stuck >= 3:
			print("[%s] Cannot reach the %s nest — gives it up." % [enemy_name, _nest_target.nest_label])
			_nest_target = null
	return true

func _try_nest_heal() -> bool:
	## Feed on the nest: restore its share of max health and drain it for good.
	var nest := _nest_target
	_nest_target = null
	if nest == null or not _nest_available(nest):
		return false
	var amount := maxi(1, roundi(max_health * nest.nest_heal_pct))
	nest.drain_nest()
	_regenerate(amount)
	print("[%s] Feeds on the %s nest: +%d health" % [enemy_name, nest.nest_label, amount])
	return true

## --- Rat King: Infest ---

const INFEST_RADIUS := 10  # sheet: "each rat within a 10 square radius"

func _hand_has_card_id(node: Node3D, cid: String) -> bool:
	if node == null or not node.has_method("get_deck_manager"):
		return false
	var deck = node.get_deck_manager()
	if deck == null or not ("hand" in deck):
		return false
	for c in deck.hand:
		if c.card_id == cid:
			return true
	return false

func _rats_within(radius: int) -> Array:
	## Living rats within `radius` squares of the king (Manhattan, as every
	## range here), the king himself included: Wererats and Archer Rats. The
	## Swarm is bugs and a nest is a structure — neither is a rat (sheet:
	## "each rat ... including himself").
	var out: Array = []
	for e in _sibling_enemies():
		if e.enemy_type in [EnemyType.WERERAT, EnemyType.ARCHER_RAT, EnemyType.RAT_KING] \
				and _cells_between(self, e) <= radius:
			out.append(e)
	return out

func _try_infest(target_node: Node3D) -> bool:
	## Infest (5 tempo): one Infest card into the hand per rat within 10
	## squares, himself included. Each hatches into 2 Wererats beside the
	## holder if it is still in the hand 5 tempo later (DeckManager counts
	## the fuse, hand only); playing it for 50 mana or discarding it ends
	## the brood.
	var deck = target_node.get_deck_manager() if target_node.has_method("get_deck_manager") else null
	if deck == null:
		turn_completed.emit()
		return true
	var rats := _rats_within(INFEST_RADIUS)
	var main = get_parent()
	var spawner = main.enemy_spawner if main and "enemy_spawner" in main else null
	for _r in rats:
		var card: Card = Card.create_infest()
		if spawner:
			# Bound to the spawner, not the king: a brood laid by a king
			# since slain still hatches. Leaving the room frees the spawner,
			# the handler goes invalid, and the card crumbles unhatched.
			card.hatch_handler = Callable(spawner, "spawn_hatchlings").bind(target_node, EnemyType.WERERAT, 2)
		deck.add_card_to_hand(card)
	print("[%s] INFEST — %d brood(s) squirm into the hand (%d rat(s) within %d)" % [enemy_name, rats.size(), rats.size(), INFEST_RADIUS])
	turn_completed.emit()
	return true

## --- Sewer Cobra ---

# sheet: Venom Spray — "range 5 (in a cone, only targeting the immediate
# square in front of it to 4 squares at range 5)". Read here as a forward
# cone down the dominant axis toward the target: at forward distance 1..5
# the half-width is 0, 1, 1, 1, 2 — widths 1, 3, 3, 3, 5 — so it opens from
# the one square in front to a 5-wide row at range 5. TODO(sheet): "4
# squares at range 5" may mean a 4-wide far row; the grid has no even,
# centred row, so the cone ends 5 wide.
const VENOM_CONE_HALF_WIDTH := [0, 1, 1, 1, 2]
const VENOM_POISON := 8        # sheet: 8 poison to all targets in the cone
const VENOM_ARMOR_DAMAGE := 10  # sheet: 10 damage, only to a target with armor
const COBRA_THORNS := 5        # sheet: 5 thorns while it has armor
const COBRA_HEALTH_POISON := 3  # sheet: 3 poison when hit directly to health
const COBRA_EXPOSED_STUN := 3   # sheet: stunned 3 tempo on exposure

func _venom_cone_cells(target_node: Node3D) -> Array:
	if not grid_manager:
		return []
	var my_cell: Vector2i = grid_manager.world_to_grid(position)
	var t_cell: Vector2i = grid_manager.world_to_grid(target_node.position)
	var diff: Vector2i = t_cell - my_cell
	var forward := Vector2i(signi(diff.x), 0) if absi(diff.x) >= absi(diff.y) else Vector2i(0, signi(diff.y))
	if forward == Vector2i.ZERO:
		forward = Vector2i(1, 0)
	var side := Vector2i(-forward.y, forward.x)
	var cells: Array = []
	for f in range(1, VENOM_CONE_HALF_WIDTH.size() + 1):
		var half: int = VENOM_CONE_HALF_WIDTH[f - 1]
		for l in range(-half, half + 1):
			cells.append(my_cell + forward * f + side * l)
	return cells

func _try_venom_spray(target_node: Node3D) -> bool:
	## Venom Spray (15 tempo, Async): 8 Poison to every player-side unit in
	## the cone; one that has armor also takes 10 (armor absorbs it first,
	## as any hit). No armor, no immediate damage — the poison is the bite.
	## The numbers are the sheet's, flat: the band rebalance scales the
	## bite, not the venom. A spray that finds nobody is spent all the same
	## (Async: the clock restarts whether or not it lands).
	var cells := _venom_cone_cells(target_node)
	var hit := 0
	if cells.is_empty():
		# No grid (bare tests): the spray reaches whoever it is aimed at.
		if _get_cell_distance(target_node) <= VENOM_CONE_HALF_WIDTH.size():
			_venom_hit(target_node)
			hit = 1
	else:
		for u in _player_units():
			if not is_instance_valid(u):
				continue
			if grid_manager.world_to_grid(u.position) in cells:
				_venom_hit(u)
				hit += 1
	print("[%s] VENOM SPRAY — %d unit(s) in the cone" % [enemy_name, hit])
	turn_completed.emit()
	return true

func _venom_hit(u: Node3D) -> void:
	_apply_player_debuff(u, Debuff.create(Debuff.DebuffType.POISON, VENOM_POISON, 15))
	if u.has_method("get_stats"):
		var st = u.get_stats()
		if st and st.get_total_armor() > 0:
			_deal_damage_to_player(u, VENOM_ARMOR_DAMAGE, "Venom Spray")

func _cobra_attacker() -> Node3D:
	## Who the cobra answers: the player, as Cerberus's Roar thorns read it
	## (TODO(sheet): co-op — a second player's hit is answered on P1).
	var main = get_parent()
	if main == null or not ("player" in main) or main.player == null or not is_instance_valid(main.player):
		return null
	return main.player

func _cobra_strike_back(dmg: int) -> void:
	## The standing thorns: the attacker's direct hit costs them `dmg`.
	var who := _cobra_attacker()
	if who == null:
		return
	var st = who.get_stats() if who.has_method("get_stats") else null
	if st == null:
		return
	st.take_damage(dmg)
	print("[%s] Thorns bite back for %d (armored)" % [enemy_name, dmg])

func _cobra_poison_attacker(stacks: int) -> void:
	## A hit that cost it health: the attacker is poisoned.
	var who := _cobra_attacker()
	if who == null:
		return
	_apply_player_debuff(who, Debuff.create(Debuff.DebuffType.POISON, stacks, 15))
	print("[%s] Venom in the wound — %d Poison on the attacker" % [enemy_name, stacks])

## --- Grave Digger ---

func _choose_grave_digger_action() -> void:
	## Nothing but the job: walk to the broken stone, then work on it.
	if repair_cell.x < 0:
		chosen_action = {}
		return
	if _cell_adjacent_to_cell(repair_cell):
		chosen_action = _get_action("repair")
	else:
		chosen_action = _get_action("dig_walk")

func _cell_adjacent_to_cell(cell: Vector2i) -> bool:
	if grid_manager == null:
		return false
	var a := grid_manager.world_to_grid(position)
	return maxi(absi(a.x - cell.x), absi(a.y - cell.y)) <= 1

func _try_dig_walk() -> bool:
	if repair_cell.x < 0 or grid_manager == null:
		return false
	if not _start_path(_build_greedy_path(position, repair_cell, maxi(1, int(move_distance)))):
		print("[%s] Cannot get closer to the stone this tempo" % enemy_name)
	return true

func _try_repair() -> bool:
	## The 8 tempo are up: the stone stands again, and the digger is done.
	if repair_cell.x < 0:
		return false
	print("[%s] Sets the gravestone at %s right" % [enemy_name, repair_cell])
	if repair_handler.is_valid():
		repair_handler.call(self)
	return true

## --- Cerberus ---

func _foes_in_play() -> Array:
	## The players Cerberus watches: the spawner's party in co-op, else the
	## scene's one player.
	var main = get_parent()
	if main == null:
		return []
	var out: Array = []
	if "enemy_spawner" in main and main.enemy_spawner and not main.enemy_spawner.players.is_empty():
		for p in main.enemy_spawner.players:
			if is_instance_valid(p) and p.has_method("get_stats") and p.get_stats():
				out.append(p)
	elif "player" in main and main.player and is_instance_valid(main.player) and main.player.has_method("get_stats"):
		out.append(main.player)
	return out

func _choose_cerberus_action(distance: int) -> void:
	## The Sync clock only ever carries Swipe, Roar and Move: Bite and Venom
	## Tail are Async (sheet) and fire on their own clocks whenever they come
	## up in reach. Close in; Roar when the thorns are spent, else Swipe.
	if distance > 1:
		if enemy_thorns <= 0 and randf() < 0.25:
			chosen_action = _get_action("cerberus_roar")
		else:
			chosen_action = _get_action("move")
		return
	if enemy_thorns <= 0 and randf() < 0.35:
		chosen_action = _get_action("cerberus_roar")
	else:
		chosen_action = _get_action("swipe")

func _try_cerberus_bite(target_node: Node3D) -> bool:
	## Bite: 25. Below 66% health the second head bites too (25 + 5 Bleed);
	## below 33% the third head bites as well (25, and the wound feeds him).
	if is_disarmed or not _in_attack_range(target_node):
		# Async: a bite whose tempo comes up out of reach is spent — the Sync
		# clock does the walking, so no _try_move here.
		print("[%s] Bite comes up out of reach — spent" % enemy_name)
		return false
	var dmg: int = attack_damage + strengthen_stacks
	_deal_damage_to_player(target_node, dmg, "Bite")
	if current_health * 3 < max_health * 2:
		_deal_damage_to_player(target_node, dmg, "Second Head")
		_apply_player_debuff(target_node, Debuff.create(Debuff.DebuffType.BLEED, 5, 15))
	if current_health * 3 < max_health:
		_deal_damage_to_player(target_node, dmg, "Third Head")
		_regenerate(dmg)
	turn_completed.emit()
	return true

func _try_swipe(target_node: Node3D) -> bool:
	## Swipe: no wound of its own, but 8 Bleed.
	return _try_elemental(target_node, 0, "Swipe", {"bleed": 8})

func _try_venom_tail(target_node: Node3D) -> bool:
	## Venom Tail: the victim discards 3 random cards and is stunned for 15
	## tempo; when the stun lifts they gain 2 Vulnerable and 10 tempo of Cuffed.
	if is_disarmed or not _in_attack_range(target_node):
		# Async: spent when it comes up out of reach (see Bite).
		print("[%s] Venom Tail comes up out of reach — spent" % enemy_name)
		return false
	if target_node.has_method("get_deck_manager"):
		var deck = target_node.get_deck_manager()
		if deck and "hand" in deck:
			var dropped := 0
			for _i in range(3):
				if deck.hand.is_empty():
					break
				var card = deck.hand[randi() % deck.hand.size()]
				if deck.discard_card_from_hand(card):
					dropped += 1
			print("[%s] Venom Tail: %d card(s) knocked from the hand" % [enemy_name, dropped])
	_apply_player_debuff(target_node, Debuff.create(Debuff.DebuffType.STUN, 0, 15))
	_venom_countdown = 15
	_venom_victim = target_node
	turn_completed.emit()
	return true

func _tick_venom(amount: int) -> void:
	## The aftermath lands the moment the victim's Stun is actually gone
	## (sheet: "once the stun is over") — cleansed early counts; the 15-tempo
	## countdown stays as the upper bound should the stun never have landed.
	if _venom_countdown <= 0:
		return
	_venom_countdown -= amount
	var stun_gone := false
	if _venom_victim != null and is_instance_valid(_venom_victim) and _venom_victim.has_method("get_debuff_manager"):
		var vdm = _venom_victim.get_debuff_manager()
		stun_gone = vdm != null and not vdm.has_debuff(Debuff.DebuffType.STUN)
	if _venom_countdown > 0 and not stun_gone:
		return
	_venom_countdown = 0
	if _venom_victim != null and is_instance_valid(_venom_victim):
		_apply_player_debuff(_venom_victim, Debuff.create(Debuff.DebuffType.VULNERABLE, 2, 15))
		_apply_player_debuff(_venom_victim, Debuff.create(Debuff.DebuffType.CUFFED, 0, 10))
		print("[%s] The venom lingers: 2 Vulnerable, Cuffed for 10 tempo" % enemy_name)
	_venom_victim = null

func _try_cerberus_roar() -> bool:
	## Roar: 25 armor and 25 thorns.
	current_armor += 25
	enemy_thorns += 25
	update_health_display()
	_update_status_indicators()
	print("[%s] ROARS — +25 armor, +25 thorns (%d/%d)" % [enemy_name, current_armor, enemy_thorns])
	turn_completed.emit()
	return true

func _gain_guardian_brace(why: String) -> void:
	_brace_charges += 5
	print("[%s] Guardian of Death (%s): Brace 30%% for %d hits" % [enemy_name, why, _brace_charges])
	_update_status_indicators()

func _within_tiles(node: Node3D, radius: float) -> bool:
	var d := node.position - position
	return Vector3(d.x, 0, d.z).length() <= radius

func _guardian_scan() -> void:
	## Guardian of Death: every unit in play — his foes and his allies (the
	## door among them) — watched for the moment it drops below half health
	## within 8 squares. Each such drop is another 5 hits of Brace; a unit
	## that heals back above half and drops again counts again.
	var units: Array = []
	for p in _foes_in_play():
		var st = p.get_stats()
		units.append([p, st.current_health, st.max_health])
	for e in _sibling_enemies():
		if e != self:
			units.append([e, e.current_health, e.max_health])
	for u in units:
		var key: int = u[0].get_instance_id()
		var below: bool = int(u[1]) * 2 < int(u[2])
		if _guardian_watch.has(key):
			if below and not _guardian_watch[key] and _within_tiles(u[0], GUARDIAN_RADIUS):
				_gain_guardian_brace("%s below half" % (u[0].enemy_name if u[0] is Enemy else "a foe"))
		_guardian_watch[key] = below

func _hook_deathyard_dog() -> void:
	## Deathyard Dog: a foe healing within 5 squares gives him 15 Strengthen.
	if _deathyard_hooked:
		return
	var foes := _foes_in_play()
	if foes.is_empty():
		return
	_deathyard_hooked = true
	for p in foes:
		var st = p.get_stats()
		if st.has_signal("healed"):
			st.healed.connect(_on_foe_healed.bind(p))

func _on_foe_healed(amount: int, who: Node3D) -> void:
	if is_dead or amount <= 0 or who == null or not is_instance_valid(who):
		return
	if not _within_tiles(who, DEATHYARD_RADIUS):
		return
	strengthen_stacks += 15
	print("[%s] Deathyard Dog: a foe heals in reach — +15 Strengthen (%d)" % [enemy_name, strengthen_stacks])
	_update_status_indicators()

func _thorns_strike_back() -> void:
	## Roar's thorns: the player's direct hit costs them the thorn damage,
	## and one thorn is spent per hit.
	var main = get_parent()
	if main == null or not ("player" in main) or main.player == null or not is_instance_valid(main.player):
		return
	var st = main.player.get_stats() if main.player.has_method("get_stats") else null
	if st == null:
		return
	var dmg := enemy_thorns
	enemy_thorns -= 1
	st.take_damage(dmg)
	print("[%s] Thorns bite back for %d (%d thorns left)" % [enemy_name, dmg, enemy_thorns])
	_update_status_indicators()

## --- Hell's Door ---

func _door_check_thresholds() -> void:
	## At 75%, 50% and 33% the door seals itself against all damage for 10 tempo.
	for t in DOOR_SEAL_THRESHOLDS:
		if t in _door_thresholds_hit:
			continue
		if current_health > 0 and current_health <= max_health * t:
			_door_thresholds_hit.append(t)
			door_sealed_tempo = DOOR_SEAL_TEMPO
			print("[%s] Seals itself at %d%% — invulnerable for %d tempo" % [enemy_name, int(t * 100), DOOR_SEAL_TEMPO])
	_update_status_indicators()

func drain_nest() -> void:
	## A nest the king has fed on: spent, and it reads so (greyed straw).
	nest_used = true
	if _enemy_figure and "_sprite" in _enemy_figure and _enemy_figure._sprite:
		_enemy_figure._sprite.modulate = Color(0.45, 0.42, 0.4)
	if _enemy_figure and _enemy_figure.has_method("flash"):
		_enemy_figure.flash(Color(0.4, 0.9, 0.5))

func _choose_hydra_action(distance: int) -> void:
	# Once enraged (4th hit) she will heal to full when meaningfully hurt.
	if hydra_heal_unlocked and current_health <= max_health / 2:
		chosen_action = _get_action("hydra_heal")
	elif distance <= 1:
		chosen_action = _get_action("hydra_attack")
	else:
		chosen_action = _get_action("hydra_move")

func _choose_soldier_action(distance: int) -> void:
	if distance <= 1:
		chosen_action = _get_action("goblin_attack")
	else:
		chosen_action = _get_action("goblin_move")

func _choose_mage_action(distance: int) -> void:
	# attack_range is in world units (~cells); ember when the player is in range.
	if distance <= int(attack_range):
		chosen_action = _get_action("ember")
	else:
		chosen_action = _get_action("goblin_move")

func _choose_shaman_action(distance: int) -> void:
	if distance <= int(attack_range):
		# Heal wounded allies, otherwise lay down a wall of fire.
		if _allies_need_healing() and randf() < 0.5:
			chosen_action = _get_action("sear_wounds")
		else:
			chosen_action = _get_action("fire_wall")
	else:
		chosen_action = _get_action("goblin_move")

func _allies_need_healing() -> bool:
	for e in _sibling_enemies():
		if e.current_health < e.max_health:
			return true
	return false

func _sibling_enemies() -> Array:
	## Living enemies sharing this enemy's parent (the main scene), including self.
	var out: Array = []
	var parent = get_parent()
	if not parent:
		return out
	for child in parent.get_children():
		if child is Enemy and child.is_alive():
			out.append(child)
	return out

## --- Forest-act action selection ---

func _choose_sludge_action(distance: int) -> void:
	# Melee up close, spit at range, otherwise close in.
	if distance <= 1:
		chosen_action = _get_action("sludge_melee")
	elif distance <= int(attack_range):
		chosen_action = _get_action("sludge_spit")
	else:
		chosen_action = _get_action("move")


func _choose_melee_action(distance: int, attack_name: String) -> void:
	if distance <= 1:
		chosen_action = _get_action(attack_name)
	else:
		chosen_action = _get_action("move")

func _choose_ranged_action(distance: int, attack_name: String) -> void:
	# Silenced casters cannot fire their spell/ranged attack; they reposition instead.
	if is_silenced:
		chosen_action = _get_action("move")
	elif distance <= int(attack_range):
		chosen_action = _get_action(attack_name)
	else:
		chosen_action = _get_action("move")

func _choose_beaver_action(distance: int) -> void:
	# Chomp queues an immediate Tail Whip follow-up (resolves 2 tempo later).
	if _beaver_followup:
		chosen_action = _get_action("tail_whip")
	elif distance <= 1:
		chosen_action = _get_action("chomp")
	else:
		chosen_action = _get_action("move")

func _choose_hunter_action(distance: int) -> void:
	# Hook reaches out to 7 tiles: ready at once the first time (sheet:
	# "starts charged"), then 8 tempo to recharge after each one. Net Throw
	# whenever it is off its 8-tempo cooldown and the target is close
	# (sheet: no range given — within 3 squares, TODO(sheet)); cleave is the
	# melee swipe.
	if _hook_recharge <= 0 and distance >= 2 and distance <= 7:
		chosen_action = _get_action("hook")
	elif _net_cooldown <= 0 and distance <= 3:
		chosen_action = _get_action("net_throw")
	elif distance <= 1:
		chosen_action = _get_action("cleave")
	else:
		chosen_action = _get_action("move")

func _choose_treant_action(distance: int) -> void:
	if distance <= 1:
		chosen_action = _get_action("treant_slam") if randf() < 0.6 else _get_action("root")
	elif current_health * 2 < max_health:
		# Badly hurt and out of melee: draw deep and mend.
		chosen_action = _get_action("treant_heal")
	elif distance <= 4:
		chosen_action = _get_action("root")
	else:
		chosen_action = _get_action("move")

## --- Elite first-pass action selection ---

func _choose_large_bear_action(distance: int) -> void:
	# Roar softens everything nearby (4-tile radius) between mauls.
	if distance <= 4 and _roar_cooldown <= 0:
		chosen_action = _get_action("roar")
		_roar_cooldown = 15
	elif distance <= 1:
		chosen_action = _get_action("maul")
	else:
		chosen_action = _get_action("move")

func _choose_werewolf_action(distance: int, target: Node3D) -> void:
	# Ramping rhythm: each consecutive claw on the SAME target arms 1 tempo
	# faster (5, 4, 3...); switching targets resets the rhythm. The streak is
	# dropped HERE, when the claw is armed, so the first claw on a new target
	# takes the full 5 (sheet) rather than inheriting the old streak's pace
	# (_try_werewolf_claw restarts the count when it lands). Build a fresh
	# dict so the base action stays 5.
	if target != _ww_last_target:
		_ww_streak = 0
	if distance <= 1:
		var cost: int = maxi(1, 5 - _ww_streak)
		chosen_action = {"name": "werewolf_claw", "tempo_cost": cost}
	else:
		chosen_action = _get_action("move")

func _choose_vampire_action(distance: int) -> void:
	# Absorb is always cast right after a bat-form escape, at any range.
	if _vamp_absorb_pending:
		chosen_action = _get_action("absorb")
	elif distance <= 1:
		chosen_action = _get_action("vampire_bite")
	else:
		chosen_action = _get_action("move")

func _choose_necromancer_action(distance: int) -> void:
	if is_silenced:
		chosen_action = _get_action("move")
	elif distance <= int(attack_range):
		# Keep a small undead retinue up; bolt (and hex) between raises.
		if _necro_summons_alive < 3 and randf() < 0.5:
			chosen_action = _get_action("summon_skeleton")
		else:
			chosen_action = _get_action("dark_bolt")
	else:
		chosen_action = _get_action("move")

func _choose_bone_dragon_action(distance: int) -> void:
	if distance <= 1:
		chosen_action = _get_action("dragon_bite") if randf() < 0.6 else _get_action("breath_swarm")
	elif distance <= 6 and not is_silenced:
		chosen_action = _get_action("breath_swarm")
	else:
		chosen_action = _get_action("move")

func _choose_manticore_action(distance: int) -> void:
	if distance <= 1:
		if _stinger_cooldown <= 0:
			chosen_action = _get_action("stinger")
		else:
			chosen_action = _get_action("manticore_bite")
	else:
		chosen_action = _get_action("move")

func _choose_wyvern_action(distance: int) -> void:
	# Talon Grab reaches out to 3 tiles (it flies above its target).
	if distance <= 3 and _talon_cooldown <= 0:
		chosen_action = _get_action("talon_grab")
	elif distance <= 1:
		chosen_action = _get_action("wyvern_bite")
	else:
		chosen_action = _get_action("move")

func _choose_ifrit_action(distance: int) -> void:
	# Fire Breath covers a 5x5 in front, so it fires from up to 4 tiles out.
	if distance <= 1:
		chosen_action = _get_action("ifrit_attack") if randf() < 0.6 else _get_action("fire_breath")
	elif distance <= 4 and not is_silenced:
		chosen_action = _get_action("fire_breath")
	else:
		chosen_action = _get_action("move")

func _choose_minotaur_action(distance: int) -> void:
	# A queued Bull Rush (armed by Labyrinth Leap) takes priority.
	if _minotaur_rush_pending:
		chosen_action = _get_action("bull_rush")
	elif distance <= 1:
		chosen_action = _get_action("minotaur_attack")
	else:
		chosen_action = _get_action("move")

func _choose_legacy_action(distance: int) -> void:
	## Legacy behavior for MINION/ELITE/BOSS types.
	if distance <= 1:
		for action in actions:
			if action["name"] == "attack":
				chosen_action = action
				return
	chosen_action = _get_action("move")
	if chosen_action.is_empty() and actions.size() > 0:
		chosen_action = actions[0]

func _get_action(action_name: String) -> Dictionary:
	for action in actions:
		if action["name"] == action_name:
			return action
	return actions[0] if actions.size() > 0 else {}

#endregion
#region ACTION EXECUTION
# ============================================
# ACTION EXECUTION
# ============================================

func _execute_action(action_name: String, move_target: Node3D) -> bool:
	# Play animation for this action
	_play_enemy_animation(action_name)

	match action_name:
		"attack":
			return _try_attack(move_target)
		"move":
			return _try_move(move_target)
		"bite":
			return _try_bite(move_target)
		"scurry":
			return _try_scurry(move_target)
		"kick":
			return _try_kick(move_target)
		"smash":
			return _try_smash(move_target)
		"shoot":
			return _try_shoot(move_target)
		"scurry_away":
			return _try_scurry_away(move_target)
		"get_into_range":
			return _try_get_into_range(move_target)
		"seek_nest":
			return _try_seek_nest()
		"nest_heal":
			return _try_nest_heal()
		"infest":
			return _try_infest(move_target)
		"dig_walk":
			return _try_dig_walk()
		"repair":
			return _try_repair()
		"cerberus_bite":
			return _try_cerberus_bite(move_target)
		"swipe":
			return _try_swipe(move_target)
		"venom_tail":
			return _try_venom_tail(move_target)
		"cerberus_roar":
			return _try_cerberus_roar()
		"hydra_attack":
			return _try_hydra_attack(move_target)
		"hydra_move":
			return _try_move(move_target)
		"hydra_heal":
			return _try_hydra_heal()
		"goblin_attack":
			return _try_goblin_attack(move_target)
		"goblin_move":
			return _try_move(move_target)
		"ember":
			return _try_ember(move_target)
		"fire_wall":
			return _try_fire_wall(move_target)
		"sear_wounds":
			return _try_sear_wounds()
		# ----- Forest act -----
		"chomp":
			return _try_chomp(move_target)
		"tail_whip":
			return _try_tail_whip(move_target)
		"mini_bear_attack":
			return _try_mini_bear_attack(move_target)
		"maul":
			return _try_maul(move_target)
		"roar":
			return _try_roar(move_target)
		"wolf_bite":
			return _try_wolf_bite(move_target)
		"coyote_nip":
			return _try_elemental(move_target, attack_damage, "Nip")
		"bugbear_strike":
			return _try_bugbear_strike(move_target)
		"cleave":
			return _try_cleave(move_target)
		"net_throw":
			return _try_net_throw(move_target)
		"swoop":
			return _try_swoop(move_target)
		"hook":
			return _try_hook(move_target)
		"treant_slam":
			return _try_elemental(move_target, attack_damage, "Slam")
		"root":
			return _try_root(move_target)
		"treant_heal":
			_regenerate(_treant_heal_amount()); turn_completed.emit(); return true
		"frost_bolt":
			return _try_elemental(move_target, attack_damage, "Frost Bolt", {"slow": 1})
		"fire_bolt":
			return _try_elemental(move_target, attack_damage, "Fire Bolt", {"burn": attack_burn})
		"spark_bolt":
			return _try_elemental(move_target, attack_damage, "Spark", {"shock": attack_shock})
		"gust":
			return _try_elemental(move_target, attack_damage, "Gust")
		"boulder":
			return _try_elemental(move_target, attack_damage, "Boulder")
		# ----- Graveyard act -----
		"werewolf_claw":
			return _try_werewolf_claw(move_target)
		"vampire_bite":
			return _try_vampire_bite(move_target)
		"absorb":
			return _try_vampire_absorb()
		"flee":
			return _try_flee(move_target)
		"vanish":
			return _try_vanish()
		"dark_bolt":
			return _try_necro_bolt(move_target)
		"summon_skeleton":
			return _try_necro_summon(move_target)
		"dragon_bite":
			return _try_elemental(move_target, attack_damage, "Bite")
		"breath_swarm":
			return _try_breath_swarm(move_target)
		"collector_swing":
			return _try_elemental(move_target, attack_damage + strengthen_stacks, "Strike")
		"collect_soul":
			return _try_collect_soul(move_target)
		"titan_smash":
			return _try_elemental(move_target, attack_damage, "Smash")
		"boulder_roll":
			return _try_boulder_roll(move_target)
		"crawler_bite":
			return _try_crawler_bite(move_target)
		"web":
			return _try_crawler_web(move_target)
		"screech":
			return _try_elemental(move_target, attack_damage, "Screech")
		# ----- Sewer act -----
		"sludge_melee":
			return _try_elemental(move_target, attack_damage, "Sludge")
		"sludge_spit":
			return _try_elemental(move_target, attack_damage, "Spit")
		"pipe_attack":
			return _try_pipe_claw(move_target)
		"croc_bite":
			return _try_elemental(move_target, attack_damage, "Bite")
		"venom_spray":
			return _try_venom_spray(move_target)
		# ----- Mountains act -----
		"ice_club":
			return _try_ice_club(move_target)
		"manticore_bite":
			return _try_elemental(move_target, attack_damage, "Bite")
		"stinger":
			return _try_stinger(move_target)
		"wyvern_bite":
			return _try_elemental(move_target, attack_damage, "Bite")
		"talon_grab":
			return _try_talon_grab(move_target)
		# ----- Underworld act -----
		"ifrit_attack":
			return _try_elemental(move_target, attack_damage, "Attack")
		"fire_breath":
			return _try_fire_breath(move_target)
		"minotaur_attack":
			return _try_elemental(move_target, attack_damage + strengthen_stacks, "Attack", {"burn": attack_burn})
		"bull_rush":
			return _try_bull_rush(move_target)
		# ----- Heavens act -----
		"chain_lightning":
			return _try_chain_lightning(move_target)
		# ----- Mountains act, second pass (the enemy sheet) -----
		"hoof_punch":
			return _try_elemental(move_target, attack_damage, "Hoof Punch")
		"goat_charge":
			return _try_goat_charge(move_target)
		"dive_bomb":
			return _try_dive_bomb(move_target)
		"eye_scrape":
			return _try_eye_scrape(move_target)
		"roc_retreat":
			return _try_roc_retreat(move_target)
		"track":
			return _try_track(move_target)
		"bite_and_claw":
			return _try_bite_and_claw(move_target)
		"sunken_bite":
			return _try_sunken_bite(move_target)
		"snowball":
			return _try_snowball(move_target)
		"ice_blast":
			return _try_ice_blast(move_target)
		# ----- Underworld act, second pass -----
		"mimic":
			return _try_mimic(move_target)
		"demon_cuff":
			return _try_demon_cuff(move_target)
		"demon_attack":
			return _try_elemental(move_target, attack_damage, "Attack")
		"peck":
			return _try_elemental(move_target, attack_damage, "Peck")
		"card_steal":
			return _try_card_steal(move_target)
		"fire_web":
			return _try_fire_web(move_target)
		"mind_slow":
			return _try_mind_slow(move_target)
		"mind_cuff":
			return _try_mind_cuff(move_target)
		"spirit_spit":
			return _try_spirit_spit(move_target)
		"specter_vanish":
			return _try_specter_vanish()
		"mana_drain":
			return _try_mana_drain(move_target)
		"damaging_snap":
			return _try_damaging_snap(move_target)
		# ----- Heavens act, second pass -----
		"loves_arrow":
			return _try_loves_arrow(move_target)
		_:
			push_warning("[%s] Unknown action: %s" % [enemy_name, action_name])
			return false

func _try_hydra_attack(target_node: Node3D) -> bool:
	if is_disarmed:
		return _try_move(target_node)
	if _in_attack_range(target_node):
		_deal_damage_to_player(target_node, attack_damage + strength, "Strike")
		turn_completed.emit()
		return true
	return _try_move(target_node)

func _try_hydra_heal() -> bool:
	## Heals to full (only used once the 4th hit has enraged her).
	_regenerate(max_health)
	print("[%s] Regrows her heads — healed to full!" % enemy_name)
	turn_completed.emit()
	return true

func _try_goblin_attack(target_node: Node3D) -> bool:
	if is_disarmed:
		return _try_move(target_node)
	if _in_attack_range(target_node):
		_deal_damage_to_player(target_node, attack_damage, "Strike")
		turn_completed.emit()
		return true
	return _try_move(target_node)

func _try_ember(target_node: Node3D) -> bool:
	## Fire Goblin Mage: ranged ember — damage plus 1 burn.
	if is_disarmed or is_silenced:
		return _try_move(target_node)
	if _in_attack_range(target_node):
		_deal_damage_to_player(target_node, attack_damage, "Ember")
		_apply_burn_to_player(target_node, 1)
		turn_completed.emit()
		return true
	return _try_move(target_node)

func _try_fire_wall(target_node: Node3D) -> bool:
	## Fire Goblin Shaman: raises a wall of fire in the player's path. Damage and
	## burn are only dealt if the player walks into it (handled by Main).
	if is_disarmed or is_silenced:
		return _try_move(target_node)
	if not _in_attack_range(target_node):
		return _try_move(target_node)
	if not grid_manager:
		turn_completed.emit()
		return true
	var player_cell = grid_manager.world_to_grid(target_node.position)
	var my_cell = grid_manager.world_to_grid(position)
	# A 3-tile wall one step in front of the player (toward the shaman).
	var dir = my_cell - player_cell
	var step = Vector2i(signi(dir.x), signi(dir.y))
	if step == Vector2i.ZERO:
		step = Vector2i(1, 0)
	var center = player_cell + step
	var perp = Vector2i(step.y, step.x)  # perpendicular
	if perp == Vector2i.ZERO:
		perp = Vector2i(0, 1)
	var tiles: Array = [center, center + perp, center - perp]
	var main = get_parent()
	if main and main.has_method("register_fire_wall"):
		main.register_fire_wall(tiles, attack_damage, 3)
	print("[%s] Raises a wall of fire!" % enemy_name)
	turn_completed.emit()
	return true

func _try_sear_wounds() -> bool:
	## Fire Goblin Shaman: 2 damage to ALL allies (can kill), then heals the
	## survivors for 6.
	# Sear Wounds is a cast; silence mutes it and the shaman forfeits the action.
	if is_silenced:
		print("[%s] Silenced — cannot Sear Wounds." % enemy_name)
		turn_completed.emit()
		return true
	var allies = _sibling_enemies()
	for a in allies:
		if is_instance_valid(a):
			a.take_damage(2, false)  # from_player = false (a Hydra still counts the hit)
	for a in allies:
		if is_instance_valid(a) and a.is_alive():
			a._regenerate(6)
	print("[%s] Sears wounds — 2 to all, then heals 6." % enemy_name)
	turn_completed.emit()
	return true

func _apply_burn_to_player(player_node: Node3D, stacks: int) -> void:
	if not player_node.has_method("get_debuff_manager"):
		return
	var dm = player_node.get_debuff_manager()
	if not dm:
		return
	for i in range(stacks):
		dm.apply_debuff(Debuff.new(Debuff.DebuffType.BURN, 1))

#endregion
#region FOREST ACT
# ============================================
# FOREST ACT — ACTIONS & HELPERS
# ============================================

## Reach is measured in grid steps (no diagonals), the same distance the
## choosers use to pick an attack, so a swing lined up at arm's length
## cannot land on a target that stepped diagonally away — and a melee
## reach of 1.5 means the four neighbouring tiles, never the corners.
func _in_attack_range(target_node: Node3D) -> bool:
	return _get_cell_distance(target_node) <= int(attack_range)

func _apply_player_debuff(player_node: Node3D, debuff) -> void:
	if player_node and player_node.has_method("get_debuff_manager"):
		var dm = player_node.get_debuff_manager()
		if dm:
			dm.apply_debuff(debuff)

func _blind_player(player_node: Node3D, tempo: int) -> void:
	## Blind: mechanic lives on PlayerStats (Card.execute reads it); the debuff is
	## applied too so the status icon shows.
	if player_node.has_method("get_stats"):
		var st = player_node.get_stats()
		if st:
			st.is_blinded = true
			st.blind_tempo = tempo
	_apply_player_debuff(player_node, Debuff.create(Debuff.DebuffType.BLIND, Debuff.BLIND_MISS, tempo))
	print("[%s] Blinds the target!" % enemy_name)

## Generic elemental strike: moves into range if needed, otherwise hits for `dmg`
## (using this enemy's damage_type) and applies any debuffs in `opts`.
func _try_elemental(target_node: Node3D, dmg: int, label: String, opts := {}) -> bool:
	if is_disarmed:
		return _try_move(target_node)
	if not _in_attack_range(target_node):
		return _try_move(target_node)
	_deal_damage_to_player(target_node, dmg, label)
	if int(opts.get("burn", 0)) > 0:
		_apply_burn_to_player(target_node, int(opts["burn"]))
	if int(opts.get("shock", 0)) > 0:
		_apply_player_debuff(target_node, Debuff.create(Debuff.DebuffType.SHOCKED, int(opts["shock"]), 15))
	if int(opts.get("slow", 0)) > 0:
		_apply_player_debuff(target_node, Debuff.create_slowed(int(opts["slow"]), enemy_name))
	if int(opts.get("bleed", 0)) > 0:
		_apply_player_debuff(target_node, Debuff.create(Debuff.DebuffType.BLEED, int(opts["bleed"]), 15))
	turn_completed.emit()
	return true

func _try_chomp(target_node: Node3D) -> bool:
	if not is_disarmed and _in_attack_range(target_node):
		_deal_damage_to_player(target_node, attack_damage, "Chomp")
		_apply_player_debuff(target_node, Debuff.create(Debuff.DebuffType.STUN, 0, 3))
		_beaver_followup = true  # queue the Tail Whip follow-up
		turn_completed.emit()
		return true
	return _try_move(target_node)

func _try_tail_whip(target_node: Node3D) -> bool:
	_beaver_followup = false
	if not is_disarmed and _in_attack_range(target_node):
		_deal_damage_to_player(target_node, maxi(1, roundi(6 * _pps_dmg)), "Tail Whip")
		# Vulnerable: target takes extra damage (≈15 tempo window).
		_apply_player_debuff(target_node, Debuff.create(Debuff.DebuffType.VULNERABLE, 5, 15))
		turn_completed.emit()
		return true
	return _try_move(target_node)

func _try_mini_bear_attack(target_node: Node3D) -> bool:
	return _try_elemental(target_node, attack_damage + pack_attack_bonus, "Swipe")

func _try_maul(target_node: Node3D) -> bool:
	# Rage of the bear: below half health, attacks deal 1.5x and apply double
	# bleed (and the bear feeds on bleed damage — see main.on_player_bled).
	var dmg: int = attack_damage + strengthen_stacks
	var bleed: int = bleed_on_attack
	if current_health * 2 < max_health:
		dmg = roundi(dmg * 1.5)
		bleed *= 2
	return _try_elemental(target_node, dmg, "Maul", {"bleed": bleed})

func _try_wolf_bite(target_node: Node3D) -> bool:
	var dmg = attack_damage + (2 if _wolf_aura_active() else 0)
	return _try_elemental(target_node, dmg, "Bite")

func _try_bugbear_strike(target_node: Node3D) -> bool:
	# First Strike: if the player has not hit this bugbear yet, +8 damage.
	var dmg = attack_damage + (8 if hits_taken == 0 else 0)
	return _try_elemental(target_node, dmg, "Strike")

func _try_swoop(target_node: Node3D) -> bool:
	if not is_disarmed and _in_attack_range(target_node):
		_deal_damage_to_player(target_node, attack_damage, "Swoop")
		if randf() < attack_blind_chance:
			_blind_player(target_node, 5)
		turn_completed.emit()
		return true
	return _try_move(target_node)

func _try_hook(target_node: Node3D) -> bool:
	## Reach out (range 2-7) and reel the player in to just in front of the hunter.
	var dist = _get_cell_distance(target_node)
	if dist < 2 or dist > 7:
		return _try_move(target_node)
	if grid_manager:
		var my_cell = grid_manager.world_to_grid(position)
		var pl_cell = grid_manager.world_to_grid(target_node.position)
		var dir = pl_cell - my_cell
		var dest = Vector2i(my_cell.x + signi(dir.x), my_cell.y + signi(dir.y))
		var world = grid_manager.grid_to_world(dest)
		if dungeon_manager:
			world.y = dungeon_manager.get_elevation_world_y(dest)
		target_node.target_position = world
		if "is_moving" in target_node:
			target_node.is_moving = true
	print("[%s] Hooks the target and reels them in!" % enemy_name)
	_hook_recharge = 8  # sheet: Hook's 8 tempo — the next one needs winding again
	turn_completed.emit()
	return true

func _try_cleave(target_node: Node3D) -> bool:
	## Cleave (sheet): 8 damage to the three squares in front of the hunter —
	## the adjacent cell toward the target and the two beside it, the same row
	## the Shaman's fire wall uses. Every player-side unit standing there is
	## hit, summons included. A diagonal target takes the dominant axis as
	## "front" (ties go to x), which still covers the diagonal cell itself.
	if is_disarmed or not _in_attack_range(target_node):
		return _try_move(target_node)
	if not grid_manager:
		_deal_damage_to_player(target_node, attack_damage, "Cleave")
		turn_completed.emit()
		return true
	var my_cell: Vector2i = grid_manager.world_to_grid(position)
	var dir: Vector2i = grid_manager.world_to_grid(target_node.position) - my_cell
	var step := Vector2i(signi(dir.x), 0) if absi(dir.x) >= absi(dir.y) else Vector2i(0, signi(dir.y))
	if step == Vector2i.ZERO:
		step = Vector2i(1, 0)
	var perp := Vector2i(step.y, step.x)
	var center := my_cell + step
	var front: Array = [center, center + perp, center - perp]
	var hit := 0
	for u in _player_units():
		if not is_instance_valid(u):
			continue
		if grid_manager.world_to_grid(u.position) in front:
			_deal_damage_to_player(u, attack_damage, "Cleave")
			hit += 1
	if hit == 0:
		# The target stands in reach but off the three squares (a diagonal
		# nobody else fills): the swing still lands on them.
		_deal_damage_to_player(target_node, attack_damage, "Cleave")
	print("[%s] Cleaves the ground in front — %d caught" % [enemy_name, maxi(1, hit)])
	turn_completed.emit()
	return true

func _try_net_throw(target_node: Node3D) -> bool:
	## Net Throw (sheet): "apply weighted to the target's entire hand" — one
	## Weighted stack per card held, so every card costs +2 tempo until that
	## many have been played (the closest the stack-driven debuff comes to a
	## whole hand). 2 tempo, then 8 tempo of cooldown. The sheet gives no
	## range: within 3 squares (TODO(sheet)).
	if is_disarmed or _get_cell_distance(target_node) > 3:
		return _try_move(target_node)
	var hand_size := 0
	if target_node.has_method("get_deck_manager"):
		var deck = target_node.get_deck_manager()
		if deck and "hand" in deck:
			hand_size = deck.hand.size()
	_net_cooldown = 8
	if hand_size <= 0:
		print("[%s] Net Throw finds an empty hand — nothing to weigh down" % enemy_name)
		turn_completed.emit()
		return true
	_apply_player_debuff(target_node, Debuff.create(Debuff.DebuffType.WEIGHTED, hand_size))
	print("[%s] Net Throw — the whole hand is Weighted (%d)" % [enemy_name, hand_size])
	turn_completed.emit()
	return true

func _try_root(target_node: Node3D) -> bool:
	if _get_cell_distance(target_node) > 4:
		return _try_move(target_node)
	# Rooted: pinned in place (can still attack) for ~8 tempo.
	_apply_player_debuff(target_node, Debuff.create(Debuff.DebuffType.ROOTED, 0, 8))
	print("[%s] Roots erupt — the target is pinned!" % enemy_name)
	turn_completed.emit()
	return true

func _wolf_aura_active() -> bool:
	for e in _sibling_enemies():
		if e != self and e.enemy_type == EnemyType.WOLF and position.distance_to(e.position) <= 4.0:
			return true
	return false

func _treant_heal_amount() -> int:
	var amt = 5
	var pct = float(current_health) / float(max_health) * 100.0
	if pct < 60.0:
		amt += 2 * int((60.0 - pct) / 10.0)
	return amt

func _try_pipe_claw(target_node: Node3D) -> bool:
	## Pipe Crawler: claw with a 25% chance to disarm the player (5 tempo).
	if is_disarmed:
		return _try_move(target_node)
	if not _in_attack_range(target_node):
		return _try_move(target_node)
	_deal_damage_to_player(target_node, attack_damage, "Claw")
	if randf() < 0.25:
		_apply_player_debuff(target_node, Debuff.create(Debuff.DebuffType.DISARM, 0, 5))
		print("[%s] Claw knocks the weapon loose — disarmed!" % enemy_name)
	turn_completed.emit()
	return true

#endregion
#region ELITE FIRST PASS
# ============================================
# ELITE FIRST PASS — ACTIONS & HELPERS
# ============================================

## Every player-side unit on the field: the player(s), plus their living
## summons (co-op aware, mirrors EnemySpawner._target_for's candidate list).
func _player_units() -> Array:
	var out: Array = []
	var main = get_parent()
	if not main:
		return out
	if "enemy_spawner" in main and main.enemy_spawner:
		var sp = main.enemy_spawner
		var ps: Array = sp._living_players()
		if ps.is_empty() and sp.player and is_instance_valid(sp.player):
			ps = [sp.player]
		out = ps + sp._living_summons()
	elif "player" in main and main.player and is_instance_valid(main.player):
		out = [main.player]
	return out

func _unit_health(u: Node3D) -> int:
	if u.has_method("get_stats"):
		var st = u.get_stats()
		if st:
			return int(st.current_health)
	if "current_health" in u:
		return int(u.current_health)
	return 0

func _cells_between(a: Node3D, b: Node3D) -> int:
	if grid_manager:
		return grid_manager.get_distance_in_cells(a.position, b.position)
	var diff = b.position - a.position
	return int(Vector3(diff.x, 0, diff.z).length())

func _cell_is_free(cell: Vector2i) -> bool:
	return not (cell in blocked_tiles) and not (cell in occupied_tiles) and not (cell in _unit_cells())

func _unit_cells() -> Array:
	## Live tiles held by the player side (see unit_cells_provider).
	if unit_cells_provider.is_valid():
		return unit_cells_provider.call()
	return []

func _trim_path_tail() -> void:
	## Drop trailing waypoints that now sit on a unit's tile, so the move ends
	## one tile short instead of on top of a player, summon, or other enemy.
	if _move_path.is_empty() or not grid_manager:
		return
	var taken: Array = _unit_cells()
	for c in occupied_tiles:
		taken.append(c)
	while not _move_path.is_empty():
		var last_cell := grid_manager.world_to_grid(_move_path[_move_path.size() - 1])
		if last_cell in taken:
			_move_path.pop_back()
		else:
			break

## A free world position on/near the given spot (for summon placement).
func _free_cell_near(world_pos: Vector3, radius: int) -> Vector3:
	if not grid_manager:
		return world_pos + Vector3(1, 0, 0)
	var base := grid_manager.world_to_grid(world_pos)
	for r in range(1, radius + 1):
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			var cand: Vector2i = base + d * r
			if _cell_is_free(cand):
				var w := grid_manager.grid_to_world(cand)
				if dungeon_manager:
					w.y = dungeon_manager.get_elevation_world_y(cand)
				return w
	return grid_manager.grid_to_world(base)

## A random unoccupied cell roughly `dist` squares from `from_cell` (shrinking
## the throw until something is free).
func _random_free_cell_at_distance(from_cell: Vector2i, dist: int) -> Vector2i:
	for try_dist in range(dist, 0, -1):
		for _attempt in range(8):
			var ang := randf() * TAU
			var cand := from_cell + Vector2i(roundi(cos(ang) * try_dist), roundi(sin(ang) * try_dist))
			if _cell_is_free(cand):
				return cand
	return from_cell

func _dash_away_from(pos: Vector3, tiles: int) -> void:
	if grid_manager:
		var threat_cell = grid_manager.world_to_grid(pos)
		_start_path(_build_greedy_path(position, threat_cell, tiles, true))
	else:
		var diff = position - pos
		var direction = Vector3(diff.x, 0, diff.z).normalized()
		if direction.length() < 0.1:
			direction = Vector3(1, 0, 0)
		target_position = position + direction * float(tiles)
		is_moving = true

## --- Wererabbit ---

func _try_flee(target_node: Node3D) -> bool:
	## Loot monster: always runs AWAY from its pursuer.
	if is_instance_valid(target_node):
		_dash_away_from(target_node.position, maxi(1, int(move_distance)))
	return true

func _try_vanish() -> bool:
	## The escape: gone in a puff of smoke — no loot, no XP, no death.
	print("[%s] Vanishes in a puff of smoke!" % enemy_name)
	var main = get_parent()
	if main and "enemy_spawner" in main and main.enemy_spawner:
		main.enemy_spawner.despawn_enemy(self)
	else:
		queue_free()
	return true

## --- Crypt Crawler ---

func _choose_crawler_action(distance: int) -> void:
	# After 3 consecutive bites it webs its prey.
	if _crawler_attack_streak >= 3 and distance <= 2:
		chosen_action = _get_action("web")
	elif distance <= 1:
		chosen_action = _get_action("crawler_bite")
	else:
		chosen_action = _get_action("move")

func _try_crawler_bite(target_node: Node3D) -> bool:
	if is_disarmed or not _in_attack_range(target_node):
		_crawler_attack_streak = 0  # the chain breaks when it can't keep biting
		return _try_move(target_node)
	_deal_damage_to_player(target_node, attack_damage, "Bite")
	_crawler_attack_streak += 1
	turn_completed.emit()
	return true

func _try_crawler_web(target_node: Node3D) -> bool:
	## Webs the target: a Paralysis card lands in their hand — they cannot
	## move until it is played (other actions are fine), then it is erased.
	_crawler_attack_streak = 0
	if is_disarmed or _get_cell_distance(target_node) > 2:
		return _try_move(target_node)
	if target_node.has_method("get_deck_manager"):
		var deck = target_node.get_deck_manager()
		if deck:
			deck.add_card_to_hand(Card.create_paralysis())
			print("[%s] Webs its prey — Paralysis added to the hand!" % enemy_name)
	turn_completed.emit()
	return true

## --- Spirit Collector ---

func _choose_collector_action(distance: int) -> void:
	if distance <= 1:
		# Mostly swings; now and then it cages a piece of your soul.
		chosen_action = _get_action("collect_soul") if randf() < 0.35 else _get_action("collector_swing")
	else:
		chosen_action = _get_action("move")

func _try_collect_soul(target_node: Node3D) -> bool:
	## 8 (+ Strengthen) damage, and a 'Release Soul' card lands in the hand —
	## it saps and Drains the holder until played (which strengthens every
	## living collector, see Card._execute_release_soul), then is erased.
	if is_disarmed or not _in_attack_range(target_node):
		return _try_move(target_node)
	_deal_damage_to_player(target_node, attack_damage + strengthen_stacks, "Collect Soul")
	if target_node.has_method("get_deck_manager"):
		var deck = target_node.get_deck_manager()
		if deck:
			deck.add_card_to_hand(Card.create_release_soul())
			print("[%s] Cages a piece of their soul!" % enemy_name)
	turn_completed.emit()
	return true

## --- Grave Titan ---

func _choose_titan_action(distance: int) -> void:
	if distance <= 1:
		chosen_action = _get_action("titan_smash")
	elif distance <= 3:
		chosen_action = _get_action("boulder_roll")
	else:
		chosen_action = _get_action("move")

func _try_boulder_roll(target_node: Node3D) -> bool:
	## Rolls the boulder at anything within 3 squares.
	if is_disarmed or _get_cell_distance(target_node) > 3:
		return _try_move(target_node)
	_deal_damage_to_player(target_node, attack_damage, "Boulder Roll")
	turn_completed.emit()
	return true

## --- Large Bear ---

func _mini_bears_present() -> bool:
	for e in _sibling_enemies():
		if e != self and e.enemy_type == EnemyType.MINI_BEAR:
			return true
	return false

func _try_roar(target_node: Node3D) -> bool:
	## Roar: every enemy of the bear within a 4-square radius is left Vulnerable.
	var roared := false
	for u in _player_units():
		if _cells_between(self, u) <= 4 and u.has_method("get_debuff_manager"):
			var dm = u.get_debuff_manager()
			if dm:
				dm.apply_debuff(Debuff.create(Debuff.DebuffType.VULNERABLE, 1, 15))
				roared = true
	if roared:
		print("[%s] ROARS — everything nearby is Vulnerable!" % enemy_name)
	elif is_instance_valid(target_node):
		return _try_move(target_node)
	turn_completed.emit()
	return true

## --- Werewolf ---

func _try_werewolf_claw(target_node: Node3D) -> bool:
	if is_disarmed or not _in_attack_range(target_node):
		return _try_move(target_node)
	# Ramping rhythm: consecutive claws on the SAME target arm 1 tempo faster
	# each time (5, 4, 3...); a new target resets it (read in _choose_werewolf_action).
	_ww_streak = _ww_streak + 1 if target_node == _ww_last_target else 1
	_ww_last_target = target_node
	# +3 vs armor: armour-piercing claws.
	var dmg: int = attack_damage
	var p_stats = target_node.get_stats() if target_node.has_method("get_stats") else null
	if p_stats and p_stats.get_total_armor() > 0:
		dmg += 3
	_deal_damage_to_player(target_node, dmg, "Claw")
	# A debuffed target gets raked a second time for half damage.
	var dm = target_node.get_debuff_manager() if target_node.has_method("get_debuff_manager") else null
	if dm and dm.debuffs.size() > 0:
		_deal_damage_to_player(target_node, maxi(1, dmg / 2), "Claw (rake)")
	turn_completed.emit()
	return true

## --- Vampire ---

func _try_vampire_bite(target_node: Node3D) -> bool:
	if is_disarmed or not _in_attack_range(target_node):
		return _try_move(target_node)
	# Life steal heals 100% of HEALTH damage dealt — armor chip heals nothing.
	var p_stats = target_node.get_stats() if target_node.has_method("get_stats") else null
	var before: int = p_stats.current_health if p_stats else _unit_health(target_node)
	_deal_damage_to_player(target_node, attack_damage, "Bite")
	var after: int = p_stats.current_health if p_stats else _unit_health(target_node)
	var health_dmg: int = maxi(0, before - after)
	if health_dmg > 0:
		_regenerate(health_dmg)
	turn_completed.emit()
	return true

func _try_vampire_absorb() -> bool:
	## Cast only (and always) right after a bat-form escape: drains the
	## healthiest player-side unit on the map — 20 after the first escape,
	## 10 after the second (10 x charges spent, dwindling).
	_vamp_absorb_pending = false
	var amount: int = maxi(1, roundi(10 * (_bat_form_charges + 1) * _pps_dmg))
	var best: Node3D = null
	var best_hp: int = -1
	for u in _player_units():
		var hp := _unit_health(u)
		if hp > best_hp:
			best_hp = hp
			best = u
	if best != null:
		if best.has_method("get_stats"):
			var st = best.get_stats()
			var before: int = st.current_health if st else 0
			_deal_damage_to_player(best, amount, "Absorb")
			var stolen: int = maxi(0, before - (st.current_health if st else 0))
			_regenerate(stolen)
		elif best.has_method("take_damage"):
			best.take_damage(amount)
			_regenerate(amount)
		print("[%s] Absorbs life from the healthiest target!" % enemy_name)
	turn_completed.emit()
	return true

## --- Necromancer ---

func _try_necro_bolt(target_node: Node3D) -> bool:
	if is_disarmed or is_silenced:
		return _try_move(target_node)
	if _get_cell_distance(target_node) > int(attack_range):
		return _try_move(target_node)
	_deal_damage_to_player(target_node, attack_damage, "Bolt")
	# Hex: TWO random cards in the hand each cost +30 mana until played
	# (each hex is its own instance claiming its own card).
	if target_node.has_method("get_debuff_manager"):
		var dm = target_node.get_debuff_manager()
		if dm:
			dm.apply_debuff(Debuff.create(Debuff.DebuffType.HEXED, 30, 25))
			dm.apply_debuff(Debuff.create(Debuff.DebuffType.HEXED, 30, 25))
	turn_completed.emit()
	return true

func _try_necro_summon(_target_node: Node3D) -> bool:
	## Raises undead beside the necromancer. FIRST-PASS PLACEHOLDER roster
	## (no summon structure has been specced yet): one skeleton or zombie
	## per cast. After 5 of its summons die, it raises a Bone Dragon.
	if is_silenced:
		print("[%s] Silenced — the dead stay dead." % enemy_name)
		turn_completed.emit()
		return true
	var t: EnemyType = EnemyType.SKELETON if randf() < 0.5 else EnemyType.ZOMBIE
	if _necro_spawn(t):
		print("[%s] Raises the dead!" % enemy_name)
	turn_completed.emit()
	return true

func _necro_spawn(t: EnemyType) -> Enemy:
	var main = get_parent()
	if not main or not ("enemy_spawner" in main) or not main.enemy_spawner:
		return null
	var e: Enemy = main.enemy_spawner.spawn_enemy(t, _free_cell_near(position, 2))
	if e:
		_necro_summons_alive += 1
		e.died.connect(_on_necro_summon_died)
	return e

func _on_necro_summon_died(_e: Enemy) -> void:
	_necro_summons_alive = maxi(0, _necro_summons_alive - 1)
	_necro_summon_deaths += 1
	if _necro_summon_deaths >= 5 and not _necro_dragon_raised and not is_dead:
		_necro_dragon_raised = true
		if _necro_spawn(EnemyType.BONE_DRAGON):
			print("[%s] Five servants fallen — a BONE DRAGON rises!" % enemy_name)

## --- Bone Dragon ---

func _try_breath_swarm(target_node: Node3D) -> bool:
	## 12 damage down a 6-tile line; a Swarm hatches beside everyone it hits.
	if is_disarmed or is_silenced:
		return _try_move(target_node)
	if not grid_manager:
		return _try_elemental(target_node, attack_damage, "Breath")
	var my_cell = grid_manager.world_to_grid(position)
	var t_cell = grid_manager.world_to_grid(target_node.position)
	var dir = Vector2i(signi(t_cell.x - my_cell.x), signi(t_cell.y - my_cell.y))
	if dir == Vector2i.ZERO:
		dir = Vector2i(1, 0)
	var line: Array = []
	for i in range(1, 7):
		line.append(my_cell + dir * i)
	var main = get_parent()
	var hits := 0
	for u in _player_units():
		if not is_instance_valid(u):
			continue
		if grid_manager.world_to_grid(u.position) in line:
			hits += 1
			if u.has_method("get_stats"):
				_deal_damage_to_player(u, attack_damage, "Breath Swarm")
			elif u.has_method("take_damage"):
				u.take_damage(attack_damage)
			if main and "enemy_spawner" in main and main.enemy_spawner:
				main.enemy_spawner.spawn_enemy(EnemyType.SWARM, _free_cell_near(u.position, 1))
	print("[%s] Breath Swarm rakes the line — %d unit(s) hit!" % [enemy_name, hits])
	turn_completed.emit()
	return true

## --- Treant ---

func _treant_strip_thorns() -> void:
	## Every 10 tempo: rips all thorns off its enemies and heals for the total.
	var total := 0
	for u in _player_units():
		if not u.has_method("get_buff_manager"):
			continue
		var bm = u.get_buff_manager()
		if not bm:
			continue
		var thorns = bm.get_buff(Buff.BuffType.THORNS)
		if thorns and thorns.value > 0:
			total += int(thorns.value)
			bm.remove_buff(Buff.BuffType.THORNS)
	if total > 0:
		_regenerate(total)
		print("[%s] Tears the thorns away and drinks them in — heals %d!" % [enemy_name, total])

## --- Ice Troll ---

func _try_ice_club(target_node: Node3D) -> bool:
	if is_disarmed or not _in_attack_range(target_node):
		return _try_move(target_node)
	_ice_troll_strike(target_node, attack_damage, "Club")
	turn_completed.emit()
	return true

func _ice_troll_strike(target_node: Node3D, dmg: int, label: String) -> void:
	## Every Ice Troll attack adds a stack of frost (Cold) and Brittle. If the
	## blow FREEZES the target (Cold reaching 5), Clobber (50) auto-triggers.
	_deal_damage_to_player(target_node, dmg, label)
	var dm = target_node.get_debuff_manager() if target_node.has_method("get_debuff_manager") else null
	if not dm:
		return
	var was_frozen: bool = dm.has_debuff(Debuff.DebuffType.FROZEN)
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.COLD, 1, 15))
	dm.apply_debuff(Debuff.create(Debuff.DebuffType.BRITTLE, 1, 15))
	if label != "Clobber" and not was_frozen and dm.has_debuff(Debuff.DebuffType.FROZEN):
		print("[%s] The freeze leaves them wide open — CLOBBER!" % enemy_name)
		_ice_troll_strike(target_node, maxi(1, roundi(50 * _pps_dmg)), "Clobber")

## --- White Manticore ---

func _try_stinger(target_node: Node3D) -> bool:
	if is_disarmed or not _in_attack_range(target_node):
		return _try_move(target_node)
	_deal_damage_to_player(target_node, maxi(1, roundi(25 * _pps_dmg)), "Stinger")
	var dm = target_node.get_debuff_manager() if target_node.has_method("get_debuff_manager") else null
	if dm:
		# Clumsy for 3 cycles (sheet) = 15 tempo on the clock: no card burns
		# it, it simply runs out. Poison: 8 stacks.
		dm.apply_debuff(Debuff.create_timed(Debuff.DebuffType.CLUMSY, 15, enemy_name))
		dm.apply_debuff(Debuff.create(Debuff.DebuffType.POISON, 8, 15))
	_stinger_cooldown = 5
	turn_completed.emit()
	return true

## --- Wyvern ---

func _try_talon_grab(target_node: Node3D) -> bool:
	## Flies above its target (reaches 3 tiles), grabs, deals 25 and drags them
	## to an unoccupied space 8 squares away.
	if is_disarmed:
		return _try_move(target_node)
	if _get_cell_distance(target_node) > 3:
		return _try_move(target_node)
	_deal_damage_to_player(target_node, maxi(1, roundi(25 * _pps_dmg)), "Talon Grab")
	if grid_manager and is_instance_valid(target_node):
		var dest := _random_free_cell_at_distance(grid_manager.world_to_grid(target_node.position), 8)
		var world = grid_manager.grid_to_world(dest)
		if dungeon_manager:
			world.y = dungeon_manager.get_elevation_world_y(dest)
		target_node.target_position = world
		if "is_moving" in target_node:
			target_node.is_moving = true
		print("[%s] Talons close — drags its prey %d squares away!" % [enemy_name, 8])
	_talon_cooldown = 10  # 8-tempo action + 2-cycle cooldown
	turn_completed.emit()
	return true

## --- Ifrit ---

func _try_fire_breath(target_node: Node3D) -> bool:
	## A 5x5 sheet of flame in front of the ifrit: 20 damage + 5 burn to
	## anything inside, and the tiles keep burning for 3 tempo.
	if is_disarmed or is_silenced:
		return _try_move(target_node)
	if not grid_manager:
		return _try_elemental(target_node, maxi(1, roundi(20 * _pps_dmg)), "Fire Breath", {"burn": 5})
	var my_cell: Vector2i = grid_manager.world_to_grid(position)
	var t_cell: Vector2i = grid_manager.world_to_grid(target_node.position)
	var diff: Vector2i = t_cell - my_cell
	# Breathe down the dominant axis so the 5x5 stays a clean square.
	var forward := Vector2i(signi(diff.x), 0) if absi(diff.x) >= absi(diff.y) else Vector2i(0, signi(diff.y))
	if forward == Vector2i.ZERO:
		forward = Vector2i(1, 0)
	var side := Vector2i(-forward.y, forward.x)
	var tiles: Array = []
	for f in range(1, 6):
		for l in range(-2, 3):
			tiles.append(my_cell + forward * f + side * l)
	var breath_dmg: int = maxi(1, roundi(20 * _pps_dmg))
	for u in _player_units():
		if not is_instance_valid(u):
			continue
		if grid_manager.world_to_grid(u.position) in tiles:
			if u.has_method("get_stats"):
				_deal_damage_to_player(u, breath_dmg, "Fire Breath", DamageTypes.Type.FIRE)
				_apply_burn_to_player(u, 5)
			elif u.has_method("take_damage"):
				u.take_damage(breath_dmg)
	var main = get_parent()
	if main and main.has_method("register_fire_wall"):
		main.register_fire_wall(tiles, breath_dmg, 5, 99, 3)  # lingers 3 tempo
	print("[%s] FIRE BREATH — a 5x5 sheet of flame!" % enemy_name)
	turn_completed.emit()
	return true

## --- Inflamed Minotaur ---

func _minotaur_labyrinth_leap() -> void:
	## Labyrinth Leap: springs away 14 spaces to a random unoccupied tile —
	## minus 1 space per Slow stack. MINOTAUR-SPECIFIC: slow is his weakness
	## (Sword of Theseus ramps it); this is not a universal slow rule.
	## Bull Rush follows a random 5 to 15 tempo after landing — the player
	## never knows quite when he is coming back.
	var spaces: int = maxi(0, 14 - slow_stacks)
	_minotaur_leap_spaces = spaces
	_minotaur_rush_pending = true
	_minotaur_damage_taken = 0  # the count toward the next leap starts over
	if spaces > 0 and grid_manager:
		var dest := _random_free_cell_at_distance(grid_manager.world_to_grid(position), spaces)
		var world = grid_manager.grid_to_world(dest)
		if dungeon_manager:
			world.y = dungeon_manager.get_elevation_world_y(dest)
		position = world
		target_position = world
		is_moving = false
		_move_path.clear()
		# A leap is not a walk: the wake picks up again from where he lands.
		_wake_prev_cell = dest
	var delay: int = randi_range(5, 15)
	chosen_action = {"name": "bull_rush", "tempo_cost": delay}
	action_tempo_counter = 0
	print("[%s] LABYRINTH LEAP — springs %d spaces away! (slowed by %d) Bull Rush in %d tempo" % [enemy_name, spaces, slow_stacks, delay])

func _try_bull_rush(target_node: Node3D) -> bool:
	## Charges the player: damage scales with the spaces covered by the leap
	## and the rush combined; stun + weaken chance = spaces x 4% (both are
	## reserved for the final target). Every player-side unit brushed en
	## route is left Vulnerable.
	_minotaur_rush_pending = false
	var victim: Node3D = target_node
	# The minotaur always prioritizes a PLAYER over summons.
	var main = get_parent()
	if main and "enemy_spawner" in main and main.enemy_spawner:
		var ps: Array = main.enemy_spawner._living_players()
		if ps.is_empty() and main.enemy_spawner.player and is_instance_valid(main.enemy_spawner.player):
			ps = [main.enemy_spawner.player]
		var best_d := INF
		for p in ps:
			var d: float = position.distance_to(p.position)
			if d < best_d:
				best_d = d
				victim = p
	if not is_instance_valid(victim):
		turn_completed.emit()
		return true
	var rush_spaces := 0
	if grid_manager:
		# The real way through the maze (greedy steps dead-end at its walls).
		var path := _build_route_path(position, grid_manager.world_to_grid(victim.position), 24)
		if path.is_empty():
			path = _build_greedy_path(position, grid_manager.world_to_grid(victim.position), 24)
		rush_spaces = path.size()
		# Units brushed along the charge are trampled Vulnerable.
		for u in _player_units():
			if u == victim or not is_instance_valid(u) or not u.has_method("get_debuff_manager"):
				continue
			for wp in path:
				if Vector3(u.position.x - wp.x, 0, u.position.z - wp.z).length() <= 1.2:
					var udm = u.get_debuff_manager()
					if udm:
						udm.apply_debuff(Debuff.create(Debuff.DebuffType.VULNERABLE, 1, 15))
					break
		if not path.is_empty():
			var land: Vector3 = path[path.size() - 1]
			# The charge burns its whole lane: fire in the wake of every tile
			# crossed (the one he stands on at the end excepted), same trap as
			# his walking trail.
			var lane: Array = [grid_manager.world_to_grid(position)]
			for wp in path:
				var wc := grid_manager.world_to_grid(wp)
				if wc != lane[lane.size() - 1]:
					lane.append(wc)
			var land_cell := grid_manager.world_to_grid(land)
			lane.erase(land_cell)
			if not lane.is_empty() and main and main.has_method("register_fire_wall"):
				main.register_fire_wall(lane, 10, 2, 99, 15, self, 10)
			position = land
			target_position = land
			is_moving = false
			_move_path.clear()
			_wake_prev_cell = land_cell
	var total: int = _minotaur_leap_spaces + rush_spaces
	_minotaur_leap_spaces = 0
	var dmg: int = maxi(1, roundi(total * _pps_dmg))
	_deal_damage_to_player(victim, dmg, "Bull Rush")
	var dm = victim.get_debuff_manager() if victim.has_method("get_debuff_manager") else null
	if dm:
		dm.apply_debuff(Debuff.create(Debuff.DebuffType.VULNERABLE, 1, 15))
		var chance: int = clampi(total * 4, 0, 100)
		if randi() % 100 < chance:
			dm.apply_debuff(Debuff.create(Debuff.DebuffType.STUN, 0, 5))
			dm.apply_debuff(Debuff.create(Debuff.DebuffType.WEAKENED, 1, -1))
			print("[%s] Bull Rush connects square — STUNNED and WEAKENED!" % enemy_name)
	print("[%s] BULL RUSH — %d spaces of momentum, %d damage!" % [enemy_name, total, dmg])
	turn_completed.emit()
	return true

## --- Djinn ---

func _try_chain_lightning(target_node: Node3D) -> bool:
	## 35 lightning to each unit hit: initial cast reaches 5 squares, every
	## bound arcs up to 4 squares from the last unit struck.
	if is_disarmed or is_silenced:
		return _try_move(target_node)
	if _get_cell_distance(target_node) > 5:
		return _try_move(target_node)
	var hit: Array = [target_node]
	_djinn_zap(target_node)
	var current: Node3D = target_node
	while true:
		var next: Node3D = null
		var best := INF
		for u in _player_units():
			if u in hit or not is_instance_valid(u):
				continue
			var d: float = float(_cells_between(current, u))
			if d <= 4.0 and d < best:
				best = d
				next = u
		if next == null:
			break
		hit.append(next)
		_djinn_zap(next)
		current = next
	print("[%s] Chain lightning arcs through %d unit(s)!" % [enemy_name, hit.size()])
	turn_completed.emit()
	return true

func _djinn_zap(u: Node3D) -> void:
	if u.has_method("get_stats"):
		_deal_damage_to_player(u, attack_damage, "Chain Lightning", DamageTypes.Type.LIGHTNING)
	elif u.has_method("take_damage"):
		u.take_damage(attack_damage)

#endregion
#region MOUNTAINS SECOND PASS (the enemy sheet: Weregoat, Roc, Sabertooth, Snow Wraith)
# ============================================
# MOUNTAINS SECOND PASS — docs/ENEMY_SHEET.tsv
# ============================================

## Hits a player-side unit (player or summon) the same way _djinn_zap does.
func _hit_unit(u: Node3D, dmg: int, label: String, dmg_type: int = -1) -> void:
	if not is_instance_valid(u):
		return
	if u.has_method("get_stats"):
		_deal_damage_to_player(u, dmg, label, dmg_type)
	elif u.has_method("take_damage"):
		u.take_damage(dmg)

## Put the enemy down on a square at once (a leap or a dive, not a walk). Any
## glide still queued from an earlier move is dropped, or the physics step
## would slide it back along the old path from the new spot.
func _land_at(world_pos: Vector3) -> void:
	if grid_manager:
		var cell := grid_manager.world_to_grid(world_pos)
		world_pos = grid_manager.grid_to_world(cell)
		if dungeon_manager:
			world_pos.y = dungeon_manager.get_elevation_world_y(cell)
	position = world_pos
	target_position = world_pos
	is_moving = false
	_move_path.clear()

## Whether a square can be stood on at all: the floor of the dungeon (or the
## grid, outdoors), with nothing built, parked or raised on it.
func _can_stand_on(cell: Vector2i) -> bool:
	if not _cell_is_free(cell) or cell in pillar_tiles:
		return false
	if dungeon_manager != null:
		return dungeon_manager.is_floor(cell)
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_manager.grid_width and cell.y < grid_manager.grid_height

## The player-side units standing within `radius` squares of `cell`.
func _units_within(units: Array, cell: Vector2i, radius: int) -> Array:
	var out: Array = []
	for u in units:
		if is_instance_valid(u) and _manhattan_dist(grid_manager.world_to_grid(u.position), cell) <= radius:
			out.append(u)
	return out

# --- Weregoat ---

const GOAT_CHARGE_SQUARES := 8    # sheet: "Charge up to 8 squares"
const GOAT_CHARGE_DAMAGE := 8     # sheet: 8 damage to all targets in his path
# TODO(sheet): the sheet gives no length for the landing stun — 3 tempo, the
# same stun the Giant Beaver's Chomp deals.
const GOAT_CHARGE_STUN_TEMPO := 3

func _choose_weregoat_action(distance: int) -> void:
	if distance <= 1:
		chosen_action = _get_action("hoof_punch")
	elif distance <= GOAT_CHARGE_SQUARES:
		chosen_action = _get_action("goat_charge")
	else:
		chosen_action = _get_action("move")

## Charge (sheet): run up to 8 squares along the straight line that crosses
## the most of the player's units (any of the 8 directions); 8 damage to
## everything in the path. The goat pulls up on the first free square past
## the last unit it ran through, so the landing stun (everything within 1
## square) catches them. With nobody on any line it charges the route to its
## target instead and lands beside it — stun only, nothing was in the path.
func _try_goat_charge(target_node: Node3D) -> bool:
	if is_disarmed or rooted_tempo > 0:
		return _try_move(target_node)
	if not grid_manager:
		return _try_elemental(target_node, GOAT_CHARGE_DAMAGE, "Charge")
	var my_cell := grid_manager.world_to_grid(position)
	var units: Array = []
	var unit_at := {}   # cell -> the player-side unit standing on it
	for u in _player_units():
		if is_instance_valid(u):
			units.append(u)
			unit_at[grid_manager.world_to_grid(u.position)] = u
	var best := {}
	var best_score := -1
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var lane := _goat_charge_lane(my_cell, d, unit_at)
		if lane.is_empty():
			continue
		# Most units in the path first; among equal lanes the landing that
		# stuns the most, then the one that catches the goat's own target.
		var lane_hits: Array = lane["hits"]
		var score: int = lane_hits.size() * 100 + _units_within(units, lane["land"], 1).size() * 10
		if target_node in lane_hits:
			score += 1
		if score > best_score:
			best_score = score
			best = lane
	var hits: Array = best.get("hits", [])
	var land_cell: Vector2i = best.get("land", my_cell)
	if hits.is_empty() and best_score <= 0:
		# No line reaches anyone: charge the route to the target and pull up
		# beside it (or just walk if even that is out of reach).
		var path := _build_route_path(position, grid_manager.world_to_grid(target_node.position), GOAT_CHARGE_SQUARES)
		if path.is_empty():
			return _try_move(target_node)
		land_cell = grid_manager.world_to_grid(path[path.size() - 1])
	# The blows land from where the run starts: the lane is clear of walls by
	# construction, so nothing is hit through one.
	for u in hits:
		_hit_unit(u, GOAT_CHARGE_DAMAGE, "Charge")
	_land_at(grid_manager.grid_to_world(land_cell))
	var stunned := 0
	for u in _units_within(units, land_cell, 1):
		_apply_player_debuff(u, Debuff.create(Debuff.DebuffType.STUN, 0, GOAT_CHARGE_STUN_TEMPO))
		stunned += 1
	print("[%s] CHARGE — %d unit(s) trampled, %d stunned where it lands" % [enemy_name, hits.size(), stunned])
	turn_completed.emit()
	return true

## One straight charge lane from `from` along `dir`, up to 8 squares. It stops
## short of walls, other enemies, pillars and the edge of the floor (and never
## cuts a wall corner on a diagonal); player-side units are run through, not
## around. Returns {"hits": [units in the path], "land": the square the goat
## pulls up on}, or {} when it could not take a single step that way. A unit
## with a wall right behind it is still hit — the goat slams into it and pulls
## up on the square before.
func _goat_charge_lane(from: Vector2i, dir: Vector2i, unit_at: Dictionary) -> Dictionary:
	var hits: Array = []
	var land := from
	var landed := false
	var pulled_up := false   # the landing past the latest victim is already set
	for i in range(1, GOAT_CHARGE_SQUARES + 1):
		var c: Vector2i = from + dir * i
		if unit_at.has(c):
			hits.append(unit_at[c])
			pulled_up = false
			continue
		if not _can_stand_on(c):
			break
		if dungeon_manager != null and not dungeon_manager.has_line_of_sight(from, c):
			break
		if hits.is_empty() or not pulled_up:
			land = c
			landed = true
			pulled_up = true
	if not landed:
		return {}
	return {"hits": hits, "land": land}

# --- Roc ---

const ROC_DIVE_SQUARES := 6       # sheet: "attack from up to 6 paces away"
# TODO(sheet): "move away until dive bomb is once again active" — the sheet
# gives no length for that wait; one cycle (5 tempo), the dive's own tempo.
const ROC_DIVE_COOLDOWN := 5
const ROC_SCRAPE_AFTER := 3       # sheet: "in melee range for more than 3 tempo"

var _dive_cooldown: int = 0        # Roc: raw tempo until Dive Bomb is ready again
var _roc_melee_tempo: int = 0      # Roc: consecutive tempo a player unit has stood in melee reach

## Dive when it is ready and the target is in reach; every other tempo the
## Roc backs off (it has no "move": the retreat IS its movement, so the Sync
## clock is never left without a choice).
func _choose_roc_action(distance: int) -> void:
	if distance <= ROC_DIVE_SQUARES and _dive_cooldown <= 0 and not is_disarmed:
		chosen_action = _get_action("dive_bomb")
	else:
		chosen_action = _get_action("roc_retreat")

## Dive Bomb (sheet): attack from up to 6 squares; the Roc ends beside the
## player. Disarmed, out of reach, or with no free square beside the target it
## backs off instead; Rooted it cannot fly at all.
## TODO(sheet): the sheet gives no damage — first-pass attack_damage (8).
func _try_dive_bomb(target_node: Node3D) -> bool:
	if is_disarmed or not is_instance_valid(target_node) or _cells_between(self, target_node) > ROC_DIVE_SQUARES:
		return _try_roc_retreat(target_node)
	if _cells_between(self, target_node) > 1:
		if rooted_tempo > 0:
			return false
		var perch := _free_cell_near(target_node.position, 1)
		if grid_manager and grid_manager.world_to_grid(perch) == grid_manager.world_to_grid(target_node.position):
			return _try_roc_retreat(target_node)  # nowhere to land beside them
		_land_at(perch)
	_deal_damage_to_player(target_node, attack_damage, "Dive Bomb")
	_dive_cooldown = ROC_DIVE_COOLDOWN
	turn_completed.emit()
	return true

## Eye Scrape (sheet, Async 3): only lands if a player unit has been in melee
## reach for more than 3 tempo — 2 Weakened on whoever is crowding it (the
## target if it is the one in reach, else any unit beside it). _roc_melee_tempo
## is ticked in on_tempo_advanced.
func _try_eye_scrape(target_node: Node3D) -> bool:
	if is_disarmed or _roc_melee_tempo <= ROC_SCRAPE_AFTER:
		return false
	var victim: Node3D = null
	if is_instance_valid(target_node) and _in_attack_range(target_node):
		victim = target_node
	else:
		for u in _player_units():
			if is_instance_valid(u) and _cells_between(self, u) <= 1:
				victim = u
				break
	if victim == null:
		return false
	_apply_player_debuff(victim, Debuff.create(Debuff.DebuffType.WEAKENED, 2, -1))
	print("[%s] Eye Scrape! 2 Weakened" % enemy_name)
	turn_completed.emit()
	return true

## The Roc always moves AWAY from the player. Only a Root pins it; cornered
## (no square is further off — every step changes the distance by one, so
## there is no sidestep that keeps it) it holds where it is, and a player who
## crowds it there meets Eye Scrape. Returns false when it could not move,
## which the Sync clock treats as a spent 1-tempo action: it tries again next
## tempo rather than idling on a stale choice.
func _try_roc_retreat(target_node: Node3D) -> bool:
	if rooted_tempo > 0 or not is_instance_valid(target_node):
		return false
	var tiles := maxi(1, int(move_distance))
	if not grid_manager:
		_dash_away_from(target_node.position, tiles)
		return true
	var threat := grid_manager.world_to_grid(target_node.position)
	return _start_path(_build_greedy_path(position, threat, tiles, true))

# --- Sabertooth Tiger ---

var _track_target: Node3D = null   # Sabertooth: the unit Track marked (it must hunt this one)
const SABERTOOTH_CRIT_CHANCE := 0.35

func _choose_sabertooth_action(distance: int) -> void:
	# Hunting its Track quarry: measure to it, not to the spawner's target
	# (unless a Taunt is pulling it elsewhere — see _move_target_for).
	var quarry := _track_quarry()
	if quarry != null and not (taunt_target and is_instance_valid(taunt_target)):
		distance = _get_cell_distance(quarry)
	if distance <= 1:
		chosen_action = _get_action("bite_and_claw")
	else:
		chosen_action = _get_action("move")

## The unit Track marked, while it still stands. The lock clears the moment
## that unit dies, is freed or becomes untargetable, and the tiger goes back
## to whoever the spawner points it at.
func _track_quarry() -> Node3D:
	if _track_target == null:
		return null
	if not is_instance_valid(_track_target) or _track_target.get("is_dead") == true \
			or _track_target.get("untargetable") == true or _unit_health(_track_target) <= 0:
		_track_target = null
		return null
	return _track_target

## Track (sheet, Async 10): +15 Strengthen against the nearest unit, which the
## tiger must then attack — _track_quarry() steers its moves and strikes from
## here on (see _move_target_for).
func _try_track(target_node: Node3D) -> bool:
	var nearest: Node3D = null
	var best := 999
	for u in _player_units():
		var d := _cells_between(self, u)
		if d < best:
			best = d
			nearest = u
	if nearest == null and is_instance_valid(target_node):
		nearest = target_node  # nothing else in sight: the one it was given
	if nearest == null:
		return false
	_track_target = nearest
	strengthen_stacks += 15
	print("[%s] Track: +15 Strengthen against %s" % [enemy_name, nearest.name])
	_update_status_indicators()
	return true

## A sabertooth strike: 35% crit for 1.5x and 6 Bleed; spends the Track
## Strengthen on the first blow that lands.
func _sabertooth_strike(target_node: Node3D, dmg: int, label: String) -> void:
	var total := dmg + strengthen_stacks
	strengthen_stacks = 0
	if randf() < SABERTOOTH_CRIT_CHANCE:
		total = ceili(total * 1.5)
		print("[%s] %s CRITS!" % [enemy_name, label])
		_deal_damage_to_player(target_node, total, label)
		_apply_player_debuff(target_node, Debuff.create(Debuff.DebuffType.BLEED, 6, 15))
	else:
		_deal_damage_to_player(target_node, total, label)
	_update_status_indicators()

## Bite and Claw (sheet, 5): bite 6 then claw 3 — two separate attacks, each
## with its own crit roll and its own Strengthen.
func _try_bite_and_claw(target_node: Node3D) -> bool:
	if is_disarmed or not _in_attack_range(target_node):
		return _try_move(target_node)
	_sabertooth_strike(target_node, 6, "Bite")
	if is_instance_valid(target_node):
		_sabertooth_strike(target_node, 3, "Claw")
	turn_completed.emit()
	return true

## Sunken Bite (sheet, Async 15): 10 damage + 8 Bleed.
func _try_sunken_bite(target_node: Node3D) -> bool:
	if is_disarmed or not _in_attack_range(target_node):
		return false
	_sabertooth_strike(target_node, 10, "Sunken Bite")
	_apply_player_debuff(target_node, Debuff.create(Debuff.DebuffType.BLEED, 8, 15))
	turn_completed.emit()
	return true

# --- Snow Wraith ---

func _choose_snow_wraith_action(distance: int) -> void:
	if is_silenced or distance > int(attack_range):
		chosen_action = _get_action("move")
		return
	# Snowball first (it is the slow + frost opener); Ice Blast once they are slowed.
	var slowed := false
	if _last_seen_target and _last_seen_target.has_method("get_debuff_manager"):
		var dm = _last_seen_target.get_debuff_manager()
		slowed = dm != null and dm.is_slowed()
	chosen_action = _get_action("ice_blast") if slowed else _get_action("snowball")

## Snowball (sheet, 8): no damage; Slowed for 3 tempo + 2 Cold.
func _try_snowball(target_node: Node3D) -> bool:
	if is_silenced or not _in_attack_range(target_node):
		return _try_move(target_node)
	_apply_player_debuff(target_node, Debuff.create_timed(Debuff.DebuffType.SLOWED, 3, enemy_name))
	_apply_player_debuff(target_node, Debuff.create(Debuff.DebuffType.COLD, 2, 15))
	print("[%s] Snowball: Slowed 3 tempo + 2 Cold" % enemy_name)
	turn_completed.emit()
	return true

## Ice Blast (sheet): 5 ice damage, +3 if the target has armor; Slowed 3 tempo.
func _try_ice_blast(target_node: Node3D) -> bool:
	if is_silenced or not _in_attack_range(target_node):
		return _try_move(target_node)
	var dmg := attack_damage
	if target_node.has_method("get_stats"):
		var st = target_node.get_stats()
		if st and st.has_method("get_total_armor") and st.get_total_armor() > 0:
			dmg += 3
	_deal_damage_to_player(target_node, dmg, "Ice Blast", DamageTypes.Type.ICE)
	_apply_player_debuff(target_node, Debuff.create_timed(Debuff.DebuffType.SLOWED, 3, enemy_name))
	turn_completed.emit()
	return true

#endregion
#region UNDERWORLD & HEAVENS SECOND PASS (Demon, Ash Harpy, Magma Spider, Mind Eater, Specter, Succubus, Cherub)
# ============================================
# UNDERWORLD & HEAVENS SECOND PASS — docs/ENEMY_SHEET.tsv
# ============================================

# --- Demon ---

func _choose_demon_action(distance: int) -> void:
	if distance <= 1:
		chosen_action = _get_action("demon_attack")
	else:
		chosen_action = _get_action("move")

## Mimic (sheet, Async 8): a 1-HP duplicate that looks identical (health shown,
## buffs and debuffs copied) and hits as hard; at most 2 per demon.
## TODO(sheet): not yet built — see the implementation brief.
func _try_mimic(_target_node: Node3D) -> bool:
	return false

## Cuff (sheet, Async 8): the target cannot draw for 15 tempo.
func _try_demon_cuff(target_node: Node3D) -> bool:
	if is_silenced or not _in_attack_range(target_node):
		return false
	_apply_player_debuff(target_node, Debuff.create(Debuff.DebuffType.CUFFED, 0, 15))
	print("[%s] Cuff: no draws for 15 tempo" % enemy_name)
	turn_completed.emit()
	return true

# --- Ash Harpy ---

var _harpy_steal_used: bool = false   # Ash Harpy: Card Steal fires once per harpy

func _choose_harpy_action(distance: int) -> void:
	if not _harpy_steal_used and distance <= 4:
		chosen_action = _get_action("card_steal")
	elif distance <= 1:
		chosen_action = _get_action("peck")
	else:
		chosen_action = _get_action("move")

## Card Steal (sheet, 8): spots a card from 4 squares, flies into melee and
## takes a card from the hand; the card returns when the harpy dies.
## TODO(sheet): the steal / return is not yet built — flies in only.
func _try_card_steal(target_node: Node3D) -> bool:
	if _cells_between(self, target_node) > 1:
		return _try_move(target_node)
	return false

# --- Magma Spider ---

func _choose_magma_spider_action(_distance: int) -> void:
	chosen_action = _get_action("fire_web")

## Fire Web (sheet): a web of fire on the ground around the spider — inside it
## the player is Slowed and takes 1 damage every 3 tempo.
## TODO(sheet): the ground zone is not yet built.
func _try_fire_web(_target_node: Node3D) -> bool:
	return false

# --- Mind Eater ---

func _choose_mind_eater_action(distance: int) -> void:
	if is_silenced or distance > int(attack_range):
		chosen_action = {}
		return
	chosen_action = _get_action("mind_slow") if randf() < 0.6 else _get_action("mind_cuff")

## Mind Slow (sheet, 10): every card in the hand costs 20 more mana.
## TODO(sheet): hand-wide mana tax not yet built.
func _try_mind_slow(_target_node: Node3D) -> bool:
	return false

## Manipulate Mind Space (sheet, 8): Cuffed for 15 tempo.
func _try_mind_cuff(target_node: Node3D) -> bool:
	if is_silenced or not _in_attack_range(target_node):
		return false
	_apply_player_debuff(target_node, Debuff.create(Debuff.DebuffType.CUFFED, 0, 15))
	print("[%s] Manipulate Mind Space: no draws for 15 tempo" % enemy_name)
	turn_completed.emit()
	return true

# --- Specter ---

func _choose_specter_action(distance: int) -> void:
	_choose_ranged_action(distance, "spirit_spit")

## Spirit Spit (sheet, 5): 2 damage at range 2.
func _try_spirit_spit(target_node: Node3D) -> bool:
	if is_silenced:
		return _try_move(target_node)
	return _try_elemental(target_node, attack_damage, "Spirit Spit")

## Invisible (sheet, Async 8): fades out for 3 tempo — cannot be targeted.
## TODO(sheet): enemy untargetability not yet built.
func _try_specter_vanish() -> bool:
	return false

# --- Succubus ---

func _choose_succubus_action(distance: int) -> void:
	if is_silenced or distance > int(attack_range):
		chosen_action = _get_action("move")
		return
	chosen_action = _get_action("mana_drain") if randf() < 0.5 else _get_action("damaging_snap")

## Mana Drain (sheet, 10): drains 10 mana from the target's pool.
func _try_mana_drain(target_node: Node3D) -> bool:
	if is_silenced or not _in_attack_range(target_node):
		return _try_move(target_node)
	if target_node.has_method("get_stats"):
		var st = target_node.get_stats()
		if st:
			st.current_mana = maxf(0.0, st.current_mana - 10.0)
			st.mana_changed.emit(st.current_mana, st.max_mana)
			if st.current_mana <= 0.0 and st.maintained_mana > 0 and st.has_method("_break_maintained_cards"):
				st._break_maintained_cards()
			print("[%s] Mana Drain: -10 mana" % enemy_name)
	turn_completed.emit()
	return true

## Damaging Snap (sheet, 6): damage = missing mana / 20, + 4.
func _try_damaging_snap(target_node: Node3D) -> bool:
	if is_silenced or not _in_attack_range(target_node):
		return _try_move(target_node)
	var dmg := 4
	if target_node.has_method("get_stats"):
		var st = target_node.get_stats()
		if st:
			dmg += int(floor(maxf(0.0, st.max_mana - st.current_mana) / 20.0))
	_deal_damage_to_player(target_node, dmg, "Damaging Snap")
	turn_completed.emit()
	return true

# --- Cherub ---

var _cherub_first_arrow: bool = true   # Cherub: the first arrow flies the moment the player enters its reach

func _choose_cherub_action(distance: int) -> void:
	_choose_ranged_action(distance, "loves_arrow")

## Love's Arrow (sheet): 2 damage; for 5 tempo the Cherub cannot be attacked
## directly (poison, burn and area damage still land).
## TODO(sheet): the untargetable window and the instant first arrow are not yet built.
func _try_loves_arrow(target_node: Node3D) -> bool:
	if is_silenced:
		return _try_move(target_node)
	return _try_elemental(target_node, attack_damage, "Love's Arrow")

#endregion
#region BASIC ACTIONS

func _try_attack(target_node: Node3D) -> bool:
	if is_disarmed:
		print("[%s] Disarmed - cannot attack!" % enemy_name)
		return _try_move(target_node)
	# Switch Kick: disarmed for a number of ATTACKS, not a duration.
	if disarmed_attacks > 0:
		disarmed_attacks -= 1
		print("[%s] Disarmed for this attack! (%d left)" % [enemy_name, disarmed_attacks])
		return _try_move(target_node)
	if _in_attack_range(target_node):
		_deal_damage_to_player(target_node, attack_damage, "Attack")
		turn_completed.emit()
		return true
	return _try_move(target_node)

func _try_move(target_node: Node3D) -> bool:
	var diff = target_node.position - position
	var flat_dist = Vector3(diff.x, 0, diff.z).length()
	if flat_dist <= aggro_range:
		move_towards_target(target_node.position)
		return true
	return false  # Out of aggro range - idle

func _try_bite(target_node: Node3D) -> bool:
	if is_disarmed:
		return _try_move(target_node)
	if _in_attack_range(target_node):
		_deal_damage_to_player(target_node, attack_damage, "Bite")
		turn_completed.emit()
		return true
	return _try_move(target_node)

func _try_scurry(target_node: Node3D) -> bool:
	## Wererat dashes 5 tiles toward the target. (Slowed now taxes the move's
	## tempo in _check_and_fire_actions instead of trimming tiles.)
	var tiles = 5
	_dash_towards_target(target_node.position, tiles)
	print("[%s] Scurries %d tiles toward target!" % [enemy_name, tiles])
	return true

func _try_kick(target_node: Node3D) -> bool:
	if is_disarmed:
		return _try_move(target_node)
	if _in_attack_range(target_node):
		_deal_damage_to_player(target_node, maxi(1, roundi(6 * _pps_dmg)), "Kick")
		turn_completed.emit()
		return true
	return _try_move(target_node)

func _try_smash(target_node: Node3D) -> bool:
	if is_disarmed:
		return _try_move(target_node)
	if _in_attack_range(target_node):
		_deal_damage_to_player(target_node, maxi(1, roundi(14 * _pps_dmg)), "Smash")
		# Inject Lightly Dazed card into player's hand
		if target_node.has_method("get_deck_manager"):
			var dm = target_node.get_deck_manager()
			if dm:
				dm.add_card_to_hand(Card.create_lightly_dazed())
				print("[%s] Smash added Lightly Dazed to player's hand!" % enemy_name)
		turn_completed.emit()
		return true
	return _try_move(target_node)

func _try_shoot(target_node: Node3D) -> bool:
	## Archer Rat: Ranged attack at range 4.
	if is_disarmed:
		print("[%s] Disarmed - cannot shoot!" % enemy_name)
		return _try_get_into_range(target_node)
	if _in_attack_range(target_node):
		_deal_damage_to_player(target_node, attack_damage, "Arrow Shot")
		turn_completed.emit()
		return true
	# Out of range, try to get closer
	return _try_get_into_range(target_node)

func _try_scurry_away(target_node: Node3D) -> bool:
	## Archer Rat: Run 5 paces away from threat.
	var tiles = 5

	if grid_manager:
		var threat_cell = grid_manager.world_to_grid(target_node.position)
		_start_path(_build_greedy_path(position, threat_cell, tiles, true))
	else:
		var diff = position - target_node.position
		var direction = Vector3(diff.x, 0, diff.z).normalized()
		if direction.length() < 0.1:
			direction = Vector3(1, 0, 0)
		target_position = position + direction * (tiles * 1.0)
		is_moving = true

	print("[%s] Scurries %d tiles away from threat!" % [enemy_name, tiles])
	return true

func _try_get_into_range(target_node: Node3D) -> bool:
	## Archer Rat: Move 2 tiles toward target to get into shooting range.
	# A nest's archer walks up to its cliff top instead (3 tiles a step):
	# round the side of the cliff first, then onto the top.
	if perch_cell.x >= 0 and not _at_perch() and grid_manager:
		var here := grid_manager.world_to_grid(position)
		if perch_approach.x >= 0 and here == perch_approach:
			_perch_approach_done = true
		var leg := perch_cell if (_perch_approach_done or perch_approach.x < 0) else perch_approach
		if not _start_path(_build_greedy_path(position, leg, 3, false, true)):
			print("[%s] Cannot climb to its perch this tempo" % enemy_name)
		else:
			print("[%s] Climbs toward the high ground at %s (via %s)" % [enemy_name, perch_cell, leg])
		return true
	if _in_attack_range(target_node):
		# Already in range, shoot instead
		return _try_shoot(target_node)

	var tiles = 2

	if grid_manager:
		var player_cell = grid_manager.world_to_grid(target_node.position)
		_start_path(_build_greedy_path(position, player_cell, tiles))
	else:
		var diff = target_node.position - position
		var direction = Vector3(diff.x, 0, diff.z).normalized()
		target_position = position + direction * (tiles * 1.0)
		is_moving = true

	print("[%s] Moves %d tiles to get into range!" % [enemy_name, tiles])
	return true

## Deal damage to the player with attack flash.
func _deal_damage_to_player(player_node: Node3D, base_damage: int, attack_name: String, dmg_type: int = -1) -> void:
	# Can't hit the player through a wall — a structure between us blocks the blow.
	if dungeon_manager and grid_manager and is_instance_valid(player_node):
		var from_cell = grid_manager.world_to_grid(position)
		var to_cell = grid_manager.world_to_grid(player_node.position)
		if not dungeon_manager.has_line_of_sight(from_cell, to_cell):
			print("[%s] %s blocked by a wall!" % [enemy_name, attack_name])
			return
	# Default to this enemy's configured element when the caller doesn't override.
	if dmg_type < 0:
		dmg_type = damage_type
	# Face the target as we strike so attacks don't play backwards.
	if _enemy_figure and is_instance_valid(player_node):
		var face_diff = player_node.position - position
		_enemy_figure.set_facing_from_velocity(Vector3(face_diff.x, 0, face_diff.z))

	var effective_damage = max(0, base_damage - attack_reduction)
	# Weaken (Fan Save): -30% damage dealt (plus the player's Weaken Amp sphere
	# nodes), one stack consumed per attack.
	var weaken_percent: float = 30.0 + _player_sphere_amp("sphere_weaken_amp")
	if weaken_stacks > 0:
		effective_damage = floori(effective_damage * maxf(0.0, 1.0 - weaken_percent / 100.0))
		weaken_stacks -= 1
		print("[%s] Weakened! -%d%% damage (%d stacks left)" % [enemy_name, int(weaken_percent), weaken_stacks])
		_update_status_indicators()
	elif zone_weakened:
		# Territorial Mark: the same reduction, but persistent while inside the
		# zone — no stack to consume, it lifts the moment the enemy leaves.
		effective_damage = floori(effective_damage * maxf(0.0, 1.0 - weaken_percent / 100.0))
		print("[%s] Weakened by the Territorial Mark! -%d%% damage" % [enemy_name, int(weaken_percent)])
	# Cursed (player-applied): deals (20 + Curse Amp)% less damage, and takes
	# (20 + Curse Pain)% of the damage it deals back as self-damage.
	if cursed_tempo > 0:
		var curse_reduce: float = 20.0 + _player_sphere_amp("sphere_curse_amp")
		effective_damage = floori(effective_damage * maxf(0.0, 1.0 - curse_reduce / 100.0))
		print("[%s] Cursed! -%d%% damage dealt" % [enemy_name, int(curse_reduce)])
		var curse_pain: float = 20.0 + _player_sphere_amp("sphere_curse_pain_amp")
		var self_dmg: int = floori(effective_damage * curse_pain / 100.0)
		if self_dmg > 0 and not is_dead:
			take_damage(self_dmg, false)
			print("[%s] Cursed! Takes %d self-damage (%d%% of the blow)" % [enemy_name, self_dmg, int(curse_pain)])
	print("[%s] %s for %d damage! (base %d, reduction %d)" % [enemy_name, attack_name, effective_damage, base_damage, attack_reduction])

	# Summon targets (Frankensteins Monster, surfaced Bull Worms) have no player
	# stat pipeline — the hit goes straight through their own take_damage.
	if not player_node.has_method("get_stats") and player_node.has_method("take_damage"):
		if "last_attacker" in player_node:
			player_node.last_attacker = self  # a destroyed Specter answers its killer
		if effective_damage > 0:
			player_node.take_damage(effective_damage)
		return

	if player_node.has_method("get_stats"):
		var player_stats_ref = player_node.get_stats()
		# Remember who is striking so counters (Return Cut) know their target.
		if player_stats_ref and "last_attacker" in player_stats_ref:
			player_stats_ref.last_attacker = self
		if player_stats_ref and effective_damage > 0:
			# The blow is coming: reactions that shield against it (Magic
			# Barrier) raise their armor now, before the damage math.
			attacking_player.emit(self, player_node)
			var debuff_mgr = null
			var buff_mgr = null
			if player_node.has_method("get_debuff_manager"):
				debuff_mgr = player_node.get_debuff_manager()
			if player_node.has_method("get_buff_manager"):
				buff_mgr = player_node.get_buff_manager()

			# Repelled Block: "the enemy's NEXT MELEE attack": ranged hits pass
			# under it; a melee hit spends it whether or not armor held, and a
			# fully blocked one is negated and pushes both apart.
			var rb_melee: bool = Vector2(player_node.position.x - position.x, player_node.position.z - position.z).length() <= 1.6
			if buff_mgr and buff_mgr.has_buff(Buff.BuffType.REPELLED_BLOCK) and rb_melee \
					and player_stats_ref.get_total_armor() < effective_damage:
				var rb_spent = buff_mgr.get_buff(Buff.BuffType.REPELLED_BLOCK)
				rb_spent.use_charge()
				if rb_spent.is_expired():
					buff_mgr.remove_buff(Buff.BuffType.REPELLED_BLOCK)
				print("[%s] Repelled Block: the blow got through — the stance is spent" % enemy_name)
			if buff_mgr and buff_mgr.has_buff(Buff.BuffType.REPELLED_BLOCK) and rb_melee:
				if player_stats_ref.get_total_armor() >= effective_damage:
					# Fully blocked - consume the buff, negate damage, push enemy back 4 and player back 2
					var rb = buff_mgr.get_buff(Buff.BuffType.REPELLED_BLOCK)
					rb.use_charge()
					if rb.is_expired():
						buff_mgr.remove_buff(Buff.BuffType.REPELLED_BLOCK)
					# Push enemy away from player
					knockback(player_node.position, 4)
					# Push player away from enemy
					if player_node.has_method("blink_to") and grid_manager:
						var player_diff = player_node.position - position
						var player_dir = Vector3(player_diff.x, 0, player_diff.z).normalized()
						var player_new_pos = player_node.position + player_dir * 2.0
						player_new_pos = grid_manager.snap_to_grid(player_new_pos)
						player_node.position = player_new_pos
						player_node.target_position = player_new_pos
					print("[%s] Repelled Block triggered! Enemy pushed back 4, player pushed back 2" % enemy_name)
					return  # Skip damage entirely

			# Defensive Sacrifice (Abjurers Cane): main may intercept the blow
			# to offer the discard choice. When it does, it owns this hit —
			# it applies the (possibly halved) damage and calls
			# _finish_player_hit itself once the player has chosen.
			var ds_main = get_tree().current_scene
			if ds_main and ds_main.has_method("offer_defensive_sacrifice") \
					and ds_main.offer_defensive_sacrifice(self, player_node, effective_damage, debuff_mgr, buff_mgr, dmg_type):
				return

			player_stats_ref.take_damage(effective_damage, debuff_mgr, buff_mgr, dmg_type)
			_finish_player_hit(player_node)

	# Attack flash on figure, sprite, or mesh
	if _enemy_figure:
		_enemy_figure.flash(Color(1.0, 0.7, 0.3))
	elif _enemy_sprite and _enemy_animator and _enemy_animator.sprite_sheet_loaded:
		var tween = create_tween()
		tween.tween_property(_enemy_sprite, "modulate", Color(1.0, 0.7, 0.3), 0.1)
		tween.tween_property(_enemy_sprite, "modulate", Color.WHITE, 0.1)
	elif mesh:
		var tween = create_tween()
		var mat = mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			var orig_color = mat.albedo_color
			tween.tween_property(mat, "albedo_color", Color.ORANGE, 0.1)
			tween.tween_property(mat, "albedo_color", orig_color, 0.1)

## The riders that follow a landed hit on the player — split out so the
## Defensive Sacrifice mediation in main can finish a deferred hit the
## same way the direct path does.
func _finish_player_hit(player_node: Node3D) -> void:
	if player_node.has_method("get_inventory"):
		var p_inventory = player_node.get_inventory()
		if p_inventory:
			p_inventory.on_damage_taken()
	# Trigger on_attacked passives (thorns, In the Trenches, etc.)
	if player_node.has_method("on_attacked_by"):
		player_node.on_attacked_by(self)
	attacked_player.emit(self, player_node)

## A barricade wall in the way: when no step toward the target is possible,
## swing at an adjacent blocked tile that lies toward it. Main decides whether
## that tile is a breakable barricade (two hits fell one) or true terrain.
func _try_smash_barricade(goal_cell: Vector2i) -> void:
	if not grid_manager or is_dead:
		return
	var cur := grid_manager.world_to_grid(position)
	var cur_dist := _manhattan_dist(cur, goal_cell)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var candidate: Vector2i = cur + d
		if candidate in blocked_tiles and _manhattan_dist(candidate, goal_cell) < cur_dist:
			barricade_attacked.emit(self, candidate)
			return

## Dash multiple tiles toward a position in one action.
## Stops at any barricade tile encountered along the path.
func _dash_towards_target(pos: Vector3, tiles: int) -> void:
	if is_channeling():
		print("[%s] Channeling - cannot dash!" % enemy_name)
		return
	# Rooted (Gravity Gauntlets): held in place — attacks/casts fine, no movement.
	if rooted_tempo > 0:
		print("[%s] Rooted - cannot dash!" % enemy_name)
		return
	# Enemies trapped on a rise pillar cannot dash
	if grid_manager:
		var current_cell = grid_manager.world_to_grid(position)
		if current_cell in pillar_tiles:
			print("[%s] Trapped on pillar - cannot dash!" % enemy_name)
			return

	if grid_manager:
		var player_cell = grid_manager.world_to_grid(pos)
		if not _start_path(_build_greedy_path(position, player_cell, tiles)):
			_try_smash_barricade(player_cell)
			return  # Can't move at all
	else:
		var diff = pos - position
		var direction = Vector3(diff.x, 0, diff.z).normalized()
		target_position = position + direction * (tiles * 1.0)
		is_moving = true

## Armored Troll passive: heal HP with green flash.
func _regenerate(amount: int) -> void:
	if is_dead:
		return
	# Narashimha (Mane of Narashimha): the wound from Neither Man nor Beast will
	# not close — healing works normally but can never restore health above the
	# cap recorded when the hit landed, so THAT damage stays lost until expiry.
	var heal_ceiling = max_health
	if narashimha_tempo > 0 and narashimha_heal_cap >= 0:
		heal_ceiling = min(heal_ceiling, narashimha_heal_cap)
	var healed = min(amount, heal_ceiling - current_health)
	if healed <= 0:
		return
	current_health += healed
	update_health_display()
	print("[%s] Regenerates %d health! (%d/%d)" % [enemy_name, healed, current_health, max_health])
	# Heal flash on figure, sprite, or mesh
	if _enemy_figure:
		_enemy_figure.flash(Color(0.5, 1.0, 0.5))
	elif _enemy_sprite and _enemy_animator and _enemy_animator.sprite_sheet_loaded:
		var tween = create_tween()
		tween.tween_property(_enemy_sprite, "modulate", Color(0.5, 1.0, 0.5), 0.15)
		tween.tween_property(_enemy_sprite, "modulate", Color.WHITE, 0.15)
	elif mesh:
		var tween = create_tween()
		var mat = mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			var orig_color = mat.albedo_color
			tween.tween_property(mat, "albedo_color", Color.GREEN, 0.15)
			tween.tween_property(mat, "albedo_color", orig_color, 0.15)

#endregion
#region TEMPO BAR VISUAL UPDATE
# ============================================
# TEMPO BAR VISUAL UPDATE
# ============================================

func get_action_progress() -> float:
	## 0..1 fill toward this enemy's next action (-1 when nothing is ticking).
	## Mirrors the overhead tempo bar; the unit tracker draws the same value.
	var shown := get_display_action()
	if shown.is_empty():
		return -1.0
	return clampf(float(shown["counter"]) / float(maxi(1, int(shown["cost"]))), 0.0, 1.0)

## Overhead label / bar colours per clock kind: yellow for the shared Sync
## clock, sky blue for an Async clock, orange while channeling.
const ACTION_COLOR_SYNC := Color(1.0, 0.85, 0.0)
const ACTION_COLOR_ASYNC := Color(0.55, 0.8, 1.0)
const ACTION_COLOR_CHANNEL := Color(1.0, 0.55, 0.2)

static func action_kind_color(kind: String) -> Color:
	match kind:
		"async":
			return ACTION_COLOR_ASYNC
		"channel":
			return ACTION_COLOR_CHANNEL
	return ACTION_COLOR_SYNC

func _update_tempo_bar() -> void:
	if not _tempo_bar_bg or not _tempo_bar_fg:
		return

	var shown := get_display_action()
	if shown.is_empty():
		_tempo_bar_bg.visible = false
		_tempo_bar_fg.visible = false
		if _action_label:
			_action_label.text = ""
		return

	_tempo_bar_bg.visible = true
	_tempo_bar_fg.visible = true

	var cost: int = maxi(1, int(shown["cost"]))
	var progress = clampf(float(shown["counter"]) / float(cost), 0.0, 1.0)
	var current_width = _tempo_bar_width * progress
	var kind_color := action_kind_color(str(shown["kind"]))
	var fg_mat := _tempo_bar_fg.material_override as StandardMaterial3D
	if fg_mat:
		fg_mat.albedo_color = Color(kind_color, 0.9)

	var fg_mesh = _tempo_bar_fg.mesh as QuadMesh
	if fg_mesh:
		fg_mesh.size.x = max(0.01, current_width)

	# Offset foreground so the bar fills from left to right
	_tempo_bar_fg.position.x = -(_tempo_bar_width - current_width) / 2.0

	if _action_label:
		if str(shown["kind"]) == "channel":
			_action_label.text = "Channeling %s" % str(shown["label"])
		else:
			_action_label.text = str(shown["label"])
		_action_label.modulate = kind_color
	# The action word appears/disappears: restack so the name hugs the bars.
	_layout_head_up()

#endregion
#region PHYSICS
# ============================================
# PHYSICS
# ============================================

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Glide Y toward the terrain height (elevation steps, pillars) so climbs
	# look like climbing instead of teleporting upward
	if ground_y_provider.is_valid():
		var ground_y: float = ground_y_provider.call(position)
		if absf(position.y - ground_y) > 0.002:
			position.y = move_toward(position.y, ground_y, 3.5 * delta)
		target_position.y = position.y

	if is_moving:
		var diff = target_position - position
		var flat_diff = Vector3(diff.x, 0, diff.z)
		var distance = flat_diff.length()

		if distance < 0.1:
			# Snap XZ only — Y keeps gliding toward the terrain height
			position.x = target_position.x
			position.z = target_position.z
			# Bleed: every tile reached tears the wound open — 1 damage per
			# tile, and each point of damage removes a stack.
			if bleed_stacks > 0 and not is_dead:
				# Bleed Amp (sphere node): each tile tears 1 + amp damage; one
				# stack still closes per tile.
				var bleed_tile_dmg := 1 + int(_player_sphere_amp("sphere_bleed_amp"))
				take_damage(bleed_tile_dmg, false)
				bleed_stacks -= 1
				print("[%s] Bleed deals %d damage (moved a tile, %d stack(s) left)" % [enemy_name, bleed_tile_dmg, bleed_stacks])
				if bleed_stacks <= 0:
					debuff_expired.emit(self, "bleed")
				_update_status_indicators()
			# Inflamed Minotaur: leaves fire in its wake — a trap on every tile
			# it walks off of (wake-things are Traps by convention; see STORY.md).
			# Burning a player heals the minotaur 10 (handled by main).
			if enemy_type == EnemyType.INFLAMED_MINOTAUR and grid_manager:
				var wake_cur := grid_manager.world_to_grid(position)
				if _wake_prev_cell.x > -9000 and _wake_prev_cell != wake_cur:
					var wake_main = get_parent()
					if wake_main and wake_main.has_method("register_fire_wall"):
						wake_main.register_fire_wall([_wake_prev_cell], 10, 2, 99, 15, self, 10)
				_wake_prev_cell = wake_cur
			# Advance to the next waypoint if the route has more tiles, so we
			# follow the path around corners instead of stopping short. A unit
			# that has since stepped onto the route's end cuts the route short.
			_trim_path_tail()
			if not _move_path.is_empty():
				target_position = _move_path.pop_front()
			elif _wandering:
				# Idle shuffle done: settle without the action bookkeeping a
				# real move carries (no turn_completed — no tempo was spent).
				# movement_completed still fires so terrain traps can bite.
				_wandering = false
				is_moving = false
				velocity = Vector3.ZERO
				_play_enemy_animation("idle")
				movement_completed.emit(self)
			else:
				is_moving = false
				velocity = Vector3.ZERO
				_play_enemy_animation("idle")
				movement_completed.emit(self)
				turn_completed.emit()
		else:
			velocity = flat_diff.normalized() * move_speed
			# Play walking animation / drop to all-fours while moving
			if _enemy_figure:
				_enemy_figure.set_facing_from_velocity(velocity)
				_enemy_figure.set_walking(true)
			elif _enemy_animator and _enemy_animator.sprite_sheet_loaded:
				if not _enemy_animator.is_animation_playing("walking"):
					_play_enemy_animation("walk")
	else:
		velocity = Vector3.ZERO
		_idle_ambient(delta)

	move_and_slide()

## Standing still: face whoever we're sizing up if they're in aggro range,
## otherwise pace a tile now and then.
func _idle_ambient(delta: float) -> void:
	if is_training_dummy or is_structure:
		return  # dummies and nests hold their tile
	if _wander_timer > 0.0:
		_wander_timer -= delta
	var tgt := _ambient_target()
	if tgt != null:
		var to_target := Vector3(tgt.position.x - position.x, 0.0, tgt.position.z - position.z)
		if to_target.length() <= aggro_range:
			# Someone's close: no pacing, just square up to them.
			if _enemy_figure and _enemy_figure.has_method("set_facing_from_velocity"):
				_enemy_figure.set_facing_from_velocity(to_target)
			_wander_timer = maxf(_wander_timer, 1.0)
			return
	if _wander_timer > 0.0:
		return
	_wander_timer = randf_range(3.0, 8.0)
	_try_wander()

## Whoever this enemy should be watching: the spawner's last pick, else an
## explicit target, else the scene's player (before the first tempo tick the
## spawner hasn't pointed us at anyone yet, and a freshly spawned pack must
## not pace around a player standing right beside it).
func _ambient_target() -> Node3D:
	if _last_seen_target != null and is_instance_valid(_last_seen_target):
		return _last_seen_target
	if target != null and is_instance_valid(target):
		return target
	var main = get_parent()
	if main and "player" in main and main.player and is_instance_valid(main.player):
		return main.player
	return null

func _try_wander() -> void:
	## One idle step to a free neighbouring tile inside the home leash.
	if is_structure:
		return
	if is_stunned or is_frozen or rooted_tempo > 0 or tree_tempo > 0 or is_moving or is_channeling():
		return
	if grid_manager == null:
		return
	var cur := grid_manager.world_to_grid(position)
	if cur in pillar_tiles:
		return
	if _home_cell.x < -9000:
		_home_cell = cur
	var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	dirs.shuffle()
	for d in dirs:
		var c: Vector2i = cur + d
		if absi(c.x - _home_cell.x) > WANDER_LEASH or absi(c.y - _home_cell.y) > WANDER_LEASH:
			continue
		if c in blocked_tiles or c in occupied_tiles or c in pillar_tiles:
			continue
		if dungeon_manager != null:
			if not dungeon_manager.is_floor(c):
				continue
		elif c.x < 0 or c.y < 0 or c.x >= grid_manager.grid_width or c.y >= grid_manager.grid_height:
			continue
		# Never shuffle onto a unit's tile.
		var unit := _ambient_target()
		if unit != null and grid_manager.world_to_grid(unit.position) == c:
			continue
		if c in _unit_cells():
			continue
		var wp := grid_manager.grid_to_world(c)
		if dungeon_manager != null:
			wp.y = dungeon_manager.get_elevation_world_y(c)
		_wandering = true
		_start_path([wp])
		return

#endregion
#region MOVEMENT & COMBAT
# ============================================
# MOVEMENT & COMBAT
# ============================================

func set_target(new_target: Node3D) -> void:
	target = new_target

func _build_greedy_path(start_pos: Vector3, goal_cell: Vector2i, tiles: int, away: bool = false,
		onto_goal: bool = false) -> Array[Vector3]:
	## Greedy tile-by-tile route toward (or away from) goal_cell, honoring walls
	## and other enemies. Returns the ordered list of tile-center world positions
	## so movement follows the actual path instead of gliding straight through
	## corners/walls. Empty if no step is possible. `onto_goal` lets the route
	## end ON the goal cell (a perch to stand on, not a target to stop beside).
	var path: Array[Vector3] = []
	if not grid_manager:
		return path
	var last_cell := grid_manager.world_to_grid(start_pos)
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var unit_cells: Array = _unit_cells()
	for _step in range(tiles):
		var best_cell := last_cell
		var best_dist := _manhattan_dist(last_cell, goal_cell)
		for d in dirs:
			var candidate: Vector2i = last_cell + d
			if candidate == goal_cell and not away and not onto_goal:
				continue  # Don't step onto the target's tile
			if candidate in blocked_tiles:
				continue  # Walls / structures
			if candidate in occupied_tiles:
				continue  # Other enemies
			if candidate in unit_cells:
				continue  # Players (current + destination tiles) and summons
			var dist := _manhattan_dist(candidate, goal_cell)
			var better := dist > best_dist if away else dist < best_dist
			if better:
				best_dist = dist
				best_cell = candidate
		if best_cell == last_cell:
			break  # No improving step available
		last_cell = best_cell
		var wp := grid_manager.grid_to_world(best_cell)
		if dungeon_manager:
			wp.y = dungeon_manager.get_elevation_world_y(best_cell)
		path.append(wp)
	return path

func _build_route_path(start_pos: Vector3, goal_cell: Vector2i, tiles: int) -> Array[Vector3]:
	## Shortest route toward goal_cell through the walkable grid (breadth-first
	## over walls, other enemies and player-side units), cut to the first
	## `tiles` steps and stopping beside the goal, never on it. The greedy route
	## above walks into dead ends; the Inflamed Minotaur's maze needs the real
	## way round. Empty if the goal cannot be reached (or we already stand
	## beside it).
	var path: Array[Vector3] = []
	if not grid_manager or tiles < 1:
		return path
	var start := grid_manager.world_to_grid(start_pos)
	if _manhattan_dist(start, goal_cell) <= 1:
		return path
	var unit_cells: Array = _unit_cells()
	var came_from := {start: start}
	var queue: Array = [start]
	var found := Vector2i(-9999, -9999)
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if _manhattan_dist(cur, goal_cell) <= 1:
			found = cur
			break
		for d in dirs:
			var nxt: Vector2i = cur + d
			if came_from.has(nxt) or nxt == goal_cell:
				continue
			if nxt in blocked_tiles or nxt in occupied_tiles or nxt in unit_cells:
				continue
			if nxt.x < 0 or nxt.y < 0 or nxt.x >= grid_manager.grid_width or nxt.y >= grid_manager.grid_height:
				continue
			came_from[nxt] = cur
			queue.append(nxt)
	if found.x < -9000:
		return path
	var cells: Array = []
	var walk: Vector2i = found
	while walk != start:
		cells.push_front(walk)
		walk = came_from[walk]
	for i in range(mini(tiles, cells.size())):
		var wp := grid_manager.grid_to_world(cells[i])
		if dungeon_manager:
			wp.y = dungeon_manager.get_elevation_world_y(cells[i])
		path.append(wp)
	return path

func _start_path(path: Array[Vector3]) -> bool:
	## Begin gliding along the given waypoint list. Returns false if empty.
	if path.is_empty():
		return false
	_move_path = path
	_trim_path_tail()
	if _move_path.is_empty():
		return false
	target_position = _move_path.pop_front()
	is_moving = true
	return true

func intended_cell() -> Vector2i:
	## The tile this enemy will end on: its final queued waypoint if moving,
	## otherwise its current tile. Used to reserve destinations so two enemies
	## acting in the same tempo tick don't pick the same cell.
	if not grid_manager:
		return Vector2i.ZERO
	if is_moving:
		if not _move_path.is_empty():
			return grid_manager.world_to_grid(_move_path[_move_path.size() - 1])
		return grid_manager.world_to_grid(target_position)
	return grid_manager.world_to_grid(position)

func move_towards_target(pos: Vector3) -> void:
	# Channeling: planted until the channel resolves or breaks.
	if is_channeling():
		print("[%s] Channeling - cannot move!" % enemy_name)
		return
	# Rooted (Gravity Gauntlets): held in place — attacks/casts fine, no movement.
	if rooted_tempo > 0:
		print("[%s] Rooted - cannot move!" % enemy_name)
		return
	# Enemies trapped on a rise pillar cannot move until it expires
	if grid_manager:
		var current_cell = grid_manager.world_to_grid(position)
		if current_cell in pillar_tiles:
			print("[%s] Trapped on pillar - cannot move!" % enemy_name)
			return

	var tiles = int(move_distance)
	if tiles < 1:
		tiles = 1
	# Tripped: movement -4 while it lasts; nothing left means no step at all.
	if tripped_tempo > 0:
		tiles -= TRIP_MOVE_PENALTY
		if tiles < 1:
			print("[%s] Tripped - cannot move!" % enemy_name)
			return
	# Slowed no longer trims tiles — it taxes the move action's tempo instead
	# (see _check_and_fire_actions), matching the player's Slowed.

	if grid_manager:
		# Feared (Cupids lead arrow): run AWAY from the fear source instead.
		if fear_tempo > 0 and fear_source and is_instance_valid(fear_source):
			var flee_cell = grid_manager.world_to_grid(fear_source.position)
			_start_path(_build_greedy_path(position, flee_cell, tiles, true))
			return
		var player_cell = grid_manager.world_to_grid(pos)
		# Follow a tile-by-tile route so we never glide through walls or corners.
		# The Inflamed Minotaur knows his Labyrinth: he takes the real way
		# round its walls where a greedy step would dead-end.
		if enemy_type == EnemyType.INFLAMED_MINOTAUR:
			var route := _build_route_path(position, player_cell, tiles)
			if not route.is_empty():
				_start_path(route)
				return
		_start_path(_build_greedy_path(position, player_cell, tiles))
	else:
		var diff = pos - position
		var direction = Vector3(diff.x, 0, diff.z).normalized()
		var new_target = position + direction * (tiles * 1.0)
		target_position = new_target
		is_moving = true

func _manhattan_dist(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func attack_player(player_node: Node3D) -> void:
	_deal_damage_to_player(player_node, attack_damage, "Attack")

#endregion
#region TAKING DAMAGE
# ============================================
# TAKING DAMAGE
# ============================================

## Deal damage to this enemy. Armor absorbs first, remainder hits health.
## Set from_player = true when the damage originates from the player's card/attack.
## Returns true if the enemy was just Exposed (armor broken to 0).
## The player's sphere-grid debuff amps (Vuln Amp / Weaken Amp nodes) apply to
## every Vulnerable/Weaken this enemy carries. Enemies sit under main, which
## holds the player — returns 0 outside that tree (tests, summons).
func _player_sphere_amp(field: String) -> float:
	var main = get_parent()
	if main and "player" in main and main.player and main.player.has_method("get_stats"):
		var stats = main.player.get_stats()
		if stats and field in stats:
			return float(stats.get(field))
	return 0.0

func take_damage(amount: int, from_player: bool = false, damage_type: int = DamageTypes.Type.PHYSICAL, ignore_armor: bool = false) -> bool:
	# ignore_armor: skip the armor-absorption chain entirely so the full amount
	# hits health (Neither Man nor Beast "ignoring all resistances and armor").
	if is_dead:
		return false
	# Hell's Door, sealed: nothing gets through until the seal fades.
	if enemy_type == EnemyType.HELL_DOOR and door_sealed_tempo > 0:
		print("[%s] Sealed — the blow glances off (%d tempo left)" % [enemy_name, door_sealed_tempo])
		if _enemy_figure and _enemy_figure.has_method("flash"):
			_enemy_figure.flash(Color(0.9, 0.3, 0.3))
		return false
	last_hit_from_player = from_player
	last_hit_direct = from_player and PlayerStats.hit_source_direct
	# Blue Robe: each enemy a slotted card strikes takes the type IT resists least.
	if from_player and PlayerStats.adaptive_damage_type and not ignore_armor:
		damage_type = get_lowest_resistance_type()

	# Per-type resistance: percent reduction from damage_resistances (empty for
	# most enemies today — Blue Robe reads this table for its adaptive type).
	# ignore_armor hits bypass resistances too (Neither Man nor Beast).
	if not ignore_armor:
		var type_resist: float = float(damage_resistances.get(damage_type, 0.0))
		if damage_type == DamageTypes.Type.PHYSICAL and phys_defense_debuff_tempo > 0:
			type_resist -= phys_defense_debuff_percent  # lowered defense: below 0 is a vulnerability
		if type_resist != 0.0:
			# Negative resist = vulnerability: the hit lands harder (Treant vs fire).
			# Percent math before the divide keeps 100 * 115% at exactly 115.
			amount = floori(amount * (100.0 - minf(type_resist, 90.0)) / 100.0)

	# Skill-tree hit modifiers (Cory's Eat, Brad's Solemn Independence): a
	# percentage on the player's direct hits — cards, gauntlet skills, the
	# auto attack — never on DoT ticks, which pass from_player = false.
	if from_player and player_hit_modifier.is_valid():
		amount = int(player_hit_modifier.call(self, amount))
	# Cerberus — Guardian of Death: Brace takes 30% off each of the next hits.
	if _brace_charges > 0 and amount > 0:
		amount = floori(amount * 0.7)
		_brace_charges -= 1
		print("[%s] Braced! -30%% (%d hits of Brace left)" % [enemy_name, _brace_charges])
		_update_status_indicators()
	if amount > 0:
		has_been_damaged = true

	# Raw post-resist size of this hit, for the elite threshold reactions
	# (Ifrit backflip, Minotaur leap, Djinn wishes, bear strengthen).
	var incoming_hit: int = amount
	var _health_before_hit: int = current_health
	var _armor_before_hit: int = current_armor  # Sewer Cobra: thorns are judged on the armor it had

	# Remember the raw incoming damage of this hit (before armor math) so
	# on-expose passives like Easy Target can repeat "your damage".
	if from_player:
		last_player_hit_damage = amount

	# Hydra: grows stronger with every hit she takes — sheet: "every time she
	# is hit", so any damage source counts (allies, DoT ticks, self-damage).
	if enemy_type == EnemyType.HYDRA and amount > 0:
		hits_taken += 1
		strength += 2
		print("[%s] Enraged by hit %d — strength now %d" % [enemy_name, hits_taken, strength])
		if hits_taken == 4:
			max_health += 40
			current_health += 40
			hydra_heal_unlocked = true
			print("[%s] Grows hardier (+40 max HP) and prepares to heal!" % enemy_name)
			update_health_display()

	# Forest traits that react to being hit by the player.
	if from_player and enemy_type != EnemyType.HYDRA:
		hits_taken += 1  # Bugbear First Strike: lost once the player lands a hit.
	if from_player and enemy_type == EnemyType.MINI_BEAR:
		_alert_mini_bear_pack()

	# Wear Down stacks only off the player's hits — DoT ticks (poison, burn,
	# shock) route through take_damage too and must not count as "hits".
	if from_player and wear_down_tempo > 0:
		attack_reduction += 1
		print("[%s] Wear Down stacks! Attack reduced by %d" % [enemy_name, attack_reduction])
		_update_status_indicators()

	# Apply premeditated bonus damage (only from player attacks)
	if from_player and bonus_damage_next_hit > 0:
		print("[%s] Premeditated bonus: +%d damage!" % [enemy_name, bonus_damage_next_hit])
		amount += bonus_damage_next_hit
		bonus_damage_next_hit = 0

	# Marked (Mark card): the player's attacks deal bonus damage to this target.
	if from_player and is_marked:
		var mark_bonus: int = ceili(amount * MARKED_BONUS_PERCENT / 100.0)
		amount += mark_bonus
		print("[%s] Marked: +%d damage!" % [enemy_name, mark_bonus])

	# Void resistance (Mane of Narashimha aura): resistances lowered, so the
	# player's hits land for extra damage while the enemy is inside the aura.
	if from_player and void_resistance_percent > 0.0:
		amount = floori(amount * (1.0 + void_resistance_percent / 100.0))

	# Vulnerable: the hit lands 30% harder (plus the player's Vuln Amp sphere
	# nodes), consuming one stack.
	if from_player and vulnerable_stacks > 0:
		var vuln_percent: float = 30.0 + _player_sphere_amp("sphere_vulnerable_amp")
		amount = floori(amount * (1.0 + vuln_percent / 100.0))
		vulnerable_stacks -= 1
		print("[%s] Vulnerable! +%d%% damage (%d stacks left)" % [enemy_name, int(vuln_percent), vulnerable_stacks])
		_update_status_indicators()

	# Jordan 1s: below the threshold health %, add rate × missing-health% damage.
	if from_player and missing_life_damage_rate > 0.0 and max_health > 0:
		var health_pct: float = float(current_health) / float(max_health) * 100.0
		if health_pct <= missing_life_threshold:
			amount += floori(missing_life_damage_rate * (100.0 - health_pct))

	# Armor Break: double damage to armor, no health damage. Zero effect on unarmored.
	var just_exposed = false
	if ignore_armor:
		pass  # bypass armor entirely — the full amount falls through to health below
	elif armor_break_incoming and current_armor <= 0:
		amount = 0
		print("[%s] Armor Break: no armor to break, no damage dealt" % enemy_name)
	elif armor_break_incoming and current_armor > 0:
		var doubled = amount * 2
		var armor_absorbed = min(current_armor, doubled)
		current_armor -= armor_absorbed
		print("[%s] Armor Break! %d doubled damage to armor! Armor: %d/%d" % [enemy_name, armor_absorbed, current_armor, max_armor])
		_update_armor_bar()
		if current_armor <= 0:
			just_exposed = true
			is_exposed = true
			print("[%s] EXPOSED! Armor broken!" % enemy_name)
		amount = 0  # No spillover to health
	elif current_armor > 0:
		# Normal armor absorbs damage first
		var was_armored = current_armor > 0
		var armor_absorbed = min(current_armor, amount)
		current_armor -= armor_absorbed
		amount -= armor_absorbed
		print("[%s] Armor absorbed %d damage! Armor: %d/%d" % [enemy_name, armor_absorbed, current_armor, max_armor])
		_update_armor_bar()
		if was_armored and current_armor <= 0:
			just_exposed = true
			is_exposed = true
			print("[%s] EXPOSED! Armor broken!" % enemy_name)

	# Remaining damage hits health (skipped if armor break consumed all damage)
	if amount > 0:
		current_health -= amount
		current_health = max(0, current_health)

	damaged.emit(amount)
	update_health_display()

	# Floating damage number
	_spawn_damage_number(amount, just_exposed)

	# Damage flash on figure, sprite, or mesh
	if _enemy_figure:
		_enemy_figure.play_action("hit")
		_enemy_figure.flash(Color(1.0, 0.3, 0.3))
	elif _enemy_sprite and _enemy_animator and _enemy_animator.sprite_sheet_loaded:
		_play_enemy_animation("hit")
		var tween = create_tween()
		tween.tween_property(_enemy_sprite, "modulate", Color(1.0, 0.3, 0.3), 0.1)
		tween.tween_property(_enemy_sprite, "modulate", Color.WHITE, 0.15)
	elif mesh:
		var tween = create_tween()
		var mat = mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			var orig_color = mat.albedo_color
			tween.tween_property(mat, "albedo_color", Color.RED, 0.1)
			tween.tween_property(mat, "albedo_color", orig_color, 0.1)

	print("[%s] Took damage! Health: %d/%d, Armor: %d/%d" % [enemy_name, current_health, max_health, current_armor, max_armor])

	# Earth Mage: gain armor every time it is hit (for the NEXT blow, applied after
	# this hit has resolved so it doesn't soak the triggering damage).
	if from_player and armor_per_hit > 0 and current_health > 0:
		current_armor += armor_per_hit
		max_armor = max(max_armor, current_armor)
		_update_armor_bar()
		print("[%s] Hardens — +%d armor (now %d)" % [enemy_name, armor_per_hit, current_armor])

	# Large Bear: drops to all fours below 20% HP (posture change).
	if enemy_type == EnemyType.LARGE_BEAR and not _drops_to_all_fours \
			and current_health > 0 and current_health <= max_health * 0.20:
		_drops_to_all_fours = true
		if _enemy_figure and _enemy_figure.has_method("set_quadruped"):
			_enemy_figure.set_quadruped(true)
		print("[%s] Wounded — drops to all fours!" % enemy_name)

	# --- Elite first-pass on-hit reactions ---
	if not is_dead and current_health > 0:
		match enemy_type:
			EnemyType.LARGE_BEAR:
				# Mini Bears watching: +1 strengthen per hit taken, ANY source.
				if incoming_hit > 0 and _mini_bears_present():
					strengthen_stacks += 1
					print("[%s] The little ones watch — strengthen %d!" % [enemy_name, strengthen_stacks])
				# Toughened hide below 50% HP: 30% physical resistance that
				# never goes away, even if the bear heals back above half.
				if not _bear_hide_toughened and current_health * 2 < max_health:
					_bear_hide_toughened = true
					damage_resistances[DamageTypes.Type.PHYSICAL] = maxf(30.0,
						float(damage_resistances.get(DamageTypes.Type.PHYSICAL, 0.0)))
					print("[%s] Hide toughens — 30%% physical resistance, for good!" % enemy_name)
			EnemyType.RAT_KING:
				_rat_king_consider_nest()
			EnemyType.CERBERUS:
				# Guardian of Death on himself: the first time below half.
				if not _guardian_self_used and current_health * 2 < max_health:
					_guardian_self_used = true
					_gain_guardian_brace("Cerberus below half")
				if from_player and last_hit_direct and enemy_thorns > 0 and incoming_hit > 0:
					_thorns_strike_back()
			EnemyType.HELL_DOOR:
				_door_check_thresholds()
			EnemyType.VAMPIRE:
				# Bat form: below 50% HP, flies 6 squares away (2 charges, no
				# way to recharge), then Absorb is always the next cast.
				if _bat_form_charges > 0 and current_health * 2 < max_health:
					_bat_form_charges -= 1
					_vamp_absorb_pending = true
					chosen_action = {}
					action_tempo_counter = 0
					var vamp_main = get_parent()
					if vamp_main and "player" in vamp_main and vamp_main.player and is_instance_valid(vamp_main.player):
						_dash_away_from(vamp_main.player.position, 6)
					print("[%s] BAT FORM — flits away! (%d charge(s) left)" % [enemy_name, _bat_form_charges])
			EnemyType.IFRIT:
				# Backflip: a single blow over 40 sends it 3 squares backwards.
				if from_player and incoming_hit > 40:
					var ifrit_main = get_parent()
					if ifrit_main and "player" in ifrit_main and ifrit_main.player and is_instance_valid(ifrit_main.player):
						knockback(ifrit_main.player.position, 3)
						print("[%s] Backflips away from the blow!" % enemy_name)
			EnemyType.INFLAMED_MINOTAUR:
				# Labyrinth Leap: once the damage he has taken from the player
				# since his last leap passes 20 — a running total, not a single
				# blow — he springs away (tempo does not trigger this; the
				# damage threshold does). A Bull Rush still owed goes first;
				# the total keeps counting underneath it.
				if from_player and incoming_hit > 0:
					_minotaur_damage_taken += incoming_hit
					if _minotaur_damage_taken > 20 and not _minotaur_rush_pending:
						_minotaur_labyrinth_leap()
			EnemyType.DJINN:
				# Every attack on the Djinn grants the attacker 3 Wishes, each
				# searing the holder for 1/3 of that attack's damage per cycle
				# until bought off (60 mana, 0 tempo).
				if from_player and incoming_hit > 0:
					var djinn_main = get_parent()
					if djinn_main and "player" in djinn_main and djinn_main.player \
							and djinn_main.player.has_method("get_deck_manager"):
						var djinn_deck = djinn_main.player.get_deck_manager()
						if djinn_deck:
							var per_wish: int = maxi(1, floori(incoming_hit / 3.0))
							for _w in range(3):
								djinn_deck.add_card_to_hand(Card.create_djinn_wish(per_wish))
							print("[%s] Grants 3 Wishes... each seething for %d per cycle held" % [enemy_name, per_wish])

	if just_exposed:
		exposed.emit(self)

	# --- Sewer Cobra (sheet passives) ---
	if enemy_type == EnemyType.SEWER_CROC and not is_dead:
		if from_player and last_hit_direct and incoming_hit > 0:
			# "While the sewer cobra has armor, they have 5 thorns": a flat 5
			# back at the attacker for every direct hit landed while it was
			# still armoured — judged before the hit, so the blow that breaks
			# the armor pays too. Not Roar's decaying enemy_thorns.
			if _armor_before_hit > 0:
				_cobra_strike_back(COBRA_THORNS)
			# "When receiving damage directly to health, the sewer cobra
			# inflicts 3 poison to the attacker": health lost, not just armor.
			if current_health < _health_before_hit:
				_cobra_poison_attacker(COBRA_HEALTH_POISON)
		if just_exposed and current_health > 0:
			# "Upon being exposed, the sewer cobra is stunned for 3 tempo and
			# its tempo counter is completely reset": apply_debuff("stun")
			# resets every clock, Bite's and Venom Spray's alike.
			apply_debuff("stun", COBRA_EXPOSED_STUN)

	# Action keywords: Disruptable clocks count this hit; Trigger actions
	# keyed to being hit, losing armor, or dropping under half health fire.
	if incoming_hit > 0 and not is_dead:
		_on_damage_for_disrupt(incoming_hit)
		fire_trigger("damaged")
		if just_exposed:
			fire_trigger("exposed")
		if _health_before_hit * 2 > max_health and current_health * 2 <= max_health and current_health > 0:
			fire_trigger("half_health")

	if current_health <= 0:
		if is_training_dummy:
			# A dojo dummy shrugs a killing blow off: back to full, no death,
			# no loot, no XP — the numbers were the point.
			current_health = max_health
			update_health_display()
			print("[%s] Refilled to %d" % [enemy_name, max_health])
		else:
			die()

	return just_exposed

func _alert_mini_bear_pack() -> void:
	## When this mini bear is hurt, packmates within sight gain +2 attack damage.
	for e in _sibling_enemies():
		if e != self and e.enemy_type == EnemyType.MINI_BEAR and e.is_alive():
			if position.distance_to(e.position) <= e.aggro_range:
				e.pack_attack_bonus += 2
				print("[%s] Packmate hurt — attack now +%d" % [e.enemy_name, e.pack_attack_bonus])

#endregion
#region FLOATING DAMAGE NUMBERS
# ============================================
# FLOATING DAMAGE NUMBERS
# ============================================

func _spawn_damage_number(amount: int, was_exposed: bool = false) -> void:
	if amount <= 0:
		return

	var label = Label3D.new()
	label.text = str(amount)
	label.font_size = 28 if amount >= 10 else 22
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 50

	# Color based on damage significance
	if was_exposed:
		label.modulate = Color(1.0, 0.5, 0.0)  # Orange for armor break
		label.font_size = 32
		label.text = str(amount) + "!"
	elif amount >= 15:
		label.modulate = Color(1.0, 0.2, 0.2)  # Bright red for big hits
		label.font_size = 32
	elif amount >= 8:
		label.modulate = Color(1.0, 0.5, 0.3)  # Orange-red for medium hits
	else:
		label.modulate = Color(1.0, 0.85, 0.5)  # Yellow for small hits

	# Random horizontal offset to avoid stacking
	var x_offset = randf_range(-0.3, 0.3)
	label.position = position + Vector3(x_offset, 1.5, 0)
	get_parent().add_child(label)

	# Animate: float up and fade out
	var tween = label.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 1.5, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.3)
	# Slight scale up then down
	tween.tween_property(label, "font_size", label.font_size + 6, 0.1)
	tween.chain()
	tween.tween_property(label, "font_size", label.font_size, 0.3)

	tween.chain()
	tween.tween_callback(label.queue_free)

#endregion
#region DAMAGE PREVIEW
# ============================================
# DAMAGE PREVIEW
# ============================================

func show_damage_preview(amount: int) -> void:
	## Show a red damage number above the enemy's head as a preview.
	if amount <= 0:
		hide_damage_preview()
		return

	if not _damage_preview_label:
		_damage_preview_label = Label3D.new()
		_damage_preview_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_damage_preview_label.no_depth_test = true
		_damage_preview_label.render_priority = 60
		_damage_preview_label.outline_size = 10
		_damage_preview_label.outline_modulate = Color(0, 0, 0, 0.8)
		add_child(_damage_preview_label)

	_damage_preview_label.text = str(amount)
	_damage_preview_label.font_size = 30 if amount >= 15 else 24
	_damage_preview_label.modulate = Color(1.0, 0.2, 0.2, 0.9)
	_damage_preview_label.position = Vector3(0, 2.0, 0)
	_damage_preview_label.visible = true

func hide_damage_preview() -> void:
	if _damage_preview_label and is_instance_valid(_damage_preview_label):
		_damage_preview_label.visible = false

#endregion
#region STATUS EFFECTS
# ============================================
# STATUS EFFECTS
# ============================================

## Lower physical defense by `percent` for `tempo` (a stronger application
## replaces a weaker one; the timer refreshes either way).
func apply_phys_defense_debuff(percent: float, tempo: int) -> void:
	phys_defense_debuff_percent = maxf(phys_defense_debuff_percent, percent)
	phys_defense_debuff_tempo = maxi(phys_defense_debuff_tempo, tempo)
	print("[%s] Physical defense -%.0f%% for %d tempo" % [enemy_name, phys_defense_debuff_percent, phys_defense_debuff_tempo])

func apply_taunt(taunter: Node3D, tempo: int) -> void:
	taunt_target = taunter
	taunt_tempo = tempo
	print("[%s] Taunted for %d tempo" % [enemy_name, tempo])
	_update_status_indicators()

func apply_fear(source: Node3D, tempo: int) -> void:
	## Feared (Cupids lead arrow): movement runs AWAY from the source.
	fear_source = source
	fear_tempo = tempo
	print("[%s] Feared for %d tempo" % [enemy_name, tempo])
	_update_status_indicators()

## Cupids Bow: mark the enemy with one arrow; once both marks land, the enemy
## becomes a tree. Returns true when this mark completed the pair.
func apply_cupid_mark(golden: bool) -> bool:
	if golden:
		cupid_golden = true
	else:
		cupid_lead = true
	print("[%s] Cupid mark: %s" % [enemy_name, "golden" if golden else "lead"])
	if cupid_golden and cupid_lead and tree_tempo <= 0:
		cupid_golden = false
		cupid_lead = false
		_enter_tree_form()
		return true
	_update_status_indicators()
	return false

var _tree_node: Node3D = null

func _enter_tree_form() -> void:
	## 4 tempo as a tree: keeps every buff/debuff, cannot act, and heals 3 on
	## each of its first 3 tempo. The body is hidden behind a little tree.
	tree_tempo = 4
	tree_regen_ticks = 3
	print("[%s] Turned into a tree!" % enemy_name)
	if _enemy_figure:
		_enemy_figure.visible = false
	if _tree_node == null:
		_tree_node = Node3D.new()
		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.09
		trunk_mesh.bottom_radius = 0.13
		trunk_mesh.height = 0.6
		trunk.mesh = trunk_mesh
		var trunk_mat := StandardMaterial3D.new()
		trunk_mat.albedo_color = Color(0.42, 0.28, 0.12)
		trunk.material_override = trunk_mat
		trunk.position.y = 0.3
		_tree_node.add_child(trunk)
		var crown := MeshInstance3D.new()
		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = 0.35
		crown_mesh.height = 0.6
		crown.mesh = crown_mesh
		var crown_mat := StandardMaterial3D.new()
		crown_mat.albedo_color = Color(0.22, 0.55, 0.2)
		crown.material_override = crown_mat
		crown.position.y = 0.85
		_tree_node.add_child(crown)
		add_child(_tree_node)
	_tree_node.visible = true
	_update_status_indicators()

func _exit_tree_form() -> void:
	tree_tempo = 0
	tree_regen_ticks = 0
	if _tree_node:
		_tree_node.visible = false
	if _enemy_figure:
		_enemy_figure.visible = true
	print("[%s] No longer a tree" % enemy_name)
	_update_status_indicators()

func set_armor_break_incoming(value: bool) -> void:
	armor_break_incoming = value

func apply_wear_down(tempo: int) -> void:
	wear_down_tempo = max(wear_down_tempo, tempo)
	print("[%s] Wear Down applied for %d tempo" % [enemy_name, wear_down_tempo])
	_update_status_indicators()

## True when a debuff of this apply_debuff key is already active on this enemy.
## Keys mirror the match arms in apply_debuff.
func has_debuff_type(debuff_name: String) -> bool:
	match debuff_name:
		"stun": return is_stunned and stun_tempo > 0
		"slow": return slow_stacks > 0
		"disarmed": return is_disarmed and disarmed_tempo > 0
		"marked": return is_marked and marked_tempo > 0
		"silenced": return is_silenced and silenced_tempo > 0
		"choke_dot": return choke_dot_stacks > 0
		"burn": return burn_stacks > 0
		"cold": return cold_stacks > 0 or (is_frozen and frozen_tempo > 0)
		"poison": return poison_stacks > 0
		"shock": return shock_stacks > 0
		"bleed": return bleed_stacks > 0
		"vulnerable": return vulnerable_stacks > 0
		"weaken": return weaken_stacks > 0
		"root": return rooted_tempo > 0
		"trip": return tripped_tempo > 0
		"cursed": return cursed_tempo > 0
		"disarm_attacks": return disarmed_attacks > 0
		"narashimha": return narashimha_tempo > 0
		"polymorph": return polymorph_tempo > 0
	return false

# Whether the most recent apply_debuff added a debuff type the enemy did not
# already have (read by Prey on the Weak, which triggers on unique debuffs only).
var last_debuff_was_new: bool = false

func apply_debuff(debuff_name: String, value: int) -> void:
	# Feral Evocation: while a converted card's play resolves, any of the four
	# slot elements it lands is swapped to the converted color's element.
	if Card.active_element_remap != "" and debuff_name in ["burn", "cold", "shock", "poison"] \
			and debuff_name != Card.active_element_remap:
		print("[%s] Feral Evocation: %s becomes %s" % [enemy_name, debuff_name, Card.active_element_remap])
		debuff_name = Card.active_element_remap
	# Elixir: poison from a card played under Elixir heals instead.
	if debuff_name == "poison" and Card.elixir_poison_heals and value > 0:
		_regenerate(value)
		print("[%s] Elixir: %d poison became healing" % [enemy_name, value])
		return
	last_debuff_was_new = not has_debuff_type(debuff_name)
	match debuff_name:
		"stun":
			is_stunned = true
			stun_tempo = max(stun_tempo, value + int(_player_sphere_amp("sphere_stun_amp")))
			# Reset every action clock so stun delays their next action
			_reset_action_clocks()
			print("[%s] Stunned for %d tempo!" % [enemy_name, stun_tempo])
		"slow":
			# Slowed stacks freely: every movement is delayed (+2 tempo) and eats a stack.
			slow_stacks += value
			print("[%s] Slowed! Delayed movement for the next %d movement(s)" % [enemy_name, slow_stacks])
		"disarmed":
			is_disarmed = true
			disarmed_tempo = value + int(_player_sphere_amp("sphere_disarm_amp"))
			print("[%s] Disarmed for %d tempo" % [enemy_name, disarmed_tempo])
		"marked":
			is_marked = true
			marked_tempo = value
			print("[%s] Marked for %d tempo" % [enemy_name, value])
		"silenced":
			is_silenced = true
			silenced_tempo = max(silenced_tempo, value + int(_player_sphere_amp("sphere_silence_amp")))
			# Drop any queued spell so the enemy re-decides now that it's muted
			chosen_action = {}
			print("[%s] Silenced for %d tempo!" % [enemy_name, silenced_tempo])
		"choke_dot":
			choke_dot_stacks += value
			print("[%s] Choke DoT applied! Stacks: %d" % [enemy_name, choke_dot_stacks])
		"burn":
			burn_stacks += value
			print("[%s] Burning! Stacks: %d" % [enemy_name, burn_stacks])
		"cold":
			cold_stacks += value
			print("[%s] Cold applied! Stacks: %d/5" % [enemy_name, cold_stacks])
			if cold_stacks >= 5:
				cold_stacks = 0
				cold_damage_next = 1  # Element Pollination's doubling tick restarts with the freeze
				is_frozen = true
				frozen_tempo = max(frozen_tempo, 5)  # Frozen for 5 tempo (one cycle)
				# Reset every action clock so frozen delays their next action
				_reset_action_clocks()
				print("[%s] FROZEN! Cold reached 5 stacks!" % enemy_name)
		"poison":
			poison_stacks += value
			print("[%s] Poisoned! Stacks: %d" % [enemy_name, poison_stacks])
		"shock":
			shock_stacks += value + int(_player_sphere_amp("sphere_shock_amp"))
			print("[%s] Shocked! Stacks: %d" % [enemy_name, shock_stacks])
			# Element Pollination: Shock stuns at 5 stacks like Cold freezes,
			# while the Elemental Weaver's maintain is up.
			if Card.element_pollination_active and shock_stacks >= 5:
				shock_stacks = 0
				is_stunned = true
				stun_tempo = max(stun_tempo, 5)  # "freezes like Cold": a 5-tempo stun
				_reset_action_clocks()
				print("[%s] STUNNED! Shock reached 5 stacks (Element Pollination)!" % enemy_name)
		"bleed":
			bleed_stacks += value
			print("[%s] Bleeding! Stacks: %d (damage per tile moved)" % [enemy_name, bleed_stacks])
		"vulnerable":
			vulnerable_stacks += value
			print("[%s] Vulnerable! Stacks: %d (+30%% per hit taken)" % [enemy_name, vulnerable_stacks])
		"weaken":
			weaken_stacks += value
			print("[%s] Weakened! Stacks: %d (-30%% damage dealt)" % [enemy_name, weaken_stacks])
		"trip":
			# value is the duration in raw tempo; movement -TRIP_MOVE_PENALTY
			tripped_tempo = max(tripped_tempo, value)
			print("[%s] Tripped! Movement -%d for %d tempo" % [enemy_name, TRIP_MOVE_PENALTY, tripped_tempo])
		"root":
			# value is the hold in raw tempo; can attack and cast, cannot move
			rooted_tempo = max(rooted_tempo, value + int(_player_sphere_amp("sphere_root_amp")))
			print("[%s] Rooted for %d tempo!" % [enemy_name, rooted_tempo])
		"cursed":
			# Matches the player's Cursed: deals less damage AND hurts itself on
			# every attack (base 20%/20%, boosted by Curse Amp / Curse Pain).
			cursed_tempo = max(cursed_tempo, value)
			print("[%s] Cursed for %d tempo!" % [enemy_name, cursed_tempo])
		"disarm_attacks":
			disarmed_attacks += value
			print("[%s] Disarmed for %d attack(s)!" % [enemy_name, disarmed_attacks])
		"narashimha":
			# value is the window in raw tempo. Applied right after the Neither
			# Man nor Beast hit, so current health IS the ceiling: healing can
			# never bring health back above this point, which is exactly
			# "cannot heal the damage dealt by this card".
			narashimha_tempo = max(narashimha_tempo, value)
			narashimha_heal_cap = current_health if narashimha_heal_cap < 0 else min(narashimha_heal_cap, current_health)
			print("[%s] Narashimha: cannot heal above %d for %d cycles" % [enemy_name, narashimha_heal_cap, narashimha_tempo])
		"polymorph":
			# Circe's Wand: value is the window in raw tempo (5 tempo = 1 cycle).
			# A pig re-decides what it was about to do — with far fewer options.
			polymorph_tempo = max(polymorph_tempo, maxi(1, ceili(value / 5.0)))
			chosen_action = {}
			print("[%s] POLYMORPH! A pig for %d cycle(s) — walk and bite only" % [enemy_name, polymorph_tempo])
		_:
			print("[%s] Unknown debuff: %s" % [enemy_name, debuff_name])
	debuff_applied.emit(self, debuff_name, value)
	_update_status_indicators()

func apply_stun(tempo: int = 5) -> void:
	apply_debuff("stun", tempo)

func knockback(away_from: Vector3, spaces: int = 1) -> void:
	if is_dead:
		return
	if not grid_manager:
		return
	var diff = position - away_from
	# Determine grid direction: allow diagonal by using sign of each axis
	var dir_x = 0
	var dir_z = 0
	if abs(diff.x) > 0.1:
		dir_x = 1 if diff.x > 0 else -1
	if abs(diff.z) > 0.1:
		dir_z = 1 if diff.z > 0 else -1
	if dir_x == 0 and dir_z == 0:
		return
	knock_dir(Vector2i(dir_x, dir_z), spaces)

## Shove `spaces` tiles along `dir` (a unit grid step, diagonals allowed),
## stopping short of blocked or occupied tiles.
func knock_dir(dir: Vector2i, spaces: int) -> void:
	if is_dead or not grid_manager or spaces <= 0 or dir == Vector2i.ZERO:
		return
	var dir_x: int = dir.x
	var dir_z: int = dir.y
	# Step tile-by-tile, stopping at blocked or occupied tiles
	var current_cell = grid_manager.world_to_grid(position)
	var last_valid_cell = current_cell
	var taken: Array = _unit_cells()
	for i in range(spaces):
		var next_cell = Vector2i(current_cell.x + dir_x * (i + 1), current_cell.y + dir_z * (i + 1))
		if next_cell in blocked_tiles or next_cell in occupied_tiles or next_cell in taken:
			break
		last_valid_cell = next_cell
	var new_pos = grid_manager.grid_to_world(last_valid_cell)
	position = new_pos
	target_position = new_pos
	print("[%s] Knocked back %d space(s)" % [enemy_name, spaces])
	if last_valid_cell != current_cell:
		# A shove is a move too: melee-range edges (Territorial Death, In the
		# Trenches, Close is Favored) and terrain traps see the new tile.
		movement_completed.emit(self)

#endregion
#region HEALTH & DISPLAY
# ============================================
# HEALTH & DISPLAY
# ============================================

func update_health_display() -> void:
	if health_label:
		health_label.text = "%d / %d" % [current_health, max_health]
	_update_health_bar()

func reduce_armor(amount: int) -> void:
	if current_armor > 0:
		current_armor = max(0, current_armor - amount)
		_update_armor_bar()

func update_outline() -> void:
	if not outline:
		return
	var mat = outline.get_surface_override_material(0) as StandardMaterial3D
	match enemy_type:
		EnemyType.ELITE:
			outline.visible = true
			if mat:
				mat.albedo_color = Color(1.0, 0.85, 0.0, 0.8)
		EnemyType.BOSS:
			outline.visible = true
			if mat:
				mat.albedo_color = Color(0.8, 0.0, 0.8, 0.8)
		EnemyType.ARMORED_TROLL:
			outline.visible = true
			if mat:
				mat.albedo_color = Color(0.0, 0.8, 0.2, 0.8)  # Green glow
		_:
			outline.visible = false

func set_hover_highlight(enabled: bool) -> void:
	## Toggle the mouse-hover highlight. Enemies that have a procedural figure
	## glow the model directly so the placeholder box outline never appears
	## around them; box-mesh enemies fall back to the bright outline box.
	_set_hover_text_visible(enabled)
	if _enemy_figure:
		_enemy_figure.set_highlight(enabled)
		if outline:
			outline.visible = false
		return
	if not outline:
		return
	if enabled:
		var mat = outline.get_surface_override_material(0) as StandardMaterial3D
		outline.visible = true
		if mat:
			mat.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
	else:
		update_outline()

func _set_hover_text_visible(shown: bool) -> void:
	## The name and the exact health / armor numbers only appear while the
	## enemy is hovered (battlefield or unit tracker); the bars themselves
	## stay up all the time.
	if name_label:
		name_label.visible = shown
	if health_label:
		health_label.visible = shown
	if _armor_label:
		_armor_label.visible = shown
	if _action_label:
		_action_label.visible = shown

func update_name_display() -> void:
	if name_label:
		name_label.text = enemy_name
		match enemy_type:
			EnemyType.ELITE:
				name_label.modulate = Color(1.0, 0.85, 0.0)
			EnemyType.BOSS:
				name_label.modulate = Color(0.8, 0.0, 0.8)
			EnemyType.ARMORED_TROLL:
				name_label.modulate = Color(0.4, 1.0, 0.3)  # Green
			_:
				name_label.modulate = Color(1.0, 1.0, 1.0)

const CONSUMED_EXPLOSION_DAMAGE: int = 8
const CONSUMED_EXPLOSION_RANGE: float = 1.9   # adjacent tiles (incl. diagonals)

func die() -> void:
	is_dead = true
	_reset_action_clocks()
	print("[%s] Defeated!" % enemy_name)
	if enemy_type == EnemyType.CONSUMED:
		_consumed_explode()
	died.emit(self)

	# Hide tempo bar on death
	if _tempo_bar_bg:
		_tempo_bar_bg.visible = false
	_die_visuals()

func _consumed_explode() -> void:
	## The Consumed: on death, explodes for damage to EVERYTHING nearby —
	## the player and fellow enemies alike.
	print("[%s] Bursts apart in a wave of hatred!" % enemy_name)
	var main = get_parent()
	if main and "player" in main and main.player and is_instance_valid(main.player):
		var diff = main.player.position - position
		if Vector3(diff.x, 0, diff.z).length() <= CONSUMED_EXPLOSION_RANGE:
			_deal_damage_to_player(main.player, maxi(1, roundi(CONSUMED_EXPLOSION_DAMAGE * _pps_dmg)), "Death Burst")
	for e in _sibling_enemies():
		if e != self and is_instance_valid(e) and e.is_alive():
			if position.distance_to(e.position) <= CONSUMED_EXPLOSION_RANGE:
				e.take_damage(CONSUMED_EXPLOSION_DAMAGE, false)

func _die_visuals() -> void:
	if _tempo_bar_fg:
		_tempo_bar_fg.visible = false
	if _health_bar_bg:
		_health_bar_bg.visible = false
	if _health_bar_fg:
		_health_bar_fg.visible = false
	if _action_label:
		_action_label.text = ""
	# Hide armor bar on death
	if _armor_bar_sprite:
		_armor_bar_sprite.visible = false
	if _armor_label:
		_armor_label.text = ""

	# Stop animations on death
	if _enemy_animator:
		_enemy_animator.stop()

	# Shrinking a PHYSICS body to zero scale makes its basis singular — the
	# physics server then spams `invert: Condition "det == 0"` every frame.
	# Drop the collider first and stop the shrink just shy of zero; the node
	# frees right after, so the difference is invisible.
	var death_col := get_node_or_null("CollisionShape3D")
	if death_col is CollisionShape3D:
		death_col.set_deferred("disabled", true)
	# Figures with real death frames (Craftpix packs) play them out first;
	# the shrink-away then removes the corpse.
	var hold := 0.0
	if _enemy_figure and _enemy_figure.has_method("play_death"):
		hold = _enemy_figure.play_death()
	var tween = create_tween()
	if hold > 0.0:
		tween.tween_interval(hold + 0.25)
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.5)
	tween.tween_callback(queue_free)

func is_alive() -> bool:
	return not is_dead

#endregion
#region STATUS EFFECT DATA & VISUAL INDICATORS
# ============================================
# STATUS EFFECT DATA & VISUAL INDICATORS
# ============================================

## Status indicator container (circles above enemy head)
var _status_container: Node3D = null
var _status_nodes: Array = []  # [{node: Node3D, ...}]
const MAX_VISIBLE_STATUS: int = 5

## Returns a list of active status effects as dictionaries.
## Each: { "name": String, "color": Color, "stacks": int }
func get_active_effects() -> Array[Dictionary]:
	var effects: Array[Dictionary] = []

	if taunt_tempo > 0:
		effects.append({"name": "Taunt", "color": Color(1.0, 0.6, 0.0), "stacks": taunt_tempo})
	if fear_tempo > 0:
		effects.append({"name": "Fear", "color": Color(0.75, 0.55, 0.95), "stacks": fear_tempo})
	if tree_tempo > 0:
		effects.append({"name": "Tree", "color": Color(0.3, 0.7, 0.3), "stacks": tree_tempo})
	elif cupid_golden or cupid_lead:
		effects.append({"name": "Cupid", "color": Color(1.0, 0.75, 0.8), "stacks": (1 if cupid_golden else 0) + (1 if cupid_lead else 0)})
	if zone_weakened and weaken_stacks <= 0:
		effects.append({"name": "Weaken", "color": Color(0.8, 0.5, 0.9), "stacks": 1})
	if wear_down_tempo > 0:
		var wd_stacks = attack_reduction if attack_reduction > 0 else wear_down_tempo
		effects.append({"name": "Wear Down", "color": Color(0.9, 0.6, 0.3), "stacks": wd_stacks})
	if slow_stacks > 0:
		effects.append({"name": "Slow", "color": Color(0.4, 0.6, 1.0), "stacks": slow_stacks})
	if tripped_tempo > 0:
		effects.append({"name": "Tripped", "color": Color(0.5, 0.7, 1.0), "stacks": tripped_tempo})
	if cursed_tempo > 0:
		effects.append({"name": "Cursed", "color": Color(0.3, 0.0, 0.3), "stacks": cursed_tempo})
	if is_disarmed and disarmed_tempo > 0:
		effects.append({"name": "Disarm", "color": Color(0.8, 0.3, 0.3), "stacks": disarmed_tempo})
	if is_marked and marked_tempo > 0:
		effects.append({"name": "Marked", "color": Color(1.0, 0.2, 0.2), "stacks": marked_tempo})
	if is_silenced and silenced_tempo > 0:
		effects.append({"name": "Silenced", "color": Color(0.7, 0.3, 0.9), "stacks": silenced_tempo})
	if choke_dot_stacks > 0:
		effects.append({"name": "Choke", "color": Color(0.5, 0.7, 0.4), "stacks": choke_dot_stacks})
	if is_exposed:
		effects.append({"name": "Exposed", "color": Color(1.0, 1.0, 0.3), "stacks": 1})
	if is_stunned and stun_tempo > 0:
		effects.append({"name": "Stun", "color": Color(1.0, 1.0, 0.0), "stacks": stun_tempo})
	if polymorph_tempo > 0:
		effects.append({"name": "Polymorph", "color": Color(1.0, 0.6, 0.8), "stacks": polymorph_tempo})
	if is_frozen and frozen_tempo > 0:
		effects.append({"name": "Frozen", "color": Color(0.5, 0.8, 1.0), "stacks": frozen_tempo})
	if burn_stacks > 0:
		effects.append({"name": "Burn", "color": Color(1.0, 0.5, 0.0), "stacks": burn_stacks})
	if cold_stacks > 0:
		effects.append({"name": "Cold", "color": Color(0.4, 0.7, 1.0), "stacks": cold_stacks})
	if poison_stacks > 0:
		effects.append({"name": "Poison", "color": Color(0.2, 0.8, 0.2), "stacks": poison_stacks})
	if shock_stacks > 0:
		effects.append({"name": "Shock", "color": Color(1.0, 1.0, 0.3), "stacks": shock_stacks})
	if bleed_stacks > 0:
		effects.append({"name": "Bleed", "color": Color(0.85, 0.15, 0.2), "stacks": bleed_stacks})
	if narashimha_tempo > 0:
		effects.append({"name": "Narashimha", "color": Color(0.35, 0.0, 0.4), "stacks": narashimha_tempo})
	if vulnerable_stacks > 0:
		effects.append({"name": "Vulnerable", "color": Color(1.0, 0.6, 0.2), "stacks": vulnerable_stacks})
	if weaken_stacks > 0:
		effects.append({"name": "Weaken", "color": Color(0.5, 0.5, 0.8), "stacks": weaken_stacks})
	if rooted_tempo > 0:
		effects.append({"name": "Rooted", "color": Color(0.4, 0.3, 0.15), "stacks": rooted_tempo})
	if disarmed_attacks > 0:
		effects.append({"name": "Disarmed", "color": Color(0.8, 0.3, 0.3), "stacks": disarmed_attacks})
	if gravestone_provider.is_valid():
		var standing: int = int(gravestone_provider.call())
		if standing > 0:
			effects.append({"name": "Gravebound", "color": Color(0.55, 0.85, 0.6), "stacks": standing})
	if door_sealed_tempo > 0:
		effects.append({"name": "Sealed", "color": Color(0.9, 0.35, 0.3), "stacks": door_sealed_tempo})
	if _brace_charges > 0:
		effects.append({"name": "Brace", "color": Color(0.5, 0.5, 0.8), "stacks": _brace_charges})
	if enemy_thorns > 0:
		effects.append({"name": "Thorns", "color": Color(0.8, 0.4, 0.8), "stacks": enemy_thorns})
	elif enemy_type == EnemyType.SEWER_CROC and current_armor > 0:
		# sheet: "While the sewer cobra has armor, they have 5 thorns" — a
		# standing 5, gone the moment it is exposed.
		effects.append({"name": "Thorns", "color": Color(0.8, 0.4, 0.8), "stacks": COBRA_THORNS})
	if strengthen_stacks > 0 and enemy_type in [EnemyType.CERBERUS, EnemyType.SPIRIT_COLLECTOR]:
		effects.append({"name": "Strengthen", "color": Color(1.0, 0.5, 0.3), "stacks": strengthen_stacks})

	return effects

## Slowed: every movement action burns one stack; the debuff ends at zero.
func _consume_slow_stack() -> void:
	slow_stacks = max(0, slow_stacks - 1)
	if slow_stacks == 0:
		print("[%s] Slow worn off, movement restored" % enemy_name)
		debuff_expired.emit(self, "slow")
	_update_status_indicators()

func _update_status_indicators() -> void:
	## Renders colored circles above the enemy's head for active buffs/debuffs.
	## Each circle has a small number showing stacks, positioned at the bottom-right.
	## Caps at MAX_VISIBLE_STATUS on the battlefield; shows "+" if more exist.
	if not is_instance_valid(self):
		return

	# Create the container on first use
	if not _status_container:
		_status_container = Node3D.new()
		_status_container.position = Vector3(0, 0.5, _status_z)
		add_child(_status_container)

	# Remove old nodes
	for entry in _status_nodes:
		if is_instance_valid(entry["node"]):
			entry["node"].queue_free()
	_status_nodes.clear()

	var effects = get_active_effects()
	if effects.is_empty():
		return

	var show_count = min(effects.size(), MAX_VISIBLE_STATUS)
	var has_overflow = effects.size() > MAX_VISIBLE_STATUS
	var total_slots = show_count + (1 if has_overflow else 0)

	var circle_size: float = 0.08
	var spacing: float = 0.2
	var start_x: float = -(total_slots - 1) * spacing / 2.0

	for i in range(show_count):
		var eff = effects[i]
		var node = _create_status_circle(eff["name"], eff["color"], eff["stacks"], circle_size)
		node.position = Vector3(start_x + i * spacing, 0, 0)
		_status_container.add_child(node)
		_status_nodes.append({"node": node, "name": eff["name"]})

	# Overflow indicator "+"
	if has_overflow:
		var plus_label = Label3D.new()
		plus_label.text = "+"
		plus_label.font_size = 20
		plus_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		plus_label.modulate = Color(1, 1, 1)
		plus_label.position = Vector3(start_x + show_count * spacing, 0, 0)
		_status_container.add_child(plus_label)
		_status_nodes.append({"node": plus_label})

## The status circles as hover targets: world position + effect name.
func get_status_hover_targets() -> Array:
	var out: Array = []
	for entry in _status_nodes:
		var n = entry.get("node")
		if entry.get("name", "") != "" and n and is_instance_valid(n):
			out.append({"pos": n.global_position, "name": entry["name"]})
	return out

## Hover text for one status circle: what it does and what is left, read
## live off the enemy's own counters.
func get_effect_tooltip(eff_name: String) -> Dictionary:
	var desc := ""
	var remaining := ""
	var color := Color.WHITE
	for eff in get_active_effects():
		if eff["name"] == eff_name:
			color = eff["color"]
			break
	match eff_name:
		"Sealed":
			desc = "Hell's Door has sealed itself: no damage gets through until the seal fades. It seals at 75%, 50% and 33% health."
			remaining = "Remaining: %d tempo" % door_sealed_tempo
		"Brace":
			desc = "Guardian of Death: the next hits deal 30% less. Gained whenever he, a foe or an ally within 8 squares first drops below half health."
			remaining = "Hits left: %d" % _brace_charges
		"Thorns":
			desc = "Roar's thorns: every direct hit on him costs the attacker this much; one thorn is spent per hit."
			remaining = "Thorns: %d" % enemy_thorns
		"Strengthen":
			if enemy_type == EnemyType.SPIRIT_COLLECTOR:
				desc = "Released souls: +5 damage to every Strike and Collect Soul each time a 'Release Soul' is played. It does not fade."
			else:
				desc = "Deathyard Dog: +15 damage every time a foe heals within 5 squares of him. It does not fade."
			remaining = "Bonus damage: %d" % strengthen_stacks
		"Gravebound":
			desc = "Regenerates 1 health every cycle for each gravestone still standing. It never fades — only breaking the stones lowers it."
			remaining = "Standing gravestones: %d" % int(gravestone_provider.call()) if gravestone_provider.is_valid() else ""
		"Taunt":
			desc = "Must attack whoever taunted it."
			remaining = "Remaining: %d tempo" % taunt_tempo
		"Fear":
			desc = "Flees away from the source of its fear."
			remaining = "Remaining: %d tempo" % fear_tempo
		"Tree":
			desc = "Turned into a tree: cannot act; regrows 3 health on each of its first 3 tempo."
			remaining = "Remaining: %d tempo" % tree_tempo
		"Cupid":
			desc = "Struck by a Cupid arrow. Carrying both the Golden and Lead marks turns it into a tree."
			remaining = "Marks: %d of 2" % ((1 if cupid_golden else 0) + (1 if cupid_lead else 0))
		"Weaken":
			desc = "Deals 30% less damage; each attack burns a stack."
			remaining = ("Stacks: %d" % weaken_stacks) if weaken_stacks > 0 else "While inside the zone"
		"Wear Down":
			desc = "Its attacks deal %d less damage." % attack_reduction
			remaining = "Remaining: %d tempo" % wear_down_tempo
		"Slow":
			desc = "Movement costs 3 tempo per tile instead of 1; each tile moved burns a stack."
			remaining = "Stacks: %d" % slow_stacks
		"Cursed":
			desc = "Deals 20% less damage and takes 20% of its own damage."
			remaining = "Remaining: %d tempo" % cursed_tempo
		"Disarm":
			desc = "Cannot attack."
			remaining = "Remaining: %d tempo" % disarmed_tempo
		"Disarmed":
			desc = "Its next attacks are skipped."
			remaining = "Attacks skipped: %d" % disarmed_attacks
		"Marked":
			desc = "Takes extra damage from your attacks."
			remaining = "Remaining: %d tempo" % marked_tempo
		"Silenced":
			desc = "Cannot cast spells."
			remaining = "Remaining: %d tempo" % silenced_tempo
		"Choke":
			desc = "Takes %d damage at the end of each cycle." % choke_dot_damage
			remaining = "Ticks left: %d" % choke_dot_stacks
		"Exposed":
			desc = "Its armor was broken through — a hit got past it."
			remaining = "Until it gains armor again"
		"Stun":
			desc = "Cannot take any actions."
			remaining = "Remaining: %d tempo" % stun_tempo
		"Polymorph":
			desc = "A pig: it can only walk and make basic melee attacks."
			remaining = "Remaining: %d tempo" % polymorph_tempo
		"Frozen":
			desc = "Cannot act at all."
			remaining = "Remaining: %d tempo" % frozen_tempo
		"Burn":
			desc = "Burn damage doubles each cycle (1, 2, 4, 8...); attacking while burning also triggers the current burn damage."
			remaining = "Stacks: %d" % burn_stacks
		"Cold":
			desc = "At 5 stacks it becomes Frozen for 1 cycle."
			remaining = "Stacks: %d of 5" % cold_stacks
		"Poison":
			desc = "Takes %d damage per cycle, loses 1 poison each cycle." % poison_stacks
			remaining = "Stacks: %d" % poison_stacks
		"Shock":
			desc = "Arcs %d damage to itself and nearby enemies each cycle, loses 1 per cycle." % shock_stacks
			remaining = "Stacks: %d" % shock_stacks
		"Bleed":
			desc = "Takes damage per tile moved; each damage removes a stack."
			remaining = "Stacks: %d" % bleed_stacks
		"Narashimha":
			desc = "Its healing is capped by the Mane of Narashimha."
			remaining = "Remaining: %d tempo" % narashimha_tempo
		"Vulnerable":
			desc = "Takes 30% more damage on the next hits; each hit burns a stack."
			remaining = "Stacks: %d" % vulnerable_stacks
		"Rooted":
			desc = "Cannot move."
			remaining = "Remaining: %d tempo" % rooted_tempo
		_:
			desc = ""
			remaining = ""
	return {"desc": desc, "remaining": remaining, "color": color}

func _create_status_circle(eff_name: String, color: Color, stacks: int, radius: float) -> Node3D:
	## A small colored circle above the enemy's head with the effect's glyph on
	## it and a stack count. A small full sphere reads as a round dot from any
	## camera angle (no billboard edge-on issue).
	var root = Node3D.new()

	# Small round dot (unshaded so it reads as a flat coloured circle).
	var dot = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	dot.mesh = sphere
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.25)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.render_priority = 20
	dot.material_override = mat
	root.add_child(dot)

	# Glyph on top, sized to sit inside the small circle.
	var tex = StatusIcons.get_icon(eff_name)
	if tex:
		var sp = Sprite3D.new()
		sp.texture = tex
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.shaded = false
		sp.no_depth_test = true
		sp.render_priority = 21
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sp.pixel_size = (radius * 1.7) / float(maxi(tex.get_width(), 1))
		sp.position = Vector3(0, 0, radius + 0.005)
		root.add_child(sp)

	# Stack count (small, bottom-right)
	if stacks > 1:
		var label = Label3D.new()
		label.text = str(stacks)
		label.font_size = 22
		label.pixel_size = 0.005
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.render_priority = 22
		label.modulate = Color(1, 1, 1)
		label.outline_modulate = Color(0, 0, 0)
		label.outline_size = 6
		label.position = Vector3(radius * 0.9, -radius * 0.9, radius + 0.01)
		root.add_child(label)

	return root
#endregion
