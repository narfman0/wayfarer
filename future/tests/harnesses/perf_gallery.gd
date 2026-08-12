## Performance gallery: loads every plane, lets it reach steady state, then
## measures render cost — GPU/CPU render time via the RenderingServer viewport
## measurement API (immune to the Xvfb present bottleneck, which caps wall-clock
## FPS at ~16 on this box regardless of GPU), plus draw calls, primitives, and
## VRAM. Writes res://.screenshots/perf.csv and prints a markdown table.
## Needs a display and the Forward+ renderer:
##   xvfb-run -a godot --rendering-driver vulkan \
##       res://future/tests/harnesses/perf_gallery.tscn
## Software-Vulkan floor proxy (weak-GPU estimate on the same box):
##   VK_DRIVER_FILES=/usr/share/vulkan/icd.d/lvp_icd.x86_64.json xvfb-run -a ...
extends Node

const WARMUP_FRAMES := 40
const SAMPLE_FRAMES := 90
const CSV_PATH := "res://.screenshots/perf.csv"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://.screenshots")
	_run()

func _run() -> void:
	var vp_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	var adapter := RenderingServer.get_video_adapter_name()
	print("perf gallery on: ", adapter)

	var rows: Array[Dictionary] = []
	for plane_id: String in SceneManager.LEVELS:
		GameState.sarro = null
		GameState.liris = null
		var level: Node3D = (load(SceneManager.LEVELS[plane_id]) as PackedScene).instantiate()
		add_child(level)
		for i in WARMUP_FRAMES:
			await get_tree().process_frame
		var gpu := 0.0
		var cpu := 0.0
		for i in SAMPLE_FRAMES:
			await get_tree().process_frame
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp_rid)
		var row := {
			"plane": plane_id,
			"gpu_ms": gpu / SAMPLE_FRAMES,
			"cpu_ms": cpu / SAMPLE_FRAMES,
			"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			"vram_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		}
		rows.append(row)
		print("  %-22s gpu %6.2f ms   cpu %5.2f ms   %5d draws   %7d prims   %6.1f MB" % [
			plane_id, row["gpu_ms"], row["cpu_ms"], row["draw_calls"],
			row["primitives"], row["vram_mb"]])
		level.queue_free()
		await get_tree().process_frame

	_write_csv(rows, adapter)
	_print_markdown(rows)
	print("PERF GALLERY DONE")
	get_tree().quit(0)

func _write_csv(rows: Array[Dictionary], adapter: String) -> void:
	var f := FileAccess.open(CSV_PATH, FileAccess.WRITE)
	f.store_line("# adapter: %s  |  %s" % [adapter, Time.get_datetime_string_from_system()])
	f.store_line("plane,gpu_ms,cpu_ms,draw_calls,primitives,vram_mb")
	for r in rows:
		f.store_line("%s,%.3f,%.3f,%d,%d,%.1f" % [
			r["plane"], r["gpu_ms"], r["cpu_ms"], r["draw_calls"],
			r["primitives"], r["vram_mb"]])
	f.close()
	print("wrote ", CSV_PATH)

func _print_markdown(rows: Array[Dictionary]) -> void:
	print("\n| plane | GPU ms | CPU ms | draws | prims | VRAM MB |")
	print("|---|---|---|---|---|---|")
	for r in rows:
		print("| %s | %.2f | %.2f | %d | %d | %.1f |" % [
			r["plane"], r["gpu_ms"], r["cpu_ms"], r["draw_calls"],
			r["primitives"], r["vram_mb"]])
