## Root of the scene. Wires the systems together and verifies the maths port on startup.
extends Node3D

@export var environment_controller: EnvironmentController
@export var architecture: Architecture
@export var floating_lanterns: FloatingLanterns
@export var trees: Trees
@export var audio_director: AudioDirector


func _ready() -> void:
	_ready_quit_handling()
	NoiseCheck.run()
	BoatCheck.run()
	AudioCheck.run()
	WorldCheck.run(floating_lanterns, architecture, trees)
	print("[main] Ukiyo River - %s / %s" % [
		environment_controller.time_key, environment_controller.weather_key,
	])


## Take over quitting so the audio generator can be released first - see
## AudioDirector.shutdown(). Without this, closing the window leaks its playback.
func _ready_quit_handling() -> void:
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		shutdown_and_quit()


## Also reachable from the screenshot tool, so the offscreen renders exit the same way a real
## window close does.
func shutdown_and_quit() -> void:
	if audio_director != null:
		audio_director.shutdown()
	# The audio server releases the playback on its own thread, so give it wall-clock time
	# rather than a frame or two - two frames raced it and let the leak through intermittently.
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
