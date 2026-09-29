## Lightning bolts, the flash envelope, and the thunder that follows.
##
## Prototype: reference/ukiyo-river.html lines 1223-1265 plus the flash block in the frame loop.
## A strike picks a bearing and a distance, subdivides a line from cloud base to ground into a
## jagged polyline, expands it into a camera-facing ribbon with three forks, and drives a
## five-pulse flash envelope. Thunder is fired after the sound has had time to travel.
##
## Runs at a low process_priority so `flash` is already set when EnvironmentController applies it
## to the sky, the sun and the ambient light in the same frame.
class_name Lightning
extends Node3D

## Prototype jag(): recursion depth and the initial sideways displacement.
const JAG_DEPTH: int = 7
const JAG_DISPLACEMENT: float = 45.0

## Prototype: bolts only fall once the storm has faded in.
const STORM_THRESHOLD: float = 0.6

## Prototype: the bolt mesh is drawn for this long, the flash envelope runs for this long.
const BOLT_VISIBLE: float = 0.6
const FLASH_WINDOW: float = 1.2

## Prototype: sound covers roughly this much distance per second.
const SOUND_SPEED: float = 140.0

@export var environment_controller: EnvironmentController
@export var boat: Boat
@export var camera: Camera3D
@export var audio_director: AudioDirector
@export var bolt_mesh: MeshInstance3D

var _immediate: ImmediateMesh
var _material: StandardMaterial3D
var _since_strike: float = 99.0
var _next_strike: float = 2.5
## Each entry is (start time, amplitude).
var _pulses: Array[Vector2] = []
var _direction: Vector3 = Vector3.UP


func _ready() -> void:
	if bolt_mesh == null:
		return
	_immediate = ImmediateMesh.new()
	bolt_mesh.mesh = _immediate
	_material = bolt_mesh.material_override as StandardMaterial3D
	bolt_mesh.visible = false


func _process(delta: float) -> void:
	if environment_controller == null:
		return
	var dt: float = minf(delta, 0.05)
	var storm: float = environment_controller.num("storm")

	if storm > STORM_THRESHOLD:
		_next_strike -= dt
		if _next_strike <= 0.0:
			strike()
			# Prototype: 4 to 13 seconds between bolts.
			_next_strike = 4.0 + randf() * 9.0

	_since_strike += dt
	var flash: float = 0.0
	if _since_strike < FLASH_WINDOW:
		flash = _flash_at(_since_strike) * clampf(storm * 1.2, 0.0, 1.0)
	environment_controller.flash = flash
	environment_controller.flash_direction = _direction

	if bolt_mesh != null:
		bolt_mesh.visible = _since_strike < BOLT_VISIBLE
		if _material != null:
			var albedo: Color = _material.albedo_color
			albedo.a = clampf(flash * 1.3 + 0.08, 0.0, 1.0)
			_material.albedo_color = albedo


## Prototype: the Weather button brings the next bolt forward when you switch back to Storm.
func schedule_soon() -> void:
	_next_strike = 1.5


## strike() - place a bolt, build its mesh, start the flash, and queue the thunder.
func strike() -> void:
	if boat == null or camera == null or _immediate == null:
		return

	var angle: float = randf() * TAU
	# Prototype: roughly one bolt in five falls close by.
	var close: bool = randf() < 0.22
	var distance: float = (60.0 + randf() * 50.0) if close else (130.0 + randf() * 200.0)
	var bx: float = boat.boat_x + sin(angle) * distance
	var bz: float = boat.boat_z + cos(angle) * distance

	var top := Vector3(bx + (randf() - 0.5) * 40.0, 190.0, bz + (randf() - 0.5) * 40.0)
	var bottom := Vector3(bx, maxf(0.0, UkiyoMath.terrain_h(bx, bz)), bz)

	var points: PackedVector3Array = PackedVector3Array([top])
	_jag(top, bottom, JAG_DEPTH, JAG_DISPLACEMENT, points)

	var to_camera: Vector3 = (camera.global_position - bottom).normalized()
	var width: float = 0.6 + distance * 0.006

	_immediate.clear_surfaces()
	_immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_ribbon(points, width, to_camera)
	# Three forks branching off the main channel.
	for _i: int in 3:
		var start: Vector3 = points[int(float(points.size()) * (0.15 + randf() * 0.5))]
		var end: Vector3 = start + Vector3(
			(randf() - 0.5) * 70.0, -30.0 - randf() * 50.0, (randf() - 0.5) * 70.0
		)
		var branch: PackedVector3Array = PackedVector3Array([start])
		_jag(start, end, 5, 20.0, branch)
		_ribbon(branch, width * 0.45, to_camera)
	_immediate.surface_end()

	_since_strike = 0.0
	_pulses = [
		Vector2(0.0, 1.0),
		Vector2(0.07, 0.3 + randf() * 0.3),
		Vector2(0.16, 0.6 + randf() * 0.4),
		Vector2(0.33, 0.2),
		Vector2(0.46, randf() * 0.6),
	]
	_direction = Vector3(bx - boat.boat_x, 120.0, bz - boat.boat_z).normalized()

	# Prototype: nearness drives how sharp the thunder is, and the delay is the travel time.
	var nearness: float = clampf((distance - 60.0) / 270.0, 0.0, 1.0)
	if audio_director != null:
		var timer: SceneTreeTimer = get_tree().create_timer(distance / SOUND_SPEED)
		timer.timeout.connect(audio_director.thunder.bind(nearness))


## jag(a, b, depth, displacement, out) - midpoint displacement down to single segments.
func _jag(a: Vector3, b: Vector3, depth: int, displacement: float, out: PackedVector3Array) -> void:
	if depth == 0:
		out.push_back(b)
		return
	var mid: Vector3 = (a + b) * 0.5
	mid.x += (randf() - 0.5) * displacement
	mid.z += (randf() - 0.5) * displacement
	mid.y += (randf() - 0.5) * displacement * 0.3
	_jag(a, mid, depth - 1, displacement * 0.55, out)
	_jag(mid, b, depth - 1, displacement * 0.55, out)


## ribbon() - widen the polyline into camera-facing quads, tapering along its length.
func _ribbon(points: PackedVector3Array, width: float, to_camera: Vector3) -> void:
	for i: int in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var w: float = width * (1.0 - float(i) / float(points.size()) * 0.6)
		var side: Vector3 = (b - a).cross(to_camera).normalized() * w
		_immediate.surface_add_vertex(a - side)
		_immediate.surface_add_vertex(a + side)
		_immediate.surface_add_vertex(b + side)
		_immediate.surface_add_vertex(a - side)
		_immediate.surface_add_vertex(b + side)
		_immediate.surface_add_vertex(b - side)


## flashAt(t) - the pulses summed, each decaying at exp(-dt * 18).
func _flash_at(t: float) -> float:
	var total: float = 0.0
	for pulse: Vector2 in _pulses:
		if t >= pulse.x:
			total += pulse.y * exp(-(t - pulse.x) * 18.0)
	return total
