shader_type canvas_item;
render_mode unshaded;

// filter_linear is essential: the hardware does the texel averaging.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

// false: 5x5 kernel in 3x3 = 9 taps. true: 9x9 kernel in 5x5 = 25 taps.
uniform bool wide_kernel = true;
// Scales tap offsets, so the blur gets wider at the same cost (blocky past ~2).
uniform float spread : hint_range(0.5, 4.0) = 1.0;

// Linear-sampling offsets/weights (RasterGrid). Weights already sum to 1.
const float OFF9[3] = float[](0.0, 1.3846153846, 3.2307692308);
const float WGT9[3] = float[](0.2270270270, 0.3162162162, 0.0702702703);
// Binomial 1 4 6 4 1 / 16 merged into 3 taps.
const float OFF5[3] = float[](0.0, 1.2, 0.0);
const float WGT5[3] = float[](0.375, 0.3125, 0.0);

void fragment() {
	int r = wide_kernel ? 2 : 1;
	vec2 px = SCREEN_PIXEL_SIZE * spread;
	vec4 acc = vec4(0.0);

	for (int i = -r; i <= r; i++) {
		int ai = abs(i);
		float ox = (wide_kernel ? OFF9[ai] : OFF5[ai]) * sign(float(i));
		float wx = wide_kernel ? WGT9[ai] : WGT5[ai];
		for (int j = -r; j <= r; j++) {
			int aj = abs(j);
			float oy = (wide_kernel ? OFF9[aj] : OFF5[aj]) * sign(float(j));
			float wy = wide_kernel ? WGT9[aj] : WGT5[aj];
			acc += wx * wy * textureLod(screen_texture, SCREEN_UV + vec2(ox, oy) * px, 0.0);
		}
	}

	// Un-premultiply, same as the built-in CanvasGroup shader
	if (acc.a > 0.0001) {
		acc.rgb /= acc.a;
	}
	COLOR *= acc;
}

// 2nd
//shader_type canvas_item;
//render_mode unshaded;
//
//uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
//
//// Kernel half-size in texels. 5 = the 11x11 kernel from the reference.
//uniform int radius : hint_range(1, 16) = 5;
//uniform float sigma : hint_range(0.1, 16.0) = 7.0;
//// Scales tap offsets; >1 widens the blur at the same cost (blockier past ~2).
//uniform float spread : hint_range(0.5, 4.0) = 1.0;
//
//float g(float x, float s) {
	//return exp(-0.5 * x * x / (s * s));
//}
//
//void fragment() {
	//// Build merged 1-D taps: offset + weight, pairing neighbours into one bilinear fetch.
	//float offs[17];
	//float wts[17];
	//int n = 0;
//
	//offs[n] = 0.0;
	//wts[n] = g(0.0, sigma);
	//n++;
//
	//for (int k = 1; k <= radius; k += 2) {
		//float w1 = g(float(k), sigma);
		//float o;
		//float w;
		//if (k + 1 <= radius) {
			//float w2 = g(float(k + 1), sigma);
			//w = w1 + w2;
			//o = (float(k) * w1 + float(k + 1) * w2) / w;
		//} else {
			//w = w1;
			//o = float(k);
		//}
		//// Mirror to both sides
		//offs[n] = o;  wts[n] = w;  n++;
		//offs[n] = -o; wts[n] = w;  n++;
	//}
//
	//vec4 acc = vec4(0.0);
	//float wsum = 0.0;
	//for (int i = 0; i < n; i++) {
		//for (int j = 0; j < n; j++) {
			//float w = wts[i] * wts[j];
			//vec2 off = vec2(offs[i], offs[j]) * spread * SCREEN_PIXEL_SIZE;
			//acc += w * textureLod(screen_texture, SCREEN_UV + off, 0.0);
			//wsum += w;
		//}
	//}
	//acc /= wsum;
//
	//if (acc.a > 0.0001) {
		//acc.rgb /= acc.a;
	//}
	//COLOR *= acc;
//}

//shader_type canvas_item;
//render_mode unshaded;
//
//uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
//
//group_uniforms blur;
//// Blur strength, in pixels of the texture being rendered to.
//uniform float blur_strength : hint_range(0.1, 32.0) = 4.0;
//// false = grid (taps = (2r+1)^2), true = spiral (taps = spiral_samples)
//uniform bool use_spiral = true;
//
//group_uniforms grid;
//// Taps per side of center. 1 -> 9 taps, 2 -> 25, 3 -> 49, 5 -> 121.
//uniform int radius : hint_range(1, 8) = 2;
//// If on, tap spacing is chosen so the grid covers ~2 blur_strength. Off = use manual_spread.
//uniform bool auto_spread = true;
//uniform float manual_spread : hint_range(0.5, 8.0) = 1.0;
//
//group_uniforms spiral;
//// Total taps. 8-16 is usually enough with jitter.
//uniform int spiral_samples : hint_range(2, 64) = 32;
//
//group_uniforms dither;
//// Per-pixel noise rotation/offset to hide banding at low tap counts. 0 = off.
//uniform float jitter : hint_range(0.0, 1.0) = 1.0;
//
//// Interleaved gradient noise, cheap and well distributed
//float ign(vec2 p) {
	//return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
//}
//
//void fragment() {
	//vec2 px = SCREEN_PIXEL_SIZE;
	//float noise = ign(FRAGCOORD.xy) * jitter;
	//vec4 acc = vec4(0.0);
//
	//if (use_spiral) {
		//// Vogel spiral with radii distributed as a 2D gaussian (Rayleigh),
		//// so every tap has equal weight and no normalization is needed.
		//float n = float(spiral_samples);
		//for (int k = 0; k < spiral_samples; k++) {
			//float u = (float(k) + 0.5) / n;
			//float r = blur_strength * sqrt(-2.0 * log(1.0 - u));
			//float a = float(k) * 2.39996323 + noise * TAU;
			//vec2 off = vec2(cos(a), sin(a)) * r * px;
			//acc += textureLod(screen_texture, SCREEN_UV + off, 0.0);
		//}
		//acc /= n;
	//} else {
		//float spread = auto_spread ? max(1.0, 2.0 * blur_strength / float(radius)) : manual_spread;
		//float inv2s2 = 0.5 / (blur_strength * blur_strength);
		//float wsum = 0.0;
		//// Jitter shifts the whole grid by up to half a tap
		//vec2 shift = (vec2(noise, fract(noise * 7.31)) - 0.5) * spread * jitter;
		//for (int i = -radius; i <= radius; i++) {
			//float dx = float(i) * spread;
			//float wx = exp(-dx * dx * inv2s2);
			//for (int j = -radius; j <= radius; j++) {
				//float dy = float(j) * spread;
				//float w = wx * exp(-dy * dy * inv2s2);
				//acc += w * textureLod(screen_texture, SCREEN_UV + (vec2(dx, dy) + shift) * px, 0.0);
				//wsum += w;
			//}
		//}
		//acc /= wsum;
	//}
//
	//// Un-premultiply, same as the built-in CanvasGroup shader
	//if (acc.a > 0.0001) {
		//acc.rgb /= acc.a;
	//}
	//COLOR *= acc;
//}