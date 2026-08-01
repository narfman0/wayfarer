# Progression — XP Curve & Encounter Budget (first draft, for tuning)

Status: EXPERIMENT. Per-kill + quest XP (supersedes gameplay.md's original
no-levels design — see amendment there). We tune act by act, level by
level, against this draft rather than redesigning the system.

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
