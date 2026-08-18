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
signal attacked_player(enemy: Enemy)
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
	RING_WRAITH }

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
var max_armor: int = 0
var current_armor: int = 0
var is_exposed: bool = false          # True once armor has been broken to 0
var last_player_hit_damage: int = 0   # Raw damage of the player's most recent hit (for on-expose passives)
var bonus_damage_next_hit: int = 0    # Applied on the next take_damage call, then cleared
var target: Node3D = null
var is_moving: bool = false
var target_position: Vector3
var _move_path: Array[Vector3] = []  # Remaining tile-center waypoints for the current move
var is_dead: bool = false

var grid_manager: GridManager
var dungeon_manager = null  # Set by main.gd for elevation lookups
var ground_y_provider: Callable = Callable()  # Set by main.gd: world_pos -> desired ground Y
var blocked_tiles: Array[Vector2i] = []  # Set by main.gd for barricade obstacles
var pillar_tiles: Array[Vector2i] = []   # Set by main.gd for rise pillars (traps enemy on top)
var occupied_tiles: Array[Vector2i] = [] # Set by main.gd: tiles occupied by other enemies

# Armor Break: set by card.execute() before attack, cleared after
var armor_break_incoming: bool = false

# Status effects applied by player cards (duration in tempo cycles, 1 cycle = 5 global tempo)
var taunt_target: Node3D = null
var taunt_tempo: int = 0       # Remaining tempo cycles for taunt
var attack_reduction: int = 0
var wear_down_tempo: int = 0   # Remaining tempo cycles for wear down
# Slowed (reworked): a flat -1 tile on every movement; slow_stacks counts how
# many movements it affects, one consumed per move. Stacks accumulate freely
# (Sword of Theseus ramps them) — no timed expiry.
var slow_stacks: int = 0
var is_disarmed: bool = false   # Cannot attack when disarmed
var disarmed_tempo: int = 0    # Remaining tempo cycles for disarm
var is_marked: bool = false    # Takes extra damage from player attacks
var marked_tempo: int = 0      # Remaining tempo for mark
const MARKED_BONUS_DAMAGE := 3  # Flat bonus the player's attacks gain vs a marked target
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
var bleed_stacks: int = 0      # Bleed: take X damage per tile moved, lose 1 per cycle
var vulnerable_stacks: int = 0   # Vulnerable: next hit from the player deals +30%; 1 stack consumed per hit
var weaken_stacks: int = 0       # Weaken: this enemy deals -30% damage; 1 stack consumed per attack
var rooted_tempo: int = 0        # Rooted (Gravity Gauntlets): cannot move, can still attack/cast
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
var tree_regen_ticks: int = 0    # Tree form: heals 5 on each of its first 3 tempo
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
var attacks_slow: bool = false                     # Ice Mage: attacks apply Slowed
var attack_burn: int = 0                           # Fire Mage: burn stacks applied on hit
var attack_shock: int = 0                          # Spark Mage: shock stacks applied on hit
var attack_blind_chance: float = 0.0               # Giant Hawk: chance to Blind on hit
var _beaver_followup: bool = false                 # Giant Beaver: chomp queues a Tail Whip
var _hook_charged: bool = true                     # Infected Hunter: starts with a hook prepared
var _drops_to_all_fours: bool = false              # Large Bear: posture change below 20% HP (visual)
var hydra_heal_unlocked: bool = false

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

## Currently chosen action. The enemy commits to this action and waits for tempo.
var chosen_action: Dictionary = {}

## Sword Breaker: tempo added to this enemy's NEXT melee attack, spent when that
## attack finally lands. Everything an enemy does from arm's length counts as a
## melee attack except the actions named here — repositioning, fleeing, healing,
## and the ranged/utility casts.
const NON_MELEE_ACTIONS := {
	"move": true, "hydra_move": true, "goblin_move": true, "scurry": true,
	"scurry_away": true, "get_into_range": true, "flee": true, "vanish": true,
	"hydra_heal": true, "treant_heal": true, "sear_wounds": true,
	"collect_soul": true, "summon_skeleton": true, "fire_wall": true,
	"shoot": true, "ember": true, "dark_bolt": true, "frost_bolt": true,
	"fire_bolt": true, "spark_bolt": true, "sludge_spit": true, "web": true,
	"hook": true, "breath_swarm": true, "screech": true, "gust": true,
}
var next_melee_tempo_tax: int = 0

## Armored Troll passive: accumulator for regeneration (heals 2 HP every 6 global tempo).
var regen_accumulator: int = 0

# ============================================
# TEMPO BAR VISUALS
# ============================================

var _tempo_bar_bg: MeshInstance3D
var _tempo_bar_fg: MeshInstance3D
var _action_label: Label3D
var _tempo_bar_width: float = 0.85

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
			attack_damage = 2
			move_distance = 1.0
			xp_reward = 5
			_set_mesh_color(Color(0.5, 0.35, 0.2))  # Brown

		EnemyType.SKELETON:
			enemy_name = "Skeleton"
			max_health = 18
			max_armor = 10
			attack_damage = 5
			move_distance = 1.0
			xp_reward = 5
			_set_mesh_color(Color(0.85, 0.85, 0.75))  # Bone white

		EnemyType.ARMORED_TROLL:
			enemy_name = "Armored Troll"
			max_health = 45
			max_armor = 30
			attack_damage = 4
			move_distance = 1.0
			xp_reward = 8
			_set_mesh_color(Color(0.2, 0.4, 0.15))  # Dark green

		EnemyType.ARCHER_RAT:
			enemy_name = "Archer Rat"
			max_health = 5
			max_armor = 0
			attack_damage = 1
			attack_range = 4.0  # Ranged attacker
			move_distance = 2.0  # Moves 2 tiles when repositioning
			xp_reward = 4
			_set_mesh_color(Color(0.6, 0.4, 0.25))  # Light brown

		EnemyType.HYDRA:
			enemy_name = "Hydra"
			max_health = 30
			attack_damage = 4         # +accumulated strength
			attack_range = 1.5        # Melee
			move_distance = 3.0       # Moves 3 spaces
			aggro_range = 12.0
			xp_reward = 15
			_set_mesh_color(Color(0.2, 0.55, 0.35))  # Scaled green

		EnemyType.FIRE_GOBLIN_SOLDIER:
			enemy_name = "Fire Goblin Soldier"
			max_health = 4
			attack_damage = 1
			attack_range = 1.5        # Range 0 — must be adjacent
			move_distance = 4.0       # Moves 4 spaces
			xp_reward = 4
			_set_mesh_color(Color(0.85, 0.35, 0.15))  # Ember orange

		EnemyType.FIRE_GOBLIN_MAGE:
			enemy_name = "Fire Goblin Mage"
			max_health = 6
			attack_damage = 6         # Ember damage
			attack_range = 4.0
			move_distance = 2.0
			xp_reward = 6
			_set_mesh_color(Color(0.9, 0.45, 0.2))

		EnemyType.FIRE_GOBLIN_SHAMAN:
			enemy_name = "Fire Goblin Shaman"
			max_health = 8
			attack_damage = 4         # Fire wall damage
			attack_range = 5.0
			move_distance = 2.0
			xp_reward = 8
			_set_mesh_color(Color(0.95, 0.55, 0.25))

		# ===================== FOREST ACT =====================
		EnemyType.GIANT_BEAVER:
			enemy_name = "Giant Beaver"
			max_health = 50
			attack_damage = 6         # Chomp damage; Tail Whip deals 4
			attack_range = 1.5
			move_distance = 3.0       # 3 spaces / 6 tempo
			xp_reward = 12
			_set_mesh_color(Color(0.45, 0.30, 0.18))

		EnemyType.MINI_BEAR:
			enemy_name = "Mini Bear"
			max_health = 10
			attack_damage = 2
			attack_range = 1.5
			move_distance = 5.0       # 5 spaces / 5 tempo
			xp_reward = 4
			_set_mesh_color(Color(0.40, 0.26, 0.16))

		EnemyType.LARGE_BEAR:
			enemy_name = "Large Bear"
			max_health = 75
			attack_damage = 8
			attack_range = 1.5
			move_distance = 6.0       # 6 spaces / 7 tempo
			xp_reward = 16
			bleed_on_attack = 3
			_set_mesh_color(Color(0.32, 0.20, 0.12))

		EnemyType.WOLF:
			enemy_name = "Wolf"
			max_health = 18
			attack_damage = 4
			attack_range = 1.5
			move_distance = 4.0       # 4 spaces / 3 tempo
			xp_reward = 6
			_set_mesh_color(Color(0.45, 0.45, 0.48))

		EnemyType.COYOTE:
			enemy_name = "Coyote"
			max_health = 5
			attack_damage = 1
			attack_range = 1.5
			move_distance = 4.0       # 4 spaces / 3 tempo
			xp_reward = 2
			_set_mesh_color(Color(0.62, 0.52, 0.36))

		EnemyType.BUGBEAR:
			enemy_name = "Bugbear"
			max_health = 25
			attack_damage = 3
			attack_range = 1.5
			move_distance = 6.0       # 6 spaces / 4 tempo
			xp_reward = 9
			_set_mesh_color(Color(0.36, 0.30, 0.22))

		EnemyType.INFECTED_HUNTER:
			enemy_name = "Infected Hunter"
			max_health = 21
			attack_damage = 4         # AOE swipe in front
			attack_range = 1.5
			move_distance = 2.0       # 2 spaces / 3 tempo
			aggro_range = 12.0        # so it can hook from range 7
			xp_reward = 9
			_set_mesh_color(Color(0.40, 0.50, 0.30))

		EnemyType.GIANT_HAWK:
			enemy_name = "Giant Hawk"
			max_health = 15
			attack_damage = 6
			attack_range = 2.0
			move_distance = 8.0       # 8 spaces / 3 tempo
			xp_reward = 7
			immune_to_high_ground = true
			attack_blind_chance = 0.15
			_set_mesh_color(Color(0.50, 0.38, 0.24))

		EnemyType.TREANT:
			enemy_name = "Treant"
			max_health = 75
			attack_damage = 10
			attack_range = 1.5
			move_distance = 9.0       # 9 spaces / 10 tempo
			aggro_range = 12.0
			xp_reward = 16
			damage_type = DamageTypes.Type.EARTH
			_set_mesh_color(Color(0.32, 0.42, 0.20))

		EnemyType.ICE_MAGE:
			enemy_name = "Ice Mage"
			max_health = 35
			attack_damage = 3
			attack_range = 3.0
			move_distance = 3.0       # 3 spaces / 5 tempo
			xp_reward = 9
			damage_type = DamageTypes.Type.ICE
			attacks_slow = true
			_set_mesh_color(Color(0.55, 0.75, 0.95))

		EnemyType.FIRE_MAGE:
			enemy_name = "Fire Mage"
			max_health = 25
			attack_damage = 4
			attack_range = 2.0
			move_distance = 2.0       # 2 spaces / 3 tempo
			xp_reward = 8
			damage_type = DamageTypes.Type.FIRE
			attack_burn = 1
			_set_mesh_color(Color(0.90, 0.35, 0.20))

		EnemyType.SPARK_MAGE:
			enemy_name = "Spark Mage"
			max_health = 10
			attack_damage = 1
			attack_range = 6.0
			move_distance = 2.0       # 2 spaces / 3 tempo
			xp_reward = 6
			damage_type = DamageTypes.Type.LIGHTNING
			attack_shock = 1
			_set_mesh_color(Color(0.85, 0.85, 0.40))

		EnemyType.AIR_MAGE:
			enemy_name = "Air Mage"
			max_health = 20
			attack_damage = 2
			attack_range = 8.0
			move_distance = 6.0       # 6 spaces / 3 tempo
			xp_reward = 8
			damage_type = DamageTypes.Type.WIND
			_set_mesh_color(Color(0.70, 0.85, 0.80))

		EnemyType.EARTH_MAGE:
			enemy_name = "Earth Mage"
			max_health = 50
			attack_damage = 6
			attack_range = 1.5
			move_distance = 5.0       # 5 spaces / 5 tempo
			xp_reward = 10
			damage_type = DamageTypes.Type.EARTH
			armor_per_hit = 3
			_set_mesh_color(Color(0.45, 0.35, 0.25))

		# ===================== GRAVEYARD ACT =====================
		EnemyType.ZOMBIE:
			enemy_name = "Zombie"
			max_health = 10
			attack_damage = 3
			attack_range = 1.5
			move_distance = 3.0
			xp_reward = 4
			_set_mesh_color(Color(0.49, 0.57, 0.40))

		EnemyType.WEREWOLF:
			enemy_name = "Werewolf"
			max_health = 25
			attack_damage = 7         # +3 vs armor (armour-piercing)
			attack_range = 1.5
			move_distance = 3.0
			aggro_range = 12.0
			xp_reward = 12
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
			max_health = 20
			attack_damage = 8         # Life steal on health damage
			attack_range = 1.5
			move_distance = 5.0
			xp_reward = 14
			_set_mesh_color(Color(0.16, 0.15, 0.20))

		EnemyType.NECROMANCER:
			enemy_name = "Necromancer"
			max_health = 45
			attack_damage = 2
			attack_range = 10.0
			move_distance = 8.0
			aggro_range = 14.0
			xp_reward = 16
			_set_mesh_color(Color(0.12, 0.11, 0.16))

		EnemyType.BONE_DRAGON:
			enemy_name = "Bone Dragon"
			max_health = 50
			attack_damage = 10
			attack_range = 1.5
			move_distance = 5.0
			aggro_range = 14.0
			xp_reward = 25
			_set_mesh_color(Color(0.91, 0.89, 0.84))

		EnemyType.SPIRIT_COLLECTOR:
			enemy_name = "Spirit Collector"
			max_health = 30
			attack_damage = 5
			attack_range = 1.5
			move_distance = 3.0
			xp_reward = 12
			_set_mesh_color(Color(0.60, 0.52, 0.33))

		EnemyType.GRAVE_TITAN:
			enemy_name = "Grave Titan"
			max_health = 50
			max_armor = 15
			attack_damage = 12
			attack_range = 1.5
			move_distance = 4.0
			aggro_range = 12.0
			xp_reward = 20
			_set_mesh_color(Color(0.84, 0.85, 0.87))

		EnemyType.CRYPT_CRAWLER:
			enemy_name = "Crypt Crawler"
			max_health = 15
			attack_damage = 5
			attack_range = 1.5
			move_distance = 3.0
			xp_reward = 9
			_set_mesh_color(Color(0.20, 0.17, 0.22))

		EnemyType.SCREECHER:
			enemy_name = "Screecher"
			max_health = 10
			attack_damage = 2
			attack_range = 1.5
			move_distance = 4.0       # 4 spaces / 2 tempo while invisible
			xp_reward = 6
			_set_mesh_color(Color(0.07, 0.07, 0.10))

		EnemyType.CONSUMED:
			enemy_name = "The Consumed"
			max_health = 18
			attack_damage = 5
			attack_range = 1.5
			move_distance = 5.0       # 5 spaces / 3 tempo
			xp_reward = 10
			_set_mesh_color(Color(0.35, 0.29, 0.28))

		# ===================== SEWER ACT =====================
		EnemyType.SLUDGE:
			enemy_name = "Sludge Being"
			max_health = 8
			attack_damage = 3
			attack_range = 6.0        # Can spit at range
			move_distance = 3.0
			xp_reward = 5
			_set_mesh_color(Color(0.25, 0.63, 0.36))

		EnemyType.PIPE_CRAWLER:
			enemy_name = "Pipe Crawler"
			max_health = 15
			attack_damage = 4
			attack_range = 1.5
			move_distance = 2.0
			xp_reward = 7
			_set_mesh_color(Color(0.48, 0.54, 0.43))

		EnemyType.SEWER_CROC:
			enemy_name = "Sewer Crocodile"
			max_health = 25
			max_armor = 15
			attack_damage = 10
			attack_range = 1.5
			move_distance = 2.0
			aggro_range = 12.0
			xp_reward = 14
			_set_mesh_color(Color(0.27, 0.38, 0.23))

		EnemyType.RAT_KING:
			enemy_name = "Rat King"
			max_health = 15
			attack_damage = 4
			attack_range = 1.5
			move_distance = 2.0
			xp_reward = 8
			_set_mesh_color(Color(0.5, 0.35, 0.2))

		EnemyType.SWARM:
			enemy_name = "Swarm"
			max_health = 8
			attack_damage = 3
			attack_range = 1.5
			move_distance = 8.0       # 8 spaces / 3 tempo — very fast
			xp_reward = 5
			_set_mesh_color(Color(0.18, 0.16, 0.13))

	current_health = max_health
	current_armor = max_armor
	update_health_display()
	update_name_display()
	update_outline()
	_setup_actions()
	_setup_tempo_bar()
	_setup_armor_bar()
	_setup_sprite()

	if grid_manager:
		position = grid_manager.snap_to_grid(position)
		target_position = position

func _set_mesh_color(color: Color) -> void:
	if mesh:
		var mat = mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			mat.albedo_color = color

var figure_kind: String = ""  # EnemyFigure kind this enemy renders as ("" = coloured box)

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
		_:
			return  # Generic tiers (Minion/Elite/Boss) keep their coloured box

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
	## Define available actions per enemy species.
	match enemy_type:
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
				{"name": "smash", "tempo_cost": 6},
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
				{"name": "fire_wall",   "tempo_cost": 8},
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
				{"name": "hook",   "tempo_cost": 8},
				{"name": "cleave", "tempo_cost": 3},
				{"name": "move",   "tempo_cost": 3},
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
				{"name": "croc_bite", "tempo_cost": 6},
				{"name": "move",      "tempo_cost": 5},
			]
		EnemyType.RAT_KING:
			actions = [
				{"name": "bite", "tempo_cost": 2},
				{"name": "move", "tempo_cost": 2},
			]
		EnemyType.SWARM:
			actions = [
				{"name": "attack", "tempo_cost": 2},
				{"name": "move",   "tempo_cost": 3},
			]

# ============================================
# COMPENDIUM DATA
# ============================================

static func get_all_enemy_data() -> Array:
	## Returns compendium-friendly data for every enemy type.
	## Single source of truth — compendium reads from here.
	var _type_display := {
		EnemyType.MINION: "Minion",
		EnemyType.ELITE: "Elite",
		EnemyType.BOSS: "Boss",
		EnemyType.WERERAT: "Minion",
		EnemyType.SKELETON: "Minion",
		EnemyType.ARMORED_TROLL: "Elite",
		EnemyType.ARCHER_RAT: "Minion",
		EnemyType.HYDRA: "Elite",
		EnemyType.FIRE_GOBLIN_SOLDIER: "Minion",
		EnemyType.FIRE_GOBLIN_MAGE: "Minion",
		EnemyType.FIRE_GOBLIN_SHAMAN: "Elite",
		EnemyType.GIANT_BEAVER: "Elite",
		EnemyType.MINI_BEAR: "Minion",
		EnemyType.LARGE_BEAR: "Elite",
		EnemyType.WOLF: "Minion",
		EnemyType.COYOTE: "Minion",
		EnemyType.BUGBEAR: "Minion",
		EnemyType.INFECTED_HUNTER: "Elite",
		EnemyType.GIANT_HAWK: "Minion",
		EnemyType.TREANT: "Elite",
		EnemyType.ICE_MAGE: "Minion",
		EnemyType.FIRE_MAGE: "Minion",
		EnemyType.SPARK_MAGE: "Minion",
		EnemyType.AIR_MAGE: "Minion",
		EnemyType.EARTH_MAGE: "Elite",
		EnemyType.ZOMBIE: "Minion",
		EnemyType.WEREWOLF: "Elite",
		EnemyType.WERERABBIT: "Minion",
		EnemyType.VAMPIRE: "Elite",
		EnemyType.NECROMANCER: "Elite",
		EnemyType.BONE_DRAGON: "Boss",
		EnemyType.SPIRIT_COLLECTOR: "Elite",
		EnemyType.GRAVE_TITAN: "Boss",
		EnemyType.CRYPT_CRAWLER: "Minion",
		EnemyType.SCREECHER: "Minion",
		EnemyType.CONSUMED: "Elite",
		EnemyType.SLUDGE: "Minion",
		EnemyType.PIPE_CRAWLER: "Minion",
		EnemyType.SEWER_CROC: "Elite",
		EnemyType.RAT_KING: "Elite",
		EnemyType.SWARM: "Minion",
		EnemyType.WEREGOAT: "Elite", EnemyType.WYVERN: "Elite", EnemyType.ROC: "Boss",
		EnemyType.ICE_TROLL: "Elite", EnemyType.SNOW_WRAITH: "Minion", EnemyType.GRANITE_COLOSSUS: "Boss",
		EnemyType.WHITE_MANTICORE: "Elite", EnemyType.SABERTOOTH: "Minion",
		EnemyType.CERBERUS: "Boss", EnemyType.SUCCUBUS: "Elite", EnemyType.DEMON: "Elite",
		EnemyType.IFRIT: "Elite", EnemyType.MIND_EATER: "Elite", EnemyType.SPECTER: "Minion",
		EnemyType.MAGMA_SPIDER: "Elite", EnemyType.PIT_FIEND: "Boss", EnemyType.ASH_HARPY: "Minion",
		EnemyType.INFLAMED_MINOTAUR: "Elite",
		EnemyType.CHERUB: "Minion", EnemyType.DJINN: "Elite", EnemyType.CORRUPTED_ARCHANGEL: "Boss",
	}
	var _stats := {
		EnemyType.MINION: {"name": "Minion", "health": 25, "armor": 0, "damage": 3, "xp": 5},
		EnemyType.ELITE: {"name": "Elite", "health": 80, "armor": 0, "damage": 6, "xp": 10},
		EnemyType.BOSS: {"name": "Boss", "health": 200, "armor": 0, "damage": 10, "xp": 25},
		EnemyType.WERERAT: {"name": "Wererat", "health": 8, "armor": 0, "damage": 2, "xp": 5},
		EnemyType.SKELETON: {"name": "Skeleton", "health": 18, "armor": 10, "damage": 5, "xp": 5},
		EnemyType.ARMORED_TROLL: {"name": "Armored Troll", "health": 45, "armor": 30, "damage": 4, "xp": 8},
		EnemyType.ARCHER_RAT: {"name": "Archer Rat", "health": 5, "armor": 0, "damage": 1, "xp": 4},
		EnemyType.HYDRA: {"name": "Hydra", "health": 30, "armor": 0, "damage": 4, "xp": 15},
		EnemyType.FIRE_GOBLIN_SOLDIER: {"name": "Fire Goblin Soldier", "health": 4, "armor": 0, "damage": 1, "xp": 4},
		EnemyType.FIRE_GOBLIN_MAGE: {"name": "Fire Goblin Mage", "health": 6, "armor": 0, "damage": 6, "xp": 6},
		EnemyType.FIRE_GOBLIN_SHAMAN: {"name": "Fire Goblin Shaman", "health": 8, "armor": 0, "damage": 4, "xp": 8},
		EnemyType.GIANT_BEAVER: {"name": "Giant Beaver", "health": 50, "armor": 0, "damage": 6, "xp": 12},
		EnemyType.MINI_BEAR: {"name": "Mini Bear", "health": 10, "armor": 0, "damage": 2, "xp": 4},
		EnemyType.LARGE_BEAR: {"name": "Large Bear", "health": 75, "armor": 0, "damage": 8, "xp": 16},
		EnemyType.WOLF: {"name": "Wolf", "health": 18, "armor": 0, "damage": 4, "xp": 6},
		EnemyType.COYOTE: {"name": "Coyote", "health": 5, "armor": 0, "damage": 1, "xp": 2},
		EnemyType.BUGBEAR: {"name": "Bugbear", "health": 25, "armor": 0, "damage": 3, "xp": 9},
		EnemyType.INFECTED_HUNTER: {"name": "Infected Hunter", "health": 21, "armor": 0, "damage": 4, "xp": 9},
		EnemyType.GIANT_HAWK: {"name": "Giant Hawk", "health": 15, "armor": 0, "damage": 6, "xp": 7},
		EnemyType.TREANT: {"name": "Treant", "health": 75, "armor": 0, "damage": 10, "xp": 16},
		EnemyType.ICE_MAGE: {"name": "Ice Mage", "health": 35, "armor": 0, "damage": 3, "xp": 9},
		EnemyType.FIRE_MAGE: {"name": "Fire Mage", "health": 25, "armor": 0, "damage": 4, "xp": 8},
		EnemyType.SPARK_MAGE: {"name": "Spark Mage", "health": 10, "armor": 0, "damage": 1, "xp": 6},
		EnemyType.AIR_MAGE: {"name": "Air Mage", "health": 20, "armor": 0, "damage": 2, "xp": 8},
		EnemyType.EARTH_MAGE: {"name": "Earth Mage", "health": 50, "armor": 0, "damage": 6, "xp": 10},
		EnemyType.ZOMBIE: {"name": "Zombie", "health": 10, "armor": 0, "damage": 3, "xp": 4},
		EnemyType.WEREWOLF: {"name": "Werewolf", "health": 25, "armor": 0, "damage": 7, "xp": 12},
		EnemyType.WERERABBIT: {"name": "Wererabbit", "health": 25, "armor": 0, "damage": 0, "xp": 8},
		EnemyType.VAMPIRE: {"name": "Vampire", "health": 20, "armor": 0, "damage": 8, "xp": 14},
		EnemyType.NECROMANCER: {"name": "Necromancer", "health": 45, "armor": 0, "damage": 2, "xp": 16},
		EnemyType.BONE_DRAGON: {"name": "Bone Dragon", "health": 50, "armor": 0, "damage": 10, "xp": 25},
		EnemyType.SPIRIT_COLLECTOR: {"name": "Spirit Collector", "health": 30, "armor": 0, "damage": 5, "xp": 12},
		EnemyType.GRAVE_TITAN: {"name": "Grave Titan", "health": 50, "armor": 15, "damage": 12, "xp": 20},
		EnemyType.CRYPT_CRAWLER: {"name": "Crypt Crawler", "health": 15, "armor": 0, "damage": 5, "xp": 9},
		EnemyType.SCREECHER: {"name": "Screecher", "health": 10, "armor": 0, "damage": 2, "xp": 6},
		EnemyType.CONSUMED: {"name": "The Consumed", "health": 18, "armor": 0, "damage": 5, "xp": 10},
		EnemyType.SLUDGE: {"name": "Sludge Being", "health": 8, "armor": 0, "damage": 3, "xp": 5},
		EnemyType.PIPE_CRAWLER: {"name": "Pipe Crawler", "health": 15, "armor": 0, "damage": 4, "xp": 7},
		EnemyType.SEWER_CROC: {"name": "Sewer Crocodile", "health": 25, "armor": 15, "damage": 10, "xp": 14},
		EnemyType.RAT_KING: {"name": "Rat King", "health": 15, "armor": 0, "damage": 4, "xp": 8},
		EnemyType.SWARM: {"name": "Swarm", "health": 8, "armor": 0, "damage": 3, "xp": 5},
		EnemyType.WEREGOAT: {"name": "Weregoat", "health": 0, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.WYVERN: {"name": "Wyvern", "health": 0, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.ROC: {"name": "Roc", "health": 0, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.ICE_TROLL: {"name": "Ice Troll", "health": 0, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.SNOW_WRAITH: {"name": "Snow Wraith", "health": 0, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.GRANITE_COLOSSUS: {"name": "Granite Colossus", "health": 0, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.WHITE_MANTICORE: {"name": "White Manticore", "health": 0, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.SABERTOOTH: {"name": "Sabertooth Tiger", "health": 0, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.CERBERUS: {"name": "Cerberus", "health": 0, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.SUCCUBUS: {"name": "Succubus", "health": 0, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.DEMON: {"name": "Demon", "health": 0, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.IFRIT: {"name": "Ifrit", "health": 0, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.MIND_EATER: {"name": "Mind Eater", "health": 0, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.SPECTER: {"name": "Specter", "health": 0, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.MAGMA_SPIDER: {"name": "Magma Spider", "health": 0, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.PIT_FIEND: {"name": "Pit Fiend", "health": 0, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.ASH_HARPY: {"name": "Ash Harpy", "health": 0, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.INFLAMED_MINOTAUR: {"name": "Inflamed Minotaur", "health": 0, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.CHERUB: {"name": "Cherub", "health": 0, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.DJINN: {"name": "Djinn", "health": 0, "armor": 0, "damage": 0, "xp": 0},
		EnemyType.CORRUPTED_ARCHANGEL: {"name": "Corrupted Archangel", "health": 0, "armor": 0, "damage": 0, "xp": 0},
	}
	var _actions := {
		EnemyType.MINION: [{"name": "Attack", "tempo": 3}, {"name": "Move", "tempo": 5}],
		EnemyType.ELITE: [{"name": "Attack", "tempo": 4}, {"name": "Move", "tempo": 6}],
		EnemyType.BOSS: [{"name": "Attack", "tempo": 5}, {"name": "Move", "tempo": 8}],
		EnemyType.WERERAT: [{"name": "Move", "tempo": 2}, {"name": "Bite", "tempo": 2}, {"name": "Scurry", "tempo": 4}],
		EnemyType.SKELETON: [{"name": "Move", "tempo": 5}, {"name": "Attack", "tempo": 4}],
		EnemyType.ARMORED_TROLL: [{"name": "Move", "tempo": 4}, {"name": "Kick", "tempo": 3}, {"name": "Smash", "tempo": 6}],
		EnemyType.ARCHER_RAT: [{"name": "Shoot", "tempo": 5}, {"name": "Scurry Away", "tempo": 2}, {"name": "Get Into Range", "tempo": 2}],
		EnemyType.HYDRA: [{"name": "Strike", "tempo": 8}, {"name": "Move", "tempo": 6}, {"name": "Heal", "tempo": 5}],
		EnemyType.FIRE_GOBLIN_SOLDIER: [{"name": "Attack", "tempo": 3}, {"name": "Move", "tempo": 2}],
		EnemyType.FIRE_GOBLIN_MAGE: [{"name": "Ember", "tempo": 4}, {"name": "Move", "tempo": 3}],
		EnemyType.FIRE_GOBLIN_SHAMAN: [{"name": "Fire Wall", "tempo": 8}, {"name": "Sear Wounds", "tempo": 6}, {"name": "Move", "tempo": 3}],
		EnemyType.GIANT_BEAVER: [{"name": "Chomp", "tempo": 4}, {"name": "Tail Whip", "tempo": 2}, {"name": "Move", "tempo": 6}],
		EnemyType.MINI_BEAR: [{"name": "Attack", "tempo": 3}, {"name": "Move", "tempo": 5}],
		EnemyType.LARGE_BEAR: [{"name": "Maul", "tempo": 4}, {"name": "Move", "tempo": 7}],
		EnemyType.WOLF: [{"name": "Bite", "tempo": 5}, {"name": "Move", "tempo": 3}],
		EnemyType.COYOTE: [{"name": "Nip", "tempo": 4}, {"name": "Move", "tempo": 3}],
		EnemyType.BUGBEAR: [{"name": "Strike", "tempo": 5}, {"name": "Move", "tempo": 4}],
		EnemyType.INFECTED_HUNTER: [{"name": "Hook", "tempo": 8}, {"name": "Cleave", "tempo": 3}, {"name": "Move", "tempo": 3}],
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
		EnemyType.VAMPIRE: [{"name": "Bite", "tempo": 5}, {"name": "Move", "tempo": 5}],
		EnemyType.NECROMANCER: [{"name": "Bolt", "tempo": 5}, {"name": "Summon", "tempo": 8}, {"name": "Move", "tempo": 6}],
		EnemyType.BONE_DRAGON: [{"name": "Bite", "tempo": 5}, {"name": "Breath", "tempo": 6}, {"name": "Move", "tempo": 5}],
		EnemyType.SPIRIT_COLLECTOR: [{"name": "Strike", "tempo": 3}, {"name": "Collect Soul", "tempo": 8}, {"name": "Move", "tempo": 4}],
		EnemyType.GRAVE_TITAN: [{"name": "Smash", "tempo": 8}, {"name": "Boulder Roll", "tempo": 5}, {"name": "Move", "tempo": 8}],
		EnemyType.CRYPT_CRAWLER: [{"name": "Bite", "tempo": 3}, {"name": "Web", "tempo": 3}, {"name": "Move", "tempo": 4}],
		EnemyType.SCREECHER: [{"name": "Screech", "tempo": 5}, {"name": "Drift", "tempo": 2}],
		EnemyType.CONSUMED: [{"name": "Attack", "tempo": 5}, {"name": "Move", "tempo": 3}],
		EnemyType.SLUDGE: [{"name": "Melee", "tempo": 5}, {"name": "Spit", "tempo": 6}, {"name": "Move", "tempo": 5}],
		EnemyType.PIPE_CRAWLER: [{"name": "Claw", "tempo": 5}, {"name": "Move", "tempo": 2}],
		EnemyType.SEWER_CROC: [{"name": "Bite", "tempo": 6}, {"name": "Move", "tempo": 5}],
		EnemyType.RAT_KING: [{"name": "Bite", "tempo": 2}, {"name": "Move", "tempo": 2}],
		EnemyType.SWARM: [{"name": "Attack", "tempo": 2}, {"name": "Move", "tempo": 3}],
		EnemyType.WEREGOAT: [], EnemyType.WYVERN: [], EnemyType.ROC: [],
		EnemyType.ICE_TROLL: [], EnemyType.SNOW_WRAITH: [], EnemyType.GRANITE_COLOSSUS: [],
		EnemyType.WHITE_MANTICORE: [], EnemyType.SABERTOOTH: [],
		EnemyType.CERBERUS: [], EnemyType.SUCCUBUS: [], EnemyType.DEMON: [],
		EnemyType.IFRIT: [], EnemyType.MIND_EATER: [], EnemyType.SPECTER: [],
		EnemyType.MAGMA_SPIDER: [], EnemyType.PIT_FIEND: [], EnemyType.ASH_HARPY: [],
		EnemyType.INFLAMED_MINOTAUR: [],
		EnemyType.CHERUB: [], EnemyType.DJINN: [], EnemyType.CORRUPTED_ARCHANGEL: [],
	}
	var _specials := {
		EnemyType.MINION: "Basic enemy.\nAt range ≤1: Attacks.\nOtherwise: Moves toward player.",
		EnemyType.ELITE: "Stronger than minions.\nAt range ≤1: Attacks.\nOtherwise: Moves toward player.",
		EnemyType.BOSS: "High health and damage.\nAt range ≤1: Attacks.\nOtherwise: Moves toward player.",
		EnemyType.WERERAT: "Fast and evasive (8 HP, 2 dmg).\nAt range ≤1: Bites.\nAt range ≥6: Scurries (dashes away).\nOtherwise: Moves toward player.",
		EnemyType.SKELETON: "Has armor that must be broken.\nAt range ≤1: Attacks.\nOtherwise: Moves toward player.",
		EnemyType.ARMORED_TROLL: "Regenerates 2 HP every 6 global tempo.\nAt range ≤1: 60% Smash / 40% Kick.\nOtherwise: Moves toward player.",
		EnemyType.ARCHER_RAT: "Ranged attacker (range 4).\nAt range ≤2: Scurries 5 tiles away.\nAt range 3-4: Shoots for 1 damage.\nAt range >4: Moves 2 tiles closer.",
		EnemyType.HYDRA: "Grows stronger with every hit she takes: +2 strength per hit. On the 4th hit she also gains +20 max HP and unlocks Heal.\nStrike (8 tempo): 4 + strength damage.\nMove (6 tempo): 3 spaces.\nHeal (5 tempo): heals to full (after the 4th hit).",
		EnemyType.FIRE_GOBLIN_SOLDIER: "Melee rusher (range 0).\nAttack (3 tempo): 1 damage.\nMove (2 tempo): 4 spaces.",
		EnemyType.FIRE_GOBLIN_MAGE: "Ranged caster (range 4).\nEmber (4 tempo): 6 damage + 1 burn.\nMove (3 tempo): 2 spaces.",
		EnemyType.FIRE_GOBLIN_SHAMAN: "Support caster (range 5).\nFire Wall (8 tempo): raises a wall; if the player walks into it they take 4 damage + 3 burn.\nSear Wounds (6 tempo): 2 damage to all allies (can kill), then heals survivors 4.\nMove (3 tempo): 2 spaces.",
		EnemyType.GIANT_BEAVER: "Chomp (4 tempo): 6 damage, stuns 3 tempo. Then Tail Whip (2 tempo later): 4 damage + Vulnerable (15 tempo).\nMove (6 tempo): 3 spaces.",
		EnemyType.MINI_BEAR: "Travels in packs. When a packmate in sight is hurt, gains +1 attack damage.\nAttack (3 tempo): 2 damage.\nMove (5 tempo): 5 spaces.",
		EnemyType.LARGE_BEAR: "Very tanky. Maul applies Bleed (you take damage when you move). Drops to all fours below 20% HP.\nMaul (4 tempo): 8 damage + 3 Bleed.\nMove (7 tempo): 6 spaces.",
		EnemyType.WOLF: "Within 4 tiles of another wolf: +2 HP regen/cycle and +2 attack damage.\nBite (5 tempo): 4 damage.\nMove (3 tempo): 4 spaces.",
		EnemyType.COYOTE: "Fragile nuisance.\nNip (4 tempo): 1 damage.\nMove (3 tempo): 4 spaces.",
		EnemyType.BUGBEAR: "First Strike: if it hits you before you have hit it, +5 damage.\nStrike (5 tempo): 3 damage.\nMove (4 tempo): 6 spaces.",
		EnemyType.INFECTED_HUNTER: "Hook (range 7, 8 tempo, starts charged): pulls you to it over 2 tempo.\nCleave (3 tempo): 4 damage in front.\nMove (3 tempo): 2 spaces.",
		EnemyType.GIANT_HAWK: "Flying — ignores your high-ground bonus.\nSwoop (4 tempo): 6 damage, 15% to Blind for 5 tempo.\nMove (3 tempo): 8 spaces.",
		EnemyType.TREANT: "Heals 5 HP every 5 tempo, +2 per 10% HP below 60%.\nSlam (10 tempo): 10 earth damage.\nRoot (8 tempo): pins you for 8 tempo (can attack, cannot move).\nMove (10 tempo): 9 spaces.",
		EnemyType.ICE_MAGE: "Attacks Slow your movement.\nFrost Bolt (range 3, 3 tempo): 3 ice damage + Slow.\nMove (5 tempo): 3 spaces.",
		EnemyType.FIRE_MAGE: "Attacks apply 1 Burn.\nFire Bolt (range 2, 3 tempo): 4 fire damage + 1 Burn.\nMove (3 tempo): 2 spaces.",
		EnemyType.SPARK_MAGE: "Attacks apply 1 Shock.\nSpark (range 6, 2 tempo): 1 lightning damage + 1 Shock.\nMove (3 tempo): 2 spaces.",
		EnemyType.AIR_MAGE: "Long-range caster.\nGust (range 8, 5 tempo): 2 wind damage.\nMove (3 tempo): 6 spaces.",
		EnemyType.EARTH_MAGE: "Gains 3 armor every time it is hit.\nBoulder (melee, 6 tempo): 6 earth damage.\nMove (5 tempo): 5 spaces.",
		EnemyType.ZOMBIE: "Slow, beefy undead.\nAt range ≤1: Attacks (3 dmg, 6 tempo).\nOtherwise: shambles toward player (3 spaces / 8 tempo).",
		EnemyType.WEREWOLF: "Bear-sized grey beast with armor-piercing claws.\nClaw (5 tempo): 7 damage; deals +3 extra to armor.\nMove (3 tempo): 3 spaces.",
		EnemyType.WERERABBIT: "Loot monster — does not attack.\nFlees for 3 cycles, then Vanishes in a puff of smoke.\nMove (1 tempo): 2 spaces.",
		EnemyType.VAMPIRE: "Victorian aristocrat with life steal.\nBite (5 tempo): 8 damage; heals for 100% of damage dealt to health (not armor).\nMove (5 tempo): 5 spaces.",
		EnemyType.NECROMANCER: "Hooded caster (range 10) who raises the dead.\nBolt (5 tempo): 2 damage.\nSummon (8 tempo): raises undead. After 5 of its summons die, it raises a Bone Dragon.\nMove (6 tempo): 8 spaces.",
		EnemyType.BONE_DRAGON: "Skeletal wyrm. Summoned by the Necromancer, but also roams freely.\nBite (5 tempo): 10 damage.\nBreath Swarm (6 tempo): 8 damage in a line (6 spaces); spawns an insect swarm for each unit hit.\nMove (5 tempo): 5 spaces.",
		EnemyType.SPIRIT_COLLECTOR: "Lantern-bearer with a soul cage on its back.\nStrike (3 tempo): 5 damage.\nCollect Soul (8 tempo): 2 damage; adds a 'Release Soul' card to your hand (deals 1 damage per tempo until played, then is erased).",
		EnemyType.GRAVE_TITAN: "Yeti-like brute (15 armor) hauling a boulder.\nSmash (8 tempo): 12 damage in front.\nBoulder Roll (range 3, 5 tempo): rolls the boulder for 8 damage.\nMove (8 tempo): 4 spaces.",
		EnemyType.CRYPT_CRAWLER: "Large spider. After 3 consecutive attacks it webs you.\nBite (3 tempo): 5 damage.\nWeb: adds a 'Paralysis' card to your hand — you cannot move until it is played (other actions are fine), then it is erased.\nMove (4 tempo): 3 spaces.",
		EnemyType.SCREECHER: "Soul-creature — invisible (a black void ghost) until it strikes.\nScreech (5 tempo): 2 damage; it becomes visible for 3 tempo, then fades again.\nDrift: 4 spaces / 2 tempo while invisible (2 spaces / 5 tempo while visible).",
		EnemyType.CONSUMED: "Flesh-and-hatred golem; muscle shows through its lacerations.\nAttack (5 tempo): 5 damage.\nMove (3 tempo): 5 spaces.\nOn death: explodes for 4 damage to everything nearby.",
		# --- Mountains (design mock-ups — stats & moves TBD) ---
		EnemyType.WEREGOAT: "Minotaur-built: human torso and arms, goat head and goat hind legs.\n[Design mock-up — stats & moves TBD.]",
		EnemyType.WYVERN: "A large serpentine flier with talons and wings — no arms.\n[Design mock-up — stats & moves TBD.]",
		EnemyType.ROC: "An enormous bird with huge talons and a white-checkered mane.\n[Design mock-up — stats & moves TBD.]",
		EnemyType.ICE_TROLL: "Bigger than the Armored Troll — taller, with massive hands and feet; no weapon.\n[Design mock-up — stats & moves TBD.]",
		EnemyType.SNOW_WRAITH: "A pale mountain spirit trailing tattered cloth.\n[Design mock-up — stats & moves TBD.]",
		EnemyType.GRANITE_COLOSSUS: "A huge rigid figure of mountain stone that emerges from the rock face — hard to spot before it moves.\n[Design mock-up — stats & moves TBD.]",
		EnemyType.WHITE_MANTICORE: "A manticore with a snow-leopard body, bat wings and a spiked tail.\n[Design mock-up — stats & moves TBD.]",
		EnemyType.SABERTOOTH: "A sabertooth tiger.\n[Design mock-up — stats & moves TBD.]",
		# --- Underworld (design mock-ups — stats & moves TBD) ---
		EnemyType.CERBERUS: "Three-headed hound with spiked collars and a chain on the left head.\n[Design mock-up — stats & moves TBD.]",
		EnemyType.SUCCUBUS: "A winged fey: short shorts, sleeveless top, elbow gloves, long boots and small horns.\n[Design mock-up — stats & moves TBD.]",
		EnemyType.DEMON: "A red, thorned demon wielding a dagger and a trident.\n[Design mock-up — stats & moves TBD.]",
		EnemyType.IFRIT: "A muscular bipedal fire-hound, hunched, with long near-ground arms.\n[Design mock-up — stats & moves TBD.]",
		EnemyType.MIND_EATER: "A gaunt, hunched flesh-horror with long raking claws.\n[Design mock-up — stats & moves TBD.]",
		EnemyType.SPECTER: "A dark shadow-form of a humanoid.\n[Design mock-up — stats & moves TBD.]",
		EnemyType.MAGMA_SPIDER: "A large tarantula in red, orange and black with glowing seams.\n[Design mock-up — stats & moves TBD.]",
		EnemyType.PIT_FIEND: "A larger, regal demon with a barbed tail and a great whip.\n[Design mock-up — stats & moves TBD.]",
		EnemyType.ASH_HARPY: "A harpy seemingly risen from and made of ash.\n[Design mock-up — stats & moves TBD.]",
		EnemyType.INFLAMED_MINOTAUR: "A smouldering minotaur with a fiery axe; leaves fire in its wake.\n[Design mock-up — stats & moves TBD.]",
		# --- Heavens (design mock-ups — stats & moves TBD) ---
		EnemyType.CHERUB: "An adult cupid — winged archer with a bow.\n[Design mock-up — stats & moves TBD.]",
		EnemyType.DJINN: "A blue genie with bracelets, a black ponytail and a red necklace.\n[Design mock-up — stats & moves TBD.]",
		EnemyType.CORRUPTED_ARCHANGEL: "Black eyes and long black hair, white wings and robes, wielding a black two-handed sword.\n[Design mock-up — stats & moves TBD.]",
		EnemyType.SLUDGE: "Gelatinous ooze that strikes up close or at range.\nMelee (5 tempo): 3 damage.\nSpit (range 6, 6 tempo): 3 damage.\nMove (5 tempo): 3 spaces.",
		EnemyType.PIPE_CRAWLER: "Many-limbed crawler scuttling on all fours.\nClaw (5 tempo): 4 damage; 15% chance to disarm you.\nMove (2 tempo): 2 spaces.",
		EnemyType.SEWER_CROC: "Armoured ambush predator (15 armor).\nBite (6 tempo): 10 damage.\nMove (5 tempo): 2 spaces.",
		EnemyType.RAT_KING: "A giant crowned rat that leads the swarm.\nBite (2 tempo): 4 damage.\nMove (2 tempo): 2 spaces.",
		EnemyType.SWARM: "A single unit made of countless biting bugs.\nAttack (2 tempo): 3 damage.\nMove (3 tempo): 8 spaces — very fast.",
	}

	var result: Array = []
	for enemy_type in EnemyType.values():
		var s = _stats[enemy_type]
		result.append({
			"name": s["name"],
			"type": _type_display[enemy_type],
			"health": s["health"],
			"armor": s["armor"],
			"damage": s["damage"],
			"xp": s["xp"],
			"actions": _actions[enemy_type],
			"special": _specials[enemy_type],
		})
	return result

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
	_tempo_bar_bg.position = Vector3(0, 1.15, 0)
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
	_tempo_bar_fg.position = Vector3(0, 1.15, 0.001)  # Slightly in front
	_tempo_bar_fg.visible = false
	add_child(_tempo_bar_fg)

	# Action label (above tempo bar) — sized and outlined to stay readable
	# from a zoomed-out camera, like the name label.
	_action_label = Label3D.new()
	_action_label.position = Vector3(0, 1.29, 0)
	_action_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_action_label.font_size = 26  # 2x supersampled -> 13px on screen
	_action_label.outline_size = 6
	_action_label.outline_modulate = Color(0, 0, 0, 1.0)
	_action_label.pixel_size = 0.00107
	_action_label.fixed_size = true  # constant screen size — readable at any zoom
	_action_label.no_depth_test = true
	_action_label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR  # no mip smear
	_action_label.render_priority = 20
	_action_label.modulate = Color(1.0, 0.85, 0.0)  # Yellow text
	_action_label.text = ""
	add_child(_action_label)

	# Move name label up to make room for the tempo bar + larger action text
	if name_label:
		name_label.position.y = 1.5

const _ARMOR_BAR_PIXEL_WIDTH: int = 200
const _ARMOR_BAR_PIXEL_HEIGHT: int = 24

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
	_armor_bar_sprite.position = Vector3(0, 0.75, 0)
	add_child(_armor_bar_sprite)

	# Armor value label rendered on top of the sprite
	_armor_label = Label3D.new()
	_armor_label.position = Vector3(0, 0.75, 0.001)
	_armor_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_armor_label.font_size = 14
	_armor_label.modulate = Color(0.95, 0.95, 0.95)
	_armor_label.no_depth_test = true
	_armor_label.render_priority = 20
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

# ============================================
# TEMPO-DRIVEN ACTION HANDLING
# ============================================

## Called by EnemySpawner whenever global tempo advances.
func on_tempo_advanced(amount: int, player_node: Node3D) -> void:
	if is_dead:
		return

	action_tempo_counter += amount
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

	# Armored Troll passive: regenerate 2 HP every 6 global tempo
	if enemy_type == EnemyType.ARMORED_TROLL:
		regen_accumulator += amount
		while regen_accumulator >= 6:
			regen_accumulator -= 6
			_regenerate(2)

	# Treant passive: heals 5 HP every 5 tempo, +2 per 10% HP below 60%.
	if enemy_type == EnemyType.TREANT:
		regen_accumulator += amount
		while regen_accumulator >= 5:
			regen_accumulator -= 5
			_regenerate(_treant_heal_amount())

	# Wolf pack: within 4 tiles of another wolf, regen 2 HP every 5 tempo.
	if enemy_type == EnemyType.WOLF and _wolf_aura_active():
		regen_accumulator += amount
		while regen_accumulator >= 5:
			regen_accumulator -= 5
			_regenerate(2)

	# Tick status effect durations once per tempo cycle (every 5 global tempo)
	while _cycle_accumulator >= 5:
		_cycle_accumulator -= 5
		_tick_status_durations()

	_check_and_fire_actions(player_node)
	_update_tempo_bar()

func _tick_status_durations() -> void:
	if taunt_tempo > 0:
		taunt_tempo -= 1
		if taunt_tempo <= 0:
			taunt_target = null
			print("[%s] Taunt expired" % enemy_name)

	if fear_tempo > 0:
		fear_tempo -= 1
		if fear_tempo <= 0:
			fear_source = null
			print("[%s] Fear expired" % enemy_name)

	if wear_down_tempo > 0:
		wear_down_tempo -= 1
		if wear_down_tempo <= 0:
			attack_reduction = 0
			print("[%s] Wear Down expired, attack restored" % enemy_name)


	if disarmed_tempo > 0:
		disarmed_tempo -= 1
		if disarmed_tempo <= 0:
			is_disarmed = false
			print("[%s] Disarm expired, can attack again" % enemy_name)
			debuff_expired.emit(self, "disarmed")

	if marked_tempo > 0:
		marked_tempo -= 1
		if marked_tempo <= 0:
			is_marked = false
			print("[%s] Mark expired" % enemy_name)
			debuff_expired.emit(self, "marked")

	if silenced_tempo > 0:
		silenced_tempo -= 1
		if silenced_tempo <= 0:
			is_silenced = false
			print("[%s] Silence expired, can cast again" % enemy_name)
			debuff_expired.emit(self, "silenced")

	# Choke: deal the caster's half-auto-attack damage per cycle, lose 1 stack
	if choke_dot_stacks > 0:
		take_damage(choke_dot_damage, false)
		print("[%s] Choke deals %d damage (%d stacks left)" % [enemy_name, choke_dot_damage, choke_dot_stacks - 1])
		choke_dot_stacks -= 1
		if choke_dot_stacks <= 0:
			print("[%s] Choke expired" % enemy_name)
			debuff_expired.emit(self, "choke")

	if frozen_tempo > 0:
		frozen_tempo -= 1
		if frozen_tempo <= 0:
			is_frozen = false
			print("[%s] Frozen expired, can act again" % enemy_name)
			debuff_expired.emit(self, "frozen")

	if stun_tempo > 0:
		stun_tempo -= 1
		if stun_tempo <= 0:
			is_stunned = false
			print("[%s] Stun expired, can act again" % enemy_name)
			debuff_expired.emit(self, "stun")

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
		poison_stacks -= 1
		if poison_stacks <= 0:
			print("[%s] Poison expired" % enemy_name)
			debuff_expired.emit(self, "poison")

	# Bleed: no cycle damage (it hurts per tile moved) — clots 1 stack per cycle
	if bleed_stacks > 0:
		bleed_stacks -= 1
		if bleed_stacks <= 0:
			print("[%s] Bleed expired" % enemy_name)
			debuff_expired.emit(self, "bleed")

	# Rooted: the hold releases one cycle at a time
	if rooted_tempo > 0:
		rooted_tempo -= 1
		if rooted_tempo <= 0:
			print("[%s] Root released" % enemy_name)
			debuff_expired.emit(self, "root")

	# Narashimha: the heal-cap window counts down one cycle at a time
	if narashimha_tempo > 0:
		narashimha_tempo -= 1
		if narashimha_tempo <= 0:
			narashimha_heal_cap = -1
			print("[%s] Narashimha wound closes" % enemy_name)
			debuff_expired.emit(self, "narashimha")

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

func _check_and_fire_actions(player_node: Node3D) -> void:
	if not player_node:
		return

	# Skip actions if stunned or frozen
	if is_stunned:
		print("[%s] Stunned - cannot act!" % enemy_name)
		return
	if is_frozen:
		print("[%s] Frozen - cannot act!" % enemy_name)
		return
	if tree_tempo > 0:
		return  # A tree does not act.

	# Skip actions if player is invisible (ring wraiths see through everything)
	if not ignores_invisibility and player_node.has_method("get_buff_manager"):
		var p_buff_mgr = player_node.get_buff_manager()
		if p_buff_mgr and p_buff_mgr.is_invisible():
			return

	# Skip actions if this enemy is blind to this player (Serial Killer)
	if player_node in invisible_to_players:
		return

	# Choose action if we don't have one yet
	if chosen_action.is_empty():
		_choose_action(player_node)

	if chosen_action.is_empty():
		return

	# Fire when enough tempo has accumulated for the chosen action. Sword
	# Breaker's tax makes exactly one melee swing arrive late.
	var action_cost: int = chosen_action["tempo_cost"]
	var taxed: bool = next_melee_tempo_tax > 0 and not NON_MELEE_ACTIONS.has(chosen_action["name"])
	if taxed:
		action_cost += next_melee_tempo_tax
	if action_tempo_counter >= action_cost:
		if taxed:
			print("[%s] Sword Breaker: swing delayed %d tempo" % [enemy_name, next_melee_tempo_tax])
			next_melee_tempo_tax = 0
		var move_target = player_node
		if taunt_target and is_instance_valid(taunt_target):
			move_target = taunt_target

		_execute_action(chosen_action["name"], move_target)
		action_tempo_counter = 0
		chosen_action = {}
		# Immediately choose next action so the bar shows what's coming
		_choose_action(player_node)

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
			_choose_melee_action(distance, "maul")
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
			_choose_melee_action(distance, "werewolf_claw")
		EnemyType.WERERABBIT:
			chosen_action = _get_action("flee")  # Loot monster — only flees
		EnemyType.VAMPIRE:
			_choose_melee_action(distance, "vampire_bite")
		EnemyType.NECROMANCER:
			_choose_ranged_action(distance, "dark_bolt")
		EnemyType.BONE_DRAGON:
			_choose_melee_action(distance, "dragon_bite")
		EnemyType.SPIRIT_COLLECTOR:
			_choose_melee_action(distance, "collector_swing")
		EnemyType.GRAVE_TITAN:
			_choose_melee_action(distance, "titan_smash")
		EnemyType.CRYPT_CRAWLER:
			_choose_melee_action(distance, "crawler_bite")
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
			_choose_melee_action(distance, "bite")
		EnemyType.SWARM:
			_choose_melee_action(distance, "attack")
		_:
			_choose_legacy_action(distance)

	if not chosen_action.is_empty():
		print("[%s] Chose action: %s (cost: %d tempo)" % [enemy_name, chosen_action["name"], chosen_action["tempo_cost"]])

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
	if distance <= 2:
		# Too close! Scurry away to get distance
		chosen_action = _get_action("scurry_away")
	elif distance > 4:
		# Out of range - move closer
		chosen_action = _get_action("get_into_range")
	else:
		# In range (3-4 tiles) - shoot!
		chosen_action = _get_action("shoot")

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
	# Hook reaches out to 7 tiles (and starts charged); cleave is the melee swipe.
	if _hook_charged and distance >= 2 and distance <= 7:
		chosen_action = _get_action("hook")
	elif distance <= 1:
		chosen_action = _get_action("cleave")
	else:
		chosen_action = _get_action("move")

func _choose_treant_action(distance: int) -> void:
	if distance <= 1:
		chosen_action = _get_action("treant_slam") if randf() < 0.6 else _get_action("root")
	elif distance <= 4:
		chosen_action = _get_action("root")
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
		"wolf_bite":
			return _try_wolf_bite(move_target)
		"coyote_nip":
			return _try_elemental(move_target, 1, "Nip")
		"bugbear_strike":
			return _try_bugbear_strike(move_target)
		"cleave":
			return _try_elemental(move_target, attack_damage, "Cleave")
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
		# ----- Graveyard act (special mechanics are placeholders for now) -----
		"werewolf_claw":
			return _try_elemental(move_target, attack_damage, "Claw")
		"vampire_bite":
			return _try_elemental(move_target, attack_damage, "Life Steal")
		"flee":
			return _try_move(move_target)
		"vanish":
			turn_completed.emit(); return true
		"dark_bolt":
			return _try_elemental(move_target, attack_damage, "Dark Bolt")
		"summon_skeleton":
			turn_completed.emit(); return true
		"dragon_bite":
			return _try_elemental(move_target, attack_damage, "Bite")
		"breath_swarm":
			return _try_elemental(move_target, attack_damage, "Breath")
		"collector_swing":
			return _try_elemental(move_target, attack_damage, "Strike")
		"collect_soul":
			return _try_elemental(move_target, attack_damage, "Collect Soul")
		"titan_smash":
			return _try_elemental(move_target, attack_damage, "Smash")
		"boulder_roll":
			return _try_elemental(move_target, attack_damage, "Boulder Roll")
		"crawler_bite":
			return _try_elemental(move_target, attack_damage, "Bite")
		"web":
			return _try_elemental(move_target, attack_damage, "Web")
		"screech":
			return _try_elemental(move_target, attack_damage, "Screech")
		# ----- Sewer act -----
		"sludge_melee":
			return _try_elemental(move_target, attack_damage, "Sludge")
		"sludge_spit":
			return _try_elemental(move_target, attack_damage, "Spit")
		"pipe_attack":
			return _try_elemental(move_target, attack_damage, "Claw")
		"croc_bite":
			return _try_elemental(move_target, attack_damage, "Bite")
		_:
			push_warning("[%s] Unknown action: %s" % [enemy_name, action_name])
			return false

func _try_hydra_attack(target_node: Node3D) -> bool:
	if is_disarmed:
		return _try_move(target_node)
	var diff = target_node.position - position
	var flat_dist = Vector3(diff.x, 0, diff.z).length()
	if flat_dist <= attack_range:
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
	var diff = target_node.position - position
	var flat_dist = Vector3(diff.x, 0, diff.z).length()
	if flat_dist <= attack_range:
		_deal_damage_to_player(target_node, attack_damage, "Strike")
		turn_completed.emit()
		return true
	return _try_move(target_node)

func _try_ember(target_node: Node3D) -> bool:
	## Fire Goblin Mage: ranged ember — damage plus 1 burn.
	if is_disarmed or is_silenced:
		return _try_move(target_node)
	var diff = target_node.position - position
	var flat_dist = Vector3(diff.x, 0, diff.z).length()
	if flat_dist <= attack_range:
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
	var diff = target_node.position - position
	var flat_dist = Vector3(diff.x, 0, diff.z).length()
	if flat_dist > attack_range:
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
	## survivors for 4.
	# Sear Wounds is a cast; silence mutes it and the shaman forfeits the action.
	if is_silenced:
		print("[%s] Silenced — cannot Sear Wounds." % enemy_name)
		turn_completed.emit()
		return true
	var allies = _sibling_enemies()
	for a in allies:
		if is_instance_valid(a):
			a.take_damage(2, false)  # from_player = false: doesn't enrage a Hydra
	for a in allies:
		if is_instance_valid(a) and a.is_alive():
			a._regenerate(4)
	print("[%s] Sears wounds — 2 to all, then heals 4." % enemy_name)
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

# ============================================
# FOREST ACT — ACTIONS & HELPERS
# ============================================

func _in_attack_range(target_node: Node3D) -> bool:
	var diff = target_node.position - position
	return Vector3(diff.x, 0, diff.z).length() <= attack_range

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
	_apply_player_debuff(player_node, Debuff.create(Debuff.DebuffType.BLIND, 50, tempo))
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
		_apply_player_debuff(target_node, Debuff.create_slowed(int(opts["slow"]), 15, enemy_name))
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
		_deal_damage_to_player(target_node, 4, "Tail Whip")
		# Vulnerable: target takes extra damage (≈15 tempo window).
		_apply_player_debuff(target_node, Debuff.create(Debuff.DebuffType.VULNERABLE, 5, 15))
		turn_completed.emit()
		return true
	return _try_move(target_node)

func _try_mini_bear_attack(target_node: Node3D) -> bool:
	return _try_elemental(target_node, attack_damage + pack_attack_bonus, "Swipe")

func _try_maul(target_node: Node3D) -> bool:
	return _try_elemental(target_node, attack_damage, "Maul", {"bleed": bleed_on_attack})

func _try_wolf_bite(target_node: Node3D) -> bool:
	var dmg = attack_damage + (2 if _wolf_aura_active() else 0)
	return _try_elemental(target_node, dmg, "Bite")

func _try_bugbear_strike(target_node: Node3D) -> bool:
	# First Strike: if the player has not hit this bugbear yet, +5 damage.
	var dmg = attack_damage + (5 if hits_taken == 0 else 0)
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

func _try_attack(target_node: Node3D) -> bool:
	if is_disarmed:
		print("[%s] Disarmed - cannot attack!" % enemy_name)
		return _try_move(target_node)
	# Switch Kick: disarmed for a number of ATTACKS, not a duration.
	if disarmed_attacks > 0:
		disarmed_attacks -= 1
		print("[%s] Disarmed for this attack! (%d left)" % [enemy_name, disarmed_attacks])
		return _try_move(target_node)
	var diff = target_node.position - position
	var flat_dist = Vector3(diff.x, 0, diff.z).length()
	if flat_dist <= attack_range:
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
	var diff = target_node.position - position
	var flat_dist = Vector3(diff.x, 0, diff.z).length()
	if flat_dist <= attack_range:
		_deal_damage_to_player(target_node, 3, "Bite")
		turn_completed.emit()
		return true
	return _try_move(target_node)

func _try_scurry(target_node: Node3D) -> bool:
	## Wererat dashes 5 tiles toward the target.
	var tiles = 5
	var effective_tiles = tiles
	if slow_stacks > 0:
		effective_tiles = max(0, tiles - 1)
		_consume_slow_stack()
	_dash_towards_target(target_node.position, effective_tiles)
	print("[%s] Scurries %d tiles toward target!" % [enemy_name, effective_tiles])
	return true

func _try_kick(target_node: Node3D) -> bool:
	if is_disarmed:
		return _try_move(target_node)
	var diff = target_node.position - position
	var flat_dist = Vector3(diff.x, 0, diff.z).length()
	if flat_dist <= attack_range:
		_deal_damage_to_player(target_node, 4, "Kick")
		turn_completed.emit()
		return true
	return _try_move(target_node)

func _try_smash(target_node: Node3D) -> bool:
	if is_disarmed:
		return _try_move(target_node)
	var diff = target_node.position - position
	var flat_dist = Vector3(diff.x, 0, diff.z).length()
	if flat_dist <= attack_range:
		_deal_damage_to_player(target_node, 10, "Smash")
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
	var diff = target_node.position - position
	var flat_dist = Vector3(diff.x, 0, diff.z).length()
	if flat_dist <= attack_range:
		_deal_damage_to_player(target_node, attack_damage, "Arrow Shot")
		turn_completed.emit()
		return true
	# Out of range, try to get closer
	return _try_get_into_range(target_node)

func _try_scurry_away(target_node: Node3D) -> bool:
	## Archer Rat: Run 5 paces away from threat.
	var tiles = 5
	var effective_tiles = tiles
	if slow_stacks > 0:
		effective_tiles = max(0, tiles - 1)
		_consume_slow_stack()

	if grid_manager:
		var threat_cell = grid_manager.world_to_grid(target_node.position)
		_start_path(_build_greedy_path(position, threat_cell, effective_tiles, true))
	else:
		var diff = position - target_node.position
		var direction = Vector3(diff.x, 0, diff.z).normalized()
		if direction.length() < 0.1:
			direction = Vector3(1, 0, 0)
		target_position = position + direction * (effective_tiles * 1.0)
		is_moving = true

	print("[%s] Scurries %d tiles away from threat!" % [enemy_name, effective_tiles])
	return true

func _try_get_into_range(target_node: Node3D) -> bool:
	## Archer Rat: Move 2 tiles toward target to get into shooting range.
	var diff = target_node.position - position
	var flat_dist = Vector3(diff.x, 0, diff.z).length()
	if flat_dist <= attack_range:
		# Already in range, shoot instead
		return _try_shoot(target_node)

	var tiles = 2
	var effective_tiles = tiles
	if slow_stacks > 0:
		effective_tiles = max(0, tiles - 1)
		_consume_slow_stack()

	if grid_manager:
		var player_cell = grid_manager.world_to_grid(target_node.position)
		_start_path(_build_greedy_path(position, player_cell, effective_tiles))
	else:
		var direction = Vector3(diff.x, 0, diff.z).normalized()
		target_position = position + direction * (effective_tiles * 1.0)
		is_moving = true

	print("[%s] Moves %d tiles to get into range!" % [enemy_name, effective_tiles])
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
	# Weaken (Fan Save): -30% damage dealt, one stack consumed per attack.
	if weaken_stacks > 0:
		effective_damage = floori(effective_damage * 0.7)
		weaken_stacks -= 1
		print("[%s] Weakened! -30%% damage (%d stacks left)" % [enemy_name, weaken_stacks])
		_update_status_indicators()
	elif zone_weakened:
		# Territorial Mark: the same -30%, but persistent while inside the
		# zone — no stack to consume, it lifts the moment the enemy leaves.
		effective_damage = floori(effective_damage * 0.7)
		print("[%s] Weakened by the Territorial Mark! -30%% damage" % enemy_name)
	print("[%s] %s for %d damage! (base %d, reduction %d)" % [enemy_name, attack_name, effective_damage, base_damage, attack_reduction])

	# Summon targets (Frankensteins Monster, surfaced Bull Worms) have no player
	# stat pipeline — the hit goes straight through their own take_damage.
	if not player_node.has_method("get_stats") and player_node.has_method("take_damage"):
		if effective_damage > 0:
			player_node.take_damage(effective_damage)
		return

	if player_node.has_method("get_stats"):
		var player_stats_ref = player_node.get_stats()
		# Remember who is striking so counters (Return Cut) know their target.
		if player_stats_ref and "last_attacker" in player_stats_ref:
			player_stats_ref.last_attacker = self
		if player_stats_ref and effective_damage > 0:
			var debuff_mgr = null
			var buff_mgr = null
			if player_node.has_method("get_debuff_manager"):
				debuff_mgr = player_node.get_debuff_manager()
			if player_node.has_method("get_buff_manager"):
				buff_mgr = player_node.get_buff_manager()

			# Check Repelled Block: if armor fully blocks the attack, negate damage and push
			if buff_mgr and buff_mgr.has_buff(Buff.BuffType.REPELLED_BLOCK):
				if player_stats_ref.current_armor >= effective_damage:
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

			player_stats_ref.take_damage(effective_damage, debuff_mgr, buff_mgr, dmg_type)

			if player_node.has_method("get_inventory"):
				var p_inventory = player_node.get_inventory()
				if p_inventory:
					p_inventory.on_damage_taken()

			# Trigger on_attacked passives (thorns, In the Trenches, Phalanx, etc.)
			if player_node.has_method("on_attacked_by"):
				player_node.on_attacked_by(self)
			attacked_player.emit(self)

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

## Dash multiple tiles toward a position in one action.
## Stops at any barricade tile encountered along the path.
func _dash_towards_target(pos: Vector3, tiles: int) -> void:
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

# ============================================
# TEMPO BAR VISUAL UPDATE
# ============================================

func get_action_progress() -> float:
	## 0..1 fill toward this enemy's next action (-1 when no action is chosen).
	## Mirrors the overhead tempo bar; the unit tracker draws the same value.
	if chosen_action.is_empty():
		return -1.0
	var cost = chosen_action.get("tempo_cost", 1)
	return clampf(float(action_tempo_counter) / float(cost), 0.0, 1.0)

func _update_tempo_bar() -> void:
	if not _tempo_bar_bg or not _tempo_bar_fg:
		return

	if chosen_action.is_empty():
		_tempo_bar_bg.visible = false
		_tempo_bar_fg.visible = false
		if _action_label:
			_action_label.text = ""
		return

	_tempo_bar_bg.visible = true
	_tempo_bar_fg.visible = true

	var cost = chosen_action.get("tempo_cost", 1)
	var progress = clampf(float(action_tempo_counter) / float(cost), 0.0, 1.0)
	var current_width = _tempo_bar_width * progress

	var fg_mesh = _tempo_bar_fg.mesh as QuadMesh
	if fg_mesh:
		fg_mesh.size.x = max(0.01, current_width)

	# Offset foreground so the bar fills from left to right
	_tempo_bar_fg.position.x = -(_tempo_bar_width - current_width) / 2.0

	if _action_label:
		_action_label.text = chosen_action.get("name", "").capitalize()

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
			# Bleed: every tile reached tears the wound open
			if bleed_stacks > 0 and not is_dead:
				take_damage(bleed_stacks, false)
				print("[%s] Bleed deals %d damage (moved a tile)" % [enemy_name, bleed_stacks])
			# Advance to the next waypoint if the route has more tiles, so we
			# follow the path around corners instead of stopping short.
			if not _move_path.is_empty():
				target_position = _move_path.pop_front()
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

	move_and_slide()

# ============================================
# MOVEMENT & COMBAT
# ============================================

func set_target(new_target: Node3D) -> void:
	target = new_target

func _build_greedy_path(start_pos: Vector3, goal_cell: Vector2i, tiles: int, away: bool = false) -> Array[Vector3]:
	## Greedy tile-by-tile route toward (or away from) goal_cell, honoring walls
	## and other enemies. Returns the ordered list of tile-center world positions
	## so movement follows the actual path instead of gliding straight through
	## corners/walls. Empty if no step is possible.
	var path: Array[Vector3] = []
	if not grid_manager:
		return path
	var last_cell := grid_manager.world_to_grid(start_pos)
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for _step in range(tiles):
		var best_cell := last_cell
		var best_dist := _manhattan_dist(last_cell, goal_cell)
		for d in dirs:
			var candidate: Vector2i = last_cell + d
			if candidate == goal_cell and not away:
				continue  # Don't step onto the target's tile
			if candidate in blocked_tiles:
				continue  # Walls / structures
			if candidate in occupied_tiles:
				continue  # Other enemies
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

func _start_path(path: Array[Vector3]) -> bool:
	## Begin gliding along the given waypoint list. Returns false if empty.
	if path.is_empty():
		return false
	_move_path = path
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
	var effective_tiles = tiles
	if slow_stacks > 0:
		effective_tiles = max(0, tiles - 1)
		_consume_slow_stack()
	if effective_tiles <= 0:
		print("[%s] Too slowed to move!" % enemy_name)
		return

	if grid_manager:
		# Feared (Cupids lead arrow): run AWAY from the fear source instead.
		if fear_tempo > 0 and fear_source and is_instance_valid(fear_source):
			var flee_cell = grid_manager.world_to_grid(fear_source.position)
			_start_path(_build_greedy_path(position, flee_cell, effective_tiles, true))
			return
		var player_cell = grid_manager.world_to_grid(pos)
		# Follow a tile-by-tile route so we never glide through walls or corners.
		_start_path(_build_greedy_path(position, player_cell, effective_tiles))
	else:
		var diff = pos - position
		var direction = Vector3(diff.x, 0, diff.z).normalized()
		var new_target = position + direction * (effective_tiles * 1.0)
		target_position = new_target
		is_moving = true

func _manhattan_dist(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func attack_player(player_node: Node3D) -> void:
	_deal_damage_to_player(player_node, attack_damage, "Attack")

# ============================================
# TAKING DAMAGE
# ============================================

## Deal damage to this enemy. Armor absorbs first, remainder hits health.
## Set from_player = true when the damage originates from the player's card/attack.
## Returns true if the enemy was just Exposed (armor broken to 0).
func take_damage(amount: int, from_player: bool = false, damage_type: int = DamageTypes.Type.PHYSICAL, ignore_armor: bool = false) -> bool:
	# ignore_armor: skip the armor-absorption chain entirely so the full amount
	# hits health (Neither Man nor Beast "ignoring all resistances and armor").
	if is_dead:
		return false

	# Per-type resistance: percent reduction from damage_resistances (empty for
	# most enemies today — Blue Robe reads this table for its adaptive type).
	# ignore_armor hits bypass resistances too (Neither Man nor Beast).
	if not ignore_armor:
		var type_resist: float = float(damage_resistances.get(damage_type, 0.0))
		if type_resist > 0.0:
			amount = floori(amount * (1.0 - minf(type_resist, 90.0) / 100.0))

	# Remember the raw incoming damage of this hit (before armor math) so
	# on-expose passives like Easy Target can repeat "your damage".
	if from_player:
		last_player_hit_damage = amount

	# Hydra: grows stronger with every hit she takes from the player.
	if enemy_type == EnemyType.HYDRA and from_player:
		hits_taken += 1
		strength += 2
		print("[%s] Enraged by hit %d — strength now %d" % [enemy_name, hits_taken, strength])
		if hits_taken == 4:
			max_health += 20
			current_health += 20
			hydra_heal_unlocked = true
			print("[%s] Grows hardier (+20 max HP) and prepares to heal!" % enemy_name)
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
		amount += MARKED_BONUS_DAMAGE
		print("[%s] Marked: +%d damage!" % [enemy_name, MARKED_BONUS_DAMAGE])

	# Void resistance (Mane of Narashimha aura): resistances lowered, so the
	# player's hits land for extra damage while the enemy is inside the aura.
	if from_player and void_resistance_percent > 0.0:
		amount = floori(amount * (1.0 + void_resistance_percent / 100.0))

	# Vulnerable: the hit lands 30% harder, consuming one stack.
	if from_player and vulnerable_stacks > 0:
		amount = floori(amount * 1.3)
		vulnerable_stacks -= 1
		print("[%s] Vulnerable! +30%% damage (%d stacks left)" % [enemy_name, vulnerable_stacks])
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

	if just_exposed:
		exposed.emit(self)

	if current_health <= 0:
		die()

	return just_exposed

func _alert_mini_bear_pack() -> void:
	## When this mini bear is hurt, packmates within sight gain +1 attack damage.
	for e in _sibling_enemies():
		if e != self and e.enemy_type == EnemyType.MINI_BEAR and e.is_alive():
			if position.distance_to(e.position) <= e.aggro_range:
				e.pack_attack_bonus += 1
				print("[%s] Packmate hurt — attack now +%d" % [e.enemy_name, e.pack_attack_bonus])

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

# ============================================
# STATUS EFFECTS
# ============================================

func apply_taunt(taunter: Node3D, cycles: int) -> void:
	taunt_target = taunter
	taunt_tempo = cycles
	print("[%s] Taunted for %d tempo cycles" % [enemy_name, cycles])
	_update_status_indicators()

func apply_fear(source: Node3D, cycles: int) -> void:
	## Feared (Cupids lead arrow): movement runs AWAY from the source.
	fear_source = source
	fear_tempo = cycles
	print("[%s] Feared for %d tempo cycles" % [enemy_name, cycles])
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
	## 4 tempo as a tree: keeps every buff/debuff, cannot act, and heals 5 on
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

func apply_wear_down(cycles: int) -> void:
	wear_down_tempo = max(wear_down_tempo, cycles)
	print("[%s] Wear Down applied for %d tempo cycles" % [enemy_name, wear_down_tempo])
	_update_status_indicators()

func apply_debuff(debuff_name: String, value: int) -> void:
	# Feral Evocation: while a converted card's play resolves, any of the four
	# slot elements it lands is swapped to the converted color's element.
	if Card.active_element_remap != "" and debuff_name in ["burn", "cold", "shock", "poison"] \
			and debuff_name != Card.active_element_remap:
		print("[%s] Feral Evocation: %s becomes %s" % [enemy_name, debuff_name, Card.active_element_remap])
		debuff_name = Card.active_element_remap
	match debuff_name:
		"stun":
			is_stunned = true
			stun_tempo = max(stun_tempo, value)
			# Reset action tempo counter so stun delays their next action
			action_tempo_counter = 0
			chosen_action = {}
			print("[%s] Stunned for %d tempo cycles!" % [enemy_name, stun_tempo])
		"slow":
			# Slowed stacks freely: every movement is -1 tile and eats a stack.
			slow_stacks += value
			print("[%s] Slowed! -1 movement for the next %d movement(s)" % [enemy_name, slow_stacks])
		"disarmed":
			is_disarmed = true
			disarmed_tempo = value
			print("[%s] Disarmed for %d tempo cycles" % [enemy_name, value])
		"marked":
			is_marked = true
			marked_tempo = value
			print("[%s] Marked for %d tempo cycles" % [enemy_name, value])
		"silenced":
			is_silenced = true
			silenced_tempo = max(silenced_tempo, value)
			# Drop any queued spell so the enemy re-decides now that it's muted
			chosen_action = {}
			print("[%s] Silenced for %d tempo cycles!" % [enemy_name, silenced_tempo])
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
				frozen_tempo = max(frozen_tempo, 1)  # Frozen for 1 tempo cycle
				# Reset action tempo counter so frozen delays their next action
				action_tempo_counter = 0
				chosen_action = {}
				print("[%s] FROZEN! Cold reached 5 stacks!" % enemy_name)
		"poison":
			poison_stacks += value
			print("[%s] Poisoned! Stacks: %d" % [enemy_name, poison_stacks])
		"shock":
			shock_stacks += value
			print("[%s] Shocked! Stacks: %d" % [enemy_name, shock_stacks])
			# Element Pollination: Shock stuns at 5 stacks like Cold freezes,
			# while the Elemental Weaver's maintain is up.
			if Card.element_pollination_active and shock_stacks >= 5:
				shock_stacks = 0
				is_stunned = true
				stun_tempo = max(stun_tempo, 1)  # Stunned for 1 tempo cycle
				action_tempo_counter = 0
				chosen_action = {}
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
		"root":
			# value is the hold in tempo cycles; can attack and cast, cannot move
			rooted_tempo = max(rooted_tempo, value)
			print("[%s] Rooted for %d tempo cycles!" % [enemy_name, rooted_tempo])
		"disarm_attacks":
			disarmed_attacks += value
			print("[%s] Disarmed for %d attack(s)!" % [enemy_name, disarmed_attacks])
		"narashimha":
			# value is the window in tempo cycles (10 tempo = 2 cycles). Applied
			# right after the Neither Man nor Beast hit, so current health IS the
			# ceiling: healing can never bring health back above this point,
			# which is exactly "cannot heal the damage dealt by this card".
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

func apply_stun(tempo_cycles: int = 1) -> void:
	apply_debuff("stun", tempo_cycles)

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
	# Step tile-by-tile, stopping at blocked tiles
	var current_cell = grid_manager.world_to_grid(position)
	var last_valid_cell = current_cell
	for i in range(spaces):
		var next_cell = Vector2i(current_cell.x + dir_x * (i + 1), current_cell.y + dir_z * (i + 1))
		if next_cell in blocked_tiles:
			break
		last_valid_cell = next_cell
	var new_pos = grid_manager.grid_to_world(last_valid_cell)
	position = new_pos
	target_position = new_pos
	print("[%s] Knocked back %d space(s)" % [enemy_name, spaces])

# ============================================
# HEALTH & DISPLAY
# ============================================

func update_health_display() -> void:
	if health_label:
		health_label.text = "%d / %d" % [current_health, max_health]

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

func die() -> void:
	is_dead = true
	chosen_action = {}
	print("[%s] Defeated!" % enemy_name)
	died.emit(self)

	# Hide tempo bar on death
	if _tempo_bar_bg:
		_tempo_bar_bg.visible = false
	if _tempo_bar_fg:
		_tempo_bar_fg.visible = false
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

	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.5)
	tween.tween_callback(queue_free)

func is_alive() -> bool:
	return not is_dead

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
		_status_container.position = Vector3(0, 1.9, 0)
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
		_status_nodes.append({"node": node})

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
