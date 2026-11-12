shader_type canvas_item;

// -----------------------------------------------------------------------------
// Bumpy-silhouette cylinder (see bumpy_cylinder.gdshader) + a second texture
// layer (albedo + tangent-space normal) wrapped on the same surface.
//
// noise_tex  : drives the geometry (radius / silhouette / base relief).
// rock_tex   : albedo, projected with the same (theta, y) parametrisation.
// rock_normal: tangent-space normal map (OpenGL / green-up), projected the same way.
// -----------------------------------------------------------------------------

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pattern_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform float tiles_around : hint_range(0.25, 16.0, 0.05) = 2.0;      // noise repeats per full turn
uniform float rock_tiles_around : hint_range(0.25, 32.0, 0.05) = 4.0; // rock repeats per full turn
uniform float spin_speed = 0.05;                                      // turns/sec (shared by all layers)
//uniform float aspect = 1.0;                                           // quad height / width
uniform float lod : hint_range(0.0, 8.0, 0.1) = 2.0;                  // fixed mip for the noise height

uniform float edge_bump_strength : hint_range(0.0, 0.45, 0.01) = 0.2;
uniform float bump_strength : hint_range(0.0, 8.0, 0.05) = 1.0;
uniform float rock_normal_strength : hint_range(0.0, 4.0, 0.05) = 1.0;
uniform float cavity_strength : hint_range(0.0, 1.0, 0.01) = 0.5;     // darken albedo in low noise areas
uniform float normal_depth : hint_range(0.0, 2.0, 0.05) = 1.0;
uniform bool flip_normal_y = false;

const float QUARTER_TURN = PI * 0.5;
const float ASIN_SAFE = 0.9999;
const float D_THETA = 0.03;
const float D_Y = 0.03;

varying vec2 local_position;
void vertex() {
    local_position = VERTEX;
}

float height_at(float theta, float y, float scroll) {
	float k = tiles_around / TAU;
	return textureLod(noise_tex, vec2(theta * k + scroll, y * k), lod).r;
}

float radius_at(float theta, float y, float scroll) {
	return 1.0 - edge_bump_strength * (1.0 - height_at(theta, y, scroll));
}
uniform float cel_steps = 6.0;
uniform float light_strength = 1.0;
uniform vec3 light_dir = vec3(0.0, 1.0, 1.0);
void fragment() {
	vec2 p = local_position * 0.01;//(UV - 0.5) * 2.0;
	p *= 30.;
	p.x = mod(p.x + 1.5, 3.) - 1.5;
	float x = p.x;
	float y = p.y;
	float scroll = 1.;// TIME * spin_speed;

	// ---- Silhouette + angle (unchanged) --------------------------------------
	float r_left  = radius_at(-QUARTER_TURN, y, scroll);
	float r_right = radius_at( QUARTER_TURN, y, scroll);
	float r_sil = mix(r_left, r_right, smoothstep(-0.5, 0.5, x));

	float x_n = clamp(x / r_sil, -ASIN_SAFE, ASIN_SAFE);
	float theta = asin(x_n);

	float edge_dist = abs(x) - r_sil;
	float aa = max(fwidth(edge_dist), 1e-5);
	float alpha = clamp(0.5 - edge_dist / aa, 0.0, 1.0);

	// ---- Geometric normal from the noise-displaced surface -------------------
	float h = height_at(theta, y, scroll);
	float R = 1.0 - edge_bump_strength * (1.0 - h);

	float Rt = (radius_at(theta + D_THETA, y, scroll) - radius_at(theta - D_THETA, y, scroll)) / (2.0 * D_THETA);
	float Ry = (radius_at(theta, y + D_Y, scroll) - radius_at(theta, y - D_Y, scroll)) / (2.0 * D_Y);
	float k_t = bump_strength * Rt / R;
	float k_y = bump_strength * Ry;

	vec3 n_geo = vec3(sin(theta) - k_t * cos(theta),
	                  -k_y,
	                  cos(theta) + k_t * sin(theta));
	n_geo = normalize(vec3(n_geo.xy, max(n_geo.z, 1e-3))); // y-down frame

	// ---- Second texture layer ------------------------------------------------
	// Same parametrisation as the noise: u follows the surface angle, v follows y.
	// Both are scaled by one density (tiles / TAU) so texels are square at the
	// cylinder centre; the texture's own aspect ratio is compensated for.
	float rk = rock_tiles_around / TAU;
	vec2 ts = vec2(textureSize(rock_tex, 0));
	vec2 uv_scale = vec2(rk, rk * ts.x / ts.y);
	vec2 rock_uv = vec2(theta, y) * uv_scale + vec2(scroll, 0.0);

	// Analytic screen-space derivatives so mip selection / anisotropic filtering
	// respect the foreshortening near the limb (d theta / dx = 1 / (r sqrt(1 - x_n^2))).
	// Capped so the very last pixels at the limb don't blow up to infinity.
	float dtheta_dx = 1.0 / (r_sil * sqrt(max(1.0 - x_n * x_n, 0.001)));
	vec2 grad_scale = vec2(dtheta_dx, 1.0) * uv_scale;
	vec2 duv_dx = vec2(dFdx(x), dFdx(y)) * grad_scale;
	vec2 duv_dy = vec2(dFdy(x), dFdy(y)) * grad_scale;

	// https://www.google.com/search?q=textureGrad+glsl&sxsrf=AKL5yDh2j3QvVi2tbbi1PTBF3_IyEVtudg%3A1794436497562
	// textureGrad is a built-in GLSL function that samples a texture using explicit partial derivatives
	vec3 rock = textureGrad(rock_tex, rock_uv, duv_dx, duv_dy).rgb;
	vec3 pattern = textureGrad(pattern_tex, rock_uv, duv_dx, duv_dy).rgb;
	vec3 tn = textureGrad(rock_normal, rock_uv, duv_dx, duv_dy).xyz * 2.0 - 1.0;

	// Rotate the tangent-space normal into the cylinder's local frame:
	//   tangent   = direction of increasing theta (screen-right at the centre)
	//   bitangent = screen-up (our frame is y-down; a green-up map tilts toward -y)
	vec3 tangent = vec3(cos(theta), 0.0, -sin(theta));
	vec3 detail = tangent * tn.x + vec3(0.0, -1.0, 0.0) * tn.y;
	vec3 n = normalize(n_geo + detail * rock_normal_strength);
	n = normalize(vec3(n.xy, max(n.z, 1e-3)));

	n.y = -n.y; // to Godot's green-up convention
	if (flip_normal_y) {
		n.y = -n.y;
	}
	//vec3 normal = textureLod(rock_normal, _UV, lod).xyz;
	float diffuse_raw        = dot(n,  light_dir); //normalize(light_pos)); 
	float diffuse_normalized = diffuse_raw * 0.5 + 0.5;
	float diffuse_clamped    = max( 0., diffuse_raw);
	float brightness         = mix(diffuse_clamped, diffuse_normalized, .1);
	brightness = floor(brightness * 6.) / 6.;
	// ---- Output --------------------------------------------------------------
	float splatmap = smoothstep(0. - fwidth(h), 0.9 + fwidth(h), h);
	vec3 albedo = (splatmap * rock * mix(1.0, h, cavity_strength) +
	              (1. - splatmap) * pattern) * brightness;
	
	// mix( 0.3, 0.5, h)
	COLOR = vec4(albedo, alpha);
	//NORMAL_MAP = n * 0.5 + 0.5;
	//NORMAL_MAP_DEPTH = normal_depth;
}
