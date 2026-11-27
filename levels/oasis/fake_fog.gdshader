
shader_type canvas_item;

uniform vec4 fog_color : source_color = vec4(0.75, 0.82, 0.9, 1.0);

// Rectangle dimensions in local shader units (pixels).
uniform vec2 rect_size = vec2(400.0, 250.0);

// Fog shape
uniform float fog_thickness = 35.0;
uniform float fog_density = 0.8;
uniform float edge_softness = 18.0;
uniform float distortion = 25.0;

// Noise texture
uniform sampler2D noise_texture : repeat_enable, filter_linear_mipmap;

uniform float noise_scale = 0.008;
uniform float detail_scale = 1.9;
uniform float detail_strength = 0.5;
uniform float noise_speed = 0.025;

// --------------------------------------------------
// Fragment
// --------------------------------------------------

void fragment() {
    // Local coordinates, independent of source texture size.
    vec2 pixel = UV * rect_size;

    // Rectangle SDF.
    vec2 half_size = rect_size * 0.5;
    vec2 p = abs(pixel - half_size) - half_size;

    float sdf = length(max(p, vec2(0.0)))
        + min(max(p.x, p.y), 0.0);

    float edge_distance = abs(sdf);

    // Screen-space noise coordinates.
    // Noise detail does not stretch with the rectangle.
    vec2 noise_uv = UV / noise_scale;

    float t = TIME * noise_speed;

    // Two independently scrolling texture samples.
    float n1 = texture(
        noise_texture,
        noise_uv + vec2(0.3 * t, t * 0.73)
    ).r;

    float n2 = texture(
        noise_texture,
        noise_uv * detail_scale
        + vec2(-t * 0.61, t * 0.87)
        + vec2(0.37, 0.19)
    ).r;

    // Multiplication breaks up the repeating pattern.
    float combined_noise = n1 * n2;

    // Remap and center the noise.
    combined_noise = combined_noise * 2.0 - 0.5;

    // Distort the SDF boundary.
    float distorted_distance =
        edge_distance - combined_noise * distortion;

    // Fog falloff.
    float fog = 1.0 - smoothstep(
        fog_thickness,
        fog_thickness + edge_softness,
        distorted_distance
    );

    // Modulate density.
    fog *= mix(
        0.65,
        1.0,
        n1 * n1 * detail_strength + (1.0 - detail_strength)
    );

    fog *= fog_density;

    COLOR = vec4(
        fog_color.rgb,
        clamp(fog * fog, 0.0, 1.0)
    );
}
