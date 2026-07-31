## Scenario: Gilded Oni Tavern Brawl
## 2v3 — Sarro+Liris vs three ronin in a cramped interior.
## Expected: party should win ~65%+ at average play.
class_name ScenarioTavernBrawl
extends RefCounted

const NAME        := "Tavern Brawl"
const DESCRIPTION := "2v3: Sarro + Liris vs three ronin, cramped interior (no cover)"
const TERRAIN     := "indoor_cramped"

static func make_party() -> Array:
	return [
		WayfarerCharacter.make_sarro().make_combatant(),
		WayfarerCharacter.make_liris().make_combatant(),
	]

static func make_enemies() -> Array:
	return [
		FixtureRonin.make(1),
		FixtureRonin.make(1),
		FixtureRonin.make(1),
	]
