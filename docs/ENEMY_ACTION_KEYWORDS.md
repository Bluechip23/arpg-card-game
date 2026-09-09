# Enemy Action Keywords

How an enemy's actions relate to the tempo ticker. Every action in an
enemy's table (`Enemy.actions_for_type`, `scripts/battle/enemy.gd`) is a
dictionary; the keywords are optional keys on it. Anything not tagged uses
the defaults: **Sync**, **Immediate**, **Non-interruptible**.

```gdscript
{"name": "punch",      "tempo_cost": 3, "async": true},
{"name": "kick",       "tempo_cost": 5},                       # Sync (default)
{"name": "power_bomb", "tempo_cost": 9, "async": true, "disrupt": 10},
{"name": "fire_wall",  "tempo_cost": 8, "channel": 5},         # 3 wind-up, 5 channel
{"name": "beam",       "tempo_cost": 5, "channel": 5},         # stand-alone channel
{"name": "retaliate",  "trigger": "damaged"},                  # no clock at all
{"name": "shoot",      "tempo_cost": 5, "label": "Arrow"},     # display name only
```

One tempo is processed at a time, even when the ticker jumps several at once,
so every rule below is exact per tempo.

## Sync (default)

The enemy runs **one shared clock** and commits to **one action at a time**.
The AI picks the action, the clock counts up to its tempo cost, it fires, the
clock resets, the AI picks the next.

Punch 3 / Kick 5, both Sync: Punch fires at tempo 3, Kick 5 tempo later at 8,
Punch 3 after that at 11.

A Sync action may only **start** ticking on a tempo where no Async clock is
mid-count — right after every Async action has fired (their counters are all
at 0). Once started it keeps counting whatever the Async clocks do.

## Async

The action keeps **its own clock**. It counts every tempo, fires when it
reaches its cost, resets to 0, and counts again. Firing it never resets any
other clock. Async clocks start on the first tempo of the fight, ahead of any
Sync action.

An Async action whose tempo comes up while it cannot land (target out of
reach) is spent: the clock restarts anyway.

### Worked example 1 — Punch 3 Async, Kick 5 Sync

| Tempo | Punch | Kick | Fires |
|------:|:-----:|:----:|-------|
| 1 | 1 | – | |
| 2 | 2 | – | |
| 3 | 3 | – | **Punch** |
| 4 | 1 | 1 | |
| 5 | 2 | 2 | |
| 6 | 3 | 3 | **Punch** |
| 7 | 1 | 4 | |
| 8 | 2 | 5 | **Kick** |
| 9 | 3 | – | **Punch** (Kick cannot restart: Punch was mid-count) |
| 10 | 1 | 1 | |
| 11 | 2 | 2 | |
| 12 | 3 | 3 | **Punch** |
| 13 | 1 | 4 | |
| 14 | 2 | 5 | **Kick** |

### Worked example 2 — Punch 3 Async, Kick 5 Sync, Power Bomb 9 Async

| Tempo | Punch | Power Bomb | Kick | Fires |
|------:|:-----:|:----------:|:----:|-------|
| 1 | 1 | 1 | – | |
| 2 | 2 | 2 | – | |
| 3 | 3 | 3 | – | **Punch** |
| 4 | 1 | 4 | – | Kick cannot start: Power Bomb is mid-count |
| 5 | 2 | 5 | – | |
| 6 | 3 | 6 | – | **Punch** |
| 7 | 1 | 7 | – | |
| 8 | 2 | 8 | – | |
| 9 | 3 | 9 | – | **Punch**, **Power Bomb** |
| 10 | 1 | 1 | 1 | Kick starts: every Async clock was at 0 |
| 11 | 2 | 2 | 2 | |
| 12 | 3 | 3 | 3 | **Punch** |
| 13 | 1 | 4 | 4 | |
| 14 | 2 | 5 | 5 | **Kick** |
| 15 | 3 | 6 | – | **Punch** |
| 18 | 3 | 9 | – | **Punch**, **Power Bomb** |
| 19 | 1 | 1 | 1 | Kick starts again |

## Channel N

The **last N tempo** of the action are a channel. `tempo_cost` is the whole
action: "8 tempo, Channel 5" winds up for 3 tempo, then channels for 5, and
resolves at the end of tempo 8. `channel >= tempo_cost` is a stand-alone
channel with no wind-up; it starts counting on the tempo it is chosen.

While channeling the enemy is **planted**: it cannot move, dash, or wander,
and **every other clock pauses** (Sync and Async alike) until the channel
resolves or breaks. The overhead bar turns orange and reads
"Channeling <name>".

**Immediate** is the default: no channel, the action resolves the moment its
tempo comes up.

## Disruptable X

Damage dealt to the enemy while the action is counting (or channeling) is
added up. When the total reaches X, that action's clock **restarts from 0**
(a channel collapses). The tally resets whenever the clock resets. Only the
tagged action is affected; other clocks keep going.

**Non-interruptible** is the default: the clock or channel runs on no matter
how hard the enemy is hit.

## Trigger

No clock. The action fires in response to an event. Events wired today:

| Event | Fires when |
|-------|-----------|
| `damaged` | the enemy takes damage |
| `exposed` | the enemy's armor is broken to 0 |
| `ally_died` | another enemy dies |
| `half_health` | the enemy drops to or below half health |

A triggered action can also carry `channel`; it then begins channeling
instead of resolving at once. A stunned, frozen, or already-channeling enemy
does not react.

## Stun and freeze

A stun or freeze resets **every** clock (Sync, Async, and any channel) when it
lands, so the delay is paid once; clocks count again while the status runs
down and actions resume when it ends.

## Where the keywords show up

- **Overhead bar / unit tracker**: yellow = Sync clock, blue = Async clock,
  orange = channel. The bar shows whichever clock fires soonest.
- **Inspect panel**: the current clock plus every action with its keywords.
- **Compendium**: keywords beside each action's tempo.
- **Keyword legend**: the "Enemy Actions" section.
