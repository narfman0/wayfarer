# Progression — XP Curve & Encounter Budget (first draft, for tuning)

Status: EXPERIMENT. Per-kill + quest XP (supersedes gameplay.md's original
no-levels design — see amendment there). We tune act by act, level by
level, against this draft rather than redesigning the system.

AMENDED 2026-08-11:
- **Levels now grant real choices**, not just HP/to-hit: fighting style +
  starting feat at creation, subclass at 3, ASI-or-feat at class ASI
  levels — spent at rest points via the level-up screen
  (`CharacterProgression`). The "what levels grant" section below is
  stale on this point.
- **Spells are castable** (skill bar keys 7–0 → `level_base.cast_spell`),
  so caster levels now mean slots + prepared spells, not just stats.
- **Dungeon XP exists outside this curve**: the Rift Below awards
  150–600 XP/kill (roster-flat, repeatable). Not yet reconciled with the
  act curve — flag for the tuning playthrough.
- The "current placements" tables predate the act splits (road/fields/
  anchor scenes and the reach/kaveth sub-scenes) — plane totals still
  hold; per-scene rows are historical.

## Model

- **Per-kill XP**: every `EnemyController` has `xp_value`; the whole party
  is granted that amount on the kill (no split, both companions level in
  lockstep).
- **Quest/event XP**: any dialogue or trigger can `do GameState.grant_xp(N)`.
  A kill is never double-counted — quest awards are for non-kill beats.
- **Soft curve**: nothing is level-gated. Skipping fights just means
  arriving a level or two low; the SRD math keeps ±2 levels survivable.
- Enemies respawn per session (levels.md), so re-kills can re-award —
  acceptable for now; revisit if farming becomes attractive.

## Targets

SRD thresholds: level 20 at **355,000 XP**. Target: hit 20 at the
Convergence approach (storyline beat 3.7). Quest XP should carry roughly
a quarter of the total so pacifist-leaning play isn't starved.

| Act | Levels | XP span | Kills (approx) | Typical xp_value | Quest XP share |
|-----|--------|---------|----------------|------------------|----------------|
| 1 — Tamori | 1 → 5 | 0 → 6,500 | ~25 | 50–300 | ~1,500 (elder, Odo, Idris, ritual) |
| 2a — Reach | 5 → 8 | 6,500 → 34,000 | ~30 | 300–700 | deal/negotiation beats |
| 2b — Kaveth | 8 → 11 | 34,000 → 85,000 | ~30 | 700–1,400 | defector, tear reveal |
| 2c — Verath | 11 → 13 | 85,000 → 120,000 | ~25 | 1,000–1,800 | faction resolution, portal beat |
| 2d — Between | 13 → 15 | 120,000 → 165,000 | ~10 | 2,500–4,000 | the vision (large event award) |
| 3a — Ashan | 15 → 16 | 165,000 → 195,000 | 0 | — | reunion milestone: 30,000 event XP |
| 3b — Convergence | 16 → 20 | 195,000 → 355,000 | ~15 | 6,000–12,000 | conversation beats award too |

Rule of thumb when placing an encounter: `xp_value ≈ (level XP span) /
(kills planned in that stretch)`, rounded to something readable.

## Current placements (draft values)

| Enemy | Scene | xp_value |
|---|---|---|
| BanditGuard | tamori.tscn | 100 |
| RoadBandit1–2 + patroller | tamori_road.tscn | 100 each |
| AmbushBrute | tamori_road.tscn | 250 |
| FieldBandit1–4 | tamori_fields.tscn | 100 each |
| FieldBrute1–2 | tamori_fields.tscn | 250 each |
| Brute1–2 (arena) | tamori_anchor.tscn | 250 each |
| Warped Anchor Warden (boss) | tamori_anchor.tscn | 1500 |
| Odo intro / fields intel | village.dialogue | 25 + 25 |

Full clear of Act 1 content: 100 + 50 + 550 (road) + 900 (fields) +
2,000 (anchor) = **3,600 XP → level 4** at the boss kill (threshold
2,700), on curve; Act 2 entry lands mid-level-4.

## Acts 2–3 placements (v1 scenes — fewer, fatter kills)

v1 ships each plane as ONE scene, so kill counts are lower than the
target table and xp_values are proportionally fatter. When planes split
into multiple scenes, divide these values across more enemies without
changing plane totals. Quest beats are StoryEvent markers (gold rings,
[F] to resolve, once ever) until real dialogue scenes replace them.

| Plane | Kills | Quest events | Plane total |
|---|---|---|---|
| reach | 6× guard @2,000 + 3× enforcer @3,500 + captain @2,500 | Extractor Deal 2,500 (`reach_done`) | 27,500 |
| kaveth | 8× husk @3,500 + 2× shade @6,000 | Records 5,000 (`kaveth_records`) + Waking Tear 6,000 (`kaveth_done`) | 51,000 |
| verath | 5× dock blade @5,000 | Accord 5,000 (`verath_resolved`) + Cael glimpse 5,000 (`saw_cael`) | 35,000 |
| between | 4× veil fragment @5,000 | Ancestor's Fragment 25,000 (`act2_done`) | 45,000 |
| ashan | none | Reunion 30,000 (`ashan_done`) | 30,000 |
| convergence | 8× zealot @10,000 + Cael @65,000 | Menders 10,000 + Conversation 8,000 | 163,000 |

Cumulative on a full clear: 3,600 → 31,100 (reach) → 82,100 (kaveth) →
117,100 (verath) → 162,100 (between) → 192,100 (ashan) → 290,100 before
Cael → **355,100 at the Cael kill = level 20 exactly at the finale.**
Each plane lands ~1 level under the target-table entry for the *next*
act — the act-by-act tuning pass decides whether to thicken encounters
or accept the tighter curve.

Portal chain gates: `act1_done` → reach, `reach_done` → kaveth,
`kaveth_done` → verath, `saw_cael` → between, `act2_done` → ashan,
`ashan_done` → convergence. Cael's death sets `cael_fought` +
`game_won` (win screen).

### Testing a plane in isolation

Every level scene runs standalone (editor "Run Current Scene"): with no
party in GameState, WayfarerLevel spawns a debug party boosted to the
scene's `debug_party_level` (reach 5, kaveth 8, verath 11, between 13,
ashan 15, convergence 16) and suppresses ALL saving so tests never touch
the real slot.

Known cosmetic issue (pre-existing, all planes): far-from-camera
characters sometimes render in bind pose (lying flat, +90°X). Skeleton
data is correct (verified) and close-range/combat rendering is fine;
runtime workarounds (lod_bias, per-instance Skin, cull margin,
custom_aabb, skeleton rebind) all failed. Real fix: bake the armature
orientation upright in the cooker (fbx_to_glb.py) so the bind pose
stands, then re-cook Fantasy_Characters + re-fetch.

## Tuning loop

1. Play (or headless-run) an act; log `GameState.sarro.stats.xp` at each
   beat.
2. Compare against the table; adjust `xp_value`s and quest awards, not
   the thresholds.
3. When an act holds up, lock its values and move to the next.

## What levels currently grant

HP (hit die average + CON) and proficiency (attack/save/skill bonuses)
via SRD math; caster slots exist in the engine but no castable abilities
are implemented yet — the hotbar/ability track (gameplay.md) is where
"unlock your spells" becomes real. Until then, levels mean survivability
and to-hit.
