## Root of the scene. Wires the systems together and verifies the maths port on startup.
extends Node3D

@export var environment_controller: EnvironmentController
@export var architecture: Architecture
@export var floating_lanterns: FloatingLanterns


func _ready() -> void:
	NoiseCheck.run()
	BoatCheck.run()
	AudioCheck.run()
	WorldCheck.run(floating_lanterns, architecture)
	print("[main] Ukiyo River - %s / %s" % [
		environment_controller.time_key, environment_controller.weather_key,
	])
