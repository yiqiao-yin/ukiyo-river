## Builds the four enemy types, in the same idiom as the boatman: lathes, cones and squashed
## spheres, no skinned meshes.
##
## The armour is the real tell between them, so each kind gets its own lacquer colour and its
## own silhouette:
##   ashigaru - foot soldier, light chest plate and a wide jingasa hat, carries a spear
##   ronin    - masterless, no helmet, topknot bare, carries a katana
##   samurai  - full lamellar cuirass, shoulder guards, kabuto with a crest, katana
##   sohei    - warrior monk, hooded robe over armour, naginata, deep chi
class_name SamuraiBuilder
extends RefCounted

enum Kind { ASHIGARU, RONIN, SAMURAI, SOHEI }

const KIND_NAMES: Dictionary = {
	Kind.ASHIGARU: "Ashigaru",
	Kind.RONIN: "Ronin",
	Kind.SAMURAI: "Samurai",
	Kind.SOHEI: "Sohei",
}
const KIND_KANJI: Dictionary = {
	Kind.ASHIGARU: "足軽",
	Kind.RONIN: "浪人",
	Kind.SAMURAI: "侍",
	Kind.SOHEI: "僧兵",
}

## Material keys for this builder's own palette. Skin, cord and the straw of a jingasa come
## from BoatMaterials so the whole cast shares one look.
const LACQUER: String = "lacquer"
const LACING: String = "lacing"
const CLOTH: String = "cloth"
const STEEL: String = "steel"

## Lacquer colour per kind - the quickest read at a distance.
const LACQUER_COLOURS: Dictionary = {
	Kind.ASHIGARU: "#3b3a36",
	Kind.RONIN: "#4a2f2a",
	Kind.SAMURAI: "#7c1f1a",
	Kind.SOHEI: "#2b3a34",
}
## Silk lacing between the plates.
const LACING_COLOURS: Dictionary = {
	Kind.ASHIGARU: "#6d6555",
	Kind.RONIN: "#8a7448",
	Kind.SAMURAI: "#c8a33c",
	Kind.SOHEI: "#7a4a2c",
}
const CLOTH_COLOURS: Dictionary = {
	Kind.ASHIGARU: "#4a4e52",
	Kind.RONIN: "#3a3340",
	Kind.SAMURAI: "#222a3c",
	Kind.SOHEI: "#5c4a36",
}


## Returns {material key: ArrayMesh} for the body, in the figure's own space with the feet at
## y = 0 and facing +Z, the same convention the boatman uses.
static func build(kind: Kind) -> Dictionary:
	var buffers: Dictionary = {}
	for key: String in [LACQUER, LACING, CLOTH, STEEL, BoatMaterials.SKIN, BoatMaterials.HAIR,
			BoatMaterials.CORD, BoatMaterials.STRAW]:
		buffers[key] = MeshUtil.Buffer.new()

	_legs(buffers, kind)
	_torso(buffers, kind)
	_head(buffers, kind)

	var meshes: Dictionary = {}
	for key: String in buffers:
		var buffer: MeshUtil.Buffer = buffers[key]
		if buffer.is_empty():
			continue
		var mesh := ArrayMesh.new()
		buffer.commit(mesh)
		meshes[key] = mesh
	return meshes


## The weapon itself, built separately so it can be parented to the swinging arm. Its origin is
## the grip, and it runs along +Y.
static func build_weapon(weapon: Weapon) -> Dictionary:
	var buffers: Dictionary = {
		BoatMaterials.BAMBOO: MeshUtil.Buffer.new(),
		STEEL: MeshUtil.Buffer.new(),
		BoatMaterials.CORD: MeshUtil.Buffer.new(),
	}
	var shaft: MeshUtil.Buffer = buffers[BoatMaterials.BAMBOO]
	var steel: MeshUtil.Buffer = buffers[STEEL]
	var cord: MeshUtil.Buffer = buffers[BoatMaterials.CORD]

	match weapon.display_name:
		"Katana":
			# Grip, guard, then a blade that widens a little toward the tip.
			MeshUtil.add_cone(cord, Vector3(0, -0.26, 0), Vector3(0, 0.0, 0), 0.022, 0.024, 8)
			MeshUtil.add_cone(steel, Vector3(0, 0.0, 0), Vector3(0, 0.02, 0), 0.06, 0.06, 12)
			_blade(steel, 0.02, 1.02, 0.028, 0.008)
		"Naginata":
			MeshUtil.add_cone(shaft, Vector3(0, -0.9, 0), Vector3(0, 0.62, 0), 0.028, 0.024, 10)
			MeshUtil.add_cone(cord, Vector3(0, 0.6, 0), Vector3(0, 0.66, 0), 0.03, 0.03, 8)
			_blade(steel, 0.66, 0.52, 0.036, 0.01)
		"Yari":
			MeshUtil.add_cone(shaft, Vector3(0, -1.2, 0), Vector3(0, 1.0, 0), 0.026, 0.022, 10)
			MeshUtil.add_cone(steel, Vector3(0, 1.0, 0), Vector3(0, 1.32, 0), 0.026, 0.0, 8)
		"Tetsubo":
			MeshUtil.add_cone(shaft, Vector3(0, -0.3, 0), Vector3(0, 0.5, 0), 0.04, 0.05, 10)
			MeshUtil.add_cone(steel, Vector3(0, 0.5, 0), Vector3(0, 1.05, 0), 0.075, 0.085, 8)
			# Studs down the head of the club.
			for row: int in 4:
				var y: float = 0.56 + float(row) * 0.13
				for i: int in 6:
					var a: float = TAU * float(i) / 6.0 + float(row) * 0.4
					MeshUtil.add_sphere(steel, Vector3(cos(a) * 0.08, y, sin(a) * 0.08), 0.018, 6, 4)
		_:
			# Bo staff, and anything unrecognised.
			MeshUtil.add_cone(shaft, Vector3(0, -1.5, 0), Vector3(0, 1.5, 0), 0.03, 0.028, 10)

	var meshes: Dictionary = {}
	for key: String in buffers:
		var buffer: MeshUtil.Buffer = buffers[key]
		if buffer.is_empty():
			continue
		var mesh := ArrayMesh.new()
		buffer.commit(mesh)
		meshes[key] = mesh
	return meshes


## A flat tapering blade: a long thin box that narrows and comes to a point.
static func _blade(buf: MeshUtil.Buffer, base_y: float, length: float, width: float, thick: float) -> void:
	var steps: int = 8
	var rows: Array[PackedInt32Array] = []
	for i: int in steps + 1:
		var t: float = float(i) / float(steps)
		var y: float = base_y + length * t
		# Slight curve, as a katana has.
		var z: float = -0.06 * t * t
		var w: float = width * (1.0 - 0.35 * t)
		var d: float = thick * (1.0 - 0.6 * t)
		var ids := PackedInt32Array()
		for corner: Vector2 in [
			Vector2(-w, -d), Vector2(w, -d), Vector2(w, d), Vector2(-w, d),
		]:
			ids.push_back(buf.vert(Vector3(corner.x, y, z + corner.y), Vector2(t, 0.0)))
		rows.push_back(ids)
	for i: int in steps:
		for c: int in 4:
			var n: int = (c + 1) % 4
			buf.quad(rows[i][c], rows[i][n], rows[i + 1][n], rows[i + 1][c])
	buf.quad(rows[0][3], rows[0][2], rows[0][1], rows[0][0])
	var last: int = rows.size() - 1
	buf.quad(rows[last][0], rows[last][1], rows[last][2], rows[last][3])


static func _legs(b: Dictionary, kind: Kind) -> void:
	var cloth: MeshUtil.Buffer = b[CLOTH]
	var skin: MeshUtil.Buffer = b[BoatMaterials.SKIN]
	var straw: MeshUtil.Buffer = b[BoatMaterials.STRAW]
	for side: float in [-1.0, 1.0]:
		var hip := Vector3(side * 0.11, 0.84, 0.0)
		var knee := Vector3(side * 0.13, 0.45, 0.05)
		var ankle := Vector3(side * 0.14, 0.08, -0.02)
		MeshUtil.add_cone(cloth, hip, knee, 0.095, 0.07, 12)
		MeshUtil.add_cone(cloth, knee, ankle, 0.062, 0.05, 12)
		MeshUtil.add_sphere(skin, ankle, 0.045, 12, 8)
		MeshUtil.add_sphere(skin, Vector3(ankle.x, 0.04, ankle.z + 0.07), 0.05, 12, 8,
			Vector3(0.95, 0.6, 2.0))
		MeshUtil.add_box(straw, Vector3(ankle.x, 0.012, ankle.z + 0.06), Vector3(0.12, 0.022, 0.27))
		# Shin guards, on everyone but the monk.
		if kind != Kind.SOHEI:
			for plate: int in 3:
				var t: float = 0.25 + float(plate) * 0.25
				MeshUtil.add_box(
					b[LACQUER], knee.lerp(ankle, t) + Vector3(0.0, 0.0, 0.055),
					Vector3(0.11, 0.075, 0.03)
				)


static func _torso(b: Dictionary, kind: Kind) -> void:
	var lacquer: MeshUtil.Buffer = b[LACQUER]
	var lacing: MeshUtil.Buffer = b[LACING]
	var cloth: MeshUtil.Buffer = b[CLOTH]
	var skin: MeshUtil.Buffer = b[BoatMaterials.SKIN]

	# Body under the armour.
	_lathe_squashed(cloth, PackedVector2Array([
		Vector2(0.06, 0.82), Vector2(0.19, 0.92), Vector2(0.22, 1.06),
		Vector2(0.21, 1.24), Vector2(0.17, 1.40), Vector2(0.09, 1.46),
	]), 24, 0.78)

	# Do: the cuirass. A stack of lacquered bands laced together, wider at the chest.
	var bands: int = 5 if kind != Kind.ASHIGARU else 3
	for i: int in bands:
		var t: float = float(i) / float(maxi(bands - 1, 1))
		var y: float = 0.96 + t * 0.40
		var radius: float = 0.245 - 0.02 * t
		_ring_plates(lacquer, y, radius, 0.072, 10, 0.80)
		if i < bands - 1:
			_lathe_squashed(lacing, PackedVector2Array([
				Vector2(radius * 0.97, y + 0.040), Vector2(radius * 0.97, y + 0.052),
			]), 20, 0.80)

	# Kusazuri: the skirt of hanging plates.
	if kind != Kind.SOHEI:
		for i: int in 6:
			var a: float = TAU * float(i) / 6.0 + PI / 6.0
			var out := Vector3(cos(a), 0.0, sin(a) * 0.8)
			MeshUtil.add_box(
				lacquer, Vector3(out.x * 0.235, 0.86, out.z * 0.235),
				Vector3(0.15, 0.20, 0.035), Basis(Vector3.UP, -a + PI * 0.5)
			)

	# Sode: shoulder guards. The full samurai gets big ones, the ronin small, the monk none.
	var sode: float = {Kind.SAMURAI: 1.0, Kind.RONIN: 0.62, Kind.ASHIGARU: 0.5, Kind.SOHEI: 0.0}[kind]
	if sode > 0.0:
		for side: float in [-1.0, 1.0]:
			for plate: int in 3:
				var drop: float = float(plate) * 0.075
				MeshUtil.add_box(
					lacquer,
					Vector3(side * (0.27 + drop * 0.12), 1.33 - drop, 0.0),
					Vector3(0.05, 0.075, 0.30 * sode),
					Basis(Vector3(0.0, 0.0, 1.0), side * -0.35)
				)

	# The monk's robe hangs over everything.
	if kind == Kind.SOHEI:
		_lathe_squashed(cloth, PackedVector2Array([
			Vector2(0.34, 0.60), Vector2(0.31, 0.86), Vector2(0.27, 1.12),
			Vector2(0.23, 1.32), Vector2(0.15, 1.44),
		]), 28, 0.85)

	# Neck.
	MeshUtil.add_cone(skin, Vector3(0.0, 1.42, 0.0), Vector3(0.0, 1.53, 0.01), 0.055, 0.05, 10)

	# Shoulders, so the arms have something to come out of.
	for side: float in [-1.0, 1.0]:
		MeshUtil.add_sphere(b[LACQUER] if sode > 0.0 else cloth,
			Vector3(side * 0.22, 1.33, 0.0), 0.085, 12, 8)


static func _head(b: Dictionary, kind: Kind) -> void:
	var skin: MeshUtil.Buffer = b[BoatMaterials.SKIN]
	var hair: MeshUtil.Buffer = b[BoatMaterials.HAIR]
	var lacquer: MeshUtil.Buffer = b[LACQUER]
	var steel: MeshUtil.Buffer = b[STEEL]
	var cloth: MeshUtil.Buffer = b[CLOTH]
	var straw: MeshUtil.Buffer = b[BoatMaterials.STRAW]
	var head_y: float = 1.62

	MeshUtil.add_sphere(skin, Vector3(0.0, head_y, 0.012), 0.1, 16, 12, Vector3(0.9, 1.1, 1.0))
	MeshUtil.add_sphere(skin, Vector3(0.0, head_y - 0.06, 0.045), 0.06, 12, 8, Vector3(1.1, 0.8, 1.0))

	match kind:
		Kind.ASHIGARU:
			# Jingasa: a wide shallow straw hat, worn instead of a helmet.
			MeshUtil.add_lathe(straw, PackedVector2Array([
				Vector2(0.30, head_y + 0.06), Vector2(0.26, head_y + 0.10),
				Vector2(0.16, head_y + 0.15), Vector2(0.001, head_y + 0.17),
			]), 28)
			MeshUtil.add_sphere(hair, Vector3(0.0, head_y + 0.02, -0.01), 0.1, 12, 8,
				Vector3(0.94, 1.0, 1.0))
		Kind.RONIN:
			# Bare head, shaved pate with a topknot.
			MeshUtil.add_sphere(hair, Vector3(0.0, head_y + 0.025, -0.012), 0.103, 14, 10,
				Vector3(0.95, 1.0, 1.02))
			MeshUtil.add_sphere(hair, Vector3(0.0, head_y + 0.13, -0.05), 0.033, 10, 8,
				Vector3(0.8, 0.7, 1.4))
		Kind.SAMURAI:
			# Kabuto: a riveted bowl, a flared neck guard and a crest at the brow.
			MeshUtil.add_lathe(lacquer, PackedVector2Array([
				Vector2(0.125, head_y + 0.02), Vector2(0.124, head_y + 0.07),
				Vector2(0.10, head_y + 0.13), Vector2(0.055, head_y + 0.17),
				Vector2(0.001, head_y + 0.18),
			]), 24)
			# Shikoro, the neck guard, in flared rings.
			for ring: int in 3:
				var t: float = float(ring) / 2.0
				MeshUtil.add_lathe(lacquer, PackedVector2Array([
					Vector2(0.15 + t * 0.055, head_y + 0.015 - t * 0.055),
					Vector2(0.155 + t * 0.055, head_y - 0.005 - t * 0.055),
				]), 22)
			# Maedate: the crest. Two horns curving up from the brow.
			for side: float in [-1.0, 1.0]:
				MeshUtil.add_cone(
					steel, Vector3(side * 0.045, head_y + 0.12, 0.09),
					Vector3(side * 0.13, head_y + 0.30, 0.03), 0.016, 0.004, 6
				)
			# Menpo: an iron half mask over the jaw.
			MeshUtil.add_sphere(steel, Vector3(0.0, head_y - 0.05, 0.05), 0.085, 12, 8,
				Vector3(1.0, 0.75, 1.0))
		Kind.SOHEI:
			# Zukin: a cloth hood wound round the head, leaving the face open.
			MeshUtil.add_lathe(cloth, PackedVector2Array([
				Vector2(0.125, head_y - 0.09), Vector2(0.135, head_y + 0.02),
				Vector2(0.115, head_y + 0.11), Vector2(0.06, head_y + 0.16),
				Vector2(0.001, head_y + 0.175),
			]), 22)
			MeshUtil.add_torus(cloth, Vector3(0.0, head_y + 0.055, 0.0), 0.132, 0.022, 8, 20,
				TAU, Basis(Vector3.RIGHT, PI * 0.5))


## A ring of overlapping plates, which is what reads as lamellar armour at this size.
static func _ring_plates(
	buf: MeshUtil.Buffer, y: float, radius: float, height: float, count: int, squash: float
) -> void:
	for i: int in count:
		var a: float = TAU * float(i) / float(count)
		MeshUtil.add_box(
			buf, Vector3(cos(a) * radius, y, sin(a) * radius * squash),
			Vector3(radius * 0.72, height, 0.03), Basis(Vector3.UP, -a + PI * 0.5)
		)


static func _lathe_squashed(
	target: MeshUtil.Buffer, profile: PackedVector2Array, segments: int, z_scale: float
) -> void:
	var temp := MeshUtil.Buffer.new()
	MeshUtil.add_lathe(temp, profile, segments)
	MeshUtil.append_transformed(
		target, temp, Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 1.0, z_scale)), Vector3.ZERO)
	)


## Materials for this builder's own palette, on top of the shared cast materials.
static func materials(kind: Kind) -> Dictionary:
	var out: Dictionary = BoatMaterials.build().duplicate()
	out[LACQUER] = _lacquered(Color(LACQUER_COLOURS[kind] as String), 0.28)
	out[LACING] = _lacquered(Color(LACING_COLOURS[kind] as String), 0.7)
	out[CLOTH] = _lacquered(Color(CLOTH_COLOURS[kind] as String), 0.9)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("#9aa0a6").srgb_to_linear()
	steel.metallic = 0.85
	steel.roughness = 0.32
	out[STEEL] = steel
	return out


static func _lacquered(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.srgb_to_linear()
	mat.roughness = roughness
	mat.metallic = 0.0
	return mat
