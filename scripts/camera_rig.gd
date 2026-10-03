## Camera, ported from reference/ukiyo-river.html lines 1309-1330 and 1444-1463.
##
## Three modes cycling in the prototype's order: Follow, Boatman, Orbit. Drag looks around,
## the wheel zooms. The follow position is smoothed and lifted clear of the ground; the heading
## it orbits is smoothed separately so the camera swings behind the boat rather than snapping.
extends Camera3D

enum Mode { FOLLOW, BOATMAN, ORBIT }

## Prototype MODES, used for the View button in Phase 4.
const MODE_NAMES: PackedStringArray = ["Follow", "Boatman", "Orbit"]

## Prototype: cam.yawOff -= dx*0.006, cam.pitch += dy*0.004, fpPitch -= dy*0.004.
const YAW_PER_PIXEL: float = 0.006
const PITCH_PER_PIXEL: float = 0.004

## Prototype: clamp(cam.pitch, 0.04, 1.25) and clamp(cam.fpPitch, -0.7, 0.6).
const PITCH_MIN: float = 0.04
const PITCH_MAX: float = 1.25
const FP_PITCH_MIN: float = -0.7
const FP_PITCH_MAX: float = 0.6

## Prototype: cam.dist *= exp(deltaY*0.001), clamped 4.5-40.
const ZOOM_STEP: float = 1.12
const DIST_MIN: float = 4.5
const DIST_MAX: float = 40.0

@export var boat: Boat

var mode: Mode = Mode.FOLLOW

var _yaw_offset: float = 0.0
var _pitch: float = 0.24
var _fp_pitch: float = -0.05
var _distance: float = 12.0
var _orbit: float = 0.0
var _head: float = 0.0
var _dragging: bool = false
## Set from Settings.
var look_sensitivity: float = 1.0


func _ready() -> void:
	fov = 60.0
	near = 0.1
	far = 2200.0
	if boat != null:
		_head = boat.heading
	_update(1.0, 0.0)


## Prototype: the View button resets the look-around offset on every change.
func cycle_mode() -> void:
	mode = ((mode + 1) % MODE_NAMES.size()) as Mode
	_yaw_offset = 0.0


func mode_name() -> String:
	return MODE_NAMES[mode]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_MIDDLE:
				# Left click strikes and right click guards, so looking around is the
				# middle button.
				_dragging = button.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed:
					_distance = clampf(_distance / ZOOM_STEP, DIST_MIN, DIST_MAX)
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					_distance = clampf(_distance * ZOOM_STEP, DIST_MIN, DIST_MAX)
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_yaw_offset -= motion.relative.x * YAW_PER_PIXEL * look_sensitivity
		if mode == Mode.BOATMAN:
			_fp_pitch = clampf(
				_fp_pitch - motion.relative.y * PITCH_PER_PIXEL * look_sensitivity, FP_PITCH_MIN, FP_PITCH_MAX
			)
		else:
			_pitch = clampf(
				_pitch + motion.relative.y * PITCH_PER_PIXEL * look_sensitivity, PITCH_MIN, PITCH_MAX
			)


func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)
	_update(1.0 - exp(-dt * 6.0), dt)


func _update(weight: float, dt: float) -> void:
	if boat == null:
		return
	_head = UkiyoMath.angle_lerp(_head, boat.heading, 1.0 - exp(-dt * 2.2))

	# Prototype hides him in first person - you are looking out of his eyes.
	if boat.boatman != null:
		boat.boatman.visible = mode != Mode.BOATMAN

	if mode == Mode.BOATMAN:
		_update_boatman_view()
		return

	if mode == Mode.ORBIT:
		_orbit += dt * 0.1

	var yaw: float = (_orbit if mode == Mode.ORBIT else _head) + _yaw_offset + PI
	var target: Vector3 = boat.global_position + Vector3(0.0, 1.6, 0.0)
	var wanted := Vector3(
		target.x + sin(yaw) * cos(_pitch) * _distance,
		target.y + sin(_pitch) * _distance,
		target.z + cos(yaw) * cos(_pitch) * _distance
	)
	# Never let the camera sink into the bank or below the waterline.
	wanted.y = maxf(wanted.y, maxf(UkiyoMath.terrain_h(wanted.x, wanted.z) + 1.4, 0.7))
	global_position = global_position.lerp(wanted, weight)
	look_at(target, Vector3.UP)


## First person from the boatman's eye, looking where the boat is pointed plus the drag offset.
func _update_boatman_view() -> void:
	if boat.eye == null:
		return
	var eye_position: Vector3 = boat.eye.global_position
	global_position = eye_position
	var yaw: float = boat.heading + _yaw_offset
	var target := Vector3(
		eye_position.x + sin(yaw) * cos(_fp_pitch) * 10.0,
		eye_position.y + sin(_fp_pitch) * 10.0,
		eye_position.z + cos(yaw) * cos(_fp_pitch) * 10.0
	)
	look_at(target, Vector3.UP)
