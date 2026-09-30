// Foliage cards. Alpha-cut quads whose normals point out of the crown rather than out of the
// quad, so a flat card lights like part of a canopy - the prototype's nFn.
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

#include "res://shaders/tree_sway.gdshaderinc"

uniform sampler2D u_foliage : source_color, filter_linear_mipmap;

void vertex() {
	VERTEX = sway(VERTEX, MODEL_MATRIX);
}

void fragment() {
	vec4 sample_colour = texture(u_foliage, UV);
	// COLOR is the vertex occlusion times the MultiMesh instance tint.
	ALBEDO = sample_colour.rgb * COLOR.rgb;
	ALPHA = sample_colour.a;
	// Prototype alphaTest: 0.42.
	ALPHA_SCISSOR_THRESHOLD = 0.42;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
