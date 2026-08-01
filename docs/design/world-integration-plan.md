# World, Synty, and Narrative Integration Plan

Goal: turn the single graybox arena into Act 1 of the designed game — four
Tamori levels, portal transitions, story flags driving dialogue and gates,
and Synty art replacing placeholders. Ordered so every phase ends playable,
and so art (the only user-gated dependency) never blocks systems work.

## Guiding order: systems → graybox → narrative → art

Art comes last on purpose: graybox levels validate encounter and story flow
cheaply, and the Synty pass then reskins working content. The reverse order
(art first) stalls everything behind asset import.

---

## Phase 1 — World infrastructure — DONE 2026-07-31 (SceneManager, flag-gated portals, level_base, story flags; barks + retargeted idle/run animations landed alongside)

## (original Phase 1 spec follows)

The plumbing every level needs. All testable in graybox headless.

- **SceneManager autoload** — `change_level(path, spawn_portal_id)`:
  fade out → load level → place party at the named portal spawn → fade in.
  Autosave on transition (levels.md specifies this).
- **StoryFlags in GameState** — a `flags: Dictionary` (string → bool/int)
  with `set_flag/has_flag`, persisted in the save payload (bump
  SAVE_VERSION). Dialogue mutations and triggers write these; portals and
  dialogue conditions read them.
- **Portal node** (reusable scene) — Area3D + interact prompt (F is already
  in the input map). Gate types from levels.md: `narrative` (requires
  flag), `boss` (requires boss-dead flag), `open`. Blocked portals show
  their lore reason as a dialogue line.
- **Level template scene** — the levels.md skeleton: `Level/Ground`,
  `Props`, `Enemies`, `Triggers`, `Portals` + CameraPivot/HUD wiring
  extracted from tamori.tscn into a shared base script so new levels are
  data, not copied code.
- **Save v2** — current level path, story flags, cleared-encounter ids
  (enemies stay dead within a session per levels.md; respawn on new
  session is already the default since we don't persist them).

## Phase 2 — Act 1 graybox (4 levels, authored encounters)

Build the designed act structure with capsules and colored boxes:

- **Tamori Docks** (rename/evolve current tamori.tscn) — village hub,
  NPCs, first fight, portal east.
- **Sword Road** — travel level, 2–3 authored encounters teaching patrols
  and ambushes (EnemyController already supports waypoints + aggro).
- **Mender Outpost** — mixed encounter density, mini-boss gate flag.
- **Veil Anchor** — boss arena per levels.md (boundary, phase triggers at
  HP thresholds, one-way entry). Boss = reskinned EnemyController with
  phases; Beehave trees stay future.

Encounter design rules from levels.md apply (first encounter open and
readable, later ones tighter with patrols).

## Phase 3 — Narrative integration

Wire the act-1.md script into the levels via Dialogue Manager:

- **Reconcile the two openings.** act-1.md opens on Liris's farm and the
  barn fire; the existing tamori_tavern.dialogue is the tavern brawl that
  *causes* it. Proposed: tavern brawl becomes a short pre-title playable
  beat (it already exists as dialogue), farm sequence follows as the
  emotional opening. Decision needed before scripting.
- **Dialogue ⇄ flags bridge** — Dialogue Manager mutations call
  `GameState.set_flag(...)`; conditions read flags. This is the glue that
  makes portals narrative-gated.
- **Scene-by-scene beats** as dialogue files per level: village delegation,
  eastern-fields tear, meeting Idris (her records unlock the Sword Road
  portal — first narrative gate), elder giving coordinates, etc.
- **NPC node** — talkable villager (Area3D + F) that launches a dialogue
  title and can carry a one-line ambient bark. 3–4 village side moments
  from act-1.md.
- **Liris conviction** — data only for now: an int on GameState written by
  dialogue choices, saved. Conviction-gated portals become possible later
  without UI.
- MVP for the cold open: text-over-black cards. Real cinematic later.

## Phase 4 — Synty art pass (asset server on srv)

UNBLOCKED: narfman0 runs an asset server at
`http://srv.blastedstudios.com:49200` (`~/data/other/asset-server` on srv)
— nginx serves cooked GLBs at `/assets/`, index at `/index.json`; a
Blender-based cooker container converts raw Synty FBX → GLB. Fetch into
the project with `./fetch_assets.sh` (assets/meshes/ is gitignored; the
server is the source of truth).

Packs relevant to Wayfarer (cooked as of 2026-07-31): Fantasy Kingdom v5
(1852 GLB env/props), Fantasy Characters v3 (rigged characters — verified
importing into Godot with skeleton intact), ANIMATION Base Locomotion v3,
Nature Biomes Meadow Forest v2. Also owned: Dungeons Realms, Viking Realm,
Goblin War Camp, Swamp/Jungle biomes, Prototype, and others.

**Look decision needed**: there is no Samurai/feudal-Japan pack. Either
re-flavor Tamori's visuals to fantasy-kingdom-village (keeps narrative,
changes art direction) or buy POLYGON Samurai and drop it in raw/.
- **Environment kit smoke-test scene** — one scene that instances every
  imported tile/prop for visual QA before level dressing.
- **Dress the four levels** — swap `Ground` meshes, prop the spaces,
  lighting/environment mood per act-1.md (cherry blossoms, mist, dusk
  palette). Level scripts don't change — that's what the graybox phase
  buys us.
- **Characters** — replace capsules: Synty rigged characters, shared-rig
  AnimationLibrary (idle/run/attack/death), AnimationTree driven by
  existing controller state (velocity → run blend, attack signal → swing).
  This is the biggest single art task; do Sarro first end-to-end, then
  reuse the setup for Liris/enemies.

## Phase 5 — Act close & polish

- Veil Anchor boss fight tuned (bosses.md), death cutscene camera point,
  loot drop → equipment upgrade.
- Act 2 portal stub (portal exists, leads to a "to be continued" card).
- Pause-and-queue and hotbar abilities remain a separate combat track —
  not part of this plan.

---

## Dependencies / decisions needed from narfman0

1. ~~Which Synty packs~~ — RESOLVED: asset server on srv (see Phase 4).
2. ~~Export format~~ — RESOLVED: server cooks FBX → GLB; Godot imports GLB
   natively.
3. ~~Tamori's look~~ — RESOLVED (2026-07-31): no Samurai pack; using
   Fantasy Kingdom + available packs as placeholders. Tamori is dressed
   with FK tents/props/trees. Note: Meadow Forest foliage needs its own
   leaf textures + alpha materials, so FK stylized trees are used instead
   for now.
4. **Opening reconciliation**: tavern-brawl-then-farm (proposed) or cut
   the tavern to narration?
5. OK to rename `tamori.tscn` → `levels/tamori/docks.tscn` as part of the
   template refactor?

## Asset-server maintenance notes (srv)

Found while integrating (2026-07-31): the cooker's whole-tree Blender
batch segfaulted in May (Blender 5.1.1, on Fantasy Kingdom's
`SM_Bld_Castle_Drawbridge_01_Chains_01.fbx`), which is why most packs
were never cooked; the inotify watcher also misses touches (likely watch
exhaustion — kenney_aio alone is 85k files). Worked around by exec'ing
the converter per-pack inside the container. Worth fixing in the
asset-server repo eventually: per-pack batch fallback + inotify watch
limit bump.

## Suggested sequencing

Phases 1→2 are pure code and can start immediately (1 before 2, hard
dependency). Phase 3 overlaps Phase 2 once flags exist. Phase 4 starts
whenever packs are available — it only touches scenes, not scripts.
