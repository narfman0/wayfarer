# Wayfarer — Start-to-Finish Storyline (Beat Sheet)

The playable spine of the game, start to finish: every beat in order, tied
to levels, story flags, and choices. Scene-level detail lives in act-1.md /
act-2.md / act-3.md; this document is the map. Flags use the shipped
`GameState.set_flag/has_flag` system; conviction is `GameState` data
(see Conviction Economy below).

Structure: 3 acts, 7 planes + the Between, ~15 hours.
Emotional spine: **grief makes people dangerous; the Veil needs to be left
alone; you can't go back — forward is enough.**

---

## Prologue — The Debt (reconciled opening)

Resolves the act-1.md (farm opening) vs tamori_tavern.dialogue (tavern
opening) conflict — both, in causal order:

**P1. Cold open (non-interactive).** A wheat field at dusk. A shimmer that
doesn't move right. A woman with a basket steps too close. Gone. Title:
WAYFARER. *(MVP: text-over-black cards.)*

**P2. The tavern (playable, ~5 min).** The Gilded Oni, Tamori's Gate
District — the existing `tamori_tavern.dialogue` beat. Sarro defuses or
brawls (first combat tutorial). He leaves at a jog, trailed by two men.
→ `opening_tavern_done`

**P3. Liris's morning (playable-lite).** Her farm: feed the chickens, the
neighbor across the fence. Slow on purpose. Sarro clips the lantern post
mid-flight; the barn burns; a Veil-tear cracks open beside it; her mother
steps out to look — gone. The only time Sarro physically stops Liris:
the tear is lethal without conviction. The debt is set.
→ `opening_done` (already shipped as flag)

**P4. Character creation** sits before P2 (Sarro is the created
character; class Soldier/Ghost for now).

---

## Act 1 — Debt (Tamori, ~4h)

Level map (reconciles levels.md's four-level act with the narrative):
`tamori.tscn` = **Village** (hub, shipped) → **East Road** (travel +
first patrol encounters; levels.md's "Sword Road") → **Eastern Fields**
(`tamori_fields.tscn`, shipped as sketch) → **The Anchor Tear** (act
finale site; levels.md's "Veil Anchor").

**1.1 The village is wrong.** Hub NPCs establish: eastern tear opened
three weeks ago, crops black, village blames itself. Odo the well keeper
(shipped) points east. Delegation asks for help — Liris because she's
known, Sarro because strangers with swords sometimes help.
→ `heard_about_fields` (shipped; gates East portal)

**1.2 East Road.** First real encounters — bandits picking at abandoned
farms (patrol/ambush teaching per levels.md). Optional side beats: the
family arguing about leaving; the child who saw something come through.

**1.3 Eastern Fields.** The tear. What came through is a *condition*,
not a creature — confused, not hostile. CHOICE: fight it, or figure out
what it is and help it home (more lore, conviction +).
→ `fields_resolved`

**1.4 Meeting Idris.** Veil Warden camped at the field's edge, watching
a tear behave wrongly for the first time in fifty years. Direct, not
warm. Trade: she shares her records if they help with the Anchor Tear.
→ `met_idris`

**1.5 The Anchor Tear (act climax).** CHOICE — the Warden's Ritual:
- Let Idris perform the old ritual: works imperfectly, costs her a
  memory she names out loud. `ritual_idris`
- Find another way: longer (village info-gathering), teaches Veil
  mechanics. `ritual_alternative`, conviction +
- Do nothing / push through: dangerous, Idris relationship lost.
  `ritual_refused`

**1.6 The trail out.** Idris, on the way out: a scholar was here six
weeks ago doing "Veil research." Tears came two weeks later. The
abandoned Mender campsite: meticulous, sad notes; a map with the next
location. Liris finishes the harvest she started. She doesn't look back.
→ `act1_done`; portal through the Between (brief, beautiful) to Act 2.

---

## Act 2 — The Chase (The Reach → Old Kaveth → Verath → The Between, ~7h)

Always arriving after. Each plane: a complete small story + the wound the
factions left.

### The Reach (2a)
**2.1 Arriving wrong** — out of a tear into a cattle pen; first
accidental competence together.
**2.2 The Extractor operation** — tears held open by energy harvesting,
with permits. The Fence: personable, unashamed.
**2.3 CHOICE — the Extractor Deal:**
- Take it: Cael's next location now; extraction continues; the damage is
  visible on any return visit. `deal_taken`
- Refuse: slower route; the Fence decides you're interesting and helps
  differently later. `deal_refused`
- Negotiate (requires Veil knowledge from 1.5 alternative or 1.3 help):
  partial shutdown. `deal_negotiated`, conviction +
**2.4 The long walk** — the slow scene. Liris talks about her mother;
the abandoned Mender camp at dusk. "They think they're fixing it. …
So did I."
→ `reach_done`

### Old Kaveth (2b)
**2.5 Ruins at dusk** — a city built *around* the Veil. The nephilim
carving Sarro won't talk about.
**2.6 The Defector** — a Mender who left after Kaveth's anchor stone was
taken (working name **Serane** — see Continuity: the shipped villager
"Mira" frees the overview's defector name for reuse, or rename one).
Their records: forty-one closed tears, none healed — stitched.
**2.7 CHOICE — Trust:** bring the Defector (asset + Extractor heat,
`defector_joined`) or take the documents and go (`defector_left` — they
help anyway, alone).
**2.8 The waking tear** — sustained set-piece in shifting ruins. Reveal:
the anchor stone marked the tear; it was healing *on its own* for
centuries. The Menders repair what is already healing.
→ `kaveth_done`, conviction +

### Verath (2c)
**2.9 A city with sides** — two factions blame each other for dead
trade; one secretly hosts Menders. CHOICE: which to work through
(`verath_side_idealists` / `verath_side_merchants`) — neither wrong
about everything.
**2.10 Glimpsing Cael** — at the docks, watching a tear over water. He
sees them. Doesn't run. Leaves. He has a face now: tired.
→ `saw_cael`
**2.11 CHOICE — Sarro's portal.** A small unstable gate, *right
direction*, ten minutes:
- He goes (`sarro_portal_taken`): finds evidence his sister passed
  through and moved on — a direction, not an answer. Comes back changed.
- He stays (`sarro_portal_stayed`): watches it close; something between
  them shifts.
Either is complete; the game never says which was right.

### The Between (act threshold)
**2.12 The crossing goes wrong.** Inside the Veil: Mender repairs
visible as rigid scar tissue; untouched regions quietly healing. Thesis
becomes evidence. A fragment of Sarro's divine ancestor gives him
something (not the answer he wants — see Open Questions).
→ `act2_done`, conviction + (the big one: Liris has *seen* it)

---

## Act 3 — Forward (Ashan → The Convergence, ~4h)

### Ashan (3a) — no wound here; this is the point
**3.1 The search** — short, ordinary: neighbors, a trade, a street.
**3.2 The reunion** — Liris's mother, alive; halting, specific, heard in
full. Sarro is a guest and knows it.
**3.3 The path home isn't there.** Origin thresholds don't reopen. Her
mother can't go back. Neither can she. Sat with, not dramatized.
**3.4 The hand.** Evening. Liris takes Sarro's hand. No dialogue.
→ `ashan_done`, conviction ++ (her certainty completes here)

### The Convergence (3b)
**3.5 Ahead of it, for once.** Cael's largest stitching, hours from
completion; cascade across dozens of planes if it finishes.
**3.6 Through the Menders** — not a battle; junior Menders talked aside,
the Defector's presence disorienting to old colleagues. One optional,
regrettable fight with a Mender who won't move. The Fence watches from
a distance, calculating.
**3.7 The conversation.** Not a dialogue tree with a win button. Cael's
data vs what they've seen (Kaveth, the Between, Ashan). The Defector's
"I stayed longer than you did to find out." The turn: Liris's mother —
went through six years ago, alive, carried through by an untouched
Veil. Cael: "That's about when I started."
- If **conviction ≥ threshold**: the final phase never becomes a fight.
  He sits down. `cael_convinced`
- Else: a harder version — a short fight against his despair (bosses.md
  final encounter), same destination. `cael_fought`
**3.8 The intervention stops.** He calls it off; his team obeys on
trust. The Defector says nothing; that matters. The Fence leaves without
a word.

### The ending
**3.9 Leave him there.** Not victors — done. Tears stop multiplying;
in Tamori, the eastern water clears (epilogue flag callback to 1.3).
**3.10 The final portal (player's last choice).** A portal opens nearby,
unhurried. Sarro: *"Shall we continue?"*
- **Go together** — through, into the Veil, credits.
- **Go alone** — she stays arrived; he keeps moving; also honest.
- **Don't go** — it closes; they stay; also enough.
No variant is graded. *(overview.md's ending; act-3.md ends one beat
earlier — this beat is canonical.)*

---

## Conviction Economy (Liris)

`GameState` int, raised by understanding-over-force choices:
helping the fields condition home (1.3), the ritual alternative (1.5),
negotiating the Deal (2.3), Kaveth's revelation (2.8), the Between
(2.12), Ashan (3.4 — largest single gain).
Gates: certain Veil crossings mid-game (levels.md portal type), and the
`cael_convinced` peaceful resolution threshold. Never shown as a number
— surfaced through her dialogue confidence.

## Choice → Consequence Summary

| Choice | Beat | Flags | Ripples |
|---|---|---|---|
| Fields condition: fight/help | 1.3 | `fields_resolved` (+kind) | lore, conviction, epilogue water line |
| Warden's Ritual | 1.5 | `ritual_*` | Idris relationship; Veil knowledge for 2.3 |
| Extractor Deal | 2.3 | `deal_*` | Reach damage on return; Fence's late help; Fence at Convergence |
| Defector trust | 2.7 | `defector_*` | 3.6 ease; 3.7 witness line |
| Verath faction | 2.9 | `verath_side_*` | city outcome color, route to 2.10 |
| Sarro's portal | 2.11 | `sarro_portal_*` | his 3.10 shading; party dynamic lines |
| Cael resolution | 3.7 | `cael_*` | fight vs dialogue finale |
| Final portal | 3.10 | ending variant | credits variant |

## Continuity fixes this document resolves (or flags)

1. **Opening**: tavern-then-farm, both playable (P2→P3). tamori_tavern
   dialogue stays; farm sequence is new work.
2. **Name collision**: overview.md calls the Defector "Mira"; the shipped
   Tamori bark villager is also "Mira." Villager renamed (see commit);
   Defector keeps a working name **Serane** until decided.
3. **levels.md Act 1** ("Docks → Sword Road → Mender Outpost → Veil
   Anchor" + boss) vs narrative act-1 (no boss, ritual climax): mapped
   as Village → East Road → Eastern Fields → Anchor Tear, with the
   levels.md "boss" slot filled by the 1.5 set-piece (the tear itself /
   what guards it), not a person.
4. **Ending**: act-3.md stops at "Forward."; overview.md adds the final
   portal choice. The portal choice is canonical (3.10).

## Open Questions (carried from overview.md, still open)

- What exactly does the ancestor give Sarro in the Between (2.12)?
- Liris's mother: why she stopped trying to return (informs 3.3).
- Defector's specific participation/guilt (informs 2.6, 3.7).
- Does Cael ever find his daughter? (Deliberately unanswered.)
