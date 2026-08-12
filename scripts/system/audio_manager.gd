## Autoload — minimum viable audio: pooled one-shot SFX and a crossfading
## per-plane ambient loop. Everything is flat (non-positional) placeholder
## audio synthesized into assets/audio/; the point is that the game is no
## longer silent, and every plane already *sounds* different when real assets
## eventually replace the WAVs (same names, no code change).
extends Node

const _DIR := "res://assets/audio/"

## plane_id → ambient loop. Planes sharing a mood share a file.
const _AMBIENTS := {
	"tamori": "ambient_meadow",
	"tamori_road": "ambient_meadow",
	"tamori_fields": "ambient_fields",
	"tamori_anchor": "ambient_fields",
	"reach": "ambient_reach",
	"reach_rig": "ambient_reach",
	"kaveth": "ambient_kaveth",
	"kaveth_vault": "ambient_kaveth",
	"verath": "ambient_verath",
	"verath_seawall": "ambient_verath",
	"between": "ambient_between",
	"ashan": "ambient_ashan",
	"convergence_approach": "ambient_convergence",
	"convergence": "ambient_convergence",
}

const _SFX_POOL_SIZE := 6
const _AMBIENT_DB := -14.0
const _SFX_DB := -8.0
const _CROSSFADE_SECS := 1.2

var _pool: Array[AudioStreamPlayer] = []
var _pool_idx := 0
var _ambient_current: AudioStreamPlayer
var _ambient_old: AudioStreamPlayer
var _ambient_name := ""
var _fade_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # sfx during pause menus too
	set_master_volume(master_volume())  # restore persisted volume
	for i in _SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.volume_db = _SFX_DB
		add_child(p)
		_pool.append(p)
	_ambient_current = AudioStreamPlayer.new()
	_ambient_old = AudioStreamPlayer.new()
	for p in [_ambient_current, _ambient_old]:
		p.volume_db = _AMBIENT_DB
		add_child(p)

## Master volume, persisted alongside the graphics settings. Stored linear
## 0..1; applied to the Master bus (0 = silent via the bottom of the dB ramp).
func master_volume() -> float:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		return clampf(cf.get_value("audio", "master", 1.0), 0.0, 1.0)
	return 1.0

func set_master_volume(v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(0, v <= 0.0)
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	cf.set_value("audio", "master", v)
	cf.save("user://settings.cfg")

## Fire a one-shot by base name ("hit" → sfx_hit.wav). Small random pitch
## spread keeps rapid repeats from machine-gunning.
func play_sfx(name: String, volume_db := 0.0, pitch_jitter := 0.07) -> void:
	var stream := _load("sfx_" + name)
	if stream == null:
		return
	var p := _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % _SFX_POOL_SIZE
	p.stream = stream
	p.volume_db = _SFX_DB + volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()

## Start (or crossfade to) the plane's ambient loop. Safe to call every level
## load — same ambient keeps playing untouched across sibling planes.
func play_ambient(plane_id: String) -> void:
	var name: String = _AMBIENTS.get(plane_id, "ambient_meadow")
	if name == _ambient_name and _ambient_current.playing:
		return
	_ambient_name = name
	var stream := _load(name)
	if stream == null:
		return
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = wav.data.size() / 2  # 16-bit mono: 2 bytes per frame
	# swap players: old fades out, new fades in
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	var t := _ambient_current
	_ambient_current = _ambient_old
	_ambient_old = t
	_ambient_current.stream = stream
	_ambient_current.volume_db = -60.0
	_ambient_current.play()
	var fading := _ambient_old
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(_ambient_current, "volume_db", _AMBIENT_DB, _CROSSFADE_SECS)
	_fade_tween.tween_property(_ambient_old, "volume_db", -60.0, _CROSSFADE_SECS)
	# guard against a swap happening mid-fade: only stop the player if it is
	# still the outgoing one when the fade completes
	_fade_tween.chain().tween_callback(func() -> void:
		if fading != _ambient_current:
			fading.stop())

func _load(base: String) -> AudioStream:
	var path := _DIR + base + ".wav"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream
