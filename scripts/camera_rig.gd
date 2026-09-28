## Camera.
##
## Phase 1 is an inspection rig: orbit a point on the river with a mouse drag, zoom with the
## wheel, walk the point around with WASD so the whole valley can be looked over before the boat
## exists. Phase 3 replaces the target with the boat and adds the prototype's three modes
## (Follow / Boatman / Orbit) together with its InputMap-driven controls.
##
## Drag sensitivity, pitch clamps and the exponential position smoothing are the prototype's
## (reference/ukiyo-river.html lines 1309-1330 and 1444-1463).
extends Camera3D

## Prototype: cam.yawOff -= dx*0.006, cam.pitch += dy*0.004.
const YAW_PER_PIXEL: float = 0.006
const PITCH_PER_PIXEL: float = 0.004

## Prototype: clamp(cam.pitch, 0.04, 1.25).
const PITCH_MIN: float = 0.04
const PITCH_MAX: float = 1.25

## Prototype: cam.dist *= exp(deltaY*0.001), clamped 4.5-40. The upper bound is opened up for
## Phase 1 only, so the valley can be seen from above; Phase 3 restores the prototype's 40.
const ZOOM_STEP: float = 1.12
const DIST_MIN: float = 4.5
const DIST_MAX: float = 400.0

## Phase 1 scaffolding: metres per second the orbit target walks under WASD.
const TARGET_SPEED: float = 60.0

## Prototype boat start: boat = { x: riverX(-335), z: -335 }.
const START_Z: float = -335.0

var _yaw: float = 0.0
var _pitch: float = 0.24
var _distance: float = 40.0
var _target: Vector3 = Vector3.ZERO
var _dragging: bool = false


func _ready() -> void:
	fov = 60.0
	near = 0.1
	far = 2200.0
	_target = Vector3(UkiyoMath.river_x(START_Z), 0.0, START_Z)
	_place(1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				_dragging = button.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed:
					_distance = clampf(_distance / ZOOM_STEP, DIST_MIN, DIST_MAX)
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					_distance = clampf(_distance * ZOOM_STEP, DIST_MIN, DIST_MAX)
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * YAW_PER_PIXEL
		_pitch = clampf(_pitch + motion.relative.y * PITCH_PER_PIXEL, PITCH_MIN, PITCH_MAX)


func _process(delta: float) -> void:
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		move.z += 1.0
	if Input.is_key_pressed(KEY_S):
		move.z -= 1.0
	if Input.is_key_pressed(KEY_D):
		move.x += 1.0
	if Input.is_key_pressed(KEY_A):
		move.x -= 1.0
	if move != Vector3.ZERO:
		# Move relative to where the camera is looking, on the horizontal plane.
		var forward := Vector3(sin(_yaw), 0.0, cos(_yaw))
		var right := Vector3(forward.z, 0.0, -forward.x)
		_target += (forward * move.z + right * move.x).normalized() * TARGET_SPEED * delta

	_place(1.0 - exp(-delta * 6.0))


## Prototype's follow placement: orbit the target, never dip below the ground or the waterline.
func _place(weight: float) -> void:
	var yaw: float = _yaw + PI
	var wanted := Vector3(
		_target.x + sin(yaw) * cos(_pitch) * _distance,
		_target.y + sin(_pitch) * _distance,
		_target.z + cos(yaw) * cos(_pitch) * _distance
	)
	wanted.y = maxf(wanted.y, maxf(UkiyoMath.terrain_h(wanted.x, wanted.z) + 1.4, 0.7))
	global_position = global_position.lerp(wanted, weight)
	look_at(_target + Vector3(0.0, 1.6, 0.0), Vector3.UP)
