## Scenario: Open Road Ambush
## 2v5 — Sarro+Liris vs a mixed bandit gang. High enemy count, weaker individuals.
## Expected: challenging — party wins ~50% range. Tests AoE and positioning limits.
class_name ScenarioOpenAmbush
extends RefCounted

const NAME        := "Open Ambush"
const DESCRIPTION := "2v5: Sarro + Liris vs bandit gang — numbers vs quality"
const TERRAIN     := "outdoor_open"

static func make_party() -> Array:
	return [
		WayfarerCharacter.make_sarro().make_combatant(),
		WayfarerCharacter.make_liris().make_combatant(),
	]

static func make_enemies() -> Array:
	return [
		FixtureBandit.make(1),
		FixtureBandit.make(1),
		FixtureBandit.make(1),
		FixtureRonin.make(1),
		FixtureBandit.make(1),
	]
