// Sky, ported from the skyMat ShaderMaterial in reference/ukiyo-river.html (lines 184-220).
//
// The prototype drew this onto a back-side sphere pinned to the camera; Godot has a sky shader
// type, so the sphere, the renderOrder trick and the camera pinning all go away. vDir becomes
// EYEDIR and gl_FragColor becomes COLOR. Everything between is the prototype's maths unchanged.
shader_type sky;

// The colour uniforms are deliberately NOT tagged source_color: environment_controller.gd hands
// them over already converted to linear, and a source_color hint would convert them a second
// time and sink the whole sky into black. The defaults below are linear too.
uniform vec3 u_top = vec3(0.027, 0.039, 0.071);
uniform vec3 u_hor = vec3(0.141, 0.188, 0.282);
uniform vec3 u_fog = vec3(0.122, 0.157, 0.208);
uniform vec3 u_sun_col = vec3(0.624, 0.706, 0.847);
uniform vec3 u_sun_dir = vec3(0.35, 0.42, 0.8);
uniform float u_time = 0.0;
uniform float u_cloud : hint_range(0.0, 1.0) = 1.0;
uniform float u_flash = 0.0;
uniform float u_stars : hint_range(0.0, 1.0) = 1.0;
uniform float u_haze : hint_range(0.0, 1.0) = 0.0;

// NOISE_GLSL from the prototype.
float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(h21(i), h21(i + vec2(1.0, 0.0)), u.x),
		mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm5(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		s += a * vn(p);
		p = p * 2.02 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return s;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float y = d.y;

	vec3 col = mix(u_hor, u_top, smoothstep(0.0, 0.55, y));

	// Stars
	vec2 sg = d.xz / (max(y, 0.0) + 0.35) * 220.0;
	col += step(0.997, h21(floor(sg))) * u_stars * smoothstep(0.05, 0.35, y) * 0.8;

	// Sun or moon disc and its halo
	float s = max(dot(d, normalize(u_sun_dir)), 0.0);
	col += u_sun_col * (pow(s, 700.0) * 3.0 + pow(s, 40.0) * 0.22 + pow(s, 6.0) * 0.1);

	// Scrolling cloud deck
	vec2 cp = d.xz / (max(y, 0.0) + 0.15) * 0.9 + vec2(u_time * 0.006, u_time * 0.012);
	float c = fbm5(cp);
	float cl = smoothstep(0.62 - u_cloud * 0.45, 0.9 - u_cloud * 0.3, c);
	vec3 ccol = mix(u_hor * 0.5 + u_top * 0.2, u_hor * 1.05, fbm5(cp * 2.3 + 5.0));
	col = mix(col, ccol, cl * smoothstep(-0.02, 0.12, y));
	col += u_sun_col * pow(s, 12.0) * 0.25 * (1.0 - u_cloud) * cl;

	// Lightning
	col += u_flash * vec3(0.7, 0.74, 0.95) * (0.25 + cl * 0.9) * smoothstep(-0.1, 0.4, y);

	// Fade into the fog near and below the horizon
	col = mix(col, u_fog, (1.0 - smoothstep(-0.02, 0.22, y)) * 0.92);
	col = mix(col, u_fog, u_haze * 0.55);

	COLOR = col;
}
