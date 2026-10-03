## A short burst of sparks where a blow was turned aside.
##
## Blocking worked before this and was invisible, which made it feel like nothing had happened.
## A parry throws bright gold; an ordinary block throws fewer, cooler sparks - so the two read
## differently the moment they happen, without reading the HUD.
class_name SparkBurst
extends GPUParticles3D

const PARRY_COLOUR: String = "#ffd978"
const BLOCK_COLOUR: String = "#cfd8e4"


static func create(parry: bool) -> SparkBurst:
	var burst := SparkBurst.new()
	burst.one_shot = true
	burst.emitting = false
	burst.amount = 26 if parry else 14
	burst.lifetime = 0.42 if parry else 0.3
	burst.explosiveness = 1.0
	burst.local_coords = false
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	burst.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.06
	process.direction = Vector3(0, 0.35, 0)
	process.spread = 180.0
	process.initial_velocity_min = 1.6 if parry else 1.0
	process.initial_velocity_max = 4.2 if parry else 2.4
	process.gravity = Vector3(0, -5.5, 0)
	process.damping_min = 1.5
	process.damping_max = 3.0
	process.scale_min = 0.5
	process.scale_max = 1.0
	# Sparks cool as they fly.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(Color(PARRY_COLOUR if parry else BLOCK_COLOUR), 0.0))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	burst.process_material = process

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(Color(PARRY_COLOUR if parry else BLOCK_COLOUR), 1.0)
	burst.material_override = material

	var quad := QuadMesh.new()
	quad.size = Vector2(0.055, 0.055)
	burst.draw_pass_1 = quad
	return burst


## Fires once at `where` and tidies itself up afterwards.
static func fire(parent: Node3D, where: Vector3, parry: bool) -> void:
	if parent == null:
		return
	var burst: SparkBurst = create(parry)
	parent.add_child(burst)
	burst.global_position = where
	burst.emitting = true
	burst.finished.connect(burst.queue_free)
