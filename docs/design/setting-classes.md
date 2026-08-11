# Wayfarer — The Setting in D&D Terms, Classes & Subclasses

What makes this setting mechanically *itself*, not a reskin. Companion to
setting.md (world bible), storyline.md (beats), progression.md (XP curve).

---

## 1. The cosmology, translated to D&D terms

Standard D&D has the Weave, alignment planes, old gods, resurrection, and
magic as a profession. Wayfarer replaces all five:

**One magical object: the Veil.** There is no Weave, no schools, no
arcane/divine split. Every supernatural act in the setting is an
*interaction with the Veil* — the living membrane between planes. The
question that defines every tradition (and therefore every class) is not
"where does your power come from?" but **"how do you touch the Veil —
and what does that cost it?"** Borrow, force, cut, or refuse: those four
answers are the four classes.

**Conviction replaces alignment.** The Veil responds to emotional clarity.
Conviction is not goodness — Cael has enormous conviction and is wrong.
It is *coherence of belief*, and it is the resource that gates transit,
fuels one class outright, and decides the game's ending. Mechanically it
lives on GameState (storyline.md, Conviction Economy).

**Young, nervous gods.** The New Pantheon crystallized out of mass belief
during the last Veil collapse, centuries ago — quasi-Roman, recent,
bureaucratic, mortal descendants everywhere. There are no ancient
mysteries; the gods remember being born and fear being unmade by another
collapse. "Divine magic" therefore isn't granted — the gods don't power
wardens or psions. What the Pantheon offers is *lineage* (nephilim, like
Sarro) and occasional cryptic communion. Gods in this setting are
stakeholders, not patrons.

**Planes of the mundane.** No Nine Hells, no elemental chaos. Every plane
is an ordinary world — rice farms, cattle land, a trading port — made
strange only by what bleeds through. Wonder comes from juxtaposition
(the wrong creature in the right field), not from visiting Fire World.
The only non-place is the Between: the Veil interior, where transit
happens and lingering kills.

**No resurrection, no way home.** You cannot re-cross your origin
threshold, and the dead do not come back. Death saves are reflavored as
*the Veil tugging* — a dying person is being pulled through, and
stabilizing them is holding them here. This makes the setting's stakes
D&D-legible but permanent in texture: what is lost stays lost; the game
is about moving forward anyway.

**Slots are Veil-charge.** EnergySlots (the engine term is already right)
are how much of the Veil's current a person can safely hold. Long rests
recover them only at *stable* tears and old shrine-sites — which welds
the resource loop to the portal/pacing structure the game already has.

---

## 2. The classes

Four classes, one per answer to the Veil question. Chassis map onto the
SRD engine (hit die, saves, slot progression) already in the addon.
Subclasses unlock at level 3 (beat ~1.5 on the progression curve).

AMENDED 2026-08-11: **all four classes are playable in the creation
wizard** (species, background, and starting spells for casters are picked
there too). Casting shipped — skill-bar keys 7–0 cast prepared spells
through EnergySlots. The six Soldier/Ghost subclasses below are built
(chosen at level 3 at a rest point, two passives each, per
`CharacterProgression`); Warden/Psion subclasses and the overstitch/scar
system remain designs.

### SOLDIER — the ones who refuse the Veil
*Chassis: fighter. d10, STR/CON saves, all armor, no slots.*

**Setting logic.** In a world where touching the Veil is morally loaded,
the person who solves problems with a sword and nothing else is not the
boring default — they're an *ethical position*. Soldiers are the
embodiment of the game's thesis: leave it alone. Every faction hires
them; none of them owns them. Displacement is the setting's constant
(swallowed villages, dead trade routes), and displaced people with
discipline become soldiers.

**Subclasses:**
- **Freeblade** — caravan guards, tavern fighters, drifters. Sarro's
  style: effortless, improvisational, wins without caring. Tempo kit:
  Action Surge analog, riposte, fighting dirty. The Extractors hire
  Freeblades; so does everyone else.
- **Gatewatch** — the Wardens' martial arm, sworn to guard stable tears.
  Protection kit: Sentinel-style lockdown, bodyguard interposition,
  vigilance (can't be surprised). In decline along with the order;
  a Gatewatch soldier is half guard, half mourner.
- **Anchor** — a Kaveth-descended discipline: stillness so complete the
  Veil calms around it. Immovability kit: cannot be moved/knocked down,
  aura that steadies allies (save bonuses), and at high level a
  suppression zone where bleedthrough effects and Veil abilities weaken
  — the martial answer to magic, earned by discipline, not equipment.

### GHOST — the ones the planes forgot
*Chassis: rogue. d8, DEX/INT saves, light armor, widest skills (4).*

**Setting logic.** When a tear swallows a village, the survivors are
people without a home plane, records, or names that mean anything where
they landed. Some of them learn to live unnoticed — to move like they're
already gone. "Ghost" is what settled folk call them. It's a class made
of the setting's collateral damage, which is why it gets the widest
skill list: ghosts survive by competence.

**Subclasses:**
- **Threshold Thief** — learned (or stole) the Extractor trick of
  palming *micro-tears*. Sneak-attack chassis plus, later: a short blink
  step through the Veil-skin (misty step at will is the level-13+
  fantasy), pocketing objects "elsewhere." Every use is a pinprick wound
  — narratively noted, mechanically cheap. The morally itchy subclass.
- **Faceless** — Verath's specialty: identity work. Displaced people get
  new names; the Faceless collect them. Social infiltration kit:
  disguise, mimicry, contacts in every port, expertise stacking on
  Deception/Persuasion. The campaign's political beats (2.9) are theirs.
- **Between-Scout** — survived a transit that went long. Something in
  them still hears the Veil: danger sense, seeing tears before they
  open, evasion/uncanny dodge early, and late — one free party-wide
  re-entry save when a crossing goes wrong. The Between (2.12) is their
  homecoming.

### WARDEN — the ones who borrow
*Chassis: full caster, WIS. d8, WIS/CHA saves, medium armor.*

**Setting logic.** The old order. Wardens learned, over centuries, to
*channel the Veil's own current* — never forcing, always returning what
flows through. Their magic is the proof hiding in plain sight that the
game's thesis is true: the Veil sustains those who work with it. They
kept the sacred tears; the world stopped listening; the Menders are
their heresy and their shame. Idris is the order's living remnant.

Casting identity: slots = current held; spells are all *redirections* —
mending flesh (the body is a plane; healing is guiding it back to its
shape), light, warding, calming what bled through. Almost nothing purely
destructive; their "attack" magic is radiant redirection (Guiding Bolt).

**Subclasses:**
- **Order of the Current** — healers and travelers; Liris's destination
  (see §3). Healing Word, Guiding Bolt, bless/sanctuary analogs, and the
  capstone fantasy: carrying companions through transit on borrowed
  conviction.
- **Order of the Anchor** — the stabilizers, keepers of Kaveth's
  inheritance. Wards, zones, abjuration analog: shields, glyphs,
  dispelling bleedthrough. Slower, tankier caster; scales with the
  ritual/set-piece beats (1.5, 2.8).
- **The Mender** — *the heresy, playable.* Stitching: casting that
  forces instead of borrows. Mechanically: every Mender spell can be
  **overstitched** — cast at +1 slot level of effect for free — but each
  overstitch leaves a *scar token* on the encounter/zone (enemies there
  gain resistance ticks; the zone twists). Short-term power, visible
  accumulating cost: the entire antagonist argument as a build choice.
  A Mender player character walks Cael's road and feels why. (Late-game
  narrative hooks react: Idris, the Defector, and Cael all notice.)

### PSION — the ones who impose
*Chassis: full caster, INT. d6, INT/WIS saves, no armor.*

**Setting logic.** If conviction lets a farmer cross a tear, what could
*trained, weaponized certainty* do? Psions are the scholars — mostly
Kaveth's intellectual descendants — who formalized conviction into a
discipline. They don't borrow the current and don't cut it; they impose
shape on it by believing precisely. This makes them the setting's
wizard: bookish, rigorous, slightly feared — and the class closest to
the Menders' mistake without being it. A psion's power is the same
faculty Liris grows for free; they got theirs by decades of study, and
some of them resent that.

**Subclasses:**
- **Resonant** — conviction turned outward: emotion-shaping. Buffs,
  fear, charms, the calm-the-bled-through toolkit; the social caster.
  In faction beats they read crowds like weather.
- **Cartographer** — space and connection: the map-makers of the
  Between. Short translocations, sending, portal-stabilizing, and the
  navigation utility the party needs in Act 2. The "wizard's wizard."
- **Sever** — the forbidden third answer: cutting connections. Single
  target unmaking, counterspell analog, isolating enemies from allies
  (banishment-feel). Severing is what Extractor technology industrializes
  — the discipline predates the machines and disowns them, loudly, in a
  way that convinces no one. Regulated, feared, dramatically loaded.

---

## 3. Sarro and Liris in class terms

**Sarro = Freeblade Soldier + Nephilim lineage.** Lineage is a layer,
not a class (the D&D-sense "race/background" slot): free Veil transit,
ancestor communion (rare, costly, story-triggered), and a divine spark
that surfaces in fixed story beats rather than a spell list. His class
says *drifter who refuses the Veil*; his blood says *the Veil refuses to
refuse him*. That tension IS his arc (2.11).

**Liris = the conviction arc made playable.** She starts classless — a
farmer with a mace. Her Warden (Current) levels unlock as conviction
milestones pass, not as XP accrues: the storyline's conviction economy
IS her class progression. By Ashan she is a full Warden; the capstone —
carrying someone through the Veil — is narratively spent in the finale.
Mechanically simple (her class features gate on story flags), thematically
load-bearing: the system the player reads as "leveling Liris" is the
story's central argument accumulating.

---

## 4. How the game stays ours (mechanical identity checklist)

- **Rest at tears.** Long rest = camp at a stable tear/shrine. Resource
  pacing rides the world structure, not an inn menu.
- **Overstitch is universal temptation.** Menders get it free; ANY caster
  can force-cast in an emergency at scar cost. The thesis is a button
  every caster can press and regret.
- **Scars are world-state.** Zones remember forced magic (flags on the
  level); NPCs comment; epilogue text reads them back.
- **Death is a tug, not an end-state reversal.** Death saves reflavored;
  no resurrection magic exists for anyone, ever. Defeat = washed back
  to the last stable tear (fiction for reload).
- **Loot is displacement.** Magic items are artifacts from *somewhere
  else* — each names its home plane; the Fence buys and sells them.
  Equipment carries setting like text carries plot.
- **Combat is optional more often than usual.** Displaced creatures are
  confused, not evil (beat 1.3 is the template); talking a junior Mender
  aside (3.6) is a class-skill moment, not a cutscene.
- **No summoning, no planar binding, no teleport networks.** All the
  D&D staples that treat planes as utilities are absent by design — the
  Veil is a character, not a subway.

## Implementation notes (current engine, 2026-08-11)

- All four chassis ship in ClassData and the creation wizard. The six
  Soldier/Ghost subclasses are live in `CharacterProgression.SUBCLASSES`
  (passives wired into melee_attacker / enemy_controller / level_base);
  Warden/Psion subclasses are not yet built.
- Casting is live: `ability_registry` builds spell entries from prepared
  spells, `level_base.cast_spell(spell, caster)` resolves them, and
  EnergySlots gate non-cantrips. Long rest at a stable tear recovers all.
- Overstitch/scar remains unbuilt. Its ingredients now all exist —
  GameState.flags per-zone, EnemyController buff hooks, a real cast
  path — so it's purely a content/UI task when we want it.
