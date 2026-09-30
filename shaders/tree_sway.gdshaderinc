// Wind sway, ported from swayMat's onBeforeCompile in reference/ukiyo-river.html (lines 896-909).
//
// The whole tree leans on a slow phase offset by its world position, so neighbouring trees move
// together but not in lockstep; foliage adds a faster flutter on top. u_height is the species'
// nominal height and u_flutter is 0 for trunks.
//
// The prototype reads the per-instance offset from instanceMatrix[3]; MODEL_MATRIX carries the
// same thing for a MultiMesh instance.

uniform float u_time = 0.0;
uniform float u_wind = 1.0;
uniform float u_height = 15.0;
uniform float u_flutter = 0.0;

vec3 sway(vec3 p, mat4 model) {
	float h_n = max(p.y, 0.0) / u_height;
	float amount = u_wind * 0.028 * h_n * h_n * u_height;
	vec2 ip = vec2(model[3][0], model[3][2]);
	float phase = u_time * 1.6 + ip.x * 0.05 + ip.y * 0.07;
	vec3 out_p = p;
	out_p.x += sin(phase) * amount
		+ sin(u_time * 5.3 + p.x * 3.0 + p.z * 2.0 + ip.x) * u_flutter * u_wind * 0.05 * h_n;
	out_p.z += cos(phase * 0.83) * amount * 0.7
		+ cos(u_time * 4.7 + p.y * 3.0 + ip.y) * u_flutter * u_wind * 0.05 * h_n;
	return out_p;
}
