## Geometry helpers shared by everything that builds a mesh in script.
##
## Godot winds front faces clockwise; three.js winds them counter-clockwise. Rather than flip
## triangle order at each call site, every builder here takes corners in the prototype's
## counter-clockwise-as-seen-from-outside order and the Buffer class emits them reversed.
class_name MeshUtil
extends RefCounted


## Area-weighted vertex normals, matching three.js computeVertexNormals() under Godot's winding.
static func compute_normals(
	vertices: PackedVector3Array, indices: PackedInt32Array
) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.ZERO)

	var i: int = 0
	while i < indices.size():
		var ia: int = indices[i]
		var ib: int = indices[i + 1]
		var ic: int = indices[i + 2]
		var face: Vector3 = (vertices[ia] - vertices[ib]).cross(vertices[ic] - vertices[ib])
		normals[ia] += face
		normals[ib] += face
		normals[ic] += face
		i += 3

	for k: int in normals.size():
		var n: Vector3 = normals[k]
		normals[k] = n.normalized() if n.length_squared() > 0.0 else Vector3.UP
	return normals


## Accumulates vertices and triangles for one material, then bakes an ArrayMesh surface.
class Buffer:
	extends RefCounted

	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	func vert(p: Vector3, uv: Vector2 = Vector2.ZERO) -> int:
		vertices.push_back(p)
		uvs.push_back(uv)
		return vertices.size() - 1

	## Corners counter-clockwise as seen from outside, the prototype's order.
	func quad(a: int, b: int, c: int, d: int) -> void:
		tri(a, b, c)
		tri(a, c, d)

	## Corners counter-clockwise as seen from outside; emitted reversed for Godot.
	func tri(a: int, b: int, c: int) -> void:
		indices.push_back(a)
		indices.push_back(c)
		indices.push_back(b)

	func is_empty() -> bool:
		return indices.is_empty()

	## Adds this buffer to `mesh` as one surface and returns its index, or -1 if empty.
	func commit(mesh: ArrayMesh) -> int:
		if is_empty():
			return -1
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = MeshUtil.compute_normals(vertices, indices)
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh.get_surface_count() - 1

	## A ring of `segments` vertices around `centre`, in the plane spanned by `right` and `up`.
	## Returns the vertex ids, ordered so that quads built with the next ring face outward.
	func ring(centre: Vector3, right: Vector3, up: Vector3, radius: float, segments: int,
			v: float) -> PackedInt32Array:
		var ids := PackedInt32Array()
		for s: int in segments:
			var a: float = TAU * float(s) / float(segments)
			var dir: Vector3 = right * cos(a) + up * sin(a)
			ids.push_back(vert(centre + dir * radius, Vector2(float(s) / float(segments), v)))
		return ids

	## Skins two rings of equal length into a tube wall.
	func skin(lower: PackedInt32Array, upper: PackedInt32Array) -> void:
		var n: int = lower.size()
		for s: int in n:
			var t: int = (s + 1) % n
			quad(lower[s], lower[t], upper[t], upper[s])

	## Triangle fan closing an arbitrary ring, oriented to face `outward`.
	##
	## Unlike cap(), this makes no assumption about how the ring was wound: it sums the fan's
	## face normals and flips the whole thing if the result disagrees with `outward`. The hull
	## needs this because its section loop runs the outer shell one way and the inner shell back
	## the other, and the prototype emits both end caps with identical winding - which leaves one
	## of them facing into the boat.
	func cap_fan(ids: PackedInt32Array, centre: Vector3, outward: Vector3) -> void:
		var n: int = ids.size()
		if n < 3:
			return
		var normal := Vector3.ZERO
		for s: int in n:
			var t: int = (s + 1) % n
			normal += (vertices[ids[s]] - centre).cross(vertices[ids[t]] - centre)
		var flip: bool = normal.dot(outward) < 0.0
		var c: int = vert(centre, Vector2(0.5, 0.5))
		for s: int in n:
			var t: int = (s + 1) % n
			if flip:
				tri(c, ids[t], ids[s])
			else:
				tri(c, ids[s], ids[t])

	## Triangle fan closing a ring, with the normal pointing along `outward`.
	func cap(ids: PackedInt32Array, centre: Vector3, outward: Vector3, axis: Vector3) -> void:
		var c: int = vert(centre, Vector2(0.5, 0.5))
		var n: int = ids.size()
		var flip: bool = outward.dot(axis) < 0.0
		for s: int in n:
			var t: int = (s + 1) % n
			if flip:
				tri(c, ids[t], ids[s])
			else:
				tri(c, ids[s], ids[t])


## A capped cone from `a` (radius `r_a`) to `b` (radius `r_b`) - the prototype's limb()/cylinder.
static func add_cone(
	buf: Buffer, a: Vector3, b: Vector3, r_a: float, r_b: float, segments: int
) -> void:
	var axis: Vector3 = b - a
	var length: float = axis.length()
	if length < 1e-6:
		return
	axis /= length
	var right: Vector3 = _perpendicular(axis)
	var up: Vector3 = axis.cross(right).normalized()

	var lower: PackedInt32Array = buf.ring(a, right, up, r_a, segments, 0.0)
	var upper: PackedInt32Array = buf.ring(b, right, up, r_b, segments, 1.0)
	buf.skin(lower, upper)
	if r_a > 1e-6:
		buf.cap(lower, a, -axis, axis)
	if r_b > 1e-6:
		buf.cap(upper, b, axis, axis)


## Revolves a profile of (radius, height) pairs around the Y axis - three.js LatheGeometry.
static func add_lathe(buf: Buffer, profile: PackedVector2Array, segments: int) -> void:
	var rows: Array[PackedInt32Array] = []
	for point: Vector2 in profile:
		var ids := PackedInt32Array()
		for s: int in segments:
			var a: float = TAU * float(s) / float(segments)
			ids.push_back(buf.vert(
				Vector3(cos(a) * point.x, point.y, sin(a) * point.x),
				Vector2(float(s) / float(segments), point.y)
			))
		rows.push_back(ids)
	for i: int in rows.size() - 1:
		buf.skin(rows[i + 1], rows[i])


## An axis-aligned box centred on `centre` - three.js BoxGeometry.
static func add_box(buf: Buffer, centre: Vector3, size: Vector3) -> void:
	var h: Vector3 = size * 0.5
	var v: PackedInt32Array = PackedInt32Array()
	for sz: int in [-1, 1]:
		for sy: int in [-1, 1]:
			for sx: int in [-1, 1]:
				v.push_back(buf.vert(centre + Vector3(h.x * float(sx), h.y * float(sy), h.z * float(sz))))
	# Vertex order is (x fastest, then y, then z): 0..3 are the -z face, 4..7 the +z face.
	buf.quad(v[4], v[5], v[7], v[6])  # +z
	buf.quad(v[1], v[0], v[2], v[3])  # -z
	buf.quad(v[2], v[6], v[7], v[3])  # +y
	buf.quad(v[0], v[1], v[5], v[4])  # -y
	buf.quad(v[5], v[1], v[3], v[7])  # +x
	buf.quad(v[0], v[4], v[6], v[2])  # -x


## Any unit vector perpendicular to `axis`.
static func _perpendicular(axis: Vector3) -> Vector3:
	var guess: Vector3 = Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT
	return guess.cross(axis).normalized()
