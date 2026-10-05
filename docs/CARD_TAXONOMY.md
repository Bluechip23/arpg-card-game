# Card Taxonomy — the card web

The designer's card web is the canonical model for what a card *is*. Read it
before adding a card, a rider, or a passive that says "attack", "spell",
"offensive", "defensive" or "utility".

```
Card
├── Playable
│   ├── Power
│   ├── Offensive ──┬── Attack ──┐
│   │               └── Spell ───┤
│   ├── Defensive ───── Spell ───┤── Ranged / Melee ── Ally · Self · AOE · Point Click
│   └── Utility ─────── Spell ───┘
├── Instant (reaction)  ╌╌ may also be Offensive / Defensive / Utility
├── Unplayable
└── Enchantment
```

**A card can be several things at once.** A spell and an attack (If Pigs
Could Fly), defensive and offensive, utility and defensive, an instant that
is also a utility spell (Healthy Bliss). The tags on the sheet decide, never
what the card happens to do: a utility that deals damage is not offensive
unless it carries the rider.

## Reading the web

| Word on the sheet / in a passive | What it means | In code |
|---|---|---|
| **Offensive** | The card carries the offensive rider. Every Attack is offensive; a Spell, Utility or Instant is offensive only when tagged. | `Card.is_offensive()` — `card_type == ATTACK or has_keyword("offensive")` |
| **Attack** | The Attack shape under Offensive. Not a spell. | `Card.is_attack()` — tagged `attack`, or an Attack-type card that is not a spell |
| **Spell** | The Spell shape — under Offensive (Fireball), Defensive (none yet) or Utility (Lady Luck). Silence stops it in every role. | `school == CardSchool.SPELL` ⇔ tagged `spell` |
| **Defensive** | The Defense type, or the `defense` tag on an instant / utility (Vengeful Shield). | `card_type == DEFENSE or has_keyword("defense")` |
| **Utility** | The Utility type, or the `utility` tag on an instant (Healthy Bliss). | `card_type == UTILITY or has_keyword("utility")` |
| **Power** | Standing effects (Halo, Fountain of Health). Never offensive unless tagged. | `card_type == POWER` |
| **Instant** | Fires from the hand on its trigger; never played by hand. May carry the riders above. | `card_type == REACTION` + `reaction_trigger` |
| **Ranged / Melee** | The reach of the Attack or Spell. A Conditional card is melee until a bow is held (ranged 5, +1 tempo). | `is_ranged`, `range_modifier`, `conditional` tag |
| **Ally · Self · AOE · Point Click** | Who or where it lands. | `target_types`, `is_aoe` / `aoe_shape` |

"Damage" in a passive's text means **offensive** (the rider), not "deals
damage" and not "attack" (Deadly, Eagle Eye). "Attack" means the Attack
shape (Exposed Blind Spot's crit, Lethal Resourcefulness's "non-attack",
Skilled Momentum, Life Steal). "Spell" means the Spell school.

## The engine's representation

The engine keeps one `card_type` per card because many systems (the DEX
attack-speed counter, Disarm, Tighten String, the Attack card's weapon
adoption…) key on it. An **offensive spell is stored as `card_type ==
ATTACK` with `school == SPELL`** and shows **"Spell"** on its face; the
helpers above are what passives, items and riders read, never the raw
type. Disarm blocks the Attack shape only (`school == PHYSICAL`); Silence
blocks the Spell school in any role.

## Rulings on "attack"-worded systems

Settled by the designer (2026-10-05): these read the **Attack shape**
(`is_attack()`), never offensive spells — Tighten String and the High Ground
bonus (ranged attacks), Empower, Wear Down, Armor Break, the DEX attack-speed
counter and its proc (half tempo, mana discount, Killing Rhythm), Collect
Arrows. **Heavy Swing** is worded "offensive" and reads `is_offensive()`.
Disarm blocks the Attack shape; Silence blocks the Spell school.

Open questions for the designer are tracked in `docs/CARD_REFERENCE.md`
(the per-card "Mismatch" lines).
