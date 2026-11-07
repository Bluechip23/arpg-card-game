# Phase 2 — wiring audit

Every card, item, enemy, summon and passive was read against its stated description, its code path traced (cost, targeting, triggers, stacking, duration, the tempo clock), marked, and **proven by a test**. Eleven slices were audited in parallel; each slice's full notes are in `docs/audit/wiring/<slice>.md`. Regenerate this page with `python3 tools/audit/wiring_merge.py`.

Status: **CORRECT** (code does what the text says) · **FIXED** (was wrong; code changed to match the text) · **MISSING** (described, not built; now built) · **FLAGGED** (the text is unclear or contradicts another system — a question for you below; where a slice also fixed the clear part, the row says so) · **BLOCKED** (too large to fix safely in the audit; plan in `validation.md`). Rows marked *(Phase 6 re-check)* were CORRECT until the independent re-check in `validation.md` found them wrong.

## Totals

| type | CORRECT | FIXED | MISSING | FLAGGED | BLOCKED | total |
|---|---|---|---|---|---|---|
| card | 210 | 28 | 1 | 16 | 0 | 255 |
| enemy | 66 | 4 | 0 | 4 | 0 | 74 |
| item | 162 | 15 | 0 | 11 | 1 | 189 |
| passive | 42 | 8 | 0 | 9 | 1 | 60 |
| summon | 13 | 0 | 0 | 3 | 0 | 16 |
| **all** | **493** | **55** | **1** | **43** | **2** | **594** |

## FLAGGED — questions for the designer

### cards_a

- **Whirling Weapon (`composed_reaction`)** — The text says "when you are attacked (melee, ranged or spell)". It fires on any damage you take: Burn/Poison/Choke ticks and self-paid costs (Cultish Wounds' bleed, Communal Donation, Demonic Rage's health price) set it off too. Should it fire only on enemy attacks (e.g. the enemy `attacked_player` signal), or on any damage?
- **Death Vortex (`death_vortex`)** — "After you are hit 5 times": the streak counts every damage instance, DoT ticks and self-inflicted costs included, and never resets except by firing. Should only enemy hits count, and should the streak lapse after some time?
- *(Related to the FIXED Composed Response, `composed_response`.)* When an Overcharge is the only overflow mode, the overflowed card is now discarded (it used to vanish). If the designer instead wants it left on top of the draw pile (what a full hand does with no overflow mode at all), that is a one-line change in `OverflowManager.process_overflow`.

### cards_b

- **Element Pollination** — (1) "your Shock freezes at 5 stacks like Cold":
  the code gives a 5-tempo *Stun* (an earlier pass chose this,
  `test_card_item_audit.gd` asserts it). Should it be Cold's *Frozen*
  instead, which shows as Frozen and counts as Cold for anything that reads
  it? (2) "your Burn also splashes nearby enemies like Shock": Shock arcs
  its tick to the *one* nearest enemy, while the pollinated Burn hits
  *every* enemy within 2.5. Should Burn's splash copy Shock's single arc?

### cards_c

- **Mana Surge, Last Breath, Life Swap.** Mana numbers in these texts are still on the scale used before the x10 rescale. The code was rescaled on purpose, and the HUD and card badges show raw mana. Should the text change to "gain 10 mana", "3 damage per 10 mana" and "10 mana = 1 HP"? Or should the code follow the text as written: 1 mana, 3 per mana, 1:1?
- **Hope This Works.** For "provide STR for 3 attacks", should it be the Strengthen it is now (+2 damage on the next 3 attacks) or +STR? And how much: is 2 right?
- **Mark.** "Extra damage from your attacks": should the +15% apply only to the Attack shape (`is_attack()`), or to every hit you deal as now (spells, AoE splashes, summons that pass `from_player`)?
- **Misery Loves Company.** "Your next AOE attack": should an AoE spell (Ice Grenade, Poison Bomb, Fireball, Internal Combustion) spend and spread it as now, or only an AoE attack?
- **Morphine.** The 4 temp HP can run out 1 to 4 tempo before the stated 15, because temp HP is counted per cycle. Should temp HP tick on raw tempo? That is a shared change to `PlayerStats.process_turn` / `process_tempo` and to `test_coop_status_ticks.gd`. Or should Morphine take its temp HP back itself when its buff ends?

### cards_d

- **Push**: "Move a *unit* away from you". Should Push also target allies (and summons), or is "unit" just loose wording for an enemy? Today it is enemy-only.
- **Quick Arrow**: "A free ranged attack" / "a free 0-cost Quick Arrow". Should it also cost 0 tempo (it costs 2), or does "free" mean mana only?
- **Return Cut**: what does "counter with a melee strike" hit for? Today it is STR-only damage with no base (`get_effective_physical_damage(0)`, 1 at low STR). Should it be the auto attack's swing (base 3 through the same pipeline), or a number on the card?
- *(Not a wiring issue, noted for the art pass.)* Rise's structure is a procedural `CylinderMesh` (`Main._spawn_pillar`), which goes against CLAUDE.md's "Art: Packs First" rule. A pack's cliff or rock piece would replace it.

### cards_e

- **smith_thy_soul** — "Gain armor equal to ((Health + mana) / 2) / 10." The code adds the raw mana pool, which runs on the x10 economy (`passive_scaling.gd`: design "1 mana" = 10 in code; Try This's "+3 mana pool" is +30 and Specific Strike's "+1m" is +10 in code). At 100 HP / 100 code-mana the card gives 10 armor; read in design units (100 + 10) it gives 5. `tests/test_card_sheet_pass.gd` pins the raw reading. **Question: is "mana" in the formula the raw pool (as now) or design mana (pool / 10)?**
- **song_of_a_swords_sing** — "Disarm the enemy for 5 tempo and gain 2 armor for every KIND of debuff on it". The code counts kinds *before* its own Disarm lands, so on a clean enemy it gives 0 armor; the card's example ("burn + frost + disarm is three") counts a Disarm already there. **Question: does the Song's own Disarm count as a kind (always at least +2 armor), or only debuffs already on the enemy (as now)?**
- **wear_down** — "Decrease enemy attack by 1 per consecutive hit. Lasts 15 tempo." The 15 tempo is the window in which your attacks stack the reduction (as written). The reduction itself, though, clears after the enemy's next 2 attacks (`Enemy.WEAR_DOWN_ATTACKS`, from the sheet), which the card text does not say, and "consecutive" is not enforced (a miss or a non-attack does not reset the count). **Question: should the card text mention the 2-attack limit, and should a break in the hits reset the stack?**

### enemies_a

- **Fire Goblin Soldier:** the compendium says "Range 0". The soldier attacks a player on an adjacent square,
  like every melee enemy. Should the text read "Melee" (or "Range 1"), or should it really have no reach?
- **Mini Bear:** "When a packmate in sight is hurt, gains +2 attack damage." The code grants the +2 only when
  the player's own hit lands on the packmate. Should burn and poison ticks, summons' hits and allies' hits
  (Sear Wounds) also feed the pack bonus? The Large Bear's "every time it is hurt" counts any source. Note
  that any-source would stack +2 on every DoT tick, so this is a balance call.
- **Screecher:** the action list calls the move "Drift" and the prose calls it "Scuttle". The behaviour is
  the same either way (4 spaces / 2 tempo unseen, 2 / 5 seen). Which name stands? No rename was made, per
  the audit rules.

### enemies_b

- **Granite Colossus** — the compendium lists "Move (5 tempo): 3 spaces" but also says "it only stands", and its action table is empty (the sheet's moves are TBD). Should it walk (add a 5-tempo Move to its table) or should the Move line come out of the text until its kit is designed?
- **Spirit Bow / budded bows** — "This bow and its bow summons gain +2 damage and +5% crit chance per living bow summon" (Bow of Budding Blasts). The code gives each bow +2 damage per *other* bow, but +5% crit per bow *including itself*; a lone Spirit Bow hits for 10, matching the Spirit Bow card's "10-damage shot". Does a bow count itself (then a lone bow hits for 12 and the card text changes), or not (then the crit should be 5% per other bow)?
- **Manifest spirit / golem** — `SummonedSkeleton` keeps "spirit" and "golem" kinds and `main.gd` has `summon_spirit` / `summon_golem` manifest handlers, but no card or item produces them; they are reachable only from the sandbox. Keep for a future item, or remove?
- **Flat sheet numbers vs the level-band note** (shared by several enemies, not a single row) — every banded enemy's compendium text ends "(Level-band rebalance: action numbers above are base — actual HP x…, damage x….)". Most hard-coded hits honour it (`roundi(N * _pps_dmg)`: Stinger, Talon Grab, Clobber, Fire Breath, totems), but some stay flat: Weregoat Charge 8 (test_sheet_mountains asserts 8), Sabertooth Bite 6 / Claw 3 / Sunken Bite 10, Thanatos Death Bolt 15, Snow Wraith Ice Blast's +3, Succubus Damaging Snap's +4, Sewer Cobra Venom Spray 10 (its comment says flat on purpose). Should those scale with the band like the rest, or should the note say which numbers it covers?

### items_a

- **bessy**: "Offensive cards deal +25% damage to Weakened enemies." The bonus is 25% of the card's base plus flat bonuses, computed before STR scaling, so on a stat-heavy hit it is a few points rather than a quarter more. Tigers Sunday Red and Purge Wrath use the same pre-scaling base; Megingjörð's multiplier is applied at the end. Should Bessy's +25% apply to the final hit, as Megingjörð's x2 does?
- **bloodbound_plate**: What should "+3 armor" do on a chest? Today nothing reads `armor_bonus` outside a shield's Basic Block. Possible meanings: 3 armor on equip, 3 armor at each battle start, or +3 to the unerring cap. Or should the text drop it?
- **boomerang**: The text says "a one-handed throwing arm; pairs with a quiver", but the 2026-10-25 ruling (`test_ranged_pass`) refuses quivers beside anything but a bow. Should the text change, or should the boomerang be the exception that takes a quiver?

### items_b

- **laurentius_lost_spear**: "Grants 2 Psionic Flows (instant): … Whichever comes first." With both Flows in hand, the first attack (or the first hit on an ally) fires both at once: +16 damage and two shoves, or 16 healing. Should each copy be a separate charge, with one firing per trigger? Or is both firing together intended? `trigger_reactions` fires every matching instant in hand for every card, so a fix here would change instant rules game-wide.
- **nine_ruins_of_sanguine**:
  1. "can be hit (even by you)": nothing lets the player's cards or AoE strike Sanguine. Only enemies target him. Should player AoE include him, and should he be a valid target for offensive cards? This needs a targeting decision. BLOCKED: it is a new targeting rule, beyond a wiring fix.
  2. "Every attack grants 1 Vitality": Attack cards build Vitality, and spells correctly don't, but the basic attack (the Attack button) builds none. Does the basic attack count as "an attack" for Vitality? The same question applies to Fallen's Wrath's "your attacks deal +Wrath damage", which the basic attack also doesn't get.

### items_c

- **Quivers in the off hand (standard_quiver, shock_quiver, sack_of_bone_arrows).**
  A quiver can only be worn beside a bow, so it is always in the off hand,
  and every off-hand item takes the 0.9 modifier (rounded down). That makes
  Standard Quiver's +1 range and +1 AGI/DEX zero for everyone but Stephen,
  Shock Quiver's 2 Shock into 1, and trims every quiver stat. Should quivers
  be exempt from the off-hand modifier (they never have a main-hand option),
  or should their tooltips state the off-hand numbers?
- **Wrist Rocket: "pairs with a quiver".** The 2026-10-25 hand rule refuses a
  quiver beside it. Should the tooltip drop "pairs with a quiver", or should
  the Wrist Rocket be the one thrown weapon a quiver may accompany?
- **Slotted Rope Half Sleeve: its +3 on a card that blocks nothing.** The
  sleeve's "-3 block from your block cards" uses the same any-type channel as
  Thick Steel (the resolving card's first armor grant), so the on-self "+3 …
  armor on a card that blocks nothing" always nets 0. Should the -3 apply only
  to the card's own block (so a non-block card keeps the full +3 armor), or is
  the rider meant to cancel out there?

### passives

- **Vines Codependence** — "Whenever you heal": when Brad *is healed* (by
  anyone, his own heals and allies' — what the code does), or when Brad *casts*
  a heal (on himself or an ally, which Redemption's "when healing (self or
  ally)" does)?
- **Wither** — (CLAUDE.md open note) what does "+1 charge" mean per debuff?
  Today: +1 stack (5 tempo) on stack debuffs, +1 tempo on Disarm/Root/Curse,
  nothing on Stun/Silence/Narashimha/Polymorph/Mark/Trip (cooldown still spent).
  And should it fire only on debuffs Cory applies (today: any source — allies,
  traps, the enemy itself)?
- **Expel Negativity** — "2 charges, 10 tempo cooldown": should each spent
  charge come back 10 tempo after it was used, as In the Trenches does with the
  same words? Today both refill together only after both are spent.
- **Regrowth** — should a trigger that draws nothing (Cuffed, empty draw and
  discard piles) spend the 25→11 cooldown? And is "emptying your hand" only the
  moment the hand empties, or any time the hand is empty when the cooldown is
  up (today: any hand refresh while empty, a save loaded with an empty hand
  included)?
- **Mana Surge** — the text says the Mana Surge card is an "Attack"; it is a
  Spell (spell school, INT scaling, face reads "Spell"). Which? Should the
  100-mana window count mana when it is paid (play) or when the card resolves
  (today), and should a play paid in health (Demonic Rage) count?
- **Mad Scientist** — (a) Utility→Heal regen lasts 15 tempo; the text gives no
  duration — is 15 right? (b) "Potion cards" is implemented as every Pocket card
  (Dagger Throw, Quick Shot… only heal/poison ones do anything) — should it be
  the potion cards only? (c) A heal Poisoned Blood flips to damage on yourself
  or an ally counts as a "Poison" outcome but has no enemy to land on — intended?
- **Elemental Conclusion** — should it roll only on burn/cold/shock *Stephen*
  applies, and only once per application (not again on Harnessed Sun's +2 or
  Wither's +1)?

## Every entity

| name | type | status | what was wrong | what changed | test name |
|---|---|---|---|---|---|
| Absorb Essence (`absorb_essence`) | card | FIXED | "Delay: 10 tempo" was counted down 5 at a time on cycle ends, so the Energy Ball could arrive 6 tempo after the cast | `main._process_pending_absorb_essences(amount)` now runs on every tempo advance (moved out of the cycle end) | test_wiring_cards_a.gd::absorb_essence: Delay 10 tempo, then the Energy Ball; ::absorb_essence: no Energy Ball before the delay runs out; ::absorb_essence: a flat 1 to every enemy, however far |
| Adimantium Wall (`adimantium_wall`) | card | CORRECT | — | — | test_wiring_cards_a.gd::adimantium_wall: gain 40 block; ::adimantium_wall: jailed for 40 tempo after play |
| Adrenaline Shot (`adrenaline_shot`) | card | CORRECT | — | — | test_wiring_cards_a.gd::adrenaline_shot: two cards in the target's hand cost 3 less tempo; ::adrenaline_shot: 5 tempo later one card +3 and another +2 |
| Anticipation (`anticipation`) | card | CORRECT | — | — | test_wiring_cards_a.gd::anticipation: gain 1 mana (10 on the x10 scale); ::anticipation: a Prepare is shuffled into the draw pile |
| Approach (`approach`) | card | MISSING | "For each movement taken, gain 5 armor": the card armed `BuffManager.approach_armor_per_move` but nothing ever read it — steps gave no armor | `main._on_player_tile_reached` grants the stepper `approach_armor_per_move` armor per tile while `approach_tempo_remaining` > 0 | test_wiring_cards_a.gd::approach: each movement taken grants 5 armor; ::approach: a second step, 5 more; ::approach: once its 10 tempo are over, steps grant nothing; ::approach: Slowed for 10 tempo |
| Armor Break (`armor_break`) | card | CORRECT | — | — | test_wiring_cards_a.gd::armor_break: the next attack deals double damage to armor only; ::armor_break: does nothing to an unarmored enemy |
| Armor Patch (`armor_patch`) | card | CORRECT | — | — | test_wiring_cards_a.gd::armor_patch: on draw, gain 3 armor; ::armor_patch: on draw, Cleanse 1; ::armor_patch: immediately discarded |
| Armored Discipline (`armored_discipline`) | card | CORRECT | — | — | test_wiring_cards_a.gd::armored_discipline: Maintain 5M (50 reserved); ::armored_discipline: health damage taken becomes that much armor |
| Balance of Alnilam (`balance_of_alnilam`) | card | CORRECT | — | — | test_wiring_cards_a.gd::balance_of_alnilam: the only card in hand -> draw 6, up to the hand cap; ::balance_of_alnilam: with another card in hand, nothing is drawn |
| Balistic Arrow (`balistic_arrow`) | card | CORRECT | — | — | test_wiring_cards_a.gd::balistic_arrow: 30 damage to the first enemy and through it to the next in line; ::balistic_arrow: nothing off the line is hit |
| Barbed Exterior (`barbed_exterior`) | card | CORRECT | — | — | test_wiring_cards_a.gd::barbed_exterior: non-deteriorating (still 5 after two hits); ::barbed_exterior: non-removable (a buff purge leaves them); ::barbed_exterior: gone when no longer maintained |
| Bark Up (`bark_up`) | card | CORRECT | — | — | test_wiring_cards_a.gd::bark_up: every point of Regen (4) and Thorns (6) becomes armor |
| Barricade (`barricade`) | card | CORRECT | — | — | test_wiring_cards_a.gd::barricade: a wall 3 tiles wide directly in front of you |
| Basic Attack (`basic_attack`) | card | CORRECT | — | — | test_wiring_cards_a.gd::basic_attack: 10 damage with your weapon |
| Best Offense is a Good Defense (`best_offense`) | card | CORRECT | — | — | test_wiring_cards_a.gd::best_offense: 3 Smith while holding an attack card; ::best_offense: for 25 tempo; ::best_offense: 6 Smith instead when holding no attack card |
| Biscuit (`biscuit`) | card | CORRECT | — | — | test_wiring_cards_a.gd::biscuit: fully heals yourself; ::biscuit: +3 damage for 3 attacks |
| Blade Barrage (`blade_barrage`) | card | CORRECT | — | — | test_wiring_cards_a.gd::blade_barrage: X*10 with X = the attack cards in hand; ::blade_barrage: Glut 15 tempo; ::blade_barrage: while glutted no card can be played |
| Blink (`blink`) | card | CORRECT | — | — | test_wiring_cards_a.gd::blink: reaches up to 7 spaces; ::blink: teleports to the chosen point |
| Block (`block`) | card | CORRECT | — | — | test_wiring_cards_a.gd::block: 8 armor |
| Bloodlust (`bloodlust`) | card | CORRECT | — | — | test_wiring_cards_a.gd::bloodlust: 3 Vulnerable on yourself; ::bloodlust: gain 3 mana (30 on the x10 scale); ::bloodlust: the Strengthen ends after 20 tempo |
| Bob and Weave (`bob_and_weave`) | card | CORRECT | — | — | test_wiring_cards_a.gd::bob_and_weave: gain 5 armor and draw a card |
| Bottomless Quiver (`bottomless_quiver`) | card | CORRECT | — | — | test_wiring_cards_a.gd::bottomless_quiver: an overflowing attack is manifested, playable at full cost; ::bottomless_quiver: a non-attack overflow is discarded; ::bottomless_quiver: every overflowed card spends a charge |
| Bouncing Shield (`bouncing_shield`) | card | CORRECT | — | — | test_wiring_cards_a.gd::bouncing_shield: 5 to each enemy it bounces through, each within 5 of the last; ::bouncing_shield: 10 temporary mana per target; ::bouncing_shield: after 10 tempo it returns with the armor (also test_item_feedback.gd) |
| Braced Draw (`braced_draw`) | card | CORRECT | — | — | test_wiring_cards_a.gd::braced_draw: 8 armor and draw a card |
| Chain Lightning (`chain_lightning`) | card | CORRECT | — | — | test_wiring_cards_a.gd::chain_lightning: 10, then -2 per bounce to nearby enemies |
| Charge (`charge`) | card | FIXED | An enemy knocked back 2 landed further along the 5-tile path and was struck again (18 damage instead of 8+STR) | `main._apply_card_world_effects` "charge": each enemy takes the damage once; it is still shoved each time it is reached | test_wiring_cards_a.gd::charge: 8 damage to the enemy hit, once; ::charge: the enemy is knocked back; ::charge: you charge forward with no target needed |
| Choke (`choke`) | card | CORRECT | — | — | test_wiring_cards_a.gd::choke: Silence for 5 tempo; ::choke: Sticky 3 — back in hand after a use; ::choke: the 2 damage lands at the next cycle, once |
| Cinquedea (`cinquedea`) | card | CORRECT | — | — | test_wiring_cards_a.gd::cinquedea: range 4; ::cinquedea: 6 damage and 1 Weaken |
| Clang Up (`clang_up`) | card | CORRECT | — | — | test_wiring_cards_a.gd::clang_up: gain 10 block |
| Clear Mind (`clear_mind`) | card | CORRECT | — | — | test_wiring_cards_a.gd::clear_mind: purges the debuffs — whole stacks; ::clear_mind: draws 1 card for each debuff purged (2); ::clear_mind: at most 3 are purged |
| Close is Favored (`close_is_favored`) | card | CORRECT | — | — | test_wiring_cards_a.gd::close_is_favored: 13 damage to the enemy that came into melee range; ::close_is_favored: the card is erased (entry-only trigger: test_item_feedback.gd) |
| Collect Arrows (`collect_arrows`) | card | CORRECT | — | — | test_wiring_cards_a.gd::collect_arrows: the two chosen attack cards come back to hand; ::collect_arrows: Glut 15 tempo; ::collect_arrows: attack cards only (an offensive spell stays) |
| Communal Donation (`communal_donation`) | card | CORRECT | — | — | test_wiring_cards_a.gd::communal_donation: asks for the amount and its allocation; ::communal_donation: you take the chosen damage, past armor; ::communal_donation: the ally is healed from it |
| Whirling Weapon (`composed_reaction`) | card | FLAGGED | Fires on `PlayerStats.damage_taken`, which every damage source emits — DoT ticks (Burn, Poison, Choke), self-paid costs (Cultish Wounds, Communal Donation, Demonic Rage's health price) — not only "when you are attacked" | — (armor and melee-damage halves verified) | test_wiring_cards_a.gd::composed_reaction: when you are attacked, gain 5 armor; ::composed_reaction: and deal 5 to an enemy in melee range; ::composed_reaction: nothing is dealt when no enemy is in melee range |
| Composed Response (`composed_response`) | card | FIXED | Overflow with only an Overcharge active (this card's Overflow 5) popped the overflowed card off the draw pile and put it nowhere — the card left the deck for good (only the 5th was discarded) | `OverflowManager.process_overflow`: a card no primary effect (Jailed/Quiver/Manifest/Enhance/Skip) took is always discarded | test_wiring_cards_a.gd::composed_response: an overflow creates a Whirling Weapon in hand; ::composed_response: each overflow spends one of the five; ::composed_response: the overflowed card itself is discarded, not lost from the deck |
| Consecutive Snap (`consecutive_snap`) | card | CORRECT | — | — | test_wiring_cards_a.gd::consecutive_snap: each reuse costs -1m/-1t; ::consecutive_snap: each reuse +9 damage; ::consecutive_snap: Sticky 3 — it stays in hand |
| Cover (`cover`) | card | CORRECT | — | — | test_wiring_cards_a.gd::cover: the hit is reduced by the hand size, Cover included (3); ::cover: costs its 2 tempo (summons: test_card_sheet_pass.gd) |
| Crack of Mintaka (`crack_of_mintaka`) | card | CORRECT | — | — | test_wiring_cards_a.gd::crack_of_mintaka: 10 damage to an enemy within that many squares; ::crack_of_mintaka: 2 discards do not reach an enemy 3 squares away; ::crack_of_mintaka: +3% crit damage per card discarded |
| Crops (`crops`) | card | FIXED | A bushel could grow on the cell of an ally already standing there and was eaten on the next tempo — fewer than 5 bushels, and eaten without anyone walking over it | `main._apply_card_world_effects` "crops": cells occupied by an ally are skipped when placing | test_wiring_cards_a.gd::crops: every cast grows 5 bushels, none under an ally standing there; ::crops: walking over one eats it for 20 life and 20 mana; ::crops: bushels do not expire on their own |
| Cryonics (`cryonics`) | card | FIXED + FLAGGED | *(Phase 6 re-check)* Picking a summon as the ally encased and stunned the caster instead. | A summon pick is refused, nothing spent (`main.HERO_ONLY_ALLY_CARDS`). FLAGGED: should a summon count as Cryonics' "ally"? | test_recheck_fixes.gd::Cryonics / Friendship on a summon; test_wiring_cards_a.gd::cryonics: the encased ally is untargetable; ::cryonics: they cannot act; ::cryonics: heals 3 health per 5 tempo; ::cryonics: after 15 tempo the ice melts |
| Cultish Wounds (`cultish_wounds`) | card | CORRECT | — | — | test_wiring_cards_a.gd::cultish_wounds: Maintain 2M (20 reserved); ::cultish_wounds: 1 damage to self, ignoring armor; ::cultish_wounds: repeats every 5 tempo (the cycle) |
| Golden (`cupids_golden_arrow`) | card | CORRECT | — | — | test_wiring_cards_a.gd::cupids_golden_arrow: 10 damage and 2 Vulnerable; ::cupids_golden_arrow: on its 50%, taunted toward you for 5 tempo; ::cupids arrows: carrying both marks turns it into a tree for 4 tempo |
| Lead (`cupids_lead_arrow`) | card | CORRECT | — | — | test_wiring_cards_a.gd::cupids_lead_arrow: 2 Weaken; the fear only on its 50%; ::cupids_lead_arrow: on its 50%, fleeing from you for 5 tempo; ::cupids arrows: the tree regrows 3 health on each of its first 3 tempo, and ends after 4 |
| Curse of the Living (`curse_of_the_living`) | card | CORRECT | — | — | test_wiring_cards_a.gd::curse_of_the_living: every heal you take is halved (21 -> 11); ::curse_of_the_living: each ally is healed half of what remains, rounded up (6) |
| Dagger Throw (`dagger_throw`) | card | CORRECT | — | — | test_wiring_cards_a.gd::dagger_throw: 5 damage |
| Death Vortex (`death_vortex`) | card | FLAGGED | "After you are hit 5 times" counts every `damage_taken` emit — DoT ticks and self-paid costs wind the streak as well as enemy hits (same root as Whirling Weapon) | — (spin, damage and return verified) | test_wiring_cards_a.gd::death_vortex: after 5 hits, 15 to every adjacent enemy; ::death_vortex: if the Vortex kills, it returns to your hand |
| Deep Breaths (`deep_breaths`) | card | CORRECT | — | — | test_wiring_cards_a.gd::deep_breaths: heal 20 (through the heal pipeline) |
| Deep Pockets (`deep_pockets`) | card | CORRECT | — | — | test_wiring_cards_a.gd::deep_pockets: draws until a card costs more than 0 mana, then stops |
| Defensive Awareness (`defensive_awareness`) | card | CORRECT | — | — | test_wiring_cards_a.gd::defensive_awareness: 3 armor for each enemy within 2 spaces |
| Defensive Sacrifice (`defensive_sacrifice`) | card | CORRECT | — | — | test_wiring_cards_a.gd::defensive_sacrifice: discard a card, the damage is halved (20 -> 10); ::defensive_sacrifice: gain 10 mana; ::defensive_sacrifice: decline — the full hit lands and the card stays in hand |
| Demonic Rage (`demonic_rage`) | card | FIXED | The health price was paid through `take_damage`, so armor soaked it (with armor up, a "health" payment cost nothing); the quiver path also refused the play unless HP exceeded the raw mana cost (50 HP for a 50-mana card) instead of the 1-HP-per-mana price | `DeckManager.play_card` and `main.play_quiver_card` pay with `take_direct_damage`; the quiver check compares HP with the converted price | test_wiring_cards_a.gd::demonic_rage: the next mana use is paid in health, 1 per mana (2 for 20); ::demonic_rage: armor does not soak the health price; ::demonic_rage: one of the five uses spent; ::demonic_rage: a free card spends no use |
| Detonova (`detonova`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Detonova deals the banked 17 flat (no INT) to an enemy within 2 |
| Discard (`discard`) | card | FIXED | The random discard was not counted in `true_discards_this_cycle`, so it was not "a card discarded this cycle" for Exacerbate Wounds. | `Card._execute_discard` goes through `DeckManager.discard_card_from_hand` (counts it, emits the discard signals). | test_wiring_cards_b.gd::Discard's discard counts as a card discarded this cycle |
| Wish (`djinn_wish`) | card | CORRECT | — | — | test_wiring_cards_b.gd::a Wish held over a cycle sears its holder for 3 / Wish costs 60 mana / 0 tempo to play |
| Donate Cleats (`donate_cleats`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Donate Cleats grants the ally +5 AGI and +4 DEX / gone after 5 tempo |
| Down but not out (`down_but_not_out`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Down but not out heals 1 per debuff stack |
| Down Town (`down_town`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Down Town deals the auto attack's damage |
| Draw (`draw`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Draw draws a card |
| Earth Rattle (`earth_rattle`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Earth Rattle deals 40 to the impact and 3 squares around it / enemies hit are Slowed 2 and Weakened 2 |
| Element Pollination (`element_pollination`) | card | FLAGGED | Shock at 5 stacks gives a 5-tempo **Stun**, not Cold's **Frozen**. Burn's splash hits **every** enemy within 2.5, while Shock arcs to the **one** nearest. | — (design question) | test_wiring_cards_b.gd::Burn splashes its tick onto a nearby enemy / 5 Shock stacks lock the enemy for 5 tempo |
| Elixir (`elixir`) | card | CORRECT | — | — | test_wiring_cards_b.gd::poison a card applies under Elixir heals its target instead / the window closes after 25 tempo |
| Empower (`empower`) | card | CORRECT | — | — | test_wiring_cards_b.gd::the next 2 attack cards drawn are empowered, the third is not / an empowered attack deals +3 damage |
| Enchanted Quiver (`enchanted_quiver`) | card | CORRECT | — ("free 0-cost" is read as 0 mana; the Quick Arrow keeps the 2 tempo its own card sets) | — | test_wiring_cards_b.gd::the next 3 ranged attacks each put a Quick Arrow in hand, the 4th none |
| Enchantment: Attack (`enchantment_attack`) | card | CORRECT | — | — | test_wiring_cards_b.gd::a card deals +3 while it is in hand / Enchantment: Attack discards after 2 cycles |
| Enchantment: Defense (`enchantment_defense`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Enchantment: Defense -> +3 block on an armor gain |
| Enchantment: Mana Regen (`enchantment_mana_regen`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Enchantment: Mana Regen -> +1 mana regen |
| Enchantment: Movement (`enchantment_movement`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Enchantment: Movement -> 5 more tiles of flash per refresh |
| Endured Tolerance (`endured_tolerance`) | card | CORRECT | — | — | test_wiring_cards_b.gd::another copy adds 5 more tempo, not more % / its Erase fuse waits while Glutted |
| Energy Ball (`energy_ball`) | card | CORRECT | — (X is the base the spell pipeline scales, like every spell's number) | — | test_wiring_cards_b.gd::Energy Ball deals X = Absorb Essence's total (as a spell) / Energy Ball is erased after use |
| Energy Barrier (`energy_barrier`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Energy Barrier: gain 5 armor / Erase 1: gone at the next erase tick |
| Escape and bewilder (`escape_and_bewilder`) | card | FIXED | The blink went to wherever the cursor was when the card resolved (tick 1 of 2), not the tile clicked — so it could also land past the 5-space cap checked at click time. | Shared: `_resolve_queued_card` hands the play's aimed tile to `_apply_card_world_effects`, which uses it for point cards (`_resolving_aim_world`). | test_wiring_cards_b.gd::Escape and bewilder blinks up to 5 spaces to the aimed tile / an enemy within 3 of the vacated tile is stunned for 3 tempo |
| Exacerbate Wounds (`exacerbate_wounds`) | card | FIXED | A card thrown away by Discard did not count (see Discard). | Fixed in `Card._execute_discard`. | test_wiring_cards_b.gd::Exacerbate Wounds deals 3 x 2 discards through the STR pipeline |
| Exhausted Assault (`exhausted_assault`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Exhausted Assault deals 4 damage 3 times / Glut 10 after it resolves / at zero mana it costs 0 mana |
| Exposed Artery (`exposed_artery`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Exposed Artery deals 0.5 x 60% missing = 30 |
| Exposing Strike (`exposing_strike`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Exposing Strike: 10 damage and 1 Vulnerable |
| Feed into the Pain (`feed_into_the_pain`) | card | CORRECT | — | — | test_wiring_cards_b.gd::a hit below 30% health fires it / Strengthen 20 for 4 attacks / 25 temp HP for 5 tempo |
| Fire Punch (`fire_punch`) | card | CORRECT | — | — | test_wiring_cards_b.gd::a path of fire behind the target / a copy with Erase 5 lands in hand / the copy does not copy itself |
| Fireball (`fireball`) | card | FIXED | Resolving on tick 6, the blast centred on wherever the cursor had moved by then, not the aimed tile (range cap bypassable too). | Same shared aim fix as Escape and bewilder. | test_wiring_cards_b.gd::Fireball: 12 damage and 3 burn where it was aimed / the 4-square circle catches an enemy 2 from the centre / 1 less mana (10 on the x10 scale) per other fire spell this cycle |
| Fleet Etching (`fleet_etching`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Fleet Etching: Haste 1 for the next 2 moves (refusal unslotted: test_engrave.gd) |
| Forever Armor (`forever_armor`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Maintain: +6 max unerring armor |
| Fortify Alliance (`fortify_alliance`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Fortify Alliance heals the ally for 5 / and gives the caster 5 armor |
| Fountain of Health (`fountain_of_life`) | card | CORRECT | — | — | test_wiring_cards_b.gd::every cycle: 2 damage to self / and a card drawn |
| Friendship (`friendship`) | card | FIXED + FLAGGED | *(Phase 6 re-check)* Picking a summon as the first ally made the caster the first ally instead. | A summon pick is refused, nothing spent. FLAGGED: summons have no PlayerStats, so can a summon be linked? In solo with no partner the card has no second ally. | test_recheck_fixes.gd::Cryonics / Friendship on a summon; test_wiring_cards_b.gd::when one heals, both heal / damage is split / the bond lasts 5 tempo |
| From the Ashes (`from_the_ashes`) | card | CORRECT | — | — | test_wiring_cards_b.gd::enemies within 3 take 5 per stack purged / heal 5 per stack / Regen equal to half the stacks |
| Energy (`gain_mana`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Energy: gain 2 mana (20 on the x10 scale) |
| Gargle and Spit (`gargle_and_spit`) | card | CORRECT | — | — | test_wiring_cards_b.gd::heal 3 / +1 strength for 20 tempo / after the 4th play it is discarded |
| Gift from the Gods (`gift_from_the_gods`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Gain 3 Enlightened (10% crit chance) |
| Gift from the Phoenix (`gift_from_the_phoenix`) | card | FIXED | "Heal up to 80%" healed the gap to 80% and then `heal()` added the INT / healing-gear bonus on top, landing above 80%. | `main._on_player_health_changed` passes the base that lands exactly on 80% once the bonus is added. | test_wiring_cards_b.gd::heal up to 80% — not past it / 5 burn on the nearest enemy |
| Give In (`give_in`) | card | CORRECT | — | — | test_wiring_cards_b.gd::immediately gain 3 mana (30) / the next tempo-triggered draw does not happen |
| God of Thunder (`god_of_thunder`) | card | CORRECT | — | — | test_wiring_cards_b.gd::absorbs all shock within a diameter of 8 of the target / the bolt deals the shock absorbed |
| Grounding (`grounding`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Grounding costs 200 - 5 per Shock in reach / 10 damage to each enemy in the radius, shocked or not |
| Gulped Potion (`gulped_potion`) | card | CORRECT | — | — | test_wiring_cards_b.gd::heal 1 / gone after the 3rd play |
| Halo (`halo`) | card | FIXED | "Heal all allies … radius of 3" skipped summons, which the game counts as allies (Healthy Bliss heals them). | `main._process_maintained_card_effects` also heals every summon within 3. | test_wiring_cards_b.gd::summons inside the radius are allies too / an ally 5 squares away is outside the circle |
| Hard Helmet (`hard_helmet`) | card | FIXED | The 2 damage went to the triggering utility card's enemy target when it had one, not "the closest enemy". | `_fire_instant_site_effect` "hard_helmet" always picks `_get_nearest_enemy()`. | test_wiring_cards_b.gd::2 damage to the closest enemy / gain 8 armor |
| Harden (`harden`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Harden: 10 armor / 10% physical resistance for 15 tempo |
| Harness Lightning (`harness_lightning`) | card | CORRECT | — | — | test_wiring_cards_b.gd::an orb that strikes every 5 tempo for 30 tempo / 4 (INT-scaled) to an enemy within 3 each strike |
| Heal (`heal`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Heal: restore 4 HP |
| Healing Potion (`healing_potion`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Healing Potion: heal 5 |
| Healing Tonic (`healing_tonic`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Healing Tonic heals the ally for 5 / an ally 6 squares away is not |
| Healthy Bliss (`healthy_bliss`) | card | FIXED | The INT / healing bonus was applied twice: the sweep pre-boosted the 10, then `heal()` boosted it again. | `main._healthy_bliss_sweep` passes the base (after Blood Libation) to `heal()`, which adds the bonus once; summons get the boosted amount as before. | test_wiring_cards_b.gd::heals you for 10 / after 20 tempo in hand it fires |
| Healthy Habit (`healthy_habit`) | card | CORRECT | — | — | test_wiring_cards_b.gd::draw 2 cards / gain 2 mana (20) / Burden: the next play costs more |
| Heavy Greedy Cheese (`heavy_greedy_cheese`) | card | CORRECT | — | — | test_wiring_cards_b.gd::with the Cheese in hand another card costs +100 mana and +2 tempo / the Cheese itself: 25% of max mana and 5 tempo |
| Heavy Swing | card | CORRECT | — | — | test_wiring_cards_c.gd::Heavy Swing is refused while a non-offensive card (Block) is in hand; ::with only offensive cards beside it, it deals 20 (+STR); ::heavy_swing: played for its 30 mana / 3 tempo |
| Hemotoxins | card | CORRECT | — | — | test_wiring_cards_c.gd::Hemotoxins: 10 Poison on a healthy target; ::…20 Poison on a target below 50% health |
| Heroic Leap | card | CORRECT | — | — | test_wiring_cards_c.gd::Heroic Leap jumps STR (3) tiles; ::…and the landing hits for damage from the distance; ::a 1-tile hop deals less than the full leap |
| Hold the Line | card | CORRECT | — | — | test_wiring_cards_c.gd::Hold the Line: +5 armor; ::…+2 DET; ::…+2 STR (Might) for 15 tempo; ::…on every ally, not only you |
| Hope This Works | card | FLAGGED | "Provide STR for 3 attacks" is built as Strengthen +2 damage for the next 3 attacks. It is not +STR, and the text gives no amount. The heal, the 50% roll and ally targeting work. | — | test_wiring_cards_c.gd::Hope This Works (success): heals the ally 5 (+INT); ::…and Strengthens their next 3 attacks; ::…(fail) does nothing; ::…aimed at an ally, the ally is healed and strengthened, not the caster |
| House Money | card | CORRECT | — | — | test_wiring_cards_c.gd::House Money: the next odds are boosted to certain; ::…the chance card in hand re-rolls and triggers; ::…a multi-outcome card lands its best outcome |
| Huck | card | CORRECT | — | — | test_wiring_cards_c.gd::Huck: deals your armor (30) and you lose all of it |
| Hunker Down | card | CORRECT | — | — | test_wiring_cards_c.gd::Hunker Down: Fortify for 30 tempo |
| Ice Grenade | card | CORRECT | — | — | test_wiring_cards_c.gd::Ice Grenade: 5 damage (+INT) within 2 squares of the aim; ::…2 Cold on each enemy hit; ::…two shots: the grenade stays in hand after the first; ::…the second, aimed separately, lands where it is aimed and spends the card |
| If Pigs Could Fly | card | CORRECT | — | — | test_wiring_cards_c.gd::If Pigs Could Fly: 15 to the target and the area around it; ::…the area is INT/8 wide (INT 16: the next tile only) |
| Improvised Ammo | card | CORRECT | — | — | test_wiring_cards_c.gd::Improvised Ammo: 8 damage and 3 Weaken; ::…discarded: 4 damage to the nearest enemy; ::…and Improvised Ammo gains +10% crit; ::…permanently (saved with the character) |
| Infest | card | CORRECT | — | — | test_wiring_cards_c.gd::…hatches at 5 tempo in hand; ::…played (50 mana, 0 tempo) it is erased; ::…discarded it is erased and never hatches; the 2 Wererats: tests/test_rat_king_infest.gd |
| Internal Combustion | card | CORRECT | — | — | test_wiring_cards_c.gd::Internal Combustion: removes half your armor; ::…and deals that much around you |
| Item Mastery | card | CORRECT | — | — | test_wiring_cards_c.gd::Item Mastery: a card an item grants comes to hand; ::…and a card slotted in an item; ::…but no plain deck card |
| ITS ALIVE!!!!! | card | CORRECT | — | — | test_wiring_cards_c.gd::ITS ALIVE: the nearby corpse rises as Frankensteins Monster |
| Lady Luck | card | CORRECT | — | — | test_wiring_cards_c.gd::Lady Luck: the blessed ally gets +30% crit for 5 attacks; ::…aimed at an ally, the ally is blessed |
| Last Breath | card | FLAGGED | The text says "3 damage per mana spent". The code deals 3 per **10** mana (`mana * 0.3`), and its comment says this keeps the feel from before the x10 mana rescale. The HUD shows raw mana (for example 50/50), so the text no longer matches what the player sees. Consuming all mana works. | — | test_wiring_cards_c.gd::Last Breath consumes all remaining mana; ::…3 damage per 10 mana (x10 scale): 40 mana → 12 (+STR) |
| Lead Arrow | card | CORRECT | — | — | test_wiring_cards_c.gd::Lead Arrow: 1.8x damage; ::…clicking an enemy from flat ground does not fire it; ::(control: the same click fires Mixed Bag) |
| Lethal Recall | card | CORRECT | — | — | test_wiring_cards_c.gd::Lethal Recall: the last instant's effect triggers 2 more times |
| Life Steal | card | CORRECT | — | — | test_wiring_cards_c.gd::…the next attack heals for the damage it did (+INT, the heal pipeline); ::…once |
| Life Swap | card | FLAGGED | The text says "1 mana = 1 HP". The code exchanges 10 mana for 1 HP (the x10 rescale), and the HUD shows raw mana. The swap and the strike on the enemy in melee range work. | — | test_wiring_cards_c.gd::Life Swap: HP and mana pools exchange at 10 mana = 1 HP; ::…the HP lost (280) hits the enemy in melee range |
| Lightly Dazed | card | CORRECT | — | — | test_wiring_cards_c.gd::Lightly Dazed: Linger — joins a full hand; ::…erased after 40; ::lightly_dazed cannot be played from hand |
| Living Armor | card | CORRECT | — | — | test_wiring_cards_c.gd::Living Armor: Regen back up to the Fortify's number (3); ::…and never past it |
| Loaded Die | card | CORRECT | — | — | test_wiring_cards_c.gd::Loaded Die: the next chance card is +10%; ::…spent by the next card with a probability |
| M for Mini | card | CORRECT | — | — | test_wiring_cards_c.gd::M for Mini: 2 Vulnerable and 2 Weaken |
| Mage Shield | card | CORRECT | — | — | test_wiring_cards_c.gd::Mage Shield: taking damage fires it for 10 block |
| Magic Barrier | card | CORRECT | — | — | test_wiring_cards_c.gd::Magic Barrier: an incoming attack fires it for 8 armor; ::…and it is consumed (erased) |
| Mana Surge | card | FLAGGED | The text says "gain 1 mana". The code gives 10 mana (`gain_mana(10)`), which is 1 mana on the scale used before the x10 rescale. The HUD shows raw mana, so the player sees +10. The 5 damage and Erase work. | — | test_wiring_cards_c.gd::Mana Surge: 5 damage; ::…erased after play; ::…gains 10 mana on the x10 scale (text: 'gain 1 mana') |
| Mark | card | FLAGGED | The text says "extra damage from your **attacks**". The code raises **every** player hit by 15%, including spells (shown with Fireball), and any `take_damage(x, true)`. CARD_TAXONOMY treats "attack" as the Attack shape. The 15% and the 25 tempo work. | — | test_wiring_cards_c.gd::Mark: 25 tempo; ::…your hits on it land 15% harder; ::…and it wears off after 25 tempo; ::…(as built, a spell's hit is marked up too) |
| Meditate | card | CORRECT | — | — | test_wiring_cards_c.gd::Meditate: discards the hand and draws to full -2; ::…heals to 80%; ::…Glut 5 |
| Meister of Faustmesser | card | CORRECT | — | — | test_wiring_cards_c.gd::Meister of Faustmesser: zero-cost cards in the discard pile come to hand, others stay; ::…and the card is jailed for 20. (The hand cap still applies, as it does to every non-Linger card.) |
| Mend | card | FIXED | *(Phase 6 re-check)* Only heroes and Frankenstein's Monsters were restored; wolves, skeletons, worms, spirit bows, clones and the penguin in range got nothing. | Every friendly summon within 4 is restored (as Halo and the Greaves aura already were). | test_recheck_fixes.gd::Mend; test_wiring_cards_c.gd::Mend: 20% health (+INT) and 20% mana restored; ::…and armor equal to the health restored; ::…an ally within 4 squares too; ::…not one 6 squares away. (Of the summons, only Frankensteins are healed.) |
| Mind Mend | card | CORRECT | — | — | test_wiring_cards_c.gd::Mind Mend: costs 15 health, no mana; ::…restores 60 mana |
| Mind over Matter | card | CORRECT | — | — | test_wiring_cards_c.gd::Mind over Matter: the next hit is halved and paid in mana, 1 per point; ::…only the next hit; also tests/test_shields_pass.gd |
| Minor Wounds | card | CORRECT | — | — | test_wiring_cards_c.gd::Minor Wounds: 2 damage to self on draw; ::…Erase 40 |
| Mirror Mirror | card | CORRECT | — | — | test_wiring_cards_c.gd::Mirror Mirror: the chosen card is duplicated into the hand; ::…the duplicate has Erase 5 |
| Misery Loves Company | card | FLAGGED | The text says "your next AOE **attack**". The code fires on the next AOE of any kind, spells included: Ice Grenade, Poison Bomb, Fireball and Internal Combustion all call `_apply_misery_spread`. Spreading the debuffs (theirs and yours) works once. | — | test_wiring_cards_c.gd::Misery Loves Company: the next AOE spreads a hit enemy's debuff to every enemy hit; ::…and your own debuffs too; ::…once |
| Mixed Bag | card | CORRECT | — | — | test_wiring_cards_c.gd::Mixed Bag: a standard ranged arrow |
| Monk of the Night | card | CORRECT | — | — | test_wiring_cards_c.gd::Monk of the Night: maintained (50 mana held); ::…an attack grants 10% of its damage as block; ::…a spell does not |
| Morphine | card | FLAGGED | The text says "After 15 tempo, lose it and take 2 damage". The 2 damage lands at exactly 15 tempo (the buff's own timer). The 4 temp HP sit in the shared temp-HP pool, though, and that pool counts down 5 per **cycle** (`PlayerStats.process_turn`). So the temp HP goes at the third cycle boundary, anywhere from 11 to 15 tempo after the play. | — (fixing it means changing the shared temp-HP clock, and `test_coop_status_ticks.gd` asserts the cycle clock) | test_wiring_cards_c.gd::Morphine: +4 temp HP; ::…the temp HP goes on the third cycle boundary, 11-15 tempo; ::…then you take 2 damage |
| Multishot | card | CORRECT | — | — | test_wiring_cards_c.gd::Multishot: 7 damage 3 times; ::…Glut 5; ::…each hit gains 10% crit chance |
| Negotiate | card | CORRECT | — | — | test_wiring_cards_c.gd::Negotiate: steal 5 gold |
| Neither Man nor Beast | card | CORRECT | — | — (the comment on `_execute_neither_man_nor_beast` says "5 base damage", but the code reads `base_damage` = 10; left alone to avoid touching card.gd) | test_wiring_cards_c.gd::Neither Man nor Beast: 10 damage through armor and resistance; ::…the target cannot heal it back; ::…after 10 tempo it can |
| Oops | card | CORRECT | — | — | test_wiring_cards_c.gd::Oops outcome 0: 5 hits of 3; ::Oops outcome 1: 3 hits of 3; ::Oops outcome 2: 2 hits of 3; ::…30% / 40% / 30% |
| Out of Guesses | card | CORRECT | — | — | test_wiring_cards_c.gd::Out of Guesses: discards the hand and draws that many; ::…the old hand is in the discard pile |
| Paralysis | card | CORRECT | — | — | test_wiring_cards_c.gd::Paralysis: you cannot move while it is in hand; ::…play it (10 mana, 5 tempo) to tear it free — it is gone; ::…and you can move again |
| Parry | card | CORRECT | — | — | test_wiring_cards_c.gd::Parry: 5 armor, 5 damage; ::…10% physical resistance for 1 attack |
| Patience | card | CORRECT | — | — | test_wiring_cards_c.gd::Patience: the draw is due 15 tempo after the play; ::…in 15 tempo, draw 3 |
| Peshtigo's Kiss | card | CORRECT | — | — | tests/test_peshtigo_live.gd (hits for 10 + 5 per enemy in the INT/8 circle, asks to Maintain, burns for half every cycle, goes out when dismissed); test_wiring_cards_c.gd::peshtigos_kiss: played for its 60 mana / 5 tempo |
| Petey the Pet Rock | card | FIXED | *(Phase 6 re-check)* The Slowed went on only at a 5-tempo cycle boundary, only when none was there, so it fell to 1 stack between cycles, and nothing lifted it when Petey left the hand. | `main._sync_held_slow`: put on when drawn, topped back to 2 each cycle, lifted with the last copy (mirrors Release Soul's Drain). | test_recheck_fixes.gd::Petey; test_wiring_cards_c.gd::Petey: on draw, draw 3 cards; ::…while in hand: Slowed 2; ::…on discard: discard 2 cards |
| Poison Bomb | card | CORRECT | — | — | test_wiring_cards_c.gd::Poison Bomb: 6 Poison on every enemy within 2 squares; ::…none 3 squares out |
| Poisoned Blood | card | FIXED | The 5 charges sit on the caster, but a heal aimed at an ally resolved on the ally's buff manager. That manager has no Poisoned Blood, so the ally was healed instead of hurt. Heals on yourself and on summons already worked. | `DeckManager.execute_deferred_card` hands the caster's buff manager to `Card.execute` (`Card.caster_buff_manager`) during an ally-routed cast. Poisoned Blood reads and spends the caster's charges from it. | test_wiring_cards_d.gd::Poisoned Blood: a heal on an ally deals damage instead; ::that heal spent one instance; ::a heal on yourself deals damage instead; ::a heal on a summon deals damage instead; ::gone after 5 instances |
| Poke | card | CORRECT | — | — | test_wiring_cards_d.gd::Poke: 2 + half the modifiers; ::Poke is melee (the formula with real STR also: test_card_sheet_pass.gd::Poke = 2 + half the modifiers) |
| Polymorph | card | FIXED | The 5th-debuff trigger, the 25-tempo jail and the 5-tempo pig all worked. But a pig that had no action literally named `move` fell back to `actions[0]`. A polymorphed Fire Goblin Mage kept casting Ember, against "able only to walk and make basic melee attacks". | `Enemy._choose_action`: a pig walks with its own move action (`move`, else the first `MOVEMENT_ACTIONS` entry: goblin_move, hydra_move, scurry…). With neither a walk nor a bite it stands still. It never falls back to `actions[0]`. | test_wiring_cards_d.gd::the 5th distinct debuff fires it, and it is jailed 25 tempo; ::a pig walks — the mage's own move, never Ember; ::…even beside you a pig mage casts nothing; ::a pig beside you makes its basic melee attack; ::the pig wears off after 5 tempo |
| Poof and Weave | card | CORRECT | — | — | test_wiring_cards_d.gd::Poof and Weave: +10 armor; ::Poof and Weave: draws a card; ::Poof and Weave: invisible; ::the invisibility lasts 5 tempo |
| Potion of Continuance | card | CORRECT | — | — | test_wiring_cards_d.gd::Potion of Continuance: draws 2 |
| Preemptive Answer | card | CORRECT | — | — | test_wiring_cards_d.gd::Preemptive Answer fires on the hit that drops you to 25%; ::Preemptive Answer purges 3 debuffs; ::Preemptive Answer heals 20 (+heal power) |
| Premeditated | card | FIXED | *(Phase 6 re-check)* A second Premeditated at the exposed enemy did not carry the +15 (`card_id != "premeditated"`), so the bonus waited for a later card. | The exclusion is gone: "your next card" includes another Premeditated. | test_recheck_fixes.gd::Premeditated; test_wiring_cards_d.gd::Premeditated: breaking the armor marks the enemy for +15; ::the next card at that enemy deals +15 on top of its effect; ::…only the next one |
| Preparation | card | CORRECT | — | — | test_wiring_cards_d.gd::Preparation: the next utility card costs 2 less; ::Preparation: …and the one after; ::Preparation: the third pays full price |
| Prepare | card | CORRECT | — | — | test_wiring_cards_d.gd::Prepare: draws 3; ::Prepare: Erase 1 — erased at the next tick it sits in hand |
| Protection From Alnitak | card | CORRECT | — | — | test_wiring_cards_d.gd::Protection From Alnitak: +10 armor; ::Brace = empty hand slots (2%) for 5 attacks |
| Provider | card | CORRECT | — | — | test_wiring_cards_d.gd::Provider: heals the ally 6 (+their heal power); ::Provider: gives the ally 1 mana (10 on the x10 scale); ::Provider: Burden — the second play costs +1 mana / +1 tempo |
| Psionic Flow | card | CORRECT | — | — | test_wiring_cards_d.gd::Psionic Flow fires when you play an attack; ::…for +8 damage; ::…and pushes the target back 1; ::Psionic Flow fires when an ally within 3 squares takes damage; ::…restoring 8 to them; ::…and pushing the attacker back 1; ::whichever comes first: one card, one trigger |
| Purge Wrath | card | CORRECT | — | — | test_wiring_cards_d.gd::Purge Wrath: Wrath resets to 0; ::Purge Wrath: the next attack is armed with +20% and the flat +20; ::the next attack hits for its damage + the flat Wrath + Wrath%; ::…and only that attack |
| Push | card | FLAGGED | "Move a unit away from you 2 squares": the 2-square push works, but the card can only target enemies (`target_types` defaults to `["enemy"]`), so an ally cannot be pushed. | — | test_wiring_cards_d.gd::Push: the unit moves 2 squares away |
| Quick Arrow | card | FLAGGED | "A free ranged attack" (Enchanted Quiver: "a free 0-cost Quick Arrow"). It costs 0 mana but 2 tempo. Elsewhere in this slice "free" means 0 mana and 0 tempo (Shuriken, shift). The 4 damage at range 5 and the Enchanted Quiver creation work. | — | test_wiring_cards_d.gd::Quick Arrow: 0 mana; ::Quick Arrow: deals 4 (+modifiers) at range 5; ::Enchanted Quiver puts a Quick Arrow in hand after a ranged attack |
| Quick Shot | card | CORRECT | — | — | test_wiring_cards_d.gd::Quick Shot: 2 + half modifiers; ::Quick Shot: draws a card |
| Raged Circulation | card | CORRECT | — | — | test_wiring_cards_d.gd::Raged Circulation: the TARGET receives +30% healing; ::…not the caster; ::a heal lands 30% larger; ::regen lands 30% larger too; ::Raged Circulation ends after 15 tempo |
| Ragnarok | card | CORRECT | — | — | test_wiring_cards_d.gd::Ragnarok: every jailed card is released into the hand; ::Ragnarok: heals 10 per released card; ::Ragnarok: +10% crit and +5 STR per card; ::Ragnarok: jailed for 30 tempo after play |
| Rain of Arrows | card | CORRECT | — | — (it only exists as Castle Wall's Overdraw spell: shop- and drop-excluded, never dealt to a hand, cast by `Main._overdraw_cast_spell`) | test_wiring_cards_d.gd::Rain of Arrows: 10 damage within 3 squares; ::…and nothing beyond; ::…for its 45 mana |
| Reaper's Taking | card | CORRECT | — | — | test_wiring_cards_d.gd::Reaper's Taking fires when an enemy within 5 drops below 25%; ::…and deals 20; ::…after teleporting beside it |
| Reckless Strike | card | CORRECT | — | — | test_wiring_cards_d.gd::Reckless Strike: deals 15 (+modifiers); ::Reckless Strike: 2 Minor Wounds added to your deck |
| Regal Etching | card | CORRECT | — | — | test_wiring_cards_d.gd::Regal Etching: Engrave — refused while not slotted; ::Regal Etching: draws a card |
| Release Soul | card | CORRECT | — | — | test_wiring_cards_d.gd::Release Soul: Drain while held, saps 5 per 5-tempo cycle (1 per tempo); ::a cycle in hand saps 5; ::Release Soul: every Spirit Collector gains 5 Strengthen; ::Release Soul: released (erased), not discarded (also test_sheet_act1b.gd) |
| Release Tension | card | CORRECT | — | — | test_wiring_cards_d.gd::Release Tension: one stack of the CHOSEN debuff comes off; ::Release Tension: heals 3 per debuff removed |
| Reload | card | CORRECT | — | — | test_wiring_cards_d.gd::Reload: draws 3 |
| Repelled Block | card | CORRECT | — | — | test_wiring_cards_d.gd::Repelled Block: +5 armor; ::a fully blocked melee hit: 0 damage; ::…the enemy is pushed back 4; ::…and you are pushed back 2; ::if the armor gives out, you take the damage |
| Reposition | card | CORRECT | — | — | test_wiring_cards_d.gd::Reposition: the chosen card is discarded; ::Reposition: a new one is drawn |
| Resourceful Replenish | card | CORRECT | — | — | test_wiring_cards_d.gd::Resourceful Replenish: maintained; ::your attacks heal 5% of the damage dealt |
| Return Cut | card | FLAGGED | It fires when armor eats a whole hit and strikes the adjacent attacker with a +5% crit roll, as written. But the "melee strike" is `get_effective_physical_damage(0)`: STR only, with no base damage, so 1 damage at low STR. The auto attack strikes for base 3 through the same pipeline. | — | test_wiring_cards_d.gd::Return Cut fires when an attack fails to break your armor; ::…and counters with a melee strike |
| Reverberate Regrowth | card | CORRECT | — | — | test_wiring_cards_d.gd::the armor is broken through; ::…nothing comes back before 5 tempo; ::…the 10 armor the hit ate comes back 5 tempo later |
| Rise | card | FIXED | The pillar went up wherever the mouse was when the card resolved, 4 tempo after the click, not on the tile the player aimed at. (Shared cause, see below.) | `Main._apply_card_world_effects` uses the aimed tile for point cards, and Rise reads it instead of a fresh `get_mouse_world_position()`. | test_wiring_cards_d.gd::Rise: a structure stands on the map; ::…on the aimed tile |
| Risk It | card | CORRECT | — | — | test_wiring_cards_d.gd::Risk It: a 30% chance; ::Risk It: on success you receive the Biscuit; ::Risk It: on a miss, nothing |
| Roar | card | CORRECT | — | — | test_wiring_cards_d.gd::Roar: an enemy within 3 is knocked back 1; ::…an enemy 3 squares away too; ::…but not one 5 away |
| Roll | card | FIXED | The contact check used `get_enemy_at_position`'s default 1.0 reach, which also catches an enemy one square beyond the next. The roller stopped a square short of the character it hit and never touched it. The roll also took its direction from the cursor at resolution, 5 tempo after the click (the shared aim cause below). | Roll checks contact with half a square's reach, so only an enemy ON the next square ends the roll. It now aims at the clicked tile. | test_wiring_cards_d.gd::Roll: the roll ends on hitting a character; ::…an enemy takes 10; ::…and is disarmed for 5 tempo; ::Roll: X = its tempo cost, max 5 |
| Round 'Em Up | card | FIXED | "Pick a point. Enemies near it are displaced towards it." The pull centred on wherever the cursor was when the card resolved (3 tempo later), not on the picked point. | Shared aim fix (below). | test_wiring_cards_d.gd::Round 'Em Up: an enemy 2 from the picked point is pulled toward it; ::…one outside the 5 diameter stays put |
| Sanguine the Penguin | card | CORRECT | — | — | test_wiring_cards_d.gd::at 9 Vitality the instant fires; ::…the stacks purge; ::…Sanguine waddles forth with 50 HP; ::…beside you; ::…8 damage every 5 tempo; ::damage he takes heals you half as much; ::…and pecks a neighbour for 8 |
| Savage Strike | card | CORRECT | — | — | test_wiring_cards_d.gd::Savage Strike: deals 6 (+modifiers); ::Savage Strike: a copy lands in the discard pile; ::…the copy has Erase 20 |
| Savage Strike (copy) | card | CORRECT | — | — | test_wiring_cards_d.gd::the copy deals 6 (+modifiers); ::the copy makes no further copy; ::Erase 20: still there after 15 tempo in hand; ::Erase 20: erased after 20 tempo in hand |
| Self Infliction | card | CORRECT | — | — | test_wiring_cards_d.gd::Self Infliction: 80% of remaining health dealt to self; ::…+5 strength for 10 tempo; ::…+5 determination for 10 tempo |
| Serene Center | card | CORRECT | — | — | test_wiring_cards_d.gd::health = half max + half temp, temp consumed; ::mana = half its maximum, raised from 1; ::…or lowered |
| Shadows | card | CORRECT | — | — | test_wiring_cards_d.gd::Shadows: invisible; ::…still at 9 tempo; ::…gone after 10 tempo |
| Shed Weight | card | FIXED | "Discard all defensive cards" checked only `card_type == DEFENSE`. A defense-tagged instant (Vengeful Shield) stayed in hand, against the taxonomy's Defensive (`card_type == DEFENSE or has_keyword("defense")`, docs/CARD_TAXONOMY.md). | `_execute_shed_weight` uses the taxonomy test both to pick the discards and to pick the non-defensive cards that get the tempo cut. | test_wiring_cards_d.gd::Shed Weight: every defensive card is discarded — the Defense type and the defense-tagged instant; ::…and the non-defensive card loses 1 tempo per card discarded |
| Shepherd's Mark | card | CORRECT | — | — (the armor in the text is written in by `Card.create_shepherds_mark` from the Whispers of the Flock rank) | test_wiring_cards_d.gd::the ally is marked for 10 tempo; ::a lethal hit leaves them at 1 HP; ::…with 5 armor, the number on the card; ::…and the caster takes 8 |
| Shield of Growth | card | CORRECT | — | — | test_wiring_cards_d.gd::Shield of Growth: damage done to you grows your armor; ::…and you are disarmed; ::…still at 9 tempo; ::…both end after 10 tempo |
| Shield Ready | card | CORRECT | — | — | test_wiring_cards_d.gd::Shield Ready: Engrave; ::Shield Ready: +5 armor now; ::…5 more 5 tempo later |
| Shield Slam | card | CORRECT | — | — | test_wiring_cards_d.gd::Shield Slam: damage = your current armor; ::…then you lose half your armor |
| shift | card | CORRECT | — | — | test_wiring_cards_d.gd::shift: move up to 2 spaces; ::…not 3 |
| Shiv | card | CORRECT | — | — | test_wiring_cards_d.gd::Shiv: melee; ::Shiv: 2 damage (+modifiers) |
| Shuriken | card | CORRECT | — | — | test_wiring_cards_d.gd::Shuriken charges 0 mana / 0 tempo through the play path — Free; ::Shuriken: 3 (+modifiers) to an enemy within range; ::…never one out of range (3) |
| Shuriken Pouch | card | CORRECT | — | — | test_wiring_cards_d.gd::Shuriken Pouch: Manifest 3; ::an overflow card becomes a Shuriken; ::…free; ::the Shuriken deals 3 to a random enemy |
| Skeleton Army | card | FIXED | 4 skeletons with 10 HP, 6 damage every 5 tempo and 1 square every tempo, as written (also test_summon_cards.gd). But they stood up around wherever the cursor was when the 7-tempo cast resolved, not around the aimed point. | Shared aim fix (below). | test_wiring_cards_d.gd::Skeleton Army: 4 skeletons; ::…10 HP each, move 1 every tempo, 6 damage every 5 tempo; ::…standing up on and around the aimed point |
| sky_attack | card | CORRECT |  |  | wce::…and shoots for its damage plus High Ground's +4 |
| sky_fall | card | FIXED | "In 10 tempo, it lands": the arrow counted down 5 per tempo cycle, so it landed 5–10 tempo after the shot depending on where in the cycle it was loosed (1 tempo later when shot just before a cycle boundary). | `main._process_pending_sky_falls(amount)` now ticks on raw tempo from the tempo dispatcher, not on the cycle. | wce::phase 0: it lands on the 10th tempo counting the shot's own; wce::phase 3: … |
| slash | card | CORRECT |  |  | wce::Slash deals 10; Conditional: tests/test_conditional_range.gd |
| slice | card | CORRECT |  |  | wce::Slice deals 15 |
| smith_thy_soul | card | FLAGGED | Formula reads the raw mana pool (x10 code units); see Flagged. |  | wce::armor = ((health + mana) / 2) / 10 (raw pools) |
| smoke_bomb | card | CORRECT |  |  | wce::standing in the smoke: invisible; wce::…and +10% crit; wce::the cloud is gone after 8 tempo; wce::jailed for 20 tempo after play |
| snowballs_chance | card | CORRECT |  |  | wce::fire 3 spaces forward deals 10, no snowballs on a miss; wce::on the 50%, snowballs (4 each) also strike |
| song_of_a_swords_sing | card | FLAGGED | Kinds are counted before its own Disarm lands; see Flagged. |  | wce::disarms for 5 tempo; wce::3 Burn + 1 Weaken = 2 kinds = 4 armor |
| spark | card | CORRECT |  |  | wce::Spark deals 3; wce::-2 tempo on two cards in hand; wce::15 tempo later, +2 tempo back on two cards |
| specific_strike | card | CORRECT |  |  | wce::+1m (10) per other card in hand; wce::+1 tempo per other card in hand |
| spider_senses | card | CORRECT |  |  | wce::taking damage fires it: +5 armor |
| spirit_arrow | card | CORRECT |  |  | wce::pierces every enemy on the line for 8 |
| spirit_bow | card | CORRECT |  |  | wce::a 10-damage shot on the 4th tempo; wce::it dissolves once the mana is no longer reserved |
| splinter | card | CORRECT |  |  | wce::applies 1 Bleed, no damage; wce::range 3 |
| sprinkle | card | CORRECT |  |  | wce::Sprinkle deals 25; wce::Sprinkle is erased after play |
| sprinkle_bomb | card | CORRECT |  |  | wce::Sprinkle Bomb hits every enemy within 2 tiles for 25; wce::Sprinkle Bomb is erased after play |
| stance_switch | card | CORRECT |  |  | wce::removes 10 armor and applies 2 Vulnerable; wce::no armor: just 2 Vulnerable |
| stone_encase | card | CORRECT |  |  | wce::+50 armor; wce::stunned for 5 tempo |
| succumb | card | CORRECT |  |  | wce::Blessed 2 for 20 tempo (4 cycles); wce::after 10 tempo: takes the 10 damage; wce::…and CUFFED for 10 tempo |
| summon_battle_turtle | card | CORRECT |  |  | wce::summon_battle_turtle raises 1 battle_turtle; stat block: tests/test_summon_cards.gd |
| summon_shadow_hound | card | CORRECT |  |  | wce::summon_shadow_hound raises 1 shadow_hound; tests/test_summon_cards.gd::bites every 8 - INT/10 tempo |
| summon_skeleton | card | CORRECT |  |  | wce::summon_skeleton charges 42 mana (45 − INT 3); tests/test_summon_cards.gd::...and refunds INT - 45 |
| surrounding_ice | card | CORRECT |  |  | wce::hits within two squares for its damage; wce::a missed roll spares that enemy |
| swap | card | CORRECT |  |  | wce::switches positions with the enemy |
| sweeping_disarm | card | CORRECT |  |  | wce::surrounding enemies (diagonal too) disarmed for 5 tempo; wce::…and take 3 |
| switch_kick | card | CORRECT |  |  | wce::2 damage and Disarm for 5 tempo |
| taunt | card | CORRECT |  |  | wce::an enemy 3 squares away is taunted for 10 tempo; wce::one 4 squares away … is not |
| terrain_formation | card | CORRECT |  |  | wce::a hill rises where aimed; wce::gone after 5 tempo |
| territorial_mark | card | CORRECT |  |  | wce::deals 15; wce::an enemy 2 squares beside the arrow's path is Weakened; wce::the smoke lasts 25 tempo; wce::territorial_mark costs 35 health |
| the_lights_favor | card | CORRECT |  |  | wce::heals 5 (… after healing bonuses) and draws a card |
| the_nibelung_curse | card | CORRECT |  |  | wce::aimed at an enemy: deals the stored healing as damage; wce::aimed at yourself: takes the stored healing |
| thrown_stone | card | CORRECT |  |  | wce::On Draw: 4 damage to a random enemy; wce::played: 4 damage to an enemy |
| tight_rope | card | CORRECT |  |  | wce::a hit that puts you below 20% fires it; wce::+20 temp health for 5 tempo; wce::+15 damage on the next attack |
| tighten_string | card | FIXED | "Next 3 ranged attacks played": the charge was spent when the attack RESOLVED, so attacks queued before the first resolved were all strung (4 shots off 3 charges; the count went to -1). | The charge is spent in `main.play_selected_card` when the strung attack is played; `_undo_card_temp_mods` no longer spends it (a cancelled shot still keeps its charge spent, as before). | wce::queued before any resolves, only 3 of 4 ranged attacks are strung; wce::ranged attack 1: +3 tempo, +6 damage; wce::+6 range on the charged shot; wce::+20% crit on the charged shot |
| tower_shield | card | CORRECT |  |  | wce::+40 armor; wce::staggered for 40 tempo |
| trick_shot | card | CORRECT |  |  | wce::the 80% bounce repeats the hit on the next enemy; wce::never more than 4 bounces (80/60/40/20%) |
| tricks_of_alberich | card | CORRECT |  |  | wce::taunts enemies in a 4-square radius for 5 tempo; wce::+10 STR for the taunt's 5 tempo; wce::+4 armor per enemy taunted; wce::+2 Regen per enemy taunted |
| trip | card | CORRECT |  |  | wce::5 damage; wce::movement -4 for 10 tempo |
| try_this | card | CORRECT |  |  | wce::+3 mana pool, +2 hand size; wce::for 10 tempo; wce::the 10% reverse: -3 mana pool, -2 hand size |
| turtle_power | card | CORRECT |  |  | wce::turtle_power raises 3 battle_turtle; tests/test_summon_cards.gd::after 5 tempo it regains a fifth of the cap |
| turtle_up | card | CORRECT |  |  | wce::Fortify for 20 tempo |
| twenty_twenty | card | CORRECT |  |  | wce::+3 range on ranged offensive cards; wce::not on melee cards |
| understanding | card | CORRECT |  |  | wce::armed after 10 tempo; wce::the next damaging card auto-crits |
| vengeful_shield | card | CORRECT |  |  | wce::exposed: it fires for 5 armor; wce::…and stuns the enemy in melee range for 5 tempo |
| vined_encasing | card | FIXED | *(Phase 6 re-check)* Meeting thorns already up (Spiked Mitts, Spiked Shield…), the Vined thorns merged into them and lost their rule — the lot then fell 1 per hit; ordinary thorns gained later started shedding by damage. | `Buff.vined_value` keeps the Vined share inside the one Thorns buff: hits wear only the plain share, damage taken sheds only the Vined share. | test_recheck_fixes.gd::Vined Encasing; wce::1 thorn per armor (12) for 20 tempo, shed X per X damage |
| vines | card | CORRECT |  |  | wce::held in place for 15 tempo; wce::4 damage every 5 tempo, three times |
| volatile_mixture | card | CORRECT |  |  | wce::On Discard: 8 to the nearest enemy; wce::5 tempo in hand: discarded; wce::…after 8 self-damage |
| wear_down | card | FLAGGED | Card text omits the enemy-side limit (the reduction clears after the enemy's next 2 attacks); see Flagged. |  | wce::lasts 15 tempo; wce::a hit: enemy attack -1; wce::a consecutive hit: -2 |
| worms_armageddon | card | CORRECT |  |  | wce::23 damage to a single target; wce::the 10%: two Alaskan Bull Worms; wce::each 12 HP, 6 damage, burrowed |
| worst_that_could_happen | card | CORRECT |  |  | wce::heads: 5 damage +15; wce::tails: 5 damage, stunned 5 tempo |
| wrath_of_the_sea | card | CORRECT |  |  | wce::spends HALF your current mana; wce::the mana spent (plus STR) to every enemy in the 4x4; wce::shoved to the burst's edge; wce::+15 mana per enemy hit |
| Minion | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::MINION: Attack hits for its damage (3) |
| Elite | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::ELITE: Attack hits for its damage (5) |
| Boss | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::BOSS: Attack hits for its damage (11) |
| Wererat | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Wererat: Scurry dashes 5 tiles toward you (8 -> 3) |
| Skeleton | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Skeleton: Attack hits for 6 (scaled) |
| Armored Troll | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Troll: Smash adds a Lightly Dazed card (also regen, 30/15/15 resists, ~60% Smash, Kick 6) |
| Archer Rat | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Archer Rat: at range 6 it shoots (range 6 is the designer's 2026-10-21 call; `ENEMY_SHEET.tsv` still says 4) |
| Hydra | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Hydra: the 4th hit gives +40 max HP and unlocks Heal; heads: test_hydra_heads.gd; 190 HP and non-player hits: test_sheet_act1b.gd |
| Fire Goblin Soldier | enemy | FLAGGED | Text says "Range 0". The code gives it melee reach (adjacent), like every melee enemy. | — | test_wiring_enemies_a.gd::Goblin Soldier: Attack hits for 2 |
| Fire Goblin Mage | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Goblin Mage: Ember adds 1 Burn |
| Fire Goblin Shaman | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Goblin Shaman: walking into the wall burns you (6 + 3 Burn); …::Goblin Shaman: 8 damage while channeling breaks the Fire Wall; …::Goblin Shaman: Sear Wounds can kill |
| Giant Beaver | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Beaver: Tail Whip lays 5 Vulnerable stacks (5 tempo each) |
| Mini Bear | enemy | FLAGGED | Text: "+2 attack damage when a packmate in sight is hurt". The code counts only the player's own hits (`from_player`). DoT ticks, summons and allies' hits give nothing. | — | test_wiring_enemies_a.gd::Mini Bear: a packmate in sight hurt: +2 attack damage |
| Large Bear | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Large Bear: raging, attacks deal 1.5x (24); …::Large Bear: the resistance stays after healing above 50% (forever); …::Large Bear: Roar leaves everything within 4 squares Vulnerable |
| Wolf | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Wolf: and +2 HP regen a cycle |
| Coyote | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Coyote: Nip hits for 2 |
| Bugbear | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Bugbear: First Strike — +8 before you have hit it |
| Infected Hunter | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Hunter: Hook reaches range 7; Cleave rows, Net Throw and Hook recharge: test_sheet_act1b.gd |
| Giant Hawk | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Hawk: the high-ground check never favours you against it |
| Treant | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Treant: and heals for the total (7 thorns + 2 regen ticks); …::Treant: Root pins you for 8 tempo |
| Ice Mage | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Ice Mage: Frost Bolt Slows; totem: test_totems.gd |
| Fire Mage | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Fire Mage: Fire Bolt adds 2 Burn; totem: test_totems.gd |
| Spark Mage | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Spark Mage: Spark adds 1 Shock; totem: test_totems.gd |
| Air Mage | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::AIR_MAGE: gust hits for 5 (scaled); totem: test_totems.gd |
| Earth Mage | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Earth Mage: gains 4 armor every time it is hit; totem: test_totems.gd |
| Zombie | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Zombie: 3 spaces a shamble |
| Werewolf | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Werewolf: a debuffed target is raked a second time for half (16); …::Werewolf: +3 vs armor |
| Treasure Bunny | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Bunny: after 3 cycles (15 tempo) it vanishes; the smoke and no loot: test_treasure_bunny_vanish.gd |
| Vampire | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Vampire: the first Absorb drains 20 (scaled 21); …::Vampire: no charges back — no third Bat Form |
| Necromancer | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Necromancer: Bolt Hexes 2 cards (+30 mana, up to 25 tempo); Raise the Fallen: test_necromancer_rise.gd |
| Bone Dragon | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Bone Dragon: a Swarm hatches beside the one it hit; …::Bone Dragon: 1 health a cycle per standing gravestone (3 stones) |
| Spirit Collector | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Collector: its Strengthen never fades; Release Soul: test_sheet_act1b.gd; range casting: test_enemy_ranged_in_range.gd |
| Grave Titan | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Titan: Boulder Roll hits for 15 (scaled) |
| Crypt Crawler | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Crawler: after 3 consecutive attacks it webs you; floor webs: test_enemy_ranged_in_range.gd |
| Screecher | enemy | FLAGGED | Behaviour matches. The move is named twice: "Drift" in the action list, "Scuttle" in the prose. | — | test_wiring_enemies_a.gd::Screecher: while seen, 2 spaces for 5 tempo; …::Screecher: unseen, your direct attack finds nothing |
| The Consumed | enemy | FIXED | Text: "On death: explodes for 8 damage to everything nearby". The burst hit only `main.player` and enemies, never the player's summons (or a co-op second player). | `_consumed_explode` now hits every player-side unit (`_player_units()`) within the blast. | test_wiring_enemies_a.gd::Consumed: and on a summon beside it — everything nearby |
| Sludge | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Sludge: at range 6 it Spits |
| Pipe Crawler | enemy | CORRECT |  |  | test_wiring_enemies_b.gd::Pipe Crawler: about 25% of claws disarm (…); ::Pipe Crawler: the disarm lasts 5 tempo |
| Sewer Cobra (SEWER_CROC) | enemy | CORRECT |  |  | test_sheet_act1a.gd (Venom Spray cone, thorns, poison back, exposed stun and clock reset); test_wiring_enemies_b.gd::SEWER_CROC: armor 20 as the text quotes |
| Rat King | enemy | CORRECT |  |  | test_sheet_act1a.gd (Infest), test_rat_king_lair.gd (nest flights 50/30/30, 20/30/50% heals), test_rat_king_infest.gd |
| Swarm | enemy | CORRECT |  |  | test_wiring_enemies_b.gd::Swarm: Move is 8 spaces for 3 tempo; ::Swarm: Attack deals 3 |
| Weregoat | enemy | CORRECT |  |  | test_sheet_mountains.gd (Charge: lane damage, landing stun 3 tempo); test_weregoat_charge.gd |
| Wyvern | enemy | FIXED | Talon Grab's "unoccupied space 8 squares away" was any cell not marked blocked: about a third of grabs in the dojo dragged the player off the grid or into the rock past the walls (`_random_free_cell_at_distance` never checked the map) | `Enemy._random_free_cell_at_distance` now also requires `_can_stand_on` (floor, on the map, no pillar) | test_wiring_enemies_b.gd::Wyvern: the prey is dragged onto open floor, never off the map; ::Wyvern: then a 2-cycle (10 tempo) cooldown |
| Roc | enemy | CORRECT |  |  | test_sheet_mountains.gd (dive from 6, lands beside, 5-tempo cooldown, always retreats, Eye Scrape after 3 tempo for 2 Weakened) |
| Ice Troll | enemy | CORRECT |  |  | test_wiring_enemies_b.gd::Ice Troll: every attack adds a stack of Cold (5 tempo); ::Ice Troll: a freezing club triggers Clobber (50, band-scaled …) |
| Snow Wraith | enemy | CORRECT |  |  | test_wiring_enemies_b.gd::Snow Wraith: Snowball Slows for 3 tempo; ::Snow Wraith: Ice Blast +3 against armor |
| Granite Colossus | enemy | FLAGGED | Text gives "Move (5 tempo): 3 spaces" and then "it only stands"; its table is empty, so it never moves | none | test_wiring_enemies_b.gd::Granite Colossus: no actions on the sheet yet — it only stands; test_enemy_sheet_pass.gd (350 HP / 250 armor) |
| White Manticore | enemy | CORRECT |  |  | test_sheet_mountains.gd (Stinger: 8 Poison, 3 Clumsy stacks, 5-tempo cooldown) |
| Sabertooth Tiger | enemy | CORRECT |  |  | test_wiring_enemies_b.gd::Sabertooth: about 35% of strikes crit for 1.5x; ::Sabertooth: a crit inflicts 6 Bleed; ::Sunken Bite: 10 damage + 8 Bleed; test_sheet_mountains.gd (Track, Bite and Claw) |
| Cerberus | enemy | CORRECT |  |  | test_hellgate.gd (Bite heads, Venom Tail, Roar, Guardian of Death, Deathyard Dog); test_wiring_enemies_b.gd::Cerberus: Swipe lays 8 Bleed and no wound of its own |
| Succubus | enemy | CORRECT |  |  | test_wiring_enemies_b.gd::Succubus: Damaging Snap = missing mana / 20 + 4; test_succubus_drain.gd (drains 10 mana) |
| Demon | enemy | CORRECT |  |  | test_sheet_underworld.gd (Mimic); test_wiring_enemies_b.gd::Demon: Cuff — no draws for 15 tempo |
| Ifrit | enemy | CORRECT |  |  | test_wiring_enemies_b.gd::Ifrit: a unit inside the 5x5 is hit, one beside it is not; ::Ifrit: the 25 tiles keep burning for 3 tempo; ::Ifrit: a blow over 40 backflips it 3 squares away |
| Mind Eater | enemy | CORRECT |  |  | test_sheet_underworld.gd (Mind Slow +20 per card until played); test_wiring_enemies_b.gd::Mind Eater: Manipulate Mind Space — no draws for 15 tempo, from 5 squares |
| Specter | enemy | CORRECT |  |  | test_sheet_underworld.gd (Invisible 3 tempo); test_wiring_enemies_b.gd::Specter: Spirit Spit hits for 2 (…) at range 2 |
| Magma Spider | enemy | CORRECT |  |  | test_sheet_underworld.gd (Fire Web range 3, Slowed, 1 every 3 tempo; Fire Bounce 4 squares, trail 3 tempo) |
| Pit Fiend | enemy | CORRECT |  |  | test_wiring_enemies_b.gd::PIT_FIEND: a design mock-up with no moves, as the compendium says |
| Ash Harpy | enemy | CORRECT |  |  | test_sheet_underworld.gd (Card Steal from 5, once, card returns on death; Peck from 4 lands beside) |
| Inflamed Minotaur | enemy | FIXED | Labyrinth Leap uses the same helper as Talon Grab: "a random open tile" could be off the map or inside a wall (test_labyrinth passed only because the maze is walled all round) | same change as the Wyvern (shared helper) | test_wiring_enemies_b.gd::Minotaur: he lands on open floor; ::Minotaur: each Slow stack shortens the 14-space leap by 1; test_labyrinth.gd (Bull Rush, wake fire heals 10, Lost in the Labyrinth) |
| Cherub | enemy | CORRECT |  |  | test_sheet_underworld.gd (first arrow on entering 4, hidden 5 tempo, 10-tempo clock); test_cherub_arrow.gd |
| Djinn | enemy | CORRECT |  |  | test_wiring_enemies_b.gd::Djinn: …and bounds 4 squares on for 35 (…); ::Djinn: an attack on him puts 3 Wishes in the hand; ::Djinn: each Wish sears for 1/3 of the hit per cycle |
| Corrupted Archangel | enemy | CORRECT |  |  | test_wiring_enemies_b.gd::CORRUPTED_ARCHANGEL: a design mock-up with no moves, as the compendium says |
| Ring Wraith | enemy | CORRECT |  |  | test_wiring_enemies_b.gd::Ring Wraith: acts though you are invisible (…); ::Ring Wraith: the slain one resummons fresh, the wounded one returns as it was |
| Training Dummy | enemy | CORRECT |  |  | test_wiring_enemies_b.gd::Dummy: a killing blow only refills it; test_dojo.gd |
| Rat Nest | enemy | CORRECT |  |  | test_rat_king_lair.gd (15-HP structure, releases its archer once, feeds the king once) |
| Gravestone | enemy | CORRECT |  |  | test_boneyard.gd (10-HP structure, 1 regen per stone per cycle, never decays) |
| Grave Digger | enemy | CORRECT |  |  | test_boneyard.gd (walks to the stone, repairs in 8 tempo, three in all) |
| Hell's Door | enemy | CORRECT |  |  | test_hellgate.gd (seals at 75/50/33% for 10 tempo, feeds Guardian of Death) |
| Thanatos | enemy | FIXED | "each of his servants that falls … costs him 10 health": the echo went through his 40 armor (58 band-scaled) and 25% resist, so it cost 7 armor and no health at all | `_necro_rise_on_death`: when the summoner is Thanatos the 10 goes straight to health (`ignore_armor`); the Necromancer ("takes 10 damage") is unchanged | test_wiring_enemies_b.gd::Thanatos: …and costs him 10 health (…); ::Thanatos: Death Bolt hits for 15 at 6 squares; ::Thanatos: …and Hexes a card (+30 mana, 25 tempo) |
| Air Totem | enemy | CORRECT |  |  | test_totems.gd (vortex 3/2/1 extra tempo) |
| Earth Totem | enemy | CORRECT |  |  | test_totems.gd (heals its mage, not itself); test_wiring_enemies_b.gd::Earth Totem: Thorns — a direct hit on it costs the attacker 5 |
| Lightning Totem | enemy | CORRECT |  |  | test_wiring_enemies_b.gd::Lightning Totem: …and every other unit within 4; ::Lightning Totem: strikes the nearest of them (…) |
| Fire Totem | enemy | CORRECT |  |  | test_totems.gd (3 Burn within 3, not at 4) |
| Ice Totem | enemy | CORRECT |  |  | test_totems.gd (bursts for 1 + tempo stood, goes off at 10, crumbles with its mage) |
| Summon (base class) | summon | CORRECT |  |  | test_summon_debuffs.gd (enemy debuffs on summons); test_card_sheet_pass.gd (Cover on summons) |
| HealableSummon | summon | CORRECT |  |  | test_wiring_enemies_b.gd::Healable summon: heals land on it |
| MarkableSummon (Shepherd's Mark) | summon | CORRECT |  |  | test_wiring_enemies_b.gd::Markable summon: Shepherd's Mark — survives at 1 HP with its armor; ::Markable summon: …and the caster takes 8 |
| Spirit Bow (maintained) | summon | FLAGGED | The item says its bow summons gain "+2 damage … per living bow summon"; the code adds +2 per OTHER bow (a lone spirit bow hits for 10, as the Spirit Bow card says) but counts every bow, itself included, for the +5% crit | none | test_ranged_pass.gd (10 damage every 4 tempo); test_wiring_enemies_b.gd::Spirit Bow: with no mana held for it, it dissolves |
| Budded bow | summon | FLAGGED | *(Phase 6 re-check)* Same question as the Spirit Bow flag below: +2 damage per *other* bow, +5% crit per bow including itself. |  | test_ranged_pass.gd (6 damage every 5 tempo, any damage kills it); test_wiring_enemies_b.gd::Budded bows: up to 4 at once; ::Budded bow: …it withers after 2 attacks |
| Draupnir's duplicate (summoned_clone) | summon | CORRECT |  |  | test_rings_pass.gd (9th hit drips one, trigger waits); test_wiring_enemies_b.gd::Draupnir: a quarter of your health; ::Draupnir: only one at a time; ::Draupnir: when a duplicate dies, Strengthen |
| Bone-arrow skeleton (Sack of Bone Arrows) | summon | CORRECT |  |  | test_wiring_enemies_b.gd::Bone skeletons: up to 3 at once; ::Bone skeleton: the victim's half health, 5 damage, 4 squares a tempo, attacks every 5 tempo |
| Manifest spirit / golem (summoned_skeleton kinds) | summon | FLAGGED | No card or item text summons them: only the sandbox and the `summon_spirit` / `summon_golem` manifest branches in `main.gd`, which no data file produces | none | (none — no stated description) |
| Summon Skeleton / Skeleton Army | summon | CORRECT |  |  | test_summon_cards.gd (10 HP, 6 damage every 5 tempo, 1 space a tempo, 4 for the Army, outside the cap); test_summon_march.gd |
| Shadow Hound | summon | CORRECT |  |  | test_summon_cards.gd (10 HP, 4 damage every 8 − INT/10); test_summon_march.gd (2 spaces a tempo) |
| Battle Turtle / Turtle Power | summon | CORRECT |  |  | test_summon_cards.gd (25 HP, unerring armor INT/2, a fifth back every 5 tempo, shared with allies); test_summon_march.gd |
| Seance Specter (summoned_specter) | summon | CORRECT |  |  | test_wiring_enemies_b.gd::Seance specter: fades at 25 tempo; ::Seance specter: destroyed, its HP lands on its killer |
| Wolf (Gauntlets of Dungeon Mastering) | summon | CORRECT |  |  | test_wiring_enemies_b.gd::Wolves: a pack of 3 at most; ::Wolves: two pack-mates each bite for 6 (5 +20%); ::Wolf: 2 squares every 3 tempo |
| Alaskan Bull Worm | summon | CORRECT |  |  | test_wiring_enemies_b.gd::Bull Worm: untargetable while burrowed; ::Bull Worm: surfaces to attack, for 6; ::Bull Worm: 1 movement per tempo, still burrowed |
| Frankensteins Monster | summon | CORRECT |  |  | test_wiring_enemies_b.gd::Frankenstein: 50 + INT x0.8 HP, 10 + INT x0.25 attack, 5% + INT/10 resist (INT 40); ::Frankenstein: 4 spaces every 8 tempo; test_card_item_audit.gd (raised from the corpse) |
| Sanguine the Penguin | summon | CORRECT |  |  | test_wiring_enemies_b.gd::Sanguine: damage he takes heals you half as much (…); ::Sanguine: 8 damage every 5 tempo; test_item_feedback.gd (the Vitality summon) |
| abjurers_cane | item | CORRECT | — (note: an instant firing from hand also counts as a discard for the +3 block, as `trigger_reactions` emits `non_play_discard`) | — | T::Abjurers Cane: discarding a card grants 3 block; T::abjurers_cane is two-handed (its text says so); T::abjurers_cane grants ["defensive_sacrifice", "defensive_sacrifice"] |
| adimantium | item | CORRECT | — | — | T::Adimantium: an attack slotted in it gains 8 armor; T::Adimantium: each tile costs 1 extra tempo while worn; T::adimantium_wall: 35m / 4t, block 40; tests/test_chest_pass.gd (Adimantium: +10 armor when Exposed, cooldown armed (15 cycles)) |
| alchemeist_belt | item | CORRECT | — | — | T::Alchemeist belt: a 5-heal card heals 5 + 4% of max health; T::hemotoxins: 50m / 5t |
| armor_chopper | item | CORRECT | — | — | T::Armor Chopper: a melee attack card strips 10 more armor; tests/test_item_feedback.gd (auto attack shred) |
| assasian_belt | item | CORRECT | — | — | T::Assasian Belt: a slotted attack that hits applies 1 Vulnerable; T::assasian_belt grants ["shuriken", "shuriken"] |
| axes_axe | item | CORRECT | — | — | T::axes_axe: stats match its text; T::axes_axe grants ["death_vortex", "death_vortex", "death_vortex"]; tests/test_weapons_pass.gd (Axe's Axe banks 5 flash past the cap) |
| band_of_aid | item | CORRECT | — | — | T::Band of Aid: a slotted card that doesn't heal heals you 1 (+INT bonus); T::Band of Aid: a slotted 5-heal card heals 6 (+INT bonus) |
| baseball_hat | item | CORRECT | — | — | T::baseball_hat: stats match its text |
| belt_of_scrolls | item | CORRECT | — | — | T::belt_of_scrolls grants ["chain_lightning", "fire_punch", "ice_grenade"] |
| belt_of_wumbology | item | CORRECT | — | — | T::Belt of Wumbology: any slotted card grants Strengthen 10 for 2 attacks; T::m_for_mini: 15m / 2t |
| belthronding | item | CORRECT | — | — | T::Belthronding: four slotted plays leave 3 Close is Favored in hand; T::balistic_arrow: 75m / 5t, base_damage 30; tests/test_item_feedback.gd (Belthronding share: 10% within 3) |
| bessy | item | FLAGGED | The +25% vs Weakened is 25% of the card's base + flat bonuses before stat (STR) scaling, so it is well under 25% of the actual hit: +2 on a 161-damage Slash at high STR. | — | T::Bessy: a slotted attack on a Weakened enemy hits harder; T::Bessy: the attack-speed threshold is 5 higher while wielded; T::earth_rattle: 60m / 6t |
| bladed_doughnut | item | CORRECT | — | — | T::bladed_doughnut: stats match its text; tests/test_bladed_doughnut.gd (kill with doughnut equipped -> Sprinkle conjured into hand) |
| blast_stick | item | CORRECT | — | — | T::Blast Stick: an offensive spell costs 10% more; T::Blast Stick: +20% of the 88-mana cost as damage; T::blast_stick is two-handed |
| blink_boots | item | CORRECT | — | — | T::blink_boots grants ["blink", "blink"] |
| bloodbound_plate | item | FLAGGED | "+3 armor" has no consumer. `armor_bonus` is read only as a shield's Basic Block amount, so on a chest it does nothing. The "+2 on every armor gain" part works. | — | T::Bloodbound Plate: gaining 5 armor gains 7; T::Bloodbound Plate: '+3 armor' is data only — equipping it grants no armor (flagged) |
| blue_robe | item | CORRECT | — | — | T::blue_robe: stats match its text; tests/test_item_feedback.gd (a slotted Slash on a physical-resister lands as fire, unresisted) |
| boomerang | item | FLAGGED | The text says it "pairs with a quiver", but the 2026-10-25 ruling allows a quiver only beside a bow, so equipping a quiver next to the boomerang is refused. | — | T::Boomerang: a quiver is refused beside it (flagged: text says it pairs with one); tests/test_ranged_pass.gd (a quiver is refused beside the boomerang) |
| boot_holsters | item | FIXED | "If an instant, deal 10 damage to the nearest enemy within 3" never fired. The rider sat in `_helm_card_world_effects`, which runs only for played cards, and instants fire from the hand. Separately, cards in its plain slot read the item's riders (see dragon_skull). | The rider moved to `main._slotted_instant_fired`, hooked on `deck_manager.reaction_triggered` (emitted however an instant fires). It reads `card.get_on_self_bonus()`, so a plain slot gets nothing. | T::Boot Holsters: a slotted instant firing deals 10 to the nearest enemy within 3; T::Boot Holsters: an instant in the plain slot deals nothing; T::Boot Holsters: a slotted attack costs 1 less tempo |
| boots_of_speed | item | CORRECT | — | — | T::Boots of Speed: after 36 flash spent moving, a hand card loses 1 tempo |
| boots_of_the_balancer | item | CORRECT | — | — | T::Boots of the Balancer: +20 armor at 4 steps missing; T::boots_of_the_balancer grants ["tight_rope"] |
| bow_of_arash | item | CORRECT | — | — | T::Bow of Arash: a ranged offensive card gains 2 range; T::Bow of Arash: a slotted card pays half its 80 mana as life; T::territorial_mark: 45m / 5t, health_cost 35; T::Territorial Mark: range 10 |
| bow_of_budding_blasts | item | CORRECT | — | — | T::Budding Blasts: buds cap at 4; T::a bud: 6 damage every 5 tempo, 2 shots; T::a bud dies to any damage; T::Budding Blasts: a slotted attack gains +2 per living bow; T::Budding Blasts: a crit with a slotted attack buds a bow; T::spirit_bow: 65m / 3t |
| brass_knuckles | item | CORRECT | — | — | T::Brass Knuckles: a melee offensive card deals +2; T::Brass Knuckles: 1 unerring armor at 20 tempo |
| briarhide_plate | item | CORRECT | — | — | T::briarhide_plate: stats match its text; T::vined_encasing: 50m / 4t; tests/test_chest_pass.gd (Briarhide exposed armor) |
| brown_boots | item | CORRECT | — | — | T::brown_boots: stats match its text |
| buckler | item | CORRECT | — | — | T::Buckler: a 20 hit lands 3 lighter |
| buffed_leather | item | CORRECT | — | — | T::buffed_leather: stats match its text |
| burgonet | item | CORRECT | — | — | T::burgonet: 2 unerring armor every 5 tempo; T::burgonet: the counter resets when unequipped |
| capacious_extremus | item | CORRECT | — | — | T::Capacious Extremus: a slotted card costs 10% less; T::Capacious Extremus: 5 slots, 4 bonus and 1 plain |
| captain_planets_circlet | item | CORRECT | — (note: with a 4-card hand the payout of draw 3 plus Fireball plus Rise overflows, and a full hand turns cards away) | — | T::Captain Planet: all five heal 15; T::Captain Planet: draw 3 and add a Fireball and a Rise; T::Captain Planet: the conjured pair carries Erase 10 |
| car_battery | item | CORRECT | — | — | T::Car Battery: a slotted attack applies 3 Shock; T::Car Battery: a card in the plain slot applies none; T::car_battery is two-handed |
| caster_boots | item | CORRECT | — | — | T::Caster Boots: a slotted damaging card deals +10% of INT |
| castle_wall | item | CORRECT | — | — | T::Castle wall: hand size 3 smaller; T::Castle wall: a slotted block card blocks 8 more; T::huck: 100m / 5t; tests/test_overdraw_riders.gd, tests/test_shields_pass.gd (Overdraw heal + Rain of Arrows, 3 charges, one per 15 tempo) |
| chain_crocs | item | CORRECT | — | — | T::Chain Crocs: a slotted card costs 20% less; T::chain_crocs: 5 unerring armor every 15 tempo |
| chain_gloves | item | CORRECT | — (note: the text omits Guard's 5-mana cost) | — | T::chain_gloves: 1 unerring armor every 15 tempo; T::Chain Gloves: Guard gains 2 armor; T::chain_gloves: ready again after 20 tempo |
| chain_mail | item | CORRECT | — | — | T::chain_mail: 8 unerring armor every 15 tempo; T::chain_mail: the grant stops at the unerring cap; T::clang_up: 20m / 5t, block 10 |
| chewbaccas_bandolier | item | CORRECT | — | — | T::Chewbaccas: a slotted ranged attack costs 1 less tempo; T::Chewbaccas: a slotted ranged attack deals +5; T::Chewbaccas: after 5 tempo it explodes for 8; T::Chewbaccas: an enemy stepping on it sets it off at once; T::Chewbaccas: the casing never hurts you |
| circes_wand_of_cauldron_stirring | item | CORRECT | — | — | T::Circe's Wand: an attack (slotted or not) Silences 5 tempo; T::circes_wand_of_cauldron_stirring grants ["polymorph", "polymorph"] |
| cloth_bracer | item | CORRECT | — (note: the text omits Band aid's 10-mana cost) | — | T::Cloth bracer: Band aid heals 5 (+INT bonus); T::cloth_bracer: ready again after 20 tempo; T::cloth_bracer: stats match its text |
| cloth_slippers | item | CORRECT | — | — | T::cloth_slippers: stats match its text |
| coffin_lid | item | CORRECT | — | — | T::Coffin Lid: a slotted attack heals 10% of its 159 damage; T::Coffin Lid: below half health, +8% lifesteal; T::curse_of_the_living: 65m / 7t |
| concealed_carry | item | CORRECT | — | — | T::Concealed Carry: Lethal Poke is a 0-base melee hit; T::Concealed Carry: a Lethal Poke crit deals x1.5 on top of the crit; T::concealed_carry: ready again after 15 tempo; T::concealed_carry grants ["smoke_bomb"] |
| construction_hammer | item | CORRECT | — | — | T::construction_hammer grants ["hard_helmet"]; T::hard_helmet is an instant |
| copper_bracers | item | CORRECT | — | — | T::Copper Bracers: Clang gains 8 armor for 25 mana; T::copper_bracers: ready again after 15 tempo |
| corset_of_cure | item | FIXED | Two bugs in the cleanse. (1) It subtracted 3 from `Debuff.stacks`, which counts applications and is almost always 1, so it removed the whole debuff instead of 3 stacks; the stack count lives in `value`. (2) A slotted card with no target (an instant firing, an untargeted play) errored out of `Card._execute_card` on `null.has_method`, skipping the rest of the play's cleanup. | `card.gd`: the cleanse takes 3 off `value` (removing the debuff at 0) and is guarded against a null target. | T::Corset of Cure: a slotted card aimed at you cleanses 3 stacks; T::Corset of Cure: a slotted card with no target resolves cleanly (no error mid-play); T::Corset of Cure: a debuff leaving you puts a Healing Tonic in hand; T::Healing Tonic: 0m/0t, range 5, heal 5 |
| crooked_dueling_shield | item | CORRECT | — | — | T::Crooked: the blue card applies 1 Weaken; T::Crooked: the red card applies 1 Vulnerable; T::Crooked: red right after blue gains 10 armor; T::Crooked: a fully blocked attack Weakens the attacker 2; T::Crooked: blocking an already-Weakened attacker deals 5; tests/test_shields_pass.gd (crit riders) |
| cross_bow | item | CORRECT | — | — | T::cross_bow: stats match its text; T::cross_bow (a bow) needs both hands |
| cuffs_of_current | item | CORRECT | — | — | T::Cuffs of Current: a free draw on the 3rd cycle; T::Cuffs of Current: Zeet deals INT/2 for 35 mana; T::cuffs_of_current: ready again after 15 tempo |
| cupids_bow | item | CORRECT | — | — | T::cupids_bow grants ["cupids_golden_arrow", "cupids_lead_arrow"]; T::cupids_golden_arrow: 45m / 3t, base_damage 10; T::cupids_lead_arrow: 45m / 3t, base_damage 10 |
| cyclops_ring | item | CORRECT | — | — | T::Cyclops Ring: the third 25+ hit grants Strengthen 15 for 2 hits; T::Cyclops Ring: the two strengthened hits don't feed the counter |
| cyde_livingstons_sneakers | item | CORRECT | — | — | T::Cyde: the 5th consecutive attack draws a card; T::Cyde: a non-attack card breaks the streak; T::donate_cleats: 35m / 0t |
| delfins_deterministic_round_shield | item | CORRECT | — | — | T::Delfins: a 90% roll becomes 100% slotted; T::Delfins: Overdraw peaks the next 4 cards of the draw pile; T::mage_shield: 0m / 0t, block 10 |
| diamond_ring | item | CORRECT | — | — | T::Diamond Ring: a 100 hit lands as 97 |
| divine_resistance | item | CORRECT | — | — | T::Divine Resistance: 6% resist at 50% missing; T::preemptive_answer is an instant |
| dragon_skull | item | FIXED | A card in its plain (vanilla) slot still got "+1 range". `main._helm_range_bonus` read `slotted_in_item.get_on_self_bonus()` (the item's riders) instead of the card's own bonus, which is neutral in a plain slot. `_helm_card_world_effects` did the same. | Both read `card.get_on_self_bonus()`. This is a shared helper, so Monocle, Shamans mask, Tactical belt, Houdinis Slippers, Slotted Sash, Dungeon Mastering and Shadow Cowl get the same plain-slot rule. | T::Dragon Skull: any slotted offensive card gains 1 range; T::Dragon Skull: a card in the plain slot gains no range; T::Dragon Skull: a crit breathes 10 + INT/2 fire in the cone; T::Dragon Skull: the cone reaches 3 squares, not 5 |
| draupnir | item | CORRECT | — | — | T::Draupnir: the 9th hit drips a duplicate; T::Draupnir: the duplicate has a quarter of your health; T::Draupnir: swings every 7 tempo, moves 2 squares per 3 tempo; T::Draupnir: only one at a time; T::Draupnir: the duplicate dying grants Strengthen 10 for 2 attacks |
| dunce_cap | item | CORRECT | — | — | T::dunce_cap: stats match its text |
| earth_book | item | CORRECT | — (note: the on-self 3 armor makes any slotted card armor-granting, so the book's own +1 block rides it: 4 armor) | — | T::Earth Book: an offensive card deals +1; T::Earth Book: an armor-granting card grants +1 block; T::Earth Book: any slotted card gains you 3 armor (+1 from the book's own block bonus) |
| elemental_emblem | item | CORRECT | — | — | T::elemental_emblem: stats match its text; T::Elemental emblem is a shield with plain slots only |
| elemental_trail_blazers | item | CORRECT | — | — | T::Trail Blazers: a tempo move leaves no fire; T::Trail Blazers: a flash move leaves a fire spot (INT/5, 3 tempo); T::Trail Blazers: an enemy on it takes INT/5 and the fire goes out; T::Trail Blazers: it burns out at 3 tempo |
| elemental_weaver | item | CORRECT | — | — | T::Elemental Weaver: 3 Burn applied deals 3; T::Elemental Weaver: 2 Shock applied deals 2; T::elemental_weaver is two-handed; T::element_pollination is a Maintain |
| elvish_cloak | item | CORRECT | — | — | T::Elvish Cloak: a slotted ranged attack deals +2; T::Elvish Cloak: a slotted melee attack gains nothing |
| emerald | item | CORRECT | — | — | T::emerald: the 5th Poison zaps an enemy within 5 for 2 |
| equator | item | CORRECT | — | — | T::equator: a slotted Slash that hits applies 4 burn_stacks; T::serene_center costs 30 mana, 4 tempo as its item says |
| fallens_wrath | item | FIXED | The on-self "1.5x damage" scaled only the card's base and riders, before STR, so a hit landed short of 1.5x (19 instead of 21 in the dojo). The rebound was half of that smaller bonus. | `card.gd`: the overdrive now sets the end-of-pipeline `PlayerStats.hit_multiplier`, as Megingjörð does. `progression_triggers.modify_player_hit` records what the multiplier adds, and `Card.pay_overdrive_rebound` charges half of it when the play closes. | T::fallens_wrath: a slotted card deals 1.5x the whole hit; T::fallens_wrath: and you take half the bonus yourself; T::fallens_wrath: your attacks deal +Wrath damage; T::fallens_wrath: Wrath caps at 30; test_weapons_pass (10+ Wrath: hits land 50% harder) |
| fanned_bracers | item | CORRECT | — | — | T::fanned_bracers: Fan Save inflicts 1 Weaken; T::Fanned Bracers: 10 tempo cooldown |
| feathered_hat | item | CORRECT | — | — | T::feathered_hat: the 25th flash point arms a crit and resets the counter; T::feathered_hat: the next ranged offensive card crits and spends it; T::feathered_hat: a slotted card resolves with +10% crit damage |
| feral_evocation | item | FIXED | Its colored slots also ran the Staff label gate. Only Fireball and Peshtigo's Kiss carry that label, so the blue, yellow and green slots could never be filled and no conversion could happen. This is why `test_spell_weapons_pass` was failing on the base commit. | `item_data.gd` `_slot_gate_ok`: on a colored slot, the card's element alone decides. | T::feral_evocation: playing the red card turns the blue card in hand red; T::feral_evocation: the conversion deals 4 damage to an enemy within 4; T::feral_evocation: a converted card reverts once it has left the hand; test_spell_weapons_pass |
| fire_book | item | BLOCKED | *(Phase 6 re-check)* The Burn rides only cards aimed at one enemy; area and point cards (played with you as the target) get the +1 damage but never Burn. | BLOCKED with Life Steal: needs a shared on-hit hook for main.gd's area hits. | T::fire_book: an unslotted Slash applies 1 burn_stacks; T::fire_book: an unslotted Slash deals +1 |
| fire_quiver | item | CORRECT | — | — | T::fire_quiver: a slotted damaging card deals +2; T::fire_quiver: a slotted Slash that hits applies 1 burn_stacks |
| frankensteins_screws | item | CORRECT | — | — | T::frankensteins_screws: a summon below 25% beside you heals 3; T::its_alive costs 20 mana, 5 tempo as its item says |
| friendship_ring | item | CORRECT | — | — | T::friendship_ring: heals are 5 larger |
| frost_book | item | CORRECT | — | — | T::frost_book: an unslotted Slash applies 1 cold_stacks |
| frost_quiver | item | CORRECT | — | — | T::frost_quiver: a slotted Draw gains you 2 armor; T::frost_quiver: a slotted Slash that hits applies 1 cold_stacks |
| gauntlets_of_dungeon_mastering | item | FIXED | A card in one of its plain (vanilla) slots also summoned a wolf: `main._helm_card_world_effects` read the riders straight off the item. | `main.gd`: the riders are read through the card (`Card.get_on_self_bonus`), so a plain slot stays neutral. Shared helper; see below. | T::gauntlets_of_dungeon_mastering: any slotted card summons a wolf, up to a pack of 3; T::gauntlets_of_dungeon_mastering: a plain-slot card summons no wolf; T::gauntlets_of_dungeon_mastering: a wolf with one packmate bites for +20% and 2 Bleed; T::House Rule puts the picked discard card in your hand |
| girdle_of_aphrodite | item | CORRECT | — | — | T::girdle_of_aphrodite: a slotted offensive card Taunts its target for 15 tempo; T::girdle_of_aphrodite: a slotted defense card heals its target 15; test_item_feedback |
| gold_band | item | CORRECT | — | — | T::gold_band: 10 shield gained -> two zaps of 2 |
| gravity_gauntlets | item | CORRECT | — | — | T::gravity_gauntlets: a slotted offensive card holds the target 5 tempo; T::gravity_gauntlets: an enemy 2 squares off is pulled into the target area |
| guardian_greaves | item | FIXED | "Restore 6 health … to all allies (you included) within 4": among summons, only Frankenstein's Monsters were healed. Wolves, skeletons, bows, worms and the penguin were skipped, though `main._all_summons` defines them as allies for card text. | `main.gd` `_helm_on_cycle_passives`: the aura heals every summon from `_all_summons()` within the radius. | T::guardian_greaves: an ally summon within 4 regains 6 too; T::guardian_greaves: you regain 6 health a cycle; T::guardian_greaves: and 5% physical resistance inside the aura |
| hallowed_trunk | item | FLAGGED | *(Phase 6 re-check)* Only armor taken by hits counts toward "every 10 armor removed"; the 2-per-cycle armor decay does not. Should decay count? | — | T::hallowed_trunk: the 10th armor point removed grants 1 Regen; T::hallowed_trunk: imbue tree grants 5 Regen and 10 Thorns |
| hammer_of_ajax | item | CORRECT | — | — | T::hammer_of_ajax: a slotted offensive card adds 10% of max health |
| hannibals_mask | item | CORRECT | — | — | T::hannibals_mask: a slotted attack heals 15% of its damage; T::hannibals_mask: Resourceful Replenish maintained — attacks lifesteal 5% |
| harnessed_sun | item | CORRECT | — | — | T::harnessed_sun: a 1-Burn application lands as 3 (+2); T::harnessed_sun: the 25th Burn cleanses a debuff on you |
| heal_stone | item | CORRECT | — | — | T::heal_stone: a heal of 5+ zaps an enemy for 2; T::heal_stone: lifesteal does not count; T::heal_stone: regen does not count |
| hermes_boots | item | CORRECT | — | — | T::hermes_boots: any slotted card restores 1 flash point; T::hermes_boots: a trap springing on an enemy deals 25% more |
| hide_of_garmr | item | CORRECT | — | — | T::hide_of_garmr: equipping gives exactly the described stats; T::ragnarok costs 45 mana, 5 tempo as its item says |
| holster | item | CORRECT | — | — | T::holster: a slotted damaging card deals +2 |
| horned_nasal_helm | item | CORRECT | — | — | T::horned_nasal_helm: a slotted Slash that hits applies 1 bleed_stacks; T::horned_nasal_helm: at 15 tempo 2 random debuffs are purged |
| houdinis_slippers | item | FIXED | A plain-slot card also made you invisible, for the same reason as Dungeon Mastering. | Same `main.gd` fix. | T::houdinis_slippers: any slotted card makes you invisible for 5 tempo; T::houdinis_slippers: a plain-slot card does not |
| ice_orb | item | CORRECT | — | — | T::ice_orb: an unslotted Slash applies 2 cold_stacks; T::ice_orb: an unslotted Slash deals +2 |
| jordan_1s | item | FIXED | "Below 50% enemy health": the bonus also fired at exactly 50% (+25 on any hit). | `enemy.gd`: `<` instead of `<=` at both sites (the damage preview and `take_damage`). | T::jordan_1s: at exactly 50% no bonus; T::jordan_1s: at 40% a 10 hit gains 0.5 x 60 = 30 |
| kettle_hat | item | CORRECT | — | — | T::kettle_hat: at 15 tempo, +2 unerring armor; T::kettle_hat: unequipping resets the counter; test_unerring_armor |
| knife_toed_boots | item | CORRECT | — | — | T::knife_toed_boots: a melee crit lands the multiplied hit +10; T::knife_toed_boots: a ranged card does not; T::knife_toed_boots: Shiv is a 2-damage melee card |
| laurentius_lost_spear | item | FLAGGED | Both granted Psionic Flows fire together on the first trigger, because `trigger_reactions` fires every matching instant in hand. See the question below. | — | T::laurentius_lost_spear: a slotted self-target card may target an ally; T::laurentius_lost_spear: Psionic Flow adds 8 damage; T::laurentius_lost_spear: and shoves the target back 1 |
| leather_belt | item | CORRECT | — | — | T::leather_belt: a slotted damaging card deals +1 |
| leather_boots | item | CORRECT | — | — | T::leather_boots: equipping gives exactly the described stats |
| leather_cap | item | CORRECT | — | — | T::leather_cap: equipping gives exactly the described stats |
| leather_gauntlets | item | CORRECT | — | — | T::leather_gauntlets: equipping gives exactly the described stats |
| legend_has_it | item | CORRECT | — | — | T::legend_has_it: a 100 hit lands 5 lighter |
| lions_halberd | item | CORRECT | — | — | T::lions_halberd: a slotted damaging card deals +10 |
| long_bow | item | FIXED | "3 card slots (2 bonus, 1 plain)": a card in the plain slot still got +2 range. `main._helm_range_bonus` read the riders off the item. | `main.gd` `_helm_range_bonus` reads them through the card. | T::long_bow: a slotted offensive card gains +2 range; T::long_bow: a slotted damaging card deals +2 |
| magic_staff | item | CORRECT | — | — | T::magic_staff: an unslotted Slash deals +4; T::magic_staff / reaper_scythe: two-handed |
| mail_coif | item | CORRECT | — | — | T::mail_coif: at 15 tempo, +5 unerring armor |
| mane_of_narashimha | item | CORRECT | — | — | T::mane_of_narashimha: your hit lands 5% harder in the aura; T::mane_of_narashimha: 3 squares off, out of the aura |
| marvolo_gaunt | item | FIXED | In single player the save never applied "Marvolo's Misunderstanding deals 25 damage after 7 tempo unless purged": only Player 2 was connected to `marvolo_triggered`. | `main.gd`: Player 1 is wired through `_wire_marvolo_hooks` as well. This replaces P1's unbound `debuff_expired` connection and its `_wire_dot_log` call, which `_wire_marvolo_hooks` also makes. | T::marvolo_gaunt: Marvolo's Misunderstanding — 25 damage in 7 tempo; T::marvolo_gaunt: left alone it lands for 25; T::marvolo_gaunt: purged, the Misunderstanding deals nothing; test_rings_pass |
| mauls_sabre | item | CORRECT | — | — | T::mauls_sabre: blue slot +5 damage, 1 Weaken, +8 block; T::mauls_sabre: red slot +15 damage; T::mauls_sabre: blue right after red also applies 1 Vulnerable; test_weapons_pass (red after blue: -1 tempo) |
| medic_wraps | item | CORRECT | — | — | T::medic_wraps: heals 5 and gains 3 armor; T::Medic Wraps: 15 tempo cooldown |
| megingjord | item | CORRECT | — | — | T::megingjord: a slotted card costs double mana; T::megingjord: any card, not only damaging ones; test_item_feedback (the whole hit is doubled) |
| mits_of_chingiz | item | CORRECT | — | — | T::mits_of_chingiz: the second offensive card in a row adds a Switch Kick; T::mits_of_chingiz: then a 20 tempo cooldown |
| momentum_mits | item | CORRECT | — | — | T::momentum_mits: any slotted card draws you a card; T::momentum_mits: Continue to move draws a card |
| monocle | item | FIXED | A card in its plain slot still got the +5 range (same `_helm_range_bonus` cause as Long Bow). | Same `main.gd` fix. | T::monocle: a slotted ranged offensive card gains +5 range; T::monocle: a card in its plain slot gains no range; T::monocle: a slotted ranged offensive card resolves with +25% crit; T::monocle: 20/20 maintained gives ranged offensive cards +3 range |
| mountain_boots | item | CORRECT | — | — | T::mountain_boots: an offensive card from high ground deals 20% more; T::mountain_boots: a damaging non-offensive card gets nothing |
| nine_ruins_of_sanguine | item | FLAGGED | "can be hit (even by you)" is not implemented: player cards cannot target the penguin, and the player's AoE skips him. The basic attack also builds no Vitality. See the questions below. | — | T::nine_ruins_of_sanguine: 3 Vitality: +6 attack damage; T::nine_ruins_of_sanguine: and 3% lifesteal; T::nine_ruins_of_sanguine: no Vitality while he lives; T::nine_ruins_of_sanguine: damage he takes heals you half; test_item_feedback (the 5-tempo window) |
| orions_belt | item | CORRECT | — | — | T::orions_belt: granted [...] are in the deck |
| pick | item | CORRECT | — | — | T::pick: a slotted damaging card deals +5 |
| pocket_knife | item | CORRECT | — | — | T::pocket_knife: a DEX-proc'd 7-tempo attack takes 3 - 2 = 1 tempo and resolves on tick 1 |
| poseidons_trident | item | CORRECT | — | — | T::poseidons_trident: the square behind the target takes the same hit; T::poseidons_trident: a third square is out of reach |
| potion_belt | item | CORRECT | — | — | T::potion_belt: a slotted utility card costs 1 less tempo; T::potion_belt: granted [...] are in the deck |
| presence_of_mind | item | CORRECT | — | — | T::presence_of_mind: a slotted Block gains 10% of max mana as extra block; T::presence_of_mind: any card gets it |
| quiver_of_wet_stones | item | CORRECT | — | — | T::quiver_of_wet_stones: a slotted hit strips 4 extra armor on top of its +2 |
| reaction_rod | item | CORRECT | — | — | T::reaction_rod: an enemy striking from melee takes 4 Shock; T::grounding costs 200 mana, 10 tempo as its item says |
| reaper_scythe | item | CORRECT | — | — | T::reaper_scythe: above half health, 10% lifesteal; T::reaper_scythe: below half, 10% of the damage returns as mana; T::reaper_scythe: a card aimed below half costs 10% less |
| return_scroll | item | CORRECT | — | — | T::return_scroll: right-clicking it opens a portal; test_town_portal_return (walk in, twin in town, closes once used) |
| ring_of_nibelung | item | CORRECT | — | — | T::ring_of_nibelung: the 5th heal brings the Curse carrying the healed total; T::ring_of_nibelung: only one copy can exist |
| ring_of_stone_hide | item | CORRECT | — | — | T::ring_of_stone_hide: a Block gives +4; T::ring_of_stone_hide: 100 block gained -> 10% resistance for 15 tempo |
| ring_of_thomas_the_train_tracks | item | CORRECT | — | — | T::Thomas: a shuffle grants 7 Regen; T::Thomas: every 3rd shuffle also heals 25; T::Thomas Lv.3: every 2nd shuffle heals 35 (also tests/test_rings_pass.gd) |
| rollerblades | item | CORRECT | — | — | T::Rollerblades: a slotted instant (5 armor) gains 10 more; T::Rollerblades: a flash move costs 1 less; T::Rollerblades: Shift moves you 2 spaces |
| roman_bracers | item | CORRECT | — | — | T::Roman Bracers: a slotted melee attack deals +5; T::Roman Bracers: Slice costs 2 tempo; T::Roman Bracers: Slice has a 10 tempo cooldown |
| rusty_dagger | item | CORRECT | — | — | T::Rusty Dagger: a slotted card crits ~15% of the time from 0% |
| sabre_tooth | item | CORRECT | — | — | T::Sabre Tooth: an offensive hit applies 5 Bleed; T::Sabre Tooth: striking the same target again rakes 5 more Bleed; T::Sabre Tooth: ...and ticks the attack-speed counter once more |
| sack_of_bone_arrows | item | FLAGGED | Its +5 WIS / +3 INT land as +4 / +2: a quiver always sits in the off hand, which takes the 0.9 off-hand modifier (rounded down). The kill-skeleton rider is a boolean and works in full. | — | T::sack_of_bone_arrows: stat block lands on the wearer; T::Sack of Bone Arrows: a kill with a slotted offensive card raises a skeleton; T::Sack: up to 3 at once |
| scholars_cap | item | CORRECT | — | — | T::Scholars Cap: +5 max brain points (on top of its +5 WIS); T::Scholars Cap: Peek costs 1 less; T::Scholars Cap: any slotted card regains 2 brain points; T::Scholars Cap Lv.3 |
| scholars_signet | item | CORRECT | — | — | T::scholars_signet: stat block lands on the wearer |
| shadow_cowl | item | CORRECT | — | — | T::Shadow Cowl: a slotted offensive card deals +2; T::Shadow Cowl: ...and makes the next 2 tiles free; T::Shadow Cowl: the 2 tiles cost no tempo |
| shadow_obi | item | CORRECT | — | — | T::Shadow Obi: +5 damage while invisible; T::Shadow Obi: an unslotted 1-tempo card deals 3 to a random enemy; T::Shadow Obi: a 2-tempo card zaps nothing |
| shamans_mask | item | FIXED | "Utility cards" read only the Utility type, so a utility-tagged instant (Healthy Bliss) got neither the heal nor the zap — CARD_TAXONOMY makes Utility the type OR the tag. | card.gd utility-heal rider and main._helm_card_world_effects' zap read the type or the `utility` tag; on_self_rules.qualifies("utility") too. | T::Shamans mask: a slotted utility card heals 3; T::Shamans mask: 1 spell damage to the enemy within 3, not the one at 5; T::Shamans mask: a utility-tagged instant counts as a utility card |
| shepherds_crook | item | CORRECT | — | — | T::Shepherds Crook: all your healing heals 5 more; T::Shepherds Crook: a targeted card pulls its target 1 square toward you; T::Shepherds Crook: allies are pulled too; T::Shepherds Crook is two-handed |
| shock_quiver | item | FLAGGED | In play it applies 1 Shock and +4.5% crit, with +2 AGI / +1 WIS / +1 DEX: the off-hand 0.9 modifier every quiver sits under halves the 2 Shock (rounded down) and trims everything else. | — | T::Shock Quiver (FLAG): the off hand makes 2 Shock / 5% crit into 1 / 4.5%; T::Shock Quiver: a slotted hit applies its (off-hand) Shock |
| short_bow | item | CORRECT | — | — | T::Short Bow is two-handed; T::Short Bow: no second weapon; T::Short Bow: pairs with a quiver |
| short_sword | item | CORRECT | — | — | T::short_sword: grants 1 x slice into the deck; T::Short Sword: Slice (10 mana, 3 tempo); T::Slice deals 15 damage |
| side_card_sabre | item | CORRECT | — | — | T::Side Card Sabre: weightless beside a main-hand sword; T::Side Card Sabre: its slotted cards cost 1 less tempo; T::Side Card Sabre: a shield in the main hand doesn't count |
| sleeved_katar | item | CORRECT | — | — | T::Sleeved Katar: +25% crit damage; T::Sleeved Katar: +5% crit chance; T::Sleeved Katar: the skill grants 5 armor; T::Sleeved Katar: the next melee card deals +5; T::Sleeved Katar: 25 tempo cooldown; T::Return Cut is an Instant |
| slotted_rope_half_sleeve | item | FLAGGED | Its on-self "+3 block (armor on a card that blocks nothing)" nets 0 on a non-block card: the +3 is that card's first armor grant, and the sleeve's own "-3 block from your block cards" rides the any-type armor channel (PlayerStats.add_armor, the Thick Steel ruling), so it eats the +3. Everything else matches. | — | T::Rope Sleeve (FLAG): a slotted card that blocks nothing nets 3 - 3 = 0 armor; T::Rope Sleeve: a slotted block card gets +3 block; T::Rope Sleeve: any slotted card discards a card; T::Rope Sleeve: Overdraw drops a Cinquedea into the manifest zone, up to 5; T::Rope Sleeve: each waiting Cinquedea gives block cards +1; T::Rope Sleeve: spending a Cinquedea takes its point with it |
| smithed_excellence | item | CORRECT | — | — | T::Smithed Excellence: with block up, 10% more physical resistance; T::Smithed Excellence: a slotted card grants 2% resistance to all types for 3 tempo |
| spartan_spear | item | CORRECT | — | — | T::Spartan Spear: nothing without a shield; T::Spartan Spear: a shield grants Reach; T::Spartan Spear: Reach — a melee card hits 2 squares away; T::Spartan Spear: ...and +2 melee damage |
| spidey_web_shooters | item | CORRECT | — | — | T::Spidey: a slotted offensive card Disarms for 5 tempo; T::Spidey: Coming in! pulls you to a target 5 squares away; T::Spidey: Coming in! has a 10 tempo cooldown |
| spiked_mitts | item | CORRECT | — | — | T::Spiked Mitts: ANY slotted card provides +5 armor; T::Spiked Mitts: 25 armor gained -> 5 thorns; T::Spiked Mitts: Well placed guard — 5 thorns, 15 mana, 15 tempo CD |
| spiked_shield | item | CORRECT | — | — | T::Spiked Shield: 1 Thorns every cycle |
| standard_quiver | item | FLAGGED | Its only rider, +1 range on offensive cards, is 0 in play (and its +1 AGI / +1 DEX are 0): a quiver always sits in the off hand, and the 0.9 off-hand modifier floors 1 to 0. Only Stephen's empowered 1.1 off hand gets it. | — | T::Standard Quiver (FLAG): the off hand floors its +1 range to 0; T::standard_quiver: stat block lands on the wearer |
| steel_boots | item | CORRECT | — | — | T::Steel Boots: nothing after 10 tempo; T::Steel Boots: 1 unerring armor at 15 tempo |
| steel_plate | item | CORRECT | — | — | T::Steel Plate: nothing at 15 tempo; T::Steel Plate: 8 unerring armor every 20 tempo with room under the cap; T::Steel Plate: at 20 tempo, up to your unerring cap |
| steve_rodgers_bastion | item | CORRECT | — | — | T::Bastion: an enemy hit gives you 5 mana; T::Bastion Lv.2: 7 mana per hit; T::Bastion: Bouncing Shield (55 mana, 4 tempo); T::Reverberate Regrowth is a 55-mana Maintain |
| strap_of_stone | item | CORRECT | — | — | T::Strap of Stone: 10 unerring armor every 20 tempo; T::Strap of Stone: ...up to your unerring cap; T::Strap of Stone: a slotted card grants 10% physical resistance for 10 tempo; T::Stone Encase: gain 50 armor and become stunned |
| stringless_sender | item | CORRECT | — | — | T::Stringless Sender: 1 less tempo; T::Stringless Sender: 10 more mana; T::Stringless Sender: ~20% of shots bounce; T::Stringless Sender: the bounce lands at full damage |
| studded_belt | item | CORRECT | — | — | T::Studded belt: any slotted card gains you 3 thorns |
| suit_and_tie | item | CORRECT | — | — | T::Suit and Tie: obtaining gold heals 3; T::Suit and Tie: Negotiate (20 mana, 3 tempo) |
| summoners_cap | item | CORRECT | — | — | T::Summoners Cap: a slotted heal heals 3 more; T::Summoners Cap: a slotted card that doesn't heal heals you 3; T::summoners_cap: grants 1 x heal into the deck |
| supernova_cuirass | item | CORRECT | — | — | T::Supernova: a 100 hit lands as 88, 10 harnessed as one stack; T::Supernova: with no stack room (10) it absorbs nothing; T::Supernova: Detonova deals the absorbed 10 within 2 squares, unscaled by INT (also tests/test_chest_pass.gd) |
| sword_breaker | item | CORRECT | — | — | T::Sword Breaker: any slotted card gains 4 armor and Fortify for 5 tempo; T::Sword Breaker: melee damage the armor swallows whole costs that enemy 2 tempo; T::Sword Breaker: ...on its next melee attack's wind-up |
| sword_of_theseus | item | CORRECT | — | — | T::Sword of Theseus: 5% lifesteal; T::Sword of Theseus: a hit applies 2 Slow; T::Sword of Theseus: +1 damage per Slow on the target; T::Sword of Theseus Lv.3 |
| tactical_belt | item | FIXED | "A card aimed at an enemy detonates": any slotted card with a target detonated, so a self-cast card (a heal on yourself) blasted every enemy next to you; and a card in its plain slot detonated too (main read the item's bonus, not the card's). | main._helm_card_world_effects: the blast needs an Enemy target, and the step reads `card.get_on_self_bonus()` (neutral in a plain slot). | T::Tactical belt: the enemy beside the target takes 2; T::Tactical belt: a card aimed at yourself detonates nothing; T::Tactical belt: a card in the plain slot detonates nothing; T::Tactical belt: the wielder (an ally beside the target) is unharmed |
| tattered_cloth | item | CORRECT | — | — | T::tattered_cloth: stat block lands on the wearer |
| techno_wraps | item | CORRECT | — | — | T::Techno Wraps: the discard pile shuffles into the draw pile; T::Techno Wraps: 15 tempo cooldown |
| the_headbandz | item | CORRECT | — | — | T::The Headbandz: a slotted card costs 20% less mana; T::The Headbandz Lv.3: 35% off slotted cards; T::The Headbandz Lv.3: Out of Guesses costs 1 tempo |
| the_precious | item | CORRECT | — | — | T::The Precious: the 4th enemy hit drags you into shadow form for 10 tempo; T::The Precious: max mana is halved inside; T::The Precious: THREE ring wraiths hunt you; T::The Precious: a wraith has 100 HP, 15 damage every 2 tempo, moves every 4; T::The Precious: after 1 tempo, clicking the badge leaves shadow form; T::The Precious: they return as they were left; T::The Precious Lv.3: TWO wraiths |
| the_rapid_recurve | item | CORRECT | — | — | T::Rapid Recurve: 1.5x mana; T::Rapid Recurve: Double Shot hits a second time at full damage; T::Rapid Recurve: the card is jailed 20 tempo after play |
| the_slotted_sash | item | FIXED | "Defense cards" / "utility cards" read only the raw type, so Vengeful Shield (a defense-tagged instant) got no +2 armor and a utility-tagged instant Weakened nobody; and a card in its plain slot still Weakened (main read the item's bonus, not the card's). | card.gd defense-armor rider reads the type or the `defense` tag; main's Weaken step reads the type or the `utility` tag and the card's own (plain-slot-neutral) bonus; on_self_rules.qualifies("defense"/"utility") too. | T::Slotted Sash: offensive cards +2 damage; T::Slotted Sash: defense cards +2 armor; T::Slotted Sash: a defense-tagged instant counts as a defense card; T::Slotted Sash: a utility card Weakens a random enemy within 5; T::Slotted Sash: a utility card in the plain slot Weakens nothing |
| theif_hat | item | CORRECT | — | — | T::theif_hat: stat block lands on the wearer |
| thick_steel_helm | item | CORRECT | — | — | T::Thick Steel Helm: 10% resistance to all damage; T::Thick Steel Helm: an armor card grants 2 more; T::Thick Steel Helm: ...of any type |
| tigers_sunday_red | item | CORRECT | — | — | T::Tigers: +1 range on a ranged offensive card; T::Tigers: +(HP-gap / 4)% damage; T::Tigers: a slotted offensive card heals 3% of max health; T::Tigers Lv.3 |
| tightened_cross_bow | item | CORRECT | — | — | T::Tightened Cross Bow: +5 damage; T::Tightened Cross Bow: +1 tempo |
| titanium_toe_tuckers | item | CORRECT | — | — | T::Titanium Toe Tuckers: a slotted attack provides +8 armor; T::Titanium Toe Tuckers: side step gives 2 more armor |
| treebeards_branch | item | CORRECT | — | — | T::Treebeards Branch: any slotted card gains you 3 Thorns; T::Treebeards Branch: Overdraw grants 3 Regen; T::Treebeards Branch: Bark Up (45 mana, 3 tempo) |
| trench_of_tranquility | item | CORRECT | — | — | T::Trench: a slotted heal card heals 5 more; T::Trench: a slotted card that doesn't heal heals you 5; T::Mind Mend costs 15 HEALTH; T::Deep Breaths heals 20 |
| umbral_eclipse | item | CORRECT | — | — | T::Umbral Eclipse: gaining armor deals 5 to the enemy in melee range; T::Umbral Eclipse: nothing when no enemy is in melee range; T::Umbral Eclipse: an Insight draw restores 2 flash points; T::Umbral Eclipse Lv.3 |
| vanguard | item | CORRECT | — | — | T::Vanguard: a hit is 3 damage lighter; T::Vanguard: 1 Regen every cycle |
| velvet_plate | item | CORRECT | — | — | T::Velvet Plate: a slotted attack heals you 5 |
| vengeful_shield | item | CORRECT | — | — | T::Vengeful Shield: the enemy target is shoved back 1; T::Vengeful Shield: a card with no enemy target shoves every adjacent enemy |
| waistband | item | CORRECT | — | — | T::Waistband: any slotted card gains you 2 armor |
| wand_of_clarity | item | CORRECT | — | — | T::Wand of Clarity: no debuffs -> ALL cards 15% less mana; T::Wand of Clarity: a debuff takes the discount away; T::Wand of Clarity: a slotted card regains 2 brain and 2 flash |
| wand_of_deliverance | item | CORRECT | — | — | T::Wand of Deliverance: all your cards gain +2 range; T::Wand of Deliverance: damaging offensive cards deal +2 |
| wand_of_the_phoenix_feather | item | CORRECT | — | — | T::Phoenix Feather: applying Burn burns you 1 — once per play; T::From the Ashes: enemies within 3 take 5 per stack; T::From the Ashes: heal 5 per stack; T::From the Ashes: Regen equal to half of it; T::Phoenix Feather Lv.3 |
| wizard_hat | item | CORRECT | — | — | T::Wizard Hat: the 3rd attack arms +5 spell power; T::Wizard Hat: the next spell deals +5; T::Wizard Hat: ...and spends it |
| wooden_plank | item | CORRECT | — | — | T::Wooden Plank: the hit that drops you below half grants 1 Regen; T::Wooden Plank: further hits below half grant no more |
| wooden_shield | item | CORRECT | — | — | T::Wooden Shield: an enemy that strikes you in melee takes 1 Bleed; T::Wooden Shield: a ranged striker does not |
| wooden_spear | item | CORRECT | — | — | T::Wooden Spear: an offensive hit applies 1 Bleed |
| wooden_sword | item | CORRECT | — | — | T::Wooden Sword: +1 damage; T::Wooden Sword: 1 card slot; T::wooden_sword: grants 1 x splinter into the deck |
| wrist_rocket | item | FLAGGED | The tooltip says "One-handed; pairs with a quiver", but a quiver is refused beside it: the designer ruled (2026-10-25, docs/ITEM_NOTES.md "RANGED") that a quiver is only worn beside a bow and the Wrist Rocket "take[s] no quiver". Its +10% crit, one-handedness and 2 Improvised Ammo are right. | — | T::Wrist Rocket: +10% crit chance; T::Wrist Rocket is one-handed; T::Wrist Rocket (FLAG): a quiver is refused beside it; T::wrist_rocket: grants 2 x improvised_ammo into the deck |
| Enraged Will | passive | FIXED | Fired at exactly the threshold (`<=`); the text says "drop below". "10 mana per kill" is right: displayed mana is code mana (HUD shows `current/max`, max 50). Fires on the damage hook while low, so once the cooldown passes the next hit re-triggers it (fits "Cooldown"). | `progression_triggers.gd`: strict `<` threshold. | test_wiring_passives.gd::Enraged Will r15: at exactly 25% HP nothing swings; ::Enraged Will: two kills by the swing gain 10 mana each |
| In the Trenches | passive | CORRECT | — | — | test_wiring_passives.gd::In the Trenches r15: an enemy stepping adjacent takes a free 120% attack |
| Stone Skin | passive | CORRECT | — | — | test_wiring_passives.gd::Stone Skin r15: PHYSICAL damage reduced by 11.50% |
| Point to Prove | passive | CORRECT | — | — | test_wiring_passives.gd::Point to Prove r15: confirming pays 6 HP (6%) and ignores STUN |
| Directed Strength | passive | CORRECT | Reference flagged "<= 50%". Gain below 50%, lose "when going above": at exactly 50% the text does not say to lose it, and the code keeps it. | — | test_wiring_passives.gd::Directed Strength r15: below 50% health it adds +15 STR |
| The Way of the Plate | passive | CORRECT | — | — | test_wiring_passives.gd::The Way of the Plate r15: the 2th refunds 10 mana and 1 tempo |
| Ancestral Aid | passive | FIXED | "More defense" counted only the Defense type; the taxonomy's defensive card is the type or the `defense` tag (Vengeful Shield). | `progression_triggers.gd`: new `_is_defensive()` used for the hand count. | test_wiring_passives.gd::Ancestral Aid r15: more defense cards (a defense-tagged instant counts) heals 17 |
| Redemption | passive | CORRECT | — | — | test_wiring_passives.gd::Redemption r15: the next offensive card's roll spends it |
| Life Steal | passive | BLOCKED | *(Phase 6 re-check)* Heals `max(1, damage dealt × %)` once per attack card, and falls back to the card's printed damage when the play recorded none — a whiff heals, and an area attack steals from one hit only. | BLOCKED: area attacks resolve in main.gd with no record of what they hit. Plan in docs/audit/validation.md. | test_wiring_passives.gd::Life Steal r15: a passive hit of 200 steals 8% = 16 |
| Pristine Armor | passive | CORRECT | — | — | test_wiring_passives.gd::Pristine Armor r15: three in a row add +14 more; ::a utility in between resets the streak |
| Vines Codependence | passive | FLAGGED | Fires on any direct heal Brad *receives* (an ally's heal on him included) and not on a heal he casts on an ally. "Whenever you heal" can read either way. | — | test_wiring_passives.gd::Vines Codependence r15: a direct heal grants 8 thorns for 5 tempo |
| Solemn Independence | passive | CORRECT | — | — | test_wiring_passives.gd::Solemn Independence r15: an offensive hit of 100 lands for 112 |
| Energy Barrier | passive | CORRECT | — | — | test_wiring_passives.gd::Energy Barrier r15: the 3rd non-regen gain adds a 0m/0t Energy Barrier for 17 armor, Erase 1 |
| Prey on the Weak | passive | CORRECT | — | — | test_wiring_passives.gd::Prey on the Weak r15: a new debuff on an enemy below 50% deals 17 |
| Wither | passive | FLAGGED | The open design note in CLAUDE.md: "+1 charge" is `apply_debuff(name, 1)` — +1 stack on stack debuffs, +1 tempo on additive timers, a no-op on max-timers (Stun, Silence…) that still spends the cooldown; it fires on debuffs from any source. Its +1 also re-rolls Elemental Conclusion. | — (design note, not changed) | test_wiring_passives.gd::Wither r15: +1 charge on the applied debuff (poison 2 → 3) |
| Budding | passive | CORRECT | — | — | test_wiring_passives.gd::Budding r15: utility, defense, offensive (none back to back) heals 19 and gives 19 temp HP for 15 tempo |
| Eat | passive | CORRECT | — | — | test_wiring_passives.gd::Eat r15: an enemy at 5% (threshold 39%) takes +34% from a direct hit |
| Expel Negativity | passive | FLAGGED | Fired at exactly the threshold (`<=`; text: "drop below") — fixed. Open: the 2 charges refill together only when both are spent and 10 tempo pass, while In the Trenches (same "2 charges, 10 tempo cooldown" wording) returns each charge 10 tempo after it was spent. Debuffs with no enemy counterpart (Cuffed, Blind…) cannot move (nothing spent). | `progression_triggers.gd`: strict `<` threshold. | test_wiring_passives.gd::Expel Negativity r15: exactly at 63% is not below it; ::dropping below 63% moves Slowed to the nearest enemy, one charge |
| Circle of Life | passive | CORRECT | — | — | test_wiring_passives.gd::Circle of Life r15: and +24 damage on the next 3 offensive cards |
| Territorial Death | passive | CORRECT | — | — | test_wiring_passives.gd::Territorial Death r15: after 1 tempo it fires again |
| Self Reliance | passive | CORRECT | — | — | test_wiring_passives.gd::Self Reliance r15: 3 cards in one cycle cut a hand card by 60m |
| Death as Lifeblood | passive | CORRECT | Reference flagged the Euclidean 2.0 radius. The grid is walked without diagonals (`get_distance_in_cells` is Manhattan), and on whole cells a 2.0 radius is exactly "within 2 squares": (1,1) and (2,0) in, (2,1) out. | — | test_wiring_passives.gd::Death as Lifeblood r15: each cycle 5 HP per enemy within 2 squares, up to 12 |
| Serial Killer | passive | FIXED | Fired at exactly the threshold (`<=`); the text says "drops below". | `progression_triggers.gd`: strict `<`. | test_wiring_passives.gd::Serial Killer r15: exactly at 25% is not below it; ::attacking it reveals him with an auto-crit |
| Regrowth | passive | FLAGGED | Draw 4 on an empty hand and the 25→11 cooldown work. Open: the cooldown is spent even when nothing could be drawn (Cuffed, empty piles), and any hand refresh with an empty hand fires it (including a load with an empty hand), not only the act of emptying it. | — | test_wiring_passives.gd::Regrowth r15: emptying the hand draws 4, cooldown 11 |
| Arcane Overflow | passive | CORRECT | Reference's re-audit note says it primes on an offensive card; the code (rightly, per the taxonomy) primes on the Spell school. | — | test_wiring_passives.gd::Arcane Overflow r15: the next offensive card costs -1 tempo (Slash 3 → 2) |
| I Heal You | passive | CORRECT | — | — | test_wiring_passives.gd::I Heal You r15: every 4 tempo an ally 3 squares away is healed 3 |
| Tricks of Death | passive | CORRECT | — | — | test_wiring_passives.gd::Tricks of Death r15: card chances +12.0 points |
| A Mage's Favor | passive | CORRECT | — | — | test_wiring_passives.gd::A Mage's Favor r15: a reroll batch that changed an outcome adds one 0m/0t Magic Barrier instant (16 armor)…; test_passive_feedback2.gd (the barrier is up before the blow) |
| Harnessed Power | passive | CORRECT | — | — | test_wiring_passives.gd::Harnessed Power r15: damage +32% / armor gain +32% / healing +32% |
| Whispers of the Flock | passive | FLAGGED | *(Phase 6 re-check)* Only a card with a printed heal aimed at another ally grants the Mark; Communal Donation, Mend and Halo's per-cycle heals never do. Should every heal of an ally count? | — | test_wiring_passives.gd::Whispers r15: the marked ally survives lethal at 1 HP with 19 armor; Jeremy takes 8 |
| Seance | passive | CORRECT | — | — | test_wiring_passives.gd::Seance r15: 33 HP, 33 damage to its killer |
| Kinetic Armor | passive | FIXED | "Defensive cards in your deck" counted only the Defense type, not `defense`-tagged cards. | `progression_triggers.gd`: `_is_defensive()` for hand, draw and discard. | test_wiring_passives.gd::Kinetic Armor r15: past 16 tempo the nearest enemy gets shock = defense cards in the deck |
| Mana Surge | passive | FLAGGED | The conjured card said "gain 1 mana"; it gains 10, as the passive says — fixed. Open: the text calls the card an "Attack" but it is a Spell (school SPELL, INT-scaled, card face "Spell"); and spending is recorded when each card resolves, from its printed cost (a Demonic-Rage play paid in health still counts as mana spent). | `card.gd` `create_mana_surge`: description "gain 10 mana". | test_wiring_passives.gd::Mana Surge r15: 100 mana within 5 tempo adds a 0m/2t Mana Surge dealing 18; ::the card says it gains 10 mana |
| Haunted Rebuke | passive | FIXED | "3 or more defensive cards" counted only the Defense type. | `progression_triggers.gd`: `_is_defensive()`. | test_wiring_passives.gd::Haunted Rebuke r15: with 3 defensive cards (a defense-tagged instant counts) the attacker's next action takes +3 tempo, cooldown 11 |
| Blood Libation | passive | CORRECT | — | — | test_wiring_passives.gd::Blood Libation r15: at 5 stacks he takes 10, then the heal lands doubled, stacks consumed |
| Fresh Start | passive | CORRECT | — | — | test_wiring_passives.gd::Fresh Start r15: emptying the hand cleanses a debuff |
| Keep Them Guessing | passive | CORRECT | — | — | test_wiring_passives.gd::Keep Them Guessing r15: the 4th discard cuts a hand card by 3 tempo for 5 tempo |
| Quick Step | passive | CORRECT | — | — | test_wiring_passives.gd::Quick Step r15: an instant fired from hand grants 16 armor |
| Stimulant | passive | FIXED | Drew a card (and spent its cooldown) when Poisoned Blood turned the Pocket heal into damage, so nobody was healed. | `progression_triggers.gd`: skip when `heal_to_damage` flipped the heal. | test_wiring_passives.gd::Stimulant r15: a heal Poisoned Blood flipped to damage heals nobody: no draw, no cooldown |
| Now You See Me | passive | FLAGGED | *(Phase 6 re-check)* Charge and the Repelled Block push move you without counting as "non-standard movement"; Roll and Heroic Leap count. Should they? | — | test_wiring_passives.gd::Now You See Me r15: a displacement grants invisibility for 5 tempo; test_passive_triggers / test_passive_feedback2 (the displacement sources) |
| From the Hip | passive | CORRECT | — | — | test_wiring_passives.gd::From the Hip r15: a drawn attack costs -30m/-2t |
| Ladder Work | passive | CORRECT | — | — | test_wiring_passives.gd::Ladder Work r15: the first attack this cycle deals +6 per card discarded last cycle |
| Pop Rocks | passive | CORRECT | — | — | test_wiring_passives.gd::Pop Rocks r15: poisoning a poisoned enemy deals 1/3 of its stacks (9 → 3) |
| Surprise Opener | passive | CORRECT | — | — | test_wiring_passives.gd::Surprise Opener r15: first strike on an untouched, unarmored enemy: +40 |
| Nimble Assault | passive | FIXED | "No Defense cards" ignored a `defense`-tagged card in hand. | `progression_triggers.gd`: `_is_defensive()`. | test_wiring_passives.gd::Nimble Assault r15: a defense card in hand (a defense-tagged instant counts): no draw |
| Let's Dance | passive | CORRECT | — | — | test_wiring_passives.gd::Let's Dance r15: 8 spaces ÷ 1 = 8 armor and 8 damage to the nearest enemy within 3 |
| Mad Scientist | passive | FLAGGED | Poison Bomb is aimed at a tile, so its card-play target is no enemy: the Utility→Poison and Defense→Poison outcomes never landed — fixed. Open: Utility→Heal regen lasts 15 tempo (not in the text); "potion cards" is read as every Pocket card; a Poisoned-Blood-flipped heal on yourself or an ally has no poison outcome to land. | `main.gd` records the enemies Poison Bomb poisoned (`last_poison_bomb_hits`); `progression_triggers.gd` lands the riders on each. | test_wiring_passives.gd::Mad Scientist r15: Utility → Poison Bomb: +9 poison on every enemy it poisoned; ::Defense → Poison Bomb: -15% physical defense on them for 5 tempo |
| Eye Scrape | passive | FIXED | Counted one crit per card: a multi-hit card critting on several hits advanced "every Nth critical strike" by 1; Quiver / Manifest plays reported no crits at all. | `buff_manager.gd`: `crit_hits` counter; `main.gd` passes the count for hand, echo and Quiver/Manifest plays; `progression_triggers._trigger_skill_tree_on_crit(target, crit_count)` counts each. | test_wiring_passives.gd::Eye Scrape: a Multishot critting on all 3 hits counts 3 critical strikes (rank 13: every 3rd) |
| Deadly | passive | CORRECT | — | — | test_wiring_passives.gd::Deadly r15: and +30% crit damage |
| Clean Exchange | passive | CORRECT | — | — | test_wiring_passives.gd::Clean Exchange r15: the attack deals its damage and gains the 8 block when played |
| Eagle Eye | passive | CORRECT | — | — | test_wiring_passives.gd::Eagle Eye r15: a ranged offensive card adds 142% of its range 6 = +9 |
| Patience is a Virtue | passive | CORRECT | — | — | test_wiring_passives.gd::Patience is a Virtue r15: it grants 30% resistance to all damage for 5 tempo |
| Easy Target | passive | CORRECT | — | — | test_wiring_passives.gd::Easy Target r15: exposing the enemy deals the 30 hit again |
| Exposed Blind Spot | passive | CORRECT | — | — | test_wiring_passives.gd::Exposed Blind Spot r15: a melee blow arms 4.50% per non-attack card |
| Scouted | passive | CORRECT | — | — | test_wiring_passives.gd::Scouted r15: +6 range on the next attack; ::the next attack on ANY enemy auto-crits; ::with +30% crit damage |
| Swing for the Fences | passive | CORRECT | — | — | test_wiring_passives.gd::Swing for the Fences r15: a 6-tempo card deals 380% of 6 = +23 |
| Skilled Momentum | passive | CORRECT | — | — | test_wiring_passives.gd::Skilled Momentum r15: the next attack after 3 in a row is played twice; ::the armed attack lands twice |
| Lethal Resourcefulness | passive | CORRECT | — | — | test_wiring_passives.gd::Lethal Resourcefulness r15: 3 cards + a non-attack: a free basic attack |
| Elemental Conclusion | passive | FLAGGED | Chance 50%→100% matches (the table steps +3/rank to 89%, then 100% at rank 15 — the curve is balance). Open: it rolls on every burn/cold/shock landing on an enemy, whoever applied it, and again on the riders' re-applications (Harnessed Sun's +2, Wither's +1), so one application can roll it more than once. | — | test_wiring_passives.gd::Elemental Conclusion r15: 100% — every burn gets +1 charge; ::Elemental Conclusion r1: about 50% |
| Dominate | passive | CORRECT | — | — | test_wiring_passives.gd::Dominate r15: an attack speed proc adds a 30m/0t basic attack card; ::after 5 tempo yes |
