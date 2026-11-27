shader_type canvas_item;

// from https://www.patreon.com/SaturnsMind/posts/tutorial-fire-175439401
// pretty dope

uniform sampler2D color_ramp : source_color, hint_default_white, filter_nearest, repeat_disable;
uniform float speed : hint_range(0.1, 5.0) = 1.0;

// Inigo Quilez smin
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Mirza Beig's Circle Wave (Parabola-based sideways push)
float circle_wave(vec2 uv, float t) {
    float pos = uv.y * 3.0 - t * 6.0;
    float cell = floor(pos);
    float a = fract(pos) * 2.0 - 1.0;
    float bump = 1.0 - (a * a); // Parabolic bump
    float sign_flip = sign(mod(cell, 2.0) - 0.5);
    return bump * sign_flip * 0.12 * uv.y; // Zero at base, strongest at tip
}

// Mathematical Flame Shape (Width curve based on height)
float flame_func(vec2 uv, float t, float height_mult, float width_mult) {
    float h = uv.y / height_mult;
    if (h < 0.0 || h > 1.0) return 1.0;
    
    // Width curve: sqrt(h) gives round bottom, (1.0 - h) pulls to point at top
    float width = sqrt(clamp(h, 0.0, 1.0)) * (1.0 - h) * width_mult;
    
    // Apply circle wave sway
    float sway = circle_wave(uv, t);
    float local_x = uv.x - 0.5 - sway;
    
    // Signed distance to edge (negative inside, positive outside)
    float d = abs(local_x) - width;
    return d;
}

void fragment() 
{
    vec2 uv = UV;
	uv.y = 1. - UV.y;
    float t = TIME * speed;
    
    // 1. Dual Flames merged with Smooth Min (smin) for organic liquid movement
    float d1 = flame_func(uv, t, 1.0, 0.6);
    float d2 = flame_func(uv, t + 1.5, 0.85, 0.45);
    float d = smin(d1, d2, 0.05);
    
    // 2. Carve Holes using Sliding Rows (checking current row and neighbors i = -1 to 1)
    float time_rows = t * 10.0;
    for (int i = -1; i <= 1; i++) {
        float row_pos = uv.y * 4.0 - time_rows + float(i);
        float cell = floor(row_pos);
        float cell_center_y = (cell + 0.5 + time_rows) / 4.0;
        
        // Alternate left/right offset per row
        float cell_sign = sign(mod(cell, 2.0) - 0.5);
        float hole_x = 0.5 + cell_sign * 0.2 * (1.0 - uv.y * 0.5);
        
        vec2 hole_uv = vec2(uv.x, uv.y) - vec2(hole_x, cell_center_y);
        hole_uv.y *= 0.55; // Squash space vertically to stretch holes into teardrop tongues
        
        // Radius grows with height (keeps base solid)
        float hole_radius = 0.07 * smoothstep(0.2, 0.45, uv.y);
        float hole_d = length(hole_uv) - hole_radius;
        
        // Smooth subtraction carving (-smin trick)
        d = -smin(-d, hole_d, 0.05);
    }

    // 4. Banded Toon Colors via Gradient Ramp (depth inside flame)
    // Inside is negative, so flip d to make depth positive (0 at edge, deeper inside > 0)
    float depth = -d;
    float normalized_depth = clamp(depth / 0.18, 0.0, 1.0);
    
    // Sample gradient (ensure GradientTexture1D interpolation is set to Constant)
    vec4 fire_color = texture(color_ramp, vec2(normalized_depth, 0.5));
    
    // HDR Glow boost (turn on WorldEnvironment Glow with threshold ~1.0)
    fire_color.rgb *= 1.8;
    
    COLOR = vec4(fire_color.xyz, fire_color.r);
}