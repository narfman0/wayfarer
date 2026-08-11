# Wayfarer — CLAUDE.md

Cosmic fantasy RPG. Two companions (Sarro + Liris) trace damage left by well-meaning antagonists destabilizing the Veil (planar portal network). Tone: Blade of the Immortal meets Planescape. Playable prototype through all three acts. **`docs/architecture.md` is the authoritative as-built reference — read it first.**

## Gameplay pillars (as built)

- **Feel**: sword-and-skill combat over hidden D&D SRD rules; BG3-style UI (portrait party panel, icon skill bar).
- **Camera**: locked orthographic isometric (yaw 45°, pitch −30°), follows Sarro; wheel zooms ortho size 14–26.
- **Combat**: real-time by default; **[T] toggles BG3-style turn-based** (initiative, action economy, opportunity attacks). Bosses refuse TB — their fights are timed orchestrations. Enemy archetypes: bruiser / skirmisher / heavy (telegraphed slams) / support (interruptible heals). Sword Combat animation clips on all humanoids.
- **World**: hand-authored scenes (13 flat arenas + Tamori's 80 m floating island) plus a **procedural dungeon** (dungeon_run: rooms carved into a void map, CR-budgeted encounters selected at the rift portal). Procedural scenery exists but is opt-in per scene (`generate_scenery`, default off — manual placement preferred).
- **Enemy aggro**: proximity sphere → Patrol → Chase → Attack (+ Return/leash) state machine; pack aggro via `pack_id`; ambush triggers. Dynamic spawns MUST go through `level_base.register_enemy()` or they have no character sheet.
- **Progression**: XP levels 1–20 (kills + story beats). Build choices — fighting style, feats, ASI, subclass at 3 — are spent **at rest points**; species/background/spells picked at creation. Liris is story-driven (conviction arc). Gold/inventory/shops/loot bags exist.

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
- `WayfarerCharacter` — wraps CharacterStats + ClassData + equipment + build choices (feats/subclass/spells)
- `CharacterProgression` — build-choice registries, pending-choice engine, combat bonuses
- `CombatManager` — encounter state + the turn-based engine (autoload)

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

`CombatManager` (autoload) owns encounter state: real-time by default (6 s rounds only poll for combat end; the archetype AI runs free), turn-based on toggle (initiative queue, per-turn action/bonus/reaction/movement metadata, OA reaction modal). Attack resolution flows through `WayfarerCharacter.make_combatant()` → SRD `Combatant` (build-choice bonuses + crit range stamped there). Spells cast via `level_base.cast_spell(spell, caster)` from the skill bar.

## Testing

Headless suites in `future/tests/harnesses/` (phase1, anchor_fight, act2, act3, progression, systems, all_planes) — run any with `godot --headless res://future/tests/harnesses/<name>.tscn`; each prints ALL PASS / exits nonzero. Xvfb galleries (`plane_gallery`, `ui_gallery`) screenshot to `.screenshots/`. Run relevant suites before committing; screenshots after visual changes.

## Key design rules

- Combat is snappy and meaningful but narrative is the focus
- Portal transit requires conviction (Liris must earn it; Sarro is exempt)
- Antagonists (Menders + Extractors) are sympathetic — resolution is convincing them, not defeating them (conviction ≥ 2 unlocks Cael's dialogue ending)
- One difficulty in act content; the dungeon rift's CR select is the challenge dial
- Enemy placement is authored in act content; the dungeon is the sanctioned procedural space
