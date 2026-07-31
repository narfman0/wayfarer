## Fixed companion character creation — players choose one feat for each companion.
## Sarro (Soldier) and Liris (Warden) are pre-built; only feat selection is here.
class_name CharacterCreation
extends Control

## Feats available for Sarro (combat-focused Soldier)
const SARRO_FEATS := [
	{"label": "Great Weapon Master — +10 dmg on -5 hit trade",  "feat": "gwm"},
	{"label": "Alert — +5 initiative, can't be surprised",       "feat": "alert"},
	{"label": "Sentinel — lock down adjacent foes",              "feat": "sentinel"},
	{"label": "Mobile — +10 speed, no OA after attacking",      "feat": "mobile"},
]

## Feats available for Liris (Warden support)
const LIRIS_FEATS := [
	{"label": "War Caster — concentration advantage, somatic substitute",  "feat": "war_caster"},
	{"label": "Lucky — 3 luck points per day",                             "feat": "lucky"},
	{"label": "Alert — +5 initiative, can't be surprised",                 "feat": "alert"},
	{"label": "Mobile — +10 speed, no OA after attacking",                 "feat": "mobile"},
]

@onready var _sarro_group: VBoxContainer = $Layout/Companions/SarroPanel/Feats
@onready var _liris_group: VBoxContainer = $Layout/Companions/LirisPanel/Feats
@onready var _confirm_btn: Button = $Layout/Confirm

var _sarro_selected: String = ""
var _liris_selected: String = ""

func _ready() -> void:
	_build_feat_list(_sarro_group, SARRO_FEATS, func(key): _sarro_selected = key)
	_build_feat_list(_liris_group, LIRIS_FEATS, func(key): _liris_selected = key)
	_confirm_btn.pressed.connect(_on_confirm)
	_confirm_btn.disabled = false  # MVP: feats are optional

func _build_feat_list(container: VBoxContainer, options: Array, on_select: Callable) -> void:
	var group := ButtonGroup.new()
	for opt in options:
		var btn := CheckBox.new()
		btn.button_group = group
		btn.toggle_mode = true
		btn.text = opt["label"]
		var key: String = opt["feat"]
		btn.toggled.connect(func(on: bool):
			if on:
				on_select.call(key)
				_check_confirm_enabled()
		)
		container.add_child(btn)

func _check_confirm_enabled() -> void:
	pass  # MVP: always enabled; feats are optional choices

func _on_confirm() -> void:
	var sarro := WayfarerCharacter.make_sarro()
	var liris := WayfarerCharacter.make_liris()
	var sf := _make_feat(_sarro_selected)
	var lf := _make_feat(_liris_selected)
	if sf != null: sarro.feats.append(sf)
	if lf != null: liris.feats.append(lf)
	GameState.set_party(sarro, liris)
	get_tree().change_scene_to_file("res://scenes/world/tamori.tscn")

func _make_feat(key: String) -> FeatData:
	match key:
		"gwm":        return FeatData.make_gwm()
		"alert":      return FeatData.make_alert()
		"sentinel":   return FeatData.make_sentinel()
		"mobile":     return FeatData.make_mobile()
		"war_caster": return FeatData.make_war_caster()
		"lucky":      return FeatData.make_lucky()
	return null
