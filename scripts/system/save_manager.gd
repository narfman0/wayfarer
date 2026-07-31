## Static save/load helpers. All persistence lives in user://saves/.
## Slots are simple integers; slot 0 is the autosave.
class_name SaveManager
extends RefCounted

const _SAVE_DIR := "user://saves/"
const _SAVE_EXT := ".json"

static func _path(slot: int) -> String:
	return _SAVE_DIR + "slot_%d" % slot + _SAVE_EXT

static func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_path(slot))

static func save_game(slot: int, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(_SAVE_DIR)
	var f := FileAccess.open(_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: could not open %s for writing" % _path(slot))
		return
	f.store_string(JSON.stringify(data, "\t"))

static func load_game(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var f := FileAccess.open(_path(slot), FileAccess.READ)
	if f == null:
		push_error("SaveManager: could not open %s for reading" % _path(slot))
		return {}
	var result := JSON.parse_string(f.get_as_text())
	if typeof(result) != TYPE_DICTIONARY:
		push_error("SaveManager: corrupt save at slot %d" % slot)
		return {}
	return result

static func delete_save(slot: int) -> void:
	var p := _path(slot)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)

## Returns an Array of slot indices that have save files.
static func list_saves() -> Array[int]:
	var slots: Array[int] = []
	var dir := DirAccess.open(_SAVE_DIR)
	if dir == null:
		return slots
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(_SAVE_EXT):
			var num_str := fname.replace("slot_", "").replace(_SAVE_EXT, "")
			if num_str.is_valid_int():
				slots.append(num_str.to_int())
		fname = dir.get_next()
	slots.sort()
	return slots
