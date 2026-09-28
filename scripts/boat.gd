## The boat: geometry, physics, and the Drift autopilot.
##
## Prototype: reference/ukiyo-river.html lines 693-741 (build) and 1361-1399 (updateBoat).
## The boat keeps the prototype's convention that +Z is forward, so heading feeds straight into
## rotation.y and the trigonometry below is the prototype's unchanged. Nothing here uses look_at.
class_name Boat
extends Node3D

## Prototype FLOW - the river carries everything downstream at this rate.
const FLOW: float = 0.45

## Prototype: the boat starts here, pointing down the channel.
const START_Z: float = -335.0

## Prototype: the hull is held this far inside the bank before it scrapes.
const BANK_MARGIN: float = 1.8

## Prototype: |z| is clamped here, at the ends of the modelled river.
const Z_LIMIT: float = 390.0

@export var environment_controller: EnvironmentController

## Where the Boatman camera sits. Phase 7 reparents this to the boatman's head.
@export var eye: Marker3D

## The bow lantern's light and glow, positioned by the builder's LANTERN_POS.
@export var lantern_light: OmniLight3D
@export var lantern_glow: MeshInstance3D

## Live state, read by the camera and the water shader.
var boat_x: float = 0.0
var boat_z: float = START_Z
var heading: float = 0.0
var speed: float = 0.0
var turn: float = 0.0
## Poling phase, consumed by the boatman animation in Phase 7.
var push: float = 0.0

## Prototype `autopilot`, on until the player touches the controls.
var drift: bool = true

var _auto_direction: float = 1.0
var _paper_material: StandardMaterial3D
var _glow_material: StandardMaterial3D


func _ready() -> void:
	boat_x = UkiyoMath.river_x(START_Z)
	boat_z = START_Z
	heading = atan(UkiyoMath.river_slope(START_Z))
	rotation_order = EULER_ORDER_YXZ

	var meshes: Dictionary = BoatBuilder.build()
	var materials: Dictionary = BoatBuilder.materials()
	for key: String in meshes:
		var instance := MeshInstance3D.new()
		instance.name = key.capitalize()
		instance.mesh = meshes[key]
		instance.material_override = materials[key]
		add_child(instance)
		if key == BoatBuilder.MAT_PAPER:
			_paper_material = materials[key]

	# Put the boat where it belongs before anyone reads it. Without this the transform stays at
	# the origin until the first physics tick, and the camera spends its first seconds crawling
	# 335 m up the river to catch up.
	position = Vector3(boat_x, 0.0, boat_z)
	rotation = Vector3(0.0, heading, 0.0)

	if eye != null:
		eye.position = BoatBuilder.EYE_POS
	if lantern_light != null:
		# Prototype: lampLight sits just behind and below the lantern itself.
		lantern_light.position = BoatBuilder.LANTERN_POS + Vector3(0.0, -0.1, -0.2)
	if lantern_glow != null:
		lantern_glow.position = BoatBuilder.LANTERN_POS
		_glow_material = lantern_glow.material_override as StandardMaterial3D


## The prototype runs everything from one loop with one clock. Keeping the boat on _process
## rather than _physics_process matches that, keeps it on the same `elapsed` the waves and the
## environment use, and avoids the camera reading a 60 Hz transform from a 300 fps frame.
func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)
	var t: float = 0.0
	var wind: float = 1.0
	if environment_controller != null:
		t = environment_controller.elapsed
		wind = environment_controller.num("wind")
	step_physics(dt, t, wind)
	_update_lantern(t)


## updateBoat(dt, t) - input, autopilot, integration, bank limits, then bob and tilt.
## Public so scripts/tools/boat_check.gd can step it with a fixed dt.
func step_physics(dt: float, t: float, wind: float) -> void:
	var thrust: float = 0.0
	var steer: float = 0.0
	if Input.is_action_pressed("ukiyo_forward"):
		thrust += 1.0
	if Input.is_action_pressed("ukiyo_back"):
		thrust -= 0.6
	if Input.is_action_pressed("ukiyo_right"):
		steer += 1.0
	if Input.is_action_pressed("ukiyo_left"):
		steer -= 1.0
	thrust = clampf(thrust, -0.6, 1.0)
	steer = clampf(steer, -1.0, 1.0)

	var player_input: bool = absf(thrust) > 0.05 or absf(steer) > 0.05
	if player_input and drift:
		drift = false

	if drift:
		# Aim 28 m downstream, reversing at the ends of the river.
		if boat_z > 360.0:
			_auto_direction = -1.0
		elif boat_z < -360.0:
			_auto_direction = 1.0
		var target_z: float = boat_z + 28.0 * _auto_direction
		var target_x: float = UkiyoMath.river_x(target_z)
		var d: float = atan2(target_x - boat_x, target_z - boat_z) - heading
		while d > PI:
			d -= TAU
		while d < -PI:
			d += TAU
		steer = clampf(-d * 2.2, -1.0, 1.0)
		thrust = 0.25 if absf(d) > 1.2 else 0.5

	speed += (thrust * 3.2 - speed * 0.45) * dt
	var turn_rate: float = steer * (0.35 + minf(absf(speed), 5.0) * 0.1)
	turn = lerpf(turn, turn_rate, 1.0 - exp(-dt * 3.0))
	heading -= turn * dt
	boat_x += sin(heading) * speed * dt
	boat_z += cos(heading) * speed * dt + FLOW * dt

	# Bank collision: slide along the limit and shed a little speed.
	var limit: float = UkiyoMath.RIVER_HALF - BANK_MARGIN
	var offset: float = boat_x - UkiyoMath.river_x(boat_z)
	if absf(offset) > limit:
		boat_x = UkiyoMath.river_x(boat_z) + signf(offset) * limit
		speed *= 0.96
	if absf(boat_z) > Z_LIMIT:
		boat_z = signf(boat_z) * Z_LIMIT
		speed *= 0.9

	# Ride the waves: sample ahead for pitch and abeam for roll.
	var forward_reach: float = 3.0
	var y: float = UkiyoMath.wave_h(boat_x, boat_z, t, wind)
	var y_forward: float = UkiyoMath.wave_h(
		boat_x + sin(heading) * forward_reach, boat_z + cos(heading) * forward_reach, t, wind
	)
	var y_side: float = UkiyoMath.wave_h(
		boat_x + cos(heading), boat_z - sin(heading), t, wind
	)

	position = Vector3(boat_x, y + 0.02 * sin(t * 1.1), boat_z)
	rotation = Vector3(
		-(y_forward - y) / forward_reach * 2.0 - speed * 0.006 + 0.012 * sin(t * 0.9),
		heading,
		(y_side - y) * 1.5 + turn * speed * 0.02 + 0.02 * sin(t * 0.7) * wind
	)

	# Poling effort, used by the boatman animation.
	var activity: float = 1.0 if (drift or absf(thrust) > 0.05) else 0.2
	push += dt * (0.7 + absf(speed) * 0.22) * activity


## The prototype's lantern flicker, driving the light, the paper and the glow sprite.
func _update_lantern(t: float) -> void:
	var night: float = 1.0
	if environment_controller != null:
		night = environment_controller.num("night")
	var flicker: float = 1.0 + 0.05 * sin(t * 13.0) + 0.04 * sin(t * 23.7)

	if lantern_light != null:
		lantern_light.light_energy = (0.5 + 1.9 * night) * flicker
	if _paper_material != null:
		var level: float = clampf((0.55 + 0.6 * night) * flicker, 0.0, 1.2)
		_paper_material.albedo_color = Color("#ffd898").srgb_to_linear() * level
	if _glow_material != null:
		var alpha: float = (0.25 + 0.6 * night) * flicker
		_glow_material.albedo_color = Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0))


## World position of the lantern, for the water shader's specular and light pool.
func lantern_global_position() -> Vector3:
	return global_transform * BoatBuilder.LANTERN_POS


## Heading as the (sin, cos) pair the water shader wants.
func heading_vector() -> Vector2:
	return Vector2(sin(heading), cos(heading))


## Prototype: uSpeedN = clamp(|speed| / 6, 0, 1).
func speed_normalised() -> float:
	return clampf(absf(speed) / 6.0, 0.0, 1.0)
