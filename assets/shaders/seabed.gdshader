shader_type spatial;
render_mode diffuse_burley;

uniform float sea_time = 0.0;
varying vec3 world_position;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1,0)), f.x),
		mix(hash2(i + vec2(0,1)), hash2(i + vec2(1,1)), f.x), f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float deposits = noise2(p * 0.22);
	float bend = noise2(p * 0.43);
	float wave = p.x * 4.2 + p.y * 0.85 + bend * 4.5;
	// Broad ripple slopes and narrow troughs alternate with quiet open sand.
	float ripples = sin(wave);
	float ripple_strength = smoothstep(0.28, 0.68, deposits);
	float grain = (noise2(p * 60.0) - 0.5) * 0.055;
	vec3 sand = mix(vec3(0.32,0.34,0.32), vec3(0.53,0.52,0.47), deposits);
	sand *= 0.97 + ripples * ripple_strength * 0.055 + grain;
	// Sparse caustic seams decay with depth and follow paused game time.
	vec2 drift = vec2(sea_time * 0.035, sea_time * -0.022);
	float a = sin(p.x * 0.59 + sin(p.y * 0.43 + drift.x) * 1.9 + drift.y);
	float b = sin(p.y * 0.63 - sin(p.x * 0.37 + drift.y) * 1.7);
	float seam = pow(max(0.0, 1.0 - abs(a + b) * 0.75), 22.0);
	float shallow = clamp((world_position.y + 48.0) / 35.0, 0.08, 0.9);
	ALBEDO = sand + vec3(0.027,0.032,0.030) * seam * shallow;
	NORMAL_MAP = normalize(vec3(cos(wave) * ripple_strength * 0.03, 0.006 * sin(p.y * 9.0), 1.0)) * 0.5 + 0.5;
	ROUGHNESS = 0.97;
	SPECULAR = 0.1;
}
