## Root of the scene. Wires the systems together and verifies the maths port on startup.
extends Node3D

@export var environment_controller: EnvironmentController


func _ready() -> void:
	NoiseCheck.run()
	print("[main] Ukiyo River - %s / %s" % [
		environment_controller.time_key, environment_controller.weather_key,
	])
