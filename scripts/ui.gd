## The top-right control bar.
##
## Prototype: reference/ukiyo-river.html lines 79-86 and the handlers at 1344-1351. Five buttons
## cycling in the prototype's order - Weather storm/rain/clear, Time night/dusk/day, View
## Follow/Boatman/Orbit - plus Drift and Sound as on/off toggles.
extends CanvasLayer

@export var environment_controller: EnvironmentController
@export var camera: Camera3D
@export var boat: Boat
@export var lightning: Lightning
@export var audio_director: AudioDirector

@export var weather_button: Button
@export var time_button: Button
@export var view_button: Button
@export var drift_button: Button
@export var sound_button: Button


func _ready() -> void:
	weather_button.pressed.connect(_on_weather)
	time_button.pressed.connect(_on_time)
	view_button.pressed.connect(_on_view)
	drift_button.pressed.connect(_on_drift)
	sound_button.pressed.connect(_on_sound)
	_refresh()


func _on_weather() -> void:
	environment_controller.cycle_weather()
	# Prototype: switching back to Storm pulls the next bolt in so it is not a long wait.
	if environment_controller.weather_key == "storm" and lightning != null:
		lightning.schedule_soon()
	_refresh()


func _on_time() -> void:
	environment_controller.cycle_time()
	_refresh()


func _on_view() -> void:
	camera.cycle_mode()
	_refresh()


func _on_drift() -> void:
	boat.drift = not boat.drift
	_refresh()


func _on_sound() -> void:
	audio_director.enabled = not audio_director.enabled
	_refresh()


func _process(_delta: float) -> void:
	# Drift switches itself off the moment the player steers, so the button has to follow it.
	if boat != null and drift_button.button_pressed != boat.drift:
		drift_button.button_pressed = boat.drift


func _refresh() -> void:
	var weather: Dictionary = EnvironmentController.WEATHERS[environment_controller.weather_key]
	weather_button.text = "Weather: %s" % weather["label"]
	time_button.text = "Time: %s" % environment_controller.time_key.capitalize()
	view_button.text = "View: %s" % camera.mode_name()
	drift_button.button_pressed = boat.drift
	sound_button.button_pressed = audio_director.enabled
