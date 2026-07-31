# Wayfarer — Level & Act Structure

## Philosophy

Hand-crafted levels, authored encounters. Every enemy is placed intentionally — each encounter teaches the player something or advances the narrative. The world feels lived-in, not generated.

Replayability comes from character build choices, not procedural content. Procedural dungeons are a future addition, not a launch feature.

## Structure

```
Act 1 — Tamori (feudal Japanese plane)
  └─ Levels: Tamori Docks → Sword Road → Mender Outpost → Veil Anchor (boss)

Act 2 — Caelum Rift (storm-wracked sky plane)
  └─ Levels: Crumbling Spire → Storm Archive → Extractor Camp → Fracture Point (boss)

Act 3 — The Veil Itself (meta-plane, unstable)
  └─ Levels: Veil Crossing → Locus Core → Convergence (final)
```

Each act is 4–6 hours of content. Total runtime target: ~15 hours on first playthrough.

## Levels

Each level is a single Godot scene. A level scene contains:

- `Level/Ground` — MeshInstance3D, Synty ground tiles or tile grid
- `Level/Props` — set dressing (furniture, barrels, lanterns, environmental storytelling)
- `Level/Enemies` — Node3D with all hand-placed enemy nodes
- `Level/Triggers` — Area3D zones for aggro radii, cutscene triggers, portal unlocks
- `Level/Portals` — the entry and exit portal nodes

Levels are loaded via `SceneManager.change_level(path)`, which handles fade-out, save, load, fade-in.

## Portal system

Portals are the primary level transition mechanism. A portal can be:

| Type | Trigger | Example |
|------|---------|---------|
| Narrative | Dialogue flag set | Tamori elder gives Sarro coordinates |
| Boss-cleared | Boss death signal | Mender Outpost boss dies → anchor portal opens |
| Exploration | Player reaches location | Hidden portal behind waterfall |
| Conviction | Liris conviction ≥ threshold | Certain Veil crossings require Liris's belief |

Portal transition flow:
1. Player interacts with portal (F / A button).
2. If gated: check condition; show lore reason if blocked (e.g. "Liris hesitates — she doesn't believe this path is right yet").
3. Fade out → `SceneManager` loads next level → fade in at target portal's spawn point.

Portals are bidirectional by default. Players can backtrack to earlier levels; enemies respawn only on a new session (not on re-entry within the same play session).

## Enemy placement

Each enemy node in `Level/Enemies` has:

```gdscript
@export var patrol_waypoints: Array[NodePath] = []
@export var aggro_radius: float = 6.0          # metres
@export var requires_los: bool = true
@export var faction: SRD.Faction = SRD.Faction.MENDER
```

Designers place `WaypointMarker3D` nodes as children or siblings, then populate `patrol_waypoints`. The Beehave tree picks up these exports at runtime.

Encounter design rules:
- First encounter of each enemy type: no patrol, wide open, easy to understand.
- Subsequent encounters: patrol paths, tighter spaces, mixed types.
- Ambush encounters: enemies start hidden (behind geometry or in a trigger volume that spawns them).

## Boss arenas

Each act boss has a dedicated sub-scene (e.g. `levels/tamori/boss_arena.tscn`) with:
- Arena boundary (invisible wall while fight is active)
- Phase triggers (HP thresholds that change the Beehave tree root)
- Cinematic camera point used for the death cutscene
- Loot drop node (equipment resource + narrative pickup)

Boss arenas are accessed through a one-way portal; players cannot re-enter after clearing.

## Save points

Auto-save on:
- Level entry
- Boss death
- Narrative milestone (flag set)

No manual saves. The single slot tracks: current level, portal state flags, party HP/resources, conviction score.

## Future: random dungeons

Optional side portals will generate procedural dungeons using a modular tile system. These are scoped out and will not block Act 1 development. When implemented they sit in their own `levels/dungeons/` directory and use a separate `DungeonGenerator` autoload. All hand-crafted act content is isolated from this system.
