class_name GameplayWalkthrough
extends ScrollContainer

## Displays gameplay overview and tutorials

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
- When tempo reaches the threshold (default: 5), enemies take their turn
- The counter then resets (overflow carries over)
- Some actions cost 0 tempo (instant actions like Blink, Draw)

[color=yellow]Tempo Costs:[/color]
- Standard actions: 1 tempo
- Powerful actions: 2+ tempo
- Quick actions: 0 tempo
- Movement: Free moves based on Agility, then 1 tempo per extra move

[color=yellow]Strategic Implications:[/color]
- Chain multiple 0-tempo actions before enemies respond
- Balance powerful moves against giving enemies more turns
- Use Steady buff to skip tempo on key actions
- Weighted debuff increases your tempo costs

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
- Free moves = 1 + floor(AGI/5)
- AGI 5 = 2 free moves, AGI 10 = 3 free moves

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
3. [color=blue]Transferred[/color] - Card goes to ally
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

[font_size=18][color=cyan]━━━ COMBAT TIPS ━━━[/color][/font_size]

- Watch your tempo! Multiple actions = more enemy turns
- DEX builds reward patience - wait for DEX procs
- Armor decays each turn unless you have Fortify
- Stack damage reduction: Resilient (%) applies before Brace (flat)
- Thorns punishes aggressive enemies
- Use Cleanse to remove dangerous debuffs
- Manifest tokens are free effects - use overflow to your advantage!
"""
