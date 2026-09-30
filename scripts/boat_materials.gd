## The prototype's BM material table, shared by the boat and the boatman.
##
## Prototype: reference/ukiyo-river.html lines 634-654, plus the per-frame wetness at line 1515.
## Textures come from assets/generated, written once by scripts/tools/generate_textures.gd.
class_name BoatMaterials
extends RefCounted

const HULL: String = "hull"
const DECK: String = "deck"
const DARK: String = "dark"
const CANOPY: String = "canopy"
const BAMBOO: String = "bamboo"
const STRAW: String = "straw"
const STRAW_IN: String = "straw_in"
const MINO: String = "mino"
const KIMONO: String = "kimono"
const PANTS: String = "pants"
const GAITER: String = "gaiter"
const OBI: String = "obi"
const SKIN: String = "skin"
const HAIR: String = "hair"
const CORD: String = "cord"
const PAPER: String = "paper"

const GENERATED: String = "res://assets/generated/"


## One shared table, as the prototype has one `BM`. This matters: the rain roughness is applied
## across the whole table once per frame, so if the boat and the boatman each built their own,
## his kimono, cape and straw would never get wet.
static var _shared: Dictionary = {}


static func build() -> Dictionary:
	if not _shared.is_empty():
		return _shared
	var out: Dictionary = {}
	# Prototype repeat values become uv1_scale.
	out[HULL] = _textured("hull", "hull_bump", Vector2(1, 3), 0.55, true)
	out[DECK] = _textured("deck", "deck_bump", Vector2(1, 1), 0.6, false)
	out[DARK] = _textured("hull", "", Vector2(1, 3), 0.45, false)
	out[DARK].albedo_color = Color("#6e5a4a").srgb_to_linear()
	out[CANOPY] = _textured("weave", "weave_bump", Vector2(5, 3), 0.8, true)
	out[BAMBOO] = _textured("bamboo", "", Vector2(1, 7), 0.4, false)
	out[STRAW] = _textured("fiber", "fiber_bump", Vector2(6, 1), 0.75, true)
	out[STRAW_IN] = _textured("fiber", "", Vector2(6, 1), 0.85, true)
	out[STRAW_IN].albedo_color = Color("#7a6a55").srgb_to_linear()
	out[KIMONO] = _textured("kimono", "", Vector2(3, 2), 0.85, false)
	out[PANTS] = _textured("pants", "", Vector2(2, 2), 0.9, false)
	out[GAITER] = _textured("gaiter", "", Vector2(2, 2), 0.9, false)
	out[OBI] = _textured("obi", "", Vector2(4, 1), 0.8, false)

	# The straw cape is alpha cut, so the individual strands separate.
	var mino: StandardMaterial3D = _textured("strands", "", Vector2(5, 1), 0.85, true)
	mino.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mino.alpha_scissor_threshold = 0.45
	out[MINO] = mino

	out[SKIN] = _plain(Color("#8f664a"), 0.6)
	out[HAIR] = _plain(Color("#15110e"), 0.5)
	out[CORD] = _plain(Color("#2c2118"), 0.8)

	# The lantern paper is unlit; boat.gd drives its brightness.
	var paper := StandardMaterial3D.new()
	paper.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paper.albedo_texture = load(GENERATED + "lantern.png")
	out[PAPER] = paper
	_shared = out
	return out


## The roughness each material starts at, so the rain can scale it without drifting.
static func base_roughness(materials: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in materials:
		out[key] = (materials[key] as StandardMaterial3D).roughness
	return out


## Prototype: everything gets glossier as it gets wetter.
static func apply_wetness(materials: Dictionary, base: Dictionary, rain: float) -> void:
	var factor: float = 1.0 - 0.45 * rain
	for key: String in materials:
		var material: StandardMaterial3D = materials[key]
		if material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			continue
		material.roughness = float(base[key]) * factor


static func _textured(
	albedo: String, normal: String, repeat: Vector2, roughness: float, double_sided: bool
) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(GENERATED + albedo + ".png")
	if not normal.is_empty():
		# three.js bumpMap perturbs from a height gradient; Godot wants a normal map, so the
		# greyscale variant is fed through as one at modest depth.
		mat.normal_enabled = true
		mat.normal_texture = load(GENERATED + normal + ".png")
		mat.normal_scale = 0.5
	mat.uv1_scale = Vector3(repeat.x, repeat.y, 1.0)
	mat.roughness = roughness
	mat.metallic = 0.0
	if double_sided:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


static func _plain(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.srgb_to_linear()
	mat.roughness = roughness
	mat.metallic = 0.0
	return mat
