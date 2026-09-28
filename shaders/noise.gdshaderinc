// NOISE_GLSL from reference/ukiyo-river.html (lines 184-188), plus a precision-safe variant.
// Shared by the sky and water shaders, as the prototype shares the string.

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

// h21 multiplies its input by 456.21 and takes the fractional part. Fed a lattice coordinate of
// a few hundred - which is what world-space xz over a 900 m river produces - that product lands
// where a 32-bit float only resolves to about 0.008, so neighbouring cells quantise onto the
// same hash and the noise collapses into flat, axis-aligned tiles. Wrapping the lattice onto a
// 512-cell torus first keeps the argument small and the hash sharp.
//
// The prototype has the same weakness; it simply never showed, because its water sampled a
// blurred half-resolution reflection target that hid the normal detail. A near-mirror Godot
// surface magnifies it into visible tiling, so the water shader uses these variants instead.
// The period is 512 cells, which at the water's noise scales is 320 m to 930 m of world space.
const float LATTICE_PERIOD = 512.0;

float h21_wrapped(vec2 p) {
	return h21(mod(p, LATTICE_PERIOD));
}

float vn_wrapped(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	// Each corner is wrapped independently so the field stays seamless across the period.
	return mix(
		mix(h21_wrapped(i), h21_wrapped(i + vec2(1.0, 0.0)), u.x),
		mix(h21_wrapped(i + vec2(0.0, 1.0)), h21_wrapped(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}
