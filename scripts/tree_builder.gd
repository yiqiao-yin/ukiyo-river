## Cedar, black pine and cherry.
##
## Prototype: reference/ukiyo-river.html lines 912-1135. Each species is a branching bark tube
## plus a set of textured cards standing in for foliage. The cards carry authored normals -
## pointing out of the crown rather than out of the quad - and an ambient occlusion value in
## their vertex colour, which is what stops a flat quad reading as a flat quad.
##
## Every species takes a seed and drives its own mulberry32, so the variants are reproducible
## and independent of the world stream that scatters them.
class_name TreeBuilder
extends RefCounted


## GB.tube() - sweeps a ring along a polyline, carrying a parallel transport frame so the tube
## does not twist. `ao` is either a float or a Callable taking the centre point.
static func tube(
	buf: MeshUtil.Buffer, points: PackedVector3Array, radii: PackedFloat32Array,
	segments: int, v_scale: float, ao: Variant
) -> void:
	var count: int = points.size()
	if count < 2:
		return
	var rows: Array[PackedInt32Array] = []
	var length: float = 0.0
	var previous_normal := Vector3.ZERO
	var has_previous: bool = false

	for k: int in count:
		var t: Vector3 = (
			(points[k + 1] - points[k]) if k < count - 1 else (points[k] - points[k - 1])
		).normalized()
		if k > 0:
			length += points[k].distance_to(points[k - 1])
		var nr: Vector3
		if has_previous:
			# Parallel transport: project the last frame onto the new cross-section.
			nr = previous_normal - t * previous_normal.dot(t)
		else:
			var guess: Vector3 = Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT
			nr = guess.cross(t)
		nr = nr.normalized()
		previous_normal = nr
		has_previous = true
		var bn: Vector3 = t.cross(nr)

		var ring_ao: float = ao.call(points[k]) if ao is Callable else float(ao)
		var ids := PackedInt32Array()
		for s: int in segments + 1:
			var a: float = float(s) / float(segments) * TAU
			var d: Vector3 = nr * cos(a) + bn * sin(a)
			ids.push_back(buf.vert_shaded(
				points[k] + d * radii[k], d,
				Vector2(float(s) / float(segments), length * v_scale), ring_ao
			))
		rows.push_back(ids)

	for k: int in count - 1:
		for s: int in segments:
			# Wound outward. The prototype's own order faces into the tube, which its
			# single-sided trunk material would cull; noted in PORT_LOG.
			buf.quad(rows[k][s], rows[k][s + 1], rows[k + 1][s + 1], rows[k + 1][s])


## GB.card() - one textured quad. `anchored` puts the origin at the quad's near edge rather
## than its centre, which is how branches grow outward from the trunk.
static func card(
	buf: MeshUtil.Buffer, o: Vector3, ax: Vector3, ay: Vector3, w: float, h: float,
	normal_fn: Callable, ao_fn: Callable, anchored: bool
) -> void:
	var origin: Vector3 = o if anchored else o - ax * (w * 0.5)
	var corners: Array[Vector4] = [
		Vector4(0.0, -0.5, 0.0, 0.0), Vector4(1.0, -0.5, 1.0, 0.0),
		Vector4(1.0, 0.5, 1.0, 1.0), Vector4(0.0, 0.5, 0.0, 1.0),
	]
	var ids := PackedInt32Array()
	for q: Vector4 in corners:
		var p: Vector3 = origin + ax * (q.x * w) + ay * (q.y * h)
		ids.push_back(buf.vert_shaded(p, normal_fn.call(p), Vector2(q.z, q.w), ao_fn.call(p)))
	buf.quad(ids[0], ids[1], ids[2], ids[3])


## buildSugi(seed, far) - a cedar: a straight tapering trunk with whorls of flat sprays.
static func build_sugi(seed_value: int, far: bool) -> Dictionary:
	var r := UkiyoRng.new(seed_value)
	var trunk := MeshUtil.Buffer.new()
	var foliage := MeshUtil.Buffer.new()

	var height: float = 13.0 + r.next() * 3.0
	var bx: float = (r.next() - 0.5) * 0.6
	var bz: float = (r.next() - 0.5) * 0.6
	var axis := func(y: float) -> Vector3:
		var f: float = y / height
		return Vector3(bx * f * f, y, bz * f * f)

	var points := PackedVector3Array()
	var radii := PackedFloat32Array()
	for k: int in 9:
		var t: float = float(k) / 8.0
		points.push_back(axis.call(t * height))
		radii.push_back(lerpf(0.36, 0.04, pow(t, 0.8)))
	radii[0] = 0.58
	tube(trunk, points, radii, 5 if far else 9, 0.3,
		func(p: Vector3) -> float: return 0.55 + 0.45 * clampf(p.y / 4.0, 0.0, 1.0))

	var y0: float = height * 0.3
	var step: float = 1.35 if far else 0.85
	var y: float = y0
	while y < height - 0.3:
		var f: float = (y - y0) / (height - y0)
		var branch_length: float = (pow(1.0 - f, 0.85) * 2.9 + 0.4) * (0.85 + r.next() * 0.3)
		var branches: int = (3 if far else 4) + (1 if r.next() < 0.5 else 0)
		var a0: float = r.next() * 6.28
		var ap: Vector3 = axis.call(y)

		var normal_fn := func(p: Vector3) -> Vector3:
			var d := Vector3(p.x - ap.x, 0.0, p.z - ap.z)
			if d.length_squared() < 1e-4:
				return Vector3.UP
			return (d.normalized() + Vector3(0.0, 0.55, 0.0)).normalized()
		var ao_fn := func(p: Vector3) -> float:
			var radial: float = Vector2(p.x - ap.x, p.z - ap.z).length()
			return 0.42 + 0.58 * clampf(radial / branch_length, 0.0, 1.0) * (0.75 + 0.25 * f)

		for b: int in branches:
			var az: float = a0 + float(b) * 6.28 / float(branches) + (r.next() - 0.5) * 0.6
			var out := Vector3(cos(az), 0.0, sin(az))
			var side := Vector3(-sin(az), 0.0, cos(az))
			var ax: Vector3 = Vector3(out.x, -0.3 - r.next() * 0.3 + f * 0.45, out.z).normalized()
			var o: Vector3 = ap + ax * 0.05
			card(
				foliage, o, ax, (side + Vector3(0.0, 0.12, 0.0)).normalized(),
				branch_length * 1.05, branch_length * 0.62, normal_fn, ao_fn, true
			)
			if not far:
				var up: Vector3 = ax.cross(side).normalized()
				if up.y < 0.0:
					up = -up
				card(
					foliage, o, ax, up,
					branch_length * 0.95, branch_length * 0.48, normal_fn, ao_fn, true
				)
		y += step * (0.8 + r.next() * 0.4)

	# A crossed pair of cards closing the top off.
	var cap: Vector3 = axis.call(height - 0.2) + Vector3(0.0, -0.6, 0.0)
	var up_normal := func(_p: Vector3) -> Vector3: return Vector3.UP
	var full_ao := func(_p: Vector3) -> float: return 1.0
	card(foliage, cap, Vector3.UP, Vector3.RIGHT, 1.6, 0.7, up_normal, full_ao, true)
	card(foliage, cap, Vector3.UP, Vector3(0.0, 0.0, 1.0), 1.6, 0.7, up_normal, full_ao, true)

	return _finish(trunk, foliage)


## buildMatsu(seed) - a black pine: a leaning, kinked trunk with flat pads of needles.
static func build_matsu(seed_value: int) -> Dictionary:
	var r := UkiyoRng.new(seed_value)
	var trunk := MeshUtil.Buffer.new()
	var foliage := MeshUtil.Buffer.new()

	var height: float = 5.5 + r.next() * 2.5
	var lean: float = 0.35 + r.next() * 0.4
	var la: float = r.next() * 6.28
	var ld := Vector3(cos(la), 0.0, sin(la))

	var points := PackedVector3Array()
	var radii := PackedFloat32Array()
	for k: int in 11:
		var t: float = float(k) / 10.0
		var off: float = sin(t * 2.4) * lean * height * 0.35
		points.push_back(Vector3(
			ld.x * off + sin(t * 9.0 + la) * 0.08,
			t * height,
			ld.z * off + cos(t * 7.0 + la) * 0.08
		))
		radii.push_back(lerpf(0.3, 0.09, t))
	radii[0] = 0.45
	tube(trunk, points, radii, 8, 0.35, 0.8)

	# Each pad is a centre and a radius; the crown one sits on top of the trunk.
	var pads: Array[Vector4] = [
		_pad(points[10] + Vector3(0.0, 0.25, 0.0), 1.4 + r.next() * 0.5)
	]
	var branches: int = 3 + int(r.next() * 3.0)
	for _b: int in branches:
		var k: int = 4 + int(r.next() * 6.0)
		var s: Vector3 = points[k]
		var az: float = r.next() * 6.28
		var out := Vector3(cos(az), 0.0, sin(az))
		var length: float = 1.5 + r.next() * 1.8
		var branch_points := PackedVector3Array([s])
		for j: int in range(1, 5):
			var f: float = float(j) / 4.0
			branch_points.push_back(s + out * (length * f) + Vector3(
				(r.next() - 0.5) * 0.25,
				f * (0.25 + r.next() * 0.4) - sin(f * 3.0) * 0.15,
				(r.next() - 0.5) * 0.25
			))
		tube(trunk, branch_points, PackedFloat32Array([0.12, 0.09, 0.07, 0.05, 0.035]), 6, 0.5, 0.75)
		pads.push_back(_pad(branch_points[4] + Vector3(0.0, 0.12, 0.0), 0.85 + r.next() * 0.55))

	for pad: Vector4 in pads:
		var c := Vector3(pad.x, pad.y, pad.z)
		var radius: float = pad.w
		var normal_fn := func(p: Vector3) -> Vector3:
			return Vector3(p.x - c.x, (p.y - c.y) * 2.4 + radius * 0.35, p.z - c.z).normalized()
		var ao_fn := func(p: Vector3) -> float:
			return 0.5 + 0.5 * clampf((p.y - c.y) / (radius * 0.35) * 0.5 + 0.5, 0.0, 1.0)
		for j: int in 18:
			var a: float = r.next() * 6.28
			var d: float = sqrt(r.next()) * radius * 0.8
			var p: Vector3 = c + Vector3(
				cos(a) * d, (r.next() - 0.4) * radius * 0.3, sin(a) * d
			)
			var ya: float = r.next() * 6.28
			var hx := Vector3(cos(ya), 0.0, sin(ya))
			if j % 3 != 0:
				var hz := Vector3(-hx.z, (r.next() - 0.5) * 0.5, hx.x).normalized()
				hx.y = (r.next() - 0.5) * 0.4
				hx = hx.normalized()
				card(foliage, p, hx, hz, radius * 1.05, radius * 0.95, normal_fn, ao_fn, false)
			else:
				card(foliage, p, hx, Vector3.UP, radius * 1.0, radius * 0.55, normal_fn, ao_fn, false)

	return _finish(trunk, foliage)


## buildSakura(seed) - a cherry: a recursively branching frame hung with blossom clusters.
static func build_sakura(seed_value: int) -> Dictionary:
	var r := UkiyoRng.new(seed_value)
	var trunk := MeshUtil.Buffer.new()
	var foliage := MeshUtil.Buffer.new()
	## Each entry is (position, card count, card size).
	var clusters: Array = []

	_branch(
		trunk, clusters, r, Vector3.ZERO,
		Vector3((r.next() - 0.5) * 0.25, 1.0, (r.next() - 0.5) * 0.25).normalized(),
		1.6 + r.next() * 0.4, 0.3, 0
	)

	var centre := Vector3.ZERO
	for cluster: Array in clusters:
		centre += cluster[0] as Vector3
	centre /= float(clusters.size())
	var crown_radius: float = 0.0
	for cluster: Array in clusters:
		crown_radius = maxf(crown_radius, (cluster[0] as Vector3).distance_to(centre))
	crown_radius = maxf(crown_radius, 0.001)

	var normal_fn := func(p: Vector3) -> Vector3:
		return (p - centre + Vector3(0.0, 0.6, 0.0)).normalized()
	var ao_fn := func(p: Vector3) -> float:
		return 0.55 + 0.45 * clampf(p.distance_to(centre) / crown_radius, 0.0, 1.0)

	for cluster: Array in clusters:
		var c: Vector3 = cluster[0]
		var n: int = cluster[1]
		var size: float = cluster[2]
		for _j: int in n:
			var ax := Vector3(
				r.next() - 0.5, (r.next() - 0.5) * 0.6, r.next() - 0.5
			).normalized()
			var tmp := Vector3(r.next() - 0.5, r.next() - 0.5, r.next() - 0.5)
			var ay: Vector3 = ax.cross(tmp).normalized()
			var p: Vector3 = c + Vector3(
				(r.next() - 0.5) * 0.4, (r.next() - 0.3) * 0.3, (r.next() - 0.5) * 0.4
			)
			card(
				foliage, p, ax, ay,
				size * (0.85 + r.next() * 0.3), size * (0.85 + r.next() * 0.3),
				normal_fn, ao_fn, false
			)

	return _finish(trunk, foliage)


static func _branch(
	trunk: MeshUtil.Buffer, clusters: Array, r: UkiyoRng,
	start: Vector3, direction: Vector3, length: float, radius: float, depth: int
) -> void:
	var points := PackedVector3Array([start])
	var radii := PackedFloat32Array([radius])
	var p: Vector3 = start
	var d: Vector3 = direction
	for k: int in range(1, 5):
		d = (d + Vector3(
			(r.next() - 0.5) * 0.4, (r.next() - 0.5) * 0.15 + 0.03, (r.next() - 0.5) * 0.4
		)).normalized()
		p = p + d * (length / 4.0)
		points.push_back(p)
		radii.push_back(lerpf(radius, radius * 0.6, float(k) / 4.0))
	var segments: int = 9 if depth == 0 else (7 if depth == 1 else 5)
	tube(trunk, points, radii, segments, 0.6, 0.7 if depth == 0 else 0.85)

	if depth < 2:
		for _c: int in 3:
			var rv := Vector3(r.next() - 0.5, r.next() - 0.5, r.next() - 0.5)
			var perp: Vector3 = d.cross(rv).normalized()
			var angle: float = 0.8 + r.next() * 0.45
			var nd: Vector3 = d * cos(angle) + perp * sin(angle)
			nd.y += 0.06
			nd = nd.normalized()
			_branch(
				trunk, clusters, r, p, nd,
				length * (0.72 if depth > 0 else 0.95), radius * 0.58, depth + 1
			)
		if depth == 1:
			clusters.push_back([p, 4, 1.6])
	else:
		clusters.push_back([p, 5, 2.0])
		clusters.push_back([points[2], 3, 1.5])


static func _pad(centre: Vector3, radius: float) -> Vector4:
	return Vector4(centre.x, centre.y, centre.z, radius)


static func _finish(trunk: MeshUtil.Buffer, foliage: MeshUtil.Buffer) -> Dictionary:
	var trunk_mesh := ArrayMesh.new()
	trunk.commit(trunk_mesh)
	var foliage_mesh := ArrayMesh.new()
	foliage.commit(foliage_mesh)
	return {"trunk": trunk_mesh, "foliage": foliage_mesh}
