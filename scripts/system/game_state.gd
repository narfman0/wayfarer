## Autoload singleton — holds all persistent game state.
## Access anywhere as GameState.party, GameState.current_plane, etc.
extends Node

signal party_updated
signal plane_changed(plane_id: String)

## The two companions and their runtime data.
var sarro: WayfarerCharacter = null
var liris: WayfarerCharacter = null

## Which plane/scene is currently active.
var current_plane: String = ""

## Whether a save exists from a previous session.
var has_active_save: bool = false

## Total play time in seconds.
var play_time_seconds: float = 0.0

func _ready() -> void:
	has_active_save = SaveManager.has_save(0)

func _process(delta: float) -> void:
	if current_plane != "":
		play_time_seconds += delta

## Initialize fresh party (call from character creation).
func new_game(sarro_feats: Array[FeatData], liris_feats: Array[FeatData]) -> void:
	sarro = WayfarerCharacter.make_sarro()
	for feat in sarro_feats:
		sarro.feats.append(feat)
	sarro.setup()

	liris = WayfarerCharacter.make_liris()
	for feat in liris_feats:
		liris.feats.append(feat)
	liris.setup()

	current_plane = "tamori"
	play_time_seconds = 0.0
	party_updated.emit()

## Load a saved game into state (call from main menu Continue).
func load_game(slot: int = 0) -> bool:
	var data := SaveManager.load_game(slot)
	if data.is_empty():
		return false
	_deserialize(data)
	has_active_save = true
	party_updated.emit()
	return true

## Persist current state to disk.
func save_game(slot: int = 0) -> void:
	SaveManager.save_game(slot, _serialize())
	has_active_save = true

## Quick helpers
func party() -> Array[WayfarerCharacter]:
	var p: Array[WayfarerCharacter] = []
	if sarro != null: p.append(sarro)
	if liris != null: p.append(liris)
	return p

func travel_to(plane_id: String) -> void:
	current_plane = plane_id
	plane_changed.emit(plane_id)

# ── Serialization ─────────────────────────────────────────────────────────────

func _serialize() -> Dictionary:
	return {
		"current_plane": current_plane,
		"play_time": play_time_seconds,
		"sarro": _serialize_char(sarro),
		"liris": _serialize_char(liris),
	}

func _serialize_char(c: WayfarerCharacter) -> Dictionary:
	if c == null:
		return {}
	return {
		"current_hp": c.stats.current_hp,
		"xp": c.stats.xp,
		"level": c.stats.level,
		"feat_names": c.feats.map(func(f): return f.feat_name),
	}

func _deserialize(data: Dictionary) -> void:
	current_plane = data.get("current_plane", "tamori")
	play_time_seconds = data.get("play_time", 0.0)
	sarro = WayfarerCharacter.make_sarro()
	liris = WayfarerCharacter.make_liris()
	_apply_char_data(sarro, data.get("sarro", {}))
	_apply_char_data(liris, data.get("liris", {}))

func _apply_char_data(c: WayfarerCharacter, data: Dictionary) -> void:
	if data.is_empty():
		return
	c.stats.current_hp = data.get("current_hp", c.stats.max_hp)
	c.stats.xp = data.get("xp", 0)
	# Feat rehydration — look up by name from built-in factories
	for fname in data.get("feat_names", []):
		var feat := _feat_by_name(fname)
		if feat != null:
			c.feats.append(feat)
	c.setup()

func _feat_by_name(name: String) -> FeatData:
	match name:
		"Alert":               return FeatData.make_alert()
		"Lucky":               return FeatData.make_lucky()
		"Mobile":              return FeatData.make_mobile()
		"Sentinel":            return FeatData.make_sentinel()
		"War Caster":          return FeatData.make_war_caster()
		"Sharpshooter":        return FeatData.make_sharpshooter()
		"Great Weapon Master": return FeatData.make_gwm()
	return null
