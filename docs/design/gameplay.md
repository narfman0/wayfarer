# Wayfarer — Gameplay Design

## Core feel

Diablo II combat feel with WoW-style hotbar abilities, D&D SRD rules underneath, optional pause.

The player never manages menus mid-combat. Movement, attacking, and ability use all happen through the same overhead-camera action rhythm. The SRD is the hidden physics engine — AC, saving throws, spell slots — but players experience it as snappy action, not a spreadsheet.

## Camera

Third-person isometric overhead, fixed angle (~45° pitch). Camera follows the active party leader (Sarro by default). No free rotation — a fixed angle keeps level design legible and art controllable. The camera pans smoothly; no snapping.

Zoom: mouse wheel adjusts FOV between a comfortable default and a slightly wider tactical view. No first-person.

## Movement & targeting

- **Click-to-move** (or WASD — both supported). Character pathfinds to destination.
- **Left-click enemy** → move into melee range and auto-attack.
- **Right-click / ability key** → use active ability on target or target point.
- Sarro and Liris move together; Liris follows Sarro at a short offset and acts semi-autonomously in combat.

## Combat loop

Real-time. Optional pause at any time (Space or Start). When paused, the player can queue actions for both companions before unpausing.

Enemy turns are not discrete — all combatants act on initiative ticks in real time, same as Diablo II. D&D initiative order is hidden but drives AI tick rate and reaction timing under the hood.

### Attack flow (melee)

1. Player clicks enemy.
2. Sarro moves into melee range (SRD reach: 5 ft = ~1.5 m).
3. Attack roll: d20 + STR modifier + proficiency vs target AC.
4. Hit → damage roll; CRIT (nat 20) → double dice.
5. Enemy retaliates on its initiative tick; its attack roll follows same rules.

### Abilities (hotbar)

Four ability slots per character (1–4 / D-pad). Each maps to a class feature or spell:

- Sarro (Soldier): Action Surge, Second Wind, Fighting Style passive, one feat slot.
- Liris (Warden): Healing Word, Guiding Bolt, Channel Divinity, one spell slot.

Cooldowns are SRD resource costs (spell slots, short/long rest recharge) mapped to visual cooldown timers. No mana bar — slots are the resource.

### Pause-and-queue

When paused:
- Action queue appears above each character.
- Player clicks ability → target to queue it.
- Unpause → both characters execute queued actions simultaneously.
- Queued actions flash on the HUD so player can see what's coming.

## Enemy behavior

### Placement

All enemies in the shipped game are hand-placed. Each encounter is designed — enemy type, count, position, patrol path, and aggro trigger are authored in the level scene. No spawn randomization in Act 1.

### Aggro

Enemies have an aggro radius (cylinder trigger). When Sarro or Liris enters the radius, the enemy transitions from Patrol → Chase → Attack. Line-of-sight check is optional per enemy — some are alert (require LOS), others are sound-reactive (no LOS required).

Patrol paths are a simple array of waypoints on the enemy's Node3D; the AI walks between them until aggro triggers.

### AI states (Beehave behavior tree)

```
Root (Selector)
  ├─ IsAggroed? (Sequence)
  │    ├─ HasTarget?
  │    └─ AttackOrApproach
  ├─ IsAlerted? (Sequence)
  │    └─ SearchLastKnownPosition
  └─ Patrol (walk waypoints)
```

Enemy ability use follows simple priority: heal self if HP < 25%, use signature ability on cooldown, else basic attack.

## Character progression

AMENDED 2026-08-01 (experiment — see progression.md): classic XP leveling
1–20. Kills and quest beats grant party XP (`GameState.grant_xp`); SRD
thresholds; level 20 lands at the Convergence. No hard level gates —
under-leveled play is allowed and survivable. The original no-levels
design below is retained for reference; feats/equipment remain layers on
top of levels rather than replacements.

Original design (superseded):

1. **Story milestones** — each act end grants a feat or ability upgrade.
2. **Equipment** — weapons and armor found in the world swap stats.
3. **Conviction** (Liris only) — narrative resource that gates portal transit and some abilities.

This keeps the game focused on encounter design rather than grinding.

## Replayability

- Different feat choices at character creation change combat feel substantially (Sentinel, Great Weapon Master, Lucky, etc.).
- Liris's conviction arc has two branches that affect dialogue and late-game portal access.
- New Game+ (future): enemies scale, loot pool expands.
- Random dungeons (future): optional side areas off-portal with procedural layouts.

## Boss fights

Bosses are a different contract than regular enemies. See `docs/design/bosses.md` for full design.

Short version:
- **Telegraphed AoE**: ground indicators (circle/cone/line/donut) appear 1–2s before attack fires. Player must move out.
- **Phases**: HP thresholds (e.g. 60%, 30%) trigger transitions — brief invuln window, new or modified ability set, environment reacts.
- **Unique mechanic per boss**: interrupt a channel, soak zones, clear adds, conviction check (Liris). One or two per fight, not all of them.
- **No enrage timer**. If it's too easy, tune HP/damage directly.
- Boss arenas are separate sub-scenes loaded at act end. One-way entry; `cleared` flag stored in `GameState`.

## Difficulty

One named difficulty. Enemy stats tuned for the feat/equipment loadout of a fresh character. No easy/hard toggle — balance the one experience well.

Optional pause is the accessibility lever. Players who want Diablo feel play unpaused; players who want more control pause freely. No mechanical difference in outcomes.
