shader_type spatial;
render_mode diffuse_burley, cull_disabled;

uniform vec4 base_color : source_color = vec4(0.51, 0.55, 0.50, 1.0);
uniform bool porous = false;
uniform bool use_vertex_color = false;
varying vec3 world_point;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(cell), hash3(cell + vec3(1,0,0)), f.x),
		mix(hash3(cell + vec3(0,1,0)), hash3(cell + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash3(cell + vec3(0,0,1)), hash3(cell + vec3(1,0,1)), f.x),
		mix(hash3(cell + vec3(0,1,1)), hash3(cell + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 p = world_point;
	vec3 color = use_vertex_color ? COLOR.rgb : base_color.rgb;
	float broad = noise3(p * 0.75);
	float fine = noise3(p * (porous ? 22.0 : 7.0));
	float grain = noise3(p * 56.0);
	if (porous) {
		float pores = smoothstep(0.66, 0.80, fine);
		ALBEDO = color * (0.86 + broad * 0.18 - pores * 0.09 + grain * 0.025);
		ROUGHNESS = 0.91 + grain * 0.08;
	} else {
		float strata = sin(p.y * 4.4 + p.x * 0.33 + broad * 2.0) * 0.05;
		float breaks = smoothstep(0.67, 0.83, fine) * 0.035;
		ALBEDO = color * (0.82 + broad * 0.20 + strata - breaks + grain * 0.015);
		ROUGHNESS = 0.88 + fine * 0.1;
	}
	SPECULAR = 0.16;
}
