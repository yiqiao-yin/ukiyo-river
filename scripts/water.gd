## River surface.
##
## The mesh and the ShaderMaterial live in main.tscn so they stay tunable in the inspector; this
## script only feeds shaders/water.gdshader the values the prototype recomputes every frame
## (reference/ukiyo-river.html lines 1535-1542).
extends MeshInstance3D

## Prototype: reference to the live env object.
@export var environment_controller: EnvironmentController

var _material: ShaderMaterial


func _ready() -> void:
	# The prototype's water never casts a shadow - it is drawn after the shadow pass entirely.
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = material_override as ShaderMaterial
	if _material == null:
		push_error("[water] expected a ShaderMaterial in material_override")


func _process(_delta: float) -> void:
	if _material == null or environment_controller == null:
		return
	var env: EnvironmentController = environment_controller
	_material.set_shader_parameter("u_time", env.elapsed)
	_material.set_shader_parameter("u_wind", env.num("wind"))
	_material.set_shader_parameter("u_rain", env.num("rain"))
	_material.set_shader_parameter("u_flash", env.flash)
	_material.set_shader_parameter("u_ambient", env.num("amb"))
	_material.set_shader_parameter("u_cloud", env.num("cloud"))
	_material.set_shader_parameter("u_deep", _rgb(env.col("deep")))
	_material.set_shader_parameter("u_sun_dir", env.sun_dir)
	# Prototype: uSunCol is the sun colour premultiplied by its intensity.
	_material.set_shader_parameter("u_sun_col", _rgb(env.col("sun_col")) * env.num("sun"))


## Shader vec3 uniforms take a Vector3, not a Color.
func _rgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)
