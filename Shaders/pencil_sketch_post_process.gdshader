shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float edge_strength = 0.48;
uniform float hatch_strength = 0.78;
uniform float paper_grain = 0.060;
uniform float line_spacing = 5.6;
uniform float line_width = 0.130;
uniform float stroke_randomness = 0.90;
uniform float stroke_angle = 0.72;
uniform float density_contrast = 0.82;
uniform float tone_steps = 4.0;

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
	return noise(coord * 0.040) * 0.55 + noise(coord * 0.230) * 0.45;
}

float pencil_stroke(vec2 coord, float angle, float spacing, float width, float seed, float pressure) {
	spacing = max(spacing, 0.001);

	float s = sin(angle);
	float c = cos(angle);
	float rough_across = -coord.x * s + coord.y * c;
	float rough_line = floor(rough_across / spacing);
	float line_angle = angle + (hash(vec2(rough_line, seed * 17.0)) - 0.5) * 0.16 * stroke_randomness;

	s = sin(line_angle);
	c = cos(line_angle);
	float along = coord.x * c + coord.y * s;
	float across = -coord.x * s + coord.y * c;
	float line_index = floor(across / spacing);

	float line_shift = (hash(vec2(line_index, seed * 3.1)) - 0.5) * spacing * 0.34 * stroke_randomness;
	float waviness = (noise(vec2(along * 0.010, line_index * 0.23 + seed)) - 0.5) * spacing * 0.20 * stroke_randomness;
	float adjusted_across = across + line_shift + waviness;
	float line = abs(fract(adjusted_across / spacing) - 0.5);
	float tooth = paper_tooth(vec2(along * 0.10, line_index * 0.31 + seed));
	float effective_width = width * mix(0.94, 1.06, tooth);
	float stroke = 1.0 - smoothstep(effective_width, effective_width + 0.045, line);

	float pressure_noise = mix(0.86, 1.06, noise(vec2(along * 0.012, line_index * 0.37 + seed)));

	return stroke * pressure * pressure_noise;
}

void fragment() {
	vec4 source = texture(screen_texture, SCREEN_UV);
	vec2 pixel = SCREEN_PIXEL_SIZE;
	float luma = luminance(source.rgb);
	float safe_tone_steps = max(tone_steps, 1.0);
	float reduced_luma = floor(luma * safe_tone_steps + 0.5) / safe_tone_steps;

	float left = luminance(texture(screen_texture, SCREEN_UV + vec2(-pixel.x, 0.0)).rgb);
	float right = luminance(texture(screen_texture, SCREEN_UV + vec2(pixel.x, 0.0)).rgb);
	float up = luminance(texture(screen_texture, SCREEN_UV + vec2(0.0, -pixel.y)).rgb);
	float down = luminance(texture(screen_texture, SCREEN_UV + vec2(0.0, pixel.y)).rgb);
	float edge = abs(left - right) + abs(up - down);
	edge = smoothstep(0.055, 0.280, edge) * edge_strength;

	float darkness = pow(clamp(1.0 - reduced_luma, 0.0, 1.0), density_contrast);
	float contour_bias = clamp((right - left - down + up) * 1.85, -0.28, 0.28);
	float angle = stroke_angle + contour_bias;

	float layer_1 = smoothstep(0.080, 0.150, darkness);
	float layer_2 = smoothstep(0.220, 0.290, darkness);
	float layer_3 = smoothstep(0.360, 0.440, darkness);
	float layer_4 = smoothstep(0.510, 0.590, darkness);
	float layer_5 = smoothstep(0.660, 0.740, darkness);
	float layer_6 = smoothstep(0.800, 0.900, darkness);

	float hatch = 0.0;
	hatch += pencil_stroke(FRAGCOORD.xy, angle, line_spacing * 1.12, line_width * 0.92, 1.0, 0.42) * layer_1;
	hatch += pencil_stroke(FRAGCOORD.xy, angle + 0.035, line_spacing * 0.96, line_width * 0.96, 2.0, 0.44) * layer_2;
	hatch += pencil_stroke(FRAGCOORD.xy, angle - 0.050, line_spacing * 0.82, line_width * 0.96, 3.0, 0.44) * layer_3;
	hatch += pencil_stroke(FRAGCOORD.xy, angle + 0.085, line_spacing * 0.68, line_width * 0.90, 4.0, 0.40) * layer_4;
	hatch += pencil_stroke(FRAGCOORD.xy, angle - 0.105, line_spacing * 0.56, line_width * 0.84, 5.0, 0.38) * layer_5;
	hatch += pencil_stroke(FRAGCOORD.xy, angle + 0.145, line_spacing * 0.46, line_width * 0.78, 6.0, 0.36) * layer_6;

	float compressed_hatch = 1.0 - exp(-(hatch * hatch_strength));
	float graphite_fill = smoothstep(0.72, 1.0, darkness) * paper_tooth(FRAGCOORD.xy * 0.70 + vec2(93.0, 47.0)) * 0.16;
	float pencil = clamp(edge + compressed_hatch + graphite_fill, 0.0, 1.0);

	float grain = hash(floor(FRAGCOORD.xy)) - 0.5;
	float tooth = paper_tooth(FRAGCOORD.xy);
	vec3 paper = vec3(0.935, 0.920, 0.875) + grain * paper_grain + (tooth - 0.5) * paper_grain * 0.60;
	vec3 graphite = vec3(0.045, 0.043, 0.040);
	vec3 sketch = mix(paper * (1.0 - darkness * 0.045), graphite, pencil);

	COLOR = vec4(clamp(sketch, vec3(0.0), vec3(1.0)), source.a);
}
