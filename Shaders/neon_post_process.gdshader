shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec4 neon_cyan : source_color = vec4(0.0, 0.95, 1.0, 1.0);
uniform vec4 neon_magenta : source_color = vec4(1.0, 0.08, 0.86, 1.0);
uniform float edge_strength = 1.45;
uniform float glow_strength = 1.55;
uniform float glow_radius = 3.0;
uniform float background_dim = 0.28;
uniform float saturation = 1.55;
uniform float highlight_threshold = 0.48;
uniform float bloom_strength = 1.25;
uniform float bloom_radius = 4.0;
uniform float bloom_threshold = 0.5;
uniform float bloom_softness = 0.14;

float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

vec3 neon_tint(vec3 color, vec2 uv) {
	float warm_bias = color.r - color.g * 0.35 + color.b * 0.22;
	float scan_bias = sin((uv.x * 3.1 + uv.y * 2.2) * 6.28318) * 0.16;
	float blend_value = smoothstep(0.16, 0.84, warm_bias + scan_bias + 0.36);
	return mix(neon_cyan.rgb, neon_magenta.rgb, blend_value);
}

float highlight_mask(vec2 uv) {
	vec3 color = texture(screen_texture, uv).rgb;
	return smoothstep(highlight_threshold, 1.0, luminance(color));
}

vec4 neon_layer(vec2 uv, vec2 pixel) {
	vec4 source = texture(screen_texture, uv);
	float luma = luminance(source.rgb);

	float left = luminance(texture(screen_texture, uv + vec2(-pixel.x, 0.0)).rgb);
	float right = luminance(texture(screen_texture, uv + vec2(pixel.x, 0.0)).rgb);
	float up = luminance(texture(screen_texture, uv + vec2(0.0, -pixel.y)).rgb);
	float down = luminance(texture(screen_texture, uv + vec2(0.0, pixel.y)).rgb);
	float edge = abs(left - right) + abs(up - down);
	edge = smoothstep(0.035, 0.22, edge) * edge_strength;

	vec2 glow_pixel = pixel * glow_radius;
	float glow = highlight_mask(uv) * 0.48;
	glow += highlight_mask(uv + vec2(glow_pixel.x, 0.0)) * 0.12;
	glow += highlight_mask(uv + vec2(-glow_pixel.x, 0.0)) * 0.12;
	glow += highlight_mask(uv + vec2(0.0, glow_pixel.y)) * 0.12;
	glow += highlight_mask(uv + vec2(0.0, -glow_pixel.y)) * 0.12;
	glow += highlight_mask(uv + vec2(glow_pixel.x, glow_pixel.y) * 1.55) * 0.07;
	glow += highlight_mask(uv + vec2(-glow_pixel.x, glow_pixel.y) * 1.55) * 0.07;
	glow += highlight_mask(uv + vec2(glow_pixel.x, -glow_pixel.y) * 1.55) * 0.07;
	glow += highlight_mask(uv + vec2(-glow_pixel.x, -glow_pixel.y) * 1.55) * 0.07;

	vec3 tint = neon_tint(source.rgb, uv);
	vec3 saturated = mix(vec3(luma), source.rgb, saturation);
	vec3 base = saturated * background_dim;
	vec3 neon_lines = tint * edge;
	vec3 neon_glow = tint * glow * glow_strength;
	vec3 highlights = source.rgb * smoothstep(0.62, 1.0, luma) * 0.5;
	vec3 color = base + neon_lines + neon_glow + highlights;

	float generated_alpha = clamp(max(neon_lines.r, max(neon_lines.g, neon_lines.b)) * 0.35 + glow * 0.28, 0.0, 1.0);
	return vec4(clamp(color, vec3(0.0), vec3(1.0)), max(source.a, generated_alpha));
}

vec4 neon_bright_pass(vec2 uv, vec2 pixel) {
	vec4 neon = neon_layer(uv, pixel);
	float max_channel = max(neon.r, max(neon.g, neon.b));
	float mask = smoothstep(bloom_threshold, bloom_threshold + bloom_softness, max_channel) * neon.a;
	return vec4(neon.rgb * mask, mask);
}

vec4 neon_bloom_blur(vec2 uv, vec2 pixel) {
	vec2 radius = pixel * bloom_radius;
	vec4 bloom = vec4(0.0);

	bloom += neon_bright_pass(uv + radius * vec2(-2.0, -2.0), pixel) * 0.00390625;
	bloom += neon_bright_pass(uv + radius * vec2(-1.0, -2.0), pixel) * 0.015625;
	bloom += neon_bright_pass(uv + radius * vec2(0.0, -2.0), pixel) * 0.0234375;
	bloom += neon_bright_pass(uv + radius * vec2(1.0, -2.0), pixel) * 0.015625;
	bloom += neon_bright_pass(uv + radius * vec2(2.0, -2.0), pixel) * 0.00390625;

	bloom += neon_bright_pass(uv + radius * vec2(-2.0, -1.0), pixel) * 0.015625;
	bloom += neon_bright_pass(uv + radius * vec2(-1.0, -1.0), pixel) * 0.0625;
	bloom += neon_bright_pass(uv + radius * vec2(0.0, -1.0), pixel) * 0.09375;
	bloom += neon_bright_pass(uv + radius * vec2(1.0, -1.0), pixel) * 0.0625;
	bloom += neon_bright_pass(uv + radius * vec2(2.0, -1.0), pixel) * 0.015625;

	bloom += neon_bright_pass(uv + radius * vec2(-2.0, 0.0), pixel) * 0.0234375;
	bloom += neon_bright_pass(uv + radius * vec2(-1.0, 0.0), pixel) * 0.09375;
	bloom += neon_bright_pass(uv, pixel) * 0.140625;
	bloom += neon_bright_pass(uv + radius * vec2(1.0, 0.0), pixel) * 0.09375;
	bloom += neon_bright_pass(uv + radius * vec2(2.0, 0.0), pixel) * 0.0234375;

	bloom += neon_bright_pass(uv + radius * vec2(-2.0, 1.0), pixel) * 0.015625;
	bloom += neon_bright_pass(uv + radius * vec2(-1.0, 1.0), pixel) * 0.0625;
	bloom += neon_bright_pass(uv + radius * vec2(0.0, 1.0), pixel) * 0.09375;
	bloom += neon_bright_pass(uv + radius * vec2(1.0, 1.0), pixel) * 0.0625;
	bloom += neon_bright_pass(uv + radius * vec2(2.0, 1.0), pixel) * 0.015625;

	bloom += neon_bright_pass(uv + radius * vec2(-2.0, 2.0), pixel) * 0.00390625;
	bloom += neon_bright_pass(uv + radius * vec2(-1.0, 2.0), pixel) * 0.015625;
	bloom += neon_bright_pass(uv + radius * vec2(0.0, 2.0), pixel) * 0.0234375;
	bloom += neon_bright_pass(uv + radius * vec2(1.0, 2.0), pixel) * 0.015625;
	bloom += neon_bright_pass(uv + radius * vec2(2.0, 2.0), pixel) * 0.00390625;

	return bloom;
}

void fragment() {
	vec2 pixel = SCREEN_PIXEL_SIZE;
	vec4 neon = neon_layer(SCREEN_UV, pixel);
	vec4 bloom = neon_bloom_blur(SCREEN_UV, pixel) * bloom_strength;
	vec3 result = neon.rgb + bloom.rgb * (1.0 + bloom_strength);
	float alpha = max(neon.a, clamp(bloom.a * bloom_strength, 0.0, 1.0));

	COLOR = vec4(clamp(result, vec3(0.0), vec3(1.0)), alpha);
}
