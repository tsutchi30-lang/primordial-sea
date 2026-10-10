shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

uniform sampler2D thickness_map : source_color, filter_linear_mipmap;
uniform float rest_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 membrane = texture(thickness_map, UV);
    float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
    float grazing = pow(1.0 - facing, 2.0);
    // No TIME: deformation belongs to the paused game-time-driven SailRig.
    ALBEDO = membrane.rgb * (0.92 + 0.08 * UV.y) + vec3(0.025, 0.035, 0.025) * grazing;
    ROUGHNESS = mix(0.59, 0.43, UV.y);
    SPECULAR = 0.28;
    METALLIC = 0.0;
    ALPHA = clamp(membrane.a + grazing * 0.10 + rest_amount * 0.025, 0.24, 0.96);
}
