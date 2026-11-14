shader_type canvas_item;

/*
 * VACUUM SUCTION (Luigi's Mansion style) - Godot 4.x, Sprite2D friendly
 * ---------------------------------------------------------------------
 * Everything happens in fragment() as an INVERSE UV warp:
 * for every screen pixel we compute "which source pixel should I show here?".
 * To make the ghost look smaller we therefore sample FARTHER from the target,
 * to make it look rotated by +a we sample rotated by -a, and so on.
 *
 * COORDINATE SPACE
 *   target_pos and ghost_center are in the sprite's UV space:
 *   (0,0) = top-left of the texture, (1,1) = bottom-right.
 *   Values outside 0..1 are allowed (nozzle outside the sprite) - the helper
 *   in the GDScript converts global positions for you.
 *
 * IMPORTANT LIMITATION
 *   A Sprite2D can only draw inside its own quad. If the nozzle is far outside
 *   the texture, pad the texture with transparent margin (or move the node
 *   toward the nozzle while the shader runs). Atlas/region_rect textures are
 *   not supported because UV no longer spans 0..1.
 */

// ---------------------------------------------------------------- inputs
uniform vec2 target_pos = vec2(0.5, 0.5);   // suction target (UV space)
uniform vec2 ghost_center = vec2(0.5, 0.5); // where the ghost body is (UV space), defines the funnel axis

uniform float suction_progress : hint_range(0.0, 1.0) = 0.0; // 0 = normal, 1 = fully swallowed
uniform float swirl_strength : hint_range(-30.0, 30.0) = 10.0; // radians of twist at the center at full suction (negative = reverse spin)
uniform float stretch_factor : hint_range(0.0, 4.0) = 1.5;    // how much the ghost elongates / narrows into a tail

// ---------------------------------------------------------------- shaping
uniform float influence_radius : hint_range(0.05, 3.0) = 0.8; // radius (in sprite-heights) of the vortex + pinch
uniform float stretch_reach : hint_range(0.05, 4.0) = 1.5;    // radius of the funnel / tail deformation
uniform float suction_curve : hint_range(0.5, 4.0) = 2.0;     // >1 = slow start, violent finish
uniform float spiral_mix : hint_range(0.0, 1.0) = 0.5;        // 0 = classic rotational whirl, 1 = logarithmic spiral
uniform float pinch : hint_range(0.0, 6.0) = 1.5;             // extra radial compression close to the nozzle

// ---------------------------------------------------------------- ghostly look
uniform float aberration : hint_range(0.0, 0.3) = 0.08;       // RGB split strength (0 = off)
uniform float fade_radius : hint_range(0.0, 0.5) = 0.12;      // alpha fades to 0 inside this radius of the nozzle
uniform vec4 glow_color : source_color = vec4(0.55, 0.95, 1.0, 1.0);
uniform float streak_strength : hint_range(0.0, 2.0) = 0.6;   // brightness of the spiral speed lines
uniform float streak_arms = 5.0;
uniform float streak_speed = 8.0;

const float EPS = 0.0001;

// Node modulate has to be forwarded manually because we overwrite COLOR.
varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

/*
 * Output UV -> source UV.
 * 'ca' is a small per-channel factor used for chromatic aberration
 * (+ for red, 0 for green, - for blue). With ca = 0 this is the plain warp.
 */
vec2 vacuum_warp(vec2 uv, float ca, float aspect) {
	// Eased progress: slow wind-up, violent finish.
	float suck = pow(clamp(suction_progress, 0.0, 1.0), suction_curve);

	// ---- 1. UV OFFSET -------------------------------------------------
	// Work in "sprite-height" units so circles stay circles on non-square textures.
	vec2 sc = vec2(aspect, 1.0);
	vec2 p = (uv - target_pos) * sc;   // vector from nozzle to this pixel
	float d = length(p);               // distance from nozzle

	// ---- 2. DISTANCE ATTENUATION --------------------------------------
	// 1 right at the nozzle, smoothly 0 at the edge of the radius.
	float pull_w = 1.0 - smoothstep(0.0, influence_radius, d);
	float pull_w2 = pull_w * pull_w;                           // sharper: concentrates the effect at the center
	float reach_w = 1.0 - smoothstep(0.0, stretch_reach, d);   // wider weight for the funnel

	// ---- 3. STRETCH / FUNNEL ------------------------------------------
	// Split p into a component ALONG the ghost->nozzle axis and one ACROSS it.
	// Sampling "less far" along the axis elongates the ghost; sampling "farther"
	// across the axis (growing toward the nozzle) squeezes it into a tapering tail.
	vec2 to_target = (target_pos - ghost_center) * sc;
	float to_len = length(to_target);
	vec2 axis = to_len > EPS ? to_target / to_len : vec2(1.0, 0.0);
	vec2 normal = vec2(-axis.y, axis.x);

	float par = dot(p, axis);
	float perp = dot(p, normal);
	par /= 1.0 + 0.5 * stretch_factor * suck * reach_w;                  // elongate along the pull
	perp *= 1.0 + 2.0 * stretch_factor * suck * reach_w * reach_w;       // thin out near the nozzle
	p = axis * par + normal * perp;

	// ---- 4. RADIAL PULL & SCALE ---------------------------------------
	// Uniform shrink toward the nozzle: image scale = (1 - suck), so we sample
	// 1/(1 - suck) times farther away. At suck -> 1 the sample point leaves the
	// texture and the ghost is gone. 'pinch' adds extra compression near the center.
	float shrink = max(1.0 - suck, 0.02);
	float k = (1.0 + ca) / shrink;
	k *= 1.0 + pinch * suck * pull_w2;
	p *= k;

	// ---- 5. VORTEX ----------------------------------------------------
	// Rotate the sample point by an angle that grows toward the nozzle.
	//  - rotational whirl: angle ~ pull_w^2
	//  - logarithmic spiral: angle ~ ln(R / d)  (theta = k * ln(r))
	float log_profile = clamp(log(influence_radius / max(d, 0.002)) * 0.4, 0.0, 1.5);
	float profile = mix(pull_w2, log_profile, spiral_mix);
	float angle = swirl_strength * suck * profile * (1.0 + 2.0 * ca); // ca also shears the angle -> rotational RGB smear
	float cs = cos(angle);
	float sn = sin(angle);
	p = vec2(cs * p.x - sn * p.y, sn * p.x + cs * p.y);

	// Back to UV space.
	return target_pos + p / sc;
}

// Texture fetch that returns transparent outside the texture (no edge smearing / tiling).
vec4 fetch_masked(sampler2D tex, vec2 uv) {
	vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	return texture(tex, uv) * inside.x * inside.y;
}

void fragment() {
	float aspect = TEXTURE_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.x; // width / height
	float t = clamp(suction_progress, 0.0, 1.0);
	float suck = pow(t, suction_curve);

	// ---- 6. CHROMATIC ABERRATION --------------------------------------
	// Three warps with slightly different scale/twist per channel.
	float ca = aberration * suck;
	vec4 cr = fetch_masked(TEXTURE, vacuum_warp(UV, +ca, aspect));
	vec4 cg = fetch_masked(TEXTURE, vacuum_warp(UV, 0.0, aspect));
	vec4 cb = fetch_masked(TEXTURE, vacuum_warp(UV, -ca, aspect));

	// Recombine in premultiplied space so transparent texels can't leak junk RGB.
	float a = max(max(cr.a, cg.a), cb.a);
	vec3 rgb = vec3(cr.r * cr.a, cg.g * cg.a, cb.b * cb.a) / max(a, EPS);

	// ---- 7. GHOSTLY FADE & ENERGY -------------------------------------
	vec2 pd = (UV - target_pos) * vec2(aspect, 1.0);
	float d = length(pd);
	float core = 1.0 - smoothstep(0.0, influence_radius, d); // 1 at nozzle

	// Dissolve into the nozzle, plus a final global fade.
	float center_fade = smoothstep(0.0, max(fade_radius, EPS), d);
	a *= mix(1.0, center_fade, suck);
	a *= 1.0 - smoothstep(0.9, 1.0, t);

	// Spiral speed lines: phase = arms * polar angle + twist * ln(r) - time.
	float spin_dir = swirl_strength >= 0.0 ? 1.0 : -1.0;
	float phase = atan(pd.y, pd.x) * streak_arms + spin_dir * log(max(d, 0.002)) * 6.0 - TIME * streak_speed * spin_dir;
	float streak = 0.5 + 0.5 * sin(phase);

	rgb = mix(rgb, glow_color.rgb, suck * core * core * 0.5);     // tint toward the vacuum's glow
	rgb += glow_color.rgb * streak * streak_strength * suck * core; // additive energy streaks

	COLOR = vec4(rgb, a) * v_modulate;
}
