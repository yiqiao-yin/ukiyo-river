## Scatters the forest and instances it.
##
## Prototype: reference/ukiyo-river.html lines 1137-1169. Up to 2300 trees are rejection-sampled
## along both banks, sorted into cherry, pine, near cedar and far cedar by how far from the water
## they landed, then instanced per species variant.
##
## Draws from the shared world stream last, after the villages and the floating lanterns. The
## rejection loop is the delicate part: an iteration that fails the distance, height or exclusion
## test consumes three numbers and stops, while one that succeeds consumes six. Getting that
## wrong shifts the whole forest.
class_name Trees
extends Node3D

## Prototype: at most this many trees from at most this many attempts.
const MAX_TREES: int = 2300
const MAX_ATTEMPTS: int = 9000

## Prototype: trees live between here and 126 m from the centre line, biased toward the water.
const NEAR_BANK: float = UkiyoMath.RIVER_HALF + 6.0
const SPREAD: float = 120.0

## Prototype: nothing below this height, nothing past the edge of the terrain.
const MIN_HEIGHT: float = 0.6
const MAX_ABS_X: float = 440.0

@export var environment_controller: EnvironmentController
@export var world_rng: WorldRng
@export var architecture: Architecture

## The four scatter lists, kept after building. scripts/tools/world_check.gd compares them
## against the prototype: they come off the tail of the shared random stream, so they only
## match if every draw before them did too.
var placements: Dictionary = {}

var _shaders: Array[ShaderMaterial] = []


func _ready() -> void:
	var rng: UkiyoRng = world_rng.rng
	var cherry: Array[Array] = []
	var pine: Array[Array] = []
	var cedar_near: Array[Array] = []
	var cedar_far: Array[Array] = []

	var placed: int = 0
	for _i: int in MAX_ATTEMPTS:
		if placed >= MAX_TREES:
			break
		var z: float = (rng.next() * 2.0 - 1.0) * 430.0
		var side: float = -1.0 if rng.next() < 0.5 else 1.0
		var d: float = NEAR_BANK + pow(rng.next(), 1.5) * SPREAD
		var x: float = UkiyoMath.river_x(z) + side * d
		if absf(x) > MAX_ABS_X:
			continue
		var h: float = UkiyoMath.terrain_h(x, z)
		if h < MIN_HEIGHT or architecture.blocked(x, z):
			continue
		var roll: float = rng.next()
		# The last two draws are the instance's yaw and its size, kept with it.
		var item: Array = [x, h, z, rng.next(), rng.next()]
		placed += 1
		if d < 48.0 and roll < 0.16:
			cherry.push_back(item)
		elif d < 42.0 and roll < 0.45:
			pine.push_back(item)
		elif d < 70.0:
			cedar_near.push_back(item)
		else:
			cedar_far.push_back(item)

	placements = {
		"cedar_near": cedar_near, "cedar_far": cedar_far, "pine": pine, "cherry": cherry,
	}

	var textures: Dictionary = _load_textures()
	_place(
		cedar_near, [TreeBuilder.build_sugi(101, false), TreeBuilder.build_sugi(202, false),
			TreeBuilder.build_sugi(303, false)],
		textures, "sugi", 15.0, 1.0, Vector2(0.75, 1.2), Color.WHITE
	)
	_place(
		cedar_far, [TreeBuilder.build_sugi(404, true), TreeBuilder.build_sugi(505, true)],
		textures, "sugi", 15.0, 1.0, Vector2(0.8, 1.3), Color("#e8efe6")
	)
	_place(
		pine, [TreeBuilder.build_matsu(11), TreeBuilder.build_matsu(22),
			TreeBuilder.build_matsu(33)],
		textures, "pine", 7.0, 0.8, Vector2(0.85, 1.25), Color.WHITE
	)
	_place(
		cherry, [TreeBuilder.build_sakura(7), TreeBuilder.build_sakura(8),
			TreeBuilder.build_sakura(9)],
		textures, "sakura", 6.0, 1.4, Vector2(1.0, 1.4), Color.WHITE
	)

	print("[trees] %d cedar near, %d cedar far, %d pine, %d cherry" % [
		cedar_near.size(), cedar_far.size(), pine.size(), cherry.size(),
	])


func _process(_delta: float) -> void:
	if environment_controller == null:
		return
	var t: float = environment_controller.elapsed
	var wind: float = environment_controller.num("wind")
	for material: ShaderMaterial in _shaders:
		material.set_shader_parameter("u_time", t)
		material.set_shader_parameter("u_wind", wind)


## Splits the placements round robin across the variants and builds one multimesh pair each.
func _place(
	items: Array[Array], variants: Array, textures: Dictionary, species: String,
	sway_height: float, flutter: float, scale_range: Vector2, tint: Color
) -> void:
	if items.is_empty():
		return
	var buckets: Array[Array] = []
	for _v: int in variants.size():
		buckets.push_back([])
	for i: int in items.size():
		buckets[i % variants.size()].push_back(items[i])

	for vi: int in variants.size():
		var bucket: Array = buckets[vi]
		if bucket.is_empty():
			continue
		var variant: Dictionary = variants[vi]
		var trunk := _multimesh(variant["trunk"] as ArrayMesh, bucket.size(), false)
		var foliage := _multimesh(variant["foliage"] as ArrayMesh, bucket.size(), true)

		for i: int in bucket.size():
			var item: Array = bucket[i]
			var yaw: float = float(item[3]) * 6.28
			var scale: float = scale_range.x + float(item[4]) * (scale_range.y - scale_range.x)
			# Prototype sinks each tree 0.25 m so the flare of the trunk meets the ground.
			var xform := Transform3D(
				Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale),
				Vector3(float(item[0]), float(item[1]) - 0.25, float(item[2]))
			)
			trunk.multimesh.set_instance_transform(i, xform)
			foliage.multimesh.set_instance_transform(i, xform)
			# Prototype varies each tree's foliage tint with its yaw draw.
			foliage.multimesh.set_instance_color(i, tint * (0.82 + float(item[3]) * 0.3))

		trunk.material_override = _trunk_material(textures, species, sway_height)
		foliage.material_override = _foliage_material(textures, species, sway_height, flutter)
		add_child(trunk)
		add_child(foliage)


func _multimesh(mesh: ArrayMesh, count: int, use_colors: bool) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = use_colors
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	# The trees are scattered over the whole valley, so let each batch be drawn wherever it is
	# rather than culled against a bounding box that spans everything anyway.
	instance.custom_aabb = AABB(Vector3(-450, -10, -450), Vector3(900, 60, 900))
	return instance


func _trunk_material(textures: Dictionary, species: String, height: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/trunk.gdshader")
	material.set_shader_parameter("u_bark", textures[species + "_bark"])
	material.set_shader_parameter("u_bark_normal", textures[species + "_bump"])
	material.set_shader_parameter("u_height", height)
	material.set_shader_parameter("u_flutter", 0.0)
	_shaders.push_back(material)
	return material


func _foliage_material(
	textures: Dictionary, species: String, height: float, flutter: float
) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/foliage.gdshader")
	material.set_shader_parameter("u_foliage", textures[species + "_leaf"])
	material.set_shader_parameter("u_height", height)
	material.set_shader_parameter("u_flutter", flutter)
	_shaders.push_back(material)
	return material


## Loaded from assets/generated, written once by scripts/tools/generate_textures.gd.
func _load_textures() -> Dictionary:
	return {
		"sugi_bark": load("res://assets/generated/bark_sugi.png"),
		"sugi_bump": load("res://assets/generated/bark_sugi_bump.png"),
		"sugi_leaf": load("res://assets/generated/foliage_cedar.png"),
		"pine_bark": load("res://assets/generated/bark_pine.png"),
		"pine_bump": load("res://assets/generated/bark_pine_bump.png"),
		"pine_leaf": load("res://assets/generated/foliage_pine.png"),
		"sakura_bark": load("res://assets/generated/bark_sakura.png"),
		"sakura_bump": load("res://assets/generated/bark_sakura_bump.png"),
		"sakura_leaf": load("res://assets/generated/foliage_blossom.png"),
	}
