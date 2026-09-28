## Valley floor, banks and mountains.
##
## Prototype: reference/ukiyo-river.html lines 223-242 - a 900 m PlaneGeometry with 230x230
## segments displaced by terrainH() and tinted per vertex from five base colours.
extends MeshInstance3D

## Prototype TS: the terrain is a square this many metres on a side, centred on the origin.
const SIZE: float = 900.0

## Prototype TSEG (desktop branch).
const SEGMENTS: int = 230

# Prototype vertex colours. Written as hex here and converted to linear on load: three.js r128
# wrote these straight to the framebuffer, Godot converts linear to sRGB on output, so the hex
# has to be un-converted going in for the same pixel to come out.
const C_GRASS_1: Color = Color("#223020")
const C_GRASS_2: Color = Color("#34422a")
const C_MUD: Color = Color("#2c2821")
const C_ROCK: Color = Color("#4a4944")
const C_HIGH: Color = Color("#2b3530")


func _ready() -> void:
	mesh = _build()
	material_override = _make_material()


func _build() -> ArrayMesh:
	var verts_per_side: int = SEGMENTS + 1
	var vertex_count: int = verts_per_side * verts_per_side

	var vertices := PackedVector3Array()
	vertices.resize(vertex_count)
	var colors := PackedColorArray()
	colors.resize(vertex_count)
	var indices := PackedInt32Array()
	indices.resize(SEGMENTS * SEGMENTS * 6)

	var step: float = SIZE / float(SEGMENTS)
	var half: float = SIZE * 0.5

	for iz: int in verts_per_side:
		var z: float = -half + float(iz) * step
		var row: int = iz * verts_per_side
		for ix: int in verts_per_side:
			var x: float = -half + float(ix) * step
			vertices[row + ix] = Vector3(x, UkiyoMath.terrain_h(x, z), z)

	var n: int = 0
	for iz: int in SEGMENTS:
		for ix: int in SEGMENTS:
			var a: int = iz * verts_per_side + ix
			var b: int = a + 1
			var c: int = a + verts_per_side
			var d: int = c + 1
			# Godot front faces wind clockwise (the reverse of three.js), so these are the
			# prototype's two triangles with their order flipped.
			indices[n] = a
			indices[n + 1] = b
			indices[n + 2] = c
			indices[n + 3] = b
			indices[n + 4] = d
			indices[n + 5] = c
			n += 6

	var normals: PackedVector3Array = MeshUtil.compute_normals(vertices, indices)

	for i: int in vertex_count:
		colors[i] = _vertex_color(vertices[i], normals[i].y)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return array_mesh


## Prototype's per-vertex blend: grass noise, then height, then slope, then mud at the waterline.
func _vertex_color(v: Vector3, normal_y: float) -> Color:
	var c: Color = C_GRASS_1.lerp(C_GRASS_2, UkiyoMath.vnoise(v.x * 0.08, v.z * 0.08))
	c = c.lerp(C_HIGH, UkiyoMath.smooth(25.0, 70.0, v.y))
	c = c.lerp(C_ROCK, 1.0 - UkiyoMath.smooth(0.62, 0.86, normal_y))
	c = c.lerp(C_MUD, 1.0 - UkiyoMath.smooth(-0.4, 1.4, v.y))
	return c.srgb_to_linear()


func _make_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	# MeshLambertMaterial has no specular term.
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat
