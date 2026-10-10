shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

varying vec3 world_position;

void vertex() {
	VERTEX.y += sin(VERTEX.x * 0.16 + TIME * 0.5) * 0.06 + sin(VERTEX.z * 0.2 + TIME * 0.37) * 0.045;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float wave = sin(p.x * 0.48 + sin(p.y * 0.23 + TIME * 0.3)) * sin(p.y * 0.41 + TIME * 0.21);
	float shine = pow(abs(wave), 10.0);
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);
	ALBEDO = mix(vec3(0.09, 0.43, 0.44), vec3(0.47, 0.82, 0.77), fresnel) + vec3(0.13, 0.19, 0.15) * shine;
	ALPHA = FRONT_FACING ? 0.52 : 0.28;
}
