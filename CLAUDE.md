# CLAUDE.md - AI Development Guidelines

## Game Design Direction

**This is a TRUE RPG, not a roguelike.**

This distinction is critical and must guide every design and implementation decision:

### What this game IS:
- A persistent-character action card RPG
- The player builds ONE character and carries them through the entire story
- Character progression (sphere grid, equipment, deck, stats) is permanent and cumulative
- Story-driven with a beginning, middle, and end
- Multi-act progression where the player's state carries forward between acts (planes of existence)

### What this game is NOT:
- Not a roguelike or roguelite
- No permadeath
- No run-based progression or meta-currencies that persist across "runs"
- No procedurally generated content that resets
- No starting over with a fresh character after death

### Core RPG Pillars:
1. **Persistent Character** - One character, one journey. Stats, equipment, cards, and sphere grid unlocks are permanent
2. **Story Progression** - The player progresses through a narrative across 4 acts (Earth, Hell, Heaven, and a final return to Earth)
3. **Meaningful Builds** - Sphere grid, equipment, and deck choices define a unique character build
4. **World Continuity** - Waypoints, quests, NPCs, and town vendors persist across the entire game

When adding new features or mechanics, always ask: "Does this support a persistent, story-driven RPG experience?" If a mechanic feels like it belongs in a roguelike (temporary buffs that reset between runs, random reward pools, death-and-restart loops), rethink the approach.

## Narrative Canon

The story, world, and characters are documented in [`docs/STORY.md`](docs/STORY.md) — the canonical worldbuilding bible (Olorin, the three Acts/Worlds, the bestiary, the roguelike end-game, and how the narrative maps to existing systems). Read it before adding story, quest, world-theme, or enemy content, and keep it updated when story decisions are made.
