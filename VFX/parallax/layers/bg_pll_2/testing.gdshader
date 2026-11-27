shader_type canvas_item;


// -----------------------------------------------------------------------------
// Bumpy-silhouette cylinder colonnade.
//
// Each column is still a noise-displaced cylinder with (theta, y) texture
// mapping. New in this version:
//   1. Per-column variation from the column ID (noise offset, radius, taper,
//      belly, UV offset / mirror, tint).
//   2. Each column axis follows a curve x = axis(y): per-column lean + parabolic
//      bow + a shared bow. Theta is measured from the curved axis, so the
//      cylinder mapping follows it; normals / texture gradients are sheared.
//   3. Pairs of neighbouring columns can merge into a decayed arch / wall.
//      The wall is a recessed heightfield, smooth-blended into the columns.
//      Alpha, normal, height and albedo are cross-faded, so the surface stays
//      continuous. The wall uses a planar texture projection (no cylinder
//      there); columns keep the exact cylindrical mapping.
//
// Assumes canvas_item y-down: ground is at larger y.
// -----------------------------------------------------------------------------

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pattern_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform float tiles_around : hint_range(0.25, 16.0, 0.05) = 2.0;      // noise repeats per full turn
uniform float rock_tiles_around : hint_range(0.25, 32.0, 0.05) = 4.0; // rock repeats per full turn
uniform float lod : hint_range(0.0, 8.0, 0.1) = 2.0;                  // fixed mip for the noise height

uniform float edge_bump_strength : hint_range(0.0, 0.45, 0.01) = 0.2;
uniform float bump_strength : hint_range(0.0, 8.0, 0.05) = 1.0;
uniform float rock_normal_strength : hint_range(0.0, 4.0, 0.05) = 1.0;
uniform float cavity_strength : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float normal_depth : hint_range(0.0, 2.0, 0.05) = 1.0;
uniform bool flip_normal_y = false;

uniform float cel_steps = 6.0;
uniform float light_strength = 1.0;
uniform vec3 light_dir = vec3(0.0, 1.0, 1.0);

group_uniforms column_shape;
// y range the column curves / arch ground are defined over (shader units, i.e.
// after local_position * 0.01 * 30). Match these to your quad.
uniform float column_top_y = 0.0;
uniform float ground_y = 30.0;
uniform float curve_amount : hint_range(0.0, 0.6, 0.01) = 0.35;     // max per-column axis offset (lean + bow)
uniform float shared_bow : hint_range(-0.5, 0.5, 0.01) = 0.15;      // bow common to every column
uniform float radius_variation : hint_range(0.0, 0.3, 0.01) = 0.15;
uniform float entasis_variation : hint_range(0.0, 1., 0.01) = 0.2; // belly bulge
uniform float taper_variation : hint_range(0.0, 0.3, 0.01) = 0.08;
uniform float tint_variation : hint_range(0.0, 1.0, 0.01) = 0.25;

group_uniforms arch_wall;
uniform float merge_chance : hint_range(0.0, 1.0, 0.01) = 0.3;      // fraction of neighbour pairs that merge
uniform float column_radius = 0.9;                                  // nominal radius used to place the arch springing
uniform float open_height_min = 4.0;                                // opening height above ground (spring line)
uniform float open_height_max = 14.0;
uniform float arch_rise : hint_range(0.0, 2.0, 0.05) = 1.0;         // arch rise / half-span
uniform float arch_tilt : hint_range(0.0, 2.0, 0.05) = 0.4;         // asymmetry of a broken arch
uniform float decay_amount : hint_range(0.0, 6.0, 0.05) = 1.5;      // crown erosion amplitude (y units)
uniform float decay_frequency : hint_range(0.05, 2.0, 0.01) = 0.35;
uniform float wall_depth : hint_range(0.1, 1.0, 0.01) = 1.0;        // keep < column radius
uniform float merge_softness : hint_range(0.01, 0.6, 0.01) = 0.2;   // fillet between wall and columns
uniform float bevel_width : hint_range(0.02, 1.0, 0.01) = 0.3;      // rounded edge of the arch cut
group_uniforms;

const float QUARTER_TURN = PI * 0.5;
const float ASIN_SAFE = 0.9999;
const float D_THETA = 0.03;
const float D_Y = 0.03;
const float D_W = 0.03;
const float CELL_W = 5.0;

//varying vec2 local_position;
//void vertex() {
	//local_position = VERTEX;
//}

// ---- Hashing ----------------------------------------------------------------
vec4 hash41(float n) {
	return fract(sin(vec4(n) * vec4(127.1, 311.7, 74.7, 269.5) + vec4(19.3, 47.1, 5.9, 83.7)) * 43758.5453);
}

// ---- Per-column parameters --------------------------------------------------
struct Col {
	vec2 noise_off;
	float rscale;
	float lean;
	float bow;
	float belly;
	float taper;
	float flip;
	vec2 uv_off;
	float tint;
};

Col make_col(float id) {
	vec4 a = hash41(id);
	vec4 b = hash41(id + 37.0);
	vec4 c = hash41(id + 71.0);
	Col col;
	col.noise_off = a.xy * 16.0;
	col.rscale = mix(1.0 - radius_variation, 1.0 + radius_variation * 0.75, a.z);
	col.lean = a.w - 0.5;
	col.bow = b.x - 0.5;
	col.belly = (b.y - 0.3) * entasis_variation;
	col.taper = (b.z - 0.5) * 2.0 * taper_variation;
	col.flip = (b.w > 0.5) ? 1.0 : -1.0;
	col.uv_off = c.xy * 7.0;
	col.tint = c.z;
	return col;
}

// Normalised position along the column in [-1, 1].
float col_s(float y) {
	float t = clamp((y - column_top_y) / max(ground_y - column_top_y, 1e-3), 0.0, 1.0);
	return 2.0 * t - 1.0;
}

// Driving curve of the column axis (x offset as a function of y).
float axis_x(Col c, float y) {
	float s = col_s(y);
	float bow_prof = 1.0 - s * s;
	return curve_amount * (c.lean * s + c.bow * bow_prof) + shared_bow * bow_prof;
}

float radius_scale(Col c, float y) {
	float s = col_s(y);
	return c.rscale * (1.0 + c.belly * (1.0 - s * s)) * (1.0 + c.taper * s);
}

float height_at(Col c, float theta, float y, float scroll) {
	float k = tiles_around / TAU;
	return textureLod(noise_tex, vec2(theta * k + scroll, y * k) + c.noise_off, lod).r;
}

float radius_at(Col c, float theta, float y, float scroll) {
	return radius_scale(c, y) * (1.0 - edge_bump_strength * (1.0 - height_at(c, theta, y, scroll)));
}

// ---- Column surface ---------------------------------------------------------
struct Surf {
	float sd;     // signed distance to the silhouette (<0 inside)
	float theta;
	float xn;
	float r_sil;
	float h;
	float axp;    // d axis / d y
	float z;      // front height (R cos theta), 0 outside
	vec3 n;       // geometric normal, y-down frame
};

Surf eval_col(Col c, float cx, float x, float y, float scroll) {
	Surf s;
	float d = x - (cx + axis_x(c, y));
	float r_left  = radius_at(c, -QUARTER_TURN, y, scroll);
	float r_right = radius_at(c,  QUARTER_TURN, y, scroll);
	s.r_sil = mix(r_left, r_right, smoothstep(-0.5, 0.5, d));
	s.xn = clamp(d / s.r_sil, -ASIN_SAFE, ASIN_SAFE);
	s.theta = asin(s.xn);
	s.sd = abs(d) - s.r_sil;
	s.axp = (axis_x(c, y + D_Y) - axis_x(c, y - D_Y)) / (2.0 * D_Y);
	s.h = 0.5;
	s.z = 0.0;
	s.n = vec3(0.0, 0.0, 1.0);
	if (s.sd > 0.1) {
		return s; // far outside: skip the expensive normal work
	}

	s.h = height_at(c, s.theta, y, scroll);
	float R = radius_scale(c, y) * (1.0 - edge_bump_strength * (1.0 - s.h));
	float Rt = (radius_at(c, s.theta + D_THETA, y, scroll) - radius_at(c, s.theta - D_THETA, y, scroll)) / (2.0 * D_THETA);
	float Ry = (radius_at(c, s.theta, y + D_Y, scroll) - radius_at(c, s.theta, y - D_Y, scroll)) / (2.0 * D_Y);
	float k_t = bump_strength * Rt / R;
	float k_y = bump_strength * Ry;

	// P(theta, y) = (axis(y) + R sin t, y, R cos t)  ->  N = P_theta x P_y
	float nx = sin(s.theta) - k_t * cos(s.theta);
	float nz = cos(s.theta) + k_t * sin(s.theta);
	s.n = normalize(vec3(nx, -k_y - s.axp * nx, max(nz, 1e-3)));
	s.z = R * cos(s.theta);
	return s;
}

// ---- Arch / wall between two neighbouring columns ---------------------------
struct Wall {
	float on;
	float open_h;
	float tilt;
	float decay;
	float pointed;
	float depth;
	vec2 noff;
};

Wall make_wall(float k) {
	vec4 a = hash41(k * 1.618 + 91.7);
	vec4 b = hash41(k * 2.414 + 13.3);
	Wall w;
	w.on = step(a.x, merge_chance);
	w.open_h = mix(open_height_min, open_height_max, a.y);
	w.decay = a.z * decay_amount;
	w.tilt = (a.w - 0.5) * 2.0 * arch_tilt;
	w.pointed = b.x;
	w.depth = mix(0.35, 0.6, b.y) * wall_depth;
	w.noff = b.zw * 8.0;
	return w;
}

// Returns (y - crown, lateral): crown distance is > 0 below the crown (opening),
// lateral is > 0 between the two column axes.
vec2 wall_field(Wall w, Col cl, Col cr, float cxl, float cxr, float x, float y) {
	float axl = cxl + axis_x(cl, y);
	float axr = cxr + axis_x(cr, y);
	float el = axl + column_radius * cl.rscale;
	float er = axr - column_radius * cr.rscale;
	float width = max(er - el, 0.05);
	float g = clamp((x - el) / width, 0.0, 1.0);
	float e = abs(2.0 * g - 1.0);
	float prof = mix(sqrt(max(1.0 - e * e, 0.0)), 1.0 - e, w.pointed);
	float crown = ground_y - w.open_h - width * 0.5 * arch_rise * prof + w.tilt * (g - 0.5);
	float nz = textureLod(noise_tex, vec2(x, y) * decay_frequency + w.noff, 1.0).r;
	crown += (nz - 0.5) * w.decay;
	return vec2(y - crown, min(x - axl, axr - x));
}

// Wall front height: rounded at the arch cut, fading to 0 at the column axes
// (so neighbouring pairs agree exactly under the columns).
float wall_z(Wall w, vec2 f) {
	return w.depth * smoothstep(0.0, bevel_width, -f.x) * smoothstep(0.0, 0.5, f.y);
}

group_uniforms parallax;

//uniform vec2 camera_pos;
varying vec2 initial_world_pos;
varying vec2 target_pos_varying;
uniform vec2 scroll_scale = vec2(0.1, 1.);
uniform vec2 texture_scale = vec2(15000.);

global uniform vec2 parallax_camera_pos;


void vertex() {
	initial_world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	//vec2 cam_pos = (inverse(CANVAS_MATRIX) * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	// FIX: Flipped the subtraction order so 0.0 locks to the camera
	vec2 parallax_offset = parallax_camera_pos * (vec2(1.0) - scroll_scale);
	target_pos_varying = initial_world_pos - parallax_offset;
}

void fragment() {
	// ---------------------------------------
	vec2 p = target_pos_varying / texture_scale;
	p *= 250.;
	float x = p.x;
	float y = p.y;
	float scroll = 1.; // TIME * spin_speed

	// ---- Domain repetition: this pixel sees the columns on both sides of it ---
	float cell = floor(x / CELL_W);
	float cxl = cell * CELL_W;
	float cxr = cxl + CELL_W;
	Col cl = make_col(cell);
	Col cr = make_col(cell + 1.0);
	Surf sl = eval_col(cl, cxl, x, y, scroll);
	Surf sr = eval_col(cr, cxr, x, y, scroll);

	// Column that is in front at this pixel (drives the cylindrical mapping)
	Surf sc = sl;
	Col cc = cl;
	if (sr.z > sl.z) {
		sc = sr;
		cc = cr;
	}

	// ---- Optional merged wall / arch -----------------------------------------
	Wall w = make_wall(cell);
	float sd = min(sl.sd, sr.sd);
	float h_w = 0.0;                    // 0 = column surface, 1 = wall surface
	vec3 n_wall = vec3(0.0, 0.0, 1.0);
	if (w.on > 0.5) {
		vec2 f = wall_field(w, cl, cr, cxl, cxr, x, y);
		sd = min(sd, max(f.x, -f.y));

		float z_w = wall_z(w, f);
		float zx = (wall_z(w, wall_field(w, cl, cr, cxl, cxr, x + D_W, y)) - wall_z(w, wall_field(w, cl, cr, cxl, cxr, x - D_W, y))) / (2.0 * D_W);
		float zy = (wall_z(w, wall_field(w, cl, cr, cxl, cxr, x, y + D_W)) - wall_z(w, wall_field(w, cl, cr, cxl, cxr, x, y - D_W))) / (2.0 * D_W);
		n_wall = normalize(vec3(-zx, -zy, 1.0));

		// Smooth-max style weight between wall height and column front height
		float zc = max(sl.z, sr.z);
		float present = smoothstep(0.0, bevel_width * 0.5, -f.x);
		float fillet = clamp(0.5 + 0.5 * (z_w - zc) / max(merge_softness, 1e-3), 0.0, 1.0);
		h_w = (zc > 1e-4) ? present * fillet : 1.0;
	}

	float aa = max(fwidth(sd), 1e-5);
	float alpha = clamp(0.5 - sd / aa, 0.0, 1.0);

	// ---- Texture mapping -----------------------------------------------------
	float rk = rock_tiles_around / TAU;
	vec2 ts = vec2(textureSize(rock_tex, 0));
	vec2 uv_scale = vec2(rk, rk * ts.x / ts.y);

	// Column: cylindrical (theta, y), per-column offset + mirror.
	vec2 rock_uv = vec2(sc.theta * cc.flip, y) * uv_scale + vec2(scroll, 0.0) + cc.uv_off;
	float dtheta_dx = 1.0 / (sc.r_sil * sqrt(max(1.0 - sc.xn * sc.xn, 0.001)));
	// theta at fixed screen x also changes with y because the axis is sheared.
	vec2 duv_dx = vec2((dFdx(x) - sc.axp * dFdx(y)) * dtheta_dx * cc.flip, dFdx(y)) * uv_scale;
	vec2 duv_dy = vec2((dFdy(x) - sc.axp * dFdy(y)) * dtheta_dx * cc.flip, dFdy(y)) * uv_scale;

	vec3 rock_c = textureGrad(rock_tex, rock_uv, duv_dx, duv_dy).rgb;
	vec3 pattern_c = textureGrad(pattern_tex, rock_uv, duv_dx, duv_dy).rgb;
	vec3 tn_c = textureGrad(rock_normal, rock_uv, duv_dx, duv_dy).xyz * 2.0 - 1.0;

	// Wall: planar, same texel density. Sampled unconditionally (uniform control flow).
	vec2 planar_uv = vec2(x, y) * uv_scale + w.noff;
	vec3 rock_w = texture(rock_tex, planar_uv).rgb;
	vec3 pattern_w = texture(pattern_tex, planar_uv).rgb;
	vec3 tn_w = texture(rock_normal, planar_uv).xyz * 2.0 - 1.0;
	float h_wall = textureLod(noise_tex, vec2(x, y) * (tiles_around / TAU) + w.noff, lod).r;

	// ---- Blend column <-> wall -----------------------------------------------
	float h = mix(sc.h, h_wall, h_w);
	vec3 rock = mix(rock_c, rock_w, h_w);
	vec3 pattern = mix(pattern_c, pattern_w, h_w);

	vec3 tangent = vec3(cos(sc.theta), 0.0, -sin(sc.theta));
	vec3 detail_c = tangent * (tn_c.x * cc.flip) + vec3(0.0, -1.0, 0.0) * tn_c.y;
	vec3 detail_w = vec3(tn_w.x, -tn_w.y, 0.0);
	vec3 detail = mix(detail_c, detail_w, h_w);

	vec3 n_geo = normalize(mix(sc.n, n_wall, h_w));
	vec3 n = normalize(n_geo + detail * rock_normal_strength);
	n = normalize(vec3(n.xy, max(n.z, 1e-3)));

	n.y = -n.y; // to Godot's green-up convention
	if (flip_normal_y) {
		n.y = -n.y;
	}

	// ---- Lighting ------------------------------------------------------------
	float diffuse_raw        = dot(n, light_dir);
	float diffuse_normalized = diffuse_raw * 0.5 + 0.5;
	float diffuse_clamped    = max(0., diffuse_raw);
	float brightness         = mix(diffuse_clamped, diffuse_normalized, .1);
	brightness = floor(brightness * cel_steps) / cel_steps;

	// ---- Output --------------------------------------------------------------
	float tint = mix(cc.tint, mix(cl.tint, cr.tint, clamp((x - cxl) / CELL_W, 0.0, 1.0)), h_w);
	float tint_mul = mix(1.0, 0.75 + 0.5 * tint, tint_variation);

	float splatmap = smoothstep(0. - fwidth(h), 0.9 + fwidth(h), h);
	vec3 albedo = (splatmap * rock * mix(1.0, h, cavity_strength) +
	              (1. - splatmap) * pattern) * brightness * tint_mul;

	COLOR = vec4(albedo, alpha);
}
