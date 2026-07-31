# Wayfarer — CLAUDE.md

Cosmic fantasy ARPG. Two companions (Sarro + Liris) trace damage left by well-meaning antagonists destabilizing the Veil (planar portal network). Tone: Blade of the Immortal meets Planescape. Pre-production.

## Gameplay pillars

- **Feel**: Diablo II combat, WoW hotbar abilities, D&D SRD rules underneath.
- **Camera**: fixed isometric overhead (~45° pitch), follows Sarro, mouse-wheel zoom only.
- **Combat**: real-time with optional pause (Space). Click-to-move + click-to-attack. Abilities on 1–4 / D-pad. SRD attack rolls + AC + saving throws run silently underneath.
- **World**: hand-crafted levels and enemy placement. No spawn randomization in shipped acts. Replayability comes from feat/build choices, not RNG. Random dungeons are a future optional add-on.
- **Levels**: acts composed of hand-crafted scenes connected by portals. Portal triggers are narrative, boss-gated, or exploration-based.
- **Enemy aggro**: proximity cylinder + optional LOS check → Patrol → Chase → Attack (Beehave BT).
- **Progression**: no XP levels. Story milestone feats + equipment drops + Liris conviction arc.

Design docs: `docs/design/gameplay.md`, `docs/design/levels.md`, `docs/design/bosses.md`
Narrative docs: `docs/narrative/overview.md` (start here), `docs/narrative/arc-detailed.md`, `docs/narrative/act-1.md`, `docs/narrative/act-2.md`, `docs/narrative/act-3.md`, `docs/narrative/setting.md`

## Project structure

```
scenes/
  world/       exploration levels (3D isometric)
  ui/          HUD, menus, dialogue, pause
scripts/
  characters/  WayfarerCharacter resource + companion factories
  combat/      CombatManager, ability system, enemy AI wiring
  world/       PlayerController, CompanionFollow, portal logic
  ui/
docs/
  design/      gameplay.md, levels.md (GDD)
  narrative/   act docs
assets/
  meshes/
    environment/ — ground planes, architecture (Synty modular kits)
    characters/  — Sarro, Liris, NPC meshes
    props/       — set dressing
vendor/
  godot-srd-addon/   git submodule — SRD rules engine (narfman0/godot-srd-addon)
addons/
  srd            -> ../vendor/godot-srd-addon/addons/srd  (submodule symlink)
  dialogue_manager/  vendored directly — Nathan Hoad dialogue manager
  phantom_camera/    vendored directly — cinematic camera (PhantomCamera3D)
  beehave/           vendored directly — behavior tree AI
```

## Level / terrain approach

Static Synty mesh assets — no GDExtension, no build step. Each level scene has:
- `Level/Ground` — MeshInstance3D; swap in Synty ground tile
- `Level/Props` — Node3D; child MeshInstance3D for set dressing
- `Level/Enemies` — hand-placed enemy nodes with patrol waypoints
- `Level/Triggers` — Area3D zones (aggro, cutscene, portal unlock)
- `Level/Portals` — entry and exit portal nodes

Drop Synty `.glb` files into `assets/meshes/` and instantiate in scene.
Terrain3D can be revisited later if procedural terrain becomes necessary.

## SRD addon

All rules (combat, conditions, saving throws, spells, feats, AI, etc.) live in `addons/srd/`. Import with `git submodule update --init`.

The Wayfarer layer:
- `WayfarerCharacter` — wraps CharacterStats + ClassData + feats + equipment
- `CombatManager` — orchestrates CombatOrder, AI turns, SpellResolver, optional pause

To update the addon:
```bash
cd vendor/godot-srd-addon && git pull && cd ../..
git add vendor/godot-srd-addon && git commit -m "chore: update srd addon"
```

## Companions

| Name | Class | Role |
|------|-------|------|
| Sarro | Soldier (Fighter) | Melee, STR 16, half-divine, passes Veil freely |
| Liris | Warden (Cleric) | Support/healer, WIS 16, conviction-based portal transit |

## Combat

Real-time ARPG. SRD initiative order drives AI tick rate invisibly. Player clicks to move and attack; abilities on hotbar (4 slots per character). Optional pause lets player queue actions for both companions. CombatManager handles attack rolls, damage, conditions, and death saves.

Override `CombatManager.build_ai_context()` in a scene to wire positional callbacks (is_in_melee_range, can_reach, distance) to actual node positions.

## Key design rules

- No crafting, no inventory mini-game
- Combat is snappy and meaningful but narrative is the focus
- Portal transit requires conviction (Liris must earn it; Sarro is exempt)
- Antagonists (Menders + Extractors) are sympathetic — resolution is convincing them, not defeating them
- One difficulty; optional pause is the accessibility lever
- Enemy placement is always authored; never random in act content
