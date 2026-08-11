# Wayfarer — Boss Design

STATUS 2026-08-11: all three boss fights shipped as designed (Warped
Anchor Warden, the Kaveth Waking Tear guardian, Cael at the Convergence)
— telegraphs (circle/cone/line/donut), phase transitions with invuln
windows, casts/interrupts, and per-fight mechanics are live. One
as-built rule the sections below predate: **bosses refuse turn-based
mode** — [T] is declined ("The Veil won't wait — not in this fight") and
a latched TB force-exits when a boss joins, because these fights are
timed telegraph orchestrations. Phase AI is a plain state machine in
EnemyController, not a Beehave tree.

## Design contract

Regular enemies: the player wins by applying DPS and not taking too much damage.

Bosses: the player wins by *reading and reacting* — dodging telegraphed attacks, completing phase mechanics, and managing positioning. The SRD damage numbers still apply, but the fight is primarily a puzzle the player decodes over several attempts.

Reference: WoW raid/dungeon boss design. Not a bullet sponge. A fight with a distinct opener, one or two mid-phase shifts, and a climactic final phase.

## Core mechanics vocabulary

### Telegraphed AoE

The most important boss mechanic. A visual indicator appears on the ground *before* the attack fires, giving the player ~1–2 seconds to move out.

**Types:**

| Shape | Visual | Examples |
|-------|--------|---------|
| Circle | Expanding ring decal | Shockwave slam, explosion |
| Cone | Fan-shaped decal from boss facing | Breath weapon, cleave |
| Line | Narrow rectangle | Charge path, lightning bolt |
| Donut | Ring (stand inside or outside) | Veil pulse |

Implementation: `BossAbility` node emits `telegraph_started(shape, duration, origin, params)`. The HUD/world layer renders a mesh (flat quad or CSGShape) with a warning material. After `duration` seconds, the ability fires and the telegraph is removed.

### Phase transitions

HP thresholds trigger phase changes. Each phase has:
- A transition animation/VFX (boss staggers, environment reacts)
- A brief invulnerability window (~1.5s) so the player can see what's changing
- A new or modified Beehave tree root that adds/replaces abilities

Phases are numbered 1–N. Phase 1 is always the simplest — teaches the player the boss's basic kit. Later phases layer in complexity.

### Special mechanics (per-fight)

Each boss has at least one unique mechanic that isn't just "dodge the circle":

- **Interrupt** — Boss channels a cast (progress bar visible). Player must use an interrupt ability (Sarro: Shield Bash; or a specific talent) within the window or the cast resolves for massive damage.
- **Add wave** — Boss summons weaker enemies. Player must decide: keep hitting boss or clear adds. Adds have a buff that makes them dangerous if left alive.
- **Soak / sacrifice** — A zone appears that must have a player standing in it, or it detonates for AoE damage. Forces positioning decisions.
- **Conviction check** (Liris specific) — Boss creates a Veil anomaly. Liris must channel her Guiding Bolt into it to seal it while Sarro holds aggro. Fails if her conviction score is too low.

No boss uses all of these. Pick one or two per boss and execute them cleanly.

### Enrage

No enrage timer. Fights end when the boss dies or the party wipes. If the fight feels too easy, adjust HP/damage — don't add a hidden clock.

---

## Act boss designs

### Act 1 — The Mender Anchor (Tamori)

**Identity:** Zealous but genuinely kind Mender who believes stabilizing the Veil in Tamori will protect it. She's wrong about the method, not the goal.

**Lore:** She's anchored herself to a Veil crystallization rig. Breaking the rig (the actual boss objective) hurts her — Sarro isn't attacking her, he's dismantling her work while she defends it.

**Phase 1 (100–60% HP)**
- Basic melee + ranged Veil pulse (circle telegraph, moderate damage)
- Mechanic: **Anchor Surge** — every 30s she channels into the rig, healing it for 10% durability. Player must interrupt or the rig repairs faster than they can damage it.

**Phase 2 (60–30% HP)**
- Transition: rig cracks, she enters a desperate state, speech line ("please, I'm so close")
- New ability: **Veil Shards** — three sequential line telegraphs, rotates around the arena. Must be stepped between.
- Rig now spawns crystal adds that slow movement-on-contact. Must be cleared.

**Phase 3 (30–0% HP)**
- Transition: she stops fighting the companions and starts pouring everything into the rig
- Mechanic becomes purely DPS-race: rig has 30s before it completes. **Conviction check** fires — Liris must channel to disrupt the rig while Sarro absorbs Mender's attacks alone.
- She doesn't die. When rig breaks she collapses, the Veil stabilizes, and the narrative choice begins: help her or leave her.

---

### Act 2 — The Extractor Engine (Caelum Rift)

**Identity:** Not a person — an autonomous Extractor construct the Extractors built and lost control of. Pure mechanics boss; horror tone.

**Phase 1 (100–50% HP)**
- Melee slams with large circle telegraphs (slow, readable)
- **Harvest Beam**: rotating line telegraph (180° sweep), stays active for 3s. Rotate with it or get behind pillars.
- Pillars in arena are destructible (each has HP). Player should preserve them.

**Phase 2 (50–25% HP)**
- Transition: destroys one pillar itself. Changes pattern — beams are now faster.
- New mechanic: **Siphon Zone** — four circle soaks appear simultaneously. Both companions must stand in separate soaks or the un-soaked ones chain-lightning the arena.

**Phase 3 (25–0% HP)**
- Destroys all remaining pillars; arena is now open.
- All phase 1 + 2 mechanics active simultaneously, slightly faster.
- No new mechanic — execution test. Reward for players who preserved pillars: debris on the ground provides partial line-of-sight cover for the beam.

---

### Act 3 — Cael, the Convergence (The Veil)

**Identity:** The central antagonist. A former planar cartographer who mapped the entire Veil network and now believes controlled collapse and reconstruction is the only way to save it. Tragic. Brilliant. Wrong.

**This fight is as much dialogue as combat.** Between phases, Cael speaks. The player's earlier conviction choices (Liris's arc) affect what he says and whether an alternate resolution is available.

**Phase 1 — "You still don't understand"**
- Cael fights reluctantly, mostly defending himself
- Standard telegraphs: Veil Bolt (circle), Rift Step (blinks to a random position, leaves a hazard pool at origin)
- Mechanic: **Planar Echo** — a copy of a previous boss ability fires (rotates through Act 1 + 2 mechanics). Reminds player of the journey.

**Phase 2 — "Then I'll show you what I've seen"**
- Transition at 60% HP: Cael reveals the full Veil map — arena becomes a visual representation of the network. The "floor" is the Veil itself.
- New mechanic: **Collapse Point** — Cael targets a node on the Veil-floor. If it isn't disrupted (Liris channels on it), that section of the arena floor becomes impassable.
- Up to 3 Collapse Points can be active; the arena shrinks.

**Phase 3 — "I have no other choice"**
- Trigger: 30% HP OR Liris conviction ≥ threshold (alternate trigger)
- **If conviction is high enough:** Phase 3 becomes a dialogue phase. Cael stops fighting. The player must use dialogue choices to reach the resolution. Combat ends without killing him.
- **If not:** Cael enters full collapse mode — all previous mechanics simultaneously, arena at minimum size.
- Both resolutions lead to the ending, but the dialogue resolution grants a different epilogue.

---

## Technical implementation notes

### BossPhaseController

Each boss scene has a `BossPhaseController` node:
```gdscript
@export var hp_thresholds: Array[float] = [0.6, 0.3]  # fractions
signal phase_changed(new_phase: int)
```

`CombatManager` calls `boss.notify_hp_changed(fraction)` on each damage event. `BossPhaseController` checks thresholds, emits `phase_changed`, triggers the transition coroutine (invuln window + VFX + Beehave tree swap).

### TelegraphRenderer

Autoload or scene-local node. Call:
```gdscript
TelegraphRenderer.show(shape, origin, params, duration)
```
Instantiates a flat mesh with a warning shader (pulsing red/orange), auto-frees after `duration`. Separate from the `BossAbility` that fires afterward.

### Boss arena as its own scene

Each boss fight is a sub-scene (`scenes/bosses/tamori_anchor.tscn`, etc.) with its own arena geometry, trigger volumes, and `BossPhaseController`. The world level loads it via `SceneManager` at the end of the act.

One-way: player cannot re-enter after clearing. Boss scene stores a `cleared` flag in `GameState`.
