shader_type canvas_item;
render_mode blend_add;

void vertex() {
	// Called for every vertex the material is visible on.
}
uniform float light_strength : hint_range(0.0, 1.0) = 0.12;
uniform float light_radius : hint_range(0.01, 2.0) = 0.1;
uniform vec3 light_color : source_color = vec3(1.0, 0.88, 0.72);
uniform vec2 player_screen_pos;

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
	//vec2 offset = (uv - player_screen_pos);
    float dist = length(centered_uv);

    float light_mask = 4. * exp(
        -0.1 * (dist * dist) / (light_radius * light_radius)
    );

    float v = light_mask * light_strength;

    // Center noise around zero
    float noise = interleaved_gradient_noise(FRAGCOORD.xy) - 0.5;

    // Adjust dithering strength
    v += noise / 255.0;

    vec3 light_rgb = light_color * v;

    COLOR = vec4(light_rgb, v);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
