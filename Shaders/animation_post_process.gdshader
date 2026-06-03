shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec3 ink_color = vec3(0.035, 0.03, 0.025);
uniform float color_steps = 5.0;
uniform float color_boost = 0.18;
uniform float shadow_softness = 0.28;
uniform float dark_contour_threshold = 0.10;
uniform float dark_contour_softness = 0.08;
uniform float edge_color_threshold = 0.18;
uniform float edge_color_softness = 0.14;
uniform float edge_ink_strength = 0.85;

float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

float sample_luminance(vec2 uv, vec2 offset) {
	return luminance(texture(screen_texture, uv + offset).rgb);
}

void fragment() {
	vec4 source = texture(screen_texture, SCREEN_UV);
	vec2 pixel = SCREEN_PIXEL_SIZE;

	vec3 posterized = floor(source.rgb * color_steps + 0.5) / color_steps;
	vec3 softened = mix(source.rgb, posterized, 1.0 - shadow_softness);
	vec3 boosted = mix(softened, min(softened * 1.12 + 0.06, vec3(1.0)), color_boost);

	float min_neighbor_luma = 1.0;
	min_neighbor_luma = min(min_neighbor_luma, sample_luminance(SCREEN_UV, vec2(-pixel.x, 0.0)));
	min_neighbor_luma = min(min_neighbor_luma, sample_luminance(SCREEN_UV, vec2(pixel.x, 0.0)));
	min_neighbor_luma = min(min_neighbor_luma, sample_luminance(SCREEN_UV, vec2(0.0, -pixel.y)));
	min_neighbor_luma = min(min_neighbor_luma, sample_luminance(SCREEN_UV, vec2(0.0, pixel.y)));
	min_neighbor_luma = min(min_neighbor_luma, sample_luminance(SCREEN_UV, vec2(-pixel.x, -pixel.y)));
	min_neighbor_luma = min(min_neighbor_luma, sample_luminance(SCREEN_UV, vec2(pixel.x, pixel.y)));
	min_neighbor_luma = min(min_neighbor_luma, sample_luminance(SCREEN_UV, vec2(pixel.x, -pixel.y)));
	min_neighbor_luma = min(min_neighbor_luma, sample_luminance(SCREEN_UV, vec2(-pixel.x, pixel.y)));

	float center_luma = luminance(source.rgb);
	float dark_neighbor = 1.0 - smoothstep(
		dark_contour_threshold,
		dark_contour_threshold + dark_contour_softness,
		min_neighbor_luma
	);
	float colored_edge_pixel = smoothstep(
		edge_color_threshold,
		edge_color_threshold + edge_color_softness,
		center_luma
	);
	float contour_leak_mask = dark_neighbor * colored_edge_pixel * clamp(source.a * 2.0, 0.0, 1.0);
	vec3 animation_color = mix(boosted, ink_color, contour_leak_mask * edge_ink_strength);

	COLOR = vec4(animation_color, source.a);
}
