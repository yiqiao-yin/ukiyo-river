## Renders main.tscn offscreen for a fixed number of frames and writes a PNG.
##
## Used to eyeball a phase without opening the editor:
##   godot --path 'C:\Dev\ukiyo-river' --resolution 1280x720 res://scenes/screenshot.tscn
## Headless runs cannot do this - they never build a rendering device, so shader compile errors
## and anything that only shows up on screen stay invisible there.
extends Node

@export_file("*.png") var out_path: String = "res://shot.png"
@export var wait_frames: int = 120

var _frames: int = 0


func _ready() -> void:
	add_child(load("res://main.tscn").instantiate())


func _process(_delta: float) -> void:
	_frames += 1
	if _frames < wait_frames:
		return
	set_process(false)
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(out_path)
	if error != OK:
		push_error("[screenshot] could not write %s (error %d)" % [out_path, error])
	else:
		print("[screenshot] wrote ", ProjectSettings.globalize_path(out_path))
	get_tree().quit()
