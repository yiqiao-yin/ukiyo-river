## Torii gates, houses, shrines, pagodas, stone lanterns, bridges and stilt houses.
##
## Prototype: reference/ukiyo-river.html lines 344-511. Each builder returns geometry in its own
## local space; architecture.gd places them and merges everything sharing a material, which is
## what the prototype's bakeStatic() does with its render-time groups.
class_name ArchitectureBuilder
extends RefCounted

## Material keys. These are the prototype's MAT table, one merged surface each.
const MAT_VERM: String = "verm"
const MAT_WOOD: String = "wood"
const MAT_DARKWOOD: String = "darkwood"
const MAT_ROOF: String = "roof"
const MAT_THATCH: String = "thatch"
const MAT_PLASTER: String = "plaster"
const MAT_STONE: String = "stone"
const MAT_STONE_DARK: String = "stone_dark"
const MAT_BRONZE: String = "bronze"
## Unshaded, brightness driven per frame by how dark it is.
const MAT_LAMP: String = "lamp"
const MAT_WINDOW: String = "window"

const KEYS: PackedStringArray = [
	MAT_VERM, MAT_WOOD, MAT_DARKWOOD, MAT_ROOF, MAT_THATCH, MAT_PLASTER,
	MAT_STONE, MAT_STONE_DARK, MAT_BRONZE, MAT_LAMP, MAT_WINDOW,
]

## Prototype MAT colours, and the two animated bases.
const COLOURS: Dictionary = {
	MAT_VERM: "#a8352a",
	MAT_WOOD: "#4b3526",
	MAT_DARKWOOD: "#2b211a",
	MAT_ROOF: "#2a2e33",
	MAT_THATCH: "#5e4f36",
	MAT_PLASTER: "#cfc4ae",
	MAT_STONE: "#6f6c64",
	MAT_STONE_DARK: "#4c4a45",
	MAT_BRONZE: "#5e5236",
}
const LAMP_BASE: String = "#ffc978"
const WINDOW_BASE: String = "#e9a75a"


static func new_buffers() -> Dictionary:
	var buffers: Dictionary = {}
	for key: String in KEYS:
		buffers[key] = MeshUtil.Buffer.new()
	return buffers


## Merges `source` buffers into `target` buffers under one transform - the prototype's bakeStatic.
static func merge(target: Dictionary, source: Dictionary, xform: Transform3D) -> void:
	for key: String in source:
		var part: MeshUtil.Buffer = source[key]
		if not part.is_empty():
			MeshUtil.append_transformed(target[key], part, xform)


## torii(s) - two tapered posts, the lintel, two bent beams and the central tablet.
static func torii(scale: float) -> Dictionary:
	var b: Dictionary = new_buffers()
	for x: float in [-2.3, 2.3]:
		MeshUtil.add_cone(
			b[MAT_VERM], Vector3(x, 1.4 - 4.8, 0.0), Vector3(x, 1.4 + 4.8, 0.0), 0.33, 0.27, 10
		)
		MeshUtil.add_cone(
			b[MAT_DARKWOOD], Vector3(x, -0.2, 0.0), Vector3(x, 0.3, 0.0), 0.42, 0.42, 10
		)
	MeshUtil.add_box(b[MAT_VERM], Vector3(0.0, 4.7, 0.0), Vector3(6.2, 0.32, 0.32))
	MeshUtil.add_bent_bar(b[MAT_VERM], Vector3(0.0, 5.75, 0.0), Vector3(7.0, 0.4, 0.6), 0.3)
	MeshUtil.add_bent_bar(b[MAT_DARKWOOD], Vector3(0.0, 6.05, 0.0), Vector3(7.6, 0.28, 0.72), 0.42)
	MeshUtil.add_box(b[MAT_DARKWOOD], Vector3(0.0, 5.2, 0.0), Vector3(0.3, 0.9, 0.2))
	return _scaled(b, scale)


## house(opts) - plinth, plastered walls, corner posts, a lit window and a hipped roof.
static func house(
	w: float, d: float, wall_height: float, roof_height: float,
	roof_key: String, wall_key: String, post_key: String, with_plinth: bool
) -> Dictionary:
	var b: Dictionary = new_buffers()
	if with_plinth:
		MeshUtil.add_box(
			b[MAT_STONE_DARK], Vector3(0.0, -1.7, 0.0), Vector3(w + 0.5, 4.0, d + 0.5)
		)
	MeshUtil.add_box(b[wall_key], Vector3(0.0, 0.3 + wall_height * 0.5, 0.0), Vector3(w, wall_height, d))
	MeshUtil.add_box(
		b[MAT_DARKWOOD], Vector3(0.0, 0.3 + wall_height, 0.0), Vector3(w + 0.12, 0.2, d + 0.12)
	)
	MeshUtil.add_box(b[MAT_DARKWOOD], Vector3(0.0, 0.55, 0.0), Vector3(w + 0.12, 0.5, d + 0.12))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			MeshUtil.add_box(
				b[post_key],
				Vector3(sx * w * 0.5, 0.3 + wall_height * 0.5, sz * d * 0.5),
				Vector3(0.2, wall_height, 0.2)
			)
	MeshUtil.add_box(
		b[MAT_WINDOW], Vector3(0.0, 1.55, d * 0.5 + 0.03), Vector3(w * 0.55, 0.9, 0.06)
	)
	MeshUtil.add_pyramid(
		b[roof_key],
		Vector3(0.0, 0.3 + wall_height + roof_height * 0.5 - 0.05, 0.0),
		Vector3(w * 0.98, roof_height, d * 0.98)
	)
	MeshUtil.add_box(
		b[MAT_DARKWOOD],
		Vector3(0.0, 0.3 + wall_height + roof_height - 0.15, 0.0),
		Vector3(0.25, 0.25, d * 0.5)
	)
	return b


## pagoda() - five diminishing storeys on a stone base, topped with a finial and its rings.
static func pagoda() -> Dictionary:
	var b: Dictionary = new_buffers()
	MeshUtil.add_box(b[MAT_STONE], Vector3(0.0, -1.5, 0.0), Vector3(7.4, 4.0, 7.4))
	var y: float = 0.5
	for i: int in 5:
		var s: float = 4.8 - float(i) * 0.55
		MeshUtil.add_box(b[MAT_VERM], Vector3(0.0, y + 0.75, 0.0), Vector3(s * 0.66, 1.5, s * 0.66))
		MeshUtil.add_box(b[MAT_PLASTER], Vector3(0.0, y + 0.8, 0.0), Vector3(s * 0.5, 0.7, s * 0.67))
		MeshUtil.add_pyramid(b[MAT_ROOF], Vector3(0.0, y + 1.85, 0.0), Vector3(s * 1.08, 0.85, s * 1.08))
		y += 1.95
	MeshUtil.add_cone(
		b[MAT_BRONZE], Vector3(0.0, y + 1.6 - 1.9, 0.0), Vector3(0.0, y + 1.6 + 1.9, 0.0),
		0.12, 0.07, 6
	)
	for k: int in 6:
		var ring_y: float = y + 0.6 + float(k) * 0.4
		MeshUtil.add_cone(
			b[MAT_BRONZE], Vector3(0.0, ring_y - 0.035, 0.0), Vector3(0.0, ring_y + 0.035, 0.0),
			0.28, 0.28, 10
		)
	return b


## toro() - a stone lantern. The two crossed lamp boxes are the lit part.
static func toro() -> Dictionary:
	var b: Dictionary = new_buffers()
	MeshUtil.add_cone(b[MAT_STONE], Vector3(0.0, -0.2, 0.0), Vector3(0.0, 0.3, 0.0), 0.45, 0.35, 6)
	MeshUtil.add_cone(b[MAT_STONE], Vector3(0.0, 0.3, 0.0), Vector3(0.0, 1.3, 0.0), 0.18, 0.14, 6)
	MeshUtil.add_box(b[MAT_STONE], Vector3(0.0, 1.37, 0.0), Vector3(0.72, 0.15, 0.72))
	MeshUtil.add_box(b[MAT_STONE], Vector3(0.0, 1.67, 0.0), Vector3(0.5, 0.45, 0.5))
	MeshUtil.add_box(b[MAT_LAMP], Vector3(0.0, 1.67, 0.0), Vector3(0.34, 0.3, 0.54))
	MeshUtil.add_box(b[MAT_LAMP], Vector3(0.0, 1.67, 0.0), Vector3(0.54, 0.3, 0.34))
	MeshUtil.add_pyramid(b[MAT_STONE], Vector3(0.0, 2.08, 0.0), Vector3(0.95, 0.38, 0.95))
	MeshUtil.add_sphere(b[MAT_STONE], Vector3(0.0, 2.33, 0.0), 0.08, 6, 4)
	return b


## bridge(z0) - an arched deck with rails, balusters, newel posts and piles.
static func bridge() -> Dictionary:
	var b: Dictionary = new_buffers()
	var span: float = 25.0
	var segments: int = 26
	var previous := Vector2.ZERO
	var has_previous: bool = false

	for i: int in segments + 1:
		var s: float = -span + 2.0 * span * float(i) / float(segments)
		var y: float = _arc(s, span)
		if has_previous:
			var length: float = Vector2(s - previous.x, y - previous.y).length()
			var angle: float = atan2(y - previous.y, s - previous.x)
			var mid := Vector3((s + previous.x) * 0.5, (y + previous.y) * 0.5, 0.0)
			var basis := Basis(Vector3.BACK, angle)
			MeshUtil.add_box(b[MAT_WOOD], mid, Vector3(length + 0.06, 0.35, 3.6), basis)
			for sz: float in [-1.7, 1.7]:
				MeshUtil.add_box(
					b[MAT_VERM], mid + Vector3(0.0, 1.0, sz),
					Vector3(length + 0.06, 0.14, 0.14), basis
				)
				MeshUtil.add_box(
					b[MAT_VERM], mid + Vector3(0.0, 0.55, sz),
					Vector3(length + 0.06, 0.08, 0.08), basis
				)
		if i % 2 == 0:
			for sz: float in [-1.7, 1.7]:
				MeshUtil.add_box(
					b[MAT_VERM], Vector3(s, y + 0.55, sz), Vector3(0.16, 1.1, 0.16)
				)
		previous = Vector2(s, y)
		has_previous = true

	for s: float in [-span, span]:
		for sz: float in [-1.7, 1.7]:
			var top: float = _arc(s, span)
			MeshUtil.add_cone(
				b[MAT_VERM], Vector3(s, top, sz), Vector3(s, top + 1.4, sz), 0.14, 0.14, 8
			)
			MeshUtil.add_sphere(b[MAT_BRONZE], Vector3(s, top + 1.5, sz), 0.2, 8, 6)

	for s: float in [-21.0, -18.5, 18.5, 21.0]:
		for sz: float in [-1.3, 1.3]:
			var height: float = _arc(s, span) + 4.0
			var centre_y: float = (_arc(s, span) - 4.0) * 0.5
			MeshUtil.add_cone(
				b[MAT_DARKWOOD],
				Vector3(s, centre_y - height * 0.5, sz), Vector3(s, centre_y + height * 0.5, sz),
				0.22, 0.2, 8
			)
	return b


## stilt() - a thatched house on piles with a jetty running out over the water.
static func stilt() -> Dictionary:
	var b: Dictionary = new_buffers()
	# Prototype hides the house's stone plinth: it stands on piles instead.
	var cabin: Dictionary = house(5.0, 4.0, 2.2, 1.7, MAT_THATCH, MAT_PLASTER, MAT_DARKWOOD, false)
	merge(b, cabin, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.3, 0.0)))
	for px: float in [-2.4, 2.4]:
		for pz: float in [-1.9, 1.9]:
			MeshUtil.add_cone(
				b[MAT_DARKWOOD], Vector3(px, -3.3, pz), Vector3(px, 1.7, pz), 0.12, 0.12, 6
			)
	MeshUtil.add_box(b[MAT_WOOD], Vector3(0.0, 1.55, 0.0), Vector3(6.0, 0.2, 5.0))
	MeshUtil.add_box(b[MAT_WOOD], Vector3(0.0, 0.9, 4.6), Vector3(1.4, 0.15, 4.5))
	for pz: float in [3.2, 5.5]:
		for px: float in [-0.6, 0.6]:
			MeshUtil.add_cone(
				b[MAT_DARKWOOD], Vector3(px, -3.1, pz), Vector3(px, 0.9, pz), 0.09, 0.09, 6
			)
	return b


## The bridge's deck profile: flat at the ends, rising 6.8 m at the crown.
static func _arc(s: float, span: float) -> float:
	var t: float = s / span
	return 1.2 + 6.8 * (1.0 - t * t)


static func _scaled(buffers: Dictionary, scale: float) -> Dictionary:
	if is_equal_approx(scale, 1.0):
		return buffers
	var out: Dictionary = new_buffers()
	merge(out, buffers, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), Vector3.ZERO))
	return out


## Lambert has no specular term, so the shaded materials are fully rough with specular off.
static func materials() -> Dictionary:
	var out: Dictionary = {}
	for key: String in COLOURS:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(COLOURS[key] as String).srgb_to_linear()
		mat.roughness = 1.0
		mat.metallic = 0.0
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		out[key] = mat
	for key: String in [MAT_LAMP, MAT_WINDOW]:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		out[key] = mat
	return out
