shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float warmth = 0.11;
uniform float shadow_warmth = 0.16;
uniform float saturation = 0.88;
uniform float contrast = 0.92;
uniform float paint_strength = 0.34;
uniform float paper_grain = 0.035;

float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec4 source = texture(screen_texture, SCREEN_UV);
	float luma = luminance(source.rgb);

	vec3 warm_light = vec3(1.04, 1.01, 0.94);
	vec3 warm_shadow = vec3(0.92, 0.96, 1.04);
	vec3 temperature = mix(warm_shadow, warm_light, smoothstep(0.2, 0.9, luma));
	vec3 graded = source.rgb * mix(vec3(1.0), temperature, warmth + (1.0 - luma) * shadow_warmth);

	float soft_luma = luminance(graded);
	vec3 gray = vec3(soft_luma);
	graded = mix(gray, graded, saturation);
	graded = (graded - 0.5) * contrast + 0.5;

	vec3 painted = floor(clamp(graded, vec3(0.0), vec3(1.0)) * 8.0 + 0.5) / 8.0;
	graded = mix(graded, painted, paint_strength);

	float grain = hash(floor(FRAGCOORD.xy)) - 0.5;
	graded += grain * paper_grain * (0.65 + (1.0 - luma) * 0.35);

	COLOR = vec4(clamp(graded, vec3(0.0), vec3(1.0)), source.a);
}
