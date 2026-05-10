shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float layer_strength = 0.88;
uniform float edge_strength = 0.28;
uniform float paper_grain = 0.050;
uniform float line_spacing = 5.6;
uniform float line_width = 0.125;
uniform float stroke_randomness = 0.84;
uniform float density_contrast = 0.78;
uniform float color_steps = 4.0;

float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float paper_tooth(vec2 coord) {
	return noise(coord * 0.040) * 0.55 + noise(coord * 0.240) * 0.45;
}

float pencil_stroke(vec2 coord, float angle, float spacing, float width, float seed, float pressure) {
	spacing = max(spacing, 0.001);

	float s = sin(angle);
	float c = cos(angle);
	float rough_across = -coord.x * s + coord.y * c;
	float rough_line = floor(rough_across / spacing);
	float line_angle = angle + (hash(vec2(rough_line, seed * 17.0)) - 0.5) * 0.14 * stroke_randomness;

	s = sin(line_angle);
	c = cos(line_angle);
	float along = coord.x * c + coord.y * s;
	float across = -coord.x * s + coord.y * c;
	float line_index = floor(across / spacing);

	float line_shift = (hash(vec2(line_index, seed * 3.1)) - 0.5) * spacing * 0.32 * stroke_randomness;
	float waviness = (noise(vec2(along * 0.010, line_index * 0.23 + seed)) - 0.5) * spacing * 0.18 * stroke_randomness;
	float adjusted_across = across + line_shift + waviness;
	float line = abs(fract(adjusted_across / spacing) - 0.5);
	float tooth = paper_tooth(vec2(along * 0.10, line_index * 0.31 + seed));
	float effective_width = width * mix(0.94, 1.06, tooth);
	float stroke = 1.0 - smoothstep(effective_width, effective_width + 0.044, line);

	float pressure_noise = mix(0.86, 1.05, noise(vec2(along * 0.012, line_index * 0.39 + seed)));

	return stroke * pressure * pressure_noise;
}

float channel_density(float channel, float luma, float saturation, float value) {
	float darkness = pow(clamp(1.0 - luma, 0.0, 1.0), density_contrast);
	float chroma_ink = channel * saturation;
	float shadow_ink = darkness * mix(0.95, 0.32, saturation);
	float white_guard = 1.0 - smoothstep(0.82, 1.0, value) * (1.0 - saturation);
	return clamp((chroma_ink + shadow_ink) * white_guard, 0.0, 1.0);
}

float color_layer(vec2 coord, float base_angle, float density, float seed) {
	float layer_1 = smoothstep(0.080, 0.160, density);
	float layer_2 = smoothstep(0.260, 0.340, density);
	float layer_3 = smoothstep(0.460, 0.560, density);
	float layer_4 = smoothstep(0.680, 0.820, density);

	float strokes = 0.0;
	strokes += pencil_stroke(coord, base_angle, line_spacing * 1.12, line_width * 0.90, seed, 0.40) * layer_1;
	strokes += pencil_stroke(coord, base_angle + 0.040, line_spacing * 0.92, line_width * 0.94, seed + 10.0, 0.42) * layer_2;
	strokes += pencil_stroke(coord, base_angle - 0.055, line_spacing * 0.74, line_width * 0.94, seed + 20.0, 0.42) * layer_3;
	strokes += pencil_stroke(coord, base_angle + 0.100, line_spacing * 0.58, line_width * 0.86, seed + 30.0, 0.38) * layer_4;
	return clamp(1.0 - exp(-strokes), 0.0, 1.0);
}

void fragment() {
	vec4 source = texture(screen_texture, SCREEN_UV);
	vec2 pixel = SCREEN_PIXEL_SIZE;
	float safe_color_steps = max(color_steps, 1.0);
	vec3 reduced_color = floor(source.rgb * safe_color_steps + vec3(0.5)) / safe_color_steps;
	float luma = luminance(reduced_color);
	float value = max(reduced_color.r, max(reduced_color.g, reduced_color.b));
	float min_channel = min(reduced_color.r, min(reduced_color.g, reduced_color.b));
	float saturation = (value - min_channel) / max(value, 0.001);

	float left = luminance(texture(screen_texture, SCREEN_UV + vec2(-pixel.x, 0.0)).rgb);
	float right = luminance(texture(screen_texture, SCREEN_UV + vec2(pixel.x, 0.0)).rgb);
	float up = luminance(texture(screen_texture, SCREEN_UV + vec2(0.0, -pixel.y)).rgb);
	float down = luminance(texture(screen_texture, SCREEN_UV + vec2(0.0, pixel.y)).rgb);
	float edge = abs(left - right) + abs(up - down);
	edge = smoothstep(0.055, 0.290, edge) * edge_strength;
	float contour_bias = clamp((right - left - down + up) * 1.80, -0.26, 0.26);

	float darkness = pow(clamp(1.0 - luma, 0.0, 1.0), density_contrast);
	float red_density = channel_density(reduced_color.r, luma, saturation, value);
	float green_density = channel_density(reduced_color.g, luma, saturation, value);
	float blue_density = channel_density(reduced_color.b, luma, saturation, value);

	float red_layer = color_layer(FRAGCOORD.xy, 0.68 + contour_bias * 0.44, red_density, 1.0);
	float green_layer = color_layer(FRAGCOORD.xy, 0.86 + contour_bias * 0.38, green_density, 2.0);
	float blue_layer = color_layer(FRAGCOORD.xy, 0.55 + contour_bias * 0.34, blue_density, 3.0);

	float grain = hash(floor(FRAGCOORD.xy)) - 0.5;
	float tooth = paper_tooth(FRAGCOORD.xy);
	vec3 paper = vec3(0.940, 0.925, 0.882) + grain * paper_grain + (tooth - 0.5) * paper_grain * 0.62;

	vec3 red_pigment = vec3(0.92, 0.045, 0.030);
	vec3 green_pigment = vec3(0.045, 0.72, 0.060);
	vec3 blue_pigment = vec3(0.050, 0.110, 0.95);

	float edge_layer = edge * (0.25 + darkness * 0.55);
	red_layer = clamp(red_layer + edge_layer, 0.0, 1.0);
	green_layer = clamp(green_layer + edge_layer, 0.0, 1.0);
	blue_layer = clamp(blue_layer + edge_layer, 0.0, 1.0);

	float stroke_sum = red_layer + green_layer + blue_layer;
	vec3 interlaced_mix = (
		red_pigment * red_layer +
		green_pigment * green_layer +
		blue_pigment * blue_layer
	) / max(stroke_sum, 0.001);
	float overlap = clamp(stroke_sum, 0.0, 1.0);
	vec3 result = mix(paper, interlaced_mix, overlap * layer_strength);
	result = mix(result, result * 0.88, darkness * overlap * 0.28);

	COLOR = vec4(clamp(result, vec3(0.0), vec3(1.0)), source.a);
}
