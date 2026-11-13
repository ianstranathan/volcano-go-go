shader_type canvas_item;

// CanvasGroup renders its children to a buffer, which this exposes
// through the screen texture.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

// Blur radius in screen pixels.
uniform float radius : hint_range(0.0, 64.0, 0.1) = 8.0;

// Samples per side of the kernel (total = (2n+1)^2).
// Higher = smoother, but more expensive.
uniform int samples : hint_range(1, 16, 1) = 4;

void fragment() {
	//if (radius <= 0.001) {
		//COLOR = texture(screen_texture, SCREEN_UV);
	//} else {
	float sigma = radius / 3.0; // kernel reaches ~3 sigma at the edge
	float step_size = radius / float(samples);
	float inv_two_sigma_sq = 1.0 / (2.0 * sigma * sigma);

	vec4 accum = vec4(0.0);
	float total_weight = 0.0;

	for (int y = -samples; y <= samples; y++) {
		for (int x = -samples; x <= samples; x++) {
			vec2 offset = vec2(float(x), float(y)) * step_size;
			float w = exp(-dot(offset, offset) * inv_two_sigma_sq);

			vec4 c = texture(screen_texture, SCREEN_UV + offset * SCREEN_PIXEL_SIZE);

			// Accumulate premultiplied so transparent pixels don't darken edges.
			accum += vec4(c.rgb * c.a, c.a) * w;
			total_weight += w;
		}
	}
	accum /= total_weight;
	// Un-premultiply back for Godot's standard blend mode.
	COLOR = accum.a > 0.0001 ? vec4(accum.rgb / accum.a, accum.a) : vec4(0.0);
//}
}