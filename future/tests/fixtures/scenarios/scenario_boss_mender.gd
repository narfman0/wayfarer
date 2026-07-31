## Scenario: Mender Archon Boss Fight
## 2v1 boss — Sarro+Liris vs a high-level Mender Archon + two acolytes.
## Tests whether a CR-appropriate boss presents a real threat.
class_name ScenarioBossMender
extends RefCounted

const NAME        := "Mender Archon"
const DESCRIPTION := "2v3: Sarro + Liris vs Mender Archon (lvl 4) + two acolytes"
const TERRAIN     := "outdoor_ritual_site"

static func make_party() -> Array:
	return [
		WayfarerCharacter.make_sarro().make_combatant(),
		WayfarerCharacter.make_liris().make_combatant(),
	]

static func make_enemies() -> Array:
	return [
		FixtureMender.make_boss(4),
		FixtureMender.make(1),
		FixtureMender.make(1),
	]
