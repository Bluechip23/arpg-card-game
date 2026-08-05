class_name GameplayWalkthrough
extends ScrollContainer

@onready var content: RichTextLabel = $Content

func _ready() -> void:
	_build_walkthrough()

func _build_walkthrough() -> void:
	if not content:
		return
	
	content.bbcode_enabled = true
	content.text = """[font_size=24][color=gold]GAMEPLAY WALKTHROUGH[/color][/font_size]

[font_size=18][color=cyan]━━━ TEMPO SYSTEM ━━━[/color][/font_size]

The tempo system replaces traditional turn-based combat with a fluid action economy.

[color=yellow]How Tempo Works:[/color]
- Every action (playing cards, moving) adds to your tempo counter
- Each enemy has a tempo threshold. When crossed, they take action
- Advanced enemies have moves with different tempo thresholds (channel, cast fireball)
- If the character plays 4 tempo, and the enemy's threshold is 2, the enemy acts twice
- Important: A unit taking an action does not prohibit other units from taking actions 
- If an enemy begins moving towards you, or attacking you, you can still play cards, move, or take other actions
- Also, if a player takes an action, say move, that player is able to take other actions, say dagger throw or heal, during that move.

[color=yellow]Cycles (every 5 tempo):[/color]
- Every 5 global tempo completes one cycle
- Mana regeneration fires once per cycle
- Card draw timers tick once per cycle
- Buff/debuff durations tick once per cycle
- Armor decays by 2 per cycle (modified by Fortify, Stalwart, Brittle)

[font_size=18][color=cyan]━━━ STAT SYSTEM ━━━[/color][/font_size]

[color=yellow]Core Stats:[/color]

[color=red]Strength (STR)[/color]
- +10 carry capacity per point (base capacity 50)
- +0.5 physical damage per point
- Heavy weapons require high STR
- Spare carry capacity also speeds up the attack counter a little (capped — see DEX)

[color=green]Dexterity (DEX)[/color]
- Attack speed counter = 45 - 0.5 x DEX, adjusted by encumbrance
- Encumbrance (capped): traveling light shaves up to 8 attacks off, heavy loads add up to 7, overburdened is +10
- Dual wielding (a matched pair in both hands) shaves 4 more
- When counter hits 0: DEX PROC
- DEX PROC = Next attack costs 2 less mana AND half tempo (rounded down)!
- Also +3% crit damage per point (base crit 110%)

[color=blue]Intelligence (INT)[/color]
- +0.5 spell damage per point
- +0.15 mana regen per point (about +1 per 7)
- Also boosts healing amount

[color=purple]Wisdom (WIS)[/color]
- +1 hand size per 5 points
- Draws cards 1 tempo sooner per 4 points (base: every 25 tempo)

[color=cyan]Agility (AGI)[/color]
- 1 Flash point per AGI point, refreshed every 3 cycles
- Spending Flash is a CHOICE — the Flash row above Attack shows your pool (lightning bolt)
- Boots toggle: while on, moving a tile spends 1 Flash point (no tempo cost)
- Sidestep button: spend 3 Flash for 2 block
- Daggers button: spend 5 Flash to advance the attack-speed counter 1 tick
- Buttons fade while you can't afford them
- Without Flash, each tile costs 1 tempo
- [color=red]Pass-Through:[/color] Moving through a tile occupied by another unit (ally or enemy) always costs 2 tempo, regardless of Flash points

[color=orange]Determination (DET)[/color]
- Modifies STR/DEX/INT/WIS/AGI at low health
- DET 15 = no effect
- Below 15 = penalty when hurt
- Above 15 = bonus when hurt
- Scales with health thresholds: 0.1% per point at 80% HP, 0.25% at 60%, 0.6% at 40%, 1% at 10%
- Does NOT affect HP, Mana, or itself

[font_size=18][color=cyan]━━━ CARD TYPES ━━━[/color][/font_size]

[color=red]Attack:[/color] Offensive cards that deal damage
[color=dodgerblue]Defense:[/color] Protective cards that grant armor or block
[color=green]Utility:[/color] Support cards for draw, healing, buffs, movement, etc.
[color=yellow]Reaction:[/color] Triggers automatically from hand when a condition is met (e.g., on damage taken). Costs 0 mana and 0 tempo
[color=gray]Unplayable:[/color] Cannot be played. Takes up a hand slot if card is designated by Linger. If not, character can have an infinite amount of the Unplayable card + a standard hand.
[color=green]Power:[/color] Generally requiring Maintain, these cards act as passives as long as you have the resources to maintain them.


[font_size=18][color=cyan]━━━ CARD MECHANICS ━━━[/color][/font_size]

[color=yellow]On-Draw:[/color]
- Some cards trigger an effect the moment they are drawn into your hand
- Example: Thrown Stone deals 4 damage to a random enemy when drawn

[color=yellow]Glut:[/color]
- Puts the player on cooldown. If Glut: 5, the player will not be able to play cards for 5 tempo after playing the card.

[color=yellow]Sticky:[/color]
- Sticky cards stay in your hand after being played
- They can be used X times before being auto-discarded
- Example: Choke (sticky 3) can be played 3 times before leaving your hand

[color=yellow]Erase:[/color]
- After X tempo, this card is permanently deleted from the deck
- Unlike discard, erased cards cannot be recovered

[color=yellow]High Ground:[/color]
- Being elevated (e.g., standing on a pillar from Rise) grants combat bonuses
- Ranged attacks from high ground deal [color=green]+4 damage[/color] and gain [color=green]+2 range[/color]
- Some cards like Lead Arrow require high ground to be played
- Example: Lead Arrow does 1.8x damage but requires high ground

[color=yellow]AOE (Area of Effect):[/color]
- Circle: Hits all enemies within a radius around a target point
- Cone: Hits enemies in a cone in front of the caster
- Line: Hits enemies in a line from the caster toward a target
- AOE RNG is rolled PER ENEMY (green/red shadow indicators)

[color=yellow]Range:[/color]
- Melee: Must be adjacent to target (default for all cards)
- Ranged: Base range = 5 tiles. Ranged +X = 5+X, Ranged -X = 5-X

[color=yellow]Maintain:[/color]
- Define a resource required to keep a card persistant.
- If Maintain: 3, 3 of the players mana will be reserved for this card to stay in play
- When mana drops to 0, card is immediately discarded and effect goes away

[color=yellow]Card Types:[/color]
- Some cards will be designated with a type (arrow, pocket, gem, etc)
- These types desginate which items the card can be slctted into
- Arrow: Quivers, Pocket: Belts, Gem: Gauntlets, Rings
- Card types may come with other effects as well

[color=yellow]Culling Stone:[/color]
- Culling stones are used to remove cards from your deck. 
- Culling stones can be collected in the wilderness from chests or enemy drops.


[font_size=18][color=cyan]━━━ OVERFLOW SYSTEM ━━━[/color][/font_size]

When your hand is full and you try to draw, the overflow system activates.

[color=yellow]Overflow Priority:[/color]
1. [color=red]Jailed[/color] - Card goes to jail (highest priority)
2. [color=purple]Manifest/Enhance[/color] - Whichever was applied first
3. [color=blue]Skip[/color] - Card goes to discard pile
4. [color=green]Peak/Overcharge[/color] - Always trigger (don't block others)

[color=yellow]Manifest:[/color]
- Card goes to a special manifest zone
- Displays as the manifest effect (e.g., "Skeleton", "Mushroom", "Shuriken")
- Click to activate the effect and discard the card
- The original card doesn't matter - only the manifest effect

[color=yellow]Enhance:[/color]
- Attack cards gain bonus damage, then the card is discarded.
- Effect can be positive or negative. 

[color=yellow]Overcharge:[/color]
- An effect triggers immediately (e.g., gain health, mana, armor, or deal damage to all)
- Card stays on top of draw pile
- Triggers alongside other overflow effects
- Allies can provide overflow to allies by making them draw.

[color=yellow]Sources:[/color]
- Cards can apply overflow effects: "Next 3 overdraw: Manifest Skeleton"
- Equipment can provide permanent effects
- Enemies can curse you with negative overflow

[font_size=18][color=cyan]━━━ EQUIPMENT SYSTEM ━━━[/color][/font_size]

[color=yellow]Slot Types:[/color]
- Weapon (Main Hand / Off-Hand)
- Armor (Head, Chest, Boots)
- Accessories (Rings, Belt, Gauntlets)

[color=yellow]Off-Hand Penalty:[/color]
- Default: 90% effectiveness for off-hand items
- Items do not make distinctions between being a main hand or off-hand

[color=yellow]Ring Triggers:[/color]
Rings have passive effects that trigger on events:
- On Enemy Kill → effect
- On Gain Armor Threshold → effect (e.g., gain 10+ armor)
- On Take Damage → effect
- On Heal → effect
- On Play Attack Card → effect
- On Play Utility Card → effect
- On Draw Card → effect
- On Discard Card → effect
- On Low Health → effect
- On Full Mana → effect

[color=yellow]Ring Effects:[/color]
- Heal to Full, Gain Armor, Gain Mana, Draw Card
- Deal Damage to All Enemies, Reduce Cooldowns, Gain Temp Strength

[color=yellow]Gauntlet Skills:[/color]
- Active skills: have a mana cost and cooldown (e.g., Power Grip: 8 dmg, CD 3, Cost 2)
- Passive skills: always active (e.g., Stalwart: -1 armor decay per cycle)

[color=yellow]Card-Item Slots:[/color]
- Some items have card slots where you can enchant cards
- Enchanted cards are removed from your deck and placed in the item
- Items may have On-Self bonuses (+damage, +block, +heal, -mana cost) for slotted cards
- Molded cards are locked in and cannot be extracted
- Picky cards can only re-equip to the same item type
- Pliable cards can re-equip to any item type
- Some cards will be limited to which items they can be slotted in
	- Arrow - Can on be on quivers
	- Gem - can only be placed in gem slots
	- Pocket - can only be used in belts
- Extracting removes a card from an item and returns it to the discard pile
- Chisel cards can only be played when slotted in an item

[font_size=18][color=cyan]━━━ CHARACTER PASSIVES ━━━[/color][/font_size]

Everyone shares the same baseline slots: 1 helm, 2 rings, 1 belt, 1 chest,
1 main hand, 1 off hand, 1 pair of boots, 1 gauntlet — plus one twist each:

[color=red]Ryan:[/color] Belt cards cost 1 less mana (3 belt slots)
[color=green]Brad:[/color] Chest items weigh 20% less. War Rack: gear strapped to his back swaps with his hands — FREE on a 25-tempo cooldown (one side must be a single two-handed item; incoming cards rush to hand), or at normal swap cost anytime
[color=blue]Jeremy:[/color] Every 3rd cycle, the first ring trigger triggers twice (4 ring slots)
[color=purple]Stephen:[/color] +10% off-hand enchantments, others get -10% (standard slots)
[color=orange]Cory:[/color] Gain 1 mana when gauntlet skill comes off cooldown (2 gauntlet slots)

[font_size=18][color=cyan]━━━ RNG ━━━[/color][/font_size]

[color=yellow]How RNG Works:[/color]
- RNG is determined when cards enter your hand
- The card indicates the outcome with green numbers (success) or red (failure)
- Binary RNG: single percentage, either success or fail
- Multi-outcome RNG: weighted random picks which outcome triggers

[color=yellow]AOE RNG:[/color]
- AOE RNG is rolled PER ENEMY
- Green shadow = success, Red shadow = failure for each enemy
- Chance boost from items/effects applies to the roll

[color=yellow]Re-rolling:[/color]
- The RNG for a card re-rolls after 15 tempo is played
- This means holding cards can change their outcome

[font_size=18][color=cyan]━━━ LEVELING ━━━[/color][/font_size]

- Gain XP from killing enemies
- XP to next level = current level × 10
- On level up: +2 max health
- On level up: +3 stat points, banked — spend them any time from the Skill Tree screen (L)
- On level up: HP and Mana fully restored
- On level up: gain spheres to place on the Sphere Grid

[color=yellow]Sphere Grid:[/color]
- The sphere grid is how characters advance their passives, cards, and stats
- Place spheres on connected nodes to unlock new abilities and stat bonuses
- Nodes radiate outward in rings from a central starting point

[color=yellow]Sphere Constellations:[/color]
- Connecting certain spheres together will unlock constellations on the grid
- Each constellation provides the player with a new buff
- Nodes CAN NOT be used in more than one constellation causing players to make grid decisions. 

[color=yellow]Spheres:[/color]
- There is a single, universal [color=cyan]Sphere[/color] - one Sphere unlocks any node, whatever its type
- You earn Spheres by leveling up; spend one to unlock any node connected to your grid

[color=yellow]Node Types:[/color]
- [color=red]Stat[/color] - Grants flat stat bonuses (STR, DEX, INT, WIS, AGI, DET)
- [color=purple]+4 Stats[/color] - Banks 4 stat points to your pool; spend them on any stats from the stat screen, just like leveling up
- [color=green]Passive[/color] - Grants a triggered passive ability (e.g., "On kill: heal 1 HP")
- [color=coral]Health[/color] - Increases max health
- [color=cyan]Mana[/color] - Increases max mana
- [color=gold]Keystone[/color] - Rare, build-defining nodes that rewrite the rules of an entire system (how life steal works, what armor becomes, what drives Determination...). A character can attach at most [color=gold]3 Keystones[/color] - choose the ones that define your build

[color=yellow]Paper Feathers:[/color]
- Paper Feathers can be found from enemy loot and chests
- You can also create Paper Feathers by converting cards into Origami Swans at Olorin (20 swans = 1 feather)

[color=yellow]Mutating Spheres:[/color]
- Passive spheres can be mutated (transmuted) into a different version that fits your play style
- Each Passive node has 2 possible mutations to choose from
- Example: "On kill: heal 1 HP" can mutate into "On kill: gain 2 mana" or "On kill: gain 2 armor"

"""
