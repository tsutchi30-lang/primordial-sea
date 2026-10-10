shader_type spatial;
render_mode diffuse_burley;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float grain = sin(p.x * 17.0 + sin(p.y * 8.0)) * sin(p.y * 21.0) * 0.025;
	float ripple = sin(p.x * 1.8 + sin(p.y * 0.3) * 2.0) * 0.035;
	float a = abs(sin(p.x * 0.52 + sin(p.y * 0.31 + TIME * 0.18) * 1.4));
	float b = abs(sin(p.y * 0.61 - sin(p.x * 0.34 + TIME * 0.13) * 1.7));
	float caustic = pow(1.0 - min(a, b), 15.0) * 0.075;
	float shallow = clamp((world_position.y + 52.0) / 40.0, 0.1, 1.0);
	ALBEDO = COLOR.rgb * (0.78 + grain + ripple) + vec3(0.82, 0.9, 0.86) * caustic * shallow;
	ROUGHNESS = 0.94;
	EMISSION = COLOR.rgb * 0.008;
}
