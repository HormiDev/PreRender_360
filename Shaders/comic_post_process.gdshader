shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float color_steps = 4.0;
uniform float contrast = 1.18;
uniform float ink_strength = 0.32;
uniform float dot_scale = 3.5;
uniform float dot_opacity = 0.28;

float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec4 source = texture(screen_texture, SCREEN_UV);
	vec3 contrasted = clamp((source.rgb - 0.5) * contrast + 0.5, vec3(0.0), vec3(1.0));
	vec3 posterized = floor(contrasted * color_steps + 0.5) / color_steps;

	float luma = luminance(contrasted);
	vec2 cell = floor(FRAGCOORD.xy / dot_scale);
	vec2 local = fract(FRAGCOORD.xy / dot_scale) - vec2(0.5);
	float checker = mod(cell.x + cell.y, 2.0);
	float radius = mix(0.14, 0.46, 1.0 - luma);
	float dot_mask = 1.0 - smoothstep(radius, radius + 0.08, length(local));
	dot_mask *= 1.0 - checker * 0.35;
	dot_mask *= smoothstep(0.18, 0.82, 1.0 - luma);

	vec3 ink_color = vec3(0.035, 0.03, 0.025);
	vec3 comic_color = mix(posterized, ink_color, dot_mask * dot_opacity);
	comic_color = mix(comic_color, min(comic_color * 1.08 + 0.04, vec3(1.0)), ink_strength * 0.35);

	COLOR = vec4(comic_color, source.a);
}
