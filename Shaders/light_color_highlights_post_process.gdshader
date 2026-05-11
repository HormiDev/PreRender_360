shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec4 light_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float highlight_threshold = 0.58;
uniform float highlight_softness = 0.24;
uniform float highlight_focus = 1.85;
uniform float light_tint_strength = 0.92;
uniform float grayscale_contrast = 1.08;

float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

vec3 safe_light_color(vec3 color) {
	float peak = max(color.r, max(color.g, color.b));
	if (peak <= 0.001) {
		return vec3(1.0);
	}
	return color / peak;
}

void fragment() {
	vec4 source = texture(screen_texture, SCREEN_UV);
	float luma = luminance(source.rgb);
	float gray_value = clamp((luma - 0.5) * grayscale_contrast + 0.5, 0.0, 1.0);
	vec3 grayscale = vec3(gray_value);

	float highlight_mask = smoothstep(
		highlight_threshold,
		highlight_threshold + highlight_softness,
		luma
	);
	highlight_mask = pow(highlight_mask, highlight_focus);

	vec3 light_tint = safe_light_color(light_color.rgb);
	vec3 colored_light = light_tint * min(gray_value * 1.18 + 0.06, 1.0);
	vec3 result = mix(grayscale, mix(grayscale, colored_light, light_tint_strength), highlight_mask);

	COLOR = vec4(clamp(result, vec3(0.0), vec3(1.0)), source.a);
}
