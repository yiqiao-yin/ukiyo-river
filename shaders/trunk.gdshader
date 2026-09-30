// Bark. The prototype uses a Phong material with a bump map and an ambient occlusion value
// carried in the vertex colour; the sway is shared with the foliage.
shader_type spatial;
render_mode cull_back;

#include "res://shaders/tree_sway.gdshaderinc"

uniform sampler2D u_bark : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D u_bark_normal : hint_roughness_gray, filter_linear_mipmap, repeat_enable;

void vertex() {
	VERTEX = sway(VERTEX, MODEL_MATRIX);
}

void fragment() {
	// COLOR carries the baked occlusion, darkening the trunk where the canopy closes over it.
	ALBEDO = texture(u_bark, UV).rgb * COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	NORMAL_MAP = texture(u_bark_normal, UV).rgb;
	NORMAL_MAP_DEPTH = 0.4;
}
