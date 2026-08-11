# Wayfarer — State & Architecture

As-built reference, updated 2026-08-11 after the BG3-direction pivot.
This documents what IS in the repo, not plans. Design-intent references
(kept): `design/bosses.md`, `design/gameplay.md`, `design/levels.md`,
`design/progression.md`, `design/setting-classes.md`, `narrative/`.
Where those docs and this one disagree, this one describes the build.

## What the game is right now

A playable, start-to-finish 3D RPG in Godot 4.7 with a **locked
orthographic isometric camera** (45°/−30°): two-character party (a fully
built player character + Liris, a customizable Warden companion), SRD 5e
combat that runs **real-time by default with an opt-in BG3-style
turn-based mode**, fifteen scenes across seven planes plus a procedural
dungeon, three telegraph-driven boss fights, a gold/inventory/shop
economy, and six meaningful story choices threading a conviction score
into two endings. Art is Synty kits (now including Samurai Empire and
Dark Fantasy); audio is synthesized placeholder WAV.

## World inventory

Two terrain styles coexist:

- **Island-grid scene** (`dungeon_run` only): a `TiledTerrain`
  mesh over `IslandGrid` (2 m tiles, 32×32 default, flat top at y=0)
  with noise-displaced craggy undersides floating in a **void sky**;
  click-to-move routes on `AStarGrid2D` (`player_controller.gd`).
  (Tamori trialed the grid and was reverted upstream to a flat 80×80 m
  slab.)
- **Flat arenas** (the other 14 scenes): BoxMesh slab over an
  infinite `WorldBoundaryShape3D`, 36–56 m per side. Invisible boundary
  walls are generated at load, sized from the ground collider or the
  GroundMesh AABB (`level_base._setup_bounds`).

| Scene | plane_id | Content |
|---|---|---|
| tamori | tamori | 80 m starting plane: village NPCs, shop, dungeon rift, opening dialogue |
| dungeon_run | dungeon_run | Procedural: rooms carved into the void, corridors, **CR-budgeted encounter groups** (see below), seeded loot, exit portal |
| tamori_road / _fields / _anchor | — | Act 1 chain; anchor = Idris + rig boss → Warden's Ritual choice |
| reach / reach_rig | — | Skirmisher intro + Deal dialogue → Extractor Engine boss |
| kaveth / kaveth_vault | — | Combat-free night ruins → husk/shade vault, Waking Tear |
| verath / verath_seawall | — | Dock blades → Cael glimpse + Sarro's Portal choice |
| between / ashan | — | Prototype non-place; combat-free golden-hour village (wandering NPCs) |
| convergence_approach / convergence | — | Zealot gauntlet (support healers) → Cael, conviction-gated ending |

`SceneManager.LEVELS` is the plane_id → scene registry. Portal chain
gates on story flags as before.

## Systems architecture

**Autoloads**: `SceneManager` (registry, fades, portal staging) ·
`GameState` (party, XP/level-ups, flags, conviction, **gold +
inventory**, save/load; SAVE_VERSION 5) · `AudioManager` (SFX pool +
per-plane ambient crossfade) · `CombatManager` (encounter state,
initiative, TB turn engine, reactions) · `UITheme` (Cinzel/Crimson
fantasy theme) · `DialogueManager` (addon).

**Combat** — two layers over one SRD core:

- *Real-time (default)*: the archetype FSM in `enemy_controller.gd` —
  bruiser / skirmisher (kiting + dodgeable projectiles) / heavy
  (telegraphed slams) / support (interruptible group heal), plus cast
  bars + Shield Bash interrupts, pack aggro, spawn-leashing, ambush
  triggers, boss phases. `telegraph.gd` ground warnings with
  `contains()` hit-tests; `juice.gd` feel layer.
- *Turn-based (opt-in, [T] in combat)*: `CombatManager` rolls d20+DEX
  initiative and runs one combatant at a time with per-turn
  action/bonus/reaction/movement budgets (node metadata), opportunity
  attacks via an accept/skip reaction modal, and a movement-range ring.
  Enemy turns are archetype-aware (skirmishers volley, supports heal
  the most wounded packmate, heavies fight as melee — telegraph-dodging
  is inherently real-time). **Bosses refuse TB** (`enter_tb_mode`
  returns false; latched TB force-exits when a boss joins) because boss
  fights are timed orchestrations.
- Player abilities live in `level_base.gd` gated on turn economy in TB;
  `melee_attacker.gd` resolves rolls through `Combatant` (bonus hooks +
  crit_threshold from build choices).

**Build choices** (`character_progression.gd`): creation wizard picks
class (all four: Soldier, Ghost, Warden, Psion), **species, background**
(SRD addon resources), fighting style, ability scores, skills, starting
feat, and **cantrips/spells for casters**; Liris is optionally
customized. Level 3 grants subclass; class ASI levels grant +2/+1+1 or
a feat — all spent at rest points (`level_up_screen.gd`); the HUD also
offers short/long rest buttons out of combat. Choices persist as
records replayed over saved base scores; max HP recomputes from
scratch. Spells cast through `level_base.cast_spell` from the skill bar
(click or keys 7 8 9 0), spending `EnergySlots` (`use_slot`).

**Dungeon (The Rift Below)**: `rift_portal.gd` (extends VeilPortal) asks
for a difficulty before entry — Faint/Open/Churning/Screaming Rift →
`dungeon_cr_tier` flag (easy ×0.5 / fair ×1.0 / hard ×1.5 / deadly
×2.2). `dungeon_run.gd` gives each room a CR budget
`(1 + party_level × 0.5) × tier_mult` (final room ×1.5) and draws a
seeded group from the ROSTER (skeleton 1.0 / skeleton_ranger 1.0 /
skeleton_armored 2.0 / hunter 3.0 — each with statblock, XP 150–600,
loot table). **Every dynamic spawn goes through
`level_base.register_enemy()`** — that's what attaches the character
sheet and death/phase wiring; skipping it yields a blank shell.

**Animation**: `character_animator.gd` retargets Base Locomotion clips
onto every humanoid and layers **Sword Combat oneshots** — attack,
heavy attack (crits), hit react, and death — plus **cast gestures**
(point / prayer / arms-raised / prayer-loop, borrowed from the
Idles + Emotes packs; no dedicated spellcasting pack exists). Combat
uses **contact-frame timing**: rolls resolve at swing start, but
damage/SFX/numbers land at the visual contact — player wind-ups are
0.18–0.30s with a movement-cancelable follow-through, enemy swings
wind up 0.5s (dodgeable by stepping out, interrupted by a stagger; the
wind-up window is where boss impact-area projection will hook in), and
spells fire at a 0.4s gesture apex. Bow Combat clips + bow/arrow
meshes are confirmed cooked on srv but intentionally unwired (no player
ranged weapon exists yet).

**Economy**: `GameState.gold`/`inventory` with signals; `LootTable`
(weighted, seeded tables) → `LootBag` (searchable Area3D on corpses) →
`loot_bag_screen`; `shop_npc` + `shop_screen` (Odo's Goods in Tamori);
`inventory_screen` from the pause menu; walk-over `gold_pickup`; a real
death screen with Try Again / Main Menu.

**UI**: `party_panel` (BG3-style portrait cards, click to select) +
`skill_bar` (64 px icon slots from `ability_registry`, tooltips) +
`combat_hud` (TB controls, reaction modal) + HUD toasts, gold readout,
pending-build-choice hint.

**Procedural identity (dormant by default)**: `scenery.gd` biome
recipes and the `EditorPreview` node still exist but
`generate_scenery` now defaults to **false** — manual placement is the
preferred direction; recipes are opt-in per scene and the editor
preview honors the same flag. `atmosphere.gd` still runs everywhere:
void-sky environment override, dimmed sun + cool fill light, per-plane
motes. Veil tears (`veil_tear.gd`) and scar tissue remain the shared
motif on portals/rest points.

**Story**: dialogue files set flags/conviction via `do GameState...`;
six choices (Warden's Ritual, Extractor Deal, Sarro's Portal, Cael's
Resolution at conviction ≥ 2, Final Portal; Mender-You-Understand still
a gold ring). `npc.gd` villagers talk, bark, and wander.

## Asset pipeline

Synty FBX on srv (`srv.blastedstudios.com:49200`) cooked to gltf+atlas
(cm→m/Y-up correction baked on a child node — scene roots are
metre-scale). `./fetch_assets.sh` default mode fetches **only assets
referenced by the project** (~50 MB); `--pack`/`--all` for whole packs.
Post-fetch it runs `tools/patch_gltf_materials.py` (BLEND→MASK +
texture-index fixes). Packs in use include Fantasy Kingdom/Characters,
Base Locomotion, MeadowForest, AncientEgypt, Scifi, Western, Prototype,
**Samurai Empire, Dark Fantasy**. Placeholder audio via
`tools/gen_audio.py` (tracked in `assets/audio/`).

## Verification

Headless harnesses in `future/tests/harnesses/` (each prints ALL PASS,
nonzero exit on failure): `phase1_smoke` (feel + spells + zoom + combat clips),
`anchor_fight_smoke`, `act2_smoke`, `act3_smoke`, `progression_smoke`
(39 build-choice checks), `systems_smoke` (TB, boss refusal, loot,
gold, pathfinding), `all_planes_smoke` (every plane incl. dungeon_run:
atmosphere, bounds-vs-mesh, scenery flag honesty). `plane_gallery` and
`ui_gallery` screenshot under Xvfb — always eyeball after visual work.

## Tuning knobs

- Encounters: per-node exports (`enemy_type`, `xp_value`, `archetype`,
  `pack_id`, `leash_radius`, `patrol_points`, `loot_table_key`,
  `loot_seed`, `is_boss`).
- Statblocks: `character_factory.make_enemy`. Loot: `loot_table.gd`.
- Archetype/TB feel: consts atop `enemy_controller.gd` /
  `combat_manager.gd` (RT_ROUND, movement math).
- Boss mechanics: consts atop `anchor_tear.gd`, `reach_rig.gd`,
  `convergence.gd`. Dungeon shape: consts in `dungeon_run.gd` +
  `island_grid.gd`.
- Plane look: `atmosphere.gd` PLANES, `resources/env_*.tres`; dormant
  scenery recipes in `scenery.gd`.
- Player abilities/spells: `level_base.gd`, `ability_registry.gd`,
  addon `spell_data.gd`.

## Known gaps / decided-out

- TB enemy turns don't use telegraphs (real-time-only by design);
  boss fights are RT-only.
- The Between rebuild and the Mender-You-Understand dialogue remain
  unbuilt.
- Dungeon XP (150–600/kill, repeatable) is not reconciled with the act
  XP curve — tuning-playthrough item.
- Bow Combat assets are ready on srv but unwired (no ranged player
  weapon).
- Terrain3D was trialed and reverted; the island grid now lives only in
  the dungeon.
- Out of scope by decision: free camera rotation, difficulty modes in
  act content (the rift CR select is the challenge dial), spawn
  randomization outside the dungeon.
