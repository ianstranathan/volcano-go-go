
shader_type canvas_item;
// Unshaded: Light2D nodes won't double-light the baked-in cel shading.
render_mode unshaded;

//ffe680
const vec3 LUMA = vec3(0.299, 0.587, 0.114);

// ═══════════════════════════ TEXTURES ═══════════════════════════
group_uniforms textures;
uniform sampler2D magma_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;

// ═══════════════════════════ FLOW ═══════════════════════════
group_uniforms flow;

uniform float slow_speed : hint_range(0.0, 1.0) = 0.05;
uniform float fast_speed : hint_range(0.0, 2.0) = 0.22;
uniform float molten_y_scale : hint_range(0.2, 2.0) = 0.7;
uniform vec2 molten_uv_offset = vec2(0.37, 0.19);

// ═══════════════════════════ SMOOTH WARP ═══════════════════════════
group_uniforms warp;
uniform float warp_scale : hint_range(0.1, 4.0) = 0.6;
uniform float warp_speed : hint_range(0.0, 1.0) = 0.06;
uniform float warp_x : hint_range(0.0, 0.4) = 0.05;
uniform float warp_y : hint_range(0.0, 0.4) = 0.10;
uniform float crust_warp_mul : hint_range(0.0, 1.0) = 0.35;

// ═══════════════════════════ RIVULETS ═══════════════════════════
group_uniforms rivulets;
uniform vec2 rivulet_tiles = vec2(2.0, 0.4);
uniform float rivulet_speed : hint_range(0.0, 1.0) = 0.12;
uniform float rivulet_influence : hint_range(0.0, 1.5) = 0.7;
uniform float rivulet_bump : hint_range(0.0, 30.0) = 6.0;

// ═══════════════════════════ NORMALS / LIGHT ═══════════════════════════
group_uniforms lighting;
uniform float normal_strength : hint_range(0.0, 4.0) = 1.4;
uniform bool flip_normal_y = true;
uniform float refraction_strength : hint_range(0.0, 0.25) = 0.06;
uniform float crust_refraction_mul : hint_range(0.0, 1.0) = 0.2;
uniform vec3 light_dir = vec3(-0.5, -0.55, 0.65);
uniform float crust_ambient : hint_range(0.0, 0.5) = 0.10;
uniform float crust_light_gain : hint_range(0.0, 5.0) = 2.0;
uniform float hot_light_response : hint_range(0.0, 1.0) = 0.3;
uniform float crust_spec : hint_range(0.0, 1.0) = 0.35;
uniform float shadow_dist : hint_range(0.0, 0.05) = 0.012;
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.6;

// ═══════════════════════════ CRUST / HEAT MASK ═══════════════════════════
group_uniforms crust;
uniform float heat_threshold : hint_range(0.0, 1.0) = 0.42;
uniform float heat_softness : hint_range(0.001, 0.4) = 0.06;
uniform vec3 crust_color : source_color = vec3(0.17, 0.13, 0.13);
uniform float crust_albedo_mix : hint_range(0.0, 1.0) = 0.35;
uniform float crust_albedo_boost : hint_range(0.0, 6.0) = 2.0;

// ═══════════════════════════ MOLTEN / EMISSION ═══════════════════════════
group_uniforms molten;
uniform float molten_min_heat : hint_range(0.0, 1.0) = 0.30;
uniform float edge_heat_boost : hint_range(0.0, 1.0) = 0.35;
uniform float emission_strength : hint_range(0.0, 8.0) = 2.8;
uniform vec3 color_deep : source_color = vec3(0.45, 0.02, 0.0);
uniform vec3 color_mid : source_color = vec3(1.0, 0.22, 0.02);
uniform vec3 color_hot : source_color = vec3(1.0, 0.55, 0.06);
uniform vec3 color_core : source_color = vec3(1.0, 0.90, 0.50);

// ═══════════════════════════ LIGHT BLEED ONTO ROCK ═══════════════════════════
group_uniforms bleed;
uniform float glow_lod : hint_range(0.0, 7.0) = 3.0;
uniform float glow_probe : hint_range(0.002, 0.1) = 0.03;
uniform float bleed_strength : hint_range(0.0, 3.0) = 0.9;
uniform vec3 bleed_color : source_color = vec3(1.0, 0.30, 0.04);

// ═══════════════════════════ EMBER PULSE ═══════════════════════════
group_uniforms ember_pulse;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.2;
uniform float pulse_amount : hint_range(0.0, 0.6) = 0.15;
uniform float pulse_phase_spread : hint_range(0.0, 30.0) = 10.0;

// ═══════════════════════════ HELPERS ═══════════════════════════

// Heat 0..1 -> lava color.
vec3 heat_ramp(float h) {
	vec3 c = mix(color_deep, color_mid, smoothstep(0.0, 0.40, h));
	c = mix(c, color_hot, smoothstep(0.35, 0.75, h));
	c = mix(c, color_core, smoothstep(0.70, 1.00, h));
	return c;
}

uniform float vertical_scroll_speed : hint_range(0.0, 2.0) = 1.0;

// ═══════════════════════════ FRAGMENT ═══════════════════════════
void fragment() {
	vec2 uv = UV; // arbitrary number bro
	
	// ── 1. SMOOTH WARP
	vec2 wp = uv * warp_scale;
	float wn1 = texture(noise_tex, wp + vec2(0.0, -TIME * warp_speed * vertical_scroll_speed)).r - 0.5;

float wn2 = texture(noise_tex, wp * 0.7 + vec2(0.43, 0.17 - TIME * warp_speed * 0.6 * vertical_scroll_speed)).r - 0.5;
	vec2 warp = vec2(wn1 * warp_x, wn2 * warp_y) * 2.0;

	// ── 2. RIVULETS
	vec2 sp = vec2(uv.x * rivulet_tiles.x + wn1 * 0.6,
               uv.y * rivulet_tiles.y - TIME * rivulet_speed * vertical_scroll_speed + wn2 * 0.4);
	float streak_raw = texture(noise_tex, sp).r;
	float streak = smoothstep(0.30, 0.70, streak_raw);
	float sx = texture(noise_tex, sp + vec2(0.01, 0.0)).r;
	float sy = texture(noise_tex, sp + vec2(0.0, 0.01)).r;
	vec2 bump = (vec2(sx, sy) - streak_raw) * rivulet_bump;

	// ── 3. NORMAL
	vec2 uv_crust = uv + vec2(0.0, -TIME * slow_speed * vertical_scroll_speed) + warp * crust_warp_mul;
	vec2 nxy = texture(normal_map, uv_crust).rg * 2.0 - 1.0;
	if (flip_normal_y) {
		nxy.y = -nxy.y;
	}
	float nz = sqrt(max(1.0 - dot(nxy, nxy), 0.0001));
	vec3 normal = normalize(vec3(nxy * normal_strength - bump, nz));

	// ── 4. DUAL-SPEED PANNING + HEAT REFRACTION
	vec2 refr = normal.xy * refraction_strength;
	vec2 uv_molten = vec2(uv.x, uv.y * molten_y_scale) + molten_uv_offset
               + vec2(0.0, -TIME * fast_speed * vertical_scroll_speed) + warp + refr;
	uv_crust += refr * crust_refraction_mul;

	// ── 5. HEAT MASK
	vec4 crust_tex = texture(magma_albedo, uv_crust);
	float lum_c = dot(crust_tex.rgb, LUMA);
	float streak_bias = (streak - 0.5) * rivulet_influence;
	float mask = smoothstep(heat_threshold - heat_softness, heat_threshold + heat_softness, lum_c + streak_bias);
	float rim = mask * (1.0 - mask) * 4.0;

	// ── 6. STYLIZED DIFFUSE + CEL SHADING
	vec3 L = normalize(light_dir);
	float diffuse_raw = dot(normal, L);
	float diffuse_normalized = diffuse_raw * 0.5 + 0.5;
	float diffuse_clamped = max(0.0, diffuse_raw);
	float brightness = mix(diffuse_clamped, diffuse_normalized, 0.1);
	brightness = floor(brightness * 6.0) / 6.0;

	// ── 7. EMBER PULSE
	float pulse = 1.0 + sin(TIME * pulse_speed + wn1 * pulse_phase_spread) * pulse_amount;

	// ── 8. MOLTEN
	vec3 molten_tex = texture(magma_albedo, uv_molten).rgb;
	float lum_m = dot(molten_tex, LUMA);
	float heat = mix(molten_min_heat, 1.0, smoothstep(0.15, 0.85, lum_m));
	heat += (streak - 0.5) * 0.5 + rim * edge_heat_boost;
	heat = clamp(heat, 0.0, 1.0);

	vec3 molten_col = heat_ramp(heat) * (0.8 + heat * heat * emission_strength);
	molten_col *= mix(1.0, brightness * 2.0, hot_light_response);

	float lum_s = dot(texture(magma_albedo, uv_crust + L.xy * shadow_dist).rgb, LUMA);
	float mask_s = smoothstep(heat_threshold - heat_softness, heat_threshold + heat_softness, lum_s + streak_bias);
	molten_col *= 1.0 - shadow_strength * (1.0 - mask_s);
	molten_col *= pulse;

	// ── 9. CRUST
	vec3 crust_base = mix(crust_color, clamp(crust_tex.rgb * crust_albedo_boost, 0.0, 1.0), crust_albedo_mix);
	vec3 crust_final = crust_base * (crust_ambient + brightness * crust_light_gain);

	vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
	float spec = step(0.5, pow(max(dot(normal, H), 0.0), 28.0)) * crust_spec;
	crust_final += vec3(1.0, 0.70, 0.55) * spec;

	// Blurred heat glow spilling onto the rock.
	float blur_c = dot(textureLod(magma_albedo, uv_crust, glow_lod).rgb, LUMA);
	float blur_x = dot(textureLod(magma_albedo, uv_crust + vec2(glow_probe, 0.0), glow_lod).rgb, LUMA);
	float blur_y = dot(textureLod(magma_albedo, uv_crust + vec2(0.0, glow_probe), glow_lod).rgb, LUMA);
	vec2 grad = vec2(blur_x - blur_c, blur_y - blur_c);
	vec2 to_lava = grad / max(length(grad), 0.0001);
	float bleed = smoothstep(0.12, 0.65, blur_c + streak_bias * 0.5);
	float facing = clamp(dot(normal.xy, to_lava) * 1.5 + 0.5, 0.0, 1.0);
	crust_final += bleed_color * bleed * mix(0.35, 1.0, facing) * bleed_strength * pulse;

	// ── 10. COMPOSE
	vec3 col = mix(crust_final, molten_col, mask);

	COLOR = vec4(max(col, vec3(0.0)), 1.);
}
