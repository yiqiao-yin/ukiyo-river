## Rain streaks and drifting petals.
##
## Prototype: reference/ukiyo-river.html lines 1176-1187 and updateRain() at 1417-1443. Rain is
## 8000 line segments recycled inside a 70 x 35 x 70 box around the camera, falling at 22-32 m/s
## with a wind drift, each drawn as 0.035 s of travel. Petals are 220 points falling at 0.5-1.1
## m/s with a sine sway, recycled in a 50 m box.
##
## Both become GPUParticles3D parented to nothing and moved onto the camera each frame, with
## local_coords off so the drops stay in world space while the emitter follows.
extends Node3D

## Prototype RAIN_MAX (desktop branch) and NPET.
const RAIN_MAX: int = 8000
const PETAL_COUNT: int = 220

## Prototype: the recycling box around the camera.
const RAIN_BOX: Vector3 = Vector3(70.0, 35.0, 70.0)
const PETAL_BOX: Vector3 = Vector3(50.0, 10.0, 50.0)

## Prototype: drops fall at these speeds, and the streak is this many seconds of travel.
const FALL_MIN: float = 22.0
const FALL_MAX: float = 32.0
const STREAK_SECONDS: float = 0.035

## Prototype: wind pushes along a fixed bearing, wx = cos(0.6)*wind*5, wz = sin(0.6)*wind*5.
const WIND_BEARING: float = 0.6
const WIND_SCALE: float = 5.0

@export var environment_controller: EnvironmentController
@export var camera: Camera3D
@export var rain: GPUParticles3D
@export var petals: GPUParticles3D

var _rain_process: ParticleProcessMaterial
var _rain_material: StandardMaterial3D


func _ready() -> void:
	if rain != null:
		rain.amount = RAIN_MAX
		_rain_process = rain.process_material as ParticleProcessMaterial
		_rain_material = rain.material_override as StandardMaterial3D
	if petals != null:
		petals.amount = PETAL_COUNT


func _process(_delta: float) -> void:
	if environment_controller == null or camera == null:
		return
	var env: EnvironmentController = environment_controller
	var rain_amount: float = env.num("rain")
	var wind: float = env.num("wind")

	# Follow the camera. The prototype wraps each drop around the camera by hand; moving the
	# emitter does the same job and keeps the drops themselves in world space. Both emitters sit
	# above the camera in their own local transforms, because the prototype only ever recycles a
	# drop to somewhere overhead - spawning them level with the camera puts a few right against
	# the lens, where a 1 cm drop covers a quarter of the screen.
	global_position = camera.global_position

	if rain != null:
		rain.emitting = rain_amount > 0.01
		# amount_ratio thins the drops without restarting the system, which is what the
		# prototype's setDrawRange(0, n*2) achieves.
		rain.amount_ratio = clampf(rain_amount, 0.0, 1.0)
		_update_rain_motion(wind)
		if _rain_material != null:
			# Prototype: the streak colour is the horizon lerped most of the way to a cold white,
			# and the flash brightens it.
			var tint: Color = env.col("hor").lerp(Color("#e8eefc").srgb_to_linear(), 0.55)
			tint.a = clampf(
				0.2 + 0.12 * (1.0 - env.num("night")) + env.flash * 0.3, 0.0, 1.0
			)
			_rain_material.albedo_color = tint



## Rain velocity is constant in the prototype - drops do not accelerate - so the wind goes into
## the emission direction rather than into gravity.
func _update_rain_motion(wind: float) -> void:
	if _rain_process == null:
		return
	var wx: float = cos(WIND_BEARING) * wind * WIND_SCALE
	var wz: float = sin(WIND_BEARING) * wind * WIND_SCALE
	var mid := Vector3(wx, -(FALL_MIN + FALL_MAX) * 0.5, wz)
	_rain_process.direction = mid.normalized()
	_rain_process.initial_velocity_min = Vector3(wx, -FALL_MIN, wz).length()
	_rain_process.initial_velocity_max = Vector3(wx, -FALL_MAX, wz).length()
