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
	## Filled only by vert_shaded. When present these are used instead of computing normals
	## from the winding, which the trees need: their foliage is flat cards standing in for a
	## canopy, so the normals have to point out of the crown rather than out of the quad.
	var normals := PackedVector3Array()
	var colors := PackedColorArray()

	func vert(p: Vector3, uv: Vector2 = Vector2.ZERO) -> int:
		vertices.push_back(p)
		uvs.push_back(uv)
		return vertices.size() - 1

	## A vertex carrying its own normal and an ambient occlusion value in the colour channel -
	## the prototype's GB.vert().
	func vert_shaded(p: Vector3, normal: Vector3, uv: Vector2, ao: float) -> int:
		vertices.push_back(p)
		uvs.push_back(uv)
		normals.push_back(normal)
		colors.push_back(Color(ao, ao, ao, 1.0))
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
		if normals.size() == vertices.size():
			arrays[Mesh.ARRAY_NORMAL] = normals
		else:
			arrays[Mesh.ARRAY_NORMAL] = MeshUtil.compute_normals(vertices, indices)
		if colors.size() == vertices.size():
			arrays[Mesh.ARRAY_COLOR] = colors
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

	buf.skin(
		buf.ring(a, right, up, r_a, segments, 0.0),
		buf.ring(b, right, up, r_b, segments, 1.0)
	)
	# The caps get their own copy of each ring. Sharing the wall's vertices would average the
	# cap normal into the wall normal and round off what should be a hard rim, which is not what
	# three.js CylinderGeometry does.
	if r_a > 1e-6:
		buf.cap(buf.ring(a, right, up, r_a, segments, 0.0), a, -axis, axis)
	if r_b > 1e-6:
		buf.cap(buf.ring(b, right, up, r_b, segments, 1.0), b, axis, axis)


## Revolves a profile of (radius, height) pairs around the Y axis - three.js LatheGeometry.
## `phi_length` under a full turn leaves the shape open, which is how the straw cape is built.
static func add_lathe(
	buf: Buffer, profile: PackedVector2Array, segments: int,
	phi_start: float = 0.0, phi_length: float = TAU
) -> void:
	var closed: bool = is_equal_approx(phi_length, TAU)
	var count: int = segments if closed else segments + 1
	var rows: Array[PackedInt32Array] = []
	for point: Vector2 in profile:
		var ids := PackedInt32Array()
		for s: int in count:
			var a: float = phi_start + phi_length * float(s) / float(segments)
			ids.push_back(buf.vert(
				Vector3(cos(a) * point.x, point.y, sin(a) * point.x),
				Vector2(float(s) / float(segments), point.y)
			))
		rows.push_back(ids)
	for i: int in rows.size() - 1:
		if closed:
			buf.skin(rows[i + 1], rows[i])
		else:
			for s: int in segments:
				buf.quad(rows[i + 1][s], rows[i + 1][s + 1], rows[i][s + 1], rows[i][s])


## A torus in the XY plane - three.js TorusGeometry.
static func add_torus(
	buf: Buffer, centre: Vector3, radius: float, tube: float,
	tube_segments: int, arc_segments: int, arc: float = TAU,
	basis: Basis = Basis.IDENTITY
) -> void:
	var closed: bool = is_equal_approx(arc, TAU)
	var count: int = arc_segments if closed else arc_segments + 1
	var rows: Array[PackedInt32Array] = []
	for i: int in count:
		var u: float = arc * float(i) / float(arc_segments)
		var ring_centre := Vector3(cos(u) * radius, sin(u) * radius, 0.0)
		var outward := Vector3(cos(u), sin(u), 0.0)
		var ids := PackedInt32Array()
		for j: int in tube_segments:
			var v: float = TAU * float(j) / float(tube_segments)
			ids.push_back(buf.vert(
				centre + basis * (
					ring_centre + outward * (cos(v) * tube) + Vector3(0.0, 0.0, sin(v) * tube)
				),
				Vector2(float(i) / float(arc_segments), float(j) / float(tube_segments))
			))
		rows.push_back(ids)
	for i: int in (count if closed else count - 1):
		buf.skin(rows[(i + 1) % count], rows[i])


## A box centred on `centre` - three.js BoxGeometry.
##
## Each face gets its own four vertices. Sharing the eight corners would average three face
## normals at every corner and shade the box like a rounded blob; BoxGeometry has per-face
## normals, and almost every building in this project is a box.
static func add_box(
	buf: Buffer, centre: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY
) -> void:
	var h: Vector3 = size * 0.5
	# Per face: the outward axis, then the two in-plane axes spanning it.
	var faces: Array[Array] = [
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
		[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	]
	for face: Array in faces:
		var out: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		var origin: Vector3 = out * h
		var du: Vector3 = u * h
		var dv: Vector3 = v * h
		var a: int = buf.vert(centre + basis * (origin - du - dv), Vector2(0, 0))
		var b: int = buf.vert(centre + basis * (origin + du - dv), Vector2(1, 0))
		var c: int = buf.vert(centre + basis * (origin + du + dv), Vector2(1, 1))
		var d: int = buf.vert(centre + basis * (origin - du + dv), Vector2(0, 1))
		buf.quad(a, b, c, d)


## The prototype's roofGeo: ConeGeometry(1, 1, 4) turned 45 degrees, so a square pyramid whose
## base corners sit on the diagonals, flat shaded.
##
## `size` is the scale the prototype applies to the mesh, not the width of the base: the cone has
## radius 1, so after scaling the corners land at 0.707*size from the centre and the base is
## 1.414*size across. That overhang is what gives the roofs their eaves.
static func add_pyramid(
	buf: Buffer, centre: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY
) -> void:
	var apex: Vector3 = centre + basis * Vector3(0, size.y * 0.5, 0)
	var corners: Array[Vector3] = []
	for i: int in 4:
		var angle: float = PI * 0.25 + TAU * float(i) / 4.0
		corners.push_back(centre + basis * Vector3(
			cos(angle) * size.x, -size.y * 0.5, sin(angle) * size.z
		))
	for i: int in 4:
		var p0: Vector3 = corners[i]
		var p1: Vector3 = corners[(i + 1) % 4]
		buf.tri(
			buf.vert(apex, Vector2(0.5, 1)),
			buf.vert(p1, Vector2(1, 0)),
			buf.vert(p0, Vector2(0, 0))
		)
	# Base, so the roof is not hollow when seen from below.
	var b0: int = buf.vert(corners[0], Vector2(0, 0))
	var b1: int = buf.vert(corners[1], Vector2(1, 0))
	var b2: int = buf.vert(corners[2], Vector2(1, 1))
	var b3: int = buf.vert(corners[3], Vector2(0, 1))
	buf.quad(b3, b2, b1, b0)


## A UV sphere - three.js SphereGeometry.
static func add_sphere(
	buf: Buffer, centre: Vector3, radius: float, segments: int, rings: int,
	scale: Vector3 = Vector3.ONE
) -> void:
	var rows: Array[PackedInt32Array] = []
	for r: int in rings + 1:
		var phi: float = PI * float(r) / float(rings)
		var y: float = cos(phi) * radius
		var ring_radius: float = sin(phi) * radius
		var ids := PackedInt32Array()
		for sgm: int in segments + 1:
			var theta: float = TAU * float(sgm) / float(segments)
			ids.push_back(buf.vert(
				centre + Vector3(cos(theta) * ring_radius, y, sin(theta) * ring_radius) * scale,
				Vector2(float(sgm) / float(segments), float(r) / float(rings))
			))
		rows.push_back(ids)
	for r: int in rings:
		for sgm: int in segments:
			buf.quad(rows[r][sgm], rows[r][sgm + 1], rows[r + 1][sgm + 1], rows[r + 1][sgm])


## The prototype's bendBox: a bar swept along X whose ends rise by t*t*curve.
static func add_bent_bar(
	buf: Buffer, centre: Vector3, size: Vector3, curve: float, basis: Basis = Basis.IDENTITY
) -> void:
	var steps: int = 12
	var half: Vector3 = size * 0.5
	var rows: Array[PackedInt32Array] = []
	for i: int in steps + 1:
		var t: float = -1.0 + 2.0 * float(i) / float(steps)
		var x: float = t * half.x
		var lift: float = t * t * curve
		var ids := PackedInt32Array()
		# Cross-section corners, counter-clockwise looking back down +X.
		for corner: Vector2 in [
			Vector2(-half.y, -half.z), Vector2(half.y, -half.z),
			Vector2(half.y, half.z), Vector2(-half.y, half.z),
		]:
			ids.push_back(buf.vert(
				centre + basis * Vector3(x, corner.x + lift, corner.y),
				Vector2(float(i) / float(steps), 0.0)
			))
		rows.push_back(ids)
	for i: int in steps:
		for c: int in 4:
			var n: int = (c + 1) % 4
			buf.quad(rows[i][c], rows[i][n], rows[i + 1][n], rows[i + 1][c])
	buf.quad(rows[0][3], rows[0][2], rows[0][1], rows[0][0])
	var last: int = rows.size() - 1
	buf.quad(rows[last][0], rows[last][1], rows[last][2], rows[last][3])


## Copies `source` into `target`, transformed. The prototype's bakeStatic() does the same job:
## build each object in its own space, then merge everything sharing a material.
static func append_transformed(target: Buffer, source: Buffer, xform: Transform3D) -> void:
	var base: int = target.vertices.size()
	for i: int in source.vertices.size():
		target.vert(xform * source.vertices[i], source.uvs[i])
	for index: int in source.indices:
		target.indices.push_back(base + index)


## Any unit vector perpendicular to `axis`.
static func _perpendicular(axis: Vector3) -> Vector3:
	var guess: Vector3 = Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT
	return guess.cross(axis).normalized()
