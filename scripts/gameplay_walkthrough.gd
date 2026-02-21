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
- Advanced enemies have moves with different tempo thresholds (channel, cast fireball).
- If the character plays 4 tempo, and the enemies threshold is 2, the enemy acts twice.

[font_size=18][color=cyan]━━━ STAT SYSTEM ━━━[/color][/font_size]

[color=yellow]Core Stats:[/color]

[color=red]Strength (STR)[/color]
- +10 carry capacity per point
- +1 physical damage per 2 points
- Heavy weapons require high STR

[color=green]Dexterity (DEX)[/color]
- Affects attack speed counter (30 - DEX)
- When counter hits 0: DEX PROC
- DEX PROC = Next attack costs 2 less mana AND 0 tempo!

[color=blue]Intelligence (INT)[/color]
- +1 spell damage per point
- +1 mana regen per 5 points

[color=purple]Wisdom (WIS)[/color]
- +1 hand size per 5 points
- Faster card draws

[color=cyan]Agility (AGI)[/color]
- Movements per tempo = floor(AGI/5)
- AGI 5 = 1 free move, AGI 10 = 2 free moves

[color=orange]Determination (DET)[/color]
- Modifies other stats at low health
- DET 10 = no effect
- Below 10 = penalty when hurt
- Above 10 = bonus when hurt
- Does NOT affect HP, Mana, or itself

[font_size=18][color=cyan]━━━ OVERFLOW SYSTEM ━━━[/color][/font_size]

When your hand is full and you try to draw, the overflow system activates.

[color=yellow]Overflow Priority:[/color]
1. [color=red]Jailed[/color] - Card goes to jail (highest priority)
2. [color=purple]Manifest/Enhance[/color] - Whichever was applied first
3. [color=blue]Transferred[/color] - Card goes to discard pile
4. [color=green]Peak/Overcharge[/color] - Always trigger (don't block others)

[color=yellow]Manifest:[/color]
- Card goes to a special manifest zone
- Displays as the manifest effect (e.g., "Skeleton")
- Click to activate the effect and discard the card
- The original card doesn't matter!

[color=yellow]Overcharge:[/color]
- An effect triggers immediately (e.g., gain 2 mana)
- Card stays on top of draw pile
- Triggers alongside other overflow effects

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
- Stephen's Passive: 110% effectiveness (+20% swing!)

[color=yellow]Ring Triggers:[/color]
Rings have passive effects that trigger on events:
- On Enemy Kill → effect
- On Take Damage → effect
- On Play Attack Card → effect
- etc.

[color=yellow]Gauntlet Skills:[/color]
- Active skills with mana cost and cooldown
- Passive skills always active
- Cory gains 1 mana when skill comes off cooldown

[font_size=18][color=cyan]━━━ CHARACTER PASSIVES ━━━[/color][/font_size]

[color=red]Ryan:[/color] Belt cards cost 1 less mana
[color=green]Brad:[/color] Chest items weigh 15% less
[color=blue]Jeremy:[/color] First ring trigger per turn triggers twice
[color=purple]Stephen:[/color] +10% off-hand bonuses (others get -10%)
[color=orange]Cory:[/color] Gain 1 mana when gauntlet skill comes off cooldown

[font_size=18][color=cyan]━━━ RNG ━━━[/color][/font_size]

- RNG is determined when cards enter your hand. 
- The card indicates the outcome with green numbers (positive) or red (failure)
- RNG with AOE will be rolled PER ENEMY and be designated with green or red shadow under each enemy
- The RNG for the card re rolls after 15 tempo is played. 

"""
