## Time of day and weather: the prototype's TIMES / WEATHERS presets, targetEnv() and stepEnv().
##
## Prototype: reference/ukiyo-river.html lines 1189-1221 plus the per-frame block at 1500-1533.
## Phase 1 wires the colours, the fog, the sky shader and the sun. The remaining consumers
## (water, rain, emissive materials, audio) attach in later phases through the same `env` values,
## which is why the whole preset table lands here now rather than being filled in piecemeal.
class_name EnvironmentController
extends Node

## Cycle orders match the prototype's Time and Weather buttons.
const TIME_ORDER: PackedStringArray = ["night", "dusk", "day"]
const WEATHER_ORDER: PackedStringArray = ["storm", "rain", "clear"]

const TIMES: Dictionary = {
	"night": {
		"top": "#070a12", "hor": "#243048", "fog": "#1f2835",
		"hemi_sky": "#6b7fa6", "hemi_ground": "#0e1014", "hemi": 0.62,
		"sun_col": "#9fb4d8", "sun": 0.45, "sun_dir": Vector3(0.35, 0.42, 0.8),
		"deep": "#0f1b22", "stars": 1.0, "night": 1.0, "amb": 0.3,
	},
	"dusk": {
		"top": "#20283d", "hor": "#b0715a", "fog": "#6b5d63",
		"hemi_sky": "#9aa3c0", "hemi_ground": "#2a2420", "hemi": 0.75,
		"sun_col": "#ffb27a", "sun": 0.9, "sun_dir": Vector3(-0.55, 0.1, 0.83),
		"deep": "#1a2a30", "stars": 0.0, "night": 0.55, "amb": 0.6,
	},
	"day": {
		"top": "#5d82b3", "hor": "#cdd6dc", "fog": "#aeb8bf",
		"hemi_sky": "#dfe8f2", "hemi_ground": "#4a4636", "hemi": 1.05,
		"sun_col": "#fff2dc", "sun": 1.1, "sun_dir": Vector3(0.4, 0.7, 0.5),
		"deep": "#1f3a40", "stars": 0.0, "night": 0.0, "amb": 1.0,
	},
}

const WEATHERS: Dictionary = {
	"clear": {"rain": 0.0, "cloud": 0.25, "density": 0.0028, "wind": 0.35, "storm": 0.0, "label": "Clear"},
	"rain": {"rain": 0.45, "cloud": 0.75, "density": 0.0065, "wind": 0.85, "storm": 0.0, "label": "Rain"},
	"storm": {"rain": 1.0, "cloud": 1.0, "density": 0.0105, "wind": 1.6, "storm": 1.0, "label": "Storm"},
}

const COLOR_KEYS: PackedStringArray = [
	"top", "hor", "fog", "hemi_sky", "hemi_ground", "sun_col", "deep",
]
const NUM_KEYS: PackedStringArray = [
	"hemi", "sun", "stars", "night", "amb", "rain", "cloud", "density", "wind", "storm",
]

## Current selections. The prototype starts on a stormy night. Exported so the presets can be
## flipped from the inspector before the Weather and Time buttons arrive in Phase 4.
@export_enum("night", "dusk", "day") var time_key: String = "night"
@export_enum("storm", "rain", "clear") var weather_key: String = "storm"

## Live, smoothed environment values - the prototype's `env` object. Colours are linear.
var colors: Dictionary = {}
var numbers: Dictionary = {}
var sun_dir: Vector3 = Vector3(0.35, 0.42, 0.8).normalized()

## Lightning flash strength for this frame, written by the lightning system in Phase 4.
var flash: float = 0.0

## Accumulated scene time, the prototype's `T`.
var elapsed: float = 0.0

@export var world_environment: WorldEnvironment
@export var sun_light: DirectionalLight3D

var _sky_material: ShaderMaterial


func _ready() -> void:
	_snap_to_target()
	if world_environment != null:
		var sky: Sky = world_environment.environment.sky
		if sky != null and sky.sky_material is ShaderMaterial:
			_sky_material = sky.sky_material
	_apply()


func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)
	elapsed += dt
	step(dt)
	_apply()


## stepEnv(dt) - exponential approach to the current preset.
func step(dt: float) -> void:
	var target_colors: Dictionary = {}
	var target_numbers: Dictionary = {}
	_target_env(target_colors, target_numbers)
	var target_sun_dir: Vector3 = (TIMES[time_key]["sun_dir"] as Vector3).normalized()

	var k: float = 1.0 - exp(-dt * 1.1)
	for key: String in COLOR_KEYS:
		colors[key] = (colors[key] as Color).lerp(target_colors[key], k)
	for key: String in NUM_KEYS:
		numbers[key] = (numbers[key] as float) + (float(target_numbers[key]) - float(numbers[key])) * k
	sun_dir = sun_dir.lerp(target_sun_dir, k).normalized()


func cycle_time() -> void:
	var i: int = TIME_ORDER.find(time_key)
	time_key = TIME_ORDER[(i + 1) % TIME_ORDER.size()]


func cycle_weather() -> void:
	var i: int = WEATHER_ORDER.find(weather_key)
	weather_key = WEATHER_ORDER[(i + 1) % WEATHER_ORDER.size()]


func num(key: String) -> float:
	return float(numbers[key])


func col(key: String) -> Color:
	return colors[key] as Color


## targetEnv() - the preset pair blended into a single set of values.
func _target_env(out_colors: Dictionary, out_numbers: Dictionary) -> void:
	var t: Dictionary = TIMES[time_key]
	var w: Dictionary = WEATHERS[weather_key]
	var cloud: float = float(w["cloud"])

	for key: String in COLOR_KEYS:
		var c: Color = Color(t[key] as String).srgb_to_linear()
		if key == "top" or key == "hor" or key == "fog":
			# Overcast desaturates the sky toward its own luminance.
			var lum: float = c.r * 0.3 + c.g * 0.55 + c.b * 0.15
			c = c.lerp(Color(lum * 0.62, lum * 0.66, lum * 0.72), cloud * 0.6)
		out_colors[key] = c

	out_numbers["hemi"] = float(t["hemi"]) * (1.0 - cloud * 0.35)
	out_numbers["sun"] = float(t["sun"]) * (1.0 - cloud * 0.7)
	out_numbers["stars"] = float(t["stars"]) * (1.0 - cloud)
	out_numbers["night"] = float(t["night"])
	out_numbers["amb"] = float(t["amb"])
	out_numbers["rain"] = float(w["rain"])
	out_numbers["cloud"] = cloud
	out_numbers["density"] = float(w["density"])
	out_numbers["wind"] = float(w["wind"])
	out_numbers["storm"] = float(w["storm"])


func _snap_to_target() -> void:
	colors = {}
	numbers = {}
	_target_env(colors, numbers)
	sun_dir = (TIMES[time_key]["sun_dir"] as Vector3).normalized()


## Pushes the current values into the scene. The per-frame block from the prototype's loop.
func _apply() -> void:
	if world_environment != null:
		var e: Environment = world_environment.environment
		e.fog_light_color = col("fog")
		# three.js FogExp2 is exp(-(d*density)^2); Godot's exponential fog is exp(-d*density).
		# Using the same number matches the two curves at the 1/density e-fold distance.
		e.fog_density = num("density")
		e.ambient_light_color = col("hemi_sky")
		e.ambient_light_energy = num("hemi") + flash * 1.8
		e.volumetric_fog_enabled = num("storm") > 0.5
		e.volumetric_fog_albedo = col("fog")

	if sun_light != null:
		var lightning_dir: bool = flash > 0.05
		var dir: Vector3 = sun_dir
		sun_light.light_color = col("sun_col").lerp(
			Color(0.847, 0.878, 1.0).srgb_to_linear(), clampf(flash, 0.0, 1.0)
		)
		sun_light.light_energy = num("sun") + flash * 1.4
		if not lightning_dir:
			_aim_light(sun_light, dir)

	if _sky_material != null:
		_sky_material.set_shader_parameter("u_top", col("top"))
		_sky_material.set_shader_parameter("u_hor", col("hor"))
		_sky_material.set_shader_parameter("u_fog", col("fog"))
		_sky_material.set_shader_parameter("u_sun_col", col("sun_col"))
		_sky_material.set_shader_parameter("u_sun_dir", sun_dir)
		_sky_material.set_shader_parameter("u_time", elapsed)
		_sky_material.set_shader_parameter("u_cloud", num("cloud"))
		_sky_material.set_shader_parameter("u_flash", flash)
		_sky_material.set_shader_parameter("u_stars", num("stars"))
		_sky_material.set_shader_parameter("u_haze", num("rain") * 0.7)


## The prototype moves the light 100 m along sunDir and points it back at the boat, so the light
## travels along -sunDir. A DirectionalLight3D shines down its own -Z.
func _aim_light(light: DirectionalLight3D, direction: Vector3) -> void:
	var forward: Vector3 = -direction.normalized()
	var up: Vector3 = Vector3.UP
	if absf(forward.dot(up)) > 0.999:
		up = Vector3.FORWARD
	var right: Vector3 = up.cross(forward).normalized()
	var true_up: Vector3 = forward.cross(right).normalized()
	light.global_transform.basis = Basis(right, true_up, forward)
