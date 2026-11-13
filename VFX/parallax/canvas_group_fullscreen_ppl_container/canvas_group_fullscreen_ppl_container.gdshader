shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

// Pre-calculated values passed directly from the resource via script
uniform float radius : hint_range(0.0, 64.0, 0.1) = 0.0;
uniform float contrast_mult : hint_range(0.0, 2.0) = 1.0;
uniform float saturation_mult : hint_range(0.0, 1.0) = 1.0;
uniform float brightness : hint_range(0.0, 1.0) = 1.0;
uniform vec4 fog_color : source_color = vec4(0.75, 0.30, 0.10, 1.0);
uniform float fog_amount : hint_range(0.0, 1.0) = 0.0;
uniform int samples = 4;

void fragment() { 
	// Blur execution loop using the layer's unique pre-calculated radius
	float sigma = max(radius / 3.0, 0.001);
	float step_size = radius / float(samples);
	float inv_two_sigma_sq = 1.0 / (2.0 * sigma * sigma);

	vec4 accum = vec4(0.0);
	float total_weight = 0.0;

	if (radius < 0.1) {
		accum = texture(screen_texture, SCREEN_UV);
		accum = vec4(accum.rgb * accum.a, accum.a);
		total_weight = 1.0;
	} else {
		for (int y = -samples; y <= samples; y++) {
			for (int x = -samples; x <= samples; x++) {
				vec2 offset = vec2(float(x), float(y)) * step_size;
				float w = exp(-dot(offset, offset) * inv_two_sigma_sq);
				vec4 c = texture(screen_texture, SCREEN_UV + offset * SCREEN_PIXEL_SIZE);
				accum += vec4(c.rgb * c.a, c.a) * w;
				total_weight += w;
			}
		}
	}
	accum /= total_weight;
	vec3 color = accum.a > 0.0001 ? (accum.rgb / accum.a) : vec3(0.0);

	// 1. Apply brightness fade
	color *= brightness;

	// 2. Apply contrast adjustment
	color = mix(vec3(0.5), color, contrast_mult);

	// 3. Apply saturation adjustment
	float lum = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color = mix(vec3(lum), color, saturation_mult);

	// 4. Apply atmospheric fog tint & amount
	color = mix(color, fog_color.rgb, fog_amount);

	COLOR = accum.a > 0.0001 ? vec4(color, accum.a) : vec4(0.0);
}