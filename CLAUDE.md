# Wayfarer — CLAUDE.md

Cosmic fantasy RPG. Two companions (Sarro + Liris) follow damage left by well-meaning antagonists destabilizing the Veil (planar portal network). Tone: Blade of the Immortal meets Planescape. Pre-production.

## Project structure

```
scenes/
  world/       main world/exploration scenes
  combat/      real-time-with-pause combat scenes
  ui/          HUD, menus, dialogue
scripts/
  characters/  WayfarerCharacter resource + companion factories
  combat/      CombatManager, player input handler
  world/       plane transitions, Veil portal logic
  ui/
assets/
vendor/
  godot-srd-addon/   git submodule — the SRD rules engine
addons/
  srd -> ../vendor/godot-srd-addon/addons/srd  (symlink)
```

## SRD addon

All rules (combat, conditions, saving throws, spells, feats, AI, etc.) live in `addons/srd/`. Import with `git submodule update --init`.

The Wayfarer layer on top:
- `WayfarerCharacter` — wraps CharacterStats + ClassData + feats + equipment
- `CombatManager` — orchestrates CombatOrder, AI turns, SpellResolver, pause

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

Real-time-with-pause. CombatManager runs initiative order; player can pause anytime to direct actions. Enemy turns run through CombatAI with overridable positional callbacks.

Override `CombatManager.build_ai_context()` in the scene to wire is_in_melee_range / can_reach / distance to actual node positions.

## Key design rules

- No crafting
- No inventory management mini-game
- Combat meaningful but not the focus
- Portal transit requires conviction (Liris must earn it; Sarro is exempt)
- Antagonists (Menders + Extractors) are sympathetic — resolution is convincing them to stop, not defeating them
