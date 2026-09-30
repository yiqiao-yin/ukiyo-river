## Builds the covered river boat, ported from reference/ukiyo-river.html lines 656-741.
##
## The hull is the prototype's lofted surface: sec() gives a cross-section at each station along
## the length, profilePt() traces the section outline, and the two are swept into an outer shell,
## an inner shell 6 cm inboard and two end caps. Rails, deck, thwarts, transom, canopy, mast and
## lantern follow the prototype's numbers exactly.
##
## The boat's own axes are the prototype's: +Z is forward, the hull runs from the stern at
## t = 0 to the bow at t = 1.
class_name BoatBuilder
extends RefCounted

## Prototype HL - hull length in metres.
const HULL_LENGTH: float = 8.2

## Prototype buildHull(): NS stations along the length, NP points around half a section.
const STATIONS: int = 64
const PROFILE_POINTS: int = 20

## Prototype LANTERN_POS.
const LANTERN_POS: Vector3 = Vector3(0.0, 2.32, 3.55)

## Where the boatman's eye sits, so the Boatman camera has somewhere to be before Phase 7 builds
## him: bm(0, -0.1, -3.0) + upper(0, 0.86, 0) + head(0, 0.72, 0.01) + the prototype's
## localToWorld(0, 0.07, 0.11) eye offset.
const EYE_POS: Vector3 = Vector3(0.0, 1.55, -2.88)

## Material keys, one surface each. Shared with the boatman through BoatMaterials.
const MAT_HULL: String = BoatMaterials.HULL
const MAT_DECK: String = BoatMaterials.DECK
const MAT_DARK: String = BoatMaterials.DARK
const MAT_CANOPY: String = BoatMaterials.CANOPY
const MAT_BAMBOO: String = BoatMaterials.BAMBOO
const MAT_CORD: String = BoatMaterials.CORD
const MAT_PAPER: String = BoatMaterials.PAPER


## sec(t) -> (b: half width, k: keel height, s: sheer height, z: station position).
static func sec(t: float) -> Vector4:
	var bow: float = UkiyoMath.smooth(0.55, 1.0, t)
	var stern: float = 1.0 - UkiyoMath.smooth(0.0, 0.18, t)
	return Vector4(
		1.05 * (1.0 - pow(bow, 1.8) * 0.97) * (1.0 - stern * 0.35),
		-0.22 + bow * bow * 0.45 + stern * 0.08,
		0.42 + pow(bow, 2.2) * 0.75 + stern * 0.12,
		(t - 0.5) * HULL_LENGTH + pow(bow, 3.0) * 0.25
	)


## profilePt(b, k, s, th) -> a point on the section outline, th sweeping 0 (starboard sheer)
## through PI/2 (keel) to PI (port sheer).
static func profile_pt(b: float, k: float, s: float, th: float) -> Vector2:
	var c: float = cos(th)
	var y: float = s - (s - k) * pow(absf(sin(th)), 0.25)
	# Prototype: (s - k || 1) - guard the degenerate section.
	var span: float = s - k
	if is_zero_approx(span):
		span = 1.0
	var x: float = b * signf(c) * pow(absf(c), 0.4) * lerpf(0.8, 1.0, (y - k) / span)
	return Vector2(x, y)


## Returns {material key: ArrayMesh} for the whole boat.
static func build() -> Dictionary:
	var buffers: Dictionary = {}
	for key: String in [
		MAT_HULL, MAT_DECK, MAT_DARK, MAT_CANOPY, MAT_BAMBOO, MAT_CORD, MAT_PAPER,
	]:
		buffers[key] = MeshUtil.Buffer.new()

	_build_hull(buffers[MAT_HULL])
	_build_rails(buffers[MAT_DARK])
	_build_deck(buffers[MAT_DECK], buffers[MAT_DARK])
	_build_canopy(buffers[MAT_CANOPY], buffers[MAT_BAMBOO])
	_build_lantern_rig(buffers[MAT_BAMBOO], buffers[MAT_CORD], buffers[MAT_DARK],
		buffers[MAT_PAPER])

	var meshes: Dictionary = {}
	for key: String in buffers:
		var buffer: MeshUtil.Buffer = buffers[key]
		if buffer.is_empty():
			continue
		var mesh := ArrayMesh.new()
		buffer.commit(mesh)
		meshes[key] = mesh
	return meshes


## buildHull(): outer shell, inner shell, and a fan cap at each end.
static func _build_hull(buf: MeshUtil.Buffer) -> void:
	var ring_size: int = 2 * (PROFILE_POINTS + 1)
	var base: int = buf.vertices.size()

	for i: int in STATIONS + 1:
		var t: float = float(i) / float(STATIONS)
		var q: Vector4 = sec(t)
		for j: int in PROFILE_POINTS + 1:
			var p: Vector2 = profile_pt(q.x, q.y, q.z, PI * float(j) / float(PROFILE_POINTS))
			buf.vert(Vector3(p.x, p.y, q.w), Vector2(q.w * 0.33, float(j) / float(PROFILE_POINTS) * 0.5))
		# Inner shell, 6 cm inboard and 7 cm up, walked back the other way so the loop closes.
		var bi: float = maxf(q.x - 0.06, 0.01)
		var ki: float = q.y + 0.07
		for j: int in range(PROFILE_POINTS, -1, -1):
			var p: Vector2 = profile_pt(bi, ki, q.z, PI * float(j) / float(PROFILE_POINTS))
			buf.vert(
				Vector3(p.x, p.y, q.w),
				Vector2(q.w * 0.33, 0.5 + float(PROFILE_POINTS - j) / float(PROFILE_POINTS) * 0.5)
			)

	for i: int in STATIONS:
		for j: int in ring_size:
			var a: int = base + i * ring_size + j
			var b: int = base + i * ring_size + (j + 1) % ring_size
			var c: int = base + (i + 1) * ring_size + j
			var d: int = base + (i + 1) * ring_size + (j + 1) % ring_size
			# Prototype emits (a, c, b) and (b, c, d).
			buf.tri(a, c, b)
			buf.tri(b, c, d)

	for i: int in [0, STATIONS]:
		var ids := PackedInt32Array()
		var centre := Vector3.ZERO
		for j: int in ring_size:
			var id: int = base + i * ring_size + j
			ids.push_back(id)
			centre += buf.vertices[id]
		centre /= float(ring_size)
		# The boat's forward is +Z, so the bow cap faces +Z and the transom -Z. Spelled out
		# rather than using Vector3.FORWARD, which is -Z under Godot's opposite convention.
		var outward: Vector3 = Vector3(0.0, 0.0, 1.0) if i == STATIONS else Vector3(0.0, 0.0, -1.0)
		buf.cap_fan(ids, centre, outward)


## Two tubes down each gunwale. The prototype fits a Catmull-Rom spline through 33 sampled
## stations; sampling sec() directly at every tube segment is the same curve without the spline.
static func _build_rails(buf: MeshUtil.Buffer) -> void:
	for side: int in [-1, 1]:
		_add_rail(buf, float(side), 0.005, 0.025, 0.05, 10)
		_add_rail(buf, float(side), 0.02, -0.2, 0.03, 8)


static func _add_rail(
	buf: MeshUtil.Buffer, side: float, offset: float, dy: float, radius: float, segments: int
) -> void:
	# Prototype railCurve(): t from 0.005 to 0.98 over the length of the gunwale.
	var samples: int = 120
	var points := PackedVector3Array()
	for i: int in samples + 1:
		var t: float = 0.005 + float(i) / float(samples) * 0.975
		var q: Vector4 = sec(t)
		points.push_back(Vector3(side * (q.x + offset), q.z + dy, q.w))
	for i: int in samples:
		MeshUtil.add_cone(buf, points[i], points[i + 1], radius, radius, segments)


## Deck boards, two thwarts, the transom cap and the stem post at the bow.
static func _build_deck(deck: MeshUtil.Buffer, dark: MeshUtil.Buffer) -> void:
	# Floor: a strip between mirrored edges, the prototype's ShapeGeometry outline.
	var left := PackedInt32Array()
	var right := PackedInt32Array()
	for i: int in 21:
		var q: Vector4 = sec(0.06 + float(i) / 20.0 * 0.76)
		var w: float = 0.8 * (q.x - 0.06)
		# Prototype maps deck UVs from world position: u = z * 0.3, v = x * 0.45 + 0.5.
		left.push_back(deck.vert(Vector3(-w, -0.1, q.w), Vector2(q.w * 0.3, -w * 0.45 + 0.5)))
		right.push_back(deck.vert(Vector3(w, -0.1, q.w), Vector2(q.w * 0.3, w * 0.45 + 0.5)))
	for i: int in 20:
		# Wound so the deck faces up: (b-a) x (c-a) has to come out along +Y.
		deck.quad(left[i], left[i + 1], right[i + 1], right[i])

	for t: float in [0.26, 0.72]:
		var q: Vector4 = sec(t)
		MeshUtil.add_box(
			deck, Vector3(0.0, q.z - 0.1, q.w), Vector3(2.0 * (q.x - 0.03), 0.06, 0.28)
		)

	var tq: Vector4 = sec(0.02)
	MeshUtil.add_box(
		dark, Vector3(0.0, tq.z + 0.02, tq.w), Vector3(2.0 * tq.x + 0.06, 0.08, 0.1)
	)

	var bow: Vector4 = sec(1.0)
	var bow_back: Vector4 = sec(0.93)
	MeshUtil.add_cone(
		dark,
		Vector3(0.0, bow_back.y, bow_back.w),
		Vector3(0.0, bow.z + 0.25, bow.w + 0.12),
		0.07, 0.05, 10
	)


## Half-cylinder awning with a slight sag, four bamboo hoops, two side rails and a ridge pole.
static func _build_canopy(canopy: MeshUtil.Buffer, bamboo: MeshUtil.Buffer) -> void:
	# Prototype: can.position.set(0, 0.44, 0.05).
	var origin := Vector3(0.0, 0.44, 0.05)
	var angular: int = 48
	var axial: int = 8
	var half_length: float = 1.15

	var rows: Array[PackedInt32Array] = []
	for j: int in axial + 1:
		var z: float = -half_length + 2.0 * half_length * float(j) / float(axial)
		# Prototype: sag = 1 - 0.018*cos(z*PI*2/0.77), applied to x and y.
		var sag: float = 1.0 - 0.018 * cos(z * TAU / 0.77)
		var ids := PackedInt32Array()
		for i: int in angular + 1:
			var th: float = -PI * 0.5 + PI * float(i) / float(angular)
			# The cm.scale.set(1, 0.95, 1) on the mesh folds into the y term.
			var p := Vector3(sin(th) * sag, cos(th) * sag * 0.95, z)
			ids.push_back(canopy.vert(
				origin + p, Vector2(float(i) / float(angular), float(j) / float(axial))
			))
		rows.push_back(ids)
	for j: int in axial:
		for i: int in angular:
			# Along the length first, then around the arch, so the normals face out of the awning.
			canopy.quad(rows[j][i], rows[j + 1][i], rows[j + 1][i + 1], rows[j][i + 1])

	for z: float in [-1.12, -0.37, 0.38, 1.12]:
		_add_hoop(bamboo, origin + Vector3(0.0, 0.0, z), 1.012, 0.028, 10, 48)
	for x: float in [-1.0, 1.0]:
		MeshUtil.add_cone(
			bamboo,
			origin + Vector3(x, 0.0, -1.2), origin + Vector3(x, 0.0, 1.2), 0.032, 0.032, 10
		)
	MeshUtil.add_cone(
		bamboo,
		origin + Vector3(0.0, 0.955, -1.2), origin + Vector3(0.0, 0.955, 1.2), 0.03, 0.03, 10
	)


## Half a torus standing in the XY plane - the prototype's TorusGeometry(r, tube, .., .., PI).
static func _add_hoop(
	buf: MeshUtil.Buffer, centre: Vector3, radius: float, tube: float, tube_segments: int,
	arc_segments: int
) -> void:
	var rows: Array[PackedInt32Array] = []
	for i: int in arc_segments + 1:
		var u: float = PI * float(i) / float(arc_segments)
		# The hoop follows the canopy's 0.95 vertical squash.
		var centre_point: Vector3 = centre + Vector3(cos(u) * radius, sin(u) * radius * 0.95, 0.0)
		var outward := Vector3(cos(u), sin(u), 0.0)
		var ids := PackedInt32Array()
		for j: int in tube_segments:
			var v: float = TAU * float(j) / float(tube_segments)
			ids.push_back(buf.vert(
				centre_point + outward * (cos(v) * tube) + Vector3(0.0, 0.0, sin(v) * tube),
				Vector2(float(i) / float(arc_segments), float(j) / float(tube_segments))
			))
		rows.push_back(ids)
	for i: int in arc_segments:
		# The tube frame here (outward, +Z, arc direction) is left-handed, so the rings are
		# skinned back to front to keep the normals pointing out of the hoop.
		buf.skin(rows[i + 1], rows[i])


## Mast, arm, cord, paper lantern and its two end caps at the bow.
static func _build_lantern_rig(
	bamboo: MeshUtil.Buffer, cord: MeshUtil.Buffer, dark: MeshUtil.Buffer,
	paper: MeshUtil.Buffer
) -> void:
	MeshUtil.add_cone(bamboo, Vector3(0.0, -0.1, 2.55), Vector3(0.0, 2.72, 3.0), 0.045, 0.035, 12)
	MeshUtil.add_cone(bamboo, Vector3(0.0, 2.7, 2.97), Vector3(0.0, 2.78, 3.62), 0.03, 0.025, 10)
	MeshUtil.add_cone(cord, Vector3(0.0, 2.77, 3.55), Vector3(0.0, 2.56, 3.55), 0.006, 0.006, 6)

	# Prototype lathe profile: a barrel with alternating ribs.
	var profile := PackedVector2Array()
	for i: int in 25:
		var y: float = -0.22 + 0.44 * float(i) / 24.0
		var r: float = 0.03 + 0.15 * sqrt(maxf(0.0, 1.0 - pow(y / 0.235, 2.0)))
		if i % 2 == 1:
			r += 0.004
		profile.push_back(Vector2(r, LANTERN_POS.y + y))
	var lantern := MeshUtil.Buffer.new()
	MeshUtil.add_lathe(lantern, profile, 40)
	_append_offset(paper, lantern, Vector3(LANTERN_POS.x, 0.0, LANTERN_POS.z))

	for dy: float in [0.225, -0.225]:
		MeshUtil.add_cone(
			dark,
			LANTERN_POS + Vector3(0.0, dy - 0.025, 0.0),
			LANTERN_POS + Vector3(0.0, dy + 0.025, 0.0),
			0.08, 0.07, 20
		)


## Copies one buffer into another, shifted. add_lathe revolves around the origin, so the lantern
## is built there and moved into place.
static func _append_offset(
	target: MeshUtil.Buffer, source: MeshUtil.Buffer, offset: Vector3
) -> void:
	var base: int = target.vertices.size()
	for i: int in source.vertices.size():
		target.vert(source.vertices[i] + offset, source.uvs[i])
	for index: int in source.indices:
		target.indices.push_back(base + index)
