shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float color_steps = 5.0;
uniform float color_boost = 0.18;
uniform float shadow_softness = 0.28;

void fragment() {
	vec4 source = texture(screen_texture, SCREEN_UV);

	vec3 posterized = floor(source.rgb * color_steps + 0.5) / color_steps;
	vec3 softened = mix(source.rgb, posterized, 1.0 - shadow_softness);
	vec3 boosted = mix(softened, min(softened * 1.12 + 0.06, vec3(1.0)), color_boost);

	COLOR = vec4(boosted, source.a);
}
