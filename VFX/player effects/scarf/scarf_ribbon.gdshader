shader_type canvas_item;

// Pseudo-3D twisting ribbon.
// Frame data comes from a float texture written by scarf_ribbon.gd:
//   row 0: (tangent.x, tangent.y, sin(twist), cos(twist))
//   row 1: (twist velocity, curvature, 0, 0)
// Mesh UV: x = 0..1 along the length (particle index), y = 0..1 across the width.
//
// Ribbon frame (screen space: x right, y down, Z toward the viewer):
//   T = tangent, n2 = perpendicular to T in the screen plane
//   B = cos(twist) * n2 + sin(twist) * Z      (width direction)
//   N = cos(twist) * Z  - sin(twist) * n2     (surface normal)
// Cross-section curvature rotates N toward B by (v * camber).

uniform sampler2D ribbon_data : filter_nearest, repeat_disable;
uniform float camber = 0.8;          // set by the script (must match geometry)
uniform float ribbon_length = 216.0; // set by the script (pixels)

// Colours
uniform vec4 fabric_color : source_color = vec4(0.85, 0.22, 0.1, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.40, 0.06, 0.08, 1.0);
uniform vec4 back_color : source_color = vec4(0.74, 0.17, 0.11, 1.0);
uniform vec4 transmit_color : source_color = vec4(1.0, 0.55, 0.25, 1.0);
uniform vec4 sheen_color : source_color = vec4(1.0, 0.86, 0.7, 1.0);

// Lighting (light_dir points TOWARD the light; y is down in canvas space)
uniform vec3 light_dir = vec3(-0.5, -0.55, 0.65);
uniform float light_wrap : hint_range(0.0, 1.0) = 0.5;
uniform float translucency : hint_range(0.0, 1.0) = 0.45;
uniform float sheen_strength : hint_range(0.0, 2.0) = 0.6;
uniform float sheen_power : hint_range(2.0, 128.0) = 28.0;
uniform float rim_strength : hint_range(0.0, 1.5) = 0.4;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;

// Fabric detail (assign a seamless NoiseTexture2D)
uniform sampler2D noise_pattern : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float noise_tile_px = 48.0;
uniform float flutter_speed = 0.6;
uniform float fabric_variation : hint_range(0.0, 0.5) = 0.1;
uniform float wrinkle_strength : hint_range(0.0, 2.0) = 0.35;

varying vec4 v_frame;
varying vec3 v_dyn;
varying vec4 v_mod;

void vertex() {
	int count = textureSize(ribbon_data, 0).x;
	int idx = clamp(int(round(UV.x * float(count - 1))), 0, count - 1);
	v_frame = texelFetch(ribbon_data, ivec2(idx, 0), 0);
	v_dyn = texelFetch(ribbon_data, ivec2(idx, 1), 0).xyz;
	v_mod = COLOR; // vertex colour * CanvasItem modulate
}

void fragment() {
	// ---- Rebuild the ribbon frame from interpolated data -------------------------
	vec2 t = vec2(1.0, 0.0);
	float tl = length(v_frame.xy);
	if (tl > 0.0001) {
		t = v_frame.xy / tl;
	}
	vec2 n2 = vec2(-t.y, t.x);

	vec2 sc = vec2(0.0, 1.0);
	float sl = length(v_frame.zw);
	if (sl > 0.0001) {
		sc = v_frame.zw / sl;
	}
	float s = sc.x;
	float c = sc.y;

	vec3 T = vec3(t, 0.0);
	vec3 B = vec3(c * n2, s);
	vec3 N0 = vec3(-s * n2, c);

	// ---- Normal: cross-sectional curvature + longitudinal twist ------------------
	float v = UV.y * 2.0 - 1.0;
	float phi = v * camber;
	vec3 n = normalize(cos(phi) * N0 + sin(phi) * B);

	// ---- Fabric grain + wrinkles (stronger when the ribbon whips/rolls fast) -----
	vec2 nuv = vec2(UV.x * ribbon_length / max(noise_tile_px, 1.0) - TIME * flutter_speed, UV.y * 0.6);
	float h0 = texture(noise_pattern, nuv).r;
	float hu = texture(noise_pattern, nuv + vec2(0.02, 0.0)).r;
	float hv = texture(noise_pattern, nuv + vec2(0.0, 0.02)).r;
	vec2 grad = vec2(hu - h0, hv - h0) / 0.02;
	float activity = clamp(abs(v_dyn.x) * 0.08 + abs(v_dyn.y) * 0.5, 0.0, 1.0);
	float wr = wrinkle_strength * (0.4 + 0.6 * activity) * 0.1;
	n = normalize(n - (T * grad.x + B * grad.y) * wr);
	float grain = mix(1.0 - fabric_variation, 1.0 + fabric_variation, h0);

	// ---- Two-sided: flip normal when we see the back of the ribbon ---------------
	vec3 V = vec3(0.0, 0.0, 1.0);
	bool is_back = n.z < 0.0;
	if (is_back) {
		n = -n;
	}

	// ---- Lighting ---------------------------------------------------------------
	vec3 L = normalize(light_dir);
	float ndl = dot(n, L);

	// Wrapped, smoothed diffuse -> soft cloth shading that tracks the twist.
	float diff = clamp((ndl + light_wrap) / (1.0 + light_wrap), 0.0, 1.0);
	diff = diff * diff * (3.0 - 2.0 * diff);

	// Thin-fabric transmission: glows when the light is behind the visible face.
	float trans = pow(clamp(-ndl, 0.0, 1.0), 1.5) * translucency;

	// Satin sheen: Blinn lobe stretched by a Kajiya-Kay term along the ribbon.
	vec3 H = normalize(L + V);
	float th = dot(T, H);
	float kk = sqrt(max(1.0 - th * th, 0.0));
	float spec = pow(clamp(dot(n, H), 0.0, 1.0), sheen_power) * pow(kk, 4.0);
	spec *= smoothstep(0.0, 0.3, ndl);

	// Fresnel-style rim: edge-on surfaces catch skylight.
	float fres = pow(1.0 - clamp(n.z, 0.0, 1.0), rim_power);

	vec3 albedo = fabric_color.rgb;
	if (is_back) {
		albedo = back_color.rgb;
	}
	vec3 col = mix(shadow_color.rgb, albedo, diff) * grain;
	col += transmit_color.rgb * albedo * trans;
	col += sheen_color.rgb * spec * sheen_strength;
	col += sheen_color.rgb * fres * rim_strength * (0.35 + 0.65 * diff);

	// ---- Analytic edge anti-aliasing (silhouette + tip) --------------------------
	float dv = fwidth(v);
	float edge = clamp((1.0 - abs(v)) / max(dv * 1.2, 0.0001), 0.0, 1.0);
	float du = fwidth(UV.x);
	float tip = clamp((1.0 - UV.x) / max(du * 1.2, 0.0001), 0.0, 1.0);

	COLOR = vec4(col, 1.0) * v_mod;
	COLOR.a *= edge * tip;
}

//shader_type canvas_item;
//render_mode unshaded;
//
//// ============================================================
//// CPU simulation data
//// ============================================================
//
//// Texture dimensions: particle_count x 2, RGBAF.
//// Row 0: tangent.xy, sin(twist), cos(twist)
//// Row 1: twist_velocity, curvature, 0, 0
//
//uniform sampler2D ribbon_data : filter_nearest, repeat_disable;
//
//uniform float ribbon_length = 207.0;
//uniform float camber = 0.8;
//
//// ============================================================
//// Lighting configuration
//// ============================================================
//
//const vec3 LIGHT_DIR = vec3(-0.45, -0.55, 0.70);
//const vec3 _LIGHT_COLOR = vec3(1.0, 0.88, 0.73);
//const vec3 AMBIENT_COLOR = vec3(0.22, 0.28, 0.40);
//
//const vec3 COOL_RIM = vec3(0.12, 0.38, 0.85);
//const vec3 WARM_LIGHT = vec3(1.0, 0.48, 0.19);
//
//const float SPECULAR_POWER = 48.0;
//const float RIM_POWER = 3.0;
//
//// ============================================================
//// Interpolated simulation data
//// ============================================================
//
//varying vec4 v_frame;
//varying vec2 v_motion;
//varying float v_longitudinal;
//
//// ============================================================
//// Texture sampling
//// ============================================================
//
//vec4 sample_ribbon_data(float u, float row) {
    //ivec2 dimensions = textureSize(ribbon_data, 0);
//
    //float width = float(dimensions.x);
//
    //float index = floor(
        //clamp(u, 0.0, 1.0) * (width - 1.0) + 0.5
    //);
//
    //vec2 tex_uv = vec2(
        //(index + 0.5) / width,
        //(row + 0.5) / float(dimensions.y)
    //);
//
    //return textureLod(ribbon_data, tex_uv, 0.0);
//}
//
//// ============================================================
//// Vertex stage
//// ============================================================
//
//void vertex() {
    //vec4 frame = sample_ribbon_data(UV.x, 0.0);
    //vec4 motion = sample_ribbon_data(UV.x, 1.0);
//
    //// Tangent and torsional frame.
    //v_frame = frame;
//
    //// x = twist velocity
    //// y = curvature
    //v_motion = motion.rg;
//
    //// Physical distance along the ribbon.
    //v_longitudinal = UV.x * ribbon_length;
//}
//
//// ============================================================
//// Fragment stage
//// ============================================================
//
//void fragment() {
//
    //// --------------------------------------------------------
    //// Recover the simulated ribbon frame
    //// --------------------------------------------------------
//
    //vec2 tangent = normalize(v_frame.xy);
//
    //float sin_twist = v_frame.z;
    //float cos_twist = v_frame.w;
//
    //// Recover twist without needing atan().
    //vec2 twist_frame = normalize(
        //vec2(cos_twist, sin_twist)
    //);
//
    //float twist = atan(
        //twist_frame.y,
        //twist_frame.x
    //);
//
    //float twist_velocity = v_motion.x;
    //float curvature = v_motion.y;
//
    //// Cross-section position: -1 = left edge, +1 = right.
    //float across = UV.y * 2.0 - 1.0;
//
    //// --------------------------------------------------------
    //// Actual cross-section surface normal
    //// --------------------------------------------------------
//
    //// Ribbon cross-section angle.
    //float phi = across * camber;
//
    //// The ribbon's in-plane normal.
    //vec2 lateral = vec2(-tangent.y, tangent.x);
//
    //// The cross-section normal rotates with twist and camber.
    ////
    //// N = B*sin(phi) + N0*cos(phi)
    ////
    //// Projected into 3D pseudo-space, this produces
    //// correct lighting across the rounded ribbon surface.
//
    //float surface_angle = phi - twist;
//
    //vec3 N = normalize(vec3(
        //lateral * sin(surface_angle),
        //cos(surface_angle)
    //));
//
    //// Camera-facing, two-sided shading.
    //if (N.z < 0.0) {
        //N = -N;
    //}
//
    //vec3 V = vec3(0.0, 0.0, 1.0);
    //vec3 L = normalize(LIGHT_DIR);
    //vec3 H = normalize(L + V);
//
    //// --------------------------------------------------------
    //// Diffuse lighting
    //// --------------------------------------------------------
//
    //float NdotL = max(dot(N, L), 0.0);
//
    //float diffuse = 0.30 + 0.70 * NdotL;
//
    //vec3 diffuse_light =
        //_LIGHT_COLOR * diffuse;
//
    //// --------------------------------------------------------
    //// Ambient illumination
    //// --------------------------------------------------------
//
    //float ambient_occlusion = mix(
        //0.72,
        //1.0,
        //abs(cos(phi))
    //);
//
    //vec3 ambient =
        //AMBIENT_COLOR * ambient_occlusion;
//
    //// --------------------------------------------------------
    //// Specular highlights
    //// --------------------------------------------------------
//
    //float NdotH = max(dot(N, H), 0.0);
//
    //// Camber determines highlight concentration.
    //float roughness = mix(
        //0.42,
        //0.20,
        //clamp(camber / 1.5, 0.0, 1.0)
    //);
//
    //float spec_power = mix(
        //18.0,
        //SPECULAR_POWER,
        //1.0 - roughness
    //);
//
    //float specular = pow(
        //NdotH,
        //spec_power
    //);
//
    //// The twisting ribbon creates moving specular response.
    //float torsion_highlight = 1.0 +
        //abs(twist_velocity) * 0.025;
//
    //specular *= torsion_highlight;
//
    //vec3 specular_light =
        //_LIGHT_COLOR * specular * 0.65;
//
    //// --------------------------------------------------------
    //// Fresnel / edge illumination
    //// --------------------------------------------------------
//
    //float NdotV = abs(dot(N, V));
//
    //float fresnel = pow(
        //1.0 - NdotV,
        //RIM_POWER
    //);
//
    //vec3 rim_light = mix(
        //COOL_RIM,
        //WARM_LIGHT,
        //clamp(abs(twist_velocity) * 0.04, 0.0, 1.0)
    //) * fresnel;
//
    //// --------------------------------------------------------
    //// Curvature response
    //// --------------------------------------------------------
//
    //float bend_amount = clamp(
        //abs(curvature) * 1.8,
        //0.0,
        //1.0
    //);
//
    //// Curved portions receive additional grazing illumination.
    //float bend_highlight =
        //bend_amount * (1.0 - NdotV);
//
    //vec3 curvature_light =
        //WARM_LIGHT * bend_highlight * 0.25;
//
    //// --------------------------------------------------------
    //// Torsional motion response
    //// --------------------------------------------------------
//
    //float flutter = clamp(
        //abs(twist_velocity) / 25.0,
        //0.0,
        //1.0
    //);
//
    //vec3 flutter_light =
        //COOL_RIM * flutter * 0.12;
//
    //// --------------------------------------------------------
    //// Longitudinal material variation
    //// --------------------------------------------------------
//
    //// A subtle length-based sheen.
    //// This remains consistent as the ribbon length changes.
    //float weave = 0.97 + 0.03 * sin(
        //v_longitudinal * 0.08 + twist * 2.0
    //);
//
    //// Softer edge response.
    //float edge = smoothstep(
        //0.0,
        //0.12,
        //1.0 - abs(across)
    //);
//
    //// --------------------------------------------------------
    //// Final lighting composition
    //// --------------------------------------------------------
//
    //vec3 lighting =
        //ambient +
        //diffuse_light * 0.72 +
        //specular_light +
        //rim_light +
        //curvature_light +
        //flutter_light;
//
    //lighting *= weave;
//
    //// Preserve node modulate / vertex tint.
    //vec3 base_color = COLOR.rgb;
//
    //vec3 final_color = base_color * lighting;
//
    //// Slightly brighter highlights without clipping.
    //final_color += specular_light * base_color * 0.25;
//
    //COLOR = vec4(
        //final_color,
        //COLOR.a
    //);
//}
