shader_type canvas_item;

// Visual properties
uniform vec4 fabric_color : source_color = vec4(0.85, 0.22, 0.1, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.45, 0.08, 0.05, 1.0);
uniform sampler2D noise_pattern : hint_default_white, repeat_enable;

uniform float wave_speed = 4.0;
uniform float wave_scale = 3.0;
uniform float normal_intensity = 1.8;

void fragment() {
	// 1. Remap UV.y from [0, 1] to [-1, 1] to simulate a curved cylindrical ribbon cross-section
	float curved_y = (UV.y - 0.5) * 2.0;
	
	// Calculate pseudo-normal Z component based on a rounded profile (hemisphere shape across width)
	float normal_z = sqrt(max(0.0, 1.0 - curved_y * curved_y));
	vec3 pseudo_normal = normalize(vec3(0.0, curved_y * 0.5, normal_z));

	// 2. Sample scrolling noise for procedural fabric ripples and wind flutter details
	vec2 scrolled_uv = vec2(UV.x * wave_scale - TIME * wave_speed, UV.y);
	float noise_val = texture(noise_pattern, scrolled_uv).r;

	// 3. Fake lighting calculation (Simulated directional light from top-left-front)
	vec3 light_dir = normalize(vec3(-0.5, -0.5, 1.0));
	float diff = max(dot(pseudo_normal, light_dir), 0.0);
	
	// Smooth out diffuse lighting for soft fabric look
	diff = mix(0.3, 1.0, diff);

	// 4. Combine base color, noise variation, and lighting shading
	vec3 base_shading = mix(shadow_color.rgb, fabric_color.rgb, diff);
	vec3 final_color = base_shading * mix(0.85, 1.15, noise_val);

	// 5. Add subtle edge rim lighting for depth enhancement
	float rim = 1.0 - abs(curved_y);
	rim = pow(rim, 2.5) * 0.35;
	final_color += vec3(rim);

	COLOR = vec4(final_color, 1.0);
}