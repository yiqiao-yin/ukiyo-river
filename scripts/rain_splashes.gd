## Rain bouncing off the boat and running off its edges.
##
## Prototype: reference/ukiyo-river.html lines 849-881. A 220-point CPU pool spawns splashes on
## the canopy and the hat at 140 a second, and slower drips off the gunwales and the hat brim at
## 30 a second, both scaled by how hard it is raining.
##
## Here they are four GPUParticles3D whose emitters are point clouds sampled off the same
## surfaces. Each system's `amount` is the prototype's rate times its lifetime, so the same
## number of drops is in the air at once, and `amount_ratio` scales with the rain.
class_name RainSplashes
extends Node3D

## Prototype: splashes at 140/s, 70% on the canopy and 30% on the hat; drips at 30/s, split
## evenly between the gunwales and the hat brim.
const SPLASH_LIFE: float = 0.16
const DRIP_LIFE: float = 0.8
const CANOPY_RATE: float = 140.0 * 0.7
const HAT_SPLASH_RATE: float = 140.0 * 0.3
const GUNWALE_RATE: float = 30.0 * 0.5
const HAT_DRIP_RATE: float = 30.0 * 0.5

## Prototype PointsMaterial: colour 0xdfe8f5, size 0.04.
const DROP_SIZE: float = 0.04
const DROP_COLOUR: String = "#dfe8f5"

## Its own stream, so sampling these point clouds cannot disturb the world layout.
const SAMPLE_SEED: int = 8081

@export var environment_controller: EnvironmentController
## The boatman's hat, which the head-borne splashes and drips hang off.
@export var hat: Node3D

var _systems: Array[GPUParticles3D] = []


func _ready() -> void:
	var rng := UkiyoRng.new(SAMPLE_SEED)

	# Canopy: the prototype spawns along the arc of the awning, in the boat's own space.
	var canopy := PackedVector3Array()
	for _i: int in 240:
		var a: float = (rng.next() * 2.0 - 1.0) * 1.35
		var z: float = (rng.next() * 2.0 - 1.0) * 1.1
		canopy.push_back(Vector3(sin(a) * 1.0, 0.44 + cos(a) * 0.95, z + 0.05))
	_systems.push_back(_splash_system("CanopySplash", self, canopy, CANOPY_RATE))

	# Gunwales: a line of drips down each side.
	var sides := PackedVector3Array()
	for _i: int in 120:
		var side: float = -1.02 if rng.next() < 0.5 else 1.02
		sides.push_back(Vector3(side, 0.44, (rng.next() * 2.0 - 1.0) * 1.15))
	_systems.push_back(_drip_system("GunwaleDrip", self, sides, GUNWALE_RATE))

	if hat != null:
		var hat_top := PackedVector3Array()
		for _i: int in 120:
			var a: float = rng.next() * TAU
			var r: float = rng.next() * 0.4
			hat_top.push_back(Vector3(cos(a) * r, 0.17 - r * 0.45, sin(a) * r))
		_systems.push_back(_splash_system("HatSplash", hat, hat_top, HAT_SPLASH_RATE))

		var brim := PackedVector3Array()
		for _i: int in 120:
			var a: float = rng.next() * TAU
			brim.push_back(Vector3(cos(a) * 0.46, -0.05, sin(a) * 0.46))
		_systems.push_back(_drip_system("HatDrip", hat, brim, HAT_DRIP_RATE))


func _process(_delta: float) -> void:
	if environment_controller == null:
		return
	var rain: float = environment_controller.num("rain")
	for system: GPUParticles3D in _systems:
		system.emitting = rain > 0.01
		system.amount_ratio = clampf(rain, 0.0, 1.0)


## Drops kicked up off a surface: a spread of upward velocities falling back under gravity.
func _splash_system(
	name_hint: String, parent: Node3D, points: PackedVector3Array, rate: float
) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	_set_points(process, points)
	process.direction = Vector3.UP
	# Prototype: 0.6-1.5 up with up to 0.4 either way sideways.
	process.spread = 25.0
	process.initial_velocity_min = 0.7
	process.initial_velocity_max = 1.6
	process.gravity = Vector3(0.0, -9.8, 0.0)
	return _system(name_hint, parent, process, rate, SPLASH_LIFE)


## Water running off an edge: barely any initial speed, then gravity.
func _drip_system(
	name_hint: String, parent: Node3D, points: PackedVector3Array, rate: float
) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	_set_points(process, points)
	process.direction = Vector3.DOWN
	process.spread = 0.0
	process.initial_velocity_min = 0.3
	process.initial_velocity_max = 0.3
	process.gravity = Vector3(0.0, -9.8, 0.0)
	return _system(name_hint, parent, process, rate, DRIP_LIFE)


func _system(
	name_hint: String, parent: Node3D, process: ParticleProcessMaterial,
	rate: float, lifetime: float
) -> GPUParticles3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tint: Color = Color(DROP_COLOUR).srgb_to_linear()
	tint.a = 0.85
	material.albedo_color = tint

	var quad := QuadMesh.new()
	quad.size = Vector2(DROP_SIZE, DROP_SIZE)

	var particles := GPUParticles3D.new()
	particles.name = name_hint
	particles.draw_pass_1 = quad
	particles.material_override = material
	particles.process_material = process
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Rate is amount over lifetime, so this reproduces the prototype's spawns per second.
	particles.lifetime = lifetime
	particles.amount = maxi(1, int(ceil(rate * lifetime)))
	particles.preprocess = lifetime
	# Drops are left behind in the world rather than riding the boat.
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-6, -4, -8), Vector3(12, 10, 16))
	parent.add_child(particles)
	return particles


## Godot takes an emission point cloud as an RGBF texture, one pixel per point.
func _set_points(process: ParticleProcessMaterial, points: PackedVector3Array) -> void:
	var image := Image.create_empty(points.size(), 1, false, Image.FORMAT_RGBF)
	for i: int in points.size():
		image.set_pixel(i, 0, Color(points[i].x, points[i].y, points[i].z))
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	process.emission_point_count = points.size()
	process.emission_point_texture = ImageTexture.create_from_image(image)
