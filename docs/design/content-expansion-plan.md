# Content Expansion Plan — Levels, Encounters, Aesthetic, Fun

Status: PROPOSED 2026-08-02. Gap analysis of the current build plus a
phased plan for thicker levels, real encounter variety, per-plane
aesthetic identity, and combat feel. Companion to `levels.md`,
`bosses.md`, `gameplay.md`, `progression.md` — this doc is about closing
the gap between those designs and what's in the scenes today.

## Where the build is today

Working well (don't touch, build on):

- The **level pipeline** (`scripts/world/level_base.gd`): party sync,
  prop collision, animators, autosave, portals/flags, dialogue camera,
  defeat/respawn loop. Adding a scene is cheap.
- The **XP spine** (`progression.md`): full portal-gated chain from
  Tamori to the Convergence, tuned to land level 20 at Cael.
- The **scenery pass** (`scripts/world/scenery.gd`): seeded, avoid-aware
  scatter. Right architecture, wrong scope — one biome for eight planes.

The gaps, honestly stated:

| Area | Designed (docs) | Shipped (scenes/scripts) |
|---|---|---|
| Levels | 2–3 scenes per plane, authored layouts, ambush geometry, hidden portals | One ~46 m flat box per plane, a dozen props, same meadow scatter everywhere |
| Encounters | Patrols, LOS aggro, ambushes, mixed types, per-type behavior | One melee FSM (`enemy_controller.gd`); enemies differ only in statblock; most stand still until you walk into their sphere |
| Bosses | Telegraphs, interrupts, adds, soaks, conviction checks (`bosses.md`) | `is_boss` = stat buff + 1.8 s invuln at 60/30 % HP |
| Aesthetic | Six planes with distinct identities (`narrative/overview.md`) | Per-plane fog color (`resources/env_*.tres`); everything else identical |
| Fun/feel | "Diablo II combat feel" | Auto-attack + 4 hardcoded hotbar keys; feedback is floating numbers and `print()`; no audio at all |
| Story | Six meaningful choices, dialogue-driven | 3 dialogue files (all Act 1); Acts 2–3 beats are `StoryEvent` gold rings |

Asset server inventory (checked 2026-08-02) — packs we can pull beyond
the four in `fetch_assets.sh`: **AncientEgypt**, **Scifi Space**,
**Western**, **Shopping Plaza**, **Prototype**. These are enough to give
every plane a distinct kit without buying anything.

---

## Workstream A — Encounter toolkit (systems that multiply content)

Build the vocabulary once; every scene gets richer for free.

### A1. Enemy archetypes (behavior, not just stats)

`enemy_controller.gd` grows a small `archetype` export (or subclasses)
so the factory roster maps to *different decisions for the player*:

- **Bruiser** — current behavior. Slow, hits hard. (bandit brute,
  enforcer, husk)
- **Skirmisher** — ranged projectile attack, backs away when the player
  closes, forcing the player to chase or eat chip damage. This is the
  single highest-value addition: it creates positioning gameplay where
  none exists. (extractor guard → crossbow, dock blade → thrown knives)
- **Lurker** — starts hidden/inert, activates from an ambush trigger.
  (kaveth shade rising from rubble, veil fragment coalescing)
- **Support** — heals or shields allies until killed; creates a
  kill-order decision and mirrors the Mender theme mechanically.
  (mender zealot channeling into allies)
- **Elite** — any of the above plus one telegraphed signature ability
  (A3) and a loot drop.

### A2. Encounter scripting primitives

- **AmbushTrigger** (Area3D): un-hides / spawns a group when crossed.
  `levels.md` promises ambushes; nothing implements them.
- **Pack aggro**: enemies with a shared `pack_id` aggro together —
  pulling one guard pulls the camp, which makes camp layouts matter.
- **Leashing**: chase gives up beyond a radius *from spawn* (currently
  from self), walk home, heal to full. Prevents degenerate
  drag-one-enemy-at-a-time play and makes camps re-attemptable.
- **Patrols actually used**: the export exists but almost no scene
  populates `patrol_points`. Authoring rule: every open-area scene has
  at least one patroller crossing the main path.

### A3. Telegraphed ground AoE (TelegraphRenderer)

Per `bosses.md`: circle / cone / line / donut warning decals (flat mesh
+ pulsing emissive shader), `show(shape, origin, params, duration)`,
then the ability fires. Built once, used by elites *and* all three
bosses. This is the mechanic that turns combat from stat-checks into
read-and-react — the core of the promised feel.

### A4. Interrupt hook

Sarro gets one interrupt (Shield Bash on the empty ability slot): a
visible enemy cast bar + a punish window. Needed by the Act 1 boss
(Anchor Surge) and the support archetype; cheap once cast-channeling
exists.

---

## Workstream B — Per-plane aesthetic identity

### B1. Biome recipes (data-driven scenery)

Refactor `scenery.gd`'s hardcoded MeadowForest tables into per-plane
**recipes**: `{backdrop[], groundcover[], scatter[], densities, ground
material, unit scale}` keyed by `plane_id` (fallback: current meadow).
The generator logic stays; only the tables move. Proposed mapping from
available packs:

| Plane | Kit | Identity |
|---|---|---|
| Tamori (+road/fields/anchor) | Fantasy Kingdom village + Meadow | Warm farmland, fences, lanterns — the home worth missing |
| The Reach | Sparse meadow + **Scifi Space** rigs/crates/cables | Big empty grassland scarred by industrial extraction |
| Old Kaveth | Fantasy Kingdom ruins + **AncientEgypt** monuments | Monumental ruins built *around* the Veil; beautiful at night, nothing attacks you in the outer ring |
| Verath | **Western** docks/boardwalks + Kingdom harbor props | Frontier port, salt-bleached wood, cranes over water |
| The Between | **Prototype** pack geometry, floating, heavy fog | Abstract non-place — graybox *as* aesthetic: the plane that isn't finished being real |
| Ashan | AncientEgypt domestic + warm meadow | Settled, golden-hour, gardens — the only plane with no enemies |
| Convergence | Scifi + Prototype + tears everywhere | Cael's apparatus mid-operation; the Veil under strain |

Add the new packs to `DEFAULT_PACKS` in `fetch_assets.sh`. Watch unit
scale per pack (see the MeadowForest `_UNIT` lesson — verify each
pack's authoring scale before scattering).

### B2. Lighting & sky pass

Each `env_*.tres` gets a deliberate sun angle/color + fog + sky
gradient, not just a tint: Tamori late-morning, Kaveth night with
emissive Veil-light, Verath overcast sea-glare, Between directionless
fog, Ashan golden hour, Convergence harsh violet. One signature
ambient particle per plane at most (drifting pollen / dust / veil
motes) — cheap GPUParticles3D, big identity payoff.

### B3. A shared Veil visual language

The Veil is the game's one recurring motif; it should look like *one
thing everywhere*:

- **`veil_tear.tscn`** — replace the placeholder emissive torus (used
  in `reach.tscn` and elsewhere) with a small layered scene: torus +
  inner distortion disc + GPUParticles + OmniLight + low hum (B4).
  Reused by portals, rest points ("stable tear"), story tears, and
  Cael's apparatus at different scales/colors.
- **Scar tissue** — a rigid, crystalline decal/mesh set marking
  Mender-stitched areas (visibly *wrong* against organic scenery).
  The Between's reveal — scar tissue vs. self-healing Veil — becomes
  something the player has already been reading for two acts.

### B4. Audio (currently zero)

Minimum viable identity: one ambient loop per plane + combat SFX set
(swing, hit, crit, death, telegraph warning, portal). Even
placeholder-quality audio is a step-change; the game is silent today.

### B5. Ground variety

Replace the single-color 46 m `BoxMesh` grounds with per-plane tiled or
vertex-colored ground meshes and gentle height accents (raised road,
sunken field). Full terrain stays out of scope (per CLAUDE.md).

---

## Workstream C — Thicker levels

### C1. Layout grammar (applies to every scene)

Every scene gets, instead of an open square:

1. **Entrance vista** — first frame after fade-in is composed (portal
   placed so the camera reads landmark + path).
2. **A landmark** — one tall/emissive thing visible from anywhere,
   orienting the player (Tamori: anchor shrine; Reach: the rig; Kaveth:
   the monument; Verath: the crane; Convergence: the apparatus).
3. **A shaped main path** — cliffs/walls/fences channel movement
   through 2–3 authored encounters with distinct grammar (open first
   read, then a chokepoint, then an ambush or pack camp).
4. **One side pocket** — off-path reward: equipment pickup (system
   exists, barely used), lore StoryEvent, or a hidden portal
   (`levels.md` promises the exploration portal type; ship at least one
   per act).
5. **Exit gate** — portal whose unlock condition is legible in-world.

### C2. Split planes into 2–3 scenes

Act 1 already does this (village → road → fields → anchor) and it's the
best-paced act as a result. Once Workstreams A/B make scenes cheap to
flavor, split Act 2–3 planes per `levels.md`, dividing each plane's XP
total across more, smaller kills per `progression.md`'s stated rule:

- **Reach**: approach road (skirmisher introduction, the Fence's camp)
  → extraction rig (pack camps, enforcer elite, the Deal).
- **Kaveth**: outer ruins at night (no combat — trust the tone doc, let
  it be beautiful; Mira beat) → deep vault (husks, shade ambushes).
- **Verath**: docks (dock-blade skirmishers among crates) → seawall
  (Cael glimpse, Sarro's portal choice).
- **Between**: single scene, but rebuilt as floating islands with the
  scar-tissue/self-healing reveal as *walkthrough environment art*.
- **Convergence**: approach (zealot gauntlet with support archetype
  earning its keep) → Cael's arena (Workstream D).

### C3. Rest points as pacing beats

`rest_point.gd` exists; give each scene's rest point one short
companion conversation (rotating pool) so rests become the quiet
moments the narrative docs care about, not just a heal button.

---

## Workstream D — Bosses per bosses.md

Implement `BossPhaseController` + ability sequencer once, then author
three fights:

1. **Act 1 — Mender Anchor** (build first; it's the template): rig as a
   second attackable objective, Anchor Surge interrupt (A4), Veil
   Shards line telegraphs (A3), phase-3 conviction channel. She doesn't
   die — fight ends in the choice, which the current
   kill-the-`anchor_warden` scene contradicts.
2. **Act 2 — Extractor Engine**: rotating Harvest Beam + destructible
   pillars + soak zones. Pure mechanics, horror tone.
3. **Act 3 — Cael**: Planar Echo (reuses fights 1–2's abilities — free
   by then), Collapse Points shrinking the arena, and the
   conviction-gated dialogue phase 3 (the current `convergence.gd`
   kill-only path becomes the low-conviction branch).

---

## Workstream E — Fun & feel (the juice pass)

- **Hit feedback**: 40–60 ms hit-stop on melee connect, small knockback
  nudge, impact flash/particle on the victim, camera micro-shake on
  crits. All in `melee_attacker.gd`/`enemy_controller.gd`; a day of
  work that transforms moment-to-moment feel.
- **Death**: enemies currently `queue_free()` mid-swing — add a fall +
  dissolve/fade and leave the loot sparkle.
- **Ability track**: levels currently grant only HP/to-hit
  (`progression.md` admits this). Wire level-up unlocks: Sarro —
  Action Surge (2), Shield Bash/interrupt (3), feat choice (5); Liris —
  real Warden kit when spellcasting lands, conviction-flavored
  upgrades to Guiding Bolt/Channel Divinity. Move the hotbar out of
  `level_base.gd`'s hardcoded handlers into per-character ability data
  so unlocks are possible at all.
- **Dialogue over gold rings**: convert the six meaningful choices
  (overview.md table) from `StoryEvent` markers to real
  `.dialogue` scenes, Extractor Deal first (it's the first one players
  hit and it's currently a single [F] press with no choice in it).
- **Lived-in NPCs**: Tamori and Ashan get 3–4 `VillageNPC`s with idle
  walk loops between waypoints — the "complete small story" planes
  need people in them.

---

## Suggested order

Each phase is playable and shippable on its own; later phases get
cheaper because of earlier ones.

1. **Feel + skirmisher + telegraphs** (A1 ranged, A3, E hit-feedback):
   biggest fun-per-effort; combat becomes positional and juicy in every
   existing scene without touching a single layout.
2. **Biome recipes + env/audio pass** (B1, B2, B4): every plane
   instantly distinct; pure content tables once the refactor lands.
3. **Act 1 vertical slice** (C1 grammar on the four Tamori scenes, D1
   Mender Anchor, E dialogue for the Warden's Ritual): Act 1 becomes
   the quality bar the rest of the game copies.
4. **Act 2 thickening** (C2 splits, A2 ambush/pack/leash in anger, B3
   Veil language, D2 Engine).
5. **Act 3 + systems payoff** (Ashan with NPCs and zero combat, D3
   Cael, E ability track completed, conviction plumbing end-to-end).
6. **Tuning loop** per `progression.md` after each act.

## Explicitly out of scope (unchanged from CLAUDE.md)

Procedural dungeons, crafting, difficulty modes, free camera rotation,
Terrain3D, spawn randomization in act content.
