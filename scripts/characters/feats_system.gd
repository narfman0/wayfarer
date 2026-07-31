class_name FeatsSystem
extends RefCounted

static func apply_stat_mods(stats: CharacterStats, feat: FeatData) -> void:
	if feat == null:
		return
	stats.speed += feat.speed_mod

static func has_feat(feats: Array, feat_name: String) -> bool:
	for f in feats:
		if f is FeatData and f.feat_name == feat_name:
			return true
	return false

class LuckyTracker:
	var points: int = 3
	func use() -> bool:
		if points > 0:
			points -= 1
			return true
		return false
	func restore() -> void:
		points = 3
