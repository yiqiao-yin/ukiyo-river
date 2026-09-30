## Renders main.tscn offscreen for a fixed number of frames and writes a PNG.
##
## Used to eyeball a phase without opening the editor:
##   godot --path 'C:\Dev\ukiyo-river' --resolution 1280x720 res://scenes/screenshot.tscn
## Headless runs cannot do this - they never build a rendering device, so shader compile errors
## and anything that only shows up on screen stay invisible there.
extends Node

@export_file("*.png") var out_path: String = "res://shot.png"
@export var wait_frames: int = 120

## Frames at the start to ignore while shaders compile and the terrain builds.
@export var warmup_frames: int = 40

var _frames: int = 0
var _timed_frames: int = 0
var _timed_seconds: float = 0.0
var _main: Node


func _ready() -> void:
	_main = load("res://main.tscn").instantiate()
	add_child(_main)


func _process(delta: float) -> void:
	_frames += 1
	if _frames > warmup_frames:
		_timed_frames += 1
		_timed_seconds += delta
	if _frames < wait_frames:
		return
	set_process(false)
	if _timed_frames > 0:
		var ms: float = _timed_seconds / float(_timed_frames) * 1000.0
		print("[screenshot] %.2f ms/frame (%.0f fps) over %d frames" % [
			ms, 1000.0 / ms, _timed_frames,
		])
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(out_path)
	if error != OK:
		push_error("[screenshot] could not write %s (error %d)" % [out_path, error])
	else:
		print("[screenshot] wrote ", ProjectSettings.globalize_path(out_path))
	# Drop the grabbed image and let the renderer finish a frame before tearing down, otherwise
	# the viewport texture is still live at shutdown and Godot reports leaked texture RIDs.
	image = null
	await get_tree().process_frame
	# Leave through the same door the game does, so this run exercises the real shutdown.
	if _main != null and _main.has_method("shutdown_and_quit"):
		_main.shutdown_and_quit()
	else:
		get_tree().quit()
