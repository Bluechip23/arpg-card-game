# Card ARPG Demo - Developer Guide

Welcome to the Card ARPG Demo project. This guide will help you get set up, understand the codebase, and contribute effectively.

---

## Table of Contents

1. [Project Setup](#project-setup)
2. [Project Structure](#project-structure)
3. [Branch & Communication Rules](#branch--communication-rules)
4. [How to Make a New Card](#how-to-make-a-new-card)
5. [How to Add a New Item](#how-to-add-a-new-item)
6. [How to Add a New Status Effect](#how-to-add-a-new-status-effect-buffdebuff)

---

## Project Setup

**Engine:** Godot 4.6

1. Download and install **Godot 4.6** from [godotengine.org](https://godotengine.org/download)
2. Clone this repository
3. Open Godot, click **Import**, and navigate to the project folder
4. Select the `project.godot` file and open the project
5. Press **F5** to run the game

There are no external dependencies, no package managers, and no environment variables needed. Everything runs through the Godot editor.

---

## Project Structure

```
arpg-card-game/
├── project.godot          # Godot project config (1280x720, Forward Plus)
├── main.tscn              # Root game scene
│
├── scripts/               # All game logic (GDScript)
│   ├── main.gd            # Main game loop, card playing, combat flow
│   ├── card.gd            # Card data class + all 71 card definitions
│   ├── player_stats.gd    # Player stat calculations and tracking
│   ├── deck_manager.gd    # Deck, hand, draw/discard/jail pile management
│   ├── enemy.gd           # Enemy behavior and combat
│   ├── buff.gd            # Buff definitions (17 types)
│   ├── debuff.gd          # Debuff definitions (25 types)
│   ├── buff_manager.gd    # Buff application and tracking
│   ├── debuff_manager.gd  # Debuff application and tracking
│   ├── tempo_manager.gd   # Tempo meter and enemy turn triggering
│   ├── turn_manager.gd    # Turn loop and draw timer
│   ├── grid_manager.gd    # Grid conversions and distance calculations
│   ├── overflow_manager.gd# Overflow card effect handling
│   ├── inventory.gd       # Equipment management
│   ├── item_data.gd       # Item definitions and properties
│   ├── enemy_spawner.gd   # Enemy spawning and wave management
│   ├── character_data.gd  # Character definitions (stats, card pools)
│   ├── card_ui.gd         # Card visual display in hand
│   └── ...                # UI scripts, helpers, etc.
│
├── scenes/                # Godot scene files (.tscn)
│   ├── player.tscn        # Player character
│   ├── enemy.tscn         # Enemy character
│   ├── card_ui.tscn       # Card visual in hand
│   ├── character_select.tscn  # Character selection screen
│   ├── inventory.tscn     # Equipment screen
│   ├── test_ui.tscn       # Debug/test panel (T key)
│   └── ...                # UI panels, tooltips, indicators
│
└── .godot/                # Godot cache (auto-generated, do not edit)
```

**Key files you will touch most often:**
- `scripts/card.gd` - Adding or editing cards
- `scripts/main.gd` - Card execution logic and game flow
- `scripts/item_data.gd` - Adding new items
- `scripts/buff.gd` / `scripts/debuff.gd` - Adding status effects
- `scripts/character_data.gd` - Adding characters or modifying card pools

---

## Branch & Communication Rules

When you create a branch, name it like this:

```
your_name-subject-branch_title
```

- **your_name** - Your name so we know who made it
- **subject** - The area of the project (card, gameplay, ui, item, buff, enemy, etc.)
- **branch_title** - Short description of what you're doing

**Examples:**
```
ryan-card-add_fireball_card
jeremy-gameplay-fix_tempo_overflow
stephen-ui-update_character_panel
cory-buff-add_shield_wall_buff
```

**After you push**, post in the Discord what your branch does and what it changes. The team will review it and we will progress accordingly.

---

## How to Make a New Card

All cards live in `scripts/card.gd`. To add a new card, you need to:

### 1. Write a static factory function

Add a new `static func create_your_card() -> Card` at the bottom of `card.gd`. Here is the template with every field you need to consider:

```gdscript
static func create_your_card_name() -> Card:
    var card = Card.new()

    # === REQUIRED FIELDS ===
    card.card_id = "your_card_id"          # Unique ID, lowercase with underscores
    card.card_name = "Your Card Name"      # Display name
    card.description = "What it does"      # Short text shown on the card
    card.card_type = CardType.ATTACK       # ATTACK, DEFENSE, or UTILITY
    card.card_type_name = "Attack"         # "Attack", "Defense", or "Utility"
    card.mana_cost = 1                     # Mana required to play
    card.tempo_cost = 4                    # Tempo added when played (threshold is 5)
    card.damage = 0                        # Damage dealt
    card.base_damage = 0                   # Must match damage
    card.block = 0                         # Armor gained
    card.base_block = 0                    # Must match block
    card.heal_amount = 0                   # HP healed
    card.target_types = ["enemy"]           # Array of: "enemy", "ally", "self", "point", "all_nearby"

    # === OPTIONAL FIELDS (set only what applies) ===
    card.is_ranged = false                 # true = ranged attack (base range 5)
    card.range_modifier = 0                # Adjusts range (+2 = range 7, -2 = range 3)
    card.is_aoe = false                    # true = area-of-effect
    card.aoe_shape = ""                    # "cone", "circle", or "line"
    card.aoe_range = 100.0                 # AOE radius/length
    card.chance_effect_percent = 0.0       # Per-enemy hit chance for AOE
    card.sticky = 0                        # Turns card lingers in hand (0 = normal)
    card.duration = 0                      # Effect duration in turns
    card.requires_high_ground = false      # Needs elevated position to play
    card.rng_outcomes_data = []            # RNG percentages (see RNG section below)

    return card
```

### 2. Wire up the card's execution logic

The card's actual behavior when played is handled in `scripts/main.gd`. Search for existing card_id checks (e.g., `"slash"`, `"heal"`) to see where to add your card's logic.

### 3. Add it to a character's card pool

Cards are assigned to characters in `scripts/character_data.gd`. Add your card's `create_` function to the appropriate character's card list.

### RNG Cards

If your card has random outcomes, set `rng_outcomes_data`:

```gdscript
# Binary (one percentage, pass or fail):
card.rng_outcomes_data = [{"percent": 60.0}]

# Multi-outcome (weighted, picks one):
card.rng_outcomes_data = [
    {"percent": 40.0},   # Outcome 0
    {"percent": 35.0},   # Outcome 1
    {"percent": 25.0}    # Outcome 2
]
```

### A Note on Using AI to Create Cards

If you are using an AI to help you make a card, **be very detailed about what you want**. You will most likely have to give a much more detailed description than you think.

Don't just say "make a card that does fire damage." Actually envision yourself playing the card and describe everything that happens:

- What does the player see when they play it?
- Does it hit one enemy or multiple?
- Is it melee or ranged?
- Does it apply a buff or debuff? For how long?
- Does it cost a lot of tempo or a little?
- Does it have an RNG element? What are the chances?
- What happens on success? What happens on failure?
- Does the card interact with any existing mechanics (armor, mana, movement)?

The AI can absolutely make the card, but it needs more context than you think. More than what you think is actually happening. Walk through the full play experience in your head, and describe that.

---

## How to Add a New Item

All items are defined in `scripts/item_data.gd`. Items are equipment that go into slots: Helm, Chest, Ring, Belt, Boots, Gauntlets, or Weapon.

### 1. Write a static factory function

Add a new `static func create_your_item() -> ItemData` in `item_data.gd`:

```gdscript
static func create_your_item_name() -> ItemData:
	var item = ItemData.new()

	# === REQUIRED FIELDS ===
	item.item_name = "Your Item Name"
	item.item_type = ItemType.HELM          # HELM, CHEST, RING, BELT, BOOTS, GAUNTLETS, WEAPON
	item.item_type_name = "Helm"            # Display name for the slot
	item.weight = 3                         # Item weight
	item.description = "+2 Armor"           # Short description of what it does

	# === STAT BONUSES (set any that apply) ===
	item.strength_bonus = 0
	item.dexterity_bonus = 0
	item.intelligence_bonus = 0
	item.wisdom_bonus = 0
	item.determination_bonus = 0
	item.agility_bonus = 0
	item.health_bonus = 0
	item.mana_bonus = 0
	item.armor_bonus = 0
	item.hand_size_bonus = 0

	# === WEAPON-SPECIFIC (only for weapons) ===
	item.weapon_damage = 0
	item.weapon_hand = WeaponHand.MAIN_HAND  # MAIN_HAND, OFF_HAND, or TWO_HAND
	item.is_two_handed = false
	item.damage_percent_bonus = 0.0
	item.fire_damage_percent = 0.0
	item.ice_damage_percent = 0.0
	item.lightning_damage_percent = 0.0

	# === SPECIAL EFFECTS (optional) ===
	item.special_effect = SpecialEffect.NONE
	# Available: OVERFLOW_HEAL_ARMOR, GRANT_BLINK_CARD, INCREASE_HAND_SIZE,
	#            CHANCE_BOOST, GRANT_CARDS
	item.special_effect_value = 0
	item.special_effect_value_2 = 0
	item.granted_card_ids = []              # For GRANT_CARDS effect

	return item
```

### Ring Trigger System

Rings can have passive triggers that fire on game events:

```gdscript
item.ring_trigger = RingTrigger.ON_ENEMY_KILL
# Available triggers:
#   ON_ENEMY_KILL, ON_GAIN_ARMOR_THRESHOLD, ON_TAKE_DAMAGE, ON_HEAL,
#   ON_PLAY_ATTACK_CARD, ON_PLAY_UTILITY_CARD, ON_DRAW_CARD,
#   ON_DISCARD_CARD, ON_LOW_HEALTH, ON_FULL_MANA

item.ring_trigger_threshold = 0            # For threshold-based triggers
item.ring_effect = RingEffect.GAIN_ARMOR
# Available effects:
#   HEAL_TO_FULL, GAIN_ARMOR, GAIN_MANA, DRAW_CARD,
#   DEAL_DAMAGE_ALL_ENEMIES, REDUCE_COOLDOWNS, GAIN_TEMP_STRENGTH

item.ring_effect_value = 5                 # Value for the effect
```

### Gauntlet Skill System

Gauntlets can have active or passive skills:

```gdscript
# Active skill (has cooldown, costs mana):
item.gauntlet_skill_type = GauntletSkillType.ACTIVE
item.gauntlet_skill_name = "Power Grip"
item.gauntlet_skill_description = "Deal 8 damage"
item.gauntlet_skill_cooldown = 3
item.gauntlet_skill_mana_cost = 2
item.gauntlet_skill_effect_id = "power_grip"   # Used in main.gd to execute

# Passive skill (always active):
item.gauntlet_skill_type = GauntletSkillType.PASSIVE
item.gauntlet_skill_name = "Stalwart"
item.gauntlet_skill_description = "Armor decays 1 less per turn"
item.gauntlet_skill_effect_id = "stalwart"
```

### 2. Wire it up

Add the item to a character's starting equipment in `character_data.gd`, or make it available as a drop/reward in the game flow.

---

## How to Add a New Status Effect (Buff/Debuff)

Buffs live in `scripts/buff.gd`, debuffs live in `scripts/debuff.gd`. The process is similar for both.

### Adding a New Buff

**Step 1:** Add your buff to the `BuffType` enum in `buff.gd`:

```gdscript
enum BuffType {
    THORNS,
    FOCUSED,
    # ... existing types ...
    WEAR_DOWN,
    YOUR_NEW_BUFF       # <-- add here
}
```

**Step 2:** Add the name and description in `_set_name_and_description()`:

```gdscript
BuffType.YOUR_NEW_BUFF:
    buff_name = "Your Buff Name"
    description = "What it does, value = %d" % value
```

**Step 3:** Add an icon color in `get_icon_color()`:

```gdscript
BuffType.YOUR_NEW_BUFF: return Color(0.5, 0.8, 0.5)  # Pick a color
```

**Step 4:** If charge-based, add it to `is_charge_based()`:

```gdscript
func is_charge_based() -> bool:
    match buff_type:
        BuffType.ENLIGHTENED, BuffType.STRENGTHEN, ..., BuffType.YOUR_NEW_BUFF:
            return true
    return false
```

**Step 5:** Create a factory method:

```gdscript
static func create_your_new_buff(val: int = 3, duration: int = 3, source: String = "") -> Buff:
    var buff = Buff.new(BuffType.YOUR_NEW_BUFF, val, duration)
    buff.source_name = source
    return buff
```

**Step 6:** Wire up the actual effect in `scripts/buff_manager.gd`. Search for where existing buffs are applied (e.g., how `THORNS` deals damage back, how `REGEN` heals each turn) and add your buff's logic there.

### Adding a New Debuff

Same pattern, but in `scripts/debuff.gd` and `scripts/debuff_manager.gd`:

1. Add to the `DebuffType` enum
2. Add name/description in `_set_name_and_description()`
3. Add icon color in `get_icon_color()`
4. Add a `static func create_your_debuff()` factory method
5. Wire up the effect logic in `scripts/debuff_manager.gd`

### Key Concepts

- **Duration-based** buffs/debuffs tick down each turn and expire when duration hits 0. Use `duration = -1` for "until cleansed."
- **Charge-based** buffs deplete when triggered (e.g., "next 3 attacks"). Set `charges` and `duration = -1`.
- **Value** (`val`) is the magnitude: damage amount, percentage, bonus, etc.
