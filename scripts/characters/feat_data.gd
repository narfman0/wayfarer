class_name FeatData
extends Resource

@export var feat_name: String = ""
@export var str_mod: int = 0
@export var dex_mod: int = 0
@export var con_mod: int = 0
@export var int_mod: int = 0
@export var wis_mod: int = 0
@export var cha_mod: int = 0
@export var speed_mod: int = 0
@export var initiative_mod: int = 0

static func make_gwm() -> FeatData:
	var f := FeatData.new(); f.feat_name = "Great Weapon Master"; return f

static func make_alert() -> FeatData:
	var f := FeatData.new(); f.feat_name = "Alert"; f.initiative_mod = 5; return f

static func make_sentinel() -> FeatData:
	var f := FeatData.new(); f.feat_name = "Sentinel"; return f

static func make_mobile() -> FeatData:
	var f := FeatData.new(); f.feat_name = "Mobile"; f.speed_mod = 10; return f

static func make_war_caster() -> FeatData:
	var f := FeatData.new(); f.feat_name = "War Caster"; return f

static func make_lucky() -> FeatData:
	var f := FeatData.new(); f.feat_name = "Lucky"; return f
