## Paper lanterns set adrift on the river.
##
## Prototype: reference/ukiyo-river.html lines 513-518 and updateFloaters() at 1400-1416. Forty
## of them ride the current a little faster than the water, wrap around the boat so there are
## always some in sight, and nudge aside if the hull comes too close.
##
## Draws from the shared world RNG immediately after the villages, as in the prototype.
class_name FloatingLanterns
extends Node3D

## Prototype NFL.
const COUNT: int = 40

## Prototype: the lanterns drift at FLOW * 1.3.
const DRIFT: float = Boat.FLOW * 1.3

## Prototype: they wrap to stay within this much of the boat.
const WRAP_RANGE: float = 160.0
const WRAP_SPAN: float = 320.0

## Prototype: the hull pushes a lantern aside inside this radius.
const PUSH_RADIUS: float = 2.6
const PUSH_RATE: float = 2.5

@export var environment_controller: EnvironmentController
@export var boat: Boat
@export var world_rng: WorldRng
@export var paper: MultiMeshInstance3D
@export var base: MultiMeshInstance3D

## Per lantern: x is its position along the river, y its offset across it, z its phase.
## Public because scripts/tools/world_check.gd reads it - these 120 numbers come off the shared
## stream after every village draw, so they only line up if the whole sequence did.
var floaters: PackedVector3Array = PackedVector3Array()

var _paper_material: StandardMaterial3D


func _ready() -> void:
	var rng: UkiyoRng = world_rng.rng
	for _i: int in COUNT:
		# Order matters: z, then off, then phase, exactly as the prototype's object literal.
		var z: float = -330.0 + rng.next() * 300.0
		var off: float = (rng.next() * 2.0 - 1.0) * (UkiyoMath.RIVER_HALF - 3.0)
		var phase: float = rng.next() * 6.28
		floaters.push_back(Vector3(z, off, phase))

	_paper_material = _setup(paper, Vector3(0.34, 0.42, 0.34), true)
	_setup(base, Vector3(0.52, 0.1, 0.52), false)


func _process(_delta: float) -> void:
	if environment_controller == null or boat == null:
		return
	var delta: float = minf(get_process_delta_time(), 0.05)
	var t: float = environment_controller.elapsed
	var wind: float = environment_controller.num("wind")
	var night: float = environment_controller.num("night")

	if _paper_material != null:
		var flicker: float = 1.0 + 0.05 * sin(t * 13.0) + 0.04 * sin(t * 23.7)
		_paper_material.albedo_color = (
			Color(ArchitectureBuilder.LAMP_BASE).srgb_to_linear()
			* ((0.4 + 0.8 * night) * flicker * 1.1)
		)

	var limit: float = UkiyoMath.RIVER_HALF - 1.0
	for i: int in COUNT:
		var f: Vector3 = floaters[i]
		f.x += DRIFT * delta
		if f.x > boat.boat_z + WRAP_RANGE:
			f.x -= WRAP_SPAN
		if f.x < boat.boat_z - WRAP_RANGE:
			f.x += WRAP_SPAN

		var x: float = UkiyoMath.river_x(f.x) + f.y
		var dx: float = x - boat.boat_x
		var dz: float = f.x - boat.boat_z
		if Vector2(dx, dz).length() < PUSH_RADIUS:
			f.y += (signf(dx) if not is_zero_approx(dx) else 1.0) * delta * PUSH_RATE
			x = UkiyoMath.river_x(f.x) + f.y
		f.y = clampf(f.y, -limit, limit)
		floaters[i] = f

		# Prototype hides the far ones by collapsing them rather than culling.
		var scale: float = 1.0 if absf(f.x) < 440.0 else 0.0001
		var y: float = UkiyoMath.wave_h(x, f.x, t, wind)
		var basis := Basis.from_euler(
			Vector3(0.05 * sin(t + f.z), f.z, 0.05 * cos(t * 1.3 + f.z)), EULER_ORDER_XYZ
		).scaled(Vector3.ONE * scale)
		base.multimesh.set_instance_transform(i, Transform3D(basis, Vector3(x, y + 0.08, f.x)))
		paper.multimesh.set_instance_transform(
			i, Transform3D(basis, Vector3(x, y + 0.08 + 0.26, f.x))
		)


## Builds one MultiMesh of `COUNT` boxes and returns its material.
func _setup(target: MultiMeshInstance3D, size: Vector3, lit: bool) -> StandardMaterial3D:
	if target == null:
		return null
	var buffer := MeshUtil.Buffer.new()
	MeshUtil.add_box(buffer, Vector3.ZERO, size)
	var mesh := ArrayMesh.new()
	buffer.commit(mesh)

	var material := StandardMaterial3D.new()
	if lit:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		material.albedo_color = Color(
			ArchitectureBuilder.COLOURS[ArchitectureBuilder.MAT_DARKWOOD] as String
		).srgb_to_linear()
		material.roughness = 1.0
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = COUNT
	target.multimesh = multimesh
	target.material_override = material
	target.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The lanterns roam the whole river, so let them be drawn wherever they are.
	target.custom_aabb = AABB(Vector3(-450, -5, -450), Vector3(900, 20, 900))
	return material
