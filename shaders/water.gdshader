// River surface, ported from the waterMat ShaderMaterial in reference/ukiyo-river.html
// (lines 245-342).
//
// The wave sum, flow noise, rain ripples, boat wake, stern foam, lantern and sun speculars and
// the hull cut-out are the prototype's maths unchanged. Three things are done the Godot way:
//
//   * Reflections. The prototype rendered the scene a second time through a mirrored camera into
//     a render target and sampled it with `mix(deep, refl, fres + 0.3)`. Here the surface hands
//     the engine a normal and a low roughness and lets Environment SSR, the reflection probe and
//     the sky do the work. See PORT_LOG.md - the prototype's 30% reflection floor at normal
//     incidence is not physical and is approximated by u_refl_boost.
//   * Fog. The prototype's hand-rolled exp-squared term is gone; Environment fog covers it.
//   * The additive highlight terms become EMISSION rather than being summed into gl_FragColor.
shader_type spatial;
render_mode world_vertex_coords, cull_back, specular_schlick_ggx;

#include "res://shaders/noise.gdshaderinc"

// Driven every frame by environment_controller.gd. Colours arrive already linear, so none of
// these carry a source_color hint (see the same note in sky.gdshader).
uniform float u_time = 0.0;
uniform float u_wind = 1.0;
uniform float u_rain : hint_range(0.0, 1.0) = 1.0;
uniform float u_flash = 0.0;
uniform float u_ambient : hint_range(0.0, 1.0) = 0.3;
uniform float u_cloud : hint_range(0.0, 1.0) = 1.0;
uniform vec3 u_deep = vec3(0.007, 0.011, 0.017);
uniform vec3 u_sun_dir = vec3(0.35, 0.42, 0.8);
uniform vec3 u_sun_col = vec3(0.347, 0.456, 0.687);

// Boat couplings. Defaults put the boat far outside the plane so nothing is cut out and no wake
// appears until boat.gd starts writing them in Phase 3.
uniform vec2 u_boat = vec2(0.0, 100000.0);
uniform vec2 u_boat_dir = vec2(0.0, 1.0);
uniform float u_speed_n : hint_range(0.0, 1.0) = 0.0;
uniform vec3 u_lamp_pos = vec3(0.0, 2.32, 100000.0);
uniform vec3 u_lamp_col = vec3(1.0, 0.45, 0.1);

// Stands in for the prototype's non-physical reflection floor. 0 is pure Fresnel.
uniform float u_refl_boost : hint_range(0.0, 1.0) = 0.3;
uniform float u_roughness : hint_range(0.0, 0.5) = 0.02;

varying vec3 v_world;

// WAVE_GLSL: x is the height, yz is the gradient.
vec3 waves(vec2 p, float t) {
	vec3 r = vec3(0.0);
	float ph;
	ph = dot(p, vec2(0.21, 0.13)) + t * 1.3;
	r += vec3(sin(ph), cos(ph) * vec2(0.21, 0.13)) * 0.06;
	ph = dot(p, vec2(-0.17, 0.29)) + t * 1.7;
	r += vec3(sin(ph), cos(ph) * vec2(-0.17, 0.29)) * 0.05;
	ph = dot(p, vec2(0.41, -0.23)) + t * 2.3;
	r += vec3(sin(ph), cos(ph) * vec2(0.41, -0.23)) * 0.035;
	ph = dot(p, vec2(-0.33, -0.47)) + t * 2.9;
	r += vec3(sin(ph), cos(ph) * vec2(-0.33, -0.47)) * 0.025;
	return r * u_wind;
}

vec2 noise_grad(vec2 p) {
	float e = 0.15;
	float c = vn_wrapped(p);
	return vec2(vn_wrapped(p + vec2(e, 0.0)) - c, vn_wrapped(p + vec2(0.0, e)) - c) / e;
}

// Expanding rings where the rain lands: one per cell of a jittered grid, 3x3 neighbourhood.
vec2 ripples(vec2 p, float t, float scale, float seed, float density) {
	vec2 g = p * scale;
	vec2 id = floor(g);
	vec2 f = fract(g);
	vec2 grad = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 o = vec2(float(i), float(j));
			vec2 cid = id + o;
			float r1 = h21_wrapped(cid + seed);
			if (r1 > density) {
				continue;
			}
			float r2 = h21_wrapped(cid + seed + 17.13);
			float r3 = h21_wrapped(cid + seed + 41.7);
			vec2 d = f - (o + vec2(r2, r3));
			float dist = length(d);
			float ph = fract(t * 1.1 + r1 * 7.31 + r2 * 3.1);
			float x = dist - ph * 0.9;
			float ring = sin(x * 32.0) * (1.0 - smoothstep(0.0, 0.12, abs(x))) * (1.0 - ph) * (1.0 - ph);
			grad += d / (dist + 1e-4) * ring;
		}
	}
	return grad;
}

void vertex() {
	// world_vertex_coords means VERTEX is already in world space here.
	VERTEX.y += waves(VERTEX.xz, u_time).x;
	v_world = VERTEX;
}

void fragment() {
	// Cut the water out of the hull footprint, using the prototype's sec() profile inline.
	vec2 bq = v_world.xz - u_boat;
	float al = dot(bq, u_boat_dir);
	float lt = dot(bq, vec2(u_boat_dir.y, -u_boat_dir.x));
	float tt = al / 8.2 + 0.5;
	// Prototype starts the cut-out at tt = 0.03, which leaves a 25 cm band of water standing
	// inside the transom. It never showed there; against a near-mirror surface it catches the
	// lantern and blows out to white, so the cut-out runs to the transom itself at tt = 0.
	if (tt > 0.0 && tt < 0.93) {
		float bw = smoothstep(0.55, 1.0, tt);
		float st = 1.0 - smoothstep(0.0, 0.18, tt);
		float hb = 1.05 * (1.0 - pow(bw, 1.8) * 0.97) * (1.0 - st * 0.35);
		if (abs(lt) < hb * 0.86 - 0.08) {
			discard;
		}
	}

	vec2 p = v_world.xz;

	// Wave gradient, then the flow noise drifting downstream on top of it.
	vec2 g = waves(p, u_time).yz;
	vec2 flow = vec2(0.0, u_time * 0.35);
	g += (noise_grad(p * 0.55 - flow) * 0.10 + noise_grad(p * 1.6 - flow * 1.4) * 0.05)
		* (0.5 + u_wind * 0.5);

	float cam_dist = length(CAMERA_POSITION_WORLD - v_world);
	float lod = exp(-cam_dist * 0.035);
	if (u_rain > 0.01) {
		g += (ripples(p, u_time, 1.15, 3.0, u_rain * 0.85) * 0.55
			+ ripples(p, u_time * 1.3, 2.4, 11.0, u_rain * 0.7) * 0.35) * lod;
	}

	// Bow wave: concentric ring travelling out from the boat, scaled by its speed.
	vec2 bd = p - u_boat;
	float bdist = length(bd);
	g += bd / (bdist + 1e-3) * cos(bdist * 2.4 - u_time * 6.0) * exp(-bdist * 0.22) * u_speed_n * 0.35;

	vec3 n = normalize(vec3(-g.x, 1.0, -g.y));
	vec3 V = normalize(CAMERA_POSITION_WORLD - v_world);
	float ndv = max(dot(n, V), 0.0);
	float fres = 0.12 + 0.88 * pow(1.0 - ndv, 4.0);

	// Body colour. The prototype mixes this with its mirror texture; here the engine's
	// reflections are layered on top through ROUGHNESS and SPECULAR instead.
	ALBEDO = u_deep * (0.35 + 0.65 * u_ambient);
	METALLIC = 0.0;
	ROUGHNESS = u_roughness + u_rain * 0.02;
	SPECULAR = clamp(0.5 + u_refl_boost * fres, 0.0, 1.0);
	// Godot wants a view-space normal here.
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	vec3 highlight = vec3(0.0);

	// Bow lantern: a tight specular plus a soft pool of light on the water.
	vec3 lv = u_lamp_pos - v_world;
	float ld = length(lv);
	vec3 l_dir = lv / ld;
	highlight += u_lamp_col * pow(max(dot(n, normalize(l_dir + V)), 0.0), 140.0) * 1.8
		/ (1.0 + ld * ld * 0.02);
	highlight += u_lamp_col * 0.09 / (1.0 + ld * ld * 0.08);

	// Sun or moon glitter, cut back by cloud.
	highlight += u_sun_col * pow(max(dot(n, normalize(normalize(u_sun_dir) + V)), 0.0), 400.0)
		* 1.2 * (1.0 - u_cloud * 0.8);

	// Foam in the wake behind the stern.
	vec2 back = -u_boat_dir;
	vec2 side = vec2(back.y, -back.x);
	float along = dot(bd, back);
	float lat = dot(bd, side);
	float foam = step(0.0, along) * exp(-along * 0.06)
		* exp(-abs(lat) / (0.5 + max(along, 0.0) * 0.12) * 1.5) * u_speed_n;
	foam *= 0.5 + 0.5 * vn_wrapped(p * 3.0 + u_time * 2.0);
	highlight += vec3(0.55, 0.6, 0.62) * foam * 0.35 * (0.3 + u_ambient);

	// Lightning picks out the surface.
	highlight += u_flash * vec3(0.5, 0.55, 0.7) * (0.2 + fres * 0.6);

	EMISSION = highlight;
}
