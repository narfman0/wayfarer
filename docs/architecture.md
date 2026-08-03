# Wayfarer — State & Architecture

As-built reference, 2026-08-03. This documents what IS in the repo, not
plans. Design-intent references (kept): `design/bosses.md`,
`design/gameplay.md`, `design/levels.md`, `design/progression.md`,
`design/setting-classes.md`, `narrative/`.

## What the game is right now

A playable, start-to-finish 3D action RPG in Godot 4.7: two-character
party (Sarro + companion Liris), SRD 5e-style dice combat, click/WASD
movement, fourteen scenes across seven planes, three telegraph-driven
boss fights, six meaningful story choices threading a conviction score
into two different endings. All art is Synty placeholder kits over
graybox arenas; all audio is synthesized placeholder WAV.

## World inventory

Every scene is a flat box arena (BoxMesh ground + infinite
WorldBoundaryShape3D floor). No terrain, no heightmaps — walkable space
is a plane; "cliffs" and hills are non-colliding backdrop dressing.

| Scene | plane_id | Arena (m) | Content |
|---|---|---|---|
| tamori | tamori | 40×40 | Village: 3 NPCs, opening dialogue, shrine, gated exit |
| tamori_road | tamori_road | 56×26 | Bandits, patroller, waymark tower, Mender campsite lore |
| tamori_fields | tamori_fields | 44×44 | Bandit/brute camp, patrol, Blackened Paddy lore, loot |
| tamori_anchor | tamori_anchor | 36×36 | BOSS: Idris + crystallization rig → Warden's Ritual choice |
| reach | reach | 46×46 | Skirmisher intro, fence-camp pack, the Extractor Deal dialogue |
| reach_rig | reach_rig | 46×46 | Ambush, pack camp, elite; BOSS: Extractor Engine |
| kaveth | kaveth | 46×46 | Combat-free night ruins, Defector's Records, lore |
| kaveth_vault | kaveth_vault | 42×42 | Husk pack, lurker-shade ambush, Waking Tear beat |
| verath | verath | 46×46 | Dock-blade pack, Faction Accord |
| verath_seawall | verath_seawall | 46×30 | Cael glimpse, Sarro's Portal choice dialogue |
| between | between | 46×46 | Prototype-graybox non-place (single scene) |
| ashan | ashan | 46×46 | Zero combat; 4 wandering villagers, the Reunion |
| convergence_approach | convergence_approach | 44×44 | Zealot gauntlet with support healers |
| convergence | convergence | 50×50 | BOSS: Cael — conviction-gated dialogue or combat ending |

World graph (portals, flag-gated): tamori → road → fields → anchor →
reach → reach_rig → kaveth → kaveth_vault → verath → verath_seawall →
between → ashan → convergence_approach → convergence.
`SceneManager.LEVELS` is the plane_id → scene registry.

## Systems architecture (~5.3k lines GDScript)

**Autoloads** (`scripts/system/`): `SceneManager` (level registry,
fade transitions, portal spawn staging) · `GameState` (party, XP/level
ups, story flags, conviction score, save/load; SAVE_VERSION 3) ·
`AudioManager` (pooled SFX + crossfading per-plane ambient loops) ·
`DialogueManager` (addon).

**Level pipeline** (`scripts/world/level_base.gd`, ~470 lines — every
scene extends it or a subclass): party sync + debug-party fallback,
enemy character assignment from the factory, generated trimesh prop
collision, animator attachment, autosave on entry, defeat/respawn,
dialogue camera (dolly/yaw/focus blend), wheel zoom, hotbar abilities
(Second Wind, Guiding Bolt, Healing Word, Channel Divinity, Shield
Bash lvl 3, Action Surge lvl 2), pause action queue. Per-scene scripts
(`anchor_tear.gd`, `reach_rig.gd`, `convergence.gd`,
`verath_seawall.gd`, `tamori.gd`) add boss fights and beats on top.

**Combat** (`scripts/combat/`): `enemy_controller.gd` — one FSM
(Patrol/Chase/Attack/Return) with four archetypes chosen per type or
per node: bruiser, skirmisher (kiting + dodgeable projectiles), heavy
(telegraphed slam), support (interruptible group-heal channel). Plus:
visible cast bars with interrupt/stun, pack aggro (`pack_id`),
spawn-leashing with walk-home heal, ambush hiding
(`ambush_trigger.gd`), boss phase thresholds (60/30%), knockback,
loot drops. `telegraph.gd` — circle/line/cone/donut ground warnings
with `contains()` hit-tests (dodge-out always works). `juice.gd` —
hit-stop, camera shake, impact particles, death collapse.
`veil_rig.gd` — stationary attackable objectives (Idris's rig, Engine
pillars). Bosses are level-script orchestrations over these parts —
there is no separate boss framework.

**Procedural per-plane identity** (all keyed by plane_id, split scenes
alias to their plane): `scenery.gd` — PACKS registry (folder/ext/unit
per Synty pack) + RECIPES (backdrop ring, scatter layers, ground
tint); seeded by plane_id, collision-free, backdrop pieces auto-slide
clear of spawns + camera boom. `atmosphere.gd` — sun angle/color/
energy + one signature CPUParticles field per plane.
`resources/env_*.tres` — sky/fog/glow per plane. `AudioManager`
ambients per plane. `veil_tear.gd`/`scar_tissue.gd` — the shared Veil
motif and Mender-scar dressing.

**Story**: dialogue files in `dialogue/` (Dialogue Manager syntax) set
flags and conviction via `do GameState...`. Six choices: Warden's
Ritual, Extractor Deal, Sarro's Portal, (Mender-You-Understand — not
yet built), Cael's Resolution (conviction ≥ 2 → dialogue ending),
Final Portal. `story_event.gd` gold-ring beats remain for minor lore.
`npc.gd` — talkable/barking villagers with optional wander loops.

## Asset pipeline

Synty FBX lives on srv (`srv.blastedstudios.com:49200`); the
asset-cooker bakes them to gltf+bin with a shared per-pack atlas and
the cm→m/Y-up correction on a child node (scene roots are metre-scale
— never re-apply 0.01). `./fetch_assets.sh` syncs `assets/meshes/`
(gitignored). Six packs in use: Fantasy Kingdom, Fantasy Characters,
Base Locomotion, MeadowForest, AncientEgypt, Scifi Space, Western,
Prototype. Placeholder audio is generated by `tools/gen_audio.py` into
`assets/audio/` (tracked).

## Verification

Headless smoke harnesses in `future/tests/harnesses/` (phase1,
anchor_fight, act2, act3, all_planes) — each prints `ALL PASS` /
nonzero exit — plus `plane_gallery.tscn` under Xvfb which screenshots
every plane to `.screenshots/` for visual review. Numeric checks have
missed composition bugs twice; always eyeball the gallery after
visual changes.

## Tuning knobs (where to change what)

- **Enemy placement/difficulty**: per-node exports in the scene files —
  `enemy_type`, `xp_value`, `aggro_radius`, `archetype`, `pack_id`,
  `leash_radius`, `patrol_points`, `loot_preset`, `is_boss`.
- **Statblocks**: `character_factory.gd` `make_enemy()` roster.
- **Archetype feel**: consts at the top of `enemy_controller.gd`
  (ranged band, slam radius/windup, support cast/period).
- **Boss mechanics**: consts at the top of `anchor_tear.gd`,
  `reach_rig.gd`, `convergence.gd` (periods, damage dice, phase gates,
  conviction threshold).
- **Plane look**: `scenery.gd` RECIPES, `atmosphere.gd` PLANES,
  `resources/env_*.tres`.
- **XP curve**: scene `xp_value`s + `docs/design/progression.md`.
- **Player abilities**: `level_base.gd` ability functions + consts.

## Known placeholder quirks / not built

- Scifi "asteroid" backdrop meshes carry station-sign atlas textures
  (cooker best-guess texture wiring).
- Crystal adds in the Anchor fight deferred (no dynamic enemy
  spawning).
- The Between has not had its floating-islands rebuild; the
  Mender-You-Understand choice is not built.
- Out of scope by decision: procedural dungeons, crafting, difficulty
  modes, free camera rotation, Terrain3D, spawn randomization.
