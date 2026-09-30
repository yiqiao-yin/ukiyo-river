## Runs the main scene for a fixed number of frames, then closes it the way a window close
## does, and reports whether anything was left behind.
##
## This replaces `--quit-after N` as the per-change check. `--quit-after` force-quits between
## frames, which skips the game's own shutdown entirely - so it could never catch a problem in
## it, and it reported a false leak warning for the audio generator that no amount of project
## code could fix (godotengine/godot#95484). Sending the close request instead exercises exactly
## what happens when the player quits.
##
##   godot --headless --path 'C:\Dev\ukiyo-river' --script res://scripts/tools/run_check.gd
extends SceneTree

## Long enough for every system to build and a couple of seconds of simulation to run.
const FRAMES: int = 120

var _frames: int = 0


func _initialize() -> void:
	root.add_child(load("res://main.tscn").instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == FRAMES:
		print("[run_check] closing after %d frames" % FRAMES)
		root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	return false
