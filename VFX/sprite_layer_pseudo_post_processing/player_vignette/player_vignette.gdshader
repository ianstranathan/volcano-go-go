shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D noise_texture : repeat_enable;
uniform vec2 player_screen_pos = vec2(0.5, 0.5);


instance uniform int vignette_layer : hint_enum("Zero", "One");

// Layer 0: Main vignette
instance uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;

// Layer 1: Noise vignette
instance uniform float noise_strength : hint_range(0.0, 1.0) = 0.3;
instance uniform float noise_scale = 3.0;

// Shared
instance uniform float vignette_radius = 1.2;
instance uniform float vignette_softness = 1.0;

float interleaved_gradient_noise(vec2 pixel) {
    return fract(
        52.9829189 * fract(
            dot(pixel, vec2(0.06711056, 0.00583715))
        )
    );
}

void fragment() {
    vec2 uv = 2.0 * UV - 1.0;
    vec2 viewport_size = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = viewport_size.x / viewport_size.y;
	
    vec2 centered_uv = uv - player_screen_pos;
	centered_uv.x *= aspect;
    float dist = length(centered_uv);

    // --------------------------------
    // Layer 0: Base vignette
    // --------------------------------

    float zero_mask = 1.0 - smoothstep(
        0.2,
        1.8,
        dist
    );
	
    float zero_alpha = (1.0 - zero_mask) * vignette_strength;

    vec4 base_vignette_col = vec4(
        vec3(0.0),
        zero_alpha
    );


    // --------------------------------
    // Layer 1: Noise vignette
    // --------------------------------

	float noise = texture(
	    noise_texture,
	    uv * noise_scale - vec2(0., 0.1 * TIME)
	).r;

	// Fade noise in as distance from player increases
	float noise_fade = smoothstep(
	    0.25,
	    0.85,
	    dist
	);

	// Modulate noise with distance fade
	float noisy_mask = zero_mask * mix(
	    1.0,
	    noise,
	    noise_strength * noise_fade
	);

	float noisy_alpha = (1.0 - noisy_mask) * vignette_strength;

	vec4 noise_vignette_col = vec4(
	    vec3(0.0),
	    noisy_alpha
	);
	
	COLOR = mix(base_vignette_col, noise_vignette_col, float(vignette_layer == 1));
	float _noise = interleaved_gradient_noise(FRAGCOORD.xy) - 0.5;

    // Adjust dithering strength
    COLOR.xyz += _noise / 255.0;
}
